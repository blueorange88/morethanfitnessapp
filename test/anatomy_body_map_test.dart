import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/anatomy_page.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/models/anatomy_log.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/models/anatomy_location_chips.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/models/anatomy_marks.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/models/body_mask.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/models/body_map_data.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/models/body_part.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/models/exercise_muscles.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/widgets/body_map_canvas.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/anatomy_history_page.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/anatomy_trend_page.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/models/anatomy_trend.dart';
import 'package:mtf_app/pages/personal_training_log_anatomy/widgets/trend_chart.dart';
import 'package:mtf_app/services/anatomy_exercise_store.dart';
import 'package:mtf_app/services/anatomy_history_service.dart';
import 'package:mtf_app/services/anatomy_log_service.dart';

class _FakeAnatomyService implements AnatomyLogService {
  List<AnatomyLogRecord> saved = const <AnatomyLogRecord>[];
  int _seq = 0;

  @override
  Future<List<AnatomyLogRecord>> load({
    required String lessonLogId,
    required String trainerId,
    required String memberId,
    String scheduleDocId = '',
  }) async => const <AnatomyLogRecord>[];

  @override
  String newRecordId(String lessonLogId) => 'rec-${_seq++}';

  @override
  Future<List<AnatomyLogRecord>> save({
    required String lessonLogId,
    required String trainerId,
    required String memberId,
    String scheduleDocId = '',
    required List<AnatomyLogRecord> records,
    required Set<String> deletedRecordIds,
  }) async {
    saved = records;
    return records;
  }
}

BodyMapData _loadData() =>
    BodyMapData.parse(File('assets/anatomy/body_map.json').readAsStringSync());

/// [part]/[side] 조각 안에서, 겹침 우선순위까지 따져도 그 조각이 눌리는 점 중
/// 경계에서 가장 먼(가장 안쪽) 점.
Offset _interiorPoint(BodyMapScene scene, String part, BodySide side) {
  final zone = scene.zones.firstWhere((z) => z.part == part && z.side == side);
  Offset? best;
  var bestDistance = -1.0;
  for (var y = zone.bounds.top; y <= zone.bounds.bottom; y += 1) {
    for (var x = zone.bounds.left; x <= zone.bounds.right; x += 1) {
      final p = Offset(x, y);
      if (!identical(scene.hitTest(p, tolerance: 0), zone)) continue;
      final d = zone.distanceTo(p);
      if (d > bestDistance) {
        bestDistance = d;
        best = p;
      }
    }
  }
  if (best == null) throw StateError('눌릴 수 있는 점이 없음: $part $side');
  return best;
}

/// [part]/[side] 구역 안에서 [from] 과 가장 멀리 떨어진, 그 구역이 눌리는 점.
Offset _farInteriorPoint(
  BodyMapScene scene,
  String part,
  BodySide side,
  Offset from,
) {
  final zone = scene.zones.firstWhere((z) => z.part == part && z.side == side);
  Offset? best;
  var bestDistance = -1.0;
  for (var y = zone.bounds.top; y <= zone.bounds.bottom; y += 2) {
    for (var x = zone.bounds.left; x <= zone.bounds.right; x += 2) {
      final point = Offset(x, y);
      if (!identical(scene.hitTest(point, tolerance: 0), zone)) continue;
      if (zone.distanceTo(point) < 6) continue;
      final d = (point - from).distance;
      if (d > bestDistance) {
        bestDistance = d;
        best = point;
      }
    }
  }
  return best!;
}

Future<void> _tapMapPoint(
  WidgetTester tester,
  BodyMapData data,
  Offset viewBoxPoint,
) async {
  final rect = tester.getRect(find.byKey(const ValueKey('body_map_canvas')));
  await tester.tapAt(
    rect.topLeft +
        Offset(
          viewBoxPoint.dx * rect.width / data.viewBox.width,
          viewBoxPoint.dy * rect.height / data.viewBox.height,
        ),
  );
  await tester.pump();
}

AnatomyLogRecord _histRecord({
  required String lesson,
  required DateTime date,
  String exercise = '스쿼트',
  List<AnatomySet> sets = const [],
  String part = 'quad',
  String partLabel = '대퇴사두',
  List<String> related = const [],
  AnatomyRecordType type = AnatomyRecordType.exercise,
  BodySide side = BodySide.both,
  int painLevel = 0,
  String memo = '',
  MobilityResult? mobility,
}) {
  return AnatomyLogRecord(
    anatomyLogId: '$lesson-$exercise-${type.name}-${side.name}',
    trainerId: 'trainer-1',
    memberId: 'member-1',
    lessonLogId: lesson,
    scheduleDocId: '',
    recordedAt: date,
    bodyGender: BodyGender.male,
    bodyView: BodyView.front,
    bodySide: side,
    bodyPartId: part,
    bodyPartLabel: partLabel,
    recordType: type,
    exerciseName: exercise,
    painLevel: painLevel,
    memo: memo,
    sets: sets,
    relatedPartIds: related,
    mobilityResult: mobility,
    createdAt: date,
    updatedAt: date,
  );
}

class _ThrowingHistoryStore implements AnatomyHistoryStore {
  @override
  Future<List<AnatomyLogRecord>> loadMemberRecords({
    required String trainerId,
    required String memberId,
    int limit = 400,
  }) async => throw StateError('offline');
}

class _FakeHistoryStore implements AnatomyHistoryStore {
  _FakeHistoryStore(this.records);

  final List<AnatomyLogRecord> records;
  int calls = 0;

  @override
  Future<List<AnatomyLogRecord>> loadMemberRecords({
    required String trainerId,
    required String memberId,
    int limit = 400,
  }) async {
    calls++;
    return records;
  }
}

