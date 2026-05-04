import 'package:flutter/material.dart';

class ShadcnCarousel extends StatefulWidget {
  final List<Widget> items;

  const ShadcnCarousel({
    super.key,
    required this.items,
  });

  @override
  State<ShadcnCarousel> createState() => _ShadcnCarouselState();
}

class _ShadcnCarouselState extends State<ShadcnCarousel> {
  final PageController _ctrl = PageController();

  @override
  Widget build(BuildContext context) {
    return PageView(
      controller: _ctrl,
      children: widget.items,
    );
  }
}
