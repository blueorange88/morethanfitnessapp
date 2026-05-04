// lib/pages/test_binder_ui_tray_bundle_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:characters/characters.dart';

import 'package:mtf_app/pages/binder_card.dart';
import 'package:mtf_app/models/member.dart';

/// 홈 톤과 맞춘 팔레트
const Color kPrimaryColor = Color(0xFF4F46E5);
const Color kPrimaryColor2 = Color(0xFF9333EA);
const Color kAccentAmber = Color(0xFFFBBF24);
const Color kAccentOrange = Color(0xFFF97316);
const Color kBgColor = Color(0xFFF3F4F6);
const double kMaxContentWidth = 480;

class TestBinderUiTrayBundlePage extends StatefulWidget {
  const TestBinderUiTrayBundlePage({super.key});

  @override
  State<TestBinderUiTrayBundlePage> createState() =>
      _TestBinderUiTrayBundlePageState();
}

enum _Loc { main, tray1, tray2, tray3 }

class _DragPayload {
  const _DragPayload({required this.memberId, required this.from});
  final String memberId;
  final _Loc from;
}

class _TestBinderUiTrayBundlePageState extends State<TestBinderUiTrayBundlePage> {
  late final List<Member> _members = _demoMembers();

  // 핀 상태(최대 5)
  final List<String> _pinnedIds = [];

  // 위치
  final Map<String, _Loc> _locById = {};

  // 선택(한 번에 하나)
  String? _selectedId;

  // 트레이 이름표
  late final TextEditingController _tray1Name =
  TextEditingController(text: 'TRAY 1');
  late final TextEditingController _tray2Name =
  TextEditingController(text: 'TRAY 2');
  late final TextEditingController _tray3Name =
  TextEditingController(text: 'TRAY 3');

  // 토스트(인덱스 탭 위에 표시) — 지금은 바인더 내부 버튼으로 바뀌어서 “인덱스 탭” 개념이 없지만,
  // 여전히 카드에 피드백용 토스트는 쓸 수 있게 유지
  String? _toastForId;
  String? _toastText;
  Timer? _toastTimer;

  // 드롭 스냅 애니메이션 토큰
  String? _lastDroppedId;
  _Loc? _lastDroppedTray;
  int _dropToken = 0;

  _Loc? _hoveringTray;

  // ✅ 바인더 크기: 0.65 고정
  static const double _binderScale = 0.65;

  // ✅ 겹침(슬롯) 설정
  static const double _overlapFactor = 0.38;
  final ScrollController _stackScroll = ScrollController();

  // ✅ 트레이 아코디언: 하나만 펼치기
  _Loc _expandedTray = _Loc.tray1;

  @override
  void initState() {
    super.initState();
    for (final m in _members) {
      _locById[m.id] = _Loc.main;
    }
  }

  @override
  void dispose() {
    _tray1Name.dispose();
    _tray2Name.dispose();
    _tray3Name.dispose();
    _toastTimer?.cancel();
    _stackScroll.dispose();
    super.dispose();
  }

  bool _isPinned(String id) => _pinnedIds.contains(id);

