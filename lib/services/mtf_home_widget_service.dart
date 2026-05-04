import 'package:home_widget/home_widget.dart';

import '../models/widget_theme.dart';

class MtfHomeWidgetService {
  static const String _widgetName = 'MtfScheduleWidgetReceiver';
  static const String _androidName = 'MtfScheduleWidgetReceiver';
  static const String _qualifiedAndroidName =
      'com.example.mtf_app.MtfScheduleWidgetReceiver';

  static const String keyActiveOffset = 'mtf_widget_active_offset';

  static const String keyTitle0 = 'mtf_widget_title_0';
  static const String keyHeader0 = 'mtf_widget_header_0';
  static const String keyTitle1 = 'mtf_widget_title_1';
  static const String keyHeader1 = 'mtf_widget_header_1';

  static const String keyDayFilter = 'mtf_widget_day_filter';
  static const String keyStartHour = 'mtf_widget_start_hour';
  static const String keyEndHour = 'mtf_widget_end_hour';

  static const String keyRows0 = 'mtf_widget_rows_0';
  static const String keyRows1 = 'mtf_widget_rows_1';

  // ✅ 새로 추가
  static const String keyDays0 = 'mtf_widget_days_0';
  static const String keyDays1 = 'mtf_widget_days_1';

  static const String keyBlocks0 = 'mtf_widget_blocks_0';
  static const String keyBlocks1 = 'mtf_widget_blocks_1';

  static const String keyCurrentMarkerRatio0 = 'mtf_widget_current_marker_ratio_0';
  static const String keyCurrentMarkerRatio1 = 'mtf_widget_current_marker_ratio_1';

  static const int _maxWeeks = 2;
  static const String _rowSeparator = '§§ROW§§';

  static const String keyNextLessonTime = 'mtf_widget_next_lesson_time';
  static const String keyNextLessonName = 'mtf_widget_next_lesson_name';
  static const String keyNextLessonType = 'mtf_widget_next_lesson_type';
  static const String keyNextLessonMemo = 'mtf_widget_next_lesson_memo';

  static const String keySecondLessonTime = 'mtf_widget_second_lesson_time';
  static const String keySecondLessonName = 'mtf_widget_second_lesson_name';
  static const String keySecondLessonType = 'mtf_widget_second_lesson_type';
  static const String keySecondLessonMemo = 'mtf_widget_second_lesson_memo';

  static const String keyWidgetThemeMode = 'mtf_widget_theme_mode';

  static Future<WidgetThemeType> loadWidgetTheme() async {
    final raw = await HomeWidget.getWidgetData<String>(
      keyWidgetThemeMode,
      defaultValue: WidgetThemeType.light.name,
    );

    return widgetThemeTypeFromRaw(raw ?? WidgetThemeType.light.name);
  }

  static Future<void> syncWidgetTheme(WidgetThemeType type) async {
    final theme = kMtfWidgetThemes[type] ?? kMtfWidgetThemes[WidgetThemeType.light]!;

    await HomeWidget.saveWidgetData<String>(keyWidgetThemeMode, type.name);

    await HomeWidget.saveWidgetData<String>('mtf_widget_header_start', theme.headerStartColor);
    await HomeWidget.saveWidgetData<String>('mtf_widget_header_end', theme.headerEndColor);
    await HomeWidget.saveWidgetData<String>('mtf_widget_body_bg', theme.bodyBgColor);
    await HomeWidget.saveWidgetData<String>('mtf_widget_time_col_bg', theme.timeColBgColor);
    await HomeWidget.saveWidgetData<String>('mtf_widget_row_even', theme.rowEvenColor);
    await HomeWidget.saveWidgetData<String>('mtf_widget_row_odd', theme.rowOddColor);
    await HomeWidget.saveWidgetData<String>('mtf_widget_today_col', theme.todayColColor);
    await HomeWidget.saveWidgetData<String>('mtf_widget_today_header', theme.todayHeaderColor);
    await HomeWidget.saveWidgetData<String>('mtf_widget_today_border', theme.todayBorderColor);
    await HomeWidget.saveWidgetData<String>('mtf_widget_grid_line', theme.gridLineColor);
    await HomeWidget.saveWidgetData<String>('mtf_widget_time_col_line', theme.timeColLineColor);
    await HomeWidget.saveWidgetData<String>('mtf_widget_day_text', theme.dayTextColor);
    await HomeWidget.saveWidgetData<String>('mtf_widget_time_text', theme.timeTextColor);
    await HomeWidget.saveWidgetData<String>('mtf_widget_header_text', theme.headerTextColor);
    await HomeWidget.saveWidgetData<String>('mtf_widget_icon_color', theme.iconColor);
    await HomeWidget.saveWidgetData<String>('mtf_widget_is_dark', theme.isDark.toString());
    await HomeWidget.saveWidgetData<String>('mtf_widget_is_ttobak', theme.isTtobak.toString());

    await updateAllWidgets();
  }

