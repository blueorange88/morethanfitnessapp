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

  group('deletedMemberCleanupTargetDocIds', () {
    test('삭제 회원의 스케줄만 대상으로 삼고 다른 회원·연결 없는 스케줄은 제외한다', () {
      final targets = deletedMemberCleanupTargetDocIds(
        memberIdByDocId: const {'s1': 'gone', 's2': 'alive', 's3': ''},
        deletedMemberIds: {'gone'},
        blockedDocIds: <String>{},
      );
      expect(targets, {'s1'});
    });

    test('규칙이 거부한 문서는 다시 대상이 되지 않아 재시도 루프가 끊긴다', () {
      final blocked = <String>{};
      const docs = {'s1': 'gone', 's2': 'gone'};
      var targets = deletedMemberCleanupTargetDocIds(
        memberIdByDocId: docs,
        deletedMemberIds: {'gone'},
        blockedDocIds: blocked,
      );
      expect(targets, {'s1', 's2'});

      blocked.addAll(targets);
      targets = deletedMemberCleanupTargetDocIds(
        memberIdByDocId: docs,
        deletedMemberIds: {'gone'},
        blockedDocIds: blocked,
      );
      expect(targets, isEmpty);
    });
  });

  test(
    'Home blocks failed cleanup docs and never runs cleanup twice at once',
    () {
      final source = File('lib/pages/home_page.dart').readAsStringSync();
      expect(source, contains('_deletedMemberCleanupBlockedDocIds.addAll'));
      expect(source, contains('if (_deletedMemberCleanupRunning) return;'));
    },
  );

  test('Personal lookup is owner-scoped without document ID whereIn', () {
    final source =
        File(
          'lib/services/home_deleted_member_schedule_service.dart',
        ).readAsStringSync();

    expect(source, contains("where('trainerId', isEqualTo: ownerUid)"));
    expect(source, contains("where('workspaceType', isEqualTo: 'personal')"));
    expect(source, isNot(contains('FieldPath.documentId')));
    expect(source, isNot(contains('SharedPreferences')));
    expect(
      source.indexOf('if (memberIds.isEmpty) return <String>{};'),
      lessThan(source.indexOf('final snapshot =')),
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

    final source =
        File(
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

  test('횟수 새로고침은 await 중 삭제된 레슨을 옛 복사본으로 되살리지 않는다', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();
    final start = source.indexOf(
      'Future<void> _refreshScheduleCountsFromMembers()',
    );
    final end = source.indexOf('String _buildTodayLessonCountText');

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final body = source.substring(start, end);
    final guard = body.indexOf('upsert.removeWhere(');
    final patch = body.indexOf('_patchScheduleData(upsert: upsert');

    expect(guard, greaterThanOrEqualTo(0));
    expect(patch, greaterThan(guard));
    expect(body.substring(guard, patch), contains('scheduleData[key]'));
  });

  test('삭제 표시를 지울 때 uid 접두사가 붙은 실제 문서 ID도 함께 지운다', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();
    final start = source.indexOf('void _clearRecentlyDeletedScheduleDocId');
    final end = source.indexOf('void _beginScheduleMutation');

    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    expect(
      source.substring(start, end),
      contains('homeScheduleScopedDocumentId('),
    );
  });
}
