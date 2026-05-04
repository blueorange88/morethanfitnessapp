import 'package:flutter/material.dart';

class ShadcnSidebarItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  ShadcnSidebarItem({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class ShadcnSidebar extends StatelessWidget {
  final List<ShadcnSidebarItem> items;
  final double width;

  const ShadcnSidebar({
    super.key,
    required this.items,
    this.width = 220,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: width,
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          right: BorderSide(color: cs.outline.withOpacity(0.3)),
        ),
      ),
      child: ListView(
        children: [
          for (var item in items)
            ListTile(
              leading: Icon(item.icon, color: cs.onSurfaceVariant),
              title: Text(item.label),
              onTap: item.onTap,
            )
        ],
      ),
    );
  }
}
