import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/member.dart';
import 'package:mtf_app/pages/client_list_page.dart';
import 'package:mtf_app/theme/app_colors.dart';

void main() {
  test('고객리스트 회원권 잔여일은 별도 D-DAY와 구분해 표시한다', () {
    expect(membershipExpiryLabel(30), '회원권-30');
    expect(membershipExpiryLabel(1), '회원권-1');
    expect(membershipExpiryLabel(7), '회원권-7');
    expect(membershipExpiryLabel(0), '회원권-0');
    expect(membershipExpiryLabel(-1), '만료');
    expect(membershipExpiryLabel(-3), '만료');
    expect(membershipExpiryLabel(-30), '만료');
  });

  testWidgets('320·360·384·411dp에서 긴 회원명과 회원권 label이 overflow 없이 표시된다',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final today = DateTime.now();
    final member = Member(
      id: 'member-viewport',
      name: '매우 긴 회원 이름 테스트',
      remainingSessions: 119,
      totalSessions: 120,
      expireAt: DateTime(today.year, today.month, today.day + 7),
      anniversaryDate: DateTime(today.year, today.month, today.day + 5),
      anniversaryLabel: '바디프로필',
      memberStatus: '활성',
      gender: Gender.unknown,
    );

    for (final width in const <double>[320, 360, 384, 411]) {
      await tester.binding.setSurfaceSize(Size(width, 720));
      await tester.pumpWidget(
        MaterialApp(
          theme: lightTheme(),
          home: Scaffold(
            body: MemberListRow(
              member: member,
              displayGroupLabel: 'MORE THAN GYM',
              displayGroupAccentColor: const Color(0xFFEFCB62),
              displayGroupTextColor: const Color(0xFF0B1E32),
              groupMenuItems: const [],
              isPinned: false,
              onPinTap: () {},
              onEditTap: () {},
              onLogTap: () {},
              onQuickGroupChanged: (_) {},
              onAnyInteraction: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('회원권-7'), findsWidgets, reason: 'width=$width');
      expect(find.text('바디프로필 D-5'), findsOneWidget, reason: 'width=$width');
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
  });

  testWidgets('회원권이 없으면 기존 미등록 표시를 유지한다', (tester) async {
    const member = Member(
      id: 'member-unregistered',
      name: '미등록 회원',
      remainingSessions: 0,
      totalSessions: 0,
      memberStatus: '활성',
      gender: Gender.unknown,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: Scaffold(
          body: MemberListRow(
            member: member,
            displayGroupLabel: 'MORE THAN GYM',
            displayGroupAccentColor: const Color(0xFFEFCB62),
            displayGroupTextColor: const Color(0xFF0B1E32),
            groupMenuItems: const [],
            isPinned: false,
            onPinTap: () {},
            onEditTap: () {},
            onLogTap: () {},
            onQuickGroupChanged: (_) {},
            onAnyInteraction: () {},
          ),
        ),
      ),
    );

    expect(find.text('회차 미등록'), findsOneWidget);
    expect(find.textContaining('회원권'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('종료일이 지난 활성 회원은 상태 write 없이 회원권 label만 만료로 표시한다', (tester) async {
    final today = DateTime.now();
    final member = Member(
      id: 'member-membership-expired',
      name: '회원권 만료 테스트',
      remainingSessions: 3,
      totalSessions: 10,
      expireAt: DateTime(today.year, today.month, today.day - 3),
      memberStatus: '활성',
      gender: Gender.unknown,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: Scaffold(
          body: MemberListRow(
            member: member,
            displayGroupLabel: 'MORE THAN GYM',
            displayGroupAccentColor: const Color(0xFFEFCB62),
            displayGroupTextColor: const Color(0xFF0B1E32),
            groupMenuItems: const [],
            isPinned: false,
            onPinTap: () {},
            onEditTap: () {},
            onLogTap: () {},
            onQuickGroupChanged: (_) {},
            onAnyInteraction: () {},
          ),
        ),
      ),
    );

    expect(find.text('만료'), findsWidgets);
    expect(find.textContaining('회원권+'), findsNothing);
    expect(member.memberStatus, '활성');
    expect(tester.takeException(), isNull);
  });
}
