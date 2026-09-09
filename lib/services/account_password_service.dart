import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'mtf_firebase_functions.dart';

enum AccountPasswordErrorCode {
  unauthenticated,
  anonymousNotAllowed,
  invalidCurrentPassword,
  weakPassword,
  confirmationMismatch,
  tooManyRequests,
  network,
  finalizeFailed,
  unknown,
}

class AccountPasswordException implements Exception {
  const AccountPasswordException(
    this.code, {
    this.passwordWasUpdated = false,
  });

  final AccountPasswordErrorCode code;
  final bool passwordWasUpdated;
}

abstract interface class AccountPasswordGateway {
  String? get currentEmail;
  bool get isAnonymous;

  Future<void> reauthenticate(String currentPassword);
  Future<void> updatePassword(String newPassword);
  Future<void> forceRefreshIdToken();
  Future<void> completeInitialPasswordChange();
  Future<void> sendPasswordResetEmail();
}

class FirebaseAccountPasswordGateway implements AccountPasswordGateway {
  FirebaseAccountPasswordGateway({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _auth = auth,
        _functions = functions;

  final FirebaseAuth? _auth;
  final FirebaseFunctions? _functions;

  FirebaseAuth get _resolvedAuth => _auth ?? FirebaseAuth.instance;
  FirebaseFunctions get _resolvedFunctions =>
      _functions ?? MtfFirebaseFunctions.instance;

  User get _requiredUser {
    final user = _resolvedAuth.currentUser;
    if (user == null) throw StateError('unauthenticated');
    return user;
  }

  @override
  String? get currentEmail => _resolvedAuth.currentUser?.email?.trim();

  @override
  bool get isAnonymous => _resolvedAuth.currentUser?.isAnonymous ?? false;

  @override
  Future<void> reauthenticate(String currentPassword) async {
    final user = _requiredUser;
    final email = user.email?.trim() ?? '';
    if (email.isEmpty) throw StateError('email_required');
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await user.reauthenticateWithCredential(credential);
  }

  @override
  Future<void> updatePassword(String newPassword) =>
      _requiredUser.updatePassword(newPassword);

  @override
  Future<void> forceRefreshIdToken() async {
    await _requiredUser.getIdToken(true);
  }

  @override
  Future<void> completeInitialPasswordChange() async {
    await MtfFirebaseFunctions.call(
      'completeInitialPasswordChange',
      functions: _resolvedFunctions,
    );
  }

  @override
  Future<void> sendPasswordResetEmail() async {
    final email = currentEmail;
    if (email == null || email.isEmpty) throw StateError('email_required');
    await _resolvedAuth.sendPasswordResetEmail(email: email);
  }
}

class AccountPasswordService {
  AccountPasswordService({AccountPasswordGateway? gateway})
      : _gateway = gateway ?? FirebaseAccountPasswordGateway();

  final AccountPasswordGateway _gateway;
  bool _busy = false;

  String? get currentEmail => _gateway.currentEmail;

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) async {
    if (_gateway.currentEmail == null) {
      throw const AccountPasswordException(
        AccountPasswordErrorCode.unauthenticated,
      );
    }
    if (_gateway.isAnonymous) {
      throw const AccountPasswordException(
        AccountPasswordErrorCode.anonymousNotAllowed,
      );
    }
    if (newPassword != confirmation) {
      throw const AccountPasswordException(
        AccountPasswordErrorCode.confirmationMismatch,
      );
    }
    if (newPassword.length < 8) {
      throw const AccountPasswordException(
          AccountPasswordErrorCode.weakPassword);
    }
    if (_busy) return;
    _busy = true;
    var passwordUpdated = false;
    try {
      await _gateway.reauthenticate(currentPassword);
      await _gateway.updatePassword(newPassword);
      passwordUpdated = true;
      await _gateway.forceRefreshIdToken();
      try {
        await _gateway.completeInitialPasswordChange();
      } catch (_) {
        throw const AccountPasswordException(
          AccountPasswordErrorCode.finalizeFailed,
          passwordWasUpdated: true,
        );
      }
    } on AccountPasswordException {
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AccountPasswordException(
        switch (error.code) {
          'wrong-password' ||
          'invalid-credential' ||
          'user-mismatch' =>
            AccountPasswordErrorCode.invalidCurrentPassword,
          'weak-password' => AccountPasswordErrorCode.weakPassword,
          'too-many-requests' => AccountPasswordErrorCode.tooManyRequests,
          'network-request-failed' => AccountPasswordErrorCode.network,
          _ => AccountPasswordErrorCode.unknown,
        },
        passwordWasUpdated: passwordUpdated,
      );
    } catch (_) {
      throw AccountPasswordException(
        AccountPasswordErrorCode.unknown,
        passwordWasUpdated: passwordUpdated,
      );
    } finally {
      _busy = false;
    }
  }

  Future<void> sendPasswordReset() async {
    if (_busy) return;
    _busy = true;
    try {
      await _gateway.sendPasswordResetEmail();
    } on FirebaseAuthException catch (error) {
      throw AccountPasswordException(
        switch (error.code) {
          'too-many-requests' => AccountPasswordErrorCode.tooManyRequests,
          'network-request-failed' => AccountPasswordErrorCode.network,
          _ => AccountPasswordErrorCode.unknown,
        },
      );
    } catch (_) {
      throw const AccountPasswordException(AccountPasswordErrorCode.unknown);
    } finally {
      _busy = false;
    }
  }
}

String accountPasswordErrorMessage(Object error) {
  if (error is! AccountPasswordException) {
    return '비밀번호를 변경하지 못했어요. 잠시 후 다시 시도해주세요.';
  }
  return switch (error.code) {
    AccountPasswordErrorCode.unauthenticated => '계정에 다시 로그인해주세요.',
    AccountPasswordErrorCode.anonymousNotAllowed => '연결된 이메일 계정에서 변경해주세요.',
    AccountPasswordErrorCode.invalidCurrentPassword => '현재 비밀번호가 올바르지 않아요.',
    AccountPasswordErrorCode.weakPassword => '새 비밀번호는 8자 이상 입력해주세요.',
    AccountPasswordErrorCode.confirmationMismatch => '새 비밀번호 확인이 일치하지 않아요.',
    AccountPasswordErrorCode.tooManyRequests => '요청이 너무 많아요. 잠시 후 다시 시도해주세요.',
    AccountPasswordErrorCode.network => '네트워크 연결을 확인해주세요.',
    AccountPasswordErrorCode.finalizeFailed =>
      '비밀번호는 변경됐지만 계정 확인을 마치지 못했어요. 새 비밀번호로 다시 진행해주세요.',
    AccountPasswordErrorCode.unknown => '비밀번호를 변경하지 못했어요. 잠시 후 다시 시도해주세요.',
  };
}
