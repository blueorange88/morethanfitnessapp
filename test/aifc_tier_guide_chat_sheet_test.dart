import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/aifc_tier_guide_chat_sheet.dart';

Widget _subject({required double width, required double scale}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, 800),
        textScaler: TextScaler.linear(scale),
      ),
      child: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: 800,
            child: const AifcTierGuideChatSheet(
              trainerName: '라디오',
              currentTierName: 'Beginner',
              nextTierName: 'Amateur',
              memberCount: 0,
              lessonCount: 8,
              hasProduct: false,
              trainerInfoDone: false,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('등급 선택은 말풍선을 누적하지 않고 상세 하나를 교체한다', (tester) async {
    await tester.pumpWidget(_subject(width: 360, scale: 1));
    await tester.pumpAndSettle();

    expect(find.text('레슨 일정'), findsOneWidget);
    expect(find.text('8 / 10'), findsOneWidget);
    await tester.tap(find.text('Amateur').first);
    await tester.pumpAndSettle();

    expect(find.text('고객카드와 회원관리'), findsOneWidget);
    expect(find.textContaining('등급 볼게요'), findsNothing);
    expect(find.textContaining('Amateur는 고객카드'), findsOneWidget);
  });

  for (final width in <double>[320, 360, 412, 480]) {
    for (final scale in <double>[1, 1.3, 1.8]) {
      testWidgets('$width dp / textScale $scale에서 overflow가 없다',
          (tester) async {
        await tester.pumpWidget(_subject(width: width, scale: scale));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Amateur').first);
        await tester.tap(find.text('Amateur').first);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('선생님 정보 입력 완료'), findsOneWidget);
      });
    }
  }
}
