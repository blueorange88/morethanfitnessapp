import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/theme/app_colors.dart';
import 'package:mtf_app/widgets/home/lesson_editor/home_lesson_footer_actions.dart';

void main() {
  testWidgets('일정 삭제 중에는 모든 하단 동작을 비활성화한다', (tester) async {
    var cancelCalls = 0;
    var deleteCalls = 0;
    var saveCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HomeLessonFooterActions(
            isEditMode: true,
            isLocked: false,
            isCustomerSignedConfirmedLesson: false,
            isContractLinkedConfirmedLesson: false,
            isBusy: true,
            isDeleting: true,
            onCancel: () => cancelCalls += 1,
            onDelete: () async => deleteCalls += 1,
            onSave: () async => saveCalls += 1,
          ),
        ),
      ),
    );

    expect(find.text('삭제 중…'), findsOneWidget);
    final buttons = tester.widgetList<ButtonStyleButton>(
      find.byType(ButtonStyleButton),
    );
    expect(buttons.every((button) => button.onPressed == null), isTrue);
    expect(cancelCalls, 0);
    expect(deleteCalls, 0);
    expect(saveCalls, 0);
  });

  Future<Color?> saveButtonColor(WidgetTester tester, ThemeData theme) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: HomeLessonFooterActions(
            isEditMode: false,
            isLocked: false,
            isCustomerSignedConfirmedLesson: false,
            isContractLinkedConfirmedLesson: false,
            isBusy: false,
            isDeleting: false,
            onCancel: () {},
            onDelete: () async {},
            onSave: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final button = tester.widget<ButtonStyleButton>(
      find.bySubtype<ElevatedButton>(),
    );
    return button.style?.backgroundColor?.resolve(<WidgetState>{});
  }

  testWidgets('밝은 모드 저장 버튼은 앱 메인 네이비이고 어두운 모드는 테마색을 쓴다', (tester) async {
    expect(
      await saveButtonColor(tester, lightTheme()),
      AppColors.deepNavy,
    );
    expect(await saveButtonColor(tester, darkTheme()), isNull);
  });
}
