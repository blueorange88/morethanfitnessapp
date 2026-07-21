class HomeQuickSignMemberState {
  const HomeQuickSignMemberState({
    required this.hasContract,
    required this.lessonRegistered,
    required this.lessonType,
    required this.totalSessions,
    required this.remainSessions,
    required this.basis,
    this.contractId,
  });

  final bool hasContract;
  final bool lessonRegistered;
  final String lessonType;
  final int totalSessions;
  final int remainSessions;
  final String basis; // contract | manual | none
  final String? contractId;
}