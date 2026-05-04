import 'package:flutter/material.dart';

class ShadcnCard extends StatelessWidget {
  final Widget? header;
  final Widget? content;
  final Widget? footer;

  const ShadcnCard({
    super.key,
    this.header,
    this.content,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) header!,
          if (content != null) Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: content!,
          ),
          if (footer != null) footer!,
        ],
      ),
    );
  }
}
