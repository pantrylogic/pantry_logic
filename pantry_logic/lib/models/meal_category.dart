class MealCategory {
  final String id;
  final String householdId;
  final String name;
  final int sortOrder;

  const MealCategory({
    required this.id,
    required this.householdId,
    required this.name,
    required this.sortOrder,
  });

  factory MealCategory.fromJson(Map<String, dynamic> json) => MealCategory(
        id: json['id'] as String,
        householdId: json['household_id'] as String,
        name: json['name'] as String,
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}
