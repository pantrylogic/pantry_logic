class InventoryItem {
  final String id;
  final String householdId;
  final String itemId;
  final String itemName;
  final String location;
  final String? quantity;
  final String? notes;
  final String? addedBy;
  final String? addedByName;
  final DateTime updatedAt;

  const InventoryItem({
    required this.id,
    required this.householdId,
    required this.itemId,
    required this.itemName,
    required this.location,
    this.quantity,
    this.notes,
    this.addedBy,
    this.addedByName,
    required this.updatedAt,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    final item = json['items'] as Map<String, dynamic>?;
    final profile = json['profiles'] as Map<String, dynamic>?;
    return InventoryItem(
      id: json['id'] as String,
      householdId: json['household_id'] as String,
      itemId: json['item_id'] as String,
      itemName: item?['name'] as String? ?? '',
      location: json['location'] as String? ?? 'Pantry',
      quantity: json['quantity'] as String?,
      notes: json['notes'] as String?,
      addedBy: json['added_by'] as String?,
      addedByName: profile?['display_name'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

/// What [InventoryService.addOrMergeStock] did, so it can be undone.
class StockAddResult {
  final String inventoryItemId;

  /// Where the item is stored (an existing row keeps its location).
  final String location;

  /// A new stock row was inserted.
  final bool created;

  /// Quantity added to an existing numeric (or empty) quantity.
  final int? addedDelta;

  /// The existing quantity was empty before [addedDelta] was added.
  final bool wasEmpty;

  /// An existing non-plain quantity (e.g. "½") was overwritten with a
  /// merged value; [replacedQuantity] is the old text.
  final bool replaced;
  final String? replacedQuantity;

  const StockAddResult({
    required this.inventoryItemId,
    required this.location,
    this.created = false,
    this.addedDelta,
    this.wasEmpty = false,
    this.replaced = false,
    this.replacedQuantity,
  });
}

/// Thrown when attempting to add an item that's already in stock.
class AlreadyInPantryException implements Exception {
  final String itemName;
  const AlreadyInPantryException(this.itemName);
}

/// Thrown when a stock row was already removed (e.g. by another member).
class StockItemGoneException implements Exception {
  const StockItemGoneException();
}

/// Thrown when renaming an item to a name the household already uses.
class ItemNameTakenException implements Exception {
  final String name;
  const ItemNameTakenException(this.name);
}
