import 'dart:async';

import 'package:flutter/material.dart';

import '../aifc/core/aifc_avatar.dart';

class AifcToast {
  static OverlayEntry? _entry;
  static Timer? _timer;

  static void show({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(milliseconds: 1400),
    double bottomOffset = 76,
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    hide();

    _entry = OverlayEntry(
      builder: (context) {
        final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
        final effectiveBottom =
            keyboardInset > 0 ? keyboardInset + 16 : bottomOffset;
        return Positioned.fill(
          child: IgnorePointer(
            child: SafeArea(
              child: Stack(
                children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    left: 24,
                    right: 24,
                    bottom: effectiveBottom,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 340),
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF0F1020,
                              ).withValues(alpha: 0.96),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.18),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const AifcAvatar(
                                  size: 26,
                                  isAnimating: false,
                                  backgroundColor: Color(0xFF0F1020),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    message,
                                    textAlign: TextAlign.left,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      height: 1.35,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_entry!);

    _timer = Timer(duration, hide);
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;

    _entry?.remove();
    _entry = null;
  }
}
