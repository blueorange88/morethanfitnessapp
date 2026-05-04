// lib/pages/binder_card_page.dart
import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:mtf_app/pages/client_card_page.dart';
import 'package:mtf_app/pages/contract_page.dart';
import 'package:mtf_app/pages/personal_training_log_page.dart';
import 'package:mtf_app/models/member.dart';

/// ---------- Theme ----------
const Color kPrimaryColor = Color(0xFF6366F1);
const Color kPrimaryColor2 = Color(0xFF8B5CF6);
const Color kBgColor = Color(0xFFF8FAFC);
const Color kBorderColor = Color(0xFFE2E8F0);
const Color kTextPrimary = Color(0xFF1E293B);
const Color kTextSecondary = Color(0xFF64748B);

/// Firestore members 문서에 저장할 그룹 필드명
const String kFilingGroupField = 'filingGroup';

enum _BinderSortType {
  recentLog,
  expireSoon,
  nameAsc,
  remainingLow,
}

String _sortLabel(_BinderSortType type) {
  switch (type) {
    case _BinderSortType.recentLog:
      return '최근 이용순';
    case _BinderSortType.expireSoon:
      return '만료 임박순';
    case _BinderSortType.nameAsc:
      return '이름순';
    case _BinderSortType.remainingLow:
      return '잔여 적은순';
  }
}

class BinderCardPage extends StatefulWidget {
  const BinderCardPage({super.key});

  @override
  State<BinderCardPage> createState() => _BinderCardPageState();
}

class RailGroup {
  RailGroup({
    required this.id,
    required this.name,
    required this.color,
  });

  final String id;
  String name;
  final Color color;
}

class _BinderCardPageState extends State<BinderCardPage> {
  final _qC = TextEditingController();
  Timer? _debounce;

  final Set<String> _pinnedIds = {};
  bool _holderOpen = false;
  int? _hoveredGroupIndex;

  String _query = '';
  _BinderSortType _sortType = _BinderSortType.recentLog;
  bool _sortAscending = true;

  /// null = 미분류 보기
  String? _selectedGroupId;

  /// 마지막으로 열어본 그룹
  String? _lastViewedGroupId;

  /// 이동 모드
  bool _moveMode = false;
  final Set<String> _selectedMoveIds = {};

