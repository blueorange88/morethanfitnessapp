import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/models/anatomy_log.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/models/anatomy_trend.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/widgets/anatomy_change_card.dart';

AnatomyLogRecord _rec({
  required String lesson,
  required DateTime at,
  String exercise = '',
  AnatomyRecordType type = AnatomyRecordType.exercise,
  List<AnatomySet> sets = const [],
  String part = 'quad',
  String label = '대퇴사두',
  String memo = '',
}) {
  return AnatomyLogRecord(
    anatomyLogId: '$lesson-$exercise-${type.name}-$memo',
    trainerId: 't',
    memberId: 'm',
    lessonLogId: lesson,
    scheduleDocId: '',
    recordedAt: at,
    bodyGender: BodyGender.male,
    bodyView: BodyView.front,
    bodySide: BodySide.both,
    bodyPartId: part,
    bodyPartLabel: label,
    recordType: type,
    exerciseName: exercise,
    painLevel: type == AnatomyRecordType.pain ? 4 : 0,
    memo: memo,
    sets: sets,
    createdAt: at,
    updatedAt: at,
  );
}

Future<void> _pump(
  WidgetTester tester,
  AnatomyMemberHistory history, {
  VoidCallback? onOpen,
  double width = 450,
}) async {
  tester.view.physicalSize = Size(width * 2, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF1F2A44),
        body: SingleChildScrollView(
          child: AnatomyChangeCard(
            history: history,
            onOpenDetail: onOpen ?? () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final now = DateTime.now();
  DateTime daysAgo(int d) => DateTime(now.year, now.month, now.day - d, 16);

  final history = AnatomyMemberHistory([
    _rec(
      lesson: 'l1',
      at: daysAgo(14),
      exercise: '스쿼트',
      sets: const [AnatomySet(weightKg: 60, reps: 10)],
    ),
    _rec(
      lesson: 'l2',
      at: daysAgo(7),
      exercise: '스쿼트',
      sets: const [AnatomySet(weightKg: 70, reps: 10)],
    ),
    _rec(
      lesson: 'l2',
      at: daysAgo(7),
      exercise: '힙쓰러스트',
      part: 'glute',
      label: '둔근',
      sets: const [AnatomySet(weightKg: 80, reps: 12)],
    ),
    _rec(
      lesson: 'l2',
      at: daysAgo(7),
      type: AnatomyRecordType.pain,
      memo: '무릎',
    ),
    _rec(
      lesson: 'l2',
      at: daysAgo(7),
      type: AnatomyRecordType.caution,
      memo: '어깨',
    ),
  ]);

  testWidgets('대표 운동의 값·직전 대비 변화·집중 부위·통증 개수를 보여준다', (tester) async {
    await _pump(tester, history);
    expect(find.byKey(const ValueKey<String>('change_card')), findsOneWidget);
    expect(find.text('운동 변화'), findsOneWidget);
    // 운동 칩(최근 기록한 순)과 대표 운동의 추정 1RM
    expect(
      find.byKey(const ValueKey<String>('change_chip_스쿼트')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('change_chip_힙쓰러스트')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey<String>('change_value')), findsOneWidget);
    expect(find.textContaining('통증 1 · 주의 1'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('change_focus_quad')),
      findsOneWidget,
    );
  });

  testWidgets('운동 칩을 누르면 그 운동의 값으로 바뀌고 변화는 두 번 이상일 때만 보인다', (tester) async {
    await _pump(tester, history);
    final firstValue = tester.widget<Text>(
      find.byKey(const ValueKey<String>('change_value')),
    );
    await tester.tap(find.byKey(const ValueKey<String>('change_chip_힙쓰러스트')));
    await tester.pump();
    final secondValue = tester.widget<Text>(
      find.byKey(const ValueKey<String>('change_value')),
    );
    expect(secondValue.data, isNot(firstValue.data));
    // 힙쓰러스트는 한 번만 기록해서 직전 대비가 없다
    expect(find.byKey(const ValueKey<String>('change_delta')), findsNothing);
  });

  testWidgets('최근 기록이 PR이면 트로피가 보이고 한 번뿐인 운동은 안 보인다', (tester) async {
    await _pump(tester, history);
    await tester.tap(find.byKey(const ValueKey<String>('change_chip_스쿼트')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('change_pr')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey<String>('change_chip_힙쓰러스트')));
    await tester.pump();
    expect(find.byKey(const ValueKey<String>('change_pr')), findsNothing);
  });

  testWidgets('좁은 폰(320dp)에서도 넘치지 않는다', (tester) async {
    await _pump(tester, history, width: 320);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const ValueKey<String>('change_chip_스쿼트')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('자세히 보기를 누르면 콜백이 불린다', (tester) async {
    var opened = 0;
    await _pump(tester, history, onOpen: () => opened++);
    await tester.tap(find.byKey(const ValueKey<String>('change_open_detail')));
    expect(opened, 1);
  });

  testWidgets('기록이 없으면 아무것도 그리지 않는다', (tester) async {
    await _pump(tester, AnatomyMemberHistory(const []));
    expect(find.byKey(const ValueKey<String>('change_card')), findsNothing);
  });

  testWidgets('운동 세트 기록이 없고 통증만 있으면 안내와 통증 개수만 보인다', (tester) async {
    await _pump(
      tester,
      AnatomyMemberHistory([
        _rec(
          lesson: 'l1',
          at: daysAgo(3),
          type: AnatomyRecordType.pain,
          memo: '무릎',
        ),
      ]),
    );
    expect(
      find.byKey(const ValueKey<String>('change_no_exercise')),
      findsOneWidget,
    );
    expect(find.textContaining('통증 1'), findsOneWidget);
  });
}
