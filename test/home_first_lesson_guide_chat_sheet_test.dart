import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/home/sections/home_first_lesson_guide_chat_sheet.dart';

void main() {
  testWidgets('첫 레슨 안내는 공용 AI FC 대화 흐름에 선택을 남긴다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => HomeFirstLessonGuideChatSheet.show(
                context: context,
                canCreateCustomerCard: false,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('첫 레슨을 등록했어요'), findsOneWidget);
    expect(find.text('사용방법 보기'), findsOneWidget);

    await tester.tap(find.text('사용방법 보기'));
    await tester.pumpAndSettle();
    expect(find.text('사용방법 보기'), findsWidgets);
    expect(find.textContaining('일정표에서 레슨을 눌러'), findsOneWidget);
  });

  testWidgets('Beginner 고객카드 선택은 Amateur 조건을 안내한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => HomeFirstLessonGuideChatSheet.show(
                context: context,
                canCreateCustomerCard: false,
              ),
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('고객카드 등록 알아보기'));
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.textContaining('Amateur부터 사용할 수 있어요'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
