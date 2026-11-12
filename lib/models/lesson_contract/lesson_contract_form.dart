/// 레슨계약서 v2 강사 입력 값. 서버(`personal_contract_rules.ts`)와 같은 상한으로
/// 검사하고, 서버가 받는 `content` 형식으로 바꾼다.
library;

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

import '../../utils/lesson_contract/lesson_contract_rules.dart';
import 'lesson_contract_settings.dart';

const int kContractMaxPeriodDays = 1095;
const int kContractMaxPaidAmount = 100000000;
const int kContractMaxListPrice = 1000000000;

enum ContractTransferFeeType {
  none('none'),
  amount('amount'),
  percent('percent');

  const ContractTransferFeeType(this.wire);
  final String wire;

  static ContractTransferFeeType parse(Object? value) {
    for (final type in values) {
      if (type.wire == value) return type;
    }
    return none;
  }
}

/// 비고 최대 글자 수(서버 `product.remarks` 상한과 같다).
const int kContractMaxRemarksLength = 100;

const List<(String, String)> kContractPaymentMethods = [
  ('card', '카드'),
  ('transfer', '계좌이체'),
  ('cash', '현금'),
  ('other', '기타'),
];

String _text(Object? value) => (value ?? '').toString().trim();

int? _intOrNull(Object? value) => value is num ? value.toInt() : null;

final RegExp _datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

/// `yyyy-MM-dd` 문자열이 실제 날짜인지 확인한다.
DateTime? parseContractDate(String value) {
  if (!_datePattern.hasMatch(value)) return null;
  final parsed = DateTime.tryParse('${value}T00:00:00Z');
  if (parsed == null) return null;
  final roundTrip = parsed.toIso8601String().substring(0, 10);
  return roundTrip == value ? parsed : null;
}

String formatContractDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// 고객카드의 생년월일을 계약서 형식(`YYYY-MM-DD`)으로 바꾼다. 읽을 수 없으면 빈 문자열.
/// 카드마다 저장 형식이 달라(문자열 `1990-05-17`·`1990.5.17`·`19900517`, 날짜 값) 모두 읽는다.
String contractBirthDateFromCard(Object? value, {DateTime? now}) {
  DateTime? date;
  if (value is Timestamp) {
    date = value.toDate();
  } else if (value is DateTime) {
    date = value;
  } else {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return '';
    final separated = RegExp(
      r'^(\d{4})[.\-/\s]+(\d{1,2})[.\-/\s]+(\d{1,2})\.?$',
    ).firstMatch(text);
    final compact = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(text);
    final match = separated ?? compact;
    if (match == null) return '';
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) return '';
  }
  final today = now ?? DateTime.now();
  if (date.year < 1900 || date.isAfter(today)) return '';
  return formatContractDate(DateTime(date.year, date.month, date.day));
}

/// 고객카드 문서에서 생년월일을 찾는다. 카드마다 `birthDate`·`birth`·`birthday` 중 하나로
/// 저장돼 있어 차례로 확인한다.
String contractBirthDateFromCardMap(Map<String, dynamic>? card) {
  if (card == null) return '';
  for (final key in const ['birthDate', 'birth', 'birthday']) {
    final value = contractBirthDateFromCard(card[key]);
    if (value.isNotEmpty) return value;
  }
  return '';
}

/// 강사가 입력하는 계약 내용(당사자 제외 — 당사자는 설정에서 가져온다).
class LessonContractForm {
  const LessonContractForm({
    this.memberId = '',
    this.memberName = '',
    this.memberPhone = '',
    this.memberBirthDate = '',
    this.memberEmail = '',
    this.productName = '',
    this.sessionCount,
    this.sessionMinutes = 50,
    this.paidAmount,
    this.vatIncluded = false,
    this.listPrice,
    this.paymentMethod = '',
    this.paymentDate = '',
    this.periodStart = '',
    this.periodEnd = '',
    this.periodUnlimited = false,
    this.remarks = '',
    this.cancelDeadline = const ContractCancelDeadline.hoursBefore(
      kContractDefaultCancelHours,
    ),
    this.lateNoShowMinutes = kContractDefaultLateLimitMinutes,
    this.penaltyPercent = kContractDefaultPenaltyPercent,
    this.refundBusinessDays = kContractDefaultRefundBusinessDays,
    this.refundByListPrice = false,
    this.transferPolicy = ContractTransferPolicy.conditional,
    this.transferFeeType = ContractTransferFeeType.none,
    this.transferFeeValue = 0,
    this.expiryExtensionClause = true,
    this.unavoidableRefundClause = false,
    this.extraTerms = '',
  });

