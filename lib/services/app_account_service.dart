import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'app_environment.dart';
import 'mtf_firebase_functions.dart';

enum AppAccountState { guest, linked, verified, organizationMember }

enum AppTier { beginner, amateur, semiPro, pro, master, grandPrix }

enum AppAccountErrorCode {
  invalidEmail,
  weakPassword,
  emailAlreadyInUse,
  invalidCredential,
  tooManyRequests,
  network,
  requestInProgress,
  googleSetupRequired,
  anonymousProviderDisabled,
  unauthenticated,
  credentialAlreadyInUse,
  accountExistsWithDifferentCredential,
  providerAlreadyLinked,
  requiresRecentLogin,
  uidChangedUnexpectedly,
  unknown,
}

class AppAccountException implements Exception {
  const AppAccountException(this.code, {this.cause});

  final AppAccountErrorCode code;
  final Object? cause;

  @override
  String toString() => 'AppAccountException(${code.name})';
}

class AppAccountUser {
  const AppAccountUser({
    required this.uid,
    required this.email,
    required this.emailVerified,
    required this.isAnonymous,
  });

  final String uid;
  final String email;
  final bool emailVerified;
  final bool isAnonymous;
}

class AppAccountSnapshot {
  const AppAccountSnapshot({
    required this.state,
    required this.tier,
    this.user,
  });

  const AppAccountSnapshot.guest()
      : state = AppAccountState.guest,
        tier = AppTier.beginner,
        user = null;

  final AppAccountState state;
  final AppTier tier;
  final AppAccountUser? user;

  bool get isGuest => state == AppAccountState.guest;

  factory AppAccountSnapshot.fromUser(AppAccountUser? user) {
    if (user == null || user.isAnonymous) {
      return const AppAccountSnapshot.guest();
    }
    return AppAccountSnapshot(
      state: user.emailVerified
          ? AppAccountState.verified
          : AppAccountState.linked,
      tier: AppTier.beginner,
      user: user,
    );
  }
}

class AppAccountRegistrationResult {
  const AppAccountRegistrationResult({
    required this.snapshot,
    required this.verificationEmailSent,
  });

  final AppAccountSnapshot snapshot;
  final bool verificationEmailSent;
}

abstract interface class AppAccountAuthGateway {
  AppAccountUser? get currentUser;

  Stream<AppAccountUser?> authStateChanges();

  Future<AppAccountUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<AppAccountUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  Future<void> sendEmailVerification();

  Future<void> sendPasswordResetEmail(String email);

  Future<void> signOut();
}

abstract interface class AppAnonymousIdentityGateway {
  Future<AppAccountUser> signInAnonymously();

  Future<AppAccountUser> linkWithEmailCredential({
    required String email,
    required String password,
  });

  Future<void> forceRefreshIdToken();
}

abstract interface class AnonymousProfileGateway {
  Future<void> bootstrapAnonymousBeginnerProfile();

  Future<void> transitionAnonymousProfileToLinked();

  Future<Map<String, dynamic>> reconcilePersonalTier();
}

class FirebaseAnonymousProfileGateway implements AnonymousProfileGateway {
  FirebaseAnonymousProfileGateway({FirebaseFunctions? functions})
      : _functions = functions;

  final FirebaseFunctions? _functions;

  FirebaseFunctions get _resolvedFunctions =>
      _functions ?? MtfFirebaseFunctions.instance;

  @override
  Future<void> bootstrapAnonymousBeginnerProfile() async {
    await MtfFirebaseFunctions.call(
      'bootstrapAnonymousBeginnerProfile',
      functions: _resolvedFunctions,
    );
  }

  @override
  Future<void> transitionAnonymousProfileToLinked() async {
    await MtfFirebaseFunctions.call(
      'transitionAnonymousProfileToLinked',
      functions: _resolvedFunctions,
    );
  }

  @override
  Future<Map<String, dynamic>> reconcilePersonalTier() async {
    final result = await MtfFirebaseFunctions.call(
      'reconcilePersonalTier',
      functions: _resolvedFunctions,
    );
    if (result is! Map) {
      throw StateError('personal_tier_reconcile_invalid_response');
    }
    return Map<String, dynamic>.from(result);
  }
}

