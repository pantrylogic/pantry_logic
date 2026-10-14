import 'item_name.dart';

/// One item parsed from the fast stock-entry field.
class StockEntry {
  final String name;

  /// Whole-number quantity, or null when none was typed.
  final int? quantity;

  const StockEntry(this.name, [this.quantity]);

  @override
  bool operator ==(Object other) =>
      other is StockEntry && other.name == name && other.quantity == quantity;

  @override
  int get hashCode => Object.hash(name, quantity);

  @override
  String toString() => 'StockEntry($name, $quantity)';
}

// "2 milk", "2x milk", "2 x milk"
final RegExp _leadingQty = RegExp(r'^(\d+)\s*[x×]?\s+(.+)$', caseSensitive: false);
// "milk 2", "milk x2", "milk x 2"
final RegExp _trailingQty = RegExp(r'^(.+?)\s+[x×]?\s*(\d+)$', caseSensitive: false);

/// Splits [input] on commas and newlines and parses a quantity from each
/// part: `milk 2`, `2 milk`, `2x milk` and `milk x2` all become
/// ("milk", 2). Parts without a number get a null quantity; empty parts
/// are dropped. A quantity of 0 is treated as "no quantity".
List<StockEntry> parseStockEntries(String input) {
  final entries = <StockEntry>[];
  for (final raw in input.split(RegExp(r'[,\n\r]'))) {
    final entry = parseStockEntry(raw);
    if (entry != null) entries.add(entry);
  }
  return entries;
}

/// Parses a single part (no commas/newlines). Returns null when empty.
StockEntry? parseStockEntry(String raw) {
  final text = normalizeItemName(raw);
  if (text.isEmpty) return null;

  for (final (re, qtyGroup, nameGroup) in [
    (_leadingQty, 1, 2),
    (_trailingQty, 2, 1),
  ]) {
    final m = re.firstMatch(text);
    if (m == null) continue;
    final name = normalizeItemName(m.group(nameGroup)!);
    final qty = int.tryParse(m.group(qtyGroup)!);
    if (name.isEmpty || qty == null) continue;
    return StockEntry(name, qty > 0 ? qty : null);
  }
  return StockEntry(text);
}
