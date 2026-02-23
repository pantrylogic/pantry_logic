class CalendarEntry {
  final String id;
  final String householdId;
  final String? mealId;
  final String? mealName;
  final int needCount;
  final int missingCount;
  final DateTime date;

  bool get hasMeal => mealId != null;
  bool get allInPantry => needCount > 0 && missingCount == 0;
  bool get hasNeedList => needCount > 0;

  const CalendarEntry({
    required this.id,
    required this.householdId,
    this.mealId,
    this.mealName,
    required this.needCount,
    required this.missingCount,
    required this.date,
  });

  factory CalendarEntry.fromJson(
    Map<String, dynamic> json, {
    Set<String> inventoryItemIds = const {},
  }) {
    final meal = json['meals'] as Map<String, dynamic>?;
    final needList = meal?['meal_need_list'] as List<dynamic>? ?? [];
    final needCount = needList.length;
    final missingCount = needList
        .where((n) => !inventoryItemIds.contains(n['item_id'] as String))
        .length;

    return CalendarEntry(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      mealId: json['meal_id'] as String?,
      mealName: meal?['name'] as String?,
      needCount: needCount,
      missingCount: missingCount,
      date: DateTime.parse(json['date'] as String),
    );
  }
}
