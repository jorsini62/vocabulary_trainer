import 'package:flutter/material.dart';

/// Standard modal message used for brief user-facing notifications that
/// require acknowledgement rather than a transient banner.
class AppMessageDialog {
  const AppMessageDialog._();

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String actionLabel = 'OK',
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
