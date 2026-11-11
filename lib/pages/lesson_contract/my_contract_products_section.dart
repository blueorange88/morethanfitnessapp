import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/lesson_contract/contract_product_input.dart';
import '../../models/lesson_contract/lesson_contract_settings.dart';
import '../../services/personal_contract_gateway.dart';
import '../../utils/lesson_contract/lesson_contract_rules.dart';
import '../../utils/lesson_contract/won_input_formatter.dart';
import '../../widgets/aifc_interaction.dart';

/// 마이페이지의 `내 수업 상품`. 레슨계약서를 쓸 때 불러오는 상품(이름·횟수·1회 시간·금액)을
/// 미리 만들어 두고 고치고 지운다. 계약서 입력 화면의 `내 수업 상품으로 저장`과 같은 목록(프로필
/// `contractProducts`)을 쓴다.
class MyContractProductsSection extends StatefulWidget {
  const MyContractProductsSection({
    super.key,
    required this.personalOwnerUid,
    this.gateway,
  });

  final String personalOwnerUid;
  final PersonalContractGateway? gateway;

  @override
  State<MyContractProductsSection> createState() =>
      _MyContractProductsSectionState();
}

class _MyContractProductsSectionState extends State<MyContractProductsSection> {
  late final PersonalContractGateway _gateway =
      widget.gateway ?? PersonalContractGateway();

