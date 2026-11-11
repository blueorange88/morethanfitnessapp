import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/form_error_focus.dart';

class _Harness extends StatefulWidget {
  const _Harness();

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  final formKey = GlobalKey<FormState>();
  final name = FocusNode();
  final phone = FocusNode();
  final anchor = GlobalKey();
  final plain = FocusNode();

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    plain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      key: const ValueKey('name'),
                      focusNode: name,
                      validator:
                          (v) => (v ?? '').isEmpty ? '이름을 입력해 주세요' : null,
                    ),
                    const SizedBox(height: 900),
                    TextFormField(
                      key: const ValueKey('phone'),
                      focusNode: phone,
                      validator:
                          (v) => (v ?? '').isEmpty ? '연락처를 입력해 주세요' : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 900),
              TextField(key: const ValueKey('plain'), focusNode: plain),
              SizedBox(key: anchor, height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

void main() {
  testWidgets('Form 검증이 실패하면 맨 위의 틀린 칸으로 이동하고 커서를 놓는다', (tester) async {
    await tester.pumpWidget(const _Harness());
    final state = tester.state<_HarnessState>(find.byType(_Harness));
    // 아래쪽 연락처만 채우면 위쪽 이름이 첫 오류다.
    await tester.enterText(find.byKey(const ValueKey('phone')), '010');
    expect(state.formKey.currentState!.validate(), isFalse);
    // 다음 프레임을 기다리므로 테스트에서는 프레임을 직접 넘겨 준다.
    final moving = focusFirstInvalidFormField(state.formKey.currentContext);
    await tester.pumpAndSettle();
    expect(await moving, isTrue);
    expect(state.name.hasFocus, isTrue);
    expect(state.phone.hasFocus, isFalse);
  });

  testWidgets('여러 칸이 틀리면 화면에서 가장 위에 있는 칸을 고른다', (tester) async {
    await tester.pumpWidget(const _Harness());
    final state = tester.state<_HarnessState>(find.byType(_Harness));
    expect(state.formKey.currentState!.validate(), isFalse);
    final moving = focusFirstInvalidFormField(state.formKey.currentContext);
    await tester.pumpAndSettle();
    await moving;
    expect(state.name.hasFocus, isTrue);
  });

  testWidgets('오류가 없으면 아무것도 하지 않는다', (tester) async {
    await tester.pumpWidget(const _Harness());
    final state = tester.state<_HarnessState>(find.byType(_Harness));
    await tester.enterText(find.byKey(const ValueKey('name')), '홍');
    await tester.enterText(find.byKey(const ValueKey('phone')), '010');
    expect(state.formKey.currentState!.validate(), isTrue);
    final moving = focusFirstInvalidFormField(state.formKey.currentContext);
    await tester.pumpAndSettle();
    expect(await moving, isFalse);
  });

  testWidgets('revealAndFocus는 위치로 스크롤하고 글자 칸에 커서를 놓는다', (tester) async {
    await tester.pumpWidget(const _Harness());
    final state = tester.state<_HarnessState>(find.byType(_Harness));
    final moving = revealAndFocus(
      anchorContext: state.anchor.currentContext,
      focusNode: state.plain,
    );
    await tester.pumpAndSettle();
    await moving;
    expect(state.plain.hasFocus, isTrue);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('plain'))).dy,
      lessThan(600),
    );
    // 포커스 칸을 넘기지 않으면 이동만 한다(날짜·선택 칸).
    state.plain.unfocus();
    await tester.pump();
    final onlyMove = revealAndFocus(anchorContext: state.anchor.currentContext);
    await tester.pumpAndSettle();
    await onlyMove;
    expect(state.plain.hasFocus, isFalse);
  });
}
