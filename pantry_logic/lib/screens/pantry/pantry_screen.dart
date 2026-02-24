import 'package:flutter/material.dart';
import '../../models/inventory_item.dart';
import '../../models/item.dart';
import '../../models/storage_location.dart';
import '../../services/inventory_service.dart';

class PantryScreen extends StatefulWidget {
  const PantryScreen({super.key});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  final _service = InventoryService();
  late final Stream<List<InventoryItem>> _stream;

  // ─── Add-item bar ─────────────────────────────────────────────────────────────
  final _addCtrl = TextEditingController();
  final _addFocus = FocusNode();
  List<AutocompleteSuggestion> _suggestions = [];
  bool _showSuggestions = false;

  // ─── Search ───────────────────────────────────────────────────────────────────
  bool _searching = false;
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String _searchQuery = '';

  // ─── Storage locations ────────────────────────────────────────────────────────
  List<StorageLocation> _locations = [];

  @override
  void initState() {
    super.initState();
    _stream = _service.streamInventoryItems().asBroadcastStream();
    _loadLocations();
    _addCtrl.addListener(_onAddChanged);
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  Future<void> _loadLocations() async {
    try {
      final locs = await _service.getStorageLocations();
      if (mounted) setState(() => _locations = locs);
    } catch (_) {}
  }

  @override
  void dispose() {
    _addCtrl.dispose();
    _addFocus.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ─── Autocomplete ─────────────────────────────────────────────────────────────

  void _onAddChanged() {
    final q = _addCtrl.text;
    if (q.trim().isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
      });
      return;
    }
    _service.searchAutocomplete(q).then((results) {
      if (mounted) {
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

  // ─── Add item ─────────────────────────────────────────────────────────────────

  Future<void> _addFromSuggestion(AutocompleteSuggestion suggestion) async {
    _hideSuggestions();
    _addCtrl.clear();
    _addFocus.unfocus();
    await _showAddItemSheet(
      name: suggestion.name,
      itemId: suggestion.itemId,
      defaultLocation: suggestion.defaultLocation,
      category: suggestion.category,
    );
  }

  Future<void> _addFromText() async {
    final name = _addCtrl.text.trim();
    if (name.isEmpty) return;
    _hideSuggestions();
    _addCtrl.clear();
    _addFocus.unfocus();
    await _showAddItemSheet(name: name);
  }

  Future<void> _showAddItemSheet({
    required String name,
    String? itemId,
    String? defaultLocation,
    String? category,
  }) async {
    final initialLocation = defaultLocation ??
        (_locations.isNotEmpty ? _locations.first.name : 'Pantry');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _AddItemSheet(
        name: name,
        locations: _locations,
        initialLocation: initialLocation,
        initialQuantity: '',
        initialNotes: '',
        onSave: (location, quantity, notes) async {
          final messenger = ScaffoldMessenger.of(context);
          try {
            final item = await _service.getOrCreateItem(
              name: name,
              category: category,
              defaultLocation: defaultLocation,
            );
            await _service.addInventoryItem(
              itemId: item.id,
              itemName: item.name,
              location: location.isNotEmpty ? location : 'Pantry',
              quantity: quantity,
              notes: notes,
            );
            if (ctx.mounted) Navigator.pop(ctx);
          } on AlreadyInPantryException {
            if (ctx.mounted) {
              Navigator.pop(ctx);
              messenger.showSnackBar(
                SnackBar(content: Text('$name is already in your pantry.')),
              );
            }
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Could not add item. Try again.')),
              );
            }
          }
        },
      ),
    );
  }

  // ─── Edit / delete ────────────────────────────────────────────────────────────

  Future<void> _showEditSheet(InventoryItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _EditItemSheet(
        item: item,
        locations: _locations,
        initialLocation: item.location,
        initialQuantity: item.quantity ?? '',
        initialNotes: item.notes ?? '',
        onSave: (location, quantity, notes) async {
          try {
            await _service.updateInventoryItem(
              item.id,
              location: location.isNotEmpty ? location : item.location,
              quantity: quantity,
              notes: notes,
            );
            if (ctx.mounted) Navigator.pop(ctx);
          } catch (e) {
            if (ctx.mounted) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Could not save. Try again.')),
              );
            }
          }
        },
        onDelete: () {
          Navigator.pop(ctx);
          _deleteItem(item);
        },
      ),
    );
  }

  Future<void> _deleteItem(InventoryItem item) async {
    try {
      await _service.deleteInventoryItem(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.itemName} removed from pantry.'),
          action: SnackBarAction(
            label: 'Add to grocery list',
            onPressed: () async {
              try {
                await _service.addToGroceryList(item.itemId);
              } catch (_) {}
            },
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove item.')),
        );
      }
    }
  }

  // ─── Search toggle ────────────────────────────────────────────────────────────

  void _startSearch() {
    setState(() => _searching = true);
    Future.microtask(() => _searchFocus.requestFocus());
  }

  void _stopSearch() {
    setState(() {
      _searching = false;
      _searchQuery = '';
    });
    _searchCtrl.clear();
    _searchFocus.unfocus();
  }

  // ─── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _hideSuggestions();
        _addFocus.unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: _searching
              ? TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  decoration: const InputDecoration(
                    hintText: 'Search pantry…',
                    border: InputBorder.none,
                  ),
                  style: Theme.of(context).textTheme.titleMedium,
                )
              : const Text('Pantry'),
          actions: [
            if (_searching)
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: _stopSearch,
              )
            else
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _startSearch,
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
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  var items = snapshot.data ?? [];

                  if (_searchQuery.isNotEmpty) {
                    items = items
                        .where((i) =>
                            i.itemName
                                .toLowerCase()
                                .contains(_searchQuery) ||
                            i.location
                                .toLowerCase()
                                .contains(_searchQuery))
                        .toList();
                  }

                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        _searchQuery.isNotEmpty
                            ? 'No items match "$_searchQuery".'
                            : 'Your pantry is empty.\nAdd items below.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                      ),
                    );
                  }

                  // Group by location
                  final grouped = <String, List<InventoryItem>>{};
                  for (final item in items) {
                    grouped.putIfAbsent(item.location, () => []).add(item);
                  }

                  // Order groups by storage_locations sort_order, then alphabetical
                  final locationOrder = {
                    for (var i = 0; i < _locations.length; i++)
                      _locations[i].name: i
                  };
                  final groupKeys = grouped.keys.toList()
                    ..sort((a, b) {
                      final ia = locationOrder[a] ?? 999;
                      final ib = locationOrder[b] ?? 999;
                      if (ia != ib) return ia.compareTo(ib);
                      return a.compareTo(b);
                    });

                  return ListView.builder(
                    itemCount: groupKeys.length,
                    itemBuilder: (context, gi) {
                      final location = groupKeys[gi];
                      final groupItems = grouped[location]!;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionHeader(location: location),
                          ...groupItems.map(
                            (item) => _InventoryTile(
                              item: item,
                              onTap: () => _showEditSheet(item),
                              onDismissed: () => _deleteItem(item),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            if (_showSuggestions)
              _SuggestionsDropdown(
                suggestions: _suggestions,
                onTap: _addFromSuggestion,
              ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 0.5,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: _AddBar(
                  controller: _addCtrl,
                  focusNode: _addFocus,
                  onSubmitted: (_) => _addFromText(),
                  onTapOutside: (_) {
                    Future.delayed(const Duration(milliseconds: 80), () {
                      if (mounted) _hideSuggestions();
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Add bar ──────────────────────────────────────────────────────────────────

class _AddBar extends StatelessWidget {
  const _AddBar({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onTapOutside,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final TapRegionCallback onTapOutside;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onSubmitted: onSubmitted,
        onTapOutside: onTapOutside,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          hintText: 'Add to pantry…',
          prefixIcon: const Icon(Icons.add),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}

// ─── Suggestions dropdown ─────────────────────────────────────────────────────

class _SuggestionsDropdown extends StatelessWidget {
  const _SuggestionsDropdown({
    required this.suggestions,
    required this.onTap,
  });

  final List<AutocompleteSuggestion> suggestions;
  final ValueChanged<AutocompleteSuggestion> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: suggestions.length,
        itemBuilder: (context, i) {
          final s = suggestions[i];
          return ListTile(
            dense: true,
            leading: Icon(
              s.isHouseholdItem ? Icons.inventory_2_outlined : Icons.search,
              size: 18,
            ),
            title: Text(s.name),
            subtitle: s.category != null ? Text(s.category!) : null,
            trailing: Text(
              s.defaultLocation,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            onTap: () => onTap(s),
          );
        },
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        location.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

// ─── Inventory tile ───────────────────────────────────────────────────────────

class _InventoryTile extends StatelessWidget {
  const _InventoryTile({
    required this.item,
    required this.onTap,
    required this.onDismissed,
  });

  final InventoryItem item;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (item.quantity != null && item.quantity!.isNotEmpty) item.quantity!,
      if (item.notes != null && item.notes!.isNotEmpty) item.notes!,
    ].join(' · ');

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Theme.of(context).colorScheme.error,
        child: Icon(Icons.delete_outline,
            color: Theme.of(context).colorScheme.onError),
      ),
      onDismissed: (_) => onDismissed(),
      child: ListTile(
        title: Text(item.itemName),
        subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: onTap,
      ),
    );
  }
}

// ─── Add item bottom sheet ────────────────────────────────────────────────────

class _AddItemSheet extends StatelessWidget {
  const _AddItemSheet({
    required this.name,
    required this.locations,
    required this.initialLocation,
    required this.initialQuantity,
    required this.initialNotes,
    required this.onSave,
  });

  final String name;
  final List<StorageLocation> locations;
  final String initialLocation;
  final String initialQuantity;
  final String initialNotes;
  final void Function(String location, String quantity, String notes) onSave;

  @override
  Widget build(BuildContext context) {
    return _ItemSheet(
      title: 'Add "$name"',
      locations: locations,
      initialLocation: initialLocation,
      initialQuantity: initialQuantity,
      initialNotes: initialNotes,
      saveLabel: 'Add to Pantry',
      onSave: onSave,
    );
  }
}

// ─── Edit item bottom sheet ───────────────────────────────────────────────────

class _EditItemSheet extends StatelessWidget {
  const _EditItemSheet({
    required this.item,
    required this.locations,
    required this.initialLocation,
    required this.initialQuantity,
    required this.initialNotes,
    required this.onSave,
    this.onDelete,
  });

  final InventoryItem item;
  final List<StorageLocation> locations;
  final String initialLocation;
  final String initialQuantity;
  final String initialNotes;
  final void Function(String location, String quantity, String notes) onSave;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return _ItemSheet(
      title: item.itemName,
      locations: locations,
      initialLocation: initialLocation,
      initialQuantity: initialQuantity,
      initialNotes: initialNotes,
      saveLabel: 'Save',
      onSave: onSave,
      onDelete: onDelete,
    );
  }
}

// ─── Shared sheet body ────────────────────────────────────────────────────────

class _ItemSheet extends StatefulWidget {
  const _ItemSheet({
    required this.title,
    required this.locations,
    required this.initialLocation,
    required this.initialQuantity,
    required this.initialNotes,
    required this.saveLabel,
    required this.onSave,
    this.onDelete,
  });

  final String title;
  final List<StorageLocation> locations;
  final String initialLocation;
  final String initialQuantity;
  final String initialNotes;
  final String saveLabel;
  final void Function(String location, String quantity, String notes) onSave;
  final VoidCallback? onDelete;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final TextEditingController _locationCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _notesCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _locationCtrl = TextEditingController(text: widget.initialLocation);
    _quantityCtrl = TextEditingController(text: widget.initialQuantity);
    _notesCtrl = TextEditingController(text: widget.initialNotes);
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _quantityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),

          // Location chips
          if (widget.locations.isNotEmpty) ...[
            Text('Location', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            _LocationChips(
              locations: widget.locations,
              controller: _locationCtrl,
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 12),
          ],

          // Quantity
          TextField(
            controller: _quantityCtrl,
            decoration: const InputDecoration(
              labelText: 'Quantity',
              hintText: 'e.g. 2, 500 ml, half a bag',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 12),

          // Notes
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          // Save button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving
                  ? null
                  : () {
                      setState(() => _saving = true);
                      widget.onSave(
                        _locationCtrl.text.trim(),
                        _quantityCtrl.text.trim(),
                        _notesCtrl.text.trim(),
                      );
                    },
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.saveLabel),
            ),
          ),
          if (widget.onDelete != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: widget.onDelete,
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Delete item'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Location chips ───────────────────────────────────────────────────────────

class _LocationChips extends StatelessWidget {
  const _LocationChips({
    required this.locations,
    required this.controller,
    required this.onChanged,
  });

  final List<StorageLocation> locations;
  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: locations.map((loc) {
        final selected = controller.text == loc.name;
        return ChoiceChip(
          label: Text(loc.name),
          selected: selected,
          onSelected: (_) {
            controller.text = loc.name;
            onChanged();
          },
        );
      }).toList(),
    );
  }
}
