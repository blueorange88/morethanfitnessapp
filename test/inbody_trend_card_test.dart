import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/inbody_history.dart';
import 'package:mtf_app/widgets/inbody_trend_card.dart';

InbodyHistoryPoint _point(
  int month,
  int day, {
  double? weight,
  double? muscle,
  double? fat,
}) => InbodyHistoryPoint(
  measuredAt: DateTime(2026, month, day),
  weightKg: weight,
  skeletalMuscleKg: muscle,
  bodyFatPct: fat,
);

Future<void> _pump(
  WidgetTester tester,
  List<InbodyHistoryPoint> points,
  VoidCallback onMeasure,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: const Color(0xFF111827),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: InbodyTrendCard(points: points, onMeasure: onMeasure),
        ),
      ),
    ),
  );
}

void main() {
  group('인바디 이력 읽기', () {
    test('서버 이력을 측정일 순으로 읽고 값이 없는 항목은 비워 둔다', () {
      final points = parseInbodyHistory({
        'inbodyHistory': [
          {
            'measuredAt': Timestamp.fromDate(DateTime(2026, 10, 8)),
            'weightKg': 62.3,
            'bodyFatPct': 23.4,
            'source': 'scan',
          },
          {
            'measuredAt': Timestamp.fromDate(DateTime(2026, 9, 1)),
            'weightKg': 64,
            'skeletalMuscleKg': 24.8,
          },
        ],
      });

      expect(points.map((p) => inbodyDateText(p.measuredAt)), [
        '2026-09-01',
        '2026-10-08',
      ]);
      expect(points.first.skeletalMuscleKg, 24.8);
      expect(points.last.skeletalMuscleKg, isNull);
      expect(points.last.source, 'scan');
      expect(points.first.source, 'manual');
    });

    test('이력이 없으면 회원카드에 입력한 최신 값과 측정일을 한 건으로 본다', () {
      final points = parseInbodyHistory({
        'inbody': {'heightCm': 170, 'weightKg': 65.5},
        'inbodyMeasuredAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
      });

      expect(points, hasLength(1));
      expect(points.single.weightKg, 65.5);
      expect(inbodyDateText(points.single.measuredAt), '2026-10-01');
    });

    test('측정일이 없거나 값이 없거나 0인 항목은 이력으로 쓰지 않는다', () {
      expect(parseInbodyHistory(null), isEmpty);
      expect(
        parseInbodyHistory({
          'inbody': {'weightKg': 65},
        }),
        isEmpty,
      );
      expect(
        parseInbodyHistory({
          'inbodyHistory': [
            {
              'measuredAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
              'weightKg': 0,
            },
            'text',
          ],
        }),
        isEmpty,
      );
    });

    test('직전 측정과의 차이는 같은 항목이 있는 최근 두 값으로 계산한다', () {
      final points = [
        _point(8, 1, weight: 64),
        _point(9, 1, muscle: 24),
        _point(10, 1, weight: 62.5),
      ];
      expect(inbodyMetricChange(points, InbodyMetric.weight), -1.5);
      expect(inbodyMetricChange(points, InbodyMetric.skeletalMuscle), isNull);
    });
  });

  group('인바디 추이 카드', () {
    testWidgets('기록이 없으면 샘플 숫자 없이 안내와 입력 버튼만 보인다', (tester) async {
      var taps = 0;
      await _pump(tester, const [], () => taps++);

      expect(find.byKey(const Key('inbody_trend_empty')), findsOneWidget);
      expect(find.text('아직 인바디 기록이 없어요'), findsOneWidget);
      expect(find.byKey(const Key('inbody_trend_chart')), findsNothing);
      expect(find.text('31.5'), findsNothing);
      expect(find.byKey(const Key('inbody_trend_add')), findsNothing);

      await tester.tap(find.byKey(const Key('inbody_trend_cta')));
      expect(taps, 1);
    });

    testWidgets('기록이 있으면 최신 값·직전 대비 변화와 측정 추가 버튼을 보여준다', (tester) async {
      var taps = 0;
      await _pump(tester, [
        _point(9, 1, weight: 64, muscle: 24.0, fat: 25.0),
        _point(10, 1, weight: 62.5, muscle: 24.8, fat: 23.4),
      ], () => taps++);

      expect(find.text('62.5kg'), findsOneWidget);
      expect(find.text('-1.5kg'), findsOneWidget);
      expect(find.text('24.8kg'), findsOneWidget);
      expect(find.text('+0.8kg'), findsOneWidget);
      expect(find.text('23.4%'), findsOneWidget);
      expect(find.text('-1.6%'), findsOneWidget);
      expect(find.text('마지막 측정 2026-10-01 · 총 2건'), findsOneWidget);
      expect(find.byKey(const Key('inbody_trend_chart')), findsOneWidget);

      await tester.tap(find.byKey(const Key('inbody_trend_add')));
      expect(taps, 1);
    });

    testWidgets('기록이 한 건이면 그래프 대신 2건 이상 필요하다고 알려준다', (tester) async {
      await _pump(tester, [_point(10, 1, weight: 62.5)], () {});

      expect(find.byKey(const Key('inbody_trend_chart')), findsNothing);
      expect(find.byKey(const Key('inbody_trend_need_more')), findsOneWidget);
      expect(find.text('62.5kg'), findsOneWidget);
    });

    testWidgets('항목을 누르면 그 항목의 추이로 바뀐다', (tester) async {
      await _pump(tester, [
        _point(9, 1, weight: 64, muscle: 24.0),
        _point(10, 1, weight: 62.5),
      ], () {});
      // 체중은 두 건이라 그래프가 있고, 골격근량은 한 건이라 안내가 나온다.
      expect(find.byKey(const Key('inbody_trend_chart')), findsOneWidget);

      await tester.tap(find.byKey(const Key('inbody_metric_skeletalMuscle')));
      await tester.pump();

      expect(find.byKey(const Key('inbody_trend_chart')), findsNothing);
      expect(find.text('골격근량 기록이 2건 이상이면 추이를 볼 수 있어요'), findsOneWidget);
    });
  });

  group('레슨일지 헤더 연결', () {
    final page =
        File('lib/pages/personal_training_log_page.dart').readAsStringSync();

    test('가짜 샘플 추이는 없고 서버 이력을 읽어 추이 카드에 넘긴다', () {
      expect(page, isNot(contains('31.5, 31.9')));
      expect(page, isNot(contains('_inbodyTrend')));
      expect(page, contains('InbodyTrendCard(points: inbodyPoints'));
      expect(page, contains('inbodyPoints: _inbodyHistory,'));
      expect(
        page,
        contains('parseInbodyHistory(snapshot.data()?[\'health\'])'),
      );
    });

    test('헤더 아이콘과 추이 카드는 같은 입구(_openInbodyMeasure)를 쓴다', () {
      expect(page, contains('onInbodyTap: _openInbodyMeasure,'));
      expect(page, contains('onInbodyMeasure: onInbodyTap,'));
      expect(page, contains("tooltip: '인바디 입력'"));
    });

    test('개인 워크스페이스는 새 흐름, 기존 워크스페이스는 이전 흐름을 연다', () {
      expect(
        RegExp(
          r'Future<void> _openInbodyMeasure\(\) async \{[\s\S]*?'
          r'if \(!_isPersonalWorkspace \|\| memberId\.isEmpty\) \{\s*'
          r'await _showInbodyScanOptions\(\);',
        ).hasMatch(page),
        isTrue,
      );
    });

    test('체크리스트나 헤더에서 측정하면 이력을 다시 읽는다', () {
      expect(
        RegExp(
          r'if \(result != null\) await _loadInbodyHistory\(\);',
        ).allMatches(page).length,
        2,
      );
    });
  });
}
