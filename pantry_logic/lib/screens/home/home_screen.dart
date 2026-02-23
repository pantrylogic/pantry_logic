import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/calendar_entry.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../services/calendar_service.dart';
import '../../services/settings_service.dart';
import '../hungry/hungry_category_screen.dart';
import '../hungry/restock_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _authService = AuthService();
  final _calendarService = CalendarService();
  final _settingsService = SettingsService();

  Profile? _profile;
  CalendarEntry? _tonight;
  List<CalendarEntry> _weekEntries = [];
  int _groceryCount = 0;
  int _pantryCount = 0;
  bool _loading = true;

  late final DateTime _weekStart;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _load();
  }

  Future<void> _load() async {
    try {
      final today = DateTime.now();
      final results = await Future.wait([
        _authService.getProfile(),
        _calendarService.getEntryForDate(today),
        _calendarService.getWeek(_weekStart),
        _settingsService.getGroceryCount(),
        _settingsService.getPantryCount(),
      ]);
      if (mounted) {
        setState(() {
          _profile = results[0] as Profile?;
          _tonight = results[1] as CalendarEntry?;
          _weekEntries = results[2] as List<CalendarEntry>;
          _groceryCount = results[3] as int;
          _pantryCount = results[4] as int;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
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
    final background = isDark ? AppColors.backgroundDm : AppColors.background;
    final border = isDark ? AppColors.borderDm : AppColors.border;
    final success = isDark ? AppColors.successDm : AppColors.success;
    final warning = isDark ? AppColors.warningDm : AppColors.warning;

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    // ── Header row ────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hey, ${_profile?.displayName ?? 'there'} 👋',
                                  style: nsSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "Here's what's going on in the kitchen.",
                                  style: nsSans(
                                    fontSize: 13,
                                    color: textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Settings gear
                          GestureDetector(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen()),
                            ),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: surface,
                                shape: BoxShape.circle,
                                border: Border.all(color: border),
                              ),
                              child: Icon(Icons.settings_outlined,
                                  size: 18, color: textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Anonymous banner ──────────────────────────────────────
                    if (_profile?.isAnonymous == true)
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: warning.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: warning, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Guest session — create an account to keep access across devices.',
                                style: nsSans(
                                    fontSize: 13, color: warning, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 20),

                    // ── Quick stats row ────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.shopping_cart_outlined,
                              count: _groceryCount,
                              label: 'to buy',
                              primary: primary,
                              surface: surface,
                              border: border,
                              textPrimary: textPrimary,
                              textMuted: textMuted,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.inventory_2_outlined,
                              count: _pantryCount,
                              label: 'in pantry',
                              primary: primary,
                              surface: surface,
                              border: border,
                              textPrimary: textPrimary,
                              textMuted: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Tonight's dinner ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _TonightCard(
                        entry: _tonight,
                        primary: primary,
                        surface: surface,
                        border: border,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        textMuted: textMuted,
                        success: success,
                        warning: warning,
                        isDark: isDark,
                        background: background,
                        onEatThis: _tonight?.mealId != null
                            ? () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => RestockScreen(
                                      mealId: _tonight!.mealId!,
                                      mealName: _tonight!.mealName ?? '',
                                    ),
                                  ),
                                )
                            : null,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── I'm Hungry button ─────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const HungryCategoryScreen()),
                        ),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              vertical: 18, horizontal: 24),
                          decoration: BoxDecoration(
                            color: primary,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '🍽️',
                                style: const TextStyle(fontSize: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "I'm Hungry",
                                      style: nsSans(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? background
                                            : AppColors.surface,
                                      ),
                                    ),
                                    Text(
                                      'Find something to eat',
                                      style: nsSans(
                                        fontSize: 13,
                                        color: (isDark
                                                ? background
                                                : AppColors.surface)
                                            .withValues(alpha: 0.75),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: (isDark ? background : AppColors.surface)
                                    .withValues(alpha: 0.7),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── This week ─────────────────────────────────────────────
                    _WeekPreview(
                      weekStart: _weekStart,
                      entries: _weekEntries,
                      primary: primary,
                      surface: surface,
                      border: border,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      textMuted: textMuted,
                      success: success,
                      warning: warning,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Stat card ──────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final Color primary;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textMuted;

  const _StatCard({
    required this.icon,
    required this.count,
    required this.label,
    required this.primary,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textMuted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: primary),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: nsSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              Text(
                label,
                style: nsSans(fontSize: 12, color: textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tonight card ───────────────────────────────────────────────────────────────

class _TonightCard extends StatelessWidget {
  final CalendarEntry? entry;
  final Color primary;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color background;
  final bool isDark;
  final VoidCallback? onEatThis;

  const _TonightCard({
    required this.entry,
    required this.primary,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.background,
    required this.isDark,
    this.onEatThis,
  });

  @override
  Widget build(BuildContext context) {
    final hasMeal = entry != null && entry!.hasMeal;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TONIGHT',
            style: nsSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: textMuted,
            ),
          ),
          const SizedBox(height: 6),
          if (hasMeal) ...[
            Text(
              entry!.mealName!,
              style: nsSans(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            if (entry!.hasNeedList) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color:
                          entry!.allInPantry ? success : warning,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    entry!.allInPantry
                        ? 'All ingredients in pantry'
                        : '${entry!.missingCount} ingredient${entry!.missingCount == 1 ? '' : 's'} missing',
                    style: nsSans(
                      fontSize: 12,
                      color: entry!.allInPantry ? success : warning,
                    ),
                  ),
                ],
              ),
            ],
            if (onEatThis != null) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: onEatThis,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Eat This',
                    style: nsSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? background : AppColors.surface,
                    ),
                  ),
                ),
              ),
            ],
          ] else
            Text(
              'Nothing planned — tap Calendar to plan dinner.',
              style: nsSans(fontSize: 14, color: textMuted, height: 1.4),
            ),
        ],
      ),
    );
  }
}

