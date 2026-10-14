import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locations.dart';
import '../../core/quantity.dart';
import '../../core/theme.dart';
import '../../core/ui_prefs.dart';
import '../../models/inventory_item.dart';
import '../../models/storage_location.dart';
import '../../services/inventory_service.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/brand.dart';
import '../../widgets/collapsible_section_header.dart';
import '../shell/shell_controller.dart';
import 'stock_entry_sheet.dart';

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

  // Inline quantity stepper state, keyed by stock row id. Taps update
  // [_qtyOverride] at once; the summed delta is written ~400ms after the
  // last tap via the atomic adjust_quantity RPC. The override is dropped
  // once the stream shows the server value (or after a timeout). Writes
  // for one item run one after another (see [_serialized]).
  static const _stepDebounce = Duration(milliseconds: 400);
  static const _overrideTimeout = Duration(seconds: 5);
  final Map<String, double> _qtyOverride = {};
  final Map<String, int> _pendingDelta = {};
  final Map<String, Timer> _debounce = {};
  final Map<String, int> _inFlight = {};
  final Map<String, Timer> _overrideExpiry = {};
  final Map<String, Future<void>> _writes = {};
  StreamSubscription<List<InventoryItem>>? _reconcileSub;

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
    _reconcileSub = _stream.listen(_reconcile, onError: (_) {});
    _loadLocations();
    _loadCollapsed();
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    // Write any taps still waiting on the debounce before leaving.
    for (final id in _debounce.keys.toList()) {
      _debounce.remove(id)?.cancel();
      final delta = _pendingDelta.remove(id);
      if (delta != null && delta != 0) {
        _serialized(id, () => _service.adjustQuantity(id, delta))
            .catchError((Object e, st) {
          logError('Flush quantity on dispose', e, st);
          return 0.0;
        });
      }
    }
    for (final t in _overrideExpiry.values) {
      t.cancel();
    }
    _reconcileSub?.cancel();
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

  Future<void> _openAddSheet() =>
      showStockEntrySheet(context, locations: _locationNames());

  // ─── Edit ──────────────────────────────────────────────────────────────────

  Future<void> _openEditSheet(InventoryItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    await showAppSheet<void>(
      context: context,
      builder: (ctx) => _EditItemSheet(
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

  /// Swipe/delete: removes a stock row with the same undo snackbar as
  /// "used up" (Undo + Add to list).
  Future<void> _deleteItem(
    InventoryItem item,
    ScaffoldMessengerState messenger,
  ) async {
    final override = _qtyOverride[item.id];
    final restoreQty =
        override != null ? serializeQuantity(override) : item.quantity;
    _cancelStepping(item.id);
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
      onUndo: () => _restoreItem(item, messenger, quantity: restoreQty),
      secondaryLabel: 'Add to list',
      onSecondary: () => _addToGrocery(item, messenger),
    );
  }

  Future<void> _restoreItem(
    InventoryItem item,
    ScaffoldMessengerState messenger, {
    String? quantity,
  }) async {
    try {
      await _service.addInventoryItem(
        itemId: item.itemId,
        itemName: item.itemName,
        location: item.location,
        quantity: quantity,
        notes: item.notes,
        addedBy: item.addedBy,
      );
    } on AlreadyInPantryException {
      // Someone re-added it in the meantime — nothing to restore.
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not restore ${item.itemName}.', e, st);
    }
  }

  // ─── Quantity stepper ──────────────────────────────────────────────────────

  double? _displayQty(InventoryItem item) =>
      _qtyOverride[item.id] ?? parseQuantity(item.quantity);

  bool _isBusy(String id) =>
      _pendingDelta.containsKey(id) || (_inFlight[id] ?? 0) > 0;

  /// Runs [write] after any earlier write for the same item has finished,
  /// so the server sees taps, exact sets and "used up" in order.
  Future<T> _serialized<T>(String id, Future<T> Function() write) {
    final result = (_writes[id] ?? Future<void>.value()).then((_) => write());
    final done = result.then<void>((_) {}, onError: (_) {});
    _writes[id] = done;
    done.then((_) {
      if (identical(_writes[id], done)) _writes.remove(id);
    });
    return result;
  }

  void _cancelStepping(String id) {
    _debounce.remove(id)?.cancel();
    _overrideExpiry.remove(id)?.cancel();
    _pendingDelta.remove(id);
    _qtyOverride.remove(id);
  }

  void _step(InventoryItem item, int delta) {
    final current = _displayQty(item) ?? 0;
    final next = current + delta;
    if (delta < 0 && next <= 0) {
      _consume(item, delta, restoreQuantity: serializeQuantity(current));
      return;
    }
    _overrideExpiry.remove(item.id)?.cancel();
    setState(() {
      _qtyOverride[item.id] = next;
      _pendingDelta[item.id] = (_pendingDelta[item.id] ?? 0) + delta;
    });
    _debounce.remove(item.id)?.cancel();
    _debounce[item.id] = Timer(_stepDebounce, () => _flush(item));
  }

  Future<void> _flush(InventoryItem item) async {
    final id = item.id;
    _debounce.remove(id);
    final delta = _pendingDelta.remove(id);
    if (delta == null || delta == 0) {
      _expireOverride(id);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    _inFlight[id] = (_inFlight[id] ?? 0) + 1;
    double? serverQty;
    Object? error;
    StackTrace? stack;
    try {
      serverQty =
          await _serialized(id, () => _service.adjustQuantity(id, delta));
    } catch (e, st) {
      error = e;
      stack = st;
    }
    _endInFlight(id);
    // Deleted meanwhile (used up / swiped): nothing to reconcile.
    if (!mounted || _hiddenIds.contains(id)) return;

    if (error != null) {
      setState(() => _cancelStepping(id));
      showErrorSnackBar(
          messenger, 'Could not update ${item.itemName}.', error, stack);
      return;
    }
    // Later taps are still pending: keep showing their optimistic value.
    if (!_isBusy(id)) setState(() => _qtyOverride[id] = serverQty!);
    _expireOverride(id);
  }

  /// "Used up": sends [delta] (relative to what's shown) plus any taps
  /// still waiting on the debounce to consume_item, which deletes the row
  /// only if that takes it to 0 or below. Undo re-inserts the returned row
  /// with [restoreQuantity] (what was shown before the last tap); null keeps
  /// the row's own quantity.
  Future<void> _consume(
    InventoryItem item,
    int delta, {
    String? restoreQuantity,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final id = item.id;
    final total = (_pendingDelta[id] ?? 0) + delta;
    setState(() {
      _cancelStepping(id);
      _hiddenIds.add(id);
    });

    final Map<String, dynamic>? deleted;
    try {
      deleted = await _serialized(id, () => _service.consumeItem(id, total));
    } on StockItemGoneException {
      showAppSnackBar(messenger, '${item.itemName} was already removed.');
      return;
    } catch (e, st) {
      if (mounted) setState(() => _hiddenIds.remove(id));
      showErrorSnackBar(messenger, 'Could not update ${item.itemName}.', e, st);
      return;
    }

    if (deleted == null) {
      // Kept: someone added stock meanwhile. The stream shows the new value.
      if (mounted) setState(() => _hiddenIds.remove(id));
      showAppSnackBar(
          messenger, '${item.itemName} wasn\'t used up: someone added more.');
      return;
    }
    showUndoSnackBar(
      messenger,
      '${item.itemName} used up',
      onUndo: () => _restoreConsumed(item, deleted!, restoreQuantity, messenger),
      secondaryLabel: 'Add to list',
      onSecondary: () => _addToGrocery(item, messenger),
    );
  }

  Future<void> _restoreConsumed(
    InventoryItem item,
    Map<String, dynamic> row,
    String? quantity,
    ScaffoldMessengerState messenger,
  ) async {
    try {
      await _service.restoreInventoryRow(
        row,
        itemName: item.itemName,
        quantity: quantity,
      );
      // Same row id as before, so stop hiding it.
      if (mounted) setState(() => _hiddenIds.remove(item.id));
    } on AlreadyInPantryException {
      // Someone re-added it in the meantime — nothing to restore.
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not restore ${item.itemName}.', e, st);
    }
  }

  void _endInFlight(String id) {
    final left = (_inFlight[id] ?? 1) - 1;
    if (left > 0) {
      _inFlight[id] = left;
    } else {
      _inFlight.remove(id);
    }
  }

  /// Drops the override after a while even if the stream never matches it
  /// (e.g. realtime is disconnected).
  void _expireOverride(String id) {
    if (_isBusy(id) || !_qtyOverride.containsKey(id)) return;
    _overrideExpiry.remove(id)?.cancel();
    _overrideExpiry[id] = Timer(_overrideTimeout, () {
      _overrideExpiry.remove(id);
      if (mounted && !_isBusy(id)) setState(() => _qtyOverride.remove(id));
    });
  }

  /// Drops overrides the stream has caught up with.
  void _reconcile(List<InventoryItem> items) {
    if (_qtyOverride.isEmpty || !mounted) return;
    final byId = {for (final i in items) i.id: i};
    final settled = _qtyOverride.keys.where((id) {
      if (_isBusy(id)) return false;
      final row = byId[id];
      return row == null || parseQuantity(row.quantity) == _qtyOverride[id];
    }).toList();
    if (settled.isEmpty) return;
    setState(() {
      for (final id in settled) {
        _qtyOverride.remove(id);
        _overrideExpiry.remove(id)?.cancel();
      }
    });
  }

  /// Exact value from tapping the number. This is a plain set, not a
  /// delta: the user is stating what's on the shelf.
  Future<void> _editQuantity(InventoryItem item) async {
    final messenger = ScaffoldMessenger.of(context);
    final current = _displayQty(item);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _QuantityDialog(
        itemName: item.itemName,
        initial: current == null ? '' : serializeQuantity(current),
      ),
    );
    if (result == null || !mounted) return;
    final text = result.trim();
    final value = double.tryParse(text);
    if (text.isNotEmpty && value == null) return;
    if (value != null && value <= 0) {
      // Whatever is shown, all of it: −ceil so 0.5 counts as used up too.
      _consume(item, -(current ?? 0).ceil());
      return;
    }
    setState(() {
      _cancelStepping(item.id);
      if (value != null) _qtyOverride[item.id] = value;
    });
    _inFlight[item.id] = (_inFlight[item.id] ?? 0) + 1;
    try {
      await _serialized(
          item.id,
          () => _service.setQuantity(
              item.id, value == null ? null : serializeQuantity(value)));
    } catch (e, st) {
      if (mounted) setState(() => _qtyOverride.remove(item.id));
      showErrorSnackBar(
          messenger, 'Could not update ${item.itemName}.', e, st);
    } finally {
      _endInFlight(item.id);
      _expireOverride(item.id);
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
          _AddStockBar(onTap: _openAddSheet),
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
                quantity: _displayQty(item),
                steppable: isSteppableQuantity(item.quantity),
                onStep: (d) => _step(item, d),
                onQuantityTap: () => _editQuantity(item),
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
    required this.quantity,
    required this.steppable,
    required this.onStep,
    required this.onQuantityTap,
    required this.onTap,
    required this.onDelete,
    required this.onAddToGrocery,
  });

  final InventoryItem item;

  /// Numeric quantity to show (may be an optimistic value), null if none.
  final double? quantity;

  /// Whether the stored quantity can be stepped (empty or a plain number).
  final bool steppable;
  final ValueChanged<int> onStep;
  final VoidCallback onQuantityTap;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onAddToGrocery;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    final Widget trailing;
    if (!steppable) {
      // Free text such as "500 ml": shown as-is, edited from the item sheet.
      trailing = Padding(
        padding: const EdgeInsets.only(left: 12, right: 12),
        child: _QuantityPill(formatQuantity(item.quantity)),
      );
    } else if (quantity == null) {
      trailing = _StepButton(
        icon: Icons.add_rounded,
        tooltip: 'Set quantity for ${item.itemName}',
        onPressed: () => onStep(1),
      );
    } else {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepButton(
            icon: Icons.remove_rounded,
            tooltip: 'One less ${item.itemName}',
            onPressed: () => onStep(-1),
          ),
          _QuantityButton(
            text: formatQuantity(serializeQuantity(quantity!)),
            semanticLabel: 'Quantity of ${item.itemName}. Tap to edit.',
            onPressed: onQuantityTap,
          ),
          _StepButton(
            icon: Icons.add_rounded,
            tooltip: 'One more ${item.itemName}',
            onPressed: () => onStep(1),
          ),
        ],
      );
    }

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
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
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
                  const SizedBox(width: 8),
                  trailing,
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

/// 44×44 icon button for the row stepper.
class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      iconSize: 22,
      color: p.primary,
      style: IconButton.styleFrom(
        minimumSize: const Size(44, 44),
        fixedSize: const Size(44, 44),
        padding: EdgeInsets.zero,
      ),
    );
  }
}

