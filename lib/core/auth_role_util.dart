// lib/core/auth_role_util.dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthRoleUtil {
  static Future<bool> isStaff() async {
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return false;
    final token = await u.getIdTokenResult(true);
    final role = token.claims?['role'];
    return role == 'admin' || role == 'staff' || role == 'manager';
  }

  static Future<String?> currentUid() async {
    return FirebaseAuth.instance.currentUser?.uid;
  }

  static Future<String?> currentName() async {
    final u = FirebaseAuth.instance.currentUser;
    return u?.displayName ?? u?.email;
  }
}
