/// 레슨계약서 v2 설정 값(당사자 + 내 기본 조건). 서버 규칙
/// (`functions/src/personal_contract_rules.ts`)과 같은 상한·형식을 쓴다.
library;

const int kContractMaxPenaltyPercent = 10;
const int kContractDefaultPenaltyPercent = 10;
const int kContractDefaultCancelHours = 24;

/// 환급 처리 기한 입력 상한(약 6개월). 3영업일을 넘기면 입력할 때 안내가 나온다.
const int kContractMaxRefundBusinessDays = 130;
const int kContractDefaultRefundBusinessDays = 3;
const int kContractMaxCancelHours = 72;

/// 레슨 시작시간 이후 이 시간(분)이 지나면 레슨 진행이 불가하다는 기본 기준.
const int kContractDefaultLateLimitMinutes = 30;

enum ContractPartyKind {
  center('center'),
  individual('individual');

  const ContractPartyKind(this.wire);
  final String wire;

  static ContractPartyKind parse(Object? value) =>
      value == 'center' ? center : individual;
}

enum ContractTransferPolicy {
  allowed('allowed', '허용'),
  conditional('conditional', '조건부'),
  denied('denied', '불허');

  const ContractTransferPolicy(this.wire, this.label);
  final String wire;
  final String label;

  static ContractTransferPolicy parse(Object? value) {
    for (final policy in values) {
      if (policy.wire == value) return policy;
    }
    return conditional;
  }
}

String _text(Object? value) => (value ?? '').toString().trim();

int _int(Object? value, int fallback) =>
    value is num ? value.toInt() : fallback;

/// 계약 당사자(센터 또는 강사 개인).
class ContractParty {
  const ContractParty({
    required this.kind,
    required this.name,
    required this.trainerName,
    required this.phone,
    required this.place,
    this.businessNo = '',
    this.logoPath = '',
  });

  final ContractPartyKind kind;
  final String name;
  final String trainerName;
  final String phone;
  final String place;
  final String businessNo;
  final String logoPath;

  factory ContractParty.fromMap(Map<String, dynamic> map) => ContractParty(
    kind: ContractPartyKind.parse(map['kind']),
    name: _text(map['name']),
    trainerName: _text(map['trainerName']),
    phone: _text(map['phone']),
    place: _text(map['place']),
    businessNo: _text(map['businessNo']),
    logoPath: _text(map['logoPath']),
  );

  Map<String, Object?> toCallable() => {
    'kind': kind.wire,
    'name': name.trim(),
    'trainerName': trainerName.trim(),
    'phone': phone.trim(),
    'place': place.trim(),
    'businessNo': businessNo.trim(),
    'logoPath': logoPath.trim(),
  };

  ContractParty copyWith({
    ContractPartyKind? kind,
    String? name,
    String? trainerName,
    String? phone,
    String? place,
    String? businessNo,
    String? logoPath,
  }) => ContractParty(
    kind: kind ?? this.kind,
    name: name ?? this.name,
    trainerName: trainerName ?? this.trainerName,
    phone: phone ?? this.phone,
    place: place ?? this.place,
    businessNo: businessNo ?? this.businessNo,
    logoPath: logoPath ?? this.logoPath,
  );

  /// 계약서에 쓸 수 있는 상태인지(필수 칸이 모두 채워졌는지).
  bool get isComplete => validate().isEmpty;

