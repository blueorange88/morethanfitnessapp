String normalizePhone(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

String digitsOnly(String value) {
  return value.replaceAll(RegExp(r'\D'), '');
}

const List<String> koreanChoseongTable = [
  'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ',
  'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', 'ㅆ', 'ㅇ',
  'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
];

String normalizeSearchText(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), '');
}

String choseongOfChar(String char) {
  if (char.isEmpty) return '';

  final code = char.codeUnitAt(0);

  if (code >= 0xAC00 && code <= 0xD7A3) {
    final index = ((code - 0xAC00) ~/ 588);
    return koreanChoseongTable[index];
  }

  if (koreanChoseongTable.contains(char)) {
    return char;
  }

  return char.toLowerCase();
}

String choseongText(String value) {
  final buffer = StringBuffer();

  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(choseongOfChar(char));
  }

  return buffer.toString();
}

bool matchesSmartMemberSearch({
  required String rawQuery,
  required List<String> targets,
}) {
  final query = normalizeSearchText(rawQuery);
  if (query.isEmpty) return true;

  final queryDigits = digitsOnly(query);

  for (final rawTarget in targets) {
    final target = normalizeSearchText(rawTarget);
    final targetChoseong = choseongText(target);
    final targetDigits = digitsOnly(target);

    if (target.contains(query)) return true;
    if (targetChoseong.contains(query)) return true;

    if (queryDigits.isNotEmpty && targetDigits.contains(queryDigits)) {
      return true;
    }
  }

  return false;
}