  final List<RailGroup> _groups = [
    RailGroup(id: 'strategy', name: '그룹1', color: const Color(0xFF334155)),
    RailGroup(id: 'design', name: '그룹2', color: const Color(0xFFEC4899)),
    RailGroup(id: 'platform', name: '그룹3', color: const Color(0xFF10B981)),
    RailGroup(id: 'ops', name: '그룹4', color: const Color(0xFFF59E0B)),
    RailGroup(id: 'archive', name: '만료회원1', color: const Color(0xFF64748B)),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _qC.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {
        _query = _qC.text.trim();
      });
    });
  }

  bool _match(Member m, String kw) {
    if (kw.trim().isEmpty) return true;
    final k = kw.trim().toLowerCase();
    final kDigits = k.replaceAll(RegExp(r'\D'), '');

    final name = (m.name ?? '').toLowerCase();
    final trainer = (m.trainer ?? '').toLowerCase();
    final status = (m.memberStatus ?? '').toLowerCase();
    final phoneDigits = (m.phone ?? '').replaceAll(RegExp(r'\D'), '');

    return name.contains(k) ||
        trainer.contains(k) ||
        status.contains(k) ||
        (kDigits.isNotEmpty && phoneDigits.contains(kDigits));
  }

  bool _isPinned(Member m) => _pinnedIds.contains(m.id);

  bool _isSelectedForMove(String memberId) => _selectedMoveIds.contains(memberId);

  RailGroup? _groupById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final g in _groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  bool _isUngrouped(String? groupId) {
    return groupId == null || groupId.isEmpty || _groupById(groupId) == null;
  }

  String get _currentViewLabel {
    if (_selectedGroupId == null) return '미분류';
    return _groupById(_selectedGroupId)?.name ?? '그룹';
  }

  void _togglePin(Member m) {
    setState(() {
      if (_isPinned(m)) {
        _pinnedIds.remove(m.id);
      } else {
        if (_pinnedIds.length >= 5) {
          final first = _pinnedIds.first;
          _pinnedIds.remove(first);
        }
        _pinnedIds.add(m.id);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _pinnedIds.contains(m.id)
              ? '고정됨: ${m.name ?? m.id}'
              : '고정 해제: ${m.name ?? m.id}',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _toggleHolderFromHeader() {
    setState(() {
      if (_holderOpen) {
        _holderOpen = false;
        return;
      }

      _holderOpen = true;

      if (!_moveMode && _lastViewedGroupId != null) {
        _selectedGroupId = _lastViewedGroupId;
      }
    });
  }

  void _openHolderPanel() {
    if (_holderOpen) return;
    setState(() => _holderOpen = true);
  }

  void _selectGroupView(String? groupId, {bool closePanel = true}) {
    setState(() {
      _selectedGroupId = groupId;
      if (groupId != null) {
        _lastViewedGroupId = groupId;
      }
      if (closePanel) {
        _holderOpen = false;
      }
    });
  }

  void _resetToUngroupedView() {
    setState(() {
      _selectedGroupId = null;
    });
  }

  void _enterMoveMode({String? initialMemberId}) {
    setState(() {
      _holderOpen = true;

      if (_moveMode &&
          initialMemberId != null &&
          _selectedMoveIds.contains(initialMemberId)) {
        return;
      }

      // 첫 드래그는 단일 이동으로 처리.
      // 이동 완료 후에만 탭 선택을 쓰도록 moveMode는 여기서 켜지지 않음.
    });
  }

  void _exitMoveMode() {
    setState(() {
      _moveMode = false;
      _selectedMoveIds.clear();
      _hoveredGroupIndex = null;
      _holderOpen = false;
    });
  }

  void _toggleMoveSelection(String memberId) {
    setState(() {
      _moveMode = true;
      if (_selectedMoveIds.contains(memberId)) {
        _selectedMoveIds.remove(memberId);
      } else {
        _selectedMoveIds.add(memberId);
      }
    });
  }

  bool _shouldDragSelectedGroup(String draggedMemberId) {
    return _moveMode &&
        _selectedMoveIds.length > 1 &&
        _selectedMoveIds.contains(draggedMemberId);
  }

  Future<void> _updateMembersGroup(
      Iterable<String> memberIds, {
        String? groupId,
        required bool clear,
      }) async {
    final ids = memberIds.toList();
    if (ids.isEmpty) return;

    const chunkSize = 400;

    for (int i = 0; i < ids.length; i += chunkSize) {
      final end = (i + chunkSize > ids.length) ? ids.length : i + chunkSize;
      final chunk = ids.sublist(i, end);
      final batch = FirebaseFirestore.instance.batch();

      for (final id in chunk) {
        final ref = FirebaseFirestore.instance.collection('members').doc(id);
        if (clear) {
          batch.update(ref, {kFilingGroupField: FieldValue.delete()});
        } else {
          batch.update(ref, {kFilingGroupField: groupId});
        }
      }

      await batch.commit();
    }
  }

  Future<void> _handleDroppedMembers({
    required String draggedMemberId,
    required String? targetGroupId,
  }) async {
    final ids = _shouldDragSelectedGroup(draggedMemberId)
        ? _selectedMoveIds.toList()
        : <String>[draggedMemberId];

    final count = ids.length;
    final targetName =
    targetGroupId == null ? '미분류' : (_groupById(targetGroupId)?.name ?? '그룹');

    if (targetGroupId == null) {
      await _updateMembersGroup(ids, clear: true);
    } else {
      await _updateMembersGroup(ids, groupId: targetGroupId, clear: false);
      _lastViewedGroupId = targetGroupId;
    }

    if (!mounted) return;

    setState(() {
      _hoveredGroupIndex = null;
      _moveMode = true;
      _selectedMoveIds.clear();
      _holderOpen = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$count명 → $targetName 이동 완료'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _selectAllVisible(List<Member> visibleMembers) {
    setState(() {
      _moveMode = true;
      _holderOpen = true;
      _selectedMoveIds.addAll(visibleMembers.map((m) => m.id));
    });
  }

  void _clearMoveSelection() {
    setState(() {
      _selectedMoveIds.clear();
    });
  }

  Future<void> _openJournal(Member m) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonalTrainingLogPage(
          memberId: m.id,
          memberName: m.name ?? '',
          trainerName: m.trainer ?? '',
          memberPhone: m.phone ?? '',
        ),
      ),
    );
  }

  Future<void> _openEdit(Member m) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientCardPage.edit(
          memberId: m.id,
          initialName: m.name,
        ),
      ),
    );
  }

  Future<void> _openContract(Member m) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContractPage(
          memberId: m.id,
          memberName: m.name ?? '',
          trainerName: m.trainer ?? '',
        ),
      ),
    );
  }

  Future<void> _openCreate() async {
    final newId = FirebaseFirestore.instance.collection('members').doc().id;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientCardPage.newMember(memberId: newId),
      ),
    );
  }

  Future<void> _renameGroup(int index) async {
    final controller = TextEditingController(text: _groups[index].name);

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('그룹 이름 변경'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '그룹 이름 입력',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('저장'),
            ),
          ],
        );
      },
    );

    if (!mounted) return;
    if (result == null || result.isEmpty) return;

    setState(() {
      _groups[index].name = result;
    });
  }

  void _sortMembers(List<Member> list) {
    list.sort((a, b) {
      int result = 0;

      switch (_sortType) {
        case _BinderSortType.recentLog:
          final aDate = a.lastLogAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.lastLogAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          result = bDate.compareTo(aDate);
          break;

        case _BinderSortType.expireSoon:
          final aDate = a.expireAt ?? DateTime(9999);
          final bDate = b.expireAt ?? DateTime(9999);
          result = aDate.compareTo(bDate);
          break;

        case _BinderSortType.nameAsc:
          result = (a.name ?? a.id).compareTo(b.name ?? b.id);
          break;

        case _BinderSortType.remainingLow:
          result = a.remainingSessions.compareTo(b.remainingSessions);
          break;
      }

      if (!_sortAscending) {
        result = -result;
      }

      if (result != 0) return result;
      return (a.name ?? a.id).compareTo(b.name ?? b.id);
    });
  }

  List<Member> _applyPinnedOrder(List<Member> input) {
    final pinned = input.where((m) => _pinnedIds.contains(m.id)).toList();
    final rest = input.where((m) => !_pinnedIds.contains(m.id)).toList();

    _sortMembers(pinned);
    _sortMembers(rest);

    return [...pinned, ...rest];
  }

  @override
  Widget build(BuildContext context) {
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
                  currentViewLabel: _currentViewLabel,
                  moveMode: _moveMode,
                  selectedCount: _selectedMoveIds.length,
                  onMenuTap: _toggleHolderFromHeader,
                  onBack: () => Navigator.of(context).maybePop(),
                  onCreateMember: _openCreate,
                  onResetView:
                  _selectedGroupId == null ? null : _resetToUngroupedView,
                  onExitMoveMode: _moveMode ? _exitMoveMode : null,
                ),
                _SearchSortBar(
                  controller: _qC,
                  sortType: _sortType,
                  sortAscending: _sortAscending,
                  onChanged: (_) => _onSearchChanged(),
                  onClear: () {
                    _qC.clear();
                    setState(() => _query = '');
                  },
                  onSortChanged: (value) {
                    if (value == null) return;
                    setState(() => _sortType = value);
                  },
                  onToggleOrder: () {
                    setState(() => _sortAscending = !_sortAscending);
                  },
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream:
                    FirebaseFirestore.instance.collection('members').snapshots(),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting &&
                          !snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snap.hasError) {
                        return Center(
                          child: Text('불러오기 실패: ${snap.error}'),
                        );
                      }

                      final docs = snap.data?.docs ?? [];

                      final filingMap = <String, String?>{
                        for (final d in docs)
                          d.id: (d.data()[kFilingGroupField] as String?)
                      };

                      final members = docs
                          .map((d) => Member.fromFirestore(d.id, d.data()))
                          .where((m) => _match(m, _query))
                          .where((m) {
                        final groupId = filingMap[m.id];
                        if (_selectedGroupId == null) {
                          return _isUngrouped(groupId);
                        }
                        return groupId == _selectedGroupId;
                      }).toList();

                      final ordered = _applyPinnedOrder(members);

                      return Column(
                        children: [
                          if (_moveMode)
                            _MoveModeBar(
                              selectedCount: _selectedMoveIds.length,
                              visibleCount: ordered.length,
                              onSelectAll: ordered.isEmpty
                                  ? null
                                  : () => _selectAllVisible(ordered),
                              onClearSelection:
                              _selectedMoveIds.isEmpty ? null : _clearMoveSelection,
                              onDone: _exitMoveMode,
                            ),
                          Expanded(
                            child: ordered.isEmpty
                                ? _EmptyState(
                              onCreate: _openCreate,
                              keyword: _query,
                              viewLabel: _currentViewLabel,
                            )
                                : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                10,
                                16,
                                20,
                              ),
                              itemCount: ordered.length,
                              itemBuilder: (context, i) {
                                final m = ordered[i];
                                final groupId = filingMap[m.id];
                                final group = _groupById(groupId);

                                return _DraggableMemberRow(
                                  member: m,
                                  pinned: _isPinned(m),
                                  holderOpen: _holderOpen,
                                  group: group,
                                  moveMode: _moveMode,
                                  selectedForMove: _isSelectedForMove(m.id),
                                  selectedCount: _selectedMoveIds.length,
                                  onPinTap: () => _togglePin(m),
                                  onDragStarted: () =>
                                      _enterMoveMode(initialMemberId: m.id),
                                  onMoveTap: () => _toggleMoveSelection(m.id),
                                  onOpenJournal: () => _openJournal(m),
                                  onOpenEdit: () => _openEdit(m),
                                  onOpenContract: () => _openContract(m),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            if (_holderOpen)
              GestureDetector(
                onTap: () => setState(() => _holderOpen = false),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _holderOpen ? 1 : 0,
                  child: Container(color: Colors.black26),
                ),
              ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              left: _holderOpen ? 0 : -292,
              top: 0,
              bottom: 0,
              width: 292,
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                FirebaseFirestore.instance.collection('members').snapshots(),
                builder: (context, snap) {
                  final docs = snap.data?.docs ?? [];

                  final groupCounts = <String, int>{
                    for (final g in _groups) g.id: 0,
                  };
                  int ungroupedCount = 0;

                  for (final d in docs) {
                    final gid = d.data()[kFilingGroupField] as String?;
                    if (_isUngrouped(gid)) {
                      ungroupedCount++;
                    } else if (gid != null && groupCounts.containsKey(gid)) {
                      groupCounts[gid] = (groupCounts[gid] ?? 0) + 1;
                    }
                  }

                  return _ModernHolderPanel(
                    groups: _groups,
                    hoveredGroupIndex: _hoveredGroupIndex,
                    selectedGroupId: _selectedGroupId,
                    groupCounts: groupCounts,
                    ungroupedCount: ungroupedCount,
                    moveMode: _moveMode,
                    selectedMoveCount: _selectedMoveIds.length,
                    onHoverChanged: (value) =>
                        setState(() => _hoveredGroupIndex = value),
                    onAccept: (memberId, groupIndex) async {
                      await _handleDroppedMembers(
                        draggedMemberId: memberId,
                        targetGroupId: _groups[groupIndex].id,
                      );
                    },
                    onClearGroup: (memberId) async {
                      await _handleDroppedMembers(
                        draggedMemberId: memberId,
                        targetGroupId: null,
                      );
                    },
                    onRenameGroup: _renameGroup,
                    onSelectGroup: (groupId) {
                      if (_moveMode && _selectedMoveIds.isNotEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '선택한 카드 중 하나를 롱프레스해서 그룹 박스로 드롭하세요.',
                            ),
                            duration: Duration(seconds: 1),
                          ),
                        );
                        return;
                      }

                      _selectGroupView(groupId, closePanel: true);
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

/* -------------------- Header -------------------- */

class _ModernHeader extends StatelessWidget {
  const _ModernHeader({
    required this.pinnedCount,
    required this.holderOpen,
    required this.currentViewLabel,
    required this.moveMode,
    required this.selectedCount,
    required this.onMenuTap,
    required this.onBack,
    required this.onCreateMember,
    required this.onResetView,
    required this.onExitMoveMode,
  });

  final int pinnedCount;
  final bool holderOpen;
  final String currentViewLabel;
  final bool moveMode;
  final int selectedCount;
  final VoidCallback onMenuTap;
  final VoidCallback onBack;
  final VoidCallback onCreateMember;
  final VoidCallback? onResetView;
  final VoidCallback? onExitMoveMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
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
                margin: const EdgeInsets.only(right: 8),
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: onCreateMember,
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                label: const Text('신규등록회원'),
                style: FilledButton.styleFrom(
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.white,
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _HolderToggleButton(
                isOpen: holderOpen,
                onTap: onMenuTap,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CurrentViewChip(
                  label: currentViewLabel,
                  onReset: onResetView,
                ),
              ),
              if (moveMode) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '이동 모드 · $selectedCount명',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: kPrimaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onExitMoveMode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: kBorderColor),
                    ),
                    child: const Text(
                      '종료',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: kTextSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CurrentViewChip extends StatelessWidget {
  const _CurrentViewChip({
    required this.label,
    required this.onReset,
  });

  final String label;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inbox_rounded,
            size: 16,
            color: kPrimaryColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '현재 보기: $label',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: kTextPrimary,
              ),
            ),
          ),
          if (onReset != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onReset,
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  '미분류로',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: kPrimaryColor,
                  ),
                ),
              ),
            ),
          ],
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
      tooltip: '그룹 보관함',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(
            Icons.inbox_rounded,
            size: 20,
            color: kPrimaryColor,
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

class _SearchSortBar extends StatelessWidget {
  const _SearchSortBar({
    required this.controller,
    required this.sortType,
    required this.sortAscending,
    required this.onChanged,
    required this.onClear,
    required this.onSortChanged,
    required this.onToggleOrder,
  });

  final TextEditingController controller;
  final _BinderSortType sortType;
  final bool sortAscending;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final ValueChanged<_BinderSortType?> onSortChanged;
  final VoidCallback onToggleOrder;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          Expanded(
            flex: 8,
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorderColor),
              ),
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                decoration: InputDecoration(
                  hintText: '이름 / 담당 / 연락처',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: kTextSecondary,
                  ),
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.clear_rounded),
                  )
                      : null,
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                ),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 128,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kBorderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<_BinderSortType>(
                  value: sortType,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.unfold_more_rounded,
                    size: 18,
                    color: kTextSecondary,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                  ),
                  items: _BinderSortType.values.map((type) {
                    return DropdownMenuItem<_BinderSortType>(
                      value: type,
                      child: Text(
                        _sortLabel(type),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: onSortChanged,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 46,
            height: 46,
            child: IconButton.filledTonal(
              onPressed: onToggleOrder,
              tooltip: sortAscending ? '오름차순' : '내림차순',
              icon: Icon(
                sortAscending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 18,
              ),
              style: IconButton.styleFrom(
                backgroundColor: kPrimaryColor.withOpacity(0.10),
                foregroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoveModeBar extends StatelessWidget {
  const _MoveModeBar({
    required this.selectedCount,
    required this.visibleCount,
    required this.onSelectAll,
    required this.onClearSelection,
    required this.onDone,
  });

  final int selectedCount;
  final int visibleCount;
  final VoidCallback? onSelectAll;
  final VoidCallback? onClearSelection;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: kPrimaryColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kPrimaryColor.withOpacity(0.18)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.touch_app_rounded,
              size: 18,
              color: kPrimaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selectedCount == 0
                    ? '이동 모드입니다. 카드를 탭해 선택하거나 카드를 롱프레스해 이동하세요.'
                    : '$selectedCount명 선택됨 · 선택된 카드 중 하나를 롱프레스해서 그룹 박스로 드롭하세요.',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                ),
              ),
            ),
            TextButton(
              onPressed: visibleCount == 0 ? null : onSelectAll,
              child: const Text('전체선택'),
            ),
            TextButton(
              onPressed: selectedCount == 0 ? null : onClearSelection,
              child: const Text('선택해제'),
            ),
            FilledButton(
              onPressed: onDone,
              style: FilledButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('완료'),
            ),
          ],
        ),
      ),
    );
  }
}

