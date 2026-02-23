import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/household.dart';
import '../models/profile.dart';
import '../models/storage_location.dart';
import '../models/meal_category.dart';

class SettingsService {
  static final _client = Supabase.instance.client;

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

  // ─── Household ───────────────────────────────────────────────────────────────

  Future<Household?> getHousehold() async {
    final hid = _householdId;
    if (hid == null) return null;
    final data = await _client
        .from('households')
        .select()
        .eq('id', hid)
        .maybeSingle();
    if (data == null) return null;
    return Household.fromJson(data);
  }

  Future<void> updateHouseholdName(String name) async {
    final hid = _householdId;
    if (hid == null) throw Exception('No household assigned.');
    await _client
        .from('households')
        .update({'name': name.trim()})
        .eq('id', hid);
  }

  // ─── Members ─────────────────────────────────────────────────────────────────

  Future<List<Profile>> getMembers() async {
    final hid = _householdId;
    if (hid == null) return [];
    final rows = await _client
        .from('profiles')
        .select()
        .eq('household_id', hid)
        .order('display_name');
    return rows.map(Profile.fromJson).toList();
  }

  // ─── Display name ────────────────────────────────────────────────────────────

  Future<void> updateDisplayName(String name) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in.');
    await _client
        .from('profiles')
        .update({'display_name': name.trim()})
        .eq('id', userId);
  }

  // ─── Storage locations ───────────────────────────────────────────────────────

  Future<List<StorageLocation>> getLocations() async {
    final rows = await _client
        .from('storage_locations')
        .select()
        .order('sort_order')
        .order('name');
    return rows.map(StorageLocation.fromJson).toList();
  }

  Future<StorageLocation> addLocation(String name) async {
    final hid = _householdId;
    if (hid == null) throw Exception('No household assigned.');
    final row = await _client
        .from('storage_locations')
        .insert({'household_id': hid, 'name': name.trim()})
        .select()
        .single();
    return StorageLocation.fromJson(row);
  }

  Future<void> renameLocation(String locationId, String name) async {
    await _client
        .from('storage_locations')
        .update({'name': name.trim()})
        .eq('id', locationId);
  }

  Future<void> deleteLocation(String locationId) async {
    await _client
        .from('storage_locations')
        .delete()
        .eq('id', locationId);
  }

  // ─── Meal categories ─────────────────────────────────────────────────────────

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

  Future<void> renameCategory(String categoryId, String name) async {
    await _client
        .from('meal_categories')
        .update({'name': name.trim()})
        .eq('id', categoryId);
  }

  Future<void> deleteCategory(String categoryId) async {
    await _client
        .from('meal_categories')
        .delete()
        .eq('id', categoryId);
  }

  // ─── Counts (for home dashboard) ─────────────────────────────────────────────

  Future<int> getGroceryCount() async {
    final result = await _client
        .from('grocery_items')
        .select('id')
        .eq('purchased', false);
    return (result as List).length;
  }

  Future<int> getPantryCount() async {
    final result = await _client.from('inventory_items').select('id');
    return (result as List).length;
  }
}
