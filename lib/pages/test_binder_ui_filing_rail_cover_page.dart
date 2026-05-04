// lib/pages/test_binder_ui_filing_rail_cover_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mtf_app/models/member.dart';

/// 톤 맞춘 팔레트
const Color kPrimaryColor = Color(0xFF6366F1);
const Color kPrimaryColor2 = Color(0xFF8B5CF6);
const Color kBgColor = Color(0xFFF8FAFC);
const Color kBorderColor = Color(0xFFE2E8F0);
const Color kTextPrimary = Color(0xFF1E293B);
const Color kTextSecondary = Color(0xFF64748B);

const String kHolderSvgAsset = 'assets/svg/morethan_holder_tintable.svg';

enum _RailSortType {
  recentLog,
  expireSoon,
  nameAsc,
  remainingLow,
}

String _sortLabel(_RailSortType type) {
  switch (type) {
    case _RailSortType.recentLog:
      return '최근 이용순';
    case _RailSortType.expireSoon:
      return '만료 임박순';
    case _RailSortType.nameAsc:
      return '이름순';
    case _RailSortType.remainingLow:
      return '잔여 적은순';
  }
}

class TestBinderUiFilingRailCoverPage extends StatefulWidget {
  const TestBinderUiFilingRailCoverPage({super.key});

  @override
  State<TestBinderUiFilingRailCoverPage> createState() =>
      _TestBinderUiFilingRailCoverPageState();
}

/// 그룹(보관함) 모델
class RailGroup {
  RailGroup({
    required this.name,
    required this.color,
    List<String>? memberIds,
  }) : memberIds = memberIds ?? <String>[];

  String name;
  Color color;
  final List<String> memberIds;
}

