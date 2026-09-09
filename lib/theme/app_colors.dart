import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================
//  AppColors — MORE THAN 브랜드 색상 시스템
//  일반 UI는 네이비·웜 옐로우를 사용하고 AIFC 퍼플은 별도 팔레트로 유지한다.
// ============================================================

class AppColors {
  AppColors._();

  // ── 브랜드 기본 ─────────────────────────────────────────
  static const Color navy = Color(0xFF0B1E32);
  static const Color deepNavy = navy;
  static const Color darkBackground = Color(0xFF071522);
  static const Color warmYellow = Color(0xFFEFCB62);
  static const Color warmIvory = Color(0xFFF7F5EF);
  static const Color gold = warmYellow;
  static const Color offWhite = warmIvory;

  // ── Lululala (기존 인디고·퍼플 라이트) ──────────────────
  static const Color lululalaPrimary = Color(0xFF4F46E5);
  static const Color lululalaSecondary = Color(0xFF9333EA);
  static const Color lululalaBackground = Color(0xFFF3F4F6);
  static const Color lululalaSurface = Color(0xFFFFFFFF);
  static const Color lululalaBorder = Color(0xFFE5E7EB);
  static const Color lululalaTextPrimary = Color(0xFF111827);
  static const Color lululalaTextSecondary = Color(0xFF6B7280);

  // ── Light 헤더/버튼 그라데이션 ──────────────────────────
  static const Color lightGradientStart = deepNavy;
  static const Color lightGradientEnd = Color(0xFF163A54);

  // ── Dark 헤더/버튼 그라데이션 ───────────────────────────
  static const Color darkGradientStart = Color(0xFF163A54);
  static const Color darkGradientEnd = darkBackground;

  // ── 프리미엄 배너 그라데이션 (공통) ─────────────────────
  static const Color proGradientStart = Color(0xFFFBBF24); // 앰버
  static const Color proGradientEnd = Color(0xFFF97316); // 오렌지

