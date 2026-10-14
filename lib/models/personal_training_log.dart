class PersonalTrainingLogRecord {
  const PersonalTrainingLogRecord({
    required this.lessonLogId,
    required this.trainerId,
    required this.workspaceType,
    required this.schemaVersion,
    required this.memberId,
    required this.lessonDate,
    required this.startAt,
    required this.endAt,
    required this.lessonType,
    required this.status,
    required this.source,
    required this.memo,
    this.scheduleDocId,
    this.details,
    this.deductionApplied = false,
    this.createdAt,
    this.updatedAt,
  });

  final String lessonLogId;
  final String trainerId;
  final String workspaceType;
  final int schemaVersion;
  final String memberId;
  final String? scheduleDocId;
  final DateTime lessonDate;
  final DateTime startAt;
  final DateTime endAt;
  final String lessonType;
  final String status;
  final String source;
  final String memo;
  // 세부 기록(체크·특이사항·운동 구성). 형식은 personal_training_log_details.dart 참고.
  final Map<String, dynamic>? details;
  final bool deductionApplied;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isDraft => status == 'draft';
  bool get isCancelled => status == 'confirm_cancelled';
  bool get isFinalized => const {
    'completed',
    'no_show_deducted',
    'no_show_not_deducted',
    'service',
  }.contains(status);
}

class PersonalTrainingLogDraft {
  const PersonalTrainingLogDraft({
    required this.memberId,
    required this.lessonDate,
    required this.startAt,
    required this.endAt,
    required this.lessonType,
    this.scheduleDocId,
    this.memo = '',
    this.source = 'formal',
    this.details,
  });

  final String memberId;
  final String? scheduleDocId;
  final DateTime lessonDate;
  final DateTime startAt;
  final DateTime endAt;
  final String lessonType;
  final String memo;
  final String source;
  final Map<String, dynamic>? details;

  PersonalTrainingLogDraft copyWith({
    String? scheduleDocId,
    bool clearSchedule = false,
    DateTime? lessonDate,
    DateTime? startAt,
    DateTime? endAt,
    String? lessonType,
    String? memo,
    Map<String, dynamic>? details,
  }) {
    return PersonalTrainingLogDraft(
      memberId: memberId,
      scheduleDocId: clearSchedule ? null : scheduleDocId ?? this.scheduleDocId,
      lessonDate: lessonDate ?? this.lessonDate,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      lessonType: lessonType ?? this.lessonType,
      memo: memo ?? this.memo,
      source: source,
      details: details ?? this.details,
    );
  }
}

abstract final class PersonalTrainingLogStatus {
  static const draft = 'draft';
  static const completed = 'completed';
  static const noShowDeducted = 'no_show_deducted';
  static const noShowNotDeducted = 'no_show_not_deducted';
  static const service = 'service';
  static const confirmCancelled = 'confirm_cancelled';

  static const finalized = {
    completed,
    noShowDeducted,
    noShowNotDeducted,
    service,
  };
}
