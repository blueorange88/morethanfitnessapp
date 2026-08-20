import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../utils/home_schedule_write_plan.dart';
import '../utils/home_schedule_move_plan.dart';

String homeScheduleScopedDocumentId(String docId, String? ownerUid) {
  final clean = docId.trim();
  if (clean.isEmpty) return '';
  final owner = ownerUid?.trim() ?? '';
  if (owner.isEmpty || clean.startsWith('$owner--')) return clean;
  return '$owner--$clean';
}

bool shouldPersistMemberNextLessonCache(String? ownerUid) {
  return (ownerUid?.trim() ?? '').isEmpty;
}

enum HomeScheduleMutationFailureReason {
  commitFailed,
  sourceStillExists,
  retainedSourceMissing,
  serverVerificationFailed,
}

class HomeScheduleMutationException implements Exception {
  const HomeScheduleMutationException({
    required this.reason,
    required this.mutationId,
    this.sourceDocId,
    this.cause,
  });

  final HomeScheduleMutationFailureReason reason;
  final String mutationId;
  final String? sourceDocId;
  final Object? cause;

  @override
  String toString() {
    return 'HomeScheduleMutationException('
        'reason=$reason, mutationId=$mutationId, sourceDocId=$sourceDocId)';
  }
}

class HomeScheduleEditWrite {
  const HomeScheduleEditWrite({
    required this.targetDocId,
    required this.data,
  });

  final String targetDocId;
  final Map<String, dynamic> data;
}

class HomeScheduleFirestoreService {
  HomeScheduleFirestoreService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _schedules =>
      _db.collection('schedules');

  static CollectionReference<Map<String, dynamic>> get _members =>
      _db.collection('members');

  static String _scopedDocId(String docId, String? ownerUid) {
    return homeScheduleScopedDocumentId(docId, ownerUid);
  }

  static Map<String, dynamic> _personalIdentity(String? ownerUid) {
    final owner = ownerUid?.trim() ?? '';
    if (owner.isEmpty) return const {};
    return {'trainerId': owner, 'workspaceType': 'personal'};
  }

  static String _newMutationId(String action) {
    return '$action-${DateTime.now().microsecondsSinceEpoch}';
  }

  static void _logMutation(String message) {
    if (kDebugMode) {
      debugPrint('[MTF_SCHEDULE_MUTATION] $message');
    }
  }

  static Future<void> _verifySourceStateFromServer({
    required Iterable<String> sourceDocIds,
    required String mutationId,
    required String action,
    required bool expectedExists,
  }) async {
    await Future.wait(sourceDocIds.map((sourceDocId) async {
      try {
        final snapshot = await _schedules.doc(sourceDocId).get(
              const GetOptions(source: Source.server),
            );

        _logMutation(
          'mutationId=$mutationId action=$action serverVerify '
          'sourceDocId=$sourceDocId exists=${snapshot.exists}',
        );

        if (!isHomeScheduleSourceVerificationSuccessful(
          sourceRetained: expectedExists,
          sourceExists: snapshot.exists,
        )) {
          throw HomeScheduleMutationException(
            reason: expectedExists
                ? HomeScheduleMutationFailureReason.retainedSourceMissing
                : HomeScheduleMutationFailureReason.sourceStillExists,
            mutationId: mutationId,
            sourceDocId: sourceDocId,
          );
        }
      } on HomeScheduleMutationException {
        rethrow;
      } catch (error) {
        _logMutation(
          'mutationId=$mutationId action=$action serverVerifyFailed '
          'sourceDocId=$sourceDocId error=$error',
        );
        throw HomeScheduleMutationException(
          reason: HomeScheduleMutationFailureReason.serverVerificationFailed,
          mutationId: mutationId,
          sourceDocId: sourceDocId,
          cause: error,
        );
      }
    }));
  }

  static Future<void> _commitBatchAndVerify({
    required WriteBatch batch,
    required List<String> sourceDocIds,
    List<String> retainedSourceDocIds = const [],
    required List<String> targetDocIds,
    required String mutationId,
    required String action,
  }) async {
    _logMutation(
      'mutationId=$mutationId action=$action batchCommitStart '
      'sourceDocIds=${sourceDocIds.join(',')} '
      'targetDocIds=${targetDocIds.join(',')}',
    );

    try {
      await batch.commit();
    } catch (error) {
      _logMutation(
        'mutationId=$mutationId action=$action batchCommitFailed error=$error',
      );
      throw HomeScheduleMutationException(
        reason: HomeScheduleMutationFailureReason.commitFailed,
        mutationId: mutationId,
        cause: error,
      );
    }

    _logMutation(
      'mutationId=$mutationId action=$action batchCommitSuccess',
    );

    await _verifySourceStateFromServer(
      sourceDocIds: sourceDocIds,
      mutationId: mutationId,
      action: action,
      expectedExists: false,
    );
    await _verifySourceStateFromServer(
      sourceDocIds: retainedSourceDocIds,
      mutationId: mutationId,
      action: action,
      expectedExists: true,
    );
  }

  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _slotKey(DateTime value) => '${_dateKey(value)}T'
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';

