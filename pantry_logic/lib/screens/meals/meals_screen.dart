import 'package:flutter/material.dart';

import '../../core/meal_status.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/ui_prefs.dart';
import '../../models/meal.dart';
import '../../models/meal_category.dart';
import '../../services/meal_service.dart';
import '../../widgets/add_bar.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/brand.dart';
import '../../widgets/category_picker_sheet.dart';
import '../../widgets/collapsible_section_header.dart';
import '../../widgets/confirm_dialog.dart';
import '../shell/shell_controller.dart';
import 'manage_categories_sheet.dart';
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

  /// Latest meals from the stream, for per-category counts.
  List<Meal> _meals = [];

  /// Section keys (category ids, or [_uncategorizedKey]) the user collapsed.
  Set<String> _collapsed = {};
  static const _uncategorizedKey = '_uncategorized';

  @override
  int get tabIndex => ShellTab.meals;

  @override
  void onTabActivated() => _loadCategories();

  @override
  void initState() {
    super.initState();
    _stream = _service.streamMeals().asBroadcastStream();
    _loadCategories();
    UiPrefs.getStringSet(UiPrefs.mealsCollapsedCategories).then((saved) {
      if (mounted) setState(() => _collapsed = saved);
    });
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
        messenger,
        'Add a meal category (top right) before adding meals.',
      );
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
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: AppRoutes.settings(AppRoutes.mealDetail),
        builder: (_) => MealDetailScreen(meal: meal),
      ),
    );
  }

  Future<void> _toggleSection(String key) async {
    final next = {..._collapsed};
    if (!next.remove(key)) next.add(key);
    setState(() => _collapsed = next);
    await UiPrefs.setStringSet(UiPrefs.mealsCollapsedCategories, next);
  }

  Future<void> _manageCategories() async {
    final counts = <String, int>{};
    for (final m in _meals) {
      final id = m.categoryId;
      if (id != null) counts[id] = (counts[id] ?? 0) + 1;
    }
    await showManageCategoriesSheet(
      context,
      categories: _categories,
      mealCounts: counts,
    );
    await _loadCategories();
  }

  List<Widget> _buildItems(List<Meal> meals, AppPalette p) {
    final grouped = <String?, List<Meal>>{};
    for (final meal in meals) {
      // Meals whose category isn't loaded yet (or was just deleted) fall
      // into Uncategorized rather than vanishing.
      final known = _categories.any((c) => c.id == meal.categoryId);
      (grouped[known ? meal.categoryId : null] ??= []).add(meal);
    }

    // Every category gets a section (sort_order, then name — as loaded) so
    // new, empty ones are visible; uncategorized meals go last.
    final sections = <(String key, String title, List<Meal> meals)>[
      for (final c in _categories) (c.id, c.name, grouped[c.id] ?? []),
      if (grouped[null] != null)
        (_uncategorizedKey, 'Uncategorized', grouped[null]!),
    ];

    final widgets = <Widget>[];
    for (final (key, title, group) in sections) {
      group.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      final expanded = !_collapsed.contains(key);

      widgets.add(
        CollapsibleSectionHeader(
          title: title,
          count: group.length,
          expanded: expanded,
          onTap: () => _toggleSection(key),
        ),
      );
      if (!expanded) continue;

      widgets.add(
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: Column(
              children: [
                if (group.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No meals yet',
                        style: nsSans(fontSize: 14, color: p.textMuted),
                      ),
                    ),
                  ),
                for (var i = 0; i < group.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 16, color: p.border),
                  _mealRow(group[i], p),
                ],
              ],
            ),
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _mealRow(Meal meal, AppPalette p) {
    final status = MealStatus(
      needCount: meal.needCount,
      missingCount: meal.missingCount,
      unknownCount: meal.unknownCount,
    );
    final statusColor = status.textColor(p);

    return Dismissible(
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
              Icon(Icons.chevron_right_rounded, size: 18, color: p.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meals'),
        actions: [
          IconButton(
            tooltip: 'Manage categories',
            icon: const Icon(Icons.category_outlined),
            onPressed: _manageCategories,
          ),
        ],
      ),
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
                _meals = meals;
                if (meals.isEmpty && _categories.isEmpty) {
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
