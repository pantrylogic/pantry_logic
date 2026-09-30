import 'package:flutter/material.dart';

import '../../core/meal_status.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/meal.dart';
import '../../models/meal_category.dart';
import '../../models/meal_need_item.dart';
import '../../services/meal_service.dart';
import '../../widgets/add_bar.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/category_picker_sheet.dart';
import '../../widgets/confirm_dialog.dart';
import '../hungry/restock_screen.dart';

class MealDetailScreen extends StatefulWidget {
  final Meal meal;
  const MealDetailScreen({super.key, required this.meal});

  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  final _service = MealService();
  late final Stream<List<MealNeedItem>> _stream;
  List<MealCategory> _categories = [];

  // Local copies of mutable meal fields — updated optimistically after edits.
  late String _name;
  late String? _categoryId;
  late String? _categoryName;
  late String? _notes;

  bool _suggestionsShowing = false;

  /// Ingredients removed optimistically (swipe) before the stream catches up.
  final Set<String> _hiddenItemIds = {};

  String get _mealId => widget.meal.id;

  @override
  void initState() {
    super.initState();
    _name = widget.meal.name;
    _categoryId = widget.meal.categoryId;
    _categoryName = widget.meal.categoryName;
    _notes = widget.meal.notes;
    _stream = _service.streamNeedList(_mealId).asBroadcastStream();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _service.getCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (e, st) {
      logError('Load meal categories', e, st);
    }
  }

  // ── Ingredients ─────────────────────────────────────────────────────────

  Future<void> _addIngredient({
    required String name,
    String? itemId,
    String? category,
    String? defaultLocation,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final resolvedId = itemId ??
          (await _service.getOrCreateItem(
            name: name,
            category: category,
            defaultLocation: defaultLocation,
          ))
              .id;
      await _service.addNeedItem(mealId: _mealId, itemId: resolvedId);
      if (mounted) setState(() => _hiddenItemIds.remove(resolvedId));
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not add $name. Try again.', e, st);
    }
  }

