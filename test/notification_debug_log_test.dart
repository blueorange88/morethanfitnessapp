import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/schedule_item.dart';
import 'package:mtf_app/services/notification_service.dart';

void main() {
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
