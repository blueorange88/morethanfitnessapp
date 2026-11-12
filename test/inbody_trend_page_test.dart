import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/inbody_trend_page.dart';
import 'package:mtf_app/services/inbody_history.dart';
import 'package:mtf_app/widgets/inbody_trend_card.dart';
import 'package:mtf_app/widgets/inbody_trend_chart.dart';

List<InbodyHistoryPoint> _points() => [
  for (var i = 0; i < 12; i++)
    InbodyHistoryPoint(
      measuredAt: DateTime(2026, 1 + i ~/ 1, 5),
      weightKg: 70.0 - i * 0.5,
      skeletalMuscleKg: 30.0 + i * 0.1,
    ),
];

String _rangeText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('inbody_page_range_text'))).data!;

void main() {
  group('InbodyChartViewport', () {
    final dates = [DateTime(2026, 1, 1), DateTime(2026, 7, 1)];

    test('전체 기간은 기록 앞뒤로 여유를 둔다', () {
      final vp = InbodyChartViewport.full(dates);
      expect(vp.startMs, lessThan(dates.first.millisecondsSinceEpoch));
      expect(vp.endMs, greaterThan(dates.last.millisecondsSinceEpoch));
      expect(vp.isFull, isTrue);
    });

    test('줌인하면 기간이 줄고, 손가락 아래 시각은 그대로 있다', () {
      final vp = InbodyChartViewport.full(dates);
      final anchor = vp.startMs + 0.5 * vp.span;
      final zoomed = vp.scaledAround(
        scale: 2,
        anchorFraction: 0.5,
        targetFraction: 0.5,
      );
      expect(zoomed.span, closeTo(vp.span / 2, 1));
      expect(zoomed.startMs + 0.5 * zoomed.span, closeTo(anchor, 1));
      expect(zoomed.isFull, isFalse);
    });

    test('가장 가깝게는 7일, 가장 멀게는 전체까지만 줌한다', () {
      final vp = InbodyChartViewport.full(dates);
      final tight = vp.scaledAround(
        scale: 1000,
        anchorFraction: 0.5,
        targetFraction: 0.5,
      );
      expect(tight.span, closeTo(7 * 24 * 60 * 60 * 1000, 1));
      final wide = tight.scaledAround(
        scale: 0.0001,
        anchorFraction: 0.5,
        targetFraction: 0.5,
      );
      expect(wide.span, closeTo(vp.fullSpan, 1));
    });

    test('옮겨도 기록 범위 밖으로 나가지 않는다', () {
      final vp = InbodyChartViewport.full(dates).lastDays(30);
      final moved = vp.scaledAround(
        scale: 1,
        anchorFraction: 0.5,
        targetFraction: 5, // 한참 오른쪽으로 끌었다
      );
      expect(moved.startMs, greaterThanOrEqualTo(vp.minMs));
      expect(moved.endMs, lessThanOrEqualTo(vp.maxMs));
    });

    test('기록이 한 건이면 앞뒤 15일을 보여 준다', () {
      final vp = InbodyChartViewport.full([DateTime(2026, 5, 1)]);
      expect(vp.fullSpan, closeTo(30 * 24 * 60 * 60 * 1000, 1));
    });

    test('lastDays는 기록이 더 짧으면 전체를 보여 준다', () {
      final vp = InbodyChartViewport.full(dates);
      expect(vp.lastDays(3650).isFull, isTrue);
      expect(vp.lastDays(30).span, closeTo(30 * 24 * 60 * 60 * 1000, 1));
    });
  });

  group('InbodyTrendPage', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(home: InbodyTrendPage(points: _points())),
      );
    }

    testWidgets('처음에는 전체 기간이고 마지막 측정값이 보인다', (tester) async {
      await pump(tester);
      expect(
        tester.widget<Text>(find.byKey(const Key('inbody_page_readout'))).data,
        contains('2026-12-05 · 64.5kg'),
      );
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('inbody_page_range_3')))
            .selected,
        isTrue,
      );
    });

    testWidgets('기간 칩을 누르면 보이는 기간이 바뀐다', (tester) async {
      await pump(tester);
      final before = _rangeText(tester);
      await tester.tap(find.byKey(const Key('inbody_page_range_0')));
      await tester.pump();
      expect(_rangeText(tester), isNot(before));
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const Key('inbody_page_range_0')))
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('inbody_page_range_3')));
      await tester.pump();
      expect(_rangeText(tester), before);
    });

    testWidgets('두 손가락을 벌리면 기간이 줄어든다', (tester) async {
      await pump(tester);
      final before = _rangeText(tester);
      final center = tester.getCenter(
        find.byKey(const Key('inbody_chart_canvas')),
      );
      final a = await tester.startGesture(
        center - const Offset(20, 0),
        pointer: 1,
      );
      final b = await tester.startGesture(
        center + const Offset(20, 0),
        pointer: 2,
      );
      await tester.pump();
      await a.moveTo(center - const Offset(120, 0));
      await b.moveTo(center + const Offset(120, 0));
      await tester.pump();
      await a.up();
      await b.up();
      await tester.pump();
      expect(_rangeText(tester), isNot(before));
      // 어느 기간 칩도 선택되어 있지 않다(손으로 줌한 상태).
      for (var i = 0; i < 4; i++) {
        expect(
          tester
              .widget<ChoiceChip>(find.byKey(Key('inbody_page_range_$i')))
              .selected,
          isFalse,
        );
      }
    });

    testWidgets('지표를 바꾸면 그 지표 값이 보인다', (tester) async {
      await pump(tester);
      await tester.tap(
        find.byKey(const Key('inbody_page_metric_skeletalMuscle')),
      );
      await tester.pump();
      expect(
        tester.widget<Text>(find.byKey(const Key('inbody_page_readout'))).data,
        contains('31.1kg'),
      );
    });

    testWidgets('기록이 한 건뿐인 지표는 안내만 보인다', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: InbodyTrendPage(
            points: [
              InbodyHistoryPoint(
                measuredAt: DateTime(2026, 5, 1),
                weightKg: 60,
              ),
            ],
          ),
        ),
      );
      expect(find.byKey(const Key('inbody_page_need_more')), findsOneWidget);
    });
  });

  group('인바디 카드에서 큰 화면 열기', () {
    testWidgets('크게 보기를 누르면 큰 차트 화면이 열린다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InbodyTrendCard(points: _points(), onMeasure: () {}),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('inbody_trend_expand')));
      await tester.pumpAndSettle();
      expect(find.byType(InbodyTrendPage), findsOneWidget);
    });

    testWidgets('작은 차트를 눌러도 열린다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: InbodyTrendCard(points: _points(), onMeasure: () {}),
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('inbody_trend_chart')));
      await tester.pumpAndSettle();
      expect(find.byType(InbodyTrendPage), findsOneWidget);
    });
  });
}
