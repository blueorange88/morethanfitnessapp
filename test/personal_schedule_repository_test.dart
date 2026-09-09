import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/personal_schedule.dart';
import 'package:mtf_app/services/personal_schedule_repository.dart';
import 'package:mtf_app/services/personal_schedule_widget_sync_service.dart';

void main() {
  final start = DateTime(2026, 7, 20, 14);

  PersonalScheduleDraft draft({
    DateTime? at,
    String? memberId,
    String name = '홍길동',
  }) {
    final value = at ?? start;
    return PersonalScheduleDraft(
      startAt: value,
      endAt: value.add(const Duration(minutes: 50)),
      name: name,
      type: 'PT',
      memberId: memberId,
    );
  }

  test('같은 시간 일정도 random document id가 충돌하지 않는다', () async {
    final source = _MemoryScheduleDataSource(uid: 'trainer-a');
    final repository = PersonalScheduleRepository(
      uid: 'trainer-a',
      dataSource: source,
    );
    final left = await repository.create(draft());
    final right = await repository.create(draft(name: '김회원'));
    expect(left, isNot(right));
    expect(source.records, hasLength(2));
  });

  test('단일 생성은 canonical owner와 slot 필드를 고정한다', () async {
    final source = _MemoryScheduleDataSource(uid: 'trainer-a');
    final repository = PersonalScheduleRepository(
      uid: 'trainer-a',
      dataSource: source,
    );
    final id = await repository.create(draft());
    final record = source.records[id]!;
    expect(id, startsWith('trainer-a--'));
    expect(record.trainerId, 'trainer-a');
    expect(record.workspaceType, 'personal');
    expect(record.scheduleId, id);
    expect(record.dateKey, '2026-07-20');
    expect(record.slotKey, '2026-07-20T14:00');
  });

  test('멀티 등록은 선택한 날짜별 새 문서만 생성한다', () async {
    final source = _MemoryScheduleDataSource(uid: 'trainer-a');
    final repository = PersonalScheduleRepository(
      uid: 'trainer-a',
      dataSource: source,
    );
    final ids = await repository.createMany([
      draft(),
      draft(at: start.add(const Duration(days: 2))),
      draft(at: start.add(const Duration(days: 4))),
    ]);
    expect(ids.toSet(), hasLength(3));
    expect(source.records, hasLength(3));
  });

  test('수정은 owner와 document identity를 유지한다', () async {
    final source = _MemoryScheduleDataSource(uid: 'trainer-a');
    final repository = PersonalScheduleRepository(
      uid: 'trainer-a',
      dataSource: source,
    );
    final id = await repository.create(draft());
    await repository.update(id, draft(name: '수정 회원'));
    expect(source.records[id]!.name, '수정 회원');
    expect(source.records[id]!.trainerId, 'trainer-a');
  });

  test('시간 이동은 같은 document id를 원자적으로 갱신한다', () async {
    final source = _MemoryScheduleDataSource(uid: 'trainer-a');
    final repository = PersonalScheduleRepository(
      uid: 'trainer-a',
      dataSource: source,
    );
    final id = await repository.create(draft());
    await repository.move(
      scheduleId: id,
      startAt: start.add(const Duration(hours: 1)),
      endAt: start.add(const Duration(hours: 1, minutes: 50)),
    );
    expect(source.records.keys, [id]);
    expect(source.records[id]!.startAt.hour, 15);
  });

  test('이동 write 실패 시 기존 일정이 그대로 남는다', () async {
    final source = _MemoryScheduleDataSource(uid: 'trainer-a');
    final repository = PersonalScheduleRepository(
      uid: 'trainer-a',
      dataSource: source,
    );
    final id = await repository.create(draft());
    source.failNextUpdate = true;
    await expectLater(
      repository.move(
        scheduleId: id,
        startAt: start.add(const Duration(hours: 2)),
        endAt: start.add(const Duration(hours: 2, minutes: 50)),
      ),
      throwsA(isA<StateError>()),
    );
    expect(source.records[id]!.startAt, start);
  });

  test('삭제는 선택한 본인 일정 하나만 제거한다', () async {
    final source = _MemoryScheduleDataSource(uid: 'trainer-a');
    final repository = PersonalScheduleRepository(
      uid: 'trainer-a',
      dataSource: source,
    );
    final first = await repository.create(draft());
    final second = await repository.create(draft(name: '유지'));
    await repository.delete(first);
    expect(source.records.containsKey(first), false);
    expect(source.records.containsKey(second), true);
  });

  test('다른 trainer 회원은 일정에 연결할 수 없다', () async {
    final source = _MemoryScheduleDataSource(uid: 'trainer-a')
      ..members['other-member'] = {
        'trainerId': 'trainer-b',
        'workspaceType': 'personal',
        'managementState': 'active',
      };
    final repository = PersonalScheduleRepository(
      uid: 'trainer-a',
      dataSource: source,
    );
    await expectLater(
      repository.create(draft(memberId: 'other-member')),
      throwsA(
        isA<PersonalScheduleException>().having(
          (error) => error.failure,
          'failure',
          PersonalScheduleFailure.memberNotOwned,
        ),
      ),
    );
    expect(source.records, isEmpty);
  });

  test('현재 trainer의 personal 회원만 일정에 연결할 수 있다', () async {
    final source = _MemoryScheduleDataSource(uid: 'trainer-a')
      ..members['owned-member'] = {
        'trainerId': 'trainer-a',
        'workspaceType': 'personal',
        'managementState': 'active',
      };
    final repository = PersonalScheduleRepository(
      uid: 'trainer-a',
      dataSource: source,
    );
    final id = await repository.create(draft(memberId: 'owned-member'));
    expect(source.records[id]!.memberId, 'owned-member');
  });

  test('이름만 있는 임시 일정은 회원 문서를 조회하거나 생성하지 않는다', () async {
    final source = _MemoryScheduleDataSource(uid: 'trainer-a');
    final repository = PersonalScheduleRepository(
      uid: 'trainer-a',
      dataSource: source,
    );
    await repository.create(draft(name: '임시 대상'));
    expect(source.memberReads, 0);
    expect(source.members, isEmpty);
    expect(source.records.values.single.memberId, isNull);
  });

  test('주간 복사는 새 ID와 같은 owner를 사용한다', () async {
    final source = _MemoryScheduleDataSource(uid: 'trainer-a');
    final repository = PersonalScheduleRepository(
      uid: 'trainer-a',
      dataSource: source,
    );
    final sourceId = await repository.create(draft());
    final copied = await repository.copyToWeek(
      source: [source.records[sourceId]!],
      targetMonday: DateTime(2026, 7, 27),
    );
    expect(copied.single, isNot(sourceId));
    expect(source.records[copied.single]!.trainerId, 'trainer-a');
    expect(source.records[copied.single]!.startAt, DateTime(2026, 7, 27, 14));
  });

  test('Auth UID 변경 후 이전 repository mutation을 차단한다', () async {
    final source = _MemoryScheduleDataSource(uid: 'trainer-a');
    final repository = PersonalScheduleRepository(
      uid: 'trainer-a',
      dataSource: source,
    );
    source.uid = 'trainer-b';
    expect(
      () => repository.create(draft()),
      throwsA(isA<PersonalScheduleException>()),
    );
  });

  test('앱 재실행을 가정한 새 repository도 같은 UID 일정만 읽는다', () async {
    final source = _MemoryScheduleDataSource(uid: 'trainer-a');
    final firstRepository = PersonalScheduleRepository(
      uid: 'trainer-a',
      dataSource: source,
    );
    final id = await firstRepository.create(draft());

    final reopenedRepository = PersonalScheduleRepository(
      uid: 'trainer-a',
      dataSource: source,
    );
    final records = await reopenedRepository
        .watchRange(
          start: DateTime(2026, 7, 20),
          endExclusive: DateTime(2026, 7, 21),
        )
        .first;
    expect(records.map((record) => record.scheduleId), [id]);
  });

  test('확정된 일정은 수정과 삭제를 차단한다', () async {
    final source = _MemoryScheduleDataSource(uid: 'trainer-a')
      ..records['confirmed'] = _record(
        id: 'confirmed',
        uid: 'trainer-a',
        start: start,
        confirmed: true,
      );
    final repository = PersonalScheduleRepository(
      uid: 'trainer-a',
      dataSource: source,
    );
    await expectLater(
      repository.update('confirmed', draft()),
      throwsA(isA<PersonalScheduleException>()),
    );
    await expectLater(
      repository.delete('confirmed'),
      throwsA(isA<PersonalScheduleException>()),
    );
  });

  test('widget은 현재 UID 일정만 전달한다', () async {
    final gateway = _FakeWidgetGateway();
    final service = PersonalScheduleWidgetSyncService(
      uid: 'trainer-a',
      gateway: gateway,
    );
    await service.sync([
      _record(id: 'a', uid: 'trainer-a', start: start),
      _record(id: 'b', uid: 'trainer-b', start: start),
    ]);
    expect(gateway.synced.map((record) => record.scheduleId), ['a']);
    expect(gateway.owner, 'trainer-a');
  });

  test('widget UID 변경과 로그아웃은 이전 cache를 제거한다', () async {
    final gateway = _FakeWidgetGateway()..owner = 'trainer-old';
    final service = PersonalScheduleWidgetSyncService(
      uid: 'trainer-new',
      gateway: gateway,
    );
    await service.sync([
      _record(id: 'new', uid: 'trainer-new', start: start),
    ]);
    expect(gateway.clearCalls, 1);
    expect(gateway.owner, 'trainer-new');
    await service.clearForSignOut();
    expect(gateway.clearCalls, 2);
    expect(gateway.owner, '');
  });
}

