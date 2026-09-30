import 'package:flutter/material.dart';

import '../../core/locations.dart';
import '../../core/quantity.dart';
import '../../core/theme.dart';
import '../../core/ui_prefs.dart';
import '../../models/inventory_item.dart';
import '../../models/storage_location.dart';
import '../../services/inventory_service.dart';
import '../../widgets/add_bar.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/brand.dart';
import '../../widgets/collapsible_section_header.dart';
import '../shell/shell_controller.dart';

/// The Stock tab: everything in the house, grouped by storage location.
class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> with TabActivation {
  final _service = InventoryService();
  late final Stream<List<InventoryItem>> _stream;

  List<StorageLocation> _locations = [];

  /// Locations the user has collapsed (persisted per device).
  Set<String> _collapsed = {};

  /// Rows removed optimistically (swipe/delete) before the stream catches up.
  final Set<String> _hiddenIds = {};

  bool _searching = false;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  @override
  int get tabIndex => ShellTab.stock;

  @override
  void onTabActivated() => _loadLocations();

  @override
  void initState() {
    super.initState();
    _stream = _service.streamInventoryItems().asBroadcastStream();
    _loadLocations();
    _loadCollapsed();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _loadLocations() async {
    try {
      final locs = await _service.getStorageLocations();
      if (mounted) setState(() => _locations = locs);
    } catch (e, st) {
      logError('Load storage locations', e, st);
    }
  }

  Future<void> _loadCollapsed() async {
    final saved = await UiPrefs.getStringSet(UiPrefs.stockCollapsedLocations);
    if (mounted) setState(() => _collapsed = saved);
  }

  /// Location names in display order, plus [extra] if it isn't one of them
  /// (e.g. an item whose custom location was deleted).
  List<String> _locationNames([String? extra]) => sortLocationNames([
        ..._locations.map((l) => l.name),
        if (extra != null && extra.isNotEmpty) extra,
      ]);

  Future<void> _toggleSection(String location) async {
    // While searching, sections with matches are forced open and the saved
    // state is left alone.
    if (_query.isNotEmpty) return;
    final next = {..._collapsed};
    if (!next.remove(location)) next.add(location);
    setState(() => _collapsed = next);
    await UiPrefs.setStringSet(UiPrefs.stockCollapsedLocations, next);
  }

  // ─── Search ────────────────────────────────────────────────────────────────

  void _startSearch() {
    setState(() => _searching = true);
    Future.microtask(() => _searchFocus.requestFocus());
  }

  void _stopSearch() {
    _searchCtrl.clear();
    _searchFocus.unfocus();
    setState(() => _searching = false);
  }

  // ─── Add ───────────────────────────────────────────────────────────────────

  Future<void> _openAddSheet({
    required String name,
    String? itemId,
    String? category,
    String? defaultLocation,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final names = _locationNames(defaultLocation);
    final initialLocation = defaultLocation ??
        (names.contains('Pantry')
            ? 'Pantry'
            : (names.isNotEmpty ? names.first : 'Pantry'));

    await showAppSheet<void>(
      context: context,
      builder: (ctx) => _ItemSheet(
        title: 'Add to stock',
        saveLabel: 'Add to stock',
        initialName: name,
        locations: names,
        initialLocation: initialLocation,
        onSave: (r) async {
          final sameName = r.name.toLowerCase() == name.toLowerCase();
          try {
            final resolvedId = sameName && itemId != null
                ? itemId
                : (await _service.getOrCreateItem(
                    name: r.name,
                    category: sameName ? category : null,
                    defaultLocation: defaultLocation,
                  ))
                    .id;
            await _service.addInventoryItem(
              itemId: resolvedId,
              itemName: r.name,
              location: r.location,
              quantity: r.quantity,
              notes: r.notes,
            );
          } on AlreadyInPantryException {
            showAppSnackBar(messenger, '${r.name} is already in stock.');
          }
          if (ctx.mounted) Navigator.pop(ctx);
          return null;
        },
      ),
    );
  }

  // ─── Edit ──────────────────────────────────────────────────────────────────

  Future<void> _openEditSheet(InventoryItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    await showAppSheet<void>(
      context: context,
      builder: (ctx) => _ItemSheet(
        title: 'Edit item',
        saveLabel: 'Save',
        initialName: item.itemName,
        locations: _locationNames(item.location),
        initialLocation: item.location,
        initialQuantity: item.quantity ?? '',
        initialNotes: item.notes ?? '',
        addedByName: item.addedByName,
        onSave: (r) async {
          if (r.name != item.itemName) {
            try {
              await _service.renameItem(item.itemId, r.name);
            } on ItemNameTakenException {
              return '"${r.name}" already exists. Pick a different name.';
            }
          }
          await _service.updateInventoryItem(
            item.id,
            location: r.location,
            quantity: r.quantity,
            notes: r.notes,
          );
          if (ctx.mounted) Navigator.pop(ctx);
          return null;
        },
        onAddToGrocery: () => _addToGrocery(item, messenger),
        onDelete: () {
          Navigator.pop(ctx);
          _deleteItem(item, messenger);
        },
      ),
    );
  }

  // ─── Row actions ───────────────────────────────────────────────────────────

  Future<void> _addToGrocery(
    InventoryItem item,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      final added = await _service.addToGroceryList(item.itemId);
      showAppSnackBar(
        messenger,
        added
            ? 'Added ${item.itemName} to the grocery list.'
            : '${item.itemName} is already on the grocery list.',
      );
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not add to the grocery list.', e, st);
    }
  }

  Future<void> _deleteItem(
    InventoryItem item,
    ScaffoldMessengerState messenger,
  ) async {
    setState(() => _hiddenIds.add(item.id));
    try {
      await _service.deleteInventoryItem(item.id);
    } catch (e, st) {
      if (mounted) setState(() => _hiddenIds.remove(item.id));
      showErrorSnackBar(messenger, 'Could not remove ${item.itemName}.', e, st);
      return;
    }
    showUndoSnackBar(
      messenger,
      '${item.itemName} removed from stock.',
      onUndo: () => _restoreItem(item, messenger),
    );
  }

  Future<void> _restoreItem(
    InventoryItem item,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      await _service.addInventoryItem(
        itemId: item.itemId,
        itemName: item.itemName,
        location: item.location,
        quantity: item.quantity,
        notes: item.notes,
        addedBy: item.addedBy,
      );
    } on AlreadyInPantryException {
      // Someone re-added it in the meantime — nothing to restore.
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not restore ${item.itemName}.', e, st);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                focusNode: _searchFocus,
                style: nsSans(fontSize: 17, color: p.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Search stock…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              )
            : const Text('Stock'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search',
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
            onPressed: _searching ? _stopSearch : _startSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<InventoryItem>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const _EmptyState(
                    icon: Icons.cloud_off_rounded,
                    message: 'Could not load stock. Reopen the tab to try '
                        'again.',
                  );
                }
                return _buildList(snapshot.data ?? []);
              },
            ),
          ),
          AddBar(
            hintText: 'Add to stock…',
            search: _service.searchAutocomplete,
            suggestionTrailing: SuggestionTrailing.location,
            keepFocusAfterSubmit: false,
            onSubmit: (name) => _openAddSheet(name: name),
            onSuggestion: (s) => _openAddSheet(
              name: s.name,
              itemId: s.itemId,
              category: s.category,
              defaultLocation: s.defaultLocation,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(List<InventoryItem> all) {
    var items = all.where((i) => !_hiddenIds.contains(i.id)).toList();

    if (_query.isNotEmpty) {
      items = items
          .where((i) =>
              i.itemName.toLowerCase().contains(_query) ||
              i.location.toLowerCase().contains(_query))
          .toList();
    }

    if (items.isEmpty) {
      return _EmptyState(
        icon: _query.isNotEmpty
            ? Icons.search_off_rounded
            : Icons.inventory_2_outlined,
        message: _query.isNotEmpty
            ? 'Nothing matches "${_searchCtrl.text.trim()}".'
            : 'Nothing in stock yet.\nAdd items below.',
      );
    }

    final grouped = <String, List<InventoryItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.location, () => []).add(item);
    }
    final locations = sortLocationNames(grouped.keys);

    final children = <Widget>[];
    for (final location in locations) {
      final group = grouped[location]!
        ..sort((a, b) =>
            a.itemName.toLowerCase().compareTo(b.itemName.toLowerCase()));
      final expanded = _query.isNotEmpty || !_collapsed.contains(location);

      children.add(CollapsibleSectionHeader(
        title: location,
        count: group.length,
        expanded: expanded,
        onTap: () => _toggleSection(location),
      ));
      if (expanded) {
        children.add(_SectionCard(
          children: [
            for (final item in group)
              _StockRow(
                key: ValueKey('stock_${item.id}'),
                item: item,
                onTap: () => _openEditSheet(item),
                onDelete: () =>
                    _deleteItem(item, ScaffoldMessenger.of(context)),
                onAddToGrocery: () =>
                    _addToGrocery(item, ScaffoldMessenger.of(context)),
              ),
          ],
        ));
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: children,
    );
  }
}

