import 'package:flutter/material.dart';

class ShadcnRadioItem<T> {
  final T value;
  final String label;

  ShadcnRadioItem({
    required this.value,
    required this.label,
  });
}

class ShadcnRadioGroup<T> extends StatelessWidget {
  final T groupValue;
  final List<ShadcnRadioItem<T>> items;
  final ValueChanged<T> onChanged;

  const ShadcnRadioGroup({
    super.key,
    required this.groupValue,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        for (var item in items)
          InkWell(
            onTap: () => onChanged(item.value),
            child: Row(
              children: [
                Radio<T>(
                  value: item.value,
                  groupValue: groupValue,
                  onChanged: (v) => onChanged(v as T),
                  activeColor: cs.primary,
                ),
                Text(item.label),
              ],
            ),
          ),
      ],
    );
  }
}
