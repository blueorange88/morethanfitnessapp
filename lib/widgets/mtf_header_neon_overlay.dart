import 'dart:math' as math;
import 'package:flutter/material.dart';

class MtfHeaderNeonOverlay extends StatefulWidget {
  const MtfHeaderNeonOverlay({
    super.key,
    required this.child,
    required this.isExpanded,
    this.entryKey,
    this.autoPlay = true,
    this.bottomRadius = 32,
    this.drawDuration = const Duration(milliseconds: 950),
    this.fadeDuration = const Duration(milliseconds: 180),
    this.lineColor = const Color(0xFFEDE9FE),
    this.glowColor = const Color(0xFF7C3AED),
    this.strokeWidth = 2.2,
    this.intensity = 1,
    this.enabled = true,
  });

  final Widget child;

  /// 이 값이 바뀌면 닫힌 상태에서 네온라인을 다시 실행합니다.
  /// 홈에 다시 진입할 때마다 숫자를 올려서 넘기면 됩니다.
  final Object? entryKey;

  final bool isExpanded;

  /// 앱 첫 진입 시 닫힌 헤더에 네온라인을 한 번 그림
  final bool autoPlay;

  final double bottomRadius;
  final Duration drawDuration;
  final Duration fadeDuration;
  final Color lineColor;
  final Color glowColor;
  final double strokeWidth;
  final double intensity;
  final bool enabled;

  @override
  State<MtfHeaderNeonOverlay> createState() => _MtfHeaderNeonOverlayState();
}

