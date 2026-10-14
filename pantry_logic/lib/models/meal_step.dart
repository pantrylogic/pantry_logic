/// One numbered step in a meal's directions (`meal_steps`).
class MealStep {
  final String id;
  final String mealId;
  final String householdId;
  final int position;
  final String text;
  final DateTime createdAt;

  const MealStep({
    required this.id,
    required this.mealId,
    required this.householdId,
    required this.position,
    required this.text,
    required this.createdAt,
  });

  factory MealStep.fromJson(Map<String, dynamic> json) => MealStep(
        id: json['id'] as String,
        mealId: json['meal_id'] as String,
        householdId: json['household_id'] as String,
        position: json['position'] as int,
        text: json['text'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  MealStep copyWith({int? position, String? text}) => MealStep(
        id: id,
        mealId: mealId,
        householdId: householdId,
        position: position ?? this.position,
        text: text ?? this.text,
        createdAt: createdAt,
      );
}
