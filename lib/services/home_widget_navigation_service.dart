import 'package:flutter/foundation.dart';
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
      if (action.isNotEmpty) {
        await _dispatch(
          action,
          onAction,
          coldStart: false,
          source: 'newIntent',
        );
      }
    });
    await consumePending(onAction);
  }

  static Future<void> consumePending(
    Future<void> Function(String action) onAction,
  ) async {
    final response = await _channel.invokeMethod<Object?>('consume');
    final action = response is Map
        ? response['action']?.toString().trim() ?? ''
        : response?.toString().trim() ?? '';
    final coldStart = response is Map && response['coldStart'] == true;
    final source = response is Map
        ? response['source']?.toString().trim() ?? 'initialIntent'
        : 'initialIntent';
    if (action.isNotEmpty) {
      await _dispatch(
        action,
        onAction,
        coldStart: coldStart,
        source: source == 'onNewIntent' ? 'newIntent' : 'initialIntent',
      );
    }
  }

  static Future<void> _dispatch(
    String action,
    Future<void> Function(String action) onAction, {
    required bool coldStart,
    required String source,
  }) async {
    if (kDebugMode) {
      debugPrint(
        '[MTF_DAILY_WIDGET_DEEPLINK] '
        'source=$source coldStart=$coldStart activityForeground=true '
        'homeReady=true queued=false consumed=false result=dispatching',
      );
    }
    await onAction(action);
    if (kDebugMode) {
      debugPrint(
        '[MTF_DAILY_WIDGET_DEEPLINK] '
        'source=$source coldStart=$coldStart activityForeground=true '
        'homeReady=true queued=false consumed=true result=success',
      );
    }
  }

  static void stop() => _channel.setMethodCallHandler(null);
}
