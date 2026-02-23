import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_text_field.dart';
import '../home/home_screen.dart';
import 'sign_up_screen.dart';

class JoinHouseholdScreen extends StatefulWidget {
  const JoinHouseholdScreen({super.key});

  @override
  State<JoinHouseholdScreen> createState() => _JoinHouseholdScreenState();
}

class _JoinHouseholdScreenState extends State<JoinHouseholdScreen> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'What should we call you?');
      return;
    }
    if (code.isEmpty) {
      setState(() => _error = 'Enter the household code.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Anonymous sign in first
      await _authService.signInAnonymously(displayName: name);
      // Then join the household
      await _authService.joinHousehold(code);

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (e) {
      // Sign out if something went wrong mid-flow
      try {
        await _authService.signOut();
      } catch (_) {}

      if (!mounted) return;
      setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('not found') || raw.contains('No household')) {
      return 'No household found with that code. Double-check and try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDm : AppColors.primary;
    final textSecondary =
        isDark ? AppColors.textSecondaryDm : AppColors.textSecondary;
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
                      Icon(Icons.arrow_back_ios_new_rounded,
                          size: 14, color: primary),
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

              const Text('🏠', style: TextStyle(fontSize: 40)),
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
                'Enter the code from someone in your household.',
                textAlign: TextAlign.center,
                style: nsSans(
                  fontSize: 14,
                  color: textSecondary,
                  height: 1.5,
                ),
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
                  color: isDark ? AppColors.textPrimaryDm : AppColors.textPrimary,
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
                style: nsSans(
                  fontSize: 14,
                  color: textSecondary,
                ),
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
                'You\'ll be asked to create an account later\nif you want access across devices.',
                textAlign: TextAlign.center,
                style: nsSans(
                  fontSize: 12,
                  color: textMuted,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
