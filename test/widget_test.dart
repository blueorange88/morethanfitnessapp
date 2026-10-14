import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/korean_search_utils.dart';

void main() {
  group('matchesSmartMemberSearch', () {
    const targets = ['김민수', '010-1234-5678'];

    test('이름의 일부로 회원을 찾는다', () {
      expect(
        matchesSmartMemberSearch(rawQuery: '민수', targets: targets),
        isTrue,
      );
    });

    test('한글 초성으로 회원을 찾는다', () {
      expect(
        matchesSmartMemberSearch(rawQuery: 'ㄱㅁㅅ', targets: targets),
        isTrue,
      );
    });

    test('구분자를 제외한 전화번호 숫자로 회원을 찾는다', () {
      expect(
        matchesSmartMemberSearch(rawQuery: '12345678', targets: targets),
        isTrue,
      );
    });

    test('일치하지 않는 검색어는 회원을 찾지 않는다', () {
      expect(
        matchesSmartMemberSearch(rawQuery: '이영희', targets: targets),
        isFalse,
      );
    });
  });
}
