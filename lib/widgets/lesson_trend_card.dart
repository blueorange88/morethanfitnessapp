import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/lesson_insights_stats.dart';
import '../utils/lesson_trend_series.dart';

const List<String> _kWeekdayNames = ['월', '화', '수', '목', '금', '토', '일'];

/// 인사이트의 레슨 추이 차트. 막대 하나가 하루·한 주·한 달이고, 두 손가락으로 모으면
/// 일별 → 주별 → 월별로, 벌리면 반대로 바뀐다. 한 손가락으로 옆으로 밀면 기간이 이동한다.
/// 손동작을 모르는 사람을 위해 `일별 / 주별 / 월별` 칩도 같이 둔다.
class LessonTrendCard extends StatefulWidget {
  const LessonTrendCard({
    super.key,
    required this.lessons,
    required this.memberCreatedAts,
    required this.dataStart,
    required this.hasYearData,
    required this.onNeedYearData,
    this.onMultiTouchChanged,
    this.now,
  });

  /// 불러온 레슨(삭제된 것 제외).
  final List<LessonInsightEntry> lessons;

  /// 회원 등록일(신규 회원 지표용).
  final List<DateTime> memberCreatedAts;

  /// 레슨을 불러온 가장 이른 날. 이보다 앞으로는 옮길 수 없다.
  final DateTime dataStart;

  /// 월별을 보기에 충분한 기간(최근 12개월)을 이미 불러왔는지.
  final bool hasYearData;

  /// 월별로 처음 내려갈 때 더 긴 기간을 불러온다.
  final Future<void> Function() onNeedYearData;

  /// 두 손가락이 닿아 있는 동안 true. 바깥 세로 스크롤을 잠그는 데 쓴다.
  final ValueChanged<bool>? onMultiTouchChanged;

  /// 테스트용 현재 시각.
  final DateTime? now;

  @override
  State<LessonTrendCard> createState() => _LessonTrendCardState();
}

class _LessonTrendCardState extends State<LessonTrendCard> {
  static const double _left = 30;
  static const double _right = 6;
  static const double _top = 18;
  static const double _bottom = 22;

  TrendGranularity _granularity = TrendGranularity.week;
  TrendMetric _metric = TrendMetric.completed;
  late DateTime _anchor = _today;
  int? _selected;
  bool _loadingYear = false;

  final Map<int, Offset> _pointers = {};
  double _pinchRef = 0;
  double _dragAccum = 0;

  DateTime get _today {
    final n = widget.now ?? DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  List<TrendBucket> get _buckets => buildTrendBuckets(
    dates: trendDates(
      metric: _metric,
      lessons: widget.lessons,
      memberCreatedAts: widget.memberCreatedAts,
    ),
    granularity: _granularity,
    anchor: _anchor,
  );

  Future<void> _setGranularity(TrendGranularity next) async {
    if (next == _granularity || _loadingYear) return;
    if (next == TrendGranularity.month && !widget.hasYearData) {
      setState(() => _loadingYear = true);
      try {
        await widget.onNeedYearData();
      } catch (_) {
        // 못 불러와도 있는 데이터로 보여 준다.
      }
      if (!mounted) return;
      setState(() => _loadingYear = false);
    }
    setState(() {
      _granularity = next;
      _selected = null;
      _anchor = clampTrendAnchor(
        anchor: _anchor,
        granularity: next,
        today: _today,
        earliest: widget.dataStart,
      );
    });
  }

  void _shift(int steps) {
    if (steps == 0) return;
    setState(() {
      _selected = null;
      _anchor = shiftTrendAnchor(
        anchor: _anchor,
        granularity: _granularity,
        steps: steps,
        today: _today,
        earliest: widget.dataStart,
      );
    });
  }

  void _onPointerDown(PointerDownEvent e) {
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 2) {
      _pinchRef = _pinchDistance();
      widget.onMultiTouchChanged?.call(true);
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length < 2 || _pinchRef <= 0) return;
    final ratio = _pinchDistance() / _pinchRef;
    // 모으면 거칠게(일→주→월), 벌리면 세밀하게(월→주→일). 한 번에 한 단계씩.
    if (ratio < 0.78) {
      _pinchRef = _pinchDistance();
      _setGranularity(_granularity.coarser);
    } else if (ratio > 1.28) {
      _pinchRef = _pinchDistance();
      _setGranularity(_granularity.finer);
    }
  }

