import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/member.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'client_card_page.dart';
import 'personal_training_log_page.dart';

const Color kClientBgColor = Color(0xFFF3F4F6);
const Color kClientCardColor = Colors.white;
const Color kClientBorderColor = Color(0xFFE5E7EB);
const double kClientPageHorizontalPadding = 16;
const double kClientMaxContentWidth = 480;

class ClientListPage extends StatelessWidget {
    const ClientListPage({super.key});

    @override
    Widget build(BuildContext context) {
        return const MemberDashboardPage();
    }
}

class MemberDashboardPage extends StatefulWidget {
    const MemberDashboardPage({super.key});

    @override
    State<MemberDashboardPage> createState() => _MemberDashboardPageState();
}

class _MemberDashboardPageState extends State<MemberDashboardPage> {
    static const String _adminRestorePin = '0000';
    final TextEditingController _searchController = TextEditingController();
    final ValueNotifier<String> _searchKeywordNotifier = ValueNotifier<String>('');
    final GlobalKey<_DashboardBlueHeaderState> _headerKey = GlobalKey<_DashboardBlueHeaderState>();
    final ScrollController _scrollController = ScrollController();
    final Map<String, GlobalKey> _memberItemKeys = <String, GlobalKey>{};
    final ValueNotifier<String?> _highlightNotifier = ValueNotifier<String?>(null);
    int _highlightRequestToken = 0;

    bool _sortAscending = true;

    DateTime? _selectedLessonDate;
    SortOption _sortOption = SortOption.name;

    final ValueNotifier<List<String>> _pinnedMemberIdsNotifier =
    ValueNotifier<List<String>>(<String>[]);

    final ValueNotifier<bool> _isGroupingModeNotifier =
    ValueNotifier<bool>(false);

    final ValueNotifier<Set<String>> _selectedGroupMemberIdsNotifier =
    ValueNotifier<Set<String>>(<String>{});

    static const String _ungroupedGroupId = '__ungrouped__';

    static const String _systemDormantGroupId = '__system_dormant__';
    static const String _systemExpiredGroupId = '__system_expired__';

    static const List<String> _systemGroupIds = <String>[
        _systemDormantGroupId,
        _systemExpiredGroupId,
    ];

    final List<String> _groupIds = [];
    final Map<String, String> _groupNames = {
        _ungroupedGroupId: 'More Than GYM',
    };

    String get _headerSelectedGroupLabel {
        if (_selectedGroupId == null) return '전체';
        return _groupLabel(_selectedGroupId!);
    }

    List<_MemberCardGroupMenuItem> _buildHeaderGroupFilterItems() {
        return <_MemberCardGroupMenuItem>[
            const _MemberCardGroupMenuItem(
                id: '__all__',
                label: '전체',
                icon: Icons.dashboard_rounded,
            ),
            ..._groupIds.map(
                    (groupId) => _MemberCardGroupMenuItem(
                    id: groupId,
                    label: _groupLabel(groupId),
                    icon: Icons.folder_open_rounded,
                ),
            ),
            _MemberCardGroupMenuItem(
                id: _systemDormantGroupId,
                label: _groupLabel(_systemDormantGroupId),
                icon: Icons.bedtime_rounded,
            ),
            _MemberCardGroupMenuItem(
                id: _systemExpiredGroupId,
                label: _groupLabel(_systemExpiredGroupId),
                icon: Icons.warning_amber_rounded,
            ),
        ];
    }

    final ValueNotifier<String?> _selectedGroupIdNotifier =
    ValueNotifier<String?>(null);

    int _nextGroupNumber = 4;

    final ValueNotifier<Map<String, String>> _memberGroupMapNotifier =
    ValueNotifier<Map<String, String>>(<String, String>{});

    @override
    void dispose() {
        _searchController.dispose();
        _searchKeywordNotifier.dispose();
        _scrollController.dispose();
        _highlightNotifier.dispose();
        _pinnedMemberIdsNotifier.dispose();
        _isGroupingModeNotifier.dispose();
        _selectedGroupMemberIdsNotifier.dispose();
        _selectedGroupIdNotifier.dispose();
        _memberGroupMapNotifier.dispose();
        super.dispose();
    }

    @override
    void initState() {
        super.initState();
        _loadGroups();
    }

    Map<String, String> _defaultGroupNames() {
        return <String, String>{
            _ungroupedGroupId: 'More Than Fitness',
            _systemDormantGroupId: '휴면회원',
            _systemExpiredGroupId: '만료회원',
        };
    }

    Future<Map<String, String>> _loadMemberGroupMapOnly() async {
        final memberSnap = await FirebaseFirestore.instance
            .collection('members')
            .get();

        final memberGroupMap = <String, String>{};

        for (final doc in memberSnap.docs) {
            final data = doc.data();
            final groupId = (data['groupId'] ?? '').toString().trim();

            if (groupId.isNotEmpty &&
                groupId != _systemDormantGroupId &&
                groupId != _systemExpiredGroupId) {
                memberGroupMap[doc.id] = groupId;
            }
        }

        return memberGroupMap;
    }

    Future<void> _loadGroups() async {
        final fallbackNames = _defaultGroupNames();

        try {
            final groupCollection =
            FirebaseFirestore.instance.collection('member_groups');

            final groupSnap = await groupCollection.get();

            final loadedIds = <String>[];
            final loadedNames = <String, String>{...fallbackNames};

            for (final doc in groupSnap.docs) {
                final data = doc.data();
                final bool isArchived = data['isArchived'] == true;
                if (isArchived) continue;

                final bool isSystem = data['isSystem'] == true;
                final String name = (data['name'] ?? '').toString().trim();

                loadedNames[doc.id] = name.isEmpty ? doc.id : name;

                if (!isSystem &&
                    doc.id != _systemDormantGroupId &&
                    doc.id != _systemExpiredGroupId) {
                    loadedIds.add(doc.id);
                }
            }

            loadedIds.sort((a, b) {
                int orderOf(String id) {
                    final doc = groupSnap.docs.where((e) => e.id == id);
                    if (doc.isEmpty) return 9999;
                    final raw = doc.first.data()['order'];
                    return raw is num ? raw.toInt() : 9999;
                }

                return orderOf(a).compareTo(orderOf(b));
            });

            final memberGroupMap = await _loadMemberGroupMapOnly();

            if (!mounted) return;

            setState(() {
                _groupIds
                    ..clear()
                    ..addAll(loadedIds);

                _groupNames
                    ..clear()
                    ..addAll(loadedNames);
            });

            _setMemberGroupMap(memberGroupMap);

            int maxNumber = 0;
            for (final id in loadedIds) {
                final match = RegExp(r'^group_(\d+)$').firstMatch(id);
                final number = int.tryParse(match?.group(1) ?? '');
                if (number != null && number > maxNumber) {
                    maxNumber = number;
                }
            }

            _nextGroupNumber = maxNumber + 1;
            if (_nextGroupNumber < 3) {
                _nextGroupNumber = 3;
            }
        } catch (e) {
            try {
                final memberGroupMap = await _loadMemberGroupMapOnly();

                if (!mounted) return;

                setState(() {
                    _groupIds.clear();
                    _groupNames
                        ..clear()
                        ..addAll(fallbackNames);
                });

                _setMemberGroupMap(memberGroupMap);
                _nextGroupNumber = 3;
            } catch (_) {
                if (!mounted) return;

                setState(() {
                    _groupIds.clear();
                    _groupNames
                        ..clear()
                        ..addAll(fallbackNames);
                });

                _setMemberGroupMap(<String, String>{});
                _nextGroupNumber = 3;
            }
        }
    }

    bool get _isGroupingMode => _isGroupingModeNotifier.value;

    Set<String> get _selectedGroupMemberIds =>
        _selectedGroupMemberIdsNotifier.value;

    List<String> get _pinnedMemberIds => _pinnedMemberIdsNotifier.value;

    String? get _selectedGroupId => _selectedGroupIdNotifier.value;

    Map<String, String> get _memberGroupMap => _memberGroupMapNotifier.value;

    void _setGroupingMode(bool value) {
        if (_isGroupingModeNotifier.value == value) return;
        _isGroupingModeNotifier.value = value;
    }

    void _setSelectedGroupMemberIds(Set<String> value) {
        _selectedGroupMemberIdsNotifier.value = Set<String>.from(value);
    }

    void _setPinnedMemberIds(List<String> value) {
        _pinnedMemberIdsNotifier.value = List<String>.from(value);
    }

    void _setSelectedGroupId(String? value) {
        if (_selectedGroupIdNotifier.value == value) return;
        _selectedGroupIdNotifier.value = value;
    }

    void _setMemberGroupMap(Map<String, String> value) {
        _memberGroupMapNotifier.value = Map<String, String>.from(value);
    }

    void _closeHeaderOverlayIfNeeded() {
        _headerKey.currentState?.closeOverlayFromOutside();
    }

    Future<void> _collapseHeaderIfExpanded() async {
        final headerState = _headerKey.currentState;
        if (headerState == null) return;

        if (headerState.isExpanded) {
            headerState.closeOverlayFromOutside();
            await Future.delayed(const Duration(milliseconds: 260));
        }
    }

