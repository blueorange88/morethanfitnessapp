/// 레슨계약서 v2 입력 규칙의 앱 쪽 구현. 서버
/// (`functions/src/personal_contract_rules.ts`)와 같은 상한·문구 가드·환불 계산을 써서
/// 서버가 거부할 입력을 저장 전에 미리 알려 준다. 서버가 항상 최종 검증을 한다.
library;

import '../../models/lesson_contract/lesson_contract_settings.dart';

// ---- 금지·경고 문구 가드 (명세서 §12) ----
// 공백·구두점을 제거한 문자열에서 찾는다. 자유 입력 칸에만 적용한다.
final List<({String code, RegExp pattern})> _forbiddenPhrases = [
  (code: 'refund_denied', pattern: RegExp(r'환불(은|이)?(불가|안됩|안돼|안됨|금지|없)')),
  (code: 'refund_denied', pattern: RegExp(r'환불(을)?(하지않|해드리지않|불가)')),
  (code: 'refund_short_window', pattern: RegExp(r'환불(신청)?(은)?\d+일(이내|내|까지)')),
  (code: 'simple_change_of_mind', pattern: RegExp('단순변심')),
  (code: 'card_fee_deduction', pattern: RegExp('카드수수료')),
  (code: 'fee_deduction', pattern: RegExp(r'수수료(를)?공제')),
  (code: 'jurisdiction_fixed', pattern: RegExp('(재판관할|관할법원|관할로한다)')),
  (code: 'blanket_disclaimer', pattern: RegExp('(모든|어떠한|일체의?)(사고|상해|손실|책임)')),
  (code: 'blanket_disclaimer', pattern: RegExp('책임(을|은)?(지지않|없)')),
  (code: 'oral_agreement_void', pattern: RegExp('(구두|서면)약정(은|이)?(효력|무효)')),
];

final RegExp _squashPattern = RegExp(r'''[\s.,·:;!?'"()\[\]-]+''');

/// 금지 문구 코드. 문제가 없으면 null.
String? findForbiddenPhrase(String input) {
  final squashed = input.replaceAll(_squashPattern, '');
  for (final rule in _forbiddenPhrases) {
    if (rule.pattern.hasMatch(squashed)) return rule.code;
  }
  return null;
}

/// 금지 문구 코드를 사용자 문구로 바꾼다.
String forbiddenPhraseMessage(String code) {
  switch (code) {
    case 'refund_denied':
    case 'refund_short_window':
    case 'simple_change_of_mind':
      return '환불을 막거나 제한하는 문구는 쓸 수 없어요.';
    case 'card_fee_deduction':
    case 'fee_deduction':
      return '카드수수료 등 수수료 공제 문구는 쓸 수 없어요.';
    case 'jurisdiction_fixed':
      return '재판관할을 정하는 문구는 쓸 수 없어요.';
    case 'blanket_disclaimer':
      return '책임을 모두 면제하는 문구는 쓸 수 없어요.';
    case 'oral_agreement_void':
      return '약정의 효력을 부정하는 문구는 쓸 수 없어요.';
  }
  return '쓸 수 없는 문구가 들어 있어요.';
}

/// 지각 기준 문장. 가능성을 흐리는 표현 없이 진행 불가로 못박아 쓴다.
String lateLimitSentence(int minutes) => '레슨 시작시간 $minutes분 이후는 레슨 진행이 불가합니다.';

// ---- 환불 계산 (명세서 §6) ----
enum RefundKind { beforeFirstLesson, memberReason, providerFault, unavoidable }

class RefundResult {
  const RefundResult({
    required this.unitPrice,
    required this.consumed,
    required this.penalty,
    required this.refund,
  });

  final int unitPrice;
  final int consumed;
  final int penalty;
  final int refund;
}

int contractUnitPrice(int amount, int sessionCount) =>
    (amount / sessionCount).round();

/// 서버의 `computeRefund`와 같은 계산. 소진분 + 위약금이 결제금액을 넘으면 환불 0이고
/// 추가 청구는 없다.
RefundResult computeRefund({
  required RefundKind kind,
  required int paidAmount,
  required int sessionCount,
  required int usedSessions,
  required int? listPrice,
  required bool listPriceBasis,
  required int penaltyPercent,
}) {
  if (sessionCount < 1 ||
      usedSessions < 0 ||
      usedSessions > sessionCount ||
      penaltyPercent < 0 ||
      penaltyPercent > kContractMaxPenaltyPercent) {
    throw ArgumentError('refund_input_invalid');
  }
  final contractUnit = contractUnitPrice(paidAmount, sessionCount);
  final basisAmount =
      listPriceBasis && listPrice != null ? listPrice : paidAmount;
  final consumedUnit = contractUnitPrice(basisAmount, sessionCount);
  final penalty = paidAmount * penaltyPercent ~/ 100;

  switch (kind) {
    case RefundKind.providerFault:
      final remaining = sessionCount - usedSessions;
      final refund =
          remaining * contractUnit > paidAmount
              ? paidAmount
              : remaining * contractUnit;
      return RefundResult(
        unitPrice: contractUnit,
        consumed: paidAmount - refund,
        penalty: 0,
        refund: refund,
      );
    case RefundKind.beforeFirstLesson:
      return RefundResult(
        unitPrice: contractUnit,
        consumed: 0,
        penalty: penalty,
        refund: paidAmount - penalty < 0 ? 0 : paidAmount - penalty,
      );
    case RefundKind.memberReason:
    case RefundKind.unavoidable:
      final consumed = usedSessions * consumedUnit;
      final applied = kind == RefundKind.unavoidable ? 0 : penalty;
      final raw = paidAmount - consumed - applied;
      return RefundResult(
        unitPrice: consumedUnit,
        consumed: consumed,
        penalty: applied,
        refund: raw < 0 ? 0 : raw,
      );
  }
}

/// 서명 전 화면과 PDF에 보여 주는 환불 계산 예시에서 쓸 소진 횟수.
/// 총 횟수의 약 30%(최소 1회, 최대 총 횟수 − 1). 1회권은 소진 예시를 만들지 않는다(0).
int refundExampleUsedSessions(int sessionCount) {
  if (sessionCount < 2) return 0;
  final used = (sessionCount * 0.3).round();
  return used.clamp(1, sessionCount - 1);
}

/// 정상가 대비 할인율 표기(`33.3%`, 정수면 `33%`). 할인이 아니면 빈 문자열.
String discountRateLabel(int paidAmount, int listPrice) {
  if (listPrice <= 0 || paidAmount < 0 || paidAmount >= listPrice) return '';
  final rate = (listPrice - paidAmount) * 100 / listPrice;
  final rounded = (rate * 10).round() / 10;
  return rounded == rounded.roundToDouble()
      ? '${rounded.round()}%'
      : '${rounded.toStringAsFixed(1)}%';
}

/// 쉼표·공백을 지운 숫자. 비었거나 숫자가 아니면 null.
int? parseWon(String text) {
  final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.isEmpty ? null : int.tryParse(digits);
}

/// `1,000,000` 형식.
String formatWon(int value) {
  final negative = value < 0;
  final digits = value.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer';
}
