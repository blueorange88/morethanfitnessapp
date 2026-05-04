// lib/pages/test_binder_ui_envelope_box_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:mtf_app/pages/binder_card.dart';
import 'package:mtf_app/models/member.dart';

/// 홈 화면 톤과 맞춘 팔레트
const Color kPrimaryColor = Color(0xFF4F46E5);
const Color kPrimaryColor2 = Color(0xFF9333EA);
const Color kAccentAmber = Color(0xFFFBBF24);
const Color kAccentOrange = Color(0xFFF97316);
const Color kBgColor = Color(0xFFF3F4F6);
const double kMaxContentWidth = 480;

enum _ContainerMode { envelope, box }

class TestBinderUiEnvelopeBoxPage extends StatefulWidget {
  const TestBinderUiEnvelopeBoxPage({super.key});

  @override
  State<TestBinderUiEnvelopeBoxPage> createState() =>
      _TestBinderUiEnvelopeBoxPageState();
}

class _TestBinderUiEnvelopeBoxPageState
    extends State<TestBinderUiEnvelopeBoxPage> {
  late final List<Member> _members = _demoMembers();
  final List<String> _pinnedIds = [];
  _ContainerMode _mode = _ContainerMode.envelope;

  bool _isPinned(Member m) => _pinnedIds.contains(m.id);

  void _togglePin(Member m) {
    setState(() {
      if (_isPinned(m)) {
        _pinnedIds.remove(m.id);
      } else {
        if (_pinnedIds.length >= 5) _pinnedIds.removeAt(0);
        _pinnedIds.add(m.id);
      }
    });
  }

  List<Member> get _ordered {
    final map = {for (final m in _members) m.id: m};
    final pinned = _pinnedIds.map((id) => map[id]).whereType<Member>().toList();
    final rest = _members.where((m) => !_pinnedIds.contains(m.id)).toList();
    return [...pinned, ...rest];
  }

  @override
  Widget build(BuildContext context) {
    final members = _ordered;
    final pinnedSet = _pinnedIds.toSet();

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double width = isTablet ? kMaxContentWidth : constraints.maxWidth;

        return Scaffold(
          backgroundColor: kBgColor,
          body: SafeArea(
            child: Center(
              child: SizedBox(
                width: width,
                child: Column(
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _ModeToggle(
                        mode: _mode,
                        onChanged: (m) => setState(() => _mode = m),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // 상단 "수납 컨테이너" 영역
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _StorageContainerHeader(
                        mode: _mode,
                        pinnedCount: _pinnedIds.length,
                        onClear: _pinnedIds.isEmpty
                            ? null
                            : () => setState(_pinnedIds.clear),
                      ),
                    ),

                    const SizedBox(height: 10),

                    Expanded(
                      child: Stack(
                        children: [
                          PageView.builder(
                            controller: PageController(viewportFraction: 0.86),
                            itemCount: members.length,
                            itemBuilder: (_, i) {
                              final m = members[i];
                              final pinned = pinnedSet.contains(m.id);

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 18,
                                ),
                                child: Stack(
                                  children: [
                                    BinderCard(
                                      member: m,
                                      onOpenJournal: () async {},
                                      onOpenEdit: () async {},
                                      onOpenContract: () async {},
                                      onLongPress: () => _togglePin(m),
                                    ),
                                    Positioned(
                                      right: 10,
                                      top: 10,
                                      child: IconButton.filledTonal(
                                        style: IconButton.styleFrom(
                                          backgroundColor:
                                          kPrimaryColor.withOpacity(0.12),
                                          foregroundColor: kPrimaryColor,
                                        ),
                                        onPressed: () => _togglePin(m),
                                        icon: Icon(
                                          pinned
                                              ? Icons.push_pin
                                              : Icons.push_pin_outlined,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),

                          // 가운데 안내
                          Align(
                            alignment: Alignment.center,
                            child: IgnorePointer(
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 160),
                                opacity: _pinnedIds.isEmpty ? 1 : 0,
                                child: Container(
                                  margin:
                                  const EdgeInsets.symmetric(horizontal: 18),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.88),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Colors.black.withOpacity(0.08),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    '핀 버튼/롱프레스 → 위의 ${_mode == _ContainerMode.envelope ? '봉투' : '박스'}에 “수납된 묶음”처럼 보이게',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 14, left: 16, right: 16, bottom: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryColor, kPrimaryColor2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Row(
        children: [
          _CircleIcon(
            icon: Icons.arrow_back,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '운동기록 바인더',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                SizedBox(height: 2),
                Text(
                  'Binder UI · Envelope / Box',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withOpacity(0.24)),
            ),
            child: Text(
              'Pinned ${_pinnedIds.length}/5',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({
    required this.mode,
    required this.onChanged,
  });

  final _ContainerMode mode;
  final ValueChanged<_ContainerMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PillToggle(
            label: 'Envelope',
            isSelected: mode == _ContainerMode.envelope,
            onTap: () => onChanged(_ContainerMode.envelope),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PillToggle(
            label: 'Box',
            isSelected: mode == _ContainerMode.box,
            onTap: () => onChanged(_ContainerMode.box),
          ),
        ),
      ],
    );
  }
}

class _PillToggle extends StatelessWidget {
  const _PillToggle({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kPrimaryColor : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: kPrimaryColor.withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 6),
            )
          ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _StorageContainerHeader extends StatelessWidget {
  const _StorageContainerHeader({
    required this.mode,
    required this.pinnedCount,
    required this.onClear,
  });

  final _ContainerMode mode;
  final int pinnedCount;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final isEnvelope = mode == _ContainerMode.envelope;

    final String title = isEnvelope ? '봉투에 넣어 보관' : '박스에 넣어 보관';
    final IconData icon =
    isEnvelope ? Icons.mail_outline : Icons.all_inbox_outlined;

    final String statusText = isEnvelope
        ? (pinnedCount == 0 ? '비어있음' : '서류 $pinnedCount개 수납됨')
        : (pinnedCount == 0 ? '박스가 비어있음' : '묶음 $pinnedCount개 보관');

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: 124,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: kPrimaryColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '핀한 회원 최대 5명까지 위로 “수납”된 느낌',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black.withOpacity(0.55),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$pinnedCount/5',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.black.withOpacity(0.55),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (onClear != null)
                        TextButton.icon(
                          onPressed: onClear,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('비우기'),
                          style: TextButton.styleFrom(
                            foregroundColor: kPrimaryColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: const Size(0, 0),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isEnvelope
                      ? [
                    kAccentAmber.withOpacity(0.95),
                    kAccentOrange.withOpacity(0.95),
                  ]
                      : [
                    kPrimaryColor.withOpacity(0.95),
                    kPrimaryColor2.withOpacity(0.95),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                statusText,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.20)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

List<Member> _demoMembers() {
  final now = DateTime.now();
  DateTime daysFromNow(int d) => now.add(Duration(days: d));
  DateTime daysAgo(int d) => now.subtract(Duration(days: d));

  return [
    Member(
      id: 'm001',
      name: '김지훈',
      gender: Gender.male,
      phone: '010-1111-2222',
      totalSessions: 30,
      remainingSessions: 18,
      expireAt: daysFromNow(21),
      lastLogAt: daysAgo(2),
      memberStatus: '정상',
    ),
    Member(
      id: 'm002',
      name: '박서연',
      gender: Gender.female,
      phone: '010-3333-4444',
      totalSessions: 20,
      remainingSessions: 4,
      expireAt: daysFromNow(7),
      lastLogAt: daysAgo(1),
      memberStatus: '정상',
    ),
    Member(
      id: 'm003',
      name: '이도윤',
      gender: Gender.male,
      phone: '010-5555-6666',
      totalSessions: 10,
      remainingSessions: 0,
      expireAt: daysAgo(3),
      lastLogAt: daysAgo(10),
      memberStatus: '정상',
    ),
    Member(
      id: 'm004',
      name: '최유나',
      gender: Gender.female,
      phone: '010-7777-8888',
      totalSessions: 50,
      remainingSessions: 29,
      expireAt: daysFromNow(60),
      lastLogAt: daysAgo(0),
      memberStatus: '정상',
    ),
  ];
}