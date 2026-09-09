import 'package:flutter/material.dart';

class ShadcnSelectItem<T> {
  final String label;
  final T value;

  ShadcnSelectItem({
    required this.label,
    required this.value,
  });
}

class ShadcnSelect<T> extends StatelessWidget {
  final List<ShadcnSelectItem<T>> items;
  final T value;
  final ValueChanged<T> onChanged;

  const ShadcnSelect({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outline.withOpacity(0.5)),
      ),
      child: DropdownButton<T>(
        value: value,
        underline: const SizedBox(),
        icon: Icon(Icons.expand_more, color: cs.onSurfaceVariant),
        isExpanded: true,
        onChanged: (v) => onChanged(v as T),
        items: [
          for (var item in items)
            DropdownMenuItem(
              value: item.value,
              child: Text(
                item.label,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            )
        ],
      ),
    );
  }
}
