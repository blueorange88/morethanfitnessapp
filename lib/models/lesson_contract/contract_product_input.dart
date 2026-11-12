/// 마이페이지 `내 수업 상품` 입력 검사와 상품 만들기. 서버(`normalizeProductPresets`)와 같은 상한을 쓴다.
library;

import '../../utils/lesson_contract/lesson_contract_rules.dart';
import 'lesson_contract_form.dart';
import 'lesson_contract_settings.dart';

const int kContractProductMaxCount = 20;
const int kContractProductMaxNameLength = 40;
const int kContractProductMaxSessions = 200;
const int kContractProductMinMinutes = 10;
const int kContractProductMaxMinutes = 180;

/// 내 수업 상품 한 개의 입력 값을 검사한다. 칸 이름(`name`·`sessionCount`·`sessionMinutes`·
/// `paidAmount`·`listPrice`) → 오류 문구. 비어 있으면 저장할 수 있다.
///
/// [otherNames]는 같은 목록에 이미 있는 다른 상품 이름이다(수정 중인 상품 자신은 뺀다).
Map<String, String> validateContractProductInput({
  required String name,
  required int? sessionCount,
  required int? sessionMinutes,
  required int? paidAmount,
  int? listPrice,
  List<String> otherNames = const [],
}) {
  final errors = <String, String>{};
  final trimmed = name.trim();
  if (trimmed.isEmpty) {
    errors['name'] = '상품 이름을 입력해 주세요.';
  } else if (trimmed.length > kContractProductMaxNameLength) {
    errors['name'] = '상품 이름은 $kContractProductMaxNameLength자 이하로 입력해 주세요.';
  } else if (findForbiddenPhrase(trimmed) != null) {
    errors['name'] = '환불을 막거나 책임을 모두 면제하는 문구는 쓸 수 없어요.';
  } else if (otherNames.any((other) => _sameName(other, trimmed))) {
    errors['name'] = '같은 이름의 수업 상품이 이미 있어요.';
  }

  if (sessionCount == null ||
      sessionCount < 1 ||
      sessionCount > kContractProductMaxSessions) {
    errors['sessionCount'] = '총 횟수는 1~$kContractProductMaxSessions회로 입력해 주세요.';
  }
  if (sessionMinutes == null ||
      sessionMinutes < kContractProductMinMinutes ||
      sessionMinutes > kContractProductMaxMinutes) {
    errors['sessionMinutes'] =
        '1회 시간은 $kContractProductMinMinutes~$kContractProductMaxMinutes분으로 입력해 주세요.';
  }
  if (paidAmount == null ||
      paidAmount < 1 ||
      paidAmount > kContractMaxPaidAmount) {
    errors['paidAmount'] = '결제금액을 1원 이상 입력해 주세요.';
  }
  if (listPrice != null) {
    if (paidAmount != null &&
        (listPrice <= paidAmount || listPrice > kContractMaxListPrice)) {
      errors['listPrice'] = '정상가는 결제금액보다 커야 해요.';
    } else if (listPrice > kContractMaxListPrice) {
      errors['listPrice'] = '정상가가 너무 커요.';
    }
  }
  return errors;
}

bool _sameName(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

/// 검사를 통과한 입력으로 상품을 만든다. 서비스 내용은 계약서 입력 화면과 같은 문구로 자동 작성한다.
ContractProductPreset buildContractProductPreset({
  required String name,
  required int sessionCount,
  required int sessionMinutes,
  required int paidAmount,
  int? listPrice,
}) {
  final trimmed = name.trim();
  return ContractProductPreset(
    name: trimmed,
    serviceContent: '$trimmed (총 $sessionCount회, 1회 $sessionMinutes분)',
    sessionCount: sessionCount,
    sessionMinutes: sessionMinutes,
    paidAmount: paidAmount,
    listPrice: listPrice,
  );
}
