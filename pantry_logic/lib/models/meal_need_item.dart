class MealNeedItem {
  final String mealId;
  final String itemId;
  final String itemName;

  /// Non-null when the item is currently in the pantry (shows the location).
  final String? inventoryLocation;

  bool get inPantry => inventoryLocation != null;

  const MealNeedItem({
    required this.mealId,
    required this.itemId,
    required this.itemName,
    this.inventoryLocation,
  });
}
