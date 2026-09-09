class PersonalTierProgress {
  const PersonalTierProgress({
    required this.currentTier,
    required this.scheduleCount,
    required this.scheduleGoal,
    required this.scheduleMissionCompleted,
    required this.teacherInfoCompleted,
    required this.completedMissionCount,
    required this.totalMissionCount,
  });

  static const int defaultScheduleGoal = 10;
  static const int defaultMissionTotal = 2;

  final String currentTier;
  final int scheduleCount;
  final int scheduleGoal;
  final bool scheduleMissionCompleted;
  final bool teacherInfoCompleted;
  final int completedMissionCount;
  final int totalMissionCount;

  bool get beginnerMissionEarned {
    const earned = <String>{
      'Amateur',
      'Semi-Pro',
      'Pro',
      'Master',
      'Grand Prix',
    };
    return earned.contains(currentTier.trim());
  }

  bool get displayScheduleMissionCompleted =>
      beginnerMissionEarned || scheduleMissionCompleted;

  bool get displayTeacherInfoCompleted =>
      beginnerMissionEarned || teacherInfoCompleted;

  int get displayCompletedMissionCount => beginnerMissionEarned
      ? totalMissionCount
      : completedMissionCount.clamp(0, totalMissionCount);

  bool get needsTeacherInfoReview =>
      beginnerMissionEarned && !teacherInfoCompleted;

  String debugLog({required String source}) {
    final displayCompleted =
        beginnerMissionEarned ? defaultMissionTotal : completedMissionCount;
    return '[MTF_TIER_PROGRESS] source=$source '
        'currentTier=$currentTier '
        'rawScheduleCount=$scheduleCount '
        'rawScheduleComplete=$scheduleMissionCompleted '
        'rawTeacherInfoComplete=$teacherInfoCompleted '
        'rawCompleted=$completedMissionCount '
        'displayCompleted=$displayCompleted '
        'displayTotal=$defaultMissionTotal '
        'earned=$beginnerMissionEarned';
  }

  factory PersonalTierProgress.fromProfile(Map<String, dynamic> profile) {
    final raw = profile['personalTierProgress'];
    final progress =
        raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    final scheduleCount = _int(progress['scheduleCount']);
    final scheduleGoal = _int(progress['scheduleGoal'], defaultScheduleGoal);
    final scheduleComplete = progress['scheduleMissionCompleted'] == true ||
        scheduleCount >= scheduleGoal;
    final teacherComplete = progress['teacherInfoCompleted'] == true;
    return PersonalTierProgress(
      currentTier: (profile['tier'] ?? 'Beginner').toString().trim(),
      scheduleCount: scheduleCount,
      scheduleGoal: scheduleGoal,
      scheduleMissionCompleted: scheduleComplete,
      teacherInfoCompleted: teacherComplete,
      completedMissionCount: _int(progress['completedMissionCount'],
          (scheduleComplete ? 1 : 0) + (teacherComplete ? 1 : 0)),
      totalMissionCount:
          _int(progress['totalMissionCount'], defaultMissionTotal),
    );
  }

  factory PersonalTierProgress.fromCallable(Map<String, dynamic> data) {
    return PersonalTierProgress.fromProfile({
      'tier': data['tier'],
      'personalTierProgress': data,
    });
  }

  static int _int(Object? value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }
}
