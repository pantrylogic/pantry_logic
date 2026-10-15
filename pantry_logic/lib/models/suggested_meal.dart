/// A meal returned by the Hungry suggestion engine.
class SuggestedMeal {
  final String id;
  final String name;
  final String? categoryId;
  final String? categoryName;

  /// Total items in the need list (0 = no need list).
  final int needCount;

  /// Items in the need list that are NOT currently in inventory.
  final int missingCount;
  final int unknownCount;

  /// Names of the missing items — used in the suggestion UI.
  final List<String> missingItemNames;
  final List<String> unknownItemNames;

  bool get hasNeedList => needCount > 0;
  bool get allInPantry =>
      needCount > 0 && missingCount == 0 && unknownCount == 0;

  const SuggestedMeal({
    required this.id,
    required this.name,
    this.categoryId,
    this.categoryName,
    required this.needCount,
    required this.missingCount,
    required this.unknownCount,
    required this.missingItemNames,
    required this.unknownItemNames,
  });
}
