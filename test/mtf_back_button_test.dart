import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/theme/app_colors.dart';
import 'package:mtf_app/widgets/mtf_back_button.dart';

void main() {
  group('MtfBackButton', () {
    testWidgets('원형 테두리 없이 `<`만 보이고 누르면 동작한다', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: Center(child: MtfBackButton(onTap: () => taps++)),
          ),
        ),
      );

      expect(find.text('<'), findsOneWidget);
      // 기준 디자인(내 회원 관리)의 글자 모양: 24, w500, 흰색.
      final text = tester.widget<Text>(find.text('<'));
      expect(text.style!.fontSize, 24);
      expect(text.style!.fontWeight, FontWeight.w500);
      expect(text.style!.color, Colors.white);
      // 원형 바탕·테두리(BoxDecoration)가 없다.
      expect(
        find.descendant(
          of: find.byType(MtfBackButton),
          matching: find.byWidgetPredicate(
            (w) => w is DecoratedBox || w is Container && w.decoration != null,
          ),
        ),
        findsNothing,
      );
      expect(tester.getSize(find.byType(MtfBackButton)), const Size(42, 42));

      await tester.tap(find.byType(MtfBackButton));
      expect(taps, 1);
    });

    testWidgets('색을 바꿀 수 있고 접근성 이름은 뒤로', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MtfBackButton(onTap: () {}, color: Colors.indigo),
          ),
        ),
      );
      expect(tester.widget<Text>(find.text('<')).style!.color, Colors.indigo);
      expect(find.bySemanticsLabel('뒤로'), findsOneWidget);
      handle.dispose();
    });
  });

  for (final entry in {'밝은 모드': lightTheme(), '어두운 모드': darkTheme()}.entries) {
    testWidgets('${entry.key}: 앱바를 쓰는 페이지의 기본 뒤로가기도 같은 `<` 모양이다', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: entry.value,
          home: Builder(
            builder:
                (context) => TextButton(
                  onPressed:
                      () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder:
                              (_) => Scaffold(
                                appBar: AppBar(title: const Text('설정')),
                              ),
                        ),
                      ),
                  child: const Text('열기'),
                ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();

      final glyph = tester.widget<Text>(
        find.descendant(of: find.byType(BackButton), matching: find.text('<')),
      );
      expect(glyph.style!.fontSize, 24);
      expect(glyph.style!.fontWeight, FontWeight.w500);
      // 앱바 글자색(밝은 배경은 어두운 색, 어두운 배경은 밝은 색)을 따른다.
      expect(glyph.style!.color, entry.value.appBarTheme.foregroundColor);
    });
  }

  test('커스텀 헤더 페이지들이 모두 공용 뒤로가기를 쓰고 옛 원형·화살표 뒤로가기는 남지 않는다', () {
    const headerFiles = [
      'lib/pages/client_list_page.dart',
      'lib/pages/stats_page.dart',
      'lib/pages/lesson_contract/lesson_contract_widgets.dart',
      'lib/pages/lesson_type_management_page.dart',
      'lib/pages/more_care_admin_page.dart',
      'lib/pages/notification_settings_page.dart',
      'lib/pages/settings_page.dart',
      'lib/pages/widget_settings_page.dart',
      'lib/pages/personal_member_taxonomy_management_page.dart',
      'lib/pages/personal_training_log_quick_sign_page.dart',
      'lib/pages/contract_list_page.dart',
      'lib/pages/contract_page.dart',
      'lib/pages/my_page.dart',
      'lib/pages/personal_training_log_anatomy/widgets/anatomy_header.dart',
      'lib/pages/personal_training_log_category_page.dart',
      'lib/pages/personal_training_log_text_voice_page.dart',
      'lib/pages/personal_training_log_page.dart',
      'lib/pages/binder_card_page.dart',
      'lib/pages/client_card_page.dart',
    ];
    for (final path in headerFiles) {
      final source = File(path).readAsStringSync();
      expect(source, contains('MtfBackButton('), reason: path);
    }
    // 앱바 헤더의 뒤로가기 화살표 아이콘은 이 파일들에서 사라졌다(버튼 안의 화살표 등은 예외).
    for (final path in [
      'lib/pages/lesson_contract/lesson_contract_widgets.dart',
      'lib/pages/settings_page.dart',
      'lib/pages/widget_settings_page.dart',
      'lib/pages/notification_settings_page.dart',
      'lib/pages/more_care_admin_page.dart',
      'lib/pages/lesson_type_management_page.dart',
      'lib/pages/contract_list_page.dart',
      'lib/pages/stats_page.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('Icons.arrow_back')),
        reason: path,
      );
    }
  });

  test('인사이트 헤더는 내 회원 관리 헤더와 같은 그라데이션을 쓴다', () {
    final stats = File('lib/pages/stats_page.dart').readAsStringSync();
    final start = stats.indexOf('class _StatsHeader');
    final end = stats.indexOf('class _DashboardCard', start);
    final header = stats.substring(start, end);
    expect(header, contains('context.mtfHeaderGradient'));
    expect(header, isNot(contains('drawerHeaderBackground')));
    expect(header, contains('MtfHeaderNeonOverlay('));

    final list = File('lib/pages/client_list_page.dart').readAsStringSync();
    expect(list, contains('context.mtfHeaderGradient'));
  });
}
