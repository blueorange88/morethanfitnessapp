import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/member.dart';
import 'package:mtf_app/widgets/personal_member_status_filter.dart';

void main() {
  test('canonical managementState를 기존 회원 상태 표시값으로 변환한다', () {
    expect(
      personalMemberStatusFromCanonical({'managementState': 'active'}),
      '활성',
    );
    expect(
      personalMemberStatusFromCanonical({'managementState': 'dormant'}),
      '휴면',
    );
    expect(
      personalMemberStatusFromCanonical({'managementState': 'paused'}),
      '휴면',
    );
    expect(
      personalMemberStatusFromCanonical({'managementState': 'expired'}),
      '만료',
    );
    expect(personalMemberStatusFromCanonical({'memberStatus': '휴면'}), '휴면');
  });

  test('기존 memberStatus 기준으로 전체·휴면·만료를 판정한다', () {
    expect(
      matchesPersonalMemberStatusFilter(
        memberStatus: '활성',
        filter: PersonalMemberStatusFilter.all,
      ),
      isTrue,
    );
    expect(
      matchesPersonalMemberStatusFilter(
        memberStatus: '휴면',
        filter: PersonalMemberStatusFilter.dormant,
      ),
      isTrue,
    );
    expect(
      matchesPersonalMemberStatusFilter(
        memberStatus: '만료',
        filter: PersonalMemberStatusFilter.expired,
      ),
      isTrue,
    );
    expect(
      matchesPersonalMemberStatusFilter(
        memberStatus: '활성',
        filter: PersonalMemberStatusFilter.expired,
      ),
      isFalse,
    );
  });

  test('그룹·태그를 고르면 활성 회원만, 전체에서는 휴면·만료도 보인다', () {
    bool matches(
      String status, {
      String? group,
      String? tag,
      PersonalMemberStatusFilter filter = PersonalMemberStatusFilter.all,
    }) {
      return matchesPersonalMemberListClassification(
        memberStatus: status,
        memberGroupId: 'group-gym',
        memberTagIds: const ['tag-vip'],
        statusFilter: filter,
        selectedGroupId: group,
        defaultGroupId: '__ungrouped__',
        selectedTagId: tag,
      );
    }

    expect(matches('활성', group: 'group-gym'), isTrue);
    expect(matches('만료', group: 'group-gym'), isFalse);
    expect(matches('휴면', group: 'group-gym'), isFalse);
    expect(matches('만료', tag: 'tag-vip'), isFalse);
    expect(matches('만료'), isTrue);
    expect(matches('휴면'), isTrue);
    expect(matches('만료', filter: PersonalMemberStatusFilter.expired), isTrue);
  });

  test('휴면·만료 칩은 그룹·태그 선택을 풀고 그룹·태그 칩은 상태를 푼다', () {
    final source = File('lib/pages/client_list_page.dart').readAsStringSync();
    final start = source.indexOf('void _selectPersonalStatusExclusively(');
    final end = source.indexOf('Future<bool> _guardPersonalTaxonomyFeature(');
    final helper = source.substring(start, end);
    expect(helper, contains('_selectedPersonalTagIdNotifier.value = null'));
    expect(helper, contains('_setSelectedGroupId(null)'));
    expect(helper, contains('_setSelectedPersonalStatusFilter(status)'));

    final handlerStart = source.indexOf(
      'Future<void> _handlePersonalTaxonomyFilterEntry(',
    );
    final handler = source.substring(handlerStart, start);
    expect(
      handler,
      contains(
        '_selectPersonalStatusExclusively(PersonalMemberStatusFilter.dormant)',
      ),
    );
    expect(
      handler,
      contains(
        '_selectPersonalStatusExclusively(PersonalMemberStatusFilter.expired)',
      ),
    );
    expect(
      handler.substring(handler.indexOf('_handleGroupFilter(entry.id)')),
      contains(
        '_setSelectedPersonalStatusFilter(PersonalMemberStatusFilter.all)',
      ),
    );
  });

  test('휴면·만료는 회원 블럭 그룹 메뉴에서 상태 전환으로 옮긴다', () {
    final source = File('lib/pages/client_list_page.dart').readAsStringSync();
    final start = source.indexOf('Future<void> _handleMemberQuickGroupChange(');
    final end = source.indexOf('void _handleGroupFilter(', start);
    final handler = source.substring(start, end);
    expect(handler, contains("_updateMemberStatus(member, '휴면')"));
    expect(handler, contains("_updateMemberStatus(member, '만료')"));
    expect(handler, contains("nextState: 'active'"));
    final menuStart = source.indexOf(
      'List<_MemberCardGroupMenuItem> _buildMemberCardGroupMenuItems()',
    );
    final menu = source.substring(
      menuStart,
      source.indexOf('Future<void> _handleMemberQuickGroupChange(', menuStart),
    );
    expect(menu, isNot(contains('_isPersonalWorkspace')));
    expect(menu, contains('_systemDormantGroupId'));
    expect(menu, contains('_systemExpiredGroupId'));
  });

  test('상태·그룹·태그는 AND로 결합된다(상태 칩 선택 중)', () {
    expect(
      matchesPersonalMemberListClassification(
        memberStatus: '만료',
        memberGroupId: 'group-gym',
        memberTagIds: const ['tag-vip', 'tag-pain'],
        statusFilter: PersonalMemberStatusFilter.expired,
        selectedGroupId: 'group-gym',
        defaultGroupId: '__ungrouped__',
        selectedTagId: 'tag-vip',
      ),
      isTrue,
    );
    expect(
      matchesPersonalMemberListClassification(
        memberStatus: '휴면',
        memberGroupId: 'group-gym',
        memberTagIds: const ['tag-vip'],
        statusFilter: PersonalMemberStatusFilter.expired,
        selectedGroupId: 'group-gym',
        defaultGroupId: '__ungrouped__',
        selectedTagId: 'tag-vip',
      ),
      isFalse,
    );
    expect(
      matchesPersonalMemberListClassification(
        memberStatus: '만료',
        memberGroupId: 'group-gym',
        memberTagIds: const ['tag-diet'],
        statusFilter: PersonalMemberStatusFilter.expired,
        selectedGroupId: 'group-gym',
        defaultGroupId: '__ungrouped__',
        selectedTagId: 'tag-vip',
      ),
      isFalse,
    );
  });

  test('canonical membership 종료일과 활동상태 필터 의미를 분리한다', () {
    final member = Member.fromFirestore('member-test', {
      'memberStatus': '활성',
      'membership': {'endAt': DateTime.now().subtract(const Duration(days: 1))},
    });
    expect(member.isExpired, isTrue);
    expect(
      matchesPersonalMemberStatusFilter(
        memberStatus: member.memberStatus,
        filter: PersonalMemberStatusFilter.expired,
      ),
      isFalse,
    );
  });

  test('상태 변경과 taxonomy는 별도 client write 계약이다', () {
    final source = File('lib/pages/client_list_page.dart').readAsStringSync();
    final saveService =
        File(
          'lib/services/personal_member_card_save_service.dart',
        ).readAsStringSync();
    expect(source, isNot(contains('PersonalMemberStatusFilterBar')));
    expect(source, contains('PersonalTaxonomyFilterRole.statusDormant'));
    expect(source, contains('PersonalTaxonomyFilterRole.statusExpired'));
    expect(source, contains('matchesPersonalMemberListClassification'));
    expect(source, contains('.transitionStateAndVerify('));
    expect(saveService, contains("'transitionManagedMemberState'"));
    expect(saveService, contains("member['managementState'] != nextState"));
    expect(source, contains("return member.memberStatus == '만료';"));
    expect(source, contains("return member.memberStatus == '휴면';"));
    expect(source, isNot(contains("visibleSystemGroups: {\n        if")));
  });

  test('통합 strip 전체는 분류 세 축만 초기화하고 검색어는 유지한다', () {
    final source = File('lib/pages/client_list_page.dart').readAsStringSync();
    final handlerStart = source.indexOf(
      'Future<void> _handlePersonalTaxonomyFilterEntry(',
    );
    final handlerEnd = source.indexOf(
      'Future<bool> _guardPersonalTaxonomyFeature(',
      handlerStart,
    );
    final handler = source.substring(handlerStart, handlerEnd);

    expect(handler, contains('_handleGroupFilter(_allGroupId)'));
    expect(handler, contains('_selectedPersonalTagIdNotifier.value = null'));
    expect(
      handler,
      contains(
        '_setSelectedPersonalStatusFilter(PersonalMemberStatusFilter.all)',
      ),
    );
    expect(handler, isNot(contains('_searchController.clear()')));
    expect(handler, isNot(contains("_searchKeywordNotifier.value = ''")));
  });

  test('그룹 관리 page는 공통 header·surface 토큰을 사용한다', () {
    final source =
        File(
          'lib/pages/personal_member_taxonomy_management_page.dart',
        ).readAsStringSync();
    expect(source, contains('context.mtfHeaderGradient'));
    expect(source, contains('personal_taxonomy_management_header'));
    expect(source, contains('SystemUiOverlayStyle.light'));
    expect(source, contains('foreground = AppColors.lightSurface'));
    expect(source, contains('height: 44'));
    // 뒤로가기는 공용 버튼(42×42)을 쓴다.
    expect(source, contains('MtfBackButton(onTap: onBackTap'));
    expect(source, contains('fontSize: 20'));
    expect(source, contains('bottom: Radius.circular(kMtfHeaderBottomRadius)'));
    expect(source, isNot(contains('appBar: AppBar(')));
    expect(source, contains('tokens.memberListBackground'));
    expect(source, contains('tokens.cardSurface'));
    expect(source, contains('tokens.cardBorder'));
    expect(source, contains('tokens.gradeSheetAccent'));
    expect(source, contains('minimumSize: const Size.fromHeight(48)'));
    expect(source, isNot(contains('Color(0x')));
  });

  test('태그 관리는 기존 AIFC sheet·bubble·dialog 컴포넌트를 유지한다', () {
    final source =
        File(
          'lib/widgets/aifc_personal_tag_management_chat_sheet.dart',
        ).readAsStringSync();
    expect(source, contains('AifcSheetFrame('));
    expect(source, contains('AifcChatBubble('));
    expect(source, contains('AifcChatSheet.show('));
    expect(source, contains('AifcConfirmChatSheet.show('));
    expect(source, contains('PersonalTagHorizontalStrip('));
    expect(source, isNot(contains('Color(0x')));
  });
}
