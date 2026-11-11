import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/personal_training_log_category_page.dart';
import 'package:mtf_app/pages/personal_training_log_text_voice_page.dart';
import 'package:mtf_app/widgets/leave_draft_guard.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 런처 화면에서 [pageBuilder] 화면을 열고, 닫힌 뒤 돌려받은 값을 모아서 돌려준다.
Future<List<Object?>> _openFromLauncher(
  WidgetTester tester,
  Widget Function() pageBuilder,
) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 4000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final results = <Object?>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder:
            (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    results.add(
                      await Navigator.of(context).push<Object?>(
                        MaterialPageRoute<Object?>(
                          builder: (_) => pageBuilder(),
                        ),
                      ),
                    );
                  },
                  child: const Text('열기'),
                ),
              ),
            ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  await tester.pumpAndSettle();
  return results;
}

Future<void> _back(WidgetTester tester) async {
  final navigator = tester.state<NavigatorState>(find.byType(Navigator));
  await navigator.maybePop();
  await tester.pumpAndSettle();
}

Finder get _dialog => find.byKey(const ValueKey<String>('leave_draft_dialog'));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('LeaveDraftGuard', () {
    Widget guarded({required bool dirty, required VoidCallback onSave}) {
      return LeaveDraftGuard(
        isDirty: () => dirty,
        onSave: onSave,
        child: const Scaffold(body: Text('작성 화면')),
      );
    }

    testWidgets('바뀐 내용이 없으면 확인창 없이 바로 나간다', (tester) async {
      final results = await _openFromLauncher(
        tester,
        () => guarded(dirty: false, onSave: () {}),
      );
      await _back(tester);
      expect(_dialog, findsNothing);
      expect(find.text('열기'), findsOneWidget);
      expect(results, [null]);
    });

    testWidgets('저장하지 않은 내용이 있으면 계속 작성·삭제·저장 세 가지를 묻는다', (tester) async {
      await _openFromLauncher(
        tester,
        () => guarded(dirty: true, onSave: () {}),
      );
      await _back(tester);
      expect(_dialog, findsOneWidget);
      expect(find.text('작성 중인 레슨일지가 있어요'), findsOneWidget);
      expect(find.text('계속 작성'), findsOneWidget);
      expect(find.text('삭제하고 나가기'), findsOneWidget);
      expect(find.text('저장하고 나가기'), findsOneWidget);
    });

    testWidgets('계속 작성을 고르면 화면에 남는다', (tester) async {
      await _openFromLauncher(
        tester,
        () => guarded(dirty: true, onSave: () {}),
      );
      await _back(tester);
      await tester.tap(find.byKey(const ValueKey<String>('leave_draft_stay')));
      await tester.pumpAndSettle();
      expect(_dialog, findsNothing);
      expect(find.text('작성 화면'), findsOneWidget);
    });

    testWidgets('창 밖을 눌러 닫아도 화면에 남는다', (tester) async {
      await _openFromLauncher(
        tester,
        () => guarded(dirty: true, onSave: () {}),
      );
      await _back(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.text('작성 화면'), findsOneWidget);
    });

    testWidgets('삭제하고 나가기를 고르면 저장 없이 나간다', (tester) async {
      var saved = 0;
      final results = await _openFromLauncher(
        tester,
        () => guarded(dirty: true, onSave: () => saved++),
      );
      await _back(tester);
      await tester.tap(
        find.byKey(const ValueKey<String>('leave_draft_discard')),
      );
      await tester.pumpAndSettle();
      expect(find.text('열기'), findsOneWidget);
      expect(saved, 0);
      expect(results, [null]);
    });

    testWidgets('저장하고 나가기를 고르면 저장 함수를 부른다', (tester) async {
      var saved = 0;
      await _openFromLauncher(
        tester,
        () => guarded(dirty: true, onSave: () => saved++),
      );
      await _back(tester);
      await tester.tap(find.byKey(const ValueKey<String>('leave_draft_save')));
      await tester.pumpAndSettle();
      expect(saved, 1);
    });
  });

  group('텍스트·음성 레슨일지 편집 화면', () {
    Widget page() => const PersonalTrainingLogTextVoicePage(
      initialName: '테스트 회원',
      autoOpenPreCheck: false,
    );

    testWidgets('아무것도 바꾸지 않았으면 바로 나간다', (tester) async {
      await _openFromLauncher(tester, page);
      await _back(tester);
      expect(_dialog, findsNothing);
      expect(find.text('열기'), findsOneWidget);
    });

    testWidgets('제목을 쓰고 나가려 하면 확인하고, 삭제하면 값 없이 돌아간다', (tester) async {
      final results = await _openFromLauncher(tester, page);
      await tester.enterText(find.byType(TextField).first, '하체 운동');
      await tester.pump();
      await _back(tester);
      expect(_dialog, findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('leave_draft_discard')),
      );
      await tester.pumpAndSettle();
      expect(find.text('열기'), findsOneWidget);
      expect(results, [null]);
    });

    testWidgets('저장하고 나가기를 고르면 쓴 내용을 돌려준다', (tester) async {
      final results = await _openFromLauncher(tester, page);
      await tester.enterText(find.byType(TextField).first, '하체 운동');
      await tester.pump();
      await _back(tester);
      await tester.tap(find.byKey(const ValueKey<String>('leave_draft_save')));
      await tester.pumpAndSettle();
      expect(find.text('열기'), findsOneWidget);
      expect(results.single, isA<Map<String, dynamic>>());
      expect((results.single! as Map<String, dynamic>)['title'], '하체 운동');
    });
  });

  group('카테고리 레슨일지 편집 화면', () {
    Widget page() => const PersonalTrainingLogCategoryPage(
      initialName: '테스트 회원',
      autoOpenPreCheck: false,
    );

    testWidgets('아무것도 바꾸지 않았으면 바로 나간다', (tester) async {
      await _openFromLauncher(tester, page);
      await _back(tester);
      expect(_dialog, findsNothing);
      expect(find.text('열기'), findsOneWidget);
    });

    testWidgets('제목을 쓰고 나가려 하면 확인한다', (tester) async {
      final results = await _openFromLauncher(tester, page);
      await tester.enterText(find.byType(TextField).first, '하체 운동');
      await tester.pump();
      await _back(tester);
      expect(_dialog, findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('leave_draft_discard')),
      );
      await tester.pumpAndSettle();
      expect(find.text('열기'), findsOneWidget);
      expect(results, [null]);
    });
  });
}
