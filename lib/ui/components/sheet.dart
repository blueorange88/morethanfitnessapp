import 'package:flutter/material.dart';

class ShadcnSheet {
  static Future<T?> show<T>(
      BuildContext context, {
        required Widget child,
        bool dragClose = true,
      }) {
    final cs = Theme.of(context).colorScheme;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      enableDrag: dragClose,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 12,
          ),
          child: child,
        );
      },
    );
  }
}
