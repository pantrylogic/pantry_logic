import '../core/ingredient_availability.dart';

class CalendarEntry {
  final String id;
  final String householdId;
  final String? mealId;
  final String? mealName;
  final int needCount;
  final int missingCount;
  final int unknownCount;
  final DateTime date;

  bool get hasMeal => mealId != null;
  bool get allInPantry =>
      needCount > 0 && missingCount == 0 && unknownCount == 0;
  bool get hasNeedList => needCount > 0;

  const CalendarEntry({
    required this.id,
    required this.householdId,
    this.mealId,
    this.mealName,
    required this.needCount,
    required this.missingCount,
    required this.unknownCount,
    required this.date,
  });

  factory CalendarEntry.fromJson(
    Map<String, dynamic> json, {
    Map<String, String?> inventoryQuantities = const {},
  }) {
    final meal = json['meals'] as Map<String, dynamic>?;
    final needList = meal?['meal_need_list'] as List<dynamic>? ?? [];
    final availability = MealAvailabilitySummary.fromIngredients(
      needList.map((need) {
        final itemId = need['item_id'] as String;
        return calculateIngredientAvailability(
          isInInventory: inventoryQuantities.containsKey(itemId),
          requiredQuantity: need['required_quantity'] as int?,
          inventoryQuantity: inventoryQuantities[itemId],
        );
      }),
    );

    return CalendarEntry(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      mealId: json['meal_id'] as String?,
      mealName: meal?['name'] as String?,
      needCount: availability.needCount,
      missingCount: availability.missingCount,
      unknownCount: availability.unknownCount,
      date: DateTime.parse(json['date'] as String),
    );
  }
}
