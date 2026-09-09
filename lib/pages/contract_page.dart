import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/app_tier_access_service.dart';
import '../widgets/aifc_tier_feature_gate_sheet.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../services/lesson_product_service.dart';
import '../services/more_care_slot_service.dart';

import '../models/product_model.dart';

import '../widgets/aifc_confirm_chat_sheet.dart';
import '../widgets/aifc_info_chat_sheet.dart';
import '../widgets/aifc_interaction.dart';
import '../widgets/aifc_option_chat_sheet.dart';
import '../widgets/mtf_floating_more_menu.dart';
import '../widgets/mtf_header_neon_overlay.dart';

import '../aifc/core/aifc_nickname.dart';
import '../theme/app_colors.dart';

const Color kContractBgColor = Color(0xFFF3F4F6);
const Color kContractCardColor = Colors.white;
const Color kContractBorderColor = Color(0xFFE5E7EB);
const double kContractPageHorizontalPadding = 16;
const double kContractMaxContentWidth = 480;

enum ContractSourceMode {
  basicTemplate,
  customWrite,
  uploadPdf,
}

enum PaymentMethod {
  cash,
  card,
  transfer,
}

enum ContractDeliveryMethod {
  email,
  sms,
  kakao,
  print,
  storeOnly,
}

enum ContractStage {
  requiredInfo,
  detailConfirm,
}

enum ContractStatus {
  draft,
  step1Saved,
  awaitingSign,
  signed,
  sent,
  cancelled,
  superseded,
}

enum _ContractMoreAction {
  documentType,
  sourceMode,
  tempSave,
  savePdf,
  sendCustomer,
  sendTrainer,
  newVersion,
}

class _ContractUiMemory {
  static String lastDocumentType = 'PT 계약서';
  static ContractSourceMode lastSourceMode = ContractSourceMode.basicTemplate;

  static bool vatIncluded = true;
  static bool unlimitedEndDate = false;

  static bool useLessonClause = true;
  static bool useReservationClause = true;
  static bool useHoldClause = false;
  static bool usePenaltyClause = true;
  static bool useTransferClause = false;

  static bool reservationTipShown = false;
  static bool penaltyTipShown = false;

  static Map<int, int> lessonUnitPricePresets = <int, int>{
    10: 100000,
    20: 95000,
    30: 90000,
  };

  static List<_LessonTemplateCategory> lessonTemplateCategories =
      _buildDefaultLessonTemplateCategories();

  static List<_LessonTemplateCategory> _buildDefaultLessonTemplateCategories() {
    return [
      _LessonTemplateCategory(
        id: 'cat_pilates_default',
        name: '필라테스 레슨',
        items: [
          _LessonTemplateItem(
            id: 'pilates_10',
            name: '필라테스 개인 레슨 10회',
            sessionCount: 10,
            totalPrice: 1100000,
            vatIncluded: true,
          ),
          _LessonTemplateItem(
            id: 'pilates_20',
            name: '필라테스 개인 레슨 20회',
            sessionCount: 20,
            totalPrice: 2090000,
            vatIncluded: true,
          ),
          _LessonTemplateItem(
            id: 'pilates_30',
            name: '필라테스 개인 레슨 30회',
            sessionCount: 30,
            totalPrice: 2970000,
            vatIncluded: true,
          ),
        ],
      ),
      _LessonTemplateCategory(
        id: 'cat_pt_default',
        name: 'PT 레슨',
        items: [
          _LessonTemplateItem(
            id: 'pt_10',
            name: 'PT레슨 10회',
            sessionCount: 10,
            totalPrice: 1100000,
            vatIncluded: true,
          ),
          _LessonTemplateItem(
            id: 'pt_20',
            name: 'PT레슨 20회',
            sessionCount: 20,
            totalPrice: 2090000,
            vatIncluded: true,
          ),
          _LessonTemplateItem(
            id: 'pt_30',
            name: 'PT레슨 30회',
            sessionCount: 30,
            totalPrice: 2970000,
            vatIncluded: true,
          ),
        ],
      ),
    ];
  }
}

class ContractPage extends StatefulWidget {
  final String memberId;
  final String memberName;
  final String trainerName;
  final ContractStage initialStage;
  final String? contractId;
  final String? personalOwnerUid;

  const ContractPage({
    super.key,
    required this.memberId,
    required this.memberName,
    required this.trainerName,
    this.initialStage = ContractStage.requiredInfo,
    this.contractId,
    this.personalOwnerUid,
  });

  @override
  State<ContractPage> createState() => _ContractPageState();
}

