import 'package:flutter/material.dart';

class AifcColors {
  const AifcColors._();

  static const sheetBg = Color(0xFFF5F4FF);
  static const pageBg = Color(0xFFF8F7FF);

  static const primary = Color(0xFF4F46E5);
  static const userBubble = Color(0xFF4F46E5);
  static const secondary = Color(0xFF9333EA);
  static const blue = Color(0xFF38BDF8);

  static const fcBubbleBg = Color(0xFFFFFFFF);
  static const fcBubbleBorder = Color(0xFFE0DEFF);
  static const fcText = Color(0xFF1E1B4B);

  static const text = Color(0xFF111827);
  static const textMuted = Color(0xFF7C7ABB);
  static const textHint = Color(0xFFA5A3C8);

  static const cardBg = Color(0xFFFFFFFF);
  static const cardSoftBg = Color(0xFFF8F7FF);
  static const cardBorder = Color(0xFFE0DEFF);

  static const noShowDeducted = Color(0xFFDC2626);
  static const noShowNotDeducted = Color(0xFFEA580C);
  static const service = Color(0xFF059669);

  static const darkToast = Color(0xFF0F1020);

  static const danger = Color(0xFFDC2626);
  static const warning = Color(0xFFEA580C);
  static const success = Color(0xFF059669);
}

class AifcRadius {
  const AifcRadius._();

  static const double sheet = 28;
  static const double card = 22;
  static const double bubble = 16;
  static const double button = 14;
  static const double chip = 999;
}

class AifcText {
  const AifcText._();

  static const title = TextStyle(
    color: AifcColors.text,
    fontSize: 17,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.3,
  );

  static const body = TextStyle(
    color: AifcColors.fcText,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.52,
  );

  static const caption = TextStyle(
    color: AifcColors.textHint,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w900,
  );
}

class AifcShadow {
  const AifcShadow._();

  static List<BoxShadow> sheet = [
    BoxShadow(
      color: AifcColors.primary.withOpacity(0.14),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.10),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> soft = [
    BoxShadow(
      color: AifcColors.primary.withOpacity(0.06),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];
}