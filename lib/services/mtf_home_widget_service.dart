import 'package:home_widget/home_widget.dart';

import '../models/widget_theme.dart';

class MtfHomeWidgetService {
  static const String _widgetName = 'MtfScheduleWidgetReceiver';
  static const String _androidName = 'MtfScheduleWidgetReceiver';
  static const String _qualifiedAndroidName =
      'com.example.mtf_app.MtfScheduleWidgetReceiver';

  static const String keyActiveOffset = 'mtf_widget_active_offset';
  static const String keyPersonalOwnerUid = 'mtf_widget_personal_owner_uid';

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

  static const String keyCurrentMarkerRatio0 =
      'mtf_widget_current_marker_ratio_0';
  static const String keyCurrentMarkerRatio1 =
      'mtf_widget_current_marker_ratio_1';

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

  static const String keyTodayRollupItems =
      'mtf_widget_today_rollup_items_v1';

  static const String keyWidgetThemeMode = 'mtf_widget_theme_mode';

  static Future<String> loadPersonalOwnerUid() async {
    return await HomeWidget.getWidgetData<String>(
          keyPersonalOwnerUid,
          defaultValue: '',
        ) ??
        '';
  }

  static Future<void> savePersonalOwnerUid(String uid) {
    return HomeWidget.saveWidgetData<String>(keyPersonalOwnerUid, uid.trim());
  }

  static Future<void> clearPersonalScheduleData() async {
    await HomeWidget.saveWidgetData<String>(keyPersonalOwnerUid, '');
    await HomeWidget.saveWidgetData<int>(keyActiveOffset, 0);
    await HomeWidget.saveWidgetData<String>(keyTitle0, '이번 주 스케줄');
    await HomeWidget.saveWidgetData<String>(keyHeader0, '');
    await HomeWidget.saveWidgetData<String>(keyTitle1, '다음 주 스케줄');
    await HomeWidget.saveWidgetData<String>(keyHeader1, '');
    await HomeWidget.saveWidgetData<String>(keyRows0, '');
    await HomeWidget.saveWidgetData<String>(keyRows1, '');
    await HomeWidget.saveWidgetData<String>(keyDays0, '');
    await HomeWidget.saveWidgetData<String>(keyDays1, '');
    await HomeWidget.saveWidgetData<String>(keyBlocks0, '');
    await HomeWidget.saveWidgetData<String>(keyBlocks1, '');
    await HomeWidget.saveWidgetData<String>(keyCurrentMarkerRatio0, '-1');
    await HomeWidget.saveWidgetData<String>(keyCurrentMarkerRatio1, '-1');
    await syncNextLessons(
      nextTime: '',
      nextName: '',
      nextType: '',
      nextMemo: '',
      secondTime: '',
      secondName: '',
      secondType: '',
      secondMemo: '',
    );
    await HomeWidget.saveWidgetData<String>(keyTodayRollupItems, '[]');
    await updateAllWidgets();
  }

  static Future<WidgetThemeType> loadWidgetTheme() async {
    final raw = await HomeWidget.getWidgetData<String>(
      keyWidgetThemeMode,
      defaultValue: WidgetThemeType.light.name,
    );

    return widgetThemeTypeFromRaw(raw ?? WidgetThemeType.light.name);
  }

