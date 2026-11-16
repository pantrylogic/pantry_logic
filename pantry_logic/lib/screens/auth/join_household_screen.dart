import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_text_field.dart';
import '../shell/main_shell.dart';
import 'sign_up_screen.dart';
import '../../widgets/brand.dart';

class JoinHouseholdScreen extends StatefulWidget {
  const JoinHouseholdScreen({super.key});

  /// Returns a message if the form is invalid, otherwise null.
  static String? validate({
    required String name,
    required String email,
    required String password,
    required String code,
  }) {
    if (name.isEmpty) return 'What should we call you?';
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      return 'Please enter a valid email address.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    if (code.isEmpty) return 'Enter the household code.';
    return null;
  }

  /// Turns an auth / join error into something a person can act on.
  static String friendlyError(String raw) {
    final e = raw.toLowerCase();
    if (e.contains('already been registered') ||
        e.contains('already registered') ||
        e.contains('email_exists') ||
        e.contains('user_already_exists')) {
      return 'That email already has an account. Go back and use Sign in.';
    }
    if (e.contains('not found') || e.contains('no household')) {
      return 'No household found with that code. Double-check and try again.';
    }
    if (e.contains('already in a household')) {
      return 'You are already in a household.';
    }
    if (e.contains('weak') || e.contains('password')) {
      return 'Please choose a stronger password.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  State<JoinHouseholdScreen> createState() => _JoinHouseholdScreenState();
}

class _JoinHouseholdScreenState extends State<JoinHouseholdScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final code = _codeCtrl.text.trim();

    final problem = JoinHouseholdScreen.validate(
      name: name,
      email: email,
      password: password,
      code: code,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Create the account unless an earlier attempt already did (for
      // example the code was wrong): then just retry the join.
      if (_authService.currentUser == null) {
        await _authService.signUp(
          displayName: name,
          email: email,
          password: password,
        );
      }
      await _authService.joinHousehold(code);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = JoinHouseholdScreen.friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDm : AppColors.primary;
    final textSecondary = isDark
        ? AppColors.textSecondaryDm
        : AppColors.textSecondary;
    final textMuted = isDark ? AppColors.textMutedDm : AppColors.textMuted;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Back
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 14,
                        color: primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Back',
                        style: nsSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              const IconBadge(Icons.group_add_rounded, size: 56),
              const SizedBox(height: 8),

              Text(
                'Join a Household',
                style: nsSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Create your account and enter the code from someone in your household.',
                textAlign: TextAlign.center,
                style: nsSans(fontSize: 14, color: textSecondary, height: 1.5),
              ),
              const SizedBox(height: 36),

              // Error
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.errorDm : AppColors.error)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: nsSans(
                      fontSize: 13,
                      color: isDark ? AppColors.errorDm : AppColors.error,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Display name
              AuthTextField(
                controller: _nameCtrl,
                placeholder: 'Your name',
                textCapitalization: TextCapitalization.words,
                autofocus: true,
              ),
              const SizedBox(height: 10),

              AuthTextField(
                controller: _emailCtrl,
                placeholder: 'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 10),

              AuthTextField(
                controller: _passwordCtrl,
                placeholder: 'Password',
                obscureText: true,
              ),
              const SizedBox(height: 10),

              // Invite code — centred, larger text
              AuthTextField(
                controller: _codeCtrl,
                placeholder: 'Household code',
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: nsSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                  color: isDark
                      ? AppColors.textPrimaryDm
                      : AppColors.textPrimary,
                ),
                onSubmitted: (_) => _join(),
              ),
              const SizedBox(height: 16),

              // Join button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _join,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Join'),
                ),
              ),
              const SizedBox(height: 32),

              // Divider + create own
              Text(
                'Starting your own household?',
                style: nsSans(fontSize: 14, color: textSecondary),
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const SignUpScreen(),
                          ),
                        ),
                  child: const Text('Create a New Home'),
                ),
              ),
              const SizedBox(height: 24),

              Text(
                'Already have an account?\nGo back and use Sign in.',
                textAlign: TextAlign.center,
                style: nsSans(fontSize: 12, color: textMuted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
