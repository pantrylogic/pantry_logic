import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/household.dart';
import '../models/profile.dart';

class AuthService {
  static final _client = Supabase.instance.client;

  // ─── Auth state ─────────────────────────────────────────────────────────────

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;

  // ─── Sign up (full account — household creator) ──────────────────────────────

  Future<void> signUp({
    required String displayName,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );

    if (response.user == null) {
      throw Exception('Sign up failed. Please try again.');
    }

    // Trigger creates the profile row. Ensure display_name is set.
    // (Supabase may delay trigger slightly — upsert with a small guard)
    await Future.delayed(const Duration(milliseconds: 300));
    await _client.from('profiles').update({
      'display_name': displayName,
    }).eq('id', response.user!.id);
  }

  // ─── Sign in (returning full account) ────────────────────────────────────────

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  // ─── Anonymous sign-in (household joiner) ────────────────────────────────────

  Future<void> signInAnonymously({required String displayName}) async {
    final response = await _client.auth.signInAnonymously(
      data: {'display_name': displayName},
    );

    if (response.user == null) {
      throw Exception('Could not create a guest session. Please try again.');
    }

    await Future.delayed(const Duration(milliseconds: 300));
    await _client.from('profiles').update({
      'display_name': displayName,
    }).eq('id', response.user!.id);
  }

  // ─── Profile ─────────────────────────────────────────────────────────────────

  Future<Profile?> getProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (data == null) return null;
    return Profile.fromJson(data);
  }

  // ─── Create household (owner) ─────────────────────────────────────────────────

  Future<Household> createHousehold(String name) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in.');

    final code = _generateInviteCode();

    final data = await _client
        .from('households')
        .insert({'name': name.trim(), 'invite_code': code, 'created_by': userId})
        .select()
        .single();

    final household = Household.fromJson(data);

    await _client
        .from('profiles')
        .update({'household_id': household.id, 'role': 'owner'})
        .eq('id', userId);

    // Refresh the JWT so the hook re-runs and embeds the new household_id
    // into app_metadata. RLS policies read from the token, not the DB.
    await _client.auth.refreshSession();

    return household;
  }

  // ─── Join household (member via invite code) ──────────────────────────────────

  Future<Household> joinHousehold(String inviteCode) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in.');

    final data = await _client
        .from('households')
        .select()
        .eq('invite_code', inviteCode.toUpperCase().trim())
        .maybeSingle();

    if (data == null) {
      throw Exception('No household found with that code. Double-check and try again.');
    }

    final household = Household.fromJson(data);

    await _client
        .from('profiles')
        .update({'household_id': household.id, 'role': 'member'})
        .eq('id', userId);

    // Refresh the JWT so the hook re-runs and embeds the new household_id
    // into app_metadata. RLS policies read from the token, not the DB.
    await _client.auth.refreshSession();

    return household;
  }

  // ─── Upgrade anonymous → full account ────────────────────────────────────────

  Future<void> upgradeToFullAccount({
    required String email,
    required String password,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not signed in.');

    await _client.auth.updateUser(
      UserAttributes(email: email, password: password),
    );

    await _client
        .from('profiles')
        .update({'auth_type': 'full'})
        .eq('id', userId);
  }

  // ─── Sign out ────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  // 6-char uppercase code — skips visually ambiguous characters
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
