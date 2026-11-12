import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/schedule_item.dart';
import 'package:mtf_app/services/notification_service.dart';

void main() {
  group('스마트 알람 등급 정책', () {
    test('Amateur의 기존 스마트 예약은 전체 재구축 대상으로 분류한다', () {
      final policy = buildSmartAlarmSyncPolicy(
        tierAllowed: false,
        userRequested: true,
        pendingNotificationCount: 4,
      );

      expect(policy.effective, isFalse);
      expect(policy.legacySmartReservationsPresent, isTrue);
      expect(policy.cancelledSmartCount, 4);
      expect(policy.generalNotificationsResynced, isTrue);
    });

    test('Semi-Pro는 사용자 요청이 있을 때만 스마트 알람을 사용한다', () {
      final disabled = buildSmartAlarmSyncPolicy(
        tierAllowed: true,
        userRequested: false,
        pendingNotificationCount: 2,
      );
      final enabled = buildSmartAlarmSyncPolicy(
        tierAllowed: true,
        userRequested: true,
        pendingNotificationCount: 2,
      );

      expect(disabled.effective, isFalse);
      expect(enabled.effective, isTrue);
      expect(enabled.generalNotificationsResynced, isFalse);
    });

    test('정책 로그에는 이름이나 일정 본문 없이 상태만 포함한다', () {
      final message = buildSmartAlarmPolicyDebugMessage(
        buildSmartAlarmSyncPolicy(
          tierAllowed: false,
          userRequested: true,
          pendingNotificationCount: 3,
        ),
      );

      expect(message, contains('effective=false'));
      expect(message, contains('cancelledSmartCount=3'));
      expect(message, isNot(contains('memberName')));
      expect(message, isNot(contains('lessonName')));
    });
  });

  test('Smart Alarm 의사결정 로그에 일정 개인정보를 남기지 않는다', () {
    final item = ScheduleItem(
      docId: 'private-document-id',
      startAt: DateTime(2026, 7, 22, 18),
      endAt: DateTime(2026, 7, 22, 18, 50),
      day: '수',
      time: '18:00',
      endTime: '18:50',
      name: '민감회원명',
      type: 'PT',
      attended: false,
      memberId: 'private-member-id',
      phone: '010-1234-5678',
      memo: '허리 통증 주의',
    );

    final message = buildSmartAlarmDecisionDebugMessage(
      item: item,
      decision: 'include',
      reason: 'new_day_flow',
    );

    expect(message, contains('decision=include'));
    expect(message, contains('reason=new_day_flow'));
    expect(message, contains('startAt=2026-07-22T18:00:00.000'));
    expect(message, contains('lessonTypePresent=true'));
    expect(message, contains('memberNamePresent=true'));
    expect(message, contains('memberLinked=true'));
    expect(message, isNot(contains('민감회원명')));
    expect(message, isNot(contains('PT')));
    expect(message, isNot(contains('010-1234-5678')));
    expect(message, isNot(contains('허리 통증 주의')));
    expect(message, isNot(contains('private-document-id')));
    expect(message, isNot(contains('private-member-id')));
  });
}
