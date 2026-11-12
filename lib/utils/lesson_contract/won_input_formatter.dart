import 'package:flutter/services.dart';

import 'lesson_contract_rules.dart';

/// 금액 입력 칸: 숫자만 받고 세 자리마다 쉼표를 넣는다.
class WonInputFormatter extends TextInputFormatter {
  const WonInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final text = formatWon(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