class _TestBinderUiFilingRailCoverPageState
    extends State<TestBinderUiFilingRailCoverPage> {
  late final List<Member> _members = _demoMembers();

  final List<String> _pinnedIds = [];
  bool _holderOpen = false;
  int? _hoveredGroupIndex;
  String _searchQuery = '';
  _RailSortType _sortType = _RailSortType.recentLog;

  late final List<RailGroup> _groups = [
    RailGroup(name: '전략 기획팀', color: const Color(0xFF334155)),
    RailGroup(name: '비주얼 디자인', color: const Color(0xFFEC4899)),
    RailGroup(name: '플랫폼 개발', color: const Color(0xFF10B981)),
    RailGroup(name: '운영 관리', color: const Color(0xFFF59E0B)),
    RailGroup(name: '기록 보관', color: const Color(0xFF64748B)),
  ];

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

  void _toggleHolder() {
    setState(() => _holderOpen = !_holderOpen);
  }

  void _openHolderPanel() {
    if (_holderOpen) return;
    setState(() => _holderOpen = true);
  }

  void _moveMember(String id, int groupIndex) {
    setState(() {
      for (final g in _groups) {
        g.memberIds.remove(id);
      }
      _groups[groupIndex].memberIds.add(id);
      _hoveredGroupIndex = null;
    });
  }

  int? _groupIndexOf(String memberId) {
    for (int i = 0; i < _groups.length; i++) {
      if (_groups[i].memberIds.contains(memberId)) return i;
    }
    return null;
  }

  RailGroup? _groupOf(String memberId) {
    final idx = _groupIndexOf(memberId);
    if (idx == null) return null;
    return _groups[idx];
  }

  bool _matchesSearch(Member m) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return true;

    final targets = [
      m.name ?? '',
      m.id,
      m.phone ?? '',
      m.memberStatus ?? '',
    ];

    return targets.any((v) => v.toLowerCase().contains(q));
  }

  List<Member> _sortMembers(List<Member> list) {
    list.sort((a, b) {
      int result = 0;

      switch (_sortType) {
        case _RailSortType.recentLog:
          final aDate = a.lastLogAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.lastLogAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          result = bDate.compareTo(aDate);
          break;

        case _RailSortType.expireSoon:
          final aDate = a.expireAt ?? DateTime(9999);
          final bDate = b.expireAt ?? DateTime(9999);
          result = aDate.compareTo(bDate);
          break;

        case _RailSortType.nameAsc:
          result = (a.name ?? a.id).compareTo(b.name ?? b.id);
          break;

        case _RailSortType.remainingLow:
          result = a.remainingSessions.compareTo(b.remainingSessions);
          break;
      }

      if (result != 0) return result;
      return (a.name ?? a.id).compareTo(b.name ?? b.id);
    });

    return list;
  }

  List<Member> get _ordered {
    final pinned = _sortMembers(
      _members.where((m) => _isPinned(m) && _matchesSearch(m)).toList(),
    );

    final rest = _sortMembers(
      _members.where((m) => !_isPinned(m) && _matchesSearch(m)).toList(),
    );

    return [...pinned, ...rest];
  }

  @override
  Widget build(BuildContext context) {
    final members = _ordered;

    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _ModernHeader(
                  pinnedCount: _pinnedIds.length,
                  holderOpen: _holderOpen,
                  onMenuTap: _toggleHolder,
                  onBack: () => Navigator.of(context).maybePop(),
                  sortType: _sortType,
                  onSearchChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                  onSortChanged: (value) {
                    if (value == null) return;
                    setState(() => _sortType = value);
                  },
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 20),
                    itemCount: members.length,
                    itemBuilder: (context, i) {
                      final m = members[i];
                      final group = _groupOf(m.id);

                      return _DraggableBinderTile(
                        member: m,
                        pinned: _isPinned(m),
                        holderOpen: _holderOpen,
                        group: group,
                        onPinTap: () => _togglePin(m),
                        onDragStarted: _openHolderPanel,
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_holderOpen)
              GestureDetector(
                onTap: _toggleHolder,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _holderOpen ? 1 : 0,
                  child: Container(color: Colors.black26),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              left: _holderOpen ? 0 : -280,
              top: 0,
              bottom: 0,
              width: 280,
              child: _ModernHolderPanel(
                groups: _groups,
                hoveredGroupIndex: _hoveredGroupIndex,
                onHoverChanged: (value) =>
                    setState(() => _hoveredGroupIndex = value),
                onAccept: _moveMember,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------- Header -------------------- */

class _ModernHeader extends StatelessWidget {
  const _ModernHeader({
    required this.pinnedCount,
    required this.holderOpen,
    required this.onMenuTap,
    required this.onBack,
    required this.sortType,
    required this.onSearchChanged,
    required this.onSortChanged,
  });

  final int pinnedCount;
  final bool holderOpen;
  final VoidCallback onMenuTap;
  final VoidCallback onBack;
  final _RailSortType sortType;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_RailSortType?> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: kBorderColor)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    size: 18,
                    color: kTextPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ARCHIVE RAIL',
                      style: TextStyle(
                        fontSize: 12,
                        color: kPrimaryColor,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.3,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '인재 서류 관리',
                      style: TextStyle(
                        fontSize: 20,
                        color: kTextPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: kBorderColor),
                ),
                child: Text(
                  'Pinned $pinnedCount',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: kTextSecondary,
                  ),
                ),
              ),
              _HolderToggleButton(
                isOpen: holderOpen,
                onTap: onMenuTap,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 190,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorderColor),
                ),
                child: TextField(
                  onChanged: onSearchChanged,
                  decoration: const InputDecoration(
                    hintText: '회원 검색',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextSecondary,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: kTextSecondary,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 11),
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.sort_rounded,
                        size: 18,
                        color: kTextSecondary,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '정렬방법',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: kTextSecondary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<_RailSortType>(
                            value: sortType,
                            isExpanded: true,
                            icon: const Icon(
                              Icons.unfold_more_rounded,
                              size: 18,
                              color: kTextSecondary,
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary,
                            ),
                            items: _RailSortType.values.map((type) {
                              return DropdownMenuItem<_RailSortType>(
                                value: type,
                                child: Text(_sortLabel(type)),
                              );
                            }).toList(),
                            onChanged: onSortChanged,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HolderToggleButton extends StatelessWidget {
  const _HolderToggleButton({
    required this.isOpen,
    required this.onTap,
  });

  final bool isOpen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onTap,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          SvgPicture.asset(
            kHolderSvgAsset,
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(
              kPrimaryColor,
              BlendMode.srcIn,
            ),
          ),
          Positioned(
            right: -6,
            top: -6,
            child: Icon(
              isOpen ? Icons.close : Icons.chevron_right,
              size: 14,
              color: kPrimaryColor,
            ),
          ),
        ],
      ),
      style: IconButton.styleFrom(
        backgroundColor: kPrimaryColor.withOpacity(0.10),
        foregroundColor: kPrimaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/* -------------------- Holder Panel -------------------- */

class _ModernHolderPanel extends StatelessWidget {
  const _ModernHolderPanel({
    required this.groups,
    required this.hoveredGroupIndex,
    required this.onHoverChanged,
    required this.onAccept,
  });

  final List<RailGroup> groups;
  final int? hoveredGroupIndex;
  final ValueChanged<int?> onHoverChanged;
  final void Function(String, int) onAccept;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 20,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                'FILING RACKS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: kTextSecondary,
                  letterSpacing: 2,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                itemCount: groups.length,
                itemBuilder: (context, i) {
                  final group = groups[i];

                  return DragTarget<String>(
                    onWillAcceptWithDetails: (_) {
                      onHoverChanged(i);
                      return true;
                    },
                    onLeave: (_) => onHoverChanged(null),
                    onAcceptWithDetails: (details) {
                      onAccept(details.data, i);
                    },
                    builder: (context, candidate, _) {
                      final bool isHovered =
                          hoveredGroupIndex == i || candidate.isNotEmpty;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: isHovered
                              ? group.color.withOpacity(0.14)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isHovered ? group.color : kBorderColor,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: isHovered
                                    ? group.color.withOpacity(0.18)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.inventory_2_rounded,
                                color: isHovered ? group.color : kTextSecondary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    group.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: kTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    group.memberIds.isEmpty
                                        ? '드롭하여 분류'
                                        : '${group.memberIds.length}개 파일 보관 중',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isHovered
                                          ? group.color
                                          : kTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color:
                                isHovered ? group.color : Colors.grey[200],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${group.memberIds.length}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color:
                                  isHovered ? Colors.white : kTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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

/* -------------------- Draggable Binder Tile -------------------- */

class _DraggableBinderTile extends StatelessWidget {
  const _DraggableBinderTile({
    required this.member,
    required this.pinned,
    required this.holderOpen,
    required this.group,
    required this.onPinTap,
    required this.onDragStarted,
  });

  final Member member;
  final bool pinned;
  final bool holderOpen;
  final RailGroup? group;
  final VoidCallback onPinTap;
  final VoidCallback onDragStarted;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _MemberDonutBadge(member: member),
          const SizedBox(width: 14),
          Expanded(
            child: _BinderInfo(
              member: member,
              group: group,
              pinned: pinned,
              holderOpen: holderOpen,
            ),
          ),
          const SizedBox(width: 8),
          Column(
            children: [
              GestureDetector(
                onTap: onPinTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: pinned
                        ? kPrimaryColor
                        : Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: pinned ? Colors.transparent : kBorderColor,
                    ),
                  ),
                  child: Icon(
                    pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 18,
                    color: pinned ? Colors.white : kTextSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Icon(
                Icons.drag_indicator_rounded,
                color: Colors.black.withOpacity(0.22),
              ),
            ],
          ),
        ],
      ),
    );

    return LongPressDraggable<String>(
      data: member.id,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: onDragStarted,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 300,
          child: Opacity(opacity: 0.92, child: tile),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.32, child: tile),
      child: tile,
    );
  }
}

class _MemberDonutBadge extends StatelessWidget {
  const _MemberDonutBadge({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final total = member.totalSessions <= 0 ? 1 : member.totalSessions;
    final used = (member.totalSessions - member.remainingSessions).clamp(
      0,
      total,
    );
    final progress = (used / total).clamp(0.0, 1.0);

    final accent = _progressColor(member.remainingSessions, total);

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        shape: BoxShape.circle,
        border: Border.all(color: kBorderColor),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(50, 50),
            painter: _MiniDonutPainter(
              value: progress,
              stroke: 7,
              fg: accent,
              bg: const Color(0xFFE5E7EB),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${member.remainingSessions}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: kTextPrimary,
                ),
              ),
              Text(
                '/$total',
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: kTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _progressColor(int remaining, int total) {
    final ratio = total <= 0 ? 0.0 : remaining / total;
    if (ratio <= 0.3) return const Color(0xFFEF4444);
    if (ratio <= 0.7) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }
}

class _BinderInfo extends StatelessWidget {
  const _BinderInfo({
    required this.member,
    required this.group,
    required this.pinned,
    required this.holderOpen,
  });

  final Member member;
  final RailGroup? group;
  final bool pinned;
  final bool holderOpen;

  @override
  Widget build(BuildContext context) {
    final groupColor = group?.color ?? const Color(0xFFCBD5E1);
    final groupName = group?.name ?? '미분류';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (member.name ?? member.id).trim().isEmpty
              ? '회원'
              : (member.name ?? member.id).trim(),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: kTextPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: groupColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                groupName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kTextSecondary,
                ),
              ),
            ),
            if (pinned)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'PINNED',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: kPrimaryColor,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _MetaChip(
              icon: Icons.calendar_today_outlined,
              text: _fmtDate(member.expireAt),
            ),
            _MetaChip(
              icon: Icons.history,
              text: _fmtDate(member.lastLogAt),
            ),
            _MetaChip(
              icon: Icons.confirmation_num_outlined,
              text: '${member.remainingSessions}/${member.totalSessions}',
            ),
            if (holderOpen)
              const _MetaChip(
                icon: Icons.swipe_left_alt_rounded,
                text: '드래그하여 분류',
              ),
          ],
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: kTextSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: kTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------- Donut Painter -------------------- */

class _MiniDonutPainter extends CustomPainter {
  _MiniDonutPainter({
    required this.value,
    required this.stroke,
    required this.fg,
    required this.bg,
  });

  final double value;
  final double stroke;
  final Color fg;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = (size.width / 2) - stroke / 2;

    final pBg = Paint()
      ..color = bg
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final pFg = Paint()
      ..color = fg
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      0,
      math.pi * 2,
      false,
      pBg,
    );
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      -math.pi / 2,
      math.pi * 2 * value,
      false,
      pFg,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniDonutPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.stroke != stroke ||
        oldDelegate.fg != fg ||
        oldDelegate.bg != bg;
  }
}

/* -------------------- Utils -------------------- */

String _fmtDate(DateTime? d) {
  if (d == null) return '-';
  final yy = (d.year % 100).toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  final dd = d.day.toString().padLeft(2, '0');
  return '$yy.$mm.$dd';
}

/* -------------------- Demo Data -------------------- */

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
    Member(
      id: 'm005',
      name: '정민수',
      gender: Gender.unknown,
      phone: '010-9999-0000',
      totalSessions: 12,
      remainingSessions: 2,
      expireAt: daysFromNow(5),
      lastLogAt: daysAgo(4),
      memberStatus: '휴면',
    ),
  ];
}