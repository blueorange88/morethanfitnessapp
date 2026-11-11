import 'package:flutter/material.dart';

import '../services/inbody_history.dart';
import '../widgets/inbody_trend_chart.dart';

/// 인바디 추이를 크게 보는 화면. 지표(체중·골격근량·체지방률)와 기간 칩을 고르고, 차트를
/// 두 손가락으로 벌리거나 모아 기간을 바꾸고 한 손가락으로 밀어 옮긴다.
class InbodyTrendPage extends StatefulWidget {
  const InbodyTrendPage({
    super.key,
    required this.points,
    this.initialMetric = InbodyMetric.weight,
  });

  final List<InbodyHistoryPoint> points;
  final InbodyMetric initialMetric;

  @override
  State<InbodyTrendPage> createState() => _InbodyTrendPageState();
}

class _InbodyTrendPageState extends State<InbodyTrendPage> {
  late InbodyMetric _metric = widget.initialMetric;
  late InbodyChartViewport _viewport = InbodyChartViewport.full([
    for (final p in widget.points) p.measuredAt,
  ]);
  int? _selected;

  static const _ranges = <(String, int?)>[
    ('1개월', 30),
    ('3개월', 91),
    ('1년', 365),
    ('전체', null),
  ];

  List<({DateTime at, double value})> get _series =>
      inbodySeriesOf(widget.points, _metric);

  /// 지금 보이는 기간이 어느 칩과 같은지(손으로 줌하면 어느 칩도 아님).
  int? get _activeRangeIndex {
    final base = InbodyChartViewport.full([
      for (final p in widget.points) p.measuredAt,
    ]);
    // 전체를 보고 있으면(기록이 1년보다 짧아도) `전체` 칩이 선택된다.
    if (_viewport.isFull) return _ranges.length - 1;
    for (var i = 0; i < _ranges.length; i++) {
      final days = _ranges[i].$2;
      final target = days == null ? base.showAll() : base.lastDays(days);
      if ((target.startMs - _viewport.startMs).abs() < 1000 &&
          (target.endMs - _viewport.endMs).abs() < 1000) {
        return i;
      }
    }
    return null;
  }

  String _readout() {
    final series = _series;
    final index = _selected ?? (series.isEmpty ? null : series.length - 1);
    if (index == null || index >= series.length) {
      return '${_metric.label} 기록이 없어요';
    }
    final point = series[index];
    final text = '${_plain(point.value)}${_metric.unit}';
    if (index == 0) return '${inbodyDateText(point.at)} · $text';
    final diff = point.value - series[index - 1].value;
    final diffText =
        diff == 0
            ? '변화 없음'
            : '${diff > 0 ? '+' : ''}${_plain(diff)}${_metric.unit}';
    return '${inbodyDateText(point.at)} · $text ($diffText)';
  }

  static String _plain(double value) {
    final text = value.toStringAsFixed(1);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final series = _series;
    final active = _activeRangeIndex;
    return Scaffold(
      appBar: AppBar(title: const Text('인바디 추이')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  for (final metric in InbodyMetric.values)
                    ChoiceChip(
                      key: Key('inbody_page_metric_${metric.name}'),
                      label: Text(metric.label),
                      selected: _metric == metric,
                      onSelected:
                          (_) => setState(() {
                            _metric = metric;
                            _selected = null;
                          }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < _ranges.length; i++)
                    ChoiceChip(
                      key: Key('inbody_page_range_$i'),
                      label: Text(_ranges[i].$1),
                      selected: active == i,
                      onSelected:
                          (_) => setState(() {
                            final days = _ranges[i].$2;
                            _viewport =
                                days == null
                                    ? _viewport.showAll()
                                    : _viewport.lastDays(days);
                          }),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                _readout(),
                key: const Key('inbody_page_readout'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${inbodyDateText(_viewport.startDate)} ~ ${inbodyDateText(_viewport.endDate)}',
                key: const Key('inbody_page_range_text'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child:
                    series.length >= 2
                        ? InbodyTrendChart(
                          points: series,
                          viewport: _viewport,
                          selectedIndex:
                              _selected ??
                              (series.isEmpty ? null : series.length - 1),
                          onViewportChanged:
                              (next) => setState(() => _viewport = next),
                          onSelect:
                              (index) => setState(() => _selected = index),
                        )
                        : Center(
                          child: Text(
                            '${_metric.label} 기록이 2건 이상이면 추이를 볼 수 있어요',
                            key: const Key('inbody_page_need_more'),
                          ),
                        ),
              ),
              const SizedBox(height: 8),
              Text(
                '두 손가락으로 벌리거나 모아서 기간을 바꾸고, 한 손가락으로 밀어서 옮겨요. 점을 누르면 그날 값이 보여요.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
