import 'package:flutter/material.dart';

class ShadcnSeparator extends StatelessWidget {
  final Axis direction;
  final double thickness;

  const ShadcnSeparator({
    super.key,
    this.direction = Axis.horizontal,
    this.thickness = 1,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: direction == Axis.horizontal ? double.infinity : thickness,
      height: direction == Axis.horizontal ? thickness : double.infinity,
      color: cs.outline.withOpacity(0.4),
    );
  }
}