class FirebaseAppAccountAuthGateway
    implements AppAccountAuthGateway, AppAnonymousIdentityGateway {
  FirebaseAppAccountAuthGateway({FirebaseAuth? auth})
      : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  AppAccountUser? get currentUser => _mapUser(_auth.currentUser);

  @override
  Stream<AppAccountUser?> authStateChanges() =>
      _auth.authStateChanges().map(_mapUser);

  @override
  Future<AppAccountUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _requiredUser(credential.user);
  }

  @override
  Future<AppAccountUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _requiredUser(credential.user);
  }

  @override
  Future<AppAccountUser> signInAnonymously() async {
    final credential = await _auth.signInAnonymously();
    return _requiredUser(credential.user);
  }

  @override
  Future<AppAccountUser> linkWithEmailCredential({
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      throw const AppAccountException(AppAccountErrorCode.unauthenticated);
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    final result = await user.linkWithCredential(credential);
    return _requiredUser(result.user);
  }

  @override
  Future<void> forceRefreshIdToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AppAccountException(AppAccountErrorCode.unauthenticated);
    }
    await user.getIdToken(true);
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('authenticated_user_required');
    await user.sendEmailVerification();
  }

  @override
  Future<void> sendPasswordResetEmail(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  @override
  Future<void> signOut() => _auth.signOut();

  static AppAccountUser _requiredUser(User? user) {
    final mapped = _mapUser(user);
    if (mapped == null) throw StateError('authenticated_user_required');
    return mapped;
  }

  static AppAccountUser? _mapUser(User? user) {
    if (user == null) return null;
    return AppAccountUser(
      uid: user.uid,
      email: (user.email ?? '').trim(),
      emailVerified: user.emailVerified,
      isAnonymous: user.isAnonymous,
    );
  }
}

class AppAccountService {
  AppAccountService({
    AppAccountAuthGateway? gateway,
    AppAnonymousIdentityGateway? anonymousGateway,
    AnonymousProfileGateway? profileGateway,
  }) {
    final resolvedGateway = gateway ?? FirebaseAppAccountAuthGateway();
    _gateway = resolvedGateway;
    if (anonymousGateway != null) {
      _anonymousGateway = anonymousGateway;
    } else if (resolvedGateway is AppAnonymousIdentityGateway) {
      _anonymousGateway = resolvedGateway as AppAnonymousIdentityGateway;
    } else {
      _anonymousGateway = null;
    }
    _profileGateway = profileGateway ?? FirebaseAnonymousProfileGateway();
  }

  static final AppAccountService instance = AppAccountService();

  late final AppAccountAuthGateway _gateway;
  late final AppAnonymousIdentityGateway? _anonymousGateway;
  late final AnonymousProfileGateway _profileGateway;
  bool _requestInProgress = false;
  Future<AppAccountUser>? _anonymousSessionInFlight;

  AppAccountSnapshot get currentSnapshot =>
      AppAccountSnapshot.fromUser(_gateway.currentUser);

  AppAccountUser? get currentUser => _gateway.currentUser;

  Stream<AppAccountUser?> userChanges() =>
      _gateway.authStateChanges().distinct((a, b) =>
          a?.uid == b?.uid &&
          a?.isAnonymous == b?.isAnonymous &&
          a?.emailVerified == b?.emailVerified);

  Future<void> sendCurrentUserEmailVerification() async {
    final current = _gateway.currentUser;
    if (current == null || current.isAnonymous) {
      throw const AppAccountException(AppAccountErrorCode.unauthenticated);
    }
    try {
      await _gateway.sendEmailVerification();
    } catch (error) {
      throw _translate(error);
    }
  }

  Stream<AppAccountSnapshot> accountStateChanges() => _gateway
      .authStateChanges()
      .map(AppAccountSnapshot.fromUser)
      .distinct((a, b) =>
          a.state == b.state &&
          a.user?.uid == b.user?.uid &&
          a.user?.emailVerified == b.user?.emailVerified);

  Future<AppAccountUser> ensureAnonymousSession() {
    final current = _gateway.currentUser;
    if (current != null) return Future.value(current);
    final inFlight = _anonymousSessionInFlight;
    if (inFlight != null) return inFlight;

    final operation = _createAnonymousSessionAndClear();
    _anonymousSessionInFlight = operation;
    return operation;
  }

  Future<AppAccountUser> _createAnonymousSessionAndClear() async {
    try {
      return await _createAnonymousSession();
    } finally {
      _anonymousSessionInFlight = null;
    }
  }

  Future<AppAccountUser> _createAnonymousSession() async {
    final gateway = _anonymousGateway;
    if (gateway == null) {
      throw const AppAccountException(AppAccountErrorCode.unknown);
    }
    try {
      return await gateway.signInAnonymously();
    } catch (error) {
      if (error is FirebaseAuthException &&
          error.code == 'operation-not-allowed') {
        throw AppAccountException(
          AppAccountErrorCode.anonymousProviderDisabled,
          cause: error,
        );
      }
      throw _translate(error);
    }
  }