class _MtfHeaderNeonOverlayState extends State<MtfHeaderNeonOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _drawCtrl;
  late final AnimationController _fadeCtrl;

  late final Animation<double> _drawAnim;
  late final Animation<double> _fadeAnim;

  bool _reverseDirection = false;

  @override
  void initState() {
    super.initState();

    _drawCtrl = AnimationController(
      vsync: this,
      duration: widget.drawDuration,
    );

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: widget.fadeDuration,
    );

    _drawAnim = CurvedAnimation(
      parent: _drawCtrl,
      curve: Curves.easeOutCubic,
    );

    _fadeAnim = CurvedAnimation(
      parent: _fadeCtrl,
      curve: Curves.easeOutCubic,
    );

    if (widget.isExpanded) {
      // 처음부터 펼쳐진 상태라면 네온은 숨김
      _drawCtrl.value = 1.0;
      _fadeCtrl.value = 0.0;
    } else {
      // 닫힌 기본 상태에서는 네온이 보여야 함
      _fadeCtrl.value = 1.0;

      if (widget.autoPlay) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _reverseDirection = false;
          _drawCtrl.forward(from: 0);
        });
      } else {
        _drawCtrl.value = 1.0;
      }
    }
  }

  @override
  void didUpdateWidget(covariant MtfHeaderNeonOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 홈에 다시 진입했을 때처럼 entryKey가 바뀌면,
    // 헤더가 닫힌 상태에서 네온라인을 다시 그립니다.
    if (oldWidget.entryKey != widget.entryKey && !widget.isExpanded) {
      setState(() {
        _reverseDirection = false;
      });

      _fadeCtrl.forward(from: 1.0);
      _drawCtrl.forward(from: 0);
      return;
    }

    if (oldWidget.isExpanded == widget.isExpanded) return;

    if (widget.isExpanded) {
      // 헤더 열기: 네온라인 사라짐
      _fadeCtrl.reverse(from: _fadeCtrl.value);
    } else {
      // 헤더 닫기: 반대 방향에서 네온라인 다시 그려짐
      setState(() {
        _reverseDirection = true;
      });

      _fadeCtrl.forward(from: 1.0);
      _drawCtrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _drawCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animationsDisabled =
        MediaQuery.maybeOf(context)?.disableAnimations == true;
    if (!widget.enabled || animationsDisabled || !TickerMode.of(context)) {
      return widget.child;
    }
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: Listenable.merge([_drawAnim, _fadeAnim]),
              builder: (context, _) {
                if (_fadeAnim.value <= 0) {
                  return const SizedBox.shrink();
                }

                return Opacity(
                  opacity: _fadeAnim.value,
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: _MtfHeaderNeonPainter(
                        progress: _drawAnim.value,
                        reverseDirection: _reverseDirection,
                        bottomRadius: widget.bottomRadius,
                        lineColor: widget.lineColor,
                        glowColor: widget.glowColor,
                        strokeWidth: widget.strokeWidth,
                        intensity: widget.intensity,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _MtfHeaderNeonPainter extends CustomPainter {
  const _MtfHeaderNeonPainter({
    required this.progress,
    required this.reverseDirection,
    required this.bottomRadius,
    required this.lineColor,
    required this.glowColor,
    required this.strokeWidth,
    required this.intensity,
  });

  final double progress;
  final bool reverseDirection;
  final double bottomRadius;
  final Color lineColor;
  final Color glowColor;
  final double strokeWidth;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final double w = size.width;
    final double h = size.height;

    final double p = progress.clamp(0.0, 1.0).toDouble();

    // 선 길이와 투명도 분리
    final double alpha = p < 0.10 ? p / 0.10 : 1.0;

    final double stroke = strokeWidth;
    final strength = intensity.clamp(0.0, 1.0);

    // stroke 절반만 안쪽으로 넣어 실제 헤더 라운드와 맞춤
    final double inset = stroke / 2;

    // 헤더의 bottom radius와 맞춤
    final double radius = math.max(0, bottomRadius - inset);

    // 양끝을 너무 위로 올리지 않고, 하단 라운드에 더 붙게 보정
    final fullPath = Path()
      ..moveTo(inset - 4, h - radius - 4) // 왼쪽 끝 — 위 바깥 대각
      ..lineTo(inset, h - radius)
      ..quadraticBezierTo(inset, h - inset, radius, h - inset)
      ..lineTo(w - radius, h - inset)
      ..quadraticBezierTo(w - inset, h - inset, w - inset, h - radius)
      ..lineTo(w - inset + 4, h - radius - 4); // 오른쪽 끝 — 위 바깥 대각

    final metrics = fullPath.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final totalLength = metrics.fold<double>(
      0.0,
      (sum, metric) => sum + metric.length,
    );

    final drawLength = totalLength * p;
    final extractedPath = Path();

    for (final metric in metrics) {
      if (!reverseDirection) {
        // 앱 진입: 왼쪽 → 오른쪽
        final segmentLength = math.min(drawLength, metric.length);
        extractedPath.addPath(
          metric.extractPath(0, segmentLength),
          Offset.zero,
        );
      } else {
        // 헤더 닫기: 오른쪽 → 왼쪽
        final start = (metric.length - drawLength).clamp(0.0, metric.length);
        extractedPath.addPath(
          metric.extractPath(start, metric.length),
          Offset.zero,
        );
      }
    }

    // 외곽 글로우 — 너무 뭉치지 않게 살짝 줄임
    canvas.drawPath(
      extractedPath,
      Paint()
        ..color = glowColor.withValues(alpha: 0.28 * alpha * strength)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8 * strength
        ..strokeCap = StrokeCap.square
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // 중간 글로우 — 커브 끝 뭉침 방지
    canvas.drawPath(
      extractedPath,
      Paint()
        ..color = lineColor.withValues(alpha: 0.46 * alpha * strength)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * strength
        ..strokeCap = StrokeCap.square
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // 메인 네온선
    canvas.drawPath(
      extractedPath,
      Paint()
        ..color = lineColor.withValues(alpha: alpha * strength)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.square, // butt → square
    );
  }

  @override
  bool shouldRepaint(covariant _MtfHeaderNeonPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.reverseDirection != reverseDirection ||
        oldDelegate.bottomRadius != bottomRadius ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.intensity != intensity;
  }
}
