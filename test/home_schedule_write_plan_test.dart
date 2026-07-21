import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/home_schedule_write_plan.dart';

void main() {
  test('단일 update는 createOrUpdate로 분류한다', () {
    final action = resolveHomeScheduleWriteAction(
      deleteCount: 0,
      writeCount: 1,
    );

    expect(action, HomeScheduleWriteAction.createOrUpdate);
  });

  test('명시적 다중 write만 createOrUpdateMany로 분류한다', () {
    final action = resolveHomeScheduleWriteAction(
      deleteCount: 0,
      writeCount: 2,
    );

    expect(action, HomeScheduleWriteAction.createOrUpdateMany);
  });

  test('source 삭제와 target write는 moveOrReplace로 분류한다', () {
    final action = resolveHomeScheduleWriteAction(
      deleteCount: 1,
      writeCount: 1,
    );

    expect(action, HomeScheduleWriteAction.moveOrReplace);
  });

  test('단일 편집은 update 또는 move 전용 commit을 사용한다', () {
    expect(
      shouldUseSingleHomeScheduleEditCommit(
        selectedDayCount: 1,
        deleteCount: 1,
        explicitMultiDaySelection: false,
      ),
      isTrue,
    );
  });

  test('명시적 다중 선택은 batch commit을 사용한다', () {
    expect(
      shouldUseSingleHomeScheduleEditCommit(
        selectedDayCount: 2,
        deleteCount: 1,
        explicitMultiDaySelection: true,
      ),
      isFalse,
    );
  });

  test('명시하지 않은 다중 target은 단일 commit 대상으로 인정하지 않는다', () {
    expect(
      shouldUseSingleHomeScheduleEditCommit(
        selectedDayCount: 3,
        deleteCount: 1,
        explicitMultiDaySelection: false,
      ),
      isFalse,
    );
  });
}