  // ── Light 배경 ──────────────────────────────────────────
  static const Color lightBg = warmIvory;
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE8E4DA);
  static const Color lightBorderFocus = warmYellow;

  // ── Light 텍스트 ────────────────────────────────────────
  static const Color lightTextPrimary = deepNavy;
  static const Color lightTextSecondary = Color(0xFF52606D);
  static const Color lightTextTertiary = Color(0xFF7B8794);
  static const Color lightTextHint = Color(0xFF9AA4AE);

  // ── Dark 배경 ───────────────────────────────────────────
  static const Color darkBg = darkBackground;
  static const Color darkSurface = Color(0xFF12283A);
  static const Color darkSurface2 = Color(0xFF1A3449);
  static const Color darkDialogSurface = Color(0xFF162E42);
  static const Color darkBorder = Color(0xFF294256);

  // ── Dark 텍스트 ─────────────────────────────────────────
  static const Color darkTextPrimary = Color(0xFFF7F4EA);
  static const Color darkTextSecondary = Color(0xFFB7C2CC);
  static const Color darkTextTertiary = Color(0xFF8192A0);

  // ── 골드 팔레트 (Dark 전용) ─────────────────────────────
  static const Color goldDeep = Color(0xFF5A3E00);
  static const Color goldMid = Color(0xFF8B6914);
  static const Color goldBase = warmYellow;
  static const Color goldLight = Color(0xFFF5DC98);
  static const Color goldCream = Color(0xFFFFF4CF);

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
      return block.withValues(alpha: 0.12);
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

  static const LinearGradient lululalaHeaderGradient = LinearGradient(
    colors: [lululalaPrimary, lululalaSecondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient proGradient = LinearGradient(
    colors: [proGradientStart, proGradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

@immutable
class MtfChartPalette extends ThemeExtension<MtfChartPalette> {
  const MtfChartPalette({
    required this.primarySeries,
    required this.secondarySeries,
    required this.tertiarySeries,
    required this.positiveSeries,
    required this.warningSeries,
    required this.negativeSeries,
    required this.gridLine,
    required this.axisText,
    required this.tooltipSurface,
  });

  static const light = MtfChartPalette(
    primarySeries: AppColors.deepNavy,
    secondarySeries: Color(0xFF2F6F89),
    tertiarySeries: AppColors.warmYellow,
    positiveSeries: Color(0xFF059669),
    warningSeries: Color(0xFFEA580C),
    negativeSeries: Color(0xFFDC2626),
    gridLine: AppColors.lightBorder,
    axisText: AppColors.lightTextSecondary,
    tooltipSurface: AppColors.deepNavy,
  );

  static const dark = MtfChartPalette(
    primarySeries: AppColors.warmYellow,
    secondarySeries: Color(0xFF69B4D0),
    tertiarySeries: Color(0xFFAFA2FF),
    positiveSeries: Color(0xFF59C99A),
    warningSeries: Color(0xFFF5A65B),
    negativeSeries: Color(0xFFF87171),
    gridLine: AppColors.darkBorder,
    axisText: AppColors.darkTextSecondary,
    tooltipSurface: AppColors.darkDialogSurface,
  );

  static const lululala = MtfChartPalette(
    primarySeries: AppColors.lululalaPrimary,
    secondarySeries: Color(0xFF06B6D4),
    tertiarySeries: AppColors.lululalaSecondary,
    positiveSeries: Color(0xFF10B981),
    warningSeries: Color(0xFFF97316),
    negativeSeries: Color(0xFFDC2626),
    gridLine: AppColors.lululalaBorder,
    axisText: AppColors.lululalaTextSecondary,
    tooltipSurface: Color(0xFF312E81),
  );

  final Color primarySeries;
  final Color secondarySeries;
  final Color tertiarySeries;
  final Color positiveSeries;
  final Color warningSeries;
  final Color negativeSeries;
  final Color gridLine;
  final Color axisText;
  final Color tooltipSurface;

  List<Color> get categoricalSeries => [
        primarySeries,
        secondarySeries,
        warningSeries,
        positiveSeries,
        tertiarySeries,
      ];

  @override
  MtfChartPalette copyWith({
    Color? primarySeries,
    Color? secondarySeries,
    Color? tertiarySeries,
    Color? positiveSeries,
    Color? warningSeries,
    Color? negativeSeries,
    Color? gridLine,
    Color? axisText,
    Color? tooltipSurface,
  }) {
    return MtfChartPalette(
      primarySeries: primarySeries ?? this.primarySeries,
      secondarySeries: secondarySeries ?? this.secondarySeries,
      tertiarySeries: tertiarySeries ?? this.tertiarySeries,
      positiveSeries: positiveSeries ?? this.positiveSeries,
      warningSeries: warningSeries ?? this.warningSeries,
      negativeSeries: negativeSeries ?? this.negativeSeries,
      gridLine: gridLine ?? this.gridLine,
      axisText: axisText ?? this.axisText,
      tooltipSurface: tooltipSurface ?? this.tooltipSurface,
    );
  }

  @override
  MtfChartPalette lerp(ThemeExtension<MtfChartPalette>? other, double t) {
    if (other is! MtfChartPalette) return this;
    return MtfChartPalette(
      primarySeries: Color.lerp(primarySeries, other.primarySeries, t)!,
      secondarySeries: Color.lerp(secondarySeries, other.secondarySeries, t)!,
      tertiarySeries: Color.lerp(tertiarySeries, other.tertiarySeries, t)!,
      positiveSeries: Color.lerp(positiveSeries, other.positiveSeries, t)!,
      warningSeries: Color.lerp(warningSeries, other.warningSeries, t)!,
      negativeSeries: Color.lerp(negativeSeries, other.negativeSeries, t)!,
      gridLine: Color.lerp(gridLine, other.gridLine, t)!,
      axisText: Color.lerp(axisText, other.axisText, t)!,
      tooltipSurface: Color.lerp(tooltipSurface, other.tooltipSurface, t)!,
    );
  }
}

@immutable
class MtfThemeTokens extends ThemeExtension<MtfThemeTokens> {
  const MtfThemeTokens({
    required this.memberListBackground,
    required this.memberListCard,
    required this.memberListCardBorder,
    required this.memberListSelected,
    required this.navigationSheetBackground,
    required this.navigationSelectedBackground,
    required this.lockedItemForeground,
    required this.drawerBackground,
    required this.drawerHeaderBackground,
    required this.drawerSelectedBackground,
    required this.sheetBackground,
    required this.dialogBackground,
    required this.gradeSheetAccent,
    required this.donationSurface,
    required this.donationAccent,
    required this.donationForeground,
    required this.donationProgress,
    required this.aifcBackground,
    required this.aifcSurface,
    required this.aifcUserBubble,
    required this.aifcUserBubbleForeground,
    required this.aifcInputSurface,
    required this.scheduleBackground,
    required this.scheduleGridLine,
    required this.scheduleHeaderBackground,
    required this.scheduleTimeText,
    required this.scheduleTodayHighlight,
    required this.scheduleEmptySlot,
    required this.scheduleSelectedBorder,
    required this.schedulerOuterSurface,
    required this.schedulerBorder,
    required this.schedulerCornerSurface,
    required this.cardSurface,
    required this.cardBorder,
    required this.trainingLogSurface,
    required this.trainingLogSetRow,
    required this.trainingLogSetDivider,
    required this.trainingLogCompleted,
    required this.contractDocumentSurface,
    required this.contractDocumentText,
    required this.contractDocumentBorder,
    required this.signatureCanvasSurface,
    required this.signatureStroke,
    required this.notificationCardSurface,
    required this.notificationLockedSurface,
    required this.widgetPreviewSurface,
    required this.widgetPreviewBorder,
  });

  static const light = MtfThemeTokens(
    memberListBackground: AppColors.lightBg,
    memberListCard: AppColors.lightSurface,
    memberListCardBorder: AppColors.lightBorder,
    memberListSelected: Color(0xFFFFF1C2),
    navigationSheetBackground: AppColors.lightSurface,
    navigationSelectedBackground: Color(0xFFFFF1C2),
    lockedItemForeground: AppColors.lightTextSecondary,
    drawerBackground: AppColors.lightSurface,
    drawerHeaderBackground: AppColors.deepNavy,
    drawerSelectedBackground: Color(0xFFFFF1C2),
    sheetBackground: AppColors.lightSurface,
    dialogBackground: AppColors.lightSurface,
    gradeSheetAccent: AppColors.warmYellow,
    donationSurface: Color(0xFFFFF3E2),
    donationAccent: Color(0xFFC9792B),
    donationForeground: AppColors.deepNavy,
    donationProgress: Color(0xFFE4A23A),
    aifcBackground: AppColors.warmIvory,
    aifcSurface: Color(0xFFF6F3FF),
    aifcUserBubble: AppColors.warmYellow,
    aifcUserBubbleForeground: AppColors.deepNavy,
    aifcInputSurface: AppColors.lightSurface,
    scheduleBackground: AppColors.lightSurface,
    scheduleGridLine: AppColors.lightBorder,
    scheduleHeaderBackground: AppColors.deepNavy,
    scheduleTimeText: AppColors.lightTextSecondary,
    scheduleTodayHighlight: Color(0xFFFFF1C2),
    scheduleEmptySlot: Color(0xFFFAF8F2),
    scheduleSelectedBorder: AppColors.warmYellow,
    schedulerOuterSurface: AppColors.lightSurface,
    schedulerBorder: AppColors.lightBorder,
    schedulerCornerSurface: AppColors.deepNavy,
    cardSurface: AppColors.lightSurface,
    cardBorder: AppColors.lightBorder,
    trainingLogSurface: AppColors.lightSurface,
    trainingLogSetRow: AppColors.lightSurface2,
    trainingLogSetDivider: AppColors.lightBorder,
    trainingLogCompleted: Color(0xFF059669),
    contractDocumentSurface: AppColors.warmIvory,
    contractDocumentText: AppColors.deepNavy,
    contractDocumentBorder: AppColors.lightBorder,
    signatureCanvasSurface: Colors.white,
    signatureStroke: AppColors.deepNavy,
    notificationCardSurface: AppColors.lightSurface,
    notificationLockedSurface: Color(0xFFF1EFE8),
    widgetPreviewSurface: AppColors.lightSurface2,
    widgetPreviewBorder: AppColors.lightBorder,
  );

  static const dark = MtfThemeTokens(
    memberListBackground: AppColors.darkBg,
    memberListCard: AppColors.darkSurface,
    memberListCardBorder: AppColors.darkBorder,
    memberListSelected: Color(0xFF4A401F),
    navigationSheetBackground: AppColors.darkDialogSurface,
    navigationSelectedBackground: Color(0xFF4A401F),
    lockedItemForeground: AppColors.darkTextSecondary,
    drawerBackground: AppColors.darkSurface,
    drawerHeaderBackground: AppColors.darkBg,
    drawerSelectedBackground: Color(0xFF4A401F),
    sheetBackground: AppColors.darkDialogSurface,
    dialogBackground: AppColors.darkDialogSurface,
    gradeSheetAccent: AppColors.warmYellow,
    donationSurface: Color(0xFF3A251B),
    donationAccent: Color(0xFFF2B45E),
    donationForeground: Color(0xFFFFF1DC),
    donationProgress: AppColors.warmYellow,
    aifcBackground: AppColors.darkDialogSurface,
    aifcSurface: AppColors.darkSurface2,
    aifcUserBubble: AppColors.warmYellow,
    aifcUserBubbleForeground: AppColors.deepNavy,
    aifcInputSurface: AppColors.darkSurface2,
    scheduleBackground: AppColors.darkSurface,
    scheduleGridLine: AppColors.darkBorder,
    scheduleHeaderBackground: AppColors.deepNavy,
    scheduleTimeText: AppColors.darkTextSecondary,
    scheduleTodayHighlight: Color(0xFF4A401F),
    scheduleEmptySlot: Color(0xFF10283A),
    scheduleSelectedBorder: AppColors.warmYellow,
    schedulerOuterSurface: AppColors.darkSurface,
    schedulerBorder: AppColors.darkBorder,
    schedulerCornerSurface: AppColors.deepNavy,
    cardSurface: AppColors.darkSurface,
    cardBorder: AppColors.darkBorder,
    trainingLogSurface: AppColors.darkSurface,
    trainingLogSetRow: AppColors.darkSurface2,
    trainingLogSetDivider: AppColors.darkBorder,
    trainingLogCompleted: Color(0xFF59C99A),
    contractDocumentSurface: AppColors.warmIvory,
    contractDocumentText: AppColors.deepNavy,
    contractDocumentBorder: Color(0xFFD8D2C4),
    signatureCanvasSurface: Colors.white,
    signatureStroke: AppColors.deepNavy,
    notificationCardSurface: AppColors.darkSurface,
    notificationLockedSurface: Color(0xFF10283A),
    widgetPreviewSurface: AppColors.darkSurface2,
    widgetPreviewBorder: AppColors.darkBorder,
  );

  static const lululala = MtfThemeTokens(
    memberListBackground: AppColors.lululalaBackground,
    memberListCard: AppColors.lululalaSurface,
    memberListCardBorder: AppColors.lululalaBorder,
    memberListSelected: Color(0xFFEEF2FF),
    navigationSheetBackground: AppColors.lululalaSurface,
    navigationSelectedBackground: Color(0xFFEEF2FF),
    lockedItemForeground: AppColors.lululalaTextSecondary,
    drawerBackground: AppColors.lululalaSurface,
    drawerHeaderBackground: AppColors.lululalaPrimary,
    drawerSelectedBackground: Color(0xFFEEF2FF),
    sheetBackground: AppColors.lululalaSurface,
    dialogBackground: AppColors.lululalaSurface,
    gradeSheetAccent: AppColors.lululalaPrimary,
    donationSurface: Color(0xFFFFF1E6),
    donationAccent: Color(0xFFE07A3F),
    donationForeground: Color(0xFF542B1B),
    donationProgress: Color(0xFFF59E0B),
    aifcBackground: Color(0xFFF5F4FF),
    aifcSurface: AppColors.lululalaSurface,
    aifcUserBubble: AppColors.lululalaPrimary,
    aifcUserBubbleForeground: Colors.white,
    aifcInputSurface: AppColors.lululalaSurface,
    scheduleBackground: AppColors.lululalaSurface,
    scheduleGridLine: AppColors.lululalaBorder,
    scheduleHeaderBackground: AppColors.lululalaPrimary,
    scheduleTimeText: AppColors.lululalaTextSecondary,
    scheduleTodayHighlight: Color(0x22FDE68A),
    scheduleEmptySlot: Color(0xFFF8FAFC),
    scheduleSelectedBorder: AppColors.lululalaPrimary,
    schedulerOuterSurface: AppColors.lululalaSurface,
    schedulerBorder: AppColors.lululalaBorder,
    schedulerCornerSurface: AppColors.lululalaPrimary,
    cardSurface: AppColors.lululalaSurface,
    cardBorder: AppColors.lululalaBorder,
    trainingLogSurface: AppColors.lululalaSurface,
    trainingLogSetRow: Color(0xFFF8FAFC),
    trainingLogSetDivider: AppColors.lululalaBorder,
    trainingLogCompleted: Color(0xFF059669),
    contractDocumentSurface: Color(0xFFFFFEFA),
    contractDocumentText: AppColors.lululalaTextPrimary,
    contractDocumentBorder: AppColors.lululalaBorder,
    signatureCanvasSurface: Colors.white,
    signatureStroke: AppColors.lululalaTextPrimary,
    notificationCardSurface: AppColors.lululalaSurface,
    notificationLockedSurface: Color(0xFFF1F2F6),
    widgetPreviewSurface: Color(0xFFF8FAFC),
    widgetPreviewBorder: AppColors.lululalaBorder,
  );

  final Color memberListBackground;
  final Color memberListCard;
  final Color memberListCardBorder;
  final Color memberListSelected;
  final Color navigationSheetBackground;
  final Color navigationSelectedBackground;
  final Color lockedItemForeground;
  final Color drawerBackground;
  final Color drawerHeaderBackground;
  final Color drawerSelectedBackground;
  final Color sheetBackground;
  final Color dialogBackground;
  final Color gradeSheetAccent;
  final Color donationSurface;
  final Color donationAccent;
  final Color donationForeground;
  final Color donationProgress;
  final Color aifcBackground;
  final Color aifcSurface;
  final Color aifcUserBubble;
  final Color aifcUserBubbleForeground;
  final Color aifcInputSurface;
  final Color scheduleBackground;
  final Color scheduleGridLine;
  final Color scheduleHeaderBackground;
  final Color scheduleTimeText;
  final Color scheduleTodayHighlight;
  final Color scheduleEmptySlot;
  final Color scheduleSelectedBorder;
  final Color schedulerOuterSurface;
  final Color schedulerBorder;
  final Color schedulerCornerSurface;
  final Color cardSurface;
  final Color cardBorder;
  final Color trainingLogSurface;
  final Color trainingLogSetRow;
  final Color trainingLogSetDivider;
  final Color trainingLogCompleted;
  final Color contractDocumentSurface;
  final Color contractDocumentText;
  final Color contractDocumentBorder;
  final Color signatureCanvasSurface;
  final Color signatureStroke;
  final Color notificationCardSurface;
  final Color notificationLockedSurface;
  final Color widgetPreviewSurface;
  final Color widgetPreviewBorder;

  @override
  MtfThemeTokens copyWith({
    Color? memberListBackground,
    Color? memberListCard,
    Color? memberListCardBorder,
    Color? memberListSelected,
    Color? navigationSheetBackground,
    Color? navigationSelectedBackground,
    Color? lockedItemForeground,
    Color? drawerBackground,
    Color? drawerHeaderBackground,
    Color? drawerSelectedBackground,
    Color? sheetBackground,
    Color? dialogBackground,
    Color? gradeSheetAccent,
    Color? donationSurface,
    Color? donationAccent,
    Color? donationForeground,
    Color? donationProgress,
    Color? aifcBackground,
    Color? aifcSurface,
    Color? aifcUserBubble,
    Color? aifcUserBubbleForeground,
    Color? aifcInputSurface,
    Color? scheduleBackground,
    Color? scheduleGridLine,
    Color? scheduleHeaderBackground,
    Color? scheduleTimeText,
    Color? scheduleTodayHighlight,
    Color? scheduleEmptySlot,
    Color? scheduleSelectedBorder,
    Color? schedulerOuterSurface,
    Color? schedulerBorder,
    Color? schedulerCornerSurface,
    Color? cardSurface,
    Color? cardBorder,
    Color? trainingLogSurface,
    Color? trainingLogSetRow,
    Color? trainingLogSetDivider,
    Color? trainingLogCompleted,
    Color? contractDocumentSurface,
    Color? contractDocumentText,
    Color? contractDocumentBorder,
    Color? signatureCanvasSurface,
    Color? signatureStroke,
    Color? notificationCardSurface,
    Color? notificationLockedSurface,
    Color? widgetPreviewSurface,
    Color? widgetPreviewBorder,
  }) {
    return MtfThemeTokens(
      memberListBackground: memberListBackground ?? this.memberListBackground,
      memberListCard: memberListCard ?? this.memberListCard,
      memberListCardBorder: memberListCardBorder ?? this.memberListCardBorder,
      memberListSelected: memberListSelected ?? this.memberListSelected,
      navigationSheetBackground:
          navigationSheetBackground ?? this.navigationSheetBackground,
      navigationSelectedBackground:
          navigationSelectedBackground ?? this.navigationSelectedBackground,
      lockedItemForeground: lockedItemForeground ?? this.lockedItemForeground,
      drawerBackground: drawerBackground ?? this.drawerBackground,
      drawerHeaderBackground:
          drawerHeaderBackground ?? this.drawerHeaderBackground,
      drawerSelectedBackground:
          drawerSelectedBackground ?? this.drawerSelectedBackground,
      sheetBackground: sheetBackground ?? this.sheetBackground,
      dialogBackground: dialogBackground ?? this.dialogBackground,
      gradeSheetAccent: gradeSheetAccent ?? this.gradeSheetAccent,
      donationSurface: donationSurface ?? this.donationSurface,
      donationAccent: donationAccent ?? this.donationAccent,
      donationForeground: donationForeground ?? this.donationForeground,
      donationProgress: donationProgress ?? this.donationProgress,
      aifcBackground: aifcBackground ?? this.aifcBackground,
      aifcSurface: aifcSurface ?? this.aifcSurface,
      aifcUserBubble: aifcUserBubble ?? this.aifcUserBubble,
      aifcUserBubbleForeground:
          aifcUserBubbleForeground ?? this.aifcUserBubbleForeground,
      aifcInputSurface: aifcInputSurface ?? this.aifcInputSurface,
      scheduleBackground: scheduleBackground ?? this.scheduleBackground,
      scheduleGridLine: scheduleGridLine ?? this.scheduleGridLine,
      scheduleHeaderBackground:
          scheduleHeaderBackground ?? this.scheduleHeaderBackground,
      scheduleTimeText: scheduleTimeText ?? this.scheduleTimeText,
      scheduleTodayHighlight:
          scheduleTodayHighlight ?? this.scheduleTodayHighlight,
      scheduleEmptySlot: scheduleEmptySlot ?? this.scheduleEmptySlot,
      scheduleSelectedBorder:
          scheduleSelectedBorder ?? this.scheduleSelectedBorder,
      schedulerOuterSurface:
          schedulerOuterSurface ?? this.schedulerOuterSurface,
      schedulerBorder: schedulerBorder ?? this.schedulerBorder,
      schedulerCornerSurface:
          schedulerCornerSurface ?? this.schedulerCornerSurface,
      cardSurface: cardSurface ?? this.cardSurface,
      cardBorder: cardBorder ?? this.cardBorder,
      trainingLogSurface: trainingLogSurface ?? this.trainingLogSurface,
      trainingLogSetRow: trainingLogSetRow ?? this.trainingLogSetRow,
      trainingLogSetDivider:
          trainingLogSetDivider ?? this.trainingLogSetDivider,
      trainingLogCompleted: trainingLogCompleted ?? this.trainingLogCompleted,
      contractDocumentSurface:
          contractDocumentSurface ?? this.contractDocumentSurface,
      contractDocumentText: contractDocumentText ?? this.contractDocumentText,
      contractDocumentBorder:
          contractDocumentBorder ?? this.contractDocumentBorder,
      signatureCanvasSurface:
          signatureCanvasSurface ?? this.signatureCanvasSurface,
      signatureStroke: signatureStroke ?? this.signatureStroke,
      notificationCardSurface:
          notificationCardSurface ?? this.notificationCardSurface,
      notificationLockedSurface:
          notificationLockedSurface ?? this.notificationLockedSurface,
      widgetPreviewSurface: widgetPreviewSurface ?? this.widgetPreviewSurface,
      widgetPreviewBorder: widgetPreviewBorder ?? this.widgetPreviewBorder,
    );
  }

  @override
  MtfThemeTokens lerp(ThemeExtension<MtfThemeTokens>? other, double t) {
    if (other is! MtfThemeTokens) return this;
    return MtfThemeTokens(
      memberListBackground: Color.lerp(
        memberListBackground,
        other.memberListBackground,
        t,
      )!,
      memberListCard: Color.lerp(memberListCard, other.memberListCard, t)!,
      memberListCardBorder: Color.lerp(
        memberListCardBorder,
        other.memberListCardBorder,
        t,
      )!,
      memberListSelected:
          Color.lerp(memberListSelected, other.memberListSelected, t)!,
      navigationSheetBackground: Color.lerp(
        navigationSheetBackground,
        other.navigationSheetBackground,
        t,
      )!,
      navigationSelectedBackground: Color.lerp(
        navigationSelectedBackground,
        other.navigationSelectedBackground,
        t,
      )!,
      lockedItemForeground: Color.lerp(
        lockedItemForeground,
        other.lockedItemForeground,
        t,
      )!,
      drawerBackground:
          Color.lerp(drawerBackground, other.drawerBackground, t)!,
      drawerHeaderBackground: Color.lerp(
        drawerHeaderBackground,
        other.drawerHeaderBackground,
        t,
      )!,
      drawerSelectedBackground: Color.lerp(
        drawerSelectedBackground,
        other.drawerSelectedBackground,
        t,
      )!,
      sheetBackground: Color.lerp(sheetBackground, other.sheetBackground, t)!,
      dialogBackground:
          Color.lerp(dialogBackground, other.dialogBackground, t)!,
      gradeSheetAccent:
          Color.lerp(gradeSheetAccent, other.gradeSheetAccent, t)!,
      donationSurface: Color.lerp(donationSurface, other.donationSurface, t)!,
      donationAccent: Color.lerp(donationAccent, other.donationAccent, t)!,
      donationForeground:
          Color.lerp(donationForeground, other.donationForeground, t)!,
      donationProgress:
          Color.lerp(donationProgress, other.donationProgress, t)!,
      aifcBackground: Color.lerp(aifcBackground, other.aifcBackground, t)!,
      aifcSurface: Color.lerp(aifcSurface, other.aifcSurface, t)!,
      aifcUserBubble: Color.lerp(aifcUserBubble, other.aifcUserBubble, t)!,
      aifcUserBubbleForeground: Color.lerp(
        aifcUserBubbleForeground,
        other.aifcUserBubbleForeground,
        t,
      )!,
      aifcInputSurface:
          Color.lerp(aifcInputSurface, other.aifcInputSurface, t)!,
      scheduleBackground:
          Color.lerp(scheduleBackground, other.scheduleBackground, t)!,
      scheduleGridLine:
          Color.lerp(scheduleGridLine, other.scheduleGridLine, t)!,
      scheduleHeaderBackground: Color.lerp(
        scheduleHeaderBackground,
        other.scheduleHeaderBackground,
        t,
      )!,
      scheduleTimeText:
          Color.lerp(scheduleTimeText, other.scheduleTimeText, t)!,
      scheduleTodayHighlight: Color.lerp(
        scheduleTodayHighlight,
        other.scheduleTodayHighlight,
        t,
      )!,
      scheduleEmptySlot:
          Color.lerp(scheduleEmptySlot, other.scheduleEmptySlot, t)!,
      scheduleSelectedBorder: Color.lerp(
        scheduleSelectedBorder,
        other.scheduleSelectedBorder,
        t,
      )!,
      schedulerOuterSurface: Color.lerp(
        schedulerOuterSurface,
        other.schedulerOuterSurface,
        t,
      )!,
      schedulerBorder: Color.lerp(schedulerBorder, other.schedulerBorder, t)!,
      schedulerCornerSurface: Color.lerp(
        schedulerCornerSurface,
        other.schedulerCornerSurface,
        t,
      )!,
      cardSurface: Color.lerp(cardSurface, other.cardSurface, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      trainingLogSurface:
          Color.lerp(trainingLogSurface, other.trainingLogSurface, t)!,
      trainingLogSetRow:
          Color.lerp(trainingLogSetRow, other.trainingLogSetRow, t)!,
      trainingLogSetDivider:
          Color.lerp(trainingLogSetDivider, other.trainingLogSetDivider, t)!,
      trainingLogCompleted:
          Color.lerp(trainingLogCompleted, other.trainingLogCompleted, t)!,
      contractDocumentSurface: Color.lerp(
        contractDocumentSurface,
        other.contractDocumentSurface,
        t,
      )!,
      contractDocumentText:
          Color.lerp(contractDocumentText, other.contractDocumentText, t)!,
      contractDocumentBorder: Color.lerp(
        contractDocumentBorder,
        other.contractDocumentBorder,
        t,
      )!,
      signatureCanvasSurface:
          Color.lerp(signatureCanvasSurface, other.signatureCanvasSurface, t)!,
      signatureStroke: Color.lerp(signatureStroke, other.signatureStroke, t)!,
      notificationCardSurface: Color.lerp(
        notificationCardSurface,
        other.notificationCardSurface,
        t,
      )!,
      notificationLockedSurface: Color.lerp(
        notificationLockedSurface,
        other.notificationLockedSurface,
        t,
      )!,
      widgetPreviewSurface:
          Color.lerp(widgetPreviewSurface, other.widgetPreviewSurface, t)!,
      widgetPreviewBorder:
          Color.lerp(widgetPreviewBorder, other.widgetPreviewBorder, t)!,
    );
  }
}

extension MtfThemeBuildContext on BuildContext {
  MtfThemeTokens get mtfThemeTokens {
    return Theme.of(this).extension<MtfThemeTokens>() ?? MtfThemeTokens.light;
  }

  MtfChartPalette get mtfChartPalette {
    return Theme.of(this).extension<MtfChartPalette>() ?? MtfChartPalette.light;
  }

  LinearGradient get mtfHeaderGradient {
    final theme = Theme.of(this);
    if (theme.brightness == Brightness.light &&
        theme.colorScheme.primary == AppColors.lululalaPrimary) {
      return AppColors.lululalaHeaderGradient;
    }
    return theme.brightness == Brightness.dark
        ? AppColors.darkHeaderGradient
        : AppColors.lightHeaderGradient;
  }
}

// ============================================================
//  ThemeData
// ============================================================

ThemeData lightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.deepNavy,
    brightness: Brightness.light,
    primary: AppColors.deepNavy,
    secondary: AppColors.warmYellow,
    surface: AppColors.lightSurface,
  ).copyWith(
    onPrimary: Colors.white,
    onSecondary: AppColors.deepNavy,
    primaryContainer: AppColors.deepNavy,
    onPrimaryContainer: Colors.white,
    secondaryContainer: const Color(0xFFFFF1C2),
    onSecondaryContainer: AppColors.deepNavy,
    onSurface: AppColors.lightTextPrimary,
    onSurfaceVariant: AppColors.lightTextSecondary,
    outline: AppColors.lightBorder,
    outlineVariant: const Color(0xFFF0ECE3),
    inverseSurface: AppColors.darkSurface,
    onInverseSurface: AppColors.darkTextPrimary,
    inversePrimary: AppColors.warmYellow,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    extensions: const [MtfThemeTokens.light, MtfChartPalette.light],
    scaffoldBackgroundColor: AppColors.lightBg,
    canvasColor: AppColors.lightSurface,
    dividerColor: AppColors.lightBorder,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lightSurface,
      foregroundColor: AppColors.lightTextPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.lightSurface,
      modalBackgroundColor: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        color: AppColors.lightTextPrimary,
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: const TextStyle(
        color: AppColors.lightTextSecondary,
        fontSize: 14,
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
        borderSide: const BorderSide(
          color: AppColors.lightBorderFocus,
          width: 1.5,
        ),
      ),
      hintStyle: const TextStyle(color: AppColors.lightTextHint, fontSize: 12),
      labelStyle:
          const TextStyle(color: AppColors.lightTextSecondary, fontSize: 12),
    ),
    elevatedButtonTheme: _elevatedButtonTheme(scheme),
    filledButtonTheme: _filledButtonTheme(scheme),
    outlinedButtonTheme: _outlinedButtonTheme(scheme),
    textButtonTheme: _textButtonTheme(scheme),
    navigationBarTheme: _navigationBarTheme(scheme),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: AppColors.deepNavy,
      unselectedItemColor: AppColors.lightTextTertiary,
      backgroundColor: AppColors.lightSurface,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    chipTheme: _chipTheme(scheme),
    dividerTheme: const DividerThemeData(
      color: AppColors.lightBorder,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: _snackBarTheme(scheme),
    switchTheme: _switchTheme(scheme),
    checkboxTheme: _checkboxTheme(scheme),
    radioTheme: _radioTheme(scheme),
    datePickerTheme: _datePickerTheme(scheme),
    timePickerTheme: _timePickerTheme(scheme),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.lightTextPrimary),
      bodyMedium: TextStyle(color: AppColors.lightTextPrimary),
      bodySmall: TextStyle(color: AppColors.lightTextSecondary),
      titleLarge: TextStyle(color: AppColors.lightTextPrimary),
      titleMedium: TextStyle(color: AppColors.lightTextPrimary),
      titleSmall: TextStyle(color: AppColors.lightTextPrimary),
      labelLarge: TextStyle(color: AppColors.lightTextPrimary),
    ),
  );
  return base.copyWith(
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.deepNavy,
      selectionColor: Color(0x66EFCB62),
      selectionHandleColor: AppColors.deepNavy,
    ),
  );
}

