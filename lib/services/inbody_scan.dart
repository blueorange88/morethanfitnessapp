// 인바디 용지를 글자 인식(OCR)으로 읽은 결과를 해석하고, 용지가 이 회원 것인지 확인한다.
//
// 인식은 기기 안(ML Kit)에서 이뤄지며 이 파일은 인식된 글자(문자열)만 다룬다.
// 용지 모양은 기종마다 달라서 키워드와 숫자 범위로 읽는 방식이다. 못 읽은 값은 빈 문자열이며,
// 사용자가 확인 화면에서 고친다.

class InbodyScanResult {
  const InbodyScanResult({
    this.date = '',
    this.height = '',
    this.weight = '',
    this.skeletalMuscle = '',
    this.bodyFatPercent = '',
    this.bodyFatKg = '',
    this.age,
    this.gender,
    this.rawText = '',
  });

  /// 측정일(`YYYY.MM.DD` 또는 `YYYY-MM-DD` 그대로).
  final String date;
  final String height;
  final String weight;
  final String skeletalMuscle;
  final String bodyFatPercent;
  final String bodyFatKg;

  /// 용지에 적힌 나이(세).
  final int? age;

  /// 용지에 적힌 성별: `male` / `female` / null(못 읽음).
  final String? gender;

  /// 인식된 원문(DEV 확인용).
  final String rawText;

  bool get hasAnyMeasurement =>
      height.isNotEmpty ||
      weight.isNotEmpty ||
      skeletalMuscle.isNotEmpty ||
      bodyFatPercent.isNotEmpty ||
      bodyFatKg.isNotEmpty;
}

class _Range {
  const _Range(this.min, this.max);
  final double min;
  final double max;
  bool contains(double value) => value >= min && value <= max;
}

const _heightRange = _Range(100, 230);
const _weightRange = _Range(20, 300);
const _skeletalRange = _Range(5, 100);
const _bodyFatPercentRange = _Range(2, 70);
const _bodyFatKgRange = _Range(1, 150);

final RegExp _numberPattern = RegExp(r'(\d{1,3}(?:[.,]\d{1,2})?)');

List<String> _linesOf(String raw) =>
    raw
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

String _compact(String text) =>
    text.replaceAll(RegExp(r'\s+'), '').toLowerCase();

double? _parseNumber(String text) => double.tryParse(text.replaceAll(',', '.'));

/// 키워드가 있는 줄(과 그 아래 두 줄)에서 범위 안의 첫 숫자를 찾는다.
String _findValue(
  List<String> lines,
  List<String> keywords,
  _Range range, {
  List<String> excludeKeywords = const [],
}) {
  for (var i = 0; i < lines.length; i++) {
    final compact = _compact(lines[i]);
    final hasKeyword = keywords.any(
      (keyword) => compact.contains(_compact(keyword)),
    );
    if (!hasKeyword) continue;
    if (excludeKeywords.any((word) => compact.contains(_compact(word)))) {
      continue;
    }
    for (var offset = 0; offset <= 2 && i + offset < lines.length; offset++) {
      // 다른 항목 이름이 나오면 다음 줄 값은 그 항목의 것일 수 있어 멈춘다.
      if (offset > 0 && _looksLikeLabelLine(lines[i + offset])) break;
      for (final match in _numberPattern.allMatches(lines[i + offset])) {
        final value = _parseNumber(match.group(1)!);
        if (value != null && range.contains(value)) {
          return match.group(1)!.replaceAll(',', '.');
        }
      }
    }
  }
  return '';
}

bool _looksLikeLabelLine(String line) {
  final hangul = RegExp(r'[가-힣]').allMatches(line).length;
  final digits = RegExp(r'\d').allMatches(line).length;
  return hangul >= 2 && digits <= 1;
}

int? _findAge(List<String> lines, String raw) {
  // 123세 / 나이 35 / Age 35 / 연령 35
  final candidates = <RegExp>[
    RegExp(r'(\d{1,3})\s*세'),
    RegExp(r'(?:나이|연령|age)\s*[:：]?\s*(\d{1,3})', caseSensitive: false),
  ];
  for (final pattern in candidates) {
    for (final match in pattern.allMatches(raw)) {
      final age = int.tryParse(match.group(1)!);
      if (age != null && age >= 5 && age <= 110) return age;
    }
  }
  return null;
}

String? _findGender(String raw) {
  final labeled = RegExp(
    r'성별\s*[:：]?\s*(남|여|male|female)',
    caseSensitive: false,
  ).firstMatch(raw);
  if (labeled != null) {
    final value = labeled.group(1)!.toLowerCase();
    return (value == '남' || value == 'male') ? 'male' : 'female';
  }
  final hasMale =
      RegExp(r'남성|남자|\bmale\b', caseSensitive: false).hasMatch(raw) &&
      !RegExp(r'\bfemale\b', caseSensitive: false).hasMatch(raw);
  final hasFemale = RegExp(
    r'여성|여자|\bfemale\b',
    caseSensitive: false,
  ).hasMatch(raw);
  if (hasMale && !hasFemale) return 'male';
  if (hasFemale && !hasMale) return 'female';
  return null;
}

