enum PersonalMemberStatusFilter { all, dormant, expired }

String personalMemberStatusFilterLabel(PersonalMemberStatusFilter filter) {
  return switch (filter) {
    PersonalMemberStatusFilter.all => '전체 회원',
    PersonalMemberStatusFilter.dormant => '휴면',
    PersonalMemberStatusFilter.expired => '만료',
  };
}

bool matchesPersonalMemberStatusFilter({
  required String memberStatus,
  required PersonalMemberStatusFilter filter,
}) {
  return switch (filter) {
    PersonalMemberStatusFilter.all => true,
    PersonalMemberStatusFilter.dormant => memberStatus == '휴면',
    PersonalMemberStatusFilter.expired => memberStatus == '만료',
  };
}

bool matchesPersonalMemberListClassification({
  required String memberStatus,
  required String? memberGroupId,
  required Iterable<String> memberTagIds,
  required PersonalMemberStatusFilter statusFilter,
  required String? selectedGroupId,
  required String defaultGroupId,
  required String? selectedTagId,
}) {
  // 휴면·만료는 하나의 분류처럼 보인다: 그룹·태그를 고르면 활성 회원만 나오고,
  // 휴면·만료 회원은 해당 칩이나 전체에서 본다.
  final isGroupOrTagSelected = selectedGroupId != null || selectedTagId != null;
  final matchesStatus =
      statusFilter == PersonalMemberStatusFilter.all && isGroupOrTagSelected
          ? memberStatus != '휴면' && memberStatus != '만료'
          : matchesPersonalMemberStatusFilter(
            memberStatus: memberStatus,
            filter: statusFilter,
          );
  final matchesGroup = switch (selectedGroupId) {
    null => true,
    String id when id == defaultGroupId => memberGroupId == null,
    String id => memberGroupId == id,
  };
  final matchesTag =
      selectedTagId == null || memberTagIds.contains(selectedTagId);
  return matchesStatus && matchesGroup && matchesTag;
}
