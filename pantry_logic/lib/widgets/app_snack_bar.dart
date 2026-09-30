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
void showUndoSnackBar(
  ScaffoldMessengerState messenger,
  String message, {
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 5),
}) {
  showAppSnackBar(
    messenger,
    message,
    duration: duration,
    action: SnackBarAction(label: 'Undo', onPressed: onUndo),
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
