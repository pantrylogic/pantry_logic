import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_logic/models/meal_consumption.dart';

MealConsumptionItem plan({
  int? required,
  String? id = 'stock',
  String? quantity = '6',
}) => MealConsumptionItem.plan(
  itemId: 'item',
  itemName: 'Item',
  requiredQuantity: required,
  inventoryId: id,
  inventoryQuantity: quantity,
  inventoryUpdatedAt: '2026-10-16T00:00:00Z',
);

void main() {
  test('deducts the count required by a meal', () {
    expect(plan(required: 4).disposition, MealConsumptionDisposition.deduct);
    expect(plan(required: 4).resultingQuantity, 2);
    expect(plan(required: 2).resultingQuantity, 4);
  });

  test('exact depletion is a planned deduction', () {
    final item = plan(required: 6);
    expect(item.disposition, MealConsumptionDisposition.deduct);
    expect(item.resultingQuantity, 0);
  });

  test('presence-only requirements never deduct numeric stock', () {
    final item = plan(required: null, quantity: '6');
    expect(item.disposition, MealConsumptionDisposition.notTracked);
  });

  test('unknown, insufficient, and absent stock are skipped', () {
    expect(
      plan(required: 2, quantity: 'some').disposition,
      MealConsumptionDisposition.checkQuantity,
    );
    expect(
      plan(required: 4, quantity: '2').disposition,
      MealConsumptionDisposition.shortage,
    );
    expect(
      plan(required: 2, id: null, quantity: null).disposition,
      MealConsumptionDisposition.absent,
    );
  });

  test('expectations preserve the reviewed inventory version', () {
    final expectation = plan(required: 2).expectation;
    expect(expectation['inventory_id'], 'stock');
    expect(expectation['quantity'], '6');
    expect(expectation['updated_at'], '2026-10-16T00:00:00Z');
  });
}
