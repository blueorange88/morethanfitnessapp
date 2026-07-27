import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'mtf_firebase_functions.dart';
import '../utils/member_input_validation.dart';

@visibleForTesting
String personalMemberGenderForSave(String value) {
  switch (value.trim().toLowerCase()) {
    case '남':
    case '남성':
    case '남자':
    case 'male':
    case 'm':
      return 'male';
    case '여':
    case '여성':
    case '여자':
    case 'female':
    case 'f':
      return 'female';
    default:
      throw ArgumentError.value(value, 'gender', 'gender_invalid');
  }
}

@visibleForTesting
String personalMemberBirthDateForSave(String value) {
  final result = normalizeAndValidateMemberBirthDate(
    value,
    required: true,
  );
  if (!result.isValid || result.normalizedText == null) {
    throw ArgumentError.value(value, 'birthDate', 'birth_date_invalid');
  }
  return result.normalizedText!;
}

enum PersonalMemberGroupSelectionType {
  canonicalDefault,
  canonicalCustom,
  virtual,
  legacyOrMissing,
  otherOwner,
}

class PersonalMemberGroupSelection {
  const PersonalMemberGroupSelection({
    required this.type,
    required this.groupId,
    required this.isValid,
    required this.fallbackApplied,
  });

  final PersonalMemberGroupSelectionType type;
  final String? groupId;
  final bool isValid;
  final bool fallbackApplied;
}

@visibleForTesting
PersonalMemberGroupSelection normalizePersonalMemberGroupSelection({
  required String? selectedGroupId,
  Set<String> canonicalCustomGroupIds = const <String>{},
  Set<String> otherOwnerGroupIds = const <String>{},
}) {
  final selected = (selectedGroupId ?? '').trim();
  if (selected.isEmpty || selected == '__ungrouped__') {
    return const PersonalMemberGroupSelection(
      type: PersonalMemberGroupSelectionType.canonicalDefault,
      groupId: null,
      isValid: true,
      fallbackApplied: false,
    );
  }
  if (otherOwnerGroupIds.contains(selected)) {
    return const PersonalMemberGroupSelection(
      type: PersonalMemberGroupSelectionType.otherOwner,
      groupId: null,
      isValid: false,
      fallbackApplied: false,
    );
  }
  if (canonicalCustomGroupIds.contains(selected)) {
    return PersonalMemberGroupSelection(
      type: PersonalMemberGroupSelectionType.canonicalCustom,
      groupId: selected,
      isValid: true,
      fallbackApplied: false,
    );
  }
  if (selected == '__all__' ||
      selected == '__system_dormant__' ||
      selected == '__system_expired__') {
    return const PersonalMemberGroupSelection(
      type: PersonalMemberGroupSelectionType.virtual,
      groupId: null,
      isValid: true,
      fallbackApplied: true,
    );
  }
  return const PersonalMemberGroupSelection(
    type: PersonalMemberGroupSelectionType.legacyOrMissing,
    groupId: null,
    isValid: true,
    fallbackApplied: true,
  );
}

class PersonalMemberCardSaveResult {
  const PersonalMemberCardSaveResult({
    required this.memberId,
    required this.readbackSucceeded,
    required this.snapshotObserved,
    required this.groupSelection,
  });

  final String memberId;
  final bool readbackSucceeded;
  final bool snapshotObserved;
  final PersonalMemberGroupSelection groupSelection;
}

