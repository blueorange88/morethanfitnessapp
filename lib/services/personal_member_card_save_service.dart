import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/personal_member_taxonomy.dart';
import '../utils/member_input_validation.dart';
import 'mtf_firebase_functions.dart';

const personalMemberUpdateCallableTimeout = Duration(seconds: 20);

enum PersonalMemberSaveTraceStage {
  saveButtonTap('SAVE_BUTTON_TAP'),
  localValidate('LOCAL_VALIDATE'),
  phoneDuplicateCheck('PHONE_DUPLICATE_CHECK'),
  callableStart('CALLABLE_START'),
  callableResponse('CALLABLE_RESPONSE'),
  canonicalReadback('CANONICAL_READBACK'),
  ownerSnapshotConfirm('OWNER_SNAPSHOT_CONFIRM'),
  uiSuccess('UI_SUCCESS');

  const PersonalMemberSaveTraceStage(this.label);

  final String label;
}

enum PersonalMemberSaveTraceStatus {
  start('START'),
  ok('OK'),
  fail('FAIL'),
  timeout('TIMEOUT');

  const PersonalMemberSaveTraceStatus(this.label);

  final String label;
}

typedef PersonalMemberSaveTraceSink = void Function(String message);

class PersonalMemberSaveTrace {
  PersonalMemberSaveTrace._({
    required this.id,
    required PersonalMemberSaveTraceSink sink,
  })  : _sink = sink,
        _stopwatch = Stopwatch()..start();

  factory PersonalMemberSaveTrace.start({
    PersonalMemberSaveTraceSink? sink,
  }) {
    final timestamp =
        DateTime.now().microsecondsSinceEpoch.toRadixString(36).toUpperCase();
    final sequence = (_nextSequence++ % 1296)
        .toRadixString(36)
        .toUpperCase()
        .padLeft(2, '0');
    return PersonalMemberSaveTrace._(
      id: 'SAVE-$timestamp-$sequence',
      sink: sink ?? debugPrint,
    );
  }

  static int _nextSequence = 0;

  final String id;
  final PersonalMemberSaveTraceSink _sink;
  final Stopwatch _stopwatch;

  void record(
    PersonalMemberSaveTraceStage stage,
    PersonalMemberSaveTraceStatus status, {
    String outcome = 'none',
    String functionName = 'none',
    String errorCode = 'none',
  }) {
    _sink(
      '[MTF_MEMBER_SAVE_TRACE] '
      'trace=$id '
      'stage=${stage.label} '
      'status=${status.label} '
      'elapsedMs=${_stopwatch.elapsedMilliseconds} '
      'outcome=${_safeToken(outcome)} '
      'function=${_safeToken(functionName)} '
      'errorCode=${_safeToken(errorCode)}',
    );
  }

  static String _safeToken(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return 'none';
    return normalized.replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  }
}

PersonalMemberSaveTraceStatus personalMemberSaveTraceFailureStatus(
  Object error,
) {
  final cause =
      error is PersonalMemberCardUpdateException ? error.cause : error;
  final code = personalMemberUpdateErrorCode(cause).toLowerCase();
  if (cause is TimeoutException || code.contains('timeout')) {
    return PersonalMemberSaveTraceStatus.timeout;
  }
  return PersonalMemberSaveTraceStatus.fail;
}

String personalMemberSaveTraceFailureOutcome(Object error) {
  final cause =
      error is PersonalMemberCardUpdateException ? error.cause : error;
  final code = personalMemberUpdateErrorCode(cause).toLowerCase();
  final diagnostic = cause.toString().toLowerCase();
  if (cause is FirebaseFunctionsException) {
    final serverReason = personalMemberSaveTraceServerReason(cause);
    if (serverReason != null) return serverReason.toUpperCase();
  }
  if (diagnostic.contains('unknownhostexception') ||
      diagnostic.contains('unable to resolve host') ||
      diagnostic.contains('host lookup')) {
    return 'DNS_FAIL';
  }
  if (cause is TimeoutException || code.contains('timeout')) {
    return 'TIMEOUT';
  }
  if (code == 'permission-denied') return 'PERMISSION_DENIED';
  if (code == 'not-found') return 'NOT_FOUND';
  if (code.contains('mismatch')) return 'MISMATCH';
  if (personalMemberUpdateIsNetworkError(cause)) return 'NETWORK_FAIL';
  return 'FAIL';
}

@visibleForTesting
String? personalMemberSaveTraceServerReason(
  FirebaseFunctionsException error,
) {
  final diagnostic =
      '${error.message ?? ''} ${error.details ?? ''}'.trim().toLowerCase();
  for (final reason in const {
    'profile_required',
    'member_count_conflict',
    'account_link_required',
    'profile_completion_required',
    'workspace_not_eligible',
    'amateur_required',
    'semi_pro_required',
    'personal_group_not_found',
    'personal_tag_not_found',
  }) {
    if (diagnostic.contains(reason)) return reason;
  }
  return null;
}

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

