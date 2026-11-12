import 'package:cloud_firestore/cloud_firestore.dart';

import '../pages/personal_training_log_anatomy/models/anatomy_log.dart';

/// 한 회원의 아나토미 기록을 레슨일지 전체에 걸쳐 읽는 저장소.
abstract interface class AnatomyHistoryStore {
  Future<List<AnatomyLogRecord>> loadMemberRecords({
    required String trainerId,
    required String memberId,
    int limit = 400,
  });
}

/// `anatomyRecords` collection group 조회. 쿼리에 `trainerId == 내 uid` 조건이 있어야
/// 규칙을 통과하고, `trainerId, memberId, recordedAt(내림차순)` 복합 인덱스를 쓴다.
class FirestoreAnatomyHistoryStore implements AnatomyHistoryStore {
  FirestoreAnatomyHistoryStore({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<List<AnatomyLogRecord>> loadMemberRecords({
    required String trainerId,
    required String memberId,
    int limit = 400,
  }) async {
    final snapshot =
        await _firestore
            .collectionGroup('anatomyRecords')
            .where('trainerId', isEqualTo: trainerId.trim())
            .where('memberId', isEqualTo: memberId.trim())
            .orderBy('recordedAt', descending: true)
            .limit(limit)
            .get();
    return [
      for (final doc in snapshot.docs)
        AnatomyLogRecord.fromFirestore(<String, dynamic>{
          ...doc.data(),
          'anatomyLogId': doc.id,
        }),
    ];
  }
}
