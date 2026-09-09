import 'package:flutter/widgets.dart';

enum AppWorkspaceMode {
  guest,
  personal,
  linkedPersonal,
  legacyAdmin,
  legacyDeveloper,
}

class AppWorkspaceScope extends InheritedWidget {
  const AppWorkspaceScope({
    super.key,
    required this.mode,
    required super.child,
  });

  final AppWorkspaceMode mode;

  static AppWorkspaceMode of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<AppWorkspaceScope>()
            ?.mode ??
        AppWorkspaceMode.guest;
  }

  @override
  bool updateShouldNotify(AppWorkspaceScope oldWidget) =>
      mode != oldWidget.mode;
}