  Future<void> bootstrapAnonymousBeginnerProfile() async {
    final current = _gateway.currentUser;
    if (current == null || !current.isAnonymous) {
      throw const AppAccountException(AppAccountErrorCode.unauthenticated);
    }
    try {
      await _profileGateway.bootstrapAnonymousBeginnerProfile();
    } catch (error) {
      throw _translate(error);
    }
  }

  Future<Map<String, dynamic>> reconcilePersonalTier() async {
    try {
      final result = await _profileGateway.reconcilePersonalTier();
      if (kDebugMode) {
        debugPrint(
          '[MTF_TIER_RECONCILE] '
          'environment=${AppEnvironmentConfig.environmentName} '
          'currentTier=${result['tier'] ?? 'unknown'} '
          'scheduleCount=${result['scheduleCount'] ?? 0} '
          'scheduleGoal=${result['scheduleGoal'] ?? 10} '
          'scheduleMissionCompleted=${result['scheduleMissionCompleted'] == true} '
          'teacherInfoCompleted=${result['teacherInfoCompleted'] == true} '
          'completedMissionCount=${result['completedMissionCount'] ?? 0} '
          'eligible=${result['eligible'] == true} '
          'action=${result['changed'] == true ? 'promote' : 'keep'} '
          'result=success errorCode=none',
        );
      }
      return result;
    } catch (error) {
      if (kDebugMode) {
        final code = error is FirebaseFunctionsException
            ? error.code
            : error.runtimeType.toString();
        debugPrint(
          '[MTF_TIER_RECONCILE] '
          'environment=${AppEnvironmentConfig.environmentName} '
          'currentTier=unknown scheduleCount=unknown scheduleGoal=10 '
          'scheduleMissionCompleted=false teacherInfoCompleted=false '
          'completedMissionCount=unknown eligible=false action=skip '
          'result=failure errorCode=$code',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> claimTierCelebration(
    String transitionId,
  ) async {
    try {
      final result = await MtfFirebaseFunctions.call(
        'claimTierCelebration',
        parameters: <String, dynamic>{'transitionId': transitionId},
      );
      if (result is! Map) {
        throw StateError('tier_celebration_claim_invalid_response');
      }
      return Map<String, dynamic>.from(result);
    } catch (error) {
      throw _translate(error);
    }
  }

  Future<AppAccountUser> linkAnonymousWithEmail({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    _validateEmail(cleanEmail);
    _validatePassword(password);

    return _guard(() async {
      final before = _gateway.currentUser;
      final gateway = _anonymousGateway;
      if (before == null || !before.isAnonymous || gateway == null) {
        throw const AppAccountException(AppAccountErrorCode.unauthenticated);
      }
      try {
        final linked = await gateway.linkWithEmailCredential(
          email: cleanEmail,
          password: password,
        );
        if (linked.uid != before.uid) {
          throw const AppAccountException(
            AppAccountErrorCode.uidChangedUnexpectedly,
          );
        }
        await gateway.forceRefreshIdToken();
        await _profileGateway.transitionAnonymousProfileToLinked();
        return linked;
      } catch (error) {
        throw _translate(error);
      }
    });
  }

  Future<AppAccountRegistrationResult> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    _validateEmail(cleanEmail);
    _validatePassword(password);

    return _guard(() async {
      try {
        final user = await _gateway.createUserWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
        var verificationSent = false;
        try {
          await _gateway.sendEmailVerification();
          verificationSent = true;
        } catch (_) {
          verificationSent = false;
        }
        return AppAccountRegistrationResult(
          snapshot: AppAccountSnapshot.fromUser(user),
          verificationEmailSent: verificationSent,
        );
      } catch (error) {
        throw _translate(error);
      }
    });
  }

  Future<AppAccountSnapshot> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim();
    _validateEmail(cleanEmail);
    if (password.isEmpty) {
      throw const AppAccountException(AppAccountErrorCode.weakPassword);
    }

    return _guard(() async {
      try {
        final user = await _gateway.signInWithEmailAndPassword(
          email: cleanEmail,
          password: password,
        );
        return AppAccountSnapshot.fromUser(user);
      } catch (error) {
        throw _translate(error);
      }
    });
  }

  Future<void> sendPasswordReset(String email) async {
    final cleanEmail = email.trim();
    _validateEmail(cleanEmail);
    await _guard(() async {
      try {
        await _gateway.sendPasswordResetEmail(cleanEmail);
      } catch (error) {
        throw _translate(error);
      }
    });
  }

  Future<void> signOut() async {
    await _guard(() async {
      try {
        await _gateway.signOut();
      } catch (error) {
        throw _translate(error);
      }
    });
  }

  Future<AppAccountSnapshot> signInWithGoogle() async {
    throw const AppAccountException(
      AppAccountErrorCode.googleSetupRequired,
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    if (_requestInProgress) {
      throw const AppAccountException(
        AppAccountErrorCode.requestInProgress,
      );
    }
    _requestInProgress = true;
    try {
      return await action();
    } finally {
      _requestInProgress = false;
    }
  }

  static void _validateEmail(String email) {
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    if (!valid) {
      throw const AppAccountException(AppAccountErrorCode.invalidEmail);
    }
  }

  static void _validatePassword(String password) {
    if (password.length < 6) {
      throw const AppAccountException(AppAccountErrorCode.weakPassword);
    }
  }

  static AppAccountException _translate(Object error) {
    if (error is AppAccountException) return error;
    if (error is FirebaseAuthException) {
      return AppAccountException(
        switch (error.code) {
          'invalid-email' => AppAccountErrorCode.invalidEmail,
          'weak-password' => AppAccountErrorCode.weakPassword,
          'email-already-in-use' => AppAccountErrorCode.emailAlreadyInUse,
          'credential-already-in-use' =>
            AppAccountErrorCode.credentialAlreadyInUse,
          'account-exists-with-different-credential' =>
            AppAccountErrorCode.accountExistsWithDifferentCredential,
          'provider-already-linked' =>
            AppAccountErrorCode.providerAlreadyLinked,
          'requires-recent-login' => AppAccountErrorCode.requiresRecentLogin,
          'wrong-password' ||
          'user-not-found' ||
          'invalid-credential' =>
            AppAccountErrorCode.invalidCredential,
          'too-many-requests' => AppAccountErrorCode.tooManyRequests,
          'network-request-failed' => AppAccountErrorCode.network,
          _ => AppAccountErrorCode.unknown,
        },
        cause: error,
      );
    }
    return AppAccountException(AppAccountErrorCode.unknown, cause: error);
  }
}

String appAccountErrorMessage(Object error) {
  if (error is! AppAccountException) {
    return '계정 요청을 처리하지 못했어요. 잠시 후 다시 시도해주세요.';
  }
  return switch (error.code) {
    AppAccountErrorCode.invalidEmail => '이메일 주소 형식을 확인해주세요.',
    AppAccountErrorCode.weakPassword => '비밀번호는 6자 이상 입력해주세요.',
    AppAccountErrorCode.emailAlreadyInUse =>
      '이미 사용 중인 이메일이에요. 기록은 자동으로 합치지 않습니다.',
    AppAccountErrorCode.invalidCredential => '이메일 또는 비밀번호가 올바르지 않아요.',
    AppAccountErrorCode.tooManyRequests => '요청이 너무 많아요. 잠시 후 다시 시도해주세요.',
    AppAccountErrorCode.network => '네트워크 연결을 확인해주세요.',
    AppAccountErrorCode.requestInProgress => '계정 요청을 처리하고 있어요.',
    AppAccountErrorCode.googleSetupRequired =>
      'Google 계정 연결은 설정 확인 후 제공할 예정이에요.',
    AppAccountErrorCode.anonymousProviderDisabled =>
      '익명 시작 기능을 사용할 수 없어요. 잠시 후 다시 시도해주세요.',
    AppAccountErrorCode.unauthenticated => '계정 연결을 시작할 사용자를 확인할 수 없어요.',
    AppAccountErrorCode.credentialAlreadyInUse ||
    AppAccountErrorCode.accountExistsWithDifferentCredential =>
      '이미 사용 중인 계정이에요. 기록은 자동으로 합치지 않습니다.',
    AppAccountErrorCode.providerAlreadyLinked => '이미 연결된 로그인 방식이에요.',
    AppAccountErrorCode.requiresRecentLogin => '보안을 위해 다시 인증한 뒤 시도해주세요.',
    AppAccountErrorCode.uidChangedUnexpectedly =>
      '기존 기록을 보호하기 위해 계정 연결을 중단했어요.',
    AppAccountErrorCode.unknown => '계정 요청을 처리하지 못했어요. 잠시 후 다시 시도해주세요.',
  };
}
