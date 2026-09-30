import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_logic/core/like.dart';
import 'package:pantry_logic/core/locations.dart';

void main() {
  test('built-in locations use the fixed order, custom ones follow A→Z', () {
    expect(
      sortLocationNames(
          ['Pantry', 'garage', 'Deep Freeze', 'Basement', 'Fridge', 'Freezer']),
      ['Fridge', 'Freezer', 'Deep Freeze', 'Pantry', 'Basement', 'garage'],
    );
  });

  test('duplicates are removed', () {
    expect(sortLocationNames(['Pantry', 'Pantry', 'Fridge']),
        ['Fridge', 'Pantry']);
  });

  test('escapeLike makes wildcards literal', () {
    expect(escapeLike('50% off_brand'), r'50\% off\_brand');
    expect(escapeLike(r'a\b'), r'a\\b');
    expect(escapeLike('Milk'), 'Milk');
  });
}
