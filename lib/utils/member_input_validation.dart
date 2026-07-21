import 'package:flutter/services.dart';

class MemberInputValidationResult {
  const MemberInputValidationResult({
    required this.isValid,
    this.errorText,
  });

  final bool isValid;
  final String? errorText;
}

class MemberBirthDateNormalizationResult {
  const MemberBirthDateNormalizationResult({
    required this.isValid,
    this.normalizedText,
    this.date,
    this.errorText,
  });

  final bool isValid;
  final String? normalizedText;
  final DateTime? date;
  final String? errorText;
}

String normalizeMemberPhone(String value) {
  return value.replaceAll(RegExp(r'[^0-9]'), '');
}

String formatKoreanMobilePhone(String value) {
  final digits = normalizeMemberPhone(value);

  if (digits.isEmpty) return '';

  if (digits.length <= 3) {
    return digits;
  }

  if (digits.length <= 6) {
    return '${digits.substring(0, 3)}-${digits.substring(3)}';
  }

  if (digits.length <= 10) {
    return '${digits.substring(0, 3)}-'
        '${digits.substring(3, 6)}-'
        '${digits.substring(6)}';
  }

  final cut = digits.substring(0, 11);

  return '${cut.substring(0, 3)}-'
      '${cut.substring(3, 7)}-'
      '${cut.substring(7)}';
}

bool isKoreanMobilePhonePrefix(String digits) {
  return digits.startsWith('010') ||
      digits.startsWith('011') ||
      digits.startsWith('016') ||
      digits.startsWith('017') ||
      digits.startsWith('018') ||
      digits.startsWith('019');
}

MemberInputValidationResult validateKoreanMobilePhone(
  String value, {
  bool required = true,
}) {
  final phone = normalizeMemberPhone(value);

  if (phone.isEmpty) {
    return MemberInputValidationResult(
      isValid: !required,
      errorText: required ? '휴대폰 번호를 입력해주세요.' : null,
    );
  }

  if (phone.length != 10 && phone.length != 11) {
    return const MemberInputValidationResult(
      isValid: false,
      errorText: '휴대폰 번호는 숫자 10~11자리로 입력해주세요.',
    );
  }

  if (!isKoreanMobilePhonePrefix(phone)) {
    return const MemberInputValidationResult(
      isValid: false,
      errorText: '휴대폰 번호는 010 등 이동전화 번호로 입력해주세요.',
    );
  }

  return const MemberInputValidationResult(isValid: true);
}

DateTime? parseMemberBirthDate(String value) {
  final text = value.trim();

  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (match == null) return null;

  final year = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  final day = int.tryParse(match.group(3) ?? '');

  if (year == null || month == null || day == null) return null;

  final date = DateTime(year, month, day);

  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }

  return date;
}

