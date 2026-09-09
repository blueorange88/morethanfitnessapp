import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/home/lesson_editor/home_lesson_editor_fields.dart';
import 'package:mtf_app/widgets/home/lesson_editor/home_recent_members_section.dart';

void main() {
  HomeMemberSuggestionCandidate candidate({
    required String id,
    required String name,
    required DateTime createdAt,
    String phone = '',
    String trainerId = 'owner-a',
    String workspaceType = 'personal',
    bool isDeleted = false,
    String deleteStatus = '',
  }) {
    return HomeMemberSuggestionCandidate(
      id: id,
      name: name,
      phone: phone,
      sessionCountText: '10/20',
      createdAt: createdAt,
      trainerId: trainerId,
      workspaceType: workspaceType,
      isDeleted: isDeleted,
      deleteStatus: deleteStatus,
    );
  }

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

  test('입력값이 있을 때만 자동완성 dropdown을 연다', () {
    expect(
      shouldShowHomeMemberSearchSuggestions(
        searchKeyword: '  ',
      ),
      isFalse,
    );
    expect(
      shouldShowHomeMemberSearchSuggestions(
        searchKeyword: '홍',
      ),
      isTrue,
    );
  });

  test('owner 범위 회원을 createdAt 최신순으로 반환한다', () {
    final results = filterHomeMemberSuggestions(
      candidates: [
        candidate(
          id: 'old',
          name: '이전회원',
          createdAt: DateTime(2026, 1, 1),
        ),
        candidate(
          id: 'other-owner',
          name: '다른강사회원',
          createdAt: DateTime(2026, 4, 1),
          trainerId: 'owner-b',
        ),
        candidate(
          id: 'new',
          name: '최신회원',
          createdAt: DateTime(2026, 3, 1),
        ),
      ],
      ownerUid: 'owner-a',
      searchKeyword: '',
    );

    expect(results.map((member) => member.id), ['new', 'old']);
  });

  test('이름 일부와 초성 검색 결과에 canonical memberId를 유지한다', () {
    final candidates = [
      candidate(
        id: 'member-hgd',
        name: '홍길동',
        phone: '01012345678',
        createdAt: DateTime(2026, 3, 1),
      ),
      candidate(
        id: 'member-hgs',
        name: '홍길순',
        phone: '01000001234',
        createdAt: DateTime(2026, 2, 1),
      ),
    ];

    final partial = filterHomeMemberSuggestions(
      candidates: candidates,
      ownerUid: 'owner-a',
      searchKeyword: ' 홍 ',
    );
    final choseong = filterHomeMemberSuggestions(
      candidates: candidates,
      ownerUid: 'owner-a',
      searchKeyword: 'ㅎㄱㄷ',
    );

    expect(partial.map((member) => member.name), ['홍길동', '홍길순']);
    expect(choseong.single.id, 'member-hgd');
  });

  test('owner가 없거나 검색 결과가 없으면 추천하지 않는다', () {
    final members = [
      candidate(
        id: 'member-a',
        name: '홍길동',
        createdAt: DateTime(2026, 3, 1),
      ),
    ];

    expect(
      filterHomeMemberSuggestions(
        candidates: members,
        ownerUid: '',
        searchKeyword: '',
      ),
      isEmpty,
    );
    expect(
      filterHomeMemberSuggestions(
        candidates: members,
        ownerUid: 'owner-a',
        searchKeyword: '없는회원',
      ),
      isEmpty,
    );
  });

  test('같은 문서 후보는 중복 표시하지 않고 이름 변경을 즉시 반영한다', () {
    final results = filterHomeMemberSuggestions(
      candidates: [
        candidate(
          id: 'member-new-name',
          name: '변경된이름',
          phone: '01012345678',
          createdAt: DateTime(2026, 3, 1),
        ),
        candidate(
          id: 'duplicate',
          name: '변경된이름',
          phone: '01012345678',
          createdAt: DateTime(2026, 2, 1),
        ),
      ],
      ownerUid: 'owner-a',
      searchKeyword: '변경',
    );

    expect(results, hasLength(1));
    expect(results.single.id, 'member-new-name');
    expect(results.single.name, '변경된이름');
  });

  testWidgets('검색 추천 Overlay는 본문 높이를 늘리지 않고 memberId를 연결한다', (tester) async {
    String? selectedMemberId;
    final nameController = TextEditingController();
    final sessionCountController = TextEditingController();
    addTearDown(nameController.dispose);
    addTearDown(sessionCountController.dispose);
    final members = [
      candidate(
        id: 'member-hgd',
        name: '홍길동',
        phone: '01012345678',
        createdAt: DateTime(2026, 3, 1),
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: StatefulBuilder(
            builder: (context, setState) {
              final hasLinkedMember = selectedMemberId != null;
              return HomeLessonMemberInputSection(
                key: const Key('home_member_input_section'),
                nameController: nameController,
                sessionCountController: sessionCountController,
                hasLinkedMember: hasLinkedMember,
                onNameTap: () {},
                onNameChanged: (_) => setState(() {
                  selectedMemberId = null;
                }),
                onClearName: () => setState(nameController.clear),
                showAutocompleteDropdown:
                    nameController.text.trim().isNotEmpty && !hasLinkedMember,
                autocompleteDropdown: HomeMemberSearchSuggestionsList(
                  members: members,
                  onPicked: (member) => setState(() {
                    selectedMemberId = member.id;
                    nameController.value = TextEditingValue(
                      text: member.name,
                      selection: TextSelection.collapsed(
                        offset: member.name.length,
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ),
      ),
    ));

    final heightBefore = tester
        .getSize(find.byKey(const Key('home_member_input_section')))
        .height;
    await tester.tap(find.byKey(const Key('home_lesson_member_name_field')));
    await tester.enterText(
      find.byKey(const Key('home_lesson_member_name_field')),
      '홍',
    );
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('home_member_search_suggestions_list')),
        findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('home_member_input_section'))).height,
      heightBefore,
    );
    expect(find.text('홍길동'), findsOneWidget);
    expect(find.text('•••• 5678'), findsOneWidget);
    expect(find.text('01012345678'), findsNothing);

    await tester.tap(
      find.byKey(const Key('home_member_search_suggestion_member-hgd')),
    );
    await tester.pump();
    await tester.pump();
    expect(selectedMemberId, 'member-hgd');
    expect(find.byKey(const Key('home_member_search_suggestions_list')),
        findsNothing);

    await tester.tap(find.byKey(const Key('home_lesson_member_name_field')));
    await tester.enterText(
      find.byKey(const Key('home_lesson_member_name_field')),
      '',
    );
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('home_member_search_suggestions_list')),
        findsNothing);
  });

  testWidgets('검색 결과 없음 문구와 스크롤 목록을 제공한다', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              HomeMemberSearchSuggestionsList(
                members: const [],
                onPicked: (_) {},
              ),
              HomeMemberSearchSuggestionsList(
                members: List.generate(
                  8,
                  (index) => candidate(
                    id: 'member-$index',
                    name: '회원$index',
                    createdAt: DateTime(2026, 3, index + 1),
                  ),
                ),
                onPicked: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('일치하는 등록 회원이 없어요.'), findsOneWidget);
    expect(
      find.byKey(const Key('home_member_search_suggestions_list')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('320·360·390·411dp와 키보드 viewInsets에서 Overlay 높이를 유지한다',
      (tester) async {
    final members = [
      candidate(
        id: 'member-hgd',
        name: '홍길동',
        createdAt: DateTime(2026, 3, 1),
      ),
    ];

    for (final width in const [320.0, 360.0, 390.0, 411.0]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 760);
      final nameController = TextEditingController(text: '홍');
      final sessionCountController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 760),
              viewInsets: const EdgeInsets.only(bottom: 300),
            ),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(12),
                child: HomeLessonMemberInputSection(
                  key: const Key('home_member_input_section'),
                  nameController: nameController,
                  sessionCountController: sessionCountController,
                  hasLinkedMember: false,
                  onNameTap: () {},
                  onNameChanged: (_) {},
                  onClearName: nameController.clear,
                  showAutocompleteDropdown: true,
                  autocompleteDropdown: HomeMemberSearchSuggestionsList(
                    members: members,
                    onPicked: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('home_lesson_member_name_field')));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'width=$width');
      expect(
        tester
            .getSize(find.byKey(const Key('home_member_input_section')))
            .height,
        lessThan(60),
        reason: 'width=$width',
      );
      expect(
        tester
            .getSize(
                find.byKey(const Key('home_member_search_suggestions_list')))
            .height,
        lessThanOrEqualTo(homeMemberSuggestionContentMaxHeight),
        reason: 'width=$width',
      );
      expect(
        find.byKey(const Key('home_member_search_suggestion_member-hgd')),
        findsOneWidget,
        reason: 'width=$width',
      );
      nameController.dispose();
      sessionCountController.dispose();
    }
    tester.view.reset();
  });

  test('Home 위젯 트리는 입력 Overlay와 독립 최근 회원 영역을 함께 유지한다', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();
    final fieldSource = File(
      'lib/widgets/home/lesson_editor/home_lesson_editor_fields.dart',
    ).readAsStringSync();
    final inputIndex = source.indexOf('HomeLessonMemberInputSection(');
    final memoIndex = source.indexOf('HomeLessonMemoSection(', inputIndex);
    final autocompleteIndex =
        source.indexOf('HomeMemberSearchSuggestionsOverlay(', inputIndex);
    final quickActionIndex =
        source.indexOf('HomeLessonQuickActionsSection(', memoIndex);
    final recentIndex =
        source.indexOf('HomeRecentMembersSection(', quickActionIndex);
    final footerIndex = source.indexOf('HomeLessonFooterActions(', recentIndex);

    expect(inputIndex, greaterThan(0));
    expect(autocompleteIndex, greaterThan(inputIndex));
    expect(autocompleteIndex, lessThan(memoIndex));
    expect(quickActionIndex, greaterThan(memoIndex));
    expect(recentIndex, greaterThan(quickActionIndex));
    expect(footerIndex, greaterThan(recentIndex));
    expect(
      source.substring(quickActionIndex, footerIndex),
      isNot(contains('if (showMemberSuggestionSpace)')),
    );
    expect(
      source.substring(recentIndex, footerIndex),
      isNot(contains('searchKeyword: searchKeyword')),
    );
    expect(fieldSource, contains('OverlayEntry('));
    expect(fieldSource, contains('CompositedTransformTarget('));
    expect(fieldSource, contains('CompositedTransformFollower('));
    expect(source.substring(inputIndex, footerIndex),
        isNot(contains('Scrollable.ensureVisible')));
  });

  test('최근 등록 회원 query는 cache가 아닌 owner-scoped members createdAt 후보를 사용한다', () {
    final source = File(
      'lib/widgets/home/lesson_editor/home_recent_members_section.dart',
    ).readAsStringSync();

    expect(source, contains("collection('members')"));
    expect(source, contains("where('trainerId', isEqualTo: owner)"));
    expect(source, contains("where('workspaceType', isEqualTo: 'personal')"));
    expect(source, contains('a.createdAt?.millisecondsSinceEpoch'));
    expect(source, contains('b.createdAt?.millisecondsSinceEpoch'));
    expect(source, isNot(contains('SharedPreferences')));
    expect(source, isNot(contains('recentMemberIds')));
  });
}
