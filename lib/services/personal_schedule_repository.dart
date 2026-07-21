import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/personal_schedule.dart';

const _personalScheduleSchemaVersion = 1;
const _personalWorkspaceType = 'personal';

enum PersonalScheduleFailure {
  unauthenticated,
  ownerChanged,
  invalidInput,
  memberNotOwned,
  scheduleNotFound,
  scheduleNotOwned,
  confirmedLocked,
  commitFailed,
}

class PersonalScheduleException implements Exception {
  const PersonalScheduleException(this.failure, [this.cause]);

  final PersonalScheduleFailure failure;
  final Object? cause;
}

class PersonalScheduleWrite {
  const PersonalScheduleWrite({required this.scheduleId, required this.data});

  final String scheduleId;
  final Map<String, dynamic> data;
}

abstract interface class PersonalScheduleDataSource {
  String? get currentUid;

  String newScheduleId();

  Stream<List<PersonalScheduleRecord>> watchRange({
    required String uid,
    required DateTime start,
    required DateTime endExclusive,
  });

  Future<Map<String, dynamic>?> loadMember(String memberId);

  Future<PersonalScheduleRecord?> loadSchedule(String scheduleId);

  Future<void> createMany(List<PersonalScheduleWrite> writes);

  Future<void> updateSchedule(
    String scheduleId,
    Map<String, dynamic> changes,
  );

  Future<void> deleteSchedule(String scheduleId);
}

class PersonalScheduleRepository {
  PersonalScheduleRepository({required this.uid, required this.dataSource});

  final String uid;
  final PersonalScheduleDataSource dataSource;

  Stream<List<PersonalScheduleRecord>> watchRange({
    required DateTime start,
    required DateTime endExclusive,
  }) {
    _requireCurrentOwner();
    if (!endExclusive.isAfter(start)) {
      throw const PersonalScheduleException(
        PersonalScheduleFailure.invalidInput,
      );
    }
    return dataSource.watchRange(
      uid: uid,
      start: start,
      endExclusive: endExclusive,
    );
  }

  Future<String> create(PersonalScheduleDraft draft) async {
    final ids = await createMany([draft]);
    return ids.single;
  }

  Future<List<String>> createMany(List<PersonalScheduleDraft> drafts) async {
    _requireCurrentOwner();
    if (drafts.isEmpty) return const [];
    if (drafts.length > 400) {
      throw const PersonalScheduleException(
        PersonalScheduleFailure.invalidInput,
      );
    }
    final writes = <PersonalScheduleWrite>[];
    for (final draft in drafts) {
      _validateDraft(draft);
      await _validateMember(draft.memberId);
      final generatedId = dataSource.newScheduleId().trim();
      if (generatedId.isEmpty) {
        throw const PersonalScheduleException(
          PersonalScheduleFailure.commitFailed,
        );
      }
      final scheduleId =
          generatedId.startsWith('$uid--') ? generatedId : '$uid--$generatedId';
      writes.add(
        PersonalScheduleWrite(
          scheduleId: scheduleId,
          data: _canonicalData(scheduleId, draft),
        ),
      );
    }
    try {
      await dataSource.createMany(writes);
      return writes.map((write) => write.scheduleId).toList(growable: false);
    } catch (error) {
      if (error is PersonalScheduleException) rethrow;
      throw PersonalScheduleException(
        PersonalScheduleFailure.commitFailed,
        error,
      );
    }
  }

  Future<void> update(
    String scheduleId,
    PersonalScheduleDraft draft,
  ) async {
    _requireCurrentOwner();
    _validateDraft(draft);
    await _validateMember(draft.memberId);
    final existing = await _ownedSchedule(scheduleId);
    if (existing.lessonConfirmed) {
      throw const PersonalScheduleException(
        PersonalScheduleFailure.confirmedLocked,
      );
    }
    await dataSource.updateSchedule(
      existing.scheduleId,
      _mutableData(draft),
    );
  }

