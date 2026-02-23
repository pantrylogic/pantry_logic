import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/suggested_meal.dart';
import '../../services/hungry_service.dart';
import 'restock_screen.dart';

class HungrySuggestionScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const HungrySuggestionScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<HungrySuggestionScreen> createState() =>
      _HungrySuggestionScreenState();
}

class _HungrySuggestionScreenState extends State<HungrySuggestionScreen> {
  final _service = HungryService();
  List<SuggestedMeal>? _meals;
  int _index = 0;
  bool _loading = true;
  bool _eating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final meals = await _service.getSuggestions(widget.categoryId);
      if (mounted) setState(() => _meals = meals);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load suggestions: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _next() {
    if (_meals == null) return;
    setState(() => _index = (_index + 1).clamp(0, _meals!.length - 1));
  }

  Future<void> _eatThis(SuggestedMeal meal) async {
    if (_eating) return;
    setState(() => _eating = true);
    try {
      if (!meal.hasNeedList) {
        // No need list — just confirm and go back
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Enjoy ${meal.name}! 🍽️'),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RestockScreen(
          mealId: meal.id,
          mealName: meal.name,
        ),
      ));
    } finally {
      if (mounted) setState(() => _eating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDm : AppColors.primary;
    final accentLight =
        isDark ? AppColors.accentLightDm : AppColors.accentLight;
    final accentSoft = isDark ? AppColors.accentSoftDm : AppColors.accentSoft;
    final textPrimary =
        isDark ? AppColors.textPrimaryDm : AppColors.textPrimary;
    final textSecondary =
        isDark ? AppColors.textSecondaryDm : AppColors.textSecondary;
    final textMuted = isDark ? AppColors.textMutedDm : AppColors.textMuted;
    final surface = isDark ? AppColors.surfaceDm : AppColors.surface;
    final border = isDark ? AppColors.borderDm : AppColors.border;
    final success = isDark ? AppColors.successDm : AppColors.success;
    final warning = isDark ? AppColors.warningDm : AppColors.warning;

    final meals = _meals;
    final hasMeals = meals != null && meals.isNotEmpty;
    final meal = hasMeals ? meals[_index] : null;
    final isLast = hasMeals && _index >= meals.length - 1;

    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '← Category',
            style: nsSans(fontSize: 14, color: primary),
          ),
        ),
        leadingWidth: 110,
        title: Text(
          widget.categoryName,
          style: nsSans(fontWeight: FontWeight.w700),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : !hasMeals
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🤔',
                              style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 16),
                          Text(
                            'No meals in this category yet',
                            style: nsSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add some meals to ${widget.categoryName} and they\'ll show up here.',
                            textAlign: TextAlign.center,
                            style: nsSans(
                              fontSize: 14,
                              color: textMuted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Counter ──────────────────────────────────────────
                        Text(
                          '${_index + 1} of ${meals.length}',
                          style: nsSans(fontSize: 12, color: textMuted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),

                        // ── Suggestion card ───────────────────────────────────
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Meal name
                                Text(
                                  meal!.name,
                                  style: nsSans(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    color: textPrimary,
                                    height: 1.2,
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Inventory status
                                if (!meal.hasNeedList)
                                  _StatusRow(
                                    icon: Icons.format_list_bulleted_rounded,
                                    color: textMuted,
                                    text: 'No need list',
                                  )
                                else if (meal.allInPantry)
                                  _StatusRow(
                                    icon: Icons.check_circle_rounded,
                                    color: success,
                                    text: 'You have everything ✓',
                                  )
                                else ...[
                                  _StatusRow(
                                    icon:
                                        Icons.radio_button_unchecked_rounded,
                                    color: warning,
                                    text:
                                        'Missing ${meal.missingCount} item${meal.missingCount == 1 ? '' : 's'}',
                                  ),
                                  if (meal.missingItemNames.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: meal.missingItemNames
                                          .map(
                                            (name) => Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 10,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: warning
                                                    .withValues(alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                name,
                                                style: nsSans(
                                                  fontSize: 12,
                                                  color: warning,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                                  ],
                                ],

                                const Spacer(),

                                // Pool indicator
                                if (meal.allInPantry || !meal.hasNeedList)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: accentSoft
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Ready to make',
                                      style: nsSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: primary,
                                      ),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: accentLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Missing a few things',
                                      style: nsSans(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: textSecondary,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Actions ───────────────────────────────────────────
                        FilledButton(
                          onPressed: _eating ? null : () => _eatThis(meal),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _eating
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: surface,
                                  ),
                                )
                              : Text(
                                  'Eat This 🍽️',
                                  style: nsSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: isLast ? null : _next,
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isLast
                                ? 'No more suggestions'
                                : 'Suggest Another',
                            style: nsSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isLast ? textMuted : primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _StatusRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          text,
          style: nsSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