  static Future<void> syncWidgetTheme(WidgetThemeType type) async {
    final theme =
        kMtfWidgetThemes[type] ?? kMtfWidgetThemes[WidgetThemeType.light]!;

    await HomeWidget.saveWidgetData<String>(keyWidgetThemeMode, type.name);

    await HomeWidget.saveWidgetData<String>(
        'mtf_widget_header_start', theme.headerStartColor);
    await HomeWidget.saveWidgetData<String>(
        'mtf_widget_header_end', theme.headerEndColor);
    await HomeWidget.saveWidgetData<String>(
        'mtf_widget_body_bg', theme.bodyBgColor);
    await HomeWidget.saveWidgetData<String>(
        'mtf_widget_time_col_bg', theme.timeColBgColor);
    await HomeWidget.saveWidgetData<String>(
        'mtf_widget_row_even', theme.rowEvenColor);
    await HomeWidget.saveWidgetData<String>(
        'mtf_widget_row_odd', theme.rowOddColor);
    await HomeWidget.saveWidgetData<String>(
        'mtf_widget_today_col', theme.todayColColor);
    await HomeWidget.saveWidgetData<String>(
        'mtf_widget_today_header', theme.todayHeaderColor);
    await HomeWidget.saveWidgetData<String>(
        'mtf_widget_today_border', theme.todayBorderColor);
    await HomeWidget.saveWidgetData<String>(
        'mtf_widget_grid_line', theme.gridLineColor);
    await HomeWidget.saveWidgetData<String>(
        'mtf_widget_time_col_line', theme.timeColLineColor);
    await HomeWidget.saveWidgetData<String>(
        'mtf_widget_day_text', theme.dayTextColor);
    await HomeWidget.saveWidgetData<String>(
        'mtf_widget_time_text', theme.timeTextColor);
    await HomeWidget.saveWidgetData<String>(
        'mtf_widget_header_text', theme.headerTextColor);
    await HomeWidget.saveWidgetData<String>(
        'mtf_widget_icon_color', theme.iconColor);
    await HomeWidget.saveWidgetData<String>(
        'mtf_widget_is_dark', theme.isDark.toString());
    await HomeWidget.saveWidgetData<String>(
        'mtf_widget_is_ttobak', theme.isTtobak.toString());

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

    await HomeWidget.updateWidget(
      name: 'MtfTodayLessonRollupWidgetReceiver',
      androidName: 'MtfTodayLessonRollupWidgetReceiver',
      qualifiedAndroidName:
          'com.example.mtf_app.MtfTodayLessonRollupWidgetReceiver',
    );
  }

  static Future<void> syncTodayLessonRollup(String encodedItems) async {
    await HomeWidget.saveWidgetData<String>(
      keyTodayRollupItems,
      encodedItems,
    );
    await HomeWidget.updateWidget(
      name: 'MtfTodayLessonRollupWidgetReceiver',
      androidName: 'MtfTodayLessonRollupWidgetReceiver',
      qualifiedAndroidName:
          'com.example.mtf_app.MtfTodayLessonRollupWidgetReceiver',
    );
  }

  static Future<void> rolloverCachedNextWeekToCurrentWeek() async {
    final now = DateTime.now();

    final rows1 = await HomeWidget.getWidgetData<String>(
          keyRows1,
          defaultValue: '',
        ) ??
        '';

    final blocks1 = await HomeWidget.getWidgetData<String>(
          keyBlocks1,
          defaultValue: '',
        ) ??
        '';

    final days1 = await HomeWidget.getWidgetData<String>(
          keyDays1,
          defaultValue: '',
        ) ??
        '';

    final header1 = await HomeWidget.getWidgetData<String>(
          keyHeader1,
          defaultValue: '',
        ) ??
        '';

    final startHour = await HomeWidget.getWidgetData<int>(
          keyStartHour,
          defaultValue: 6,
        ) ??
        6;

    final endHour = await HomeWidget.getWidgetData<int>(
          keyEndHour,
          defaultValue: 22,
        ) ??
        22;

    await HomeWidget.saveWidgetData<int>(keyActiveOffset, 0);

    await HomeWidget.saveWidgetData<String>(
      keyTitle0,
      '이번 주 스케줄',
    );

    await HomeWidget.saveWidgetData<String>(
      keyHeader0,
      header1.isEmpty ? '이번 주 스케줄' : header1,
    );

    await HomeWidget.saveWidgetData<String>(
      keyRows0,
      _markCurrentRow(
        packedRows: rows1,
        now: now,
      ),
    );

    await HomeWidget.saveWidgetData<String>(
      keyDays0,
      days1,
    );

    await HomeWidget.saveWidgetData<String>(
      keyBlocks0,
      blocks1,
    );

    await HomeWidget.saveWidgetData<String>(
      keyCurrentMarkerRatio0,
      _currentMarkerRatioString(
        now: now,
        startHour: startHour,
        endHour: endHour,
      ),
    );

    // 다음 주 데이터는 앱을 다시 열 때 정확히 재동기화됩니다.
    await HomeWidget.saveWidgetData<String>(
      keyTitle1,
      '다음 주 스케줄',
    );

    await HomeWidget.saveWidgetData<String>(
      keyHeader1,
      '앱을 열면 다음 주 스케줄이 갱신돼요',
    );

    await HomeWidget.saveWidgetData<String>(keyRows1, '');
    await HomeWidget.saveWidgetData<String>(keyBlocks1, '');
    await HomeWidget.saveWidgetData<String>(keyCurrentMarkerRatio1, '-1');

    await _update();
  }

