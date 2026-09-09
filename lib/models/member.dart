import 'package:cloud_firestore/cloud_firestore.dart';

enum Gender { male, female, unknown }

String personalMemberStatusFromCanonical(Map<String, dynamic> data) {
  final managementState = (data['managementState'] ?? '').toString().trim();
  switch (managementState) {
    case 'dormant':
    case 'paused':
      return '휴면';
    case 'expired':
      return '만료';
    case 'active':
      return '활성';
  }
  final legacyStatus = (data['memberStatus'] ?? '').toString().trim();
  return legacyStatus.isEmpty ? '활성' : legacyStatus;
}

class Member {
  final String id;
  final String? name;
  final String? phone;
  final String? trainer;
  final String? grade;
  final int remainingSessions;
  final int totalSessions;
  final DateTime? firstDate;
  final DateTime? recentReg;
  final DateTime? expireAt;
  final DateTime? birthDate;
  final DateTime? anniversaryDate;
  final String? anniversaryLabel;
  final String? specialEvent;
  final DateTime? nextMoreDayAt;
  final String? nextMoreDayLabel;
  final String? nextMoreDaySource;
  final bool femaleConditionEnabled;
  final DateTime? femaleConditionLastStartAt;
  final int femaleConditionCycleDays;
  final String? femaleConditionMemo;
  final DateTime? lastLogAt;
  final DateTime? nextLessonAt;
  final String memberStatus;
  final String? groupId;
  final String? personalGroupId;
  final List<String> personalTagIds;
  final Gender gender;

  const Member({
    required this.id,
    this.name,
    this.phone,
    this.trainer,
    this.grade,
    required this.remainingSessions,
    required this.totalSessions,
    this.firstDate,
    this.recentReg,
    this.expireAt,
    this.birthDate,
    this.anniversaryDate,
    this.anniversaryLabel,
    this.specialEvent,
    this.nextMoreDayAt,
    this.nextMoreDayLabel,
    this.nextMoreDaySource,
    this.femaleConditionEnabled = false,
    this.femaleConditionLastStartAt,
    this.femaleConditionCycleDays = 28,
    this.femaleConditionMemo,
    this.lastLogAt,
    this.nextLessonAt,
    this.groupId,
    this.personalGroupId,
    this.personalTagIds = const <String>[],
    required this.memberStatus,
    required this.gender,
  });

  bool get isExpired {
    if (memberStatus == '만료') return true;
    if (expireAt == null) return false;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(expireAt!.year, expireAt!.month, expireAt!.day);
    return end.isBefore(today);
  }

  static Gender _normGender(String? g) {
    final s = (g ?? '').toLowerCase().trim();
    if (RegExp(r'^(f|여|female|woman)').hasMatch(s)) return Gender.female;
    if (RegExp(r'^(m|남|male|man)').hasMatch(s)) return Gender.male;
    return Gender.unknown;
  }

  static DateTime? _toDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    return null;
  }

  factory Member.fromFirestore(String id, Map<String, dynamic> d) {
    final sessions = (d['sessions'] is Map)
        ? Map<String, dynamic>.from(d['sessions'] as Map)
        : <String, dynamic>{};

    final membership = (d['membership'] is Map)
        ? Map<String, dynamic>.from(d['membership'] as Map)
        : <String, dynamic>{};

    final health = (d['health'] is Map)
        ? Map<String, dynamic>.from(d['health'] as Map)
        : <String, dynamic>{};

    final femaleCondition = (health['femaleCondition'] is Map)
        ? Map<String, dynamic>.from(health['femaleCondition'] as Map)
        : <String, dynamic>{};

    return Member(
      id: id,
      name: d['name'] as String?,
      phone: d['phone'] as String?,
      trainer: d['trainer'] as String?,
      grade: d['membershipGrade'] as String?,
      remainingSessions: (sessions['remain'] as num?)?.toInt() ??
          (d['remainSessions'] as num?)?.toInt() ??
          (d['remainingSessions'] as num?)?.toInt() ??
          0,
      totalSessions: (sessions['total'] as num?)?.toInt() ??
          (d['totalSessions'] as num?)?.toInt() ??
          0,
      firstDate: _toDate(membership['startAt']) ?? _toDate(d['createdAt']),
      recentReg: _toDate(membership['lastRegisteredAt']),
      expireAt: _toDate(
        membership['endAt'] ?? membership['passEnd'] ?? d['expireAt'],
      ),
      birthDate: _toDate(d['birth'] ?? d['birthDate'] ?? d['birthday']),
      anniversaryDate: _toDate(d['anniversaryDate']),
      anniversaryLabel: (d['anniversaryLabel'] as String?)?.trim(),
      specialEvent: (d['specialEvent'] as String?)?.trim(),
      nextMoreDayAt: _toDate(d['nextMoreDayAt']),
      nextMoreDayLabel: (d['nextMoreDayLabel'] as String?)?.trim(),
      nextMoreDaySource: (d['nextMoreDaySource'] as String?)?.trim(),
      femaleConditionEnabled: (femaleCondition['enabled'] as bool?) ?? false,
      femaleConditionLastStartAt: _toDate(femaleCondition['lastStartAt']),
      femaleConditionCycleDays:
          (femaleCondition['cycleDays'] as num?)?.toInt() ?? 28,
      femaleConditionMemo: (femaleCondition['memo'] as String?)?.trim(),
      lastLogAt: _toDate(d['lastLessonAt'] ?? d['lastLogAt']),
      nextLessonAt:
          _toDate(d['nextLessonAt']) ?? _toDate(d['nextReservationAt']),
      memberStatus: personalMemberStatusFromCanonical(d),
      gender: _normGender(d['gender'] as String?),
      groupId: d['groupId'] as String?,
      personalGroupId: (d['personalGroupId'] as String?)?.trim(),
      personalTagIds: d['personalTagIds'] is Iterable
          ? (d['personalTagIds'] as Iterable)
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList(growable: false)
          : const <String>[],
    );
  }
}
