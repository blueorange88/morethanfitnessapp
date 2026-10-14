import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
