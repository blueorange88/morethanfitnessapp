enum HomeQuickRegAction {
  fastSave,
  goDetail,
}

class HomeQuickRegResult {
  final HomeQuickRegAction action;
  final String name;
  final String phone;
  final DateTime visitDate;
  final DateTime? consultDate;

  const HomeQuickRegResult({
    required this.action,
    required this.name,
    required this.phone,
    required this.visitDate,
    required this.consultDate,
  });
}