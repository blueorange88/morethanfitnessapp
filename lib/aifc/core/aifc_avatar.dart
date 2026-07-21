import 'dart:math' as math;
import 'package:flutter/material.dart';

const Color kAifcPrimary = Color(0xFF4F46E5);
const Color kAifcSecond = Color(0xFF9333EA);
const Color kAifcBlue = Color(0xFF38BDF8);

const List<Color> kAifcRingColors = [
  Color(0xFF4F46E5),
  Color(0xFF9333EA),
  Color(0xFF38BDF8),
  Color(0xFF4F46E5),
];

class AifcAvatar extends StatefulWidget {
  const AifcAvatar({
    super.key,
    this.size = 34,
    this.isAnimating = true,
    this.backgroundColor,
  });

  final double size;
  final bool isAnimating;
  final Color? backgroundColor;

  @override
  State<AifcAvatar> createState() => _AifcAvatarState();
}

class _AifcAvatarState extends State<AifcAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  double get _outerSize => widget.size + 8;
  double get _whiteSize => widget.size + 4;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant AifcAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isAnimating != widget.isAnimating) {
      _syncAnimation();
    }
  }

  void _syncAnimation() {
    if (widget.isAnimating) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _outerSize,
      height: _outerSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * math.pi * 2,
                child: child,
              );
            },
            child: Container(
              width: _outerSize,
              height: _outerSize,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: kAifcRingColors,
                ),
              ),
            ),
          ),
          Container(
            width: _whiteSize,
            height: _whiteSize,
            decoration: BoxDecoration(
              color: widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
              shape: BoxShape.circle,
            ),
          ),
          Container(
            width: widget.size,
            height: widget.size,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  kAifcPrimary,
                  kAifcSecond,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Text(
              'FC',
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.size * 0.34,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}