  List<ContractProductPreset> _products = const [];
  bool _loading = true;
  bool _loadFailed = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final settings = await _gateway.loadSettings(widget.personalOwnerUid);
      if (!mounted) return;
      setState(() {
        _products = settings.products;
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

  void _toast(String message) =>
      AifcInteraction.toast(context: context, message: message);

  /// 목록 전체를 서버에 저장한다. 성공하면 true.
  Future<bool> _persist(List<ContractProductPreset> next) async {
    if (_saving) return false;
    setState(() => _saving = true);
    try {
      await _gateway.saveSettings(products: next);
      if (!mounted) return false;
      setState(() {
        _products = next;
        _saving = false;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() => _saving = false);
      _toast(contractErrorMessage(error));
      return false;
    }
  }

  Future<void> _openEditor({ContractProductPreset? editing, int? index}) async {
    final others = [
      for (var i = 0; i < _products.length; i++)
        if (i != index) _products[i].name,
    ];
    final result = await showModalBottomSheet<ContractProductPreset>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ProductEditorSheet(editing: editing, otherNames: others),
    );
    if (result == null || !mounted) return;
    final next = [..._products];
    if (index == null) {
      next.add(result);
    } else {
      next[index] = result;
    }
    if (await _persist(next) && mounted) {
      _toast(index == null ? '내 수업 상품을 추가했어요.' : '내 수업 상품을 고쳤어요.');
    }
  }

  Future<void> _confirmDelete(int index) async {
    final product = _products[index];
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('상품을 삭제할까요?'),
            content: Text(
              "'${product.name}' 상품이 내 수업 상품에서 사라져요.\n이미 작성한 계약서에는 영향이 없어요.",
            ),
            actions: [
              TextButton(
                key: const Key('my_product_delete_cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                key: const Key('my_product_delete_confirm'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  '삭제',
                  style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
    );
    if (ok != true || !mounted) return;
    final next = [..._products]..removeAt(index);
    if (await _persist(next) && mounted) {
      _toast('내 수업 상품에서 삭제했어요.');
    }
  }

  String _summary(ContractProductPreset product) {
    final unit = contractUnitPrice(product.paidAmount, product.sessionCount);
    final base =
        '총 ${product.sessionCount}회 · 1회 ${product.sessionMinutes}분 · '
        '${formatWon(product.paidAmount)}원 (회당 ${formatWon(unit)}원)';
    final list = product.listPrice;
    return list == null ? base : '$base\n정상가 ${formatWon(list)}원';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (_loadFailed) {
      body = Row(
        children: [
          Expanded(
            child: Text(
              '내 수업 상품을 불러오지 못했어요.',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
          TextButton(
            key: const Key('my_products_retry'),
            onPressed: _load,
            child: const Text('다시 불러오기'),
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_products.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '저장된 수업 상품이 없어요.\n상품을 추가해 두면 레슨계약서를 쓸 때 상품명·횟수·금액을 바로 불러올 수 있어요.',
                key: const Key('my_products_empty'),
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
              ),
            ),
          for (var i = 0; i < _products.length; i++)
            Container(
              key: Key('my_product_$i'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _products[i].name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _summary(_products[i]),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: Key('my_product_edit_$i'),
                    tooltip: '수정',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    onPressed:
                        _saving
                            ? null
                            : () =>
                                _openEditor(editing: _products[i], index: i),
                  ),
                  IconButton(
                    key: Key('my_product_delete_$i'),
                    tooltip: '삭제',
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    onPressed: _saving ? null : () => _confirmDelete(i),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            key: const Key('my_product_add'),
            onPressed:
                _saving || _products.length >= kContractProductMaxCount
                    ? null
                    : () => _openEditor(),
            icon: const Icon(Icons.add_rounded),
            label: Text(
              _products.length >= kContractProductMaxCount
                  ? '최대 $kContractProductMaxCount개까지 저장할 수 있어요'
                  : '상품 추가',
            ),
          ),
        ],
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 160),
      alignment: Alignment.topCenter,
      child: body,
    );
  }
}

/// 상품 추가·수정 시트.
class _ProductEditorSheet extends StatefulWidget {
  const _ProductEditorSheet({required this.editing, required this.otherNames});

  final ContractProductPreset? editing;
  final List<String> otherNames;

  @override
  State<_ProductEditorSheet> createState() => _ProductEditorSheetState();
}

class _ProductEditorSheetState extends State<_ProductEditorSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.editing?.name ?? '',
  );
  late final TextEditingController _count = TextEditingController(
    text: '${widget.editing?.sessionCount ?? ''}',
  );
  late final TextEditingController _minutes = TextEditingController(
    text: '${widget.editing?.sessionMinutes ?? 50}',
  );
  late final TextEditingController _paid = TextEditingController(
    text: widget.editing == null ? '' : formatWon(widget.editing!.paidAmount),
  );
  late final TextEditingController _list = TextEditingController(
    text:
        widget.editing?.listPrice == null
            ? ''
            : formatWon(widget.editing!.listPrice!),
  );

  final Map<String, FocusNode> _focus = {
    for (final key in const [
      'name',
      'sessionCount',
      'sessionMinutes',
      'paidAmount',
      'listPrice',
    ])
      key: FocusNode(),
  };

  Map<String, String> _errors = const {};

  @override
  void dispose() {
    for (final controller in [_name, _count, _minutes, _paid, _list]) {
      controller.dispose();
    }
    for (final node in _focus.values) {
      node.dispose();
    }
    super.dispose();
  }

  int? _int(TextEditingController controller) =>
      int.tryParse(controller.text.trim());

  void _save() {
    final listText = _list.text.trim();
    final listPrice = listText.isEmpty ? null : parseWon(listText);
    final errors = validateContractProductInput(
      name: _name.text,
      sessionCount: _int(_count),
      sessionMinutes: _int(_minutes),
      paidAmount: parseWon(_paid.text),
      listPrice: listText.isEmpty ? null : (listPrice ?? 0),
      otherNames: widget.otherNames,
    );
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      // 처음 틀린 칸에 커서를 놓는다.
      for (final key in const [
        'name',
        'sessionCount',
        'sessionMinutes',
        'paidAmount',
        'listPrice',
      ]) {
        if (errors.containsKey(key)) {
          _focus[key]!.requestFocus();
          break;
        }
      }
      return;
    }
    Navigator.of(context).pop(
      buildContractProductPreset(
        name: _name.text,
        sessionCount: _int(_count)!,
        sessionMinutes: _int(_minutes)!,
        paidAmount: parseWon(_paid.text)!,
        listPrice: listText.isEmpty ? null : listPrice,
      ),
    );
  }

  Widget _field(
    String key,
    TextEditingController controller,
    String label, {
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    int? maxLength,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: Key('my_product_field_$key'),
        controller: controller,
        focusNode: _focus[key],
        keyboardType: keyboard,
        inputFormatters: formatters,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          errorText: _errors[key],
          counterText: '',
          isDense: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + bottomInset),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.editing == null ? '수업 상품 추가' : '수업 상품 수정',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              _field('name', _name, '상품 이름', maxLength: 40, hint: '예: PT 10회'),
              Row(
                children: [
                  Expanded(
                    child: _field(
                      'sessionCount',
                      _count,
                      '총 횟수(회)',
                      keyboard: TextInputType.number,
                      maxLength: 3,
                      formatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      'sessionMinutes',
                      _minutes,
                      '1회 시간(분)',
                      keyboard: TextInputType.number,
                      maxLength: 3,
                      formatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),
              _field(
                'paidAmount',
                _paid,
                '결제금액(원)',
                keyboard: TextInputType.number,
                maxLength: 11,
                formatters: const [WonInputFormatter()],
              ),
              _field(
                'listPrice',
                _list,
                '정상가(원, 선택)',
                keyboard: TextInputType.number,
                maxLength: 13,
                formatters: const [WonInputFormatter()],
                hint: '할인 상품일 때만 입력해요',
              ),
              const SizedBox(height: 4),
              FilledButton(
                key: const Key('my_product_save'),
                onPressed: _save,
                child: const Text('저장'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
