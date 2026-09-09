import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/home_guest_schedule_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('첫 체험 일정을 로컬 저장한다', () async {
    final repository = GuestScheduleRepository(now: _fixedNow);
    final result = await _save(repository, 1);

    expect(result.status, GuestScheduleSaveStatus.saved);
    expect(await repository.load(), hasLength(1));
  });

  test('체험 일정은 5개까지 저장한다', () async {
    final repository = GuestScheduleRepository();
    for (var index = 0; index < 5; index++) {
      expect((await _save(repository, index)).status,
          GuestScheduleSaveStatus.saved);
    }
    expect(await repository.load(), hasLength(5));
  });

  test('6번째 저장은 입력 record를 만들지 않고 차단한다', () async {
    final repository = GuestScheduleRepository();
    for (var index = 0; index < 5; index++) {
      await _save(repository, index);
    }

    final result = await _save(repository, 6);
    expect(result.status, GuestScheduleSaveStatus.limitReached);
    expect(result.record, isNull);
    expect(await repository.load(), hasLength(5));
  });

  test('하나를 삭제하면 다시 등록할 수 있다', () async {
    final repository = GuestScheduleRepository();
    for (var index = 0; index < 5; index++) {
      await _save(repository, index);
    }
    final records = await repository.load();

    expect(await repository.delete(records.first.guestScheduleId), isTrue);
    expect((await _save(repository, 7)).status, GuestScheduleSaveStatus.saved);
    expect(await repository.load(), hasLength(5));
  });

  test('수정은 ID와 생성 시각을 유지하고 개수를 늘리지 않는다', () async {
    var now = DateTime(2026, 7, 15, 9);
    final repository = GuestScheduleRepository(now: () => now);
    final original = (await _save(repository, 1)).record!;
    now = now.add(const Duration(hours: 1));

    final result = await repository.save(
      guestScheduleId: original.guestScheduleId,
      nameOrAlias: '수정 별칭',
      lessonType: '요가',
      startAt: DateTime(2026, 7, 16, 11),
      endAt: DateTime(2026, 7, 16, 12),
      memo: '수정 메모',
      colorHex: '#DB2777',
    );

    expect(result.record!.guestScheduleId, original.guestScheduleId);
    expect(result.record!.createdAtLocal, original.createdAtLocal);
    expect(result.record!.updatedAtLocal, now);
    expect(await repository.load(), hasLength(1));
  });

  test('일정 이동은 같은 ID를 유지한다', () async {
    final repository = GuestScheduleRepository();
    final original = (await _save(repository, 1)).record!;
    final movedStart = original.startAt.add(const Duration(days: 2, hours: 1));

    final moved = await repository.save(
      guestScheduleId: original.guestScheduleId,
      nameOrAlias: original.nameOrAlias,
      lessonType: original.lessonType,
      startAt: movedStart,
      endAt: movedStart.add(const Duration(minutes: 50)),
      memo: original.memo,
      colorHex: original.colorHex,
    );

    expect(moved.record!.guestScheduleId, original.guestScheduleId);
    expect(moved.record!.startAt, movedStart);
  });

  test('새 repository에서도 저장 일정을 다시 불러온다', () async {
    await _save(GuestScheduleRepository(), 1);

    final restored = await GuestScheduleRepository().load();
    expect(restored, hasLength(1));
    expect(restored.single.nameOrAlias, '별칭 1');
  });

  test('저장 JSON에는 개인정보와 실제 owner 식별자가 없다', () async {
    await _save(GuestScheduleRepository(), 1);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(GuestScheduleRepository.storageKey)!;
    final item = (jsonDecode(raw) as List).single as Map<String, dynamic>;

    expect(
        item.keys,
        containsAll([
          'guestScheduleId',
          'nameOrAlias',
          'lessonType',
          'startAt',
          'endAt',
          'memo',
          'colorHex',
          'createdAtLocal',
          'updatedAtLocal',
        ]));
    expect(item.keys, isNot(contains('phone')));
    expect(item.keys, isNot(contains('memberId')));
    expect(item.keys, isNot(contains('trainerId')));
    expect(item.keys, isNot(contains('health')));
    expect(item.keys, isNot(contains('birth')));
  });

  test('빠른 연속 저장도 최대 5개를 넘지 않는다', () async {
    final repository = GuestScheduleRepository();
    final results = await Future.wait([
      for (var index = 0; index < 8; index++) _save(repository, index),
    ]);

    expect(
      results.where((result) => result.status == GuestScheduleSaveStatus.saved),
      hasLength(5),
    );
    expect(await repository.load(), hasLength(5));
  });

  test('삭제한 일정은 새 repository에서 다시 나타나지 않는다', () async {
    final repository = GuestScheduleRepository();
    final record = (await _save(repository, 1)).record!;
    await repository.delete(record.guestScheduleId);

    expect(await GuestScheduleRepository().load(), isEmpty);
  });

  test('손상된 로컬 값은 서버 fallback 없이 빈 목록으로 처리한다', () async {
    SharedPreferences.setMockInitialValues({
      GuestScheduleRepository.storageKey: '{not-json',
    });

    expect(await GuestScheduleRepository().load(), isEmpty);
  });
}

DateTime _fixedNow() => DateTime(2026, 7, 15, 9);

Future<GuestScheduleSaveResult> _save(
  GuestScheduleRepository repository,
  int index,
) {
  final start = DateTime(2026, 7, 15, 9 + index);
  return repository.save(
    nameOrAlias: '별칭 $index',
    lessonType: 'PT',
    startAt: start,
    endAt: start.add(const Duration(minutes: 50)),
    memo: '로컬 메모',
    colorHex: '#4F46E5',
  );
}