  final String memberId;
  final String memberName;
  final String memberPhone;
  final String memberBirthDate;
  final String memberEmail;

  final String productName;
  final int? sessionCount;
  final int? sessionMinutes;
  final int? paidAmount;

  /// 실결제금액에 부가가치세(VAT)가 포함돼 있는지.
  final bool vatIncluded;
  final int? listPrice;
  final String paymentMethod;
  final String paymentDate;
  final String periodStart;
  final String periodEnd;

  /// 유효기간 종료일을 정하지 않는 계약(기간 경과로 남은 횟수가 소멸하지 않음). 이때 [periodEnd]는 비운다.
  final bool periodUnlimited;

  /// 안내용 비고(분할결제 일정 등, 최대 100자). 특약과 달리 계약 조항이 아니다.
  final String remarks;

  /// 계약서에 표시하는 종료일 문구.
  String get periodEndLabel =>
      periodUnlimited ? '종료일 없음' : (periodEnd.isEmpty ? '-' : periodEnd);

  final ContractCancelDeadline cancelDeadline;
  final int? lateNoShowMinutes;
  final int penaltyPercent;
  final int refundBusinessDays;
  final bool refundByListPrice;
  final ContractTransferPolicy transferPolicy;
  final ContractTransferFeeType transferFeeType;
  final int transferFeeValue;
  final bool expiryExtensionClause;
  final bool unavoidableRefundClause;
  final String extraTerms;

  /// 내 기본 조건으로 채운 새 계약.
  factory LessonContractForm.fromDefaults(
    ContractDefaults defaults, {
    required DateTime today,
  }) => LessonContractForm(
    periodStart: formatContractDate(today),
    paymentDate: formatContractDate(today),
    cancelDeadline: defaults.cancelDeadline,
    lateNoShowMinutes: defaults.lateNoShowMinutes,
    penaltyPercent: defaults.penaltyPercent,
    refundBusinessDays: defaults.refundBusinessDays,
    transferPolicy: defaults.transferPolicy,
    transferFeeType:
        defaults.transferFeePercent > 0
            ? ContractTransferFeeType.percent
            : ContractTransferFeeType.none,
    transferFeeValue: defaults.transferFeePercent,
    expiryExtensionClause: defaults.expiryExtensionClause,
    unavoidableRefundClause: defaults.unavoidableRefundClause,
  );

  /// 저장된 계약 문서(`personal_contracts`)에서 이어서 편집할 값을 만든다.
  factory LessonContractForm.fromContract(Map<String, dynamic> data) {
    Map<String, dynamic> section(String key) {
      final value = data[key];
      return value is Map ? Map<String, dynamic>.from(value) : {};
    }

    final member = section('member');
    final product = section('product');
    final terms = section('terms');
    final transfer =
        terms['transfer'] is Map
            ? Map<String, dynamic>.from(terms['transfer'] as Map)
            : <String, dynamic>{};
    final fallback = ContractDefaults.fromMap(terms);
    return LessonContractForm(
      memberId: _text(data['memberId']),
      memberName: _text(member['name']),
      memberPhone: _text(member['phone']),
      memberBirthDate: _text(member['birthDate']),
      memberEmail: _text(member['email']),
      productName: _text(product['name']),
      sessionCount: _intOrNull(product['sessionCount']),
      sessionMinutes: _intOrNull(product['sessionMinutes']),
      paidAmount: _intOrNull(product['paidAmount']),
      vatIncluded: product['vatIncluded'] == true,
      listPrice: _intOrNull(product['listPrice']),
      paymentMethod: _text(product['paymentMethod']),
      paymentDate: _text(product['paymentDate']),
      periodStart: _text(product['periodStart']),
      periodEnd: _text(product['periodEnd']),
      periodUnlimited: product['periodUnlimited'] == true,
      remarks: _text(product['remarks']),
      cancelDeadline: fallback.cancelDeadline,
      lateNoShowMinutes: fallback.lateNoShowMinutes,
      penaltyPercent: fallback.penaltyPercent,
      refundBusinessDays: fallback.refundBusinessDays,
      refundByListPrice: terms['refundBasis'] == 'list_price',
      transferPolicy: fallback.transferPolicy,
      transferFeeType: ContractTransferFeeType.parse(transfer['feeType']),
      transferFeeValue: _intOrNull(transfer['feeValue']) ?? 0,
      expiryExtensionClause: fallback.expiryExtensionClause,
      unavoidableRefundClause: fallback.unavoidableRefundClause,
      extraTerms: _text(terms['extraTerms']),
    );
  }

