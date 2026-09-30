import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_logic/core/quantity.dart';

void main() {
  group('parseQuantity', () {
    test('plain numbers and decimals', () {
      expect(parseQuantity('2'), 2);
      expect(parseQuantity(' 1.5 '), 1.5);
      expect(parseQuantity('.5'), 0.5);
      expect(parseQuantity('0.25'), 0.25);
    });

    test('ascii and unicode fractions', () {
      expect(parseQuantity('1/2'), 0.5);
      expect(parseQuantity('1 1/2'), 1.5);
      expect(parseQuantity('½'), 0.5);
      expect(parseQuantity('2¾'), 2.75);
      expect(parseQuantity('1/0'), isNull);
    });

    test('non-numeric returns null', () {
      expect(parseQuantity(null), isNull);
      expect(parseQuantity(''), isNull);
      expect(parseQuantity('500 ml'), isNull);
      expect(parseQuantity('half a bag'), isNull);
      expect(parseQuantity('NaN'), isNull);
    });
  });

  group('serializeQuantity', () {
    test('whole numbers drop the decimal', () {
      expect(serializeQuantity(2), '2');
      expect(serializeQuantity(1.0), '1');
    });

    test('fractions keep up to three decimals', () {
      expect(serializeQuantity(1.5), '1.5');
      expect(serializeQuantity(0.25), '0.25');
      expect(serializeQuantity(1 / 3), '0.333');
    });
  });

  group('formatQuantity', () {
    test('halves and quarters become glyphs', () {
      expect(formatQuantity('.5'), '½');
      expect(formatQuantity('0.5'), '½');
      expect(formatQuantity('1.5'), '1½');
      expect(formatQuantity('0.25'), '¼');
      expect(formatQuantity('2.75'), '2¾');
    });

    test('thirds only when exact to storage precision', () {
      expect(formatQuantity('0.333'), '⅓');
      expect(formatQuantity('1.667'), '1⅔');
      expect(formatQuantity('1/3'), '⅓');
      expect(formatQuantity('0.33'), '0.33');
    });

    test('whole numbers are trimmed', () {
      expect(formatQuantity('1.0'), '1');
      expect(formatQuantity('3'), '3');
    });

    test('other decimals pass through normalized', () {
      expect(formatQuantity('1.2'), '1.2');
      expect(formatQuantity('1.20'), '1.2');
    });

    test('non-numeric passes through unchanged', () {
      expect(formatQuantity('500 ml'), '500 ml');
      expect(formatQuantity('  half a bag '), 'half a bag');
      expect(formatQuantity(null), '');
      expect(formatQuantity(''), '');
    });
  });

  group('mergeQuantities', () {
    test('sums numeric quantities', () {
      expect(mergeQuantities('1', '2'), '3');
      expect(mergeQuantities('1', '.5'), '1.5');
      expect(mergeQuantities('½', '1'), '1.5');
    });

    test('missing side falls back to the other', () {
      expect(mergeQuantities(null, '2'), '2');
      expect(mergeQuantities('2', null), '2');
      expect(mergeQuantities('2', ''), '2');
      expect(mergeQuantities(null, null), isNull);
    });

    test('non-numeric keeps the existing value', () {
      expect(mergeQuantities('half a bag', '2'), 'half a bag');
      expect(mergeQuantities('2', '500 ml'), '2');
    });
  });
}