    void _highlightMember(String? memberId) {
        if (memberId == null) {
            if (_highlightNotifier.value != null) {
                _highlightNotifier.value = null;
            }
            return;
        }

        if (_highlightNotifier.value == memberId) {
            _highlightNotifier.value = null;
            WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _highlightNotifier.value = memberId;
            });
            return;
        }

        _highlightNotifier.value = memberId;
    }

    int _issueHighlightToken() {
        _highlightRequestToken++;
        return _highlightRequestToken;
    }

    bool _isLatestHighlightToken(int token) {
        return _highlightRequestToken == token;
    }

    Future<void> scrollToMember(String memberId) async {
        final int token = _issueHighlightToken();

        await _collapseHeaderIfExpanded();
        await Future.delayed(const Duration(milliseconds: 30));

        final targetContext = _memberItemKeys[memberId]?.currentContext;
        if (targetContext == null) return;

        final renderObject = targetContext.findRenderObject();
        if (renderObject == null || !renderObject.attached || renderObject is! RenderBox) {
            return;
        }

        final scrollableState = Scrollable.of(targetContext);
        final viewportObject = scrollableState?.context.findRenderObject();
        if (viewportObject == null || viewportObject is! RenderBox) return;

        final position = _scrollController.position;

        const double pinnedHeaderHeight = 92;
        const double topSafeSpacing = 12;
        const double thumbReachOffset = 72;

        final RenderBox itemBox = renderObject;
        final RenderBox viewportBox = viewportObject;

        final Offset itemTopLeftInViewport = itemBox.localToGlobal(
            Offset.zero,
            ancestor: viewportBox,
        );

        final double itemTop = itemTopLeftInViewport.dy;
        final double itemHeight = itemBox.size.height > 0 ? itemBox.size.height : 140;
        final double itemCenter = itemTop + (itemHeight / 2);

        final double visibleTop = pinnedHeaderHeight + topSafeSpacing;
        final double visibleBottom = viewportBox.size.height;
        final double visibleCenter =
            visibleTop + ((visibleBottom - visibleTop) / 2) + thumbReachOffset;

        final double delta = itemCenter - visibleCenter;

        final double targetOffset = (position.pixels + delta).clamp(
            position.minScrollExtent,
            position.maxScrollExtent,
        );

        await _scrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 460),
            curve: Curves.easeOutCubic,
        );

        if (!mounted || !_isLatestHighlightToken(token)) return;

        await Future.delayed(const Duration(milliseconds: 80));

        if (!mounted || !_isLatestHighlightToken(token)) return;
        _highlightMember(memberId);

        await Future.delayed(const Duration(milliseconds: 900));

        if (!mounted || !_isLatestHighlightToken(token)) return;
        if (_highlightNotifier.value == memberId) {
            _highlightMember(null);
        }
    }

    @override
    Widget build(BuildContext context) {
        return LayoutBuilder(
            builder: (context, constraints) {
                final bool isTablet = constraints.maxWidth >= 600;
                final double width =
                isTablet ? kClientMaxContentWidth : constraints.maxWidth;

                final scaffold = Scaffold(
                    backgroundColor: kClientBgColor,
                    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance.collection('members').snapshots(),
                        builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                                return const Center(
                                    child: CircularProgressIndicator(),
                                );
                            }

                            if (snapshot.hasError) {
                                return Center(
                                    child: Padding(
                                        padding: const EdgeInsets.all(24),
                                        child: Text(
                                            '회원 데이터를 불러오는 중 오류가 발생했어요.\n${snapshot.error}',
                                            textAlign: TextAlign.center,
                                        ),
                                    ),
                                );
                            }

                            final docs = snapshot.data?.docs ?? [];

                            final visibleDocs = docs.where((doc) {
                                final data = doc.data();
                                return data['isDeleted'] != true;
                            }).toList();

                            final allMembers = visibleDocs
                                .map((doc) => Member.fromFirestore(doc.id, doc.data()))
                                .toList();

                            return Center(
                                child: SizedBox(
                                    width: width,
                                    child: _buildBody(allMembers),
                                ),
                            );
                        },
                    ),
                );

                return AnimatedBuilder(
                    animation: _isGroupingModeNotifier,
                    child: scaffold,
                    builder: (context, child) {
                        return PopScope(
                            canPop: !_isGroupingMode,
                            onPopInvokedWithResult: (didPop, result) async {
                                if (didPop) return;

                                final shouldExit = await _confirmExitGroupingMode();
                                if (!mounted) return;

                                if (shouldExit) {
                                    _exitGroupingMode();
                                }
                            },
                            child: child!,
                        );
                    },
                );
            },
        );
    }

    Widget _buildBody(List<Member> allMembers) {
        final headerData = DashboardHeaderData.fromMembers(allMembers);

        return ValueListenableBuilder<String>(
            valueListenable: _searchKeywordNotifier,
            builder: (context, searchKeyword, _) {
                return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragEnd: (details) async {
                        if (!_isGroupingMode) return;

                        final velocity = details.primaryVelocity ?? 0;
                        if (velocity < -250) {
                            await _handleGroupingModeCloseRequest();
                        }
                    },
                    child: Stack(
                        children: [
                            Listener(
                                behavior: HitTestBehavior.translucent,
                                onPointerDown: (event) {
                                    final isInsideHeader =
                                        _headerKey.currentState?.containsGlobalPosition(event.position) ?? false;

                                    if (!isInsideHeader) {
                                        _closeHeaderOverlayIfNeeded();
                                    }
                                },
                                child: CustomScrollView(
                                    key: const PageStorageKey('client_card_scroll'),
                                    controller: _scrollController,
                                    slivers: [
                                        SliverToBoxAdapter(
                                            child: ListenableBuilder(
                                                listenable: _isGroupingModeNotifier,
                                                builder: (context, _) {
                                                    return RepaintBoundary(
                                                        child:DashboardBlueHeader(
                                                            key: _headerKey,
                                                            data: headerData,
                                                            isGroupingMode: _isGroupingMode,

                                                            onBackTap: () async {
                                                                if (_isGroupingMode) {
                                                                    await _handleGroupingModeCloseRequest();
                                                                    return;
                                                                }
                                                                if (!mounted) return;
                                                                Navigator.of(context).maybePop();
                                                            },

                                                            onAddCustomer: _openCreate,
                                                            onToggleGroupingMode: _handleHeaderGroupingToggle,
                                                            onCreateGroup: _handleHeaderCreateGroup,
                                                            onResetFilters: _resetQuickFilters,
                                                            onRestoreDeletedMembers: _openDeletedMembersRestoreSheet,

                                                            selectedGroupLabel: _headerSelectedGroupLabel,
                                                            groupFilterItems: _buildHeaderGroupFilterItems(),
                                                            onGroupFilterSelected: (groupId) {
                                                                _setSelectedGroupId(groupId == '__all__' ? null : groupId);
                                                            },

                                                            onAlertTap: (memberId) async {
                                                                await scrollToMember(memberId);
                                                            },
                                                        ),
                                                    );
                                                },
                                            ),
                                        ),
                                        SliverPersistentHeader(
                                            pinned: true,
                                            delegate: _PinnedSearchHeaderDelegate(
                                                minExtentValue: 92,
                                                maxExtentValue: 92,
                                                child: RepaintBoundary(
                                                    child: Container(
                                                        color: kClientBgColor,
                                                        padding: const EdgeInsets.fromLTRB(
                                                            kClientPageHorizontalPadding,
                                                            12,
                                                            kClientPageHorizontalPadding,
                                                            10,
                                                        ),
                                                        child: _SearchAndFilterCard(
                                                            controller: _searchController,
                                                            selectedLessonDate: _selectedLessonDate,
                                                            sortOption: _sortOption,
                                                            sortAscending: _sortAscending,
                                                            onSearchChanged: (value) {
                                                                _searchKeywordNotifier.value = value;
                                                            },
                                                            onMenuSelected: (action) async {
                                                                switch (action) {
                                                                    case _SearchMenuAction.sortName:
                                                                        setState(() {
                                                                            _sortOption = SortOption.name;
                                                                        });
                                                                        break;

                                                                    case _SearchMenuAction.sortExpirySoon:
                                                                        setState(() {
                                                                            _sortOption = SortOption.expirySoon;
                                                                        });
                                                                        break;

                                                                    case _SearchMenuAction.sortRecentLesson:
                                                                        setState(() {
                                                                            _sortOption = SortOption.recentLesson;
                                                                        });
                                                                        break;

                                                                    case _SearchMenuAction.sortRecentRegistration:
                                                                        setState(() {
                                                                            _sortOption = SortOption.recentRegistration;
                                                                        });
                                                                        break;

                                                                    case _SearchMenuAction.pickLessonDate:
                                                                        await _pickLessonDate();
                                                                        break;

                                                                    case _SearchMenuAction.clearLessonDate:
                                                                        setState(() {
                                                                            _selectedLessonDate = null;
                                                                        });
                                                                        break;
                                                                }
                                                            },
                                                            onToggleSortDirection: () {
                                                                setState(() {
                                                                    _sortAscending = !_sortAscending;
                                                                });
                                                            },
                                                        ),
                                                    ),
                                                ),
                                            ),
                                        ),
                                        SliverToBoxAdapter(
                                            child: ListenableBuilder(
                                                listenable: Listenable.merge([
                                                    _isGroupingModeNotifier,
                                                    _selectedGroupMemberIdsNotifier,
                                                ]),
                                                builder: (context, _) {
                                                    return Padding(
                                                        padding: const EdgeInsets.fromLTRB(
                                                            kClientPageHorizontalPadding,
                                                            8,
                                                            kClientPageHorizontalPadding,
                                                            10,
                                                        ),
                                                        child: RepaintBoundary(
                                                            child: _GroupingModeBar(
                                                                isVisible: _isGroupingMode,
                                                                selectedCount: _selectedGroupMemberIds.length,
                                                                onClose: _handleGroupingModeCloseRequest,
                                                                onClearSelection: _selectedGroupMemberIds.isEmpty
                                                                    ? null
                                                                    : () {
                                                                    _setSelectedGroupMemberIds(<String>{});
                                                                },
                                                            ),
                                                        ),
                                                    );
                                                },
                                            ),
                                        ),
                                        SliverToBoxAdapter(
                                            child: ListenableBuilder(
                                                listenable: Listenable.merge([
                                                    _pinnedMemberIdsNotifier,
                                                    _selectedGroupMemberIdsNotifier,
                                                    _memberGroupMapNotifier,
                                                    _isGroupingModeNotifier,
                                                    _selectedGroupIdNotifier,
                                                ]),
                                                builder: (context, _) {
                                                    return Padding(
                                                        padding: const EdgeInsets.fromLTRB(
                                                            kClientPageHorizontalPadding,
                                                            0,
                                                            kClientPageHorizontalPadding,
                                                            28,
                                                        ),
                                                        child: _buildMemberListContent(
                                                            allMembers: allMembers,
                                                            searchKeyword: searchKeyword,
                                                        ),
                                                    );
                                                },
                                            ),
                                        ),
                                    ],
                                ),
                            ),
                            ListenableBuilder(
                                listenable: Listenable.merge([
                                    _isGroupingModeNotifier,
                                    _selectedGroupMemberIdsNotifier,
                                    _memberGroupMapNotifier,
                                    _selectedGroupIdNotifier,
                                ]),
                                builder: (context, _) {
                                    if (!_isGroupingMode) {
                                        return const SizedBox.shrink();
                                    }

                                    final groupCounts = _buildGroupCounts(allMembers);

                                    return Positioned(
                                        left: 10,
                                        top: 118,
                                        child: RepaintBoundary(
                                            child: _GroupingSidePanel(
                                                groupIds: _groupIds,
                                                systemGroupIds: _systemGroupIds,
                                                ungroupedGroupId: _ungroupedGroupId,
                                                selectedGroupId: _selectedGroupId,
                                                selectedMemberCount: _selectedGroupMemberIds.length,
                                                groupCounts: groupCounts,
                                                groupNames: _groupNames,
                                                onSelectGroup: _setSelectedGroupId,
                                                onShowAll: () => _setSelectedGroupId(null),
                                                onApplyGroup: _assignSelectedMembersToGroup,
                                                onRenameGroup: _showRenameGroupDialog,
                                                onDeleteGroup: _showDeleteGroupDialog,
                                                onCreateGroup: _showCreateGroupDialog,
                                                onAcceptDrop: (draggedMemberId, targetGroupId) async {
                                                    await _handleDroppedMembersLocally(
                                                        draggedMemberId: draggedMemberId,
                                                        targetGroupId: targetGroupId,
                                                    );
                                                },
                                            ),
                                        ),
                                    );
                                },
                            ),
                        ],
                    ),
                );
            },
        );
    }



    Widget _buildMemberListContent({
        required List<Member> allMembers,
        required String searchKeyword,
    }) {
        final filteredMembers = _buildFilteredMembers(
            allMembers,
            searchKeyword,
            groupFilterId: _selectedGroupId,
        );

        if (filteredMembers.isEmpty) {
            return Padding(
                padding: const EdgeInsets.only(top: 28),
                child: Center(
                    child: Text(
                        _selectedGroupId == null
                            ? '조건에 맞는 회원이 없어요'
                            : '${_groupLabel(_selectedGroupId!)}에 표시할 회원이 없어요',
                        style: const TextStyle(
                            fontSize: 15,
                            color: Colors.black54,
                            fontWeight: FontWeight.w600,
                        ),
                    ),
                ),
            );
        }

        return Column(
            children: filteredMembers.map((member) {
                final itemKey = _memberItemKeys.putIfAbsent(
                    member.id,
                        () => GlobalKey(),
                );

                return KeyedSubtree(
                    key: itemKey,
                    child: MemberSimpleCard(
                        key: ValueKey('member_card_${member.id}'),
                        member: member,
                        groupLabel: _memberGroupMap[member.id] == null
                            ? null
                            : _groupLabel(_memberGroupMap[member.id]!),
                        displayGroupLabel: _memberDisplayGroupLabel(member),
                        displayGroupAccentColor: _memberDisplayGroupAccentColor(member),
                        displayGroupTextColor: _memberDisplayGroupTextColor(member),
                        groupMenuItems: _buildMemberCardGroupMenuItems(),
                        onQuickGroupChanged: (groupId) async {
                            await _handleMemberQuickGroupChange(member, groupId);
                        },
                        selectedGroupDragCount: _dragPreviewCount(member.id),
                        onContractTap: () {},
                        onEditTap: () => _openEdit(member),
                        onLogTap: () => _openLog(member),
                        onPinTap: () => _togglePin(member),
                        isPinned: _pinnedMemberIds.contains(member.id),
                        onSetExpired: () => _updateMemberStatus(member, '만료'),
                        onSetDormant: () => _updateMemberStatus(member, '휴면'),
                        onSetActive: () => _updateMemberStatus(member, '활성'),
                        isGroupingMode: _isGroupingMode,
                        isSelectedForGroup: _selectedGroupMemberIds.contains(member.id),
                        onGroupSelectTap: () => _toggleGroupSelection(member),
                        onEnterGroupingMode: () => _enterGroupingMode(member.id),
                        onAnyInteraction: _closeHeaderOverlayIfNeeded,
                        highlightListenable: _highlightNotifier,
                    ),
                );
            }).toList(),
        );
    }



    List<Member> _buildFilteredMembers(
        List<Member> members,
        String rawQuery, {
            String? groupFilterId,
        }) {
        final query = rawQuery.trim().toLowerCase();
        final queryDigits = _digitsOnly(query);

        final filtered = members.where((member) {
            final name = (member.name ?? '').toLowerCase();
            final phone = (member.phone ?? '').toLowerCase();
            final phoneDigits = _digitsOnly(phone);
            final memberGroupId = _memberGroupMap[member.id];

            final matchesSearch = query.isEmpty
                ? true
                : name.contains(query) ||
                phone.contains(query) ||
                (queryDigits.isNotEmpty && phoneDigits.contains(queryDigits));

            final matchesDate = _selectedLessonDate == null
                ? true
                : (member.lastLogAt != null &&
                _isSameDate(member.lastLogAt!, _selectedLessonDate!));

            final matchesGroup = switch (groupFilterId) {
                null => true,
                _ungroupedGroupId => !_isExpiredMember(member) &&
                    !_isDormantMember(member) &&
                    memberGroupId == null,
                _systemDormantGroupId => _isDormantMember(member),
                _systemExpiredGroupId => _isExpiredMember(member),
                _ => !_isExpiredMember(member) &&
                    !_isDormantMember(member) &&
                    memberGroupId == groupFilterId,
            };

            final shouldHideExpiredByDefault =
                groupFilterId == null &&
                    query.isEmpty &&
                    _selectedLessonDate == null &&
                    _isExpiredMember(member);

            if (shouldHideExpiredByDefault) {
                return false;
            }

            return matchesSearch && matchesDate && matchesGroup;
        }).toList();

        filtered.sort(_memberComparator(_sortOption));

        final sortedMembers = _sortAscending ? filtered : filtered.reversed.toList();

        final List<Member> pinned = [];
        final List<Member> normal = [];

        for (final pinnedId in _pinnedMemberIds) {
            final match = sortedMembers.where((member) => member.id == pinnedId);
            if (match.isNotEmpty) {
                pinned.add(match.first);
            }
        }

        for (final member in sortedMembers) {
            if (!_pinnedMemberIds.contains(member.id)) {
                normal.add(member);
            }
        }

        return [...pinned, ...normal];
    }

    void _showSnack(String message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
        );
    }

    int _maxGroupNameLength(String groupId) {
        if (groupId == _ungroupedGroupId) return 6;
        if (_systemGroupIds.contains(groupId)) return 6;
        return 8;
    }

    Future<void> _showRenameGroupDialog(String groupId) async {
        final int maxLength = _maxGroupNameLength(groupId);
        final controller = TextEditingController(
            text: _groupNames[groupId] ?? _groupLabel(groupId),
        );

        final result = await showDialog<String>(
            context: context,
            builder: (dialogContext) {
                return StatefulBuilder(
                    builder: (context, setInnerState) {
                        return AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                            ),
                            title: Text(
                                groupId == _ungroupedGroupId
                                    ? '기본 그룹 이름 수정'
                                    : _systemGroupIds.contains(groupId)
                                    ? '시스템 그룹 이름 수정'
                                    : '그룹 이름 수정',
                            ),
                            content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(
                                        _systemGroupIds.contains(groupId)
                                            ? '시스템 기능은 그대로 유지되고 표시 이름만 바뀌어요.'
                                            : '짧고 구분 쉬운 이름으로 적어주세요.',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w600,
                                        ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                        controller: controller,
                                        autofocus: true,
                                        decoration: InputDecoration(
                                            hintText: '최대 $maxLength자',
                                            counterText: '${controller.text.length}/$maxLength',
                                            filled: true,
                                            fillColor: const Color(0xFFF8FAFC),
                                            border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: BorderSide.none,
                                            ),
                                        ),
                                        onChanged: (value) {
                                            if (value.length > maxLength) {
                                                final trimmed = value.substring(0, maxLength);
                                                controller.value = TextEditingValue(
                                                    text: trimmed,
                                                    selection: TextSelection.collapsed(
                                                        offset: trimmed.length,
                                                    ),
                                                );
                                                _showSnack('이름은 최대 ${maxLength}자까지 입력할 수 있어요.');
                                            }
                                            setInnerState(() {});
                                        },
                                    ),
                                ],
                            ),
                            actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(dialogContext),
                                    child: const Text('취소'),
                                ),
                                FilledButton(
                                    onPressed: () {
                                        Navigator.pop(dialogContext, controller.text.trim());
                                    },
                                    child: const Text('저장'),
                                ),
                            ],
                        );
                    },
                );
            },
        );

        if (result == null) return;
        if (result.trim().isEmpty) {
            _showSnack('이름을 입력해주세요.');
            return;
        }

        final newName = result.trim();

        try {
            if (groupId != _ungroupedGroupId) {
                await FirebaseFirestore.instance
                    .collection('member_groups')
                    .doc(groupId)
                    .set({
                    'name': newName,
                    'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
            }

            if (!mounted) return;

            setState(() {
                _groupNames[groupId] = newName;
            });
        } catch (e) {
            _showSnack('그룹 이름 변경에 실패했어요.');
        }
    }

    Future<void> _showCreateGroupDialog() async {
        if (_groupIds.length >= 5) {
            _showSnack('그룹은 최대 5개까지만 만들 수 있어요.');
            return;
        }

        final int nextNumber = _nextGroupNumber;
        final String newGroupId = 'group_$nextNumber';
        final controller = TextEditingController();

        final result = await showDialog<String>(
            context: context,
            builder: (dialogContext) {
                return StatefulBuilder(
                    builder: (context, setInnerState) {
                        return AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                            ),
                            title: const Text('새 그룹 만들기'),
                            content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    const Text(
                                        '장소 / 반 / 소속 이름처럼 짧게 적어주세요.',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.black54,
                                            fontWeight: FontWeight.w600,
                                        ),
                                    ),
                                    const SizedBox(height: 10),
                                    TextField(
                                        controller: controller,
                                        autofocus: true,
                                        decoration: InputDecoration(
                                            hintText: '예: 오전반, 오후반, 모어댄피트니스',
                                            counterText: '${controller.text.length}/8',
                                            filled: true,
                                            fillColor: const Color(0xFFF8FAFC),
                                            border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: BorderSide.none,
                                            ),
                                        ),
                                        onChanged: (value) {
                                            if (value.length > 8) {
                                                final trimmed = value.substring(0, 8);
                                                controller.value = TextEditingValue(
                                                    text: trimmed,
                                                    selection: TextSelection.collapsed(
                                                        offset: trimmed.length,
                                                    ),
                                                );
                                                _showSnack('그룹 이름은 최대 8자까지 입력할 수 있어요.');
                                            }
                                            setInnerState(() {});
                                        },
                                    ),
                                ],
                            ),
                            actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(dialogContext),
                                    child: const Text('취소'),
                                ),
                                FilledButton(
                                    onPressed: () {
                                        Navigator.pop(dialogContext, controller.text.trim());
                                    },
                                    child: const Text('생성'),
                                ),
                            ],
                        );
                    },
                );
            },
        );

        if (result == null) return;
        if (result.trim().isEmpty) {
            _showSnack('그룹 이름을 입력해주세요.');
            return;
        }

        final newName = result.trim();

        try {
            await FirebaseFirestore.instance
                .collection('member_groups')
                .doc(newGroupId)
                .set({
                'name': newName,
                'order': _groupIds.length + 1,
                'isArchived': false,
                'isSystem': false,
                'systemType': 'custom',
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
            });

            if (!mounted) return;

            setState(() {
                _groupIds.add(newGroupId);
                _groupNames[newGroupId] = newName;
                _nextGroupNumber++;
            });
        } catch (e) {
            _showSnack('그룹 저장 권한이 없거나 그룹 저장에 실패했어요.');
        }
    }

    Future<void> _showDeleteGroupDialog(String groupId) async {
        if (_systemGroupIds.contains(groupId) || groupId == _ungroupedGroupId) {
            return;
        }

        final result = await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
                return AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text('그룹을 삭제할까요?'),
                    content: Text(
                        '${_groupLabel(groupId)} 그룹을 삭제하면 해당 회원들은 기본 그룹으로 이동해요.',
                        style: const TextStyle(height: 1.45),
                    ),
                    actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const Text('취소'),
                        ),
                        FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('삭제'),
                        ),
                    ],
                );
            },
        );

        if (result == true) {
            await _deleteGroup(groupId);
        }
    }

    Future<void> _deleteGroup(String groupId) async {
        if (_systemGroupIds.contains(groupId) || groupId == _ungroupedGroupId) {
            return;
        }

        final memberRefs = await FirebaseFirestore.instance
            .collection('members')
            .where('groupId', isEqualTo: groupId)
            .get();

        final batch = FirebaseFirestore.instance.batch();

        for (final doc in memberRefs.docs) {
            batch.set(doc.reference, {
                'groupId': FieldValue.delete(),
                'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
        }

        batch.delete(
            FirebaseFirestore.instance.collection('member_groups').doc(groupId),
        );

        await batch.commit();

        final nextMap = Map<String, String>.from(_memberGroupMap)
            ..removeWhere((key, value) => value == groupId);

        if (!mounted) return;

        setState(() {
            _groupIds.remove(groupId);
            _groupNames.remove(groupId);
        });

        _setMemberGroupMap(nextMap);

        if (_selectedGroupId == groupId) {
            _setSelectedGroupId(null);
        }

        _showSnack('그룹이 삭제되었어요.');
    }

    void _enterGroupingMode([String? initialMemberId]) {
        _closeHeaderOverlayIfNeeded();

        final nextSelected = Set<String>.from(_selectedGroupMemberIds);
        if (initialMemberId != null) {
            nextSelected.add(initialMemberId);
        }

        _setSelectedGroupMemberIds(nextSelected);
        _setGroupingMode(true);
    }

    void _exitGroupingMode() {
        _setGroupingMode(false);
        _setSelectedGroupMemberIds(<String>{});
        _setSelectedGroupId(null);
    }

    void _toggleGroupSelection(Member member) {
        final nextSelected = Set<String>.from(_selectedGroupMemberIds);

        if (nextSelected.contains(member.id)) {
            nextSelected.remove(member.id);
        } else {
            nextSelected.add(member.id);
        }

        _setSelectedGroupMemberIds(nextSelected);
    }

    Map<String, int> _buildGroupCounts(List<Member> allMembers) {
        final Map<String, int> counts = {
            _ungroupedGroupId: 0,
            _systemDormantGroupId: 0,
            _systemExpiredGroupId: 0,
            for (final groupId in _groupIds) groupId: 0,
        };

        for (final member in allMembers) {
            if (_isExpiredMember(member)) {
                counts[_systemExpiredGroupId] = counts[_systemExpiredGroupId]! + 1;
                continue;
            }

            if (_isDormantMember(member)) {
                counts[_systemDormantGroupId] = counts[_systemDormantGroupId]! + 1;
                continue;
            }

            final groupId = _memberGroupMap[member.id];
            if (groupId == null) {
                counts[_ungroupedGroupId] = counts[_ungroupedGroupId]! + 1;
            } else if (counts.containsKey(groupId)) {
                counts[groupId] = counts[groupId]! + 1;
            } else {
                counts[_ungroupedGroupId] = counts[_ungroupedGroupId]! + 1;
            }
        }

        return counts;
    }

    bool _isHeaderGroupDropdownOpen = false;

    String _groupLabel(String groupId) {
        if (_groupNames.containsKey(groupId)) {
            return _groupNames[groupId]!;
        }

        if (groupId == _ungroupedGroupId) return 'More Than Fitness';
        if (groupId == _systemDormantGroupId) return '휴면회원';
        if (groupId == _systemExpiredGroupId) return '만료회원';

        return groupId;
    }

    String _memberDisplayGroupLabel(Member member) {
        if (_isExpiredMember(member)) return _groupLabel(_systemExpiredGroupId);
        if (_isDormantMember(member)) return _groupLabel(_systemDormantGroupId);

        final groupId = _memberGroupMap[member.id];
        if (groupId != null) {
            return _groupLabel(groupId).toUpperCase();
        }

        return 'MORE THAN FITNESS';
    }

    Color _memberDisplayGroupAccentColor(Member member) {
        if (_isExpiredMember(member)) {
            return const Color(0xFF6B7280);
        }
        if (_isDormantMember(member)) {
            return const Color(0xFFD1D5DB);
        }

        final groupId = _memberGroupMap[member.id];
        if (groupId == null) {
            return const Color(0xFFE5E7EB);
        }

        final palette = <Color>[
            const Color(0xFFDDD6FE),
            const Color(0xFFDBEAFE),
            const Color(0xFFFCE7F3),
            const Color(0xFFDCFCE7),
            const Color(0xFFFDE68A),
        ];

        final index = _groupIds.indexOf(groupId);
        if (index < 0) return const Color(0xFFE5E7EB);
        return palette[index % palette.length];
    }

    Color _memberDisplayGroupTextColor(Member member) {
        if (_isExpiredMember(member)) {
            return const Color(0xFFF9FAFB);
        }
        if (_isDormantMember(member)) {
            return const Color(0xFF4B5563);
        }

        final groupId = _memberGroupMap[member.id];
        if (groupId == null) {
            return const Color(0xFF4B5563);
        }

        final palette = <Color>[
            const Color(0xFF5B21B6),
            const Color(0xFF1D4ED8),
            const Color(0xFFBE185D),
            const Color(0xFF15803D),
            const Color(0xFF92400E),
        ];

        final index = _groupIds.indexOf(groupId);
        if (index < 0) return const Color(0xFF4B5563);
        return palette[index % palette.length];
    }

    List<_MemberCardGroupMenuItem> _buildMemberCardGroupMenuItems() {
        return <_MemberCardGroupMenuItem>[
            const _MemberCardGroupMenuItem(
                id: _ungroupedGroupId,
                label: 'More Than Fitness',
                icon: Icons.home_rounded,
            ),
            ..._groupIds.map(
                    (groupId) => _MemberCardGroupMenuItem(
                    id: groupId,
                    label: _groupLabel(groupId),
                    icon: Icons.folder_open_rounded,
                ),
            ),
            _MemberCardGroupMenuItem(
                id: _systemDormantGroupId,
                label: _groupLabel(_systemDormantGroupId),
                icon: Icons.bedtime_rounded,
            ),
            _MemberCardGroupMenuItem(
                id: _systemExpiredGroupId,
                label: _groupLabel(_systemExpiredGroupId),
                icon: Icons.warning_amber_rounded,
            ),
        ];
    }

    Future<void> _handleMemberQuickGroupChange(Member member, String targetGroupId) async {
        _closeHeaderOverlayIfNeeded();

        final memberRef =
        FirebaseFirestore.instance.collection('members').doc(member.id);

        final nextGroupMap = Map<String, String>.from(_memberGroupMap);
        final batch = FirebaseFirestore.instance.batch();

        if (targetGroupId == _systemDormantGroupId) {
            nextGroupMap.remove(member.id);
            batch.set(
                memberRef,
                {
                    'memberStatus': '휴면',
                    'groupId': FieldValue.delete(),
                    'updatedAt': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true),
            );
        } else if (targetGroupId == _systemExpiredGroupId) {
            nextGroupMap.remove(member.id);
            batch.set(
                memberRef,
                {
                    'memberStatus': '만료',
                    'groupId': FieldValue.delete(),
                    'updatedAt': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true),
            );
        } else if (targetGroupId == _ungroupedGroupId) {
            nextGroupMap.remove(member.id);
            batch.set(
                memberRef,
                {
                    'memberStatus': '활성',
                    'groupId': FieldValue.delete(),
                    'updatedAt': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true),
            );
        } else {
            nextGroupMap[member.id] = targetGroupId;
            batch.set(
                memberRef,
                {
                    'memberStatus': '활성',
                    'groupId': targetGroupId,
                    'updatedAt': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true),
            );
        }

        await batch.commit();
        _setMemberGroupMap(nextGroupMap);

        if (!mounted) return;
        _showSnack('${member.name ?? '회원'}님 그룹이 변경되었어요.');
    }

    bool _shouldDragSelectedGroup(String draggedMemberId) {
        if (!_isGroupingMode) return false;
        if (_selectedGroupMemberIds.length < 2) return false;
        return _selectedGroupMemberIds.contains(draggedMemberId);
    }

    List<String> _resolveDraggedMemberIds(String draggedMemberId) {
        if (_shouldDragSelectedGroup(draggedMemberId)) {
            return _selectedGroupMemberIds.toList();
        }

        return [draggedMemberId];
    }

    int _dragPreviewCount(String draggedMemberId) {
        return _resolveDraggedMemberIds(draggedMemberId).length;
    }

    Future<void> _assignSelectedMembersToGroup() async {
        _closeHeaderOverlayIfNeeded();

        if (_selectedGroupMemberIds.isEmpty) {
            _showSnack('먼저 회원을 선택해주세요.');
            return;
        }

        if (_selectedGroupId == null) {
            _showSnack('먼저 그룹을 선택해주세요.');
            return;
        }

        final nextGroupMap = Map<String, String>.from(_memberGroupMap);
        final batch = FirebaseFirestore.instance.batch();

        for (final memberId in _selectedGroupMemberIds) {
            final memberRef =
            FirebaseFirestore.instance.collection('members').doc(memberId);

            if (_selectedGroupId == _systemDormantGroupId) {
                nextGroupMap.remove(memberId);
                batch.set(memberRef, {
                    'memberStatus': '휴면',
                    'groupId': FieldValue.delete(),
                    'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
            } else if (_selectedGroupId == _systemExpiredGroupId) {
                nextGroupMap.remove(memberId);
                batch.set(memberRef, {
                    'memberStatus': '만료',
                    'groupId': FieldValue.delete(),
                    'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
            } else if (_selectedGroupId == _ungroupedGroupId) {
                nextGroupMap.remove(memberId);
                batch.set(memberRef, {
                    'memberStatus': '활성',
                    'groupId': FieldValue.delete(),
                    'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
            } else {
                nextGroupMap[memberId] = _selectedGroupId!;
                batch.set(memberRef, {
                    'memberStatus': '활성',
                    'groupId': _selectedGroupId,
                    'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
            }
        }

        await batch.commit();

        _setMemberGroupMap(nextGroupMap);
        _setSelectedGroupMemberIds(<String>{});
    }

    Future<void> _handleDroppedMembersLocally({
        required String draggedMemberId,
        required String targetGroupId,
    }) async {
        _closeHeaderOverlayIfNeeded();

        final ids = _resolveDraggedMemberIds(draggedMemberId);
        final nextGroupMap = Map<String, String>.from(_memberGroupMap);
        final batch = FirebaseFirestore.instance.batch();

        for (final memberId in ids) {
            final memberRef =
            FirebaseFirestore.instance.collection('members').doc(memberId);

            if (targetGroupId == _systemDormantGroupId) {
                nextGroupMap.remove(memberId);
                batch.set(memberRef, {
                    'memberStatus': '휴면',
                    'groupId': FieldValue.delete(),
                    'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
            } else if (targetGroupId == _systemExpiredGroupId) {
                nextGroupMap.remove(memberId);
                batch.set(memberRef, {
                    'memberStatus': '만료',
                    'groupId': FieldValue.delete(),
                    'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
            } else if (targetGroupId == _ungroupedGroupId) {
                nextGroupMap.remove(memberId);
                batch.set(memberRef, {
                    'memberStatus': '활성',
                    'groupId': FieldValue.delete(),
                    'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
            } else {
                nextGroupMap[memberId] = targetGroupId;
                batch.set(memberRef, {
                    'memberStatus': '활성',
                    'groupId': targetGroupId,
                    'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
            }
        }

        await batch.commit();

        _setMemberGroupMap(nextGroupMap);
        _setSelectedGroupMemberIds(<String>{});
    }

    void _handleHeaderGroupingToggle() async {
        _closeHeaderOverlayIfNeeded();

        if (_isGroupingMode) {
            await _handleGroupingModeCloseRequest();
            return;
        }

        _enterGroupingMode();
    }

    void _handleHeaderCreateGroup() async {
        _closeHeaderOverlayIfNeeded();
        await _showCreateGroupDialog();
    }

    void _resetQuickFilters() {
        _closeHeaderOverlayIfNeeded();

        _searchController.clear();
        _searchKeywordNotifier.value = '';
        _setSelectedGroupId(null);

        setState(() {
            _selectedLessonDate = null;
            _sortOption = SortOption.name;
            _sortAscending = true;
        });
    }

    void _toggleHeaderGroupDropdown() {
        setState(() {
            _isHeaderGroupDropdownOpen = !_isHeaderGroupDropdownOpen;
        });
    }

    void _closeHeaderGroupDropdown() {
        if (!_isHeaderGroupDropdownOpen) return;
        setState(() {
            _isHeaderGroupDropdownOpen = false;
        });
    }

    void _handleHeaderGroupFilterSelected(String groupId) {
        _setSelectedGroupId(groupId == '__all__' ? null : groupId);
        _closeHeaderGroupDropdown();
    }

    Comparator<Member> _memberComparator(SortOption option) {
        switch (option) {
            case SortOption.name:
                return (a, b) => _compareNameOrder(a.name ?? '', b.name ?? '');

            case SortOption.expirySoon:
                return (a, b) {
                    final aExpiryRank = a.remainingSessions < 5 ? 0 : 1;
                    final bExpiryRank = b.remainingSessions < 5 ? 0 : 1;
                    final rankCompare = aExpiryRank.compareTo(bExpiryRank);
                    if (rankCompare != 0) return rankCompare;

                    final sessionsCompare =
                    a.remainingSessions.compareTo(b.remainingSessions);
                    if (sessionsCompare != 0) return sessionsCompare;

                    return _compareNameOrder(a.name ?? '', b.name ?? '');
                };

            case SortOption.recentLesson:
                return (a, b) {
                    final aDate = a.lastLogAt ?? DateTime(1900);
                    final bDate = b.lastLogAt ?? DateTime(1900);
                    final compare = bDate.compareTo(aDate);
                    if (compare != 0) return compare;
                    return _compareNameOrder(a.name ?? '', b.name ?? '');
                };

            case SortOption.recentRegistration:
                return (a, b) {
                    final aDate = a.recentReg ?? a.firstDate ?? DateTime(1900);
                    final bDate = b.recentReg ?? b.firstDate ?? DateTime(1900);
                    final compare = bDate.compareTo(aDate);
                    if (compare != 0) return compare;
                    return _compareNameOrder(a.name ?? '', b.name ?? '');
                };
        }
    }

    void _openEdit(Member member) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ClientCardPage.edit(
                    memberId: member.id,
                    initialName: member.name,
                ),
            ),
        );
    }

    void _openLog(Member member) {
        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => PersonalTrainingLogPage(
                    memberId: member.id,
                    memberName: member.name ?? '',
                    memberPhone: member.phone ?? '',
                ),
            ),
        );
    }

    void _openCreate() {
        final newId = FirebaseFirestore.instance.collection('members').doc().id;

        Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ClientCardPage.newMember(
                    memberId: newId,
                ),
            ),
        );
    }

    void _togglePin(Member member) {
        _closeHeaderOverlayIfNeeded();

        final nextPinned = List<String>.from(_pinnedMemberIds);
        final isPinned = nextPinned.contains(member.id);

        if (isPinned) {
            nextPinned.remove(member.id);
            _setPinnedMemberIds(nextPinned);
            return;
        }

        if (nextPinned.length >= 5) {
            _showSnack('상단고정은 최대 5명까지만 가능해요.');
            return;
        }

        nextPinned.insert(0, member.id);
        _setPinnedMemberIds(nextPinned);
    }

    Future<bool> _confirmExitGroupingMode() async {
        if (!_isGroupingMode) return true;

        final result = await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
                return AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                    ),
                    title: const Text(
                        '그룹 모드를 종료할까요?',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                        ),
                    ),
                    content: Text(
                        _selectedGroupMemberIds.isEmpty
                            ? '지금 그룹핑 모드를 종료하면 선택 상태가 닫혀요.'
                            : '선택한 회원 ${_selectedGroupMemberIds.length}명의 선택 상태가 해제돼요.',
                        style: const TextStyle(
                            height: 1.4,
                        ),
                    ),
                    actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const Text('계속 작업'),
                        ),
                        FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('종료하기'),
                        ),
                    ],
                );
            },
        );

        return result ?? false;
    }

    Future<void> _handleGroupingModeCloseRequest() async {
        final shouldExit = await _confirmExitGroupingMode();
        if (!mounted) return;

        if (shouldExit) {
            _exitGroupingMode();
        }
    }

    Future<void> _updateMemberStatus(Member member, String newStatus) async {
        try {
            await FirebaseFirestore.instance
                .collection('members')
                .doc(member.id)
                .set({
                'memberStatus': newStatus,
                'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('${member.name ?? '회원'}님 그룹이 변경되었어요.'),
                ),
            );
        } catch (e) {
            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('상태 변경에 실패했어요: $e'),
                ),
            );
        }
    }

    Future<String?> _askRestorePin() async {
        final c = TextEditingController();

        final result = await showDialog<String>(
            context: context,
            builder: (ctx) => AlertDialog(
                title: const Text('관리자 PIN 입력'),
                content: TextField(
                    controller: c,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        hintText: 'PIN 입력',
                        border: OutlineInputBorder(),
                    ),
                ),
                actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('취소'),
                    ),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, c.text.trim()),
                        child: const Text('확인'),
                    ),
                ],
            ),
        );

        c.dispose();
        return result;
    }

    Future<void> _restoreDeletedMember(String memberId) async {
        final pin = await _askRestorePin();
        if (pin == null) return;

        if (pin != _adminRestorePin) {
            _showSnack('관리자 PIN이 일치하지 않아요.');
            return;
        }

        await FirebaseFirestore.instance.collection('members').doc(memberId).set({
            'isDeleted': false,
            'deletedAt': FieldValue.delete(),
            'deleteScheduledAt': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;
        _showSnack('삭제 대기 회원이 복구되었어요.');
    }

    Future<void> _openDeletedMembersRestoreSheet() async {
        final snap = await FirebaseFirestore.instance
            .collection('members')
            .where('isDeleted', isEqualTo: true)
            .get();

        if (!mounted) return;

        final docs = snap.docs;

        showModalBottomSheet(
            context: context,
            showDragHandle: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (ctx) {
                return SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                const Text(
                                    '삭제 대기 회원 복구',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                    ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                    '복구 요청은 고객센터로 문의 바랍니다.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black54,
                                    ),
                                ),
                                const SizedBox(height: 14),
                                if (docs.isEmpty)
                                    const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16),
                                        child: Text(
                                            '삭제 대기 회원이 없습니다.',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black54,
                                            ),
                                        ),
                                    )
                                else
                                    Flexible(
                                        child: ListView.separated(
                                            shrinkWrap: true,
                                            itemCount: docs.length,
                                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                                            itemBuilder: (_, index) {
                                                final data = docs[index].data();
                                                final name = (data['name'] ?? '이름없음').toString();
                                                final phone = (data['phone'] ?? '').toString();

                                                return Container(
                                                    padding: const EdgeInsets.all(12),
                                                    decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius: BorderRadius.circular(14),
                                                        border: Border.all(color: const Color(0xFFE5E7EB)),
                                                    ),
                                                    child: Row(
                                                        children: [
                                                            Expanded(
                                                                child: Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                                    children: [
                                                                        Text(
                                                                            name,
                                                                            style: const TextStyle(
                                                                                fontSize: 14,
                                                                                fontWeight: FontWeight.w900,
                                                                            ),
                                                                        ),
                                                                        const SizedBox(height: 4),
                                                                        Text(
                                                                            phone,
                                                                            style: const TextStyle(
                                                                                fontSize: 12,
                                                                                fontWeight: FontWeight.w600,
                                                                                color: Colors.black54,
                                                                            ),
                                                                        ),
                                                                    ],
                                                                ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            OutlinedButton(
                                                                onPressed: () async {
                                                                    Navigator.pop(ctx);
                                                                    await _restoreDeletedMember(docs[index].id);
                                                                },
                                                                child: const Text('복구'),
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
                );
            },
        );
    }

    Future<void> _pickLessonDate() async {
        final now = DateTime.now();
        final picked = await showDatePicker(
            context: context,
            initialDate: _selectedLessonDate ?? now,
            firstDate: DateTime(now.year - 2),
            lastDate: DateTime(now.year + 2),
        );

        if (picked != null) {
            setState(() {
                _selectedLessonDate = picked;
            });
        }
    }
}

enum SortOption {
    name,
    expirySoon,
    recentLesson,
    recentRegistration,
}

enum _SearchMenuAction {
    sortName,
    sortExpirySoon,
    sortRecentLesson,
    sortRecentRegistration,
    pickLessonDate,
    clearLessonDate,
}

enum AlertType {
    membershipExpiry,
    newMember,
    attentionNeeded,
    birthday,
    healthCheck,
    hundredDay,
    hundredLesson,
    reRegistration,
    painCheck,
}

enum HeaderFocusType {
    expiry,
    newMember,
    attention,
    birthday,
    calm,
}

class DashboardAlert {
    const DashboardAlert({
        required this.memberId,
        required this.customerName,
        required this.type,
        required this.label,
        required this.priority,
        this.daysLeft,
    });

    final String memberId;
    final String customerName;
    final AlertType type;
    final String label;
    final int priority;
    final int? daysLeft;
}

class DashboardHeaderData {
    const DashboardHeaderData({
        required this.expiryCount,
        required this.attentionCount,
        required this.birthdayCount,
        required this.alerts,
        required this.focusType,
        required this.focusCount,
        required this.focusTitle,
        required this.focusSubtitle,
        required this.dailyTitle,
    });

    final int expiryCount;
    final int attentionCount;
    final int birthdayCount;
    final List<DashboardAlert> alerts;

    final HeaderFocusType focusType;
    final int focusCount;
    final String focusTitle;
    final String focusSubtitle;
    final String dailyTitle;

    int get totalCareCount => alerts.map((e) => e.customerName).toSet().length;

    static DashboardHeaderData fromMembers(List<Member> members) {
        final now = DateTime.now();

        int expiryCount = 0;
        int attentionCount = 0;
        int birthdayCount = 0;

        final List<DashboardAlert> alerts = [];

        for (final member in members) {
            final isExpired = member.memberStatus == '만료' || member.isExpired;
            final isDormant = member.memberStatus == '휴면';
            final isActive = !isExpired && !isDormant;

            final remaining = member.remainingSessions;
            final firstDate = member.firstDate;
            final recentReg = member.recentReg;
            final expireAt = member.expireAt;

            final firstLessonDays =
            firstDate == null ? 9999 : _daysBetween(firstDate, now);

            final isExpirySoon = isActive && remaining < 5;
            final isNewMember = isActive && firstLessonDays >= 0 && firstLessonDays < 7;
            final isBirthdayThisMonth = false;
            final isAttention = false;

            if (isExpirySoon) {
                expiryCount++;
            }

            if (isBirthdayThisMonth) {
                birthdayCount++;
            }

            if (isAttention) {
                attentionCount++;
            }

            if (isNewMember) {
                attentionCount++;
            }

            if (isExpired) {
                alerts.add(
                    DashboardAlert(
                        memberId: member.id,
                        customerName: member.name ?? '이름없음',
                        type: AlertType.membershipExpiry,
                        label: '만료회원',
                        priority: 1,
                    ),
                );
            } else if (isDormant) {
                alerts.add(
                    DashboardAlert(
                        memberId: member.id,
                        customerName: member.name ?? '이름없음',
                        type: AlertType.attentionNeeded,
                        label: '휴면회원',
                        priority: 2,
                    ),
                );
            } else if (isExpirySoon) {
                String label = '만료예정 · ${member.remainingSessions}회 남음';
                if (expireAt != null) {
                    label =
                    '만료예정 · ${member.remainingSessions}회 남음 · ${_formatDate(expireAt)}';
                }

        alerts.add(
        DashboardAlert(
        memberId: member.id,
        customerName: member.name ?? '이름없음',
        type: AlertType.membershipExpiry,
        label: label,
        priority: 1,
        ),
        );
            }

            if (isNewMember) {
        alerts.add(
        DashboardAlert(
        memberId: member.id,
        customerName: member.name ?? '이름없음',
        type: AlertType.newMember,
        label: recentReg != null
        ? '신규 등록 · ${_formatDate(recentReg)}'
            : '신규 회원',
        daysLeft: firstLessonDays,
        priority: 4,
        ),
        );
            }
        }

        alerts.sort((a, b) {
            final priorityCompare = a.priority.compareTo(b.priority);
            if (priorityCompare != 0) return priorityCompare;

            final aDays = a.daysLeft ?? 9999;
            final bDays = b.daysLeft ?? 9999;
            return aDays.compareTo(bDays);
        });

        final HeaderFocusType focusType;
        final int focusCount;

        if (expiryCount > 0) {
            focusType = HeaderFocusType.expiry;
            focusCount = expiryCount;
        } else if (attentionCount > 0) {
            focusType = HeaderFocusType.attention;
            focusCount = attentionCount;
        } else if (birthdayCount > 0) {
            focusType = HeaderFocusType.birthday;
            focusCount = birthdayCount;
        } else {
            focusType = HeaderFocusType.calm;
            focusCount = 0;
        }

        final focusTitle = switch (focusType) {
            HeaderFocusType.expiry => '만료예정 $focusCount명',
            HeaderFocusType.newMember => '체크해보세요 $focusCount명',
            HeaderFocusType.attention => '체크해보세요 $focusCount명',
            HeaderFocusType.birthday => '소중한 일정 $focusCount명',
            HeaderFocusType.calm => '오늘은 마음의 여유를 즐겨보세요',
        };

        return DashboardHeaderData(
            expiryCount: expiryCount,
            attentionCount: attentionCount,
            birthdayCount: birthdayCount,
            alerts: alerts.take(8).toList(),
            focusType: focusType,
            focusCount: focusCount,
            focusTitle: focusTitle,
            focusSubtitle: _rotatingSubtitle(focusType),
            dailyTitle: _rotatingDailyTitle(),
        );
    }

    static String _rotatingDailyTitle() {
        final titles = [
            '오늘의 고객 이슈를 점검해 볼까요?',
            '오늘의 체크포인트를 볼까요?',
            '세심한 관리 포인트를 확인해 보세요',
            '한 번 더 보면 빠짐 없이 챙길 수 있어요',
            '지금 체크하면 한 주가 더 편해질 수 있어요',
        ];
        final now = DateTime.now();
        return titles[now.microsecondsSinceEpoch % titles.length];
    }

    static String _rotatingSubtitle(HeaderFocusType type) {
        final dayIndex = DateTime.now().day % 4;

        final expiryLines = [
            '마지막까지 좋은 경험으로 이어질 수 있게 확인해보세요.',
            '만료 전 안내 한 번이 재등록으로 이어질 수 있어요.',
            '남은 횟수가 적은 회원부터 먼저 챙겨보세요.',
            '작은 안내가 다음 기회로 연결될 수 있어요.',
        ];

        final attentionLines = [
            '신규와 확인 필요 회원을 함께 살펴보세요.',
            '지금 체크해두면 운영 흐름이 훨씬 편해져요.',
            '간단한 확인만으로 만족도가 달라질 수 있어요.',
            '놓치기 쉬운 회원부터 먼저 확인해보세요.',
        ];

        final birthdayLines = [
            '기억해주는 한마디가 좋은 경험으로 남을 수 있어요.',
            '세심한 일정 확인이 관계를 더 좋게 만들어요.',
            '소중한 일정을 챙기면 만족도가 높아질 수 있어요.',
            '가벼운 축하와 체크가 오래 남는 경험이 될 수 있어요.',
        ];

        final calmLines = [
            '오늘의 흐름을 차분하게 점검해보세요.',
            '좋은 흐름일수록 기본 관리가 중요해요.',
            '지금처럼 안정적으로 운영을 이어가면 돼요.',
            '작은 점검이 더 매끄러운 하루를 만들어요.',
        ];

        return switch (type) {
            HeaderFocusType.expiry => expiryLines[dayIndex],
            HeaderFocusType.newMember => attentionLines[dayIndex],
            HeaderFocusType.attention => attentionLines[dayIndex],
            HeaderFocusType.birthday => birthdayLines[dayIndex],
            HeaderFocusType.calm => calmLines[dayIndex],
        };
    }
}

enum _DashboardHeaderMenuAction {
    toggleGrouping,
    createGroup,
    resetFilters,
    restoreDeletedMembers,
}
class DashboardBlueHeader extends StatefulWidget {
    const DashboardBlueHeader({
        super.key,
        required this.data,
        required this.onBackTap,
        required this.isGroupingMode,
        required this.onAddCustomer,
        required this.onToggleGroupingMode,
        required this.onCreateGroup,
        required this.onResetFilters,
        required this.onRestoreDeletedMembers,

        required this.selectedGroupLabel,
        required this.groupFilterItems,
        required this.onGroupFilterSelected,


        required this.onAlertTap,
    });

    final DashboardHeaderData data;
    final VoidCallback onBackTap;
    final bool isGroupingMode;
    final VoidCallback onAddCustomer;
    final VoidCallback onToggleGroupingMode;
    final VoidCallback onCreateGroup;
    final VoidCallback onResetFilters;
    final VoidCallback onRestoreDeletedMembers;

    final String selectedGroupLabel;
    final List<_MemberCardGroupMenuItem> groupFilterItems;
    final ValueChanged<String> onGroupFilterSelected;

    final void Function(String memberId)? onAlertTap;

    @override
    State<DashboardBlueHeader> createState() => _DashboardBlueHeaderState();
}

class _DashboardBlueHeaderState extends State<DashboardBlueHeader>
    with TickerProviderStateMixin {
    bool _expanded = false;
    String _overlayGuideText = '';

    bool get isExpanded => _expanded;

    void _toggleOverlay() {
        setState(() {
            _expanded = !_expanded;
            if (_expanded) {
                _overlayGuideText = _buildGuideTextOnce(widget.data.focusType);
            }
        });
    }

    void closeOverlayFromOutside() {
        if (!_expanded) return;
        setState(() => _expanded = false);
    }

    void _openOverlay() {
        if (_expanded) return;
        setState(() {
            _expanded = true;
            _overlayGuideText = _buildGuideTextOnce(widget.data.focusType);
        });
    }

    Future<void> _closeOverlay() async {
        if (!_expanded) return;
        setState(() => _expanded = false);
    }

    bool containsGlobalPosition(Offset globalPosition) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return false;

        final rect = box.localToGlobal(Offset.zero) & box.size;
        return rect.contains(globalPosition);
    }

    String _buildGuideTextOnce(HeaderFocusType focusType) {
        final expiryLines = [
            '마지막까지 좋은 경험으로 이어질 수 있게 확인해보세요.',
            '만료 전 안내 한 번이 재등록 흐름을 만들 수 있어요.',
            '남은 횟수가 적은 회원부터 먼저 챙겨보세요.',
            '작은 안내가 다음 기회로 연결될 수 있어요.',
        ];

        final attentionLines = [
            '신규와 확인 필요 회원을 함께 살펴보세요.',
            '지금 체크해두면 한 주의 흐름이 훨씬 편해져요.',
            '간단한 확인만으로 만족도가 달라질 수 있어요.',
            '놓치기 쉬운 회원부터 먼저 확인해보세요.',
        ];

        final birthdayLines = [
            '기억해주는 한마디가 좋은 경험으로 남을 수 있어요.',
            '세심한 일정 확인이 관계를 더 좋게 만들어요.',
            '소중한 일정을 챙기면 만족도가 높아질 수 있어요.',
            '가벼운 축하와 체크가 오래 남는 경험이 될 수 있어요.',
        ];

        final calmLines = [
            '오늘의 흐름을 차분하게 점검해보세요.',
            '좋은 흐름일수록 한번 더 기본 관리를 살펴 봐야해요.',
            '지금처럼 행복은 강도가 아니라 빈도에서 온데요.',
            '작은 점검이 더 매끄러운 하루를 만들어요.',
        ];

        final lines = switch (focusType) {
            HeaderFocusType.expiry => expiryLines,
            HeaderFocusType.newMember => attentionLines,
            HeaderFocusType.attention => attentionLines,
            HeaderFocusType.birthday => birthdayLines,
            HeaderFocusType.calm => calmLines,
        };

        final index = DateTime.now().microsecondsSinceEpoch % lines.length;
        return lines[index];
    }

    void _handleMenuSelected(_DashboardHeaderMenuAction action) {
        switch (action) {
            case _DashboardHeaderMenuAction.toggleGrouping:
                widget.onToggleGroupingMode();
                break;
            case _DashboardHeaderMenuAction.createGroup:
                widget.onCreateGroup();
                break;
            case _DashboardHeaderMenuAction.resetFilters:
                widget.onResetFilters();
                break;
            case _DashboardHeaderMenuAction.restoreDeletedMembers:
                widget.onRestoreDeletedMembers();
                break;
        }
    }
    void _handleHeaderDragUpdate(DragUpdateDetails details) {
        final delta = details.primaryDelta ?? 0;

        if (delta > 8 && !_expanded) {
            _openOverlay();
        } else if (delta < -8 && _expanded) {
            _closeOverlay();
        }
    }

    @override
    Widget build(BuildContext context) {
        final data = widget.data;
        final topPadding = MediaQuery.of(context).padding.top;

        return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: _handleHeaderDragUpdate,
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                width: double.infinity,
                padding: EdgeInsets.only(
                    top: topPadding + 12,
                    left: 16,
                    right: 16,
                    bottom: 14,
                ),
                decoration: BoxDecoration(
                    color: const Color(0xFF5B4BDB),
                    borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(_expanded ? 22 : 28),
                    ),
                    boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                        ),
                    ],
                ),
                child: AnimatedSize(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            SizedBox(
                                height: 44,
                                child: Row(
                                    children: [
                                        Container(
                                            width: 42,
                                            height: 42,
                                            decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: Colors.white.withOpacity(0.3),
                                                    width: 2,
                                                ),
                                            ),
                                            child: InkWell(
                                                onTap: widget.onBackTap,
                                                borderRadius: BorderRadius.circular(999),
                                                child: const Center(
                                                    child: Text(
                                                        '<',
                                                        style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 24,
                                                            fontWeight: FontWeight.w500,
                                                            height: 1.0,
                                                        ),
                                                    ),
                                                ),
                                            ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                            child: Row(
                                                children: [
                                                    const Text(
                                                        '내 회원 관리',
                                                        style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 19,
                                                            fontWeight: FontWeight.w800,
                                                            letterSpacing: -0.2,
                                                        ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    PopupMenuButton<String>(
                                                        onSelected: widget.onGroupFilterSelected,
                                                        color: Colors.white,
                                                        tooltip: '그룹 선택',
                                                        offset: const Offset(0, 28),
                                                        constraints: const BoxConstraints(
                                                            minWidth: 170,
                                                            maxWidth: 210,
                                                        ),
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius: BorderRadius.circular(14),
                                                        ),
                                                        itemBuilder: (context) {
                                                            return widget.groupFilterItems.map((item) {
                                                                final bool isSelected =
                                                                    (widget.selectedGroupLabel == item.label) ||
                                                                        (widget.selectedGroupLabel == '전체' &&
                                                                            item.id == '__all__');

                                                                return PopupMenuItem<String>(
                                                                    value: item.id,
                                                                    child: Row(
                                                                        children: [
                                                                            Icon(
                                                                                item.icon,
                                                                                size: 15,
                                                                                color: isSelected
                                                                                    ? const Color(0xFF5B4BDB)
                                                                                    : const Color(0xFF4B5563),
                                                                            ),
                                                                            const SizedBox(width: 8),
                                                                            Expanded(
                                                                                child: Text(
                                                                                    item.label,
                                                                                    maxLines: 1,
                                                                                    overflow: TextOverflow.ellipsis,
                                                                                    style: TextStyle(
                                                                                        fontSize: 12.2,
                                                                                        fontWeight: isSelected
                                                                                            ? FontWeight.w900
                                                                                            : FontWeight.w700,
                                                                                        color: isSelected
                                                                                            ? const Color(0xFF5B4BDB)
                                                                                            : const Color(0xFF111827),
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        ],
                                                                    ),
                                                                );
                                                            }).toList();
                                                        },
                                                        child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                                Text(
                                                                    widget.selectedGroupLabel,
                                                                    style: TextStyle(
                                                                        color: Colors.white.withValues(alpha: 0.88),
                                                                        fontSize: 11.8,
                                                                        fontWeight: FontWeight.w700,
                                                                        letterSpacing: -0.1,
                                                                    ),
                                                                ),
                                                                const SizedBox(width: 2),
                                                                Icon(
                                                                    Icons.keyboard_arrow_down_rounded,
                                                                    color: Colors.white.withValues(alpha: 0.88),
                                                                    size: 16,
                                                                ),
                                                            ],
                                                        ),
                                                    ),
                                                ],
                                            ),
                                        ),
                                        Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                                InkWell(
                                                    onTap: widget.onAddCustomer,
                                                    borderRadius: BorderRadius.circular(999),
                                                    child: Container(
                                                        width: 40,
                                                        height: 40,
                                                        decoration: BoxDecoration(
                                                            color: Colors.white.withValues(alpha: 0.14),
                                                            shape: BoxShape.circle,
                                                            border: Border.all(
                                                                color: Colors.white.withValues(alpha: 0.18),
                                                            ),
                                                        ),
                                                        child: const Icon(
                                                            Icons.person_add_alt_1_rounded,
                                                            color: Colors.white,
                                                            size: 20,
                                                        ),
                                                    ),
                                                ),
                                                const SizedBox(width: 8),
                                                PopupMenuButton<_DashboardHeaderMenuAction>(
                                                    onSelected: _handleMenuSelected,
                                                    color: Colors.white,
                                                    tooltip: '더보기',
                                                    shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(16),
                                                    ),
                                                    padding: EdgeInsets.zero,
                                                    icon: Container(
                                                        width: 40,
                                                        height: 40,
                                                        decoration: BoxDecoration(
                                                            color: Colors.white.withValues(alpha: 0.14),
                                                            shape: BoxShape.circle,
                                                            border: Border.all(
                                                                color: Colors.white.withValues(alpha: 0.18),
                                                            ),
                                                        ),
                                                        child: const Icon(
                                                            Icons.more_horiz_rounded,
                                                            color: Colors.white,
                                                            size: 21,
                                                        ),
                                                    ),
                                                    itemBuilder: (context) => [
                                                        PopupMenuItem(
                                                            value: _DashboardHeaderMenuAction.toggleGrouping,
                                                            child: Row(
                                                                children: [
                                                                    Icon(
                                                                        widget.isGroupingMode
                                                                            ? Icons.close_fullscreen_rounded
                                                                            : Icons.groups_2_rounded,
                                                                        size: 18,
                                                                        color: const Color(0xFF4B5563),
                                                                    ),
                                                                    const SizedBox(width: 10),
                                                                    Text(widget.isGroupingMode ? '그룹핑 종료' : '그룹핑 시작'),
                                                                ],
                                                            ),
                                                        ),
                                                        const PopupMenuDivider(),
                                                        const PopupMenuItem(
                                                            value: _DashboardHeaderMenuAction.createGroup,
                                                            child: Row(
                                                                children: [
                                                                    Icon(
                                                                        Icons.add_box_rounded,
                                                                        size: 18,
                                                                        color: Color(0xFF4B5563),
                                                                    ),
                                                                    SizedBox(width: 10),
                                                                    Text('새 그룹 만들기'),
                                                                ],
                                                            ),
                                                        ),
                                                        const PopupMenuItem(
                                                            value: _DashboardHeaderMenuAction.resetFilters,
                                                            child: Row(
                                                                children: [
                                                                    Icon(
                                                                        Icons.restart_alt_rounded,
                                                                        size: 18,
                                                                        color: Color(0xFF4B5563),
                                                                    ),
                                                                    SizedBox(width: 10),
                                                                    Text('필터 초기화'),

                                                                ],
                                                            ),
                                                        ),
                                                        const PopupMenuItem(
                                                            value: _DashboardHeaderMenuAction.restoreDeletedMembers,
                                                            child: Row(
                                                                children: [
                                                                    Icon(
                                                                        Icons.restore_from_trash_rounded,
                                                                        size: 18,
                                                                        color: Color(0xFF4B5563),
                                                                    ),
                                                                    SizedBox(width: 10),
                                                                    Text('삭제 대기 회원 복구'),
                                                                ],
                                                            ),
                                                        ),
                                                    ],
                                                ),
                                            ],
                                        ),
                                    ],
                                ),
                            ),
                            const SizedBox(height: 10),
                            Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                    data.dailyTitle,
                                    textAlign: TextAlign.left,
                                    style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.92),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.2,
                                    ),
                                ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                                children: [
                                    Expanded(child: _StatCard(icon: Icons.warning_amber_rounded, label: '만료예정', value: '${data.expiryCount}')),
                                    const SizedBox(width: 8),
                                    Expanded(child: _StatCard(icon: Icons.celebration_outlined, label: '소중한일정', value: '${data.birthdayCount}')),
                                    const SizedBox(width: 8),
                                    Expanded(child: _StatCard(icon: Icons.task_alt_rounded, label: '체크해보세요', value: '${data.attentionCount}')),
                                ],
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                                onTap: _toggleOverlay,
                                borderRadius: BorderRadius.circular(13),
                                child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.10),
                                        borderRadius: BorderRadius.circular(13),
                                        border: Border.all(
                                            color: Colors.white.withValues(alpha: 0.14),
                                        ),
                                    ),
                                    child: Row(
                                        children: [
                                            const Expanded(
                                                child: Text(
                                                    '세심한 관리 일정',
                                                    style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 12.8,
                                                        fontWeight: FontWeight.w800,
                                                    ),
                                                ),
                                            ),
                                            Icon(
                                                _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                                color: Colors.white.withValues(alpha: 0.92),
                                                size: 20,
                                            ),
                                        ],
                                    ),
                                ),
                            ),
                            ClipRect(
                                child: AnimatedSize(
                                    duration: const Duration(milliseconds: 260),
                                    curve: Curves.easeOutCubic,
                                    alignment: Alignment.topCenter,
                                    child: !_expanded
                                        ? const SizedBox.shrink()
                                        : Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: _HeaderSlideOverlay(
                                            data: widget.data,
                                            guideText: _overlayGuideText,
                                            onClose: () {
                                                setState(() => _expanded = false);
                                            },
                                            onAlertTap: widget.onAlertTap,
                                        ),
                                    ),
                                ),
                            ),
                        ],
                    ),
                ),
            ),
        );
    }
}

