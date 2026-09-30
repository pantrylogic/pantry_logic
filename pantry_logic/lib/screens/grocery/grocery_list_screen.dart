import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/grocery_item.dart';
import '../../models/item.dart';
import '../../services/grocery_service.dart';
import '../../widgets/add_bar.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/brand.dart';
import '../../core/quantity.dart';

class GroceryListScreen extends StatefulWidget {
  const GroceryListScreen({super.key});

  @override
  State<GroceryListScreen> createState() => _GroceryListScreenState();
}

class _GroceryListScreenState extends State<GroceryListScreen> {
  final _groceryService = GroceryService();

  late final Stream<List<GroceryItem>> _stream;

  @override
  void initState() {
    super.initState();
    // asBroadcastStream allows multiple StreamBuilders (AppBar + body) to listen
    _stream = _groceryService.streamGroceryItems().asBroadcastStream();
  }

  // ─── Add item ────────────────────────────────────────────────────────────────

  /// Adds [name] to the list. [suggestion] is set when the user picked an
  /// autocomplete entry.
  Future<void> _addItem(String name, [AutocompleteSuggestion? suggestion]) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final String itemId;
      if (suggestion?.itemId != null) {
        itemId = suggestion!.itemId!;
      } else {
        final item = await _groceryService.getOrCreateItem(
          name: name,
          category: suggestion?.category,
          defaultLocation: suggestion?.defaultLocation,
        );
        itemId = item.id;
      }
      await _groceryService.addGroceryItem(itemId: itemId);
    } catch (e, st) {
      showErrorSnackBar(messenger, 'Could not add $name. Try again.', e, st);
    }
  }

  // ─── Item actions ────────────────────────────────────────────────────────────

  Future<void> _togglePurchased(GroceryItem item) async {
    try {
      if (item.purchased) {
        await _groceryService.uncheckItem(item.id);
      } else {
        await _groceryService.checkOffItem(item);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Something went wrong. Try again.')),
        );
      }
    }
  }

  Future<void> _deleteItem(GroceryItem item) async {
    try {
      await _groceryService.deleteGroceryItem(item.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not remove item. Try again.')),
        );
      }
    }
  }

  Future<void> _clearCompleted() async {
    try {
      await _groceryService.clearCompleted();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not clear items. Try again.')),
        );
      }
    }
  }

  void _showEditSheet(GroceryItem item) {
    final quantityCtrl = TextEditingController(text: item.quantity ?? '');
    final notesCtrl = TextEditingController(text: item.notes ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.surfaceDm : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.itemName,
              style: nsSans(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDm : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityCtrl,
              decoration: const InputDecoration(
                labelText: 'Quantity',
                hintText: 'e.g. 2, 500g, a few',
              ),
              textCapitalization: TextCapitalization.none,
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Brand, size, etc.',
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _groceryService.updateGroceryItem(
                    item.id,
                    quantity: quantityCtrl.text.trim(),
                    notes: notesCtrl.text.trim(),
                  );
                },
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _deleteItem(item);
                },
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? AppColors.errorDm : AppColors.error,
                ),
                child: const Text('Delete item'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDm : AppColors.primary;
    final textMuted = isDark ? AppColors.textMutedDm : AppColors.textMuted;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Grocery List',
          style: nsSans(fontWeight: FontWeight.w700),
        ),
        actions: [
          StreamBuilder<List<GroceryItem>>(
            stream: _stream,
            builder: (ctx, snap) {
              final hasPurchased =
                  snap.data?.any((i) => i.purchased) ?? false;
              if (!hasPurchased) return const SizedBox.shrink();
              return TextButton(
                onPressed: _clearCompleted,
                child: Text(
                  'Clear completed',
                  style: nsSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── List ────────────────────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<GroceryItem>>(
              stream: _stream,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snap.hasError) {
                  return Center(
                    child: Text(
                      'Could not load grocery list.',
                      style: nsSans(color: textMuted),
                    ),
                  );
                }

                final items = snap.data ?? [];

                // Partition: unpurchased first (oldest→newest), purchased last
                final unpurchased = items
                    .where((i) => !i.purchased)
                    .toList()
                  ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
                final purchased = items
                    .where((i) => i.purchased)
                    .toList()
                  ..sort((a, b) =>
                      (a.purchasedAt ?? a.createdAt)
                          .compareTo(b.purchasedAt ?? b.createdAt));

                final sorted = [...unpurchased, ...purchased];

                if (sorted.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const IconBadge(Icons.check_rounded, size: 56),
                          const SizedBox(height: 12),
                          Text(
                            'Nothing to buy — nice!',
                            style: nsSans(
                              fontSize: 16,
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: sorted.length,
                  itemBuilder: (ctx, i) {
                    final item = sorted[i];
                    return _GroceryItemTile(
                      key: ValueKey(item.id),
                      item: item,
                      onToggle: () => _togglePurchased(item),
                      onEdit: () => _showEditSheet(item),
                      onDelete: () => _deleteItem(item),
                    );
                  },
                );
              },
            ),
          ),

          AddBar(
            hintText: 'Add an item…',
            search: _groceryService.searchAutocomplete,
            textCapitalization: TextCapitalization.words,
            onSubmit: _addItem,
            onSuggestion: (sug) => _addItem(sug.name, sug),
          ),
        ],
      ),
    );
  }
}

// ─── Grocery item tile ─────────────────────────────────────────────────────────

class _GroceryItemTile extends StatelessWidget {
  final GroceryItem item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GroceryItemTile({
    super.key,
    required this.item,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDm : AppColors.primary;
    final textPrimary =
        isDark ? AppColors.textPrimaryDm : AppColors.textPrimary;
    final textMuted = isDark ? AppColors.textMutedDm : AppColors.textMuted;
    final textSecondary =
        isDark ? AppColors.textSecondaryDm : AppColors.textSecondary;
    final surface = isDark ? AppColors.surfaceDm : AppColors.surface;

    final isPurchased = item.purchased;
    final nameColor = isPurchased ? textMuted : textPrimary;
    final rowOpacity = isPurchased ? 0.6 : 1.0;

    return Dismissible(
      key: ValueKey('dismiss_${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: isDark ? AppColors.errorDm : AppColors.error,
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      child: Opacity(
        opacity: rowOpacity,
        child: InkWell(
          onTap: onEdit,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? AppColors.borderDm : AppColors.border,
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                // Checkbox
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      isPurchased
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: isPurchased ? primary : textMuted,
                      size: 24,
                    ),
                  ),
                ),

                // Item name + notes
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.itemName,
                              style: nsSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: nameColor,
                                decoration: isPurchased
                                    ? TextDecoration.lineThrough
                                    : null,
                                decorationColor: nameColor,
                              ),
                            ),
                          ),
                          if (item.quantity != null &&
                              item.quantity!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                formatQuantity(item.quantity),
                                style: nsSans(
                                  fontSize: 13,
                                  color: textSecondary,
                                  decoration: isPurchased
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: textSecondary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (item.notes != null && item.notes!.isNotEmpty)
                        Text(
                          item.notes!,
                          style: nsSans(
                            fontSize: 12,
                            color: textMuted,
                          ),
                        ),
                    ],
                  ),
                ),

                // Added by
                if (item.addedByName != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      item.addedByName!,
                      style: nsSans(
                        fontSize: 12,
                        color: textMuted,
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
