import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/aifc/core/aifc_theme.dart';
import 'package:mtf_app/models/app_theme_mode.dart';
import 'package:mtf_app/models/widget_theme.dart';
import 'package:mtf_app/providers/theme_provider.dart';
import 'package:mtf_app/services/app_tier_access_service.dart';
import 'package:mtf_app/theme.dart';
import 'package:mtf_app/widgets/aifc_confirm_chat_sheet.dart';
import 'package:mtf_app/widgets/aifc_tier_feature_gate_sheet.dart';
import 'package:mtf_app/widgets/home/schedule/home_weekly_schedule_table.dart';
import 'package:mtf_app/widgets/home/sections/home_today_next_lessons_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('라이트 테마가 MORE THAN 브랜드 색상과 공통 컴포넌트를 사용한다', () {
    final theme = lightTheme();
    final colors = theme.colorScheme;

    expect(theme.brightness, Brightness.light);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFF7F5EF));
    expect(colors.primary, const Color(0xFF0B1E32));
    expect(colors.secondary, const Color(0xFFEFCB62));
    expect(colors.onPrimary, Colors.white);
    expect(colors.onSecondary, const Color(0xFF0B1E32));
    expect(colors.onSurface, const Color(0xFF0B1E32));
    expect(colors.onSurfaceVariant, const Color(0xFF52606D));
    expect(colors.outline, const Color(0xFFE8E4DA));
    expect(theme.cardTheme.color, Colors.white);
    expect(theme.bottomSheetTheme.modalBackgroundColor, Colors.white);
    expect(theme.inputDecorationTheme.fillColor, Colors.white);
    final tokens = theme.extension<MtfThemeTokens>()!;
    expect(tokens.memberListBackground, AppColors.lightBg);
    expect(tokens.memberListCard, AppColors.lightSurface);
    expect(tokens.memberListCardBorder, AppColors.lightBorder);
    expect(tokens.navigationSheetBackground, AppColors.lightSurface);
    expect(tokens.navigationSelectedBackground, const Color(0xFFFFF1C2));
    expect(tokens.drawerBackground, AppColors.lightSurface);
    expect(tokens.sheetBackground, AppColors.lightSurface);
    expect(tokens.scheduleHeaderBackground, AppColors.deepNavy);
    expect(tokens.scheduleSelectedBorder, AppColors.warmYellow);
    expect(tokens.cardBorder, AppColors.lightBorder);
    expect(
      theme.inputDecorationTheme.focusedBorder,
      isA<OutlineInputBorder>().having(
        (border) => border.borderSide.color,
        'focus color',
        const Color(0xFFEFCB62),
      ),
    );

    _expectCentralComponentThemes(theme);
    expect(
      theme.filledButtonTheme.style?.backgroundColor?.resolve({}),
      const Color(0xFFEFCB62),
    );
    expect(
      theme.filledButtonTheme.style?.foregroundColor?.resolve({}),
      const Color(0xFF0B1E32),
    );
  });

  test('다크 테마가 순수 검정 대신 브랜드 네이비를 사용한다', () {
    final theme = darkTheme();
    final colors = theme.colorScheme;

    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, const Color(0xFF071522));
    expect(theme.scaffoldBackgroundColor, isNot(Colors.black));
    expect(colors.surface, const Color(0xFF12283A));
    expect(colors.primary, const Color(0xFFEFCB62));
    expect(colors.secondary, const Color(0xFFEFCB62));
    expect(colors.onPrimary, const Color(0xFF0B1E32));
    expect(colors.onSurface, const Color(0xFFF7F4EA));
    expect(colors.onSurfaceVariant, const Color(0xFFB7C2CC));
    expect(colors.outline, const Color(0xFF294256));
    expect(theme.cardTheme.color, const Color(0xFF12283A));
    expect(
      theme.bottomSheetTheme.modalBackgroundColor,
      const Color(0xFF162E42),
    );
    expect(theme.dialogTheme.backgroundColor, const Color(0xFF162E42));
    expect(theme.inputDecorationTheme.fillColor, const Color(0xFF1A3449));
    final tokens = theme.extension<MtfThemeTokens>()!;
    expect(tokens.memberListBackground, AppColors.darkBg);
    expect(tokens.memberListCard, AppColors.darkSurface);
    expect(tokens.memberListCardBorder, AppColors.darkBorder);
    expect(tokens.navigationSheetBackground, AppColors.darkDialogSurface);
    expect(tokens.navigationSelectedBackground, const Color(0xFF4A401F));
    expect(tokens.drawerBackground, AppColors.darkSurface);
    expect(tokens.sheetBackground, AppColors.darkDialogSurface);
    expect(tokens.scheduleGridLine, AppColors.darkBorder);
    expect(tokens.scheduleEmptySlot, const Color(0xFF10283A));
    expect(tokens.cardBorder, AppColors.darkBorder);

    _expectCentralComponentThemes(theme);
    expect(
      theme.filledButtonTheme.style?.backgroundColor?.resolve({}),
      const Color(0xFFEFCB62),
    );
    expect(
      theme.filledButtonTheme.style?.foregroundColor?.resolve({}),
      const Color(0xFF0B1E32),
    );
  });

  test('AIFC 퍼플 팔레트는 브랜드 옐로우와 별도로 유지된다', () {
    expect(AifcColors.primary, const Color(0xFF4F46E5));
    expect(AifcColors.secondary, const Color(0xFF9333EA));
    expect(AifcColors.primary, isNot(AppColors.warmYellow));
  });

  test('기존 pref_dark_mode true는 다크로 복원하고 새 preference를 저장한다', () async {
    SharedPreferences.setMockInitialValues({PrefKeys.darkMode: true});
    final synced = <WidgetThemeType>[];
    final notifier = AppThemeNotifier(
      widgetThemeSync: (theme) async => synced.add(theme),
    );

    await notifier.initialized;
    expect(notifier.state, AppThemeMode.dark);
    expect(synced, [WidgetThemeType.dark]);

    await notifier.setTheme(AppThemeMode.light);
    expect(notifier.state, AppThemeMode.light);
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(PrefKeys.appTheme), 'light');
    expect(preferences.getBool(PrefKeys.darkMode), isFalse);
    expect(synced.last, WidgetThemeType.brandLight);
  });

  test('룰루랄라 테마는 기존 인디고·퍼플 화면과 위젯 팔레트를 유지한다', () {
    final theme = lululalaTheme();
    final tokens = theme.extension<MtfThemeTokens>()!;
    final chart = theme.extension<MtfChartPalette>()!;

    expect(theme.scaffoldBackgroundColor, AppColors.lululalaBackground);
    expect(theme.colorScheme.primary, AppColors.lululalaPrimary);
    expect(theme.colorScheme.secondary, AppColors.lululalaSecondary);
    expect(tokens.drawerHeaderBackground, AppColors.lululalaPrimary);
    expect(tokens.scheduleBackground, AppColors.lululalaSurface);
    expect(chart.primarySeries, AppColors.lululalaPrimary);
    expect(
      widgetThemeForAppTheme(AppThemeMode.lululala),
      WidgetThemeType.light,
    );
  });

  testWidgets('다크 홈의 다음 레슨 제목과 빈 상태가 테마 대비를 사용한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme(),
        home: Scaffold(
          body: HomeTodayNextLessonsSection(
            nextLessons: const [],
            primaryColor: AppColors.warmYellow,
            buildCountText: (_) => '',
            onLessonTap: (_, __) {},
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('오늘 다음 레슨'));
    final emptyText = tester.widget<Text>(find.text('오늘 남은 레슨이 없습니다.'));
    final emptyIcon =
        tester.widget<Icon>(find.byIcon(Icons.check_circle_outline));

    expect(title.style?.color, AppColors.darkTextPrimary);
    expect(emptyText.style?.color, AppColors.darkTextSecondary);
    expect(emptyIcon.color, AppColors.darkTextSecondary);
  });

  testWidgets('다크 스케줄러는 브랜드 배경·격자·헤더 토큰을 사용한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme(),
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: HomeWeeklyScheduleTable(
              dayFilter: 'weekend',
              weekOffset: 0,
              scheduleData: const {},
              currentTime: DateTime(2026, 8, 8, 9, 30),
              timeSlots: const ['09:00', '10:00'],
              onCellTap: (_, __, ___) {},
            ),
          ),
        ),
      ),
    );

    expect(_hasContainerColor(tester, AppColors.darkSurface), isTrue);
    expect(_hasContainerColor(tester, const Color(0xFF10283A)), isTrue);
    expect(_hasBorderColor(tester, AppColors.darkBorder), isTrue);
    expect(tester.widget<Text>(find.text('일')).style?.color,
        AppColors.darkTextPrimary);
    expect(tester.takeException(), isNull);
  });

  testWidgets('다크 등급 안내 시트는 브랜드 surface와 웜 옐로우 CTA를 사용한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                AifcTierFeatureGateSheet.show(
                  context: context,
                  access: _beginnerAccess,
                  feature: AppTierFeatureKey.contract,
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('열기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final cta = tester.widget<FilledButton>(find.widgetWithText(
      FilledButton,
      '등급 안내 보기',
    ));
    expect(
      cta.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.warmYellow,
    );
    expect(_hasContainerColor(tester, AppColors.darkDialogSurface), isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('dark common confirm sheet uses themed surface and brand CTA',
      (tester) async {
    final theme = darkTheme();

    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                AifcConfirmChatSheet.show(
                  context: context,
                  title: 'confirm title',
                  message: 'confirm message',
                );
              },
              child: const Text('open confirm sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open confirm sheet'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      _hasContainerColor(tester, theme.colorScheme.surfaceContainerHighest),
      isTrue,
    );
    expect(_hasContainerColor(tester, AppColors.warmYellow), isTrue);
    expect(find.text('confirm title'), findsOneWidget);
    expect(find.text('confirm message'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _beginnerAccess = AppTierAccessSnapshot(
  tierRank: 0,
  earnedTierRank: 0,
  supportTierRank: 0,
  organizationTierRank: 0,
  storedTierRank: 0,
  isSponsor: false,
  profileCompleted: true,
  kakaoLinked: false,
  activeMemberCount: 0,
  kakaoCardLinkedMemberCount: 0,
  contractSignedMemberCount: 0,
  branchCount: 0,
);

bool _hasContainerColor(WidgetTester tester, Color color) {
  return tester.widgetList<Container>(find.byType(Container)).any((container) {
    final decoration = container.decoration;
    return decoration is BoxDecoration && decoration.color == color;
  });
}

bool _hasBorderColor(WidgetTester tester, Color color) {
  return tester.widgetList<Container>(find.byType(Container)).any((container) {
    final decoration = container.decoration;
    if (decoration is! BoxDecoration || decoration.border is! Border) {
      return false;
    }
    final border = decoration.border! as Border;
    return border.top.color == color ||
        border.right.color == color ||
        border.bottom.color == color ||
        border.left.color == color;
  });
}

void _expectCentralComponentThemes(ThemeData theme) {
  expect(theme.appBarTheme.backgroundColor, isNotNull);
  expect(theme.cardTheme.color, isNotNull);
  expect(theme.bottomSheetTheme.modalBackgroundColor, isNotNull);
  expect(theme.dialogTheme.backgroundColor, isNotNull);
  expect(theme.inputDecorationTheme.fillColor, isNotNull);
  expect(theme.elevatedButtonTheme.style, isNotNull);
  expect(theme.filledButtonTheme.style, isNotNull);
  expect(theme.outlinedButtonTheme.style, isNotNull);
  expect(theme.textButtonTheme.style, isNotNull);
  expect(theme.navigationBarTheme.backgroundColor, isNotNull);
  expect(theme.bottomNavigationBarTheme.backgroundColor, isNotNull);
  expect(theme.chipTheme.selectedColor, isNotNull);
  expect(theme.dividerTheme.color, isNotNull);
  expect(theme.snackBarTheme.backgroundColor, isNotNull);
  expect(theme.switchTheme.trackColor, isNotNull);
  expect(theme.checkboxTheme.fillColor, isNotNull);
  expect(theme.radioTheme.fillColor, isNotNull);
  expect(theme.datePickerTheme.backgroundColor, isNotNull);
  expect(theme.timePickerTheme.backgroundColor, isNotNull);
}
