import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/item.dart';
import '../../models/meal.dart';
import '../../models/meal_category.dart';
import '../../models/meal_need_item.dart';
import '../../services/meal_service.dart';
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

  // Local copies of mutable meal fields — updated optimistically after edits
  late String _name;
  late String? _categoryId;
  late String? _categoryName;
  late String? _notes;

  // ── Add ingredient bar ────────────────────────────────────────────────────
  final _addCtrl = TextEditingController();
  final _addFocus = FocusNode();
  List<AutocompleteSuggestion> _suggestions = [];
  bool _showSuggestions = false;
  bool _addingItem = false;

  // Guard against callbacks firing during/after dispose
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _name = widget.meal.name;
    _categoryId = widget.meal.categoryId;
    _categoryName = widget.meal.categoryName;
    _notes = widget.meal.notes;
    _stream = _service.streamNeedList(widget.meal.id).asBroadcastStream();
    _loadCategories();
    _addCtrl.addListener(_onAddChanged);
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await _service.getCategories();
      if (!_disposed) setState(() => _categories = cats);
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _addCtrl.removeListener(_onAddChanged);
    _addCtrl.dispose();
    _addFocus.dispose();
    super.dispose();
  }

  // ── Autocomplete ──────────────────────────────────────────────────────────

  void _onAddChanged() {
    final q = _addCtrl.text.trim();
    if (q.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _service.searchAutocomplete(q).then((results) {
      if (_disposed) return;
      if (_addCtrl.text.trim() == q) {
        setState(() {
          _suggestions = results;
          _showSuggestions = results.isNotEmpty;
        });
      }
    });
  }

  void _hideSuggestions() {
    setState(() => _showSuggestions = false);
  }

  Future<void> _pickSuggestion(AutocompleteSuggestion s) async {
    _hideSuggestions();
    _addCtrl.clear();
    _addFocus.unfocus();
    await _addIngredient(
      name: s.name,
      itemId: s.itemId,
      category: s.category,
      defaultLocation: s.defaultLocation,
    );
  }

  Future<void> _submitAdd() async {
    final name = _addCtrl.text.trim();
    if (name.isEmpty) {
      _addFocus.unfocus();
      return;
    }
    _hideSuggestions();
    _addCtrl.clear();
    _addFocus.unfocus();
    await _addIngredient(name: name);
  }

  Future<void> _addIngredient({
    required String name,
    String? itemId,
    String? category,
    String? defaultLocation,
  }) async {
    if (_addingItem) return;
    setState(() => _addingItem = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      // If suggestion already has an item_id, use it directly; otherwise create
      final resolvedId = itemId ??
          (await _service.getOrCreateItem(
            name: name,
            category: category,
            defaultLocation: defaultLocation,
          ))
              .id;
      await _service.addNeedItem(mealId: widget.meal.id, itemId: resolvedId);
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not add ingredient: $e')));
    } finally {
      if (!_disposed) setState(() => _addingItem = false);
    }
  }

  Future<void> _removeNeedItem(MealNeedItem item) async {
    await _service.removeNeedItem(
        mealId: widget.meal.id, itemId: item.itemId);
  }

  // ── Add missing to grocery list ────────────────────────────────────────────

  Future<void> _addMissingToGrocery() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final count = await _service.addMissingToGroceryList(widget.meal.id);
      messenger.showSnackBar(SnackBar(
        content: Text(
          count == 0
              ? 'All missing items already on grocery list.'
              : count == 1
                  ? '1 item added to grocery list.'
                  : '$count items added to grocery list.',
        ),
      ));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not add to grocery list: $e')));
    }
  }

  // ── Edit actions ──────────────────────────────────────────────────────────

  Future<void> _showRenameSheet() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _EditSheet(
        title: 'Rename meal',
        initialText: _name,
        hint: 'Meal name',
        onSave: (v) => Navigator.of(ctx).pop(v),
      ),
    );
    final newName = result?.trim() ?? '';
    if (newName.isEmpty || newName == _name) return;
    try {
      await _service.updateMeal(widget.meal.id, name: newName);
      if (!_disposed) setState(() => _name = newName);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not rename: $e')));
    }
  }

  Future<void> _showCategorySheet() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<_CategoryChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) =>
          _CategorySheet(categories: _categories, currentId: _categoryId),
    );
    if (result == null) return;
    try {
      if (result.isNone) {
        await _service.updateMeal(widget.meal.id, clearCategory: true);
        if (!_disposed) setState(() => (_categoryId = null, _categoryName = null));
      } else {
        await _service.updateMeal(
            widget.meal.id, categoryId: result.categoryId);
        if (!_disposed) {
          final cat =
              _categories.firstWhere((c) => c.id == result.categoryId);
          setState(() {
            _categoryId = cat.id;
            _categoryName = cat.name;
          });
        }
      }
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not update category: $e')));
    }
  }

  Future<void> _showNotesSheet() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _EditSheet(
        title: 'Notes',
        initialText: _notes ?? '',
        hint: 'e.g. serves 4, 30 min…',
        maxLines: 4,
        onSave: (v) => Navigator.of(ctx).pop(v),
      ),
    );
    if (result == null) return;
    try {
      final newNotes = result.trim().isEmpty ? null : result.trim();
      await _service.updateMeal(
        widget.meal.id,
        notes: newNotes ?? '',
        clearNotes: newNotes == null,
      );
      if (!_disposed) setState(() => _notes = newNotes);
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not save notes: $e')));
    }
  }

  Future<void> _confirmDelete() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete meal?',
          style: nsSans(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: Text(
          'This will permanently delete "$_name" and its need list.',
          style: nsSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: nsSans()),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: nsSans(
                color: Theme.of(ctx).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteMeal(widget.meal.id);
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDm : AppColors.primary;
    final accentLight =
        isDark ? AppColors.accentLightDm : AppColors.accentLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDm : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.textSecondaryDm : AppColors.textSecondary;
    final textMuted = isDark ? AppColors.textMutedDm : AppColors.textMuted;
    final surface = isDark ? AppColors.surfaceDm : AppColors.surface;
    final border = isDark ? AppColors.borderDm : AppColors.border;
    final success = isDark ? AppColors.successDm : AppColors.success;
    final warning = isDark ? AppColors.warningDm : AppColors.warning;
    final errorColor = isDark ? AppColors.errorDm : AppColors.error;

    return GestureDetector(
      onTap: () {
        _hideSuggestions();
        _addFocus.unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_name, style: nsSans(fontWeight: FontWeight.w700)),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) {
                switch (v) {
                  case 'rename':
                    _showRenameSheet();
                  case 'category':
                    _showCategorySheet();
                  case 'notes':
                    _showNotesSheet();
                  case 'delete':
                    _confirmDelete();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Text('Rename meal', style: nsSans()),
                ),
                PopupMenuItem(
                  value: 'category',
                  child: Text('Change category', style: nsSans()),
                ),
                PopupMenuItem(
                  value: 'notes',
                  child: Text(
                    _notes != null ? 'Edit notes' : 'Add notes',
                    style: nsSans(),
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete meal',
                    style: nsSans(
                      color: errorColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: StreamBuilder<List<MealNeedItem>>(
          stream: _stream,
          builder: (ctx, snap) {
            final items = snap.data ?? [];
            final missingCount = items.where((i) => !i.inPantry).length;

            return Column(
              children: [
                // ── Meal info (category chip + notes) ──────────────────────
                if (_categoryName != null || _notes != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    decoration: BoxDecoration(
                      color: surface,
                      border: Border(
                        bottom: BorderSide(color: border, width: 0.5),
                      ),
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (_categoryName != null)
                          GestureDetector(
                            onTap: _showCategorySheet,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: accentLight,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _categoryName!,
                                style: nsSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: primary,
                                ),
                              ),
                            ),
                          ),
                        if (_notes != null)
                          GestureDetector(
                            onTap: _showNotesSheet,
                            child: Text(
                              _notes!,
                              style: nsSans(
                                fontSize: 13,
                                color: textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                // ── Need list header ───────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                  child: Row(
                    children: [
                      Text(
                        'NEED LIST',
                        style: nsSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: textMuted,
                        ),
                      ),
                      const Spacer(),
                      if (items.isNotEmpty)
                        Text(
                          '${items.length} item${items.length == 1 ? '' : 's'}',
                          style: nsSans(fontSize: 12, color: textMuted),
                        ),
                    ],
                  ),
                ),

                // ── Need list items ────────────────────────────────────────
                Expanded(
                  child: snap.connectionState == ConnectionState.waiting &&
                          items.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : items.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Text(
                                  'No ingredients added yet.\nUse the bar below to build the need list.',
                                  textAlign: TextAlign.center,
                                  style: nsSans(
                                    fontSize: 14,
                                    color: textMuted,
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
                                color: border,
                              ),
                              itemBuilder: (_, i) {
                                final item = items[i];
                                return Dismissible(
                                  key: ValueKey(item.itemId),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding:
                                        const EdgeInsets.only(right: 20),
                                    color:
                                        errorColor.withValues(alpha: 0.12),
                                    child: Icon(
                                      Icons.delete_outline_rounded,
                                      color: errorColor,
                                      size: 22,
                                    ),
                                  ),
                                  onDismissed: (_) => _removeNeedItem(item),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        Icon(
                                          item.inPantry
                                              ? Icons.check_circle_rounded
                                              : Icons
                                                  .radio_button_unchecked_rounded,
                                          size: 20,
                                          color: item.inPantry
                                              ? success
                                              : warning,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.itemName,
                                                style: nsSans(
                                                  fontSize: 15,
                                                  fontWeight:
                                                      FontWeight.w600,
                                                  color: textPrimary,
                                                ),
                                              ),
                                              Text(
                                                item.inPantry
                                                    ? 'In pantry · ${item.inventoryLocation}'
                                                    : 'Missing',
                                                style: nsSans(
                                                  fontSize: 12,
                                                  color: item.inPantry
                                                      ? success
                                                      : warning,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),

                // ── Action buttons (Eat This + Add Missing) ───────────────
                if (items.isNotEmpty && !_showSuggestions)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    decoration: BoxDecoration(
                      color: surface,
                      border:
                          Border(top: BorderSide(color: border, width: 0.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RestockScreen(
                                mealId: widget.meal.id,
                                mealName: _name,
                              ),
                            ),
                          ),
                          icon:
                              const Icon(Icons.restaurant_rounded, size: 18),
                          label: Text(
                            'Eat This',
                            style: nsSans(
                                fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                          ),
                        ),
                        if (missingCount > 0) ...[
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _addMissingToGrocery,
                            icon: const Icon(
                                Icons.add_shopping_cart_rounded,
                                size: 18),
                            label: Text(
                              'Add $missingCount missing to grocery list',
                              style: nsSans(
                                  fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 44),
                              backgroundColor:
                                  warning.withValues(alpha: 0.15),
                              foregroundColor: warning,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                // ── Autocomplete suggestions (above add bar) ──────────────
                if (_showSuggestions && _suggestions.isNotEmpty)
                  Material(
                    elevation: 2,
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: surface,
                        border: Border(
                          top: BorderSide(color: border, width: 0.5),
                        ),
                      ),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: _suggestions.length,
                        itemBuilder: (_, i) {
                          final s = _suggestions[i];
                          return InkWell(
                            onTap: () => _pickSuggestion(s),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(Icons.add_rounded,
                                      size: 16, color: primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      s.name,
                                      style: nsSans(
                                          fontSize: 14, color: textPrimary),
                                    ),
                                  ),
                                  if (s.category != null)
                                    Text(
                                      s.category!,
                                      style: nsSans(
                                          fontSize: 12, color: textMuted),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // ── Add ingredient bar ─────────────────────────────────────
                Container(
                  decoration: BoxDecoration(
                    color: surface,
                    border:
                        Border(top: BorderSide(color: border, width: 0.5)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _addCtrl,
                              focusNode: _addFocus,
                              textCapitalization:
                                  TextCapitalization.sentences,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submitAdd(),
                              style:
                                  nsSans(fontSize: 15, color: textPrimary),
                              decoration: InputDecoration(
                                hintText: 'Add ingredient…',
                                hintStyle:
                                    nsSans(fontSize: 15, color: textMuted),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _addingItem
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: primary),
                                )
                              : GestureDetector(
                                  onTap: _submitAdd,
                                  child: Icon(
                                    Icons.add_circle_rounded,
                                    color: primary,
                                    size: 28,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─── Edit sheet ─────────────────────────────────────────────────────────────
// StatefulWidget so it owns + disposes the TextEditingController at the
// right point in the widget lifecycle (avoids "controller used after disposed"
// when the sheet's close animation outlives the Future that created the ctrl).

class _EditSheet extends StatefulWidget {
  final String title;
  final String initialText;
  final String hint;
  final int maxLines;
  final void Function(String) onSave;

  const _EditSheet({
    required this.title,
    required this.initialText,
    required this.hint,
    this.maxLines = 1,
    required this.onSave,
  });

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDm : AppColors.primary;
    final textPrimary =
        isDark ? AppColors.textPrimaryDm : AppColors.textPrimary;
    final textMuted = isDark ? AppColors.textMutedDm : AppColors.textMuted;
    final border = isDark ? AppColors.borderDm : AppColors.border;

    // Keyboard inset owned here (StatefulWidget element deactivates cleanly).
    final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 24, 16, 24 + keyboardBottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: nsSans(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            autofocus: true,
            maxLines: widget.maxLines,
            textCapitalization: TextCapitalization.sentences,
            style: nsSans(fontSize: 15, color: textPrimary),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: nsSans(fontSize: 15, color: textMuted),
              filled: true,
              fillColor: isDark ? AppColors.surfaceDm : AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => widget.onSave(_ctrl.text),
            child: Text('Save', style: nsSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Category sheet ──────────────────────────────────────────────────────────

class _CategoryChoice {
  final String? categoryId;
  bool get isNone => categoryId == null;
  const _CategoryChoice({this.categoryId});
}

class _CategorySheet extends StatelessWidget {
  final List<MealCategory> categories;
  final String? currentId;

  const _CategorySheet({required this.categories, this.currentId});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDm : AppColors.primary;
    final textPrimary =
        isDark ? AppColors.textPrimaryDm : AppColors.textPrimary;
    final textMuted = isDark ? AppColors.textMutedDm : AppColors.textMuted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Change category',
            style: nsSans(fontWeight: FontWeight.w700, fontSize: 17),
          ),
          const SizedBox(height: 12),
          _CategoryTile(
            label: 'None',
            isSelected: currentId == null,
            primary: primary,
            textPrimary: textPrimary,
            textMuted: textMuted,
            onTap: () =>
                Navigator.of(context).pop(const _CategoryChoice()),
          ),
          const SizedBox(height: 2),
          ...categories.map(
            (cat) => _CategoryTile(
              label: cat.name,
              isSelected: cat.id == currentId,
              primary: primary,
              textPrimary: textPrimary,
              textMuted: textMuted,
              onTap: () => Navigator.of(context)
                  .pop(_CategoryChoice(categoryId: cat.id)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color primary;
  final Color textPrimary;
  final Color textMuted;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.isSelected,
    required this.primary,
    required this.textPrimary,
    required this.textMuted,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: isSelected ? primary : textMuted,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: nsSans(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? primary : textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
