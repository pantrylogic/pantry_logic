// Quantity helpers.
//
// Quantities are stored as free text (inventory_items.quantity and
// grocery_items.quantity are `text` columns) so users can write "2",
// "500 ml" or "half a bag". These helpers are the single place that
// interprets them as numbers:
//
//   parseQuantity     raw text  → number (or null when not numeric)
//   serializeQuantity number    → raw text for storage ("2", "1.5")
//   formatQuantity    raw text  → display text ("½", "1¼", "500 ml")
//   mergeQuantities   combines two raw quantities (grocery check-off)

const Map<String, double> _unicodeFractions = {
  '¼': 0.25,
  '½': 0.5,
  '¾': 0.75,
  '⅓': 1 / 3,
  '⅔': 2 / 3,
};

// Fractions shown as glyphs. The tolerance means a stored "0.333" shows
// as ⅓ while a user-typed "0.33" stays "0.33".
const List<(double, String)> _displayFractions = [
  (0.25, '¼'),
  (0.5, '½'),
  (0.75, '¾'),
  (1 / 3, '⅓'),
  (2 / 3, '⅔'),
];
const double _fractionTolerance = 0.002;

final RegExp _simpleFraction = RegExp(r'^(\d+)\s*/\s*(\d+)$');
final RegExp _mixedFraction = RegExp(r'^(\d+)\s+(\d+)\s*/\s*(\d+)$');
final RegExp _unicodeMixed = RegExp(r'^(\d*)\s*([¼½¾⅓⅔])$');

/// Parses a stored quantity into a number.
///
/// Accepts plain decimals ("2", ".5", "1.25"), ASCII fractions ("1/2",
/// "1 1/2") and unicode fractions ("½", "1½"). Returns null for anything
/// else — including text with units such as "500 ml".
double? parseQuantity(String? raw) {
  final s = raw?.trim() ?? '';
  if (s.isEmpty) return null;

  final plain = double.tryParse(s);
  if (plain != null) return plain.isFinite ? plain : null;

  final mixed = _mixedFraction.firstMatch(s);
  if (mixed != null) {
    final den = int.parse(mixed.group(3)!);
    if (den == 0) return null;
    return int.parse(mixed.group(1)!) + int.parse(mixed.group(2)!) / den;
  }

  final simple = _simpleFraction.firstMatch(s);
  if (simple != null) {
    final den = int.parse(simple.group(2)!);
    if (den == 0) return null;
    return int.parse(simple.group(1)!) / den;
  }

  final uni = _unicodeMixed.firstMatch(s);
  if (uni != null) {
    final whole = uni.group(1)!.isEmpty ? 0 : int.parse(uni.group(1)!);
    return whole + _unicodeFractions[uni.group(2)!]!;
  }

  return null;
}

/// Converts a number to the raw text we store: whole numbers without a
/// decimal point, otherwise up to three decimals with trailing zeros
/// trimmed ("1.5", "0.333").
String serializeQuantity(double value) {
  final rounded = (value * 1000).roundToDouble() / 1000;
  if (rounded == rounded.truncateToDouble()) {
    return rounded.toInt().toString();
  }
  var text = rounded.toStringAsFixed(3);
  text = text.replaceFirst(RegExp(r'0+$'), '');
  return text.replaceFirst(RegExp(r'\.$'), '');
}

/// Display-only formatting for a stored quantity.
///
/// ".5"/"0.5" → "½", "1.0" → "1", "1.25" → "1¼". Non-numeric text is
/// returned trimmed and otherwise unchanged. Null/empty → "".
String formatQuantity(String? raw) {
  final s = raw?.trim() ?? '';
  if (s.isEmpty) return '';
  final value = parseQuantity(s);
  if (value == null || value < 0) return s;

  final whole = value.truncate();
  final frac = value - whole;
  if (frac.abs() < _fractionTolerance) return whole.toString();

  for (final (target, glyph) in _displayFractions) {
    if ((frac - target).abs() < _fractionTolerance) {
      return whole == 0 ? glyph : '$whole$glyph';
    }
  }
  return serializeQuantity(value);
}

/// Merges two stored quantities (used when a grocery item is checked off
/// into inventory). Numeric values are summed; otherwise the existing
/// value wins, falling back to the incoming one.
String? mergeQuantities(String? existing, String? incoming) {
  final inc = incoming?.trim() ?? '';
  final ex = existing?.trim() ?? '';
  if (inc.isEmpty) return ex.isEmpty ? existing : ex;
  if (ex.isEmpty) return inc;

  final exNum = parseQuantity(ex);
  final incNum = parseQuantity(inc);
  if (exNum != null && incNum != null) {
    return serializeQuantity(exNum + incNum);
  }
  // Non-numeric: keep existing (item was already in stock with a label).
  return ex;
}

final RegExp _plainDecimal = RegExp(r'^\d*\.?\d+$');

/// Whether the +/− stepper can adjust this stored quantity: empty, or a
/// plain non-negative decimal ("2", "1.5"). Fractions and text with units
/// are edited from the item sheet instead. Must match the parsing in the
/// `adjust_quantity` SQL function.
bool isSteppableQuantity(String? raw) {
  final s = raw?.trim() ?? '';
  return s.isEmpty || _plainDecimal.hasMatch(s);
}
