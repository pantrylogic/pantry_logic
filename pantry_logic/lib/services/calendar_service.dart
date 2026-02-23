import 'dart:async';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/calendar_entry.dart';
import '../models/meal.dart';

class CalendarService {
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

  // ─── Weekly stream ────────────────────────────────────────────────────────────

  /// Stream of CalendarEntry objects for [weekStart]..[weekStart+6].
  /// Emits on any change to calendar_entries, meals, or inventory.
  Stream<List<CalendarEntry>> streamWeek(DateTime weekStart) {
    final ctrl = StreamController<List<CalendarEntry>>();
    final channels = <RealtimeChannel>[];
    final start = _dateOnly(weekStart);
    final end = _dateOnly(weekStart.add(const Duration(days: 6)));

    Future<void> fetchAndEmit() async {
      if (ctrl.isClosed) return;
      try {
        final rows = await _client
            .from('calendar_entries')
            .select('*, meals(id, name, meal_need_list(item_id))')
            .gte('date', start)
            .lte('date', end)
            .order('date');

        final inventoryRows =
            await _client.from('inventory_items').select('item_id');
        final inventoryIds =
            inventoryRows.map((r) => r['item_id'] as String).toSet();

        if (!ctrl.isClosed) {
          ctrl.add(
            rows
                .map((r) =>
                    CalendarEntry.fromJson(r, inventoryItemIds: inventoryIds))
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
      for (final table in [
        'calendar_entries',
        'meals',
        'meal_need_list',
        'inventory_items'
      ]) {
        final ch = _client
            .channel('cal_${table}_$ts')
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

  // ─── CRUD ─────────────────────────────────────────────────────────────────────

  /// Assign [mealId] to [date]. Upserts (one meal per household per day).
  Future<void> assignMeal({
    required DateTime date,
    required String mealId,
  }) async {
    final hid = _householdId;
    if (hid == null) throw Exception('No household assigned.');
    await _client.from('calendar_entries').upsert(
      {
        'household_id': hid,
        'meal_id': mealId,
        'date': _dateOnly(date),
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'household_id,date',
    );
  }

  /// Remove the meal from [date] (sets meal_id to null).
  Future<void> clearDay(DateTime date) async {
    final hid = _householdId;
    if (hid == null) throw Exception('No household assigned.');
    await _client
        .from('calendar_entries')
        .delete()
        .eq('household_id', hid)
        .eq('date', _dateOnly(date));
  }

  // ─── Home dashboard helpers ───────────────────────────────────────────────────

  /// Get a single [CalendarEntry] for [date], or null if none.
  Future<CalendarEntry?> getEntryForDate(DateTime date) async {
    final rows = await _client
        .from('calendar_entries')
        .select('*, meals(id, name, meal_need_list(item_id))')
        .eq('date', _dateOnly(date))
        .limit(1);

    if (rows.isEmpty) return null;

    final inventoryRows =
        await _client.from('inventory_items').select('item_id');
    final inventoryIds =
        inventoryRows.map((r) => r['item_id'] as String).toSet();

    return CalendarEntry.fromJson(rows.first, inventoryItemIds: inventoryIds);
  }

  /// Fetch the week's entries (no stream) for the home dashboard week preview.
  Future<List<CalendarEntry>> getWeek(DateTime weekStart) async {
    final start = _dateOnly(weekStart);
    final end = _dateOnly(weekStart.add(const Duration(days: 6)));

    final rows = await _client
        .from('calendar_entries')
        .select('*, meals(id, name, meal_need_list(item_id))')
        .gte('date', start)
        .lte('date', end)
        .order('date');

    final inventoryRows =
        await _client.from('inventory_items').select('item_id');
    final inventoryIds =
        inventoryRows.map((r) => r['item_id'] as String).toSet();

    return rows
        .map((r) => CalendarEntry.fromJson(r, inventoryItemIds: inventoryIds))
        .toList();
  }

  /// Get all meals for the household (for the picker).
  Future<List<Meal>> getMeals() async {
    final rows = await _client
        .from('meals')
        .select('*, meal_categories(name), meal_need_list(item_id)')
        .order('name');

    final inventoryRows =
        await _client.from('inventory_items').select('item_id');
    final inventoryIds =
        inventoryRows.map((r) => r['item_id'] as String).toSet();

    return rows
        .map((r) => Meal.fromJson(r, inventoryItemIds: inventoryIds))
        .toList();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────────

  String _dateOnly(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}
