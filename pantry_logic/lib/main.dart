import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme.dart';
import 'models/profile.dart';
import 'services/auth_service.dart';
import 'screens/auth/sign_up_screen.dart';
import 'screens/auth/create_household_screen.dart';
import 'screens/shell/main_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://jnketipluuuwljsykczy.supabase.co',
    anonKey: 'sb_publishable_m4Tu7M8mPoVFV_f9KdOchg_TZBnk8hL',
  );

  runApp(const PantryLogicApp());
}

class PantryLogicApp extends StatelessWidget {
  const PantryLogicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pantry Logic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      // Inject NotoColorEmoji into the ambient DefaultTextStyle so every
      // Text widget (including those with a bare TextStyle(fontSize:x)) can
      // fall back to the bundled emoji font for emoji characters.
      builder: (context, child) => DefaultTextStyle.merge(
        style: const TextStyle(fontFamilyFallback: ['NotoColorEmoji']),
        child: child!,
      ),
      home: const _AuthGate(),
    );
  }
}

// ─── Auth gate ────────────────────────────────────────────────────────────────
//
// Determines where to send the user on app launch / after sign-out.
// This widget is always the root of the stack. Individual flow screens
// push themselves on top and clear the stack when they complete.

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  final _authService = AuthService();

  bool _initialising = true;
  bool _loadingProfile = false;
  Session? _session;
  Profile? _profile;

  @override
  void initState() {
    super.initState();
    _init();

    // Listen for auth state changes (sign-in, sign-out, token refresh)
    Supabase.instance.client.auth.onAuthStateChange.listen(_onAuthChange);
  }

  Future<void> _init() async {
    _session = Supabase.instance.client.auth.currentSession;

    if (_session != null) {
      _profile = await _authService.getProfile();
    }

    if (mounted) setState(() => _initialising = false);
  }

  Future<void> _onAuthChange(AuthState state) async {
    if (!mounted) return;

    switch (state.event) {
      case AuthChangeEvent.signedIn:
      case AuthChangeEvent.userUpdated:
        if (mounted) {
          setState(() {
            _session = state.session;
            _loadingProfile = true;
          });
        }
        final profile = await _authService.getProfile();
        if (mounted) {
          setState(() {
            _profile = profile;
            _loadingProfile = false;
          });
        }
        break;

      case AuthChangeEvent.signedOut:
        if (mounted) {
          setState(() {
            _session = null;
            _profile = null;
          });
        }
        break;

      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialising || _loadingProfile) {
      return const _SplashScreen();
    }

    // Not signed in → sign up / join landing
    if (_session == null) {
      return const SignUpScreen();
    }

    // Signed in but no household yet → create household step
    if (_profile == null || !_profile!.hasHousehold) {
      return const CreateHouseholdScreen();
    }

    // Signed in with a household → main app
    return const MainShell();
  }
}

// ─── Splash / loading screen ──────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDm : AppColors.primary;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🫙', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