  LessonContractForm copyWith({
    String? memberId,
    String? memberName,
    String? memberPhone,
    String? memberBirthDate,
    String? memberEmail,
    String? productName,
    int? sessionCount,
    bool clearSessionCount = false,
    int? sessionMinutes,
    bool clearSessionMinutes = false,
    int? paidAmount,
    bool clearPaidAmount = false,
    bool? vatIncluded,
    int? listPrice,
    bool clearListPrice = false,
    String? paymentMethod,
    String? paymentDate,
    String? periodStart,
    String? periodEnd,
    bool? periodUnlimited,
    String? remarks,
    ContractCancelDeadline? cancelDeadline,
    int? lateNoShowMinutes,
    bool clearLateNoShow = false,
    int? penaltyPercent,
    int? refundBusinessDays,
    bool? refundByListPrice,
    ContractTransferPolicy? transferPolicy,
    ContractTransferFeeType? transferFeeType,
    int? transferFeeValue,
    bool? expiryExtensionClause,
    bool? unavoidableRefundClause,
    String? extraTerms,
  }) => LessonContractForm(
    memberId: memberId ?? this.memberId,
    memberName: memberName ?? this.memberName,
    memberPhone: memberPhone ?? this.memberPhone,
    memberBirthDate: memberBirthDate ?? this.memberBirthDate,
    memberEmail: memberEmail ?? this.memberEmail,
    productName: productName ?? this.productName,
    sessionCount:
        clearSessionCount ? null : (sessionCount ?? this.sessionCount),
    sessionMinutes:
        clearSessionMinutes ? null : (sessionMinutes ?? this.sessionMinutes),
    paidAmount: clearPaidAmount ? null : (paidAmount ?? this.paidAmount),
    vatIncluded: vatIncluded ?? this.vatIncluded,
    listPrice: clearListPrice ? null : (listPrice ?? this.listPrice),
    paymentMethod: paymentMethod ?? this.paymentMethod,
    paymentDate: paymentDate ?? this.paymentDate,
    periodStart: periodStart ?? this.periodStart,
    periodEnd: periodEnd ?? this.periodEnd,
    periodUnlimited: periodUnlimited ?? this.periodUnlimited,
    remarks: remarks ?? this.remarks,
    cancelDeadline: cancelDeadline ?? this.cancelDeadline,
    lateNoShowMinutes:
        clearLateNoShow ? null : (lateNoShowMinutes ?? this.lateNoShowMinutes),
    penaltyPercent: penaltyPercent ?? this.penaltyPercent,
    refundBusinessDays: refundBusinessDays ?? this.refundBusinessDays,
    refundByListPrice: refundByListPrice ?? this.refundByListPrice,
    transferPolicy: transferPolicy ?? this.transferPolicy,
    transferFeeType: transferFeeType ?? this.transferFeeType,
    transferFeeValue: transferFeeValue ?? this.transferFeeValue,
    expiryExtensionClause: expiryExtensionClause ?? this.expiryExtensionClause,
    unavoidableRefundClause:
        unavoidableRefundClause ?? this.unavoidableRefundClause,
    extraTerms: extraTerms ?? this.extraTerms,
  );

  /// 서비스 내용은 입력받지 않고 상품명·횟수·1회 시간으로 자동 작성한다.
  String get serviceContent {
    final name = productName.trim();
    final count = sessionCount;
    final minutes = sessionMinutes;
    if (name.isEmpty) return '';
    if (count == null || minutes == null) return name;
    return '$name (총 $count회, 1회 $minutes분)';
  }

