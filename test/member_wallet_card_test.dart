import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/member.dart';
import 'package:mtf_app/pages/client_list_page.dart';
import 'package:mtf_app/theme/app_colors.dart';

Member _member({
  int remaining = 12,
  int total = 30,
  int? expireInDays = 40,
  String status = '활성',
  String? grade,
}) {
  final today = DateTime.now();
  return Member(
    id: 'member-wallet',
    name: '김혜림',
    remainingSessions: remaining,
    totalSessions: total,
    grade: grade,
    expireAt:
        expireInDays == null
            ? null
            : DateTime(today.year, today.month, today.day + expireInDays),
    memberStatus: status,
    gender: Gender.unknown,
  );
}

Widget _host({
  required Member member,
  bool expanded = false,
  VoidCallback? onToggle,
  VoidCallback? onEdit,
  VoidCallback? onLog,
}) {
  return MaterialApp(
    theme: lightTheme(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 360,
          child: MemberWalletCard(
            member: member,
            displayGroupLabel: 'MORE THAN GYM',
            groupMenuItems: const [],
            isPinned: false,
            isExpanded: expanded,
            isLastInSection: true,
            onToggleExpanded: onToggle ?? () {},
            onPinTap: () {},
            onEditTap: onEdit ?? () {},
            onLogTap: onLog ?? () {},
            onQuickGroupChanged: (_) {},
            onAnyInteraction: () {},
          ),
        ),
      ),
    ),
  );
}

Finder _warningPills() => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> &&
      key.value.startsWith('member_wallet_card_warning_');
});

