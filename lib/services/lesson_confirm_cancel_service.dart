import 'package:cloud_firestore/cloud_firestore.dart';

class LessonConfirmCancelResult {
  const LessonConfirmCancelResult({
    required this.scheduleDocId,
    this.cancelledMemberId,
    this.trainingLogId,
    this.restoredTotalForLocal = 0,
    this.restoredRemainForLocal = 0,
    this.hasRestoredCountForLocal = false,
  });

  final String scheduleDocId;
  final String? cancelledMemberId;
  final String? trainingLogId;
  final int restoredTotalForLocal;
  final int restoredRemainForLocal;
  final bool hasRestoredCountForLocal;
}

class LessonConfirmCancelService {
  LessonConfirmCancelService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<LessonConfirmCancelResult> cancelByScheduleDocId(
      String scheduleDocId,
      ) async {
    final cleanScheduleDocId = scheduleDocId.trim();

    if (cleanScheduleDocId.isEmpty) {
      throw Exception('empty_schedule_doc_id');
    }

    final scheduleRef = _db.collection('schedules').doc(cleanScheduleDocId);

    String? cancelledMemberId;
    String? cancelledTrainingLogId;

    int restoredTotalForLocal = 0;
    int restoredRemainForLocal = 0;
    bool hasRestoredCountForLocal = false;

    await _db.runTransaction((tx) async {
      final scheduleSnap = await tx.get(scheduleRef);
      final scheduleData = scheduleSnap.data();

      if (scheduleData == null) {
        throw Exception('schedule_not_found');
      }

      final isConfirmed = scheduleData['lessonConfirmed'] == true ||
          scheduleData['lessonConfirmedAt'] != null ||
          (scheduleData['lessonConfirmStatus'] ?? '').toString().trim().isNotEmpty ||
          (scheduleData['trainingLogId'] ?? '').toString().trim().isNotEmpty ||
          (scheduleData['quickTrainingLogId'] ?? '').toString().trim().isNotEmpty ||
          (scheduleData['lastTrainingLogId'] ?? '').toString().trim().isNotEmpty;

      if (!isConfirmed) {
        throw Exception('schedule_not_confirmed');
      }

      final memberId = (scheduleData['memberId'] ?? '').toString().trim();
      cancelledMemberId = memberId.isNotEmpty ? memberId : null;

      final status = (scheduleData['lessonConfirmStatus'] ?? '').toString().trim();

      final trainingLogId = [
        scheduleData['trainingLogId'],
        scheduleData['quickTrainingLogId'],
        scheduleData['lastTrainingLogId'],
      ]
          .map((e) => (e ?? '').toString().trim())
          .firstWhere((e) => e.isNotEmpty, orElse: () => '');

      cancelledTrainingLogId = trainingLogId.isEmpty ? null : trainingLogId;

      DocumentReference<Map<String, dynamic>>? logRef;
      Map<String, dynamic> logData = <String, dynamic>{};

      if (trainingLogId.isNotEmpty) {
        logRef = _db.collection('training_logs').doc(trainingLogId);

        final logSnap = await tx.get(logRef);
        logData = logSnap.data() ?? <String, dynamic>{};
      }

      final memberRef = memberId.isEmpty
          ? null
          : _db.collection('members').doc(memberId);

      Map<String, dynamic> memberData = <String, dynamic>{};

      if (memberRef != null) {
        final memberSnap = await tx.get(memberRef);
        memberData = memberSnap.data() ?? <String, dynamic>{};
      }

      final sessions = memberData['sessions'] is Map
          ? Map<String, dynamic>.from(memberData['sessions'] as Map)
          : <String, dynamic>{};

      final rawCurrentRemain = memberData['remainSessions'] ??
          memberData['remainingSessions'] ??
          sessions['remain'] ??
          memberData['remainingPt'] ??
          memberData['ptRemaining'];

      final rawCurrentTotal = memberData['totalSessions'] ??
          sessions['total'] ??
          memberData['sessionTotal'];

      final rawCurrentDone = memberData['doneSessions'] ?? sessions['done'];

      final currentRemain = _intFromAny(rawCurrentRemain);
      final currentTotal = _intFromAny(rawCurrentTotal);
      final currentDone = _intFromAny(rawCurrentDone);

      final logDeductionApplied = logData['deductionApplied'] == true;
      final scheduleSnapshotBefore =
      _intFromAny(scheduleData['sessionSnapshotRemainBefore']);
      final scheduleSnapshotAfter =
      _intFromAny(scheduleData['sessionSnapshotRemainAfter']);

      final looksDeductedBySnapshot =
          scheduleSnapshotBefore > scheduleSnapshotAfter;

      final shouldRestoreOne =
          logDeductionApplied || looksDeductedBySnapshot;

      final restoredRemain =
      shouldRestoreOne ? currentRemain + 1 : currentRemain;

      final restoredDone = shouldRestoreOne
          ? (currentDone > 0 ? currentDone - 1 : 0)
          : currentDone;

      if (memberRef != null) {
        restoredTotalForLocal = currentTotal;
        restoredRemainForLocal = restoredRemain;
        hasRestoredCountForLocal = true;
      }

      if (memberRef != null) {
        final memberUpdate = <String, dynamic>{
          'updatedAt': FieldValue.serverTimestamp(),
          'lastLessonStatus': 'confirm_cancelled',
        };

        if (trainingLogId.isNotEmpty) {
          memberUpdate['confirmedTrainingLogIds'] =
              FieldValue.arrayRemove([trainingLogId]);
          memberUpdate['deductedTrainingLogIds'] =
              FieldValue.arrayRemove([trainingLogId]);
        }

        if (shouldRestoreOne) {
          memberUpdate.addAll({
            'remainSessions': restoredRemain,
            'remainingSessions': restoredRemain,
            'doneSessions': restoredDone,
            'sessions.remain': restoredRemain,
            'sessions.done': restoredDone,
            'lessonSync.cancelledLogId': trainingLogId,
            'lessonSync.cancelledAt': FieldValue.serverTimestamp(),
          });
        }

        final lessonStats = memberData['lessonStats'] is Map
            ? Map<String, dynamic>.from(memberData['lessonStats'] as Map)
            : <String, dynamic>{};

        if (status == 'no_show_deducted') {
          final current = _intFromAny(sessions['noShowDeductedCount']);
          final statsCurrent =
          _intFromAny(lessonStats['noShowDeductedCount']);

          memberUpdate['sessions.noShowDeductedCount'] =
          current > 0 ? current - 1 : 0;
          memberUpdate['lessonStats.noShowDeductedCount'] =
          statsCurrent > 0 ? statsCurrent - 1 : 0;
        } else if (status == 'no_show_not_deducted') {
          final current = _intFromAny(sessions['noShowUndeductedCount']);
          final statsCurrent =
          _intFromAny(lessonStats['noShowUndeductedCount']);

          memberUpdate['sessions.noShowUndeductedCount'] =
          current > 0 ? current - 1 : 0;
          memberUpdate['lessonStats.noShowUndeductedCount'] =
          statsCurrent > 0 ? statsCurrent - 1 : 0;
        } else if (status == 'service') {
          final current = _intFromAny(sessions['serviceSessionCount']);
          final statsCurrent =
          _intFromAny(lessonStats['serviceSessionCount']);

          memberUpdate['sessions.serviceSessionCount'] =
          current > 0 ? current - 1 : 0;
          memberUpdate['lessonStats.serviceSessionCount'] =
          statsCurrent > 0 ? statsCurrent - 1 : 0;
        } else if (status == 'completed') {
          final statsCurrent = _intFromAny(lessonStats['completedCount']);

          memberUpdate['lessonStats.completedCount'] =
          statsCurrent > 0 ? statsCurrent - 1 : 0;
        }

        final confirmedStatsCurrent =
        _intFromAny(lessonStats['confirmedCount']);

        memberUpdate['lessonStats.confirmedCount'] =
        confirmedStatsCurrent > 0 ? confirmedStatsCurrent - 1 : 0;
        memberUpdate['lessonStats.lastConfirmStatus'] = 'confirm_cancelled';
        memberUpdate['lessonStats.lastCancelledAt'] =
            FieldValue.serverTimestamp();

        tx.set(
          memberRef,
          memberUpdate,
          SetOptions(merge: true),
        );
      }

      if (logRef != null) {
        tx.set(
          logRef,
          {
            'voided': true,
            'voidedAt': FieldValue.serverTimestamp(),
            'voidReason': 'trainer_cancel_confirm',
            'voidSource': 'home_schedule',
            'locked': false,
            'lessonConfirmed': false,
            'deductionApplied': false,
            'confirmCancelled': true,
            'confirmCancelledAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      if (memberRef != null && trainingLogId.isNotEmpty) {
        final reverseLedgerRef = memberRef
            .collection('lesson_ledger')
            .doc('${trainingLogId}_reverse');

        tx.set(
          reverseLedgerRef,
          {
            'type': 'reverse',
            'source': 'confirm_cancel',
            'scheduleId': cleanScheduleDocId,
            'logId': trainingLogId,
            'status': status,
            'restoredSessions': shouldRestoreOne ? 1 : 0,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      final scheduleCancelUpdate = <String, dynamic>{
        'lessonConfirmed': FieldValue.delete(),
        'lessonConfirmedAt': FieldValue.delete(),
        'lessonConfirmStatus': FieldValue.delete(),
        'lessonConfirmLabel': FieldValue.delete(),
        'trainingLogId': FieldValue.delete(),
        'quickTrainingLogId': FieldValue.delete(),
        'lastTrainingLogId': FieldValue.delete(),
        'lastSignedAt': FieldValue.delete(),
        'attendanceOverride': FieldValue.delete(),
        'sessionSnapshotTotal': FieldValue.delete(),
        'sessionSnapshotRemainBefore': FieldValue.delete(),
        'sessionSnapshotRemainAfter': FieldValue.delete(),
        'sessionSnapshotDoneBefore': FieldValue.delete(),
        'sessionSnapshotDoneAfter': FieldValue.delete(),
        'sessionSnapshotLessonNumber': FieldValue.delete(),
        'sessionSnapshotLabel': FieldValue.delete(),
        'attended': false,
        'confirmCancelledAt': FieldValue.serverTimestamp(),
        'confirmCancelledLogId': trainingLogId.isEmpty ? null : trainingLogId,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (memberRef != null) {
        if (currentTotal > 0) {
          scheduleCancelUpdate['totalSessions'] = currentTotal.toString();
        }

        scheduleCancelUpdate['remainingSessions'] = restoredRemain.toString();
        scheduleCancelUpdate['remainSessions'] = restoredRemain.toString();
      }

      tx.set(
        scheduleRef,
        scheduleCancelUpdate,
        SetOptions(merge: true),
      );
    });

    return LessonConfirmCancelResult(
      scheduleDocId: cleanScheduleDocId,
      cancelledMemberId: cancelledMemberId,
      trainingLogId: cancelledTrainingLogId,
      restoredTotalForLocal: restoredTotalForLocal,
      restoredRemainForLocal: restoredRemainForLocal,
      hasRestoredCountForLocal: hasRestoredCountForLocal,
    );
  }

  static int _intFromAny(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }
}