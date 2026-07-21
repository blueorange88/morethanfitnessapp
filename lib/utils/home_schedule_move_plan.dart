class HomeScheduleMovePlan {
  const HomeScheduleMovePlan({
    required this.sourceDocId,
    required this.targetDocId,
    required this.dataDocId,
  });

  final String sourceDocId;
  final String targetDocId;
  final String dataDocId;

  bool get shouldDeleteSource =>
      sourceDocId.isNotEmpty && sourceDocId != targetDocId;

  bool get hasDataDocIdMismatch =>
      dataDocId.isNotEmpty && dataDocId != sourceDocId;

  static HomeScheduleMovePlan fromSnapshot({
    required String actualSourceDocId,
    required String dataDocId,
    required String targetDocId,
  }) {
    return HomeScheduleMovePlan(
      sourceDocId: actualSourceDocId.trim(),
      targetDocId: targetDocId.trim(),
      dataDocId: dataDocId.trim(),
    );
  }
}

enum HomeScheduleEditBranch { create, update, move, copyMany, replaceMany }

class HomeScheduleEditPlan {
  const HomeScheduleEditPlan({
    required this.sourceIsRetained,
    required this.branch,
    required this.deleteSource,
    required this.writeCount,
  });

  final bool sourceIsRetained;
  final HomeScheduleEditBranch branch;
  final bool deleteSource;
  final int writeCount;

  factory HomeScheduleEditPlan.resolve({
    required String sourceActualDocId,
    required Set<String> targetActualDocIds,
  }) {
    final source = sourceActualDocId.trim();
    final targets = targetActualDocIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    if (source.isEmpty) {
      return HomeScheduleEditPlan(
        sourceIsRetained: false,
        branch: HomeScheduleEditBranch.create,
        deleteSource: false,
        writeCount: targets.length,
      );
    }
    final retained = source.isNotEmpty && targets.contains(source);
    final multiple = targets.length > 1;
    return HomeScheduleEditPlan(
      sourceIsRetained: retained,
      branch: retained
          ? multiple
              ? HomeScheduleEditBranch.copyMany
              : HomeScheduleEditBranch.update
          : multiple
              ? HomeScheduleEditBranch.replaceMany
              : HomeScheduleEditBranch.move,
      deleteSource: !retained,
      writeCount: targets.length,
    );
  }
}

bool isHomeScheduleConflictCandidate({
  required String candidateDocId,
  required DateTime candidateStartAt,
  required DateTime candidateEndAt,
  required DateTime targetStartAt,
  required DateTime targetEndAt,
  Set<String> ignoreDocIds = const <String>{},
  bool isTemporarilyHidden = false,
  bool isDeleted = false,
}) {
  if (!targetEndAt.isAfter(targetStartAt) ||
      !candidateEndAt.isAfter(candidateStartAt) ||
      isTemporarilyHidden ||
      isDeleted ||
      ignoreDocIds.contains(candidateDocId.trim())) {
    return false;
  }
  return targetStartAt.isBefore(candidateEndAt) &&
      candidateStartAt.isBefore(targetEndAt);
}

bool isHomeScheduleSourceVerificationSuccessful({
  required bool sourceRetained,
  required bool sourceExists,
}) {
  return sourceRetained == sourceExists;
}