  /// 칸 이름 → 오류 문구. 비어 있으면 서버 검증도 통과한다.
  Map<String, String> validate() {
    final errors = <String, String>{};
    final nameLength = name.trim().length;
    if (nameLength < 2 || nameLength > 40) {
      errors['name'] =
          kind == ContractPartyKind.center
              ? '센터 이름을 2~40자로 입력해 주세요.'
              : '표시할 이름을 2~40자로 입력해 주세요.';
    }
    final trainerLength = trainerName.trim().length;
    if (trainerLength < 2 || trainerLength > 20) {
      errors['trainerName'] = '담당 강사 이름을 2~20자로 입력해 주세요.';
    }
    if (!RegExp(r'^[0-9+\-\s()]{8,20}$').hasMatch(phone.trim())) {
      errors['phone'] = '연락처를 숫자로 입력해 주세요.';
    }
    final placeLength = place.trim().length;
    if (placeLength < 2 || placeLength > 100) {
      errors['place'] = '수업 장소를 2~100자로 입력해 주세요.';
    }
    final business = businessNo.trim();
    if (business.isNotEmpty &&
        !RegExp(r'^\d{3}-?\d{2}-?\d{5}$').hasMatch(business)) {
      errors['businessNo'] = '사업자등록번호는 숫자 10자리로 입력해 주세요.';
    }
    return errors;
  }
}

/// 취소 마감 시간. `hours == 0`이면 당일 취소 불가.
class ContractCancelDeadline {
  const ContractCancelDeadline.hoursBefore(this.hours) : sameDay = false;
  const ContractCancelDeadline.sameDay() : hours = 0, sameDay = true;

  final int hours;
  final bool sameDay;

  Map<String, Object?> toCallable() => {
    'mode': sameDay ? 'same_day' : 'hours_before',
    'hours': sameDay ? 0 : hours,
  };

  factory ContractCancelDeadline.fromMap(Object? raw) {
    if (raw is Map && raw['mode'] == 'same_day') {
      return const ContractCancelDeadline.sameDay();
    }
    final hours =
        raw is Map ? _int(raw['hours'], kContractDefaultCancelHours) : 0;
    if (hours < 1 || hours > kContractMaxCancelHours) {
      return const ContractCancelDeadline.hoursBefore(
        kContractDefaultCancelHours,
      );
    }
    return ContractCancelDeadline.hoursBefore(hours);
  }

  String get label => sameDay ? '당일 취소 불가' : '수업 $hours시간 전';

  @override
  bool operator ==(Object other) =>
      other is ContractCancelDeadline &&
      other.sameDay == sameDay &&
      other.hours == hours;

  @override
  int get hashCode => Object.hash(sameDay, hours);
}

/// 내 기본 조건. 새 계약을 시작할 때 채워지고 계약마다 한 번 더 바꿀 수 있다.
/// 마감 후 취소·노쇼 1회 차감, 강사 사정 취소 미차감·보강, 만료 후 소멸은 고정이라
/// 여기에 없다.
class ContractDefaults {
  const ContractDefaults({
    this.cancelDeadline = const ContractCancelDeadline.hoursBefore(
      kContractDefaultCancelHours,
    ),
    this.lateNoShowMinutes = kContractDefaultLateLimitMinutes,
    this.penaltyPercent = kContractDefaultPenaltyPercent,
    this.refundBusinessDays = kContractDefaultRefundBusinessDays,
    this.transferPolicy = ContractTransferPolicy.conditional,
    this.transferFeePercent = 0,
    this.expiryExtensionClause = true,
    this.unavoidableRefundClause = false,
  });

  final ContractCancelDeadline cancelDeadline;
  final int? lateNoShowMinutes;
  final int penaltyPercent;
  final int refundBusinessDays;
  final ContractTransferPolicy transferPolicy;

  /// 0이면 수수료 없음. 양도 불허일 때는 항상 0.
  final int transferFeePercent;
  final bool expiryExtensionClause;
  final bool unavoidableRefundClause;

  static const ContractDefaults standard = ContractDefaults();

