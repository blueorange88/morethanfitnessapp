import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/home_schedule_tombstone_guard.dart';

void main() {
  group('shouldApplyHomeScheduleSnapshot', () {
    test('최신 binding의 최신 revision만 적용한다', () {
      expect(
        shouldApplyHomeScheduleSnapshot(
          bindingId: 2,
          currentBindingId: 2,
          revision: 4,
          latestRevision: 4,
        ),
        isTrue,
      );
      expect(
        shouldApplyHomeScheduleSnapshot(
          bindingId: 2,
          currentBindingId: 2,
          revision: 3,
          latestRevision: 4,
        ),
        isFalse,
      );
      expect(
        shouldApplyHomeScheduleSnapshot(
          bindingId: 1,
          currentBindingId: 2,
          revision: 4,
          latestRevision: 4,
        ),
        isFalse,
      );
    });
  });

  group('resolveHomeScheduleTombstone', () {
    test('캐시 snapshot에서는 source 부재여도 tombstone을 유지한다', () {
      expect(
        resolveHomeScheduleTombstone(
          isFromCache: true,
          hasPendingWrites: false,
          mutationInFlight: false,
          sourcePresent: false,
        ),
        HomeScheduleTombstoneDecision.keep,
      );
    });

    test('pending writes 또는 mutation 진행 중에는 유지한다', () {
      expect(
        resolveHomeScheduleTombstone(
          isFromCache: false,
          hasPendingWrites: true,
          mutationInFlight: false,
          sourcePresent: false,
        ),
        HomeScheduleTombstoneDecision.keep,
      );
      expect(
        resolveHomeScheduleTombstone(
          isFromCache: false,
          hasPendingWrites: false,
          mutationInFlight: true,
          sourcePresent: true,
        ),
        HomeScheduleTombstoneDecision.keep,
      );
    });

    test('authoritative snapshot에서 source 부재를 확인하면 해제한다', () {
      expect(
        resolveHomeScheduleTombstone(
          isFromCache: false,
          hasPendingWrites: false,
          mutationInFlight: false,
          sourcePresent: false,
        ),
        HomeScheduleTombstoneDecision.confirmedDeleted,
      );
    });

    test('authoritative snapshot에 source가 남아 있으면 실패 상태로 해제한다', () {
      expect(
        resolveHomeScheduleTombstone(
          isFromCache: false,
          hasPendingWrites: false,
          mutationInFlight: false,
          sourcePresent: true,
        ),
        HomeScheduleTombstoneDecision.sourceStillExists,
      );
    });
  });
}