MemberBirthDateNormalizationResult normalizeAndValidateMemberBirthDate(
  String value, {
  bool required = false,
  int minAge = 4,
  int maxAgeExclusive = 100,
  DateTime? now,
}) {
  final text = value.trim();

  if (text.isEmpty) {
    return MemberBirthDateNormalizationResult(
      isValid: !required,
      normalizedText: '',
      errorText: required ? '생년월일을 입력해주세요.' : null,
    );
  }

  DateTime? exactDate(int year, int month, int day) {
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  final candidates = <DateTime>[];
  final separated = RegExp(
    r'^(\d{4})[.\-/](\d{1,2})[.\-/](\d{1,2})$',
  ).firstMatch(text);

  if (separated != null) {
    final year = int.parse(separated.group(1)!);
    final month = int.parse(separated.group(2)!);
    final day = int.parse(separated.group(3)!);
    final date = exactDate(year, month, day);
    if (date != null) candidates.add(date);
  } else if (RegExp(r'^[\d.\-/]+$').hasMatch(text)) {
    final digits = text.replaceAll(RegExp(r'\D'), '');
    final year = digits.length >= 4 ? int.parse(digits.substring(0, 4)) : 0;

    if (digits.length == 8) {
      final date = exactDate(
        year,
        int.parse(digits.substring(4, 6)),
        int.parse(digits.substring(6, 8)),
      );
      if (date != null) candidates.add(date);
    } else if (digits.length == 7) {
      final monthOneDigit = exactDate(
        year,
        int.parse(digits.substring(4, 5)),
        int.parse(digits.substring(5, 7)),
      );
      final monthTwoDigits = exactDate(
        year,
        int.parse(digits.substring(4, 6)),
        int.parse(digits.substring(6, 7)),
      );
      if (monthOneDigit != null) candidates.add(monthOneDigit);
      if (monthTwoDigits != null && monthTwoDigits != monthOneDigit) {
        candidates.add(monthTwoDigits);
      }
    } else if (digits.length == 6) {
      final date = exactDate(
        year,
        int.parse(digits.substring(4, 5)),
        int.parse(digits.substring(5, 6)),
      );
      if (date != null) candidates.add(date);
    }
  }

  if (candidates.length > 1) {
    return const MemberBirthDateNormalizationResult(
      isValid: false,
      errorText: '생년월일을 확인해주세요.',
    );
  }

  if (candidates.isEmpty) {
    return const MemberBirthDateNormalizationResult(
      isValid: false,
      errorText: '생년월일을 확인해주세요.',
    );
  }

  final date = candidates.single;
  final today = now ?? DateTime.now();
  final currentDate = DateTime(today.year, today.month, today.day);

  if (date.isAfter(currentDate)) {
    return const MemberBirthDateNormalizationResult(
      isValid: false,
      errorText: '생년월일은 오늘 이후일 수 없어요.',
    );
  }

  if (date.year < 1900) {
    return const MemberBirthDateNormalizationResult(
      isValid: false,
      errorText: '생년월일을 다시 확인해주세요.',
    );
  }

  final age = ageFromBirthDate(date, currentDate);

  if (age < minAge) {
    return const MemberBirthDateNormalizationResult(
      isValid: false,
      errorText: '만 3세 이하는 등록하기 어려워요. 생년월일을 확인해주세요.',
    );
  }

  if (age >= maxAgeExclusive) {
    return const MemberBirthDateNormalizationResult(
      isValid: false,
      errorText: '만 100세 이상은 생년월일을 다시 확인해주세요.',
    );
  }

  final normalizedText = '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  return MemberBirthDateNormalizationResult(
    isValid: true,
    normalizedText: normalizedText,
    date: date,
  );
}

int ageFromBirthDate(DateTime birthDate, DateTime now) {
  var age = now.year - birthDate.year;

  final birthdayPassed = now.month > birthDate.month ||
      (now.month == birthDate.month && now.day >= birthDate.day);

  if (!birthdayPassed) {
    age -= 1;
  }

  return age;
}

String? memberAgeLabelFromBirthText(String value) {
  final date = parseMemberBirthDate(value);
  if (date == null) return null;

  final age = ageFromBirthDate(date, DateTime.now());
  if (age < 0) return null;

  return '만 $age세';
}

MemberInputValidationResult validateMemberBirthDate(
  String value, {
  bool required = false,
  int minAge = 4,
  int maxAgeExclusive = 100,
}) {
  final result = normalizeAndValidateMemberBirthDate(
    value,
    required: required,
    minAge: minAge,
    maxAgeExclusive: maxAgeExclusive,
  );

  return MemberInputValidationResult(
    isValid: result.isValid,
    errorText: result.errorText,
  );
}

class MemberPhoneInputFormatter extends TextInputFormatter {
  const MemberPhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = formatKoreanMobilePhone(newValue.text);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class MemberBirthDateInputFormatter extends TextInputFormatter {
  const MemberBirthDateInputFormatter();

  static const int _maxDigits = 8;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length > _maxDigits) {
      digits = digits.substring(0, _maxDigits);
    }

    final safeSelectionOffset =
        newValue.selection.baseOffset.clamp(0, newValue.text.length).toInt();
    final digitsBeforeSelection = newValue.text
        .substring(0, safeSelectionOffset)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length
        .clamp(0, digits.length)
        .toInt();

    String text;

    if (digits.length <= 4) {
      text = digits;
    } else if (digits.length <= 6) {
      text = '${digits.substring(0, 4)}-${digits.substring(4)}';
    } else {
      text = '${digits.substring(0, 4)}-'
          '${digits.substring(4, 6)}-'
          '${digits.substring(6)}';
    }

    var formattedSelectionOffset = 0;
    var seenDigits = 0;
    while (formattedSelectionOffset < text.length &&
        seenDigits < digitsBeforeSelection) {
      if (RegExp(r'\d').hasMatch(text[formattedSelectionOffset])) {
        seenDigits += 1;
      }
      formattedSelectionOffset += 1;
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: formattedSelectionOffset),
    );
  }
}
