import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../models/household.dart';
import '../../models/profile.dart';
import '../../models/storage_location.dart';
import '../../models/meal_category.dart';
import '../../services/settings_service.dart';
import '../../services/auth_service.dart';
import '../auth/sign_up_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsService = SettingsService();
  final _authService = AuthService();

  Household? _household;
  Profile? _profile;
  List<Profile> _members = [];
  List<StorageLocation> _locations = [];
  List<MealCategory> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _settingsService.getHousehold(),
        _authService.getProfile(),
        _settingsService.getMembers(),
        _settingsService.getLocations(),
        _settingsService.getCategories(),
      ]);
      if (mounted) {
        setState(() {
          _household = results[0] as Household?;
          _profile = results[1] as Profile?;
          _members = results[2] as List<Profile>;
          _locations = results[3] as List<StorageLocation>;
          _categories = results[4] as List<MealCategory>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textPrimary =
            isDark ? AppColors.textPrimaryDm : AppColors.textPrimary;
        final textSecondary =
            isDark ? AppColors.textSecondaryDm : AppColors.textSecondary;
        final errorColor = isDark ? AppColors.errorDm : AppColors.error;

        return AlertDialog(
          title: Text('Sign out',
              style: nsSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textPrimary)),
          content: Text('Are you sure you want to sign out?',
              style: nsSans(fontSize: 14, color: textSecondary)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child:
                  Text('Cancel', style: nsSans(fontSize: 14, color: textPrimary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Sign out',
                  style: nsSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: errorColor)),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await _authService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SignUpScreen()),
      (_) => false,
    );
  }

  // ── Edit household name ───────────────────────────────────────────────────────

  Future<void> _editHouseholdName() async {
    final ctrl = TextEditingController(text: _household?.name ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textPrimary =
            isDark ? AppColors.textPrimaryDm : AppColors.textPrimary;
        final primary = isDark ? AppColors.primaryDm : AppColors.primary;
        return AlertDialog(
          title: Text('Household name',
              style: nsSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textPrimary)),
          content: TextField(
            controller: ctrl,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. The Smiths',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child:
                  Text('Cancel', style: nsSans(fontSize: 14, color: textPrimary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: Text('Save',
                  style: nsSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primary)),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    if (result == null || result.isEmpty) return;
    try {
      await _settingsService.updateHouseholdName(result);
      if (mounted) {
        setState(() {
          _household = _household == null
              ? null
              : Household(
                  id: _household!.id,
                  name: result,
                  inviteCode: _household!.inviteCode,
                  createdBy: _household!.createdBy,
                  createdAt: _household!.createdAt,
                );
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not update: $e')));
      }
    }
  }

  // ── Edit display name ─────────────────────────────────────────────────────────

  Future<void> _editDisplayName() async {
    final ctrl = TextEditingController(text: _profile?.displayName ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textPrimary =
            isDark ? AppColors.textPrimaryDm : AppColors.textPrimary;
        final primary = isDark ? AppColors.primaryDm : AppColors.primary;
        return AlertDialog(
          title: Text('Your name',
              style: nsSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textPrimary)),
          content: TextField(
            controller: ctrl,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Display name',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child:
                  Text('Cancel', style: nsSans(fontSize: 14, color: textPrimary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: Text('Save',
                  style: nsSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primary)),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    if (result == null || result.isEmpty) return;
    try {
      await _settingsService.updateDisplayName(result);
      if (mounted) {
        setState(() {
          _profile = _profile?.copyWith(displayName: result);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not update: $e')));
      }
    }
  }

  // ── Add / rename / delete items (shared dialog) ───────────────────────────────

  Future<String?> _showNameDialog({
    required String title,
    String? initial,
    required String hint,
  }) async {
    final ctrl = TextEditingController(text: initial ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final textPrimary =
            isDark ? AppColors.textPrimaryDm : AppColors.textPrimary;
        final primary = isDark ? AppColors.primaryDm : AppColors.primary;
        return AlertDialog(
          title: Text(title,
              style: nsSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: textPrimary)),
          content: TextField(
            controller: ctrl,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: InputDecoration(
              hintText: hint,
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child:
                  Text('Cancel', style: nsSans(fontSize: 14, color: textPrimary)),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: Text('Save',
                  style: nsSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primary)),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    return result;
  }

  // ── Locations ─────────────────────────────────────────────────────────────────

  Future<void> _addLocation() async {
    final name = await _showNameDialog(
      title: 'New location',
      hint: 'e.g. Freezer',
    );
    if (name == null || name.isEmpty) return;
    try {
      final loc = await _settingsService.addLocation(name);
      if (mounted) setState(() => _locations = [..._locations, loc]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not add: $e')));
      }
    }
  }

  Future<void> _renameLocation(StorageLocation loc) async {
    final name = await _showNameDialog(
      title: 'Rename location',
      initial: loc.name,
      hint: loc.name,
    );
    if (name == null || name.isEmpty || name == loc.name) return;
    try {
      await _settingsService.renameLocation(loc.id, name);
      if (mounted) {
        setState(() {
          _locations = _locations.map((l) {
            if (l.id != loc.id) return l;
            return StorageLocation(
              id: l.id,
              householdId: l.householdId,
              name: name,
              isDefault: l.isDefault,
              sortOrder: l.sortOrder,
            );
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not rename: $e')));
      }
    }
  }

  Future<void> _deleteLocation(StorageLocation loc) async {
    try {
      await _settingsService.deleteLocation(loc.id);
      if (mounted) {
        setState(() => _locations = _locations.where((l) => l.id != loc.id).toList());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  // ── Meal categories ───────────────────────────────────────────────────────────

  Future<void> _addCategory() async {
    final name = await _showNameDialog(
      title: 'New category',
      hint: 'e.g. Quick Meals',
    );
    if (name == null || name.isEmpty) return;
    try {
      final cat = await _settingsService.addCategory(name);
      if (mounted) setState(() => _categories = [..._categories, cat]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not add: $e')));
      }
    }
  }

  Future<void> _renameCategory(MealCategory cat) async {
    final name = await _showNameDialog(
      title: 'Rename category',
      initial: cat.name,
      hint: cat.name,
    );
    if (name == null || name.isEmpty || name == cat.name) return;
    try {
      await _settingsService.renameCategory(cat.id, name);
      if (mounted) {
        setState(() {
          _categories = _categories.map((c) {
            if (c.id != cat.id) return c;
            return MealCategory(
              id: c.id,
              householdId: c.householdId,
              name: name,
              sortOrder: c.sortOrder,
            );
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not rename: $e')));
      }
    }
  }

  Future<void> _deleteCategory(MealCategory cat) async {
    try {
      await _settingsService.deleteCategory(cat.id);
      if (mounted) {
        setState(() =>
            _categories = _categories.where((c) => c.id != cat.id).toList());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDm : AppColors.primary;
    final textPrimary =
        isDark ? AppColors.textPrimaryDm : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.textSecondaryDm : AppColors.textSecondary;
    final textMuted = isDark ? AppColors.textMutedDm : AppColors.textMuted;
    final surface = isDark ? AppColors.surfaceDm : AppColors.surface;
    final border = isDark ? AppColors.borderDm : AppColors.border;
    final errorColor = isDark ? AppColors.errorDm : AppColors.error;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings', style: nsSans(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // ── Profile section ────────────────────────────────────────────
                _SectionHeader(label: 'YOU', textMuted: textMuted),
                _SettingsTile(
                  title: 'Your name',
                  value: _profile?.displayName,
                  icon: Icons.person_outline_rounded,
                  primary: primary,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  border: border,
                  surface: surface,
                  onTap: _editDisplayName,
                ),

                // ── Household section ──────────────────────────────────────────
                _SectionHeader(label: 'HOUSEHOLD', textMuted: textMuted),
                _SettingsTile(
                  title: 'Household name',
                  value: _household?.name,
                  icon: Icons.home_outlined,
                  primary: primary,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  border: border,
                  surface: surface,
                  onTap: _profile?.isOwner == true ? _editHouseholdName : null,
                ),
                _SettingsTile(
                  title: 'Invite code',
                  value: _household?.inviteCode,
                  icon: Icons.share_outlined,
                  primary: primary,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  border: border,
                  surface: surface,
                  onTap: () {
                    final code = _household?.inviteCode;
                    if (code != null) {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite code copied')),
                      );
                    }
                  },
                ),

                // ── Members ────────────────────────────────────────────────────
                _SectionHeader(
                    label: 'MEMBERS (${_members.length})',
                    textMuted: textMuted),
                ..._members.map(
                  (member) => _MemberTile(
                    member: member,
                    isCurrentUser:
                        member.id == _authService.currentUser?.id,
                    primary: primary,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    border: border,
                    surface: surface,
                  ),
                ),

                // ── Storage locations ──────────────────────────────────────────
                _SectionHeader(
                    label: 'STORAGE LOCATIONS', textMuted: textMuted),
                ..._locations.map(
                  (loc) => _EditableTile(
                    name: loc.name,
                    isDefault: loc.isDefault,
                    primary: primary,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    textMuted: textMuted,
                    border: border,
                    surface: surface,
                    errorColor: errorColor,
                    onRename: loc.isDefault ? null : () => _renameLocation(loc),
                    onDelete: loc.isDefault ? null : () => _deleteLocation(loc),
                  ),
                ),
                _AddTile(
                  label: 'Add location',
                  primary: primary,
                  textPrimary: textPrimary,
                  border: border,
                  surface: surface,
                  onTap: _addLocation,
                ),

                // ── Meal categories ────────────────────────────────────────────
                _SectionHeader(
                    label: 'MEAL CATEGORIES', textMuted: textMuted),
                ..._categories.map(
                  (cat) => _EditableTile(
                    name: cat.name,
                    isDefault: false,
                    primary: primary,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    textMuted: textMuted,
                    border: border,
                    surface: surface,
                    errorColor: errorColor,
                    onRename: () => _renameCategory(cat),
                    onDelete: () => _deleteCategory(cat),
                  ),
                ),
                _AddTile(
                  label: 'Add category',
                  primary: primary,
                  textPrimary: textPrimary,
                  border: border,
                  surface: surface,
                  onTap: _addCategory,
                ),

                const SizedBox(height: 32),

                // ── Sign out ───────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton(
                    onPressed: _signOut,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: errorColor.withValues(alpha: 0.5)),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Sign out',
                      style: nsSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: errorColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color textMuted;

  const _SectionHeader({required this.label, required this.textMuted});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
      child: Text(
        label,
        style: nsSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: textMuted,
        ),
      ),
    );
  }
}

// ── Settings tile ──────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final String title;
  final String? value;
  final IconData icon;
  final Color primary;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color surface;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
    this.value,
    required this.icon,
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.surface,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: nsSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: textPrimary)),
                  if (value != null)
                    Text(value!,
                        style: nsSans(fontSize: 13, color: textSecondary)),
                ],
              ),
            ),
            if (onTap != null)
              Icon(Icons.chevron_right_rounded, size: 18, color: textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Member tile ────────────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final Profile member;
  final bool isCurrentUser;
  final Color primary;
  final Color textPrimary;
  final Color textSecondary;
  final Color border;
  final Color surface;

  const _MemberTile({
    required this.member,
    required this.isCurrentUser,
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
    required this.border,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: primary.withValues(alpha: 0.15),
            child: Text(
              member.displayName.isNotEmpty
                  ? member.displayName[0].toUpperCase()
                  : '?',
              style: nsSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              member.displayName + (isCurrentUser ? ' (you)' : ''),
              style: nsSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textPrimary),
            ),
          ),
          Text(
            member.role ?? '',
            style: nsSans(fontSize: 12, color: textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Editable list tile ─────────────────────────────────────────────────────────

class _EditableTile extends StatelessWidget {
  final String name;
  final bool isDefault;
  final Color primary;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color surface;
  final Color errorColor;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;

  const _EditableTile({
    required this.name,
    required this.isDefault,
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.surface,
    required this.errorColor,
    this.onRename,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: nsSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary)),
                if (isDefault)
                  Text('Default',
                      style: nsSans(fontSize: 12, color: textMuted)),
              ],
            ),
          ),
          if (!isDefault) ...[
            GestureDetector(
              onTap: onRename,
              child: Icon(Icons.edit_outlined, size: 18, color: textSecondary),
            ),
            const SizedBox(width: 16),
            GestureDetector(
              onTap: onDelete,
              child: Icon(Icons.delete_outline_rounded,
                  size: 18, color: errorColor.withValues(alpha: 0.7)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Add tile ───────────────────────────────────────────────────────────────────

class _AddTile extends StatelessWidget {
  final String label;
  final Color primary;
  final Color textPrimary;
  final Color border;
  final Color surface;
  final VoidCallback onTap;

  const _AddTile({
    required this.label,
    required this.primary,
    required this.textPrimary,
    required this.border,
    required this.surface,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline_rounded, size: 20, color: primary),
            const SizedBox(width: 12),
            Text(label,
                style: nsSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: primary)),
          ],
        ),
      ),
    );
  }
}