class _HeaderSlideOverlayState extends State<_HeaderSlideOverlay> {
    final Set<String> _dismissedAlertKeys = <String>{};
    final ScrollController _alertScrollController = ScrollController();

    bool _showScrollHint = false;
    bool _isNearBottom = false;

    String _alertKey(DashboardAlert alert, int i) =>
        '${alert.type.name}_${alert.customerName}_${alert.label}_$i';

    @override
    void initState() {
        super.initState();
        _alertScrollController.addListener(_handleAlertScroll);
        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _updateScrollHintState();
        });
    }

    @override
    void dispose() {
        _alertScrollController
            ..removeListener(_handleAlertScroll)
            ..dispose();
        super.dispose();
    }

    void _handleAlertScroll() {
        _updateScrollHintState();
    }

    void _updateScrollHintState() {
        if (!_alertScrollController.hasClients) return;

        final position = _alertScrollController.position;
        final bool nextShowScrollHint = position.maxScrollExtent > 12;
        final bool nextIsNearBottom =
            position.pixels >= (position.maxScrollExtent - 24);

        if (_showScrollHint != nextShowScrollHint ||
            _isNearBottom != nextIsNearBottom) {
            setState(() {
                _showScrollHint = nextShowScrollHint;
                _isNearBottom = nextIsNearBottom;
            });
        }
    }

    Future<void> _handleHintTap() async {
        if (!_alertScrollController.hasClients) return;

        final position = _alertScrollController.position;

        if (_isNearBottom) {
            await _alertScrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
            );
            return;
        }

        final double nextOffset = (position.pixels + 220).clamp(
            0,
            position.maxScrollExtent,
        );

        await _alertScrollController.animateTo(
            nextOffset,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
        );
    }

    void _restoreAlert(String key) {
        setState(() {
            _dismissedAlertKeys.remove(key);
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _updateScrollHintState();
        });
    }

    void _dismissAlert(String key, DashboardAlert alert) {
        setState(() {
            _dismissedAlertKeys.add(key);
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _updateScrollHintState();
        });

        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.hideCurrentSnackBar();
        messenger?.showSnackBar(
            SnackBar(
                content: Text('${alert.customerName}님 알림을 숨겼어요'),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
                action: SnackBarAction(
                    label: '실행취소',
                    onPressed: () => _restoreAlert(key),
                ),
            ),
        );
    }

    @override
    Widget build(BuildContext context) {
        final indexed = widget.data.alerts.asMap().entries.toList();

        final remaining = indexed
            .where((e) => !_dismissedAlertKeys.contains(_alertKey(e.value, e.key)))
            .toList();

        final hasAlerts = remaining.isNotEmpty;

        WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _updateScrollHintState();
        });

        return SizedBox(
            height: !hasAlerts ? 84 : 360,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    Text(
                        '"${widget.guideText}"',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.90),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                        ),
                    ),
                    const SizedBox(height: 10),
                    if (!hasAlerts)
                        Text(
                            '지금 바로 챙겨야 할 항목이 없어요.',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                            ),
                        )
                    else
                        Expanded(
                            child: Column(
                                children: [
                                    Expanded(
                                        child: ShaderMask(
                                            shaderCallback: (rect) => const LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                    Colors.white,
                                                    Colors.white,
                                                    Color(0xCCFFFFFF),
                                                    Color(0x55FFFFFF),
                                                ],
                                                stops: [0.0, 0.78, 0.90, 1.0],
                                            ).createShader(rect),
                                            blendMode: BlendMode.dstIn,
                                            child: ListView.separated(
                                                controller: _alertScrollController,
                                                padding: EdgeInsets.zero,
                                                physics: const BouncingScrollPhysics(),
                                                itemCount: remaining.length,
                                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                                itemBuilder: (_, i) {
                                                    final entry = remaining[i];
                                                    final alert = entry.value;
                                                    final key = _alertKey(alert, entry.key);

                                                    return Dismissible(
                                                        key: ValueKey(key),
                                                        direction: DismissDirection.horizontal,
                                                        dismissThresholds: const {
                                                            DismissDirection.startToEnd: 0.22,
                                                            DismissDirection.endToStart: 0.22,
                                                        },
                                                        background: const _OverlayDismissBackground(
                                                            alignment: Alignment.centerLeft,
                                                            icon: Icons.delete_sweep_rounded,
                                                        ),
                                                        secondaryBackground: const _OverlayDismissBackground(
                                                            alignment: Alignment.centerRight,
                                                            icon: Icons.delete_sweep_rounded,
                                                        ),
                                                        onDismissed: (_) => _dismissAlert(key, alert),
                                                        child: GestureDetector(
                                                            behavior: HitTestBehavior.opaque,
                                                            onTap: () {
                                                                widget.onClose();
                                                                widget.onAlertTap?.call(alert.memberId);
                                                            },
                                                            child: _OverlayAlertTileBlue(alert: alert),
                                                        ),
                                                    );
                                                },
                                            ),
                                        ),
                                    ),
                                    if (_showScrollHint) ...[
                                        const SizedBox(height: 8),
                                        InkWell(
                                            onTap: _handleHintTap,
                                            borderRadius: BorderRadius.circular(12),
                                            child: Padding(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                ),
                                                child: Center(
                                                    child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                            Icon(
                                                                _isNearBottom
                                                                    ? Icons.keyboard_arrow_up_rounded
                                                                    : Icons.keyboard_arrow_down_rounded,
                                                                color: Colors.white.withValues(alpha: 0.82),
                                                                size: 18,
                                                            ),
                                                            const SizedBox(width: 2),
                                                            Text(
                                                                _isNearBottom
                                                                    ? '위쪽 소식 다시 보기'
                                                                    : '아래 소식 더 보기',
                                                                textAlign: TextAlign.center,
                                                                style: TextStyle(
                                                                    color: Colors.white.withValues(alpha: 0.78),
                                                                    fontSize: 11.5,
                                                                    fontWeight: FontWeight.w700,
                                                                ),
                                                            ),
                                                        ],
                                                    ),
                                                ),
                                            ),
                                        ),
                                    ],
                                ],
                            ),
                        ),
                ],
            ),
        );
    }
}

