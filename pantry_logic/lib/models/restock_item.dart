/// Why this item appears in the restock prompt.
enum RestockReason {
  /// Was in inventory with a numeric quantity; auto-reduced to ≤ 0.
  /// The inventory entry has already been deleted before this is returned.
  hitZero,

  /// Is in inventory but has no parseable numeric quantity.
  /// User must decide: "Add to list" or "Still have some".
  noQuantity,
}

/// An item the user needs to act on after tapping "Eat This".
class RestockDecisionItem {
  final String itemId;
  final String itemName;
  final RestockReason reason;

  const RestockDecisionItem({
    required this.itemId,
    required this.itemName,
    required this.reason,
  });
}