/// The tappable number between − and +.
class _QuantityButton extends StatelessWidget {
  const _QuantityButton({
    required this.text,
    required this.semanticLabel,
    required this.onPressed,
  });

  final String text;
  final String semanticLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    // container: its own node, not merged into the row's "edit item" button.
    return Semantics(
      container: true,
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 36, minHeight: 44),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                text,
                style: nsSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: p.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom bar on the Stock tab. Looks like the other screens' add bars but
/// opens the batch-entry sheet, where the typing happens.
class _AddStockBar extends StatelessWidget {
  const _AddStockBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Semantics(
            button: true,
            label: 'Add to stock',
            excludeSemantics: true,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                isEmpty: true,
                decoration: InputDecoration(
                  hintText: 'Add to stock…',
                  prefixIcon:
                      Icon(Icons.add_rounded, color: p.primary, size: 22),
                ),
                child: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small numeric prompt for an exact quantity. Returns the typed text
/// (possibly empty, meaning "no quantity"), or null if cancelled.
class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.itemName, required this.initial});

  final String itemName;
  final String initial;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initial,
  )..selection =
      TextSelection(baseOffset: 0, extentOffset: widget.initial.length);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _done() => Navigator.of(context).pop(_ctrl.text);

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return AlertDialog(
      title: Text(
        widget.itemName,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: nsSans(
            fontSize: 17, fontWeight: FontWeight.w700, color: p.textPrimary),
      ),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _done(),
        style: nsSans(
            fontSize: 20, fontWeight: FontWeight.w700, color: p.textPrimary),
        decoration: const InputDecoration(
          labelText: 'Quantity',
          floatingLabelAlignment: FloatingLabelAlignment.center,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: p.textPrimary),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _done, child: const Text('Set')),
      ],
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

