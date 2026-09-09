import 'dart:math' as math;

import '../core/aifc_avatar.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _MinuteInputMode {
  quick,
  dial,
}

class AifcHomeScheduleMinuteChatSheet {
  const AifcHomeScheduleMinuteChatSheet._();

  static const String _modePrefsKey =
      'home_schedule_minute_input_mode_v1';

  static Future<int?> show({
    required BuildContext context,
    required String nickname,
    required String title,
    required String message,
    required int currentMinute,
    required Color primaryColor,
    String confirmLabel = '적용할게요',
    String footerText = '충돌이 있는 시간 줄은 기존 값으로 유지돼요.',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_modePrefsKey);

    final initialMode = switch (savedMode) {
      'dial' => _MinuteInputMode.dial,
      'quick' => _MinuteInputMode.quick,
      _ => null,
    };

    final safeName = _nicknameLabel(nickname);
    final validMinutes = [0, 10, 20, 30, 40, 50];
    final safeCurrentMinute =
    validMinutes.contains(currentMinute) ? currentMinute : 0;

    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _MinuteChatSheetBody(
          nicknameLabel: safeName,
          title: title,
          message: message,
          initialMinute: safeCurrentMinute,
          initialMode: initialMode,
          validMinutes: validMinutes,
          primaryColor: primaryColor,
          confirmLabel: confirmLabel,
          footerText: footerText,
          onSaveMode: (mode) async {
            await prefs.setString(
              _modePrefsKey,
              mode == _MinuteInputMode.dial ? 'dial' : 'quick',
            );
          },
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

class _MinuteChatSheetBody extends StatefulWidget {
  const _MinuteChatSheetBody({
    required this.nicknameLabel,
    required this.title,
    required this.message,
    required this.initialMinute,
    required this.initialMode,
    required this.validMinutes,
    required this.primaryColor,
    required this.confirmLabel,
    required this.footerText,
    required this.onSaveMode,
  });

  final String nicknameLabel;
  final String title;
  final String message;
  final int initialMinute;
  final _MinuteInputMode? initialMode;
  final List<int> validMinutes;
  final Color primaryColor;
  final String confirmLabel;
  final String footerText;
  final Future<void> Function(_MinuteInputMode mode) onSaveMode;

  @override
  State<_MinuteChatSheetBody> createState() => _MinuteChatSheetBodyState();
}

class _MinuteChatSheetBodyState extends State<_MinuteChatSheetBody> {
  late int _selectedMinute;
  late _MinuteInputMode? _mode;

  @override
  void initState() {
    super.initState();
    _selectedMinute = widget.initialMinute;
    _mode = widget.initialMode;
  }

  void _setMode(_MinuteInputMode mode) {
    HapticFeedback.selectionClick();

    setState(() {
      _mode = mode;
    });

    widget.onSaveMode(mode);
  }

  void _toggleMode() {
    final current = _mode ?? _MinuteInputMode.quick;
    final next = current == _MinuteInputMode.quick
        ? _MinuteInputMode.dial
        : _MinuteInputMode.quick;

    _setMode(next);
  }

  @override
  Widget build(BuildContext context) {
    final mode = _mode;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F4FF),
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(26),
            ),
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
                  trailing: mode == null
                      ? null
                      : _InputModeIconButton(
                    mode: mode,
                    primaryColor: widget.primaryColor,
                    onTap: _toggleMode,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.nicknameLabel}, ${widget.title}',
                        style: const TextStyle(
                          color: Color(0xFF1E1B4B),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.message,
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

                if (mode == null)
                  _ModePickerCard(
                    primaryColor: widget.primaryColor,
                    onQuickTap: () => _setMode(_MinuteInputMode.quick),
                    onDialTap: () => _setMode(_MinuteInputMode.dial),
                  )
                else if (mode == _MinuteInputMode.quick)
                  _QuickMinutePicker(
                    minutes: widget.validMinutes,
                    selectedMinute: _selectedMinute,
                    primaryColor: widget.primaryColor,
                    onSelected: (minute) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedMinute = minute;
                      });
                    },
                  )
                else
                  _CompassMinuteDial(
                    minutes: widget.validMinutes,
                    selectedMinute: _selectedMinute,
                    primaryColor: widget.primaryColor,
                    onChanged: (minute) {
                      setState(() {
                        _selectedMinute = minute;
                      });
                    },
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
                          onPressed: mode == null
                              ? null
                              : () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).pop(_selectedMinute);
                          },
                          child: Text(
                            widget.confirmLabel,
                            style: const TextStyle(
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

                Text(
                  widget.footerText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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

class _FcBubble extends StatelessWidget {
  const _FcBubble({
    required this.child,
    required this.primaryColor,
    this.trailing,
  });

  final Widget child;
  final Color primaryColor;
  final Widget? trailing;

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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: child),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InputModeIconButton extends StatelessWidget {
  const _InputModeIconButton({
    required this.mode,
    required this.primaryColor,
    required this.onTap,
  });

  final _MinuteInputMode mode;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool showDialIcon = mode == _MinuteInputMode.quick;

    return Tooltip(
      message: showDialIcon ? '다이얼로 바꾸기' : '빠른 선택으로 바꾸기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primaryColor.withOpacity(0.14),
            ),
          ),
          child: Icon(
            showDialIcon
                ? Icons.unfold_more_rounded
                : Icons.touch_app_rounded,
            size: 19,
            color: primaryColor,
          ),
        ),
      ),
    );
  }
}

