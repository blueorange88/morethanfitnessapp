import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/home_lesson_editor_result.dart';
import 'package:mtf_app/widgets/home/lesson_editor/home_lesson_quick_actions_section.dart';

void main() {
  Widget buildSection({
    bool isPersistedSchedule = true,
    bool hasLinkedMember = true,
    bool isConfirmedLesson = false,
    Future<void> Function()? onOpenLessonContract,
    Future<void> Function()? onOpenMembershipContract,
    Future<void> Function()? onOpenLessonContractFromUnregistered,
    Future<void> Function()? onOpenMembershipContractFromUnregistered,
    bool withLessonContract = true,
    bool withMembershipContract = true,
    bool hasContract = false,
    Future<void> Function()? onOpenLessonConfirm,
    Future<void> Function()? onOpenSignRequest,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: HomeLessonQuickActionsSection(
          hasLinkedMember: hasLinkedMember,
          memberName: '테스트회원',
          memberId: 'member-a',
          linkedMemberDeleted: false,
          isConfirmedLesson: isConfirmedLesson,
          isCustomerSignedConfirmedLesson: false,
          isContractLinkedConfirmedLesson: false,
          isPersistedSchedule: isPersistedSchedule,
          loadHasContract: (_) async => hasContract,
          onShowToast: (_) {},
          onOpenMemberCard: () async {},
          onOpenWorkoutLog: () async {},
          onOpenLessonConfirm: onOpenLessonConfirm ?? () async {},
          onOpenSignRequest: onOpenSignRequest ?? () async {},
          onLinkExistingMember: () async {},
          onRegisterManualMember: () async {},
          onCancelConfirmedLesson: () async {},
          onOpenLessonContract:
              withLessonContract ? (onOpenLessonContract ?? () async {}) : null,
          onOpenMembershipManage:
              withMembershipContract
                  ? (onOpenMembershipContract ?? () async {})
                  : null,
          onOpenLessonContractFromUnregistered:
              withLessonContract
                  ? (onOpenLessonContractFromUnregistered ?? () async {})
                  : null,
          onOpenMembershipContractFromUnregistered:
              withMembershipContract
                  ? (onOpenMembershipContractFromUnregistered ?? () async {})
                  : null,
        ),
      ),
    );
  }

  testWidgets('신규계약서 칩 하나로 합쳐지고 레슨계약서 아이콘을 쓴다', (tester) async {
    await tester.pumpWidget(buildSection());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('aifc_quick_actions_section')), findsOneWidget);
    expect(find.text('AIFC 추천업무'), findsOneWidget);
    expect(find.text('신규계약서'), findsOneWidget);
    // 시트가 열리기 전에는 계약서 칩이 따로 보이지 않는다.
    expect(find.text('레슨계약서'), findsNothing);
    expect(find.text('회원권계약서'), findsNothing);
    expect(find.byKey(const Key('aifc_lesson_contract_action')), findsNothing);
    expect(
      find.byKey(const Key('aifc_membership_contract_action')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('aifc_contract_manage_action')),
        matching: find.byIcon(Icons.description_outlined),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Semi-Pro부터'), findsNothing);
    expect(find.textContaining('Pro부터'), findsNothing);

    final memberSize = tester.getSize(
      find.byKey(const Key('aifc_member_card_action')),
    );
    expect(memberSize.height, 36);
    expect(memberSize.width, lessThan(145));

    const key = Key('aifc_contract_manage_action');
    expect(tester.getSize(find.byKey(key)).height, memberSize.height);
    final container = tester.widget<Container>(find.byKey(key));
    final decoration = container.decoration! as BoxDecoration;
    expect(container.constraints!.minHeight, 36);
    expect(container.constraints!.maxHeight, 36);
    expect(
      container.padding,
      const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
    );
    expect(decoration.color, const Color(0xFFFFF1C2));
    expect(decoration.border, isNotNull);
    expect(decoration.borderRadius, BorderRadius.circular(14));
    expect(decoration.boxShadow, isNull);

    final icons = tester.widgetList<Icon>(
      find.descendant(
        of: find.byKey(const Key('aifc_quick_actions_section')),
        matching: find.byType(Icon),
      ),
    );
    expect(icons.every((icon) => icon.size == 16), isTrue);

    final actionWrap = tester.widgetList<Wrap>(
      find.descendant(
        of: find.byKey(const Key('aifc_quick_actions_section')),
        matching: find.byType(Wrap),
      ),
    );
    expect(
      actionWrap.any((wrap) => wrap.spacing == 5 && wrap.runSpacing == 7),
      isTrue,
    );
  });

  testWidgets('버튼 순서는 신규계약서 → 회원카드 → 레슨일지 → 레슨확정이다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildSection());
    await tester.pumpAndSettle();

    Offset at(Finder finder) => tester.getTopLeft(finder);
    final contract = at(find.byKey(const Key('aifc_contract_manage_action')));
    final member = at(find.byKey(const Key('aifc_member_card_action')));
    final log = at(find.text('레슨일지'));
    final confirm = at(find.text('레슨확정'));

    // 한 줄에 놓이므로 왼쪽에서 오른쪽 순서로 비교한다.
    expect(contract.dy, member.dy);
    expect(contract.dx, lessThan(member.dx));
    expect(member.dx, lessThan(log.dx));
    expect(log.dx, lessThan(confirm.dx));
  });

  testWidgets('계약이 있으면 빠른 서명·서명 요청이 서명요청 버튼 하나로 합쳐진다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildSection(hasContract: true));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('aifc_sign_action')), findsOneWidget);
    expect(find.text('서명요청'), findsOneWidget);
    expect(find.text('빠른 서명'), findsNothing);
    expect(find.text('서명 요청'), findsNothing);
    expect(find.text('레슨확정'), findsNothing);

    // 신규계약서 → 회원카드 → 레슨일지 → 서명요청 한 줄.
    final log = tester.getTopLeft(find.text('레슨일지'));
    final sign = tester.getTopLeft(find.text('서명요청'));
    expect(log.dy, sign.dy);
    expect(log.dx, lessThan(sign.dx));
  });

  testWidgets('서명요청을 누르면 방법을 고르는 시트가 뜨고 선택한 동작을 실행한다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 900);
    addTearDown(tester.view.reset);
    var quick = 0;
    var request = 0;
    await tester.pumpWidget(
      buildSection(
        hasContract: true,
        onOpenLessonConfirm: () async => quick += 1,
        onOpenSignRequest: () async => request += 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('aifc_sign_action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home_sign_action_sheet')), findsOneWidget);
    expect(find.text('빠른 서명'), findsOneWidget);
    expect(find.text('서명 요청하기'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home_sign_action_quick')));
    await tester.pumpAndSettle();
    expect((quick, request), (1, 0));

    await tester.tap(find.byKey(const Key('aifc_sign_action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home_sign_action_request')));
    await tester.pumpAndSettle();
    expect((quick, request), (1, 1));

    // 시트를 그냥 닫으면 아무것도 실행하지 않는다.
    await tester.tap(find.byKey(const Key('aifc_sign_action')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect((quick, request), (1, 1));
  });

  testWidgets('계약이 없으면 레슨확정만, 확정된 레슨에는 서명요청이 없다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildSection());
    await tester.pumpAndSettle();
    expect(find.text('레슨확정'), findsOneWidget);
    expect(find.text('서명요청'), findsNothing);

    await tester.pumpWidget(
      buildSection(hasContract: true, isConfirmedLesson: true),
    );
    await tester.pumpAndSettle();
    expect(find.text('확정완료'), findsOneWidget);
    expect(find.text('서명요청'), findsNothing);
  });

  testWidgets('확정된 레슨에서도 신규계약서 → 회원카드 → 레슨일지가 앞에 온다', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildSection(isConfirmedLesson: true));
    await tester.pumpAndSettle();

    final contract = tester.getTopLeft(
      find.byKey(const Key('aifc_contract_manage_action')),
    );
    final log = tester.getTopLeft(find.text('레슨일지'));
    final done = tester.getTopLeft(find.text('확정완료'));
    expect(contract.dx, lessThan(log.dx));
    expect(log.dx, lessThan(done.dx));
  });

  testWidgets('신규 레슨에서는 AIFC 추천업무 전체를 표시하지 않는다', (tester) async {
    await tester.pumpWidget(
      buildSection(hasLinkedMember: false, isPersistedSchedule: false),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('aifc_quick_actions_section')), findsNothing);
    expect(find.text('AIFC 추천업무'), findsNothing);
    expect(find.byKey(const Key('aifc_member_card_action')), findsNothing);
    expect(find.byKey(const Key('aifc_contract_manage_action')), findsNothing);

    await tester.pumpWidget(
      buildSection(hasLinkedMember: true, isPersistedSchedule: false),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('aifc_quick_actions_section')), findsNothing);
    expect(find.text('AIFC 추천업무'), findsNothing);
  });

  testWidgets('신규계약서를 누르면 레슨계약서·회원권계약서 중 고르는 시트가 뜨고 중앙 진입 콜백에 위임한다', (
    tester,
  ) async {
    var lessonOpenCount = 0;
    var membershipOpenCount = 0;

    await tester.pumpWidget(
      buildSection(
        onOpenLessonContract: () async {
          lessonOpenCount += 1;
        },
        onOpenMembershipContract: () async {
          membershipOpenCount += 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('aifc_contract_manage_action')));
    await tester.pumpAndSettle();
    // 누르기 전에는 어느 것도 열리지 않고, 시트에 두 선택지가 있다.
    expect(lessonOpenCount, 0);
    expect(membershipOpenCount, 0);
    expect(find.byKey(const Key('aifc_contract_chooser')), findsOneWidget);
    expect(find.text('레슨계약서'), findsOneWidget);
    expect(find.text('회원권계약서'), findsOneWidget);

    await tester.tap(find.byKey(const Key('aifc_lesson_contract_action')));
    await tester.pumpAndSettle();
    expect(lessonOpenCount, 1);
    expect(membershipOpenCount, 0);
    // 선택하면 시트는 먼저 닫힌다.
    expect(find.byKey(const Key('aifc_contract_chooser')), findsNothing);

    await tester.tap(find.byKey(const Key('aifc_contract_manage_action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('aifc_membership_contract_action')));
    await tester.pumpAndSettle();
    expect(lessonOpenCount, 1);
    expect(membershipOpenCount, 1);
    expect(find.textContaining('부터 사용할 수 있어요.'), findsNothing);
  });

  testWidgets('시트를 그냥 닫으면 아무 계약서도 열지 않는다', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      buildSection(
        onOpenLessonContract: () async => opened += 1,
        onOpenMembershipContract: () async => opened += 1,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('aifc_contract_manage_action')));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aifc_contract_chooser')), findsNothing);
    expect(opened, 0);
  });

  testWidgets('한 종류만 열 수 있으면 고르지 않고 바로 연다', (tester) async {
    var lessonOpenCount = 0;
    await tester.pumpWidget(
      buildSection(
        withMembershipContract: false,
        onOpenLessonContract: () async {
          lessonOpenCount += 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('aifc_contract_manage_action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('aifc_contract_chooser')), findsNothing);
    expect(lessonOpenCount, 1);
  });

  testWidgets('저장 문서가 있는 기존 레슨에서만 AIFC 추천업무를 표시한다', (tester) async {
    const newLesson = HomeLessonEditorInput(
      day: '월',
      time: '09:00',
      weekOffset: 0,
    );
    const temporaryLesson = HomeLessonEditorInput(
      day: '월',
      time: '09:00',
      weekOffset: 0,
      existingSession: {'name': '임시 입력'},
    );
    const persistedLesson = HomeLessonEditorInput(
      day: '월',
      time: '09:00',
      weekOffset: 0,
      existingSession: {'docId': 'schedule-a'},
    );
    const canonicalPersistedLesson = HomeLessonEditorInput(
      day: '월',
      time: '09:00',
      weekOffset: 0,
      existingSession: {'actualDocumentId': 'schedule-b'},
    );

    expect(newLesson.hasPersistedSchedule, isFalse);
    expect(temporaryLesson.isEditMode, isTrue);
    expect(temporaryLesson.hasPersistedSchedule, isFalse);
    expect(persistedLesson.hasPersistedSchedule, isTrue);
    expect(canonicalPersistedLesson.hasPersistedSchedule, isTrue);

    await tester.pumpWidget(buildSection(isPersistedSchedule: false));
    await tester.pumpAndSettle();

    expect(find.text('AIFC 추천업무'), findsNothing);

    await tester.pumpWidget(buildSection(isPersistedSchedule: true));
    await tester.pumpAndSettle();

    expect(find.text('AIFC 추천업무'), findsOneWidget);
    expect(find.text('신규계약서'), findsOneWidget);
  });

  testWidgets('기존 미연결 회원도 신규계약서 칩 하나로 계약서를 고른다', (tester) async {
    var lessonOpenCount = 0;
    var membershipOpenCount = 0;

    await tester.pumpWidget(
      buildSection(
        hasLinkedMember: false,
        isPersistedSchedule: true,
        onOpenLessonContractFromUnregistered: () async {
          lessonOpenCount += 1;
        },
        onOpenMembershipContractFromUnregistered: () async {
          membershipOpenCount += 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    // 연결·등록 칩과 합쳐 3개 칩만 있다(계약 칩이 둘이던 때보다 한 개 줄어 줄이 늘지 않는다).
    expect(find.text('기존 회원 연결'), findsOneWidget);
    expect(find.text('내 회원으로 등록'), findsOneWidget);
    expect(find.text('신규계약서'), findsOneWidget);
    expect(find.text('레슨계약서'), findsNothing);

    await tester.tap(find.byKey(const Key('aifc_contract_manage_action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('aifc_lesson_contract_action')));
    await tester.pumpAndSettle();
    expect(lessonOpenCount, 1);

    await tester.tap(find.byKey(const Key('aifc_contract_manage_action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('aifc_membership_contract_action')));
    await tester.pumpAndSettle();
    expect(membershipOpenCount, 1);
  });

  for (final width in const [320.0, 360.0, 384.0, 411.0]) {
    testWidgets('${width.toInt()}dp에서 신규계약서 버튼 overflow가 없다', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildSection());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('aifc_contract_manage_action')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('aifc_contract_manage_action')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('aifc_contract_chooser')), findsOneWidget);
    });
  }

  test('계약 버튼에는 애니메이션 강조나 내부 tier 문구가 없다', () {
    final source =
        File(
          'lib/widgets/home/lesson_editor/home_lesson_quick_actions_section.dart',
        ).readAsStringSync();

    expect(source, isNot(contains('AnimationController')));
    expect(source, isNot(contains('_RecommendedActionWash')));
    expect(source, isNot(contains('RadialGradient')));
    expect(source, isNot(contains('supportingText')));
  });

  test('Home 계약 진입은 기존 중앙 feature gate를 유지한다', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();
    final lessonStart = source.indexOf(
      'Future<void> _openLessonContractFromHomeLesson',
    );
    final membershipStart = source.indexOf(
      'Future<void> _openMembershipManageFromHomeLesson',
    );
    final lessonBody = source.substring(
      lessonStart,
      source.indexOf('Future<void>', lessonStart + 20),
    );
    final membershipBody = source.substring(membershipStart, lessonStart);

    expect(lessonBody, contains('AifcTierFeatureGateSheet.guard('));
    expect(lessonBody, contains('AppTierFeatureKey.contract'));
    expect(membershipBody, contains('AifcTierFeatureGateSheet.guard('));
    expect(membershipBody, contains('AppTierFeatureKey.membershipContract'));
  });

  test('신규 Personal 계약 진입은 legacy 및 미존재 member read를 만들지 않는다', () {
    final homeSource = File('lib/pages/home_page.dart').readAsStringSync();
    final contractSource =
        File('lib/pages/contract_page.dart').readAsStringSync();
    final membershipSource =
        File('lib/pages/membership_contract_page.dart').readAsStringSync();

    expect(
      homeSource,
      contains(
        'personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null',
      ),
    );
    expect(homeSource, contains('loadExistingDraft: false'));
    expect(contractSource, contains('if (!isPersonalContract)'));
    expect(membershipSource, contains('if (widget.loadExistingDraft)'));
    expect(
      homeSource,
      isNot(contains('if (saved != true && !memberSnap.exists)')),
    );
    expect(
      homeSource,
      isNot(contains('if (ok != true && !memberSnap.exists)')),
    );
  });

  test('Home AIFC 섹션은 저장 문서 존재 여부를 전달받는다', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();
    final quickActionsIndex = source.indexOf('HomeLessonQuickActionsSection(');

    expect(quickActionsIndex, greaterThan(0));
    expect(source, contains('editorInput.hasPersistedSchedule'));
    expect(source, contains('if (hasPersistedSchedule) ...['));
    expect(source, contains('hasPersistedSchedule'));
    expect(source, isNot(contains('isPersistedSchedule: isEditMode')));
  });
}
