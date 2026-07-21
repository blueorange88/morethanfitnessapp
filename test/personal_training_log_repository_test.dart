import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/personal_training_log.dart';
import 'package:mtf_app/services/personal_training_log_repository.dart';

void main() {
  final start = DateTime(2026, 7, 20, 14);

  PersonalTrainingLogDraft draft({
    String memberId = 'member-a',
    String? scheduleId,
    String source = 'formal',
  }) {
    return PersonalTrainingLogDraft(
      memberId: memberId,
      scheduleDocId: scheduleId,
      lessonDate: DateTime(2026, 7, 20),
      startAt: start,
      endAt: start.add(const Duration(minutes: 50)),
      lessonType: 'PT',
      memo: '하체 운동',
      source: source,
    );
  }

  _Harness harness({String uid = 'trainer-a'}) {
    final source = _MemoryLogDataSource(uid: uid)
      ..members['member-a'] = _member('member-a', uid);
    final gateway = _MemoryMutationGateway(source);
    return _Harness(
      source,
      gateway,
      PersonalTrainingLogRepository(
        uid: uid,
        dataSource: source,
        mutationGateway: gateway,
      ),
    );
  }

  test('일반 레슨일지 초안은 canonical owner와 random id를 사용한다', () async {
    final value = harness();
    final first = await value.repository.createDraft(draft());
    final second = await value.repository.createDraft(draft());
    expect(first, isNot(second));
    final record = value.source.records[first]!;
    expect(record.trainerId, 'trainer-a');
    expect(record.workspaceType, 'personal');
    expect(record.lessonLogId, first);
    expect(record.source, 'formal');
  });

  test('schedule 없는 직접 작성도 저장한다', () async {
    final value = harness();
    final id = await value.repository.createDraft(draft());
    expect(value.source.records[id]!.scheduleDocId, isNull);
  });

  test('다른 trainer 회원 연결은 거부한다', () async {
    final value = harness()
      ..source.members['member-b'] = _member('member-b', 'trainer-b');
    await expectLater(
      value.repository.createDraft(draft(memberId: 'member-b')),
      throwsA(isA<PersonalTrainingLogException>()),
    );
    expect(value.source.records, isEmpty);
  });

  test('다른 trainer 일정 연결은 거부한다', () async {
    final value = harness()
      ..source.schedules['schedule-b'] = _schedule(
        'schedule-b',
        'trainer-b',
        'member-a',
      );
    await expectLater(
      value.repository.createDraft(draft(scheduleId: 'schedule-b')),
      throwsA(isA<PersonalTrainingLogException>()),
    );
  });

  test('일정의 연결 회원이 다르면 거부한다', () async {
    final value = harness()
      ..source.schedules['schedule-a'] = _schedule(
        'schedule-a',
        'trainer-a',
        'member-other',
      );
    await expectLater(
      value.repository.createDraft(draft(scheduleId: 'schedule-a')),
      throwsA(isA<PersonalTrainingLogException>()),
    );
  });

  test('자동저장은 내용만 바꾸고 identity를 유지한다', () async {
    final value = harness();
    final id = await value.repository.createDraft(draft());
    await value.repository.autosave(id, draft().copyWith(memo: '수정 메모'));
    final record = value.source.records[id]!;
    expect(record.memo, '수정 메모');
    expect(record.memberId, 'member-a');
    expect(record.trainerId, 'trainer-a');
  });

  test('자동저장에서 member identity 변경을 거부한다', () async {
    final value = harness()
      ..source.members['member-c'] = _member('member-c', 'trainer-a');
    final id = await value.repository.createDraft(draft());
    await expectLater(
      value.repository.autosave(id, draft(memberId: 'member-c')),
      throwsA(
        isA<PersonalTrainingLogException>().having(
          (error) => error.failure,
          'failure',
          PersonalTrainingLogFailure.immutableIdentity,
        ),
      ),
    );
  });

  test('네 확정 상태를 공통 mutation gateway로 전달한다', () async {
    for (final status in PersonalTrainingLogStatus.finalized) {
      final value = harness();
      final id = await value.repository.createDraft(draft());
      await value.repository.finalize(id, status);
      expect(value.gateway.finalizeCalls.single, '$id:$status');
    }
  });

  test('빠른서명과 정식 레슨일지는 같은 canonical 경로를 사용한다', () async {
    final value = harness();
    final formal = await value.repository.createDraft(draft());
    final quick = await value.repository.saveQuickSign(
      draft: draft(),
      status: PersonalTrainingLogStatus.completed,
    );
    expect(value.source.records[formal]!.source, 'formal');
    expect(value.source.records[quick]!.source, 'home_quick_sign');
    expect(value.source.records[quick]!.trainerId, 'trainer-a');
    expect(value.gateway.finalizeCalls, ['$quick:completed']);
  });

  test('확정취소도 같은 owner gateway를 사용한다', () async {
    final value = harness();
    final id = await value.repository.createDraft(draft());
    await value.repository.finalize(id, PersonalTrainingLogStatus.completed);
    await value.repository.cancelFinalize(id);
    expect(value.gateway.cancelCalls, [id]);
  });

  test('회원별 목록은 현재 UID와 personal 문서만 반환한다', () async {
    final value = harness();
    final id = await value.repository.createDraft(draft());
    value.source.records['other'] = _record(
      id: 'other',
      uid: 'trainer-b',
      memberId: 'member-a',
      start: start,
    );
    final records = await value.repository
        .watchMemberRange(
          memberId: 'member-a',
          start: DateTime(2026, 7, 20),
          endExclusive: DateTime(2026, 7, 21),
        )
        .first;
    expect(records.map((record) => record.lessonLogId), [id]);
  });

  test('UID 변경 후 이전 repository 접근을 차단한다', () async {
    final value = harness();
    value.source.uid = 'trainer-b';
    expect(
      () => value.repository.createDraft(draft()),
      throwsA(isA<PersonalTrainingLogException>()),
    );
  });
}

