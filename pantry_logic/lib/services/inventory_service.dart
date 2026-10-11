import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/inventory_item.dart';
import '../models/item.dart';
import '../models/storage_location.dart';
import '../core/like.dart';
import '../core/item_name.dart';

class InventoryService {
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

  // ─── Storage locations ────────────────────────────────────────────────────────

  Future<List<StorageLocation>> getStorageLocations() async {
    final rows = await _client
        .from('storage_locations')
        .select()
        .order('sort_order')
        .order('name');
    return rows.map(StorageLocation.fromJson).toList();
  }

  // ─── Autocomplete ────────────────────────────────────────────────────────────

  Future<List<AutocompleteSuggestion>> searchAutocomplete(String query) async {
    final trimmed = normalizeItemName(query);
    if (trimmed.isEmpty) return [];

    final pattern = '%${escapeLike(trimmed)}%';

    final itemRows = await _client
        .from('items')
        .select('id, name, category, default_location')
        .ilike('name', pattern)
        .order('name')
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

  // ─── Inventory stream ─────────────────────────────────────────────────────────

  Stream<List<InventoryItem>> streamInventoryItems() {
    final ctrl = StreamController<List<InventoryItem>>();
    RealtimeChannel? channel;

    Future<void> fetchAndEmit() async {
      if (ctrl.isClosed) return;
      try {
        final rows = await _client
            .from('inventory_items')
            .select('*, items(name), profiles!added_by(display_name)')
            .order('location')
            .order('updated_at', ascending: false);
        if (!ctrl.isClosed) {
          ctrl.add(rows.map(InventoryItem.fromJson).toList());
        }
      } catch (e) {
        if (!ctrl.isClosed) ctrl.addError(e);
      }
    }

    ctrl.onListen = () {
      fetchAndEmit();
      channel = _client
          .channel('inventory_${DateTime.now().millisecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'inventory_items',
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

  // ─── Items ────────────────────────────────────────────────────────────────────

  Future<Item> getOrCreateItem({
    required String name,
    String? category,
    String? defaultLocation,
  }) async {
    final trimmed = normalizeItemName(name);

    final existing = await _client
        .from('items')
        .select()
        .ilike('name', escapeLike(trimmed))
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
            .ilike('name', escapeLike(trimmed))
            .single();
        return Item.fromJson(fallback);
      }
      rethrow;
    }
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────────

  /// Adds an item to inventory. Throws [AlreadyInPantryException] if
  /// the item is already tracked (unique constraint on household_id, item_id).
  Future<void> addInventoryItem({
    required String itemId,
    required String itemName,
    required String location,
    String? quantity,
    String? notes,
    String? addedBy,
  }) async {
    final hid = _householdId;
    if (hid == null) throw Exception('No household assigned.');
    final userId = addedBy ?? _client.auth.currentUser?.id;
    try {
      await _client.from('inventory_items').insert({
        'household_id': hid,
        'item_id': itemId,
        'location': location,
        if (quantity != null && quantity.isNotEmpty) 'quantity': quantity,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (userId != null) 'added_by': userId,
      });
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw AlreadyInPantryException(itemName);
      rethrow;
    }

    // Learn the location: last-used wins.
    await _client
        .from('items')
        .update({'default_location': location}).eq('id', itemId);
  }

  Future<void> updateInventoryItem(
    String inventoryItemId, {
    String? location,
    String? quantity,
    String? notes,
  }) async {
    final updates = <String, dynamic>{};
    if (location != null) updates['location'] = location;
    updates['quantity'] = quantity?.isNotEmpty == true ? quantity : null;
    updates['notes'] = notes?.isNotEmpty == true ? notes : null;
    await _client
        .from('inventory_items')
        .update(updates)
        .eq('id', inventoryItemId);
  }

  Future<void> deleteInventoryItem(String inventoryItemId) async {
    await _client
        .from('inventory_items')
        .delete()
        .eq('id', inventoryItemId);
  }

  /// Renames the underlying item (shared by stock, grocery and meal
  /// ingredients). Throws [ItemNameTakenException] if another item in the
  /// household already has that name (case-insensitive unique index).
  Future<void> renameItem(String itemId, String newName) async {
    final trimmed = newName.trim();
    try {
      await _client.from('items').update({'name': trimmed}).eq('id', itemId);
    } on PostgrestException catch (e) {
      if (e.code == '23505') throw ItemNameTakenException(trimmed);
      rethrow;
    }
  }

  /// Adds an inventory item's underlying item to the grocery list.
  /// Returns false (and adds nothing) if it's already on the list.
  Future<bool> addToGroceryList(String itemId) async {
    final hid = _householdId;
    if (hid == null) throw Exception('No household assigned.');
    final existing = await _client
        .from('grocery_items')
        .select('id')
        .eq('item_id', itemId)
        .eq('purchased', false)
        .limit(1);
    if (existing.isNotEmpty) return false;
    final userId = _client.auth.currentUser?.id;
    await _client.from('grocery_items').insert({
      'household_id': hid,
      'item_id': itemId,
      if (userId != null) 'added_by': userId,
    });
    return true;
  }
}
