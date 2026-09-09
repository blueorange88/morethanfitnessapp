import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/personal_member_taxonomy.dart';
import 'mtf_firebase_functions.dart';

class PersonalMemberTaxonomyDeleteResult {
  const PersonalMemberTaxonomyDeleteResult({
    required this.affectedMemberCount,
  });

  final int affectedMemberCount;
}

class PersonalMemberAssignmentResult {
  const PersonalMemberAssignmentResult({
    required this.memberId,
    required this.readbackSucceeded,
    required this.snapshotObserved,
  });

  final String memberId;
  final bool readbackSucceeded;
  final bool snapshotObserved;
}

class PersonalMemberTaxonomyService {
  PersonalMemberTaxonomyService({
    required String uid,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : uid = uid.trim(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? MtfFirebaseFunctions.instance;

  final String uid;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  DocumentReference<Map<String, dynamic>> get _profileRef =>
      _firestore.collection('trainer_profiles').doc(uid);

  CollectionReference<Map<String, dynamic>> _collection(
    PersonalMemberTaxonomyKind kind,
  ) {
    return _profileRef.collection(
      kind == PersonalMemberTaxonomyKind.group
          ? 'personal_groups'
          : 'personal_tags',
    );
  }

  Stream<List<PersonalMemberTaxonomyItem>> watch(
    PersonalMemberTaxonomyKind kind,
  ) {
    return _collection(kind).orderBy('createdAt').snapshots().map(
          (snapshot) => snapshot.docs
              .map(
                (document) => PersonalMemberTaxonomyItem.fromFirestore(
                  kind: kind,
                  document: document,
                ),
              )
              .toList(growable: false),
        );
  }

  Future<List<PersonalMemberTaxonomyItem>> loadFromServer(
    PersonalMemberTaxonomyKind kind,
  ) async {
    final snapshot = await _collection(kind).orderBy('createdAt').get(
          const GetOptions(source: Source.server),
        );
    return snapshot.docs
        .map(
          (document) => PersonalMemberTaxonomyItem.fromFirestore(
            kind: kind,
            document: document,
          ),
        )
        .toList(growable: false);
  }

  Future<PersonalMemberTaxonomyItem> create({
    required PersonalMemberTaxonomyKind kind,
    required String idempotencyKey,
    required String name,
  }) async {
    _validateName(name);
    final functionName = kind == PersonalMemberTaxonomyKind.group
        ? 'createPersonalGroup'
        : 'createPersonalTag';
    final response = await _call(functionName, {
      'idempotencyKey': idempotencyKey,
      'name': normalizePersonalTaxonomyDisplayName(name),
    });
    final id = _responseId(response, kind);
    return _readback(kind, id);
  }

  Future<PersonalMemberTaxonomyItem> rename({
    required PersonalMemberTaxonomyKind kind,
    required String id,
    required String name,
  }) async {
    _validateName(name);
    final functionName = kind == PersonalMemberTaxonomyKind.group
        ? 'renamePersonalGroup'
        : 'renamePersonalTag';
    final idKey = kind == PersonalMemberTaxonomyKind.group
        ? 'personalGroupId'
        : 'personalTagId';
    final response = await _call(functionName, {
      idKey: id.trim(),
      'name': normalizePersonalTaxonomyDisplayName(name),
    });
    if (_responseId(response, kind) != id.trim()) {
      throw StateError('personal_taxonomy_response_mismatch');
    }
    return _readback(kind, id.trim());
  }

  Future<PersonalMemberTaxonomyDeleteResult> delete({
    required PersonalMemberTaxonomyKind kind,
    required String id,
  }) async {
    final functionName = kind == PersonalMemberTaxonomyKind.group
        ? 'deletePersonalGroup'
        : 'deletePersonalTag';
    final idKey = kind == PersonalMemberTaxonomyKind.group
        ? 'personalGroupId'
        : 'personalTagId';
    final response = await _call(functionName, {idKey: id.trim()});
    if (_responseId(response, kind) != id.trim() ||
        response['deleted'] != true) {
      throw StateError('personal_taxonomy_delete_response_mismatch');
    }
    final deleted = await _collection(kind).doc(id.trim()).get(
          const GetOptions(source: Source.server),
        );
    if (deleted.exists) {
      throw StateError('personal_taxonomy_delete_readback_mismatch');
    }
    await _verifyMemberCleanup(kind, id.trim());
    return PersonalMemberTaxonomyDeleteResult(
      affectedMemberCount:
          (response['affectedMemberCount'] as num?)?.toInt() ?? 0,
    );
  }

  Future<PersonalMemberAssignmentResult> assignMemberAndVerify({
    required String memberId,
    required PersonalMemberAssignmentPatch assignments,
  }) async {
    final assignmentFields = assignments.toCallableMap();
    if (assignmentFields.isEmpty) {
      throw ArgumentError('personal_assignment_empty');
    }
    final response = await _call('updateManagedMember', {
      'memberId': memberId.trim(),
      ...assignmentFields,
    });
    if (response['updated'] != true ||
        response['memberId'] != memberId.trim()) {
      throw StateError('personal_assignment_response_mismatch');
    }
    final document = await _firestore
        .collection('members')
        .doc(memberId.trim())
        .get(const GetOptions(source: Source.server));
    final member = document.data();
    if (!document.exists ||
        member == null ||
        member['memberId'] != memberId.trim() ||
        member['trainerId'] != uid ||
        member['workspaceType'] != 'personal' ||
        !assignments.matchesMember(member)) {
      throw StateError('personal_assignment_readback_mismatch');
    }
    final snapshotObserved = await _firestore
        .collection('members')
        .doc(memberId.trim())
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data();
          return snapshot.exists &&
              data != null &&
              data['trainerId'] == uid &&
              data['workspaceType'] == 'personal' &&
              assignments.matchesMember(data);
        })
        .firstWhere((observed) => observed)
        .timeout(const Duration(seconds: 12));
    return PersonalMemberAssignmentResult(
      memberId: memberId.trim(),
      readbackSucceeded: true,
      snapshotObserved: snapshotObserved,
    );
  }

  Future<Map<String, dynamic>> _call(
    String functionName,
    Map<String, dynamic> parameters,
  ) async {
    final response = await MtfFirebaseFunctions.call(
      functionName,
      functions: _functions,
      parameters: parameters,
    );
    if (response is! Map) {
      throw StateError('personal_taxonomy_response_invalid');
    }
    return Map<String, dynamic>.from(response);
  }

  String _responseId(
    Map<String, dynamic> response,
    PersonalMemberTaxonomyKind kind,
  ) {
    final key = kind == PersonalMemberTaxonomyKind.group
        ? 'personalGroupId'
        : 'personalTagId';
    final id = (response[key] ?? '').toString().trim();
    if (id.isEmpty) {
      throw StateError('personal_taxonomy_id_missing');
    }
    return id;
  }

  Future<PersonalMemberTaxonomyItem> _readback(
    PersonalMemberTaxonomyKind kind,
    String id,
  ) async {
    final document = await _collection(kind).doc(id).get(
          const GetOptions(source: Source.server),
        );
    return PersonalMemberTaxonomyItem.fromFirestore(
      kind: kind,
      document: document,
    );
  }

  Future<void> _verifyMemberCleanup(
    PersonalMemberTaxonomyKind kind,
    String id,
  ) async {
    final members = await _firestore
        .collection('members')
        .where('trainerId', isEqualTo: uid)
        .where('workspaceType', isEqualTo: 'personal')
        .get(const GetOptions(source: Source.server));
    final hasStaleReference = members.docs.any((document) {
      final member = document.data();
      if (kind == PersonalMemberTaxonomyKind.group) {
        return (member['personalGroupId'] ?? '').toString().trim() == id;
      }
      final tags = member['personalTagIds'];
      return tags is Iterable &&
          tags.map((value) => value.toString()).contains(id);
    });
    if (hasStaleReference) {
      throw StateError('personal_taxonomy_member_cleanup_mismatch');
    }
  }

  void _validateName(String name) {
    final error = validatePersonalTaxonomyName(name);
    if (error != null) throw ArgumentError(error);
  }
}
