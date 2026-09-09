import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/home_deleted_member_schedule_service.dart';
import 'package:mtf_app/services/home_schedule_firestore_service.dart';

void main() {
  group('deleted Personal member resolution', () {
    test('keeps existing members and removes only a missing member', () {
      final deleted = resolveDeletedPersonalMemberIds(
        linkedMemberIds: {'member-a', 'member-b', 'member-c'},
        ownedMembersById: {
          'member-a': const {'workspaceType': 'personal'},
          'member-c': const {'workspaceType': 'personal'},
        },
      );

      expect(deleted, {'member-b'});
    });

    test('removes all linked IDs when all owner members are missing', () {
      final deleted = resolveDeletedPersonalMemberIds(
        linkedMemberIds: {'member-a', 'member-b'},
        ownedMembersById: const {},
      );

      expect(deleted, {'member-a', 'member-b'});
    });

    test('treats deleted owner documents as unavailable', () {
      final deleted = resolveDeletedPersonalMemberIds(
        linkedMemberIds: {'active', 'deleted', 'pending'},
        ownedMembersById: {
          'active': const {'isDeleted': false},
          'deleted': const {'isDeleted': true},
          'pending': const {'deleteStatus': 'pending_delete'},
        },
      );

      expect(deleted, {'deleted', 'pending'});
    });
  });

  group('schedule cleanup authority', () {
    test('does not write cleanup from cache or pending snapshots', () {
      expect(
        shouldCleanupDeletedMemberScheduleLinks(
          isFromCache: true,
          hasPendingWrites: false,
          hasDeletedMemberIds: true,
        ),
        isFalse,
      );
      expect(
        shouldCleanupDeletedMemberScheduleLinks(
          isFromCache: false,
          hasPendingWrites: true,
          hasDeletedMemberIds: true,
        ),
        isFalse,
      );
    });

    test('allows cleanup only from an authoritative server snapshot', () {
      expect(
        shouldCleanupDeletedMemberScheduleLinks(
          isFromCache: false,
          hasPendingWrites: false,
          hasDeletedMemberIds: true,
        ),
        isTrue,
      );
    });
  });

  test('Personal lookup is owner-scoped without document ID whereIn', () {
    final source = File(
      'lib/services/home_deleted_member_schedule_service.dart',
    ).readAsStringSync();

    expect(source, contains("where('trainerId', isEqualTo: ownerUid)"));
    expect(
      source,
      contains("where('workspaceType', isEqualTo: 'personal')"),
    );
    expect(source, isNot(contains('FieldPath.documentId')));
    expect(source, isNot(contains('SharedPreferences')));
    expect(
      source.indexOf('if (memberIds.isEmpty) return <String>{};'),
      lessThan(source.indexOf('final snapshot = await _members')),
    );
  });

  test('Home catches member resolution failures without exposing IDs', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();

    expect(source, contains('[MTF_SCHEDULE_MEMBER_RESOLUTION]'));
    expect(source, contains('errorCode=\$errorCode'));
    expect(source, contains('scheduleData.clear();'));
    expect(
      source,
      isNot(contains('[MTF_SCHEDULE_MEMBER_RESOLUTION] memberId=')),
    );
  });

  test('Personal schedules do not write derived nextLessonAt to members', () {
    expect(shouldPersistMemberNextLessonCache('personal-owner'), isFalse);
    expect(shouldPersistMemberNextLessonCache('  personal-owner  '), isFalse);
    expect(shouldPersistMemberNextLessonCache(null), isTrue);
    expect(shouldPersistMemberNextLessonCache(''), isTrue);

    final source = File(
      'lib/services/home_schedule_firestore_service.dart',
    ).readAsStringSync();
    final guardIndex = source.indexOf(
      'if (!shouldPersistMemberNextLessonCache(ownerUid)) return;',
    );
    final memberWriteIndex = source.indexOf(
      "await _members.doc(cleanMemberId).set({",
    );

    expect(guardIndex, greaterThanOrEqualTo(0));
    expect(memberWriteIndex, greaterThan(guardIndex));
  });
}
