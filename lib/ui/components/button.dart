import 'package:flutter/material.dart';

enum ButtonVariant { solid, outline, ghost, destructive }
enum ButtonSize { sm, md, lg }

class ShadcnButton extends StatelessWidget {
  final ButtonVariant variant;
  final ButtonSize size;
  final VoidCallback? onPressed;
  final Widget child;
  final bool disabled;

  const ShadcnButton({
    super.key,
    required this.child,
    this.variant = ButtonVariant.solid,
    this.size = ButtonSize.md,
    this.onPressed,
    this.disabled = false,
  });

  Color _background(ColorScheme cs) {
    switch (variant) {
      case ButtonVariant.outline:
      case ButtonVariant.ghost:
        return Colors.transparent;
      case ButtonVariant.destructive:
        return cs.error;
      default:
        return cs.primary;
    }
  }

  Color _foreground(ColorScheme cs) {
    switch (variant) {
      case ButtonVariant.outline:
      case ButtonVariant.ghost:
        return cs.primary;
      case ButtonVariant.destructive:
        return cs.onError;
      default:
        return cs.onPrimary;
    }
  }

  EdgeInsets _padding() {
    switch (size) {
      case ButtonSize.sm:
        return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
      case ButtonSize.lg:
        return const EdgeInsets.symmetric(horizontal: 20, vertical: 14);
      default:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
    }
  }

  BorderSide _border(ColorScheme cs) {
    if (variant == ButtonVariant.outline) {
      return BorderSide(color: cs.primary, width: 1.5);
    }
    return BorderSide.none;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Opacity(
      opacity: disabled ? 0.5 : 1.0,
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: _padding(),
          decoration: BoxDecoration(
            color: _background(cs),
            borderRadius: BorderRadius.circular(8),
            border: Border.fromBorderSide(_border(cs)),
          ),
          child: DefaultTextStyle(
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _foreground(cs),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
