import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import 'mtf_home_widget_service.dart';

@pragma('vm:entry-point')
FutureOr<void> mtfWidgetBackgroundCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (uri == null) return;
  if (uri.scheme != 'mtfwidget') return;
  if (uri.host != 'week') return;

  final path = uri.path;

  if (path == '/prev') {
    await MtfHomeWidgetService.shiftWeek(-1);
    return;
  }

  if (path == '/next') {
    await MtfHomeWidgetService.shiftWeek(1);
    return;
  }
}

Future<void> registerMtfWidgetInteractivity() async {
  await HomeWidget.registerInteractivityCallback(
    mtfWidgetBackgroundCallback,
  );
}