import 'package:flutter/material.dart';

class ShadcnSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ShadcnSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Switch(
      value: value,
      onChanged: onChanged,
      activeColor: cs.primary,
      inactiveTrackColor: cs.surfaceVariant,
      activeTrackColor: cs.primaryContainer,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
