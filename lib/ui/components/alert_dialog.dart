import 'package:flutter/material.dart';

class ShadcnAlertDialog {
  static Future<void> show({
    required BuildContext context,
    required String title,
    required String description,
    required VoidCallback onConfirm,
    String confirmText = "확인",
    String cancelText = "취소",
  }) async {
    final cs = Theme.of(context).colorScheme;

    return showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: cs.surface,
          insetPadding: const EdgeInsets.all(24),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(description,
                    style: TextStyle(fontSize: 14, color: cs.onSurface)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: Text(cancelText),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onConfirm();
                      },
                      child: Text(confirmText),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
