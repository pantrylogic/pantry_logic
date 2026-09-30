import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Opens a modal bottom sheet with the app's standard configuration.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: builder,
  );
}

/// Standard bottom-sheet body: drag handle, optional title, padding, and
/// keyboard-aware bottom inset. Content scrolls if it doesn't fit.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    this.title,
    this.titleTrailing,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  });

  final String? title;
  final Widget? titleTrailing;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: padding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                if (title != null) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title!,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (titleTrailing != null) titleTrailing!,
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
