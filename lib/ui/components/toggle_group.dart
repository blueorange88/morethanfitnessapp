import 'package:flutter/material.dart';

class ShadcnToggleGroup extends StatelessWidget {
  final List<String> items;
  final String value;
  final ValueChanged<String> onChanged;

  const ShadcnToggleGroup({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ShadcnToggle(
              value: item == value,
              onChanged: (_) => onChanged(item),
              child: Text(item),
            ),
          ),
      ],
    );
  }
}
