import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/ingredient_availability.dart';
import '../models/meal_category.dart';
import '../models/meal_consumption.dart';
import '../models/suggested_meal.dart';

class HungryService {
  static final _client = Supabase.instance.client;

  Future<List<MealCategory>> getCategories() async {
    final rows = await _client
        .from('meal_categories')
        .select()
        .order('sort_order', ascending: true)
        .order('name', ascending: true);
    return rows.map(MealCategory.fromJson).toList();
  }

  Future<List<SuggestedMeal>> getSuggestions(String categoryId) async {
    final mealRows = await _client
        .from('meals')
        .select(
          'id, name, category_id, meal_categories(name), '
          'meal_need_list(item_id, required_quantity, items(name))',
        )
        .eq('category_id', categoryId)
        .order('name');
    final inventoryRows = await _client
        .from('inventory_items')
        .select('item_id, quantity');
    final quantities = {
      for (final row in inventoryRows)
        row['item_id'] as String: row['quantity'] as String?,
    };
    final meals = mealRows.map((row) {
      final needs = row['meal_need_list'] as List<dynamic>? ?? [];
      final entries = needs
          .map(
            (need) => (
              need: need,
              availability: calculateIngredientAvailability(
                isInInventory: quantities.containsKey(need['item_id']),
                requiredQuantity: need['required_quantity'] as int?,
                inventoryQuantity: quantities[need['item_id']],
              ),
            ),
          )
          .toList();
      final summary = MealAvailabilitySummary.fromIngredients(
        entries.map((entry) => entry.availability),
      );
      return SuggestedMeal(
        id: row['id'] as String,
        name: row['name'] as String,
        categoryId: row['category_id'] as String?,
        categoryName:
            (row['meal_categories'] as Map<String, dynamic>?)?['name']
                as String?,
        needCount: summary.needCount,
        missingCount: summary.missingCount,
        unknownCount: summary.unknownCount,
        missingItemNames: entries
            .where((entry) => entry.availability.isMissing)
            .map(
              (entry) =>
                  (entry.need['items'] as Map<String, dynamic>)['name']
                      as String,
            )
            .toList(),
        unknownItemNames: entries
            .where((entry) => entry.availability.isUnknown)
            .map(
              (entry) =>
                  (entry.need['items'] as Map<String, dynamic>)['name']
                      as String,
            )
            .toList(),
      );
    }).toList();
    final ready =
        meals.where((meal) => meal.allInPantry || !meal.hasNeedList).toList()
          ..shuffle();
    final notReady =
        meals.where((meal) => !meal.allInPantry && meal.hasNeedList).toList()
          ..shuffle();
    return [...ready, ...notReady];
  }

  /// Builds a read-only consumption preview; it never changes inventory.
  Future<MealConsumptionPreview> getConsumptionPreview(String mealId) async {
    final needs = await _client
        .from('meal_need_list')
        .select('item_id, required_quantity, items(name)')
        .eq('meal_id', mealId);
    final itemIds = needs.map((row) => row['item_id'] as String).toList();
    if (itemIds.isEmpty) return const MealConsumptionPreview([]);
    final inventoryRows = await _client
        .from('inventory_items')
        .select('id, item_id, quantity, updated_at')
        .inFilter('item_id', itemIds);
    final inventory = {
      for (final row in inventoryRows) row['item_id'] as String: row,
    };
    return MealConsumptionPreview(
      needs.map((need) {
        final stock = inventory[need['item_id'] as String];
        return MealConsumptionItem.plan(
          itemId: need['item_id'] as String,
          itemName: (need['items'] as Map<String, dynamic>)['name'] as String,
          requiredQuantity: need['required_quantity'] as int?,
          inventoryId: stock?['id'] as String?,
          inventoryQuantity: stock?['quantity'] as String?,
          inventoryUpdatedAt: stock?['updated_at'] as String?,
        );
      }).toList(),
    );
  }

  Future<Map<String, dynamic>> consumeMeal(
    String mealId,
    MealConsumptionPreview preview, {
    required String operationId,
  }) async {
    final result = await _client.rpc(
      'consume_meal_ingredients',
      params: {
        'p_meal_id': mealId,
        'p_operation_id': operationId,
        'p_expected': preview.items
            .where((item) => item.requiredQuantity != null)
            .map((item) => item.expectation)
            .toList(),
      },
    );
    return Map<String, dynamic>.from(result as Map);
  }

  static String newConsumptionOperationId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
