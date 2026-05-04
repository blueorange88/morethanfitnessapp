// lib/pages/test_hub_pages.dart
import 'package:flutter/material.dart';

// 페이지 import
import 'test_training_log_draft_page.dart';
import 'test_training_log_editor_page.dart';
import 'test_client_log_hub_page.dart';
import 'test_home_page.dart';

// Sketch UI 실험 페이지들
import 'test_sketch_ui_lab_page_gm.dart';
import 'test_sketch_ui_lab_page_co.dart';
import 'test_sketch_ui_lab_page_gp.dart';

// ✅ Magazine holder preview page (alias 권장)
import 'test_magazine_file_holder_page.dart' as mag;

// ✅ 바인더 페이지 import (Firestore + PageView)
import 'binder_card_page.dart';

// ✅ 바인더 UI 컨셉 테스트 페이지들
import 'test_binder_ui_filing_rail_cover_page.dart' as rail_cover;
import 'test_binder_ui_filing_rail_page.dart' as rail;
import 'test_binder_ui_envelope_box_page.dart';
import 'test_binder_ui_tray_bundle_page.dart';

class TestHubPage extends StatelessWidget {
  const TestHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final tiles = <_TestTile>[
      _TestTile(
        title: '운동일지 작성 초안 테스트',
        subtitle: '텍스트 + 음성보조용 초안 페이지',
        icon: Icons.edit_note_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TestTrainingLogDraftPage()),
          );
        },
      ),
      _TestTile(
        title: '운동일지 리스트 테스트',
        subtitle: '운동일지 리스트형 테스트 페이지',
        icon: Icons.schedule_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TestTrainingLogEditorPage()),
          );
        },
      ),
      _TestTile(
        title: '홈 화면 테스트',
        subtitle: 'Home UI 테스트',
        icon: Icons.home_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TestHomePage()),
          );
        },
      ),

      _TestTile(
        title: 'Magazine Holder 테스트',
        subtitle: '파일꽂이 시각 확인',
        icon: Icons.folder_copy_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const mag.TestMagazineFileHolderPage()),
          );
        },
      ),

      // ✅ Live Binder
      _TestTile(
        title: 'Binder (Firestore + PageView)',
        subtitle: '회원 스와이프/바인더 Live 테스트',
        icon: Icons.folder_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => BinderCardPage()),
          );
        },
      ),

      // ✅ 바인더 UI 컨셉 테스트
      _TestTile(
        title: 'Binder UI · Filing Rail Cover',
        subtitle: '덮개 있음 · 탭 2번으로 내용 보기',
        icon: Icons.keyboard_double_arrow_up_rounded,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const rail_cover.TestBinderUiFilingRailCoverPage()),
          );
        },
      ),
      _TestTile(
        title: 'Binder UI · Filing Rail',
        subtitle: '핀(최대5) → 파일 레일에 꽂기',
        icon: Icons.view_agenda_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const rail.TestBinderUiFilingRailPage()),
          );
        },
      ),
      _TestTile(
        title: 'Binder UI · Envelope / Box',
        subtitle: '핀/그룹 → 봉투/박스에 넣어 묶기',
        icon: Icons.all_inbox_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TestBinderUiEnvelopeBoxPage()),
          );
        },
      ),
      _TestTile(
        title: 'Binder UI · Tray + Bundle',
        subtitle: '핀/그룹 → 트레이 + 묶음(클립/밴드)',
        icon: Icons.inbox_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TestBinderUiTrayBundlePage()),
          );
        },
      ),

      // Sketch UI pages
      _TestTile(
        title: '스케치 UI (Gemini)',
        subtitle: 'Gemini 제안 UI 실험',
        icon: Icons.auto_awesome,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TestSketchUiLabGmPage()),
          );
        },
      ),
      _TestTile(
        title: '스케치 UI (Copilot)',
        subtitle: 'Copilot 제안 UI 실험',
        icon: Icons.rocket_launch_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => TestSketchUiLabCoPage()),
          );
        },
      ),
      _TestTile(
        title: '스케치 UI (GPT)',
        subtitle: 'GPT 제안 UI 실험',
        icon: Icons.psychology_alt_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TestSketchUiLabGpPage()),
          );
        },
      ),

      _TestTile(
        title: '운동기록일지허브페이지',
        subtitle: '운동기록일지테스트',
        icon: Icons.badge_outlined,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TestClientLogHubPage()),
          );
        },
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '테스트',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),

              // 상단 빠른 버튼들
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.folder_outlined),
                    label: const Text('Binder Live'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => BinderCardPage()),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.keyboard_double_arrow_up_rounded),
                    label: const Text('Filing Rail Cover UI'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const rail_cover.TestBinderUiFilingRailCoverPage()),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.view_agenda_outlined),
                    label: const Text('Filing Rail UI'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const rail.TestBinderUiFilingRailPage()),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.all_inbox_outlined),
                    label: const Text('Envelope/Box UI'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TestBinderUiEnvelopeBoxPage()),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.inbox_outlined),
                    label: const Text('Tray+Bundle UI'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TestBinderUiTrayBundlePage()),
                      );
                    },
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.folder_copy_outlined),
                    label: const Text('Magazine Holder'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const mag.TestMagazineFileHolderPage()),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Expanded(
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
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            showDragHandle: true,
            builder: (_) => const _QuickSheet(),
          );
        },
        icon: const Icon(Icons.playlist_add_check_outlined),
        label: const Text('빠른 테스트'),
      ),
    );
  }
}

class _QuickSheet extends StatelessWidget {
  const _QuickSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('Binder Live (Firestore + PageView)'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BinderCardPage()),
              );
            },
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.keyboard_double_arrow_up_rounded),
            title: const Text('Binder UI · Filing Rail Cover'),
            subtitle: const Text('덮개 있음 · 탭 2번으로 내용 보기'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const rail_cover.TestBinderUiFilingRailCoverPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.view_agenda_outlined),
            title: const Text('Binder UI · Filing Rail'),
            subtitle: const Text('핀(최대5) → 파일 레일에 꽂기'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const rail.TestBinderUiFilingRailPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.all_inbox_outlined),
            title: const Text('Binder UI · Envelope / Box'),
            subtitle: const Text('핀/그룹 → 봉투/박스에 넣어 묶기'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TestBinderUiEnvelopeBoxPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.inbox_outlined),
            title: const Text('Binder UI · Tray + Bundle'),
            subtitle: const Text('핀/그룹 → 트레이 + 묶음(클립/밴드)'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TestBinderUiTrayBundlePage()),
              );
            },
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.folder_copy_outlined),
            title: const Text('Magazine Holder 테스트'),
            subtitle: const Text('파일꽂이 시각 확인'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const mag.TestMagazineFileHolderPage()),
              );
            },
          ),
          const Divider(height: 1),

          ListTile(
            leading: const Icon(Icons.home_outlined),
            title: const Text('홈 화면 테스트'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => TestHomePage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.badge_outlined),
            title: const Text('운동기록일지허브페이지테스트'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TestClientLogHubPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.psychology_alt_outlined),
            title: const Text('스케치 UI (GPT)'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TestSketchUiLabGpPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TestTile {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  _TestTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class _TestCard extends StatelessWidget {
  final _TestTile tile;

  const _TestCard({required this.tile});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: tile.onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.black12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(tile.icon, size: 44, color: cs.primary),
              const SizedBox(height: 12),
              Text(
                tile.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                tile.subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}