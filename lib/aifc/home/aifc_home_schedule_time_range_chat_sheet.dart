import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/aifc_avatar.dart';

class AifcHomeScheduleTimeRangeResult {
  const AifcHomeScheduleTimeRangeResult({
    required this.startHour,
    required this.endHourExclusive,
  });

  final int startHour;
  final int endHourExclusive;
}

class AifcHomeScheduleTimeRangeChatSheet {
  const AifcHomeScheduleTimeRangeChatSheet._();

  static Future<AifcHomeScheduleTimeRangeResult?> show({
    required BuildContext context,
    required String nickname,
    required int startHour,
    required int endHourExclusive,
    required Color primaryColor,
  }) {
    final safeName = _nicknameLabel(nickname);

    return showModalBottomSheet<AifcHomeScheduleTimeRangeResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _TimeRangeSheetBody(
          nicknameLabel: safeName,
          startHour: startHour,
          endHourExclusive: endHourExclusive,
          primaryColor: primaryColor,
        );
      },
    );
  }

  static String _nicknameLabel(String value) {
    final text = value.trim();
    if (text.isEmpty) return '강사님';
    return text.endsWith('님') ? text : '$text님';
  }
}

class _TimeRangeSheetBody extends StatefulWidget {
  const _TimeRangeSheetBody({
    required this.nicknameLabel,
    required this.startHour,
    required this.endHourExclusive,
    required this.primaryColor,
  });

  final String nicknameLabel;
  final int startHour;
  final int endHourExclusive;
  final Color primaryColor;

  @override
  State<_TimeRangeSheetBody> createState() => _TimeRangeSheetBodyState();
}

class _TimeRangeSheetBodyState extends State<_TimeRangeSheetBody> {
  late int _startHour;
  late int _lastHour;

  late FixedExtentScrollController _startController;
  late FixedExtentScrollController _lastController;

  final List<int> _startHours = List<int>.generate(23, (i) => i); // 00~22
  final List<int> _lastHours = List<int>.generate(23, (i) => i + 1); // 01~23