// ─── Section card ─────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: 16, color: p.border),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Stock row ────────────────────────────────────────────────────────────────

class _StockRow extends StatelessWidget {
  const _StockRow({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
    required this.onAddToGrocery,
  });

  final InventoryItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onAddToGrocery;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final qty = formatQuantity(item.quantity);

    return Dismissible(
      key: ValueKey('dismiss_${item.id}'),
      // Swipe right: add to grocery list (row stays).
      // Swipe left: remove (with undo).
      background: _SwipeBackground(
        color: p.primary,
        foreground: p.onPrimary,
        icon: Icons.add_shopping_cart_rounded,
        label: 'Add to list',
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _SwipeBackground(
        color: p.error,
        foreground: Colors.white,
        icon: Icons.delete_outline_rounded,
        label: 'Remove',
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onAddToGrocery();
          return false;
        }
        return true;
      },
      onDismissed: (_) => onDelete(),
      child: Material(
        color: p.surface,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.itemName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: nsSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  if (qty.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    _QuantityPill(qty),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantityPill extends StatelessWidget {
  const _QuantityPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 140),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: p.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.border),
        ),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: nsSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: p.textMuted,
          ),
        ),
      ),
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({
    required this.color,
    required this.foreground,
    required this.icon,
    required this.label,
    required this.alignment,
  });

  final Color color;
  final Color foreground;
  final IconData icon;
  final String label;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final start = alignment == Alignment.centerLeft;
    final text = Text(
      label,
      style: nsSans(fontSize: 13, fontWeight: FontWeight.w700, color: foreground),
    );
    return Container(
      color: color,
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!start) ...[text, const SizedBox(width: 8)],
          Icon(icon, color: foreground, size: 22),
          if (start) ...[const SizedBox(width: 8), text],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBadge(icon, size: 56),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: nsSans(fontSize: 15, color: p.textMuted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add / edit sheet ─────────────────────────────────────────────────────────

class _ItemSheetResult {
  const _ItemSheetResult({
    required this.name,
    required this.location,
    required this.quantity,
    required this.notes,
  });

  final String name;
  final String location;
  final String quantity;
  final String notes;
}

/// Returns an error message for the name field, or null on success.
/// Other failures should be thrown.
typedef _ItemSheetSave = Future<String?> Function(_ItemSheetResult result);

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({
    required this.title,
    required this.saveLabel,
    required this.initialName,
    required this.locations,
    required this.initialLocation,
    this.initialQuantity = '',
    this.initialNotes = '',
    this.addedByName,
    required this.onSave,
    this.onAddToGrocery,
    this.onDelete,
  });

  final String title;
  final String saveLabel;
  final String initialName;
  final List<String> locations;
  final String initialLocation;
  final String initialQuantity;
  final String initialNotes;
  final String? addedByName;
  final _ItemSheetSave onSave;
  final VoidCallback? onAddToGrocery;
  final VoidCallback? onDelete;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _notesCtrl;
  late String _location;
  String? _nameError;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _quantityCtrl = TextEditingController(text: widget.initialQuantity);
    _notesCtrl = TextEditingController(text: widget.initialNotes);
    _location = widget.initialLocation;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _quantityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Give the item a name.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _saving = true;
      _nameError = null;
    });
    try {
      final error = await widget.onSave(_ItemSheetResult(
        name: name,
        location: _location,
        quantity: _quantityCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
      ));
      if (mounted && error != null) setState(() => _nameError = error);
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not save. Try again.', e, st);
    } finally {
      // Always re-enable the button, including after a failure.
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final locations = widget.locations.contains(_location)
        ? widget.locations
        : sortLocationNames([...widget.locations, _location]);

    return AppSheet(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.sentences,
            style: nsSans(fontSize: 15, color: p.textPrimary),
            decoration: InputDecoration(
              labelText: 'Name',
              errorText: _nameError,
              errorMaxLines: 2,
            ),
            onChanged: (_) {
              if (_nameError != null) setState(() => _nameError = null);
            },
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Location'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final loc in locations)
                ChoiceChip(
                  label: Text(loc),
                  selected: loc == _location,
                  onSelected: (_) => setState(() => _location = loc),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _QuantityStepper(controller: _quantityCtrl),
          const SizedBox(height: 16),
          TextField(
            controller: _notesCtrl,
            textCapitalization: TextCapitalization.sentences,
            minLines: 1,
            maxLines: 3,
            style: nsSans(fontSize: 15, color: p.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Notes',
              hintText: 'Brand, size, anything useful',
            ),
          ),
          if (widget.addedByName != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 16, color: p.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Added by ${widget.addedByName}',
                    style: nsSans(fontSize: 13, color: p.textMuted),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: _saving
                ? SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: p.onPrimary),
                  )
                : Text(widget.saveLabel),
          ),
          if (widget.onAddToGrocery != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: widget.onAddToGrocery,
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
              label: const Text('Add to grocery list'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                foregroundColor: p.primary,
              ),
            ),
          ],
          if (widget.onDelete != null) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              label: const Text('Remove from stock'),
              style: TextButton.styleFrom(
                foregroundColor: p.error,
                minimumSize: const Size(double.infinity, 48),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Text(
      text,
      style: nsSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: p.textSecondary,
      ),
    );
  }
}

