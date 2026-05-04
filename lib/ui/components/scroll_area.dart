import 'package:flutter/material.dart';

class ShadcnScrollArea extends StatelessWidget {
  final Widget child;

  const ShadcnScrollArea({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ScrollConfiguration(
      behavior: _NoGlowScroll(),
      child: Scrollbar(
        thumbVisibility: true,
        radius: const Radius.circular(8),
        thickness: 6,
        trackVisibility: true,
        child: child,
      ),
    );
  }
}

class _NoGlowScroll extends ScrollBehavior {
  @override
  Widget buildViewportChrome(
      BuildContext context, Widget child, AxisDirection axisDirection) {
    return child;
  }
}