  static Future<void> updateAllWidgets() async {
    await HomeWidget.updateWidget(
      name: 'MtfScheduleWidgetReceiver',
      androidName: 'MtfScheduleWidgetReceiver',
      qualifiedAndroidName: 'com.example.mtf_app.MtfScheduleWidgetReceiver',
    );

    await HomeWidget.updateWidget(
      name: 'MtfNextLessonWidgetReceiver',
      androidName: 'MtfNextLessonWidgetReceiver',
      qualifiedAndroidName: 'com.example.mtf_app.MtfNextLessonWidgetReceiver',
    );
  }


  static Future<void> syncNextLessons({
    required String nextTime,
    required String nextName,
    required String nextType,
    required String nextMemo,
    required String secondTime,
    required String secondName,
    required String secondType,
    required String secondMemo,
  }) async {
    await HomeWidget.saveWidgetData<String>(keyNextLessonTime, nextTime);
    await HomeWidget.saveWidgetData<String>(keyNextLessonName, nextName);
    await HomeWidget.saveWidgetData<String>(keyNextLessonType, nextType);
    await HomeWidget.saveWidgetData<String>(keyNextLessonMemo, nextMemo);

    await HomeWidget.saveWidgetData<String>(keySecondLessonTime, secondTime);
    await HomeWidget.saveWidgetData<String>(keySecondLessonName, secondName);
    await HomeWidget.saveWidgetData<String>(keySecondLessonType, secondType);
    await HomeWidget.saveWidgetData<String>(keySecondLessonMemo, secondMemo);

    await HomeWidget.updateWidget(
      name: 'MtfNextLessonWidgetReceiver',
      androidName: 'MtfNextLessonWidgetReceiver',
      qualifiedAndroidName: 'com.example.mtf_app.MtfNextLessonWidgetReceiver',
    );
  }

  static Future<void> syncGridWeeks({
    required String dayFilter,
    required int startHour,
    required int endHour,
    required String title0,
    required String header0,
    required List<String> rows0,
    required List<String> days0,
    required List<String> blocks0,
    required double? currentMarkerRatio0,
    required String title1,
    required String header1,
    required List<String> rows1,
    required List<String> days1,
    required List<String> blocks1,
    required double? currentMarkerRatio1,
  }) async {
    final int currentOffset =
    (await HomeWidget.getWidgetData<int>(keyActiveOffset, defaultValue: 0) ?? 0)
        .clamp(0, _maxWeeks - 1);

    await HomeWidget.saveWidgetData<String>(keyTitle0, title0);
    await HomeWidget.saveWidgetData<String>(keyHeader0, header0);
    await HomeWidget.saveWidgetData<String>(keyTitle1, title1);
    await HomeWidget.saveWidgetData<String>(keyHeader1, header1);

    await HomeWidget.saveWidgetData<String>(keyDayFilter, dayFilter);
    await HomeWidget.saveWidgetData<int>(keyStartHour, startHour);
    await HomeWidget.saveWidgetData<int>(keyEndHour, endHour);

    await HomeWidget.saveWidgetData<String>(keyRows0, rows0.join(_rowSeparator));
    await HomeWidget.saveWidgetData<String>(keyRows1, rows1.join(_rowSeparator));

    await MtfHomeWidgetService.syncWidgetTheme(
      await MtfHomeWidgetService.loadWidgetTheme(),);

    // ✅ 요일 저장
    await HomeWidget.saveWidgetData<String>(keyDays0, days0.join('|'));
    await HomeWidget.saveWidgetData<String>(keyDays1, days1.join('|'));

    // ✅ 블럭 저장
    await HomeWidget.saveWidgetData<String>(keyBlocks0, blocks0.join(_rowSeparator));
    await HomeWidget.saveWidgetData<String>(keyBlocks1, blocks1.join(_rowSeparator));

    // ✅ 현재시간 줄 비율 저장
    await HomeWidget.saveWidgetData<String>(
      keyCurrentMarkerRatio0,
      (currentMarkerRatio0 ?? -1).toString(),
    );
    await HomeWidget.saveWidgetData<String>(
      keyCurrentMarkerRatio1,
      (currentMarkerRatio1 ?? -1).toString(),
    );

    await HomeWidget.saveWidgetData<int>(keyActiveOffset, currentOffset);
    await _update();
  }

  static Future<void> shiftWeek(int delta) async {
    final int currentOffset =
    (await HomeWidget.getWidgetData<int>(keyActiveOffset, defaultValue: 0) ?? 0)
        .clamp(0, _maxWeeks - 1);

    final int nextOffset = (currentOffset + delta).clamp(0, _maxWeeks - 1);
    await HomeWidget.saveWidgetData<int>(keyActiveOffset, nextOffset);
    await _update();
  }

  static Future<void> _update() async {
    await HomeWidget.updateWidget(
      name: _widgetName,
      androidName: _androidName,
      qualifiedAndroidName: _qualifiedAndroidName,
    );
  }
}
