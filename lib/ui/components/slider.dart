import 'package:flutter/material.dart';

class ShadcnSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final double min;
  final double max;

  const ShadcnSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: cs.primary,
        inactiveTrackColor: cs.surfaceVariant,
        thumbColor: cs.primary,
        overlayColor: cs.primary.withOpacity(0.15),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      ),
      child: Slider(
        value: value,
        onChanged: onChanged,
        min: min,
        max: max,
      ),
    );
  }
}
