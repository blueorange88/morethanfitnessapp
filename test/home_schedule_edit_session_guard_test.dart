import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/home_schedule_edit_session_guard.dart';

void main() {
  HomeScheduleEditSessionGuard buildGuard() {
    return HomeScheduleEditSessionGuard(
      editSessionId: 'edit-1',
      currentActualDocId: 'source-A',
      currentDataDocId: 'source-A',
      currentStartAt: DateTime(2026, 7, 13, 14),
    );
  }

  test('이동 성공 후 current identity를 target으로 교체한다', () {
    final guard = buildGuard();

    final attempt = guard.begin(HomeScheduleEditMutationAction.save);
    guard.completeSave(
      targetActualDocId: 'target-B',
      targetDataDocId: 'target-B',
      targetStartAt: DateTime(2026, 7, 13, 13),
      moved: true,
    );

    expect(attempt.allowed, isTrue);
    expect(guard.state, HomeScheduleEditSessionState.moved);
    expect(guard.currentActualDocId, 'target-B');
    expect(guard.currentDataDocId, 'target-B');
    expect(guard.currentStartAt, DateTime(2026, 7, 13, 13));
  });

  test('이동 저장 중 삭제 재진입을 차단한다', () {
    final guard = buildGuard();

    final save = guard.begin(HomeScheduleEditMutationAction.save);
    final delete = guard.begin(HomeScheduleEditMutationAction.delete);

    expect(save.allowed, isTrue);
    expect(delete.allowed, isFalse);
    expect(delete.ignoredReason, 'state_saving');
  });

  test('이동 완료 세션은 target identity를 남기고 후속 삭제를 차단한다', () {
    final guard = buildGuard();

    guard.begin(HomeScheduleEditMutationAction.save);
    guard.completeSave(
      targetActualDocId: 'target-B',
      targetDataDocId: 'target-B',
      targetStartAt: DateTime(2026, 7, 13, 13),
      moved: true,
    );
    final delete = guard.begin(HomeScheduleEditMutationAction.delete);

    expect(guard.currentActualDocId, 'target-B');
    expect(delete.allowed, isFalse);
    expect(delete.ignoredReason, 'state_moved');
  });

  test('삭제 완료 후 모든 후속 저장을 차단한다', () {
    final guard = buildGuard();

    guard.begin(HomeScheduleEditMutationAction.delete);
    guard.completeDelete();
    final save = guard.begin(HomeScheduleEditMutationAction.save);

    expect(guard.state, HomeScheduleEditSessionState.deleted);
    expect(save.allowed, isFalse);
    expect(save.ignoredReason, 'state_deleted');
  });

  test('빠른 저장 두 번은 첫 mutation만 허용한다', () {
    final guard = buildGuard();

    final first = guard.begin(HomeScheduleEditMutationAction.save);
    final second = guard.begin(HomeScheduleEditMutationAction.save);

    expect(first.allowed, isTrue);
    expect(second.allowed, isFalse);
  });

  test('단일 편집은 이전 반복 요일을 가져오지 않는다', () {
    final selectedDays = initialHomeScheduleEditSelectedDays('수');

    expect(selectedDays, {'수'});
    expect(isExplicitHomeScheduleMultiDay(selectedDays), isFalse);

    selectedDays.add('금');
    expect(isExplicitHomeScheduleMultiDay(selectedDays), isTrue);
  });

  test('다중 등록 뒤 새 단일 편집 세션은 현재 요일 하나로 초기화한다', () {
    final multiSession = HomeScheduleEditSelectionState.single(currentDay: '월');
    multiSession.toggleDay(
      '수',
      caller: 'test.daySelector',
      userAction: 'toggleWeekday',
    );
    multiSession.toggleDay(
      '금',
      caller: 'test.daySelector',
      userAction: 'toggleWeekday',
    );
    expect(multiSession.selectedDays, {'월', '수', '금'});
    expect(multiSession.explicitMultiDaySelection, isTrue);
    multiSession.dispose();

    final thursdaySession =
        HomeScheduleEditSelectionState.single(currentDay: '목');
    expect(thursdaySession.selectedDays, {'목'});
    expect(thursdaySession.explicitMultiDaySelection, isFalse);
  });

  test('이동된 단일 레슨을 다시 열면 다중 상태를 상속하지 않는다', () {
    final firstSession = HomeScheduleEditSelectionState.single(currentDay: '금');
    firstSession.toggleDay(
      '목',
      caller: 'test.daySelector',
      userAction: 'toggleWeekday',
    );
    firstSession.dispose();

    final reopened = HomeScheduleEditSelectionState.single(currentDay: '금');
    final save = reopened.prepareForSave(currentTargetDay: '금');

    expect(save.selectedDays, {'금'});
    expect(save.isMultiDay, isFalse);
    expect(save.explicitMultiDaySelection, isFalse);
  });

  test('현재 세션에서 월 수 금을 직접 선택한 경우만 명시적 다중이다', () {
    final state = HomeScheduleEditSelectionState.single(currentDay: '월');
    state.toggleDay(
      '수',
      caller: 'HomeLessonDaySelector.onDayTapped',
      userAction: 'toggleWeekday',
    );
    state.toggleDay(
      '금',
      caller: 'HomeLessonDaySelector.onDayTapped',
      userAction: 'toggleWeekday',
    );

    final save = state.prepareForSave(currentTargetDay: '월');
    expect(save.selectedDays, {'월', '수', '금'});
    expect(save.explicitMultiDaySelection, isTrue);
    expect(save.isMultiDay, isTrue);
    expect(state.lastChangedCaller, 'HomeLessonDaySelector.onDayTapped');
  });

  test('오염된 암시적 다중 상태는 저장 직전 현재 날짜 하나로 보정한다', () {
    final save = normalizeHomeScheduleEditSelectionForSave(
      currentTargetDay: '목',
      selectedDays: {'월', '수', '목'},
      explicitMultiDaySelection: false,
    );

    expect(save.selectedDays, {'목'});
    expect(save.isMultiDay, isFalse);
    expect(save.invariantCorrected, isTrue);
    expect(save.correctionReason, 'implicit_single_selection_state_leak');
  });
}