PersonalScheduleRecord _record({
  required String id,
  required String uid,
  required DateTime start,
  bool confirmed = false,
}) {
  return PersonalScheduleRecord(
    scheduleId: id,
    trainerId: uid,
    workspaceType: 'personal',
    schemaVersion: 1,
    startAt: start,
    endAt: start.add(const Duration(minutes: 50)),
    dateKey: PersonalScheduleDocumentIdentity.dateKey(start),
    slotKey: PersonalScheduleDocumentIdentity.slotKey(start),
    name: '회원',
    type: 'PT',
    status: 'scheduled',
    lessonConfirmed: confirmed,
  );
}

class _MemoryScheduleDataSource implements PersonalScheduleDataSource {
  _MemoryScheduleDataSource({required this.uid});

  String? uid;
  var nextId = 0;
  var memberReads = 0;
  var failNextUpdate = false;
  final records = <String, PersonalScheduleRecord>{};
  final members = <String, Map<String, dynamic>>{};

  @override
  String? get currentUid => uid;

  @override
  String newScheduleId() => 'personal-${++nextId}';

  @override
  Stream<List<PersonalScheduleRecord>> watchRange({
    required String uid,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    return Stream.value(
      records.values
          .where(
            (record) =>
                record.trainerId == uid &&
                !record.startAt.isBefore(start) &&
                record.startAt.isBefore(endExclusive),
          )
          .toList(),
    );
  }

  @override
  Future<Map<String, dynamic>?> loadMember(String memberId) async {
    memberReads++;
    return members[memberId];
  }

  @override
  Future<PersonalScheduleRecord?> loadSchedule(String scheduleId) async =>
      records[scheduleId];

  @override
  Future<void> createMany(List<PersonalScheduleWrite> writes) async {
    for (final write in writes) {
      final start = write.data['startAt'] as DateTime;
      records[write.scheduleId] = PersonalScheduleRecord(
        scheduleId: write.scheduleId,
        trainerId: write.data['trainerId'] as String,
        workspaceType: write.data['workspaceType'] as String,
        schemaVersion: write.data['schemaVersion'] as int,
        startAt: start,
        endAt: write.data['endAt'] as DateTime,
        dateKey: write.data['dateKey'] as String,
        slotKey: write.data['slotKey'] as String,
        name: write.data['name'] as String,
        type: write.data['type'] as String,
        status: write.data['status'] as String,
        memberId: _nullable(write.data['memberId']),
        phone: _nullable(write.data['phone']),
        remainingSessions: write.data['remainingSessions'] as int?,
        totalSessions: write.data['totalSessions'] as int?,
        memo: write.data['memo'] as String,
        typeColorHex: write.data['typeColorHex'] as String,
      );
    }
  }

  @override
  Future<void> updateSchedule(
    String scheduleId,
    Map<String, dynamic> changes,
  ) async {
    if (failNextUpdate) {
      failNextUpdate = false;
      throw StateError('write failed');
    }
    final current = records[scheduleId]!;
    final draft = PersonalScheduleDraft(
      startAt: changes['startAt'] as DateTime? ?? current.startAt,
      endAt: changes['endAt'] as DateTime? ?? current.endAt,
      name: changes['name'] as String? ?? current.name,
      type: changes['type'] as String? ?? current.type,
      status: changes['status'] as String? ?? current.status,
      memberId: changes.containsKey('memberId')
          ? _nullable(changes['memberId'])
          : current.memberId,
      phone: changes.containsKey('phone')
          ? _nullable(changes['phone'])
          : current.phone,
      remainingSessions:
          changes['remainingSessions'] as int? ?? current.remainingSessions,
      totalSessions: changes['totalSessions'] as int? ?? current.totalSessions,
      memo: changes['memo'] as String? ?? current.memo,
      typeColorHex: changes['typeColorHex'] as String? ?? current.typeColorHex,
    );
    records[scheduleId] = PersonalScheduleRecord(
      scheduleId: current.scheduleId,
      trainerId: current.trainerId,
      workspaceType: current.workspaceType,
      schemaVersion: current.schemaVersion,
      startAt: draft.startAt,
      endAt: draft.endAt,
      dateKey: PersonalScheduleDocumentIdentity.dateKey(draft.startAt),
      slotKey: PersonalScheduleDocumentIdentity.slotKey(draft.startAt),
      name: draft.name,
      type: draft.type,
      status: draft.status,
      memberId: draft.memberId,
      phone: draft.phone,
      remainingSessions: draft.remainingSessions,
      totalSessions: draft.totalSessions,
      memo: draft.memo,
      typeColorHex: draft.typeColorHex,
      lessonConfirmed: current.lessonConfirmed,
    );
  }

  @override
  Future<void> deleteSchedule(String scheduleId) async {
    records.remove(scheduleId);
  }

  String? _nullable(dynamic value) {
    final text = value?.toString() ?? '';
    return text.isEmpty ? null : text;
  }
}

class _FakeWidgetGateway implements PersonalScheduleWidgetGateway {
  String owner = '';
  int clearCalls = 0;
  List<PersonalScheduleRecord> synced = const [];

  @override
  Future<void> clear() async {
    clearCalls++;
    owner = '';
    synced = const [];
  }

  @override
  Future<String> loadOwnerUid() async => owner;

  @override
  Future<void> saveOwnerUid(String uid) async => owner = uid;

  @override
  Future<void> sync(
    String uid,
    List<PersonalScheduleRecord> schedules,
  ) async {
    synced = schedules;
  }
}
