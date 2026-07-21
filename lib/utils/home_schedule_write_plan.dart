enum HomeScheduleWriteAction {
  createOrUpdate,
  createOrUpdateMany,
  moveOrReplace,
}

HomeScheduleWriteAction resolveHomeScheduleWriteAction({
  required int deleteCount,
  required int writeCount,
}) {
  if (deleteCount > 0) return HomeScheduleWriteAction.moveOrReplace;
  if (writeCount > 1) return HomeScheduleWriteAction.createOrUpdateMany;
  return HomeScheduleWriteAction.createOrUpdate;
}

bool shouldUseSingleHomeScheduleEditCommit({
  required int selectedDayCount,
  required int deleteCount,
  required bool explicitMultiDaySelection,
}) {
  if (!explicitMultiDaySelection && selectedDayCount > 1) {
    return false;
  }
  final hasSingleAllowedTarget = selectedDayCount == 1;
  return hasSingleAllowedTarget && deleteCount <= 1;
}
