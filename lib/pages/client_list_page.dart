import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../models/member.dart';
import '../models/personal_member_taxonomy.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'client_card_page.dart';
import 'personal_training_log_page.dart';
import '../utils/korean_search_utils.dart' as search_utils;
import '../services/app_tier_access_service.dart';
import '../services/personal_member_card_save_service.dart';
import '../services/personal_member_preferences_service.dart';
import '../services/personal_member_taxonomy_service.dart';
import 'personal_member_taxonomy_management_page.dart';
import '../widgets/aifc_tier_feature_gate_sheet.dart';
import '../widgets/personal_training_log_entry_guard.dart';
import '../theme/app_colors.dart';

import '../widgets/aifc_interaction.dart';
import '../aifc/core/aifc_nickname.dart';
import '../aifc/core/aifc_avatar.dart';
import '../aifc/core/aifc_chat_bubble.dart';
import '../aifc/core/aifc_sheet_frame.dart';
import '../widgets/aifc_confirm_chat_sheet.dart';
import '../widgets/aifc_info_chat_sheet.dart';
import '../widgets/aifc_personal_tag_management_chat_sheet.dart';
import '../aifc/core/aifc_theme.dart';
import '../widgets/aifc_option_chat_sheet.dart';
import '../widgets/personal_member_status_filter.dart';
import '../widgets/personal_taxonomy_filter_strip.dart';
import '../widgets/mtf_floating_more_menu.dart';
import '../widgets/mtf_header_neon_overlay.dart';

import 'dart:math' as math;
import 'dart:async';

const Color kClientBgColor = Color(0xFFF3F4F6);
const Color kClientCardColor = Colors.white;
const Color kClientBorderColor = Color(0xFFE5E7EB);
const double kClientPageHorizontalPadding = 16;
const double kClientMaxContentWidth = 480;

class ClientListPage extends StatefulWidget {
  const ClientListPage({
    super.key,
    this.initialFilter = ClientListInitialFilter.none,
    this.personalOwnerUid,
  });

  final ClientListInitialFilter initialFilter;
  final String? personalOwnerUid;

  @override
  State<ClientListPage> createState() => _MemberDashboardPageState();
}

// 예전 이름으로 열리는 곳이 있을 수 있어서 호환용으로 남김
class MemberDashboardPage extends ClientListPage {
  const MemberDashboardPage({super.key})
      : super(initialFilter: ClientListInitialFilter.none);
}

class _MemberDashboardPageState extends State<ClientListPage> {
  bool get _isPersonalWorkspace =>
      (widget.personalOwnerUid?.trim() ?? '').isNotEmpty;

  Query<Map<String, dynamic>> get _membersQuery {
    final query = FirebaseFirestore.instance.collection('members');
    final owner = widget.personalOwnerUid?.trim() ?? '';
    if (owner.isEmpty) return query;
    return query
        .where('trainerId', isEqualTo: owner)
        .where('workspaceType', isEqualTo: 'personal');
  }

  static const String _memberListViewModeKey = 'member_list_view_mode';

  static const String _lastSelectedGroupFilterKey =
      'client_list_last_selected_group_filter_v1';
  static const String _lastSelectedStatusFilterKey =
      'client_list_last_selected_status_filter_v1';

  static const String _allGroupId = '__all__';

  ClientListInitialFilter _initialQuickFilter = ClientListInitialFilter.none;

  final TextEditingController _searchController = TextEditingController();
  final ValueNotifier<String> _searchKeywordNotifier =
      ValueNotifier<String>('');
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<_DashboardBlueHeaderState> _headerKey =
      GlobalKey<_DashboardBlueHeaderState>();
  final int _headerMessageSeed = DateTime.now().microsecondsSinceEpoch;
  final Map<String, GlobalKey> _memberItemKeys = <String, GlobalKey>{};
  final ValueNotifier<String?> _highlightNotifier =
      ValueNotifier<String?>(null);
  int _highlightRequestToken = 0;

  bool _sortAscending = true;

  bool _isLowRemainingMember(Member member) {
    final remain = member.remainingSessions;
    return remain > 0 && remain <= 5;
  }

  bool _isCareNeededMember(Member member) {
    final isExpired = _isExpiredMember(member);
    final isDormant = _isDormantMember(member);
    final isActive = !isExpired && !isDormant;

    if (isDormant) return true;
    if (!isActive) return false;

    final remaining = member.remainingSessions;
    final total = member.totalSessions <= 0 ? 0 : member.totalSessions;
    final usedSessions = total <= 0 ? 0 : (total - remaining).clamp(0, total);

    final now = DateTime.now();
    final baseDate = member.recentReg ?? member.firstDate;
    final firstLessonDays =
        baseDate == null ? 9999 : _daysBetween(baseDate, now);

    final isLowRemaining = remaining > 0 && remaining <= 5;
    final isNewMember = firstLessonDays >= 0 && firstLessonDays < 7;
    final isHundredDay = firstLessonDays >= 93 && firstLessonDays <= 103;
    final isHundredLesson = usedSessions >= 93 && usedSessions <= 100;

    return isLowRemaining || isNewMember || isHundredDay || isHundredLesson;
  }

  DateTime? _selectedLessonDate;
  SortOption _sortOption = SortOption.name;
  _MembershipListFilter? _membershipFilter;

  final ValueNotifier<List<String>> _pinnedMemberIdsNotifier =
      ValueNotifier<List<String>>(<String>[]);

  final ValueNotifier<bool> _isListViewNotifier = ValueNotifier<bool>(false);

  static const String _ungroupedGroupId = '__ungrouped__';

  static const String _systemDormantGroupId = '__system_dormant__';
  static const String _systemExpiredGroupId = '__system_expired__';

  static const List<String> _systemGroupIds = <String>[
    _systemDormantGroupId,
    _systemExpiredGroupId,
  ];

  final List<String> _groupIds = [];
  final Map<String, String> _groupNames = {
    _ungroupedGroupId: 'MORE THAN GYM',
  };

  List<_MemberCardGroupMenuItem> _buildHeaderGroupFilterItems(
    List<Member> members,
  ) {
    final counts = _buildGroupCounts(members);
    return <_MemberCardGroupMenuItem>[
      _MemberCardGroupMenuItem(
        id: _ungroupedGroupId,
        label:
            '${_groupLabel(_ungroupedGroupId)} ${counts[_ungroupedGroupId] ?? 0}',
        icon: Icons.home_rounded,
      ),
      ..._groupIds.map(
        (groupId) => _MemberCardGroupMenuItem(
          id: groupId,
          label: '${_groupLabel(groupId)} ${counts[groupId] ?? 0}',
          icon: Icons.folder_open_rounded,
        ),
      ),
      _MemberCardGroupMenuItem(
        id: _systemDormantGroupId,
        label:
            '${_groupLabel(_systemDormantGroupId)} ${counts[_systemDormantGroupId] ?? 0}',
        icon: Icons.bedtime_rounded,
      ),
      _MemberCardGroupMenuItem(
        id: _systemExpiredGroupId,
        label:
            '${_groupLabel(_systemExpiredGroupId)} ${counts[_systemExpiredGroupId] ?? 0}',
        icon: Icons.warning_amber_rounded,
      ),
      const _MemberCardGroupMenuItem(
        id: _allGroupId,
        label: '전체',
        icon: Icons.dashboard_rounded,
      ),
    ];
  }

  List<PersonalTaxonomyFilterEntry> _buildPersonalTaxonomyFilterEntries(
    List<Member> members,
  ) {
    return buildPersonalTaxonomyFilterEntries(
      defaultGroupId: _ungroupedGroupId,
      defaultGroupLabel: _groupLabel(_ungroupedGroupId),
      customGroups: {
        for (final group in _personalGroups) group.id: group.name,
      },
      tags: {
        for (final tag in _personalTags) tag.id: tag.name,
      },
      visibleSystemGroups: const {},
      allId: _allGroupId,
      dormantCount: members.where(_isDormantMember).length,
      expiredCount: members.where(_isExpiredMember).length,
    );
  }

  final ValueNotifier<String?> _selectedGroupIdNotifier =
      ValueNotifier<String?>(null);

  final ValueNotifier<String?> _selectedPersonalTagIdNotifier =
      ValueNotifier<String?>(null);

  final ValueNotifier<PersonalMemberStatusFilter>
      _selectedPersonalStatusFilterNotifier =
      ValueNotifier<PersonalMemberStatusFilter>(PersonalMemberStatusFilter.all);

  final ValueNotifier<_DashboardCareFilter?> _dashboardCareFilterNotifier =
      ValueNotifier<_DashboardCareFilter?>(null);

  final ValueNotifier<Set<String>> _alertFilterMemberIdsNotifier =
      ValueNotifier<Set<String>>(<String>{});

  int _nextGroupNumber = 4;

  final ValueNotifier<Map<String, String>> _memberGroupMapNotifier =
      ValueNotifier<Map<String, String>>(<String, String>{});

  final ValueNotifier<int> _groupNamesVersionNotifier = ValueNotifier<int>(0);

  String _aifcTrainerNameSourceText = '';
  StreamSubscription<PersonalMemberPreferences>?
      _personalMemberPreferencesSubscription;
  StreamSubscription<List<PersonalMemberTaxonomyItem>>?
      _personalGroupSubscription;
  StreamSubscription<List<PersonalMemberTaxonomyItem>>?
      _personalTagSubscription;
  List<PersonalMemberTaxonomyItem> _personalGroups = const [];
  List<PersonalMemberTaxonomyItem> _personalTags = const [];
  AppTierAccessSnapshot? _personalTierAccess;

  @override
  void dispose() {
    _personalMemberPreferencesSubscription?.cancel();
    _personalGroupSubscription?.cancel();
    _personalTagSubscription?.cancel();
    _searchController.dispose();
    _searchKeywordNotifier.dispose();
    _scrollController.dispose();
    _highlightNotifier.dispose();
    _pinnedMemberIdsNotifier.dispose();
    _isListViewNotifier.dispose();
    _selectedGroupIdNotifier.dispose();
    _selectedPersonalTagIdNotifier.dispose();
    _selectedPersonalStatusFilterNotifier.dispose();
    _dashboardCareFilterNotifier.dispose();
    _alertFilterMemberIdsNotifier.dispose();
    _memberGroupMapNotifier.dispose();
    _groupNamesVersionNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _initialQuickFilter = widget.initialFilter;

    if (_initialQuickFilter == ClientListInitialFilter.lowRemaining) {
      _sortOption = SortOption.expirySoon;
      _sortAscending = true;
    }

    _loadAifcTrainerNameSource();
    _loadViewMode();
    _loadGroups();
    _loadPersonalTierAccess();
  }

  String _compactDuplicateDisplayName({
    required Member member,
    required Map<String, bool> duplicateNameMap,
    int maxLength = 4,
  }) {
    final rawName = (member.name ?? '').trim();
    if (rawName.isEmpty) return '회원';

    final isDuplicate = duplicateNameMap[rawName] ?? false;
    if (!isDuplicate) {
      return rawName.length <= maxLength
          ? rawName
          : rawName.substring(0, maxLength);
    }

    final phoneDigits = (member.phone ?? '').replaceAll(RegExp(r'\D'), '');
    final suffix = phoneDigits.isNotEmpty
        ? phoneDigits.substring(phoneDigits.length - 1)
        : '';

    final baseMaxLength =
        suffix.isEmpty ? maxLength : maxLength - suffix.length;
    final compactBase = rawName.length <= baseMaxLength
        ? rawName
        : rawName.substring(0, baseMaxLength);

    return '$compactBase$suffix';
  }

  Map<String, String> _defaultGroupNames() {
    return <String, String>{
      _ungroupedGroupId: 'MORE THAN GYM',
      _systemDormantGroupId: '휴면회원',
      _systemExpiredGroupId: '만료회원',
    };
  }

  String _groupDocId(String groupId) {
    if (groupId == _ungroupedGroupId) return 'default_group';
    if (groupId == _systemDormantGroupId) return 'system_dormant';
    if (groupId == _systemExpiredGroupId) return 'system_expired';

    return groupId;
  }

  String _appGroupIdFromDocId(String docId) {
    if (docId == 'default_group') return _ungroupedGroupId;
    if (docId == 'system_dormant') return _systemDormantGroupId;
    if (docId == 'system_expired') return _systemExpiredGroupId;

    return docId;
  }

  Future<Map<String, String>> _loadMemberGroupMapOnly() async {
    final memberSnap = await _membersQuery.get();

    final memberGroupMap = <String, String>{};

    for (final doc in memberSnap.docs) {
      final data = doc.data();

      if (data['isDeleted'] == true) {
        continue;
      }

      final groupId = (data['groupId'] ?? '').toString().trim();

      if (groupId.isNotEmpty &&
          groupId != _systemDormantGroupId &&
          groupId != _systemExpiredGroupId) {
        memberGroupMap[doc.id] = groupId;
      }
    }

    return memberGroupMap;
  }

  String _trainerNameSourceFromProfileData(Map<String, dynamic>? data) {
    if (data == null) return '';

    final source = (data['trainerNameSource'] ??
            data['aifcNameSource'] ??
            data['contractTrainerNameSource'] ??
            data['nameSource'] ??
            '')
        .toString()
        .trim();

    final nickname = (data['nickname'] ??
            data['aifcNickname'] ??
            data['trainerNickname'] ??
            '')
        .toString()
        .trim();

    final realName = (data['realName'] ??
            data['trainerRealName'] ??
            data['trainerName'] ??
            data['name'] ??
            '')
        .toString()
        .trim();

    final directName = (data['displayName'] ??
            data['customTrainerName'] ??
            data['aifcDisplayName'] ??
            '')
        .toString()
        .trim();

    if (source == 'nickname' && nickname.isNotEmpty) {
      return nickname;
    }

    if ((source == 'realName' || source == 'real') && realName.isNotEmpty) {
      return realName;
    }

    if ((source == 'custom' || source == 'direct') && directName.isNotEmpty) {
      return directName;
    }

    if (directName.isNotEmpty) return directName;
    if (nickname.isNotEmpty) return nickname;
    if (realName.isNotEmpty) return realName;

    return '';
  }

  Future<void> _loadAifcTrainerNameSource() async {
    try {
      final owner = widget.personalOwnerUid?.trim() ?? '';
      final doc = _isPersonalWorkspace
          ? await FirebaseFirestore.instance
              .collection('trainer_profiles')
              .doc(owner)
              .get()
          : await FirebaseFirestore.instance
              .collection('trainer_profile')
              .doc('me')
              .get();

      final nextName = _trainerNameSourceFromProfileData(doc.data());

      if (!mounted) return;

      setState(() {
        _aifcTrainerNameSourceText = nextName;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _aifcTrainerNameSourceText = '';
      });
    }
  }

