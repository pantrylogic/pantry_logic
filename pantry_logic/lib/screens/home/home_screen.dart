import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/meal_status.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../core/ui_prefs.dart';
import '../../models/calendar_entry.dart';
import '../../models/profile.dart';
import '../../services/auth_service.dart';
import '../../services/calendar_service.dart';
import '../../services/settings_service.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/day_plan_sheets.dart';
import '../hungry/hungry_category_screen.dart';
import '../settings/settings_screen.dart';
import '../shell/shell_controller.dart';

/// Number of days shown in the plan card (today + 6).
const _planDays = 7;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TabActivation {
  final _authService = AuthService();
  final _calendarService = CalendarService();
  final _settingsService = SettingsService();

  Profile? _profile;
  Map<String, CalendarEntry> _entries = {};
  int _groceryCount = 0;
  int _stockCount = 0;
  bool _loading = true;
  bool _upcomingExpanded = false;

  DateTime get _today => DayClock.instance.value;

  @override
  int get tabIndex => ShellTab.home;

  @override
  void onTabActivated() => _load();

  @override
  void initState() {
    super.initState();
    DayClock.instance.addListener(_onDayChanged);
    _load();
    UiPrefs.getBool(UiPrefs.homeUpcomingExpanded).then((v) {
      if (mounted) setState(() => _upcomingExpanded = v);
    });
  }

  @override
  void dispose() {
    DayClock.instance.removeListener(_onDayChanged);
    super.dispose();
  }

  /// Local midnight passed: the rolling window moves on by a day.
  void _onDayChanged() => _load();

  Future<void> _load() async {
    final start = _today;
    try {
      final results = await Future.wait([
        _authService.getProfile(),
        _calendarService.getWeek(start),
        _settingsService.getGroceryCount(),
        _settingsService.getPantryCount(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = results[0] as Profile?;
        _entries = {
          for (final e in results[1] as List<CalendarEntry>) dateKey(e.date): e,
        };
        _groceryCount = results[2] as int;
        _stockCount = results[3] as int;
        _loading = false;
      });
    } catch (e, st) {
      logError('Load home dashboard', e, st);
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleUpcoming() {
    setState(() => _upcomingExpanded = !_upcomingExpanded);
    UiPrefs.setBool(UiPrefs.homeUpcomingExpanded, _upcomingExpanded);
  }

  void _onDayTap(DateTime day) {
    final entry = _entries[dateKey(day)];
    if (entry != null && entry.hasMeal) {
      DayPlanSheets.dayActions(context, day, entry, onChanged: _load);
    } else {
      DayPlanSheets.pickMeal(context, day, onChanged: _load);
    }
  }

  Future<void> _eatThis(CalendarEntry entry) async {
    await DayPlanSheets.eatThis(context, entry);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  // Pull-to-refresh must work even when content is short.
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    _Header(
                      name: _profile?.displayName,
                      onSettings: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SettingsScreen()),
                      ),
                    ),
                    if (_profile?.isAnonymous == true) const _GuestBanner(),
                    const SizedBox(height: 20),

                    // ── Quick stats ──────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              icon: Icons.shopping_cart_outlined,
                              count: _groceryCount,
                              label: 'to buy',
                              onTap: () => goToTab(ShellTab.grocery),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              icon: Icons.inventory_2_outlined,
                              count: _stockCount,
                              label: 'in stock',
                              onTap: () => goToTab(ShellTab.stock),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Rolling 7-day plan ───────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _PlanCard(
                        days: rollingDays(_today, _planDays),
                        today: _today,
                        entries: _entries,
                        upcomingExpanded: _upcomingExpanded,
                        onToggleUpcoming: _toggleUpcoming,
                        onDayTap: _onDayTap,
                        onEatThis: _eatThis,
                        onOpenCalendar: () => goToTab(ShellTab.calendar),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── I'm Hungry ───────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _HungryButton(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            settings:
                                AppRoutes.settings(AppRoutes.hungryCategory),
                            builder: (_) => const HungryCategoryScreen(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.name, required this.onSettings});

  final String? name;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: 'Hey, ${name ?? 'there'} ',
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: Icon(
                          Icons.waving_hand_rounded,
                          size: 22,
                          color: p.warning,
                        ),
                      ),
                    ],
                  ),
                  style: nsSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "Here's what's going on in the kitchen.",
                  style: nsSans(fontSize: 13, color: p.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: onSettings,
            icon: Icon(Icons.settings_outlined, color: p.textSecondary),
            style: IconButton.styleFrom(
              backgroundColor: p.surface,
              side: BorderSide(color: p.border),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestBanner extends StatelessWidget {
  const _GuestBanner();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: p.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: p.warningText, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Guest session — create an account to keep access across devices.',
              style: nsSans(fontSize: 13, color: p.warningText, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat card ───────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.count,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: p.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count',
                      style: nsSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    Text(
                      label,
                      style: nsSans(fontSize: 12, color: p.textMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: p.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Plan card ───────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.days,
    required this.today,
    required this.entries,
    required this.upcomingExpanded,
    required this.onToggleUpcoming,
    required this.onDayTap,
    required this.onEatThis,
    required this.onOpenCalendar,
  });

  final List<DateTime> days;
  final DateTime today;
  final Map<String, CalendarEntry> entries;
  final bool upcomingExpanded;
  final VoidCallback onToggleUpcoming;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<CalendarEntry> onEatThis;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final upcoming = days.skip(2).toList();
    final plannedUpcoming =
        upcoming.where((d) => entries[dateKey(d)]?.hasMeal == true).length;

    Widget divider() => Divider(height: 1, indent: 14, endIndent: 14, color: p.border);

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Card header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 0),
            child: Row(
              children: [
                Text(
                  'DINNER PLAN',
                  style: nsSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: p.textMuted,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onOpenCalendar,
                  child: const Text('Calendar'),
                ),
              ],
            ),
          ),
          _DayRow(
            day: days[0],
            label: 'Tonight',
            entry: entries[dateKey(days[0])],
            emphasized: true,
            onTap: () => onDayTap(days[0]),
            onEatThis: onEatThis,
          ),
          divider(),
          _DayRow(
            day: days[1],
            label: 'Tomorrow',
            entry: entries[dateKey(days[1])],
            onTap: () => onDayTap(days[1]),
          ),
          divider(),
          // Collapsible "next 5 days"
          Semantics(
            button: true,
            expanded: upcomingExpanded,
            child: InkWell(
              onTap: onToggleUpcoming,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Row(
                  children: [
                    Text(
                      'Next ${upcoming.length} days',
                      style: nsSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: p.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$plannedUpcoming of ${upcoming.length} planned',
                      style: nsSans(fontSize: 12, color: p.textMuted),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: upcomingExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(Icons.expand_more_rounded,
                          size: 22, color: p.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (upcomingExpanded)
            for (final d in upcoming) ...[
              divider(),
              _DayRow(
                day: d,
                label: kWeekdayShort[d.weekday - 1],
                sublabel: '${d.day} ${kMonthShort[d.month - 1]}',
                entry: entries[dateKey(d)],
                onTap: () => onDayTap(d),
              ),
            ],
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.label,
    this.sublabel,
    required this.entry,
    required this.onTap,
    this.emphasized = false,
    this.onEatThis,
  });

  final DateTime day;
  final String label;
  final String? sublabel;
  final CalendarEntry? entry;
  final VoidCallback onTap;
  final bool emphasized;
  final ValueChanged<CalendarEntry>? onEatThis;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final e = entry;
    final hasMeal = e != null && e.hasMeal;
    final status = hasMeal
        ? MealStatus(needCount: e.needCount, missingCount: e.missingCount)
        : null;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, emphasized ? 12 : 10, 12,
            emphasized ? 12 : 10),
        child: Row(
          children: [
            SizedBox(
              width: 76,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: nsSans(
                      fontSize: emphasized ? 14 : 13,
                      fontWeight: FontWeight.w700,
                      color: emphasized ? p.primary : p.textSecondary,
                    ),
                  ),
                  if (sublabel != null)
                    Text(
                      sublabel!,
                      style: nsSans(fontSize: 12, color: p.textMuted),
                    ),
                ],
              ),
            ),
            Expanded(
              child: hasMeal
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.mealName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: nsSans(
                            fontSize: emphasized ? 16 : 14,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(status!.icon,
                                size: 13, color: status.textColor(p)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                emphasized ? status.longLabel : status.label,
                                overflow: TextOverflow.ellipsis,
                                style: nsSans(
                                  fontSize: 12,
                                  color: status.textColor(p),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Text(
                      'Nothing planned',
                      style: nsSans(fontSize: 14, color: p.textMuted),
                    ),
            ),
            const SizedBox(width: 8),
            if (hasMeal && onEatThis != null)
              FilledButton(
                onPressed: () => onEatThis!(e),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  textStyle: nsSans(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                child: const Text('Eat This'),
              )
            else
              Icon(
                hasMeal
                    ? Icons.chevron_right_rounded
                    : Icons.add_circle_outline_rounded,
                size: hasMeal ? 20 : 22,
                color: hasMeal ? p.textMuted : p.primary,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Hungry button ───────────────────────────────────────────────────────────

class _HungryButton extends StatelessWidget {
  const _HungryButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final fg = p.onPrimary;
    return Material(
      color: p.primary,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
          child: Row(
            children: [
              Icon(Icons.restaurant_rounded, size: 28, color: fg),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "I'm Hungry",
                      style: nsSans(
                          fontSize: 17, fontWeight: FontWeight.w700, color: fg),
                    ),
                    Text(
                      'Find something to eat',
                      style: nsSans(
                          fontSize: 13, color: fg.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: fg.withValues(alpha: 0.7)),
            ],
          ),
        ),
      ),
    );
  }
}