class _HeaderSlideOverlay extends StatefulWidget {
    const _HeaderSlideOverlay({
        required this.data,
        required this.guideText,
        required this.onClose,
        required this.onAlertTap,
    });

    final DashboardHeaderData data;
    final String guideText;
    final VoidCallback onClose;
    final void Function(String memberId)? onAlertTap;

    @override
    State<_HeaderSlideOverlay> createState() => _HeaderSlideOverlayState();
}

class _OverlayDismissBackground extends StatelessWidget {
  const _OverlayDismissBackground({
    required this.alignment,
    required this.icon,
  });

  final Alignment alignment;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: alignment,
      child: Icon(
        icon,
        color: Colors.white.withValues(alpha: 0.95),
        size: 22,
      ),
    );
  }
}

class _OverlayAlertTileBlue extends StatelessWidget {
    const _OverlayAlertTileBlue({required this.alert});

    final DashboardAlert alert;

    @override
    Widget build(BuildContext context) {
        final style = _alertStyle(alert.type);

        return Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
                color: style.tileColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: style.borderColor),
            ),
            child: Row(
                children: [
                    Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: style.badgeColor,
                            shape: BoxShape.circle,
                        ),
                        child: Text(
                            style.iconText,
                            style: const TextStyle(fontSize: 14),
                        ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: RichText(
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                                children: [
                                    TextSpan(
                                        text: '${alert.customerName}님 ',
                                        style: TextStyle(
                                            fontSize: 12.4,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white.withValues(alpha: 0.98),
                                        ),
                                    ),
                                    TextSpan(
                                        text: alert.label,
                                        style: TextStyle(
                                            fontSize: 12.0,
                                            fontWeight: FontWeight.w700,
                                            color: style.labelColor,
                                        ),
                                    ),
                                ],
                            ),
                        ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                            style.tagText,
                            style: TextStyle(
                                fontSize: 10.2,
                                fontWeight: FontWeight.w800,
                                color: style.tagColor,
                            ),
                        ),
                    ),
                ],
            ),
        );
    }
}

