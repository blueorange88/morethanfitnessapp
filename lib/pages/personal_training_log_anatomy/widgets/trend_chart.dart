import 'package:flutter/material.dart';

import '../models/anatomy_trend.dart';

/// 날짜별 값의 꺾은선 그래프. 날짜 간격에 비례해 점을 놓는다. 점이 하나면 점만,
/// 없으면 안내 문구를 보여준다.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.points,
    required this.unit,
    this.height = 190,
  });

  final List<TrendPoint> points;
  final String unit;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            '이 지표로 그릴 기록이 아직 없어요.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        key: const ValueKey<String>('trend_chart'),
        painter: _TrendPainter(
          points: points,
          line: colors.primary,
          grid: colors.outline.withValues(alpha: 0.5),
          label: colors.onSurfaceVariant,
          surface: colors.surface,
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.line,
    required this.grid,
    required this.label,
    required this.surface,
  });

  final List<TrendPoint> points;
  final Color line;
  final Color grid;
  final Color label;
  final Color surface;

  static const double _left = 44;
  static const double _right = 14;
  static const double _top = 12;
  static const double _bottom = 26;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      _left,
      _top,
      size.width - _right,
      size.height - _bottom,
    );
    var minValue = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    var maxValue = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    if (maxValue - minValue < 1e-9) {
      final pad = maxValue == 0 ? 1.0 : maxValue * 0.1;
      minValue -= pad;
      maxValue += pad;
    } else {
      final pad = (maxValue - minValue) * 0.12;
      minValue -= pad;
      maxValue += pad;
    }

    final gridPaint =
        Paint()
          ..color = grid
          ..strokeWidth = 0.8;
    for (var i = 0; i <= 3; i++) {
      final y = plot.bottom - plot.height * i / 3;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), gridPaint);
      _text(
        canvas,
        formatAnatomyNumber(minValue + (maxValue - minValue) * i / 3),
        Offset(plot.left - 6, y),
        alignRight: true,
      );
    }

    final first = points.first.date;
    final last = points.last.date;
    final span = last.difference(first).inMinutes;
    Offset at(TrendPoint p) {
      final x =
          points.length == 1 || span == 0
              ? plot.center.dx
              : plot.left +
                  plot.width * p.date.difference(first).inMinutes / span;
      final y =
          plot.bottom -
          plot.height * (p.value - minValue) / (maxValue - minValue);
      return Offset(x, y);
    }

    if (points.length > 1) {
      final path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
      for (final p in points.skip(1)) {
        path.lineTo(at(p).dx, at(p).dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round
          ..color = line,
      );
    }
    for (var i = 0; i < points.length; i++) {
      final center = at(points[i]);
      final isLast = i == points.length - 1;
      canvas.drawCircle(center, isLast ? 6 : 4, Paint()..color = line);
      canvas.drawCircle(center, isLast ? 3 : 2, Paint()..color = surface);
    }

    _text(
      canvas,
      formatAnatomyShortDate(first),
      Offset(plot.left, size.height - 8),
    );
    if (points.length > 1) {
      _text(
        canvas,
        formatAnatomyShortDate(last),
        Offset(plot.right, size.height - 8),
        alignRight: true,
      );
    }
  }

  void _text(
    Canvas canvas,
    String text,
    Offset anchor, {
    bool alignRight = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: 10, color: label)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = alignRight ? anchor.dx - painter.width : anchor.dx;
    painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.line != line ||
      oldDelegate.grid != grid;
}
