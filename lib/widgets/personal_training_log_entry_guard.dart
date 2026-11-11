import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../pages/training_log_consent_page.dart';
import '../services/app_tier_access_service.dart';
import '../services/personal_member_consent_service.dart';
import 'aifc_tier_feature_gate_sheet.dart';
import 'aifc_toast.dart';

enum PersonalTrainingLogMemberAccess { allowed, consentRequired, denied }

@visibleForTesting
PersonalTrainingLogMemberAccess resolvePersonalTrainingLogMemberAccess({
  required String ownerUid,
  required String memberId,
  required bool memberExists,
  required Map<String, dynamic>? memberData,
}) {
  final owner = ownerUid.trim();
  final member = memberId.trim();
  final data = memberData;
  if (owner.isEmpty || member.isEmpty || !memberExists || data == null) {
    return PersonalTrainingLogMemberAccess.denied;
  }
  if (data['memberId'] != member ||
      data['trainerId'] != owner ||
      data['workspaceType'] != 'personal') {
    return PersonalTrainingLogMemberAccess.denied;
  }

  if (data['trainingLogConsentAgreed'] == true) {
    return PersonalTrainingLogMemberAccess.allowed;
  }
  return PersonalTrainingLogMemberAccess.consentRequired;
}

class PersonalTrainingLogEntryGuard {
  const PersonalTrainingLogEntryGuard._();

  static Future<bool> guard({
    required BuildContext context,
    required String ownerUid,
    required String memberId,
    required String entryPoint,
    required Future<AppTierAccessSnapshot> Function() loadAccess,
    AppTierAccessSnapshot? access,
    FirebaseFirestore? firestore,
    bool checkTier = true,
  }) async {
    final navigator = Navigator.of(context);
    if (checkTier) {
      final tierAllowed = await AifcTierFeatureGateSheet.guard(
        context: context,
        access: access,
        feature: AppTierFeatureKey.trainingLog,
        loadAccess: loadAccess,
        entryPoint: entryPoint,
      );
      if (!tierAllowed || !context.mounted) return false;
    }

    final owner = ownerUid.trim();
    final member = memberId.trim();
    if (owner.isEmpty || member.isEmpty) {
      _log(entryPoint: entryPoint, result: 'deny', reason: 'identity_missing');
      return false;
    }

    final db = firestore ?? FirebaseFirestore.instance;
    final memberRef = db.collection('members').doc(member);
    try {
      final initial = await memberRef.get(
        const GetOptions(source: Source.server),
      );
      final initialAccess = resolvePersonalTrainingLogMemberAccess(
        ownerUid: owner,
        memberId: member,
        memberExists: initial.exists,
        memberData: initial.data(),
      );
      if (initialAccess == PersonalTrainingLogMemberAccess.denied) {
        _log(entryPoint: entryPoint, result: 'deny', reason: 'owner_mismatch');
        if (context.mounted) _showFailure(context);
        return false;
      }
      if (initialAccess == PersonalTrainingLogMemberAccess.allowed) {
        _log(entryPoint: entryPoint, result: 'allow', reason: 'already_ready');
        return true;
      }

      if (!navigator.mounted) return false;
      final agreed = await navigator.push<bool>(
        MaterialPageRoute(
          builder:
              (_) => TrainingLogConsentPage(
                onAgree:
                    () => PersonalMemberConsentService(
                      uid: owner,
                    ).update(memberId: member, agreed: true),
              ),
        ),
      );
      if (agreed != true || !navigator.mounted) {
        _log(
          entryPoint: entryPoint,
          result: 'deny',
          reason: 'consent_cancelled',
        );
        return false;
      }

      final readback = await memberRef.get(
        const GetOptions(source: Source.server),
      );
      final readbackAccess = resolvePersonalTrainingLogMemberAccess(
        ownerUid: owner,
        memberId: member,
        memberExists: readback.exists,
        memberData: readback.data(),
      );
      final allowed = readbackAccess == PersonalTrainingLogMemberAccess.allowed;
      _log(
        entryPoint: entryPoint,
        result: allowed ? 'allow' : 'deny',
        reason: allowed ? 'consent_readback' : 'consent_readback_mismatch',
      );
      if (!allowed && context.mounted) _showFailure(context);
      return allowed;
    } catch (error) {
      final code =
          error is FirebaseException
              ? error.code
              : error.runtimeType.toString();
      _log(entryPoint: entryPoint, result: 'error', reason: code);
      if (context.mounted) {
        _showFailure(context, network: isNetworkFailureCode(code));
      }
      return false;
    }
  }

  /// 인터넷이 없거나 불안정해서 서버에서 읽지 못한 경우의 오류 코드.
  @visibleForTesting
  static bool isNetworkFailureCode(String code) =>
      code == 'unavailable' ||
      code == 'deadline-exceeded' ||
      code == 'network-request-failed';

  /// 실패 안내는 앱 전체와 같은 AIFC 알림(토스트)으로 보여 준다.
  static void _showFailure(BuildContext context, {bool network = false}) {
    if (!context.mounted) return;
    AifcToast.show(
      context: context,
      message:
          network
              ? '네트워크가 불안정해요. 연결을 확인하고 다시 시도해 주세요.'
              : '회원의 레슨일지 사용 상태를 확인하지 못했어요. 다시 시도해주세요.',
      bottomOffset: 110,
      duration: const Duration(milliseconds: 2600),
    );
  }

  static void _log({
    required String entryPoint,
    required String result,
    required String reason,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[MTF_TRAINING_LOG_ENTRY] entryPoint=$entryPoint '
      'result=$result reason=$reason identifiersLogged=false',
    );
  }
}
