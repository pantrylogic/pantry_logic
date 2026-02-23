import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/meal_category.dart';
import '../models/meal.dart';
import '../models/meal_need_item.dart';
import '../models/item.dart';

class MealService {
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

  // ─── Categories ──────────────────────────────────────────────────────────────

  Future<List<MealCategory>> getCategories() async {
    final rows = await _client
        .from('meal_categories')
        .select()
        .order('sort_order')
        .order('name');
    return rows.map(MealCategory.fromJson).toList();
  }

  Future<MealCategory> addCategory(String name) async {
    final hid = _householdId;
    if (hid == null) throw Exception('No household assigned.');
    final row = await _client
        .from('meal_categories')
        .insert({'household_id': hid, 'name': name.trim()})
        .select()
        .single();
    return MealCategory.fromJson(row);
  }

  Future<void> deleteCategory(String categoryId) async {
    await _client.from('meal_categories').delete().eq('id', categoryId);
  }

  // ─── Meals stream ─────────────────────────────────────────────────────────────

  /// Real-time stream of all meals for the household.
  /// Includes category name, need list item count, and missing item count.
  Stream<List<Meal>> streamMeals() {
    final ctrl = StreamController<List<Meal>>();
    final channels = <RealtimeChannel>[];

    Future<void> fetchAndEmit() async {
      if (ctrl.isClosed) return;
      try {
        final mealRows = await _client
            .from('meals')
            .select('*, meal_categories(name), meal_need_list(item_id)')
            .order('name');

        final inventoryRows =
            await _client.from('inventory_items').select('item_id');
        final inventoryIds =
            inventoryRows.map((r) => r['item_id'] as String).toSet();

        if (!ctrl.isClosed) {
          ctrl.add(
            mealRows
                .map((r) => Meal.fromJson(r, inventoryItemIds: inventoryIds))
                .toList(),
          );
        }
      } catch (e) {
        if (!ctrl.isClosed) ctrl.addError(e);
      }
    }

    ctrl.onListen = () {
      fetchAndEmit();
      final ts = DateTime.now().millisecondsSinceEpoch;
      for (final table in ['meals', 'meal_need_list', 'inventory_items']) {
        final ch = _client
            .channel('meals_${table}_$ts')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: table,
              callback: (_) => fetchAndEmit(),
            )
            .subscribe();
        channels.add(ch);
      }
    };

    ctrl.onCancel = () {
      for (final ch in channels) {
        _client.removeChannel(ch);
      }
      ctrl.close();
    };