  void _showToast(String memberId, String text) {
    _toastTimer?.cancel();
    setState(() {
      _toastForId = memberId;
      _toastText = text;
    });
    _toastTimer = Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _toastForId = null;
        _toastText = null;
      });
    });
  }

  void _togglePin(Member m) {
    final wasPinned = _isPinned(m.id);
    setState(() {
      if (wasPinned) {
        _pinnedIds.remove(m.id);
      } else {
        if (_pinnedIds.length >= 5) _pinnedIds.removeAt(0);
        _pinnedIds.add(m.id);
      }
    });

    HapticFeedback.mediumImpact();
    _showToast(m.id, wasPinned ? '고정 해제' : '고정됨');
  }

  void _selectOrOpen(Member m) {
    final isSelected = _selectedId == m.id;
    if (!isSelected) {
      setState(() => _selectedId = m.id);
      return;
    }
    _openMember(m);
  }

  Future<void> _openMember(Member m) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.folder_open, color: kPrimaryColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      m.name ?? m.id,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: const Text(
                  '열기(테스트)\n\n여기서 실제로는 BinderCard의 오버레이/상세로 연결하면 됨.',
                  style: TextStyle(fontSize: 12, height: 1.35),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.edit_note_outlined),
                      label: const Text('수정'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryColor,
                        side: BorderSide(color: kPrimaryColor.withOpacity(0.45)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.playlist_add_check),
                      label: const Text('기록 열기'),
                      style: FilledButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _moveTo(String id, _Loc to) {
    setState(() {
      _locById[id] = to;
      _lastDroppedId = id;
      _lastDroppedTray = to;
      _dropToken++;
      if (to == _Loc.main) {
        _selectedId = id;
      }
    });
  }

  List<Member> _membersIn(_Loc loc) {
    final ids =
    _locById.entries.where((e) => e.value == loc).map((e) => e.key).toSet();
    return _members.where((m) => ids.contains(m.id)).toList();
  }

  List<Member> get _mainOrdered {
    final mainMembers = _membersIn(_Loc.main);
    final byId = {for (final m in mainMembers) m.id: m};

    final pinned = _pinnedIds.map((id) => byId[id]).whereType<Member>().toList();
    final rest = mainMembers.where((m) => !_pinnedIds.contains(m.id)).toList();

    // ✅ 선택된 바인더는 맨 앞으로(마지막)
    final selected = _selectedId != null ? byId[_selectedId!] : null;
    final list = <Member>[
      ...pinned.where((m) => m.id != _selectedId),
      ...rest.where((m) => m.id != _selectedId),
      if (selected != null) selected,
    ];
    return list;
  }

  void _setExpandedTray(_Loc loc) {
    setState(() => _expandedTray = loc);
  }

  @override
  Widget build(BuildContext context) {
    final mainMembers = _mainOrdered;
    final tray1 = _membersIn(_Loc.tray1);
    final tray2 = _membersIn(_Loc.tray2);
    final tray3 = _membersIn(_Loc.tray3);

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
                    _TopHeader(
                      title: '서류철 트레이',
                      subtitle:
                      '핀/드래그는 “진짜 바인더 안” · 트레이 이름은 자동 축소',
                      pinned: _pinnedIds.length,
                      onBack: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(height: 10),

                    // 메인(바인더 스택/슬롯)
                    Expanded(
                      child: DragTarget<_DragPayload>(
                        onWillAccept: (p) => p != null,
                        onAccept: (p) {
                          _moveTo(p.memberId, _Loc.main);
                          setState(() => _hoveringTray = null);
                        },
                        builder: (context, _, __) {
                          if (mainMembers.isEmpty) {
                            return const _EmptyMainHint(
                              label: '메인에 서류가 비어있어요.\n아래 트레이에서 끌어와서 놓아보세요.',
                            );
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: _OverlappingBinderStack(
                              controller: _stackScroll,
                              members: mainMembers,
                              scale: _binderScale,
                              overlapFactor: _overlapFactor,
                              selectedId: _selectedId,
                              isPinned: (id) => _isPinned(id),
                              toastForId: _toastForId,
                              toastText: _toastText,
                              onSelectOrOpen: _selectOrOpen,
                              onTogglePin: _togglePin,
                            ),
                          );
                        },
                      ),
                    ),

                    // ✅ 트레이: 아코디언(낮게 깔기)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Column(
                        children: [
                          _AccordionTray(
                            controller: _tray1Name,
                            accent: kAccentAmber,
                            loc: _Loc.tray1,
                            isExpanded: _expandedTray == _Loc.tray1,
                            items: tray1,
                            hovering: _hoveringTray == _Loc.tray1,
                            onTapHeader: () => _setExpandedTray(_Loc.tray1),
                            onHover: () =>
                                setState(() => _hoveringTray = _Loc.tray1),
                            onHoverEnd: () =>
                                setState(() => _hoveringTray = null),
                            onAccept: (p) {
                              _moveTo(p.memberId, _Loc.tray1);
                              setState(() => _hoveringTray = null);
                            },
                            lastDroppedId: _lastDroppedId,
                            lastDroppedTray: _lastDroppedTray,
                            dropToken: _dropToken,
                          ),
                          const SizedBox(height: 10),
                          _AccordionTray(
                            controller: _tray2Name,
                            accent: kPrimaryColor,
                            loc: _Loc.tray2,
                            isExpanded: _expandedTray == _Loc.tray2,
                            items: tray2,
                            hovering: _hoveringTray == _Loc.tray2,
                            onTapHeader: () => _setExpandedTray(_Loc.tray2),
                            onHover: () =>
                                setState(() => _hoveringTray = _Loc.tray2),
                            onHoverEnd: () =>
                                setState(() => _hoveringTray = null),
                            onAccept: (p) {
                              _moveTo(p.memberId, _Loc.tray2);
                              setState(() => _hoveringTray = null);
                            },
                            lastDroppedId: _lastDroppedId,
                            lastDroppedTray: _lastDroppedTray,
                            dropToken: _dropToken,
                          ),
                          const SizedBox(height: 10),
                          _AccordionTray(
                            controller: _tray3Name,
                            accent: kPrimaryColor2,
                            loc: _Loc.tray3,
                            isExpanded: _expandedTray == _Loc.tray3,
                            items: tray3,
                            hovering: _hoveringTray == _Loc.tray3,
                            onTapHeader: () => _setExpandedTray(_Loc.tray3),
                            onHover: () =>
                                setState(() => _hoveringTray = _Loc.tray3),
                            onHoverEnd: () =>
                                setState(() => _hoveringTray = null),
                            onAccept: (p) {
                              _moveTo(p.memberId, _Loc.tray3);
                              setState(() => _hoveringTray = null);
                            },
                            lastDroppedId: _lastDroppedId,
                            lastDroppedTray: _lastDroppedTray,
                            dropToken: _dropToken,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/* -------------------- 메인: 겹치는 바인더 스택 -------------------- */

class _OverlappingBinderStack extends StatelessWidget {
  const _OverlappingBinderStack({
    required this.controller,
    required this.members,
    required this.scale,
    required this.overlapFactor,
    required this.selectedId,
    required this.isPinned,
    required this.toastForId,
    required this.toastText,
    required this.onSelectOrOpen,
    required this.onTogglePin,
  });

  final ScrollController controller;
  final List<Member> members;
  final double scale;
  final double overlapFactor;
  final String? selectedId;

  final bool Function(String id) isPinned;
  final String? toastForId;
  final String? toastText;

  final void Function(Member m) onSelectOrOpen;
  final void Function(Member m) onTogglePin;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final baseWidth = c.maxWidth * 0.86;
        final step = baseWidth * (1 - overlapFactor);
        final double contentW = members.isEmpty
            ? c.maxWidth
            : (baseWidth + step * (members.length - 1))
            .clamp(c.maxWidth, 999999.0)
            .toDouble();

        return SingleChildScrollView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: SizedBox(
            width: contentW,
            height: c.maxHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = 0; i < members.length; i++)
                  Positioned(
                    left: i * step,
                    top: 6,
                    child: _MainBinderItem(
                      member: members[i],
                      scale: scale,
                      width: baseWidth,
                      selected: selectedId == members[i].id,
                      pinned: isPinned(members[i].id),
                      toastText:
                      (toastForId == members[i].id) ? toastText : null,
                      onTap: () => onSelectOrOpen(members[i]),
                      onPin: () => onTogglePin(members[i]),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MainBinderItem extends StatelessWidget {
  const _MainBinderItem({
    required this.member,
    required this.scale,
    required this.width,
    required this.selected,
    required this.pinned,
    required this.toastText,
    required this.onTap,
    required this.onPin,
  });

  final Member member;
  final double scale;
  final double width;

  final bool selected;
  final bool pinned;

  final String? toastText;

  final VoidCallback onTap;
  final VoidCallback onPin;

  @override
  Widget build(BuildContext context) {
    final liftY = selected ? -8.0 : 0.0;

    final feedback = Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.88,
        child: Transform.scale(
          scale: 1.03,
          child: _A4MiniFileBody(member: member, height: 98),
        ),
      ),
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      transform: Matrix4.translationValues(0, liftY, 0),
      child: SizedBox(
        width: width,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Transform.scale(
              scale: scale,
              alignment: Alignment.topLeft,
              child: GestureDetector(
                onTap: onTap,
                child: AbsorbPointer(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // ✅ BinderCard 안에 버튼이 들어가게: BinderCard에 슬롯 파라미터를 추가한 상태를 전제로 함
                      BinderCard(
                        member: member,
                        onOpenJournal: () async {},
                        onOpenEdit: () async {},
                        onOpenContract: () async {},
                        onLongPress: () {},

                        // ✅ 상단: 고정핀
                        topRightAction: _BinderPinButton(
                          pinned: pinned,
                          onTap: onPin,
                        ),

                        // ✅ 하단: 드래그 핸들
                        bottomRightAction: LongPressDraggable<_DragPayload>(
                          data:
                          _DragPayload(memberId: member.id, from: _Loc.main),
                          dragAnchorStrategy: pointerDragAnchorStrategy,
                          feedback: feedback,
                          childWhenDragging: Opacity(
                            opacity: 0.35,
                            child: const _BinderDragHandle(),
                          ),
                          child: const _BinderDragHandle(),
                        ),
                      ),

                      // ✅ 토스트는 카드 위로 살짝 띄우기
                      if (toastText != null)
                        Positioned(
                          top: -12,
                          right: 6,
                          child: _MiniToast(text: toastText!),
                        ),
                    ],
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

/* -------------------- 바인더 내부 버튼 -------------------- */

class _BinderPinButton extends StatelessWidget {
  const _BinderPinButton({required this.pinned, required this.onTap});

  final bool pinned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = pinned ? kPrimaryColor : Colors.white.withOpacity(0.78);
    final border =
    pinned ? Colors.transparent : Colors.black.withOpacity(0.10);
    final iconColor = pinned ? Colors.white : Colors.black.withOpacity(0.70);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(pinned ? 0.14 : 0.10),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            pinned ? Icons.push_pin : Icons.push_pin_outlined,
            size: 18,
            color: iconColor,
          ),
        ),
      ),
    );
  }
}

class _BinderDragHandle extends StatelessWidget {
  const _BinderDragHandle();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.drag_indicator, size: 18, color: Colors.black.withOpacity(0.70)),
// 또는 Icons.drag_handle
          const SizedBox(width: 4),
          Text(
            'DRAG',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Colors.black.withOpacity(0.70),
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------- 토스트 -------------------- */

class _MiniToast extends StatelessWidget {
  const _MiniToast({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.78),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

/* -------------------- 트레이: 아코디언 -------------------- */

class _AccordionTray extends StatelessWidget {
  const _AccordionTray({
    required this.controller,
    required this.accent,
    required this.loc,
    required this.isExpanded,
    required this.items,
    required this.hovering,
    required this.onTapHeader,
    required this.onHover,
    required this.onHoverEnd,
    required this.onAccept,
    required this.lastDroppedId,
    required this.lastDroppedTray,
    required this.dropToken,
  });

  final TextEditingController controller;
  final Color accent;

  final _Loc loc;
  final bool isExpanded;
  final List<Member> items;

  final bool hovering;

  final VoidCallback onTapHeader;
  final VoidCallback onHover;
  final VoidCallback onHoverEnd;
  final void Function(_DragPayload payload) onAccept;

  final String? lastDroppedId;
  final _Loc? lastDroppedTray;
  final int dropToken;

  @override
  Widget build(BuildContext context) {
    // ✅ 낮게 깔기: 접힘/펼침 높이
    const collapsedH = 54.0;
    const expandedH = 150.0;

    // ✅ 파일 스택(미니 A4)
    const fileH = 74.0;
    final fileW = fileH / 1.414;
    final dx = fileW * 0.33;
    final maxVisible = items.length.clamp(0, 14);
    final stackW =
    maxVisible == 0 ? fileW : (fileW + dx * (maxVisible - 1)) + 18;

    final border =
    hovering ? accent.withOpacity(0.55) : Colors.black.withOpacity(0.10);

    return DragTarget<_DragPayload>(
      onWillAccept: (p) {
        onHover();
        return p != null;
      },
      onLeave: (_) => onHoverEnd(),
      onAccept: onAccept,
      builder: (context, _, __) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          height: isExpanded ? expandedH : collapsedH,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              // ✅ 왼쪽 “트레이 인덱스 탭”
              _TrayIndexTab(
                accent: accent,
                controller: controller,
                count: items.length,
                isExpanded: isExpanded,
                onTap: onTapHeader,
              ),
              const SizedBox(width: 10),

              // ✅ 오른쪽: 접힘이면 라벨/힌트만, 펼침이면 파일 웰 표시
              Expanded(
                child: InkWell(
                  onTap: onTapHeader,
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: isExpanded
                        ? Container(
                      key: const ValueKey('expanded'),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.black.withOpacity(0.08)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            accent.withOpacity(0.10),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                      child: items.isEmpty
                          ? Center(
                        child: Text(
                          '여기로 드롭',
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.42),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                          : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: SizedBox(
                          width: stackW,
                          height: fileH,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              for (int i = 0; i < maxVisible; i++)
                                _TrayFile(
                                  key: ValueKey(
                                      '${loc.name}_${items[i].id}_$dropToken'),
                                  member: items[i],
                                  left: i * dx,
                                  height: fileH,
                                  slideIn:
                                  (items[i].id == lastDroppedId &&
                                      lastDroppedTray == loc),
                                  dragData: _DragPayload(
                                      memberId: items[i].id,
                                      from: loc),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                        : Container(
                      key: const ValueKey('collapsed'),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(
                            color: Colors.black.withOpacity(0.06)),
                      ),
                      child: Text(
                        '탭해서 열기 · 드래그는 그대로 드롭 가능',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withOpacity(0.55),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
}

class _TrayIndexTab extends StatelessWidget {
  const _TrayIndexTab({
    required this.accent,
    required this.controller,
    required this.count,
    required this.isExpanded,
    required this.onTap,
  });

  final Color accent;
  final TextEditingController controller;
  final int count;
  final bool isExpanded;
  final VoidCallback onTap;

  double _autoFontSize(String text) {
    // ✅ “A안 자동 축소”: 길이에 따라 폰트 줄이기 (너무 작아지지 않게 clamp)
    final len = text.trim().characters.length;
    if (len <= 6) return 12;
    final down = (len - 6) * 0.8; // 길어질수록 빠르게 줄임
    return (12 - down).clamp(8.5, 12.0);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isExpanded ? 0.20 : 0.12),
                      blurRadius: isExpanded ? 16 : 12,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // ✅ 중앙: 트레이 이름(세로) — TextField 유지 + 자동 축소 + 길이 제한
                    Center(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: SizedBox(
                          width: 120,
                          child: AnimatedBuilder(
                            animation: controller,
                            builder: (context, _) {
                              final fontSize = _autoFontSize(controller.text);
                              return TextField(
                                controller: controller,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                textInputAction: TextInputAction.done,
                                inputFormatters: [
                                  // ✅ 너무 길어서 깨지는 것 방지(필수 안전장치)
                                  LengthLimitingTextInputFormatter(16),
                                ],
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.95),
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                                decoration: const InputDecoration(
                                  isCollapsed: true,
                                  border: InputBorder.none,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    // 상단 아이콘
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          shape: BoxShape.circle,
                          border:
                          Border.all(color: Colors.white.withOpacity(0.12)),
                        ),
                        child: Icon(
                          Icons.all_inbox_outlined,
                          size: 16,
                          color: Colors.white.withOpacity(0.92),
                        ),
                      ),
                    ),

                    // 하단 카운트 칩
                    Positioned(
                      left: 6,
                      right: 6,
                      bottom: 6,
                      child: Container(
                        height: 22,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.22),
                          borderRadius: BorderRadius.circular(999),
                          border:
                          Border.all(color: Colors.white.withOpacity(0.16)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 옆 포인트(선택 느낌)
          Positioned(
            left: -6,
            top: 10,
            bottom: 10,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* -------------------- 트레이 파일(드래그 가능) -------------------- */

class _TrayFile extends StatelessWidget {
  const _TrayFile({
    super.key,
    required this.member,
    required this.left,
    required this.height,
    required this.slideIn,
    required this.dragData,
  });

  final Member member;
  final double left;
  final double height;
  final bool slideIn;
  final _DragPayload dragData;

  @override
  Widget build(BuildContext context) {
    final slideOffset = slideIn ? const Offset(0.18, 0) : Offset.zero;

    final feedback = Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.85,
        child: Transform.scale(
          scale: 1.05,
          child: _A4MiniFileBody(member: member, height: height),
        ),
      ),
    );

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 170),
      curve: Curves.easeOutCubic,
      left: left,
      top: 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: slideOffset,
        child: LongPressDraggable<_DragPayload>(
          data: dragData,
          dragAnchorStrategy: pointerDragAnchorStrategy,
          feedback: feedback,
          childWhenDragging: Opacity(
            opacity: 0.35,
            child: _A4MiniFileBody(member: member, height: height),
          ),
          child: _A4MiniFileBody(member: member, height: height),
        ),
      ),
    );
  }
}

/* -------------------- 미니 파일 -------------------- */

class _A4MiniFileBody extends StatelessWidget {
  const _A4MiniFileBody({
    required this.member,
    required this.height,
  });

  final Member member;
  final double height;

  @override
  Widget build(BuildContext context) {
    final width = height / 1.414;

    final g = member.gender;
    Color a;
    Color b;

    if (g == Gender.female) {
      a = const Color(0xFFFFEEF7);
      b = const Color(0xFFFFB8D8);
    } else if (g == Gender.male) {
      a = const Color(0xFFEEF2FF);
      b = const Color(0xFFBFD3FF);
    } else {
      a = const Color(0xFFE6FFFB);
      b = const Color(0xFF99F6E4);
    }

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [a, b],
        ),
        border: Border.all(color: Colors.black.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 12,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.70),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.black.withOpacity(0.06)),
              ),
              child: Text(
                (member.name ?? member.id),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(
              4,
                  (i) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Container(
                  height: 4.5,
                  width: width * (0.78 - i * 0.10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
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

/* -------------------- 기타 UI -------------------- */

class _EmptyMainHint extends StatelessWidget {
  const _EmptyMainHint({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 22),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kPrimaryColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.inventory_2_outlined, color: kPrimaryColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------- 상단 헤더 -------------------- */

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
                Text(subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
              'Pinned $pinned/5',
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

/* -------------------- 더미 데이터 -------------------- */

List<Member> _demoMembers() {
  final now = DateTime.now();
  DateTime daysFromNow(int d) => now.add(Duration(days: d));
  DateTime daysAgo(int d) => now.subtract(Duration(days: d));

  return [
    Member(
      id: 'm001',
      name: '이순신',
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
      name: '홍길동',
      gender: Gender.male,
      phone: '010-3333-4444',
      totalSessions: 20,
      remainingSessions: 4,
      expireAt: daysFromNow(7),
      lastLogAt: daysAgo(1),
      memberStatus: '정상',
    ),
    Member(
      id: 'm003',
      name: '신사임당',
      gender: Gender.female,
      phone: '010-5555-6666',
      totalSessions: 10,
      remainingSessions: 0,
      expireAt: daysAgo(3),
      lastLogAt: daysAgo(10),
      memberStatus: '정상',
    ),
    Member(
      id: 'm004',
      name: '유관순',
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
      name: '세종대왕',
      gender: Gender.male,
      phone: '010-9999-0000',
      totalSessions: 12,
      remainingSessions: 2,
      expireAt: daysFromNow(5),
      lastLogAt: daysAgo(4),
      memberStatus: '휴면',
    ),
  ];
}