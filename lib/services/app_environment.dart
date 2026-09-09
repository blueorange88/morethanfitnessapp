import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

enum AppEnvironment { dev, prod }

abstract final class AppEnvironmentConfig {
  static const productionFirebaseProjectId = 'more-than-fitness-f6adb';
  static const developmentFirebaseProjectId = 'more-than-fitness-dev-mft';
  static const productionPackageName = 'com.example.mtf_app';
  static const developmentPackageName = 'com.example.mtf_app.dev';
  static AppEnvironment _current = AppEnvironment.prod;
  static String _firebaseProjectId = '';
  static String _firebaseAppId = '';
  static final Set<String> _loggedDebugLegacyAccessEntries = <String>{};

  static AppEnvironment get current => _current;
  static bool get isDev => _current == AppEnvironment.dev;
  static String get environmentName => _current.name;
  static String get packageName => packageNameFor(_current);

  static String packageNameFor(AppEnvironment environment) =>
      environment == AppEnvironment.dev
          ? developmentPackageName
          : productionPackageName;

  static String expectedFirebaseProjectId(AppEnvironment environment) =>
      environment == AppEnvironment.dev
          ? developmentFirebaseProjectId
          : productionFirebaseProjectId;

  static bool get canOpenDebugLegacyWorkspace =>
      canOpenDebugLegacyWorkspaceForIdentity(
        debugBuild: kDebugMode,
        environment: _current,
        projectId: _firebaseProjectId,
        packageName: packageName,
      );

  @visibleForTesting
  static bool canOpenDebugLegacyWorkspaceForIdentity({
    required bool debugBuild,
    required AppEnvironment environment,
    required String projectId,
    required String packageName,
  }) {
    return debugBuild &&
        environment == AppEnvironment.dev &&
        projectId.trim() == developmentFirebaseProjectId &&
        packageName.trim() == developmentPackageName;
  }

  static void debugLogLegacyWorkspaceAccess(String entryPoint) {
    if (!kDebugMode || !_loggedDebugLegacyAccessEntries.add(entryPoint)) return;
    debugPrint(
      '[MTF_DEBUG_LEGACY_ACCESS] '
      'environment=$environmentName '
      'projectId=${_firebaseProjectId.isEmpty ? 'uninitialized' : _firebaseProjectId} '
      'packageName=$packageName '
      'debugBuild=$kDebugMode '
      'allowed=$canOpenDebugLegacyWorkspace '
      'entryPoint=$entryPoint',
    );
  }

  static String get firebaseProjectId {
    if (_firebaseProjectId.isEmpty) {
      throw StateError('firebase_environment_not_initialized');
    }
    return _firebaseProjectId;
  }

  static String get firebaseAppId {
    if (_firebaseAppId.isEmpty) {
      throw StateError('firebase_environment_not_initialized');
    }
    return _firebaseAppId;
  }

  static void select(AppEnvironment environment) {
    _current = environment;
  }

  static void bindFirebaseApp(FirebaseApp app) {
    validateFirebaseProject(
      environment: _current,
      projectId: app.options.projectId,
    );
    _firebaseProjectId = app.options.projectId;
    _firebaseAppId = app.options.appId;
  }

  static void validateFirebaseProject({
    required AppEnvironment environment,
    required String projectId,
  }) {
    final cleanProjectId = projectId.trim();
    if (cleanProjectId.isEmpty) {
      throw StateError('firebase_project_id_missing');
    }
    if (cleanProjectId != expectedFirebaseProjectId(environment)) {
      throw StateError(
        environment == AppEnvironment.dev
            ? 'dev_firebase_project_mismatch'
            : 'prod_firebase_project_mismatch',
      );
    }
  }

  static String personalScope(String uid, {String? projectId}) {
    final cleanUid = uid.trim();
    final cleanProjectId = (projectId ?? firebaseProjectId).trim();
    if (cleanProjectId.isEmpty || cleanUid.isEmpty) {
      throw ArgumentError('projectId and uid are required');
    }
    return 'mtf_${_safeKeyPart(cleanProjectId)}_${_safeKeyPart(cleanUid)}';
  }

  static String personalPreferenceKey({
    required String uid,
    required String featureKey,
    String? projectId,
  }) {
    final cleanFeatureKey = featureKey.trim();
    if (cleanFeatureKey.isEmpty) {
      throw ArgumentError('featureKey is required');
    }
    return '${personalScope(uid, projectId: projectId)}_'
        '${_safeKeyPart(cleanFeatureKey)}';
  }

  static void debugLogEnvironment() {
    if (!kDebugMode) return;
    debugPrint(
      '[MTF_APP_ENV] environment=$environmentName '
      'projectId=$firebaseProjectId packageName=$packageName',
    );
  }

  static String _safeKeyPart(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}
