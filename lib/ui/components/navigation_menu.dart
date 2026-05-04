import 'package:flutter/material.dart';

class ShadcnNavItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  ShadcnNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

class ShadcnNavigationMenu extends StatelessWidget {
  final List<ShadcnNavItem> items;
  final int selected;

  const ShadcnNavigationMenu({
    super.key,
    required this.items,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return NavigationRail(
      selectedIndex: selected,
      backgroundColor: cs.surface,
      onDestinationSelected: (i) => items[i].onTap(),
      destinations: [
        for (var i = 0; i < items.length; i++)
          NavigationRailDestination(
            icon: Icon(items[i].icon),
            selectedIcon: Icon(items[i].icon, color: cs.primary),
            label: Text(items[i].label),
          )
      ],
    );
  }
}
