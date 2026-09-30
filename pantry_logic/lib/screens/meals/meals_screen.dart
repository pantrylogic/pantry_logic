import 'package:flutter/material.dart';

import '../../core/meal_status.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/meal.dart';
import '../../models/meal_category.dart';
import '../../services/meal_service.dart';
import '../../widgets/add_bar.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/brand.dart';
import '../../widgets/category_picker_sheet.dart';
import '../../widgets/confirm_dialog.dart';
import '../shell/shell_controller.dart';
import 'meal_detail_screen.dart';

class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> with TabActivation {
  final _service = MealService();
  late final Stream<List<Meal>> _stream;
  List<MealCategory> _categories = [];

  /// Meals removed optimistically after a confirmed swipe-delete.
  final Set<String> _hiddenIds = {};

  @override
  int get tabIndex => ShellTab.meals;

  @override
  void onTabActivated() => _loadCategories();

  @override
  void initState() {
    super.initState();
    _stream = _service.streamMeals().asBroadcastStream();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _service.getCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (e, st) {
      logError('Load meal categories', e, st);
    }
  }

  /// New meals always get a category so the Hungry flow can suggest them.
  Future<void> _createMeal(String name) async {
    final messenger = ScaffoldMessenger.of(context);
    if (_categories.isEmpty) await _loadCategories();
    if (!mounted) return;
    if (_categories.isEmpty) {
      showAppSnackBar(
          messenger, 'Add a meal category in Settings before adding meals.');
      return;
    }

    final categoryId = await showCategoryPicker(
      context,
      categories: _categories,
      title: 'What kind of meal is "$name"?',
      confirmLabel: 'Add meal',
    );
    if (categoryId == null) return;

    try {
      await _service.addMeal(name: name, categoryId: categoryId);
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not add $name. Try again.', e, st);
    }
  }

  Future<void> _deleteMeal(Meal meal) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _hiddenIds.add(meal.id));
    try {
      await _service.deleteMeal(meal.id);
    } catch (e, st) {
      if (mounted) setState(() => _hiddenIds.remove(meal.id));
      showErrorSnackBar(messenger, 'Could not delete ${meal.name}.', e, st);
    }
  }

  void _openMeal(Meal meal) {
    Navigator.of(context).push(MaterialPageRoute(
      settings: AppRoutes.settings(AppRoutes.mealDetail),
      builder: (_) => MealDetailScreen(meal: meal),
    ));
  }

  List<Widget> _buildItems(List<Meal> meals, AppPalette p) {
    final order = {for (final c in _categories) c.id: c.sortOrder};

    final grouped = <String?, List<Meal>>{};
    for (final meal in meals) {
      (grouped[meal.categoryId] ??= []).add(meal);
    }

    // Categories by sort_order; uncategorized (older meals) last.
    final keys = grouped.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return (order[a] ?? 999).compareTo(order[b] ?? 999);
      });

    final widgets = <Widget>[];
    for (final catId in keys) {
      final group = grouped[catId]!
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      final label = catId != null
          ? (group.first.categoryName ?? 'Other')
          : 'Uncategorized';

      widgets.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Text(
          label.toUpperCase(),
          style: nsSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: p.textMuted,
          ),
        ),
      ));

      for (var i = 0; i < group.length; i++) {
        final meal = group[i];
        final status = MealStatus(
          needCount: meal.needCount,
          missingCount: meal.missingCount,
        );
        final statusColor = status.textColor(p);

        widgets.add(Dismissible(
          key: ValueKey(meal.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: p.error.withValues(alpha: 0.12),
            child: Icon(Icons.delete_outline_rounded, color: p.error, size: 22),
          ),
          confirmDismiss: (_) => confirmDeleteMeal(context, meal.name),
          onDismissed: (_) => _deleteMeal(meal),
          child: InkWell(
            onTap: () => _openMeal(meal),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          meal.name,
                          style: nsSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(status.icon, size: 14, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              status.label,
                              style: nsSans(fontSize: 12, color: statusColor),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: p.textMuted),
                ],
              ),
            ),
          ),
        ));

        if (i < group.length - 1) {
          widgets.add(
            Divider(height: 1, indent: 16, endIndent: 16, color: p.border),
          );
        }
      }
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Meals')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Meal>>(
              stream: _stream,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final meals = (snap.data ?? [])
                    .where((m) => !_hiddenIds.contains(m.id))
                    .toList();
                if (meals.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const IconBadge(Icons.restaurant_menu_rounded),
                          const SizedBox(height: 16),
                          Text(
                            'Add meals your household likes',
                            textAlign: TextAlign.center,
                            style: nsSans(
                              fontSize: 16,
                              color: p.textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add ingredients to a meal to see what\'s\n'
                            'missing and add it to your grocery list.',
                            textAlign: TextAlign.center,
                            style: nsSans(
                              fontSize: 14,
                              color: p.textMuted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.only(bottom: 8),
                  children: _buildItems(meals, p),
                );
              },
            ),
          ),
          AddBar(
            hintText: 'New meal…',
            keepFocusAfterSubmit: false,
            onSubmit: _createMeal,
          ),
        ],
      ),
    );
  }
}
