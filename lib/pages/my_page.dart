import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'settings_page.dart';
import 'password_change_page.dart';
import 'stats_page.dart';
import 'contract_list_page.dart';
import 'more_care_admin_page.dart';

import '../services/app_tier_access_service.dart';
import '../services/lesson_product_service.dart';
import '../services/managed_member_workspace_service.dart';
import '../services/app_environment.dart';
import '../services/my_page_draft_store.dart';
import '../utils/personal_tier_parser.dart';
import '../utils/member_input_validation.dart';
import '../utils/personal_trainer_profile_validation.dart';

import '../models/product_model.dart';
import '../models/personal_tier_progress.dart';

import '../widgets/aifc_tier_guide_chat_sheet.dart';
import '../widgets/aifc_tier_feature_gate_sheet.dart';
import '../widgets/aifc_interaction.dart';
import '../widgets/aifc_confirm_chat_sheet.dart';
import '../widgets/aifc_option_chat_sheet.dart';
import '../widgets/aifc_info_chat_sheet.dart';
import '../widgets/premium_banner_widget.dart';
import '../widgets/mtf_header_neon_overlay.dart';
import '../widgets/mtf_floating_more_menu.dart';
import '../widgets/aifc_upgrade_chat_sheet.dart';
import '../theme/app_colors.dart';

import '../aifc/core/aifc_chat_sheet.dart';
import '../aifc/core/aifc_nickname.dart';
import '../aifc/core/aifc_avatar.dart';

import 'package:flutter/services.dart';

const Color kMyPrimary = Color(0xFF4F46E5);
const Color kMyPrimary2 = Color(0xFF9333EA);
const Color kMyBg = Color(0xFFF3F4F6);
const Color kMyCard = Colors.white;
const Color kMyBorder = Color(0xFFE5E7EB);
const Color kMyText = Color(0xFF111827);
const Color kMyMuted = Color(0xFF6B7280);
const double kMyMaxContentWidth = 480;

String myPageProfileDocumentPath(String? personalOwnerUid) {
  final uid = (personalOwnerUid ?? '').trim();
  return uid.isEmpty ? 'trainer_profile/me' : 'trainer_profiles/$uid';
}

String myPageNudgePreferenceKey(
  String? personalOwnerUid, {
  String? projectId,
}) {
  const base = 'my_ai_fc_profile_nudge_step_v1';
  final uid = (personalOwnerUid ?? '').trim();
  return uid.isEmpty
      ? base
      : AppEnvironmentConfig.personalPreferenceKey(
          uid: uid,
          featureKey: base,
          projectId: projectId,
        );
}

String myPageNicknameFromProfile(
  Map<String, dynamic> data, {
  required bool personalWorkspace,
}) {
  final nickname = (data['nickname'] ?? '').toString().trim();
  if (personalWorkspace) return nickname;
  final displayName = (data['displayName'] ?? '').toString().trim();
  return displayName.isNotEmpty ? displayName : nickname;
}

String myPageRealNameFromProfile(
  Map<String, dynamic> data, {
  required bool personalWorkspace,
}) {
  if (personalWorkspace) return (data['realName'] ?? '').toString().trim();
  return (data['name'] ?? data['realName'] ?? '').toString().trim();
}

String myPageJobTitleFromProfile(
  Map<String, dynamic> data, {
  required bool personalWorkspace,
}) {
  if (personalWorkspace) {
    return (data['jobTitle'] ?? data['position'] ?? '').toString().trim();
  }
  return (data['position'] ?? data['affiliationType'] ?? '').toString().trim();
}

String myPageLessonFieldsFromProfile(
  Map<String, dynamic> data, {
  required bool personalWorkspace,
}) {
  if (personalWorkspace) {
    return (data['primaryActivity'] ?? data['lessonSpecialty'] ?? '')
        .toString()
        .trim();
  }
  return (data['lessonSpecialty'] ?? data['primaryActivity'] ?? '')
      .toString()
      .trim();
}

enum MyPageNameSaveAction { save, requireName, confirmRealName }

enum _RealNameNicknameChoice { useRealName, enterNickname, cancel }

MyPageNameSaveAction resolveMyPageNameSaveAction({
  required String nickname,
  required String realName,
}) {
  final cleanNickname = nickname.trim();
  final cleanRealName = realName.trim();
  if (cleanNickname.isEmpty && cleanRealName.isEmpty) {
    return MyPageNameSaveAction.requireName;
  }
  if (cleanNickname.isEmpty) {
    return MyPageNameSaveAction.confirmRealName;
  }
  return MyPageNameSaveAction.save;
}

bool canUseRealNameAsNickname(String realName) {
  final cleanRealName = realName.trim();
  return cleanRealName.isNotEmpty && cleanRealName.length <= 6;
}

const Set<String> _myPageContractNameSources = {
  'realName',
  'displayName',
  'manual',
};

String myPageContractNameSourceFromProfile(Map<String, dynamic> data) {
  final source = (data['contractTrainerNameSource'] ?? '').toString().trim();
  return _myPageContractNameSources.contains(source) ? source : 'manual';
}

String myPageContractCustomNameFromProfile(
  Map<String, dynamic> data, {
  required String source,
}) {
  final custom = (data['contractTrainerCustomName'] ?? '').toString().trim();
  if (custom.isNotEmpty) return custom;
  if (source != 'manual') return '';
  return (data['contractTrainerName'] ?? '').toString().trim();
}

String? myPageContractNameValidationMessage({
  required String source,
  required String nickname,
  required String realName,
  required String customName,
}) {
  switch (source) {
    case 'displayName':
      return nickname.trim().isEmpty ? '계약서에 반영할 닉네임을 입력해주세요.' : null;
    case 'realName':
      return realName.trim().isEmpty ? '계약서에 반영할 실명을 입력해주세요.' : null;
    case 'manual':
      return customName.trim().isEmpty ? '계약서에 반영할 이름을 입력해주세요.' : null;
    default:
      return '계약서 담당강사명 반영 방식을 다시 선택해주세요.';
  }
}

String myPageJobPrompt(String nickname) {
  return nickname.trim().isEmpty
      ? '회원님들께 어떤 직업으로 안내할까요?'
      : '어떤 직업으로 회원님들께 안내할까요?';
}

enum MyPageMoreMenuAction { stats, contracts, settings, passwordChange }

enum _MyPageExitAction { saveExit, draftExit, discard, continueEditing }

const List<MtfMoreMenuItem<MyPageMoreMenuAction>> myPageMoreMenuItems = [
  MtfMoreMenuItem(
    value: MyPageMoreMenuAction.stats,
    icon: Icons.bar_chart_rounded,
    label: '인사이트',
    subLabel: '레슨 추이와 관리 흐름',
  ),
  MtfMoreMenuItem(
    value: MyPageMoreMenuAction.contracts,
    icon: Icons.description_outlined,
    label: '계약서 관리',
    subLabel: '계약서 작성 · 이력',
  ),
  MtfMoreMenuItem(
    value: MyPageMoreMenuAction.settings,
    icon: Icons.settings_outlined,
    label: '설정',
    subLabel: '앱 · 위젯 설정',
  ),
  MtfMoreMenuItem(
    value: MyPageMoreMenuAction.passwordChange,
    icon: Icons.password_rounded,
    label: '비밀번호 변경',
    subLabel: '계정 보안 관리',
  ),
];

class MyPage extends StatefulWidget {
  const MyPage({super.key, this.personalOwnerUid});

  final String? personalOwnerUid;

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final _formKey = GlobalKey<FormState>();
  final _contentScrollController = ScrollController();
  final MyPageDraftStore _draftStore = const MyPageDraftStore();

  final _nameController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _gymNameController = TextEditingController();
  final _centerLocationController = TextEditingController();
  final _activityAreaController = TextEditingController();
  final _positionController = TextEditingController();
  final _birthController = TextEditingController();
  final _phoneController = TextEditingController();
  final _introController = TextEditingController();
  final _lessonSpecialtyController = TextEditingController();
  final _contractTrainerCustomNameController = TextEditingController();
  String? _affiliationType;
  final List<String> _selectedActivityRegions = <String>[];
  bool _optionalJobTitleExpanded = false;
  bool _optionalCenterFieldsExpanded = false;
  final _englishNameFieldKey = GlobalKey();
  final _realNameFocusNode = FocusNode();
  final _nicknameFocusNode = FocusNode();
  String _loadedNickname = '';
  String _loadedRealName = '';
  String _loadedJobTitle = '';

  String _gender = 'unset';
  // ✅ UX 개선: 라디오 그룹으로 변경 (realName / displayName / manual)
  String _contractTrainerNameSource = 'manual';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDirty = false;
  bool _isExitSheetShowing = false;
  bool _isBusinessConnectionChecking = false;
  bool _profileLoadFailed = false;
  bool _isApplyingProfileValues = false;
  Map<String, dynamic> _initialProfileValues = const {};
  bool _isHeaderCardExpanded = false;

  // bool _trainerMatchingConsent = false;
  // DateTime? _trainerMatchingConsentAt;

  //향후 MORE 매칭 참여
  //강사님의 프로필을 필요한 수강생에게 소개...

  //마이페이지 첫 진입 시 1회
  //→ 모어댄 서비스 이용 안내
  // → 이용약관 동의
  //→ 개인정보 처리방침 동의

  bool _didShowAiFcProfileNudge = false;
  String get _aiFcProfileNudgeStepKey =>
      myPageNudgePreferenceKey(widget.personalOwnerUid);

  String _currentTierName = 'Beginner';
  String _nextTierName = 'Amateur';
  String _tierMessage = '첫 레슨과 첫 회원을 등록하면 Amateur로 올라갈 수 있어요.';
  int _memberCountForTier = 0;
  int _lessonCountForTier = 0;
  bool _isTierLoading = true;
  bool _isSponsor = false;
  bool _hasProduct = false;
  bool _accountLinkedForTier = false;
  bool _teacherInfoCompletedForTier = false;
  bool _moreBusinessLinked = false;
  String _moreBusinessCompanyId = '';
  String _moreBusinessCompanyName = '';

  bool get _isPersonalWorkspace =>
      (widget.personalOwnerUid ?? '').trim().isNotEmpty;

  bool get _beginnerMissionEarned =>
      _resolveAppTier(_currentTierName).index >= AppTier.amateur.index;

  bool get _displayTrainerInfoDone =>
      _beginnerMissionEarned || _teacherInfoCompletedForTier;

  DocumentReference<Map<String, dynamic>> get _profileRef =>
      FirebaseFirestore.instance.doc(
        myPageProfileDocumentPath(widget.personalOwnerUid),
      );

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadTierStatus();

