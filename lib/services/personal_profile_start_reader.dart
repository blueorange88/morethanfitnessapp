import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import 'app_account_service.dart';
import 'app_environment.dart';
import 'mtf_firebase_functions.dart';

enum PersonalProfileReadErrorCode {
  profileNotFound,
  identityMismatch,
  workspaceNotReady,
}

class PersonalProfileReadException implements Exception {
  const PersonalProfileReadException(this.code);

  final PersonalProfileReadErrorCode code;
}

abstract interface class PersonalProfileStartReader {
  Future<PersonalProfileStartResult> read(AppAccountUser user);
}

class PersonalProfileStartResult {
  const PersonalProfileStartResult({
    required this.nickname,
    required this.onboardingCompleted,
    this.profileData = const <String, dynamic>{},
  });

  const PersonalProfileStartResult.onboardingCompleted({
    required this.nickname,
    this.profileData = const <String, dynamic>{},
  }) : onboardingCompleted = true;

  final String nickname;
  final bool onboardingCompleted;
  final Map<String, dynamic> profileData;

  bool get needsNicknameOnboarding =>
      nickname.trim().isEmpty || !onboardingCompleted;
}

abstract interface class PersonalNicknameOnboardingGateway {
  Future<void> saveNickname({
    required String uid,
    required String nickname,
    String source = 'onboarding',
  });
}

class FirebasePersonalNicknameOnboardingGateway
    implements PersonalNicknameOnboardingGateway {
  FirebasePersonalNicknameOnboardingGateway({FirebaseFunctions? functions})
      : _functionsOverride = functions;

  final FirebaseFunctions? _functionsOverride;

  FirebaseFunctions get _functions =>
      _functionsOverride ?? MtfFirebaseFunctions.instance;

  @override
  Future<void> saveNickname({
    required String uid,
    required String nickname,
    String source = 'onboarding',
  }) async {
    final cleanNickname = nickname.trim();
    if (uid.trim().isEmpty || cleanNickname.isEmpty) {
      throw ArgumentError('uid and nickname are required');
    }
    String previous = '';
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('trainer_profiles')
          .doc(uid)
          .get(const GetOptions(source: Source.server));
      previous = (snapshot.data()?['nickname'] ?? '').toString().trim();
    } catch (_) {
      previous = '<unavailable>';
    }
    if (kDebugMode) {
      debugPrint(
        '[MTF_NICKNAME_WRITE] uid=$uid source=$source '
        'previous=$previous next=$cleanNickname',
      );
    }
    final result = await MtfFirebaseFunctions.call(
      'completeNicknameOnboarding',
      functions: _functions,
      parameters: {'nickname': cleanNickname},
    );
    if (result is! Map ||
        result['completed'] != true ||
        (result['nickname'] as String? ?? '').trim() != cleanNickname) {
      throw StateError('nickname_onboarding_not_confirmed');
    }
  }
}

class FirebasePersonalProfileStartReader implements PersonalProfileStartReader {
  FirebasePersonalProfileStartReader({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  @override
  Future<PersonalProfileStartResult> read(AppAccountUser user) async {
    final snapshot = await _firestore
        .collection('trainer_profiles')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists) {
      throw const PersonalProfileReadException(
        PersonalProfileReadErrorCode.profileNotFound,
      );
    }
    final data = snapshot.data() ?? const <String, dynamic>{};
    if (kDebugMode) {
      final nickname = (data['nickname'] ?? '').toString().trim();
      final realName =
          (data['realName'] ?? data['name'] ?? data['displayName'] ?? '')
              .toString()
              .trim();
      final completedAt = data['onboardingCompletedAt'];
      final completedAtLabel = completedAt is Timestamp
          ? completedAt.toDate().toIso8601String()
          : completedAt?.toString() ?? 'null';
      debugPrint(
        '[MTF_NICKNAME_STATE] uid=${user.uid} '
        'isAnonymous=${user.isAnonymous} '
        'nickname=$nickname '
        'onboardingCompleted=${data['onboardingCompleted'] == true} '
        'onboardingCompletedAt=$completedAtLabel '
        'profileExists=${snapshot.exists}',
      );
      debugPrint(
        '[MTF_ENV_IDENTITY] '
        'projectId=${AppEnvironmentConfig.firebaseProjectId} '
        'appId=${AppEnvironmentConfig.firebaseAppId} '
        'packageName=${AppEnvironmentConfig.packageName} '
        'uid=${user.uid} '
        'isAnonymous=${user.isAnonymous} '
        'profilePath=trainer_profiles/${user.uid} '
        'nickname=$nickname '
        'realName=$realName '
        'onboardingCompleted=${data['onboardingCompleted'] == true}',
      );
    }
    if (data['trainerId'] != user.uid) {
      throw const PersonalProfileReadException(
        PersonalProfileReadErrorCode.identityMismatch,
      );
    }
    if (data['workspaceType'] != 'personal') {
      throw const PersonalProfileReadException(
        PersonalProfileReadErrorCode.workspaceNotReady,
      );
    }
    return PersonalProfileStartResult(
      nickname: (data['nickname'] as String? ?? '').trim(),
      onboardingCompleted: data['onboardingCompleted'] == true,
      profileData: Map<String, dynamic>.from(data),
    );
  }
}
