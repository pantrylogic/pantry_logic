import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/suggested_meal.dart';
import '../models/restock_item.dart';
import '../models/meal_category.dart';

class HungryService {
  static final _client = Supabase.instance.client;

  // ─── JWT helpers ─────────────────────────────────────────────────────────────

  String? get _householdId {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      var payload = parts[1];
      final rem = payload.length % 4;
      if (rem > 0) payload = payload.padRight(payload.length + (4 - rem), '=');
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      return (map['app_metadata'] as Map<String, dynamic>?)?['household_id']
          as String?;
    } catch (_) {
      return null;
    }
  }

  // ─── Categories ───────────────────────────────────────────────────────────────

  Future<List<MealCategory>> getCategories() async {
    final rows = await _client
        .from('meal_categories')
        .select()
        .order('sort_order')
        .order('name');
    return rows.map(MealCategory.fromJson).toList();
  }

  // ─── Suggestions ──────────────────────────────────────────────────────────────

  /// Returns meals in the given category, sorted by priority:
  /// - Pool A (shuffled): meals where every need-list item is in inventory,
  ///   OR meals with no need list at all.
  /// - Pool B (shuffled): meals where one or more need-list items are missing.
  Future<List<SuggestedMeal>> getSuggestions(String categoryId) async {
    final mealRows = await _client
        .from('meals')
        .select(
          'id, name, category_id, meal_categories(name), '
          'meal_need_list(item_id, items(name))',
        )
        .eq('category_id', categoryId)
        .order('name');

    final invRows = await _client.from('inventory_items').select('item_id');
    final inventoryIds =
        invRows.map((r) => r['item_id'] as String).toSet();

    final meals = mealRows.map((r) {
      final needList = r['meal_need_list'] as List<dynamic>? ?? [];
      final missingEntries = needList
          .where((n) => !inventoryIds.contains(n['item_id'] as String))
          .toList();
      final missingNames = missingEntries
          .map((n) => (n['items'] as Map<String, dynamic>)['name'] as String)
          .toList();
      return SuggestedMeal(
        id: r['id'] as String,
        name: r['name'] as String,
        categoryId: r['category_id'] as String?,
        categoryName:
            (r['meal_categories'] as Map<String, dynamic>?)?['name'] as String?,
        needCount: needList.length,
        missingCount: missingEntries.length,
        missingItemNames: missingNames,
      );
    }).toList();

    final poolA = meals.where((m) => m.missingCount == 0).toList()..shuffle();
    final poolB = meals.where((m) => m.missingCount > 0).toList()..shuffle();
    return [...poolA, ...poolB];
  }

  // ─── Restock ──────────────────────────────────────────────────────────────────

  /// Executes the restock flow for a meal:
  /// 1. Fetches all need-list items that are currently in inventory.
  /// 2. Items with a parseable numeric quantity ≥ 1 are auto-reduced by 1;
  ///    if the new quantity hits 0, the inventory entry is deleted.
  /// 3. Returns the list of items requiring a user decision:
  ///    - [RestockReason.hitZero]: had qty, now at 0 — inventory already deleted.
  ///    - [RestockReason.noQuantity]: in inventory but no parseable numeric qty.
  ///    Items that still have qty > 0 after auto-reduction are silently updated
  ///    and do not appear in the returned list.
  Future<List<RestockDecisionItem>> executeRestock(String mealId) async {
    // 1. Fetch need list
    final needRows = await _client
        .from('meal_need_list')
        .select('item_id, items(name)')
        .eq('meal_id', mealId);

    final itemIds = needRows.map((r) => r['item_id'] as String).toList();
    if (itemIds.isEmpty) return [];

    // 2. Fetch inventory entries for those items
    final invRows = await _client
        .from('inventory_items')
        .select('id, item_id, quantity')
        .inFilter('item_id', itemIds);

    // Build a map: item_id → {id, quantity}
    final invMap = {
      for (final r in invRows)
        r['item_id'] as String: (
          id: r['id'] as String,
          quantity: r['quantity'] as String?,
        ),
    };

    // 3. Process each need-list item that's in inventory
    final decisions = <RestockDecisionItem>[];

    for (final needRow in needRows) {
      final itemId = needRow['item_id'] as String;
      final itemName =
          (needRow['items'] as Map<String, dynamic>)['name'] as String;
      final inv = invMap[itemId];
      if (inv == null) continue; // not in inventory — skip

      final parsedQty = double.tryParse(inv.quantity?.trim() ?? '');

      if (parsedQty != null) {
        // Has numeric quantity — auto-reduce
        final newQty = parsedQty - 1;
        if (newQty <= 0) {
          // Delete from inventory
          await _client
              .from('inventory_items')
              .delete()
              .eq('id', inv.id);
          decisions.add(RestockDecisionItem(
            itemId: itemId,
            itemName: itemName,
            reason: RestockReason.hitZero,
          ));
        } else {
          // Silently update
          await _client
              .from('inventory_items')
              .update({'quantity': _formatQty(newQty)})
              .eq('id', inv.id);
        }
      } else {
        // No parseable quantity — user must decide
        decisions.add(RestockDecisionItem(
          itemId: itemId,
          itemName: itemName,
          reason: RestockReason.noQuantity,
        ));
      }
    }

    return decisions;
  }

  String _formatQty(double qty) {
    // Return "2" instead of "2.0" for whole numbers.
    if (qty == qty.truncateToDouble()) return qty.toInt().toString();
    return qty.toString();
  }

  // ─── Post-restock user actions ────────────────────────────────────────────────

  /// Adds an item to the household grocery list.
  Future<void> addToGroceryList(String itemId) async {
    final hid = _householdId;
    if (hid == null) throw Exception('No household assigned.');
    final userId = _client.auth.currentUser?.id;
    try {
      await _client.from('grocery_items').insert({
        'household_id': hid,
        'item_id': itemId,
        if (userId != null) 'added_by': userId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') return; // already on grocery list — ignore
      rethrow;
    }
  }

  /// Removes an item from inventory (by item_id within the household).
  /// Used when the user chooses "Add to list" for a no-quantity item.
  Future<void> removeFromInventoryByItemId(String itemId) async {
    await _client.from('inventory_items').delete().eq('item_id', itemId);
    // RLS restricts to the household, so no explicit household filter needed.
  }
}
