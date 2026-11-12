import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/inbody_scan.dart';

void main() {
  group('인바디 용지 글자 해석', () {
    test('한 줄에 라벨과 값이 있는 용지에서 측정값·키·나이·성별·측정일을 읽는다', () {
      final scan = parseInbodyText('''
InBody
ID 홍길동
키 171cm  나이 35세  성별 남성  측정일시 2026.10.01 09:12
체수분 | 40.2
체중 | 70.4
골격근량 | 31.2
체지방량 | 16.5
체지방률 | 23.4
''');

      expect(scan.height, '171');
      expect(scan.age, 35);
      expect(scan.gender, 'male');
      expect(scan.date, '2026.10.01');
      expect(scan.weight, '70.4');
      expect(scan.skeletalMuscle, '31.2');
      expect(scan.bodyFatKg, '16.5');
      expect(scan.bodyFatPercent, '23.4');
      expect(scan.hasAnyMeasurement, isTrue);
    });

    test('라벨과 값이 다른 줄로 나뉘어 인식돼도 값을 읽는다', () {
      final scan = parseInbodyText('''
체중
58.2
골격근량
22.1
체지방률
27.5
''');

      expect(scan.weight, '58.2');
      expect(scan.skeletalMuscle, '22.1');
      expect(scan.bodyFatPercent, '27.5');
    });

    test('값이 없는 라벨 다음 줄의 다른 항목 값을 가져오지 않는다', () {
      final scan = parseInbodyText('''
체중
골격근량
22.1
''');

      expect(scan.weight, '');
      expect(scan.skeletalMuscle, '22.1');
    });

    test('범위를 벗어난 숫자는 값으로 쓰지 않는다', () {
      final scan = parseInbodyText('''
체중 | 7040
골격근량 | 3
체지방률 | 150
''');

      expect(scan.weight, '');
      expect(scan.skeletalMuscle, '');
      expect(scan.bodyFatPercent, '');
    });

    test('체지방률 줄은 체지방량으로 읽지 않는다', () {
      final scan = parseInbodyText('체지방률 | 23.4');
      expect(scan.bodyFatKg, '');
      expect(scan.bodyFatPercent, '23.4');
    });

    test('여성과 영문 표기, 나이 라벨 형식을 읽는다', () {
      final scan = parseInbodyText('Age 29  Gender Female  Height 163.5 cm');
      expect(scan.age, 29);
      expect(scan.gender, 'female');
      expect(scan.height, '163.5');
    });

    test('아무것도 못 읽으면 빈 값이고 측정값이 없다고 알려준다', () {
      final scan = parseInbodyText('흐릿한 글자 abc');
      expect(scan.hasAnyMeasurement, isFalse);
      expect(scan.age, isNull);
      expect(scan.gender, isNull);
      expect(scan.date, '');
    });
  });

  group('만 나이', () {
    test('생일이 지났는지에 따라 달라진다', () {
      final birth = DateTime(1999, 11, 11);
      expect(internationalAge(birth, DateTime(2026, 11, 10)), 26);
      expect(internationalAge(birth, DateTime(2026, 11, 11)), 27);
      expect(internationalAge(null, DateTime(2026, 1, 1)), isNull);
    });
  });

  group('회원 본인 확인', () {
    const scan35Male = InbodyScanResult(age: 35, gender: 'male');
    final measuredAt = DateTime(2026, 10, 1);

    InbodyMemberCheck check({
      InbodyScanResult scan = scan35Male,
      DateTime? birth,
      String? gender,
    }) => verifyInbodyAgainstMember(
      scan: scan,
      cardBirthDate: birth,
      cardGender: gender,
      measuredAt: measuredAt,
    );

    test('나이와 성별이 같으면 일치', () {
      final result = check(birth: DateTime(1991, 3, 3), gender: '남');
      expect(result.status, InbodyMemberMatch.match);
      expect(result.ageOnCard, 35);
      expect(result.needsConfirmation, isFalse);
    });

    test('나이가 1살 다르면 가벼운 안내(근접 일치)', () {
      final result = check(birth: DateTime(1990, 3, 3), gender: '남');
      expect(result.status, InbodyMemberMatch.nearMatch);
      expect(result.ageDifference, 1);
      expect(result.needsConfirmation, isFalse);
    });

    test('나이가 2살 이상 다르면 다른 회원일 수 있다고 확인을 요구한다', () {
      final result = check(birth: DateTime(1999, 11, 11), gender: '남');
      expect(result.status, InbodyMemberMatch.mismatch);
      expect(result.ageDifference, 35 - 26);
      expect(result.needsConfirmation, isTrue);
    });

    test('성별이 다르면 나이가 같아도 불일치', () {
      final result = check(birth: DateTime(1991, 3, 3), gender: '여');
      expect(result.status, InbodyMemberMatch.mismatch);
      expect(result.genderMismatch, isTrue);
    });

    test('서버 성별 표기(male/female)도 같은 값으로 본다', () {
      expect(
        check(birth: DateTime(1991, 3, 3), gender: 'male').status,
        InbodyMemberMatch.match,
      );
      expect(inbodyGenderKey('female'), 'female');
      expect(inbodyGenderKey('미입력'), isNull);
    });

    test('용지에서 나이·성별을 못 읽었거나 카드에 값이 없으면 확인 불가', () {
      expect(
        check(
          scan: const InbodyScanResult(),
          birth: DateTime(1991, 3, 3),
          gender: '남',
        ).status,
        InbodyMemberMatch.unknown,
      );
      expect(
        check(birth: null, gender: null).status,
        InbodyMemberMatch.unknown,
      );
    });

    test('카드에 성별이 없어도 나이가 같으면 일치로 본다', () {
      final result = check(birth: DateTime(1991, 3, 3), gender: '미입력');
      expect(result.status, InbodyMemberMatch.match);
    });
  });
}
