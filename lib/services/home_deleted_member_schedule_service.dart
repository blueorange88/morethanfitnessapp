import 'package:cloud_firestore/cloud_firestore.dart';

Set<String> resolveDeletedPersonalMemberIds({
  required Set<String> linkedMemberIds,
  required Map<String, Map<String, dynamic>> ownedMembersById,
}) {
  final deletedMemberIds = <String>{};

  for (final memberId in linkedMemberIds) {
    final member = ownedMembersById[memberId];
    if (member == null) {
      deletedMemberIds.add(memberId);
      continue;
    }

    final isDeleted = member['isDeleted'] == true;
    final deleteStatus = (member['deleteStatus'] ?? '').toString();
    if (isDeleted || deleteStatus == 'pending_delete') {
      deletedMemberIds.add(memberId);
    }
  }

  return deletedMemberIds;
}

bool shouldCleanupDeletedMemberScheduleLinks({
  required bool isFromCache,
  required bool hasPendingWrites,
  required bool hasDeletedMemberIds,
}) {
  return hasDeletedMemberIds && !isFromCache && !hasPendingWrites;
}

class HomeDeletedMemberScheduleService {
  HomeDeletedMemberScheduleService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _members =>
      _db.collection('members');

  static CollectionReference<Map<String, dynamic>> get _schedules =>
      _db.collection('schedules');

  static Future<Set<String>> deletedMemberIdsFromScheduleDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required String personalOwnerUid,
  }) async {
    final ownerUid = personalOwnerUid.trim();
    if (ownerUid.isEmpty) return <String>{};

    final memberIds = <String>{};
    for (final doc in docs) {
      final data = doc.data();
      final memberId = (data['memberId'] ?? '').toString().trim();

      if (memberId.isEmpty || data['linkedMemberDeleted'] == true) continue;
      memberIds.add(memberId);
    }

    if (memberIds.isEmpty) return <String>{};

    final snapshot = await _members
        .where('trainerId', isEqualTo: ownerUid)
        .where('workspaceType', isEqualTo: 'personal')
        .get();

    final ownedMembersById = <String, Map<String, dynamic>>{
      for (final doc in snapshot.docs)
        if (memberIds.contains(doc.id)) doc.id: doc.data(),
    };

    return resolveDeletedPersonalMemberIds(
      linkedMemberIds: memberIds,
      ownedMembersById: ownedMembersById,
    );
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

    final snap =
        await _schedules.where('memberId', isEqualTo: cleanMemberId).get();

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
