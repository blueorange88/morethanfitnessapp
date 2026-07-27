// lib/pages/home_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'client_card_page.dart';
import 'personal_training_log_page.dart';
import 'stats_page.dart';
import 'client_list_page.dart';
import 'contract_page.dart';
import 'settings_page.dart';
import 'my_page.dart';
import '../services/notification_service.dart';
import '../models/schedule_item.dart';
import '../models/personal_training_log.dart';
import '../models/personal_tier_progress.dart';
import 'personal_training_log_quick_sign_page.dart';
import 'membership_contract_page.dart';

import '../widgets/mtf_animated_drawer.dart';

import '../utils/korean_search_utils.dart' as search_utils;
import '../utils/home_header_greeting_copy.dart';
import '../utils/home_header_message_engine.dart';
import '../services/home_header_message_history.dart';
import '../services/mtf_route_observer.dart';
import '../utils/home_schedule_tombstone_guard.dart';
import '../utils/home_schedule_move_plan.dart';
import '../utils/home_schedule_edit_session_guard.dart';
import '../utils/home_schedule_write_plan.dart';
import '../utils/home_today_schedule_focus.dart';
import '../utils/personal_tier_parser.dart';

import '../models/lesson_type_item.dart';
import '../models/home_lesson_editor_result.dart';
import '../models/home_lesson_save_request.dart';
import '../models/home_lesson_save_result.dart';
import '../models/home_quick_registration_result.dart';
import '../models/home_quick_sign_member_state.dart';
import '../models/home_repeat_lesson_grouping_mode.dart';

import '../services/home_widget_preview_sync_service.dart';
import '../services/home_widget_grid_mapper.dart';
import '../services/home_widget_block_mapper.dart';
import '../services/home_lesson_notification_controller.dart';
import '../services/home_widget_sync_controller.dart';
import '../services/home_widget_navigation_service.dart';
import '../services/home_schedule_firestore_service.dart';
import '../services/home_week_paste_conflict_service.dart';
import '../services/home_deleted_member_schedule_service.dart';
import '../services/home_member_lookup_service.dart';
import '../services/lesson_confirmation_service.dart';
import '../services/lesson_confirm_cancel_service.dart';
import '../services/app_tier_access_service.dart';
import '../services/app_environment.dart';
import '../services/app_account_service.dart' show AppAccountService;
import '../services/mtf_firebase_functions.dart';
import '../services/personal_training_log_repository.dart';

import '../widgets/home/lesson_editor/home_lesson_editor_header.dart';
import '../widgets/home/lesson_editor/home_lesson_day_selector.dart';
import '../widgets/home/lesson_editor/home_lesson_type_selector.dart';
import '../widgets/home/lesson_editor/home_member_connection_hint.dart';
import '../widgets/home/lesson_editor/home_recent_members_section.dart';
import '../widgets/home/lesson_editor/home_lesson_footer_actions.dart';
import '../widgets/home/lesson_editor/home_lesson_quick_actions_section.dart';
import '../widgets/home/lesson_editor/home_lesson_type_editor_panel.dart';
import '../widgets/home/lesson_editor/home_lesson_editor_fields.dart';
import '../widgets/home/lesson_editor/home_member_match_picker_sheet.dart';
import '../widgets/home/lesson_editor/home_lesson_start_end_time_picker.dart';
import '../widgets/home/lesson_editor/home_time_range_dialog.dart';
import '../widgets/home/lesson_editor/home_member_sign_request_sheet.dart';
import '../widgets/home/sections/home_header_section.dart';
import '../widgets/home/sections/home_today_next_lessons_section.dart';
import '../widgets/home/sections/home_weekly_goal_section.dart';
import '../widgets/home/sections/home_recent_clients_section.dart';
import '../widgets/home/sections/home_this_week_schedule_section.dart';
import '../widgets/home/sections/home_support_tier_guide_sheet.dart';
import '../widgets/home/sections/home_first_lesson_guide_chat_sheet.dart';
import '../widgets/home/sections/home_aifc_nudge_sheet.dart';
import '../widgets/home/sections/home_bottom_nav_bar.dart';
import '../widgets/home/sections/home_center_plan_guide_sheet.dart';
import '../widgets/home/schedule/home_minute_picker_sheets.dart';
import '../widgets/home/schedule/home_week_paste_overwrite_sheet.dart';
import '../widgets/home/schedule/home_row_minute_settings_sheet.dart';
import '../widgets/home/schedule/home_repeat_lesson_grouping_sheet.dart';

import '../widgets/aifc_tier_feature_gate_sheet.dart';
import '../widgets/personal_training_log_entry_guard.dart';

import '../aifc/home/aifc_home_schedule_time_range_chat_sheet.dart';
import '../aifc/home/aifc_home_schedule_action_chat_sheet.dart';
import '../aifc/home/aifc_home_schedule_minute_chat_sheet.dart';
import '../aifc/core/aifc_avatar.dart';
import '../aifc/core/aifc_nickname.dart';
import '../widgets/aifc_interaction.dart';
import '../widgets/aifc_lesson_confirm_chat_sheet.dart';
import '../widgets/aifc_quick_register_chat_sheet.dart';
import '../widgets/aifc_pin_confirm_chat_sheet.dart';
import '../widgets/aifc_confirm_chat_sheet.dart';
import '../widgets/premium_banner_widget.dart';
import '../widgets/aifc_upgrade_chat_sheet.dart';
import '../widgets/aifc_tier_guide_chat_sheet.dart';
import '../widgets/aifc_consult_checklist_chat_sheet.dart';
import '../aifc/home/aifc_tier_celebration_sheet.dart';

/// ----------------------
/// 공통 컬러 팔레트 (홈 기준)
/// ----------------------
const Color kPrimaryColor = Color(0xFF4F46E5); // 홈 그라데이션 시작
const Color kPrimaryColor2 = Color(0xFF9333EA); // 홈 그라데이션 끝
const Color kAccentAmber = Color(0xFFFBBF24);
const Color kAccentOrange = Color(0xFFF97316);
const Color kBgColor = Color(0xFFF3F4F6); // 전체 배경 톤
const double kMaxContentWidth = 480;

const double kScheduleRowHeight = 40.0;
const double kScheduleHeaderCellHeight = 34.0;

// ── 홈 스케줄러 라이트 디자인 ─────────────────────────
const Color kScheduleLightBg = Color(0xFFFFFFFF);
const Color kScheduleRowEven = Color(0xFFEFF6FF);
const Color kScheduleRowOdd = Color(0xFFFFFFFF);

const Color kScheduleTimeColTop = Color(0xFFFFFFFF);
const Color kScheduleTimeColMid = Color(0xFFF8FAFC);
const Color kScheduleTimeColBottom = Color(0xFFEFF6FF);

const Color kScheduleGridLine = Color(0xFFE5E7EB);
const Color kScheduleTimeColLine = Color(0xFFD1D5DB);
const Color kScheduleTimeText = Color(0xFF475569);

const Color kScheduleTodayHeader = Color(0xFFFBBF24);
const Color kScheduleTodayHeaderDeep = Color(0xFFF59E0B);
const Color kScheduleTodayEven = Color(0x33FBBF24);
const Color kScheduleTodayOdd = Color(0x22FBBF24);
const Color kScheduleCurrentLine = Color(0xFFE11D48);

const String kMemberSignBaseUrl =
    'https://more-than-fitness-f6adb.web.app/sign';

// 개인 강사 후원 가격
const int kAmateurSupportMonthlyPrice = 2900;
const int kSemiProSupportMonthlyPrice = 3900;
const int kProSupportMonthlyPrice = 5900;

// 조직/지점 후원 가격.
// 실제 Master / Grand Prix 권한 연결은 추후 별도 작업.
const int kMasterSupportMonthlyPrice = 39000;
const int kGrandPrixSupportMonthlyPrice = 89000;

enum HomeAction {
  quickSchedule,
  quickMember,
  notifications,
  settings,
  expiringMembers,
}

const List<String> kSeedLessonTypeNames = [
  'PT',
  '필라테스',
  '그룹레슨',
  'OT상담',
];

const List<Color> kLessonTypePalette = [
  Color(0xFF4F46E5), // indigo
  Color(0xFF7C3AED), // purple
  Color(0xFF2563EB), // blue
  Color(0xFF0F766E), // teal
  Color(0xFF16A34A), // green
  Color(0xFFF97316), // orange
  Color(0xFFDB2777), // pink
];

@visibleForTesting
Widget buildHomeMyPageDestination({String? personalOwnerUid}) =>
    MyPage(personalOwnerUid: personalOwnerUid);

@visibleForTesting
String homeSchedulePreferenceKey(
  String baseKey,
  String? personalOwnerUid, {
  String? projectId,
}) {
  final owner = personalOwnerUid?.trim() ?? '';
  return owner.isEmpty
      ? baseKey
      : AppEnvironmentConfig.personalPreferenceKey(
          uid: owner,
          featureKey: baseKey,
          projectId: projectId,
        );
}

@visibleForTesting
bool shouldApplyPersonalProfileSnapshot({
  required bool hasInitialProfile,
  required bool fromCache,
}) =>
    !hasInitialProfile || !fromCache;

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.personalOwnerUid,
    this.initialPersonalProfileData,
  });

  final String? personalOwnerUid;
  final Map<String, dynamic>? initialPersonalProfileData;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with RouteAware, WidgetsBindingObserver {
  bool get _isPersonalWorkspace =>
      (widget.personalOwnerUid ?? '').trim().isNotEmpty;

  String get _personalOwnerUid => widget.personalOwnerUid?.trim() ?? '';
  String get _personalPreferenceScope =>
      AppEnvironmentConfig.personalScope(_personalOwnerUid);

  Query<Map<String, dynamic>> _ownedCollectionQuery(String collection) {
    final base = FirebaseFirestore.instance.collection(collection);
    if (!_isPersonalWorkspace) return base;
    return base
        .where('trainerId', isEqualTo: _personalOwnerUid)
        .where('workspaceType', isEqualTo: 'personal');
  }

  DocumentReference<Map<String, dynamic>> get _trainerProfileRef =>
      _isPersonalWorkspace
          ? FirebaseFirestore.instance
              .collection('trainer_profiles')
              .doc(_personalOwnerUid)
          : FirebaseFirestore.instance.collection('trainer_profile').doc('me');

  Future<AppTierAccessSnapshot> _loadCurrentTierAccess() {
    if (_isPersonalWorkspace) {
      return AppTierAccessService.loadPersonalTrainerAccess(
        uid: _personalOwnerUid,
      );
    }
    return AppTierAccessService.loadTrainerAccess();
  }

  final GlobalKey<ScaffoldState> _homeScaffoldKey = GlobalKey<ScaffoldState>();

  bool isHeaderExpanded = false;

  String dayFilter = "all";

  int startHour = 6;
  int endHour = 23;
  int defaultMinute = 0;
  final Map<int, int> _timeRowMinutes = {};

  late DateTime currentTime;
  Timer? _timer;

  /// 내부 저장용 레슨일정 데이터
  ///
  /// 키 형식은 절대 날짜 기반입니다.
  /// 예) "2026-07-06-09:00"
  ///
  /// 주차 구분은 key에 직접 저장하지 않고,
  /// startAt을 기준으로 현재 주의 월요일과 비교해 계산합니다.
  ///
  /// 주의:
  /// - Firestore 문서 id 형식은 _scheduleDocIdFromDate() 기준입니다.
  /// - 화면/로컬 Map key 형식은 _absoluteKeyFromDate() 기준입니다.
  /// - 예전 "0-월-09:00" 방식으로 key를 만들면
  ///   수정/삭제/붙여넣기 로직과 어긋날 수 있습니다.
  final Map<String, dynamic> scheduleData = {};

  int _weeklyLessonGoal = 40;
  bool _notificationsOn = false;
  bool _lessonNotificationNudgeAnswered = false;
  bool _customerCardNudgeAnswered = false;

  static const String _customerCardNudgePrefsKey =
      'home_customer_card_nudge_answered_v1';

  static const String _lessonNotificationNudgePrefsKey =
      'home_lesson_notification_nudge_answered_v1';

  static const String _contractFirstEntryCelebratedPrefsKey =
      'home_contract_first_entry_celebrated_v1';

  bool _showScheduleHelp = false;

  AppTier _currentAppTier = AppTier.beginner;
  bool _isSponsor = false;
  bool _hasProduct = false;
  bool _trainerInfoDone = false;
  bool get _displayTrainerInfoDone =>
      _currentAppTier.index >= AppTier.amateur.index || _trainerInfoDone;
  int _bannerMemberCount = 0;
  String _bannerTrainerName = '';
  int _moreSenseMemberCount = 0;
  List<HomeMoreSenseContext> _moreSenseItems = const [];
  HomeHeaderMessageSelection? _headerMessageSelection;
  String _headerMessageContextSignature = '';
  int _homeEntrySerial = 0;
  Set<String> _recentHeaderMessageKeys = <String>{};
  Set<String> _askedHeaderQuestionKeys = <String>{};
  bool _headerMessageHistoryReady = false;
  ModalRoute<void>? _subscribedHomeRoute;

  late final HomeHeaderMessageHistory _headerMessageHistory =
      HomeHeaderMessageHistory(
    scopeKey: _isPersonalWorkspace ? _personalPreferenceScope : 'legacy',
  );

  int _kakaoCardLinkedMemberCount = 0;
  int _contractSignedMemberCount = 0;

  String _lastTierCacheSignature = '';
  bool _tierCacheSyncing = false;

  bool _bannerProfileReady = false;
  bool _bannerMembersReady = false;
  bool _bannerProductsReady = false;
  bool _scheduleStreamReady = false;
  bool _bannerTierReadFailed = false;
  String _lastHeaderWorkloadLogSignature = '';

  bool get _bannerStateReady => _isPersonalWorkspace
      ? _bannerProfileReady
      : _bannerProfileReady &&
          _bannerMembersReady &&
          _bannerProductsReady &&
          _scheduleStreamReady;

  String get _bannerTierName {
    if (_bannerTierReadFailed) return '확인실패';
    return _bannerStateReady ? _currentAppTier.label : '확인중';
  }

  int get _amateurProgressCount {
    if (!_isPersonalWorkspace) return scheduleData.length;
    return PersonalTierProgress.fromProfile(_bannerProfileData).scheduleCount;
  }

  PersonalTierProgress get _personalTierProgress =>
      PersonalTierProgress.fromProfile(_bannerProfileData);

  Map<String, dynamic> _bannerProfileData = <String, dynamic>{};
  bool _hasInitialPersonalProfileData = false;
  bool _tierCelebrationClaimInFlight = false;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _bannerProfileSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _bannerMembersSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _bannerProductsSub;

  String _formatLessonSheetTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return time;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    final isPm = hour >= 12;
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final ampm = isPm ? '오후' : '오전';

    return '$ampm ${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openMembershipContractFromHome() async {
    final access = await _loadCurrentTierAccess();

    if (!mounted) return;

    final canUse = await AifcTierFeatureGateSheet.guard(
      context: context,
      access: access,
      feature: AppTierFeatureKey.membershipContract,
      loadAccess: _loadCurrentTierAccess,
      onShowTierGuide: (info) async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${info.requiredTierLabel} 안내는 마이페이지의 등급 안내에서 다시 확인할 수 있어요.',
            ),
          ),
        );
      },
    );

    if (!canUse || !mounted) return;

    final member = await _showMembershipContractMemberPicker();

    if (!mounted || member == null) return;

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MembershipContractPage(
          memberId: member.id,
          memberName: member.name,
          trainerName: member.trainerName,
          lessonType: member.lessonType,
          totalSessions: member.totalSessions,
          remainingSessions: member.remainingSessions,
          membershipStartAt: member.membershipStartAt,
          membershipEndAt: member.membershipEndAt,
          membershipPaused: member.membershipPaused,
        ),
      ),
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('회원권계약서 초안을 저장했어요.'),
        ),
      );
    }
  }

  Future<_HomeMembershipContractMember?>
      _showMembershipContractMemberPicker() async {
    final snapshot = await _ownedCollectionQuery('members')
        .where('isDeleted', isNotEqualTo: true)
        .limit(80)
        .get();

    if (!mounted) return null;

    final members = snapshot.docs
        .map((doc) {
          return _HomeMembershipContractMember.fromFirestore(
            doc.id,
            doc.data(),
          );
        })
        .where((member) => member.name.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('회원권계약서를 작성할 회원이 아직 없어요.'),
        ),
      );
      return null;
    }

    return showModalBottomSheet<_HomeMembershipContractMember>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * 0.82,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.14),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 16, 18, 10),
                    child: Row(
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          color: Color(0xFF4F46E5),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '회원권계약서 작성할 회원 선택',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final member = members[index];

                        final periodText = member.membershipStartAt == null &&
                                member.membershipEndAt == null
                            ? '회원권 기간 미등록'
                            : '${_homeMembershipDateText(member.membershipStartAt)} ~ ${_homeMembershipDateText(member.membershipEndAt)}';

                        return InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            Navigator.of(sheetContext).pop(member);
                          },
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.person_rounded,
                                    color: Color(0xFF4F46E5),
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        member.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        periodText,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF6B7280),
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '잔여 ${member.remainingSessions}회 / 총 ${member.totalSessions}회',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _homeMembershipDateText(DateTime? value) {
    if (value == null) return '-';

    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  /// "이번 주 레슨일정 사용법" 안내 토글
  bool _hideScheduleExamples = false;

  /// 주간 레슨일정 슬라이드
  int _weekPageIndex = _todayWeekIndex; // 처음엔 "이번 주"

  // PageView 컨트롤러 (처음 페이지를 이번 주로)
  late final PageController _weekPageController =
      PageController(initialPage: _todayWeekIndex);
  final ScrollController _homeScrollController = ScrollController();
  final GlobalKey _scheduleSectionKey = GlobalKey();
  final GlobalKey _todayNextLessonsKey = GlobalKey();

  /// 빠른 등록 중 중복 요청 방지
  bool _isSubmitting = false;
  final Set<String> _deletingScheduleDocIds = <String>{};
  final Set<String> _pendingScheduleMutationDocIds = <String>{};
  final Map<String, DateTime> _recentlyDeletedScheduleDocIds =
      <String, DateTime>{};
  String _lastSelectedLessonTypeId = '';
  List<LessonTypeItem> _lessonTypes = [];
  static const int _defaultLessonDurationMinutes = 50;

  int _preferredLessonDurationMinutes = _defaultLessonDurationMinutes;

  HomeRepeatLessonGroupingMode _repeatLessonGroupingMode =
      HomeRepeatLessonGroupingMode.none;

  List<Map<String, dynamic>> _copiedWeekSchedules = [];
  String? _copiedWeekSourceLabel;
  DateTime? _streamAnchorMonday;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _scheduleSub;

  // Firestore snapshot 콜백 안에서 회원 상태를 추가 조회하므로,
  // 이전 snapshot 처리가 최신 snapshot보다 늦게 끝날 수 있습니다.
  // binding id와 snapshot 순번으로 오래된 결과가 화면을 덮지 못하게 합니다.
  int _scheduleStreamBindingId = 0;

  late final HomeWidgetSyncController _homeWidgetSyncController;
  late final HomeLessonNotificationController _lessonNotificationController;

  OverlayEntry? _aifcNotificationToastEntry;
  Timer? _aifcNotificationToastTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initializeBannerFromInitialPersonalProfile();

    _homeWidgetSyncController = HomeWidgetSyncController();

    _lessonNotificationController = HomeLessonNotificationController(
      nudgePrefsKey: _lessonNotificationNudgePrefsKey,
    );

    currentTime = DateTime.now();
    unawaited(_loadHomeHeaderMessageHistory());
    _ensureTimeRowMinutes();
    unawaited(_loadScheduleViewPrefs());
    unawaited(_loadRepeatLessonGroupingMode());
    unawaited(_loadScheduleExamplePrefs());
    unawaited(_loadLessonNotificationNudgePrefs());
    unawaited(_loadCustomerCardNudgePrefs());
    unawaited(_loadWeeklyGoal());
    _bindScheduleStream();
    _bindBannerDataStreams();
    unawaited(_loadLessonTypePrefs());
    _queueHomeWidgetSync(source: 'appStart');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(HomeWidgetNavigationService.start(_handleWidgetAction));
    });

    unawaited(NotificationService.instance.initialize());
    unawaited(_loadNotificationEnabledState());
    _queueNotificationSync(delay: Duration.zero);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeClaimPendingTierCelebration(_bannerProfileData);
    });

    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;

      setState(() {
        currentTime = DateTime.now();
      });

      _rebindScheduleStreamIfNeeded();
      _queueHomeWidgetSync(source: 'timer');
    });
  }

  void _initializeBannerFromInitialPersonalProfile() {
    final initial = widget.initialPersonalProfileData;
    if (!_isPersonalWorkspace || initial == null || initial.isEmpty) return;

    final profileData = Map<String, dynamic>.from(initial);
    _hasInitialPersonalProfileData = true;
    _bannerProfileData = profileData;
    _bannerTrainerName = _trainerHeaderNameFromData(profileData);
    _trainerInfoDone = _personalTierProgress.teacherInfoCompleted;
    _isSponsor = profileData['isSponsor'] == true;
    _bannerMemberCount = ((profileData['validMemberCount'] ??
                profileData['lifetimeQualifiedMemberCount']) as num?)
            ?.toInt() ??
        0;
    final tier = parsePersonalTierLabel(profileData['tier']);
    if (tier != null) {
      _currentAppTier = _resolveAppTier(tier);
      _bannerTierReadFailed = false;
      _bannerProfileReady = true;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || identical(route, _subscribedHomeRoute)) return;
    if (_subscribedHomeRoute != null) mtfRouteObserver.unsubscribe(this);
    _subscribedHomeRoute = route;
    mtfRouteObserver.subscribe(this, route);
  }

  @override
  void didPopNext() {
    if (!mounted) return;
    setState(() {
      _homeEntrySerial++;
      _headerMessageContextSignature = '';
    });
    _queueHomeWidgetSync(delay: Duration.zero, source: 'resume');
    unawaited(HomeWidgetNavigationService.consumePending(_handleWidgetAction));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    _queueHomeWidgetSync(delay: Duration.zero, source: 'resume');
    unawaited(HomeWidgetNavigationService.consumePending(_handleWidgetAction));
  }

  Future<void> _handleWidgetAction(String action) async {
    if (!mounted || action != 'today') return;
    await _openTodayScheduleFocus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    HomeWidgetNavigationService.stop();
    mtfRouteObserver.unsubscribe(this);
    _scheduleSub?.cancel();
    _bannerProfileSub?.cancel();
    _bannerMembersSub?.cancel();
    _bannerProductsSub?.cancel();
    _weekPageController.dispose();
    _homeScrollController.dispose();
    _timer?.cancel();
    _homeWidgetSyncController.dispose();
    _lessonNotificationController.dispose();
    _hideAifcNotificationToast();
    _hideActionToast();
    super.dispose();
  }

  Future<void> _loadHomeHeaderMessageHistory() async {
    final saved = await _headerMessageHistory.load(DateTime.now());
    if (!mounted) return;
    setState(() {
      _recentHeaderMessageKeys = saved.recent;
      _askedHeaderQuestionKeys = saved.questions;
      _headerMessageHistoryReady = true;
      _headerMessageContextSignature = '';
    });
  }

  String _colorToHex(Color color) {
    final hex = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
    return '#${hex.toUpperCase()}';
  }

  String _generateLessonTypeId() {
    return DateTime.now().microsecondsSinceEpoch.toString();
  }

  Color _nextSeedColor(int index) {
    return kLessonTypePalette[index % kLessonTypePalette.length];
  }

  List<LessonTypeItem> _buildSeedLessonTypes() {
    return List<LessonTypeItem>.generate(
      kSeedLessonTypeNames.length,
      (index) => LessonTypeItem(
        id: 'seed_$index',
        name: kSeedLessonTypeNames[index],
        colorHex: _colorToHex(_nextSeedColor(index)),
      ),
    );
  }

  void _toggleHeaderExpanded() {
    setState(() {
      isHeaderExpanded = !isHeaderExpanded;
    });
  }

  Future<void> _loadWeeklyGoal() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt('goal_weekly_lesson_target') ?? 40;
    if (!mounted) return;
    setState(() => _weeklyLessonGoal = saved);
  }

  Future<void> _editWeeklyGoal() async {
    final controller = TextEditingController(text: '$_weeklyLessonGoal');
    final submitted = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('주간 레슨 목표'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            labelText: '목표 레슨 수',
            hintText: '비우면 기본값 40회',
            suffixText: '회',
          ),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || submitted == null) return;

    final parsed = parseHomeWeeklyGoalInput(submitted);
    final prefs = await SharedPreferences.getInstance();
    if (submitted.trim().isEmpty) {
      await prefs.remove('goal_weekly_lesson_target');
    } else {
      await prefs.setInt('goal_weekly_lesson_target', parsed);
    }
    if (!mounted) return;
    setState(() => _weeklyLessonGoal = parsed);
  }

  Future<void> _loadLessonTypePrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString('home_lesson_types_v3');
    final lastId = prefs.getString('home_last_lesson_type_id') ?? '';

    List<LessonTypeItem> nextItems = [];

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          nextItems = decoded
              .whereType<Map>()
              .map(
                (e) => LessonTypeItem.fromMap(
                  Map<String, dynamic>.from(e),
                ),
              )
              .where((e) => e.id.isNotEmpty && e.name.trim().isNotEmpty)
              .toList();
        }
      } catch (_) {}
    }

    if (nextItems.isEmpty) {
      nextItems = _buildSeedLessonTypes();
      await prefs.setString(
        'home_lesson_types_v3',
        jsonEncode(nextItems.map((e) => e.toMap()).toList()),
      );
    }

    final safeLastId =
        nextItems.any((e) => e.id == lastId) ? lastId : nextItems.first.id;

    if (!mounted) return;

    setState(() {
      _lessonTypes = nextItems;
      _lastSelectedLessonTypeId = safeLastId;
    });
  }

  Future<void> _saveLessonTypePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'home_lesson_types_v3',
      jsonEncode(_lessonTypes.map((e) => e.toMap()).toList()),
    );
    await prefs.setString(
      'home_last_lesson_type_id',
      _lastSelectedLessonTypeId,
    );
  }

  Future<void> _loadScheduleViewPrefs() async {
    final prefs = await SharedPreferences.getInstance();

    final owner = _isPersonalWorkspace ? _personalOwnerUid : null;
    final savedStartHour =
        prefs.getInt(homeSchedulePreferenceKey('home_start_hour', owner));
    final savedEndHour =
        prefs.getInt(homeSchedulePreferenceKey('home_end_hour', owner));
    final savedDefaultMinute =
        prefs.getInt(homeSchedulePreferenceKey('home_default_minute', owner));

    final rawRowMinutes = prefs.getString(
      homeSchedulePreferenceKey('home_time_row_minutes_v1', owner),
    );

    if (!mounted) return;

    setState(() {
      if (savedStartHour != null) startHour = savedStartHour;
      if (savedEndHour != null) endHour = savedEndHour;
      if (savedDefaultMinute != null) defaultMinute = savedDefaultMinute;

      _timeRowMinutes.clear();

      if (rawRowMinutes != null && rawRowMinutes.isNotEmpty) {
        try {
          final decoded = jsonDecode(rawRowMinutes) as Map<String, dynamic>;
          decoded.forEach((key, value) {
            final hour = int.tryParse(key);
            final minute = int.tryParse(value.toString());
            if (hour != null && minute != null) {
              _timeRowMinutes[hour] = minute;
            }
          });
        } catch (_) {}
      }

      _ensureTimeRowMinutes();
    });
  }

  Future<void> _loadRepeatLessonGroupingMode() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _repeatLessonGroupingMode = homeRepeatLessonGroupingModeFromString(
        prefs.getString(kHomeRepeatLessonGroupingModePrefsKey),
      );
    });
  }

  Future<void> _saveRepeatLessonGroupingMode(
    HomeRepeatLessonGroupingMode mode,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      kHomeRepeatLessonGroupingModePrefsKey,
      mode.storageValue,
    );

    if (!mounted) return;

    setState(() {
      _repeatLessonGroupingMode = mode;
    });

    _showActionToast(
      context,
      '반복 레슨 모아보기 방식을 ${mode.shortLabel}으로 변경했어요.',
      bottomOffset: 110,
    );
  }

  Future<void> _openRepeatLessonGroupingSheet() async {
    final picked = await HomeRepeatLessonGroupingSheet.show(
      context: context,
      currentMode: _repeatLessonGroupingMode,
      primaryColor: kPrimaryColor,
    );

    if (!mounted || picked == null) return;

    await _saveRepeatLessonGroupingMode(picked);
  }

  Future<void> _saveScheduleViewPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final owner = _isPersonalWorkspace ? _personalOwnerUid : null;

    await prefs.setInt(
      homeSchedulePreferenceKey('home_start_hour', owner),
      startHour,
    );
    await prefs.setInt(
      homeSchedulePreferenceKey('home_end_hour', owner),
      endHour,
    );
    await prefs.setInt(
      homeSchedulePreferenceKey('home_default_minute', owner),
      defaultMinute,
    );

    final map = <String, int>{};
    _timeRowMinutes.forEach((key, value) {
      map[key.toString()] = value;
    });

    await prefs.setString(
      homeSchedulePreferenceKey('home_time_row_minutes_v1', owner),
      jsonEncode(map),
    );
  }

  Future<void> _loadScheduleExamplePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getBool('home_hide_schedule_examples_v1') ?? false;

    if (!mounted) return;

    setState(() {
      _hideScheduleExamples = hidden;
    });
  }

  Future<void> _hideScheduleExamplesForever() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('home_hide_schedule_examples_v1', true);

    if (!mounted) return;

    setState(() {
      _hideScheduleExamples = true;
    });

    _showActionToast(context, '예시 레슨을 숨겼어요.');
  }

  bool _shouldShowScheduleExamples(int weekOffset) {
    if (_hideScheduleExamples) return false;
    if (weekOffset != 0) return false;

    // 실제 레슨이 3개 이상 등록되면 예시는 자연스럽게 사라집니다.
    return _allScheduleItems().length < 3;
  }

  void _showScheduleExampleInfo() {
    _showActionToast(
      context,
      '예시용 레슨입니다. 실제 데이터에는 저장되지 않아요.',
      bottomOffset: 110,
    );
  }

  LessonTypeItem? _findLessonTypeById(String id, List<LessonTypeItem> items) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  LessonTypeItem? _findLessonTypeByName(
      String name, List<LessonTypeItem> items) {
    for (final item in items) {
      if (item.name == name) return item;
    }
    return null;
  }

  Color _legacyLessonTypeColor(String type) {
    switch (type) {
      case '레슨':
      case 'PT':
        return kPrimaryColor;
      case '필라테스':
        return const Color(0xFF7C3AED);
      case '그룹':
      case '그룹레슨':
        return kAccentOrange;
      case '요가':
        return const Color(0xFF0F766E);
      case 'OT상담':
      case '상담':
        return const Color(0xFF2563EB);
      default:
        return kPrimaryColor;
    }
  }

  String _lessonTypeColorHexByName(String type) {
    final item = _findLessonTypeByName(type, _lessonTypes);
    if (item != null) return item.colorHex;
    return _colorToHex(_legacyLessonTypeColor(type));
  }

  LessonTypeItem _resolveLessonTypeForSchedule(Map<String, dynamic>? session) {
    final typeId = session?['typeId']?.toString() ?? '';
    final typeName =
        (session?['typeName'] ?? session?['type'] ?? 'PT').toString();
    final typeColorHex = session?['typeColorHex']?.toString();

    final byId =
        typeId.isNotEmpty ? _findLessonTypeById(typeId, _lessonTypes) : null;
    if (byId != null) return byId;

    final byName = _findLessonTypeByName(typeName, _lessonTypes);
    if (byName != null) return byName;

    return LessonTypeItem(
      id: _generateLessonTypeId(),
      name: typeName,
      colorHex: typeColorHex?.isNotEmpty == true
          ? typeColorHex!
          : _colorToHex(_legacyLessonTypeColor(typeName)),
    );
  }

  void _rebindScheduleStreamIfNeeded() {
    final nextAnchor = _mondayOfWeek(currentTime);
    final prevAnchor = _streamAnchorMonday;

    if (prevAnchor == null ||
        prevAnchor.year != nextAnchor.year ||
        prevAnchor.month != nextAnchor.month ||
        prevAnchor.day != nextAnchor.day) {
      _bindScheduleStream();
    }
  }

  void _bindScheduleStream() {
    _scheduleSub?.cancel();

    final bindingId = ++_scheduleStreamBindingId;
    var latestSnapshotId = 0;

    final anchorMonday = _mondayOfWeek(currentTime);
    _streamAnchorMonday = anchorMonday;

    final start = anchorMonday.add(Duration(days: _minWeekOffset * 7));
    final endExclusive =
        anchorMonday.add(Duration(days: (_maxWeekOffset + 1) * 7));

    _scheduleSub = _ownedCollectionQuery('schedules')
        .where(
          'startAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(
          'startAt',
          isLessThan: Timestamp.fromDate(endExclusive),
        )
        .snapshots()
        .listen((snapshot) async {
      final snapshotId = ++latestSnapshotId;

      if (kDebugMode) {
        debugPrint(
          '[MTF_SCHEDULE_STREAM] binding=$bindingId revision=$snapshotId '
          'fromCache=${snapshot.metadata.isFromCache} '
          'pendingWrites=${snapshot.metadata.hasPendingWrites} '
          'docCount=${snapshot.docs.length}',
        );
      }

      Set<String> deletedMemberIds;
      try {
        deletedMemberIds =
            await _deletedMemberIdsFromScheduleDocs(snapshot.docs);
      } catch (error) {
        if (kDebugMode) {
          final errorCode = error is FirebaseException
              ? error.code
              : error.runtimeType.toString();
          debugPrint(
            '[MTF_SCHEDULE_MEMBER_RESOLUTION] result=failure '
            'errorCode=$errorCode',
          );
        }
        if (!mounted || bindingId != _scheduleStreamBindingId) return;
        setState(() {
          _scheduleStreamReady = true;
          scheduleData.clear();
        });
        _queueHomeWidgetSync(source: 'scheduleSnapshot');
        return;
      }

      // 새 snapshot 또는 새 stream binding이 이미 시작됐다면 이 결과는 폐기합니다.
      // 그렇지 않으면 오래된 snapshot이 삭제된 레슨을 다시 화면에 올릴 수 있습니다.
      if (!mounted ||
          !shouldApplyHomeScheduleSnapshot(
            bindingId: bindingId,
            currentBindingId: _scheduleStreamBindingId,
            revision: snapshotId,
            latestRevision: latestSnapshotId,
          )) {
        debugPrint(
          '[MTF_SCHEDULE_STREAM] stale snapshot ignored '
          'binding=$bindingId snapshot=$snapshotId latest=$latestSnapshotId',
        );
        return;
      }

      _reconcileRecentlyDeletedScheduleDocIds(
        snapshot.docs,
        isFromCache: snapshot.metadata.isFromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
        revision: snapshotId,
      );

      if (shouldCleanupDeletedMemberScheduleLinks(
        isFromCache: snapshot.metadata.isFromCache,
        hasPendingWrites: snapshot.metadata.hasPendingWrites,
        hasDeletedMemberIds: deletedMemberIds.isNotEmpty,
      )) {
        unawaited(
          _cleanupDeletedMemberScheduleLinks(
            docs: snapshot.docs,
            deletedMemberIds: deletedMemberIds,
          ),
        );
      }

      final next = <String, dynamic>{};

      for (final doc in snapshot.docs) {
        final docId = doc.id.trim();

        if (_isScheduleDocTemporarilyHidden(docId)) {
          debugPrint('[MTF_SCHEDULE_DELETE] hidden from stream docId=$docId');
          continue;
        }

        final data = doc.data();
        final dataDocId = (data['docId'] ?? '').toString().trim();

        if (kDebugMode) {
          if (dataDocId.isNotEmpty && dataDocId != docId) {
            debugPrint(
              '[MTF_SCHEDULE_STREAM] actualDocId=$docId '
              'dataDocId=$dataDocId mismatch=true revision=$snapshotId',
            );
          }
        }

        if (_isScheduleDataDeleted(data)) {
          continue;
        }

        final ts = data['startAt'];
        if (ts is! Timestamp) continue;

        final dt = ts.toDate();
        final key = _makeKey(
          ((_mondayOfWeek(dt).difference(anchorMonday).inDays) / 7).round(),
          _weekDaysAll[dt.weekday - 1],
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}',
        );

        DateTime? endDt;
        final endTs = data['endAt'];
        if (endTs is Timestamp) {
          endDt = endTs.toDate();
        }

        final memberIdText = (data['memberId'] ?? '').toString().trim();

        final bool linkedMemberDeleted = data['linkedMemberDeleted'] == true ||
            (memberIdText.isNotEmpty &&
                deletedMemberIds.contains(memberIdText));

        final sessionsMap = data['sessions'] is Map
            ? Map<String, dynamic>.from(data['sessions'] as Map)
            : <String, dynamic>{};

        final lessonSyncMap = data['lessonSync'] is Map
            ? Map<String, dynamic>.from(data['lessonSync'] as Map)
            : <String, dynamic>{};

        final lastContractSummaryMap = data['lastContractSummary'] is Map
            ? Map<String, dynamic>.from(data['lastContractSummary'] as Map)
            : <String, dynamic>{};

        final smartAlarmContextMap = data['smartAlarmContext'] is Map
            ? Map<String, dynamic>.from(data['smartAlarmContext'] as Map)
            : <String, dynamic>{};

        final moreCareSlotMap = data['moreCareSlot'] is Map
            ? Map<String, dynamic>.from(data['moreCareSlot'] as Map)
            : <String, dynamic>{};

        final moreCareStatusText =
            (data['moreCareStatus'] ?? moreCareSlotMap['status'] ?? '')
                .toString()
                .trim();

        final moreCareRequestIdText =
            (data['moreCareRequestId'] ?? moreCareSlotMap['requestId'] ?? '')
                .toString()
                .trim();

        final moreCareTemporaryUntilValue =
            data['moreCareTemporaryUntil'] ?? moreCareSlotMap['temporaryUntil'];

        final contractIdText = (data['contractId'] ??
                lessonSyncMap['contractId'] ??
                lastContractSummaryMap['contractId'] ??
                '')
            .toString()
            .trim();

        final contractNoText =
            (data['contractNo'] ?? lastContractSummaryMap['contractNo'] ?? '')
                .toString()
                .trim();

        final lessonSyncSourceText = (data['lessonSyncSource'] ??
                data['contractLessonSyncSource'] ??
                lessonSyncMap['source'] ??
                '')
            .toString()
            .trim();

        final bool contractSignedValue = data['contractSigned'] == true ||
            data['isContractSigned'] == true ||
            data['finalSigned'] == true ||
            lessonSyncMap['contractSigned'] == true ||
            contractIdText.isNotEmpty;

        final nextItem = <String, dynamic>{
          'actualDocumentId': doc.id,
          'dataDocumentId': dataDocId,
          'docId': doc.id,
          'startAt': dt,
          'name': (data['name'] ?? '').toString(),
          'type': (data['type'] ?? 'PT').toString(),

          if (data['lessonConfirmed'] != null)
            'lessonConfirmed': data['lessonConfirmed'] == true,
          if (data['lessonConfirmedAt'] != null)
            'lessonConfirmedAt': data['lessonConfirmedAt'],
          if (data['lessonConfirmStatus'] != null)
            'lessonConfirmStatus': data['lessonConfirmStatus'].toString(),

          if (data['basis'] != null) 'basis': data['basis'].toString(),
          if (data['contractLinked'] != null)
            'contractLinked': data['contractLinked'] == true,

          if (contractIdText.isNotEmpty) 'contractId': contractIdText,

          if (contractNoText.isNotEmpty) 'contractNo': contractNoText,

          if (contractSignedValue) 'contractSigned': true,

          if (lessonSyncSourceText.isNotEmpty)
            'lessonSyncSource': lessonSyncSourceText,

          if (data['cancelLockedByContract'] != null)
            'cancelLockedByContract': data['cancelLockedByContract'] == true,
          if (data['cancelLockContractReason'] != null)
            'cancelLockContractReason':
                data['cancelLockContractReason'].toString(),

          if (data['trainingLogId'] != null)
            'trainingLogId': data['trainingLogId'].toString(),
          if (data['quickTrainingLogId'] != null)
            'quickTrainingLogId': data['quickTrainingLogId'].toString(),
          if (data['lastTrainingLogId'] != null)
            'lastTrainingLogId': data['lastTrainingLogId'].toString(),

          if (data['memberSigned'] != null)
            'memberSigned': data['memberSigned'] == true,
          if (data['customerSigned'] != null)
            'customerSigned': data['customerSigned'] == true,

          if (data['memberSignedAt'] != null)
            'memberSignedAt': data['memberSignedAt'],
          if (data['customerSignedAt'] != null)
            'customerSignedAt': data['customerSignedAt'],

          if (data['memberSignature'] != null)
            'memberSignature': data['memberSignature'],
          if (data['customerSignature'] != null)
            'customerSignature': data['customerSignature'],

          if (data['typeName'] != null) 'typeName': data['typeName'].toString(),
          if (data['typeId'] != null) 'typeId': data['typeId'].toString(),
          if (data['typeColorHex'] != null)
            'typeColorHex': data['typeColorHex'].toString(),

          'attended': data['attended'] == true,
          'endAt':
              endDt ?? dt.add(Duration(minutes: _defaultLessonDurationMinutes)),
          'endTime': (data['endTime'] ?? '').toString(),

          if (data['attendanceOverride'] != null)
            'attendanceOverride': data['attendanceOverride'],

          if (data['sessionSnapshotTotal'] != null)
            'sessionSnapshotTotal': data['sessionSnapshotTotal'],
          if (data['sessionSnapshotRemainBefore'] != null)
            'sessionSnapshotRemainBefore': data['sessionSnapshotRemainBefore'],
          if (data['sessionSnapshotRemainAfter'] != null)
            'sessionSnapshotRemainAfter': data['sessionSnapshotRemainAfter'],
          if (data['sessionSnapshotDoneBefore'] != null)
            'sessionSnapshotDoneBefore': data['sessionSnapshotDoneBefore'],
          if (data['sessionSnapshotDoneAfter'] != null)
            'sessionSnapshotDoneAfter': data['sessionSnapshotDoneAfter'],
          if (data['sessionSnapshotLessonNumber'] != null)
            'sessionSnapshotLessonNumber': data['sessionSnapshotLessonNumber'],
          if (data['sessionSnapshotLabel'] != null)
            'sessionSnapshotLabel': data['sessionSnapshotLabel'].toString(),

          // 삭제 회원과 연결된 스케줄은 회원카드/레슨일지 연결 정보 제외

          if (!linkedMemberDeleted && memberIdText.isNotEmpty)
            'memberId': memberIdText,

          if (!linkedMemberDeleted && data['phone'] != null)
            'phone': data['phone'].toString(),

          if (!linkedMemberDeleted && data['totalSessions'] != null)
            'totalSessions': data['totalSessions'].toString(),

          if (!linkedMemberDeleted && data['remainingSessions'] != null)
            'remainingSessions': data['remainingSessions'].toString(),

          if (!linkedMemberDeleted && data['remainSessions'] != null)
            'remainSessions': data['remainSessions'].toString(),

          if (!linkedMemberDeleted &&
              (data['doneSessions'] != null || sessionsMap['done'] != null))
            'doneSessions':
                (data['doneSessions'] ?? sessionsMap['done']).toString(),

          if (!linkedMemberDeleted &&
              data['totalSessions'] == null &&
              sessionsMap['total'] != null)
            'totalSessions': sessionsMap['total'].toString(),

          if (!linkedMemberDeleted &&
              data['remainingSessions'] == null &&
              data['remainSessions'] == null &&
              sessionsMap['remain'] != null)
            'remainingSessions': sessionsMap['remain'].toString(),

          if (linkedMemberDeleted) 'linkedMemberDeleted': true,

          if (data['deletedMemberId'] != null)
            'deletedMemberId': data['deletedMemberId'].toString(),

          if (data['deletedMemberName'] != null)
            'deletedMemberName': data['deletedMemberName'].toString(),

          if (data['memo'] != null) 'memo': data['memo'].toString(),

          if (smartAlarmContextMap.isNotEmpty)
            'smartAlarmContext': smartAlarmContextMap,

          if (data['lastLessonLogSummary'] != null)
            'lastLessonLogSummary': data['lastLessonLogSummary'].toString(),

          if (data['lastLessonLogKeywords'] is List)
            'lastLessonLogKeywords': (data['lastLessonLogKeywords'] as List)
                .map((e) => e.toString())
                .toList(),

          if (data['nextLessonReminderHint'] != null)
            'nextLessonReminderHint': data['nextLessonReminderHint'].toString(),

          if (moreCareStatusText.isNotEmpty)
            'moreCareStatus': moreCareStatusText,

          if (moreCareRequestIdText.isNotEmpty)
            'moreCareRequestId': moreCareRequestIdText,

          if (moreCareTemporaryUntilValue != null)
            'moreCareTemporaryUntil': moreCareTemporaryUntilValue,

          if (moreCareSlotMap.isNotEmpty) 'moreCareSlot': moreCareSlotMap,
        };

        final existingAtSameTime = next[key];
        if (existingAtSameTime is Map<String, dynamic>) {
          final existingDocId =
              (existingAtSameTime['docId'] ?? '').toString().trim();
          final duplicateIds = <String>{
            ...((existingAtSameTime['duplicateDocIds'] as List?) ?? const [])
                .map((id) => id.toString().trim()),
          }..removeWhere((id) => id.isEmpty);

          if (_hasSameScheduleIdentity(existingAtSameTime, nextItem)) {
            duplicateIds.add(docId);
            existingAtSameTime['duplicateDocIds'] = duplicateIds.toList();
            next[key] = existingAtSameTime;

            if (kDebugMode) {
              debugPrint(
                '[MTF_SCHEDULE_STREAM] exactDuplicate key=$key '
                'primaryDocId=$existingDocId duplicateDocIds=${duplicateIds.join(',')}',
              );
            }
          } else {
            final conflictIds = <String>{
              ...((existingAtSameTime['conflictingDocIds'] as List?) ??
                      const [])
                  .map((id) => id.toString().trim()),
              docId,
            }..removeWhere((id) => id.isEmpty);
            existingAtSameTime['conflictingDocIds'] = conflictIds.toList();
            next[key] = existingAtSameTime;

            if (kDebugMode) {
              debugPrint(
                '[MTF_SCHEDULE_STREAM] unsafeTimeCollision key=$key '
                'primaryDocId=$existingDocId conflictDocIds=${conflictIds.join(',')}',
              );
            }
          }
        } else {
          next[key] = nextItem;
        }
      }

      if (!mounted) return;

      final shouldUpdate = !mapEquals(scheduleData, next);

      if (!shouldUpdate && _scheduleStreamReady) {
        return;
      }

      setState(() {
        _scheduleStreamReady = true;

        if (shouldUpdate) {
          scheduleData
            ..clear()
            ..addAll(next);
        }
      });

      unawaited(_refreshScheduleCountsFromMembers());
      _queueHomeWidgetSync(source: 'scheduleSnapshot');
      _queueNotificationSync();
      _updateBannerState();
    }, onError: (Object error, StackTrace stackTrace) {
      if (kDebugMode) {
        final errorCode = error is FirebaseException
            ? error.code
            : error.runtimeType.toString();
        debugPrint(
          '[MTF_SCHEDULE_STREAM] binding=$bindingId result=failure '
          'errorCode=$errorCode',
        );
      }
      if (!mounted || bindingId != _scheduleStreamBindingId) return;
      setState(() {
        _scheduleStreamReady = true;
        scheduleData.clear();
      });
      _queueHomeWidgetSync(source: 'scheduleSnapshot');
    });
  }

  Future<Set<String>> _deletedMemberIdsFromScheduleDocs(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    return HomeDeletedMemberScheduleService.deletedMemberIdsFromScheduleDocs(
      docs,
      personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : '',
    );
  }

  Future<void> _cleanupDeletedMemberScheduleLinks({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required Set<String> deletedMemberIds,
  }) async {
    try {
      await HomeDeletedMemberScheduleService.cleanupDeletedMemberScheduleLinks(
        docs: docs,
        deletedMemberIds: deletedMemberIds,
      );
    } catch (e) {
      debugPrint('삭제 회원 스케줄 연결 정리 실패: $e');
    }
  }

  AppTier _resolveAppTier(String tier) {
    switch (parsePersonalTierLabel(tier)) {
      case 'Beginner':
        return AppTier.beginner;
      case 'Amateur':
        return AppTier.amateur;
      case 'Semi-Pro':
        return AppTier.semiPro;
      case 'Pro':
        return AppTier.pro;
      case 'Master':
        return AppTier.master;
      case 'Grand Prix':
        return AppTier.grandPrix;
      default:
        return AppTier.beginner;
    }
  }

  int _homeMaxTierRankFromValues(List<dynamic> values) {
    var maxRank = 0;

    for (final value in values) {
      final rank = AppTierAccessService.tierRankFromText(
        (value ?? '').toString(),
      );

      if (rank > maxRank) {
        maxRank = rank;
      }
    }

    return maxRank;
  }

  bool _homeBoolFromAny(dynamic value) {
    if (value is bool) return value;

    final text = (value ?? '').toString().trim().toLowerCase();

    return text == 'true' ||
        text == '1' ||
        text == 'yes' ||
        text == 'y' ||
        text == 'on' ||
        text == 'linked' ||
        text == 'connected';
  }

  String _resolveTierNameForBanner({
    required Map<String, dynamic> profileData,
    required int activeMemberCount,
    required int kakaoCardLinkedMemberCount,
    required int contractSignedMemberCount,
  }) {
    if (_isPersonalWorkspace) {
      return parsePersonalTierLabel(profileData['tier']) ?? '';
    }
    final profileCompleted = _homeBoolFromAny(
      profileData['profileCompleted'] ??
          profileData['trainerInfoDone'] ??
          profileData['myInfoCompleted'],
    );

    final kakaoLinked = _homeBoolFromAny(
      profileData['kakaoLinked'] ??
          profileData['kakaoConnected'] ??
          profileData['kakaoSyncEnabled'] ??
          profileData['hasKakaoAccount'],
    );

    final earnedRank = _homeEarnedTierRank(
      profileCompleted: profileCompleted,
      kakaoLinked: kakaoLinked,
      activeMemberCount: activeMemberCount,
      kakaoCardLinkedMemberCount: kakaoCardLinkedMemberCount,
      contractSignedMemberCount: contractSignedMemberCount,
    );

    final supportRank = _homeMaxTierRankFromValues([
      profileData['supportTier'],
      profileData['subscriptionTier'],
      profileData['paidTier'],
      profileData['sponsorTier'],
      profileData['planTier'],
      profileData['plan'],
    ]);

    final organizationRank = _homeMaxTierRankFromValues([
      profileData['organizationTier'],
      profileData['orgTier'],
      profileData['centerTier'],
    ]);

    final storedRank = _homeMaxTierRankFromValues([
      profileData['effectiveTier'],
      profileData['currentTier'],
      profileData['earnedTier'],
      profileData['appTier'],
      profileData['tier'],
    ]);

    final sponsorRank = profileData['isSponsor'] == true ? 2 : 0;

    final effectiveRank = [
      earnedRank,
      supportRank,
      organizationRank,
      storedRank,
      sponsorRank,
    ].fold<int>(0, (maxRank, rank) {
      return rank > maxRank ? rank : maxRank;
    });

    return AppTierAccessService.tierLabelFromRank(effectiveRank);
  }

  bool _isTrainerInfoDoneForBanner(Map<String, dynamic> data) {
    if (_isPersonalWorkspace) {
      return PersonalTierProgress.fromProfile(data).teacherInfoCompleted;
    }
    final requiredValues = [
      data['name'],
      data['phone'],
      data['lessonSpecialty'],
      data['gymName'],
    ];

    return requiredValues.every(
      (v) => v != null && v.toString().trim().isNotEmpty,
    );
  }

  void _updateBannerState({
    Map<String, dynamic>? profileData,
    int? memberCount,
    int? moreSenseCount,
    List<HomeMoreSenseContext>? moreSenseItems,
    int? kakaoCardLinkedMemberCount,
    int? contractSignedMemberCount,
    bool? hasProduct,
    bool? profileReady,
    bool? membersReady,
    bool? productsReady,
  }) {
    if (!mounted) return;

    final nextProfileData = profileData ?? _bannerProfileData;
    final nextMemberCount = memberCount ?? _bannerMemberCount;
    final nextHasProduct = hasProduct ?? _hasProduct;
    final nextMoreSenseCount = moreSenseCount ?? _moreSenseMemberCount;
    final nextKakaoCardLinkedCount =
        kakaoCardLinkedMemberCount ?? _kakaoCardLinkedMemberCount;
    final nextContractSignedCount =
        contractSignedMemberCount ?? _contractSignedMemberCount;

    final nextTierName = _resolveTierNameForBanner(
      profileData: nextProfileData,
      activeMemberCount: nextMemberCount,
      kakaoCardLinkedMemberCount: nextKakaoCardLinkedCount,
      contractSignedMemberCount: nextContractSignedCount,
    );

    final nextTrainerInfoDone = _isTrainerInfoDoneForBanner(nextProfileData);
    final nextTrainerName = _trainerHeaderNameFromData(nextProfileData);
    if (kDebugMode && _isPersonalWorkspace) {
      final progress = PersonalTierProgress.fromProfile(nextProfileData);
      debugPrint(progress.debugLog(source: 'home'));
    }

    setState(() {
      _bannerProfileData = nextProfileData;
      _bannerMemberCount = nextMemberCount;
      _moreSenseMemberCount = nextMoreSenseCount;
      if (moreSenseItems != null) {
        _moreSenseItems =
            List<HomeMoreSenseContext>.unmodifiable(moreSenseItems);
      }
      _hasProduct = nextHasProduct;
      _isSponsor = nextProfileData['isSponsor'] == true;
      _trainerInfoDone = nextTrainerInfoDone;
      _bannerTrainerName = nextTrainerName;
      _currentAppTier = _resolveAppTier(nextTierName);
      _kakaoCardLinkedMemberCount = nextKakaoCardLinkedCount;
      _contractSignedMemberCount = nextContractSignedCount;

      if (profileReady != null) _bannerProfileReady = profileReady;
      if (membersReady != null) _bannerMembersReady = membersReady;
      if (productsReady != null) _bannerProductsReady = productsReady;
    });
    _maybeClaimPendingTierCelebration(nextProfileData);
  }

  void _maybeClaimPendingTierCelebration(Map<String, dynamic> profile) {
    if (!_isPersonalWorkspace || !mounted) return;
    final transitionId =
        (profile['lastTierTransitionId'] ?? '').toString().trim();
    final celebratedId =
        (profile['lastCelebratedTierTransitionId'] ?? '').toString().trim();
    final targetTier =
        (profile['lastTierTransitionTo'] ?? '').toString().trim();
    if (transitionId.isEmpty ||
        transitionId == celebratedId ||
        targetTier != 'Amateur') {
      return;
    }
    unawaited(_claimAndShowAmateurCelebration(transitionId));
  }

  void _bindBannerDataStreams() {
    _bannerProfileSub?.cancel();
    _bannerMembersSub?.cancel();
    _bannerProductsSub?.cancel();

    _bannerProfileSub = _trainerProfileRef
        .snapshots(includeMetadataChanges: true)
        .listen((snap) {
      final profileData = snap.data() ?? <String, dynamic>{};
      final fromCache = snap.metadata.isFromCache;
      final shouldApply = !_isPersonalWorkspace ||
          shouldApplyPersonalProfileSnapshot(
            hasInitialProfile: _hasInitialPersonalProfileData,
            fromCache: fromCache,
          );
      var reason = !_isPersonalWorkspace
          ? 'legacy_snapshot'
          : _hasInitialPersonalProfileData && fromCache
              ? 'initial_profile_protect_cached_snapshot'
              : fromCache
                  ? 'cached_snapshot_without_initial_profile'
                  : 'server_snapshot';
      if (_isPersonalWorkspace) {
        final rawTier = profileData['tier'];
        final parsedTier = parsePersonalTierLabel(rawTier);
        final success = snap.exists && parsedTier != null;
        if (!shouldApply) {
          _logPersonalProfileSnapshot(
            snap: snap,
            applied: false,
            reason: reason,
          );
          return;
        }
        if (kDebugMode) {
          debugPrint(
            '[MTF_TIER_READ] uid=$_personalOwnerUid '
            'environment=${AppEnvironmentConfig.environmentName} '
            'profileExists=${snap.exists} '
            'source=trainer_profiles/$_personalOwnerUid '
            'rawTier=${(rawTier ?? '').toString()} '
            'parsedTier=${parsedTier ?? 'none'} '
            'result=${success ? 'success' : 'failure'} errorCode=none',
          );
        }
        if (!success) {
          reason = 'invalid_personal_profile';
          _logPersonalProfileSnapshot(
            snap: snap,
            applied: false,
            reason: reason,
          );
          if (mounted) {
            setState(() {
              _bannerTierReadFailed = true;
              _bannerProfileReady = false;
            });
          }
          return;
        }
        _bannerTierReadFailed = false;
      }
      _logPersonalProfileSnapshot(snap: snap, applied: true, reason: reason);
      _updateBannerState(profileData: profileData, profileReady: true);
    }, onError: (Object error) {
      if (kDebugMode && _isPersonalWorkspace) {
        final code = error is FirebaseException
            ? error.code
            : error.runtimeType.toString();
        debugPrint(
          '[MTF_TIER_READ] uid=$_personalOwnerUid '
          'environment=${AppEnvironmentConfig.environmentName} '
          'profileExists=unknown source=trainer_profiles/$_personalOwnerUid '
          'rawTier=unknown parsedTier=none result=failure errorCode=$code',
        );
      }
      if (mounted && _isPersonalWorkspace && !_hasInitialPersonalProfileData) {
        setState(() {
          _bannerTierReadFailed = true;
          _bannerProfileReady = false;
        });
      }
    });

    _bannerMembersSub =
        _ownedCollectionQuery('members').snapshots().listen((snapshot) {
      int activeMembers = 0;

      final kakaoCardLinkedMemberIds = <String>{};
      final contractSignedMemberIds = <String>{};
      final moreSenseMemberIds = <String>{};
      final moreSenseItems = <HomeMoreSenseContext>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        if (data['isDeleted'] == true) continue;
        if ((data['deleteStatus'] ?? '').toString() == 'pending_delete') {
          continue;
        }

        final name = (data['name'] ?? '').toString().trim();
        final phone = (data['phone'] ?? '').toString().trim();

        final hasActiveMemberCore = name.isNotEmpty || phone.isNotEmpty;

        if (hasActiveMemberCore) {
          activeMembers++;
        }

        if (_homeHasMoreSenseSignal(data)) {
          moreSenseMemberIds.add(doc.id);
        }
        moreSenseItems.addAll(_homeMoreSenseContexts(doc.id, data));

        if (_homeHasKakaoCardLinkedMember(data)) {
          kakaoCardLinkedMemberIds.add(doc.id);
        }

        if (_homeHasSignedContractMember(data)) {
          contractSignedMemberIds.add(doc.id);
        }
      }

      final kakaoCardLinkedMembers = kakaoCardLinkedMemberIds.length;
      final contractSignedMembers = contractSignedMemberIds.length;
      final serverMemberCount = _isPersonalWorkspace
          ? ((_bannerProfileData['validMemberCount'] ??
                  _bannerProfileData['lifetimeQualifiedMemberCount']) as num?)
              ?.toInt()
          : null;

      _updateBannerState(
        memberCount: serverMemberCount ?? activeMembers,
        moreSenseCount: moreSenseMemberIds.length,
        moreSenseItems: moreSenseItems,
        kakaoCardLinkedMemberCount: kakaoCardLinkedMembers,
        contractSignedMemberCount: contractSignedMembers,
        membersReady: true,
      );

      if (!_isPersonalWorkspace) {
        unawaited(
          _syncTierAccessCacheToProfile(
            activeMemberCount: activeMembers,
            kakaoCardLinkedMemberCount: kakaoCardLinkedMembers,
            contractSignedMemberCount: contractSignedMembers,
          ),
        );
      }
    });

    if (_isPersonalWorkspace) {
      _updateBannerState(hasProduct: false, productsReady: true);
      return;
    }
    _bannerProductsSub = FirebaseFirestore.instance
        .collection('lesson_products')
        .snapshots()
        .listen((snapshot) {
      final hasProduct = snapshot.docs.any((doc) {
        final data = doc.data();
        return data['isDeleted'] != true;
      });

      _updateBannerState(
        hasProduct: hasProduct,
        productsReady: true,
      );
    });
  }

  void _logPersonalProfileSnapshot({
    required DocumentSnapshot<Map<String, dynamic>> snap,
    required bool applied,
    required String reason,
  }) {
    if (!kDebugMode || !_isPersonalWorkspace) return;
    final data = snap.data() ?? const <String, dynamic>{};
    final updatedAt = data['updatedAt'];
    final updatedAtText = updatedAt is Timestamp
        ? updatedAt.toDate().toIso8601String()
        : updatedAt is DateTime
            ? updatedAt.toIso8601String()
            : updatedAt?.toString() ?? 'null';
    debugPrint(
      '[MTF_PROFILE_SNAPSHOT] uid=$_personalOwnerUid '
      'fromCache=${snap.metadata.isFromCache} '
      'hasPendingWrites=${snap.metadata.hasPendingWrites} '
      'nickname=${(data['nickname'] ?? '').toString().trim()} '
      'updatedAt=$updatedAtText applied=$applied reason=$reason',
    );
  }

  // -------- 주간 레슨일정 범위 관련 상수 --------
  // 이번 주 기준으로 뒤로 4주, 앞으로 4주
  static const int _minWeekOffset = -4;
  static const int _maxWeekOffset = 4;

  // 전체 페이지 수 = -4 ~ +4 → 9
  static const int _totalWeeks = _maxWeekOffset - _minWeekOffset + 1; // 9

  // index(0~8) 중에서 "이번 주"가 되는 인덱스
  // offset = 0 이 되게 하려면  index + _minWeekOffset = 0
  // → index = -_minWeekOffset
  static const int _todayWeekIndex = -_minWeekOffset; // 4

  // ---------- 공통 유틸 ----------
  String _trainerHeaderNameFromData(Map<String, dynamic>? data) {
    final nickname = (data?['nickname'] ?? '').toString().trim();
    final displayName = (data?['displayName'] ?? '').toString().trim();
    final name = (data?['name'] ?? '').toString().trim();

    if (_isPersonalWorkspace && nickname.isNotEmpty) return nickname;
    final value = displayName.isNotEmpty ? displayName : name;
    return value.isEmpty && !_isPersonalWorkspace ? '강사님' : value;
  }

  String _trainerShortNameFromData(Map<String, dynamic>? data) {
    final savedShortName = (data?['shortName'] ?? '').toString().trim();
    if (savedShortName.isNotEmpty) return savedShortName;

    final headerName = _trainerHeaderNameFromData(data);
    return _buildTrainerShortName(headerName);
  }

  String _buildTrainerShortName(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return '강';

    final normalized =
        text.endsWith('강사님') ? text.replaceAll('강사님', '').trim() : text;

    if (normalized.isEmpty) {
      return text.length <= 2 ? text : text.substring(0, 2);
    }

    return normalized.length <= 2 ? normalized : normalized.substring(0, 2);
  }

  /// PageView index(0~8) → weekOffset(-4~4) 변환
  int _indexToOffset(int index) {
    return _minWeekOffset + index;
  }

  DateTime _mondayOfWeek(DateTime base) {
    return DateTime(base.year, base.month, base.day)
        .subtract(Duration(days: base.weekday - 1));
  }

  DateTime _dateForCell(int weekOffset, String day, String time) {
    final dayIndex = _weekDaysAll.indexOf(day);
    final monday =
        _mondayOfWeek(currentTime).add(Duration(days: weekOffset * 7));
    final date = monday.add(Duration(days: dayIndex));

    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String _normalizePhone(String value) {
    return search_utils.normalizePhone(value);
  }

  int? _toNullableInt(dynamic value) {
    if (value == null) return null;

    if (value is int) return value;
    if (value is num) return value.toInt();

    final text = value.toString().replaceAll(RegExp(r'[^0-9-]'), '');
    if (text.trim().isEmpty) return null;

    return int.tryParse(text);
  }

  String _makeKey(int weekOffset, String day, String time) {
    final dt = _dateForCell(weekOffset, day, time);
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d-$h:$min';
  }

  bool _hasLinkedMemberConnection({
    String? memberId,
    String? phone,
  }) {
    final cleanMemberId = memberId?.trim() ?? '';

    // 회원카드/레슨일지 이동은 memberId가 있을 때만 연결된 회원으로 봅니다.
    // phone이나 이름만으로 연결 판단하면 동명이인/예전 데이터에서 잘못 열릴 수 있어요.
    return cleanMemberId.isNotEmpty;
  }

  bool _isManualScheduleMember(Map<String, dynamic>? session) {
    if (session == null) return false;

    final memberId = (session['memberId'] ?? '').toString().trim();
    final phone = _normalizePhone((session['phone'] ?? '').toString());

    return memberId.isEmpty && phone.isEmpty;
  }

  Map<String, dynamic> _buildWeekSlice(int weekOffset) {
    final Map<String, dynamic> result = {};

    final weekStart =
        _mondayOfWeek(currentTime).add(Duration(days: weekOffset * 7));
    final weekEnd = weekStart.add(const Duration(days: 7));

    scheduleData.forEach((key, value) {
      if (value is! Map<String, dynamic>) return;

      final docId = (value['docId'] ?? '').toString().trim();

      if (docId.isNotEmpty && _isScheduleDocTemporarilyHidden(docId)) {
        return;
      }

      final rawStartAt = value['startAt'];
      if (rawStartAt is! DateTime) return;

      if (rawStartAt.isBefore(weekStart) || !rawStartAt.isBefore(weekEnd)) {
        return;
      }

      final day = _weekDaysAll[rawStartAt.weekday - 1];
      final time = _timeStringFromDateTime(rawStartAt);

      result['$day-$time'] = {
        ...Map<String, dynamic>.from(value),
        'day': day,
        'time': time,
        'startAt': rawStartAt,
      };
    });

    return result;
  }

  Map<String, dynamic> _buildScheduleExampleSlice(int weekOffset) {
    if (!_shouldShowScheduleExamples(weekOffset)) {
      return {};
    }

    final monday =
        _mondayOfWeek(currentTime).add(Duration(days: weekOffset * 7));

    DateTime exampleDate(int dayOffset, int hour, int minute) {
      final date = monday.add(Duration(days: dayOffset));
      return DateTime(date.year, date.month, date.day, hour, minute);
    }

    Map<String, dynamic> exampleItem({
      required String id,
      required DateTime startAt,
      required int minutes,
      required String name,
      required String type,
      required String memo,
      required String remainingSessions,
      required String totalSessions,
    }) {
      final endAt = startAt.add(Duration(minutes: minutes));
      final day = _weekDaysAll[startAt.weekday - 1];

      return {
        'docId': id,
        'isExample': true,
        'startAt': startAt,
        'endAt': endAt,
        'day': day,
        'time': _timeStringFromDateTime(startAt),
        'endTime': _timeStringFromDateTime(endAt),
        'name': name,
        'type': type,
        'typeName': type,
        'typeColorHex': '#9CA3AF',
        'attended': false,
        'remainingSessions': remainingSessions,
        'totalSessions': totalSessions,
        'memo': memo,
      };
    }

    final examples = <Map<String, dynamic>>[
      exampleItem(
        id: 'example_schedule_1',
        startAt: exampleDate(0, 9, 0),
        minutes: 50,
        name: '김모어',
        type: 'PT',
        memo: '하체운동 · 무릎 체크',
        remainingSessions: '9',
        totalSessions: '10',
      ),
      exampleItem(
        id: 'example_schedule_2',
        startAt: exampleDate(2, 14, 0),
        minutes: 50,
        name: '박회원',
        type: '필라테스',
        memo: '코어 안정화',
        remainingSessions: '4',
        totalSessions: '8',
      ),
      exampleItem(
        id: 'example_schedule_3',
        startAt: exampleDate(4, 18, 0),
        minutes: 60,
        name: '이예시',
        type: '그룹레슨',
        memo: '그룹 컨디셔닝',
        remainingSessions: '2',
        totalSessions: '12',
      ),
    ];

    final result = <String, dynamic>{};

    for (final item in examples) {
      final startAt = item['startAt'];
      if (startAt is! DateTime) continue;

      final key = '${item['day']}-${item['time']}';
      result[key] = item;
    }

    return result;
  }

  List<String> get _weekDaysAll => const ["월", "화", "수", "목", "금", "토", "일"];

  List<String> get _weekDays {
    const weekdayDays = ["월", "화", "수", "목", "금"];
    const weekendDays = ["토", "일"];
    switch (dayFilter) {
      case "weekday":
        return weekdayDays;
      case "weekend":
        return weekendDays;
      default:
        return _weekDaysAll;
    }
  }

  void _ensureTimeRowMinutes() {
    for (int h = startHour; h < endHour; h++) {
      _timeRowMinutes.putIfAbsent(h, () => defaultMinute);
    }
  }

  List<String> get _timeSlots {
    _ensureTimeRowMinutes();
    return List<String>.generate(
      endHour - startHour,
      (i) {
        final hour = startHour + i;
        final minute = _timeRowMinutes[hour] ?? defaultMinute;
        return "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
      },
    );
  }

  void _showSnack(
    String msg, {
    Duration duration = const Duration(milliseconds: 1400),
  }) {
    if (!mounted) return;

    AifcInteraction.toast(
      context: context,
      message: msg,
      duration: duration,
      bottomOffset: 110,
    );
  }

  void _hideActionToast() {
    AifcInteraction.hideToast();
  }

  void _showActionToast(
    BuildContext targetContext,
    String message, {
    double bottomOffset = 76,
    Duration duration = const Duration(milliseconds: 1400),
  }) {
    AifcInteraction.toast(
      context: targetContext,
      message: message,
      bottomOffset: bottomOffset,
      duration: duration,
    );
  }

  Future<void> _loadLessonNotificationNudgePrefs() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _lessonNotificationNudgeAnswered =
          prefs.getBool(_lessonNotificationNudgePrefsKey) ?? false;
    });
  }

  Future<void> _loadNotificationEnabledState() async {
    final enabled = await _lessonNotificationController.loadEnabled();

    if (!mounted) return;

    setState(() {
      _notificationsOn = enabled;
    });
  }

  void _hideAifcNotificationToast() {
    _aifcNotificationToastTimer?.cancel();
    _aifcNotificationToastTimer = null;
    _aifcNotificationToastEntry?.remove();
    _aifcNotificationToastEntry = null;
  }

  void _showAifcNotificationToast({
    required String title,
    required String subtitle,
    double bottomOffset = 110,
    Duration duration = const Duration(milliseconds: 1900),
  }) {
    final overlay = Overlay.of(context);

    _hideAifcNotificationToast();

    _aifcNotificationToastEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: IgnorePointer(
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: bottomOffset,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: Material(
                          color: Colors.transparent,
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 11, 13, 11),
                            decoration: BoxDecoration(
                              color: const Color(0xFF111827)
                                  .withValues(alpha: 0.94),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.22),
                                  blurRadius: 18,
                                  offset: const Offset(0, 7),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const AifcAvatar(
                                  size: 34,
                                  isAnimating: true,
                                  backgroundColor: Colors.white,
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12.8,
                                          fontWeight: FontWeight.w900,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        subtitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.72),
                                          fontSize: 10.8,
                                          fontWeight: FontWeight.w600,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
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
        );
      },
    );

    overlay.insert(_aifcNotificationToastEntry!);
    _aifcNotificationToastTimer = Timer(duration, _hideAifcNotificationToast);
  }

  Future<void> _toggleLessonNotificationFromHeader() async {
    final result = await _lessonNotificationController.toggle(
      currentlyEnabled: _notificationsOn,
    );

    if (!mounted) return;

    setState(() {
      _notificationsOn = result.enabled;
      _lessonNotificationNudgeAnswered = true;
    });

    if (result.enabled) {
      _queueNotificationSync(delay: Duration.zero);
    }

    _showAifcNotificationToast(
      title: result.title,
      subtitle: result.subtitle,
    );
  }

  Future<void> _loadCustomerCardNudgePrefs() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _customerCardNudgeAnswered =
          prefs.getBool(_customerCardNudgePrefsKey) ?? false;
    });
  }

  Future<void> _setCustomerCardNudgeAnswered() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_customerCardNudgePrefsKey, true);

    if (!mounted) return;

    setState(() {
      _customerCardNudgeAnswered = true;
    });
  }

  Future<void> _maybeShowCustomerCardNudge({
    required bool savedSuccessfully,
    required bool isEditMode,
    required bool isLinkedMember,
    required bool shouldOfferCustomerCard,
    required String memberName,
    String? memberPhone,
    String? scheduleDocId,
  }) async {
    if (!savedSuccessfully) {
      _logTierReconcileSkipped('scheduleCreate');
      return;
    }
    if (isEditMode) return;
    if (isLinkedMember) return;
    if (!shouldOfferCustomerCard) return;
    if (_customerCardNudgeAnswered) return;

    final cleanName = memberName.trim();
    if (cleanName.isEmpty) return;

    await Future.delayed(const Duration(milliseconds: 360));

    if (!mounted) return;

    final shouldCreateCard = await HomeAifcNudgeSheet.show(
      context: context,
      title: '${aifcPersonLabel(cleanName)}을 고객카드로 관리해볼까요?',
      message: '지금은 이름만으로 레슨을 잡아뒀어요.\n'
          '고객카드를 만들어두면 레슨기록, 상담메모, 결제정보를 한곳에서 관리할 수 있어요.\n\n'
          '지금 바쁘시면 나중에 만들어도 괜찮아요.',
      secondaryLabel: '나중에',
      primaryLabel: '고객카드 만들기',
      primaryColor: kPrimaryColor,
    );

    if (!mounted || shouldCreateCard == null) return;

    await _setCustomerCardNudgeAnswered();

    if (!mounted) return;

    if (!shouldCreateCard) {
      _showActionToast(
        context,
        '알겠습니다. 필요할 때 고객카드로 연결해드릴게요.',
        bottomOffset: 110,
      );
      return;
    }

    await Future.delayed(const Duration(milliseconds: 140));

    if (!mounted) return;

    await _openClientCardFromManualSchedule(
      memberName: cleanName,
      phone: memberPhone,
      scheduleDocId: scheduleDocId,
    );
  }

  Future<void> _runAfterLessonSavedNudges({
    required bool savedSuccessfully,
    required bool savedFromEditMode,
    required bool savedIsLinkedMember,
    required bool shouldOfferCustomerCard,
    required String savedMemberName,
    required int createdScheduleCount,
    String? savedMemberPhone,
    String? savedScheduleDocId,
  }) async {
    if (!savedSuccessfully) return;

    if (_isPersonalWorkspace && !savedFromEditMode) {
      await _maybeShowFirstLessonGuide(
        createdScheduleCount: createdScheduleCount,
        memberName: savedMemberName,
        memberPhone: savedMemberPhone,
        scheduleDocId: savedScheduleDocId,
      );
      if (!mounted) return;
      try {
        await _reconcilePersonalTierAfterServerWrite('scheduleCreate');
      } catch (_) {
        // 저장은 이미 성공했습니다. 승급 진행률은 다음 시작/저장 때 self-heal 합니다.
      }
    }

    await _maybeShowLessonNotificationNudge(
      isEditMode: savedFromEditMode,
      savedSuccessfully: savedSuccessfully,
    );

    if (!mounted) return;

    if (!_isPersonalWorkspace) {
      await _maybeShowCustomerCardNudge(
        savedSuccessfully: savedSuccessfully,
        isEditMode: savedFromEditMode,
        isLinkedMember: savedIsLinkedMember,
        shouldOfferCustomerCard: shouldOfferCustomerCard,
        memberName: savedMemberName,
        memberPhone: savedMemberPhone,
        scheduleDocId: savedScheduleDocId,
      );
    }
  }

  Future<Map<String, dynamic>?> _reconcilePersonalTierAfterServerWrite(
    String source,
  ) async {
    if (!_isPersonalWorkspace) return null;
    if (kDebugMode) {
      debugPrint(
        '[MTF_TIER_RECONCILE_TRIGGER] source=$source '
        'serverWriteSucceeded=true action=call',
      );
    }
    try {
      final result = await AppAccountService.instance.reconcilePersonalTier();
      if (result['promoted'] == true) {
        final transitionId = (result['transitionId'] ?? '').toString().trim();
        if (kDebugMode) {
          debugPrint(
            '[MTF_TIER_TRANSITION] from=Beginner to=Amateur '
            'transitionId=${transitionId.isEmpty ? 'missing' : transitionId} '
            'result=${transitionId.isEmpty ? 'failure' : 'success'}',
          );
        }
        if (transitionId.isNotEmpty && mounted) {
          await _claimAndShowAmateurCelebration(transitionId);
        }
      }
      return result;
    } catch (_) {
      if (kDebugMode) {
        debugPrint(
          '[MTF_TIER_RECONCILE_TRIGGER] source=$source '
          'serverWriteSucceeded=true action=call result=failure',
        );
      }
      return null;
    }
  }

  void _logTierReconcileSkipped(String source) {
    if (!kDebugMode || !_isPersonalWorkspace) return;
    debugPrint(
      '[MTF_TIER_RECONCILE_TRIGGER] source=$source '
      'serverWriteSucceeded=false action=skip',
    );
  }

  Future<void> _claimAndShowAmateurCelebration(String transitionId) async {
    if (_tierCelebrationClaimInFlight || !mounted) return;
    _tierCelebrationClaimInFlight = true;
    try {
      final claim =
          await AppAccountService.instance.claimTierCelebration(transitionId);
      final claimed = claim['claimed'] == true;
      if (kDebugMode) {
        debugPrint(
          '[MTF_TIER_CELEBRATION] tier=Amateur '
          'transitionId=$transitionId '
          'claim=${claimed ? 'success' : 'alreadyClaimed'} '
          'action=${claimed ? 'show' : 'skip'}',
        );
      }
      if (!claimed || !mounted) return;
      final openMembers = await AifcTierCelebrationSheet.show(
        context: context,
        trainerName: _bannerTrainerName,
        upgrade: AifcTierUpgrade.beginnerToAmateur,
      );
      if (openMembers == true && mounted) await _openMembersPage();
    } catch (_) {
      if (kDebugMode) {
        debugPrint(
          '[MTF_TIER_CELEBRATION] tier=Amateur '
          'transitionId=$transitionId claim=failure action=skip',
        );
      }
    } finally {
      _tierCelebrationClaimInFlight = false;
    }
  }

  Future<void> _maybeShowFirstLessonGuide({
    required int createdScheduleCount,
    required String memberName,
    String? memberPhone,
    String? scheduleDocId,
  }) async {
    try {
      final raw = await MtfFirebaseFunctions.call(
        'claimFirstLessonGuide',
        parameters: <String, dynamic>{
          'createdScheduleCount': createdScheduleCount,
        },
      );
      final result = raw is Map
          ? Map<String, dynamic>.from(raw)
          : const <String, dynamic>{};
      final shouldShow = result['shouldShow'] == true;
      final alreadyShown = result['alreadyShown'] == true;
      if (kDebugMode) {
        debugPrint(
          '[MTF_FIRST_LESSON_GUIDE] uid=$_personalOwnerUid '
          'workspace=personal isFirstSuccessfulCreate=$shouldShow '
          'alreadyShown=$alreadyShown action=${shouldShow ? 'show' : 'skip'} '
          'reason=${shouldShow ? 'server_claimed' : alreadyShown ? 'already_shown' : 'no_server_schedule'}',
        );
      }
      if (!shouldShow || !mounted) return;
      final access = await _loadCurrentTierAccess();
      if (!mounted) return;
      final action = await HomeFirstLessonGuideChatSheet.show(
        context: context,
        canCreateCustomerCard: AppTierAccessService.canUseFeature(
          access,
          AppTierFeatureKey.customerCardCreate,
        ),
      );
      if (!mounted || action != HomeFirstLessonGuideAction.openCustomerCard) {
        return;
      }
      await _openClientCardFromManualSchedule(
        memberName: memberName,
        phone: memberPhone,
        scheduleDocId: scheduleDocId,
      );
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[MTF_FIRST_LESSON_GUIDE] uid=$_personalOwnerUid '
          'workspace=personal isFirstSuccessfulCreate=false '
          'alreadyShown=unknown action=skip reason=${error.runtimeType}',
        );
      }
    }
  }

  Future<void> _setLessonNotificationPreference(bool enabled) async {
    final result = await _lessonNotificationController.setEnabled(enabled);

    if (!mounted) return;

    setState(() {
      _lessonNotificationNudgeAnswered = true;
      _notificationsOn = result.enabled;
    });

    if (result.enabled) {
      _queueNotificationSync(delay: Duration.zero);
    }

    _showAifcNotificationToast(
      title: result.title,
      subtitle: result.subtitle,
    );
  }

  Future<void> _maybeShowLessonNotificationNudge({
    required bool isEditMode,
    required bool savedSuccessfully,
  }) async {
    if (!savedSuccessfully) return;
    if (isEditMode) return;
    if (_lessonNotificationNudgeAnswered) return;

    await Future.delayed(const Duration(milliseconds: 420));

    if (!mounted) return;

    final wantsNotification = await HomeAifcNudgeSheet.show(
      context: context,
      title: '레슨 전에 제가 체크사항 말씀드릴까요?',
      message: '수업 시간을 놓치지 않도록 휴대폰에 잠깐 신호보내드릴 수 있어요.\n'
          '불편하시면 따로 알려드리지 않겠습니다. 필요하실때 알려주세요',
      secondaryLabel: '다음에',
      primaryLabel: '알려주세요',
      primaryColor: kPrimaryColor,
    );

    if (!mounted || wantsNotification == null) return;

    await _setLessonNotificationPreference(wantsNotification);
  }

  void _showError(String msg) => _showSnack(msg);

  String _widgetDayFilterLabel() {
    switch (dayFilter) {
      case 'weekday':
        return '주5';
      case 'weekend':
        return '주2';
      default:
        return '주7';
    }
  }

  String _timeLabelFromDate(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _absoluteKeyFromDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d-$h:$min';
  }

  String _scheduleDocIdFromDate(DateTime dt, String day) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$y$m$d-$h$min-$day';
  }

  String _actualScheduleTargetDocumentId(DateTime dt, String day) {
    return homeScheduleScopedDocumentId(
      _scheduleDocIdFromDate(dt, day),
      _isPersonalWorkspace ? _personalOwnerUid : null,
    );
  }

  ScheduleItem? _scheduleItemFromRaw(dynamic raw) {
    if (raw is! Map<String, dynamic>) return null;

    return ScheduleItem.fromMap(
      raw,
      defaultDurationMinutes: _defaultLessonDurationMinutes,
    );
  }

  List<ScheduleItem> _allScheduleItems() {
    final items = <ScheduleItem>[];

    for (final raw in scheduleData.values) {
      if (raw is Map<String, dynamic>) {
        final docId = (raw['docId'] ?? '').toString().trim();

        if (docId.isNotEmpty && _isScheduleDocTemporarilyHidden(docId)) {
          continue;
        }

        if (_isScheduleDataDeleted(raw)) {
          continue;
        }
      }

      final item = _scheduleItemFromRaw(raw);
      if (item != null) {
        items.add(item);
      }
    }

    items.sort((a, b) => a.startAt.compareTo(b.startAt));
    return items;
  }

  List<ScheduleItem> _scheduleItemsForDay(DateTime dayDate) {
    final start = DateTime(dayDate.year, dayDate.month, dayDate.day);
    final end = start.add(const Duration(days: 1));

    return _allScheduleItems().where((item) {
      return !item.startAt.isBefore(start) && item.startAt.isBefore(end);
    }).toList();
  }

  List<ScheduleItem> _scheduleItemsForToday() {
    final now = currentTime;
    return _scheduleItemsForDay(DateTime(now.year, now.month, now.day));
  }

  List<ScheduleItem> _scheduleItemsForWeek(int weekOffset) {
    final start =
        _mondayOfWeek(currentTime).add(Duration(days: weekOffset * 7));
    final end = start.add(const Duration(days: 7));

    return _allScheduleItems().where((item) {
      return !item.startAt.isBefore(start) && item.startAt.isBefore(end);
    }).toList();
  }

  List<String> _buildWidgetVisibleDays() {
    return List<String>.from(_weekDays);
  }

  double? _buildWidgetCurrentMarkerRatio(int weekOffset) {
    // 현재 시간 표시선은 이번 주 위젯에서만 저장합니다.
    // 다음 주/지난 주 기준 데이터에는 current marker를 남기지 않습니다.
    if (weekOffset != 0) {
      return null;
    }

    return HomeWidgetGridMapper.buildCurrentMarkerRatio(
      weekOffset: weekOffset,
      currentTime: currentTime,
      startHour: startHour,
      endHour: endHour,
    );
  }

  List<HomeWidgetScheduleBlock> _buildWidgetBlocks(int weekOffset) {
    final days = _buildWidgetVisibleDays();

    final blockItems = _scheduleItemsForWeek(weekOffset)
        .where((item) => days.contains(item.day))
        .map((item) {
      return HomeWidgetBlockItem(
        startAt: item.startAt,
        endAt: item.endAt,
        day: item.day,
        name: item.name,
        type: item.type,
        colorHex: item.typeColorHex ?? _lessonTypeColorHexByName(item.type),
      );
    }).toList();

    return HomeWidgetBlockMapper.buildBlocks(
      weekOffset: weekOffset,
      currentTime: currentTime,
      startHour: startHour,
      endHour: endHour,
      visibleDays: days,
      allWeekDays: _weekDaysAll,
      items: blockItems,
    );
  }

  int _countThisWeekSessions() {
    return _scheduleItemsForWeek(0).length;
  }

  String _pickAiFcHeaderMessage(
    List<String> messages, {
    int salt = 0,
  }) {
    if (messages.isEmpty) return '';

    // 빌드마다 랜덤 변경되지 않도록 2시간 단위로만 자연스럽게 변경
    final seed = currentTime.year +
        currentTime.month +
        currentTime.day +
        (currentTime.hour ~/ 2) +
        salt;

    return messages[seed.abs() % messages.length];
  }

  bool _isTodayHiddenByCurrentDayFilter() {
    final todayWeekday = currentTime.weekday;

    if (dayFilter == 'weekday') {
      return todayWeekday == DateTime.saturday ||
          todayWeekday == DateTime.sunday;
    }

    if (dayFilter == 'weekend') {
      return todayWeekday >= DateTime.monday && todayWeekday <= DateTime.friday;
    }

    return false;
  }

  String _buildTodayHiddenByFilterNotice({
    required int todayCount,
    required String trainerLabel,
  }) {
    // 이 메서드는 "오늘 레슨이 실제로 있는데"
    // 현재 주5/주2 보기 때문에 오늘 칸이 접혀 있을 때만 강하게 안내합니다.
    if (todayCount <= 0) {
      return '';
    }

    final isWeekendToday = currentTime.weekday == DateTime.saturday ||
        currentTime.weekday == DateTime.sunday;

    if (dayFilter == 'weekday' && isWeekendToday) {
      return _pickAiFcHeaderMessage(
        [
          '지금은 평일 보기라 주말 칸이 살짝 접혀 있어요. 오늘 레슨 $todayCount개는 주7 보기에서 바로 확인할 수 있어요.',
          '$trainerLabel, 오늘은 주말인데 화면은 주5 모드예요. 오늘 레슨 $todayCount개는 제가 기억하고 있어요.',
          '주말 일정은 잠시 접혀 있어요. 오늘 레슨 $todayCount개는 주7 보기에서 다시 펼쳐볼 수 있어요.',
          '오늘 주말 레슨 $todayCount개가 있어요. 화면에 안 보이면 주7 보기로 한 번 펼쳐볼까요?',
        ],
        salt: 70 + todayCount,
      );
    }

    if (dayFilter == 'weekend' && !isWeekendToday) {
      return _pickAiFcHeaderMessage(
        [
          '지금은 주말 보기라 평일 칸이 살짝 접혀 있어요. 오늘 레슨 $todayCount개는 주7 보기에서 바로 확인할 수 있어요.',
          '$trainerLabel, 오늘은 평일인데 화면은 주말 모드예요. 오늘 일정 $todayCount개는 제가 놓치지 않고 기억해둘게요.',
          '평일 일정은 잠시 접혀 있어요. 오늘 레슨 $todayCount개는 주7 보기에서 다시 펼쳐볼 수 있어요.',
          '오늘 평일 레슨 $todayCount개가 있어요. 화면에 안 보이면 주7 보기로 한 번 확인해볼까요?',
        ],
        salt: 72 + todayCount,
      );
    }

    return '';
  }

  bool _looksLikeFirstHomeExperience({
    required int todayCount,
    required int weekCount,
  }) {
    return todayCount == 0 &&
        weekCount == 0 &&
        _bannerMemberCount == 0 &&
        !_hasProduct;
  }

  String _buildFirstHomeWelcomeNotice({
    required String trainerLabel,
  }) {
    return _pickAiFcHeaderMessage(
      [
        '안녕하세요 $trainerLabel, 반가워요. 앞으로 레슨 일정도, 회원 관리도 같이 즐겁게 만들어가봐요.',
        '$trainerLabel, 모어댄에 오신 걸 환영해요. 처음엔 가볍게 시작해도 괜찮아요. 제가 옆에서 하나씩 도와드릴게요.',
        '반가워요 $trainerLabel. 오늘부터 일정 관리도, 회원 관리도 조금 더 편하고 재밌게 만들어봐요.',
        '$trainerLabel, 이제 모어댄이 같이 달려볼게요. 첫 레슨 하나부터 천천히 시작해볼까요?',
        '환영해요 $trainerLabel. 앞으로 바쁜 날도, 여유로운 날도 제가 옆에서 흐름을 같이 챙겨볼게요.',
        '$trainerLabel, 시작은 가볍게 가도 좋아요. 레슨 일정 하나씩 쌓이면 모어댄이 더 똑똑하게 도와드릴게요.',
        '안녕하세요 $trainerLabel. 앞으로 회원님들과 만들어갈 좋은 순간들, 제가 옆에서 같이 기록해볼게요.',
      ],
      salt: 5,
    );
  }

  String _buildRestDayHeaderNotice({
    required String trainerLabel,
    required int moreSenseCount,
    required bool todayHiddenByFilter,
  }) {
    final messages = <String>[
      '오늘은 쉬는 날인가 봐요. 다시 달릴 체력도 이런 날 비축하는 거죠.',
      '평온한 하루 보내고 계신가요? 오늘은 무리하지 말고 천천히 가도 괜찮아요.',
      '오늘은 여유롭게 일상에서 살짝 벗어나 볼까요?',
      '힐링하는 하루 보내고 계신가요? 잠깐 시간 나면 모어댄도 조용히 옆에 있을게요.',
      '오늘 같은 날도 있어야 다시 힘차게 달릴 수 있죠.',
      '좋은 하루 보내고 계신가요? 오늘은 $trainerLabel 컨디션도 좀 챙겨주세요.',
      '오늘도 힘나는 하루 보내세요. 레슨이 없어도 좋은 리듬은 이어갈 수 있어요.',
      '오늘은 스케줄이 프리해요. 몸도 마음도 살짝 숨 고르는 날로 가볼까요?',
      '레슨 없는 날엔 회원카드 정리하기 딱 좋아요. 물론 쉬는 게 먼저고요.',
      '오늘은 여백이 있는 날이에요. 여백은 다음 계획을 그리는 자리이기도 하고요.',
      '모어댄이 정리 모드만 살짝 켜둘게요. $trainerLabel은 너무 무리하지 마세요.',
      '오늘같이 비는 날, 끼니는 챙기셨어요? 회원님만큼 본인도 좀 챙겨야죠.',
    ];

    if (moreSenseCount > 0) {
      messages.addAll([
        '오늘은 레슨은 없지만, 살짝 챙기면 좋은 MORE 센스 $moreSenseCount개가 있어요.',
        '시간 괜찮으시면 MORE 센스 $moreSenseCount개만 가볍게 훑어봐도 좋아요. 무리는 말고요.',
        '레슨 없는 날엔 이런 관리가 은근히 차이를 만들어요. MORE 센스 $moreSenseCount개가 기다리고 있어요.',
      ]);
    }

    if (todayHiddenByFilter) {
      if (dayFilter == 'weekend') {
        messages.addAll([
          '지금은 주말 보기로 접어둔 평일이에요. 오늘은 평온한 하루 보내고 계신가요?',
          '평일 칸은 살짝 접혀 있지만, 오늘 레슨은 없어요. 좋은 하루 보내고 계신가요?',
        ]);
      } else if (dayFilter == 'weekday') {
        messages.addAll([
          '지금은 평일 보기라 주말 칸은 접혀 있어요. 오늘은 레슨 없는 날이니 푹 쉬어도 좋겠어요.',
          '주말 칸은 살짝 접혀 있지만, 오늘 레슨은 없어요. 힘나는 하루 보내세요.',
        ]);
      }
    }

    return _pickAiFcHeaderMessage(
      messages,
      salt: 200 +
          moreSenseCount +
          (todayHiddenByFilter ? 17 : 0) +
          (dayFilter == 'weekend' ? 3 : 0),
    );
  }

  String _buildAiFcHeaderNotice({
    required int todayCount,
    required int weekCount,
    required int moreSenseCount,
  }) {
    final trainerLabel = aifcNicknameLabel(_bannerTrainerName);
    final todayHiddenByFilter = _isTodayHiddenByCurrentDayFilter();

    if (_looksLikeFirstHomeExperience(
      todayCount: todayCount,
      weekCount: weekCount,
    )) {
      return _buildFirstHomeWelcomeNotice(
        trainerLabel: trainerLabel,
      );
    }

    // 1. 레슨이 실제로 있는데 주5/주2 필터 때문에 오늘 칸이 접힌 경우
    // 이 경우는 "쉬는 날"로 보이면 안 되므로 안내를 우선합니다.
    if (todayHiddenByFilter && todayCount > 0) {
      final hiddenByFilterNotice = _buildTodayHiddenByFilterNotice(
        todayCount: todayCount,
        trainerLabel: trainerLabel,
      );

      if (hiddenByFilterNotice.isNotEmpty) {
        return hiddenByFilterNotice;
      }
    }

    // 2. 아주 바쁜 날은 MORE 센스보다 레슨 개수 문구를 우선합니다.
    if (todayCount >= 15) {
      return _pickAiFcHeaderMessage(
        [
          '오늘 레슨 $todayCount개… 이건 거의 레슨 괴물 모드예요. 진짜 대단합니다.',
          '레슨 $todayCount개요? 오늘은 모어댄도 정신 바짝 차리고 따라붙을게요.',
          '오늘 일정은 레전드급이에요. 하나씩만 가도 충분히 대단한 하루예요.',
          '$todayCount개 레슨이면 체력과 집중력을 다 쓰는 날이에요. 진짜 멋집니다.',
          '오늘은 거의 풀가동 데이예요. 체크할 건 제가 먼저 붙잡아둘게요.',
          '레슨 $todayCount개, 이건 바쁜 날을 넘어선 레슨 챔피언 모드예요.',
          '오늘 밥은 드셨어요? 이 정도 스케줄 소화하시는 거 보면 진짜 존경스러워요.',
        ],
        salt: 150 + todayCount,
      );
    }

    if (todayCount >= 11) {
      return _pickAiFcHeaderMessage(
        [
          '오늘 레슨 $todayCount개, 꽤 빡센 하루예요. 체크포인트는 제가 먼저 잡아둘게요.',
          '$todayCount개 레슨이면 체력전이에요. 무리하지 않게 흐름부터 잡아볼게요.',
          '오늘은 진짜 바쁜 날이에요. 레슨 사이 작은 틈도 소중하게 써볼까요?',
          '레슨 $todayCount개, 레슨 집중 모드 켜야 하는 날이에요.',
          '오늘 일정은 묵직합니다. 그래도 하나씩 가면 충분히 깔끔하게 끝낼 수 있어요.',
          '$todayCount개면 이미 손꼽히게 바쁜 날이에요. 모어댄이 옆에서 계속 체크할게요.',
          '이 정도 페이스면 오늘 끼니는 거르신 거 아니에요?',
        ],
        salt: 110 + todayCount,
      );
    }

    if (todayCount >= 9) {
      return _pickAiFcHeaderMessage(
        [
          '오늘 레슨 $todayCount개, 바쁜 날이에요. 페이스 조절은 저랑 같이해요.',
          '$todayCount개 레슨이면 꽤 묵직한 하루예요. 순서부터 잘 잡아볼게요.',
          '오늘은 레슨이 많은 날이에요. 놓칠 포인트는 제가 먼저 표시해둘게요.',
          '레슨 $todayCount개, 이제부터는 체력 관리도 전략이에요.',
          '오늘 일정 꽉 찼어요. 숨 고를 타이밍은 제가 같이 챙겨볼게요.',
          '$todayCount개의 무대, 큐시트처럼 순서는 제가 챙겨드릴게요.',
          '이렇게 바쁜 날은 물이라도 챙겨 드셨어요?',
        ],
        salt: 90 + todayCount,
      );
    }

    // 3. 이번 주 전체가 비어 있으면 첫 시작 유도.
    // 단, 최초 진입자는 위에서 이미 환영 문구로 처리됩니다.
    if (weekCount == 0) {
      return _pickAiFcHeaderMessage(
        [
          '이번 주 시간표, 아직 새하얀 도화지네요. 첫 붓질은 제가 도와드릴게요.',
          '텅 빈 일정표라니, 사실 뭐든 채울 수 있다는 뜻이에요. 첫 레슨부터 가볼까요?',
          '이번 주는 무대가 비어 있어요. 탭 한 번이면 시작할 수 있어요.',
          '일정이 고요해요. 고요한 건 괜찮지만, 심심한 건 조금 아쉽죠?',
          '이번 주 스케줄이 아주 깨끗해요. 이제 첫 발자국만 남기면 돼요.',
          '빈 시간표도 시작 전엔 원래 이래요. 첫 레슨 하나만 꽂아볼까요?',
          '아직 이번 주 레슨이 없어요. 모어댄이 조용히 대기 중입니다.',
        ],
        salt: 10,
      );
    }

    // 4. 오늘 레슨이 없으면 쉬는 날/회복 문구 우선.
    // MORE 센스는 이 안에서 부드럽게 섞습니다.
    if (todayCount == 0) {
      return _buildRestDayHeaderNotice(
        trainerLabel: trainerLabel,
        moreSenseCount: moreSenseCount,
        todayHiddenByFilter: todayHiddenByFilter,
      );
    }

    // 5. 오늘 1~8개이고 MORE 센스가 있으면 MORE 센스 문구를 보여줍니다.
    // 너무 바쁜 날에는 위에서 이미 레슨 개수 문구가 우선됩니다.
    if (moreSenseCount > 0) {
      return _pickAiFcHeaderMessage(
        [
          'MORE 센스 레이더에 회원님 $moreSenseCount명이 잡혔어요. 제가 먼저 캐치했어요.',
          '오늘 그냥 지나치기 아까운 회원님 $moreSenseCount명이 있어요. 살짝 챙겨볼까요?',
          '티 안 나게 놓치기 쉬운 신호, $moreSenseCount명 분 모아뒀어요.',
          '회원님 $moreSenseCount명에게 오늘 작은 관심 하나 얹어두면 좋겠어요.',
          '오늘의 숨은 관리 카드 $moreSenseCount장. 먼저 열어보실래요?',
          '제가 먼저 봐뒀어요. 오늘 챙기면 좋은 회원님 $moreSenseCount명이 있어요.',
          '관심 온도 살짝 올려두면 좋은 회원님 $moreSenseCount명이 있어요.',
          '회원님 $moreSenseCount명이 조용히 관리 타이밍을 보내고 있어요. 제가 받아뒀어요.',
        ],
        salt: moreSenseCount,
      );
    }

    if (todayCount <= 2) {
      return _pickAiFcHeaderMessage(
        [
          '오늘은 한 명 한 명 제대로 보기 좋은 날이에요.',
          '오늘의 주인공은 적지만, 집중력은 100% 발휘하기 좋은 날이에요.',
          '레슨 $todayCount개, 부담은 가볍게. 디테일은 더 깊게 갈 수 있어요.',
          '오늘은 원 포인트 레슨일이에요. 화력을 필요한 곳에 모아볼까요?',
          '레슨 $todayCount개면 오히려 더 알차게 갈 수 있는 날이에요.',
          '오늘은 속도보다 깊이로 가기 좋은 스케줄이에요.',
          '오늘처럼 여유 있는 날엔 본인 루틴은 좀 챙기셨어요?',
        ],
        salt: 30 + todayCount,
      );
    }

    if (todayCount <= 4) {
      return _pickAiFcHeaderMessage(
        [
          '오늘 레슨 $todayCount개, 여유 있게 리듬 타기 좋은 날이에요.',
          '오늘은 너무 빡세지도, 너무 심심하지도 않은 스케줄이에요.',
          '레슨 $todayCount개면 딱 기분 좋게 일하는 맛 나는 날이에요.',
          '오늘은 흐름 챙기면서 회원별 포인트도 보기 좋은 날이에요.',
          '스케줄이 적당히 살아 있어요. 무리 없이 깔끔하게 가볼까요?',
          '오늘 $todayCount개, 페이스만 잘 잡으면 꽤 산뜻하게 흘러갈 거예요.',
          '이 정도 페이스면 물 한 잔 마실 틈은 있으시죠?',
        ],
        salt: 40 + todayCount,
      );
    }

    if (todayCount <= 6) {
      return _pickAiFcHeaderMessage(
        [
          '오늘 레슨 $todayCount개, 무리 없이 레슨 리듬 타기 좋은 날이에요.',
          '레슨 $todayCount개면 하루 흐름이 슬슬 살아나는 스케줄이에요.',
          '오늘은 꽉 차진 않았지만, 충분히 일하는 맛 나는 날이에요.',
          '중간중간 숨 쉴 틈도 있고, 레슨 흐름도 있는 괜찮은 날이에요.',
          '오늘 $todayCount개, 회원별 포인트만 잘 잡으면 깔끔하게 끝낼 수 있어요.',
          '무겁진 않지만 가볍지도 않은 날이에요. 모어댄이 흐름 잡아둘게요.',
          '이 정도면 끼니는 제때 챙기실 수 있겠죠?',
        ],
        salt: 60 + todayCount,
      );
    }

    // 7~8개: 꽉 찬 보통 근무일
    return _pickAiFcHeaderMessage(
      [
        '오늘 레슨 $todayCount개, 딱 일하는 맛 나는 스케줄이에요.',
        '레슨 $todayCount개면 꽤 꽉 찬 하루예요. 흐름만 잘 타면 좋겠어요.',
        '오늘은 트레이너다운 하루네요. 순서와 페이스는 제가 같이 볼게요.',
        '$todayCount개 레슨이면 하루가 알차게 굴러가겠어요.',
        '오늘은 꽉 찬 보통 근무일이에요. 레슨 사이 체크포인트 챙겨둘게요.',
        '이 정도면 알차게 레슨하는 날이에요. 무리 없이 리듬 타볼까요?',
        '오늘처럼 바쁜 날, 단백질 챙길 시간은 있으신가요?',
      ],
      salt: 80 + todayCount,
    );
  }

  int _countTodaySessions() {
    return _scheduleItemsForToday().length;
  }

  int _countWeekSessions(int weekOffset) {
    return _scheduleItemsForWeek(weekOffset).length;
  }

  int _weeklyGoalTarget() {
    // SharedPreferences는 initState에서 로드해둔 값 사용
    return _weeklyLessonGoal > 0 ? _weeklyLessonGoal : 40;
  }

  List<String> _buildWidgetWeekRows(int weekOffset) {
    return HomeWidgetGridMapper.buildWeekRows(
      weekOffset: weekOffset,
      timeSlots: _timeSlots,
      visibleDays: _buildWidgetVisibleDays(),
      currentTime: currentTime,
    );
  }

  void _patchScheduleData({
    List<String> removeKeys = const [],
    Map<String, Map<String, dynamic>> upsert = const {},
    bool syncWidget = true,
  }) {
    var changed = false;

    for (final key in removeKeys) {
      changed = scheduleData.remove(key) != null || changed;
    }

    upsert.forEach((key, value) {
      final prev = scheduleData[key];
      if (prev is Map<String, dynamic>) {
        if (mapEquals(prev, value)) return;
      }
      scheduleData[key] = value;
      changed = true;
    });

    if (!changed) return;

    if (mounted) {
      setState(() {});
    }

    if (syncWidget) {
      _queueHomeWidgetSync();
    }

    _queueNotificationSync();
  }

  String _buildWidgetHeaderText({
    required int weekOffset,
  }) {
    final weekSlice = _buildWeekSlice(weekOffset);
    final filterLabel = _widgetDayFilterLabel();
    final rangeLabel =
        '${startHour.toString().padLeft(2, '0')}-${(endHour - 1).toString().padLeft(2, '0')}';
    final count = weekSlice.length;

    if (count == 0) {
      return '$filterLabel · $rangeLabel · 레슨일정 없음';
    }

    return '$filterLabel · $rangeLabel · ${count}건';
  }

  void _queueHomeWidgetSync({
    Duration delay = const Duration(milliseconds: 250),
    String source = 'mutation',
  }) {
    _homeWidgetSyncController.queue(
      delay: delay,
      syncAction: () async {
        if (!mounted) return;
        await _syncHomeWidgetPreview(source: source);
      },
    );
  }

  void _queueNotificationSync({
    Duration delay = const Duration(milliseconds: 800),
  }) {
    _lessonNotificationController.queueSync(
      delay: delay,
      syncAction: () async {
        if (!mounted) return;
        await _syncNotificationsFromSchedule();
      },
    );
  }

  Future<void> _syncNotificationsFromSchedule() async {
    final items = _allScheduleItems();
    try {
      await NotificationService.instance.syncLessonNotifications(
        items,
        personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
      );
    } catch (error) {
      if (kDebugMode) {
        final errorCode = error is FirebaseException
            ? error.code
            : error.runtimeType.toString();
        debugPrint('[MTF_SMART_ALARM] result=failure errorCode=$errorCode');
      }
    }
  }

  Future<void> _syncHomeWidgetPreview({String source = 'mutation'}) async {
    if (_isPersonalWorkspace && !_scheduleStreamReady) {
      if (kDebugMode) {
        debugPrint(
          '[MTF_DAILY_WIDGET_OWNER] source=$source authUidPresent=true '
          'ownerKeyPresentBefore=unknown ownerKeyWritten=false '
          'ownerMatchedAfter=false environmentMatched=true '
          'workspaceMatched=true result=deferred '
          'errorCode=schedule_snapshot_pending',
        );
      }
      return;
    }
    final rows0 = _buildWidgetWeekRows(0);
    final rows1 = _buildWidgetWeekRows(1);

    final days0 = _buildWidgetVisibleDays();
    final days1 = _buildWidgetVisibleDays();

    final List<String> blocks0 = _buildWidgetBlocks(0)
        .map((HomeWidgetScheduleBlock e) => e.encode())
        .toList();

    final List<String> blocks1 = _buildWidgetBlocks(1)
        .map((HomeWidgetScheduleBlock e) => e.encode())
        .toList();

    final currentMarkerRatio0 = _buildWidgetCurrentMarkerRatio(0);
    final currentMarkerRatio1 = _buildWidgetCurrentMarkerRatio(1);

    final header0 = '${_buildWidgetHeaderText(
      weekOffset: 0,
    )} · ${rows0.length}줄';

    final header1 = '${_buildWidgetHeaderText(
      weekOffset: 1,
    )} · ${rows1.length}줄';

    final lessons = _allScheduleItems().map((item) {
      return HomeWidgetPreviewLesson(
        startAt: item.startAt,
        endAt: item.endAt,
        memberName: item.name,
        lessonType: item.type,
        memo: item.memo ?? '',
        ownerUid: _personalOwnerUid,
        workspaceType: _isPersonalWorkspace ? 'personal' : 'legacy',
        remainingSessions: int.tryParse(item.remainingSessions ?? ''),
      );
    }).toList();

    await HomeWidgetPreviewSyncService.sync(
      HomeWidgetPreviewSyncPayload(
        dayFilter: dayFilter,
        startHour: startHour,
        endHour: endHour,
        title0: _weekTitleForOffset(0),
        header0: header0,
        rows0: rows0,
        days0: days0,
        blocks0: blocks0,
        currentMarkerRatio0: currentMarkerRatio0,
        title1: _weekTitleForOffset(1),
        header1: header1,
        rows1: rows1,
        days1: days1,
        blocks1: blocks1,
        currentMarkerRatio1: currentMarkerRatio1,
        lessons: lessons,
        personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : '',
        environment: AppEnvironmentConfig.environmentName,
        projectId: AppEnvironmentConfig.firebaseProjectId,
        source: source,
        debugLog: false,
      ),
    );
  }

  // ---------- 시간/분 설정 관련 ----------

  Future<int?> _updateScheduleKeysForHour(
    int hour,
    int oldMinute,
    int newMinute, {
    bool syncAfter = true,
  }) async {
    if (oldMinute == newMinute) return 0;

    final candidates = <Map<String, dynamic>>[];
    final movingDocIds = <String>{};

    scheduleData.forEach((key, value) {
      if (value is! Map<String, dynamic>) return;

      final docId = value['docId']?.toString().trim() ?? '';

      if (docId.isNotEmpty && _isScheduleDocTemporarilyHidden(docId)) {
        return;
      }

      if (_isScheduleDataDeleted(value)) {
        return;
      }

      final rawStartAt = value['startAt'];
      if (rawStartAt is! DateTime) return;

      if (rawStartAt.hour != hour || rawStartAt.minute != oldMinute) {
        return;
      }

      // 확정된 레슨은 시간 줄 변경으로 이동하지 않습니다.
      if (_isScheduleLessonConfirmed(value)) {
        return;
      }

      final day = _weekDaysAll[rawStartAt.weekday - 1];

      candidates.add({
        'docId': docId,
        'day': day,
        'startAt': rawStartAt,
        'data': Map<String, dynamic>.from(value),
      });

      if (docId.isNotEmpty) {
        movingDocIds.add(docId);
      }
    });

    if (candidates.isEmpty) return 0;

    final conflictTimes = <String>{};

    for (final item in candidates) {
      final startAt = item['startAt'] as DateTime;
      final originalData =
          Map<String, dynamic>.from(item['data'] as Map<String, dynamic>);

      final durationMinutes = _durationMinutesFromSession(originalData);

      final targetStartAt = DateTime(
        startAt.year,
        startAt.month,
        startAt.day,
        hour,
        newMinute,
      );

      final targetEndAt = targetStartAt.add(
        Duration(minutes: durationMinutes),
      );

      final conflicts = _findScheduleOverlapsInRange(
        startAt: targetStartAt,
        endAt: targetEndAt,
        ignoreDocIds: movingDocIds,
      );

      if (conflicts.isNotEmpty) {
        conflictTimes.add(
          '${_timeLabelFromDate(targetStartAt)}~${_timeLabelFromDate(targetEndAt)}',
        );
      }
    }

    if (conflictTimes.isNotEmpty) {
      _showError(
        '${hour.toString().padLeft(2, '0')}시 줄은 ${conflictTimes.join(', ')} 충돌 때문에 변경하지 않았어요.',
      );
      return null;
    }

    final deleteDocIds = <String>[];
    final firestoreWrites = <HomeScheduleEditWrite>[];
    final localUpdates = <Map<String, dynamic>>[];

    for (final item in candidates) {
      final originalData =
          Map<String, dynamic>.from(item['data'] as Map<String, dynamic>);
      if (_hasUnsafeScheduleCollision(originalData)) {
        _showError('같은 시간에 서로 다른 레슨 문서가 있어 시간 이동을 중단했어요.');
        return null;
      }
      final sourceDocId = item['docId']?.toString().trim() ?? '';
      final day = item['day'] as String;
      final startAt = item['startAt'] as DateTime;

      final durationMinutes = _durationMinutesFromSession(originalData);

      final targetStartAt = DateTime(
        startAt.year,
        startAt.month,
        startAt.day,
        hour,
        newMinute,
      );

      final targetEndAt = targetStartAt.add(
        Duration(minutes: durationMinutes),
      );

      final targetDocId = _scheduleDocIdFromDate(targetStartAt, day);
      final movePlan = HomeScheduleMovePlan.fromSnapshot(
        actualSourceDocId: sourceDocId,
        dataDocId: (originalData['docId'] ?? '').toString(),
        targetDocId: targetDocId,
      );

      if (kDebugMode) {
        debugPrint(
          '[MTF_SCHEDULE_MUTATION] action=move '
          'actualSourceDocId=${movePlan.sourceDocId} '
          'dataDocId=${movePlan.dataDocId} '
          'targetDocId=$targetDocId '
          'dataDocIdMismatch=${movePlan.hasDataDocIdMismatch} '
          'sourceStartAt=${startAt.toIso8601String()} '
          'targetStartAt=${targetStartAt.toIso8601String()}',
        );
      }

      _clearRecentlyDeletedScheduleDocId(targetDocId);

      final sourceKey = _absoluteKeyFromDate(startAt);
      final targetKey = _absoluteKeyFromDate(targetStartAt);
      final targetTime = _timeLabelFromDate(targetStartAt);
      final targetEndTime = _timeLabelFromDate(targetEndAt);

      final firestoreData = Map<String, dynamic>.from(originalData);
      firestoreData.remove('docId');
      firestoreData['startAt'] = Timestamp.fromDate(targetStartAt);
      firestoreData['endAt'] = Timestamp.fromDate(targetEndAt);
      firestoreData['day'] = day;
      firestoreData['time'] = targetTime;
      firestoreData['endTime'] = targetEndTime;
      firestoreData['updatedAt'] = FieldValue.serverTimestamp();

      firestoreWrites.add(
        HomeScheduleEditWrite(
          targetDocId: targetDocId,
          data: firestoreData,
        ),
      );

      final exactSourceDocIds = _exactScheduleSourceDocIds(originalData);
      final sourceIdsToDelete = movePlan.shouldDeleteSource
          ? exactSourceDocIds
          : exactSourceDocIds.where((id) => id != movePlan.sourceDocId).toSet();

      for (final sourceId in sourceIdsToDelete) {
        deleteDocIds.add(sourceId);
        _markScheduleDocAsRecentlyDeleted(sourceId);
      }

      localUpdates.add({
        'sourceKey': sourceKey,
        'targetKey': targetKey,
        'data': {
          ...originalData,
          'actualDocumentId': targetDocId,
          'dataDocumentId': targetDocId,
          'docId': targetDocId,
          'startAt': targetStartAt,
          'endAt': targetEndAt,
          'day': day,
          'time': targetTime,
          'endTime': targetEndTime,
        },
      });
    }

    _beginScheduleMutation(deleteDocIds);
    try {
      await HomeScheduleFirestoreService.commitScheduleWrites(
        deleteDocIds: deleteDocIds,
        writes: firestoreWrites,
        ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
      );
    } catch (e) {
      if (_shouldClearTombstoneAfterMutationError(e)) {
        for (final docId in deleteDocIds) {
          _clearRecentlyDeletedScheduleDocId(docId);
        }
      }

      debugPrint('시간 줄 이동 저장 실패: $e');
      _showError('시간 줄 변경 중 오류가 발생했어요.');
      return null;
    } finally {
      _endScheduleMutation(deleteDocIds);
    }

    final removeKeys = <String>[];
    final upsert = <String, Map<String, dynamic>>{};

    for (final item in localUpdates) {
      final sourceKey = item['sourceKey']?.toString() ?? '';
      final targetKey = item['targetKey']?.toString() ?? '';
      final data = item['data'];

      if (sourceKey.isNotEmpty) {
        removeKeys.add(sourceKey);
      }

      if (targetKey.isNotEmpty && data is Map<String, dynamic>) {
        upsert[targetKey] = Map<String, dynamic>.from(data);
      }
    }

    _patchScheduleData(
      removeKeys: removeKeys,
      upsert: upsert,
      syncWidget: syncAfter,
    );

    return candidates.length;
  }

  Future<void> _openAllRowsMinuteSheet() async {
    final pickedMinute = await AifcHomeScheduleMinuteChatSheet.show(
      context: context,
      nickname: _bannerTrainerName,
      title: '한 번에 전체 스케줄 시간을 맞춰볼까요?',
      message: '모든 시간 줄의 시작 분과 새로 등록하는 레슨의 기본 시작 분을 함께 바꿀 수 있어요.\n'
          '이렇게 바꿔놓으시면 스케줄표와 위젯 기준이 같이 정리돼서 편하실 거예요.',
      currentMinute: defaultMinute,
      primaryColor: kPrimaryColor,
      confirmLabel: '전체 적용할게요',
      footerText: '확정된 레슨은 움직이지 않고, 충돌이 있는 시간 줄은 기존 값으로 유지돼요.',
    );

    if (!mounted || pickedMinute == null) return;

    final moveResults = <int, int?>{};

    for (int hour = startHour; hour < endHour; hour++) {
      final oldMinute = _timeRowMinutes[hour] ?? defaultMinute;

      moveResults[hour] = await _updateScheduleKeysForHour(
        hour,
        oldMinute,
        pickedMinute,
        syncAfter: false,
      );
    }

    if (!mounted) return;

    final successfulHours = moveResults.entries
        .where((entry) => entry.value != null)
        .map((entry) => entry.key)
        .toList();

    final conflictHours = moveResults.entries
        .where((entry) => entry.value == null)
        .map((entry) => entry.key)
        .toList();

    final movedCount = moveResults.values
        .whereType<int>()
        .fold<int>(0, (sum, value) => sum + value);

    setState(() {
      for (final hour in successfulHours) {
        _timeRowMinutes[hour] = pickedMinute;
      }

      if (successfulHours.length == endHour - startHour) {
        defaultMinute = pickedMinute;
      }
    });

    await _saveScheduleViewPrefs();

    if (!mounted) return;

    await _syncHomeWidgetPreview();

    if (conflictHours.isEmpty) {
      _showSnack(
        '모든 시간 줄과 기본 시작 분이 ${pickedMinute.toString().padLeft(2, '0')}분으로 설정되었습니다.'
        '${movedCount > 0 ? ' 기존 레슨일정 $movedCount개도 함께 옮겼어요.' : ''}',
      );
    } else if (successfulHours.isEmpty) {
      _showActionToast(
        context,
        '충돌 때문에 변경된 시간 줄이 없어요.',
      );
    } else {
      _showSnack(
        '충돌 없는 ${successfulHours.length}개 시간 줄만 ${pickedMinute.toString().padLeft(2, '0')}분으로 적용했어요. '
        '충돌 ${conflictHours.length}개 줄은 기존 시간으로 유지했어요.',
      );
    }
  }

  Future<void> _openRowMinuteSheet(int hour, int currentMinute) async {
    final hourLabel = _formatHomeHourLabel(hour);

    final pickedMinute = await HomeRowMinuteSettingsSheet.show(
      context: context,
      hourLabel: hourLabel,
      currentMinute: currentMinute,
      primaryColor: kPrimaryColor,
    );

    if (!mounted || pickedMinute == null) return;

    final oldMinute = _timeRowMinutes[hour] ?? currentMinute;

    final movedCount = await _updateScheduleKeysForHour(
      hour,
      oldMinute,
      pickedMinute,
      syncAfter: false,
    );

    if (!mounted || movedCount == null) return;

    setState(() {
      _timeRowMinutes[hour] = pickedMinute;
      defaultMinute = pickedMinute;
    });

    await _saveScheduleViewPrefs();

    if (!mounted) return;

    await _syncHomeWidgetPreview();

    _showSnack(
      '${hour.toString().padLeft(2, '0')}시 줄이 ${pickedMinute.toString().padLeft(2, '0')}분으로 변경되었습니다.'
      '${movedCount > 0 ? ' 기존 레슨일정 $movedCount개도 함께 옮겼어요.' : ''}',
    );
  }

  // ✅ (변경) 더블탭 → 롱프레스
  void _onTimeRowLongPress(String timeLabel) {
    final parts = timeLabel.split(":");
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]) ?? -1;
    if (hour < 0 || hour > 23) return;
    final minuteFromLabel = int.tryParse(parts[1]) ?? 0;
    final currentMinute = _timeRowMinutes[hour] ?? minuteFromLabel;
    _openRowMinuteSheet(hour, currentMinute);
  }

  Future<void> _openTimeRangeDialog() async {
    final result = await AifcHomeScheduleTimeRangeChatSheet.show(
      context: context,
      nickname: _bannerTrainerName,
      startHour: startHour,
      endHourExclusive: endHour,
      primaryColor: kPrimaryColor,
    );

    if (!mounted || result == null) return;

    setState(() {
      startHour = result.startHour;
      endHour = result.endHourExclusive;
      _ensureTimeRowMinutes();
    });

    await _saveScheduleViewPrefs();

    if (!mounted) return;

    await _syncHomeWidgetPreview();

    final firstLabel = _formatHomeHourLabel(startHour);
    final lastLabel = _formatHomeHourLabel(endHour - 1);
    final praise = _scheduleRangePraiseText(
      startHour: startHour,
      endHourExclusive: endHour,
    );

    _showActionToast(
      context,
      '첫 레슨 시작은 $firstLabel, 마지막 레슨은 $lastLabel 기준으로 설정해둘게요.\n$praise',
      bottomOffset: 110,
      duration: const Duration(milliseconds: 2200),
    );
  }

  String _formatHomeHourLabel(int hour) {
    final isPm = hour >= 12;
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final ampm = isPm ? '오후' : '오전';
    return '$ampm ${displayHour.toString().padLeft(2, '0')}:00';
  }

  String _scheduleRangePraiseText({
    required int startHour,
    required int endHourExclusive,
  }) {
    final visibleHours = endHourExclusive - startHour;

    if (visibleHours <= 6) {
      return '한 분 한 분 소중하게 생각하시는 모습 정말 멋지십니다 👏';
    }

    if (visibleHours >= 12) {
      return '항상 성실하신 모습 정말 멋집니다 👍';
    }

    return '오늘도 힘나는 하루 시작해볼까요 💪';
  }

  String _timeStringFromDateTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<Map<String, String>?> _openLessonStartEndTimeDialog({
    required String initialStartTime,
    required String initialEndTime,
    HomeLessonTimePickerInitialFocus initialFocus =
        HomeLessonTimePickerInitialFocus.start,
  }) async {
    final result = await HomeLessonStartEndTimePicker.show(
      context: context,
      initialStartTime: initialStartTime,
      initialEndTime: initialEndTime,
      preferredDurationMinutes: _preferredLessonDurationMinutes,
      onError: _showError,
      initialFocus: initialFocus,
    );

    if (!mounted || result == null) return null;

    _preferredLessonDurationMinutes = result.durationMinutes;

    return {
      'startTime': result.startTime,
      'endTime': result.endTime,
    };
  }

  Future<String?> _openLessonEndTimeOnlyDialog({
    required String initialStartTime,
    required String initialEndTime,
  }) async {
    final picked = await _openLessonStartEndTimeDialog(
      initialStartTime: initialStartTime,
      initialEndTime: initialEndTime,
      initialFocus: HomeLessonTimePickerInitialFocus.end,
    );

    if (picked == null) return null;

    return picked['endTime'];
  }

  String _formatMonthlyPrice(int value) {
    return '${NumberFormat.decimalPattern('ko_KR').format(value)}원';
  }

  void _showComingSoon(String label) {
    _showActionToast(
      context,
      '$label 기능은 준비중이에요. 곧 더 간편하고 확실하게 도와드릴게요.',
      bottomOffset: 110,
    );
  }

  Future<void> _openLegacySettingsPage() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
        ),
      ),
    );

    if (!mounted) return;

    if (changed == true) {
      await _loadRepeatLessonGroupingMode();
      _queueNotificationSync(delay: Duration.zero);
    }
  }

  // -------------- 정식 회원 등록 (헤더 아이콘) --------------
  Future<bool> _guardCustomerCardCreate(String entryPoint) async {
    if (!_isPersonalWorkspace) return true;
    return AifcTierFeatureGateSheet.guard(
      context: context,
      access: null,
      feature: AppTierFeatureKey.customerCardCreate,
      loadAccess: _loadCurrentTierAccess,
      entryPoint: entryPoint,
    );
  }

  Future<void> _openFullRegistrationPage() async {
    if (!await _guardCustomerCardCreate('home_full_registration')) return;
    final newId = FirebaseFirestore.instance.collection('members').doc().id;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientCardPage.fromQuickRegistration(
          memberId: newId,
          initialName: '',
          initialPhone: '',
          initialVisitDate: DateTime.now(),
          initialConsultDate: null,
          personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
        ),
      ),
    );
  }

  // ---------- 빠른 회원 등록 ----------

  Future<HomeQuickRegResult?> _openQuickRegistrationDialog() async {
    String nickname = '강사님';

    try {
      final snap = await _trainerProfileRef.get();

      final data = snap.data();
      nickname = _trainerHeaderNameFromData(data);
    } catch (_) {
      nickname = '강사님';
    }

    final result = await AifcQuickRegisterChatSheet.show(
      context: context,
      nickname: nickname,
    );

    if (result == null) return null;

    return HomeQuickRegResult(
      action: result.goDetail
          ? HomeQuickRegAction.goDetail
          : HomeQuickRegAction.fastSave,
      name: result.name,
      phone: result.phone,
      visitDate: DateTime.now(),
      consultDate: result.consultDate,
    );
  }

  Future<void> _showQuickRegistrationDialog() async {
    if (_isSubmitting) return;
    if (!await _guardCustomerCardCreate('home_quick_registration')) return;

    final result = await _openQuickRegistrationDialog();
    if (!mounted || result == null) return;

    if (result.action == HomeQuickRegAction.goDetail) {
      final newId = FirebaseFirestore.instance.collection('members').doc().id;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ClientCardPage.fromQuickRegistration(
            memberId: newId,
            initialName: result.name,
            initialPhone: result.phone,
            initialVisitDate: result.visitDate,
            initialConsultDate: result.consultDate,
            personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
          ),
        ),
      );
      return;
    }

    if (result.action == HomeQuickRegAction.fastSave) {
      setState(() => _isSubmitting = true);
      try {
        final newId = FirebaseFirestore.instance.collection('members').doc().id;
        await FirebaseFirestore.instance.collection('members').doc(newId).set({
          'name': result.name,
          'phone': result.phone,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'memberStatus': '활성',
          'membershipGrade': 'BRONZE',
          'note':
              '최초 방문일: ${DateFormat('yyyy-MM-dd').format(result.visitDate)}',
          if (result.consultDate != null)
            'nextReservationAt': Timestamp.fromDate(result.consultDate!),
        }, SetOptions(merge: true));

        if (!mounted) return;
        final hasConsult = result.consultDate != null;

        _showActionToast(
          context,
          hasConsult
              ? '제가 ${aifcPersonLabel(result.name)}을 빠르게 등록해뒀어요. 상담 일정도 놓치지 않게 챙겨드릴게요.'
              : '제가 ${aifcPersonLabel(result.name)}을 빠르게 등록해뒀어요. 고객카드는 필요할 때 이어서 채우면 돼요.',
          bottomOffset: 110,
        );
      } catch (e) {
        if (!mounted) return;
        _showActionToast(
          context,
          '등록에 실패했습니다.',
          bottomOffset: 110,
        );
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  void _onAction(HomeAction action) {
    switch (action) {
      case HomeAction.quickSchedule:
        _showQuickRegistrationDialog();
        break;
      case HomeAction.quickMember:
        _openFullRegistrationPage();
        break;
      case HomeAction.notifications:
        unawaited(_toggleLessonNotificationFromHeader());
        break;
      case HomeAction.settings:
        _openLegacySettingsPage();
        break;
      case HomeAction.expiringMembers:
        _showComingSoon('만료 임박 / 잔여 레슨 관리');
        break;
    }
  }

  // ---------- 오늘 다음 레슨 ----------

  List<Map<String, dynamic>> _findTodayNextLessons() {
    final now = currentTime;
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    final List<Map<String, dynamic>> entries = [];

    scheduleData.forEach((key, value) {
      if (value is! Map<String, dynamic>) return;

      final docId = (value['docId'] ?? '').toString().trim();

      if (docId.isNotEmpty && _isScheduleDocTemporarilyHidden(docId)) {
        return;
      }

      if (_isScheduleDataDeleted(value)) {
        return;
      }

      final rawStartAt = value['startAt'];
      if (rawStartAt is! DateTime) return;

      final startAt = rawStartAt;
      if (startAt.isBefore(todayStart) || !startAt.isBefore(tomorrowStart)) {
        return;
      }

      final rawEndAt = value['endAt'];
      final endAt = rawEndAt is DateTime
          ? rawEndAt
          : startAt.add(
              const Duration(minutes: _defaultLessonDurationMinutes),
            );

      final day = _weekDaysAll[startAt.weekday - 1];
      final time =
          '${startAt.hour.toString().padLeft(2, '0')}:${startAt.minute.toString().padLeft(2, '0')}';

      entries.add({
        'day': day,
        'time': time,
        'name': (value['name'] ?? '').toString(),
        'type': (value['type'] ?? 'PT').toString(),
        'memo': (value['memo'] ?? '').toString(),
        'totalSessions': (value['totalSessions'] ?? '').toString(),
        'remainingSessions': (value['remainingSessions'] ?? '').toString(),
        'memberId': (value['memberId'] ?? '').toString(),
        'phone': (value['phone'] ?? '').toString(),
        'isManualMember': _isManualScheduleMember(value),
        'dt': startAt,
        'endAt': endAt,
      });
    });

    if (entries.isEmpty) return [];

    entries.sort(
      (a, b) => (a['dt'] as DateTime).compareTo(b['dt'] as DateTime),
    );

    Map<String, dynamic>? current;
    final List<Map<String, dynamic>> upcoming = [];

    for (final e in entries) {
      final startAt = e['dt'] as DateTime;
      final endAt = e['endAt'] as DateTime;

      if (!now.isBefore(startAt) && now.isBefore(endAt)) {
        current ??= e;
      } else if (startAt.isAfter(now)) {
        upcoming.add(e);
      }
    }

    final List<Map<String, dynamic>> result = [];

    final currentLesson = current;

    if (currentLesson != null) {
      result.add({
        ...Map<String, dynamic>.from(currentLesson),
        'isOngoing': true,
        'minutesToStart': 0,
        'minutesToEnd':
            (currentLesson['endAt'] as DateTime).difference(now).inMinutes,
      });
    }

    // 진행중 레슨이 없으면 다음 레슨 2개까지 보여줍니다.
    // 진행중 레슨이 있으면 현재 레슨 + 바로 다음 레슨까지만 보여줍니다.
    final maxUpcomingCount = currentLesson == null ? 2 : 1;

    for (final next in upcoming.take(maxUpcomingCount)) {
      result.add({
        ...Map<String, dynamic>.from(next),
        'isOngoing': false,
        'minutesToStart': (next['dt'] as DateTime).difference(now).inMinutes,
      });
    }

    DateTime? previousEndAt;

    for (var i = 0; i < result.length; i++) {
      final item = result[i];
      final startAt = item['dt'] as DateTime;
      final endAt = item['endAt'] as DateTime;
      final isOngoing = item['isOngoing'] == true;
      final bool isNextAfterOngoing =
          i > 0 && result[i - 1]['isOngoing'] == true;
      final minutesToStart = item['minutesToStart'] is int
          ? item['minutesToStart'] as int
          : startAt.difference(now).inMinutes;

      int? gapFromPreviousMinutes;
      var isSeparatedFromPrevious = false;

      if (previousEndAt != null) {
        gapFromPreviousMinutes = startAt.difference(previousEndAt).inMinutes;
        isSeparatedFromPrevious = gapFromPreviousMinutes > 60;
      }

      var visualSoftness = 0;

      if (!isOngoing) {
        if (minutesToStart > 240) {
          visualSoftness = 2;
        } else if (minutesToStart > 90) {
          visualSoftness = 1;
        }

        if (isSeparatedFromPrevious && visualSoftness < 2) {
          visualSoftness = 2;
        }

        if (i > 0 && visualSoftness > 0) {
          visualSoftness += 1;
        }

        if (visualSoftness > 3) {
          visualSoftness = 3;
        }
      }

      item['gapFromPreviousMinutes'] = gapFromPreviousMinutes;
      item['isSeparatedFromPrevious'] = isSeparatedFromPrevious;
      item['visualSoftness'] = visualSoftness;
      item['isNextAfterOngoing'] = isNextAfterOngoing;

      previousEndAt = endAt;
    }

    return result;
  }

  Map<String, int> _countWeekLessonTypes(int weekOffset) {
    final result = <String, int>{};

    for (final item in _scheduleItemsForWeek(weekOffset)) {
      result[item.type] = (result[item.type] ?? 0) + 1;
    }

    return result;
  }

  double _weeklyGoalProgress(int current, int target) {
    if (target <= 0) return 0;
    final value = current / target;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  String _topWeeklyLessonTypeLabel(Map<String, int> typeCounts, int rank) {
    if (typeCounts.isEmpty) return '-';

    final sorted = typeCounts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        if (byCount != 0) return byCount;
        return a.key.compareTo(b.key);
      });

    if (rank < 0 || rank >= sorted.length) return '-';
    return '${sorted[rank].key} ${sorted[rank].value}회';
  }

  Future<void> _openTodayScheduleFocus() async {
    final restored = _weekPageIndex != _todayWeekIndex;
    if (_weekPageIndex != _todayWeekIndex) {
      await _weekPageController.animateToPage(
        _todayWeekIndex,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }

    if (!isHeaderExpanded || dayFilter != 'all') {
      setState(() {
        isHeaderExpanded = true;
        dayFilter = 'all';
      });
    }

    final now = DateTime.now();
    final targetHour = resolveHomeTodayTargetHour(
      now: now,
      lessonStartTimes: _allScheduleItems().map((item) => item.startAt),
      startHour: startHour,
      endHourExclusive: endHour,
    );

    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _scheduleSectionKey.currentContext == null) return;
    await Scrollable.ensureVisible(
      _scheduleSectionKey.currentContext!,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
    if (!mounted || !_homeScrollController.hasClients) return;
    const scheduleChromeHeight = 150.0;
    const rowHeight = 40.0;
    final rowOffset = (targetHour - startHour) * rowHeight;
    final centered = (_homeScrollController.offset +
            scheduleChromeHeight +
            rowOffset -
            MediaQuery.sizeOf(context).height * 0.35)
        .clamp(
      _homeScrollController.position.minScrollExtent,
      _homeScrollController.position.maxScrollExtent,
    );
    await _homeScrollController.animateTo(
      centered.toDouble(),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || _todayNextLessonsKey.currentContext == null) return;
    await Scrollable.ensureVisible(
      _todayNextLessonsKey.currentContext!,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );
    if (kDebugMode) {
      debugPrint(
        '[MTF_HOME_SCROLL_TODAY] currentWeekRestored=$restored '
        'targetDay=${now.weekday} targetTime=$targetHour '
        'horizontalCentered=true verticalCentered=true',
      );
    }
  }

  Future<void> _openMembersPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientListPage(
          personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
        ),
      ),
    );

    if (!mounted) return;
  }

  Future<void> _openThisWeekStats() async {
    if (_isPersonalWorkspace) {
      try {
        final allowed = await AifcTierFeatureGateSheet.guard(
          context: context,
          access: null,
          feature: AppTierFeatureKey.lessonInsights,
          loadAccess: _loadCurrentTierAccess,
          entryPoint: 'home_lesson_insights',
        );
        if (!allowed || !mounted) return;
      } catch (_) {
        if (!mounted) return;
        _showActionToast(
          context,
          '등급 정보를 확인하지 못했어요.',
          bottomOffset: 110,
        );
        return;
      }
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatsPage(
          scheduleData: Map<String, dynamic>.from(scheduleData),
          personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
        ),
      ),
    );

    if (!mounted) return;
  }

  Future<void> _openSupportTierGuideSheet({
    String highlightTier = 'semiPro',
  }) async {
    await HomeSupportTierGuideSheet.show(
      context: context,
      highlightTier: highlightTier,
      primaryColor: kPrimaryColor,
      secondaryColor: kPrimaryColor2,
      litePrice: kAmateurSupportMonthlyPrice,
      semiProPrice: kSemiProSupportMonthlyPrice,
      proPrice: kProSupportMonthlyPrice,
      formatMonthlyPrice: _formatMonthlyPrice,
      onSponsorTap: (supportTier) {
        final message = switch (supportTier) {
          'semiPro' => '든든하게 응원하기 결제 기능은 준비 중이에요.',
          'pro' => 'Pro 응원 결제 기능은 준비 중이에요. AI FC 개발을 응원할 수 있게 준비하고 있어요.',
          _ => 'MORE NEXT STEP 응원 결제 기능은 준비 중이에요.',
        };

        _showActionToast(
          context,
          message,
          bottomOffset: 110,
        );
      },
    );
  }

  Future<void> _openCenterPlanGuideSheet({
    String highlightTier = 'master',
  }) async {
    await HomeCenterPlanGuideSheet.show(
      context: context,
      highlightTier: highlightTier,
      primaryColor: kPrimaryColor,
      secondaryColor: kPrimaryColor2,
      masterPrice: kMasterSupportMonthlyPrice,
      grandPrixPrice: kGrandPrixSupportMonthlyPrice,
      formatMonthlyPrice: _formatMonthlyPrice,
      onCenterPlanTap: (centerTier) {
        final message = switch (centerTier) {
          'grandPrix' => 'Grand Prix 센터 플랜 문의 기능은 준비 중이에요.',
          _ => 'Master 센터 플랜 문의 기능은 준비 중이에요.',
        };

        _showActionToast(
          context,
          message,
          bottomOffset: 110,
        );
      },
    );
  }

  Future<bool> _hasSeenContractFirstEntryCelebration() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_contractFirstEntryCelebratedPrefsKey) ?? false;
  }

  Future<void> _setContractFirstEntryCelebrationSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_contractFirstEntryCelebratedPrefsKey, true);
  }

  Future<void> _openContractStartChatSheet() async {
    String trainerName = '강사님';

    try {
      final snap = await _trainerProfileRef.get();

      trainerName = _trainerHeaderNameFromData(snap.data());
    } catch (_) {
      trainerName = '강사님';
    }

    if (!mounted) return;

    final canUse = await AifcTierFeatureGateSheet.guard(
      context: context,
      access: null,
      feature: AppTierFeatureKey.contract,
      loadAccess: _loadCurrentTierAccess,
      entryPoint: 'home_new_contract',
    );

    debugPrint(
      '[MTF_CONTRACT] currentTier=${_currentAppTier.label}, '
      'tier=${_bannerProfileData['tier']}, '
      'appTier=${_bannerProfileData['appTier']}, '
      'currentTierField=${_bannerProfileData['currentTier']}, '
      'supportTier=${_bannerProfileData['supportTier']}, '
      'subscriptionTier=${_bannerProfileData['subscriptionTier']}, '
      'planTier=${_bannerProfileData['planTier']}, '
      'plan=${_bannerProfileData['plan']}, '
      'isSponsor=$_isSponsor, '
      'canUse=$canUse',
    );

    if (!mounted) return;

    // ✅ 세미프로 이상: 최초 1회만 축하 시트, 이후 바로 레슨계약서 작성
    if (canUse) {
      final hasSeenCelebration = await _hasSeenContractFirstEntryCelebration();

      if (!mounted) return;

      if (!hasSeenCelebration) {
        final shouldStart = await AifcTierCelebrationSheet.show(
          context: context,
          trainerName: trainerName,
          upgrade: AifcTierUpgrade.amateurToSemiPro,
        );

        if (!mounted) return;

        if (shouldStart != true) {
          return;
        }

        await _setContractFirstEntryCelebrationSeen();

        if (!mounted) return;

        await _openNewContractPage();
        return;
      }

      await _openNewContractPage();
      return;
    }

    return;
  }

  Future<void> _openNewContractPage() async {
    final newMemberId =
        FirebaseFirestore.instance.collection('members').doc().id;

    String trainerName = '강사님';

    try {
      final snap = await _trainerProfileRef.get();

      final data = snap.data();

      final contractTrainerName =
          (data?['contractTrainerName'] ?? '').toString().trim();
      final displayName = (data?['displayName'] ?? '').toString().trim();
      final name = (data?['name'] ?? '').toString().trim();

      if (contractTrainerName.isNotEmpty) {
        trainerName = contractTrainerName;
      } else if (displayName.isNotEmpty) {
        trainerName = displayName;
      } else if (name.isNotEmpty) {
        trainerName = name;
      }
    } catch (_) {}

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContractPage(
          memberId: newMemberId,
          memberName: '',
          trainerName: trainerName,
          initialStage: ContractStage.requiredInfo,
          personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
        ),
      ),
    );
  }

  Future<void> _openConsultPlaceholder() async {
    final access = await _loadCurrentTierAccess();

    if (!mounted) return;

    String nextTierNameFromRank(int rank) {
      if (rank < 1) return 'Amateur';
      if (rank < 2) return 'Semi-Pro';
      if (rank < 3) return 'Pro';
      if (rank < 4) return 'Master';
      if (rank < 5) return 'Grand Prix';

      return 'Grand Prix';
    }

    final canUseConsult = await AifcTierFeatureGateSheet.guard(
      context: context,
      access: access,
      feature: AppTierFeatureKey.consult,
      loadAccess: _loadCurrentTierAccess,
      onShowTierGuide: (_) async {
        if (!mounted) return;

        await AifcTierGuideChatSheet.show(
          context: context,
          trainerName: _bannerTrainerName,
          currentTierName: access.tierLabel,
          nextTierName: nextTierNameFromRank(access.tierRank),
          memberCount: access.activeMemberCount,
          lessonCount: scheduleData.length,
          hasProduct: _hasProduct,
          trainerInfoDone: access.profileCompleted,
        );
      },
    );

    if (!mounted || !canUseConsult) return;

    final result = await AifcConsultChecklistChatSheet.show(
      context: context,
      trainerName: _bannerTrainerName,
    );

    if (!mounted || result == null) return;

    final itemText =
        result.items.isEmpty ? '' : result.items.map((e) => '• $e').join('\n');

    final memoText = result.memo.trim();

    final summary = [
      if (itemText.isNotEmpty) itemText,
      if (memoText.isNotEmpty) memoText,
    ].join('\n');

    if (summary.trim().isEmpty) return;

    _showActionToast(
      context,
      '상담 체크리스트를 정리했어요. 다음 단계에서 회원카드 메모 저장까지 연결하면 됩니다.',
      bottomOffset: 110,
    );
  }

  // ---------- 셀 탭 처리 ----------

  String _buildSessionCountText(Map<String, dynamic>? session) {
    if (session == null) return '';

    int? parseIntValue(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toInt();

      final text = value.toString().trim();
      if (text.isEmpty || text == 'null') return null;

      return int.tryParse(text);
    }

    final bool isConfirmed = session['lessonConfirmed'] == true ||
        session['lessonConfirmedAt'] != null ||
        (session['lessonConfirmStatus'] ?? '').toString().trim().isNotEmpty ||
        (session['trainingLogId'] ?? '').toString().trim().isNotEmpty;

    if (isConfirmed) {
      final lessonNumber = parseIntValue(
        session['sessionSnapshotLessonNumber'] ??
            session['sessionSnapshotDoneAfter'],
      );

      final total = parseIntValue(session['sessionSnapshotTotal']);

      if (lessonNumber != null &&
          lessonNumber > 0 &&
          total != null &&
          total > 0) {
        return '$lessonNumber/$total';
      }

      final snapshotLabel =
          (session['sessionSnapshotLabel'] ?? '').toString().trim();

      if (snapshotLabel.isNotEmpty) {
        return snapshotLabel;
      }
    }

    final total = parseIntValue(session['totalSessions']);
    final remain = parseIntValue(
      session['remainingSessions'] ?? session['remainSessions'],
    );

    if (total != null && total > 0 && remain != null) {
      final done = (total - remain).clamp(0, total);
      final nextLessonNumber = (done + 1).clamp(1, total);
      return '$nextLessonNumber/$total';
    }

    return '';
  }

  Map<String, String> _memberSessionCountFieldsFromData(
    Map<String, dynamic> data,
  ) {
    return HomeMemberLookupService.memberSessionCountFieldsFromData(data);
  }

  Future<String> _loadMemberSessionCountText(String memberId) async {
    final value = await HomeMemberLookupService.loadMemberSessionCountText(
      memberId,
      ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
    );

    if (value.isEmpty) {
      return '';
    }

    return value;
  }

  DateTime? _dateFromAny(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  int _homeDaysBetween(DateTime from, DateTime to) {
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(to.year, to.month, to.day);
    return b.difference(a).inDays;
  }

  int? _homeDaysUntilMonthDay(DateTime? value, DateTime now) {
    if (value == null) return null;

    final today = DateTime(now.year, now.month, now.day);
    var target = DateTime(today.year, value.month, value.day);

    if (target.isBefore(today)) {
      target = DateTime(today.year + 1, value.month, value.day);
    }

    return target.difference(today).inDays;
  }

  int? _homeFemaleConditionDaysLeft(Map<String, dynamic> data, DateTime now) {
    final health = data['health'] is Map
        ? Map<String, dynamic>.from(data['health'] as Map)
        : <String, dynamic>{};

    final female = health['femaleCondition'] is Map
        ? Map<String, dynamic>.from(health['femaleCondition'] as Map)
        : <String, dynamic>{};

    if (female['enabled'] != true) return null;

    final lastStart = _dateFromAny(female['lastStartAt']);
    if (lastStart == null) return null;

    final rawCycle = female['cycleDays'];
    final cycleDays = rawCycle is num ? rawCycle.toInt().clamp(20, 45) : 28;

    final today = DateTime(now.year, now.month, now.day);
    var expected = DateTime(lastStart.year, lastStart.month, lastStart.day);

    while (expected.isBefore(today.subtract(const Duration(days: 2)))) {
      expected = expected.add(Duration(days: cycleDays));
    }

    return expected.difference(today).inDays;
  }

  bool _homeHasMoreSenseSignal(Map<String, dynamic> data) {
    if (data['isDeleted'] == true) return false;
    if ((data['deleteStatus'] ?? '').toString() == 'pending_delete')
      return false;

    final now = DateTime.now();

    final status = (data['memberStatus'] ?? '활성').toString();
    final isDormant = status == '휴면';
    final isExpired = status == '만료';

    if (isDormant) return true;
    if (isExpired) return true;

    final sessions = data['sessions'] is Map
        ? Map<String, dynamic>.from(data['sessions'] as Map)
        : <String, dynamic>{};

    int intFromAny(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse((value ?? '').toString()) ?? 0;
    }

    final remain = intFromAny(
      data['remainingSessions'] ??
          data['remainSessions'] ??
          sessions['remain'] ??
          data['remainingPt'] ??
          data['ptRemaining'],
    );

    final total = intFromAny(
      data['totalSessions'] ?? sessions['total'] ?? data['sessionTotal'],
    );

    if (total > 0 && remain >= 0 && remain <= 5) {
      return true;
    }

    final expireAt = _dateFromAny(data['expireAt']) ??
        _dateFromAny((data['membership'] is Map)
            ? (data['membership'] as Map)['endAt']
            : null);

    final membershipDaysLeft =
        expireAt == null ? null : _homeDaysBetween(now, expireAt);

    if (membershipDaysLeft != null &&
        membershipDaysLeft >= 0 &&
        membershipDaysLeft <= 10) {
      return true;
    }

    final birthDate = _dateFromAny(
      data['birth'] ?? data['birthDate'] ?? data['birthday'],
    );

    final birthdayDaysLeft = _homeDaysUntilMonthDay(birthDate, now);

    if (birthdayDaysLeft != null &&
        birthdayDaysLeft >= 0 &&
        birthdayDaysLeft <= 7) {
      return true;
    }

    final anniversaryDaysLeft = _homeDaysUntilMonthDay(
      _dateFromAny(data['anniversaryDate']),
      now,
    );

    if (anniversaryDaysLeft != null &&
        anniversaryDaysLeft >= 0 &&
        anniversaryDaysLeft <= 14) {
      return true;
    }

    final nextMoreDayAt = _dateFromAny(data['nextMoreDayAt']);
    final nextMoreDayDaysLeft =
        nextMoreDayAt == null ? null : _homeDaysBetween(now, nextMoreDayAt);

    if (nextMoreDayDaysLeft != null &&
        nextMoreDayDaysLeft >= -7 &&
        nextMoreDayDaysLeft <= 14) {
      return true;
    }

    final femaleConditionDaysLeft = _homeFemaleConditionDaysLeft(data, now);

    if (femaleConditionDaysLeft != null &&
        femaleConditionDaysLeft >= -2 &&
        femaleConditionDaysLeft <= 3) {
      return true;
    }

    return false;
  }

  List<HomeMoreSenseContext> _homeMoreSenseContexts(
    String memberId,
    Map<String, dynamic> data,
  ) {
    final now = currentTime;
    final name = (data['name'] ?? '').toString().trim();
    final result = <HomeMoreSenseContext>[];
    final birth =
        _dateFromAny(data['birth'] ?? data['birthDate'] ?? data['birthday']);
    if (birth != null && birth.month == now.month && birth.day == now.day) {
      result.add(HomeMoreSenseContext(
        key: 'birthday:$memberId:${now.year}',
        kind: HomeMoreSenseKind.birthday,
        memberName: name,
      ));
    }

    final membership = data['membership'] is Map
        ? Map<String, dynamic>.from(data['membership'] as Map)
        : const <String, dynamic>{};
    final expiry =
        _dateFromAny(data['expireAt']) ?? _dateFromAny(membership['endAt']);
    if (expiry != null && _homeDaysBetween(now, expiry) == 0) {
      result.add(HomeMoreSenseContext(
        key: 'expiry:$memberId:${now.year}-${now.month}-${now.day}',
        kind: HomeMoreSenseKind.membershipExpiry,
        memberName: name,
      ));
    }

    final dDay = _dateFromAny(data['nextMoreDayAt']);
    if (dDay != null && _homeDaysBetween(now, dDay) == 0) {
      result.add(HomeMoreSenseContext(
        key: 'dday:$memberId:${now.year}-${now.month}-${now.day}',
        kind: HomeMoreSenseKind.dDay,
        memberName: name,
      ));
    }

    final anniversary =
        _dateFromAny(data['anniversaryDate'] ?? data['firstLessonAt']);
    if (anniversary != null &&
        anniversary.month == now.month &&
        anniversary.day == now.day &&
        now.isAfter(anniversary)) {
      result.add(HomeMoreSenseContext(
        key: 'milestone:$memberId:${now.year}',
        kind: HomeMoreSenseKind.milestone,
        memberName: name,
        days: DateTime(now.year, now.month, now.day)
            .difference(
                DateTime(anniversary.year, anniversary.month, anniversary.day))
            .inDays,
      ));
    }

    final sessions = data['sessions'] is Map
        ? Map<String, dynamic>.from(data['sessions'] as Map)
        : const <String, dynamic>{};
    final rawRemain = data['remainingSessions'] ??
        data['remainSessions'] ??
        sessions['remain'] ??
        data['remainingPt'] ??
        data['ptRemaining'];
    final remain =
        rawRemain is num ? rawRemain.toInt() : int.tryParse('$rawRemain');
    if (remain != null && remain >= 0 && remain <= 5) {
      result.add(HomeMoreSenseContext(
        key: 'low:$memberId:$remain',
        kind: HomeMoreSenseKind.lowSessions,
        memberName: name,
      ));
    }
    return result;
  }

  bool _homeHasKakaoCardLinkedMember(Map<String, dynamic> data) {
    if (data['isDeleted'] == true) return false;
    if ((data['deleteStatus'] ?? '').toString() == 'pending_delete') {
      return false;
    }

    final name = (data['name'] ?? '').toString().trim();
    final phone =
        (data['phone'] ?? data['phoneDisplay'] ?? '').toString().trim();

    final hasCardCore = name.isNotEmpty || phone.isNotEmpty;

    if (!hasCardCore) return false;

    final kakaoLinked = data['kakaoLinked'] == true ||
        data['kakaoConnected'] == true ||
        data['kakaoSyncEnabled'] == true ||
        data['kakaoCardLinked'] == true ||
        data['kakaoClientCardLinked'] == true ||
        (data['kakaoUserId'] ?? '').toString().trim().isNotEmpty ||
        (data['kakaoMemberId'] ?? '').toString().trim().isNotEmpty ||
        (data['kakaoPhone'] ?? '').toString().trim().isNotEmpty;

    return kakaoLinked;
  }

  bool _homeHasSignedContractMember(Map<String, dynamic> data) {
    if (data['isDeleted'] == true) return false;
    if ((data['deleteStatus'] ?? '').toString() == 'pending_delete') {
      return false;
    }

    final lessonSync = data['lessonSync'] is Map
        ? Map<String, dynamic>.from(data['lessonSync'] as Map)
        : <String, dynamic>{};

    final lastContractSummary = data['lastContractSummary'] is Map
        ? Map<String, dynamic>.from(data['lastContractSummary'] as Map)
        : <String, dynamic>{};

    final contractId = (data['contractId'] ??
            lessonSync['contractId'] ??
            lastContractSummary['contractId'] ??
            '')
        .toString()
        .trim();

    return data['contractSigned'] == true ||
        data['isContractSigned'] == true ||
        data['finalSigned'] == true ||
        lessonSync['contractSigned'] == true ||
        contractId.isNotEmpty;
  }

  int _homeEarnedTierRank({
    required bool profileCompleted,
    required bool kakaoLinked,
    required int activeMemberCount,
    required int kakaoCardLinkedMemberCount,
    required int contractSignedMemberCount,
  }) {
    if (activeMemberCount >= 50 ||
        kakaoCardLinkedMemberCount >= 40 ||
        contractSignedMemberCount >= 20) {
      return 3; // Pro
    }

    if (activeMemberCount >= 30 || kakaoCardLinkedMemberCount >= 20) {
      return 2; // Semi-Pro
    }

    if (kakaoLinked || profileCompleted) {
      return 1; // Amateur
    }

    return 0; // Beginner
  }

  Future<void> _syncTierAccessCacheToProfile({
    required int activeMemberCount,
    required int kakaoCardLinkedMemberCount,
    required int contractSignedMemberCount,
  }) async {
    final signature = [
      activeMemberCount,
      kakaoCardLinkedMemberCount,
      contractSignedMemberCount,
    ].join('|');

    if (_lastTierCacheSignature == signature || _tierCacheSyncing) {
      return;
    }

    _lastTierCacheSignature = signature;
    _tierCacheSyncing = true;

    try {
      final profileRef = _trainerProfileRef;

      final profileSnap = await profileRef.get();
      final profileData = profileSnap.data() ?? <String, dynamic>{};

      final kakaoLinked = profileData['kakaoLinked'] == true ||
          profileData['kakaoConnected'] == true ||
          profileData['kakaoSyncEnabled'] == true ||
          profileData['hasKakaoAccount'] == true;

      final profileCompleted = profileData['profileCompleted'] == true ||
          profileData['trainerInfoDone'] == true ||
          profileData['myInfoCompleted'] == true;

      final earnedRank = _homeEarnedTierRank(
        profileCompleted: profileCompleted,
        kakaoLinked: kakaoLinked,
        activeMemberCount: activeMemberCount,
        kakaoCardLinkedMemberCount: kakaoCardLinkedMemberCount,
        contractSignedMemberCount: contractSignedMemberCount,
      );

      final supportRank = [
        profileData['supportTier'],
        profileData['subscriptionTier'],
        profileData['paidTier'],
        profileData['sponsorTier'],
        profileData['planTier'],
        profileData['plan'],
      ].fold<int>(0, (maxRank, value) {
        final rank = AppTierAccessService.tierRankFromText(
          (value ?? '').toString(),
        );

        return rank > maxRank ? rank : maxRank;
      });

      final organizationRank = [
        profileData['organizationTier'],
        profileData['orgTier'],
        profileData['centerTier'],
      ].fold<int>(0, (maxRank, value) {
        final rank = AppTierAccessService.tierRankFromText(
          (value ?? '').toString(),
        );

        return rank > maxRank ? rank : maxRank;
      });

      final sponsorRank = profileData['isSponsor'] == true ? 2 : 0;

      final effectiveRank = [
        earnedRank,
        supportRank,
        organizationRank,
        sponsorRank,
      ].fold<int>(0, (maxRank, value) {
        return value > maxRank ? value : maxRank;
      });

      final earnedTier = AppTierAccessService.tierLabelFromRank(earnedRank);
      final effectiveTier =
          AppTierAccessService.tierLabelFromRank(effectiveRank);

      await profileRef.set(
        {
          'activeMemberCount': activeMemberCount,
          'kakaoCardLinkedMemberCount': kakaoCardLinkedMemberCount,
          'contractSignedMemberCount': contractSignedMemberCount,
          'profileCompleted': profileCompleted,
          'myInfoCompleted': profileCompleted,
          'earnedTier': earnedTier,
          'effectiveTier': effectiveTier,
          'tierUpdatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (kDebugMode) {
        debugPrint(
          '[MTF_TIER] cache synced '
          'active=$activeMemberCount '
          'kakaoCard=$kakaoCardLinkedMemberCount '
          'contract=$contractSignedMemberCount '
          'earned=$earnedTier '
          'effective=$effectiveTier',
        );
      }
    } catch (e) {
      debugPrint('[MTF_TIER] cache sync failed: $e');
    } finally {
      _tierCacheSyncing = false;
    }
  }

  Future<Map<String, dynamic>> _loadMemberLogPageArgs({
    required String memberId,
    required String fallbackName,
    String? fallbackPhone,
  }) async {
    final cleanId = memberId.trim();

    if (cleanId.isEmpty) {
      return {
        'memberName': fallbackName,
        'memberPhone': fallbackPhone ?? '',
        'totalSessions': 0,
        'remainingSessions': 0,
        'lastLogAt': null,
      };
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('members')
          .doc(cleanId)
          .get();

      final data = snap.data();

      if (data == null) {
        return {
          'memberName': fallbackName,
          'memberPhone': fallbackPhone ?? '',
          'totalSessions': 0,
          'remainingSessions': 0,
          'lastLogAt': null,
        };
      }

      final countFields = _memberSessionCountFieldsFromData(data);

      final total = int.tryParse(
            (countFields['totalSessions'] ?? '').toString(),
          ) ??
          0;

      final remain = int.tryParse(
            (countFields['remainingSessions'] ?? '').toString(),
          ) ??
          0;

      final loadedName = (data['name'] ?? '').toString().trim();
      final loadedPhone = (data['phone'] ?? '').toString().trim();

      return {
        'memberName': loadedName.isNotEmpty ? loadedName : fallbackName,
        'memberPhone':
            loadedPhone.isNotEmpty ? loadedPhone : (fallbackPhone ?? ''),
        'totalSessions': total,
        'remainingSessions': remain,
        'lastLogAt': _dateFromAny(data['lastLessonAt'] ?? data['lastLogAt']),
      };
    } catch (e) {
      debugPrint('레슨일지 회원 정보 불러오기 실패: $e');

      return {
        'memberName': fallbackName,
        'memberPhone': fallbackPhone ?? '',
        'totalSessions': 0,
        'remainingSessions': 0,
        'lastLogAt': null,
      };
    }
  }

  Future<Map<String, String>> _loadMemberSessionCountFields(
    String memberId,
  ) {
    return HomeMemberLookupService.loadMemberSessionCountFields(
      memberId,
      ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
    );
  }

  Future<Map<String, dynamic>> _loadMemberSmartAlarmFields(
    String memberId,
  ) async {
    final cleanMemberId = memberId.trim();
    if (cleanMemberId.isEmpty) return const {};

    try {
      final snap = await FirebaseFirestore.instance
          .collection('members')
          .doc(cleanMemberId)
          .get();

      final data = snap.data();
      if (data == null) return const {};

      if (data['isDeleted'] == true ||
          (data['deleteStatus'] ?? '').toString() == 'pending_delete') {
        return const {};
      }

      final result = <String, dynamic>{};

      final sessions = data['sessions'] is Map
          ? Map<String, dynamic>.from(data['sessions'] as Map)
          : <String, dynamic>{};

      final lessonSync = data['lessonSync'] is Map
          ? Map<String, dynamic>.from(data['lessonSync'] as Map)
          : <String, dynamic>{};

      final lastContractSummary = data['lastContractSummary'] is Map
          ? Map<String, dynamic>.from(data['lastContractSummary'] as Map)
          : <String, dynamic>{};

      final smartAlarmContext = data['smartAlarmContext'] is Map
          ? Map<String, dynamic>.from(data['smartAlarmContext'] as Map)
          : <String, dynamic>{};

      final moreCareSlotMap = data['moreCareSlot'] is Map
          ? Map<String, dynamic>.from(data['moreCareSlot'] as Map)
          : <String, dynamic>{};

      final moreCareStatusText =
          (data['moreCareStatus'] ?? moreCareSlotMap['status'] ?? '')
              .toString()
              .trim();

      final moreCareRequestIdText =
          (data['moreCareRequestId'] ?? moreCareSlotMap['requestId'] ?? '')
              .toString()
              .trim();

      final moreCareTemporaryUntilValue =
          data['moreCareTemporaryUntil'] ?? moreCareSlotMap['temporaryUntil'];

      final doneSessions = _toNullableInt(
        data['doneSessions'] ??
            data['usedSessions'] ??
            sessions['done'] ??
            sessions['used'],
      );

      if (doneSessions != null) {
        result['doneSessions'] = doneSessions.toString();
      }

      final contractId = (data['contractId'] ??
              lessonSync['contractId'] ??
              lastContractSummary['contractId'] ??
              '')
          .toString()
          .trim();

      final contractNo =
          (data['contractNo'] ?? lastContractSummary['contractNo'] ?? '')
              .toString()
              .trim();

      final lessonSyncSource = (data['lessonSyncSource'] ??
              data['contractLessonSyncSource'] ??
              lessonSync['source'] ??
              '')
          .toString()
          .trim();

      final contractSigned = data['contractSigned'] == true ||
          data['isContractSigned'] == true ||
          data['finalSigned'] == true ||
          lessonSync['contractSigned'] == true ||
          contractId.isNotEmpty;

      if (contractId.isNotEmpty) {
        result['contractId'] = contractId;
      }

      if (contractNo.isNotEmpty) {
        result['contractNo'] = contractNo;
      }

      if (contractSigned) {
        result['contractSigned'] = true;
      }

      if (lessonSyncSource.isNotEmpty) {
        result['lessonSyncSource'] = lessonSyncSource;
      }

      if (smartAlarmContext.isNotEmpty) {
        result['smartAlarmContext'] = smartAlarmContext;
      }

      final lastLessonLogSummary =
          (data['lastLessonLogSummary'] ?? '').toString().trim();

      if (lastLessonLogSummary.isNotEmpty) {
        result['lastLessonLogSummary'] = lastLessonLogSummary;
      }

      final nextLessonReminderHint =
          (data['nextLessonReminderHint'] ?? '').toString().trim();

      if (nextLessonReminderHint.isNotEmpty) {
        result['nextLessonReminderHint'] = nextLessonReminderHint;
      }

      final rawKeywords = data['lastLessonLogKeywords'];

      if (rawKeywords is List && rawKeywords.isNotEmpty) {
        result['lastLessonLogKeywords'] =
            rawKeywords.map((e) => e.toString()).toList();
      }

      if (moreCareStatusText.isNotEmpty) {
        result['moreCareStatus'] = moreCareStatusText;
      }

      if (moreCareRequestIdText.isNotEmpty) {
        result['moreCareRequestId'] = moreCareRequestIdText;
      }

      if (moreCareTemporaryUntilValue != null) {
        result['moreCareTemporaryUntil'] = moreCareTemporaryUntilValue;
      }

      if (moreCareSlotMap.isNotEmpty) {
        result['moreCareSlot'] = moreCareSlotMap;
      }

      final membershipMap = data['membership'] is Map
          ? Map<String, dynamic>.from(data['membership'] as Map)
          : <String, dynamic>{};

      final membershipStatus =
          (membershipMap['status'] ?? data['membershipStatus'] ?? '')
              .toString()
              .trim();

      if (membershipStatus.isNotEmpty) {
        result['membershipStatus'] = membershipStatus;
      }

      final membershipEndAt = _dateFromAny(
        membershipMap['endAt'] ??
            data['membershipEndAt'] ??
            data['passEnd'] ??
            data['expireAt'],
      );

      if (membershipEndAt != null) {
        final membershipDaysLeft =
            _homeDaysBetween(DateTime.now(), membershipEndAt);

        result['membershipEndAt'] = membershipEndAt;
        result['membershipDaysLeft'] = membershipDaysLeft;
        result['membershipDDay'] = membershipDaysLeft;
      }

      final membershipContractStatus = (data['membershipContractStatus'] ??
              membershipMap['contractStatus'] ??
              '')
          .toString()
          .trim();

      final membershipContractSignedAt = _dateFromAny(
        data['membershipContractSignedAt'] ?? membershipMap['contractSignedAt'],
      );

      final membershipContractDraftExists =
          data['membershipContractDraftExists'] == true ||
              membershipContractStatus == 'draft';

      final membershipContractSigned = membershipContractStatus == 'signed' ||
          membershipContractSignedAt != null;

      if (membershipContractStatus.isNotEmpty) {
        result['membershipContractStatus'] = membershipContractStatus;
      } else if (membershipContractDraftExists) {
        result['membershipContractStatus'] = 'draft';
      }

      if (membershipContractDraftExists) {
        result['membershipContractDraftExists'] = true;
      }

      if (membershipContractSigned) {
        result['membershipContractSigned'] = true;
      }

      if (membershipContractDraftExists && !membershipContractSigned) {
        result['membershipContractNeedsSignature'] = true;
      }

      final membershipResumeDueAt = _dateFromAny(
        membershipMap['resumeDueAt'] ?? data['membershipResumeDueAt'],
      );

      if (membershipResumeDueAt != null) {
        result['membershipResumeDueAt'] = membershipResumeDueAt;

        final resumeDaysLeft =
            _homeDaysBetween(DateTime.now(), membershipResumeDueAt);
        result['membershipResumeDaysLeft'] = resumeDaysLeft;
      }

      if (result.isNotEmpty && kDebugMode) {
        debugPrint(
          '[MTF_SMART_ALARM] member smart fields loaded '
          'memberIdPresent=${cleanMemberId.isNotEmpty} '
          'keys=${result.keys.join(', ')}',
        );
      }

      return result;
    } catch (e) {
      debugPrint('회원 스마트 알림 필드 불러오기 실패: $e');
      return const {};
    }
  }

  Future<bool> _isDeletedMemberId(String? memberId) {
    return HomeMemberLookupService.isDeletedMemberId(
      memberId,
      ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
    );
  }

  bool _isLinkedMemberDeletedFromSession(Map<String, dynamic>? session) {
    if (session == null) return false;

    return session['linkedMemberDeleted'] == true ||
        session['memberIsDeleted'] == true ||
        (session['memberDeleteStatus'] ?? '').toString() == 'pending_delete';
  }

  Future<void> _refreshScheduleCountsFromMembers() async {
    if (scheduleData.isEmpty) return;

    final upsert = <String, Map<String, dynamic>>{};

    final scheduleEntries = scheduleData.entries.toList();

    for (final entry in scheduleEntries) {
      final rawValue = entry.value;

      if (rawValue is! Map) continue;

      final raw = Map<String, dynamic>.from(rawValue);

      final docId = (raw['docId'] ?? '').toString().trim();

      if (docId.isNotEmpty && _isScheduleDocTemporarilyHidden(docId)) {
        continue;
      }

      if (_isScheduleDataDeleted(raw)) {
        continue;
      }

      // 확정된 레슨은 확정 당시 회차 스냅샷을 유지해야 하므로
      // 고객카드 최신 회차로 다시 덮어쓰지 않습니다.
      // 단, 스마트 알림 context는 다음 레슨 준비용 정보라서 별도로 반영할 수 있습니다.
      final memberId = (raw['memberId'] ?? '').toString().trim();
      if (memberId.isEmpty) continue;

      final memberDeleted = await _isDeletedMemberId(memberId);

      if (memberDeleted) {
        upsert[entry.key] = {
          ...raw,
          'linkedMemberDeleted': true,
          'memberIsDeleted': true,
          'memberDeleteStatus': 'pending_delete',
        };
        continue;
      }

      final latestSmartFields = await _loadMemberSmartAlarmFields(memberId);

      if (_isScheduleLessonConfirmed(raw)) {
        if (latestSmartFields.isEmpty) continue;

        final next = {
          ...Map<String, dynamic>.from(raw),
          ...latestSmartFields,
        };

        if (!mapEquals(raw, next)) {
          upsert[entry.key] = next;
        }

        continue;
      }

      final latestCountFields = await _loadMemberSessionCountFields(memberId);

      final currentRemain = (raw['remainingSessions'] ?? '').toString();
      final currentTotal = (raw['totalSessions'] ?? '').toString();

      final nextRemain = latestCountFields['remainingSessions'] ?? '';
      final nextTotal = latestCountFields['totalSessions'] ?? '';

      final next = Map<String, dynamic>.from(raw);

      var changed = false;

      if (nextRemain.isNotEmpty && currentRemain != nextRemain) {
        next['remainingSessions'] = nextRemain;
        changed = true;
      }

      if (nextTotal.isNotEmpty && currentTotal != nextTotal) {
        next['totalSessions'] = nextTotal;
        changed = true;
      }

      for (final entry in latestSmartFields.entries) {
        final prevValue = next[entry.key];
        final nextValue = entry.value;

        if (prevValue is Map && nextValue is Map) {
          if (mapEquals(
            Map<String, dynamic>.from(prevValue),
            Map<String, dynamic>.from(nextValue),
          )) {
            continue;
          }
        } else if (prevValue is List && nextValue is List) {
          if (listEquals(prevValue, nextValue)) {
            continue;
          }
        } else if (prevValue == nextValue) {
          continue;
        }

        next[entry.key] = nextValue;
        changed = true;
      }

      if (changed) {
        upsert[entry.key] = next;
      }
    }

    if (upsert.isEmpty) return;

    if (kDebugMode) {
      debugPrint(
        '[MTF_SMART_ALARM] schedule smart fields patched '
        'count=${upsert.length}',
      );
    }

    _patchScheduleData(
      upsert: upsert,
      syncWidget: true,
    );
  }

  String _buildTodayLessonCountText(Map<String, dynamic> data) {
    final total = (data['totalSessions'] ?? '').toString().trim();

    final remain = (data['remainingSessions'] ?? '').toString().trim();

    if (total.isEmpty && remain.isEmpty) return '';

    if (total.isNotEmpty && remain.isNotEmpty) {
      return '${total}회 중 ${remain}회 남음';
    }

    if (total.isNotEmpty) return '총 ${total}회';

    return '${remain}회 남음';
  }

  Map<String, dynamic> _parseSessionCount(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return {};

    final parts = value.split('/');
    if (parts.length != 2) return {};

    // 표기 기준:
    // 10/4 = 총 10회 / 잔여 4회
    final total = parts[0].trim();
    final remain = parts[1].trim();

    final result = <String, dynamic>{};

    if (total.isNotEmpty) {
      result['totalSessions'] = total;
    }

    if (remain.isNotEmpty) {
      result['remainingSessions'] = remain;
    }

    return result;
  }

  Future<void> _saveScheduleToFirestore({
    required int weekOffset,
    required String day,
    required String time,
    required String endTime,
    required String name,
    required LessonTypeItem lessonType,
    required bool attended,
    required Map<String, dynamic> countMap,
    String? memberId,
    String? phone,
    String? memo,
  }) async {
    final dt = _dateForCell(weekOffset, day, time);
    final endDt = _dateForCell(weekOffset, day, endTime);

    if (!endDt.isAfter(dt)) {
      throw Exception('종료 시간은 시작 시간보다 늦어야 합니다.');
    }

    final docId = _scheduleDocIdFromDate(dt, day);

    _clearRecentlyDeletedScheduleDocId(docId);

    await HomeScheduleFirestoreService.saveSchedule(
      docId: docId,
      startAt: dt,
      endAt: endDt,
      day: day,
      time: time,
      endTime: endTime,
      name: name,
      lessonTypeName: lessonType.name,
      lessonTypeId: lessonType.id,
      lessonTypeColorHex: lessonType.colorHex,
      attended: attended,
      countMap: countMap,
      memberId: memberId,
      phone: phone,
      memo: memo,
      ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
    );
  }

  Future<void> _refreshMemberNextLesson(String memberId) async {
    final cleanMemberId = memberId.trim();
    if (cleanMemberId.isEmpty) return;

    try {
      await HomeScheduleFirestoreService.refreshMemberNextLesson(
        cleanMemberId,
        ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
      );
    } catch (e) {
      debugPrint('nextLessonAt 갱신 실패: $e');
    }
  }

  void _removeLocalScheduleByDocId(
    String docId, {
    bool syncWidget = true,
  }) {
    final cleanDocId = docId.trim();
    if (cleanDocId.isEmpty) return;

    _markScheduleDocAsRecentlyDeleted(cleanDocId);

    final removeKeys = <String>[];

    scheduleData.forEach((key, value) {
      if (value is! Map<String, dynamic>) return;

      final currentDocId = value['docId']?.toString().trim() ?? '';
      if (currentDocId == cleanDocId) {
        removeKeys.add(key);
      }
    });

    if (removeKeys.isEmpty) return;

    _patchScheduleData(
      removeKeys: removeKeys,
      syncWidget: syncWidget,
    );
  }

  void _markScheduleDocAsRecentlyDeleted(String docId) {
    final cleanDocId = docId.trim();
    if (cleanDocId.isEmpty) return;

    // 시간 제한으로 숨김을 풀지 않습니다.
    // Firestore의 최신 snapshot에서 문서가 실제로 사라진 것이 확인될 때까지
    // tombstone을 유지해야 오래된 snapshot 때문에 일정이 되살아나지 않습니다.
    _recentlyDeletedScheduleDocIds[cleanDocId] = DateTime.now();
    if (kDebugMode) {
      debugPrint(
        '[MTF_SCHEDULE_TOMBSTONE] added docId=$cleanDocId '
        'at=${_recentlyDeletedScheduleDocIds[cleanDocId]!.toIso8601String()}',
      );
    }
  }

  bool _hasSameScheduleIdentity(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    bool sameDate(dynamic a, dynamic b) {
      if (a is! DateTime || b is! DateTime) return a == b;
      return a.isAtSameMomentAs(b);
    }

    String text(Map<String, dynamic> data, String key) =>
        (data[key] ?? '').toString().trim();

    final leftType = text(left, 'typeId').isNotEmpty
        ? text(left, 'typeId')
        : text(left, 'type');
    final rightType = text(right, 'typeId').isNotEmpty
        ? text(right, 'typeId')
        : text(right, 'type');

    return sameDate(left['startAt'], right['startAt']) &&
        sameDate(left['endAt'], right['endAt']) &&
        text(left, 'memberId') == text(right, 'memberId') &&
        text(left, 'name') == text(right, 'name') &&
        leftType == rightType &&
        _isScheduleLessonConfirmed(left) == _isScheduleLessonConfirmed(right);
  }

  Set<String> _exactScheduleSourceDocIds(Map<String, dynamic> data) {
    return <String>{
      _actualScheduleDocumentId(data),
      ...((data['duplicateDocIds'] as List?) ?? const [])
          .map((id) => id.toString().trim()),
    }..removeWhere((id) => id.isEmpty);
  }

  String _actualScheduleDocumentId(Map<String, dynamic> data) {
    return (data['actualDocumentId'] ?? data['docId'] ?? '').toString().trim();
  }

  String _dataScheduleDocumentId(Map<String, dynamic> data) {
    return (data['docId'] ?? '').toString().trim();
  }

  bool _hasUnsafeScheduleCollision(Map<String, dynamic> data) {
    return ((data['conflictingDocIds'] as List?) ?? const [])
        .any((id) => id.toString().trim().isNotEmpty);
  }

  Set<String> _allScheduleDocumentIds(Map<String, dynamic> data) {
    return _exactScheduleSourceDocIds(data);
  }

  void _reconcileRecentlyDeletedScheduleDocIds(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs, {
    required bool isFromCache,
    required bool hasPendingWrites,
    required int revision,
  }) {
    if (_recentlyDeletedScheduleDocIds.isEmpty) return;

    final visibleDocIds =
        docs.map((doc) => doc.id.trim()).where((id) => id.isNotEmpty).toSet();

    for (final docId in _recentlyDeletedScheduleDocIds.keys.toList()) {
      final mutationInFlight = _deletingScheduleDocIds.contains(docId) ||
          _pendingScheduleMutationDocIds.contains(docId);
      final sourcePresent = visibleDocIds.contains(docId);
      final decision = resolveHomeScheduleTombstone(
        isFromCache: isFromCache,
        hasPendingWrites: hasPendingWrites,
        mutationInFlight: mutationInFlight,
        sourcePresent: sourcePresent,
      );

      if (kDebugMode) {
        debugPrint(
          '[MTF_SCHEDULE_TOMBSTONE] revision=$revision docId=$docId '
          'fromCache=$isFromCache pendingWrites=$hasPendingWrites '
          'mutationInFlight=$mutationInFlight sourcePresent=$sourcePresent '
          'decision=$decision',
        );
      }

      if (decision == HomeScheduleTombstoneDecision.keep) continue;

      _recentlyDeletedScheduleDocIds.remove(docId);

      if (kDebugMode) {
        debugPrint(
          '[MTF_SCHEDULE_TOMBSTONE] released docId=$docId '
          'reason=$decision revision=$revision',
        );
      }
    }
  }

  void _clearRecentlyDeletedScheduleDocId(String docId) {
    final cleanDocId = docId.trim();
    if (cleanDocId.isEmpty) return;

    _recentlyDeletedScheduleDocIds.remove(cleanDocId);
    if (kDebugMode) {
      debugPrint(
        '[MTF_SCHEDULE_TOMBSTONE] cleared docId=$cleanDocId',
      );
    }
  }

  void _beginScheduleMutation(Iterable<String> docIds) {
    _pendingScheduleMutationDocIds.addAll(
      docIds.map((id) => id.trim()).where((id) => id.isNotEmpty),
    );
  }

  void _endScheduleMutation(Iterable<String> docIds) {
    for (final docId in docIds) {
      _pendingScheduleMutationDocIds.remove(docId.trim());
    }
  }

  bool _shouldClearTombstoneAfterMutationError(Object error) {
    if (error is! HomeScheduleMutationException) return true;
    return error.reason !=
        HomeScheduleMutationFailureReason.serverVerificationFailed;
  }

  bool _isScheduleDocTemporarilyHidden(String docId) {
    final cleanDocId = docId.trim();
    if (cleanDocId.isEmpty) return false;

    if (_deletingScheduleDocIds.contains(cleanDocId) ||
        _pendingScheduleMutationDocIds.contains(cleanDocId)) {
      return true;
    }

    return _recentlyDeletedScheduleDocIds.containsKey(cleanDocId);
  }

  bool _isScheduleDataDeleted(Map<String, dynamic> data) {
    if (data['isDeleted'] == true) return true;
    if (data['deleted'] == true) return true;
    if (data['voided'] == true) return true;
    if (data['archived'] == true) return true;

    final statusText = [
      data['status'],
      data['scheduleStatus'],
      data['lessonStatus'],
      data['deleteStatus'],
    ].map((e) => (e ?? '').toString().trim().toLowerCase()).join(' ');

    return statusText.contains('deleted') ||
        statusText.contains('delete') ||
        statusText.contains('removed') ||
        statusText.contains('archived') ||
        statusText.contains('voided') ||
        statusText.contains('pending_delete');
  }

  Future<bool> _deleteScheduleFromFirestore(
    String docId, {
    Map<String, dynamic>? schedule,
    String? editSessionLogFields,
  }) async {
    final cleanDocId = docId.trim();

    if (cleanDocId.isEmpty) {
      debugPrint('레슨 삭제 실패: docId 비어 있음');
      return false;
    }

    final scheduleData = schedule ?? const <String, dynamic>{};
    if (_hasUnsafeScheduleCollision(scheduleData)) {
      _showActionToast(
        context,
        '같은 시간에 서로 다른 레슨 문서가 있어 자동 삭제하지 않았어요.',
        bottomOffset: 110,
      );
      return false;
    }

    final sourceDocIds = <String>{
      cleanDocId,
      ..._exactScheduleSourceDocIds(scheduleData),
    };

    // 같은 문서를 연속 탭/중복 콜백으로 여러 번 삭제 요청하는 것 방지
    if (sourceDocIds.any(_deletingScheduleDocIds.contains)) {
      debugPrint('레슨 삭제 중복 요청 무시: $cleanDocId');
      return false;
    }

    _deletingScheduleDocIds.addAll(sourceDocIds);

    if (kDebugMode) {
      debugPrint(
        '[MTF_SCHEDULE_MUTATION] action=delete '
        'actualSourceDocId=$cleanDocId dataDocId=$docId '
        'sourceDocIds=${sourceDocIds.join(',')} '
        '${editSessionLogFields ?? ''}',
      );
    }

    try {
      for (final sourceDocId in sourceDocIds) {
        final isConfirmed = await _isScheduleDocConfirmed(sourceDocId);

        if (isConfirmed) {
          _showActionToast(
            context,
            '확정된 레슨은 삭제할 수 없어요.',
            bottomOffset: 110,
          );
          return false;
        }
      }

      for (final sourceDocId in sourceDocIds) {
        _markScheduleDocAsRecentlyDeleted(sourceDocId);
      }

      final snap = await HomeScheduleFirestoreService.getSchedule(
        cleanDocId,
        ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
      );

      if (kDebugMode) {
        debugPrint(
          '[MTF_SCHEDULE_MUTATION] action=delete resolvedSnapshot '
          'uiTime=${(scheduleData['time'] ?? '').toString()} '
          'currentActualDocId=$cleanDocId '
          'currentDataDocId=${(scheduleData['docId'] ?? '').toString()} '
          'snapshotId=${snap.id} referencePath=${snap.reference.path} '
          '${editSessionLogFields ?? ''}',
        );
      }

      // Firestore 문서가 이미 없으면 실패가 아니라
      // 로컬에 남은 오래된 블럭만 정리하고 성공 처리합니다.
      if (!snap.exists) {
        debugPrint('레슨 삭제: 이미 삭제된 문서라 로컬에서만 정리합니다. ($cleanDocId)');

        _removeLocalScheduleByDocId(
          cleanDocId,
          syncWidget: false,
        );

        if (mounted) {
          _queueHomeWidgetSync();
        }

        await _reconcilePersonalTierAfterServerWrite('scheduleDelete');

        return true;
      }

      final data = snap.data();
      final memberId = (data?['memberId'] ?? '').toString().trim();

      if (sourceDocIds.length == 1) {
        await HomeScheduleFirestoreService.deleteSchedule(
          cleanDocId,
          ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
        );
      } else {
        await HomeScheduleFirestoreService.deleteSchedules(
          sourceDocIds.toList(),
          ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
        );
      }

      for (final sourceDocId in sourceDocIds) {
        _removeLocalScheduleByDocId(
          sourceDocId,
          syncWidget: false,
        );
      }

      if (memberId.isNotEmpty) {
        await _refreshMemberNextLesson(memberId);
      }

      if (mounted) {
        _queueHomeWidgetSync(delay: Duration.zero);
        _queueNotificationSync(delay: Duration.zero);
        _updateBannerState();
      }

      await _reconcilePersonalTierAfterServerWrite('scheduleDelete');

      return true;
    } catch (e) {
      if (_shouldClearTombstoneAfterMutationError(e)) {
        for (final sourceDocId in sourceDocIds) {
          _clearRecentlyDeletedScheduleDocId(sourceDocId);
        }
      }
      debugPrint('레슨 삭제 실패: $e');
      _logTierReconcileSkipped('scheduleDelete');
      return false;
    } finally {
      _deletingScheduleDocIds.removeAll(sourceDocIds);
    }
  }

  Future<String?> _resolveLinkedMemberId({
    String? memberId,
    required String memberName,
    String? phone,
  }) async {
    final cleanMemberId = memberId?.trim() ?? '';

    if (cleanMemberId.isNotEmpty) {
      return cleanMemberId;
    }

    // 안전 기준:
    // 회원카드/레슨일지는 memberId가 있을 때만 직접 이동합니다.
    // 이름이나 전화번호로 자동 탐색하면 동명이인 또는 예전 수기 데이터가
    // 다른 회원카드로 열릴 수 있습니다.
    return null;
  }

  Future<List<Map<String, dynamic>>> _findExactMemberCandidates(
    String inputText,
  ) {
    return HomeMemberLookupService.findExactMemberCandidates(
      inputText,
      ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
    );
  }

  Future<Map<String, dynamic>?> _openMemberMatchPickerSheet({
    required String typedName,
    required String lessonLabel,
    required List<Map<String, dynamic>> candidates,
  }) async {
    return HomeMemberMatchPickerSheet.show(
      context: context,
      typedName: typedName,
      lessonLabel: lessonLabel,
      candidates: candidates,
    );
  }

  Future<Map<String, String?>?> _resolveMemberLinkBeforeSave({
    required String inputText,
    required String lessonLabel,
    String? selectedMemberId,
    String? selectedMemberPhone,
  }) async {
    final selectedLink =
        await HomeMemberLookupService.resolveSelectedMemberLink(
      selectedMemberId: selectedMemberId,
      selectedMemberPhone: selectedMemberPhone,
      ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
    );

    if (selectedLink != null) {
      return selectedLink;
    }

    final candidates = await _findExactMemberCandidates(inputText);

    if (candidates.isEmpty) {
      return HomeMemberLookupService.emptyResolvedLink();
    }

    final picked = await _openMemberMatchPickerSheet(
      typedName: inputText.trim(),
      lessonLabel: lessonLabel,
      candidates: candidates,
    );

    if (picked == null || picked['manual'] == true) {
      return HomeMemberLookupService.emptyResolvedLink();
    }

    return HomeMemberLookupService.resolvedLinkFromPickedCandidate(picked);
  }

  Future<void> _openClientCardFromManualSchedule({
    required String memberName,
    String? phone,
    String? scheduleDocId,
  }) async {
    if (!await _guardCustomerCardCreate('manual_schedule_customer_card')) {
      return;
    }
    final cleanName = memberName.trim();
    final cleanPhone = _normalizePhone(phone ?? '');

    if (cleanName.isEmpty) {
      _showActionToast(context, '회원 이름을 먼저 입력해주세요.', bottomOffset: 110);
      return;
    }

    final newId = FirebaseFirestore.instance.collection('members').doc().id;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientCardPage.fromQuickRegistration(
          memberId: newId,
          initialName: cleanName,
          initialPhone: cleanPhone,
          initialVisitDate: DateTime.now(),
          initialConsultDate: null,
          personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
        ),
      ),
    );

    if (!mounted) return;

    final memberSnap =
        await FirebaseFirestore.instance.collection('members').doc(newId).get();

    if (!memberSnap.exists) {
      _showActionToast(
        context,
        '회원 등록이 완료되지 않아 미등록 상태로 유지되었어요.',
        bottomOffset: 110,
      );
      return;
    }

    final memberData = memberSnap.data() ?? <String, dynamic>{};
    final countFields = _memberSessionCountFieldsFromData(memberData);

    final docId = scheduleDocId?.trim() ?? '';

    final savedPhone = _normalizePhone(
      (memberData['phone'] ?? cleanPhone).toString(),
    );

    bool linkedToSchedule = false;

    if (docId.isNotEmpty) {
      linkedToSchedule = await _applyMemberLinkToSchedule(
        scheduleDocId: docId,
        memberId: newId,
        phone: savedPhone,
        sessionCountFields: countFields,
        waitForCountsRefresh: false,
      );
    }

    if (!mounted) return;

    if (linkedToSchedule) {
      _showActionToast(
        context,
        '회원으로 등록하고 레슨일정에 연결했어요.',
        bottomOffset: 110,
      );
    } else {
      _showActionToast(
        context,
        '회원카드는 등록했어요. 다만 레슨일정 연결은 다시 확인해주세요.',
        bottomOffset: 110,
      );
    }
  }

  Future<bool> _openCancelConfirmedLessonSheet({
    required String scheduleDocId,
  }) async {
    final cleanScheduleDocId = scheduleDocId.trim();

    if (cleanScheduleDocId.isEmpty) {
      _showActionToast(
        context,
        '확정취소할 레슨일정을 찾지 못했어요.',
        bottomOffset: 110,
      );
      return false;
    }

    final scheduleSnap = await FirebaseFirestore.instance
        .collection('schedules')
        .doc(cleanScheduleDocId)
        .get();

    final scheduleData = scheduleSnap.data();

    final bool isMemberSignedConfirmed =
        _isCustomerSignedConfirmedSchedule(scheduleData);

    final bool isContractLinkedConfirmed =
        _isContractLinkedConfirmedSchedule(scheduleData);

    if (isMemberSignedConfirmed || isContractLinkedConfirmed) {
      if (!mounted) return false;

      final message = isMemberSignedConfirmed
          ? '회원 서명이 포함된 레슨 확정은 임의로 취소할 수 없어요.\n'
              '서명 기록 보호를 위해 레슨일지에서 확인만 가능해요.'
          : '계약서 기준으로 확정된 레슨은 임의로 취소할 수 없어요.\n'
              '계약서와 연결된 회차 기록은 보호됩니다.';

      _showActionToast(
        context,
        message,
        bottomOffset: 110,
        duration: const Duration(milliseconds: 2200),
      );

      return false;
    }

    final result = await _cancelConfirmedLessonByScheduleDocId(
      cleanScheduleDocId,
    );

    if (!mounted) {
      return false;
    }

    if (result != true) {
      _showActionToast(
        context,
        '확정취소에 실패했어요. 다시 확인해주세요.',
        bottomOffset: 110,
      );
      return false;
    }

    _showActionToast(
      context,
      '레슨 확정을 취소했어요. 차감된 회차가 있다면 회원카드에 되돌렸어요.',
      bottomOffset: 110,
      duration: const Duration(milliseconds: 1900),
    );

    unawaited(() async {
      await _refreshScheduleCountsFromMembers();

      if (mounted) {
        _queueHomeWidgetSync();
      }
    }());

    return true;
  }

  Future<bool> _cancelConfirmedLessonByScheduleDocId(
    String scheduleDocId,
  ) async {
    final cleanScheduleDocId = scheduleDocId.trim();
    if (cleanScheduleDocId.isEmpty) return false;

    try {
      if (_isPersonalWorkspace) {
        final scheduleSnapshot = await FirebaseFirestore.instance
            .collection('schedules')
            .doc(cleanScheduleDocId)
            .get();
        final schedule = scheduleSnapshot.data();
        final trainingLogId =
            (schedule?['trainingLogId'] ?? '').toString().trim();
        if (schedule == null ||
            schedule['trainerId'] != _personalOwnerUid ||
            schedule['workspaceType'] != 'personal' ||
            trainingLogId.isEmpty) {
          debugPrint(
            '[MTF_PERSONAL_LESSON_CANCEL] guard=blocked reason=owner_or_log',
          );
          return false;
        }
        await PersonalTrainingLogRepository.firebase(uid: _personalOwnerUid)
            .cancelFinalize(trainingLogId);
        return true;
      }

      final result = await LessonConfirmCancelService.cancelByScheduleDocId(
        cleanScheduleDocId,
      );

      final upsert = <String, Map<String, dynamic>>{};

      scheduleData.forEach((key, value) {
        if (value is! Map<String, dynamic>) return;

        final docId = (value['docId'] ?? '').toString().trim();
        if (docId != cleanScheduleDocId) return;

        final localData = Map<String, dynamic>.from(value);

        localData
          ..remove('lessonConfirmed')
          ..remove('lessonConfirmedAt')
          ..remove('lessonConfirmStatus')
          ..remove('lessonConfirmLabel')
          ..remove('trainingLogId')
          ..remove('quickTrainingLogId')
          ..remove('lastTrainingLogId')
          ..remove('lastSignedAt')
          ..remove('attendanceOverride')
          ..remove('sessionSnapshotTotal')
          ..remove('sessionSnapshotRemainBefore')
          ..remove('sessionSnapshotRemainAfter')
          ..remove('sessionSnapshotDoneBefore')
          ..remove('sessionSnapshotDoneAfter')
          ..remove('sessionSnapshotLessonNumber')
          ..remove('sessionSnapshotLabel');

        localData['attended'] = false;

        if (result.hasRestoredCountForLocal) {
          if (result.restoredTotalForLocal > 0) {
            localData['totalSessions'] =
                result.restoredTotalForLocal.toString();
          }

          localData['remainingSessions'] =
              result.restoredRemainForLocal.toString();
          localData['remainSessions'] =
              result.restoredRemainForLocal.toString();
        }

        upsert[key] = localData;
      });

      if (upsert.isNotEmpty) {
        _patchScheduleData(
          upsert: upsert,
          syncWidget: false,
        );
      }

      final cancelledMemberId = result.cancelledMemberId?.trim() ?? '';
      if (cancelledMemberId.isNotEmpty) {
        await _refreshMemberNextLesson(cancelledMemberId);
      }

      return true;
    } catch (e) {
      debugPrint('확정취소 실패: $e');
      return false;
    }
  }

  Future<bool> _applyMemberLinkToSchedule({
    required String scheduleDocId,
    required String memberId,
    String? phone,
    Map<String, String> sessionCountFields = const {},
    bool waitForCountsRefresh = true,
  }) async {
    final cleanDocId = scheduleDocId.trim();
    final cleanMemberId = memberId.trim();
    final cleanPhone = _normalizePhone(phone ?? '');

    if (cleanDocId.isEmpty || cleanMemberId.isEmpty) {
      return false;
    }

    final scheduleSnap = await FirebaseFirestore.instance
        .collection('schedules')
        .doc(cleanDocId)
        .get();

    if (!scheduleSnap.exists) {
      if (mounted) {
        _showActionToast(
          context,
          '연결할 레슨일정을 찾지 못했어요.',
          bottomOffset: 110,
        );
      }
      return false;
    }

    final memberSnap = await FirebaseFirestore.instance
        .collection('members')
        .doc(cleanMemberId)
        .get();

    final memberData = memberSnap.data();

    if (memberData == null ||
        memberData['isDeleted'] == true ||
        (memberData['deleteStatus'] ?? '').toString() == 'pending_delete') {
      if (mounted) {
        _showActionToast(
          context,
          '삭제된 회원은 연결할 수 없어요.',
          bottomOffset: 110,
        );
      }
      return false;
    }

    await FirebaseFirestore.instance
        .collection('schedules')
        .doc(cleanDocId)
        .set({
      'memberId': cleanMemberId,
      if (cleanPhone.isNotEmpty) 'phone': cleanPhone,
      if (sessionCountFields['remainingSessions'] != null)
        'remainingSessions': sessionCountFields['remainingSessions'],
      if (sessionCountFields['totalSessions'] != null)
        'totalSessions': sessionCountFields['totalSessions'],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final upsert = <String, Map<String, dynamic>>{};

    scheduleData.forEach((key, value) {
      if (value is! Map<String, dynamic>) return;

      final currentDocId = (value['docId'] ?? '').toString().trim();
      if (currentDocId != cleanDocId) return;

      final next = Map<String, dynamic>.from(value)
        ..['memberId'] = cleanMemberId
        ..remove('linkedMemberDeleted')
        ..remove('memberIsDeleted')
        ..remove('memberDeleteStatus')
        ..remove('deletedMemberId')
        ..remove('deletedMemberName');

      if (cleanPhone.isNotEmpty) {
        next['phone'] = cleanPhone;
      } else {
        next.remove('phone');
      }

      if (sessionCountFields['remainingSessions'] != null) {
        next['remainingSessions'] = sessionCountFields['remainingSessions'];
      }

      if (sessionCountFields['totalSessions'] != null) {
        next['totalSessions'] = sessionCountFields['totalSessions'];
      }

      upsert[key] = next;
    });

    if (upsert.isNotEmpty) {
      _patchScheduleData(
        upsert: upsert,
        syncWidget: true,
      );
    }

    await _refreshMemberNextLesson(cleanMemberId);

    if (waitForCountsRefresh) {
      await _refreshScheduleCountsFromMembers();
    } else {
      unawaited(_refreshScheduleCountsFromMembers());
    }

    return true;
  }

  Future<void> _linkManualScheduleToExistingMember({
    required String memberName,
    required String scheduleDocId,
  }) async {
    final cleanName = memberName.trim();
    final cleanDocId = scheduleDocId.trim();

    if (cleanName.isEmpty) {
      _showActionToast(context, '회원 이름을 먼저 입력해주세요.', bottomOffset: 110);
      return;
    }

    if (cleanDocId.isEmpty) {
      _showActionToast(context, '연결할 레슨일정을 찾지 못했어요.', bottomOffset: 110);
      return;
    }

    final candidates = await _findExactMemberCandidates(cleanName);

    if (!mounted) return;

    if (candidates.isEmpty) {
      _showActionToast(context, '같은 이름의 기존 회원을 찾지 못했어요.', bottomOffset: 110);
      return;
    }

    final picked = await _openMemberMatchPickerSheet(
      typedName: cleanName,
      lessonLabel: '이 레슨',
      candidates: candidates,
    );

    if (!mounted || picked == null || picked['manual'] == true) return;

    final memberId = picked['id']?.toString() ?? '';
    final phone = picked['phone']?.toString() ?? '';

    final remain = picked['remainingSessions'];
    final total = picked['totalSessions'];

    final remainValue = remain is num
        ? remain.toInt()
        : int.tryParse((remain ?? '').toString()) ?? 0;

    final totalValue = total is num
        ? total.toInt()
        : int.tryParse((total ?? '').toString()) ?? 0;

    final countFields = <String, String>{};
    if (totalValue > 0 || remainValue > 0) {
      countFields['remainingSessions'] = remainValue.toString();
      countFields['totalSessions'] = totalValue.toString();
    }

    await _applyMemberLinkToSchedule(
      scheduleDocId: cleanDocId,
      memberId: memberId,
      phone: phone,
      sessionCountFields: countFields,
      waitForCountsRefresh: false,
    );

    if (!mounted) return;
    _showActionToast(context, '기존 회원과 레슨일정을 연결했어요.', bottomOffset: 110);
  }

  Future<void> _unlinkScheduleMemberLinkByMemberId(String memberId) async {
    final cleanMemberId = memberId.trim();
    if (cleanMemberId.isEmpty) return;

    try {
      await HomeDeletedMemberScheduleService.unlinkSchedulesByMemberId(
        cleanMemberId,
      );

      final upsert = <String, Map<String, dynamic>>{};

      scheduleData.forEach((key, value) {
        if (value is! Map<String, dynamic>) return;

        final localMemberId = (value['memberId'] ?? '').toString().trim();
        if (localMemberId != cleanMemberId) return;

        final next = Map<String, dynamic>.from(value)
          ..remove('memberId')
          ..remove('phone')
          ..remove('totalSessions')
          ..remove('remainingSessions')
          ..remove('remainSessions')
          ..['linkedMemberDeleted'] = true
          ..['deletedMemberId'] = cleanMemberId;

        upsert[key] = next;
      });

      if (upsert.isNotEmpty) {
        _patchScheduleData(
          upsert: upsert,
          syncWidget: true,
        );
      }
    } catch (e) {
      debugPrint('삭제 회원 스케줄 연결 해제 실패: $e');
    }
  }

  Future<void> _openLessonContractRegistrationFromHomeLesson({
    required String memberName,
    String? phone,
    String? scheduleDocId,
  }) async {
    final cleanName = memberName.trim();
    final cleanPhone = _normalizePhone(phone ?? '');
    final cleanScheduleDocId = (scheduleDocId ?? '').trim();

    if (cleanName.isEmpty) {
      _showActionToast(
        context,
        '회원 이름을 먼저 입력해주세요.',
        bottomOffset: 110,
      );
      return;
    }

    final canUse = await AifcTierFeatureGateSheet.guard(
      context: context,
      access: null,
      feature: AppTierFeatureKey.contract,
      loadAccess: _loadCurrentTierAccess,
      entryPoint: 'lesson_editor_new_contract',
    );
    if (!mounted || !canUse) return;

    final newMemberId =
        FirebaseFirestore.instance.collection('members').doc().id;

    String trainerName =
        _bannerTrainerName.trim().isEmpty ? '강사님' : _bannerTrainerName.trim();

    try {
      final snap = await _trainerProfileRef.get();

      final data = snap.data();

      final contractTrainerName =
          (data?['contractTrainerName'] ?? '').toString().trim();
      final displayName = (data?['displayName'] ?? '').toString().trim();
      final name = (data?['name'] ?? '').toString().trim();

      if (contractTrainerName.isNotEmpty) {
        trainerName = contractTrainerName;
      } else if (displayName.isNotEmpty) {
        trainerName = displayName;
      } else if (name.isNotEmpty) {
        trainerName = name;
      }
    } catch (_) {}

    if (!mounted) return;

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ContractPage(
          memberId: newMemberId,
          memberName: cleanName,
          trainerName: trainerName,
          initialStage: ContractStage.requiredInfo,
        ),
      ),
    );

    if (!mounted) return;

    final memberSnap = await FirebaseFirestore.instance
        .collection('members')
        .doc(newMemberId)
        .get();

    if (saved != true && !memberSnap.exists) {
      _showActionToast(
        context,
        '레슨계약서 작성이 완료되지 않아 미등록 상태로 유지했어요.',
        bottomOffset: 110,
      );
      return;
    }

    final ensuredMemberData = await _ensureHomeContractCreatedMember(
      memberId: newMemberId,
      memberName: cleanName,
      phone: cleanPhone,
      lessonType: 'PT',
      source: 'lesson_contract_home_registration',
    );

    if (ensuredMemberData == null) {
      _showActionToast(
        context,
        '레슨계약서 저장은 확인했지만 회원카드 연결 정보를 만들지 못했어요.',
        bottomOffset: 110,
      );
      return;
    }

    final countFields = _memberSessionCountFieldsFromData(ensuredMemberData);

    if (cleanScheduleDocId.isNotEmpty) {
      await _applyMemberLinkToSchedule(
        scheduleDocId: cleanScheduleDocId,
        memberId: newMemberId,
        phone: cleanPhone,
        sessionCountFields: countFields,
      );
    }

    if (!mounted) return;

    _showActionToast(
      context,
      '레슨계약서 기준으로 회원을 등록하고 레슨일정에 연결했어요.',
      bottomOffset: 110,
    );
  }

  Future<void> _openMembershipContractRegistrationFromHomeLesson({
    required String memberName,
    String? phone,
    String? scheduleDocId,
    String lessonType = 'PT',
    String sessionCountText = '',
  }) async {
    final cleanName = memberName.trim();
    final cleanPhone = _normalizePhone(phone ?? '');
    final cleanScheduleDocId = (scheduleDocId ?? '').trim();

    if (cleanName.isEmpty) {
      _showActionToast(
        context,
        '회원 이름을 먼저 입력해주세요.',
        bottomOffset: 110,
      );
      return;
    }

    final access = await _loadCurrentTierAccess();

    if (!mounted) return;

    final canUse = await AifcTierFeatureGateSheet.guard(
      context: context,
      access: access,
      feature: AppTierFeatureKey.membershipContract,
      loadAccess: _loadCurrentTierAccess,
      onShowTierGuide: (info) async {
        _showActionToast(
          context,
          '${info.requiredTierLabel}부터 회원권계약서를 사용할 수 있어요.',
          bottomOffset: 110,
        );
      },
    );

    if (!canUse || !mounted) return;

    final newMemberId =
        FirebaseFirestore.instance.collection('members').doc().id;

    final countMap = _parseSessionCount(sessionCountText);

    final totalSessions = _toNullableInt(countMap['totalSessions']) ?? 0;
    final remainingSessions =
        _toNullableInt(countMap['remainingSessions']) ?? 0;

    String trainerName =
        _bannerTrainerName.trim().isEmpty ? '강사님' : _bannerTrainerName.trim();

    try {
      final snap = await _trainerProfileRef.get();

      final data = snap.data();

      final contractTrainerName =
          (data?['contractTrainerName'] ?? '').toString().trim();
      final displayName = (data?['displayName'] ?? '').toString().trim();
      final name = (data?['name'] ?? '').toString().trim();

      if (contractTrainerName.isNotEmpty) {
        trainerName = contractTrainerName;
      } else if (displayName.isNotEmpty) {
        trainerName = displayName;
      } else if (name.isNotEmpty) {
        trainerName = name;
      }
    } catch (_) {}

    if (!mounted) return;

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MembershipContractPage(
          memberId: newMemberId,
          memberName: cleanName,
          trainerName: trainerName,
          lessonType: lessonType.trim().isEmpty ? 'PT' : lessonType.trim(),
          totalSessions: totalSessions,
          remainingSessions: remainingSessions,
          membershipStartAt: null,
          membershipEndAt: null,
          membershipPaused: false,
        ),
      ),
    );

    if (!mounted) return;

    final memberSnap = await FirebaseFirestore.instance
        .collection('members')
        .doc(newMemberId)
        .get();

    if (ok != true && !memberSnap.exists) {
      _showActionToast(
        context,
        '회원권계약서 작성이 완료되지 않아 미등록 상태로 유지했어요.',
        bottomOffset: 110,
      );
      return;
    }

    final ensuredMemberData = await _ensureHomeContractCreatedMember(
      memberId: newMemberId,
      memberName: cleanName,
      phone: cleanPhone,
      lessonType: lessonType,
      totalSessions: totalSessions,
      remainingSessions: remainingSessions,
      source: 'membership_contract_home_registration',
    );

    if (ensuredMemberData == null) {
      _showActionToast(
        context,
        '회원권계약서 저장은 확인했지만 회원카드 연결 정보를 만들지 못했어요.',
        bottomOffset: 110,
      );
      return;
    }

    final countFields = _memberSessionCountFieldsFromData(ensuredMemberData);

    if (cleanScheduleDocId.isNotEmpty) {
      await _applyMemberLinkToSchedule(
        scheduleDocId: cleanScheduleDocId,
        memberId: newMemberId,
        phone: cleanPhone,
        sessionCountFields: countFields,
      );
    }

    if (!mounted) return;

    _showActionToast(
      context,
      '회원권계약서 기준으로 회원을 등록하고 레슨일정에 연결했어요.',
      bottomOffset: 110,
    );
  }

  Future<void> _openClientCardFromSchedule({
    String? memberId,
    required String memberName,
    String? phone,
  }) async {
    final resolvedMemberId = await _resolveLinkedMemberId(
      memberId: memberId,
      memberName: memberName,
      phone: phone,
    );

    if (!mounted) return;

    if (resolvedMemberId == null || resolvedMemberId.isEmpty) {
      _showActionToast(
        context,
        '회원카드가 연결되지 않은 레슨이에요.',
        bottomOffset: 110,
      );
      return;
    }

    final deleted = await _isDeletedMemberId(resolvedMemberId);

    if (deleted) {
      await _unlinkScheduleMemberLinkByMemberId(resolvedMemberId);

      if (!mounted) return;

      _showActionToast(
        context,
        '회원카드에 연결되지 않은 레슨으로 변경했어요.',
        bottomOffset: 110,
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientCardPage(
          memberId: resolvedMemberId,
          personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
        ),
      ),
    );

    if (!mounted) return;
    await _refreshScheduleCountsFromMembers();
  }

  bool _homeSessionHasLessonContract(Map<String, dynamic>? session) {
    if (session == null) return false;

    final contractId = (session['contractId'] ?? '').toString().trim();
    final contractNo = (session['contractNo'] ?? '').toString().trim();
    final basis = (session['basis'] ?? '').toString().trim();

    return session['contractSigned'] == true ||
        session['isContractSigned'] == true ||
        session['contractLinked'] == true ||
        basis == 'contract' ||
        contractId.isNotEmpty ||
        contractNo.isNotEmpty;
  }

  bool _homeSessionIsLowRemaining(Map<String, dynamic>? session) {
    if (session == null) return false;

    final remain = _toNullableInt(
      session['remainingSessions'] ??
          session['remainSessions'] ??
          session['sessionSnapshotRemainAfter'],
    );

    final total = _toNullableInt(
      session['totalSessions'] ?? session['sessionSnapshotTotal'],
    );

    if (remain == null) return false;
    if (total != null && total <= 0) return false;

    return remain >= 0 && remain <= 3;
  }

  bool _homeSessionLooksFirstContractTiming(Map<String, dynamic>? session) {
    if (session == null) return false;

    final remain = _toNullableInt(
      session['remainingSessions'] ?? session['remainSessions'],
    );

    final total = _toNullableInt(session['totalSessions']);

    if (remain == null || total == null) return false;
    if (total <= 0) return false;

    // 신규 등록 직후 첫 레슨 전후에는 레슨계약서 작성 추천 가능
    return remain == total;
  }

  bool _shouldRecommendHomeLessonContractAction({
    required Map<String, dynamic>? session,
    required bool hasLinkedMember,
    required bool linkedMemberDeleted,
  }) {
    if (!hasLinkedMember) return false;
    if (linkedMemberDeleted) return false;
    if (_homeSessionHasLessonContract(session)) return false;

    final bool lowRemaining = _homeSessionIsLowRemaining(session);

    final remain = _toNullableInt(
      session?['remainingSessions'] ?? session?['remainSessions'],
    );

    final total = _toNullableInt(session?['totalSessions']);

    final bool firstContractTiming =
        remain != null && total != null && total > 0 && remain == total;

    // 레슨계약서는 매번 뜨면 피로도가 높으므로,
    // 첫 등록 타이밍 또는 재등록/만료 임박 타이밍에만 추천합니다.
    return lowRemaining || firstContractTiming;
  }

  bool _shouldRecommendHomeMembershipManageAction({
    required Map<String, dynamic>? session,
    required bool hasLinkedMember,
    required bool linkedMemberDeleted,
  }) {
    if (!hasLinkedMember) return false;
    if (linkedMemberDeleted) return false;

    final membershipStatus =
        (session?['membershipStatus'] ?? '').toString().trim();

    final membershipContractStatus =
        (session?['membershipContractStatus'] ?? '').toString().trim();

    final membershipDaysLeft = _toNullableInt(
      session?['membershipDaysLeft'] ??
          session?['membershipDDay'] ??
          session?['membershipDday'],
    );

    final membershipResumeDaysLeft = _toNullableInt(
      session?['membershipResumeDaysLeft'],
    );

    final bool paused = membershipStatus == 'paused';

    final bool membershipSoon =
        membershipDaysLeft != null && membershipDaysLeft <= 30;

    final bool resumeSoon = membershipResumeDaysLeft != null &&
        membershipResumeDaysLeft >= 0 &&
        membershipResumeDaysLeft <= 7;

    final bool contractNeedsSignature =
        session?['membershipContractNeedsSignature'] == true ||
            session?['membershipContractDraftExists'] == true ||
            membershipContractStatus == 'draft' ||
            membershipContractStatus == 'unsigned';

    return _homeSessionIsLowRemaining(session) ||
        paused ||
        resumeSoon ||
        membershipSoon ||
        contractNeedsSignature;
  }

  Future<void> _openWorkoutLogFromSchedule({
    String? memberId,
    required String memberName,
    String? phone,
  }) async {
    if (_isPersonalWorkspace) {
      final allowed = await AifcTierFeatureGateSheet.guard(
        context: context,
        access: null,
        feature: AppTierFeatureKey.trainingLog,
        loadAccess: _loadCurrentTierAccess,
        entryPoint: 'home_schedule_training_log',
      );
      if (!allowed || !mounted) return;
    }

    final resolvedMemberId = await _resolveLinkedMemberId(
      memberId: memberId,
      memberName: memberName,
      phone: phone,
    );

    if (!mounted) return;

    if (resolvedMemberId == null || resolvedMemberId.isEmpty) {
      _showActionToast(
        context,
        '회원카드가 연결되지 않은 레슨이에요.',
        bottomOffset: 110,
      );
      return;
    }

    final deleted = await _isDeletedMemberId(resolvedMemberId);

    if (deleted) {
      await _unlinkScheduleMemberLinkByMemberId(resolvedMemberId);

      if (!mounted) return;

      _showActionToast(
        context,
        '회원카드 연결이 없는 레슨으로 변경했어요.',
        bottomOffset: 110,
      );
      return;
    }

    if (_isPersonalWorkspace) {
      final consentAllowed = await PersonalTrainingLogEntryGuard.guard(
        context: context,
        ownerUid: _personalOwnerUid,
        memberId: resolvedMemberId,
        loadAccess: _loadCurrentTierAccess,
        entryPoint: 'home_schedule_training_log_consent',
        checkTier: false,
      );
      if (!consentAllowed || !mounted) return;
    }

    final logPageArgs = await _loadMemberLogPageArgs(
      memberId: resolvedMemberId,
      fallbackName: memberName,
      fallbackPhone: phone,
    );

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonalTrainingLogPage(
          memberId: resolvedMemberId,
          memberName: (logPageArgs['memberName'] ?? memberName).toString(),
          memberPhone: (logPageArgs['memberPhone'] ?? phone ?? '').toString(),
          totalSessions: logPageArgs['totalSessions'] as int? ?? 0,
          remainingSessions: logPageArgs['remainingSessions'] as int? ?? 0,
          lastLogAt: logPageArgs['lastLogAt'] as DateTime?,
          personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
        ),
      ),
    );

    if (!mounted) return;
    await _refreshScheduleCountsFromMembers();
  }

  Future<Map<String, dynamic>?> _ensureHomeContractCreatedMember({
    required String memberId,
    required String memberName,
    String? phone,
    String lessonType = 'PT',
    int totalSessions = 0,
    int remainingSessions = 0,
    required String source,
  }) async {
    final cleanMemberId = memberId.trim();
    final cleanName = memberName.trim();
    final cleanPhone = _normalizePhone(phone ?? '');
    final cleanLessonType =
        lessonType.trim().isEmpty ? 'PT' : lessonType.trim();

    if (cleanMemberId.isEmpty || cleanName.isEmpty) {
      return null;
    }

    final memberRef =
        FirebaseFirestore.instance.collection('members').doc(cleanMemberId);

    final beforeSnap = await memberRef.get();
    final beforeData = beforeSnap.data();

    if (beforeData != null) {
      if (beforeData['isDeleted'] == true ||
          (beforeData['deleteStatus'] ?? '').toString() == 'pending_delete') {
        return null;
      }

      return beforeData;
    }

    final hasSessionCount = totalSessions > 0 || remainingSessions > 0;

    await memberRef.set({
      'name': cleanName,
      if (cleanPhone.isNotEmpty) 'phone': cleanPhone,
      'memberStatus': '활성',
      'membershipGrade': 'BRONZE',
      if (cleanLessonType.isNotEmpty) 'lessonType': cleanLessonType,
      if (hasSessionCount) 'totalSessions': totalSessions,
      if (hasSessionCount) 'remainingSessions': remainingSessions,
      if (hasSessionCount) 'remainSessions': remainingSessions,
      if (hasSessionCount)
        'sessions': {
          'total': totalSessions,
          'remain': remainingSessions,
          'done': totalSessions > 0
              ? (totalSessions - remainingSessions).clamp(0, totalSessions)
              : 0,
          'notRegistered': false,
        },
      'createdFrom': source,
      'createdByHomeContractFlow': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    final afterSnap = await memberRef.get();
    return afterSnap.data();
  }

  Future<void> _openMembershipManageFromHomeLesson({
    required String? memberId,
    required String memberName,
  }) async {
    final cleanMemberId = (memberId ?? '').trim();
    final cleanMemberName = memberName.trim();

    if (cleanMemberId.isEmpty) {
      _showActionToast(
        context,
        '기존 회원 연결 후 사용할 수 있어요.',
        bottomOffset: 110,
      );
      return;
    }

    final access = await _loadCurrentTierAccess();

    if (!mounted) return;

    final allowed = await AifcTierFeatureGateSheet.guard(
      context: context,
      access: access,
      feature: AppTierFeatureKey.membershipContract,
      loadAccess: _loadCurrentTierAccess,
      onShowTierGuide: (info) async {
        _showActionToast(
          context,
          '${info.requiredTierLabel}부터 회원권 관리 기능을 사용할 수 있어요.',
          bottomOffset: 110,
        );
      },
    );

    if (!allowed || !mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientCardPage.edit(
          memberId: cleanMemberId,
          initialName: cleanMemberName.isEmpty ? null : cleanMemberName,
          openMembershipManageOnStart: true,
        ),
      ),
    );

    if (!mounted) return;

    await _refreshScheduleCountsFromMembers();
  }

  Future<void> _openLessonContractFromHomeLesson({
    required String? memberId,
    required String memberName,
  }) async {
    final cleanMemberId = (memberId ?? '').trim();
    final cleanMemberName = memberName.trim();

    if (cleanMemberId.isEmpty) {
      _showActionToast(
        context,
        '기존 회원 연결 후 레슨계약서를 작성할 수 있어요.',
        bottomOffset: 110,
      );
      return;
    }

    final canUse = await AifcTierFeatureGateSheet.guard(
      context: context,
      access: null,
      feature: AppTierFeatureKey.contract,
      loadAccess: _loadCurrentTierAccess,
      entryPoint: 'linked_member_lesson_contract',
    );
    if (!mounted || !canUse) return;

    String trainerName =
        _bannerTrainerName.trim().isEmpty ? '강사님' : _bannerTrainerName.trim();

    try {
      final snap = await _trainerProfileRef.get();

      final data = snap.data();

      final contractTrainerName =
          (data?['contractTrainerName'] ?? '').toString().trim();
      final displayName = (data?['displayName'] ?? '').toString().trim();
      final name = (data?['name'] ?? '').toString().trim();

      if (contractTrainerName.isNotEmpty) {
        trainerName = contractTrainerName;
      } else if (displayName.isNotEmpty) {
        trainerName = displayName;
      } else if (name.isNotEmpty) {
        trainerName = name;
      }
    } catch (_) {}

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContractPage(
          memberId: cleanMemberId,
          memberName: cleanMemberName,
          trainerName: trainerName,
          initialStage: ContractStage.requiredInfo,
        ),
      ),
    );

    if (!mounted) return;

    await _refreshScheduleCountsFromMembers();
  }

  Future<void> _openQuickSignFromSchedule({
    String? memberId,
    required String memberName,
    String? phone,
    String? scheduleDocId,
    String lessonType = 'PT',
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    if (_isPersonalWorkspace) {
      final allowed = await AifcTierFeatureGateSheet.guard(
        context: context,
        access: null,
        feature: AppTierFeatureKey.trainingLog,
        loadAccess: _loadCurrentTierAccess,
        entryPoint: 'home_schedule_quick_sign',
      );
      if (!allowed || !mounted) return;
    }

    final cleanMemberId = memberId?.trim() ?? '';

    if (cleanMemberId.isEmpty) {
      _showActionToast(
        context,
        '기존 회원 연결 후 빠른 서명을 사용할 수 있어요.',
        bottomOffset: 110,
      );
      return;
    }

    if (await _isDeletedMemberId(cleanMemberId)) {
      if (!mounted) return;
      _showActionToast(
        context,
        '삭제된 회원은 빠른서명을 사용할 수 없어요.',
        bottomOffset: 110,
      );
      return;
    }

    if (_isPersonalWorkspace) {
      final consentAllowed = await PersonalTrainingLogEntryGuard.guard(
        context: context,
        ownerUid: _personalOwnerUid,
        memberId: cleanMemberId,
        loadAccess: _loadCurrentTierAccess,
        entryPoint: 'home_schedule_quick_sign_consent',
        checkTier: false,
      );
      if (!consentAllowed || !mounted) return;
    }

    final memberSnap = await FirebaseFirestore.instance
        .collection('members')
        .doc(cleanMemberId)
        .get();

    final memberData = memberSnap.data() ?? <String, dynamic>{};

    final sessions = memberData['sessions'] is Map
        ? Map<String, dynamic>.from(memberData['sessions'] as Map)
        : <String, dynamic>{};

    final lessonSync = memberData['lessonSync'] is Map
        ? Map<String, dynamic>.from(memberData['lessonSync'] as Map)
        : <String, dynamic>{};

    final contractId = (lessonSync['contractId'] ?? '').toString().trim();

    final hasSignedContract =
        memberData['contractSigned'] == true || contractId.isNotEmpty;

    // ✅ 레슨계약서가 있으면 기존 빠른서명 페이지로 이동
    if (hasSignedContract) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => PersonalTrainingQuickLogSignPage(
            memberId: cleanMemberId,
            memberName: memberName,
            memberPhone: phone,
            scheduleDocId: scheduleDocId,
            lessonType: lessonType,
            startAt: startAt,
            endAt: endAt,
            personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
          ),
        ),
      );

      if (!mounted) return;

      if (result == true) {
        await _refreshScheduleCountsFromMembers();
      }

      return;
    }

    // ✅ 레슨계약서가 없으면 고객카드 레슨 정보를 기준으로 바로 확정 팝업
    final memberLessonType =
        (memberData['lessonType'] ?? lessonType).toString().trim();

    final lessonNotRegistered = sessions['notRegistered'] == true ||
        memberLessonType.isEmpty ||
        memberLessonType == '미입력';

    final totalSessions = _intFromAny(
      sessions['total'] ??
          memberData['totalSessions'] ??
          memberData['sessionTotal'],
    );

    final remainSessions = _intFromAny(
      sessions['remain'] ??
          memberData['remainSessions'] ??
          memberData['remainingSessions'] ??
          memberData['remainingPt'] ??
          memberData['ptRemaining'],
    );

    if (lessonNotRegistered || totalSessions <= 0) {
      _showActionToast(
        context,
        '고객카드에 레슨 정보를 먼저 등록하면 빠른서명을 사용할 수 있어요.',
        bottomOffset: 110,
      );
      return;
    }

    if (remainSessions <= 0) {
      _showActionToast(
        context,
        '잔여 횟수가 0회라 소진할 수 없어요. 고객카드를 확인해주세요.',
        bottomOffset: 110,
      );
      return;
    }

    await AifcLessonConfirmChatSheet.show(
      context: context,
      memberName: memberName,
      lessonType: memberLessonType,
      totalSessions: totalSessions,
      remainBefore: remainSessions,
      contractSigned: false,
      onConfirm: (status) async {
        await _confirmScheduleLessonFromHome(
          session: {
            'memberId': cleanMemberId,
            'name': memberName,
            if ((phone ?? '').trim().isNotEmpty) 'phone': phone,
            if ((scheduleDocId ?? '').trim().isNotEmpty) 'docId': scheduleDocId,
            'type': memberLessonType,
            if (startAt != null) 'startAt': startAt,
            if (endAt != null) 'endAt': endAt,
          },
          toastContext: context,
          confirmStatus: status.firestoreValue,
        );
      },
    );

    if (!mounted) return;
  }

  String _confirmStatusFromScheduleSession(Map<String, dynamic> session) {
    final override = (session['attendanceOverride'] ?? '').toString();

    switch (override) {
      case 'no_show_deducted':
        return 'no_show_deducted';
      case 'no_show_not_deducted':
        return 'no_show_not_deducted';
      case 'attendance_cancelled':
        return 'cancelled';
      default:
        return 'completed';
    }
  }

  String _confirmStatusLabel(String status) {
    switch (status) {
      case 'no_show_deducted':
        return '노쇼 차감';
      case 'no_show_not_deducted':
        return '노쇼 미차감';
      case 'service':
        return '서비스';
      case 'cancelled':
        return '출석 취소';
      case 'completed':
      default:
        return '소진';
    }
  }

  DateTime _dateFromScheduleStart(Map<String, dynamic> session) {
    final raw = session['startAt'];

    if (raw is DateTime) return raw;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }

    return DateTime.now();
  }

  DateTime _dateFromScheduleEnd(Map<String, dynamic> session) {
    final raw = session['endAt'];

    if (raw is DateTime) return raw;
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed;
    }

    return _dateFromScheduleStart(session).add(
      Duration(minutes: _preferredLessonDurationMinutes),
    );
  }

  bool _isScheduleLessonConfirmed(Map<String, dynamic> session) {
    final confirmStatus =
        (session['lessonConfirmStatus'] ?? '').toString().trim();
    final trainingLogId = (session['trainingLogId'] ?? '').toString().trim();

    return session['lessonConfirmed'] == true ||
        session['lessonConfirmedAt'] != null ||
        confirmStatus.isNotEmpty ||
        trainingLogId.isNotEmpty;
  }

  bool _hasSignatureMap(dynamic value) {
    if (value is! Map) return false;

    final map = Map<String, dynamic>.from(value as Map);

    final rawValue = (map['value'] ?? '').toString().trim();
    final rawType = (map['type'] ?? '').toString().trim();
    final signedAt = map['signedAt'];

    return rawValue.isNotEmpty || rawType.isNotEmpty || signedAt != null;
  }

  bool _isCustomerSignedConfirmedSchedule(Map<String, dynamic>? session) {
    if (session == null) return false;

    if (!_isScheduleLessonConfirmed(session)) return false;

    final memberSignature = session['memberSignature'];
    final customerSignature = session['customerSignature'];

    return session['memberSigned'] == true ||
        session['customerSigned'] == true ||
        session['memberSignedAt'] != null ||
        session['customerSignedAt'] != null ||
        _hasSignatureMap(memberSignature) ||
        _hasSignatureMap(customerSignature);
  }

  bool _isContractLinkedConfirmedSchedule(Map<String, dynamic>? session) {
    if (session == null) return false;
    if (!_isScheduleLessonConfirmed(session)) return false;

    final basis = (session['basis'] ?? '').toString().trim();
    final contractId = (session['contractId'] ?? '').toString().trim();
    final reason =
        (session['cancelLockContractReason'] ?? '').toString().trim();

    return session['contractLinked'] == true ||
        session['cancelLockedByContract'] == true ||
        basis == 'contract' ||
        contractId.isNotEmpty ||
        reason == 'contract_linked_lesson_confirm';
  }

  int _intFromAny(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  HomeQuickSignMemberState _resolveQuickSignMemberState(
    Map<String, dynamic> memberData,
  ) {
    final sessions = memberData['sessions'] is Map
        ? Map<String, dynamic>.from(memberData['sessions'] as Map)
        : <String, dynamic>{};

    final lessonSync = memberData['lessonSync'] is Map
        ? Map<String, dynamic>.from(memberData['lessonSync'] as Map)
        : <String, dynamic>{};

    final source = (lessonSync['source'] ?? memberData['lessonSource'] ?? '')
        .toString()
        .trim();

    final contractId = (lessonSync['contractId'] ?? '').toString().trim();

    final hasContract = source == 'contract' ||
        memberData['contractSigned'] == true ||
        contractId.isNotEmpty;

    final lessonType = (memberData['lessonType'] ?? '미입력').toString().trim();

    final totalSessions = _intFromAny(
      sessions['total'] ??
          memberData['totalSessions'] ??
          memberData['sessionTotal'],
    );

    final remainSessions = _intFromAny(
      sessions['remain'] ??
          memberData['remainSessions'] ??
          memberData['remainingSessions'] ??
          memberData['remainingPt'] ??
          memberData['ptRemaining'],
    );

    final notRegistered = sessions['notRegistered'] == true ||
        memberData['lessonsNotRegistered'] == true ||
        lessonType.isEmpty ||
        lessonType == '미입력' ||
        totalSessions <= 0;

    final lessonRegistered = !notRegistered;

    final basis = hasContract
        ? 'contract'
        : lessonRegistered
            ? 'manual'
            : 'none';

    return HomeQuickSignMemberState(
      hasContract: hasContract,
      lessonRegistered: lessonRegistered,
      lessonType: lessonType == '미입력' ? '레슨' : lessonType,
      totalSessions: totalSessions,
      remainSessions: remainSessions,
      basis: basis,
      contractId: contractId.isEmpty ? null : contractId,
    );
  }

  Future<bool> _isActiveMemberDoc(String memberId) {
    return HomeMemberLookupService.isActiveMemberDoc(
      memberId,
      ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
    );
  }

  Future<bool> _isScheduleDocConfirmed(String docId) async {
    return HomeScheduleFirestoreService.isScheduleConfirmed(
      docId,
      ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
    );
  }

  Future<bool> _showAifcConfirm({
    required String title,
    required String message,
    String cancelText = '취소',
    String confirmText = '확인',
    String? userCancelText,
    String? userConfirmText,
    String cancelReplyText = '좋아요. 진행하지 않을게요.',
    String confirmReplyText = '확인했어요. 이어서 진행할게요.',
    bool danger = false,
  }) {
    return AifcConfirmChatSheet.show(
      context: context,
      nickname: normalizeAifcNickname(_bannerTrainerName),
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

  Future<bool> _askConfirmCancelPin() async {
    String nickname = '강사';

    try {
      final snap = await _trainerProfileRef.get();

      final data = snap.data();
      nickname = normalizeAifcNickname(_trainerHeaderNameFromData(data));
    } catch (_) {
      nickname = '강사';
    }

    final nicknameLabel = aifcNicknameLabel(nickname);

    final result = await AifcPinConfirmChatSheet.show(
      context: context,
      nickname: nickname,
      title: '일반 확정을 취소할까요?',
      question: '회원 서명이나 계약서 기준으로 확정된 레슨은 취소할 수 없어요.\n'
          '일반 확정만 PIN 확인 후 취소할 수 있고,\n'
          '차감된 회차가 있다면 회원카드에 되돌립니다.',
      pinGuide: '진행하려면 $nicknameLabel PIN 번호를 입력해주세요.',
      inputLabel: '$nicknameLabel PIN',
      successText: '확인됐어요.\n확정취소를 진행할게요.',
      wrongText: 'PIN 번호가 맞지 않아요.\n다시 입력해주세요.',
      errorText: 'PIN 확인 중 오류가 발생했어요.\n잠시 후 다시 시도해주세요.',
      minLength: 4,
      maxLength: 4,
      onVerify: (pin) async {
        return pin == '0000';
      },
    );

    if (!mounted) return false;

    return result == true;
  }

  Future<void> _confirmScheduleLessonFromHome({
    required Map<String, dynamic> session,
    required BuildContext toastContext,
    String? confirmStatus,
  }) async {
    if (_isPersonalWorkspace) {
      final allowed = await AifcTierFeatureGateSheet.guard(
        context: context,
        access: null,
        feature: AppTierFeatureKey.trainingLog,
        loadAccess: _loadCurrentTierAccess,
        entryPoint: 'home_schedule_lesson_finalize',
      );
      if (!allowed || !mounted) return;
    }

    final memberId = (session['memberId'] ?? '').toString().trim();
    final memberName = (session['name'] ?? '회원').toString().trim();
    final memberPhone = (session['phone'] ?? '').toString().trim();
    final scheduleDocId = (session['docId'] ?? '').toString().trim();

    if (memberId.isEmpty) {
      _showActionToast(
        toastContext,
        '기존 회원 연결 후 확정할 수 있어요.',
        bottomOffset: 110,
      );
      return;
    }

    if (scheduleDocId.isEmpty) {
      _showActionToast(
        toastContext,
        '연결된 일정 문서를 찾지 못했어요.',
        bottomOffset: 110,
      );
      return;
    }

    if (_isPersonalWorkspace) {
      final consentAllowed = await PersonalTrainingLogEntryGuard.guard(
        context: context,
        ownerUid: _personalOwnerUid,
        memberId: memberId,
        loadAccess: _loadCurrentTierAccess,
        entryPoint: 'home_schedule_lesson_finalize_consent',
        checkTier: false,
      );
      if (!consentAllowed || !mounted) return;
    }

    final status = confirmStatus ?? _confirmStatusFromScheduleSession(session);

    if (status == 'cancelled') {
      _showActionToast(
        toastContext,
        '출석 취소 상태는 확정할 수 없어요.',
        bottomOffset: 110,
      );
      return;
    }

    final startAt = _dateFromScheduleStart(session);
    final endAt = _dateFromScheduleEnd(session);
    final lessonType = (session['type'] ?? 'PT').toString();

    final trainingLogId = _quickSignLogIdFromSchedule(
      memberId: memberId,
      scheduleDocId: scheduleDocId,
      startAt: startAt,
    );

    if (_isPersonalWorkspace) {
      try {
        final repository =
            PersonalTrainingLogRepository.firebase(uid: _personalOwnerUid);
        final personalLogId = await repository.createDraft(
          PersonalTrainingLogDraft(
            memberId: memberId,
            scheduleDocId: scheduleDocId,
            lessonDate: DateTime(startAt.year, startAt.month, startAt.day),
            startAt: startAt,
            endAt: endAt,
            lessonType: lessonType,
            source: 'home_quick_sign',
          ),
        );
        final result = await repository.finalize(personalLogId, status);

        await _cancelPendingSignRequestsForTrainingLog(personalLogId);
        await _refreshScheduleCountsFromMembers();
        if (!mounted) return;
        _queueHomeWidgetSync();

        final remainingAfter = result['remainingAfter'];
        final message = switch (status) {
          'no_show_deducted' => '노쇼 차감으로 확정했어요.',
          'no_show_not_deducted' => '노쇼 미차감으로 확정했어요.',
          'service' => '서비스 레슨으로 확정했어요.',
          _ => remainingAfter is num && remainingAfter <= 0
              ? '제가 고객카드 기준으로 확인했어요. 잔여 횟수는 0회입니다.'
              : '제가 고객카드 기준으로 확인했어요. 잔여 횟수를 소진하고, 담당자 확인 기록으로 남겨둘게요.',
        };
        if (!toastContext.mounted) return;
        _showActionToast(toastContext, message, bottomOffset: 110);
      } catch (error) {
        debugPrint('[MTF_PERSONAL_LESSON_CONFIRM] failed=$error');
        if (!mounted || !toastContext.mounted) return;
        _showActionToast(
          toastContext,
          personalTrainingLogErrorMessage(error),
          bottomOffset: 110,
        );
      }
      return;
    }

    try {
      final result = await LessonConfirmationService.confirmFromHome(
        LessonConfirmationRequest(
          memberId: memberId,
          memberName: memberName,
          memberPhone: memberPhone,
          scheduleDocId: scheduleDocId,
          lessonType: lessonType,
          status: status,
          startAt: startAt,
          endAt: endAt,
          trainingLogId: trainingLogId,
        ),
      );

      if (!mounted) return;

      if (result.status == LessonConfirmationResultStatus.alreadyConfirmed) {
        _showActionToast(
          toastContext,
          '이미 확정했습니다',
          bottomOffset: 110,
        );
        return;
      }

      if (result.status == LessonConfirmationResultStatus.lessonNotRegistered) {
        _showActionToast(
          toastContext,
          '고객카드에 레슨 정보가 없어 소진 할 수 없었어요.',
          bottomOffset: 110,
        );
        return;
      }

      await _cancelPendingSignRequestsForTrainingLog(result.trainingLogId);

      final localUpsert = <String, Map<String, dynamic>>{};

      scheduleData.forEach((key, value) {
        if (value is! Map<String, dynamic>) return;

        final currentDocId = (value['docId'] ?? '').toString().trim();
        if (currentDocId != scheduleDocId) return;

        final localData = {
          ...Map<String, dynamic>.from(value),
          'lessonConfirmed': true,
          'lessonConfirmedAt': DateTime.now(),
          'lessonConfirmStatus': status,
          'lessonConfirmLabel': _confirmStatusLabel(status),
          'trainingLogId': result.trainingLogId,
          'attended': status == 'completed',
          'sessionSnapshotTotal': result.snapshotTotal,
          'sessionSnapshotRemainBefore': result.snapshotRemainBefore,
          'sessionSnapshotRemainAfter': result.snapshotRemainAfter,
          'sessionSnapshotDoneBefore': result.snapshotDoneBefore,
          'sessionSnapshotDoneAfter': result.snapshotDoneAfter,
          'sessionSnapshotLessonNumber': result.snapshotDoneAfter,
          'sessionSnapshotLabel':
              '${result.snapshotDoneAfter}/${result.snapshotTotal}',
        };

        switch (status) {
          case 'no_show_deducted':
            localData['attendanceOverride'] = 'no_show_deducted';
            break;
          case 'no_show_not_deducted':
            localData['attendanceOverride'] = 'no_show_not_deducted';
            break;
          case 'service':
            localData['attendanceOverride'] = 'service';
            break;
          case 'completed':
          default:
            localData.remove('attendanceOverride');
            break;
        }

        localUpsert[key] = localData;
      });

      if (localUpsert.isNotEmpty) {
        _patchScheduleData(
          upsert: localUpsert,
          syncWidget: false,
        );
      }

      await _refreshScheduleCountsFromMembers();

      if (mounted) {
        _queueHomeWidgetSync();
      }

      final message = switch (status) {
        'no_show_deducted' => '노쇼 차감으로 확정했어요.',
        'no_show_not_deducted' => '노쇼 미차감으로 확정했어요.',
        'service' => '서비스 레슨으로 확정했어요.',
        _ => (result.nextRemainForMessage ?? 0) <= 0
            ? '제가 고객카드 기준으로 확인했어요. 잔여 횟수는 0회입니다.'
            : '제가 고객카드 기준으로 확인했어요. 잔여 횟수를 소진하고, 담당자 확인 기록으로 남겨둘게요.',
      };

      _showActionToast(
        toastContext,
        message,
        bottomOffset: 110,
      );
    } catch (e) {
      debugPrint('스케줄 레슨 확정 실패: $e');

      if (!mounted) return;

      _showActionToast(
        toastContext,
        '레슨 확정에 실패했어요. 다시 시도해주세요.',
        bottomOffset: 110,
      );
    }
  }

  String _generateMemberSignToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = math.Random.secure();

    return List.generate(
      32,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
  }

  String _buildMemberSignUrl(String token) {
    return '$kMemberSignBaseUrl?t=$token';
  }

  String _quickSignLogIdFromSchedule({
    required String memberId,
    String? scheduleDocId,
    DateTime? startAt,
  }) {
    final cleanScheduleDocId = (scheduleDocId ?? '').trim();

    if (cleanScheduleDocId.isNotEmpty) {
      return 'quick_sign_$cleanScheduleDocId';
    }

    final start = startAt ?? DateTime.now();
    return 'quick_sign_${memberId}_${start.microsecondsSinceEpoch}';
  }

  Future<Map<String, String>?> _createMemberSignRequestFromSchedule({
    required String memberId,
    required String memberName,
    String? memberPhone,
    String? scheduleDocId,
    String lessonType = 'PT',
    DateTime? startAt,
    DateTime? endAt,
  }) async {
    if (_isPersonalWorkspace) {
      final allowed = await AifcTierFeatureGateSheet.guard(
        context: context,
        access: null,
        feature: AppTierFeatureKey.trainingLog,
        loadAccess: _loadCurrentTierAccess,
        entryPoint: 'home_schedule_member_signature_request',
      );
      if (!allowed || !mounted) return null;
    }

    final cleanMemberId = memberId.trim();
    final cleanMemberName = memberName.trim();
    final cleanPhone = _normalizePhone(memberPhone ?? '');
    final cleanScheduleDocId = (scheduleDocId ?? '').trim();

    if (cleanMemberId.isEmpty) {
      _showActionToast(
        context,
        '기존 회원 연결 후 서명 요청을 만들 수 있어요.',
        bottomOffset: 110,
      );
      return null;
    }

    if (await _isDeletedMemberId(cleanMemberId)) {
      _showActionToast(
        context,
        '삭제된 회원은 서명요청을 보낼 수 없어요.',
        bottomOffset: 110,
      );
      return null;
    }

    if (_isPersonalWorkspace) {
      final consentAllowed = await PersonalTrainingLogEntryGuard.guard(
        context: context,
        ownerUid: _personalOwnerUid,
        memberId: cleanMemberId,
        loadAccess: _loadCurrentTierAccess,
        entryPoint: 'home_schedule_member_signature_request_consent',
        checkTier: false,
      );
      if (!consentAllowed || !mounted) return null;
    }

    if (cleanScheduleDocId.isNotEmpty) {
      final isScheduleConfirmed =
          await _isScheduleDocConfirmed(cleanScheduleDocId);

      if (isScheduleConfirmed) {
        _showActionToast(
          context,
          '이미 확정된 레슨이에요.',
          bottomOffset: 110,
        );
        return null;
      }
    }

    final effectiveStartAt = startAt ?? DateTime.now();
    final effectiveEndAt =
        endAt ?? effectiveStartAt.add(const Duration(minutes: 50));

    final trainingLogId = _quickSignLogIdFromSchedule(
      memberId: cleanMemberId,
      scheduleDocId: cleanScheduleDocId,
      startAt: effectiveStartAt,
    );

    final existingLog = await FirebaseFirestore.instance
        .collection('training_logs')
        .doc(trainingLogId)
        .get();

    final existingLogData = existingLog.data();

    if (existingLogData != null) {
      final locked = existingLogData['locked'] == true;
      final deductionApplied = existingLogData['deductionApplied'] == true;
      final lessonConfirmed = existingLogData['lessonConfirmed'] == true ||
          existingLogData['lessonConfirmedAt'] != null;
      final waitingTrainerConfirm =
          existingLogData['waitingTrainerConfirm'] == true;
      final memberSigned = existingLogData['memberSigned'] == true;

      if (locked || deductionApplied || lessonConfirmed) {
        _showActionToast(
          context,
          '이미 확정된 레슨이에요.',
          bottomOffset: 110,
        );
        return null;
      }

      if (waitingTrainerConfirm || memberSigned) {
        _showActionToast(
          context,
          '이미 REMOTE SIGN 서명이 도착했어요. 빠른서명에서 확인해 주세요.',
          bottomOffset: 110,
        );
        return null;
      }
    }

    // 이미 만들어진 대기 요청이 있으면 새 QR을 만들지 않고 재사용
    final existingRequestSnapshot = await FirebaseFirestore.instance
        .collection('sign_requests')
        .where('trainingLogId', isEqualTo: trainingLogId)
        .limit(10)
        .get();

    final now = DateTime.now();

    for (final doc in existingRequestSnapshot.docs) {
      final data = doc.data();

      final used = data['used'] == true;
      final status = (data['status'] ?? '').toString();
      final expiresAtRaw = data['expiresAt'];

      DateTime? expiresAt;
      if (expiresAtRaw is Timestamp) {
        expiresAt = expiresAtRaw.toDate();
      } else if (expiresAtRaw is DateTime) {
        expiresAt = expiresAtRaw;
      }

      final isExpired = expiresAt != null && expiresAt.isBefore(now);

      final isWaiting = status == 'waiting_member_signature' ||
          status == 'waiting' ||
          status.isEmpty;

      if (!used && isWaiting && !isExpired) {
        final existingToken = (data['token'] ?? doc.id).toString().trim();

        if (existingToken.isNotEmpty) {
          return {
            'token': existingToken,
            'link': _buildMemberSignUrl(existingToken),
            'trainingLogId': trainingLogId,
          };
        }
      }

      if (!used && isExpired) {
        await doc.reference.set({
          'used': true,
          'status': 'expired',
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    final token = _generateMemberSignToken();
    final link = _buildMemberSignUrl(token);

    await FirebaseFirestore.instance
        .collection('sign_requests')
        .doc(token)
        .set({
      'token': token,
      'status': 'waiting_member_signature',
      'used': false,
      'memberId': cleanMemberId,
      'memberName': cleanMemberName.isEmpty ? '회원' : cleanMemberName,
      if (cleanPhone.isNotEmpty) 'memberPhone': cleanPhone,
      if (cleanScheduleDocId.isNotEmpty) 'scheduleDocId': cleanScheduleDocId,
      'trainingLogId': trainingLogId,
      'lessonType': lessonType,
      'startAt': Timestamp.fromDate(effectiveStartAt),
      'endAt': Timestamp.fromDate(effectiveEndAt),
      'requestType': 'member_signature',
      'source': 'trainer_app',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(hours: 24)),
      ),
    }, SetOptions(merge: true));

    return {
      'token': token,
      'link': link,
      'trainingLogId': trainingLogId,
    };
  }

  Future<void> _cancelPendingSignRequestsForTrainingLog(
    String trainingLogId,
  ) async {
    try {
      await LessonConfirmationService.cancelPendingSignRequestsForTrainingLog(
        trainingLogId,
      );
    } catch (e) {
      debugPrint('대기 중인 서명 요청 취소 실패: $e');
    }
  }

  void _onCellTap(String day, String time, bool hasSession, int weekOffset) {
    final key = _makeKey(weekOffset, day, time);
    final raw = scheduleData[key];

    if (raw is Map<String, dynamic>) {
      final docId = (raw['docId'] ?? '').toString().trim();

      if (docId.isNotEmpty && _isScheduleDocTemporarilyHidden(docId)) {
        _openLessonEditorSheet(day, time, weekOffset);
        return;
      }

      if (_isScheduleDataDeleted(raw)) {
        _openLessonEditorSheet(day, time, weekOffset);
        return;
      }

      _openLessonEditorSheet(
        day,
        time,
        weekOffset,
        existingSession: Map<String, dynamic>.from(raw),
      );
      return;
    }

    _openLessonEditorSheet(day, time, weekOffset);
  }

  String _lessonSlotKey(String day, String time) {
    return '$day|$time';
  }

  List<Map<String, dynamic>> _findLinkedRepeatGroupForSession({
    required int weekOffset,
    required Map<String, dynamic> session,
  }) {
    if (_repeatLessonGroupingMode == HomeRepeatLessonGroupingMode.none) {
      return const [];
    }

    final memberId = (session['memberId'] ?? '').toString().trim();

    if (memberId.isEmpty) {
      return const [];
    }

    final originalStartAt = session['startAt'];

    if (originalStartAt is! DateTime) {
      return const [];
    }

    final originalEndAt = _resolveSessionEndAt(session);
    final originalDurationMinutes =
        originalEndAt.difference(originalStartAt).inMinutes;

    if (originalDurationMinutes <= 0) {
      return const [];
    }

    final originalTypeId = (session['typeId'] ?? '').toString().trim();
    final originalTypeName =
        (session['typeName'] ?? session['type'] ?? '').toString().trim();

    final weekStart =
        _mondayOfWeek(currentTime).add(Duration(days: weekOffset * 7));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final result = <Map<String, dynamic>>[];

    scheduleData.forEach((key, value) {
      if (value is! Map<String, dynamic>) return;

      final docId = (value['docId'] ?? '').toString().trim();

      if (docId.isNotEmpty && _isScheduleDocTemporarilyHidden(docId)) {
        return;
      }

      if (_isScheduleDataDeleted(value)) {
        return;
      }

      if (_isScheduleLessonConfirmed(value)) {
        return;
      }

      final itemMemberId = (value['memberId'] ?? '').toString().trim();

      if (itemMemberId != memberId) {
        return;
      }

      final startAt = value['startAt'];

      if (startAt is! DateTime) {
        return;
      }

      if (startAt.isBefore(weekStart) || !startAt.isBefore(weekEnd)) {
        return;
      }

      final endAt = _resolveSessionEndAt(value);

      if (_repeatLessonGroupingMode ==
          HomeRepeatLessonGroupingMode.sameMemberSameTime) {
        if (startAt.hour != originalStartAt.hour ||
            startAt.minute != originalStartAt.minute) {
          return;
        }

        final durationMinutes = endAt.difference(startAt).inMinutes;

        if (durationMinutes != originalDurationMinutes) {
          return;
        }

        final itemTypeId = (value['typeId'] ?? '').toString().trim();
        final itemTypeName =
            (value['typeName'] ?? value['type'] ?? '').toString().trim();

        if (originalTypeId.isNotEmpty &&
            itemTypeId.isNotEmpty &&
            originalTypeId != itemTypeId) {
          return;
        }

        if (originalTypeId.isEmpty &&
            originalTypeName.isNotEmpty &&
            itemTypeName.isNotEmpty &&
            originalTypeName != itemTypeName) {
          return;
        }
      }

      final itemTypeId = (value['typeId'] ?? '').toString().trim();
      final itemTypeName =
          (value['typeName'] ?? value['type'] ?? '').toString().trim();

      if (originalTypeId.isNotEmpty &&
          itemTypeId.isNotEmpty &&
          originalTypeId != itemTypeId) {
        return;
      }

      if (originalTypeId.isEmpty &&
          originalTypeName.isNotEmpty &&
          itemTypeName.isNotEmpty &&
          originalTypeName != itemTypeName) {
        return;
      }

      final itemDay = _weekDaysAll[startAt.weekday - 1];

      result.add({
        'key': key,
        'docId': docId,
        'day': itemDay,
        'time': _timeStringFromDateTime(startAt),
        'startAt': startAt,
        'endAt': endAt,
        'data': Map<String, dynamic>.from(value),
      });
    });

    result.sort((a, b) {
      final aDay = (a['day'] ?? '').toString();
      final bDay = (b['day'] ?? '').toString();

      return _weekDaySortValue(aDay).compareTo(_weekDaySortValue(bDay));
    });

    return result;
  }

  DateTime _resolveSessionEndAt(Map<String, dynamic> session) {
    final start = session['startAt'];
    if (start is! DateTime) return DateTime.now();

    final end = session['endAt'];
    if (end is DateTime) return end;

    return start.add(Duration(minutes: _defaultLessonDurationMinutes));
  }

  int _durationMinutesFromSession(Map<String, dynamic> session) {
    final start = session['startAt'];

    if (start is! DateTime) {
      return _defaultLessonDurationMinutes;
    }

    final end = _resolveSessionEndAt(session);
    final minutes = end.difference(start).inMinutes;

    if (minutes <= 0) {
      return _defaultLessonDurationMinutes;
    }

    return minutes;
  }

  List<Map<String, dynamic>> _findScheduleOverlapsInRange({
    required DateTime startAt,
    required DateTime endAt,
    Set<String> ignoreDocIds = const <String>{},
  }) {
    final conflicts = <Map<String, dynamic>>[];

    if (!endAt.isAfter(startAt)) {
      return conflicts;
    }

    for (final value in scheduleData.values) {
      if (value is! Map<String, dynamic>) continue;

      final candidateDocId = value['docId']?.toString().trim() ?? '';

      final candidateStartAt = value['startAt'];

      if (candidateStartAt is! DateTime) {
        continue;
      }

      final candidateEndAt = _resolveSessionEndAt(value);

      final overlaps = isHomeScheduleConflictCandidate(
        candidateDocId: candidateDocId,
        candidateStartAt: candidateStartAt,
        candidateEndAt: candidateEndAt,
        targetStartAt: startAt,
        targetEndAt: endAt,
        ignoreDocIds: ignoreDocIds,
        isTemporarilyHidden: candidateDocId.isNotEmpty &&
            _isScheduleDocTemporarilyHidden(candidateDocId),
        isDeleted: _isScheduleDataDeleted(value),
      );

      if (!overlaps) {
        continue;
      }

      final day = _weekDaysAll[candidateStartAt.weekday - 1];

      conflicts.add({
        'day': day,
        'time': _timeStringFromDateTime(candidateStartAt),
        'endTime': _timeStringFromDateTime(candidateEndAt),
        'docId': candidateDocId,
        'name': (value['name'] ?? '').toString(),
      });
    }

    return conflicts;
  }

  bool _timeRangeOverlaps({
    required DateTime startA,
    required DateTime endA,
    required DateTime startB,
    required DateTime endB,
  }) {
    return startA.isBefore(endB) && startB.isBefore(endA);
  }

  Future<List<Map<String, dynamic>>> _findMoveConflicts({
    required int weekOffset,
    required String originalDay,
    required String originalTime,
    required Set<String> selectedDays,
    required String editableTime,
    required String editableEndTime,
    required Map<String, dynamic> existingSession,
  }) async {
    final originalDocId = _actualScheduleDocumentId(existingSession);

    final ignoreDocIds = <String>{
      ..._exactScheduleSourceDocIds(existingSession),
      _dataScheduleDocumentId(existingSession),
      if (originalDocId.isNotEmpty) originalDocId,
    }..removeWhere((id) => id.isEmpty);

    final conflicts = <Map<String, dynamic>>[];

    for (final d in selectedDays) {
      final targetStartAt = _dateForCell(weekOffset, d, editableTime);
      final targetEndAt = _dateForCell(weekOffset, d, editableEndTime);

      if (!targetEndAt.isAfter(targetStartAt)) {
        continue;
      }

      final targetConflicts = _findScheduleOverlapsInRange(
        startAt: targetStartAt,
        endAt: targetEndAt,
        ignoreDocIds: ignoreDocIds,
      );
      conflicts.addAll(targetConflicts);
      if (kDebugMode) {
        debugPrint(
          '[MTF_SCHEDULE_CONFLICT] '
          'targetDay=$d targetStartAt=${targetStartAt.toIso8601String()} '
          'targetEndAt=${targetEndAt.toIso8601String()} '
          'ignoredSourceCount=${ignoreDocIds.length} '
          'conflictCount=${targetConflicts.length} '
          'result=${targetConflicts.isEmpty ? 'clear' : 'blocked'}',
        );
      }
    }

    final unique = <String, Map<String, dynamic>>{};

    for (final item in conflicts) {
      final docId = item['docId']?.toString().trim() ?? '';

      if (docId.isEmpty) {
        continue;
      }

      unique[docId] = item;
    }

    return unique.values.toList();
  }

  Future<bool> _saveEditedLessonSchedule({
    required String editSessionId,
    required int weekOffset,
    required String originalDay,
    required String originalTime,
    required Set<String> selectedDays,
    required bool explicitMultiDaySelection,
    required String editableTime,
    required String editableEndTime,
    required String resolvedName,
    required LessonTypeItem lessonType,
    required bool attended,
    required Map<String, dynamic> countMap,
    String? memberId,
    String? phone,
    String? memo,
    required Map<String, dynamic> existingSession,
  }) async {
    if (!explicitMultiDaySelection && selectedDays.length != 1) {
      if (kDebugMode) {
        debugPrint(
          '[MTF_SCHEDULE_MUTATION] action=blocked '
          'reason=implicitMultiDaySelection selectedDays=$selectedDays',
        );
      }
      return false;
    }

    final existingDocId = _actualScheduleDocumentId(existingSession);

    if (existingDocId.isNotEmpty) {
      final isConfirmed = await _isScheduleDocConfirmed(existingDocId);

      if (isConfirmed) {
        return false;
      }
    }

    final originalDocId = _actualScheduleDocumentId(existingSession);
    if (originalDocId.isEmpty) return false;
    final editPlan = HomeScheduleEditPlan.resolve(
      sourceActualDocId: originalDocId,
      targetActualDocIds: selectedDays
          .map(
            (day) => _actualScheduleTargetDocumentId(
              _dateForCell(weekOffset, day, editableTime),
              day,
            ),
          )
          .toSet(),
    );

    final sourceItems = <Map<String, dynamic>>[
      {
        'key': existingSession['startAt'] is DateTime
            ? _absoluteKeyFromDate(existingSession['startAt'] as DateTime)
            : _makeKey(weekOffset, originalDay, originalTime),
        'docId': originalDocId,
        'day': originalDay,
        'time': originalTime,
        'startAt': existingSession['startAt'],
        'data': Map<String, dynamic>.from(existingSession),
      },
    ];

    if (sourceItems.any((item) {
      final data = item['data'];
      return data is Map<String, dynamic> && _hasUnsafeScheduleCollision(data);
    })) {
      return false;
    }

    final deleteDocIds = <String>{};

    final firestoreWrites = <HomeScheduleEditWrite>[];
    final localRemoves = <String>{};
    final localWrites = <Map<String, dynamic>>[];
    final affectedMemberIds = <String>{};

    final previousMemberId =
        (existingSession['memberId'] ?? '').toString().trim();

    if (previousMemberId.isNotEmpty) {
      affectedMemberIds.add(previousMemberId);
    }

    if ((memberId ?? '').trim().isNotEmpty) {
      affectedMemberIds.add(memberId!.trim());
    }

    for (final item in sourceItems) {
      final sourceDocId = (item['docId'] ?? '').toString().trim();
      final sourceDay = (item['day'] ?? '').toString().trim();
      final sourceKey = (item['key'] ?? '').toString().trim();

      if (sourceDocId.isEmpty || sourceDay.isEmpty) {
        continue;
      }

      final targetStartAt = _dateForCell(weekOffset, sourceDay, editableTime);
      final targetActualDocId = _actualScheduleTargetDocumentId(
        targetStartAt,
        sourceDay,
      );
      final sourceData = item['data'];
      final movePlan = HomeScheduleMovePlan.fromSnapshot(
        actualSourceDocId: sourceDocId,
        dataDocId:
            sourceData is Map ? (sourceData['docId'] ?? '').toString() : '',
        targetDocId: targetActualDocId,
      );

      if (kDebugMode) {
        final sourceStartAt = item['startAt'];
        debugPrint(
          '[MTF_SCHEDULE_MUTATION] action=move '
          'actualSourceDocId=${movePlan.sourceDocId} '
          'dataDocId=${movePlan.dataDocId} '
          'targetDocId=$targetActualDocId sourceStartAt=$sourceStartAt '
          'dataDocIdMismatch=${movePlan.hasDataDocIdMismatch} '
          'targetStartAt=${targetStartAt.toIso8601String()}',
        );
      }

      final sourceIsRetained = editPlan.sourceIsRetained;

      final exactSourceDocIds = sourceData is Map<String, dynamic>
          ? _exactScheduleSourceDocIds(sourceData)
          : <String>{movePlan.sourceDocId};
      final sourceIdsToDelete = !sourceIsRetained
          ? exactSourceDocIds
          : exactSourceDocIds.where((id) => id != movePlan.sourceDocId).toSet();

      if (sourceIdsToDelete.isNotEmpty) {
        for (final sourceId in sourceIdsToDelete) {
          deleteDocIds.add(sourceId);
          _markScheduleDocAsRecentlyDeleted(sourceId);
        }

        if (!sourceIsRetained && sourceKey.isNotEmpty) {
          localRemoves.add(sourceKey);
        }
      }
    }

    for (final d in selectedDays) {
      final dt = _dateForCell(weekOffset, d, editableTime);
      final endDt = _dateForCell(weekOffset, d, editableEndTime);

      if (!endDt.isAfter(dt)) {
        return false;
      }

      final targetDocId = _scheduleDocIdFromDate(dt, d);
      final targetActualDocId = _actualScheduleTargetDocumentId(dt, d);
      final targetKey = _absoluteKeyFromDate(dt);

      _clearRecentlyDeletedScheduleDocId(targetActualDocId);
      final cleanMemberId = (memberId ?? '').trim();
      final cleanPhone = _normalizePhone(phone ?? '');
      final cleanMemo = (memo ?? '').trim();

      final nextRemainingSessions =
          (countMap['remainingSessions'] ?? '').toString().trim();
      final nextTotalSessions =
          (countMap['totalSessions'] ?? '').toString().trim();

      final firestoreData = <String, dynamic>{
        'startAt': Timestamp.fromDate(dt),
        'day': d,
        'time': editableTime,
        'name': resolvedName,
        'type': lessonType.name,
        'typeName': lessonType.name,
        'typeId': lessonType.id,
        'typeColorHex': lessonType.colorHex,
        'attended':
            d == originalDay && editableTime == originalTime ? attended : false,
        'updatedAt': FieldValue.serverTimestamp(),
        'endAt': Timestamp.fromDate(endDt),
        'endTime': editableEndTime,

        // 비어 있으면 예전 연결값 삭제
        'memberId':
            cleanMemberId.isNotEmpty ? cleanMemberId : FieldValue.delete(),
        'phone': cleanPhone.isNotEmpty ? cleanPhone : FieldValue.delete(),

        // 비어 있으면 예전 메모 삭제
        'memo': cleanMemo.isNotEmpty ? cleanMemo : FieldValue.delete(),

        // 비어 있으면 예전 회차정보 삭제
        'remainingSessions': nextRemainingSessions.isNotEmpty
            ? nextRemainingSessions
            : FieldValue.delete(),
        'totalSessions': nextTotalSessions.isNotEmpty
            ? nextTotalSessions
            : FieldValue.delete(),
      };

      firestoreWrites.add(
        HomeScheduleEditWrite(
          targetDocId: targetDocId,
          data: firestoreData,
        ),
      );

      final localData = {
        ...Map<String, dynamic>.from(existingSession),
        'actualDocumentId': targetActualDocId,
        'dataDocumentId': targetActualDocId,
        'docId': targetActualDocId,
        'startAt': dt,
        'day': d,
        'time': editableTime,
        'name': resolvedName,
        'type': lessonType.name,
        'typeName': lessonType.name,
        'typeId': lessonType.id,
        'typeColorHex': lessonType.colorHex,
        'attended':
            d == originalDay && editableTime == originalTime ? attended : false,
        'endAt': endDt,
        'endTime': editableEndTime,
      };

      if (cleanMemberId.isNotEmpty) {
        localData['memberId'] = cleanMemberId;
      } else {
        localData.remove('memberId');
      }

      if (cleanPhone.isNotEmpty) {
        localData['phone'] = cleanPhone;
      } else {
        localData.remove('phone');
      }

      if (cleanMemo.isNotEmpty) {
        localData['memo'] = cleanMemo;
      } else {
        localData.remove('memo');
      }

      if (nextRemainingSessions.isNotEmpty) {
        localData['remainingSessions'] = nextRemainingSessions;
      } else {
        localData.remove('remainingSessions');
      }

      if (nextTotalSessions.isNotEmpty) {
        localData['totalSessions'] = nextTotalSessions;
      } else {
        localData.remove('totalSessions');
      }

      localWrites.add({
        'key': targetKey,
        'data': localData,
      });
    }

    _beginScheduleMutation(deleteDocIds);
    try {
      if (shouldUseSingleHomeScheduleEditCommit(
        selectedDayCount: selectedDays.length,
        deleteCount: deleteDocIds.length,
        explicitMultiDaySelection: explicitMultiDaySelection,
      )) {
        await HomeScheduleFirestoreService.commitEditedSchedule(
          deleteDocId: deleteDocIds.isEmpty ? null : deleteDocIds.first,
          retainedSourceDocIds:
              editPlan.sourceIsRetained ? <String>[originalDocId] : const [],
          writes: firestoreWrites,
          ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
        );
      } else {
        await HomeScheduleFirestoreService.commitScheduleWrites(
          deleteDocIds: deleteDocIds.toList(),
          retainedSourceDocIds:
              editPlan.sourceIsRetained ? <String>[originalDocId] : const [],
          writes: firestoreWrites,
          ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
        );
      }

      final removeKeys = localRemoves.toList();
      final upsert = <String, Map<String, dynamic>>{};

      for (final item in localWrites) {
        final key = item['key'] as String;
        final data =
            Map<String, dynamic>.from(item['data'] as Map<String, dynamic>);
        upsert[key] = data;
      }

      _patchScheduleData(
        removeKeys: removeKeys,
        upsert: upsert,
        syncWidget: false,
      );
      if (kDebugMode) {
        debugPrint(
          '[MTF_SCHEDULE_SAVE_RESULT] editSessionId=$editSessionId '
          'writeCount=${firestoreWrites.length} '
          'deleteCount=${deleteDocIds.length} '
          'localPatchCount=${removeKeys.length + upsert.length} '
          'result=success errorCode=none',
        );
      }

      for (final memberId in affectedMemberIds) {
        await _refreshMemberNextLesson(memberId);
      }

      if (mounted) {
        _queueHomeWidgetSync();
      }

      await _reconcilePersonalTierAfterServerWrite(
        deleteDocIds.isNotEmpty ? 'scheduleDelete' : 'scheduleCreate',
      );

      return true;
    } catch (e) {
      if (_shouldClearTombstoneAfterMutationError(e)) {
        for (final docId in deleteDocIds) {
          _clearRecentlyDeletedScheduleDocId(docId);
        }
      }

      if (kDebugMode) {
        final errorCode =
            e is FirebaseException ? e.code : e.runtimeType.toString();
        debugPrint(
          '[MTF_SCHEDULE_SAVE_RESULT] editSessionId=$editSessionId '
          'writeCount=${firestoreWrites.length} '
          'deleteCount=${deleteDocIds.length} localPatchCount=0 '
          'result=failure errorCode=$errorCode',
        );
      }
      _logTierReconcileSkipped(
        deleteDocIds.isNotEmpty ? 'scheduleDelete' : 'scheduleCreate',
      );
      return false;
    } finally {
      _endScheduleMutation(deleteDocIds);
    }
  }

  Future<HomeLessonSaveResult> _handleLessonSave(
    HomeLessonSaveRequest request,
  ) async {
    final isEditMode = request.isEditMode;
    final weekOffset = request.weekOffset;
    final originalDay = request.originalDay;
    final originalTime = request.originalTime;
    final saveSelection = normalizeHomeScheduleEditSelectionForSave(
      currentTargetDay: originalDay,
      selectedDays: request.selectedDays,
      explicitMultiDaySelection: request.explicitMultiDaySelection,
    );
    final selectedDays = saveSelection.selectedDays;
    final editableTime = request.editableTime;
    final editableEndTime = request.editableEndTime;
    final typedName = request.typedName;
    final lessonType = request.lessonType;
    final sessionCountController = request.sessionCountController;
    final existingSession = request.existingSession;
    final memoController = request.memoController;
    final selectedMemberId = request.selectedMemberId;
    final selectedMemberPhone = request.selectedMemberPhone;

    if (kDebugMode) {
      debugPrint(
        '[MTF_SCHEDULE_MUTATION] editSessionId=${request.editSessionId} '
        'caller=_handleLessonSave userAction=saveInvariant '
        'selectedWeekdays=${selectedDays.join(',')} '
        'isMultiDay=${saveSelection.isMultiDay} '
        'explicitMultiDaySelection=${saveSelection.explicitMultiDaySelection} '
        'selectedDatesChangedCaller=${request.selectedDatesChangedCaller} '
        'singleEditInvariantCorrected=${saveSelection.invariantCorrected} '
        'correctionReason=${saveSelection.correctionReason}',
      );
    }

    if (typedName.isEmpty) {
      return const HomeLessonSaveResult.failed(
        failureMessage: '이름을 입력해주세요.',
        errorCode: 'name_required',
      );
    }

    final resolvedMember = await _resolveMemberLinkBeforeSave(
      inputText: typedName,
      lessonLabel: '${_formatLessonSheetTime(editableTime)} 레슨',
      selectedMemberId: selectedMemberId,
      selectedMemberPhone: selectedMemberPhone,
    );

    if (resolvedMember == null) {
      return const HomeLessonSaveResult.failed(
        failureMessage: '회원 연결 정보를 확인해주세요.',
        errorCode: 'member_resolution_failed',
      );
    }

    final resolvedMemberId = resolvedMember['memberId']?.trim() ?? '';
    final resolvedPhone = _normalizePhone(resolvedMember['phone'] ?? '');
    final resolvedName = (resolvedMember['name']?.trim().isNotEmpty ?? false)
        ? resolvedMember['name']!.trim()
        : typedName;

    Map<String, dynamic> countMap =
        _parseSessionCount(sessionCountController.text);

    final resolvedSessionCountText =
        (resolvedMember['sessionCountText'] ?? '').trim();

    if (resolvedMemberId.isNotEmpty) {
      String linkedSessionCountText = resolvedSessionCountText;

      if (linkedSessionCountText.isEmpty) {
        linkedSessionCountText =
            await _loadMemberSessionCountText(resolvedMemberId);
      }

      if (linkedSessionCountText.isNotEmpty) {
        sessionCountController.text = linkedSessionCountText;
        countMap = _parseSessionCount(linkedSessionCountText);
      } else {
        countMap = {};
      }
    }

    final memoText = memoController.text.trim();

    for (final d in selectedDays) {
      final targetStartAt = _dateForCell(weekOffset, d, editableTime);
      final targetEndAt = _dateForCell(weekOffset, d, editableEndTime);

      if (!targetEndAt.isAfter(targetStartAt)) {
        return const HomeLessonSaveResult.failed(
          failureMessage: '종료 시간은 시작 시간보다 늦어야 해요.',
          errorCode: 'invalid_time_range',
        );
      }

      if (isEditMode) {
        final conflicts = await _findMoveConflicts(
          weekOffset: weekOffset,
          originalDay: originalDay,
          originalTime: originalTime,
          selectedDays: {d},
          editableTime: editableTime,
          editableEndTime: editableEndTime,
          existingSession: existingSession!,
        );

        if (conflicts.isNotEmpty) {
          return const HomeLessonSaveResult.failed(
            failureMessage: '같은 시간에 다른 레슨이 있어요.',
            errorCode: 'schedule_conflict',
          );
        }
      } else {
        final conflicts = _findScheduleOverlapsInRange(
          startAt: targetStartAt,
          endAt: targetEndAt,
        );

        if (conflicts.isNotEmpty) {
          return const HomeLessonSaveResult.failed(
            failureMessage: '같은 시간에 다른 레슨이 있어요.',
            errorCode: 'schedule_conflict',
          );
        }
      }
    }

    if (isEditMode) {
      final saved = await _saveEditedLessonSchedule(
        editSessionId: request.editSessionId,
        weekOffset: weekOffset,
        originalDay: originalDay,
        originalTime: originalTime,
        selectedDays: selectedDays,
        explicitMultiDaySelection: saveSelection.explicitMultiDaySelection,
        editableTime: editableTime,
        editableEndTime: editableEndTime,
        resolvedName: resolvedName,
        lessonType: lessonType,
        attended: existingSession?['attended'] == true,
        countMap: countMap,
        memberId: resolvedMemberId.isNotEmpty ? resolvedMemberId : null,
        phone: resolvedPhone.isNotEmpty ? resolvedPhone : null,
        existingSession: existingSession!,
        memo: memoText.isNotEmpty ? memoText : null,
      );

      if (!saved) {
        return const HomeLessonSaveResult.failed(
          failureMessage: '레슨일정을 저장하지 못했어요.',
          errorCode: 'edit_commit_failed',
        );
      }
    } else {
      try {
        for (final d in selectedDays) {
          await _saveScheduleToFirestore(
            weekOffset: weekOffset,
            day: d,
            time: editableTime,
            endTime: editableEndTime,
            name: resolvedName,
            lessonType: lessonType,
            attended: false,
            countMap: countMap,
            memberId: resolvedMemberId.isNotEmpty ? resolvedMemberId : null,
            phone: resolvedPhone.isNotEmpty ? resolvedPhone : null,
            memo: memoText.isNotEmpty ? memoText : null,
          );
        }

        if (resolvedMemberId.isNotEmpty) {
          await _refreshMemberNextLesson(resolvedMemberId);
        }
      } catch (_) {
        return const HomeLessonSaveResult.failed(
          failureMessage: '레슨일정을 저장하지 못했어요.',
          errorCode: 'create_commit_failed',
        );
      }
    }

    final orderedSelectedDays = _weekDaysAll
        .where((candidate) => selectedDays.contains(candidate))
        .toList();
    final primaryTargetDay = orderedSelectedDays.isNotEmpty
        ? orderedSelectedDays.first
        : originalDay;
    final primaryTargetStartAt =
        _dateForCell(weekOffset, primaryTargetDay, editableTime);

    return HomeLessonSaveResult(
      success: true,
      isLinkedMember: resolvedMemberId.isNotEmpty,
      targetDocId: _actualScheduleTargetDocumentId(
        primaryTargetStartAt,
        primaryTargetDay,
      ),
      targetStartAt: primaryTargetStartAt,
      isMultiDay: isExplicitHomeScheduleMultiDay(
        selectedDays,
        explicitMultiDaySelection: saveSelection.explicitMultiDaySelection,
      ),
      createdScheduleCount: isEditMode ? 0 : selectedDays.length,
    );
  }

  Future<void> _openLessonEditorSheet(
    String day,
    String time,
    int weekOffset, {
    Map<String, dynamic>? existingSession,
  }) async {
    final editorInput = HomeLessonEditorInput(
      day: day,
      time: time,
      weekOffset: weekOffset,
      existingSession: existingSession,
    );

    existingSession = editorInput.safeExistingSession;

    final bool isEditMode = editorInput.isEditMode;
    final editSessionId =
        'lesson-edit-${DateTime.now().microsecondsSinceEpoch}';
    final initialActualDocId = existingSession == null
        ? ''
        : _actualScheduleDocumentId(existingSession!);
    final initialDataDocId = existingSession == null
        ? ''
        : _dataScheduleDocumentId(existingSession!);
    final editSessionGuard = HomeScheduleEditSessionGuard(
      editSessionId: editSessionId,
      currentActualDocId: initialActualDocId,
      currentDataDocId: initialDataDocId,
      currentStartAt: existingSession?['startAt'] is DateTime
          ? existingSession!['startAt'] as DateTime
          : null,
    );

    final bool isConfirmedLesson = isEditMode &&
        existingSession != null &&
        _isScheduleLessonConfirmed(existingSession!);

    final nameController = TextEditingController(
      text: existingSession?['name']?.toString() ?? '',
    );

    final sessionCountController = TextEditingController(
      text: _buildSessionCountText(existingSession),
    );

    final memoController = TextEditingController(
      text: existingSession?['memo']?.toString() ?? '',
    );

    final List<LessonTypeItem> localLessonTypes =
        (_lessonTypes.isNotEmpty ? _lessonTypes : _buildSeedLessonTypes())
            .map((e) => e.copyWith())
            .toList();

    if (isEditMode && existingSession != null) {
      final existingType = _resolveLessonTypeForSchedule(existingSession!);
      final exists = localLessonTypes.any(
        (e) => e.id == existingType.id || e.name == existingType.name,
      );
      if (!exists) {
        localLessonTypes.add(existingType);
      }
    }

    String selectedLessonTypeId = (() {
      if (isEditMode && existingSession != null) {
        final existingType = _resolveLessonTypeForSchedule(existingSession!);
        final byId = localLessonTypes.where((e) => e.id == existingType.id);
        if (byId.isNotEmpty) return byId.first.id;

        final byName =
            localLessonTypes.where((e) => e.name == existingType.name);
        if (byName.isNotEmpty) return byName.first.id;
      }

      if (_lastSelectedLessonTypeId.isNotEmpty &&
          localLessonTypes.any((e) => e.id == _lastSelectedLessonTypeId)) {
        return _lastSelectedLessonTypeId;
      }

      return localLessonTypes.first.id;
    })();

    final originalStartAt = existingSession?['startAt'] is DateTime
        ? existingSession!['startAt'] as DateTime
        : null;
    final initialSelectedDay = originalStartAt == null
        ? day
        : _weekDaysAll[originalStartAt.weekday - 1];
    final selectionState = HomeScheduleEditSelectionState.single(
      currentDay: initialSelectedDay,
    );

    String? selectedMemberId = existingSession?['memberId']?.toString();
    String? selectedMemberPhone = existingSession?['phone']?.toString();

    final List<String> allDays = _weekDaysAll;

    String editableTime = time;

    String editableEndTime;

    if (isEditMode) {
      final existingEndAt = existingSession?['endAt'];

      if (existingEndAt is DateTime) {
        editableEndTime = _timeStringFromDateTime(existingEndAt);
      } else {
        final baseStart = _dateForCell(weekOffset, day, time);
        editableEndTime = _timeStringFromDateTime(
          baseStart.add(Duration(minutes: _preferredLessonDurationMinutes)),
        );
      }
    } else {
      final baseStart = _dateForCell(weekOffset, day, time);
      editableEndTime = _timeStringFromDateTime(
        baseStart.add(Duration(minutes: _preferredLessonDurationMinutes)),
      );
    }

    String? sheetToastMessage;
    Timer? sheetToastTimer;
    bool showMemberHint = false;
    bool didShowMemberInputHint = false;
    String memberHintMessage = '등록된 회원이라면 아래 회원 칩을 선택해주세요.';
    bool memberHintIsLinked = false;
    Timer? memberHintTimer;
    bool showLessonTypeEditor = false;
    bool sheetAlive = true;
    String? editingLessonTypeId;
    String editingColorHex = localLessonTypes.first.colorHex;
    final lessonTypeNameController = TextEditingController();
    final groupingCandidateCount = isEditMode && existingSession != null
        ? _findLinkedRepeatGroupForSession(
            weekOffset: weekOffset,
            session: existingSession!,
          ).length
        : 0;
    String buildEditSessionLogFields({
      required String mutationId,
      required String caller,
      required String userAction,
      required HomeScheduleEditSessionState stateBefore,
      String? sourceDocId,
      String? targetDocId,
      DateTime? targetStartAt,
      bool guardAllowed = true,
      String? ignoredReason,
    }) {
      final selectedDays = selectionState.selectedDays;
      final selectedDates = selectedDays
          .map(
            (selectedDay) => _dateForCell(
              weekOffset,
              selectedDay,
              editableTime,
            ).toIso8601String(),
          )
          .join(',');

      return 'editSessionId=$editSessionId mutationId=$mutationId '
          'caller=$caller userAction=$userAction '
          'stateBefore=${stateBefore.name} '
          'stateAfter=${editSessionGuard.state.name} '
          'currentActualDocId=${editSessionGuard.currentActualDocId} '
          'currentDataDocId=${editSessionGuard.currentDataDocId} '
          'sourceDocId=${sourceDocId ?? editSessionGuard.currentActualDocId} '
          'targetDocId=${targetDocId ?? ''} '
          'currentStartAt=${editSessionGuard.currentStartAt?.toIso8601String() ?? ''} '
          'targetStartAt=${targetStartAt?.toIso8601String() ?? ''} '
          'selectedDates=$selectedDates '
          'selectedWeekdays=${selectedDays.join(',')} '
          'isMultiDay=${isExplicitHomeScheduleMultiDay(
        selectedDays,
        explicitMultiDaySelection: selectionState.explicitMultiDaySelection,
      )} '
          'explicitMultiDaySelection=${selectionState.explicitMultiDaySelection} '
          'selectedDatesChangedCaller=${selectionState.lastChangedCaller} '
          'isRecurring=false '
          'groupingCandidateCount=$groupingCandidateCount '
          'groupingAppliedToSelection=false '
          'sheetMounted=${sheetAlive && mounted} '
          'selectedScheduleIdentity=${existingSession == null ? 0 : identityHashCode(existingSession)} '
          'mutationGuard=${guardAllowed ? 'allowed' : 'blocked'} '
          'callbackIgnoredReason=${ignoredReason ?? ''}';
    }

    void logEditSession({
      required String tag,
      required String mutationId,
      required String caller,
      required String userAction,
      required HomeScheduleEditSessionState stateBefore,
      String? sourceDocId,
      String? targetDocId,
      DateTime? targetStartAt,
      bool guardAllowed = true,
      String? ignoredReason,
    }) {
      if (!kDebugMode) return;
      debugPrint(
        '[$tag] ${buildEditSessionLogFields(
          mutationId: mutationId,
          caller: caller,
          userAction: userAction,
          stateBefore: stateBefore,
          sourceDocId: sourceDocId,
          targetDocId: targetDocId,
          targetStartAt: targetStartAt,
          guardAllowed: guardAllowed,
          ignoredReason: ignoredReason,
        )}',
      );
    }

    logEditSession(
      tag: 'MTF_SCHEDULE_EDIT_SESSION',
      mutationId: '$editSessionId-open',
      caller: '_openLessonEditorSheet',
      userAction: 'open',
      stateBefore: HomeScheduleEditSessionState.idle,
    );
    if (kDebugMode) {
      final initializedDates = selectionState.selectedDays
          .map(
            (selectedDay) => _dateForCell(
              weekOffset,
              selectedDay,
              editableTime,
            ).toIso8601String(),
          )
          .join(',');
      debugPrint(
        '[MTF_SCHEDULE_EDIT_SESSION] editSessionId=$editSessionId '
        'originalActualDocId=$initialActualDocId '
        'originalStartAt=${originalStartAt?.toIso8601String() ?? ''} '
        'initializedSelectedDates=$initializedDates '
        'initializedSelectedWeekdays=${selectionState.selectedDays.join(',')} '
        'explicitMultiDaySelection=false '
        'stateSource=editSessionLocalSingleLesson',
      );
    }

    LessonTypeItem? getSelectedLessonType() {
      for (final item in localLessonTypes) {
        if (item.id == selectedLessonTypeId) return item;
      }
      return localLessonTypes.isNotEmpty ? localLessonTypes.first : null;
    }

    void showSheetToast(
      void Function(VoidCallback fn) setModalState,
      String message,
    ) {
      if (!sheetAlive || !mounted) return;

      sheetToastTimer?.cancel();

      setModalState(() {
        sheetToastMessage = message;
      });

      sheetToastTimer = Timer(const Duration(milliseconds: 1400), () {
        if (!sheetAlive || !mounted) return;

        setModalState(() {
          sheetToastMessage = null;
        });
      });
    }

    void openAddLessonTypeEditor(void Function(VoidCallback fn) setModalState) {
      setModalState(() {
        showLessonTypeEditor = true;
        editingLessonTypeId = null;
        editingColorHex = _colorToHex(_nextSeedColor(localLessonTypes.length));
        lessonTypeNameController.clear();
      });
    }

    void openEditLessonTypeEditor(
      LessonTypeItem item,
      void Function(VoidCallback fn) setModalState,
    ) {
      setModalState(() {
        showLessonTypeEditor = true;
        editingLessonTypeId = item.id;
        editingColorHex = item.colorHex;
        lessonTypeNameController.text = item.name;
        lessonTypeNameController.selection = TextSelection.collapsed(
          offset: lessonTypeNameController.text.length,
        );
      });
    }

    void submitLessonTypeEditor(void Function(VoidCallback fn) setModalState) {
      final name = lessonTypeNameController.text.trim();
      if (name.isEmpty) {
        _showSnack('레슨 종류 이름을 입력해주세요.');
        return;
      }

      final duplicated = localLessonTypes.any((e) {
        if (editingLessonTypeId != null && e.id == editingLessonTypeId) {
          return false;
        }
        return e.name == name;
      });

      if (duplicated) {
        _showSnack('이미 있는 레슨 종류예요.');
        return;
      }

      FocusManager.instance.primaryFocus?.unfocus();

      setModalState(() {
        if (editingLessonTypeId == null) {
          final item = LessonTypeItem(
            id: _generateLessonTypeId(),
            name: name,
            colorHex: editingColorHex,
          );
          localLessonTypes.add(item);
          selectedLessonTypeId = item.id;
        } else {
          final index =
              localLessonTypes.indexWhere((e) => e.id == editingLessonTypeId);
          if (index >= 0) {
            localLessonTypes[index] = localLessonTypes[index].copyWith(
              name: name,
              colorHex: editingColorHex,
            );
            selectedLessonTypeId = localLessonTypes[index].id;
          }
        }

        showLessonTypeEditor = false;
        editingLessonTypeId = null;
        lessonTypeNameController.clear();
      });
    }

    void deleteEditingLessonType(void Function(VoidCallback fn) setModalState) {
      if (editingLessonTypeId == null) return;

      if (localLessonTypes.length <= 1) {
        _showSnack('레슨 종류는 최소 1개는 남아 있어야 해요.');
        return;
      }

      FocusManager.instance.primaryFocus?.unfocus();

      setModalState(() {
        localLessonTypes.removeWhere((e) => e.id == editingLessonTypeId);

        if (!localLessonTypes.any((e) => e.id == selectedLessonTypeId)) {
          selectedLessonTypeId = localLessonTypes.first.id;
        }

        showLessonTypeEditor = false;
        editingLessonTypeId = null;
        lessonTypeNameController.clear();
      });
    }

    HomeLessonEditorResult buildResult({
      String? snackMessage,
      bool savedSuccessfully = false,
      bool deletedSuccessfully = false,
      bool savedFromEditMode = false,
      bool savedIsLinkedMember = false,
      bool shouldOfferCustomerCard = false,
      int createdScheduleCount = 0,
      String? savedMemberName,
      String? savedMemberPhone,
      String? savedScheduleDocId,
    }) {
      return HomeLessonEditorResult(
        lessonTypes: localLessonTypes.map((e) => e.toMap()).toList(),
        selectedLessonTypeId: selectedLessonTypeId,
        savedSuccessfully: savedSuccessfully,
        deletedSuccessfully: deletedSuccessfully,
        savedFromEditMode: savedFromEditMode,
        savedIsLinkedMember: savedIsLinkedMember,
        shouldOfferCustomerCard: shouldOfferCustomerCard,
        createdScheduleCount: createdScheduleCount,
        savedMemberName: savedMemberName,
        savedMemberPhone: savedMemberPhone,
        savedScheduleDocId: savedScheduleDocId,
        snackMessage: snackMessage,
        editSessionId: editSessionId,
      );
    }

    Widget lockEditableArea(Widget child) {
      return IgnorePointer(
        ignoring: isConfirmedLesson,
        child: Opacity(
          opacity: isConfirmedLesson ? 0.52 : 1.0,
          child: child,
        ),
      );
    }

    final result = await showModalBottomSheet<HomeLessonEditorResult>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
            child: Material(
              color: const Color(0xFFF8FAFC),
              child: StatefulBuilder(
                builder: (sheetContext, setModalState) {
                  void safeSetModalState(VoidCallback fn) {
                    if (!sheetAlive || !mounted) return;
                    setModalState(fn);
                  }

                  final currentNameText = nameController.value.text.trim();
                  final searchKeyword = currentNameText.toLowerCase();

                  final bool hasLinkedMember = _hasLinkedMemberConnection(
                    memberId: selectedMemberId,
                    phone: selectedMemberPhone,
                  );

                  final linkedMemberDeleted =
                      _isLinkedMemberDeletedFromSession(existingSession);

                  final quickActionSession = existingSession == null
                      ? null
                      : Map<String, dynamic>.from(existingSession!);

                  final shouldRecommendLessonContractAction =
                      _shouldRecommendHomeLessonContractAction(
                    session: quickActionSession,
                    hasLinkedMember: hasLinkedMember,
                    linkedMemberDeleted: linkedMemberDeleted,
                  );

                  final shouldRecommendMembershipManageAction =
                      _shouldRecommendHomeMembershipManageAction(
                    session: quickActionSession,
                    hasLinkedMember: hasLinkedMember,
                    linkedMemberDeleted: linkedMemberDeleted,
                  );

                  void showMemberConnectionHint({
                    required String message,
                    required bool isLinked,
                    required Duration duration,
                  }) {
                    memberHintTimer?.cancel();

                    safeSetModalState(() {
                      showMemberHint = true;
                      memberHintMessage = message;
                      memberHintIsLinked = isLinked;
                    });

                    memberHintTimer = Timer(duration, () {
                      if (!sheetAlive || !mounted) return;

                      safeSetModalState(() {
                        showMemberHint = false;
                      });
                    });
                  }

                  void showMemberInputHintOnce() {
                    if (didShowMemberInputHint) return;
                    didShowMemberInputHint = true;
                    showMemberConnectionHint(
                      message: '등록된 회원이라면 아래 회원 칩을 선택해주세요.',
                      isLinked: false,
                      duration: const Duration(milliseconds: 1800),
                    );
                  }

                  void showMemberLinkedHint() {
                    showMemberConnectionHint(
                      message: '회원카드와 연결했어요.',
                      isLinked: true,
                      duration: const Duration(milliseconds: 1200),
                    );
                  }

                  void closeLessonEditorBeforeNavigate() {
                    final selectedLessonType = getSelectedLessonType();

                    if (selectedLessonType != null) {
                      setState(() {
                        _lessonTypes =
                            localLessonTypes.map((e) => e.copyWith()).toList();
                        _lastSelectedLessonTypeId = selectedLessonType.id;
                      });

                      unawaited(_saveLessonTypePrefs());
                    }

                    Navigator.of(sheetContext).pop();
                  }

                  return SafeArea(
                    top: false,
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              HomeLessonEditorHeader(
                                day: day,
                                startTimeLabel:
                                    _formatLessonSheetTime(editableTime),
                                endTimeLabel: editableEndTime.isEmpty
                                    ? '미설정'
                                    : _formatLessonSheetTime(editableEndTime),
                                endTimeIsEmpty: editableEndTime.isEmpty,
                                onClose: () => Navigator.of(sheetContext).pop(),
                                onTimeTap: () async {
                                  if (isConfirmedLesson) {
                                    showSheetToast(
                                      setModalState,
                                      '확정된 레슨은 시간을 수정할 수 없어요.',
                                    );
                                    return;
                                  }

                                  final picked =
                                      await _openLessonStartEndTimeDialog(
                                    initialStartTime: editableTime,
                                    initialEndTime: editableEndTime,
                                  );
                                  if (picked == null) return;

                                  safeSetModalState(() {
                                    editableTime = picked['startTime']!;
                                    editableEndTime = picked['endTime']!;
                                  });
                                },
                                onEndTimeTap: () async {
                                  if (isConfirmedLesson) {
                                    showSheetToast(
                                      setModalState,
                                      '확정된 레슨은 시간을 수정할 수 없어요.',
                                    );
                                    return;
                                  }

                                  final pickedEndTime =
                                      await _openLessonEndTimeOnlyDialog(
                                    initialStartTime: editableTime,
                                    initialEndTime: editableEndTime,
                                  );

                                  if (pickedEndTime == null) return;

                                  safeSetModalState(() {
                                    editableEndTime = pickedEndTime;
                                  });
                                },
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.center,
                                      children: [
                                        lockEditableArea(
                                          HomeLessonTypeSelector(
                                            lessonTypes: localLessonTypes,
                                            selectedTypeId:
                                                selectedLessonTypeId,
                                            onSelected: (item) {
                                              setModalState(() {
                                                selectedLessonTypeId = item.id;
                                              });
                                            },
                                            onAddTap: () =>
                                                openAddLessonTypeEditor(
                                              setModalState,
                                            ),
                                            onChipLongPress: (item) =>
                                                openEditLessonTypeEditor(
                                              item,
                                              setModalState,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          top: -5,
                                          child: IgnorePointer(
                                            child: Center(
                                              child:
                                                  HomeMemberConnectionHintBubble(
                                                visible: showMemberHint,
                                                message: memberHintMessage,
                                                isLinked: memberHintIsLinked,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (showLessonTypeEditor) ...[
                                      const SizedBox(height: 10),
                                      HomeLessonTypeEditorPanel(
                                        isEditMode: editingLessonTypeId != null,
                                        nameController:
                                            lessonTypeNameController,
                                        selectedColorHex: editingColorHex,
                                        paletteColorHexes: kLessonTypePalette
                                            .map((color) => _colorToHex(color))
                                            .toList(),
                                        onColorSelected: (hex) {
                                          setModalState(() {
                                            editingColorHex = hex;
                                          });
                                        },
                                        onClose: () {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();

                                          setModalState(() {
                                            showLessonTypeEditor = false;
                                            editingLessonTypeId = null;
                                            lessonTypeNameController.clear();
                                          });
                                        },
                                        onSubmit: () => submitLessonTypeEditor(
                                            setModalState),
                                        onDelete: editingLessonTypeId == null
                                            ? null
                                            : () => deleteEditingLessonType(
                                                setModalState),
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    lockEditableArea(
                                      HomeLessonDaySelector(
                                        allDays: allDays,
                                        selectedDays:
                                            selectionState.selectedDays,
                                        activeColor: kPrimaryColor,
                                        onDayTapped: (tappedDay) {
                                          final changed =
                                              selectionState.toggleDay(
                                            tappedDay,
                                            caller:
                                                'HomeLessonDaySelector.onDayTapped',
                                            userAction: 'toggleWeekday',
                                          );
                                          if (!changed) return;
                                          safeSetModalState(() {});
                                          logEditSession(
                                            tag: 'MTF_SCHEDULE_EDIT_SESSION',
                                            mutationId:
                                                '$editSessionId-selection',
                                            caller: selectionState
                                                .lastChangedCaller,
                                            userAction:
                                                selectionState.lastUserAction,
                                            stateBefore: editSessionGuard.state,
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    lockEditableArea(
                                      HomeLessonMemberInputSection(
                                        nameController: nameController,
                                        sessionCountController:
                                            sessionCountController,
                                        hasLinkedMember: hasLinkedMember ||
                                            isConfirmedLesson,
                                        onNameTap: showMemberInputHintOnce,
                                        onNameChanged: (_) {
                                          safeSetModalState(() {
                                            selectedMemberId = null;
                                            selectedMemberPhone = null;
                                          });
                                        },
                                        onClearName: () {
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();

                                          safeSetModalState(() {
                                            nameController.value =
                                                const TextEditingValue(
                                              text: '',
                                              selection:
                                                  TextSelection.collapsed(
                                                      offset: 0),
                                            );
                                            selectedMemberId = null;
                                            selectedMemberPhone = null;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    lockEditableArea(
                                      HomeLessonMemoSection(
                                        memoController: memoController,
                                      ),
                                    ),
                                    if (isEditMode) ...[
                                      const SizedBox(height: 8),
                                      HomeLessonQuickActionsSection(
                                        hasLinkedMember: hasLinkedMember,
                                        memberName: nameController.text.trim(),
                                        memberId: selectedMemberId,
                                        canUseLessonContract:
                                            shouldRecommendLessonContractAction,
                                        lessonContractLockedMessage:
                                            '레슨계약서는 Semi-Pro부터 사용할 수 있어요.',
                                        onOpenLessonContract:
                                            shouldRecommendLessonContractAction
                                                ? () async {
                                                    closeLessonEditorBeforeNavigate();

                                                    await Future.delayed(
                                                        const Duration(
                                                            milliseconds: 120));

                                                    if (!mounted) return;

                                                    await _openLessonContractFromHomeLesson(
                                                      memberId:
                                                          selectedMemberId,
                                                      memberName: nameController
                                                          .text
                                                          .trim(),
                                                    );
                                                  }
                                                : null,
                                        canUseMembershipManage:
                                            shouldRecommendMembershipManageAction,
                                        membershipManageLockedMessage:
                                            '회원권 관리는 Pro부터 사용할 수 있어요.',
                                        onOpenMembershipManage:
                                            shouldRecommendMembershipManageAction
                                                ? () async {
                                                    closeLessonEditorBeforeNavigate();

                                                    await Future.delayed(
                                                        const Duration(
                                                            milliseconds: 120));

                                                    if (!mounted) return;

                                                    await _openMembershipManageFromHomeLesson(
                                                      memberId:
                                                          selectedMemberId,
                                                      memberName: nameController
                                                          .text
                                                          .trim(),
                                                    );
                                                  }
                                                : null,
                                        linkedMemberDeleted:
                                            linkedMemberDeleted,
                                        isConfirmedLesson: isConfirmedLesson,
                                        isCustomerSignedConfirmedLesson:
                                            _isCustomerSignedConfirmedSchedule(
                                          existingSession == null
                                              ? null
                                              : Map<String, dynamic>.from(
                                                  existingSession!),
                                        ),
                                        isContractLinkedConfirmedLesson:
                                            _isContractLinkedConfirmedSchedule(
                                          existingSession == null
                                              ? null
                                              : Map<String, dynamic>.from(
                                                  existingSession!),
                                        ),
                                        onShowToast: (message) {
                                          _showActionToast(
                                            sheetContext,
                                            message,
                                            bottomOffset: 110,
                                          );
                                        },
                                        loadHasContract: (cleanMemberId) async {
                                          final snapshot =
                                              await FirebaseFirestore.instance
                                                  .collection('members')
                                                  .doc(cleanMemberId)
                                                  .get();

                                          final data = snapshot.data();
                                          if (data == null) return false;

                                          return _resolveQuickSignMemberState(
                                                  data)
                                              .hasContract;
                                        },
                                        onOpenMemberCard: () async {
                                          closeLessonEditorBeforeNavigate();

                                          await Future.delayed(const Duration(
                                              milliseconds: 120));

                                          if (!mounted) return;

                                          await _openClientCardFromSchedule(
                                            memberId: selectedMemberId,
                                            memberName:
                                                nameController.text.trim(),
                                            phone: selectedMemberPhone,
                                          );
                                        },
                                        onOpenWorkoutLog: () async {
                                          closeLessonEditorBeforeNavigate();

                                          await Future.delayed(const Duration(
                                              milliseconds: 120));

                                          if (!mounted) return;

                                          await _openWorkoutLogFromSchedule(
                                            memberId: selectedMemberId,
                                            memberName:
                                                nameController.text.trim(),
                                            phone: selectedMemberPhone,
                                          );
                                        },
                                        onOpenLessonConfirm: () async {
                                          closeLessonEditorBeforeNavigate();

                                          await Future.delayed(const Duration(
                                              milliseconds: 120));

                                          if (!mounted) return;

                                          final session = existingSession;
                                          final scheduleDocId =
                                              session?['docId']?.toString();
                                          final lessonType =
                                              (session?['typeName'] ??
                                                      session?['type'] ??
                                                      'PT')
                                                  .toString();

                                          DateTime? startAt;
                                          DateTime? endAt;

                                          if (session != null) {
                                            final rawStartAt =
                                                session['startAt'];
                                            final rawEndAt = session['endAt'];

                                            if (rawStartAt is DateTime) {
                                              startAt = rawStartAt;
                                            }

                                            if (rawEndAt is DateTime) {
                                              endAt = rawEndAt;
                                            }
                                          }

                                          await _openQuickSignFromSchedule(
                                            memberId: selectedMemberId,
                                            memberName:
                                                nameController.text.trim(),
                                            phone: selectedMemberPhone,
                                            scheduleDocId: scheduleDocId,
                                            lessonType: lessonType,
                                            startAt: startAt,
                                            endAt: endAt,
                                          );
                                        },
                                        onOpenSignRequest: () async {
                                          closeLessonEditorBeforeNavigate();

                                          await Future.delayed(const Duration(
                                              milliseconds: 120));

                                          if (!mounted) return;

                                          final session = existingSession;
                                          final scheduleDocId =
                                              session?['docId']?.toString();
                                          final lessonType =
                                              (session?['typeName'] ??
                                                      session?['type'] ??
                                                      'PT')
                                                  .toString();

                                          DateTime? startAt;
                                          DateTime? endAt;

                                          if (session != null) {
                                            final rawStartAt =
                                                session['startAt'];
                                            final rawEndAt = session['endAt'];

                                            if (rawStartAt is DateTime) {
                                              startAt = rawStartAt;
                                            }

                                            if (rawEndAt is DateTime) {
                                              endAt = rawEndAt;
                                            }
                                          }

                                          final request =
                                              await _createMemberSignRequestFromSchedule(
                                            memberId: selectedMemberId ?? '',
                                            memberName:
                                                nameController.text.trim(),
                                            memberPhone: selectedMemberPhone,
                                            scheduleDocId: scheduleDocId,
                                            lessonType: lessonType,
                                            startAt: startAt,
                                            endAt: endAt,
                                          );

                                          if (!mounted || request == null)
                                            return;

                                          final link =
                                              (request['link'] ?? '').trim();

                                          if (link.isEmpty) {
                                            _showActionToast(
                                              context,
                                              '서명 링크를 만들지 못했어요. 다시 시도해주세요.',
                                              bottomOffset: 110,
                                            );
                                            return;
                                          }

                                          await HomeMemberSignRequestSheet.show(
                                            context: context,
                                            memberName:
                                                nameController.text.trim(),
                                            link: link,
                                            primaryColor: kPrimaryColor,
                                            onShowToast:
                                                (toastContext, message) {
                                              _showActionToast(
                                                toastContext,
                                                message,
                                                bottomOffset: 110,
                                              );
                                            },
                                          );
                                        },
                                        onLinkExistingMember: () async {
                                          closeLessonEditorBeforeNavigate();

                                          await Future.delayed(const Duration(
                                              milliseconds: 120));

                                          if (!mounted) return;

                                          await _linkManualScheduleToExistingMember(
                                            memberName:
                                                nameController.text.trim(),
                                            scheduleDocId:
                                                existingSession?['docId']
                                                        ?.toString() ??
                                                    '',
                                          );
                                        },
                                        onRegisterManualMember: () async {
                                          closeLessonEditorBeforeNavigate();

                                          await Future.delayed(const Duration(
                                              milliseconds: 120));

                                          if (!mounted) return;

                                          await _openClientCardFromManualSchedule(
                                            memberName:
                                                nameController.text.trim(),
                                            phone: selectedMemberPhone,
                                            scheduleDocId:
                                                existingSession?['docId']
                                                    ?.toString(),
                                          );
                                        },
                                        onOpenLessonContractFromUnregistered:
                                            () async {
                                          final cleanName =
                                              nameController.text.trim();

                                          if (cleanName.isEmpty) {
                                            showSheetToast(
                                              setModalState,
                                              '회원 이름을 먼저 입력해주세요.',
                                            );
                                            return;
                                          }

                                          closeLessonEditorBeforeNavigate();

                                          await Future.delayed(const Duration(
                                              milliseconds: 120));

                                          if (!mounted) return;

                                          await _openLessonContractRegistrationFromHomeLesson(
                                            memberName: cleanName,
                                            phone: selectedMemberPhone,
                                            scheduleDocId:
                                                existingSession?['docId']
                                                    ?.toString(),
                                          );
                                        },
                                        onOpenMembershipContractFromUnregistered:
                                            () async {
                                          final cleanName =
                                              nameController.text.trim();

                                          if (cleanName.isEmpty) {
                                            showSheetToast(
                                              setModalState,
                                              '회원 이름을 먼저 입력해주세요.',
                                            );
                                            return;
                                          }

                                          closeLessonEditorBeforeNavigate();

                                          await Future.delayed(const Duration(
                                              milliseconds: 120));

                                          if (!mounted) return;

                                          await _openMembershipContractRegistrationFromHomeLesson(
                                            memberName: cleanName,
                                            phone: selectedMemberPhone,
                                            scheduleDocId:
                                                existingSession?['docId']
                                                    ?.toString(),
                                            lessonType: getSelectedLessonType()
                                                    ?.name ??
                                                (existingSession?['typeName'] ??
                                                        existingSession?[
                                                            'type'] ??
                                                        'PT')
                                                    .toString(),
                                            sessionCountText:
                                                sessionCountController.text
                                                    .trim(),
                                          );
                                        },
                                        onCancelConfirmedLesson: () async {
                                          final ok =
                                              await _askConfirmCancelPin();

                                          if (!mounted || ok != true) return;

                                          final cancelled =
                                              await _openCancelConfirmedLessonSheet(
                                            scheduleDocId:
                                                existingSession?['docId']
                                                        ?.toString() ??
                                                    '',
                                          );

                                          if (!mounted || !cancelled) return;

                                          if (Navigator.of(sheetContext)
                                              .canPop()) {
                                            Navigator.of(sheetContext).pop();
                                          }
                                        },
                                      ),
                                    ],
                                    const SizedBox(height: 10),
                                    HomeRecentMembersSection(
                                      searchKeyword: searchKeyword,
                                      ownerUid: _isPersonalWorkspace
                                          ? _personalOwnerUid
                                          : null,
                                      onOpenAllMembersTap: () async {
                                        Navigator.of(sheetContext).pop();

                                        await Future.delayed(
                                          const Duration(milliseconds: 120),
                                        );

                                        if (!mounted) return;

                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => ClientListPage(
                                              personalOwnerUid:
                                                  _isPersonalWorkspace
                                                      ? _personalOwnerUid
                                                      : null,
                                            ),
                                          ),
                                        );
                                      },
                                      onPicked: (name, memberId, phone,
                                          sessionCountText) {
                                        safeSetModalState(() {
                                          nameController.value =
                                              TextEditingValue(
                                            text: name,
                                            selection: TextSelection.collapsed(
                                              offset: name.length,
                                            ),
                                          );
                                          selectedMemberId = memberId;
                                          selectedMemberPhone = phone;

                                          if (sessionCountText.isNotEmpty) {
                                            sessionCountController.value =
                                                TextEditingValue(
                                              text: sessionCountText,
                                              selection:
                                                  TextSelection.collapsed(
                                                offset: sessionCountText.length,
                                              ),
                                            );
                                          }
                                        });

                                        showMemberLinkedHint();
                                      },
                                    ),
                                    const SizedBox(height: 18),
                                    HomeLessonFooterActions(
                                      isEditMode: isEditMode,
                                      isLocked: isConfirmedLesson,
                                      isCustomerSignedConfirmedLesson:
                                          _isCustomerSignedConfirmedSchedule(
                                        existingSession == null
                                            ? null
                                            : Map<String, dynamic>.from(
                                                existingSession!),
                                      ),
                                      isContractLinkedConfirmedLesson:
                                          _isContractLinkedConfirmedSchedule(
                                        existingSession == null
                                            ? null
                                            : Map<String, dynamic>.from(
                                                existingSession!),
                                      ),
                                      onCancel: () =>
                                          Navigator.of(sheetContext).pop(),
                                      onDelete: () async {
                                        final attempt = editSessionGuard.begin(
                                          HomeScheduleEditMutationAction.delete,
                                        );
                                        logEditSession(
                                          tag: attempt.allowed
                                              ? 'MTF_SCHEDULE_EDIT_SESSION'
                                              : 'MTF_SCHEDULE_CALLBACK',
                                          mutationId: attempt.mutationId,
                                          caller: 'lessonEditor.onDelete',
                                          userAction: 'deleteTap',
                                          stateBefore: attempt.stateBefore,
                                          guardAllowed: attempt.allowed,
                                          ignoredReason: attempt.ignoredReason,
                                        );
                                        if (!attempt.allowed) return;

                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                        await Future.delayed(
                                          const Duration(milliseconds: 10),
                                        );

                                        final docId = editSessionGuard
                                            .currentActualDocId
                                            .trim();

                                        if (docId.isEmpty) {
                                          editSessionGuard.fail();
                                          showSheetToast(
                                            setModalState,
                                            '삭제할 레슨일정을 찾지 못했어요.',
                                          );
                                          return;
                                        }

                                        final deleted =
                                            await _deleteScheduleFromFirestore(
                                          docId,
                                          schedule: existingSession == null
                                              ? null
                                              : Map<String, dynamic>.from(
                                                  existingSession!,
                                                ),
                                          editSessionLogFields:
                                              buildEditSessionLogFields(
                                            mutationId: attempt.mutationId,
                                            caller: 'lessonEditor.onDelete',
                                            userAction: 'deleteTap',
                                            stateBefore: attempt.stateBefore,
                                            sourceDocId: docId,
                                          ),
                                        );

                                        if (!sheetAlive ||
                                            editSessionGuard.state !=
                                                HomeScheduleEditSessionState
                                                    .saving) {
                                          logEditSession(
                                            tag: 'MTF_SCHEDULE_CALLBACK',
                                            mutationId: attempt.mutationId,
                                            caller: 'lessonEditor.onDelete',
                                            userAction: 'deleteResultIgnored',
                                            stateBefore: attempt.stateBefore,
                                            guardAllowed: false,
                                            ignoredReason: !sheetAlive
                                                ? 'sheetDisposed'
                                                : 'state_${editSessionGuard.state.name}',
                                          );
                                          return;
                                        }

                                        if (!deleted) {
                                          editSessionGuard.fail();
                                          logEditSession(
                                            tag: 'MTF_SCHEDULE_MUTATION',
                                            mutationId: attempt.mutationId,
                                            caller: 'lessonEditor.onDelete',
                                            userAction: 'deleteFailed',
                                            stateBefore: attempt.stateBefore,
                                            sourceDocId: docId,
                                          );
                                          if (!mounted) return;
                                          showSheetToast(
                                            setModalState,
                                            '레슨일정 삭제에 실패했어요.',
                                          );
                                          return;
                                        }

                                        editSessionGuard.completeDelete();
                                        logEditSession(
                                          tag: 'MTF_SCHEDULE_MUTATION',
                                          mutationId: attempt.mutationId,
                                          caller: 'lessonEditor.onDelete',
                                          userAction: 'deleteCompleted',
                                          stateBefore: attempt.stateBefore,
                                          sourceDocId: docId,
                                        );
                                        if (!mounted || !sheetAlive) return;
                                        sheetAlive = false;
                                        Navigator.of(sheetContext).pop(
                                          buildResult(
                                            deletedSuccessfully: true,
                                            snackMessage:
                                                '$day $time 레슨일정이 삭제되었어요.',
                                          ),
                                        );
                                      },
                                      onSave: () async {
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                        await Future.delayed(
                                          const Duration(milliseconds: 10),
                                        );

                                        final selectedLessonType =
                                            getSelectedLessonType();

                                        if (selectedLessonType == null) {
                                          showSheetToast(
                                            setModalState,
                                            '레슨 종류를 선택해주세요.',
                                          );
                                          return;
                                        }

                                        final typedName =
                                            nameController.text.trim();

                                        if (editableEndTime.trim().isEmpty) {
                                          showSheetToast(
                                            setModalState,
                                            '종료 시간을 설정해주세요.',
                                          );
                                          return;
                                        }

                                        final saveSelection =
                                            selectionState.prepareForSave(
                                          currentTargetDay: initialSelectedDay,
                                        );
                                        final selectedTargetDocIds =
                                            saveSelection.selectedDays
                                                .map(
                                                  (selectedDay) =>
                                                      _actualScheduleTargetDocumentId(
                                                    _dateForCell(
                                                      weekOffset,
                                                      selectedDay,
                                                      editableTime,
                                                    ),
                                                    selectedDay,
                                                  ),
                                                )
                                                .toSet();
                                        final editPlan =
                                            HomeScheduleEditPlan.resolve(
                                          sourceActualDocId: editSessionGuard
                                              .currentActualDocId,
                                          targetActualDocIds:
                                              selectedTargetDocIds,
                                        );
                                        final sourceIsRetained =
                                            editPlan.sourceIsRetained;
                                        final saveBranch = editPlan.branch.name;
                                        if (kDebugMode) {
                                          final selectedDates =
                                              saveSelection.selectedDays
                                                  .map(
                                                    (selectedDay) =>
                                                        _dateForCell(
                                                      weekOffset,
                                                      selectedDay,
                                                      editableTime,
                                                    ).toIso8601String(),
                                                  )
                                                  .join(',');
                                          debugPrint(
                                            '[MTF_SCHEDULE_EDIT_PLAN] '
                                            'editSessionId=$editSessionId '
                                            'sourceDocId=${editSessionGuard.currentActualDocId} '
                                            'sourceDay=$initialSelectedDay '
                                            'selectedDates=$selectedDates '
                                            'selectedDays=${saveSelection.selectedDays.join(',')} '
                                            'sourceRetained=$sourceIsRetained '
                                            'branch=$saveBranch '
                                            'deleteCount=${editPlan.deleteSource ? 1 : 0} '
                                            'writeCount=${editPlan.writeCount}',
                                          );
                                        }

                                        final attempt = editSessionGuard.begin(
                                          HomeScheduleEditMutationAction.save,
                                        );
                                        logEditSession(
                                          tag: attempt.allowed
                                              ? 'MTF_SCHEDULE_EDIT_SESSION'
                                              : 'MTF_SCHEDULE_CALLBACK',
                                          mutationId: attempt.mutationId,
                                          caller: 'lessonEditor.onSave',
                                          userAction: 'saveTap',
                                          stateBefore: attempt.stateBefore,
                                          guardAllowed: attempt.allowed,
                                          ignoredReason: attempt.ignoredReason,
                                        );
                                        if (!attempt.allowed) return;

                                        HomeLessonSaveResult saveResult;
                                        try {
                                          saveResult = await _handleLessonSave(
                                            HomeLessonSaveRequest(
                                              isEditMode: isEditMode,
                                              weekOffset: weekOffset,
                                              originalDay: initialSelectedDay,
                                              originalTime: time,
                                              selectedDays: Set<String>.from(
                                                saveSelection.selectedDays,
                                              ),
                                              explicitMultiDaySelection:
                                                  saveSelection
                                                      .explicitMultiDaySelection,
                                              editSessionId: editSessionId,
                                              selectedDatesChangedCaller:
                                                  selectionState
                                                      .lastChangedCaller,
                                              editableTime: editableTime,
                                              editableEndTime: editableEndTime,
                                              typedName: typedName,
                                              lessonType: selectedLessonType,
                                              sessionCountController:
                                                  sessionCountController,
                                              existingSession:
                                                  existingSession == null
                                                      ? null
                                                      : Map<String,
                                                          dynamic>.from(
                                                          existingSession!,
                                                        ),
                                              selectedMemberId:
                                                  selectedMemberId,
                                              selectedMemberPhone:
                                                  selectedMemberPhone,
                                              memoController: memoController,
                                            ),
                                          );
                                        } catch (error) {
                                          editSessionGuard.fail();
                                          logEditSession(
                                            tag: 'MTF_SCHEDULE_CALLBACK',
                                            mutationId: attempt.mutationId,
                                            caller: 'lessonEditor.onSave',
                                            userAction: 'saveException',
                                            stateBefore: attempt.stateBefore,
                                            guardAllowed: false,
                                            ignoredReason: 'exception_$error',
                                          );
                                          if (mounted && sheetAlive) {
                                            showSheetToast(
                                              setModalState,
                                              '레슨일정을 저장하지 못했어요.',
                                            );
                                          }
                                          return;
                                        }

                                        if (!sheetAlive ||
                                            editSessionGuard.state !=
                                                HomeScheduleEditSessionState
                                                    .saving) {
                                          logEditSession(
                                            tag: 'MTF_SCHEDULE_CALLBACK',
                                            mutationId: attempt.mutationId,
                                            caller: 'lessonEditor.onSave',
                                            userAction: 'saveResultIgnored',
                                            stateBefore: attempt.stateBefore,
                                            guardAllowed: false,
                                            ignoredReason: !sheetAlive
                                                ? 'sheetDisposed'
                                                : 'state_${editSessionGuard.state.name}',
                                          );
                                          return;
                                        }

                                        if (!saveResult.success) {
                                          editSessionGuard.fail();
                                          logEditSession(
                                            tag: 'MTF_SCHEDULE_CALLBACK',
                                            mutationId: attempt.mutationId,
                                            caller: 'lessonEditor.onSave',
                                            userAction: 'saveFailed',
                                            stateBefore: attempt.stateBefore,
                                            guardAllowed: false,
                                            ignoredReason: 'saveResultFailed',
                                          );
                                          showSheetToast(
                                            setModalState,
                                            saveResult.failureMessage,
                                          );
                                          return;
                                        }

                                        final sourceDocIdBeforeSave =
                                            editSessionGuard.currentActualDocId;
                                        final targetDocId =
                                            saveResult.targetDocId ??
                                                sourceDocIdBeforeSave;
                                        final targetStartAt = saveResult
                                                .targetStartAt ??
                                            editSessionGuard.currentStartAt ??
                                            _dateForCell(
                                              weekOffset,
                                              day,
                                              editableTime,
                                            );
                                        final moved = isEditMode &&
                                            sourceDocIdBeforeSave.isNotEmpty &&
                                            sourceDocIdBeforeSave !=
                                                targetDocId;
                                        editSessionGuard.completeSave(
                                          targetActualDocId: targetDocId,
                                          targetDataDocId: targetDocId,
                                          targetStartAt: targetStartAt,
                                          moved: moved,
                                        );
                                        if (existingSession != null) {
                                          existingSession = {
                                            ...existingSession!,
                                            'actualDocumentId': targetDocId,
                                            'dataDocumentId': targetDocId,
                                            'docId': targetDocId,
                                            'startAt': targetStartAt,
                                          };
                                        }
                                        logEditSession(
                                          tag: 'MTF_SCHEDULE_MUTATION',
                                          mutationId: attempt.mutationId,
                                          caller: 'lessonEditor.onSave',
                                          userAction: moved
                                              ? 'moveCompleted'
                                              : 'saveCompleted',
                                          stateBefore: attempt.stateBefore,
                                          sourceDocId: sourceDocIdBeforeSave,
                                          targetDocId: targetDocId,
                                          targetStartAt: targetStartAt,
                                        );

                                        if (!mounted || !sheetAlive) return;

                                        final orderedDays = _weekDaysAll
                                            .where(
                                              (d) => saveSelection.selectedDays
                                                  .contains(d),
                                            )
                                            .toList();

                                        final savedTypeLabel =
                                            saveResult.isLinkedMember
                                                ? '회원 레슨'
                                                : '미등록 회원 레슨';

                                        final bool shouldOfferCustomerCard =
                                            !isEditMode &&
                                                !saveResult.isLinkedMember &&
                                                typedName.trim().isNotEmpty &&
                                                saveSelection
                                                        .selectedDays.length ==
                                                    1;

                                        String? savedScheduleDocId;

                                        if (shouldOfferCustomerCard) {
                                          final savedDay = orderedDays.first;
                                          final savedStartAt = _dateForCell(
                                            weekOffset,
                                            savedDay,
                                            editableTime,
                                          );

                                          savedScheduleDocId =
                                              _scheduleDocIdFromDate(
                                            savedStartAt,
                                            savedDay,
                                          );
                                        }

                                        sheetAlive = false;
                                        Navigator.of(sheetContext).pop(
                                          buildResult(
                                            savedSuccessfully: true,
                                            savedFromEditMode: isEditMode,
                                            savedIsLinkedMember:
                                                saveResult.isLinkedMember,
                                            shouldOfferCustomerCard:
                                                shouldOfferCustomerCard,
                                            createdScheduleCount:
                                                saveResult.createdScheduleCount,
                                            savedMemberName: typedName.trim(),
                                            savedMemberPhone:
                                                selectedMemberPhone,
                                            savedScheduleDocId:
                                                savedScheduleDocId,
                                            snackMessage:
                                                '${orderedDays.join(', ')} '
                                                '${_formatLessonSheetTime(editableTime)} ~ '
                                                '${_formatLessonSheetTime(editableEndTime)} '
                                                '$savedTypeLabel으로 저장되었어요.',
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 70,
                          child: IgnorePointer(
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              child: sheetToastMessage == null
                                  ? const SizedBox.shrink()
                                  : Center(
                                      key: ValueKey(sheetToastMessage),
                                      child: Container(
                                        constraints:
                                            const BoxConstraints(maxWidth: 280),
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 24),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF111827)
                                              .withValues(alpha: 0.94),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.16),
                                              blurRadius: 12,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.info_outline_rounded,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                sheetToastMessage!,
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
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
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    final stateBeforeDispose = editSessionGuard.state;
    sheetAlive = false;

    sheetToastTimer?.cancel();
    memberHintTimer?.cancel();
    logEditSession(
      tag: 'MTF_SCHEDULE_CALLBACK',
      mutationId: '$editSessionId-close',
      caller: '_openLessonEditorSheet',
      userAction: 'sheetClosed',
      stateBefore: stateBeforeDispose,
      guardAllowed: false,
      ignoredReason: 'sheetDisposed',
    );
    editSessionGuard.dispose();
    selectionState.dispose();

// 안정화 우선:
// 레슨 등록 바텀시트는 닫힘 애니메이션, 키보드 hide, TextField 정리 타이밍이 겹치면
// TextEditingController was used after being disposed 오류가 발생할 수 있습니다.
// 지금은 빨간 화면 방지를 우선해서 dispose를 하지 않습니다.
// 추후 이 바텀시트를 별도 StatefulWidget으로 분리한 뒤 State.dispose()에서 정리합니다.

    if (!mounted || result == null) return;

    if (kDebugMode) {
      debugPrint(
        '[MTF_SCHEDULE_CALLBACK] editSessionId=${result.editSessionId ?? editSessionId} '
        'caller=_openLessonEditorSheet.result '
        'savedSuccessfully=${result.savedSuccessfully} '
        'deletedSuccessfully=${result.deletedSuccessfully} '
        'parentScheduleWrite=false '
        'callbackIgnoredReason=${result.deletedSuccessfully ? 'deleteResultDoesNotSave' : ''}',
      );
    }

    final rawLessonTypes = result.lessonTypes;
    final bool savedSuccessfully = result.savedSuccessfully;
    final bool savedFromEditMode = result.savedFromEditMode;
    final bool savedIsLinkedMember = result.savedIsLinkedMember;
    final bool shouldOfferCustomerCard = result.shouldOfferCustomerCard;

    final String savedMemberName =
        (result.savedMemberName ?? '').toString().trim();

    final String savedMemberPhone =
        (result.savedMemberPhone ?? '').toString().trim();

    final String savedScheduleDocId =
        (result.savedScheduleDocId ?? '').toString().trim();

    final nextLessonTypes = rawLessonTypes
        .whereType<Map>()
        .map((e) => LessonTypeItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    final nextSelectedLessonTypeId = result.selectedLessonTypeId.isNotEmpty
        ? result.selectedLessonTypeId
        : _lastSelectedLessonTypeId;

    final safeSelectedId =
        nextLessonTypes.any((e) => e.id == nextSelectedLessonTypeId)
            ? nextSelectedLessonTypeId
            : (nextLessonTypes.isNotEmpty
                ? nextLessonTypes.first.id
                : _lastSelectedLessonTypeId);

    final snackMessage = result.snackMessage;
    final nextLessonTypesSnapshot =
        nextLessonTypes.map((e) => e.copyWith()).toList();
    final nextSelectedLessonTypeIdSnapshot = safeSelectedId;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      setState(() {
        if (nextLessonTypesSnapshot.isNotEmpty) {
          _lessonTypes = nextLessonTypesSnapshot;
        }
        _lastSelectedLessonTypeId = nextSelectedLessonTypeIdSnapshot;
      });

      unawaited(_saveLessonTypePrefs());

      if (snackMessage != null && snackMessage.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 80), () {
          if (!mounted) return;
          _showActionToast(context, snackMessage, bottomOffset: 110);
        });
      }
      if (savedSuccessfully) {
        unawaited(
          _runAfterLessonSavedNudges(
            savedSuccessfully: savedSuccessfully,
            savedFromEditMode: savedFromEditMode,
            savedIsLinkedMember: savedIsLinkedMember,
            shouldOfferCustomerCard: shouldOfferCustomerCard,
            savedMemberName: savedMemberName,
            createdScheduleCount: result.createdScheduleCount,
            savedMemberPhone:
                savedMemberPhone.isEmpty ? null : savedMemberPhone,
            savedScheduleDocId:
                savedScheduleDocId.isEmpty ? null : savedScheduleDocId,
          ),
        );
      }
    });
  }

  int _weekDaySortValue(String day) {
    return _weekDaysAll.indexOf(day);
  }

  Future<List<Map<String, dynamic>>> _findPasteConflictsForWeek(
    int weekOffset,
    List<Map<String, dynamic>> items,
  ) async {
    final candidates = <HomeWeekPasteCandidate>[];

    for (final item in items) {
      final day = (item['day'] ?? '').toString().trim();
      final time = (item['time'] ?? '').toString().trim();
      final endTimeRaw = (item['endTime'] ?? '').toString().trim();

      if (day.isEmpty || time.isEmpty) continue;

      final startAt = _dateForCell(weekOffset, day, time);
      final endAt = endTimeRaw.isNotEmpty
          ? _dateForCell(weekOffset, day, endTimeRaw)
          : startAt.add(
              const Duration(minutes: _defaultLessonDurationMinutes),
            );

      if (!endAt.isAfter(startAt)) continue;

      final copyEndTime = _timeStringFromDateTime(endAt);
      final copyKey = '$day|$time|$copyEndTime';

      candidates.add(
        HomeWeekPasteCandidate(
          day: day,
          time: time,
          endTime: copyEndTime,
          copyKey: copyKey,
          startAt: startAt,
          endAt: endAt,
        ),
      );
    }

    if (candidates.isEmpty) return const [];

    final existingSchedules = <HomeWeekPasteExistingSchedule>[];

    for (final value in scheduleData.values) {
      if (value is! Map<String, dynamic>) continue;

      final docId = value['docId']?.toString().trim() ?? '';
      if (docId.isEmpty) continue;

      if (_isScheduleDocTemporarilyHidden(docId)) {
        continue;
      }

      if (_isScheduleDataDeleted(value)) {
        continue;
      }

      final rawStartAt = value['startAt'];
      if (rawStartAt is! DateTime) continue;

      final existingDay = _weekDaysAll[rawStartAt.weekday - 1];
      final existingEndAt = _resolveSessionEndAt(value);

      for (final actualDocId in _allScheduleDocumentIds(value)) {
        existingSchedules.add(
          HomeWeekPasteExistingSchedule(
            docId: actualDocId,
            day: existingDay,
            time: _timeStringFromDateTime(rawStartAt),
            endTime: _timeStringFromDateTime(existingEndAt),
            startAt: rawStartAt,
            endAt: existingEndAt,
            name: (value['name'] ?? '').toString(),
            memberId: (value['memberId'] ?? '').toString(),
            isConfirmed: _isScheduleLessonConfirmed(value),
          ),
        );
      }
    }

    if (existingSchedules.isEmpty) return const [];

    return HomeWeekPasteConflictService.findConflicts(
      candidates: candidates,
      existingSchedules: existingSchedules,
    );
  }

  Future<bool> _confirmWeekPasteOverwrite({
    required String targetLabel,
    List<Map<String, dynamic>> conflictExamples = const [],
  }) async {
    final conflictCount = conflictExamples.length;
    final confirmedCount =
        conflictExamples.where((e) => e['isConfirmed'] == true).length;
    final editableCount = conflictCount - confirmedCount;

    String exampleText() {
      if (conflictExamples.isEmpty) return '';

      final samples = conflictExamples.take(3).map((e) {
        final day = (e['day'] ?? '').toString();
        final time = (e['time'] ?? '').toString();
        final name = (e['name'] ?? '').toString();
        final isConfirmed = e['isConfirmed'] == true;

        final label = isConfirmed ? '확정 보호' : '덮어쓰기 가능';

        return '· $day $time ${name.isEmpty ? '레슨' : name} ($label)';
      }).join('\n');

      return '\n\n$samples';
    }

    final message = conflictCount == 0
        ? '$targetLabel에 붙여넣을 준비가 되었어요.'
        : '$targetLabel에 겹치는 레슨일정이 $conflictCount개 있어요.\n'
            '확정된 레슨 $confirmedCount개는 보호하고, 미확정 일정 $editableCount개만 덮어쓸 수 있어요.'
            '${exampleText()}\n\n'
            '복사한 스케줄을 이어서 붙여넣을까요?';

    return _showAifcConfirm(
      title: '겹치는 레슨일정이 있어요',
      message: message,
      cancelText: '취소',
      confirmText: '붙여넣기',
      userCancelText: '취소할게요',
      userConfirmText: '붙여넣을게요',
      cancelReplyText: '좋아요. 기존 스케줄은 그대로 둘게요.',
      confirmReplyText: '확인했어요. 확정된 레슨은 보호하고 붙여넣기를 진행할게요.',
    );
  }

  List<Map<String, dynamic>> _buildWeekCopyPayload(int weekOffset) {
    final payload = <Map<String, dynamic>>[];

    final weekStart =
        _mondayOfWeek(currentTime).add(Duration(days: weekOffset * 7));
    final weekEnd = weekStart.add(const Duration(days: 7));

    scheduleData.forEach((key, value) {
      if (value is! Map<String, dynamic>) return;

      final docId = (value['docId'] ?? '').toString().trim();

      if (docId.isNotEmpty && _isScheduleDocTemporarilyHidden(docId)) {
        return;
      }

      if (_isScheduleDataDeleted(value)) {
        return;
      }

      final rawStartAt = value['startAt'];

      final startAt = value['startAt'];

      if (startAt is! DateTime) return;

      if (startAt.isBefore(weekStart) || !startAt.isBefore(weekEnd)) {
        return;
      }

      final endAt = value['endAt'] is DateTime
          ? value['endAt'] as DateTime
          : startAt.add(const Duration(minutes: _defaultLessonDurationMinutes));

      final day = _weekDaysAll[startAt.weekday - 1];
      final time = _timeStringFromDateTime(startAt);

      final rawEndTime = (value['endTime'] ?? '').toString().trim();
      final endTime =
          rawEndTime.isNotEmpty ? rawEndTime : _timeStringFromDateTime(endAt);

      payload.add({
        'copyKey': '$day|$time',
        'day': day,
        'time': time,
        'endTime': endTime,
        'name': (value['name'] ?? '').toString(),
        'type': (value['typeName'] ?? value['type'] ?? 'PT').toString(),
        'typeName': (value['typeName'] ?? value['type'] ?? 'PT').toString(),
        'typeId': (value['typeId'] ?? '').toString(),
        'typeColorHex': (value['typeColorHex'] ?? '').toString(),
        'attended': false,
        if ((value['memberId'] ?? '').toString().trim().isNotEmpty)
          'memberId': (value['memberId'] ?? '').toString().trim(),
        if ((value['phone'] ?? '').toString().trim().isNotEmpty)
          'phone': (value['phone'] ?? '').toString().trim(),
        if ((value['remainingSessions'] ?? '').toString().trim().isNotEmpty)
          'remainingSessions':
              (value['remainingSessions'] ?? '').toString().trim(),
        if ((value['remainSessions'] ?? '').toString().trim().isNotEmpty)
          'remainSessions': (value['remainSessions'] ?? '').toString().trim(),
        if ((value['totalSessions'] ?? '').toString().trim().isNotEmpty)
          'totalSessions': (value['totalSessions'] ?? '').toString().trim(),
      });
    });

    return payload;
  }

  Future<void> _copyWeekSchedules(int weekOffset) async {
    final payload = _buildWeekCopyPayload(weekOffset);

    if (payload.isEmpty) {
      _showSnack('복사할 레슨일정이 없어요.');
      return;
    }

    setState(() {
      _copiedWeekSchedules = payload;
      _copiedWeekSourceLabel =
          _weekTitleForOffset(weekOffset).replaceAll('\n', ' ');
    });

    _showSnack('${payload.length}개의 레슨일정을 복사했어요.');
  }

  Future<void> _pasteWeekSchedules(int weekOffset) async {
    if (_copiedWeekSchedules.isEmpty) {
      _showSnack('먼저 복사한 레슨일정이 있어야 해요.');
      return;
    }

    if (scheduleData.values.any((value) =>
        value is Map<String, dynamic> && _hasUnsafeScheduleCollision(value))) {
      _showSnack('같은 시간에 서로 다른 레슨 문서가 있어 붙여넣기를 중단했어요.');
      return;
    }

    final targetLabel = _weekTitleForOffset(weekOffset).replaceAll('\n', ' ');

    final conflicts = await _findPasteConflictsForWeek(
      weekOffset,
      _copiedWeekSchedules,
    );

    final confirmedConflicts =
        conflicts.where((e) => e['isConfirmed'] == true).toList();

    final editableConflicts =
        conflicts.where((e) => e['isConfirmed'] != true).toList();

    final blockedCopyKeys = confirmedConflicts
        .map((e) => (e['copyKey'] ?? '').toString())
        .where((e) => e.isNotEmpty)
        .toSet();

    final overwriteDocIds = editableConflicts
        .map((e) => (e['docId'] ?? '').toString().trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    final affectedMemberIds = <String>{};

    for (final conflict in conflicts) {
      final memberId = (conflict['memberId'] ?? '').toString().trim();
      if (memberId.isNotEmpty) {
        affectedMemberIds.add(memberId);
      }
    }

    final memberActiveCache = <String, bool>{};

    Future<bool> isActiveMemberForPaste(String memberId) async {
      final cleanId = memberId.trim();
      if (cleanId.isEmpty) return false;

      if (memberActiveCache.containsKey(cleanId)) {
        return memberActiveCache[cleanId]!;
      }

      final active = await _isActiveMemberDoc(cleanId);
      memberActiveCache[cleanId] = active;
      return active;
    }

    if (conflicts.isNotEmpty) {
      final confirmed = await _confirmWeekPasteOverwrite(
        targetLabel: targetLabel,
        conflictExamples: conflicts,
      );

      if (!confirmed) return;
    }

    if (overwriteDocIds.isNotEmpty) {
      for (final docId in overwriteDocIds) {
        _markScheduleDocAsRecentlyDeleted(docId);
      }

      _beginScheduleMutation(overwriteDocIds);
      try {
        await HomeScheduleFirestoreService.deleteSchedules(
          overwriteDocIds,
          ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
        );
      } catch (e) {
        if (_shouldClearTombstoneAfterMutationError(e)) {
          for (final docId in overwriteDocIds) {
            _clearRecentlyDeletedScheduleDocId(docId);
          }
        }

        debugPrint('붙여넣기 덮어쓰기 삭제 실패: $e');

        if (!mounted) return;

        _showSnack('기존 레슨일정을 정리하지 못해 붙여넣기를 중단했어요.');
        return;
      } finally {
        _endScheduleMutation(overwriteDocIds);
      }

      final removeKeys = <String>[];

      scheduleData.forEach((key, value) {
        if (value is! Map<String, dynamic>) return;

        final docId = (value['docId'] ?? '').toString().trim();
        if (overwriteDocIds.contains(docId)) {
          removeKeys.add(key);
        }
      });

      if (removeKeys.isNotEmpty) {
        _patchScheduleData(
          removeKeys: removeKeys,
          syncWidget: false,
        );
      }
    }

    int pastedCount = 0;
    int skippedConfirmedCount = 0;

    final pasteWrites = <HomeScheduleEditWrite>[];

    for (final item in _copiedWeekSchedules) {
      final day = (item['day'] ?? '').toString().trim();
      final time = (item['time'] ?? '').toString().trim();
      final endTime = (item['endTime'] ?? '').toString().trim();
      final name = (item['name'] ?? '').toString().trim();

      if (day.isEmpty || time.isEmpty || name.isEmpty) continue;

      final startAt = _dateForCell(weekOffset, day, time);
      final resolvedEndTime = endTime.isNotEmpty
          ? endTime
          : _timeStringFromDateTime(
              startAt.add(
                const Duration(minutes: _defaultLessonDurationMinutes),
              ),
            );

      final copyKey = '$day|$time|$resolvedEndTime';

      if (blockedCopyKeys.contains(copyKey)) {
        skippedConfirmedCount++;
        continue;
      }

      final rawMemberId = (item['memberId'] ?? '').toString().trim();
      final rawPhone = _normalizePhone((item['phone'] ?? '').toString());

      final bool keepMemberLink =
          rawMemberId.isNotEmpty && await isActiveMemberForPaste(rawMemberId);

      final memberId = keepMemberLink ? rawMemberId : '';
      final phone = keepMemberLink ? rawPhone : '';

      final countMap = <String, dynamic>{};

      if (keepMemberLink) {
        final remainingSessions =
            (item['remainingSessions'] ?? '').toString().trim();
        final totalSessions = (item['totalSessions'] ?? '').toString().trim();

        if (remainingSessions.isNotEmpty) {
          countMap['remainingSessions'] = remainingSessions;
        }
        if (totalSessions.isNotEmpty) {
          countMap['totalSessions'] = totalSessions;
        }

        affectedMemberIds.add(memberId);
      }

      final copiedTypeId = (item['typeId'] ?? '').toString().trim();
      final copiedTypeName = (item['type'] ?? 'PT').toString().trim();
      final copiedTypeColorHex = (item['typeColorHex'] ?? '').toString().trim();

      final lessonType = copiedTypeId.isNotEmpty
          ? (_findLessonTypeById(copiedTypeId, _lessonTypes) ??
              LessonTypeItem(
                id: copiedTypeId,
                name: copiedTypeName.isEmpty ? 'PT' : copiedTypeName,
                colorHex: copiedTypeColorHex.isNotEmpty
                    ? copiedTypeColorHex
                    : _lessonTypeColorHexByName(copiedTypeName),
              ))
          : (_findLessonTypeByName(copiedTypeName, _lessonTypes) ??
              LessonTypeItem(
                id: _generateLessonTypeId(),
                name: copiedTypeName.isEmpty ? 'PT' : copiedTypeName,
                colorHex: copiedTypeColorHex.isNotEmpty
                    ? copiedTypeColorHex
                    : _lessonTypeColorHexByName(copiedTypeName),
              ));

      final dt = _dateForCell(weekOffset, day, time);
      final endDt = _dateForCell(weekOffset, day, resolvedEndTime);

      if (!endDt.isAfter(dt)) {
        continue;
      }

      final targetDocId = _scheduleDocIdFromDate(dt, day);

      _clearRecentlyDeletedScheduleDocId(targetDocId);

      pasteWrites.add(
        HomeScheduleEditWrite(
          targetDocId: targetDocId,
          data: {
            'startAt': Timestamp.fromDate(dt),
            'endAt': Timestamp.fromDate(endDt),
            'day': day,
            'time': time,
            'endTime': resolvedEndTime,
            'name': name,
            'type': lessonType.name,
            'typeName': lessonType.name,
            'typeId': lessonType.id,
            'typeColorHex': lessonType.colorHex,
            'attended': false,
            if (memberId.isNotEmpty) 'memberId': memberId,
            if (phone.isNotEmpty) 'phone': phone,
            ...countMap,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        ),
      );

      pastedCount++;
    }

    if (pasteWrites.isNotEmpty) {
      await HomeScheduleFirestoreService.commitScheduleWrites(
        writes: pasteWrites,
        ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
      );
    }

    for (final memberId in affectedMemberIds) {
      await _refreshMemberNextLesson(memberId);
    }

    if (mounted) {
      _queueHomeWidgetSync();
    }

    if (pastedCount == 0 && skippedConfirmedCount > 0) {
      _showSnack('확정된 레슨과 겹쳐 붙여넣을 수 있는 일정이 없어요.');
      return;
    }

    if (skippedConfirmedCount > 0) {
      _showSnack(
        '${_copiedWeekSourceLabel ?? '복사한 레슨일정'} 중 $pastedCount개를 $targetLabel 에 붙여넣었어요. '
        '확정된 레슨과 겹친 $skippedConfirmedCount개는 제외했어요.',
      );
      return;
    }

    _showSnack(
      '${_copiedWeekSourceLabel ?? '복사한 레슨일정'} $pastedCount개를 $targetLabel 에 붙여넣었어요.',
    );
  }

  Future<void> _deleteAllSchedulesInWeek(int weekOffset) async {
    final weekSlice = _buildWeekSlice(weekOffset);

    if (weekSlice.values.any((value) =>
        value is Map<String, dynamic> && _hasUnsafeScheduleCollision(value))) {
      _showSnack('같은 시간에 서로 다른 레슨 문서가 있어 전체삭제를 중단했어요.');
      return;
    }

    final allItems = weekSlice.entries
        .where((entry) => entry.value is Map<String, dynamic>)
        .map((entry) {
          final data = Map<String, dynamic>.from(entry.value as Map);
          return {
            'weekKey': entry.key,
            'data': data,
            'docId': (data['docId'] ?? '').toString().trim(),
            'docIds': _allScheduleDocumentIds(data).toList(),
            'memberId': (data['memberId'] ?? '').toString().trim(),
            'isConfirmed': _isScheduleLessonConfirmed(data),
          };
        })
        .where((item) => (item['docId'] ?? '').toString().isNotEmpty)
        .toList();

    if (allItems.isEmpty) {
      _showSnack('삭제할 레슨일정이 없어요.');
      return;
    }

    final protectedItems =
        allItems.where((item) => item['isConfirmed'] == true).toList();

    final deletableItems =
        allItems.where((item) => item['isConfirmed'] != true).toList();

    final protectedCount = protectedItems.length;
    final deleteCount = deletableItems.length;

    if (deleteCount == 0) {
      _showActionToast(
        context,
        '확정된 레슨은 전체삭제에서 제외돼요. 삭제할 미확정 일정이 없어요.',
        bottomOffset: 110,
      );
      return;
    }

    final targetLabel = _weekTitleForOffset(weekOffset).replaceAll('\n', ' ');

    final message = protectedCount > 0
        ? '$targetLabel 의 미확정 레슨일정 $deleteCount개만 삭제합니다.\n'
            '확정된 레슨 $protectedCount개는 보호되어 삭제하지 않아요.'
        : '$targetLabel 의 레슨일정 $deleteCount개를 모두 삭제합니다.\n'
            '삭제 후에는 되돌리기 어렵기 때문에 신중히 확인해주세요.';

    final confirmed = await _showAifcConfirm(
      title: '레슨일정을 삭제할까요?',
      message: message,
      cancelText: '취소',
      confirmText: '삭제',
      userCancelText: '취소할게요',
      userConfirmText: '삭제할게요',
      cancelReplyText: '좋아요. 레슨일정은 그대로 둘게요.',
      confirmReplyText: '확인했어요. 레슨일정 삭제를 진행할게요.',
      danger: true,
    );

    if (!confirmed) return;

    final deleteDocIds = deletableItems
        .expand((item) => ((item['docIds'] as List?) ?? const []))
        .map((id) => id.toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    for (final docId in deleteDocIds) {
      _markScheduleDocAsRecentlyDeleted(docId);
    }

    _beginScheduleMutation(deleteDocIds);
    try {
      await HomeScheduleFirestoreService.deleteSchedules(
        deleteDocIds.toList(),
        ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
      );
    } catch (e) {
      if (_shouldClearTombstoneAfterMutationError(e)) {
        for (final docId in deleteDocIds) {
          _clearRecentlyDeletedScheduleDocId(docId);
        }
      }

      debugPrint('주간 레슨일정 전체삭제 실패: $e');
      _logTierReconcileSkipped('scheduleDelete');

      if (!mounted) return;

      _showSnack('레슨일정 삭제에 실패했어요.');
      return;
    } finally {
      _endScheduleMutation(deleteDocIds);
    }

    final affectedMemberIds = deletableItems
        .map((item) => (item['memberId'] ?? '').toString().trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    for (final memberId in affectedMemberIds) {
      await _refreshMemberNextLesson(memberId);
    }

    final removeKeys = <String>[];

    scheduleData.forEach((key, value) {
      if (value is! Map<String, dynamic>) return;

      final docId = (value['docId'] ?? '').toString().trim();

      if (deleteDocIds.contains(docId)) {
        removeKeys.add(key);
      }
    });

    _patchScheduleData(
      removeKeys: removeKeys,
      syncWidget: true,
    );

    await _reconcilePersonalTierAfterServerWrite('scheduleDelete');

    if (protectedCount > 0) {
      _showSnack(
        '$targetLabel 미확정 레슨 $deleteCount개를 삭제했어요. 확정된 레슨 $protectedCount개는 보호했어요.',
      );
    } else {
      _showSnack('$targetLabel 레슨일정 $deleteCount개를 삭제했어요.');
    }
  }

  Future<void> _openWeekActionMenu(int weekOffset) async {
    final targetLabel = _weekTitleForOffset(weekOffset).replaceAll('\n', ' ');

    final action = await AifcHomeScheduleActionChatSheet.show(
      context: context,
      nickname: _bannerTrainerName,
      targetLabel: targetLabel,
      hasCopiedSchedules: _copiedWeekSchedules.isNotEmpty,
      copiedSourceLabel: _copiedWeekSourceLabel,
      copiedCount: _copiedWeekSchedules.length,
      primaryColor: kPrimaryColor,
    );

    if (!mounted || action == null) return;

    switch (action) {
      case AifcHomeScheduleAction.copyWeek:
        await _copyWeekSchedules(weekOffset);
        break;

      case AifcHomeScheduleAction.pasteWeek:
        await _pasteWeekSchedules(weekOffset);
        break;

      case AifcHomeScheduleAction.deleteWeek:
        await _deleteAllSchedulesInWeek(weekOffset);
        break;

      case AifcHomeScheduleAction.timeRange:
        await Future.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        await _openTimeRangeDialog();
        break;

      case AifcHomeScheduleAction.allRowsMinute:
        await Future.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        await _openAllRowsMinuteSheet();
        break;

      case AifcHomeScheduleAction.repeatGrouping:
        await Future.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        await _openRepeatLessonGroupingSheet();
        break;
    }
  }

  Future<void> _openWeekBulkActionMenu(int weekOffset) async {
    final targetLabel = _weekTitleForOffset(weekOffset).replaceAll('\n', ' ');

    final action = await AifcHomeScheduleActionChatSheet.show(
      context: context,
      nickname: _bannerTrainerName,
      targetLabel: targetLabel,
      hasCopiedSchedules: _copiedWeekSchedules.isNotEmpty,
      copiedSourceLabel: _copiedWeekSourceLabel,
      copiedCount: _copiedWeekSchedules.length,
      primaryColor: kPrimaryColor,
      openBulkFirst: true,
    );

    if (!mounted || action == null) return;

    switch (action) {
      case AifcHomeScheduleAction.copyWeek:
        await _copyWeekSchedules(weekOffset);
        break;

      case AifcHomeScheduleAction.pasteWeek:
        await _pasteWeekSchedules(weekOffset);
        break;

      case AifcHomeScheduleAction.deleteWeek:
        await _deleteAllSchedulesInWeek(weekOffset);
        break;

      case AifcHomeScheduleAction.timeRange:
        await Future.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        await _openTimeRangeDialog();
        break;

      case AifcHomeScheduleAction.allRowsMinute:
        await Future.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        await _openAllRowsMinuteSheet();
        break;

      case AifcHomeScheduleAction.repeatGrouping:
        await Future.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        await _openRepeatLessonGroupingSheet();
        break;
    }
  }

  // ---------- offset에 따라 상단 제목 문자열 생성 ----------
  String _weekTitleForOffset(int offset) {
    if (offset == -1) return "지난 주 스케줄";
    if (offset == 0) return "이번 주 스케줄";
    if (offset == 1) return "다음 주 스케줄";

    final mondayThisWeek = _mondayOfWeek(currentTime);
    final monday = mondayThisWeek.add(Duration(days: 7 * offset));
    final sunday = monday.add(const Duration(days: 6));

    String fmt(DateTime d) => "${d.month}월 ${d.day}일";

    return "${fmt(monday)}부터\n${fmt(sunday)}까지";
  }

  // ---------- 빌드 ----------

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double width = isTablet ? kMaxContentWidth : constraints.maxWidth;

        final nextLessons = _findTodayNextLessons();

        return WillPopScope(
          onWillPop: () async {
            final state = _homeScaffoldKey.currentState;

            if (state?.isEndDrawerOpen == true) {
              Navigator.of(context).pop();
              return false;
            }

            return true;
          },
          child: AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            ),
            child: Scaffold(
              key: _homeScaffoldKey,
              extendBody: true,
              backgroundColor: kBgColor,
              endDrawer: MtfAnimatedDrawer(
                trainerName: _bannerTrainerName,
                shortName: _trainerShortNameFromData(_bannerProfileData),
                tierName: _bannerTierName,
                memberCount: _bannerMemberCount,
                bannerData: PremiumBannerData(
                  currentTier:
                      _bannerStateReady ? _currentAppTier : AppTier.beginner,
                  isSponsor: _isSponsor,
                  scheduleCount: _amateurProgressCount,
                  memberCount: _bannerMemberCount,
                  trainerInfoDone: _displayTrainerInfoDone,
                  accountLinked: _bannerProfileData['accountLinked'] == true,
                  requiresLinkedAccount: false,
                  hasProduct: _hasProduct,
                ),
                onMyPage: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => buildHomeMyPageDestination(
                        personalOwnerUid:
                            _isPersonalWorkspace ? _personalOwnerUid : null,
                      ),
                    ),
                  );
                },
                onMembers: _openMembersPage,
                onContract: _openContractStartChatSheet,
                onMembershipContract: _openMembershipContractFromHome,
                onStats: _openThisWeekStats,
                onSettings: _openLegacySettingsPage,
                onUpgrade: () {
                  if (_currentAppTier == AppTier.pro) {
                    unawaited(
                      _openSupportTierGuideSheet(
                        highlightTier: 'pro',
                      ),
                    );
                    return;
                  }

                  if (_currentAppTier == AppTier.master ||
                      _currentAppTier == AppTier.grandPrix) {
                    unawaited(
                      _openCenterPlanGuideSheet(
                        highlightTier: _currentAppTier == AppTier.grandPrix
                            ? 'grandPrix'
                            : 'master',
                      ),
                    );
                    return;
                  }

                  unawaited(_openUpgradeChatSheet());
                },
                onGoods: () {
                  _showActionToast(
                    context,
                    '브랜딩 굿즈 제작은 준비중이에요. 강사님 이름이나 센터명을 담은 소량 홍보 상품을 곧 연결해드릴게요.',
                    bottomOffset: 110,
                  );
                },
                onLiveBeta: () => _showComingSoon('실시간 회원관리'),
              ),
              body: Center(
                child: SizedBox(
                  width: width,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SingleChildScrollView(
                        controller: _homeScrollController,
                        padding: const EdgeInsets.only(bottom: 120),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 10),
                            _buildProBanner(),
                            const SizedBox(height: 24),
                            _buildTodayNextLessons(nextLessons),
                            const SizedBox(height: 24),
                            _buildThisWeekSchedule(),
                            const SizedBox(height: 24),
                            _buildWeeklyGoal(),
                            const SizedBox(height: 24),
                            _buildRecentClients(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                      Positioned(
                        bottom: -10,
                        left: 0,
                        right: 0,
                        child: HomeBottomNavBar(
                          activeIndex: -1,
                          primaryColor: kPrimaryColor,
                          secondaryColor: kPrimaryColor2,
                          onChanged: (i) {
                            if (i == 0) {
                              _openThisWeekStats();
                            } else if (i == 1) {
                              _openContractStartChatSheet();
                            } else if (i == 2) {
                              _openConsultPlaceholder();
                            } else if (i == 3) {
                              _openMembersPage();
                            }
                          },
                          onCenterTap: _showQuickRegistrationDialog,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------- 섹션 위젯들 ----------

  HomeHeaderMessageSelection _resolveHomeHeaderMessageSelection() {
    final lessons = _scheduleItemsForToday()
        .map((item) => HomeHeaderLessonContext(
              startAt: item.startAt,
              endAt: item.endAt,
            ))
        .toList(growable: false);
    final activePhase = lessons
        .map((item) =>
            '${item.startAt.millisecondsSinceEpoch}:${item.endAt.isAfter(currentTime) ? 1 : 0}')
        .join(',');
    final eventKeys = _moreSenseItems.map((item) => item.key).join(',');
    final signature = [
      currentTime.year,
      currentTime.month,
      currentTime.day,
      currentTime.hour >= 11 && currentTime.hour < 14 ? 'meal' : 'normal',
      _homeEntrySerial,
      activePhase,
      eventKeys,
      _moreSenseMemberCount,
      _bannerMemberCount,
    ].join('|');

    if (_headerMessageSelection != null &&
        _headerMessageContextSignature == signature) {
      return _headerMessageSelection!;
    }

    final blockedQuestions = _headerMessageHistoryReady
        ? _askedHeaderQuestionKeys
        : <String>{
            'mood_future',
            'weather_umbrella',
            'gap_long_question',
            'gap_meal',
          };
    final selection = HomeHeaderMessageEngine.select(
      now: currentTime,
      lessons: lessons,
      moreSenseItems: _moreSenseItems,
      moreSenseCount: _moreSenseMemberCount,
      memberCount: _bannerMemberCount,
      entrySerial: _homeEntrySerial,
      recentKeys: _recentHeaderMessageKeys,
      askedQuestionKeysToday: blockedQuestions,
    );
    _headerMessageContextSignature = signature;
    _headerMessageSelection = selection;
    _recentHeaderMessageKeys = <String>{
      selection.fcKey,
      ..._recentHeaderMessageKeys,
    }.take(5).toSet();
    if (selection.questionKey != null) {
      _askedHeaderQuestionKeys = <String>{
        ..._askedHeaderQuestionKeys,
        selection.questionKey!,
      };
    }
    unawaited(_headerMessageHistory.remember(
      messageKey: selection.fcKey,
      questionKey: selection.questionKey,
    ));
    return selection;
  }

  Widget _buildHeader() {
    final todayCount = _countTodaySessions();
    final weekCount = _countThisWeekSessions();
    final moreSenseCount = _moreSenseMemberCount;

    final headerMessages = _resolveHomeHeaderMessageSelection();
    final workload = HomeHeaderMessageEngine.workloadFeedback(
      todayCount: todayCount,
      scheduleReady: _scheduleStreamReady,
    );
    final workloadSignature =
        '$todayCount|$_scheduleStreamReady|${workload.messageKey}';
    if (kDebugMode && _lastHeaderWorkloadLogSignature != workloadSignature) {
      _lastHeaderWorkloadLogSignature = workloadSignature;
      debugPrint(
        '[MTF_HEADER_WORKLOAD] todayCount=$todayCount '
        'scheduleReady=$_scheduleStreamReady '
        'bucket=${workload.bucket.name} messageKey=${workload.messageKey}',
      );
    }

    return HomeHeaderSection(
      isExpanded: isHeaderExpanded,
      todayCount: todayCount,
      weekCount: weekCount,
      moreSenseCount: moreSenseCount,
      aiFcHeaderNotice: headerMessages.fcText,
      expandedSupportNotice: workload.text,
      notificationsOn: _notificationsOn,
      primaryColor: kPrimaryColor,
      secondaryColor: kPrimaryColor2,
      loadProfileFromFirestore: !_isPersonalWorkspace,
      profileDisplayName: _bannerTrainerName,
      greetingScopeKey:
          _isPersonalWorkspace ? _personalPreferenceScope : 'legacy',
      onToggleExpanded: _toggleHeaderExpanded,
      onQuickMemberTap: () => _onAction(HomeAction.quickMember),
      onNotificationTap: () => _onAction(HomeAction.notifications),
      onTodayTap: _openTodayScheduleFocus,
      onMoreSenseTap: _openCareNeededMembers,
      onWeekTap: _openThisWeekStats,
    );
  }

  void _openCareNeededMembers() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientListPage(
          initialFilter: ClientListInitialFilter.careNeeded,
          personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
        ),
      ),
    );
  }

  String _nextTierNameFromAppTier(AppTier tier) {
    switch (tier) {
      case AppTier.beginner:
        return 'Amateur';
      case AppTier.amateur:
        return 'Semi-Pro';
      case AppTier.semiPro:
        return 'Pro';
      case AppTier.pro:
        return 'Master';
      case AppTier.master:
        return 'Grand Prix';
      case AppTier.grandPrix:
        return 'Grand Prix';
    }
  }

  Future<void> _openUpgradeChatSheet({
    String source = 'banner',
  }) async {
    if (!_bannerStateReady) {
      _showActionToast(
        context,
        '등급 정보를 확인하고 있어요. 잠시 후 다시 열어주세요.',
        bottomOffset: 110,
      );
      return;
    }

    final action = await AifcUpgradeChatSheet.show(
      context: context,
      data: PremiumBannerData(
        currentTier: _currentAppTier,
        isSponsor: _isSponsor,
        scheduleCount: _amateurProgressCount,
        memberCount: _bannerMemberCount,
        trainerInfoDone: _displayTrainerInfoDone,
        accountLinked: _bannerProfileData['accountLinked'] == true,
        requiresLinkedAccount: false,
        hasProduct: _hasProduct,
      ),
      trainerName: _bannerTrainerName,
    );

    if (!mounted) return;

    if (action == null || action == AifcUpgradeAction.later) {
      if (source == 'contract') {
        _showActionToast(
          context,
          '필요할 때 언제든 레슨계약서를 다시 시작할 수 있어요.',
          bottomOffset: 110,
        );
      }
      return;
    }

    switch (action) {
      case AifcUpgradeAction.showTierGuide:
        await AifcTierGuideChatSheet.show(
          context: context,
          trainerName: _bannerTrainerName,
          currentTierName: _currentAppTier.label,
          nextTierName: _nextTierNameFromAppTier(_currentAppTier),
          memberCount: _bannerMemberCount,
          lessonCount: scheduleData.length,
          hasProduct: _hasProduct,
          trainerInfoDone: _displayTrainerInfoDone,
        );
        break;

      case AifcUpgradeAction.sponsor:
        if (_currentAppTier == AppTier.master ||
            _currentAppTier == AppTier.grandPrix) {
          await _openCenterPlanGuideSheet(
            highlightTier:
                _currentAppTier == AppTier.grandPrix ? 'grandPrix' : 'master',
          );
          break;
        }

        await _openSupportTierGuideSheet(
          highlightTier: _currentAppTier == AppTier.pro ? 'pro' : 'semiPro',
        );
        break;

      case AifcUpgradeAction.goFillInfo:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => buildHomeMyPageDestination(
              personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
            ),
          ),
        );
        break;

      case AifcUpgradeAction.goAddMember:
        _openMembersPage();
        break;

      case AifcUpgradeAction.goAddProduct:
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => buildHomeMyPageDestination(
              personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
            ),
          ),
        );
        break;

      case AifcUpgradeAction.later:
        break;
    }
  }

  Widget _buildProBanner() {
    if (!_bannerStateReady) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          height: 92,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFE5E7EB),
            ),
          ),
          child: const Center(
            child: Text(
              '등급 정보를 확인하고 있어요',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PremiumBannerWidget(
        data: PremiumBannerData(
          currentTier: _currentAppTier,
          isSponsor: _isSponsor,
          scheduleCount: _amateurProgressCount,
          memberCount: _bannerMemberCount,
          trainerInfoDone: _displayTrainerInfoDone,
          accountLinked: _bannerProfileData['accountLinked'] == true,
          requiresLinkedAccount: false,
          hasProduct: _hasProduct,
        ),
        onTap: () {
          if (_currentAppTier == AppTier.pro) {
            unawaited(
              _openSupportTierGuideSheet(
                highlightTier: 'pro',
              ),
            );
            return;
          }

          if (_currentAppTier == AppTier.master ||
              _currentAppTier == AppTier.grandPrix) {
            unawaited(
              _openCenterPlanGuideSheet(
                highlightTier: _currentAppTier == AppTier.grandPrix
                    ? 'grandPrix'
                    : 'master',
              ),
            );
            return;
          }

          unawaited(_openUpgradeChatSheet());
        },
      ),
    );
  }

  Widget _buildTodayNextLessons(List<Map<String, dynamic>> nextLessons) {
    return KeyedSubtree(
      key: _todayNextLessonsKey,
      child: HomeTodayNextLessonsSection(
        nextLessons: nextLessons,
        primaryColor: kPrimaryColor,
        buildCountText: _buildTodayLessonCountText,
        onLessonTap: (day, time) {
          _onCellTap(day, time, true, 0);
        },
      ),
    );
  }

  Widget _buildThisWeekSchedule() {
    final weekOffset = _indexToOffset(_weekPageIndex);
    final title = _weekTitleForOffset(weekOffset);

    return KeyedSubtree(
      key: _scheduleSectionKey,
      child: HomeThisWeekScheduleSection(
        title: title,
        dayFilter: dayFilter,
        showScheduleHelp: _showScheduleHelp,
        weekPageController: _weekPageController,
        totalWeeks: _totalWeeks,
        weekPageIndex: _weekPageIndex,
        indexToOffset: _indexToOffset,
        timeSlots: _timeSlots,
        currentTime: currentTime,
        primaryColor: kPrimaryColor,
        shouldShowScheduleExamples: _shouldShowScheduleExamples,
        buildWeekSlice: _buildWeekSlice,
        buildScheduleExampleSlice: _buildScheduleExampleSlice,
        onToggleHelp: () {
          setState(() {
            _showScheduleHelp = !_showScheduleHelp;
          });
        },
        onDayFilterChanged: (value) {
          setState(() {
            dayFilter = value;
          });
          _queueHomeWidgetSync();
        },
        onPageChanged: (index) {
          setState(() {
            _weekPageIndex = index;
          });
        },
        onWeekActionMenu: _openWeekBulkActionMenu,
        onScheduleMoreMenu: _openWeekActionMenu,
        onHideScheduleExamples: _hideScheduleExamplesForever,
        onTimeHeaderTap: _openTimeRangeDialog,
        onTimeHeaderLongPress: () {
          unawaited(_openAllRowsMinuteSheet());
        },
        onTimeRowLongPress: (timeLabel) {
          _onTimeRowLongPress(timeLabel);
        },
        onExampleTap: _showScheduleExampleInfo,
        onCellTap: (offset, day, time, hasSession) {
          _onCellTap(day, time, hasSession, offset);
        },
        onEventTap: (offset, session) {
          final rawStartAt = session['startAt'];

          if (rawStartAt is! DateTime) return;

          final day = _weekDaysAll[rawStartAt.weekday - 1];

          final time =
              '${rawStartAt.hour.toString().padLeft(2, '0')}:${rawStartAt.minute.toString().padLeft(2, '0')}';

          _openLessonEditorSheet(
            day,
            time,
            offset,
            existingSession: Map<String, dynamic>.from(session),
          );
        },
      ),
    );
  }

  Widget _buildWeeklyGoal() {
    final weekOffset = _indexToOffset(_weekPageIndex);
    final goalTitle = homeWeeklyGoalTitleForOffset(
      weekOffset,
      fallbackWeekTitle: _weekTitleForOffset(weekOffset),
    );

    final weekCount = _countWeekSessions(weekOffset);
    final goalTarget = _weeklyGoalTarget();
    final progress = _weeklyGoalProgress(weekCount, goalTarget);
    final typeCounts = _countWeekLessonTypes(weekOffset);

    final top1 = _topWeeklyLessonTypeLabel(typeCounts, 0);
    final top2 = _topWeeklyLessonTypeLabel(typeCounts, 1);

    return HomeWeeklyGoalSection(
      title: goalTitle,
      weekCount: weekCount,
      goalTarget: goalTarget,
      progress: progress,
      topFirst: top1,
      topSecond: top2,
      primaryColor: kPrimaryColor,
      onEdit: _isPersonalWorkspace ? _editWeeklyGoal : null,
    );
  }

  Widget _buildRecentClients() {
    return HomeRecentClientsSection(
      primaryColor: kPrimaryColor,
      ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
      onOpenAllTap: _openMembersPage,
      onMemberTap: _openRecentMemberCard,
      onCreateTap: () {
        unawaited(_openFullRegistrationPage());
      },
    );
  }

  Future<void> _openRecentMemberCard(String memberId) async {
    final valid = await HomeMemberLookupService.validateMemberCardOwner(
      memberId,
      ownerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
      source: 'home_recent_member_card_open',
    );
    if (!mounted) return;
    if (!valid) {
      _showActionToast(
        context,
        '현재 작업공간에서 확인할 수 없는 회원이에요.',
        bottomOffset: 110,
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientCardPage(
          memberId: memberId,
          isEditMode: true,
          personalOwnerUid: _isPersonalWorkspace ? _personalOwnerUid : null,
        ),
      ),
    );
  }
}

@visibleForTesting
String homeWeeklyGoalTitleForOffset(
  int weekOffset, {
  required String fallbackWeekTitle,
}) {
  if (weekOffset == 0) return '이번 주 목표';
  if (weekOffset == 1) return '다음 주 목표';
  if (weekOffset == -1) return '지난 주 목표';
  return '${fallbackWeekTitle.replaceAll('\n', ' ')} 목표';
}

@visibleForTesting
int parseHomeWeeklyGoalInput(String value) {
  final parsed = int.tryParse(value.trim());
  return parsed != null && parsed > 0 ? parsed : 40;
}

class _HomeMembershipContractMember {
  const _HomeMembershipContractMember({
    required this.id,
    required this.name,
    required this.trainerName,
    required this.lessonType,
    required this.totalSessions,
    required this.remainingSessions,
    required this.membershipStartAt,
    required this.membershipEndAt,
    required this.membershipPaused,
  });

  final String id;
  final String name;
  final String trainerName;
  final String lessonType;
  final int totalSessions;
  final int remainingSessions;
  final DateTime? membershipStartAt;
  final DateTime? membershipEndAt;
  final bool membershipPaused;

  static DateTime? _dateFromAny(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }

  static int _intFromAny(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  factory _HomeMembershipContractMember.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    final sessions = data['sessions'] is Map
        ? Map<String, dynamic>.from(data['sessions'] as Map)
        : <String, dynamic>{};

    final membership = data['membership'] is Map
        ? Map<String, dynamic>.from(data['membership'] as Map)
        : <String, dynamic>{};

    final total = _intFromAny(
      sessions['total'] ?? data['totalSessions'] ?? data['sessionTotal'],
    );

    final remain = _intFromAny(
      sessions['remain'] ??
          data['remainSessions'] ??
          data['remainingSessions'] ??
          data['remainingPt'] ??
          data['ptRemaining'],
    );

    return _HomeMembershipContractMember(
      id: id,
      name: (data['name'] ?? '').toString().trim(),
      trainerName: (data['trainer'] ?? '').toString().trim(),
      lessonType: (data['lessonType'] ?? '').toString().trim(),
      totalSessions: total,
      remainingSessions: remain,
      membershipStartAt: _dateFromAny(membership['startAt']),
      membershipEndAt: _dateFromAny(membership['endAt']),
      membershipPaused: membership['status'] == 'paused' ||
          data['membershipStatus'] == 'paused',
    );
  }
}
