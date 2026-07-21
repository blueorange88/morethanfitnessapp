import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/app_environment.dart';
import 'package:mtf_app/services/mtf_firebase_initializer.dart';
import 'package:mtf_app/widgets/app_environment_banner.dart';

void main() {
  test('prod와 dev Android packageName을 분리한다', () {
    AppEnvironmentConfig.select(AppEnvironment.prod);
    expect(AppEnvironmentConfig.packageName, 'com.example.mtf_app');

    AppEnvironmentConfig.select(AppEnvironment.dev);
    expect(AppEnvironmentConfig.packageName, 'com.example.mtf_app.dev');
  });

  test('개발 작업공간은 정확한 DEV Debug identity에서만 허용한다', () {
    bool allowed({
      required bool debugBuild,
      required AppEnvironment environment,
      required String projectId,
      required String packageName,
    }) =>
        AppEnvironmentConfig.canOpenDebugLegacyWorkspaceForIdentity(
          debugBuild: debugBuild,
          environment: environment,
          projectId: projectId,
          packageName: packageName,
        );

    expect(
      allowed(
        debugBuild: true,
        environment: AppEnvironment.dev,
        projectId: AppEnvironmentConfig.developmentFirebaseProjectId,
        packageName: AppEnvironmentConfig.developmentPackageName,
      ),
      isTrue,
    );
    expect(
      allowed(
        debugBuild: true,
        environment: AppEnvironment.prod,
        projectId: AppEnvironmentConfig.productionFirebaseProjectId,
        packageName: AppEnvironmentConfig.productionPackageName,
      ),
      isFalse,
    );
    expect(
      allowed(
        debugBuild: false,
        environment: AppEnvironment.dev,
        projectId: AppEnvironmentConfig.developmentFirebaseProjectId,
        packageName: AppEnvironmentConfig.developmentPackageName,
      ),
      isFalse,
    );
    expect(
      allowed(
        debugBuild: true,
        environment: AppEnvironment.dev,
        projectId: AppEnvironmentConfig.productionFirebaseProjectId,
        packageName: AppEnvironmentConfig.developmentPackageName,
      ),
      isFalse,
    );
    expect(
      allowed(
        debugBuild: true,
        environment: AppEnvironment.dev,
        projectId: AppEnvironmentConfig.developmentFirebaseProjectId,
        packageName: AppEnvironmentConfig.productionPackageName,
      ),
      isFalse,
    );
  });

  test('personal key는 Firebase projectId와 UID를 모두 포함한다', () {
    expect(
      AppEnvironmentConfig.personalPreferenceKey(
        projectId: 'project-dev',
        uid: 'uid-a',
        featureKey: 'header_history',
      ),
      'mtf_project-dev_uid-a_header_history',
    );
    expect(
      AppEnvironmentConfig.personalScope(
        'uid-a',
        projectId: 'project-dev',
      ),
      isNot(
        AppEnvironmentConfig.personalScope(
          'uid-a',
          projectId: 'project-prod',
        ),
      ),
    );
  });

  test('dev가 운영 Firebase projectId를 사용하면 명확히 중단한다', () {
    expect(
      () => AppEnvironmentConfig.validateFirebaseProject(
        environment: AppEnvironment.dev,
        projectId: AppEnvironmentConfig.productionFirebaseProjectId,
      ),
      throwsStateError,
    );
    expect(
      () => AppEnvironmentConfig.validateFirebaseProject(
        environment: AppEnvironment.dev,
        projectId: AppEnvironmentConfig.developmentFirebaseProjectId,
      ),
      returnsNormally,
    );
    expect(
      () => AppEnvironmentConfig.validateFirebaseProject(
        environment: AppEnvironment.dev,
        projectId: 'another-development-project',
      ),
      throwsStateError,
    );
  });

  test('Firebase 기본 앱이 이미 있으면 initialize 대신 reuse한다', () {
    expect(
      MtfFirebaseInitializer.actionFor(defaultAppExists: false),
      MtfFirebaseInitializationAction.initialize,
    );
    expect(
      MtfFirebaseInitializer.actionFor(defaultAppExists: true),
      MtfFirebaseInitializationAction.reuse,
    );
  });

  testWidgets('dev에만 방해하지 않는 DEV 표시를 겹쳐 표시한다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppEnvironmentBanner(
          enabled: true,
          child: Scaffold(body: Text('home')),
        ),
      ),
    );
    expect(find.byKey(const Key('dev_environment_banner')), findsOneWidget);
    expect(find.text('home'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: AppEnvironmentBanner(
          enabled: false,
          child: Scaffold(body: Text('home')),
        ),
      ),
    );
    expect(find.byKey(const Key('dev_environment_banner')), findsNothing);
  });

  test('Android flavor는 dev 설정 누락 시 운영 설정 fallback을 차단한다', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('create("prod")'));
    expect(gradle, contains('create("dev")'));
    expect(gradle, contains('applicationIdSuffix = ".dev"'));
    expect(gradle, contains('src/dev/google-services.json'));
    expect(gradle, contains('devGoogleServicesFile.exists()'));
  });
}
