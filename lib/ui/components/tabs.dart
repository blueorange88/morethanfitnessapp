import 'package:flutter/material.dart';

class ShadcnTabs extends StatefulWidget {
  final List<String> tabs;
  final List<Widget> views;

  const ShadcnTabs({
    super.key,
    required this.tabs,
    required this.views,
  });

  @override
  State<ShadcnTabs> createState() => _ShadcnTabsState();
}

class _ShadcnTabsState extends State<ShadcnTabs>
    with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TabController(
      length: widget.tabs.length,
      vsync: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        TabBar(
          controller: _controller,
          indicatorColor: cs.primary,
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurface.withOpacity(0.6),
          tabs: [
            for (var t in widget.tabs) Tab(text: t),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: widget.views,
          ),
        ),
      ],
    );
  }
}
