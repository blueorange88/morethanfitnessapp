import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/inbody_history.dart';

const double _kDayMs = 24 * 60 * 60 * 1000;

/// 인바디 추이 차트가 보여 주는 기간(가로 축). 두 손가락 줌·한 손가락 이동·기간 칩이 모두
/// 이 값을 바꾼다. 값은 `millisecondsSinceEpoch`이다.
class InbodyChartViewport {
  const InbodyChartViewport({
    required this.startMs,
    required this.endMs,
    required this.minMs,
    required this.maxMs,
  });

  /// 측정 기록 전체를 보여 주는 기간(앞뒤로 조금 여유를 둔다). 기록이 한 건이면 앞뒤 15일.
  factory InbodyChartViewport.full(List<DateTime> dates) {
    if (dates.isEmpty) {
      final now = DateTime.now().millisecondsSinceEpoch.toDouble();
      return InbodyChartViewport(
        startMs: now - 15 * _kDayMs,
        endMs: now + 15 * _kDayMs,
        minMs: now - 15 * _kDayMs,
        maxMs: now + 15 * _kDayMs,
      );
    }
    final first = dates.first.millisecondsSinceEpoch.toDouble();
    final last = dates.last.millisecondsSinceEpoch.toDouble();
    final pad = last - first < _kDayMs ? 15 * _kDayMs : (last - first) * 0.04;
    return InbodyChartViewport(
      startMs: first - pad,
      endMs: last + pad,
      minMs: first - pad,
      maxMs: last + pad,
    );
  }

  final double startMs;
  final double endMs;

  /// 움직일 수 있는 바깥 범위(전체 기록 + 여유).
  final double minMs;
  final double maxMs;

  double get span => endMs - startMs;
  double get fullSpan => maxMs - minMs;

  /// 가장 가깝게 볼 수 있는 기간(7일, 전체가 더 짧으면 전체).
  double get minSpan => math.min(7 * _kDayMs, fullSpan);

  bool get isFull => span >= fullSpan - 1;

  DateTime get startDate =>
      DateTime.fromMillisecondsSinceEpoch(startMs.round());
  DateTime get endDate => DateTime.fromMillisecondsSinceEpoch(endMs.round());

  InbodyChartViewport _with(double start, double end) => InbodyChartViewport(
    startMs: start,
    endMs: end,
    minMs: minMs,
    maxMs: maxMs,
  );

  /// 두 손가락 줌·이동. 줌을 시작할 때 손가락 가운데 아래에 있던 시각([anchorFraction], 0~1)이
  /// 지금 손가락 가운데 위치([targetFraction], 0~1) 아래에 오도록 기간을 고른다.
  InbodyChartViewport scaledAround({
    required double scale,
    required double anchorFraction,
    required double targetFraction,
  }) {
    final safeScale = scale.isFinite && scale > 0 ? scale : 1.0;
    final newSpan = (span / safeScale).clamp(minSpan, fullSpan).toDouble();
    final anchorTime = startMs + anchorFraction * span;
    var newStart = anchorTime - targetFraction * newSpan;
    newStart =
        newStart.clamp(minMs, math.max(minMs, maxMs - newSpan)).toDouble();
    return _with(newStart, newStart + newSpan);
  }

  /// 마지막 측정 쪽을 기준으로 최근 [days]일을 보여 준다. 기록이 더 짧으면 전체.
  InbodyChartViewport lastDays(int days) {
    final newSpan = math.min(days * _kDayMs, fullSpan);
    return _with(maxMs - newSpan, maxMs);
  }

  InbodyChartViewport showAll() => _with(minMs, maxMs);
}

/// 인바디 추이 선 그래프: 측정일을 실제 날짜 간격으로 놓고, 두 손가락 줌과 한 손가락 이동,
/// 점 누르기를 지원한다. 세로 스크롤 안에 넣지 말고 고정 높이 영역에 둔다.
class InbodyTrendChart extends StatefulWidget {
  const InbodyTrendChart({
    super.key,
    required this.points,
    required this.viewport,
    required this.onViewportChanged,
    this.selectedIndex,
    this.onSelect,
  });

  /// 측정일 순 (날짜, 값).
  final List<({DateTime at, double value})> points;
  final InbodyChartViewport viewport;
  final ValueChanged<InbodyChartViewport> onViewportChanged;
  final int? selectedIndex;
  final ValueChanged<int?>? onSelect;

  @override
  State<InbodyTrendChart> createState() => _InbodyTrendChartState();
}

class _InbodyTrendChartState extends State<InbodyTrendChart> {
  static const double _left = 44;
  static const double _right = 14;
  static const double _top = 12;
  static const double _bottom = 26;

  InbodyChartViewport? _gestureBase;
  double _anchorFraction = 0.5;
  bool _moved = false;

  double _plotWidth(double width) => math.max(1, width - _left - _right);

  double _fractionOf(double dx, double width) =>
      ((dx - _left) / _plotWidth(width)).clamp(0.0, 1.0).toDouble();

  void _onScaleStart(ScaleStartDetails d, double width) {
    _gestureBase = widget.viewport;
    _anchorFraction = _fractionOf(d.localFocalPoint.dx, width);
    _moved = false;
  }

  void _onScaleUpdate(ScaleUpdateDetails d, double width) {
    final base = _gestureBase;
    if (base == null) return;
    _moved = true;
    widget.onViewportChanged(
      base.scaledAround(
        scale: d.horizontalScale,
        anchorFraction: _anchorFraction,
        targetFraction: _fractionOf(d.localFocalPoint.dx, width),
      ),
    );
  }

