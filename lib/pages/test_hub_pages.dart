import 'package:flutter/material.dart';
import 'mtf_drawer_page.dart';

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
      _TestTile(
        title: 'UI Lab',
        subtitle: '위젯/애니메이션 실험',
        icon: Icons.science_outlined,
        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('UI Lab: 추후 연결')),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('테스트')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: tiles.map((t) => _TestCard(tile: t)).toList(),
        ),
      ),
    );
  }
}

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
              Icon(tile.icon, size: 44),
              const SizedBox(height: 12),
              Text(tile.title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(tile.subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
