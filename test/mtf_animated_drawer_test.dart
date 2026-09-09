import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/mtf_animated_drawer.dart';
import 'package:mtf_app/widgets/premium_banner_widget.dart';
import 'package:mtf_app/theme.dart';

void main() {
  final source =
      File('lib/widgets/mtf_animated_drawer.dart').readAsStringSync();

  test('주요 메뉴는 회원권계약서와 같은 고정형 운영 설명을 사용한다', () {
    expect(source, contains("sub: '회원 정보 확인 및 관리 지원'"));
    expect(source, contains("sub: '레슨 계약서 작성 및 운영 지원'"));
    expect(source, contains("sub: '회원권 계약서 작성 및 운영 지원'"));
    expect(source, contains("sub: '레슨 및 회원 운영 분석 지원'"));
    expect(source, isNot(contains('mtfDrawerFeatureSubtitle')));
    expect(source, isNot(contains('회원 정보를 확인하고 관리해요.')));
    expect(source, isNot(contains('회원별 레슨계약서를 작성하고 확인해요.')));
    expect(source, isNot(contains('레슨과 회원 흐름을 확인해요.')));
  });

  test('Drawer 기본 전환 위에 중복 전체 패널 애니메이션을 두지 않는다', () {
    expect(source, isNot(contains('_slideCtrl')));
    expect(source, isNot(contains('_slideAnim')));
    expect(source, isNot(contains('_livePulseCtrl')));
    expect(source, isNot(contains('_contentCtrl')));
    expect(source, contains('AlwaysStoppedAnimation<double>(1)'));
    expect(source, contains('child: _buildBody()'));
    expect(source, contains('builder: (context, child)'));
    expect(source, contains('duration: const Duration(milliseconds: 300)'));
    expect(source, contains('MORE WELLNESS 회원관리'));
  });

  test('회원권계약서 메뉴는 고정된 운영 지원 설명을 사용한다', () {
    expect(source, contains("sub: '회원권 계약서 작성 및 운영 지원'"));
    expect(source, isNot(contains('회원권계약서를 작성하고 확인해요.')));
  });

  for (final entry in <(String, ThemeData, Color)>[
    ('라이트', lightTheme(), AppColors.lightSurface),
    ('다크', darkTheme(), AppColors.darkSurface),
  ]) {
    testWidgets('${entry.$1} Drawer가 브랜드 surface와 대비 텍스트를 사용한다',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: entry.$2,
          home: const MtfAnimatedDrawer(
            trainerName: 'DEV 강사',
            shortName: '강',
            tierName: 'Amateur',
            memberCount: 1,
            bannerData: PremiumBannerData(
              currentTier: AppTier.amateur,
              isSponsor: false,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 600));

      final hasPanelSurface =
          tester.widgetList<Container>(find.byType(Container)).any((container) {
        final decoration = container.decoration;
        return decoration is BoxDecoration && decoration.color == entry.$3;
      });

      expect(hasPanelSurface, isTrue);
      expect(find.text('고객카드'), findsOneWidget);
      expect(find.text('회원 정보 확인 및 관리 지원'), findsOneWidget);
      expect(find.text('레슨 계약서 작성 및 운영 지원'), findsOneWidget);
      expect(find.text('레슨 및 회원 운영 분석 지원'), findsOneWidget);
      expect(find.text('설정'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