/// 부위 선택 격자는 필요한 만큼만 만들어지므로, 보이게 스크롤한 뒤 누른다.
Future<void> pickPart(WidgetTester tester, String id) async {
  final target = find.byKey(ValueKey('record_pick_$id'));
  await tester.scrollUntilVisible(
    target,
    60,
    scrollable: find.descendant(
      of: find.byKey(const ValueKey('record_part_picker')),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  group('BodyMapData', () {
    final data = _loadData();

    test('남녀 앞·뒷면 네 장면이 있고 이미지 파일이 있다', () {
      expect(data.scenes.keys.toSet(), {
        'male_front',
        'male_back',
        'female_front',
        'female_back',
      });
      for (final scene in data.scenes.values) {
        expect(File(scene.image).existsSync(), isTrue, reason: scene.image);
      }
    });

    test('모든 조각이 앱 부위 id 이고 그 면에서 보이는 부위다', () {
      final parts = {for (final p in kBodyParts) p.id: p};
      for (final entry in data.scenes.entries) {
        for (final zone in entry.value.zones) {
          final part = parts[zone.part];
          expect(part, isNotNull, reason: '${entry.key} ${zone.part}');
          expect(part!.legacy, isFalse, reason: zone.part);
          expect(
            part.visibleIn(entry.value.view),
            isTrue,
            reason: '${entry.key} ${zone.part}',
          );
        }
      }
    });

    test('보이는 부위마다 남녀 모두 조각이 있다', () {
      // 여자 뒷면 어깨는 조각이 하나뿐이라 후면삼각근만 있다(측면삼각근 없음).
      const exempt = {
        'female_back': {'delt_side'},
      };
      for (final gender in [BodyGender.male, BodyGender.female]) {
        for (final view in BodyView.values) {
          final key = '${gender.name}_${view.name}';
          final scene = data.sceneFor(gender, view);
          final present = scene.zones.map((z) => z.part).toSet();
          for (final part in kBodyParts.where(
            (p) =>
                !p.legacy &&
                p.visibleIn(view) &&
                !(exempt[key]?.contains(p.id) ?? false),
          )) {
            expect(present, contains(part.id), reason: '$key ${part.id}');
          }
        }
      }
    });

    test('좌우 구분 부위는 양쪽 조각이 모두 있고 복근만 center 다', () {
      for (final scene in data.scenes.values) {
        final sidesByPart = <String, Set<BodySide>>{};
        for (final zone in scene.zones) {
          sidesByPart.putIfAbsent(zone.part, () => <BodySide>{}).add(zone.side);
        }
        for (final entry in sidesByPart.entries) {
          if (entry.key == 'abs') {
            expect(entry.value, {BodySide.center});
          } else {
            expect(entry.value, {BodySide.left, BodySide.right});
          }
        }
      }
    });

    test('앞면은 화면 왼쪽이 사람의 오른쪽, 뒷면은 왼쪽이다', () {
      final front = data.sceneFor(BodyGender.male, BodyView.front);
      final back = data.sceneFor(BodyGender.male, BodyView.back);
      final frontRight = front.zones.firstWhere(
        (z) => z.part == 'delt_side' && z.side == BodySide.right,
      );
      final backLeft = back.zones.firstWhere(
        (z) => z.part == 'delt_side' && z.side == BodySide.left,
      );
      expect(frontRight.bounds.center.dx, lessThan(297));
      expect(backLeft.bounds.center.dx, lessThan(297));
    });

    test('터치: 가운데 가슴은 chest, 승모근이 윗등보다 위', () {
      final front = data.sceneFor(BodyGender.male, BodyView.front);
      expect(front.hitTest(const Offset(296, 200))?.part, 'chest');
      final back = data.sceneFor(BodyGender.male, BodyView.back);
      expect(back.hitTest(const Offset(295, 140))?.part, 'trapezius');
      final wing = _interiorPoint(back, 'upper_back', BodySide.left);
      expect(back.hitTest(wing, tolerance: 0)?.part, 'upper_back');
    });

    test('터치: 조각 사이 작은 틈은 가장 가까운 조각으로, 멀면 null', () {
      BodyMapZone square(String part, double left) => BodyMapZone(
        part: part,
        side: BodySide.center,
        points: [
          Offset(left, 0),
          Offset(left + 10, 0),
          Offset(left + 10, 10),
          Offset(left, 10),
        ],
      );
      final scene = BodyMapScene(
        view: BodyView.front,
        image: 'x',
        zones: [square('a', 0), square('b', 14)],
      );
      // 두 조각 사이 4 간격의 틈
      expect(scene.hitTest(const Offset(11, 5), tolerance: 0), isNull);
      expect(scene.hitTest(const Offset(11, 5))?.part, 'a');
      expect(scene.hitTest(const Offset(13, 5))?.part, 'b');
      expect(scene.hitTest(const Offset(12, 40)), isNull);
    });

    test('isCoveredBy: 양쪽·한쪽·가운데 조각', () {
      final left = BodyMapZone(
        part: 'x',
        side: BodySide.left,
        points: const [Offset(0, 0), Offset(1, 0), Offset(1, 1)],
      );
      final center = BodyMapZone(
        part: 'abs',
        side: BodySide.center,
        points: const [Offset(0, 0), Offset(1, 0), Offset(1, 1)],
      );
      expect(left.isCoveredBy(null), isFalse);
      expect(left.isCoveredBy(BodySide.both), isTrue);
      expect(left.isCoveredBy(BodySide.left), isTrue);
      expect(left.isCoveredBy(BodySide.right), isFalse);
      expect(center.isCoveredBy(BodySide.center), isTrue);
      expect(center.isCoveredBy(BodySide.right), isTrue);
    });

    test('회원 성별 값을 바디 기준으로 바꾼다', () {
      expect(bodyGenderFromMemberValue('male'), BodyGender.male);
      expect(bodyGenderFromMemberValue(' Female '), BodyGender.female);
      expect(bodyGenderFromMemberValue('여성'), BodyGender.female);
      expect(bodyGenderFromMemberValue('남'), BodyGender.male);
      expect(bodyGenderFromMemberValue(''), BodyGender.unspecified);
      expect(bodyGenderFromMemberValue(null), BodyGender.unspecified);
      expect(bodyGenderFromMemberValue('other'), BodyGender.unspecified);
    });

    test('nextSingleSide: 한쪽씩 모드 전이', () {
      BodySide? next(BodySide? c, BodySide t) =>
          BodyMapData.nextSingleSide(c, t);
      expect(next(null, BodySide.left), BodySide.left);
      expect(next(BodySide.left, BodySide.left), isNull);
      expect(next(BodySide.left, BodySide.right), BodySide.both);
      expect(next(BodySide.both, BodySide.left), BodySide.right);
      expect(next(BodySide.both, BodySide.right), BodySide.left);
      expect(next(BodySide.center, BodySide.center), BodySide.center);
    });
  });

  group('AnatomySet', () {
    test('요약: 같은 무게·맨몸·섞인 무게', () {
      expect(
        anatomySetsSummary(const [
          AnatomySet(weightKg: 8, reps: 12),
          AnatomySet(weightKg: 8, reps: 12),
          AnatomySet(weightKg: 8, reps: 12),
        ]),
        '3 X 8kg | 36회',
      );
      expect(
        anatomySetsSummary(const [
          AnatomySet(weightKg: 0, reps: 15),
          AnatomySet(weightKg: 0, reps: 10),
        ]),
        '2세트 | 25회',
      );
      expect(
        anatomySetsSummary(const [
          AnatomySet(weightKg: 8, reps: 12),
          AnatomySet(weightKg: 10.5, reps: 10),
        ]),
        '2세트 | 최대 10.5kg | 22회',
      );
      expect(anatomySetsSummary(const []), '');
    });

    test('볼륨과 추정 1RM', () {
      const set = AnatomySet(weightKg: 60, reps: 10);
      expect(set.volumeKg, 600);
      expect(set.estimatedOneRepMaxKg, closeTo(80, 0.001));
      expect(
        const AnatomySet(weightKg: 0, reps: 10).estimatedOneRepMaxKg,
        isNull,
      );
      expect(
        const AnatomySet(weightKg: 60, reps: 20).estimatedOneRepMaxKg,
        isNull,
      );
    });

    test('범위를 벗어난 값은 읽지 않는다', () {
      expect(AnatomySet.fromMap({'w': 8, 'r': 12}), isNotNull);
      expect(AnatomySet.fromMap({'w': -1, 'r': 12}), isNull);
      expect(AnatomySet.fromMap({'w': 1001, 'r': 12}), isNull);
      expect(AnatomySet.fromMap({'w': 8, 'r': 1000}), isNull);
      expect(AnatomySet.fromMap({'w': '8', 'r': 12}), isNull);
      expect(AnatomySet.fromMap('x'), isNull);
    });

    test('기록에 세트가 저장·복원되고 없으면 필드를 쓰지 않는다', () {
      final base = AnatomyLogRecord(
        anatomyLogId: 'a',
        trainerId: 't',
        memberId: 'm',
        lessonLogId: 'l',
        scheduleDocId: '',
        recordedAt: DateTime(2026, 10, 12),
        bodyGender: BodyGender.male,
        bodyView: BodyView.front,
        bodySide: BodySide.right,
        bodyPartId: 'delt_side',
        bodyPartLabel: '측면삼각근',
        recordType: AnatomyRecordType.exercise,
        exerciseName: '사이드 레터럴 레이즈',
        painLevel: 0,
        memo: '',
        createdAt: DateTime(2026, 10, 12),
        updatedAt: DateTime(2026, 10, 12),
      );
      expect(base.toFirestore().containsKey('sets'), isFalse);
      final withSets = base.copyWith(
        sets: const [
          AnatomySet(weightKg: 8, reps: 12),
          AnatomySet(weightKg: 8.5, reps: 10),
        ],
      );
      final map = withSets.toFirestore();
      expect(map['sets'], [
        {'w': 8.0, 'r': 12},
        {'w': 8.5, 'r': 10},
      ]);
      expect(AnatomyLogRecord.fromFirestore(map).sets, withSets.sets);
      // 옛 기록(sets 없음)도 읽힌다.
      expect(AnatomyLogRecord.fromFirestore(base.toFirestore()).sets, isEmpty);
    });
  });

  group('운동별 사용 부위', () {
    test('모든 부위 id 는 실제 부위이고 중복이 없다', () {
      final ids = {for (final p in kBodyParts.where((p) => !p.legacy)) p.id};
      for (final entry in kExerciseMuscles.entries) {
        expect(entry.value, isNotEmpty, reason: entry.key);
        expect(
          entry.value.toSet().length,
          entry.value.length,
          reason: entry.key,
        );
        for (final id in entry.value) {
          expect(ids, contains(id), reason: '${entry.key} $id');
        }
      }
    });

    test('추천 운동은 모두 사용 부위가 정해져 있다', () {
      for (final part in kBodyParts.where((p) => !p.legacy)) {
        for (final name in part.recommendedExercises) {
          expect(kExerciseMuscles, contains(name), reason: '${part.id} $name');
        }
      }
    });

    test('보조 부위 제안은 목표 부위를 뺀다', () {
      expect(relatedPartsFor('스쿼트', 'glute'), [
        'quad',
        'hamstring',
        'adductor',
      ]);
      expect(relatedPartsFor('스쿼트', 'quad'), [
        'glute',
        'hamstring',
        'adductor',
      ]);
      expect(relatedPartsFor('스쿼트', 'iliopsoas'), [
        'quad',
        'glute',
        'hamstring',
        'adductor',
      ]);
      expect(relatedPartsFor('내가 만든 운동', 'quad'), isEmpty);
    });

    test('기록에 보조 부위가 저장·복원되고 없으면 필드를 쓰지 않는다', () {
      final base = AnatomyLogRecord(
        anatomyLogId: 'a',
        trainerId: 't',
        memberId: 'm',
        lessonLogId: 'l',
        scheduleDocId: '',
        recordedAt: DateTime(2026, 10, 12),
        bodyGender: BodyGender.male,
        bodyView: BodyView.front,
        bodySide: BodySide.both,
        bodyPartId: 'glute',
        bodyPartLabel: '둔근',
        recordType: AnatomyRecordType.exercise,
        exerciseName: '스쿼트',
        painLevel: 0,
        memo: '',
        createdAt: DateTime(2026, 10, 12),
        updatedAt: DateTime(2026, 10, 12),
      );
      expect(base.toFirestore().containsKey('relatedPartIds'), isFalse);
      final withRelated = base.copyWith(relatedPartIds: ['quad', 'adductor']);
      final map = withRelated.toFirestore();
      expect(map['relatedPartIds'], ['quad', 'adductor']);
      expect(AnatomyLogRecord.fromFirestore(map).relatedPartIds, [
        'quad',
        'adductor',
      ]);
      // 옛 기록은 비어 있고, 중복·빈 값·8개 초과는 걸러진다.
      expect(
        AnatomyLogRecord.fromFirestore(base.toFirestore()).relatedPartIds,
        isEmpty,
      );
      final dirty = Map<String, dynamic>.of(map)
        ..['relatedPartIds'] = [
          'quad',
          'quad',
          '',
          ...List.generate(10, (i) => 'p$i'),
        ];
      final parsed = AnatomyLogRecord.fromFirestore(dirty).relatedPartIds;
      expect(parsed.length, AnatomyLogRecord.maxRelatedParts);
      expect(parsed.first, 'quad');
      expect(parsed.toSet().length, parsed.length);
    });
  });

  group('바디맵 표시(색)', () {
    final data = _loadData();
    final back = data.sceneFor(BodyGender.male, BodyView.back);
    final front = data.sceneFor(BodyGender.male, BodyView.front);

    AnatomyLogRecord record(
      String part,
      AnatomyRecordType type, {
      BodySide side = BodySide.both,
      List<String> related = const [],
    }) {
      return AnatomyLogRecord(
        anatomyLogId: '$part-${type.name}-${side.name}',
        trainerId: 't',
        memberId: 'm',
        lessonLogId: 'l',
        scheduleDocId: '',
        recordedAt: DateTime(2026, 10, 12),
        bodyGender: BodyGender.male,
        bodyView: BodyView.back,
        bodySide: side,
        bodyPartId: part,
        bodyPartLabel: part,
        recordType: type,
        exerciseName: '',
        painLevel: 0,
        memo: '',
        relatedPartIds: related,
        createdAt: DateTime(2026, 10, 12),
        updatedAt: DateTime(2026, 10, 12),
      );
    }

    BodyMapZone zone(BodyMapScene scene, String part, BodySide side) =>
        scene.zones.firstWhere((z) => z.part == part && z.side == side);

    test('기록 종류별 단일 표시', () {
      for (final entry
          in {
            AnatomyRecordType.exercise: AnatomyMark.target,
            AnatomyRecordType.pain: AnatomyMark.pain,
            AnatomyRecordType.caution: AnatomyMark.caution,
            AnatomyRecordType.mobility: AnatomyMark.mobility,
          }.entries) {
        expect(
          anatomyMarksFor(zone(back, 'glute', BodySide.left), [
            record('glute', entry.key),
          ]),
          [entry.value],
        );
      }
    });

    test('종류가 겹치면 섞지 않고 우선순위 순으로 여러 표시를 돌려준다', () {
      final marks = anatomyMarksFor(zone(back, 'glute', BodySide.left), [
        record('glute', AnatomyRecordType.exercise),
        record('glute', AnatomyRecordType.pain),
        record('glute', AnatomyRecordType.mobility),
      ]);
      expect(marks, [
        AnatomyMark.pain,
        AnatomyMark.mobility,
        AnatomyMark.target,
      ]);
    });

    test('함께 쓴 부위는 다른 표시가 없을 때만 나타난다', () {
      final exercise = record(
        'quad',
        AnatomyRecordType.exercise,
        related: ['glute', 'hamstring'],
      );
      final glute = zone(back, 'glute', BodySide.left);
      expect(anatomyMarksFor(glute, [exercise]), [AnatomyMark.related]);
      // 같은 부위에 통증 기록이 있으면 통증만(줄무늬에 함께 쓴 부위는 없음)
      expect(
        anatomyMarksFor(glute, [
          exercise,
          record('glute', AnatomyRecordType.pain),
        ]),
        [AnatomyMark.pain],
      );
      // 통증 기록의 함께 쓴 부위는 표시하지 않는다
      expect(
        anatomyMarksFor(glute, [
          record('quad', AnatomyRecordType.pain, related: ['glute']),
        ]),
        isEmpty,
      );
    });

    test('코어를 함께 쓴 부위로 고르면 복근·복사근·기립근·허리를 칠한다', () {
      final exercise = record(
        'glute',
        AnatomyRecordType.exercise,
        related: ['core'],
      );
      for (final entry
          in {
            front: ['abs', 'oblique'],
            back: ['lower_back'],
          }.entries) {
        for (final part in entry.value) {
          final z = entry.key.zones.firstWhere((z) => z.part == part);
          expect(anatomyMarksFor(z, [exercise]), [
            AnatomyMark.related,
          ], reason: part);
        }
      }
      // 코어에 들지 않는 부위는 칠하지 않는다
      expect(
        anatomyMarksFor(zone(front, 'chest', BodySide.left), [exercise]),
        isEmpty,
      );
      // 목표 부위가 코어 구성 부위면 목표 표시가 우선한다
      final abs = record('abs', AnatomyRecordType.exercise, related: ['core']);
      expect(
        anatomyMarksFor(front.zones.firstWhere((z) => z.part == 'abs'), [abs]),
        [AnatomyMark.target],
      );
    });

    test('코어는 함께 쓴 부위 목록에만 있고 이름이 보인다', () {
      expect(selectableRelatedParts.map((p) => p.id), contains('core'));
      expect(bodyPartLabels(['core']), ['코어']);
      expect(
        kBodyParts.where((p) => !p.legacy).map((p) => p.id),
        isNot(contains('core')),
      );
    });

    test('좌우: 한쪽 기록은 반대쪽 조각을 칠하지 않는다', () {
      final right = record(
        'delt_side',
        AnatomyRecordType.pain,
        side: BodySide.right,
      );
      expect(
        anatomyMarksFor(zone(front, 'delt_side', BodySide.right), [right]),
        [AnatomyMark.pain],
      );
      expect(
        anatomyMarksFor(zone(front, 'delt_side', BodySide.left), [right]),
        isEmpty,
      );
    });

    test('색은 종류마다 달라 서로 섞이지 않는다', () {
      for (final dark in [false, true]) {
        final colors = {
          for (final m in AnatomyMark.values) anatomyMarkColor(m, dark: dark),
        };
        expect(colors.length, AnatomyMark.values.length);
      }
    });
  });

  group('점(핀)', () {
    final data = _loadData();
    final front = data.sceneFor(BodyGender.male, BodyView.front);
    final back = data.sceneFor(BodyGender.male, BodyView.back);

    test('AnatomyPin 은 범위를 벗어나면 읽지 않는다', () {
      expect(AnatomyPin.fromMap({'x': 100, 'y': 200.5}), isNotNull);
      expect(AnatomyPin.fromMap({'x': -1, 'y': 10}), isNull);
      expect(AnatomyPin.fromMap({'x': 701, 'y': 10}), isNull);
      expect(AnatomyPin.fromMap({'x': 10, 'y': 901}), isNull);
      expect(AnatomyPin.fromMap({'x': '10', 'y': 10}), isNull);
      expect(AnatomyPin.fromMap('10,10'), isNull);
    });

    test('기록에 점과 가동성 결과가 저장·복원되고 없으면 필드를 쓰지 않는다', () {
      final base = AnatomyLogRecord(
        anatomyLogId: 'a',
        trainerId: 't',
        memberId: 'm',
        lessonLogId: 'l',
        scheduleDocId: '',
        recordedAt: DateTime(2026, 10, 12),
        bodyGender: BodyGender.male,
        bodyView: BodyView.front,
        bodySide: BodySide.left,
        bodyPartId: 'quad',
        bodyPartLabel: '대퇴사두',
        recordType: AnatomyRecordType.mobility,
        exerciseName: '토마스 테스트',
        painLevel: 0,
        memo: '',
        createdAt: DateTime(2026, 10, 12),
        updatedAt: DateTime(2026, 10, 12),
      );
      expect(base.toFirestore().containsKey('pin'), isFalse);
      expect(base.toFirestore().containsKey('mobilityResult'), isFalse);
      final pinned = base.copyWith(
        pin: const AnatomyPin(x: 250.5, y: 560),
        mobilityResult: MobilityResult.mild,
      );
      final map = pinned.toFirestore();
      expect(map['pin'], {'x': 250.5, 'y': 560.0});
      expect(map['mobilityResult'], 'mild');
      final restored = AnatomyLogRecord.fromFirestore(map);
      expect(restored.pin, const AnatomyPin(x: 250.5, y: 560));
      expect(restored.mobilityResult, MobilityResult.mild);
      // 결과를 지울 수 있다(점은 유지).
      final cleared = pinned.copyWith(clearMobilityResult: true);
      expect(cleared.mobilityResult, isNull);
      expect(cleared.pin, isNotNull);
      // 옛 기록·잘못된 값
      expect(AnatomyLogRecord.fromFirestore(base.toFirestore()).pin, isNull);
      final bad =
          Map<String, dynamic>.of(map)
            ..['mobilityResult'] = 'weird'
            ..['pin'] = {'x': 9999, 'y': 1};
      final parsed = AnatomyLogRecord.fromFirestore(bad);
      expect(parsed.mobilityResult, isNull);
      expect(parsed.pin, isNull);
    });

    test('점의 좌우: 가운데선 근처는 중앙, 구역이 있으면 구역 따라', () {
      final mid = front.midline;
      expect(front.sideForPoint(Offset(mid + 3, 300), null), BodySide.center);
      expect(front.sideForPoint(Offset(mid - 7, 300), null), BodySide.center);
      final rightArm = front.zones.firstWhere(
        (z) => z.part == 'biceps' && z.side == BodySide.right,
      );
      expect(
        front.sideForPoint(rightArm.bounds.center, rightArm),
        BodySide.right,
      );
    });

    test('구역이 없으면 x 위치로: 앞면은 화면 왼쪽이 오른쪽, 뒷면은 왼쪽', () {
      expect(
        front.sideForPoint(Offset(front.midline - 60, 300), null),
        BodySide.right,
      );
      expect(
        front.sideForPoint(Offset(front.midline + 60, 300), null),
        BodySide.left,
      );
      expect(
        back.sideForPoint(Offset(back.midline - 60, 300), null),
        BodySide.left,
      );
      expect(
        back.sideForPoint(Offset(back.midline + 60, 300), null),
        BodySide.right,
      );
    });

    test('점으로 찍은 통증·주의·가동성은 구역을 칠하지 않는다', () {
      AnatomyLogRecord record(AnatomyRecordType type, {AnatomyPin? pin}) {
        return AnatomyLogRecord(
          anatomyLogId: 'x${type.name}${pin != null}',
          trainerId: 't',
          memberId: 'm',
          lessonLogId: 'l',
          scheduleDocId: '',
          recordedAt: DateTime(2026, 10, 12),
          bodyGender: BodyGender.male,
          bodyView: BodyView.front,
          bodySide: BodySide.both,
          bodyPartId: 'quad',
          bodyPartLabel: '대퇴사두',
          recordType: type,
          exerciseName: '무릎',
          painLevel: 3,
          memo: '',
          pin: pin,
          createdAt: DateTime(2026, 10, 12),
          updatedAt: DateTime(2026, 10, 12),
        );
      }

      final zone = front.zones.firstWhere((z) => z.part == 'quad');
      const pin = AnatomyPin(x: 250, y: 560);
      expect(
        anatomyMarksFor(zone, [record(AnatomyRecordType.pain, pin: pin)]),
        isEmpty,
      );
      expect(
        anatomyMarksFor(zone, [record(AnatomyRecordType.caution, pin: pin)]),
        isEmpty,
      );
      expect(
        anatomyMarksFor(zone, [record(AnatomyRecordType.mobility, pin: pin)]),
        isEmpty,
      );
      // 점이 없는 예전 기록은 구역을 칠한다.
      expect(anatomyMarksFor(zone, [record(AnatomyRecordType.pain)]), [
        AnatomyMark.pain,
      ]);
      // 운동은 점이 있어도 구역을 칠한다.
      expect(
        anatomyMarksFor(zone, [record(AnatomyRecordType.exercise, pin: pin)]),
        [AnatomyMark.target],
      );
    });

    test('몸 마스크: 열린 마스크는 어디든 몸으로 본다', () {
      final mask = BodyMask.open(data.viewBox);
      expect(mask.contains(const Offset(10, 10)), isTrue);
    });

    test('위치 칩: 구역별 칩과 기본 칩, 칩 키', () {
      expect(locationChipsFor('quad'), contains('무릎'));
      expect(locationChipsFor('lower_back'), ['허리', '꼬리뼈', '골반']);
      expect(locationChipsFor('other'), kGeneralLocationChips);
      expect(locationChipKey('quad'), 'p:quad');
      expect(kMobilityChipKey, 't:mobility');
      expect(kMobilityTestChips, contains('토마스 테스트'));
      for (final part in kBodyParts.where((p) => !p.legacy)) {
        expect(kLocationChips, contains(part.id), reason: part.id);
      }
    });
  });

  group('운동 이력·추이 계산', () {
    final d1 = DateTime(2026, 9, 1, 10);
    final d2 = DateTime(2026, 9, 8, 10);
    final d3 = DateTime(2026, 9, 15, 10);
    AnatomyLogRecord rec(
      String lesson,
      DateTime date,
      List<AnatomySet> sets, {
      String exercise = '스쿼트',
      List<String> related = const [],
    }) => _histRecord(
      lesson: lesson,
      date: date,
      exercise: exercise,
      sets: sets,
      related: related,
    );
    const heavy = [
      AnatomySet(weightKg: 60, reps: 10),
      AnatomySet(weightKg: 60, reps: 8),
    ];
    const heavier = [AnatomySet(weightKg: 70, reps: 5)];
    const light = [AnatomySet(weightKg: 20, reps: 12)];

    test('레슨별로 묶고 날짜 오름차순, 이름 표기 차이(공백·대소문자)는 같은 운동', () {
      final history = AnatomyMemberHistory([
        rec('l2', d2, heavier, exercise: ' 스쿼트 '),
        rec('l1', d1, heavy),
        rec('l1', d1, light), // 같은 레슨 같은 운동은 세트를 합친다
        rec('l3', d3, const [], exercise: '스쿼트'), // 세트 없는 기록은 뺀다
      ]);
      final sessions = history.sessionsFor('스쿼트');
      expect(sessions.map((s) => s.lessonLogId), ['l1', 'l2']);
      expect(sessions.first.sets.length, 3);
      expect(sessions.first.date, d1);
    });

    test('지표 값: 추정 1RM·최대 무게·볼륨·최대 횟수', () {
      final session = ExerciseSession(
        lessonLogId: 'l',
        date: DateTime(2026, 9, 1),
        sets: const [
          AnatomySet(weightKg: 60, reps: 10),
          AnatomySet(weightKg: 80, reps: 3),
        ],
      );
      expect(
        session.value(TrendMetric.oneRm)!,
        closeTo(88.0, 0.01),
      ); // 80*(1+3/30)
      expect(session.value(TrendMetric.maxWeight), 80);
      expect(session.value(TrendMetric.volume), 60 * 10 + 80 * 3);
      expect(session.value(TrendMetric.maxReps), 10);
      // 맨몸(무게 0)은 무게 기반 지표가 없다
      final bodyweight = ExerciseSession(
        lessonLogId: 'l',
        date: DateTime(2026, 9, 1),
        sets: const [AnatomySet(weightKg: 0, reps: 15)],
      );
      expect(bodyweight.value(TrendMetric.oneRm), isNull);
      expect(bodyweight.value(TrendMetric.maxWeight), isNull);
      expect(bodyweight.value(TrendMetric.volume), isNull);
      expect(bodyweight.value(TrendMetric.maxReps), 15);
    });

    test('추이 점은 지표를 계산할 수 있는 레슨만, 날짜 순', () {
      final history = AnatomyMemberHistory([
        rec('l1', d1, light),
        rec('l2', d2, heavy),
        rec('l3', d3, heavier),
      ]);
      final points = history.trend('스쿼트', TrendMetric.maxWeight);
      expect(points.map((p) => p.value), [20, 60, 70]);
      expect(points.map((p) => p.date), [d1, d2, d3]);
    });

    test('최근 운동 이름: 최신순·중복 제거·개수 제한', () {
      final history = AnatomyMemberHistory([
        rec('l1', d1, light, exercise: '런지'),
        rec('l2', d2, light, exercise: '스쿼트'),
        rec('l3', d3, light, exercise: '런지'),
        rec('l3', d3.add(const Duration(minutes: 1)), light, exercise: '레그프레스'),
      ]);
      expect(history.recentExerciseNames(), ['레그프레스', '런지', '스쿼트']);
      expect(history.recentExerciseNames(limit: 2), ['레그프레스', '런지']);
    });

    test('지난번 기록은 지금 쓰는 레슨을 뺀다', () {
      final history = AnatomyMemberHistory([
        rec('l1', d1, light),
        rec('l2', d2, heavy),
        rec('now', d3, heavier),
      ]);
      expect(history.lastSession('스쿼트')!.lessonLogId, 'now');
      expect(
        history.lastSession('스쿼트', excludeLessonLogId: 'now')!.lessonLogId,
        'l2',
      );
      expect(history.lastSession('없는 운동'), isNull);
    });

    test('merge: 같은 레슨은 서버 값 대신 편집 중인 기록으로 바꾼다', () {
      final merged = AnatomyMemberHistory.merge(
        fetched: [rec('now', d2, light), rec('l1', d1, heavy)],
        current: [rec('now', d3, heavier)],
        lessonLogId: 'now',
      );
      expect(merged.sessionsFor('스쿼트').map((s) => s.lessonLogId), [
        'l1',
        'now',
      ]);
      expect(merged.sessionsFor('스쿼트').last.sets, heavier);
    });

    test('지난번 보조 부위 기억', () {
      final history = AnatomyMemberHistory([
        rec('l1', d1, light, exercise: '내 운동', related: ['glute']),
        rec('l2', d2, light, exercise: '내 운동', related: ['glute', 'hamstring']),
        rec('l3', d3, light, exercise: '내 운동'), // 보조 부위 없는 기록은 건너뜀
      ]);
      final memory = history.lastRelatedFor('내 운동')!;
      expect(memory.related, ['glute', 'hamstring']);
      expect(memory.mainPartId, 'quad');
      expect(history.lastRelatedFor('다른 운동'), isNull);
    });

    test('최근 4주 집중 부위: 레슨 수·세트 수 순, 오래된 기록 제외', () {
      final now = DateTime(2026, 10, 12);
      final history = AnatomyMemberHistory([
        _histRecord(
          lesson: 'a',
          date: DateTime(2026, 10, 10),
          part: 'glute',
          partLabel: '둔근',
          sets: heavy,
        ),
        _histRecord(
          lesson: 'b',
          date: DateTime(2026, 10, 3),
          part: 'glute',
          partLabel: '둔근',
          sets: heavy,
        ),
        _histRecord(
          lesson: 'b',
          date: DateTime(2026, 10, 3),
          exercise: '런지',
          part: 'quad',
          partLabel: '대퇴사두',
          sets: heavier,
        ),
        _histRecord(
          lesson: 'old',
          date: DateTime(2026, 8, 1),
          part: 'chest',
          partLabel: '가슴',
          sets: heavy,
        ),
        _histRecord(
          lesson: 'a',
          date: DateTime(2026, 10, 10),
          exercise: '무릎',
          part: 'quad',
          partLabel: '대퇴사두',
          type: AnatomyRecordType.pain,
          painLevel: 3,
        ),
      ]);
      final focus = history.focus(now: now);
      expect(focus.map((e) => e.partId), ['glute', 'quad']);
      expect(focus.first.sessions, 2);
      expect(focus.first.sets, 4);
      expect(focus.last.sessions, 1);
    });

    test('운동별 개요: 최근에 한 운동이 위, 직전 기록 비교', () {
      final history = AnatomyMemberHistory([
        rec('l1', d1, light, exercise: '런지'),
        rec('l2', d2, heavy, exercise: '스쿼트'),
        rec('l3', d3, heavier, exercise: '스쿼트'),
      ]);
      final overviews = history.exercises();
      expect(overviews.map((o) => o.name), ['스쿼트', '런지']);
      expect(overviews.first.previous!.lessonLogId, 'l2');
      expect(overviews.last.previous, isNull);
    });

    test('종류별 기록은 최신순', () {
      final history = AnatomyMemberHistory([
        _histRecord(
          lesson: 'l1',
          date: d1,
          exercise: '무릎',
          type: AnatomyRecordType.pain,
          painLevel: 3,
        ),
        _histRecord(
          lesson: 'l2',
          date: d3,
          exercise: '발목',
          type: AnatomyRecordType.pain,
          painLevel: 5,
        ),
        rec('l2', d2, light),
      ]);
      expect(
        history.byType(AnatomyRecordType.pain).map((r) => r.exerciseName),
        ['발목', '무릎'],
      );
    });

    test('표시 형식', () {
      expect(formatAnatomyDate(DateTime(2026, 3, 4)), '2026.03.04');
      expect(formatAnatomyShortDate(DateTime(2026, 3, 4)), '3/4');
      expect(formatAnatomyNumber(80), '80');
      expect(formatAnatomyNumber(88.04), '88');
      expect(formatAnatomyNumber(11.25), '11.3');
      expect(formatAnatomyNumber(123.4), '123');
    });
  });

  group('추이·이력 화면', () {
    final d1 = DateTime(2026, 9, 1, 10);
    final d2 = DateTime(2026, 9, 8, 10);
    final d3 = DateTime(2026, 9, 15, 10);
    final history = AnatomyMemberHistory([
      _histRecord(
        lesson: 'l1',
        date: d1,
        sets: const [AnatomySet(weightKg: 50, reps: 10)],
      ),
      _histRecord(
        lesson: 'l2',
        date: d2,
        sets: const [AnatomySet(weightKg: 60, reps: 10)],
      ),
      _histRecord(
        lesson: 'l3',
        date: d3,
        sets: const [AnatomySet(weightKg: 60, reps: 12)],
      ),
      _histRecord(
        lesson: 'l3',
        date: d3,
        exercise: '무릎 안쪽 당김',
        type: AnatomyRecordType.pain,
        painLevel: 5,
        side: BodySide.left,
        memo: '내려갈 때',
      ),
      _histRecord(
        lesson: 'l3',
        date: d3,
        exercise: '발목 굽히기',
        type: AnatomyRecordType.mobility,
        mobility: MobilityResult.mild,
        side: BodySide.right,
      ),
      _histRecord(
        lesson: 'l3',
        date: d3,
        exercise: '머리 위로 들 때 조심',
        type: AnatomyRecordType.caution,
        part: 'delt_side',
        partLabel: '측면삼각근',
      ),
    ]);

    Future<void> pump(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(900, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: child));
      await tester.pumpAndSettle();
    }

    testWidgets('추이 화면: 지표를 바꾸면 값과 변화가 바뀐다', (tester) async {
      await pump(
        tester,
        AnatomyExerciseTrendPage(exercise: '스쿼트', history: history),
      );
      expect(find.text('스쿼트 추이'), findsOneWidget);
      expect(find.byType(TrendChart), findsOneWidget);
      // 추정 1RM: 60*(1+12/30)=84, 직전 60*(1+10/30)=80 → ▲4
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('trend_latest'))).data,
        '84kg',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('trend_change'))).data,
        '▲ 4kg',
      );
      await tester.tap(find.byKey(const ValueKey('trend_metric_maxReps')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('trend_latest'))).data,
        '12회',
      );
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('trend_change'))).data,
        '▲ 2회',
      );
      await tester.tap(find.byKey(const ValueKey('trend_metric_volume')));
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('trend_latest'))).data,
        '720kg',
      );
      expect(find.byKey(const ValueKey('trend_session_l3')), findsOneWidget);
      expect(find.byKey(const ValueKey('trend_session_l1')), findsOneWidget);
    });

    testWidgets('추이 화면: 기록이 없는 운동은 안내를 보여준다', (tester) async {
      await pump(
        tester,
        AnatomyExerciseTrendPage(exercise: '없는 운동', history: history),
      );
      expect(find.text('이 지표로 그릴 기록이 아직 없어요.'), findsOneWidget);
      expect(find.text('아직 세트를 기록한 레슨이 없어요.'), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('trend_latest'))).data,
        '-',
      );
    });

    testWidgets('이력 화면: 운동 탭에 집중 부위와 운동별 기록, 누르면 추이', (tester) async {
      final now = DateTime.now();
      final recent = AnatomyMemberHistory([
        _histRecord(
          lesson: 'r1',
          date: now.subtract(const Duration(days: 3)),
          part: 'glute',
          partLabel: '둔근',
          exercise: '힙쓰러스트',
          sets: const [AnatomySet(weightKg: 40, reps: 12)],
        ),
        _histRecord(
          lesson: 'r2',
          date: now.subtract(const Duration(days: 10)),
          part: 'glute',
          partLabel: '둔근',
          exercise: '힙쓰러스트',
          sets: const [AnatomySet(weightKg: 30, reps: 12)],
        ),
      ]);
      await pump(
        tester,
        AnatomyHistoryPage(memberName: '김회원', history: recent),
      );
      expect(find.text('김회원 님 변화 보기'), findsOneWidget);
      expect(find.byKey(const ValueKey('focus_glute')), findsOneWidget);
      expect(find.text('2회 · 2세트'), findsOneWidget);
      expect(find.byKey(const ValueKey('exercise_row_힙쓰러스트')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('exercise_row_힙쓰러스트')));
      await tester.pumpAndSettle();
      expect(find.text('힙쓰러스트 추이'), findsOneWidget);
    });

    testWidgets('이력 화면: 오래된 기록만 있으면 집중 부위는 비어 있다', (tester) async {
      final old = AnatomyMemberHistory([
        _histRecord(
          lesson: 'x',
          date: DateTime(2020, 1, 1),
          sets: const [AnatomySet(weightKg: 40, reps: 10)],
        ),
      ]);
      await pump(tester, AnatomyHistoryPage(memberName: '', history: old));
      expect(find.text('변화 보기'), findsOneWidget);
      expect(find.byKey(const ValueKey('focus_empty')), findsOneWidget);
    });

    testWidgets('이력 화면: 통증·불편 탭과 가동성·주의 탭', (tester) async {
      await pump(
        tester,
        AnatomyHistoryPage(memberName: '김회원', history: history),
      );
      await tester.tap(find.byKey(const ValueKey('history_tab_pain')));
      await tester.pumpAndSettle();
      expect(find.text('왼쪽 무릎 안쪽 당김'), findsOneWidget);
      expect(find.text('5 / 10'), findsOneWidget);
      expect(find.text('내려갈 때'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('history_tab_other')));
      await tester.pumpAndSettle();
      expect(find.text('오른쪽 발목 굽히기'), findsOneWidget);
      expect(find.text('△ 보상'), findsOneWidget);
      expect(find.text('머리 위로 들 때 조심'), findsOneWidget);
      expect(find.text('주의'), findsWidgets);
    });

    testWidgets('이력이 없으면 빈 안내', (tester) async {
      await pump(
        tester,
        AnatomyHistoryPage(
          memberName: '김회원',
          history: AnatomyMemberHistory(const []),
        ),
      );
      expect(find.byKey(const ValueKey('exercise_empty')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('history_tab_pain')));
      await tester.pumpAndSettle();
      expect(find.text('아직 통증·불편 기록이 없어요.'), findsOneWidget);
    });
  });

  group('PersonalTrainingLogAnatomyPage 입력 창', () {
    final data = _loadData();
    final front = data.sceneFor(BodyGender.unspecified, BodyView.front);

    setUp(() {
      // 구역 밖의 몸을 누르는 테스트를 위해 모든 곳을 몸으로 본다.
      BodyMask.resetCacheForTest();
      BodyMask.loader = (asset, viewBox) async => BodyMask.open(viewBox);
    });
    tearDown(() {
      BodyMask.loader = BodyMask.defaultLoader;
      BodyMask.resetCacheForTest();
    });

    Future<_FakeAnatomyService> openPage(
      WidgetTester tester, {
      String? memberGender,
      AnatomyExerciseStore? store,
      AnatomyHistoryStore? historyStore,
    }) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final service = _FakeAnatomyService();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<bool>(
                              builder:
                                  (_) => PersonalTrainingLogAnatomyPage(
                                    lessonLogId: 'lesson-1',
                                    recordedAt: DateTime(2026, 7, 15, 14),
                                    memberId: 'member-1',
                                    memberName: '김회원',
                                    trainerId: 'trainer-1',
                                    scheduleDocId: 'schedule-1',
                                    memberGender: memberGender,
                                    service: service,
                                    exerciseStore: store,
                                    historyStore: historyStore,
                                  ),
                            ),
                          ),
                      child: const Text('열기'),
                    ),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      return service;
    }

    Future<void> tapZone(
      WidgetTester tester,
      BodyMapScene scene,
      String part,
      BodySide side,
    ) async {
      await _tapMapPoint(tester, data, _interiorPoint(scene, part, side));
      await tester.pumpAndSettle();
    }

    /// 열린 입력 창에서 운동을 고르고 세트를 채워 추가한다.
    Future<void> addExercise(
      WidgetTester tester,
      String name, {
      String weight = '8',
      String reps = '12',
    }) async {
      await tester.tap(find.byKey(ValueKey('record_option_$name')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('set_weight_0')),
        weight,
      );
      await tester.enterText(find.byKey(const ValueKey('set_reps_0')), reps);
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
    }

    testWidgets('부위를 누르면 입력 창이 열리고 기록이 목록에 쌓인다', (tester) async {
      await openPage(tester);
      await tapZone(tester, front, 'delt_side', BodySide.right);
      expect(find.byKey(const ValueKey('record_sheet_title')), findsOneWidget);
      expect(find.text('측면삼각근'), findsWidgets);
      await addExercise(tester, '사이드 레터럴 레이즈');
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();
      expect(find.text('기록 1개'), findsOneWidget);
      expect(find.text('사이드 레터럴 레이즈'), findsOneWidget);
      expect(find.text('1 X 8kg | 12회'), findsOneWidget);
    });

    testWidgets('양쪽 함께 모드는 양쪽, 한쪽씩 모드는 누른 쪽이 기본값이다', (tester) async {
      await openPage(tester);
      await tapZone(tester, front, 'delt_side', BodySide.right);
      final both = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('record_side_both')),
      );
      expect(both.selected, isTrue);
      await tester.tapAt(const Offset(10, 10)); // 창 닫기
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('side_mode_single')));
      await tester.pump();
      await tapZone(tester, front, 'delt_side', BodySide.right);
      final right = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('record_side_right')),
      );
      expect(right.selected, isTrue);
    });

    testWidgets('복근은 좌우 선택 없이 열린다', (tester) async {
      await openPage(tester);
      await tapZone(tester, front, 'abs', BodySide.center);
      expect(find.byKey(const ValueKey('record_side_both')), findsNothing);
      expect(find.byKey(const ValueKey('record_side_left')), findsNothing);
    });

    testWidgets('세트 횟수가 없으면 오류를 보이고 추가하지 않는다', (tester) async {
      await openPage(tester);
      await tapZone(tester, front, 'quad', BodySide.left);
      await tester.tap(find.byKey(const ValueKey('record_option_스쿼트')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('set_weight_0')), '60');
      await tester.enterText(find.byKey(const ValueKey('set_reps_0')), '');
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('record_error')), findsOneWidget);
      expect(find.textContaining('이번에 추가한 기록'), findsNothing);
    });

    testWidgets('무게·횟수에 글자를 넣으면 숫자만 입력하라는 안내가 뜬다', (tester) async {
      await openPage(tester);
      await tapZone(tester, front, 'quad', BodySide.left);
      await tester.tap(find.byKey(const ValueKey('record_option_스쿼트')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('set_reps_0')), '10회');
      await tester.pump();
      expect(find.text('숫자만 입력할 수 있어요.'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('set_reps_0')))
            .controller!
            .text,
        '10',
      );
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('숫자만 입력할 수 있어요.'), findsNothing);

      await tester.enterText(find.byKey(const ValueKey('set_weight_0')), '6o');
      await tester.pump();
      expect(find.text('숫자만 입력할 수 있어요.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));

      // 숫자와 소수점은 안내 없이 들어간다
      await tester.enterText(
        find.byKey(const ValueKey('set_weight_0')),
        '62.5',
      );
      await tester.pump();
      expect(find.text('숫자만 입력할 수 있어요.'), findsNothing);
    });

    testWidgets('세트마다 보조 횟수를 적을 수 있고 요약에 (+보조)로 보인다', (tester) async {
      final service = await openPage(tester);
      await tapZone(tester, front, 'quad', BodySide.left);
      await tester.tap(find.byKey(const ValueKey('record_option_스쿼트')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('set_weight_0')), '40');
      await tester.enterText(find.byKey(const ValueKey('set_reps_0')), '8');
      await tester.enterText(find.byKey(const ValueKey('set_assist_0')), '2');
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();
      expect(find.text('1 X 40kg | 8(+2)회'), findsOneWidget);
      expect(service, isNotNull);
    });

    testWidgets('보조 횟수가 비어 있으면 0으로 보고 저장하지 않는다', (tester) async {
      await openPage(tester);
      await tapZone(tester, front, 'quad', BodySide.left);
      await addExercise(tester, '스쿼트', weight: '40', reps: '8');
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();
      expect(find.text('1 X 40kg | 8회'), findsOneWidget);
    });

    testWidgets('운동을 고르지 않으면 추가할 수 없다', (tester) async {
      await openPage(tester);
      await tapZone(tester, front, 'quad', BodySide.left);
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('record_error')), findsOneWidget);
    });

    testWidgets('운동을 고르면 첫 세트 횟수가 12로 채워진다', (tester) async {
      await openPage(tester);
      await tapZone(tester, front, 'delt_side', BodySide.right);
      await tester.tap(find.byKey(const ValueKey('record_option_사이드 레터럴 레이즈')));
      await tester.pumpAndSettle();
      final reps = tester.widget<TextField>(
        find.byKey(const ValueKey('set_reps_0')),
      );
      expect(reps.controller!.text, '12');
    });

    testWidgets('시스템 내비게이션 바 위로 기록 추가 버튼이 올라온다', (tester) async {
      await openPage(tester);
      const navBar = FakeViewPadding(bottom: 120);
      tester.view.padding = navBar;
      tester.view.viewPadding = navBar;
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewPadding);
      await tapZone(tester, front, 'delt_side', BodySide.right);
      final submit = tester.getRect(
        find.byKey(const ValueKey('record_submit')),
      );
      expect(submit.bottom, lessThanOrEqualTo(3200 - 120));
    });

    testWidgets('통증 정도는 1부터 시작하고 0은 저장되지 않는다', (tester) async {
      final service = await openPage(tester);
      await tapZone(tester, front, 'delt_side', BodySide.right);
      await tester.tap(find.byKey(const ValueKey('record_type_pain')));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('record_pain')),
      );
      expect(slider.min, 1);
      expect(slider.value, 1);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('record_pain_value')))
            .data,
        '1 / 10',
      );
      await tester.enterText(find.byKey(const ValueKey('record_title')), '무릎');
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('저장하기'));
      await tester.pumpAndSettle();
      expect(service.saved.single.painLevel, 1);
    });

    testWidgets('주의·가동성은 내용이나 메모 없이는 추가되지 않는다', (tester) async {
      await openPage(tester);
      await tapZone(tester, front, 'delt_side', BodySide.right);
      for (final type in ['caution', 'mobility']) {
        await tester.tap(find.byKey(ValueKey('record_type_$type')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('record_submit')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('record_error')), findsOneWidget);
        expect(find.textContaining('이번에 추가한 기록'), findsNothing);
      }
      await tester.enterText(
        find.byKey(const ValueKey('record_title')),
        '어깨 올리기 제한',
      );
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      expect(find.text('이번에 추가한 기록 1개'), findsOneWidget);
    });

    testWidgets('통증 기록은 슬라이더 값을 저장한다', (tester) async {
      final service = await openPage(tester);
      await tapZone(tester, front, 'delt_side', BodySide.right);
      await tester.tap(find.byKey(const ValueKey('record_type_pain')));
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const ValueKey('record_pain')),
        const Offset(400, 0),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('record_title')),
        '어깨 앞쪽 당김',
      );
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('저장하기'));
      await tester.pumpAndSettle();
      final record = service.saved.single;
      expect(record.recordType, AnatomyRecordType.pain);
      expect(record.painLevel, greaterThan(0));
      expect(record.exerciseName, '어깨 앞쪽 당김');
      expect(record.sets, isEmpty);
    });

    testWidgets('기록을 눌러 수정하고 삭제한다', (tester) async {
      await openPage(tester);
      await tapZone(tester, front, 'delt_side', BodySide.right);
      await addExercise(tester, '사이드 레터럴 레이즈');
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('record_rec-0')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('set_reps_0')), '15');
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      expect(find.text('1 X 8kg | 15회'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('record_rec-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_delete')));
      await tester.pumpAndSettle();
      expect(find.textContaining('아직 기록이 없어요'), findsOneWidget);
    });

    testWidgets('한쪽 기록과 세트가 bodySide·bodyView·sets 로 저장된다', (tester) async {
      final service = await openPage(tester);
      await tester.tap(find.byKey(const ValueKey('side_mode_single')));
      await tester.pump();
      await tapZone(tester, front, 'delt_side', BodySide.right);
      await addExercise(tester, '사이드 레터럴 레이즈');
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();
      expect(find.text('측면삼각근 (오른쪽)'), findsOneWidget);

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장하기'));
      await tester.pumpAndSettle();

      final record = service.saved.single;
      expect(record.bodyPartId, 'delt_side');
      expect(record.bodySide, BodySide.right);
      expect(record.bodyView, BodyView.front);
      expect(record.bodyPartLabel, '측면삼각근');
      expect(record.sets, const [AnatomySet(weightKg: 8, reps: 12)]);
    });

    testWidgets('스쿼트를 고르면 보조 부위가 켜지고 목표 부위를 바꿔 저장한다', (tester) async {
      final service = await openPage(tester);
      await tapZone(tester, front, 'quad', BodySide.left);
      await tester.tap(find.byKey(const ValueKey('record_option_스쿼트')));
      await tester.pumpAndSettle();

      for (final id in ['glute', 'hamstring', 'adductor']) {
        final chip = tester.widget<FilterChip>(
          find.byKey(ValueKey('record_related_$id')),
        );
        expect(chip.selected, isTrue, reason: id);
      }
      // 햄스트링은 이번 수업에서 뺀다
      await tester.tap(find.byKey(const ValueKey('record_related_hamstring')));
      await tester.pumpAndSettle();
      // 목표 부위를 대퇴사두 → 둔근으로
      await tester.tap(find.byKey(const ValueKey('record_target')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_target_glute')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('record_sheet_title')))
            .data,
        '둔근',
      );
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();

      // 목록은 목표 부위(둔근) 아래에, 함께 쓴 부위가 표시된다
      expect(find.text('둔근'), findsWidgets);
      expect(find.text('함께 쓴 부위 · 대퇴사두 · 내전근'), findsOneWidget);

      // 그림: 목표 부위는 진하게, 보조 부위는 연하게
      final canvas = tester.widget<BodyMapCanvas>(find.byType(BodyMapCanvas));
      expect(canvas.records.single.bodyPartId, 'glute');
      expect(canvas.records.single.relatedPartIds, ['quad', 'adductor']);

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장하기'));
      await tester.pumpAndSettle();
      final record = service.saved.single;
      expect(record.bodyPartId, 'glute');
      expect(record.bodyPartLabel, '둔근');
      expect(record.relatedPartIds, ['quad', 'adductor']);
      expect(record.exerciseName, '스쿼트');
    });

    testWidgets('부위 추가는 4열 격자로 열리고 목표 부위는 고를 수 없다', (tester) async {
      await openPage(tester);
      await tapZone(tester, front, 'quad', BodySide.left);
      await tester.tap(find.byKey(const ValueKey('record_option_스쿼트')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_related_add')));
      await tester.pumpAndSettle();

      final grid = tester.widget<GridView>(
        find.byKey(const ValueKey('record_part_picker')),
      );
      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, 4);
      // 목표 부위(대퇴사두)는 눌러도 바뀌지 않는다
      final main = tester.widget<FilterChip>(
        find.byKey(const ValueKey('record_pick_quad')),
      );
      expect(main.onSelected, isNull);
      // 눌러서 켜고 다시 눌러서 끈다
      await pickPart(tester, 'calf');
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('record_pick_calf')))
            .selected,
        isTrue,
      );
      await pickPart(tester, 'calf');
      expect(
        tester
            .widget<FilterChip>(find.byKey(const ValueKey('record_pick_calf')))
            .selected,
        isFalse,
      );
    });

    testWidgets('같은 스쿼트도 수업마다 목표 부위를 다르게 기록한다', (tester) async {
      await openPage(tester);
      await tapZone(tester, front, 'quad', BodySide.left);
      await addExercise(tester, '스쿼트', weight: '60', reps: '10');
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();
      expect(find.text('대퇴사두'), findsWidgets);
      final canvas = tester.widget<BodyMapCanvas>(find.byType(BodyMapCanvas));
      expect(canvas.records.single.bodyPartId, 'quad');
      expect(canvas.records.single.relatedPartIds, [
        'glute',
        'hamstring',
        'adductor',
      ]);
    });

    testWidgets('내 운동은 보조 부위가 비어 있고 직접 추가한다', (tester) async {
      await openPage(tester);
      await tapZone(tester, front, 'quad', BodySide.left);
      await tester.enterText(
        find.byKey(const ValueKey('record_search')),
        '불가리안 스플릿 스쿼트',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('record_add_custom')));
      await tester.pumpAndSettle();
      expect(find.byType(FilterChip), findsNothing);
      await tester.tap(find.byKey(const ValueKey('record_related_add')));
      await tester.pumpAndSettle();
      await pickPart(tester, 'glute');
      await tester.tap(find.byKey(const ValueKey('record_part_picker_done')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('record_related_glute')),
        findsOneWidget,
      );
    });

    testWidgets('코어를 함께 쓴 부위로 고를 수 있다', (tester) async {
      await openPage(tester);
      await tapZone(tester, front, 'quad', BodySide.left);
      await tester.tap(find.byKey(const ValueKey('record_option_스쿼트')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_related_add')));
      await tester.pumpAndSettle();
      await pickPart(tester, 'core');
      await tester.tap(find.byKey(const ValueKey('record_part_picker_done')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('record_related_core')), findsOneWidget);
      expect(find.text('코어'), findsWidgets);
    });

    /// 구역을 눌러 통증 점을 찍고 [text] 를 적어 추가한 뒤 입력 창을 닫는다.
    Future<Offset> addPainPin(
      WidgetTester tester,
      Offset point,
      String text, {
      String? memo,
    }) async {
      await _tapMapPoint(tester, data, point);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_type_pain')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('record_title')), text);
      if (memo != null) {
        await tester.enterText(find.byKey(const ValueKey('record_memo')), memo);
      }
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();
      return point;
    }

    testWidgets('통증은 누른 자리에 점으로 남고 구역은 칠하지 않는다', (tester) async {
      await openPage(tester);
      final point = _interiorPoint(front, 'quad', BodySide.left);
      await _tapMapPoint(tester, data, point);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_type_pain')));
      await tester.pumpAndSettle();
      // 좌우는 점 자리로 정해져 따로 고르지 않는다.
      expect(find.byKey(const ValueKey('record_side_both')), findsNothing);
      expect(
        tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const ValueKey('record_pin_side')),
                matching: find.byType(Text),
              ),
            )
            .data,
        '왼쪽',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('record_sheet_title')))
            .data,
        '아픈 곳 · 대퇴사두',
      );
      await tester.tap(find.byKey(const ValueKey('record_chip_무릎')));
      await tester.pump();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('record_title')))
            .controller!
            .text,
        '무릎',
      );
      await tester.enterText(
        find.byKey(const ValueKey('record_title')),
        '무릎 안쪽 당김',
      );
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();

      final canvas = tester.widget<BodyMapCanvas>(find.byType(BodyMapCanvas));
      final record = canvas.records.single;
      expect(record.recordType, AnatomyRecordType.pain);
      expect(record.bodySide, BodySide.left);
      expect(record.bodyPartId, 'quad');
      expect(record.pin!.x, closeTo(point.dx, 0.6));
      expect(record.pin!.y, closeTo(point.dy, 0.6));
      final zone = front.zones.firstWhere(
        (z) => z.part == 'quad' && z.side == BodySide.left,
      );
      expect(anatomyMarksFor(zone, canvas.records), isEmpty);
    });

    testWidgets('점을 다시 누르면 수정 창이 열리고 삭제할 수 있다', (tester) async {
      await openPage(tester);
      final point = await addPainPin(
        tester,
        _interiorPoint(front, 'quad', BodySide.left),
        '무릎 안쪽',
      );
      await _tapMapPoint(tester, data, point);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('record_sheet_title')))
            .data,
        '아픈 곳 · 대퇴사두',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('record_title')))
            .controller!
            .text,
        '무릎 안쪽',
      );
      await tester.tap(find.byKey(const ValueKey('record_delete')));
      await tester.pumpAndSettle();
      expect(find.textContaining('아직 기록이 없어요'), findsOneWidget);
    });

    testWidgets('점 근처를 누르면 새로 만들지 않고 그 점을 연다', (tester) async {
      await openPage(tester);
      final point = await addPainPin(
        tester,
        _interiorPoint(front, 'quad', BodySide.left),
        '무릎',
      );
      // 점에서 약간 떨어진 자리(같은 구역)도 같은 점으로 본다
      await _tapMapPoint(tester, data, point + const Offset(6, 6));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('record_delete')), findsOneWidget);
    });

    testWidgets('같은 구역·좌우·글자의 통증은 중복으로 막는다', (tester) async {
      await openPage(tester);
      final first = await addPainPin(
        tester,
        _interiorPoint(front, 'quad', BodySide.left),
        '무릎',
      );
      final far = _farInteriorPoint(front, 'quad', BodySide.left, first);
      await _tapMapPoint(tester, data, far);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_type_pain')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('record_title')),
        ' 무릎 ',
      );
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('record_error')), findsOneWidget);
      expect(find.textContaining('이미 같은 기록'), findsOneWidget);
      // 글자가 다르면 추가된다
      await tester.enterText(find.byKey(const ValueKey('record_title')), '발목');
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      expect(find.text('이번에 추가한 기록 1개'), findsOneWidget);
    });

    testWidgets('통증 글자는 필수이고 숫자·기호만으로는 추가되지 않는다', (tester) async {
      await openPage(tester);
      await _tapMapPoint(
        tester,
        data,
        _interiorPoint(front, 'quad', BodySide.left),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_type_pain')));
      await tester.pumpAndSettle();
      for (final text in ['', '5', '...', ' - ']) {
        await tester.enterText(
          find.byKey(const ValueKey('record_title')),
          text,
        );
        await tester.tap(find.byKey(const ValueKey('record_submit')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('record_error')),
          findsOneWidget,
          reason: '"$text"',
        );
        expect(find.textContaining('이번에 추가한 기록'), findsNothing);
      }
      // 한 글자 위치어(목, 등)도 쓸 수 있다
      await tester.enterText(find.byKey(const ValueKey('record_title')), '목');
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      expect(find.text('이번에 추가한 기록 1개'), findsOneWidget);
    });

    testWidgets('구역 밖의 몸을 누르면 기타 부위로 점을 찍는다', (tester) async {
      final service = await openPage(tester);
      await _tapMapPoint(tester, data, const Offset(30, 30));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('record_sheet_title')))
            .data,
        '아픈 곳 · 기타 부위',
      );
      expect(find.byKey(const ValueKey('record_type_exercise')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('record_chip_목')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('저장하기'));
      await tester.pumpAndSettle();
      final record = service.saved.single;
      expect(record.bodyPartId, 'other');
      expect(record.bodyPartLabel, '기타 부위');
      expect(record.pin, isNotNull);
      expect(record.exerciseName, '목');
    });

    testWidgets('가동성은 검사 칩과 결과(○△×)를 점과 함께 저장한다', (tester) async {
      final service = await openPage(tester);
      await _tapMapPoint(
        tester,
        data,
        _interiorPoint(front, 'quad', BodySide.right),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_type_mobility')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('record_sheet_title')))
            .data,
        '가동성 · 대퇴사두',
      );
      await tester.tap(find.byKey(const ValueKey('record_chip_토마스 테스트')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('record_mobility_mild')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('저장하기'));
      await tester.pumpAndSettle();
      final record = service.saved.single;
      expect(record.recordType, AnatomyRecordType.mobility);
      expect(record.exerciseName, '토마스 테스트');
      expect(record.mobilityResult, MobilityResult.mild);
      expect(record.bodySide, BodySide.right);
      expect(record.pin, isNotNull);
    });

    testWidgets('결과를 다시 누르면 선택이 풀린다', (tester) async {
      await openPage(tester);
      await _tapMapPoint(
        tester,
        data,
        _interiorPoint(front, 'quad', BodySide.right),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_type_mobility')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_mobility_severe')));
      await tester.pump();
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('record_mobility_severe')),
            )
            .selected,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('record_mobility_severe')));
      await tester.pump();
      expect(
        tester
            .widget<ChoiceChip>(
              find.byKey(const ValueKey('record_mobility_severe')),
            )
            .selected,
        isFalse,
      );
    });

    testWidgets('주의도 점으로 찍히고 글자가 필수다', (tester) async {
      await openPage(tester);
      await _tapMapPoint(
        tester,
        data,
        _interiorPoint(front, 'delt_side', BodySide.right),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_type_caution')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('record_error')), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('record_title')),
        '머리 위로 들 때 조심',
      );
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();
      final canvas = tester.widget<BodyMapCanvas>(find.byType(BodyMapCanvas));
      expect(canvas.records.single.recordType, AnatomyRecordType.caution);
      expect(anatomyPinSymbol(canvas.records.single), '!');
      expect(canvas.records.single.pin, isNotNull);
    });

    testWidgets('내가 추가한 위치 칩은 서버 저장소에 p: 키로 저장된다', (tester) async {
      final store = _FakeExerciseStore();
      await openPage(tester, store: store);
      await _tapMapPoint(
        tester,
        data,
        _interiorPoint(front, 'quad', BodySide.left),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_type_pain')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_chip_add')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('record_chip_input')),
        'L.knee',
      );
      await tester.tap(find.byKey(const ValueKey('record_chip_input_done')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('record_title')))
            .controller!
            .text,
        'L.knee',
      );
      expect(store.saved['p:quad'], ['L.knee']);
      expect(find.byKey(const ValueKey('record_chip_L.knee')), findsOneWidget);
    });

    testWidgets('확인 단계에서 점을 누르면 적어 둔 내용이 보인다', (tester) async {
      await openPage(tester);
      final point = await addPainPin(
        tester,
        _interiorPoint(front, 'quad', BodySide.left),
        '무릎 안쪽 당김',
        memo: '내려갈 때만',
      );
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('다음'));
        await tester.pumpAndSettle();
      }
      expect(find.byKey(const ValueKey('confirm_map')), findsOneWidget);
      await _tapMapPoint(tester, data, point);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pin_details')), findsOneWidget);
      expect(find.text('무릎 안쪽 당김'), findsWidgets);
      expect(find.text('내려갈 때만'), findsWidgets);
      expect(find.textContaining('불편 정도'), findsOneWidget);
    });

    testWidgets('부위 목록으로 만든 통증(점 없음)은 구역을 칠하고 좌우를 고른다', (tester) async {
      await openPage(tester);
      await tester.tap(find.byKey(const ValueKey('part_list_tile')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('대퇴사두').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_type_pain')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('record_side_both')), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('record_title')), '무릎');
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();
      final canvas = tester.widget<BodyMapCanvas>(find.byType(BodyMapCanvas));
      expect(canvas.records.single.pin, isNull);
      final zone = front.zones.firstWhere((z) => z.part == 'quad');
      expect(anatomyMarksFor(zone, canvas.records), [AnatomyMark.pain]);
    });

    final oldDate = DateTime.now().subtract(const Duration(days: 7));
    List<AnatomyLogRecord> oldRecords() => [
      _histRecord(
        lesson: 'old-1',
        date: oldDate.subtract(const Duration(days: 7)),
        sets: const [AnatomySet(weightKg: 50, reps: 10)],
      ),
      _histRecord(
        lesson: 'old-2',
        date: oldDate,
        sets: const [
          AnatomySet(weightKg: 60, reps: 10),
          AnatomySet(weightKg: 60, reps: 10),
          AnatomySet(weightKg: 60, reps: 10),
        ],
      ),
      _histRecord(
        lesson: 'old-2',
        date: oldDate,
        exercise: '불가리안 스플릿 스쿼트',
        sets: const [AnatomySet(weightKg: 10, reps: 8)],
        related: const ['glute', 'hamstring'],
      ),
    ];

    testWidgets('이력 저장소가 없으면 이력 버튼·최근 칩이 없다', (tester) async {
      await openPage(tester);
      expect(
        find.byKey(const ValueKey('anatomy_history_button')),
        findsNothing,
      );
      await tapZone(tester, front, 'quad', BodySide.left);
      expect(find.byKey(const ValueKey('record_recent_스쿼트')), findsNothing);
    });

    testWidgets('입력 창에 최근 운동이 뜨고 고르면 지난번 기록과 같게 입력할 수 있다', (tester) async {
      final store = _FakeHistoryStore(oldRecords());
      await openPage(tester, historyStore: store);
      expect(store.calls, 1);
      await tapZone(tester, front, 'quad', BodySide.left);
      expect(find.byKey(const ValueKey('record_recent_스쿼트')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('record_recent_스쿼트')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('record_last_session')), findsOneWidget);
      expect(find.textContaining('3 X 60kg | 30회'), findsOneWidget);
      // 기본은 12회 한 줄, 같게 입력하면 지난번 3세트가 채워진다
      expect(find.byKey(const ValueKey('set_weight_1')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('record_copy_last')));
      await tester.pumpAndSettle();
      for (final i in [0, 1, 2]) {
        expect(
          tester
              .widget<TextField>(find.byKey(ValueKey('set_weight_$i')))
              .controller!
              .text,
          '60',
        );
        expect(
          tester
              .widget<TextField>(find.byKey(ValueKey('set_reps_$i')))
              .controller!
              .text,
          '10',
        );
      }
    });

    testWidgets('지난번 기록의 추이 버튼으로 추이 화면을 연다', (tester) async {
      await openPage(tester, historyStore: _FakeHistoryStore(oldRecords()));
      await tapZone(tester, front, 'quad', BodySide.left);
      await tester.tap(find.byKey(const ValueKey('record_recent_스쿼트')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_open_trend')));
      await tester.pumpAndSettle();
      expect(find.text('스쿼트 추이'), findsOneWidget);
      expect(find.byKey(const ValueKey('trend_session_old-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('trend_session_old-2')), findsOneWidget);
    });

    testWidgets('내 운동은 지난번 선택한 보조 부위를 다시 불러온다', (tester) async {
      await openPage(tester, historyStore: _FakeHistoryStore(oldRecords()));
      await tapZone(tester, front, 'quad', BodySide.left);
      await tester.tap(
        find.byKey(const ValueKey('record_recent_불가리안 스플릿 스쿼트')),
      );
      await tester.pumpAndSettle();
      for (final id in ['glute', 'hamstring']) {
        expect(
          tester
              .widget<FilterChip>(find.byKey(ValueKey('record_related_$id')))
              .selected,
          isTrue,
          reason: id,
        );
      }
    });

    testWidgets('이번 레슨에 방금 넣은 운동도 지난번 계산에서는 빠지고 최근에는 보인다', (tester) async {
      await openPage(tester, historyStore: _FakeHistoryStore(const []));
      await tapZone(tester, front, 'quad', BodySide.left);
      await addExercise(tester, '스쿼트', weight: '40', reps: '10');
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();
      await tapZone(tester, front, 'quad', BodySide.left);
      // 이번 레슨 기록은 최근에는 나오지만, 지난번 줄에는 쓰지 않는다
      expect(find.byKey(const ValueKey('record_recent_스쿼트')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('record_recent_스쿼트')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('record_last_session')), findsNothing);
    });

    testWidgets('머리말 이력 버튼으로 이력 화면을 열고 이번 레슨 기록도 포함한다', (tester) async {
      await openPage(tester, historyStore: _FakeHistoryStore(oldRecords()));
      await tapZone(tester, front, 'quad', BodySide.left);
      await addExercise(tester, '런지', weight: '20', reps: '10');
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('anatomy_history_button')));
      await tester.pumpAndSettle();
      expect(find.text('김회원 님 변화 보기'), findsOneWidget);
      expect(find.byKey(const ValueKey('exercise_row_런지')), findsOneWidget);
      expect(find.byKey(const ValueKey('exercise_row_스쿼트')), findsOneWidget);
    });

    testWidgets('이력을 못 불러와도 기록은 계속 할 수 있다', (tester) async {
      await openPage(tester, historyStore: _ThrowingHistoryStore());
      await tapZone(tester, front, 'quad', BodySide.left);
      await addExercise(tester, '스쿼트');
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();
      expect(find.text('기록 1개'), findsOneWidget);
    });

    testWidgets('기록이 없으면 다음으로 넘어갈 수 없다', (tester) async {
      await openPage(tester);
      final next = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, '다음'),
      );
      expect(next.onPressed, isNull);
    });

    testWidgets('회원 성별을 알면 바디 기준을 고르지 않고 그 몸으로 저장한다', (tester) async {
      final service = await openPage(tester, memberGender: 'female');
      expect(find.text('바디 기준'), findsNothing);
      final female = data.sceneFor(BodyGender.female, BodyView.front);
      await tapZone(tester, female, 'abs', BodySide.center);
      await tester.tap(find.byKey(const ValueKey('record_option_크런치')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('저장하기'));
      await tester.pumpAndSettle();
      expect(service.saved.single.bodyGender, BodyGender.female);
      expect(service.saved.single.bodySide, BodySide.center);
    });

    testWidgets('회원 성별을 모르면 바디 기준을 고르게 한다', (tester) async {
      await openPage(tester);
      expect(find.text('바디 기준'), findsOneWidget);
      expect(find.text('미지정'), findsOneWidget);
    });

    testWidgets('목록에 없는 운동은 내 운동으로 저장하고 다음에 보여준다', (tester) async {
      final store = _FakeExerciseStore();
      await openPage(tester, store: store);
      await tapZone(tester, front, 'delt_side', BodySide.right);
      await tester.enterText(
        find.byKey(const ValueKey('record_search')),
        '아쿠아백 로테이션',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('record_add_custom')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('set_reps_0')), '10');
      await tester.tap(find.byKey(const ValueKey('record_submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('record_finish')));
      await tester.pumpAndSettle();
      expect(store.saved['a:delt_side'], ['아쿠아백 로테이션']);

      await tapZone(tester, front, 'delt_side', BodySide.left);
      expect(
        find.byKey(const ValueKey('record_option_아쿠아백 로테이션')),
        findsOneWidget,
      );
    });

    testWidgets('연달아 추가한 기록은 창을 내려도 잃지 않는다', (tester) async {
      await openPage(tester);
      await tapZone(tester, front, 'delt_side', BodySide.right);
      await addExercise(tester, '사이드 레터럴 레이즈');
      await tester.tapAt(const Offset(10, 10)); // 완료 없이 창 닫기
      await tester.pumpAndSettle();
      expect(find.text('기록 1개'), findsOneWidget);
    });

    testWidgets('머리말은 공통 그라데이션 머리말이고 뒤로가기로 닫힌다', (tester) async {
      await openPage(tester);
      expect(find.text('김회원 님 아나토미 레슨일지'), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('열기'), findsOneWidget);
    });
  });
}

class _FakeExerciseStore implements AnatomyExerciseStore {
  Map<String, List<String>> saved = <String, List<String>>{};

  @override
  Future<Map<String, List<String>>> load() async => saved;

  @override
  Future<void> save(Map<String, List<String>> exercises) async {
    saved = exercises;
  }
}
