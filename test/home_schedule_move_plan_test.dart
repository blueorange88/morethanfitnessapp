import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/home_schedule_move_plan.dart';
import 'package:mtf_app/services/home_schedule_firestore_service.dart';

void main() {
  group('HomeScheduleMovePlan', () {
    test('personal target ID는 owner scope를 한 번만 적용한다', () {
      expect(
        homeScheduleScopedDocumentId('20260724-1400-금', 'owner-a'),
        'owner-a--20260724-1400-금',
      );
      expect(
        homeScheduleScopedDocumentId(
          'owner-a--20260724-1400-금',
          'owner-a',
        ),
        'owner-a--20260724-1400-금',
      );
    });

    test('같은 personal 실제 ID는 원본 유지로 판단한다', () {
      final plan = HomeScheduleMovePlan.fromSnapshot(
        actualSourceDocId: 'owner-a--20260724-1400-금',
        dataDocId: 'owner-a--20260724-1400-금',
        targetDocId: homeScheduleScopedDocumentId(
          '20260724-1400-금',
          'owner-a',
        ),
      );
      expect(plan.shouldDeleteSource, isFalse);
    });
    test('source와 target ID가 같으면 source를 삭제하지 않는다', () {
      final plan = HomeScheduleMovePlan.fromSnapshot(
        actualSourceDocId: 'schedule-a',
        dataDocId: 'schedule-a',
        targetDocId: 'schedule-a',
      );

      expect(plan.shouldDeleteSource, isFalse);
    });

    test('source와 target ID가 다르면 실제 source를 삭제한다', () {
      final plan = HomeScheduleMovePlan.fromSnapshot(
        actualSourceDocId: 'schedule-a',
        dataDocId: 'schedule-a',
        targetDocId: 'schedule-b',
      );

      expect(plan.shouldDeleteSource, isTrue);
      expect(plan.sourceDocId, 'schedule-a');
    });

    test('data docId가 달라도 실제 snapshot ID를 source로 유지한다', () {
      final plan = HomeScheduleMovePlan.fromSnapshot(
        actualSourceDocId: 'actual-source',
        dataDocId: 'stale-field-id',
        targetDocId: 'target',
      );

      expect(plan.hasDataDocIdMismatch, isTrue);
      expect(plan.sourceDocId, 'actual-source');
      expect(plan.shouldDeleteSource, isTrue);
    });
  });

  group('HomeScheduleEditPlan', () {
    test('신규 일정은 source 삭제 없는 create로 계획한다', () {
      final plan = HomeScheduleEditPlan.resolve(
        sourceActualDocId: '',
        targetActualDocIds: {'trainer-a--20260721-1300-화'},
      );

      expect(plan.branch, HomeScheduleEditBranch.create);
      expect(plan.sourceIsRetained, isFalse);
      expect(plan.deleteSource, isFalse);
      expect(plan.writeCount, 1);
    });

    test('신규 다중 일정도 원본 삭제 없이 target만 생성한다', () {
      final plan = HomeScheduleEditPlan.resolve(
        sourceActualDocId: '',
        targetActualDocIds: {
          'trainer-a--20260721-1300-화',
          'trainer-a--20260722-1300-수',
        },
      );

      expect(plan.branch, HomeScheduleEditBranch.create);
      expect(plan.deleteSource, isFalse);
      expect(plan.writeCount, 2);
    });

    const source = 'owner--20260724-1400-금';

    test('원래 요일만 선택하면 update하며 source를 삭제하지 않는다', () {
      final plan = HomeScheduleEditPlan.resolve(
        sourceActualDocId: source,
        targetActualDocIds: {source},
      );
      expect(plan.branch, HomeScheduleEditBranch.update);
      expect(plan.sourceIsRetained, isTrue);
      expect(plan.deleteSource, isFalse);
    });

    test('원래 요일과 추가 요일은 copyMany이며 source를 유지한다', () {
      final plan = HomeScheduleEditPlan.resolve(
        sourceActualDocId: source,
        targetActualDocIds: {source, 'owner--20260723-1400-목'},
      );
      expect(plan.branch, HomeScheduleEditBranch.copyMany);
      expect(plan.sourceIsRetained, isTrue);
      expect(plan.deleteSource, isFalse);
      expect(plan.writeCount, 2);
    });

    test('원래 요일을 빼고 하나를 고르면 move한다', () {
      final plan = HomeScheduleEditPlan.resolve(
        sourceActualDocId: source,
        targetActualDocIds: {'owner--20260723-1400-목'},
      );
      expect(plan.branch, HomeScheduleEditBranch.move);
      expect(plan.deleteSource, isTrue);
    });

    test('원래 요일을 빼고 여러 요일을 고르면 replaceMany한다', () {
      final plan = HomeScheduleEditPlan.resolve(
        sourceActualDocId: source,
        targetActualDocIds: {
          'owner--20260723-1400-목',
          'owner--20260722-1400-수',
        },
      );
      expect(plan.branch, HomeScheduleEditBranch.replaceMany);
      expect(plan.deleteSource, isTrue);
      expect(plan.writeCount, 2);
    });
  });

  group('schedule conflict candidate', () {
    final targetStart = DateTime(2026, 7, 23, 14);
    final targetEnd = DateTime(2026, 7, 23, 15);

    test('actual 또는 duplicate source ID는 자기 자신 충돌에서 제외한다', () {
      for (final id in {'actual', 'duplicate'}) {
        expect(
          isHomeScheduleConflictCandidate(
            candidateDocId: id,
            candidateStartAt: targetStart,
            candidateEndAt: targetEnd,
            targetStartAt: targetStart,
            targetEndAt: targetEnd,
            ignoreDocIds: {'actual', 'duplicate'},
          ),
          isFalse,
        );
      }
    });

    test('같은 시간이어도 다른 날짜면 충돌하지 않는다', () {
      expect(
        isHomeScheduleConflictCandidate(
          candidateDocId: 'other-day',
          candidateStartAt: DateTime(2026, 7, 24, 14),
          candidateEndAt: DateTime(2026, 7, 24, 15),
          targetStartAt: targetStart,
          targetEndAt: targetEnd,
        ),
        isFalse,
      );
    });

    test('같은 날짜의 실제 겹침만 충돌한다', () {
      expect(
        isHomeScheduleConflictCandidate(
          candidateDocId: 'real-conflict',
          candidateStartAt: DateTime(2026, 7, 23, 14, 30),
          candidateEndAt: DateTime(2026, 7, 23, 15, 30),
          targetStartAt: targetStart,
          targetEndAt: targetEnd,
        ),
        isTrue,
      );
    });

    test('tombstone 또는 pending delete 후보는 충돌하지 않는다', () {
      expect(
        isHomeScheduleConflictCandidate(
          candidateDocId: 'hidden',
          candidateStartAt: targetStart,
          candidateEndAt: targetEnd,
          targetStartAt: targetStart,
          targetEndAt: targetEnd,
          isTemporarilyHidden: true,
        ),
        isFalse,
      );
      expect(
        isHomeScheduleConflictCandidate(
          candidateDocId: 'deleted',
          candidateStartAt: targetStart,
          candidateEndAt: targetEnd,
          targetStartAt: targetStart,
          targetEndAt: targetEnd,
          isDeleted: true,
        ),
        isFalse,
      );
    });
  });

  group('source server verification', () {
    test('copyMany는 retained source가 서버에 남아 있으면 성공이다', () {
      expect(
        isHomeScheduleSourceVerificationSuccessful(
          sourceRetained: true,
          sourceExists: true,
        ),
        isTrue,
      );
    });

    test('move는 제거한 source가 서버에 없으면 성공이다', () {
      expect(
        isHomeScheduleSourceVerificationSuccessful(
          sourceRetained: false,
          sourceExists: false,
        ),
        isTrue,
      );
    });

    test('copyMany source가 사라진 경우에만 검증 실패다', () {
      expect(
        isHomeScheduleSourceVerificationSuccessful(
          sourceRetained: true,
          sourceExists: false,
        ),
        isFalse,
      );
    });
  });
}
