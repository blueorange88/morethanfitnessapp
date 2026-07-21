import 'package:flutter/widgets.dart';

import 'lesson_type_item.dart';

class HomeLessonSaveRequest {
  const HomeLessonSaveRequest({
    required this.isEditMode,
    required this.weekOffset,
    required this.originalDay,
    required this.originalTime,
    required this.selectedDays,
    required this.explicitMultiDaySelection,
    required this.editSessionId,
    required this.selectedDatesChangedCaller,
    required this.editableTime,
    required this.editableEndTime,
    required this.typedName,
    required this.lessonType,
    required this.sessionCountController,
    required this.existingSession,
    required this.memoController,
    this.selectedMemberId,
    this.selectedMemberPhone,
  });

  final bool isEditMode;
  final int weekOffset;
  final String originalDay;
  final String originalTime;
  final Set<String> selectedDays;
  final bool explicitMultiDaySelection;
  final String editSessionId;
  final String selectedDatesChangedCaller;
  final String editableTime;
  final String editableEndTime;
  final String typedName;
  final LessonTypeItem lessonType;
  final TextEditingController sessionCountController;
  final Map<String, dynamic>? existingSession;
  final TextEditingController memoController;
  final String? selectedMemberId;
  final String? selectedMemberPhone;
}
