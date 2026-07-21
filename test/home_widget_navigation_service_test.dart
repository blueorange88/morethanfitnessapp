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
      return consumeCount == 1 ? 'today' : '';
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
}
