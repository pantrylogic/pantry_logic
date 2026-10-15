import '../core/quantity.dart';

enum MealConsumptionDisposition {
  deduct,
  notTracked,
  checkQuantity,
  shortage,
  absent,
}

class MealConsumptionItem {
  final String itemId;
  final String itemName;
  final int? requiredQuantity;
  final String? inventoryId;
  final String? inventoryQuantity;
  final String? inventoryUpdatedAt;
  final MealConsumptionDisposition disposition;
  final double? resultingQuantity;

  const MealConsumptionItem({
    required this.itemId,
    required this.itemName,
    required this.requiredQuantity,
    required this.inventoryId,
    required this.inventoryQuantity,
    required this.inventoryUpdatedAt,
    required this.disposition,
    this.resultingQuantity,
  });

  factory MealConsumptionItem.plan({
    required String itemId,
    required String itemName,
    required int? requiredQuantity,
    String? inventoryId,
    String? inventoryQuantity,
    String? inventoryUpdatedAt,
  }) {
    if (requiredQuantity == null) {
      return MealConsumptionItem(
        itemId: itemId,
        itemName: itemName,
        requiredQuantity: null,
        inventoryId: inventoryId,
        inventoryQuantity: inventoryQuantity,
        inventoryUpdatedAt: inventoryUpdatedAt,
        disposition: MealConsumptionDisposition.notTracked,
      );
    }
    if (inventoryId == null) {
      return MealConsumptionItem(
        itemId: itemId,
        itemName: itemName,
        requiredQuantity: requiredQuantity,
        inventoryId: null,
        inventoryQuantity: null,
        inventoryUpdatedAt: null,
        disposition: MealConsumptionDisposition.absent,
      );
    }
    // The RPC deliberately accepts only the existing decimal/stepper format.
    final quantity = isSteppableQuantity(inventoryQuantity)
        ? parseQuantity(inventoryQuantity)
        : null;
    if (quantity == null) {
      return MealConsumptionItem(
        itemId: itemId,
        itemName: itemName,
        requiredQuantity: requiredQuantity,
        inventoryId: inventoryId,
        inventoryQuantity: inventoryQuantity,
        inventoryUpdatedAt: inventoryUpdatedAt,
        disposition: MealConsumptionDisposition.checkQuantity,
      );
    }
    if (quantity < requiredQuantity) {
      return MealConsumptionItem(
        itemId: itemId,
        itemName: itemName,
        requiredQuantity: requiredQuantity,
        inventoryId: inventoryId,
        inventoryQuantity: inventoryQuantity,
        inventoryUpdatedAt: inventoryUpdatedAt,
        disposition: MealConsumptionDisposition.shortage,
      );
    }
    return MealConsumptionItem(
      itemId: itemId,
      itemName: itemName,
      requiredQuantity: requiredQuantity,
      inventoryId: inventoryId,
      inventoryQuantity: inventoryQuantity,
      inventoryUpdatedAt: inventoryUpdatedAt,
      disposition: MealConsumptionDisposition.deduct,
      resultingQuantity: quantity - requiredQuantity,
    );
  }

  Map<String, dynamic> get expectation => {
    'item_id': itemId,
    'inventory_id': inventoryId,
    'quantity': inventoryQuantity,
    'updated_at': inventoryUpdatedAt,
  };
}

class MealConsumptionPreview {
  final List<MealConsumptionItem> items;
  const MealConsumptionPreview(this.items);
  int get deductions => items
      .where((item) => item.disposition == MealConsumptionDisposition.deduct)
      .length;
}