  factory ContractDefaults.fromMap(Map<String, dynamic> map) {
    final transfer = map['transfer'];
    final policy =
        transfer is Map
            ? ContractTransferPolicy.parse(transfer['policy'])
            : ContractTransferPolicy.conditional;
    final feePercent =
        transfer is Map && transfer['feeType'] == 'percent'
            ? _int(transfer['feeValue'], 0)
            : 0;
    final late = map['lateNoShowMinutes'];
    return ContractDefaults(
      cancelDeadline: ContractCancelDeadline.fromMap(map['cancelDeadline']),
      lateNoShowMinutes:
          late is num
              ? late.toInt()
              : (map.containsKey('lateNoShowMinutes')
                  ? null
                  : kContractDefaultLateLimitMinutes),
      penaltyPercent: _int(
        map['penaltyPercent'],
        kContractDefaultPenaltyPercent,
      ).clamp(0, kContractMaxPenaltyPercent),
      refundBusinessDays: _int(
        map['refundBusinessDays'],
        kContractDefaultRefundBusinessDays,
      ).clamp(1, kContractMaxRefundBusinessDays),
      transferPolicy: policy,
      transferFeePercent:
          policy == ContractTransferPolicy.denied
              ? 0
              : feePercent.clamp(0, kContractMaxPenaltyPercent),
      expiryExtensionClause: map['expiryExtensionClause'] != false,
      unavoidableRefundClause: map['unavoidableRefundClause'] == true,
    );
  }

  Map<String, Object?> toCallable() {
    final feePercent =
        transferPolicy == ContractTransferPolicy.denied
            ? 0
            : transferFeePercent;
    return {
      'cancelDeadline': cancelDeadline.toCallable(),
      'lateNoShowMinutes': lateNoShowMinutes,
      'penaltyPercent': penaltyPercent,
      'refundBusinessDays': refundBusinessDays,
      'transfer': {
        'policy': transferPolicy.wire,
        'feeType': feePercent > 0 ? 'percent' : 'none',
        'feeValue': feePercent,
      },
      'expiryExtensionClause': expiryExtensionClause,
      'unavoidableRefundClause': unavoidableRefundClause,
    };
  }

  ContractDefaults copyWith({
    ContractCancelDeadline? cancelDeadline,
    int? lateNoShowMinutes,
    bool clearLateNoShow = false,
    int? penaltyPercent,
    int? refundBusinessDays,
    ContractTransferPolicy? transferPolicy,
    int? transferFeePercent,
    bool? expiryExtensionClause,
    bool? unavoidableRefundClause,
  }) => ContractDefaults(
    cancelDeadline: cancelDeadline ?? this.cancelDeadline,
    lateNoShowMinutes:
        clearLateNoShow ? null : (lateNoShowMinutes ?? this.lateNoShowMinutes),
    penaltyPercent: penaltyPercent ?? this.penaltyPercent,
    refundBusinessDays: refundBusinessDays ?? this.refundBusinessDays,
    transferPolicy: transferPolicy ?? this.transferPolicy,
    transferFeePercent: transferFeePercent ?? this.transferFeePercent,
    expiryExtensionClause: expiryExtensionClause ?? this.expiryExtensionClause,
    unavoidableRefundClause:
        unavoidableRefundClause ?? this.unavoidableRefundClause,
  );

  /// 앱 기본안과 다른 항목 이름(`기본안과 다름` 표시용).
  List<String> differencesFromStandard() {
    const base = ContractDefaults.standard;
    return [
      if (cancelDeadline != base.cancelDeadline) '취소 마감 시간',
      if (lateNoShowMinutes != base.lateNoShowMinutes) '진행 불가 기준(지각)',
      if (penaltyPercent != base.penaltyPercent) '위약금',
      if (refundBusinessDays != base.refundBusinessDays) '환급 처리 기한',
      if (transferPolicy != base.transferPolicy ||
          transferFeePercent != base.transferFeePercent)
        '양도',
      if (expiryExtensionClause != base.expiryExtensionClause) '연장 협의 문구',
      if (unavoidableRefundClause != base.unavoidableRefundClause) '불가피 사유 환불',
    ];
  }
}

/// 내 수업 상품(계약 입력 화면에서 불러오는 목록). 기간·결제 정보는 계약마다 정한다.
class ContractProductPreset {
  const ContractProductPreset({
    required this.name,
    required this.serviceContent,
    required this.sessionCount,
    required this.sessionMinutes,
    required this.paidAmount,
    this.listPrice,
  });

  final String name;
  final String serviceContent;
  final int sessionCount;
  final int sessionMinutes;
  final int paidAmount;
  final int? listPrice;

