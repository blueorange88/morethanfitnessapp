import 'package:flutter/material.dart';

enum AlertVariant { defaultVariant, destructive }

class ShadcnAlert extends StatelessWidget {
  final AlertVariant variant;
  final String title;
  final String description;

  const ShadcnAlert({
    super.key,
    required this.title,
    required this.description,
    this.variant = AlertVariant.defaultVariant,
  });

  Color _background(ColorScheme cs) {
    return variant == AlertVariant.destructive
        ? cs.errorContainer
        : cs.surfaceVariant;
  }

  Color _foreground(ColorScheme cs) {
    return variant == AlertVariant.destructive
        ? cs.onErrorContainer
        : cs.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _background(cs),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style:
            TextStyle(fontWeight: FontWeight.bold, color: _foreground(cs)),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(color: _foreground(cs)),
          ),
        ],
      ),
    );
  }
}
