import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/personal_training_log.dart';
import 'mtf_firebase_functions.dart';

enum PersonalTrainingLogFailure {
  unauthenticated,
  trainerMismatch,
  memberNotOwned,
  scheduleNotOwned,
  scheduleMemberMismatch,
  recordNotFound,
  immutableIdentity,
  finalized,
  invalidInput,
}

class PersonalTrainingLogException implements Exception {
  const PersonalTrainingLogException(this.failure);

  final PersonalTrainingLogFailure failure;
}

abstract interface class PersonalTrainingLogDataSource {
  String? get currentUid;

  String newLogId();

  Stream<List<PersonalTrainingLogRecord>> watchMemberRange({
    required String uid,
    required String memberId,
    required DateTime start,
    required DateTime endExclusive,
  });

  Future<Map<String, dynamic>?> loadMember(String memberId);

  Future<Map<String, dynamic>?> loadSchedule(String scheduleId);

  Future<PersonalTrainingLogRecord?> loadLog(String lessonLogId);

  Future<void> createLog(String lessonLogId, Map<String, dynamic> data);

  Future<void> updateLog(String lessonLogId, Map<String, dynamic> changes);

  Future<void> deleteLog(String lessonLogId);
}

abstract interface class PersonalTrainingLogMutationGateway {
  Future<Map<String, dynamic>> finalize({
    required String lessonLogId,
    required String status,
  });

  Future<Map<String, dynamic>> cancel(String lessonLogId);
}

class PersonalTrainingLogRepository {
  PersonalTrainingLogRepository({
    required this.uid,
    required PersonalTrainingLogDataSource dataSource,
    required PersonalTrainingLogMutationGateway mutationGateway,
  })  : _dataSource = dataSource,
        _mutationGateway = mutationGateway;

  factory PersonalTrainingLogRepository.firebase({required String uid}) {
    return PersonalTrainingLogRepository(
      uid: uid,
      dataSource: FirebasePersonalTrainingLogDataSource(),
      mutationGateway: FirebasePersonalTrainingLogMutationGateway(),
    );
  }

  final String uid;
  final PersonalTrainingLogDataSource _dataSource;
  final PersonalTrainingLogMutationGateway _mutationGateway;

