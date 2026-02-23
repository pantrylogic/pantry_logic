class Item {
  final String id;
  final String householdId;
  final String name;
  final String? category;
  final String defaultLocation;

  const Item({
    required this.id,
    required this.householdId,
    required this.name,
    this.category,
    required this.defaultLocation,
  });

  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json['id'] as String,
        householdId: json['household_id'] as String,
        name: json['name'] as String,
        category: json['category'] as String?,
        defaultLocation: json['default_location'] as String? ?? 'Pantry',
      );
}

/// A suggestion returned by autocomplete search.
/// May come from the household's existing items table or the global dictionary.
class AutocompleteSuggestion {
  /// Non-null when this item already exists in the household's items table.
  final String? itemId;
  final String name;
  final String? category;
  final String defaultLocation;

  const AutocompleteSuggestion({
    this.itemId,
    required this.name,
    this.category,
    required this.defaultLocation,
  });

  bool get isHouseholdItem => itemId != null;
}
