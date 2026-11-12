import 'package:flutter/material.dart';

import '../../models/lesson_contract/lesson_contract_form.dart';
import '../../models/lesson_contract/lesson_contract_settings.dart';
import '../../services/personal_contract_gateway.dart';
import '../../utils/form_error_focus.dart';
import 'lesson_contract_terms_section.dart';
import 'lesson_contract_widgets.dart';
import '../../widgets/aifc_interaction.dart';

const double kLessonContractSettingsMaxWidth = 480;

/// 레슨계약서의 `계약 당사자`와 `내 기본 조건`을 정하는 화면.
/// 새 계약을 시작할 때 이 값이 채워지고, 계약에는 시작 시점의 값이 복사된다.
class LessonContractSettingsPage extends StatefulWidget {
  const LessonContractSettingsPage({
    super.key,
    required this.personalOwnerUid,
    this.gateway,
  });

  final String personalOwnerUid;
  final PersonalContractGateway? gateway;

  @override
  State<LessonContractSettingsPage> createState() =>
      _LessonContractSettingsPageState();
}

class _LessonContractSettingsPageState
    extends State<LessonContractSettingsPage> {
  final _nameController = TextEditingController();
  final _trainerController = TextEditingController();
  final _phoneController = TextEditingController();
  final _placeController = TextEditingController();
  final _businessController = TextEditingController();

  late final PersonalContractGateway _gateway =
      widget.gateway ?? PersonalContractGateway();

  bool _loading = true;
  bool _saving = false;
  bool _loadFailed = false;
  bool _showErrors = false;

  /// 틀린 칸으로 이동해 커서를 놓기 위한 칸별 포커스·위치(오류 이름 기준).
  final Map<String, FocusNode> _focus = {};
  final Map<String, GlobalKey> _anchors = {};
  final GlobalKey<LessonContractTermsSectionState> _termsKey =
      GlobalKey<LessonContractTermsSectionState>();

  FocusNode _focusFor(String key) => _focus.putIfAbsent(key, FocusNode.new);

  GlobalKey _anchor(String key) => _anchors.putIfAbsent(key, GlobalKey.new);
  ContractPartyKind _kind = ContractPartyKind.individual;

  /// 로고는 마이페이지에서 올린 값을 그대로 계약 당사자에 싣는다(여기서는 바꾸지 않는다).
  String _logoPath = '';

  /// `내 기본 조건` 편집 값(계약 입력 화면과 같은 조항 입력 위젯을 쓰려고 입력 값 형태로 둔다).
  LessonContractForm _terms = LessonContractForm.fromDefaults(
    ContractDefaults.standard,
    today: DateTime(2000),
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final node in _focus.values) {
      node.dispose();
    }
    _nameController.dispose();
    _trainerController.dispose();
    _phoneController.dispose();
    _placeController.dispose();
    _businessController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await _gateway.loadProfile(widget.personalOwnerUid);
      final settings = ContractSettings.fromProfile(profile);
      final party = settings.party ?? ContractSettings.suggestParty(profile);
      if (!mounted) return;
      setState(() {
        _kind = party.kind;
        _nameController.text = party.name;
        _trainerController.text = party.trainerName;
        _phoneController.text = party.phone;
        _placeController.text = party.place;
        _businessController.text = party.businessNo;
        _logoPath = party.logoPath;
        _terms = LessonContractForm.fromDefaults(
          settings.defaults,
          today: DateTime(2000),
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  ContractParty get _party => ContractParty(
    kind: _kind,
    name: _nameController.text,
    trainerName: _trainerController.text,
    phone: _phoneController.text,
    place: _placeController.text,
    businessNo: _businessController.text,
    logoPath: _logoPath,
  );

  void _toast(String message) =>
      AifcInteraction.toast(context: context, message: message);

  Future<void> _save() async {
    if (_saving) return;
    final party = _party;
    final termsErrors = _terms.validateTerms();
    if (party.validate().isNotEmpty || termsErrors.isNotEmpty) {
      setState(() => _showErrors = true);
      _toast(
        termsErrors.isNotEmpty
            ? termsErrors.values.first
            : '빨간 표시가 있는 칸을 확인해 주세요.',
      );
      // 위에서부터 처음 틀린 칸으로 이동하고 커서를 놓는다.
      final partyErrors = party.validate();
      String? firstParty;
      for (final key in const [
        'name',
        'trainerName',
        'phone',
        'place',
        'businessNo',
      ]) {
        if (partyErrors.containsKey(key)) {
          firstParty = key;
          break;
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (firstParty != null) {
          await revealAndFocus(
            anchorContext: _anchors[firstParty]?.currentContext,
            focusNode: _focus[firstParty],
            alignment: 0.1,
          );
        } else {
          _termsKey.currentState?.focusError(termsErrors.keys.first);
        }
      });
      return;
    }
    final defaults = _terms.toDefaults();
    setState(() => _saving = true);
    try {
      await _gateway.saveSettings(party: party, defaults: defaults);
      if (!mounted) return;
      setState(() => _saving = false);
      _toast('계약 설정을 저장했어요.');
      Navigator.of(context).maybePop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _toast(contractErrorMessage(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth >= 600
                ? kLessonContractSettingsMaxWidth
                : constraints.maxWidth;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  LessonContractHeader(
                    title: '계약 설정',
                    backKey: const ValueKey<String>('contract_settings_back'),
                    onBack: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(child: _buildBody(context)),
                ],
              ),
            ),
          ),
        );
      },
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
              const Text('설정을 불러오지 못했어요.'),
              const SizedBox(height: 12),
              FilledButton(
                key: const ValueKey<String>('contract_settings_retry'),
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
    final errors = _showErrors ? _party.validate() : const <String, String>{};
    final termsErrors =
        _showErrors ? _terms.validateTerms() : const <String, String>{};
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
          LessonContractSectionCard(
            title: '계약 당사자',
            subtitle: '계약서 맨 위에 표시됩니다. 계약 시작 시점의 값이 계약서에 복사됩니다.',
            child: _buildParty(errors),
          ),
          const SizedBox(height: 14),
          LessonContractSectionCard(
            title: '내 기본 조건',
            subtitle: '새 계약을 시작할 때 조항의 빈칸이 이 값으로 채워집니다. 계약마다 바꿀 수 있습니다.',
            child: LessonContractTermsSection(
              key: _termsKey,
              form: _terms,
              errors: termsErrors,
              keyPrefix: 'contract',
              perContract: false,
              onChanged: (next) => setState(() => _terms = next),
            ),
          ),
          const SizedBox(height: 14),
          const _FixedTermsCard(),
          const SizedBox(height: 18),
          FilledButton(
            key: const ValueKey<String>('contract_settings_save'),
            onPressed: _saving ? null : _save,
            child:
                _saving
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('저장'),
          ),
        ],
      ),
    );
  }

  Widget _buildParty(Map<String, String> errors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<ContractPartyKind>(
          key: const ValueKey<String>('contract_party_kind'),
          initialValue: _kind,
          decoration: const InputDecoration(labelText: '당사자 구분', isDense: true),
          items: const [
            DropdownMenuItem(
              value: ContractPartyKind.individual,
              child: Text('강사 개인'),
            ),
            DropdownMenuItem(
              value: ContractPartyKind.center,
              child: Text('센터'),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _kind = value);
          },
        ),
        const SizedBox(height: 12),
        _field(
          'contract_party_name',
          _nameController,
          _kind == ContractPartyKind.center ? '센터 이름' : '표시할 이름',
          errors['name'],
          errorKey: 'name',
          maxLength: 40,
        ),
        _field(
          'contract_party_trainer',
          _trainerController,
          '담당 강사 이름',
          errors['trainerName'],
          errorKey: 'trainerName',
          maxLength: 20,
        ),
        _field(
          'contract_party_phone',
          _phoneController,
          '연락처',
          errors['phone'],
          errorKey: 'phone',
          keyboard: TextInputType.phone,
          maxLength: 20,
        ),
        _field(
          'contract_party_place',
          _placeController,
          '수업 장소',
          errors['place'],
          errorKey: 'place',
          maxLength: 100,
        ),
        _field(
          'contract_party_business',
          _businessController,
          '사업자등록번호 (선택)',
          errors['businessNo'],
          errorKey: 'businessNo',
          keyboard: TextInputType.number,
          maxLength: 12,
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
  }) {
    return Padding(
      key: _anchor(errorKey),
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        key: ValueKey<String>(key),
        controller: controller,
        focusNode: _focusFor(errorKey),
        keyboardType: keyboard,
        maxLength: maxLength,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          errorText: error,
          counterText: '',
          isDense: true,
        ),
      ),
    );
  }
}

class _FixedTermsCard extends StatelessWidget {
  const _FixedTermsCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey<String>('contract_fixed_terms'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '계약마다 바꿀 수 없는 기준',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            '· 취소 가능 시간이 지난 후의 취소와 불참은 레슨 1회가 차감됩니다.\n'
            '· 강사 사정으로 취소되거나 지연된 레슨은 차감하지 않고 보강합니다.\n'
            '· 유효기간 종료일이 지나면 남은 횟수는 소멸합니다.',
            style: TextStyle(height: 1.6),
          ),
        ],
      ),
    );
  }
}