    return ctrl.stream;
  }

  // ─── Need list stream ─────────────────────────────────────────────────────────

  /// Real-time stream of a meal's need list with current pantry status.
  Stream<List<MealNeedItem>> streamNeedList(String mealId) {
    final ctrl = StreamController<List<MealNeedItem>>();
    final channels = <RealtimeChannel>[];

    Future<void> fetchAndEmit() async {
      if (ctrl.isClosed) return;
      try {
        final needRows = await _client
            .from('meal_need_list')
            .select('meal_id, item_id, items(name)')
            .eq('meal_id', mealId);

        final itemIds = needRows.map((r) => r['item_id'] as String).toList();

        Map<String, String> inventoryLocations = {};
        if (itemIds.isNotEmpty) {
          final invRows = await _client
              .from('inventory_items')
              .select('item_id, location')
              .inFilter('item_id', itemIds);
          inventoryLocations = {
            for (final r in invRows)
              r['item_id'] as String: r['location'] as String,
          };
        }

        if (!ctrl.isClosed) {
          // Sort by item name
          final items = needRows.map((r) {
            final item = r['items'] as Map<String, dynamic>?;
            final itemId = r['item_id'] as String;
            return MealNeedItem(
              mealId: r['meal_id'] as String,
              itemId: itemId,
              itemName: item?['name'] as String? ?? '',
              inventoryLocation: inventoryLocations[itemId],
            );
          }).toList()
            ..sort((a, b) => a.itemName.compareTo(b.itemName));

          ctrl.add(items);
        }
      } catch (e) {
        if (!ctrl.isClosed) ctrl.addError(e);
      }
    }

    ctrl.onListen = () {
      fetchAndEmit();
      final ts = DateTime.now().millisecondsSinceEpoch;
      for (final table in ['meal_need_list', 'inventory_items']) {
        final ch = _client
            .channel('needlist_${table}_$ts')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: table,
              callback: (_) => fetchAndEmit(),
            )
            .subscribe();
        channels.add(ch);
      }
    };

    ctrl.onCancel = () {
      for (final ch in channels) {
        _client.removeChannel(ch);
      }
      ctrl.close();
    };

    return ctrl.stream;
  }

  // ─── Meal CRUD ───────────────────────────────────────────────────────────────

  Future<void> addMeal({required String name, String? categoryId}) async {
    final hid = _householdId;
    if (hid == null) throw Exception('No household assigned.');
    await _client.from('meals').insert({
      'household_id': hid,
      'name': name.trim(),
      if (categoryId != null) 'category_id': categoryId,
    });
  }

  Future<void> updateMeal(
    String mealId, {
    String? name,
    String? categoryId,
    bool clearCategory = false,
    String? notes,
    bool clearNotes = false,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null && name.isNotEmpty) updates['name'] = name.trim();
    if (clearCategory) {
      updates['category_id'] = null;
    } else if (categoryId != null) {
      updates['category_id'] = categoryId;
    }
    if (clearNotes) {
      updates['notes'] = null;
    } else if (notes != null) {
      updates['notes'] = notes.isNotEmpty ? notes : null;
    }
    if (updates.isEmpty) return;
    await _client.from('meals').update(updates).eq('id', mealId);
  }

  Future<void> deleteMeal(String mealId) async {
    await _client.from('meals').delete().eq('id', mealId);
  }

  // ─── Need list CRUD ───────────────────────────────────────────────────────────

  Future<void> addNeedItem({
    required String mealId,
    required String itemId,
  }) async {
    try {
      await _client.from('meal_need_list').insert({
        'meal_id': mealId,
        'item_id': itemId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') return; // already in need list — ignore
      rethrow;
    }
  }

  Future<void> removeNeedItem({
    required String mealId,
    required String itemId,
  }) async {
    await _client
        .from('meal_need_list')
        .delete()
        .eq('meal_id', mealId)
        .eq('item_id', itemId);
  }

  // ─── Add missing to grocery list ─────────────────────────────────────────────

  /// Adds all need-list items not currently in the pantry to the grocery list.
  /// Skips items already on the grocery list (unpurchased).
  /// Returns the number of items actually added.
  Future<int> addMissingToGroceryList(String mealId) async {
    final hid = _householdId;
    if (hid == null) throw Exception('No household assigned.');
    final userId = _client.auth.currentUser?.id;

    final needRows = await _client
        .from('meal_need_list')
        .select('item_id')
        .eq('meal_id', mealId);
    final needIds = needRows.map((r) => r['item_id'] as String).toList();
    if (needIds.isEmpty) return 0;

    final invRows = await _client
        .from('inventory_items')
        .select('item_id')
        .inFilter('item_id', needIds);
    final inventoryIds = invRows.map((r) => r['item_id'] as String).toSet();

    final missing =
        needIds.where((id) => !inventoryIds.contains(id)).toList();
    if (missing.isEmpty) return 0;

    final existingRows = await _client
        .from('grocery_items')
        .select('item_id')
        .eq('purchased', false)
        .inFilter('item_id', missing);
    final existingIds =
        existingRows.map((r) => r['item_id'] as String).toSet();

    final toAdd =
        missing.where((id) => !existingIds.contains(id)).toList();
    if (toAdd.isEmpty) return 0;

    await _client.from('grocery_items').insert(
      toAdd
          .map((itemId) => {
                'household_id': hid,
                'item_id': itemId,
                if (userId != null) 'added_by': userId,
              })
          .toList(),
    );

    return toAdd.length;
  }

  // ─── Item autocomplete / get-or-create ───────────────────────────────────────

  Future<List<AutocompleteSuggestion>> searchAutocomplete(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final pattern = '%$trimmed%';

    final itemRows = await _client
        .from('items')
        .select('id, name, category, default_location')
        .ilike('name', pattern)
        .order('name')
        .limit(8);

    final suggestions = itemRows
        .map((r) => AutocompleteSuggestion(
              itemId: r['id'] as String,
              name: r['name'] as String,
              category: r['category'] as String?,
              defaultLocation: r['default_location'] as String? ?? 'Pantry',
            ))
        .toList();

    final existingNames =
        suggestions.map((s) => s.name.toLowerCase()).toSet();

    final dictRows = await _client
        .from('starter_dictionary')
        .select('name, category, default_location')
        .ilike('name', pattern)
        .order('name')
        .limit(10);

    final dictSuggestions = dictRows
        .where((r) =>
            !existingNames.contains((r['name'] as String).toLowerCase()))
        .take(8 - suggestions.length)
        .map((r) => AutocompleteSuggestion(
              itemId: null,
              name: r['name'] as String,
              category: r['category'] as String?,
              defaultLocation: r['default_location'] as String? ?? 'Pantry',
            ))
        .toList();

    return [...suggestions, ...dictSuggestions];
  }

  Future<Item> getOrCreateItem({
    required String name,
    String? category,
    String? defaultLocation,
  }) async {
    final trimmed = name.trim();
    final existing = await _client
        .from('items')
        .select()
        .ilike('name', trimmed)
        .maybeSingle();
    if (existing != null) return Item.fromJson(existing);

    final hid = _householdId;
    if (hid == null) throw Exception('No household assigned.');
    try {
      final created = await _client
          .from('items')
          .insert({
            'household_id': hid,
            'name': trimmed,
            if (category != null) 'category': category,
            'default_location': defaultLocation ?? 'Pantry',
          })
          .select()
          .single();
      return Item.fromJson(created);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        final fallback = await _client
            .from('items')
            .select()
            .ilike('name', trimmed)
            .single();
        return Item.fromJson(fallback);
      }
      rethrow;
    }
  }
}
