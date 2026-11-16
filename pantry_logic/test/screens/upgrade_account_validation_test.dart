import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_logic/screens/auth/upgrade_account_screen.dart';

void main() {
  const v = UpgradeAccountScreen.validate;

  test('requires every field', () {
    expect(v('', 'secret1', 'secret1'), 'Please fill in all fields.');
    expect(v('a@b.co', '', ''), 'Please fill in all fields.');
  });

  test('rejects a malformed email', () {
    expect(
      v('nope', 'secret1', 'secret1'),
      'Please enter a valid email address.',
    );
  });

  test('rejects short passwords', () {
    expect(
      v('a@b.co', '12345', '12345'),
      'Password must be at least 6 characters.',
    );
  });

  test('rejects mismatched passwords', () {
    expect(v('a@b.co', 'secret1', 'secret2'), "Passwords don't match.");
  });

  test('accepts a valid form', () {
    expect(v('a@b.co', 'secret1', 'secret1'), isNull);
  });
}
