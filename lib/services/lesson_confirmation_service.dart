import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum LessonConfirmationResultStatus {
  success,
  alreadyConfirmed,
  lessonNotRegistered,
}

class LessonConfirmationRequest {
  const LessonConfirmationRequest({
    required this.memberId,
    required this.memberName,
    required this.memberPhone,
    required this.scheduleDocId,
    required this.lessonType,
    required this.status,
    required this.startAt,
    required this.endAt,
    required this.trainingLogId,
  });

  final String memberId;
  final String memberName;
  final String memberPhone;
  final String scheduleDocId;
  final String lessonType;
  final String status;
  final DateTime startAt;
  final DateTime endAt;
  final String trainingLogId;
}

class LessonConfirmationResult {
  const LessonConfirmationResult({
    required this.status,
    required this.trainingLogId,
    this.nextRemainForMessage,
    this.snapshotTotal = 0,
    this.snapshotRemainBefore = 0,
    this.snapshotRemainAfter = 0,
    this.snapshotDoneBefore = 0,
    this.snapshotDoneAfter = 0,
  });

  final LessonConfirmationResultStatus status;
  final String trainingLogId;
  final int? nextRemainForMessage;
  final int snapshotTotal;
  final int snapshotRemainBefore;
  final int snapshotRemainAfter;
  final int snapshotDoneBefore;
  final int snapshotDoneAfter;

  bool get isSuccess => status == LessonConfirmationResultStatus.success;
}

