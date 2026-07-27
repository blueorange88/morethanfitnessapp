import '../models/personal_schedule.dart';
import 'home_widget_block_mapper.dart';
import 'home_widget_grid_mapper.dart';
import 'home_widget_preview_sync_service.dart';
import 'mtf_home_widget_service.dart';
import 'app_environment.dart';

abstract interface class PersonalScheduleWidgetGateway {
  Future<String> loadOwnerUid();

  Future<void> saveOwnerUid(String uid);

  Future<void> clear();

  Future<void> sync(
    String uid,
    List<PersonalScheduleRecord> schedules,
  );
}

class PersonalScheduleWidgetSyncService {
  PersonalScheduleWidgetSyncService({
    required this.uid,
    PersonalScheduleWidgetGateway? gateway,
  }) : _gateway = gateway ?? const HomeWidgetPersonalScheduleGateway();

  final String uid;
  final PersonalScheduleWidgetGateway _gateway;

  Future<void> sync(List<PersonalScheduleRecord> schedules) async {
    final owner = await _gateway.loadOwnerUid();
    if (owner.isNotEmpty && owner != uid) {
      await _gateway.clear();
    }
    final owned = schedules
        .where(
          (schedule) =>
              schedule.trainerId == uid && schedule.workspaceType == 'personal',
        )
        .toList(growable: false);
    await _gateway.sync(uid, owned);
    await _gateway.saveOwnerUid(uid);
  }

  Future<void> clearForSignOut() => _gateway.clear();
}

class HomeWidgetPersonalScheduleGateway
    implements PersonalScheduleWidgetGateway {
  const HomeWidgetPersonalScheduleGateway();

  static const _days = ['월', '화', '수', '목', '금', '토', '일'];

  @override
  Future<String> loadOwnerUid() => MtfHomeWidgetService.loadPersonalOwnerUid();

  @override
  Future<void> saveOwnerUid(String uid) =>
      MtfHomeWidgetService.savePersonalOwnerUid(uid);

  @override
  Future<void> clear() => MtfHomeWidgetService.clearPersonalScheduleData();

  @override
  Future<void> sync(
    String uid,
    List<PersonalScheduleRecord> schedules,
  ) async {
    final now = DateTime.now();
    final timeSlots = [
      for (var hour = 6; hour < 22; hour++)
        '${hour.toString().padLeft(2, '0')}:00',
    ];
    List<String> rows(int offset) => HomeWidgetGridMapper.buildWeekRows(
          weekOffset: offset,
          timeSlots: timeSlots,
          visibleDays: _days,
          currentTime: now,
        );
    List<String> blocks(int offset) {
      final items = schedules.map((schedule) {
        return HomeWidgetBlockItem(
          startAt: schedule.startAt,
          endAt: schedule.endAt,
          day: _days[schedule.startAt.weekday - 1],
          name: schedule.name,
          type: schedule.type,
          colorHex:
              schedule.typeColorHex.isEmpty ? '#7C3AED' : schedule.typeColorHex,
        );
      }).toList();
      return HomeWidgetBlockMapper.buildBlocks(
        weekOffset: offset,
        currentTime: now,
        startHour: 6,
        endHour: 22,
        visibleDays: _days,
        allWeekDays: _days,
        items: items,
      ).map((block) => block.encode()).toList();
    }

    await HomeWidgetPreviewSyncService.sync(
      HomeWidgetPreviewSyncPayload(
        dayFilter: 'all',
        startHour: 6,
        endHour: 22,
        title0: '이번 주 스케줄',
        header0: _weekHeader(now, 0),
        rows0: rows(0),
        days0: _days,
        blocks0: blocks(0),
        currentMarkerRatio0: HomeWidgetGridMapper.buildCurrentMarkerRatio(
          weekOffset: 0,
          currentTime: now,
          startHour: 6,
          endHour: 22,
        ),
        title1: '다음 주 스케줄',
        header1: _weekHeader(now, 1),
        rows1: rows(1),
        days1: _days,
        blocks1: blocks(1),
        currentMarkerRatio1: null,
        lessons: schedules.map((schedule) {
          return HomeWidgetPreviewLesson(
            startAt: schedule.startAt,
            endAt: schedule.endAt,
            memberName: schedule.name,
            lessonType: schedule.type,
            memo: schedule.memo,
            ownerUid: schedule.trainerId,
            workspaceType: schedule.workspaceType,
            remainingSessions: schedule.remainingSessions,
            status: schedule.status,
          );
        }).toList(),
        personalOwnerUid: uid,
        environment: AppEnvironmentConfig.environmentName,
        projectId: AppEnvironmentConfig.firebaseProjectId,
        source: 'scheduleSnapshot',
      ),
    );
  }

  String _weekHeader(DateTime now, int offset) {
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1))
        .add(Duration(days: offset * 7));
    final sunday = monday.add(const Duration(days: 6));
    return '${monday.month}.${monday.day} - ${sunday.month}.${sunday.day}';
  }
}
