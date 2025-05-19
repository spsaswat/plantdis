import 'package:flutter/material.dart';
import 'dart:async';

class UIUtils {
  /// Shows a loading dialog with a spinner and optional message
  static void showLoadingDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 20),
                Text(message, style: TextStyle(fontSize: 16)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Format disease name for display by replacing underscores with spaces
  static String formatDiseaseName(String diseaseName) {
    if (diseaseName == 'No disease detected' || diseaseName == 'N/A') {
      return diseaseName;
    }
    return diseaseName.replaceAll('_', ' ');
  }

  /// Shows a deletion loading dialog that auto-dismisses.
  static void showDeletionDialog(
    BuildContext context,
    String message, {
    int timeoutSeconds = 5, // Shorter timeout now
  }) {
    // Create a timer that will auto-close the dialog
    Timer? timeoutTimer = Timer(Duration(seconds: timeoutSeconds), () {
      // Ensure context is still valid before trying to pop
      if (Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false, // User cannot dismiss manually
      builder: (BuildContext dialogContext) {
        return WillPopScope(
          onWillPop: () async => false, // Prevent back button from closing
          child: Dialog(
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                  SizedBox(height: 10),
                  Text(
                    "Deletion continuing in background...", // Simpler message
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  // Removed Button
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      // Ensure timer is cancelled when dialog is dismissed
      timeoutTimer.cancel();
    });
    // No completer or return value needed
  }

  /// Shows a confirmation dialog with customizable actions
  static Future<bool> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color confirmColor = Colors.red,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              child: Text(cancelText),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text(confirmText, style: TextStyle(color: confirmColor)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// Shows a snackbar with the given message
  static void showSnackBar(
    BuildContext context,
    String message, {
    Color backgroundColor = Colors.black87,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Shows a success snackbar
  static void showSuccessSnackBar(BuildContext context, String message) {
    showSnackBar(context, message, backgroundColor: Colors.green);
  }

  /// Shows an error snackbar
  static void showErrorSnackBar(BuildContext context, String message) {
    showSnackBar(context, message, backgroundColor: Colors.red);
  }
}
