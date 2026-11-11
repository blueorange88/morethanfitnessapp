/// 레슨계약서 본문 문구와 미리보기용 문서 구성.
///
/// 입력 화면의 조항 문장(빈칸이 있는 문장)과 미리보기·PDF의 완성 문장이 같은 문구를 쓰도록
/// 문구 조각을 여기서 한 번만 정의한다. 문구는 법률 검토 전 초안이다.
library;

import '../../models/lesson_contract/lesson_contract_form.dart';
import '../../models/lesson_contract/lesson_contract_settings.dart';
import 'lesson_contract_rules.dart';

// ---- 조항 문구 조각 (입력 화면의 빈칸 앞뒤 문장) ----
const String kCancelHoursBefore = '회원은 레슨 시작 ';
const String kCancelHoursAfter =
    '시간 전까지 예약을 변경하거나 취소할 수 있습니다. 취소 가능 시간이 지난 후에 취소하는 경우에는 레슨 1회가 차감됩니다.';
const String kCancelSameDay =
    '회원은 당일 예약을 변경하거나 취소할 수 없으며, 당일에 취소하는 경우에는 레슨 1회가 차감됩니다.';
const String kLateBefore = '또한 레슨 시작시간 ';
const String kLateAfter = '분 이후는 레슨 진행이 불가하며, 이 경우 불참으로 보아 레슨 1회가 차감됩니다.';

const String kPenaltyBefore = '회원이 계약을 중도에 해지하는 경우 위약금은 총 결제금액의 ';
const String kPenaltyAfter =
    '%로 하되 $kContractMaxPenaltyPercent%를 초과하지 않으며, 환불금액은 결제금액에서 이미 받은 레슨의 값(이용분)과 위약금을 공제한 금액으로 합니다. 환급은 환불을 신청한 날부터 영업일 ';
const String kRefundDaysAfter = '일 이내에 처리합니다.';

const String kBasisContractUnit =
    '중도 해지할 때 이미 받은 레슨의 값(이용분)은 1회 금액 × 받은 횟수로 계산합니다. 1회 금액은 실제 낸 금액을 총 횟수로 나눈 금액입니다.';
const String kBasisListPrice =
    '중도 해지할 때 이미 받은 레슨의 값(이용분)은 1회 금액 × 받은 횟수로 계산합니다. 1회 금액은 할인 전 정상가를 총 횟수로 나눈 금액이며, 이용분과 위약금의 합계가 실제 낸 금액을 넘지 않습니다.';

const String kTransferBefore = '회원권의 양도는 ';
const String kTransferAllowedAfter = '로 하며, 양도 수수료는 ';
const String kTransferDeniedAfter = '로 하며 양도할 수 없습니다.';

const String kExtensionClause =
    '질병·부상 등 불가피한 사유로 장기간 레슨을 받기 어려운 경우에는 유효기간의 연장을 협의합니다.';
const String kUnavoidableRefundClause =
    '질병·부상으로 계약을 해지하는 경우에는 진단서 등으로 확인한 뒤 위약금을 면제하고 이용분만 공제합니다.';

const String kTrainerCancelText =
    '강사의 사정으로 레슨이 취소되거나 지연되는 경우에는 레슨을 차감하지 않고 사용 가능 기간 안에 보강합니다.';
const String kNoWaiverText =
    '강사가 사정에 따라 특정 레슨을 차감하지 않더라도 이후 레슨에는 같은 규정이 적용됩니다.';
const String kRefundMethodText =
    '환불은 결제 수단과 같은 방식으로 하며, 카드로 결제한 경우에는 가능한 범위에서 카드 결제를 취소합니다. 카드수수료는 공제하지 않습니다.';
const String kTrainerFaultRefundText =
    '강사의 귀책 사유로 레슨을 계속 받을 수 없는 경우에는 위약금 없이 남은 횟수에 회당 금액을 곱한 금액을 환불합니다.';
const String kExpiryText = '유효기간 종료일이 지나면 남은 횟수는 소멸합니다.';
const String kNoExpiryText = '유효기간 종료일을 정하지 않아, 기간이 지났다는 이유로 남은 횟수가 소멸하지 않습니다.';

