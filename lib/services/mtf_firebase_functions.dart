import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

final FirebaseFunctions mtfFirebaseFunctions =
    FirebaseFunctions.instanceFor(region: MtfFirebaseFunctions.region);

abstract final class MtfFirebaseFunctions {
  static const region = 'asia-northeast3';
  static bool _usesEmulator = false;

  static FirebaseFunctions get instance => mtfFirebaseFunctions;

  static Future<dynamic> call(
    String name, {
    Object? parameters,
    FirebaseFunctions? functions,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '[MTF_FUNCTIONS_CALLABLE] '
        'projectId=${Firebase.app().options.projectId} '
        'region=$region '
        'emulator=$_usesEmulator '
        'callable=$name',
      );
    }
    final callable = (functions ?? mtfFirebaseFunctions).httpsCallable(name);
    final result = parameters == null
        ? await callable.call()
        : await callable.call(parameters);
    return result.data;
  }

  static FirebaseFunctions useEmulator({
    required String host,
    required int port,
    required bool automaticHostMapping,
  }) {
    mtfFirebaseFunctions.useFunctionsEmulator(
      host,
      port,
      automaticHostMapping: automaticHostMapping,
    );
    _usesEmulator = true;
    return mtfFirebaseFunctions;
  }
}
