import 'package:flutter/material.dart';

class HomeSameNameScheduleLinkCandidate {
  const HomeSameNameScheduleLinkCandidate({
    required this.scheduleDocId,
    required this.memberName,
    required this.startAt,
  });

  final String scheduleDocId;
  final String memberName;
  final DateTime startAt;

  String get label {
    const weekdays = <String>['월', '화', '수', '목', '금', '토', '일'];
    final period = startAt.hour < 12 ? '오전' : '오후';
    final hour = startAt.hour % 12 == 0 ? 12 : startAt.hour % 12;
    final minute =
        startAt.minute == 0
            ? ''
            : ' ${startAt.minute.toString().padLeft(2, '0')}분';
    return '${weekdays[startAt.weekday - 1]}요일 $period $hour시$minute $memberName 님';
  }
}

String normalizeHomeScheduleLinkName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

List<HomeSameNameScheduleLinkCandidate> homeSameNameUnlinkedScheduleCandidates({
  required Iterable<Map<String, dynamic>> schedules,
  required String currentScheduleDocId,
  required String memberName,
}) {
  final cleanCurrentId = currentScheduleDocId.trim();
  final normalizedName = normalizeHomeScheduleLinkName(memberName);
  if (cleanCurrentId.isEmpty || normalizedName.isEmpty) return const [];

  DateTime? currentStartAt;
  for (final schedule in schedules) {
    if ((schedule['docId'] ?? '').toString().trim() != cleanCurrentId) {
      continue;
    }
    final value = schedule['startAt'];
    if (value is DateTime) currentStartAt = value;
    break;
  }
  if (currentStartAt == null) return const [];

  final currentWeekStart = DateTime(
    currentStartAt.year,
    currentStartAt.month,
    currentStartAt.day - (currentStartAt.weekday - 1),
  );
  final currentWeekEnd = currentWeekStart.add(const Duration(days: 7));
  final seenIds = <String>{};
  final candidates = <HomeSameNameScheduleLinkCandidate>[];

  for (final schedule in schedules) {
    final docId = (schedule['docId'] ?? '').toString().trim();
    final startAt = schedule['startAt'];
    final linkedMemberId = (schedule['memberId'] ?? '').toString().trim();
    final candidateName = (schedule['name'] ?? '').toString().trim();

    if (docId.isEmpty ||
        docId == cleanCurrentId ||
        !seenIds.add(docId) ||
        startAt is! DateTime ||
        linkedMemberId.isNotEmpty ||
        schedule['isDeleted'] == true ||
        normalizeHomeScheduleLinkName(candidateName) != normalizedName ||
        startAt.isBefore(currentWeekStart) ||
        !startAt.isBefore(currentWeekEnd)) {
      continue;
    }

    candidates.add(
      HomeSameNameScheduleLinkCandidate(
        scheduleDocId: docId,
        memberName: candidateName,
        startAt: startAt,
      ),
    );
  }

  candidates.sort((left, right) => left.startAt.compareTo(right.startAt));
  return candidates;
}

class HomeSameNameScheduleLinkSheet {
  const HomeSameNameScheduleLinkSheet._();

  static Future<Set<String>?> show({
    required BuildContext context,
    required String memberName,
    required List<HomeSameNameScheduleLinkCandidate> candidates,
  }) {
    final selectedIds =
        candidates.map((candidate) => candidate.scheduleDocId).toSet();

    return showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final theme = Theme.of(sheetContext);
            final scheme = theme.colorScheme;
            final bottomSafe = MediaQuery.viewPaddingOf(sheetContext).bottom;
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.72,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '같은 이름의 일정도 연결할까요?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${memberName.trim()} 님으로 연결할 다른 미연결 일정을 선택해 주세요. 이 일정은 항상 연결됩니다.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Flexible(
                      child: ListView.separated(
                        key: const Key('same_name_schedule_link_list'),
                        shrinkWrap: true,
                        itemCount: candidates.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final candidate = candidates[index];
                          final selected = selectedIds.contains(
                            candidate.scheduleDocId,
                          );
                          return CheckboxListTile(
                            key: ValueKey(
                              'same_name_schedule_${candidate.scheduleDocId}',
                            ),
                            value: selected,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(color: scheme.outlineVariant),
                            ),
                            title: Text(
                              candidate.label,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onChanged: (value) {
                              setSheetState(() {
                                if (value == true) {
                                  selectedIds.add(candidate.scheduleDocId);
                                } else {
                                  selectedIds.remove(candidate.scheduleDocId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      key: const Key('same_name_schedule_link_actions'),
                      padding: EdgeInsets.only(bottom: bottomSafe),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              child: const Text('취소'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              key: const Key('same_name_schedule_link_confirm'),
                              onPressed:
                                  () => Navigator.of(
                                    sheetContext,
                                  ).pop(Set<String>.from(selectedIds)),
                              child: Text('${selectedIds.length + 1}개 일정 연결'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
