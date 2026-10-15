import 'package:flutter/material.dart';

import '../../core/routes.dart';
import '../../core/theme.dart';
import '../../models/meal_consumption.dart';
import '../../services/hungry_service.dart';
import '../../widgets/app_snack_bar.dart';

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
  MealConsumptionPreview? _preview;
  String? _operationId;
  bool _loading = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() => _loading = true);
    try {
      final preview = await _service.getConsumptionPreview(widget.mealId);
      if (mounted) {
        setState(() {
          _preview = preview;
          _operationId = HungryService.newConsumptionOperationId();
        });
      }
    } catch (error, stackTrace) {
      if (mounted) {
        showErrorSnackBar(
          ScaffoldMessenger.of(context),
          'Could not review stock for this meal.',
          error,
          stackTrace,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _confirm() async {
    final preview = _preview;
    final operationId = _operationId;
    if (_submitting || preview == null || operationId == null) return;
    setState(() => _submitting = true);
    try {
      final result = await _service.consumeMeal(
        widget.mealId,
        preview,
        operationId: operationId,
      );
      if (!mounted) return;
      if (result['status'] == 'conflict') {
        showAppSnackBar(
          ScaffoldMessenger.of(context),
          'Stock changed while you were reviewing. Please review it again.',
        );
        await _loadPreview();
        return;
      }
      showAppSnackBar(ScaffoldMessenger.of(context), 'Stock updated.');
      popToRestockOrigin(context);
    } catch (error, stackTrace) {
      if (mounted) {
        showErrorSnackBar(
          ScaffoldMessenger.of(context),
          'Could not update stock. Nothing was changed.',
          error,
          stackTrace,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).brightness == Brightness.dark;
    final surface = colors ? AppColors.surfaceDm : AppColors.surface;
    final border = colors ? AppColors.borderDm : AppColors.border;
    final secondary = colors
        ? AppColors.textSecondaryDm
        : AppColors.textSecondary;
    return Scaffold(
      appBar: AppBar(
        title: Text('Review stock', style: nsSans(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          widget.mealName,
                          style: nsSans(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Review stock changes before confirming.',
                          style: nsSans(fontSize: 15, color: secondary),
                        ),
                        const SizedBox(height: 20),
                        ...?_preview?.items.map(
                          (item) => _ConsumptionRow(
                            item: item,
                            surface: surface,
                            border: border,
                            secondary: secondary,
                          ),
                        ),
                      ],
                    ),
            ),
            Container(
              decoration: BoxDecoration(
                color: surface,
                border: Border(top: BorderSide(color: border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(
                    onPressed: _loading || _submitting ? null : _confirm,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Done - Update Stock',
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
}

class _ConsumptionRow extends StatelessWidget {
  final MealConsumptionItem item;
  final Color surface;
  final Color border;
  final Color secondary;
  const _ConsumptionRow({
    required this.item,
    required this.surface,
    required this.border,
    required this.secondary,
  });
  @override
  Widget build(BuildContext context) {
    final (icon, text) = switch (item.disposition) {
      MealConsumptionDisposition.deduct => (
        Icons.remove_circle_outline_rounded,
        '${item.inventoryQuantity} -> ${item.resultingQuantity == 0 ? 'removed' : item.resultingQuantity}',
      ),
      MealConsumptionDisposition.notTracked => (
        Icons.inventory_2_outlined,
        'Not tracked',
      ),
      MealConsumptionDisposition.checkQuantity => (
        Icons.help_outline_rounded,
        'Check quantity - deduction skipped',
      ),
      MealConsumptionDisposition.shortage => (
        Icons.warning_amber_rounded,
        'Shortage - deduction skipped',
      ),
      MealConsumptionDisposition.absent => (
        Icons.remove_circle_outline_rounded,
        'Not in stock - deduction skipped',
      ),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  style: nsSans(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                Text(text, style: nsSans(fontSize: 13, color: secondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
