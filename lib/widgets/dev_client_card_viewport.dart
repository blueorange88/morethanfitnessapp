import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/app_environment.dart';

abstract final class DevClientCardViewportController {
  static const supportedWidths = <double>[320, 360, 390, 411];
  static final ValueNotifier<double?> selectedWidth =
      ValueNotifier<double?>(null);

  static bool get isAvailable => kDebugMode && AppEnvironmentConfig.isDev;

  static void select(double? width) {
    if (!isAvailable) return;
    if (width != null && !supportedWidths.contains(width)) return;
    selectedWidth.value = width;
  }

  @visibleForTesting
  static void resetForTesting() {
    selectedWidth.value = null;
  }
}

class DevClientCardViewport extends StatelessWidget {
  const DevClientCardViewport({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!DevClientCardViewportController.isAvailable) return child;

    return ValueListenableBuilder<double?>(
      valueListenable: DevClientCardViewportController.selectedWidth,
      builder: (context, selectedWidth, _) {
        final originalMediaQuery = MediaQuery.of(context);
        return ColoredBox(
          color: const Color(0xFFE5E7EB),
          child: Stack(
            fit: StackFit.expand,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  if (selectedWidth == null) return child;
                  final appliedWidth =
                      selectedWidth.clamp(0, constraints.maxWidth).toDouble();
                  final simulatedMediaQuery = originalMediaQuery.copyWith(
                    size: Size(appliedWidth, originalMediaQuery.size.height),
                  );
                  return Center(
                    child: SizedBox(
                      key: const Key('dev_client_card_simulated_viewport'),
                      width: appliedWidth,
                      height: constraints.maxHeight,
                      child: MediaQuery(
                        data: simulatedMediaQuery,
                        child: child,
                      ),
                    ),
                  );
                },
              ),
              Positioned(
                top: 8,
                left: 8,
                child: SafeArea(
                  child: Material(
                    color: const Color(0xE61F2937),
                    borderRadius: BorderRadius.circular(999),
                    child: PopupMenuButton<double?>(
                      key: const Key('dev_client_card_viewport_selector'),
                      tooltip: 'DEV 고객카드 폭',
                      initialValue: selectedWidth,
                      onSelected: DevClientCardViewportController.select,
                      itemBuilder: (_) => <PopupMenuEntry<double?>>[
                        const PopupMenuItem<double?>(
                          value: null,
                          child: Text('OFF / 전체 폭'),
                        ),
                        for (final width
                            in DevClientCardViewportController.supportedWidths)
                          PopupMenuItem<double?>(
                            value: width,
                            child: Text('${width.toInt()}dp'),
                          ),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        child: Text(
                          selectedWidth == null
                              ? 'DEV 폭: OFF'
                              : 'DEV 폭: ${selectedWidth.toInt()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
