import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/home/lesson_editor/home_lesson_editor_fields.dart';

Widget _host({
  required TextEditingController name,
  required TextEditingController count,
  FocusNode? nameFocusNode,
}) {
  return MaterialApp(
    home: Scaffold(
      body: HomeLessonMemberInputSection(
        nameController: name,
        sessionCountController: count,
        nameFocusNode: nameFocusNode,
        hasLinkedMember: false,
        onNameTap: () {},
        onNameChanged: (_) {},
        onClearName: name.clear,
        showAutocompleteDropdown: false,
      ),
    ),
  );
}

void main() {
  testWidgets('바깥에서 넘긴 포커스로 이름 칸에 커서를 놓을 수 있다', (tester) async {
    final name = TextEditingController();
    final count = TextEditingController();
    final focus = FocusNode();
    addTearDown(name.dispose);
    addTearDown(count.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      _host(name: name, count: count, nameFocusNode: focus),
    );
    expect(focus.hasFocus, isFalse);

    // 저장할 때 이름이 비어 있으면 홈 화면이 하는 것과 같은 요청.
    focus.requestFocus();
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('home_lesson_member_name_field')),
          )
          .focusNode,
      same(focus),
    );
  });

  testWidgets('포커스를 넘기지 않아도 기존처럼 동작하고 위젯을 닫아도 넘겨 받은 포커스는 남는다', (tester) async {
    final name = TextEditingController();
    final count = TextEditingController();
    final focus = FocusNode();
    addTearDown(name.dispose);
    addTearDown(count.dispose);
    addTearDown(focus.dispose);

    await tester.pumpWidget(_host(name: name, count: count));
    await tester.tap(find.byKey(const Key('home_lesson_member_name_field')));
    await tester.pump();
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('home_lesson_member_name_field')),
          )
          .focusNode!
          .hasFocus,
      isTrue,
    );

    // 넘겨 받은 포커스는 위젯이 정리하지 않는다(바깥 소유).
    await tester.pumpWidget(
      _host(name: name, count: count, nameFocusNode: focus),
    );
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(() => focus.requestFocus(), returnsNormally);
  });
}
