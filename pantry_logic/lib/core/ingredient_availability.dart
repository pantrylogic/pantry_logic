import 'quantity.dart';

enum IngredientAvailabilityKind { available, missing, unknownQuantity }

/// Availability for one meal ingredient.
///
/// A null requirement uses presence matching. A positive requirement uses a
/// numeric inventory quantity when one can be parsed. Free-text quantities
/// such as "half a bag" remain deliberately unknown rather than guessed.
class IngredientAvailability {
  final IngredientAvailabilityKind kind;
  final double? shortage;

  const IngredientAvailability._(this.kind, {this.shortage});

  const IngredientAvailability.available()
    : this._(IngredientAvailabilityKind.available);

  const IngredientAvailability.missing({double? shortage})
    : this._(IngredientAvailabilityKind.missing, shortage: shortage);

  const IngredientAvailability.unknownQuantity()
    : this._(IngredientAvailabilityKind.unknownQuantity);

  bool get isAvailable => kind == IngredientAvailabilityKind.available;
  bool get isMissing => kind == IngredientAvailabilityKind.missing;
  bool get isUnknown => kind == IngredientAvailabilityKind.unknownQuantity;
}

/// Shared summary used by meals, calendar entries and Hungry suggestions.
class MealAvailabilitySummary {
  final int needCount;
  final int missingCount;
  final int unknownCount;

  const MealAvailabilitySummary({
    required this.needCount,
    required this.missingCount,
    required this.unknownCount,
  });

  factory MealAvailabilitySummary.fromIngredients(
    Iterable<IngredientAvailability> ingredients,
  ) {
    final values = ingredients.toList(growable: false);
    return MealAvailabilitySummary(
      needCount: values.length,
      missingCount: values.where((value) => value.isMissing).length,
      unknownCount: values.where((value) => value.isUnknown).length,
    );
  }

  bool get isReady => needCount > 0 && missingCount == 0 && unknownCount == 0;
}

IngredientAvailability calculateIngredientAvailability({
  required bool isInInventory,
  required int? requiredQuantity,
  required String? inventoryQuantity,
}) {
  if (!isInInventory) {
    return IngredientAvailability.missing(
      shortage: requiredQuantity?.toDouble(),
    );
  }

  final availableQuantity = parseQuantity(inventoryQuantity);
  if (requiredQuantity == null) {
    if (availableQuantity != null && availableQuantity <= 0) {
      return const IngredientAvailability.missing();
    }
    return const IngredientAvailability.available();
  }

  if (availableQuantity == null) {
    return const IngredientAvailability.unknownQuantity();
  }
  if (availableQuantity >= requiredQuantity) {
    return const IngredientAvailability.available();
  }
  return IngredientAvailability.missing(
    shortage: requiredQuantity - availableQuantity,
  );
}