class LessonConfirmationService {
  LessonConfirmationService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<LessonConfirmationResult> confirmFromHome(
    LessonConfirmationRequest request,
  ) async {
    final cleanMemberId = request.memberId.trim();
    final cleanScheduleDocId = request.scheduleDocId.trim();
    final cleanTrainingLogId = request.trainingLogId.trim();
    final cleanStatus =
        request.status.trim().isEmpty ? 'completed' : request.status.trim();

    final memberRef = _db.collection('members').doc(cleanMemberId);
    final logRef = _db.collection('training_logs').doc(cleanTrainingLogId);
    final scheduleRef = _db.collection('schedules').doc(cleanScheduleDocId);

    bool alreadyConfirmed = false;
    bool lessonNotRegisteredInTx = false;
    int? nextRemainForMessage;

    int snapshotTotalForLocal = 0;
    int snapshotRemainBeforeForLocal = 0;
    int snapshotRemainAfterForLocal = 0;
    int snapshotDoneBeforeForLocal = 0;
    int snapshotDoneAfterForLocal = 0;

    await _db.runTransaction((tx) async {
      final scheduleSnap = await tx.get(scheduleRef);
      final scheduleData = scheduleSnap.data();

      if (scheduleData?['lessonConfirmed'] == true ||
          scheduleData?['lessonConfirmedAt'] != null) {
        alreadyConfirmed = true;
        return;
      }

      final logSnap = await tx.get(logRef);
      final logData = logSnap.data() ?? <String, dynamic>{};

      if (logData['locked'] == true || logData['lessonConfirmed'] == true) {
        alreadyConfirmed = true;
        return;
      }

      final memberSnap = await tx.get(memberRef);
      final memberData = memberSnap.data() ?? <String, dynamic>{};

      final sessions = memberData['sessions'] is Map
          ? Map<String, dynamic>.from(memberData['sessions'] as Map)
          : <String, dynamic>{};

      final lessonTypeFromMember =
          (memberData['lessonType'] ?? request.lessonType).toString().trim();

      final lessonNotRegistered = sessions['notRegistered'] == true ||
          lessonTypeFromMember.isEmpty ||
          lessonTypeFromMember == '미입력';

      if (lessonNotRegistered) {
        lessonNotRegisteredInTx = true;
        return;
      }

      final lessonSync = memberData['lessonSync'] is Map
          ? Map<String, dynamic>.from(memberData['lessonSync'] as Map)
          : <String, dynamic>{};

      final contractId = (lessonSync['contractId'] ?? '').toString().trim();

      final basis =
          memberData['contractSigned'] == true || contractId.isNotEmpty
              ? 'contract'
              : 'manual';

      final rawRemain = memberData['remainSessions'] ??
          memberData['remainingSessions'] ??
          sessions['remain'] ??
          memberData['remainingPt'] ??
          memberData['ptRemaining'];

      final rawTotal = memberData['totalSessions'] ??
          sessions['total'] ??
          memberData['sessionTotal'];

      final rawDone = memberData['doneSessions'] ?? sessions['done'];

      final currentRemain = _intFromAny(rawRemain);
      final currentDone = _intFromAny(rawDone);
      final currentTotal = _intFromAny(rawTotal);

      final shouldDeduct = _shouldDeductForConfirmStatus(cleanStatus);
      final actuallyDeducted = shouldDeduct && currentRemain > 0;

      final nextRemain = actuallyDeducted ? currentRemain - 1 : currentRemain;

      final nextDone = actuallyDeducted ? currentDone + 1 : currentDone;

      nextRemainForMessage = nextRemain;

      snapshotTotalForLocal = currentTotal;
      snapshotRemainBeforeForLocal = currentRemain;
      snapshotRemainAfterForLocal = nextRemain;
      snapshotDoneBeforeForLocal = currentDone;
      snapshotDoneAfterForLocal = nextDone;

      final memberUpdate = <String, dynamic>{
        'lastLogAt': Timestamp.fromDate(request.startAt),
        'lastLessonAt': Timestamp.fromDate(request.startAt),
        'lastLessonType': request.lessonType,
        'lastLessonStatus': cleanStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'confirmedTrainingLogIds': FieldValue.arrayUnion([cleanTrainingLogId]),
        'lessonStats.confirmedCount': FieldValue.increment(1),
        'lessonStats.lastConfirmStatus': cleanStatus,
        'lessonStats.lastConfirmedAt': Timestamp.fromDate(request.startAt),
        'lessonStats.lastLessonType': request.lessonType,
        'lessonStats.lastBasis': basis,
      };

      if (actuallyDeducted) {
        memberUpdate.addAll({
          'remainSessions': nextRemain,
          'remainingSessions': nextRemain,
          'doneSessions': nextDone,
          'sessions.remain': nextRemain,
          'sessions.done': nextDone,
          'sessions.source': basis,
          'deductedTrainingLogIds': FieldValue.arrayUnion([cleanTrainingLogId]),
          'lessonSource': basis,
          'lessonSync.source': basis,
          'lessonSync.lastLogId': cleanTrainingLogId,
          'lessonSync.lastLogSource': 'home_confirm',
          'lessonSync.updatedAt': FieldValue.serverTimestamp(),
        });
      }

      if (cleanStatus == 'no_show_deducted') {
        memberUpdate['noShowDeductedCount'] = FieldValue.increment(1);
        memberUpdate['sessions.noShowDeductedCount'] = FieldValue.increment(1);
        memberUpdate['lessonStats.noShowDeductedCount'] =
            FieldValue.increment(1);
      } else if (cleanStatus == 'no_show_not_deducted') {
        memberUpdate['noShowUndeductedCount'] = FieldValue.increment(1);
        memberUpdate['sessions.noShowUndeductedCount'] =
            FieldValue.increment(1);
        memberUpdate['lessonStats.noShowUndeductedCount'] =
            FieldValue.increment(1);
      } else if (cleanStatus == 'service') {
        memberUpdate['serviceSessionCount'] = FieldValue.increment(1);
        memberUpdate['sessions.serviceSessionCount'] = FieldValue.increment(1);
        memberUpdate['lessonStats.serviceSessionCount'] =
            FieldValue.increment(1);
      } else if (cleanStatus == 'completed') {
        memberUpdate['lessonStats.completedCount'] = FieldValue.increment(1);
      }

      tx.set(memberRef, memberUpdate, SetOptions(merge: true));

      tx.set(
          logRef,
          {
            'id': cleanTrainingLogId,
            'memberId': cleanMemberId,
            'memberName': request.memberName.trim().isEmpty
                ? '회원'
                : request.memberName.trim(),
            'memberNameSnapshot': request.memberName.trim().isEmpty
                ? '회원'
                : request.memberName.trim(),
            if (request.memberPhone.trim().isNotEmpty)
              'memberPhone': _normalizePhone(request.memberPhone),
            'scheduleDocId': cleanScheduleDocId,
            'source': 'trainer_schedule_confirm',
            'quickSignedOnly': true,
            'isQuickSignLog': true,
            'inputMethod': 'quick_sign',
            'title': '레슨확정',
            'logTitle': '레슨확정',
            'type': request.lessonType,
            'lessonType': request.lessonType,
            'sessionStatus': cleanStatus,
            'status': cleanStatus,
            'sessionStatusLabel': _confirmStatusLabel(cleanStatus),
            'startAt': Timestamp.fromDate(request.startAt),
            'endAt': Timestamp.fromDate(request.endAt),
            'date': DateFormat('yyyy-MM-dd').format(request.startAt),
            'time':
                '${request.startAt.hour.toString().padLeft(2, '0')}:${request.startAt.minute.toString().padLeft(2, '0')}',
            'trainerSigned': true,
            'trainerSignature': {
              'type': 'confirm_button',
              'value': '레슨확정',
              'signedAt': FieldValue.serverTimestamp(),
              'signedBy': 'trainer_app',
            },
            'memberSigned': false,
            'waitingTrainerConfirm': false,
            'confirmedByTrainer': true,
            'confirmedAt': FieldValue.serverTimestamp(),
            'confirmMethod': 'trainer_confirmed',
            'trainerConfirmed': true,
            'basis': basis,
            'contractId': contractId.isEmpty ? null : contractId,
            'deductionKey': cleanTrainingLogId,
            'remainBeforeDeduct': currentRemain,
            'remainAfterDeduct': nextRemain,
            'sessionSnapshotTotal': currentTotal,
            'sessionSnapshotRemainBefore': currentRemain,
            'sessionSnapshotRemainAfter': nextRemain,
            'sessionSnapshotDoneBefore': currentDone,
            'sessionSnapshotDoneAfter': nextDone,
            'sessionSnapshotLessonNumber': nextDone,
            'sessionSnapshotLabel': '$nextDone/$currentTotal',
            'locked': true,
            'deductionTarget': shouldDeduct,
            'deductionApplied': actuallyDeducted,
            'deductionSkippedReason': shouldDeduct && !actuallyDeducted
                ? 'no_remaining_sessions'
                : (!shouldDeduct ? 'not_deduction_mode' : null),
            'lessonConfirmed': true,
            'updatedAt': FieldValue.serverTimestamp(),
            if (!logSnap.exists) 'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true));

      if (actuallyDeducted) {
        final ledgerRef =
            memberRef.collection('lesson_ledger').doc(cleanTrainingLogId);

        tx.set(
          ledgerRef,
          {
            'type': 'deduct',
            'source': 'home_quick_sign',
            'confirmMethod': 'trainer_confirmed',
            'scheduleId': cleanScheduleDocId,
            'logId': cleanTrainingLogId,
            'contractId': contractId.isEmpty ? null : contractId,
            'basis': basis,
            'lessonType': request.lessonType,
            'deltaRemain': currentRemain > 0 ? -1 : 0,
            'deductedSessions': currentRemain > 0 ? 1 : 0,
            'remainBefore': currentRemain,
            'remainAfter': nextRemain,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      final scheduleUpdate = <String, dynamic>{
        'lessonConfirmed': true,
        'lessonConfirmedAt': FieldValue.serverTimestamp(),
        'lessonConfirmStatus': cleanStatus,
        'lessonConfirmLabel': _confirmStatusLabel(cleanStatus),
        'trainingLogId': cleanTrainingLogId,
        'basis': basis,
        'contractLinked': basis == 'contract',
        if (contractId.isNotEmpty) 'contractId': contractId,
        if (basis == 'contract') 'cancelLockedByContract': true,
        if (basis == 'contract')
          'cancelLockContractReason': 'contract_linked_lesson_confirm',
        'attended': cleanStatus == 'completed',
        'sessionSnapshotTotal': currentTotal,
        'sessionSnapshotRemainBefore': currentRemain,
        'sessionSnapshotRemainAfter': nextRemain,
        'sessionSnapshotDoneBefore': currentDone,
        'sessionSnapshotDoneAfter': nextDone,
        'sessionSnapshotLessonNumber': nextDone,
        'sessionSnapshotLabel': '$nextDone/$currentTotal',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      switch (cleanStatus) {
        case 'no_show_deducted':
          scheduleUpdate['attendanceOverride'] = 'no_show_deducted';
          break;
        case 'no_show_not_deducted':
          scheduleUpdate['attendanceOverride'] = 'no_show_not_deducted';
          break;
        case 'service':
          scheduleUpdate['attendanceOverride'] = 'service';
          break;
        case 'completed':
        default:
          scheduleUpdate['attendanceOverride'] = FieldValue.delete();
          break;
      }

      tx.set(
        scheduleRef,
        scheduleUpdate,
        SetOptions(merge: true),
      );
    });

    if (alreadyConfirmed) {
      return LessonConfirmationResult(
        status: LessonConfirmationResultStatus.alreadyConfirmed,
        trainingLogId: cleanTrainingLogId,
      );
    }

    if (lessonNotRegisteredInTx) {
      return LessonConfirmationResult(
        status: LessonConfirmationResultStatus.lessonNotRegistered,
        trainingLogId: cleanTrainingLogId,
      );
    }

    return LessonConfirmationResult(
      status: LessonConfirmationResultStatus.success,
      trainingLogId: cleanTrainingLogId,
      nextRemainForMessage: nextRemainForMessage,
      snapshotTotal: snapshotTotalForLocal,
      snapshotRemainBefore: snapshotRemainBeforeForLocal,
      snapshotRemainAfter: snapshotRemainAfterForLocal,
      snapshotDoneBefore: snapshotDoneBeforeForLocal,
      snapshotDoneAfter: snapshotDoneAfterForLocal,
    );
  }

  static Future<void> cancelPendingSignRequestsForTrainingLog(
    String trainingLogId,
  ) async {
    final cleanLogId = trainingLogId.trim();
    if (cleanLogId.isEmpty) return;

    final snapshot = await _db
        .collection('sign_requests')
        .where('trainingLogId', isEqualTo: cleanLogId)
        .limit(20)
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _db.batch();

    for (final doc in snapshot.docs) {
      final data = doc.data();

      if (data['used'] == true) continue;

      batch.set(
        doc.reference,
        {
          'used': true,
          'status': 'cancelled_by_confirmed_lesson',
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  static bool _shouldDeductForConfirmStatus(String status) {
    return status == 'completed' || status == 'no_show_deducted';
  }

  static String _confirmStatusLabel(String status) {
    switch (status) {
      case 'no_show_deducted':
        return '노쇼 차감';
      case 'no_show_not_deducted':
        return '노쇼 미차감';
      case 'service':
        return '서비스';
      case 'cancelled':
        return '출석 취소';
      case 'completed':
      default:
        return '소진';
    }
  }

  static int _intFromAny(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  static String _normalizePhone(String value) {
    return value.replaceAll(RegExp(r'\D'), '');
  }
}
