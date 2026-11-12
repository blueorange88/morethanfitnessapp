import 'package:cloud_firestore/cloud_firestore.dart';

import 'body_part.dart';

enum BodyGender { male, female, unspecified }

enum BodySide { left, right, center, both }

/// 회원카드의 성별 값을 바디 기준으로 바꾼다. 알 수 없으면 미지정.
BodyGender bodyGenderFromMemberValue(String? raw) {
  switch ((raw ?? '').trim().toLowerCase()) {
    case 'male':
    case 'm':
    case '남':
    case '남성':
    case '남자':
      return BodyGender.male;
    case 'female':
    case 'f':
    case '여':
    case '여성':
    case '여자':
      return BodyGender.female;
  }
  return BodyGender.unspecified;
}

enum AnatomyRecordType { exercise, pain, caution, mobility }

enum BodyView { front, back }

/// 바디맵에서 찍은 점의 위치. 좌표는 바디맵 viewBox(595.3 x 841.9) 기준이고,
/// 해당 기록의 `bodyGender`·`bodyView` 그림에서만 맞는다.
class AnatomyPin {
  const AnatomyPin({required this.x, required this.y});

  static const double maxX = 700;
  static const double maxY = 900;

  final double x;
  final double y;

  Map<String, dynamic> toMap() => <String, dynamic>{'x': x, 'y': y};

  /// 범위를 벗어나거나 읽을 수 없는 값은 null.
  static AnatomyPin? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final x = raw['x'];
    final y = raw['y'];
    if (x is! num || y is! num) return null;
    final px = x.toDouble();
    final py = y.toDouble();
    if (px < 0 || px > maxX || py < 0 || py > maxY) return null;
    return AnatomyPin(x: px, y: py);
  }

  @override
  bool operator ==(Object other) =>
      other is AnatomyPin && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// 가동성 검사 결과. ○ 정상, △ 보상(다른 곳을 써서 움직임), × 제한(움직임이 막힘).
enum MobilityResult { normal, mild, severe }

/// 운동 한 세트. [weightKg] 0 은 맨몸(무게 없음).
class AnatomySet {
  const AnatomySet({
    required this.weightKg,
    required this.reps,
    this.assist = 0,
  });

  static const int maxSets = 30;
  static const double maxWeightKg = 1000;
  static const int maxReps = 999;
  static const int maxAssist = 99;

  final double weightKg;

  /// 혼자 한 횟수.
  final int reps;

  /// 트레이너가 도와서 한 횟수(선택). 볼륨·추정 1RM 계산에는 넣지 않는다.
  final int assist;

  Map<String, dynamic> toMap() => <String, dynamic>{
    'w': weightKg,
    'r': reps,
    if (assist > 0) 'a': assist,
  };

  /// 범위를 벗어나거나 읽을 수 없는 값은 null.
  static AnatomySet? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final w = raw['w'];
    final r = raw['r'];
    if (w is! num || r is! num) return null;
    final weight = w.toDouble();
    final reps = r.toInt();
    if (weight < 0 || weight > maxWeightKg || reps < 0 || reps > maxReps) {
      return null;
    }
    final a = raw['a'];
    final assist = a is num ? a.toInt() : 0;
    return AnatomySet(
      weightKg: weight,
      reps: reps,
      assist: assist < 0 || assist > maxAssist ? 0 : assist,
    );
  }

  /// 무게 × 횟수(kg).
  double get volumeKg => weightKg * reps;

  /// Epley 추정 1RM. 무게가 없거나 12회를 넘으면 신뢰하기 어려워 null.
  double? get estimatedOneRepMaxKg {
    if (weightKg <= 0 || reps <= 0 || reps > 12) return null;
    return weightKg * (1 + reps / 30);
  }

  @override
  bool operator ==(Object other) =>
      other is AnatomySet &&
      other.weightKg == weightKg &&
      other.reps == reps &&
      other.assist == assist;

  @override
  int get hashCode => Object.hash(weightKg, reps, assist);
}

