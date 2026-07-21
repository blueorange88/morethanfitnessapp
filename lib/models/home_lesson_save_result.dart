class HomeLessonSaveResult {
  final bool success;
  final bool isLinkedMember;
  final String? targetDocId;
  final DateTime? targetStartAt;
  final bool isMultiDay;
  final int createdScheduleCount;
  final String failureMessage;
  final String errorCode;

  const HomeLessonSaveResult({
    required this.success,
    required this.isLinkedMember,
    this.targetDocId,
    this.targetStartAt,
    this.isMultiDay = false,
    this.createdScheduleCount = 0,
    this.failureMessage = '',
    this.errorCode = 'none',
  });

  const HomeLessonSaveResult.failed({
    this.failureMessage = '레슨일정을 저장하지 못했어요.',
    this.errorCode = 'unknown',
  })  : success = false,
        isLinkedMember = false,
        targetDocId = null,
        targetStartAt = null,
        isMultiDay = false,
        createdScheduleCount = 0;
}