_OverlayAlertVisualStyle _alertStyle(AlertType type) {
    switch (type) {
        case AlertType.membershipExpiry:
            return _OverlayAlertVisualStyle(
                iconText: '⚠️',
                tagText: '만료',
                tileColor: const Color(0x26FF8A65),
                borderColor: const Color(0x42FFB199),
                badgeColor: const Color(0x33FFFFFF),
                labelColor: const Color(0xFFFFD7CC),
                tagColor: const Color(0xFFFFE2D8),
            );

        case AlertType.newMember:
            return _OverlayAlertVisualStyle(
                iconText: '💫',
                tagText: '신규',
                tileColor: const Color(0x2610B981),
                borderColor: const Color(0x4234D399),
                badgeColor: const Color(0x33FFFFFF),
                labelColor: const Color(0xFFD9FFEF),
                tagColor: const Color(0xFFE7FFF4),
            );

        case AlertType.attentionNeeded:
            return _OverlayAlertVisualStyle(
                iconText: '✅️',
                tagText: '확인',
                tileColor: const Color(0x26F59E0B),
                borderColor: const Color(0x42FBBF24),
                badgeColor: const Color(0x33FFFFFF),
                labelColor: const Color(0xFFFFEDC2),
                tagColor: const Color(0xFFFFF3D9),
            );

        case AlertType.birthday:
            return _OverlayAlertVisualStyle(
                iconText: '🎉',
                tagText: '일정',
                tileColor: const Color(0x26EC4899),
                borderColor: const Color(0x42F472B6),
                badgeColor: const Color(0x33FFFFFF),
                labelColor: const Color(0xFFFFD9EB),
                tagColor: const Color(0xFFFFE7F2),
            );

        case AlertType.healthCheck:
            return _OverlayAlertVisualStyle(
                iconText: '🩺',
                tagText: '건강체크',
                tileColor: const Color(0x2622C55E),
                borderColor: const Color(0x424ADE80),
                badgeColor: const Color(0x33FFFFFF),
                labelColor: const Color(0xFFD8FFE7),
                tagColor: const Color(0xFFE8FFF0),
            );

        case AlertType.hundredDay:
            return _OverlayAlertVisualStyle(
                iconText: '💯',
                tagText: '100일',
                tileColor: const Color(0x268B5CF6),
                borderColor: const Color(0x42A78BFA),
                badgeColor: const Color(0x33FFFFFF),
                labelColor: const Color(0xFFE9DEFF),
                tagColor: const Color(0xFFF2ECFF),
            );

        case AlertType.hundredLesson:
            return _OverlayAlertVisualStyle(
                iconText: '🏅',
                tagText: '100회',
                tileColor: const Color(0x260EA5E9),
                borderColor: const Color(0x4238BDF8),
                badgeColor: const Color(0x33FFFFFF),
                labelColor: const Color(0xFFD9F3FF),
                tagColor: const Color(0xFFE8F8FF),
            );

        case AlertType.reRegistration:
            return _OverlayAlertVisualStyle(
                iconText: '💬',
                tagText: '재등록',
                tileColor: const Color(0x256366F1),
                borderColor: const Color(0x42818CF8),
                badgeColor: const Color(0x33FFFFFF),
                labelColor: const Color(0xFFE0E4FF),
                tagColor: const Color(0xFFEEF1FF),
            );

        case AlertType.painCheck:
            return _OverlayAlertVisualStyle(
                iconText: '🚨',
                tagText: '주의',
                tileColor: const Color(0x26EF4444),
                borderColor: const Color(0x42F87171),
                badgeColor: const Color(0x33FFFFFF),
                labelColor: const Color(0xFFFFD8D8),
                tagColor: const Color(0xFFFFE6E6),
            );
    }
}

