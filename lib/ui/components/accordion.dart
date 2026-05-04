import 'package:flutter/material.dart';

class ShadcnAccordion extends StatelessWidget {
  final List<AccordionItemData> items;

  const ShadcnAccordion({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: items
          .map(
            (item) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
          ),
          child: ExpansionTile(
            tilePadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            childrenPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            title: Text(
              item.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            iconColor: cs.primary,
            collapsedIconColor: cs.onSurface.withOpacity(0.6),
            children: [
              DefaultTextStyle(
                style: TextStyle(
                  fontSize: 14,
                  color: cs.onSurfaceVariant,
                ),
                child: item.content,
              ),
            ],
          ),
        ),
      )
          .toList(),
    );
  }
}

class AccordionItemData {
  final String title;
  final Widget content;

  AccordionItemData({
    required this.title,
    required this.content,
  });
}
