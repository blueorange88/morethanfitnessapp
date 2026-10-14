import 'package:flutter/material.dart';

import '../services/inbody_history.dart';

/// 레슨일지 헤더(어두운 배경)에 보여주는 인바디 추이 카드.
///
/// 기록이 없으면 안내와 `인바디 입력하기` 버튼을, 있으면 최신 값·직전 대비 변화·추이 그래프와
/// `+ 측정 추가`를 보여준다. 샘플 숫자는 쓰지 않는다.
class InbodyTrendCard extends StatefulWidget {
  const InbodyTrendCard({
    super.key,
    required this.points,
    required this.onMeasure,
  });

  final List<InbodyHistoryPoint> points;
  final VoidCallback onMeasure;

  @override
  State<InbodyTrendCard> createState() => _InbodyTrendCardState();
}

class _InbodyTrendCardState extends State<InbodyTrendCard> {
  InbodyMetric _metric = InbodyMetric.weight;

  String _number(double value) {
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  Widget _title({required bool hasData}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            '인바디 추이',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (hasData)
          TextButton.icon(
            key: const Key('inbody_trend_add'),
            onPressed: widget.onMeasure,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('측정 추가', style: TextStyle(fontSize: 11.5)),
          ),
      ],
    );
  }

  Widget _empty() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(hasData: false),
        const SizedBox(height: 6),
        const Text(
          '아직 인바디 기록이 없어요',
          key: Key('inbody_trend_empty'),
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '카메라로 인바디 용지를 읽거나 직접 입력하면 변화가 여기에 쌓여요.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 11.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: FilledButton.icon(
            key: const Key('inbody_trend_cta'),
            onPressed: widget.onMeasure,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF111827),
            ),
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: const Text('인바디 입력하기'),
          ),
        ),
      ],
    );
  }

  Widget _metricTile(InbodyMetric metric) {
    final points = widget.points;
    final latest = [
      for (final point in points)
        if (point.valueOf(metric) != null) point.valueOf(metric)!,
    ];
    final selected = _metric == metric;
    final change = inbodyMetricChange(points, metric);
    final changeText =
        change == null
            ? ''
            : change == 0
            ? '변화 없음'
            : '${change > 0 ? '+' : ''}${_number(change)}${metric.unit}';

    return Expanded(
      child: InkWell(
        key: Key('inbody_metric_${metric.name}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _metric = metric),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: selected ? 0.20 : 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: selected ? 0.5 : 0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                metric.label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                latest.isEmpty ? '-' : '${_number(latest.last)}${metric.unit}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                changeText.isEmpty ? ' ' : changeText,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.points;
    final series = [
      for (final point in points)
        if (point.valueOf(_metric) != null) point.valueOf(_metric)!,
    ];

    return Container(
      key: const Key('inbody_trend_card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
      child:
          points.isEmpty
              ? _empty()
              : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _title(hasData: true),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _metricTile(InbodyMetric.weight),
                      const SizedBox(width: 6),
                      _metricTile(InbodyMetric.skeletalMuscle),
                      const SizedBox(width: 6),
                      _metricTile(InbodyMetric.bodyFatPercent),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 52,
                    child:
                        series.length >= 2
                            ? CustomPaint(
                              key: const Key('inbody_trend_chart'),
                              painter: _TrendPainter(series),
                              child: const SizedBox.expand(),
                            )
                            : Center(
                              child: Text(
                                '${_metric.label} 기록이 2건 이상이면 추이를 볼 수 있어요',
                                key: const Key('inbody_trend_need_more'),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '마지막 측정 ${inbodyDateText(points.last.measuredAt)} · 총 ${points.length}건',
                    key: const Key('inbody_trend_footer'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final span =
        (maxValue - minValue).abs() < 0.0001 ? 1.0 : maxValue - minValue;
    const pad = 6.0;
    final width = size.width - pad * 2;
    final height = size.height - pad * 2;

    Offset pointAt(int index) => Offset(
      pad + width * index / (values.length - 1),
      pad + height * (1 - (values[index] - minValue) / span),
    );

    final line =
        Paint()
          ..color = Colors.white
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(pointAt(i).dx, pointAt(i).dy);
    }
    canvas.drawPath(path, line);

    final dot = Paint()..color = Colors.white;
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(pointAt(i), i == values.length - 1 ? 4 : 2.5, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.values != values;
}
