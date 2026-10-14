import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'app_account_service.dart';

enum PersonalStartStage {
  ensureAnonymousSession,
  bootstrapAnonymousBeginnerProfile,
  personalProfileRead,
  personalWorkspace,
}

enum PersonalStartFailureKind {
  anonymousAccount,
  profile,
  functionsEmulator,
  firestore,
  workspace,
}

class PersonalStartException implements Exception {
  const PersonalStartException({required this.stage, required this.cause});

  final PersonalStartStage stage;
  final Object cause;
}

abstract final class PersonalStartDiagnostics {
  static Future<T> run<T>(
    PersonalStartStage stage,
    Future<T> Function() action,
  ) async {
    _log(stage, 'start');
    try {
      final result = await action();
      _log(stage, 'success');
      return result;
    } catch (error) {
      _logFailure(stage, error);
      throw PersonalStartException(stage: stage, cause: error);
    }
  }

  static T runSync<T>(PersonalStartStage stage, T Function() action) {
    _log(stage, 'start');
    try {
      final result = action();
      _log(stage, 'success');
      return result;
    } catch (error) {
      _logFailure(stage, error);
      throw PersonalStartException(stage: stage, cause: error);
    }
  }

  static PersonalStartFailureKind failureKind(Object? error) {
    if (error is! PersonalStartException) {
      return PersonalStartFailureKind.workspace;
    }
    final firebaseCause = _firebaseCause(error.cause);
    return switch (error.stage) {
      PersonalStartStage.ensureAnonymousSession =>
        PersonalStartFailureKind.anonymousAccount,
      PersonalStartStage.bootstrapAnonymousBeginnerProfile =>
        firebaseCause is FirebaseFunctionsException
            ? PersonalStartFailureKind.functionsEmulator
            : PersonalStartFailureKind.profile,
      PersonalStartStage.personalProfileRead =>
        PersonalStartFailureKind.firestore,
      PersonalStartStage.personalWorkspace =>
        PersonalStartFailureKind.workspace,
    };
  }

  static void _log(PersonalStartStage stage, String status) {
    debugPrint('[MTF_APP_START] ${stage.name} $status');
  }

  static void _logFailure(PersonalStartStage stage, Object error) {
    final cause = _firebaseCause(error);
    final firebaseCode = cause is FirebaseException ? cause.code : '-';
    final functionsCode =
        cause is FirebaseFunctionsException ? cause.code : '-';
    debugPrint(
      '[MTF_APP_START] ${stage.name} failure '
      'runtimeType=${cause.runtimeType} '
      'wrappedRuntimeType=${error.runtimeType} '
      'firebaseCode=$firebaseCode '
      'functionsCode=$functionsCode '
      'message=${_safeMessage(error, cause)}',
    );
  }

  static Object _firebaseCause(Object error) {
    var current = error;
    for (var depth = 0; depth < 3; depth++) {
      if (current is PersonalStartException) {
        current = current.cause;
        continue;
      }
      if (current is AppAccountException && current.cause != null) {
        current = current.cause!;
        continue;
      }
      break;
    }
    return current;
  }

  static String _safeMessage(Object error, Object cause) {
    if (cause is FirebaseFunctionsException) {
      return 'Firebase Functions request failed';
    }
    if (cause is FirebaseException) return 'Firebase request failed';
    if (error is AppAccountException) {
      return 'Account preparation failed (${error.code.name})';
    }
    return 'Startup preparation failed';
  }
}