ThemeData darkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.warmYellow,
    brightness: Brightness.dark,
    primary: AppColors.warmYellow,
    secondary: AppColors.warmYellow,
    surface: AppColors.darkSurface,
  ).copyWith(
    onPrimary: AppColors.deepNavy,
    onSecondary: AppColors.deepNavy,
    primaryContainer: AppColors.darkSurface2,
    onPrimaryContainer: AppColors.darkTextPrimary,
    secondaryContainer: const Color(0xFF4A401F),
    onSecondaryContainer: AppColors.goldCream,
    onSurface: AppColors.darkTextPrimary,
    onSurfaceVariant: AppColors.darkTextSecondary,
    outline: AppColors.darkBorder,
    outlineVariant: const Color(0xFF20394C),
    inverseSurface: AppColors.warmIvory,
    onInverseSurface: AppColors.deepNavy,
    inversePrimary: AppColors.deepNavy,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    extensions: const [MtfThemeTokens.dark, MtfChartPalette.dark],
    scaffoldBackgroundColor: AppColors.darkBg,
    canvasColor: AppColors.darkSurface,
    dividerColor: AppColors.darkBorder,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkBg,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.darkBorder),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.darkDialogSurface,
      modalBackgroundColor: AppColors.darkDialogSurface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.darkDialogSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        color: AppColors.darkTextPrimary,
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: const TextStyle(
        color: AppColors.darkTextSecondary,
        fontSize: 14,
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
    elevatedButtonTheme: _elevatedButtonTheme(scheme),
    filledButtonTheme: _filledButtonTheme(scheme),
    outlinedButtonTheme: _outlinedButtonTheme(scheme),
    textButtonTheme: _textButtonTheme(scheme),
    navigationBarTheme: _navigationBarTheme(scheme),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: AppColors.goldBase,
      unselectedItemColor: AppColors.darkTextTertiary,
      backgroundColor: AppColors.darkSurface,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    chipTheme: _chipTheme(scheme),
    dividerTheme: const DividerThemeData(
      color: AppColors.darkBorder,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: _snackBarTheme(scheme),
    switchTheme: _switchTheme(scheme),
    checkboxTheme: _checkboxTheme(scheme),
    radioTheme: _radioTheme(scheme),
    datePickerTheme: _datePickerTheme(scheme),
    timePickerTheme: _timePickerTheme(scheme),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.darkTextPrimary),
      bodyMedium: TextStyle(color: AppColors.darkTextPrimary),
      bodySmall: TextStyle(color: AppColors.darkTextSecondary),
      titleLarge: TextStyle(color: AppColors.darkTextPrimary),
      titleMedium: TextStyle(color: AppColors.darkTextPrimary),
      titleSmall: TextStyle(color: AppColors.darkTextPrimary),
      labelLarge: TextStyle(color: AppColors.darkTextPrimary),
    ),
  );
  return base.copyWith(
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.warmYellow,
      selectionColor: Color(0x66EFCB62),
      selectionHandleColor: AppColors.warmYellow,
    ),
  );
}

