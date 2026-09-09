import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'aifc_avatar.dart';
import 'aifc_theme.dart';
import 'aifc_typing_dots.dart';

enum AifcBubbleSide {
  fc,
  user,
}

class AifcChatBubble extends StatelessWidget {
  const AifcChatBubble({
    super.key,
    required this.side,
    this.text,
    this.child,
    this.dimmed = false,
    this.showAvatar = true,
    this.useThemeSurface = false,
  });

  final AifcBubbleSide side;
  final String? text;
  final Widget? child;
  final bool dimmed;
  final bool showAvatar;
  final bool useThemeSurface;

  bool get _isUser => side == AifcBubbleSide.user;

  @override
  Widget build(BuildContext context) {
    final bubble =
        _isUser ? _buildUserBubble(context) : _buildFcBubble(context);

    return AnimatedOpacity(
      opacity: dimmed ? 0.55 : 1.0,
      duration: const Duration(milliseconds: 220),
      child: bubble,
    );
  }

  Widget _buildUserBubble(BuildContext context) {
    final tokens = context.mtfThemeTokens;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const SizedBox(width: 48),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 11,
            ),
            decoration: BoxDecoration(
              color: tokens.aifcUserBubble,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: tokens.aifcUserBubble.withOpacity(0.24),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              text ?? '',
              style: TextStyle(
                color: tokens.aifcUserBubbleForeground,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFcBubble(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    final backgroundColor = useThemeSurface
        ? colorScheme.surfaceContainerHighest
        : tokens.aifcSurface;
    final borderColor =
        useThemeSurface ? colorScheme.outlineVariant : tokens.cardBorder;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showAvatar) ...[
          AifcAvatar(
            size: 30,
            isAnimating: false,
            backgroundColor: tokens.aifcBackground,
          ),
          const SizedBox(width: 9),
        ] else
          const SizedBox(width: 39),
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: borderColor,
                width: 0.5,
              ),
              boxShadow: AifcShadow.soft,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (text != null && text!.trim().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      11,
                      14,
                      child == null ? 11 : 0,
                    ),
                    child: Text(
                      text!,
                      style: AifcText.body.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                if (child != null) ...[
                  if (text != null && text!.trim().isNotEmpty)
                    const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                    child: child!,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }
}

class AifcTypingBubble extends StatelessWidget {
  const AifcTypingBubble({
    super.key,
    this.showAvatar = true,
  });

  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final tokens = context.mtfThemeTokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showAvatar) ...[
          AifcAvatar(
            size: 30,
            isAnimating: true,
            backgroundColor: tokens.aifcBackground,
          ),
          const SizedBox(width: 9),
        ] else
          const SizedBox(width: 39),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          decoration: BoxDecoration(
            color: tokens.aifcSurface,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(16),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(
              color: tokens.cardBorder,
              width: 0.5,
            ),
            boxShadow: AifcShadow.soft,
          ),
          child: const AifcTypingDots(),
        ),
        const SizedBox(width: 32),
      ],
    );
  }
}
