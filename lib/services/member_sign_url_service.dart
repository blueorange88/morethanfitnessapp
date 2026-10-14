import 'package:flutter/foundation.dart';

import 'app_environment.dart';

abstract final class MemberSignUrlService {
  static Uri build(String token) {
    return buildForEnvironment(
      token: token,
      environment: AppEnvironmentConfig.current,
    );
  }

  @visibleForTesting
  static Uri buildForEnvironment({
    required String token,
    required AppEnvironment environment,
  }) {
    final cleanToken = token.trim();
    if (cleanToken.isEmpty) {
      throw ArgumentError.value(token, 'token', 'must not be empty');
    }

    final projectId = AppEnvironmentConfig.expectedFirebaseProjectId(
      environment,
    );
    return Uri.https('$projectId.web.app', '/sign', {'t': cleanToken});
  }
}
