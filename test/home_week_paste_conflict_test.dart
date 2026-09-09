import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/home_week_paste_conflict_service.dart';
import 'package:mtf_app/theme.dart';
import 'package:mtf_app/widgets/home/schedule/home_week_paste_overwrite_sheet.dart';

void main() {
  HomeWeekPasteCandidate candidate(
    int index,
    int hour, {
    int minute = 0,
    int durationMinutes = 50,
  }) {
    final startAt = DateTime(2026, 8, 17, hour, minute);
    final endAt = startAt.add(Duration(minutes: durationMinutes));
    return HomeWeekPasteCandidate(
      sourceIndex: index,
      day: '월',
      time: '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}',
      endTime: '${endAt.hour.toString().padLeft(2, '0')}:'
          '${endAt.minute.toString().padLeft(2, '0')}',
      startAt: startAt,
      endAt: endAt,
    );
  }

  HomeWeekPasteExistingSchedule existing(
    String id,
    int hour, {
    int minute = 0,
    int durationMinutes = 50,
  }) {
    final startAt = DateTime(2026, 8, 17, hour, minute);
    final endAt = startAt.add(Duration(minutes: durationMinutes));
    return HomeWeekPasteExistingSchedule(
      docId: id,
      day: '월',
      time: '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}',
      endTime: '${endAt.hour.toString().padLeft(2, '0')}:'
          '${endAt.minute.toString().padLeft(2, '0')}',
      startAt: startAt,
      endAt: endAt,
      name: 'DEV 일정',
      memberId: 'member-$id',
      isConfirmed: false,
    );
  }

  group('HomeWeekPasteConflictService', () {
    test('기존 일정이 없으면 5개를 전부 붙여넣을 수 있다', () {
      final plan = HomeWeekPasteConflictService.classify(
        candidates: List.generate(5, (index) => candidate(index, 9 + index)),
        existingSchedules: const [],
      );

      expect(plan.pasteableCount, 5);
      expect(plan.conflictingCount, 0);
    });

    for (final conflictCount in [1, 2, 3]) {
      test('$conflictCount개 충돌은 후보 $conflictCount개만 제외한다', () {
        final candidates =
            List.generate(5, (index) => candidate(index, 9 + index));
        final existingSchedules = List.generate(
          conflictCount,
          (index) => existing('existing-$index', 9 + index),
        );

        final plan = HomeWeekPasteConflictService.classify(
          candidates: candidates,
          existingSchedules: existingSchedules,
        );

        expect(plan.conflictingCount, conflictCount);
        expect(plan.pasteableCount, 5 - conflictCount);
      });
    }

    test('모든 후보가 충돌하면 붙여넣기 대상은 0개다', () {
      final plan = HomeWeekPasteConflictService.classify(
        candidates: [candidate(0, 13), candidate(1, 14)],
        existingSchedules: [
          existing('existing-13', 13),
          existing('existing-14', 14),
        ],
      );

      expect(plan.allConflicting, isTrue);
      expect(plan.pasteableCount, 0);
      expect(plan.conflictingCount, 2);
    });

    test('13:20~14:10과 양쪽에서 겹치는 두 후보를 모두 제외한다', () {
      final plan = HomeWeekPasteConflictService.classify(
        candidates: [
          candidate(0, 13),
          candidate(1, 14),
          candidate(2, 15),
        ],
        existingSchedules: [
          existing('existing', 13, minute: 20),
        ],
      );

      expect(plan.conflictingSourceIndexes, {0, 1});
      expect(plan.pasteableSourceIndexes, {2});
    });

    test('기존 종료와 신규 시작이 정확히 같으면 충돌하지 않는다', () {
      final plan = HomeWeekPasteConflictService.classify(
        candidates: [candidate(0, 13, minute: 50)],
        existingSchedules: [existing('existing', 13)],
      );

      expect(plan.conflictingCount, 0);
      expect(plan.pasteableSourceIndexes, {0});
    });

    test('같은 시간의 정확한 중복은 충돌이다', () {
      final plan = HomeWeekPasteConflictService.classify(
        candidates: [candidate(0, 13)],
        existingSchedules: [existing('existing', 13)],
      );

      expect(plan.conflictingSourceIndexes, {0});
    });

    test('후보 하나가 기존 일정 여러 개와 겹쳐도 제외 수는 1개다', () {
      final plan = HomeWeekPasteConflictService.classify(
        candidates: [candidate(0, 13, minute: 20)],
        existingSchedules: [
          existing('existing-a', 13),
          existing('existing-b', 14),
        ],
      );

      expect(plan.conflictingCount, 1);
    });

    test('붙여넣기 후보끼리 겹치면 두 후보 모두 제외한다', () {
      final plan = HomeWeekPasteConflictService.classify(
        candidates: [
          candidate(0, 13),
          candidate(1, 13, minute: 30),
          candidate(2, 15),
        ],
        existingSchedules: const [],
      );

      expect(plan.conflictingSourceIndexes, {0, 1});
      expect(plan.pasteableSourceIndexes, {2});
    });

    test('확인 사이 충돌 후보 집합 변경을 감지한다', () {
      final first = HomeWeekPasteConflictService.classify(
        candidates: [candidate(0, 13), candidate(1, 14)],
        existingSchedules: [existing('existing-13', 13)],
      );
      final second = HomeWeekPasteConflictService.classify(
        candidates: [candidate(0, 13), candidate(1, 14)],
        existingSchedules: [
          existing('existing-13', 13),
          existing('existing-14', 14),
        ],
      );

      expect(first.hasSameConflicts(second), isFalse);
    });
  });

  group('HomeWeekPasteOverwriteSheet', () {
    Future<void> pumpPrompt(
      WidgetTester tester, {
      required ThemeData theme,
      required int conflictCount,
      required int pasteableCount,
      required ValueChanged<bool> onResult,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () async {
                    final result = await HomeWeekPasteOverwriteSheet.show(
                      context: context,
                      targetLabel: '다음 주',
                      conflictCount: conflictCount,
                      pasteableCount: pasteableCount,
                      primaryColor: Theme.of(context).colorScheme.primary,
                    );
                    onResult(result);
                  },
                  child: const Text('열기'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
    }

    for (final entry in <String, ThemeData>{
      'light': lightTheme(),
      'dark': darkTheme(),
      'lululala': lululalaTheme(),
    }.entries) {
      testWidgets('${entry.key}에서 부분 충돌 문구와 동적 버튼을 렌더링한다',
          (tester) async {
        bool? result;
        await pumpPrompt(
          tester,
          theme: entry.value,
          conflictCount: 2,
          pasteableCount: 3,
          onResult: (value) => result = value,
        );

        expect(find.text('겹치는 일정이 2개 있어요'), findsOneWidget);
        expect(find.textContaining('나머지 3개 일정을'), findsOneWidget);
        expect(find.text('기존 일정은 변경되지 않아요.'), findsOneWidget);
        expect(find.text('2개 제외하고 붙여넣기'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.tap(find.byKey(const Key('week_paste_conflict_cancel')));
        await tester.pumpAndSettle();
        expect(result, isFalse);
      });
    }

    testWidgets('확인하면 정상 일정만 붙여넣도록 true를 반환한다', (tester) async {
      bool? result;
      await pumpPrompt(
        tester,
        theme: lightTheme(),
        conflictCount: 2,
        pasteableCount: 3,
        onResult: (value) => result = value,
      );

      await tester.tap(find.byKey(const Key('week_paste_conflict_confirm')));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('모두 충돌하면 확인 버튼만 표시하고 false를 반환한다', (tester) async {
      bool? result;
      await pumpPrompt(
        tester,
        theme: lightTheme(),
        conflictCount: 2,
        pasteableCount: 0,
        onResult: (value) => result = value,
      );

      expect(find.text('붙여넣을 수 있는 일정이 없어요'), findsOneWidget);
      expect(find.text('2개 일정이 모두 기존 일정과 겹쳐요.'), findsOneWidget);
      expect(find.byKey(const Key('week_paste_conflict_confirm')), findsNothing);
      await tester.tap(find.byKey(const Key('week_paste_conflict_ack')));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });
  });

  test('Home 붙여넣기는 기존 일정 delete 없이 pasteable index만 batch에 추가한다', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _pasteWeekSchedules');
    final end = source.indexOf('Future<void> _deleteAllSchedulesInWeek', start);
    final pasteSource = source.substring(start, end);

    expect(pasteSource, contains('pasteableSourceIndexes'));
    expect(pasteSource, contains('commitScheduleWrites'));
    expect(pasteSource, isNot(contains('deleteSchedules')));
    expect(pasteSource, isNot(contains('deleteDocIds:')));
    expect(source, contains("where('trainerId', isEqualTo: _personalOwnerUid)"));
    expect(source, contains("where('workspaceType', isEqualTo: 'personal')"));
  });
}
