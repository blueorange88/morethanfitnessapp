import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/app_tier_access_service.dart';

void main() {
  test('Android launcher 이름은 prod와 dev flavor resource로 분리된다', () {
    final prod = File(
      'android/app/src/prod/res/values/strings.xml',
    ).readAsStringSync();
    final dev = File(
      'android/app/src/dev/res/values/strings.xml',
    ).readAsStringSync();

    expect(prod, contains('<string name="app_name">모어댄</string>'));
    expect(dev, contains('<string name="app_name">모어댄 DEV</string>'));
    expect(prod, isNot(contains('모어댄 DEV')));
  });

  test('personal schedules 범위 query 복합 인덱스가 정의돼 있다', () {
    final json = jsonDecode(
      File('firestore.indexes.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final indexes = (json['indexes'] as List).cast<Map<String, dynamic>>();

    final schedules = indexes.singleWhere(
      (index) => index['collectionGroup'] == 'schedules',
    );
    final fields = (schedules['fields'] as List)
        .cast<Map<String, dynamic>>()
        .map((field) => field['fieldPath'])
        .toList();

    expect(fields, ['trainerId', 'workspaceType', 'startAt']);
    expect(schedules['queryScope'], 'COLLECTION');
  });

  test('personal tier는 canonical profile 값만 권한 snapshot에 반영한다', () {
    final access = AppTierAccessService.personalSnapshotFromProfile({
      'tier': 'Beginner',
      'profileCompleted': true,
      'validMemberCount': 3,
      'isSponsor': true,
      'supportTier': 'Grand Prix',
      'organizationTier': 'Master',
    });

    expect(access.tierLabel, 'Beginner');
    expect(access.tierRank, 0);
    expect(access.activeMemberCount, 3);
    expect(access.profileCompleted, isTrue);
    expect(access.isSponsor, isFalse);
    expect(access.supportTierRank, 0);
    expect(access.organizationTierRank, 0);
  });

  test('Home과 smart alarm은 personal owner tier 경로를 전달한다', () {
    final home = File('lib/pages/home_page.dart').readAsStringSync();
    final notifications =
        File('lib/services/notification_service.dart').readAsStringSync();

    expect(home,
        contains('Future<AppTierAccessSnapshot> _loadCurrentTierAccess()'));
    expect(home, contains('personalOwnerUid: _isPersonalWorkspace'));
    expect(home, contains('onError: (Object error, StackTrace stackTrace)'));
    expect(
      notifications,
      contains('AppTierAccessService.loadPersonalTrainerAccess(uid: ownerUid)'),
    );
  });
}
