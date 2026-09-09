import 'package:cloud_firestore/cloud_firestore.dart';

const Set<String> monthlyConfirmedLessonStatuses = {
  'completed',
  'no_show_deducted',
  'no_show_not_deducted',
  'service',
};

class MonthlyLessonRecord {
  const MonthlyLessonRecord({
    required this.lessonLogId,
    required this.trainerId,
    required this.workspaceType,
    required this.memberId,
    required this.memberNameSnapshot,
    required this.startAt,
    required this.endAt,
    required this.lessonType,
    required this.status,
    required this.sessionTotalSnapshot,
    required this.lessonNumberSnapshot,
  });

  final String lessonLogId;
  final String trainerId;
  final String workspaceType;
  final String memberId;
  final String memberNameSnapshot;
  final DateTime startAt;
  final DateTime? endAt;
  final String lessonType;
  final String status;
  final int sessionTotalSnapshot;
  final int lessonNumberSnapshot;

  bool get isConfirmed => monthlyConfirmedLessonStatuses.contains(status);
  bool get isCancelled => status == 'confirm_cancelled';

  factory MonthlyLessonRecord.fromFirestore({
    required String id,
    required Map<String, dynamic> data,
  }) {
    DateTime? date(dynamic value) => switch (value) {
          Timestamp timestamp => timestamp.toDate(),
          DateTime dateTime => dateTime,
          String text => DateTime.tryParse(text),
          _ => null,
        };
    int integer(dynamic value) => switch (value) {
          num number => number.toInt(),
          _ => int.tryParse((value ?? '').toString()) ?? 0,
        };

    final startAt = date(data['startAt']);
    if (startAt == null) {
      throw const FormatException('monthly_lesson_start_at_missing');
    }
    return MonthlyLessonRecord(
      lessonLogId: id,
      trainerId: (data['trainerId'] ?? '').toString().trim(),
      workspaceType: (data['workspaceType'] ?? '').toString().trim(),
      memberId: (data['memberId'] ?? '').toString().trim(),
      memberNameSnapshot:
          (data['memberNameSnapshot'] ?? data['memberName'] ?? '')
              .toString()
              .trim(),
      startAt: startAt,
      endAt: date(data['endAt']),
      lessonType: (data['lessonType'] ?? data['type'] ?? '').toString().trim(),
      status: (data['status'] ?? data['sessionStatus'] ?? '').toString().trim(),
      sessionTotalSnapshot: integer(
        data['sessionSnapshotTotal'] ?? data['totalSessionsSnapshot'],
      ),
      lessonNumberSnapshot: integer(
        data['sessionSnapshotLessonNumber'] ??
            data['sessionSnapshotDoneAfter'] ??
            data['lessonNumberSnapshot'],
      ),
    );
  }
}

class MonthlyLessonSummary {
  MonthlyLessonSummary({required List<MonthlyLessonRecord> records})
      : records = List.unmodifiable(
          [...records]
            ..sort((left, right) => left.startAt.compareTo(right.startAt)),
        );

  final List<MonthlyLessonRecord> records;

  Iterable<MonthlyLessonRecord> get confirmedRecords =>
      records.where((record) => record.isConfirmed);

  int get totalConfirmed => confirmedRecords.length;
  int get completed => _count('completed');
  int get service => _count('service');
  int get noShowDeducted => _count('no_show_deducted');
  int get noShowNotDeducted => _count('no_show_not_deducted');
  int get actualMemberCount => confirmedRecords
      .map((record) => record.memberId)
      .where((id) => id.isNotEmpty)
      .toSet()
      .length;

  int _count(String status) =>
      confirmedRecords.where((record) => record.status == status).length;

  int countForDay(DateTime day) =>
      recordsForDay(day).where((record) => record.isConfirmed).length;

  List<MonthlyLessonRecord> recordsForDay(
    DateTime day, {
    bool includeCancelled = true,
  }) {
    return records.where((record) {
      final sameDay = record.startAt.year == day.year &&
          record.startAt.month == day.month &&
          record.startAt.day == day.day;
      return sameDay &&
          (record.isConfirmed || (includeCancelled && record.isCancelled));
    }).toList(growable: false);
  }
}

DateTime monthlyLessonMonthStart(DateTime month) =>
    DateTime(month.year, month.month);

DateTime monthlyLessonNextMonthStart(DateTime month) =>
    DateTime(month.year, month.month + 1);
