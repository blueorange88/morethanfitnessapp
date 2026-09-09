import 'package:flutter/material.dart';

class ShadcnSkeleton extends StatefulWidget {
  final double height;
  final double width;
  final BorderRadius? radius;

  const ShadcnSkeleton({
    super.key,
    this.height = 16,
    this.width = double.infinity,
    this.radius,
  });

  @override
  State<ShadcnSkeleton> createState() => _ShadcnSkeletonState();
}

class _ShadcnSkeletonState extends State<ShadcnSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.radius ?? BorderRadius.circular(8),
            color:
            Colors.grey[(300 + (_ctrl.value * 100).toInt()).clamp(300, 400)],
          ),
        );
      },
    );
  }
}
