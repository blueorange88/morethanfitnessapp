import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../pages/personal_training_log_anatomy/models/anatomy_log.dart';

enum AnatomyLogErrorCode {
  unauthenticated('unauthenticated'),
  trainerMismatch('trainer_mismatch'),
  parentNotFound('parent_not_found'),
  legacyParentMissingIdentity('legacy_parent_missing_identity'),
  memberMismatch('member_mismatch'),
  scheduleMismatch('schedule_mismatch'),
  pathLessonLogMismatch('path_lesson_log_mismatch'),
  immutableIdentityChange('immutable_identity_change'),
  recordNotFound('record_not_found'),
  permissionDenied('permission_denied'),
  unknown('unknown');

  const AnatomyLogErrorCode(this.value);
  final String value;
}

class AnatomyLogException implements Exception {
  const AnatomyLogException(this.code, {this.cause});

  final AnatomyLogErrorCode code;
  final Object? cause;

  @override
  String toString() => 'AnatomyLogException(${code.value})';
}

class AnatomyLogSaveContext {
  const AnatomyLogSaveContext({
    required this.lessonLogId,
    required this.trainerId,
    required this.memberId,
    this.scheduleDocId = '',
  });

  final String lessonLogId;
  final String trainerId;
  final String memberId;
  final String scheduleDocId;

  List<String> get missingFields => <String>[
        if (lessonLogId.trim().isEmpty) 'lessonLogId',
        if (memberId.trim().isEmpty) 'memberId',
        if (trainerId.trim().isEmpty) 'trainerId',
      ];

  bool get isValid => missingFields.isEmpty;
}

class AnatomyLogDocument {
  const AnatomyLogDocument({required this.id, required this.data});

  final String id;
  final Map<String, dynamic> data;
}

abstract interface class AnatomyLogTransaction {
  Future<Map<String, dynamic>?> getParent(String lessonLogId);

  Future<Map<String, dynamic>?> getRecord(
    String lessonLogId,
    String anatomyLogId,
  );

  void updateParent(String lessonLogId, Map<String, dynamic> data);

  void createRecord(
    String lessonLogId,
    String anatomyLogId,
    Map<String, dynamic> data,
  );

  void updateRecord(
    String lessonLogId,
    String anatomyLogId,
    Map<String, dynamic> data,
  );

  void deleteRecord(String lessonLogId, String anatomyLogId);
}

abstract interface class AnatomyLogStore {
  String newRecordId(String lessonLogId);

  Future<Map<String, dynamic>?> getParent(String lessonLogId);

  Future<List<AnatomyLogDocument>> getRecords(String lessonLogId);

  Future<T> runTransaction<T>(
    Future<T> Function(AnatomyLogTransaction transaction) action,
  );
}

typedef AnatomyCurrentUid = String? Function();

class AnatomyLogService {
  AnatomyLogService({
    FirebaseFirestore? firestore,
    AnatomyLogStore? store,
    AnatomyCurrentUid? currentUid,
  })  : assert(firestore == null || store == null),
        _store = store ??
            _FirestoreAnatomyLogStore(
              firestore ?? FirebaseFirestore.instance,
            ),
        _currentUid =
            currentUid ?? (() => FirebaseAuth.instance.currentUser?.uid);

  final AnatomyLogStore _store;
  final AnatomyCurrentUid _currentUid;

  Future<List<AnatomyLogRecord>> load({
    required String lessonLogId,
    required String trainerId,
    required String memberId,
    String scheduleDocId = '',
  }) async {
    final context = AnatomyLogSaveContext(
      lessonLogId: lessonLogId.trim(),
      trainerId: trainerId.trim(),
      memberId: memberId.trim(),
      scheduleDocId: scheduleDocId.trim(),
    );
    _validateActor(context.trainerId);
    _validateContext(context);

    try {
      final parent = await _store.getParent(context.lessonLogId);
      _validateParent(parent, context);
      final documents = await _store.getRecords(context.lessonLogId);
      final records = <AnatomyLogRecord>[];

      for (final document in documents) {
        try {
          _validateStoredRecord(
            document.id,
            document.data,
            context,
            parent!,
          );
          records.add(
            AnatomyLogRecord.fromFirestore(
              Map<String, dynamic>.from(document.data)
                ..['anatomyLogId'] = document.id,
            ),
          );
        } on AnatomyLogException catch (error) {
          _logIntegrityError(error.code, 'load_child_skipped');
        }
      }

      if (records.isEmpty) {
        records.addAll(_decodeLegacyRecords(parent!, context));
      }
      return AnatomyRecordCollection.sorted(records);
    } catch (error) {
      throw _translate(error);
    }
  }

  String newRecordId(String lessonLogId) =>
      _store.newRecordId(lessonLogId.trim());