  Future<void> move({
    required String scheduleId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    _requireCurrentOwner();
    final existing = await _ownedSchedule(scheduleId);
    if (existing.lessonConfirmed) {
      throw const PersonalScheduleException(
        PersonalScheduleFailure.confirmedLocked,
      );
    }
    final draft = existing.toDraft(startAt: startAt, endAt: endAt);
    _validateDraft(draft);
    await dataSource.updateSchedule(scheduleId, {
      'startAt': draft.startAt,
      'endAt': draft.endAt,
      'dateKey': PersonalScheduleDocumentIdentity.dateKey(draft.startAt),
      'slotKey': PersonalScheduleDocumentIdentity.slotKey(draft.startAt),
    });
  }

  Future<void> delete(String scheduleId) async {
    _requireCurrentOwner();
    final existing = await _ownedSchedule(scheduleId);
    if (existing.lessonConfirmed) {
      throw const PersonalScheduleException(
        PersonalScheduleFailure.confirmedLocked,
      );
    }
    await dataSource.deleteSchedule(existing.scheduleId);
  }

  Future<List<String>> copyToWeek({
    required List<PersonalScheduleRecord> source,
    required DateTime targetMonday,
  }) async {
    _requireCurrentOwner();
    final monday = DateTime(
      targetMonday.year,
      targetMonday.month,
      targetMonday.day,
    ).subtract(Duration(days: targetMonday.weekday - 1));
    final drafts = <PersonalScheduleDraft>[];
    for (final record in source) {
      if (record.trainerId != uid ||
          record.workspaceType != _personalWorkspaceType) {
        throw const PersonalScheduleException(
          PersonalScheduleFailure.scheduleNotOwned,
        );
      }
      final duration = record.endAt.difference(record.startAt);
      final targetStart = monday.add(
        Duration(
          days: record.startAt.weekday - 1,
          hours: record.startAt.hour,
          minutes: record.startAt.minute,
        ),
      );
      drafts.add(
        record.toDraft(
          startAt: targetStart,
          endAt: targetStart.add(duration),
        ),
      );
    }
    return createMany(drafts);
  }

  void _requireCurrentOwner() {
    final current = dataSource.currentUid?.trim() ?? '';
    if (current.isEmpty) {
      throw const PersonalScheduleException(
        PersonalScheduleFailure.unauthenticated,
      );
    }
    if (current != uid) {
      throw const PersonalScheduleException(
          PersonalScheduleFailure.ownerChanged);
    }
  }

  void _validateDraft(PersonalScheduleDraft draft) {
    final name = draft.name.trim();
    final type = draft.type.trim();
    if (name.isEmpty ||
        name.length > 80 ||
        type.isEmpty ||
        type.length > 40 ||
        !draft.endAt.isAfter(draft.startAt) ||
        !const {'scheduled', 'attended', 'cancelled'}.contains(draft.status)) {
      throw const PersonalScheduleException(
        PersonalScheduleFailure.invalidInput,
      );
    }
  }

  Future<void> _validateMember(String? memberId) async {
    final cleanId = memberId?.trim() ?? '';
    if (cleanId.isEmpty) return;
    final member = await dataSource.loadMember(cleanId);
    if (member == null ||
        member['trainerId'] != uid ||
        member['workspaceType'] != _personalWorkspaceType ||
        member['managementState'] == 'deleted') {
      throw const PersonalScheduleException(
        PersonalScheduleFailure.memberNotOwned,
      );
    }
  }

  Future<PersonalScheduleRecord> _ownedSchedule(String scheduleId) async {
    final cleanId = scheduleId.trim();
    if (cleanId.isEmpty) {
      throw const PersonalScheduleException(
        PersonalScheduleFailure.scheduleNotFound,
      );
    }
    final record = await dataSource.loadSchedule(cleanId);
    if (record == null) {
      throw const PersonalScheduleException(
        PersonalScheduleFailure.scheduleNotFound,
      );
    }
    if (record.trainerId != uid ||
        record.workspaceType != _personalWorkspaceType) {
      throw const PersonalScheduleException(
        PersonalScheduleFailure.scheduleNotOwned,
      );
    }
    return record;
  }

  Map<String, dynamic> _canonicalData(
    String scheduleId,
    PersonalScheduleDraft draft,
  ) {
    return {
      'scheduleId': scheduleId,
      'trainerId': uid,
      'workspaceType': _personalWorkspaceType,
      'schemaVersion': _personalScheduleSchemaVersion,
      ..._mutableData(draft),
    };
  }

  Map<String, dynamic> _mutableData(PersonalScheduleDraft draft) {
    final memberId = draft.memberId?.trim() ?? '';
    final phone = draft.phone?.trim() ?? '';
    return {
      'startAt': draft.startAt,
      'endAt': draft.endAt,
      'dateKey': PersonalScheduleDocumentIdentity.dateKey(draft.startAt),
      'slotKey': PersonalScheduleDocumentIdentity.slotKey(draft.startAt),
      'name': draft.name.trim(),
      'type': draft.type.trim(),
      'status': draft.status,
      'memberId': memberId,
      'phone': phone,
      'remainingSessions': draft.remainingSessions,
      'totalSessions': draft.totalSessions,
      'memo': draft.memo.trim(),
      'typeColorHex': draft.typeColorHex.trim(),
    };
  }
}

class FirebasePersonalScheduleDataSource implements PersonalScheduleDataSource {
  FirebasePersonalScheduleDataSource({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _schedules =>
      _firestore.collection('schedules');

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  String newScheduleId() => _schedules.doc().id;

  @override
  Stream<List<PersonalScheduleRecord>> watchRange({
    required String uid,
    required DateTime start,
    required DateTime endExclusive,
  }) {
    _requireUid(uid);
    return _schedules
        .where('trainerId', isEqualTo: uid)
        .where('workspaceType', isEqualTo: _personalWorkspaceType)
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startAt', isLessThan: Timestamp.fromDate(endExclusive))
        .snapshots()
        .map((snapshot) {
      final records = snapshot.docs
          .map((document) => _recordFromSnapshot(document))
          .whereType<PersonalScheduleRecord>()
          .toList()
        ..sort((left, right) => left.startAt.compareTo(right.startAt));
      return records;
    });
  }

  @override
  Future<Map<String, dynamic>?> loadMember(String memberId) async {
    final snapshot = await _firestore.collection('members').doc(memberId).get();
    return snapshot.data();
  }

  @override
  Future<PersonalScheduleRecord?> loadSchedule(String scheduleId) async {
    final snapshot = await _schedules.doc(scheduleId).get();
    return _recordFromSnapshot(snapshot);
  }

  @override
  Future<void> createMany(List<PersonalScheduleWrite> writes) async {
    final uid = _requireSignedIn();
    final batch = _firestore.batch();
    for (final write in writes) {
      final data = Map<String, dynamic>.from(write.data);
      if (data['trainerId'] != uid) {
        throw const PersonalScheduleException(
          PersonalScheduleFailure.ownerChanged,
        );
      }
      batch.set(_schedules.doc(write.scheduleId), {
        ..._firestoreData(data),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> updateSchedule(
    String scheduleId,
    Map<String, dynamic> changes,
  ) async {
    final uid = _requireSignedIn();
    final reference = _schedules.doc(scheduleId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (data == null) {
        throw const PersonalScheduleException(
          PersonalScheduleFailure.scheduleNotFound,
        );
      }
      _validateOwnedMutable(data, uid);
      transaction.update(reference, {
        ..._firestoreData(changes),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  Future<void> deleteSchedule(String scheduleId) async {
    final uid = _requireSignedIn();
    final reference = _schedules.doc(scheduleId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      final data = snapshot.data();
      if (data == null) {
        throw const PersonalScheduleException(
          PersonalScheduleFailure.scheduleNotFound,
        );
      }
      _validateOwnedMutable(data, uid);
      transaction.delete(reference);
    });
  }

  String _requireSignedIn() {
    final uid = currentUid?.trim() ?? '';
    if (uid.isEmpty) {
      throw const PersonalScheduleException(
        PersonalScheduleFailure.unauthenticated,
      );
    }
    return uid;
  }

  void _requireUid(String expectedUid) {
    if (_requireSignedIn() != expectedUid) {
      throw const PersonalScheduleException(
          PersonalScheduleFailure.ownerChanged);
    }
  }

  void _validateOwnedMutable(Map<String, dynamic> data, String uid) {
    if (data['trainerId'] != uid ||
        data['workspaceType'] != _personalWorkspaceType) {
      throw const PersonalScheduleException(
        PersonalScheduleFailure.scheduleNotOwned,
      );
    }
    if (_isConfirmed(data)) {
      throw const PersonalScheduleException(
        PersonalScheduleFailure.confirmedLocked,
      );
    }
  }

  bool _isConfirmed(Map<String, dynamic> data) =>
      data['lessonConfirmed'] == true ||
      data['lessonConfirmedAt'] != null ||
      (data['lessonConfirmStatus'] ?? '').toString().trim().isNotEmpty ||
      (data['trainingLogId'] ?? '').toString().trim().isNotEmpty;

  Map<String, dynamic> _firestoreData(Map<String, dynamic> source) {
    return source.map((key, value) {
      if (value is DateTime) return MapEntry(key, Timestamp.fromDate(value));
      return MapEntry(key, value);
    });
  }

  PersonalScheduleRecord? _recordFromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (data == null) return null;
    final startAt = _dateTime(data['startAt']);
    final endAt = _dateTime(data['endAt']);
    if (startAt == null || endAt == null) return null;
    return PersonalScheduleRecord(
      scheduleId: (data['scheduleId'] ?? snapshot.id).toString(),
      trainerId: (data['trainerId'] ?? '').toString(),
      workspaceType: (data['workspaceType'] ?? '').toString(),
      schemaVersion: (data['schemaVersion'] as num?)?.toInt() ?? 0,
      startAt: startAt,
      endAt: endAt,
      dateKey: (data['dateKey'] ?? '').toString(),
      slotKey: (data['slotKey'] ?? '').toString(),
      name: (data['name'] ?? '').toString(),
      type: (data['type'] ?? 'PT').toString(),
      status: (data['status'] ?? 'scheduled').toString(),
      memberId: _optional(data['memberId']),
      phone: _optional(data['phone']),
      remainingSessions: (data['remainingSessions'] as num?)?.toInt(),
      totalSessions: (data['totalSessions'] as num?)?.toInt(),
      memo: (data['memo'] ?? '').toString(),
      typeColorHex: (data['typeColorHex'] ?? '').toString(),
      createdAt: _dateTime(data['createdAt']),
      updatedAt: _dateTime(data['updatedAt']),
      lessonConfirmed: _isConfirmed(data),
    );
  }

  DateTime? _dateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String? _optional(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
