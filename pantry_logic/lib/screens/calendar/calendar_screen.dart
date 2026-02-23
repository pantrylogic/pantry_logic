import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/calendar_entry.dart';
import '../../models/meal.dart';
import '../../services/calendar_service.dart';
import '../hungry/restock_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _service = CalendarService();

  late final DateTime _weekStart;
  late final Stream<List<CalendarEntry>> _stream;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Monday of the current week
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _stream = _service.streamWeek(_weekStart).asBroadcastStream();
  }

  // ── Meal picker ──────────────────────────────────────────────────────────────

  Future<void> _showMealPicker(DateTime date) async {
    List<Meal>? meals;
    try {
      meals = await _service.getMeals();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load meals: $e')),
        );
      }
      return;
    }
    if (!mounted) return;

    if (meals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Add some meals first on the Meals tab.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _MealPickerSheet(
        date: date,
        meals: meals!,
        onPick: (meal) => _assignMeal(date, meal),
      ),
    );
  }

  Future<void> _assignMeal(DateTime date, Meal meal) async {
    try {
      await _service.assignMeal(date: date, mealId: meal.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not assign meal: $e')),
        );
      }
    }
  }

  // ── Day action sheet ─────────────────────────────────────────────────────────

  Future<void> _showDayActions(
      BuildContext context, DateTime date, CalendarEntry entry) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDm : AppColors.primary;
    final textPrimary =
        isDark ? AppColors.textPrimaryDm : AppColors.textPrimary;
    final errorColor = isDark ? AppColors.errorDm : AppColors.error;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.borderDm : AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    entry.mealName ?? '',
                    style: nsSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ),
                // Eat This
                ListTile(
                  leading: Icon(Icons.restaurant_rounded, color: primary),
                  title: Text(
                    'Eat This',
                    style: nsSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textPrimary),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RestockScreen(
                          mealId: entry.mealId!,
                          mealName: entry.mealName!,
                        ),
                      ),
                    );
                  },
                ),
                // Change
                ListTile(
                  leading: Icon(Icons.swap_horiz_rounded, color: primary),
                  title: Text(
                    'Change meal',
                    style: nsSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textPrimary),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showMealPicker(date);
                  },
                ),
                // Remove
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: errorColor),
                  title: Text(
                    'Remove',
                    style: nsSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: errorColor),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _clearDay(date);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _clearDay(DateTime date) async {
    try {
      await _service.clearDay(date);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not remove meal: $e')),
        );
      }
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDm : AppColors.primary;
    final textPrimary =
        isDark ? AppColors.textPrimaryDm : AppColors.textPrimary;
    final textMuted = isDark ? AppColors.textMutedDm : AppColors.textMuted;
    final surface = isDark ? AppColors.surfaceDm : AppColors.surface;
    final border = isDark ? AppColors.borderDm : AppColors.border;
    final success = isDark ? AppColors.successDm : AppColors.success;
    final warning = isDark ? AppColors.warningDm : AppColors.warning;
    final background =
        isDark ? AppColors.backgroundDm : AppColors.background;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final weekDays = List.generate(
      7,
      (i) => _weekStart.add(Duration(days: i)),
    );

    // Month/year header — show range
    final firstDay = weekDays.first;
    final lastDay = weekDays.last;
    final String weekLabel;
    if (firstDay.month == lastDay.month) {
      weekLabel =
          '${_monthName(firstDay.month)} ${firstDay.year}';
    } else if (firstDay.year == lastDay.year) {
      weekLabel =
          '${_monthName(firstDay.month)} – ${_monthName(lastDay.month)} ${firstDay.year}';
    } else {
      weekLabel =
          '${_monthName(firstDay.month)} ${firstDay.year} – ${_monthName(lastDay.month)} ${lastDay.year}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Calendar', style: nsSans(fontWeight: FontWeight.w700)),
      ),
      body: StreamBuilder<List<CalendarEntry>>(
        stream: _stream,
        builder: (ctx, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          // Map date → entry
          final entries = <String, CalendarEntry>{};
          for (final e in snap.data ?? []) {
            entries[_dateKey(e.date)] = e;
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Week label ─────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  weekLabel.toUpperCase(),
                  style: nsSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: textMuted,
                  ),
                ),
              ),

              // ── Day rows ───────────────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: 7,
                  itemBuilder: (_, i) {
                    final day = weekDays[i];
                    final isToday = _isSameDay(day, todayDate);
                    final entry = entries[_dateKey(day)];
                    final hasMeal = entry != null && entry.hasMeal;

                    // Status dot colour
                    Color? dotColor;
                    if (hasMeal) {
                      if (!entry.hasNeedList) {
                        dotColor = textMuted;
                      } else if (entry.allInPantry) {
                        dotColor = success;
                      } else {
                        dotColor = warning;
                      }
                    }

                    return Column(
                      children: [
                        InkWell(
                          onTap: () {
                            if (hasMeal) {
                              _showDayActions(context, day, entry);
                            } else {
                              _showMealPicker(day);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                // Day column
                                SizedBox(
                                  width: 44,
                                  child: Column(
                                    children: [
                                      Text(
                                        _dayAbbr(day.weekday),
                                        style: nsSans(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                          color: isToday
                                              ? primary
                                              : textMuted,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: isToday
                                            ? BoxDecoration(
                                                color: primary,
                                                shape: BoxShape.circle,
                                              )
                                            : null,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${day.day}',
                                          style: nsSans(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: isToday
                                                ? (isDark
                                                    ? background
                                                    : surface)
                                                : textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Meal info
                                Expanded(
                                  child: hasMeal
                                      ? Row(
                                          children: [
                                            if (dotColor != null) ...[
                                              Container(
                                                width: 8,
                                                height: 8,
                                                decoration: BoxDecoration(
                                                  color: dotColor,
                                                  shape: BoxShape.circle,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            Expanded(
                                              child: Text(
                                                entry.mealName ?? '',
                                                style: nsSans(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: textPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Text(
                                          'Tap to plan dinner',
                                          style: nsSans(
                                            fontSize: 14,
                                            color: textMuted,
                                          ),
                                        ),
                                ),

                                // Chevron
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (i < 6)
                          Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: border),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _dayAbbr(int weekday) {
    const abbrs = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return abbrs[weekday - 1];
  }

  String _monthName(int month) {
    const names = [
      '',
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return names[month];
  }
}

// ── Meal Picker Sheet ────────────────────────────────────────────────────────

class _MealPickerSheet extends StatelessWidget {
  final DateTime date;
  final List<Meal> meals;
  final void Function(Meal) onPick;

  const _MealPickerSheet({
    required this.date,
    required this.meals,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDm : AppColors.primary;
    final textPrimary =
        isDark ? AppColors.textPrimaryDm : AppColors.textPrimary;
    final textMuted = isDark ? AppColors.textMutedDm : AppColors.textMuted;
    final border = isDark ? AppColors.borderDm : AppColors.border;
    final success = isDark ? AppColors.successDm : AppColors.success;
    final warning = isDark ? AppColors.warningDm : AppColors.warning;

    // Day label
    final dayNames = [
      '', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    final dayLabel = '${dayNames[date.weekday]} ${date.day}';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (_, controller) {
        return Column(
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Plan dinner for $dayLabel',
                  style: nsSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: controller,
                itemCount: meals.length,
                separatorBuilder: (context, index) =>
                    Divider(height: 1, indent: 16, endIndent: 16, color: border),
                itemBuilder: (_, i) {
                  final meal = meals[i];

                  Color statusColor;
                  if (!meal.hasNeedList) {
                    statusColor = textMuted;
                  } else if (meal.allInPantry) {
                    statusColor = success;
                  } else {
                    statusColor = warning;
                  }

                  return ListTile(
                    leading: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(
                      meal.name,
                      style: nsSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textPrimary),
                    ),
                    subtitle: meal.categoryName != null
                        ? Text(
                            meal.categoryName!,
                            style: nsSans(fontSize: 12, color: textMuted),
                          )
                        : null,
                    trailing: Icon(Icons.add_circle_outline_rounded,
                        color: primary, size: 22),
                    onTap: () {
                      Navigator.of(context).pop();
                      onPick(meal);
                    },
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
