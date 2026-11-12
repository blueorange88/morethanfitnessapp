import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/training_log_pre_check.dart';

Future<void> _open(
  WidgetTester tester, {
  required TrainingLogPreCheckData data,
  Future<String?> Function()? onMeasureInbody,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 1400);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final painC = TextEditingController();
  final noteC = TextEditingController();
  await tester.pumpWidget(
    MaterialApp(
      home: StatefulBuilder(
        builder:
            (context, setState) => Scaffold(
              body: ListView(
                children: [
                  TrainingLogPreCheckCard(
                    data: data,
                    onEdit:
                        () => showTrainingLogPreCheckDialog(
                          context,
                          memberName: '지나',
                          data: data,
                          painDetailController: painC,
                          noteController: noteC,
                          issueOptions: const ['피로'],
                          onAddIssue: () async => null,
                          onMeasureInbody: onMeasureInbody,
                          onChanged: () => setState(() {}),
                        ),
                  ),
                ],
              ),
            ),
      ),
    ),
  );
  await tester.tap(find.byKey(const Key('pre_check_edit_button')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('회원이 없는 일지(콜백 없음)에는 인바디 측정 줄이 없다', (tester) async {
    await _open(tester, data: TrainingLogPreCheckData());
    expect(find.byKey(const Key('pre_inbody_row')), findsNothing);
  });

  testWidgets('인바디 측정 줄은 측정 전 안내와 측정하기 버튼을 보여준다', (tester) async {
    await _open(
      tester,
      data: TrainingLogPreCheckData(),
      onMeasureInbody: () async => null,
    );

    expect(find.byKey(const Key('pre_inbody_row')), findsOneWidget);
    expect(find.text('인바디 측정'), findsOneWidget);
    expect(find.text('이번 레슨에 측정하지 않았어요'), findsOneWidget);
    expect(find.text('측정하기'), findsOneWidget);
  });

  testWidgets('측정하기를 누르면 흐름을 열고 돌아온 요약을 줄과 카드에 보여준다', (tester) async {
    final data = TrainingLogPreCheckData();
    var calls = 0;
    await _open(
      tester,
      data: data,
      onMeasureInbody: () async {
        calls += 1;
        return '체중 62.3kg · 체지방률 23.4%';
      },
    );

    await tester.tap(find.byKey(const Key('pre_inbody_measure')));
    await tester.pumpAndSettle();

    expect(calls, 1);
    expect(data.inbodySummary, '체중 62.3kg · 체지방률 23.4%');
    expect(find.text('체중 62.3kg · 체지방률 23.4%'), findsOneWidget);
    expect(find.text('다시 측정'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pre_check_done')));
    await tester.pumpAndSettle();
    // 요약 카드에도 한 줄로 남는다.
    expect(find.text('인바디 체중 62.3kg · 체지방률 23.4%'), findsOneWidget);
  });

  testWidgets('측정을 취소하면 요약을 바꾸지 않는다', (tester) async {
    final data = TrainingLogPreCheckData(inbodySummary: '체중 60kg');
    await _open(tester, data: data, onMeasureInbody: () async => null);

    await tester.tap(find.byKey(const Key('pre_inbody_measure')));
    await tester.pumpAndSettle();

    expect(data.inbodySummary, '체중 60kg');
    expect(find.text('다시 측정'), findsOneWidget);
  });

  testWidgets('인바디 측정만으로는 확인 필요 개수가 늘지 않는다', (tester) async {
    final data = TrainingLogPreCheckData();
    await _open(tester, data: data, onMeasureInbody: () async => '체중 62kg');
    await tester.tap(find.byKey(const Key('pre_inbody_measure')));
    await tester.pumpAndSettle();

    expect(data.attentionCount, 0);
    expect(find.text('이상 없음 · 완료'), findsOneWidget);
  });
}
