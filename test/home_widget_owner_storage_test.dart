import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/mtf_home_widget_service.dart';

void main() {
  final generatedAt = DateTime(2026, 7, 22, 10, 30);
  final payloadRevision = generatedAt.millisecondsSinceEpoch;
  String payload(int count) => jsonEncode({
        'schemaVersion': 2,
        'payloadRevision': payloadRevision,
        'localDate': '2026-07-22',
        'items': List.filled(count, const <String, Object?>{}),
      });

  test('owner 메타데이터 재읽기 뒤 payload를 저장하고 마지막에 update한다', () async {
    final storage = _FakeWidgetStorage();

    await MtfHomeWidgetService.syncVerifiedPersonalTodayLessonRollup(
      ownerUid: 'uid-a',
      environment: 'dev',
      projectId: 'more-than-fitness-dev-mft',
      workspaceType: 'personal',
      generatedAt: generatedAt,
      encodedItems: payload(0),
      payloadRevision: payloadRevision,
      scheduleSourceCount: 0,
      todayCandidateCount: 0,
      payloadItemCount: 0,
      source: 'appStart',
      storage: storage,
    );

    expect(
      storage.values[MtfHomeWidgetService.keyPersonalOwnerUid],
      'uid-a',
    );
    expect(
      storage.values[MtfHomeWidgetService.keyPersonalEnvironment],
      'dev',
    );
    expect(
      storage.values[MtfHomeWidgetService.keyPersonalProjectId],
      'more-than-fitness-dev-mft',
    );
    expect(
      storage.values[MtfHomeWidgetService.keyPersonalWorkspaceType],
      'personal',
    );
    expect(
      storage.values[MtfHomeWidgetService.keyTodayRollupLocalDate],
      '2026-07-22',
    );
    expect(storage.operations.last, 'update');
    expect(
      storage.operations.indexOf(
        'write:${MtfHomeWidgetService.keyTodayRollupItems}',
      ),
      lessThan(storage.operations.indexOf('update')),
    );
  });

  test('기존 세션 owner가 비어 있어도 appStart에서 self-heal한다', () async {
    final storage = _FakeWidgetStorage();

    await MtfHomeWidgetService.syncVerifiedPersonalTodayLessonRollup(
      ownerUid: 'uid-existing',
      environment: 'dev',
      projectId: 'more-than-fitness-dev-mft',
      workspaceType: 'personal',
      generatedAt: generatedAt,
      encodedItems: payload(1),
      payloadRevision: payloadRevision,
      scheduleSourceCount: 1,
      todayCandidateCount: 1,
      payloadItemCount: 1,
      source: 'appStart',
      storage: storage,
    );

    expect(
      storage.values[MtfHomeWidgetService.keyPersonalOwnerUid],
      'uid-existing',
    );
    expect(storage.updateCount, 1);
  });

  test('UID가 바뀌면 이전 owner 기반 cache를 지운 뒤 새 owner를 저장한다', () async {
    final storage = _FakeWidgetStorage()
      ..values[MtfHomeWidgetService.keyPersonalOwnerUid] = 'uid-old'
      ..values[MtfHomeWidgetService.keyRows0] = 'old-row'
      ..values[MtfHomeWidgetService.keyNextLessonName] = 'old-name'
      ..values[MtfHomeWidgetService.keyTodayRollupItems] = 'old-payload';

    await MtfHomeWidgetService.syncVerifiedPersonalTodayLessonRollup(
      ownerUid: 'uid-new',
      environment: 'dev',
      projectId: 'more-than-fitness-dev-mft',
      workspaceType: 'personal',
      generatedAt: generatedAt,
      encodedItems: payload(1),
      payloadRevision: payloadRevision,
      scheduleSourceCount: 1,
      todayCandidateCount: 1,
      payloadItemCount: 1,
      source: 'uidChange',
      storage: storage,
    );

    expect(storage.values[MtfHomeWidgetService.keyRows0], '');
    expect(storage.values[MtfHomeWidgetService.keyNextLessonName], '');
    expect(
      storage.values[MtfHomeWidgetService.keyPersonalOwnerUid],
      'uid-new',
    );
    expect(
      storage.values[MtfHomeWidgetService.keyTodayRollupItems],
      payload(1),
    );
  });

  test('owner 저장 실패 시 성공 update 없이 빈 payload 안전 갱신을 시도한다', () async {
    final storage = _FakeWidgetStorage(
      failingStringKey: MtfHomeWidgetService.keyPersonalOwnerUid,
    )..values[MtfHomeWidgetService.keyTodayRollupItems] = 'stale-payload';

    await expectLater(
      MtfHomeWidgetService.syncVerifiedPersonalTodayLessonRollup(
        ownerUid: 'uid-a',
        environment: 'dev',
        projectId: 'more-than-fitness-dev-mft',
        workspaceType: 'personal',
        generatedAt: generatedAt,
        encodedItems: payload(1),
        payloadRevision: payloadRevision,
        scheduleSourceCount: 1,
        todayCandidateCount: 1,
        payloadItemCount: 1,
        source: 'resume',
        storage: storage,
      ),
      throwsStateError,
    );

    expect(
      storage.values[MtfHomeWidgetService.keyTodayRollupItems],
      '[]',
    );
    expect(storage.updateCount, 1);
  });

  test('로그아웃 clear는 owner와 모든 일정 payload를 제거한다', () async {
    final storage = _FakeWidgetStorage()
      ..values[MtfHomeWidgetService.keyPersonalOwnerUid] = 'uid-a'
      ..values[MtfHomeWidgetService.keyTodayRollupItems] = 'payload'
      ..values[MtfHomeWidgetService.keyRows0] = 'weekly'
      ..values[MtfHomeWidgetService.keyNextLessonName] = 'next';

    await MtfHomeWidgetService.clearPersonalScheduleData(storage: storage);

    expect(storage.values[MtfHomeWidgetService.keyPersonalOwnerUid], '');
    expect(storage.values[MtfHomeWidgetService.keyTodayRollupItems], '[]');
    expect(storage.values[MtfHomeWidgetService.keyRows0], '');
    expect(storage.values[MtfHomeWidgetService.keyNextLessonName], '');
    expect(storage.updateCount, 1);
  });

  test('Personal 외 workspace와 빈 identity는 저장 전에 차단한다', () async {
    for (final identity in <(String, String)>[
      ('', 'personal'),
      ('uid-a', 'legacy'),
    ]) {
      final storage = _FakeWidgetStorage();
      await expectLater(
        MtfHomeWidgetService.syncVerifiedPersonalTodayLessonRollup(
          ownerUid: identity.$1,
          environment: 'dev',
          projectId: 'more-than-fitness-dev-mft',
          workspaceType: identity.$2,
          generatedAt: generatedAt,
          encodedItems: payload(1),
          payloadRevision: payloadRevision,
          scheduleSourceCount: 1,
          todayCandidateCount: 1,
          payloadItemCount: 1,
          source: 'appStart',
          storage: storage,
        ),
        throwsStateError,
      );
      expect(storage.operations, isEmpty);
    }
  });

  test('DEV와 PROD storage는 별도 sandbox에서 서로 값을 공유하지 않는다', () async {
    final devStorage = _FakeWidgetStorage();
    final prodStorage = _FakeWidgetStorage();

    await MtfHomeWidgetService.syncVerifiedPersonalTodayLessonRollup(
      ownerUid: 'uid-dev',
      environment: 'dev',
      projectId: 'more-than-fitness-dev-mft',
      workspaceType: 'personal',
      generatedAt: generatedAt,
      encodedItems: payload(1),
      payloadRevision: payloadRevision,
      scheduleSourceCount: 1,
      todayCandidateCount: 1,
      payloadItemCount: 1,
      source: 'appStart',
      storage: devStorage,
    );

    expect(prodStorage.values, isEmpty);
    expect(
      devStorage.values[MtfHomeWidgetService.keyPersonalEnvironment],
      'dev',
    );
  });

  test('더 최신 revision이 저장돼 있으면 이전 writer 결과로 덮어쓰지 않는다', () async {
    final storage = _FakeWidgetStorage()
      ..values[MtfHomeWidgetService.keyPersonalOwnerUid] = 'uid-a'
      ..values[MtfHomeWidgetService.keyTodayRollupItems] = jsonEncode({
        'schemaVersion': 2,
        'payloadRevision': payloadRevision + 1,
        'localDate': '2026-07-22',
        'items': const <Object?>[],
      });
    final newerPayload =
        storage.values[MtfHomeWidgetService.keyTodayRollupItems];

    await MtfHomeWidgetService.syncVerifiedPersonalTodayLessonRollup(
      ownerUid: 'uid-a',
      environment: 'dev',
      projectId: 'more-than-fitness-dev-mft',
      workspaceType: 'personal',
      generatedAt: generatedAt,
      encodedItems: payload(1),
      payloadRevision: payloadRevision,
      scheduleSourceCount: 1,
      todayCandidateCount: 1,
      payloadItemCount: 1,
      source: 'lateCallback',
      storage: storage,
    );

    expect(
      storage.values[MtfHomeWidgetService.keyTodayRollupItems],
      newerPayload,
    );
    expect(storage.updateCount, 0);
  });
}

class _FakeWidgetStorage implements MtfHomeWidgetStorage {
  _FakeWidgetStorage({this.failingStringKey});

  final String? failingStringKey;
  final Map<String, Object> values = <String, Object>{};
  final List<String> operations = <String>[];
  int updateCount = 0;

  @override
  Future<int> readInt(String key) async {
    operations.add('read:$key');
    return values[key] as int? ?? 0;
  }

  @override
  Future<String> readString(String key) async {
    operations.add('read:$key');
    return values[key] as String? ?? '';
  }

  @override
  Future<void> updateTodayLessonRollup() async {
    operations.add('update');
    updateCount++;
  }

  @override
  Future<void> writeInt(String key, int value) async {
    operations.add('write:$key');
    values[key] = value;
  }

  @override
  Future<void> writeString(String key, String value) async {
    operations.add('write:$key');
    if (key == failingStringKey) {
      throw StateError('write_failed');
    }
    values[key] = value;
  }
}