ThemeData lululalaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.lululalaPrimary,
    brightness: Brightness.light,
    primary: AppColors.lululalaPrimary,
    secondary: AppColors.lululalaSecondary,
    surface: AppColors.lululalaSurface,
  ).copyWith(
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    primaryContainer: const Color(0xFFEEF2FF),
    onPrimaryContainer: const Color(0xFF312E81),
    secondaryContainer: const Color(0xFFF5F3FF),
    onSecondaryContainer: const Color(0xFF5B21B6),
    onSurface: AppColors.lululalaTextPrimary,
    onSurfaceVariant: AppColors.lululalaTextSecondary,
    outline: AppColors.lululalaBorder,
    outlineVariant: const Color(0xFFF1F5F9),
    inverseSurface: const Color(0xFF312E81),
    onInverseSurface: Colors.white,
    inversePrimary: const Color(0xFFC7D2FE),
  );
  final base = lightTheme();
  return base.copyWith(
    colorScheme: scheme,
    extensions: const [MtfThemeTokens.lululala, MtfChartPalette.lululala],
    scaffoldBackgroundColor: AppColors.lululalaBackground,
    canvasColor: AppColors.lululalaSurface,
    dividerColor: AppColors.lululalaBorder,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.lululalaSurface,
      foregroundColor: AppColors.lululalaTextPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    cardTheme: CardThemeData(
      color: AppColors.lululalaSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.lululalaBorder),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.lululalaSurface,
      modalBackgroundColor: AppColors.lululalaSurface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.lululalaSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titleTextStyle: const TextStyle(
        color: AppColors.lululalaTextPrimary,
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
      contentTextStyle: const TextStyle(
        color: AppColors.lululalaTextSecondary,
        fontSize: 14,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lululalaSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: AppColors.lululalaBorder, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: AppColors.lululalaBorder, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: AppColors.lululalaPrimary, width: 1.5),
      ),
      hintStyle: const TextStyle(
        color: AppColors.lululalaTextSecondary,
        fontSize: 12,
      ),
      labelStyle: const TextStyle(
        color: AppColors.lululalaTextSecondary,
        fontSize: 12,
      ),
    ),
    elevatedButtonTheme: _elevatedButtonTheme(scheme),
    filledButtonTheme: _filledButtonTheme(scheme),
    outlinedButtonTheme: _outlinedButtonTheme(scheme),
    textButtonTheme: _textButtonTheme(scheme),
    navigationBarTheme: _navigationBarTheme(scheme),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: AppColors.lululalaPrimary,
      unselectedItemColor: AppColors.lululalaTextSecondary,
      backgroundColor: AppColors.lululalaSurface,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    chipTheme: _chipTheme(scheme),
    dividerTheme: const DividerThemeData(
      color: AppColors.lululalaBorder,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: _snackBarTheme(scheme),
    switchTheme: _switchTheme(scheme),
    checkboxTheme: _checkboxTheme(scheme),
    radioTheme: _radioTheme(scheme),
    datePickerTheme: _datePickerTheme(scheme),
    timePickerTheme: _timePickerTheme(scheme),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.lululalaTextPrimary),
      bodyMedium: TextStyle(color: AppColors.lululalaTextPrimary),
      bodySmall: TextStyle(color: AppColors.lululalaTextSecondary),
      titleLarge: TextStyle(color: AppColors.lululalaTextPrimary),
      titleMedium: TextStyle(color: AppColors.lululalaTextPrimary),
      titleSmall: TextStyle(color: AppColors.lululalaTextPrimary),
      labelLarge: TextStyle(color: AppColors.lululalaTextPrimary),
    ),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: AppColors.lululalaPrimary,
      selectionColor: Color(0x334F46E5),
      selectionHandleColor: AppColors.lululalaPrimary,
    ),
  );
}

