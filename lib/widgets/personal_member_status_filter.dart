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
  final matchesStatus = matchesPersonalMemberStatusFilter(
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
