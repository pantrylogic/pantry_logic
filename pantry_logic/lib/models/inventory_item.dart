class InventoryItem {
  final String id;
  final String householdId;
  final String itemId;
  final String itemName;
  final String location;
  final String? quantity;
  final String? notes;
  final DateTime updatedAt;

  const InventoryItem({
    required this.id,
    required this.householdId,
    required this.itemId,
    required this.itemName,
    required this.location,
    this.quantity,
    this.notes,
    required this.updatedAt,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    final item = json['items'] as Map<String, dynamic>?;
    return InventoryItem(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      itemId: json['item_id'] as String,
      itemName: item?['name'] as String? ?? '',
      location: json['location'] as String? ?? 'Pantry',
      quantity: json['quantity'] as String?,
      notes: json['notes'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// Thrown when attempting to add an item that's already in the pantry.
class AlreadyInPantryException implements Exception {
  final String itemName;
  const AlreadyInPantryException(this.itemName);
}
