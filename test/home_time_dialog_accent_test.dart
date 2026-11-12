import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/theme/app_colors.dart';
import 'package:mtf_app/widgets/home/lesson_editor/home_time_dialog_parts.dart';

Future<Color?> _confirmBackground(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Scaffold(body: HomeDialogFooter(onCancel: () {}, onConfirm: () {})),
    ),
  );
  await tester.pumpAndSettle();
  final box = tester.widget<DecoratedBox>(
    find
        .ancestor(
          of: find.bySubtype<ElevatedButton>(),
          matching: find.byType(DecoratedBox),
        )
        .first,
  );
  return (box.decoration as BoxDecoration).color;
}

void main() {
  testWidgets('시간 선택창 적용 버튼은 밝은 모드에서 네이비, 어두운 모드에서 테마 강조색이다', (tester) async {
    expect(
      await _confirmBackground(tester, lightTheme()),
      AppColors.deepNavy,
    );
    expect(
      await _confirmBackground(tester, darkTheme()),
      isNot(AppColors.deepNavy),
    );
  });
}