/// 건강 상태 확인과 위험 고지(핵심 고지 ⑤).
const List<String> kHealthRiskParagraphs = [
  '회원은 현재 운동을 할 수 있는 신체적·정신적 상태이며, 개인 트레이닝을 받을 수 없는 의학적 사유가 없음을 확인합니다.',
  '강사는 의학적 조언을 하지 않습니다. 건강상 우려가 있는 경우 회원은 레슨 전에 전문의와 상담하고 강사에게 알립니다.',
  '회원의 신체 능력과 건강 상태에 따라 레슨의 난이도와 내용이 제한될 수 있습니다.',
  '회원은 운동 중 부상의 위험이 있음을 알고 있으며, 통증·어지러움 등 이상 증상이 있으면 즉시 강사에게 알립니다. 강사는 안전 수칙을 지키며, 강사에게 귀책 사유가 있는 범위에서는 책임을 집니다.',
  '회원의 고의 또는 과실로 타인에게 손해가 생긴 경우에는 그 범위에서 회원이 책임을 집니다.',
];

const String kPrivacyText =
    '강사는 계약의 체결과 이행, 레슨 안내를 위하여 회원의 이름, 연락처, 생년월일을 수집하여 이용하며 계약 종료 후 3년간 보관합니다.';

// ---- 토스트 안내 ----
/// 환급 영업일 칸을 누르면 띄우는 안내(환불불가 문구를 넣을 수 없는 근거).
/// 조문 번호는 2026-10-17에 원문 요약으로 확인한 것만 적는다(최종 확인은 전문가).
const String kRefundLegalNotice =
    '환불불가 문구는 계약서에 넣을 수 없습니다. '
    '약관의 규제에 관한 법률 제9조 제1호에 따라 고객의 해지권을 제한하는 약관 조항은 무효이며, '
    '위약금은 공정거래위원회 고시 제2019-9호 제4조 제1항의 상한을, '
    '환급액은 같은 고시 제5조 제1항의 산정 방식을 따릅니다.';

String _text(String value) => value.trim().isEmpty ? '' : value.trim();

String _dash(String value) => value.trim().isEmpty ? '-' : value.trim();

String _paymentMethodLabel(String wire) {
  for (final (key, label) in kContractPaymentMethods) {
    if (key == wire) return label;
  }
  return '';
}

/// 표(항목: 값)와 문단으로 이루어진 한 조항.
class ContractDocArticle {
  const ContractDocArticle({
    required this.heading,
    this.rows = const [],
    this.paragraphs = const [],
  });

  final String heading;
  final List<(String, String)> rows;
  final List<String> paragraphs;
}

/// 미리보기·PDF에 쓰는 문서 구성.
class ContractDocument {
  const ContractDocument({
    required this.title,
    required this.contractNo,
    required this.partyRows,
    required this.memberRows,
    required this.articles,
    required this.exampleLines,
    required this.signatureLabels,
  });

  final String title;
  final String contractNo;
  final List<(String, String)> partyRows;
  final List<(String, String)> memberRows;
  final List<ContractDocArticle> articles;
  final List<String> exampleLines;
  final List<String> signatureLabels;
}

/// 취소·지각 조항의 완성 문장(문단 하나).
String cancelClauseText(LessonContractForm form) {
  final deadline = form.cancelDeadline;
  final first =
      deadline.sameDay
          ? kCancelSameDay
          : '$kCancelHoursBefore${deadline.hours}$kCancelHoursAfter';
  final late = form.lateNoShowMinutes;
  if (late == null) return first;
  return '$first $kLateBefore$late$kLateAfter';
}

/// 위약금·환급 조항의 완성 문장.
String refundClauseText(LessonContractForm form) =>
    '$kPenaltyBefore${form.penaltyPercent}$kPenaltyAfter'
    '${form.refundBusinessDays}$kRefundDaysAfter';

String basisClauseText(LessonContractForm form) =>
    form.usesListPriceBasis ? kBasisListPrice : kBasisContractUnit;

