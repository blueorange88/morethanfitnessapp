import 'package:flutter/material.dart';

class ShadcnProgress extends StatelessWidget {
  final double value; // 0.0 ~ 1.0

  const ShadcnProgress({
    super.key,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: value,
        backgroundColor: cs.surfaceVariant,
        color: cs.primary,
        minHeight: 6,
      ),
    );
  }
}
