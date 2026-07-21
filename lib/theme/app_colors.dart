import 'package:flutter/material.dart';

// ============================================================
//  AppColors — 모어댄 색상 시스템
//  Light : 블루→퍼플 그라데이션 / 흰 배경 / 파스텔 칩
//  Dark  : 베이지→골드 그라데이션 / 네이비 배경 / 골드 틴트 칩
// ============================================================

class AppColors {
  AppColors._();

  // ── 브랜드 기본 ─────────────────────────────────────────
  static const Color navy = Color(0xFF0D1B2A);
  static const Color gold = Color(0xFFD4AF37);
  static const Color offWhite = Color(0xFFF5F0E8);

  // ── Light 헤더/버튼 그라데이션 ──────────────────────────
  static const Color lightGradientStart = Color(0xFF4F46E5); // 블루
  static const Color lightGradientEnd = Color(0xFF9333EA); // 퍼플

  // ── Dark 헤더/버튼 그라데이션 ───────────────────────────
  static const Color darkGradientStart = Color(0xFFC8A84E); // 밝은 골드
  static const Color darkGradientEnd = Color(0xFF8B6914); // 딥 골드

  // ── 프리미엄 배너 그라데이션 (공통) ─────────────────────
  static const Color proGradientStart = Color(0xFFFBBF24); // 앰버
  static const Color proGradientEnd = Color(0xFFF97316); // 오렌지

  // ── Light 배경 ──────────────────────────────────────────
  static const Color lightBg = Color(0xFFF8F9FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF9FAFB); // 입력 필드
  static const Color lightBorder = Color(0xFFE5E7EB);
  static const Color lightBorderFocus = Color(0xFFC7D2FE);

  // ── Light 텍스트 ────────────────────────────────────────
  static const Color lightTextPrimary = Color(0xFF111827);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightTextTertiary = Color(0xFF9CA3AF);
  static const Color lightTextHint = Color(0xFFC4C9D4);

  // ── Dark 배경 ───────────────────────────────────────────
  static const Color darkBg = Color(0xFF0D1526);
  static const Color darkSurface = Color(0xFF152040);
  static const Color darkSurface2 = Color(0xFF1A2444); // 입력 필드
  static const Color darkBorder = Color(0xFF1F3060);

  // ── Dark 텍스트 ─────────────────────────────────────────
  static const Color darkTextPrimary = Color(0xFFE8F0FF);
  static const Color darkTextSecondary = Color(0xFF6B7A9F);
  static const Color darkTextTertiary = Color(0xFF3A4A6A);

  // ── 골드 팔레트 (Dark 전용) ─────────────────────────────
  static const Color goldDeep = Color(0xFF5A3E00);
  static const Color goldMid = Color(0xFF8B6914);
  static const Color goldBase = Color(0xFFC8A84E);
  static const Color goldLight = Color(0xFFD4BF7A);
  static const Color goldCream = Color(0xFFFFF0C0); // 헤더 텍스트

  // ── 수업 타입 색상 ──────────────────────────────────────
  // 블럭(진함) / 칩 배경(파스텔) / 칩 텍스트(중간)
  // → 세 가지가 동일 계열이라 칩 선택 시 블럭과 색이 자연스럽게 연결됨

  static const Color lessonPt = Color(0xFF4F46E5);
  static const Color lessonPtLight = Color(0xFFEEF2FF);
  static const Color lessonPtText = Color(0xFF3730A3);

  static const Color lessonPilates = Color(0xFF7C3AED);
  static const Color lessonPilatesLight = Color(0xFFF5F3FF);
  static const Color lessonPilatesText = Color(0xFF5B21B6);

  static const Color lessonGroup = Color(0xFFEA580C);
  static const Color lessonGroupLight = Color(0xFFFFF7ED);
  static const Color lessonGroupText = Color(0xFFC2410C);

  static const Color lessonOt = Color(0xFF2563EB);
  static const Color lessonOtLight = Color(0xFFEFF6FF);
  static const Color lessonOtText = Color(0xFF1D4ED8);

  static const Color lessonRehab = Color(0xFF059669);
  static const Color lessonRehabLight = Color(0xFFF0FDF4);
  static const Color lessonRehabText = Color(0xFF166534);

  // ── 수업 상태 dot 색상 ───────────────────────────────────
  // dot + 텍스트 방식 — 배경 없음

  static const Color statusOngoingDot = Color(0xFF3B82F6);
  static const Color statusOngoingLight = Color(0xFF2563EB); // Light 텍스트
  static const Color statusOngoingDark = Color(0xFF60A5FA); // Dark 텍스트