ElevatedButtonThemeData _elevatedButtonTheme(ColorScheme scheme) {
  return ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: scheme.secondary,
      foregroundColor: scheme.onSecondary,
      disabledBackgroundColor: scheme.surfaceContainerHighest,
      disabledForegroundColor: scheme.onSurfaceVariant,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}

FilledButtonThemeData _filledButtonTheme(ColorScheme scheme) {
  return FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: scheme.secondary,
      foregroundColor: scheme.onSecondary,
      disabledBackgroundColor: scheme.surfaceContainerHighest,
      disabledForegroundColor: scheme.onSurfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}

OutlinedButtonThemeData _outlinedButtonTheme(ColorScheme scheme) {
  return OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: scheme.primary,
      side: BorderSide(color: scheme.outline),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}

TextButtonThemeData _textButtonTheme(ColorScheme scheme) {
  return TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: scheme.primary,
      textStyle: const TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}

NavigationBarThemeData _navigationBarTheme(ColorScheme scheme) {
  return NavigationBarThemeData(
    backgroundColor: scheme.surface,
    indicatorColor: scheme.secondary,
    iconTheme: WidgetStateProperty.resolveWith((states) {
      return IconThemeData(
        color: states.contains(WidgetState.selected)
            ? scheme.onSecondary
            : scheme.onSurfaceVariant,
      );
    }),
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      return TextStyle(
        color: states.contains(WidgetState.selected)
            ? scheme.onSurface
            : scheme.onSurfaceVariant,
        fontWeight: states.contains(WidgetState.selected)
            ? FontWeight.w800
            : FontWeight.w600,
      );
    }),
  );
}

