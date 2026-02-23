import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../models/meal_category.dart';
import '../../services/hungry_service.dart';
import 'hungry_suggestion_screen.dart';

class HungryCategoryScreen extends StatefulWidget {
  const HungryCategoryScreen({super.key});

  @override
  State<HungryCategoryScreen> createState() => _HungryCategoryScreenState();
}

class _HungryCategoryScreenState extends State<HungryCategoryScreen> {
  final _service = HungryService();
  List<MealCategory>? _categories;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cats = await _service.getCategories();
      if (mounted) setState(() => _categories = cats);
    } catch (e) {
      if (mounted) {
        setState(() => _categories = []);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load categories: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _pick(MealCategory cat) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HungrySuggestionScreen(
        categoryId: cat.id,
        categoryName: cat.name,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDm : AppColors.primary;
    final accentLight =
        isDark ? AppColors.accentLightDm : AppColors.accentLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDm : AppColors.textPrimary;
    final textMuted = isDark ? AppColors.textMutedDm : AppColors.textMuted;
    final surface = isDark ? AppColors.surfaceDm : AppColors.surface;
    final border = isDark ? AppColors.borderDm : AppColors.border;

    return Scaffold(
      appBar: AppBar(
        title: Text("I'm Hungry", style: nsSans(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _categories == null || _categories!.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🍽️',
                              style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 16),
                          Text(
                            'No meal categories yet',
                            style: nsSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add some meals first so we can help you decide.',
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
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                    children: [
                      Text(
                        'What are you feeling?',
                        style: nsSans(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Pick a category and we\'ll find something good.',
                        style: nsSans(fontSize: 14, color: textMuted),
                      ),
                      const SizedBox(height: 24),
                      ..._categories!.map((cat) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _CategoryCard(
                              category: cat,
                              primary: primary,
                              accentLight: accentLight,
                              textPrimary: textPrimary,
                              surface: surface,
                              border: border,
                              onTap: () => _pick(cat),
                            ),
                          )),
                    ],
                  ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final MealCategory category;
  final Color primary;
  final Color accentLight;
  final Color textPrimary;
  final Color surface;
  final Color border;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.primary,
    required this.accentLight,
    required this.textPrimary,
    required this.surface,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.restaurant_rounded,
                  color: primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  category.name,
                  style: nsSans(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: primary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
