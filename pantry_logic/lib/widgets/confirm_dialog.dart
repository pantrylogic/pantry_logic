import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Shows a confirmation dialog. Resolves to true only if the user confirms.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final p = AppPalette.of(ctx);
      return AlertDialog(
        title: Text(
          title,
          style: nsSans(
              fontSize: 17, fontWeight: FontWeight.w700, color: p.textPrimary),
        ),
        content: Text(
          message,
          style: nsSans(fontSize: 14, color: p.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(foregroundColor: p.textPrimary),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: destructive ? p.error : p.primary,
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result == true;
}

/// Confirmation used everywhere a meal can be deleted.
Future<bool> confirmDeleteMeal(BuildContext context, String mealName) =>
    showConfirmDialog(
      context,
      title: 'Delete meal?',
      message:
          'This will permanently delete "$mealName" and its ingredients.',
      confirmLabel: 'Delete',
      destructive: true,
    );