/* -------------------- Empty -------------------- */

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onCreate,
    required this.keyword,
    required this.viewLabel,
  });

  final VoidCallback onCreate;
  final String keyword;
  final String viewLabel;

  @override
  Widget build(BuildContext context) {
    final hasKeyword = keyword.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kBorderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.folder_off_outlined,
                size: 42,
                color: kTextSecondary,
              ),
              const SizedBox(height: 10),
              Text(
                hasKeyword ? '검색 결과가 없어요.' : '$viewLabel에 회원이 없어요.',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                hasKeyword
                    ? '다른 키워드로 검색해보세요.'
                    : '박스 아이콘으로 다른 그룹을 열거나 신규 회원을 등록해보세요.',
                style: const TextStyle(
                  color: kTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('신규 회원 등록'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------- Holder Panel -------------------- */

class _ModernHolderPanel extends StatelessWidget {
  const _ModernHolderPanel({
    required this.groups,
    required this.hoveredGroupIndex,
    required this.selectedGroupId,
    required this.groupCounts,
    required this.ungroupedCount,
    required this.moveMode,
    required this.selectedMoveCount,
    required this.onHoverChanged,
    required this.onAccept,
    required this.onClearGroup,
    required this.onRenameGroup,
    required this.onSelectGroup,
  });

  final List<RailGroup> groups;
  final int? hoveredGroupIndex;
  final String? selectedGroupId;
  final Map<String, int> groupCounts;
  final int ungroupedCount;
  final bool moveMode;
  final int selectedMoveCount;
  final ValueChanged<int?> onHoverChanged;
  final Future<void> Function(String memberId, int groupIndex) onAccept;
  final Future<void> Function(String memberId) onClearGroup;
  final void Function(int groupIndex) onRenameGroup;
  final ValueChanged<String?> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    final helperText = moveMode
        ? (selectedMoveCount == 0
        ? '카드를 탭해 선택하고, 선택된 카드 중 하나를 롱프레스해 여기로 드롭하세요.'
        : '$selectedMoveCount명 선택됨 · 선택된 카드 중 하나를 롱프레스해 여기로 드롭하세요.')
        : '그룹을 탭하면 해당 그룹을 엽니다.';

    return Material(
      elevation: 20,
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 6),
              child: Text(
                'GROUP BOXES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: kTextSecondary,
                  letterSpacing: 2,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                helperText,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kTextSecondary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: DragTarget<String>(
                onWillAcceptWithDetails: (_) {
                  onHoverChanged(null);
                  return true;
                },
                onAcceptWithDetails: (details) async {
                  await onClearGroup(details.data);
                },
                builder: (context, candidate, _) {
                  final hovered = candidate.isNotEmpty;
                  final selected = selectedGroupId == null;
                  return InkWell(
                    onTap: () => onSelectGroup(null),
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: hovered
                            ? Colors.red.withOpacity(0.08)
                            : selected
                            ? kPrimaryColor.withOpacity(0.08)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: hovered
                              ? const Color(0xFFEF4444)
                              : selected
                              ? kPrimaryColor
                              : kBorderColor,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.remove_circle_outline_rounded,
                            color: hovered
                                ? const Color(0xFFEF4444)
                                : selected
                                ? kPrimaryColor
                                : kTextSecondary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '미분류',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: kTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$ungroupedCount명',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: selected
                                        ? kPrimaryColor
                                        : kTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
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
                    onAcceptWithDetails: (details) async {
                      await onAccept(details.data, i);
                    },
                    builder: (context, candidate, _) {
                      final isHovered =
                          hoveredGroupIndex == i || candidate.isNotEmpty;
                      final isSelected = selectedGroupId == group.id;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isHovered || isSelected
                              ? group.color.withOpacity(0.14)
                              : Colors.grey[50],
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isHovered || isSelected
                                ? group.color
                                : kBorderColor,
                            width: 1.5,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => onSelectGroup(group.id),
                          borderRadius: BorderRadius.circular(18),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: isHovered || isSelected
                                        ? group.color.withOpacity(0.18)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.inbox_rounded,
                                    color: isHovered || isSelected
                                        ? group.color
                                        : kTextSecondary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
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
                                        '${groupCounts[group.id] ?? 0}명',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isHovered || isSelected
                                              ? group.color
                                              : kTextSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => onRenameGroup(i),
                                  tooltip: '이름 변경',
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    size: 18,
                                    color: kTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
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

/* -------------------- Member Row -------------------- */

class _DraggableMemberRow extends StatelessWidget {
  const _DraggableMemberRow({
    required this.member,
    required this.pinned,
    required this.holderOpen,
    required this.group,
    required this.moveMode,
    required this.selectedForMove,
    required this.selectedCount,
    required this.onPinTap,
    required this.onDragStarted,
    required this.onMoveTap,
    required this.onOpenJournal,
    required this.onOpenEdit,
    required this.onOpenContract,
  });

  final Member member;
  final bool pinned;
  final bool holderOpen;
  final RailGroup? group;
  final bool moveMode;
  final bool selectedForMove;
  final int selectedCount;
  final VoidCallback onPinTap;
  final VoidCallback onDragStarted;
  final VoidCallback onMoveTap;
  final Future<void> Function() onOpenJournal;
  final Future<void> Function() onOpenEdit;
  final Future<void> Function() onOpenContract;

  @override
  Widget build(BuildContext context) {
    final card = _MemberCardContent(
      member: member,
      pinned: pinned,
      holderOpen: holderOpen,
      group: group,
      moveMode: moveMode,
      selectedForMove: selectedForMove,
      onCardTap: moveMode ? onMoveTap : null,
      onPinTap: onPinTap,
      onOpenJournal: onOpenJournal,
      onOpenEdit: onOpenEdit,
      onOpenContract: onOpenContract,
    );

    final multiDrag = moveMode && selectedForMove && selectedCount > 1;

    final feedbackChild = multiDrag
        ? _MultiDragFeedback(count: selectedCount)
        : _SingleDragFeedback(
      member: member,
      group: group,
    );

    return LongPressDraggable<String>(
      data: member.id,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: onDragStarted,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 260,
          child: Opacity(opacity: 0.94, child: feedbackChild),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.32, child: card),
      child: card,
    );
  }
}

class _SingleDragFeedback extends StatelessWidget {
  const _SingleDragFeedback({
    required this.member,
    required this.group,
  });

  final Member member;
  final RailGroup? group;

  @override
  Widget build(BuildContext context) {
    final groupName = group?.name ?? '미분류';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kPrimaryColor, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 42,
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kPrimaryColor.withOpacity(0.18)),
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 18,
              color: kPrimaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (member.name ?? member.id).trim().isEmpty
                      ? '회원'
                      : (member.name ?? member.id).trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '총 ${member.totalSessions} / 남 ${member.remainingSessions}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: kTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: kBorderColor),
            ),
            child: Text(
              groupName,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: kTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MultiDragFeedback extends StatelessWidget {
  const _MultiDragFeedback({
    required this.count,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kPrimaryColor, width: 1.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.layers_rounded,
              color: kPrimaryColor,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$count명 이동',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: kTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberCardContent extends StatelessWidget {
  const _MemberCardContent({
    required this.member,
    required this.pinned,
    required this.holderOpen,
    required this.group,
    required this.moveMode,
    required this.selectedForMove,
    required this.onCardTap,
    required this.onPinTap,
    required this.onOpenJournal,
    required this.onOpenEdit,
    required this.onOpenContract,
  });

  final Member member;
  final bool pinned;
  final bool holderOpen;
  final RailGroup? group;
  final bool moveMode;
  final bool selectedForMove;
  final VoidCallback? onCardTap;
  final VoidCallback onPinTap;
  final Future<void> Function() onOpenJournal;
  final Future<void> Function() onOpenEdit;
  final Future<void> Function() onOpenContract;

  @override
  Widget build(BuildContext context) {
    final groupColor = group?.color ?? const Color(0xFFCBD5E1);
    final groupName = group?.name ?? '미분류';

    final isExpired =
        member.expireAt != null && member.expireAt!.isBefore(DateTime.now());

    final isLowRemaining = !isExpired && member.remainingSessions < 5;

    Color genderBg = const Color(0xFFF1F5F9);
    Color genderText = const Color(0xFF475569);
    String genderLabel = '미지정';

    if (member.gender == Gender.male) {
      genderBg = const Color(0xFFE0F2FE);
      genderText = const Color(0xFF0369A1);
      genderLabel = '남성';
    } else if (member.gender == Gender.female) {
      genderBg = const Color(0xFFFCE7F3);
      genderText = const Color(0xFFBE185D);
      genderLabel = '여성';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onCardTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: selectedForMove
                ? kPrimaryColor.withOpacity(0.06)
                : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selectedForMove ? kPrimaryColor : kBorderColor,
              width: selectedForMove ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _MemberDonutBadge(member: member),
                      if (moveMode)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: selectedForMove
                                  ? kPrimaryColor
                                  : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: selectedForMove
                                    ? kPrimaryColor
                                    : kBorderColor,
                              ),
                            ),
                            child: Icon(
                              selectedForMove
                                  ? Icons.check
                                  : Icons.radio_button_unchecked,
                              size: 14,
                              color: selectedForMove
                                  ? Colors.white
                                  : kTextSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _StatusBanner(
                              text: genderLabel,
                              backgroundColor: genderBg,
                              textColor: genderText,
                            ),
                            if (isExpired)
                              const _StatusBanner(
                                text: '만료회원',
                                backgroundColor: Color(0xFFE5E7EB),
                                textColor: Color(0xFF374151),
                              ),
                            if (isLowRemaining)
                              const _StatusBanner(
                                text: '잔여 5회 미만',
                                backgroundColor: Color(0xFFFEE2E2),
                                textColor: Color(0xFFB91C1C),
                              ),
                            if (moveMode)
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
                                  '탭하여 선택',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: kPrimaryColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (member.name ?? member.id).trim().isEmpty
                              ? '회원'
                              : (member.name ?? member.id).trim(),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
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
                              text:
                              '${member.remainingSessions}/${member.totalSessions}',
                            ),
                            if (holderOpen)
                              const _MetaChip(
                                icon: Icons.swipe_left_alt_rounded,
                                text: '롱프레스 후 분류',
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onPinTap,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 38,
                      height: 38,
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
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: moveMode ? null : onOpenContract,
                      icon: const Icon(Icons.people_alt_outlined, size: 18),
                      label: const Text('계약서'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kTextPrimary,
                        side: const BorderSide(color: kBorderColor),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: moveMode ? null : onOpenEdit,
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('고객카드 수정'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimaryColor,
                        side: BorderSide(color: kPrimaryColor.withOpacity(0.30)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: moveMode ? null : onOpenJournal,
                      icon: const Icon(Icons.fitness_center_rounded, size: 18),
                      label: const Text('운동기록일지'),
                      style: FilledButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* -------------------- Donut -------------------- */

class _MemberDonutBadge extends StatelessWidget {
  const _MemberDonutBadge({required this.member});

  final Member member;

  @override
  Widget build(BuildContext context) {
    final total = member.totalSessions <= 0 ? 1 : member.totalSessions;
    final used =
    (member.totalSessions - member.remainingSessions).clamp(0, total);
    final progress = (used / total).clamp(0.0, 1.0);

    final accent = _progressColor(member.remainingSessions, total);

    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        shape: BoxShape.circle,
        border: Border.all(color: kBorderColor),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(52, 52),
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

/* -------------------- Chips -------------------- */

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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.text,
    required this.backgroundColor,
    required this.textColor,
  });

  final String text;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: textColor,
        ),
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