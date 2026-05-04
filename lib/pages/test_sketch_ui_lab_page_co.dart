// lib/pages/test_sketch_ui_lab_page_co.dart
import 'package:flutter/material.dart';

class TestSketchUiLabCoPage extends StatelessWidget {
  // ✅ const 생성자 제공 (원하면 허브에서 const로 써도 됨)
  const TestSketchUiLabCoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('스케치 UI (Copilot)'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Copilot 실험 페이지 (임시 Stub)\n\n'
                    '✅ 지금은 빌드 안정화 목적이라 기능 없음.\n'
                    '나중에 여기에 Copilot 스타일 UI를 붙이면 됨.',
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: 6,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.auto_awesome_outlined),
                      title: Text('Demo Item ${i + 1}'),
                      subtitle: const Text('이건 더미 리스트입니다.'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Demo Item ${i + 1} tapped')),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}