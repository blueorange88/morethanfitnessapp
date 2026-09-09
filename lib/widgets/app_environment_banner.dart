import 'package:flutter/material.dart';

import '../services/dev_tier_fixture.dart';

class AppEnvironmentBanner extends StatefulWidget {
  const AppEnvironmentBanner({
    required this.enabled,
    required this.child,
    super.key,
  });

  final bool enabled;
  final Widget child;

  @override
  State<AppEnvironmentBanner> createState() => _AppEnvironmentBannerState();
}

class _AppEnvironmentBannerState extends State<AppEnvironmentBanner> {
  bool _fixturePanelOpen = false;

  bool get _fixtureEnabled =>
      widget.enabled && DevTierFixtureController.isAvailable;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    final colorScheme = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_fixturePanelOpen && _fixtureEnabled)
          Positioned.fill(
            child: GestureDetector(
              key: const Key('dev_tier_fixture_dismiss'),
              behavior: HitTestBehavior.translucent,
              onTap: () => setState(() => _fixturePanelOpen = false),
            ),
          ),
        if (_fixturePanelOpen && _fixtureEnabled)
          Positioned(
            top: 34,
            right: 8,
            child: SafeArea(
              child: Material(
                key: const Key('dev_tier_fixture_panel'),
                elevation: 10,
                color: colorScheme.surface,
                shadowColor: colorScheme.shadow,
                borderRadius: BorderRadius.circular(14),
                child: ValueListenableBuilder<DevTierFixture>(
                  valueListenable: DevTierFixtureController.selection,
                  builder: (context, selected, _) {
                    return Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                            child: Text(
                              'DEV 등급 fixture',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          for (final fixture in DevTierFixture.values)
                            InkWell(
                              key: Key(
                                'dev_tier_fixture_${fixture.name}',
                              ),
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                DevTierFixtureController.select(fixture);
                                setState(() => _fixturePanelOpen = false);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 7,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      fixture == selected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      size: 16,
                                      color: colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      fixture.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        Positioned(
          top: 4,
          right: 8,
          child: SafeArea(
            child: GestureDetector(
              onLongPress: _fixtureEnabled
                  ? () => setState(() {
                        _fixturePanelOpen = !_fixturePanelOpen;
                      })
                  : null,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xCC1D4ED8),
                  borderRadius: BorderRadius.all(Radius.circular(6)),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  child: Text(
                    'DEV',
                    key: Key('dev_environment_banner'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
