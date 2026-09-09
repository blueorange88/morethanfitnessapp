import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/member.dart';
import 'package:mtf_app/models/personal_member_taxonomy.dart';
import 'package:mtf_app/pages/personal_member_taxonomy_management_page.dart';
import 'package:mtf_app/services/app_tier_access_service.dart';

void main() {
  group('Personal taxonomy normalization', () {
    test('앞뒤와 연속 공백을 정리하고 대소문자 중복키를 만든다', () {
      expect(
        normalizePersonalTaxonomyDisplayName('  오전   회원  '),
        '오전 회원',
      );
      expect(personalTaxonomyComparisonKey(' VIP '), 'vip');
      expect(personalTaxonomyComparisonKey('vip'), 'vip');
    });

    test('이름은 2~30자만 허용한다', () {
      expect(validatePersonalTaxonomyName('A'), isNotNull);
      expect(validatePersonalTaxonomyName('VIP'), isNull);
      expect(validatePersonalTaxonomyName('가' * 31), isNotNull);
    });

    test('태그 ID는 trim, 중복 제거, 정렬한다', () {
      expect(
        normalizePersonalTagIds([' pt_b ', 'pt_a', 'pt_b', '']),
        ['pt_a', 'pt_b'],
      );
      expect(
        () => normalizePersonalTagIds(
          List<String>.generate(21, (index) => 'pt_$index'),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Personal member assignment contract', () {
    test('Amateur 신규 회원의 기본 그룹은 보내고 빈 태그 변경은 생략한다', () {
      final patch = PersonalMemberAssignmentPatch.forCreate();
      expect(
        patch.toCallableMap(),
        {'personalGroupId': null},
      );
      expect(patch.matchesMember(const <String, dynamic>{}), isTrue);
    });

    test('신규 회원이 실제 태그를 선택하면 정규화된 태그 배열을 보낸다', () {
      final patch = PersonalMemberAssignmentPatch.forCreate(
        personalTagIds: const [' pt_vip ', 'pt_diet', 'pt_vip'],
      );

      expect(
        patch.toCallableMap(),
        {
          'personalGroupId': null,
          'personalTagIds': <String>['pt_diet', 'pt_vip'],
        },
      );
    });

    test('그룹 하나와 복수 태그를 canonical field로만 저장한다', () {
      const patch = PersonalMemberAssignmentPatch(
        groupProvided: true,
        personalGroupId: 'pg_owner_group',
        tagsProvided: true,
        personalTagIds: ['pt_vip', 'pt_diet'],
      );
      expect(
        patch.toCallableMap(),
        {
          'personalGroupId': 'pg_owner_group',
          'personalTagIds': ['pt_diet', 'pt_vip'],
        },
      );
      expect(
        patch.matchesMember({
          'personalGroupId': 'pg_owner_group',
          'personalTagIds': ['pt_vip', 'pt_diet'],
        }),
        isTrue,
      );
      expect(patch.toCallableMap(), isNot(contains('groupId')));
      expect(patch.toCallableMap(), isNot(contains('groupName')));
    });

    test('Member model은 canonical과 legacy group field를 분리한다', () {
      final member = Member.fromFirestore('member-1', {
        'name': '회원',
        'memberStatus': '활성',
        'groupId': 'legacy-group',
        'personalGroupId': 'pg_owner_group',
        'personalTagIds': ['pt_vip', 'pt_vip', 'pt_diet'],
      });
      expect(member.groupId, 'legacy-group');
      expect(member.personalGroupId, 'pg_owner_group');
      expect(member.personalTagIds, ['pt_vip', 'pt_diet']);
    });
  });

  group('Personal taxonomy Phase 2 UI contract', () {
    final createdAt = DateTime.utc(2026, 8, 12);
    final groups = [
      PersonalMemberTaxonomyItem(
        id: 'group-a',
        kind: PersonalMemberTaxonomyKind.group,
        name: '오전 회원',
        normalizedName: '오전 회원',
        schemaVersion: 1,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
      PersonalMemberTaxonomyItem(
        id: 'group-b',
        kind: PersonalMemberTaxonomyKind.group,
        name: '저녁 회원',
        normalizedName: '저녁 회원',
        schemaVersion: 1,
        createdAt: createdAt,
        updatedAt: createdAt,
      ),
    ];

    test('stale group은 기본 그룹으로 안전하게 fallback한다', () {
      expect(
        resolvePersonalMemberGroupId(
          personalGroupId: 'deleted-group',
          availableGroupIds: {'group-a', 'group-b'},
        ),
        isNull,
      );
    });

    test('그룹과 태그 필터는 AND로 결정된다', () {
      expect(
        matchesPersonalMemberTaxonomyFilters(
          personalGroupId: 'group-a',
          personalTagIds: const ['tag-vip', 'tag-diet'],
          availableGroupIds: const {'group-a'},
          selectedGroupId: 'group-a',
          selectedTagId: 'tag-vip',
        ),
        isTrue,
      );
      expect(
        matchesPersonalMemberTaxonomyFilters(
          personalGroupId: 'group-a',
          personalTagIds: const ['tag-diet'],
          availableGroupIds: const {'group-a'},
          selectedGroupId: 'group-a',
          selectedTagId: 'tag-vip',
        ),
        isFalse,
      );
    });

    test('owner snapshot에서 그룹 회원 수를 local 계산한다', () {
      final counts = personalTaxonomyUsageCounts(
        kind: PersonalMemberTaxonomyKind.group,
        items: groups,
        members: const [
          {'personalGroupId': 'group-a'},
          {'personalGroupId': 'group-a'},
          {'personalGroupId': 'deleted-group'},
          <String, dynamic>{},
        ],
      );
      expect(counts.byId['group-a'], 2);
      expect(counts.byId['group-b'], 0);
      expect(counts.defaultGroupCount, 2);
    });

    test('그룹은 Amateur, 태그는 Semi-Pro gate를 사용한다', () {
      expect(
        AppTierAccessService.requiredRankForFeature(
          AppTierFeatureKey.personalGroup,
        ),
        1,
      );
      expect(
        AppTierAccessService.requiredRankForFeature(
          AppTierFeatureKey.personalTag,
        ),
        2,
      );
    });

    test('Phase 2 UI는 canonical service만 사용한다', () {
      final listSource =
          File('lib/pages/client_list_page.dart').readAsStringSync();
      final filterStripSource = File(
        'lib/widgets/personal_taxonomy_filter_strip.dart',
      ).readAsStringSync();
      final cardSource =
          File('lib/pages/client_card_page.dart').readAsStringSync();
      final managementSource = File(
        'lib/pages/personal_member_taxonomy_management_page.dart',
      ).readAsStringSync();
      expect(listSource, contains('PersonalMemberTaxonomyService'));
      expect(cardSource, contains('PersonalMemberAssignmentPatch.forCreate'));
      expect(cardSource, contains('clientCardPersonalTagsChanged('));
      expect(cardSource, contains('loadedTagIds: _loadedPersonalTagIds'));
      expect(
        listSource,
        contains('AifcPersonalTagManagementChatSheet.show'),
      );
      expect(
        cardSource,
        contains('AifcPersonalTagManagementChatSheet.show'),
      );
      expect(listSource, contains('PersonalTaxonomyFilterStrip'));
      expect(
        filterStripSource,
        contains("semanticLabel: '분류 관리'"),
      );
      expect(cardSource, contains('client_card_selected_tag_scroll'));
      expect(managementSource, isNot(contains('.set(')));
      expect(managementSource, isNot(contains('.update(')));
      expect(managementSource, isNot(contains('member_groups')));
    });

    test('태그 관리는 page push가 아닌 deterministic AIFC sheet를 사용한다', () {
      final source = File(
        'lib/widgets/aifc_personal_tag_management_chat_sheet.dart',
      ).readAsStringSync();
      expect(source, contains('AifcSheetFrame'));
      expect(source, contains('AifcChatBubble'));
      expect(source, contains('PersonalMemberTaxonomyService'));
      expect(source, contains('PersonalTagHorizontalStrip'));
      expect(source, contains('_service.create('));
      expect(source, contains('_service.rename('));
      expect(source, contains('_service.delete('));
      expect(source, isNot(contains('Navigator.of(context).push')));
      expect(source, isNot(contains('member_groups')));
    });
  });

  test('taxonomy document는 canonical schema를 검증한다', () {
    final source = File(
      'lib/models/personal_member_taxonomy.dart',
    ).readAsStringSync();
    expect(source, contains("data['schemaVersion'] != 1"));
    expect(source, contains("createdAt is! Timestamp"));
    expect(source, contains("updatedAt is! Timestamp"));
  });

  test('taxonomy service는 callable과 server readback만 사용한다', () {
    final source = File(
      'lib/services/personal_member_taxonomy_service.dart',
    ).readAsStringSync();
    for (final callable in <String>[
      'createPersonalGroup',
      'renamePersonalGroup',
      'deletePersonalGroup',
      'createPersonalTag',
      'renamePersonalTag',
      'deletePersonalTag',
      'updateManagedMember',
    ]) {
      expect(source, contains(callable));
    }
    expect(source, contains('GetOptions(source: Source.server)'));
    expect(source, isNot(contains('.set(')));
    expect(source, isNot(contains('.update(')));
    expect(source, isNot(contains('.delete(')));
  });

  test('save service는 assignment payload와 readback 검증을 연결한다', () {
    final source = File(
      'lib/services/personal_member_card_save_service.dart',
    ).readAsStringSync();
    expect(source, contains('...assignments.toCallableMap(),'));
    expect(source, contains('assignments.matchesMember(member)'));
  });

  test('Timestamp 타입은 taxonomy model의 canonical 시간 계약이다', () {
    final timestamp = Timestamp.fromDate(DateTime.utc(2026, 8, 11));
    expect(timestamp.toDate().toUtc(), DateTime.utc(2026, 8, 11));
  });
}