  /// 이름(대소문자 무시)을 포함한 모든 내용이 같은지. 이미 저장된 상품인지 알아볼 때 쓴다.
  bool hasSameContentAs(ContractProductPreset other) =>
      name.trim().toLowerCase() == other.name.trim().toLowerCase() &&
      serviceContent.trim() == other.serviceContent.trim() &&
      sessionCount == other.sessionCount &&
      sessionMinutes == other.sessionMinutes &&
      paidAmount == other.paidAmount &&
      listPrice == other.listPrice;

  static ContractProductPreset? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final name = _text(raw['name']);
    final count = raw['sessionCount'];
    final minutes = raw['sessionMinutes'];
    final paid = raw['paidAmount'];
    if (name.isEmpty || count is! num || minutes is! num || paid is! num) {
      return null;
    }
    final list = raw['listPrice'];
    return ContractProductPreset(
      name: name,
      serviceContent: _text(raw['serviceContent']),
      sessionCount: count.toInt(),
      sessionMinutes: minutes.toInt(),
      paidAmount: paid.toInt(),
      listPrice: list is num ? list.toInt() : null,
    );
  }

  Map<String, Object?> toCallable() => {
    'name': name.trim(),
    'serviceContent': serviceContent.trim(),
    'sessionCount': sessionCount,
    'sessionMinutes': sessionMinutes,
    'paidAmount': paidAmount,
    'listPrice': listPrice,
  };
}

/// 프로필 문서에서 읽은 설정.
class ContractSettings {
  const ContractSettings({
    this.party,
    this.defaults = ContractDefaults.standard,
    this.products = const [],
  });

  final ContractParty? party;
  final ContractDefaults defaults;
  final List<ContractProductPreset> products;

  factory ContractSettings.fromProfile(Map<String, dynamic>? profile) {
    final partyRaw = profile?['contractParty'];
    final defaultsRaw = profile?['contractDefaults'];
    final productsRaw = profile?['contractProducts'];
    // 로고는 마이페이지의 `centerLogoPath`가 기준이다(없으면 예전에 저장한 값을 쓴다).
    final hasCenterLogo = profile?.containsKey('centerLogoPath') ?? false;
    final centerLogo = _text(profile?['centerLogoPath']);
    ContractParty? withLogo(ContractParty? party) =>
        party == null || !hasCenterLogo
            ? party
            : party.copyWith(logoPath: centerLogo);
    return ContractSettings(
      products: [
        if (productsRaw is List)
          for (final item in productsRaw)
            if (ContractProductPreset.tryParse(item) case final preset?) preset,
      ],
      party: withLogo(
        partyRaw is Map
            ? ContractParty.fromMap(Map<String, dynamic>.from(partyRaw))
            : null,
      ),
      defaults:
          defaultsRaw is Map
              ? ContractDefaults.fromMap(Map<String, dynamic>.from(defaultsRaw))
              : ContractDefaults.standard,
    );
  }

  /// 저장된 당사자가 없을 때 프로필(소속·이름·연락처)에서 처음 채울 값.
  /// 센터에 소속돼 센터 이름이 있으면 센터, 아니면 강사 개인. 센터 이름 기본값은 없다.
  static ContractParty suggestParty(Map<String, dynamic>? profile) {
    final affiliation = _text(profile?['affiliationType']);
    final gymName = _text(profile?['gymName']);
    final realName = _text(profile?['realName']);
    final trainerName =
        _text(profile?['contractTrainerName']).isNotEmpty
            ? _text(profile?['contractTrainerName'])
            : (realName.isNotEmpty ? realName : _text(profile?['nickname']));
    final isCenter =
        (affiliation == 'center' || affiliation == 'personal_shop') &&
        gymName.isNotEmpty;
    return ContractParty(
      kind: isCenter ? ContractPartyKind.center : ContractPartyKind.individual,
      name: isCenter ? gymName : trainerName,
      trainerName: trainerName,
      phone: _text(profile?['phone']),
      place: isCenter ? _text(profile?['centerLocation']) : '',
      logoPath: _text(profile?['centerLogoPath']),
    );
  }
}
