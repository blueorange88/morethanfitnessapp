import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/home/lesson_editor/home_recent_members_section.dart';

void main() {
  Widget buildChip({
    String name = '홍길동',
    String phone = '010-1234-5678',
    VoidCallback? onTap,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: HomeRecentMemberChip(
            name: name,
            phone: phone,
            onTap: onTap ?? () {},
          ),
        ),
      ),
    );
  }

  testWidgets('원형 사람 아이콘과 이름 전화번호 뒤 4자리를 표시한다', (tester) async {
    await tester.pumpWidget(buildChip());

    expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);
    expect(find.text('홍길동'), findsOneWidget);
    expect(find.text(' · '), findsOneWidget);
    expect(find.text('5678'), findsOneWidget);
  });

  testWidgets('긴 이름만 ellipsis 처리하고 전화번호는 별도 표시한다', (tester) async {
    await tester.pumpWidget(
      buildChip(name: '매우긴회원이름테스트', phone: '01099991234'),
    );

    final nameText = tester.widget<Text>(find.text('매우긴회원이름테스트'));
    final phoneText = tester.widget<Text>(find.text('1234'));

    expect(nameText.maxLines, 1);
    expect(nameText.overflow, TextOverflow.ellipsis);
    expect(phoneText.overflow, isNull);
  });

  testWidgets('칩을 탭한 경우에만 선택 callback을 실행한다', (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(buildChip(onTap: () => tapCount++));

    expect(tapCount, 0);
    await tester.tap(find.text('홍길동'));
    await tester.pump();
    expect(tapCount, 1);
  });
}
