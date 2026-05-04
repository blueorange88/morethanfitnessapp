import 'package:flutter/material.dart';

class ShadcnPopover extends StatefulWidget {
  final Widget trigger;
  final Widget content;

  const ShadcnPopover({
    super.key,
    required this.trigger,
    required this.content,
  });

  @override
  State<ShadcnPopover> createState() => _ShadcnPopoverState();
}

class _ShadcnPopoverState extends State<ShadcnPopover> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlay;

  void _show() {
    if (_overlay != null) return;

    _overlay = OverlayEntry(
      builder: (_) => Positioned(
        child: CompositedTransformFollower(
          link: _link,
          offset: const Offset(0, 10),
          child: Material(
            borderRadius: BorderRadius.circular(10),
            elevation: 10,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Theme.of(context).colorScheme.surface,
              ),
              child: widget.content,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlay!);
  }

  void _hide() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: () => _overlay == null ? _show() : _hide(),
        child: widget.trigger,
      ),
    );
  }
}
