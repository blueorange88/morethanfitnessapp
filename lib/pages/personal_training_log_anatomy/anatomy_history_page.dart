import 'package:flutter/material.dart';

import 'anatomy_trend_page.dart';
import 'models/anatomy_log.dart';
import 'models/anatomy_trend.dart';
import 'widgets/anatomy_header.dart';

/// 한 회원의 변화 보기(아나토미 기록 기준): 운동(최근 집중 부위·운동별 추이), 통증·불편, 가동성·주의.
class AnatomyHistoryPage extends StatelessWidget {
  const AnatomyHistoryPage({
    super.key,
    required this.memberName,
    required this.history,
  });

  final String memberName;
  final AnatomyMemberHistory history;

  @override
  Widget build(BuildContext context) {
    final name = memberName.trim();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Column(
          children: [
            AnatomyHeader(title: name.isEmpty ? '변화 보기' : '$name 님 변화 보기'),
            Material(
              color: Theme.of(context).colorScheme.surface,
              child: const TabBar(
                tabs: [
                  Tab(
                    key: ValueKey<String>('history_tab_exercise'),
                    text: '운동',
                  ),
                  Tab(key: ValueKey<String>('history_tab_pain'), text: '통증·불편'),
                  Tab(
                    key: ValueKey<String>('history_tab_other'),
                    text: '가동성·주의',
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _ExerciseTab(history: history),
                  _NoteList(
                    records: history.byType(AnatomyRecordType.pain),
                    empty: '아직 통증·불편 기록이 없어요.',
                    trailingFor: (r) => '${r.painLevel} / 10',
                    trailingColor: (colors) => colors.error,
                  ),
                  _NoteList(
                    records: [
                      ...history.byType(AnatomyRecordType.mobility),
                      ...history.byType(AnatomyRecordType.caution),
                    ]..sort((a, b) => b.recordedAt.compareTo(a.recordedAt)),
                    empty: '아직 가동성·주의 기록이 없어요.',
                    trailingFor: (r) {
                      if (r.recordType == AnatomyRecordType.caution) {
                        return '주의';
                      }
                      return switch (r.mobilityResult) {
                        MobilityResult.normal => '○ 정상',
                        MobilityResult.mild => '△ 보상',
                        MobilityResult.severe => '× 제한',
                        null => '가동성',
                      };
                    },
                    trailingColor: (colors) => colors.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseTab extends StatelessWidget {
  const _ExerciseTab({required this.history});

  final AnatomyMemberHistory history;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final focus = history.focus();
    final exercises = history.exercises();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const Text(
          '최근 4주 집중 부위',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (focus.isEmpty)
          Text(
            '최근 4주 동안 목표 부위로 기록한 운동이 없어요.',
            key: const ValueKey<String>('focus_empty'),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.outline),
            ),
            child: Column(
              children: [
                for (final entry in focus)
                  Padding(
                    key: ValueKey<String>('focus_${entry.partId}'),
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 86,
                          child: Text(
                            entry.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: entry.sessions / focus.first.sessions,
                              minHeight: 8,
                              backgroundColor: colors.outline.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${entry.sessions}회 · ${entry.sets}세트',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        const Text(
          '운동별 기록',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (exercises.isEmpty)
          Text(
            '아직 세트를 기록한 운동이 없어요.',
            key: const ValueKey<String>('exercise_empty'),
            style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
          ),
        for (final overview in exercises)
          _ExerciseRow(overview: overview, history: history),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.overview, required this.history});

  final ExerciseOverview overview;
  final AnatomyMemberHistory history;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final last = overview.last;
    final previous = overview.previous;
    final now = last.value(TrendMetric.oneRm);
    final before = previous?.value(TrendMetric.oneRm);
    final change = now != null && before != null ? now - before : null;
    return InkWell(
      key: ValueKey<String>('exercise_row_${overview.name}'),
      borderRadius: BorderRadius.circular(14),
      onTap:
          () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder:
                  (_) => AnatomyExerciseTrendPage(
                    exercise: overview.name,
                    history: history,
                  ),
            ),
          ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.outline),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        overview.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      if (history.isPersonalRecord(
                        overview.name,
                        last.lessonLogId,
                      ))
                        Padding(
                          key: ValueKey<String>('exercise_pr_${overview.name}'),
                          padding: const EdgeInsets.only(left: 4),
                          child: const Icon(
                            Icons.emoji_events_rounded,
                            size: 16,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${formatAnatomyDate(last.date)} · ${last.summary}',
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (change != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '${change >= 0 ? '▲' : '▼'} ${formatAnatomyNumber(change.abs())}kg',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: change >= 0 ? const Color(0xFF16A34A) : colors.error,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _NoteList extends StatelessWidget {
  const _NoteList({
    required this.records,
    required this.empty,
    required this.trailingFor,
    required this.trailingColor,
  });

  final List<AnatomyLogRecord> records;
  final String empty;
  final String Function(AnatomyLogRecord) trailingFor;
  final Color Function(ColorScheme) trailingColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (records.isEmpty) {
      return Center(
        child: Text(
          empty,
          style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        for (final record in records)
          Container(
            key: ValueKey<String>('note_${record.anatomyLogId}'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colors.outline),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        anatomyNoteTitle(record),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatAnatomyDate(record.recordedAt)} · ${record.bodyPartLabel}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (record.memo.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            record.memo,
                            style: const TextStyle(fontSize: 12, height: 1.35),
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  trailingFor(record),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: trailingColor(colors),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
