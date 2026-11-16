import 'package:flutter_test/flutter_test.dart';
import 'package:pantry_logic/screens/auth/join_household_screen.dart';

void main() {
  String? v({
    String name = 'Pea',
    String email = 'pea@example.com',
    String password = 'secret1',
    String code = 'ABC123',
  }) => JoinHouseholdScreen.validate(
    name: name,
    email: email,
    password: password,
    code: code,
  );

  test('accepts a complete form', () => expect(v(), isNull));

  test('asks for each missing piece', () {
    expect(v(name: ''), 'What should we call you?');
    expect(v(email: ''), 'Please enter a valid email address.');
    expect(v(email: 'nope'), 'Please enter a valid email address.');
    expect(v(password: '12345'), 'Password must be at least 6 characters.');
    expect(v(code: ''), 'Enter the household code.');
  });

  group('friendlyError', () {
    const f = JoinHouseholdScreen.friendlyError;

    test('registered email points to Sign in', () {
      expect(
        f(
          'message: A user with this email address has already been registered',
        ),
        'That email already has an account. Go back and use Sign in.',
      );
    });

    test('wrong code', () {
      expect(
        f('Exception: No household found with that code. Double-check'),
        'No household found with that code. Double-check and try again.',
      );
    });

    test('fallback', () {
      expect(f('socket closed'), 'Something went wrong. Please try again.');
    });
  });
}