class PersonalMemberCardSaveService {
  PersonalMemberCardSaveService({
    required this.uid,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? MtfFirebaseFunctions.instance;

  final String uid;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<PersonalMemberCardSaveResult> createAndVerify({
    required String idempotencyKey,
    required String name,
    required String gender,
    required String birthDate,
    required String phone,
    required String postal,
    required String address,
    required String detailAddress,
    required String lessonType,
    required int totalSessions,
    required int remainingSessions,
    required bool lessonsNotRegistered,
    required String note,
    required String? selectedGroupId,
  }) async {
    final normalizedGender = personalMemberGenderForSave(gender);
    final normalizedBirthDate = personalMemberBirthDateForSave(birthDate);
    final groupSelection = normalizePersonalMemberGroupSelection(
      selectedGroupId: selectedGroupId,
    );
    if (!groupSelection.isValid) {
      throw StateError('member_group_owner_mismatch');
    }

    var functionSucceeded = false;
    var readbackSucceeded = false;
    var snapshotObserved = false;
    try {
      final response = await MtfFirebaseFunctions.call(
        'createManagedMember',
        functions: _functions,
        parameters: {
          'idempotencyKey': idempotencyKey,
          'name': name,
          'gender': normalizedGender,
          'birthDate': normalizedBirthDate,
          'phone': phone,
          'postal': postal,
          'address': address,
          'detailAddress': detailAddress,
          'lessonType': lessonType,
          'totalSessions': totalSessions,
          'remainingSessions': remainingSessions,
          'lessonsNotRegistered': lessonsNotRegistered,
          'note': note,
        },
      );
      functionSucceeded = true;
      final data = response is Map
          ? Map<String, dynamic>.from(response)
          : const <String, dynamic>{};
      final memberId = (data['memberId'] ?? '').toString().trim();
      if (memberId.isEmpty) {
        throw StateError('member_id_missing');
      }

      final document = await _firestore
          .collection('members')
          .doc(memberId)
          .get(const GetOptions(source: Source.server));
      final member = document.data();
      if (!_hasExpectedIdentity(
        document: document,
        memberId: memberId,
        member: member,
        gender: normalizedGender,
        birthDate: normalizedBirthDate,
      )) {
        throw StateError('member_readback_identity_mismatch');
      }
      final storedGroupId = (member!['groupId'] ?? '').toString().trim();
      if (storedGroupId.isNotEmpty) {
        throw StateError('member_group_readback_mismatch');
      }
      readbackSucceeded = true;

      snapshotObserved = await _firestore
          .collection('members')
          .where('trainerId', isEqualTo: uid)
          .where('workspaceType', isEqualTo: 'personal')
          .snapshots()
          .map((snapshot) => snapshot.docs.any((doc) => doc.id == memberId))
          .firstWhere((observed) => observed)
          .timeout(const Duration(seconds: 12));

      _debugLog(
        groupSelection: groupSelection,
        functionSucceeded: functionSucceeded,
        readbackSucceeded: readbackSucceeded,
        snapshotObserved: snapshotObserved,
        visibleAfterSave: false,
        result: 'success',
        errorCode: '',
      );
      return PersonalMemberCardSaveResult(
        memberId: memberId,
        readbackSucceeded: readbackSucceeded,
        snapshotObserved: snapshotObserved,
        groupSelection: groupSelection,
      );
    } catch (error) {
      final errorCode = switch (error) {
        FirebaseFunctionsException(:final code) => code,
        FirebaseException(:final code) => code,
        TimeoutException() => 'snapshot_timeout',
        StateError(:final message) => message,
        _ => 'unknown',
      };
      _debugLog(
        groupSelection: groupSelection,
        functionSucceeded: functionSucceeded,
        readbackSucceeded: readbackSucceeded,
        snapshotObserved: snapshotObserved,
        visibleAfterSave: false,
        result: 'failure',
        errorCode: errorCode,
      );
      rethrow;
    }
  }

  Future<void> updateAndVerify({
    required String memberId,
    required String name,
    required String gender,
    required String birthDate,
    required String phone,
    required String postal,
    required String address,
    required String detailAddress,
    required String lessonType,
    required int totalSessions,
    required int remainingSessions,
    required bool lessonsNotRegistered,
    required String note,
  }) async {
    final normalizedGender = personalMemberGenderForSave(gender);
    final normalizedBirthDate = personalMemberBirthDateForSave(birthDate);
    final response = await MtfFirebaseFunctions.call(
      'updateManagedMember',
      functions: _functions,
      parameters: {
        'memberId': memberId,
        'name': name,
        'gender': normalizedGender,
        'birthDate': normalizedBirthDate,
        'phone': phone,
        'postal': postal,
        'address': address,
        'detailAddress': detailAddress,
        'lessonType': lessonType,
        'totalSessions': totalSessions,
        'remainingSessions': remainingSessions,
        'lessonsNotRegistered': lessonsNotRegistered,
        'note': note,
      },
    );
    final data = response is Map
        ? Map<String, dynamic>.from(response)
        : const <String, dynamic>{};
    if (data['updated'] != true || data['memberId'] != memberId) {
      throw StateError('member_update_response_mismatch');
    }

    final document = await _firestore
        .collection('members')
        .doc(memberId)
        .get(const GetOptions(source: Source.server));
    final member = document.data();
    if (!_hasExpectedIdentity(
      document: document,
      memberId: memberId,
      member: member,
      gender: normalizedGender,
      birthDate: normalizedBirthDate,
    )) {
      throw StateError('member_update_readback_mismatch');
    }
  }

  bool _hasExpectedIdentity({
    required DocumentSnapshot<Map<String, dynamic>> document,
    required String memberId,
    required Map<String, dynamic>? member,
    required String gender,
    required String birthDate,
  }) {
    if (!document.exists ||
        document.id != memberId ||
        member == null ||
        member['memberId'] != memberId ||
        member['trainerId'] != uid ||
        member['workspaceType'] != 'personal' ||
        member['gender'] != gender ||
        member['birthDisplay'] != birthDate) {
      return false;
    }
    final birth = member['birth'];
    if (birth is! Timestamp) return false;
    final date = birth.toDate().toUtc();
    final storedBirthDate = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return storedBirthDate == birthDate;
  }

  static void logVisibleResult({
    required PersonalMemberGroupSelection groupSelection,
    required bool visibleAfterSave,
  }) {
    _debugLog(
      groupSelection: groupSelection,
      functionSucceeded: true,
      readbackSucceeded: true,
      snapshotObserved: true,
      visibleAfterSave: visibleAfterSave,
      result: visibleAfterSave ? 'success' : 'failure',
      errorCode: visibleAfterSave ? '' : 'member_not_visible',
    );
  }

  static void _debugLog({
    required PersonalMemberGroupSelection groupSelection,
    required bool functionSucceeded,
    required bool readbackSucceeded,
    required bool snapshotObserved,
    required bool visibleAfterSave,
    required String result,
    required String errorCode,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[MTF_MEMBER_CREATE] '
      'selectedGroupType=${groupSelection.type.name} '
      'selectedGroupValid=${groupSelection.isValid} '
      'fallbackApplied=${groupSelection.fallbackApplied} '
      'functionSucceeded=$functionSucceeded '
      'readbackSucceeded=$readbackSucceeded '
      'snapshotObserved=$snapshotObserved '
      'visibleAfterSave=$visibleAfterSave '
      'result=$result '
      'errorCode=${errorCode.isEmpty ? 'none' : errorCode}',
    );
  }
}