  /// 내 수업 상품을 불러와 상품 칸을 채운다. 기간·결제 정보와 조건은 그대로 둔다.
  LessonContractForm applyPreset(ContractProductPreset preset) {
    final list = preset.listPrice;
    return copyWith(
      productName: preset.name,
      sessionCount: preset.sessionCount,
      sessionMinutes: preset.sessionMinutes,
      paidAmount: preset.paidAmount,
      listPrice: list,
      clearListPrice: list == null,
      refundByListPrice: list == null ? false : refundByListPrice,
    );
  }

  /// 지금 입력한 상품 칸을 내 수업 상품으로 저장할 수 있는 형태로 바꾼다. 모자라면 null.
  ContractProductPreset? toPreset() {
    final count = sessionCount;
    final minutes = sessionMinutes;
    final paid = paidAmount;
    if (count == null ||
        minutes == null ||
        paid == null ||
        productName.trim().isEmpty) {
      return null;
    }
    return ContractProductPreset(
      name: productName.trim(),
      serviceContent: serviceContent,
      sessionCount: count,
      sessionMinutes: minutes,
      paidAmount: paid,
      listPrice: canUseListPriceBasis ? listPrice : null,
    );
  }

  /// 회당 금액(결제금액 ÷ 횟수, 원 단위 반올림). 입력이 모자라면 null.
  int? get unitPrice {
    final paid = paidAmount;
    final count = sessionCount;
    if (paid == null || count == null || paid < 1 || count < 1) return null;
    return contractUnitPrice(paid, count);
  }

  /// 정상가 기준을 실제로 쓸 수 있는지(정상가가 결제금액보다 클 때만).
  bool get canUseListPriceBasis {
    final paid = paidAmount;
    final list = listPrice;
    return paid != null && list != null && list > paid;
  }

  bool get usesListPriceBasis => refundByListPrice && canUseListPriceBasis;

  /// 계약 조건 칸만 검사한 오류(`내 기본 조건` 설정 화면에서 쓴다).
  Map<String, String> validateTerms() {
    const keys = {
      'cancelDeadline',
      'lateNoShowMinutes',
      'penaltyPercent',
      'refundBusinessDays',
      'transferFee',
    };
    return {
      for (final entry in validate().entries)
        if (keys.contains(entry.key)) entry.key: entry.value,
    };
  }

  /// 조건 칸을 `내 기본 조건`으로 바꾼다(정액 수수료·정상가 기준·추가 특약은 제외).
  ContractDefaults toDefaults() => ContractDefaults(
    cancelDeadline: cancelDeadline,
    lateNoShowMinutes: lateNoShowMinutes,
    penaltyPercent: penaltyPercent,
    refundBusinessDays: refundBusinessDays,
    transferPolicy: transferPolicy,
    transferFeePercent:
        transferPolicy == ContractTransferPolicy.denied ||
                transferFeeType != ContractTransferFeeType.percent
            ? 0
            : transferFeeValue,
    expiryExtensionClause: expiryExtensionClause,
    unavoidableRefundClause: unavoidableRefundClause,
  );

