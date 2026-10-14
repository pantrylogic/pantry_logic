import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/meal_status.dart';
import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/meal.dart';
import '../../models/meal_category.dart';
import '../../models/meal_need_item.dart';
import '../../models/meal_step.dart';
import '../../services/meal_service.dart';
import '../../widgets/add_bar.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/category_picker_sheet.dart';
import '../../widgets/confirm_dialog.dart';
import '../hungry/restock_screen.dart';

enum _DetailTab { ingredients, directions }

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

  _DetailTab _tab = _DetailTab.ingredients;

  /// Ingredients removed optimistically (swipe) before the stream catches up.
  final Set<String> _hiddenItemIds = {};

  // Directions. [_steps] mirrors the stream; local edits (add, reorder,
  // delete) are applied to it straight away and the stream reconciles.
  StreamSubscription<List<MealStep>>? _stepsSub;
  List<MealStep> _steps = [];
  bool _stepsLoaded = false;
  bool _stepsError = false;
  final Set<String> _hiddenStepIds = {};

  String get _mealId => widget.meal.id;

  @override
  void initState() {
    super.initState();
    _name = widget.meal.name;
    _categoryId = widget.meal.categoryId;
    _categoryName = widget.meal.categoryName;
    _stream = _service.streamNeedList(_mealId).asBroadcastStream();
    _stepsSub = _service.streamSteps(_mealId).listen(
      (steps) {
        if (!mounted) return;
        setState(() {
          _steps = steps;
          _stepsLoaded = true;
          _stepsError = false;
        });
      },
      onError: (Object e, StackTrace st) {
        logError('Load meal steps', e, st);
        if (mounted) setState(() => _stepsError = true);
      },
    );
    _loadCategories();
  }

  @override
  void dispose() {
    _stepsSub?.cancel();
    super.dispose();
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

  // ── Directions ──────────────────────────────────────────────────────────

  List<MealStep> get _visibleSteps =>
      _steps.where((s) => !_hiddenStepIds.contains(s.id)).toList();

  Future<void> _addStep(String text) async {
    final messenger = ScaffoldMessenger.of(context);
    final position = _steps.isEmpty
        ? 0
        : _steps.map((s) => s.position).reduce((a, b) => a > b ? a : b) + 1;
    try {
      final step = await _service.addStep(
          mealId: _mealId, text: text, position: position);
      // Show it now; the stream may still be re-fetching.
      if (mounted && !_steps.any((s) => s.id == step.id)) {
        setState(() => _steps = [..._steps, step]);
      }
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not add the step. Try again.', e, st);
    }
  }

  Future<void> _deleteStep(MealStep step) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _hiddenStepIds.add(step.id));
    try {
      await _service.deleteStep(step.id);
    } catch (e, st) {
      if (mounted) setState(() => _hiddenStepIds.remove(step.id));
      showErrorSnackBar(messenger, 'Could not remove the step.', e, st);
      return;
    }
    showUndoSnackBar(
      messenger,
      'Step removed.',
      onUndo: () async {
        try {
          await _service.restoreStep(step);
          if (mounted) setState(() => _hiddenStepIds.remove(step.id));
        } catch (e, st) {
          showErrorSnackBar(messenger, 'Could not restore the step.', e, st);
        }
      },
    );
  }

  Future<void> _reorderStep(int oldIndex, int newIndex) async {
    final messenger = ScaffoldMessenger.of(context);
    final ordered = _visibleSteps;
    if (oldIndex == newIndex) return;
    ordered.insert(newIndex, ordered.removeAt(oldIndex));
    final before = _steps;
    setState(() {
      _steps = [
        for (var i = 0; i < ordered.length; i++) ordered[i].copyWith(position: i),
        ..._steps.where((s) => _hiddenStepIds.contains(s.id)),
      ];
    });
    try {
      await _service.reorderSteps(ordered);
    } catch (e, st) {
      if (mounted) setState(() => _steps = before);
      showErrorSnackBar(messenger, 'Could not reorder the steps.', e, st);
    }
  }

  Future<void> _editStep(MealStep step) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showAppSheet<String>(
      context: context,
      builder: (_) => _TextEditSheet(
        title: 'Edit step',
        label: 'Step',
        initialText: step.text,
        maxLines: 6,
      ),
    );
    final text = result?.trim() ?? '';
    if (text.isEmpty || text == step.text) return;
    final before = _steps;
    setState(() {
      _steps = [
        for (final s in _steps) s.id == step.id ? s.copyWith(text: text) : s,
      ];
    });
    try {
      await _service.updateStepText(step.id, text);
    } catch (e, st) {
      if (mounted) setState(() => _steps = before);
      showErrorSnackBar(messenger, 'Could not save the step.', e, st);
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
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

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
                case 'delete':
                  _delete();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'rename', child: Text('Rename meal')),
              const PopupMenuItem(
                  value: 'category', child: Text('Change category')),
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
          final loading =
              snap.connectionState == ConnectionState.waiting && !snap.hasData;

          return Column(
            children: [
              _MealInfo(
                categoryName: _categoryName,
                onCategoryTap: _changeCategory,
              ),
              _TabSwitcher(
                tab: _tab,
                ingredientCount: items.length,
                onChanged: (t) => setState(() => _tab = t),
              ),
              Expanded(
                child: switch (_tab) {
                  _DetailTab.ingredients => loading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildIngredients(items),
                  _DetailTab.directions => _buildDirections(),
                },
              ),
              // Eat This is the only thing pinned to the bottom. It steps
              // aside while typing so the inline add row has room.
              if (items.isNotEmpty && !keyboardOpen)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: BoxDecoration(
                    color: p.surface,
                    border: Border(top: BorderSide(color: p.border, width: 0.5)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: FilledButton.icon(
                      onPressed: _eatThis,
                      icon: const Icon(Icons.restaurant_rounded, size: 20),
                      label: const Text('Eat This'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIngredients(List<MealNeedItem> items) {
    final p = AppPalette.of(context);
    final missingCount = items.where((i) => !i.inPantry).length;

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (items.isNotEmpty)
          missingCount > 0
              ? _MissingBanner(
                  missingCount: missingCount,
                  onAddMissing: _addMissingToGrocery,
                )
              : const _AllInStockLine(),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0)
            Divider(height: 1, indent: 52, endIndent: 16, color: p.border),
          _IngredientRow(
            key: ValueKey(items[i].itemId),
            item: items[i],
            onRemove: () => _removeIngredient(items[i]),
          ),
        ],
        _InlineAddRow(
          child: AddBar(
            framed: false,
            hintText: 'Add ingredient…',
            search: _service.searchAutocomplete,
            // Not awaited, so the next ingredient can be typed right away.
            onSubmit: (name) async {
              _addIngredient(name: name);
            },
            onSuggestion: (s) async {
              _addIngredient(
                name: s.name,
                itemId: s.itemId,
                category: s.category,
                defaultLocation: s.defaultLocation,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDirections() {
    final p = AppPalette.of(context);
    if (!_stepsLoaded && !_stepsError) {
      return const Center(child: CircularProgressIndicator());
    }
    final steps = _visibleSteps;

    final footer = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_stepsError)
          _QuietLine('Could not load the steps. Reopen the meal to try again.',
              color: p.error)
        else if (steps.isEmpty)
          const _QuietLine('No steps needed? That\'s fine.'),
        _InlineAddRow(
          child: AddBar(
            framed: false,
            hintText: 'Add step…',
            onSubmit: (text) async {
              _addStep(text);
            },
          ),
        ),
      ],
    );

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      buildDefaultDragHandles: false,
      itemCount: steps.length,
      onReorderItem: _reorderStep,
      footer: footer,
      itemBuilder: (_, i) => _StepRow(
        key: ValueKey('step_${steps[i].id}'),
        index: i,
        step: steps[i],
        showDivider: i > 0,
        onTap: () => _editStep(steps[i]),
        onDelete: () => _deleteStep(steps[i]),
      ),
    );
  }
}

// ─── Header: category ────────────────────────────────────────────────────────

class _MealInfo extends StatelessWidget {
  const _MealInfo({
    required this.categoryName,
    required this.onCategoryTap,
  });

  final String? categoryName;
  final VoidCallback onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      alignment: Alignment.centerLeft,
      // Category pill (or an "Add category" affordance)
      child: Material(
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
    );
  }
}

// ─── Tabs ────────────────────────────────────────────────────────────────────

class _TabSwitcher extends StatelessWidget {
  const _TabSwitcher({
    required this.tab,
    required this.ingredientCount,
    required this.onChanged,
  });

  final _DetailTab tab;
  final int ingredientCount;
  final ValueChanged<_DetailTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final selectedFg = p.isDark ? p.textPrimary : p.primary;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border, width: 0.5)),
      ),
      child: SegmentedButton<_DetailTab>(
        expandedInsets: EdgeInsets.zero,
        showSelectedIcon: false,
        selected: {tab},
        onSelectionChanged: (s) => onChanged(s.first),
        style: SegmentedButton.styleFrom(
          backgroundColor: p.surface,
          foregroundColor: p.textSecondary,
          selectedBackgroundColor: p.accentLight,
          selectedForegroundColor: selectedFg,
          side: BorderSide(color: p.border, width: 1.5),
          minimumSize: const Size(0, 44),
          textStyle: nsSans(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        segments: [
          ButtonSegment(
            value: _DetailTab.ingredients,
            label: Text(
              ingredientCount > 0
                  ? 'Ingredients $ingredientCount'
                  : 'Ingredients',
            ),
          ),
          const ButtonSegment(
            value: _DetailTab.directions,
            label: Text('Directions'),
          ),
        ],
      ),
    );
  }
}