void main() {
  testWidgets('접힌 카드는 그룹·이름·남은 레슨과 회원권만 보이고 회차 미등록은 숨긴다', (tester) async {
    await tester.pumpWidget(_host(member: _member()));

    expect(find.text('MORE THAN GYM'), findsOneWidget);
    expect(find.text('김혜림님'), findsOneWidget);
    expect(find.text('잔여 12회'), findsOneWidget);
    expect(find.text('회원권-40'), findsOneWidget);
    expect(find.text('레슨일지'), findsNothing);

    await tester.pumpWidget(_host(member: _member(total: 0, remaining: 0)));
    expect(find.text('회차 미등록'), findsNothing);
    expect(find.textContaining('잔여'), findsNothing);
  });

  testWidgets('잔여 5회 미만과 회원권 10일 이내만 경고 알약으로 표시한다', (tester) async {
    await tester.pumpWidget(_host(member: _member()));
    expect(_warningPills(), findsNothing);

    await tester.pumpWidget(_host(member: _member(remaining: 3)));
    expect(_warningPills(), findsOneWidget);

    // 레슨이 남았는데 기간이 곧 끝나면 두 알약이 아니라 소멸 위험 알약 하나로 알린다.
    await tester.pumpWidget(
      _host(member: _member(remaining: 3, expireInDays: 5)),
    );
    expect(_warningPills(), findsOneWidget);
    expect(find.text('잔여 3회 · D-5 소멸'), findsOneWidget);

    // 휴면·만료 회원은 경고 대신 상태만 보인다.
    await tester.pumpWidget(_host(member: _member(remaining: 3, status: '휴면')));
    expect(_warningPills(), findsNothing);
    expect(find.text('휴면'), findsOneWidget);
  });

  testWidgets('소멸 위험: 레슨이 남았고 기간이 14일 안에 끝날 때만 한 알약으로 알린다', (tester) async {
    // 잔여가 많아도 기간이 곧 끝나면 소멸 위험이다.
    await tester.pumpWidget(
      _host(member: _member(remaining: 12, expireInDays: 14)),
    );
    expect(find.text('잔여 12회 · D-14 소멸'), findsOneWidget);
    expect(_warningPills(), findsOneWidget);

    await tester.pumpWidget(
      _host(member: _member(remaining: 2, expireInDays: 0)),
    );
    expect(find.text('잔여 2회 · 오늘 소멸'), findsOneWidget);

    // 15일 이상 남았거나, 남은 레슨이 없거나, 활성이 아니면 소멸 위험이 아니다.
    await tester.pumpWidget(
      _host(member: _member(remaining: 12, expireInDays: 15)),
    );
    expect(find.textContaining('소멸'), findsNothing);
    await tester.pumpWidget(
      _host(member: _member(remaining: 0, expireInDays: 3)),
    );
    expect(find.textContaining('소멸'), findsNothing);
    await tester.pumpWidget(
      _host(member: _member(remaining: 2, expireInDays: 3, status: '휴면')),
    );
    expect(find.textContaining('소멸'), findsNothing);

    // 펼친 카드의 이슈 칩에도 같은 문구가 한 번 더 나온다.
    await tester.pumpWidget(
      _host(member: _member(remaining: 2, expireInDays: 3), expanded: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('잔여 2회 · D-3 소멸'), findsNWidgets(2));
  });

  testWidgets('이슈 칩은 접힌 줄에 개수(+N)로만 보인다', (tester) async {
    await tester.pumpWidget(
      _host(member: _member(remaining: 2, expireInDays: 5)),
    );

    final badge = find.byKey(
      const ValueKey<String>('member_wallet_card_issues'),
    );
    expect(badge, findsOneWidget);
    expect(find.textContaining('+'), findsOneWidget);
  });

  testWidgets('펼친 카드는 윗줄을 눌러도 고객카드로 가고 레슨일지 버튼은 따로 동작한다', (tester) async {
    var toggled = 0;
    var edited = 0;
    var logged = 0;

    await tester.pumpWidget(
      _host(
        member: _member(),
        expanded: true,
        onToggle: () => toggled++,
        onEdit: () => edited++,
        onLog: () => logged++,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('레슨일지'), findsOneWidget);
    expect(find.text('총 30회 / 12회 남음 · 회원권-40'), findsOneWidget);

    // 펼친 카드는 윗줄(이름)을 눌러도 닫히지 않고 고객카드로 간다.
    await tester.tap(find.text('김혜림님'));
    expect(edited, 1);
    expect(toggled, 0);

    await tester.tap(find.textContaining('다음 미정'));
    expect(edited, 2);
    expect(toggled, 0);

    await tester.tap(find.text('레슨일지'));
    expect(logged, 1);
    expect(edited, 2);
  });

  testWidgets('카드 색은 고객카드 등급 색을 따르고 접힌 높이는 62다', (tester) async {
    await tester.pumpWidget(_host(member: _member(grade: 'GOLD')));

    final face = tester.widget<DecoratedBox>(
      find.byKey(
        const ValueKey<String>('member_wallet_card_face_member-wallet'),
      ),
    );
    final gradient =
        (face.decoration as BoxDecoration).gradient as LinearGradient;
    expect(gradient.colors.first, const Color(0xFFB45309));

    // 마지막 카드는 아래로 겹친 만큼(22)을 더해 비워 둔다.
    final box = tester.getSize(find.byType(MemberWalletCard));
    expect(
      box.height,
      MemberWalletCard.collapsedHeight + MemberWalletCard.overlap,
    );
  });

  testWidgets('320dp 좁은 화면에서도 긴 이름과 경고가 넘치지 않는다', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(320, 720));

    final member = Member(
      id: 'member-wallet',
      name: '매우 긴 회원 이름 테스트용',
      remainingSessions: 3,
      totalSessions: 120,
      expireAt: DateTime.now().add(const Duration(days: 4)),
      memberStatus: '활성',
      gender: Gender.unknown,
    );
    await tester.pumpWidget(_host(member: member, expanded: true));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
  testWidgets('마지막 카드는 접혔을 때 아래 여백에 다음·최근 레슨을 보여 온전한 카드로 보인다', (tester) async {
    await tester.pumpWidget(_host(member: _member()));
    expect(
      find.byKey(const ValueKey<String>('member_wallet_card_last_info')),
      findsOneWidget,
    );

    expect(find.text('총 30회 / 12회 남음 · 회원권-40'), findsOneWidget);

    // 펼치면 그 줄은 본문으로 옮겨가고 아래 여백이 사라진다.
    await tester.pumpWidget(_host(member: _member(), expanded: true));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('member_wallet_card_last_info')),
      findsNothing,
    );
    final box = tester.getSize(find.byType(MemberWalletCard));
    expect(
      box.height,
      MemberWalletCard.collapsedHeight + MemberWalletCard.expandedExtraHeight,
    );
  });

  testWidgets('접힌 카드는 어디를 눌러도 펼치고 펼친 카드의 아랫부분은 고객카드로 간다', (tester) async {
    var toggled = 0;
    var edited = 0;
    await tester.pumpWidget(
      _host(
        member: _member(),
        onToggle: () => toggled++,
        onEdit: () => edited++,
      ),
    );
    // 마지막 접힌 카드의 아래 여백(62px 아래)을 눌러도 펼침.
    final top = tester.getTopLeft(find.byType(MemberWalletCard));
    await tester.tapAt(top + const Offset(200, 75));
    expect(toggled, 1);
    expect(edited, 0);
  });

  testWidgets('목록 끝의 등록 카드는 카드 크기로 문구가 보이고 누르면 등록으로 간다', (tester) async {
    var tapped = 0;
    Rect? tappedRect;
    Widget? tappedFace;
    await tester.pumpWidget(
      MaterialApp(
        theme: lightTheme(),
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 360,
              child: MemberAddCard(
                onTap: (rect, face) {
                  tapped++;
                  tappedRect = rect;
                  tappedFace = face;
                },
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('새로운 회원 등록하기'), findsOneWidget);
    expect(find.text(MemberAddCard.messages[0]), findsOneWidget);
    expect(find.byIcon(Icons.person_add_alt_1_rounded), findsOneWidget);
    expect(
      tester.getSize(find.byType(MemberAddCard)).height,
      MemberAddCard.height,
    );

    // 안내 문구는 4초마다 다음 문구로 바뀐다.
    await tester.pump(MemberAddCard.rotateEvery);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(MemberAddCard.messages[1]), findsOneWidget);
    expect(find.text(MemberAddCard.messages[0]), findsNothing);

    // 누르는 즉시 전환이 시작되고(기다림 없음), 카드 위치와 얼굴이 함께 넘어간다.
    await tester.tap(
      find.descendant(
        of: find.byType(MemberAddCard),
        matching: find.byType(InkWell),
      ),
    );
    expect(tapped, 1);
    expect(tappedRect, isNotNull);
    expect(tappedRect!.height, greaterThan(MemberAddCard.height * 0.9));
    expect(tappedFace, isNotNull);
    await tester.pump(MemberAddCard.shineDuration);
  });

  walletListTests();
}

class _WalletListHarness extends StatefulWidget {
  const _WalletListHarness();

  @override
  State<_WalletListHarness> createState() => _WalletListHarnessState();
}

class _WalletListHarnessState extends State<_WalletListHarness> {
  final ValueNotifier<String?> expanded = ValueNotifier<String?>(null);
  final List<String> edited = <String>[];

  @override
  void dispose() {
    expanded.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final names = ['김혜림', '박지훈', '이서연', '최민수', '정다은'];
    return MaterialApp(
      theme: lightTheme(),
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            ListenableBuilder(
              listenable: expanded,
              builder: (context, _) {
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, listIndex) {
                      if (listIndex == 0) {
                        return const SizedBox(height: 40, child: Text('구분선'));
                      }
                      final index = listIndex - 1;
                      final id = 'm$index';
                      return KeyedSubtree(
                        key: GlobalKey(),
                        child: MemberWalletCard(
                          key: ValueKey('member_wallet_card_$id'),
                          member: Member(
                            id: id,
                            name: names[index],
                            remainingSessions: 12,
                            totalSessions: 30,
                            memberStatus: '활성',
                            gender: Gender.unknown,
                          ),
                          displayGroupLabel: 'MORE THAN GYM',
                          groupMenuItems: const [],
                          isPinned: false,
                          isExpanded: expanded.value == id,
                          isLastInSection: index == names.length - 1,
                          onToggleExpanded:
                              () =>
                                  expanded.value =
                                      expanded.value == id ? null : id,
                          onPinTap: () {},
                          onEditTap: () => edited.add(id),
                          onLogTap: () {},
                          onQuickGroupChanged: (_) {},
                          onAnyInteraction: () {},
                        ),
                      );
                    }, childCount: names.length + 1),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

void walletListTests() {
  testWidgets('스크롤된 상태에서도 윗줄 탭으로 열고, 열린 카드의 윗줄은 고객카드로 간다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const _WalletListHarness());
    final state = tester.state<_WalletListHarnessState>(
      find.byType(_WalletListHarness),
    );
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -60));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이서연님'));
    await tester.pumpAndSettle();
    expect(state.expanded.value, 'm2');
    await tester.tap(find.text('이서연님'));
    await tester.pumpAndSettle();
    expect(state.expanded.value, 'm2');
    expect(state.edited, ['m2']);
  });

  testWidgets('스크롤 목록 안에서 윗줄을 누르면 펼쳐지고 다시 누르면 고객카드로 간다', (tester) async {
    await tester.pumpWidget(const _WalletListHarness());
    final state = tester.state<_WalletListHarnessState>(
      find.byType(_WalletListHarness),
    );

    await tester.tap(find.text('박지훈님'));
    await tester.pumpAndSettle();
    expect(state.expanded.value, 'm1');
    expect(find.text('레슨일지'), findsOneWidget);

    // 열린 카드의 이름줄을 다시 누르면 닫히지 않고 고객카드로 간다.
    await tester.tap(find.text('박지훈님'));
    await tester.pumpAndSettle();
    expect(state.expanded.value, 'm1');
    expect(state.edited, ['m1']);

    // 카드 윗줄의 이름 없는 빈 곳(왼쪽 위 모서리 근처)을 눌러도 동작한다.
    final top = tester.getTopLeft(
      find.byKey(const ValueKey('member_wallet_card_face_m2')),
    );
    await tester.tapAt(top + const Offset(120, 30));
    await tester.pumpAndSettle();
    expect(state.expanded.value, 'm2');

    // 다른 카드를 누르면 열린 카드는 자동으로 닫히고 새 카드가 열린다.
    await tester.tap(find.text('최민수님'));
    await tester.pumpAndSettle();
    expect(state.expanded.value, 'm3');
    expect(find.text('레슨일지'), findsOneWidget);
  });
}