ChipThemeData _chipTheme(ColorScheme scheme) {
  return ChipThemeData(
    backgroundColor: scheme.surfaceContainerLow,
    selectedColor: scheme.secondaryContainer,
    disabledColor: scheme.surfaceContainerHighest,
    side: BorderSide(color: scheme.outline),
    labelStyle: TextStyle(color: scheme.onSurface),
    secondaryLabelStyle: TextStyle(color: scheme.onSecondaryContainer),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
  );
}

SnackBarThemeData _snackBarTheme(ColorScheme scheme) {
  return SnackBarThemeData(
    backgroundColor: scheme.inverseSurface,
    contentTextStyle: TextStyle(color: scheme.onInverseSurface),
    actionTextColor: scheme.inversePrimary,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

SwitchThemeData _switchTheme(ColorScheme scheme) {
  return SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.selected)
          ? scheme.onSecondary
          : scheme.onSurfaceVariant;
    }),
    trackColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.selected)
          ? scheme.secondary
          : scheme.surfaceContainerHighest;
    }),
    trackOutlineColor: WidgetStateProperty.all(scheme.outline),
  );
}

CheckboxThemeData _checkboxTheme(ColorScheme scheme) {
  return CheckboxThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.selected)
          ? scheme.secondary
          : Colors.transparent;
    }),
    checkColor: WidgetStateProperty.all(scheme.onSecondary),
    side: BorderSide(color: scheme.outline, width: 1.5),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  );
}