// ─── Edit sheet ─────────────────────────────────────────────────────────

class _EditItemResult {
  const _EditItemResult({
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
typedef _EditItemSave = Future<String?> Function(_EditItemResult result);

class _EditItemSheet extends StatefulWidget {
  const _EditItemSheet({
    required this.initialName,
    required this.locations,
    required this.initialLocation,
    required this.initialQuantity,
    required this.initialNotes,
    this.addedByName,
    required this.onSave,
    required this.onAddToGrocery,
    required this.onDelete,
  });

  final String initialName;
  final List<String> locations;
  final String initialLocation;
  final String initialQuantity;
  final String initialNotes;
  final String? addedByName;
  final _EditItemSave onSave;
  final VoidCallback onAddToGrocery;
  final VoidCallback onDelete;

  @override
  State<_EditItemSheet> createState() => _EditItemSheetState();
}

class _EditItemSheetState extends State<_EditItemSheet> {
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
      final error = await widget.onSave(_EditItemResult(
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
      title: 'Edit item',
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
                : const Text('Save'),
          ),
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
        _SheetStepButton(
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
        _SheetStepButton(
          icon: Icons.add_rounded,
          tooltip: 'Increase quantity',
          onPressed: canIncrement ? () => _set((value ?? 0) + 1) : null,
        ),
      ],
    );
  }
}

class _SheetStepButton extends StatelessWidget {
  const _SheetStepButton({
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
