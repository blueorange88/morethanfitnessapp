import 'package:cloud_firestore/cloud_firestore.dart';

enum BodyGender { male, female, unspecified }

enum BodySide { left, right, center, both }

enum AnatomyRecordType { exercise, pain, caution, mobility }

enum BodyView { front, back }

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
      bodyView: _enumByName(
        BodyView.values,
        map['bodyView'],
        BodyView.front,
      ),
      bodySide: _enumByName(
        BodySide.values,
        map['bodySide'],
        BodySide.both,
      ),
      bodyPartId: _string(map['bodyPartId']),
      bodyPartLabel: _string(map['bodyPartLabel']),
      recordType: _enumByName(
        AnatomyRecordType.values,
        map['recordType'],
        AnatomyRecordType.exercise,
      ),
      exerciseName: _string(map['exerciseName']),
      painLevel: _clampPain(_int(map['painLevel'])),
      memo: _string(map['memo']),
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _string(dynamic value) => (value ?? '').toString().trim();

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
        .map((value) => AnatomyLogRecord.fromFirestore(
              Map<String, dynamic>.from(value),
            ))
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
  ) =>
      records.where((record) => record.anatomyLogId != anatomyLogId).toList();
}
