import 'package:flutter/widgets.dart';

/// Route names for pushed screens that other flows need to find again.
abstract final class AppRoutes {
  static const mealDetail = '/meal-detail';
  static const hungryCategory = '/hungry-category';
  static const hungrySuggestion = '/hungry-suggestion';
  static const restock = '/restock';

  /// Screens the Restock "Done" button returns to. Home and Calendar are
  /// tabs of the root route, so they're covered by `isFirst`.
  static const restockOrigins = {mealDetail, hungryCategory};

  static RouteSettings settings(String name) => RouteSettings(name: name);
}

/// Whether [route] is where the Eat This / Restock flow should return to.
bool isRestockOrigin(Route<dynamic> route) =>
    route.isFirst || AppRoutes.restockOrigins.contains(route.settings.name);

/// Pops back to the screen the Eat This flow started from: meal detail,
/// the Hungry category picker, or the main shell (Home / Calendar).
void popToRestockOrigin(BuildContext context) =>
    Navigator.of(context).popUntil(isRestockOrigin);
