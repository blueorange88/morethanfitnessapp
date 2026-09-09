import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'aifc_theme.dart';

class AifcTypingDots extends StatefulWidget {
  const AifcTypingDots({
    super.key,
    this.color = AifcColors.primary,
  });

  final Color color;

  @override
  State<AifcTypingDots> createState() => _AifcTypingDotsState();
}

class _AifcTypingDotsState extends State<AifcTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _dotValue(int index) {
    final phase = (_ctrl.value * math.pi * 2) - (index * 0.75);
    return (math.sin(phase) + 1) / 2;
  }

  Widget _dot(int index) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final value = _dotValue(index);

        return Transform.scale(
          scale: 0.72 + value * 0.32,
          child: Opacity(
            opacity: 0.35 + value * 0.65,
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      height: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _dot(0),
          _dot(1),
          _dot(2),
        ],
      ),
    );
  }
}