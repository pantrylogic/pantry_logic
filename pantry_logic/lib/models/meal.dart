class Meal {
  final String id;
  final String householdId;
  final String name;
  final String? categoryId;
  final String? categoryName;
  final String? notes;

  /// Total number of items in this meal's need list.
  final int needCount;

  /// Number of need-list items NOT currently in the pantry.
  final int missingCount;

  bool get allInPantry => needCount > 0 && missingCount == 0;
  bool get hasNeedList => needCount > 0;

  const Meal({
    required this.id,
    required this.householdId,
    required this.name,
    this.categoryId,
    this.categoryName,
    this.notes,
    required this.needCount,
    required this.missingCount,
  });

  factory Meal.fromJson(
    Map<String, dynamic> json, {
    Set<String> inventoryItemIds = const {},
  }) {
    final category = json['meal_categories'] as Map<String, dynamic>?;
    final needList = json['meal_need_list'] as List<dynamic>? ?? [];
    final needCount = needList.length;
    final missingCount = needList
        .where((n) => !inventoryItemIds.contains(n['item_id'] as String))
        .length;

    return Meal(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      name: json['name'] as String,
      categoryId: json['category_id'] as String?,
      categoryName: category?['name'] as String?,
      notes: json['notes'] as String?,
      needCount: needCount,
      missingCount: missingCount,
    );
  }
}
