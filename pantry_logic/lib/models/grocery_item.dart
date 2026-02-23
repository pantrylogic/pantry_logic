class GroceryItem {
  final String id;
  final String householdId;
  final String itemId;
  final String itemName;
  final String itemDefaultLocation;
  final String? quantity;
  final String? notes;
  final String? addedBy;
  final String? addedByName;
  final bool purchased;
  final DateTime? purchasedAt;
  final DateTime createdAt;

  const GroceryItem({
    required this.id,
    required this.householdId,
    required this.itemId,
    required this.itemName,
    required this.itemDefaultLocation,
    this.quantity,
    this.notes,
    this.addedBy,
    this.addedByName,
    required this.purchased,
    this.purchasedAt,
    required this.createdAt,
  });

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    final item = json['items'] as Map<String, dynamic>?;
    final profile = json['profiles'] as Map<String, dynamic>?;
    return GroceryItem(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      itemId: json['item_id'] as String,
      itemName: item?['name'] as String? ?? '',
      itemDefaultLocation: item?['default_location'] as String? ?? 'Pantry',
      quantity: json['quantity'] as String?,
      notes: json['notes'] as String?,
      addedBy: json['added_by'] as String?,
      addedByName: profile?['display_name'] as String?,
      purchased: json['purchased'] as bool? ?? false,
      purchasedAt: json['purchased_at'] != null
          ? DateTime.parse(json['purchased_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  GroceryItem copyWith({
    bool? purchased,
    DateTime? purchasedAt,
    String? quantity,
    String? notes,
  }) =>
      GroceryItem(
        id: id,
        householdId: householdId,
        itemId: itemId,
        itemName: itemName,
        itemDefaultLocation: itemDefaultLocation,
        quantity: quantity ?? this.quantity,
        notes: notes ?? this.notes,
        addedBy: addedBy,
        addedByName: addedByName,
        purchased: purchased ?? this.purchased,
        purchasedAt: purchasedAt ?? this.purchasedAt,
        createdAt: createdAt,
      );
}
