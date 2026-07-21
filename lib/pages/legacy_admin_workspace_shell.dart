import 'package:flutter/material.dart';

class LegacyAdminWorkspaceShell extends StatelessWidget {
  const LegacyAdminWorkspaceShell({
    super.key,
    required this.child,
    required this.onOpenPersonalWorkspace,
  });

  final Widget child;
  final VoidCallback onOpenPersonalWorkspace;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('legacy_admin_workspace_shell'),
      children: [
        Material(
          color: const Color(0xFF111827),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 40,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.storage_rounded,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 7),
                    const Expanded(
                      child: Text(
                        '기존 개발 데이터',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('switch_to_personal_workspace'),
                      onPressed: onOpenPersonalWorkspace,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('내 작업공간'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
