import 'package:flutter/services.dart' show TextEditingValue, TextSelection;
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/member_input_validation.dart';

void main() {
  group('MemberBirthDateInputFormatter', () {
    const formatter = MemberBirthDateInputFormatter();

    TextEditingValue format(String value, {String oldValue = ''}) {
      return formatter.formatEditUpdate(
        TextEditingValue(
          text: oldValue,
          selection: TextSelection.collapsed(offset: oldValue.length),
        ),
        TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        ),
      );
    }

    test('8자리 숫자를 입력 중 날짜 모양으로 표시한다', () {
      expect(format('2').text, '2');
      expect(format('2005').text, '2005');
      expect(format('20051').text, '2005-1');
      expect(format('200511').text, '2005-11');
      expect(format('2005111').text, '2005-11-1');
      expect(format('20051111').text, '2005-11-11');
    });

    test('8자리를 넘는 숫자는 첫 8자리까지만 유지한다', () {
      expect(format('200511111111').text, '2005-11-11');
      expect(format('2005-11-111').text, '2005-11-11');
    });

    test('점과 슬래시가 있는 붙여넣기도 숫자 8자리 기준으로 표시한다', () {
      expect(format('2005.11.11').text, '2005-11-11');
      expect(format('2005/11/11').text, '2005-11-11');
    });

    test('끝에서 백스페이스로 날짜 숫자를 자연스럽게 지운다', () {
      final result = format('2005-11-1', oldValue: '2005-11-11');

      expect(result.text, '2005-11-1');
      expect(result.selection.baseOffset, result.text.length);
    });
  });

  group('normalizeAndValidateMemberBirthDate', () {
    final now = DateTime(2026, 7, 12);

    void expectNormalized(String input, String expected) {
      final result = normalizeAndValidateMemberBirthDate(
        input,
        required: true,
        now: now,
      );

      expect(result.isValid, isTrue);
      expect(result.normalizedText, expected);
    }

    test('8자리 날짜를 정규화한다', () {
      expectNormalized('19990705', '1999-07-05');
    });

    test('한 자리 월과 일을 포함한 6자리 날짜를 정규화한다', () {
      expectNormalized('199975', '1999-07-05');
      expectNormalized('1999-75', '1999-07-05');
    });

    test('유일하게 해석할 수 없는 6자리 값은 변환하지 않는다', () {
      final result = normalizeAndValidateMemberBirthDate(
        '200510',
        required: true,
        now: now,
      );

      expect(result.isValid, isFalse);
      expect(result.normalizedText, isNull);

      final formattedResult = normalizeAndValidateMemberBirthDate(
        '2005-10',
        required: true,
        now: now,
      );
      expect(formattedResult.isValid, isFalse);
    });

    test('두 날짜로 해석되는 7자리 값은 거부한다', () {
      final result = normalizeAndValidateMemberBirthDate(
        '1999125',
        required: true,
        now: now,
      );

      expect(result.isValid, isFalse);
      expect(result.errorText, '생년월일을 확인해주세요.');
    });

    test('한 날짜만 유효한 7자리 값은 정규화한다', () {
      expectNormalized('1999131', '1999-01-31');
    });

    test('윤년의 2월 29일은 허용한다', () {
      expectNormalized('20000229', '2000-02-29');
    });

    test('윤년이 아닌 해의 2월 29일은 거부한다', () {
      final result = normalizeAndValidateMemberBirthDate(
        '20010229',
        required: true,
        now: now,
      );

      expect(result.isValid, isFalse);
    });

    test('미래 날짜는 거부한다', () {
      final result = normalizeAndValidateMemberBirthDate(
        '20990101',
        required: true,
        now: now,
      );

      expect(result.isValid, isFalse);
      expect(result.errorText, '생년월일은 오늘 이후일 수 없어요.');
    });

    test('점과 슬래시 구분자가 있는 날짜를 정규화한다', () {
      expectNormalized('1999.7.5', '1999-07-05');
      expectNormalized('1999/7/5', '1999-07-05');
    });
  });
}
