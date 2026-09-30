/// Storage location display order: the built-in locations in a fixed order,
/// then any custom locations alphabetically (case-insensitive).
const List<String> kDefaultLocationOrder = [
  'Fridge',
  'Freezer',
  'Deep Freeze',
  'Pantry',
];

int compareLocations(String a, String b) {
  final ia = kDefaultLocationOrder.indexOf(a);
  final ib = kDefaultLocationOrder.indexOf(b);
  if (ia != -1 || ib != -1) {
    if (ia == -1) return 1;
    if (ib == -1) return -1;
    return ia.compareTo(ib);
  }
  final ci = a.toLowerCase().compareTo(b.toLowerCase());
  return ci != 0 ? ci : a.compareTo(b);
}

/// Returns [names] de-duplicated and sorted with [compareLocations].
List<String> sortLocationNames(Iterable<String> names) =>
    names.toSet().toList()..sort(compareLocations);
