import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/meal_category.dart';
import 'app_sheet.dart';

/// Lets the user pick a meal category. Resolves to the chosen category id,
/// or null if dismissed. [selectedId] defaults to the first category.
Future<String?> showCategoryPicker(
  BuildContext context, {
  required List<MealCategory> categories,
  String? selectedId,
  required String title,
  String? subtitle,
  required String confirmLabel,
}) {
  return showAppSheet<String>(
    context: context,
    builder: (_) => _CategoryPickerSheet(
      categories: categories,
      initialId: selectedId ??
          (categories.isNotEmpty ? categories.first.id : null),
      title: title,
      subtitle: subtitle,
      confirmLabel: confirmLabel,
    ),
  );
}

class _CategoryPickerSheet extends StatefulWidget {
  const _CategoryPickerSheet({
    required this.categories,
    required this.initialId,
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
  });

  final List<MealCategory> categories;
  final String? initialId;
  final String title;
  final String? subtitle;
  final String confirmLabel;

  @override
  State<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends State<_CategoryPickerSheet> {
  late String? _selected = widget.initialId;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return AppSheet(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.subtitle != null) ...[
            Text(
              widget.subtitle!,
              style: nsSans(fontSize: 14, color: p.textMuted),
            ),
            const SizedBox(height: 8),
          ],
          RadioGroup<String>(
            groupValue: _selected,
            onChanged: (v) => setState(() => _selected = v),
            child: Column(
              children: [
                for (final c in widget.categories)
                  RadioListTile<String>(
                    value: c.id,
                    contentPadding: EdgeInsets.zero,
                    activeColor: p.primary,
                    title: Text(
                      c.name,
                      style: nsSans(
                        fontSize: 15,
                        fontWeight: c.id == _selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _selected == null
                ? null
                : () => Navigator.of(context).pop(_selected),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: Text(widget.confirmLabel),
          ),
        ],
      ),
    );
  }
}
