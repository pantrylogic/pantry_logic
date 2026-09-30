import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_logic/core/dates.dart';

void main() {
  test('today normalizes to local midnight', () {
    final t = today(DateTime(2026, 3, 8, 23, 59, 30));
    expect(t, DateTime(2026, 3, 8));
  });

  group('rollingDays', () {
    test('returns consecutive midnights starting at start', () {
      final days = rollingDays(DateTime(2026, 9, 30, 15, 42), 7);
      expect(days.length, 7);
      expect(days.first, DateTime(2026, 9, 30));
      expect(days[1], DateTime(2026, 10, 1));
      expect(days.last, DateTime(2026, 10, 6));
      for (final d in days) {
        expect(d.hour, 0);
        expect(d.minute, 0);
      }
    });

    test('crosses month and year boundaries', () {
      final days = rollingDays(DateTime(2026, 12, 29), 5);
      expect(days.map(dateKey).toList(), [
        '2026-12-29',
        '2026-12-30',
        '2026-12-31',
        '2027-01-01',
        '2027-01-02',
      ]);
    });

    test('never repeats or skips a calendar day across DST changes', () {
      // Covers both the spring-forward and fall-back weekends in most
      // time zones that observe DST.
      final days = rollingDays(DateTime(2026, 3, 1), 280);
      final keys = days.map(dateKey).toSet();
      expect(keys.length, 280);
      for (var i = 1; i < days.length; i++) {
        final gap = DateTime.utc(days[i].year, days[i].month, days[i].day)
            .difference(DateTime.utc(
                days[i - 1].year, days[i - 1].month, days[i - 1].day));
        expect(gap.inDays, 1);
      }
    });
  });

  test('addDays pages by calendar days', () {
    expect(addDays(DateTime(2026, 9, 30), 7), DateTime(2026, 10, 7));
    expect(addDays(DateTime(2026, 9, 30), -7), DateTime(2026, 9, 23));
  });

  test('dateKey pads fields', () {
    expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05');
  });

  test('untilNextMidnight', () {
    expect(
      untilNextMidnight(DateTime(2026, 9, 30, 23, 0)),
      const Duration(hours: 1),
    );
  });

  test('rangeLabel', () {
    expect(rangeLabel(DateTime(2026, 9, 30), DateTime(2026, 10, 6)),
        'Sep 30 – Oct 6, 2026');
    expect(rangeLabel(DateTime(2026, 10, 1), DateTime(2026, 10, 7)),
        'Oct 1 – 7, 2026');
  });
}
