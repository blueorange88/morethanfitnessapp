// lib/pages/test_hub_pages.dart
import 'package:flutter/material.dart';
import 'mtf_drawer_page.dart';

// ✅ [수정] 실제 생성하신 3개의 파일명에 맞춰 import 경로를 정확하게 수정합니다.
import 'test_sketch_ui_lab_page_gm.dart'; // Gemini 페이지
import 'test_sketch_ui_lab_page_cp.dart'; // Copilot 페이지
import 'test_sketch_ui_lab_page_gp.dart'; // GPT 페이지

class TestHubPage extends StatelessWidget {
  const TestHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tiles = <_TestTile>[
      _TestTile(
        title: '서랍 데모',
        subtitle: '왼→오 방향, 오픈 애니메이션',
        icon: Icons.inventory_2_outlined,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MtfDrawerPage()),
        ),
      ),
      _TestTile(
        title: '스케줄 실험',
        subtitle: '플레이스홀더(나중에 연결)',
        icon: Icons.schedule_outlined,
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('스케줄 실험 페이지: 추후 연결')),
        ),
      ),

      // ✅ [수정] 각 카드를 실제 페이지 클래스로 정확하게 연결합니다.
      _TestTile(
        title: '스케치 UI (Gemini)',
        subtitle: 'Gemini 제안 UI/애니메이션 실험',
        icon: Icons.auto_awesome, // 아이콘을 다르게 하여 구분
        onTap: () => Navigator.of(context).push(
          // ✅ TestSketchUiLabGmPage 로 연결 (클래스명은 파일 내용에 따라 다를 수 있습니다)
          MaterialPageRoute(builder: (_) => const TestSketchUiLabGmPage()),
        ),
      ),
      _TestTile(
        title: '스케치 UI (Copilot)',
        subtitle: 'Copilot 제안 UI/애니메이션 실험',
        icon: Icons.rocket_launch_outlined, // 아이콘을 다르게 하여 구분
        onTap: () => Navigator.of(context).push(
          // ✅ TestSketchUiLabCoPage 로 연결
          MaterialPageRoute(builder: (_) => const TestSketchUiLabCoPage()),
        ),
      ),
      _TestTile(
        title: '스케치 UI (GPT)',
        subtitle: 'GPT 제안 UI/애니메이션 실험',
        icon: Icons.psychology_alt_outlined, // 아이콘을 다르게 하여 구분
        onTap: () => Navigator.of(context).push(
          // ✅ TestSketchUiLabGpPage 로 연결
          MaterialPageRoute(builder: (_) => const TestSketchUiLabGpPage()),
        ),
      ),
    ];

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemCount: tiles.length,
          itemBuilder: (context, index) {
            return _TestCard(tile: tiles[index]);
          },
        ),
      ),
    );
  }
}

// 이하 _TestTile, _TestCard 클래스는 기존과 동일합니다.
class _TestTile {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  _TestTile({required this.title, required this.subtitle, required this.icon, required this.onTap});
}

class _TestCard extends StatelessWidget {
  final _TestTile tile;
  const _TestCard({required this.tile});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: tile.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 6))],
          border: Border.all(color: Colors.black12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tile.icon, size: 44, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              Text(tile.title, style: const TextStyle(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(tile.subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
