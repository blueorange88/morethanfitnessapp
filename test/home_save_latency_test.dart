import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('레슨 저장은 서버 확인을 끝까지 기다리지 않고 늦은 거부는 따로 알린다', () {
    final source =
        File(
          'lib/services/home_schedule_firestore_service.dart',
        ).readAsStringSync();
    final start = source.indexOf('static Future<void> saveSchedule(');
    final end = source.indexOf('static Future<void> deleteSchedule(');
    final body = source.substring(start, end);

    expect(body, contains('write.timeout('));
    expect(body, contains('ackWait'));
    expect(body, contains('onLateFailure'));
  });

  test('저장 호출 쪽은 늦은 서버 거부를 사용자에게 알린다', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _saveScheduleToFirestore(');
    final end = source.indexOf('Future<void> _refreshMemberNextLesson(');
    expect(source.substring(start, end), contains('onLateFailure:'));
  });

  test('횟수 새로고침은 겹쳐 돌지 않고 회원별로 한 번만 읽는다', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();
    final start = source.indexOf(
      'Future<void>? _scheduleCountsRefreshInFlight',
    );
    final end = source.indexOf('String _buildTodayLessonCountText');
    final body = source.substring(start, end);

    expect(body, contains('_scheduleCountsRefreshDirty'));
    expect(body, contains('putIfAbsent'));
    expect(body, contains('await isDeletedMemo(memberId)'));
    expect(body, contains('await smartFieldsMemo(memberId)'));
    expect(body, contains('await countFieldsMemo(memberId)'));
  });
}
