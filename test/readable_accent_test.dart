import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/theme/app_colors.dart';
import 'package:mtf_app/widgets/home/sections/home_bottom_nav_bar.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('mtfReadableAccent', () {
    test('흰 배경 위 연한 골드는 글씨로 읽히게 어두워진다', () {
      final accent = mtfReadableAccent(AppColors.warmYellow, Colors.white);
      expect(_contrast(accent, Colors.white), greaterThanOrEqualTo(4.5));
      expect(accent, isNot(AppColors.warmYellow));
      // 색상(hue)은 골드 그대로 유지한다.
      expect(
        (HSLColor.fromColor(accent).hue -
                HSLColor.fromColor(AppColors.warmYellow).hue)
            .abs(),
        lessThan(3),
      );
    });

    test('이미 대비가 충분하면 색을 바꾸지 않는다', () {
      expect(
        mtfReadableAccent(AppColors.warmYellow, AppColors.darkSurface),
        AppColors.warmYellow,
      );
      expect(
        mtfReadableAccent(AppColors.deepNavy, Colors.white),
        AppColors.deepNavy,
      );
    });
  });

  group('ColorScheme.accentText', () {
    test('라이트 테마는 진한 골드, 다크 테마는 원래 골드', () {
      final light = lightTheme().colorScheme;
      final dark = darkTheme().colorScheme;
      expect(
        _contrast(light.accentText, light.surface),
        greaterThanOrEqualTo(4.5),
      );
      expect(light.accentText, isNot(light.secondary));
      expect(dark.accentText, dark.secondary);
    });

    test('배경으로 칠하는 secondary는 그대로다', () {
      expect(lightTheme().colorScheme.secondary, AppColors.warmYellow);
    });
  });

  testWidgets('라이트 홈 하단 바의 빠른 등록 글씨가 흰 바 위에서 읽힌다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: Scaffold(
          bottomNavigationBar: HomeBottomNavBar(
            activeIndex: -1,
            primaryColor: lightTheme().colorScheme.secondary,
            secondaryColor: lightTheme().colorScheme.secondaryContainer,
            onChanged: (_) {},
            onCenterTap: () {},
          ),
        ),
      ),
    );
    final label = tester.widget<Text>(find.text('빠른 등록'));
    const tokens = MtfThemeTokens.light;
    expect(
      _contrast(label.style!.color!, tokens.navigationSheetBackground),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('빠른 등록 라벨은 다른 탭 라벨보다 크고 굵으며 눌러도 등록이 열린다', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: Scaffold(
          bottomNavigationBar: HomeBottomNavBar(
            activeIndex: -1,
            primaryColor: lightTheme().colorScheme.secondary,
            secondaryColor: lightTheme().colorScheme.secondaryContainer,
            onChanged: (_) {},
            onCenterTap: () => taps++,
          ),
        ),
      ),
    );
    final style =
        tester
            .widget<Text>(find.byKey(const Key('home_quick_register_label')))
            .style!;
    expect(style.fontSize, greaterThanOrEqualTo(13));
    expect(style.fontWeight, FontWeight.w900);

    await tester.tap(find.byKey(const Key('home_quick_register_label')));
    expect(taps, 1);
  });
}
