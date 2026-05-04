import 'package:flutter/material.dart';

enum WidgetThemeType {
  light,
  dark,
  pinkperfume,
  brownHistory,
  ttobak,
}

class MtfWidgetThemeData {
  final WidgetThemeType type;
  final String label;

  final String headerStartColor;
  final String headerEndColor;
  final String bodyBgColor;
  final String timeColBgColor;
  final String rowEvenColor;
  final String rowOddColor;
  final String todayColColor;
  final String todayHeaderColor;
  final String todayBorderColor;
  final String gridLineColor;
  final String timeColLineColor;
  final String dayTextColor;
  final String timeTextColor;
  final String headerTextColor;
  final String iconColor;

  final bool isDark;
  final bool isTtobak;

  const MtfWidgetThemeData({
    required this.type,
    required this.label,
    required this.headerStartColor,
    required this.headerEndColor,
    required this.bodyBgColor,
    required this.timeColBgColor,
    required this.rowEvenColor,
    required this.rowOddColor,
    required this.todayColColor,
    required this.todayHeaderColor,
    required this.todayBorderColor,
    required this.gridLineColor,
    required this.timeColLineColor,
    required this.dayTextColor,
    required this.timeTextColor,
    required this.headerTextColor,
    required this.iconColor,
    this.isDark = false,
    this.isTtobak = false,
  });
}

const Map<WidgetThemeType, MtfWidgetThemeData> kMtfWidgetThemes = {
  WidgetThemeType.light: MtfWidgetThemeData(
    type: WidgetThemeType.light,
    label: '라이트',
    headerStartColor: '#4F46E5',
    headerEndColor: '#9333EA',
    bodyBgColor: '#FFFFFF',
    timeColBgColor: '#F8FAFC',
    rowEvenColor: '#EFF6FF',
    rowOddColor: '#FFFFFF',
    todayColColor: '#22FDE68A',
    todayHeaderColor: '#FDE68A',
    todayBorderColor: '#E11D48',
    gridLineColor: '#E5E7EB',
    timeColLineColor: '#D1D5DB',
    dayTextColor: '#111827',
    timeTextColor: '#334155',
    headerTextColor: '#FFFFFF',
    iconColor: '#FFFFFF',
  ),

  WidgetThemeType.dark: MtfWidgetThemeData(
    type: WidgetThemeType.dark,
    label: '다크',
    headerStartColor: '#0F1E38',
    headerEndColor: '#1E293B',
    bodyBgColor: '#0F172A',
    timeColBgColor: '#111827',
    rowEvenColor: '#111827',
    rowOddColor: '#0F172A',
    todayColColor: '#334F46E5',
    todayHeaderColor: '#1E293B',
    todayBorderColor: '#E8C97A',
    gridLineColor: '#334155',
    timeColLineColor: '#475569',
    dayTextColor: '#E8C97A',
    timeTextColor: '#CBD5E1',
    headerTextColor: '#F5E9C0',
    iconColor: '#E8C97A',
    isDark: true,
  ),

  WidgetThemeType.pinkperfume: MtfWidgetThemeData(
    type: WidgetThemeType.pinkperfume,
    label: '핑크퍼퓸',
    headerStartColor: '#F4A7C5',
    headerEndColor: '#B58AE8',
    bodyBgColor: '#FFF7FB',
    timeColBgColor: '#FCECF5',
    rowEvenColor: '#FFF0F7',
    rowOddColor: '#FFF7FB',
    todayColColor: '#33F9A8D4',
    todayHeaderColor: '#FFD6EA',
    todayBorderColor: '#DB2777',
    gridLineColor: '#F4C7DC',
    timeColLineColor: '#EAB4D0',
    dayTextColor: '#9D4C72',
    timeTextColor: '#B05A82',
    headerTextColor: '#FFFFFF',
    iconColor: '#FFFFFF',
  ),

  WidgetThemeType.brownHistory: MtfWidgetThemeData(
    type: WidgetThemeType.brownHistory,
    label: '브라운히스토리',
    headerStartColor: '#6B4C2A',
    headerEndColor: '#A0784E',
    bodyBgColor: '#F7F0E4',
    timeColBgColor: '#EFE3D1',
    rowEvenColor: '#EFE7D8',
    rowOddColor: '#F7F0E4',
    todayColColor: '#36D4A96A',
    todayHeaderColor: '#D4A96A',
    todayBorderColor: '#8B5E34',
    gridLineColor: '#D6C4A8',
    timeColLineColor: '#BFA987',
    dayTextColor: '#5F4328',
    timeTextColor: '#7A5735',
    headerTextColor: '#FFF5E0',
    iconColor: '#FFF5E0',
  ),

  WidgetThemeType.ttobak: MtfWidgetThemeData(
    type: WidgetThemeType.ttobak,
    label: '또박또박',
    headerStartColor: '#FDFCF8',
    headerEndColor: '#F3F0E8',
    bodyBgColor: '#FDFCF8',
    timeColBgColor: '#F7F4EC',
    rowEvenColor: '#F7F4EC',
    rowOddColor: '#FDFCF8',
    todayColColor: '#22111827',
    todayHeaderColor: '#F1EBDD',
    todayBorderColor: '#111827',
    gridLineColor: '#D8D1C4',
    timeColLineColor: '#111827',
    dayTextColor: '#111827',
    timeTextColor: '#111827',
    headerTextColor: '#111827',
    iconColor: '#111827',
    isTtobak: true,
  ),
};

WidgetThemeType widgetThemeTypeFromRaw(String raw) {
  return WidgetThemeType.values.firstWhere(
        (e) => e.name == raw,
    orElse: () => WidgetThemeType.light,
  );
}

Color widgetColorFromHex(String hex) {
  var value = hex.trim().replaceFirst('#', '');

  if (value.length == 6) {
    value = 'FF$value';
  }

  final parsed = int.tryParse(value, radix: 16);
  return Color(parsed ?? 0xFF4F46E5);
}