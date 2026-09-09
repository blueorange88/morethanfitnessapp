import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/aifc/core/aifc_chat_bubble.dart';
import 'package:mtf_app/pages/training_log_consent_page.dart';
import 'package:mtf_app/services/app_environment.dart';
import 'package:mtf_app/services/dev_tier_fixture.dart';
import 'package:mtf_app/theme/app_colors.dart';
import 'package:mtf_app/widgets/app_environment_banner.dart';
import 'package:mtf_app/widgets/premium_banner_widget.dart';

void main() {
  test('잔여 UI 의미 토큰은 세 테마의 역할을 분리한다', () {
    expect(MtfThemeTokens.light.aifcUserBubble, AppColors.warmYellow);
    expect(MtfThemeTokens.dark.aifcUserBubble, AppColors.warmYellow);
    expect(
      MtfThemeTokens.lululala.aifcUserBubble,
      AppColors.lululalaPrimary,
    );
    expect(
      MtfThemeTokens.light.donationSurface,
      isNot(MtfThemeTokens.dark.donationSurface),
    );
    expect(
      MtfThemeTokens.light.donationSurface,
      isNot(MtfThemeTokens.lululala.donationSurface),
    );
    expect(
      MtfThemeTokens.light.schedulerBorder,
      AppColors.lightBorder,
    );
    expect(
      MtfThemeTokens.dark.schedulerBorder,
      AppColors.darkBorder,
    );
    expect(
      MtfThemeTokens.lululala.schedulerCornerSurface,
      AppColors.lululalaPrimary,
    );
  });

  test('주요 헤더·시트·스케줄러가 공통 테마 경계를 사용한다', () {
    final clientList =
        File('lib/pages/client_list_page.dart').readAsStringSync();
    final myPage = File('lib/pages/my_page.dart').readAsStringSync();
    final trainingLog =
        File('lib/pages/personal_training_log_page.dart').readAsStringSync();
    final category = File('lib/pages/personal_training_log_category_page.dart')
        .readAsStringSync();
    final consent =
        File('lib/pages/training_log_consent_page.dart').readAsStringSync();
    final schedule = File(
      'lib/widgets/home/schedule/home_weekly_schedule_table.dart',
    ).readAsStringSync();

    expect(clientList, contains('gradient: gradient'));
    expect(clientList, isNot(contains('color: const Color(0xFF5B4BDB)')));
    expect(
      myPage,
      contains('Theme.of(context).colorScheme.secondary'),
    );
    expect(myPage, contains('context.mtfHeaderGradient'));
    expect(trainingLog, contains('context.mtfHeaderGradient'));
    expect(trainingLog, contains('color: tokens.sheetBackground'));
    expect(category, contains('context.mtfHeaderGradient'));
    expect(consent, contains('context.mtfHeaderGradient'));
    expect(
      consent,
      contains('backgroundColor: context.mtfHeaderGradient.colors.first'),
    );
    expect(consent, contains('systemOverlayStyle: SystemUiOverlayStyle.light'));
    expect(
        consent, isNot(contains('backgroundColor: const Color(0xFF4F46E5)')));
    expect(consent, isNot(contains('color: Colors.black54')));
    expect(consent, contains('color: scheme.onSurfaceVariant'));
    expect(schedule, contains('schedulerOuterSurface'));
    expect(schedule, contains('schedulerBorder'));
    expect(schedule, contains('clipBehavior: Clip.antiAlias'));
  });

  test('AIFC와 후원 UI는 공통 의미 토큰을 사용한다', () {
    final chatBubble =
        File('lib/aifc/core/aifc_chat_bubble.dart').readAsStringSync();
    final chatSheet =
        File('lib/aifc/core/aifc_chat_sheet.dart').readAsStringSync();
    final quickRegister = File(
      'lib/widgets/aifc_quick_register_chat_sheet.dart',
    ).readAsStringSync();
    final consult = File(
      'lib/widgets/aifc_consult_checklist_chat_sheet.dart',
    ).readAsStringSync();
    final donation =
        File('lib/widgets/premium_banner_widget.dart').readAsStringSync();

    expect(chatBubble, contains('tokens.aifcUserBubble'));
    expect(chatBubble, contains('tokens.aifcSurface'));
    expect(chatSheet, contains('tokens.aifcInputSurface'));
    expect(quickRegister, contains('tokens.aifcInputSurface'));
    expect(quickRegister, contains('scheme.secondary'));
    expect(consult, contains('tokens.aifcSurface'));
    expect(consult, contains('scheme.secondary'));
    expect(donation, contains('tokens.donationSurface'));
    expect(donation, contains('tokens.donationAccent'));
    expect(donation, contains('tokens.donationProgress'));
  });

  for (final themeEntry in <String, ThemeData>{
    'light': lightTheme(),
    'dark': darkTheme(),
    'lululala': lululalaTheme(),
  }.entries) {
    testWidgets('${themeEntry.key} AIFC 말풍선과 동의 화면이 렌더링된다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeEntry.value,
          home: const Scaffold(
            body: Column(
              children: [
                AifcChatBubble(
                  side: AifcBubbleSide.fc,
                  text: 'FC 안내',
                ),
                AifcChatBubble(
                  side: AifcBubbleSide.user,
                  text: '사용자 답변',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('FC 안내'), findsOneWidget);
      expect(find.text('사용자 답변'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        MaterialApp(
          theme: themeEntry.value,
          home: const TrainingLogConsentPage(),
        ),
      );
      await tester.pump();

      expect(find.text('수업일지 개인정보 동의'), findsOneWidget);
      expect(find.text('동의하고 계속하기'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${themeEntry.key} 후원 카드가 테마 surface로 렌더링된다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: themeEntry.value,
          home: Scaffold(
            body: PremiumBannerWidget(
              data: const PremiumBannerData(
                currentTier: AppTier.pro,
                isSponsor: false,
              ),
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('후원'), findsOneWidget);
      expect(
        _hasContainerColor(
          tester,
          themeEntry.value.extension<MtfThemeTokens>()!.donationSurface,
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('dark DEV tier fixture panel uses theme contrast',
      (tester) async {
    AppEnvironmentConfig.select(AppEnvironment.dev);
    DevTierFixtureController.resetForTesting();
    addTearDown(() {
      DevTierFixtureController.resetForTesting();
      AppEnvironmentConfig.select(AppEnvironment.prod);
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme(),
        home: const AppEnvironmentBanner(
          enabled: true,
          child: Scaffold(body: SizedBox.expand()),
        ),
      ),
    );

    await tester.longPress(find.byKey(const Key('dev_environment_banner')));
    await tester.pump();

    final context = tester.element(
      find.byKey(const Key('dev_tier_fixture_panel')),
    );
    final scheme = Theme.of(context).colorScheme;
    final panel = tester.widget<Material>(
      find.byKey(const Key('dev_tier_fixture_panel')),
    );

    expect(panel.color, scheme.surface);
    expect(
      tester.widget<Text>(find.text('DEV 등급 fixture')).style?.color,
      scheme.onSurface,
    );
  });
}

bool _hasContainerColor(WidgetTester tester, Color color) {
  return tester.widgetList<Container>(find.byType(Container)).any((container) {
    final decoration = container.decoration;
    return decoration is BoxDecoration && decoration.color == color;
  });
}
