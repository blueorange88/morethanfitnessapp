import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/theme.dart';
import 'package:mtf_app/widgets/aifc_account_link_required_chat_sheet.dart';

void main() {
  final themes = <String, ThemeData>{
    'light': lightTheme(),
    'dark': darkTheme(),
    'lululala': lululalaTheme(),
  };

  for (final entry in themes.entries) {
    for (final width in const [320.0, 360.0, 384.0, 411.0]) {
      testWidgets('${entry.key} ${width.toInt()}dp에서 계정 연결 안내가 넘치지 않는다', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(Size(width, 760));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: entry.value,
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: TextButton(
                      onPressed:
                          () => AifcAccountLinkRequiredChatSheet.show(
                            context: context,
                            nickname: '강사',
                          ),
                      child: const Text('열기'),
                    ),
                  ),
            ),
          ),
        );

        await tester.tap(find.text('열기'));
        await tester.pumpAndSettle();
        expect(
          find.text(AifcAccountLinkRequiredChatSheet.title),
          findsOneWidget,
        );
        expect(
          find.text(AifcAccountLinkRequiredChatSheet.message),
          findsOneWidget,
        );
        expect(find.text('계정 연결하기'), findsOneWidget);
        expect(find.text('나중에'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('나중에는 시트만 닫고 연결 완료 안내는 명시적 회원 저장을 요구한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Column(
                  children: [
                    TextButton(
                      onPressed:
                          () => AifcAccountLinkRequiredChatSheet.show(
                            context: context,
                            nickname: '강사',
                          ),
                      child: const Text('연결 안내'),
                    ),
                    TextButton(
                      onPressed:
                          () => AifcAccountLinkRequiredChatSheet.showLinked(
                            context: context,
                            nickname: '강사',
                          ),
                      child: const Text('연결 완료'),
                    ),
                  ],
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('연결 안내'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('나중에').first);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text(AifcAccountLinkRequiredChatSheet.title), findsNothing);

    await tester.tap(find.text('연결 완료'));
    await tester.pumpAndSettle();
    expect(find.text('연결됐어요 🙌'), findsOneWidget);
    expect(find.text('입력 화면으로 돌아가기'), findsOneWidget);
    expect(find.textContaining('입력하신 내용도 그대로'), findsOneWidget);
    expect(find.textContaining('회원 저장을 다시 눌러주세요'), findsOneWidget);
  });
}