class _ModePickerCard extends StatelessWidget {
  const _ModePickerCard({
    required this.primaryColor,
    required this.onQuickTap,
    required this.onDialTap,
  });

  final Color primaryColor;
  final VoidCallback onQuickTap;
  final VoidCallback onDialTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          const Text(
            '선택 방법을 골라주세요.',
            style: TextStyle(
              color: Color(0xFF111827),
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ModeButton(
                  icon: Icons.touch_app_rounded,
                  title: '빠른 선택',
                  subtitle: '00, 30분처럼 바로 선택',
                  primaryColor: primaryColor,
                  onTap: onQuickTap,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _ModeButton(
                  icon: Icons.view_carousel,
                  title: '다이얼',
                  subtitle: '좌우로 밀어서 맞추기',
                  primaryColor: primaryColor,
                  onTap: onDialTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.primaryColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.055),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: primaryColor.withOpacity(0.13),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: primaryColor,
              size: 24,
            ),
            const SizedBox(height: 7),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF111827),
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 10.3,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickMinutePicker extends StatelessWidget {
  const _QuickMinutePicker({
    required this.minutes,
    required this.selectedMinute,
    required this.primaryColor,
    required this.onSelected,
  });

  final List<int> minutes;
  final int selectedMinute;
  final Color primaryColor;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 13, 12, 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: minutes.map((minute) {
          final selected = selectedMinute == minute;

          return GestureDetector(
            onTap: () => onSelected(minute),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: selected ? primaryColor : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: selected ? primaryColor : const Color(0xFFE5E7EB),
                  width: selected ? 1.2 : 0.9,
                ),
                boxShadow: selected
                    ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.22),
                    blurRadius: 9,
                    offset: const Offset(0, 3),
                  ),
                ]
                    : null,
              ),
              child: Text(
                '${minute.toString().padLeft(2, '0')}분',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: selected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CompassMinuteDial extends StatefulWidget {
  const _CompassMinuteDial({
    required this.minutes,
    required this.selectedMinute,
    required this.primaryColor,
    required this.onChanged,
  });

  final List<int> minutes;
  final int selectedMinute;
  final Color primaryColor;
  final ValueChanged<int> onChanged;

  @override
  State<_CompassMinuteDial> createState() => _CompassMinuteDialState();
}

class _CompassMinuteDialState extends State<_CompassMinuteDial>
    with SingleTickerProviderStateMixin {
  late double _position;
  late AnimationController _snapController;
  Animation<double>? _snapAnimation;

  double _dragStartX = 0;
  double _dragStartPosition = 0;

  static const double _dragStepPerPixel = 0.018;

  int get _count => widget.minutes.length;

  int _mod(int value) {
    return ((value % _count) + _count) % _count;
  }

  int get _selectedIndex {
    return _mod(_position.round());
  }

  int _minuteAtIndex(int index) {
    return widget.minutes[_mod(index)];
  }

  @override
  void initState() {
    super.initState();

    final index = widget.minutes.indexOf(widget.selectedMinute);
    _position = (index < 0 ? 0 : index).toDouble();

    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _snapController.addListener(() {
      final animation = _snapAnimation;
      if (animation == null) return;

      setState(() {
        _position = animation.value;
      });
    });

    _snapController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onChanged(_minuteAtIndex(_selectedIndex));
      }
    });
  }

  @override
  void didUpdateWidget(covariant _CompassMinuteDial oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.selectedMinute != widget.selectedMinute &&
        !_snapController.isAnimating) {
      final index = widget.minutes.indexOf(widget.selectedMinute);
      if (index >= 0) {
        _position = index.toDouble();
      }
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _snapToNearest() {
    final target = _position.roundToDouble();

    _snapAnimation = Tween<double>(
      begin: _position,
      end: target,
    ).animate(
      CurvedAnimation(
        parent: _snapController,
        curve: Curves.easeOutCubic,
      ),
    );

    _snapController.forward(from: 0);
  }

  void _moveByStep(int step) {
    HapticFeedback.selectionClick();

    _snapAnimation = Tween<double>(
      begin: _position,
      end: (_position.round() + step).toDouble(),
    ).animate(
      CurvedAnimation(
        parent: _snapController,
        curve: Curves.easeOutCubic,
      ),
    );

    _snapController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _selectedIndex;

    return GestureDetector(
      onHorizontalDragStart: (details) {
        _snapController.stop();
        _dragStartX = details.localPosition.dx;
        _dragStartPosition = _position;
      },
      onHorizontalDragUpdate: (details) {
        final delta = details.localPosition.dx - _dragStartX;

        setState(() {
          // 왼쪽으로 밀면 다음 값, 오른쪽으로 밀면 이전 값
          _position = _dragStartPosition - (delta * _dragStepPerPixel);
        });
      },
      onHorizontalDragEnd: (_) {
        HapticFeedback.selectionClick();
        _snapToNearest();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: widget.primaryColor.withOpacity(0.045),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            SizedBox(
              height: 116,
              width: double.infinity,
              child: CustomPaint(
                painter: _CompassMinutePainter(
                  position: _position,
                  minutes: widget.minutes,
                  primaryColor: widget.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DialStepButton(
                  icon: Icons.chevron_left_rounded,
                  primaryColor: widget.primaryColor,
                  onTap: () => _moveByStep(-1),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_minuteAtIndex(currentIndex).toString().padLeft(2, '0')}분',
                  style: TextStyle(
                    color: widget.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 10),
                _DialStepButton(
                  icon: Icons.chevron_right_rounded,
                  primaryColor: widget.primaryColor,
                  onTap: () => _moveByStep(1),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '좌우로 밀어서 분을 맞춰주세요',
              style: TextStyle(
                color: const Color(0xFF6B7280).withOpacity(0.82),
                fontSize: 10.8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialStepButton extends StatelessWidget {
  const _DialStepButton({
    required this.icon,
    required this.primaryColor,
    required this.onTap,
  });

  final IconData icon;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: primaryColor.withOpacity(0.075),
          shape: BoxShape.circle,
          border: Border.all(
            color: primaryColor.withOpacity(0.12),
          ),
        ),
        child: Icon(
          icon,
          size: 20,
          color: primaryColor,
        ),
      ),
    );
  }
}

class _CompassMinutePainter extends CustomPainter {
  const _CompassMinutePainter({
    required this.position,
    required this.minutes,
    required this.primaryColor,
  });

  final double position;
  final List<int> minutes;
  final Color primaryColor;

  static const double _minuteAngle = math.pi / 5.1;
  static const double _visibleUnits = 2.65;

  int get _count => minutes.length;

  int _mod(int value) {
    return ((value % _count) + _count) % _count;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height + 18;
    final radius = size.height + 6;

    final selectedIndex = position.round();
    final fractional = position - selectedIndex;

    _drawArcBase(canvas, centerX, centerY, radius);
    _drawTicks(canvas, centerX, centerY, radius, fractional);
    _drawNumbers(canvas, centerX, centerY, radius, selectedIndex, fractional);
    _drawCenterPointer(canvas, size, centerX);
  }

  void _drawArcBase(Canvas canvas, double cx, double cy, double radius) {
    final rect = Rect.fromCircle(
      center: Offset(cx, cy),
      radius: radius,
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFE5E7EB).withOpacity(0.82);

    canvas.drawArc(
      rect,
      -math.pi / 2 - (_minuteAngle * _visibleUnits),
      _minuteAngle * _visibleUnits * 2,
      false,
      paint,
    );
  }

  void _drawTicks(
      Canvas canvas,
      double cx,
      double cy,
      double radius,
      double fractional,
      ) {
    const ticksPerMinute = 8;
    final totalTicks = (_visibleUnits * ticksPerMinute).ceil();

    for (int i = -totalTicks; i <= totalTicks; i++) {
      final unit = (i / ticksPerMinute) - fractional;
      final distance = unit.abs();

      if (distance > _visibleUnits) continue;

      final fade = (1 - (distance / _visibleUnits)).clamp(0.0, 1.0);
      if (fade <= 0.03) continue;

      final angle = unit * _minuteAngle;

      final isMajor = i % ticksPerMinute == 0;
      final isMid = i % (ticksPerMinute ~/ 2) == 0;

      final tickLength = isMajor ? 15.0 : (isMid ? 9.0 : 5.0);
      final outerRadius = radius;
      final innerRadius = radius - tickLength;

      final x1 = cx + outerRadius * math.sin(angle);
      final y1 = cy - outerRadius * math.cos(angle);
      final x2 = cx + innerRadius * math.sin(angle);
      final y2 = cy - innerRadius * math.cos(angle);

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      if (isMajor) {
        paint
          ..color = primaryColor.withOpacity(0.18 + (fade * 0.56))
          ..strokeWidth = 1.4 + (fade * 0.9);
      } else if (isMid) {
        paint
          ..color = const Color(0xFF94A3B8).withOpacity(fade * 0.48)
          ..strokeWidth = 1.0;
      } else {
        paint
          ..color = const Color(0xFFE2E8F0).withOpacity(fade * 0.68)
          ..strokeWidth = 0.75;
      }

      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        paint,
      );
    }
  }

  void _drawNumbers(
      Canvas canvas,
      double cx,
      double cy,
      double radius,
      int selectedIndex,
      double fractional,
      ) {
    for (int d = -2; d <= 2; d++) {
      final unit = d - fractional;
      final distance = unit.abs();

      if (distance > _visibleUnits) continue;

      final fade = (1 - (distance / _visibleUnits)).clamp(0.0, 1.0);
      if (fade <= 0.04) continue;

      final angle = unit * _minuteAngle;
      final labelRadius = radius - 35;

      final x = cx + labelRadius * math.sin(angle);
      final y = cy - labelRadius * math.cos(angle);

      final minute = minutes[_mod(selectedIndex + d)];
      final selected = d == 0 && fractional.abs() < 0.42;

      final text = minute.toString().padLeft(2, '0');

      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: selected
                ? primaryColor
                : primaryColor.withOpacity(0.25 + (fade * 0.52)),
            fontSize: selected ? 24 : 12 + (fade * 4),
            fontWeight: selected ? FontWeight.w900 : FontWeight.w800,
            letterSpacing: selected ? 0.6 : 0,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle * 0.24);

      textPainter.paint(
        canvas,
        Offset(
          -textPainter.width / 2,
          -textPainter.height / 2,
        ),
      );

      canvas.restore();
    }
  }

  void _drawCenterPointer(Canvas canvas, Size size, double centerX) {
    final linePaint = Paint()
      ..color = primaryColor.withOpacity(0.22)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(centerX, size.height - 28),
      Offset(centerX, size.height - 10),
      linePaint,
    );

    canvas.drawCircle(
      Offset(centerX, size.height - 5),
      3.7,
      Paint()..color = primaryColor,
    );
  }

  @override
  bool shouldRepaint(covariant _CompassMinutePainter oldDelegate) {
    return oldDelegate.position != position ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.minutes != minutes;
  }
}