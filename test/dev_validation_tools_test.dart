import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/app_environment.dart';
import 'package:mtf_app/services/app_tier_access_service.dart';
import 'package:mtf_app/services/dev_tier_fixture.dart';
import 'package:mtf_app/widgets/app_environment_banner.dart';
import 'package:mtf_app/widgets/dev_client_card_viewport.dart';

AppTierAccessSnapshot _serverAccess(int rank) => AppTierAccessSnapshot(
      tierRank: rank,
      earnedTierRank: rank,
      supportTierRank: 0,
      organizationTierRank: 0,
      storedTierRank: rank,
      isSponsor: false,
      profileCompleted: false,
      kakaoLinked: false,
      activeMemberCount: 0,
      kakaoCardLinkedMemberCount: 0,
      contractSignedMemberCount: 0,
      branchCount: 0,
    );

void main() {
  setUp(() {
    AppEnvironmentConfig.select(AppEnvironment.dev);
    DevTierFixtureController.resetForTesting();
    DevClientCardViewportController.resetForTesting();
  });

  tearDown(() {
    DevTierFixtureController.resetForTesting();
    DevClientCardViewportController.resetForTesting();
    AppEnvironmentConfig.select(AppEnvironment.prod);
  });

  test('DEV tier fixture는 서버 tier를 보존하고 effective tier만 바꾼다', () {
    final server = _serverAccess(0);

    DevTierFixtureController.select(DevTierFixture.amateur);
    final amateur = server.withEffectiveTierRank(
      DevTierFixtureController.resolveTierRank(server.tierRank),
    );
    expect(amateur.tierRank, 1);
    expect(amateur.storedTierRank, 0);
    expect(
      AppTierAccessService.canUseFeature(
        amateur,
        AppTierFeatureKey.customerCardCreate,
      ),
      isTrue,
    );

    DevTierFixtureController.select(DevTierFixture.semiPro);
    final semiPro = server.withEffectiveTierRank(
      DevTierFixtureController.resolveTierRank(server.tierRank),
    );
    expect(
      AppTierAccessService.canUseFeature(
        semiPro,
        AppTierFeatureKey.trainingLog,
      ),
      isTrue,
    );

    DevTierFixtureController.select(DevTierFixture.server);
    expect(
      DevTierFixtureController.resolveTierRank(server.tierRank),
      server.tierRank,
    );
  });

  test('PROD 환경은 DEV tier override를 무시한다', () {
    DevTierFixtureController.select(DevTierFixture.pro);
    expect(DevTierFixtureController.resolveTierRank(0), 3);

    AppEnvironmentConfig.select(AppEnvironment.prod);
    expect(DevTierFixtureController.resolveTierRank(0), 0);
  });

  test('DEV tier fixture 구현은 Firestore와 Functions를 사용하지 않는다', () {
    final source =
        File('lib/services/dev_tier_fixture.dart').readAsStringSync();
    expect(source, isNot(contains('cloud_firestore')));
    expect(source, isNot(contains('FirebaseFirestore')));
    expect(source, isNot(contains('FirebaseFunctions')));
    expect(source, isNot(contains('httpsCallable')));
  });

  testWidgets('DEV 배지 길게 누르기로 로컬 tier fixture를 선택한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppEnvironmentBanner(
          enabled: true,
          child: Scaffold(body: Text('home')),
        ),
      ),
    );

    await tester.longPress(find.byKey(const Key('dev_environment_banner')));
    await tester.pump();
    expect(find.byKey(const Key('dev_tier_fixture_panel')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dev_tier_fixture_amateur')));
    await tester.pump();
    expect(
      DevTierFixtureController.selection.value,
      DevTierFixture.amateur,
    );
  });

  testWidgets('PROD에서는 DEV tier selector가 열리지 않는다', (tester) async {
    AppEnvironmentConfig.select(AppEnvironment.prod);
    await tester.pumpWidget(
      const MaterialApp(
        home: AppEnvironmentBanner(
          enabled: true,
          child: Scaffold(body: Text('home')),
        ),
      ),
    );

    await tester.longPress(find.byKey(const Key('dev_environment_banner')));
    await tester.pump();
    expect(find.byKey(const Key('dev_tier_fixture_panel')), findsNothing);
  });

  testWidgets('viewport OFF는 기존 MediaQuery를 유지한다', (tester) async {
    const original = MediaQueryData(
      size: Size(800, 1200),
      viewInsets: EdgeInsets.only(bottom: 240),
      padding: EdgeInsets.only(top: 24),
      viewPadding: EdgeInsets.only(top: 24),
      textScaler: TextScaler.linear(1.3),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: original,
          child: Material(
            child: DevClientCardViewport(
              child: SizedBox(key: Key('viewport_probe')),
            ),
          ),
        ),
      ),
    );

    final context = tester.element(find.byKey(const Key('viewport_probe')));
    final media = MediaQuery.of(context);
    expect(media.size, original.size);
    expect(media.viewInsets, original.viewInsets);
    expect(media.padding, original.padding);
    expect(media.viewPadding, original.viewPadding);
    expect(media.textScaler, original.textScaler);
    expect(
      find.byKey(const Key('dev_client_card_simulated_viewport')),
      findsNothing,
    );
  });

  for (final width in DevClientCardViewportController.supportedWidths) {
    testWidgets('viewport ${width.toInt()}dp는 width만 바꾼다', (tester) async {
      DevClientCardViewportController.select(width);
      const original = MediaQueryData(
        size: Size(800, 1200),
        viewInsets: EdgeInsets.only(bottom: 240),
        padding: EdgeInsets.only(top: 24),
        viewPadding: EdgeInsets.only(top: 24),
        textScaler: TextScaler.linear(1.3),
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: original,
            child: Material(
              child: DevClientCardViewport(
                child: SizedBox(key: Key('viewport_probe')),
              ),
            ),
          ),
        ),
      );

      final context = tester.element(find.byKey(const Key('viewport_probe')));
      final media = MediaQuery.of(context);
      expect(media.size.width, width);
      expect(media.size.height, original.size.height);
      expect(media.viewInsets, original.viewInsets);
      expect(media.padding, original.padding);
      expect(media.viewPadding, original.viewPadding);
      expect(media.textScaler, original.textScaler);
    });
  }

  testWidgets('PROD에서는 viewport selector와 width override를 숨긴다', (
    tester,
  ) async {
    DevClientCardViewportController.select(360);
    AppEnvironmentConfig.select(AppEnvironment.prod);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(800, 1200)),
          child: Material(
            child: DevClientCardViewport(
              child: SizedBox(key: Key('viewport_probe')),
            ),
          ),
        ),
      ),
    );

    final context = tester.element(find.byKey(const Key('viewport_probe')));
    expect(MediaQuery.of(context).size.width, 800);
    expect(
      find.byKey(const Key('dev_client_card_viewport_selector')),
      findsNothing,
    );
  });
}
