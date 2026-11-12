import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/lesson_contract/lesson_contract_form.dart';
import '../../models/lesson_contract/lesson_contract_settings.dart';
import '../../services/managed_member_workspace_service.dart';
import '../../services/personal_contract_gateway.dart';
import '../../utils/form_error_focus.dart';
import '../../utils/lesson_contract/lesson_contract_rules.dart';
import '../../utils/lesson_contract/won_input_formatter.dart';
import '../../widgets/aifc_interaction.dart';
import '../../utils/lesson_contract/lesson_contract_document.dart';
import 'lesson_contract_preview_page.dart';
import 'lesson_contract_sign_flow_page.dart';
import 'lesson_contract_settings_page.dart';
import 'lesson_contract_terms_section.dart';
import 'lesson_contract_widgets.dart';

const double kLessonContractFormMaxWidth = 480;

typedef ContractMemberStream = Stream<List<ManagedMemberSummary>> Function();

String _newIdempotencyKey() {
  final random = Random.secure();
  final suffix =
      List.generate(8, (_) => random.nextInt(36).toRadixString(36)).join();
  return 'lc-${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-$suffix';
}

/// `months`개월 뒤 날짜(말일을 넘으면 그 달 말일). 계약 종료일 빠른 선택에 쓴다.
DateTime addContractMonths(DateTime date, int months) {
  final monthIndex = date.month - 1 + months;
  final year = date.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, min(date.day, lastDay));
}

/// 레슨계약서 강사 입력 화면. 내 기본 조건이 채워진 상태로 시작하고, 저장하면 서버에
/// 초안으로 남는다(회원 고지·서명은 다음 단계).
class LessonContractFormPage extends StatefulWidget {
  const LessonContractFormPage({
    super.key,
    required this.personalOwnerUid,
    this.contractId,
    this.initialMemberId,
    this.gateway,
    this.membersStream,
    this.clock,
  });

  final String personalOwnerUid;

  /// 이어서 고칠 초안. 없으면 새 계약.
  final String? contractId;

  /// 새 계약을 이 회원으로 시작한다(스케줄 칩·회원카드에서 들어올 때). 고객카드에서
  /// 이름·연락처·생년월일을 가져온다.
  final String? initialMemberId;
  final PersonalContractGateway? gateway;
  final ContractMemberStream? membersStream;
  final DateTime Function()? clock;

  @override
  State<LessonContractFormPage> createState() => _LessonContractFormPageState();
}

class _LessonContractFormPageState extends State<LessonContractFormPage> {
  late final PersonalContractGateway _gateway =
      widget.gateway ?? PersonalContractGateway();
  final String _idempotencyKey = _newIdempotencyKey();

  final _memberEmail = TextEditingController();
  final _productName = TextEditingController();
  final _remarks = TextEditingController();
  final _sessionCount = TextEditingController();
  final _sessionMinutes = TextEditingController();
  final _perSession = TextEditingController();
  final _paidAmount = TextEditingController();
  final _listPrice = TextEditingController();
  final _listPerSession = TextEditingController();

  /// 횟수·회당 금액·실결제금액 중 사용자가 마지막으로 직접 고친 금액 칸(`per` 또는 `paid`).
  /// 나머지 금액 칸은 횟수와 이 값으로 자동 계산된다.
  String _lastMoneyEdit = 'paid';

  /// 정상가·회당 정상가 중 사용자가 마지막으로 직접 고친 칸(`total` 또는 `per`).
  /// 다른 칸은 횟수와 이 값으로 자동 계산된다.
  String _lastListEdit = 'total';

  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;
  bool _showErrors = false;
  bool _dirty = false;
  bool _discounted = false;
  ContractSettings _settings = const ContractSettings();
  LessonContractForm _form = const LessonContractForm();
  String? _contractId;
  String _contractNo = '';

  /// 서버의 계약 상태(`draft` `disclosed` `member_signed` `completed` …). 새 계약이면 `draft`.
  String _status = 'draft';

  bool get _statusLocked =>
      _status == 'completed' ||
      _status == 'terminated' ||
      _status == 'cancelled' ||
      _status == 'superseded';

  DateTime get _today {
    final now = (widget.clock ?? DateTime.now)();
    return DateTime(now.year, now.month, now.day);
  }

  bool get _editingExisting => _contractId != null;

  final Map<String, GlobalKey> _anchors = {};

  /// 계약 당사자 카드는 처음에 접어 둔다.
  bool _partyExpanded = false;

  GlobalKey _anchor(String name) => _anchors.putIfAbsent(name, GlobalKey.new);

  /// 글자 입력 칸의 포커스. 저장할 때 틀린 칸에 커서를 놓는 데 쓴다(오류 이름 기준).
  final Map<String, FocusNode> _focus = {};

  FocusNode _focusFor(String errorKey) =>
      _focus.putIfAbsent(errorKey, FocusNode.new);

  final GlobalKey<LessonContractTermsSectionState> _termsKey =
      GlobalKey<LessonContractTermsSectionState>();

  static const Set<String> _termsErrorKeys = {
    'cancelDeadline',
    'lateNoShowMinutes',
    'penaltyPercent',
    'refundBusinessDays',
    'transferFee',
    'extraTerms',
  };

  static const List<String> _errorOrder = [
    'member',
    'memberName',
    'memberPhone',
    'memberBirthDate',
    'memberEmail',
    'productName',
    'sessionCount',
    'sessionMinutes',
    'perSession',
    'paidAmount',
    'listPrice',
    'paymentDate',
    'remarks',
    'periodStart',
    'periodEnd',
    'cancelDeadline',
    'lateNoShowMinutes',
    'penaltyPercent',
    'refundBusinessDays',
    'transferFee',
    'refundBasis',
    'extraTerms',
  ];

  /// 오류 이름 → 화면에서 찾아갈 위치 이름.
  static String _anchorName(String errorKey) {
    if (errorKey == 'memberEmail') return errorKey;
    if (errorKey.startsWith('member')) return 'member';
    const productKeys = {
      'productName',
      'sessionCount',
      'sessionMinutes',
      'perSession',
      'paidAmount',
      'listPrice',
      'paymentDate',
      'remarks',
      'periodStart',
      'periodEnd',
    };
    return productKeys.contains(errorKey) ? errorKey : 'terms';
  }

