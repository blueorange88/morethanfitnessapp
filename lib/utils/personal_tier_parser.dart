String? parsePersonalTierLabel(Object? value) {
  final normalized = (value ?? '')
      .toString()
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_-]+'), '');

  switch (normalized) {
    case 'beginner':
      return 'Beginner';
    case 'amateur':
      return 'Amateur';
    case 'semipro':
      return 'Semi-Pro';
    case 'pro':
      return 'Pro';
    case 'master':
      return 'Master';
    case 'grandprix':
      return 'Grand Prix';
    default:
      return null;
  }
}
