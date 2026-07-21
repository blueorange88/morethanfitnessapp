import 'package:flutter/material.dart';

class HomeMemberConnectionHintBubble extends StatelessWidget {
  const HomeMemberConnectionHintBubble({
    super.key,
    required this.visible,
    required this.message,
    required this.isLinked,
  });

  final bool visible;
  final String message;
  final bool isLinked;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isLinked
        ? const Color(0xFFECFDF5)
        : const Color(0xFFF8FAFC);
    final borderColor =
        isLinked ? const Color(0xFFBBF7D0) : const Color(0xFFD1D5DB);
    final foregroundColor =
        isLinked ? const Color(0xFF059669) : const Color(0xFF4F46E5);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: visible
          ? Container(
              key: ValueKey(message),
              constraints: const BoxConstraints(maxWidth: 330),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: backgroundColor.withOpacity(0.98),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: borderColor),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLinked ? Icons.link_rounded : Icons.info_outline_rounded,
                    size: 16,
                    color: foregroundColor,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: foregroundColor,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
