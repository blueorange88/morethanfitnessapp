import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/aifc/home/aifc_home_schedule_action_chat_sheet.dart';
import 'package:mtf_app/theme/app_colors.dart';

Future<void> _openSheet(WidgetTester tester, ThemeData theme) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder:
            (context) => Scaffold(
              body: TextButton(
                onPressed:
                    () => AifcHomeScheduleActionChatSheet.show(
                      context: context,
                      nickname: '민',
                      targetLabel: '이번 주',
                      hasCopiedSchedules: false,
                      openBulkFirst: true,
                      primaryColor: AppColors.deepNavy,
                    ),
                child: const Text('열기'),
              ),
            ),
      ),
    ),
  );
  await tester.tap(find.text('열기'));
  // 아바타가 계속 움직여 pumpAndSettle이 끝나지 않으므로 시간을 정해 넘긴다.
  await tester.pump(const Duration(milliseconds: 600));
}

Color? _sheetColor(WidgetTester tester) {
  for (final box in tester.widgetList<Container>(find.byType(Container))) {
    final decoration = box.decoration;
    if (decoration is BoxDecoration &&
        decoration.borderRadius ==
            const BorderRadius.vertical(top: Radius.circular(26))) {
      return decoration.color;
    }
  }
  return null;
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  testWidgets('밝은 모드: 시트 바탕은 앱 아이보리, 보라색 고정색을 쓰지 않는다', (tester) async {
    await _openSheet(tester, ThemeData.light());
    expect(find.text('스케줄 일괄관리'), findsOneWidget);
    expect(_sheetColor(tester), AppColors.warmIvory);
  });

  testWidgets('어두운 모드: 시트 바탕은 앱 어두운 표면색, 제목 글씨는 읽을 수 있다', (tester) async {
    await _openSheet(tester, ThemeData.dark());
    expect(find.text('스케줄 일괄관리'), findsOneWidget);
    final bg = _sheetColor(tester)!;
    expect(bg, AppColors.darkSurface);
    final title = tester.widget<Text>(find.text('스케줄 일괄관리'));
    expect(_contrast(title.style!.color!, bg), greaterThanOrEqualTo(4.5));
  });
}
