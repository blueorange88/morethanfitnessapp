import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/personal_training_log_text_voice_page.dart';
import 'package:mtf_app/widgets/training_log_pre_check.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(
  WidgetTester tester, {
  bool? autoOpen,
  bool? confirmed,
  String? initialTitle,
  String? initialMemo,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 4000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: PersonalTrainingLogTextVoicePage(
        initialName: '테스트 회원',
        initialTitle: initialTitle,
        initialMemo: initialMemo,
        autoOpenPreCheck: autoOpen,
        initialPreCheckConfirmed: confirmed,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('텍스트·음성 레슨일지 구성', () {
    testWidgets('레슨 전 체크는 요약 카드이고 수업 중 체크·수업 체크사항은 없다', (tester) async {
      await _pump(tester, autoOpen: false);

      expect(find.byKey(const Key('pre_check_card')), findsOneWidget);
      expect(find.text('레슨 전 체크'), findsOneWidget);
      expect(find.text('수업 중 체크'), findsNothing);
      expect(find.text('수업 체크사항'), findsNothing);
      expect(find.text('종료 후 체크'), findsOneWidget);
      expect(find.text('내부 메모'), findsOneWidget);
      expect(find.text('회원 공개 메모'), findsOneWidget);
    });

    testWidgets('종료 후 체크에 숙제와 다음 수업 체크포인트가 모여 있다', (tester) async {
      await _pump(tester, autoOpen: false);

      expect(find.text('오늘 낸 숙제'), findsOneWidget);
      expect(find.text('지난 숙제 수행'), findsOneWidget);
      expect(find.text('다음 수업 체크포인트'), findsOneWidget);
    });

    testWidgets('새 일지에서 자동 열기를 켜면 레슨 전 체크리스트가 먼저 열린다', (tester) async {
      await _pump(tester, autoOpen: true);

      expect(find.text('테스트 회원님 레슨 전 체크리스트'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pre_check_done')));
      await tester.pumpAndSettle();
      expect(find.text('이상 없음'), findsOneWidget);
    });

    testWidgets('목록 화면에서 이미 체크했으면(확인됨) 다시 열지 않는다', (tester) async {
      await _pump(tester, autoOpen: true, confirmed: true);

      expect(find.text('테스트 회원님 레슨 전 체크리스트'), findsNothing);
      expect(find.text('이상 없음'), findsOneWidget);
    });

    testWidgets('목록 화면에서 나중에를 눌렀으면(확인 전) 카드에 아직 체크 안 함이 보인다', (tester) async {
      await _pump(tester, autoOpen: false, confirmed: false);

      expect(find.text('아직 체크 안 함'), findsOneWidget);
      expect(find.text('체크하기'), findsOneWidget);
    });

    testWidgets('저장된 일지를 다시 열 때는 열지 않는다', (tester) async {
      await _pump(
        tester,
        autoOpen: true,
        initialTitle: '하체운동',
        initialMemo: '운동 메모',
      );

      expect(find.text('테스트 회원님 레슨 전 체크리스트'), findsNothing);
      expect(find.text('이상 없음'), findsOneWidget);
    });
  });

  group('레슨일지 목록 화면 연결', () {
    final source =
        File('lib/pages/personal_training_log_page.dart').readAsStringSync();

    test('새 일지는 작성 방식을 고른 직후 방식과 상관없이 레슨 전 체크를 먼저 연다', () {
      expect(
        RegExp(
          r'log\.draftEntryMode = selected;\s*\}\);\s*'
          r'await _runPreCheckForNewLog\(log\);\s*if \(!mounted\) return;\s*'
          r"if \(selected == 'text' \|\| selected == 'category'\)",
        ).hasMatch(source),
        isTrue,
      );
    });

    test('체크를 완료하면 서버 초안에 저장하고 이미 작성 중이거나 확인한 일지는 건너뛴다', () {
      expect(
        RegExp(
          r'Future<void> _runPreCheckForNewLog[\s\S]*?'
          r'if \(!log\.isDraft \|\| log\.preCheckDone\) return;[\s\S]*?'
          r'if \(done\) await _persistPersonalLogDraft\(log\);',
        ).hasMatch(source),
        isTrue,
      );
    });

    test('에디터 두 곳은 목록 화면에서 이미 연 체크를 다시 열지 않는다', () {
      expect(
        RegExp(
          r'autoOpenPreCheck: false,[\s\S]{0,200}?'
          r'initialPreCheckConfirmed: log\.preCheckDone,',
        ).allMatches(source).length,
        2,
      );
    });

    test('체크만 저장된 초안은 작성 전 상태로 복원하고 체크 값만 되살린다', () {
      expect(source, contains("item.title = '레슨일지 작성 전';"));
      expect(source, contains('item.preCheckDone = hasPreCheck;'));
      expect(
        source,
        contains("'inputMethod': log.isDraft ? '' : log.inputMethod,"),
      );
    });
  });

  test('저장된 칩 중 자동으로 만들어지는 것은 직접 고른 칩에서 뺀다', () {
    final data = TrainingLogPreCheckData(pain: '있음', issueChips: {'통증', '피로'})
      ..dropImpliedAutoChips();
    expect(data.issueChips, {'피로'});
    expect(data.savedIssueChips.toSet(), {'피로', '통증'});

    // 통증이 없는데 옛 일지에 통증 칩이 있으면 값이 사라지지 않게 그대로 둔다.
    final legacy = TrainingLogPreCheckData(issueChips: {'통증'})
      ..dropImpliedAutoChips();
    expect(legacy.issueChips, {'통증'});
  });
}
