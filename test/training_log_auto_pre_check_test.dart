import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/personal_training_log_category_page.dart';
import 'package:mtf_app/services/training_log_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pump(
  WidgetTester tester, {
  bool? autoOpen,
  String? initialTitle,
  String? initialMemo,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(400, 1100);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: PersonalTrainingLogCategoryPage(
        initialName: '테스트 회원',
        initialTitle: initialTitle,
        initialMemo: initialMemo,
        autoOpenPreCheck: autoOpen,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('시작 전 체크 자동 열기', () {
    testWidgets('새 레슨일지는 시작 전 체크 창이 먼저 열리고 완료하면 확인 상태가 된다', (tester) async {
      await _pump(tester, autoOpen: true);

      expect(find.text('마지막 식사'), findsOneWidget);
      await tester.tap(find.byKey(const Key('pre_check_done')));
      await tester.pumpAndSettle();

      expect(find.text('마지막 식사'), findsNothing);
      expect(find.text('이상 없음'), findsOneWidget);
      expect(find.text('수정하기'), findsOneWidget);
    });

    testWidgets('완료 없이 닫으면 아직 체크 안 함으로 남고 카드에서 다시 열 수 있다', (tester) async {
      await _pump(tester, autoOpen: true);

      await tester.tapAt(const Offset(200, 20));
      await tester.pumpAndSettle();

      expect(find.text('마지막 식사'), findsNothing);
      expect(find.text('아직 체크 안 함'), findsOneWidget);
      expect(find.text('체크하기'), findsOneWidget);

      await tester.tap(find.byKey(const Key('pre_check_edit_button')));
      await tester.pumpAndSettle();
      expect(find.text('마지막 식사'), findsOneWidget);
    });

    testWidgets('저장된 일지를 다시 열 때는 자동으로 열지 않고 확인한 것으로 본다', (tester) async {
      await _pump(
        tester,
        autoOpen: true,
        initialTitle: '하체운동',
        initialMemo: '운동유형: 웨이트 트레이닝',
      );

      expect(find.text('마지막 식사'), findsNothing);
      expect(find.text('아직 체크 안 함'), findsNothing);
      expect(find.text('이상 없음'), findsOneWidget);
    });

    testWidgets('설정이 꺼져 있으면 열지 않고 카드에 아직 체크 안 함이 보인다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'training_log_auto_pre_check_local': false,
      });
      await _pump(tester); // autoOpenPreCheck null → 설정을 따른다

      expect(find.text('마지막 식사'), findsNothing);
      expect(find.text('아직 체크 안 함'), findsOneWidget);
    });

    testWidgets('설정이 없으면 기본은 켜짐이라 새 일지에서 열린다', (tester) async {
      await _pump(tester); // 설정 없음 → 기본 켜짐

      expect(find.text('마지막 식사'), findsOneWidget);
    });
  });

  group('레슨일지 설정 저장', () {
    test('기본은 켜짐이고 계정별로 따로 저장된다', () async {
      expect(await TrainingLogPreferences.autoOpenPreCheck('uid-a'), isTrue);

      await TrainingLogPreferences.setAutoOpenPreCheck('uid-a', false);
      expect(await TrainingLogPreferences.autoOpenPreCheck('uid-a'), isFalse);
      expect(await TrainingLogPreferences.autoOpenPreCheck('uid-b'), isTrue);
      expect(await TrainingLogPreferences.autoOpenPreCheck(''), isTrue);

      await TrainingLogPreferences.setAutoOpenPreCheck('uid-a', true);
      expect(await TrainingLogPreferences.autoOpenPreCheck('uid-a'), isTrue);
    });
  });
}