    for (final c in [
      _nameController,
      _displayNameController,
      _gymNameController,
      _centerLocationController,
      _activityAreaController,
      _positionController,
      _lessonSpecialtyController,
      _contractTrainerCustomNameController,
      _birthController,
      _phoneController,
      _introController,
      _nameEnController,
    ]) {
      c.addListener(_handleProfileInputChanged);
    }
  }

  @override
  void dispose() {
    AifcInteraction.hideToast();

    for (final c in [
      _nameController,
      _displayNameController,
      _gymNameController,
      _centerLocationController,
      _activityAreaController,
      _positionController,
      _lessonSpecialtyController,
      _contractTrainerCustomNameController,
      _birthController,
      _phoneController,
      _introController,
      _nameEnController,
    ]) {
      c.removeListener(_handleProfileInputChanged);
      c.dispose();
    }
    _realNameFocusNode.dispose();
    _nicknameFocusNode.dispose();
    _contentScrollController.dispose();

    super.dispose();
  }

  Map<String, dynamic> _currentProfileValues() => <String, dynamic>{
        'realName': _nameController.text,
        'nameEn': _nameEnController.text,
        'nickname': _displayNameController.text,
        'gymName': _gymNameController.text,
        'centerLocation': _centerLocationController.text,
        'activityArea': _activityAreaController.text,
        'activityRegions': List<String>.from(_selectedActivityRegions),
        'jobTitle': _positionController.text,
        'birth': _birthController.text,
        'phone': _phoneController.text,
        'intro': _introController.text,
        'primaryActivity': _lessonSpecialtyController.text,
        'contractTrainerCustomName': _contractTrainerCustomNameController.text,
        'affiliationType': _affiliationType ?? '',
        'gender': _gender,
        'contractTrainerNameSource': _contractTrainerNameSource,
      };

  void _handleProfileInputChanged() {
    if (!mounted) return;
    final changed = changedMyPageDraftFields(
      _initialProfileValues,
      _currentProfileValues(),
    );
    final dirty = !_isApplyingProfileValues && changed.isNotEmpty;
    if (_isDirty != dirty) {
      _isDirty = dirty;
      if (kDebugMode) {
        debugPrint(
          '[MTF_MY_PAGE_DIRTY] dirty=$dirty '
          'changedFields=${changed.toList()..sort()} '
          'keyboardVisible=${MediaQuery.viewInsetsOf(context).bottom > 0}',
        );
      }
    }
    setState(() {});
  }

  // ── 성별 선택 ─────────────────────────────────────────────────────────────
  String _genderLabel(String value) {
    switch (value) {
      case 'male':
        return '남';
      case 'female':
        return '여';
      case 'unset':
      default:
        return '설정 안 함';
    }
  }

  Future<void> _openGenderSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        Widget option({
          required String value,
          required String label,
          required IconData icon,
        }) {
          final active = _gender == value;

          return InkWell(
            onTap: () => Navigator.of(sheetContext).pop(value),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color:
                    active ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active ? kMyPrimary : kMyBorder,
                  width: active ? 1.3 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    color: active ? kMyPrimary : kMyMuted,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: active ? kMyPrimary : kMyText,
                        fontSize: 13.5,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (active)
                    const Icon(
                      Icons.check_rounded,
                      color: kMyPrimary,
                      size: 20,
                    ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '성별 선택',
                      style: TextStyle(
                        color: kMyText,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  option(
                    value: 'unset',
                    label: '설정 안 함',
                    icon: Icons.remove_circle_outline_rounded,
                  ),
                  const SizedBox(height: 8),
                  option(
                    value: 'male',
                    label: '남',
                    icon: Icons.male_rounded,
                  ),
                  const SizedBox(height: 8),
                  option(
                    value: 'female',
                    label: '여',
                    icon: Icons.female_rounded,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected == null) return;
    if (!mounted) return;

    setState(() {
      _gender = selected;
    });
    _handleProfileInputChanged();
  }

  Widget _buildGenderPickerField() {
    return InkWell(
      onTap: _openGenderSheet,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '성별',
          floatingLabelBehavior: FloatingLabelBehavior.always,
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kMyBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kMyBorder),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _genderLabel(_gender),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kMyText,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: kMyMuted,
            ),
          ],
        ),
      ),
    );
  }

  // ── 네비게이션 ────────────────────────────────────────────────────────────
  void _openSettingsPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPage(
          personalOwnerUid: widget.personalOwnerUid,
        ),
      ),
    );
  }

  void _openPasswordChangePage() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PasswordChangePage()),
    );
  }

  void _openContractListPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContractListPage(
          personalOwnerUid:
              _isPersonalWorkspace ? widget.personalOwnerUid!.trim() : null,
        ),
      ),
    );
  }

  Future<void> _openStatsPage() async {
    if (_isPersonalWorkspace) {
      try {
        final allowed = await AifcTierFeatureGateSheet.guard(
          context: context,
          access: null,
          feature: AppTierFeatureKey.lessonInsights,
          loadAccess: () => AppTierAccessService.loadPersonalTrainerAccess(
            uid: widget.personalOwnerUid!.trim(),
          ),
          entryPoint: 'my_page_lesson_insights',
        );
        if (!allowed || !mounted) return;
      } catch (_) {
        if (!mounted) return;
        _showSnack('등급 정보를 확인하지 못했어요.');
        return;
      }
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StatsPage(
          personalOwnerUid: widget.personalOwnerUid,
        ),
      ),
    );
  }

  Future<void> _openMoreBusinessPage() async {
    if (_isBusinessConnectionChecking) return;
    _isBusinessConnectionChecking = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Text('잠시만 기다려주세요.\n연결할 플레이스를 찾고 있어요.'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (_profileLoadFailed) {
      if (kDebugMode) {
        debugPrint(
          '[MTF_BUSINESS_CONNECTION] requestCount=unknown result=error action=stay',
        );
      }
      await AifcInfoChatSheet.show(
        context: context,
        title: '연결 상태를 확인하지 못했어요.',
        message: '잠시 후 다시 확인해주세요.',
      );
    } else if (_moreBusinessLinked) {
      if (kDebugMode) {
        debugPrint(
          '[MTF_BUSINESS_CONNECTION] requestCount=1 result=connected action=open',
        );
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MoreCareAdminPage(
            isBusinessOwner: _isMoreBusinessOwnerTier,
            isCompanyLinked: true,
            companyName: _moreBusinessCompanyName,
          ),
        ),
      );
    } else {
      if (kDebugMode) {
        debugPrint(
          '[MTF_BUSINESS_CONNECTION] requestCount=0 result=empty action=stay',
        );
      }
      await AifcInfoChatSheet.show(
        context: context,
        title: '아직 연결 요청이 도착한 플레이스가 없네요.',
        message: '연결 요청이 생기면 여기에서 알려드릴게요.',
      );
    }
    _isBusinessConnectionChecking = false;
  }

  void _handleMyPageMoreMenuSelected(MyPageMoreMenuAction action) {
    switch (action) {
      case MyPageMoreMenuAction.stats:
        unawaited(_openStatsPage());
        break;
      case MyPageMoreMenuAction.contracts:
        _openContractListPage();
        break;
      case MyPageMoreMenuAction.settings:
        _openSettingsPage();
        break;
      case MyPageMoreMenuAction.passwordChange:
        _openPasswordChangePage();
        break;
    }
  }

  // ── Firestore 로드 ────────────────────────────────────────────────────────
  Future<void> _loadProfile() async {
    try {
      final doc = await _profileRef.get();

      final data = doc.data();
      if (kDebugMode) {
        const profileFields = <String>[
          'nickname',
          'displayName',
          'name',
          'phone',
          'activityRegion',
          'primaryActivity',
          'affiliationType',
          'profileImageUrl',
          'contractTrainerName',
        ];
        final presentFields =
            profileFields.where((field) => data?[field] != null).join(',');
        debugPrint(
          '[MTF_MY_PAGE_IDENTITY] uid=${widget.personalOwnerUid ?? 'legacy'} '
          'personal=$_isPersonalWorkspace profileExists=${doc.exists} '
          'profileSource=${myPageProfileDocumentPath(widget.personalOwnerUid)} '
          'presentFields=$presentFields',
        );
      }
      if (data != null) {
        _isApplyingProfileValues = true;
        _nameController.text = myPageRealNameFromProfile(
          data,
          personalWorkspace: _isPersonalWorkspace,
        );
        _nameEnController.text =
            normalizeTrainerEnglishName((data['nameEn'] ?? '').toString());
        _displayNameController.text = myPageNicknameFromProfile(
          data,
          personalWorkspace: _isPersonalWorkspace,
        );
        _loadedNickname = _displayNameController.text.trim();
        _loadedRealName = _nameController.text.trim();
        _gymNameController.text = (data['gymName'] ?? '').toString();
        _centerLocationController.text =
            (data['centerLocation'] ?? data['activityArea'] ?? '').toString();
        _selectedActivityRegions
          ..clear()
          ..addAll(normalizeTrainerActivityRegions(
            data['activityRegions'],
            legacyActivityRegion: data['activityRegion']?.toString(),
          ));
        _activityAreaController.text = _selectedActivityRegions.isEmpty
            ? ''
            : _selectedActivityRegions.first;
        _positionController.text = myPageJobTitleFromProfile(
          data,
          personalWorkspace: _isPersonalWorkspace,
        );
        _loadedJobTitle = _positionController.text.trim();
        _birthController.text = (data['birth'] ?? '').toString();
        _phoneController.text = (data['phone'] ?? '').toString();
        final loadedAffiliation = (data['affiliationType'] ?? '').toString();
        _affiliationType = isTrainerAffiliationType(loadedAffiliation)
            ? loadedAffiliation
            : null;
        _optionalJobTitleExpanded = _positionController.text.trim().isNotEmpty;
        _optionalCenterFieldsExpanded =
            _gymNameController.text.trim().isNotEmpty ||
                _centerLocationController.text.trim().isNotEmpty;
        _introController.text = (data['intro'] ?? '').toString();
        _lessonSpecialtyController.text = myPageLessonFieldsFromProfile(
          data,
          personalWorkspace: _isPersonalWorkspace,
        );

        _contractTrainerNameSource = myPageContractNameSourceFromProfile(data);
        final rawContractSource =
            (data['contractTrainerNameSource'] ?? '').toString().trim();
        final profileReadSource = _isPersonalWorkspace
            ? (_myPageContractNameSources.contains(rawContractSource)
                ? 'firestore'
                : 'default')
            : 'legacy';
        _contractTrainerCustomNameController.text =
            myPageContractCustomNameFromProfile(
          data,
          source: _contractTrainerNameSource,
        );
        _gender = (data['gender'] ?? 'unset').toString();

        _moreBusinessCompanyId = (data['moreBusinessCompanyId'] ??
                data['businessCompanyId'] ??
                data['companyId'] ??
                '')
            .toString()
            .trim();

        _moreBusinessCompanyName = (data['moreBusinessCompanyName'] ??
                data['businessCompanyName'] ??
                data['companyName'] ??
                '')
            .toString()
            .trim();

        _moreBusinessLinked = data['moreBusinessLinked'] == true ||
            _moreBusinessCompanyId.isNotEmpty;

        // _trainerMatchingConsent =
        //    data['trainerMatchingConsent'] == true;

        // final rawTrainerMatchingConsentAt =
        //data['trainerMatchingConsentAt'];
//
        // if (rawTrainerMatchingConsentAt is Timestamp) {
        //   _trainerMatchingConsentAt = rawTrainerMatchingConsentAt.toDate();
        //  } else if (rawTrainerMatchingConsentAt is DateTime) {
        //   _trainerMatchingConsentAt = rawTrainerMatchingConsentAt;
        // } else if (rawTrainerMatchingConsentAt is String &&
        //     rawTrainerMatchingConsentAt.trim().isNotEmpty) {
        //   _trainerMatchingConsentAt =
        //       DateTime.tryParse(rawTrainerMatchingConsentAt.trim());
        // } else {
        //   _trainerMatchingConsentAt = null;
        //  }

        if (!['unset', 'male', 'female'].contains(_gender)) _gender = 'unset';

        final cachedTier = parsePersonalTierLabel(data['tier']);
        if (_isPersonalWorkspace && cachedTier != null) {
          _currentTierName = cachedTier;
        }

        _initialProfileValues = normalizeMyPageDraft(_currentProfileValues());
        _isApplyingProfileValues = false;
        _isDirty = false;

        if (kDebugMode) {
          final lessonFieldsCount =
              _lessonSpecialtyController.text.trim().isEmpty ? 0 : 1;
          debugPrint(
            '[MTF_MY_PAGE_PROFILE_READ] '
            'uid=${widget.personalOwnerUid ?? 'legacy'} '
            'environment=${AppEnvironmentConfig.environmentName} '
            'documentPath=${myPageProfileDocumentPath(widget.personalOwnerUid)} '
            'nicknamePresent=${_displayNameController.text.trim().isNotEmpty} '
            'realNamePresent=${_nameController.text.trim().isNotEmpty} '
            'jobTitlePresent=${_positionController.text.trim().isNotEmpty} '
            'lessonFieldsCount=$lessonFieldsCount '
            'contractSource=$_contractTrainerNameSource '
            'source=$profileReadSource',
          );
        }
      }
    } catch (e) {
      _isApplyingProfileValues = false;
      _profileLoadFailed = true;
      if (!mounted) return;
      _showSnack(
          _isNetworkFailure(e) ? '인터넷 연결을 확인해주세요.' : '내 정보 불러오기에 실패했어요.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final profileValid = _formKey.currentState?.validate() ?? true;
          if (!profileValid) {
            _showSnack('선생님 정보 중 확인이 필요한 항목이 있어요.');
          } else {
            _maybeShowAiFcProfileNudge();
          }
          unawaited(_offerDraftRestore());
        });
      }
    }
  }

  bool _isNetworkFailure(Object error) {
    final code = managedMemberSafeErrorCode(error).toLowerCase();
    final message = error.toString().toLowerCase();
    return code == 'unavailable' ||
        code == 'deadline-exceeded' ||
        code == 'network-request-failed' ||
        message.contains('unknownhost') ||
        message.contains('unable to resolve host') ||
        message.contains('network');
  }

  Future<void> _offerDraftRestore() async {
    if (!_isPersonalWorkspace || _isDirty || _isExitSheetShowing) return;
    final uid = widget.personalOwnerUid!.trim();
    final draft = await _draftStore.load(uid: uid);
    if (!mounted || draft == null) return;
    _isExitSheetShowing = true;
    final restore = await AifcConfirmChatSheet.show(
      context: context,
      title: '임시 보관한 내용을 이어서 작성할까요?',
      message: '이 기기에 보관한 선생님 내 정보 초안이 있어요.',
      confirmText: '복원하기',
      cancelText: '삭제하기',
    );
    _isExitSheetShowing = false;
    if (!mounted) return;
    if (restore == true) {
      _applyProfileValues(draft);
      if (kDebugMode) {
        debugPrint(
          '[MTF_MY_PAGE_DRAFT] environment=${AppEnvironmentConfig.environmentName} '
          'uidScoped=true action=restore fieldCount=${draft.length} result=success',
        );
      }
    } else {
      await _draftStore.clear(uid: uid);
      if (kDebugMode) {
        debugPrint(
          '[MTF_MY_PAGE_DRAFT] environment=${AppEnvironmentConfig.environmentName} '
          'uidScoped=true action=discard fieldCount=${draft.length} result=success',
        );
      }
    }
  }

  void _applyProfileValues(Map<String, dynamic> values) {
    _isApplyingProfileValues = true;
    _nameController.text = (values['realName'] ?? '').toString();
    _nameEnController.text = (values['nameEn'] ?? '').toString();
    _displayNameController.text = (values['nickname'] ?? '').toString();
    _gymNameController.text = (values['gymName'] ?? '').toString();
    _centerLocationController.text =
        (values['centerLocation'] ?? '').toString();
    _activityAreaController.text = (values['activityArea'] ?? '').toString();
    _positionController.text = (values['jobTitle'] ?? '').toString();
    _birthController.text = (values['birth'] ?? '').toString();
    _phoneController.text = (values['phone'] ?? '').toString();
    _introController.text = (values['intro'] ?? '').toString();
    _lessonSpecialtyController.text =
        (values['primaryActivity'] ?? '').toString();
    _contractTrainerCustomNameController.text =
        (values['contractTrainerCustomName'] ?? '').toString();
    _affiliationType = (values['affiliationType'] ?? '').toString().trim();
    if (_affiliationType!.isEmpty) _affiliationType = null;
    _selectedActivityRegions
      ..clear()
      ..addAll(normalizeTrainerActivityRegions(
        values['activityRegions'],
        legacyActivityRegion: values['activityArea']?.toString(),
      ));
    _activityAreaController.text =
        _selectedActivityRegions.isEmpty ? '' : _selectedActivityRegions.first;
    _optionalJobTitleExpanded = _positionController.text.trim().isNotEmpty;
    _optionalCenterFieldsExpanded = _gymNameController.text.trim().isNotEmpty ||
        _centerLocationController.text.trim().isNotEmpty;
    _gender = (values['gender'] ?? 'unset').toString();
    _contractTrainerNameSource =
        (values['contractTrainerNameSource'] ?? 'manual').toString();
    _isApplyingProfileValues = false;
    _handleProfileInputChanged();
  }

  Future<void> _loadTierStatus() async {
    try {
      if (_isPersonalWorkspace) {
        final snapshot = await _profileRef.get(
          const GetOptions(source: Source.server),
        );
        final profile = snapshot.data() ?? const {};
        final tier = parsePersonalTierLabel(profile['tier']);
        if (!snapshot.exists || tier == null) {
          throw StateError('personal_tier_unavailable');
        }
        if (kDebugMode) {
          debugPrint(
            '[MTF_TIER_READ] uid=${widget.personalOwnerUid!.trim()} '
            'environment=${AppEnvironmentConfig.environmentName} '
            'profileExists=${snapshot.exists} '
            'source=${myPageProfileDocumentPath(widget.personalOwnerUid)} '
            'rawTier=${(profile['tier'] ?? '').toString()} parsedTier=$tier '
            'result=success errorCode=none',
          );
        }
        final progress = PersonalTierProgress.fromProfile(profile);
        if (kDebugMode) {
          debugPrint(progress.debugLog(source: 'myPage'));
        }
        final memberCount = ((profile['validMemberCount'] ??
                profile['lifetimeQualifiedMemberCount'] ??
                0) as num)
            .toInt();
        if (!mounted) return;
        setState(() {
          _memberCountForTier = memberCount;
          _lessonCountForTier = progress.scheduleCount;
          _currentTierName = tier;
          _nextTierName = _resolveNextTierName(tier);
          _isSponsor = false;
          _accountLinkedForTier = profile['accountLinked'] == true;
          _teacherInfoCompletedForTier = progress.teacherInfoCompleted;
          _hasProduct = false;
          _tierMessage = _buildTierMessage(
            tier: tier,
            nextTier: _nextTierName,
            memberCount: memberCount,
            lessonCount: _lessonCountForTier,
            profileCompleted: progress.teacherInfoCompleted,
            kakaoLinked: false,
            kakaoCardLinkedMemberCount: 0,
            contractSignedMemberCount: 0,
          );
          _isTierLoading = false;
        });
        return;
      }
      final tierAccess = await AppTierAccessService.loadTrainerAccess();

      final schedulesSnap = await FirebaseFirestore.instance
          .collection('schedules')
          .limit(300)
          .get();

      final productsSnap = await FirebaseFirestore.instance
          .collection('lesson_products')
          .limit(20)
          .get();

      final hasProduct = productsSnap.docs.any((doc) {
        final data = doc.data();
        return data['isDeleted'] != true;
      });

      final lessonCount = schedulesSnap.docs.length;
      final tier = tierAccess.tierLabel;
      final nextTier = _resolveNextTierName(tier);

      if (!mounted) return;

      setState(() {
        _memberCountForTier = tierAccess.activeMemberCount;
        _lessonCountForTier = lessonCount;
        _currentTierName = tier;
        _nextTierName = nextTier;
        _isSponsor = tierAccess.isSponsor;
        _accountLinkedForTier = tierAccess.kakaoLinked;
        _hasProduct = hasProduct;
        _tierMessage = _buildTierMessage(
          tier: tier,
          nextTier: nextTier,
          memberCount: tierAccess.activeMemberCount,
          lessonCount: lessonCount,
          profileCompleted: tierAccess.profileCompleted,
          kakaoLinked: tierAccess.kakaoLinked,
          kakaoCardLinkedMemberCount: tierAccess.kakaoCardLinkedMemberCount,
          contractSignedMemberCount: tierAccess.contractSignedMemberCount,
        );
        _isTierLoading = false;
      });
    } catch (e) {
      if (kDebugMode && _isPersonalWorkspace) {
        final code = e is FirebaseException ? e.code : e.runtimeType.toString();
        debugPrint(
          '[MTF_TIER_READ] uid=${widget.personalOwnerUid!.trim()} '
          'environment=${AppEnvironmentConfig.environmentName} '
          'profileExists=unknown '
          'source=${myPageProfileDocumentPath(widget.personalOwnerUid)} '
          'rawTier=unknown parsedTier=none result=failure errorCode=$code',
        );
      }

      if (!mounted) return;

      setState(() {
        _currentTierName = '확인 실패';
        _tierMessage = '등급 정보를 불러오지 못했어요. 잠시 후 다시 확인해주세요.';
        _isTierLoading = false;
      });
    }
  }

  String _resolveNextTierName(String tier) {
    switch (tier) {
      case 'Beginner':
        return 'Amateur';
      case 'Amateur':
        return 'Semi-Pro';
      case 'Semi-Pro':
        return 'Pro';
      case 'Pro':
        return 'Master';
      case 'Master':
        return 'Grand Prix';
      default:
        return 'Grand Prix';
    }
  }

  AppTier _resolveAppTier(String tier) {
    switch (tier) {
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

  int _tierRank(String tier) {
    switch (tier) {
      case 'Beginner':
        return 0;
      case 'Amateur':
        return 1;
      case 'Semi-Pro':
        return 2;
      case 'Pro':
        return 3;
      case 'Master':
        return 4;
      case 'Grand Prix':
        return 5;
      default:
        return 0;
    }
  }

  bool get _isMoreBusinessOwnerTier {
    return _tierRank(_currentTierName) >= _tierRank('Master');
  }

  String get _moreBusinessStatusLabel {
    if (_isMoreBusinessOwnerTier) return '운영';
    return _moreBusinessLinked ? '연결됨' : '연결 안 됨';
  }

  IconData get _moreBusinessIcon {
    if (_isMoreBusinessOwnerTier) {
      return Icons.business_center_rounded;
    }

    return Icons.handshake_outlined;
  }

  IconData get _moreBusinessStatusIcon {
    if (_isMoreBusinessOwnerTier) {
      return Icons.apartment_rounded;
    }

    return _moreBusinessLinked ? Icons.link_rounded : Icons.link_off_rounded;
  }

  Color get _moreBusinessStatusColor {
    if (_isMoreBusinessOwnerTier) return kMyPrimary;
    return _moreBusinessLinked
        ? const Color(0xFF059669)
        : const Color(0xFFF97316);
  }

  bool get _canUseBusinessCardFeature {
    return _tierRank(_currentTierName) >= _tierRank('Semi-Pro');
  }

  Future<bool> _guardBusinessCardFeature() async {
    if (_canUseBusinessCardFeature) {
      return true;
    }

    _showActionToast(
      '명함 보기와 공유는 Semi-Pro부터 사용할 수 있어요.',
      bottomOffset: 110,
    );

    await Future.delayed(const Duration(milliseconds: 220));

    if (!mounted) return false;

    await _openUpgradeChatSheet();

    return false;
  }

  String _buildTierMessage({
    required String tier,
    required String nextTier,
    required int memberCount,
    required int lessonCount,
    bool profileCompleted = false,
    bool kakaoLinked = false,
    int kakaoCardLinkedMemberCount = 0,
    int contractSignedMemberCount = 0,
  }) {
    switch (tier) {
      case 'Beginner':
        return '레슨 일정 10개와 선생님 정보 입력을 완료하면 Amateur로 올라갈 수 있어요.';

      case 'Amateur':
        return '기본 관리 흐름이 열렸어요. 활성 회원 30명 또는 카카오+고객카드 연동 20명부터 Semi-Pro로 올라가요.';

      case 'Semi-Pro':
        return '계약서와 레슨일지 기반 관리 기능을 사용할 수 있어요. 활성 회원 50명, 카카오+고객카드 연동 40명, 계약서 20명부터 Pro 흐름이 열려요.';

      case 'Pro':
        return '고급 인사이트와 자동화까지 더 넓게 사용할 수 있어요. 이제 프로다운 관리 흐름에 가까워졌어요.';

      case 'Master':
        return '센터 단위 관리가 어울리는 단계예요. 조직 결제 플랜은 다음 단계에서 연결할게요.';

      case 'Grand Prix':
        return '다수 지점 관리까지 바라볼 수 있는 최상위 운영 단계예요. 조직 결제 플랜은 다음 단계에서 연결할게요.';

      default:
        return '$nextTier 단계까지 저 AI FC가 함께 도와드릴게요.';
    }
  }

  // ── 저장 ──────────────────────────────────────────────────────────────────
  Future<bool> _prepareNamesForSave() async {
    final nickname = _displayNameController.text.trim();
    final realName = _nameController.text.trim();
    if (nickname.length > 6) {
      _showSnack('모어댄이 부를 짧은 닉네임을 6자 이내로 입력해주세요.');
      _nicknameFocusNode.requestFocus();
      return false;
    }

    switch (resolveMyPageNameSaveAction(
      nickname: nickname,
      realName: realName,
    )) {
      case MyPageNameSaveAction.requireName:
        _showSnack('닉네임 또는 실명 중 하나는 입력해주세요.');
        _nicknameFocusNode.requestFocus();
        return false;
      case MyPageNameSaveAction.save:
        return true;
      case MyPageNameSaveAction.confirmRealName:
        final choice = await showModalBottomSheet<_RealNameNicknameChoice>(
          context: context,
          isScrollControlled: true,
          builder: (sheetContext) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '모어댄이 부를 이름이 필요해요.\n입력한 실명을 닉네임으로 사용할까요?',
                    style: TextStyle(
                      color: kMyText,
                      fontSize: 17,
                      height: 1.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    key: const Key('my_page_use_real_name_as_nickname'),
                    title: const Text('실명으로 사용할게요'),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      _RealNameNicknameChoice.useRealName,
                    ),
                  ),
                  ListTile(
                    key: const Key('my_page_enter_nickname'),
                    title: const Text('닉네임 입력하기'),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      _RealNameNicknameChoice.enterNickname,
                    ),
                  ),
                  ListTile(
                    key: const Key('my_page_cancel_name_save'),
                    title: const Text('취소'),
                    onTap: () => Navigator.pop(
                      sheetContext,
                      _RealNameNicknameChoice.cancel,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        if (!mounted) return false;
        if (choice == _RealNameNicknameChoice.enterNickname) {
          _nicknameFocusNode.requestFocus();
          return false;
        }
        if (choice != _RealNameNicknameChoice.useRealName) return false;
        if (!canUseRealNameAsNickname(realName)) {
          _showSnack('모어댄이 부를 짧은 닉네임을 6자 이내로 입력해주세요.');
          _nicknameFocusNode.requestFocus();
          return false;
        }
        _displayNameController.text = realName;
        return true;
    }
  }

  Future<bool> _saveProfile() async {
    if (_isSaving) return false;
    if (!await _prepareNamesForSave()) return false;
    final contractNameError = myPageContractNameValidationMessage(
      source: _contractTrainerNameSource,
      nickname: _displayNameController.text,
      realName: _nameController.text,
      customName: _contractTrainerCustomNameController.text,
    );
    if (contractNameError != null) {
      _showSnack(contractNameError);
      return false;
    }
    _logPersonalProfileValidation();
    if (!_formKey.currentState!.validate()) {
      await _scrollToFirstInvalidProfileField();
      return false;
    }
    setState(() => _isSaving = true);
    var activeSaveStep = 'validation';

    try {
      final name = _nameController.text.trim();
      final nameEn = normalizeTrainerEnglishName(_nameEnController.text);
      _nameEnController.text = nameEn;
      final displayName = _displayNameController.text.trim();
      final gymName = _gymNameController.text.trim();
      final activityArea = _activityAreaController.text.trim();
      final position = _positionController.text.trim();
      var birth = _birthController.text.trim();
      final birthResult = normalizeAndValidateMemberBirthDate(
        birth,
        required: false,
      );
      if (birthResult.isValid) {
        birth = birthResult.normalizedText ?? '';
        _birthController.text = birth;
      }
      final phone = _normalizePhone(_phoneController.text);
      final intro = _introController.text.trim();
      final lessonSpecialty = _lessonSpecialtyController.text.trim();
      final contractCustomName =
          _contractTrainerCustomNameController.text.trim();
      final affiliationType = (_affiliationType ?? '').trim();
      final activityRegions = normalizeTrainerActivityRegions(
        _selectedActivityRegions,
      );
      final primaryActivityRegion =
          activityRegions.isEmpty ? '' : activityRegions.first;
      _activityAreaController.text = primaryActivityRegion;
      final contractTrainerName = switch (_contractTrainerNameSource) {
        'realName' => name,
        'displayName' => displayName,
        _ => contractCustomName,
      };

      if (kDebugMode && _isPersonalWorkspace) {
        debugPrint(
          '[MTF_MY_PAGE_SAVE_START] uid=${widget.personalOwnerUid!.trim()} '
          'environment=${AppEnvironmentConfig.environmentName} '
          'nicknameChanged=${displayName != _loadedNickname} '
          'realNameChanged=${name != _loadedRealName} '
          'jobTitleChanged=${position != _loadedJobTitle}',
        );
      }

      final shortName =
          _buildShortName(displayName.isNotEmpty ? displayName : name);

      final updateData = <String, dynamic>{
        'name': name,
        'nameEn': nameEn,
        'displayName': displayName,
        'gymName': gymName,
        'activityArea': activityArea,
        'position': position,
        'lessonSpecialty': lessonSpecialty,
        'gender': _gender,
        'birth': birth,
        'phone': phone,
        'intro': intro,
        'shortName': shortName,
        'useRealNameForContract': _contractTrainerNameSource == 'realName',
        'contractTrainerNameSource': _contractTrainerNameSource,
        'contractTrainerCustomName': contractCustomName,
        'contractTrainerName': contractTrainerName,
        'updatedAt': FieldValue.serverTimestamp(),

        // 'trainerMatchingConsent': _trainerMatchingConsent,
        //  'trainerMatchingConsentVersion': 1,
        // 'trainerMatchingConsentUpdatedAt': FieldValue.serverTimestamp(),
      };

      updateData.addAll(_buildProfileCompletionPatch());

      //if (_trainerMatchingConsent) {
      //   updateData['trainerMatchingConsentAt'] =
      //    _trainerMatchingConsentAt == null
      //      ? FieldValue.serverTimestamp()
      //       : Timestamp.fromDate(_trainerMatchingConsentAt!);
      // } else {
      //    updateData['trainerMatchingConsentAt'] = FieldValue.delete();
      //  }

      if (_isPersonalWorkspace) {
        final uid = widget.personalOwnerUid!.trim();
        activeSaveStep = 'profile';
        if (kDebugMode) {
          debugPrint(
            '[MTF_MY_PAGE_SAVE_STEP] step=profile '
            'function=updatePersonalTrainerProfile result=start errorCode=none',
          );
        }
        await FirebaseManagedMemberWorkspaceGateway(uid: uid)
            .updateTrainerProfile(
          displayName: name.isNotEmpty ? name : displayName,
          nickname: displayName,
          realName: name,
          jobTitle: position,
          phone: phone,
          birth: birth,
          activityRegion: primaryActivityRegion,
          activityRegions: activityRegions,
          primaryActivity: lessonSpecialty,
          affiliationType: affiliationType,
          nameEn: nameEn,
          gymName: gymName,
          centerLocation: _centerLocationController.text.trim(),
          contractTrainerNameSource: _contractTrainerNameSource,
          contractTrainerCustomName: contractCustomName,
        );
        try {
          await FirebaseManagedMemberWorkspaceGateway(uid: uid)
              .reconcilePersonalTier();
        } catch (error) {
          if (kDebugMode) {
            debugPrint(
              '[MTF_TIER_RECONCILE] '
              'environment=${AppEnvironmentConfig.environmentName} '
              'currentTier=unknown scheduleCount=unknown scheduleGoal=10 '
              'scheduleMissionCompleted=false teacherInfoCompleted=false '
              'completedMissionCount=unknown eligible=false action=skip '
              'result=failure errorCode=${managedMemberSafeErrorCode(error)}',
            );
          }
        }
        if (kDebugMode) {
          debugPrint(
            '[MTF_MY_PAGE_SAVE_STEP] step=profile '
            'function=updatePersonalTrainerProfile result=success '
            'errorCode=none',
          );
        }
        activeSaveStep = 'reload';
        final confirmed = await _profileRef.get(
          const GetOptions(source: Source.server),
        );
        final confirmedData = confirmed.data() ?? const <String, dynamic>{};
        final confirmedNickname =
            (confirmedData['nickname'] ?? '').toString().trim();
        final confirmedRealName =
            (confirmedData['realName'] ?? '').toString().trim();
        final confirmedJobTitle =
            (confirmedData['jobTitle'] ?? '').toString().trim();
        final confirmedLessonFields =
            (confirmedData['primaryActivity'] ?? '').toString().trim();
        final confirmedNameEn =
            (confirmedData['nameEn'] ?? '').toString().trim();
        final confirmedRegions = normalizeTrainerActivityRegions(
          confirmedData['activityRegions'],
          legacyActivityRegion: confirmedData['activityRegion']?.toString(),
        );
        final confirmedContractSource =
            (confirmedData['contractTrainerNameSource'] ?? '')
                .toString()
                .trim();
        final confirmedContractCustomName =
            (confirmedData['contractTrainerCustomName'] ?? '')
                .toString()
                .trim();
        final nicknameMatched = confirmedNickname == displayName;
        final realNameMatched = confirmedRealName == name;
        final jobTitleMatched = confirmedJobTitle == position;
        final lessonFieldsMatched = confirmedLessonFields == lessonSpecialty;
        final nameEnMatched = confirmedNameEn == nameEn;
        final activityRegionsMatched = listEquals(
          confirmedRegions,
          activityRegions,
        );
        final contractSourceMatched =
            confirmedContractSource == _contractTrainerNameSource &&
                confirmedContractCustomName == contractCustomName;
        if (kDebugMode) {
          debugPrint(
            '[MTF_MY_PAGE_PROFILE_RELOAD] uid=$uid '
            'nicknameMatched=$nicknameMatched '
            'realNameMatched=$realNameMatched '
            'jobTitleMatched=$jobTitleMatched '
            'lessonFieldsMatched=$lessonFieldsMatched '
            'nameEnMatched=$nameEnMatched '
            'activityRegionsMatched=$activityRegionsMatched '
            'contractSourceMatched=$contractSourceMatched',
          );
        }
        if (!confirmed.exists ||
            !nicknameMatched ||
            !realNameMatched ||
            !jobTitleMatched ||
            !lessonFieldsMatched ||
            !nameEnMatched ||
            !activityRegionsMatched ||
            !contractSourceMatched) {
          throw StateError('personal_profile_refresh_failed');
        }
        _loadedNickname = confirmedNickname;
        _loadedRealName = name;
        _loadedJobTitle = position;
        if (kDebugMode) {
          debugPrint(
            '[MTF_MY_PAGE_PROFILE_SAVE] uid=$uid '
            'fields=nickname,realName,jobTitle,lessonFields,contractSource '
            'contractSource=$_contractTrainerNameSource '
            'result=success errorCode=none',
          );
          debugPrint(
            '[MTF_MY_PAGE_SAVE_STEP] step=reload function=profileServerRead '
            'result=success errorCode=none',
          );
          debugPrint('[MTF_MY_PAGE_SAVE_DONE] result=success failedStep=none');
        }
        activeSaveStep = 'none';
        await _loadTierStatus();
      } else {
        await _profileRef.set(updateData, SetOptions(merge: true));
      }

      if (!mounted) return false;

      await _resetAiFcProfileNudgeForMissingInfo();

      if (_hasMissingAiFcProfileInfo()) {
        _showSnack('저장했어요. 비어 있는 안내 정보는 다음에 제가 다시 도와드릴게요.');
      } else {
        _showSnack('내 정보를 저장했어요.');
      }
      _initialProfileValues = normalizeMyPageDraft(_currentProfileValues());
      _isDirty = false;
      if (_isPersonalWorkspace) {
        await _draftStore.clear(uid: widget.personalOwnerUid!.trim());
      }
      return true;
    } catch (e) {
      if (kDebugMode && _isPersonalWorkspace) {
        debugPrint(
          '[MTF_MY_PAGE_PROFILE_SAVE] '
          'uid=${widget.personalOwnerUid!.trim()} '
          'fields=nickname,realName,jobTitle,lessonFields,contractSource '
          'contractSource=$_contractTrainerNameSource '
          'result=failure errorCode=${managedMemberSafeErrorCode(e)}',
        );
        debugPrint(
          '[MTF_MY_PAGE_SAVE_DONE] result=failure failedStep=$activeSaveStep '
          'errorCode=${managedMemberSafeErrorCode(e)}',
        );
      }
      if (!mounted) return false;
      if (_isNetworkFailure(e)) {
        _showSnack('인터넷 연결을 확인해주세요.');
        final keepDraft = await AifcConfirmChatSheet.show(
          context: context,
          title: '인터넷 연결을 확인해주세요.',
          message: '입력한 내용은 화면에 그대로 두었어요. 이 기기에 임시로 보관할까요?',
          confirmText: '임시 보관',
          cancelText: '계속 작성',
        );
        if (keepDraft && mounted) await _saveDraft();
      } else {
        _showSnack(managedMemberProfileSaveErrorMessage(e));
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<bool> _saveDraft() async {
    if (!_isPersonalWorkspace) return false;
    final values = normalizeMyPageDraft(_currentProfileValues());
    try {
      await _draftStore.save(
        uid: widget.personalOwnerUid!.trim(),
        values: values,
      );
      if (kDebugMode) {
        debugPrint(
          '[MTF_MY_PAGE_DRAFT] environment=${AppEnvironmentConfig.environmentName} '
          'uidScoped=true action=save fieldCount=${values.length} result=success',
        );
      }
      return true;
    } catch (_) {
      if (kDebugMode) {
        debugPrint(
          '[MTF_MY_PAGE_DRAFT] environment=${AppEnvironmentConfig.environmentName} '
          'uidScoped=true action=save fieldCount=${values.length} result=failure',
        );
      }
      if (mounted) _showSnack('임시 보관하지 못했어요. 입력 내용은 화면에 남아 있어요.');
      return false;
    }
  }

  Future<void> _scrollToFirstInvalidProfileField() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    final formContext = _formKey.currentContext;
    if (formContext == null) return;

    Element? firstInvalidElement;
    double? firstInvalidDy;

    void inspect(Element element) {
      if (element is StatefulElement &&
          element.state is FormFieldState<dynamic>) {
        final state = element.state as FormFieldState<dynamic>;
        final renderObject = element.renderObject;
        if (state.hasError && renderObject is RenderBox) {
          final dy = renderObject.localToGlobal(Offset.zero).dy;
          if (firstInvalidDy == null || dy < firstInvalidDy!) {
            firstInvalidDy = dy;
            firstInvalidElement = element;
          }
        }
      }
      element.visitChildren(inspect);
    }

    formContext.visitChildElements(inspect);
    final invalidContext = firstInvalidElement;
    if (invalidContext == null) return;

    await Scrollable.ensureVisible(
      invalidContext,
      alignment: 0.2,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _requestExit() async {
    if (_isSaving || _isExitSheetShowing) return;
    if (!_isDirty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    _isExitSheetShowing = true;
    final action = await AifcOptionChatSheet.show<_MyPageExitAction>(
      context: context,
      title: '작성한 내용이 아직 저장되지 않았어요.',
      message: '어떻게 할까요?',
      guidanceText: '',
      items: const [
        AifcOptionItem(
          value: _MyPageExitAction.saveExit,
          title: '저장하고 나가기',
          icon: Icons.cloud_done_outlined,
        ),
        AifcOptionItem(
          value: _MyPageExitAction.draftExit,
          title: '임시로 보관하고 나가기',
          icon: Icons.drafts_outlined,
        ),
        AifcOptionItem(
          value: _MyPageExitAction.discard,
          title: '저장하지 않고 나가기',
          icon: Icons.delete_outline_rounded,
        ),
        AifcOptionItem(
          value: _MyPageExitAction.continueEditing,
          title: '계속 작성하기',
          icon: Icons.edit_outlined,
        ),
      ],
    );
    _isExitSheetShowing = false;
    if (!mounted || action == null) return;

    var result = true;
    switch (action) {
      case _MyPageExitAction.saveExit:
        result = await _saveProfile();
        if (result && mounted) Navigator.of(context).pop();
        break;
      case _MyPageExitAction.draftExit:
        result = await _saveDraft();
        if (result && mounted) Navigator.of(context).pop();
        break;
      case _MyPageExitAction.discard:
        if (_isPersonalWorkspace) {
          await _draftStore.clear(uid: widget.personalOwnerUid!.trim());
        }
        if (mounted) Navigator.of(context).pop();
        break;
      case _MyPageExitAction.continueEditing:
        break;
    }
    if (kDebugMode) {
      debugPrint(
        '[MTF_MY_PAGE_EXIT] dirty=true action=${action.name} '
        'result=${result ? 'success' : 'failure'}',
      );
    }
  }

  void _logPersonalProfileValidation() {
    if (!kDebugMode || !_isPersonalWorkspace) return;

    final phoneResult = validateKoreanMobilePhone(
      _phoneController.text,
      required: false,
    );
    final birthResult = normalizeAndValidateMemberBirthDate(
      _birthController.text,
      required: false,
    );
    final results = <String, String?>{
      'realName': validateTrainerRealName(_nameController.text) == null
          ? null
          : 'invalid_format',
      'jobTitle': validateTrainerJobTitleForAffiliation(
                _positionController.text,
                _affiliationType,
              ) ==
              null
          ? null
          : 'invalid_format',
      'primaryActivity':
          validatePrimaryActivity(_lessonSpecialtyController.text) == null
              ? null
              : 'invalid_format',
      'affiliationType': isTrainerAffiliationType(_affiliationType)
          ? null
          : 'invalid_selection',
      'activityRegion': isTrainerActivityRegion(_activityAreaController.text)
          ? null
          : 'invalid_selection',
      'phone': phoneResult.isValid ? null : 'invalid_format',
      'birthDate': birthResult.isValid ? null : 'invalid_date',
      'englishName': validateTrainerEnglishName(_nameEnController.text) == null
          ? null
          : 'invalid_characters',
    };

    for (final entry in results.entries) {
      debugPrint(
        '[MTF_PROFILE_VALIDATION] field=${entry.key} '
        'present=${entry.key == 'englishName' ? _nameEnController.text.trim().isNotEmpty : true} '
        'result=${entry.value == null ? 'valid' : 'invalid'} '
        'errorCode=${entry.value ?? 'none'}',
      );
    }
    final category = trainerAffiliationCategory(_affiliationType);
    debugPrint(
      '[MTF_PROFILE_FIELD_POLICY] '
      'affiliationCategory=${category.name} '
      'jobTitleRequired=${isTrainerJobTitleRequired(_affiliationType)} '
      'centerFieldsVisible=${category == TrainerAffiliationCategory.center || _optionalCenterFieldsExpanded} '
      'centerFieldsExpanded=${category == TrainerAffiliationCategory.center || _optionalCenterFieldsExpanded}',
    );
    debugPrint(
      '[MTF_ACTIVITY_REGIONS] count=${_selectedActivityRegions.length} '
      'primaryPresent=${_selectedActivityRegions.isNotEmpty} '
      'duplicateRejected=false action=save',
    );
  }

  Future<void> _saveSingleProfileField(String key, String value) async {
    if (_isPersonalWorkspace) {
      await FirebaseManagedMemberWorkspaceGateway(
        uid: widget.personalOwnerUid!.trim(),
      ).updateTrainerProfile(
        displayName: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : _displayNameController.text.trim(),
        nickname: _displayNameController.text.trim(),
        realName: _nameController.text.trim(),
        phone: _normalizePhone(_phoneController.text),
        birth: _birthController.text.trim(),
        activityRegion: _activityAreaController.text.trim(),
        activityRegions: List<String>.from(_selectedActivityRegions),
        primaryActivity: _lessonSpecialtyController.text.trim(),
        jobTitle: _positionController.text.trim(),
        affiliationType: _affiliationType,
        nameEn: normalizeTrainerEnglishName(_nameEnController.text),
        gymName: _gymNameController.text.trim(),
        centerLocation: _centerLocationController.text.trim(),
      );
      return;
    }
    final data = <String, dynamic>{
      key: value.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (key == 'name' && _contractTrainerNameSource == 'realName') {
      data['contractTrainerName'] = value.trim();
    }

    if (key == 'displayName' && _contractTrainerNameSource == 'displayName') {
      data['contractTrainerName'] = value.trim();
    }

    data.addAll(_buildProfileCompletionPatch());

    // data['trainerMatchingConsent'] = _trainerMatchingConsent;
    // data['trainerMatchingConsentVersion'] = 1;
    // data['trainerMatchingConsentUpdatedAt'] = FieldValue.serverTimestamp();

    // if (_trainerMatchingConsent) {
    //   data['trainerMatchingConsentAt'] =
    //   _trainerMatchingConsentAt == null
    //       ? FieldValue.serverTimestamp()
    //        : Timestamp.fromDate(_trainerMatchingConsentAt!);
    //  } else {
    //    data['trainerMatchingConsentAt'] = FieldValue.delete();
    // }

    await _profileRef.set(data, SetOptions(merge: true));
  }

  bool _isProfileCompletedForTier() {
    return isCanonicalTrainerProfileComplete({
      'realName': _nameController.text,
      'jobTitle': _positionController.text,
      'primaryActivity': _lessonSpecialtyController.text,
      'affiliationType': _affiliationType,
      'activityRegion': _activityAreaController.text,
      'activityRegions': _selectedActivityRegions,
    });
  }

  Map<String, dynamic> _buildProfileCompletionPatch() {
    final profileCompleted = _isProfileCompletedForTier();

    final data = <String, dynamic>{
      'profileCompleted': profileCompleted,
      'myInfoCompleted': profileCompleted,
    };

    if (profileCompleted) {
      data['profileCompletedAt'] = FieldValue.serverTimestamp();
    }

    return data;
  }

  bool _hasMissingAiFcProfileInfo() {
    if (_isPersonalWorkspace) return !_isProfileCompletedForTier();
    return _gymNameController.text.trim().isEmpty ||
        _positionController.text.trim().isEmpty ||
        _lessonSpecialtyController.text.trim().isEmpty ||
        _activityAreaController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _introController.text.trim().isEmpty ||
        _nameController.text.trim().isEmpty;
  }

  Future<void> _resetAiFcProfileNudgeForMissingInfo() async {
    if (!_hasMissingAiFcProfileInfo()) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_aiFcProfileNudgeStepKey, 0);
    if (!mounted) return;
    setState(() => _didShowAiFcProfileNudge = false);
  }

  // ── 유틸 ──────────────────────────────────────────────────────────────────
  String _normalizePhone(String value) => value.replaceAll(RegExp(r'\D'), '');

  String get _activityRegionSummary {
    if (_selectedActivityRegions.isEmpty) return '';
    final primary = _selectedActivityRegions.first;
    final extra = _selectedActivityRegions.length - 1;
    return extra == 0 ? primary : '$primary 외 $extra곳';
  }

  String _formatPhoneDisplay(String value) {
    final digits = _normalizePhone(value);
    if (digits.length == 11) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }
    if (digits.length == 10) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return value.trim();
  }

  String _buildShortName(String raw) {
    final text = raw.trim();

    if (text.isEmpty) return '트';

    final normalized = text.endsWith('강사')
        ? text.substring(0, text.length - '강사'.length).trim()
        : text;

    if (normalized.isEmpty) {
      return text.length <= 2 ? text : text.substring(0, 2);
    }

    return normalized.length <= 2 ? normalized : normalized.substring(0, 2);
  }

  String _buildTrainerGreetingName(String previewName) {
    return aifcNicknameLabel(previewName);
  }

  int _myPageHeaderVariant() {
    final now = DateTime.now();

    // 완전 랜덤이 아니라, 같은 시간대에서는 안정적으로 유지되는 2개 타입 선택
    // 입력 중 setState가 발생해도 문구가 계속 바뀌지 않게 하기 위함
    return (now.day + (now.hour ~/ 3)) % 2;
  }

  String _buildMyPageHeaderTitle(String previewName) {
    final name = _buildTrainerGreetingName(previewName);
    final hour = DateTime.now().hour;
    final variant = _myPageHeaderVariant();

    if (hour >= 5 && hour < 11) {
      return variant == 0 ? '좋은 아침이에요, $name' : '오늘도 기분 좋게 시작해볼까요, $name';
    }

    if (hour >= 11 && hour < 14) {
      return variant == 0 ? '점심은 챙기셨나요, $name' : '잠깐 숨 고르기 좋은 시간이네요, $name';
    }

    if (hour >= 14 && hour < 17) {
      return variant == 0 ? '오후도 차분히 가볼까요, $name' : '남은 오후도 무리 없이 이어가요, $name';
    }

    if (hour >= 17 && hour < 21) {
      return variant == 0 ? '오늘도 하루가 저물어가네요, $name' : '저녁이 천천히 내려앉고 있어요, $name';
    }

    return variant == 0 ? '오늘 하루도 고생 많으셨어요, $name' : '오늘도 정말 수고 많으셨어요, $name';
  }

  String _buildMyPageHeaderSubtitle() {
    final hour = DateTime.now().hour;
    final variant = _myPageHeaderVariant();

    if (hour >= 5 && hour < 11) {
      return variant == 0 ? '오늘도 좋은 하루가 되셨으면 좋겠어요.' : '가볍게 시작해도 충분히 좋은 하루예요.';
    }

    if (hour >= 11 && hour < 14) {
      return variant == 0 ? '잠깐 숨 고르기 좋은 시간이네요.' : '바쁜 흐름 속에서도 잠깐 쉬어가세요.';
    }

    if (hour >= 14 && hour < 17) {
      return variant == 0 ? '오후도 무리 없이 이어가볼게요.' : '오늘의 흐름을 천천히 이어가볼게요.';
    }

    if (hour >= 17 && hour < 21) {
      return variant == 0 ? '남은 하루도 편안히 마무리되길 바랄게요.' : '오늘의 마무리도 차분히 이어가볼게요.';
    }

    return variant == 0
        ? '내일도 힘나는 하루가 되셨으면 좋겠어요.'
        : '편안히 쉬고, 내일도 좋은 흐름으로 이어가요.';
  }

  void _showSnack(String msg) {
    AifcInteraction.toast(context: context, message: msg);
  }

  void _showPreparingSnack(String label) {
    _showSnack('$label 기능은 준비중입니다.');
  }

  Future<void> _handleSendBusinessCardToKakao() async {
    final canUse = await _guardBusinessCardFeature();

    if (!mounted || !canUse) return;

    _showActionToast(
      '카카오톡 명함 전송 틀을 준비했어요. 다음 단계에서 이미지 생성과 공유를 연결할게요.',
      bottomOffset: 110,
    );
  }

  void _showActionToast(String message, {double bottomOffset = 76}) {
    AifcInteraction.toast(
        context: context, message: message, bottomOffset: bottomOffset);
  }

  // ── AI FC 프로필 넛지 ─────────────────────────────────────────────────────
  Future<void> _maybeShowAiFcProfileNudge() async {
    if (_didShowAiFcProfileNudge) return;
    if (_isLoading) return;
    _didShowAiFcProfileNudge = true;

    final prefs = await SharedPreferences.getInstance();
    final savedStep = prefs.getInt(_aiFcProfileNudgeStepKey) ?? 0;
    final items = _buildAiFcProfileNudgeItems();
    if (items.isEmpty) return;

    _AiFcProfileNudgeItem? target;
    int targetIndex = savedStep;

    for (int i = 0; i < items.length; i++) {
      final index = (savedStep + i) % items.length;
      final item = items[index];
      if (item.initialValue.trim().isEmpty) {
        target = item;
        targetIndex = index;
        break;
      }
    }

    if (target == null) return;
    await Future.delayed(const Duration(milliseconds: 420));
    if (!mounted) return;

    await _showAiFcProfileNudgeDialog(
      item: target,
      currentIndex: targetIndex,
      totalCount: items.length,
    );
  }

  List<_AiFcProfileNudgeItem> _buildAiFcProfileNudgeItems() {
    final nickname = _displayNameController.text.trim().isNotEmpty
        ? _displayNameController.text.trim()
        : '강사님';

    return [
      _AiFcProfileNudgeItem(
        key: 'lessonSpecialty',
        title: 'AI FC',
        message:
            '${aifcNicknameLabel(nickname)} \n 어떤 종류의 레슨을 전문으로 하고 계신가요?\n 이제 회원님들께 레슨 분야를 자연스럽게 안내할게요.',
        label: '레슨 분야',
        hint: '예: PT / 필라테스 / 재활 / 체형교정 / 그룹레슨',
        initialValue: _lessonSpecialtyController.text,
        onSave: (value) async {
          _lessonSpecialtyController.text = value;
          await _saveSingleProfileField('lessonSpecialty', value);
        },
      ),
      _AiFcProfileNudgeItem(
        key: 'activityArea',
        title: 'AI FC',
        message:
            '${aifcNicknameLabel(nickname)} 우리 레슨플레이스 위치는 어떻게 회원님들께 안내할까요?',
        label: '센터,샵 위치 / 활동지역',
        hint: '예: 강남 / 송도 / 서울 강남구',
        initialValue: _activityAreaController.text,
        onSave: (value) async {
          _activityAreaController.text = value;
          await _saveSingleProfileField('activityArea', value);
        },
      ),
      _AiFcProfileNudgeItem(
        key: 'gymName',
        title: 'AI FC',
        message:
            '안녕하세요, ${aifcNicknameLabel(nickname)}.\n 어떤 레슨플레이스 이름으로 회원님들께 안내할까요?',
        label: '레슨 플레이스',
        hint: '예: MORE THAN GYM',
        initialValue: _gymNameController.text,
        onSave: (value) async {
          _gymNameController.text = value;
          await _saveSingleProfileField('gymName', value);
        },
      ),
      _AiFcProfileNudgeItem(
        key: 'nameEn',
        title: 'AI FC',
        message:
            '${aifcNicknameLabel(nickname)} 명함에 영문 이름도 넣어드릴게요.\n어떻게 표기할까요?',
        label: '영문 이름',
        hint: '예: Jeon Jin-woo',
        initialValue: _nameEnController.text,
        onSave: (value) async {
          _nameEnController.text = value;
          await _saveSingleProfileField('nameEn', value);
        },
      ),
      _AiFcProfileNudgeItem(
        key: 'position',
        title: 'AI FC',
        message: myPageJobPrompt(nickname),
        label: '직책 / 호칭',
        hint: '예: 강사 /트레이너 / 필라테스 강사 / 팀장 / 대표 ',
        initialValue: _positionController.text,
        onSave: (value) async {
          _positionController.text = value;
          await _saveSingleProfileField('position', value);
        },
      ),
      _AiFcProfileNudgeItem(
        key: 'phone',
        title: 'AI FC',
        message:
            '${aifcNicknameLabel(nickname)} 회원님들께 안내하거나 카카오톡 연동에 사용할 연락처가 필요할 수 있어요.\n어떤 번호로 안내할까요?',
        label: '안내 연락처',
        hint: '01012345678',
        initialValue: _phoneController.text,
        keyboardType: TextInputType.phone,
        onSave: (value) async {
          final normalized = _normalizePhone(value);
          _phoneController.text = normalized;
          await _saveSingleProfileField('phone', normalized);
        },
      ),
      _AiFcProfileNudgeItem(
        key: 'intro',
        title: 'AI FC',
        message:
            '${aifcNicknameLabel(nickname)} 회원님께 어떤 강사님으로 소개할까요?\n레슨 스타일이나 전문 분야를 한 줄로 남겨보세요.',
        label: '한줄 소개',
        hint: '예: 재활과 체형교정 중심 PT',
        initialValue: _introController.text,
        maxLines: 3,
        onSave: (value) async {
          _introController.text = value;
          await _saveSingleProfileField('intro', value);
        },
      ),
      _AiFcProfileNudgeItem(
        key: 'name',
        title: 'AI FC',
        message:
            '${aifcNicknameLabel(nickname)} 계약서에는 어떤 이름으로 남겨드릴까요?\n필요할 때만 실명을 입력해도 괜찮아요.',
        label: '계약서 표시 이름',
        hint: '예: 김민수',
        initialValue: _nameController.text,
        onSave: (value) async {
          _nameController.text = value;
          await _saveSingleProfileField('name', value);
        },
      ),
    ];
  }

  String _buildAiFcProfileReply({
    required _AiFcProfileNudgeItem item,
    required String value,
  }) {
    final v = value.trim();
    switch (item.key) {
      case 'gymName':
        return '$v로 회원님들께 안내할게요 😊';
      case 'position':
        return '좋아요. 앞으로 $v 호칭으로 자연스럽게 안내할게요.';
      case 'lessonSpecialty':
        return '$v 레슨 분야로 안내할게요.\n회원님들께 더 자연스럽게 소개할 수 있어졌어요.';
      case 'activityArea':
        return '$v 위치로 안내할게요.\n필요한 순간에 저 AI FC가 불러올게요.';
      case 'phone':
        return '안내 연락처를 적었어요.\n카카오톡 연동이나, 회원님 안내에 활용할게요.';
      case 'intro':
        return '한줄 소개내용을 바탕으로 안내 할께요.\n회원님께 더 자연스럽게 소개할 수 있을 것 같아요.';
      case 'name':
        return '$v 이름으로 기억할게요.\n계약서나 문서에 필요할 때 활용할게요.';
      default:
        return '반갑습니다! $v로 호칭할게요 😊';
    }
  }

  Future<void> _showAiFcProfileNudgeDialog({
    required _AiFcProfileNudgeItem item,
    required int currentIndex,
    required int totalCount,
  }) async {
    Future<void> moveToNextStep() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _aiFcProfileNudgeStepKey, (currentIndex + 1) % totalCount);
    }

    final result = await AifcInteraction.ask(
      context: context,
      question: item.message,
      inputLabel: item.hint,
      initialValue: item.initialValue,
      keyboardType: item.keyboardType,
      maxLines: item.maxLines,
      skipLabel: '나중에',
      onSkip: () {},
      onSave: (value) async {
        await item.onSave(value);
        return _buildAiFcProfileReply(item: item, value: value);
      },
    );

    if (!mounted) return;
    await moveToNextStep();
    if (result != null && result.trim().isNotEmpty) setState(() {});
  }

  Widget _buildContractNameSourceField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String sourceValue,
    String? focusHint,
    String? Function(String?)? validator,
    FocusNode? focusNode,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final selected = _contractTrainerNameSource == sourceValue;

    String activeMessage() {
      if (sourceValue == 'realName') {
        return '계약서 담당강사명에 이름을 반영합니다.';
      }
      return '계약서 담당강사명에 닉네임을 반영합니다.';
    }

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      scrollPadding: const EdgeInsets.only(bottom: 88),
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        filled: true,
        fillColor: selected ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
        labelStyle: const TextStyle(
          color: kMyMuted,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
        ),
        floatingLabelStyle: const TextStyle(
          color: kMyPrimary,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 11.2,
          height: 1.25,
          fontWeight: FontWeight.w600,
        ),
        suffixIcon: InkWell(
          onTap: () {
            setState(() {
              if (selected) {
                _contractTrainerNameSource = 'manual';
              } else {
                _contractTrainerNameSource = sourceValue;
              }
            });
            _handleProfileInputChanged();

            _showActionToast(
              selected ? '계약서 작성 시 담당강사명을 직접 입력합니다.' : activeMessage(),
              bottomOffset: 110,
            );
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.only(right: 12, left: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selected ? '계약서 반영중' : '계약서 반영',
                  style: TextStyle(
                    fontSize: 10.8,
                    fontWeight: FontWeight.w900,
                    color: selected ? kMyPrimary : const Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  selected
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded,
                  size: 17,
                  color: selected ? kMyPrimary : const Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 112,
          minHeight: 44,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: selected ? kMyPrimary : kMyBorder,
            width: selected ? 1.3 : 1,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: selected ? kMyPrimary : kMyBorder,
            width: selected ? 1.3 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: kMyPrimary,
            width: 1.5,
          ),
        ),
        isDense: true,
      ),
    );
  }

  // ── 일반 입력 필드 ────────────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? focusHint,
    int maxLines = 1,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return _AifcSmartTextField(
      controller: controller,
      label: label,
      questionHint: hint,
      exampleHint: focusHint ?? hint,
      maxLines: maxLines,
      validator: validator,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      readOnly: readOnly,
      onTap: onTap,
      suffixIcon: suffixIcon,
    );
  }

  // ── 빌드 ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final previewName = _displayNameController.text.trim().isNotEmpty
        ? _displayNameController.text.trim()
        : _nameController.text.trim();
    final previewShort = _buildShortName(previewName);
    final gymName = _gymNameController.text.trim();
    final intro = _introController.text.trim();
    final phone = _formatPhoneDisplay(_phoneController.text);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double width =
            isTablet ? kMyMaxContentWidth : constraints.maxWidth;

        return PopScope(
          canPop: !_isDirty,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_requestExit());
          },
          child: Scaffold(
            resizeToAvoidBottomInset: true,
            backgroundColor: kMyBg,
            body: Center(
              child: SizedBox(
                width: width,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: kMyPrimary))
                    : Column(
                        children: [
                          _buildHeader(
                            previewName: previewName,
                            previewShort: previewShort,
                            nameEn: _nameEnController.text.trim(),
                            gymName: gymName,
                            specialty: _lessonSpecialtyController.text.trim(),
                            intro: intro,
                            phone: phone,
                            address: _activityRegionSummary,
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              controller: _contentScrollController,
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding:
                                  const EdgeInsets.fromLTRB(16, 16, 16, 24),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_isMoreBusinessOwnerTier) ...[
                                      _buildMoreBusinessCard(),
                                      const SizedBox(height: 14),
                                    ],
                                    _buildPremiumBanner(),
                                    if (_isPersonalWorkspace &&
                                        _beginnerMissionEarned &&
                                        !_teacherInfoCompletedForTier) ...[
                                      const SizedBox(height: 10),
                                      _buildProfileReviewNotice(),
                                    ],
                                    const SizedBox(height: 14),
                                    _buildProfileFormCard(),
                                    const SizedBox(height: 14),
                                    if (!_isPersonalWorkspace) ...[
                                      const _GoalSettingSection(),
                                      const SizedBox(height: 14),
                                      _ProductManagementSection(
                                        nickname:
                                            normalizeAifcNickname(previewName),
                                      ),
                                      const SizedBox(height: 14),
                                    ],
                                    if (!_isMoreBusinessOwnerTier) ...[
                                      _buildMoreBusinessCard(),
                                      const SizedBox(height: 14),
                                    ],
                                    const _VersionInfoCard(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            bottomNavigationBar: _isLoading
                ? null
                : SafeArea(
                    top: false,
                    child: Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : () => _saveProfile(),
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.secondary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onSecondary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          label: _isSaving
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSecondary,
                                  ),
                                )
                              : const Text('저장하기',
                                  style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w900)),
                          icon: _isSaving
                              ? null
                              : const Icon(Icons.check_rounded, size: 20),
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  // ── 헤더 ──────────────────────────────────────────────────────────────────

  void _openHeaderCard() {
    if (!mounted) return;
    if (_isHeaderCardExpanded) return;

    setState(() {
      _isHeaderCardExpanded = true;
    });
  }

  void _closeHeaderCard() {
    if (!mounted) return;
    if (!_isHeaderCardExpanded) return;

    setState(() {
      _isHeaderCardExpanded = false;
    });
  }

  Future<void> _toggleHeaderCard() async {
    if (!mounted) return;

    if (_isHeaderCardExpanded) {
      _closeHeaderCard();
    } else {
      _openHeaderCard();
    }
  }

  void _setHeaderCardExpanded(bool expanded) {
    if (!mounted) return;

    if (expanded) {
      _openHeaderCard();
    } else {
      _closeHeaderCard();
    }
  }

  Widget _buildCompactHeaderProfile({
    required String previewName,
    required String previewShort,
    required String gymName,
    required String specialty,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.emoji_events_outlined,
              color: Colors.white,
              size: 23,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _isTierLoading
                ? Text(
                    '등급 정보를 확인하고 있어요',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '이용 중인 멤버십',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.76),
                              fontSize: 12.2,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _currentTierName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _tierMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.80),
                          fontSize: 12.2,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '회원 $_memberCountForTier명 · 레슨 $_lessonCountForTier건',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.62),
                          fontSize: 11.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          Icon(
            _isHeaderCardExpanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            color: Colors.white.withOpacity(0.82),
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSwipeHint() {
    return GestureDetector(
      onTap: () {
        unawaited(_toggleHeaderCard());
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.badge_outlined,
                color: Colors.white.withOpacity(0.72),
                size: 15,
              ),
              const SizedBox(width: 4),
              Text(
                'Business Card',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 11.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                _isHeaderCardExpanded
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: Colors.white.withOpacity(0.70),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderBusinessCardArea({
    required String previewName,
    required String nameEn,
    required String gymName,
    required String specialty,
    required String phone,
    required String address,
  }) {
    final canUseCard = _canUseBusinessCardFeature;

    final card = _MyHeaderBusinessCard(
      name: previewName.isEmpty ? '강사님' : previewName,
      nameEn: nameEn,
      gymName: gymName,
      specialty: specialty,
      phone: phone,
      address: address,
    );

    return Stack(
      children: [
        ImageFiltered(
          imageFilter: canUseCard
              ? ui.ImageFilter.blur(sigmaX: 0, sigmaY: 0)
              : ui.ImageFilter.blur(sigmaX: 3.2, sigmaY: 3.2),
          child: card,
        ),
        if (!canUseCard)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                unawaited(_openUpgradeChatSheet());
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.30),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.16),
                  ),
                ),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            color: Colors.white,
                            size: 21,
                          ),
                        ),
                        const SizedBox(height: 9),
                        const Text(
                          'Semi-Pro부터 명함 공유 가능',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '회원님께 카카오톡으로 보낼 명함을\n미리 준비해둘 수 있어요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.76),
                            fontSize: 11.5,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Semi-Pro 열어보기',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
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
    );
  }

  Widget _buildHeader({
    required String previewName,
    required String previewShort,
    required String nameEn,
    required String gymName,
    required String specialty,
    required String intro,
    required String phone,
    required String address,
  }) {
    final topInset = MediaQuery.of(context).padding.top;
    final gradient = context.mtfHeaderGradient;

    return MtfHeaderNeonOverlay(
      isExpanded: _isHeaderCardExpanded,
      intensity: 0.52,
      strokeWidth: 1.6,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;

          if (velocity > 120) {
            _setHeaderCardExpanded(true);
          } else if (velocity < -120) {
            _setHeaderCardExpanded(false);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          width: double.infinity,
          padding: EdgeInsets.only(
            top: topInset + 7,
            left: 24,
            right: 24,
            bottom: _isHeaderCardExpanded ? 10 : 6,
          ),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(32)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => unawaited(_requestExit()),
                    child: const SizedBox(
                      width: 34,
                      height: 34,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      '마이페이지',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  MtfFloatingMoreMenuButton<MyPageMoreMenuAction>(
                    key: const Key('my_page_more_menu'),
                    tooltip: '더보기',
                    icon: Icons.more_vert_rounded,
                    iconColor: Colors.white,
                    iconSize: 25,
                    cardWidth: 218,
                    offset: const Offset(0, 8),
                    onSelected: _handleMyPageMoreMenuSelected,
                    items: myPageMoreMenuItems,
                  ),
                ],
              ),
              const SizedBox(height: 5),
              GestureDetector(
                onTap: () {
                  unawaited(_toggleHeaderCard());
                },
                behavior: HitTestBehavior.opaque,
                child: _buildCompactHeaderProfile(
                  previewName: previewName,
                  previewShort: previewShort,
                  gymName: gymName,
                  specialty: specialty,
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  final slide = Tween<Offset>(
                    begin: const Offset(0, -0.04),
                    end: Offset.zero,
                  ).animate(animation);

                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: slide,
                      child: child,
                    ),
                  );
                },
                child: _isHeaderCardExpanded
                    ? Column(
                        key: const ValueKey('business_card_open'),
                        children: [
                          const SizedBox(height: 12),
                          _buildHeaderBusinessCardArea(
                            previewName: previewName,
                            nameEn: nameEn,
                            gymName: gymName,
                            specialty: specialty,
                            phone: phone,
                            address: address,
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                if (_canUseBusinessCardFeature) {
                                  unawaited(_handleSendBusinessCardToKakao());
                                } else {
                                  unawaited(_openUpgradeChatSheet());
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.22),
                                ),
                                backgroundColor: Colors.white.withOpacity(0.08),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              icon: Icon(
                                _canUseBusinessCardFeature
                                    ? Icons.ios_share_rounded
                                    : Icons.lock_outline_rounded,
                                size: 18,
                              ),
                              label: Text(
                                _canUseBusinessCardFeature
                                    ? '카카오톡으로 명함 전송'
                                    : 'Semi-Pro부터 카카오톡 전송 가능',
                                style: const TextStyle(
                                  fontSize: 13.2,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : const SizedBox.shrink(
                        key: ValueKey('business_card_closed'),
                      ),
              ),
              _buildHeaderSwipeHint(),
            ],
          ),
        ),
      ),
    );
  }

  // ── 프로필 폼 카드 ─────────────────────────────────────────────────────────

  static const _activityRegions = <String, List<String>>{
    '서울특별시': [
      '강남구',
      '강동구',
      '강서구',
      '관악구',
      '광진구',
      '구로구',
      '노원구',
      '마포구',
      '서초구',
      '성동구',
      '송파구',
      '영등포구',
      '용산구',
      '종로구',
      '중구'
    ],
    '부산광역시': ['강서구', '금정구', '남구', '동래구', '부산진구', '북구', '수영구', '연제구', '해운대구'],
    '대구광역시': ['달서구', '달성군', '동구', '북구', '수성구', '중구'],
    '인천광역시': ['계양구', '남동구', '미추홀구', '부평구', '서구', '연수구'],
    '광주광역시': ['광산구', '남구', '동구', '북구', '서구'],
    '대전광역시': ['대덕구', '동구', '서구', '유성구', '중구'],
    '울산광역시': ['남구', '동구', '북구', '울주군', '중구'],
    '세종특별자치시': ['세종시'],
    '경기도': [
      '고양시',
      '광명시',
      '김포시',
      '남양주시',
      '부천시',
      '성남시',
      '수원시',
      '시흥시',
      '안산시',
      '안양시',
      '용인시',
      '의정부시',
      '파주시',
      '평택시',
      '하남시',
      '화성시'
    ],
    '강원특별자치도': ['강릉시', '속초시', '원주시', '춘천시'],
    '충청북도': ['제천시', '청주시', '충주시'],
    '충청남도': ['공주시', '아산시', '천안시'],
    '전북특별자치도': ['군산시', '익산시', '전주시'],
    '전라남도': ['광양시', '나주시', '목포시', '순천시', '여수시'],
    '경상북도': ['경산시', '경주시', '구미시', '안동시', '포항시'],
    '경상남도': ['거제시', '김해시', '양산시', '진주시', '창원시'],
    '제주특별자치도': ['서귀포시', '제주시'],
  };

  Future<String?> _selectActivityRegion() async {
    final province = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: _activityRegions.keys
              .map((value) => ListTile(
                    title: Text(value),
                    onTap: () => Navigator.pop(context, value),
                  ))
              .toList(),
        ),
      ),
    );
    if (!mounted || province == null) return null;
    final district = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: _activityRegions[province]!
              .map((value) => ListTile(
                    title: Text(value),
                    onTap: () => Navigator.pop(context, value),
                  ))
              .toList(),
        ),
      ),
    );
    if (!mounted || district == null) return null;
    return '$province $district';
  }

  void _logActivityRegionAction(
    String action, {
    bool duplicateRejected = false,
  }) {
    if (!kDebugMode) return;
    debugPrint(
      '[MTF_ACTIVITY_REGIONS] count=${_selectedActivityRegions.length} '
      'primaryPresent=${_selectedActivityRegions.isNotEmpty} '
      'duplicateRejected=$duplicateRejected action=$action',
    );
  }

  void _syncPrimaryActivityRegion() {
    _activityAreaController.text =
        _selectedActivityRegions.isEmpty ? '' : _selectedActivityRegions.first;
  }

  Future<void> _addActivityRegion() async {
    if (_selectedActivityRegions.length >= 3) {
      _showSnack('최대 3곳까지 등록할 수 있어요.');
      return;
    }
    final region = await _selectActivityRegion();
    if (!mounted || region == null) return;
    if (_selectedActivityRegions.contains(region)) {
      _logActivityRegionAction('add', duplicateRejected: true);
      _showSnack('이미 등록된 활동 지역이에요.');
      return;
    }
    setState(() => _selectedActivityRegions.add(region));
    _syncPrimaryActivityRegion();
    _logActivityRegionAction('add');
  }

  Future<void> _showActivityRegionActions(int index) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            if (index != 0)
              ListTile(
                leading: const Icon(Icons.star_outline_rounded),
                title: const Text('대표 지역으로 설정'),
                onTap: () => Navigator.pop(context, 'primary'),
              ),
            ListTile(
              leading: const Icon(Icons.edit_location_alt_outlined),
              title: const Text('지역 변경'),
              onTap: () => Navigator.pop(context, 'change'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('삭제'),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
            ListTile(
              title: const Text('취소'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'primary') {
      setState(() {
        final region = _selectedActivityRegions.removeAt(index);
        _selectedActivityRegions.insert(0, region);
      });
      _syncPrimaryActivityRegion();
      _logActivityRegionAction('setPrimary');
      return;
    }
    if (action == 'delete') {
      setState(() => _selectedActivityRegions.removeAt(index));
      _syncPrimaryActivityRegion();
      _logActivityRegionAction('remove');
      return;
    }
    final replacement = await _selectActivityRegion();
    if (!mounted || replacement == null) return;
    final duplicateIndex = _selectedActivityRegions.indexOf(replacement);
    if (duplicateIndex >= 0 && duplicateIndex != index) {
      _logActivityRegionAction('change', duplicateRejected: true);
      _showSnack('이미 등록된 활동 지역이에요.');
      return;
    }
    setState(() => _selectedActivityRegions[index] = replacement);
    _syncPrimaryActivityRegion();
    _logActivityRegionAction('change');
  }

  Future<void> _pickBirthDate() async {
    final normalized = normalizeAndValidateMemberBirthDate(
      _birthController.text,
      required: false,
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: normalized.date ?? DateTime(1990),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _birthController.text = '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  void _logProfileFieldPolicy() {
    if (!kDebugMode) return;
    final category = trainerAffiliationCategory(_affiliationType);
    final centerCategory = category == TrainerAffiliationCategory.center;
    debugPrint(
      '[MTF_PROFILE_FIELD_POLICY] affiliationCategory=${category.name} '
      'jobTitleRequired=${isTrainerJobTitleRequired(_affiliationType)} '
      'centerFieldsVisible=${centerCategory || _optionalCenterFieldsExpanded} '
      'centerFieldsExpanded=${centerCategory || _optionalCenterFieldsExpanded}',
    );
  }

  Widget _buildAffiliationTypeField() {
    return DropdownButtonFormField<String>(
      key: const Key('my_page_affiliation_type'),
      value: _affiliationType,
      decoration: const InputDecoration(
        labelText: '소속 형태',
        border: OutlineInputBorder(),
      ),
      items: trainerAffiliationTypes.entries
          .map((entry) => DropdownMenuItem(
                value: entry.key,
                child: Text(entry.value),
              ))
          .toList(),
      onChanged: (value) {
        setState(() {
          _affiliationType = value;
          _optionalJobTitleExpanded =
              _positionController.text.trim().isNotEmpty;
          _optionalCenterFieldsExpanded =
              _gymNameController.text.trim().isNotEmpty ||
                  _centerLocationController.text.trim().isNotEmpty;
        });
        _handleProfileInputChanged();
        _logProfileFieldPolicy();
      },
      validator: (value) =>
          isTrainerAffiliationType(value) ? null : '소속 형태를 선택해주세요.',
    );
  }

  Widget _buildCenterFields() {
    return Column(
      children: [
        _buildField(
          controller: _gymNameController,
          label: '센터명',
          hint: '우리 센터는 어떤 이름으로 회원님들께 안내할까요?',
          focusHint: '예: MORE THAN GYM',
        ),
        const SizedBox(height: 12),
        _buildField(
          controller: _centerLocationController,
          label: '센터 위치',
          hint: '센터 위치를 알려주세요.',
          focusHint: '예: 서울특별시 강남구 테헤란로',
        ),
      ],
    );
  }

  Widget _buildOptionalJobTitle() {
    if (!_optionalJobTitleExpanded) {
      return Semantics(
        button: true,
        label: '직책 선택 입력',
        child: InkWell(
          key: const Key('my_page_optional_job_title_action'),
          onTap: () => setState(() => _optionalJobTitleExpanded = true),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kMyBorder),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('직책 (선택)',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    Text('입력하기 ›', style: TextStyle(color: kMyPrimary)),
                  ],
                ),
                SizedBox(height: 5),
                Text('직책이 필요한 경우에만 입력해주세요.',
                    style: TextStyle(color: kMyMuted, fontSize: 12)),
              ],
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildField(
          controller: _positionController,
          label: '직책 (선택)',
          hint: '회원님들께 안내할 직책이 있다면 입력해주세요.',
          focusHint: '예: 퍼스널트레이너',
          validator: (value) =>
              validateTrainerJobTitleForAffiliation(value, _affiliationType),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              _positionController.clear();
              setState(() => _optionalJobTitleExpanded = false);
            },
            child: const Text('직책 입력 접기'),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionalCenterFields() {
    if (!_optionalCenterFieldsExpanded) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('my_page_optional_center_action'),
          onPressed: () => setState(() => _optionalCenterFieldsExpanded = true),
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('센터 정보 추가 (선택)'),
        ),
      );
    }
    return Column(
      children: [
        _buildCenterFields(),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              _gymNameController.clear();
              _centerLocationController.clear();
              setState(() => _optionalCenterFieldsExpanded = false);
            },
            child: const Text('센터 정보 지우고 접기'),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityRegionsField() {
    return FormField<List<String>>(
      key: ValueKey('activity_regions_${_selectedActivityRegions.join('|')}'),
      initialValue: List<String>.from(_selectedActivityRegions),
      validator: (_) => _selectedActivityRegions.isNotEmpty &&
              _selectedActivityRegions.every(isKnownTrainerActivityRegion)
          ? null
          : '활동 지역을 1곳 이상 선택해주세요.',
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text('주 활동 지역',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              Text('최대 3곳', style: TextStyle(color: kMyMuted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(_selectedActivityRegions.length, (index) {
            final region = _selectedActivityRegions[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: InkWell(
                onTap: () => _showActivityRegionActions(index),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3FF),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFDDD6FE)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index == 0) ...[
                        const Text('대표 · ',
                            style: TextStyle(
                                color: kMyPrimary,
                                fontWeight: FontWeight.w800)),
                      ],
                      Expanded(child: Text(region)),
                      const Icon(Icons.close_rounded, size: 17),
                    ],
                  ),
                ),
              ),
            );
          }),
          if (_selectedActivityRegions.length < 3)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('my_page_add_activity_region'),
                onPressed: _addActivityRegion,
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('활동 지역 추가'),
              ),
            )
          else
            const Text('최대 3곳까지 등록할 수 있어요.',
                style: TextStyle(color: kMyMuted, fontSize: 12)),
          if (field.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 5, left: 12),
              child: Text(field.errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildAffiliationSpecificFields(String nickname) {
    final isCenter = trainerAffiliationCategory(_affiliationType) ==
        TrainerAffiliationCategory.center;
    final jobField = _buildField(
      controller: _positionController,
      label: '직책',
      hint: myPageJobPrompt(nickname),
      focusHint: '예: 대표 / 팀장 / 트레이너 / 강사',
      validator: (value) =>
          validateTrainerJobTitleForAffiliation(value, _affiliationType),
    );
    final activityField = _buildField(
      controller: _lessonSpecialtyController,
      label: '주 활동 종목',
      hint: '어떤 종류의 레슨을 전문으로 하고 계신가요?',
      focusHint: '예: PT / 필라테스 / 재활 / 체형교정 / 그룹레슨',
      validator: _isPersonalWorkspace ? validatePrimaryActivity : null,
    );
    return Column(
      children: [
        if (isCenter) ...[
          _buildCenterFields(),
          const SizedBox(height: 12),
          jobField,
          const SizedBox(height: 12),
          activityField,
        ] else ...[
          _buildOptionalJobTitle(),
          const SizedBox(height: 12),
          activityField,
          const SizedBox(height: 12),
          _buildOptionalCenterFields(),
        ],
        const SizedBox(height: 12),
        _buildActivityRegionsField(),
      ],
    );
  }

  Widget _buildProfileFormCard() {
    final nickname = _displayNameController.text.trim().isNotEmpty
        ? _displayNameController.text.trim()
        : '강사님';

    return _MySectionCard(
      title: 'AI FC 안내 정보',
      subtitle: '필수는 아니에요. 입력해두면 제가 필요한 순간에 자연스럽게 활용할게요.',
      icon: Icons.auto_awesome_rounded,
      child: Column(
        children: [
          // ── 기본 정보 그룹 ──────────────────────────────
          _buildContractNameSourceField(
            controller: _nameController,
            focusNode: _realNameFocusNode,
            label: '이름',
            hint: '계약서에는 어떤 이름으로 남겨드릴까요?',
            sourceValue: 'realName',
            validator: (v) {
              if (_isPersonalWorkspace) return validateTrainerRealName(v);
              if (_contractTrainerNameSource == 'realName' &&
                  (v == null || v.trim().isEmpty)) {
                return '계약서에 반영할 실명을 입력해주세요.';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          const SizedBox(height: 12),
          KeyedSubtree(
            key: _englishNameFieldKey,
            child: _buildField(
              controller: _nameEnController,
              label: '영문 이름',
              hint: '명함에 표시될 영문 이름을 알려주세요.',
              focusHint: '예: Hong Gil-Dong',
              validator: validateTrainerEnglishName,
            ),
          ),

          _buildContractNameSourceField(
            controller: _displayNameController,
            focusNode: _nicknameFocusNode,
            inputFormatters: [LengthLimitingTextInputFormatter(6)],
            label: '닉네임',
            hint: '제가 뭐라고 불러드리면 좋을까요?',
            sourceValue: 'displayName',
            validator: (v) {
              if (_contractTrainerNameSource == 'displayName' &&
                  (v == null || v.trim().isEmpty)) {
                return '계약서에 반영할 닉네임을 입력해주세요.';
              }
              return null;
            },
          ),
          if (_contractTrainerNameSource == 'manual') ...[
            const SizedBox(height: 12),
            _buildField(
              controller: _contractTrainerCustomNameController,
              label: '계약서 담당강사명 직접 입력',
              hint: '계약서에 표시할 이름을 입력해주세요.',
              validator: (v) {
                if (_contractTrainerNameSource == 'manual' &&
                    (v == null || v.trim().isEmpty)) {
                  return '계약서에 반영할 이름을 입력해주세요.';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: _buildField(
                  controller: _birthController,
                  label: '생년월일',
                  hint: '예: 1980-01-01',
                  focusHint: '예: 1980-01-01',
                  keyboardType: TextInputType.number,
                  inputFormatters: const [_MyBirthDateInputFormatter()],
                  validator: (value) {
                    final result = normalizeAndValidateMemberBirthDate(
                      value ?? '',
                      required: false,
                    );
                    return result.isValid ? null : result.errorText;
                  },
                  suffixIcon: IconButton(
                    tooltip: '달력에서 선택',
                    onPressed: _pickBirthDate,
                    icon: const Icon(Icons.calendar_month_rounded),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 4,
                child: _buildGenderPickerField(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SizedBox(height: 12),
          _buildField(
            controller: _phoneController,
            label: '안내 연락처',
            hint: '회원님들께 안내할 연락처를 알려주세요.',
            focusHint: '예: 010-1234-1234',
            keyboardType: TextInputType.phone,
            inputFormatters: const [MemberPhoneInputFormatter()],
            validator: (value) {
              final result = validateKoreanMobilePhone(
                value ?? '',
                required: false,
              );
              return result.isValid ? null : result.errorText;
            },
          ),

          // ── 구분선 ─────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: kMyBorder),
          ),

          // ── 운영 정보 그룹 ──────────────────────────────
          if (_isPersonalWorkspace) ...[
            _buildAffiliationTypeField(),
            const SizedBox(height: 12),
            _buildAffiliationSpecificFields(nickname),
          ] else ...[
            _buildField(
              controller: _positionController,
              label: '직책',
              hint: myPageJobPrompt(nickname),
              focusHint: '예: 대표 / 팀장 / 트레이너 / 강사',
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _lessonSpecialtyController,
              label: '레슨 분야',
              hint: '어떤 종류의 레슨을 전문으로 하고 계신가요?',
              focusHint: '예: PT / 필라테스 / 재활 / 체형교정 / 그룹레슨',
            ),
            const SizedBox(height: 12),
            _buildCenterFields(),
          ],
          const SizedBox(height: 12),
          _buildField(
            controller: _introController,
            label: '한줄 소개',
            hint: '회원님께 어떤 강사님으로 소개할까요?',
            focusHint: '예: 재활과 체형교정 중심 PT',
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  // ── 등급 카드 ─────────────────────────────────────────────────────────────
  Widget _buildAiFcTierCard() {
    return InkWell(
      onTap: _showTierInfoSheet,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kMyBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: _isTierLoading
            ? const SizedBox(
                height: 56,
                child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kMyPrimary)),
              )
            : Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kMyPrimary, kMyPrimary2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.emoji_events_outlined,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('현재 등급',
                                style: TextStyle(
                                    color: kMyMuted,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF2FF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(_currentTierName,
                                  style: const TextStyle(
                                      color: kMyPrimary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(_tierMessage,
                            style: const TextStyle(
                                color: kMyText,
                                fontSize: 12.5,
                                height: 1.35,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(
                          '회원 $_memberCountForTier명 · 레슨 $_lessonCountForTier건',
                          style: const TextStyle(
                              color: kMyMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded,
                      color: Color(0xFF9CA3AF)),
                ],
              ),
      ),
    );
  }

  Future<void> _showTierInfoSheet() async {
    final trainerName = _displayNameController.text.trim().isNotEmpty
        ? _displayNameController.text.trim()
        : _nameController.text.trim();

    final action = await AifcTierGuideChatSheet.show(
      context: context,
      trainerName: trainerName,
      currentTierName: _currentTierName,
      nextTierName: _nextTierName,
      memberCount: _memberCountForTier,
      lessonCount: _lessonCountForTier,
      hasProduct: _hasProduct,
      trainerInfoDone: _isPersonalWorkspace
          ? _displayTrainerInfoDone
          : !_hasMissingAiFcProfileInfo(),
    );

    if (!mounted) return;
    if (action == null || action == AifcTierGuideAction.later) {
      _showSnack('필요할 때 언제든 등급 안내를 다시 확인할 수 있어요.');
      return;
    }

    switch (action) {
      case AifcTierGuideAction.sponsor:
        _showSnack('후원 결제 화면은 준비중이에요. 곧 더 간편하게 연결할게요.');
        break;

      case AifcTierGuideAction.goFillInfo:
        _showSnack('AI FC 안내 정보를 채워주세요.');
        break;

      case AifcTierGuideAction.goAddMember:
        _showSnack('고객카드는 홈 또는 고객리스트에서 추가할 수 있어요.');
        break;

      case AifcTierGuideAction.goAddProduct:
        _showSnack('아래 레슨 상품 관리에서 상품을 추가해주세요.');
        break;

      case AifcTierGuideAction.later:
        break;
    }
  }

  // ── 프리미엄 배너 ─────────────────────────────────────────────────────────
  Future<void> _openUpgradeChatSheet() async {
    final trainerName = _displayNameController.text.trim().isNotEmpty
        ? _displayNameController.text.trim()
        : _nameController.text.trim();

    final action = await AifcUpgradeChatSheet.show(
      context: context,
      data: PremiumBannerData(
        currentTier: _resolveAppTier(_currentTierName),
        isSponsor: _isSponsor,
        scheduleCount: _lessonCountForTier,
        memberCount: _memberCountForTier,
        trainerInfoDone: _isPersonalWorkspace
            ? _displayTrainerInfoDone
            : !_hasMissingAiFcProfileInfo(),
        accountLinked: _accountLinkedForTier,
        requiresLinkedAccount: false,
        hasProduct: _hasProduct,
      ),
      trainerName: trainerName,
    );

    if (!mounted) return;
    if (action == null || action == AifcUpgradeAction.later) return;

    switch (action) {
      case AifcUpgradeAction.sponsor:
        _showSnack('후원 결제 화면은 준비 중입니다.');
        break;

      case AifcUpgradeAction.goFillInfo:
        _showSnack('AI FC 안내 정보를 채워주세요.');
        break;

      case AifcUpgradeAction.goAddMember:
        _showSnack('고객카드 추가 화면 연결은 다음 단계에서 붙일게요.');
        break;

      case AifcUpgradeAction.goAddProduct:
        _showSnack('아래 레슨 상품 관리에서 상품을 추가해주세요.');
        break;

      case AifcUpgradeAction.showTierGuide:
        await _showTierInfoSheet();
        break;

      case AifcUpgradeAction.later:
        break;
    }
  }

  Widget _buildPremiumBanner() {
    if (_isTierLoading) {
      return const SizedBox.shrink();
    }

    return PremiumBannerWidget(
      data: PremiumBannerData(
        currentTier: _resolveAppTier(_currentTierName),
        isSponsor: _isSponsor,
        scheduleCount: _lessonCountForTier,
        memberCount: _memberCountForTier,
        trainerInfoDone: _isPersonalWorkspace
            ? _displayTrainerInfoDone
            : !_hasMissingAiFcProfileInfo(),
        accountLinked: _accountLinkedForTier,
        requiresLinkedAccount: false,
        hasProduct: _hasProduct,
      ),
      onTap: _openUpgradeChatSheet,
    );
  }

  Widget _buildProfileReviewNotice() {
    return InkWell(
      onTap: () {
        _contentScrollController.animateTo(
          _contentScrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
        _formKey.currentState?.validate();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Color(0xFFB45309)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                '선생님 정보 중 확인이 필요한 항목이 있어요.',
                style: TextStyle(
                  color: Color(0xFF92400E),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Color(0xFFB45309)),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreBusinessCard() {
    final isOwner = _isMoreBusinessOwnerTier;
    final statusColor = _moreBusinessStatusColor;

    final subtitle = isOwner
        ? '센터와 선생님들의 MORE 비즈니스 흐름을 운영합니다.'
        : _moreBusinessLinked
            ? '${_moreBusinessCompanyName.isEmpty ? '연결된 회사' : _moreBusinessCompanyName}와 MORE 비즈니스 흐름을 관리합니다.'
            : '회사 연결 후 MORE 비즈니스 흐름을 사용할 수 있어요.';

    return InkWell(
      onTap: _openMoreBusinessPage,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kMyBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                _moreBusinessIcon,
                color: statusColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Flexible(
                        child: Text(
                          'MORE 비즈니스',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: kMyText,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Tooltip(
                        message: _isMoreBusinessOwnerTier
                            ? 'MORE 비즈니스'
                            : _moreBusinessLinked
                                ? '회사 연결됨'
                                : '회사 연결 안 됨',
                        child: Container(
                          width: 25,
                          height: 25,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.10),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: statusColor.withOpacity(0.18),
                            ),
                          ),
                          child: Icon(
                            _moreBusinessStatusIcon,
                            color: statusColor,
                            size: 14.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kMyMuted,
                      fontSize: 11.8,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9CA3AF),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ── 메뉴 섹션 ─────────────────────────────────────────────────────────────
  Widget _buildMenuSection({
    required String title,
    required List<_MyMenuItem> items,
  }) {
    return _MySectionCard(
      title: title,
      icon: Icons.tune_rounded,
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          return Column(
            children: [
              _MyMenuTile(item: item),
              if (index != items.length - 1)
                const Divider(height: 1, color: kMyBorder),
            ],
          );
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// 공용 위젯들
// ══════════════════════════════════════════════════════════════════════════════

class _MySectionCard extends StatelessWidget {
  const _MySectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: kMyCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kMyBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 19, color: kMyPrimary),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: kMyText,
                            fontSize: 15,
                            fontWeight: FontWeight.w900)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!,
                          style: const TextStyle(
                              color: kMyMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              height: 1.3)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MyMenuItem {
  const _MyMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingText,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailingText;
  final bool danger;
}

class _MyMenuTile extends StatelessWidget {
  const _MyMenuTile({required this.item});

  final _MyMenuItem item;

  @override
  Widget build(BuildContext context) {
    final color = item.danger ? const Color(0xFFDC2626) : kMyPrimary;
    final titleColor = item.danger ? const Color(0xFFDC2626) : kMyText;

    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withOpacity(0.09),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, size: 20, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: TextStyle(
                          color: titleColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(item.subtitle,
                      style: const TextStyle(
                          color: kMyMuted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (item.trailingText != null)
              Text(item.trailingText!,
                  style: const TextStyle(
                      color: kMyMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800))
            else
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

class _TierInfoRow extends StatelessWidget {
  const _TierInfoRow({
    required this.name,
    required this.description,
    required this.active,
  });

  final String name;
  final String description;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEEF2FF) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active ? kMyPrimary : kMyBorder,
          width: active ? 1.2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            active
                ? Icons.radio_button_checked_rounded
                : Icons.radio_button_unchecked_rounded,
            color: active ? kMyPrimary : const Color(0xFF9CA3AF),
            size: 18,
          ),
          const SizedBox(width: 9),
          SizedBox(
            width: 82,
            child: Text(name,
                style: TextStyle(
                    color: active ? kMyPrimary : kMyText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(description,
                style: const TextStyle(
                    color: kMyMuted,
                    fontSize: 11.5,
                    height: 1.3,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── 월 목표 체크 섹션 ─────────────────────────────────────────────────────────

class _GoalSettingSection extends StatefulWidget {
  const _GoalSettingSection();

  @override
  State<_GoalSettingSection> createState() => _GoalSettingSectionState();
}

class _GoalSettingSectionState extends State<_GoalSettingSection> {
  final _monthlyMemberController = TextEditingController();
  final _monthlyRevenueController = TextEditingController();
  final _weeklyLessonController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  @override
  void dispose() {
    _monthlyMemberController.dispose();
    _monthlyRevenueController.dispose();
    _weeklyLessonController.dispose();
    super.dispose();
  }

  Future<void> _loadGoals() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('trainer_profile')
          .doc('me')
          .get();

      final goals = doc.data()?['goals'] as Map<String, dynamic>?;

      if (goals != null) {
        _monthlyMemberController.text =
            (goals['monthlyMemberTarget'] ?? '').toString();

        // ✅ 버그 수정: 숫자만 추출 후 포맷
        final revenueRaw = (goals['monthlyRevenueTarget'] ?? '').toString();
        final revenueDigits = revenueRaw.replaceAll(RegExp(r'[^0-9]'), '');
        _monthlyRevenueController.text =
            _MyMoneyInputFormatter._formatWithComma(revenueDigits);

        _weeklyLessonController.text =
            (goals['weeklyLessonTarget'] ?? '').toString();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _parseGoalNumber(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  Future<void> _saveGoals() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      'goal_weekly_lesson_target',
      _parseGoalNumber(_weeklyLessonController.text),
    );

    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance
          .collection('trainer_profile')
          .doc('me')
          .set({
        'goals': {
          'monthlyMemberTarget':
              _parseGoalNumber(_monthlyMemberController.text),
          'monthlyRevenueTarget':
              _parseGoalNumber(_monthlyRevenueController.text),
          'weeklyLessonTarget': _parseGoalNumber(_weeklyLessonController.text),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      AifcInteraction.toast(
        context: context,
        message: '목표를 기록했어요. 제가 같이 체크해볼게요. 화이팅!!',
        bottomOffset: 110,
      );
    } catch (e) {
      debugPrint('목표 저장 실패: $e');

      if (!mounted) return;

      AifcInteraction.toast(
        context: context,
        message: '목표 저장에 실패했어요. 잠시 후 다시 시도해주세요.',
        bottomOffset: 110,
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _goalField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    String? hint,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters:
          inputFormatters ?? [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffix,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kMyBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kMyBorder),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _MySectionCard(
      title: '월 목표 체크',
      subtitle: '이번 달 목표를 알려주시면 회원 수, 매출, 수업 흐름을 같이 체크해볼게요.',
      icon: Icons.flag_outlined,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kMyPrimary))
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kMyBorder),
                  ),
                  child: const Text(
                    '목표는 정확하지 않아도 괜찮아요.\n대략적인 숫자만 알려주시면 제가 진행 흐름을 같이 확인해볼게요.',
                    style: TextStyle(
                        color: kMyMuted,
                        fontSize: 12,
                        height: 1.45,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                _goalField(
                    controller: _monthlyMemberController,
                    label: '이번 달 목표 회원',
                    suffix: '명'),
                const SizedBox(height: 12),
                _goalField(
                  controller: _monthlyRevenueController,
                  label: '이번 달 목표 매출',
                  hint: '예: 1,000,000',
                  suffix: '원',
                  inputFormatters: const [_MyMoneyInputFormatter()],
                ),
                const SizedBox(height: 12),
                _goalField(
                    controller: _weeklyLessonController,
                    label: '주간 레슨 목표',
                    suffix: '회'),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _saveGoals,
                    style: FilledButton.styleFrom(
                      backgroundColor: kMyPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_isSaving ? '기록하는 중...' : '목표 기록하기'),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── 레슨 상품 관리 섹션 ───────────────────────────────────────────────────────

class _ProductManagementSection extends StatelessWidget {
  const _ProductManagementSection({
    required this.nickname,
  });

  final String nickname;

  Future<void> _openAddSheet(
    BuildContext context, {
    String defaultCategory = '',
    bool showAiGuide = false,
  }) async {
    // 상품이 이미 있으면 바로 폼 열기
    if (!showAiGuide) {
      final saved = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        showDragHandle: true,
        builder: (_) => _ProductEditSheet(
          defaultCategory: defaultCategory,
          onSave: (product) => LessonProductService.addProduct(product),
        ),
      );

      if (!context.mounted) return;

      if (saved == true) {
        AifcInteraction.toast(
          context: context,
          message: '레슨 상품을 추가했어요.',
          bottomOffset: 110,
        );
      }

      return;
    }

    // 상품이 0개일 때만 AI FC 채팅 먼저
    final chatNickname = aifcNicknameLabel(nickname);
    String specialty = '';

    try {
      final snap = await FirebaseFirestore.instance
          .collection('trainer_profile')
          .doc('me')
          .get();

      final data = snap.data();
      specialty = (data?['lessonSpecialty'] ?? '').toString().trim();
    } catch (_) {}

    final autoCompleteHints = <String>[
      specialty,
      'PT',
      '피티',
      '퍼스널 트레이닝',
      'Personal Training',
      'EMS',
      '필라테스',
      'Pilates',
      '재활',
      '체형교정',
      '그룹레슨',
      'Group Training',
      '요가',
      'Yoga',
      '골프',
      'Golf',
      'Golf Training',
      '키즈',
      '산전산후',
      '다이어트',
      '근력강화',
      '스트레칭',
      'Stretching',
      '러닝',
      '러닝트레이닝',
      'Running Training',
      '기능성 운동',
      'Functional Training',
      '바디프로필',
    ].map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();

    if (!context.mounted) return;

    final result = await AifcChatSheet.show(
      context: context,
      question: '$chatNickname, 레슨 상품을 등록해두면\n'
          '계약서 작성할 때 바로 불러올 수 있어요.\n\n'
          '어떤 레슨 분야를 만들어 볼까요?'
          '${specialty.isNotEmpty ? "\n\n$specialty을 진행 중이신 것 같은데,\n그대로 적어주셔도 돼요." : ""}',
      inputLabel: specialty.isNotEmpty ? specialty : '레슨 분야를 입력해주세요',
      autoCompleteHints: autoCompleteHints,
      skipLabel: '취소',
      skipClosesImmediately: true,
      onSkip: () {},
      onSave: (value) async {
        return '$value 레슨상품을 만들었어요 👍\n이제 상품 내용을 채워주세요.';
      },
    );

    if (!context.mounted) return;
    if (result == null || result.trim().isEmpty) return;

    await Future.delayed(const Duration(milliseconds: 250));

    if (!context.mounted) return;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (_) => _ProductEditSheet(
        defaultCategory: result.trim(),
        onSave: (product) => LessonProductService.addProduct(product),
      ),
    );

    if (!context.mounted) return;

    if (saved == true) {
      AifcInteraction.toast(
        context: context,
        message: '레슨 상품을 추가했어요.',
        bottomOffset: 110,
      );
    }
  }

  Future<void> _openEditSheet(
      BuildContext context, ProductModel product) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (_) => _ProductEditSheet(
        product: product,
        onSave: (next) => LessonProductService.updateProduct(next),
      ),
    );

    if (!context.mounted) return;

    if (saved == true) {
      AifcInteraction.toast(
        context: context,
        message: '레슨 상품을 수정했어요.',
        bottomOffset: 110,
      );
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, ProductModel product) async {
    final result = await AifcConfirmChatSheet.show(
      context: context,
      nickname: normalizeAifcNickname(nickname),
      title: '상품을 삭제할까요?',
      message:
          '${product.name} 상품을 삭제하면 레슨 상품 목록에서 사라져요.\n실수로 삭제했다면 바로 되돌릴 수 있어요.',
      cancelText: '취소',
      confirmText: '삭제',
      userCancelText: '취소할게요',
      userConfirmText: '삭제할게요',
      cancelReplyText: '좋아요. 상품은 그대로 둘게요.',
      confirmReplyText: '확인했어요. 상품 삭제를 진행할게요.',
      danger: true,
    );

    if (result) {
      await LessonProductService.deleteProduct(product.id);
      if (!context.mounted) return;
      AifcInteraction.undoSnack(
        context: context,
        message: '${product.name} 상품을 삭제했어요.',
        actionLabel: '되돌리기',
        onAction: () async => LessonProductService.updateProduct(product),
      );
    }
  }

  Future<void> _confirmDeleteCategory(
    BuildContext context,
    String categoryName,
    List<ProductModel> products,
  ) async {
    if (products.isEmpty) return;

    final result = await AifcConfirmChatSheet.show(
      context: context,
      nickname: normalizeAifcNickname(nickname),
      title: '레슨 분야를 삭제할까요?',
      message: '$categoryName 분야의 레슨 상품 ${products.length}개가 목록에서 사라져요.\n'
          '실수라면 삭제 후 되돌리기는 개별 상품 기준으로만 관리하는 것이 안전해요.',
      cancelText: '취소',
      confirmText: '전체 삭제',
      userCancelText: '취소할게요',
      userConfirmText: '전체 삭제할게요',
      cancelReplyText: '좋아요. $categoryName 분야는 그대로 둘게요.',
      confirmReplyText: '확인했어요. $categoryName 분야 상품을 삭제할게요.',
      danger: true,
    );

    if (!result) return;

    try {
      for (final product in products) {
        await LessonProductService.deleteProduct(product.id);
      }

      if (!context.mounted) return;

      AifcInteraction.toast(
        context: context,
        message: '$categoryName 분야 상품 ${products.length}개를 삭제했어요.',
        bottomOffset: 110,
      );
    } catch (e) {
      debugPrint('레슨 분야 전체 삭제 실패: $e');

      if (!context.mounted) return;

      AifcInteraction.toast(
        context: context,
        message: '레슨 분야 삭제에 실패했어요. 다시 시도해주세요.',
        bottomOffset: 110,
      );
    }
  }

  Map<String, List<ProductModel>> _groupProductsByCategory(
    List<ProductModel> products,
  ) {
    final grouped = <String, List<ProductModel>>{};

    for (final product in products) {
      final category = product.categoryName.trim().isEmpty
          ? '레슨 분야'
          : product.categoryName.trim();

      grouped.putIfAbsent(category, () => <ProductModel>[]);
      grouped[category]!.add(product);
    }

    for (final entry in grouped.entries) {
      entry.value.sort((a, b) {
        final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });
    }

    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return _MySectionCard(
      title: '레슨 상품 관리',
      subtitle: '계약서 작성 시 상품명, 횟수, 금액이 자동으로 불러와집니다',
      icon: Icons.sell_outlined,
      child: StreamBuilder<List<ProductModel>>(
        stream: LessonProductService.watchProducts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            debugPrint('레슨 상품 목록 오류: ${snapshot.error}');

            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: const Text(
                '레슨 상품을 불러오지 못했어요. 저장 경로나 권한을 확인해주세요.',
                style: TextStyle(
                  color: Color(0xFFB91C1C),
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          final products = snapshot.data ?? <ProductModel>[];
          final groupedProducts = _groupProductsByCategory(products);
          final categoryNames = groupedProducts.keys.toList();

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: kMyPrimary));
          }
          return Column(
            children: [
              if (products.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kMyBorder),
                  ),
                  child: const Text(
                    '아직 알려주신 레슨 상품이 없어요.\n상품을 추가하시면, 계약서 작성할 때 바로 적용 할 수 있어요.',
                    style: TextStyle(
                        color: kMyMuted,
                        height: 1.45,
                        fontWeight: FontWeight.w600),
                  ),
                )
              else
                Column(
                  children: categoryNames.map((categoryName) {
                    final categoryProducts =
                        groupedProducts[categoryName] ?? <ProductModel>[];

                    return _ProductCategoryGroup(
                      categoryName: categoryName,
                      products: categoryProducts,
                      onAdd: () => _openAddSheet(
                        context,
                        defaultCategory: categoryName,
                      ),
                      onEdit: (product) => _openEditSheet(context, product),
                      onDelete: (product) => _confirmDelete(context, product),
                      onDeleteCategory: () => _confirmDeleteCategory(
                        context,
                        categoryName,
                        categoryProducts,
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openAddSheet(
                    context,
                    showAiGuide: products.isEmpty,
                  ),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('레슨 분야 추가'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kMyPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: kMyBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

IconData _lessonCategoryIcon(String category) {
  final c = category.trim().toLowerCase();

  if (c.contains('pt') ||
      c.contains('피티') ||
      c.contains('웨이트') ||
      c.contains('weight') ||
      c.contains('weight training') ||
      c.contains('퍼스널 트레이닝') ||
      c.contains('personaltraining') ||
      c.contains('personal training') ||
      c.contains('weight training') ||
      c.contains('퍼스널트레이닝')) {
    return Icons.fitness_center_rounded;
  }

  if (c.contains('필라테스') ||
      c.contains('pilates') ||
      c.contains('group pilates') ||
      c.contains('그룹 필라테스') ||
      c.contains('그룹필라테스')) {
    return Icons.sports_gymnastics_rounded;
  }

  if (c.contains('재활')) {
    return Icons.personal_injury_rounded;
  }

  if (c.contains('그룹') ||
      c.contains('그룹 레슨') ||
      c.contains('그룹 피티') ||
      c.contains('그룹 수업') ||
      c.contains('group training') ||
      c.contains('grouptraining') ||
      c.contains('2:1 pt') ||
      c.contains('3:1 pt')) {
    return Icons.groups_rounded;
  }

  if (c.contains('요가') || c.contains('요기') || c.contains('yoga')) {
    return Icons.self_improvement_rounded;
  }

  if (c.contains('댄스') || c.contains('줌바')) {
    return Icons.music_note_rounded;
  }

  if (c.contains('러닝') ||
      c.contains('유산소') ||
      c.contains('running') ||
      c.contains('running training') ||
      c.contains('runining pt')) {
    return Icons.directions_run_rounded;
  }

  return Icons.accessibility_new_rounded;
}

class _ProductCategoryGroup extends StatefulWidget {
  const _ProductCategoryGroup({
    required this.categoryName,
    required this.products,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onDeleteCategory,
  });

  final String categoryName;
  final List<ProductModel> products;
  final VoidCallback onAdd;
  final VoidCallback onDeleteCategory;
  final ValueChanged<ProductModel> onEdit;
  final ValueChanged<ProductModel> onDelete;

  @override
  State<_ProductCategoryGroup> createState() => _ProductCategoryGroupState();
}

class _ProductCategoryGroupState extends State<_ProductCategoryGroup> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kMyBorder),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                _expanded = !_expanded;
              });
            },
            borderRadius: BorderRadius.circular(14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: kMyPrimary.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _lessonCategoryIcon(widget.categoryName),
                    color: kMyPrimary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: kMyText,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: kMyBorder),
                  ),
                  child: Text(
                    '${widget.products.length}개',
                    style: const TextStyle(
                      color: kMyMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: widget.onAdd,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: kMyBorder),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: kMyPrimary,
                      size: 19,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                PopupMenuButton<String>(
                  tooltip: '레슨 분야 더보기',
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Color(0xFF9CA3AF),
                  ),
                  onSelected: (value) {
                    if (value == 'deleteCategory') {
                      widget.onDeleteCategory();
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'deleteCategory',
                      child: Text('분야 전체 삭제'),
                    ),
                  ],
                ),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: const Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _expanded
                ? Column(
                    key: ValueKey('open_${widget.categoryName}'),
                    children: [
                      const SizedBox(height: 10),
                      ...widget.products.map((product) {
                        return _ProductTile(
                          product: product,
                          onEdit: () => widget.onEdit(product),
                          onDelete: () => widget.onDelete(product),
                        );
                      }),
                    ],
                  )
                : const SizedBox.shrink(
                    key: ValueKey('closed'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.onEdit,
    required this.onDelete,
  });

  final ProductModel product;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  String _formatMoney(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      final indexFromEnd = raw.length - i;
      buffer.write(raw[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kMyBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: kMyPrimary.withOpacity(0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _lessonCategoryIcon(product.categoryName),
              color: kMyPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(
                        color: kMyText,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(
                  '${product.categoryName} · ${product.lessonType} · ${product.sessionCount}회 · 회당 ${_formatMoney(product.unitPrice)}원',
                  style: const TextStyle(
                      color: kMyMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  '총 ${_formatMoney(product.totalPrice)}원 · ${product.vatIncluded ? 'VAT 포함' : 'VAT 별도'}',
                  style: const TextStyle(
                      color: kMyMuted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('수정')),
              PopupMenuItem(value: 'delete', child: Text('삭제')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductEditSheet extends StatefulWidget {
  const _ProductEditSheet({
    this.product,
    this.defaultCategory = '',
    required this.onSave,
  });

  final ProductModel? product;
  final String defaultCategory;
  final Future<void> Function(ProductModel product) onSave;

  @override
  State<_ProductEditSheet> createState() => _ProductEditSheetState();
}

class _ProductEditSheetState extends State<_ProductEditSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _categoryController;
  late final TextEditingController _nameController;
  late final TextEditingController _sessionCountController;
  late final TextEditingController _unitPriceController;
  late final TextEditingController _totalPriceController;
  late final TextEditingController _lessonTypeController;

  bool _vatIncluded = true;
  bool _nameEditedManually = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final p = widget.product;

    _categoryController = TextEditingController(
      text: p?.categoryName ??
          (widget.defaultCategory.isNotEmpty
              ? widget.defaultCategory
              : 'PT 레슨'),
    );

    _nameController = TextEditingController(
      text: p?.name ?? '',
    );

    _nameEditedManually = p?.name.trim().isNotEmpty ?? false;

    _sessionCountController = TextEditingController(
      text: p?.sessionCount.toString() ?? '10',
    );

    _unitPriceController = TextEditingController(
      text: p == null
          ? ''
          : _MyMoneyInputFormatter._formatWithComma(p.unitPrice.toString()),
    );

    _totalPriceController = TextEditingController(
      text: p == null
          ? ''
          : _MyMoneyInputFormatter._formatWithComma(p.totalPrice.toString()),
    );

    _lessonTypeController = TextEditingController(
      text: p?.lessonType ?? 'PT',
    );

    _vatIncluded = p?.vatIncluded ?? true;

    _sessionCountController.addListener(_syncTotalPrice);
    _unitPriceController.addListener(_syncTotalPrice);
    _lessonTypeController.addListener(_syncProductName);
    _sessionCountController.addListener(_syncProductName);
    _nameController.addListener(_markProductNameEdited);
  }

  @override
  void dispose() {
    _sessionCountController.removeListener(_syncTotalPrice);
    _unitPriceController.removeListener(_syncTotalPrice);
    _lessonTypeController.removeListener(_syncProductName);
    _sessionCountController.removeListener(_syncProductName);
    _nameController.removeListener(_markProductNameEdited);
    _categoryController.dispose();
    _nameController.dispose();
    _sessionCountController.dispose();
    _unitPriceController.dispose();
    _totalPriceController.dispose();
    _lessonTypeController.dispose();
    super.dispose();
  }

  int _parseInt(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  void _syncTotalPrice() {
    final count = _parseInt(_sessionCountController.text);
    final unit = _parseInt(_unitPriceController.text);

    if (count <= 0 || unit <= 0) return;

    final base = count * unit;
    final total = _vatIncluded ? (base * 1.1).round() : base;
    final next = _MyMoneyInputFormatter._formatWithComma(total.toString());

    if (_totalPriceController.text != next) {
      _totalPriceController.text = next;
    }
  }

  void _markProductNameEdited() {
    if (_isSyncingProductName) return;
    _nameEditedManually = true;
  }

  bool _isSyncingProductName = false;

  void _syncProductName() {
    if (_nameEditedManually) return;

    final lessonType = _lessonTypeController.text.trim();
    final count = _parseInt(_sessionCountController.text);

    if (lessonType.isEmpty || count <= 0) return;

    final nextName = '$lessonType ${count}회';

    if (_nameController.text == nextName) return;

    _isSyncingProductName = true;
    _nameController.text = nextName;
    _isSyncingProductName = false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isSaving) return;

    setState(() => _isSaving = true);

    try {
      final product = ProductModel(
        id: widget.product?.id ?? '',
        categoryName: _categoryController.text.trim(),
        name: _nameController.text.trim(),
        sessionCount: _parseInt(_sessionCountController.text),
        unitPrice: _parseInt(_unitPriceController.text),
        totalPrice: _parseInt(_totalPriceController.text),
        vatIncluded: _vatIncluded,
        lessonType: _lessonTypeController.text.trim().isEmpty
            ? 'PT'
            : _lessonTypeController.text.trim(),
      );

      await widget.onSave(product);

      if (!mounted) return;

      // ✅ 여기서는 토스트를 띄우지 않고 true만 넘겨줌
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('레슨 상품 저장 실패: $e');

      if (!mounted) return;

      setState(() => _isSaving = false);

      AifcInteraction.toast(
        context: context,
        message: '레슨 상품 저장에 실패했어요. 다시 시도해주세요.',
        bottomOffset: 110,
      );
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? suffixText,
    String? prefixText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator ??
          (value) {
            if (value == null || value.trim().isEmpty)
              return '$label 입력이 필요합니다.';
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: suffixText,
        prefixText: prefixText,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kMyBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kMyBorder),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 4, 16, bottom + 16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const AifcAvatar(
                        size: 42,
                        isAnimating: true,
                        backgroundColor: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _HandleBar(),
                          Text(
                            widget.product == null
                                ? '레슨 상품을 추가해볼까요?'
                                : '레슨 상품을 수정할게요',
                            style: const TextStyle(
                                color: kMyText,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3),
                          ),
                          const SizedBox(height: 3),
                          const Text('등록해두면 계약서와 회원관리에서 바로 불러올 수 있어요.',
                              style: TextStyle(
                                  color: kMyMuted,
                                  fontSize: 11.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _categoryController,
                  label: '레슨 분야',
                  hint: '예: PT / 필라테스 / 재활 / 체형교정',
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: _field(
                        controller: _lessonTypeController,
                        label: '레슨 종류',
                        hint: '예: PT / 필라테스 / 재활 PT',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: _field(
                        controller: _sessionCountController,
                        label: '횟수',
                        suffixText: '회',
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _nameController,
                  label: '상품명',
                  hint: '레슨 상품명을 입력해주세요.',
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _unitPriceController,
                  label: '회당 금액',
                  prefixText: '₩ ',
                  suffixText: '원',
                  keyboardType: TextInputType.number,
                  inputFormatters: const [_MyMoneyInputFormatter()],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kMyBorder),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'VAT 설정',
                          style: TextStyle(
                            color: kMyText,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        '별도',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _vatIncluded ? kMyMuted : kMyText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Switch.adaptive(
                        value: _vatIncluded,
                        activeColor: kMyPrimary,
                        onChanged: (v) {
                          setState(() => _vatIncluded = v);
                          _syncTotalPrice();
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '포함',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _vatIncluded ? kMyText : kMyMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _totalPriceController,
                  label: '총 결제금액',
                  prefixText: '₩ ',
                  suffixText: '원',
                  keyboardType: TextInputType.number,
                  inputFormatters: const [_MyMoneyInputFormatter()],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: kMyPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(_isSaving
                        ? '기록하는 중...'
                        : widget.product == null
                            ? '레슨상품 기록하기'
                            : '수정 내용 기록하기'),
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

// ── 버전 정보 카드 ─────────────────────────────────────────────────────────────

class _VersionInfoCard extends StatelessWidget {
  const _VersionInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kMyCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kMyBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('MORE THAN',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: kMyMuted)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text('Ver. v1.0.0',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: kMyMuted)),
          ),
        ],
      ),
    );
  }
}

// ── 소형 공용 위젯 ─────────────────────────────────────────────────────────────

class _MyBirthDateInputFormatter extends TextInputFormatter {
  const _MyBirthDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    String text;
    if (digits.length <= 4) {
      text = digits;
    } else if (digits.length <= 6) {
      text = '${digits.substring(0, 4)}-${digits.substring(4)}';
    } else {
      final cut = digits.length > 8 ? digits.substring(0, 8) : digits;
      text =
          '${cut.substring(0, 4)}-${cut.substring(4, 6)}-${cut.substring(6)}';
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _HandleBar extends StatelessWidget {
  const _HandleBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFE0DEFF),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _AiFcProfileNudgeItem {
  const _AiFcProfileNudgeItem({
    required this.key,
    required this.title,
    required this.message,
    required this.label,
    required this.hint,
    required this.initialValue,
    required this.onSave,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String key;
  final String title;
  final String message;
  final String label;
  final String hint;
  final String initialValue;
  final Future<void> Function(String value) onSave;
  final TextInputType? keyboardType;
  final int maxLines;
}

class _AifcSmartTextField extends StatefulWidget {
  const _AifcSmartTextField({
    required this.controller,
    required this.label,
    required this.questionHint,
    required this.exampleHint,
    this.maxLines = 1,
    this.validator,
    this.keyboardType,
    this.inputFormatters,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String questionHint;
  final String exampleHint;
  final int maxLines;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;

  @override
  State<_AifcSmartTextField> createState() => _AifcSmartTextFieldState();
}

class _AifcSmartTextFieldState extends State<_AifcSmartTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (!mounted) return;
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hint = _focused ? widget.exampleHint : widget.questionHint;
    return TextFormField(
      controller: widget.controller,
      focusNode: _focusNode,
      scrollPadding: const EdgeInsets.only(bottom: 88),
      maxLines: widget.maxLines,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      validator: widget.validator,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: hint,
        suffixIcon: widget.suffixIcon,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: const TextStyle(
            color: kMyMuted, fontSize: 11.5, fontWeight: FontWeight.w800),
        floatingLabelStyle: const TextStyle(
            color: kMyPrimary, fontSize: 11.5, fontWeight: FontWeight.w900),
        hintStyle: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 11.2,
            height: 1.25,
            fontWeight: FontWeight.w600),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kMyBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kMyBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kMyPrimary, width: 1.3),
        ),
        isDense: true,
      ),
    );
  }
}

class _MyMoneyInputFormatter extends TextInputFormatter {
  const _MyMoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return const TextEditingValue(
          text: '', selection: TextSelection.collapsed(offset: 0));
    }
    final formatted = _formatWithComma(digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  static String _formatWithComma(String digits) {
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final indexFromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) buffer.write(',');
    }
    return buffer.toString();
  }
}

class _MyHeaderBusinessCard extends StatelessWidget {
  const _MyHeaderBusinessCard({
    required this.name,
    required this.nameEn,
    required this.gymName,
    required this.specialty,
    required this.phone,
    required this.address,
  });

  final String name;
  final String nameEn;
  final String gymName;
  final String specialty;
  final String phone;
  final String address;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.78,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFF0D1117),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _MyHeaderPhotoAreaPainter(
                  photoBg: const Color(0xFF1A2332),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _MyHeaderSlashLinePainter(),
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 0, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (gymName.isNotEmpty)
                      Row(
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: Color(0xFF38BDF8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              gymName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      const SizedBox.shrink(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            height: 1.1,
                          ),
                        ),
                        if (nameEn.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            nameEn,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              letterSpacing: 0.7,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 7),
                        if (specialty.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withOpacity(0.14),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color:
                                    const Color(0xFF38BDF8).withOpacity(0.28),
                              ),
                            ),
                            child: Text(
                              specialty,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF7DD3FC),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(
                          height: 1,
                          color: Colors.white.withOpacity(0.12),
                          thickness: 0.5,
                        ),
                        const SizedBox(height: 8),
                        if (phone.isNotEmpty)
                          _MyHeaderContactRow(
                            label: 'TEL',
                            value: phone,
                          ),
                        if (address.isNotEmpty)
                          _MyHeaderContactRow(
                            label: 'ADD',
                            value: address,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 18,
              top: 18,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.12),
                  ),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: Colors.white54,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyHeaderContactRow extends StatelessWidget {
  const _MyHeaderContactRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white30,
                fontSize: 8.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyHeaderPhotoAreaPainter extends CustomPainter {
  const _MyHeaderPhotoAreaPainter({
    required this.photoBg,
  });

  final Color photoBg;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.64, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * 0.55, size.height)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = photoBg
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant _MyHeaderPhotoAreaPainter oldDelegate) {
    return oldDelegate.photoBg != photoBg;
  }
}

class _MyHeaderSlashLinePainter extends CustomPainter {
  const _MyHeaderSlashLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final x1 = size.width * 0.64;
    final x2 = size.width * 0.55;

    final paint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(x1, 0),
        Offset(x2, size.height),
        [
          const Color(0xFF38BDF8).withOpacity(0.1),
          const Color(0xFF38BDF8),
          const Color(0xFF9333EA),
          const Color(0xFF38BDF8).withOpacity(0.1),
        ],
        [0.0, 0.28, 0.72, 1.0],
      )
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(x1, 0),
      Offset(x2, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