class _OverlayAlertVisualStyle {
    const _OverlayAlertVisualStyle({
        required this.iconText,
        required this.tagText,
        required this.tileColor,
        required this.borderColor,
        required this.badgeColor,
        required this.labelColor,
        required this.tagColor,
    });

    final String iconText;
    final String tagText;
    final Color tileColor;
    final Color borderColor;
    final Color badgeColor;
    final Color labelColor;
    final Color tagColor;
}

class _StatCard extends StatelessWidget {
    const _StatCard({
        super.key,
        required this.icon,
        required this.label,
        required this.value,
    });

    final IconData icon;
    final String label;
    final String value;

    @override
    Widget build(BuildContext context) {
        return Container(
            height: 76,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: Row(
                children: [
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Text(
                                    label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                    ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                    value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        height: 1.0,
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

class _SearchAndFilterCard extends StatelessWidget {
    const _SearchAndFilterCard({
        required this.controller,
        required this.selectedLessonDate,
        required this.sortOption,
        required this.sortAscending,
        required this.onSearchChanged,
        required this.onMenuSelected,
        required this.onToggleSortDirection,
    });

    final TextEditingController controller;
    final DateTime? selectedLessonDate;
    final SortOption sortOption;
    final bool sortAscending;
    final ValueChanged<String> onSearchChanged;
    final ValueChanged<_SearchMenuAction> onMenuSelected;
    final VoidCallback onToggleSortDirection;

    @override
    Widget build(BuildContext context) {
        final bool hasDateFilter = selectedLessonDate != null;

        return Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
                color: kClientCardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kClientBorderColor),
                boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                    ),
                ],
            ),
            child: Row(
                children: [
                    Expanded(
                        child: TextField(
                            controller: controller,
                            onChanged: onSearchChanged,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                                hintText: hasDateFilter
                                    ? '이름/전화번호 검색 · ${_formatDate(selectedLessonDate!)}'
                                    : '이름/전화번호 검색',
                                prefixIcon: const Icon(Icons.search_rounded),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                ),
                            ),
                        ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                        onTap: onToggleSortDirection,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: kClientBorderColor),
                            ),
                            child: Icon(
                                sortAscending
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                size: 18,
                            ),
                        ),
                    ),
                    const SizedBox(width: 8),
                    PopupMenuButton<_SearchMenuAction>(
                        onSelected: onMenuSelected,
                        tooltip: '검색 옵션',
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                        ),
                        itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: _SearchMenuAction.sortName,
                                child: Text('정렬 · 이름순'),
                            ),
                            const PopupMenuItem(
                                value: _SearchMenuAction.sortExpirySoon,
                                child: Text('정렬 · 만료임박순'),
                            ),
                            const PopupMenuItem(
                                value: _SearchMenuAction.sortRecentLesson,
                                child: Text('정렬 · 최근이용순'),
                            ),
                            const PopupMenuItem(
                                value: _SearchMenuAction.sortRecentRegistration,
                                child: Text('정렬 · 최근등록순'),
                            ),
                            const PopupMenuDivider(),
                            const PopupMenuItem(
                                value: _SearchMenuAction.pickLessonDate,
                                child: Text('레슨 기록일 선택'),
                            ),
                            if (hasDateFilter)
                                const PopupMenuItem(
                                    value: _SearchMenuAction.clearLessonDate,
                                    child: Text('레슨 기록일 해제'),
                                ),
                        ],
                        child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                                color: hasDateFilter
                                    ? const Color(0xFFEFF6FF)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: kClientBorderColor),
                            ),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    const Icon(Icons.more_horiz_rounded, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                        _sortLabel(sortOption),
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                        ),
                                    ),
                                ],
                            ),
                        ),
                    ),
                ],
            ),
        );
    }

    static String _sortLabel(SortOption option) {
        switch (option) {
            case SortOption.name:
                return '이름순';
            case SortOption.expirySoon:
                return '만료임박';
            case SortOption.recentLesson:
                return '최근레슨';
            case SortOption.recentRegistration:
                return '최근등록';
        }
    }
}

class _PinnedSearchHeaderDelegate extends SliverPersistentHeaderDelegate {
    _PinnedSearchHeaderDelegate({
        required this.minExtentValue,
        required this.maxExtentValue,
        required this.child,
    });

    final double minExtentValue;
    final double maxExtentValue;
    final Widget child;

    @override
    double get minExtent => minExtentValue;

    @override
    double get maxExtent => maxExtentValue;

    @override
    Widget build(
        BuildContext context,
        double shrinkOffset,
        bool overlapsContent,
        ) {
        return child;
    }

    @override
    bool shouldRebuild(covariant _PinnedSearchHeaderDelegate oldDelegate) {
        return minExtentValue != oldDelegate.minExtentValue ||
            maxExtentValue != oldDelegate.maxExtentValue ||
            child != oldDelegate.child;
    }
}

class _GroupingModeBar extends StatelessWidget {
    const _GroupingModeBar({
        required this.isVisible,
        required this.selectedCount,
        required this.onClose,
        required this.onClearSelection,
    });

    final bool isVisible;
    final int selectedCount;
    final VoidCallback onClose;
    final VoidCallback? onClearSelection;

    @override
    Widget build(BuildContext context) {
        if (!isVisible) return const SizedBox.shrink();

        return Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
                color: const Color(0xFFF5F3FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD8B4FE)),
            ),
            child: Row(
                children: [
                    const Icon(
                        Icons.groups_2_rounded,
                        size: 16,
                        color: Color(0xFF7C3AED),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(
                            selectedCount == 0
                                ? '회원 선택'
                                : '$selectedCount명 선택됨',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF5B21B6),
                            ),
                        ),
                    ),
                    if (onClearSelection != null)
                        InkWell(
                            onTap: onClearSelection,
                            child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                    '초기화',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black54,
                                    ),
                                ),
                            ),
                        ),
                    InkWell(
                        onTap: onClose,
                        child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Text(
                                '닫기',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF7C3AED),
                                ),
                            ),
                        ),
                    ),
                ],
            ),
        );
    }
}

class _GroupingSidePanel extends StatelessWidget {
    const _GroupingSidePanel({
        required this.groupIds,
        required this.systemGroupIds,
        required this.ungroupedGroupId,
        required this.selectedGroupId,
        required this.selectedMemberCount,
        required this.groupCounts,
        required this.groupNames,
        required this.onSelectGroup,
        required this.onShowAll,
        required this.onApplyGroup,
        required this.onRenameGroup,
        required this.onDeleteGroup,
        required this.onCreateGroup,
        required this.onAcceptDrop,
    });

    final List<String> groupIds;
    final List<String> systemGroupIds;
    final String ungroupedGroupId;
    final String? selectedGroupId;
    final int selectedMemberCount;
    final Map<String, int> groupCounts;
    final Map<String, String> groupNames;
    final ValueChanged<String> onSelectGroup;
    final VoidCallback onShowAll;
    final VoidCallback onApplyGroup;
    final ValueChanged<String> onRenameGroup;
    final ValueChanged<String> onDeleteGroup;
    final VoidCallback onCreateGroup;
    final Future<void> Function(String draggedMemberId, String targetGroupId)
    onAcceptDrop;

    @override
    Widget build(BuildContext context) {
        return SizedBox(
            width: 104,
            child: Material(
                color: Colors.transparent,
                child: Container(
                    padding: const EdgeInsets.fromLTRB(7, 7, 7, 7),
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.97),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE9D5FF)),
                        boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                            ),
                        ],
                    ),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                            _GroupPanelActionTile(
                                label: '전체보기',
                                onTap: onShowAll,
                            ),
                            const SizedBox(height: 5),
                            _GroupPanelActionTile(
                                label: '+그룹추가',
                                onTap: onCreateGroup,
                            ),
                            const SizedBox(height: 7),
                            ...groupIds.map((groupId) {
                                return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: _GroupDropTile(
                                        title: groupNames[groupId] ?? groupId,
                                        count: groupCounts[groupId] ?? 0,
                                        isSelected: selectedGroupId == groupId,
                                        isSystem: false,
                                        accentColor: const Color(0xFF6D28D9),
                                        backgroundColor: const Color(0xFFF8FAFC),
                                        icon: Icons.folder_open_rounded,
                                        onTap: () => onSelectGroup(groupId),
                                        onEditTap: () => onRenameGroup(groupId),
                                        onDeleteTap: () => onDeleteGroup(groupId),
                                        onAcceptDrop: (draggedMemberId) async {
                                            await onAcceptDrop(draggedMemberId, groupId);
                                        },
                                    ),
                                );
                            }),
                            Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _GroupDropTile(
                                    title: groupNames[_MemberDashboardPageState._systemDormantGroupId] ?? '휴면회원',
                                    count: groupCounts[_MemberDashboardPageState._systemDormantGroupId] ?? 0,
                                    isSelected: selectedGroupId == _MemberDashboardPageState._systemDormantGroupId,
                                    isSystem: true,
                                    accentColor: const Color(0xFF7B8794),
                                    backgroundColor: const Color(0xFFF3F4F6),
                                    icon: Icons.bedtime_rounded,
                                    onTap: () => onSelectGroup(_MemberDashboardPageState._systemDormantGroupId),
                                    onEditTap: () => onRenameGroup(_MemberDashboardPageState._systemDormantGroupId),
                                    onDeleteTap: null,
                                    onAcceptDrop: (draggedMemberId) async {
                                        await onAcceptDrop(
                                            draggedMemberId,
                                            _MemberDashboardPageState._systemDormantGroupId,
                                        );
                                    },
                                ),
                            ),
                            _GroupDropTile(
                                title: groupNames[_MemberDashboardPageState._systemExpiredGroupId] ?? '만료회원',
                                count: groupCounts[_MemberDashboardPageState._systemExpiredGroupId] ?? 0,
                                isSelected: selectedGroupId == _MemberDashboardPageState._systemExpiredGroupId,
                                isSystem: true,
                                accentColor: const Color(0xFF4B5563),
                                backgroundColor: const Color(0xFFE5E7EB),
                                icon: Icons.warning_amber_rounded,
                                onTap: () => onSelectGroup(_MemberDashboardPageState._systemExpiredGroupId),
                                onEditTap: () => onRenameGroup(_MemberDashboardPageState._systemExpiredGroupId),
                                onDeleteTap: null,
                                onAcceptDrop: (draggedMemberId) async {
                                    await onAcceptDrop(
                                        draggedMemberId,
                                        _MemberDashboardPageState._systemExpiredGroupId,
                                    );
                                },
                            ),
                            const SizedBox(height: 7),
                            FilledButton(
                                onPressed: selectedMemberCount == 0 ? null : onApplyGroup,
                                style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF7C3AED),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: const Color(0xFFE9D5FF),
                                    disabledForegroundColor: const Color(0xFF8A8A8A),
                                    padding: const EdgeInsets.symmetric(vertical: 9),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(11),
                                    ),
                                ),
                                child: Text(
                                    selectedMemberCount == 0 ? '선택 없음' : '적용',
                                    style: const TextStyle(
                                        fontSize: 10.8,
                                        fontWeight: FontWeight.w800,
                                    ),
                                ),
                            ),
                        ],
                    ),
                ),
            ),
        );
    }
}

class _GroupPanelActionTile extends StatelessWidget {
    const _GroupPanelActionTile({
        required this.label,
        required this.onTap,
    });

    final String label;
    final VoidCallback onTap;

    @override
    Widget build(BuildContext context) {
        return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(11),
            child: Container(
                height: 36,
                decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: const Color(0xFFD8B4FE)),
                ),
                alignment: Alignment.center,
                child: Text(
                    label,
                    style: const TextStyle(
                        fontSize: 10.8,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6D28D9),
                    ),
                ),
            ),
        );
    }
}

class _GroupDropTile extends StatelessWidget {
    const _GroupDropTile({
        required this.title,
        required this.count,
        required this.isSelected,
        required this.isSystem,
        required this.accentColor,
        required this.backgroundColor,
        required this.icon,
        required this.onTap,
        required this.onEditTap,
        required this.onDeleteTap,
        required this.onAcceptDrop,
    });

    final String title;
    final int count;
    final bool isSelected;
    final bool isSystem;
    final Color accentColor;
    final Color backgroundColor;
    final IconData icon;
    final VoidCallback onTap;
    final VoidCallback onEditTap;
    final VoidCallback? onDeleteTap;
    final Future<void> Function(String draggedMemberId) onAcceptDrop;

    String _compactTitle(String value) {
        final chars = value.runes.toList();
        if (chars.length <= 4) return value;
        return '${String.fromCharCodes(chars.take(4))}…';
    }

    @override
    Widget build(BuildContext context) {
        return DragTarget<String>(
            onWillAcceptWithDetails: (_) => true,
            onAcceptWithDetails: (details) async {
                await onAcceptDrop(details.data);
            },
            builder: (context, candidateData, rejectedData) {
                final bool isHovering = candidateData.isNotEmpty;

                final Color bgColor = isHovering
                    ? accentColor.withValues(alpha: 0.15)
                    : isSelected
                    ? accentColor.withValues(alpha: 0.12)
                    : backgroundColor;

                final Color borderColor = isHovering
                    ? accentColor
                    : isSelected
                    ? accentColor.withValues(alpha: 0.66)
                    : accentColor.withValues(alpha: 0.20);

                return Column(
                    children: [
                        Material(
                            color: Colors.transparent,
                            child: InkWell(
                                onTap: onTap,
                                onLongPress: onEditTap,
                                borderRadius: BorderRadius.circular(11),
                                child: Ink(
                                    height: 56,
                                    padding: const EdgeInsets.fromLTRB(6, 6, 4, 6),
                                    decoration: BoxDecoration(
                                        color: bgColor,
                                        borderRadius: BorderRadius.circular(11),
                                        border: Border.all(
                                            color: borderColor,
                                            width: isHovering ? 1.2 : 1,
                                        ),
                                    ),
                                    child: Row(
                                        children: [
                                            Container(
                                                width: 22,
                                                height: 22,
                                                decoration: BoxDecoration(
                                                    color: Colors.white.withValues(alpha: 0.95),
                                                    borderRadius: BorderRadius.circular(7),
                                                ),
                                                child: Icon(
                                                    icon,
                                                    size: 12,
                                                    color: accentColor,
                                                ),
                                            ),
                                            const SizedBox(width: 5),
                                            Expanded(
                                                child: Center(
                                                    child: Text(
                                                        '총 $count명',
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                            fontSize: 9.4,
                                                            fontWeight: FontWeight.w800,
                                                            color: accentColor.withValues(alpha: 0.88),
                                                        ),
                                                    ),
                                                ),
                                            ),
                                            InkWell(
                                                onTap: onEditTap,
                                                borderRadius: BorderRadius.circular(6),
                                                child: Container(
                                                    width: 18,
                                                    height: 18,
                                                    decoration: BoxDecoration(
                                                        color: Colors.white.withValues(alpha: 0.92),
                                                        borderRadius: BorderRadius.circular(6),
                                                        border: Border.all(
                                                            color: borderColor.withValues(alpha: 0.64),
                                                        ),
                                                    ),
                                                    child: Icon(
                                                        Icons.edit_outlined,
                                                        size: 10,
                                                        color: accentColor,
                                                    ),
                                                ),
                                            ),
                                            if (!isSystem && onDeleteTap != null) ...[
                                                const SizedBox(width: 2),
                                                InkWell(
                                                    onTap: onDeleteTap,
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: Container(
                                                        width: 18,
                                                        height: 18,
                                                        decoration: BoxDecoration(
                                                            color: Colors.white.withValues(alpha: 0.92),
                                                            borderRadius: BorderRadius.circular(6),
                                                            border: Border.all(
                                                                color: borderColor.withValues(alpha: 0.64),
                                                            ),
                                                        ),
                                                        child: const Icon(
                                                            Icons.close_rounded,
                                                            size: 10,
                                                            color: Color(0xFF6B7280),
                                                        ),
                                                    ),
                                                ),
                                            ],
                                        ],
                                    ),
                                ),
                            ),
                        ),
                        const SizedBox(height: 2),
                        Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: Align(
                                alignment: Alignment.center,
                                child: Text(
                                    _compactTitle(title),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: accentColor,
                                    ),
                                ),
                            ),
                        ),
                    ],
                );
            },
        );
    }
}