// ── Week preview ───────────────────────────────────────────────────────────────

class _WeekPreview extends StatelessWidget {
  final DateTime weekStart;
  final List<CalendarEntry> entries;
  final Color primary;
  final Color surface;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color success;
  final Color warning;

  const _WeekPreview({
    required this.weekStart,
    required this.entries,
    required this.primary,
    required this.surface,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.warning,
  });

  @override
  Widget build(BuildContext context) {
    // Build a date → entry map
    final entryMap = <String, CalendarEntry>{};
    for (final e in entries) {
      entryMap[_dateKey(e.date)] = e;
    }

    final today = DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'THIS WEEK',
              style: nsSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: textMuted,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border),
            ),
            child: Column(
              children: List.generate(7, (i) {
                final day = weekStart.add(Duration(days: i));
                final isToday = day.year == today.year &&
                    day.month == today.month &&
                    day.day == today.day;
                final entry = entryMap[_dateKey(day)];
                final hasMeal = entry != null && entry.hasMeal;

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
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 36,
                            child: Text(
                              _dayAbbr(day.weekday),
                              style: nsSans(
                                fontSize: 12,
                                fontWeight: isToday
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isToday ? primary : textMuted,
                              ),
                            ),
                          ),
                          if (hasMeal && dotColor != null) ...[
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: dotColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ] else
                            const SizedBox(width: 15),
                          Expanded(
                            child: Text(
                              hasMeal
                                  ? entry.mealName!
                                  : '–',
                              style: nsSans(
                                fontSize: 13,
                                fontWeight: hasMeal
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: hasMeal ? textPrimary : textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (i < 6)
                      Divider(
                          height: 1,
                          indent: 14,
                          endIndent: 14,
                          color: border),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _dayAbbr(int weekday) {
    const abbrs = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return abbrs[weekday - 1];
  }
}
