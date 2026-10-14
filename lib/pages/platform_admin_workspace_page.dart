import 'package:flutter/material.dart';

class PlatformAdminWorkspacePage extends StatelessWidget {
  const PlatformAdminWorkspacePage({
    super.key,
    required this.canOpenLegacyWorkspace,
    required this.onOpenPersonalWorkspace,
    required this.onOpenLegacyWorkspace,
  });

  final bool canOpenLegacyWorkspace;
  final VoidCallback onOpenPersonalWorkspace;
  final VoidCallback onOpenLegacyWorkspace;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('platform_admin_workspace_page'),
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'LEON님, 이동할 작업공간을 선택해주세요.',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 10),
                const Text(
                  '작업공간을 선택해도 기존 데이터의 소유자는 자동으로 바뀌지 않습니다.',
                  style: TextStyle(color: Color(0xFF6B7280), height: 1.45),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('open_personal_workspace'),
                  onPressed: onOpenPersonalWorkspace,
                  icon: const Icon(Icons.person_outline_rounded),
                  label: const Text('내 작업공간으로 이동'),
                ),
                if (canOpenLegacyWorkspace) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('open_legacy_workspace'),
                    onPressed: onOpenLegacyWorkspace,
                    icon: const Icon(Icons.storage_rounded),
                    label: const Text('기존 개발 데이터 열기'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
