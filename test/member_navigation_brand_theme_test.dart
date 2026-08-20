import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/theme.dart';
import 'package:mtf_app/widgets/home/sections/home_bottom_nav_bar.dart';
import 'package:mtf_app/widgets/mtf_floating_more_menu.dart';

void main() {
  test('회원관리 목록은 owner-scoped query와 브랜드 토큰을 유지한다', () {
    final source = File('lib/pages/client_list_page.dart').readAsStringSync();

    expect(source, contains(".where('trainerId', isEqualTo: owner)"));
    expect(
      source,
      contains(".where('workspaceType', isEqualTo: 'personal')"),
    );
    expect(source, contains('memberListBackground'));
    expect(source, contains('tokens.memberListCard'));
    expect(source, contains('tokens.memberListCardBorder'));
    expect(source, contains('tokens.dialogBackground'));
    expect(source, contains('_memberGroupMenuItemColor'));
    expect(source, contains('colorScheme.onSurfaceVariant'));
    expect(source, contains('onTap: () {'));
    expect(source, contains('onEditTap();'));
  });

  test('member detail entry surfaces use themed colors', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();
    final sectionCardSource = source.substring(
      source.indexOf('class _ExpandableSectionCard'),
      source.indexOf('class _HeaderMiniStat'),
    );
    final bottomActionSource = source.substring(
      source.indexOf('class _ClientCardBottomActionButton'),
      source.indexOf('class _KoreaPhoneTextInputFormatter'),
    );

    expect(sectionCardSource, contains('themeTokens.cardSurface'));
    expect(sectionCardSource, contains('themeTokens.cardBorder'));
    expect(sectionCardSource, contains('colorScheme.onSurface'));
    expect(sectionCardSource, isNot(contains('color: Colors.white')));
    expect(bottomActionSource, contains('themeTokens.cardSurface'));
    expect(bottomActionSource, contains('colorScheme.secondary'));
    expect(bottomActionSource, contains('colorScheme.onSecondary'));
    expect(bottomActionSource, isNot(contains(': Colors.white')));
  });

  for (final entry in <(String, ThemeData, Color, Color)>[
    (
      '라이트',
      lightTheme(),
      AppColors.lightSurface,
      const Color(0xFFFFF1C2),
    ),
    (
      '다크',
      darkTheme(),
      AppColors.darkDialogSurface,
      const Color(0xFF4A401F),
    ),
  ]) {
    testWidgets('${entry.$1} 홈 메뉴가 브랜드 surface와 선택 배경을 사용한다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: entry.$2,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topRight,
              child: MtfFloatingMoreMenuButton<String>(
                iconColor: entry.$2.colorScheme.onSurface,
                items: const [
                  MtfMoreMenuItem(
                    value: 'selected',
                    icon: Icons.home_rounded,
                    label: '선택 메뉴',
                    isSelected: true,
                  ),
                  MtfMoreMenuItem(
                    value: 'normal',
                    icon: Icons.settings_rounded,
                    label: '일반 메뉴',
                  ),
                ],
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(_hasContainerColor(tester, entry.$3), isTrue);
      expect(_hasContainerColor(tester, entry.$4), isTrue);
      expect(find.text('선택 메뉴'), findsOneWidget);
      expect(find.text('일반 메뉴'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('홈 하단 내비게이션은 기존 탭 동작을 유지한다', (tester) async {
    var selected = -1;
    var centerTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme(),
        home: Scaffold(
          body: HomeBottomNavBar(
            activeIndex: 3,
            primaryColor: AppColors.warmYellow,
            secondaryColor: const Color(0xFF4A401F),
            onChanged: (value) => selected = value,
            onCenterTap: () => centerTapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('고객리스트'));
    expect(selected, 3);

    await tester.tap(find.byIcon(Icons.person_add_alt_1));
    expect(centerTapped, isTrue);
    expect(tester.takeException(), isNull);
  });
}

bool _hasContainerColor(WidgetTester tester, Color color) {
  return tester.widgetList<Container>(find.byType(Container)).any((container) {
    final decoration = container.decoration;
    return decoration is BoxDecoration && decoration.color == color;
  });
}