  Future<void> _removeIngredient(MealNeedItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _hiddenItemIds.add(item.itemId));
    try {
      await _service.removeNeedItem(mealId: _mealId, itemId: item.itemId);
    } catch (e, st) {
      if (mounted) setState(() => _hiddenItemIds.remove(item.itemId));
      showErrorSnackBar(messenger, 'Could not remove ${item.itemName}.', e, st);
      return;
    }
    showUndoSnackBar(
      messenger,
      '${item.itemName} removed from ingredients.',
      onUndo: () => _addIngredient(name: item.itemName, itemId: item.itemId),
    );
  }

  Future<void> _addMissingToGrocery() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await _service.addMissingToGroceryList(_mealId);
      showAppSnackBar(
        messenger,
        count == 0
            ? 'Everything missing is already on the grocery list.'
            : '$count item${count == 1 ? '' : 's'} added to the grocery list.',
      );
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not add to the grocery list.', e, st);
    }
  }

  // ── Meal edits ──────────────────────────────────────────────────────────

  Future<void> _rename() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showAppSheet<String>(
      context: context,
      builder: (_) => _TextEditSheet(
        title: 'Rename meal',
        label: 'Meal name',
        initialText: _name,
      ),
    );
    final newName = result?.trim() ?? '';
    if (newName.isEmpty || newName == _name) return;
    try {
      await _service.updateMeal(_mealId, name: newName);
      if (mounted) setState(() => _name = newName);
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not rename the meal.', e, st);
    }
  }

  Future<void> _changeCategory() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_categories.isEmpty) await _loadCategories();
    if (!mounted || _categories.isEmpty) return;
    final id = await showCategoryPicker(
      context,
      categories: _categories,
      selectedId: _categoryId,
      title: 'Category',
      confirmLabel: 'Save',
    );
    if (id == null || id == _categoryId) return;
    try {
      await _service.updateMeal(_mealId, categoryId: id);
      final cat = _categories.firstWhere((c) => c.id == id);
      if (mounted) {
        setState(() {
          _categoryId = cat.id;
          _categoryName = cat.name;
        });
      }
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not update the category.', e, st);
    }
  }

  Future<void> _editNotes() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showAppSheet<String>(
      context: context,
      builder: (_) => _TextEditSheet(
        title: 'Notes',
        label: 'Notes',
        hint: 'e.g. serves 4, 30 min at 180°',
        initialText: _notes ?? '',
        maxLines: 5,
      ),
    );
    if (result == null) return;
    final newNotes = result.trim().isEmpty ? null : result.trim();
    try {
      await _service.updateMeal(
        _mealId,
        notes: newNotes ?? '',
        clearNotes: newNotes == null,
      );
      if (mounted) setState(() => _notes = newNotes);
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not save notes.', e, st);
    }
  }

  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    if (!await confirmDeleteMeal(context, _name)) return;
    try {
      await _service.deleteMeal(_mealId);
      navigator.pop();
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not delete the meal.', e, st);
    }
  }

  void _eatThis() {
    Navigator.of(context).push(MaterialPageRoute(
      settings: AppRoutes.settings(AppRoutes.restock),
      builder: (_) => RestockScreen(mealId: _mealId, mealName: _name),
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_name),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Meal options',
            onSelected: (v) {
              switch (v) {
                case 'rename':
                  _rename();
                case 'category':
                  _changeCategory();
                case 'notes':
                  _editNotes();
                case 'delete':
                  _delete();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename meal')),
              const PopupMenuItem(
                  value: 'category', child: Text('Change category')),
              PopupMenuItem(
                value: 'notes',
                child: Text(_notes != null ? 'Edit notes' : 'Add notes'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Delete meal',
                  style: nsSans(color: p.error, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<MealNeedItem>>(
        stream: _stream,
        builder: (ctx, snap) {
          final items = (snap.data ?? [])
              .where((i) => !_hiddenItemIds.contains(i.itemId))
              .toList();
          final missingCount = items.where((i) => !i.inPantry).length;
          final loading =
              snap.connectionState == ConnectionState.waiting && !snap.hasData;

          return Column(
            children: [
              _MealInfo(
                categoryName: _categoryName,
                notes: _notes,
                onCategoryTap: _changeCategory,
                onNotesTap: _editNotes,
              ),
              _IngredientsHeader(
                count: items.length,
                missingCount: missingCount,
                onAddMissing: _addMissingToGrocery,
              ),
              Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : items.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Text(
                                'No ingredients yet.\n'
                                'Use the bar below to add some.',
                                textAlign: TextAlign.center,
                                style: nsSans(
                                  fontSize: 14,
                                  color: p.textMuted,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 8),
                            itemCount: items.length,
                            separatorBuilder: (ctx2, i2) => Divider(
                              height: 1,
                              indent: 52,
                              endIndent: 16,
                              color: p.border,
                            ),
                            itemBuilder: (_, i) => _IngredientRow(
                              item: items[i],
                              onRemove: () => _removeIngredient(items[i]),
                            ),
                          ),
              ),
              if (items.isNotEmpty && !_suggestionsShowing)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: BoxDecoration(
                    color: p.surface,
                    border: Border(top: BorderSide(color: p.border, width: 0.5)),
                  ),
                  child: FilledButton.icon(
                    onPressed: _eatThis,
                    icon: const Icon(Icons.restaurant_rounded, size: 20),
                    label: const Text('Eat This'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                  ),
                ),
              AddBar(
                hintText: 'Add ingredient…',
                search: _service.searchAutocomplete,
                onSuggestionsVisibilityChanged: (v) =>
                    setState(() => _suggestionsShowing = v),
                onSubmit: (name) => _addIngredient(name: name),
                onSuggestion: (s) => _addIngredient(
                  name: s.name,
                  itemId: s.itemId,
                  category: s.category,
                  defaultLocation: s.defaultLocation,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Header: category + notes ────────────────────────────────────────────────

class _MealInfo extends StatelessWidget {
  const _MealInfo({
    required this.categoryName,
    required this.notes,
    required this.onCategoryTap,
    required this.onNotesTap,
  });

  final String? categoryName;
  final String? notes;
  final VoidCallback onCategoryTap;
  final VoidCallback onNotesTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category pill (or an "Add category" affordance)
          Material(
            color: categoryName != null ? p.accentLight : Colors.transparent,
            shape: StadiumBorder(
              side: categoryName != null
                  ? BorderSide.none
                  : BorderSide(color: p.border, width: 1.5),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onCategoryTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      categoryName != null
                          ? Icons.sell_outlined
                          : Icons.add_rounded,
                      size: 14,
                      color: categoryName != null
                          ? (p.isDark ? p.textPrimary : p.primary)
                          : p.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      categoryName ?? 'Add category',
                      style: nsSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: categoryName != null
                            ? (p.isDark ? p.textPrimary : p.primary)
                            : p.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Notes (or an "Add notes" affordance)
          InkWell(
            onTap: onNotesTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      notes != null
                          ? Icons.notes_rounded
                          : Icons.edit_note_rounded,
                      size: 18,
                      color: p.textMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      notes ?? 'Add notes',
                      style: nsSans(
                        fontSize: 14,
                        color: notes != null ? p.textSecondary : p.textMuted,
                        fontWeight:
                            notes != null ? FontWeight.w400 : FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientsHeader extends StatelessWidget {
  const _IngredientsHeader({
    required this.count,
    required this.missingCount,
    required this.onAddMissing,
  });

  final int count;
  final int missingCount;
  final VoidCallback onAddMissing;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Row(
        children: [
          Text(
            'INGREDIENTS',
            style: nsSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: p.textMuted,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Text(
              '$count',
              style: nsSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: p.textMuted,
              ),
            ),
          ],
          const Spacer(),
          if (missingCount > 0)
            TextButton.icon(
              onPressed: onAddMissing,
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
              label: Text('Add $missingCount missing'),
              style: TextButton.styleFrom(
                foregroundColor: p.warningText,
                visualDensity: VisualDensity.compact,
                textStyle: nsSans(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            )
          else
            const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.item, required this.onRemove});

  final MealNeedItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final status = IngredientStatus(item.inventoryLocation);
    final color = status.color(p);

    return Dismissible(
      key: ValueKey(item.itemId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: p.error.withValues(alpha: 0.12),
        child: Icon(Icons.delete_outline_rounded, color: p.error, size: 22),
      ),
      onDismissed: (_) => onRemove(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(status.icon, size: 22, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itemName,
                    style: nsSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    status.label,
                    style: nsSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Text edit sheet ─────────────────────────────────────────────────────────
// StatefulWidget so it owns + disposes the TextEditingController at the
// right point in the widget lifecycle (avoids "controller used after disposed"
// when the sheet's close animation outlives the Future that created the ctrl).

class _TextEditSheet extends StatefulWidget {
  const _TextEditSheet({
    required this.title,
    required this.label,
    required this.initialText,
    this.hint,
    this.maxLines = 1,
  });

  final String title;
  final String label;
  final String initialText;
  final String? hint;
  final int maxLines;

  @override
  State<_TextEditSheet> createState() => _TextEditSheetState();
}

class _TextEditSheetState extends State<_TextEditSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialText);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AppSheet(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            minLines: 1,
            maxLines: widget.maxLines,
            textCapitalization: TextCapitalization.sentences,
            style: nsSans(fontSize: 15, color: p.textPrimary),
            decoration: InputDecoration(
              labelText: widget.label,
              hintText: widget.hint,
            ),
            onSubmitted: widget.maxLines == 1
                ? (v) => Navigator.of(context).pop(v)
                : null,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_ctrl.text),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
