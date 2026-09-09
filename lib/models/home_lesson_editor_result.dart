class HomeLessonEditorInput {
  const HomeLessonEditorInput({
    required this.day,
    required this.time,
    required this.weekOffset,
    this.existingSession,
  });

  final String day;
  final String time;
  final int weekOffset;
  final Map<String, dynamic>? existingSession;

  bool get isEditMode => existingSession != null;

  bool get hasPersistedSchedule {
    final raw = existingSession;
    if (raw == null) return false;

    return (raw['actualDocumentId'] ?? raw['docId'] ?? '')
        .toString()
        .trim()
        .isNotEmpty;
  }

  Map<String, dynamic>? get safeExistingSession {
    final raw = existingSession;
    if (raw == null) return null;
    return Map<String, dynamic>.from(raw);
  }
}

class HomeLessonEditorResult {
  const HomeLessonEditorResult({
    required this.lessonTypes,
    required this.selectedLessonTypeId,
    this.savedSuccessfully = false,
    this.deletedSuccessfully = false,
    this.savedFromEditMode = false,
    this.savedIsLinkedMember = false,
    this.shouldOfferCustomerCard = false,
    this.createdScheduleCount = 0,
    this.savedMemberName,
    this.savedMemberPhone,
    this.savedScheduleDocId,
    this.snackMessage,
    this.editSessionId,
  });

  final List<Map<String, dynamic>> lessonTypes;
  final String selectedLessonTypeId;

  final bool savedSuccessfully;
  final bool deletedSuccessfully;
  final bool savedFromEditMode;
  final bool savedIsLinkedMember;
  final bool shouldOfferCustomerCard;
  final int createdScheduleCount;

  final String? savedMemberName;
  final String? savedMemberPhone;
  final String? savedScheduleDocId;
  final String? snackMessage;
  final String? editSessionId;
}