// ─── Ingredients ─────────────────────────────────────────────────────────────

class _MissingBanner extends StatelessWidget {
  const _MissingBanner({
    required this.missingCount,
    required this.onAddMissing,
  });

  final int missingCount;
  final VoidCallback onAddMissing;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: p.warning.withValues(alpha: p.isDark ? 0.16 : 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: p.warningText),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$missingCount missing',
              style: nsSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: p.warningText,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: onAddMissing,
            icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
            label: Text('Add $missingCount missing'),
            style: TextButton.styleFrom(
              foregroundColor: p.warningText,
              minimumSize: const Size(0, 44),
              textStyle: nsSans(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllInStockLine extends StatelessWidget {
  const _AllInStockLine();

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Row(
        children: [
          Icon(Icons.check_rounded, size: 16, color: p.successText),
          const SizedBox(width: 6),
          Text(
            'All in stock',
            style: nsSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: p.successText,
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    super.key,
    required this.item,
    required this.onRemove,
  });

  final MealNeedItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final status = IngredientStatus(item.inventoryLocation);
    final color = status.color(p);

    return Dismissible(
      key: ValueKey('dismiss_${item.itemId}'),
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

// ─── Directions ──────────────────────────────────────────────────────────────

class _StepRow extends StatelessWidget {
  const _StepRow({
    super.key,
    required this.index,
    required this.step,
    required this.showDivider,
    required this.onTap,
    required this.onDelete,
  });

  final int index;
  final MealStep step;
  final bool showDivider;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Dismissible(
      key: ValueKey('dismiss_step_${step.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: p.error.withValues(alpha: 0.12),
        child: Icon(Icons.delete_outline_rounded, color: p.error, size: 22),
      ),
      onDismissed: (_) => onDelete(),
      child: Material(
        color: p.background,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              border: showDivider
                  ? Border(top: BorderSide(color: p.border, width: 1))
                  : null,
            ),
            padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
            constraints: const BoxConstraints(minHeight: 52),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.only(top: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.accentLight,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: nsSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: p.isDark ? p.textPrimary : p.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      step.text,
                      style: nsSans(
                        fontSize: 15,
                        color: p.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Tooltip(
                    message: 'Drag to reorder',
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(Icons.drag_handle_rounded,
                          color: p.textMuted, size: 22),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Shared bits ─────────────────────────────────────────────────────────────

/// Padding for the "+ Add…" field that ends each tab's list.
class _InlineAddRow extends StatelessWidget {
  const _InlineAddRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: child,
      );
}

class _QuietLine extends StatelessWidget {
  const _QuietLine(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        text,
        style: nsSans(fontSize: 14, color: color ?? p.textMuted, height: 1.4),
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
    this.maxLines = 1,
  });

  final String title;
  final String label;
  final String initialText;
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
            decoration: InputDecoration(labelText: widget.label),
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
