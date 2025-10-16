import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart'; // ✅ 경로 수정 (../ 제거)

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = ref.watch(darkModeProvider);
    return ListView(
      children: [
        SwitchListTile(
          title: const Text('다크 모드'),
          value: dark,
            onChanged: (_) => ref.read(darkModeProvider.notifier).toggle(),
        ),
        const Divider(height: 1),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('앱 정보'),
          subtitle: Text('More Than Fitness'),
        ),
      ],
    );
  }
}
