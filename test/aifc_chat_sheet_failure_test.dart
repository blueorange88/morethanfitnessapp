import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/aifc/core/aifc_chat_sheet.dart';
import 'package:mtf_app/theme/app_colors.dart';
import 'package:mtf_app/widgets/aifc_quick_register_chat_sheet.dart';

void main() {
  testWidgets('AIFC 저장 실패는 값을 반환하지 않고 입력을 유지해 재시도한다', (tester) async {
    var attempts = 0;
    String? result = 'not-completed';

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await AifcChatSheet.show(
                  context: context,
                  question: '기본 그룹 이름을 알려주세요.',
                  inputLabel: '그룹 이름',
                  onSave: (value) async {
                    attempts += 1;
                    if (attempts == 1) {
                      throw StateError('save_failed');
                    }
                    return '$value 저장 완료';
                  },
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'DEV GROUP TEST');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();

    expect(find.textContaining('저장하지 못했어요'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'DEV GROUP TEST',
    );
    expect(result, 'not-completed');

    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(result, 'DEV GROUP TEST');
    expect(find.byType(AifcChatSheet), findsNothing);
  });

  testWidgets('AIFC 저장 실패 시 자동 종료되지 않고 명시적 나중에만 닫힌다', (tester) async {
    String? result = 'not-completed';

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                result = await AifcChatSheet.show(
                  context: context,
                  question: '회원권 기간을 알려주세요.',
                  inputLabel: '예: 120일',
                  onSave: (_) async => throw StateError('save_failed'),
                  onSkip: () {},
                  skipLabel: '나중에',
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '120일');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(seconds: 5));

    expect(find.byType(AifcChatSheet), findsOneWidget);
    expect(find.textContaining('저장하지 못했어요'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '120일',
    );
    expect(result, 'not-completed');

    await tester.tap(find.text('나중에'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 850));
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(find.byType(AifcChatSheet), findsNothing);
    expect(result, isNull);
  });

  testWidgets('빠른등록은 canonical 저장 실패 시 입력과 시트를 유지하고 재시도한다', (tester) async {
    var attempts = 0;
    String? completedName;

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () async {
                final result = await AifcQuickRegisterChatSheet.show(
                  context: context,
                  nickname: '테스트 강사',
                  onFastSave: (value) async {
                    attempts += 1;
                    if (attempts == 1) {
                      throw StateError('unavailable');
                    }
                    completedName = value.name;
                  },
                );
                if (result?.goDetail == true) {
                  completedName = 'unexpected-detail';
                }
              },
              child: const Text('빠른등록 열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('빠른등록 열기'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'DEV QUICK RETRY');
    await tester.enterText(fields.at(1), '01012345678');
    await tester.ensureVisible(find.text('빠른등록'));
    await tester.tap(find.text('빠른등록'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();

    expect(attempts, 1);
    expect(find.byType(AifcQuickRegisterChatSheet), findsOneWidget);
    expect(find.textContaining('입력한 내용은 그대로 유지'), findsOneWidget);
    expect(tester.widget<TextField>(fields.at(0)).controller!.text,
        'DEV QUICK RETRY');
    expect(
        tester.widget<TextField>(fields.at(1)).controller!.text, '01012345678');
    expect(completedName, isNull);

    await tester.ensureVisible(find.text('빠른등록'));
    await tester.tap(find.text('빠른등록'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump(const Duration(milliseconds: 1300));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(completedName, 'DEV QUICK RETRY');
    expect(find.byType(AifcQuickRegisterChatSheet), findsNothing);
  });

  testWidgets('빠른등록 계정 제한은 입력을 유지하고 같은 시트에서 연결 창을 연다', (tester) async {
    var linkAttempts = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => AifcQuickRegisterChatSheet.show(
                context: context,
                nickname: '테스트 강사',
                onFastSave: (_) async {
                  throw FirebaseFunctionsException(
                    code: 'failed-precondition',
                    message: 'account_link_required',
                  );
                },
                onAccountLink: () async {
                  linkAttempts += 1;
                  return true;
                },
              ),
              child: const Text('빠른등록 열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('빠른등록 열기'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'DEV ACCOUNT LINK');
    await tester.enterText(fields.at(1), '01012345678');
    await tester.ensureVisible(find.text('빠른등록'));
    await tester.tap(find.text('빠른등록'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();

    expect(find.text('계정 연결하기'), findsOneWidget);
    expect(
      tester.widget<TextField>(fields.at(0)).controller!.text,
      'DEV ACCOUNT LINK',
    );
    expect(
      tester.widget<TextField>(fields.at(1)).controller!.text,
      '01012345678',
    );

    await tester.tap(find.text('계정 연결하기'));
    await tester.pumpAndSettle();

    expect(linkAttempts, 1);
    expect(find.textContaining('계정이 연결됐어요'), findsOneWidget);
    expect(find.byType(AifcQuickRegisterChatSheet), findsOneWidget);
    expect(
      tester.widget<TextField>(fields.at(0)).controller!.text,
      'DEV ACCOUNT LINK',
    );
  });
}
