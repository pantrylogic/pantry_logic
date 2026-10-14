import 'dart:developer' as developer;

import 'package:flutter/material.dart';

// Snackbar helpers. They take a [ScaffoldMessengerState] (not a
// BuildContext) so callers can capture it before an async gap.

/// Shows a plain message, replacing any snackbar currently visible.
void showAppSnackBar(
  ScaffoldMessengerState messenger,
  String message, {
  SnackBarAction? action,
  Duration duration = const Duration(seconds: 3),
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), action: action, duration: duration),
    );
}

/// Logs [error] for developers and shows [message] to the user.
/// Raw exception text is never shown in the UI.
void showErrorSnackBar(
  ScaffoldMessengerState messenger,
  String message,
  Object error, [
  StackTrace? stackTrace,
]) {
  logError(message, error, stackTrace);
  showAppSnackBar(messenger, message);
}

/// Shows [message] with an Undo action that runs [onUndo].
///
/// [secondaryLabel]/[onSecondary] add a second action (SnackBar only
/// supports one), shown as a button before Undo.
void showUndoSnackBar(
  ScaffoldMessengerState messenger,
  String message, {
  required VoidCallback onUndo,
  String? secondaryLabel,
  VoidCallback? onSecondary,
  Duration duration = const Duration(seconds: 5),
}) {
  if (secondaryLabel == null || onSecondary == null) {
    showAppSnackBar(
      messenger,
      message,
      duration: duration,
      action: SnackBarAction(label: 'Undo', onPressed: onUndo),
    );
    return;
  }
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        content: LayoutBuilder(builder: (context, constraints) {
          final color = Theme.of(context).snackBarTheme.actionTextColor;
          Widget button(String label, VoidCallback onPressed) => TextButton(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  onPressed();
                },
                style: TextButton.styleFrom(
                  foregroundColor: color,
                  minimumSize: const Size(48, 40),
                ),
                child: Text(label),
              );
          final buttons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              button(secondaryLabel, onSecondary),
              button('Undo', onUndo),
            ],
          );
          // Phones: buttons under the message so nothing gets squeezed.
          if (constraints.maxWidth < 400) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message),
                Align(alignment: Alignment.centerRight, child: buttons),
              ],
            );
          }
          return Row(children: [Expanded(child: Text(message)), buttons]);
        }),
        padding: const EdgeInsets.fromLTRB(16, 6, 8, 2),
      ),
    );
}

/// Records an error in the developer log.
void logError(String context, Object error, [StackTrace? stackTrace]) {
  developer.log(
    context,
    name: 'pantry_logic',
    error: error,
    stackTrace: stackTrace,
  );
}