class _ContractPageState extends State<ContractPage>
    with SingleTickerProviderStateMixin {
  bool _creationGateResolved = false;
  late String _internalMemberId;

  late ContractSourceMode _sourceMode;
  late String _documentType;

  late ContractStage _currentStage;
  int _version = 1;
  bool _draftSaved = false;
  bool _shouldReturnSavedToCaller = false;

  late final AnimationController _livePulseController;
  late final Animation<double> _livePulseAnimation;

  OverlayEntry? _tipOverlayEntry;
  Timer? _tipTimer;

  String _lastDetailSignatureSnapshot = '';

  List<ProductModel> _products = <ProductModel>[];
  ProductModel? _selectedProduct;
  bool _isLoadingProducts = false;

  String _lastSignatureSensitiveSnapshot = '';
  bool _isApplyingProgrammaticChange = false;
  bool _trainerNameEditedManually = false;
  bool _signatureResetNoticeShownInThisChange = false;
  bool _clientCardAutoRegisterOfferShowing = false;
  String? _memberPhoneDuplicateMessage;

  final ScrollController _scrollController = ScrollController();
  final FocusNode _productNameFocusNode = FocusNode();

  final GlobalKey _basicInfoSectionKey = GlobalKey();
  final GlobalKey _paymentSectionKey = GlobalKey();
  final GlobalKey _contractSectionKey = GlobalKey();
  final GlobalKey _healthSectionKey = GlobalKey();
  final GlobalKey _finalSectionKey = GlobalKey();
  final GlobalKey _signatureSectionKey = GlobalKey();

  static const List<String> _supportMessages = [
    '어려운 결정과 다짐을 지지하고 응원합니다.',
    '한 번의 결심이 아닌, 이어갈 수 있는 관리가 되길 바랍니다.',
    '오늘의 선택이 더 편안한 내일로 이어지길 바랍니다.',
    '몸을 돌보겠다는 마음이 오래 이어질 수 있도록 함께합니다.',
    '나를 위한 선택이 오래 지속될 수 있도록 차분히 남깁니다.',
    '시작의 마음이 흔들리지 않도록 지금의 약속을 기록합니다.',
    '무리하지 않고, 천천히, 오래 갈 수 있는 변화를 응원합니다.',
  ];

  late final String _supportMessage;

  final TextEditingController _hybridLessonClauseController =
      TextEditingController();
  final TextEditingController _hybridReservationClauseController =
      TextEditingController();
  final TextEditingController _hybridHoldClauseController =
      TextEditingController();
  final TextEditingController _hybridPenaltyClauseController =
      TextEditingController();
  final TextEditingController _hybridTransferClauseController =
      TextEditingController();

  static const double _signatureSimilarityWarningThreshold = 0.45;

  // 기본 정보
  late final TextEditingController _memberNameController;
  final TextEditingController _memberBirthController = TextEditingController();
  final TextEditingController _memberPhoneController = TextEditingController();
  final TextEditingController _memberEmailController = TextEditingController();

  final TextEditingController _centerNameController =
      TextEditingController(text: 'MORE THAN FITNESS');

  late final TextEditingController _trainerNameController;

  // 결제 정보
  static const int _maxStoredPdfCount = 5;
  final List<String> _storedPdfNames = <String>[];

  final TextEditingController _productNameController =
      TextEditingController(text: 'PT레슨 10회');
  final TextEditingController _unitPriceController =
      TextEditingController(text: '100,000');
  final TextEditingController _sessionCountController =
      TextEditingController(text: '10');
  final TextEditingController _priceController =
      TextEditingController(text: '1,100,000');
  final TextEditingController _contractDateController = TextEditingController();
  final TextEditingController _paymentDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  PaymentMethod _paymentMethod = PaymentMethod.card;

  // 작성 방식별 추가
  final TextEditingController _customMainClauseController =
      TextEditingController(
    text: '회원은 환불·중도해지·예약·지연·홀드·양도 기준을 확인하고 이에 동의합니다.',
  );
  final TextEditingController _customExtraClauseController =
      TextEditingController();
  String? _uploadedPdfName;

  // VAT / 종료일
  bool _usePaymentSection = true;
  late bool _vatIncluded;
  late bool _isUnlimitedEndDate;

  // 계약 조건 토글
  late bool _useLessonClause;
  late bool _useReservationClause;
  late bool _useHoldClause;
  late bool _usePenaltyClause;
  late bool _useTransferClause;

  // 계약 조건 필드
  final TextEditingController _sessionMinutesController =
      TextEditingController(text: '50');

  final TextEditingController _cancelHoursController =
      TextEditingController(text: '24');
  final TextEditingController _lessonDelayMinutesController =
      TextEditingController(text: '30');

  final TextEditingController _holdCountController =
      TextEditingController(text: '2');
  final TextEditingController _holdDaysController =
      TextEditingController(text: '30');
  final TextEditingController _suspensionRuleController = TextEditingController(
    text: '기관에서 인정하는 사항에 따라 이용정지 운영의 예외를 둘 수 있습니다.',
  );

  final TextEditingController _penaltyPercentController =
      TextEditingController(text: '10');
  bool _noRefundProduct = false;

  bool _transferAllowed = false;
  final TextEditingController _transferRuleController = TextEditingController(
    text: '센터 승인 및 명의 확인 후 양도 가능합니다.',
  );

  IconData get _compactCurrentStepIcon {
    final label = _compactNextStepLabel;

    if (label.contains('문서')) return Icons.article_outlined;
    if (label.contains('기본')) return Icons.badge_outlined;
    if (label.contains('결제')) return Icons.payments_outlined;
    if (label.contains('기본서명')) return Icons.draw_outlined;
    if (label.contains('계약조건')) return Icons.rule_folder_outlined;
    if (label.contains('건강')) return Icons.health_and_safety_outlined;
    if (label.contains('최종확인')) return Icons.fact_check_outlined;
    if (label.contains('최종서명')) return Icons.verified_outlined;

    return Icons.check_circle_outline;
  }

  Future<void> _requestMoreCareSlotAfterContractSaved(String? memberId) async {
    final cleanMemberId = (memberId ?? '').trim();

    if (cleanMemberId.isEmpty) return;

    try {
      final decision = await MoreCareSlotService.requestTemporarySlotForMember(
        memberId: cleanMemberId,
        reason: 'contract_saved',
      );

      if (!mounted) return;

      if (decision.canUseAdvancedMoreCare &&
          decision.status == MoreCareSlotStatus.temporary) {
        _showSnack('계약서 기준 MORE 관리도 잠시 열어두었어요. 관리자에게 승인 요청을 보내둘게요.');
      }
    } catch (e) {
      debugPrint('[MTF_MORE_SLOT] contract slot request failed: $e');
    }
  }

  String get _normalizedMemberPhone {
    return _memberPhoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
  }

  String? get _memberPhoneFormatErrorText {
    final phone = _normalizedMemberPhone;

    if (phone.isEmpty) return null;

    final isLengthValid = phone.length == 10 || phone.length == 11;
    if (!isLengthValid) {
      return '휴대폰 번호는 숫자 10~11자리로 입력해주세요.';
    }

    final isMobilePrefix = phone.startsWith('010') ||
        phone.startsWith('011') ||
        phone.startsWith('016') ||
        phone.startsWith('017') ||
        phone.startsWith('018') ||
        phone.startsWith('019');

    if (!isMobilePrefix) {
      return '휴대폰 번호는 010 등 이동전화 번호로 입력해주세요.';
    }

    return null;
  }

  bool get _isMemberPhoneFormatValid {
    final phone = _normalizedMemberPhone;
    if (phone.isEmpty) return false;

    return _memberPhoneFormatErrorText == null;
  }

  int _ageFromBirthDate(DateTime birthDate, DateTime now) {
    var age = now.year - birthDate.year;

    final hasBirthdayPassedThisYear = now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);

    if (!hasBirthdayPassedThisYear) {
      age -= 1;
    }

    return age;
  }

  String? get _memberBirthFormatErrorText {
    final text = _memberBirthController.text.trim();

    if (text.isEmpty) return null;

    final date = _tryParseDate(text);
    if (date == null) {
      return 'YYYY-MM-DD 형식으로 입력해주세요.';
    }

    final now = DateTime.now();

    if (date.isAfter(now)) {
      return '생년월일은 오늘 이후일 수 없어요.';
    }

    if (date.year < 1900) {
      return '생년월일을 다시 확인해주세요.';
    }

    final age = _ageFromBirthDate(date, now);

    if (age <= 3) {
      return '만 3세 이하는 등록하기 어려워요. 생년월일을 확인해주세요.';
    }

    if (age >= 100) {
      return '만 100세 이상은 생년월일을 다시 확인해주세요.';
    }

    return null;
  }

  bool get _isMemberBirthFormatValid {
    final text = _memberBirthController.text.trim();
    if (text.isEmpty) return false;

    return _memberBirthFormatErrorText == null;
  }

  String get _memberPhoneErrorText {
    if (_memberPhoneMissing) {
      return '연락처를 입력해주세요.';
    }

    final formatError = _memberPhoneFormatErrorText;
    if (formatError != null) {
      return formatError;
    }

    final duplicateMessage = _memberPhoneDuplicateMessage;
    if (duplicateMessage != null && duplicateMessage.isNotEmpty) {
      return duplicateMessage;
    }

    return '휴대폰 번호를 확인해주세요.';
  }

  String get _memberBirthErrorText {
    if (_memberBirthMissing) {
      return '생년월일을 입력해주세요.';
    }

    return _memberBirthFormatErrorText ?? '생년월일을 확인해주세요.';
  }

  bool _isActiveDuplicateMemberDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (doc.id == _internalMemberId) return false;

    final data = doc.data();

    if (data['isDeleted'] == true) return false;

    final deleteStatus = (data['deleteStatus'] ?? '').toString().trim();
    if (deleteStatus == 'pending_delete') return false;

    return true;
  }

  Future<bool> _ensureMemberPhoneIsNotDuplicated() async {
    final phone = _normalizedMemberPhone;

    if (phone.isEmpty || !_isMemberPhoneFormatValid) {
      return true;
    }

    final rawDisplayPhone = _memberPhoneController.text.trim();

    final queryValues = <String>{
      phone,
      if (rawDisplayPhone.isNotEmpty) rawDisplayPhone,
    };

    final duplicateDocs =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    try {
      for (final value in queryValues) {
        final byPhone = await FirebaseFirestore.instance
            .collection('members')
            .where('phone', isEqualTo: value)
            .limit(8)
            .get();

        for (final doc in byPhone.docs) {
          if (_isActiveDuplicateMemberDoc(doc)) {
            duplicateDocs[doc.id] = doc;
          }
        }

        final byPhoneDisplay = await FirebaseFirestore.instance
            .collection('members')
            .where('phoneDisplay', isEqualTo: value)
            .limit(8)
            .get();

        for (final doc in byPhoneDisplay.docs) {
          if (_isActiveDuplicateMemberDoc(doc)) {
            duplicateDocs[doc.id] = doc;
          }
        }
      }

      if (duplicateDocs.isEmpty) {
        if (mounted && _memberPhoneDuplicateMessage != null) {
          setState(() {
            _memberPhoneDuplicateMessage = null;
          });
        }
        return true;
      }

      final names = duplicateDocs.values
          .map((doc) => (doc.data()['name'] ?? '').toString().trim())
          .where((name) => name.isNotEmpty)
          .take(2)
          .toList();

      final message = names.isEmpty
          ? '같은 휴대폰 번호로 등록된 회원이 이미 있어요.'
          : '같은 휴대폰 번호 회원이 이미 있어요: ${names.join(', ')}';

      if (mounted) {
        setState(() {
          _memberPhoneDuplicateMessage = message;
          _showRequiredErrors = true;
        });

        await _scrollToSection(_basicInfoSectionKey);
        _showSnack(message);
      }

      return false;
    } catch (e) {
      debugPrint('회원 휴대폰 중복 확인 실패: $e');

      // 네트워크 문제로 계약서 저장 전체를 막지는 않습니다.
      // 단, 정상 연결 상태에서는 위 로직으로 중복을 차단합니다.
      return true;
    }
  }

  String get _contractPdfFileName {
    final no =
        (_contractNo ?? 'draft').replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final member = _memberNameController.text.trim().isEmpty
        ? 'member'
        : _memberNameController.text.trim().replaceAll(RegExp(r'\s+'), '_');

    return 'MTF_contract_${no}_$member.pdf';
  }

  String _normalizeContractNickname(String value) {
    return normalizeAifcNickname(value);
  }

  void _handleTrainerNameEditedManually() {
    if (_isApplyingProgrammaticChange) return;

    _trainerNameEditedManually = true;
  }

  String _trainerProfileNameFromData(Map<String, dynamic>? data) {
    if (data == null) return '';

    final candidates = [
      data['nickname'],
      data['trainerNickname'],
      data['displayName'],
      data['trainerName'],
      data['name'],
    ];

    for (final value in candidates) {
      final text = (value ?? '').toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    }

    return '';
  }

  Future<void> _loadTrainerNameFromProfileForContract() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('trainer_profile')
          .doc('me')
          .get();

      if (!mounted) return;

      final profileName = _normalizeContractNickname(
        _trainerProfileNameFromData(snap.data()),
      );

      if (profileName.isEmpty || profileName == '강사') return;
      if (_trainerNameEditedManually) return;

      final current = _trainerNameController.text.trim();

      final shouldApplyProfileName =
          current.isEmpty || current == '강사' || current == '강사님';

      if (!shouldApplyProfileName) return;

      _isApplyingProgrammaticChange = true;

      setState(() {
        _trainerNameController.text = profileName;
      });

      _isApplyingProgrammaticChange = false;

      _lastSignatureSensitiveSnapshot = _signatureSensitiveSnapshot;
    } catch (_) {
      _isApplyingProgrammaticChange = false;
    }
  }

  bool get _isMemberEmailFormatValid {
    final email = _memberEmailController.text.trim();

    if (email.isEmpty) return false;

    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }

  bool get _shouldShowMemberPhoneFormatError {
    return _showRequiredErrors &&
        !_memberPhoneMissing &&
        !_isMemberPhoneFormatValid;
  }

  bool get _shouldShowMemberBirthFormatError {
    return _showRequiredErrors &&
        !_memberBirthMissing &&
        !_isMemberBirthFormatValid;
  }

  bool get _shouldShowMemberEmailFormatError {
    return _showRequiredErrors &&
        !_memberEmailMissing &&
        !_isMemberEmailFormatValid;
  }

  String get _detailSignatureSnapshot {
    return [
      _sourceMode.name,
      _documentType,
      _useLessonClause.toString(),
      _useReservationClause.toString(),
      _useHoldClause.toString(),
      _usePenaltyClause.toString(),
      _useTransferClause.toString(),
      _sessionMinutesController.text.trim(),
      _cancelHoursController.text.trim(),
      _lessonDelayMinutesController.text.trim(),
      _holdCountController.text.trim(),
      _holdDaysController.text.trim(),
      _suspensionRuleController.text.trim(),
      _penaltyPercentController.text.trim(),
      _noRefundProduct.toString(),
      _transferAllowed.toString(),
      _transferRuleController.text.trim(),
      _hybridLessonClauseController.text.trim(),
      _hybridReservationClauseController.text.trim(),
      _hybridHoldClauseController.text.trim(),
      _hybridPenaltyClauseController.text.trim(),
      _hybridTransferClauseController.text.trim(),
      _customMainClauseController.text.trim(),
      _customExtraClauseController.text.trim(),
      _agreeLessonClause.toString(),
      _agreeReservationClause.toString(),
      _agreeHoldClause.toString(),
      _agreePenaltyClause.toString(),
      _agreeTransferClause.toString(),
      _healthPain.toString(),
      _healthSurgery.toString(),
      _healthAccident.toString(),
      _healthPregnancy.toString(),
      _healthRehab.toString(),
      _healthNone.toString(),
      _selectedPainAreas.join(','),
      _selectedSurgeryTypes.join(','),
      _selectedAccidentTypes.join(','),
      _healthDetailController.text.trim(),
      _agreeHealthNotice.toString(),
      _agreeImportantNotice.toString(),
      _agreeSameContentSave.toString(),
      _deliveryMethod.name,
      _deliveryTarget,
    ].join('|');
  }

  void _handleDetailSignatureSensitiveChanged() {
    if (_isApplyingProgrammaticChange) return;

    if (_lastDetailSignatureSnapshot.isEmpty) {
      _lastDetailSignatureSnapshot = _detailSignatureSnapshot;
      return;
    }

    final nextSnapshot = _detailSignatureSnapshot;

    if (nextSnapshot == _lastDetailSignatureSnapshot) return;

    _lastDetailSignatureSnapshot = nextSnapshot;

    _clearFinalSignaturesBecauseDetailChanged();
  }

  List<_StepItem> get _headerStageSteps {
    if (_currentStage == ContractStage.requiredInfo) {
      return [
        _StepItem('기본정보 입력', _isBasicInfoComplete),
        _StepItem('개인레슨 결제정보', _isPaymentSectionComplete),
        _StepItem('기본 내용 확인 서명', _memberSigned && _staffSigned),
        _StepItem('1단계 저장', _isStep1Saved),
      ];
    }

    return [
      _StepItem('계약조건 확인', _isContractConditionsComplete),
      _StepItem('건강고지 확인', _isHealthSectionComplete),
      _StepItem('최종 확인 및 수령 방식', _isFinalConfirmComplete),
      _StepItem('최종 동의 서명', _isFinalSignedCompleted),
    ];
  }

  int get _headerCompletedCount {
    return _headerStageSteps.where((e) => e.done).length;
  }

  int get _headerTotalCount => _headerStageSteps.length;

  double get _headerProgressValue {
    if (_headerTotalCount <= 0) return 0;
    return (_headerCompletedCount / _headerTotalCount).clamp(0.0, 1.0);
  }

  String get _headerNextStepLabel {
    final next = _headerStageSteps.where((e) => !e.done).toList();
    if (next.isEmpty) return '완료';
    return next.first.title;
  }

  String get _compactProgressLabel {
    return '$_compactCompletedCount/$_compactTotalCount 다음: $_compactNextStepLabel';
  }

  bool get _isStep1Ready {
    return _isDocumentSetupComplete &&
        _isBasicInfoComplete &&
        _isPaymentSectionComplete &&
        _isDateRangeValid;
  }

  bool get _isStep1Saved {
    return _contractStatus == ContractStatus.step1Saved ||
        _contractStatus == ContractStatus.signed ||
        _contractStatus == ContractStatus.sent;
  }

  bool get _canOpenStep2 => _canOpenDetailConfirm;

  bool get _canOpenDetailConfirm {
    return _isStep1Saved || _isStep1Ready;
  }

  String get _stageTitle {
    switch (_currentStage) {
      case ContractStage.requiredInfo:
        return '필수 작성';
      case ContractStage.detailConfirm:
        return '상세 확인';
    }
  }

  String get _stageSubtitle {
    switch (_currentStage) {
      case ContractStage.requiredInfo:
        return '기본정보·상품·결제·기본서명을 먼저 작성합니다.';
      case ContractStage.detailConfirm:
        return '계약조건·건강고지·최종서명을 작성합니다.';
    }
  }

  bool _showRequiredErrors = false;

  String? _contractId;
  String? _contractNo;

  bool _isSavingContract = false;
  ContractStatus _contractStatus = ContractStatus.draft;

  // 조항 동의
  bool _agreeLessonClause = false;
  bool _agreeReservationClause = false;
  bool _agreeHoldClause = false;
  bool _agreePenaltyClause = false;
  bool _agreeTransferClause = false;

  // 건강 고지
  bool _healthPain = false;
  bool _healthSurgery = false;
  bool _healthAccident = false;
  bool _healthPregnancy = false;
  bool _healthRehab = false;
  bool _healthNone = true;
  bool _agreeHealthNotice = false;

  bool get _memberNameMissing => _memberNameController.text.trim().isEmpty;

  bool get _memberBirthMissing => _memberBirthController.text.trim().isEmpty;

  bool get _memberPhoneMissing => _memberPhoneController.text.trim().isEmpty;

  bool get _memberEmailMissing => _memberEmailController.text.trim().isEmpty;

  bool get _centerNameMissing => _centerNameController.text.trim().isEmpty;

  bool get _trainerNameMissing => _trainerNameController.text.trim().isEmpty;

  bool get _productNameMissing =>
      _usePaymentSection && _productNameController.text.trim().isEmpty;

  bool get _unitPriceMissing => _usePaymentSection && _unitPriceValue <= 0;

  bool get _sessionCountMissing =>
      _usePaymentSection && _sessionCountValue <= 0;

  bool get _priceMissing => _usePaymentSection && _priceValue <= 0;

  bool get _paymentDateMissing =>
      _usePaymentSection && _paymentDateController.text.trim().isEmpty;

  bool get _contractDateMissing => _contractDateController.text.trim().isEmpty;

  bool get _endDateMissing =>
      !_isUnlimitedEndDate && _endDateController.text.trim().isEmpty;

  bool get _shouldShowMemberNameError =>
      _showRequiredErrors && _memberNameMissing;

  bool get _shouldShowMemberBirthError =>
      _showRequiredErrors && _memberBirthMissing;

  bool get _shouldShowMemberPhoneError =>
      _showRequiredErrors && _memberPhoneMissing;

  bool get _shouldShowMemberEmailError =>
      _showRequiredErrors && _memberEmailMissing;

  bool get _shouldShowCenterNameError =>
      _showRequiredErrors && _centerNameMissing;

  bool get _shouldShowTrainerNameError =>
      _showRequiredErrors && _trainerNameMissing;

  bool get _shouldShowProductNameError =>
      _showRequiredErrors && _productNameMissing;

  bool get _shouldShowUnitPriceError =>
      _showRequiredErrors && _unitPriceMissing;

  bool get _shouldShowSessionCountError =>
      _showRequiredErrors && _sessionCountMissing;

  bool get _shouldShowPriceError => _showRequiredErrors && _priceMissing;

  bool get _shouldShowPaymentDateError =>
      _showRequiredErrors && _paymentDateMissing;

  bool get _shouldShowContractDateError =>
      _showRequiredErrors && _contractDateMissing;

  bool get _shouldShowEndDateError => _showRequiredErrors && _endDateMissing;

  int get _requiredTotalCount {
    var count = 6; // 회원명, 생년월일, 연락처, 이메일, 센터명, 강사명

    if (_usePaymentSection) {
      count += 6; // 상품명, 회당금액, 횟수, 실결제금액, 결제일, 계약일
      if (!_isUnlimitedEndDate) count += 1; // 종료일
    } else {
      count += 1; // 계약일
      if (!_isUnlimitedEndDate) count += 1;
    }

    return count;
  }

  int get _compactTotalCount => _buildSteps().length;

  int get _compactCompletedCount {
    return _buildSteps().where((e) => e.done).length;
  }

  double get _compactProgressValue {
    if (_compactTotalCount <= 0) return 0;
    return (_compactCompletedCount / _compactTotalCount).clamp(0.0, 1.0);
  }

  String get _compactNextStepLabel {
    final steps = _buildSteps();
    final currentIndex = steps.indexWhere((e) => !e.done);

    if (currentIndex == -1) {
      return '완료';
    }

    return steps[currentIndex].title;
  }

  int get _requiredCompletedCount {
    var count = 0;

    if (!_memberNameMissing) count++;
    if (!_memberBirthMissing) count++;
    if (!_memberPhoneMissing) count++;
    if (!_memberEmailMissing) count++;
    if (!_centerNameMissing) count++;
    if (!_trainerNameMissing) count++;

    if (_usePaymentSection) {
      if (!_productNameMissing) count++;
      if (!_unitPriceMissing) count++;
      if (!_sessionCountMissing) count++;
      if (!_priceMissing) count++;
      if (!_paymentDateMissing) count++;
    }

    if (!_contractDateMissing) count++;
    if (!_isUnlimitedEndDate && !_endDateMissing) count++;

    return count;
  }

  double get _requiredProgressValue {
    if (_requiredTotalCount <= 0) return 0;
    return (_requiredCompletedCount / _requiredTotalCount).clamp(0.0, 1.0);
  }

  String get _nextRequiredActionText {
    if (_memberNameMissing) return '회원명을 입력해주세요.';
    if (_memberBirthMissing) return '회원 생년월일을 입력해주세요.';
    if (_memberPhoneMissing) return '회원 연락처를 입력해주세요.';
    if (_memberEmailMissing) return '회원 이메일을 입력해주세요.';
    if (_centerNameMissing) return '센터명을 입력해주세요.';
    if (_trainerNameMissing) return '담당 강사를 입력해주세요.';

    if (_usePaymentSection) {
      if (_productNameMissing) return '수업 상품을 선택해주세요.';
      if (_unitPriceMissing) return '회당 금액을 입력해주세요.';
      if (_sessionCountMissing) return '상품 횟수를 입력해주세요.';
      if (_priceMissing) return '실결제금액을 입력해주세요.';
      if (_paymentDateMissing) return '결제일을 입력해주세요.';
    }

    if (_contractDateMissing) return '계약일을 입력해주세요.';
    if (_endDateMissing) return '종료일을 입력하거나 종료일 설정 안함을 선택해주세요.';
    if (!_isDateRangeValid) return '계약일과 종료일 순서를 확인해주세요.';

    if (_contractStatus == ContractStatus.draft) {
      return '필수정보가 완료되었습니다. 1단계 저장을 눌러주세요.';
    }

    if (_contractStatus == ContractStatus.step1Saved) {
      return '1단계 저장 완료. 다음 단계로 진행할 수 있어요.';
    }

    if (_contractStatus == ContractStatus.signed) {
      return '양측 서명까지 완료되었습니다.';
    }

    return '필수정보가 완료되었습니다.';
  }

  final Set<String> _selectedPainAreas = <String>{};
  final Set<String> _selectedSurgeryTypes = <String>{};
  final Set<String> _selectedAccidentTypes = <String>{};

  static const List<String> _painAreaOptions = [
    '목',
    '어깨',
    '팔꿈치',
    '손목',
    '등',
    '허리',
    '골반',
    '고관절',
    '무릎',
    '발목',
  ];

  static const List<String> _surgeryTypeOptions = [
    '외과',
    '정형외과',
    '신경외과',
    '내과',
    '산부인과',
    '흉부외과',
    '기타',
  ];

  static const List<String> _accidentTypeOptions = [
    '낙상사고',
    '교통사고',
    '찰과상',
    '골절',
    '염좌',
    '타박상',
    '기타',
  ];

  String get _signatureSensitiveSnapshot {
    return [
      _memberNameController.text.trim(),
      _memberBirthController.text.trim(),
      _memberPhoneController.text.trim(),
      _memberEmailController.text.trim(),
      _centerNameController.text.trim(),
      _trainerNameController.text.trim(),
      _productNameController.text.trim(),
      _unitPriceController.text.trim(),
      _sessionCountController.text.trim(),
      _priceController.text.trim(),
      _vatIncluded.toString(),
      _paymentMethod.name,
      _paymentDateController.text.trim(),
      _contractDateController.text.trim(),
      _isUnlimitedEndDate.toString(),
      _isUnlimitedEndDate ? '' : _endDateController.text.trim(),
    ].join('|');
  }

  void _handleSignatureSensitiveChanged() {
    if (_isApplyingProgrammaticChange) return;
    if (_lastSignatureSensitiveSnapshot.isEmpty) {
      _lastSignatureSensitiveSnapshot = _signatureSensitiveSnapshot;
      return;
    }

    final nextSnapshot = _signatureSensitiveSnapshot;

    if (nextSnapshot == _lastSignatureSensitiveSnapshot) return;

    _lastSignatureSensitiveSnapshot = nextSnapshot;

    _clearAllSignaturesBecauseContentChanged();
  }

  Map<String, dynamic> get _step1ContractPayload {
    return {
      'contractNo': _contractNo,
      'memberId': _internalMemberId,
      'memberName': _memberNameController.text.trim(),
      'memberBirth': _memberBirthController.text.trim(),
      'memberPhone': _normalizedMemberPhone,
      'memberPhoneDisplay': _memberPhoneController.text.trim(),
      'memberEmail': _memberEmailController.text.trim(),
      'trainerName': _trainerNameController.text.trim(),
      'centerName': _centerNameController.text.trim(),
      'productId': _selectedProduct?.id,
      'productSnapshot': _selectedProduct?.toContractSnapshot(),
      'productName': _productNameController.text.trim(),
      'sessionCount': _sessionCountValue,
      'unitPrice': _unitPriceValue,
      'totalPrice': _priceValue,
      'vatIncluded': _vatIncluded,
      'paymentMethod': _paymentMethod.name,
      'paymentMethodLabel': _paymentMethodLabel,
      'paymentDate': _paymentDateController.text.trim(),
      'contractDate': _contractDateController.text.trim(),
      'endDate': _isUnlimitedEndDate ? null : _endDateController.text.trim(),
      'unlimitedEndDate': _isUnlimitedEndDate,
      'basicSignature': {
        'memberSigned': _memberSigned,
        'memberSignedAt': _memberSignedAt == null
            ? null
            : Timestamp.fromDate(_memberSignedAt!),
        'memberPoints': _signaturePointsToJson(_memberSignaturePoints),
        'staffSigned': _staffSigned,
        'staffSignedAt':
            _staffSignedAt == null ? null : Timestamp.fromDate(_staffSignedAt!),
        'staffPoints': _signaturePointsToJson(_staffSignaturePoints),
        'meaning': 'basic_contract_terms_confirmation',
        'description': '회원정보, 상품, 금액, 결제방법, 결제일, 계약기간 확인',
      },
      'documentType': _documentType,
      'sourceMode': _sourceMode.name,
      'sourceModeLabel': _sourceModeLabel,
      'stage': _contractStatus.name,
      'status': _contractStatus.name,
      'step1CompletedAt': FieldValue.serverTimestamp(),
      'memberSigned': _memberSigned,
      'memberSignedAt': _memberSigned ? FieldValue.serverTimestamp() : null,
      'staffSigned': _staffSigned,
      'staffSignedAt': _staffSigned ? FieldValue.serverTimestamp() : null,
      'contractSummary': {
        'memberName': _memberNameController.text.trim(),
        'productName': _productNameController.text.trim(),
        'totalPrice': _priceValue,
        'contractDate': _contractDateController.text.trim(),
        'paymentMethodLabel': _paymentMethodLabel,
      },
      'updatedAt': FieldValue.serverTimestamp(),
      'serverTimestamp': FieldValue.serverTimestamp(),
    };
  }

  Future<bool> _saveStep1Contract() async {
    if (_isSavingContract) return false;

    final errors = <String>[];

    if (!_isBasicInfoComplete) {
      errors.add('기본정보를 모두 입력해주세요.');
    }

    if (!_isPaymentSectionComplete) {
      errors.add('결제정보를 확인해주세요.');
    }

    if (!_isDateRangeValid) {
      errors.add('계약일과 종료일 순서를 확인해주세요.');
    }

    final phoneAvailable = await _ensureMemberPhoneIsNotDuplicated();

    if (!phoneAvailable) {
      return false;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      _contractId ??= firestore.collection('contracts').doc().id;
      _contractNo ??= await _generateContractNo();

      final nextStatus = _memberSigned && _staffSigned
          ? ContractStatus.signed
          : ContractStatus.step1Saved;

      final step1Payload = {
        ..._step1ContractPayload,
        'stage': nextStatus.name,
        'status': nextStatus.name,
      };

      final contractRef = firestore.collection('contracts').doc(_contractId);
      final memberRef = firestore.collection('members').doc(_internalMemberId);

      await firestore.runTransaction((transaction) async {
        transaction.set(
          contractRef,
          {
            ...step1Payload,
            'createdAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        transaction.set(
          memberRef,
          {
            'id': _internalMemberId,
            'name': _memberNameController.text.trim(),
            'phone': _normalizedMemberPhone,
            'phoneDisplay': _memberPhoneController.text.trim(),
            'email': _memberEmailController.text.trim(),
            'birth': _memberBirthController.text.trim(),
            'contractId': _contractId,
            'contractNo': _contractNo,
            'contractSigned': _memberSigned && _staffSigned,
            'contractSignedAt': (_memberSigned && _staffSigned)
                ? FieldValue.serverTimestamp()
                : null,
            'lastContractSummary': {
              'contractId': _contractId,
              'contractNo': _contractNo,
              'productName': _productNameController.text.trim(),
              'totalPrice': _priceValue,
              'paymentMethodLabel': _paymentMethodLabel,
              'contractDate': _contractDateController.text.trim(),
            },
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      });

      if (!mounted) return true;

      setState(() {
        _contractStatus = nextStatus;
        _draftSaved = true;
        _shouldReturnSavedToCaller = true;
      });

      await _requestMoreCareSlotAfterContractSaved(_internalMemberId);

      if (!mounted) return true;

      _showSnack('계약서 1단계를 저장했어요. 계약번호: $_contractNo');
      return true;
    } catch (e) {
      if (!mounted) return false;

      _showSnack('계약서 저장에 실패했어요: $e');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSavingContract = false;
        });
      }
    }
  }

  Future<void> _loadExistingContract(String contractId) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('contracts')
          .doc(contractId)
          .get();

      final data = snap.data();
      if (data == null) {
        _showSnack('계약서 정보를 찾지 못했어요.');
        return;
      }

      if (!mounted) return;

      _isApplyingProgrammaticChange = true;

      setState(() {
        _contractId = contractId;
        _contractNo = (data['contractNo'] ?? '').toString().trim().isEmpty
            ? null
            : (data['contractNo'] ?? '').toString().trim();

        _internalMemberId = (data['memberId'] ?? widget.memberId).toString();

        _memberNameController.text =
            (data['memberName'] ?? widget.memberName).toString();
        _memberBirthController.text = (data['memberBirth'] ?? '').toString();
        _memberPhoneController.text =
            (data['memberPhoneDisplay'] ?? data['memberPhone'] ?? '')
                .toString();
        _memberEmailController.text = (data['memberEmail'] ?? '').toString();

        _trainerNameController.text =
            (data['trainerName'] ?? widget.trainerName).toString();
        _centerNameController.text =
            (data['centerName'] ?? _centerNameController.text).toString();

        _productNameController.text = (data['productName'] ?? '').toString();
        _sessionCountController.text =
            ((data['sessionCount'] ?? '').toString().isEmpty)
                ? _sessionCountController.text
                : (data['sessionCount'] ?? '').toString();

        final unitPrice = (data['unitPrice'] as num?)?.toInt() ?? 0;
        final totalPrice = (data['totalPrice'] as num?)?.toInt() ?? 0;

        if (unitPrice > 0) {
          _unitPriceController.text = _formatMoney(unitPrice);
        }

        if (totalPrice > 0) {
          _priceController.text = _formatMoney(totalPrice);
        }

        _vatIncluded = data['vatIncluded'] == true;

        final paymentMethodRaw = (data['paymentMethod'] ?? '').toString();
        _paymentMethod = PaymentMethod.values.firstWhere(
          (e) => e.name == paymentMethodRaw,
          orElse: () => PaymentMethod.card,
        );

        _paymentDateController.text = (data['paymentDate'] ?? '').toString();
        _contractDateController.text = (data['contractDate'] ?? '').toString();

        _isUnlimitedEndDate = data['unlimitedEndDate'] == true;
        _endDateController.text = (data['endDate'] ?? '').toString();

        final sourceModeRaw = (data['sourceMode'] ?? '').toString();
        _sourceMode = ContractSourceMode.values.firstWhere(
          (e) => e.name == sourceModeRaw,
          orElse: () => _sourceMode,
        );

        final documentType = (data['documentType'] ?? '').toString().trim();
        if (documentType.isNotEmpty) {
          _documentType = documentType;
        }

        final clauses = data['clauses'] is Map
            ? Map<String, dynamic>.from(data['clauses'] as Map)
            : <String, dynamic>{};

        _useLessonClause = clauses['useLessonClause'] != false;
        _useReservationClause = clauses['useReservationClause'] != false;
        _useHoldClause = clauses['useHoldClause'] == true;
        _usePenaltyClause = clauses['usePenaltyClause'] != false;
        _useTransferClause = clauses['useTransferClause'] == true;

        final basicSignature = data['basicSignature'] is Map
            ? Map<String, dynamic>.from(data['basicSignature'] as Map)
            : <String, dynamic>{};

        _memberSignaturePoints =
            _signaturePointsFromJson(basicSignature['memberPoints']);
        _staffSignaturePoints =
            _signaturePointsFromJson(basicSignature['staffPoints']);

        final memberSignedAtRaw = basicSignature['memberSignedAt'];
        final staffSignedAtRaw = basicSignature['staffSignedAt'];

        _memberSignedAt =
            memberSignedAtRaw is Timestamp ? memberSignedAtRaw.toDate() : null;

        _staffSignedAt =
            staffSignedAtRaw is Timestamp ? staffSignedAtRaw.toDate() : null;

        final finalSignature = data['finalSignature'] is Map
            ? Map<String, dynamic>.from(data['finalSignature'] as Map)
            : <String, dynamic>{};

        _memberFinalSignaturePoints =
            _signaturePointsFromJson(finalSignature['memberPoints']);
        _staffFinalSignaturePoints =
            _signaturePointsFromJson(finalSignature['staffPoints']);

        final memberFinalSignedAtRaw = finalSignature['memberSignedAt'];
        final staffFinalSignedAtRaw = finalSignature['staffSignedAt'];

        _memberFinalSignedAt = memberFinalSignedAtRaw is Timestamp
            ? memberFinalSignedAtRaw.toDate()
            : null;

        _staffFinalSignedAt = staffFinalSignedAtRaw is Timestamp
            ? staffFinalSignedAtRaw.toDate()
            : null;

        final agreements = data['agreements'] is Map
            ? Map<String, dynamic>.from(data['agreements'] as Map)
            : <String, dynamic>{};

        _agreeLessonClause = agreements['agreeLessonClause'] == true;
        _agreeReservationClause = agreements['agreeReservationClause'] == true;
        _agreeHoldClause = agreements['agreeHoldClause'] == true;
        _agreePenaltyClause = agreements['agreePenaltyClause'] == true;
        _agreeTransferClause = agreements['agreeTransferClause'] == true;
        _agreeHealthNotice = agreements['agreeHealthNotice'] == true;
        _agreeImportantNotice = agreements['agreeImportantNotice'] == true;
        _agreeSameContentSave = agreements['agreeSameContentSave'] == true;

        final healthInfo = data['healthInfo'] is Map
            ? Map<String, dynamic>.from(data['healthInfo'] as Map)
            : <String, dynamic>{};

        _healthPain = healthInfo['healthPain'] == true;
        _healthSurgery = healthInfo['healthSurgery'] == true;
        _healthAccident = healthInfo['healthAccident'] == true;
        _healthPregnancy = healthInfo['healthPregnancy'] == true;
        _healthRehab = healthInfo['healthRehab'] == true;
        _healthNone = healthInfo['healthNone'] != false;

        _selectedPainAreas
          ..clear()
          ..addAll(
            ((healthInfo['painAreas'] as List?) ?? const [])
                .map((e) => e.toString()),
          );

        _selectedSurgeryTypes
          ..clear()
          ..addAll(
            ((healthInfo['surgeryTypes'] as List?) ?? const [])
                .map((e) => e.toString()),
          );

        _selectedAccidentTypes
          ..clear()
          ..addAll(
            ((healthInfo['accidentTypes'] as List?) ?? const [])
                .map((e) => e.toString()),
          );

        _healthDetailController.text = (healthInfo['detail'] ?? '').toString();

        final delivery = data['delivery'] is Map
            ? Map<String, dynamic>.from(data['delivery'] as Map)
            : <String, dynamic>{};

        final deliveryMethodRaw = (delivery['method'] ?? '').toString();

        _deliveryMethod = ContractDeliveryMethod.values.firstWhere(
          (e) => e.name == deliveryMethodRaw,
          orElse: () => ContractDeliveryMethod.email,
        );

        final status = (data['status'] ?? data['stage'] ?? '').toString();

        _contractStatus = ContractStatus.values.firstWhere(
          (e) => e.name == status,
          orElse: () {
            if (status == 'completed') return ContractStatus.signed;
            return ContractStatus.draft;
          },
        );

        _draftSaved = status == 'draft' ||
            status == 'step1Saved' ||
            status == 'completed' ||
            status == 'signed';

        _currentStage = status == 'draft' || status == 'step1Saved'
            ? ContractStage.requiredInfo
            : ContractStage.detailConfirm;
      });

      _isApplyingProgrammaticChange = false;

      _lastSignatureSensitiveSnapshot = _signatureSensitiveSnapshot;
      _lastDetailSignatureSnapshot = _detailSignatureSnapshot;

      _showSnack('저장된 계약서를 불러왔어요.');
    } catch (e) {
      _isApplyingProgrammaticChange = false;

      if (!mounted) return;
      _showSnack('계약서 불러오기에 실패했어요: $e');
    }
  }

  Future<void> _openLessonProductPicker() async {
    List<ProductModel> products = [];

    try {
      products = await LessonProductService.fetchProducts();
    } catch (e) {
      debugPrint('레슨 상품 불러오기 실패: $e');

      if (!mounted) return;

      AifcInteraction.toast(
        context: context,
        message: '레슨 상품을 불러오지 못했어요.',
        bottomOffset: 110,
      );
      return;
    }

    if (!mounted) return;

    if (products.isEmpty) {
      AifcInteraction.toast(
        context: context,
        message: '아직 등록된 레슨 상품이 없어요. 마이페이지에서 먼저 추가해주세요.',
        bottomOffset: 110,
      );
      return;
    }

    final selected = await showModalBottomSheet<ProductModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (_) => _LessonProductPickerSheet(
        products: products,
      ),
    );

    if (!mounted) return;
    if (selected == null) return;

    _applyProduct(selected);
  }

  Future<String> _generateContractNo() async {
    final now = DateTime.now();
    final yearMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final counterRef = FirebaseFirestore.instance
        .collection('contractCounters')
        .doc(yearMonth);

    final nextSeq = await FirebaseFirestore.instance.runTransaction<int>(
      (transaction) async {
        final snapshot = await transaction.get(counterRef);

        final current = snapshot.exists
            ? ((snapshot.data()?['lastSeq'] as num?)?.toInt() ?? 0)
            : 0;

        final next = current + 1;

        transaction.set(
          counterRef,
          {
            'lastSeq': next,
            'yearMonth': yearMonth,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );

        return next;
      },
    );

    final seqText = nextSeq.toString().padLeft(3, '0');
    return 'MTF-$yearMonth-$seqText';
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;

    setState(() {
      _isLoadingProducts = true;
    });

    try {
      final products = await LessonProductService.fetchProducts();

      if (!mounted) return;

      setState(() {
        _products = products;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('수업 상품을 불러오지 못했어요.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingProducts = false;
        });
      }
    }
  }

  final TextEditingController _healthDetailController = TextEditingController();

// 최종 확인
  bool _agreeSameContentSave = false;
  bool _agreeImportantNotice = false;
  ContractDeliveryMethod _deliveryMethod = ContractDeliveryMethod.email;

  // 더미 상태
  bool _pdfSaved = false;
  bool _pdfSentToCustomer = false;
  bool _pdfSentToTrainer = false;

  // 전자서명

  List<Offset?>? _memberFinalSignaturePoints;
  List<Offset?>? _staffFinalSignaturePoints;
  DateTime? _memberFinalSignedAt;
  DateTime? _staffFinalSignedAt;

  List<Offset?>? _memberSignaturePoints;
  List<Offset?>? _staffSignaturePoints;
  DateTime? _memberSignedAt;
  DateTime? _staffSignedAt;

  bool get _memberSigned =>
      _memberSignaturePoints != null &&
      _memberSignaturePoints!.any((e) => e != null);

  bool get _staffSigned =>
      _staffSignaturePoints != null &&
      _staffSignaturePoints!.any((e) => e != null);

  bool get _isSignedCompleted => _memberSigned && _staffSigned;

// 기본 서명만으로는 잠그지 않고, 최종 서명 완료 후 잠급니다.
  bool get _isFormLocked => _isFinalSignedCompleted;

  bool get _memberFinalSigned =>
      _memberFinalSignaturePoints != null &&
      _memberFinalSignaturePoints!.any((e) => e != null);

  bool get _staffFinalSigned =>
      _staffFinalSignaturePoints != null &&
      _staffFinalSignaturePoints!.any((e) => e != null);

  bool get _isFinalSignedCompleted => _memberFinalSigned && _staffFinalSigned;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_verifyCreationGate());
    });

    _currentStage = widget.initialStage;

    _internalMemberId = widget.memberId.trim().isNotEmpty
        ? widget.memberId
        : _generateInternalMemberId();

    _sourceMode = _ContractUiMemory.lastSourceMode;
    _documentType = _ContractUiMemory.lastDocumentType;

    _vatIncluded = _ContractUiMemory.vatIncluded;
    _isUnlimitedEndDate = _ContractUiMemory.unlimitedEndDate;

    _useLessonClause = _ContractUiMemory.useLessonClause;
    _useReservationClause = _ContractUiMemory.useReservationClause;
    _useHoldClause = _ContractUiMemory.useHoldClause;
    _usePenaltyClause = _ContractUiMemory.usePenaltyClause;
    _useTransferClause = _ContractUiMemory.useTransferClause;

    _memberNameController = TextEditingController(text: widget.memberName);
    _trainerNameController = TextEditingController(
      text: _normalizeContractNickname(widget.trainerName),
    );

    _trainerNameController.addListener(_handleTrainerNameEditedManually);

    final isPersonalContract =
        (widget.personalOwnerUid ?? '').trim().isNotEmpty;
    if (!isPersonalContract) {
      unawaited(_loadTrainerNameFromProfileForContract());
    }

    final now = DateTime.now();
    final end = DateTime(now.year, now.month + 3, now.day);

    _contractDateController.text = _formatDate(now);
    _paymentDateController.text = _formatDate(now);
    _endDateController.text = _formatDate(end);

    _supportMessage = _pickRandomSupportMessage();
    _fillHybridClausesFromTemplate(force: true);
    if (!isPersonalContract) {
      _loadProducts();
    }

    _livePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    if (widget.contractId != null && widget.contractId!.trim().isNotEmpty) {
      unawaited(_loadExistingContract(widget.contractId!.trim()));
    }

    _livePulseAnimation = Tween<double>(
      begin: 0.35,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _livePulseController,
        curve: Curves.easeInOut,
      ),
    );

    final controllers = <TextEditingController>[
      _memberNameController,
      _memberBirthController,
      _memberPhoneController,
      _memberEmailController,
      _centerNameController,
      _trainerNameController,
      _productNameController,
      _unitPriceController,
      _sessionCountController,
      _priceController,
      _contractDateController,
      _paymentDateController,
      _endDateController,
      _customMainClauseController,
      _customExtraClauseController,
      _sessionMinutesController,
      _cancelHoursController,
      _lessonDelayMinutesController,
      _holdCountController,
      _holdDaysController,
      _suspensionRuleController,
      _penaltyPercentController,
      _transferRuleController,
      _healthDetailController,
      _hybridLessonClauseController,
      _hybridReservationClauseController,
      _hybridHoldClauseController,
      _hybridPenaltyClauseController,
      _hybridTransferClauseController,
    ];

    final signatureSensitiveControllers = <TextEditingController>{
      _memberNameController,
      _memberBirthController,
      _memberPhoneController,
      _memberEmailController,
      _centerNameController,
      _trainerNameController,
      _productNameController,
      _unitPriceController,
      _sessionCountController,
      _priceController,
      _paymentDateController,
      _contractDateController,
      _endDateController,
    };

    _lastSignatureSensitiveSnapshot = _signatureSensitiveSnapshot;

    final detailSignatureSensitiveControllers = <TextEditingController>{
      _customMainClauseController,
      _customExtraClauseController,
      _sessionMinutesController,
      _cancelHoursController,
      _lessonDelayMinutesController,
      _holdCountController,
      _holdDaysController,
      _suspensionRuleController,
      _penaltyPercentController,
      _transferRuleController,
      _healthDetailController,
      _hybridLessonClauseController,
      _hybridReservationClauseController,
      _hybridHoldClauseController,
      _hybridPenaltyClauseController,
      _hybridTransferClauseController,
    };

    _lastSignatureSensitiveSnapshot = _signatureSensitiveSnapshot;
    _lastDetailSignatureSnapshot = _detailSignatureSnapshot;

    for (final c in controllers) {
      c.addListener(() {
        if (!mounted) return;

        if (signatureSensitiveControllers.contains(c)) {
          _handleSignatureSensitiveChanged();
        }

        if (detailSignatureSensitiveControllers.contains(c)) {
          _handleDetailSignatureSensitiveChanged();
        }

        if (c == _memberPhoneController &&
            _memberPhoneDuplicateMessage != null) {
          _memberPhoneDuplicateMessage = null;
        }

        setState(() {});
      });
    }
  }

  Future<void> _verifyCreationGate() async {
    final uid = (widget.personalOwnerUid ?? '').trim();
    final isNewContract = (widget.contractId ?? '').trim().isEmpty;
    if (uid.isEmpty || !isNewContract) {
      if (mounted) setState(() => _creationGateResolved = true);
      return;
    }
    try {
      final allowed = await AifcTierFeatureGateSheet.guard(
        context: context,
        access: null,
        feature: AppTierFeatureKey.contract,
        loadAccess: () => AppTierAccessService.loadPersonalTrainerAccess(
          uid: uid,
        ),
        entryPoint: 'contract_page_direct_create',
      );
      if (!mounted) return;
      if (!allowed) {
        Navigator.of(context).pop();
        return;
      }
      setState(() => _creationGateResolved = true);
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _tipTimer?.cancel();
    _removeTipOverlay();

    _livePulseController.dispose();
    _scrollController.dispose();
    _productNameFocusNode.dispose();

    _memberNameController.dispose();
    _memberBirthController.dispose();
    _memberPhoneController.dispose();
    _memberEmailController.dispose();

    _centerNameController.dispose();
    _trainerNameController.removeListener(_handleTrainerNameEditedManually);
    _trainerNameController.dispose();

    _productNameController.dispose();
    _unitPriceController.dispose();
    _sessionCountController.dispose();
    _priceController.dispose();
    _contractDateController.dispose();
    _paymentDateController.dispose();
    _endDateController.dispose();

    _customMainClauseController.dispose();
    _customExtraClauseController.dispose();

    _sessionMinutesController.dispose();
    _cancelHoursController.dispose();
    _lessonDelayMinutesController.dispose();
    _holdCountController.dispose();
    _holdDaysController.dispose();
    _suspensionRuleController.dispose();
    _penaltyPercentController.dispose();
    _transferRuleController.dispose();

    _healthDetailController.dispose();
    _hybridLessonClauseController.dispose();
    _hybridReservationClauseController.dispose();
    _hybridHoldClauseController.dispose();
    _hybridPenaltyClauseController.dispose();
    _hybridTransferClauseController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final requiresGate = (widget.personalOwnerUid ?? '').trim().isNotEmpty &&
        (widget.contractId ?? '').trim().isEmpty;
    if (requiresGate && !_creationGateResolved) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double width =
            isTablet ? kContractMaxContentWidth : constraints.maxWidth;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          child: WillPopScope(
            onWillPop: _handleContractWillPop,
            child: Scaffold(
              extendBody: true,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: Center(
                child: SizedBox(
                  width: width,
                  child: Column(
                    children: [
                      _buildHeader(),
                      Expanded(
                        child: _buildEditView(),
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

  // -------------------- HEADER --------------------

  Widget _buildHeader() {
    final double topInset = MediaQuery.of(context).padding.top;
    final gradient = context.mtfHeaderGradient;

    return MtfHeaderNeonOverlay(
      isExpanded: false,
      intensity: 0.52,
      strokeWidth: 1.6,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: topInset + 16,
          left: 24,
          right: 24,
          bottom: 14,
        ),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(32),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: _closeContractPage,
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
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '개인레슨 계약서',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                _HeaderCircleIconButton(
                  icon: Icons.remove_red_eye_outlined,
                  tooltip: '미리보기',
                  onTap: _showPreviewSheet,
                ),
                const SizedBox(width: 6),
                MtfFloatingMoreMenuButton<_ContractMoreAction>(
                  tooltip: '더보기',
                  icon: Icons.more_horiz_rounded,
                  iconColor: Colors.white,
                  iconSize: 20,
                  cardWidth: 230,
                  offset: const Offset(0, 8),
                  onSelected: _handleMoreMenuAction,
                  items: [
                    MtfMoreMenuItem(
                      value: _ContractMoreAction.documentType,
                      icon: Icons.article_outlined,
                      label: '문서종류',
                      subLabel: _documentType,
                    ),
                    MtfMoreMenuItem(
                      value: _ContractMoreAction.sourceMode,
                      icon: Icons.tune_rounded,
                      label: '작성방식',
                      subLabel: _sourceModeLabel,
                    ),
                    MtfMoreMenuItem(
                      value: _ContractMoreAction.tempSave,
                      icon: _draftSaved
                          ? Icons.bookmark_added_rounded
                          : Icons.bookmark_border_rounded,
                      label: _draftSaved ? '임시저장됨' : '임시저장',
                      subLabel: _draftSaved ? '최근 저장 상태' : '작성 중 문서 저장',
                      isSelected: _draftSaved,
                    ),
                    const MtfMoreMenuItem(
                      value: _ContractMoreAction.savePdf,
                      icon: Icons.picture_as_pdf_outlined,
                      label: 'PDF 저장',
                      subLabel: '계약서 파일 저장',
                    ),
                    const MtfMoreMenuItem(
                      value: _ContractMoreAction.sendCustomer,
                      icon: Icons.send_rounded,
                      label: '고객 전송',
                      subLabel: '회원에게 보내기',
                    ),
                    const MtfMoreMenuItem(
                      value: _ContractMoreAction.sendTrainer,
                      icon: Icons.forward_to_inbox_rounded,
                      label: '강사 전송',
                      subLabel: '내 메일로 보내기',
                    ),
                    if (_isSignedCompleted)
                      const MtfMoreMenuItem(
                        value: _ContractMoreAction.newVersion,
                        icon: Icons.copy_outlined,
                        label: '새 버전 작성',
                        subLabel: '완료 계약서 복사',
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _supportMessages.contains(_supportMessage)
                        ? _supportMessage
                        : '어려운 결정과 다짐을 지지하고 응원합니다.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _buildContractHeaderProgress(),
          ],
        ),
      ),
    );
  }

  Widget _buildContractHeaderProgress() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxBarWidth = constraints.maxWidth * 0.72;
        final double barWidth = maxBarWidth.clamp(180.0, 280.0);
        final double progress = _headerProgressValue.clamp(0.0, 1.0);

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: barWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.45),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        _compactCurrentStepIcon,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_headerCompletedCount/$_headerTotalCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      '다음',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Stack(
                  children: [
                    Container(
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.20),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  _headerNextStepLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStageSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _StageTabButton(
              title: '필수 작성',
              subtitle: '기본 · 결제 · 기본서명',
              selected: _currentStage == ContractStage.requiredInfo,
              enabled: true,
              done: _isStep1Saved,
              onTap: () {
                setState(() {
                  _currentStage = ContractStage.requiredInfo;
                });
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _StageTabButton(
              title: '상세 확인',
              subtitle: '조건 · 건강 · 최종서명',
              selected: _currentStage == ContractStage.detailConfirm,
              enabled: true,
              muted: !_canOpenDetailConfirm,
              done: _isContractConditionsComplete &&
                  _isHealthSectionComplete &&
                  _isFinalConfirmComplete &&
                  _isFinalSignedCompleted,
              onTap: () {
                setState(() {
                  _currentStage = ContractStage.detailConfirm;
                });

                if (!_canOpenDetailConfirm) {
                  _showSnack('필수 작성 전에도 상세 확인 항목을 미리 볼 수 있어요.');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStageInfoCard() {
    final bool isStep1 = _currentStage == ContractStage.requiredInfo;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isStep1
              ? const [
                  Color(0xFFEEF2FF),
                  Color(0xFFF5F3FF),
                ]
              : const [
                  Color(0xFFF0FDF4),
                  Color(0xFFECFEFF),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isStep1 ? const Color(0xFFC7D2FE) : const Color(0xFFBBF7D0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isStep1
                  ? const Color(0xFF4F46E5).withOpacity(0.10)
                  : const Color(0xFF059669).withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isStep1 ? Icons.assignment_outlined : Icons.fact_check_outlined,
              color:
                  isStep1 ? const Color(0xFF4F46E5) : const Color(0xFF059669),
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _stageTitle,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _stageSubtitle,
                  style: const TextStyle(
                    fontSize: 11.8,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1View() {
    return Column(
      children: [
        KeyedSubtree(
          key: _basicInfoSectionKey,
          child: _buildBasicInfoSection(),
        ),
        const SizedBox(height: 14),
        KeyedSubtree(
          key: _paymentSectionKey,
          child: _buildPersonalLessonPaymentSection(),
        ),
        const SizedBox(height: 14),
        KeyedSubtree(
          key: _signatureSectionKey,
          child: _buildSignatureSection(),
        ),
        const SizedBox(height: 18),
        _buildStep1BottomActions(),
      ],
    );
  }

  Widget _buildDetailPreviewNotice() {
    if (_canOpenDetailConfirm) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.visibility_outlined,
              color: Color(0xFF6B7280),
              size: 19,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '상세 확인 항목 미리보기',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF374151),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '필수 작성이 완료되기 전에도 어떤 항목을 확인해야 하는지 미리 볼 수 있습니다. 최종 저장은 필수 작성 완료 후 가능합니다.',
                  style: TextStyle(
                    fontSize: 11.8,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2View() {
    return Column(
      children: [
        _buildDetailPreviewNotice(),
        if (!_canOpenDetailConfirm) const SizedBox(height: 14),
        KeyedSubtree(
          key: _contractSectionKey,
          child: _buildContractConditionSection(),
        ),
        const SizedBox(height: 14),
        _buildContractHistorySection(),
        const SizedBox(height: 14),
        KeyedSubtree(
          key: _healthSectionKey,
          child: _buildHealthSection(),
        ),
        const SizedBox(height: 14),
        KeyedSubtree(
          key: _finalSectionKey,
          child: _buildFinalConfirmSection(),
        ),
        const SizedBox(height: 14),
        _buildFinalSignatureSection(),
        const SizedBox(height: 18),
        _buildStep2BottomActions(),
      ],
    );
  }

  Widget _buildStep1BottomActions() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: kContractCardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kContractBorderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(
                _isStep1Saved
                    ? '1단계가 저장되었습니다. 2단계에서 계약조건과 건강고지를 이어서 작성할 수 있어요.'
                    : '기본정보와 결제정보를 입력한 뒤 1단계를 저장해주세요.',
                style: const TextStyle(
                  fontSize: 12.3,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF475569),
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSavingContract ? null : _handleTempSave,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: Icon(
                      _draftSaved
                          ? Icons.bookmark_added_rounded
                          : Icons.bookmark_border_rounded,
                    ),
                    label: Text(
                      _isSavingContract
                          ? '저장 중...'
                          : (_draftSaved ? '임시저장됨' : '임시저장'),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSavingContract
                        ? null
                        : () async {
                            final saved = await _saveStep1Contract();

                            if (!mounted || !saved) return;

                            setState(() {
                              _currentStage = ContractStage.detailConfirm;
                            });
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.secondary,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      _isSavingContract
                          ? '저장 중...'
                          : (_isStep1Saved ? '2단계로 이동' : '1단계 저장'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2BottomActions() {
    final bool ready = _isContractConditionsComplete &&
        _isHealthSectionComplete &&
        _isFinalConfirmComplete &&
        _isFinalSignedCompleted;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: kContractCardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kContractBorderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              decoration: BoxDecoration(
                color:
                    ready ? const Color(0xFFECFDF5) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      ready ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB),
                ),
              ),
              child: Text(
                ready
                    ? '상세 확인 항목과 최종 서명이 완료되었습니다. 최종 저장할 수 있어요.'
                    : '계약조건, 건강고지, 최종확인, 최종서명을 완료해주세요.',
                style: TextStyle(
                  fontSize: 12.3,
                  fontWeight: FontWeight.w700,
                  color:
                      ready ? const Color(0xFF047857) : const Color(0xFF475569),
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _currentStage = ContractStage.requiredInfo;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: Color(0xFFD1D5DB)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('필수 작성으로'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSavingContract
                        ? null
                        : () async {
                            if (!_canOpenDetailConfirm) {
                              setState(() {
                                _showRequiredErrors = true;
                                _currentStage = ContractStage.requiredInfo;
                              });
                              _showSnack('필수 작성을 먼저 완료해주세요.');
                              return;
                            }

                            await _saveStep2Contract();
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(
                      _isSavingContract ? '저장 중...' : '상세 확인 완료',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveStep2Contract() async {
    if (_isSavingContract) return;

    final errors = <String>[];

    if (!_isStep1Saved && !_isStep1Ready) {
      errors.add('1단계 필수정보를 먼저 저장해주세요.');
    }

    if (!_isContractConditionsComplete) {
      errors.add('계약 조건 확인 항목에 동의가 필요합니다.');
    }

    if (!_isHealthSelectionComplete) {
      errors.add('건강 고지 세부 선택을 완료해주세요.');
    }

    if (!_isHealthSectionComplete) {
      errors.add('건강안내박스 숙지 체크가 필요합니다.');
    }

    if (!_isFinalConfirmComplete) {
      errors.add('최종 확인 체크가 필요합니다.');
    }

    if (!_memberFinalSigned) {
      errors.add('회원 최종 동의 서명이 필요합니다.');
    }

    if (!_staffFinalSigned) {
      errors.add('강사 최종 확인 서명이 필요합니다.');
    }

    if (errors.isNotEmpty) {
      _showSnack(errors.first);
      return;
    }

    if (!_isStep1Saved) {
      final step1Saved = await _saveStep1Contract();

      if (!mounted || !step1Saved) {
        return;
      }
    }

    setState(() {
      _isSavingContract = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      _contractId ??= firestore.collection('contracts').doc().id;
      _contractNo ??= await _generateContractNo();

      final contractRef = firestore.collection('contracts').doc(_contractId);

      await contractRef.set(
        {
          ..._step1ContractPayload,
          'clauses': {
            'items': _contractHistoryItems,
            'useLessonClause': _useLessonClause,
            'useReservationClause': _useReservationClause,
            'useHoldClause': _useHoldClause,
            'usePenaltyClause': _usePenaltyClause,
            'useTransferClause': _useTransferClause,
          },
          'agreements': {
            'agreeLessonClause': _agreeLessonClause,
            'agreeReservationClause': _agreeReservationClause,
            'agreeHoldClause': _agreeHoldClause,
            'agreePenaltyClause': _agreePenaltyClause,
            'agreeTransferClause': _agreeTransferClause,
            'agreeHealthNotice': _agreeHealthNotice,
            'agreeImportantNotice': _agreeImportantNotice,
            'agreeSameContentSave': _agreeSameContentSave,
          },
          'delivery': {
            'method': _deliveryMethod.name,
            'methodLabel': _deliveryMethodLabel,
            'target': _deliveryTarget,
            'status': 'requested',
            'requestedAt': FieldValue.serverTimestamp(),
            'sentAt': null,
          },
          'finalSignature': {
            'memberSigned': _memberFinalSigned,
            'memberSignedAt': _memberFinalSignedAt == null
                ? null
                : Timestamp.fromDate(_memberFinalSignedAt!),
            'memberPoints': _signaturePointsToJson(_memberFinalSignaturePoints),
            'staffSigned': _staffFinalSigned,
            'staffSignedAt': _staffFinalSignedAt == null
                ? null
                : Timestamp.fromDate(_staffFinalSignedAt!),
            'staffPoints': _signaturePointsToJson(_staffFinalSignaturePoints),
            'meaning': 'full_contract_terms_confirmation',
            'description': '계약조건, 환불/중도해지, 예약/노쇼, 건강고지, 최종확인 동의',
          },
          'finalSigned': _isFinalSignedCompleted,
          'finalSignedAt':
              _isFinalSignedCompleted ? FieldValue.serverTimestamp() : null,
          'healthInfo': {
            'healthPain': _healthPain,
            'healthSurgery': _healthSurgery,
            'healthAccident': _healthAccident,
            'healthPregnancy': _healthPregnancy,
            'healthRehab': _healthRehab,
            'healthNone': _healthNone,
            'painAreas': _selectedPainAreas.toList(),
            'surgeryTypes': _selectedSurgeryTypes.toList(),
            'accidentTypes': _selectedAccidentTypes.toList(),
            'detail': _healthDetailController.text.trim(),
            'summary': _healthSummary,
          },
          'stage': 'completed',
          'status': 'completed',
          'step2CompletedAt': FieldValue.serverTimestamp(),
          'completedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _contractStatus = ContractStatus.signed;
      });

      _lastDetailSignatureSnapshot = _detailSignatureSnapshot;

      await _requestMoreCareSlotAfterContractSaved(_internalMemberId);

      if (!mounted) return;

      _showSnack('레슨계약서 상세정보를 최종 저장했어요.');

      unawaited(_offerClientCardAutoRegistrationIfNeeded());
    } catch (e) {
      if (!mounted) return;
      _showSnack('최종 저장에 실패했어요: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingContract = false;
        });
      }
    }
  }

  Widget _buildEditView() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(
        kContractPageHorizontalPadding,
        16,
        kContractPageHorizontalPadding,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStageSelector(),
          const SizedBox(height: 14),
          _buildCurrentStageInfoCard(),
          const SizedBox(height: 14),
          if (_currentStage == ContractStage.requiredInfo)
            _buildStep1View()
          else
            _buildStep2View(),
        ],
      ),
    );
  }

  // -------------------- BODY --------------------

  // -------------------- SECTION : 기본 정보 --------------------

  Widget _buildBasicInfoSection() {
    return _buildSectionCard(
      title: '기본정보',
      icon: Icons.badge_outlined,
      subtitle: '회원과 강사 정보를 먼저 입력합니다.',
      child: Column(
        children: [
          _buildTextField(
            controller: _memberNameController,
            label: '회원명',
            hint: '모어댄',
            enabled: !_isFormLocked,
            showError: _shouldShowMemberNameError,
            errorText: '회원명을 입력해주세요.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _memberBirthController,
            keyboardType: TextInputType.number,
            enabled: !_isFormLocked,
            inputFormatters: const [
              _BirthDateInputFormatter(),
            ],
            decoration: InputDecoration(
              labelText: '회원 생년월일',
              hintText: '예: 1980-01-01',
              errorText: (_shouldShowMemberBirthError ||
                      _shouldShowMemberBirthFormatError)
                  ? _memberBirthErrorText
                  : null,
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                onPressed: _isFormLocked ? null : _pickBirthDate,
              ),
              filled: true,
              fillColor: !_isFormLocked
                  ? const Color(0xFFF9FAFB)
                  : const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: (_shouldShowMemberBirthError ||
                          _shouldShowMemberBirthFormatError)
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFE5E7EB),
                  width: (_shouldShowMemberBirthError ||
                          _shouldShowMemberBirthFormatError)
                      ? 1.4
                      : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: (_shouldShowMemberBirthError ||
                          _shouldShowMemberBirthFormatError)
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF4F46E5),
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _memberPhoneController,
            label: '회원 연락처',
            hint: '010-1234-5678',
            keyboardType: TextInputType.phone,
            enabled: !_isFormLocked,
            showError: _shouldShowMemberPhoneError ||
                _shouldShowMemberPhoneFormatError ||
                _memberPhoneDuplicateMessage != null,
            errorText: _memberPhoneErrorText,
            inputFormatters: const [
              _PhoneInputFormatter(),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _memberEmailController,
            label: '회원 이메일',
            hint: 'example@email.com',
            keyboardType: TextInputType.emailAddress,
            enabled: !_isFormLocked,
            showError: _shouldShowMemberEmailError ||
                _shouldShowMemberEmailFormatError,
            errorText: _memberEmailMissing
                ? '계약서 발송용 이메일을 입력해주세요.'
                : '이메일 형식을 확인해주세요.',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _centerNameController,
            label: '센터명',
            enabled: !_isFormLocked,
            showError: _shouldShowCenterNameError,
            errorText: '센터명을 입력해주세요.',
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _trainerNameController,
            label: '담당 강사',
            enabled: !_isFormLocked,
            showError: _shouldShowTrainerNameError,
            errorText: '담당 강사를 입력해주세요.',
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalLessonPaymentSection() {
    return _buildSectionCard(
      title: '개인레슨 결제정보',
      icon: Icons.payments_outlined,
      subtitle: '스위치를 켜면 금액을 입력하고, 끄면 이번 계약서에서 제외합니다.',
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '결제정보 입력',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Switch.adaptive(
                value: _usePaymentSection,
                onChanged: _isFormLocked
                    ? null
                    : (v) {
                        setState(() {
                          _usePaymentSection = v;
                        });
                      },
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _usePaymentSection
                ? Column(
                    key: const ValueKey('payment_section_open'),
                    children: [
                      _buildLessonProductLoadButton(),
                      const SizedBox(height: 10),
                      _buildLessonProductAutocompleteField(),
                      const SizedBox(height: 10),
                      _buildSelectedProductSummaryCard(),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _unitPriceController,
                              label: '회당 결제금액',
                              hint: '77000',
                              keyboardType: TextInputType.number,
                              enabled: !_isFormLocked,
                              prefixText: '₩ ',
                              showError: _shouldShowUnitPriceError,
                              errorText: '회당 금액을 입력해주세요.',
                              inputFormatters: const [
                                _ThousandsInputFormatter(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(14),
                              border:
                                  Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Checkbox(
                                  value: _vatIncluded,
                                  onChanged: _isFormLocked
                                      ? null
                                      : (v) {
                                          final next = v ?? false;
                                          if (_vatIncluded == next) return;

                                          setState(() {
                                            _vatIncluded = next;
                                            _ContractUiMemory.vatIncluded =
                                                _vatIncluded;
                                          });

                                          _handleSignatureSensitiveChanged();
                                        },
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                const Text(
                                  'VAT',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _sessionCountController,
                        label: '상품 횟수',
                        hint: '10',
                        keyboardType: TextInputType.number,
                        enabled: !_isFormLocked,
                        suffixText: '회',
                        showError: _shouldShowSessionCountError,
                        errorText: '상품 횟수를 입력해주세요.',
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildPriceFormulaCard(),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _priceController,
                        label: '실결제금액',
                        hint: '770,000',
                        keyboardType: TextInputType.number,
                        enabled: !_isFormLocked,
                        prefixText: '₩ ',
                        helperText: _paymentDifferenceShortLabel.isEmpty
                            ? null
                            : _paymentDifferenceShortLabel,
                        showError: _shouldShowPriceError,
                        errorText: '실결제금액을 입력해주세요.',
                        inputFormatters: const [
                          _ThousandsInputFormatter(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildVatCard(),
                      const SizedBox(height: 12),
                      _buildPaymentMethodSelector(),
                      const SizedBox(height: 12),
                      _buildDateField(
                        controller: _paymentDateController,
                        label: '결제일',
                        enabled: !_isFormLocked,
                        showError: _shouldShowPaymentDateError,
                        errorText: '결제일을 선택해주세요.',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              controller: _contractDateController,
                              label: '계약일',
                              enabled: !_isFormLocked,
                              showError: _shouldShowContractDateError,
                              errorText: '계약일을 선택해주세요.',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildDateField(
                              controller: _endDateController,
                              label: '종료일',
                              enabled: !_isFormLocked && !_isUnlimitedEndDate,
                              showError: _shouldShowEndDateError,
                              errorText: '종료일을 선택해주세요.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: _isUnlimitedEndDate,
                        onChanged: _isFormLocked
                            ? null
                            : (v) {
                                final next = v ?? false;
                                if (_isUnlimitedEndDate == next) return;

                                setState(() {
                                  _isUnlimitedEndDate = next;
                                  _ContractUiMemory.unlimitedEndDate =
                                      _isUnlimitedEndDate;
                                });

                                _handleSignatureSensitiveChanged();
                              },
                        contentPadding: EdgeInsets.zero,
                        title: const Text('종료일 설정 안함'),
                      ),
                    ],
                  )
                : _buildMutedInfo(
                    '이번 계약서에서는 결제정보를 입력하지 않습니다.',
                    key: const ValueKey('payment_section_closed'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '결제 방법',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _PaymentMethodChip(
                label: '현금',
                icon: Icons.payments_outlined,
                selected: _paymentMethod == PaymentMethod.cash,
                onTap: _isFormLocked
                    ? null
                    : () {
                        if (_paymentMethod == PaymentMethod.cash) return;

                        setState(() {
                          _paymentMethod = PaymentMethod.cash;
                        });

                        _handleSignatureSensitiveChanged();
                      },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PaymentMethodChip(
                label: '카드',
                icon: Icons.credit_card_rounded,
                selected: _paymentMethod == PaymentMethod.card,
                onTap: _isFormLocked
                    ? null
                    : () {
                        if (_paymentMethod == PaymentMethod.card) return;

                        setState(() {
                          _paymentMethod = PaymentMethod.card;
                        });

                        _handleSignatureSensitiveChanged();
                      },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PaymentMethodChip(
                label: '계좌이체',
                icon: Icons.account_balance_outlined,
                selected: _paymentMethod == PaymentMethod.transfer,
                onTap: _isFormLocked
                    ? null
                    : () {
                        if (_paymentMethod == PaymentMethod.transfer) return;

                        setState(() {
                          _paymentMethod = PaymentMethod.transfer;
                        });

                        _handleSignatureSensitiveChanged();
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------- SECTION : 개인레슨 결제정보 --------------------

  Widget _buildLessonProductLoadButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isFormLocked ? null : _openLessonProductPicker,
        icon: const Icon(Icons.sell_outlined, size: 18),
        label: const Text(
          '등록된 레슨 상품 불러오기',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF4F46E5),
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildLessonProductAutocompleteField() {
    return RawAutocomplete<ProductModel>(
      textEditingController: _productNameController,
      focusNode: _productNameFocusNode,
      displayStringForOption: (option) => option.name,
      optionsBuilder: (textEditingValue) {
        if (_isFormLocked) {
          return const Iterable<ProductModel>.empty();
        }

        final query = textEditingValue.text.trim().toLowerCase();

        if (_products.isEmpty) {
          return const Iterable<ProductModel>.empty();
        }

        if (query.isEmpty) {
          return _products.take(8);
        }

        return _products.where((product) {
          final searchable = [
            product.categoryName,
            product.name,
            product.lessonType,
            '${product.sessionCount}',
            '${product.unitPrice}',
            '${product.totalPrice}',
            _formatMoney(product.unitPrice),
            _formatMoney(product.totalPrice),
          ].join(' ').toLowerCase();

          return searchable.contains(query);
        }).take(8);
      },
      onSelected: (product) {
        _applyProduct(product);
        _productNameFocusNode.unfocus();
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        final showProductError = _shouldShowProductNameError;
        final borderColor = showProductError
            ? const Color(0xFFEF4444)
            : const Color(0xFFE5E7EB);
        return TextField(
          controller: textEditingController,
          focusNode: focusNode,
          enabled: !_isFormLocked,
          onChanged: (_) {
            setState(() {
              _selectedProduct = null;
            });
          },
          decoration: InputDecoration(
              labelText: '상품명',
              hintText: _isLoadingProducts
                  ? '상품을 불러오는 중입니다'
                  : _products.isEmpty
                      ? '마이페이지에서 수업 상품을 먼저 추가해주세요'
                      : '예: PT레슨 10회',
              filled: true,
              fillColor: !_isFormLocked
                  ? const Color(0xFFF9FAFB)
                  : const Color(0xFFF3F4F6),
              errorText: showProductError ? '수업 상품을 선택하거나 입력해주세요.' : null,
              prefixIcon: _isLoadingProducts
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search_rounded, size: 20),
              suffixIcon: IconButton(
                tooltip: '상품 새로고침',
                onPressed: _isFormLocked ? null : _loadProducts,
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: borderColor,
                  width: showProductError ? 1.4 : 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: showProductError
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF4F46E5),
                  width: 1.5,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: showProductError
                      ? const Color(0xFFEF4444)
                      : const Color(0xFFD1D5DB),
                ),
              )),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();

        if (list.isEmpty) {
          return const SizedBox.shrink();
        }

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(18),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: kContractMaxContentWidth - 32,
                maxHeight: 280,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = list[index];

                    return InkWell(
                      onTap: () => onSelected(product),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${product.categoryName} · ${product.sessionCount}회 · 회당 ${_formatMoney(product.unitPrice)}원 · 총 ${_formatMoney(product.totalPrice)}원${product.vatIncluded ? ' · VAT 포함' : ' · VAT 별도'}',
                              style: const TextStyle(
                                fontSize: 12.2,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectedProductSummaryCard() {
    final product = _selectedProduct;

    if (product == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFC7D2FE),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF4F46E5),
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '선택된 레슨 상품',
                  style: TextStyle(
                    color: Color(0xFF4F46E5),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.categoryName} · ${product.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.sessionCount}회 · 회당 ${_formatMoney(product.unitPrice)}원 · 총 ${_formatMoney(product.totalPrice)}원 · ${product.vatIncluded ? 'VAT 포함' : 'VAT 별도'}',
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isUnlimitedEndDate
                      ? '종료일 설정 안함으로 적용 중입니다.'
                      : '추천 종료일: ${_endDateController.text}',
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 11.2,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '선택 해제',
            onPressed: _isFormLocked
                ? null
                : () {
                    setState(() {
                      _selectedProduct = null;
                    });
                  },
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFF6B7280),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceFormulaCard() {
    final differenceColor = _priceValue < _calculatedTotalPrice
        ? const Color(0xFF166534)
        : const Color(0xFF9A3412);

    final differenceBg = _priceValue < _calculatedTotalPrice
        ? const Color(0xFFECFDF5)
        : const Color(0xFFFFF7ED);

    final differenceBorder = _priceValue < _calculatedTotalPrice
        ? const Color(0xFFBBF7D0)
        : const Color(0xFFFED7AA);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '회당 결제금액 × 상품 횟수',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              if (_paymentDifferenceShortLabel.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: differenceBg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: differenceBorder),
                  ),
                  child: Text(
                    _paymentDifferenceShortLabel,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: differenceColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _vatIncluded
                ? '₩ ${_formatMoney(_unitPriceValue)} × ${_sessionCountValue}회 + VAT ${_formatMoney(_calculatedVatAmount)}원 = ₩ ${_formatMoney(_calculatedTotalPrice)}'
                : '₩ ${_formatMoney(_unitPriceValue)} × ${_sessionCountValue}회 = ₩ ${_formatMoney(_calculatedTotalPrice)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '계산한 금액을 실결제금액에 바로 적용할 수 있습니다.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: _isFormLocked
                    ? null
                    : () {
                        if (_priceValue == _calculatedTotalPrice) {
                          return;
                        }

                        _isApplyingProgrammaticChange = true;

                        setState(() {
                          _priceController.text =
                              _formatMoney(_calculatedTotalPrice);
                        });

                        _isApplyingProgrammaticChange = false;
                        _handleSignatureSensitiveChanged();
                      },
                child: const Text('금액 적용'),
              ),
            ],
          ),
          if (_hasPaymentDifference) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: differenceBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: differenceBorder),
              ),
              child: Text(
                _paymentDifferenceDetailText,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                  color: differenceColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------- SECTION : 계약 조건 --------------------

  Widget _buildContractConditionSection() {
    final bool isHybridWrite = _sourceMode == ContractSourceMode.customWrite;

    return _buildSectionCard(
      title:
          _sourceMode == ContractSourceMode.uploadPdf ? '추가 확인 조항' : '계약 조건 확인',
      icon: Icons.rule_folder_outlined,
      subtitle: _sourceMode == ContractSourceMode.uploadPdf
          ? '업로드한 PDF를 기본 문서로 사용하고, 아래 항목은 앱 안에서 추가로 확인할 조항입니다.'
          : isHybridWrite
              ? '기본 문구를 불러와 수정하거나, 빈칸에서 직접 작성할 수 있습니다.'
              : '입력한 값이 아래 문장으로 바로 보이고, 그 문장이 그대로 문서에 들어갑니다.',
      child: Column(
        children: [
          if (isHybridWrite) ...[
            _buildNoticeBox(
              title: '내용작성 모드',
              text: '각 조항별로 기본 문구를 불러와 수정하거나, 빈칸으로 시작해 직접 작성할 수 있습니다.',
              background: const Color(0xFFF8FAFC),
              border: const Color(0xFFE2E8F0),
              textColor: const Color(0xFF334155),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isFormLocked
                        ? null
                        : () {
                            setState(() {
                              _fillHybridClausesFromTemplate(force: true);
                            });
                          },
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('기본문구 전체 불러오기'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isFormLocked
                        ? null
                        : () {
                            setState(() {
                              _clearHybridClauses();
                            });
                          },
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('전체 빈칸으로 시작'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (_sourceMode == ContractSourceMode.uploadPdf) ...[
            _buildNoticeBox(
              title: 'PDF 보관 모드 안내',
              text:
                  '업로드한 PDF가 기본 문서이며, 아래에서 확인하는 내용은 앱 안에서 추가로 저장되는 특약/보조 조항입니다.',
              background: const Color(0xFFF8FAFC),
              border: const Color(0xFFE2E8F0),
              textColor: const Color(0xFF334155),
            ),
            const SizedBox(height: 12),
          ],
          _buildClauseToggleCard(
            title: '수업횟수 / 시간',
            checked: _useLessonClause,
            onChanged: (v) {
              setState(() {
                _useLessonClause = v ?? false;
                _ContractUiMemory.useLessonClause = _useLessonClause;
                if (!_useLessonClause) {
                  _agreeLessonClause = false;
                }
              });
              _handleDetailSignatureSensitiveChanged();
            },
            child: isHybridWrite
                ? Column(
                    children: [
                      _buildHybridClauseEditor(
                        controller: _hybridLessonClauseController,
                        label: '수업횟수 / 시간 문구',
                        generatedText: _lessonClauseText,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _agreeLessonClause,
                        onChanged: _isFormLocked
                            ? null
                            : (v) {
                                setState(() {
                                  _agreeLessonClause = v ?? false;
                                });
                                _handleDetailSignatureSensitiveChanged();
                              },
                        contentPadding: EdgeInsets.zero,
                        title: const Text('동의합니다'),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('본 상품은 총'),
                          _inlineNumberField(
                            _sessionCountController,
                            suffix: '회',
                            enabled: !_isFormLocked,
                          ),
                          const Text('이며, 1회 수업 시간은'),
                          _inlineNumberField(
                            _sessionMinutesController,
                            suffix: '분',
                            enabled: !_isFormLocked,
                          ),
                          const Text('입니다.'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildPreviewSentence(_lessonClauseText),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _agreeLessonClause,
                        onChanged: _isFormLocked
                            ? null
                            : (v) =>
                                setState(() => _agreeLessonClause = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('동의합니다'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          _buildClauseToggleCard(
            title: '예약 기준 / 레슨 지연',
            checked: _useReservationClause,
            infoAction: () => _showReservationTip(force: true),
            onChanged: (v) {
              setState(() {
                _useReservationClause = v ?? false;
                _ContractUiMemory.useReservationClause = _useReservationClause;
                if (!_useReservationClause) {
                  _agreeReservationClause = false;
                }
              });
              _handleDetailSignatureSensitiveChanged();
            },
            child: isHybridWrite
                ? Column(
                    children: [
                      _buildHybridClauseEditor(
                        controller: _hybridReservationClauseController,
                        label: '예약 기준 / 레슨 지연 문구',
                        generatedText: _reservationClauseText,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _agreeReservationClause,
                        onChanged: _isFormLocked
                            ? null
                            : (v) => setState(
                                  () => _agreeReservationClause = v ?? false,
                                ),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('동의합니다'),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      _buildTextField(
                        controller: _cancelHoursController,
                        label: '예약 변경/취소 기준 (시간)',
                        hint: '24',
                        keyboardType: TextInputType.number,
                        enabled: !_isFormLocked,
                        onTap: () => _showReservationTip(force: false),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _lessonDelayMinutesController,
                        label: '레슨 진행이 어려울 수 있는 기준 (분)',
                        hint: '30',
                        keyboardType: TextInputType.number,
                        enabled: !_isFormLocked,
                        onTap: () => _showReservationTip(force: false),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildPreviewSentence(_reservationClauseText),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _agreeReservationClause,
                        onChanged: _isFormLocked
                            ? null
                            : (v) => setState(
                                  () => _agreeReservationClause = v ?? false,
                                ),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('동의합니다'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          _buildClauseToggleCard(
            title: '홀드 / 이용정지',
            checked: _useHoldClause,
            onChanged: (v) {
              setState(() {
                _useHoldClause = v ?? false;
                _ContractUiMemory.useHoldClause = _useHoldClause;
                if (!_useHoldClause) {
                  _agreeHoldClause = false;
                }
              });
              _handleDetailSignatureSensitiveChanged();
            },
            child: isHybridWrite
                ? Column(
                    children: [
                      _buildHybridClauseEditor(
                        controller: _hybridHoldClauseController,
                        label: '홀드 / 이용정지 문구',
                        generatedText: _holdClauseText,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _agreeHoldClause,
                        onChanged: _isFormLocked
                            ? null
                            : (v) =>
                                setState(() => _agreeHoldClause = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('동의합니다'),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('홀드(일시정지)는'),
                          _inlineNumberField(
                            _holdCountController,
                            suffix: '회',
                            enabled: !_isFormLocked,
                          ),
                          const Text('총'),
                          _inlineNumberField(
                            _holdDaysController,
                            suffix: '일',
                            enabled: !_isFormLocked,
                          ),
                          const Text('가능합니다.'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _suspensionRuleController,
                        label: '이용정지 / 운영 예외 문구',
                        hint: '기관에서 인정하는 사항에 따라 이용정지 운영의 예외를 둘 수 있습니다.',
                        maxLines: 2,
                        enabled: !_isFormLocked,
                      ),
                      const SizedBox(height: 12),
                      _buildPreviewSentence(_holdClauseText),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _agreeHoldClause,
                        onChanged: _isFormLocked
                            ? null
                            : (v) =>
                                setState(() => _agreeHoldClause = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('동의합니다'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          _buildClauseToggleCard(
            title: '중도해지 시 위약금 및 정책',
            checked: _usePenaltyClause,
            infoAction: () => _showPenaltyTip(force: true),
            onChanged: (v) {
              setState(() {
                _usePenaltyClause = v ?? false;
                _ContractUiMemory.usePenaltyClause = _usePenaltyClause;
                if (!_usePenaltyClause) {
                  _agreePenaltyClause = false;
                }
              });
              _handleDetailSignatureSensitiveChanged();
            },
            child: isHybridWrite
                ? Column(
                    children: [
                      _buildHybridClauseEditor(
                        controller: _hybridPenaltyClauseController,
                        label: '중도해지 시 위약금 및 정책 문구',
                        generatedText: _penaltyClauseText,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _agreePenaltyClause,
                        onChanged: _isFormLocked
                            ? null
                            : (v) => setState(
                                () => _agreePenaltyClause = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('동의합니다'),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      CheckboxListTile(
                        value: _noRefundProduct,
                        onChanged: _isFormLocked
                            ? null
                            : (v) =>
                                setState(() => _noRefundProduct = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('환불불가 상품입니다'),
                      ),
                      if (!_noRefundProduct)
                        _buildTextField(
                          controller: _penaltyPercentController,
                          label: '위약금 비율 (%)',
                          hint: '10',
                          keyboardType: TextInputType.number,
                          enabled: !_isFormLocked,
                          onTap: () => _showPenaltyTip(force: false),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                        ),
                      const SizedBox(height: 12),
                      _buildPreviewSentence(_penaltyClauseText),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _agreePenaltyClause,
                        onChanged: _isFormLocked
                            ? null
                            : (v) => setState(
                                () => _agreePenaltyClause = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('동의합니다'),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          _buildClauseToggleCard(
            title: '양도 기준 또는 불가 여부',
            checked: _useTransferClause,
            onChanged: (v) {
              setState(() {
                _useTransferClause = v ?? false;
                _ContractUiMemory.useTransferClause = _useTransferClause;
                if (!_useTransferClause) {
                  _agreeTransferClause = false;
                }
              });
              _handleDetailSignatureSensitiveChanged();
            },
            child: isHybridWrite
                ? Column(
                    children: [
                      _buildHybridClauseEditor(
                        controller: _hybridTransferClauseController,
                        label: '양도 기준 또는 불가 여부 문구',
                        generatedText: _transferClauseText,
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _agreeTransferClause,
                        onChanged: _isFormLocked
                            ? null
                            : (v) => setState(
                                () => _agreeTransferClause = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('동의합니다'),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      SwitchListTile.adaptive(
                        value: _transferAllowed,
                        onChanged: _isFormLocked
                            ? null
                            : (v) => setState(() => _transferAllowed = v),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('양도 가능'),
                      ),
                      if (_transferAllowed)
                        _buildTextField(
                          controller: _transferRuleController,
                          label: '양도 기준',
                          hint: '센터 승인 및 명의 확인 후 양도 가능합니다.',
                          maxLines: 2,
                          enabled: !_isFormLocked,
                        ),
                      const SizedBox(height: 12),
                      _buildPreviewSentence(_transferClauseText),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _agreeTransferClause,
                        onChanged: _isFormLocked
                            ? null
                            : (v) => setState(
                                () => _agreeTransferClause = v ?? false),
                        contentPadding: EdgeInsets.zero,
                        title: const Text('동의합니다'),
                      ),
                    ],
                  ),
          ),
          if (_sourceMode == ContractSourceMode.customWrite) ...[
            const SizedBox(height: 14),
            _buildDividerLabel('추가 특약 / 메모'),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _customMainClauseController,
              label: '추가 특약',
              hint: '예: 주 2회 고정 / 대체수업 / 지점 이용 제한 등',
              maxLines: 3,
              enabled: !_isFormLocked,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _customExtraClauseController,
              label: '추가 메모',
              hint: '예: 상담 내용 / 전달사항 / 문서 보완 메모',
              maxLines: 4,
              enabled: !_isFormLocked,
            ),
          ],
          if (_sourceMode == ContractSourceMode.uploadPdf) ...[
            const SizedBox(height: 14),
            _buildDividerLabel('PDF 보관'),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '보관된 계약서 PDF',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _isFormLocked ||
                                _storedPdfNames.length >= _maxStoredPdfCount
                            ? null
                            : () {
                                setState(() {
                                  _storedPdfNames.add(
                                    'contract_${_storedPdfNames.length + 1}.pdf',
                                  );
                                });
                                _showSnack('PDF 보관 더미가 추가되었습니다.');
                              },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('추가'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_storedPdfNames.isEmpty)
                    _buildMutedInfo('보관된 PDF가 없습니다.')
                  else
                    Column(
                      children: _storedPdfNames.asMap().entries.map((entry) {
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.picture_as_pdf_outlined,
                                  size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.value,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111827),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _isFormLocked
                                    ? null
                                    : () {
                                        setState(() {
                                          _storedPdfNames.removeAt(entry.key);
                                        });
                                      },
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  if (_storedPdfNames.length >= _maxStoredPdfCount)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'PDF는 최대 5개까지 보관할 수 있습니다.',
                        style: TextStyle(
                          fontSize: 12.2,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------- SECTION : 계약문장 이력 --------------------

  Widget _buildContractHistorySection() {
    final items = _contractHistoryItems;

    return _buildSectionCard(
      title: _sourceMode == ContractSourceMode.uploadPdf
          ? '추가 확인 조항 이력'
          : '계약문장 이력',
      icon: Icons.history_outlined,
      subtitle: _sourceMode == ContractSourceMode.uploadPdf
          ? '업로드 문서 외에 앱 화면에 실제로 저장될 추가 문장 리스트입니다.'
          : '현재 문서에 실제로 들어갈 문장 리스트입니다.',
      child: items.isEmpty
          ? _buildMutedInfo(
              _sourceMode == ContractSourceMode.uploadPdf
                  ? '추가 확인 조항이 없습니다.'
                  : '선택된 계약 조건이 없습니다.',
            )
          : Column(
              children: items.map((item) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.subdirectory_arrow_right, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item,
                          style: const TextStyle(
                            height: 1.45,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  // -------------------- SECTION : 건강 고지 --------------------

  Widget _buildHealthSection() {
    return _buildSectionCard(
      title: '건강 고지',
      icon: Icons.health_and_safety_outlined,
      subtitle: '통증 부위, 최근 수술, 최근 사고 이력을 선택하면 상세 건강고지에 자동 반영됩니다.',
      child: Column(
        children: [
          CheckboxListTile(
            value: _healthPain,
            onChanged: _isFormLocked
                ? null
                : (v) {
                    setState(() {
                      _healthPain = v ?? false;
                      if (_healthPain) {
                        _healthNone = false;
                      } else {
                        _selectedPainAreas.clear();
                      }
                      _syncHealthDetailController();
                    });
                  },
            contentPadding: EdgeInsets.zero,
            title: const Text('통증 / 불편 부위가 있습니다'),
          ),
          if (_healthPain) ...[
            const SizedBox(height: 8),
            _buildHealthChoiceGroup(
              title: '통증 부위 선택',
              options: _painAreaOptions,
              selectedValues: _selectedPainAreas,
              onTap: (value) => _toggleHealthChip(
                target: _selectedPainAreas,
                value: value,
              ),
            ),
            if (_selectedPainAreas.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '통증/불편 부위를 1개 이상 선택해주세요.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
          CheckboxListTile(
            value: _healthSurgery,
            onChanged: _isFormLocked
                ? null
                : (v) {
                    setState(() {
                      _healthSurgery = v ?? false;
                      if (_healthSurgery) {
                        _healthNone = false;
                      } else {
                        _selectedSurgeryTypes.clear();
                      }
                      _syncHealthDetailController();
                    });
                  },
            contentPadding: EdgeInsets.zero,
            title: const Text('최근 수술 이력이 있습니다'),
          ),
          if (_healthSurgery) ...[
            const SizedBox(height: 8),
            _buildHealthChoiceGroup(
              title: '수술 유형 선택',
              options: _surgeryTypeOptions,
              selectedValues: _selectedSurgeryTypes,
              onTap: (value) => _toggleHealthChip(
                target: _selectedSurgeryTypes,
                value: value,
              ),
            ),
            if (_selectedSurgeryTypes.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '수술 유형을 1개 이상 선택해주세요.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
          CheckboxListTile(
            value: _healthAccident,
            onChanged: _isFormLocked
                ? null
                : (v) {
                    setState(() {
                      _healthAccident = v ?? false;
                      if (_healthAccident) {
                        _healthNone = false;
                      } else {
                        _selectedAccidentTypes.clear();
                      }
                      _syncHealthDetailController();
                    });
                  },
            contentPadding: EdgeInsets.zero,
            title: const Text('최근 사고 이력이 있습니다'),
          ),
          if (_healthAccident) ...[
            const SizedBox(height: 8),
            _buildHealthChoiceGroup(
              title: '사고 유형 선택',
              options: _accidentTypeOptions,
              selectedValues: _selectedAccidentTypes,
              onTap: (value) => _toggleHealthChip(
                target: _selectedAccidentTypes,
                value: value,
              ),
            ),
            if (_selectedAccidentTypes.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '사고 유형을 1개 이상 선택해주세요.',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
          CheckboxListTile(
            value: _healthPregnancy,
            onChanged: _isFormLocked
                ? null
                : (v) {
                    setState(() {
                      _healthPregnancy = v ?? false;
                      if (_healthPregnancy) {
                        _healthNone = false;
                      }
                      _syncHealthDetailController();
                    });
                  },
            contentPadding: EdgeInsets.zero,
            title: const Text('임신/출산 관련 사항이 있습니다'),
          ),
          CheckboxListTile(
            value: _healthRehab,
            onChanged: _isFormLocked
                ? null
                : (v) {
                    setState(() {
                      _healthRehab = v ?? false;
                      if (_healthRehab) {
                        _healthNone = false;
                      }
                      _syncHealthDetailController();
                    });
                  },
            contentPadding: EdgeInsets.zero,
            title: const Text('재활 중입니다'),
          ),
          CheckboxListTile(
            value: _healthNone,
            onChanged: _isFormLocked
                ? null
                : (v) {
                    setState(() {
                      _healthNone = v ?? false;
                      if (_healthNone) {
                        _healthPain = false;
                        _healthSurgery = false;
                        _healthAccident = false;
                        _healthPregnancy = false;
                        _healthRehab = false;

                        _selectedPainAreas.clear();
                        _selectedSurgeryTypes.clear();
                        _selectedAccidentTypes.clear();
                      }
                      _syncHealthDetailController();
                    });
                  },
            contentPadding: EdgeInsets.zero,
            title: const Text('해당 없음'),
          ),
          if (_hasAnyHealthIssue) ...[
            const SizedBox(height: 8),
            _buildTextField(
              controller: _healthDetailController,
              label: '상세 건강고지 (자동 생성)',
              hint: '선택한 항목이 자동으로 들어갑니다',
              maxLines: 4,
              enabled: true,
              readOnly: true,
            ),
          ],
          const SizedBox(height: 12),
          _buildNoticeBox(
            title: '건강안내',
            text:
                '회원은 운동에 영향을 줄 수 있는 건강상태를 사실대로 고지해야 하며, 수업 중 통증·어지러움·이상 증상이 발생하면 즉시 강사에게 알려야 합니다.',
            background: const Color(0xFFF9FAFB),
            border: const Color(0xFFE5E7EB),
            textColor: const Color(0xFF374151),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _agreeHealthNotice,
            onChanged: _isFormLocked
                ? null
                : (v) => setState(() => _agreeHealthNotice = v ?? false),
            contentPadding: EdgeInsets.zero,
            title: const Text('건강안내박스를 숙지하였습니다'),
          ),
        ],
      ),
    );
  }

  // -------------------- SECTION : 최종 확인 --------------------

  Widget _buildDeliveryMethodSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '계약서 사본 수령 방식',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _DeliveryMethodChip(
              label: '이메일',
              icon: Icons.email_outlined,
              selected: _deliveryMethod == ContractDeliveryMethod.email,
              onTap: _isFormLocked
                  ? null
                  : () {
                      if (_deliveryMethod == ContractDeliveryMethod.email)
                        return;
                      setState(() {
                        _deliveryMethod = ContractDeliveryMethod.email;
                      });
                      _handleDetailSignatureSensitiveChanged();
                    },
            ),
            _DeliveryMethodChip(
              label: '문자 링크',
              icon: Icons.sms_outlined,
              selected: _deliveryMethod == ContractDeliveryMethod.sms,
              onTap: _isFormLocked
                  ? null
                  : () {
                      if (_deliveryMethod == ContractDeliveryMethod.sms) return;
                      setState(() {
                        _deliveryMethod = ContractDeliveryMethod.sms;
                      });
                      _handleDetailSignatureSensitiveChanged();
                    },
            ),
            _DeliveryMethodChip(
              label: '카카오톡',
              icon: Icons.chat_bubble_outline_rounded,
              selected: _deliveryMethod == ContractDeliveryMethod.kakao,
              onTap: _isFormLocked
                  ? null
                  : () {
                      if (_deliveryMethod == ContractDeliveryMethod.kakao)
                        return;
                      setState(() {
                        _deliveryMethod = ContractDeliveryMethod.kakao;
                      });
                      _handleDetailSignatureSensitiveChanged();
                    },
            ),
            _DeliveryMethodChip(
              label: '인쇄본',
              icon: Icons.print_outlined,
              selected: _deliveryMethod == ContractDeliveryMethod.print,
              onTap: _isFormLocked
                  ? null
                  : () {
                      if (_deliveryMethod == ContractDeliveryMethod.print)
                        return;
                      setState(() {
                        _deliveryMethod = ContractDeliveryMethod.print;
                      });
                      _handleDetailSignatureSensitiveChanged();
                    },
            ),
            _DeliveryMethodChip(
              label: '센터 보관만',
              icon: Icons.inventory_2_outlined,
              selected: _deliveryMethod == ContractDeliveryMethod.storeOnly,
              onTap: _isFormLocked
                  ? null
                  : () {
                      if (_deliveryMethod == ContractDeliveryMethod.storeOnly)
                        return;
                      setState(() {
                        _deliveryMethod = ContractDeliveryMethod.storeOnly;
                      });
                      _handleDetailSignatureSensitiveChanged();
                    },
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
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            '선택: $_deliveryMethodLabel · $_deliveryTarget',
            style: const TextStyle(
              fontSize: 12.3,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: Color(0xFF475569),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------- SECTION : 전자서명 --------------------

  Widget _buildSignatureSection() {
    return _buildSectionCard(
      title: '기본 내용 확인 서명',
      icon: Icons.draw_outlined,
      subtitle: '회원정보, 상품, 금액, 결제방법, 결제일 및 계약기간을 확인합니다.',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFEEF2FF),
                  Color(0xFFF5F3FF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFC7D2FE)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.verified_user_outlined,
                    color: Color(0xFF4F46E5),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '기본 계약내용 확인',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF312E81),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '본인은 회원정보, 상품명, 이용횟수, 결제금액, 결제방법, 결제일 및 계약기간을 확인하고 서명합니다.',
                        style: TextStyle(
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4338CA),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSignatureBox(
            title: '회원 기본 확인 서명',
            name: _memberNameController.text.trim().isEmpty
                ? '회원명 미입력'
                : _memberNameController.text.trim(),
            points: _memberSignaturePoints,
            signedAt: _memberSignedAt,
            onTapSign: () => _openSignaturePad(
              isMember: true,
              isFinal: false,
            ),
            onClear: () {
              if (_isFormLocked) {
                _showSnack('최종 서명 완료 후 수정은 새 버전 작성으로 진행해주세요.');
                return;
              }
              setState(() {
                _memberSignaturePoints = null;
                _memberSignedAt = null;
              });
            },
            disabled: _isFormLocked,
          ),
          const SizedBox(height: 14),
          _buildSignatureBox(
            title: '강사 기본 확인 서명',
            name: _trainerNameController.text.trim().isEmpty
                ? '강사 미입력'
                : _trainerNameController.text.trim(),
            points: _staffSignaturePoints,
            signedAt: _staffSignedAt,
            onTapSign: () => _openSignaturePad(
              isMember: false,
              isFinal: false,
            ),
            onClear: () {
              if (_isFormLocked) {
                _showSnack('최종 서명 완료 후 수정은 새 버전 작성으로 진행해주세요.');
                return;
              }
              setState(() {
                _staffSignaturePoints = null;
                _staffSignedAt = null;
              });
            },
            disabled: _isFormLocked,
          ),
        ],
      ),
    );
  }

  Widget _buildFinalConfirmSection() {
    return _buildSectionCard(
      title: '최종 확인 및 수령 방식',
      icon: Icons.fact_check_outlined,
      subtitle: '계약내용 확인과 계약서 사본 수령 방식을 함께 선택합니다.',
      child: Column(
        children: [
          _buildNoticeBox(
            title: '최종 확인',
            text:
                '회원은 위 계약내용, 결제정보, 계약조건, 환불 및 중도해지 기준, 예약/취소 및 노쇼 기준, 건강고지 내용을 모두 확인합니다.',
            background: const Color(0xFFF3F4F6),
            border: const Color(0xFFD1D5DB),
            textColor: const Color(0xFF374151),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _agreeImportantNotice,
            onChanged: _isFormLocked
                ? null
                : (v) {
                    setState(() {
                      _agreeImportantNotice = v ?? false;
                    });
                    _handleDetailSignatureSensitiveChanged();
                  },
            contentPadding: EdgeInsets.zero,
            title: const Text('현재 화면의 계약내용을 모두 확인했습니다'),
          ),
          CheckboxListTile(
            value: _agreeSameContentSave,
            onChanged: _isFormLocked
                ? null
                : (v) {
                    setState(() {
                      _agreeSameContentSave = v ?? false;
                    });
                    _handleDetailSignatureSensitiveChanged();
                  },
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '아래 서명과 동시에 현재 내용이 안전하게 저장·전송될 수 있음에 동의합니다',
            ),
          ),
          const SizedBox(height: 12),
          _buildDeliveryMethodSelector(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip(
                label: _agreeImportantNotice ? '계약내용 확인 완료' : '계약내용 확인 필요',
                done: _agreeImportantNotice,
              ),
              _buildStatusChip(
                label: _agreeSameContentSave ? '저장·전송 동의 완료' : '저장·전송 동의 필요',
                done: _agreeSameContentSave,
              ),
              _buildStatusChip(
                label: '수령 방식: $_deliveryMethodLabel',
                done: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFinalSignatureSection() {
    return _buildSectionCard(
      title: '최종 동의 서명',
      icon: Icons.verified_outlined,
      subtitle: '계약조건, 환불·중도해지 기준, 건강고지 및 최종 내용을 모두 확인합니다.',
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFECFDF5),
                  Color(0xFFECFEFF),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFBBF7D0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF059669).withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.gavel_outlined,
                    color: Color(0xFF059669),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        '전체 계약조건 최종 확인',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF065F46),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '본인은 수업 운영 기준, 예약/취소 및 노쇼 기준, 환불·중도해지 기준, 건강고지 및 최종 계약내용을 모두 확인하고 이에 동의하여 서명합니다.\n\n아래 서명은 현재 화면의 계약내용이 안전하게 저장되며, 선택한 수령 방식으로 계약서 사본이 제공될 수 있음에 대한 최종 확인을 의미합니다.',
                        style: TextStyle(
                          height: 1.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSignatureBox(
            title: '회원 최종 동의 서명',
            name: _memberNameController.text.trim().isEmpty
                ? '회원명 미입력'
                : _memberNameController.text.trim(),
            points: _memberFinalSignaturePoints,
            signedAt: _memberFinalSignedAt,
            onTapSign: () => _openSignaturePad(
              isMember: true,
              isFinal: true,
            ),
            onClear: () {
              if (_isFormLocked) {
                _showSnack('최종 서명 완료 후 수정은 새 버전 작성으로 진행해주세요.');
                return;
              }
              setState(() {
                _memberFinalSignaturePoints = null;
                _memberFinalSignedAt = null;
              });
            },
            disabled: _isFormLocked,
          ),
          const SizedBox(height: 14),
          _buildSignatureBox(
            title: '강사 최종 확인 서명',
            name: _trainerNameController.text.trim().isEmpty
                ? '강사 미입력'
                : _trainerNameController.text.trim(),
            points: _staffFinalSignaturePoints,
            signedAt: _staffFinalSignedAt,
            onTapSign: () => _openSignaturePad(
              isMember: false,
              isFinal: true,
            ),
            onClear: () {
              if (_isFormLocked) {
                _showSnack('최종 서명 완료 후 수정은 새 버전 작성으로 진행해주세요.');
                return;
              }
              setState(() {
                _staffFinalSignaturePoints = null;
                _staffFinalSignedAt = null;
              });
            },
            disabled: _isFormLocked,
          ),
        ],
      ),
    );
  }

  // -------------------- PREVIEW --------------------

  Widget _buildLivePreviewSection({required bool compact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 18),
      decoration: BoxDecoration(
        color: kContractCardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kContractBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                color: Color(0xFF111827),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '문서 미리보기',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(
                  '${_documentSnapshot.length}자',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Container(
              width: compact ? 340 : 390,
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 24,
                compact ? 20 : 26,
                compact ? 18 : 24,
                compact ? 20 : 26,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: const Color(0xFF9CA3AF),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormalPreviewHeader(),
                  const SizedBox(height: 14),
                  _buildFormalPreviewPartyTable(),
                  const SizedBox(height: 12),
                  _buildFormalPreviewPaymentTable(),
                  const SizedBox(height: 12),
                  _buildFormalPreviewRuleBox(
                    title: '계약조건',
                    items: _contractHistoryItems.isEmpty
                        ? const ['선택된 계약 조건이 없습니다.']
                        : _contractHistoryItems,
                  ),
                  const SizedBox(height: 12),
                  _buildFormalPreviewRuleBox(
                    title: '건강고지',
                    items: [
                      '건강 상태: $_healthSummary',
                      if (_healthDetailController.text.trim().isNotEmpty)
                        '상세 고지: ${_healthDetailController.text.trim()}',
                      '건강안내 숙지: ${_agreeHealthNotice ? '완료' : '미완료'}',
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildFormalPreviewRuleBox(
                    title: '최종 확인 및 수령 방식',
                    items: [
                      '계약내용 확인: ${_agreeImportantNotice ? '완료' : '미완료'}',
                      '저장·전송 동의: ${_agreeSameContentSave ? '완료' : '미완료'}',
                      '계약서 사본 수령 방식: $_deliveryMethodLabel',
                      '수령 대상: $_deliveryTarget',
                    ],
                  ),
                  const SizedBox(height: 18),
                  _buildFormalPreviewSignatureArea(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormalPreviewHeader() {
    return Column(
      children: [
        Center(
          child: Text(
            _documentType,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 5),
        const Center(
          child: Text(
            'Personal Training Contract',
            style: TextStyle(
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(
              color: const Color(0xFFCBD5E1),
              width: 0.8,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '계약번호: ${_contractNo ?? '저장 전'}',
                  style: const TextStyle(
                    fontSize: 10.8,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              Text(
                '버전: v$_version',
                style: const TextStyle(
                  fontSize: 10.8,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormalPreviewMiniTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12.2,
          fontWeight: FontWeight.w900,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  Widget _buildFormalPreviewPartyTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormalPreviewMiniTitle('계약 당사자'),
        Table(
          border: TableBorder.all(
            color: const Color(0xFF9CA3AF),
            width: 0.8,
          ),
          columnWidths: const {
            0: FixedColumnWidth(72),
            1: FlexColumnWidth(),
            2: FixedColumnWidth(72),
            3: FlexColumnWidth(),
          },
          children: [
            _buildFormalPreviewTableRow(
              '회원명',
              _valueOrDash(_memberNameController.text),
              '생년월일',
              _valueOrDash(_memberBirthController.text),
            ),
            _buildFormalPreviewTableRow(
              '연락처',
              _valueOrDash(_memberPhoneController.text),
              '이메일',
              _valueOrDash(_memberEmailController.text),
            ),
            _buildFormalPreviewTableRow(
              '센터명',
              _valueOrDash(_centerNameController.text),
              '담당강사',
              _valueOrDash(_trainerNameController.text),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFormalPreviewPaymentTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormalPreviewMiniTitle('상품 및 결제 정보'),
        Table(
          border: TableBorder.all(
            color: const Color(0xFF9CA3AF),
            width: 0.8,
          ),
          columnWidths: const {
            0: FixedColumnWidth(72),
            1: FlexColumnWidth(),
            2: FixedColumnWidth(72),
            3: FlexColumnWidth(),
          },
          children: [
            _buildFormalPreviewTableRow(
              '상품명',
              _usePaymentSection
                  ? _valueOrDash(_productNameController.text)
                  : '미기재',
              '횟수',
              _usePaymentSection ? '${_sessionCountValue}회' : '미기재',
            ),
            _buildFormalPreviewTableRow(
              '회당금액',
              _usePaymentSection ? '${_formatMoney(_unitPriceValue)}원' : '미기재',
              '결제금액',
              _usePaymentSection ? '${_formatMoney(_priceValue)}원' : '미기재',
            ),
            _buildFormalPreviewTableRow(
              'VAT',
              _usePaymentSection ? _vatLabel : '미기재',
              '결제방법',
              _usePaymentSection ? _paymentMethodLabel : '미기재',
            ),
            _buildFormalPreviewTableRow(
              '결제일',
              _usePaymentSection
                  ? _valueOrDash(_paymentDateController.text)
                  : '미기재',
              '계약일',
              _valueOrDash(_contractDateController.text),
            ),
            _buildFormalPreviewTableRow(
              '종료일',
              _isUnlimitedEndDate
                  ? '설정 안함'
                  : _valueOrDash(_endDateController.text),
              '작성방식',
              _sourceModeLabel,
            ),
          ],
        ),
        if (_paymentDifferenceDocumentLine.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _paymentDifferenceDocumentLine,
            style: const TextStyle(
              fontSize: 10.8,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: Color(0xFF047857),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFormalPreviewInfoTable() {
    return Table(
      border: TableBorder.all(
        color: const Color(0xFF9CA3AF),
        width: 0.8,
      ),
      columnWidths: const {
        0: FixedColumnWidth(72),
        1: FlexColumnWidth(),
        2: FixedColumnWidth(72),
        3: FlexColumnWidth(),
      },
      children: [
        _buildFormalPreviewTableRow(
          '회원명',
          _valueOrDash(_memberNameController.text),
          '생년월일',
          _valueOrDash(_memberBirthController.text),
        ),
        _buildFormalPreviewTableRow(
          '연락처',
          _valueOrDash(_memberPhoneController.text),
          '이메일',
          _valueOrDash(_memberEmailController.text),
        ),
        _buildFormalPreviewTableRow(
          '상품명',
          _usePaymentSection
              ? _valueOrDash(_productNameController.text)
              : '미기재',
          '계약일',
          _valueOrDash(_contractDateController.text),
        ),
        _buildFormalPreviewTableRow(
          '횟수',
          _usePaymentSection ? '${_sessionCountValue}회' : '미기재',
          '결제금액',
          _usePaymentSection ? '${_formatMoney(_priceValue)}원' : '미기재',
        ),
        _buildFormalPreviewTableRow(
          '결제방법',
          _usePaymentSection ? _paymentMethodLabel : '미기재',
          '결제일',
          _usePaymentSection
              ? _valueOrDash(_paymentDateController.text)
              : '미기재',
        ),
      ],
    );
  }

  TableRow _buildFormalPreviewTableRow(
    String leftLabel,
    String leftValue,
    String rightLabel,
    String rightValue,
  ) {
    return TableRow(
      children: [
        _buildFormalPreviewLabelCell(leftLabel),
        _buildFormalPreviewValueCell(leftValue),
        _buildFormalPreviewLabelCell(rightLabel),
        _buildFormalPreviewValueCell(rightValue),
      ],
    );
  }

  Widget _buildFormalPreviewLabelCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      color: const Color(0xFFF8FAFC),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFF111827),
        ),
      ),
    );
  }

  Widget _buildFormalPreviewValueCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  Widget _buildFormalPreviewSignatureArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFormalPreviewSignatureGroup(
          title: '기본 내용 확인 서명',
          description: '회원정보, 상품명, 이용횟수, 결제금액, 결제방법, 결제일 및 계약기간을 확인합니다.',
          memberLabel: '회원 기본 확인',
          staffLabel: '강사 기본 확인',
          memberPoints: _memberSignaturePoints,
          staffPoints: _staffSignaturePoints,
          memberSignedAt: _memberSignedAt,
          staffSignedAt: _staffSignedAt,
        ),
        const SizedBox(height: 16),
        _buildFormalPreviewSignatureGroup(
          title: '최종 동의 서명',
          description: '계약조건, 환불·중도해지 기준, 예약/노쇼 기준, 건강고지 및 최종 계약내용에 동의합니다.',
          memberLabel: '회원 최종 동의',
          staffLabel: '강사 최종 확인',
          memberPoints: _memberFinalSignaturePoints,
          staffPoints: _staffFinalSignaturePoints,
          memberSignedAt: _memberFinalSignedAt,
          staffSignedAt: _staffFinalSignedAt,
        ),
      ],
    );
  }

  Widget _buildFormalPreviewSignatureGroup({
    required String title,
    required String description,
    required String memberLabel,
    required String staffLabel,
    required List<Offset?>? memberPoints,
    required List<Offset?>? staffPoints,
    required DateTime? memberSignedAt,
    required DateTime? staffSignedAt,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFF9CA3AF),
          width: 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFormalPreviewSigner(
                  memberLabel,
                  _memberNameController.text.trim(),
                  memberPoints,
                  signedAt: memberSignedAt,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildFormalPreviewSigner(
                  staffLabel,
                  _trainerNameController.text.trim(),
                  staffPoints,
                  signedAt: staffSignedAt,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormalPreviewRuleBox({
    required String title,
    required List<String> items,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF9CA3AF), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: const Color(0xFFF3F4F6),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(items.length, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == items.length - 1 ? 0 : 8,
                  ),
                  child: Text(
                    '${index + 1}. ${items[index]}',
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormalPreviewSigner(
    String label,
    String name,
    List<Offset?>? points, {
    DateTime? signedAt,
  }) {
    final hasSignature = points != null && points.any((e) => e != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          height: 58,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF9CA3AF), width: 0.8),
          ),
          child: hasSignature
              ? CustomPaint(
                  painter: _FittedSignaturePainter(points),
                  child: const SizedBox.expand(),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 6),
        Text(
          name.isEmpty ? '-' : name,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: Color(0xFF374151),
          ),
        ),
        if (signedAt != null) ...[
          const SizedBox(height: 3),
          Text(
            _formatDateTime(signedAt),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDocumentSection({
    required String title,
    required String body,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCFCFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            body,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.7,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // -------------------- BOTTOM ACTIONS --------------------

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    String? subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111827),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildReadOnlyInfoTile(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        color: const Color(0xFFF9FAFB),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF374151),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool enabled = true,
    bool readOnly = false,
    VoidCallback? onTap,
    String? helperText,
    String? prefixText,
    String? suffixText,
    List<TextInputFormatter>? inputFormatters,
    bool showError = false,
    String? errorText,
  }) {
    final borderColor =
        showError ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB);

    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      inputFormatters: inputFormatters,
      style: const TextStyle(
        color: Color(0xFF111827),
        fontWeight: FontWeight.w600,
        height: 1.45,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: showError ? null : helperText,
        errorText: showError ? (errorText ?? '필수 입력 항목입니다.') : null,
        prefixText: prefixText,
        suffixText: suffixText,
        filled: true,
        fillColor: enabled ? const Color(0xFFF9FAFB) : const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: borderColor,
            width: showError ? 1.4 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color:
                showError ? const Color(0xFFEF4444) : const Color(0xFF4F46E5),
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color:
                showError ? const Color(0xFFEF4444) : const Color(0xFFD1D5DB),
          ),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    bool enabled = true,
    bool showError = false,
    String? errorText,
  }) {
    final borderColor =
        showError ? const Color(0xFFEF4444) : const Color(0xFFE5E7EB);

    return TextField(
      controller: controller,
      readOnly: true,
      enabled: enabled,
      onTap: enabled ? () => _pickDate(controller) : null,
      decoration: InputDecoration(
        labelText: label,
        errorText: showError ? (errorText ?? '필수 선택 항목입니다.') : null,
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        filled: true,
        fillColor: enabled ? const Color(0xFFF9FAFB) : const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: borderColor,
            width: showError ? 1.4 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color:
                showError ? const Color(0xFFEF4444) : const Color(0xFF4F46E5),
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color:
                showError ? const Color(0xFFEF4444) : const Color(0xFFD1D5DB),
          ),
        ),
      ),
    );
  }

  Widget _inlineNumberField(
    TextEditingController controller, {
    required String suffix,
    bool enabled = true,
  }) {
    return SizedBox(
      width: 84,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        enabled: enabled,
        textAlign: TextAlign.center,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          suffixText: suffix,
          filled: true,
          fillColor: enabled ? Colors.white : const Color(0xFFF3F4F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
          ),
        ),
      ),
    );
  }

  Widget _buildMutedInfo(String text, {Key? key}) {
    return Container(
      key: key,
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF4B5563),
          fontSize: 12,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildNoticeBox({
    required String title,
    required String text,
    required Color background,
    required Color border,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: TextStyle(
              height: 1.45,
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewSentence(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF111827),
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDividerLabel(String text) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 1,
          color: const Color(0xFFD1D5DB),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1,
            color: const Color(0xFFD1D5DB),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip({
    required String label,
    required bool done,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: done ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: done ? const Color(0xFF166534) : const Color(0xFF4B5563),
        ),
      ),
    );
  }

  Widget _buildClauseToggleCard({
    required String title,
    required bool checked,
    required ValueChanged<bool?> onChanged,
    VoidCallback? infoAction,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              if (infoAction != null)
                IconButton(
                  tooltip: 'TIP 보기',
                  onPressed: infoAction,
                  icon: const Icon(Icons.lightbulb_outline),
                ),
              Switch.adaptive(
                value: checked,
                onChanged: _isFormLocked ? null : onChanged,
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: checked
                ? Padding(
                    key: ValueKey('clause_open_$title'),
                    padding: const EdgeInsets.only(top: 8),
                    child: child,
                  )
                : const SizedBox.shrink(
                    key: ValueKey('clause_closed'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHybridClauseEditor({
    required TextEditingController controller,
    required String label,
    required String generatedText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            TextButton(
              onPressed: _isFormLocked
                  ? null
                  : () {
                      setState(() {
                        controller.text = generatedText;
                      });
                    },
              child: const Text('기본문구'),
            ),
            TextButton(
              onPressed: _isFormLocked
                  ? null
                  : () {
                      setState(() {
                        controller.clear();
                      });
                    },
              child: const Text('빈칸'),
            ),
          ],
        ),
        _buildTextField(
          controller: controller,
          label: label,
          hint: '직접 문구를 작성해주세요',
          maxLines: 3,
          enabled: !_isFormLocked,
        ),
        const SizedBox(height: 12),
        _buildPreviewSentence(
          controller.text.trim().isEmpty
              ? '직접 작성 문구가 아직 없습니다.'
              : controller.text.trim(),
        ),
      ],
    );
  }

  Widget _buildHealthChoiceGroup({
    required String title,
    required List<String> options,
    required Set<String> selectedValues,
    required ValueChanged<String> onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((item) {
              final selected = selectedValues.contains(item);

              return FilterChip(
                label: Text(item),
                selected: selected,
                onSelected: (_) => onTap(item),
                showCheckmark: false,
                selectedColor: const Color(0xFFDBEAFE),
                backgroundColor: const Color(0xFFF9FAFB),
                labelStyle: TextStyle(
                  color: selected
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFF374151),
                  fontWeight: FontWeight.w700,
                ),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF93C5FD)
                      : const Color(0xFFE5E7EB),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureBox({
    required String title,
    required String name,
    required List<Offset?>? points,
    required DateTime? signedAt,
    required VoidCallback onTapSign,
    required VoidCallback onClear,
    required bool disabled,
  }) {
    final hasSignature = points != null && points.any((e) => e != null);
    final displayName = name.trim().isEmpty ? '이름 미입력' : name.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title · $displayName',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          hasSignature
              ? '서명이 완료되었습니다. 수정이 필요하면 다시 서명할 수 있습니다.'
              : '서명란을 탭해 이름을 직접 서명해주세요.',
          style: const TextStyle(
            fontSize: 12.2,
            height: 1.35,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: disabled ? null : onTapSign,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            height: 148,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: hasSignature
                    ? const Color(0xFF4F46E5).withOpacity(0.45)
                    : const Color(0xFFD1D5DB),
                width: hasSignature ? 1.3 : 1,
              ),
              color:
                  disabled ? const Color(0xFFF3F4F6) : const Color(0xFFF9FAFB),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: hasSignature
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: _FittedSignaturePainter(points!),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      const Color(0xFF111827).withOpacity(0.18),
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '이름을 따라 직접 서명해주세요',
                                style: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 22,
                  child: Container(
                    height: 1,
                    color: const Color(0xFFD1D5DB),
                  ),
                ),
                Positioned(
                  left: 14,
                  bottom: 6,
                  child: Text(
                    hasSignature ? '서명 완료' : '서명란 탭',
                    style: TextStyle(
                      fontSize: 10.8,
                      fontWeight: FontWeight.w800,
                      color: hasSignature
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                if (signedAt != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.86),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        _formatDateTime(signedAt),
                        style: const TextStyle(
                          fontSize: 10.8,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                if (!disabled)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.86),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hasSignature
                                ? Icons.edit_rounded
                                : Icons.touch_app_outlined,
                            size: 13,
                            color: const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            hasSignature ? '수정' : '탭해서 서명',
                            style: const TextStyle(
                              fontSize: 10.8,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: disabled ? null : onTapSign,
                icon: const Icon(Icons.draw_outlined),
                label: Text(hasSignature ? '다시 서명' : '서명하기'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextButton(
                onPressed: hasSignature && !disabled ? onClear : null,
                child: const Text('지우기'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVatCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          _buildRowValue('상품금액', '${_formatMoney(_calculatedBasePrice)}원'),
          const SizedBox(height: 8),
          _buildRowValue(
            'VAT',
            _vatIncluded ? '${_formatMoney(_calculatedVatAmount)}원' : '미포함',
          ),
          const SizedBox(height: 8),
          _buildRowValue('합계', '${_formatMoney(_calculatedTotalPrice)}원'),
        ],
      ),
    );
  }

  Widget _buildRowValue(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // -------------------- PROGRESS / VALIDATION --------------------

  List<_StepItem> _buildSteps() {
    return [
      _StepItem('문서설정', _isDocumentSetupComplete),
      _StepItem('기본정보', _isBasicInfoComplete),
      _StepItem('결제정보', _isPaymentSectionComplete),
      _StepItem('기본서명', _memberSigned && _staffSigned),
      _StepItem('계약조건', _isContractConditionsComplete),
      _StepItem('건강고지', _isHealthSectionComplete),
      _StepItem('최종확인', _isFinalConfirmComplete),
      _StepItem('최종서명', _isFinalSignedCompleted),
    ];
  }

  int get _completedStepCount => _buildSteps().where((e) => e.done).length;

  String get _currentStepTitle {
    final steps = _buildSteps();
    final currentIndex = steps.indexWhere((e) => !e.done);
    return currentIndex == -1 ? '작성완료' : steps[currentIndex].title;
  }

  String get _nextStepHint {
    final steps = _buildSteps();
    final currentIndex = steps.indexWhere((e) => !e.done);
    if (currentIndex == -1) {
      return '모든 단계 완료';
    }
    return '다음: ${steps[currentIndex].title}';
  }

  bool get _isDocumentSetupComplete {
    return _documentType.trim().isNotEmpty &&
        _sourceModeLabel.trim().isNotEmpty;
  }

  bool get _isBasicInfoComplete {
    if (_memberNameController.text.trim().isEmpty) return false;
    if (_memberBirthController.text.trim().isEmpty) return false;
    if (!_isMemberBirthFormatValid) return false;

    if (_memberPhoneController.text.trim().isEmpty) return false;
    if (!_isMemberPhoneFormatValid) return false;

    if (_memberEmailController.text.trim().isEmpty) return false;
    if (!_isMemberEmailFormatValid) return false;

    if (_centerNameController.text.trim().isEmpty) return false;
    if (_trainerNameController.text.trim().isEmpty) return false;

    return true;
  }

  bool get _isPaymentSectionComplete {
    if (!_usePaymentSection) return true;

    if (_productNameController.text.trim().isEmpty) return false;
    if (_unitPriceValue <= 0) return false;
    if (_sessionCountValue <= 0) return false;
    if (_priceValue <= 0) return false;
    if (_paymentDateController.text.trim().isEmpty) return false;
    if (_contractDateController.text.trim().isEmpty) return false;
    if (!_isUnlimitedEndDate && _endDateController.text.trim().isEmpty) {
      return false;
    }
    if (!_isDateRangeValid) return false;
    return true;
  }

  bool get _isContractConditionsComplete {
    if (_useLessonClause && !_agreeLessonClause) return false;
    if (_useReservationClause && !_agreeReservationClause) return false;
    if (_useHoldClause && !_agreeHoldClause) return false;
    if (_usePenaltyClause && !_agreePenaltyClause) return false;
    if (_useTransferClause && !_agreeTransferClause) return false;

    if (_useLessonClause && !_lessonClauseValid) return false;
    if (_useReservationClause && !_reservationClauseValid) return false;
    if (_useHoldClause && !_holdClauseValid) return false;
    if (_usePenaltyClause && !_penaltyClauseValid) return false;
    if (_useTransferClause && !_transferClauseValid) return false;

    return true;
  }

  bool get _isHealthSelectionComplete {
    if (_healthPain && _selectedPainAreas.isEmpty) return false;
    if (_healthSurgery && _selectedSurgeryTypes.isEmpty) return false;
    if (_healthAccident && _selectedAccidentTypes.isEmpty) return false;
    return true;
  }

  bool get _isHealthSectionComplete =>
      _agreeHealthNotice && _isHealthSelectionComplete;

  bool get _isFinalConfirmComplete =>
      _agreeImportantNotice && _agreeSameContentSave;

  bool get _isReadyForPdfOrCustomer => _isContractFullyReady;

  bool get _isDeliveryTargetReady {
    if (_deliveryMethod == ContractDeliveryMethod.email) {
      return _isMemberEmailFormatValid;
    }

    if (_deliveryMethod == ContractDeliveryMethod.sms ||
        _deliveryMethod == ContractDeliveryMethod.kakao) {
      return _isMemberPhoneFormatValid;
    }

    return true;
  }

  bool get _isContractFullyReady {
    return _isDocumentSetupComplete &&
        _isBasicInfoComplete &&
        _isPaymentSectionComplete &&
        _isDateRangeValid &&
        _isContractConditionsComplete &&
        _isHealthSectionComplete &&
        _isFinalConfirmComplete &&
        _isFinalSignedCompleted &&
        _isDeliveryTargetReady;
  }

  bool get _lessonClauseValid {
    if (!_useLessonClause) return true;
    if (_sourceMode == ContractSourceMode.customWrite) {
      return _hybridLessonClauseController.text.trim().isNotEmpty;
    }
    return _sessionCountValue > 0 &&
        _positiveInt(_sessionMinutesController.text) > 0;
  }

  bool get _reservationClauseValid {
    if (!_useReservationClause) return true;
    if (_sourceMode == ContractSourceMode.customWrite) {
      return _hybridReservationClauseController.text.trim().isNotEmpty;
    }
    return _positiveInt(_cancelHoursController.text) > 0 &&
        _positiveInt(_lessonDelayMinutesController.text) > 0;
  }

  bool get _holdClauseValid {
    if (!_useHoldClause) return true;
    if (_sourceMode == ContractSourceMode.customWrite) {
      return _hybridHoldClauseController.text.trim().isNotEmpty;
    }
    return _positiveInt(_holdCountController.text) > 0 &&
        _positiveInt(_holdDaysController.text) > 0;
  }

  bool get _penaltyClauseValid {
    if (!_usePenaltyClause) return true;
    if (_sourceMode == ContractSourceMode.customWrite) {
      return _hybridPenaltyClauseController.text.trim().isNotEmpty;
    }
    if (_noRefundProduct) return true;
    return _positiveInt(_penaltyPercentController.text) >= 0;
  }

  bool get _transferClauseValid {
    if (!_useTransferClause) return true;
    if (_sourceMode == ContractSourceMode.customWrite) {
      return _hybridTransferClauseController.text.trim().isNotEmpty;
    }
    if (!_transferAllowed) return true;
    return _transferRuleController.text.trim().isNotEmpty;
  }

  bool get _isDateRangeValid {
    final contractText = _contractDateController.text.trim();
    if (contractText.isEmpty) return false;

    if (_isUnlimitedEndDate) return true;

    final endText = _endDateController.text.trim();
    if (endText.isEmpty) return false;

    final contractDate = _tryParseDate(contractText);
    final endDate = _tryParseDate(endText);

    if (contractDate == null || endDate == null) return false;
    return !endDate.isBefore(contractDate);
  }

  // -------------------- TEXT / SNAPSHOT --------------------

  int get _unitPriceValue => _parseInt(_unitPriceController.text);
  int get _sessionCountValue => _positiveInt(_sessionCountController.text);
  int get _priceValue => _parseInt(_priceController.text);
  int get _calculatedBasePrice => _unitPriceValue * _sessionCountValue;
  int get _calculatedVatAmount =>
      _vatIncluded ? (_calculatedBasePrice * 0.1).round() : 0;
  int get _calculatedTotalPrice => _calculatedBasePrice + _calculatedVatAmount;

  bool get _hasPaymentDifference {
    return _calculatedTotalPrice > 0 &&
        _priceValue > 0 &&
        _priceValue < _calculatedTotalPrice;
  }

  int get _paymentDifferenceAmount {
    if (!_hasPaymentDifference) return 0;
    return _calculatedTotalPrice - _priceValue;
  }

  double? get _discountPercent {
    if (!_hasPaymentDifference) return null;
    return (_paymentDifferenceAmount / _calculatedTotalPrice) * 100;
  }

  double? get _extraPercent => null;

  String get _paymentDifferenceShortLabel {
    if (_discountPercent != null) {
      return '할인 ${_formatPercent(_discountPercent!)}';
    }
    return '';
  }

  String get _paymentDifferenceDetailText {
    final productLabel = _productNameController.text.trim().isEmpty
        ? '상품'
        : _productNameController.text.trim();

    if (_discountPercent != null) {
      return '$productLabel 금액보다 ${_formatMoney(_paymentDifferenceAmount)}원 낮습니다. 할인 ${_formatPercent(_discountPercent!)}이 반영되었습니다.';
    }
    return '';
  }

  String get _paymentDifferenceDocumentLine {
    if (_discountPercent != null) {
      return '할인 적용: ${_formatMoney(_paymentDifferenceAmount)}원 (${_formatPercent(_discountPercent!)} 할인)';
    }
    return '';
  }

  List<_LessonTemplateOption> get _allLessonTemplateOptions {
    final options = <_LessonTemplateOption>[];

    for (final category in _ContractUiMemory.lessonTemplateCategories) {
      final categoryName = category.name.trim();
      if (categoryName.isEmpty) continue;

      for (final item in category.items) {
        if (item.name.trim().isEmpty) continue;
        options.add(
          _LessonTemplateOption(
            categoryName: categoryName,
            item: item,
          ),
        );
      }
    }

    options.sort((a, b) {
      final categoryCompare =
          a.categoryName.toLowerCase().compareTo(b.categoryName.toLowerCase());
      if (categoryCompare != 0) return categoryCompare;
      return a.item.name.toLowerCase().compareTo(b.item.name.toLowerCase());
    });

    return options;
  }

  String get _sourceModeLabel {
    switch (_sourceMode) {
      case ContractSourceMode.basicTemplate:
        return '기본양식서류';
      case ContractSourceMode.customWrite:
        return '내용작성';
      case ContractSourceMode.uploadPdf:
        return '기존계약서 PDF 보관';
    }
  }

  String get _dateSummaryLabel {
    if (_isUnlimitedEndDate) {
      return '계약일 ${_valueOrDash(_contractDateController.text)} / 종료일 설정 안함';
    }
    return '계약 ${_valueOrDash(_contractDateController.text)} / 종료 ${_valueOrDash(_endDateController.text)}';
  }

  String get _vatLabel => _vatIncluded ? 'VAT 포함' : 'VAT 별도';

  String get _lessonClauseText {
    return '본 상품은 총 ${_valueOrDash(_sessionCountController.text)}회이며, 1회 수업 시간은 ${_valueOrDash(_sessionMinutesController.text)}분입니다.';
  }

  String get _reservationClauseText {
    return '예약 변경 및 취소는 레슨 ${_valueOrDash(_cancelHoursController.text)}시간 전까지 가능합니다. 레슨 약속시간 ${_valueOrDash(_lessonDelayMinutesController.text)}분 이후는 레슨 진행이 어려울 수 있습니다.';
  }

  String get _holdClauseText {
    return '홀드(일시정지)는 ${_valueOrDash(_holdCountController.text)}회, 총 ${_valueOrDash(_holdDaysController.text)}일 가능합니다. ${_valueOrDash(_suspensionRuleController.text)}';
  }

  String get _penaltyClauseText {
    if (_noRefundProduct) {
      return '본 상품은 환불불가 상품으로 운영됩니다.';
    }
    return '중도해지 시 위약금은 ${_valueOrDash(_penaltyPercentController.text)}%를 산정하여 환불 진행됩니다.';
  }

  String get _transferClauseText {
    if (!_transferAllowed) {
      return '본 상품은 양도가 불가합니다.';
    }
    return _transferRuleController.text.trim();
  }

  bool get _canSendCustomerBySelectedDeliveryMethod {
    switch (_deliveryMethod) {
      case ContractDeliveryMethod.email:
      case ContractDeliveryMethod.sms:
      case ContractDeliveryMethod.kakao:
        return true;
      case ContractDeliveryMethod.print:
      case ContractDeliveryMethod.storeOnly:
        return false;
    }
  }

  String get _customerSendActionLabel {
    switch (_deliveryMethod) {
      case ContractDeliveryMethod.email:
        return '이메일 전송';
      case ContractDeliveryMethod.sms:
        return '문자 링크 전송';
      case ContractDeliveryMethod.kakao:
        return '카카오톡 전송';
      case ContractDeliveryMethod.print:
        return '인쇄본 제공';
      case ContractDeliveryMethod.storeOnly:
        return '센터 보관';
    }
  }

  String get _deliveryMethodLabel {
    switch (_deliveryMethod) {
      case ContractDeliveryMethod.email:
        return '이메일';
      case ContractDeliveryMethod.sms:
        return '문자 링크';
      case ContractDeliveryMethod.kakao:
        return '카카오톡';
      case ContractDeliveryMethod.print:
        return '인쇄본';
      case ContractDeliveryMethod.storeOnly:
        return '센터 보관만';
    }
  }

  String get _deliveryTarget {
    switch (_deliveryMethod) {
      case ContractDeliveryMethod.email:
        return _memberEmailController.text.trim();
      case ContractDeliveryMethod.sms:
      case ContractDeliveryMethod.kakao:
        return _memberPhoneController.text.trim();
      case ContractDeliveryMethod.print:
        return '인쇄본 제공';
      case ContractDeliveryMethod.storeOnly:
        return '센터 보관';
    }
  }

  String get _paymentMethodLabel {
    switch (_paymentMethod) {
      case PaymentMethod.cash:
        return '현금';
      case PaymentMethod.card:
        return '카드';
      case PaymentMethod.transfer:
        return '계좌이체';
    }
  }

  String get _healthSummary {
    if (_healthNone) return '해당 없음';

    final items = <String>[];

    if (_healthPain) {
      items.add(
        _selectedPainAreas.isEmpty
            ? '통증/불편 부위 있음'
            : '통증/불편 부위: ${_selectedPainAreas.join(', ')}',
      );
    }

    if (_healthSurgery) {
      items.add(
        _selectedSurgeryTypes.isEmpty
            ? '최근 수술 이력 있음'
            : '최근 수술 이력: ${_selectedSurgeryTypes.join(', ')}',
      );
    }

    if (_healthAccident) {
      items.add(
        _selectedAccidentTypes.isEmpty
            ? '최근 사고 이력 있음'
            : '최근 사고 이력: ${_selectedAccidentTypes.join(', ')}',
      );
    }

    if (_healthPregnancy) items.add('임신/출산 관련');
    if (_healthRehab) items.add('재활 중');

    return items.isEmpty ? '해당 없음' : items.join(' / ');
  }

  List<String> get _contractHistoryItems {
    final items = <String>[];

    final lessonText = _resolvedClauseText(
      enabled: _useLessonClause,
      generatedText: _lessonClauseText,
      hybridController: _hybridLessonClauseController,
    );
    final reservationText = _resolvedClauseText(
      enabled: _useReservationClause,
      generatedText: _reservationClauseText,
      hybridController: _hybridReservationClauseController,
    );
    final holdText = _resolvedClauseText(
      enabled: _useHoldClause,
      generatedText: _holdClauseText,
      hybridController: _hybridHoldClauseController,
    );
    final penaltyText = _resolvedClauseText(
      enabled: _usePenaltyClause,
      generatedText: _penaltyClauseText,
      hybridController: _hybridPenaltyClauseController,
    );
    final transferText = _resolvedClauseText(
      enabled: _useTransferClause,
      generatedText: _transferClauseText,
      hybridController: _hybridTransferClauseController,
    );

    if (lessonText.isNotEmpty) items.add(lessonText);
    if (reservationText.isNotEmpty) items.add(reservationText);
    if (holdText.isNotEmpty) items.add(holdText);
    if (penaltyText.isNotEmpty) items.add(penaltyText);
    if (transferText.isNotEmpty) items.add(transferText);

    if (_sourceMode == ContractSourceMode.customWrite &&
        _customMainClauseController.text.trim().isNotEmpty) {
      items.add(_customMainClauseController.text.trim());
    }
    if (_sourceMode == ContractSourceMode.customWrite &&
        _customExtraClauseController.text.trim().isNotEmpty) {
      items.add(_customExtraClauseController.text.trim());
    }

    return items;
  }

  List<_DocSection> get _documentSections {
    final sections = <_DocSection>[
      _DocSection(
        title: '1. 문서 정보',
        body: '계약번호: ${_contractNo ?? '저장 전'}\n'
            '문서 종류: $_documentType\n'
            '계약 버전: v$_version\n'
            '작성 방식: $_sourceModeLabel\n'
            '저장 상태: ${_contractStatus.name}',
      ),
      _DocSection(
        title: '2. 기본 정보',
        body: '회원명: ${_valueOrDash(_memberNameController.text)}\n'
            '회원 생년월일: ${_valueOrDash(_memberBirthController.text)}\n'
            '회원 연락처: ${_valueOrDash(_memberPhoneController.text)}\n'
            '회원 이메일: ${_valueOrDash(_memberEmailController.text)}\n'
            '센터명: ${_valueOrDash(_centerNameController.text)}\n'
            '담당 강사명: ${_valueOrDash(_trainerNameController.text)}',
      ),
      _DocSection(
        title: '3. 개인레슨 결제정보',
        body: !_usePaymentSection
            ? '결제정보 미기재'
            : '레슨명: ${_valueOrDash(_productNameController.text)}\n'
                '회당 결제금액: ${_formatMoney(_unitPriceValue)}원\n'
                '레슨 횟수: ${_sessionCountValue}회\n'
                '계산 금액: ${_formatMoney(_calculatedTotalPrice)}원 ($_vatLabel)\n'
                '실결제금액: ${_formatMoney(_priceValue)}원'
                '${_paymentDifferenceDocumentLine.isNotEmpty ? '\n$_paymentDifferenceDocumentLine' : ''}\n'
                '결제방법: $_paymentMethodLabel\n'
                '결제일: ${_valueOrDash(_paymentDateController.text)}\n'
                '계약일: ${_valueOrDash(_contractDateController.text)}\n'
                '종료일: ${_isUnlimitedEndDate ? '설정 안함' : _valueOrDash(_endDateController.text)}',
      ),
    ];

    if (_sourceMode == ContractSourceMode.uploadPdf) {
      sections.add(
        _DocSection(
          title: '4. 업로드 문서 정보',
          body: _storedPdfNames.isEmpty
              ? '보관된 PDF가 없습니다.'
              : _storedPdfNames
                  .asMap()
                  .entries
                  .map((e) => '${e.key + 1}. ${e.value}')
                  .join('\n'),
        ),
      );
      sections.add(
        _DocSection(
          title: '5. 추가 확인 조항',
          body: _contractHistoryItems.isEmpty
              ? '추가 확인 조항이 없습니다.'
              : _contractHistoryItems.map((e) => '- $e').join('\n'),
        ),
      );
      sections.add(
        _DocSection(
          title: '6. 건강상태알림',
          body: '건강 상태: $_healthSummary'
              '${_healthDetailController.text.trim().isNotEmpty ? '\n상세 고지: ${_healthDetailController.text.trim()}' : ''}\n'
              '건강상태알림 숙지: ${_agreeHealthNotice ? '완료' : '미완료'}',
        ),
      );
      sections.add(
        _DocSection(
          title: '7. 최종 확인',
          body: '계약내용 확인: ${_agreeImportantNotice ? '완료' : '미완료'}\n'
              '저장·전송 동의: ${_agreeSameContentSave ? '완료' : '미완료'}\n'
              '계약서 사본 수령 방식: $_deliveryMethodLabel\n'
              '수령 대상: $_deliveryTarget\n'
              '현재 화면에서 고객이 확인한 문구와 동일한 내용으로 저장·전송됩니다.',
        ),
      );
      sections.add(
        _DocSection(
          title: '8. 전자서명',
          body:
              '회원 서명: ${_memberSigned ? '완료${_memberSignedAt != null ? ' (${_formatDateTime(_memberSignedAt!)})' : ''}' : '미완료'}\n'
              '강사 서명: ${_staffSigned ? '완료${_staffSignedAt != null ? ' (${_formatDateTime(_staffSignedAt!)})' : ''}' : '미완료'}',
        ),
      );
      return sections;
    }

    sections.add(
      _DocSection(
        title: '4. 계약 조건',
        body: _contractHistoryItems.isEmpty
            ? '선택된 계약 조건이 없습니다.'
            : _contractHistoryItems.map((e) => '- $e').join('\n'),
      ),
    );
    sections.add(
      _DocSection(
        title: '5. 건강상태알림',
        body: '건강 상태: $_healthSummary'
            '${_healthDetailController.text.trim().isNotEmpty ? '\n상세 고지: ${_healthDetailController.text.trim()}' : ''}\n'
            '건강상태알림 숙지: ${_agreeHealthNotice ? '완료' : '미완료'}',
      ),
    );
    sections.add(
      _DocSection(
        title: '6. 최종 확인 및 수령 방식',
        body: '계약내용 확인: ${_agreeImportantNotice ? '완료' : '미완료'}\n'
            '저장·전송 동의: ${_agreeSameContentSave ? '완료' : '미완료'}\n'
            '계약서 사본 수령 방식: $_deliveryMethodLabel\n'
            '수령 대상: $_deliveryTarget\n'
            '현재 화면에서 고객이 확인한 문구와 동일한 내용으로 저장·전송됩니다.',
      ),
    );
    sections.add(
      _DocSection(
        title: '7. 기본 내용 확인 서명',
        body: '서명 의미: 회원정보, 상품명, 이용횟수, 결제금액, 결제방법, 결제일 및 계약기간 확인\n'
            '회원 기본 확인 서명: ${_memberSigned ? '완료${_memberSignedAt != null ? ' (${_formatDateTime(_memberSignedAt!)})' : ''}' : '미완료'}\n'
            '강사 기본 확인 서명: ${_staffSigned ? '완료${_staffSignedAt != null ? ' (${_formatDateTime(_staffSignedAt!)})' : ''}' : '미완료'}',
      ),
    );
    sections.add(
      _DocSection(
        title: '8. 최종 동의 서명',
        body: '서명 의미: 계약조건, 환불/중도해지 기준, 예약/노쇼 기준, 건강고지 및 최종 계약내용 동의\n'
            '회원 최종 동의 서명: ${_memberFinalSigned ? '완료${_memberFinalSignedAt != null ? ' (${_formatDateTime(_memberFinalSignedAt!)})' : ''}' : '미완료'}\n'
            '강사 최종 확인 서명: ${_staffFinalSigned ? '완료${_staffFinalSignedAt != null ? ' (${_formatDateTime(_staffFinalSignedAt!)})' : ''}' : '미완료'}',
      ),
    );

    return sections;
  }

  String get _documentSnapshot {
    final buffer = StringBuffer();
    for (final section in _documentSections) {
      buffer.writeln('[${section.title}]');
      buffer.writeln(section.body);
      buffer.writeln();
    }
    buffer.writeln('[안내]');
    buffer.writeln(
      '본 계약서는 앱 화면에서 확인한 기본정보, 결제정보, 계약조건, 건강고지, 최종확인 및 수령방식 내용을 기준으로 저장됩니다.',
    );
    buffer.writeln(
      '기본 내용 확인 서명은 상품·금액·계약기간 확인을 의미하며, 최종 동의 서명은 전체 계약조건 확인 및 선택한 계약서 수령 방식에 대한 동의를 의미합니다.',
    );
    return buffer.toString().trim();
  }

  List<String> get _blockedExportMessages {
    final messages = <String>[];
    if (!_isDocumentSetupComplete) {
      messages.add('문서종류/작성방식 확인이 필요합니다.');
    }
    if (!_isBasicInfoComplete) {
      messages.add('기본정보 입력이 필요합니다.');
    }
    if (!_isPaymentSectionComplete) {
      messages.add('개인레슨 결제정보 입력이 필요합니다.');
    }
    if (!_isDateRangeValid) {
      messages.add('계약일과 종료일 순서를 확인해주세요.');
    }
    if (!_isContractConditionsComplete) {
      messages.add('계약 조건 확인이 필요합니다.');
    }
    if (!_isHealthSelectionComplete) {
      messages.add('건강 고지 세부 선택이 필요합니다.');
    }
    if (!_isHealthSectionComplete) {
      messages.add('건강 고지 확인이 필요합니다.');
    }
    if (!_isFinalConfirmComplete) {
      messages.add('최종 확인 체크가 필요합니다.');
    }
    if (!_memberSigned) {
      messages.add('회원 기본 내용 확인 서명이 필요합니다.');
    }

    if (!_staffSigned) {
      messages.add('강사 기본 내용 확인 서명이 필요합니다.');
    }

    if (!_memberFinalSigned) {
      messages.add('회원 최종 동의 서명이 필요합니다.');
    }

    if (!_staffFinalSigned) {
      messages.add('강사 최종 확인 서명이 필요합니다.');
    }

    if (_deliveryMethod == ContractDeliveryMethod.email &&
        !_isMemberEmailFormatValid) {
      messages.add('이메일 수령을 위해 올바른 회원 이메일이 필요합니다.');
    }

    if ((_deliveryMethod == ContractDeliveryMethod.sms ||
            _deliveryMethod == ContractDeliveryMethod.kakao) &&
        !_isMemberPhoneFormatValid) {
      messages.add('문자/카카오톡 수령을 위해 올바른 회원 연락처가 필요합니다.');
    }

    return messages;
  }

  bool get _hasAnyHealthIssue {
    return _healthPain ||
        _healthSurgery ||
        _healthAccident ||
        _healthPregnancy ||
        _healthRehab;
  }

  // -------------------- MENU / ACTIONS --------------------

  Future<void> _handleMoreMenuAction(_ContractMoreAction action) async {
    if (_isFormLocked &&
        (action == _ContractMoreAction.sourceMode ||
            action == _ContractMoreAction.documentType)) {
      _showSnack('서명 완료 후 수정은 새 버전 작성으로 진행해주세요.');
      return;
    }

    switch (action) {
      case _ContractMoreAction.documentType:
        _showDocumentTypeSelector();
        break;
      case _ContractMoreAction.sourceMode:
        _showSourceModeSelector();
        break;
      case _ContractMoreAction.tempSave:
        await _handleTempSave();
        break;
      case _ContractMoreAction.savePdf:
        await _trySavePdf();
        break;

      case _ContractMoreAction.sendCustomer:
        await _trySendCustomer();
        break;
      case _ContractMoreAction.sendTrainer:
        _showTrainerTransferComingSoon();
        break;
      case _ContractMoreAction.newVersion:
        _startNewVersion();
        break;
    }
  }

  Future<void> _handleTempSave() async {
    if (_isSavingContract) return;

    setState(() {
      _isSavingContract = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      _contractId ??= firestore.collection('contracts').doc().id;
      _contractNo ??= await _generateContractNo();

      _contractStatus = ContractStatus.draft;

      await firestore.collection('contracts').doc(_contractId).set(
        {
          ..._step1ContractPayload,
          'stage': ContractStatus.draft.name,
          'status': ContractStatus.draft.name,
          'draftSavedAt': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      setState(() {
        _draftSaved = true;
      });

      _showSnack('임시저장했어요. 계약번호: $_contractNo');
    } catch (e) {
      if (!mounted) return;
      _showSnack('임시저장에 실패했어요: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSavingContract = false;
        });
      }
    }
  }

  Future<void> _showDocumentTypeSelector() async {
    if (_isFormLocked) {
      _showSnack('서명 완료 후 수정은 새 버전 작성으로 진행해주세요.');
      return;
    }

    final result = await AifcOptionChatSheet.show<String>(
      context: context,
      nickname: _normalizeContractNickname(_trainerNameController.text),
      title: '문서종류를 선택하시겠습니까?',
      message: '계약서 제목과 문서 기준에 반영될 문서종류를 선택합니다.\n'
          '선택한 문서종류는 계약서 미리보기와 저장 문서에 반영됩니다.',
      selectedValue: _documentType,
      items: const [
        AifcOptionItem<String>(
          value: 'PT수업 계약서',
          title: 'PT수업 계약서',
          subtitle: '개인 PT 수업 계약에 사용합니다.',
          icon: Icons.fitness_center_rounded,
        ),
        AifcOptionItem<String>(
          value: '필라테스 개인레슨 계약서',
          title: '필라테스 개인레슨 계약서',
          subtitle: '필라테스 개인레슨 계약에 사용합니다.',
          icon: Icons.self_improvement_rounded,
        ),
        AifcOptionItem<String>(
          value: '골프 개인레슨 계약서',
          title: '골프 개인레슨 계약서',
          subtitle: '골프 개인레슨 계약에 사용합니다.',
          icon: Icons.sports_golf_rounded,
        ),
        AifcOptionItem<String>(
          value: '자유이용권 계약서',
          title: '자유이용권 계약서',
          subtitle: '개인레슨이 아닌 이용권 계약에 사용합니다.',
          icon: Icons.confirmation_number_outlined,
        ),
      ],
      pickedReplyText: (item) {
        return '확인되었습니다. ${item.title} 문서종류로 적용합니다.';
      },
    );

    if (result == null) return;
    if (_documentType == result) return;

    setState(() {
      _documentType = result;
      _ContractUiMemory.lastDocumentType = result;
    });

    _clearAllSignaturesBecauseContentChanged(
      message: '문서종류가 변경되어 기존 서명이 초기화되었습니다.',
    );
  }

  Future<void> _showSourceModeSelector() async {
    if (_isFormLocked) {
      _showSnack('서명 완료 후 수정은 새 버전 작성으로 진행해주세요.');
      return;
    }

    final result = await AifcOptionChatSheet.show<ContractSourceMode>(
      context: context,
      nickname: _normalizeContractNickname(_trainerNameController.text),
      title: '계약서 작성방식을 선택하시겠습니까?',
      message: '작성방식은 계약서 문구와 보관 방식에 영향을 줍니다.\n'
          '현재 계약서 운영 방식에 맞는 항목을 선택해주세요.',
      selectedValue: _sourceMode,
      items: const [
        AifcOptionItem<ContractSourceMode>(
          value: ContractSourceMode.basicTemplate,
          title: '기본양식서류',
          subtitle: '기본 계약 문구를 기준으로 값을 입력해 작성합니다.',
          icon: Icons.article_outlined,
        ),
        AifcOptionItem<ContractSourceMode>(
          value: ContractSourceMode.customWrite,
          title: '내용작성',
          subtitle: '기본 프레임워크 위에 계약 문구를 직접 작성합니다.',
          icon: Icons.edit_document,
        ),
        AifcOptionItem<ContractSourceMode>(
          value: ContractSourceMode.uploadPdf,
          title: '기존계약서 PDF 보관',
          subtitle: '작성 완료된 PDF를 보관하고 추가 확인 항목을 기록합니다.',
          icon: Icons.picture_as_pdf_outlined,
        ),
      ],
      pickedReplyText: (item) {
        return '확인되었습니다. ${item.title} 방식으로 적용합니다.';
      },
    );

    if (result == null) return;
    if (_sourceMode == result) return;

    setState(() {
      _sourceMode = result;
      _ContractUiMemory.lastSourceMode = result;

      if (result == ContractSourceMode.customWrite) {
        _fillHybridClausesFromTemplate(force: false);
      }
    });

    _clearAllSignaturesBecauseContentChanged(
      message: '작성방식이 변경되어 기존 서명이 초기화되었습니다.',
    );
  }

  Widget _buildSourceModeTile({
    required ContractSourceMode mode,
    required String title,
    required String subtitle,
  }) {
    final selected = _sourceMode == mode;

    return ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      leading: Icon(
        selected ? Icons.check_circle_rounded : Icons.tune_rounded,
        color: selected ? const Color(0xFF7C3AED) : const Color(0xFF64748B),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      onTap: () => Navigator.pop(context, mode),
    );
  }

  Future<void> _showPricePresetManager() async {
    await _showLessonPriceManager();
  }

  Future<void> _showLessonPriceManager() async {
    final tempCategories = _ContractUiMemory.lessonTemplateCategories
        .map((e) => e.clone())
        .toList();

    if (tempCategories.isEmpty) {
      tempCategories.add(
        _LessonTemplateCategory(
          id: _newTemplateId('cat'),
          name: '새 카테고리',
          items: [
            _LessonTemplateItem(
              id: _newTemplateId('item'),
              name: '새 레슨',
              sessionCount: 10,
              totalPrice: 0,
              vatIncluded: true,
            ),
          ],
        ),
      );
    }

    final Set<String> expandedCategoryIds = {
      if (tempCategories.isNotEmpty) tempCategories.first.id,
    };

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: FractionallySizedBox(
                heightFactor: 0.92,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    children: [
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '레슨 금액 설정',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '카테고리를 탭해서 열고, 그 안에 레슨 항목을 추가/수정할 수 있습니다.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                            height: 1.45,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: ListView(
                          children: [
                            ...tempCategories.asMap().entries.map((entry) {
                              final categoryIndex = entry.key;
                              final category = entry.value;
                              final isExpanded =
                                  expandedCategoryIds.contains(category.id);

                              return Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9FAFB),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    InkWell(
                                      borderRadius: BorderRadius.circular(18),
                                      onTap: () {
                                        setSheetState(() {
                                          if (isExpanded) {
                                            expandedCategoryIds
                                                .remove(category.id);
                                          } else {
                                            expandedCategoryIds
                                                .add(category.id);
                                          }
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                            14, 14, 14, 14),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                category.name.trim().isEmpty
                                                    ? '새 카테고리'
                                                    : category.name.trim(),
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w900,
                                                  color: Color(0xFF111827),
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                                border: Border.all(
                                                  color:
                                                      const Color(0xFFE5E7EB),
                                                ),
                                              ),
                                              child: Text(
                                                '${category.items.length}개',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if (tempCategories.length > 1)
                                              IconButton(
                                                onPressed: () {
                                                  setSheetState(() {
                                                    expandedCategoryIds
                                                        .remove(category.id);
                                                    tempCategories.removeAt(
                                                        categoryIndex);
                                                  });
                                                },
                                                icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                ),
                                                tooltip: '카테고리 삭제',
                                              ),
                                            Icon(
                                              isExpanded
                                                  ? Icons
                                                      .keyboard_arrow_up_rounded
                                                  : Icons
                                                      .keyboard_arrow_down_rounded,
                                              color: const Color(0xFF64748B),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      child: isExpanded
                                          ? Padding(
                                              key: ValueKey(
                                                  'category_open_${category.id}'),
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      14, 0, 14, 14),
                                              child: Column(
                                                children: [
                                                  TextFormField(
                                                    key: ValueKey(
                                                        'category_name_${category.id}'),
                                                    initialValue: category.name,
                                                    onChanged: (value) {
                                                      tempCategories[
                                                              categoryIndex] =
                                                          tempCategories[
                                                                  categoryIndex]
                                                              .copyWith(
                                                        name: value,
                                                      );
                                                    },
                                                    decoration: InputDecoration(
                                                      labelText: '카테고리명',
                                                      hintText:
                                                          '예: PT 레슨 / 재활 레슨 / 필라테스 / 요가',
                                                      filled: true,
                                                      fillColor: Colors.white,
                                                      border:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(14),
                                                      ),
                                                      enabledBorder:
                                                          OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(14),
                                                        borderSide:
                                                            const BorderSide(
                                                          color:
                                                              Color(0xFFE5E7EB),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 12),
                                                  ...category.items
                                                      .asMap()
                                                      .entries
                                                      .map((itemEntry) {
                                                    final itemIndex =
                                                        itemEntry.key;
                                                    final item =
                                                        itemEntry.value;

                                                    return Container(
                                                      width: double.infinity,
                                                      margin:
                                                          const EdgeInsets.only(
                                                              bottom: 10),
                                                      padding:
                                                          const EdgeInsets.all(
                                                              12),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(16),
                                                        border: Border.all(
                                                          color: const Color(
                                                              0xFFE5E7EB),
                                                        ),
                                                      ),
                                                      child: Column(
                                                        children: [
                                                          Row(
                                                            children: [
                                                              const Expanded(
                                                                child: Text(
                                                                  '레슨 항목',
                                                                  style:
                                                                      TextStyle(
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w800,
                                                                    color: Color(
                                                                        0xFF111827),
                                                                  ),
                                                                ),
                                                              ),
                                                              if (category.items
                                                                      .length >
                                                                  1)
                                                                IconButton(
                                                                  onPressed:
                                                                      () {
                                                                    setSheetState(
                                                                        () {
                                                                      final nextItems = [
                                                                        ...category
                                                                            .items
                                                                      ]..removeAt(
                                                                          itemIndex);

                                                                      tempCategories[
                                                                          categoryIndex] = tempCategories[
                                                                              categoryIndex]
                                                                          .copyWith(
                                                                        items:
                                                                            nextItems,
                                                                      );
                                                                    });
                                                                  },
                                                                  icon:
                                                                      const Icon(
                                                                    Icons
                                                                        .remove_circle_outline_rounded,
                                                                  ),
                                                                  tooltip:
                                                                      '레슨 항목 삭제',
                                                                ),
                                                            ],
                                                          ),
                                                          TextFormField(
                                                            key: ValueKey(
                                                                'item_name_${item.id}'),
                                                            initialValue:
                                                                item.name,
                                                            onChanged: (value) {
                                                              final nextItems =
                                                                  [
                                                                ...tempCategories[
                                                                        categoryIndex]
                                                                    .items
                                                              ];
                                                              nextItems[
                                                                      itemIndex] =
                                                                  nextItems[
                                                                          itemIndex]
                                                                      .copyWith(
                                                                name: value,
                                                              );
                                                              tempCategories[
                                                                      categoryIndex] =
                                                                  tempCategories[
                                                                          categoryIndex]
                                                                      .copyWith(
                                                                items:
                                                                    nextItems,
                                                              );
                                                            },
                                                            decoration:
                                                                InputDecoration(
                                                              labelText: '상품명',
                                                              hintText:
                                                                  '예: 개인PT 10회 레슨',
                                                              filled: true,
                                                              fillColor:
                                                                  const Color(
                                                                      0xFFF9FAFB),
                                                              border:
                                                                  OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            14),
                                                              ),
                                                              enabledBorder:
                                                                  OutlineInputBorder(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            14),
                                                                borderSide:
                                                                    const BorderSide(
                                                                  color: Color(
                                                                      0xFFE5E7EB),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              height: 10),
                                                          Row(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              SizedBox(
                                                                width: 76,
                                                                child:
                                                                    TextFormField(
                                                                  key: ValueKey(
                                                                      'item_count_${item.id}'),
                                                                  initialValue: item
                                                                      .sessionCount
                                                                      .toString(),
                                                                  keyboardType:
                                                                      TextInputType
                                                                          .number,
                                                                  inputFormatters: [
                                                                    FilteringTextInputFormatter
                                                                        .digitsOnly,
                                                                  ],
                                                                  onChanged:
                                                                      (value) {
                                                                    final nextItems =
                                                                        [
                                                                      ...tempCategories[
                                                                              categoryIndex]
                                                                          .items
                                                                    ];
                                                                    nextItems[
                                                                        itemIndex] = nextItems[
                                                                            itemIndex]
                                                                        .copyWith(
                                                                      sessionCount:
                                                                          _parseInt(
                                                                              value),
                                                                    );
                                                                    tempCategories[
                                                                        categoryIndex] = tempCategories[
                                                                            categoryIndex]
                                                                        .copyWith(
                                                                            items:
                                                                                nextItems);
                                                                  },
                                                                  decoration:
                                                                      InputDecoration(
                                                                    labelText:
                                                                        '횟수',
                                                                    suffixText:
                                                                        '회',
                                                                    filled:
                                                                        true,
                                                                    fillColor:
                                                                        const Color(
                                                                            0xFFF9FAFB),
                                                                    border:
                                                                        OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              14),
                                                                    ),
                                                                    enabledBorder:
                                                                        OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              14),
                                                                      borderSide:
                                                                          const BorderSide(
                                                                              color: Color(0xFFE5E7EB)),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  width: 8),
                                                              Expanded(
                                                                child:
                                                                    TextFormField(
                                                                  key: ValueKey(
                                                                      'item_total_${item.id}'),
                                                                  initialValue: item
                                                                      .totalPrice
                                                                      .toString(),
                                                                  keyboardType:
                                                                      TextInputType
                                                                          .number,
                                                                  inputFormatters: [
                                                                    FilteringTextInputFormatter
                                                                        .digitsOnly,
                                                                  ],
                                                                  onChanged:
                                                                      (value) {
                                                                    final nextItems =
                                                                        [
                                                                      ...tempCategories[
                                                                              categoryIndex]
                                                                          .items
                                                                    ];
                                                                    nextItems[
                                                                        itemIndex] = nextItems[
                                                                            itemIndex]
                                                                        .copyWith(
                                                                      totalPrice:
                                                                          _parseInt(
                                                                              value),
                                                                    );
                                                                    tempCategories[
                                                                        categoryIndex] = tempCategories[
                                                                            categoryIndex]
                                                                        .copyWith(
                                                                            items:
                                                                                nextItems);
                                                                  },
                                                                  decoration:
                                                                      InputDecoration(
                                                                    labelText:
                                                                        '실결제금액',
                                                                    prefixText:
                                                                        '₩ ',
                                                                    suffixText:
                                                                        '원',
                                                                    filled:
                                                                        true,
                                                                    fillColor:
                                                                        const Color(
                                                                            0xFFF9FAFB),
                                                                    border:
                                                                        OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              14),
                                                                    ),
                                                                    enabledBorder:
                                                                        OutlineInputBorder(
                                                                      borderRadius:
                                                                          BorderRadius.circular(
                                                                              14),
                                                                      borderSide:
                                                                          const BorderSide(
                                                                              color: Color(0xFFE5E7EB)),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                  width: 8),
                                                              Container(
                                                                height: 56,
                                                                padding: const EdgeInsets
                                                                    .symmetric(
                                                                    horizontal:
                                                                        8),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color: const Color(
                                                                      0xFFF9FAFB),
                                                                  borderRadius:
                                                                      BorderRadius
                                                                          .circular(
                                                                              14),
                                                                  border: Border.all(
                                                                      color: const Color(
                                                                          0xFFE5E7EB)),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  children: [
                                                                    Checkbox(
                                                                      value: item
                                                                          .vatIncluded,
                                                                      visualDensity:
                                                                          VisualDensity
                                                                              .compact,
                                                                      materialTapTargetSize:
                                                                          MaterialTapTargetSize
                                                                              .shrinkWrap,
                                                                      onChanged:
                                                                          (value) async {
                                                                        await _toggleTemplateVatIncluded(
                                                                          nextValue:
                                                                              value ?? false,
                                                                          tempCategories:
                                                                              tempCategories,
                                                                          categoryIndex:
                                                                              categoryIndex,
                                                                          itemIndex:
                                                                              itemIndex,
                                                                          setSheetState:
                                                                              setSheetState,
                                                                        );
                                                                      },
                                                                    ),
                                                                    const Text(
                                                                      'VAT 포함',
                                                                      style:
                                                                          TextStyle(
                                                                        fontSize:
                                                                            12.5,
                                                                        fontWeight:
                                                                            FontWeight.w700,
                                                                        color: Color(
                                                                            0xFF374151),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                          const SizedBox(
                                                              height: 10),
                                                          Align(
                                                            alignment: Alignment
                                                                .centerLeft,
                                                            child: Text(
                                                              item.sessionCount >
                                                                      0
                                                                  ? '회당 결제금액 자동 계산: ${_formatMoney(((item.vatIncluded ? (item.totalPrice / 1.1).round() : item.totalPrice) / item.sessionCount).round())}원'
                                                                  : '횟수를 입력하면 회당 결제금액이 자동 계산됩니다.',
                                                              style:
                                                                  const TextStyle(
                                                                fontSize: 12.2,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Color(
                                                                    0xFF64748B),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }),
                                                  Align(
                                                    alignment:
                                                        Alignment.centerLeft,
                                                    child: OutlinedButton.icon(
                                                      onPressed: () {
                                                        setSheetState(() {
                                                          final nextItems = [
                                                            ...tempCategories[
                                                                    categoryIndex]
                                                                .items,
                                                            _LessonTemplateItem(
                                                              id: _newTemplateId(
                                                                  'item'),
                                                              name: '새 레슨',
                                                              sessionCount: 10,
                                                              totalPrice: 0,
                                                              vatIncluded: true,
                                                            ),
                                                          ];

                                                          tempCategories[
                                                                  categoryIndex] =
                                                              tempCategories[
                                                                      categoryIndex]
                                                                  .copyWith(
                                                            items: nextItems,
                                                          );
                                                        });
                                                      },
                                                      icon: const Icon(
                                                          Icons.add_rounded),
                                                      label: const Text(
                                                          '레슨 항목 추가'),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : const SizedBox.shrink(
                                              key: ValueKey('category_closed'),
                                            ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  setSheetState(() {
                                    final newCategory = _LessonTemplateCategory(
                                      id: _newTemplateId('cat'),
                                      name: '새 카테고리',
                                      items: [
                                        _LessonTemplateItem(
                                          id: _newTemplateId('item'),
                                          name: '새 레슨',
                                          sessionCount: 10,
                                          totalPrice: 0,
                                          vatIncluded: true,
                                        ),
                                      ],
                                    );
                                    tempCategories.add(newCategory);
                                    expandedCategoryIds.add(newCategory.id);
                                  });
                                },
                                icon: const Icon(Icons.add_rounded),
                                label: const Text('카테고리 추가'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('닫기'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                final cleaned = tempCategories
                                    .map(
                                      (category) => category.copyWith(
                                        name: category.name.trim(),
                                        items: category.items
                                            .where(
                                              (item) =>
                                                  item.name.trim().isNotEmpty &&
                                                  item.sessionCount > 0 &&
                                                  item.totalPrice > 0,
                                            )
                                            .map(
                                              (item) => item.copyWith(
                                                name: item.name.trim(),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    )
                                    .where(
                                      (category) =>
                                          category.name.trim().isNotEmpty &&
                                          category.items.isNotEmpty,
                                    )
                                    .toList();

                                if (cleaned.isEmpty) {
                                  _showSnack(
                                    '카테고리명, 상품명, 횟수, 금액이 모두 입력된 레슨 항목을 1개 이상 저장해주세요.',
                                  );
                                  return;
                                }

                                setState(() {
                                  _ContractUiMemory.lessonTemplateCategories =
                                      cleaned;
                                });

                                Navigator.pop(context);
                                _showSnack('레슨 금액 설정이 저장되었습니다.');
                              },
                              child: const Text('저장'),
                            ),
                          ),
                        ],
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
  }

  void _applyLessonTemplate(_LessonTemplateItem item) {
    final hadSignature = _memberSigned ||
        _staffSigned ||
        _memberFinalSigned ||
        _staffFinalSigned;

    final int actualTotal = item.totalPrice;
    final int baseTotal =
        item.vatIncluded ? (actualTotal / 1.1).round() : actualTotal;

    final int unitPrice =
        item.sessionCount > 0 ? (baseTotal / item.sessionCount).round() : 0;

    _isApplyingProgrammaticChange = true;

    setState(() {
      _productNameController.text = item.name;
      _sessionCountController.text = item.sessionCount.toString();
      _unitPriceController.text = _formatMoney(unitPrice);
      _priceController.text = _formatMoney(actualTotal);
      _vatIncluded = item.vatIncluded;
      _ContractUiMemory.vatIncluded = item.vatIncluded;
    });

    _isApplyingProgrammaticChange = false;

    if (hadSignature) {
      _clearAllSignaturesBecauseContentChanged(
        message: '레슨 금액 정보가 변경되어 기존 서명이 초기화되었습니다.',
      );
    }

    _lastSignatureSensitiveSnapshot = _signatureSensitiveSnapshot;

    _showSnack(
      '${item.name} 금액설정 완료 · ${item.vatIncluded ? 'VAT 포함' : 'VAT 미포함'}',
    );
  }

  String? _inferDocumentTypeFromProduct(ProductModel product) {
    final text = [
      product.categoryName,
      product.name,
      product.lessonType,
    ].join(' ').toLowerCase();

    if (text.contains('필라테스') ||
        text.contains('바렐') ||
        text.contains('자이로토닉') ||
        text.contains('pilates')) {
      return '필라테스 개인레슨 계약서';
    }

    if (text.contains('골프') || text.contains('golf')) {
      return '골프 개인레슨 계약서';
    }

    if (text.contains('pt') ||
        text.contains('피티') ||
        text.contains('웨이트') ||
        text.contains('퍼스널')) {
      return 'PT레슨 계약서';
    }

    if (text.contains('그룹레슨') ||
        text.contains('그룹피티') ||
        text.contains('2:1') ||
        text.contains('2') ||
        text.contains('group') ||
        text.contains('그룹')) {
      return '그룹레슨 계약서';
    }

    if (text.contains('요가레슨') ||
        text.contains('요기') ||
        text.contains('핫요가') ||
        text.contains('요가')) {
      return '요가 개인레슨 계약서';
    }

    if (text.contains('댄스레슨') ||
        text.contains('댄스') ||
        text.contains('dance')) {
      return '댄스 개인레슨 계약서';
    }

    if (text.contains('발레핏') ||
        text.contains('발레') ||
        text.contains('ballefit')) {
      return '발레핏 개인레슨 계약서';
    }

    return null;
  }

  DateTime _recommendedEndDateForProduct(ProductModel product) {
    final contractDate =
        _tryParseDate(_contractDateController.text.trim()) ?? DateTime.now();

    final count = product.sessionCount;

    int months;

    if (count <= 10) {
      months = 2;
    } else if (count <= 20) {
      months = 4;
    } else if (count <= 30) {
      months = 7;
    } else {
      months = 10;
    }

    return DateTime(
      contractDate.year,
      contractDate.month + months,
      contractDate.day,
    );
  }

  void _applyProduct(ProductModel product) {
    final hadSignature = _memberSigned ||
        _staffSigned ||
        _memberFinalSigned ||
        _staffFinalSigned;

    final inferredDocumentType = _inferDocumentTypeFromProduct(product);

    _isApplyingProgrammaticChange = true;

    final recommendedEndDate = _recommendedEndDateForProduct(product);

    setState(() {
      _selectedProduct = product;

      _productNameController.text = product.name;
      _sessionCountController.text = product.sessionCount.toString();
      _unitPriceController.text = _formatMoney(product.unitPrice);
      _priceController.text = _formatMoney(product.totalPrice);
      _vatIncluded = product.vatIncluded;

      if (!_isUnlimitedEndDate) {
        _endDateController.text = _formatDate(recommendedEndDate);
      }

      if (inferredDocumentType != null &&
          inferredDocumentType != _documentType) {
        _documentType = inferredDocumentType;
        _ContractUiMemory.lastDocumentType = inferredDocumentType;
      }

      _ContractUiMemory.vatIncluded = product.vatIncluded;
    });

    _isApplyingProgrammaticChange = false;

    if (hadSignature) {
      _clearAllSignaturesBecauseContentChanged(
        message: '상품 정보가 변경되어 기존 서명이 초기화되었습니다.',
      );
    }

    _lastSignatureSensitiveSnapshot = _signatureSensitiveSnapshot;

    _showSnack(
      '${product.name} 상품을 불러왔어요. 문서종류와 금액을 확인해주세요.',
    );
  }

  Future<bool> _showVatApplyDialog() {
    return AifcConfirmChatSheet.show(
      context: context,
      nickname: _normalizeContractNickname(_trainerNameController.text),
      title: 'VAT 포함 금액을 적용하시겠습니까?',
      message: '현재 입력한 금액에 부가세 10%를 반영하여 실결제금액을 다시 계산합니다.\n'
          '계약서의 결제금액에 영향을 줄 수 있으므로 적용 전 내용을 확인해주세요.',
      cancelText: '취소',
      confirmText: '적용',
      userCancelText: '적용하지 않겠습니다',
      userConfirmText: 'VAT 포함 금액을 적용합니다',
      cancelReplyText: '확인했습니다. 현재 금액을 유지합니다.',
      confirmReplyText: '확인되었습니다. VAT 포함 금액으로 실결제금액을 반영합니다.',
      danger: false,
    );
  }

  Future<void> _toggleTemplateVatIncluded({
    required bool nextValue,
    required List<_LessonTemplateCategory> tempCategories,
    required int categoryIndex,
    required int itemIndex,
    required void Function(void Function()) setSheetState,
  }) async {
    final currentItem = tempCategories[categoryIndex].items[itemIndex];
    int nextTotal = currentItem.totalPrice;

    if (!currentItem.vatIncluded && nextValue) {
      final shouldApply = await _showVatApplyDialog();
      if (!shouldApply) return;
      nextTotal = (currentItem.totalPrice * 1.1).round();
    }

    final nextItems = [...tempCategories[categoryIndex].items];
    nextItems[itemIndex] = nextItems[itemIndex].copyWith(
      vatIncluded: nextValue,
      totalPrice: nextTotal,
    );

    setSheetState(() {
      tempCategories[categoryIndex] = tempCategories[categoryIndex].copyWith(
        items: nextItems,
      );
    });
  }

  void _applyPricePreset(int count) {
    final unitPrice = _ContractUiMemory.lessonUnitPricePresets[count];
    if (unitPrice == null) return;

    setState(() {
      _sessionCountController.text = count.toString();
      _unitPriceController.text = _formatMoney(unitPrice);
      _priceController.text = _formatMoney(count * unitPrice);
      _productNameController.text = '개인레슨 ${count}회';
    });

    _showSnack('$count회 기준 금액을 불러왔습니다.');
  }

  Future<void> _scrollToFirstIncompleteSection() async {
    if (!_isBasicInfoComplete) {
      await _scrollToSection(_basicInfoSectionKey);
      return;
    }
    if (!_isPaymentSectionComplete) {
      await _scrollToSection(_paymentSectionKey);
      return;
    }
    if (!_isContractConditionsComplete) {
      await _scrollToSection(_contractSectionKey);
      return;
    }
    if (!_isHealthSectionComplete) {
      await _scrollToSection(_healthSectionKey);
      return;
    }
    if (!_isFinalConfirmComplete) {
      await _scrollToSection(_finalSectionKey);
      return;
    }
    if (!_memberSigned || !_staffSigned) {
      await _scrollToSection(_signatureSectionKey);
    }
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    final targetContext = key.currentContext;
    if (targetContext == null) return;

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
      alignment: 0.08,
    );
  }

  Future<Uint8List> _buildContractPdfBytes() async {
    final fontData =
        await rootBundle.load('assets/fonts/NotoSansKR-VariableFont_wght.ttf');

    final regularFont = pw.Font.ttf(fontData);
    final boldFont = pw.Font.ttf(fontData);
    final memberBasicSign = await _signatureToPngBytes(_memberSignaturePoints);
    final staffBasicSign = await _signatureToPngBytes(_staffSignaturePoints);
    final memberFinalSign =
        await _signatureToPngBytes(_memberFinalSignaturePoints);
    final staffFinalSign =
        await _signatureToPngBytes(_staffFinalSignaturePoints);

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(
        base: regularFont,
        bold: boldFont,
      ),
    );

    pw.TextStyle normal({
      double size = 9.5,
      PdfColor color = PdfColors.grey800,
      pw.FontWeight weight = pw.FontWeight.normal,
    }) {
      return pw.TextStyle(
        fontSize: size,
        color: color,
        fontWeight: weight,
      );
    }

    pw.Widget title(String text) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Text(
          text,
          style: normal(
            size: 11.5,
            color: PdfColors.grey900,
            weight: pw.FontWeight.bold,
          ),
        ),
      );
    }

    pw.Widget infoTable(List<List<String>> rows) {
      return pw.Table(
        border: pw.TableBorder.all(
          color: PdfColors.grey500,
          width: 0.6,
        ),
        columnWidths: {
          0: const pw.FixedColumnWidth(58),
          1: const pw.FlexColumnWidth(),
          2: const pw.FixedColumnWidth(58),
          3: const pw.FlexColumnWidth(),
        },
        children: rows.map((row) {
          return pw.TableRow(
            children: [
              _pdfCell(row[0], label: true),
              _pdfCell(row[1]),
              _pdfCell(row[2], label: true),
              _pdfCell(row[3]),
            ],
          );
        }).toList(),
      );
    }

    pw.Widget ruleBox(String sectionTitle, List<String> items) {
      return pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey500, width: 0.6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: PdfColors.grey200,
              child: pw.Text(
                sectionTitle,
                style: normal(
                  size: 10,
                  color: PdfColors.grey900,
                  weight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: List.generate(items.length, (index) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Text(
                      '${index + 1}. ${items[index]}',
                      style: normal(size: 9),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      );
    }

    pw.Widget signatureBox({
      required String label,
      required String name,
      required Uint8List? imageBytes,
      DateTime? signedAt,
    }) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: normal(size: 9.5, weight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Container(
            height: 54,
            width: double.infinity,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey500, width: 0.6),
            ),
            alignment: pw.Alignment.center,
            child: imageBytes == null
                ? pw.Text('미서명',
                    style: normal(size: 9, color: PdfColors.grey500))
                : pw.Image(
                    pw.MemoryImage(imageBytes),
                    fit: pw.BoxFit.contain,
                  ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            name.trim().isEmpty ? '-' : name.trim(),
            style: normal(size: 9),
          ),
          if (signedAt != null)
            pw.Text(
              _formatDateTime(signedAt),
              style: normal(size: 8, color: PdfColors.grey600),
            ),
        ],
      );
    }

    pw.Widget signatureGroup({
      required String groupTitle,
      required String description,
      required Uint8List? memberImage,
      required Uint8List? staffImage,
      required DateTime? memberSignedAt,
      required DateTime? staffSignedAt,
      required String memberLabel,
      required String staffLabel,
    }) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey500, width: 0.6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              groupTitle,
              style: normal(
                size: 10.5,
                color: PdfColors.grey900,
                weight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(description, style: normal(size: 8.8)),
            pw.SizedBox(height: 8),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: signatureBox(
                    label: memberLabel,
                    name: _memberNameController.text,
                    imageBytes: memberImage,
                    signedAt: memberSignedAt,
                  ),
                ),
                pw.SizedBox(width: 14),
                pw.Expanded(
                  child: signatureBox(
                    label: staffLabel,
                    name: _trainerNameController.text,
                    imageBytes: staffImage,
                    signedAt: staffSignedAt,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.fromLTRB(
          16 * PdfPageFormat.mm,
          15 * PdfPageFormat.mm,
          16 * PdfPageFormat.mm,
          16 * PdfPageFormat.mm,
        ),
        build: (context) {
          return [
            pw.Center(
              child: pw.Text(
                _documentType,
                style: normal(
                  size: 18,
                  color: PdfColors.grey900,
                  weight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 3),
            pw.Center(
              child: pw.Text(
                'Personal Training Contract',
                style: normal(size: 9, color: PdfColors.grey600),
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Container(
              width: double.infinity,
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: PdfColors.grey100,
              child: pw.Row(
                children: [
                  pw.Expanded(
                    child: pw.Text(
                      '계약번호: ${_contractNo ?? '저장 전'}',
                      style: normal(size: 8.8, weight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Text(
                    '버전: v$_version',
                    style: normal(size: 8.8, weight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),
            title('계약 당사자'),
            infoTable([
              [
                '회원명',
                _valueOrDash(_memberNameController.text),
                '생년월일',
                _valueOrDash(_memberBirthController.text),
              ],
              [
                '연락처',
                _valueOrDash(_memberPhoneController.text),
                '이메일',
                _valueOrDash(_memberEmailController.text),
              ],
              [
                '센터명',
                _valueOrDash(_centerNameController.text),
                '담당강사',
                _valueOrDash(_trainerNameController.text),
              ],
            ]),
            pw.SizedBox(height: 10),
            title('상품 및 결제 정보'),
            infoTable([
              [
                '상품명',
                _usePaymentSection
                    ? _valueOrDash(_productNameController.text)
                    : '미기재',
                '횟수',
                _usePaymentSection ? '${_sessionCountValue}회' : '미기재',
              ],
              [
                '회당금액',
                _usePaymentSection
                    ? '${_formatMoney(_unitPriceValue)}원'
                    : '미기재',
                '결제금액',
                _usePaymentSection ? '${_formatMoney(_priceValue)}원' : '미기재',
              ],
              [
                'VAT',
                _usePaymentSection ? _vatLabel : '미기재',
                '결제방법',
                _usePaymentSection ? _paymentMethodLabel : '미기재',
              ],
              [
                '결제일',
                _usePaymentSection
                    ? _valueOrDash(_paymentDateController.text)
                    : '미기재',
                '계약일',
                _valueOrDash(_contractDateController.text),
              ],
              [
                '종료일',
                _isUnlimitedEndDate
                    ? '설정 안함'
                    : _valueOrDash(_endDateController.text),
                '작성방식',
                _sourceModeLabel,
              ],
            ]),
            if (_paymentDifferenceDocumentLine.isNotEmpty) ...[
              pw.SizedBox(height: 5),
              pw.Text(
                _paymentDifferenceDocumentLine,
                style: normal(
                  size: 8.8,
                  color: PdfColors.green800,
                  weight: pw.FontWeight.bold,
                ),
              ),
            ],
            pw.SizedBox(height: 10),
            ruleBox(
              '계약조건',
              _contractHistoryItems.isEmpty
                  ? const ['선택된 계약 조건이 없습니다.']
                  : _contractHistoryItems,
            ),
            pw.SizedBox(height: 10),
            ruleBox(
              '건강고지',
              [
                '건강 상태: $_healthSummary',
                if (_healthDetailController.text.trim().isNotEmpty)
                  '상세 고지: ${_healthDetailController.text.trim()}',
                '건강안내 숙지: ${_agreeHealthNotice ? '완료' : '미완료'}',
              ],
            ),
            pw.SizedBox(height: 10),
            ruleBox(
              '최종 확인 및 수령 방식',
              [
                '계약내용 확인: ${_agreeImportantNotice ? '완료' : '미완료'}',
                '저장·전송 동의: ${_agreeSameContentSave ? '완료' : '미완료'}',
                '계약서 사본 수령 방식: $_deliveryMethodLabel',
                '수령 대상: $_deliveryTarget',
              ],
            ),
            pw.SizedBox(height: 12),
            signatureGroup(
              groupTitle: '기본 내용 확인 서명',
              description: '회원정보, 상품명, 이용횟수, 결제금액, 결제방법, 결제일 및 계약기간을 확인합니다.',
              memberLabel: '회원 기본 확인',
              staffLabel: '강사 기본 확인',
              memberImage: memberBasicSign,
              staffImage: staffBasicSign,
              memberSignedAt: _memberSignedAt,
              staffSignedAt: _staffSignedAt,
            ),
            pw.SizedBox(height: 10),
            signatureGroup(
              groupTitle: '최종 동의 서명',
              description:
                  '계약조건, 환불·중도해지 기준, 예약/노쇼 기준, 건강고지 및 최종 계약내용에 동의합니다. 선택한 수령 방식으로 계약서 사본이 제공될 수 있습니다.',
              memberLabel: '회원 최종 동의',
              staffLabel: '강사 최종 확인',
              memberImage: memberFinalSign,
              staffImage: staffFinalSign,
              memberSignedAt: _memberFinalSignedAt,
              staffSignedAt: _staffFinalSignedAt,
            ),
          ];
        },
      ),
    );

    return doc.save();
  }

  pw.Widget _pdfCell(
    String text, {
    bool label = false,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      color: label ? PdfColors.grey200 : PdfColors.white,
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8.8,
          fontWeight: label ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  Future<void> _updateContractDeliveryStatus({
    required String status,
    String? action,
  }) async {
    if (_contractId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('contracts')
          .doc(_contractId)
          .set(
        {
          'pdf': {
            'generated': _pdfSaved,
            'generatedAt': FieldValue.serverTimestamp(),
            'fileName': _contractPdfFileName,
          },
          'delivery': {
            'method': _deliveryMethod.name,
            'methodLabel': _deliveryMethodLabel,
            'target': _deliveryTarget,
            'status': status,
            'lastAction': action,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('PDF/수령 상태 기록에 실패했어요: $e');
    }
  }

  Future<void> _trySavePdf() async {
    if (!_isContractFullyReady) {
      await _scrollToFirstIncompleteSection();
      await _showBlockedExportDialog('PDF 저장');
      return;
    }

    try {
      final bytes = await _buildContractPdfBytes();

      setState(() {
        _pdfSaved = true;
      });

      await _updateContractDeliveryStatus(
        status: 'pdf_generated',
        action: 'share_pdf_opened',
      );

      await Printing.sharePdf(
        bytes: bytes,
        filename: _contractPdfFileName,
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('PDF 생성에 실패했어요: $e');
    }
  }

  Future<void> _trySendCustomer() async {
    if (!_isContractFullyReady) {
      await _scrollToFirstIncompleteSection();
      await _showBlockedExportDialog('고객 전송');
      return;
    }

    try {
      final bytes = await _buildContractPdfBytes();

      if (_deliveryMethod == ContractDeliveryMethod.print) {
        await Printing.layoutPdf(
          name: _contractPdfFileName,
          onLayout: (_) async => bytes,
        );

        setState(() {
          _pdfSaved = true;
          _pdfSentToCustomer = true;
        });

        await _updateContractDeliveryStatus(
          status: 'print_opened',
          action: 'print_dialog_opened',
        );

        _showSnack('인쇄 화면을 열었어요.');
        return;
      }

      if (_deliveryMethod == ContractDeliveryMethod.storeOnly) {
        setState(() {
          _pdfSaved = true;
          _pdfSentToCustomer = true;
        });

        await _updateContractDeliveryStatus(
          status: 'stored_only',
          action: 'center_store_only',
        );

        _showSnack('센터 보관으로 기록했습니다.');
        return;
      }

      await Printing.sharePdf(
        bytes: bytes,
        filename: _contractPdfFileName,
      );

      setState(() {
        _pdfSaved = true;
        _pdfSentToCustomer = true;
      });

      await _updateContractDeliveryStatus(
        status: 'share_opened',
        action: _deliveryMethod.name,
      );

      _showSnack('$_customerSendActionLabel 공유 화면을 열었어요.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('계약서 공유/인쇄 준비에 실패했어요: $e');
    }
  }

  Future<void> _showTrainerTransferComingSoon() {
    return AifcInfoChatSheet.show(
      context: context,
      nickname: _normalizeContractNickname(_trainerNameController.text),
      title: '강사 전송 기능 안내',
      message: '강사 전송 기능은 현재 준비 중입니다.\n'
          '현재 버전에서는 계약서를 저장하거나 공유 기능을 통해 별도로 전달해주세요.',
      confirmText: '확인',
      userConfirmText: '확인했습니다',
      replyText: '확인되었습니다. 현재 화면으로 돌아갑니다.',
      icon: Icons.forward_to_inbox_rounded,
      accentColor: const Color(0xFF4F46E5),
    );
  }

  Future<void> _showBlockedExportDialog(String actionLabel) {
    final items = _blockedExportMessages;

    return AifcInfoChatSheet.show(
      context: context,
      nickname: _normalizeContractNickname(_trainerNameController.text),
      title: '$actionLabel 진행 불가',
      message: '계약서에 필요한 항목이 아직 완료되지 않아 현재 단계에서는 진행할 수 없습니다.\n'
          '아래 항목을 먼저 확인해주세요.',
      items: items,
      confirmText: '확인',
      userConfirmText: '확인했습니다',
      replyText: '확인되었습니다. 필요한 항목을 먼저 완료해주세요.',
      icon: Icons.assignment_late_outlined,
      accentColor: const Color(0xFFEF4444),
    );
  }

  Future<void> _showReservationTip({required bool force}) async {
    if (!force && _ContractUiMemory.reservationTipShown) return;
    _ContractUiMemory.reservationTipShown = true;

    _showFloatingTip(
      title: '예약/지연 TIP',
      message:
          '예약 변경·취소는 24시간 전 기준을 많이 사용해요. 지연은 30분 이상부터 진행이 어렵다는 문구를 자주 씁니다.',
      icon: Icons.lightbulb_outline,
    );
  }

  Future<void> _showPenaltyTip({required bool force}) async {
    if (!force && _ContractUiMemory.penaltyTipShown) return;
    _ContractUiMemory.penaltyTipShown = true;

    _showFloatingTip(
      title: '중도해지 TIP',
      message: '위약금은 센터 정책과 상품 성격에 맞게 최종 확인 후 사용하세요. 예시로 10% 문구를 자주 사용합니다.',
      icon: Icons.info_outline,
    );
  }

  void _showFloatingTip({
    required String title,
    required String message,
    required IconData icon,
  }) {
    _tipTimer?.cancel();
    _removeTipOverlay();

    final overlay = Overlay.of(context);
    if (overlay == null) return;

    final top = MediaQuery.of(context).padding.top + 10;

    _tipOverlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          left: 16,
          right: 16,
          top: top,
          child: IgnorePointer(
            ignoring: true,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: kContractMaxContentWidth,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827).withOpacity(0.96),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: 18,
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
                                  color: Colors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message,
                                style: const TextStyle(
                                  color: Color(0xFFE5E7EB),
                                  fontSize: 12.3,
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
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
        );
      },
    );

    overlay.insert(_tipOverlayEntry!);

    _tipTimer = Timer(const Duration(milliseconds: 2600), () {
      _removeTipOverlay();
    });
  }

  void _removeTipOverlay() {
    _tipOverlayEntry?.remove();
    _tipOverlayEntry = null;
  }

  Future<void> _pickDate(TextEditingController controller) async {
    DateTime initialDate = DateTime.now();
    final parsed = _tryParseDate(controller.text.trim());
    if (parsed != null) {
      initialDate = parsed;
    }

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (selected != null) {
      controller.text = _formatDate(selected);
      setState(() {});
    }
  }

  Future<void> _pickBirthDate() async {
    DateTime initialDate = DateTime(1980, 1, 1);

    final parsed = _tryParseDate(_memberBirthController.text.trim());
    if (parsed != null) {
      initialDate = parsed;
    }

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1940, 1, 1),
      lastDate: DateTime.now(),
      helpText: '생년월일 선택',
      fieldLabelText: '생년월일',
      fieldHintText: '예: 1980-01-01',
    );

    if (selected != null) {
      _memberBirthController.text = _formatDate(selected);
      setState(() {});
    }
  }

  void _clearAllSignaturesBecauseContentChanged({
    String message = '계약 내용이 변경되어 기존 서명이 초기화되었습니다. 다시 서명해주세요.',
    bool showNotice = true,
  }) {
    final hasAnySignature = _memberSigned ||
        _staffSigned ||
        _memberFinalSigned ||
        _staffFinalSigned;

    if (!hasAnySignature) return;

    setState(() {
      _memberSignaturePoints = null;
      _staffSignaturePoints = null;
      _memberSignedAt = null;
      _staffSignedAt = null;

      _memberFinalSignaturePoints = null;
      _staffFinalSignaturePoints = null;
      _memberFinalSignedAt = null;
      _staffFinalSignedAt = null;

      _contractStatus = ContractStatus.draft;
      _draftSaved = false;
    });

    if (!showNotice) return;
    if (_signatureResetNoticeShownInThisChange) return;

    _signatureResetNoticeShownInThisChange = true;
    _showSnack(message);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _signatureResetNoticeShownInThisChange = false;
    });
  }

  void _clearFinalSignaturesBecauseDetailChanged({
    String message = '상세 확인 내용이 변경되어 최종 서명이 초기화되었습니다. 다시 최종 서명해주세요.',
    bool showNotice = true,
  }) {
    final hasFinalSignature = _memberFinalSigned || _staffFinalSigned;

    if (!hasFinalSignature) return;

    setState(() {
      _memberFinalSignaturePoints = null;
      _staffFinalSignaturePoints = null;
      _memberFinalSignedAt = null;
      _staffFinalSignedAt = null;

      if (_contractStatus == ContractStatus.signed ||
          _contractStatus == ContractStatus.sent) {
        _contractStatus = ContractStatus.step1Saved;
      }
    });

    if (!showNotice) return;
    if (_signatureResetNoticeShownInThisChange) return;

    _signatureResetNoticeShownInThisChange = true;
    _showSnack(message);

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _signatureResetNoticeShownInThisChange = false;
    });
  }

  Future<bool> _confirmDifferentSignature({
    required bool isMember,
    required double similarity,
  }) {
    final signerLabel = isMember ? '회원' : '강사';
    final similarityPercent = (similarity * 100).round();

    return AifcConfirmChatSheet.show(
      context: context,
      nickname: _normalizeContractNickname(_trainerNameController.text),
      title: '$signerLabel 서명을 확인하시겠습니까?',
      message: '이번 서명이 이전 서명과 다소 다르게 감지되었습니다.\n'
          '동일한 $signerLabel의 서명이 맞는지 확인 후 진행해주세요.\n\n'
          '서명 유사도: $similarityPercent%',
      cancelText: '다시 서명',
      confirmText: '그대로 사용',
      userCancelText: '다시 서명하겠습니다',
      userConfirmText: '동일한 서명으로 확인합니다',
      cancelReplyText: '확인했습니다. 다시 서명을 진행해주세요.',
      confirmReplyText: '확인되었습니다. 현재 서명을 계약서에 반영합니다.',
      danger: similarityPercent < 35,
    );
  }

  Future<bool> _ensureReadyForFinalSignature() async {
    if (_isContractConditionsComplete &&
        _isHealthSectionComplete &&
        _isFinalConfirmComplete) {
      return true;
    }

    setState(() {
      _showRequiredErrors = true;
      _currentStage = ContractStage.detailConfirm;
    });

    if (!_isContractConditionsComplete) {
      await _scrollToSection(_contractSectionKey);
      _showSnack('계약조건 확인 항목 중 체크되지 않은 부분이 있습니다.');
      return false;
    }

    if (!_isHealthSectionComplete) {
      await _scrollToSection(_healthSectionKey);
      _showSnack('건강고지 확인 항목을 먼저 완료해주세요.');
      return false;
    }

    if (!_isFinalConfirmComplete) {
      await _scrollToSection(_finalSectionKey);
      _showSnack('최종 확인 및 수령 방식 체크를 먼저 완료해주세요.');
      return false;
    }

    return false;
  }

  Future<void> _openSignaturePad({
    required bool isMember,
    bool isFinal = false,
  }) async {
    if (_isFormLocked) {
      _showSnack('최종 서명 완료 후 수정은 새 버전 작성으로 진행해주세요.');
      return;
    }

    if (isFinal) {
      final readyForFinalSign = await _ensureReadyForFinalSignature();
      if (!readyForFinalSign) return;
    }

    if (!_isBasicInfoComplete) {
      setState(() {
        _showRequiredErrors = true;
        _currentStage = ContractStage.requiredInfo;
      });

      _showSnack('서명 전 회원 기본정보 형식을 먼저 확인해주세요.');
      await _scrollToSection(_basicInfoSectionKey);
      return;
    }

    if (!_isPaymentSectionComplete) {
      setState(() {
        _showRequiredErrors = true;
        _currentStage = ContractStage.requiredInfo;
      });

      _showSnack('서명 전 결제정보를 먼저 확인해주세요.');
      await _scrollToSection(_paymentSectionKey);
      return;
    }

    final previousOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;

    final result = await showDialog<List<Offset?>>(
      context: context,
      builder: (_) => _SignatureDialog(
        title: isFinal
            ? (isMember ? '회원 최종 동의 서명' : '강사 최종 확인 서명')
            : (isMember ? '회원 기본 내용 확인 서명' : '강사 기본 내용 확인 서명'),
        guideName: isMember
            ? _memberNameController.text.trim()
            : _trainerNameController.text.trim(),
      ),
    );

    if (result != null && result.any((e) => e != null)) {
      final now = DateTime.now();

      // 최종서명일 때만 1차 서명과 비교합니다.
      if (isFinal) {
        final previousSignature =
            isMember ? _memberSignaturePoints : _staffSignaturePoints;

        final hasPreviousSignature = previousSignature != null &&
            previousSignature.any((e) => e != null);

        if (hasPreviousSignature) {
          final similarity = _signatureSimilarity(
            previousSignature,
            result,
          );

          if (similarity < _signatureSimilarityWarningThreshold) {
            final confirmed = await _confirmDifferentSignature(
              isMember: isMember,
              similarity: similarity,
            );

            if (!confirmed) {
              // 다시 서명을 선택하면 현재 결과는 저장하지 않습니다.
              return;
            }
          }
        }
      }
      setState(() {
        if (isFinal) {
          if (isMember) {
            _memberFinalSignaturePoints = result;
            _memberFinalSignedAt = now;
          } else {
            _staffFinalSignaturePoints = result;
            _staffFinalSignedAt = now;
          }
        } else {
          if (isMember) {
            _memberSignaturePoints = result;
            _memberSignedAt = now;
          } else {
            _staffSignaturePoints = result;
            _staffSignedAt = now;
          }
        }
      });

      if (isFinal) {
        _lastDetailSignatureSnapshot = _detailSignatureSnapshot;
      } else {
        _lastSignatureSensitiveSnapshot = _signatureSensitiveSnapshot;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_scrollController.hasClients) return;

        final max = _scrollController.position.maxScrollExtent;
        final target = previousOffset.clamp(0.0, max);

        _scrollController.jumpTo(target);
      });
    }
  }

  double _signatureSimilarity(
    List<Offset?>? a,
    List<Offset?>? b,
  ) {
    final pa = a?.whereType<Offset>().toList() ?? [];
    final pb = b?.whereType<Offset>().toList() ?? [];

    if (pa.length < 6 || pb.length < 6) return 1.0;

    Rect boundsOf(List<Offset> points) {
      double minX = points.first.dx;
      double maxX = points.first.dx;
      double minY = points.first.dy;
      double maxY = points.first.dy;

      for (final p in points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }

      return Rect.fromLTRB(minX, minY, maxX, maxY);
    }

    final ra = boundsOf(pa);
    final rb = boundsOf(pb);

    final widthDiff = (ra.width - rb.width).abs() /
        ((ra.width + rb.width) / 2).clamp(1, 9999);
    final heightDiff = (ra.height - rb.height).abs() /
        ((ra.height + rb.height) / 2).clamp(1, 9999);

    final countDiff = (pa.length - pb.length).abs() /
        ((pa.length + pb.length) / 2).clamp(1, 9999);

    final diff = (widthDiff + heightDiff + countDiff) / 3;

    return (1.0 - diff).clamp(0.0, 1.0);
  }

  Future<Uint8List?> _signatureToPngBytes(
    List<Offset?>? points, {
    double width = 420,
    double height = 140,
  }) async {
    final validPoints = points?.whereType<Offset>().toList() ?? [];
    if (validPoints.isEmpty) return null;

    double minX = validPoints.first.dx;
    double maxX = validPoints.first.dx;
    double minY = validPoints.first.dy;
    double maxY = validPoints.first.dy;

    for (final p in validPoints) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    final contentWidth = (maxX - minX).abs() < 1 ? 1.0 : (maxX - minX);
    final contentHeight = (maxY - minY).abs() < 1 ? 1.0 : (maxY - minY);
    const padding = 18.0;

    final scaleX = (width - padding * 2) / contentWidth;
    final scaleY = (height - padding * 2) / contentHeight;
    final scale = min(scaleX, scaleY);

    final dx = (width - contentWidth * scale) / 2 - minX * scale;
    final dy = (height - contentHeight * scale) / 2 - minY * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points!.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];

      if (current != null && next != null) {
        final p1 = Offset(current.dx * scale + dx, current.dy * scale + dy);
        final p2 = Offset(next.dx * scale + dx, next.dy * scale + dy);
        canvas.drawLine(p1, p2, paint);
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData?.buffer.asUint8List();
  }

  List<Map<String, dynamic>> _signaturePointsToJson(List<Offset?>? points) {
    if (points == null || points.isEmpty) return const [];

    return points.map((point) {
      if (point == null) {
        return <String, dynamic>{
          'break': true,
        };
      }

      return <String, dynamic>{
        'x': point.dx,
        'y': point.dy,
      };
    }).toList();
  }

  List<Offset?> _signaturePointsFromJson(dynamic raw) {
    if (raw is! List) return <Offset?>[];

    final result = <Offset?>[];

    for (final item in raw) {
      if (item is! Map) continue;

      final map = Map<String, dynamic>.from(item);

      if (map['break'] == true) {
        result.add(null);
        continue;
      }

      final xRaw = map['x'];
      final yRaw = map['y'];

      final x = xRaw is num ? xRaw.toDouble() : double.tryParse('$xRaw');
      final y = yRaw is num ? yRaw.toDouble() : double.tryParse('$yRaw');

      if (x == null || y == null) continue;

      result.add(Offset(x, y));
    }

    return result;
  }

  void _toggleHealthChip({
    required Set<String> target,
    required String value,
  }) {
    setState(() {
      if (target.contains(value)) {
        target.remove(value);
      } else {
        target.add(value);
      }
      _syncHealthDetailController();
    });

    _handleDetailSignatureSensitiveChanged();
  }

  void _syncHealthDetailController() {
    final lines = <String>[];

    if (_healthPain && _selectedPainAreas.isNotEmpty) {
      lines.add('통증/불편 부위: ${_selectedPainAreas.join(', ')}');
    }

    if (_healthSurgery && _selectedSurgeryTypes.isNotEmpty) {
      lines.add('최근 수술 이력: ${_selectedSurgeryTypes.join(', ')}');
    }

    if (_healthAccident && _selectedAccidentTypes.isNotEmpty) {
      lines.add('최근 사고 이력: ${_selectedAccidentTypes.join(', ')}');
    }

    if (_healthPregnancy) {
      lines.add('임신/출산 관련 사항 있음');
    }

    if (_healthRehab) {
      lines.add('재활 중');
    }

    final nextText = lines.join('\n');

    _isApplyingProgrammaticChange = true;

    _healthDetailController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );

    _isApplyingProgrammaticChange = false;
  }

  Future<void> _handleComplete() async {
    final errors = <String>[];

    if (!_isDocumentSetupComplete) {
      errors.add('문서종류/작성방식을 확인해주세요.');
    }

    if (!_isBasicInfoComplete) {
      errors.add('기본정보를 모두 입력해주세요.');
    }

    if (!_isPaymentSectionComplete) {
      errors.add('개인레슨 결제정보를 확인해주세요.');
    }

    if (!_isDateRangeValid) {
      errors.add('계약일과 종료일 순서를 확인해주세요.');
    }

    if (errors.isNotEmpty) {
      setState(() {
        _showRequiredErrors = true;
      });

      await _scrollToFirstIncompleteSection();
      _showSnack(errors.first);
      return;
    }

    await _saveStep1Contract();
  }

  void _startNewVersion() {
    setState(() {
      _version += 1;

      _memberFinalSignaturePoints = null;
      _staffFinalSignaturePoints = null;
      _memberFinalSignedAt = null;
      _staffFinalSignedAt = null;
      _memberSignaturePoints = null;
      _staffSignaturePoints = null;
      _memberSignedAt = null;
      _staffSignedAt = null;
      _pdfSaved = false;
      _pdfSentToCustomer = false;
      _pdfSentToTrainer = false;
      _agreeSameContentSave = false;
      _agreeImportantNotice = false;
      _draftSaved = false;
    });
    _showSnack('새 버전 작성이 시작되었습니다. 기존 내용은 유지되고 서명만 초기화됩니다.');
  }

  void _showPreviewSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.86,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SingleChildScrollView(
                child: _buildLivePreviewSection(compact: true),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;

    AifcInteraction.toast(
      context: context,
      message: message,
      bottomOffset: 92,
      duration: const Duration(milliseconds: 1500),
    );
  }

  // -------------------- HELPERS --------------------

  void _closeContractPage() {
    if (!mounted) return;

    Navigator.of(context).pop(
      _shouldReturnSavedToCaller ? true : null,
    );
  }

  Future<bool> _handleContractWillPop() async {
    _closeContractPage();

    // 우리가 직접 pop 처리를 했으므로 기본 뒤로가기는 막습니다.
    return false;
  }

  String _generateInternalMemberId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final tail = List.generate(
      8,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    return 'mem_$tail';
  }

  String _newTemplateId(String prefix) {
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(9999)}';
  }

  String _formatDateTime(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  String _formatPercent(double value) {
    final rounded = double.parse(value.toStringAsFixed(1));
    if (rounded == rounded.roundToDouble()) {
      return '${rounded.toStringAsFixed(0)}%';
    }
    return '${rounded.toStringAsFixed(1)}%';
  }

  DateTime? _tryParseDate(String value) {
    try {
      final parts = value.split('-');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  int _parseInt(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  int _positiveInt(String text) {
    final v = _parseInt(text);
    return v < 0 ? 0 : v;
  }

  String _formatMoney(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < raw.length; i++) {
      final indexFromEnd = raw.length - i;
      buffer.write(raw[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  String _pickRandomSupportMessage() {
    return _supportMessages[Random().nextInt(_supportMessages.length)];
  }

  void _fillHybridClausesFromTemplate({bool force = false}) {
    if (force || _hybridLessonClauseController.text.trim().isEmpty) {
      _hybridLessonClauseController.text = _lessonClauseText;
    }
    if (force || _hybridReservationClauseController.text.trim().isEmpty) {
      _hybridReservationClauseController.text = _reservationClauseText;
    }
    if (force || _hybridHoldClauseController.text.trim().isEmpty) {
      _hybridHoldClauseController.text = _holdClauseText;
    }
    if (force || _hybridPenaltyClauseController.text.trim().isEmpty) {
      _hybridPenaltyClauseController.text = _penaltyClauseText;
    }
    if (force || _hybridTransferClauseController.text.trim().isEmpty) {
      _hybridTransferClauseController.text = _transferClauseText;
    }
  }

  void _clearHybridClauses() {
    _hybridLessonClauseController.clear();
    _hybridReservationClauseController.clear();
    _hybridHoldClauseController.clear();
    _hybridPenaltyClauseController.clear();
    _hybridTransferClauseController.clear();
  }

  String _resolvedClauseText({
    required bool enabled,
    required String generatedText,
    required TextEditingController hybridController,
  }) {
    if (!enabled) return '';

    if (_sourceMode == ContractSourceMode.customWrite) {
      return hybridController.text.trim();
    }

    return generatedText;
  }

  String _contractLessonTypeForMemberCard() {
    final candidates = <String>[
      _selectedProduct?.lessonType ?? '',
      _selectedProduct?.categoryName ?? '',
      _productNameController.text,
      _documentType,
    ];

    for (final raw in candidates) {
      final text = raw.trim();

      if (text.isEmpty) continue;

      if (text.contains('필라테스')) return '필라테스';
      if (text.contains('골프')) return '골프';
      if (text.contains('요가')) return '요가';
      if (text.contains('댄스')) return '댄스';
      if (text.contains('발레')) return '발레핏';
      if (text.toLowerCase().contains('pt') || text.contains('피티')) {
        return 'PT';
      }

      return text;
    }

    return '미입력';
  }

  Map<String, dynamic> _buildClientCardAutoRegisterPayload(
    Map<String, dynamic> existingMemberData,
  ) {
    final totalSessions = _usePaymentSection ? _sessionCountValue : 0;
    final remainSessions = totalSessions;
    const doneSessions = 0;

    final lessonType =
        totalSessions > 0 ? _contractLessonTypeForMemberCard() : '미입력';

    final birthText = _memberBirthController.text.trim();
    final contractDateText =
        _contractDateTextOrEmpty(_contractDateController.text);
    final endDateText = _isUnlimitedEndDate
        ? ''
        : _contractDateTextOrEmpty(_endDateController.text);

    final birthAt = _contractDateTextToTimestamp(birthText);
    final contractStartAt = _contractDateTextToTimestamp(contractDateText);
    final contractEndAt =
        _isUnlimitedEndDate ? null : _contractDateTextToTimestamp(endDateText);

    final existingMemberStatus = existingMemberData['memberStatus'];
    final existingMembershipGrade = existingMemberData['membershipGrade'];
    final existingFirstDate = existingMemberData['firstDate'];
    final existingRegisteredAt = existingMemberData['registeredAt'];

    final isNewMemberDoc = existingMemberData.isEmpty;

    return {
      'id': _internalMemberId,
      'memberId': _internalMemberId,

      // 기본정보
      'name': _memberNameController.text.trim(),
      'birth': birthAt ?? birthText,
      'birthDisplay': birthText,
      'phone': _normalizedMemberPhone,
      'phoneDisplay': _memberPhoneController.text.trim(),
      'email': _memberEmailController.text.trim(),
      'trainer': _trainerNameController.text.trim(),

      // 기존 회원카드 값이 없을 때만 기본값 보강
      if (!_hasExistingMemberValue(existingMemberStatus)) 'memberStatus': '활성',
      if (!_hasExistingMemberValue(existingMembershipGrade))
        'membershipGrade': 'GOLD',

      // 레슨 정보
      'lessonType': lessonType,
      'contractLessonType': lessonType,
      'lessonsNotRegistered': totalSessions <= 0,
      'totalSessions': totalSessions,
      'remainSessions': remainSessions,
      'remainingSessions': remainSessions,
      'doneSessions': doneSessions,

      'sessions': {
        'notRegistered': totalSessions <= 0,
        'total': totalSessions,
        'remain': remainSessions,
        'done': doneSessions,
        'noShowDeductedCount': 0,
        'noShowUndeductedCount': 0,
        'serviceSessionCount': 0,
      },

      // 회원권/계약 기간
      'membershipNotRegistered': false,
      'passStart': contractDateText,
      'passEnd': endDateText,
      'expireAt': contractEndAt,

      'membership': {
        'notRegistered': false,
        'startAt': contractStartAt,
        'endAt': contractEndAt,
        'contractDate': contractDateText,
        'unlimitedEndDate': _isUnlimitedEndDate,
        'reregisterCount': 0,
        'lastReregisterAt': null,
        'lastRegisteredAt': FieldValue.serverTimestamp(),
      },

      // 계약서 연결
      'contractId': _contractId,
      'contractNo': _contractNo,
      'contractSigned': true,
      'contractSignedAt': FieldValue.serverTimestamp(),

      'lessonSync': {
        'source': 'contract_auto_registration',
        'contractId': _contractId,
        'contractNo': _contractNo,
        'lessonType': lessonType,
        'productName': _productNameController.text.trim(),
        'sessionCount': totalSessions,
        'remainingSessions': remainSessions,
        'contractDate': contractDateText,
        'endDate': endDateText,
        'syncedAt': FieldValue.serverTimestamp(),
      },

      'lastContractSummary': {
        'contractId': _contractId,
        'contractNo': _contractNo,
        'productName': _productNameController.text.trim(),
        'sessionCount': totalSessions,
        'remainingSessions': remainSessions,
        'totalPrice': _priceValue,
        'paymentMethodLabel': _paymentMethodLabel,
        'contractDate': contractDateText,
        'endDate': endDateText,
        'finalSigned': true,
      },

      'clientCardAutoRegister': {
        'status': 'registered',
        'source': 'contract',
        'mode': isNewMemberDoc ? 'created' : 'merged',
        'contractId': _contractId,
        'contractNo': _contractNo,
        'registeredAt': FieldValue.serverTimestamp(),
      },

      if (!_hasExistingMemberValue(existingFirstDate) &&
          !_hasExistingMemberValue(existingRegisteredAt))
        'firstDate': FieldValue.serverTimestamp(),

      'recentReg': FieldValue.serverTimestamp(),
      'lastRegisteredAt': FieldValue.serverTimestamp(),

      if (isNewMemberDoc) 'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _markClientCardAutoRegisterSkipped() async {
    if (_contractId == null) return;

    final firestore = FirebaseFirestore.instance;
    final contractRef = firestore.collection('contracts').doc(_contractId);
    final memberRef = firestore.collection('members').doc(_internalMemberId);

    await firestore.runTransaction((transaction) async {
      transaction.set(
        contractRef,
        {
          'clientCardAutoRegister': {
            'status': 'skipped',
            'memberId': _internalMemberId,
            'skippedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      transaction.set(
        memberRef,
        {
          'clientCardAutoRegister': {
            'status': 'skipped',
            'source': 'contract',
            'contractId': _contractId,
            'contractNo': _contractNo,
            'skippedAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });
  }

  Future<void> _registerClientCardFromContract() async {
    if (_contractId == null) return;

    final firestore = FirebaseFirestore.instance;
    final memberRef = firestore.collection('members').doc(_internalMemberId);
    final contractRef = firestore.collection('contracts').doc(_contractId);

    var mergedExistingMember = false;

    await firestore.runTransaction((transaction) async {
      final memberSnap = await transaction.get(memberRef);
      final existingMemberData = memberSnap.data() ?? <String, dynamic>{};

      mergedExistingMember = memberSnap.exists && existingMemberData.isNotEmpty;

      final payload = _buildClientCardAutoRegisterPayload(existingMemberData);

      transaction.set(
        memberRef,
        payload,
        SetOptions(merge: true),
      );

      transaction.set(
        contractRef,
        {
          'memberId': _internalMemberId,
          'clientCardAutoRegister': {
            'status': 'registered',
            'memberId': _internalMemberId,
            'mode': mergedExistingMember ? 'merged' : 'created',
            'registeredAt': FieldValue.serverTimestamp(),
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    if (!mounted) return;

    final memberLabel = aifcPersonLabel(_memberNameController.text.trim());

    _showSnack(
      mergedExistingMember
          ? '$memberLabel 회원카드에 계약서 기준 레슨 정보와 계약번호를 보강했어요.'
          : '$memberLabel 회원카드를 등록해뒀어요.',
    );
  }

  Future<void> _offerClientCardAutoRegistrationIfNeeded() async {
    if (_clientCardAutoRegisterOfferShowing) return;
    if (_contractId == null) return;
    if (!_isFinalSignedCompleted) return;

    _clientCardAutoRegisterOfferShowing = true;

    try {
      final firestore = FirebaseFirestore.instance;
      final contractRef = firestore.collection('contracts').doc(_contractId);
      final contractSnap = await contractRef.get();

      if (!mounted) return;

      final contractData = contractSnap.data() ?? <String, dynamic>{};
      final autoRegister = contractData['clientCardAutoRegister'] is Map
          ? Map<String, dynamic>.from(
              contractData['clientCardAutoRegister'] as Map,
            )
          : <String, dynamic>{};

      final status = (autoRegister['status'] ?? '').toString().trim();

      if (status == 'registered' || status == 'skipped') {
        return;
      }

      final memberName = _memberNameController.text.trim().isEmpty
          ? '회원'
          : _memberNameController.text.trim();

      final confirmed = await AifcConfirmChatSheet.show(
        context: context,
        nickname: _normalizeContractNickname(_trainerNameController.text),
        title: '${aifcPersonLabel(memberName)} 회원카드도 등록해 놓을까요?',
        message: '계약서에 입력한 내용을 바탕으로 제가 회원카드를 미리 만들어둘게요.\n\n'
            '반영 내용\n'
            '· 회원명 / 연락처 / 생년월일 / 이메일\n'
            '· 레슨명 / 총 횟수 / 잔여 횟수\n'
            '· 계약일 / 종료일 / 계약번호\n\n'
            '개인정보동의는 레슨일지를 열 때 별도로 받을 수 있어요.',
        cancelText: '나중에',
        confirmText: '등록하기',
        userCancelText: '나중에 할게요',
        userConfirmText: '회원카드도 등록해주세요',
        cancelReplyText: '좋아요. 계약서만 저장해둘게요.',
        confirmReplyText: '확인했어요. 계약서 내용을 바탕으로 회원카드를 등록해 놓을게요.',
        danger: false,
      );

      if (!mounted) return;

      if (!confirmed) {
        await _markClientCardAutoRegisterSkipped();

        if (!mounted) return;
        _showSnack('계약서만 저장했어요.');
        return;
      }

      await _registerClientCardFromContract();
    } catch (e) {
      if (!mounted) return;
      _showSnack('회원카드 자동 등록을 완료하지 못했어요.');
    } finally {
      _clientCardAutoRegisterOfferShowing = false;
    }
  }

  bool _hasExistingMemberValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is num) return true;
    if (value is bool) return true;
    if (value is Timestamp) return true;
    if (value is Map) return value.isNotEmpty;
    if (value is List) return value.isNotEmpty;

    return true;
  }

  Timestamp? _contractDateTextToTimestamp(String value) {
    final date = _tryParseDate(value.trim());

    if (date == null) return null;

    return Timestamp.fromDate(
      DateTime(date.year, date.month, date.day),
    );
  }

  String _contractDateTextOrEmpty(String value) {
    final date = _tryParseDate(value.trim());

    if (date == null) return '';

    return _formatDate(date);
  }

  String _valueOrDash(String value) {
    final v = value.trim();
    return v.isEmpty ? '-' : v;
  }
}

class _DeliveryMethodChip extends StatelessWidget {
  const _DeliveryMethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor =
        selected ? const Color(0xFF059669) : const Color(0xFFE5E7EB);
    final bgColor =
        selected ? const Color(0xFFECFDF5) : const Color(0xFFF9FAFB);
    final textColor =
        selected ? const Color(0xFF047857) : const Color(0xFF374151);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: textColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StageTabButton extends StatelessWidget {
  const _StageTabButton({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.done,
    required this.onTap,
    this.muted = false,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final bool done;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = selected
        ? const Color(0xFF4F46E5)
        : muted
            ? const Color(0xFFF3F4F6)
            : const Color(0xFFF8FAFC);

    final Color titleColor = selected
        ? Colors.white
        : muted
            ? const Color(0xFF9CA3AF)
            : const Color(0xFF111827);

    final Color subtitleColor = selected
        ? Colors.white.withOpacity(0.78)
        : muted
            ? const Color(0xFF9CA3AF)
            : const Color(0xFF6B7280);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: enabled ? 1 : 0.62,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withOpacity(0.20),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                done
                    ? Icons.check_circle_rounded
                    : selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: selected
                    ? Colors.white
                    : done
                        ? const Color(0xFF059669)
                        : const Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: subtitleColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepItem {
  final String title;
  final bool done;

  _StepItem(this.title, this.done);
}

class _DocSection {
  final String title;
  final String body;

  _DocSection({
    required this.title,
    required this.body,
  });
}

class _LessonTemplateCategory {
  final String id;
  final String name;
  final List<_LessonTemplateItem> items;

  const _LessonTemplateCategory({
    required this.id,
    required this.name,
    required this.items,
  });

  _LessonTemplateCategory copyWith({
    String? id,
    String? name,
    List<_LessonTemplateItem>? items,
  }) {
    return _LessonTemplateCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      items: items ?? this.items,
    );
  }

  _LessonTemplateCategory clone() {
    return _LessonTemplateCategory(
      id: id,
      name: name,
      items: items.map((e) => e.clone()).toList(),
    );
  }
}

class _LessonTemplateItem {
  final String id;
  final String name;
  final int sessionCount;
  final int totalPrice;
  final bool vatIncluded;

  const _LessonTemplateItem({
    required this.id,
    required this.name,
    required this.sessionCount,
    required this.totalPrice,
    required this.vatIncluded,
  });

  _LessonTemplateItem copyWith({
    String? id,
    String? name,
    int? sessionCount,
    int? totalPrice,
    bool? vatIncluded,
  }) {
    return _LessonTemplateItem(
      id: id ?? this.id,
      name: name ?? this.name,
      sessionCount: sessionCount ?? this.sessionCount,
      totalPrice: totalPrice ?? this.totalPrice,
      vatIncluded: vatIncluded ?? this.vatIncluded,
    );
  }

  _LessonTemplateItem clone() {
    return _LessonTemplateItem(
      id: id,
      name: name,
      sessionCount: sessionCount,
      totalPrice: totalPrice,
      vatIncluded: vatIncluded,
    );
  }
}

class _LessonTemplateOption {
  final String categoryName;
  final _LessonTemplateItem item;

  const _LessonTemplateOption({
    required this.categoryName,
    required this.item,
  });
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: Colors.white.withOpacity(0.16),
            ),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _HeaderSummaryChip extends StatelessWidget {
  const _HeaderSummaryChip({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 15),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SignatureDialog extends StatefulWidget {
  final String title;
  final String guideName;

  const _SignatureDialog({
    required this.title,
    required this.guideName,
  });

  @override
  State<_SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<_SignatureDialog> {
  final ValueNotifier<List<Offset?>> _pointsNotifier =
      ValueNotifier<List<Offset?>>(<Offset?>[]);

  void _addPoint(Offset point) {
    final next = List<Offset?>.from(_pointsNotifier.value)..add(point);
    _pointsNotifier.value = next;
  }

  void _endStroke() {
    final next = List<Offset?>.from(_pointsNotifier.value)..add(null);
    _pointsNotifier.value = next;
  }

  void _clearAll() {
    _pointsNotifier.value = <Offset?>[];
  }

  @override
  void dispose() {
    _pointsNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<List<Offset?>>(
              valueListenable: _pointsNotifier,
              builder: (context, points, _) {
                final hasSignature = points.any((e) => e != null);

                return Column(
                  children: [
                    Container(
                      width: 320,
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD1D5DB)),
                        color: const Color(0xFFF9FAFB),
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) {
                          _addPoint(details.localPosition);
                        },
                        onPanEnd: (_) {
                          _endStroke();
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: RepaintBoundary(
                            child: Stack(
                              children: [
                                if (!hasSignature)
                                  Center(
                                    child: Text(
                                      widget.guideName.trim().isEmpty
                                          ? '서명'
                                          : widget.guideName.trim(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: const Color(0xFF111827)
                                            .withOpacity(0.12),
                                        fontSize: 42,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.8,
                                      ),
                                    ),
                                  ),
                                CustomPaint(
                                  painter: _SignaturePainter(points),
                                  child: const SizedBox.expand(),
                                ),
                                Positioned(
                                  left: 18,
                                  right: 18,
                                  bottom: 26,
                                  child: Container(
                                    height: 1,
                                    color: const Color(0xFFD1D5DB),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: hasSignature ? _clearAll : null,
                      child: const Text('전체 지우기'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        ValueListenableBuilder<List<Offset?>>(
          valueListenable: _pointsNotifier,
          builder: (context, points, _) {
            final hasSignature = points.any((e) => e != null);

            return FilledButton(
              onPressed: hasSignature
                  ? () => Navigator.pop(
                        context,
                        List<Offset?>.from(points),
                      )
                  : null,
              child: const Text('확인'),
            );
          },
        ),
      ],
    );
  }
}

class _SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  _SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];

      if (current != null && next != null) {
        canvas.drawLine(current, next, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _FittedSignaturePainter extends CustomPainter {
  final List<Offset?> points;

  _FittedSignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final validPoints = points.whereType<Offset>().toList();
    if (validPoints.isEmpty) return;

    double minX = validPoints.first.dx;
    double maxX = validPoints.first.dx;
    double minY = validPoints.first.dy;
    double maxY = validPoints.first.dy;

    for (final p in validPoints) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    final contentWidth = (maxX - minX).abs() < 1 ? 1.0 : (maxX - minX);
    final contentHeight = (maxY - minY).abs() < 1 ? 1.0 : (maxY - minY);
    const padding = 14.0;

    final scaleX = (size.width - padding * 2) / contentWidth;
    final scaleY = (size.height - padding * 2) / contentHeight;
    final scale = min(scaleX, scaleY);

    final dx = (size.width - contentWidth * scale) / 2 - minX * scale;
    final dy = (size.height - contentHeight * scale) / 2 - minY * scale;

    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];

      if (current != null && next != null) {
        final p1 = Offset(current.dx * scale + dx, current.dy * scale + dy);
        final p2 = Offset(next.dx * scale + dx, next.dy * scale + dy);
        canvas.drawLine(p1, p2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FittedSignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _PaymentMethodChip extends StatelessWidget {
  const _PaymentMethodChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color borderColor =
        selected ? const Color(0xFF4F46E5) : const Color(0xFFE5E7EB);
    final Color bgColor =
        selected ? const Color(0xFFEEF2FF) : const Color(0xFFF9FAFB);
    final Color textColor =
        selected ? const Color(0xFF4F46E5) : const Color(0xFF374151);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 19,
                color: textColor,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThousandsInputFormatter extends TextInputFormatter {
  const _ThousandsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final buffer = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      final indexFromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }

    final text = buffer.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _HeaderCircleIconButton extends StatelessWidget {
  const _HeaderCircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.20),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _PhoneInputFormatter extends TextInputFormatter {
  const _PhoneInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    String text;

    if (digits.length <= 3) {
      text = digits;
    } else if (digits.length <= 6) {
      text = '${digits.substring(0, 3)}-${digits.substring(3)}';
    } else if (digits.length <= 10) {
      text =
          '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    } else {
      final cut = digits.substring(0, 11);
      text =
          '${cut.substring(0, 3)}-${cut.substring(3, 7)}-${cut.substring(7)}';
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _BirthDateInputFormatter extends TextInputFormatter {
  const _BirthDateInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
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

class _LessonProductPickerSheet extends StatelessWidget {
  const _LessonProductPickerSheet({
    required this.products,
  });

  final List<ProductModel> products;

  String _formatMoney(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();

    for (int i = 0; i < raw.length; i++) {
      final indexFromEnd = raw.length - i;
      buffer.write(raw[i]);

      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<ProductModel>>{};

    for (final product in products) {
      final category = product.categoryName.trim().isEmpty
          ? '기타 레슨'
          : product.categoryName.trim();

      grouped.putIfAbsent(category, () => <ProductModel>[]);
      grouped[category]!.add(product);
    }

    final categoryNames = grouped.keys.toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.sell_outlined,
                    color: Color(0xFF4F46E5),
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '등록된 레슨 상품 불러오기',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ...categoryNames.map((categoryName) {
                final items = grouped[categoryName] ?? <ProductModel>[];

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        categoryName,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...items.map((product) {
                        return InkWell(
                          onTap: () => Navigator.of(context).pop(product),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5)
                                        .withOpacity(0.09),
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: const Icon(
                                    Icons.fitness_center_rounded,
                                    color: Color(0xFF4F46E5),
                                    size: 19,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: const TextStyle(
                                          color: Color(0xFF111827),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${product.sessionCount}회 · 회당 ${_formatMoney(product.unitPrice)}원 · 총 ${_formatMoney(product.totalPrice)}원 · ${product.vatIncluded ? 'VAT 포함' : 'VAT 별도'}',
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w600,
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
                      }),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}
