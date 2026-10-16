import '../core/ingredient_availability.dart';

class MealNeedItem {
  final String mealId;
  final String itemId;
  final String itemName;
  final String? originalIngredientText;
  final String? sourceMarkdown;
  final int? ingredientPosition;

  /// Non-null when the item is currently in the pantry (shows the location).
  final String? inventoryLocation;
  final String? inventoryQuantity;
  final int? requiredQuantity;

  bool get inPantry => inventoryLocation != null;

  IngredientAvailability get availability => calculateIngredientAvailability(
    isInInventory: inPantry,
    requiredQuantity: requiredQuantity,
    inventoryQuantity: inventoryQuantity,
  );

  const MealNeedItem({
    required this.mealId,
    required this.itemId,
    required this.itemName,
    this.originalIngredientText,
    this.sourceMarkdown,
    this.ingredientPosition,
    this.inventoryLocation,
    this.inventoryQuantity,
    this.requiredQuantity,
  });
}