  void _onTapUp(TapUpDetails d, double width) {
    if (_moved) return;
    final onSelect = widget.onSelect;
    if (onSelect == null) return;
    final vp = widget.viewport;
    final plotW = _plotWidth(width);
    int? nearest;
    var best = 28.0;
    for (var i = 0; i < widget.points.length; i++) {
      final x =
          _left +
          (widget.points[i].at.millisecondsSinceEpoch - vp.startMs) /
              vp.span *
              plotW;
      final distance = (x - d.localPosition.dx).abs();
      if (distance < best) {
        best = distance;
        nearest = i;
      }
    }
    onSelect(nearest);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          key: const Key('inbody_chart_gestures'),
          behavior: HitTestBehavior.opaque,
          onScaleStart: (d) => _onScaleStart(d, width),
          onScaleUpdate: (d) => _onScaleUpdate(d, width),
          onTapUp: (d) => _onTapUp(d, width),
          child: CustomPaint(
            key: const Key('inbody_chart_canvas'),
            size: Size(width, constraints.maxHeight),
            painter: _InbodyChartPainter(
              points: widget.points,
              viewport: widget.viewport,
              selectedIndex: widget.selectedIndex,
              lineColor: scheme.primary,
              gridColor: scheme.outlineVariant,
              textColor: scheme.onSurfaceVariant,
              pointFill: scheme.surface,
              left: _left,
              right: _right,
              top: _top,
              bottom: _bottom,
            ),
          ),
        );
      },
    );
  }
}

String _plain(double value) {
  final text = value.toStringAsFixed(1);
  return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
}

class _InbodyChartPainter extends CustomPainter {
  _InbodyChartPainter({
    required this.points,
    required this.viewport,
    required this.selectedIndex,
    required this.lineColor,
    required this.gridColor,
    required this.textColor,
    required this.pointFill,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });

  final List<({DateTime at, double value})> points;
  final InbodyChartViewport viewport;
  final int? selectedIndex;
  final Color lineColor;
  final Color gridColor;
  final Color textColor;
  final Color pointFill;
  final double left;
  final double right;
  final double top;
  final double bottom;

  void _label(
    Canvas canvas,
    String text,
    Offset anchor, {
    TextAlign align = TextAlign.center,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: textColor, fontSize: 10.5),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();
    final dx = switch (align) {
      TextAlign.right => anchor.dx - painter.width,
      TextAlign.left => anchor.dx,
      _ => anchor.dx - painter.width / 2,
    };
    painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    if (plot.width <= 0 || plot.height <= 0 || points.isEmpty) return;

    // 보이는 기간의 값으로 세로 범위를 잡는다(없으면 전체).
    var visible = [
      for (final p in points)
        if (p.at.millisecondsSinceEpoch >= viewport.startMs &&
            p.at.millisecondsSinceEpoch <= viewport.endMs)
          p.value,
    ];
    if (visible.isEmpty) visible = [for (final p in points) p.value];
    var minV = visible.reduce(math.min);
    var maxV = visible.reduce(math.max);
    if ((maxV - minV).abs() < 0.0001) {
      minV -= 1;
      maxV += 1;
    }
    final pad = (maxV - minV) * 0.12;
    minV -= pad;
    maxV += pad;

    double xOf(DateTime at) =>
        plot.left +
        (at.millisecondsSinceEpoch - viewport.startMs) /
            viewport.span *
            plot.width;
    double yOf(double v) =>
        plot.bottom - (v - minV) / (maxV - minV) * plot.height;

    // 가로 눈금선 + 값
    final grid =
        Paint()
          ..color = gridColor.withValues(alpha: 0.7)
          ..strokeWidth = 0.8;
    for (var i = 0; i < 3; i++) {
      final v = minV + (maxV - minV) * i / 2;
      final y = yOf(v);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _label(
        canvas,
        _plain(v),
        Offset(plot.left - 6, y),
        align: TextAlign.right,
      );
    }

    // 날짜 눈금(4개)
    final longRange = viewport.span > 400 * _kDayMs;
    for (var i = 0; i < 4; i++) {
      final t = viewport.startMs + viewport.span * i / 3;
      final date = DateTime.fromMillisecondsSinceEpoch(t.round());
      final text =
          longRange
              ? '${(date.year % 100).toString().padLeft(2, '0')}.${date.month}'
              : '${date.month}/${date.day}';
      final x = plot.left + plot.width * i / 3;
      _label(
        canvas,
        text,
        Offset(x.clamp(plot.left + 8, plot.right - 8), plot.bottom + 14),
      );
    }

    canvas.save();
    canvas.clipRect(plot.inflate(6));
    final line =
        Paint()
          ..color = lineColor
          ..strokeWidth = 2.2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(xOf(points[i].at), yOf(points[i].value));
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(path, line);

    final fill = Paint()..color = lineColor;
    final hole = Paint()..color = pointFill;
    for (var i = 0; i < points.length; i++) {
      final o = Offset(xOf(points[i].at), yOf(points[i].value));
      if (o.dx < plot.left - 8 || o.dx > plot.right + 8) continue;
      final selected = i == selectedIndex;
      canvas.drawCircle(o, selected ? 6.5 : 4, fill);
      canvas.drawCircle(o, selected ? 3 : 1.8, hole);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _InbodyChartPainter old) =>
      old.points != points ||
      old.viewport.startMs != viewport.startMs ||
      old.viewport.endMs != viewport.endMs ||
      old.selectedIndex != selectedIndex ||
      old.lineColor != lineColor;
}

/// 측정 기록에서 [metric] 값이 있는 것만 (날짜, 값)으로 뽑는다.
List<({DateTime at, double value})> inbodySeriesOf(
  List<InbodyHistoryPoint> points,
  InbodyMetric metric,
) => [
  for (final p in points)
    if (p.valueOf(metric) != null)
      (at: p.measuredAt, value: p.valueOf(metric)!),
];
