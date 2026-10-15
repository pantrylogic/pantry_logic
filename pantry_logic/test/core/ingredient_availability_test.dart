import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_logic/core/ingredient_availability.dart';

void main() {
  IngredientAvailability availability({
    required bool inInventory,
    int? requiredQuantity,
    String? inventoryQuantity,
  }) => calculateIngredientAvailability(
    isInInventory: inInventory,
    requiredQuantity: requiredQuantity,
    inventoryQuantity: inventoryQuantity,
  );

  group('presence requirements', () {
    test('treats a numeric positive quantity as available', () {
      expect(
        availability(inInventory: true, inventoryQuantity: '1').isAvailable,
        isTrue,
      );
    });

    test('treats zero as missing', () {
      expect(
        availability(inInventory: true, inventoryQuantity: '0').isMissing,
        isTrue,
      );
    });
  });

  group('count requirements', () {
    test('reports chicken-breast shortages', () {
      final result = availability(
        inInventory: true,
        requiredQuantity: 4,
        inventoryQuantity: '2',
      );

      expect(result.isMissing, isTrue);
      expect(result.shortage, 2);
    });

    test('reports package shortages', () {
      final result = availability(
        inInventory: true,
        requiredQuantity: 2,
        inventoryQuantity: '1',
      );

      expect(result.isMissing, isTrue);
      expect(result.shortage, 1);
    });

    test('satisfies an equal available quantity', () {
      expect(
        availability(
          inInventory: true,
          requiredQuantity: 4,
          inventoryQuantity: '4',
        ).isAvailable,
        isTrue,
      );
    });

    test('reports the full requirement when inventory is absent', () {
      final result = availability(
        inInventory: false,
        requiredQuantity: 4,
        inventoryQuantity: null,
      );

      expect(result.isMissing, isTrue);
      expect(result.shortage, 4);
    });

    test('preserves fractional shortages without rounding', () {
      final result = availability(
        inInventory: true,
        requiredQuantity: 4,
        inventoryQuantity: '2.5',
      );

      expect(result.shortage, 1.5);
    });

    test('uses unknown status for blank and free-text quantities', () {
      expect(
        availability(
          inInventory: true,
          requiredQuantity: 2,
          inventoryQuantity: null,
        ).isUnknown,
        isTrue,
      );
      expect(
        availability(
          inInventory: true,
          requiredQuantity: 2,
          inventoryQuantity: 'half a bag',
        ).isUnknown,
        isTrue,
      );
    });
  });
}
