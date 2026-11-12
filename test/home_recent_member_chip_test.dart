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
    DateTime? lastLessonAt,
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
      lastLessonAt: lastLessonAt,
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

  testWidgets('원형 아바타 아래에 이름과 추천 이유를 보여 주고 전화번호는 숨긴다', (tester) async {
    await tester.pumpWidget(buildChip());

    expect(find.byKey(const Key('home_recent_member_avatar')), findsOneWidget);
    expect(find.byIcon(Icons.person_rounded), findsOneWidget);
    expect(find.text('홍길동'), findsOneWidget);
    expect(find.text('최근 등록'), findsOneWidget);
    // 번호는 정보 전달에 도움이 안 되어 기본으로 보이지 않는다.
    expect(find.text('5678'), findsNothing);
    expect(find.text(' · '), findsNothing);
  });

  testWidgets('추천 이유마다 다른 아이콘과 글자로 알려 준다', (tester) async {
    for (final entry
        in {
          HomeAiRecommendationReason.recent: ('최근 등록', Icons.fiber_new_rounded),
          HomeAiRecommendationReason.frequent: (
            '자주 레슨',
            Icons.local_fire_department_rounded,
          ),
          HomeAiRecommendationReason.absent: ('오랜만', Icons.event_busy_rounded),
          HomeAiRecommendationReason.sameSlot: (
            '이 시간대',
            Icons.schedule_rounded,
          ),
        }.entries) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: HomeRecentMemberChip(
                name: '회원',
                phone: '',
                reason: entry.key,
                onTap: () {},
              ),
            ),
          ),
        ),
      );
      expect(find.text(entry.value.$1), findsOneWidget);
      expect(find.byIcon(entry.value.$2), findsOneWidget);
    }
  });

  testWidgets('같은 이름이 둘 이상일 때만 이름 뒤에 뒤 4자리를 붙이고 긴 이름은 줄임표 처리한다', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 80,
              child: HomeRecentMemberChip(
                name: '매우긴회원이름테스트',
                phone: '01099991234',
                showPhoneSuffix: true,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    final nameText = tester.widget<Text>(find.textContaining('매우긴회원이름테스트'));
    expect(nameText.data, '매우긴회원이름테스트·1234');
    expect(nameText.maxLines, 1);
    expect(nameText.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
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
    expect(shouldShowHomeMemberSearchSuggestions(searchKeyword: '  '), isFalse);
    expect(shouldShowHomeMemberSearchSuggestions(searchKeyword: '홍'), isTrue);
  });

  test('owner 범위 회원을 createdAt 최신순으로 반환한다', () {
    final results = filterHomeMemberSuggestions(
      candidates: [
        candidate(id: 'old', name: '이전회원', createdAt: DateTime(2026, 1, 1)),
        candidate(
          id: 'other-owner',
          name: '다른강사회원',
          createdAt: DateTime(2026, 4, 1),
          trainerId: 'owner-b',
        ),
        candidate(id: 'new', name: '최신회원', createdAt: DateTime(2026, 3, 1)),
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
      candidate(id: 'member-a', name: '홍길동', createdAt: DateTime(2026, 3, 1)),
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

    await tester.pumpWidget(
      MaterialApp(
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
                  onNameChanged:
                      (_) => setState(() {
                        selectedMemberId = null;
                      }),
                  onClearName: () => setState(nameController.clear),
                  showAutocompleteDropdown:
                      nameController.text.trim().isNotEmpty && !hasLinkedMember,
                  autocompleteDropdown: HomeMemberSearchSuggestionsList(
                    members: members,
                    onPicked:
                        (member) => setState(() {
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
      ),
    );

    final heightBefore =
        tester
            .getSize(find.byKey(const Key('home_member_input_section')))
            .height;
    await tester.tap(find.byKey(const Key('home_lesson_member_name_field')));
    await tester.enterText(
      find.byKey(const Key('home_lesson_member_name_field')),
      '홍',
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const Key('home_member_search_suggestions_list')),
      findsOneWidget,
    );
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
    expect(
      find.byKey(const Key('home_member_search_suggestions_list')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('home_lesson_member_name_field')));
    await tester.enterText(
      find.byKey(const Key('home_lesson_member_name_field')),
      '',
    );
    await tester.pump();
    await tester.pump();
    expect(
      find.byKey(const Key('home_member_search_suggestions_list')),
      findsNothing,
    );
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

  testWidgets('320·360·390·411dp와 키보드 viewInsets에서 Overlay 높이를 유지한다', (
    tester,
  ) async {
    final members = [
      candidate(id: 'member-hgd', name: '홍길동', createdAt: DateTime(2026, 3, 1)),
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
              find.byKey(const Key('home_member_search_suggestions_list')),
            )
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
    final fieldSource =
        File(
          'lib/widgets/home/lesson_editor/home_lesson_editor_fields.dart',
        ).readAsStringSync();
    final inputIndex = source.indexOf('HomeLessonMemberInputSection(');
    final memoIndex = source.indexOf('HomeLessonMemoSection(', inputIndex);
    final autocompleteIndex = source.indexOf(
      'HomeMemberSearchSuggestionsOverlay(',
      inputIndex,
    );
    final quickActionIndex = source.indexOf(
      'HomeLessonQuickActionsSection(',
      memoIndex,
    );
    final recentIndex = source.indexOf(
      'HomeRecentMembersSection(',
      quickActionIndex,
    );
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
    expect(
      source.substring(inputIndex, footerIndex),
      isNot(contains('Scrollable.ensureVisible')),
    );
  });

  test('자주 레슨한 회원은 최근등록 다음에, 레슨이 뜸한 회원은 맨 마지막에 배치된다', () {
    final now = DateTime(2026, 3, 15);
    final candidates = [
      candidate(id: 'm1', name: '회원1', createdAt: DateTime(2026, 3, 14)),
      candidate(id: 'm2', name: '회원2', createdAt: DateTime(2026, 3, 13)),
      candidate(id: 'm3', name: '회원3', createdAt: DateTime(2026, 3, 12)),
      candidate(id: 'm4', name: '회원4', createdAt: DateTime(2026, 3, 11)),
      candidate(id: 'freq', name: '열심회원', createdAt: DateTime(2026, 2, 1)),
      candidate(
        id: 'absent',
        name: '뜸한회원',
        createdAt: DateTime(2026, 1, 1),
        lastLessonAt: DateTime(2026, 2, 20),
      ),
    ];

    final result = buildAiRecommendedMembers(
      candidatesByRecency: candidates,
      recentLessonCounts: const {'freq': 4},
      now: now,
      totalSlots: 6,
      maxRecentSlots: 4,
    );

    expect(result, hasLength(6));
    expect(result.sublist(0, 4).map((e) => e.candidate.id), [
      'm1',
      'm2',
      'm3',
      'm4',
    ]);
    expect(result[4].candidate.id, 'freq');
    expect(result[4].reason, HomeAiRecommendationReason.frequent);
    expect(result[5].candidate.id, 'absent');
    expect(result[5].reason, HomeAiRecommendationReason.absent);
    expect(
      result.map((e) => e.candidate.id).toSet().length,
      result.length,
      reason: '같은 회원이 두 번 등장하면 안 된다',
    );
  });

  test('기본은 4명: 오랜만 1명을 먼저 확보하고 최근 등록 2명, 나머지는 자주 레슨한 회원', () {
    final now = DateTime(2026, 3, 15);
    final candidates = [
      candidate(id: 'm1', name: '회원1', createdAt: DateTime(2026, 3, 14)),
      candidate(id: 'm2', name: '회원2', createdAt: DateTime(2026, 3, 13)),
      candidate(id: 'm3', name: '회원3', createdAt: DateTime(2026, 3, 12)),
      candidate(id: 'freq', name: '열심회원', createdAt: DateTime(2026, 2, 1)),
      candidate(
        id: 'absent',
        name: '뜸한회원',
        createdAt: DateTime(2026, 1, 1),
        lastLessonAt: DateTime(2026, 2, 20),
      ),
    ];

    final result = buildAiRecommendedMembers(
      candidatesByRecency: candidates,
      recentLessonCounts: const {'freq': 4},
      now: now,
    );

    expect(result.map((e) => e.candidate.id), ['m1', 'm2', 'freq', 'absent']);
    expect(result.map((e) => e.reason), [
      HomeAiRecommendationReason.recent,
      HomeAiRecommendationReason.recent,
      HomeAiRecommendationReason.frequent,
      HomeAiRecommendationReason.absent,
    ]);
  });

  test('자주 레슨한 회원이 없으면 남는 칸은 신규 등록자로 채워 최대 4명이다', () {
    final now = DateTime(2026, 3, 15);
    final candidates = [
      for (var i = 1; i <= 6; i++)
        candidate(
          id: 'm$i',
          name: '회원$i',
          createdAt: DateTime(2026, 3, 15 - i),
        ),
    ];

    final result = buildAiRecommendedMembers(
      candidatesByRecency: candidates,
      recentLessonCounts: const {},
      now: now,
    );

    expect(result.map((e) => e.candidate.id), ['m1', 'm2', 'm3', 'm4']);
    expect(
      result.every((e) => e.reason == HomeAiRecommendationReason.recent),
      isTrue,
    );
  });

  test('신규 등록이 없어 최근등록이 비면 빈 자리는 자주 레슨한 회원들로 채워지고 한 줄로 줄어든다', () {
    final now = DateTime(2026, 3, 15);
    final candidates = [
      candidate(id: 'old1', name: '오래된회원1', createdAt: DateTime(2025, 1, 1)),
      candidate(id: 'freq1', name: '자주1', createdAt: DateTime(2025, 1, 2)),
      candidate(id: 'freq2', name: '자주2', createdAt: DateTime(2025, 1, 3)),
      candidate(
        id: 'absent1',
        name: '뜸함1',
        createdAt: DateTime(2025, 1, 4),
        lastLessonAt: DateTime(2026, 2, 1),
      ),
    ];

    final result = buildAiRecommendedMembers(
      candidatesByRecency: candidates,
      recentLessonCounts: const {'freq1': 5, 'freq2': 3},
      now: now,
    );

    expect(
      result.where((e) => e.reason == HomeAiRecommendationReason.recent),
      isEmpty,
      reason: '14일 이내 등록자가 없으면 최근등록 슬롯은 비어야 한다',
    );
    expect(result, hasLength(3), reason: '자주 2명 + 뜸함 1명 = 한 줄(3칸)만 채워져야 한다');
    expect(result[0].candidate.id, 'freq1');
    expect(result[1].candidate.id, 'freq2');
    expect(result[2].candidate.id, 'absent1');
    expect(result[2].reason, HomeAiRecommendationReason.absent);
  });

  test('14일이 지난 등록자는 최근등록에서 빠지지만 14일 이내 신규 등록자는 그대로 포함된다', () {
    final now = DateTime(2026, 3, 15);
    final candidates = [
      candidate(id: 'new1', name: '신규1', createdAt: DateTime(2026, 3, 10)),
      candidate(id: 'old1', name: '오래됨1', createdAt: DateTime(2026, 2, 1)),
    ];

    final result = buildAiRecommendedMembers(
      candidatesByRecency: candidates,
      recentLessonCounts: const {},
      now: now,
    );

    expect(result, hasLength(1));
    expect(result.single.candidate.id, 'new1');
    expect(result.single.reason, HomeAiRecommendationReason.recent);
  });

  test('자주/뜸한 회원 조건을 만족하는 후보가 없으면 최근 등록 회원으로 대체된다', () {
    final now = DateTime(2026, 3, 15);
    final candidates = [
      candidate(id: 'm1', name: '회원1', createdAt: DateTime(2026, 3, 14)),
      candidate(id: 'm2', name: '회원2', createdAt: DateTime(2026, 3, 13)),
      candidate(id: 'm3', name: '회원3', createdAt: DateTime(2026, 3, 12)),
    ];

    final result = buildAiRecommendedMembers(
      candidatesByRecency: candidates,
      recentLessonCounts: const {},
      now: now,
    );

    expect(result, hasLength(3));
    expect(
      result.every((e) => e.reason == HomeAiRecommendationReason.recent),
      isTrue,
    );
  });

  test('레슨 기록이 없는 신규 회원은 뜸한 회원 후보에서 제외된다', () {
    final now = DateTime(2026, 3, 15);
    final candidates = [
      candidate(id: 'm1', name: '신규회원', createdAt: DateTime(2026, 3, 14)),
    ];

    final result = buildAiRecommendedMembers(
      candidatesByRecency: candidates,
      recentLessonCounts: const {},
      now: now,
    );

    expect(result, hasLength(1));
    expect(result.single.reason, HomeAiRecommendationReason.recent);
  });

  test('스케줄 문서에서 회원별 레슨 횟수를 집계하고 삭제된 문서는 제외한다', () {
    final counts = lessonCountsFromScheduleDocs([
      {'memberId': 'a'},
      {'memberId': 'a'},
      {'memberId': 'b'},
      {'memberId': 'c', 'isDeleted': true},
      {'memberId': ''},
    ]);

    expect(counts, {'a': 2, 'b': 1});
  });

  test('최근 등록 회원 query는 cache가 아닌 owner-scoped members createdAt 후보를 사용한다', () {
    final source =
        File(
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

  test('저장된 레슨을 열었을 때(수정)는 회원 추천을 보여주지 않는다', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();
    final index = source.indexOf('HomeRecentMembersSection(');
    expect(index, greaterThan(0));
    final before = source.substring(index - 80, index);
    expect(before, contains('if (!isEditMode)'));
  });

  group('같은 요일·비슷한 시간대 추천', () {
    final now = DateTime(2026, 3, 15);

    test('시간대 횟수가 많은 회원이 맨 앞에 오고 다른 칸에서 중복되지 않는다', () {
      final candidates = [
        candidate(id: 'new1', name: '신규1', createdAt: DateTime(2026, 3, 14)),
        candidate(id: 'slotA', name: '수요일A', createdAt: DateTime(2026, 1, 1)),
        candidate(id: 'slotB', name: '수요일B', createdAt: DateTime(2026, 1, 2)),
        candidate(id: 'freq', name: '자주', createdAt: DateTime(2026, 1, 3)),
      ];

      final result = buildAiRecommendedMembers(
        candidatesByRecency: candidates,
        recentLessonCounts: const {'slotA': 5, 'freq': 4},
        slotLessonCounts: const {'slotA': 6, 'slotB': 3},
        now: now,
      );

      expect(result.take(2).map((e) => e.candidate.id), ['slotA', 'slotB']);
      expect(
        result.take(2).map((e) => e.reason),
        everyElement(HomeAiRecommendationReason.sameSlot),
      );
      expect(result.map((e) => e.candidate.id).toSet().length, result.length);
      expect(result.map((e) => e.candidate.id), contains('new1'));
      expect(result.map((e) => e.candidate.id), contains('freq'));
      expect(result.length, lessThanOrEqualTo(4));
    });

    test('시간대 횟수가 기준 미만이면 기존 추천 그대로', () {
      final candidates = [
        candidate(id: 'm1', name: '회원1', createdAt: DateTime(2026, 3, 14)),
        candidate(id: 'x', name: '한번', createdAt: DateTime(2026, 1, 1)),
      ];
      final withSlot = buildAiRecommendedMembers(
        candidatesByRecency: candidates,
        recentLessonCounts: const {},
        slotLessonCounts: const {'x': 1},
        now: now,
      );
      final without = buildAiRecommendedMembers(
        candidatesByRecency: candidates,
        recentLessonCounts: const {},
        now: now,
      );
      expect(
        withSlot.map((e) => (e.candidate.id, e.reason)).toList(),
        without.map((e) => (e.candidate.id, e.reason)).toList(),
      );
    });

    test('같은 요일이고 앞뒤 1시간 안인 레슨만 회원별로 센다', () {
      // 2026-03-11은 수요일.
      DateTime at(int day, int hour, int minute) =>
          DateTime(2026, 3, day, hour, minute);
      final docs = <Map<String, dynamic>>[
        {'memberId': 'a', 'startAt': at(11, 10, 0)},
        {'memberId': 'a', 'startAt': at(4, 10, 30)},
        {'memberId': 'a', 'startAt': at(4, 11, 0)},
        {'memberId': 'a', 'startAt': at(4, 12, 0)}, // 2시간 차이 → 제외
        {'memberId': 'a', 'startAt': at(12, 10, 0)}, // 목요일 → 제외
        {'memberId': 'b', 'startAt': at(11, 9, 0)},
        {'memberId': 'b', 'startAt': at(11, 10, 0), 'isDeleted': true},
        {'memberId': '', 'startAt': at(11, 10, 0)},
        {'memberId': 'c'},
      ];

      final counts = slotLessonCountsFromScheduleDocs(
        docs,
        weekday: DateTime.wednesday,
        minutesOfDay: 10 * 60,
      );
      expect(counts, {'a': 3, 'b': 1});
    });

    test('요일과 시간 문자열을 안전하게 읽는다', () {
      expect(homeWeekdayFromKoreanDay('월'), 1);
      expect(homeWeekdayFromKoreanDay('일'), 7);
      expect(homeWeekdayFromKoreanDay('x'), isNull);
      expect(homeWeekdayFromKoreanDay(null), isNull);
      expect(homeMinutesFromTimeText('09:30'), 570);
      expect(homeMinutesFromTimeText('9:05'), 545);
      expect(homeMinutesFromTimeText('24:00'), isNull);
      expect(homeMinutesFromTimeText(''), isNull);
      expect(homeMinutesFromTimeText(null), isNull);
    });
  });
}
