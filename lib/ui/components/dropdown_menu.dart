import 'package:flutter/material.dart';

class ShadcnDropdownMenuItem {
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;

  ShadcnDropdownMenuItem({
    required this.label,
    required this.onPressed,
    this.icon,
  });
}

class ShadcnDropdownMenu extends StatelessWidget {
  final Widget child;
  final List<ShadcnDropdownMenuItem> items;

  const ShadcnDropdownMenu({
    super.key,
    required this.child,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopupMenuButton<int>(
      color: cs.surface,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (context) {
        return [
          for (int i = 0; i < items.length; i++)
            PopupMenuItem(
              value: i,
              child: Row(
                children: [
                  if (items[i].icon != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(items[i].icon,
                          size: 18, color: cs.onSurfaceVariant),
                    ),
                  Text(items[i].label),
                ],
              ),
            )
        ];
      },
      onSelected: (i) => items[i].onPressed(),
      child: child,
    );
  }
}