  /// 칸 이름 → 오류 문구. 비어 있으면 서버 검증도 통과한다.
  Map<String, String> validate() {
    final errors = <String, String>{};

    if (memberId.trim().isEmpty) errors['member'] = '회원을 선택해 주세요.';
    final nameLength = memberName.trim().length;
    if (nameLength < 2 || nameLength > 20) {
      errors['memberName'] = '고객카드의 회원 이름을 확인해 주세요. 회원카드에서 수정할 수 있어요.';
    }
    if (!RegExp(r'^[0-9+\-\s()]{8,20}$').hasMatch(memberPhone.trim())) {
      errors['memberPhone'] = '고객카드에 연락처가 없어요. 회원카드에서 먼저 입력해 주세요.';
    }
    final birth = memberBirthDate.trim();
    if (birth.isNotEmpty && parseContractDate(birth) == null) {
      errors['memberBirthDate'] = '고객카드의 생년월일 형식을 확인해 주세요.';
    }
    final email = memberEmail.trim();
    if (email.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      errors['memberEmail'] = '이메일 형식을 확인해 주세요.';
    }

    _guarded(errors, 'productName', productName, 1, 40, '레슨명을 1~40자로 입력해 주세요.');

    final count = sessionCount;
    if (count == null || count < 1 || count > 200) {
      errors['sessionCount'] = '횟수를 1~200회로 입력해 주세요.';
    }
    final minutes = sessionMinutes;
    if (minutes == null || minutes < 10 || minutes > 180) {
      errors['sessionMinutes'] = '1회 시간을 10~180분으로 입력해 주세요.';
    }
    final paid = paidAmount;
    if (paid == null || paid < 1 || paid > kContractMaxPaidAmount) {
      errors['paidAmount'] = '실결제금액을 1원~1억원으로 입력해 주세요.';
    }
    final list = listPrice;
    if (list != null && paid != null) {
      if (list <= paid || list > kContractMaxListPrice) {
        errors['listPrice'] = '정상가는 실결제금액보다 커야 해요.';
      }
    }
    if (refundByListPrice && !canUseListPriceBasis) {
      errors['refundBasis'] = '정상가 기준은 정상가를 입력해야 쓸 수 있어요.';
    }

    if (paymentDate.trim().isNotEmpty &&
        parseContractDate(paymentDate.trim()) == null) {
      errors['paymentDate'] = '결제일을 확인해 주세요.';
    }
    final start = parseContractDate(periodStart.trim());
    final end = periodUnlimited ? null : parseContractDate(periodEnd.trim());
    if (start == null) errors['periodStart'] = '사용 시작일을 선택해 주세요.';
    if (!periodUnlimited && end == null) {
      errors['periodEnd'] = '유효기간 종료일을 선택해 주세요.';
    }
    if (start != null && end != null) {
      final span = end.difference(start).inDays;
      if (span < 0) {
        errors['periodEnd'] = '유효기간 종료일은 사용 시작일 이후여야 해요.';
      } else if (span > kContractMaxPeriodDays) {
        errors['periodEnd'] = '사용 가능 기간은 최대 3년이에요.';
      }
    }

    final deadline = cancelDeadline;
    if (!deadline.sameDay &&
        (deadline.hours < 1 || deadline.hours > kContractMaxCancelHours)) {
      errors['cancelDeadline'] =
          '취소 마감 시간은 1~$kContractMaxCancelHours시간 안에서 정해 주세요.';
    }
    final late = lateNoShowMinutes;
    if (late != null && (late < 10 || late > 60)) {
      errors['lateNoShowMinutes'] = '진행 불가 기준은 시작시간 후 10~60분이에요.';
    }
    if (penaltyPercent < 0 || penaltyPercent > kContractMaxPenaltyPercent) {
      errors['penaltyPercent'] = '위약금은 0~$kContractMaxPenaltyPercent%예요.';
    }
    if (refundBusinessDays < 1 ||
        refundBusinessDays > kContractMaxRefundBusinessDays) {
      errors['refundBusinessDays'] =
          '환급 처리 기한은 1~$kContractMaxRefundBusinessDays영업일(약 6개월)이에요.';
    }
    if (transferPolicy == ContractTransferPolicy.denied &&
        transferFeeType != ContractTransferFeeType.none) {
      errors['transferFee'] = '양도를 허용하지 않으면 수수료를 정할 수 없어요.';
    } else if (transferFeeType == ContractTransferFeeType.percent &&
        (transferFeeValue < 1 ||
            transferFeeValue > kContractMaxPenaltyPercent)) {
      errors['transferFee'] = '양도 수수료는 1~$kContractMaxPenaltyPercent%예요.';
    } else if (transferFeeType == ContractTransferFeeType.amount) {
      final cap = (paid ?? 0) ~/ 10;
      if (transferFeeValue < 1 || transferFeeValue > cap) {
        errors['transferFee'] =
            cap < 1 ? '결제금액을 먼저 입력해 주세요.' : '양도 수수료는 1~${formatWon(cap)}원이에요.';
      }
    }

    final note = remarks.trim();
    if (note.length > kContractMaxRemarksLength) {
      errors['remarks'] = '비고는 $kContractMaxRemarksLength자 이내로 입력해 주세요.';
    } else if (note.isNotEmpty) {
      final hit = findForbiddenPhrase(note);
      if (hit != null) errors['remarks'] = forbiddenPhraseMessage(hit);
    }

    final extra = extraTerms.trim();
    if (extra.length > 500) {
      errors['extraTerms'] = '추가 특약은 500자 이내로 입력해 주세요.';
    } else if (extra.isNotEmpty) {
      final hit = findForbiddenPhrase(extra);
      if (hit != null) errors['extraTerms'] = forbiddenPhraseMessage(hit);
    }
    return errors;
  }