/// Quantity input with −/+ buttons. The buttons work when the text is a
/// number (or empty, for +); anything else ("500 ml") is edited as free text.
class _QuantityStepper extends StatefulWidget {
  const _QuantityStepper({required this.controller});

  final TextEditingController controller;

  @override
  State<_QuantityStepper> createState() => _QuantityStepperState();
}

class _QuantityStepperState extends State<_QuantityStepper> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  void _set(double value) {
    final text = serializeQuantity(value);
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  @override
  Widget build(BuildContext context) {
    final raw = widget.controller.text.trim();
    final value = parseQuantity(raw);
    final canDecrement = value != null && value - 1 > 0;
    final canIncrement = raw.isEmpty || value != null;

    return Row(
      children: [
        _StepButton(
          icon: Icons.remove_rounded,
          tooltip: 'Decrease quantity',
          onPressed: canDecrement ? () => _set(value - 1) : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: widget.controller,
            textAlign: TextAlign.center,
            style: nsSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppPalette.of(context).textPrimary,
            ),
            decoration: const InputDecoration(
              labelText: 'Quantity',
              hintText: 'e.g. 2, ½, 500 ml',
              floatingLabelAlignment: FloatingLabelAlignment.center,
            ),
          ),
        ),
        const SizedBox(width: 8),
        _StepButton(
          icon: Icons.add_rounded,
          tooltip: 'Increase quantity',
          onPressed: canIncrement ? () => _set((value ?? 0) + 1) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return IconButton.outlined(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 22,
      style: IconButton.styleFrom(
        minimumSize: const Size(52, 52),
        foregroundColor: p.primary,
        side: BorderSide(color: p.border, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
