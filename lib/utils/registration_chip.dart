import 'dart:ui' show Color;

/// 잔여 횟수가 이 값 이하면(1 이상) 적다고 보고 강조한다(회원 목록·헤더 알림과 같은 기준).
const int kLowRemainingSessions = 5;

/// 최근 계약으로 더해진 횟수(추가 재등록)를 보여 주는 기간(일).
const int kRecentRegistrationDays = 30;

/// 회원의 레슨 등록 현황(회원 문서의 횟수와 마지막 등록 기록).
class MemberRegistrationInfo {
  const MemberRegistrationInfo({
    required this.total,
    required this.remain,
    required this.notRegistered,
    this.added = 0,
    this.addedAt,
  });

  final int total;
  final int remain;

  /// 회원카드에 레슨이 등록되지 않았다(횟수 없음 포함).
  final bool notRegistered;

  /// 마지막 계약으로 더해진 횟수와 시각(서버 `lastRegistration`).
  final int added;
  final DateTime? addedAt;

  /// 회원 문서(`members/{id}`)에서 읽는다. 횟수는 홈 레슨 확정이 읽는 순서와 같다.
  factory MemberRegistrationInfo.fromMemberData(Map<String, dynamic> data) {
    int number(Object? value) =>
        value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;
    final sessions =
        data['sessions'] is Map
            ? Map<String, dynamic>.from(data['sessions'] as Map)
            : <String, dynamic>{};
    final total = number(
      data['totalSessions'] ?? sessions['total'] ?? data['sessionTotal'],
    );
    final remain = number(
      data['remainSessions'] ??
          data['remainingSessions'] ??
          sessions['remain'] ??
          data['remainingPt'] ??
          data['ptRemaining'],
    );
    final last =
        data['lastRegistration'] is Map
            ? Map<String, dynamic>.from(data['lastRegistration'] as Map)
            : <String, dynamic>{};
    final at = last['at'];
    final notRegistered =
        sessions['notRegistered'] == true ||
        data['lessonsNotRegistered'] == true ||
        total <= 0;
    return MemberRegistrationInfo(
      total: total,
      remain: remain,
      notRegistered: notRegistered,
      added: number(last['added']),
      // Timestamp는 `toDate()`를 가진 객체라 의존성 없이 동적으로 읽는다.
      addedAt: at is DateTime ? at : _toDate(at),
    );
  }

  static DateTime? _toDate(Object? value) {
    if (value == null) return null;
    try {
      final date = (value as dynamic).toDate();
      return date is DateTime ? date : null;
    } catch (_) {
      return null;
    }
  }
}

/// 레슨 등록 칩의 글자와 강조 색(없으면 기본 색).
class RegistrationChipStyle {
  const RegistrationChipStyle(this.label, this.compactLabel, this.color);

  /// 회원카드용(칸이 넓다): `총 20회 · 잔여 20회 · 추가재등록 10회`.
  final String label;

  /// 홈 레슨 시트용(좁다): `총 20 / 잔여 20 (+10)`.
  final String compactLabel;
  final Color? color;
}

/// 레슨 등록 현황을 칩 글자로 만든다.
/// - 최근([kRecentRegistrationDays]일) 계약으로 더해진 횟수가 있으면 `추가재등록 X회`/`(+X)`를 붙인다.
/// - 잔여가 1~[kLowRemainingSessions]이면 주황, 등록된 횟수를 모두 쓰면 `소진`을 빨강으로 보여 준다.
/// - 레슨이 등록되지 않았으면 `미등록`(강조 없음).
RegistrationChipStyle registrationChipStyle({
  required int total,
  required int remain,
  required bool notRegistered,
  int added = 0,
  DateTime? addedAt,
  DateTime? now,
}) {
  if (notRegistered) {
    return const RegistrationChipStyle('미등록', '미등록', null);
  }
  final today = now ?? DateTime.now();
  final recent =
      added > 0 &&
      addedAt != null &&
      today.difference(addedAt).inDays <= kRecentRegistrationDays;
  final longPlus = recent ? ' · 추가재등록 $added회' : '';
  final shortPlus = recent ? ' (+$added)' : '';
  if (total > 0 && remain <= 0) {
    return RegistrationChipStyle(
      '총 $total회 · 잔여 0회 · 소진$longPlus',
      '총 $total / 잔여 0 · 소진$shortPlus',
      const Color(0xFFDC2626),
    );
  }
  final low = remain > 0 && remain <= kLowRemainingSessions;
  return RegistrationChipStyle(
    '총 $total회 · 잔여 $remain회$longPlus',
    '총 $total / 잔여 $remain$shortPlus',
    low ? const Color(0xFFEA580C) : null,
  );
}

/// [MemberRegistrationInfo]로 칩 글자를 만든다.
RegistrationChipStyle registrationChipStyleFor(
  MemberRegistrationInfo info, {
  DateTime? now,
}) => registrationChipStyle(
  total: info.total,
  remain: info.remain,
  notRegistered: info.notRegistered,
  added: info.added,
  addedAt: info.addedAt,
  now: now,
);
