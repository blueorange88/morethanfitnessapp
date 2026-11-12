import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/theme/app_colors.dart';
import 'package:mtf_app/widgets/home/lesson_editor/home_lesson_editor_header.dart';

Future<void> _pump(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(
        body: HomeLessonEditorHeader(
          day: '월',
          startTimeLabel: '09:00',
          endTimeLabel: '10:00',
          endTimeIsEmpty: false,
          onClose: () {},
          onTimeTap: () {},
        ),
      ),
    ),
  );
}

LinearGradient _gradient(WidgetTester tester) {
  final box = tester.widget<Container>(
    find
        .descendant(
          of: find.byType(HomeLessonEditorHeader),
          matching: find.byType(Container),
        )
        .first,
  );
  return (box.decoration! as BoxDecoration).gradient! as LinearGradient;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  testWidgets('밝은 모드: 헤더는 앱 메인 네이비 바탕에 흰 글씨다', (tester) async {
    await _pump(tester, lightTheme());
    final gradient = _gradient(tester);

    expect(gradient.colors.first, AppColors.deepNavy);
    expect(gradient.colors.last, AppColors.lightGradientEnd);
    expect(
      gradient.colors.contains(lightTheme().colorScheme.secondary),
      isFalse,
    );
    final title = tester.widget<Text>(find.text('월요일'));
    expect(title.style!.color, Colors.white);
    expect(_contrast(Colors.white, gradient.colors[1]), greaterThan(4.5));
  });

  testWidgets('어두운 모드: 헤더는 저장 버튼 색(secondary)이 바탕이고 글씨가 읽힌다', (tester) async {
    await _pump(tester, darkTheme());
    final scheme = darkTheme().colorScheme;
    final gradient = _gradient(tester);

    // 가운데 색이 저장 버튼 바탕색과 같다.
    expect(gradient.colors[1], scheme.secondary);

    final title = tester.widget<Text>(find.text('월요일'));
    expect(title.style!.color, scheme.onSecondary);
    expect(_contrast(scheme.onSecondary, scheme.secondary), greaterThan(4.5));
    expect(gradient.colors.any((c) => c == AppColors.deepNavy), isFalse);
  });
}
