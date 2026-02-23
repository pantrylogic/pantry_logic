import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/meal.dart';
import '../../models/meal_category.dart';
import '../../services/meal_service.dart';
import 'meal_detail_screen.dart';

class MealsScreen extends StatefulWidget {
  const MealsScreen({super.key});

  @override
  State<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends State<MealsScreen> {
  final _service = MealService();
  late final Stream<List<Meal>> _stream;
  List<MealCategory> _categories = [];

  final _addCtrl = TextEditingController();
  final _addFocus = FocusNode();
  bool _adding = false;

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
    } catch (_) {}
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _addCtrl.text.trim();
    if (name.isEmpty) {
      _addFocus.unfocus();
      return;
    }
    if (_adding) return;
    setState(() => _adding = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.addMeal(name: name);
      _addCtrl.clear();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not add meal: $e')));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _deleteMeal(Meal meal) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.deleteMeal(meal.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDm : AppColors.primary;
    final textPrimary =
        isDark ? AppColors.textPrimaryDm : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.textSecondaryDm : AppColors.textSecondary;
    final textMuted = isDark ? AppColors.textMutedDm : AppColors.textMuted;
    final surface = isDark ? AppColors.surfaceDm : AppColors.surface;
    final border = isDark ? AppColors.borderDm : AppColors.border;
    final success = isDark ? AppColors.successDm : AppColors.success;
    final warning = isDark ? AppColors.warningDm : AppColors.warning;
    final errorColor = isDark ? AppColors.errorDm : AppColors.error;

    List<Widget> buildItems(List<Meal> meals) {
      // Group by category
      final grouped = <String?, List<Meal>>{};
      for (final meal in meals) {
        (grouped[meal.categoryId] ??= []).add(meal);
      }

      // Sort category keys: by sort_order ascending, null (uncategorized) last
      final sortedKeys = grouped.keys.toList()
        ..sort((a, b) {
          if (a == null) return 1;
          if (b == null) return -1;
          final catA = _categories.firstWhere(
            (c) => c.id == a,
            orElse: () =>
                MealCategory(id: a, householdId: '', name: '', sortOrder: 999),
          );
          final catB = _categories.firstWhere(
            (c) => c.id == b,
            orElse: () =>
                MealCategory(id: b, householdId: '', name: '', sortOrder: 999),
          );
          return catA.sortOrder.compareTo(catB.sortOrder);
        });

      final widgets = <Widget>[];

      for (final catId in sortedKeys) {
        final groupMeals = grouped[catId]!
          ..sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        final label = catId != null
            ? (groupMeals.first.categoryName ?? 'Other')
            : 'Uncategorized';

        // Section header
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
          child: Text(
            label.toUpperCase(),
            style: nsSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: textMuted,
            ),
          ),
        ));

        for (int i = 0; i < groupMeals.length; i++) {
          final meal = groupMeals[i];

          // Status
          final Color statusColor;
          final String statusText;
          final IconData statusIcon;
          if (!meal.hasNeedList) {
            statusColor = textMuted;
            statusText = 'No need list';
            statusIcon = Icons.format_list_bulleted_rounded;
          } else if (meal.allInPantry) {
            statusColor = success;
            statusText = 'All in pantry';
            statusIcon = Icons.check_circle_outline_rounded;
          } else {
            statusColor = warning;
            statusText = '${meal.missingCount} missing';
            statusIcon = Icons.radio_button_unchecked_rounded;
          }

          widgets.add(Dismissible(
            key: ValueKey(meal.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: errorColor.withValues(alpha: 0.12),
              child: Icon(
                Icons.delete_outline_rounded,
                color: errorColor,
                size: 22,
              ),
            ),
            onDismissed: (_) => _deleteMeal(meal),
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => MealDetailScreen(meal: meal)),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(statusIcon, size: 13, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style:
                                    nsSans(fontSize: 12, color: statusColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ));

          if (i < groupMeals.length - 1) {
            widgets.add(
              Divider(height: 1, indent: 16, endIndent: 16, color: border),
            );
          }
        }
      }

      return widgets;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Meals', style: nsSans(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // ── Meal list ──────────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Meal>>(
              stream: _stream,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final meals = snap.data ?? [];
                if (meals.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '🍽️',
                            style: TextStyle(fontSize: 48),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Add meals your household likes',
                            textAlign: TextAlign.center,
                            style: nsSans(
                              fontSize: 16,
                              color: textSecondary,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Meals with need lists show you what\'s\nmissing and add it to your grocery list.',
                            textAlign: TextAlign.center,
                            style: nsSans(
                              fontSize: 14,
                              color: textMuted,
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
                  children: buildItems(meals),
                );
              },
            ),
          ),

          // ── Add meal bar ───────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: surface,
              border: Border(top: BorderSide(color: border, width: 0.5)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: TextField(
                  controller: _addCtrl,
                  focusNode: _addFocus,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  style: nsSans(fontSize: 15, color: textPrimary),
                  decoration: InputDecoration(
                    hintText: 'New meal…',
                    hintStyle: nsSans(fontSize: 15, color: textMuted),
                    prefixIcon: Icon(Icons.add_rounded, color: primary, size: 22),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
