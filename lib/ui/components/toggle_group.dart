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
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final item in items)
          _ShadcnToggleItem(
            label: item,
            selected: item == value,
            onTap: () => onChanged(item),
            theme: theme,
          ),
      ],
    );
  }
}

class _ShadcnToggleItem extends StatelessWidget {
  const _ShadcnToggleItem({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.theme,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final selectedBg = theme.colorScheme.primary;
    final unselectedBg = theme.colorScheme.surface;
    final selectedText = theme.colorScheme.onPrimary;
    final unselectedText = theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: selected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? selectedBg
                : theme.colorScheme.outline.withOpacity(0.35),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? selectedText : unselectedText,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}