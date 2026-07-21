import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/home/lesson_editor/home_member_connection_hint.dart';

void main() {
  testWidgets('회원 선택 안내 문구를 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomeMemberConnectionHintBubble(
            visible: true,
            message: '등록된 회원이라면 아래 회원 칩을 선택해주세요.',
            isLinked: false,
          ),
        ),
      ),
    );

    expect(
      find.text('등록된 회원이라면 아래 회원 칩을 선택해주세요.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
  });

  testWidgets('회원 연결 완료 문구를 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: HomeMemberConnectionHintBubble(
            visible: true,
            message: '회원카드와 연결했어요.',
            isLinked: true,
          ),
        ),
      ),
    );

    expect(find.text('회원카드와 연결했어요.'), findsOneWidget);
    expect(find.byIcon(Icons.link_rounded), findsOneWidget);
  });
}