Map<String, dynamic> _member(String id, String uid) => {
      'memberId': id,
      'trainerId': uid,
      'workspaceType': 'personal',
      'managementState': 'active',
    };

Map<String, dynamic> _schedule(String id, String uid, String memberId) => {
      'scheduleId': id,
      'trainerId': uid,
      'workspaceType': 'personal',
      'memberId': memberId,
    };

PersonalTrainingLogRecord _record({
  required String id,
  required String uid,
  required String memberId,
  required DateTime start,
  String status = 'draft',
  String source = 'formal',
  String memo = '',
  String? scheduleId,
}) {
  return PersonalTrainingLogRecord(
    lessonLogId: id,
    trainerId: uid,
    workspaceType: 'personal',
    schemaVersion: 1,
    memberId: memberId,
    scheduleDocId: scheduleId,
    lessonDate: DateTime(start.year, start.month, start.day),
    startAt: start,
    endAt: start.add(const Duration(minutes: 50)),
    lessonType: 'PT',
    status: status,
    source: source,
    memo: memo,
  );
}

class _Harness {
  const _Harness(this.source, this.gateway, this.repository);

  final _MemoryLogDataSource source;
  final _MemoryMutationGateway gateway;
  final PersonalTrainingLogRepository repository;
}

class _MemoryLogDataSource implements PersonalTrainingLogDataSource {
  _MemoryLogDataSource({required this.uid});

  String? uid;
  var nextId = 0;
  final records = <String, PersonalTrainingLogRecord>{};
  final members = <String, Map<String, dynamic>>{};
  final schedules = <String, Map<String, dynamic>>{};

  @override
  String? get currentUid => uid;

  @override
  String newLogId() => 'log-${++nextId}';

  @override
  Stream<List<PersonalTrainingLogRecord>> watchMemberRange({
    required String uid,
    required String memberId,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    return Stream.value(
      records.values
          .where(
            (record) =>
                record.trainerId == uid &&
                record.workspaceType == 'personal' &&
                record.memberId == memberId &&
                !record.startAt.isBefore(start) &&
                record.startAt.isBefore(endExclusive),
          )
          .toList(),
    );
  }

  @override
  Future<Map<String, dynamic>?> loadMember(String memberId) async =>
      members[memberId];

  @override
  Future<Map<String, dynamic>?> loadSchedule(String scheduleId) async =>
      schedules[scheduleId];

  @override
  Future<PersonalTrainingLogRecord?> loadLog(String lessonLogId) async =>
      records[lessonLogId];

  @override
  Future<void> createLog(
    String lessonLogId,
    Map<String, dynamic> data,
  ) async {
    records[lessonLogId] = _record(
      id: lessonLogId,
      uid: data['trainerId'] as String,
      memberId: data['memberId'] as String,
      start: data['startAt'] as DateTime,
      source: data['source'] as String,
      memo: data['memo'] as String,
      scheduleId: data['scheduleDocId'] as String?,
    );
  }

  @override
  Future<void> updateLog(
    String lessonLogId,
    Map<String, dynamic> changes,
  ) async {
    final current = records[lessonLogId]!;
    records[lessonLogId] = _record(
      id: current.lessonLogId,
      uid: current.trainerId,
      memberId: current.memberId,
      start: changes['startAt'] as DateTime? ?? current.startAt,
      status: current.status,
      source: current.source,
      memo: changes['memo'] as String? ?? current.memo,
      scheduleId: changes['scheduleDocId'] is String
          ? changes['scheduleDocId'] as String
          : current.scheduleDocId,
    );
  }

  @override
  Future<void> deleteLog(String lessonLogId) async {
    records.remove(lessonLogId);
  }
}

class _MemoryMutationGateway implements PersonalTrainingLogMutationGateway {
  _MemoryMutationGateway(this.source);

  final _MemoryLogDataSource source;
  final finalizeCalls = <String>[];
  final cancelCalls = <String>[];

  @override
  Future<Map<String, dynamic>> finalize({
    required String lessonLogId,
    required String status,
  }) async {
    finalizeCalls.add('$lessonLogId:$status');
    final current = source.records[lessonLogId]!;
    source.records[lessonLogId] = _record(
      id: current.lessonLogId,
      uid: current.trainerId,
      memberId: current.memberId,
      start: current.startAt,
      status: status,
      source: current.source,
      memo: current.memo,
      scheduleId: current.scheduleDocId,
    );
    return {'lessonLogId': lessonLogId, 'status': status};
  }

  @override
  Future<Map<String, dynamic>> cancel(String lessonLogId) async {
    cancelCalls.add(lessonLogId);
    return {'lessonLogId': lessonLogId, 'alreadyCancelled': false};
  }
}