  static const Color statusDoneDot = Color(0xFF10B981);
  static const Color statusDoneLight = Color(0xFF059669);
  static const Color statusDoneDark = Color(0xFF34D399);

  static const Color statusNoshowDot = Color(0xFFEF4444);
  static const Color statusNoshowLight = Color(0xFFDC2626);
  static const Color statusNoshowDark = Color(0xFFF87171);

  static const Color statusReadyDot = Color(0xFFD1D5DB);
  static const Color statusReadyLight = Color(0xFF6B7280);
  static const Color statusReadyDark = Color(0xFF4A5A80);

  // ── 파스텔 칩 (Light 전용) ──────────────────────────────
  static const Color pastelBlue = Color(0xFFE0E7FF);
  static const Color pastelBlueText = Color(0xFF3730A3);
  static const Color pastelPurple = Color(0xFFEDE9FE);
  static const Color pastelPurpleText = Color(0xFF5B21B6);
  static const Color pastelMint = Color(0xFFD1FAE5);
  static const Color pastelMintText = Color(0xFF065F46);
  static const Color pastelPeach = Color(0xFFFEE2E2);
  static const Color pastelPeachText = Color(0xFF991B1B);
  static const Color pastelYellow = Color(0xFFFEF3C7);
  static const Color pastelYellowText = Color(0xFF92400E);

  // ── 다크 틴트 칩 (Dark 전용) ────────────────────────────
  static const Color darkChipGoldBg = Color(0xFF1F1600);
  static const Color darkChipGoldText = Color(0xFFD4AF62);
  static const Color darkChipGoldBorder = Color(0xFF5A3E00);

  static const Color darkChipGreenBg = Color(0xFF0A1F0F);
  static const Color darkChipGreenText = Color(0xFF4ADE80);
  static const Color darkChipGreenBorder = Color(0xFF0D4020);

  static const Color darkChipRedBg = Color(0xFF1F0A00);
  static const Color darkChipRedText = Color(0xFFFB923C);
  static const Color darkChipRedBorder = Color(0xFF5A2000);

  static const Color darkChipMutedBg = Color(0xFF111C30);
  static const Color darkChipMutedText = Color(0xFF4A5A80);
  static const Color darkChipMutedBorder = Color(0xFF1A2840);

  // ── 토스트 아이콘 배경 (시맨틱) ─────────────────────────
  static const Color toastIconSaveBg = Color(0xFFEEF2FF);
  static const Color toastIconSaveText = Color(0xFF4338CA);
  static const Color toastIconDoneBg = Color(0xFFD1FAE5);
  static const Color toastIconDoneText = Color(0xFF065F46);
  static const Color toastIconErrorBg = Color(0xFFFEE2E2);
  static const Color toastIconErrorText = Color(0xFF991B1B);
  static const Color toastIconWarnBg = Color(0xFFFEF3C7);
  static const Color toastIconWarnText = Color(0xFF92400E);

  // ── 버튼 텍스트 ─────────────────────────────────────────
  static const Color btnPrimaryTextLight = Color(0xFFFFFFFF);
  static const Color btnPrimaryTextDark = Color(0xFF1C1000); // 골드 위 대비

  // ── 글래스 오버레이 ─────────────────────────────────────
  static const Color glassBg = Color(0x22FFFFFF);
  static const Color glassBorder = Color(0x33FFFFFF);
  static const Color glassShine = Color(0x2DFFFFFF); // 상단 반사

  // ── 스케줄러 ────────────────────────────────────────────
  static const Color schedulerNowLine = Color(0xFFEF4444);
  static const Color schedulerTodayTint = Color(0x1AFBBF24);
  static const double schedulerDoneOpacity = 0.55;

  // ── 잔여 회차 경고 ──────────────────────────────────────
  static const Color sessionWarnAmber = Color(0xFFFBBF24); // 10회 이하
  static const Color sessionWarnRed = Color(0xFFEF4444); // 5회 이하
  static const Color sessionEmpty = Color(0xFF9CA3AF); // 0회

  // _buildLessonEditorHeader 에서 사용하는 상태 텍스트색 별칭
  static const Color statusReadyText = lightTextSecondary; // Color(0xFF6B7280)
  static const Color statusOngoingText = Color(0xFF2563EB);
  static const Color statusDoneText = Color(0xFF059669);
  static const Color statusNoshowText = Color(0xFFDC2626);

  // ── 헬퍼 메서드 ─────────────────────────────────────────

