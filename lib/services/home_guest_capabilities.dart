class HomeGuestCapabilities {
  const HomeGuestCapabilities();

  bool get canCreateLocalSchedule => true;
  int get localScheduleLimit => 5;
  bool get canSaveMember => false;
  bool get canUseCloudSync => false;
  bool get canIssueContract => false;
  bool get canUseRemoteSignature => false;
  bool get canScheduleNotifications => false;
  bool get canSyncWidget => false;
  bool get canSearchRealMembers => false;
}
