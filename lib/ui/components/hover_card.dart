import 'package:flutter/material.dart';

class ShadcnHoverCard extends StatefulWidget {
  final Widget child;
  final Widget content;

  const ShadcnHoverCard({
    super.key,
    required this.child,
    required this.content,
  });

  @override
  State<ShadcnHoverCard> createState() => _ShadcnHoverCardState();
}

class _ShadcnHoverCardState extends State<ShadcnHoverCard> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlay;

  void _showOverlay() {
    final overlay = OverlayEntry(
      builder: (context) => Positioned(
        width: 240,
        child: CompositedTransformFollower(
          link: _link,
          offset: const Offset(0, 8),
          showWhenUnlinked: false,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 16,
                    color: Colors.black26,
                    offset: Offset(0, 8),
                  )
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: widget.content,
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);
    _overlay = overlay;
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _showOverlay(),
      onExit: (_) => _hideOverlay(),
      child: CompositedTransformTarget(
        link: _link,
        child: widget.child,
      ),
    );
  }
}
