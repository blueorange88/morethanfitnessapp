import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/registration_chip.dart';
import 'package:mtf_app/widgets/home/lesson_editor/home_lesson_editor_fields.dart';
import 'package:mtf_app/widgets/home/lesson_editor/home_member_session_caption.dart';

void main() {
  const fallbackKey = Key('fallback_field');

  Future<void> pump(
    WidgetTester tester, {
    required String? memberId,
    required MemberRegistrationLoader loader,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 140,
            child: HomeMemberSessionCaption(
              memberId: memberId,
              loader: loader,
              fallback: const SizedBox(key: fallbackKey, height: 40),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Text caption(WidgetTester tester) =>
      tester.widget<Text>(find.byKey(const Key('home_member_session_caption')));

  testWidgets('연결된 회원의 총/잔여와 추가 횟수를 이름 옆 칸에 보여 준다', (tester) async {
    await pump(
      tester,
      memberId: 'm1',
      loader:
          (_) async => MemberRegistrationInfo(
            total: 60,
            remain: 31,
            notRegistered: false,
            added: 30,
            addedAt: DateTime.now().subtract(const Duration(days: 1)),
          ),
    );
    expect(caption(tester).data, '총 60 / 잔여 31 (+30)');
    expect(find.byKey(const Key('home_member_session_field')), findsOneWidget);
    // 보여 주는 동안은 기본 입력 칸 대신 이 칸이 자리를 차지한다.
    expect(find.byKey(fallbackKey), findsNothing);
    expect(tester.takeException(), isNull, reason: '좁은 칸에서도 넘치지 않는다');
  });

  testWidgets('잔여가 적으면 주황, 소진이면 빨강으로 보인다', (tester) async {
    await pump(
      tester,
      memberId: 'm1',
      loader:
          (_) async => const MemberRegistrationInfo(
            total: 30,
            remain: 2,
            notRegistered: false,
          ),
    );
    expect(caption(tester).style?.color, const Color(0xFFEA580C));

    await pump(
      tester,
      memberId: 'm2',
      loader:
          (_) async => const MemberRegistrationInfo(
            total: 30,
            remain: 0,
            notRegistered: false,
          ),
    );
    expect(caption(tester).data, '총 30 / 잔여 0 · 소진');
    expect(caption(tester).style?.color, const Color(0xFFDC2626));
  });

  testWidgets('미등록·미연결·불러오기 실패면 기본 입력 칸을 그대로 보여 준다', (tester) async {
    await pump(
      tester,
      memberId: 'm3',
      loader:
          (_) async => const MemberRegistrationInfo(
            total: 0,
            remain: 0,
            notRegistered: true,
          ),
    );
    expect(find.byKey(fallbackKey), findsOneWidget);
    expect(find.byKey(const Key('home_member_session_field')), findsNothing);

    var calls = 0;
    await pump(
      tester,
      memberId: null,
      loader: (_) async {
        calls += 1;
        return null;
      },
    );
    expect(find.byKey(fallbackKey), findsOneWidget);
    expect(calls, 0);

    await pump(tester, memberId: 'gone', loader: (_) async => null);
    expect(find.byKey(fallbackKey), findsOneWidget);
  });

  testWidgets('회원이 바뀌면 새 회원의 값을 다시 불러온다', (tester) async {
    final loaded = <String>[];
    Widget build(String id) => MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 140,
          child: HomeMemberSessionCaption(
            memberId: id,
            loader: (memberId) async {
              loaded.add(memberId);
              return MemberRegistrationInfo(
                total: memberId == 'a' ? 10 : 20,
                remain: 10,
                notRegistered: false,
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpWidget(build('a'));
    await tester.pump();
    expect(caption(tester).data, '총 10 / 잔여 10');
    await tester.pumpWidget(build('b'));
    await tester.pump();
    expect(caption(tester).data, '총 20 / 잔여 10');
    expect(loaded, ['a', 'b']);
  });

  testWidgets('이름 칸 옆(같은 줄)에 횟수 칸이 놓이고 안내 글자는 총/잔여횟수다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 600);
    addTearDown(tester.view.reset);
    final name = TextEditingController();
    final count = TextEditingController();
    addTearDown(name.dispose);
    addTearDown(count.dispose);
    for (final linked in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: HomeLessonMemberInputSection(
                nameController: name,
                sessionCountController: count,
                onNameChanged: (_) {},
                onClearName: () {},
                hasLinkedMember: linked,
                onNameTap: () {},
                showAutocompleteDropdown: false,
                sessionCountBuilder:
                    (context, defaultField) => HomeMemberSessionCaption(
                      memberId: linked ? 'm1' : null,
                      loader:
                          (_) async => const MemberRegistrationInfo(
                            total: 60,
                            remain: 31,
                            notRegistered: false,
                            added: 30,
                          ),
                      fallback: defaultField,
                    ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final nameBox = tester.getRect(
        find.byKey(const Key('home_lesson_member_name_field')),
      );
      if (linked) {
        // 연결된 회원: 이름 칸과 같은 줄(세로 위치가 겹침)의 오른쪽에 총/잔여가 보인다.
        final field = tester.getRect(
          find.byKey(const Key('home_member_session_field')),
        );
        expect(field.left, greaterThan(nameBox.right - 1));
        expect(
          (field.center.dy - nameBox.center.dy).abs(),
          lessThan(nameBox.height),
        );
        expect(find.text('30/12'), findsNothing);
        expect(tester.takeException(), isNull);
      } else {
        expect(find.text('총/잔여횟수'), findsOneWidget);
        expect(find.text('30/12'), findsNothing);
      }
    }
  });
}
