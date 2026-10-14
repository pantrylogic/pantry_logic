import 'package:flutter/material.dart';

import '../../core/quantity.dart';
import '../../core/stock_entry.dart';
import '../../core/theme.dart';
import '../../core/ui_prefs.dart';
import '../../models/inventory_item.dart';
import '../../models/item.dart';
import '../../services/inventory_service.dart';
import '../../widgets/add_bar.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/app_snack_bar.dart';

/// Opens the fast, location-first "Add to stock" sheet.
Future<void> showStockEntrySheet(
  BuildContext context, {
  required List<String> locations,
}) =>
    showAppSheet<void>(
      context: context,
      builder: (_) => StockEntrySheet(locations: locations),
    );

/// Batch stock entry: pick a location, then type items one after another
/// (`milk 2`, `2x eggs`, `bread, butter`). Each item is saved the moment
/// it's entered; the keyboard stays up between items.
class StockEntrySheet extends StatefulWidget {
  const StockEntrySheet({super.key, required this.locations});

  /// Location names in display order.
  final List<String> locations;

  @override
  State<StockEntrySheet> createState() => _StockEntrySheetState();
}

class _SessionEntry {
  _SessionEntry({
    required this.name,
    required this.quantity,
    required this.location,
    this.itemId,
  });

  final String name;
  final int? quantity;
  final String? itemId;

  /// Location tag shown on the row. Becomes the existing row's location
  /// when the item was already in stock.
  String location;

  /// The in-flight or completed save; null result means it failed.
  Future<StockAddResult?>? save;
  StockAddResult? result;
  String? error;
}

class _StockEntrySheetState extends State<StockEntrySheet> {
  final _service = InventoryService();

  late String _location;

  /// Items added this session, newest first.
  final List<_SessionEntry> _entries = [];

  /// Last non-empty text in the field. AddBar clears the field before it
  /// reports a picked suggestion, so this is what the user had typed.
  String _typed = '';

  String? get _prefsKey {
    final uid = _service.currentUserId;
    return uid == null ? null : UiPrefs.stockLastLocation(uid);
  }

  @override
  void initState() {
    super.initState();
    final locs = widget.locations;
    _location = locs.contains('Pantry')
        ? 'Pantry'
        : (locs.isNotEmpty ? locs.first : 'Pantry');
    _loadLastLocation();
  }

  Future<void> _loadLastLocation() async {
    final key = _prefsKey;
    if (key == null) return;
    final saved = await UiPrefs.getString(key);
    // Don't override a chip the user already tapped while this loaded.
    if (mounted && saved != null && widget.locations.contains(saved)) {
      setState(() => _location = saved);
    }
  }

  void _selectLocation(String location) {
    setState(() => _location = location);
    final key = _prefsKey;
    if (key != null) UiPrefs.setString(key, location);
  }

  // ─── Adding ────────────────────────────────────────────────────────────────

  Future<List<AutocompleteSuggestion>> _search(String query) {
    // Suggest for the part being typed, without its quantity.
    final part = query.split(RegExp(r'[,\n]')).last;
    final name = parseStockEntry(part)?.name ?? '';
    if (name.isEmpty) return Future.value(const []);
    return _service.searchAutocomplete(name);
  }

  Future<void> _submit(String text) async {
    for (final e in parseStockEntries(text)) {
      _add(e.name, e.quantity);
    }
  }

  Future<void> _pickSuggestion(AutocompleteSuggestion s) async {
    final parts = parseStockEntries(_typed);
    final typing = parts.isEmpty ? null : parts.removeLast();
    for (final e in parts) {
      _add(e.name, e.quantity);
    }
    _add(s.name, typing?.quantity, itemId: s.itemId);
  }

  void _add(String name, int? quantity, {String? itemId}) {
    final entry = _SessionEntry(
      name: name,
      quantity: quantity,
      location: _location,
      itemId: itemId,
    );
    setState(() => _entries.insert(0, entry));
    _save(entry);
  }

