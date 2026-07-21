import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/monthly_lesson_record.dart';

abstract interface class MonthlyLessonStatsDataSource {
  String? get currentUid;

  Future<List<MonthlyLessonRecord>> loadMonth({
    required String uid,
    required DateTime start,
    required DateTime endExclusive,
  });
}

class PersonalMonthlyLessonStatsRepository {
  PersonalMonthlyLessonStatsRepository({
    required this.uid,
    MonthlyLessonStatsDataSource? dataSource,
  }) : _dataSource = dataSource ?? FirebaseMonthlyLessonStatsDataSource();

  final String uid;
  final MonthlyLessonStatsDataSource _dataSource;

  Future<MonthlyLessonSummary> loadMonth(DateTime month) async {
    final ownerUid = uid.trim();
    if (ownerUid.isEmpty || _dataSource.currentUid?.trim() != ownerUid) {
      throw StateError('monthly_lesson_owner_mismatch');
    }
    final start = monthlyLessonMonthStart(month);
    final endExclusive = monthlyLessonNextMonthStart(month);
    final records = await _dataSource.loadMonth(
      uid: ownerUid,
      start: start,
      endExclusive: endExclusive,
    );
    return MonthlyLessonSummary(
      records: records
          .where(
            (record) =>
                record.trainerId == ownerUid &&
                record.workspaceType == 'personal' &&
                !record.startAt.isBefore(start) &&
                record.startAt.isBefore(endExclusive),
          )
          .toList(growable: false),
    );
  }
}

class FirebaseMonthlyLessonStatsDataSource
    implements MonthlyLessonStatsDataSource {
  FirebaseMonthlyLessonStatsDataSource({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  @override
  String? get currentUid => _auth.currentUser?.uid;

  @override
  Future<List<MonthlyLessonRecord>> loadMonth({
    required String uid,
    required DateTime start,
    required DateTime endExclusive,
  }) async {
    final snapshot = await _firestore
        .collection('training_logs')
        .where('trainerId', isEqualTo: uid)
        .where('workspaceType', isEqualTo: 'personal')
        .where('startAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startAt', isLessThan: Timestamp.fromDate(endExclusive))
        .orderBy('startAt')
        .get();

    return snapshot.docs
        .map(
          (document) => MonthlyLessonRecord.fromFirestore(
            id: document.id,
            data: document.data(),
          ),
        )
        .toList(growable: false);
  }
}
