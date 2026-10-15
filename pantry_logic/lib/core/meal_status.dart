import 'package:flutter/material.dart';

import 'theme.dart';

enum MealStatusKind {
  /// The meal has no ingredients listed.
  noIngredients,

  /// Every ingredient is in stock.
  ready,

  /// One or more ingredients are missing.
  missing,

  /// A count-based ingredient has no usable numeric inventory quantity.
  unknownQuantity,
}

/// Single source of truth for turning a meal's ingredient counts into a
/// status: kind, label, icon and colours.
class MealStatus {
  final int needCount;
  final int missingCount;
  final int unknownCount;

  const MealStatus({
    required this.needCount,
    required this.missingCount,
    this.unknownCount = 0,
  });

  MealStatusKind get kind {
    if (needCount <= 0) return MealStatusKind.noIngredients;
    if (missingCount > 0) return MealStatusKind.missing;
    if (unknownCount > 0) return MealStatusKind.unknownQuantity;
    if (missingCount <= 0) return MealStatusKind.ready;
    return MealStatusKind.missing;
  }

  bool get isReady => kind == MealStatusKind.ready;
  bool get hasIngredients => kind != MealStatusKind.noIngredients;

  /// Short label, e.g. "All in stock", "2 missing", "No ingredients".
  String get label => switch (kind) {
    MealStatusKind.noIngredients => 'No ingredients',
    MealStatusKind.ready => 'All in stock',
    MealStatusKind.missing =>
      unknownCount > 0
          ? '$missingCount missing · $unknownCount check'
          : '$missingCount missing',
    MealStatusKind.unknownQuantity => 'Check quantity',
  };

  /// Longer label for cards, e.g. "2 ingredients missing".
  String get longLabel => switch (kind) {
    MealStatusKind.noIngredients => 'No ingredients listed',
    MealStatusKind.ready => 'All ingredients in stock',
    MealStatusKind.missing =>
      '$missingCount ingredient${missingCount == 1 ? '' : 's'} missing',
    MealStatusKind.unknownQuantity =>
      'Check ingredient quantit${unknownCount == 1 ? 'y' : 'ies'}',
  };

  IconData get icon => switch (kind) {
    MealStatusKind.noIngredients => Icons.format_list_bulleted_rounded,
    MealStatusKind.ready => Icons.check_circle_rounded,
    MealStatusKind.missing => Icons.error_outline_rounded,
    MealStatusKind.unknownQuantity => Icons.help_outline_rounded,
  };

  /// Colour for text and icons (meets 4.5:1 contrast).
  Color textColor(AppPalette p) => switch (kind) {
    MealStatusKind.noIngredients => p.textMuted,
    MealStatusKind.ready => p.successText,
    MealStatusKind.missing => p.warningText,
    MealStatusKind.unknownQuantity => p.warningText,
  };

  /// Colour for non-text indicators such as status dots.
  Color dotColor(AppPalette p) => switch (kind) {
    MealStatusKind.noIngredients => p.hint,
    MealStatusKind.ready => p.success,
    MealStatusKind.missing => p.warning,
    MealStatusKind.unknownQuantity => p.warning,
  };
}

/// Status of a single ingredient row.
class IngredientStatus {
  /// Location the item is stored in, or null when it's not in stock.
  final String? location;

  const IngredientStatus(this.location);

  bool get inStock => location != null;

  /// "In stock · Fridge" or "Missing".
  String get label => inStock ? 'In stock · $location' : 'Missing';

  IconData get icon =>
      inStock ? Icons.check_circle_rounded : Icons.error_outline_rounded;

  Color color(AppPalette p) => inStock ? p.successText : p.warningText;
}
