String normalizeTrainerProfileText(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String normalizeTrainerEnglishName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

String? validateTrainerEnglishName(String? value) {
  final text = normalizeTrainerEnglishName(value ?? '');
  if (text.isEmpty) return null;
  if (text.length < 2 || text.length > 40) {
    return '영문 이름은 2~40자로 입력해주세요.';
  }
  if (!RegExp(r'[A-Za-z]').hasMatch(text) ||
      !RegExp(r"^[A-Za-z '-]+$").hasMatch(text)) {
    return "영문, 공백, 하이픈(-), 아포스트로피(')만 입력해주세요.";
  }
  return null;
}

String? validateTrainerRealName(String? value) {
  final text = normalizeTrainerProfileText(value ?? '');
  if (text.isEmpty) return '이름을 입력해주세요.';
  if (text.length < 2 || text.length > 20) return '이름은 2~20자로 입력해주세요.';
  if (!RegExp(r'^[가-힣A-Za-z ]+$').hasMatch(text) ||
      RegExp(r'^[ㄱ-ㅎㅏ-ㅣ]+$').hasMatch(text)) {
    return '한글 또는 영문 이름을 확인해주세요.';
  }
  return null;
}

String? validateTrainerJobTitle(String? value) {
  final text = normalizeTrainerProfileText(value ?? '');
  if (text.isEmpty) return '직업을 선택하거나 입력해주세요.';
  if (text.length < 2 || text.length > 30) return '직업은 2~30자로 입력해주세요.';
  if (!RegExp(r'[가-힣A-Za-z0-9]').hasMatch(text) ||
      !RegExp(r'^[가-힣A-Za-z0-9 &/·._-]+$').hasMatch(text)) {
    return '직업을 확인해주세요.';
  }
  return null;
}

String? validatePrimaryActivity(String? value) {
  final text = normalizeTrainerProfileText(value ?? '');
  if (text.isEmpty) return '주 활동 종목을 입력해주세요.';
  if (text.length < 2 ||
      text.length > 30 ||
      !RegExp(r'[가-힣A-Za-z0-9]').hasMatch(text)) {
    return '주 활동 종목을 확인해주세요.';
  }
  return null;
}

const trainerAffiliationTypes = <String, String>{
  'freelancer': '프리랜서',
  'center': '센터 소속',
  'personal_shop': '개인샵',
};

enum TrainerAffiliationCategory { center, freelance, none }

TrainerAffiliationCategory trainerAffiliationCategory(String? value) {
  return switch ((value ?? '').trim()) {
    'center' || 'personal_shop' => TrainerAffiliationCategory.center,
    'freelancer' => TrainerAffiliationCategory.freelance,
    _ => TrainerAffiliationCategory.none,
  };
}

bool isTrainerJobTitleRequired(String? affiliationType) {
  return trainerAffiliationCategory(affiliationType) ==
      TrainerAffiliationCategory.center;
}

List<String> trainerProfileAffiliationFieldOrder(String? affiliationType) {
  return trainerAffiliationCategory(affiliationType) ==
          TrainerAffiliationCategory.center
      ? const ['centerName', 'centerLocation', 'jobTitle', 'primaryActivity']
      : const ['jobTitle', 'primaryActivity', 'optionalCenter'];
}

String? validateTrainerJobTitleForAffiliation(
  String? value,
  String? affiliationType,
) {
  final text = normalizeTrainerProfileText(value ?? '');
  if (text.isEmpty && !isTrainerJobTitleRequired(affiliationType)) return null;
  return validateTrainerJobTitle(text);
}

bool isTrainerAffiliationType(String? value) {
  return trainerAffiliationTypes.containsKey((value ?? '').trim());
}

bool isTrainerActivityRegion(String? value) {
  final text = normalizeTrainerProfileText(value ?? '');
  return text.length >= 4 &&
      text.length <= 40 &&
      text.contains(' ') &&
      RegExp(r'^[가-힣 ]+$').hasMatch(text);
}

const trainerActivityRegionOptions = <String, List<String>>{
  '서울특별시': [
    '강남구',
    '강동구',
    '강서구',
    '관악구',
    '광진구',
    '구로구',
    '노원구',
    '마포구',
    '서초구',
    '성동구',
    '송파구',
    '영등포구',
    '용산구',
    '종로구',
    '중구'
  ],
  '부산광역시': ['강서구', '금정구', '남구', '동래구', '부산진구', '북구', '수영구', '연제구', '해운대구'],
  '대구광역시': ['달서구', '달성군', '동구', '북구', '수성구', '중구'],
  '인천광역시': ['계양구', '남동구', '미추홀구', '부평구', '서구', '연수구'],
  '광주광역시': ['광산구', '남구', '동구', '북구', '서구'],
  '대전광역시': ['대덕구', '동구', '서구', '유성구', '중구'],
  '울산광역시': ['남구', '동구', '북구', '울주군', '중구'],
  '세종특별자치시': ['세종시'],
  '경기도': [
    '고양시',
    '광명시',
    '김포시',
    '남양주시',
    '부천시',
    '성남시',
    '수원시',
    '시흥시',
    '안산시',
    '안양시',
    '용인시',
    '의정부시',
    '파주시',
    '평택시',
    '하남시',
    '화성시'
  ],
  '강원특별자치도': ['강릉시', '속초시', '원주시', '춘천시'],
  '충청북도': ['제천시', '청주시', '충주시'],
  '충청남도': ['공주시', '아산시', '천안시'],
  '전북특별자치도': ['군산시', '익산시', '전주시'],
  '전라남도': ['광양시', '나주시', '목포시', '순천시', '여수시'],
  '경상북도': ['경산시', '경주시', '구미시', '안동시', '포항시'],
  '경상남도': ['거제시', '김해시', '양산시', '진주시', '창원시'],
  '제주특별자치도': ['서귀포시', '제주시'],
};

bool isKnownTrainerActivityRegion(String? value) {
  final text = normalizeTrainerProfileText(value ?? '');
  final separator = text.indexOf(' ');
  if (separator <= 0 || separator == text.length - 1) return false;
  final province = text.substring(0, separator);
  final district = text.substring(separator + 1);
  return trainerActivityRegionOptions[province]?.contains(district) == true;
}

List<String> normalizeTrainerActivityRegions(
  Object? values, {
  String? legacyActivityRegion,
}) {
  final candidates = <String>[
    if (values is Iterable) ...values.map((value) => value.toString()),
    if ((values is! Iterable || values.isEmpty) &&
        (legacyActivityRegion ?? '').trim().isNotEmpty)
      legacyActivityRegion!,
  ];
  final result = <String>[];
  for (final candidate in candidates) {
    final normalized = normalizeTrainerProfileText(candidate);
    if (normalized.isEmpty || result.contains(normalized)) continue;
    result.add(normalized);
    if (result.length == 3) break;
  }
  return result;
}

bool areTrainerActivityRegionsValid(Object? values) {
  if (values is! Iterable) return false;
  final raw = values.map((value) => value.toString()).toList();
  if (raw.isEmpty || raw.length > 3) return false;
  final normalized = raw.map(normalizeTrainerProfileText).toList();
  return normalized.toSet().length == normalized.length &&
      normalized.every(isKnownTrainerActivityRegion);
}

bool isCanonicalTrainerProfileComplete(Map<String, dynamic> profile) {
  final regions = normalizeTrainerActivityRegions(
    profile['activityRegions'],
    legacyActivityRegion: profile['activityRegion']?.toString(),
  );
  return validateTrainerRealName(profile['realName']?.toString()) == null &&
      validateTrainerJobTitleForAffiliation(
            profile['jobTitle']?.toString(),
            profile['affiliationType']?.toString(),
          ) ==
          null &&
      validatePrimaryActivity(profile['primaryActivity']?.toString()) == null &&
      isTrainerAffiliationType(profile['affiliationType']?.toString()) &&
      regions.isNotEmpty &&
      regions.every(isKnownTrainerActivityRegion);
}
