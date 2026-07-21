import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'mtf_firebase_functions.dart';

typedef FirebaseEmulatorConnector = FutureOr<void> Function();

class FirebaseEmulatorConfigurationException implements Exception {
  const FirebaseEmulatorConfigurationException();
}

abstract final class FirebaseEmulatorConfig {
  static const requested = bool.fromEnvironment(
    'USE_FIREBASE_EMULATORS',
    defaultValue: false,
  );
  static const host = '127.0.0.1';
  static const authPort = 9099;
  static const firestorePort = 8080;
  static const functionsPort = 5001;

  static const isEnabled = kDebugMode && requested && !kIsWeb;

  @visibleForTesting
  static bool shouldUseEmulators({
    required bool debugMode,
    required bool requested,
    bool isWeb = false,
  }) =>
      debugMode && requested && !isWeb;

  static Future<void> configure() async {
    if (!isEnabled) return;
    await configureConnectors(
      enabled: true,
      auth: () => FirebaseAuth.instance.useAuthEmulator(
        host,
        authPort,
        automaticHostMapping: false,
      ),
      firestore: () => FirebaseFirestore.instance.useFirestoreEmulator(
        host,
        firestorePort,
        automaticHostMapping: false,
      ),
      functions: () => MtfFirebaseFunctions.useEmulator(
        host: host,
        port: functionsPort,
        automaticHostMapping: false,
      ),
    );
    debugPrint(
      '[MTF_FIREBASE_EMULATOR] connected '
      'host=$host '
      'authPort=$authPort '
      'firestorePort=$firestorePort '
      'functionsPort=$functionsPort '
      'region=${MtfFirebaseFunctions.region}',
    );
  }

  @visibleForTesting
  static Future<void> configureConnectors({
    required bool enabled,
    required FirebaseEmulatorConnector auth,
    required FirebaseEmulatorConnector firestore,
    required FirebaseEmulatorConnector functions,
  }) async {
    if (!enabled) return;
    try {
      await auth();
      await firestore();
      await functions();
    } catch (error) {
      debugPrint(
        '[MTF_FIREBASE_EMULATOR] configuration_failed '
        'type=${error.runtimeType}',
      );
      throw const FirebaseEmulatorConfigurationException();
    }
  }
}
