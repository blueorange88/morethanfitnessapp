import 'package:flutter/material.dart';

import '../models/anatomy_log.dart';
import '../models/anatomy_trend.dart';
import 'trend_chart.dart';

/// 레슨일지 목록 머리말의 `MORE 레슨브리핑` 안에 들어가는 운동 변화 카드.
/// 대표 운동 하나의 그래프·직전 대비 변화와 최근 집중 부위, 통증·주의·가동성 개수를
/// 보여주고, `자세히 보기`로 전체 변화 화면을 연다. 기록이 없으면 아무것도 그리지 않는다.
class AnatomyChangeCard extends StatefulWidget {
  const AnatomyChangeCard({
    super.key,
    required this.history,
    required this.onOpenDetail,
  });

  final AnatomyMemberHistory history;
  final VoidCallback onOpenDetail;

  @override
  State<AnatomyChangeCard> createState() => _AnatomyChangeCardState();
}

class _AnatomyChangeCardState extends State<AnatomyChangeCard> {
  static const List<TrendMetric> _metricOrder = [
    TrendMetric.oneRm,
    TrendMetric.maxWeight,
    TrendMetric.volume,
    TrendMetric.maxReps,
  ];

  String? _selected;

  /// 그릴 점이 있는 첫 지표(추정 1RM → 최대 무게 → 볼륨 → 최대 횟수 순).
  TrendMetric? _metricFor(String name) {
    for (final metric in _metricOrder) {
      if (widget.history.trend(name, metric).isNotEmpty) return metric;
    }
    return null;
  }

  Widget _chip(
    String label, {
    required bool selected,
    VoidCallback? onTap,
    Key? key,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: selected ? const Color(0xFF111827) : Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = widget.history;
    if (history.records.isEmpty) return const SizedBox.shrink();

    final exercises = history.exercises();
    final focus = history.focus(limit: 3);
    final pain = history.byType(AnatomyRecordType.pain).length;
    final caution = history.byType(AnatomyRecordType.caution).length;
    final mobility = history.byType(AnatomyRecordType.mobility).length;
    final noteParts = [
      if (pain > 0) '통증 $pain',
      if (caution > 0) '주의 $caution',
      if (mobility > 0) '가동성 $mobility',
    ];

    ExerciseOverview? selected;
    for (final overview in exercises.take(5)) {
      if (overview.name == _selected) selected = overview;
    }
    selected ??= exercises.isEmpty ? null : exercises.first;
    final metric = selected == null ? null : _metricFor(selected.name);
    final points =
        selected == null || metric == null
            ? const <TrendPoint>[]
            : history.trend(selected.name, metric);
    final latest = points.isEmpty ? null : points.last.value;
    final change =
        points.length >= 2
            ? points.last.value - points[points.length - 2].value
            : null;
    final unit = metric == null ? '' : trendMetricUnit(metric);

    return Container(
      key: const ValueKey<String>('change_card'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '운동 변화',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey<String>('change_open_detail'),
                onPressed: widget.onOpenDetail,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('자세히 보기', style: TextStyle(fontSize: 11.5)),
              ),
            ],
          ),
          if (selected == null)
            const Padding(
              padding: EdgeInsets.only(right: 6, top: 2),
              child: Text(
                '아직 세트를 기록한 운동이 없어요.',
                key: ValueKey<String>('change_no_exercise'),
                style: TextStyle(color: Colors.white, fontSize: 12.5),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final overview in exercises.take(5))
                        _chip(
                          overview.name,
                          key: ValueKey<String>('change_chip_${overview.name}'),
                          selected: overview.name == selected.name,
                          onTap:
                              () => setState(() => _selected = overview.name),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        latest == null
                            ? '-'
                            : '${formatAnatomyNumber(latest)}$unit',
                        key: const ValueKey<String>('change_value'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (selected.sessions.isNotEmpty &&
                          history.isPersonalRecord(
                            selected.name,
                            selected.last.lessonLogId,
                          ))
                        const Padding(
                          key: ValueKey<String>('change_pr'),
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.emoji_events_rounded,
                            size: 20,
                            color: Color(0xFFFCD34D),
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (change != null)
                        Text(
                          '${change >= 0 ? '▲' : '▼'} '
                          '${formatAnatomyNumber(change.abs())}$unit',
                          key: const ValueKey<String>('change_delta'),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color:
                                change >= 0
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFFFCA5A5),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          '${metric == null ? '' : trendMetricLabel(metric)} · '
                          '${selected.sessions.length}번 기록',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.75),
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Theme(
                    data: ThemeData.light(),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TrendChart(
                        points: points,
                        unit: unit,
                        height: 120,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (focus.isNotEmpty || noteParts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10, right: 6),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (focus.isNotEmpty)
                    Text(
                      '최근 4주',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                      ),
                    ),
                  for (final entry in focus)
                    _chip(
                      '${entry.label} ${entry.sessions}회',
                      selected: false,
                      key: ValueKey<String>('change_focus_${entry.partId}'),
                    ),
                  if (noteParts.isNotEmpty)
                    Text(
                      noteParts.join(' · '),
                      key: const ValueKey<String>('change_notes'),
                      style: const TextStyle(
                        color: Color(0xFFFCD34D),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
