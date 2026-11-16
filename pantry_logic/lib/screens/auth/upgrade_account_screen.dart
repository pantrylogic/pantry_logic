import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_text_field.dart';
import '../../widgets/brand.dart';

/// Lets a guest (anonymous) member add an email and password so they can sign
/// back in later. Keeps the same member, so everything they added stays theirs.
/// Pops with `true` once the account has been upgraded.
class UpgradeAccountScreen extends StatefulWidget {
  const UpgradeAccountScreen({super.key});

  /// Returns a message if the form is invalid, otherwise null.
  static String? validate(String email, String password, String confirm) {
    if (email.isEmpty || password.isEmpty || confirm.isEmpty) {
      return 'Please fill in all fields.';
    }
    if (!email.contains('@') || !email.contains('.')) {
      return 'Please enter a valid email address.';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters.';
    }
    if (password != confirm) {
      return "Passwords don't match.";
    }
    return null;
  }

  @override
  State<UpgradeAccountScreen> createState() => _UpgradeAccountScreenState();
}

class _UpgradeAccountScreenState extends State<UpgradeAccountScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    final email = _emailCtrl.text.trim();
    final problem = UpgradeAccountScreen.validate(
      email,
      _passwordCtrl.text,
      _confirmCtrl.text,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.upgradeToFullAccount(
        email: email,
        password: _passwordCtrl.text,
      );
      messenger.showSnackBar(
        const SnackBar(content: Text('Account created. You can now sign in.')),
      );
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('already registered') || raw.contains('already exists')) {
      return 'That email is already in use.';
    }
    if (raw.contains('invalid') && raw.contains('email')) {
      return 'Please enter a valid email address.';
    }
    if (raw.contains('weak') || raw.contains('Password')) {
      return 'Please choose a stronger password.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDm : AppColors.primary;
    final textSecondary = isDark
        ? AppColors.textSecondaryDm
        : AppColors.textSecondary;
    final errorColor = isDark ? AppColors.errorDm : AppColors.error;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const BrandLogo(size: 72),
              const SizedBox(height: 8),
              Text(
                'Create your account',
                style: nsSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Add an email and password so you can sign back in on any '
                "device. You stay in the same household and keep everything "
                "you've added.",
                textAlign: TextAlign.center,
                style: nsSans(fontSize: 14, color: textSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: errorColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: nsSans(fontSize: 13, color: errorColor),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              AuthTextField(
                controller: _emailCtrl,
                placeholder: 'Email',
                keyboardType: TextInputType.emailAddress,
                autofocus: true,
              ),
              const SizedBox(height: 10),
              AuthTextField(
                controller: _passwordCtrl,
                placeholder: 'Password',
                obscureText: true,
              ),
              const SizedBox(height: 10),
              AuthTextField(
                controller: _confirmCtrl,
                placeholder: 'Confirm password',
                obscureText: true,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
