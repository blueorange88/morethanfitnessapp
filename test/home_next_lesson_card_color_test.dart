import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/theme/app_colors.dart';
import 'package:mtf_app/widgets/home/sections/home_next_lesson_card.dart';

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: const Scaffold(
        body: HomeNextLessonCard(
          name: '홍길동',
          time: '14:00',
          type: 'PT',
          status: '다음',
          enrolled: 0,
          cap: 0,
          primaryColor: AppColors.deepNavy,
          countText: '3/10',
          memo: '메모',
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  testWidgets('어두운 모드: 시간 글씨는 빠른 등록과 같은 강조색이라 배경에서 읽힌다', (tester) async {
    final theme = darkTheme();
    await _pump(tester, theme);

    final time = tester.widget<Text>(find.text('14:00'));
    expect(time.style!.color, theme.colorScheme.secondary);
    // 네이비(옛 색)는 어두운 카드 위에서 거의 안 보였다.
    expect(time.style!.color, isNot(AppColors.deepNavy));
    expect(
      _contrast(time.style!.color!, theme.colorScheme.surface),
      greaterThan(4.5),
    );
    expect(
      _contrast(AppColors.deepNavy, theme.colorScheme.surface),
      lessThan(2.0),
      reason: '이전 색의 대비가 낮았음을 확인',
    );
  });

  testWidgets('밝은 모드: 기존 네이비 시간 글씨를 그대로 쓴다', (tester) async {
    final theme = lightTheme();
    await _pump(tester, theme);

    final time = tester.widget<Text>(find.text('14:00'));
    expect(time.style!.color, AppColors.deepNavy);
  });
}
