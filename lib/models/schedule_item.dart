class ScheduleItem {
  final String docId;
  final DateTime startAt;
  final DateTime endAt;
  final String day;
  final String time;
  final String endTime;
  final String name;
  final String type;
  final bool attended;
  final String? memberId;
  final String? phone;
  final String? attendanceOverride;
  final String? totalSessions;
  final String? remainingSessions;
  final String? memo;
  final String? typeId;
  final String? typeColorHex;

  final int? doneSessions;

  final String? contractId;
  final String? contractNo;
  final bool? contractSigned;
  final String? lessonSyncSource;

  final Map<String, dynamic>? smartAlarmContext;
  final String? lastLessonLogSummary;
  final List<String>? lastLessonLogKeywords;
  final String? nextLessonReminderHint;

  final String? moreCareStatus;
  final DateTime? moreCareTemporaryUntil;
  final String? moreCareRequestId;

  const ScheduleItem({
    required this.docId,
    required this.startAt,
    required this.endAt,
    required this.day,
    required this.time,
    required this.endTime,
    required this.name,
    required this.type,
    required this.attended,
    this.memberId,
    this.phone,
    this.attendanceOverride,
    this.totalSessions,
    this.remainingSessions,
    this.memo,
    this.typeId,
    this.typeColorHex,
    this.doneSessions,
    this.contractId,
    this.contractNo,
    this.contractSigned,
    this.lessonSyncSource,
    this.smartAlarmContext,
    this.lastLessonLogSummary,
    this.lastLessonLogKeywords,
    this.nextLessonReminderHint,
    this.moreCareStatus,
    this.moreCareTemporaryUntil,
    this.moreCareRequestId,
  });

  ScheduleItem copyWith({
    String? docId,
    DateTime? startAt,
    DateTime? endAt,
    String? day,
    String? time,
    String? endTime,
    String? name,
    String? type,
    bool? attended,
    String? memberId,
    String? phone,
    String? attendanceOverride,
    String? totalSessions,
    String? remainingSessions,
    String? memo,
    String? typeId,
    String? typeColorHex,
    int? doneSessions,
    String? contractId,
    String? contractNo,
    bool? contractSigned,
    String? lessonSyncSource,
    Map<String, dynamic>? smartAlarmContext,
    String? lastLessonLogSummary,
    List<String>? lastLessonLogKeywords,
    String? nextLessonReminderHint,
    String? moreCareStatus,
    DateTime? moreCareTemporaryUntil,
    String? moreCareRequestId,
  }) {
    return ScheduleItem(
      docId: docId ?? this.docId,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      day: day ?? this.day,
      time: time ?? this.time,
      endTime: endTime ?? this.endTime,
      name: name ?? this.name,
      type: type ?? this.type,
      attended: attended ?? this.attended,
      memberId: memberId ?? this.memberId,
      phone: phone ?? this.phone,
      attendanceOverride: attendanceOverride ?? this.attendanceOverride,
      totalSessions: totalSessions ?? this.totalSessions,
      remainingSessions: remainingSessions ?? this.remainingSessions,
      memo: memo ?? this.memo,
      typeId: typeId ?? this.typeId,
      typeColorHex: typeColorHex ?? this.typeColorHex,
      doneSessions: doneSessions ?? this.doneSessions,
      contractId: contractId ?? this.contractId,
      contractNo: contractNo ?? this.contractNo,
      contractSigned: contractSigned ?? this.contractSigned,
      lessonSyncSource: lessonSyncSource ?? this.lessonSyncSource,
      smartAlarmContext: smartAlarmContext ?? this.smartAlarmContext,
      lastLessonLogSummary: lastLessonLogSummary ?? this.lastLessonLogSummary,
      lastLessonLogKeywords: lastLessonLogKeywords ?? this.lastLessonLogKeywords,
      nextLessonReminderHint:
      nextLessonReminderHint ?? this.nextLessonReminderHint,
      moreCareStatus: moreCareStatus ?? this.moreCareStatus,
      moreCareTemporaryUntil:
      moreCareTemporaryUntil ?? this.moreCareTemporaryUntil,
      moreCareRequestId: moreCareRequestId ?? this.moreCareRequestId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'docId': docId,
      'startAt': startAt,
      'endAt': endAt,
      'day': day,
      'time': time,
      'endTime': endTime,
      'name': name,
      'type': type,
      'attended': attended,
      if (memberId != null && memberId!.isNotEmpty) 'memberId': memberId,
      if (phone != null && phone!.isNotEmpty) 'phone': phone,
      if (attendanceOverride != null) 'attendanceOverride': attendanceOverride,
      if (totalSessions != null) 'totalSessions': totalSessions,
      if (remainingSessions != null) 'remainingSessions': remainingSessions,
      if (memo != null && memo!.isNotEmpty) 'memo': memo,
      if (typeId != null && typeId!.isNotEmpty) 'typeId': typeId,
      if (typeColorHex != null && typeColorHex!.isNotEmpty)
        'typeColorHex': typeColorHex,
      if (doneSessions != null) 'doneSessions': doneSessions,

      if (contractId != null && contractId!.isNotEmpty)
        'contractId': contractId,

      if (contractNo != null && contractNo!.isNotEmpty)
        'contractNo': contractNo,

      if (contractSigned != null)
        'contractSigned': contractSigned,

      if (lessonSyncSource != null && lessonSyncSource!.isNotEmpty)
        'lessonSyncSource': lessonSyncSource,

      if (smartAlarmContext != null && smartAlarmContext!.isNotEmpty)
        'smartAlarmContext': smartAlarmContext,

      if (lastLessonLogSummary != null && lastLessonLogSummary!.isNotEmpty)
        'lastLessonLogSummary': lastLessonLogSummary,

      if (lastLessonLogKeywords != null && lastLessonLogKeywords!.isNotEmpty)
        'lastLessonLogKeywords': lastLessonLogKeywords,

      if (nextLessonReminderHint != null && nextLessonReminderHint!.isNotEmpty)
        'nextLessonReminderHint': nextLessonReminderHint,
      if (moreCareStatus != null && moreCareStatus!.isNotEmpty)
        'moreCareStatus': moreCareStatus,

      if (moreCareTemporaryUntil != null)
        'moreCareTemporaryUntil': moreCareTemporaryUntil,

      if (moreCareRequestId != null && moreCareRequestId!.isNotEmpty)
        'moreCareRequestId': moreCareRequestId,
    };
  }

  static ScheduleItem? fromMap(
      Map<String, dynamic> raw, {
        required int defaultDurationMinutes,
      }) {
    final rawStartAt = raw['startAt'];
    if (rawStartAt is! DateTime) return null;

    final rawEndAt = raw['endAt'];
    final endAt = rawEndAt is DateTime
        ? rawEndAt
        : rawStartAt.add(Duration(minutes: defaultDurationMinutes));

    final day = (raw['day'] ?? '').toString().trim().isNotEmpty
        ? (raw['day'] ?? '').toString()
        : const ['월', '화', '수', '목', '금', '토', '일']
    [rawStartAt.weekday - 1];

    final time = (raw['time'] ?? '').toString().trim().isNotEmpty
        ? (raw['time'] ?? '').toString()
        : '${rawStartAt.hour.toString().padLeft(2, '0')}:${rawStartAt.minute.toString().padLeft(2, '0')}';

    final endTime = (raw['endTime'] ?? '').toString().trim().isNotEmpty
        ? (raw['endTime'] ?? '').toString()
        : '${endAt.hour.toString().padLeft(2, '0')}:${endAt.minute.toString().padLeft(2, '0')}';

    return ScheduleItem(
      docId: (raw['docId'] ?? '').toString(),
      startAt: rawStartAt,
      endAt: endAt,
      day: day,
      time: time,
      endTime: endTime,
      name: (raw['name'] ?? '').toString(),
      type: (raw['type'] ?? 'PT').toString(),
      attended: raw['attended'] == true,
      memberId: raw['memberId']?.toString(),
      phone: raw['phone']?.toString(),
      attendanceOverride: raw['attendanceOverride']?.toString(),
      totalSessions: raw['totalSessions']?.toString(),
      remainingSessions: raw['remainingSessions']?.toString(),
      memo: raw['memo']?.toString(),
      typeId: raw['typeId']?.toString(),
      typeColorHex: raw['typeColorHex']?.toString(),
      doneSessions: _intFromAny(
        raw['doneSessions'] ??
            raw['sessionSnapshotDoneAfter'] ??
            raw['sessionSnapshotDoneBefore'],
      ),
      contractId: raw['contractId']?.toString(),
      contractNo: raw['contractNo']?.toString(),
      contractSigned: raw['contractSigned'] == true ||
          raw['isContractSigned'] == true ||
          raw['finalSigned'] == true,
      lessonSyncSource: raw['lessonSyncSource']?.toString(),
      smartAlarmContext: raw['smartAlarmContext'] is Map
          ? Map<String, dynamic>.from(raw['smartAlarmContext'] as Map)
          : null,
      lastLessonLogSummary: raw['lastLessonLogSummary']?.toString(),
      lastLessonLogKeywords: raw['lastLessonLogKeywords'] is List
          ? (raw['lastLessonLogKeywords'] as List)
          .map((e) => e.toString())
          .toList()
          : null,
      nextLessonReminderHint: raw['nextLessonReminderHint']?.toString(),

      moreCareStatus: (
          raw['moreCareStatus'] ??
              (raw['moreCareSlot'] is Map
                  ? (raw['moreCareSlot'] as Map)['status']
                  : null) ??
              ''
      ).toString().trim(),

      moreCareTemporaryUntil: _dateTimeFromAny(
        raw['moreCareTemporaryUntil'] ??
            (raw['moreCareSlot'] is Map
                ? (raw['moreCareSlot'] as Map)['temporaryUntil']
                : null),
      ),

      moreCareRequestId: (
          raw['moreCareRequestId'] ??
              (raw['moreCareSlot'] is Map
                  ? (raw['moreCareSlot'] as Map)['requestId']
                  : null) ??
              ''
      ).toString().trim(),
    );
  }
}

int? _intFromAny(dynamic value) {
  if (value == null) return null;

  if (value is int) return value;
  if (value is num) return value.toInt();

  final text = value.toString().replaceAll(RegExp(r'[^0-9-]'), '');
  if (text.trim().isEmpty) return null;

  return int.tryParse(text);
}

DateTime? _dateTimeFromAny(dynamic value) {
  if (value == null) return null;

  if (value is DateTime) return value;

  try {
    final dynamic dynamicValue = value;

    final toDate = dynamicValue.toDate;

    if (toDate is Function) {
      final result = toDate();
      if (result is DateTime) return result;
    }
  } catch (_) {
    // Timestamp가 아니면 아래 문자열 파싱으로 넘어갑니다.
  }

  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }

  return null;
}