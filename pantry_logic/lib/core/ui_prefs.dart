import 'package:shared_preferences/shared_preferences.dart';

import '../widgets/app_snack_bar.dart';

/// Per-device UI preferences (collapsed sections etc.). Failures are logged
/// and treated as "no saved preference" — these are conveniences only.
class UiPrefs {
  UiPrefs._();

  static const stockCollapsedLocations = 'stock.collapsedLocations';
  static const homeUpcomingExpanded = 'home.upcomingExpanded';

  static Future<Set<String>> getStringSet(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(key) ?? const []).toSet();
    } catch (e, st) {
      logError('UiPrefs read $key', e, st);
      return {};
    }
  }

  static Future<void> setStringSet(String key, Set<String> value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(key, value.toList()..sort());
    } catch (e, st) {
      logError('UiPrefs write $key', e, st);
    }
  }

  static Future<bool> getBool(String key, {bool fallback = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? fallback;
    } catch (e, st) {
      logError('UiPrefs read $key', e, st);
      return fallback;
    }
  }

  static Future<void> setBool(String key, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (e, st) {
      logError('UiPrefs write $key', e, st);
    }
  }
}
