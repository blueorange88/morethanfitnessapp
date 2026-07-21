import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/personal_trainer_profile_validation.dart';

void main() {
  test('프리랜서는 직책 없이도 canonical 정보가 완료된다', () {
    final valid = <String, dynamic>{
      'realName': '김트레이너',
      'jobTitle': 'PT 트레이너',
      'primaryActivity': 'PT',
      'affiliationType': 'freelancer',
      'activityRegion': '서울특별시 강남구',
    };

    expect(isCanonicalTrainerProfileComplete(valid), isTrue);
    expect(
      isCanonicalTrainerProfileComplete({...valid, 'jobTitle': ''}),
      isTrue,
    );
    expect(
      isCanonicalTrainerProfileComplete({...valid, 'realName': 'ㄱㄱ'}),
      isFalse,
    );
    expect(
      isCanonicalTrainerProfileComplete({...valid, 'phone': ''}),
      isTrue,
    );
  });

  test('센터와 개인샵은 직책이 필수이며 이미 유효한 값은 완료된다', () {
    final base = <String, dynamic>{
      'realName': '김트레이너',
      'primaryActivity': 'PT',
      'activityRegions': ['서울특별시 강남구'],
    };
    for (final type in ['center', 'personal_shop']) {
      expect(
        isCanonicalTrainerProfileComplete({
          ...base,
          'affiliationType': type,
          'jobTitle': '',
        }),
        isFalse,
      );
      expect(
        isCanonicalTrainerProfileComplete({
          ...base,
          'affiliationType': type,
          'jobTitle': '트레이너',
        }),
        isTrue,
      );
    }
  });

  test('이름과 직업의 길이·문자 정책을 검증한다', () {
    expect(validateTrainerRealName(' 김   민수 '), isNull);
    expect(validateTrainerRealName('1234'), isNotNull);
    expect(validateTrainerRealName('ㄱㄱ'), isNotNull);
    expect(validateTrainerJobTitle('PT 트레이너'), isNull);
    expect(validateTrainerJobTitle('@@@'), isNotNull);
  });

  test('소속 형태와 시도·시군구 활동 지역을 검증한다', () {
    expect(isTrainerAffiliationType('center'), isTrue);
    expect(isTrainerAffiliationType('기타'), isFalse);
    expect(isTrainerActivityRegion('경기도 성남시'), isTrue);
    expect(isTrainerActivityRegion('서울'), isFalse);
  });

  test('소속별 입력 순서가 센터 계열과 프리랜서를 구분한다', () {
    expect(
      trainerProfileAffiliationFieldOrder('center'),
      ['centerName', 'centerLocation', 'jobTitle', 'primaryActivity'],
    );
    expect(
      trainerProfileAffiliationFieldOrder('personal_shop'),
      ['centerName', 'centerLocation', 'jobTitle', 'primaryActivity'],
    );
    expect(
      trainerProfileAffiliationFieldOrder('freelancer'),
      ['jobTitle', 'primaryActivity', 'optionalCenter'],
    );
  });

  test('활동 지역은 기존 단일값 호환과 최대 3곳·중복·형식을 검증한다', () {
    expect(
      normalizeTrainerActivityRegions(
        null,
        legacyActivityRegion: '서울특별시 강남구',
      ),
      ['서울특별시 강남구'],
    );
    expect(
      areTrainerActivityRegionsValid([
        '서울특별시 강남구',
        '서울특별시 송파구',
        '경기도 성남시',
      ]),
      isTrue,
    );
    expect(
      areTrainerActivityRegionsValid([
        '서울특별시 강남구',
        '서울특별시 강남구',
      ]),
      isFalse,
    );
    expect(
      areTrainerActivityRegionsValid([
        '서울특별시 강남구',
        '서울특별시 송파구',
        '경기도 성남시',
        '제주특별자치도 제주시',
      ]),
      isFalse,
    );
    expect(areTrainerActivityRegionsValid(['서울특별시 없는구']), isFalse);
  });

  test('영문 이름은 선택이며 영문·공백·하이픈·아포스트로피만 허용한다', () {
    for (final value in ['', 'Myeong Gu Nam', 'Ji-Won Kim', "O'Connor"]) {
      expect(validateTrainerEnglishName(value), isNull, reason: value);
    }
    for (final value in ['남명구', 'ㄴㅁㄱ', 'Myeong 구', 'Kim123', '---']) {
      expect(validateTrainerEnglishName(value), isNotNull, reason: value);
    }
    expect(normalizeTrainerEnglishName('  Myeong   Gu Nam  '), 'Myeong Gu Nam');
  });
}