  /// 처음 틀린 칸으로 이동하고 그 오류를 토스트로 알린다.
  void _reportErrors(Map<String, String> errors) {
    String? first;
    for (final key in _errorOrder) {
      if (errors.containsKey(key)) {
        first = key;
        break;
      }
    }
    first ??= errors.keys.first;
    final target = first;
    setState(() => _showErrors = true);
    _toast(errors[target] ?? '입력 내용을 확인해 주세요.');
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final anchor = _anchors[_anchorName(target)]?.currentContext;
      // 조항 안의 빈칸은 그 칸에 커서를, 글자 입력 칸은 해당 칸에 커서를 놓는다.
      // 날짜·회원 선택처럼 직접 입력하지 않는 칸은 그 자리로 이동만 한다.
      await revealAndFocus(
        anchorContext: anchor,
        focusNode: _termsErrorKeys.contains(target) ? null : _focus[target],
        alignment: 0.1,
      );
      if (_termsErrorKeys.contains(target) && mounted) {
        _termsKey.currentState?.focusError(target);
      }
    });
  }

  ContractParty? get _party => _settings.party;

  @override
  void initState() {
    super.initState();
    final initialId = (widget.contractId ?? '').trim();
    _contractId = initialId.isEmpty ? null : initialId;
    _load();
  }

  @override
  void dispose() {
    for (final controller in [
      _memberEmail,
      _productName,
      _remarks,
      _sessionCount,
      _sessionMinutes,
      _perSession,
      _paidAmount,
      _listPrice,
      _listPerSession,
    ]) {
      controller.dispose();
    }
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final settings = await _gateway.loadSettings(widget.personalOwnerUid);
      LessonContractForm form;
      if (_contractId != null) {
        final data = await _gateway.loadContract(_contractId!);
        if (data == null) throw StateError('contract_not_found');
        form = LessonContractForm.fromContract(data);
        _contractNo = displayNo(data);
        _status = (data['status'] ?? 'draft').toString();
      } else {
        form = LessonContractForm.fromDefaults(
          settings.defaults,
          today: _today,
        );
        final initialMember = (widget.initialMemberId ?? '').trim();
        if (initialMember.isNotEmpty) {
          form = await _formWithMember(form, initialMember);
        }
      }
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _applyForm(form);
        _loading = false;
        _loadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  /// 저장된 계약번호 표시(`PT-2610-0001`, 새 버전은 `-v2`).
  static String displayNo(Map<String, dynamic> data) {
    final no = (data['contractNo'] ?? '').toString();
    final version = (data['version'] as num?)?.toInt() ?? 1;
    return version > 1 ? '$no-v$version' : no;
  }

  void _applyForm(LessonContractForm form) {
    _form = form;
    _memberEmail.text = form.memberEmail;
    _productName.text = form.productName;
    _remarks.text = form.remarks;
    _sessionCount.text = form.sessionCount?.toString() ?? '';
    _sessionMinutes.text = form.sessionMinutes?.toString() ?? '';
    _paidAmount.text = _won(form.paidAmount);
    _listPrice.text = _won(form.listPrice);
    _perSession.text = _won(form.unitPrice);
    _lastMoneyEdit = 'paid';
    _lastListEdit = 'total';
    _discounted = form.listPrice != null;
    _fillListPerSession();
  }

  /// 정상가와 횟수로 회당 정상가 칸을 채운다(정상가가 없거나 횟수가 없으면 비운다).
  void _fillListPerSession() {
    final count = int.tryParse(_sessionCount.text.trim());
    final list = _discounted ? parseWon(_listPrice.text) : null;
    _setText(
      _listPerSession,
      list == null || count == null || count <= 0
          ? ''
          : formatWon(contractUnitPrice(list, count)),
    );
  }

  static String _won(int? value) => value == null ? '' : formatWon(value);

  static void _setText(TextEditingController controller, String text) {
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// 횟수·회당 금액·실결제금액 중 하나를 고쳤을 때 나머지 금액 칸을 계산한다.
  /// 횟수는 항상 직접 입력하고, 회당 금액을 마지막에 고쳤다면 실결제금액을 `회당 금액 × 횟수`로,
  /// 실결제금액을 마지막에 고쳤다면 회당 금액을 `실결제금액 ÷ 횟수`(원 단위 반올림)로 채운다.
  void _onMoneyEdited(String which) {
    if (which == 'per' || which == 'paid') _lastMoneyEdit = which;
    final count = int.tryParse(_sessionCount.text.trim());
    if (count != null && count > 0) {
      if (_lastMoneyEdit == 'per') {
        final per = parseWon(_perSession.text);
        _setText(_paidAmount, per == null ? '' : formatWon(per * count));
      } else {
        final paid = parseWon(_paidAmount.text);
        _setText(
          _perSession,
          paid == null ? '' : formatWon(contractUnitPrice(paid, count)),
        );
      }
      // 횟수를 바꾸면 정상가 칸도 마지막에 고친 쪽을 기준으로 다시 맞춘다.
      if (which == 'count' && _discounted) _recalcListFields(count);
    }
    _syncFromFields();
  }

  /// 정상가·회당 정상가 중 하나를 고쳤을 때 다른 칸을 계산한다.
  /// 회당 정상가를 마지막에 고쳤다면 정상가를 `회당 정상가 × 횟수`로, 정상가를 마지막에
  /// 고쳤다면 회당 정상가를 `정상가 ÷ 횟수`(원 단위 반올림)로 채운다.
  void _onListEdited(String which) {
    _lastListEdit = which;
    final count = int.tryParse(_sessionCount.text.trim());
    if (count != null && count > 0) _recalcListFields(count);
    _syncFromFields();
  }

  void _recalcListFields(int count) {
    if (_lastListEdit == 'per') {
      final per = parseWon(_listPerSession.text);
      _setText(_listPrice, per == null ? '' : formatWon(per * count));
    } else {
      _fillListPerSession();
    }
  }

  /// 입력 칸의 현재 값으로 [_form]을 다시 만든다.
  void _syncFromFields() {
    final listPrice = _discounted ? parseWon(_listPrice.text) : null;
    setState(() {
      _form = _form.copyWith(
        memberEmail: _memberEmail.text,
        productName: _productName.text,
        remarks: _remarks.text,
        sessionCount: int.tryParse(_sessionCount.text.trim()),
        clearSessionCount: int.tryParse(_sessionCount.text.trim()) == null,
        sessionMinutes: int.tryParse(_sessionMinutes.text.trim()),
        clearSessionMinutes: int.tryParse(_sessionMinutes.text.trim()) == null,
        paidAmount: parseWon(_paidAmount.text),
        clearPaidAmount: parseWon(_paidAmount.text) == null,
        listPrice: listPrice,
        clearListPrice: listPrice == null,
        refundByListPrice: listPrice == null ? false : _form.refundByListPrice,
      );
      _dirty = true;
    });
  }

  /// VAT를 체크할 때, 입력한 금액이 이미 VAT 포함인지 아니면 VAT(10%)를 더해야 하는지 묻는다.
  /// 체크를 해제할 때는 금액을 건드리지 않는다.
  Future<void> _onVatChanged(bool checked) async {
    final paid = parseWon(_paidAmount.text);
    if (!checked || paid == null || paid <= 0) {
      _changeForm(_form.copyWith(vatIncluded: checked));
      return;
    }
    final withVat = (paid * 11 + 5) ~/ 10;
    final choice = await showDialog<_VatChoice>(
      context: context,
      builder:
          (dialogContext) => _VatChoiceDialog(paid: paid, withVat: withVat),
    );
    if (!mounted || choice == null) return;
    if (choice == _VatChoice.add) {
      // 실결제금액을 바꾸고 회당 금액을 다시 계산한 뒤 VAT 포함으로 표시한다.
      _setText(_paidAmount, formatWon(withVat));
      _onMoneyEdited('paid');
    }
    _changeForm(_form.copyWith(vatIncluded: true));
  }

  void _changeForm(LessonContractForm next) {
    setState(() {
      _form = next;
      _dirty = true;
    });
  }

  void _toast(String message) =>
      AifcInteraction.toast(context: context, message: message);

  /// 고객카드 기준 값을 눌렀을 때, 누른 자리 바로 위에 안내를 띄운다.
  void _showCardHint(Offset position) {
    final media = MediaQuery.of(context);
    final bottom = media.size.height - media.padding.bottom - position.dy + 12;
    AifcInteraction.toast(
      context: context,
      message: '고객카드 기준입니다. 바꾸려면 회원카드에서 수정해 주세요.',
      bottomOffset: bottom.clamp(76.0, media.size.height - 140),
    );
  }

  // ---- 회원 선택 ----
  Future<void> _pickMember() async {
    final stream =
        widget.membersStream ??
        () =>
            FirebaseManagedMemberWorkspaceGateway(
              uid: widget.personalOwnerUid,
            ).watchMembers();
    final picked = await showModalBottomSheet<ManagedMemberSummary>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MemberPickerSheet(stream: stream()),
    );
    if (picked == null || !mounted) return;
    final next = await _formWithMember(
      _form,
      picked.memberId,
      fallbackName: picked.name,
      fallbackPhone: picked.phone,
    );
    if (!mounted) return;
    setState(() {
      _form = next;
      _dirty = true;
    });
  }

  /// 고객카드에서 이름·연락처·생년월일을 읽어 [form]의 회원 칸을 채운다.
  Future<LessonContractForm> _formWithMember(
    LessonContractForm form,
    String memberId, {
    String fallbackName = '',
    String fallbackPhone = '',
  }) async {
    Map<String, dynamic>? card;
    try {
      card = await _gateway.loadMemberCard(memberId);
    } catch (_) {
      // 카드를 읽지 못하면 넘겨받은 이름·연락처로 채운다.
    }
    String fromCard(String key, String fallback) {
      final value = (card?[key] ?? '').toString().trim();
      return value.isEmpty ? fallback : value;
    }

    return form.copyWith(
      memberId: memberId,
      memberName: fromCard('name', fallbackName),
      memberPhone: fromCard('phone', fallbackPhone),
      memberBirthDate: contractBirthDateFromCardMap(card),
    );
  }

  // ---- 내 수업 상품 ----
  void _applyPresetToFields(ContractProductPreset preset) {
    _productName.text = preset.name;
    _sessionCount.text = '${preset.sessionCount}';
    _sessionMinutes.text = '${preset.sessionMinutes}';
    _paidAmount.text = formatWon(preset.paidAmount);
    _perSession.text = formatWon(
      contractUnitPrice(preset.paidAmount, preset.sessionCount),
    );
    _lastMoneyEdit = 'paid';
    _lastListEdit = 'total';
    _listPrice.text = _won(preset.listPrice);
    _discounted = preset.listPrice != null;
    _fillListPerSession();
    _form = _form.applyPreset(preset);
    _dirty = true;
  }

  Future<bool> _persistProducts(List<ContractProductPreset> next) async {
    try {
      await _gateway.saveSettings(products: next);
      if (!mounted) return false;
      setState(() {
        _settings = ContractSettings(
          party: _settings.party,
          defaults: _settings.defaults,
          products: next,
        );
      });
      return true;
    } catch (error) {
      if (mounted) _toast(contractErrorMessage(error));
      return false;
    }
  }

  Future<void> _loadPreset() async {
    final picked = await showModalBottomSheet<ContractProductPreset>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProductPickerSheet(products: _settings.products),
    );
    if (picked == null || !mounted) return;
    setState(() => _applyPresetToFields(picked));
  }

  Future<void> _savePreset() async {
    final errors = _form.validate();
    const productKeys = [
      'productName',
      'sessionCount',
      'sessionMinutes',
      'paidAmount',
      'listPrice',
    ];
    final blocking = {
      for (final key in productKeys)
        if (errors[key] != null) key: errors[key]!,
    };
    final preset = _form.toPreset();
    if (preset == null || blocking.isNotEmpty) {
      _reportErrors(
        blocking.isNotEmpty
            ? blocking
            : {'productName': '저장할 상품 정보를 먼저 입력해 주세요.'},
      );
      return;
    }
    final products = [..._settings.products];
    final index = products.indexWhere(
      (item) => item.name.toLowerCase() == preset.name.toLowerCase(),
    );
    if (index >= 0) {
      if (products[index].hasSameContentAs(preset)) {
        _toast('이미 저장된 상품입니다.');
        return;
      }
      final replace = await showDialog<bool>(
        context: context,
        builder:
            (dialogContext) => AlertDialog(
              key: const Key('contract_preset_replace_dialog'),
              title: const Text('새 내용으로 저장할까요?'),
              content: Text("'${preset.name}' 상품이 이미 있어요.\n바뀐 내용으로 덮어써요."),
              actions: [
                TextButton(
                  key: const Key('contract_preset_replace_cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('취소'),
                ),
                TextButton(
                  key: const Key('contract_preset_replace_confirm'),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('저장'),
                ),
              ],
            ),
      );
      if (replace != true || !mounted) return;
      products[index] = preset;
    } else {
      products.add(preset);
    }
    if (products.length > 20) {
      _toast('수업 상품은 최대 20개까지 저장할 수 있어요.');
      return;
    }
    if (await _persistProducts(products) && mounted) {
      _toast(index >= 0 ? '내 수업 상품을 새 내용으로 바꿨어요.' : '내 수업 상품에 저장했어요.');
    }
  }

  // ---- 날짜 ----
  Future<DateTime?> _pickDate(String current) async {
    final initial = parseContractDate(current) ?? _today;
    return showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
  }

  Future<void> _pickPeriodStart() async {
    final picked = await _pickDate(_form.periodStart);
    if (picked == null) return;
    _changeForm(_form.copyWith(periodStart: formatContractDate(picked)));
  }

  Future<void> _pickPeriodEnd() async {
    final picked = await _pickDate(_form.periodEnd);
    if (picked == null) return;
    _changeForm(_form.copyWith(periodEnd: formatContractDate(picked)));
  }

  Future<void> _pickPaymentDate() async {
    final picked = await _pickDate(_form.paymentDate);
    if (picked == null) return;
    _changeForm(_form.copyWith(paymentDate: formatContractDate(picked)));
  }

  void _setEndMonths(int months) {
    final start = parseContractDate(_form.periodStart);
    if (start == null) {
      _toast('시작일을 먼저 선택해 주세요.');
      return;
    }
    _changeForm(
      _form.copyWith(
        periodEnd: formatContractDate(addContractMonths(start, months)),
      ),
    );
  }

  /// 계약 당사자(= 계약서 앞면의 강사/센터) 정보가 부족할 때의 안내. 빈 칸 이름을 함께 알린다.
  String _partyMissingMessage(ContractParty? party, {bool forPreview = false}) {
    const labels = {
      'name': '이름(센터명)',
      'trainerName': '담당 강사 이름',
      'phone': '연락처',
      'place': '수업 장소',
      'businessNo': '사업자등록번호',
    };
    final lacking = <String>[
      for (final key in (party?.validate().keys ?? const <String>[]))
        labels[key] ?? key,
    ];
    final head =
        forPreview
            ? '계약 당사자(강사) 정보를 먼저 입력하면 미리볼 수 있어요.'
            : '계약 당사자(강사) 정보를 먼저 입력해 주세요.';
    if (lacking.isEmpty) return '$head 계약 설정에서 입력할 수 있어요.';
    return '$head 빠진 항목: ${lacking.join(', ')}';
  }

  // ---- 미리보기 ----
  void _openPreview() {
    final party = _party;
    if (party == null || !party.isComplete) {
      _toast(_partyMissingMessage(party, forPreview: true));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => LessonContractPreviewPage(
              document: buildLessonContractDocument(
                form: _form,
                party: party,
                contractNo: _contractNo,
              ),
            ),
      ),
    );
  }

  // ---- 설정 ----
  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => LessonContractSettingsPage(
              personalOwnerUid: widget.personalOwnerUid,
              gateway: widget.gateway,
            ),
      ),
    );
    if (!mounted) return;
    try {
      final settings = await _gateway.loadSettings(widget.personalOwnerUid);
      if (!mounted) return;
      setState(() => _settings = settings);
    } catch (_) {
      // 설정을 다시 읽지 못해도 입력 중인 내용은 그대로 둔다.
    }
  }

  // ---- 저장 ----
  Future<bool> _save({bool quiet = false}) async {
    if (_saving) return false;
    if (_statusLocked) {
      _toast('이미 완료되었거나 취소된 계약서는 고칠 수 없어요.');
      return false;
    }
    final party = _party;
    if (party == null || !party.isComplete) {
      _toast(_partyMissingMessage(party));
      return false;
    }
    final errors = _form.validate();
    if (errors.isNotEmpty) {
      _reportErrors(errors);
      return false;
    }
    setState(() => _saving = true);
    try {
      final content = _form.toContent(party);
      final result = await _gateway.saveDraft(
        idempotencyKey: _contractId == null ? _idempotencyKey : null,
        contractId: _contractId,
        memberId: _form.memberId,
        content: content,
      );
      if (!mounted) return false;
      setState(() {
        _saving = false;
        _dirty = false;
        _contractId = result.contractId;
        _contractNo = result.contractNo;
        _status = result.status;
      });
      if (result.invalidatedSignatures) {
        _toast('내용이 바뀌어 이전 서명이 무효가 됐어요. 다시 고지가 필요해요.');
      } else if (!quiet) {
        _toast('초안을 저장했어요. ${result.contractNo}');
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _saving = false);
      _toast(contractErrorMessage(error));
      return false;
    }
  }

  /// 회원 서명 진행. 저장하지 않은 변경이 있으면 먼저 저장하고(서명 ① 이후 변경이면 서버가
  /// 서명을 무효로 돌린다) 서명 흐름 화면으로 넘어간다.
  Future<void> _startSigning() async {
    if (_saving || _statusLocked) return;
    if (_dirty || _contractId == null) {
      final saved = await _save(quiet: true);
      if (!saved || !mounted) return;
    }
    final id = _contractId;
    if (id == null || !mounted) return;
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder:
            (_) => LessonContractSignFlowPage(
              contractId: id,
              gateway: widget.gateway,
            ),
      ),
    );
    if (!mounted) return;
    if (completed == true) {
      Navigator.of(context).pop(true);
      return;
    }
    // 서명을 받다 돌아왔다면 서버의 최신 상태를 다시 읽는다.
    try {
      final data = await _gateway.loadContract(id);
      if (!mounted || data == null) return;
      setState(() => _status = (data['status'] ?? _status).toString());
    } catch (_) {
      // 상태를 못 읽어도 입력 내용은 그대로 둔다.
    }
  }

  String? get _statusNotice {
    switch (_status) {
      case 'disclosed':
        return '회원 서명 ①이 끝난 계약서예요. 내용을 바꾸면 서명이 무효가 되어 다시 받아야 해요.';
      case 'member_signed':
        return '회원 서명이 모두 끝난 계약서예요. 내용을 바꾸면 서명이 무효가 되어 다시 받아야 해요.';
      case 'completed':
        return '서명이 완료된 계약서라 고칠 수 없어요. 잘못 썼다면 완료 후 3일 안에 파기할 수 있어요.';
      case 'terminated':
        return '해지된 계약서라 고칠 수 없어요.';
      case 'cancelled':
        return '취소된 계약서예요.';
      case 'superseded':
        return '새 버전으로 대체된 계약서예요.';
    }
    return null;
  }

  Future<void> _handleBack() async {
    final navigator = Navigator.of(context);
    if (!_dirty) {
      navigator.pop();
      return;
    }
    // 0 계속 작성 · 1 저장하고 나가기 · 2 저장하지 않고 나가기
    final choice = await showDialog<int>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            key: const ValueKey<String>('contract_form_leave_dialog'),
            title: const Text('저장하지 않고 나갈까요?'),
            content: const Text('지금까지 입력한 내용이 사라져요.'),
            actions: [
              TextButton(
                key: const ValueKey<String>('contract_form_leave_stay'),
                onPressed: () => Navigator.of(dialogContext).pop(0),
                child: const Text('계속 작성'),
              ),
              TextButton(
                key: const ValueKey<String>('contract_form_leave_save'),
                onPressed: () => Navigator.of(dialogContext).pop(1),
                child: const Text('저장하고 나가기'),
              ),
              TextButton(
                key: const ValueKey<String>('contract_form_leave_discard'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(dialogContext).colorScheme.error,
                ),
                onPressed: () => Navigator.of(dialogContext).pop(2),
                child: const Text('나가기'),
              ),
            ],
          ),
    );
    if (!mounted) return;
    if (choice == 1) {
      // 저장에 성공했을 때만 나간다(검증 오류 등으로 실패하면 화면에 남는다).
      if (await _save(quiet: true) && mounted) navigator.pop();
      return;
    }
    if (choice == 2) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.maxWidth >= 600
                  ? kLessonContractFormMaxWidth
                  : constraints.maxWidth;
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: SizedBox(
                width: width,
                child: Column(
                  children: [
                    LessonContractHeader(
                      title: _contractNo.isEmpty ? '레슨계약서 작성' : _contractNo,
                      backKey: const ValueKey<String>('contract_form_back'),
                      onBack: _handleBack,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 초안 저장: 스크롤하지 않아도 항상 보이도록 머리말에 둔다.
                          TextButton(
                            key: const ValueKey<String>('contract_form_save'),
                            onPressed:
                                _loading ||
                                        _loadFailed ||
                                        _saving ||
                                        _statusLocked
                                    ? null
                                    : _save,
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              disabledForegroundColor: Colors.white54,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                            child:
                                _saving
                                    ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                    : const Text('저장'),
                          ),
                          IconButton(
                            key: const ValueKey<String>(
                              'contract_form_preview',
                            ),
                            tooltip: '계약서 미리보기',
                            onPressed:
                                _loading || _loadFailed ? null : _openPreview,
                            icon: const Icon(
                              Icons.description_outlined,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(child: _buildBody(context)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('계약서를 불러오지 못했어요.'),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey<String>('contract_form_retry'),
                onPressed: () {
                  setState(() {
                    _loading = true;
                    _loadFailed = false;
                  });
                  _load();
                },
                child: const Text('다시 불러오기'),
              ),
            ],
          ),
        ),
      );
    }
    final errors = _showErrors ? _form.validate() : const <String, String>{};
    return Theme(
      data: contractFormTheme(context),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          28 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          _buildPartyCard(context),
          const SizedBox(height: 14),
          LessonContractSectionCard(
            title: '회원',
            subtitle: '계약서에 표시되는 회원 정보입니다.',
            child: _buildMember(errors),
          ),
          const SizedBox(height: 14),
          LessonContractSectionCard(
            title: '수업 상품과 금액',
            subtitle: '횟수와 금액 두 가지를 입력하면 나머지가 자동 계산됩니다.',
            child: _buildProduct(context, errors),
          ),
          const SizedBox(height: 14),
          KeyedSubtree(
            key: _anchor('terms'),
            child: LessonContractSectionCard(
              title: '계약 조건',
              subtitle: '내 기본 조건이 채워져 있습니다. 이 계약에서만 바꿀 수 있습니다.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LessonContractTermsSection(
                    key: _termsKey,
                    form: _form,
                    errors: errors,
                    onChanged: _changeForm,
                  ),
                  const Divider(height: 28),
                  _LightDisclosure(
                    title: '환불 계산 예시 보기',
                    toggleKey: const ValueKey<String>('refund_example_toggle'),
                    child: LessonContractRefundExample(form: _form),
                  ),
                ],
              ),
            ),
          ),
          if (_statusNotice != null) ...[
            Container(
              key: const ValueKey<String>('contract_form_status_banner'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Text(_statusNotice!),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 6),
          // 초안 저장은 머리말의 `저장`으로 옮겼다. 아래에는 다음 단계(회원 서명)만 둔다.
          FilledButton.icon(
            key: const ValueKey<String>('contract_form_start_signing'),
            onPressed: _saving || _statusLocked ? null : _startSigning,
            icon:
                _saving
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.draw_outlined),
            label: Text(_status == 'draft' ? '저장하고 회원 서명 받기' : '회원 서명 이어서 진행'),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyCard(BuildContext context) {
    final party = _party;
    final scheme = Theme.of(context).colorScheme;
    if (party == null || !party.isComplete) {
      return Container(
        key: const ValueKey<String>('contract_form_party_missing'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '계약 당사자 정보가 필요해요',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: scheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '센터 또는 강사 개인의 이름, 연락처, 수업 장소를 설정에서 입력하면 계약서에 표시돼요.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
            const SizedBox(height: 10),
            FilledButton(
              key: const ValueKey<String>('contract_form_open_settings'),
              onPressed: _openSettings,
              child: const Text('계약 설정 열기'),
            ),
          ],
        ),
      );
    }
    return LessonContractCollapsibleCard(
      toggleKey: const ValueKey<String>('contract_form_party_toggle'),
      title:
          '계약 당사자 (${party.kind == ContractPartyKind.center ? '센터' : '강사 개인'})',
      expanded: _partyExpanded,
      onToggle: () => setState(() => _partyExpanded = !_partyExpanded),
      child: Column(
        key: const ValueKey<String>('contract_form_party_summary'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            party.name,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '계약 시작 시점의 값이 계약서에 복사됩니다.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text('담당 강사 ${party.trainerName} · ${party.phone}'),
          Text(party.place),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const ValueKey<String>('contract_form_open_settings'),
              onPressed: _openSettings,
              child: const Text('설정 변경'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMember(Map<String, String> errors) {
    final selected = _form.memberId.isNotEmpty;
    final cardError =
        errors['memberName'] ??
        errors['memberPhone'] ??
        errors['memberBirthDate'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeyedSubtree(
          key: _anchor('member'),
          child: _SelectField(
            fieldKey: const ValueKey<String>('contract_form_pick_member'),
            label: '회원',
            value: selected ? _form.memberName : '',
            placeholder: '회원 선택',
            enabled: !_editingExisting,
            errorText: errors['member'],
            onTap: _pickMember,
          ),
        ),
        const SizedBox(height: 10),
        if (selected)
          _MemberCardInfo(
            name: _form.memberName,
            phone: _form.memberPhone,
            birthDate: _form.memberBirthDate,
            error: cardError,
            onTapRow: _showCardHint,
          ),
        if (selected) const SizedBox(height: 10),
        _field(
          'contract_form_member_email',
          _memberEmail,
          '이메일 (선택)',
          errors['memberEmail'],
          errorKey: 'memberEmail',
          keyboard: TextInputType.emailAddress,
          maxLength: 100,
        ),
      ],
    );
  }

  Widget _buildProduct(BuildContext context, Map<String, String> errors) {
    final paid = _form.paidAmount;
    final list = _form.listPrice;
    final showDiscount =
        _discounted && paid != null && list != null && list > paid;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SelectField(
          fieldKey: const ValueKey<String>('contract_form_load_preset'),
          label: '내 수업 상품',
          value: '',
          placeholder: '저장한 상품 불러오기',
          onTap: _loadPreset,
        ),
        const SizedBox(height: 10),
        _field(
          'contract_form_product_name',
          _productName,
          '레슨명',
          errors['productName'],
          errorKey: 'productName',
          maxLength: 40,
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _field(
                'contract_form_session_count',
                _sessionCount,
                '총 횟수',
                errors['sessionCount'],
                errorKey: 'sessionCount',
                keyboard: TextInputType.number,
                maxLength: 3,
                formatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => _onMoneyEdited('count'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: _field(
                'contract_form_per_session',
                _perSession,
                '회당 금액 (원)',
                errors['perSession'],
                errorKey: 'perSession',
                keyboard: TextInputType.number,
                maxLength: 11,
                formatters: [const WonInputFormatter()],
                onChanged: (_) => _onMoneyEdited('per'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 3,
              child: _field(
                'contract_form_session_minutes',
                _sessionMinutes,
                '1회 시간(분)',
                errors['sessionMinutes'],
                errorKey: 'sessionMinutes',
                keyboard: TextInputType.number,
                maxLength: 3,
                formatters: [FilteringTextInputFormatter.digitsOnly],
              ),
            ),
          ],
        ),
        _field(
          'contract_form_paid_amount',
          _paidAmount,
          '실결제금액 (원)',
          errors['paidAmount'],
          errorKey: 'paidAmount',
          keyboard: TextInputType.number,
          maxLength: 11,
          formatters: [const WonInputFormatter()],
          onChanged: (_) => _onMoneyEdited('paid'),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _VatToggle(
              value: _form.vatIncluded,
              onChanged: _onVatChanged,
            ),
          ),
        ),
        CheckboxListTile(
          key: const ValueKey<String>('contract_form_discounted'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: const Text('할인 상품 (정상가 입력)'),
          subtitle: const Text('실제로 판매하던 정상가만 입력해 주세요.'),
          value: _discounted,
          onChanged: (value) {
            final checked = value ?? false;
            setState(() => _discounted = checked);
            if (!checked) {
              _listPrice.clear();
              _listPerSession.clear();
            }
            _syncFromFields();
          },
        ),
        if (_discounted)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _field(
                  'contract_form_list_price',
                  _listPrice,
                  '정상가 (원)',
                  errors['listPrice'],
                  errorKey: 'listPrice',
                  keyboard: TextInputType.number,
                  maxLength: 13,
                  formatters: [const WonInputFormatter()],
                  onChanged: (_) => _onListEdited('total'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _field(
                  'contract_form_list_per_session',
                  _listPerSession,
                  '회당 정상가 (원)',
                  null,
                  errorKey: 'listPerSession',
                  keyboard: TextInputType.number,
                  maxLength: 11,
                  formatters: [const WonInputFormatter()],
                  onChanged: (_) => _onListEdited('per'),
                ),
              ),
            ],
          ),
        if (showDiscount)
          _LightDisclosure(
            title: '할인율 보기',
            toggleKey: const ValueKey<String>('contract_form_discount_toggle'),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '정상가 대비 ${discountRateLabel(paid, list)} 할인 '
                '(${formatWon(list)}원 → ${formatWon(paid)}원)',
                key: const ValueKey<String>('contract_form_discount_rate'),
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            key: const ValueKey<String>('contract_form_save_preset'),
            onPressed: _savePreset,
            icon: const Icon(Icons.bookmark_add_outlined, size: 18),
            label: const Text('이 상품을 내 수업 상품으로 저장'),
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: DropdownButtonFormField<String>(
            key: const ValueKey<String>('contract_form_payment_method'),
            initialValue: _form.paymentMethod,
            decoration: const InputDecoration(
              labelText: '결제 방법 (선택)',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem(value: '', child: Text('선택 안 함')),
              for (final (wire, label) in kContractPaymentMethods)
                DropdownMenuItem(value: wire, child: Text(label)),
            ],
            onChanged:
                (value) =>
                    _changeForm(_form.copyWith(paymentMethod: value ?? '')),
          ),
        ),
        _dateField(
          'contract_form_payment_date',
          '결제일 (선택)',
          _form.paymentDate,
          errors['paymentDate'],
          _pickPaymentDate,
          errorKey: 'paymentDate',
        ),
        _field(
          'contract_form_remarks',
          _remarks,
          '비고 (선택)',
          errors['remarks'],
          errorKey: 'remarks',
          maxLength: kContractMaxRemarksLength,
          hint: '예: 11월 50만원, 12월 50만원 분할 결제',
          helper: '분할결제·쿠폰 사용처럼 안내가 필요한 내용을 적어요. 계약서 비고란에 들어가요.',
        ),
        const SizedBox(height: 4),
        Text(
          '사용 가능 기간',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        _dateField(
          'contract_form_period_start',
          '사용 시작일',
          _form.periodStart,
          errors['periodStart'],
          _pickPeriodStart,
          errorKey: 'periodStart',
        ),
        _dateField(
          'contract_form_period_end',
          '유효기간 종료일',
          _form.periodEnd,
          errors['periodEnd'],
          _pickPeriodEnd,
          errorKey: 'periodEnd',
          disabled: _form.periodUnlimited,
          disabledText: '종료일 없음',
          toggle: _NoExpiryToggle(
            value: _form.periodUnlimited,
            onChanged:
                (value) => _changeForm(
                  _form.copyWith(
                    periodUnlimited: value,
                    periodEnd: value ? '' : _form.periodEnd,
                  ),
                ),
          ),
          quickMenu: PopupMenuButton<int>(
            key: const ValueKey<String>('contract_form_end_menu'),
            tooltip: '사용 시작일 기준으로 입력',
            icon: const Icon(Icons.more_time_rounded, size: 20),
            onSelected: _setEndMonths,
            itemBuilder:
                (_) => [
                  for (final months in const [1, 2, 3, 6])
                    PopupMenuItem<int>(
                      key: ValueKey<String>('contract_form_end_plus_$months'),
                      value: months,
                      child: Text('사용 시작일 +$months개월'),
                    ),
                ],
          ),
        ),
        Text(
          _form.periodUnlimited
              ? '종료일을 정하지 않으면 기간이 지나도 남은 횟수가 소멸하지 않습니다.'
              : '유효기간 종료일이 지나면 남은 횟수는 소멸합니다. 사용 가능 기간은 최대 3년입니다.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _field(
    String key,
    TextEditingController controller,
    String label,
    String? error, {
    required String errorKey,
    TextInputType? keyboard,
    int? maxLength,
    List<TextInputFormatter>? formatters,
    ValueChanged<String>? onChanged,
    Widget? suffixIcon,
    String? hint,
    String? helper,
  }) {
    return KeyedSubtree(
      key: _anchor(errorKey),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          key: ValueKey<String>(key),
          controller: controller,
          focusNode: _focusFor(errorKey),
          keyboardType: keyboard,
          maxLength: maxLength,
          inputFormatters: formatters,
          onChanged: onChanged ?? (_) => _syncFromFields(),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            helperText: helper,
            helperMaxLines: 2,
            errorText: error,
            counterText: '',
            isDense: true,
            suffixIcon: suffixIcon,
            suffixIconConstraints: const BoxConstraints(
              minHeight: 0,
              minWidth: 0,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dateField(
    String key,
    String label,
    String value,
    String? error,
    VoidCallback onTap, {
    required String errorKey,
    Widget? quickMenu,
    Widget? toggle,
    bool disabled = false,
    String disabledText = '',
  }) {
    return KeyedSubtree(
      key: _anchor(errorKey),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: InkWell(
          key: ValueKey<String>(key),
          onTap: disabled ? null : onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              errorText: error,
              isDense: true,
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (toggle != null) toggle,
                  if (quickMenu != null && !disabled) quickMenu,
                  const Padding(
                    padding: EdgeInsets.only(right: 10, left: 4),
                    child: Icon(Icons.calendar_today_rounded, size: 18),
                  ),
                ],
              ),
              suffixIconConstraints: const BoxConstraints(
                minHeight: 0,
                minWidth: 0,
              ),
            ),
            child: Text(
              disabled ? disabledText : (value.isEmpty ? '선택' : value),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color:
                    disabled
                        ? Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6)
                        : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 드롭다운처럼 보이는 선택 칸. 누르면 `onTap`(선택 시트 열기)을 실행한다.
class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.enabled = true,
    this.errorText,
  });

  final Key fieldKey;
  final String label;
  final String value;
  final String placeholder;
  final VoidCallback onTap;
  final bool enabled;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasValue = value.isNotEmpty;
    return InkWell(
      key: fieldKey,
      onTap: enabled ? onTap : null,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          isDense: true,
          enabled: enabled,
          suffixIcon: Icon(
            Icons.arrow_drop_down_rounded,
            color: enabled ? null : theme.disabledColor,
          ),
        ),
        child: Text(
          hasValue ? value : placeholder,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: hasValue ? FontWeight.w700 : FontWeight.w400,
            color:
                hasValue
                    ? null
                    : theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
      ),
    );
  }
}

/// 가볍게 펼치는 항목(`할인율 보기`, `환불 계산 예시 보기`). 칸이나 카드 없이 글자와 화살표만 보인다.
class _LightDisclosure extends StatefulWidget {
  const _LightDisclosure({
    required this.title,
    required this.toggleKey,
    required this.child,
  });

  final String title;
  final Key toggleKey;
  final Widget child;

  @override
  State<_LightDisclosure> createState() => _LightDisclosureState();
}

class _LightDisclosureState extends State<_LightDisclosure> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          key: widget.toggleKey,
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Icon(
                  _open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.topCenter,
          child: _open ? widget.child : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

enum _VatChoice { already, add }

/// VAT 체크 시 금액 처리 방법을 고르는 창. 두 선택지는 글자를 한 줄로 줄여 맞춘 같은 크기의 카드다.
class _VatChoiceDialog extends StatelessWidget {
  const _VatChoiceDialog({required this.paid, required this.withVat});

  final int paid;
  final int withVat;

  /// 칸이 좁아도 줄바꿈이나 넘침 없이 한 줄에 들어가도록 글자 크기를 줄여 맞춘다.
  /// 줄 높이를 고정해 두 선택 카드가 글자 길이와 상관없이 같은 높이가 된다.
  static Widget _oneLine(
    BuildContext context,
    String text,
    TextStyle? style,
    double height,
  ) {
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return SizedBox(
      height: height * scale,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(text, maxLines: 1, softWrap: false, style: style),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget option({
      required Key key,
      required IconData icon,
      required String title,
      required String detail,
      required _VatChoice value,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.of(context).pop(value),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outlineVariant),
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _oneLine(
                        context,
                        title,
                        theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                        20,
                      ),
                      const SizedBox(height: 3),
                      _oneLine(
                        context,
                        detail,
                        theme.textTheme.bodySmall?.copyWith(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                        18,
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

    return AlertDialog(
      key: const ValueKey<String>('contract_form_vat_dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      title: const Text('VAT를 어떻게 처리할까요?', style: TextStyle(fontSize: 17)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '입력하신 실결제금액은 ${formatWon(paid)}원이에요.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            option(
              key: const ValueKey<String>('contract_form_vat_already'),
              icon: Icons.check_circle_outline_rounded,
              title: '이미 VAT가 포함된 금액이에요',
              detail: '${formatWon(paid)}원 (VAT 포함) 그대로',
              value: _VatChoice.already,
            ),
            const SizedBox(height: 8),
            option(
              key: const ValueKey<String>('contract_form_vat_add'),
              icon: Icons.add_circle_outline_rounded,
              title: 'VAT 10%를 더할게요',
              detail:
                  '${formatWon(paid)}원 + ${formatWon(withVat - paid)}원 = ${formatWon(withVat)}원',
              value: _VatChoice.add,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey<String>('contract_form_vat_cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
      ],
    );
  }
}

/// 유효기간 종료일 칸의 "없음" 버튼. 원 안의 X 아이콘이고, 누르면 밝은색으로 켜진다.
class _NoExpiryToggle extends StatelessWidget {
  const _NoExpiryToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      toggled: value,
      label: '유효기간 종료일 없음',
      child: IconButton(
        key: const ValueKey<String>('contract_form_no_expiry'),
        tooltip: '종료일 없음',
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        padding: EdgeInsets.zero,
        onPressed: () => onChanged(!value),
        icon: Icon(
          value ? Icons.cancel_rounded : Icons.cancel_outlined,
          size: 22,
          color:
              value ? scheme.primary : scheme.onSurface.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

/// 실결제금액 칸 오른쪽 끝의 VAT 포함 체크박스. 선택 안 하면 회색 글씨, 선택하면 또렷한 글씨.
class _VatToggle extends StatelessWidget {
  const _VatToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: const ValueKey<String>('contract_form_vat'),
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: value,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                onChanged: (checked) => onChanged(checked ?? false),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'VAT',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color:
                    value
                        ? scheme.onSurface
                        : scheme.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 고객카드에서 가져온 회원 정보(읽기 전용). 누르면 어디서 고치는지 안내만 한다.
class _MemberCardInfo extends StatelessWidget {
  const _MemberCardInfo({
    required this.name,
    required this.phone,
    required this.birthDate,
    required this.onTapRow,
    this.error,
  });

  final String name;
  final String phone;
  final String birthDate;
  final String? error;
  final ValueChanged<Offset> onTapRow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget row(String key, String label, String value) => GestureDetector(
      key: ValueKey<String>('${key}_row'),
      behavior: HitTestBehavior.opaque,
      onTapUp: (details) => onTapRow(details.globalPosition),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 72,
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '고객카드에 없음' : value,
                key: ValueKey<String>(key),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Container(
      key: const ValueKey<String>('contract_form_member_card'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        // 계약 설정 버튼과 같은 primary 계열을 옅게 깔아 앱 톤과 맞춘다(밝은/어두운 모드 공통).
        color: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.08),
          scheme.surface,
        ),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('contract_form_member_name', '이름', name),
          row('contract_form_member_phone', '연락처', phone),
          row('contract_form_member_birth', '생년월일', birthDate),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                error!,
                key: const ValueKey<String>('contract_form_member_card_error'),
                style: TextStyle(color: scheme.error),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberPickerSheet extends StatefulWidget {
  const _MemberPickerSheet({required this.stream});

  final Stream<List<ManagedMemberSummary>> stream;

  @override
  State<_MemberPickerSheet> createState() => _MemberPickerSheetState();
}

class _MemberPickerSheetState extends State<_MemberPickerSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.7;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  key: const ValueKey<String>('contract_member_search'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded),
                    hintText: '회원 이름 또는 연락처 검색',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ManagedMemberSummary>>(
                  stream: widget.stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('회원 목록을 불러오지 못했어요.'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final query = _search.text.trim().toLowerCase();
                    final digits = query.replaceAll(RegExp(r'\D'), '');
                    final members =
                        snapshot.data!.where((member) {
                          if (query.isEmpty) return true;
                          if (member.name.toLowerCase().contains(query)) {
                            return true;
                          }
                          final phone = member.phone.replaceAll(
                            RegExp(r'\D'),
                            '',
                          );
                          return digits.isNotEmpty && phone.contains(digits);
                        }).toList();
                    if (members.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            snapshot.data!.isEmpty
                                ? '등록된 회원이 없어요. 회원을 먼저 등록해 주세요.'
                                : '검색 결과가 없어요.',
                            key: const ValueKey<String>(
                              'contract_member_empty',
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        return ListTile(
                          key: ValueKey<String>(
                            'contract_member_${member.memberId}',
                          ),
                          title: Text(member.name),
                          subtitle: Text(
                            member.phone.isEmpty ? '연락처 없음' : member.phone,
                          ),
                          onTap: () => Navigator.of(context).pop(member),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 저장해 둔 수업 상품에서 고르는 시트. 여기서는 고르기만 하고, 고치고 지우는 것은
/// MY의 `내 수업 상품`에서 한다(삭제 확인창도 거기에 있다).
class _ProductPickerSheet extends StatelessWidget {
  const _ProductPickerSheet({required this.products});

  final List<ContractProductPreset> products;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // 상품이 없으면 안내 문구만 들어갈 높이로 낮게 열고, 있을 때만 목록 높이를 잡는다.
    final height =
        products.isEmpty ? null : MediaQuery.of(context).size.height * 0.6;
    return SafeArea(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child:
            products.isEmpty
                ? const Padding(
                  padding: EdgeInsets.fromLTRB(24, 4, 24, 24),
                  child: Text(
                    '저장된 수업 상품이 없어요.\n상품을 입력한 뒤 "내 수업 상품으로 저장"을 누르면 다음부터 여기서 불러올 수 있어요.',
                    key: ValueKey<String>('contract_preset_empty'),
                    textAlign: TextAlign.center,
                  ),
                )
                : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final item = products[index];
                          final list = item.listPrice;
                          return ListTile(
                            key: ValueKey<String>(
                              'contract_preset_${item.name}',
                            ),
                            title: Text(item.name),
                            subtitle: Text(
                              '${item.sessionCount}회 · ${item.sessionMinutes}분 · '
                              '${formatWon(item.paidAmount)}원'
                              '${list == null ? '' : ' (정상가 ${formatWon(list)}원)'}',
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.of(context).pop(item),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                      child: Text(
                        '수정·삭제는 MY의 `내 수업 상품`에서 할 수 있어요.',
                        key: const ValueKey<String>('contract_preset_hint'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