  Future<void> _loadViewMode() async {
    if (!mounted) return;

    // 고객리스트는 리스트뷰를 기본 화면으로 고정합니다.
    _isListViewNotifier.value = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_memberListViewModeKey, 'list');
    } catch (_) {
      // 저장 실패해도 리스트뷰 고정은 유지
    }
  }

  Future<void> _saveViewMode(bool isListView) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _memberListViewModeKey,
        isListView ? 'list' : 'card',
      );
    } catch (_) {
      // 저장 실패해도 화면 동작은 유지
    }
  }

  void _setListViewMode(bool isListView) {
    if (_isListViewNotifier.value == isListView) return;

    _isListViewNotifier.value = isListView;
    _saveViewMode(isListView);
    _scrollListToTop();
  }

  void _toggleListViewMode() {
    _setListViewMode(!_isListViewNotifier.value);
  }

  Future<void> _loadGroups() async {
    final fallbackNames = _defaultGroupNames();

    if (_isPersonalWorkspace) {
      final owner = widget.personalOwnerUid!.trim();
      final service = PersonalMemberTaxonomyService(uid: owner);
      _personalMemberPreferencesSubscription ??=
          PersonalMemberPreferencesService(uid: owner).watch().listen(
        (preferences) {
          if (!mounted) return;
          final nextNames = _defaultGroupNames()
            ..[_ungroupedGroupId] = preferences.defaultGroupLabel;
          setState(() {
            _groupNames
              ..clear()
              ..addAll(nextNames)
              ..addEntries(
                _personalGroups.map((item) => MapEntry(item.id, item.name)),
              );
            _groupNamesVersionNotifier.value++;
          });
        },
      );
      _personalGroupSubscription ??=
          service.watch(PersonalMemberTaxonomyKind.group).listen((items) {
        if (!mounted) return;
        final sorted = _sortPersonalTaxonomyItems(items);
        setState(() {
          _personalGroups = sorted;
          _groupIds
            ..clear()
            ..addAll(sorted.map((item) => item.id));
          _groupNames.removeWhere(
            (key, value) =>
                key != _ungroupedGroupId && !_systemGroupIds.contains(key),
          );
          _groupNames.addEntries(
            sorted.map((item) => MapEntry(item.id, item.name)),
          );
          _groupNamesVersionNotifier.value++;
        });
        _loadLastSelectedGroupFilter();
      });
      _personalTagSubscription ??=
          service.watch(PersonalMemberTaxonomyKind.tag).listen((items) {
        if (!mounted) return;
        final sorted = _sortPersonalTaxonomyItems(items);
        setState(() {
          _personalTags = sorted;
        });
        final selected = _selectedPersonalTagIdNotifier.value;
        if (selected != null && !sorted.any((item) => item.id == selected)) {
          _selectedPersonalTagIdNotifier.value = null;
        }
      });
      if (!mounted) return;
      setState(() {
        _groupIds.clear();
        _groupNames
          ..clear()
          ..addAll(fallbackNames);
        _memberGroupMapNotifier.value = const <String, String>{};
        _groupNamesVersionNotifier.value++;
      });
      return;
    }

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

        final String appGroupId = _appGroupIdFromDocId(doc.id);

        final bool isSystem = data['isSystem'] == true;
        final String name = (data['name'] ?? '').toString().trim();

        loadedNames[appGroupId] = name.isEmpty ? _groupLabel(appGroupId) : name;

        if (!isSystem &&
            appGroupId != _ungroupedGroupId &&
            appGroupId != _systemDormantGroupId &&
            appGroupId != _systemExpiredGroupId) {
          loadedIds.add(appGroupId);
        }
      }

      loadedIds.sort((a, b) {
        int orderOf(String id) {
          final docId = _groupDocId(id);
          final doc = groupSnap.docs.where((e) => e.id == docId);
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

      await _loadLastSelectedGroupFilter();
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

  List<PersonalMemberTaxonomyItem> _sortPersonalTaxonomyItems(
    Iterable<PersonalMemberTaxonomyItem> items,
  ) {
    final sorted = items.toList();
    sorted.sort((a, b) {
      final createdAt = a.createdAt.compareTo(b.createdAt);
      return createdAt != 0 ? createdAt : a.id.compareTo(b.id);
    });
    return List.unmodifiable(sorted);
  }

  Future<void> _loadPersonalTierAccess() async {
    if (!_isPersonalWorkspace) return;
    try {
      final access = await AppTierAccessService.loadPersonalTrainerAccess(
        uid: widget.personalOwnerUid!.trim(),
      );
      if (!mounted) return;
      setState(() => _personalTierAccess = access);
    } catch (_) {}
  }

  bool get _isListView => _isListViewNotifier.value;

  List<String> get _pinnedMemberIds => _pinnedMemberIdsNotifier.value;

  String? get _selectedGroupId => _selectedGroupIdNotifier.value;

  String? get _selectedPersonalTagId => _selectedPersonalTagIdNotifier.value;

  PersonalMemberStatusFilter get _selectedPersonalStatusFilter =>
      _selectedPersonalStatusFilterNotifier.value;

  String? _memberCanonicalGroupId(Member member) {
    if (!_isPersonalWorkspace) return _memberGroupMap[member.id];
    return resolvePersonalMemberGroupId(
      personalGroupId: member.personalGroupId,
      availableGroupIds: _groupIds.toSet(),
    );
  }

  String _personalTagLabel(String tagId) {
    for (final item in _personalTags) {
      if (item.id == tagId) return item.name;
    }
    return '';
  }

  String get _aifcNicknameLabel {
    return aifcNicknameLabel(_aifcTrainerNameSourceText);
  }

  _DashboardCareFilter? get _selectedDashboardCareFilter =>
      _dashboardCareFilterNotifier.value;

  Map<String, String> get _memberGroupMap => _memberGroupMapNotifier.value;

  Set<String> get _alertFilterMemberIds => _alertFilterMemberIdsNotifier.value;

  bool get _isAlertFilterActive => _alertFilterMemberIds.isNotEmpty;

  void _setAlertFilterMemberIds(Iterable<String> memberIds) {
    final nextIds =
        memberIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();

    _alertFilterMemberIdsNotifier.value = nextIds;
  }

  void _clearAlertFilter() {
    if (_alertFilterMemberIdsNotifier.value.isEmpty) return;

    _alertFilterMemberIdsNotifier.value = <String>{};
  }

  void _setPinnedMemberIds(List<String> value) {
    _pinnedMemberIdsNotifier.value = List<String>.from(value);
  }

  void _setSelectedGroupId(String? value) {
    if (_selectedGroupIdNotifier.value == value) return;

    _selectedGroupIdNotifier.value = value;
    _saveLastSelectedGroupFilter(value);
    _scrollListToTop();
  }

  void _setSelectedPersonalStatusFilter(PersonalMemberStatusFilter value) {
    if (_selectedPersonalStatusFilterNotifier.value == value) return;
    _selectedPersonalStatusFilterNotifier.value = value;
    _saveLastSelectedStatusFilter(value);
    _scrollListToTop();
  }

  Future<void> _saveLastSelectedStatusFilter(
    PersonalMemberStatusFilter filter,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastSelectedStatusFilterKey, filter.name);
    } catch (_) {
      // 상태 필터 저장 실패는 화면 동작에 영향을 주지 않습니다.
    }
  }

  Future<void> _saveLastSelectedGroupFilter(String? groupId) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // null은 전체보기입니다.
      await prefs.setString(
        _lastSelectedGroupFilterKey,
        groupId ?? _allGroupId,
      );
    } catch (_) {
      // 필터 저장 실패는 화면 동작에 영향을 주지 않습니다.
    }
  }

  Future<void> _loadLastSelectedGroupFilter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_isPersonalWorkspace) {
        final savedStatus = prefs.getString(_lastSelectedStatusFilterKey);
        for (final filter in PersonalMemberStatusFilter.values) {
          if (filter.name == savedStatus) {
            _selectedPersonalStatusFilterNotifier.value = filter;
            break;
          }
        }
      }
      final saved = prefs.getString(_lastSelectedGroupFilterKey);

      if (!mounted || saved == null || saved.trim().isEmpty) return;

      // 홈 헤더 등에서 특정 초기 필터로 진입한 경우는 마지막 저장값보다 진입 필터가 우선입니다.
      if (_initialQuickFilter != ClientListInitialFilter.none) return;

      final normalized = saved == _allGroupId ? null : saved;

      if (_isPersonalWorkspace && normalized == _systemDormantGroupId) {
        _selectedPersonalStatusFilterNotifier.value =
            PersonalMemberStatusFilter.dormant;
        _selectedGroupIdNotifier.value = null;
        await _saveLastSelectedStatusFilter(
          PersonalMemberStatusFilter.dormant,
        );
        await _saveLastSelectedGroupFilter(null);
        return;
      }
      if (_isPersonalWorkspace && normalized == _systemExpiredGroupId) {
        _selectedPersonalStatusFilterNotifier.value =
            PersonalMemberStatusFilter.expired;
        _selectedGroupIdNotifier.value = null;
        await _saveLastSelectedStatusFilter(
          PersonalMemberStatusFilter.expired,
        );
        await _saveLastSelectedGroupFilter(null);
        return;
      }

      final isAllowed = normalized == null ||
          normalized == _ungroupedGroupId ||
          normalized == _systemDormantGroupId ||
          normalized == _systemExpiredGroupId ||
          _groupIds.contains(normalized);

      if (!isAllowed) return;

      _selectedGroupIdNotifier.value = normalized;
    } catch (_) {
      // 저장값 복원 실패는 무시합니다.
    }
  }

  void _toggleDashboardCareFilter(_DashboardCareFilter filter) {
    _clearAlertFilter();

    final current = _dashboardCareFilterNotifier.value;
    final next = current == filter ? null : filter;

    _dashboardCareFilterNotifier.value = next;

    if (next != null) {
      _setSelectedGroupId(null);

      setState(() {
        _selectedLessonDate = null;
        _membershipFilter = null;
        _initialQuickFilter = ClientListInitialFilter.none;
      });
    }

    _scrollListToTop();
  }

  void _clearDashboardCareFilter() {
    if (_dashboardCareFilterNotifier.value == null) return;
    _dashboardCareFilterNotifier.value = null;
  }

  void _setMemberGroupMap(Map<String, String> value) {
    _memberGroupMapNotifier.value = Map<String, String>.from(value);
  }

  void _setGroupNameLocally(String groupId, String newName) {
    setState(() {
      _groupNames[groupId] = newName;
    });

    _groupNamesVersionNotifier.value++;
  }

  void _closeHeaderOverlayIfNeeded() {
    _headerKey.currentState?.closeOverlayFromOutside();
  }

  void _scrollListToTop() {
    if (!_scrollController.hasClients) return;

    _scrollController.animateTo(
      _scrollController.position.minScrollExtent,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
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

  Future<void> _handleHeaderAlertTap(
    String memberId, {
    required Set<String> alertMemberIds,
  }) async {
    final cleanMemberId = memberId.trim();

    if (cleanMemberId.isEmpty) {
      _showSnack('해당 회원을 찾지 못했어요.');
      return;
    }

    final nextAlertIds = <String>{
      ...alertMemberIds,
      cleanMemberId,
    };

    _closeHeaderOverlayIfNeeded();

    // 알림 이동은 기존 검색/날짜/그룹/케어 필터에 막히면 안 되므로
    // AI FC 알림 대상만 모아보는 임시 필터로 전환합니다.
    _searchController.clear();
    _searchKeywordNotifier.value = '';

    _clearDashboardCareFilter();

    setState(() {
      _selectedLessonDate = null;
      _initialQuickFilter = ClientListInitialFilter.none;
    });

    // 기존 그룹 필터는 해제하되, 마지막 선택 필터 저장값은 건드리지 않습니다.
    _selectedGroupIdNotifier.value = null;

    _setAlertFilterMemberIds(nextAlertIds);

    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    if (!mounted) return;

    await scrollToMember(cleanMemberId);
  }

  Future<void> scrollToMember(String memberId) async {
    final int token = _issueHighlightToken();

    await _collapseHeaderIfExpanded();

    BuildContext? targetContext;

    // 필터 변경 직후에는 아직 리스트 아이템이 렌더링되지 않았을 수 있으니
    // 몇 프레임 동안 대상 context를 다시 찾습니다.
    for (int i = 0; i < 6; i++) {
      await Future<void>.delayed(
        i == 0
            ? const Duration(milliseconds: 30)
            : const Duration(milliseconds: 80),
      );

      if (!mounted || !_isLatestHighlightToken(token)) return;

      targetContext = _memberItemKeys[memberId]?.currentContext;

      if (targetContext != null) {
        break;
      }
    }

    if (targetContext == null) {
      _showSnack('회원은 찾았지만 현재 화면에 표시하지 못했어요.');
      return;
    }

    final renderObject = targetContext.findRenderObject();

    if (renderObject == null ||
        !renderObject.attached ||
        renderObject is! RenderBox) {
      return;
    }

    final scrollableState = Scrollable.maybeOf(targetContext);

    if (scrollableState == null) {
      return;
    }

    final viewportObject = scrollableState.context.findRenderObject();

    if (viewportObject == null || viewportObject is! RenderBox) {
      return;
    }

    final position = _scrollController.position;

    final RenderBox itemBox = renderObject;
    final RenderBox viewportBox = viewportObject;

    final Offset itemTopLeftInViewport = itemBox.localToGlobal(
      Offset.zero,
      ancestor: viewportBox,
    );

    final double itemTop = itemTopLeftInViewport.dy;
    final double itemHeight =
        itemBox.size.height > 0 ? itemBox.size.height : 114;
    final double itemCenter = itemTop + (itemHeight / 2);

    // 검색/필터 고정 헤더가 위쪽을 가리므로
    // 실제로 보이는 영역의 중앙에 대상 회원이 오도록 맞춥니다.
    const double pinnedHeaderHeight = 136;
    const double topSafeSpacing = 18;
    const double bottomSafeSpacing = 28;

    final double visibleTop = pinnedHeaderHeight + topSafeSpacing;
    final double visibleBottom = viewportBox.size.height - bottomSafeSpacing;
    final double visibleCenter =
        visibleTop + ((visibleBottom - visibleTop) / 2);

    final double delta = itemCenter - visibleCenter;

    final double targetOffset = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    await _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );

    if (!mounted || !_isLatestHighlightToken(token)) return;

    await Future<void>.delayed(const Duration(milliseconds: 80));

    if (!mounted || !_isLatestHighlightToken(token)) return;

    _highlightMember(memberId);

    await Future<void>.delayed(const Duration(milliseconds: 1000));

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
          backgroundColor: context.mtfThemeTokens.memberListBackground,
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _membersQuery.snapshots(),
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

              final membershipMetaById = <String, _MemberMembershipMeta>{
                for (final doc in visibleDocs)
                  doc.id: _MemberMembershipMeta.fromData(doc.data()),
              };

              return Center(
                child: SizedBox(
                  width: width,
                  child: _buildBody(
                    allMembers,
                    membershipMetaById,
                  ),
                ),
              );
            },
          ),
        );

        return scaffold;
      },
    );
  }

  Widget _buildBody(
    List<Member> allMembers,
    Map<String, _MemberMembershipMeta> membershipMetaById,
  ) {
    final headerData = DashboardHeaderData.fromMembers(
      allMembers,
      messageSeed: _headerMessageSeed,
    );

    return ValueListenableBuilder<String>(
      valueListenable: _searchKeywordNotifier,
      builder: (context, searchKeyword, _) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (event) {
                  final isInsideHeader = _headerKey.currentState
                          ?.containsGlobalPosition(event.position) ??
                      false;

                  if (!isInsideHeader) {
                    _closeHeaderOverlayIfNeeded();
                  }
                },
                child: CustomScrollView(
                  key: const PageStorageKey('client_card_scroll'),
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: DashboardBlueHeader(
                          key: _headerKey,
                          data: headerData,
                          trainerLabel: _aifcNicknameLabel,
                          isPersonalWorkspace: _isPersonalWorkspace,
                          isListViewListenable: _isListViewNotifier,
                          selectedCareFilterListenable:
                              _dashboardCareFilterNotifier,
                          onCareFilterSelected: _toggleDashboardCareFilter,
                          onBackTap: () async {
                            if (!mounted) return;
                            Navigator.of(context).maybePop();
                          },
                          onAddCustomer: _openCreate,
                          onToggleListView: _toggleListViewMode,
                          onCreateGroup: _handleHeaderCreateGroup,
                          onManageTags: () => _openPersonalTaxonomyManagement(
                            PersonalMemberTaxonomyKind.tag,
                          ),
                          onResetFilters: _resetQuickFilters,
                          onRestoreDeletedMembers:
                              _openDeletedMembersRestoreSheet,
                          onAlertTap: (memberId) async {
                            await _handleHeaderAlertTap(
                              memberId,
                              alertMemberIds: headerData.alerts
                                  .map((alert) => alert.memberId)
                                  .toSet(),
                            );
                          },
                        ),
                      ),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _PinnedSearchHeaderDelegate(
                        minExtentValue: _isPersonalWorkspace ? 174 : 136,
                        maxExtentValue: _isPersonalWorkspace ? 174 : 136,
                        child: RepaintBoundary(
                          child: Container(
                            color: context.mtfThemeTokens.memberListBackground,
                            padding: const EdgeInsets.fromLTRB(
                              kClientPageHorizontalPadding,
                              10,
                              kClientPageHorizontalPadding,
                              8,
                            ),
                            child: ListenableBuilder(
                              listenable: Listenable.merge([
                                _selectedGroupIdNotifier,
                                _selectedPersonalTagIdNotifier,
                                _selectedPersonalStatusFilterNotifier,
                                _groupNamesVersionNotifier,
                              ]),
                              builder: (context, _) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _SearchAndFilterCard(
                                      controller: _searchController,
                                      selectedLessonDate: _selectedLessonDate,
                                      membershipFilter: _membershipFilter,
                                      sortOption: _sortOption,
                                      sortAscending: _sortAscending,
                                      onSearchChanged: (value) {
                                        _searchKeywordNotifier.value = value;
                                        _scrollListToTop();
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
                                              _sortOption =
                                                  SortOption.expirySoon;
                                            });
                                            break;

                                          case _SearchMenuAction.sortGroup:
                                            setState(() {
                                              _sortOption = SortOption.group;
                                            });
                                            break;

                                          case _SearchMenuAction
                                                .sortRecentLesson:
                                            setState(() {
                                              _sortOption =
                                                  SortOption.recentLesson;
                                            });
                                            break;

                                          case _SearchMenuAction
                                                .sortRecentRegistration:
                                            setState(() {
                                              _sortOption =
                                                  SortOption.recentRegistration;
                                            });
                                            break;

                                          case _SearchMenuAction.pickLessonDate:
                                            await _pickLessonDate();
                                            break;

                                          case _SearchMenuAction
                                                .clearLessonDate:
                                            setState(() {
                                              _selectedLessonDate = null;
                                            });
                                            break;
                                          case _SearchMenuAction
                                                .membershipNeedsCheck:
                                            setState(() {
                                              _membershipFilter =
                                                  _MembershipListFilter
                                                      .needsCheck;
                                            });
                                            _scrollListToTop();
                                            break;

                                          case _SearchMenuAction
                                                .clearMembershipFilter:
                                            setState(() {
                                              _membershipFilter = null;
                                            });
                                            _scrollListToTop();
                                            break;
                                        }
                                      },
                                      onToggleSortDirection: () {
                                        setState(() {
                                          _sortAscending = !_sortAscending;
                                        });
                                      },
                                    ),
                                    const SizedBox(height: 6),
                                    if (_isPersonalWorkspace)
                                      PersonalTaxonomyFilterStrip(
                                        entries:
                                            _buildPersonalTaxonomyFilterEntries(
                                          allMembers,
                                        ),
                                        selectedGroupId: _selectedGroupId,
                                        selectedTagId: _selectedPersonalTagId,
                                        selectedStatus:
                                            _selectedPersonalStatusFilter,
                                        onManage:
                                            _showPersonalTaxonomyManagementMenu,
                                        onSelected:
                                            _handlePersonalTaxonomyFilterEntry,
                                      )
                                    else
                                      _GroupFilterChipRow(
                                        items: _buildHeaderGroupFilterItems(
                                          allMembers,
                                        ),
                                        selectedGroupId: _selectedGroupId,
                                        accentColorForGroupId:
                                            _memberDisplayGroupAccentColorForGroupId,
                                        textColorForGroupId:
                                            _memberDisplayGroupTextColorForGroupId,
                                        onSelected: _handleGroupFilter,
                                        onSettingsTap:
                                            _showGroupManagementSheet,
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: ListenableBuilder(
                        listenable: Listenable.merge([
                          _pinnedMemberIdsNotifier,
                          _memberGroupMapNotifier,
                          _groupNamesVersionNotifier,
                          _selectedGroupIdNotifier,
                          _selectedPersonalTagIdNotifier,
                          _selectedPersonalStatusFilterNotifier,
                          _dashboardCareFilterNotifier,
                          _alertFilterMemberIdsNotifier,
                          _isListViewNotifier,
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
                              membershipMetaById: membershipMetaById,
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
        );
      },
    );
  }

  Map<String, bool> _buildDuplicateNameMap(List<Member> members) {
    final nameCount = <String, int>{};

    for (final member in members) {
      final name = (member.name ?? '').trim();
      if (name.isEmpty) continue;

      nameCount[name] = (nameCount[name] ?? 0) + 1;
    }

    return nameCount.map(
      (name, count) => MapEntry(name, count > 1),
    );
  }

  String _phoneSuffixForDuplicateDisplay(String? phone) {
    final phoneDigits = (phone ?? '').replaceAll(RegExp(r'\D'), '');

    if (phoneDigits.length >= 4) {
      return phoneDigits.substring(phoneDigits.length - 4);
    }

    return phoneDigits;
  }

  String? _duplicateDisplayNameOrNull({
    required Member member,
    required Map<String, bool> duplicateNameMap,
  }) {
    final rawName = (member.name ?? '').trim();
    if (rawName.isEmpty) return null;

    final isDuplicate = duplicateNameMap[rawName] ?? false;
    if (!isDuplicate) return null;

    final phoneSuffix = _phoneSuffixForDuplicateDisplay(member.phone);
    if (phoneSuffix.isEmpty) return null;

    return '$rawName · $phoneSuffix';
  }

  String _activeFilterTitle() {
    if (_isAlertFilterActive) {
      return 'AI FC 알림';
    }

    final selectedCareFilter = _selectedDashboardCareFilter;

    if (selectedCareFilter != null) {
      return _dashboardCareFilterLabel(selectedCareFilter);
    }

    if (_membershipFilter != null) {
      return _membershipListFilterLabel(_membershipFilter!);
    }

    if (_selectedPersonalStatusFilter != PersonalMemberStatusFilter.all) {
      return personalMemberStatusFilterLabel(_selectedPersonalStatusFilter);
    }

    if (_selectedPersonalTagId != null) {
      return _personalTagLabel(_selectedPersonalTagId!);
    }

    final selectedGroupId = _selectedGroupId;

    if (selectedGroupId == null) {
      return '전체보기';
    }

    return _groupLabel(selectedGroupId);
  }

  Widget _buildMemberListContent({
    required List<Member> allMembers,
    required String searchKeyword,
    required Map<String, _MemberMembershipMeta> membershipMetaById,
  }) {
    final filteredMembers = _buildFilteredMembers(
      allMembers,
      searchKeyword,
      groupFilterId: _selectedGroupId,
      tagFilterId: _selectedPersonalTagId,
      statusFilter: _selectedPersonalStatusFilter,
      dashboardCareFilter: _selectedDashboardCareFilter,
      alertFilterMemberIds: _alertFilterMemberIds,
      membershipMetaById: membershipMetaById,
    );

    final duplicateNameMap = _buildDuplicateNameMap(allMembers);

    final selectedCareFilter = _selectedDashboardCareFilter;

    final Widget selectedDivider = _buildGroupSectionDivider(
      '${_activeFilterTitle()} · 총 ${filteredMembers.length}명',
    );

    if (filteredMembers.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          selectedDivider,
          Padding(
            padding: const EdgeInsets.only(top: 28),
            child: Center(
              child: Text(
                '${_activeFilterTitle()}에 표시할 회원이 없어요',
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      );
    }

    final Widget content = _buildListViewContent(
      members: filteredMembers,
      duplicateNameMap: duplicateNameMap,
      membershipMetaById: membershipMetaById,
      showGroupSectionDividers: selectedCareFilter == null &&
          _selectedGroupId == null &&
          !_isAlertFilterActive,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        selectedDivider,
        content,
      ],
    );
  }

  Widget _buildCardViewContent({
    required List<Member> members,
    required Map<String, bool> duplicateNameMap,
  }) {
    return Column(
      children: members.map((member) {
        final itemKey = _memberItemKeys.putIfAbsent(
          member.id,
          () => GlobalKey(),
        );

        final displayName = _duplicateDisplayNameOrNull(
          member: member,
          duplicateNameMap: duplicateNameMap,
        );

        return KeyedSubtree(
          key: itemKey,
          child: MemberSimpleCard(
            key: ValueKey('member_card_${member.id}'),
            member: member,
            displayName: displayName,
            trainerNameSourceText: _aifcTrainerNameSourceText,
            groupLabel: _memberCanonicalGroupId(member) == null
                ? null
                : _groupLabel(_memberCanonicalGroupId(member)!),
            displayGroupLabel: _memberDisplayGroupLabel(member),
            displayGroupAccentColor: _memberDisplayGroupAccentColor(member),
            displayGroupTextColor: _memberDisplayGroupTextColor(member),
            groupMenuItems: _buildMemberCardGroupMenuItems(),
            onQuickGroupChanged: (groupId) async {
              await _handleMemberQuickGroupChange(member, groupId);
            },
            onContractTap: () {},
            onEditTap: () => _openEdit(member),
            onLogTap: () => _openLog(member),
            onPinTap: () => _togglePin(member),
            isPinned: _pinnedMemberIds.contains(member.id),
            onSetExpired: () => _updateMemberStatus(member, '만료'),
            onSetDormant: () => _updateMemberStatus(member, '휴면'),
            onSetActive: () => _updateMemberStatus(member, '활성'),
            onAnyInteraction: _closeHeaderOverlayIfNeeded,
            highlightListenable: _highlightNotifier,
          ),
        );
      }).toList(),
    );
  }

  int _groupSortRank(String label, {required bool isDefaultGroup}) {
    if (isDefaultGroup) return 0;

    final value = label.trim();
    if (value.isEmpty) return 4;

    final first = value.characters.first;

    if (RegExp(r'^[A-Za-z]').hasMatch(first)) return 1;
    if (RegExp(r'^[0-9]').hasMatch(first)) return 2;
    if (RegExp(r'^[가-힣]').hasMatch(first)) return 3;

    return 4;
  }

  int _compareGroupLabelForSection(Member a, Member b) {
    final aGroupId = _memberGroupMap[a.id];
    final bGroupId = _memberGroupMap[b.id];

    final aIsDefault = aGroupId == null;
    final bIsDefault = bGroupId == null;

    final aLabel = _memberDisplayGroupLabel(a).trim();
    final bLabel = _memberDisplayGroupLabel(b).trim();

    final rankCompare = _groupSortRank(
      aLabel,
      isDefaultGroup: aIsDefault,
    ).compareTo(
      _groupSortRank(
        bLabel,
        isDefaultGroup: bIsDefault,
      ),
    );

    if (rankCompare != 0) return rankCompare;

    final groupCompare = aLabel.toLowerCase().compareTo(bLabel.toLowerCase());
    if (groupCompare != 0) return groupCompare;

    return _compareNameOrder(a.name ?? '', b.name ?? '');
  }

  Widget _buildGroupSectionDivider(String label) {
    final displayLabel = label.trim().isEmpty ? 'MORE THAN GYM' : label.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 10),
      child: Row(
        children: [
          const Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE5E7EB),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w900,
                color: Color(0xFF6B7280),
                letterSpacing: -0.2,
              ),
            ),
          ),
          const Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE5E7EB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListViewContent({
    required List<Member> members,
    required Map<String, bool> duplicateNameMap,
    required Map<String, _MemberMembershipMeta> membershipMetaById,
    bool showGroupSectionDividers = true,
  }) {
    final displayMembers = [...members];

    if (_sortOption == SortOption.group) {
      displayMembers.sort(_compareGroupLabelForSection);
    }

    final children = <Widget>[];
    String? lastGroupLabel;

    for (final member in displayMembers) {
      final currentGroupLabel = _memberDisplayGroupLabel(member).trim().isEmpty
          ? 'MORE THAN GYM'
          : _memberDisplayGroupLabel(member).trim();

      if (showGroupSectionDividers &&
          _sortOption == SortOption.group &&
          currentGroupLabel != lastGroupLabel) {
        children.add(_buildGroupSectionDivider(currentGroupLabel));
        lastGroupLabel = currentGroupLabel;
      }

      final itemKey = _memberItemKeys.putIfAbsent(
        member.id,
        () => GlobalKey(),
      );

      final displayName = _duplicateDisplayNameOrNull(
        member: member,
        duplicateNameMap: duplicateNameMap,
      );

      children.add(
        KeyedSubtree(
          key: itemKey,
          child: MemberListRow(
            key: ValueKey('member_list_row_${member.id}'),
            member: member,
            membershipMeta: membershipMetaById[member.id],
            displayName: displayName,
            displayGroupLabel: _memberDisplayGroupLabel(member),
            displayGroupAccentColor: _memberDisplayGroupAccentColor(member),
            displayGroupTextColor: _memberDisplayGroupTextColor(member),
            groupMenuItems: _buildMemberCardGroupMenuItems(),
            isPinned: _pinnedMemberIds.contains(member.id),
            onPinTap: () => _togglePin(member),
            onEditTap: () => _openEdit(member),
            onLogTap: () => _openLog(member),
            onQuickGroupChanged: (groupId) async {
              await _handleMemberQuickGroupChange(member, groupId);
            },
            onAnyInteraction: _closeHeaderOverlayIfNeeded,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  bool _isDashboardExpiryMember(Member member) {
    final isExpired = _isExpiredMember(member);
    final isDormant = _isDormantMember(member);
    final isActive = !isExpired && !isDormant;

    if (!isActive) return false;

    final remaining = member.remainingSessions;
    final total = member.totalSessions <= 0 ? 0 : member.totalSessions;
    final hasLessonRegistration = total > 0;

    final bool isSessionExpirySoon =
        hasLessonRegistration && remaining >= 0 && remaining < 5;

    final now = DateTime.now();
    final membershipDaysLeft =
        member.expireAt == null ? null : _daysBetween(now, member.expireAt!);

    final bool isMembershipExpirySoon = membershipDaysLeft != null &&
        membershipDaysLeft >= 0 &&
        membershipDaysLeft <= 10;

    final bool isMembershipExpired =
        membershipDaysLeft != null && membershipDaysLeft < 0;

    return isSessionExpirySoon || isMembershipExpirySoon || isMembershipExpired;
  }

  bool _isDashboardSpecialMember(Member member) {
    final isExpired = _isExpiredMember(member);
    final isDormant = _isDormantMember(member);
    final isActive = !isExpired && !isDormant;

    if (!isActive) return false;

    final now = DateTime.now();

    final total = member.totalSessions <= 0 ? 0 : member.totalSessions;
    final usedSessions =
        total <= 0 ? 0 : (total - member.remainingSessions).clamp(0, total);

    final baseDate = member.recentReg ?? member.firstDate;
    final firstLessonDays =
        baseDate == null ? 9999 : _daysBetween(baseDate, now);

    final bool isHundredDay = firstLessonDays >= 93 && firstLessonDays <= 103;

    final bool isHundredLesson = usedSessions >= 93 && usedSessions <= 100;

    final int? birthdayDaysLeft = _daysUntilNextMonthDay(member.birthDate, now);

    final bool isBirthdaySoon = birthdayDaysLeft != null &&
        birthdayDaysLeft >= 0 &&
        birthdayDaysLeft <= 7;

    final int? anniversaryDaysLeft =
        _daysUntilNextMonthDay(member.anniversaryDate, now);

    final bool isAnniversarySoon = anniversaryDaysLeft != null &&
        anniversaryDaysLeft >= 0 &&
        anniversaryDaysLeft <= 14;

    final int? nextMoreDayDaysLeft = member.nextMoreDayAt == null
        ? null
        : _daysBetween(now, member.nextMoreDayAt!);

    final bool isNextMoreDaySoon = nextMoreDayDaysLeft != null &&
        nextMoreDayDaysLeft >= -7 &&
        nextMoreDayDaysLeft <= 14;

    return isHundredDay ||
        isHundredLesson ||
        isBirthdaySoon ||
        isAnniversarySoon ||
        isNextMoreDaySoon;
  }

  bool _isDashboardAttentionMember(Member member) {
    final isExpired = _isExpiredMember(member);
    final isDormant = _isDormantMember(member);
    final isActive = !isExpired && !isDormant;
    final now = DateTime.now();

    // MORE 체크: 휴면 회원은 확인 대상
    if (isDormant) return true;

    // 만료/재등록/회원권 관련은 '만료 임박'에서만 관리
    if (!isActive) return false;

    final baseDate = member.recentReg ?? member.firstDate;
    final firstLessonDays =
        baseDate == null ? 9999 : _daysBetween(baseDate, DateTime.now());

    final bool isNewMember = firstLessonDays >= 0 && firstLessonDays < 7;

    final bool isFemaleConditionCheck =
        _isFemaleConditionCheckWindow(member, now);

    return isNewMember || isFemaleConditionCheck;
  }

  bool _matchesDashboardCareFilter(
    Member member,
    _DashboardCareFilter? filter,
  ) {
    return switch (filter) {
      null => true,
      _DashboardCareFilter.expiry => _isDashboardExpiryMember(member),
      _DashboardCareFilter.special => _isDashboardSpecialMember(member),
      _DashboardCareFilter.attention => _isDashboardAttentionMember(member),
    };
  }

  String _dashboardCareFilterLabel(_DashboardCareFilter filter) {
    return switch (filter) {
      _DashboardCareFilter.expiry => '만료 임박',
      _DashboardCareFilter.special => 'MORE 데이',
      _DashboardCareFilter.attention => 'MORE 체크',
    };
  }

  bool _matchesMembershipListFilter(
    Member member,
    _MemberMembershipMeta? meta,
    _MembershipListFilter? filter,
  ) {
    if (filter == null) return true;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final expireAt = member.expireAt ?? meta?.endAt;
    final expireDate = expireAt == null
        ? null
        : DateTime(expireAt.year, expireAt.month, expireAt.day);

    int? daysLeft;
    if (expireDate != null) {
      daysLeft = expireDate.difference(today).inDays;
    }

    switch (filter) {
      case _MembershipListFilter.needsCheck:
        final bool lowSession =
            member.remainingSessions > 0 && member.remainingSessions <= 3;

        final bool membershipSoon =
            daysLeft != null && daysLeft >= 0 && daysLeft <= 30;

        final bool membershipExpired = daysLeft != null && daysLeft < 0;

        final bool membershipPaused =
            meta?.isPaused == true || member.memberStatus == '휴면';

        final bool contractUnsigned = meta?.needsContractSignature == true;

        return lowSession ||
            membershipSoon ||
            membershipExpired ||
            membershipPaused ||
            contractUnsigned;
    }
  }

  List<Member> _buildFilteredMembers(
    List<Member> members,
    String rawQuery, {
    String? groupFilterId,
    String? tagFilterId,
    PersonalMemberStatusFilter statusFilter = PersonalMemberStatusFilter.all,
    _DashboardCareFilter? dashboardCareFilter,
    Set<String> alertFilterMemberIds = const <String>{},
    required Map<String, _MemberMembershipMeta> membershipMetaById,
  }) {
    final query = search_utils.normalizeSearchText(rawQuery);

    final filtered = members.where((member) {
      final isAlertFilterActive = alertFilterMemberIds.isNotEmpty;
      final matchesAlertFilter =
          !isAlertFilterActive || alertFilterMemberIds.contains(member.id);

      final memberGroupId = _memberCanonicalGroupId(member);
      final groupLabel = _memberDisplayGroupLabel(member);
      final tagLabels = member.personalTagIds.map(_personalTagLabel).toList();

      final matchesSearch = search_utils.matchesSmartMemberSearch(
        rawQuery: rawQuery,
        targets: [
          member.name ?? '',
          member.phone ?? '',
          member.trainer ?? '',
          member.grade ?? '',
          groupLabel,
          ...tagLabels,
        ],
      );

      final matchesDate = _selectedLessonDate == null
          ? true
          : (member.lastLogAt != null &&
              _isSameDate(member.lastLogAt!, _selectedLessonDate!));

      final matchesClassification = isAlertFilterActive
          ? true
          : _isPersonalWorkspace
              ? matchesPersonalMemberListClassification(
                  memberStatus: member.memberStatus,
                  memberGroupId: memberGroupId,
                  memberTagIds: member.personalTagIds,
                  statusFilter: statusFilter,
                  selectedGroupId: groupFilterId,
                  defaultGroupId: _ungroupedGroupId,
                  selectedTagId: tagFilterId,
                )
              : switch (groupFilterId) {
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

      final matchesDashboardCare = isAlertFilterActive
          ? true
          : _matchesDashboardCareFilter(member, dashboardCareFilter);

      final matchesMembershipFilter = _matchesMembershipListFilter(
        member,
        membershipMetaById[member.id],
        _membershipFilter,
      );
      if (_initialQuickFilter == ClientListInitialFilter.lowRemaining &&
          !_isLowRemainingMember(member)) {
        return false;
      }

      if (_initialQuickFilter == ClientListInitialFilter.careNeeded &&
          !_isCareNeededMember(member)) {
        return false;
      }

      return matchesAlertFilter &&
          matchesSearch &&
          matchesDate &&
          matchesClassification &&
          matchesDashboardCare &&
          matchesMembershipFilter;
    }).toList();

    filtered.sort(_memberComparator(_sortOption));

    final sortedMembers =
        _sortAscending ? filtered : filtered.reversed.toList();

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

    AifcInteraction.toast(
      context: context,
      message: message,
      bottomOffset: 110,
    );
  }

  Future<bool> _showAifcConfirm({
    required String title,
    required String message,
    String cancelText = '취소',
    String confirmText = '확인',
    String? userCancelText,
    String? userConfirmText,
    String cancelReplyText = '좋아요. 다음에 진행할게요.',
    String confirmReplyText = '확인했어요. 이어서 진행할게요.',
    bool danger = false,
  }) {
    return AifcConfirmChatSheet.show(
      context: context,
      nickname: _aifcTrainerNameSourceText.trim().isEmpty
          ? '강사'
          : _aifcTrainerNameSourceText,
      title: title,
      message: message,
      cancelText: cancelText,
      confirmText: confirmText,
      userCancelText: userCancelText,
      userConfirmText: userConfirmText,
      cancelReplyText: cancelReplyText,
      confirmReplyText: confirmReplyText,
      danger: danger,
    );
  }

  Future<void> _commitBatchOperations(
    List<void Function(WriteBatch batch)> operations,
  ) async {
    const int chunkSize = 450;

    for (int i = 0; i < operations.length; i += chunkSize) {
      final batch = FirebaseFirestore.instance.batch();
      final chunk = operations.skip(i).take(chunkSize);

      for (final operation in chunk) {
        operation(batch);
      }

      await batch.commit();
    }
  }

  int _maxGroupNameLength(String groupId) {
    return 30;
  }

  Future<void> _showRenameGroupDialog(String groupId) async {
    final int maxLength = _maxGroupNameLength(groupId);
    final currentName = _groupNames[groupId] ?? _groupLabel(groupId);

    final result = await AifcInteraction.ask(
      context: context,
      question: groupId == _ungroupedGroupId
          ? '기본 그룹이름을 어떻게 변경해드릴까요?'
          : _systemGroupIds.contains(groupId)
              ? '고정 그룹의 이름을 어떻게 변경하고 싶으세요?'
              : '이 그룹은 어떤 이름으로 변경하고 싶으세요?',
      inputLabel: '최대 $maxLength자',
      initialValue: currentName,
      skipLabel: '나중에',
      onSkip: () {},
      onSave: (value) async {
        final newName = value.trim();

        final validationError = groupId == _ungroupedGroupId
            ? validatePersonalDefaultGroupLabel(newName)
            : (newName.isEmpty
                ? 'empty'
                : newName.length > maxLength
                    ? 'too_long'
                    : null);
        if (validationError != null) {
          throw Exception(validationError);
        }

        if (_isPersonalWorkspace) {
          await PersonalMemberPreferencesService(
            uid: widget.personalOwnerUid!.trim(),
          ).saveDefaultGroupLabel(newName);
          return '$newName 그룹명으로 적어둘게요.';
        }

        final bool isSystemGroup = _systemGroupIds.contains(groupId);

        await FirebaseFirestore.instance
            .collection('member_groups')
            .doc(_groupDocId(groupId))
            .set({
          'name': newName,
          'appGroupId': groupId,
          'isArchived': false,
          'isSystem': groupId == _ungroupedGroupId ? true : isSystemGroup,
          'systemType': groupId == _ungroupedGroupId
              ? 'default'
              : isSystemGroup
                  ? 'system'
                  : 'custom',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return '$newName 그룹명으로 적어둘게요.';
      },
    );

    if (!mounted || result == null) return;

    final newName = result.trim();
    if (newName.isEmpty) return;

    _setGroupNameLocally(groupId, newName);
    _setMemberGroupMap(_memberGroupMap);

    _showSnack('그룹 이름이 변경되었어요.');
  }

  int _nextGroupOrder() {
    return _groupIds.length + 1;
  }

  Future<void> _showCreateGroupDialog() async {
    if (_isPersonalWorkspace) {
      await _openPersonalTaxonomyManagement(
        PersonalMemberTaxonomyKind.group,
      );
      return;
    }

    if (_groupIds.length >= 5) {
      _showSnack('그룹은 최대 5개까지만 만들 수 있어요.');
      return;
    }

    final int nextNumber = _nextGroupNumber;
    final String newGroupId = 'group_$nextNumber';

    final result = await AifcInteraction.ask(
      context: context,
      question: '$_aifcNicknameLabel, 새 그룹을 만들어볼까요?\n'
          '장소, 반, 소속 이름처럼 정확하게 알려주세요.',
      inputLabel: '예: 오전반 / 오후반 / 모어댄피트니스',
      skipLabel: '나중에',
      onSkip: () {},
      onSave: (value) async {
        final newName = value.trim();

        if (newName.isEmpty) {
          throw Exception('empty');
        }

        if (newName.length > 30) {
          throw Exception('too_long');
        }

        await FirebaseFirestore.instance
            .collection('member_groups')
            .doc(newGroupId)
            .set({
          'name': newName,
          'order': _nextGroupOrder(),
          'isArchived': false,
          'isSystem': false,
          'systemType': 'custom',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return '$newName 그룹을 만들어 둘게요.';
      },
    );

    if (!mounted || result == null) return;

    final newName = result.trim();
    if (newName.isEmpty) return;

    setState(() {
      _groupIds.add(newGroupId);
      _groupNames[newGroupId] = newName;
      _nextGroupNumber++;
    });

    _showSnack('$newName 그룹을 만들었어요.');
  }

  Future<void> _saveGroupOrder(List<String> orderedGroupIds) async {
    final normalizedIds = orderedGroupIds
        .where((groupId) => _groupIds.contains(groupId))
        .toList();

    final missingIds =
        _groupIds.where((groupId) => !normalizedIds.contains(groupId)).toList();

    final nextGroupIds = <String>[
      ...normalizedIds,
      ...missingIds,
    ];

    if (nextGroupIds.length != _groupIds.length) {
      _showSnack('그룹 순서를 저장하지 못 했어요.');
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      final groupCollection =
          FirebaseFirestore.instance.collection('member_groups');

      for (int i = 0; i < nextGroupIds.length; i++) {
        final groupId = nextGroupIds[i];

        batch.set(
          groupCollection.doc(_groupDocId(groupId)),
          {
            'order': i + 1,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      if (!mounted) return;

      setState(() {
        _groupIds
          ..clear()
          ..addAll(nextGroupIds);
      });

      _groupNamesVersionNotifier.value++;
      _showSnack('그룹 순서를 변경했어요.');
    } catch (_) {
      if (!mounted) return;
      _showSnack('그룹 순서 변경에 실패했어요.');
    }
  }

  Future<void> _showDeleteGroupDialog(String groupId) async {
    if (_systemGroupIds.contains(groupId) || groupId == _ungroupedGroupId) {
      return;
    }

    final groupName = _groupLabel(groupId);

    final result = await _showAifcConfirm(
      title: '그룹을 삭제할까요?',
      message: '$groupName 그룹을 삭제하면 해당 회원들은 기본 그룹으로 이동해요.\n'
          '회원 정보는 삭제되지 않고 그룹 분류만 해제됩니다.',
      cancelText: '취소',
      confirmText: '삭제',
      userCancelText: '취소할게요',
      userConfirmText: '삭제할게요',
      cancelReplyText: '좋아요. 그룹은 그대로 둘게요.',
      confirmReplyText: '확인했어요. 그룹을 지웠어요.',
      danger: true,
    );

    if (!result) return;

    await _deleteGroup(groupId);
  }

  Future<void> _deleteGroup(String groupId) async {
    if (_systemGroupIds.contains(groupId) || groupId == _ungroupedGroupId) {
      return;
    }

    final memberRefs = await FirebaseFirestore.instance
        .collection('members')
        .where('groupId', isEqualTo: groupId)
        .get();

    final operations = <void Function(WriteBatch batch)>[];

    for (final doc in memberRefs.docs) {
      operations.add((batch) {
        batch.set(
            doc.reference,
            {
              'groupId': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
      });
    }

    operations.add((batch) {
      batch.delete(
        FirebaseFirestore.instance
            .collection('member_groups')
            .doc(_groupDocId(groupId)),
      );
    });

    await _commitBatchOperations(operations);

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

    _showSnack('그룹을 삭제했어요. 해당 회원들은 기본 그룹으로 이동했어요.');
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
        if (!_isPersonalWorkspace) continue;
      }

      if (_isDormantMember(member)) {
        counts[_systemDormantGroupId] = counts[_systemDormantGroupId]! + 1;
        if (!_isPersonalWorkspace) continue;
      }

      final groupId = _memberCanonicalGroupId(member);
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

  String _groupLabel(String groupId) {
    if (_groupNames.containsKey(groupId)) {
      return _groupNames[groupId]!;
    }

    if (groupId == _ungroupedGroupId) return 'MORE THAN GYM';
    if (groupId == _systemDormantGroupId) return '휴면회원';
    if (groupId == _systemExpiredGroupId) return '만료회원';

    return groupId;
  }

  String _memberDisplayGroupLabel(Member member) {
    if (!_isPersonalWorkspace && _isExpiredMember(member)) {
      return _groupLabel(_systemExpiredGroupId);
    }
    if (!_isPersonalWorkspace && _isDormantMember(member)) {
      return _groupLabel(_systemDormantGroupId);
    }
    final groupId = _memberCanonicalGroupId(member);

    if (groupId != null && groupId.trim().isNotEmpty) {
      return _groupLabel(groupId);
    }

    return _groupLabel(_ungroupedGroupId);
  }

  Color _memberDisplayGroupAccentColor(Member member) {
    if (!_isPersonalWorkspace && _isExpiredMember(member)) {
      return const Color(0xFF6B7280);
    }
    if (!_isPersonalWorkspace && _isDormantMember(member)) {
      return const Color(0xFFD1D5DB);
    }
    final groupId = _memberCanonicalGroupId(member);
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
    if (!_isPersonalWorkspace && _isExpiredMember(member)) {
      return const Color(0xFFF9FAFB);
    }
    if (!_isPersonalWorkspace && _isDormantMember(member)) {
      return const Color(0xFF4B5563);
    }
    final groupId = _memberCanonicalGroupId(member);
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

  Color _memberDisplayGroupAccentColorForGroupId(String groupId) {
    if (groupId == _allGroupId) {
      return const Color(0xFF5B4BDB);
    }

    if (groupId == _systemExpiredGroupId) {
      return const Color(0xFF6B7280);
    }

    if (groupId == _systemDormantGroupId) {
      return const Color(0xFFD1D5DB);
    }

    if (groupId == _ungroupedGroupId) {
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

  Color _memberDisplayGroupTextColorForGroupId(String groupId) {
    if (groupId == _allGroupId) {
      return Colors.white;
    }
    if (groupId == _systemExpiredGroupId) {
      return const Color(0xFFF9FAFB);
    }

    if (groupId == _systemDormantGroupId) {
      return const Color(0xFF4B5563);
    }

    if (groupId == _ungroupedGroupId) {
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
      _MemberCardGroupMenuItem(
        id: _ungroupedGroupId,
        label: _groupLabel(_ungroupedGroupId),
        icon: Icons.home_rounded,
      ),
      ..._groupIds.map(
        (groupId) => _MemberCardGroupMenuItem(
          id: groupId,
          label: _groupLabel(groupId),
          icon: Icons.folder_open_rounded,
        ),
      ),
      if (!_isPersonalWorkspace) ...[
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
      ],
    ];
  }

  Future<void> _handleMemberQuickGroupChange(
      Member member, String targetGroupId) async {
    _closeHeaderOverlayIfNeeded();

    if (_isPersonalWorkspace && !_systemGroupIds.contains(targetGroupId)) {
      final allowed = await _guardPersonalTaxonomyFeature(
        AppTierFeatureKey.personalGroup,
        entryPoint: 'client_list_quick_group_assignment',
      );
      if (!allowed || !mounted) return;
      try {
        await PersonalMemberTaxonomyService(
          uid: widget.personalOwnerUid!.trim(),
        ).assignMemberAndVerify(
          memberId: member.id,
          assignments: PersonalMemberAssignmentPatch(
            groupProvided: true,
            personalGroupId:
                targetGroupId == _ungroupedGroupId ? null : targetGroupId,
          ),
        );
        if (!mounted) return;
        _showSnack('${aifcPersonLabel(member.name)} 그룹이 변경됐어요.');
      } catch (_) {
        if (!mounted) return;
        _showSnack('그룹을 변경하지 못했어요. 다시 시도해 주세요.');
      }
      return;
    }

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
          'groupName': _groupLabel(_ungroupedGroupId),
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
          'groupName': _groupLabel(targetGroupId),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
    _setMemberGroupMap(nextGroupMap);

    if (!mounted) return;
    _showSnack('${aifcPersonLabel(member.name)} 그룹이 변경되었어요.');
  }

  void _handleHeaderCreateGroup() async {
    _closeHeaderOverlayIfNeeded();
    await _showCreateGroupDialog();
  }

  Future<void> _showGroupManagementSheet() async {
    _closeHeaderOverlayIfNeeded();

    if (_isPersonalWorkspace) {
      await _openPersonalTaxonomyManagement(
        PersonalMemberTaxonomyKind.group,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _GroupManagementSheet(
          groupIds: _groupIds,
          systemGroupIds: _systemGroupIds,
          ungroupedGroupId: _ungroupedGroupId,
          groupNames: _groupNames,
          onCreateGroup: _showCreateGroupDialog,
          onRenameGroup: _showRenameGroupDialog,
          onDeleteGroup: _showDeleteGroupDialog,
          onReorderGroups: _saveGroupOrder,
        );
      },
    );
  }

  void _handleGroupFilter(String groupId) {
    _clearAlertFilter();
    _clearDashboardCareFilter();
    setState(() {
      _selectedLessonDate = null;
      _membershipFilter = null;
      _initialQuickFilter = ClientListInitialFilter.none;
    });
    _setSelectedGroupId(groupId == _allGroupId ? null : groupId);
  }

  Future<void> _showPersonalTaxonomyManagementMenu() async {
    final selection =
        await AifcOptionChatSheet.show<PersonalMemberTaxonomyKind>(
      context: context,
      nickname: _aifcNicknameLabel,
      title: '회원 분류를 관리해볼까요?',
      message: '그룹은 센터·반처럼 한 곳에 소속시키고, 태그는 여러 기준을 함께 표시할 때 사용해요.',
      selectedValue: null,
      closeText: '닫기',
      guidanceText: '관리할 분류를 선택해주세요.',
      items: const [
        AifcOptionItem(
          value: PersonalMemberTaxonomyKind.group,
          title: '그룹 관리',
          subtitle: '센터, 반, 소속처럼 한 곳으로 분류해요.',
          icon: Icons.folder_open_rounded,
        ),
        AifcOptionItem(
          value: PersonalMemberTaxonomyKind.tag,
          title: '태그 관리',
          subtitle: 'VIP, 통증, 목표처럼 여러 기준을 함께 표시해요.',
          icon: Icons.sell_outlined,
        ),
      ],
    );
    if (selection == null || !mounted) return;
    await _openPersonalTaxonomyManagement(selection);
  }

  Future<void> _handlePersonalTaxonomyExample(
    PersonalTaxonomyFilterEntry entry,
  ) async {
    final isGroup = entry.role == PersonalTaxonomyFilterRole.exampleGroup;
    final kind = isGroup
        ? PersonalMemberTaxonomyKind.group
        : PersonalMemberTaxonomyKind.tag;
    if (!isGroup) {
      final allowed = await _guardPersonalTaxonomyFeature(
        AppTierFeatureKey.personalTag,
        entryPoint: 'client_list_example_tag',
      );
      if (!allowed || !mounted) return;
    }
    final selection = await AifcOptionChatSheet.show<String>(
      context: context,
      nickname: _aifcNicknameLabel,
      title: isGroup ? '그룹으로 나눠볼까요?' : '태그로 세분화해볼까요?',
      message: isGroup
          ? '새 그룹을 만들어 회원을 센터나 반별로 나눌 수 있어요.'
          : '이런 태그를 직접 만들어 회원을 여러 기준으로 분류할 수 있어요.',
      selectedValue: null,
      closeText: '닫기',
      guidanceText: '예시 칩은 안내용이며 자동으로 저장되지 않아요.',
      items: [
        AifcOptionItem(
          value: 'manage',
          title: isGroup ? '그룹 만들기' : '태그 만들기',
          subtitle:
              isGroup ? '기존 그룹 관리 화면에서 추가해요.' : '기존 AIFC 태그 관리 시트에서 추가해요.',
          icon: isGroup ? Icons.add_business_rounded : Icons.new_label_rounded,
        ),
      ],
    );
    if (selection != 'manage' || !mounted) return;
    await _openPersonalTaxonomyManagement(kind);
  }

  Future<void> _handlePersonalTaxonomyFilterEntry(
    PersonalTaxonomyFilterEntry entry,
  ) async {
    if (entry.isExample) {
      await _handlePersonalTaxonomyExample(entry);
      return;
    }
    if (entry.role == PersonalTaxonomyFilterRole.all) {
      _handleGroupFilter(_allGroupId);
      _selectedPersonalTagIdNotifier.value = null;
      _setSelectedPersonalStatusFilter(PersonalMemberStatusFilter.all);
      return;
    }
    if (entry.role == PersonalTaxonomyFilterRole.statusDormant) {
      _setSelectedPersonalStatusFilter(PersonalMemberStatusFilter.dormant);
      return;
    }
    if (entry.role == PersonalTaxonomyFilterRole.statusExpired) {
      _setSelectedPersonalStatusFilter(PersonalMemberStatusFilter.expired);
      return;
    }
    if (entry.role == PersonalTaxonomyFilterRole.tag) {
      await _handlePersonalTagFilter(entry.id);
      return;
    }
    _handleGroupFilter(entry.id);
  }

  Future<bool> _guardPersonalTaxonomyFeature(
    AppTierFeatureKey feature, {
    required String entryPoint,
  }) async {
    if (!_isPersonalWorkspace) return false;
    final allowed = await AifcTierFeatureGateSheet.guard(
      context: context,
      access: _personalTierAccess,
      feature: feature,
      loadAccess: () => AppTierAccessService.loadPersonalTrainerAccess(
        uid: widget.personalOwnerUid!.trim(),
      ),
      entryPoint: entryPoint,
    );
    if (allowed) await _loadPersonalTierAccess();
    return allowed;
  }

  Future<void> _openPersonalTaxonomyManagement(
    PersonalMemberTaxonomyKind kind,
  ) async {
    final feature = kind == PersonalMemberTaxonomyKind.group
        ? AppTierFeatureKey.personalGroup
        : AppTierFeatureKey.personalTag;
    final allowed = await _guardPersonalTaxonomyFeature(
      feature,
      entryPoint: 'client_list_${kind.name}_management',
    );
    if (!allowed || !mounted) return;
    if (kind == PersonalMemberTaxonomyKind.tag) {
      await AifcPersonalTagManagementChatSheet.show(
        context: context,
        ownerUid: widget.personalOwnerUid!.trim(),
      );
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => PersonalMemberTaxonomyManagementPage(
          ownerUid: widget.personalOwnerUid!.trim(),
          kind: kind,
        ),
      ),
    );
  }

  Future<void> _handlePersonalTagFilter(String? tagId) async {
    final allowed = await _guardPersonalTaxonomyFeature(
      AppTierFeatureKey.personalTag,
      entryPoint: 'client_list_tag_filter',
    );
    if (!allowed || !mounted) return;
    _selectedPersonalTagIdNotifier.value = tagId;
    _scrollListToTop();
  }

  void _resetQuickFilters() {
    _closeHeaderOverlayIfNeeded();

    _searchController.clear();
    _searchKeywordNotifier.value = '';

    _clearAlertFilter();
    _clearDashboardCareFilter();
    _setSelectedGroupId(null);
    _selectedPersonalTagIdNotifier.value = null;
    _setSelectedPersonalStatusFilter(PersonalMemberStatusFilter.all);

    setState(() {
      _selectedLessonDate = null;
      _membershipFilter = null;
      _sortOption = SortOption.name;
      _sortAscending = true;
      _initialQuickFilter = ClientListInitialFilter.none;
    });
  }

  Comparator<Member> _memberComparator(SortOption option) {
    switch (option) {
      case SortOption.name:
        return (a, b) => _compareNameOrder(a.name ?? '', b.name ?? '');

      case SortOption.group:
        return _compareGroupLabelForSection;

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

  Future<void> _openEdit(Member member) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClientCardPage.edit(
          memberId: member.id,
          initialName: member.name,
          personalOwnerUid: widget.personalOwnerUid,
        ),
      ),
    );
    if (!mounted || _isPersonalWorkspace) return;
    await _loadGroups();
  }

  Future<void> _openLog(Member member) async {
    final owner = widget.personalOwnerUid?.trim() ?? '';
    if (owner.isNotEmpty) {
      final allowed = await PersonalTrainingLogEntryGuard.guard(
        context: context,
        ownerUid: owner,
        memberId: member.id,
        loadAccess: () =>
            AppTierAccessService.loadPersonalTrainerAccess(uid: owner),
        entryPoint: 'client_list_training_log',
      );
      if (!allowed || !mounted) return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalTrainingLogPage(
          memberId: member.id,
          memberName: member.name ?? '',
          memberPhone: member.phone ?? '',
          totalSessions: member.totalSessions,
          remainingSessions: member.remainingSessions,
          lastLogAt: member.lastLogAt,
          personalOwnerUid: owner.isEmpty ? null : owner,
        ),
      ),
    );
  }

  Future<void> _openCreate() async {
    final owner = widget.personalOwnerUid?.trim() ?? '';
    if (owner.isNotEmpty) {
      final allowed = await AifcTierFeatureGateSheet.guard(
        context: context,
        access: null,
        feature: AppTierFeatureKey.customerCardCreate,
        loadAccess: () =>
            AppTierAccessService.loadPersonalTrainerAccess(uid: owner),
        entryPoint: 'client_list_create',
      );
      if (!allowed || !mounted) return;
    }
    final newId = FirebaseFirestore.instance.collection('members').doc().id;

    final result = await Navigator.push<PersonalMemberCardSaveResult>(
      context,
      MaterialPageRoute(
        builder: (_) => ClientCardPage.newMember(
          memberId: newId,
          personalOwnerUid: owner.isEmpty ? null : owner,
        ),
      ),
    );
    if (!mounted) return;
    if (_isPersonalWorkspace) {
      if (result == null) return;
      _searchController.clear();
      _searchKeywordNotifier.value = '';
      _clearDashboardCareFilter();
      _clearAlertFilter();
      setState(() {
        _selectedLessonDate = null;
        _membershipFilter = null;
        _initialQuickFilter = ClientListInitialFilter.none;
      });
      _setSelectedGroupId(null);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      await scrollToMember(result.memberId);
      final visible = _memberItemKeys[result.memberId]?.currentContext != null;
      PersonalMemberCardSaveService.logVisibleResult(
        groupSelection: result.groupSelection,
        visibleAfterSave: visible,
      );
      return;
    }
    await _loadGroups();
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

  Future<void> _updateMemberStatus(Member member, String newStatus) async {
    try {
      if (_isPersonalWorkspace) {
        final nextState = switch (newStatus) {
          '휴면' => 'dormant',
          '만료' => 'expired',
          _ => 'active',
        };
        await PersonalMemberCardSaveService(
          uid: widget.personalOwnerUid!.trim(),
        ).transitionStateAndVerify(
          memberId: member.id,
          nextState: nextState,
        );
        if (!mounted) return;
        _showSnack('${aifcPersonLabel(member.name)} 활동상태가 변경되었어요.');
        return;
      }
      final memberRef =
          FirebaseFirestore.instance.collection('members').doc(member.id);

      final nextGroupMap = Map<String, String>.from(_memberGroupMap);

      final updateData = <String, dynamic>{
        'memberStatus': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (newStatus == '만료' || newStatus == '휴면' || newStatus == '활성') {
        updateData['groupId'] = FieldValue.delete();
        nextGroupMap.remove(member.id);
      }

      await memberRef.set(updateData, SetOptions(merge: true));

      _setMemberGroupMap(nextGroupMap);

      if (!mounted) return;
      _showSnack('${aifcPersonLabel(member.name)} 활동상태가 변경되었어요.');
    } catch (e) {
      if (!mounted) return;

      _showSnack('활동 상태 변경에 실패했어요.');
    }
  }

  Future<void> _openDeletedMembersRestoreSheet() async {
    if (!mounted) return;

    await AifcInfoChatSheet.show(
      context: context,
      nickname: _aifcTrainerNameSourceText.trim().isEmpty
          ? '강사'
          : _aifcTrainerNameSourceText,
      title: '삭제 회원 복구 문의',
      message: '삭제된 회원은 내 회원관리에서는 바로 숨겨집니다.\n'
          '다만 복구 요청을 위해 삭제일 기준 7일간은 보관됩니다.',
      items: const [
        '삭제 후 7일 이내라면 복구 요청이 가능합니다.',
        '복구가 필요한 경우 고객센터로 문의해주세요.',
        '7일이 지나면 복구가 어려울 수 있습니다.',
      ],
      confirmText: '확인했어요',
      userConfirmText: '확인했습니다',
      replyText: '확인되었습니다. 복구가 필요하면 고객센터로 문의해주세요.',
      icon: Icons.support_agent_rounded,
      accentColor: AifcColors.primary,
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
      _scrollListToTop();
    }
  }
}

enum SortOption {
  name,
  group,
  expirySoon,
  recentLesson,
  recentRegistration,
}

enum _MembershipListFilter {
  needsCheck,
}

String _membershipListFilterLabel(_MembershipListFilter filter) {
  switch (filter) {
    case _MembershipListFilter.needsCheck:
      return '회원권 체크';
  }
}

class _MemberMembershipMeta {
  const _MemberMembershipMeta({
    required this.status,
    required this.contractStatus,
    required this.contractSignedAt,
    required this.contractDraftExists,
    required this.startAt,
    required this.endAt,
    required this.termMonths,
    required this.customDays,
  });

  final String status;
  final String contractStatus;
  final DateTime? contractSignedAt;
  final bool contractDraftExists;
  final DateTime? startAt;
  final DateTime? endAt;
  final int? termMonths;
  final int? customDays;

  bool get isPaused => status == 'paused';

  bool get isMembershipContractSigned {
    return contractStatus == 'signed' || contractSignedAt != null;
  }

  bool get needsContractSignature {
    return contractDraftExists && !isMembershipContractSigned;
  }

  int? get normalizedTermMonths {
    if (termMonths != null && termMonths! > 0) {
      return termMonths;
    }

    final days = customDays;
    if (days == null || days <= 0) return null;

    if (days >= 80 && days <= 100) return 3;
    if (days >= 160 && days <= 200) return 6;
    if (days >= 330 && days <= 390) return 12;

    return null;
  }

  String? get termLabel {
    final months = normalizedTermMonths;
    if (months == null) return null;

    return '$months개월권';
  }

  static int? _intFromAny(dynamic value) {
    if (value is num) return value.toInt();

    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;

    return int.tryParse(text);
  }

  static DateTime? _dateFromAny(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    final text = (value ?? '').toString().trim();
    if (text.isEmpty) return null;

    return DateTime.tryParse(text);
  }

  factory _MemberMembershipMeta.fromData(Map<String, dynamic> data) {
    final rawMembership = data['membership'];

    final membership = rawMembership is Map
        ? Map<String, dynamic>.from(rawMembership)
        : <String, dynamic>{};

    return _MemberMembershipMeta(
      status: (membership['status'] ?? data['membershipStatus'] ?? '')
          .toString()
          .trim(),
      contractStatus: (data['membershipContractStatus'] ??
              membership['contractStatus'] ??
              '')
          .toString()
          .trim(),
      contractSignedAt: _dateFromAny(
        data['membershipContractSignedAt'] ?? membership['contractSignedAt'],
      ),
      contractDraftExists: data['membershipContractDraftExists'] == true ||
          (data['membershipContractStatus'] ??
                      membership['contractStatus'] ??
                      '')
                  .toString()
                  .trim() ==
              'draft',
      startAt: _dateFromAny(
        membership['startAt'] ?? data['membershipStartAt'] ?? data['passStart'],
      ),
      endAt: _dateFromAny(
        membership['endAt'] ??
            data['membershipEndAt'] ??
            data['passEnd'] ??
            data['expireAt'],
      ),
      termMonths: _intFromAny(
        membership['termMonths'] ?? data['termMonths'],
      ),
      customDays: _intFromAny(
        membership['customDays'] ?? data['customDays'],
      ),
    );
  }
}

enum _SearchMenuAction {
  sortName,
  sortGroup,
  sortExpirySoon,
  sortRecentLesson,
  sortRecentRegistration,
  pickLessonDate,
  clearLessonDate,

  membershipNeedsCheck,
  clearMembershipFilter,
}

enum AlertType {
  membershipExpiry,
  newMember,
  attentionNeeded,
  birthday,
  moreDay,
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

enum ClientListInitialFilter {
  none,
  lowRemaining,
  careNeeded,
}

enum _DashboardCareFilter {
  expiry,
  special,
  attention,
}

const Map<AlertType, List<Color>> kAlertRingColors = {
  AlertType.membershipExpiry: [
    Color(0xFFF09595),
    Color(0xFFA32D2D),
    Color(0xFFF7C1C1),
    Color(0xFFF09595),
  ],
  AlertType.reRegistration: [
    Color(0xFFEF9F27),
    Color(0xFFBA7517),
    Color(0xFFFAC775),
    Color(0xFFEF9F27),
  ],
  AlertType.newMember: [
    Color(0xFF97C459),
    Color(0xFF3B6D11),
    Color(0xFFC0DD97),
    Color(0xFF97C459),
  ],
  AlertType.hundredDay: [
    Color(0xFF85B7EB),
    Color(0xFF185FA5),
    Color(0xFFB5D4F4),
    Color(0xFF85B7EB),
  ],
  AlertType.hundredLesson: [
    Color(0xFF85B7EB),
    Color(0xFF185FA5),
    Color(0xFFB5D4F4),
    Color(0xFF85B7EB),
  ],
  AlertType.birthday: [
    Color(0xFFED93B1),
    Color(0xFF993556),
    Color(0xFFF4C0D1),
    Color(0xFFED93B1),
  ],
  AlertType.moreDay: [
    Color(0xFFBFA5FF),
    Color(0xFF6D28D9),
    Color(0xFFE9D5FF),
    Color(0xFFBFA5FF),
  ],
  AlertType.attentionNeeded: [
    Color(0xFFEF9F27),
    Color(0xFFBA7517),
    Color(0xFFFAC775),
    Color(0xFFEF9F27),
  ],
  AlertType.painCheck: [
    Color(0xFFF09595),
    Color(0xFFA32D2D),
    Color(0xFFF7C1C1),
    Color(0xFFF09595),
  ],
  AlertType.healthCheck: [
    Color(0xFF97C459),
    Color(0xFF3B6D11),
    Color(0xFFC0DD97),
    Color(0xFF97C459),
  ],
};

const Map<AlertType, Color> kAlertBadgeColors = {
  AlertType.membershipExpiry: Color(0xFFA32D2D),
  AlertType.reRegistration: Color(0xFFBA7517),
  AlertType.newMember: Color(0xFF3B6D11),
  AlertType.hundredDay: Color(0xFF185FA5),
  AlertType.hundredLesson: Color(0xFF185FA5),
  AlertType.birthday: Color(0xFF993556),
  AlertType.moreDay: Color(0xFF6D28D9),
  AlertType.attentionNeeded: Color(0xFFBA7517),
  AlertType.painCheck: Color(0xFFA32D2D),
  AlertType.healthCheck: Color(0xFF3B6D11),
};

const Map<AlertType, IconData> kAlertIcons = {
  AlertType.membershipExpiry: Icons.warning_amber_rounded,
  AlertType.reRegistration: Icons.refresh_rounded,
  AlertType.newMember: Icons.person_add_alt_1_rounded,
  AlertType.hundredDay: Icons.flag_rounded,
  AlertType.hundredLesson: Icons.flag_rounded,
  AlertType.birthday: Icons.cake_rounded,
  AlertType.moreDay: Icons.event_available_rounded,
  AlertType.attentionNeeded: Icons.check_circle_outline_rounded,
  AlertType.painCheck: Icons.emergency_rounded,
  AlertType.healthCheck: Icons.favorite_border_rounded,
};

const Map<AlertType, Color> kAlertBorderColors = {
  AlertType.membershipExpiry: Color(0xFFE24B4A),
  AlertType.reRegistration: Color(0xFFEF9F27),
  AlertType.newMember: Color(0xFF639922),
  AlertType.hundredDay: Color(0xFF378ADD),
  AlertType.hundredLesson: Color(0xFF378ADD),
  AlertType.birthday: Color(0xFFD4537E),
  AlertType.moreDay: Color(0xFF7C3AED),
  AlertType.attentionNeeded: Color(0xFFEF9F27),
  AlertType.painCheck: Color(0xFFE24B4A),
  AlertType.healthCheck: Color(0xFF639922),
};

const Map<AlertType, String> kAlertChipLabels = {
  AlertType.membershipExpiry: '만료임박',
  AlertType.reRegistration: '재등록',
  AlertType.newMember: '신규',
  AlertType.hundredDay: '100일',
  AlertType.hundredLesson: '100회',
  AlertType.birthday: '생일',
  AlertType.moreDay: 'MORE 데이',
  AlertType.attentionNeeded: '확인',
  AlertType.painCheck: '주의',
  AlertType.healthCheck: '건강체크',
};

const Map<AlertType, Color> kAlertChipBgColors = {
  AlertType.membershipExpiry: Color(0xFFFCEBEB),
  AlertType.reRegistration: Color(0xFFFAEEDA),
  AlertType.newMember: Color(0xFFEAF3DE),
  AlertType.hundredDay: Color(0xFFE6F1FB),
  AlertType.hundredLesson: Color(0xFFE6F1FB),
  AlertType.birthday: Color(0xFFFBEAF0),
  AlertType.moreDay: Color(0xFFF3E8FF),
  AlertType.attentionNeeded: Color(0xFFFAEEDA),
  AlertType.painCheck: Color(0xFFFCEBEB),
  AlertType.healthCheck: Color(0xFFEAF3DE),
};

const Map<AlertType, Color> kAlertChipTextColors = {
  AlertType.membershipExpiry: Color(0xFFA32D2D),
  AlertType.reRegistration: Color(0xFFBA7517),
  AlertType.newMember: Color(0xFF3B6D11),
  AlertType.hundredDay: Color(0xFF185FA5),
  AlertType.hundredLesson: Color(0xFF185FA5),
  AlertType.birthday: Color(0xFF993556),
  AlertType.moreDay: Color(0xFF6D28D9),
  AlertType.attentionNeeded: Color(0xFFBA7517),
  AlertType.painCheck: Color(0xFFA32D2D),
  AlertType.healthCheck: Color(0xFF3B6D11),
};

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
    required this.dailyTitle,
  });

  final int expiryCount;
  final int attentionCount;
  final int birthdayCount;
  final List<DashboardAlert> alerts;

  final HeaderFocusType focusType;
  final int focusCount;
  final String dailyTitle;

  int get totalCareCount => alerts.map((e) => e.customerName).toSet().length;

  static DashboardHeaderData fromMembers(
    List<Member> members, {
    required int messageSeed,
  }) {
    final now = DateTime.now();

    int expiryCount = 0;
    int newMemberCount = 0;

    final Set<String> attentionMemberIds = <String>{};
    final Set<String> scheduleMemberIds = <String>{};

    final List<DashboardAlert> alerts = [];

    for (final member in members) {
      final isExpired = member.memberStatus == '만료';
      final isDormant = member.memberStatus == '휴면';
      final isActive = !isExpired && !isDormant;

      final remaining = member.remainingSessions;
      final total = member.totalSessions <= 0 ? 0 : member.totalSessions;
      final usedSessions = total <= 0 ? 0 : (total - remaining).clamp(0, total);

      final bool hasLessonRegistration = isActive && total > 0;

      final firstDate = member.firstDate;
      final recentReg = member.recentReg;
      final expireAt = member.expireAt;

      final int? femaleConditionDaysLeft =
          _femaleConditionDaysLeft(member, now);

      final bool isFemaleConditionCheck = isActive &&
          femaleConditionDaysLeft != null &&
          femaleConditionDaysLeft >= -2 &&
          femaleConditionDaysLeft <= 3;

      final DateTime? newMemberBaseDate = recentReg ?? firstDate;

      final firstLessonDays = newMemberBaseDate == null
          ? 9999
          : _daysBetween(newMemberBaseDate, now);

      final bool isExpirySoon =
          hasLessonRegistration && remaining >= 0 && remaining < 5;

      final bool isReRegistrationTarget =
          hasLessonRegistration && remaining >= 0 && remaining <= 3;

      final int? membershipDaysLeft =
          expireAt == null ? null : _daysBetween(now, expireAt);

      final bool isMembershipExpirySoon = isActive &&
          membershipDaysLeft != null &&
          membershipDaysLeft >= 0 &&
          membershipDaysLeft <= 10;

      final bool isMembershipExpired =
          isActive && membershipDaysLeft != null && membershipDaysLeft < 0;

      final bool needsMembershipCheck =
          isMembershipExpirySoon || isMembershipExpired;

      final bool isNewMember =
          isActive && firstLessonDays >= 0 && firstLessonDays < 7;

      final bool isHundredDay =
          isActive && firstLessonDays >= 93 && firstLessonDays <= 103;

      final bool isHundredLesson =
          isActive && usedSessions >= 93 && usedSessions <= 100;

      final int? birthdayDaysLeft =
          _daysUntilNextMonthDay(member.birthDate, now);

      final bool isBirthdaySoon = isActive &&
          birthdayDaysLeft != null &&
          birthdayDaysLeft >= 0 &&
          birthdayDaysLeft <= 7;

      final int? anniversaryDaysLeft =
          _daysUntilNextMonthDay(member.anniversaryDate, now);

      final bool isAnniversarySoon = isActive &&
          anniversaryDaysLeft != null &&
          anniversaryDaysLeft >= 0 &&
          anniversaryDaysLeft <= 14;

      final int? nextMoreDayDaysLeft = member.nextMoreDayAt == null
          ? null
          : _daysBetween(now, member.nextMoreDayAt!);

      final bool isNextMoreDaySoon = isActive &&
          nextMoreDayDaysLeft != null &&
          nextMoreDayDaysLeft >= -7 &&
          nextMoreDayDaysLeft <= 14;

      final String nextMoreDayLabel =
          (member.nextMoreDayLabel ?? '').trim().isEmpty
              ? 'D-DAY 목표'
              : member.nextMoreDayLabel!.trim();

// 재등록은 만료 임박 쪽에서만 관리
// MORE 체크에는 넣지 않음

      if (isNewMember) {
        newMemberCount++;
        attentionMemberIds.add(member.id);
      }

      if (isBirthdaySoon && birthdayDaysLeft != null) {
        alerts.add(
          DashboardAlert(
            memberId: member.id,
            customerName: member.name ?? '이름없음',
            type: AlertType.birthday,
            label: birthdayDaysLeft == 0 ? '오늘 생일이에요' : '생일이 다가와요',
            daysLeft: birthdayDaysLeft,
            // 생일 당일은 만료/재등록보다 먼저 보이게 우선순위를 올립니다.
            priority: birthdayDaysLeft == 0 ? 0 : 5,
          ),
        );
      }

      if (isAnniversarySoon && anniversaryDaysLeft != null) {
        final anniversaryLabel = (member.anniversaryLabel ?? '').trim().isEmpty
            ? 'Focus Day'
            : member.anniversaryLabel!.trim();

        alerts.add(
          DashboardAlert(
            memberId: member.id,
            customerName: member.name ?? '이름없음',
            type: AlertType.birthday,
            label: anniversaryDaysLeft == 0
                ? '$anniversaryLabel 오늘'
                : '$anniversaryLabel ${_dDayText(anniversaryDaysLeft)}',
            daysLeft: anniversaryDaysLeft,
            priority: 5,
          ),
        );
      }

      if (isNextMoreDaySoon && nextMoreDayDaysLeft != null) {
        alerts.add(
          DashboardAlert(
            memberId: member.id,
            customerName: member.name ?? '이름없음',
            type: AlertType.moreDay,
            label: nextMoreDayDaysLeft == 0
                ? '$nextMoreDayLabel 오늘이에요'
                : '$nextMoreDayLabel 일정이에요',
            daysLeft: nextMoreDayDaysLeft,
            priority: 5,
          ),
        );
      }

      if (isFemaleConditionCheck && femaleConditionDaysLeft != null) {
        attentionMemberIds.add(member.id);

        alerts.add(
          DashboardAlert(
            memberId: member.id,
            customerName: member.name ?? '이름없음',
            type: AlertType.healthCheck,
            label: '컨디션 주기 체크',
            daysLeft: femaleConditionDaysLeft,
            priority: femaleConditionDaysLeft == 0 ? 2 : 7,
          ),
        );
      }

      if (isHundredDay ||
          isHundredLesson ||
          isBirthdaySoon ||
          isAnniversarySoon ||
          isNextMoreDaySoon) {
        scheduleMemberIds.add(member.id);
      }

      if (isExpired) {
        continue;
      }

      if (isDormant) {
        attentionMemberIds.add(member.id);
        alerts.add(
          DashboardAlert(
            memberId: member.id,
            customerName: member.name ?? '이름없음',
            type: AlertType.attentionNeeded,
            label: '휴면회원',
            priority: 2,
          ),
        );
        continue;
      }

      if (isExpirySoon || needsMembershipCheck) {
        final String? membershipText = expireAt == null ||
                membershipDaysLeft == null
            ? null
            : membershipDaysLeft < 0
                ? '회원권 만료됨 · ${_formatDate(expireAt)}'
                : membershipDaysLeft == 0
                    ? '회원권 오늘 만료 · ${_formatDate(expireAt)}'
                    : '회원권 D-$membershipDaysLeft · ${_formatDate(expireAt)}';

        final String sessionText = isReRegistrationTarget
            ? '재등록 안내 필요 · ${member.remainingSessions}회 남음'
            : '레슨만료예정 · ${member.remainingSessions}회 남음';

        final bool hasSessionAlert = isExpirySoon || isReRegistrationTarget;

        final String label = hasSessionAlert
            ? membershipText == null
                ? sessionText
                : '$sessionText · $membershipText'
            : membershipText ?? '회원권 만료 임박';

        alerts.add(
          DashboardAlert(
            memberId: member.id,
            customerName: member.name ?? '이름없음',
            type: isReRegistrationTarget
                ? AlertType.reRegistration
                : AlertType.membershipExpiry,
            label: label,
            daysLeft: membershipDaysLeft != null && membershipDaysLeft >= 0
                ? membershipDaysLeft
                : null,
            priority: isReRegistrationTarget ? 2 : 1,
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
                : '신규 회원 · ${firstLessonDays + 1}일차',
            daysLeft: null,
            priority: 4,
          ),
        );
      }

      if (isHundredDay) {
        final diff = 100 - firstLessonDays;

        alerts.add(
          DashboardAlert(
            memberId: member.id,
            customerName: member.name ?? '이름없음',
            type: AlertType.hundredDay,
            label: diff == 0
                ? '레슨 시작 100일'
                : diff > 0
                    ? '레슨 시작 100일 ${_dDayText(diff)}'
                    : '레슨 시작 100일 D+${diff.abs()}',
            daysLeft: diff.abs(),
            priority: 6,
          ),
        );
      }

      if (isHundredLesson) {
        final diff = 100 - usedSessions;

        alerts.add(
          DashboardAlert(
            memberId: member.id,
            customerName: member.name ?? '이름없음',
            type: AlertType.hundredLesson,
            label: diff == 0
                ? '누적 100회 레슨'
                : diff > 0
                    ? '누적 100회까지 ${diff}회'
                    : '누적 ${usedSessions}회 레슨',
            daysLeft: diff.abs(),
            priority: 7,
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

    final int attentionCount = attentionMemberIds.length;
    final int birthdayCount = scheduleMemberIds.length;

    final HeaderFocusType focusType;
    final int focusCount;

    if (expiryCount > 0) {
      focusType = HeaderFocusType.expiry;
      focusCount = expiryCount;
    } else if (newMemberCount > 0) {
      focusType = HeaderFocusType.newMember;
      focusCount = newMemberCount;
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

    return DashboardHeaderData(
      expiryCount: expiryCount,
      attentionCount: attentionCount,
      birthdayCount: birthdayCount,
      alerts: alerts.take(12).toList(),
      focusType: focusType,
      focusCount: focusCount,
      dailyTitle: _rotatingDailyTitle(
        focusType,
        seed: messageSeed,
      ),
    );
  }

  static String _rotatingDailyTitle(
    HeaderFocusType type, {
    required int seed,
  }) {
    final expiryLines = [
      '만료 임박 회원이 있어요. 안내 한 번이 재등록으로 이어질 수 있어요.',
      '남은 횟수가 적은 회원부터 먼저 챙겨보세요.',
      '마지막까지 좋은 경험으로 이어질 수 있게 확인해보세요.',
      '작은 안내가 좋은 기회로 연결될 수 있어요.',
    ];

    final newMemberLines = [
      '신규 회원이 있어요. 처음 일주일이 가장 중요한 시기예요.',
      '첫 경험이 오래가는 인상을 만들어요. 먼저 챙겨보세요.',
      '신규 회원의 운동 흐름과 컨디션을 가볍게 확인해보세요.',
      '작은 관심이 장기 회원으로 이어질 수 있어요.',
    ];

    final attentionLines = [
      '놓치기 쉬운 회원님부터 같이 확인해볼까요?',
      '지금 확인해두면 한 주의 흐름이 훨씬 편해져요.',
      '간단한 확인만으로 만족도가 달라질 수 있어요.',
      '오늘 확인하면 좋은 관리 포인트가 있어요.',
    ];

    final birthdayLines = [
      '소중한 일정이 있는 회원님이 있어요. 기억해주는 한마디가 달라요.',
      '세심한 일정 확인이 관계를 더 좋게 만들어요.',
      '가벼운 축하와 체크가 오래 남는 경험이 될 수 있어요.',
      '소중한 일정을 챙기면 만족도가 높아질 수 있어요.',
    ];

    final calmLines = [
      '오늘은 여유로운 하루예요. 차분하게 점검해보세요.',
      '좋은 흐름일수록 기본 관리가 중요해요.',
      '지금처럼 안정적인 관리 흐름을 이어가면 돼요.',
      '작은 점검이 더 매끄러운 하루를 만들어요.',
    ];

    int pickIndex(List<String> lines) {
      if (lines.isEmpty) return 0;

      final typeSalt = switch (type) {
        HeaderFocusType.expiry => 11,
        HeaderFocusType.newMember => 23,
        HeaderFocusType.attention => 37,
        HeaderFocusType.birthday => 41,
        HeaderFocusType.calm => 53,
      };

      return (seed + typeSalt).abs() % lines.length;
    }

    return switch (type) {
      HeaderFocusType.expiry => expiryLines[pickIndex(expiryLines)],
      HeaderFocusType.newMember => newMemberLines[pickIndex(newMemberLines)],
      HeaderFocusType.attention => attentionLines[pickIndex(attentionLines)],
      HeaderFocusType.birthday => birthdayLines[pickIndex(birthdayLines)],
      HeaderFocusType.calm => calmLines[pickIndex(calmLines)],
    };
  }
}

enum _DashboardHeaderMenuAction {
  addMember,
  viewCard,
  viewList,
  createGroup,
  manageTags,
  resetFilters,
  restoreDeletedMembers,
}

class DashboardBlueHeader extends StatefulWidget {
  const DashboardBlueHeader({
    super.key,
    required this.data,
    required this.trainerLabel,
    required this.isPersonalWorkspace,
    required this.onBackTap,
    required this.isListViewListenable,
    required this.onAddCustomer,
    required this.onToggleListView,
    required this.onCreateGroup,
    required this.onManageTags,
    required this.onResetFilters,
    required this.onRestoreDeletedMembers,
    required this.selectedCareFilterListenable,
    required this.onCareFilterSelected,
    required this.onAlertTap,
  });

  final DashboardHeaderData data;
  final String trainerLabel;
  final bool isPersonalWorkspace;
  final VoidCallback onBackTap;
  final VoidCallback onAddCustomer;
  final VoidCallback onCreateGroup;
  final VoidCallback onManageTags;
  final VoidCallback onResetFilters;
  final VoidCallback onRestoreDeletedMembers;
  final ValueListenable<bool> isListViewListenable;
  final VoidCallback onToggleListView;

  final ValueListenable<_DashboardCareFilter?> selectedCareFilterListenable;
  final ValueChanged<_DashboardCareFilter> onCareFilterSelected;

  final void Function(String memberId)? onAlertTap;

  @override
  State<DashboardBlueHeader> createState() => _DashboardBlueHeaderState();
}

class _DashboardBlueHeaderState extends State<DashboardBlueHeader>
    with TickerProviderStateMixin {
  bool _expanded = false;

  bool get isExpanded => _expanded;

  void _toggleOverlay() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {}
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

  void _handleMenuSelected(_DashboardHeaderMenuAction action) {
    switch (action) {
      case _DashboardHeaderMenuAction.addMember:
        widget.onAddCustomer();
        break;

      case _DashboardHeaderMenuAction.viewCard:
        if (widget.isListViewListenable.value) {
          widget.onToggleListView();
        }
        break;

      case _DashboardHeaderMenuAction.viewList:
        if (!widget.isListViewListenable.value) {
          widget.onToggleListView();
        }
        break;

      case _DashboardHeaderMenuAction.createGroup:
        widget.onCreateGroup();
        break;

      case _DashboardHeaderMenuAction.manageTags:
        widget.onManageTags();
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

  void _showCareGuideSheet() {
    final trainerLabel =
        widget.trainerLabel.trim().isEmpty ? '강사님' : widget.trainerLabel.trim();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return AifcSheetFrame(
          maxHeightFactor: 0.76,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const AifcChatBubble(
                      side: AifcBubbleSide.user,
                      text: '관리 포인트가 뭐예요?',
                    ),
                    const SizedBox(height: 10),
                    AifcChatBubble(
                      side: AifcBubbleSide.fc,
                      text: '$trainerLabel, 제가 챙겨드리는 관리 포인트를 설명드릴게요.\n'
                          '회원관리에서 놓치기 쉬운 흐름을 세 가지로 나눠서 보여드려요.\n\n'
                          '같은 회원이 여러 조건에 걸릴 수 있지만, '
                          'AI FC가 더 중요한 내용부터 먼저 알려드리려고 노력하고 있어요.',
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CareGuideItem(
                            title: '만료 임박',
                            body: '잔여 회차, 회원권 만료, 재등록 타이밍을 확인해요.',
                            icon: Icons.warning_amber_rounded,
                            color: Color(0xFFE24B4A),
                          ),
                          SizedBox(height: 10),
                          _CareGuideItem(
                            title: 'MORE 데이',
                            body: '생일, 100회, 바디프로필처럼 특별히 챙길 날이에요.',
                            icon: Icons.event_available_rounded,
                            color: Color(0xFFD4537E),
                          ),
                          SizedBox(height: 10),
                          _CareGuideItem(
                            title: 'MORE 체크',
                            body: '건강, 통증, 메모처럼 확인이 필요한 회원 관리 포인트예요.',
                            icon: Icons.task_alt_rounded,
                            color: Color(0xFF4F46E5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(sheetContext).pop();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AifcColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AifcRadius.button),
                          ),
                        ),
                        child: const Text(
                          '알겠어요',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFocusSummaryCards(DashboardHeaderData data) {
    return ValueListenableBuilder<_DashboardCareFilter?>(
      valueListenable: widget.selectedCareFilterListenable,
      builder: (context, selectedFilter, _) {
        return Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.warning_amber_rounded,
                label: '만료 임박',
                value: '${data.expiryCount}명',
                isSelected: selectedFilter == _DashboardCareFilter.expiry,
                onTap: () {
                  widget.onCareFilterSelected(_DashboardCareFilter.expiry);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                icon: Icons.event_available_rounded,
                label: 'MORE 데이',
                value: '${data.birthdayCount}명',
                isSelected: selectedFilter == _DashboardCareFilter.special,
                onTap: () {
                  widget.onCareFilterSelected(_DashboardCareFilter.special);
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                icon: Icons.task_alt_rounded,
                label: 'MORE 체크',
                value: '${data.attentionCount}명',
                isSelected: selectedFilter == _DashboardCareFilter.attention,
                onTap: () {
                  widget.onCareFilterSelected(_DashboardCareFilter.attention);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final topPadding = MediaQuery.of(context).padding.top;
    final gradient = context.mtfHeaderGradient;

    return MtfHeaderNeonOverlay(
      isExpanded: _expanded,
      intensity: 0.52,
      bottomRadius: _expanded ? 22 : 28,
      strokeWidth: 1.6,
      child: GestureDetector(
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
            gradient: gradient,
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
          child: ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                          child: const Text(
                            '내 회원 관리',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _HeaderFlatIconButton(
                              icon: Icons.person_add_alt_1_rounded,
                              isActive: false,
                              onTap: widget.onAddCustomer,
                              tooltip: '회원 추가',
                            ),
                            const SizedBox(width: 2),
                            ValueListenableBuilder<bool>(
                              valueListenable: widget.isListViewListenable,
                              builder: (context, isListView, _) {
                                return MtfFloatingMoreMenuButton<
                                    _DashboardHeaderMenuAction>(
                                  tooltip: '더보기',
                                  icon: Icons.more_vert_rounded,
                                  iconColor:
                                      Colors.white.withValues(alpha: 0.72),
                                  iconSize: 23,
                                  cardWidth: 218,
                                  offset: const Offset(0, 8),
                                  onSelected: _handleMenuSelected,
                                  items: [
                                    if (widget.isPersonalWorkspace) ...[
                                      const MtfMoreMenuItem(
                                        value: _DashboardHeaderMenuAction
                                            .addMember,
                                        icon: Icons.person_add_alt_1_rounded,
                                        label: '회원 추가',
                                        subLabel: '새 고객카드 등록',
                                      ),
                                      const MtfMoreMenuItem(
                                        value: _DashboardHeaderMenuAction
                                            .createGroup,
                                        icon: Icons.folder_open_rounded,
                                        label: '그룹 관리',
                                        subLabel: '기본·사용자 그룹 관리',
                                      ),
                                      const MtfMoreMenuItem(
                                        value: _DashboardHeaderMenuAction
                                            .manageTags,
                                        icon: Icons.sell_outlined,
                                        label: '태그 관리',
                                        subLabel: 'Semi-Pro 복수 태그 관리',
                                      ),
                                    ],
                                    if (!widget.isPersonalWorkspace)
                                      MtfMoreMenuItem(
                                        value: _DashboardHeaderMenuAction
                                            .createGroup,
                                        icon: Icons.add_box_rounded,
                                        label: widget.isPersonalWorkspace
                                            ? '기본 그룹 이름 변경'
                                            : '새 그룹 만들기',
                                        subLabel: widget.isPersonalWorkspace
                                            ? '모든 Personal 회원 표시명'
                                            : '회원 분류 추가',
                                      ),
                                    MtfMoreMenuItem(
                                      value: _DashboardHeaderMenuAction
                                          .resetFilters,
                                      icon: Icons.restart_alt_rounded,
                                      label: '필터 초기화',
                                      subLabel: '검색/그룹 조건 해제',
                                    ),
                                    MtfMoreMenuItem(
                                      value: _DashboardHeaderMenuAction
                                          .restoreDeletedMembers,
                                      icon: Icons.support_agent_rounded,
                                      label: '삭제 회원 복구 문의',
                                      subLabel: '삭제된 회원 확인',
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, right: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const AifcAvatar(
                          size: 22,
                          isAnimating: true,
                          backgroundColor: Color(0xFF5B4BDB),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            data.dailyTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.left,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: _toggleOverlay,
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 6, 4, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'AI FC가 세심한 관리 포인트를 가져왔어요',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.92),
                                fontSize: 12.8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: _showCareGuideSheet,
                            borderRadius: BorderRadius.circular(999),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Icon(
                                Icons.help_outline_rounded,
                                size: 17,
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            _expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            color: Colors.white.withValues(alpha: 0.86),
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
                          ? const SizedBox(
                              width: double.infinity,
                              height: 0,
                            )
                          : TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, -8 * (1 - value)),
                                    child: child,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _buildFocusSummaryCards(data),
                                      const SizedBox(height: 10),
                                      _HeaderSlideOverlay(
                                        data: widget.data,
                                        onClose: () {
                                          setState(() => _expanded = false);
                                        },
                                        onAlertTap: widget.onAlertTap,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderSlideOverlayState extends State<_HeaderSlideOverlay> {
  final Set<String> _dismissedAlertKeys = <String>{};
  final Set<String> _permanentlyHiddenAlertKeys = <String>{};
  final ScrollController _alertScrollController = ScrollController();

  void _dismissAlert(String key, DashboardAlert alert) {
    setState(() {
      _dismissedAlertKeys.add(key);
    });

    _saveDismissedAlertsForToday();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateScrollHintState();
    });

    AifcInteraction.undoSnack(
      context: context,
      message: '${aifcPersonLabel(alert.customerName)} 알림을 오늘 하루 숨겼어요.',
      actionLabel: '되돌리기',
      onAction: () => _restoreAlert(key),
    );
  }

  String get _permanentHiddenPrefsKey {
    return 'dashboard_permanently_hidden_alerts_v1';
  }

  String _stableAlertKey(DashboardAlert alert) {
    return [
      alert.memberId,
      alert.type.name,
      alert.label,
    ].join('|');
  }

  String _permanentAlertKey(DashboardAlert alert) {
    // 영구 숨김은 날짜/D-day 문구가 바뀌어도 같은 종류의 알림으로 보도록
    // memberId + alert type 중심으로 저장합니다.
    //
    // 예:
    // 생일 알림 숨김 → 해당 회원 생일 알림 다시 안 보기
    // 회원권 만료 알림 숨김 → 해당 회원 회원권 만료 알림 다시 안 보기
    // MORE 데이 알림 숨김 → 해당 회원 MORE 데이 알림 다시 안 보기
    return [
      alert.memberId,
      alert.type.name,
    ].join('|');
  }

  String get _dismissedPrefsKey {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');

    return 'dashboard_dismissed_alerts_v2_$y-$m-$d';
  }

  Future<void> _loadDismissedAlertsForToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getStringList(_dismissedPrefsKey) ?? const <String>[];

      if (!mounted) return;

      setState(() {
        _dismissedAlertKeys
          ..clear()
          ..addAll(keys);
      });
    } catch (_) {}
  }

  Future<void> _loadPermanentlyHiddenAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getStringList(_permanentHiddenPrefsKey) ?? const <String>[];

      if (!mounted) return;

      setState(() {
        _permanentlyHiddenAlertKeys
          ..clear()
          ..addAll(keys);
      });
    } catch (_) {}
  }

  Future<void> _savePermanentlyHiddenAlerts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _permanentHiddenPrefsKey,
        _permanentlyHiddenAlertKeys.toList(),
      );
    } catch (_) {}
  }

  Future<void> _saveDismissedAlertsForToday() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _dismissedPrefsKey,
        _dismissedAlertKeys.toList(),
      );
    } catch (_) {}
  }

  bool _showScrollHint = false;
  bool _isNearBottom = false;

  String _alertKey(DashboardAlert alert, int i) => _stableAlertKey(alert);

  @override
  Widget build(BuildContext context) {
    final indexed = widget.data.alerts.asMap().entries.toList();

    final remaining = indexed.where((e) {
      final alert = e.value;

      final todayKey = _alertKey(alert, e.key);
      final permanentKey = _permanentAlertKey(alert);

      return !_dismissedAlertKeys.contains(todayKey) &&
          !_permanentlyHiddenAlertKeys.contains(permanentKey);
    }).toList();

    final hasAlerts = remaining.isNotEmpty;

    const double emptyHeight = 104;
    const double tileEstimatedHeight = 52;
    const double separatorHeight = 8;
    const int maxVisibleCount = 5;

    final visibleHeightCount = remaining.length.clamp(1, maxVisibleCount);

    final double overlayHeight = hasAlerts
        ? (visibleHeightCount * tileEstimatedHeight) +
            ((visibleHeightCount - 1) * separatorHeight)
        : emptyHeight;

    return SizedBox(
      height: overlayHeight,
      child: !hasAlerts
          ? const _EmptyAiFcAlertCard()
          : ListView.separated(
              controller: _alertScrollController,
              padding: EdgeInsets.zero,
              physics: remaining.length > maxVisibleCount
                  ? const BouncingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              itemCount: remaining.length,
              separatorBuilder: (_, __) => const SizedBox(
                height: separatorHeight,
              ),
              itemBuilder: (context, i) {
                final entry = remaining[i];
                final alert = entry.value;
                final key = _alertKey(alert, entry.key);

                return Dismissible(
                  key: ValueKey(key),
                  direction: DismissDirection.horizontal,
                  dismissThresholds: const {
                    DismissDirection.startToEnd: 0.28,
                    DismissDirection.endToStart: 0.22,
                  },

                  // 왼쪽 → 오른쪽 : 영구 숨김
                  background: const _OverlayDismissBackground(
                    alignment: Alignment.centerLeft,
                    icon: Icons.delete_forever_rounded,
                    label: '다시 안 보기',
                    backgroundColor: Color(0xFFDC2626),
                  ),

                  // 오른쪽 → 왼쪽 : 오늘 하루 숨김
                  secondaryBackground: const _OverlayDismissBackground(
                    alignment: Alignment.centerRight,
                    icon: Icons.delete_sweep_rounded,
                    label: '오늘 숨김',
                    backgroundColor: Color(0xFF2563EB),
                  ),

                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      HapticFeedback.mediumImpact();
                      return _confirmHideAlertPermanently(alert);
                    }

                    HapticFeedback.lightImpact();
                    return true;
                  },

                  onDismissed: (direction) {
                    if (direction == DismissDirection.startToEnd) {
                      _hideAlertPermanentlyDirect(alert);
                      return;
                    }

                    _dismissAlert(key, alert);
                  },

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
    );
  }

  @override
  void initState() {
    super.initState();

    _loadDismissedAlertsForToday();
    _loadPermanentlyHiddenAlerts();

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

    _saveDismissedAlertsForToday();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateScrollHintState();
    });
  }

  void _restorePermanentAlert(String key) {
    setState(() {
      _permanentlyHiddenAlertKeys.remove(key);
    });

    _savePermanentlyHiddenAlerts();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateScrollHintState();
    });
  }

  Future<bool> _confirmHideAlertPermanently(DashboardAlert alert) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          title: const Text(
            '이 알림을 다시 안 볼까요?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          content: Text(
            '${aifcPersonLabel(alert.customerName)} ${alert.label}\n\n'
            '앞으로 같은 종류의 알림은 헤더에서 제외할게요.\n'
            '회원 정보나 실제 기록은 삭제되지 않습니다.',
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text(
                '취소',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                '다시 안 보기',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  void _hideAlertPermanentlyDirect(DashboardAlert alert) {
    final key = _permanentAlertKey(alert);

    setState(() {
      _permanentlyHiddenAlertKeys.add(key);
    });

    _savePermanentlyHiddenAlerts();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _updateScrollHintState();
    });

    AifcInteraction.undoSnack(
      context: context,
      message: '${aifcPersonLabel(alert.customerName)} 알림을 다시 안 보도록 설정했어요.',
      actionLabel: '되돌리기',
      onAction: () => _restorePermanentAlert(key),
    );
  }
}

class _HeaderSlideOverlay extends StatefulWidget {
  const _HeaderSlideOverlay({
    required this.data,
    required this.onClose,
    required this.onAlertTap,
  });

  final DashboardHeaderData data;
  final VoidCallback onClose;
  final void Function(String memberId)? onAlertTap;

  @override
  State<_HeaderSlideOverlay> createState() => _HeaderSlideOverlayState();
}

class _OverlayDismissBackground extends StatelessWidget {
  const _OverlayDismissBackground({
    required this.alignment,
    required this.icon,
    required this.label,
    required this.backgroundColor,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bool isLeft = alignment == Alignment.centerLeft;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      alignment: alignment,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (isLeft) ...[
            Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ] else ...[
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 7),
            Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ],
        ],
      ),
    );
  }
}

class _AlertFcAvatar extends StatefulWidget {
  const _AlertFcAvatar({required this.type});

  final AlertType type;

  @override
  State<_AlertFcAvatar> createState() => _AlertFcAvatarState();
}

class _AlertFcAvatarState extends State<_AlertFcAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ringColors = kAlertRingColors[widget.type] ??
        kAlertRingColors[AlertType.attentionNeeded]!;
    final badgeColor =
        kAlertBadgeColors[widget.type] ?? const Color(0xFF4F46E5);
    final icon = kAlertIcons[widget.type] ?? Icons.info_outline_rounded;

    const double size = 28.0;
    const double outerSize = size + 6;

    return SizedBox(
      width: outerSize,
      height: outerSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, child) {
              return Transform.rotate(
                angle: _ctrl.value * 2 * math.pi,
                child: child,
              );
            },
            child: Container(
              width: outerSize,
              height: outerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: ringColors),
              ),
            ),
          ),
          Center(
            child: Container(
              width: size + 2,
              height: size + 2,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.94),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Center(
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [ringColors[1], ringColors[0]],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Text(
                'FC',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: badgeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Icon(
                icon,
                size: 7,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAiFcAlertCard extends StatelessWidget {
  const _EmptyAiFcAlertCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(14),
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
          width: 0.6,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AifcAvatar(
            size: 34,
            isAnimating: true,
            backgroundColor: Colors.white,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '평온~ 지금 바로 챙겨야 할 회원님은 없어요.\n필요한 체크포인트가 생기면 제가 알려드릴게요.',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 12.5,
                height: 1.42,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayAlertTileBlue extends StatelessWidget {
  const _OverlayAlertTileBlue({required this.alert});

  final DashboardAlert alert;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        kAlertBorderColors[alert.type] ?? const Color(0xFF4F46E5);
    final chipBg = kAlertChipBgColors[alert.type] ?? const Color(0xFFEEF2FF);
    final chipText =
        kAlertChipTextColors[alert.type] ?? const Color(0xFF4F46E5);
    final chipLabel = kAlertChipLabels[alert.type] ?? '';
    final bool isTodayAlert = alert.daysLeft == 0;

    final Color tileBg = isTodayAlert
        ? Color.alphaBlend(
            borderColor.withValues(alpha: 0.13),
            Colors.white,
          )
        : Colors.white.withValues(alpha: 0.94);

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(12),
        bottomLeft: Radius.circular(12),
        bottomRight: Radius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: tileBg,
          border: Border(
            left: BorderSide(
              color: borderColor,
              width: isTodayAlert ? 4.0 : 2.5,
            ),
            top: BorderSide(
              color: isTodayAlert
                  ? borderColor.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.50),
              width: 0.7,
            ),
            right: BorderSide(
              color: isTodayAlert
                  ? borderColor.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.50),
              width: 0.7,
            ),
            bottom: BorderSide(
              color: isTodayAlert
                  ? borderColor.withValues(alpha: 0.16)
                  : Colors.white.withValues(alpha: 0.50),
              width: 0.7,
            ),
          ),
          boxShadow: isTodayAlert
              ? [
                  BoxShadow(
                    color: borderColor.withValues(alpha: 0.18),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
              child: Row(
                children: [
                  _AlertFcAvatar(type: alert.type),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '${aifcPersonLabel(alert.customerName)} ${alert.label}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.2,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (alert.daysLeft != null) ...[
                    Text(
                      _dDayText(alert.daysLeft!),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (chipLabel.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: chipBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        chipLabel,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: chipText,
                        ),
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

class _HeaderFlatIconButton extends StatelessWidget {
  const _HeaderFlatIconButton({
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: SizedBox(
          width: 34,
          height: 40,
          child: Icon(
            icon,
            size: 23,
            color:
                isActive ? Colors.white : Colors.white.withValues(alpha: 0.72),
          ),
        ),
      ),
    );
  }
}

class _CareGuideItem extends StatelessWidget {
  const _CareGuideItem({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AifcColors.cardBorder),
        boxShadow: AifcShadow.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AifcColors.text,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AifcColors.textMuted,
                    height: 1.35,
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

class _HeaderMenuItem extends StatelessWidget {
  const _HeaderMenuItem({
    required this.icon,
    required this.label,
    required this.isSelected,
  });

  final IconData icon;
  final String label;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final color =
        isSelected ? const Color(0xFF5B4BDB) : const Color(0xFF4B5563);

    return Row(
      children: [
        Icon(
          icon,
          size: 17,
          color: color,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
              color: isSelected
                  ? const Color(0xFF5B4BDB)
                  : const Color(0xFF111827),
            ),
          ),
        ),
        if (isSelected)
          const Icon(
            Icons.check_rounded,
            size: 16,
            color: Color(0xFF5B4BDB),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.isSelected = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;

  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      height: 76,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isSelected ? 0.24 : 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: isSelected ? 0.48 : 0.0),
          width: isSelected ? 1.2 : 0,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
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

    if (onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: card,
      ),
    );
  }
}

class _SearchAndFilterCard extends StatelessWidget {
  const _SearchAndFilterCard({
    required this.controller,
    required this.selectedLessonDate,
    required this.membershipFilter,
    required this.sortOption,
    required this.sortAscending,
    required this.onSearchChanged,
    required this.onMenuSelected,
    required this.onToggleSortDirection,
  });

  final TextEditingController controller;
  final DateTime? selectedLessonDate;
  final _MembershipListFilter? membershipFilter;
  final SortOption sortOption;
  final bool sortAscending;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_SearchMenuAction> onMenuSelected;
  final VoidCallback onToggleSortDirection;

  @override
  Widget build(BuildContext context) {
    final bool hasDateFilter = selectedLessonDate != null;
    final bool hasMembershipFilter = membershipFilter != null;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: tokens.memberListCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tokens.memberListCardBorder),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
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
                    ? '이름/전화번호/그룹명 검색 · ${_formatDate(selectedLessonDate!)}'
                    : hasMembershipFilter
                        ? '${_membershipListFilterLabel(membershipFilter!)} · 이름/전화번호/그룹명 검색'
                        : '이름/전화번호/그룹명 검색',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
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
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tokens.memberListCardBorder),
              ),
              child: Icon(
                sortAscending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<_SearchMenuAction>(
            onSelected: onMenuSelected,
            tooltip: '검색 옵션',
            color: tokens.navigationSheetBackground,
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
                child: Text('정렬 · 레슨 만료 임박순'),
              ),
              const PopupMenuItem(
                value: _SearchMenuAction.sortRecentLesson,
                child: Text('정렬 · 최근이용순'),
              ),
              const PopupMenuItem(
                value: _SearchMenuAction.sortRecentRegistration,
                child: Text('정렬 · 최근등록순'),
              ),
              PopupMenuItem(
                value: _SearchMenuAction.sortGroup,
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 18,
                      color: sortOption == SortOption.group
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '그룹순',
                      style: TextStyle(
                        fontWeight: sortOption == SortOption.group
                            ? FontWeight.w900
                            : FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _SearchMenuAction.pickLessonDate,
                child: Text('레슨일 선택'),
              ),
              if (hasDateFilter)
                const PopupMenuItem(
                  value: _SearchMenuAction.clearLessonDate,
                  child: Text('레슨일 해제'),
                ),
              const PopupMenuDivider(),
              PopupMenuItem<_SearchMenuAction>(
                enabled: false,
                child: Text(
                  '회원권',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const PopupMenuItem(
                value: _SearchMenuAction.membershipNeedsCheck,
                child: Text('회원권 체크'),
              ),
              if (hasMembershipFilter)
                const PopupMenuItem(
                  value: _SearchMenuAction.clearMembershipFilter,
                  child: Text('회원권 필터 해제'),
                ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: hasDateFilter
                    ? tokens.memberListSelected
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tokens.memberListCardBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.more_horiz_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    hasMembershipFilter
                        ? _membershipListFilterLabel(membershipFilter!)
                        : _sortLabel(sortOption),
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
        return '최근 레슨';
      case SortOption.recentRegistration:
        return '최근등록';
      case SortOption.group:
        return '그룹순';
    }
  }
}

class _GroupFilterChipRow extends StatelessWidget {
  const _GroupFilterChipRow({
    required this.items,
    required this.selectedGroupId,
    required this.accentColorForGroupId,
    required this.textColorForGroupId,
    required this.onSelected,
    required this.onSettingsTap,
  });

  final List<_MemberCardGroupMenuItem> items;
  final String? selectedGroupId;
  final Color Function(String groupId) accentColorForGroupId;
  final Color Function(String groupId) textColorForGroupId;
  final ValueChanged<String> onSelected;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      ...items.map((item) {
        final bool isSelected = item.id == _MemberDashboardPageState._allGroupId
            ? selectedGroupId == null
            : selectedGroupId == item.id;

        return Padding(
          padding: const EdgeInsets.only(right: 7),
          child: _GroupFilterChip(
            label: item.label,
            icon: item.icon,
            isSelected: isSelected,
            selectedBgColor: accentColorForGroupId(item.id),
            selectedTextColor: textColorForGroupId(item.id),
            onTap: () => onSelected(item.id),
          ),
        );
      }),
      _GroupFilterChip(
        icon: Icons.settings_rounded,
        isSelected: false,
        selectedBgColor: const Color(0xFF5B4BDB),
        selectedTextColor: Colors.white,
        onTap: onSettingsTap,
      ),
    ];

    return SizedBox(
      height: 32,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(children: chips),
      ),
    );
  }
}

class _GroupFilterChip extends StatelessWidget {
  const _GroupFilterChip({
    this.label,
    required this.icon,
    required this.isSelected,
    required this.selectedBgColor,
    required this.selectedTextColor,
    required this.onTap,
  });

  final String? label;
  final IconData icon;
  final bool isSelected;
  final Color selectedBgColor;
  final Color selectedTextColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    final Color bgColor =
        isSelected ? tokens.memberListSelected : tokens.memberListCard;
    final Color fgColor =
        isSelected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          height: 32,
          padding: EdgeInsets.symmetric(
            horizontal: label == null ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isSelected ? selectedBgColor : tokens.memberListCardBorder,
              width: isSelected ? 1.2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.06),
                blurRadius: 7,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: fgColor,
              ),
              if (label != null) ...[
                const SizedBox(width: 5),
                Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: fgColor,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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

class _GroupManagementSheet extends StatefulWidget {
  const _GroupManagementSheet({
    required this.groupIds,
    required this.systemGroupIds,
    required this.ungroupedGroupId,
    required this.groupNames,
    required this.onCreateGroup,
    required this.onRenameGroup,
    required this.onDeleteGroup,
    required this.onReorderGroups,
  });

  final List<String> groupIds;
  final List<String> systemGroupIds;
  final String ungroupedGroupId;
  final Map<String, String> groupNames;
  final Future<void> Function() onCreateGroup;
  final Future<void> Function(String groupId) onRenameGroup;
  final Future<void> Function(String groupId) onDeleteGroup;
  final Future<void> Function(List<String> orderedGroupIds) onReorderGroups;

  @override
  State<_GroupManagementSheet> createState() => _GroupManagementSheetState();
}

class _GroupManagementSheetState extends State<_GroupManagementSheet> {
  _GroupManagementMode _mode = _GroupManagementMode.root;
  late List<String> _workingOrder;

  @override
  void initState() {
    super.initState();
    _workingOrder = List<String>.from(widget.groupIds);
  }

  List<String> get _allGroupIds => <String>[
        widget.ungroupedGroupId,
        ...widget.groupIds,
        _MemberDashboardPageState._systemDormantGroupId,
        _MemberDashboardPageState._systemExpiredGroupId,
      ];

  List<String> get _deletableGroupIds => widget.groupIds
      .where((groupId) =>
          groupId != widget.ungroupedGroupId &&
          !widget.systemGroupIds.contains(groupId))
      .toList();

  String _labelOf(String groupId) {
    final label = (widget.groupNames[groupId] ?? '').trim();
    if (label.isNotEmpty) return label;
    if (groupId == widget.ungroupedGroupId) return 'MORE THAN GYM';
    if (groupId == _MemberDashboardPageState._systemDormantGroupId) {
      return '휴면회원';
    }
    if (groupId == _MemberDashboardPageState._systemExpiredGroupId) {
      return '만료회원';
    }
    return groupId;
  }

  void _closeThen(Future<void> Function() action) {
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      action();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AifcSheetFrame(
      maxHeightFactor: 0.82,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AifcChatBubble(
                  side: AifcBubbleSide.fc,
                  text: _mode == _GroupManagementMode.root
                      ? '그룹을 어떻게 관리할까요?'
                      : _mode == _GroupManagementMode.order
                          ? '길게 눌러 그룹 순서를 바꿔주세요.'
                          : '어떤 그룹을 삭제할까요?',
                  child: _mode == _GroupManagementMode.root
                      ? _buildRootActions()
                      : _mode == _GroupManagementMode.order
                          ? _buildOrderEditor()
                          : _buildGroupPicker(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRootActions() {
    return Column(
      children: [
        _GroupManagementActionButton(
          icon: Icons.add_box_rounded,
          title: '새 그룹 추가',
          subtitle: '회원 분류를 새로 만들어요.',
          onTap: () => _closeThen(widget.onCreateGroup),
        ),
        const SizedBox(height: 8),
        _GroupManagementActionButton(
          icon: Icons.drive_file_rename_outline_rounded,
          title: '그룹 이름 변경',
          subtitle: '기본/고정 그룹도 표시 이름은 바꿀 수 있어요.',
          onTap: () {
            setState(() {
              _mode = _GroupManagementMode.rename;
            });
          },
        ),
        const SizedBox(height: 8),
        _GroupManagementActionButton(
          icon: Icons.swap_vert_rounded,
          title: '그룹 순서 변경',
          subtitle: '길게 누르면 필터 칩 순서를 바꿀 수 있어요.',
          onTap: () {
            setState(() {
              _workingOrder = List<String>.from(widget.groupIds);
              _mode = _GroupManagementMode.order;
            });
          },
        ),
        const SizedBox(height: 8),
        _GroupManagementActionButton(
          icon: Icons.delete_outline_rounded,
          title: '그룹 삭제',
          subtitle: '커스텀 그룹만 삭제할 수 있어요.',
          danger: true,
          onTap: () {
            setState(() {
              _mode = _GroupManagementMode.delete;
            });
          },
        ),
      ],
    );
  }

  Widget _buildOrderEditor() {
    if (widget.groupIds.length < 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '순서를 바꾸려면 커스텀 그룹이 2개 이상 필요해요.',
            style: AifcText.caption,
          ),
          const SizedBox(height: 10),
          _GroupManagementActionButton(
            icon: Icons.arrow_back_rounded,
            title: '관리 메뉴로 돌아가기',
            onTap: () {
              setState(() {
                _mode = _GroupManagementMode.root;
              });
            },
          ),
        ],
      );
    }

    final double listHeight =
        math.min(300.0, (_workingOrder.length * 58.0) + 8.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '커스텀 그룹만 순서를 바꿀 수 있어요.'
          '기본 그룹은 맨 앞, 휴면/만료 회원은 맨 뒤에 고정됩니다.',
          style: AifcText.caption,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: listHeight,
          child: ReorderableListView.builder(
            padding: EdgeInsets.zero,
            buildDefaultDragHandles: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _workingOrder.length,
            onReorder: (oldIndex, newIndex) {
              setState(() {
                if (newIndex > oldIndex) {
                  newIndex -= 1;
                }

                final movedId = _workingOrder.removeAt(oldIndex);
                _workingOrder.insert(newIndex, movedId);
              });
            },
            itemBuilder: (context, index) {
              final groupId = _workingOrder[index];

              return ReorderableDelayedDragStartListener(
                key: ValueKey('group_order_$groupId'),
                index: index,
                child: _GroupOrderTile(
                  index: index + 1,
                  label: _labelOf(groupId),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        _GroupManagementActionButton(
          icon: Icons.check_rounded,
          title: '이 순서로 저장',
          subtitle: '검색창 아래 그룹 순서에 반영돼요.',
          onTap: () => _closeThen(
            () => widget.onReorderGroups(_workingOrder),
          ),
        ),
        const SizedBox(height: 8),
        _GroupManagementActionButton(
          icon: Icons.arrow_back_rounded,
          title: '관리 메뉴로 돌아가기',
          onTap: () {
            setState(() {
              _workingOrder = List<String>.from(widget.groupIds);
              _mode = _GroupManagementMode.root;
            });
          },
        ),
      ],
    );
  }

  Widget _buildGroupPicker() {
    final ids = _mode == _GroupManagementMode.delete
        ? _deletableGroupIds
        : _allGroupIds;

    if (ids.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '삭제할 수 있는 커스텀 그룹이 아직 없어요.',
            style: AifcText.caption,
          ),
          const SizedBox(height: 10),
          _GroupManagementActionButton(
            icon: Icons.arrow_back_rounded,
            title: '관리 메뉴로 돌아가기',
            onTap: () {
              setState(() {
                _mode = _GroupManagementMode.root;
              });
            },
          ),
        ],
      );
    }

    return Column(
      children: [
        ...ids.map((groupId) {
          final bool isDelete = _mode == _GroupManagementMode.delete;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _GroupManagementActionButton(
              icon: isDelete
                  ? Icons.folder_delete_outlined
                  : Icons.folder_open_rounded,
              title: _labelOf(groupId),
              subtitle: isDelete ? '이 그룹을 삭제합니다.' : '이 그룹 이름을 변경합니다.',
              danger: isDelete,
              onTap: () => _closeThen(
                () => isDelete
                    ? widget.onDeleteGroup(groupId)
                    : widget.onRenameGroup(groupId),
              ),
            ),
          );
        }),
        _GroupManagementActionButton(
          icon: Icons.arrow_back_rounded,
          title: '관리 메뉴로 돌아가기',
          onTap: () {
            setState(() {
              _mode = _GroupManagementMode.root;
            });
          },
        ),
      ],
    );
  }
}

enum _GroupManagementMode {
  root,
  rename,
  order,
  delete,
}

class _GroupOrderTile extends StatelessWidget {
  const _GroupOrderTile({
    required this.index,
    required this.label,
  });

  final int index;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AifcColors.cardBorder),
        boxShadow: AifcShadow.soft,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AifcColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: AifcColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: AifcColors.text,
                letterSpacing: -0.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          const Icon(
            Icons.drag_handle_rounded,
            size: 20,
            color: AifcColors.textMuted,
          ),
        ],
      ),
    );
  }
}

class _GroupManagementActionButton extends StatelessWidget {
  const _GroupManagementActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AifcColors.danger : AifcColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: danger ? const Color(0xFFFECACA) : AifcColors.cardBorder,
            ),
            boxShadow: AifcShadow.soft,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: color,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: danger ? AifcColors.danger : AifcColors.text,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AifcColors.textMuted,
                          height: 1.28,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: color.withValues(alpha: 0.72),
              ),
            ],
          ),
        ),
      ),
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

Color _memberGroupMenuItemColor(BuildContext context, String groupId) {
  final colorScheme = Theme.of(context).colorScheme;
  if (Theme.of(context).brightness == Brightness.dark) {
    if (groupId == _MemberDashboardPageState._systemDormantGroupId) {
      return colorScheme.onSurfaceVariant;
    }
    if (groupId == _MemberDashboardPageState._systemExpiredGroupId) {
      return colorScheme.onSurface.withValues(alpha: 0.82);
    }
    return colorScheme.onSurface;
  }

  if (groupId == _MemberDashboardPageState._systemDormantGroupId) {
    return const Color(0xFF6B7280);
  }
  if (groupId == _MemberDashboardPageState._systemExpiredGroupId) {
    return const Color(0xFF374151);
  }
  return const Color(0xFF4B5563);
}

class MemberListRow extends StatelessWidget {
  const MemberListRow({
    super.key,
    required this.member,
    this.membershipMeta,
    this.displayName,
    required this.displayGroupLabel,
    required this.displayGroupAccentColor,
    required this.displayGroupTextColor,
    required this.groupMenuItems,
    required this.isPinned,
    required this.onPinTap,
    required this.onEditTap,
    required this.onLogTap,
    required this.onQuickGroupChanged,
    required this.onAnyInteraction,
  });

  final Member member;
  final _MemberMembershipMeta? membershipMeta;
  final String? displayName;
  final String displayGroupLabel;
  final Color displayGroupAccentColor;
  final Color displayGroupTextColor;
  final List<_MemberCardGroupMenuItem> groupMenuItems;
  final bool isPinned;
  final VoidCallback onPinTap;
  final VoidCallback onEditTap;
  final VoidCallback onLogTap;
  final ValueChanged<String> onQuickGroupChanged;
  final VoidCallback onAnyInteraction;

  String get _resolvedName {
    final name = displayName ?? member.name ?? '이름없음';
    final trimmed = name.trim();

    return trimmed.isEmpty ? '이름없음' : trimmed;
  }

  double get _groupLabelLetterSpacing {
    final label = displayGroupLabel.trim();

    final bool isMostlyEnglish = RegExp(r'^[A-Z0-9\s\-_]+$').hasMatch(label);

    if (isMostlyEnglish) {
      return 0.15;
    }

    return -0.1;
  }

  Color _statusBarColor(Member member) {
    if (_isExpiredMember(member)) return const Color(0xFF6B7280);
    if (_isDormantMember(member)) return const Color(0xFFD1D5DB);
    if (_isActiveMember(member) && member.remainingSessions < 5) {
      return const Color(0xFFEF4444);
    }
    return const Color(0xFF10B981);
  }

  String _statusLabel(Member member) {
    if (_isExpiredMember(member)) return '만료';
    if (_isDormantMember(member)) return '휴면';
    if (_isActiveMember(member) && member.remainingSessions < 5) {
      return '만료임박';
    }
    return '활성';
  }

  String _nextLessonInlineText() {
    if (member.nextLessonAt == null) return '다음 미정';
    return '다음 ${_formatDate(member.nextLessonAt!)}';
  }

  String _lastLessonText() {
    if (member.lastLogAt == null) return '레슨 기록 없음';
    return '최근 ${_formatDate(member.lastLogAt!)}';
  }

  String _sessionSummaryText() {
    final total = member.totalSessions;
    final remain = member.remainingSessions;
    final dDaySuffix = _membershipExpiryDDaySuffix(member);
    final expiryText = dDaySuffix == null ? '' : ' · $dDaySuffix';

    if (total <= 0 && remain <= 0) {
      return '회차 미등록$expiryText';
    }

    return '총 ${total}회 / ${remain}회 남음$expiryText';
  }

  List<_IssueChipData> _membershipIssueChips() {
    final items = <_IssueChipData>[];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final expireAt = member.expireAt ?? membershipMeta?.endAt;
    final expireDate = expireAt == null
        ? null
        : DateTime(expireAt.year, expireAt.month, expireAt.day);

    int? daysLeft;
    if (expireDate != null) {
      daysLeft = expireDate.difference(today).inDays;
    }

    final bool membershipPaused = membershipMeta?.isPaused == true;

    if (membershipPaused) {
      items.add(
        const _IssueChipData(
          label: '정지중',
          bgColor: Color(0xFFF3F4F6),
          textColor: Color(0xFF4B5563),
        ),
      );
    }

    if (_isActiveMember(member) &&
        member.totalSessions > 0 &&
        member.remainingSessions >= 0 &&
        member.remainingSessions <= 3) {
      items.add(
        _IssueChipData(
          label: '잔여 ${member.remainingSessions}회',
          bgColor: const Color(0xFFFAEEDA),
          textColor: const Color(0xFFBA7517),
        ),
      );
    }

    if (daysLeft != null) {
      if (daysLeft < 0) {
        items.add(
          const _IssueChipData(
            label: '회원권 만료',
            bgColor: Color(0xFFFEF2F2),
            textColor: Color(0xFFDC2626),
          ),
        );
      } else if (daysLeft <= 30) {
        final bool urgent = daysLeft <= 10;

        items.add(
          _IssueChipData(
            label: daysLeft == 0 ? '회원권 오늘' : '회원권 D-$daysLeft',
            bgColor: urgent ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
            textColor:
                urgent ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
          ),
        );
      }
    }

    final termLabel = membershipMeta?.termLabel;
    if (termLabel != null && items.isNotEmpty) {
      items.add(
        _IssueChipData(
          label: termLabel,
          bgColor: const Color(0xFFF5F3FF),
          textColor: const Color(0xFF6D28D9),
        ),
      );
    }

    if (membershipMeta?.needsContractSignature == true) {
      items.add(
        const _IssueChipData(
          label: '계약서 미서명',
          bgColor: Color(0xFFFFF7ED),
          textColor: Color(0xFFC2410C),
        ),
      );
    }

    return items;
  }

  List<_IssueChipData> _listEventChips() {
    final now = DateTime.now();
    final items = <_IssueChipData>[
      ..._membershipIssueChips(),
    ];

    if (!_isActiveMember(member)) {
      return items.take(2).toList();
    }

    final birthdayDaysLeft = _daysUntilNextMonthDay(member.birthDate, now);

    if (birthdayDaysLeft != null &&
        birthdayDaysLeft >= 0 &&
        birthdayDaysLeft <= 7) {
      items.add(
        _IssueChipData(
          label: birthdayDaysLeft == 0
              ? '🎂 D-DAY'
              : '🎂 ${_dDayText(birthdayDaysLeft)}',
          bgColor: const Color(0xFFFBEAF0),
          textColor: const Color(0xFF993556),
        ),
      );
    }

    final anniversaryDaysLeft =
        _daysUntilNextMonthDay(member.anniversaryDate, now);

    if (anniversaryDaysLeft != null &&
        anniversaryDaysLeft >= 0 &&
        anniversaryDaysLeft <= 14) {
      final label = (member.anniversaryLabel ?? '').trim().isEmpty
          ? 'Focus'
          : member.anniversaryLabel!.trim();

      items.add(
        _IssueChipData(
          label: anniversaryDaysLeft == 0
              ? '$label D-DAY'
              : '$label ${_dDayText(anniversaryDaysLeft)}',
          bgColor: const Color(0xFFE6F1FB),
          textColor: const Color(0xFF185FA5),
        ),
      );
    }

    final femaleConditionDaysLeft = _femaleConditionDaysLeft(member, now);

    if (femaleConditionDaysLeft != null &&
        femaleConditionDaysLeft >= -2 &&
        femaleConditionDaysLeft <= 3) {
      items.add(
        _IssueChipData(
          label: '여성컨디션 체크 ${_conditionDdayText(femaleConditionDaysLeft)}',
          bgColor: const Color(0xFFEAF3DE),
          textColor: const Color(0xFF3B6D11),
        ),
      );
    }

    final nextMoreDayDaysLeft = member.nextMoreDayAt == null
        ? null
        : _daysBetween(now, member.nextMoreDayAt!);

    if (nextMoreDayDaysLeft != null &&
        nextMoreDayDaysLeft >= -7 &&
        nextMoreDayDaysLeft <= 14) {
      final label = (member.nextMoreDayLabel ?? '').trim().isEmpty
          ? 'D-DAY'
          : member.nextMoreDayLabel!.trim();

      items.add(
        _IssueChipData(
          label: '$label ${_dDayText(nextMoreDayDaysLeft)}',
          bgColor: const Color(0xFFF3E8FF),
          textColor: const Color(0xFF6D28D9),
        ),
      );
    }

    final total = member.totalSessions <= 0 ? 0 : member.totalSessions;
    final used =
        total <= 0 ? 0 : (total - member.remainingSessions).clamp(0, total);

    final baseDate = member.recentReg ?? member.firstDate;
    final firstLessonDays =
        baseDate == null ? null : _daysBetween(baseDate, now);

    if (firstLessonDays != null &&
        firstLessonDays >= 93 &&
        firstLessonDays <= 103) {
      items.add(
        _IssueChipData(
          label: firstLessonDays == 100
              ? '100일'
              : firstLessonDays < 100
                  ? '100일 D-${100 - firstLessonDays}'
                  : '100일 D+${firstLessonDays - 100}',
          bgColor: const Color(0xFFE6F1FB),
          textColor: const Color(0xFF185FA5),
        ),
      );
    }

    if (used >= 93 && used <= 100) {
      items.add(
        _IssueChipData(
          label: used == 100 ? '100회' : '100회까지 ${100 - used}회',
          bgColor: const Color(0xFFE6F1FB),
          textColor: const Color(0xFF185FA5),
        ),
      );
    }

    return items.take(2).toList();
  }

  Color _sessionSummaryTextColor(BuildContext context) {
    return _isMembershipExpiryWithinDays(member, 10)
        ? const Color(0xFFEF4444)
        : Theme.of(context).colorScheme.onSurfaceVariant;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusBarColor(member);
    final eventChips = _listEventChips();
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;

    return Container(
      height: 114,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: tokens.memberListCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tokens.memberListCardBorder),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            onAnyInteraction();
            onEditTap();
          },
          child: Row(
            children: [
              Container(
                width: 4,
                height: double.infinity,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 8, 8, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: 22,
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _resolvedName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14.8,
                                        fontWeight: FontWeight.w900,
                                        color: scheme.onSurface,
                                        letterSpacing: -0.2,
                                        height: 1.0,
                                      ),
                                    ),
                                  ),
                                  if (eventChips.isNotEmpty) ...[
                                    const SizedBox(width: 6),
                                    ...eventChips.map((chip) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(right: 4),
                                        child: _TinyIssueChip(data: chip),
                                      );
                                    }),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _nextLessonInlineText(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.8,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 4),
                            InkWell(
                              onTap: () {
                                onAnyInteraction();
                                onPinTap();
                              },
                              borderRadius: BorderRadius.circular(999),
                              child: Padding(
                                padding: const EdgeInsets.all(5),
                                child: Icon(
                                  isPinned
                                      ? Icons.push_pin
                                      : Icons.push_pin_outlined,
                                  size: 18,
                                  color: isPinned
                                      ? const Color(0xFFE06A5F)
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _sessionSummaryText(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.4,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                                color: _sessionSummaryTextColor(context),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _lastLessonText(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 11.2,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          PopupMenuButton<String>(
                            onSelected: onQuickGroupChanged,
                            color: tokens.navigationSheetBackground,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            itemBuilder: (context) {
                              return groupMenuItems.map((item) {
                                final itemColor = _memberGroupMenuItemColor(
                                  context,
                                  item.id,
                                );

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
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 150),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: displayGroupAccentColor.withValues(
                                    alpha: 0.36),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                displayGroupLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w900,
                                  color: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? scheme.onSurface
                                      : displayGroupTextColor,
                                  letterSpacing: _groupLabelLetterSpacing,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            onTap: () {
                              onAnyInteraction();
                              onLogTap();
                            },
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              height: 30,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 11),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F3FF),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: const Color(0xFFE9D5FF),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_note_rounded,
                                    size: 16,
                                    color: Color(0xFF6D28D9),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '레슨일지',
                                    style: TextStyle(
                                      fontSize: 11.2,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF6D28D9),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MemberSimpleCard extends StatelessWidget {
  const MemberSimpleCard({
    super.key,
    required this.member,
    this.displayName,
    required this.trainerNameSourceText,
    required this.onContractTap,
    required this.onEditTap,
    required this.onLogTap,
    required this.onPinTap,
    required this.isPinned,
    required this.onSetExpired,
    required this.onSetDormant,
    required this.onSetActive,
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
  final String? displayName;
  final String trainerNameSourceText;
  final String? groupLabel;
  final VoidCallback onContractTap;
  final VoidCallback onEditTap;
  final VoidCallback onLogTap;
  final VoidCallback onPinTap;
  final bool isPinned;
  final VoidCallback onSetExpired;
  final VoidCallback onSetDormant;
  final VoidCallback onSetActive;
  final VoidCallback onAnyInteraction;
  final ValueListenable<String?> highlightListenable;
  final String displayGroupLabel;
  final Color displayGroupAccentColor;
  final Color displayGroupTextColor;
  final List<_MemberCardGroupMenuItem> groupMenuItems;
  final ValueChanged<String> onQuickGroupChanged;

  String get _resolvedName {
    final name = displayName ?? member.name ?? '이름없음';
    final trimmed = name.trim();

    return trimmed.isEmpty ? '이름없음' : trimmed;
  }

  double get _groupLabelLetterSpacing {
    final label = displayGroupLabel.trim();

    final bool isMostlyEnglish = RegExp(r'^[A-Z0-9\s\-_]+$').hasMatch(label);

    if (isMostlyEnglish) {
      return 0.15;
    }

    return -0.1;
  }

  @override
  Widget build(BuildContext context) {
    final chips = _buildIssueChips(member);
    final visibleChips = chips.take(2).toList();
    final hiddenChipCount = chips.length - visibleChips.length;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = context.mtfThemeTokens;
    final isDark = theme.brightness == Brightness.dark;

    void handleCardTap() {
      onAnyInteraction();
    }

    final Widget baseCard = RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isDark ? tokens.memberListCard : _cardBackgroundColor(member),
          border: Border.all(
            color:
                isDark ? tokens.memberListCardBorder : _cardBorderColor(member),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? scheme.shadow.withValues(alpha: 0.18)
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
                      const SizedBox.shrink(),
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            onAnyInteraction();
                            _showMemberInfoOverlay(context, chips);
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
                                : tokens.cardSurface,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isPinned
                                  ? const Color(0xFFF2B2A6)
                                  : tokens.memberListCardBorder,
                            ),
                          ),
                          child: Icon(
                            isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                            size: 18,
                            color: isPinned
                                ? const Color(0xFFE06A5F)
                                : scheme.onSurfaceVariant,
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
                                    _resolvedName,
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: scheme.onSurface,
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
                                        color: tokens.cardSurface,
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        '레슨만료예정 ${member.remainingSessions}회',
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
                              label: '회원카드',
                              icon: Icons.badge_outlined,
                              onTap: () {
                                onAnyInteraction();
                                onEditTap();
                              },
                            ),
                            const SizedBox(height: 8),
                            _SideQuickButton(
                              label: '레슨일지',
                              icon: Icons.edit_note_rounded,
                              onTap: () {
                                onAnyInteraction();
                                onLogTap();
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
                color: scheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(22),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                enabled: true,
                onSelected: onQuickGroupChanged,
                color: tokens.navigationSheetBackground,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                offset: const Offset(0, -8),
                itemBuilder: (context) {
                  return groupMenuItems.map((item) {
                    final itemColor = _memberGroupMenuItemColor(
                      context,
                      item.id,
                    );

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
                      letterSpacing: _groupLabelLetterSpacing,
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
      onLongPress: () {
        onAnyInteraction();
        _showMemberLongPressSheet(context);
      },
      child: highlightedCard,
    );

    return card;
  }

  void _showMemberInfoOverlay(BuildContext context, List<Widget> chips) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        final tokens = ctx.mtfThemeTokens;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Container(
            decoration: BoxDecoration(
              color: tokens.dialogBackground,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.18),
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
                            _resolvedName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: scheme.onSurface,
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
                              const _EmptyInfoChip(label: '표시할 활동상태 정보 없음'),
                            ]
                          : chips,
                    ),
                    const SizedBox(height: 18),
                    _OverlayInfoRow(
                      label: '회원 활동상태',
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
                          : '레슨기록 없음',
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
                            label: '레슨일지',
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

  Future<void> _showMemberLongPressSheet(BuildContext context) async {
    final options = <AifcOptionItem<String>>[
      if (!_isExpiredMember(member))
        const AifcOptionItem<String>(
          value: 'expired',
          title: '만료회원으로 전환',
          subtitle: '수강권이 끝난 회원으로 분류합니다.',
          icon: Icons.school_outlined,
        ),
      if (!_isDormantMember(member))
        const AifcOptionItem<String>(
          value: 'dormant',
          title: '휴면회원으로 전환',
          subtitle: '잠시 쉬는 회원으로 따로 관리합니다.',
          icon: Icons.bedtime_outlined,
        ),
      if (!_isActiveMember(member))
        const AifcOptionItem<String>(
          value: 'active',
          title: '활성회원으로 전환',
          subtitle: '다시 관리 대상에 보이도록 돌립니다.',
          icon: Icons.autorenew_rounded,
        ),
    ];

    if (options.isEmpty) return;

    final result = await AifcOptionChatSheet.show<String>(
      context: context,
      nickname:
          trainerNameSourceText.trim().isEmpty ? '강사' : trainerNameSourceText,
      title: '${aifcPersonLabel(_resolvedName)} 관리 옵션',
      message: '회원 활동 상태를 변경할 수 있습니다.\n'
          '상태 변경은 회원 목록의 분류와 표시 방식에 반영됩니다.',
      selectedValue: null,
      closeText: '닫기',
      items: options,
      pickedReplyText: (item) {
        switch (item.value) {
          case 'expired':
            return '확인되었습니다. 만료회원으로 전환합니다.';
          case 'dormant':
            return '확인되었습니다. 휴면회원으로 전환합니다.';
          case 'active':
            return '확인되었습니다. 활성회원으로 전환합니다.';
          default:
            return '확인되었습니다.';
        }
      },
    );

    if (result == null) return;

    onAnyInteraction();

    switch (result) {
      case 'expired':
        onSetExpired();
        break;
      case 'dormant':
        onSetDormant();
        break;
      case 'active':
        onSetActive();
        break;
    }
  }

  List<Widget> _buildIssueChips(Member member) {
    if (!_isActiveMember(member)) {
      return [];
    }

    final List<_IssueChipData> items = [];

    final now = DateTime.now();

    final birthDaysLeft = _daysUntilNextMonthDay(member.birthDate, now);
    if (birthDaysLeft != null && birthDaysLeft >= 0 && birthDaysLeft <= 7) {
      items.add(
        _IssueChipData(
          label:
              birthDaysLeft == 0 ? '오늘 생일' : '생일 ${_dDayText(birthDaysLeft)}',
          bgColor: const Color(0xFFFBEAF0),
          textColor: const Color(0xFF993556),
        ),
      );
    }

    final anniversaryDaysLeft =
        _daysUntilNextMonthDay(member.anniversaryDate, now);
    if (anniversaryDaysLeft != null &&
        anniversaryDaysLeft >= 0 &&
        anniversaryDaysLeft <= 14) {
      final label = (member.anniversaryLabel ?? '').trim().isEmpty
          ? 'Focus Day'
          : member.anniversaryLabel!.trim();

      items.add(
        _IssueChipData(
          label: anniversaryDaysLeft == 0
              ? '$label 오늘'
              : '$label ${_dDayText(anniversaryDaysLeft)}',
          bgColor: const Color(0xFFE6F1FB),
          textColor: const Color(0xFF185FA5),
        ),
      );
    }

    final total = member.totalSessions <= 0 ? 0 : member.totalSessions;
    final used =
        total <= 0 ? 0 : (total - member.remainingSessions).clamp(0, total);

    final baseDate = member.recentReg ?? member.firstDate;
    final firstLessonDays =
        baseDate == null ? null : _daysBetween(baseDate, now);

    if (firstLessonDays != null &&
        firstLessonDays >= 93 &&
        firstLessonDays <= 103) {
      items.add(
        _IssueChipData(
          label: firstLessonDays == 100
              ? '레슨 시작 100일'
              : firstLessonDays < 100
                  ? '100일 D-${100 - firstLessonDays}'
                  : '100일 D+${firstLessonDays - 100}',
          bgColor: const Color(0xFFE6F1FB),
          textColor: const Color(0xFF185FA5),
        ),
      );
    }

    if (used >= 93 && used <= 100) {
      items.add(
        _IssueChipData(
          label: used == 100 ? '누적 100회 레슨' : '100회까지 ${100 - used}회',
          bgColor: const Color(0xFFE6F1FB),
          textColor: const Color(0xFF185FA5),
        ),
      );
    }

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

    final dDaySuffix = _membershipExpiryDDaySuffix(member);
    if (member.expireAt != null && dDaySuffix != null) {
      final bool isExpirySoon = _isMembershipExpiryWithinDays(member, 10);

      items.add(
        _IssueChipData(
          label: '만료일 ${_formatDate(member.expireAt!)} · $dDaySuffix',
          bgColor:
              isExpirySoon ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
          textColor:
              isExpirySoon ? const Color(0xFFEF4444) : const Color(0xFF2563EB),
        ),
      );
    }

    return items.map((e) => _IssueChip(data: e)).toList();
  }
}

class _MoreChip extends StatelessWidget {
  const _MoreChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tokens.cardSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tokens.cardBorder),
      ),
      child: Text(
        '+$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: scheme.onSurface,
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
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: double.infinity,
          height: 36,
          decoration: BoxDecoration(
            color: tokens.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: tokens.cardBorder,
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
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.onSurface,
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
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: scheme.onSurface,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.2,
              color: scheme.onSurface,
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: scheme.onSurface,
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
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
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
    final int totalSessions =
        member.totalSessions <= 0 ? 20 : member.totalSessions;
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
                                    final double translateX =
                                        width * sheenValue;

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
                                                  Colors.white
                                                      .withValues(alpha: 0.0),
                                                  Colors.white
                                                      .withValues(alpha: 0.08),
                                                  Colors.white
                                                      .withValues(alpha: 0.22),
                                                  Colors.white
                                                      .withValues(alpha: 0.34),
                                                  Colors.white
                                                      .withValues(alpha: 0.14),
                                                  Colors.white
                                                      .withValues(alpha: 0.0),
                                                ],
                                                stops: const [
                                                  0.0,
                                                  0.16,
                                                  0.36,
                                                  0.52,
                                                  0.78,
                                                  1.0
                                                ],
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

class _TinyIssueChip extends StatelessWidget {
  const _TinyIssueChip({required this.data});

  final _IssueChipData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: data.bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        data.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: data.textColor,
          fontSize: 9.5,
          fontWeight: FontWeight.w900,
          height: 1.0,
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

int? _femaleConditionDaysLeft(Member member, DateTime now) {
  if (!member.femaleConditionEnabled) return null;

  final lastStart = member.femaleConditionLastStartAt;
  if (lastStart == null) return null;

  final cycleDays = member.femaleConditionCycleDays.clamp(20, 45);

  final today = DateTime(now.year, now.month, now.day);
  var expected = DateTime(
    lastStart.year,
    lastStart.month,
    lastStart.day,
  );

  while (expected.isBefore(today.subtract(const Duration(days: 2)))) {
    expected = expected.add(Duration(days: cycleDays));
  }

  return expected.difference(today).inDays;
}

bool _isFemaleConditionCheckWindow(Member member, DateTime now) {
  final daysLeft = _femaleConditionDaysLeft(member, now);
  if (daysLeft == null) return false;

  // 추천 기준: D-3 ~ D+2
  return daysLeft >= -2 && daysLeft <= 3;
}

String _conditionDdayText(int daysLeft) {
  if (daysLeft == 0) return 'D-DAY';
  if (daysLeft > 0) return 'D-$daysLeft';
  return 'D+${daysLeft.abs()}';
}

int? _daysUntilNextMonthDay(DateTime? source, DateTime now) {
  if (source == null) return null;

  final today = DateTime(now.year, now.month, now.day);

  DateTime target;
  try {
    target = DateTime(now.year, source.month, source.day);
  } catch (_) {
    return null;
  }

  if (target.isBefore(today)) {
    try {
      target = DateTime(now.year + 1, source.month, source.day);
    } catch (_) {
      return null;
    }
  }

  return target.difference(today).inDays;
}

String _dDayText(int daysLeft) {
  if (daysLeft == 0) return 'D-DAY';
  if (daysLeft > 0) return 'D-$daysLeft';
  return 'D+${daysLeft.abs()}';
}

bool _isSameDate(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _formatDate(DateTime date) {
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

String? _membershipExpiryDDaySuffix(Member member) {
  final expireAt = member.expireAt;
  if (expireAt == null) return null;

  final daysLeft = _daysBetween(DateTime.now(), expireAt);
  if (daysLeft < 0) return null;

  return _dDayText(daysLeft);
}

bool _isMembershipExpiryWithinDays(Member member, int days) {
  final expireAt = member.expireAt;
  if (expireAt == null) return false;

  final daysLeft = _daysBetween(DateTime.now(), expireAt);
  return daysLeft >= 0 && daysLeft <= days;
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
  // 회원권 종료일이 지났다고 해서 회원 자체를 '만료회원'으로 숨기면 안 됩니다.
  // 여기서는 선생님이 직접 상태를 '만료'로 바꾼 경우만 만료회원으로 봅니다.
  return member.memberStatus == '만료';
}

bool _isMembershipExpiredByDate(Member member) {
  // 회원권/멤버십 기간 만료 여부는 알림/만료임박 판단에만 사용합니다.
  return member.isExpired;
}

bool _isDormantMember(Member member) {
  return member.memberStatus == '휴면';
}

bool _isActiveMember(Member member) {
  return !_isExpiredMember(member) && !_isDormantMember(member);
}
