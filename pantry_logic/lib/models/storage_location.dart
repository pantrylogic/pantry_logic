class StorageLocation {
  final String id;
  final String householdId;
  final String name;
  final bool isDefault;
  final int sortOrder;

  const StorageLocation({
    required this.id,
    required this.householdId,
    required this.name,
    required this.isDefault,
    required this.sortOrder,
  });

  factory StorageLocation.fromJson(Map<String, dynamic> json) =>
      StorageLocation(
        id: json['id'] as String,
        householdId: json['household_id'] as String,
        name: json['name'] as String,
        isDefault: json['is_default'] as bool? ?? false,
        sortOrder: json['sort_order'] as int? ?? 0,
      );
}
