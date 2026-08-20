import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/app_theme_mode.dart';
import 'package:mtf_app/models/widget_theme.dart';
import 'package:mtf_app/pages/widget_settings_page.dart';
import 'package:mtf_app/providers/theme_provider.dart';
import 'package:mtf_app/theme.dart';
import 'package:mtf_app/widgets/home/sections/home_weekly_goal_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('앱 테마 preference 마이그레이션', () {
    test('신규 설치는 라이트를 사용한다', () {
      expect(
        resolveAppThemeMode(appThemeRaw: null, legacyDarkMode: null),
        AppThemeMode.light,
      );
    });

    test('legacy false는 룰루랄라, true는 다크로 보존한다', () {
      expect(
        resolveAppThemeMode(appThemeRaw: null, legacyDarkMode: false),
        AppThemeMode.lululala,
      );
      expect(
        resolveAppThemeMode(appThemeRaw: null, legacyDarkMode: true),
        AppThemeMode.dark,
      );
    });

    test('유효한 신규 값이 legacy bool보다 우선하고 잘못된 값은 fallback한다', () {
      expect(
        resolveAppThemeMode(appThemeRaw: 'light', legacyDarkMode: true),
        AppThemeMode.light,
      );
      expect(
        resolveAppThemeMode(appThemeRaw: 'dark', legacyDarkMode: false),
        AppThemeMode.dark,
      );
      expect(
        resolveAppThemeMode(appThemeRaw: 'lululala', legacyDarkMode: true),
        AppThemeMode.lululala,
      );
      expect(
        resolveAppThemeMode(appThemeRaw: 'unknown', legacyDarkMode: null),
        AppThemeMode.light,
      );
    });

    test('선택한 신규 값은 재시작 후 source of truth로 복원된다', () async {
      SharedPreferences.setMockInitialValues({PrefKeys.darkMode: true});
      final first = AppThemeNotifier(widgetThemeSync: (_) async {});
      await first.initialized;
      await first.setTheme(AppThemeMode.lululala);

      final second = AppThemeNotifier(widgetThemeSync: (_) async {});
      await second.initialized;
      expect(second.state, AppThemeMode.lululala);
    });
  });

  test('앱 테마는 위젯 3종에 정확히 매핑된다', () {
    expect(
      widgetThemeForAppTheme(AppThemeMode.light),
      WidgetThemeType.brandLight,
    );
    expect(
      widgetThemeForAppTheme(AppThemeMode.dark),
      WidgetThemeType.dark,
    );
    expect(
      widgetThemeForAppTheme(AppThemeMode.lululala),
      WidgetThemeType.light,
    );
  });

  test('legacy 위젯 값은 삭제하지 않고 안전하게 읽는다', () {
    expect(widgetThemeTypeFromRaw('pinkperfume'), WidgetThemeType.pinkperfume);
    expect(
        widgetThemeTypeFromRaw('brownHistory'), WidgetThemeType.brownHistory);
    expect(widgetThemeTypeFromRaw('ttobak'), WidgetThemeType.ttobak);
    expect(widgetThemeTypeFromRaw('invalid'), WidgetThemeType.light);
  });

  testWidgets('위젯 설정에는 공식 3종만 노출된다', (tester) async {
    SharedPreferences.setMockInitialValues({PrefKeys.appTheme: 'light'});
    final notifier = AppThemeNotifier(widgetThemeSync: (_) async {});
    await notifier.initialized;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appThemeProvider.overrideWith((ref) => notifier),
        ],
        child: MaterialApp(
          theme: lightTheme(),
          home: const WidgetSettingsPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('라이트'), findsOneWidget);
    expect(find.text('다크'), findsOneWidget);
    expect(find.text('룰루랄라'), findsOneWidget);
    expect(find.text('분홍퍼퓸'), findsNothing);
    expect(find.text('브라운히스토리'), findsNothing);
    expect(find.text('또박또박'), findsNothing);
  });

  for (final entry in <String, ThemeData>{
    'light': lightTheme(),
    'dark': darkTheme(),
    'lululala': lululalaTheme(),
  }.entries) {
    testWidgets('${entry.key} 목표 카드가 테마 surface와 텍스트 대비를 사용한다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: entry.value,
          home: Scaffold(
            body: HomeWeeklyGoalSection(
              title: '이번 주 목표',
              weekCount: 2,
              goalTarget: 4,
              progress: 0.5,
              topFirst: 'PT',
              topSecond: '필라테스',
              primaryColor: entry.value.colorScheme.primary,
            ),
          ),
        ),
      );

      final title = tester.widget<Text>(find.text('이번 주 목표'));
      expect(title.style?.color, entry.value.colorScheme.onSurface);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('인사이트·통계·D-DAY는 중앙 테마 팔레트를 사용한다', () {
    final stats = File('lib/pages/stats_page.dart').readAsStringSync();
    final trainingLog =
        File('lib/pages/personal_training_log_page.dart').readAsStringSync();

    expect(stats, contains('context.mtfChartPalette'));
    expect(stats, contains('context.mtfThemeTokens'));
    expect(trainingLog, contains('context.mtfChartPalette'));
    expect(trainingLog, contains('tokens.sheetBackground'));
    expect(trainingLog, contains('tokens.cardSurface'));
  });
}