  void _onPointerEnd(PointerEvent e) {
    final hadTwo = _pointers.length >= 2;
    _pointers.remove(e.pointer);
    if (hadTwo && _pointers.length < 2) {
      widget.onMultiTouchChanged?.call(false);
    }
  }

  double _pinchDistance() {
    final points = _pointers.values.take(2).toList();
    if (points.length < 2) return 0;
    return (points[0] - points[1]).distance;
  }

  String _bucketText(TrendBucket bucket) {
    final start = bucket.start;
    final last = bucket.endExclusive.subtract(const Duration(days: 1));
    switch (_granularity) {
      case TrendGranularity.day:
        return '${start.month}/${start.day}(${_kWeekdayNames[start.weekday - 1]})';
      case TrendGranularity.week:
        return '${start.month}/${start.day} ~ ${last.month}/${last.day}';
      case TrendGranularity.month:
        return '${start.year}년 ${start.month}월';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.mtfChartPalette;
    final buckets = _buckets;
    final selectedIndex = _selected ?? buckets.length - 1;
    final selected = buckets[selectedIndex];
    final total = buckets.fold<int>(0, (sum, b) => sum + b.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final g in TrendGranularity.values)
              ChoiceChip(
                key: Key('trend_granularity_${g.name}'),
                label: Text(g.label),
                selected: _granularity == g,
                onSelected: (_) => _setGranularity(g),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final m in TrendMetric.values)
              ChoiceChip(
                key: Key('trend_metric_${m.name}'),
                label: Text(m.label),
                selected: _metric == m,
                onSelected:
                    (_) => setState(() {
                      _metric = m;
                      _selected = null;
                    }),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          '${_bucketText(selected)} · ${selected.value}${_metric.unit}',
          key: const Key('trend_readout'),
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          '보이는 ${_granularity.visibleCount}${_granularity == TrendGranularity.day
              ? '일'
              : _granularity == TrendGranularity.week
              ? '주'
              : '개월'} 합계 $total${_metric.unit}',
          key: const Key('trend_total'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 200,
          child: Stack(
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final plotW = math.max(1.0, width - _left - _right);
                    final barW = plotW / buckets.length;
                    return Listener(
                      key: const Key('trend_chart'),
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerUp: _onPointerEnd,
                      onPointerCancel: _onPointerEnd,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragStart: (_) => _dragAccum = 0,
                        onHorizontalDragUpdate: (d) {
                          // 두 손가락이 닿아 있으면 줌 동작이므로 옮기지 않는다.
                          if (_pointers.length >= 2) return;
                          _dragAccum += d.delta.dx;
                          final steps = (_dragAccum / barW).truncate();
                          if (steps != 0) {
                            _dragAccum -= steps * barW;
                            // 오른쪽으로 끌면 더 지난 기간이 보인다.
                            _shift(-steps);
                          }
                        },
                        onTapUp: (d) {
                          final index =
                              ((d.localPosition.dx - _left) / barW).floor();
                          if (index >= 0 && index < buckets.length) {
                            setState(() => _selected = index);
                          }
                        },
                        child: CustomPaint(
                          key: const Key('trend_canvas'),
                          size: Size(width, 200),
                          painter: _TrendBarsPainter(
                            buckets: buckets,
                            granularity: _granularity,
                            selectedIndex: selectedIndex,
                            barColor: palette.primarySeries,
                            selectedColor: palette.tertiarySeries,
                            textColor: palette.axisText,
                            gridColor: theme.colorScheme.outlineVariant,
                            left: _left,
                            right: _right,
                            top: _top,
                            bottom: _bottom,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_loadingYear)
                Positioned.fill(
                  child: ColoredBox(
                    color: theme.colorScheme.surface.withValues(alpha: 0.6),
                    child: const Center(
                      child: CircularProgressIndicator(
                        key: Key('trend_loading'),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '두 손가락을 모으면 일별→주별→월별, 벌리면 반대로 바뀌어요. 옆으로 밀면 기간이 이동해요.',
          key: const Key('trend_hint'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TrendBarsPainter extends CustomPainter {
  _TrendBarsPainter({
    required this.buckets,
    required this.granularity,
    required this.selectedIndex,
    required this.barColor,
    required this.selectedColor,
    required this.textColor,
    required this.gridColor,
    required this.left,
    required this.right,
    required this.top,
    required this.bottom,
  });

  final List<TrendBucket> buckets;
  final TrendGranularity granularity;
  final int selectedIndex;
  final Color barColor;
  final Color selectedColor;
  final Color textColor;
  final Color gridColor;
  final double left;
  final double right;
  final double top;
  final double bottom;

  void _text(
    Canvas canvas,
    String text,
    Offset anchor, {
    bool right = false,
    double size = 10.5,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: textColor,
          fontSize: size,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx =
        right ? anchor.dx - painter.width : anchor.dx - painter.width / 2;
    painter.paint(canvas, Offset(dx, anchor.dy - painter.height / 2));
  }

  String _label(TrendBucket b) {
    switch (granularity) {
      case TrendGranularity.day:
        return '${b.start.day}';
      case TrendGranularity.week:
        return '${b.start.month}/${b.start.day}';
      case TrendGranularity.month:
        return '${b.start.month}월';
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(
      left,
      top,
      size.width - right,
      size.height - bottom,
    );
    if (plot.width <= 0 || plot.height <= 0 || buckets.isEmpty) return;

    var maxValue = buckets.fold<int>(0, (m, b) => math.max(m, b.value));
    maxValue = math.max(2, maxValue);
    if (maxValue.isOdd) maxValue += 1;

    final grid =
        Paint()
          ..color = gridColor.withValues(alpha: 0.7)
          ..strokeWidth = 0.8;
    for (var i = 0; i <= 2; i++) {
      final value = maxValue * i / 2;
      final y = plot.bottom - plot.height * i / 2;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      _text(canvas, '${value.round()}', Offset(plot.left - 5, y), right: true);
    }

    final slot = plot.width / buckets.length;
    final barWidth = math.min(slot * 0.62, 28.0);
    final labelEvery = math.max(1, (34 / slot).ceil());
    for (var i = 0; i < buckets.length; i++) {
      final b = buckets[i];
      final cx = plot.left + slot * (i + 0.5);
      final height = plot.height * b.value / maxValue;
      final isSelected = i == selectedIndex;
      if (b.value > 0) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            cx - barWidth / 2,
            plot.bottom - height,
            barWidth,
            height,
          ),
          const Radius.circular(5),
        );
        canvas.drawRRect(
          rect,
          Paint()..color = isSelected ? selectedColor : barColor,
        );
        if (slot >= 16) {
          _text(
            canvas,
            '${b.value}',
            Offset(cx, plot.bottom - height - 8),
            size: 10,
            bold: isSelected,
          );
        }
      } else if (isSelected) {
        canvas.drawCircle(
          Offset(cx, plot.bottom - 2),
          2.5,
          Paint()..color = selectedColor,
        );
      }
      if ((buckets.length - 1 - i) % labelEvery == 0) {
        _text(
          canvas,
          _label(b),
          Offset(cx, plot.bottom + 12),
          bold: isSelected,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendBarsPainter old) =>
      old.buckets != buckets ||
      old.selectedIndex != selectedIndex ||
      old.granularity != granularity ||
      old.barColor != barColor ||
      old.selectedColor != selectedColor;
}
