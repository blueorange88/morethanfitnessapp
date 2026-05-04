import 'package:cloud_firestore/cloud_firestore.dart';

enum Gender { male, female, unknown }

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
  final DateTime? lastLogAt;
  final DateTime? nextLessonAt;
  final String memberStatus;
  final String? groupId;
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
    this.lastLogAt,
    this.nextLessonAt,
    this.groupId,
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

    return Member(
      id: id,
      name: d['name'] as String?,
      phone: d['phone'] as String?,
      trainer: d['trainer'] as String?,
      grade: d['membershipGrade'] as String?,
      remainingSessions: (sessions['remain'] as num?)?.toInt() ?? 0,
      totalSessions: (sessions['total'] as num?)?.toInt() ?? 0,
      firstDate: _toDate(membership['startAt']) ?? _toDate(d['createdAt']),
      recentReg: _toDate(membership['lastRegisteredAt']),
      expireAt: _toDate(
        membership['endAt'] ?? membership['passEnd'] ?? d['expireAt'],
      ),
      lastLogAt: _toDate(d['lastLogAt']),
      nextLessonAt: _toDate(d['nextLessonAt']) ?? _toDate(d['nextReservationAt']),
      memberStatus: (d['memberStatus'] as String?) ?? '활성',
      gender: _normGender(d['gender'] as String?),
      groupId: d['groupId'] as String?,
    );
  }
}