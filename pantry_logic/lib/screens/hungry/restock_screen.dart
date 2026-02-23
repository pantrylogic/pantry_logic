import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/restock_item.dart';
import '../../services/hungry_service.dart';

class RestockScreen extends StatefulWidget {
  final String mealId;
  final String mealName;

  const RestockScreen({
    super.key,
    required this.mealId,
    required this.mealName,
  });

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen> {
  final _service = HungryService();
  List<RestockDecisionItem>? _decisions;
  bool _loading = true;

  // Track which items have been acted on (itemId → true = add to list, false = still have)
  final Map<String, bool?> _choices = {};
  final Set<String> _actionInProgress = {};

  @override
  void initState() {
    super.initState();
    _executeRestock();
  }

  Future<void> _executeRestock() async {
    try {
      final decisions = await _service.executeRestock(widget.mealId);
      if (mounted) setState(() => _decisions = decisions);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not process restock: $e')),
        );
        setState(() => _decisions = []);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addToList(RestockDecisionItem item) async {
    if (_actionInProgress.contains(item.itemId)) return;
    setState(() => _actionInProgress.add(item.itemId));
    try {
      await _service.addToGroceryList(item.itemId);
      // For no-quantity items: also remove from inventory
      if (item.reason == RestockReason.noQuantity) {
        await _service.removeFromInventoryByItemId(item.itemId);
      }
      if (mounted) setState(() => _choices[item.itemId] = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not add to list: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionInProgress.remove(item.itemId));
    }
  }

  void _stillHave(RestockDecisionItem item) {
    setState(() => _choices[item.itemId] = false);
  }

  void _skip(RestockDecisionItem item) {
    setState(() => _choices[item.itemId] = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDm : AppColors.primary;
    final textPrimary =
        isDark ? AppColors.textPrimaryDm : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.textSecondaryDm : AppColors.textSecondary;
    final textMuted = isDark ? AppColors.textMutedDm : AppColors.textMuted;
    final surface = isDark ? AppColors.surfaceDm : AppColors.surface;
    final border = isDark ? AppColors.borderDm : AppColors.border;
    final success = isDark ? AppColors.successDm : AppColors.success;
    final warning = isDark ? AppColors.warningDm : AppColors.warning;

    final decisions = _decisions ?? [];
    final hasDecisions = decisions.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('Enjoy!', style: nsSans(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Header ──────────────────────────────────────────
                          Text(
                            widget.mealName,
                            style: nsSans(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            hasDecisions
                                ? 'Need to restock anything?'
                                : 'You\'re all set — nothing to restock.',
                            style: nsSans(
                                fontSize: 15, color: textSecondary),
                          ),

                          if (hasDecisions) ...[
                            const SizedBox(height: 28),

                            // ── Decision items ───────────────────────────────
                            ...decisions.map((item) {
                              final chosen = _choices[item.itemId];
                              final inProgress =
                                  _actionInProgress.contains(item.itemId);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: chosen != null
                                          ? (chosen
                                              ? primary.withValues(alpha: 0.3)
                                              : border)
                                          : border,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            item.reason ==
                                                    RestockReason.hitZero
                                                ? Icons
                                                    .remove_circle_outline_rounded
                                                : Icons
                                                    .help_outline_rounded,
                                            size: 18,
                                            color: item.reason ==
                                                    RestockReason.hitZero
                                                ? warning
                                                : textMuted,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              item.itemName,
                                              style: nsSans(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.reason == RestockReason.hitZero
                                            ? 'Ran out — add to grocery list?'
                                            : 'Still in the pantry?',
                                        style: nsSans(
                                          fontSize: 13,
                                          color: textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 12),

                                      // Action buttons or result
                                      if (chosen != null)
                                        Row(
                                          children: [
                                            Icon(
                                              chosen
                                                  ? Icons.check_circle_rounded
                                                  : Icons
                                                      .check_circle_outline_rounded,
                                              size: 16,
                                              color: success,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              chosen
                                                  ? 'Added to grocery list'
                                                  : (item.reason ==
                                                          RestockReason
                                                              .hitZero
                                                      ? 'Skipped'
                                                      : 'Keeping it'),
                                              style: nsSans(
                                                fontSize: 13,
                                                color: success,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        )
                                      else if (inProgress)
                                        const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      else
                                        Row(
                                          children: [
                                            if (item.reason ==
                                                RestockReason.hitZero) ...[
                                              _ActionButton(
                                                label: 'Add to list',
                                                filled: true,
                                                primary: primary,
                                                surface: surface,
                                                onTap: () =>
                                                    _addToList(item),
                                              ),
                                              const SizedBox(width: 8),
                                              _ActionButton(
                                                label: 'Skip',
                                                filled: false,
                                                primary: primary,
                                                surface: surface,
                                                onTap: () => _skip(item),
                                              ),
                                            ] else ...[
                                              _ActionButton(
                                                label: 'Add to list',
                                                filled: true,
                                                primary: primary,
                                                surface: surface,
                                                onTap: () =>
                                                    _addToList(item),
                                              ),
                                              const SizedBox(width: 8),
                                              _ActionButton(
                                                label: 'Still have some',
                                                filled: false,
                                                primary: primary,
                                                surface: surface,
                                                onTap: () =>
                                                    _stillHave(item),
                                              ),
                                            ],
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
            ),

            // ── Done button ───────────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: surface,
                border: Border(top: BorderSide(color: border, width: 0.5)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: FilledButton(
                    onPressed: !_loading
                        ? () => Navigator.of(context)
                            .popUntil((r) => r.isFirst || _shouldStop(r))
                        : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Done',
                      style: nsSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Pop back to the screen that opened the Hungry flow (or the meal detail).
  // We stop at MealDetailScreen or HungryCategoryScreen.
  bool _shouldStop(Route route) {
    final name = route.settings.name;
    return name == '/meal-detail' ||
        name == '/hungry-category' ||
        route.isFirst;
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final Color primary;
  final Color surface;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.filled,
    required this.primary,
    required this.surface,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? primary : Colors.transparent,
          border: Border.all(color: primary),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: nsSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: filled ? surface : primary,
          ),
        ),
      ),
    );
  }
}
