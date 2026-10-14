import 'package:flutter/material.dart';

import 'models/anatomy_log.dart';
import 'models/anatomy_trend.dart';
import 'widgets/anatomy_header.dart';
import 'widgets/trend_chart.dart';

/// 한 운동의 추이: 지표(추정 1RM·최대 무게·볼륨·최대 횟수) 선택, 그래프, 레슨별 기록.
class AnatomyExerciseTrendPage extends StatefulWidget {
  const AnatomyExerciseTrendPage({
    super.key,
    required this.exercise,
    required this.history,
  });

  final String exercise;
  final AnatomyMemberHistory history;

  @override
  State<AnatomyExerciseTrendPage> createState() =>
      _AnatomyExerciseTrendPageState();
}

class _AnatomyExerciseTrendPageState extends State<AnatomyExerciseTrendPage> {
  TrendMetric _metric = TrendMetric.oneRm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final sessions = widget.history.sessionsFor(widget.exercise);
    final points = widget.history.trend(widget.exercise, _metric);
    final unit = trendMetricUnit(_metric);
    final latest = points.isEmpty ? null : points.last.value;
    final change =
        points.length >= 2
            ? points.last.value - points[points.length - 2].value
            : null;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          AnatomyHeader(title: '${widget.exercise} 추이'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final metric in TrendMetric.values)
                      ChoiceChip(
                        key: ValueKey<String>('trend_metric_${metric.name}'),
                        label: Text(trendMetricLabel(metric)),
                        selected: _metric == metric,
                        onSelected: (_) => setState(() => _metric = metric),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      latest == null
                          ? '-'
                          : '${formatAnatomyNumber(latest)}$unit',
                      key: const ValueKey<String>('trend_latest'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (change != null)
                      Text(
                        '${change >= 0 ? '▲' : '▼'} '
                        '${formatAnatomyNumber(change.abs())}$unit',
                        key: const ValueKey<String>('trend_change'),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color:
                              change >= 0
                                  ? const Color(0xFF16A34A)
                                  : colors.error,
                        ),
                      ),
                    const Spacer(),
                    Text(
                      '${sessions.length}번 기록',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (_metric == TrendMetric.oneRm)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '추정 1RM은 12회 이하 세트의 무게·횟수로 계산한 추정치예요.',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.outline),
                  ),
                  child: TrendChart(points: points, unit: unit),
                ),
                const SizedBox(height: 20),
                const Text(
                  '레슨별 기록',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                for (final session in sessions.reversed)
                  Container(
                    key: ValueKey<String>(
                      'trend_session_${session.lessonLogId}',
                    ),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.outline),
                    ),
                    child: Row(
                      children: [
                        Text(
                          formatAnatomyDate(session.date),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          session.summary,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (sessions.isEmpty)
                  Text(
                    '아직 세트를 기록한 레슨이 없어요.',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// [record] 가 통증·주의·가동성일 때 목록에 보여줄 한 줄 설명.
String anatomyNoteTitle(AnatomyLogRecord record) {
  final side = switch (record.bodySide) {
    BodySide.left => '왼쪽 ',
    BodySide.right => '오른쪽 ',
    _ => '',
  };
  final text = record.exerciseName.trim();
  return '$side${text.isEmpty ? record.bodyPartLabel : text}';
}
