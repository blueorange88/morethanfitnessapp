import 'package:flutter/material.dart';

class ShadcnMenuBarItem {
  final String label;
  final VoidCallback onTap;
  ShadcnMenuBarItem({required this.label, required this.onTap});
}

class ShadcnMenuBar extends StatelessWidget {
  final List<ShadcnMenuBarItem> items;

  const ShadcnMenuBar({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var item in items)
          PopupMenuButton(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(item.label,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Text(item.label),
                onTap: item.onTap,
              )
            ],
          )
      ],
    );
  }
}
