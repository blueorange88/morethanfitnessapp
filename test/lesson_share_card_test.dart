import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/models/anatomy_log.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/models/body_mask.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/widgets/anatomy_mini_figures.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/widgets/body_map_canvas.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/widgets/lesson_share_card.dart';

AnatomyLogRecord _rec({
  required String exercise,
  required int minute,
  AnatomyRecordType type = AnatomyRecordType.exercise,
  List<AnatomySet> sets = const [],
  String memo = '',
  String part = 'quad',
  String label = '대퇴사두',
}) {
  final at = DateTime(2026, 10, 12, 16, minute);
  return AnatomyLogRecord(
    anatomyLogId: '$exercise-$minute-${type.name}',
    trainerId: 't',
    memberId: 'm',
    lessonLogId: 'l1',
    scheduleDocId: '',
    recordedAt: at,
    bodyGender: BodyGender.male,
    bodyView: BodyView.front,
    bodySide: BodySide.both,
    bodyPartId: part,
    bodyPartLabel: label,
    recordType: type,
    exerciseName: exercise,
    painLevel: type == AnatomyRecordType.pain ? 5 : 0,
    memo: memo,
    sets: sets,
    createdAt: at,
    updatedAt: at,
  );
}

void main() {
  setUp(() {
    BodyMask.resetCacheForTest();
    BodyMask.loader = (asset, viewBox) async => BodyMask.open(viewBox);
  });
  tearDown(() {
    BodyMask.loader = BodyMask.defaultLoader;
    BodyMask.resetCacheForTest();
  });

  final records = [
    _rec(
      exercise: '스쿼트',
      minute: 1,
      sets: const [
        AnatomySet(weightKg: 60, reps: 5),
        AnatomySet(weightKg: 60, reps: 5),
        AnatomySet(weightKg: 60, reps: 5),
      ],
    ),
    _rec(
      exercise: '무릎 불편',
      minute: 2,
      type: AnatomyRecordType.pain,
      memo: '왼쪽 무릎이 시큰거림',
    ),
    _rec(exercise: '어깨 수술 이력', minute: 3, type: AnatomyRecordType.caution),
    _rec(exercise: '발목 가동성', minute: 4, type: AnatomyRecordType.mobility),
    _rec(
      exercise: '힙쓰러스트',
      minute: 5,
      part: 'glute',
      label: '둔근',
      sets: const [AnatomySet(weightKg: 80, reps: 12)],
    ),
  ];

  group('공유 이미지 데이터', () {
    test('운동 기록만 통과한다(통증·주의·가동성 제외)', () {
      final safe = shareSafeRecords(records);
      expect(safe.map((r) => r.exerciseName), ['스쿼트', '힙쓰러스트']);
      expect(
        safe.every((r) => r.recordType == AnatomyRecordType.exercise),
        isTrue,
      );
    });

    test('운동 줄은 기록 순서대로, 같은 운동은 세트를 합친다', () {
      final lines = shareExerciseLines([
        ...records,
        _rec(
          exercise: '스쿼트',
          minute: 9,
          sets: const [AnatomySet(weightKg: 60, reps: 5)],
        ),
      ]);
      expect(lines.map((l) => l.name), ['스쿼트', '힙쓰러스트']);
      expect(lines.first.summary, '4 X 60kg | 20회');
      expect(lines.last.summary, '1 X 80kg | 12회');
    });
  });

  group('공유 시트', () {
    Future<List<List<int>>> openSheet(WidgetTester tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sent = <List<int>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonShareSheet(
              dateText: '2026.10.12',
              timeText: '16:00',
              subtitle: '23회차 · 김회원 님',
              records: records,
              shareImage: (bytes) async => sent.add(bytes),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return sent;
    }

    testWidgets('이미지에는 운동만 있고 통증·주의·가동성·내부 메모는 없다', (tester) async {
      await openSheet(tester);
      final card = find.byKey(const ValueKey<String>('share_card'));
      expect(card, findsOneWidget);
      for (final text in [
        '2026.10.12',
        '16:00',
        '23회차 · 김회원 님',
        '스쿼트',
        '힙쓰러스트',
      ]) {
        expect(
          find.descendant(of: card, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(
        find.descendant(of: card, matching: find.text('3 X 60kg | 15회')),
        findsOneWidget,
      );
      for (final text in ['무릎 불편', '왼쪽 무릎이 시큰거림', '어깨 수술 이력', '발목 가동성']) {
        expect(
          find.descendant(of: card, matching: find.textContaining(text)),
          findsNothing,
          reason: text,
        );
      }
    });

    testWidgets('한마디는 20자까지, 입력하면 이미지에 들어간다', (tester) async {
      await openSheet(tester);
      final card = find.byKey(const ValueKey<String>('share_card'));
      expect(
        find.descendant(
          of: card,
          matching: find.byKey(const ValueKey<String>('share_card_memo')),
        ),
        findsNothing,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('share_memo')),
        '오늘 무릎 컨디션 좋았어요',
      );
      await tester.pump();
      expect(
        find.descendant(of: card, matching: find.text('오늘 무릎 컨디션 좋았어요')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const ValueKey<String>('share_memo')),
        '가' * 30,
      );
      await tester.pump();
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey<String>('share_memo')),
      );
      expect(field.maxLength, 20);
      expect(field.controller!.text.length, 20);
    });

    testWidgets('보내기를 누르면 PNG 이미지가 만들어져 전달된다', (tester) async {
      final sent = await openSheet(tester);
      await tester.tap(find.byKey(const ValueKey<String>('share_send')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      expect(sent, hasLength(1));
      // PNG 시그니처
      expect(sent.first.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
      expect(sent.first.length, greaterThan(1000));
    });
  });

  group('펼친 카드의 작은 몸 그림', () {
    testWidgets('앞·뒤 두 장을 보여주고 통증 점도 그린다', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: AnatomyMiniFigures(records: records))),
      );
      await tester.pumpAndSettle();
      final canvases = tester.widgetList<BodyMapCanvas>(
        find.byType(BodyMapCanvas),
      );
      expect(canvases, hasLength(2));
      // 트레이너 화면이라 통증·주의·가동성도 함께 넘긴다(회원 공유 이미지와 다르다)
      expect(
        canvases.first.records.any(
          (r) => r.recordType == AnatomyRecordType.pain,
        ),
        isTrue,
      );
    });
  });

  group('텍스트·카테고리 레슨 공유 시트(몸 그림 없음)', () {
    testWidgets('운동 줄과 글만 있고 몸 그림은 없으며 PNG가 만들어진다', (tester) async {
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sent = <List<int>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonShareSheet(
              dateText: '2026.10.12',
              timeText: '16:00',
              subtitle: '5회차 · 김회원 님',
              lines: const [
                ShareExerciseLine(name: '스쿼트', summary: '3세트 × 12회'),
              ],
              bodyText: '하체 위주로 진행했어요',
              notice: '아래 내용이 이미지로 보내져요.',
              shareImage: (bytes) async => sent.add(bytes),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey<String>('share_card'));
      expect(find.byType(BodyMapCanvas), findsNothing);
      expect(find.text('아래 내용이 이미지로 보내져요.'), findsOneWidget);
      for (final text in ['스쿼트', '3세트 × 12회', '하체 위주로 진행했어요']) {
        expect(
          find.descendant(of: card, matching: find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      await tester.enterText(
        find.byKey(const ValueKey<String>('share_memo')),
        '수고했어요',
      );
      await tester.pump();
      expect(
        find.descendant(of: card, matching: find.text('수고했어요')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const ValueKey<String>('share_send')));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      expect(sent, hasLength(1));
      expect(sent.first.take(4).toList(), [0x89, 0x50, 0x4E, 0x47]);
    });
  });
}
