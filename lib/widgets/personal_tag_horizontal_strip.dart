import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PersonalTagManagementButton extends StatelessWidget {
  const PersonalTagManagementButton({
    super.key,
    required this.onPressed,
    this.dimension = 40,
    this.semanticLabel = '태그 관리',
  });

  final VoidCallback onPressed;
  final double dimension;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: SizedBox.square(
          dimension: dimension,
          child: Material(
            color: tokens.cardSurface,
            shape: CircleBorder(
              side: BorderSide(color: tokens.cardBorder),
            ),
            child: InkWell(
              key: const ValueKey('personal_tag_management_button'),
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: Icon(
                Icons.settings_rounded,
                size: dimension <= 32 ? 16 : 18,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PersonalTagHorizontalStrip extends StatelessWidget {
  const PersonalTagHorizontalStrip({
    super.key,
    required this.children,
    this.fixedLeading,
    this.gap = 8,
    this.height = 40,
    this.scrollKey = const ValueKey('personal_tag_horizontal_scroll'),
  });

  final Widget? fixedLeading;
  final List<Widget> children;
  final double gap;
  final double height;
  final Key scrollKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (fixedLeading != null) ...[
            fixedLeading!,
            SizedBox(width: gap),
          ],
          Expanded(
            child: SingleChildScrollView(
              key: scrollKey,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: children,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