  /// 수업 타입명 → 스케줄러 블럭 배경색
  /// colorHex 가 있으면 그걸 우선 사용 (기존 커스텀 타입 호환)
  static Color lessonBlockColor(String typeName, {String? colorHex}) {
    if (colorHex != null && colorHex.isNotEmpty) {
      final hex = colorHex.trim().replaceFirst('#', '');
      final val = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
      if (val != null) return Color(val);
    }
    switch (typeName.trim()) {
      case 'PT수업':
      case 'PT':
        return lessonPt;
      case '필라테스':
        return lessonPilates;
      case '그룹수업':
      case '그룹':
        return lessonGroup;
      case 'OT상담':
      case '상담':
      case 'OT':
        return lessonOt;
      case '재활수업':
      case '재활':
        return lessonRehab;
      default:
        return lessonPt;
    }
  }

  /// 수업 타입명 → 칩 배경색 (Light)
  static Color lessonChipBg(String typeName, {String? colorHex}) {
    if (colorHex != null && colorHex.isNotEmpty) {
      final block = lessonBlockColor(typeName, colorHex: colorHex);
      return block.withOpacity(0.12);
    }
    switch (typeName.trim()) {
      case 'PT수업':
      case 'PT':
        return lessonPtLight;
      case '필라테스':
        return lessonPilatesLight;
      case '그룹수업':
      case '그룹':
        return lessonGroupLight;
      case 'OT상담':
      case '상담':
      case 'OT':
        return lessonOtLight;
      case '재활수업':
      case '재활':
        return lessonRehabLight;
      default:
        return lessonPtLight;
    }
  }

  /// 수업 타입명 → 칩 텍스트색 (Light)
  static Color lessonChipText(String typeName, {String? colorHex}) {
    if (colorHex != null && colorHex.isNotEmpty) {
      return lessonBlockColor(typeName, colorHex: colorHex);
    }
    switch (typeName.trim()) {
      case 'PT수업':
      case 'PT':
        return lessonPtText;
      case '필라테스':
        return lessonPilatesText;
      case '그룹수업':
      case '그룹':
        return lessonGroupText;
      case 'OT상담':
      case '상담':
      case 'OT':
        return lessonOtText;
      case '재활수업':
      case '재활':
        return lessonRehabText;
      default:
        return lessonPtText;
    }
  }

  /// 잔여 회차 → 경고 색상
  static Color sessionCountColor(int remaining) {
    if (remaining <= 0) return sessionEmpty;
    if (remaining <= 5) return sessionWarnRed;
    if (remaining <= 10) return sessionWarnAmber;
    return lightTextSecondary;
  }

  // ── 그라데이션 상수 ──────────────────────────────────────

  static const LinearGradient lightHeaderGradient = LinearGradient(
    colors: [lightGradientStart, lightGradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient darkHeaderGradient = LinearGradient(
    colors: [darkGradientStart, darkGradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient proGradient = LinearGradient(
    colors: [proGradientStart, proGradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ============================================================
//  ThemeData
// ============================================================

ThemeData lightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.lightGradientStart,
    brightness: Brightness.light,
    primary: AppColors.lightGradientStart,
    secondary: AppColors.lightGradientEnd,
    surface: AppColors.lightSurface,
    background: AppColors.lightBg,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.lightBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightSurface,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.lightBorder, width: 0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.lightBorder, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.lightBorder, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: AppColors.lightGradientStart, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.lightTextHint, fontSize: 12),
      labelStyle:
          const TextStyle(color: AppColors.lightTextSecondary, fontSize: 12),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: AppColors.lightGradientStart,
      unselectedItemColor: AppColors.lightTextTertiary,
      backgroundColor: AppColors.lightSurface,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.lightTextPrimary),
      bodyMedium: TextStyle(color: AppColors.lightTextPrimary),
      bodySmall: TextStyle(color: AppColors.lightTextSecondary),
    ),
  );
}

ThemeData darkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    brightness: Brightness.dark,
    primary: AppColors.goldBase,
    secondary: AppColors.goldBase,
    surface: AppColors.darkSurface,
    background: AppColors.darkBg,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.darkBg,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.darkBorder, width: 0.5),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.darkBorder, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.darkBorder, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.goldBase, width: 1.5),
      ),
      hintStyle:
          const TextStyle(color: AppColors.darkTextTertiary, fontSize: 12),
      labelStyle:
          const TextStyle(color: AppColors.darkTextSecondary, fontSize: 12),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: AppColors.goldBase,
      unselectedItemColor: AppColors.darkTextTertiary,
      backgroundColor: AppColors.darkSurface,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.darkTextPrimary),
      bodyMedium: TextStyle(color: AppColors.darkTextPrimary),
      bodySmall: TextStyle(color: AppColors.darkTextSecondary),
    ),
  );
}

// ============================================================
//  SharedPreferences 키
// ============================================================

class PrefKeys {
  PrefKeys._();
  static const String darkMode = 'pref_dark_mode';
}
