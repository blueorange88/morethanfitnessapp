import 'dart:async';

class HomeWidgetSyncController {
  Timer? _debounce;

  void queue({
    required Future<void> Function() syncAction,
    Duration delay = const Duration(milliseconds: 800),
  }) {
    _debounce?.cancel();

    _debounce = Timer(delay, () {
      unawaited(syncAction());
    });
  }

  void runNow({
    required Future<void> Function() syncAction,
  }) {
    _debounce?.cancel();
    _debounce = null;

    unawaited(syncAction());
  }

  void cancel() {
    _debounce?.cancel();
    _debounce = null;
  }

  void dispose() {
    cancel();
  }
}