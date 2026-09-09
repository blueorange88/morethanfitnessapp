import 'package:flutter/material.dart';

import 'aifc_theme.dart';

class AifcCard extends StatelessWidget {
  const AifcCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AifcColors.cardBg,
        borderRadius: BorderRadius.circular(AifcRadius.card),
        border: Border.all(color: AifcColors.cardBorder, width: 0.5),
        boxShadow: AifcShadow.soft,
      ),
      child: child,
    );

    if (onTap == null) return card;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: card,
    );
  }
}