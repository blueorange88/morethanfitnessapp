// lib/pages/test_binder_ui_filing_rail_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:mtf_app/models/member.dart';

/// 톤 맞춘 팔레트(필요하면 프로젝트 상수로 빼도 됨)
const Color kPrimaryColor = Color(0xFF4F46E5);
const Color kPrimaryColor2 = Color(0xFF9333EA);
const Color kBgColor = Color(0xFFF3F4F6);

const String kHolderSvgAsset = 'assets/svg/morethan_holder_tintable.svg';

/// ✅ 트레이번들처럼 체감 크기
const double _binderScale = 0.65;

/// ✅ vector_math Matrix4에는 skewY() 메서드가 없어서, shear 매트릭스를 직접 구성
Matrix4 _skewY(double radians) =>
    Matrix4.identity()..setEntry(1, 0, math.tan(radians));

class TestBinderUiFilingRailPage extends StatefulWidget {
  const TestBinderUiFilingRailPage({super.key});

  @override
  State<TestBinderUiFilingRailPage> createState() =>
      _TestBinderUiFilingRailPageState();
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

class _TestBinderUiFilingRailPageState
    extends State<TestBinderUiFilingRailPage> {
  late final List<Member> _members = _demoMembers();

  /// 핀 = 앞 정렬 유지 (그룹과 무관)
  final List<String> _pinnedIds = [];

  /// 그룹(보관함) 5개 고정
  late final List<RailGroup> _groups = [
    RailGroup(name: '그룹 1', color: const Color(0xFF7EA7E7)),
    RailGroup(name: '그룹 2', color: const Color(0xFF8B5CF6)),
    RailGroup(name: '그룹 3', color: const Color(0xFF34D399)),
    RailGroup(name: '그룹 4', color: const Color(0xFFF59E0B)),
    RailGroup(name: '그룹 5', color: const Color(0xFF94A3B8)),
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

  /// 핀된 애들 맨앞 정렬
  List<Member> get _ordered {
    final map = {for (final m in _members) m.id: m};
    final pinned = _pinnedIds.map((id) => map[id]).whereType<Member>().toList();
    final rest = _members.where((m) => !_pinnedIds.contains(m.id)).toList();
    return [...pinned, ...rest];
  }

  /// 그룹에 넣기(한 멤버는 하나의 그룹에만 속하도록 처리)
  void _moveMemberToGroup(String memberId, int groupIndex) {
    setState(() {
      for (final g in _groups) {
        g.memberIds.remove(memberId);
      }
      _groups[groupIndex].memberIds.add(memberId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final members = _ordered;

    return Scaffold(
      backgroundColor: kBgColor,
      body: SafeArea(
        child: Column(
          children: [
            _TopHeader(
              title: '서류철 레일 (커버 없음/내용 보임)',
              subtitle: '탭=리프트 · 롱프레스=핀 · 롱프레스 드래그=그룹화',
              pinned: _pinnedIds.length,
              onBack: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  // ✅ 왼쪽: SVG 보관함 5개(그룹)
                  SizedBox(
                    width: 150,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 14, 8, 14),
                      child: Column(
                        children: List.generate(5, (gi) {
                          final group = _groups[gi];
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(bottom: gi == 4 ? 0 : 10),
                              child: _GroupHolder(
                                groupIndex: gi,
                                group: group,
                                membersById: {for (final m in _members) m.id: m},
                                onAcceptMemberId: (id) =>
                                    _moveMemberToGroup(id, gi),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),

                  // ✅ 오른쪽: 카드 캐러셀
                  Expanded(
                    child: PageView.builder(
                      controller: PageController(
                        viewportFraction: 0.72, // ✅ 0.68 -> 0.72로 완화
                      ),
                      itemCount: members.length,
                      itemBuilder: (_, i) {
                        final m = members[i];
                        final pinned = _isPinned(m);

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(6, 14, 14, 14),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _DeepLiftWrapper(
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 160),
                                  curve: Curves.easeOutCubic,
                                  scale: pinned ? 1.02 : 1.0,
                                  child: Transform.scale(
                                    scale: _binderScale,
                                    alignment: Alignment.topLeft,
                                    child: LongPressDraggable<String>(
                                      data: m.id,
                                      dragAnchorStrategy:
                                      pointerDragAnchorStrategy,
                                      feedback: Material(
                                        color: Colors.transparent,
                                        child: Opacity(
                                          opacity: 0.88,
                                          child: Transform.scale(
                                            scale: 1.02,
                                            child: _CoverlessBinderCard(
                                              member: m,
                                              onLongPress: () {},
                                            ),
                                          ),
                                        ),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: 0.35,
                                        child: _CoverlessBinderCard(
                                          member: m,
                                          onLongPress: () => _togglePin(m),
                                        ),
                                      ),
                                      child: _CoverlessBinderCard(
                                        member: m,
                                        onLongPress: () => _togglePin(m),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // (선택) 핀됨 배지
                              Positioned(
                                left: 12,
                                top: 12,
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 160),
                                  opacity: pinned ? 1 : 0,
                                  child: const _PinnedBadge(),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------- Header -------------------- */

class _TopHeader extends StatelessWidget {
  const _TopHeader({
    required this.title,
    required this.subtitle,
    required this.pinned,
    required this.onBack,
  });

  final String title;
  final String subtitle;
  final int pinned;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
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
          _CircleIcon(icon: Icons.arrow_back, onTap: onBack),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
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
              'Pinned $pinned',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
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

/* -------------------- Group Holder (SVG + Files) -------------------- */

class _GroupHolder extends StatelessWidget {
  const _GroupHolder({
    required this.groupIndex,
    required this.group,
    required this.membersById,
    required this.onAcceptMemberId,
  });

  final int groupIndex;
  final RailGroup group;
  final Map<String, Member> membersById;
  final ValueChanged<String> onAcceptMemberId;

  Color _holderTint(Color c) => Color.lerp(Colors.white, c, 0.55)!;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAccept: (id) => id != null,
      onAccept: onAcceptMemberId,
      builder: (context, candidate, rejected) {
        final isHover = candidate.isNotEmpty;

        final visibleIds = group.memberIds.take(3).toList(growable: false);
        final overflow =
        (group.memberIds.length - visibleIds.length).clamp(0, 999);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          transform: Matrix4.identity()
            ..translate(isHover ? -2.0 : 0.0, isHover ? -2.0 : 0.0),
          child: Stack(
            children: [
              Positioned.fill(
                child: SvgPicture.asset(
                  kHolderSvgAsset,
                  theme: SvgTheme(currentColor: _holderTint(group.color)),
                ),
              ),

              Positioned.fill(
                child: LayoutBuilder(
                  builder: (_, c) {
                    final w = c.maxWidth;
                    final h = c.maxHeight;

                    final innerLeft = w * 0.40;
                    final innerTop = h * 0.20;
                    final innerRight = w * 0.96;
                    final innerBottom = h * 0.12;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          left: innerLeft,
                          top: innerTop,
                          right: w - innerRight,
                          bottom: innerBottom,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              if (overflow > 0)
                                ...List.generate(7, (i) {
                                  return Positioned(
                                    left: 1.5 + i * 2.0,
                                    bottom: 4.0 + i * 1.1,
                                    child: Transform(
                                      alignment: Alignment.bottomLeft,
                                      transform: Matrix4.identity()
                                        ..rotateZ(-0.05)
                                        ..multiply(_skewY(-0.10)),
                                      child: _FileSpineMini(
                                        height: (h * 0.42).clamp(60, 120),
                                        width: (w * 0.12).clamp(14, 22),
                                        color: Colors.black.withOpacity(0.07),
                                        faint: true,
                                        tabLabel: '',
                                      ),
                                    ),
                                  );
                                }),
                              ...List.generate(visibleIds.length, (i) {
                                final id = visibleIds[i];
                                final m = membersById[id];
                                final label = (m?.name ?? '').trim();

                                final dx = i * 16.0;
                                final dy = i * 3.5;

                                return Positioned(
                                  left: dx,
                                  bottom: dy,
                                  child: Transform(
                                    alignment: Alignment.bottomLeft,
                                    transform: Matrix4.identity()
                                      ..rotateZ((-0.06 + i * 0.02))
                                      ..multiply(_skewY(-0.12)),
                                    child: _FileSpineMini(
                                      height: (h * 0.45).clamp(68, 128),
                                      width: (w * 0.135).clamp(16, 24),
                                      color: _spineColorFor(id),
                                      tabLabel: label,
                                    ),
                                  ),
                                );
                              }),
                              if (overflow > 0)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.92),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.black.withOpacity(0.10),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 10,
                                          offset: const Offset(0, 6),
                                        )
                                      ],
                                    ),
                                    child: Text(
                                      '+$overflow',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        Positioned(
                          left: w * 0.06,
                          bottom: h * 0.06,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(
                                isHover ? 0.96 : 0.86,
                              ),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.black.withOpacity(0.10),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                    isHover ? 0.14 : 0.08,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Text(
                              'G${groupIndex + 1} · ${group.memberIds.length}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              if (isHover)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.08),
                          width: 1.2,
                        ),
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  static Color _spineColorFor(String id) {
    const palette = [
      Color(0xFFCBD5E1),
      Color(0xFF94A3B8),
      Color(0xFFA78BFA),
      Color(0xFF60A5FA),
      Color(0xFF34D399),
      Color(0xFFFBBF24),
      Color(0xFFFB7185),
    ];
    final h = id.codeUnits.fold<int>(0, (p, c) => p + c);
    return palette[h % palette.length];
  }
}

class _FileSpineMini extends StatelessWidget {
  const _FileSpineMini({
    required this.height,
    required this.width,
    required this.color,
    required this.tabLabel,
    this.faint = false,
  });

  final double height;
  final double width;
  final Color color;
  final String tabLabel;
  final bool faint;

  String _shortLabel(String s) {
    final t = s.trim();
    if (t.isEmpty) return '';
    return (t.length <= 3) ? t : t.substring(0, 3);
  }

  @override
  Widget build(BuildContext context) {
    final label = _shortLabel(tabLabel);

    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: faint ? color : color.withOpacity(0.88),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
        boxShadow: faint
            ? []
            : [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 4,
            top: 10,
            bottom: 10,
            child: Container(
              width: 2,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.65),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          if (!faint && label.isNotEmpty)
            Positioned(
              left: -12,
              top: 12,
              child: Transform(
                alignment: Alignment.topLeft,
                transform: Matrix4.identity()
                  ..rotateZ(-0.06)
                  ..multiply(_skewY(-0.18)),
                child: Container(
                  width: 22,
                  height: 64,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.black.withOpacity(0.10)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: 3,
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* -------------------- Coverless Binder Card (내용 항상 보임) -------------------- */

class _CoverlessBinderCard extends StatefulWidget {
  const _CoverlessBinderCard({
    required this.member,
    required this.onLongPress,
  });

  final Member member;
  final VoidCallback onLongPress;

  @override
  State<_CoverlessBinderCard> createState() => _CoverlessBinderCardState();
}

class _CoverlessBinderCardState extends State<_CoverlessBinderCard> {
  bool _lifted = false;

  void _toggleLift() {
    setState(() => _lifted = !_lifted);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;

    final coverTone = _paperTone(m.gender);
    final tabColor = _tabTone(m.gender);

    final liftY = _lifted ? -12.0 : 0.0;
    final tilt = _lifted ? -0.02 : 0.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0012)
        ..translate(0.0, liftY)
        ..rotateZ(tilt),
      child: GestureDetector(
        onTap: _toggleLift,
        onLongPress: widget.onLongPress,
        child: SizedBox(
          width: 220, // ✅ 248 -> 220
          height: 320, // ✅ 360 -> 320
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // drop shadow
              Positioned(
                left: 8,
                right: 2,
                top: 14,
                bottom: 2,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.14),
                        blurRadius: 24,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                ),
              ),

              // 좌상단 탭(붙어있는 느낌)
              Positioned(
                left: 2,
                top: 24,
                child: _AttachedIndexTab(
                  label: (m.name ?? m.id).trim(),
                  color: tabColor,
                ),
              ),

              // 내용(항상 보임)
              Positioned(
                left: 18,
                top: 10,
                right: 10,
                bottom: 10,
                child: _InnerPaperFace(member: m, tone: coverTone),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _paperTone(Gender g) {
    switch (g) {
      case Gender.female:
        return const Color(0xFFECFEFF);
      case Gender.male:
        return const Color(0xFFEEF2FF);
      case Gender.unknown:
        return const Color(0xFFE6FFFB);
    }
  }

  Color _tabTone(Gender g) {
    switch (g) {
      case Gender.female:
        return const Color(0xFF7DD3FC);
      case Gender.male:
        return const Color(0xFF67E8F9);
      case Gender.unknown:
        return const Color(0xFF86EFAC);
    }
  }
}

class _AttachedIndexTab extends StatelessWidget {
  const _AttachedIndexTab({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final text = label.trim().isEmpty ? '회원' : label.trim();
    final short = text.length <= 3 ? text : text.substring(0, 3);

    return Transform(
      alignment: Alignment.topLeft,
      transform: Matrix4.identity()
        ..rotateZ(-0.015)
        ..multiply(_skewY(-0.10)),
      child: Container(
        width: 24,
        height: 96,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(color, Colors.white, 0.18)!,
              color,
            ],
          ),
          borderRadius: const BorderRadius.horizontal(
            left: Radius.circular(10),
            right: Radius.circular(8),
          ),
          border: Border.all(color: Colors.black.withOpacity(0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            const SizedBox(height: 6),
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: RotatedBox(
                  quarterTurns: 3,
                  child: Text(
                    short,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InnerPaperFace extends StatelessWidget {
  const _InnerPaperFace({
    required this.member,
    required this.tone,
  });

  final Member member;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final total = member.totalSessions <= 0 ? 1 : member.totalSessions;
    final used = (member.totalSessions - member.remainingSessions).clamp(0, total);
    final progress = (used / total).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // 살짝 톤 레이어
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Opacity(
                opacity: 0.35,
                child: Container(color: tone),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        (member.name ?? member.id).trim().isEmpty
                            ? '회원'
                            : (member.name ?? member.id).trim(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _PaperDonut(progress: progress, text: '$used/$total'),
                  ],
                ),
                const SizedBox(height: 14),
                _PaperInfoRow(label: '만료일', value: _fmtDate(member.expireAt)),
                _PaperInfoRow(label: 'D-day', value: _ddayText(member.expireAt)),
                _PaperInfoRow(label: '최근', value: _fmtDate(member.lastLogAt)),
                const Spacer(),
                Container(
                  height: 68,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperInfoRow extends StatelessWidget {
  const _PaperInfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperDonut extends StatelessWidget {
  const _PaperDonut({
    required this.progress,
    required this.text,
  });

  final double progress;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(54, 54),
            painter: _MiniDonutPainter(
              value: progress,
              stroke: 8,
              fg: const Color(0xFFF4D03F),
              bg: const Color(0xFFE5E7EB),
            ),
          ),
          Text(
            text,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

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

/* -------------------- Deep Lift (tap position based) -------------------- */

class _DeepLiftWrapper extends StatefulWidget {
  const _DeepLiftWrapper({
    required this.child,
    this.maxTilt = 0.18,
    this.lift = 18.0,
  });

  final Widget child;
  final double maxTilt;
  final double lift;

  @override
  State<_DeepLiftWrapper> createState() => _DeepLiftWrapperState();
}

class _DeepLiftWrapperState extends State<_DeepLiftWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
    reverseDuration: const Duration(milliseconds: 180),
  );

  double _rx = 0.0;
  double _ry = 0.0;

  void _setTargetFromLocal(Offset localPos) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final s = box.size;

    final nx =
    ((localPos.dx - s.width / 2) / (s.width / 2)).clamp(-1.0, 1.0);
    final ny =
    ((localPos.dy - s.height / 2) / (s.height / 2)).clamp(-1.0, 1.0);

    _ry = (nx * widget.maxTilt).clamp(-widget.maxTilt, widget.maxTilt);
    _rx = (-ny * widget.maxTilt).clamp(-widget.maxTilt, widget.maxTilt);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (e) {
        _setTargetFromLocal(e.localPosition);
        _c.forward(from: 0);
      },
      onPointerUp: (_) => _c.reverse(),
      onPointerCancel: (_) => _c.reverse(),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final t = Curves.easeOutCubic.transform(_c.value);
          final lift = widget.lift * t;

          final m = Matrix4.identity()
            ..setEntry(3, 2, 0.0014)
            ..translate(0.0, -lift)
            ..rotateX(_rx * t)
            ..rotateY(_ry * t);

          return Transform(
            alignment: Alignment.center,
            transform: m,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/* -------------------- Badges -------------------- */

class _PinnedBadge extends StatelessWidget {
  const _PinnedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Text(
        'PINNED',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
      ),
    );
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

String _ddayText(DateTime? target) {
  if (target == null) return '-';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final t = DateTime(target.year, target.month, target.day);
  final d = t.difference(today).inDays;
  if (d == 0) return 'D-DAY';
  if (d > 0) return 'D-$d';
  return 'D+${d.abs()}';
}

/// ⚠️ Member 생성자만 네 프로젝트에 맞게 조정
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