  static void _guarded(
    Map<String, String> errors,
    String key,
    String value,
    int min,
    int max,
    String lengthMessage,
  ) {
    final text = value.trim();
    if (text.length < min || text.length > max) {
      errors[key] = lengthMessage;
      return;
    }
    final hit = findForbiddenPhrase(text);
    if (hit != null) errors[key] = forbiddenPhraseMessage(hit);
  }

  /// 앱 기본안과 다른 항목 이름(`기본안과 다름` 표시). 기본안은 서버 고정 값과
  /// `ContractDefaults.standard`다.
  List<String> differencesFromStandard() {
    const base = ContractDefaults.standard;
    return [
      if (cancelDeadline != base.cancelDeadline) '취소 마감 시간',
      if (lateNoShowMinutes != base.lateNoShowMinutes) '진행 불가 기준(지각)',
      if (penaltyPercent != base.penaltyPercent) '위약금',
      if (refundBusinessDays != base.refundBusinessDays) '환급 처리 기한',
      if (usesListPriceBasis) '정상가 기준 환불',
      if (transferPolicy != base.transferPolicy ||
          transferFeeType != ContractTransferFeeType.none)
        '양도',
      if (expiryExtensionClause != base.expiryExtensionClause) '연장 협의 문구',
      if (unavoidableRefundClause != base.unavoidableRefundClause) '불가피 사유 환불',
      if (extraTerms.trim().isNotEmpty) '추가 특약',
    ];
  }

  /// 서버 `savePersonalContractDraft`의 `content`. 먼저 [validate]가 비어 있어야 한다.
  Map<String, Object?> toContent(ContractParty party) {
    final feeType =
        transferPolicy == ContractTransferPolicy.denied
            ? ContractTransferFeeType.none
            : transferFeeType;
    return {
      'party': party.toCallable(),
      'member': {
        'name': memberName.trim(),
        'phone': memberPhone.trim(),
        'birthDate': memberBirthDate.trim(),
        'email': memberEmail.trim(),
      },
      'product': {
        'name': productName.trim(),
        'serviceContent': serviceContent,
        'sessionCount': sessionCount,
        'sessionMinutes': sessionMinutes,
        'paidAmount': paidAmount,
        // 이전 서버 버전과도 맞도록 선택했을 때만 보낸다(서버 기본값은 false).
        if (vatIncluded) 'vatIncluded': true,
        'listPrice': listPrice,
        'paymentMethod': paymentMethod,
        'paymentDate': paymentDate.trim(),
        'periodStart': periodStart.trim(),
        'periodEnd': periodUnlimited ? '' : periodEnd.trim(),
        // 이전 서버 버전과도 맞도록 종료일이 없는 계약일 때만 보낸다.
        if (periodUnlimited) 'periodUnlimited': true,
        // 이전 서버 버전과도 맞도록 입력했을 때만 보낸다.
        if (remarks.trim().isNotEmpty) 'remarks': remarks.trim(),
      },
      'terms': {
        'cancelDeadline': cancelDeadline.toCallable(),
        'lateNoShowMinutes': lateNoShowMinutes,
        'penaltyPercent': penaltyPercent,
        'refundBasis': usesListPriceBasis ? 'list_price' : 'contract_unit',
        'refundBusinessDays': refundBusinessDays,
        'transfer': {
          'policy': transferPolicy.wire,
          'feeType': feeType.wire,
          'feeValue':
              feeType == ContractTransferFeeType.none ? 0 : transferFeeValue,
        },
        'expiryExtensionClause': expiryExtensionClause,
        'unavoidableRefundClause': unavoidableRefundClause,
        'extraTerms': extraTerms.trim(),
      },
    };
  }
}
