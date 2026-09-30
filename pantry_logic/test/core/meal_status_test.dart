import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_logic/core/meal_status.dart';
import 'package:pantry_logic/core/theme.dart';

void main() {
  const light = AppPalette(false);

  test('no ingredients', () {
    const s = MealStatus(needCount: 0, missingCount: 0);
    expect(s.kind, MealStatusKind.noIngredients);
    expect(s.hasIngredients, isFalse);
    expect(s.label, 'No ingredients');
    expect(s.textColor(light), AppColors.textMuted);
  });

  test('all in stock', () {
    const s = MealStatus(needCount: 3, missingCount: 0);
    expect(s.kind, MealStatusKind.ready);
    expect(s.isReady, isTrue);
    expect(s.label, 'All in stock');
    expect(s.icon, Icons.check_circle_rounded);
    expect(s.textColor(light), AppColors.successText);
  });

  test('missing items', () {
    const one = MealStatus(needCount: 3, missingCount: 1);
    const two = MealStatus(needCount: 3, missingCount: 2);
    expect(one.kind, MealStatusKind.missing);
    expect(one.label, '1 missing');
    expect(one.longLabel, '1 ingredient missing');
    expect(two.longLabel, '2 ingredients missing');
    expect(two.textColor(light), AppColors.warningText);
    expect(two.dotColor(light), AppColors.warning);
  });

  test('ingredient status label never says "In pantry"', () {
    expect(const IngredientStatus('Pantry').label, 'In stock · Pantry');
    expect(const IngredientStatus(null).label, 'Missing');
    expect(const IngredientStatus(null).inStock, isFalse);
  });
}
