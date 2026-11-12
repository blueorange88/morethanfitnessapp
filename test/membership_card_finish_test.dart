import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/mtf_back_button.dart';
import 'package:mtf_app/widgets/mtf_header_neon_overlay.dart';
import 'package:mtf_app/pages/client_card_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _card({
  String grade = 'BRONZE',
  String group = '그룹 없음',
  VoidCallback? onBack,
  VoidCallback? onContract,
  String lesson = 'PT',
  int total = 30,
  int remain = 12,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: MembershipCardFlip(
          onBackTap: onBack ?? () {},
          onMoreSelected: (_) {},
          gradientColors: const [
            Color(0xFF78350F),
            Color(0xFF92400E),
            Color(0xFFB45309),
          ],
          icChipColors: const [Color(0xFFFCD7AA), Color(0xFF92400E)],
          avatarImage: null,
          onAvatarTap: () {},
          onAvatarLongPress: () {},
          name: '홍길동',
          phone: '010-1234-5678',
          lessonType: lesson,
          totalSessions: total,
          remainSessions: remain,
          membershipLabel: grade,
          membershipPeriod: '26.10.01 - 27.01.01',
          daysLeft: 20,
          groupLabel: group,
          memoText: '',
          reregisterCount: 1,
          noShowDeductedCount: 0,
          noShowUndeductedCount: 0,
          serviceCount: 0,
          firstRegisteredAt: null,
          anniversaryLabel: '',
          anniversaryDate: null,
          birthdayDate: null,
          contractSigned: true,
          contractSignedAt: null,
          consentAgreed: false,
          confirmTalkEnabled: false,
          onMemoTap: () {},
          onContractTap: onContract ?? () {},
          onConsentTap: () {},
          onConfirmTalkToggle: (_) {},
          badges: const [],
          onBadgeTap: (_) {},
        ),
      ),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> useSize(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Matrix4 tiltOf(WidgetTester tester) {
    final card = find.byKey(const ValueKey('membership_card_tilt'));
    return tester
        .widgetList<Transform>(
          find.descendant(of: card, matching: find.byType(Transform)),
        )
        .first
        .transform;
  }

  testWidgets('카드는 광택 레이어를 그리고, 처음 한 번 지나가는 반사광이 끝나면 멈춘다', (tester) async {
    // 안내 흔들림은 따로 시험하므로 여기서는 이미 본 것으로 둔다.
    SharedPreferences.setMockInitialValues({
      'membership_card_flip_hint_count': 3,
    });
    await tester.pumpWidget(_card());
    expect(find.byKey(const ValueKey('membership_card_sheen')), findsOneWidget);
    expect(find.textContaining('홍길동'), findsOneWidget);
    // 반사광이 끝나야 더 이상 프레임을 요청하지 않는다(계속 도는 효과가 없다).
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 700));
    // 헤더 네온 선(다른 페이지와 같은 것)도 한 번 그려지고 끝난다.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('가로로 끌면 기울고, 손을 떼면 제자리로 돌아온다', (tester) async {
    await tester.pumpWidget(_card());
    await tester.pump(const Duration(seconds: 2));
    final card = find.byKey(const ValueKey('membership_card_tilt'));
    final gesture = await tester.startGesture(
      tester.getCenter(card) + const Offset(0, 60),
    );
    await gesture.moveBy(const Offset(60, 0));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();

    Matrix4 tilt() =>
        tester
            .widgetList<Transform>(
              find.descendant(of: card, matching: find.byType(Transform)),
            )
            .first
            .transform;
    final tilted = tilt().storage[2]; // rotateY 성분
    expect(tilted.abs(), greaterThan(0.01));

    await gesture.up();
    await tester.pump(); // 되돌아오는 애니메이션 시작
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tilt().storage[2].abs(), lessThan(0.001));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('애니메이션 줄이기 설정이면 반사광도 기울기도 움직이지 않는다', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _card(),
      ),
    );
    // 보이지 않는 헤더 네온 컨트롤러가 첫 프레임 뒤에 시작하므로 두 번 넘겨서 끝낸다.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.hasRunningAnimations, isFalse);
    final card = find.byKey(const ValueKey('membership_card_tilt'));
    final gesture = await tester.startGesture(
      tester.getCenter(card) + const Offset(0, 60),
    );
    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();
    final transform =
        tester
            .widgetList<Transform>(
              find.descendant(of: card, matching: find.byType(Transform)),
            )
            .first
            .transform;
    expect(transform.storage[2].abs(), lessThan(0.0001));
    await gesture.up();
  });

  test('새 회원카드는 BRONZE로 시작하고 VIP는 흑색 금속 팔레트다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();
    expect(source, contains("String _membershipGrade = 'BRONZE';"));
    expect(source, isNot(contains("_membershipGrade = 'GOLD'")));
    expect(source, isNot(contains("? value : 'GOLD'")));
    expect(source, contains('Color(0xFF0F172A), Color(0xFF1F2937)'));
    expect(source, contains('LinearGradient _metallicGradient('));
  });

  testWidgets('카드가 곧 헤더다: 그룹 이름이 윗줄 제목이고 뒤로가기·계약서가 카드 안 윗줄에 있다', (
    tester,
  ) async {
    var back = 0;
    var contract = 0;
    await tester.pumpWidget(
      _card(group: '모어짐', onBack: () => back++, onContract: () => contract++),
    );
    await tester.pump(const Duration(seconds: 2));
    final title = find.byKey(const ValueKey('membership_card_group_title'));
    expect(tester.widget<Text>(title).data, '모어짐');
    // 카드라는 것은 모양으로 알 수 있어서 MEMBERSHIP CARD 글자는 없다.
    expect(find.text('MEMBERSHIP CARD'), findsNothing);
    expect(find.textContaining('MORE THAN GYM'), findsNothing);

    // 카드(헤더)는 화면 폭을 채운다.
    final header = find.byKey(const ValueKey('membership_card_header'));
    expect(header, findsOneWidget);
    expect(tester.getSize(header).width, 800);
    expect(
      (tester.widget<Container>(header).decoration! as BoxDecoration).gradient,
      isNotNull,
    );
    // 뒤로가기는 카드 안 윗줄의 흰색 < 다.
    final card = find.byKey(const ValueKey('membership_card_tilt'));
    expect(
      tester.widget<MtfBackButton>(find.byType(MtfBackButton)).color,
      Colors.white,
    );
    expect(
      find.descendant(of: card, matching: find.byType(MtfBackButton)),
      findsOneWidget,
    );
    await tester.tap(find.byType(MtfBackButton));
    await tester.tap(find.byKey(const ValueKey('membership_card_contract')));
    expect(back, 1);
    expect(contract, 1);
    // 앞면에는 뒤집기 버튼이 없다.
    expect(
      find.byKey(const ValueKey('membership_card_flip_button')),
      findsNothing,
    );
  });

  testWidgets('상태 표시줄 영역은 비워 두고 카드는 그 아래에서 시작하며 네온 선은 없다', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 40)),
        child: _card(),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    final header = find.byKey(const ValueKey('membership_card_header'));
    expect(tester.getTopLeft(header).dy, 40);
    expect(tester.getSize(header).height, MembershipCardFlip.cardHeight);
    expect(find.byType(MtfHeaderNeonOverlay), findsNothing);
    // 윗모서리도 아래와 같이 둥글다(상태바 줄이 비어 있어 카드가 떠 있는 모양).
    expect(
      (tester.widget<Container>(header).decoration! as BoxDecoration)
          .borderRadius,
      BorderRadius.circular(MembershipCardFlip.headerBottomRadius),
    );
    // 대표 훈장이 없으면 진짜 IC 칩 모양 칩이 앞면에 있다.
    expect(
      tester.getSize(find.byKey(const ValueKey('membership_card_ic_chip'))),
      const Size(52, 40),
    );
  });

  testWidgets('이름 아래에 종류·잔여 횟수와 기간이 붙고 등급은 이름 오른쪽에 있다', (tester) async {
    await tester.pumpWidget(_card());
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('membership_card_remaining')))
          .data,
      'PT · 잔여 12/30회',
    );
    expect(find.text('BRONZE'), findsOneWidget);
    expect(find.text('REMAINING'), findsNothing);
    expect(find.textContaining('D-20'), findsOneWidget);
    // 등급은 이름과 같은 줄(오른쪽)이다.
    final name = tester.getTopLeft(find.textContaining('홍길동')).dy;
    final grade = tester.getTopLeft(find.text('BRONZE')).dy;
    expect((name - grade).abs(), lessThan(12));
    expect(
      tester.getTopLeft(find.text('BRONZE')).dx,
      greaterThan(tester.getTopLeft(find.textContaining('홍길동')).dx),
    );
  });

  testWidgets('횟수가 0/0이면 숨기고 종류도 없으면 미등록이라고 보여 준다', (tester) async {
    await tester.pumpWidget(_card(lesson: 'PT', total: 0, remain: 0));
    await tester.pump(const Duration(seconds: 2));
    Text line() => tester.widget<Text>(
      find.byKey(const ValueKey('membership_card_remaining')),
    );
    expect(line().data, 'PT');
    await tester.pumpWidget(_card(lesson: '미입력', total: 0, remain: 0));
    await tester.pump(const Duration(seconds: 2));
    expect(line().data, '미등록');
  });

  testWidgets('메달 5칸이 앞면 아래에 있다', (tester) async {
    await tester.pumpWidget(_card());
    await tester.pump(const Duration(seconds: 2));
    // 빈 칸은 + 표시 없이 희미한 선만 남는다.
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    final header = tester.getRect(
      find.byKey(const ValueKey('membership_card_header')),
    );
    final remaining = tester.getBottomLeft(
      find.byKey(const ValueKey('membership_card_remaining')),
    );
    expect(remaining.dy, lessThan(header.bottom - 40));
  });

  testWidgets('그룹이 없으면 기본 이름을 보여 주고 영문은 대문자로 맞춘다', (tester) async {
    await tester.pumpWidget(_card(group: ''));
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('membership_card_group_title')),
          )
          .data,
      'MORE THAN GYM',
    );
    await tester.pumpWidget(_card(group: 'vip club'));
    await tester.pump(const Duration(seconds: 2));
    expect(
      tester
          .widget<Text>(
            find.byKey(const ValueKey('membership_card_group_title')),
          )
          .data,
      'VIP CLUB',
    );
  });

  for (final width in [320.0, 360.0, 412.0]) {
    testWidgets('앞면과 뒷면 모두 폭 ${width.toInt()}에서 넘치지 않는다', (tester) async {
      await useSize(tester, width);
      await tester.pumpWidget(_card(group: '아주 긴 그룹 이름을 가진 모어짐 강남 본점'));
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull, reason: '앞면');

      await tester.fling(
        find.byKey(const ValueKey('membership_card_tilt')),
        const Offset(-200, 0),
        1200,
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('MORE 데이'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '뒷면');
    });
  }

  Future<void> settleFlip(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('오른쪽에서 왼쪽으로 던지면 뒤집히고, 뒷면에서는 어느 쪽으로 던져도 돌아온다', (tester) async {
    await tester.pumpWidget(_card());
    await tester.pump(const Duration(seconds: 3));
    final card = find.byKey(const ValueKey('membership_card_tilt'));
    expect(find.text('MORE 데이'), findsNothing);

    await tester.fling(card, const Offset(-220, 0), 1200);
    await settleFlip(tester);
    expect(find.text('MORE 데이'), findsOneWidget);

    await tester.fling(card, const Offset(220, 0), 1200);
    await settleFlip(tester);
    expect(find.text('MORE 데이'), findsNothing);

    await tester.fling(card, const Offset(-220, 0), 1200);
    await settleFlip(tester);
    expect(find.text('MORE 데이'), findsOneWidget);
    await tester.fling(card, const Offset(-220, 0), 1200);
    await settleFlip(tester);
    expect(find.text('MORE 데이'), findsNothing);
  });

  testWidgets('앞면에서 오른쪽으로 밀거나 조금만 끌면 기울기만 있고 뒤집히지 않는다', (tester) async {
    await tester.pumpWidget(_card());
    await tester.pump(const Duration(seconds: 3));
    final card = find.byKey(const ValueKey('membership_card_tilt'));

    await tester.fling(card, const Offset(220, 0), 1200);
    await settleFlip(tester);
    expect(find.text('MORE 데이'), findsNothing);

    // 짧고 느리게 끌면 뒤집히지 않는다.
    final gesture = await tester.startGesture(tester.getCenter(card));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await settleFlip(tester);
    expect(find.text('MORE 데이'), findsNothing);
  });

  testWidgets('화면 가장자리에서 시작한 끌기는 뒤로 가기에 양보해 뒤집지 않는다', (tester) async {
    await tester.pumpWidget(_card());
    await tester.pump(const Duration(seconds: 3));
    final card = find.byKey(const ValueKey('membership_card_tilt'));
    final start = Offset(20, tester.getCenter(card).dy);
    await tester.timedDragFrom(
      start,
      const Offset(-200, 0),
      const Duration(milliseconds: 120),
    );
    await settleFlip(tester);
    expect(find.text('MORE 데이'), findsNothing);
  });

  testWidgets('애니메이션 줄이기 설정이어도 던져서 뒤집기는 된다', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: _card(),
      ),
    );
    final card = find.byKey(const ValueKey('membership_card_tilt'));
    await tester.fling(card, const Offset(-220, 0), 1200);
    await settleFlip(tester);
    expect(find.text('MORE 데이'), findsOneWidget);
  });

  testWidgets('뒷면은 맨 아래에 마그네틱 줄이 깔리고, 씰은 줄과 겹치지 않으며 씰을 누르면 앞면으로 돌아온다', (
    tester,
  ) async {
    var back = 0;
    await tester.pumpWidget(_card(onBack: () => back++));
    await tester.pump(const Duration(seconds: 3));
    expect(
      find.byKey(const ValueKey('membership_card_back_stripe')),
      findsNothing,
    );
    await tester.fling(
      find.byKey(const ValueKey('membership_card_tilt')),
      const Offset(-220, 0),
      1200,
    );
    await settleFlip(tester);

    final stripe = tester.getRect(
      find.byKey(const ValueKey('membership_card_back_stripe')),
    );
    final seal = tester.getRect(
      find.byKey(const ValueKey('membership_card_flip_back_button')),
    );
    final header = tester.getRect(
      find.byKey(const ValueKey('membership_card_header')),
    );
    // 줄은 화면 폭 끝에서 끝까지, 카드 맨 아래에 있다.
    expect(stripe.width, closeTo(header.width, 1));
    expect(header.bottom - stripe.bottom, lessThan(16));
    // 씰은 줄 바로 위에 있고 둘은 겹치지 않는다.
    expect(seal.size, const Size(44, 44));
    expect(seal.overlaps(stripe), isFalse);
    expect(seal.bottom, lessThanOrEqualTo(stripe.top));
    // 뒷면 윗줄에는 뒤로가기·MORE 데이가 있고 점 세 개 더보기는 없다.
    expect(find.byType(MtfBackButton), findsOneWidget);
    expect(find.byIcon(Icons.more_vert_rounded), findsNothing);
    await tester.tap(find.byType(MtfBackButton));
    expect(back, 1);

    await tester.tap(
      find.byKey(const ValueKey('membership_card_flip_back_button')),
    );
    await settleFlip(tester);
    expect(find.text('MORE 데이'), findsNothing);
  });

  for (final scale in [1.15, 1.3]) {
    testWidgets('글자를 $scale배로 키워도 앞면·뒷면이 헤더 높이 안에 들어간다', (tester) async {
      await useSize(tester, 360);
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(
            size: const Size(360, 800),
            textScaler: TextScaler.linear(scale),
          ),
          child: _card(),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull, reason: '앞면');
      await tester.fling(
        find.byKey(const ValueKey('membership_card_tilt')),
        const Offset(-200, 0),
        1200,
      );
      await settleFlip(tester);
      expect(find.text('MORE 데이'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '뒷면');
    });
  }

  testWidgets('카드의 빈 곳을 누르면 뒤집을 수 있다는 흔들림이 나온다', (tester) async {
    await tester.pumpWidget(_card());
    await tester.pump(const Duration(seconds: 2));
    // 안내 흔들림이 끝날 때까지 기다린 뒤 시작한다.
    await tester.pump(const Duration(seconds: 2));
    expect(tiltOf(tester).storage[2].abs(), lessThan(0.0001));
    final card = find.byKey(const ValueKey('membership_card_tilt'));
    await tester.tapAt(tester.getTopRight(card) + const Offset(-60, 100));
    await tester.pump();
    var moved = false;
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      if (tiltOf(tester).storage[2].abs() > 0.002) moved = true;
    }
    expect(moved, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(tiltOf(tester).storage[2].abs(), lessThan(0.0001));
  });

  testWidgets('뒤집기 안내 흔들림은 처음 3번만 자동으로 나온다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'membership_card_flip_hint_count': 3,
    });
    await tester.pumpWidget(_card());
    await tester.pump(const Duration(seconds: 3));
    var moved = false;
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
      if (tiltOf(tester).storage[2].abs() > 0.002) moved = true;
    }
    expect(moved, isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('membership_card_flip_hint_count'), 3);
  });

  testWidgets('처음 열면 입장 반사광이 끝난 뒤 안내 흔들림이 한 번 나오고 횟수가 올라간다', (tester) async {
    await tester.pumpWidget(_card());
    await tester.pump(const Duration(milliseconds: 1200));
    var moved = false;
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 60));
      if (tiltOf(tester).storage[2].abs() > 0.002) moved = true;
    }
    expect(moved, isTrue);
    await tester.pump(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('membership_card_flip_hint_count'), 1);
  });

  group('접힌 한 줄 헤더', () {
    Widget bar({
      double width = 360,
      VoidCallback? onBack,
      VoidCallback? onExpand,
      String name = '홍길동',
    }) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 700)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                child: MembershipCardCollapsedBar(
                  gradientColors: const [Color(0xFF1F2A5C), Color(0xFF3B4A8F)],
                  icChipColors: const [Color(0xFFE5C879), Color(0xFF9C7B2E)],
                  avatarImage: null,
                  name: name,
                  phone: '010-1234-5678',
                  lessonLine: membershipCardLessonLine(
                    lessonType: 'PT',
                    totalSessions: 30,
                    remainSessions: 12,
                  ),
                  onBackTap: onBack ?? () {},
                  onExpandTap: onExpand ?? () {},
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('이름 옆에 번호와 레슨 현황이 보이고 등급은 없다', (tester) async {
      await tester.pumpWidget(bar());
      final nameBox = tester.getRect(
        find.byKey(const ValueKey<String>('membership_card_collapsed_name')),
      );
      final phoneBox = tester.getRect(
        find.byKey(const ValueKey<String>('membership_card_collapsed_phone')),
      );
      expect(phoneBox.left, greaterThan(nameBox.right - 1));
      expect(phoneBox.center.dy, closeTo(nameBox.center.dy, 4));
      expect(find.text('010-1234-5678'), findsOneWidget);
      expect(find.text('PT · 잔여 12/30회'), findsOneWidget);
      expect(find.text('BRONZE'), findsNothing);
      final header = tester.getRect(
        find.byKey(const ValueKey<String>('membership_card_collapsed')),
      );
      expect(header.height, MembershipCardCollapsedBar.barHeight);
      expect(header.width, 360);
    });

    testWidgets('겹친 가장자리 없이 한 장이고 카드 얼굴에 작은 IC 칩이 있다', (tester) async {
      await tester.pumpWidget(bar());
      final card = tester.getRect(
        find.byKey(const ValueKey<String>('membership_card_collapsed')),
      );
      expect(
        find.byKey(const ValueKey<String>('membership_card_collapsed_layer_1')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('membership_card_collapsed_layer_2')),
        findsNothing,
      );
      expect(card.height, MembershipCardCollapsedBar.totalHeight);
      // IC 칩은 카드 안 오른쪽에 작게 그려진다.
      final chip = tester.getRect(
        find.byKey(const ValueKey<String>('membership_card_ic_chip')),
      );
      expect(chip.right, lessThanOrEqualTo(card.right));
      expect(chip.width, lessThan(52));
    });

    testWidgets('뒤로가기는 뒤로, 나머지 줄은 펼침을 부른다', (tester) async {
      var back = 0;
      var expand = 0;
      await tester.pumpWidget(
        bar(onBack: () => back++, onExpand: () => expand++),
      );
      await tester.tap(find.byType(MtfBackButton));
      expect(back, 1);
      expect(expand, 0);
      await tester.tap(
        find.byKey(const ValueKey<String>('membership_card_collapsed_phone')),
      );
      expect(expand, 1);
    });

    for (final width in <double>[320, 360, 412]) {
      testWidgets('${width.toInt()}dp에서 긴 이름도 넘치지 않는다', (tester) async {
        await tester.pumpWidget(bar(width: width, name: '아주아주긴이름의회원님이름'));
        expect(tester.takeException(), isNull);
      });
    }

    test('레슨 현황 문구는 횟수가 없으면 숨기고 종류도 없으면 미등록이다', () {
      expect(
        membershipCardLessonLine(
          lessonType: 'PT',
          totalSessions: 0,
          remainSessions: 0,
        ),
        'PT',
      );
      expect(
        membershipCardLessonLine(
          lessonType: '미입력',
          totalSessions: 0,
          remainSessions: 0,
        ),
        '미등록',
      );
    });

    test('페이지는 폼 스크롤에 맞춰 접고 맨 위에서 펼친다', () {
      final source = File('lib/pages/client_card_page.dart').readAsStringSync();
      expect(source, contains('controller: _formScrollController'));
      expect(source, contains('AnimatedCrossFade('));
      expect(source, contains('MembershipCardCollapsedBar('));
      final start = source.indexOf('void _syncCardHeaderToScroll()');
      final end = source.indexOf('void _setCardHeaderCollapsed(');
      final sync = source.substring(start, end);
      expect(sync, contains('offset > _cardHeaderCollapseOffset'));
      expect(sync, contains('position.maxScrollExtent - _cardHeaderShrink'));
      expect(sync, contains('offset <= _cardHeaderExpandOffset'));
    });
  });
}
