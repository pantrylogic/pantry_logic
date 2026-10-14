import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/grocery_item.dart';
import '../models/item.dart';
import '../core/quantity.dart';
import '../core/like.dart';
import '../core/item_name.dart';

class GroceryService {
  static final _client = Supabase.instance.client;

  // ─── JWT helpers ─────────────────────────────────────────────────────────────

  /// Reads household_id from the current JWT app_metadata.
  /// Returns null if not signed in or household not yet assigned.
  String? get _householdId {
    final token = _client.auth.currentSession?.accessToken;
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      var payload = parts[1];
      // Base64url padding
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

  // ─── Autocomplete ────────────────────────────────────────────────────────────

  /// Returns up to 8 suggestions from the household's own items (learned from
  /// what users have added). Empty when nothing matches.
  Future<List<AutocompleteSuggestion>> searchAutocomplete(String query) async {
    final trimmed = normalizeItemName(query);
    if (trimmed.isEmpty) return [];

    final pattern = '%${escapeLike(trimmed)}%';

    final itemRows = await _client
        .from('items')
        .select('id, name, category, default_location')
        .ilike('name', pattern)
        .order('name', ascending: true)
        .limit(8);

    return itemRows
        .map((r) => AutocompleteSuggestion(
              itemId: r['id'] as String,
              name: r['name'] as String,
              category: r['category'] as String?,
              defaultLocation: r['default_location'] as String? ?? 'Pantry',
            ))
        .toList();
  }

  // ─── Items ───────────────────────────────────────────────────────────────────

  /// Finds an existing household item by name (case-insensitive) or creates one.
  Future<Item> getOrCreateItem({
    required String name,
    String? category,
    String? defaultLocation,
  }) async {
    final trimmed = normalizeItemName(name);

    // Look for existing item in this household (RLS scopes to current household)
    final existing = await _client
        .from('items')
        .select()
        .ilike('name', escapeLike(trimmed))
        .maybeSingle();

    if (existing != null) return Item.fromJson(existing);

    // Insert new item
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
      // Race condition: another device inserted at the same time
      if (e.code == '23505') {
        final fallback = await _client
            .from('items')
            .select()
            .ilike('name', escapeLike(trimmed))
            .single();
        return Item.fromJson(fallback);
      }
      rethrow;
    }
  }

  // ─── Grocery list ─────────────────────────────────────────────────────────────

  /// Real-time stream of all grocery items for the current household.
  /// Re-fetches with full JOIN on each Realtime change event.
  Stream<List<GroceryItem>> streamGroceryItems() {
    final ctrl = StreamController<List<GroceryItem>>();
    RealtimeChannel? channel;

    Future<void> fetchAndEmit() async {
      if (ctrl.isClosed) return;
      try {
        final rows = await _client
            .from('grocery_items')
            .select(
                '*, items(name, default_location), profiles!added_by(display_name)')
            .order('created_at', ascending: false);
        if (!ctrl.isClosed) {
          ctrl.add(rows.map(GroceryItem.fromJson).toList());
        }
      } catch (e) {
        if (!ctrl.isClosed) ctrl.addError(e);
      }
    }

    ctrl.onListen = () {
      fetchAndEmit();
      channel = _client
          .channel('grocery_list_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'grocery_items',
            callback: (_) => fetchAndEmit(),
          )
          .subscribe();
    };

    ctrl.onCancel = () {
      if (channel != null) _client.removeChannel(channel!);
      ctrl.close();
    };

    return ctrl.stream;
  }

  /// Adds an item to the grocery list.
  Future<void> addGroceryItem({
    required String itemId,
    String? quantity,
    String? notes,
  }) async {
    final hid = _householdId;
    if (hid == null) throw Exception('No household assigned.');
    final userId = _client.auth.currentUser?.id;
    await _client.from('grocery_items').insert({
      'household_id': hid,
      'item_id': itemId,
      if (quantity != null && quantity.isNotEmpty) 'quantity': quantity,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
      if (userId != null) 'added_by': userId,
    });
  }

  /// Updates quantity and/or notes on an existing grocery item.
  Future<void> updateGroceryItem(
    String groceryItemId, {
    String? quantity,
    String? notes,
  }) async {
    await _client.from('grocery_items').update({
      'quantity': quantity?.isNotEmpty == true ? quantity : null,
      'notes': notes?.isNotEmpty == true ? notes : null,
    }).eq('id', groceryItemId);
  }

  /// Marks an item purchased and upserts it into inventory.
  /// Merges quantities if the item is already in inventory.
  Future<void> checkOffItem(GroceryItem item) async {
    final now = DateTime.now().toUtc().toIso8601String();

    // Mark as purchased
    await _client.from('grocery_items').update({
      'purchased': true,
      'purchased_at': now,
    }).eq('id', item.id);

    // Fetch existing inventory entry (if any) for quantity merging
    final existing = await _client
        .from('inventory_items')
        .select('location, quantity, notes')
        .eq('item_id', item.itemId)
        .maybeSingle();

    // Only a brand-new stock row gets an added_by; merging into an existing
    // row keeps whoever added it first.
    final addedBy = existing == null
        ? (item.addedBy ?? _client.auth.currentUser?.id)
        : null;

    final mergedQuantity = mergeQuantities(
      existing?['quantity'] as String?,
      item.quantity,
    );

    final location =
        existing?['location'] as String? ?? item.itemDefaultLocation;

    final notes = item.notes?.isNotEmpty == true
        ? item.notes
        : existing?['notes'] as String?;

    // Upsert into inventory (unique constraint on household_id, item_id)
    final hid = _householdId ?? item.householdId;
    await _client.from('inventory_items').upsert(
      {
        'household_id': hid,
        'item_id': item.itemId,
        'location': location,
        if (mergedQuantity != null) 'quantity': mergedQuantity,
        if (notes != null) 'notes': notes,
        if (addedBy != null) 'added_by': addedBy,
      },
      onConflict: 'household_id,item_id',
    );

    // Learn the location: last-used wins.
    await _client
        .from('items')
        .update({'default_location': location}).eq('id', item.itemId);
  }

  /// Unchecks a purchased grocery item (does not remove from inventory).
  Future<void> uncheckItem(String groceryItemId) async {
    await _client.from('grocery_items').update({
      'purchased': false,
      'purchased_at': null,
    }).eq('id', groceryItemId);
  }

  /// Removes a grocery item.
  Future<void> deleteGroceryItem(String groceryItemId) async {
    await _client.from('grocery_items').delete().eq('id', groceryItemId);
  }

  /// Removes all purchased items from the grocery list.
  Future<void> clearCompleted() async {
    await _client.from('grocery_items').delete().eq('purchased', true);
  }
}
