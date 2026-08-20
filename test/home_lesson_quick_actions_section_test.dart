import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/home_lesson_editor_result.dart';
import 'package:mtf_app/widgets/home/lesson_editor/home_lesson_quick_actions_section.dart';

void main() {
  Widget buildSection({
    bool canUseLessonContract = true,
    bool canUseMembershipContract = true,
    bool isPersistedSchedule = true,
    bool hasLinkedMember = true,
    Future<void> Function()? onOpenLessonContract,
    Future<void> Function()? onOpenMembershipContract,
    Future<void> Function()? onOpenLessonContractFromUnregistered,
    Future<void> Function()? onOpenMembershipContractFromUnregistered,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: HomeLessonQuickActionsSection(
          hasLinkedMember: hasLinkedMember,
          memberName: '테스트회원',
          memberId: 'member-a',
          linkedMemberDeleted: false,
          isConfirmedLesson: false,
          isCustomerSignedConfirmedLesson: false,
          isContractLinkedConfirmedLesson: false,
          isPersistedSchedule: isPersistedSchedule,
          loadHasContract: (_) async => false,
          onShowToast: (_) {},
          onOpenMemberCard: () async {},
          onOpenWorkoutLog: () async {},
          onOpenLessonConfirm: () async {},
          onOpenSignRequest: () async {},
          onLinkExistingMember: () async {},
          onRegisterManualMember: () async {},
          onCancelConfirmedLesson: () async {},
          canUseLessonContract: canUseLessonContract,
          canUseMembershipManage: canUseMembershipContract,
          onOpenLessonContract: onOpenLessonContract ?? () async {},
          onOpenMembershipManage: onOpenMembershipContract ?? () async {},
          onOpenLessonContractFromUnregistered:
              onOpenLessonContractFromUnregistered ?? () async {},
          onOpenMembershipContractFromUnregistered:
              onOpenMembershipContractFromUnregistered ?? () async {},
        ),
      ),
    );
  }

  testWidgets('AIFC 계약 버튼은 공통 크기와 제목만 사용한다', (tester) async {
    await tester.pumpWidget(buildSection());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('aifc_quick_actions_section')), findsOneWidget);
    expect(find.text('AIFC 추천업무'), findsOneWidget);
    expect(find.text('레슨계약서'), findsOneWidget);
    expect(find.text('회원권계약서'), findsOneWidget);
    expect(find.text('레슨 조건을 문서로 남겨요.'), findsNothing);
    expect(find.text('이용 조건을 명확하게 기록해요.'), findsNothing);
    expect(find.textContaining('Semi-Pro부터'), findsNothing);
    expect(find.textContaining('Pro부터'), findsNothing);

    final memberSize = tester.getSize(
      find.byKey(const Key('aifc_member_card_action')),
    );
    expect(memberSize.height, 36);
    expect(memberSize.width, lessThan(145));

    for (final key in const [
      Key('aifc_lesson_contract_action'),
      Key('aifc_membership_contract_action'),
    ]) {
      expect(tester.getSize(find.byKey(key)).height, memberSize.height);

      final container = tester.widget<Container>(find.byKey(key));
      final decoration = container.decoration! as BoxDecoration;
      expect(container.constraints!.minHeight, 36);
      expect(container.constraints!.maxHeight, 36);
      expect(container.constraints!.maxWidth, double.infinity);
      expect(
        container.padding,
        const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      );
      expect(decoration.color, const Color(0xFFFFF1C2));
      expect(decoration.border, isNotNull);
      expect(decoration.borderRadius, BorderRadius.circular(14));
      expect(decoration.boxShadow, isNull);
    }

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

  testWidgets('신규 레슨에서는 AIFC 추천업무 전체를 표시하지 않는다', (tester) async {
    await tester.pumpWidget(
      buildSection(
        hasLinkedMember: false,
        isPersistedSchedule: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('aifc_quick_actions_section')), findsNothing);
    expect(find.text('AIFC 추천업무'), findsNothing);
    expect(find.byKey(const Key('aifc_member_card_action')), findsNothing);
    expect(find.byKey(const Key('aifc_lesson_contract_action')), findsNothing);
    expect(
      find.byKey(const Key('aifc_membership_contract_action')),
      findsNothing,
    );

    await tester.pumpWidget(
      buildSection(
        hasLinkedMember: true,
        isPersistedSchedule: false,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('aifc_quick_actions_section')), findsNothing);
    expect(find.text('AIFC 추천업무'), findsNothing);
  });

  testWidgets('미충족 상태 표시값과 무관하게 계약 버튼 탭을 중앙 진입 콜백에 위임한다', (tester) async {
    var lessonOpenCount = 0;
    var membershipOpenCount = 0;

    await tester.pumpWidget(
      buildSection(
        canUseLessonContract: false,
        canUseMembershipContract: false,
        onOpenLessonContract: () async {
          lessonOpenCount += 1;
        },
        onOpenMembershipContract: () async {
          membershipOpenCount += 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('aifc_lesson_contract_action')));
    await tester.tap(find.byKey(const Key('aifc_membership_contract_action')));
    await tester.pump();

    expect(lessonOpenCount, 1);
    expect(membershipOpenCount, 1);
    expect(find.textContaining('부터 사용할 수 있어요.'), findsNothing);
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
    expect(find.text('레슨계약서'), findsOneWidget);
    expect(find.text('회원권계약서'), findsOneWidget);
  });

  testWidgets('기존 미연결 계약 버튼은 중앙 진입 콜백을 직접 사용한다', (tester) async {
    var lessonOpenCount = 0;

    await tester.pumpWidget(
      buildSection(
        hasLinkedMember: false,
        isPersistedSchedule: true,
        canUseLessonContract: false,
        canUseMembershipContract: false,
        onOpenLessonContractFromUnregistered: () async {
          lessonOpenCount += 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('aifc_lesson_contract_action')));
    await tester.pump();

    expect(lessonOpenCount, 1);
  });

  for (final width in const [320.0, 360.0, 384.0, 411.0]) {
    testWidgets('${width.toInt()}dp에서 계약 버튼 overflow가 없다', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildSection());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('aifc_lesson_contract_action')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('aifc_membership_contract_action')),
        findsOneWidget,
      );
    });
  }

  test('계약 버튼에는 애니메이션 강조나 내부 tier 문구가 없다', () {
    final source = File(
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
        source.indexOf(
          'Future<void>',
          lessonStart + 20,
        ));
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
          'personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null'),
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