  Future<void> _save(_SessionEntry entry) async {
    if (entry.error != null) setState(() => entry.error = null);
    final future = () async {
      try {
        final itemId = entry.itemId ??
            (await _service.getOrCreateItem(
              name: entry.name,
              defaultLocation: entry.location,
            ))
                .id;
        return await _service.addOrMergeStock(
          itemId: itemId,
          location: entry.location,
          quantity: entry.quantity,
        );
      } catch (e, st) {
        logError('Add ${entry.name} to stock', e, st);
        return null;
      }
    }();
    entry.save = future;
    final result = await future;
    if (!mounted) return;
    setState(() {
      entry.result = result;
      if (result == null) {
        entry.error = 'Not saved. Tap to retry.';
      } else {
        entry.location = result.location;
      }
    });
  }

  Future<void> _remove(_SessionEntry entry) async {
    final index = _entries.indexOf(entry);
    if (index == -1) return;
    setState(() => _entries.removeAt(index));
    try {
      // Wait for the save so we undo what actually happened.
      final result = await entry.save;
      if (result != null) await _service.undoStockAdd(result);
    } catch (e, st) {
      logError('Remove ${entry.name} from stock', e, st);
      if (!mounted) return;
      setState(() {
        entry.error = 'Could not remove. Try again.';
        _entries.insert(index.clamp(0, _entries.length), entry);
      });
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final locations = widget.locations.contains(_location)
        ? widget.locations
        : [...widget.locations, _location];
    final listMaxHeight = MediaQuery.sizeOf(context).height * 0.3;

    return AppSheet(
      title: 'Add to stock',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Tapping a chip must not take focus from the field (the
          // keyboard stays up while switching location).
          TextFieldTapRegion(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final loc in locations)
                  ChoiceChip(
                    label: Text(loc),
                    selected: loc == _location,
                    onSelected: (_) => _selectLocation(loc),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AddBar(
            framed: false,
            autofocus: true,
            splitLines: true,
            suggestionsBelow: true,
            hintText: 'e.g. milk 2, eggs, bread',
            search: _search,
            suggestionTrailing: SuggestionTrailing.location,
            onChanged: (t) {
              if (t.trim().isNotEmpty) _typed = t;
            },
            onSubmit: _submit,
            onSuggestion: _pickSuggestion,
          ),
          if (_entries.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextFieldTapRegion(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: listMaxHeight),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _entries.length,
                  separatorBuilder: (ctx2, i2) =>
                      Divider(height: 1, color: p.border),
                  itemBuilder: (_, i) {
                    final entry = _entries[i];
                    return _SessionRow(
                      key: ObjectKey(entry),
                      entry: entry,
                      onRemove: () => _remove(entry),
                      onRetry: entry.result == null && entry.error != null
                          ? () => _save(entry)
                          : null,
                    );
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    super.key,
    required this.entry,
    required this.onRemove,
    this.onRetry,
  });

  final _SessionEntry entry;
  final VoidCallback onRemove;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final result = entry.result;
    final saving = result == null && entry.error == null;

    final String? note = entry.error ??
        (result != null && !result.created ? 'Already in stock, added to it' : null);

    Widget leading;
    if (saving) {
      leading = SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
      );
    } else if (entry.error != null) {
      leading = Icon(Icons.error_outline_rounded, size: 20, color: p.error);
    } else {
      leading = Icon(Icons.check_circle_rounded, size: 20, color: p.success);
    }

    return InkWell(
      onTap: onRetry,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Row(
          children: [
            SizedBox(width: 20, child: Center(child: leading)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: entry.name),
                      if (entry.quantity != null)
                        TextSpan(
                          text: '  ×${formatQuantity('${entry.quantity}')}',
                          style: TextStyle(color: p.textMuted),
                        ),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: nsSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: p.textPrimary,
                    ),
                  ),
                  if (note != null)
                    Text(
                      note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: nsSans(
                        fontSize: 12,
                        color: entry.error != null ? p.error : p.textMuted,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _LocationTag(entry.location),
            IconButton(
              tooltip: 'Remove ${entry.name}',
              onPressed: onRemove,
              icon: Icon(Icons.close_rounded, size: 20, color: p.textMuted),
              style: IconButton.styleFrom(minimumSize: const Size(44, 44)),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationTag extends StatelessWidget {
  const _LocationTag(this.location);

  final String location;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 96),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: p.accentLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          location,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: nsSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: p.isDark ? p.textPrimary : p.primary,
          ),
        ),
      ),
    );
  }
}
