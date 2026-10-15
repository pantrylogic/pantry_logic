import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/meal_status.dart';
import '../../core/theme.dart';
import '../../models/calendar_entry.dart';
import '../../services/calendar_service.dart';
import '../../widgets/day_plan_sheets.dart';

/// Days shown per page.
const _pageDays = 7;

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _service = CalendarService();

  /// First day of the visible window (local midnight). Starts at today and
  /// pages by [_pageDays].
  late DateTime _start;
  late Stream<List<CalendarEntry>> _stream;

  DateTime get _today => DayClock.instance.value;

  bool get _showingToday => isSameDay(_start, _today);

  @override
  void initState() {
    super.initState();
    _start = _today;
    // A plain (single-subscription) stream: when the window changes,
    // StreamBuilder cancels it, which removes its realtime channels.
    _stream = _service.streamWeek(_start);
    DayClock.instance.addListener(_onDayChanged);
  }

  @override
  void dispose() {
    DayClock.instance.removeListener(_onDayChanged);
    super.dispose();
  }

  void _setStart(DateTime start) {
    final s = dateOnly(start);
    if (isSameDay(s, _start)) return;
    setState(() {
      _start = s;
      _stream = _service.streamWeek(_start);
    });
  }

  /// At local midnight, a window that was showing "today" follows along.
  void _onDayChanged() {
    final yesterday = addDays(_today, -1);
    if (isSameDay(_start, yesterday)) {
      _setStart(_today);
    } else {
      setState(() {}); // refresh today/past styling
    }
  }

  void _onDayTap(DateTime day, CalendarEntry? entry) {
    if (entry != null && entry.hasMeal) {
      DayPlanSheets.dayActions(context, day, entry);
    } else {
      DayPlanSheets.pickMeal(context, day);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final days = rollingDays(_start, _pageDays);
    final today = _today;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          if (!_showingToday)
            TextButton.icon(
              onPressed: () => _setStart(today),
              icon: const Icon(Icons.today_rounded, size: 18),
              label: const Text('Today'),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Window navigation ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous 7 days',
                  onPressed: () => _setStart(addDays(_start, -_pageDays)),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    rangeLabel(days.first, days.last),
                    textAlign: TextAlign.center,
                    style: nsSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: p.textSecondary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next 7 days',
                  onPressed: () => _setStart(addDays(_start, _pageDays)),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: p.border),
          Expanded(
            child: StreamBuilder<List<CalendarEntry>>(
              stream: _stream,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final entries = <String, CalendarEntry>{
                  for (final e in snap.data ?? const <CalendarEntry>[])
                    dateKey(e.date): e,
                };

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: days.length,
                  separatorBuilder: (ctx2, i2) => Divider(
                    height: 1,
                    indent: 16,
                    endIndent: 16,
                    color: p.border,
                  ),
                  itemBuilder: (_, i) {
                    final day = days[i];
                    final entry = entries[dateKey(day)];
                    return _CalendarDayRow(
                      day: day,
                      entry: entry,
                      isToday: isSameDay(day, today),
                      isPast: day.isBefore(today),
                      onTap: () => _onDayTap(day, entry),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarDayRow extends StatelessWidget {
  const _CalendarDayRow({
    required this.day,
    required this.entry,
    required this.isToday,
    required this.isPast,
    required this.onTap,
  });

  final DateTime day;
  final CalendarEntry? entry;
  final bool isToday;
  final bool isPast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final e = entry;
    final hasMeal = e != null && e.hasMeal;
    final status = hasMeal
        ? MealStatus(
            needCount: e.needCount,
            missingCount: e.missingCount,
            unknownCount: e.unknownCount,
          )
        : null;

    final Widget content;
    if (hasMeal) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            e.mealName ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: nsSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(status!.icon, size: 13, color: status.textColor(p)),
              const SizedBox(width: 4),
              Text(
                status.label,
                style: nsSans(fontSize: 12, color: status.textColor(p)),
              ),
            ],
          ),
        ],
      );
    } else if (isToday) {
      // Only today keeps a prompt; other empty days stay quiet.
      content = Text(
        "Plan tonight's dinner",
        style: nsSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: p.primary,
        ),
      );
    } else {
      content = const SizedBox.shrink();
    }

    final row = InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kWeekdayShort[day.weekday - 1].toUpperCase(),
                      style: nsSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: isToday ? p.primary : p.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: isToday
                          ? BoxDecoration(
                              color: p.primary,
                              shape: BoxShape.circle,
                            )
                          : null,
                      child: Text(
                        '${day.day}',
                        style: nsSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isToday ? p.onPrimary : p.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: content),
              if (hasMeal)
                Icon(Icons.chevron_right_rounded, size: 20, color: p.textMuted)
              else
                Icon(
                  Icons.add_rounded,
                  size: 20,
                  color: isToday ? p.primary : p.hint,
                ),
            ],
          ),
        ),
      ),
    );

    final label = hasMeal
        ? '${shortDayLabel(day)}: ${e.mealName}, ${status!.label}'
        : '${shortDayLabel(day)}: nothing planned';

    return Semantics(
      label: label,
      button: true,
      onTap: onTap,
      excludeSemantics: true,
      // Past days are dimmed but stay tappable.
      child: isPast ? Opacity(opacity: 0.5, child: row) : row,
    );
  }
}