String transferClauseText(LessonContractForm form) {
  if (form.transferPolicy == ContractTransferPolicy.denied) {
    return '$kTransferBefore${form.transferPolicy.label}$kTransferDeniedAfter';
  }
  final fee = switch (form.transferFeeType) {
    ContractTransferFeeType.none => '없음',
    ContractTransferFeeType.amount => '${formatWon(form.transferFeeValue)}원',
    ContractTransferFeeType.percent => '${form.transferFeeValue}%',
  };
  return '$kTransferBefore${form.transferPolicy.label}$kTransferAllowedAfter$fee입니다.';
}

ContractDocument buildLessonContractDocument({
  required LessonContractForm form,
  required ContractParty party,
  String contractNo = '',
}) {
  final paid = form.paidAmount;
  final list = form.listPrice;
  final unit = form.unitPrice;
  final count = form.sessionCount;
  final vat = form.vatIncluded ? 'VAT 포함' : 'VAT 별도';

  final productRows = <(String, String)>[
    ('레슨명', _dash(form.productName)),
    ('총 횟수', count == null ? '-' : '$count회'),
    ('1회 수업 시간', form.sessionMinutes == null ? '-' : '${form.sessionMinutes}분'),
    ('회당 금액', unit == null ? '-' : '${formatWon(unit)}원'),
    ('실결제금액', paid == null ? '-' : '${formatWon(paid)}원 ($vat)'),
    if (paid != null && list != null && list > paid)
      ('정상가', '${formatWon(list)}원 (${discountRateLabel(paid, list)} 할인)'),
    if (_paymentMethodLabel(form.paymentMethod).isNotEmpty)
      ('결제 방법', _paymentMethodLabel(form.paymentMethod)),
    if (form.paymentDate.trim().isNotEmpty) ('결제일', form.paymentDate.trim()),
    if (form.remarks.trim().isNotEmpty) ('비고', form.remarks.trim()),
    ('사용 가능 기간', '${_dash(form.periodStart)} ~ ${form.periodEndLabel}'),
  ];

  final refundParagraphs = <String>[
    refundClauseText(form),
    kRefundMethodText,
    kTrainerFaultRefundText,
    if (form.unavoidableRefundClause) kUnavoidableRefundClause,
  ];

  final validityParagraphs = <String>[
    if (form.periodUnlimited) kNoExpiryText else kExpiryText,
    if (form.expiryExtensionClause && !form.periodUnlimited) kExtensionClause,
  ];

  final articles = <ContractDocArticle>[
    ContractDocArticle(heading: '계약의 내용', rows: productRows),
    ContractDocArticle(
      heading: '예약 변경 및 취소',
      paragraphs: [cancelClauseText(form), kNoWaiverText],
    ),
    const ContractDocArticle(
      heading: '강사 사정에 의한 취소',
      paragraphs: [kTrainerCancelText],
    ),
    ContractDocArticle(heading: '유효기간과 소멸', paragraphs: validityParagraphs),
    ContractDocArticle(heading: '위약금 및 환불', paragraphs: refundParagraphs),
    ContractDocArticle(
      heading: '이용분 계산 기준',
      paragraphs: [basisClauseText(form)],
    ),
    ContractDocArticle(
      heading: '양도',
      paragraphs: [
        transferClauseText(form),
        if (form.transferPolicy != ContractTransferPolicy.denied)
          '양도받은 회원도 이 계약에 따라 환불을 받을 수 있습니다.',
      ],
    ),
    const ContractDocArticle(
      heading: '강사 변경',
      paragraphs: [
        '강사를 변경하는 경우 남은 횟수는 그대로 유지합니다. 회원이 변경을 원하지 않으면 계약을 해지할 수 있으며, 이 경우 위약금 없이 남은 횟수에 해당하는 금액을 환불합니다.',
      ],
    ),
    const ContractDocArticle(
      heading: '건강 상태 확인과 안전',
      paragraphs: kHealthRiskParagraphs,
    ),
    const ContractDocArticle(
      heading: '개인정보의 수집 및 이용',
      paragraphs: [kPrivacyText],
    ),
    const ContractDocArticle(
      heading: '계약의 변경',
      paragraphs: ['계약 내용을 변경하는 경우에는 새 계약서를 작성하여 양 당사자가 다시 서명합니다.'],
    ),
    const ContractDocArticle(
      heading: '분쟁의 해결',
      paragraphs: [
        '이 계약에 관한 분쟁은 당사자 간 협의로 해결하며, 해결되지 않는 경우 한국소비자원(국번 없이 1372)에 상담을 요청할 수 있습니다.',
      ],
    ),
    if (form.extraTerms.trim().isNotEmpty)
      ContractDocArticle(heading: '특약', paragraphs: [form.extraTerms.trim()]),
  ];

  final exampleLines = <String>[];
  if (paid != null && count != null && paid >= 1 && count >= 1) {
    if (form.penaltyPercent >= 0 &&
        form.penaltyPercent <= kContractMaxPenaltyPercent) {
      final before = computeRefund(
        kind: RefundKind.beforeFirstLesson,
        paidAmount: paid,
        sessionCount: count,
        usedSessions: 0,
        listPrice: list,
        listPriceBasis: false,
        penaltyPercent: form.penaltyPercent,
      );
      exampleLines.add(
        '결제 ${formatWon(paid)}원, 총 $count회, 위약금 ${form.penaltyPercent}% 기준',
      );
      exampleLines.add(
        '첫 레슨 전에 해지: 위약금 ${formatWon(before.penalty)}원 공제, '
        '환불 ${formatWon(before.refund)}원',
      );
      final used = refundExampleUsedSessions(count);
      if (used > 0) {
        final byUnit = computeRefund(
          kind: RefundKind.memberReason,
          paidAmount: paid,
          sessionCount: count,
          usedSessions: used,
          listPrice: list,
          listPriceBasis: false,
          penaltyPercent: form.penaltyPercent,
        );
        final byList =
            form.usesListPriceBasis
                ? computeRefund(
                  kind: RefundKind.memberReason,
                  paidAmount: paid,
                  sessionCount: count,
                  usedSessions: used,
                  listPrice: list,
                  listPriceBasis: true,
                  penaltyPercent: form.penaltyPercent,
                )
                : null;
        final applied = byList ?? byUnit;
        exampleLines.add(
          '$used회 이용 후 해지: 이용분 ${formatWon(applied.consumed)}원과 위약금 '
          '${formatWon(applied.penalty)}원 공제, 환불 ${formatWon(applied.refund)}원',
        );
      }
    }
  }

  return ContractDocument(
    title: '레슨 계약서',
    contractNo: contractNo,
    partyRows: [
      ('상호(성명)', _dash(party.name)),
      ('구분', party.kind == ContractPartyKind.center ? '센터' : '강사 개인'),
      ('담당 강사', _dash(party.trainerName)),
      ('연락처', _dash(party.phone)),
      ('수업 장소', _dash(party.place)),
      if (_text(party.businessNo).isNotEmpty)
        ('사업자등록번호', party.businessNo.trim()),
    ],
    memberRows: [
      ('성명', _dash(form.memberName)),
      ('연락처', _dash(form.memberPhone)),
      if (_text(form.memberBirthDate).isNotEmpty)
        ('생년월일', form.memberBirthDate.trim()),
      if (_text(form.memberEmail).isNotEmpty) ('이메일', form.memberEmail.trim()),
    ],
    articles: articles,
    exampleLines: exampleLines,
    signatureLabels: const ['회원 서명 (핵심 고지 확인)', '회원 서명 (계약 전체 동의)', '강사 서명'],
  );
}

