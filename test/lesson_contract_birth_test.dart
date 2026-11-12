import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/lesson_contract/lesson_contract_form.dart';

void main() {
  final now = DateTime(2026, 10, 18);

  group('contractBirthDateFromCard', () {
    test('여러 저장 형식을 YYYY-MM-DD로 맞춘다', () {
      expect(contractBirthDateFromCard('1990-05-17', now: now), '1990-05-17');
      expect(contractBirthDateFromCard('1990.5.7', now: now), '1990-05-07');
      expect(contractBirthDateFromCard('1990. 5. 7.', now: now), '1990-05-07');
      expect(contractBirthDateFromCard('1990/05/17', now: now), '1990-05-17');
      expect(contractBirthDateFromCard('19900517', now: now), '1990-05-17');
    });

    test('날짜 값(Timestamp·DateTime)도 읽는다', () {
      expect(
        contractBirthDateFromCard(
          Timestamp.fromDate(DateTime(1988, 3, 2)),
          now: now,
        ),
        '1988-03-02',
      );
      expect(
        contractBirthDateFromCard(DateTime(1988, 3, 2), now: now),
        '1988-03-02',
      );
    });

    test('없거나 이상한 값은 빈 문자열', () {
      expect(contractBirthDateFromCard(null, now: now), '');
      expect(contractBirthDateFromCard('', now: now), '');
      expect(contractBirthDateFromCard('모름', now: now), '');
      expect(contractBirthDateFromCard('1990-02-31', now: now), '');
      expect(contractBirthDateFromCard('1850-01-01', now: now), '');
      expect(contractBirthDateFromCard('2030-01-01', now: now), '');
    });
  });

  group('contractBirthDateFromCardMap', () {
    test('birthDate·birth·birthday 순서로 찾는다', () {
      expect(
        contractBirthDateFromCardMap({'birthDate': '1990-05-17'}),
        '1990-05-17',
      );
      expect(
        contractBirthDateFromCardMap({'birth': '1990.5.17'}),
        '1990-05-17',
      );
      expect(
        contractBirthDateFromCardMap({'birthDate': '', 'birthday': '19900517'}),
        '1990-05-17',
      );
    });

    test('카드가 없거나 값이 없으면 빈 문자열', () {
      expect(contractBirthDateFromCardMap(null), '');
      expect(contractBirthDateFromCardMap({'name': '홍'}), '');
    });
  });
}
