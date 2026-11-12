import 'package:flutter/foundation.dart';

import 'app_environment.dart';

enum DevTierFixture {
  server(null, '서버 실제 등급'),
  beginner(0, 'Beginner'),
  amateur(1, 'Amateur'),
  semiPro(2, 'Semi-Pro'),
  pro(3, 'Pro');

  const DevTierFixture(this.rank, this.label);

  final int? rank;
  final String label;
}

abstract final class DevTierFixtureController {
  static final ValueNotifier<DevTierFixture> selection =
      ValueNotifier<DevTierFixture>(DevTierFixture.server);

  static bool get isAvailable => kDebugMode && AppEnvironmentConfig.isDev;

  static int resolveTierRank(int serverTierRank) {
    if (!isAvailable) return serverTierRank;
    return selection.value.rank ?? serverTierRank;
  }

  static void select(DevTierFixture fixture) {
    if (!isAvailable) return;
    selection.value = fixture;
    debugPrint(
      '[MTF_DEV_TIER_FIXTURE] '
      'selection=${fixture.label} '
      'localOnly=true firestoreWrite=false functionsCall=false',
    );
  }

  @visibleForTesting
  static void resetForTesting() {
    selection.value = DevTierFixture.server;
  }
}