  Stream<List<PersonalTrainingLogRecord>> watchMemberRange({
    required String memberId,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    _requireCurrentUid();
    final cleanMemberId = memberId.trim();
    if (cleanMemberId.isEmpty || !start.isBefore(endExclusive)) {
      throw const PersonalTrainingLogException(
        PersonalTrainingLogFailure.invalidInput,
      );
    }
    return _dataSource.watchMemberRange(
      uid: uid,
      memberId: cleanMemberId,
      start: start,
      endExclusive: endExclusive,
    );
  }

  Future<String> createDraft(PersonalTrainingLogDraft draft) async {
    _requireCurrentUid();
    _validateDraft(draft);
    await _validateMember(draft.memberId);
    await _validateSchedule(draft.scheduleDocId, draft.memberId);
    final lessonLogId = _dataSource.newLogId();
    await _dataSource.createLog(lessonLogId, {
      'lessonLogId': lessonLogId,
      'trainerId': uid,
      'workspaceType': 'personal',
      'schemaVersion': 1,
      'memberId': draft.memberId.trim(),
      if ((draft.scheduleDocId ?? '').trim().isNotEmpty)
        'scheduleDocId': draft.scheduleDocId!.trim(),
      'lessonDate': draft.lessonDate,
      'startAt': draft.startAt,
      'endAt': draft.endAt,
      'lessonType': draft.lessonType.trim(),
      'status': PersonalTrainingLogStatus.draft,
      'source': draft.source,
      'memo': draft.memo.trim(),
    });
    return lessonLogId;
  }

  Future<void> autosave(
    String lessonLogId,
    PersonalTrainingLogDraft draft,
  ) async {
    _requireCurrentUid();
    _validateDraft(draft);
    final current = await _loadOwnedLog(lessonLogId);
    if (!current.isDraft) {
      throw const PersonalTrainingLogException(
        PersonalTrainingLogFailure.finalized,
      );
    }
    if (draft.memberId.trim() != current.memberId) {
      throw const PersonalTrainingLogException(
        PersonalTrainingLogFailure.immutableIdentity,
      );
    }
    await _validateSchedule(draft.scheduleDocId, current.memberId);
    await _dataSource.updateLog(lessonLogId, {
      if ((draft.scheduleDocId ?? '').trim().isEmpty)
        'scheduleDocId': FieldValue.delete()
      else
        'scheduleDocId': draft.scheduleDocId!.trim(),
      'lessonDate': draft.lessonDate,
      'startAt': draft.startAt,
      'endAt': draft.endAt,
      'lessonType': draft.lessonType.trim(),
      'memo': draft.memo.trim(),
    });
  }

  Future<Map<String, dynamic>> finalize(
    String lessonLogId,
    String status,
  ) async {
    _requireCurrentUid();
    if (!PersonalTrainingLogStatus.finalized.contains(status)) {
      throw const PersonalTrainingLogException(
        PersonalTrainingLogFailure.invalidInput,
      );
    }
    await _loadOwnedLog(lessonLogId);
    return _mutationGateway.finalize(
      lessonLogId: lessonLogId.trim(),
      status: status,
    );
  }

  Future<Map<String, dynamic>> cancelFinalize(String lessonLogId) async {
    _requireCurrentUid();
    await _loadOwnedLog(lessonLogId);
    return _mutationGateway.cancel(lessonLogId.trim());
  }

  Future<String> saveQuickSign({
    required PersonalTrainingLogDraft draft,
    required String status,
  }) async {
    final quickDraft = PersonalTrainingLogDraft(
      memberId: draft.memberId,
      scheduleDocId: draft.scheduleDocId,
      lessonDate: draft.lessonDate,
      startAt: draft.startAt,
      endAt: draft.endAt,
      lessonType: draft.lessonType,
      memo: draft.memo,
      source: 'home_quick_sign',
    );
    final id = await createDraft(quickDraft);
    await finalize(id, status);
    return id;
  }

  Future<void> deleteDraft(String lessonLogId) async {
    _requireCurrentUid();
    final current = await _loadOwnedLog(lessonLogId);
    if (!current.isDraft) {
      throw const PersonalTrainingLogException(
        PersonalTrainingLogFailure.finalized,
      );
    }
    await _dataSource.deleteLog(current.lessonLogId);
  }

  void _requireCurrentUid() {
    final currentUid = _dataSource.currentUid?.trim() ?? '';
    if (currentUid.isEmpty) {
      throw const PersonalTrainingLogException(
        PersonalTrainingLogFailure.unauthenticated,
      );
    }
    if (currentUid != uid.trim()) {
      throw const PersonalTrainingLogException(
        PersonalTrainingLogFailure.trainerMismatch,
      );
    }
  }

  void _validateDraft(PersonalTrainingLogDraft draft) {
    if (draft.memberId.trim().isEmpty ||
        draft.lessonType.trim().isEmpty ||
        !draft.startAt.isBefore(draft.endAt) ||
        !const {'formal', 'home_quick_sign'}.contains(draft.source) ||
        draft.memo.trim().length > 4000) {
      throw const PersonalTrainingLogException(
        PersonalTrainingLogFailure.invalidInput,
      );
    }
  }

  Future<void> _validateMember(String memberId) async {
    final data = await _dataSource.loadMember(memberId.trim());
    if (data == null ||
        data['memberId'] != memberId.trim() ||
        data['trainerId'] != uid ||
        data['workspaceType'] != 'personal' ||
        data['managementState'] == 'deleted') {
      throw const PersonalTrainingLogException(
        PersonalTrainingLogFailure.memberNotOwned,
      );
    }
  }

  Future<void> _validateSchedule(String? scheduleId, String memberId) async {
    final cleanScheduleId = (scheduleId ?? '').trim();
    if (cleanScheduleId.isEmpty) return;
    final data = await _dataSource.loadSchedule(cleanScheduleId);
    if (data == null ||
        data['scheduleId'] != cleanScheduleId ||
        data['trainerId'] != uid ||
        data['workspaceType'] != 'personal') {
      throw const PersonalTrainingLogException(
        PersonalTrainingLogFailure.scheduleNotOwned,
      );
    }
    final linkedMemberId = (data['memberId'] ?? '').toString().trim();
    if (linkedMemberId != memberId.trim()) {
      throw const PersonalTrainingLogException(
        PersonalTrainingLogFailure.scheduleMemberMismatch,
      );
    }
  }

  Future<PersonalTrainingLogRecord> _loadOwnedLog(String lessonLogId) async {
    final record = await _dataSource.loadLog(lessonLogId.trim());
    if (record == null) {
      throw const PersonalTrainingLogException(
        PersonalTrainingLogFailure.recordNotFound,
      );
    }
    if (record.trainerId != uid || record.workspaceType != 'personal') {
      throw const PersonalTrainingLogException(
        PersonalTrainingLogFailure.trainerMismatch,
      );
    }
    return record;
  }
}

class FirebasePersonalTrainingLogDataSource
    implements PersonalTrainingLogDataSource {
  FirebasePersonalTrainingLogDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  String newLogId() => _firestore.collection('training_logs').doc().id;

  @override
  Stream<List<PersonalTrainingLogRecord>> watchMemberRange({
    required String uid,
    required String memberId,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    return _firestore
        .collection('training_logs')
        .where('trainerId', isEqualTo: uid)
        .where('workspaceType', isEqualTo: 'personal')
        .where('memberId', isEqualTo: memberId)
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startAt', isLessThan: Timestamp.fromDate(endExclusive))
        .orderBy('startAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_fromSnapshot).toList());
  }

  @override
  Future<Map<String, dynamic>?> loadMember(String memberId) async =>
      (await _firestore.collection('members').doc(memberId).get()).data();

  @override
  Future<Map<String, dynamic>?> loadSchedule(String scheduleId) async =>
      (await _firestore.collection('schedules').doc(scheduleId).get()).data();

  @override
  Future<PersonalTrainingLogRecord?> loadLog(String lessonLogId) async {
    final snapshot =
        await _firestore.collection('training_logs').doc(lessonLogId).get();
    return snapshot.exists ? _fromSnapshot(snapshot) : null;
  }

  @override
  Future<void> createLog(String lessonLogId, Map<String, dynamic> data) {
    return _firestore.collection('training_logs').doc(lessonLogId).set({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateLog(
    String lessonLogId,
    Map<String, dynamic> changes,
  ) {
    return _firestore.collection('training_logs').doc(lessonLogId).update({
      ...changes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteLog(String lessonLogId) =>
      _firestore.collection('training_logs').doc(lessonLogId).delete();

  PersonalTrainingLogRecord _fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? const <String, dynamic>{};
    DateTime date(dynamic value) => switch (value) {
          Timestamp timestamp => timestamp.toDate(),
          DateTime dateTime => dateTime,
          _ => DateTime.fromMillisecondsSinceEpoch(0),
        };
    return PersonalTrainingLogRecord(
      lessonLogId: snapshot.id,
      trainerId: (data['trainerId'] ?? '').toString(),
      workspaceType: (data['workspaceType'] ?? '').toString(),
      schemaVersion: (data['schemaVersion'] as num?)?.toInt() ?? 0,
      memberId: (data['memberId'] ?? '').toString(),
      scheduleDocId: (data['scheduleDocId'] ?? '').toString().trim().isEmpty
          ? null
          : (data['scheduleDocId'] ?? '').toString().trim(),
      lessonDate: date(data['lessonDate']),
      startAt: date(data['startAt']),
      endAt: date(data['endAt']),
      lessonType: (data['lessonType'] ?? '').toString(),
      status: (data['status'] ?? '').toString(),
      source: (data['source'] ?? '').toString(),
      memo: (data['memo'] ?? '').toString(),
      deductionApplied: data['deductionApplied'] == true,
      createdAt: data['createdAt'] == null ? null : date(data['createdAt']),
      updatedAt: data['updatedAt'] == null ? null : date(data['updatedAt']),
    );
  }
}

class FirebasePersonalTrainingLogMutationGateway
    implements PersonalTrainingLogMutationGateway {
  FirebasePersonalTrainingLogMutationGateway({FirebaseFunctions? functions})
      : _functions = functions ?? MtfFirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, dynamic>> finalize({
    required String lessonLogId,
    required String status,
  }) async {
    final data = await MtfFirebaseFunctions.call(
      'finalizePersonalTrainingLog',
      functions: _functions,
      parameters: {'lessonLogId': lessonLogId, 'status': status},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  @override
  Future<Map<String, dynamic>> cancel(String lessonLogId) async {
    final data = await MtfFirebaseFunctions.call(
      'cancelPersonalTrainingLog',
      functions: _functions,
      parameters: {'lessonLogId': lessonLogId},
    );
    return Map<String, dynamic>.from(data as Map);
  }
}

String personalTrainingLogErrorMessage(Object error) {
  if (error is FirebaseFunctionsException) {
    final message = error.message ?? '';
    if (message.contains('member_') || message.contains('schedule_')) {
      return '현재 작업공간의 회원과 일정 연결을 확인해주세요.';
    }
    if (message.contains('already_finalized_different_status')) {
      return '이미 다른 상태로 확정된 레슨일지예요.';
    }
    if (error.code == 'unauthenticated') {
      return '로그인 상태를 확인한 뒤 다시 시도해주세요.';
    }
    if (error.code == 'permission-denied') {
      return '이 작업공간에서 처리할 수 없는 레슨일지예요.';
    }
  }
  return '레슨일지를 처리하지 못했어요. 잠시 후 다시 시도해주세요.';
}
