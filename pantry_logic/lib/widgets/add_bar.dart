import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/item.dart';
import 'app_snack_bar.dart';

/// The text-input "add" bar pinned to the bottom of list screens, with an
/// optional autocomplete dropdown that opens above it.
///
/// Place it as the last child of a screen's body [Column].
class AddBar extends StatefulWidget {
  const AddBar({
    super.key,
    required this.hintText,
    required this.onSubmit,
    this.search,
    this.onSuggestion,
    this.suggestionTrailing = SuggestionTrailing.category,
    this.textCapitalization = TextCapitalization.sentences,
    this.keepFocusAfterSubmit = true,
    this.onSuggestionsVisibilityChanged,
  });

  final String hintText;

  /// Called with the trimmed text when the user submits. The bar clears
  /// itself before calling this.
  final Future<void> Function(String text) onSubmit;

  /// Autocomplete lookup. When null, no dropdown is shown.
  final Future<List<AutocompleteSuggestion>> Function(String query)? search;

  /// Called when the user taps a suggestion.
  final Future<void> Function(AutocompleteSuggestion suggestion)?
      onSuggestion;

  /// What to show on the right of each suggestion.
  final SuggestionTrailing suggestionTrailing;

  final TextCapitalization textCapitalization;

  /// Keep the keyboard open after adding (good for rapid entry). Set to
  /// false when submitting opens a sheet.
  final bool keepFocusAfterSubmit;

  final ValueChanged<bool>? onSuggestionsVisibilityChanged;

  @override
  State<AddBar> createState() => _AddBarState();
}

enum SuggestionTrailing { category, location }

class _AddBarState extends State<AddBar> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<AutocompleteSuggestion> _suggestions = [];
  bool _busy = false;

  bool get _showing => _suggestions.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onChanged);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setSuggestions(List<AutocompleteSuggestion> list) {
    final wasShowing = _showing;
    setState(() => _suggestions = list);
    if (wasShowing != _showing) {
      widget.onSuggestionsVisibilityChanged?.call(_showing);
    }
  }

  Future<void> _onChanged() async {
    // Rebuild so the trailing add button tracks whether there's text.
    setState(() {});
    final search = widget.search;
    if (search == null) return;
    final q = _ctrl.text.trim();
    if (q.isEmpty) {
      _setSuggestions([]);
      return;
    }
    try {
      final results = await search(q);
      // Ignore stale responses.
      if (!mounted || _ctrl.text.trim() != q) return;
      _setSuggestions(results);
    } catch (e, st) {
      logError('Autocomplete failed', e, st);
    }
  }

  void _hide() {
    if (_showing) _setSuggestions([]);
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    _ctrl.clear();
    _hide();
    if (!widget.keepFocusAfterSubmit) _focus.unfocus();
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      _focus.unfocus();
      return;
    }
    await _run(() => widget.onSubmit(text));
  }

  Future<void> _pick(AutocompleteSuggestion s) async {
    final handler = widget.onSuggestion;
    await _run(() => handler != null ? handler(s) : widget.onSubmit(s.name));
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final hasText = _ctrl.text.trim().isNotEmpty;

    Widget? suffix;
    if (_busy) {
      suffix = Padding(
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: p.primary),
        ),
      );
    } else if (hasText) {
      suffix = IconButton(
        tooltip: 'Add',
        onPressed: _submit,
        icon: Icon(Icons.add_circle_rounded, color: p.primary, size: 28),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showing)
          TextFieldTapRegion(
            child: _SuggestionList(
              suggestions: _suggestions,
              trailing: widget.suggestionTrailing,
              onTap: _pick,
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: p.surface,
            border: Border(top: BorderSide(color: p.border, width: 0.5)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                textCapitalization: widget.textCapitalization,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onTapOutside: (_) {
                  _hide();
                  _focus.unfocus();
                },
                style: nsSans(fontSize: 15, color: p.textPrimary),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  prefixIcon:
                      Icon(Icons.add_rounded, color: p.primary, size: 22),
                  suffixIcon: suffix,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    required this.suggestions,
    required this.trailing,
    required this.onTap,
  });

  final List<AutocompleteSuggestion> suggestions;
  final SuggestionTrailing trailing;
  final ValueChanged<AutocompleteSuggestion> onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Material(
      color: p.surface,
      elevation: 2,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 240),
        child: ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: suggestions.length,
          separatorBuilder: (ctx2, i2) =>
              Divider(height: 1, indent: 44, color: p.border),
          itemBuilder: (context, i) {
            final s = suggestions[i];
            final trailingText = trailing == SuggestionTrailing.location
                ? s.defaultLocation
                : s.category;
            return InkWell(
              onTap: () => onTap(s),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      s.isHouseholdItem
                          ? Icons.history_rounded
                          : Icons.add_rounded,
                      size: 16,
                      color: s.isHouseholdItem ? p.primary : p.textMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.name,
                        style: nsSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: p.textPrimary,
                        ),
                      ),
                    ),
                    if (trailingText != null)
                      Text(
                        trailingText,
                        style: nsSans(fontSize: 12, color: p.textMuted),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
