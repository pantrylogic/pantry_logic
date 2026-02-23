import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../models/household.dart';
import '../../services/auth_service.dart';
import '../../widgets/auth_text_field.dart';
import '../home/home_screen.dart';

class CreateHouseholdScreen extends StatefulWidget {
  const CreateHouseholdScreen({super.key});

  @override
  State<CreateHouseholdScreen> createState() => _CreateHouseholdScreenState();
}

class _CreateHouseholdScreenState extends State<CreateHouseholdScreen> {
  final _nameCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  String? _error;
  Household? _createdHousehold;
  bool _codeCopied = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _createHousehold() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give your household a name.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final household = await _authService.createHousehold(name);
      if (!mounted) return;
      setState(() => _createdHousehold = household);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Could not create household. Please try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copyCode() {
    final code = _createdHousehold?.inviteCode ?? '';
    Clipboard.setData(ClipboardData(text: code));
    setState(() => _codeCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _codeCopied = false);
    });
  }

  void _goToApp() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDm : AppColors.primary;
    final textSecondary =
        isDark ? AppColors.textSecondaryDm : AppColors.textSecondary;
    final textMuted = isDark ? AppColors.textMutedDm : AppColors.textMuted;
    final accentLight = isDark ? AppColors.accentLightDm : AppColors.accentLight;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: _createdHousehold == null
              ? _buildNameStep(
                  isDark, primary, textSecondary, textMuted)
              : _buildCodeStep(
                  isDark, primary, textSecondary, accentLight),
        ),
      ),
    );
  }

  // ── Step 1: Name the household ─────────────────────────────────────────────

  Widget _buildNameStep(
    bool isDark,
    Color primary,
    Color textSecondary,
    Color textMuted,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('🏠', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 8),

        Text(
          'Name your household',
          style: nsSans(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
        ),
        const SizedBox(height: 8),

        Text(
          'This is how your household will appear in the app.',
          textAlign: TextAlign.center,
          style: nsSans(
            fontSize: 14,
            color: textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 36),

        if (_error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color:
                  (isDark ? AppColors.errorDm : AppColors.error).withValues(alpha: 0.1),
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

        AuthTextField(
          controller: _nameCtrl,
          placeholder: 'e.g. The Johnson House',
          textCapitalization: TextCapitalization.words,
          autofocus: true,
          onSubmitted: (_) => _createHousehold(),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _loading ? null : _createHousehold,
            child: _loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Create Household'),
          ),
        ),
      ],
    );
  }

  // ── Step 2: Show invite code ───────────────────────────────────────────────

  Widget _buildCodeStep(
    bool isDark,
    Color primary,
    Color textSecondary,
    Color accentLight,
  ) {
    final code = _createdHousehold!.inviteCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text('✅', style: TextStyle(fontSize: 40)),
        const SizedBox(height: 8),

        Text(
          _createdHousehold!.name,
          style: nsSans(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        Text(
          'Your household is ready. Share this code with your family.',
          textAlign: TextAlign.center,
          style: nsSans(
            fontSize: 14,
            color: textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),

        // Invite code display
        GestureDetector(
          onTap: _copyCode,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
            decoration: BoxDecoration(
              color: accentLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              code,
              style: nsSans(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 6,
                color: primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Copy button
        TextButton.icon(
          onPressed: _copyCode,
          icon: Icon(
            _codeCopied ? Icons.check : Icons.copy_rounded,
            size: 16,
            color: primary,
          ),
          label: Text(
            _codeCopied ? 'Copied!' : 'Copy code',
            style: nsSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _goToApp,
            child: const Text('Go to app'),
          ),
        ),
      ],
    );
  }
}