/// 세트 목록 요약. 무게가 모두 같으면 '3 X 8kg | 36회', 맨몸이면 '3세트 | 36회',
/// 무게가 섞여 있으면 '3세트 | 최대 10kg | 36회'.
String anatomySetsSummary(List<AnatomySet> sets) {
  if (sets.isEmpty) return '';
  final totalReps = sets.fold<int>(0, (total, s) => total + s.reps);
  final totalAssist = sets.fold<int>(0, (total, s) => total + s.assist);
  // 보조가 있으면 `36(+4)회` 처럼 혼자 한 횟수 뒤에 붙인다.
  final repsText = totalAssist > 0 ? '$totalReps(+$totalAssist)' : '$totalReps';
  final weights = sets.map((s) => s.weightKg).toSet();
  String kg(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  if (weights.length == 1) {
    final w = weights.first;
    return w <= 0
        ? '${sets.length}세트 | $repsText회'
        : '${sets.length} X ${kg(w)}kg | $repsText회';
  }
  final maxWeight = weights.reduce((a, b) => a > b ? a : b);
  return '${sets.length}세트 | 최대 ${kg(maxWeight)}kg | $repsText회';
}

class AnatomyLogRecord {
  const AnatomyLogRecord({
    required this.anatomyLogId,
    required this.trainerId,
    required this.memberId,
    required this.lessonLogId,
    required this.scheduleDocId,
    required this.recordedAt,
    required this.bodyGender,
    required this.bodyView,
    required this.bodySide,
    required this.bodyPartId,
    required this.bodyPartLabel,
    required this.recordType,
    required this.exerciseName,
    required this.painLevel,
    required this.memo,
    this.sets = const <AnatomySet>[],
    this.relatedPartIds = const <String>[],
    this.pin,
    this.mobilityResult,
    required this.createdAt,
    required this.updatedAt,
  });

  final String anatomyLogId;
  final String trainerId;
  final String memberId;
  final String lessonLogId;
  final String scheduleDocId;
  final DateTime recordedAt;
  final BodyGender bodyGender;
  final BodyView bodyView;
  final BodySide bodySide;
  final String bodyPartId;
  final String bodyPartLabel;
  final AnatomyRecordType recordType;
  final String exerciseName;
  final int painLevel;
  final String memo;

  /// 운동 세트(무게·횟수). 통증·주의·가동성 기록은 비어 있다.
  final List<AnatomySet> sets;

  /// 이번 수업에서 [bodyPartId](목표 부위)와 함께 쓴 보조 부위 id. 목표 부위는 강사가
  /// 수업마다 정하고, 같은 운동의 기본 사용 부위 정보는 따로 유지된다.
  final List<String> relatedPartIds;

  /// 통증·주의·가동성 기록의 점 위치. 없으면(예전 기록·부위 목록에서 만든 기록)
  /// 부위 구역 전체에 표시한다.
  final AnatomyPin? pin;

  /// 가동성 기록의 검사 결과(선택).
  final MobilityResult? mobilityResult;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toFirestore() => <String, dynamic>{
    'anatomyLogId': anatomyLogId,
    'trainerId': trainerId,
    'memberId': memberId,
    'lessonLogId': lessonLogId,
    'scheduleDocId': scheduleDocId,
    'recordedAt': Timestamp.fromDate(recordedAt),
    'bodyGender': bodyGender.name,
    'bodyView': bodyView.name,
    'bodySide': bodySide.name,
    'bodyPartId': bodyPartId,
    'bodyPartLabel': bodyPartLabel,
    'recordType': recordType.name,
    'exerciseName': exerciseName,
    'painLevel': painLevel.clamp(0, 10),
    'memo': memo,
    if (sets.isNotEmpty) 'sets': sets.map((s) => s.toMap()).toList(),
    if (relatedPartIds.isNotEmpty) 'relatedPartIds': relatedPartIds,
    if (pin != null) 'pin': pin!.toMap(),
    if (mobilityResult != null) 'mobilityResult': mobilityResult!.name,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  factory AnatomyLogRecord.fromFirestore(Map<String, dynamic> map) {
    return AnatomyLogRecord(
      anatomyLogId: _string(map['anatomyLogId'] ?? map['id']),
      trainerId: _string(map['trainerId']),
      memberId: _string(map['memberId']),
      lessonLogId: _string(map['lessonLogId']),
      scheduleDocId: _string(map['scheduleDocId']),
      recordedAt: _date(map['recordedAt']),
      bodyGender: _enumByName(
        BodyGender.values,
        map['bodyGender'],
        BodyGender.unspecified,
      ),
      bodyView: _enumByName(BodyView.values, map['bodyView'], BodyView.front),
      bodySide: _enumByName(BodySide.values, map['bodySide'], BodySide.both),
      bodyPartId: _string(map['bodyPartId']),
      bodyPartLabel: _currentPartLabel(
        _string(map['bodyPartId']),
        _string(map['bodyPartLabel']),
      ),
      recordType: _enumByName(
        AnatomyRecordType.values,
        map['recordType'],
        AnatomyRecordType.exercise,
      ),
      exerciseName: _string(map['exerciseName']),
      painLevel: _clampPain(_int(map['painLevel'])),
      memo: _string(map['memo']),
      sets: _sets(map['sets']),
      relatedPartIds: _ids(map['relatedPartIds']),
      pin: AnatomyPin.fromMap(map['pin']),
      mobilityResult: _mobility(map['mobilityResult']),
      createdAt: _date(map['createdAt']),
      updatedAt: _date(map['updatedAt']),
    );
  }

  AnatomyLogRecord copyWith({
    String? anatomyLogId,
    String? trainerId,
    String? memberId,
    String? lessonLogId,
    String? scheduleDocId,
    DateTime? recordedAt,
    BodyGender? bodyGender,
    BodyView? bodyView,
    BodySide? bodySide,
    String? bodyPartId,
    String? bodyPartLabel,
    AnatomyRecordType? recordType,
    String? exerciseName,
    int? painLevel,
    String? memo,
    List<AnatomySet>? sets,
    List<String>? relatedPartIds,
    AnatomyPin? pin,
    MobilityResult? mobilityResult,
    bool clearMobilityResult = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AnatomyLogRecord(
      anatomyLogId: anatomyLogId ?? this.anatomyLogId,
      trainerId: trainerId ?? this.trainerId,
      memberId: memberId ?? this.memberId,
      lessonLogId: lessonLogId ?? this.lessonLogId,
      scheduleDocId: scheduleDocId ?? this.scheduleDocId,
      recordedAt: recordedAt ?? this.recordedAt,
      bodyGender: bodyGender ?? this.bodyGender,
      bodyView: bodyView ?? this.bodyView,
      bodySide: bodySide ?? this.bodySide,
      bodyPartId: bodyPartId ?? this.bodyPartId,
      bodyPartLabel: bodyPartLabel ?? this.bodyPartLabel,
      recordType: recordType ?? this.recordType,
      exerciseName: exerciseName ?? this.exerciseName,
      painLevel: _clampPain(painLevel ?? this.painLevel),
      memo: memo ?? this.memo,
      sets: sets ?? this.sets,
      relatedPartIds: relatedPartIds ?? this.relatedPartIds,
      pin: pin ?? this.pin,
      mobilityResult:
          clearMobilityResult ? null : (mobilityResult ?? this.mobilityResult),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static const int maxRelatedParts = 8;

  static MobilityResult? _mobility(dynamic value) {
    final name = _string(value);
    for (final result in MobilityResult.values) {
      if (result.name == name) return result;
    }
    return null;
  }

  static List<String> _ids(dynamic value) {
    if (value is! List) return const <String>[];
    final seen = <String>{};
    final result = <String>[];
    for (final item in value) {
      final id = _string(item);
      if (id.isEmpty || id.length > 40 || !seen.add(id)) continue;
      result.add(id);
      if (result.length >= maxRelatedParts) break;
    }
    return List<String>.unmodifiable(result);
  }

  static List<AnatomySet> _sets(dynamic value) {
    if (value is! List) return const <AnatomySet>[];
    return value
        .map(AnatomySet.fromMap)
        .whereType<AnatomySet>()
        .take(AnatomySet.maxSets)
        .toList(growable: false);
  }

  static String _string(dynamic value) => (value ?? '').toString().trim();

  /// 저장된 부위 이름 대신 현재 부위 이름을 쓴다(이름을 바꿔도 옛 기록이 같이 바뀐다).
  /// 목록에 없는 id 는 저장된 이름을 그대로 쓴다.
  static String _currentPartLabel(String id, String stored) {
    for (final part in kBodyParts) {
      if (part.id == id) return part.label;
    }
    return stored;
  }

  static int _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(_string(value)) ?? 0;
  }

  static int _clampPain(int value) => value < 0 ? 0 : (value > 10 ? 10 : value);

  static DateTime _date(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  static T _enumByName<T extends Enum>(
    List<T> values,
    dynamic raw,
    T fallback,
  ) {
    final name = _string(raw);
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}

class AnatomyRecordCollection {
  const AnatomyRecordCollection._();

  static List<AnatomyLogRecord> decode(dynamic raw) {
    if (raw is! List) return const <AnatomyLogRecord>[];
    return raw
        .whereType<Map>()
        .map(
          (value) =>
              AnatomyLogRecord.fromFirestore(Map<String, dynamic>.from(value)),
        )
        .toList();
  }

  static List<Map<String, dynamic>> encode(List<AnatomyLogRecord> records) =>
      records.map((record) => record.toFirestore()).toList();

  static List<AnatomyLogRecord> sorted(List<AnatomyLogRecord> records) {
    final next = List<AnatomyLogRecord>.from(records);
    next.sort((a, b) {
      final recordedOrder = b.recordedAt.compareTo(a.recordedAt);
      if (recordedOrder != 0) return recordedOrder;
      final createdOrder = b.createdAt.compareTo(a.createdAt);
      if (createdOrder != 0) return createdOrder;
      return a.anatomyLogId.compareTo(b.anatomyLogId);
    });
    return next;
  }

  static List<AnatomyLogRecord> upsert(
    List<AnatomyLogRecord> records,
    AnatomyLogRecord updated,
  ) {
    final next = List<AnatomyLogRecord>.from(records);
    final index = next.indexWhere(
      (record) => record.anatomyLogId == updated.anatomyLogId,
    );
    if (index < 0) {
      next.add(updated);
    } else {
      next[index] = updated;
    }
    return next;
  }

  static List<AnatomyLogRecord> remove(
    List<AnatomyLogRecord> records,
    String anatomyLogId,
  ) => records.where((record) => record.anatomyLogId != anatomyLogId).toList();
}
