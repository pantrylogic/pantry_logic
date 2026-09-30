import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_logic/widgets/day_plan_sheets.dart';

void main() {
  final today = DateTime(2026, 9, 30);

  test('relative day labels', () {
    expect(relativeDayLabel(DateTime(2026, 9, 30), today), 'Tonight');
    expect(relativeDayLabel(DateTime(2026, 10, 1), today), 'Tomorrow');
    expect(relativeDayLabel(DateTime(2026, 9, 29), today), 'Yesterday');
    expect(relativeDayLabel(DateTime(2026, 10, 3), today), 'Sat 3 Oct');
  });
}
