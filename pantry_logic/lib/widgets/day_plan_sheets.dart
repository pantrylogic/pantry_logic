import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/meal_status.dart';
import '../core/routes.dart';
import '../core/theme.dart';
import '../models/calendar_entry.dart';
import '../models/meal.dart';
import '../screens/hungry/restock_screen.dart';
import '../screens/meals/meal_detail_screen.dart';
import '../services/calendar_service.dart';
import '../services/meal_service.dart';
import 'app_sheet.dart';
import 'app_snack_bar.dart';

/// Sheets for planning a single day, shared by Home and Calendar.
///
/// [onChanged] runs after anything that may have changed the plan or stock
/// (including an Undo), so screens without a live stream can reload.
abstract final class DayPlanSheets {
  static final _calendar = CalendarService();
  static final _meals = MealService();

  /// "Plan dinner for …" meal picker. Assigns the chosen meal to [date].
  static Future<void> pickMeal(
    BuildContext context,
    DateTime date, {
    VoidCallback? onChanged,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final List<Meal> meals;
    try {
      meals = await _calendar.getMeals();
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not load meals.', e, st);
      return;
    }
    if (!context.mounted) return;
    if (meals.isEmpty) {
      showAppSnackBar(messenger, 'Add some meals first on the Meals tab.');
      return;
    }

    final meal = await showModalBottomSheet<Meal>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _MealPickerSheet(date: date, meals: meals),
    );
    if (meal == null) return;

    try {
      await _calendar.assignMeal(date: date, mealId: meal.id);
      onChanged?.call();
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not plan ${meal.name}.', e, st);
    }
  }

  /// Actions for a day that already has a meal planned.
  static Future<void> dayActions(
    BuildContext context,
    DateTime date,
    CalendarEntry entry, {
    VoidCallback? onChanged,
  }) async {
    final action = await showAppSheet<_DayAction>(
      context: context,
      builder: (_) => _DayActionsSheet(date: date, entry: entry),
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case _DayAction.view:
        await openMeal(context, entry.mealId!);
        onChanged?.call();
      case _DayAction.eat:
        await eatThis(context, entry);
        onChanged?.call();
      case _DayAction.change:
        await pickMeal(context, date, onChanged: onChanged);
      case _DayAction.remove:
        await _remove(context, date, entry, onChanged);
    }
  }

  /// Opens the meal detail screen for [mealId].
  static Future<void> openMeal(BuildContext context, String mealId) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final meal = await _meals.getMeal(mealId);
      if (meal == null) {
        showAppSnackBar(messenger, 'That meal no longer exists.');
        return;
      }
      await navigator.push(
        MaterialPageRoute<void>(
          settings: AppRoutes.settings(AppRoutes.mealDetail),
          builder: (_) => MealDetailScreen(meal: meal),
        ),
      );
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not open the meal.', e, st);
    }
  }

  /// Starts the Eat This / restock flow for a planned meal.
  static Future<void> eatThis(BuildContext context, CalendarEntry entry) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          settings: AppRoutes.settings(AppRoutes.restock),
          builder: (_) => RestockScreen(
            mealId: entry.mealId!,
            mealName: entry.mealName ?? '',
          ),
        ),
      );

  static Future<void> _remove(
    BuildContext context,
    DateTime date,
    CalendarEntry entry,
    VoidCallback? onChanged,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _calendar.clearDay(date);
      onChanged?.call();
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not remove the meal.', e, st);
      return;
    }
    showUndoSnackBar(
      messenger,
      '${entry.mealName ?? 'Meal'} removed from ${shortDayLabel(date)}.',
      onUndo: () async {
        try {
          await _calendar.assignMeal(date: date, mealId: entry.mealId!);
          onChanged?.call();
        } catch (e, st) {
          showErrorSnackBar(messenger, 'Could not restore the meal.', e, st);
        }
      },
    );
  }
}

/// "Tonight", "Tomorrow", "Yesterday" or "Tue 14 Oct".
String relativeDayLabel(DateTime date, DateTime today) {
  final diff = DateTime.utc(
    date.year,
    date.month,
    date.day,
  ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
  return switch (diff) {
    0 => 'Tonight',
    1 => 'Tomorrow',
    -1 => 'Yesterday',
    _ => shortDayLabel(date),
  };
}

enum _DayAction { view, eat, change, remove }

class _DayActionsSheet extends StatelessWidget {
  const _DayActionsSheet({required this.date, required this.entry});

  final DateTime date;
  final CalendarEntry entry;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final status = MealStatus(
      needCount: entry.needCount,
      missingCount: entry.missingCount,
      unknownCount: entry.unknownCount,
    );

    Widget action(_DayAction a, IconData icon, String label, {Color? color}) =>
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon, color: color ?? p.primary),
          title: Text(
            label,
            style: nsSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color ?? p.textPrimary,
            ),
          ),
          onTap: () => Navigator.of(context).pop(a),
        );

    return AppSheet(
      title: entry.mealName ?? 'Planned meal',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            relativeDayLabel(date, today()) == shortDayLabel(date)
                ? shortDayLabel(date)
                : '${relativeDayLabel(date, today())} · ${shortDayLabel(date)}',
            style: nsSans(fontSize: 13, color: p.textMuted),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(status.icon, size: 16, color: status.textColor(p)),
              const SizedBox(width: 6),
              Text(
                status.longLabel,
                style: nsSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: status.textColor(p),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          action(_DayAction.view, Icons.menu_book_rounded, 'View meal'),
          action(_DayAction.eat, Icons.restaurant_rounded, 'Eat This'),
          action(_DayAction.change, Icons.swap_horiz_rounded, 'Change meal'),
          action(
            _DayAction.remove,
            Icons.delete_outline_rounded,
            'Remove',
            color: p.error,
          ),
        ],
      ),
    );
  }
}

class _MealPickerSheet extends StatelessWidget {
  const _MealPickerSheet({required this.date, required this.meals});

  final DateTime date;
  final List<Meal> meals;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final dayLabel =
        '${kWeekdayLong[date.weekday - 1]} ${date.day} ${kMonthShort[date.month - 1]}';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: p.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Plan dinner for $dayLabel',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: meals.length,
                separatorBuilder: (ctx2, i2) => Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: p.border,
                ),
                itemBuilder: (_, i) {
                  final meal = meals[i];
                  final status = MealStatus(
                    needCount: meal.needCount,
                    missingCount: meal.missingCount,
                    unknownCount: meal.unknownCount,
                  );
                  return ListTile(
                    leading: Icon(
                      status.icon,
                      size: 20,
                      color: status.textColor(p),
                    ),
                    title: Text(
                      meal.name,
                      style: nsSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      [
                        if (meal.categoryName != null) meal.categoryName!,
                        status.label,
                      ].join(' · '),
                      style: nsSans(fontSize: 12, color: p.textMuted),
                    ),
                    trailing: Icon(
                      Icons.add_circle_outline_rounded,
                      color: p.primary,
                      size: 22,
                    ),
                    onTap: () => Navigator.of(context).pop(meal),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
