import 'dart:async';

class HomeWidgetSyncController {
  Timer? _debounce;
  Future<void> _serial = Future<void>.value();
  bool _disposed = false;

  void queue({
    required Future<void> Function() syncAction,
    Duration delay = const Duration(milliseconds: 800),
  }) {
    _debounce?.cancel();

    _debounce = Timer(delay, () => _run(syncAction));
  }

  void runNow({
    required Future<void> Function() syncAction,
  }) {
    _debounce?.cancel();
    _debounce = null;

    _run(syncAction);
  }

  void _run(Future<void> Function() syncAction) {
    _serial = _serial.catchError((Object _) {}).then((_) async {
      if (_disposed) return;
      await syncAction();
    });
    unawaited(_serial.catchError((Object _) {}));
  }

  void cancel() {
    _debounce?.cancel();
    _debounce = null;
  }

  void dispose() {
    _disposed = true;
    cancel();
  }
}