  Future<List<AnatomyLogRecord>> save({
    required String lessonLogId,
    required String trainerId,
    required String memberId,
    String scheduleDocId = '',
    required List<AnatomyLogRecord> records,
    required Set<String> deletedRecordIds,
  }) async {
    final context = AnatomyLogSaveContext(
      lessonLogId: lessonLogId.trim(),
      trainerId: trainerId.trim(),
      memberId: memberId.trim(),
      scheduleDocId: scheduleDocId.trim(),
    );
    _validateActor(context.trainerId);
    _validateContext(context);

    final resolved = records.map((record) {
      if (record.anatomyLogId.trim().isNotEmpty) return record;
      return record.copyWith(
        anatomyLogId: _store.newRecordId(context.lessonLogId),
      );
    }).toList(growable: false);
    final ids = resolved.map((record) => record.anatomyLogId).toList();
    if (ids.toSet().length != ids.length ||
        ids.any(deletedRecordIds.contains)) {
      throw const AnatomyLogException(
        AnatomyLogErrorCode.immutableIdentityChange,
      );
    }

    try {
      await _store.runTransaction((transaction) async {
        final parent = await transaction.getParent(context.lessonLogId);
        _validateParent(parent, context);
        final validatedParent = parent!;

        final existing = <String, Map<String, dynamic>?>{};
        for (final id in <String>{...ids, ...deletedRecordIds}) {
          if (id.trim().isEmpty) continue;
          existing[id] = await transaction.getRecord(context.lessonLogId, id);
        }

        for (final record in resolved) {
          final previous = existing[record.anatomyLogId];
          if (previous != null) {
            _validateStoredRecord(
              record.anatomyLogId,
              previous,
              context,
              validatedParent,
            );
            _validateImmutableIdentity(previous, record);
          }
          _validateIncomingRecord(record, context, validatedParent);
        }

        for (final id in deletedRecordIds.where((id) => id.trim().isNotEmpty)) {
          final previous = existing[id];
          if (previous == null) {
            throw const AnatomyLogException(
              AnatomyLogErrorCode.recordNotFound,
            );
          }
          _validateStoredRecord(id, previous, context, validatedParent);
        }

        for (final record in resolved) {
          final previous = existing[record.anatomyLogId];
          if (previous == null) {
            transaction.createRecord(
              context.lessonLogId,
              record.anatomyLogId,
              _createData(record),
            );
          } else {
            transaction.updateRecord(
              context.lessonLogId,
              record.anatomyLogId,
              _mutableData(record),
            );
          }
        }
        for (final id in deletedRecordIds.where((id) => id.trim().isNotEmpty)) {
          transaction.deleteRecord(context.lessonLogId, id);
        }

        final parentUpdate = <String, dynamic>{
          'anatomySchemaVersion': 1,
          'hasAnatomyRecords': resolved.isNotEmpty,
          'anatomyRecordCount': resolved.length,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (validatedParent.containsKey('anatomyRecords')) {
          parentUpdate['anatomyRecords'] = FieldValue.delete();
        }
        transaction.updateParent(context.lessonLogId, parentUpdate);
      });
      return resolved;
    } catch (error) {
      throw _translate(error);
    }
  }

  void _validateContext(AnatomyLogSaveContext context) {
    if (context.lessonLogId.isEmpty) {
      throw const AnatomyLogException(
        AnatomyLogErrorCode.pathLessonLogMismatch,
      );
    }
    if (context.trainerId.isEmpty) {
      throw const AnatomyLogException(AnatomyLogErrorCode.trainerMismatch);
    }
    if (context.memberId.isEmpty) {
      throw const AnatomyLogException(AnatomyLogErrorCode.memberMismatch);
    }
  }

  void _validateActor(String trainerId) {
    final uid = (_currentUid() ?? '').trim();
    if (uid.isEmpty) {
      throw const AnatomyLogException(AnatomyLogErrorCode.unauthenticated);
    }
    if (uid != trainerId) {
      throw const AnatomyLogException(AnatomyLogErrorCode.trainerMismatch);
    }
  }

  void _validateParent(
    Map<String, dynamic>? parent,
    AnatomyLogSaveContext context,
  ) {
    if (parent == null) {
      throw const AnatomyLogException(AnatomyLogErrorCode.parentNotFound);
    }
    final parentTrainerId = _text(parent['trainerId']);
    final parentMemberId = _text(parent['memberId']);
    if (parentTrainerId.isEmpty || parentMemberId.isEmpty) {
      throw const AnatomyLogException(
        AnatomyLogErrorCode.legacyParentMissingIdentity,
      );
    }
    if (parentTrainerId != context.trainerId) {
      throw const AnatomyLogException(AnatomyLogErrorCode.trainerMismatch);
    }
    if (parentMemberId != context.memberId) {
      throw const AnatomyLogException(AnatomyLogErrorCode.memberMismatch);
    }
    final parentScheduleId = _text(parent['scheduleDocId']);
    if (parentScheduleId.isNotEmpty &&
        context.scheduleDocId.isNotEmpty &&
        parentScheduleId != context.scheduleDocId) {
      throw const AnatomyLogException(AnatomyLogErrorCode.scheduleMismatch);
    }
  }

  void _validateIncomingRecord(
    AnatomyLogRecord record,
    AnatomyLogSaveContext context,
    Map<String, dynamic> parent,
  ) {
    if (record.anatomyLogId.trim().isEmpty ||
        record.lessonLogId.trim() != context.lessonLogId) {
      throw const AnatomyLogException(
        AnatomyLogErrorCode.pathLessonLogMismatch,
      );
    }
    if (record.trainerId.trim() != context.trainerId) {
      throw const AnatomyLogException(AnatomyLogErrorCode.trainerMismatch);
    }
    if (record.memberId.trim() != context.memberId) {
      throw const AnatomyLogException(AnatomyLogErrorCode.memberMismatch);
    }
    _validateSchedule(record.scheduleDocId, context, parent);
  }

  void _validateStoredRecord(
    String documentId,
    Map<String, dynamic> data,
    AnatomyLogSaveContext context,
    Map<String, dynamic> parent,
  ) {
    final storedId = _text(data['anatomyLogId']);
    if (storedId != documentId) {
      throw const AnatomyLogException(
        AnatomyLogErrorCode.immutableIdentityChange,
      );
    }
    if (_text(data['lessonLogId']) != context.lessonLogId) {
      throw const AnatomyLogException(
        AnatomyLogErrorCode.pathLessonLogMismatch,
      );
    }
    if (_text(data['trainerId']) != context.trainerId) {
      throw const AnatomyLogException(AnatomyLogErrorCode.trainerMismatch);
    }
    if (_text(data['memberId']) != context.memberId) {
      throw const AnatomyLogException(AnatomyLogErrorCode.memberMismatch);
    }
    _validateSchedule(_text(data['scheduleDocId']), context, parent);
  }

  void _validateSchedule(
    String recordScheduleId,
    AnatomyLogSaveContext context,
    Map<String, dynamic> parent,
  ) {
    final parentScheduleId = _text(parent['scheduleDocId']);
    if (parentScheduleId.isNotEmpty &&
        recordScheduleId.trim().isNotEmpty &&
        parentScheduleId != recordScheduleId.trim()) {
      throw const AnatomyLogException(AnatomyLogErrorCode.scheduleMismatch);
    }
    if (context.scheduleDocId.isNotEmpty &&
        recordScheduleId.trim().isNotEmpty &&
        context.scheduleDocId != recordScheduleId.trim()) {
      throw const AnatomyLogException(AnatomyLogErrorCode.scheduleMismatch);
    }
  }

  void _validateImmutableIdentity(
    Map<String, dynamic> previous,
    AnatomyLogRecord next,
  ) {
    final previousCreatedAt =
        AnatomyLogRecord.fromFirestore(previous).createdAt;
    if (_text(previous['anatomyLogId']) != next.anatomyLogId ||
        _text(previous['lessonLogId']) != next.lessonLogId ||
        _text(previous['trainerId']) != next.trainerId ||
        _text(previous['memberId']) != next.memberId ||
        previousCreatedAt != next.createdAt) {
      throw const AnatomyLogException(
        AnatomyLogErrorCode.immutableIdentityChange,
      );
    }
    final previousScheduleId = _text(previous['scheduleDocId']);
    if (previousScheduleId.isNotEmpty &&
        previousScheduleId != next.scheduleDocId.trim()) {
      throw const AnatomyLogException(
        AnatomyLogErrorCode.immutableIdentityChange,
      );
    }
  }

  List<AnatomyLogRecord> _decodeLegacyRecords(
    Map<String, dynamic> parent,
    AnatomyLogSaveContext context,
  ) {
    final decoded = AnatomyRecordCollection.decode(parent['anatomyRecords']);
    final records = <AnatomyLogRecord>[];
    for (final record in decoded) {
      if (record.anatomyLogId.trim().isEmpty) {
        _logIntegrityError(
          AnatomyLogErrorCode.immutableIdentityChange,
          'load_legacy_child_skipped',
        );
        continue;
      }
      final normalized = record.copyWith(
        trainerId:
            record.trainerId.isEmpty ? context.trainerId : record.trainerId,
        memberId: record.memberId.isEmpty ? context.memberId : record.memberId,
        lessonLogId: record.lessonLogId.isEmpty
            ? context.lessonLogId
            : record.lessonLogId,
      );
      try {
        _validateIncomingRecord(normalized, context, parent);
        records.add(normalized);
      } on AnatomyLogException catch (error) {
        _logIntegrityError(error.code, 'load_legacy_child_skipped');
      }
    }
    return records;
  }

  Map<String, dynamic> _createData(AnatomyLogRecord record) =>
      <String, dynamic>{
        ...record.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Map<String, dynamic> _mutableData(AnatomyLogRecord record) =>
      <String, dynamic>{
        'recordedAt': Timestamp.fromDate(record.recordedAt),
        'bodyGender': record.bodyGender.name,
        'bodyView': record.bodyView.name,
        'bodySide': record.bodySide.name,
        'bodyPartId': record.bodyPartId,
        'bodyPartLabel': record.bodyPartLabel,
        'recordType': record.recordType.name,
        'exerciseName': record.exerciseName,
        'painLevel': record.painLevel.clamp(0, 10),
        'memo': record.memo,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  AnatomyLogException _translate(Object error) {
    if (error is AnatomyLogException) return error;
    if (error is FirebaseException && error.code == 'permission-denied') {
      return AnatomyLogException(
        AnatomyLogErrorCode.permissionDenied,
        cause: error,
      );
    }
    return AnatomyLogException(AnatomyLogErrorCode.unknown, cause: error);
  }

  void _logIntegrityError(AnatomyLogErrorCode code, String action) {
    debugPrint(
      '[MTF_ANATOMY_INTEGRITY] action=$action code=${code.value}',
    );
  }

  static String _text(dynamic value) => (value ?? '').toString().trim();
}

class _FirestoreAnatomyLogStore implements AnatomyLogStore {
  _FirestoreAnatomyLogStore(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _parent(String lessonLogId) =>
      _firestore.collection('training_logs').doc(lessonLogId);

  CollectionReference<Map<String, dynamic>> _records(String lessonLogId) =>
      _parent(lessonLogId).collection('anatomyRecords');

  @override
  String newRecordId(String lessonLogId) => _records(lessonLogId).doc().id;

  @override
  Future<Map<String, dynamic>?> getParent(String lessonLogId) async {
    final snapshot = await _parent(lessonLogId).get();
    return snapshot.exists ? snapshot.data() : null;
  }

  @override
  Future<List<AnatomyLogDocument>> getRecords(String lessonLogId) async {
    final snapshot = await _records(lessonLogId).get();
    return snapshot.docs
        .map(
          (document) => AnatomyLogDocument(
            id: document.id,
            data: document.data(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<T> runTransaction<T>(
    Future<T> Function(AnatomyLogTransaction transaction) action,
  ) =>
      _firestore.runTransaction(
        (transaction) => action(
          _FirestoreAnatomyLogTransaction(_firestore, transaction),
        ),
      );
}

class _FirestoreAnatomyLogTransaction implements AnatomyLogTransaction {
  _FirestoreAnatomyLogTransaction(this._firestore, this._transaction);

  final FirebaseFirestore _firestore;
  final Transaction _transaction;

  DocumentReference<Map<String, dynamic>> _parent(String lessonLogId) =>
      _firestore.collection('training_logs').doc(lessonLogId);

  DocumentReference<Map<String, dynamic>> _record(
    String lessonLogId,
    String anatomyLogId,
  ) =>
      _parent(lessonLogId).collection('anatomyRecords').doc(anatomyLogId);

  @override
  Future<Map<String, dynamic>?> getParent(String lessonLogId) async {
    final snapshot = await _transaction.get(_parent(lessonLogId));
    return snapshot.exists ? snapshot.data() : null;
  }

  @override
  Future<Map<String, dynamic>?> getRecord(
    String lessonLogId,
    String anatomyLogId,
  ) async {
    final snapshot = await _transaction.get(
      _record(lessonLogId, anatomyLogId),
    );
    return snapshot.exists ? snapshot.data() : null;
  }

  @override
  void updateParent(String lessonLogId, Map<String, dynamic> data) {
    _transaction.update(_parent(lessonLogId), data);
  }

  @override
  void createRecord(
    String lessonLogId,
    String anatomyLogId,
    Map<String, dynamic> data,
  ) {
    _transaction.set(_record(lessonLogId, anatomyLogId), data);
  }

  @override
  void updateRecord(
    String lessonLogId,
    String anatomyLogId,
    Map<String, dynamic> data,
  ) {
    _transaction.update(_record(lessonLogId, anatomyLogId), data);
  }

  @override
  void deleteRecord(String lessonLogId, String anatomyLogId) {
    _transaction.delete(_record(lessonLogId, anatomyLogId));
  }
}
