import 'package:flutter/material.dart';

class DebugLegacyWorkspaceShell extends StatelessWidget {
  const DebugLegacyWorkspaceShell({
    super.key,
    required this.child,
    required this.onExit,
  });

  final Widget child;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('debug_legacy_workspace_shell'),
      children: [
        Material(
          color: const Color(0xFF92400E),
          child: SafeArea(
            bottom: false,
            child: SizedBox(
              height: 42,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(
                      Icons.developer_mode_rounded,
                      size: 17,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 7),
                    const Expanded(
                      child: Text(
                        '개발용 · 기존 데이터',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('exit_debug_legacy_workspace'),
                      onPressed: onExit,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('체험 화면으로 돌아가기'),
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
