import 'package:flutter/material.dart';

import 'aifc_theme.dart';

class AifcPageScaffold extends StatelessWidget {
  const AifcPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
  });

  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AifcColors.pageBg,
      appBar: AppBar(
        backgroundColor: AifcColors.pageBg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AifcColors.text,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AifcText.title),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: AifcText.caption,
              ),
            ],
          ],
        ),
        actions: actions,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}