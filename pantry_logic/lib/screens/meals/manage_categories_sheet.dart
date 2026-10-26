import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/meal_category.dart';
import '../../services/meal_service.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/confirm_dialog.dart';

/// Add, rename and delete meal categories. Resolves once the sheet closes;
/// callers should reload categories afterwards.
Future<void> showManageCategoriesSheet(
  BuildContext context, {
  required List<MealCategory> categories,
  required Map<String, int> mealCounts,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (_) =>
        _ManageCategoriesSheet(categories: categories, mealCounts: mealCounts),
  );
}

class _ManageCategoriesSheet extends StatefulWidget {
  const _ManageCategoriesSheet({
    required this.categories,
    required this.mealCounts,
  });

  final List<MealCategory> categories;
  final Map<String, int> mealCounts;

  @override
  State<_ManageCategoriesSheet> createState() => _ManageCategoriesSheetState();
}

class _ManageCategoriesSheetState extends State<_ManageCategoriesSheet> {
  final _service = MealService();
  late List<MealCategory> _categories = [...widget.categories];

  bool _nameTaken(String name, {String? exceptId}) => _categories.any(
    (c) => c.id != exceptId && c.name.toLowerCase() == name.toLowerCase(),
  );

  Future<void> _add() async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await _showNameDialog(title: 'New category');
    if (name == null || name.isEmpty) return;
    if (_nameTaken(name)) {
      showAppSnackBar(messenger, '"$name" already exists.');
      return;
    }
    try {
      final cat = await _service.addCategory(name);
      if (mounted) setState(() => _categories = [..._categories, cat]);
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not add $name.', e, st);
    }
  }

  Future<void> _rename(MealCategory cat) async {
    final messenger = ScaffoldMessenger.of(context);
    final name = await _showNameDialog(
      title: 'Rename category',
      initial: cat.name,
    );
    if (name == null || name.isEmpty || name == cat.name) return;
    if (_nameTaken(name, exceptId: cat.id)) {
      showAppSnackBar(messenger, '"$name" already exists.');
      return;
    }
    try {
      await _service.renameCategory(cat.id, name);
      if (!mounted) return;
      setState(() {
        _categories = [
          for (final c in _categories)
            c.id == cat.id
                ? MealCategory(
                    id: c.id,
                    householdId: c.householdId,
                    name: name,
                    sortOrder: c.sortOrder,
                  )
                : c,
        ];
      });
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not rename ${cat.name}.', e, st);
    }
  }

  Future<void> _delete(MealCategory cat) async {
    final messenger = ScaffoldMessenger.of(context);
    final count = widget.mealCounts[cat.id] ?? 0;
    final ok = await showConfirmDialog(
      context,
      title: 'Delete "${cat.name}"?',
      message: count == 0
          ? 'This category has no meals.'
          : 'Its $count meal${count == 1 ? '' : 's'} will be kept and '
                'moved to Uncategorized.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    try {
      await _service.deleteCategory(cat.id);
      if (mounted) {
        setState(
          () => _categories = _categories.where((c) => c.id != cat.id).toList(),
        );
      }
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not delete ${cat.name}.', e, st);
    }
  }

  Future<String?> _showNameDialog({
    required String title,
    String? initial,
  }) async {
    final ctrl = TextEditingController(text: initial ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final p = AppPalette.of(ctx);
        return AlertDialog(
          title: Text(
            title,
            style: nsSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          content: TextField(
            controller: ctrl,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'e.g. Quick Meals'),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              style: TextButton.styleFrom(foregroundColor: p.textPrimary),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              style: TextButton.styleFrom(foregroundColor: p.primary),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return AppSheet(
      title: 'Meal categories',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_categories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No categories yet.',
                style: nsSans(fontSize: 14, color: p.textMuted),
              ),
            ),
          for (final cat in _categories)
            ListTile(
              contentPadding: const EdgeInsets.only(left: 4),
              title: Text(
                cat.name,
                style: nsSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: p.textPrimary,
                ),
              ),
              subtitle: Text(
                _countLabel(widget.mealCounts[cat.id] ?? 0),
                style: nsSans(fontSize: 12, color: p.textMuted),
              ),
              onTap: () => _rename(cat),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Rename',
                    icon: Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: p.textSecondary,
                    ),
                    onPressed: () => _rename(cat),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: p.error,
                    ),
                    onPressed: () => _delete(cat),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add category'),
          ),
        ],
      ),
    );
  }

  static String _countLabel(int n) => '$n meal${n == 1 ? '' : 's'}';
}
