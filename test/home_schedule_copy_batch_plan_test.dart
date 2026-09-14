import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/home_schedule_firestore_service.dart';

HomeScheduleEditWrite write(int index, {String memberId = ''}) {
  return HomeScheduleEditWrite(
    targetDocId: 'target-$index',
    data: {'name': '회원 $index', if (memberId.isNotEmpty) 'memberId': memberId},
  );
}

void main() {
  test('PROD형 37개 회원연결 일정은 고유 회원 10개 이하 배치로 분할한다', () {
    final writes = List.generate(
      37,
      (index) => write(index, memberId: 'member-${index % 17}'),
    );

    final batches = planHomeScheduleCopyWriteBatches(writes);

    expect(batches.length, 2);
    expect(batches.expand((batch) => batch).toSet(), writes.toSet());
    for (final batch in batches) {
      final memberIds =
          batch
              .map((item) => item.data['memberId'].toString())
              .where((memberId) => memberId.isNotEmpty)
              .toSet();
      expect(
        memberIds.length,
        lessThanOrEqualTo(homeScheduleCopyMaxDistinctMemberLinksPerBatch),
      );
    }
  });

  test('같은 회원의 일정은 Rules 캐시를 활용해 한 배치에 유지한다', () {
    final writes = List.generate(
      37,
      (index) => write(index, memberId: 'same-member'),
    );

    final batches = planHomeScheduleCopyWriteBatches(writes);

    expect(batches, hasLength(1));
    expect(batches.single, hasLength(37));
  });

  test('회원 미연결 일정도 Firestore write 한도 여유분에 맞춰 분할한다', () {
    final writes = List.generate(451, write);

    final batches = planHomeScheduleCopyWriteBatches(writes);

    expect(batches.map((batch) => batch.length), [450, 1]);
    expect(batches.expand((batch) => batch), orderedEquals(writes));
  });
}
