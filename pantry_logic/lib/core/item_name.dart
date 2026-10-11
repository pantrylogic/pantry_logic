/// Normalizes a user-entered item name: trims and collapses inner whitespace.
/// Case is kept for display; uniqueness is case-insensitive in the DB
/// (`items_household_lower_name` index).
String normalizeItemName(String input) =>
    input.trim().replaceAll(RegExp(r'\s+'), ' ');
