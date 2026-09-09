import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/services/home_widget_navigation_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.example.mtf_app/widget_navigation');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    HomeWidgetNavigationService.stop();
  });

  test('cold start pending action을 한 번 consume한다', () async {
    var consumeCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method != 'consume') return null;
      consumeCount++;
      return consumeCount == 1
          ? <String, Object?>{
              'action': 'today',
              'coldStart': true,
              'source': 'onCreate',
            }
          : <String, Object?>{
              'action': '',
              'coldStart': false,
              'source': 'none',
            };
    });
    final actions = <String>[];
    await HomeWidgetNavigationService.start((action) async {
      actions.add(action);
    });
    await HomeWidgetNavigationService.consumePending((action) async {
      actions.add(action);
    });
    expect(actions, ['today']);
  });

  test('warm action을 한 번 전달하고 pending consume에서 반복하지 않는다', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'consume') {
        return <String, Object?>{
          'action': '',
          'coldStart': false,
          'source': 'none',
        };
      }
      return null;
    });
    final actions = <String>[];
    await HomeWidgetNavigationService.start((action) async {
      actions.add(action);
    });
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('widgetAction', 'today'),
      ),
      (_) {},
    );
    await HomeWidgetNavigationService.consumePending((action) async {
      actions.add(action);
    });
    expect(actions, ['today']);
  });

  test('모든 위젯은 runtime package의 explicit MainActivity를 연다', () {
    final todaySource = File(
      'android/app/src/main/kotlin/com/example/mtf_app/'
      'MtfTodayLessonRollupWidget.kt',
    ).readAsStringSync();
    final nextSource = File(
      'android/app/src/main/kotlin/com/example/mtf_app/'
      'MtfNextLessonWidget.kt',
    ).readAsStringSync();
    final weeklySource = File(
      'android/app/src/main/kotlin/com/example/mtf_app/'
      'MtfScheduleWidget.kt',
    ).readAsStringSync();
    final factorySource = File(
      'android/app/src/main/kotlin/com/example/mtf_app/'
      'MtfWidgetIntentFactory.kt',
    ).readAsStringSync();
    final activitySource = File(
      'android/app/src/main/kotlin/com/example/mtf_app/MainActivity.kt',
    ).readAsStringSync();
    expect(todaySource, contains('MtfWidgetIntentFactory.openToday'));
    expect(nextSource, contains('MtfWidgetIntentFactory.openNextLesson'));
    expect(weeklySource, contains('MtfWidgetIntentFactory.openWeeklySchedule'));
    expect(weeklySource, contains('MtfWidgetIntentFactory.openWeeklySettings'));
    expect(todaySource, contains('AppWidgetId'));
    expect(nextSource, contains('AppWidgetId'));
    expect(weeklySource, contains('AppWidgetId'));
    expect(factorySource,
        contains('ComponentName(\n            context.packageName,'));
    expect(factorySource, contains('MainActivity::class.java.name'));
    expect(factorySource, contains('setPackage(context.packageName)'));
    expect(factorySource, contains('appendPath(kind)'));
    expect(factorySource,
        contains('appendQueryParameter("instance", appWidgetId.toString())'));
    expect(factorySource, contains('Intent.FLAG_ACTIVITY_SINGLE_TOP'));
    expect(factorySource,
        contains('openTodayScheduleAction(context.packageName)'));
    expect(factorySource, isNot(contains('getLaunchIntentForPackage')));
    expect(factorySource, isNot(contains('Intent.ACTION_VIEW')));
    expect(todaySource, contains('requestCode=glanceViewId uniqueData=true'));
    expect(todaySource, contains('pendingIntentType=activity'));
    expect(activitySource, contains('pendingWidgetAction = null'));
    expect(activitySource, contains('clearConsumedWidgetAction(intent)'));
    expect(activitySource, contains('channel.invokeMethod('));
    expect(activitySource, contains('object : MethodChannel.Result'));
    expect(activitySource, contains('restorePendingAction()'));
    expect(activitySource, contains('"source" to source'));
    expect(activitySource, contains('logWidgetActivity("onCreate"'));
    expect(activitySource, contains('logWidgetActivity("onNewIntent"'));
    expect(activitySource, contains('clearConsumedWidgetAction(intent)'));
    expect(
        activitySource, contains('candidate.removeExtra(EXTRA_WIDGET_ACTION)'));
    expect(activitySource, contains('candidate.action = null'));
    expect(activitySource, contains('candidate.data = null'));
    expect(activitySource,
        contains('candidate.action == openTodayScheduleAction(packageName)'));
    expect(
        activitySource,
        contains(
            'data.scheme == getString(R.string.mtf_widget_intent_scheme)'));
  });

  test('DEV flavor만 widget 이름과 본문에 DEV 표식을 사용한다', () {
    final mainResources = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    final devResources = File(
      'android/app/src/dev/res/values/strings.xml',
    ).readAsStringSync();
    final factorySource = File(
      'android/app/src/main/kotlin/com/example/mtf_app/'
      'MtfWidgetIntentFactory.kt',
    ).readAsStringSync();
    expect(mainResources,
        contains('<bool name="mtf_widget_show_dev_badge">false</bool>'));
    expect(devResources,
        contains('<bool name="mtf_widget_show_dev_badge">true</bool>'));
    expect(devResources, contains('모어댄 DEV 주간 일정'));
    expect(devResources, contains('모어댄 DEV 다음 레슨'));
    expect(devResources, contains('모어댄 DEV 오늘 레슨'));
    expect(devResources, contains('morethan-dev'));
    expect(devResources, contains('DEV 전용 · 오늘 레슨 위젯'));
    expect(factorySource, contains('R.bool.mtf_widget_show_dev_badge'));
    expect(factorySource, contains('R.string.mtf_widget_dev_badge'));
    final todaySource = File(
      'android/app/src/main/kotlin/com/example/mtf_app/'
      'MtfTodayLessonRollupWidget.kt',
    ).readAsStringSync();
    expect(todaySource, contains('private fun DevBanner'));
    expect(todaySource, contains('R.string.mtf_widget_dev_banner'));
    expect(todaySource, contains('0xFF6D28D9'));
  });

  test('위젯과 일반 알림은 exact alarm 권한 없이 inexact 예약을 사용한다', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    final receiverSource = File(
      'android/app/src/main/kotlin/com/example/mtf_app/'
      'MtfWidgetWeekRolloverReceiver.kt',
    ).readAsStringSync();
    final notificationSource = File(
      'lib/services/notification_service.dart',
    ).readAsStringSync();

    expect(manifest, isNot(contains('SCHEDULE_EXACT_ALARM')));
    expect(manifest, contains('android.permission.POST_NOTIFICATIONS'));
    expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
    expect(receiverSource, contains('setAndAllowWhileIdle('));
    expect(receiverSource, isNot(contains('setExactAndAllowWhileIdle(')));
    expect(notificationSource,
        contains('AndroidScheduleMode.inexactAllowWhileIdle'));
  });

  test('오늘 위젯 Android parser는 schema v2 revision과 서울 날짜를 사용한다', () {
    final source = File(
      'android/app/src/main/kotlin/com/example/mtf_app/'
      'MtfTodayLessonRollupWidget.kt',
    ).readAsStringSync();
    expect(source, contains('root.optInt("schemaVersion", 1)'));
    expect(source, contains('root.optLong("payloadRevision", 0L)'));
    expect(source, contains('"startAtEpochMs"'));
    expect(source, contains('"displayName"'));
    expect(source, contains('ZoneId.of(TIMEZONE_SEOUL)'));
    expect(source, contains('TAG_PARSE'));
    expect(source, contains('appWidgetId=\$appWidgetId payloadRevision='));
  });

  test('오늘 위젯 하단 일정은 중첩 Column으로 Glance 최상위 10개 제한을 넘지 않는다', () {
    final source = File(
      'android/app/src/main/kotlin/com/example/mtf_app/'
      'MtfTodayLessonRollupWidget.kt',
    ).readAsStringSync();
    expect(
      source,
      contains(
        'Column(modifier = GlanceModifier.fillMaxWidth()) {\n'
        '                    remaining.take(visibleRemainingCount)'
        '.forEach { CompactLesson(it) }',
      ),
    );
    expect(source, contains('lessons.size in 3..6'));
    expect(source, contains('minOf(sizeRemainingCapacity, 3)'));
    expect(
        source,
        contains(
            'hiddenCount = maxOf(0, remaining.size - visibleRemainingCount)'));
  });
}
