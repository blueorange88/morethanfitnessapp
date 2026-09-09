String normalizeAifcNickname(String? value) {
  final trimmed = (value ?? '').trim();

  if (trimmed.isEmpty) {
    return '강사';
  }

  if (trimmed.endsWith('님')) {
    final cleaned = trimmed.substring(0, trimmed.length - 1).trim();
    return cleaned.isEmpty ? '강사' : cleaned;
  }

  return trimmed;
}

bool _isAlreadyRespectfulNickname(String value) {
  final trimmed = value.trim();

  if (trimmed.isEmpty) return false;

  return trimmed.endsWith('쌤') ||
      trimmed.endsWith('샘') ||
      trimmed.endsWith('선생님') ||
      trimmed.endsWith('강사님') ||
      trimmed.endsWith('코치님') ||
      trimmed.endsWith('트레이너님') ||
      trimmed.endsWith('대표님') ||
      trimmed.endsWith('원장님') ||
      trimmed.endsWith('관장님');
}

String aifcNicknameLabel(String? value) {
  final raw = (value ?? '').trim();

  if (raw.isEmpty) {
    return '강사님';
  }

  if (_isAlreadyRespectfulNickname(raw)) {
    return raw;
  }

  final normalized = normalizeAifcNickname(raw);

  if (_isAlreadyRespectfulNickname(normalized)) {
    return normalized;
  }

  return '$normalized님';
}

String aifcPersonLabel(String? value, {String fallback = '회원'}) {
  final clean = (value ?? '').trim();

  if (clean.isEmpty) {
    return '$fallback님';
  }

  if (clean.endsWith('님') ||
      clean.endsWith('쌤') ||
      clean.endsWith('샘') ||
      clean.endsWith('선생님') ||
      clean.endsWith('대표님') ||
      clean.endsWith('원장님') ||
      clean.endsWith('관장님')) {
    return clean;
  }

  return '$clean님';
}