// ---- 회원 핵심 고지 ----
/// 회원이 서명 ① 전에 확인하는 핵심 고지 카드 한 장. 확인 항목 이름(id)은 서버
/// `requiredDisclosureItems`와 같아야 한다.
class ContractDisclosureCard {
  const ContractDisclosureCard({
    required this.id,
    required this.number,
    required this.title,
    required this.checkLabel,
    this.rows = const [],
    this.lines = const [],
    this.extraChecks = const [],
  });

  final String id;
  final String number;
  final String title;
  final String checkLabel;
  final List<(String, String)> rows;
  final List<String> lines;

  /// 이 카드에서 추가로 받는 확인 항목(id, 문구). 정상가 기준 계산에서 쓴다.
  final List<(String, String)> extraChecks;
}

const String kListPriceBasisCheckId = 'list_price_basis';

/// 서버에 보내는 고지 확인 항목 전체(카드 확인 + 추가 확인).
List<String> disclosureCheckIds(List<ContractDisclosureCard> cards) => [
  for (final card in cards) ...[
    card.id,
    for (final e in card.extraChecks) e.$1,
  ],
];

List<ContractDisclosureCard> buildDisclosureCards(
  LessonContractForm form,
  ContractParty party,
) {
  final document = buildLessonContractDocument(form: form, party: party);
  final content = document.articles.firstWhere((a) => a.heading == '계약의 내용');
  final amountRows = [
    for (final row in content.rows)
      if (const {
        '레슨명',
        '총 횟수',
        '1회 수업 시간',
        '회당 금액',
        '실결제금액',
        '정상가',
      }.contains(row.$1))
        row,
  ];
  final paid = form.paidAmount;
  final list = form.listPrice;
  final count = form.sessionCount;
  final listUnit =
      list != null && count != null && count > 0
          ? '${formatWon(contractUnitPrice(list, count))}원'
          : '';
  return [
    ContractDisclosureCard(
      id: 'amount',
      number: '①',
      title: '금액',
      rows: [
        ...amountRows,
        if (form.usesListPriceBasis && listUnit.isNotEmpty)
          ('정상가 기준 회당 금액', listUnit),
      ],
      checkLabel: '상품, 횟수와 금액을 확인했습니다.',
      extraChecks: [
        if (form.usesListPriceBasis)
          (
            kListPriceBasisCheckId,
            paid != null && list != null
                ? '정상가(${formatWon(list)}원)와 할인가(${formatWon(paid)}원), 회당 금액을 확인했으며 정상가 기준으로 이미 받은 레슨의 값(이용분)을 계산하는 것에 동의합니다.'
                : '정상가 기준으로 이미 받은 레슨의 값(이용분)을 계산하는 것을 확인했습니다.',
          ),
      ],
    ),
    ContractDisclosureCard(
      id: 'refund',
      number: '②',
      title: '환불 기준',
      lines: [
        refundClauseText(form),
        basisClauseText(form),
        kRefundMethodText,
        kTrainerFaultRefundText,
        if (form.unavoidableRefundClause) kUnavoidableRefundClause,
        ...document.exampleLines,
      ],
      checkLabel: '환불 기준과 계산 예시를 확인했습니다.',
    ),
    ContractDisclosureCard(
      id: 'validity',
      number: '③',
      title: '사용 가능 기간과 소멸',
      rows: [
        (
          '사용 가능 기간',
          '${form.periodStart.isEmpty ? '-' : form.periodStart} ~ ${form.periodEndLabel}',
        ),
      ],
      lines: [
        if (form.periodUnlimited) kNoExpiryText else kExpiryText,
        if (form.expiryExtensionClause && !form.periodUnlimited)
          kExtensionClause,
      ],
      checkLabel: '사용 가능 기간과 소멸 기준을 확인했습니다.',
    ),
    ContractDisclosureCard(
      id: 'cancel_noshow',
      number: '④',
      title: '예약 변경·취소와 레슨 진행',
      lines: [cancelClauseText(form), kNoWaiverText, kTrainerCancelText],
      checkLabel: '예약 변경·취소와 레슨 진행 기준을 확인했습니다.',
    ),
    const ContractDisclosureCard(
      id: 'health_risk',
      number: '⑤',
      title: '건강 상태 확인과 위험 고지',
      lines: kHealthRiskParagraphs,
      checkLabel: '건강 상태를 확인했고 위험 고지를 이해했습니다.',
    ),
  ];
}

/// 서명 ② 화면에서 보여 주는 나머지 조항(핵심 고지에 없는 조항).
const Set<String> kDisclosedHeadings = {
  '계약의 내용',
  '예약 변경 및 취소',
  '유효기간과 소멸',
  '위약금 및 환불',
  '이용분 계산 기준',
  '건강 상태 확인과 안전',
};

/// (문서 안 조항 번호, 조항) 목록. 번호는 전체 문서 기준이라 미리보기와 같다.
List<(int, ContractDocArticle)> remainingArticles(ContractDocument document) =>
    [
      for (var i = 0; i < document.articles.length; i++)
        if (!kDisclosedHeadings.contains(document.articles[i].heading))
          (i + 1, document.articles[i]),
    ];
