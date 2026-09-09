class PersonalScheduleRecord {
  const PersonalScheduleRecord({
    required this.scheduleId,
    required this.trainerId,
    required this.workspaceType,
    required this.schemaVersion,
    required this.startAt,
    required this.endAt,
    required this.dateKey,
    required this.slotKey,
    required this.name,
    required this.type,
    required this.status,
    this.memberId,
    this.phone,
    this.remainingSessions,
    this.totalSessions,
    this.memo = '',
    this.typeColorHex = '',
    this.createdAt,
    this.updatedAt,
    this.lessonConfirmed = false,
  });

  final String scheduleId;
  final String trainerId;
  final String workspaceType;
  final int schemaVersion;
  final DateTime startAt;
  final DateTime endAt;
  final String dateKey;
  final String slotKey;
  final String name;
  final String type;
  final String status;
  final String? memberId;
  final String? phone;
  final int? remainingSessions;
  final int? totalSessions;
  final String memo;
  final String typeColorHex;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool lessonConfirmed;

  PersonalScheduleDraft toDraft({DateTime? startAt, DateTime? endAt}) {
    return PersonalScheduleDraft(
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      name: name,
      type: type,
      memberId: memberId,
      phone: phone,
      remainingSessions: remainingSessions,
      totalSessions: totalSessions,
      memo: memo,
      typeColorHex: typeColorHex,
      status: status,
    );
  }
}

class PersonalScheduleDraft {
  const PersonalScheduleDraft({
    required this.startAt,
    required this.endAt,
    required this.name,
    required this.type,
    this.memberId,
    this.phone,
    this.remainingSessions,
    this.totalSessions,
    this.memo = '',
    this.typeColorHex = '',
    this.status = 'scheduled',
  });

  final DateTime startAt;
  final DateTime endAt;
  final String name;
  final String type;
  final String? memberId;
  final String? phone;
  final int? remainingSessions;
  final int? totalSessions;
  final String memo;
  final String typeColorHex;
  final String status;
}

class PersonalScheduleDocumentIdentity {
  const PersonalScheduleDocumentIdentity._();

  static String dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String slotKey(DateTime value) => '${dateKey(value)}T'
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
