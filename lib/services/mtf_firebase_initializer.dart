import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import 'app_environment.dart';

enum MtfFirebaseInitializationAction { initialize, reuse }

abstract final class MtfFirebaseInitializer {
  static MtfFirebaseInitializationAction actionFor({
    required bool defaultAppExists,
  }) =>
      defaultAppExists
          ? MtfFirebaseInitializationAction.reuse
          : MtfFirebaseInitializationAction.initialize;

  static Future<FirebaseApp> initialize(AppEnvironment environment) async {
    final existingDefaultApp = _existingDefaultApp();
    final defaultAppExists = existingDefaultApp != null;
    final action = actionFor(defaultAppExists: defaultAppExists);

    try {
      final app =
          existingDefaultApp ?? await _initializeDefaultApp(environment);
      AppEnvironmentConfig.validateFirebaseProject(
        environment: environment,
        projectId: app.options.projectId,
      );
      _debugLog(
        environment: environment,
        projectId: app.options.projectId,
        defaultAppExists: defaultAppExists,
        action: action,
        result: 'success',
      );
      return app;
    } catch (_) {
      _debugLog(
        environment: environment,
        projectId: AppEnvironmentConfig.expectedFirebaseProjectId(environment),
        defaultAppExists: defaultAppExists,
        action: action,
        result: 'failure',
      );
      rethrow;
    }
  }

  static FirebaseApp? _existingDefaultApp() {
    for (final app in Firebase.apps) {
      if (app.name == defaultFirebaseAppName) return app;
    }
    return null;
  }

  static Future<FirebaseApp> _initializeDefaultApp(
    AppEnvironment environment,
  ) {
    final FirebaseOptions? options;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Connect to the native [DEFAULT] app configured by the Android flavor.
      // Supplying another environment's options causes duplicate-app.
      options = null;
    } else if (environment == AppEnvironment.prod) {
      options = DefaultFirebaseOptions.currentPlatform;
    } else {
      options = null;
    }
    return Firebase.initializeApp(options: options);
  }

  static void _debugLog({
    required AppEnvironment environment,
    required String projectId,
    required bool defaultAppExists,
    required MtfFirebaseInitializationAction action,
    required String result,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[MTF_FIREBASE_INIT] '
      'environment=${environment.name} '
      'projectId=$projectId '
      'packageName=${AppEnvironmentConfig.packageNameFor(environment)} '
      'defaultAppExists=$defaultAppExists '
      'action=${action.name} '
      'result=$result',
    );
  }
}
