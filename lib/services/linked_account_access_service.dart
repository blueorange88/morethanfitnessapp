import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'app_account_service.dart';
import 'mtf_firebase_functions.dart';

enum LinkedAccountAccessStatus {
  passwordChangeRequired,
  personalWorkspaceReady,
  legacyAccessReady,
  profileMissing,
  bootstrapFailed,
  anonymousNotAllowed,
  permissionDenied,
  identityMismatch,
  migrationApprovalRequired,
  unknown,
}

bool isCanonicalPersonalProfile(
  Map<String, dynamic> data, {
  required String uid,
}) {
  final accountState = data['accountState'];
  return (data['trainerId'] as String?)?.trim() == uid &&
      (accountState == 'linked' || accountState == 'verified') &&
      data['workspaceType'] == 'personal' &&
      data['workspaceStatus'] == 'active' &&
      data['role'] == 'personal';
}

abstract interface class LinkedAccountAccessGateway {
  Future<LinkedAccountAccessStatus> check(AppAccountUser user);
}

class FirebaseLinkedAccountAccessGateway implements LinkedAccountAccessGateway {
  FirebaseLinkedAccountAccessGateway({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? MtfFirebaseFunctions.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  @override
  Future<LinkedAccountAccessStatus> check(AppAccountUser user) async {
    if (user.isAnonymous) {
      return LinkedAccountAccessStatus.anonymousNotAllowed;
    }
    try {
      final reference = _firestore.collection('trainer_profiles').doc(user.uid);
      var snapshot = await reference.get();
      if (!snapshot.exists) {
        try {
          await MtfFirebaseFunctions.call(
            'bootstrapTrainerProfile',
            functions: _functions,
          );
        } on FirebaseFunctionsException catch (error) {
          if (error.code == 'permission-denied') {
            return LinkedAccountAccessStatus.anonymousNotAllowed;
          }
          return LinkedAccountAccessStatus.bootstrapFailed;
        } catch (_) {
          return LinkedAccountAccessStatus.bootstrapFailed;
        }
        snapshot = await reference.get();
      }
      if (!snapshot.exists) return LinkedAccountAccessStatus.bootstrapFailed;

      final data = snapshot.data() ?? const <String, dynamic>{};
      if ((data['trainerId'] as String?)?.trim() != user.uid) {
        return LinkedAccountAccessStatus.identityMismatch;
      }
      if (data['mustChangePassword'] == true) {
        return LinkedAccountAccessStatus.passwordChangeRequired;
      }
      if (data['legacyDataAccessApproved'] == true) {
        return LinkedAccountAccessStatus.legacyAccessReady;
      }
      if (isCanonicalPersonalProfile(data, uid: user.uid)) {
        return LinkedAccountAccessStatus.personalWorkspaceReady;
      }
      return LinkedAccountAccessStatus.migrationApprovalRequired;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return LinkedAccountAccessStatus.permissionDenied;
      }
      return LinkedAccountAccessStatus.unknown;
    } catch (_) {
      return LinkedAccountAccessStatus.unknown;
    }
  }
}
