import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

enum _ContractMoreAction {
  sourceMode,
  managePricePresets,
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

  const ContractPage({
    super.key,
    required this.memberId,
    required this.memberName,
    required this.trainerName,
  });

  @override
  State<ContractPage> createState() => _ContractPageState();
}

class _ContractPageState extends State<ContractPage>
    with SingleTickerProviderStateMixin {
  late String _internalMemberId;

  late ContractSourceMode _sourceMode;
  late String _documentType;

  int _version = 1;
  bool _headerExpanded = false;
  bool _draftSaved = false;

  late final AnimationController _livePulseController;
  late final Animation<double> _livePulseAnimation;

  OverlayEntry? _tipOverlayEntry;
  Timer? _tipTimer;

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

  // 기본 정보
  late final TextEditingController _memberNameController;
  final TextEditingController _memberPhoneController = TextEditingController();
  final TextEditingController _centerNameController =
  TextEditingController(text: 'MORE THAN FITNESS');
  late final TextEditingController _trainerNameController;

  // 결제 정보
  static const int _maxStoredPdfCount = 5;
  final List<String> _storedPdfNames = <String>[];

  final TextEditingController _productNameController =
  TextEditingController(text: 'PT레슨 10회');
  final TextEditingController _unitPriceController =
  TextEditingController(text: '100000');
  final TextEditingController _sessionCountController =
  TextEditingController(text: '10');
  final TextEditingController _priceController =
  TextEditingController(text: '1100000');
  final TextEditingController _contractDateController =
  TextEditingController();
  final TextEditingController _endDateController =
  TextEditingController();

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
  final TextEditingController _suspensionRuleController =
  TextEditingController(
    text: '기관에서 인정하는 사항에 따라 이용정지 운영의 예외를 둘 수 있습니다.',
  );

  final TextEditingController _penaltyPercentController =
  TextEditingController(text: '10');
  bool _noRefundProduct = false;

  bool _transferAllowed = false;
  final TextEditingController _transferRuleController =
  TextEditingController(
    text: '센터 승인 및 명의 확인 후 양도 가능합니다.',
  );

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

  final TextEditingController _healthDetailController =
  TextEditingController();

  // 최종 확인
  bool _agreeSameContentSave = false;
  bool _agreeImportantNotice = false;

  // 더미 상태
  bool _pdfSaved = false;
  bool _pdfSentToCustomer = false;
  bool _pdfSentToTrainer = false;

  // 전자서명
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
  bool get _isFormLocked => _isSignedCompleted;

  @override
  void initState() {
    super.initState();

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
    _trainerNameController = TextEditingController(text: widget.trainerName);

    final now = DateTime.now();
    final end = DateTime(now.year, now.month + 3, now.day);

    _contractDateController.text = _formatDate(now);
    _endDateController.text = _formatDate(end);

    _supportMessage = _pickRandomSupportMessage();
    _fillHybridClausesFromTemplate(force: true);

    _livePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

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
      _memberPhoneController,
      _centerNameController,
      _trainerNameController,
      _productNameController,
      _unitPriceController,
      _sessionCountController,
      _priceController,
      _contractDateController,
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

    for (final c in controllers) {
      c.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
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
    _memberPhoneController.dispose();
    _centerNameController.dispose();
    _trainerNameController.dispose();

    _productNameController.dispose();
    _unitPriceController.dispose();
    _sessionCountController.dispose();
    _priceController.dispose();
    _contractDateController.dispose();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double width =
        isTablet ? kContractMaxContentWidth : constraints.maxWidth;

        return Scaffold(
          backgroundColor: kContractBgColor,
          body: SafeArea(
            bottom: false,
            child: Center(
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
        );
      },
    );
  }

  // -------------------- HEADER --------------------

  Widget _buildHeader() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      padding: const EdgeInsets.only(
        top: 14,
        left: 16,
        right: 16,
        bottom: 18,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF4F46E5),
            Color(0xFF9333EA),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(_headerExpanded ? 18 : 32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(999),
                    child: const SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 110),
                    child: Text(
                      '개인레슨 계약서',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeaderActionButton(
                        icon: Icons.remove_red_eye_outlined,
                        tooltip: '미리보기',
                        onTap: _showPreviewSheet,
                      ),
                      const SizedBox(width: 6),
                      PopupMenuButton<_ContractMoreAction>(
                        onSelected: _handleMoreMenuAction,
                        color: Colors.white,
                        tooltip: '더보기',
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: EdgeInsets.zero,
                        icon: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.16),
                            ),
                          ),
                          child: const Icon(
                            Icons.more_horiz_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: _ContractMoreAction.sourceMode,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.tune_rounded,
                                  size: 18,
                                  color: Color(0xFF4B5563),
                                ),
                                SizedBox(width: 10),
                                Text('작성방식 선택'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: _ContractMoreAction.managePricePresets,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.price_change_outlined,
                                  size: 18,
                                  color: Color(0xFF4B5563),
                                ),
                                SizedBox(width: 10),
                                Text('레슨 금액 설정'),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          PopupMenuItem(
                            value: _ContractMoreAction.tempSave,
                            child: Row(
                              children: [
                                Icon(
                                  _draftSaved
                                      ? Icons.bookmark_added_rounded
                                      : Icons.bookmark_border_rounded,
                                  size: 18,
                                  color: const Color(0xFF4B5563),
                                ),
                                const SizedBox(width: 10),
                                Text(_draftSaved ? '임시저장됨' : '임시저장'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: _ContractMoreAction.savePdf,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.picture_as_pdf_outlined,
                                  size: 18,
                                  color: Color(0xFF4B5563),
                                ),
                                SizedBox(width: 10),
                                Text('PDF 저장'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: _ContractMoreAction.sendCustomer,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.send_rounded,
                                  size: 18,
                                  color: Color(0xFF4B5563),
                                ),
                                SizedBox(width: 10),
                                Text('고객 전송'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: _ContractMoreAction.sendTrainer,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.forward_to_inbox_rounded,
                                  size: 18,
                                  color: Color(0xFF4B5563),
                                ),
                                SizedBox(width: 10),
                                Text('강사 전송'),
                              ],
                            ),
                          ),
                          if (_isSignedCompleted)
                            const PopupMenuItem(
                              value: _ContractMoreAction.newVersion,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.copy_outlined,
                                    size: 18,
                                    color: Color(0xFF4B5563),
                                  ),
                                  SizedBox(width: 10),
                                  Text('새 버전 작성'),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              _supportMessages.contains(_supportMessage)
                  ? _supportMessage
                  : '어려운 결정과 다짐을 지지하고 응원합니다.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontSize: 11.6,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _HeaderSelectableCard(
                  label: '문서종류',
                  value: _documentType,
                  icon: Icons.article_outlined,
                  onTap: _isFormLocked ? null : _showDocumentTypeSelector,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderSelectableCard(
                  label: '작성방식',
                  value: _sourceModeLabel,
                  icon: Icons.tune_rounded,
                  onTap: _isFormLocked ? null : _showSourceModeSelector,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HeaderProgressCard(
                  currentStepTitle: _currentStepTitle,
                  completedText:
                  '$_completedStepCount/${_buildSteps().length}',
                  progressValue:
                  _completedStepCount / _buildSteps().length.toDouble(),
                  pulseAnimation: _livePulseAnimation,
                  nextHint: _nextStepHint,
                  isCompleted: _buildSteps().every((e) => e.done),
                ),
              ),
            ],
          ),
          Transform.translate(
            offset: const Offset(0, 4),
            child: Center(
              child: InkWell(
                onTap: () {
                  setState(() {
                    _headerExpanded = !_headerExpanded;
                  });
                },
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 2,
                  ),
                  child: Icon(
                    _headerExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white.withOpacity(0.86),
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _headerExpanded
                ? Padding(
              key: const ValueKey('contract_header_summary_open'),
              padding: const EdgeInsets.only(top: 10),
              child: _buildHeaderSummaryBox(),
            )
                : const SizedBox.shrink(
              key: ValueKey('contract_header_summary_closed'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSummaryBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '현재 계약 요약',
            style: TextStyle(
              color: Colors.white.withOpacity(0.96),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeaderSummaryChip(
                icon: Icons.person_outline,
                text: _valueOrDash(_memberNameController.text),
              ),
              _HeaderSummaryChip(
                icon: Icons.fitness_center_rounded,
                text: _valueOrDash(_productNameController.text),
              ),
              _HeaderSummaryChip(
                icon: Icons.payments_outlined,
                text: _usePaymentSection ? '${_formatMoney(_priceValue)}원' : '결제정보 미사용',
              ),
              if (_paymentDifferenceShortLabel.isNotEmpty)
                _HeaderSummaryChip(
                  icon: Icons.local_offer_outlined,
                  text: _paymentDifferenceShortLabel,
                ),
              _HeaderSummaryChip(
                icon: Icons.calendar_month_outlined,
                text: _dateSummaryLabel,
              ),
              _HeaderSummaryChip(
                icon: Icons.bookmark_border_rounded,
                text: _draftSaved ? '임시저장됨' : '임시저장 전',
              ),
            ],
          ),
        ],
      ),
    );
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
          KeyedSubtree(
            key: _signatureSectionKey,
            child: _buildSignatureSection(),
          ),
          const SizedBox(height: 18),
          _buildBottomActions(),
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
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _memberPhoneController,
            label: '회원 연락처',
            hint: '01012345678',
            keyboardType: TextInputType.phone,
            enabled: !_isFormLocked,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _centerNameController,
            label: '센터명 (선택)',
            enabled: !_isFormLocked,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _trainerNameController,
            label: '담당 강사',
            enabled: !_isFormLocked,
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
                _buildLessonProductAutocompleteField(),
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
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
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
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Checkbox(
                            value: _vatIncluded,
                            onChanged: _isFormLocked
                                ? null
                                : (v) {
                              setState(() {
                                _vatIncluded = v ?? false;
                                _ContractUiMemory.vatIncluded = _vatIncluded;
                              });
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
                  hint: '770000',
                  keyboardType: TextInputType.number,
                  enabled: !_isFormLocked,
                  prefixText: '₩ ',
                  helperText: _paymentDifferenceShortLabel.isEmpty
                      ? null
                      : _paymentDifferenceShortLabel,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                ),
                const SizedBox(height: 8),
                _buildVatCard(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildDateField(
                        controller: _contractDateController,
                        label: '계약일',
                        enabled: !_isFormLocked,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildDateField(
                        controller: _endDateController,
                        label: '종료일',
                        enabled: !_isFormLocked && !_isUnlimitedEndDate,
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
                    setState(() {
                      _isUnlimitedEndDate = v ?? false;
                      _ContractUiMemory.unlimitedEndDate =
                          _isUnlimitedEndDate;
                    });
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

  // -------------------- SECTION : 개인레슨 결제정보 --------------------

  Widget _buildLessonProductAutocompleteField() {
    return RawAutocomplete<_LessonTemplateOption>(
      textEditingController: _productNameController,
      focusNode: _productNameFocusNode,
      displayStringForOption: (option) => option.item.name,
      optionsBuilder: (textEditingValue) {
        if (_isFormLocked) {
          return const Iterable<_LessonTemplateOption>.empty();
        }

        final options = _allLessonTemplateOptions;
        final query = textEditingValue.text.trim().toLowerCase();

        if (options.isEmpty) {
          return const Iterable<_LessonTemplateOption>.empty();
        }

        if (query.isEmpty) {
          return options.take(8);
        }

        return options.where((option) {
          final searchable = [
            option.categoryName,
            option.item.name,
            '${option.item.sessionCount}',
            _formatMoney(option.item.totalPrice),
          ].join(' ').toLowerCase();

          return searchable.contains(query);
        }).take(8);
      },
      onSelected: (option) {
        _applyLessonTemplate(option.item);
        _productNameFocusNode.unfocus();
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        return GestureDetector(
          onLongPress: _isFormLocked ? null : _showLessonPriceManager,
          child: TextField(
            controller: textEditingController,
            focusNode: focusNode,
            enabled: !_isFormLocked,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: '상품명',
              hintText: '예: 재활PT 10회',
              filled: true,
              fillColor:
              !_isFormLocked ? const Color(0xFFF9FAFB) : const Color(0xFFF3F4F6),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
              ),
            ),
          ),
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
                maxHeight: 260,
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
                    final option = list[index];
                    final item = option.item;

                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${option.categoryName} · ${item.sessionCount}회 · ${_formatMoney(item.totalPrice)}원${item.vatIncluded ? ' · VAT 포함' : ' · VAT 별도'}',
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

  Widget _buildPricePresetArea() {
    final categories = _ContractUiMemory.lessonTemplateCategories
        .where((e) => e.name.trim().isNotEmpty && e.items.isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
                  '레슨 금액 불러오기',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _isFormLocked ? null : _showLessonPriceManager,
                icon: const Icon(Icons.price_change_outlined, size: 16),
                label: const Text('레슨 금액 설정'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (categories.isEmpty)
            const Text(
              '저장된 레슨 금액이 없습니다. 레슨 금액 설정에서 먼저 추가해주세요.',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF6B7280),
                height: 1.45,
              ),
            )
          else
            Column(
              children: categories.map((category) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: category.items.map((item) {
                          final unitPrice = item.sessionCount > 0
                              ? (item.totalPrice / item.sessionCount).round()
                              : 0;

                          return ActionChip(
                            avatar: const Icon(Icons.bolt_rounded, size: 16),
                            label: Text(
                              '${item.name} · ${_formatMoney(item.totalPrice)}원${item.vatIncluded ? ' · VAT 포함' : ''}',
                            ),
                            onPressed: _isFormLocked
                                ? null
                                : () => _applyLessonTemplate(item),
                            tooltip:
                            '회당 ${_formatMoney(unitPrice)}원 / ${item.sessionCount}회',
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }).toList(),
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
                  setState(() {
                    _priceController.text = _calculatedTotalPrice.toString();
                  });
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
      title: _sourceMode == ContractSourceMode.uploadPdf
          ? '추가 확인 조항'
          : '계약 조건 확인',
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
                      : (v) =>
                      setState(() => _agreeLessonClause = v ?? false),
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
                      : (v) =>
                      setState(() => _agreePenaltyClause = v ?? false),
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
                      : (v) =>
                      setState(() => _agreePenaltyClause = v ?? false),
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
                      : (v) =>
                      setState(() => _agreeTransferClause = v ?? false),
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
                      : (v) =>
                      setState(() => _agreeTransferClause = v ?? false),
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
                            border:
                            Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.picture_as_pdf_outlined, size: 18),
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

  Widget _buildFinalConfirmSection() {
    return _buildSectionCard(
      title: '최종 확인',
      icon: Icons.fact_check_outlined,
      subtitle: '저장/전송 시 현재 화면 문구와 동일하게 처리된다는 점을 다시 확인합니다.',
      child: Column(
        children: [
          _buildNoticeBox(
            title: '동일 문구 저장 안내',
            text:
            '현재 화면에서 고객이 확인한 문구와 동일한 내용으로 저장·전송되도록 설계되었습니다.',
            background: const Color(0xFFF3F4F6),
            border: const Color(0xFFD1D5DB),
            textColor: const Color(0xFF374151),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _agreeImportantNotice,
            onChanged: _isFormLocked
                ? null
                : (v) => setState(() => _agreeImportantNotice = v ?? false),
            contentPadding: EdgeInsets.zero,
            title: const Text('계약 조건 확인 항목을 모두 읽고 확인했습니다'),
          ),
          CheckboxListTile(
            value: _agreeSameContentSave,
            onChanged: _isFormLocked
                ? null
                : (v) => setState(() => _agreeSameContentSave = v ?? false),
            contentPadding: EdgeInsets.zero,
            title: const Text('현재 화면 문구 그대로 저장·전송된다는 점을 확인했습니다'),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatusChip(
                label: _agreeImportantNotice ? '중요사항 확인 완료' : '중요사항 확인 필요',
                done: _agreeImportantNotice,
              ),
              _buildStatusChip(
                label: _agreeSameContentSave ? '동일문구 저장 확인' : '동일문구 저장 확인 필요',
                done: _agreeSameContentSave,
              ),
              _buildStatusChip(
                label: _pdfSaved ? 'PDF 저장 이력 있음' : 'PDF 저장 전',
                done: _pdfSaved,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // -------------------- SECTION : 전자서명 --------------------

  Widget _buildSignatureSection() {
    return _buildSectionCard(
      title: '전자서명',
      icon: Icons.draw_outlined,
      subtitle: '작성 완료 후 수정이 불가함으로 마지막 확인 단계로 보시면 됩니다.',
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
                        '서명 전 확인',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF312E81),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '회원은 환불·중도해지·예약·레슨지연·홀드·양도 기준을 확인하고 전자서명합니다.',
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
            title: '회원 서명',
            name: _memberNameController.text.trim().isEmpty
                ? '회원명 미입력'
                : _memberNameController.text.trim(),
            points: _memberSignaturePoints,
            signedAt: _memberSignedAt,
            onTapSign: () => _openSignaturePad(isMember: true),
            onClear: () {
              if (_isFormLocked) {
                _showSnack('서명 완료 후 수정은 새 버전 작성으로 진행해주세요.');
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
            title: '강사 서명',
            name: _trainerNameController.text.trim().isEmpty
                ? '강사 미입력'
                : _trainerNameController.text.trim(),
            points: _staffSignaturePoints,
            signedAt: _staffSignedAt,
            onTapSign: () => _openSignaturePad(isMember: false),
            onClear: () {
              if (_isFormLocked) {
                _showSnack('서명 완료 후 수정은 새 버전 작성으로 진행해주세요.');
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
    const Icon(Icons.description_outlined, color: Color(0xFF111827)),
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
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
    Center(
    child: Text(
    _documentType,
    textAlign: TextAlign.center,
    style: TextStyle(
    fontSize: compact ? 20 : 22,
    fontWeight: FontWeight.w900,
    color: const Color(0xFF111827),
    ),
    ),
    ),
    const SizedBox(height: 4),
    const Center(
    child: Text(
    'Personal Training Contract',
    style: TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    color: Color(0xFF4B5563),
    ),
    ),
    ),
    const SizedBox(height: 16),
    _buildFormalPreviewInfoTable(),
    const SizedBox(height: 14),
    _buildFormalPreviewRuleBox(
    title: '이용 규정',
    items: _contractHistoryItems.isEmpty
    ? const ['선택된 계약 조건이 없습니다.']
        : _contractHistoryItems,
    ),
    const SizedBox(height: 12),
    _buildFormalPreviewRuleBox(
    title: '건강상태 알림',
    items: [
    '건강 상태: $_healthSummary',
    if (_healthDetailController.text.trim().isNotEmpty)
    '상세 고지: ${_healthDetailController.text.trim()}',
    ],
    ),
    const SizedBox(height: 12),
    _buildFormalPreviewRuleBox(
    title: '확인 문구',
    items: [
    _supportMessage,
    '중요사항 확인: ${_agreeImportantNotice ? '완료' : '미완료'}',
    '동일문구 저장 확인: ${_agreeSameContentSave ? '완료' : '미완료'}',
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
          '연락처',
          _valueOrDash(_memberPhoneController.text),
        ),
        _buildFormalPreviewTableRow(
          '레슨명',
          _usePaymentSection ? _valueOrDash(_productNameController.text) : '미기재',
          '계약일',
          _valueOrDash(_contractDateController.text),
        ),
        _buildFormalPreviewTableRow(
          '횟수',
          _usePaymentSection ? '${_sessionCountValue}회' : '미기재',
          '결제금액',
          _usePaymentSection ? '${_formatMoney(_priceValue)}원' : '미기재',
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

  Widget _buildFormalPreviewSignatureArea() {
    return Row(
      children: [
        Expanded(
          child: _buildFormalPreviewSigner(
            '회원 서명',
            _memberNameController.text.trim(),
            _memberSignaturePoints,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildFormalPreviewSigner(
            '강사 서명',
            _trainerNameController.text.trim(),
            _staffSignaturePoints,
          ),
        ),
      ],
    );
  }

  Widget _buildFormalPreviewSigner(
      String label,
      String name,
      List<Offset?>? points,
      ) {
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
            painter: _FittedSignaturePainter(points!),
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

  Widget _buildBottomActions() {
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
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: const Text(
                '미리보기와 저장/전송은 상단 눈 아이콘과 더보기(...)에서 진행합니다.',
                style: TextStyle(
                  fontSize: 12.5,
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
                    onPressed: _handleTempSave,
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
                    label: Text(_draftSaved ? '임시저장됨' : '임시저장'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _handleComplete,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: Text(_isSignedCompleted ? '작성 완료됨' : '작성 완료'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

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
  }) {
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
        helperText: helperText,
        prefixText: prefixText,
        suffixText: suffixText,
        filled: true,
        fillColor: enabled ? const Color(0xFFF9FAFB) : const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
      ),
    );
  }

  Widget _buildDateField({
    required TextEditingController controller,
    required String label,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      readOnly: true,
      enabled: enabled,
      onTap: enabled ? () => _pickDate(controller) : null,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        filled: true,
        fillColor: enabled ? const Color(0xFFF9FAFB) : const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
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

  return Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
  Text(
  '$title · $name',
  style: const TextStyle(
  fontWeight: FontWeight.w700,
  color: Color(0xFF111827),
  ),
  ),
  const SizedBox(height: 10),
  Container(
  width: double.infinity,
  height: 140,
  decoration: BoxDecoration(
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: const Color(0xFFD1D5DB)),
  color: const Color(0xFFF9FAFB),
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
        : const Center(
      child: Text(
        '아직 서명이 없습니다',
        style: TextStyle(color: Color(0xFF9CA3AF)),
      ),
    ),
  ),
  if (signedAt != null)
  Positioned(
  top: 8,
  right: 8,
  child: Container(
  padding:
  const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
  decoration: BoxDecoration(
  color: Colors.white.withOpacity(0.82),
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
  ],
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
  onPressed: hasSignature ? onClear : null,
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
      _StepItem('계약조건', _isContractConditionsComplete),
      _StepItem('건강고지', _isHealthSectionComplete),
      _StepItem('최종확인', _isFinalConfirmComplete),
      _StepItem('회원서명', _memberSigned),
      _StepItem('강사서명', _staffSigned),
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
  if (_trainerNameController.text.trim().isEmpty) return false;
  return true;
  }

  bool get _isPaymentSectionComplete {
    if (!_usePaymentSection) return true;

    if (_productNameController.text.trim().isEmpty) return false;
    if (_unitPriceValue <= 0) return false;
    if (_sessionCountValue <= 0) return false;
    if (_priceValue <= 0) return false;
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

  bool get _isReadyForPdfOrCustomer {
    return _buildSteps().every((e) => e.done);
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
        body:
        '문서 종류: $_documentType\n계약 버전: v$_version\n작성 방식: $_sourceModeLabel',
      ),
      _DocSection(
        title: '2. 기본 정보',
        body:
        '회원명: ${_valueOrDash(_memberNameController.text)}\n'
            '회원 연락처: ${_valueOrDash(_memberPhoneController.text)}\n'
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
        : _storedPdfNames.asMap().entries
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
          body:
          '건강 상태: $_healthSummary'
              '${_healthDetailController.text.trim().isNotEmpty ? '\n상세 고지: ${_healthDetailController.text.trim()}' : ''}\n'
              '건강상태알림 숙지: ${_agreeHealthNotice ? '완료' : '미완료'}',
        ),
      );
      sections.add(
        _DocSection(
          title: '7. 최종 확인',
          body:
          '중요사항 확인: ${_agreeImportantNotice ? '완료' : '미완료'}\n'
              '동일문구 저장 확인: ${_agreeSameContentSave ? '완료' : '미완료'}\n'
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
        body:
        '건강 상태: $_healthSummary'
            '${_healthDetailController.text.trim().isNotEmpty ? '\n상세 고지: ${_healthDetailController.text.trim()}' : ''}\n'
            '건강상태알림 숙지: ${_agreeHealthNotice ? '완료' : '미완료'}',
      ),
    );
    sections.add(
      _DocSection(
        title: '6. 최종 확인',
        body:
        '중요사항 확인: ${_agreeImportantNotice ? '완료' : '미완료'}\n'
            '동일문구 저장 확인: ${_agreeSameContentSave ? '완료' : '미완료'}\n'
            '현재 화면에서 고객이 확인한 문구와 동일한 내용으로 저장·전송됩니다.',
      ),
    );
    sections.add(
      _DocSection(
        title: '7. 전자서명',
        body:
        '회원 서명: ${_memberSigned ? '완료${_memberSignedAt != null ? ' (${_formatDateTime(_memberSignedAt!)})' : ''}' : '미완료'}\n'
            '강사 서명: ${_staffSigned ? '완료${_staffSignedAt != null ? ' (${_formatDateTime(_staffSignedAt!)})' : ''}' : '미완료'}',
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
      '본 계약서는 앱 화면에서 확인한 문구와 동일한 내용으로 저장·전송되는 구조를 기준으로 작성됩니다.',
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
      messages.add('회원 서명이 필요합니다.');
    }
    if (!_staffSigned) {
      messages.add('강사 서명이 필요합니다.');
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

  void _handleMoreMenuAction(_ContractMoreAction action) {
  if (_isFormLocked && action == _ContractMoreAction.sourceMode) {
  _showSnack('서명 완료 후 수정은 새 버전 작성으로 진행해주세요.');
  return;
  }

  switch (action) {
  case _ContractMoreAction.sourceMode:
  _showSourceModeSelector();
  break;
  case _ContractMoreAction.managePricePresets:
  _showPricePresetManager();
  break;
  case _ContractMoreAction.tempSave:
  _handleTempSave();
  break;
  case _ContractMoreAction.savePdf:
  _trySavePdf();
  break;
  case _ContractMoreAction.sendCustomer:
  _trySendCustomer();
  break;
  case _ContractMoreAction.sendTrainer:
  _showTrainerTransferComingSoon();
  break;
  case _ContractMoreAction.newVersion:
  _startNewVersion();
  break;
  }
  }

  void _handleTempSave() {
  setState(() {
  _draftSaved = true;
  });
  _showSnack('임시저장은 현재 더미이며, 지금 화면 상태 기준으로 기억됩니다.');
  }

  Future<void> _showDocumentTypeSelector() async {
  if (_isFormLocked) {
  _showSnack('서명 완료 후 수정은 새 버전 작성으로 진행해주세요.');
  return;
  }

  final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        final items = const [
          'PT수업 계약서',
          '필라테스 개인레슨 계약서',
          '골프 개인레슨 계약서',
          '자유이용권 계약서',
        ];

        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 10),
                child: Text(
                  '문서종류 선택',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ...items.map(
                    (item) => ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Icon(
                    item == _documentType
                        ? Icons.check_circle_rounded
                        : Icons.article_outlined,
                    color: item == _documentType
                        ? const Color(0xFF7C3AED)
                        : const Color(0xFF64748B),
                  ),
                  title: Text(item),
                  onTap: () => Navigator.pop(context, item),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    setState(() {
      _documentType = result;
      _ContractUiMemory.lastDocumentType = result;
    });
  }

  Future<void> _showSourceModeSelector() async {
    if (_isFormLocked) {
      _showSnack('서명 완료 후 수정은 새 버전 작성으로 진행해주세요.');
      return;
    }

    final result = await showModalBottomSheet<ContractSourceMode>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(8, 4, 8, 10),
                child: Text(
                  '작성방식 선택',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _buildSourceModeTile(
                mode: ContractSourceMode.basicTemplate,
                title: '기본양식서류',
                subtitle: '기본적인 계약 조건을 수정 후 계약서를 작성합니다.',
              ),
              _buildSourceModeTile(
                mode: ContractSourceMode.customWrite,
                title: '내용작성',
                subtitle: '기본적인 프레임워크만 가져와 계약내용을 직접 작성합니다.',
              ),
              _buildSourceModeTile(
                mode: ContractSourceMode.uploadPdf,
                title: '기존계약서 PDF 보관',
                subtitle: '작성이 완료된 계약서를 PDF로 보관하고 회원님께 송신합니다.',
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    setState(() {
      _sourceMode = result;
      _ContractUiMemory.lastSourceMode = result;

      if (result == ContractSourceMode.customWrite) {
        _fillHybridClausesFromTemplate(force: false);
      }
    });
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
                                            expandedCategoryIds.remove(category.id);
                                          } else {
                                            expandedCategoryIds.add(category.id);
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
                                              padding: const EdgeInsets.symmetric(
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
                                                    tempCategories
                                                        .removeAt(categoryIndex);
                                                  });
                                                },
                                                icon: const Icon(
                                                  Icons.delete_outline_rounded,
                                                ),
                                                tooltip: '카테고리 삭제',
                                              ),
                                            Icon(
                                              isExpanded
                                                  ? Icons.keyboard_arrow_up_rounded
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
                                        padding: const EdgeInsets.fromLTRB(
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
                                                const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius:
                                                  BorderRadius.circular(
                                                      16),
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
                                                            onPressed: () {
                                                              setSheetState(
                                                                      () {
                                                                    final nextItems = [
                                                                      ...category
                                                                          .items
                                                                    ]
                                                                      ..removeAt(
                                                                          itemIndex);

                                                                    tempCategories[
                                                                    categoryIndex] =
                                                                        tempCategories[categoryIndex]
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
                                                        final nextItems = [
                                                          ...tempCategories[
                                                          categoryIndex]
                                                              .items
                                                        ];
                                                        nextItems[itemIndex] =
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
                                                              items: nextItems,
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
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        SizedBox(
                                                          width: 76,
                                                          child: TextFormField(
                                                            key: ValueKey('item_count_${item.id}'),
                                                            initialValue: item.sessionCount.toString(),
                                                            keyboardType: TextInputType.number,
                                                            inputFormatters: [
                                                              FilteringTextInputFormatter.digitsOnly,
                                                            ],
                                                            onChanged: (value) {
                                                              final nextItems = [...tempCategories[categoryIndex].items];
                                                              nextItems[itemIndex] = nextItems[itemIndex].copyWith(
                                                                sessionCount: _parseInt(value),
                                                              );
                                                              tempCategories[categoryIndex] =
                                                                  tempCategories[categoryIndex].copyWith(items: nextItems);
                                                            },
                                                            decoration: InputDecoration(
                                                              labelText: '횟수',
                                                              suffixText: '회',
                                                              filled: true,
                                                              fillColor: const Color(0xFFF9FAFB),
                                                              border: OutlineInputBorder(
                                                                borderRadius: BorderRadius.circular(14),
                                                              ),
                                                              enabledBorder: OutlineInputBorder(
                                                                borderRadius: BorderRadius.circular(14),
                                                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: TextFormField(
                                                            key: ValueKey('item_total_${item.id}'),
                                                            initialValue: item.totalPrice.toString(),
                                                            keyboardType: TextInputType.number,
                                                            inputFormatters: [
                                                              FilteringTextInputFormatter.digitsOnly,
                                                            ],
                                                            onChanged: (value) {
                                                              final nextItems = [...tempCategories[categoryIndex].items];
                                                              nextItems[itemIndex] = nextItems[itemIndex].copyWith(
                                                                totalPrice: _parseInt(value),
                                                              );
                                                              tempCategories[categoryIndex] =
                                                                  tempCategories[categoryIndex].copyWith(items: nextItems);
                                                            },
                                                            decoration: InputDecoration(
                                                              labelText: '실결제금액',
                                                              prefixText: '₩ ',
                                                              suffixText: '원',
                                                              filled: true,
                                                              fillColor: const Color(0xFFF9FAFB),
                                                              border: OutlineInputBorder(
                                                                borderRadius: BorderRadius.circular(14),
                                                              ),
                                                              enabledBorder: OutlineInputBorder(
                                                                borderRadius: BorderRadius.circular(14),
                                                                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          height: 56,
                                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFF9FAFB),
                                                            borderRadius: BorderRadius.circular(14),
                                                            border: Border.all(color: const Color(0xFFE5E7EB)),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              Checkbox(
                                                                value: item.vatIncluded,
                                                                visualDensity: VisualDensity.compact,
                                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                                onChanged: (value) async {
                                                                  await _toggleTemplateVatIncluded(
                                                                    nextValue: value ?? false,
                                                                    tempCategories: tempCategories,
                                                                    categoryIndex: categoryIndex,
                                                                    itemIndex: itemIndex,
                                                                    setSheetState: setSheetState,
                                                                  );
                                                                },
                                                              ),
                                                              const Text(
                                                                'VAT 포함',
                                                                style: TextStyle(
                                                                  fontSize: 12.5,
                                                                  fontWeight: FontWeight.w700,
                                                                  color: Color(0xFF374151),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Align(
                                                      alignment: Alignment.centerLeft,
                                                      child: Text(
                                                        item.sessionCount > 0
                                                            ? '회당 결제금액 자동 계산: ${_formatMoney(((item.vatIncluded ? (item.totalPrice / 1.1).round() : item.totalPrice) / item.sessionCount).round())}원'
                                                            : '횟수를 입력하면 회당 결제금액이 자동 계산됩니다.',
                                                        style: const TextStyle(
                                                          fontSize: 12.2,
                                                          fontWeight: FontWeight.w600,
                                                          color: Color(0xFF64748B),
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
                                                label:
                                                const Text('레슨 항목 추가'),
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
    final int actualTotal = item.totalPrice;
    final int baseTotal =
    item.vatIncluded ? (actualTotal / 1.1).round() : actualTotal;

    final int unitPrice = item.sessionCount > 0
        ? (baseTotal / item.sessionCount).round()
        : 0;

    setState(() {
      _productNameController.text = item.name;
      _sessionCountController.text = item.sessionCount.toString();
      _unitPriceController.text = unitPrice.toString();
      _priceController.text = actualTotal.toString();
      _vatIncluded = item.vatIncluded;
      _ContractUiMemory.vatIncluded = item.vatIncluded;
    });

    _showSnack(
      '${item.name} 금액설정 완료 · ${item.vatIncluded ? 'VAT 포함' : 'VAT 미포함'}',
    );
  }

  Future<bool> _showVatApplyDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('VAT 포함 적용'),
        content: const Text(
          '지금 금액에서 10%를 적용할까요?\n체크하면 실결제금액에 VAT를 더한 값으로 바뀝니다.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('아니오'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('적용'),
          ),
        ],
      ),
    );

    return result ?? false;
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
      _unitPriceController.text = unitPrice.toString();
      _priceController.text = (count * unitPrice).toString();
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

  void _trySavePdf() {
  if (!_isReadyForPdfOrCustomer) {
  _scrollToFirstIncompleteSection();
  _showBlockedExportDialog('PDF 저장');
  return;
  }

  setState(() => _pdfSaved = true);
  _showSnack(
  'PDF 저장 기능은 현재 더미입니다. 지금 화면 기준 ${_documentSnapshot.length}자 문구가 연결되어 있습니다.',
  );
  }

  void _trySendCustomer() {
  if (!_isReadyForPdfOrCustomer) {
  _scrollToFirstIncompleteSection();
  _showBlockedExportDialog('고객 전송');
  return;
  }

  setState(() => _pdfSentToCustomer = true);
  _showSnack('고객 전송 기능은 현재 더미입니다. 화면에서 본 문구 기준으로 연결됩니다.');
  }

  Future<void> _showTrainerTransferComingSoon() async {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('강사 전송 안내'),
        content: const Text(
          '강사 전송은 추후 연결 예정입니다.\n현재는 아직 동작하지 않는 준비 중 기능입니다.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }

  Future<void> _showBlockedExportDialog(String actionLabel) async {
    final items = _blockedExportMessages;

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('$actionLabel 불가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '아직 작성되지 않은 항목이 있어 진행할 수 없습니다.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 10),
            ...items.map(
                  (e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '• $e',
                  style: const TextStyle(height: 1.45),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
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

  Future<void> _openSignaturePad({required bool isMember}) async {
    if (_isFormLocked) {
      _showSnack('서명 완료 후 수정은 새 버전 작성으로 진행해주세요.');
      return;
    }

    final result = await showDialog<List<Offset?>>(
      context: context,
      builder: (_) => _SignatureDialog(
        title: isMember ? '회원 전자서명' : '강사 전자서명',
      ),
    );

  if (result != null && result.any((e) => e != null)) {
  final now = DateTime.now();

  setState(() {
  if (isMember) {
  _memberSignaturePoints = result;
  _memberSignedAt = now;
  } else {
  _staffSignaturePoints = result;
  _staffSignedAt = now;
  }
  });
  }
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

    _healthDetailController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  void _handleComplete() {
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
  if (!_memberSigned) {
  errors.add('회원 서명이 필요합니다.');
  }
  if (!_staffSigned) {
  errors.add('강사 서명이 필요합니다.');
  }

  if (errors.isNotEmpty) {
  _scrollToFirstIncompleteSection();
  _showSnack(errors.first);
  return;
  }

  _showSnack(
  '작성 완료 처리입니다. 저장/PDF/전송은 현재 더미이며, 화면 문구 ${_documentSnapshot.length}자 기준으로 연결되어 있습니다.',
  );
  }

  void _startNewVersion() {
  setState(() {
  _version += 1;
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message),
        ),
      );
  }

  // -------------------- HELPERS --------------------

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

  String _valueOrDash(String value) {
    final v = value.trim();
    return v.isEmpty ? '-' : v;
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

class _HeaderSelectableCard extends StatelessWidget {
  const _HeaderSelectableCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Opacity(
        opacity: onTap == null ? 0.72 : 1,
        child: Container(
          height: 92,
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.14),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 17),
              const Spacer(),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.86),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                    size: 18,
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

class _HeaderProgressCard extends StatelessWidget {
  const _HeaderProgressCard({
    required this.currentStepTitle,
    required this.completedText,
    required this.progressValue,
    required this.pulseAnimation,
    required this.nextHint,
    required this.isCompleted,
  });

  final String currentStepTitle;
  final String completedText;
  final double progressValue;
  final Animation<double> pulseAnimation;
  final String nextHint;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final statusColor =
    isCompleted ? const Color(0xFF34D399) : const Color(0xFFFF5A5A);

    return Container(
      height: 92,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (!isCompleted)
                FadeTransition(
                  opacity: pulseAnimation,
                  child: Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                )
              else
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                isCompleted ? '작성완료' : '작성중',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            nextHint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            completedText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 10.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: progressValue.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withOpacity(0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ],
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

  const _SignatureDialog({
    required this.title,
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
  child: CustomPaint(
  painter: _SignaturePainter(points),
  child: const SizedBox.expand(),
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
