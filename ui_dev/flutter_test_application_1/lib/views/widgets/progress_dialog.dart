import 'package:flutter/material.dart';

/// A blocking "please wait" dialog with a spinner and a label.
///
/// Use this rather than dropping a bare [Text] into `showDialog`: a dialog
/// route has no [Material] ancestor of its own, and text without one falls back
/// to Flutter's red-on-yellow debug style instead of the app's theme.
class ProgressDialog extends StatelessWidget {
  const ProgressDialog({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      // The caller pops this itself once the work finishes, and pops nothing
      // else. A stray dismiss would leave it popping the wrong route.
      canPop: false,
      child: Dialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: 20),
              Flexible(
                child: Text(
                  message,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
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
