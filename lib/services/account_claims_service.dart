import 'package:firebase_auth/firebase_auth.dart';

class PlatformAccountClaims {
  const PlatformAccountClaims({
    this.platformAdmin = false,
    this.legacyDataAccessApproved = false,
  });

  final bool platformAdmin;
  final bool legacyDataAccessApproved;
}

abstract interface class AccountClaimsGateway {
  Future<PlatformAccountClaims> read({bool forceRefresh = false});
}

class FirebaseAccountClaimsGateway implements AccountClaimsGateway {
  FirebaseAccountClaimsGateway({FirebaseAuth? auth}) : _auth = auth;

  final FirebaseAuth? _auth;

  @override
  Future<PlatformAccountClaims> read({bool forceRefresh = false}) async {
    final user = (_auth ?? FirebaseAuth.instance).currentUser;
    if (user == null || user.isAnonymous) {
      return const PlatformAccountClaims();
    }
    final token = await user.getIdTokenResult(forceRefresh);
    final claims = token.claims ?? const <String, dynamic>{};
    return PlatformAccountClaims(
      platformAdmin: claims['platformAdmin'] == true,
      legacyDataAccessApproved: claims['legacyDataAccessApproved'] == true,
    );
  }
}
