// lib/utils/color_util.dart
import 'package:flutter/material.dart';

class ColorUtil {
  static const _palette = <Color>[
    Color(0xFF6B5BD2),
    Color(0xFF60A5FA),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFFEC4899),
    Color(0xFF22C55E),
  ];

  static Color colorForName(String? name) {
    final s = name?.trim();
    if (s == null || s.isEmpty) return const Color(0xFF94A3B8);
    int h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _palette[h % _palette.length];
  }
}