@visibleForTesting
String personalMemberGradeForSave(String value) {
  final normalized = value.trim().toUpperCase();
  if (!const {'VVIP', 'VIP', 'GOLD', 'SILVER', 'BRONZE'}.contains(normalized)) {
    throw ArgumentError.value(value, 'membershipGrade', 'grade_invalid');
  }
  return normalized;
}

@visibleForTesting
int? normalizePersonalMembershipDaysInput(String value) {
  final match = RegExp(
    r'^([1-9]\d*)\s*(?:일|days?)?$',
    caseSensitive: false,
  ).firstMatch(value.trim());
  if (match == null) return null;
  return int.tryParse(match.group(1)!);
}

@visibleForTesting
String personalMemberCallableErrorDiagnostic({
  required String code,
  required String? message,
  required Object? details,
}) {
  String oneLine(Object? value) =>
      (value ?? 'none').toString().replaceAll(RegExp(r'[\r\n]+'), ' ');

  return 'code=${oneLine(code)} '
      'message=${oneLine(message)} '
      'details=${oneLine(details)}';
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

class PersonalMemberCardUpdateResult {
  const PersonalMemberCardUpdateResult({
    required this.memberId,
    required this.readbackSucceeded,
    required this.snapshotObserved,
    required this.scheduleNameSyncSucceeded,
    required this.scheduleNameUpdatedCount,
  });

  final String memberId;
  final bool readbackSucceeded;
  final bool snapshotObserved;
  final bool scheduleNameSyncSucceeded;
  final int scheduleNameUpdatedCount;
}

enum PersonalMemberCardUpdateStage {
  callable,
  response,
  readback,
  snapshot,
  scheduleReadback,
}

class PersonalMemberCardUpdateException implements Exception {
  const PersonalMemberCardUpdateException({
    required this.stage,
    required this.cause,
  });

  final PersonalMemberCardUpdateStage stage;
  final Object cause;

  @override
  String toString() => 'PersonalMemberCardUpdateException(stage=${stage.name}, '
      'code=${personalMemberUpdateErrorCode(cause)})';
}

@visibleForTesting
String personalMemberUpdateErrorCode(Object error) {
  final cause =
      error is PersonalMemberCardUpdateException ? error.cause : error;
  return switch (cause) {
    FirebaseFunctionsException(:final code) => code,
    FirebaseException(:final code) => code,
    TimeoutException() => 'timeout',
    StateError(:final message) => message,
    _ => cause.runtimeType.toString(),
  };
}

@visibleForTesting
bool personalMemberUpdateIsNetworkError(Object error) {
  final cause =
      error is PersonalMemberCardUpdateException ? error.cause : error;
  final code = personalMemberUpdateErrorCode(cause).toLowerCase();
  if (const {
    'unavailable',
    'network-request-failed',
    'timeout',
    'snapshot_timeout',
  }.contains(code)) {
    return true;
  }

  final diagnostic = cause.toString().toLowerCase();
  return const [
    'unable to resolve host',
    'unknownhostexception',
    'socketexception',
    'network error',
    'network_error',
    'host lookup',
    'unavailable',
  ].any(diagnostic.contains);
}

@visibleForTesting
bool personalMemberUpdateRequiresAccountLink(Object error) {
  final cause =
      error is PersonalMemberCardUpdateException ? error.cause : error;
  return cause is FirebaseFunctionsException &&
      personalMemberSaveTraceServerReason(cause) == 'account_link_required';
}

bool personalMemberUpdateNeedsLinkedProfileCompletion(Object error) {
  final cause =
      error is PersonalMemberCardUpdateException ? error.cause : error;
  return cause is FirebaseFunctionsException &&
      personalMemberSaveTraceServerReason(cause) == 'workspace_not_eligible';
}

@visibleForTesting
String personalMemberUpdateErrorMessage(Object error) {
  final code = personalMemberUpdateErrorCode(error);
  final cause =
      error is PersonalMemberCardUpdateException ? error.cause : error;
  if (cause is FirebaseFunctionsException) {
    final reason = personalMemberSaveTraceServerReason(cause);
    if (reason == 'account_link_required') {
      return '누적 유효 회원이 10명에 도달해 계정 연결이 필요해요. '
          '마이페이지에서 이메일 계정을 연결한 뒤 이 화면에서 다시 저장해주세요. '
          '입력한 내용은 그대로 유지했어요.';
    }
    if (reason == 'profile_completion_required') {
      return '누적 유효 회원이 10명에 도달해 선생님 내 정보 완료가 필요해요. '
          '마이페이지에서 내 정보를 완료한 뒤 이 화면에서 다시 저장해주세요. '
          '입력한 내용은 그대로 유지했어요.';
    }
    if (reason == 'member_count_conflict') {
      return '회원 수 정보를 확인하지 못했어요. 입력한 내용은 그대로 유지했어요. '
          '잠시 후 다시 시도해주세요.';
    }
  }
  if (personalMemberUpdateIsNetworkError(error)) {
    return '네트워크 연결을 확인한 뒤 다시 시도해주세요. 입력한 내용은 그대로 유지했어요.';
  }
  if (code == 'permission-denied') {
    return '이 작업공간에서 수정할 수 없는 회원이에요.';
  }
  if (code == 'already-exists') {
    return '같은 전화번호로 등록된 다른 회원이 있어요.';
  }
  if (code == 'invalid-argument') {
    return '입력한 회원 정보를 다시 확인해주세요.';
  }
  return '저장 중 오류가 발생했어요. 입력한 내용은 그대로 유지했어요.';
}

@immutable
class PersonalMemberMembershipUpdate {
  const PersonalMemberMembershipUpdate({
    required this.notRegistered,
    required this.termMonths,
    required this.customDays,
    required this.startAt,
    required this.endAt,
    required this.days,
    required this.lastRegisteredAt,
    required this.reregisterCount,
    required this.lastReregisterAt,
  });

  final bool notRegistered;
  final int? termMonths;
  final int? customDays;
  final DateTime? startAt;
  final DateTime? endAt;
  final int? days;
  final DateTime? lastRegisteredAt;
  final int reregisterCount;
  final DateTime? lastReregisterAt;

  Map<String, dynamic> toCallableMap() => {
        'notRegistered': notRegistered,
        'termMonths': termMonths,
        'customDays': customDays,
        'startAt': personalMemberCalendarDateForSave(startAt),
        'endAt': personalMemberCalendarDateForSave(endAt),
        'days': days,
        'lastRegisteredAt': personalMemberCalendarDateForSave(lastRegisteredAt),
        'reregisterCount': reregisterCount,
        'lastReregisterAt': personalMemberCalendarDateForSave(lastReregisterAt),
      };
}

@visibleForTesting
String? personalMemberCalendarDateForSave(DateTime? value) {
  if (value == null) return null;
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

@visibleForTesting
bool personalMemberCalendarDateMatches(dynamic stored, DateTime? expected) {
  if (expected == null) return stored == null;
  if (stored is! Timestamp) return false;
  final actual = stored.toDate();
  return actual.year == expected.year &&
      actual.month == expected.month &&
      actual.day == expected.day;
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
    String? membershipGrade,
    PersonalMemberMembershipUpdate? membership,
    DateTime? anniversaryDate,
    String? anniversaryLabel,
    required String? selectedGroupId,
    Set<String> canonicalCustomGroupIds = const <String>{},
    PersonalMemberAssignmentPatch assignments =
        const PersonalMemberAssignmentPatch(),
    PersonalMemberSaveTrace? trace,
  }) async {
    final normalizedGender = personalMemberGenderForSave(gender);
    final normalizedBirthDate = personalMemberBirthDateForSave(birthDate);
    final normalizedMembershipGrade = membershipGrade == null
        ? null
        : personalMemberGradeForSave(membershipGrade);
    final normalizedAnniversaryLabel = anniversaryDate == null
        ? null
        : (anniversaryLabel ?? '').trim().isEmpty
            ? '기념일'
            : anniversaryLabel!.trim();
    final groupSelection = normalizePersonalMemberGroupSelection(
      selectedGroupId: selectedGroupId,
      canonicalCustomGroupIds: canonicalCustomGroupIds,
    );
    if (!groupSelection.isValid) {
      throw StateError('member_group_owner_mismatch');
    }

    return _createAndVerify(
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
        ...normalizedMembershipGrade == null
            ? const <String, dynamic>{}
            : <String, dynamic>{
                'membershipGrade': normalizedMembershipGrade,
              },
        ...membership == null
            ? const <String, dynamic>{}
            : <String, dynamic>{'membership': membership.toCallableMap()},
        ...anniversaryDate == null
            ? const <String, dynamic>{}
            : <String, dynamic>{
                'anniversaryDate':
                    personalMemberCalendarDateForSave(anniversaryDate),
                'anniversaryLabel': normalizedAnniversaryLabel,
              },
        ...assignments.toCallableMap(),
      },
      expectedName: name,
      expectedPhone: phone,
      expectedGender: normalizedGender,
      expectedBirthDate: normalizedBirthDate,
      expectedConsultDate: null,
      expectedMembershipGrade: normalizedMembershipGrade,
      expectedMembership: membership,
      expectedAnniversaryDate: anniversaryDate,
      expectedAnniversaryLabel: normalizedAnniversaryLabel,
      groupSelection: groupSelection,
      registrationMode: 'full',
      assignments: assignments,
      trace: trace,
    );
  }

  Future<PersonalMemberCardSaveResult> createQuickAndVerify({
    required String idempotencyKey,
    required String name,
    required String phone,
    required String note,
    DateTime? consultDate,
  }) {
    return _createAndVerify(
      parameters: {
        'idempotencyKey': idempotencyKey,
        'registrationMode': 'quick',
        'name': name,
        'phone': phone,
        'note': note,
        if (consultDate != null)
          'nextReservationAt': personalMemberCalendarDateForSave(consultDate),
      },
      expectedName: name,
      expectedPhone: phone,
      expectedGender: null,
      expectedBirthDate: null,
      expectedConsultDate: consultDate,
      expectedMembershipGrade: null,
      expectedMembership: null,
      expectedAnniversaryDate: null,
      expectedAnniversaryLabel: null,
      groupSelection: const PersonalMemberGroupSelection(
        type: PersonalMemberGroupSelectionType.canonicalDefault,
        groupId: null,
        isValid: true,
        fallbackApplied: false,
      ),
      registrationMode: 'quick',
      assignments: const PersonalMemberAssignmentPatch(),
    );
  }

  Future<PersonalMemberCardSaveResult> _createAndVerify({
    required Map<String, dynamic> parameters,
    required String expectedName,
    required String expectedPhone,
    required String? expectedGender,
    required String? expectedBirthDate,
    required DateTime? expectedConsultDate,
    required String? expectedMembershipGrade,
    required PersonalMemberMembershipUpdate? expectedMembership,
    required DateTime? expectedAnniversaryDate,
    required String? expectedAnniversaryLabel,
    required PersonalMemberGroupSelection groupSelection,
    required String registrationMode,
    required PersonalMemberAssignmentPatch assignments,
    PersonalMemberSaveTrace? trace,
  }) async {
    var functionSucceeded = false;
    var readbackSucceeded = false;
    var snapshotObserved = false;
    try {
      trace?.record(
        PersonalMemberSaveTraceStage.callableStart,
        PersonalMemberSaveTraceStatus.start,
        functionName: 'createManagedMember',
      );
      final callableFuture = MtfFirebaseFunctions.call(
        'createManagedMember',
        functions: _functions,
        parameters: parameters,
      );
      trace?.record(
        PersonalMemberSaveTraceStage.callableStart,
        PersonalMemberSaveTraceStatus.ok,
        functionName: 'createManagedMember',
      );
      trace?.record(
        PersonalMemberSaveTraceStage.callableResponse,
        PersonalMemberSaveTraceStatus.start,
        functionName: 'createManagedMember',
      );
      dynamic response;
      try {
        response = await callableFuture;
        trace?.record(
          PersonalMemberSaveTraceStage.callableResponse,
          PersonalMemberSaveTraceStatus.ok,
          outcome: 'SDK_RESPONSE_OK',
          functionName: 'createManagedMember',
        );
      } catch (error) {
        trace?.record(
          PersonalMemberSaveTraceStage.callableResponse,
          personalMemberSaveTraceFailureStatus(error),
          outcome: personalMemberSaveTraceFailureOutcome(error),
          functionName: 'createManagedMember',
          errorCode: personalMemberUpdateErrorCode(error),
        );
        rethrow;
      }
      functionSucceeded = true;
      final data = response is Map
          ? Map<String, dynamic>.from(response)
          : const <String, dynamic>{};
      final memberId = (data['memberId'] ?? '').toString().trim();
      if (memberId.isEmpty) {
        throw StateError('member_id_missing');
      }

      trace?.record(
        PersonalMemberSaveTraceStage.canonicalReadback,
        PersonalMemberSaveTraceStatus.start,
      );
      try {
        final document = await _firestore
            .collection('members')
            .doc(memberId)
            .get(const GetOptions(source: Source.server));
        final member = document.data();
        if (!_hasExpectedCreatedMember(
          document: document,
          memberId: memberId,
          member: member,
          name: expectedName,
          phone: expectedPhone,
          gender: expectedGender,
          birthDate: expectedBirthDate,
          consultDate: expectedConsultDate,
          membershipGrade: expectedMembershipGrade,
          membership: expectedMembership,
          anniversaryDate: expectedAnniversaryDate,
          anniversaryLabel: expectedAnniversaryLabel,
        )) {
          throw StateError('member_readback_identity_mismatch');
        }
        final storedGroupId = (member!['groupId'] ?? '').toString().trim();
        if (storedGroupId.isNotEmpty) {
          throw StateError('member_group_readback_mismatch');
        }
        if (!assignments.matchesMember(member)) {
          throw StateError('member_taxonomy_readback_mismatch');
        }
        readbackSucceeded = true;
        trace?.record(
          PersonalMemberSaveTraceStage.canonicalReadback,
          PersonalMemberSaveTraceStatus.ok,
        );
      } catch (error) {
        trace?.record(
          PersonalMemberSaveTraceStage.canonicalReadback,
          personalMemberSaveTraceFailureStatus(error),
          outcome: personalMemberSaveTraceFailureOutcome(error),
          errorCode: personalMemberUpdateErrorCode(error),
        );
        rethrow;
      }

      trace?.record(
        PersonalMemberSaveTraceStage.ownerSnapshotConfirm,
        PersonalMemberSaveTraceStatus.start,
      );
      try {
        snapshotObserved = await _firestore
            .collection('members')
            .where('trainerId', isEqualTo: uid)
            .where('workspaceType', isEqualTo: 'personal')
            .snapshots()
            .map((snapshot) {
              final matches = snapshot.docs.where((doc) => doc.id == memberId);
              if (matches.isEmpty) return false;
              final snapshotDocument = matches.first;
              final snapshotMember = snapshotDocument.data();
              return _hasExpectedCreatedMember(
                    document: snapshotDocument,
                    memberId: memberId,
                    member: snapshotMember,
                    name: expectedName,
                    phone: expectedPhone,
                    gender: expectedGender,
                    birthDate: expectedBirthDate,
                    consultDate: expectedConsultDate,
                    membershipGrade: expectedMembershipGrade,
                    membership: expectedMembership,
                    anniversaryDate: expectedAnniversaryDate,
                    anniversaryLabel: expectedAnniversaryLabel,
                  ) &&
                  assignments.matchesMember(snapshotMember);
            })
            .firstWhere((observed) => observed)
            .timeout(const Duration(seconds: 12));
        trace?.record(
          PersonalMemberSaveTraceStage.ownerSnapshotConfirm,
          PersonalMemberSaveTraceStatus.ok,
        );
      } catch (error) {
        trace?.record(
          PersonalMemberSaveTraceStage.ownerSnapshotConfirm,
          personalMemberSaveTraceFailureStatus(error),
          outcome: personalMemberSaveTraceFailureOutcome(error),
          errorCode: personalMemberUpdateErrorCode(error),
        );
        rethrow;
      }

      _debugLog(
        groupSelection: groupSelection,
        functionSucceeded: functionSucceeded,
        readbackSucceeded: readbackSucceeded,
        snapshotObserved: snapshotObserved,
        visibleAfterSave: false,
        result: 'success',
        errorCode: '',
        registrationMode: registrationMode,
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
        registrationMode: registrationMode,
      );
      rethrow;
    }
  }

  Future<PersonalMemberCardUpdateResult> updateAndVerify({
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
    required String membershipGrade,
    required PersonalMemberMembershipUpdate membership,
    required DateTime? anniversaryDate,
    required String? anniversaryLabel,
    PersonalMemberAssignmentPatch assignments =
        const PersonalMemberAssignmentPatch(),
    PersonalMemberSaveTrace? trace,
  }) async {
    final normalizedGender = personalMemberGenderForSave(gender);
    final normalizedBirthDate = personalMemberBirthDateForSave(birthDate);
    final normalizedLessonType =
        lessonType.trim().isEmpty ? '미입력' : lessonType.trim();
    final normalizedMembershipGrade =
        personalMemberGradeForSave(membershipGrade);
    var stage = PersonalMemberCardUpdateStage.callable;
    try {
      trace?.record(
        PersonalMemberSaveTraceStage.callableStart,
        PersonalMemberSaveTraceStatus.start,
        functionName: 'updateManagedMember',
      );
      _debugUpdateLog(
        stage: 'callable_start',
        result: 'pending',
        errorCode: '',
        membership: membership,
        anniversaryDate: anniversaryDate,
      );
      final callableFuture = MtfFirebaseFunctions.call(
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
          'lessonType': normalizedLessonType,
          'totalSessions': totalSessions,
          'remainingSessions': remainingSessions,
          'lessonsNotRegistered': lessonsNotRegistered,
          'note': note,
          'membershipGrade': normalizedMembershipGrade,
          'membership': membership.toCallableMap(),
          'anniversaryDate': personalMemberCalendarDateForSave(anniversaryDate),
          'anniversaryLabel': anniversaryDate == null
              ? null
              : (anniversaryLabel ?? '').trim().isEmpty
                  ? '기념일'
                  : anniversaryLabel!.trim(),
          ...assignments.toCallableMap(),
        },
      );
      trace?.record(
        PersonalMemberSaveTraceStage.callableStart,
        PersonalMemberSaveTraceStatus.ok,
        functionName: 'updateManagedMember',
      );
      trace?.record(
        PersonalMemberSaveTraceStage.callableResponse,
        PersonalMemberSaveTraceStatus.start,
        functionName: 'updateManagedMember',
      );
      dynamic response;
      try {
        response = await callableFuture.timeout(
          personalMemberUpdateCallableTimeout,
        );
        trace?.record(
          PersonalMemberSaveTraceStage.callableResponse,
          PersonalMemberSaveTraceStatus.ok,
          outcome: 'SDK_RESPONSE_OK',
          functionName: 'updateManagedMember',
        );
      } catch (error) {
        trace?.record(
          PersonalMemberSaveTraceStage.callableResponse,
          personalMemberSaveTraceFailureStatus(error),
          outcome: personalMemberSaveTraceFailureOutcome(error),
          functionName: 'updateManagedMember',
          errorCode: personalMemberUpdateErrorCode(error),
        );
        rethrow;
      }
      stage = PersonalMemberCardUpdateStage.response;
      _debugUpdateLog(
        stage: 'callable_complete',
        result: 'success',
        errorCode: '',
        membership: membership,
        anniversaryDate: anniversaryDate,
      );
      final data = response is Map
          ? Map<String, dynamic>.from(response)
          : const <String, dynamic>{};
      if (data['updated'] != true || data['memberId'] != memberId) {
        throw StateError('member_update_response_mismatch');
      }
      final scheduleNameSyncSucceeded =
          data['scheduleNameSyncSucceeded'] == true;
      final scheduleNameUpdatedCount =
          (data['scheduleNameUpdatedCount'] as num?)?.toInt() ?? 0;

      stage = PersonalMemberCardUpdateStage.readback;
      trace?.record(
        PersonalMemberSaveTraceStage.canonicalReadback,
        PersonalMemberSaveTraceStatus.start,
      );
      try {
        final document = await _firestore
            .collection('members')
            .doc(memberId)
            .get(const GetOptions(source: Source.server));
        final member = document.data();
        if (!_hasExpectedMemberUpdate(
          document: document,
          memberId: memberId,
          member: member,
          name: name,
          gender: normalizedGender,
          birthDate: normalizedBirthDate,
          phone: phone,
          postal: postal,
          address: address,
          detailAddress: detailAddress,
          lessonType: normalizedLessonType,
          totalSessions: totalSessions,
          remainingSessions: remainingSessions,
          lessonsNotRegistered: lessonsNotRegistered,
          note: note,
          membershipGrade: normalizedMembershipGrade,
          membership: membership,
          anniversaryDate: anniversaryDate,
          anniversaryLabel: anniversaryLabel,
          assignments: assignments,
        )) {
          throw StateError('member_update_readback_mismatch');
        }
        trace?.record(
          PersonalMemberSaveTraceStage.canonicalReadback,
          PersonalMemberSaveTraceStatus.ok,
        );
      } catch (error) {
        trace?.record(
          PersonalMemberSaveTraceStage.canonicalReadback,
          personalMemberSaveTraceFailureStatus(error),
          outcome: personalMemberSaveTraceFailureOutcome(error),
          errorCode: personalMemberUpdateErrorCode(error),
        );
        rethrow;
      }

      stage = PersonalMemberCardUpdateStage.snapshot;
      trace?.record(
        PersonalMemberSaveTraceStage.ownerSnapshotConfirm,
        PersonalMemberSaveTraceStatus.start,
      );
      late final bool snapshotObserved;
      try {
        snapshotObserved = await _firestore
            .collection('members')
            .doc(memberId)
            .snapshots()
            .map(
              (snapshot) => _hasExpectedMemberUpdate(
                document: snapshot,
                memberId: memberId,
                member: snapshot.data(),
                name: name,
                gender: normalizedGender,
                birthDate: normalizedBirthDate,
                phone: phone,
                postal: postal,
                address: address,
                detailAddress: detailAddress,
                lessonType: normalizedLessonType,
                totalSessions: totalSessions,
                remainingSessions: remainingSessions,
                lessonsNotRegistered: lessonsNotRegistered,
                note: note,
                membershipGrade: normalizedMembershipGrade,
                membership: membership,
                anniversaryDate: anniversaryDate,
                anniversaryLabel: anniversaryLabel,
                assignments: assignments,
              ),
            )
            .firstWhere((observed) => observed)
            .timeout(const Duration(seconds: 12));
        trace?.record(
          PersonalMemberSaveTraceStage.ownerSnapshotConfirm,
          PersonalMemberSaveTraceStatus.ok,
        );
      } catch (error) {
        trace?.record(
          PersonalMemberSaveTraceStage.ownerSnapshotConfirm,
          personalMemberSaveTraceFailureStatus(error),
          outcome: personalMemberSaveTraceFailureOutcome(error),
          errorCode: personalMemberUpdateErrorCode(error),
        );
        rethrow;
      }

      if (scheduleNameSyncSucceeded) {
        stage = PersonalMemberCardUpdateStage.scheduleReadback;
        final schedules = await _firestore
            .collection('schedules')
            .where('trainerId', isEqualTo: uid)
            .where('workspaceType', isEqualTo: 'personal')
            .where('memberId', isEqualTo: memberId)
            .get(const GetOptions(source: Source.server));
        if (schedules.docs.any(
          (schedule) =>
              (schedule.data()['name'] ?? '').toString().trim() != name.trim(),
        )) {
          throw StateError('member_schedule_name_readback_mismatch');
        }
      }

      _debugUpdateLog(
        stage: 'complete',
        result: 'success',
        errorCode: '',
        membership: membership,
        anniversaryDate: anniversaryDate,
      );
      return PersonalMemberCardUpdateResult(
        memberId: memberId,
        readbackSucceeded: true,
        snapshotObserved: snapshotObserved,
        scheduleNameSyncSucceeded: scheduleNameSyncSucceeded,
        scheduleNameUpdatedCount: scheduleNameUpdatedCount,
      );
    } catch (error, stackTrace) {
      final errorCode = personalMemberUpdateErrorCode(error);
      debugPrint(
        '[MTF_MEMBER_UPDATE_FAILURE] '
        'stage=${stage.name} '
        'errorCode=$errorCode '
        'network=${personalMemberUpdateIsNetworkError(error)} '
        'causeType=${error.runtimeType}',
      );
      _debugUpdateLog(
        stage: stage.name,
        result: 'failure',
        errorCode: errorCode,
        membership: membership,
        anniversaryDate: anniversaryDate,
      );
      Error.throwWithStackTrace(
        PersonalMemberCardUpdateException(stage: stage, cause: error),
        stackTrace,
      );
    }
  }

  static void _debugUpdateLog({
    required String stage,
    required String result,
    required String errorCode,
    required PersonalMemberMembershipUpdate membership,
    required DateTime? anniversaryDate,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[MTF_MEMBER_UPDATE] '
      'stage=$stage '
      'result=$result '
      'errorCode=${errorCode.isEmpty ? 'none' : errorCode} '
      'membershipRegistered=${!membership.notRegistered} '
      'termMode=${membership.termMonths != null ? 'months' : membership.customDays != null ? 'days' : 'none'} '
      'hasStart=${membership.startAt != null} '
      'hasEnd=${membership.endAt != null} '
      'hasAnniversary=${anniversaryDate != null}',
    );
  }

  bool _hasExpectedMemberUpdate({
    required DocumentSnapshot<Map<String, dynamic>> document,
    required String memberId,
    required Map<String, dynamic>? member,
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
    required String membershipGrade,
    required PersonalMemberMembershipUpdate membership,
    required DateTime? anniversaryDate,
    required String? anniversaryLabel,
    required PersonalMemberAssignmentPatch assignments,
  }) {
    if (!_hasExpectedIdentity(
      document: document,
      memberId: memberId,
      member: member,
      gender: gender,
      birthDate: birthDate,
    )) {
      return false;
    }
    final sessions = member!['sessions'];
    final storedMembership = member['membership'];
    final expectedAnniversaryLabel = anniversaryDate == null
        ? null
        : (anniversaryLabel ?? '').trim().isEmpty
            ? '기념일'
            : anniversaryLabel!.trim();
    return (member['name'] ?? '').toString().trim() == name.trim() &&
        (member['phone'] ?? '').toString().trim() == phone.trim() &&
        (member['postal'] ?? '').toString().trim() == postal.trim() &&
        (member['address'] ?? '').toString().trim() == address.trim() &&
        (member['detailAddress'] ?? '').toString().trim() ==
            detailAddress.trim() &&
        (member['lessonType'] ?? '').toString().trim() == lessonType.trim() &&
        (member['note'] ?? '').toString().trim() == note.trim() &&
        member['membershipGrade'] == membershipGrade &&
        (member['totalSessions'] as num?)?.toInt() == totalSessions &&
        (member['remainingSessions'] as num?)?.toInt() == remainingSessions &&
        (member['remainSessions'] as num?)?.toInt() == remainingSessions &&
        sessions is Map &&
        sessions['notRegistered'] == lessonsNotRegistered &&
        (sessions['total'] as num?)?.toInt() == totalSessions &&
        (sessions['remain'] as num?)?.toInt() == remainingSessions &&
        storedMembership is Map &&
        storedMembership['notRegistered'] == membership.notRegistered &&
        (storedMembership['termMonths'] as num?)?.toInt() ==
            membership.termMonths &&
        (storedMembership['customDays'] as num?)?.toInt() ==
            membership.customDays &&
        personalMemberCalendarDateMatches(
          storedMembership['startAt'],
          membership.startAt,
        ) &&
        personalMemberCalendarDateMatches(
          storedMembership['endAt'],
          membership.endAt,
        ) &&
        (storedMembership['days'] as num?)?.toInt() == membership.days &&
        personalMemberCalendarDateMatches(
          storedMembership['lastRegisteredAt'],
          membership.lastRegisteredAt,
        ) &&
        (storedMembership['reregisterCount'] as num?)?.toInt() ==
            membership.reregisterCount &&
        personalMemberCalendarDateMatches(
          storedMembership['lastReregisterAt'],
          membership.lastReregisterAt,
        ) &&
        personalMemberCalendarDateMatches(
          member['anniversaryDate'],
          anniversaryDate,
        ) &&
        member['anniversaryLabel'] == expectedAnniversaryLabel &&
        assignments.matchesMember(member);
  }

  Future<void> deleteAndVerify({required String memberId}) async {
    final response = await MtfFirebaseFunctions.call(
      'transitionManagedMemberState',
      functions: _functions,
      parameters: {
        'memberId': memberId,
        'nextState': 'deleted',
      },
    );
    final data = response is Map
        ? Map<String, dynamic>.from(response)
        : const <String, dynamic>{};
    if (data['memberId'] != memberId) {
      throw StateError('member_delete_response_mismatch');
    }
    final document = await _firestore
        .collection('members')
        .doc(memberId)
        .get(const GetOptions(source: Source.server));
    final member = document.data();
    if (!document.exists ||
        member == null ||
        member['memberId'] != memberId ||
        member['trainerId'] != uid ||
        member['workspaceType'] != 'personal' ||
        member['managementState'] != 'deleted' ||
        member['isDeleted'] != true ||
        member['deleteStatus'] != 'pending_delete' ||
        member['deletedAt'] is! Timestamp ||
        member['deleteScheduledAt'] is! Timestamp) {
      throw StateError('member_delete_readback_mismatch');
    }
  }

  Future<void> transitionStateAndVerify({
    required String memberId,
    required String nextState,
  }) async {
    if (!const {'active', 'dormant', 'expired'}.contains(nextState)) {
      throw ArgumentError.value(nextState, 'nextState');
    }
    final response = await MtfFirebaseFunctions.call(
      'transitionManagedMemberState',
      functions: _functions,
      parameters: {
        'memberId': memberId,
        'nextState': nextState,
      },
    );
    final data = response is Map
        ? Map<String, dynamic>.from(response)
        : const <String, dynamic>{};
    if (data['memberId'] != memberId) {
      throw StateError('member_state_response_mismatch');
    }
    final document = await _firestore
        .collection('members')
        .doc(memberId)
        .get(const GetOptions(source: Source.server));
    final member = document.data();
    if (!document.exists ||
        member == null ||
        member['memberId'] != memberId ||
        member['trainerId'] != uid ||
        member['workspaceType'] != 'personal' ||
        member['managementState'] != nextState ||
        member['isDeleted'] == true) {
      throw StateError('member_state_readback_mismatch');
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

  bool _hasExpectedCreatedMember({
    required DocumentSnapshot<Map<String, dynamic>> document,
    required String memberId,
    required Map<String, dynamic>? member,
    required String name,
    required String phone,
    required String? gender,
    required String? birthDate,
    required DateTime? consultDate,
    required String? membershipGrade,
    required PersonalMemberMembershipUpdate? membership,
    required DateTime? anniversaryDate,
    required String? anniversaryLabel,
  }) {
    if (!document.exists ||
        document.id != memberId ||
        member == null ||
        member['memberId'] != memberId ||
        member['trainerId'] != uid ||
        member['workspaceType'] != 'personal' ||
        member['managementState'] != 'active' ||
        member['isDeleted'] == true ||
        (member['name'] ?? '').toString().trim() != name.trim() ||
        (member['phone'] ?? '').toString().trim() != phone.trim() ||
        member['createdAt'] is! Timestamp) {
      return false;
    }
    if (consultDate != null &&
        !personalMemberCalendarDateMatches(
          member['nextReservationAt'],
          consultDate,
        )) {
      return false;
    }
    if (membershipGrade != null &&
        member['membershipGrade'] != membershipGrade) {
      return false;
    }
    if (membership != null) {
      final storedMembership = member['membership'];
      if (storedMembership is! Map ||
          storedMembership['notRegistered'] != membership.notRegistered ||
          (storedMembership['termMonths'] as num?)?.toInt() !=
              membership.termMonths ||
          (storedMembership['customDays'] as num?)?.toInt() !=
              membership.customDays ||
          !personalMemberCalendarDateMatches(
            storedMembership['startAt'],
            membership.startAt,
          ) ||
          !personalMemberCalendarDateMatches(
            storedMembership['endAt'],
            membership.endAt,
          ) ||
          (storedMembership['days'] as num?)?.toInt() != membership.days ||
          !personalMemberCalendarDateMatches(
            storedMembership['lastRegisteredAt'],
            membership.lastRegisteredAt,
          ) ||
          (storedMembership['reregisterCount'] as num?)?.toInt() !=
              membership.reregisterCount ||
          !personalMemberCalendarDateMatches(
            storedMembership['lastReregisterAt'],
            membership.lastReregisterAt,
          )) {
        return false;
      }
      if (!personalMemberCalendarDateMatches(
            member['anniversaryDate'],
            anniversaryDate,
          ) ||
          member['anniversaryLabel'] != anniversaryLabel) {
        return false;
      }
    }
    if (gender == null && birthDate == null) {
      return !member.containsKey('groupId') && !member.containsKey('groupName');
    }
    if (gender == null || birthDate == null) return false;
    return _hasExpectedIdentity(
      document: document,
      memberId: memberId,
      member: member,
      gender: gender,
      birthDate: birthDate,
    );
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
      registrationMode: 'full',
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
    required String registrationMode,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[MTF_MEMBER_CREATE] '
      'mode=$registrationMode '
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