class _MemberCardGroupMenuItem {
    const _MemberCardGroupMenuItem({
        required this.id,
        required this.label,
        required this.icon,
    });

    final String id;
    final String label;
    final IconData icon;
}

class MemberSimpleCard extends StatelessWidget {
    const MemberSimpleCard({
        super.key,
        required this.member,
        required this.onContractTap,
        required this.onEditTap,
        required this.onLogTap,
        required this.onPinTap,
        required this.isPinned,
        required this.onSetExpired,
        required this.onSetDormant,
        required this.onSetActive,
        required this.isGroupingMode,
        required this.isSelectedForGroup,
        required this.onGroupSelectTap,
        required this.onEnterGroupingMode,
        required this.selectedGroupDragCount,
        required this.onAnyInteraction,
        required this.highlightListenable,

        required this.displayGroupLabel,
        required this.displayGroupAccentColor,
        required this.displayGroupTextColor,
        required this.groupMenuItems,
        required this.onQuickGroupChanged,

        this.groupLabel,
    });

    final Member member;
    final String? groupLabel;
    final int selectedGroupDragCount;
    final VoidCallback onContractTap;
    final VoidCallback onEditTap;
    final VoidCallback onLogTap;
    final VoidCallback onPinTap;
    final bool isPinned;
    final VoidCallback onSetExpired;
    final VoidCallback onSetDormant;
    final VoidCallback onSetActive;
    final bool isGroupingMode;
    final bool isSelectedForGroup;
    final VoidCallback onGroupSelectTap;
    final VoidCallback onEnterGroupingMode;
    final VoidCallback onAnyInteraction;
    final ValueListenable<String?> highlightListenable;
    final String displayGroupLabel;
    final Color displayGroupAccentColor;
    final Color displayGroupTextColor;
    final List<_MemberCardGroupMenuItem> groupMenuItems;
    final ValueChanged<String> onQuickGroupChanged;

    @override
    Widget build(BuildContext context) {
        final chips = _buildIssueChips(member);
        final visibleChips = chips.take(2).toList();
        final hiddenChipCount = chips.length - visibleChips.length;

        void handleCardTap() {
            onAnyInteraction();
            if (isGroupingMode) {
                onGroupSelectTap();
            }
        }

        final Widget baseCard = RepaintBoundary(
            child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                    color: isSelectedForGroup
                        ? const Color(0xFFF6F0FF)
                        : _cardBackgroundColor(member),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                        color: isSelectedForGroup
                            ? const Color(0xFF8B5CF6)
                            : _cardBorderColor(member),
                        width: isSelectedForGroup ? 1.5 : 1,
                    ),
                    boxShadow: isGroupingMode
                        ? [
                        if (isSelectedForGroup)
                            const BoxShadow(
                                color: Color(0x1A8B5CF6),
                                blurRadius: 8,
                                offset: Offset(0, 3),
                            ),
                    ]
                        : [
                        BoxShadow(
                            color: isSelectedForGroup
                                ? const Color(0x268B5CF6)
                                : _cardShadowColor(member),
                            blurRadius: 12,
                            spreadRadius: 0,
                            offset: const Offset(0, 5),
                        ),
                    ],
                ),
                child: Column(
                    children: [
                        Padding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            child: Column(
                                children: [
                                    Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                            SizedBox(
                                                width: isGroupingMode ? 32 : 0,
                                                child: isGroupingMode
                                                    ? Padding(
                                                    padding: const EdgeInsets.only(right: 10),
                                                    child: Container(
                                                        width: 22,
                                                        height: 22,
                                                        decoration: BoxDecoration(
                                                            color: isSelectedForGroup
                                                                ? const Color(0xFF8B5CF6)
                                                                : Colors.white,
                                                            shape: BoxShape.circle,
                                                            border: Border.all(
                                                                color: isSelectedForGroup
                                                                    ? const Color(0xFF8B5CF6)
                                                                    : const Color(0xFFD1D5DB),
                                                            ),
                                                        ),
                                                        child: Icon(
                                                            isSelectedForGroup
                                                                ? Icons.check
                                                                : Icons.radio_button_unchecked,
                                                            size: 14,
                                                            color: isSelectedForGroup
                                                                ? Colors.white
                                                                : Colors.black38,
                                                        ),
                                                    ),
                                                )
                                                    : null,
                                            ),
                                            Expanded(
                                                child: InkWell(
                                                    borderRadius: BorderRadius.circular(16),
                                                    onTap: () {
                                                        onAnyInteraction();
                                                        if (isGroupingMode) {
                                                            onGroupSelectTap();
                                                        } else {
                                                            _showMemberInfoOverlay(context, chips);
                                                        }
                                                    },
                                                    child: Padding(
                                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                                        child: Wrap(
                                                            crossAxisAlignment: WrapCrossAlignment.center,
                                                            spacing: 8,
                                                            runSpacing: 8,
                                                            children: [
                                                                ...visibleChips,
                                                                if (hiddenChipCount > 0)
                                                                    _MoreChip(count: hiddenChipCount),
                                                            ],
                                                        ),
                                                    ),
                                                ),
                                            ),
                                            InkWell(
                                                onTap: () {
                                                    onAnyInteraction();
                                                    onPinTap();
                                                },
                                                borderRadius: BorderRadius.circular(999),
                                                child: Container(
                                                    width: 38,
                                                    height: 38,
                                                    decoration: BoxDecoration(
                                                        color: isPinned
                                                            ? const Color(0xFFFFF3F1)
                                                            : Colors.white.withValues(alpha: 0.96),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                            color: isPinned
                                                                ? const Color(0xFFF2B2A6)
                                                                : kClientBorderColor,
                                                        ),
                                                    ),
                                                    child: Icon(
                                                        isPinned
                                                            ? Icons.push_pin
                                                            : Icons.push_pin_outlined,
                                                        size: 18,
                                                        color: isPinned
                                                            ? const Color(0xFFE06A5F)
                                                            : Colors.black54,
                                                    ),
                                                ),
                                            ),
                                        ],
                                    ),

                                    const SizedBox(height: 8),

                                    Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                            _MemberDonutBadge(member: member),
                                            const SizedBox(width: 16),
                                            Expanded(
                                                child: Padding(
                                                    padding: const EdgeInsets.only(top: 2),
                                                    child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                            Wrap(
                                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                                spacing: 8,
                                                                runSpacing: 8,
                                                                children: [
                                                                    Text(
                                                                        member.name ?? '이름없음',
                                                                        style: const TextStyle(
                                                                            fontSize: 18,
                                                                            fontWeight: FontWeight.w900,
                                                                            color: Colors.black87,
                                                                        ),
                                                                    ),
                                                                    if (_isActiveMember(member) &&
                                                                        member.remainingSessions < 5)
                                                                        Container(
                                                                            padding: const EdgeInsets.symmetric(
                                                                                horizontal: 12,
                                                                                vertical: 8,
                                                                            ),
                                                                            decoration: BoxDecoration(
                                                                                color: Colors.white.withValues(alpha: 0.94),
                                                                                borderRadius: BorderRadius.circular(999),
                                                                            ),
                                                                            child: Text(
                                                                                '만료예정 ${member.remainingSessions}회',
                                                                                style: const TextStyle(
                                                                                    color: Color(0xFFFF6B4A),
                                                                                    fontSize: 12,
                                                                                    fontWeight: FontWeight.w800,
                                                                                ),
                                                                            ),
                                                                        ),
                                                                ],
                                                            ),
                                                            _CardMetaRow(
                                                                icon: Icons.event_available_rounded,
                                                                text: member.nextLessonAt != null
                                                                    ? '다음 레슨일 : ${_formatDate(member.nextLessonAt!)}'
                                                                    : '다음 레슨일 : 미정',
                                                            ),
                                                            const SizedBox(height: 2),
                                                            _CardMetaRow(
                                                                icon: Icons.fitness_center_rounded,
                                                                text: member.lastLogAt != null
                                                                    ? '마지막 레슨일 : ${_formatDate(member.lastLogAt!)}'
                                                                    : '기록 없음',
                                                            ),
                                                            const SizedBox(height: 2),
                                                            _CardMetaRow(
                                                                icon: Icons.app_registration_rounded,
                                                                text: member.recentReg != null
                                                                    ? '마지막 등록일 : ${_formatDate(member.recentReg!)}'
                                                                    : '기록 없음',
                                                            ),
                                                        ],
                                                    ),
                                                ),
                                            ),
                                            const SizedBox(width: 12),
                                            SizedBox(
                                                width: 92,
                                                child: Column(
                                                    children: [
                                                        _SideQuickButton(
                                                            label: '고객카드',
                                                            icon: Icons.badge_outlined,
                                                            onTap: () {
                                                                onAnyInteraction();
                                                                if (!isGroupingMode) {
                                                                    onEditTap();
                                                                }
                                                            },
                                                        ),
                                                        const SizedBox(height: 8),
                                                        _SideQuickButton(
                                                            label: '운동일지',
                                                            icon: Icons.edit_note_rounded,
                                                            onTap: () {
                                                                onAnyInteraction();
                                                                if (!isGroupingMode) {
                                                                    onLogTap();
                                                                }
                                                            },
                                                        ),
                                                    ],
                                                ),
                                            ),
                                        ],
                                    ),
                                ],
                            ),
                        ),
                        Container(
                            height: 42,
                            decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.05),
                                borderRadius: const BorderRadius.vertical(
                                    bottom: Radius.circular(22),
                                ),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            alignment: Alignment.centerRight,
                            child: PopupMenuButton<String>(
                                enabled: !isGroupingMode,
                                onSelected: onQuickGroupChanged,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                ),
                                offset: const Offset(0, -8),
                                itemBuilder: (context) {
                                    return groupMenuItems.map((item) {
                                        final Color itemColor =
                                        item.id == _MemberDashboardPageState._systemDormantGroupId
                                            ? const Color(0xFF6B7280)
                                            : item.id == _MemberDashboardPageState._systemExpiredGroupId
                                            ? const Color(0xFF374151)
                                            : const Color(0xFF4B5563);

                                        return PopupMenuItem<String>(
                                            value: item.id,
                                            child: Row(
                                                children: [
                                                    Icon(
                                                        item.icon,
                                                        size: 17,
                                                        color: itemColor,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                        child: Text(
                                                            item.label,
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                            style: TextStyle(
                                                                fontSize: 12.2,
                                                                fontWeight: FontWeight.w700,
                                                                color: itemColor,
                                                            ),
                                                        ),
                                                    ),
                                                ],
                                            ),
                                        );
                                    }).toList();
                                },
                                child: Padding(
                                    padding: const EdgeInsets.only(bottom: 3, right: 1),
                                    child: Text(
                                        displayGroupLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                            fontSize: 11.1,
                                            fontWeight: FontWeight.w800,
                                            color: displayGroupTextColor.withValues(alpha: 0.92),
                                            letterSpacing: 0.55,
                                        ),
                                    ),
                                ),
                            ),
                        ),
                    ],
                ),
            ),
        );

        final Widget highlightedCard = _CardHighlightWrapper(
            memberId: member.id,
            highlightListenable: highlightListenable,
            child: baseCard,
        );

        final card = GestureDetector(
            onTap: handleCardTap,
            onLongPress: isGroupingMode
                ? null
                : () {
                onAnyInteraction();
                _showMemberLongPressSheet(context);
            },
            child: highlightedCard,
        );

        if (!isGroupingMode) {
            return card;
        }

        final bool dragAsBundle =
            isSelectedForGroup && selectedGroupDragCount > 1;

        return LongPressDraggable<String>(
            key: ValueKey('drag_${member.id}'),
            data: member.id,
            maxSimultaneousDrags: 1,
            dragAnchorStrategy: pointerDragAnchorStrategy,
            onDragStarted: onAnyInteraction,
            feedback: IgnorePointer(
                child: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                        width: 220,
                        child: dragAsBundle
                            ? _MultiMemberDragFeedback(count: selectedGroupDragCount)
                            : _SingleMemberDragFeedback(
                            memberName: member.name ?? '회원',
                            groupLabel: groupLabel,
                        ),
                    ),
                ),
            ),
            childWhenDragging: Opacity(
                opacity: 0.38,
                child: card,
            ),
            child: card,
        );
    }

    void _showMemberInfoOverlay(BuildContext context, List<Widget> chips) {
        showDialog(
            context: context,
            barrierColor: Colors.black.withValues(alpha: 0.35),
            builder: (ctx) {
                return Dialog(
                    backgroundColor: Colors.transparent,
                    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    child: Container(
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.96),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.10),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                ),
                            ],
                        ),
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                            child: SingleChildScrollView(
                                child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                        Row(
                                            children: [
                                                Expanded(
                                                    child: Text(
                                                        member.name ?? '이름없음',
                                                        style: const TextStyle(
                                                            fontSize: 20,
                                                            fontWeight: FontWeight.w900,
                                                            color: Colors.black87,
                                                        ),
                                                    ),
                                                ),
                                                IconButton(
                                                    onPressed: () => Navigator.pop(ctx),
                                                    icon: const Icon(Icons.close_rounded),
                                                ),
                                            ],
                                        ),
                                        const SizedBox(height: 12),
                                        Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: chips.isEmpty
                                                ? [
                                                const _EmptyInfoChip(label: '표시할 상태 정보 없음'),
                                            ]
                                                : chips,
                                        ),
                                        const SizedBox(height: 18),
                                        _OverlayInfoRow(
                                            label: '회원 상태',
                                            value: member.memberStatus,
                                        ),
                                        _OverlayInfoRow(
                                            label: '남은 횟수',
                                            value:
                                            '${member.remainingSessions} / ${member.totalSessions}',
                                        ),
                                        _OverlayInfoRow(
                                            label: '담당 트레이너',
                                            value: member.trainer ?? '미지정',
                                        ),
                                        _OverlayInfoRow(
                                            label: '등급',
                                            value: member.grade ?? '미지정',
                                        ),
                                        _OverlayInfoRow(
                                            label: '다음 레슨일',
                                            value: member.nextLessonAt != null
                                                ? _formatDate(member.nextLessonAt!)
                                                : '미정',
                                        ),
                                        _OverlayInfoRow(
                                            label: '마지막 레슨일',
                                            value: member.lastLogAt != null
                                                ? _formatDate(member.lastLogAt!)
                                                : '기록 없음',
                                        ),
                                        _OverlayInfoRow(
                                            label: '마지막 등록일',
                                            value: member.recentReg != null
                                                ? _formatDate(member.recentReg!)
                                                : '기록 없음',
                                        ),
                                        _OverlayInfoRow(
                                            label: '만료일',
                                            value: member.expireAt != null
                                                ? _formatDate(member.expireAt!)
                                                : '미정',
                                        ),
                                        const SizedBox(height: 18),
                                        Row(
                                            children: [
                                                Expanded(
                                                    child: _SideQuickButton(
                                                        label: '고객정보',
                                                        icon: Icons.badge_outlined,
                                                        onTap: () {
                                                            Navigator.pop(ctx);
                                                            onAnyInteraction();
                                                            onEditTap();
                                                        },
                                                    ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                    child: _SideQuickButton(
                                                        label: '운동일지',
                                                        icon: Icons.edit_note_rounded,
                                                        onTap: () {
                                                            Navigator.pop(ctx);
                                                            onAnyInteraction();
                                                            onLogTap();
                                                        },
                                                    ),
                                                ),
                                            ],
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

    void _showMemberLongPressSheet(BuildContext context) {
        showModalBottomSheet(
            context: context,
            showDragHandle: true,
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (ctx) {
                return SafeArea(
                    child: ListView(
                        shrinkWrap: true,
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                        children: [
                            const Padding(
                                padding: EdgeInsets.fromLTRB(8, 4, 8, 10),
                                child: Text(
                                    '회원 분류 / 그룹 설정',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                    ),
                                ),
                            ),
                            ListTile(
                                leading: const Icon(Icons.school_outlined),
                                title: const Text('만료회원으로 전환'),
                                onTap: () {
                                    Navigator.pop(ctx);
                                    onAnyInteraction();
                                    onSetExpired();
                                },
                            ),
                            ListTile(
                                leading: const Icon(Icons.bedtime_outlined),
                                title: const Text('휴면회원으로 전환'),
                                onTap: () {
                                    Navigator.pop(ctx);
                                    onAnyInteraction();
                                    onSetDormant();
                                },
                            ),
                            ListTile(
                                leading: const Icon(Icons.groups_2_outlined),
                                title: const Text('그룹 설정하기'),
                                onTap: () {
                                    Navigator.pop(ctx);
                                    onAnyInteraction();
                                    onEnterGroupingMode();
                                },
                            ),
                            if (!_isActiveMember(member))
                                ListTile(
                                    leading: const Icon(Icons.autorenew_rounded),
                                    title: const Text('활성회원으로 전환'),
                                    onTap: () {
                                        Navigator.pop(ctx);
                                        onAnyInteraction();
                                        onSetActive();
                                    },
                                ),
                        ],
                    ),
                );
            },
        );
    }

    List<Widget> _buildIssueChips(Member member) {
        if (!_isActiveMember(member)) {
            return [];
        }

        final List<_IssueChipData> items = [];

        if (member.remainingSessions < 5) {
            items.add(
                const _IssueChipData(
                    label: '만료 임박',
                    bgColor: Color(0xFFFEF2F2),
                    textColor: Color(0xFFDC2626),
                ),
            );
        }

        if (member.firstDate != null &&
            _daysBetween(member.firstDate!, DateTime.now()) < 7) {
            items.add(
                const _IssueChipData(
                    label: '신규',
                    bgColor: Color(0xFFEEFDF3),
                    textColor: Color(0xFF15803D),
                ),
            );
        }

        if (member.expireAt != null) {
            items.add(
                _IssueChipData(
                    label: '만료일 ${_formatDate(member.expireAt!)}',
                    bgColor: const Color(0xFFEFF6FF),
                    textColor: const Color(0xFF2563EB),
                ),
            );
        }

        return items.map((e) => _IssueChip(data: e)).toList();
    }
}