  @override
  void initState() {
    super.initState();

    _startHour = widget.startHour.clamp(0, 22);
    _lastHour = (widget.endHourExclusive - 1).clamp(1, 23);

    if (_lastHour <= _startHour) {
      _lastHour = (_startHour + 1).clamp(1, 23);
    }

    _startController = FixedExtentScrollController(
      initialItem: _startHours.indexOf(_startHour).clamp(0, _startHours.length - 1),
    );

    _lastController = FixedExtentScrollController(
      initialItem: _lastHours.indexOf(_lastHour).clamp(0, _lastHours.length - 1),
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _lastController.dispose();
    super.dispose();
  }

  String _hourText(int hour) {
    return hour.toString().padLeft(2, '0');
  }

  String _rangePreviewText() {
    return '첫 레슨 시작은 ${_hourText(_startHour)}:00, '
        '마지막 레슨은 ${_hourText(_lastHour)}:00 기준으로 보여드릴게요.';
  }

  void _setStartHour(int value) {
    HapticFeedback.selectionClick();

    setState(() {
      _startHour = value;

      if (_lastHour <= _startHour) {
        _lastHour = (_startHour + 1).clamp(1, 23);

        final lastIndex = _lastHours.indexOf(_lastHour);
        if (lastIndex >= 0) {
          _lastController.animateToItem(
            lastIndex,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  void _setLastHour(int value) {
    HapticFeedback.selectionClick();

    setState(() {
      _lastHour = value;

      if (_lastHour <= _startHour) {
        _startHour = (_lastHour - 1).clamp(0, 22);

        final startIndex = _startHours.indexOf(_startHour);
        if (startIndex >= 0) {
          _startController.animateToItem(
            startIndex,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleHourCount = _lastHour - _startHour + 1;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F4FF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8D4FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                _FcBubble(
                  primaryColor: widget.primaryColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.nicknameLabel}, 시간 범위를 정해볼까요?',
                        style: const TextStyle(
                          color: Color(0xFF1E1B4B),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '스케줄표에 보여줄 첫 레슨 시작 시간과 마지막 레슨 시간을 함께 맞춰둘게요.',
                        style: TextStyle(
                          color: const Color(0xFF1E1B4B).withOpacity(0.66),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 13),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.primaryColor.withOpacity(0.07),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _MiniHourWheel(
                              title: '첫 레슨 시작',
                              controller: _startController,
                              hours: _startHours,
                              selectedHour: _startHour,
                              primaryColor: widget.primaryColor,
                              onChanged: _setStartHour,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 132,
                            margin: const EdgeInsets.symmetric(horizontal: 10),
                            color: const Color(0xFFE5E7EB),
                          ),
                          Expanded(
                            child: _MiniHourWheel(
                              title: '마지막 레슨',
                              controller: _lastController,
                              hours: _lastHours,
                              selectedHour: _lastHour,
                              primaryColor: widget.primaryColor,
                              onChanged: _setLastHour,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: widget.primaryColor.withOpacity(0.065),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: widget.primaryColor.withOpacity(0.13),
                          ),
                        ),
                        child: Text(
                          '${_rangePreviewText()}\n총 $visibleHourCount개 시간 줄이 표시돼요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: widget.primaryColor,
                            fontSize: 11.2,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6B7280),
                          side: const BorderSide(
                            color: Color(0xFFE5E7EB),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          '취소',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.primaryColor,
                              const Color(0xFF9333EA),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: widget.primaryColor.withOpacity(0.22),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () {
                            HapticFeedback.mediumImpact();

                            Navigator.of(context).pop(
                              AifcHomeScheduleTimeRangeResult(
                                startHour: _startHour,
                                endHourExclusive: _lastHour + 1,
                              ),
                            );
                          },
                          child: const Text(
                            '이렇게 설정할게요',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                const Text(
                  '이 설정은 홈 스케줄표와 위젯 미리보기 기준에 함께 반영돼요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniHourWheel extends StatelessWidget {
  const _MiniHourWheel({
    required this.title,
    required this.controller,
    required this.hours,
    required this.selectedHour,
    required this.primaryColor,
    required this.onChanged,
  });

  final String title;
  final FixedExtentScrollController controller;
  final List<int> hours;
  final int selectedHour;
  final Color primaryColor;
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
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 128,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 12,
                right: 12,
                top: 45,
                child: Container(
                  height: 1,
                  color: primaryColor.withOpacity(0.12),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 45,
                child: Container(
                  height: 1,
                  color: primaryColor.withOpacity(0.12),
                ),
              ),
              ListWheelScrollView.useDelegate(
                controller: controller,
                itemExtent: 36,
                diameterRatio: 1.45,
                perspective: 0.003,
                physics: const FixedExtentScrollPhysics(),
                onSelectedItemChanged: (index) {
                  onChanged(hours[index]);
                },
                childDelegate: ListWheelChildBuilderDelegate(
                  childCount: hours.length,
                  builder: (context, index) {
                    final hour = hours[index];
                    final distance = (hour - selectedHour).abs();

                    final opacity = _opacityForDistance(distance);
                    final fontSize = _fontSizeForDistance(distance);
                    final fontWeight = _fontWeightForDistance(distance);

                    final isSelected = distance == 0;

                    return Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 120),
                        opacity: opacity,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 120),
                          curve: Curves.easeOut,
                          style: TextStyle(
                            color: isSelected
                                ? primaryColor
                                : const Color(0xFF64748B),
                            fontSize: fontSize,
                            fontWeight: fontWeight,
                            letterSpacing: isSelected ? 0.7 : 0,
                          ),
                          child: Text(
                            hour.toString().padLeft(2, '0'),
                          ),
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

class _FcBubble extends StatelessWidget {
  const _FcBubble({
    required this.child,
    required this.primaryColor,
  });

  final Widget child;
  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AifcAvatar(
          size: 34,
          isAnimating: true,
          backgroundColor: Colors.white,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: const Color(0xFFE0DEFF),
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}