/// 인식된 글자에서 측정값·나이·성별을 읽는다.
InbodyScanResult parseInbodyText(String raw) {
  final lines = _linesOf(raw);
  final dateMatch = RegExp(
    r'(20\d{2}[.\-/]\d{1,2}[.\-/]\d{1,2})',
  ).firstMatch(raw);

  // 키는 "171cm"처럼 단위가 붙은 값을 우선하고, 없으면 "키" 라벨 줄에서 찾는다.
  var height = '';
  for (final match in RegExp(
    r'(\d{3}(?:[.,]\d)?)\s*cm',
    caseSensitive: false,
  ).allMatches(raw)) {
    final value = _parseNumber(match.group(1)!);
    if (value != null && _heightRange.contains(value)) {
      height = match.group(1)!.replaceAll(',', '.');
      break;
    }
  }
  if (height.isEmpty) {
    height = _findValue(lines, ['키', 'height'], _heightRange);
  }

  return InbodyScanResult(
    date: dateMatch?.group(1)?.replaceAll('/', '.') ?? '',
    height: height,
    weight: _findValue(
      lines,
      ['체중', 'weight'],
      _weightRange,
      excludeKeywords: ['제지방', '조절', '목표'],
    ),
    skeletalMuscle: _findValue(lines, [
      '골격근량',
      'smm',
      'skeletal',
    ], _skeletalRange),
    bodyFatPercent: _findValue(lines, [
      '체지방률',
      'pbf',
      '%체지방',
      'percentbodyfat',
    ], _bodyFatPercentRange),
    bodyFatKg: _findValue(
      lines,
      ['체지방량', 'bodyfatmass', 'fatmass'],
      _bodyFatKgRange,
      excludeKeywords: ['체지방률'],
    ),
    age: _findAge(lines, raw),
    gender: _findGender(raw),
    rawText: raw,
  );
}

/// 생일 기준 만 나이.
int? internationalAge(DateTime? birth, DateTime at) {
  if (birth == null) return null;
  var age = at.year - birth.year;
  final hadBirthday =
      at.month > birth.month ||
      (at.month == birth.month && at.day >= birth.day);
  if (!hadBirthday) age -= 1;
  return age < 0 ? null : age;
}

enum InbodyMemberMatch {
  /// 나이·성별이 모두 맞거나 맞는 쪽만 있고 어긋남이 없다.
  match,

  /// 나이가 1살 차이(생일 전후·입력 방식 차이일 수 있음).
  nearMatch,

  /// 나이가 2살 이상 다르거나 성별이 다르다. 다른 회원의 용지일 수 있다.
  mismatch,

  /// 비교할 값이 없다(용지에서 못 읽었거나 카드에 생년월일·성별이 없음).
  unknown,
}

class InbodyMemberCheck {
  const InbodyMemberCheck({
    required this.status,
    this.ageOnSheet,
    this.ageOnCard,
    this.genderOnSheet,
    this.genderOnCard,
    this.ageDifference,
    this.genderMismatch = false,
  });

  final InbodyMemberMatch status;
  final int? ageOnSheet;
  final int? ageOnCard;
  final String? genderOnSheet;
  final String? genderOnCard;
  final int? ageDifference;
  final bool genderMismatch;

  bool get needsConfirmation => status == InbodyMemberMatch.mismatch;
}

/// 카드 성별 값(남/여, male/female, 미입력 등)을 `male`/`female`/null로 바꾼다.
String? inbodyGenderKey(String? raw) {
  final value = (raw ?? '').trim().toLowerCase();
  if (value == '남' ||
      value == '남성' ||
      value == '남자' ||
      value == 'male' ||
      value == 'm') {
    return 'male';
  }
  if (value == '여' ||
      value == '여성' ||
      value == '여자' ||
      value == 'female' ||
      value == 'f') {
    return 'female';
  }
  return null;
}

/// 용지에서 읽은 나이·성별이 회원카드(생년월일·성별)와 맞는지 확인한다.
InbodyMemberCheck verifyInbodyAgainstMember({
  required InbodyScanResult scan,
  required DateTime? cardBirthDate,
  required String? cardGender,
  DateTime? measuredAt,
}) {
  final at = measuredAt ?? DateTime.now();
  final ageOnCard = internationalAge(cardBirthDate, at);
  final genderOnCard = inbodyGenderKey(cardGender);
  final ageOnSheet = scan.age;
  final genderOnSheet = scan.gender;

  final ageDifference =
      (ageOnCard != null && ageOnSheet != null)
          ? (ageOnSheet - ageOnCard).abs()
          : null;
  final genderMismatch =
      genderOnCard != null &&
      genderOnSheet != null &&
      genderOnCard != genderOnSheet;

  late final InbodyMemberMatch status;
  if (genderMismatch || (ageDifference != null && ageDifference >= 2)) {
    status = InbodyMemberMatch.mismatch;
  } else if (ageDifference == null &&
      (genderOnCard == null || genderOnSheet == null)) {
    status = InbodyMemberMatch.unknown;
  } else if (ageDifference == 1) {
    status = InbodyMemberMatch.nearMatch;
  } else {
    status = InbodyMemberMatch.match;
  }

  return InbodyMemberCheck(
    status: status,
    ageOnSheet: ageOnSheet,
    ageOnCard: ageOnCard,
    genderOnSheet: genderOnSheet,
    genderOnCard: genderOnCard,
    ageDifference: ageDifference,
    genderMismatch: genderMismatch,
  );
}
