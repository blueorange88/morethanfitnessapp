enum HomeScheduleTombstoneDecision {
  keep,
  confirmedDeleted,
  sourceStillExists,
}

bool shouldApplyHomeScheduleSnapshot({
  required int bindingId,
  required int currentBindingId,
  required int revision,
  required int latestRevision,
}) {
  return bindingId == currentBindingId && revision == latestRevision;
}

HomeScheduleTombstoneDecision resolveHomeScheduleTombstone({
  required bool isFromCache,
  required bool hasPendingWrites,
  required bool mutationInFlight,
  required bool sourcePresent,
}) {
  if (isFromCache || hasPendingWrites || mutationInFlight) {
    return HomeScheduleTombstoneDecision.keep;
  }

  return sourcePresent
      ? HomeScheduleTombstoneDecision.sourceStillExists
      : HomeScheduleTombstoneDecision.confirmedDeleted;
}
