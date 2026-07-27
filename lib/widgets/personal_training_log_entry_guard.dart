import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../pages/training_log_consent_page.dart';
import '../services/app_tier_access_service.dart';
import '../services/personal_member_consent_service.dart';
import 'aifc_tier_feature_gate_sheet.dart';

enum PersonalTrainingLogMemberAccess {
  allowed,
  consentRequired,
  denied,
}

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

  final lessonSync = data['lessonSync'] is Map
      ? Map<String, dynamic>.from(data['lessonSync'] as Map)
      : const <String, dynamic>{};
  final hasSignedContract = data['contractSigned'] == true ||
      data['contractSignedAt'] != null ||
      (lessonSync['contractId'] ?? '').toString().trim().isNotEmpty;
  if (hasSignedContract || data['trainingLogConsentAgreed'] == true) {
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
    final messenger = ScaffoldMessenger.maybeOf(context);
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
        _showFailure(messenger);
        return false;
      }
      if (initialAccess == PersonalTrainingLogMemberAccess.allowed) {
        _log(entryPoint: entryPoint, result: 'allow', reason: 'already_ready');
        return true;
      }

      if (!navigator.mounted) return false;
      final agreed = await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => TrainingLogConsentPage(
            onAgree: () => PersonalMemberConsentService(uid: owner).update(
              memberId: member,
              agreed: true,
            ),
          ),
        ),
      );
      if (agreed != true || !navigator.mounted) {
        _log(
            entryPoint: entryPoint,
            result: 'deny',
            reason: 'consent_cancelled');
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
      if (!allowed) _showFailure(messenger);
      return allowed;
    } catch (error) {
      final code = error is FirebaseException
          ? error.code
          : error.runtimeType.toString();
      _log(entryPoint: entryPoint, result: 'error', reason: code);
      _showFailure(messenger);
      return false;
    }
  }

  static void _showFailure(ScaffoldMessengerState? messenger) {
    if (messenger == null || !messenger.mounted) return;
    messenger.showSnackBar(
      const SnackBar(
        content: Text('회원의 레슨일지 사용 상태를 확인하지 못했어요. 다시 시도해주세요.'),
      ),
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
