import 'dart:async';

import 'package:flutter/widgets.dart';

/// Strips the time component (local midnight of the same calendar day).
DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Today at local midnight.
DateTime today([DateTime? now]) => dateOnly(now ?? DateTime.now());

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// [count] consecutive calendar days starting at [start] (normalized to
/// midnight). Built from calendar fields rather than Duration arithmetic,
/// so DST transitions never skip or repeat a day.
List<DateTime> rollingDays(DateTime start, int count) => List.generate(
      count,
      (i) => DateTime(start.year, start.month, start.day + i),
    );

/// Adds [days] calendar days (DST-safe).
DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// ISO date key "yyyy-mm-dd" matching the calendar_entries.date column.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// Time remaining until the next local midnight.
Duration untilNextMidnight([DateTime? now]) {
  final n = now ?? DateTime.now();
  return DateTime(n.year, n.month, n.day + 1).difference(n);
}

const List<String> kWeekdayShort = [
  'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun', //
];
const List<String> kWeekdayLong = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
  'Sunday', //
];
const List<String> kMonthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct',
  'Nov', 'Dec', //
];
const List<String> kMonthLong = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July',
  'August', 'September', 'October', 'November', 'December', //
];

/// "Tue 14 Oct"
String shortDayLabel(DateTime d) =>
    '${kWeekdayShort[d.weekday - 1]} ${d.day} ${kMonthShort[d.month - 1]}';

/// "Oct 14 – 20, 2026" style label for a run of days.
String rangeLabel(DateTime first, DateTime last) {
  final m1 = kMonthShort[first.month - 1];
  final m2 = kMonthShort[last.month - 1];
  if (first.year != last.year) {
    return '$m1 ${first.day}, ${first.year} – $m2 ${last.day}, ${last.year}';
  }
  if (first.month != last.month) {
    return '$m1 ${first.day} – $m2 ${last.day}, ${last.year}';
  }
  return '$m1 ${first.day} – ${last.day}, ${last.year}';
}

/// App-wide notifier holding "today" (local midnight). It updates itself at
/// each local midnight and whenever the app resumes, so screens can listen
/// to it to roll their date windows over.
class DayClock extends ValueNotifier<DateTime> {
  DayClock._() : super(today()) {
    _schedule();
    _lifecycle = AppLifecycleListener(onResume: refresh);
  }

  static final DayClock instance = DayClock._();

  Timer? _timer;
  late final AppLifecycleListener _lifecycle;

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  /// Re-reads the clock; notifies listeners only if the day changed.
  void refresh() {
    final t = today();
    if (!isSameDay(t, value)) value = t;
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    // A small margin guarantees we land after midnight.
    _timer = Timer(
      untilNextMidnight() + const Duration(seconds: 1),
      refresh,
    );
  }
}
