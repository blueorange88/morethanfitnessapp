import 'package:flutter/services.dart';

class HomeWidgetNavigationService {
  HomeWidgetNavigationService._();

  static const MethodChannel _channel =
      MethodChannel('com.example.mtf_app/widget_navigation');

  static Future<void> start(
    Future<void> Function(String action) onAction,
  ) async {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'widgetAction') return;
      final action = call.arguments?.toString().trim() ?? '';
      if (action.isNotEmpty) await onAction(action);
    });
    await consumePending(onAction);
  }

  static Future<void> consumePending(
    Future<void> Function(String action) onAction,
  ) async {
    final action =
        (await _channel.invokeMethod<String>('consume') ?? '').trim();
    if (action.isNotEmpty) await onAction(action);
  }

  static void stop() => _channel.setMethodCallHandler(null);
}
