import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/client_card_page.dart';

void main() {
  test('회원권 안내 이름은 님을 한 번만 붙인다', () {
    expect(membershipMemberLabel('김유리'), '김유리님');
    expect(membershipMemberLabel(' 김유리님 '), '김유리님');
    expect(membershipMemberLabel('김유리 님'), '김유리님');
    expect(membershipMemberLabel(''), '회원님');
  });
}
