import 'package:cloud_firestore/cloud_firestore.dart';

class HomeDeletedMemberScheduleService {
  HomeDeletedMemberScheduleService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _members =>
      _db.collection('members');

  static CollectionReference<Map<String, dynamic>> get _schedules =>
      _db.collection('schedules');

  static Future<Set<String>> deletedMemberIdsFromScheduleDocs(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      ) async {
    final memberIds = <String>{};

    for (final doc in docs) {
      final data = doc.data();

      final memberId = (data['memberId'] ?? '').toString().trim();

      if (memberId.isEmpty) continue;
      if (data['linkedMemberDeleted'] == true) continue;

      memberIds.add(memberId);
    }

    if (memberIds.isEmpty) return <String>{};

    final deletedIds = <String>{};
    final ids = memberIds.toList();

    for (int i = 0; i < ids.length; i += 10) {
      final chunk = ids.skip(i).take(10).toList();

      final snapshot = await _members
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      final foundIds = snapshot.docs.map((doc) => doc.id).toSet();

      // 문서 자체가 없는 회원도 삭제된 회원처럼 취급
      for (final id in chunk) {
        if (!foundIds.contains(id)) {
          deletedIds.add(id);
        }
      }

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final isDeleted = data['isDeleted'] == true;
        final deleteStatus = (data['deleteStatus'] ?? '').toString();

        if (isDeleted || deleteStatus == 'pending_delete') {
          deletedIds.add(doc.id);
        }
      }
    }

    return deletedIds;
  }

  static Future<void> cleanupDeletedMemberScheduleLinks({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required Set<String> deletedMemberIds,
  }) async {
    if (deletedMemberIds.isEmpty) return;

    var batch = _db.batch();
    var count = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (count == 0) return;
      if (!force && count < 450) return;

      await batch.commit();
      batch = _db.batch();
      count = 0;
    }

    for (final doc in docs) {
      final data = doc.data();
      final memberId = (data['memberId'] ?? '').toString().trim();

      if (memberId.isEmpty) continue;
      if (!deletedMemberIds.contains(memberId)) continue;

      batch.set(
        doc.reference,
        {
          'memberId': FieldValue.delete(),
          'phone': FieldValue.delete(),
          'totalSessions': FieldValue.delete(),
          'remainingSessions': FieldValue.delete(),
          'remainSessions': FieldValue.delete(),

          'sessionSnapshotTotal': FieldValue.delete(),
          'sessionSnapshotRemainBefore': FieldValue.delete(),
          'sessionSnapshotRemainAfter': FieldValue.delete(),
          'sessionSnapshotDoneBefore': FieldValue.delete(),
          'sessionSnapshotDoneAfter': FieldValue.delete(),
          'sessionSnapshotLessonNumber': FieldValue.delete(),
          'sessionSnapshotLabel': FieldValue.delete(),

          'linkedMemberDeleted': true,
          'deletedMemberId': memberId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      count++;
      await commitIfNeeded();
    }

    await commitIfNeeded(force: true);
  }

  static Future<void> unlinkSchedulesByMemberId(String memberId) async {
    final cleanMemberId = memberId.trim();
    if (cleanMemberId.isEmpty) return;

    final snap = await _schedules
        .where('memberId', isEqualTo: cleanMemberId)
        .get();

    if (snap.docs.isEmpty) return;

    var batch = _db.batch();
    var count = 0;

    Future<void> commitIfNeeded({bool force = false}) async {
      if (count == 0) return;
      if (!force && count < 450) return;

      await batch.commit();
      batch = _db.batch();
      count = 0;
    }

    for (final doc in snap.docs) {
      batch.set(
        doc.reference,
        {
          'memberId': FieldValue.delete(),
          'phone': FieldValue.delete(),
          'totalSessions': FieldValue.delete(),
          'remainingSessions': FieldValue.delete(),
          'remainSessions': FieldValue.delete(),
          'linkedMemberDeleted': true,
          'deletedMemberId': cleanMemberId,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      count++;
      await commitIfNeeded();
    }

    await commitIfNeeded(force: true);
  }
}