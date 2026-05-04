import 'package:flutter/material.dart';

class ShadcnDrawer {
  static Future<T?> show<T>(
      BuildContext context, {
        required Widget child,
        Duration duration = const Duration(milliseconds: 250),
        Alignment alignment = Alignment.centerRight,
        double width = 320,
      }) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Drawer',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: duration,
      pageBuilder: (context, anim, secAnim) {
        return SafeArea(
          child: Align(
            alignment: alignment,
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: SizedBox(
                width: width,
                child: child,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim, child) {
        return SlideTransition(
          position: Tween(
            begin: const Offset(1.0, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)),
          child: child,
        );
      },
    );
  }
}
