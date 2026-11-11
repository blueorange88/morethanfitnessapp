import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/lesson_insights_stats.dart';
import 'package:mtf_app/widgets/lesson_trend_card.dart';

final _now = DateTime(2026, 11, 12, 10);

LessonInsightEntry _entry(DateTime at, String status) =>
    LessonInsightEntry(startAt: at, status: status, type: 'PT');

List<LessonInsightEntry> _lessons() => [
  // 이번 주(11/9~) 완료 3건 + 미확정 1건
  _entry(DateTime(2026, 11, 10, 9), 'completed'),
  _entry(DateTime(2026, 11, 10, 18), 'completed'),
  _entry(DateTime(2026, 11, 11, 9), 'completed'),
  _entry(DateTime(2026, 11, 12, 9), ''),
  // 지난주
  _entry(DateTime(2026, 11, 3, 9), 'completed'),
];

Future<void> _pump(
  WidgetTester tester, {
  bool hasYearData = false,
  Future<void> Function()? onNeedYearData,
  ValueChanged<bool>? onMulti,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: LessonTrendCard(
              lessons: _lessons(),
              memberCreatedAts: [DateTime(2026, 11, 2)],
              dataStart: DateTime(2026, 8, 14),
              hasYearData: hasYearData,
              onNeedYearData: onNeedYearData ?? () async {},
              onMultiTouchChanged: onMulti,
              now: _now,
            ),
          ),
        ),
      ),
    ),
  );
}

String _readout(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('trend_readout'))).data!;

bool _selected(WidgetTester tester, String key) =>
    tester.widget<ChoiceChip>(find.byKey(Key(key))).selected;

Future<void> _pinch(WidgetTester tester, {required bool spread}) async {
  final center = tester.getCenter(find.byKey(const Key('trend_canvas')));
  final start = spread ? 20.0 : 140.0;
  final end = spread ? 140.0 : 20.0;
  final a = await tester.startGesture(center - Offset(start, 0), pointer: 11);
  final b = await tester.startGesture(center + Offset(start, 0), pointer: 12);
  await tester.pump();
  await a.moveTo(center - Offset(end, 0));
  await b.moveTo(center + Offset(end, 0));
  await tester.pump();
  await a.up();
  await b.up();
  await tester.pump();
}

void main() {
  testWidgets('처음에는 주별·완료 레슨이고 이번 주 값이 읽힌다', (tester) async {
    await _pump(tester);
    expect(_selected(tester, 'trend_granularity_week'), isTrue);
    expect(_selected(tester, 'trend_metric_completed'), isTrue);
    expect(_readout(tester), '11/9 ~ 11/15 · 3회');
    expect(
      tester.widget<Text>(find.byKey(const Key('trend_total'))).data,
      '보이는 12주 합계 4회',
    );
  });

  testWidgets('일별 칩을 누르면 하루 단위로 바뀌고 오늘 값이 읽힌다', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('trend_granularity_day')));
    await tester.pump();
    expect(_readout(tester), '11/12(목) · 0회'); // 오늘 레슨은 미확정
    expect(
      tester.widget<Text>(find.byKey(const Key('trend_total'))).data,
      '보이는 14일 합계 4회',
    );
  });

  testWidgets('지표를 바꾸면 등록 레슨 수가 읽힌다', (tester) async {
    await _pump(tester);
    await tester.tap(find.byKey(const Key('trend_metric_registered')));
    await tester.pump();
    expect(_readout(tester), '11/9 ~ 11/15 · 4회');
    await tester.tap(find.byKey(const Key('trend_metric_newMembers')));
    await tester.pump();
    expect(_readout(tester), '11/9 ~ 11/15 · 0명');
  });

  testWidgets('두 손가락을 모으면 주별에서 월별로 거칠어진다', (tester) async {
    var needYear = 0;
    await _pump(tester, onNeedYearData: () async => needYear++);
    await _pinch(tester, spread: false);
    await tester.pumpAndSettle();
    expect(_selected(tester, 'trend_granularity_month'), isTrue);
    expect(_readout(tester), '2026년 11월 · 4회');
    // 12개월 데이터가 아직 없어서 한 번 불러온다.
    expect(needYear, 1);
  });

  testWidgets('두 손가락을 벌리면 주별에서 일별로 세밀해진다', (tester) async {
    await _pump(tester);
    await _pinch(tester, spread: true);
    await tester.pumpAndSettle();
    expect(_selected(tester, 'trend_granularity_day'), isTrue);
  });

  testWidgets('이미 12개월을 불러왔으면 월별로 가도 다시 불러오지 않는다', (tester) async {
    var needYear = 0;
    await _pump(
      tester,
      hasYearData: true,
      onNeedYearData: () async => needYear++,
    );
    await tester.tap(find.byKey(const Key('trend_granularity_month')));
    await tester.pumpAndSettle();
    expect(needYear, 0);
    expect(_selected(tester, 'trend_granularity_month'), isTrue);
  });

  testWidgets('옆으로 밀면(오른쪽으로 끌면) 지난 기간이 보인다', (tester) async {
    await _pump(tester);
    expect(_readout(tester), '11/9 ~ 11/15 · 3회');
    await tester.drag(
      find.byKey(const Key('trend_canvas')),
      const Offset(60, 0),
    );
    await tester.pump();
    // 한 주 앞으로 가서 맨 오른쪽 주가 지난주가 된다.
    expect(_readout(tester), '11/2 ~ 11/8 · 1회');
  });

  testWidgets('막대 근처를 누르면 그 묶음 값이 읽힌다', (tester) async {
    await _pump(tester);
    final rect = tester.getRect(find.byKey(const Key('trend_canvas')));
    // 맨 오른쪽에서 두 번째 칸(지난주)을 누른다.
    final slot = (rect.width - 30 - 6) / 12;
    await tester.tapAt(Offset(rect.left + 30 + slot * 10.5, rect.center.dy));
    await tester.pump();
    expect(_readout(tester), '11/2 ~ 11/8 · 1회');
  });

  testWidgets('두 손가락이 닿으면 바깥 스크롤을 잠그고 떼면 푼다', (tester) async {
    final events = <bool>[];
    await _pump(tester, onMulti: events.add);
    await _pinch(tester, spread: true);
    await tester.pumpAndSettle();
    expect(events, [true, false]);
  });
}
