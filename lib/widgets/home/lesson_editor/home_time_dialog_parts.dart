import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';

class HomeTimeDialogHeader extends StatelessWidget {
  const HomeTimeDialogHeader({
    super.key,
    required this.title,
    required this.timeRange,
    required this.onKbToggle,
    required this.useKeyboard,
    this.showKbButton = true,
  });

  final String title;
  final String timeRange;
  final VoidCallback onKbToggle;
  final bool useKeyboard;
  final bool showKbButton;

  @override
  Widget build(BuildContext context) {
    final tokens = context.mtfThemeTokens;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tokens.drawerHeaderBackground,
            AppColors.deepNavy,
          ],
          stops: const [0.0, 1.0],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 38,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x2BFFFFFF),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Divider(
              height: 1,
              color: Color(0x2EFFFFFF),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          timeRange,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white.withOpacity(0.82),
                            letterSpacing: -0.2,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (showKbButton) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onKbToggle,
                    child: Icon(
                      useKeyboard
                          ? Icons.schedule_outlined
                          : Icons.keyboard_alt_outlined,
                      size: 18,
                      color: Colors.white.withOpacity(0.72),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HomeDialWheel extends StatelessWidget {
  const HomeDialWheel({
    super.key,
    required this.label,
    required this.controller,
    required this.itemCount,
    required this.selectedIndex,
    required this.labelBuilder,
    required this.onChanged,
  });

  final String label;
  final FixedExtentScrollController controller;
  final int itemCount;
  final int selectedIndex;
  final String Function(int index) labelBuilder;
  final ValueChanged<int> onChanged;

  double _opacityForDistance(int distance) {
    switch (distance) {
      case 0:
        return 1.0;
      case 1:
        return 0.62;
      case 2:
        return 0.34;
      default:
        return 0.18;
    }
  }

  double _fontSizeForDistance(int distance) {
    switch (distance) {
      case 0:
        return 24.0;
      case 1:
        return 18.0;
      case 2:
        return 14.5;
      default:
        return 13.0;
    }
  }

  FontWeight _fontWeightForDistance(int distance) {
    return distance == 0 ? FontWeight.w900 : FontWeight.w700;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.mtfThemeTokens;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 70,
          height: 124,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 7,
                right: 7,
                top: 43,
                child: Container(
                  height: 1,
                  color: tokens.gradeSheetAccent.withOpacity(0.28),
                ),
              ),
              Positioned(
                left: 7,
                right: 7,
                bottom: 43,
                child: Container(
                  height: 1,
                  color: tokens.gradeSheetAccent.withOpacity(0.28),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: controller,
                physics: const FixedExtentScrollPhysics(),
                itemExtent: 36,
                diameterRatio: 1.45,
                perspective: 0.003,
                onSelectedItemChanged: onChanged,
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: itemCount,
                  builder: (context, index) {
                    final distance = (index - selectedIndex).abs();
                    final isSelected = distance == 0;

                    final opacity = _opacityForDistance(distance);
                    final fontSize = _fontSizeForDistance(distance);
                    final fontWeight = _fontWeightForDistance(distance);

                    return Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 120),
                        opacity: opacity,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOut,
                          style: TextStyle(
                            fontSize: fontSize,
                            fontWeight: fontWeight,
                            letterSpacing: isSelected ? 0.7 : 0,
                            color: isSelected
                                ? tokens.gradeSheetAccent
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          child: Text(labelBuilder(index)),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class HomeDialogFooter extends StatelessWidget {
  const HomeDialogFooter({
    super.key,
    required this.onCancel,
    required this.onConfirm,
    this.cancelLabel = '취소',
    this.confirmLabel = '적용',
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String cancelLabel;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.mtfThemeTokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                backgroundColor: tokens.cardSurface,
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                padding: const EdgeInsets.symmetric(vertical: 9),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Text(
                cancelLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: tokens.gradeSheetAccent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: ElevatedButton(
                onPressed: onConfirm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: theme.colorScheme.onSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  confirmLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeMaxNumberInputFormatter extends TextInputFormatter {
  final int max;
  final int maxLength;

  const HomeMaxNumberInputFormatter({
    required this.max,
    this.maxLength = 2,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;

    if (text.isEmpty) {
      return newValue;
    }

    if (!RegExp(r'^\d+$').hasMatch(text)) {
      return oldValue;
    }

    if (text.length > maxLength) {
      return oldValue;
    }

    final value = int.tryParse(text);
    if (value == null) {
      return oldValue;
    }

    if (value > max) {
      return oldValue;
    }

    return newValue;
  }
}
