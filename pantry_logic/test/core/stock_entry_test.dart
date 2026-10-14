import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_logic/core/quantity.dart';
import 'package:pantry_logic/core/stock_entry.dart';

void main() {
  group('parseStockEntry', () {
    test('quantity before or after the name', () {
      for (final input in ['milk 2', '2 milk', '2x milk', 'milk x2',
          '2 x milk', 'milk x 2', '2X Milk', 'milk ×2']) {
        final e = parseStockEntry(input)!;
        expect(e.name.toLowerCase(), 'milk', reason: input);
        expect(e.quantity, 2, reason: input);
      }
    });

    test('no number means no quantity', () {
      expect(parseStockEntry('milk'), const StockEntry('milk'));
      expect(parseStockEntry('  greek   yogurt '),
          const StockEntry('greek yogurt'));
    });

    test('numbers inside names are left alone', () {
      expect(parseStockEntry('2% milk'), const StockEntry('2% milk'));
      expect(parseStockEntry('vitamin B12'), const StockEntry('vitamin B12'));
      expect(parseStockEntry('2 xylitol gum'),
          const StockEntry('xylitol gum', 2));
    });

    test('multi-word names keep their quantity', () {
      expect(parseStockEntry('chicken thighs 4'),
          const StockEntry('chicken thighs', 4));
      expect(parseStockEntry('3 cans tomatoes'),
          const StockEntry('cans tomatoes', 3));
    });

    test('zero quantity and bare numbers', () {
      expect(parseStockEntry('milk 0'), const StockEntry('milk'));
      expect(parseStockEntry('42'), const StockEntry('42'));
      expect(parseStockEntry('   '), isNull);
    });
  });

  group('parseStockEntries', () {
    test('splits on commas and newlines', () {
      expect(parseStockEntries('milk, eggs 12,bread'), const [
        StockEntry('milk'),
        StockEntry('eggs', 12),
        StockEntry('bread'),
      ]);
      expect(parseStockEntries('milk\n2 eggs\r\n\n, ,butter'), const [
        StockEntry('milk'),
        StockEntry('eggs', 2),
        StockEntry('butter'),
      ]);
    });
  });

  group('isSteppableQuantity', () {
    test('empty and plain decimals are steppable', () {
      expect(isSteppableQuantity(null), isTrue);
      expect(isSteppableQuantity(''), isTrue);
      expect(isSteppableQuantity(' 3 '), isTrue);
      expect(isSteppableQuantity('1.5'), isTrue);
      expect(isSteppableQuantity('.5'), isTrue);
    });

    test('fractions and units are not', () {
      expect(isSteppableQuantity('1/2'), isFalse);
      expect(isSteppableQuantity('½'), isFalse);
      expect(isSteppableQuantity('500 ml'), isFalse);
      expect(isSteppableQuantity('-1'), isFalse);
    });
  });
}