  static String _markCurrentRow({
    required String packedRows,
    required DateTime now,
  }) {
    if (packedRows.trim().isEmpty) return packedRows;

    final currentMinutes = now.hour * 60 + now.minute;

    final rows = packedRows
        .split(_rowSeparator)
        .where((e) => e.trim().isNotEmpty)
        .map((row) {
      final parts = row.split('|');

      if (parts.length < 2) return row;

      final time = parts.first.trim();
      final timeParts = time.split(':');

      if (timeParts.length != 2) {
        parts[1] = '0';
        return parts.join('|');
      }

      final hour = int.tryParse(timeParts[0]) ?? -1;
      final minute = int.tryParse(timeParts[1]) ?? 0;

      if (hour < 0) {
        parts[1] = '0';
        return parts.join('|');
      }

      final rowStartMinutes = hour * 60 + minute;
      final isCurrent = currentMinutes >= rowStartMinutes &&
          currentMinutes < rowStartMinutes + 60;

      parts[1] = isCurrent ? '1' : '0';

      return parts.join('|');
    }).toList();

    return rows.join(_rowSeparator);
  }

  static String _currentMarkerRatioString({
    required DateTime now,
    required int startHour,
    required int endHour,
  }) {
    final start = DateTime(now.year, now.month, now.day, startHour);
    final end = DateTime(now.year, now.month, now.day, endHour);

    if (!now.isAfter(start) || !now.isBefore(end)) {
      return '-1';
    }

    final totalMinutes = end.difference(start).inMinutes;
    if (totalMinutes <= 0) return '-1';

    final passedMinutes = now.difference(start).inMinutes;

    return (passedMinutes / totalMinutes).clamp(0.0, 1.0).toStringAsFixed(6);
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
    final int currentOffset = (await HomeWidget.getWidgetData<int>(
                keyActiveOffset,
                defaultValue: 0) ??
            0)
        .clamp(0, _maxWeeks - 1);

    await HomeWidget.saveWidgetData<String>(keyTitle0, title0);
    await HomeWidget.saveWidgetData<String>(keyHeader0, header0);
    await HomeWidget.saveWidgetData<String>(keyTitle1, title1);
    await HomeWidget.saveWidgetData<String>(keyHeader1, header1);

    await HomeWidget.saveWidgetData<String>(keyDayFilter, dayFilter);
    await HomeWidget.saveWidgetData<int>(keyStartHour, startHour);
    await HomeWidget.saveWidgetData<int>(keyEndHour, endHour);

    await HomeWidget.saveWidgetData<String>(
        keyRows0, rows0.join(_rowSeparator));
    await HomeWidget.saveWidgetData<String>(
        keyRows1, rows1.join(_rowSeparator));

    // ✅ 요일 저장
    await HomeWidget.saveWidgetData<String>(keyDays0, days0.join('|'));
    await HomeWidget.saveWidgetData<String>(keyDays1, days1.join('|'));

    // ✅ 블럭 저장
    await HomeWidget.saveWidgetData<String>(
        keyBlocks0, blocks0.join(_rowSeparator));
    await HomeWidget.saveWidgetData<String>(
        keyBlocks1, blocks1.join(_rowSeparator));

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
    final int currentOffset = ((await HomeWidget.getWidgetData<int>(
                  keyActiveOffset,
                  defaultValue: 0,
                ) ??
                0)
            .clamp(0, _maxWeeks - 1))
        .toInt();

    final int nextOffset =
        (currentOffset + delta).clamp(0, _maxWeeks - 1).toInt();

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