RadioThemeData _radioTheme(ColorScheme scheme) {
  return RadioThemeData(
    fillColor: WidgetStateProperty.resolveWith((states) {
      return states.contains(WidgetState.selected)
          ? scheme.secondary
          : scheme.onSurfaceVariant;
    }),
  );
}

DatePickerThemeData _datePickerTheme(ColorScheme scheme) {
  return DatePickerThemeData(
    backgroundColor: scheme.surface,
    surfaceTintColor: Colors.transparent,
    headerBackgroundColor: scheme.primaryContainer,
    headerForegroundColor: scheme.onPrimaryContainer,
    todayBackgroundColor: WidgetStateProperty.all(scheme.secondaryContainer),
    todayForegroundColor: WidgetStateProperty.all(scheme.onSecondaryContainer),
    dayOverlayColor:
        WidgetStateProperty.all(scheme.secondary.withValues(alpha: 0.12)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  );
}

TimePickerThemeData _timePickerTheme(ColorScheme scheme) {
  return TimePickerThemeData(
    backgroundColor: scheme.surface,
    hourMinuteColor: scheme.surfaceContainerHigh,
    hourMinuteTextColor: scheme.onSurface,
    dialBackgroundColor: scheme.surfaceContainerHigh,
    dialHandColor: scheme.secondary,
    dialTextColor: scheme.onSurface,
    entryModeIconColor: scheme.primary,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  );
}

// ============================================================
//  SharedPreferences 키
// ============================================================

class PrefKeys {
  PrefKeys._();
  static const String appTheme = 'pref_app_theme';
  static const String darkMode = 'pref_dark_mode';
}
