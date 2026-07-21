import 'package:flutter/foundation.dart';

import 'home_widget_today_rollup_mapper.dart';
import 'mtf_home_widget_service.dart';
import 'mtf_next_lesson_widget_sync.dart';

class HomeWidgetPreviewLesson {
  const HomeWidgetPreviewLesson({
    required this.startAt,
    required this.endAt,
    required this.memberName,
    required this.lessonType,
    required this.memo,
    this.remainingSessions,
    this.status = 'scheduled',
  });

  final DateTime startAt;
  final DateTime endAt;
  final String memberName;
  final String lessonType;
  final String memo;
  final int? remainingSessions;
  final String status;
}

class HomeWidgetPreviewSyncPayload {
  const HomeWidgetPreviewSyncPayload({
    required this.dayFilter,
    required this.startHour,
    required this.endHour,
    required this.title0,
    required this.header0,
    required this.rows0,
    required this.days0,
    required this.blocks0,
    required this.currentMarkerRatio0,
    required this.title1,
    required this.header1,
    required this.rows1,
    required this.days1,
    required this.blocks1,
    required this.currentMarkerRatio1,
    required this.lessons,
    this.personalOwnerUid = '',
    this.debugLog = false,
  });

  final String dayFilter;
  final int startHour;
  final int endHour;

  final String title0;
  final String header0;
  final List<String> rows0;
  final List<String> days0;
  final List<String> blocks0;
  final double? currentMarkerRatio0;

  final String title1;
  final String header1;
  final List<String> rows1;
  final List<String> days1;
  final List<String> blocks1;
  final double? currentMarkerRatio1;

  final List<HomeWidgetPreviewLesson> lessons;
  final String personalOwnerUid;
  final bool debugLog;
}

class HomeWidgetPreviewSyncService {
  const HomeWidgetPreviewSyncService._();

  static Future<void> sync(HomeWidgetPreviewSyncPayload payload) async {
    if (payload.debugLog) {
      debugPrint(
        '[MTF_WIDGET] rows0=${payload.rows0.length}, '
        'rows1=${payload.rows1.length}, '
        'startHour=${payload.startHour}, '
        'endHour=${payload.endHour}, '
        'days=${payload.days0.join(",")}',
      );
    }

    await MtfHomeWidgetService.syncGridWeeks(
      dayFilter: payload.dayFilter,
      startHour: payload.startHour,
      endHour: payload.endHour,
      title0: payload.title0,
      header0: payload.header0,
      rows0: payload.rows0,
      days0: payload.days0,
      blocks0: payload.blocks0,
      currentMarkerRatio0: payload.currentMarkerRatio0,
      title1: payload.title1,
      header1: payload.header1,
      rows1: payload.rows1,
      days1: payload.days1,
      blocks1: payload.blocks1,
      currentMarkerRatio1: payload.currentMarkerRatio1,
    );

    final widgetEvents = payload.lessons.map((lesson) {
      return WidgetLessonEvent(
        startAt: lesson.startAt,
        memberName: lesson.memberName,
        lessonType: lesson.lessonType,
        memo: lesson.memo,
      );
    }).toList();

    await syncNextLessonWidgetFromEvents(widgetEvents);

    await MtfHomeWidgetService.syncTodayLessonRollup(
      HomeWidgetTodayRollupMapper.encode(
        HomeWidgetTodayRollupSnapshot(
          ownerUid: payload.personalOwnerUid,
          generatedAt: DateTime.now(),
          items: payload.lessons.map((lesson) {
            return HomeWidgetTodayRollupItem(
              startAt: lesson.startAt,
              endAt: lesson.endAt,
              memberName: lesson.memberName,
              lessonType: lesson.lessonType,
              remainingSessions: lesson.remainingSessions,
              status: lesson.status,
            );
          }).toList(),
        ),
      ),
    );
  }
}
