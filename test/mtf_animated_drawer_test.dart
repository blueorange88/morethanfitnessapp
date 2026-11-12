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
    expect(source, contains('duration: const Duration(milliseconds: 140)'));
    expect(source, contains('MORE THAN wellness 회원관리'));
  });

  test('회원권계약서 메뉴는 고정된 운영 지원 설명을 사용한다', () {
    expect(source, contains("sub: '회원권 계약서 작성 및 운영 지원'"));
    expect(source, isNot(contains('회원권계약서를 작성하고 확인해요.')));
  });

  Future<void> pumpDrawer(
    WidgetTester tester, {
    VoidCallback? onContractManage,
    VoidCallback? onContract,
    VoidCallback? onMembershipContract,
  }) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: MtfAnimatedDrawer(
          trainerName: 'DEV 강사',
          shortName: '강',
          tierName: 'Semi-Pro',
          memberCount: 1,
          bannerData: const PremiumBannerData(
            currentTier: AppTier.semiPro,
            isSponsor: false,
          ),
          onContractManage: onContractManage,
          onContract: onContract,
          onMembershipContract: onMembershipContract,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('일반 워크스페이스는 레슨계약서·회원권계약서 대신 계약서 관리 하나만 보인다', (tester) async {
    var manage = 0;
    var lesson = 0;
    var membership = 0;
    await pumpDrawer(
      tester,
      onContractManage: () => manage += 1,
      onContract: () => lesson += 1,
      onMembershipContract: () => membership += 1,
    );
    expect(find.text('계약서 관리'), findsOneWidget);
    expect(find.text('계약서 검색 · 작성 · 이력'), findsOneWidget);
    expect(find.text('레슨계약서'), findsNothing);
    expect(find.text('회원권계약서'), findsNothing);
    expect(find.text('인사이트'), findsOneWidget);

    await tester.tap(find.text('계약서 관리'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(manage, 1);
    expect(lesson, 0);
    expect(membership, 0);
  });

  testWidgets('그 밖의 워크스페이스(레거시)는 레슨계약서·회원권계약서 두 항목이 그대로다', (tester) async {
    var lesson = 0;
    var membership = 0;
    await pumpDrawer(
      tester,
      onContract: () => lesson += 1,
      onMembershipContract: () => membership += 1,
    );
    expect(find.text('계약서 관리'), findsNothing);
    expect(find.text('레슨계약서'), findsOneWidget);
    expect(find.text('회원권계약서'), findsOneWidget);
    await tester.tap(find.text('회원권계약서'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(membership, 1);
    expect(lesson, 0);
  });

  test('홈은 일반 워크스페이스에서만 계약서 관리를 넘기고 등급 확인·회원권 버튼을 함께 쓴다', () {
    final home = File('lib/pages/home_page.dart').readAsStringSync();
    expect(
      home,
      contains('_isPersonalWorkspace && _personalOwnerUid.isNotEmpty'),
    );
    expect(home, contains('? _openContractManageFromHome'));
    expect(
      home,
      contains('_openContractStartChatSheet(opener: _openContractManagePage)'),
    );
    final page = home.substring(
      home.indexOf('Future<void> _openContractManagePage()'),
      home.indexOf('Future<void> _openContractStartChatSheet({'),
    );
    expect(page, contains('MemberContractsPage('));
    expect(page, contains('memberId: null,'));
    expect(page, contains('autoStartWhenEmpty: false,'));
    expect(page, contains('onOpenMembership: _openMembershipContractFromHome'));
  });

  test('회원카드의 지난 레슨계약서는 일반 워크스페이스에서 대화창 없이 이 회원의 계약서 목록을 연다', () {
    final card = File('lib/pages/client_card_page.dart').readAsStringSync();
    final start = card.indexOf('Future<void> _openContractHistorySheet()');
    final body = card.substring(
      start,
      card.indexOf('Future<void> _openTrainingLogConsent()', start),
    );
    final personal = body.indexOf('if (_isPersonalWorkspace) {');
    final dialog = body.indexOf('AifcContractHistoryChatSheet.show(');
    expect(personal, greaterThan(-1));
    expect(
      body.substring(personal, dialog),
      contains('await _openContract();'),
    );
    // 그 밖의 워크스페이스는 기존 대화창을 그대로 쓴다.
    expect(dialog, greaterThan(personal));
  });

  for (final entry in <(String, ThemeData, Color)>[
    ('라이트', lightTheme(), AppColors.lightSurface),
    ('다크', darkTheme(), AppColors.darkSurface),
  ]) {
    testWidgets('${entry.$1} Drawer가 브랜드 surface와 대비 텍스트를 사용한다', (
      tester,
    ) async {
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

      final hasPanelSurface = tester
          .widgetList<Container>(find.byType(Container))
          .any((container) {
            final decoration = container.decoration;
            return decoration is BoxDecoration && decoration.color == entry.$3;
          });

      expect(hasPanelSurface, isTrue);
      expect(find.text('회원리스트'), findsOneWidget);
      expect(find.text('회원 정보 확인 및 관리 지원'), findsOneWidget);
      expect(find.text('레슨 계약서 작성 및 운영 지원'), findsOneWidget);
      expect(find.text('레슨 및 회원 운영 분석 지원'), findsOneWidget);
      expect(find.text('설정'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
