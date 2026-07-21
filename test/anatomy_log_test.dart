import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/models/anatomy_log.dart';
import 'package:mtf_app/services/anatomy_log_service.dart';

void main() {
  final recordedAt = DateTime(2026, 7, 15, 14);
  final createdAt = DateTime(2026, 7, 15, 15);

  AnatomyLogRecord record({
    String id = 'anatomy-1',
    BodyGender gender = BodyGender.female,
    BodyView view = BodyView.back,
    BodySide side = BodySide.left,
    AnatomyRecordType type = AnatomyRecordType.exercise,
    String partId = 'hamstring',
    String partLabel = '햄스트링',
    String exerciseName = '레그 컬',
    int painLevel = 0,
  }) {
    return AnatomyLogRecord(
      anatomyLogId: id,
      trainerId: 'trainer-1',
      memberId: 'member-1',
      lessonLogId: 'lesson-1',
      scheduleDocId: 'schedule-1',
      recordedAt: recordedAt,
      bodyGender: gender,
      bodyView: view,
      bodySide: side,
      bodyPartId: partId,
      bodyPartLabel: partLabel,
      recordType: type,
      exerciseName: exerciseName,
      painLevel: painLevel,
      memo: '무릎 정렬 확인',
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  test('직렬화와 역직렬화가 전체 연결 필드를 보존한다', () {
    final original = record();
    final decoded = AnatomyLogRecord.fromFirestore(original.toFirestore());

    expect(decoded.anatomyLogId, 'anatomy-1');
    expect(decoded.trainerId, 'trainer-1');
    expect(decoded.memberId, 'member-1');
    expect(decoded.lessonLogId, 'lesson-1');
    expect(decoded.scheduleDocId, 'schedule-1');
    expect(decoded.recordedAt, recordedAt);
    expect(decoded.bodyPartId, 'hamstring');
  });

  test('남성·여성, 앞면·뒷면, 좌·우·중앙·양측 값을 보존한다', () {
    for (final gender in BodyGender.values) {
      for (final view in BodyView.values) {
        for (final side in BodySide.values) {
          final decoded = AnatomyLogRecord.fromFirestore(
            record(gender: gender, view: view, side: side).toFirestore(),
          );
          expect(decoded.bodyGender, gender);
          expect(decoded.bodyView, view);
          expect(decoded.bodySide, side);
        }
      }
    }
  });

  test('운동 기록을 저장하고 불러온다', () {
    final decoded = AnatomyLogRecord.fromFirestore(record().toFirestore());
    expect(decoded.recordType, AnatomyRecordType.exercise);
    expect(decoded.exerciseName, '레그 컬');
  });

  test('통증 기록과 0~10 painLevel을 저장한다', () {
    final pain = record(
      type: AnatomyRecordType.pain,
      exerciseName: '',
      painLevel: 7,
    );
    final decoded = AnatomyLogRecord.fromFirestore(pain.toFirestore());
    expect(decoded.recordType, AnatomyRecordType.pain);
    expect(decoded.painLevel, 7);
    expect(record(painLevel: 99).copyWith().painLevel, 10);
  });

  test('같은 기록 수정 시 ID를 유지하고 중복을 만들지 않는다', () {
    final original = record();
    final updated =
        original.copyWith(memo: '수정 메모', updatedAt: DateTime(2026, 7, 16));
    final records = AnatomyRecordCollection.upsert([original], updated);

    expect(records, hasLength(1));
    expect(records.single.anatomyLogId, original.anatomyLogId);
    expect(records.single.memo, '수정 메모');
  });

  test('여러 부위 기록을 직렬화 후 모두 보존한다', () {
    final records = [
      record(),
      record(
        id: 'anatomy-2',
        view: BodyView.front,
        side: BodySide.right,
        partId: 'chest',
        partLabel: '가슴',
        exerciseName: '벤치프레스',
      ),
    ];

    final decoded = AnatomyRecordCollection.decode(
      AnatomyRecordCollection.encode(records),
    );
    expect(decoded.map((e) => e.anatomyLogId), ['anatomy-1', 'anatomy-2']);
  });

  test('삭제한 기록은 목록에서 제거된다', () {
    final records = [record(), record(id: 'anatomy-2')];
    final next = AnatomyRecordCollection.remove(records, 'anatomy-1');
    expect(next.map((e) => e.anatomyLogId), ['anatomy-2']);
  });

  test('목록은 recordedAt 내림차순 후 createdAt 내림차순으로 정렬한다', () {
    final olderLesson = record(id: 'older').copyWith(
      recordedAt: DateTime(2026, 7, 14),
      createdAt: DateTime(2026, 7, 15, 20),
    );
    final earlierCreated = record(id: 'earlier-created').copyWith(
      createdAt: DateTime(2026, 7, 15, 14),
    );
    final laterCreated = record(id: 'later-created').copyWith(
      createdAt: DateTime(2026, 7, 15, 16),
    );

    final sorted = AnatomyRecordCollection.sorted(
      [olderLesson, earlierCreated, laterCreated],
    );
    expect(
      sorted.map((e) => e.anatomyLogId),
      ['later-created', 'earlier-created', 'older'],
    );
  });

  test('필수 연결 ID가 하나라도 없으면 저장 context를 거부한다', () {
    const valid = AnatomyLogSaveContext(
      lessonLogId: 'lesson-1',
      trainerId: 'trainer-1',
      memberId: 'member-1',
      scheduleDocId: 'schedule-1',
    );
    const scheduleOptional = AnatomyLogSaveContext(
      lessonLogId: 'lesson-1',
      trainerId: 'trainer-1',
      memberId: 'member-1',
      scheduleDocId: '',
    );

    expect(valid.isValid, isTrue);
    expect(scheduleOptional.isValid, isTrue);
    expect(scheduleOptional.missingFields, isEmpty);
  });

  test('필드가 없는 과거 문서는 안전한 기본값으로 읽는다', () {
    final legacy = AnatomyLogRecord.fromFirestore(<String, dynamic>{
      'id': 'legacy-1',
      'recordedAt': Timestamp.fromDate(recordedAt),
    });

    expect(legacy.anatomyLogId, 'legacy-1');
    expect(legacy.bodyGender, BodyGender.unspecified);
    expect(legacy.bodyView, BodyView.front);
    expect(legacy.bodySide, BodySide.both);
    expect(legacy.recordType, AnatomyRecordType.exercise);
    expect(legacy.painLevel, 0);
  });

  group('AnatomyLogService 무결성', () {
    late _FakeAnatomyLogStore store;
    late AnatomyLogService service;

    setUp(() {
      store = _FakeAnatomyLogStore();
      service = AnatomyLogService(
        store: store,
        currentUid: () => 'trainer-1',
      );
    });

    test('상위 training_log가 없으면 저장을 중단하고 부모를 만들지 않는다', () async {
      await expectLater(
        service.save(
          lessonLogId: 'lesson-1',
          trainerId: 'trainer-1',
          memberId: 'member-1',
          records: [record()],
          deletedRecordIds: const {},
        ),
        _failsWith(AnatomyLogErrorCode.parentNotFound),
      );

      expect(store.parents, isEmpty);
      expect(store.createdRecordCount, 0);
      expect(store.updatedParentCount, 0);
    });

    test('로그인 uid와 trainerId가 다르면 저장을 거부한다', () async {
      store.seedParent();
      service = AnatomyLogService(
        store: store,
        currentUid: () => 'another-trainer',
      );

      await expectLater(
        service.save(
          lessonLogId: 'lesson-1',
          trainerId: 'trainer-1',
          memberId: 'member-1',
          records: [record()],
          deletedRecordIds: const {},
        ),
        _failsWith(AnatomyLogErrorCode.trainerMismatch),
      );
    });

    test('로그인 사용자가 없으면 unauthenticated로 저장을 거부한다', () async {
      store.seedParent();
      service = AnatomyLogService(store: store, currentUid: () => null);

      await expectLater(
        service.save(
          lessonLogId: 'lesson-1',
          trainerId: 'trainer-1',
          memberId: 'member-1',
          records: [record()],
          deletedRecordIds: const {},
        ),
        _failsWith(AnatomyLogErrorCode.unauthenticated),
      );
    });

    test('부모 memberId가 다르면 저장을 거부한다', () async {
      store.seedParent(memberId: 'another-member');

      await expectLater(
        service.save(
          lessonLogId: 'lesson-1',
          trainerId: 'trainer-1',
          memberId: 'member-1',
          records: [record()],
          deletedRecordIds: const {},
        ),
        _failsWith(AnatomyLogErrorCode.memberMismatch),
      );
    });

    test('경로 lessonLogId와 문서 필드가 다르면 저장을 거부한다', () async {
      store.seedParent();

      await expectLater(
        service.save(
          lessonLogId: 'lesson-1',
          trainerId: 'trainer-1',
          memberId: 'member-1',
          records: [record().copyWith(lessonLogId: 'lesson-2')],
          deletedRecordIds: const {},
        ),
        _failsWith(AnatomyLogErrorCode.pathLessonLogMismatch),
      );
    });

    test('scheduleDocId가 없어도 부모 identity가 유효하면 저장한다', () async {
      store.seedParent(scheduleDocId: '');

      await service.save(
        lessonLogId: 'lesson-1',
        trainerId: 'trainer-1',
        memberId: 'member-1',
        scheduleDocId: '',
        records: [record().copyWith(scheduleDocId: '')],
        deletedRecordIds: const {},
      );

      expect(store.records['lesson-1']!.keys, ['anatomy-1']);
    });

    test('부모와 자식 scheduleDocId가 모두 있고 다르면 저장을 거부한다', () async {
      store.seedParent(scheduleDocId: 'schedule-parent');

      await expectLater(
        service.save(
          lessonLogId: 'lesson-1',
          trainerId: 'trainer-1',
          memberId: 'member-1',
          records: [record().copyWith(scheduleDocId: 'schedule-child')],
          deletedRecordIds: const {},
        ),
        _failsWith(AnatomyLogErrorCode.scheduleMismatch),
      );
    });

    test('같은 anatomyLogId 수정은 문서 ID를 유지하고 내용만 갱신한다', () async {
      store.seedParent();
      store.seedRecord(record());
      final loaded = await service.load(
        lessonLogId: 'lesson-1',
        trainerId: 'trainer-1',
        memberId: 'member-1',
        scheduleDocId: 'schedule-1',
      );

      await service.save(
        lessonLogId: 'lesson-1',
        trainerId: 'trainer-1',
        memberId: 'member-1',
        scheduleDocId: 'schedule-1',
        records: [loaded.single.copyWith(memo: '변경된 메모')],
        deletedRecordIds: const {},
      );

      expect(store.records['lesson-1']!.keys, ['anatomy-1']);
      expect(store.records['lesson-1']!['anatomy-1']!['memo'], '변경된 메모');
    });

    for (final change in <String, AnatomyLogRecord Function(AnatomyLogRecord)>{
      'trainerId': (value) => value.copyWith(trainerId: 'another-trainer'),
      'memberId': (value) => value.copyWith(memberId: 'another-member'),
      'lessonLogId': (value) => value.copyWith(lessonLogId: 'lesson-2'),
      'createdAt': (value) => value.copyWith(
            createdAt: value.createdAt.add(const Duration(seconds: 1)),
          ),
    }.entries) {
      test('수정 시 ${change.key} 변경을 차단한다', () async {
        store.seedParent();
        store.seedRecord(record());

        await expectLater(
          service.save(
            lessonLogId: 'lesson-1',
            trainerId: 'trainer-1',
            memberId: 'member-1',
            scheduleDocId: 'schedule-1',
            records: [change.value(record())],
            deletedRecordIds: const {},
          ),
          _failsWith(AnatomyLogErrorCode.immutableIdentityChange),
        );
      });
    }

    test('기록 하나를 삭제해도 같은 레슨의 다른 기록은 유지한다', () async {
      store.seedParent();
      store.seedRecord(record());
      store.seedRecord(record(id: 'anatomy-2'));

      await service.save(
        lessonLogId: 'lesson-1',
        trainerId: 'trainer-1',
        memberId: 'member-1',
        scheduleDocId: 'schedule-1',
        records: [record(id: 'anatomy-2')],
        deletedRecordIds: const {'anatomy-1'},
      );

      expect(store.records['lesson-1']!.keys, ['anatomy-2']);
    });

    test('존재하지 않는 기록 삭제를 성공으로 처리하지 않는다', () async {
      store.seedParent();

      await expectLater(
        service.save(
          lessonLogId: 'lesson-1',
          trainerId: 'trainer-1',
          memberId: 'member-1',
          records: const [],
          deletedRecordIds: const {'missing-record'},
        ),
        _failsWith(AnatomyLogErrorCode.recordNotFound),
      );
    });

    test('identity가 없는 legacy 부모는 명확한 오류로 차단한다', () async {
      store.parents['lesson-1'] = <String, dynamic>{'title': '과거 기록'};

      await expectLater(
        service.save(
          lessonLogId: 'lesson-1',
          trainerId: 'trainer-1',
          memberId: 'member-1',
          records: [record()],
          deletedRecordIds: const {},
        ),
        _failsWith(AnatomyLogErrorCode.legacyParentMissingIdentity),
      );
    });

    test('조회 결과 정렬 규칙을 유지한다', () async {
      store.seedParent();
      store.seedRecord(
        record(id: 'b').copyWith(createdAt: DateTime(2026, 7, 15, 16)),
      );
      store.seedRecord(
        record(id: 'a').copyWith(createdAt: DateTime(2026, 7, 15, 16)),
      );
      store.seedRecord(
        record(id: 'older').copyWith(recordedAt: DateTime(2026, 7, 14)),
      );

      final loaded = await service.load(
        lessonLogId: 'lesson-1',
        trainerId: 'trainer-1',
        memberId: 'member-1',
        scheduleDocId: 'schedule-1',
      );

      expect(loaded.map((value) => value.anatomyLogId), ['a', 'b', 'older']);
    });
  });
}

Matcher _failsWith(AnatomyLogErrorCode code) => throwsA(
      isA<AnatomyLogException>().having(
        (error) => error.code,
        'code',
        code,
      ),
    );

class _FakeAnatomyLogStore implements AnatomyLogStore, AnatomyLogTransaction {
  final Map<String, Map<String, dynamic>> parents = {};
  final Map<String, Map<String, Map<String, dynamic>>> records = {};
  int createdRecordCount = 0;
  int updatedParentCount = 0;
  int _nextId = 1;

  void seedParent({
    String trainerId = 'trainer-1',
    String memberId = 'member-1',
    String scheduleDocId = 'schedule-1',
  }) {
    parents['lesson-1'] = <String, dynamic>{
      'trainerId': trainerId,
      'memberId': memberId,
      'scheduleDocId': scheduleDocId,
    };
  }

  void seedRecord(AnatomyLogRecord record) {
    records.putIfAbsent(record.lessonLogId, () => {})[record.anatomyLogId] =
        record.toFirestore();
  }

  @override
  String newRecordId(String lessonLogId) => 'generated-${_nextId++}';

  @override
  Future<Map<String, dynamic>?> getParent(String lessonLogId) async =>
      parents[lessonLogId] == null
          ? null
          : Map<String, dynamic>.from(parents[lessonLogId]!);

  @override
  Future<List<AnatomyLogDocument>> getRecords(String lessonLogId) async =>
      (records[lessonLogId] ?? const {})
          .entries
          .map(
            (entry) => AnatomyLogDocument(
              id: entry.key,
              data: Map<String, dynamic>.from(entry.value),
            ),
          )
          .toList();

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(AnatomyLogTransaction transaction) action,
  ) =>
      action(this);

  @override
  Future<Map<String, dynamic>?> getRecord(
    String lessonLogId,
    String anatomyLogId,
  ) async {
    final data = records[lessonLogId]?[anatomyLogId];
    return data == null ? null : Map<String, dynamic>.from(data);
  }

  @override
  void updateParent(String lessonLogId, Map<String, dynamic> data) {
    final parent = parents[lessonLogId];
    if (parent == null) throw StateError('parent_not_found');
    updatedParentCount++;
    parent.addAll(data);
  }

  @override
  void createRecord(
    String lessonLogId,
    String anatomyLogId,
    Map<String, dynamic> data,
  ) {
    createdRecordCount++;
    records.putIfAbsent(lessonLogId, () => {})[anatomyLogId] =
        _withResolvedServerTimes(data);
  }

  @override
  void updateRecord(
    String lessonLogId,
    String anatomyLogId,
    Map<String, dynamic> data,
  ) {
    records[lessonLogId]![anatomyLogId]!.addAll(
      _withResolvedServerTimes(data),
    );
  }

  @override
  void deleteRecord(String lessonLogId, String anatomyLogId) {
    records[lessonLogId]?.remove(anatomyLogId);
  }

  Map<String, dynamic> _withResolvedServerTimes(Map<String, dynamic> data) {
    final result = Map<String, dynamic>.from(data);
    final timestamp = Timestamp.fromDate(DateTime(2026, 7, 15, 15));
    if (result['createdAt'] is FieldValue) result['createdAt'] = timestamp;
    if (result['updatedAt'] is FieldValue) result['updatedAt'] = timestamp;
    return result;
  }
}