class _InlineGroupLabel extends StatelessWidget {
    const _InlineGroupLabel({
        required this.label,
    });

    final String label;

    @override
    Widget build(BuildContext context) {
        return Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF6D28D9),
                letterSpacing: -0.1,
                shadows: [
                    Shadow(
                        color: Color(0x1A6D28D9),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                    ),
                ],
            ),
        );
    }
}

class _SingleMemberDragFeedback extends StatelessWidget {
    const _SingleMemberDragFeedback({
        required this.memberName,
        required this.groupLabel,
    });

    final String memberName;
    final String? groupLabel;

    @override
    Widget build(BuildContext context) {
        return Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: const Color(0xFF8B5CF6),
                    width: 1.5,
                ),
                boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 14,
                        offset: const Offset(0, 8),
                    ),
                ],
            ),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                    Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                            Icons.person_rounded,
                            color: Color(0xFF7C3AED),
                            size: 18,
                        ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(
                            memberName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.black87,
                            ),
                        ),
                    ),
                    if (groupLabel != null) ...[
                        const SizedBox(width: 8),
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Text(
                                groupLabel!,
                                style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black54,
                                ),
                            ),
                        ),
                    ],
                ],
            ),
        );
    }
}

class _MultiMemberDragFeedback extends StatelessWidget {
    const _MultiMemberDragFeedback({
        required this.count,
    });

    final int count;

    @override
    Widget build(BuildContext context) {
        return Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: const Color(0xFF8B5CF6),
                    width: 1.6,
                ),
                boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
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
                            color: const Color(0xFFF3E8FF),
                            borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                            Icons.layers_rounded,
                            color: Color(0xFF7C3AED),
                        ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                        '$count명 이동',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                        ),
                    ),
                ],
            ),
        );
    }
}

class _MoreChip extends StatelessWidget {
    const _MoreChip({required this.count});

    final int count;

    @override
    Widget build(BuildContext context) {
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: kClientBorderColor),
            ),
            child: Text(
                '+$count',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                ),
            ),
        );
    }
}

class _SideQuickButton extends StatelessWidget {
    const _SideQuickButton({
        required this.label,
        required this.onTap,
        this.icon,
    });

    final String label;
    final VoidCallback onTap;
    final IconData? icon;

    @override
    Widget build(BuildContext context) {
        return Material(
            color: Colors.transparent,
            child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(16),
                child: Ink(
                    width: double.infinity,
                    height: 36,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFFE5E7EB),
                        ),
                    ),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                if (icon != null) ...[
                                    Icon(
                                        icon,
                                        size: 15,
                                        color: const Color(0xFF6B7280),
                                    ),
                                    const SizedBox(width: 4),
                                ],
                                Flexible(
                                    child: Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Color(0xFF374151),
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.1,
                                        ),
                                    ),
                                ),
                            ],
                        ),
                    ),
                ),
            ),
        );
    }
}

class _CardMetaRow extends StatelessWidget {
    const _CardMetaRow({
        required this.icon,
        required this.text,
    });

    final IconData icon;
    final String text;

    @override
    Widget build(BuildContext context) {
        return Row(
            children: [
                Icon(
                    icon,
                    size: 14,
                    color: Colors.black87,
                ),
                const SizedBox(width: 5),
                Expanded(
                    child: Text(
                        text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.2,
                            color: Colors.black87,
                            fontWeight: FontWeight.w600,
                            height: 1.18,
                        ),
                    ),
                ),
            ],
        );
    }
}

class _OverlayInfoRow extends StatelessWidget {
    const _OverlayInfoRow({
        required this.label,
        required this.value,
    });

    final String label;
    final String value;

    @override
    Widget build(BuildContext context) {
        return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    SizedBox(
                        width: 92,
                        child: Text(
                            label,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.black54,
                            ),
                        ),
                    ),
                    Expanded(
                        child: Text(
                            value,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                            ),
                        ),
                    ),
                ],
            ),
        );
    }
}

class _EmptyInfoChip extends StatelessWidget {
    const _EmptyInfoChip({required this.label});

    final String label;

    @override
    Widget build(BuildContext context) {
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
                label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                ),
            ),
        );
    }
}

class _BottomActionButton extends StatelessWidget {
    const _BottomActionButton({
        required this.label,
        required this.icon,
        required this.onTap,
    });

    final String label;
    final IconData icon;
    final VoidCallback onTap;

    @override
    Widget build(BuildContext context) {
        return InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
                height: 42,
                decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kClientBorderColor),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        Icon(icon, size: 16, color: Colors.black54),
                        const SizedBox(width: 6),
                        Flexible(
                            child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11,
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

class _MemberDonutBadge extends StatelessWidget {
    const _MemberDonutBadge({required this.member});

    final Member member;

    @override
    Widget build(BuildContext context) {
        final int totalSessions = member.totalSessions <= 0 ? 20 : member
            .totalSessions;
        final int remaining = member.remainingSessions.clamp(0, totalSessions);
        final int used = (totalSessions - remaining).clamp(0, totalSessions);
        final double progress = totalSessions == 0 ? 0 : used / totalSessions;

        final Color accent = _progressColor(member, remaining, totalSessions);

        return Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
                color: _donutShellColor(member),
                shape: BoxShape.circle,
                border: Border.all(color: _donutBorderColor(member)),
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
                            bg: _donutTrackColor(member),
                        ),
                    ),
                    Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                            Text(
                                '$remaining',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: _donutTextColor(member),
                                ),
                            ),
                            Text(
                                '/$totalSessions',
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: _donutSubTextColor(member),
                                ),
                            ),
                        ],
                    ),
                ],
            ),
        );
    }

    Color _progressColor(Member member, int remaining, int total) {
        if (_isExpiredMember(member)) {
            return const Color(0xFF6B7280);
        }
        if (_isDormantMember(member)) {
            return const Color(0xFF9CA3AF);
        }

        final ratio = total == 0 ? 0.0 : remaining / total;
        if (ratio <= 0.3) return Colors.white;
        if (ratio <= 0.7) return const Color(0xFFFFF3B0);
        return const Color(0xFF10B981);
    }

    Color _donutTrackColor(Member member) {
        if (_isExpiredMember(member)) {
            return const Color(0xFFD1D5DB);
        }
        if (_isDormantMember(member)) {
            return const Color(0xFFCBD5E1);
        }
        if (_isActiveMember(member) && member.remainingSessions < 5) {
            return Colors.white24;
        }
        return const Color(0xFFE5E7EB);
    }

    Color _donutShellColor(Member member) {
        if (_isExpiredMember(member)) {
            return const Color(0xFF9CA3AF);
        }
        if (_isDormantMember(member)) {
            return const Color(0xFFE5E7EB);
        }
        if (_isActiveMember(member) && member.remainingSessions < 5) {
            return const Color(0xFFEF4444);
        }
        return const Color(0xFFF8FAFC);
    }

    Color _donutBorderColor(Member member) {
        if (_isExpiredMember(member)) {
            return const Color(0xFF6B7280);
        }
        if (_isDormantMember(member)) {
            return const Color(0xFFD1D5DB);
        }
        if (member.remainingSessions < 5) {
            return const Color(0xFFDC2626);
        }
        return const Color(0xFFE5E7EB);
    }

    Color _donutTextColor(Member member) {
        if (_isExpiredMember(member) ||
            _isDormantMember(member) ||
            member.remainingSessions < 5) {
            return Colors.white;
        }
        return const Color(0xFF111827);
    }

    Color _donutSubTextColor(Member member) {
        if (_isExpiredMember(member) ||
            _isDormantMember(member) ||
            member.remainingSessions < 5) {
            return Colors.white70;
        }
        return const Color(0xFF6B7280);
    }
}

class _CardHighlightWrapper extends StatelessWidget {
    const _CardHighlightWrapper({
        required this.memberId,
        required this.highlightListenable,
        required this.child,
    });

    final String memberId;
    final ValueListenable<String?> highlightListenable;
    final Widget child;

    @override
    Widget build(BuildContext context) {
        return ValueListenableBuilder<String?>(
            valueListenable: highlightListenable,
            child: child,
            builder: (context, highlightedMemberId, baseChild) {
                final bool isHighlighted = highlightedMemberId == memberId;

                return TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                        begin: -1.55,
                        end: isHighlighted ? 1.55 : -1.55,
                    ),
                    duration: const Duration(milliseconds: 1150),
                    curve: Curves.easeInOutCubic,
                    child: baseChild,
                    builder: (context, sheenValue, child) {
                        return TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: 1.0,
                                end: isHighlighted ? 1.008 : 1.0,
                            ),
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            child: child,
                            builder: (context, scale, child) {
                                final double lift = isHighlighted ? -2 : 0;

                                return AnimatedContainer(
                                    duration: const Duration(milliseconds: 260),
                                    curve: Curves.easeOutCubic,
                                    transform: Matrix4.identity()..translate(0.0, lift),
                                    child: Transform.scale(
                                        scale: scale,
                                        alignment: Alignment.center,
                                        child: ClipRRect(
                                            borderRadius: BorderRadius.circular(22),
                                            child: Stack(
                                                clipBehavior: Clip.hardEdge,
                                                children: [
                                                    child!,
                                                    if (isHighlighted)
                                                        Positioned.fill(
                                                            child: IgnorePointer(
                                                                child: LayoutBuilder(
                                                                    builder: (context, constraints) {
                                                                        final double width = constraints.maxWidth;
                                                                        final double translateX = width * sheenValue;

                                                                        return Transform.translate(
                                                                            offset: Offset(translateX, 0),
                                                                            child: Transform.rotate(
                                                                                angle: -0.30,
                                                                                child: Align(
                                                                                    alignment: Alignment.centerLeft,
                                                                                    child: Container(
                                                                                        width: width * 0.26,
                                                                                        decoration: BoxDecoration(
                                                                                            gradient: LinearGradient(
                                                                                                begin: Alignment.centerLeft,
                                                                                                end: Alignment.centerRight,
                                                                                                colors: [
                                                                                                    Colors.white.withValues(alpha: 0.0),
                                                                                                    Colors.white.withValues(alpha: 0.08),
                                                                                                    Colors.white.withValues(alpha: 0.22),
                                                                                                    Colors.white.withValues(alpha: 0.34),
                                                                                                    Colors.white.withValues(alpha: 0.14),
                                                                                                    Colors.white.withValues(alpha: 0.0),
                                                                                                ],
                                                                                                stops: const [0.0, 0.16, 0.36, 0.52, 0.78, 1.0],
                                                                                            ),
                                                                                        ),
                                                                                    ),
                                                                                ),
                                                                            ),
                                                                        );
                                                                    },
                                                                ),
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
                );
            },
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
        final center = Offset(size.width / 2, size.height / 2);
        final radius = (size.width / 2) - stroke / 2;

        final bgPaint = Paint()
            ..color = bg
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round;

        final fgPaint = Paint()
            ..color = fg
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round;

        canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            0,
            3.1415926535 * 2,
            false,
            bgPaint,
        );

        canvas.drawArc(
            Rect.fromCircle(center: center, radius: radius),
            -3.1415926535 / 2,
            3.1415926535 * 2 * value,
            false,
            fgPaint,
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

class _IssueChipData {
    const _IssueChipData({
        required this.label,
        required this.bgColor,
        required this.textColor,
    });

    final String label;
    final Color bgColor;
    final Color textColor;
}

class _IssueChip extends StatelessWidget {
    const _IssueChip({required this.data});

    final _IssueChipData data;

    @override
    Widget build(BuildContext context) {
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
                color: data.bgColor,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                    BoxShadow(
                        color: data.textColor.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                    ),
                ],
            ),
            child: Text(
                data.label,
                style: TextStyle(
                    color: data.textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                ),
            ),
        );
    }
}

int _daysBetween(DateTime from, DateTime to) {
    final fromOnly = DateTime(from.year, from.month, from.day);
    final toOnly = DateTime(to.year, to.month, to.day);
    return toOnly.difference(fromOnly).inDays;
}

int _daysUntilThisYearBirthday(DateTime now, DateTime birthDate) {
    DateTime target = DateTime(now.year, birthDate.month, birthDate.day);
    if (target.isBefore(DateTime(now.year, now.month, now.day))) {
        target = DateTime(now.year + 1, birthDate.month, birthDate.day);
    }
    return _daysBetween(now, target);
}

bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

Color _cardBackgroundColor(Member member) {
    if (_isExpiredMember(member)) {
        return const Color(0xFFE5E7EB);
    }
    if (_isDormantMember(member)) {
        return const Color(0xFFF3F4F6);
    }

    switch (member.gender) {
        case Gender.male:
            return const Color(0xFFF2F8FF);
        case Gender.female:
            return const Color(0xFFFFF4F8);
        case Gender.unknown:
            return Colors.white;
    }
}

Color _cardBorderColor(Member member) {
    if (_isExpiredMember(member)) {
        return const Color(0xFFD1D5DB);
    }
    if (_isDormantMember(member)) {
        return const Color(0xFFE5E7EB);
    }

    switch (member.gender) {
        case Gender.male:
            return const Color(0xFFD7EAFE);
        case Gender.female:
            return const Color(0xFFF6D7E5);
        case Gender.unknown:
            return const Color(0xFFEAEAEA);
    }
}

Color _cardShadowColor(Member member) {
    if (_isExpiredMember(member)) {
        return const Color(0x1A6B7280);
    }
    if (_isDormantMember(member)) {
        return const Color(0x1273748B);
    }

    switch (member.gender) {
        case Gender.male:
            return const Color(0x144A90E2);
        case Gender.female:
            return const Color(0x14E46AA3);
        case Gender.unknown:
            return Colors.black.withValues(alpha: 0.06);
    }
}

String _digitsOnly(String value) {
    return value.replaceAll(RegExp(r'[^0-9]'), '');
}

int _compareNameOrder(String a, String b) {
    final aCategory = _nameCategory(a);
    final bCategory = _nameCategory(b);

    if (aCategory != bCategory) return aCategory.compareTo(bCategory);

    return a.toLowerCase().compareTo(b.toLowerCase());
}

int _nameCategory(String value) {
    if (value.isEmpty) return 4;

    final code = value.codeUnitAt(0);

    final isHangul = (code >= 0xAC00 && code <= 0xD7A3);
    final isEnglishUpper = (code >= 65 && code <= 90);
    final isEnglishLower = (code >= 97 && code <= 122);
    final isNumber = (code >= 48 && code <= 57);

    if (isHangul) return 0;
    if (isEnglishUpper || isEnglishLower) return 1;
    if (isNumber) return 2;
    return 3;
}

bool _isExpiredMember(Member member) {
    return member.memberStatus == '만료' || member.isExpired;
}

bool _isDormantMember(Member member) {
    return member.memberStatus == '휴면';
}

bool _isActiveMember(Member member) {
    return !_isExpiredMember(member) && !_isDormantMember(member);
}