  static DateTime? _writeStartAt(Map<String, dynamic> data) {
    final value = data['startAt'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static Map<String, dynamic> _scheduleWriteData({
    required String targetDocId,
    required Map<String, dynamic> data,
    required String? ownerUid,
  }) {
    final owner = ownerUid?.trim() ?? '';
    if (owner.isEmpty) return Map<String, dynamic>.from(data);
    final startAt = _writeStartAt(data);
    if (startAt == null) throw Exception('missing_schedule_start_at');
    final attended = data['attended'] == true;
    return {
      ...data,
      'scheduleId': targetDocId,
      'trainerId': owner,
      'workspaceType': 'personal',
      'schemaVersion': 1,
      'dateKey': _dateKey(startAt),
      'slotKey': _slotKey(startAt),
      'status': attended ? 'attended' : 'scheduled',
    };
  }

  static Future<void> saveSchedule({
    required String docId,
    required DateTime startAt,
    required DateTime endAt,
    required String day,
    required String time,
    required String endTime,
    required String name,
    required String lessonTypeName,
    required String lessonTypeId,
    required String lessonTypeColorHex,
    required bool attended,
    required Map<String, dynamic> countMap,
    String? memberId,
    String? phone,
    String? memo,
    String? ownerUid,
  }) async {
    if (!endAt.isAfter(startAt)) {
      throw Exception('end_before_start');
    }

    final cleanMemberId = memberId?.trim() ?? '';
    final cleanPhone = phone?.trim() ?? '';
    final cleanMemo = memo?.trim() ?? '';

    final mutationId = _newMutationId('createOrUpdate');
    _logMutation(
      'mutationId=$mutationId action=createOrUpdate targetDocId=$docId '
      'targetStartAt=${startAt.toIso8601String()}',
    );

    final targetDocId = _scopedDocId(docId, ownerUid);
    final data = <String, dynamic>{
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'day': day,
      'time': time,
      'endTime': endTime,
      'name': name,
      'type': lessonTypeName,
      'typeName': lessonTypeName,
      'typeId': lessonTypeId,
      'typeColorHex': lessonTypeColorHex,
      'attended': attended,
      if (cleanMemberId.isNotEmpty) 'memberId': cleanMemberId,
      if (cleanPhone.isNotEmpty) 'phone': cleanPhone,
      if (cleanMemo.isNotEmpty) 'memo': cleanMemo,
      ...countMap,
      ..._personalIdentity(ownerUid),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _schedules.doc(targetDocId).set(
          _scheduleWriteData(
            targetDocId: targetDocId,
            data: data,
            ownerUid: ownerUid,
          ),
          SetOptions(merge: true),
        );
  }

  static Future<void> deleteSchedule(String docId, {String? ownerUid}) async {
    final cleanDocId = _scopedDocId(docId, ownerUid);
    if (cleanDocId.isEmpty) {
      throw Exception('empty_schedule_doc_id');
    }

    final mutationId = _newMutationId('delete');
    final batch = _db.batch()..delete(_schedules.doc(cleanDocId));

    await _commitBatchAndVerify(
      batch: batch,
      sourceDocIds: [cleanDocId],
      targetDocIds: const [],
      mutationId: mutationId,
      action: 'delete',
    );
  }

  static Future<void> deleteSchedules(
    List<String> docIds, {
    String? ownerUid,
  }) async {
    final cleanIds = docIds
        .map((e) => _scopedDocId(e, ownerUid))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    if (cleanIds.isEmpty) return;

    // Firestore batch 제한 여유분을 두고 450개씩 처리
    for (int i = 0; i < cleanIds.length; i += 450) {
      final chunk = cleanIds.skip(i).take(450).toList();
      final batch = _db.batch();

      for (final docId in chunk) {
        batch.delete(_schedules.doc(docId));
      }

      final mutationId = _newMutationId('deleteMany');
      await _commitBatchAndVerify(
        batch: batch,
        sourceDocIds: chunk,
        targetDocIds: const [],
        mutationId: mutationId,
        action: 'deleteMany',
      );
    }
  }

  static Future<void> commitScheduleWrites({
    List<String> deleteDocIds = const [],
    List<String> retainedSourceDocIds = const [],
    List<HomeScheduleEditWrite> writes = const [],
    String? ownerUid,
  }) async {
    final cleanDeleteIds = deleteDocIds
        .map((e) => _scopedDocId(e, ownerUid))
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final cleanWrites =
        writes.where((e) => e.targetDocId.trim().isNotEmpty).toList();
    final cleanRetainedIds = retainedSourceDocIds
        .map((e) => _scopedDocId(e, ownerUid))
        .where((e) => e.isNotEmpty && !cleanDeleteIds.contains(e))
        .toSet()
        .toList();

    if (cleanDeleteIds.isEmpty && cleanWrites.isEmpty) return;

    final batch = _db.batch();

    for (final docId in cleanDeleteIds) {
      batch.delete(_schedules.doc(docId));
    }

    for (final write in cleanWrites) {
      final targetDocId = _scopedDocId(write.targetDocId, ownerUid);
      batch.set(
        _schedules.doc(targetDocId),
        _scheduleWriteData(
          targetDocId: targetDocId,
          data: write.data,
          ownerUid: ownerUid,
        ),
        SetOptions(merge: true),
      );
    }

    final action = resolveHomeScheduleWriteAction(
      deleteCount: cleanDeleteIds.length,
      writeCount: cleanWrites.length,
    ).name;
    final mutationId = _newMutationId(action);
    await _commitBatchAndVerify(
      batch: batch,
      sourceDocIds: cleanDeleteIds,
      retainedSourceDocIds: cleanRetainedIds,
      targetDocIds: cleanWrites
          .map((write) => _scopedDocId(write.targetDocId, ownerUid))
          .toList(),
      mutationId: mutationId,
      action: action,
    );
  }

  static Future<void> commitEditedSchedule({
    String? deleteDocId,
    List<String> retainedSourceDocIds = const [],
    required List<HomeScheduleEditWrite> writes,
    String? ownerUid,
  }) async {
    final batch = _db.batch();

    final cleanDeleteDocId = _scopedDocId(deleteDocId ?? '', ownerUid);

    if (cleanDeleteDocId.isNotEmpty) {
      batch.delete(_schedules.doc(cleanDeleteDocId));
    }

    for (final write in writes) {
      final cleanTargetDocId = _scopedDocId(write.targetDocId, ownerUid);
      if (cleanTargetDocId.isEmpty) continue;

      batch.set(
        _schedules.doc(cleanTargetDocId),
        _scheduleWriteData(
          targetDocId: cleanTargetDocId,
          data: write.data,
          ownerUid: ownerUid,
        ),
        SetOptions(merge: true),
      );
    }

    final sourceDocIds = cleanDeleteDocId.isEmpty
        ? const <String>[]
        : <String>[cleanDeleteDocId];
    final cleanRetainedIds = retainedSourceDocIds
        .map((e) => _scopedDocId(e, ownerUid))
        .where((e) => e.isNotEmpty && !sourceDocIds.contains(e))
        .toSet()
        .toList();
    final action = sourceDocIds.isEmpty ? 'update' : 'moveOrReplace';
    final mutationId = _newMutationId(action);
    await _commitBatchAndVerify(
      batch: batch,
      sourceDocIds: sourceDocIds,
      retainedSourceDocIds: cleanRetainedIds,
      targetDocIds: writes
          .map((write) => _scopedDocId(write.targetDocId, ownerUid))
          .toList(),
      mutationId: mutationId,
      action: action,
    );
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> getSchedule(
    String docId, {
    String? ownerUid,
    Source source = Source.serverAndCache,
  }) {
    return _schedules
        .doc(_scopedDocId(docId, ownerUid))
        .get(GetOptions(source: source));
  }

  static Future<bool> isScheduleConfirmed(
    String docId, {
    String? ownerUid,
  }) async {
    final cleanDocId = _scopedDocId(docId, ownerUid);
    if (cleanDocId.isEmpty) return false;

    try {
      final snap = await _schedules.doc(cleanDocId).get();
      final data = snap.data();

      if (data == null) return false;

      return data['lessonConfirmed'] == true ||
          data['lessonConfirmedAt'] != null ||
          (data['lessonConfirmStatus'] ?? '').toString().trim().isNotEmpty ||
          (data['trainingLogId'] ?? '').toString().trim().isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<void> refreshMemberNextLesson(
    String memberId, {
    String? ownerUid,
  }) async {
    final cleanMemberId = memberId.trim();
    if (cleanMemberId.isEmpty) return;
    if (!shouldPersistMemberNextLessonCache(ownerUid)) return;

    final now = DateTime.now();

    Query<Map<String, dynamic>> scheduleQuery =
        _schedules.where('memberId', isEqualTo: cleanMemberId);
    final owner = ownerUid?.trim() ?? '';
    if (owner.isNotEmpty) {
      scheduleQuery = scheduleQuery
          .where('trainerId', isEqualTo: owner)
          .where('workspaceType', isEqualTo: 'personal');
    }
    final query = await scheduleQuery.get();

    DateTime? nearest;

    for (final doc in query.docs) {
      final data = doc.data();
      final raw = data['startAt'];

      DateTime? date;

      if (raw is Timestamp) {
        date = raw.toDate();
      } else if (raw is DateTime) {
        date = raw;
      } else if (raw is String && raw.isNotEmpty) {
        date = DateTime.tryParse(raw);
      }

      if (date == null) continue;
      if (date.isBefore(now)) continue;

      if (nearest == null || date.isBefore(nearest)) {
        nearest = date;
      }
    }

    await _members.doc(cleanMemberId).set({
      'nextLessonAt': nearest == null ? null : Timestamp.fromDate(nearest),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
