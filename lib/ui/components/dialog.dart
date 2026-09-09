import 'package:flutter/material.dart';

class ShadcnDialog {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool barrierDismissible = true,
  }) {
    final cs = Theme.of(context).colorScheme;

    return showGeneralDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: "Dialog",
      transitionDuration: const Duration(milliseconds: 180),
      barrierColor: Colors.black.withOpacity(0.4),
      pageBuilder: (_, __, ___) => Align(
        alignment: Alignment.center,
        child: Material(
          color: cs.surface,
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
      transitionBuilder: (_, anim, __, child) {
        return Transform.scale(
          scale: 0.95 + (anim.value * 0.05),
          child: Opacity(
            opacity: anim.value,
            child: child,
          ),
        );
      },
    );
  }
}
