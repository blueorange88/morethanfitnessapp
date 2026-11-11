import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/lesson_contract_delivery_service.dart';
import '../../services/personal_contract_gateway.dart';
import '../../utils/lesson_contract/lesson_contract_pdf.dart';
import '../../utils/lesson_contract/signature_strokes.dart';
import '../../widgets/aifc_interaction.dart';
import 'lesson_contract_widgets.dart';

/// 서명 이벤트에서 서명 획을 불러오는 단계 이름 순서.
const List<String> kDeliverySteps = ['disclosure', 'member', 'trainer'];

enum _Phase { preparing, ready, issued, failed }

String _kstDate(DateTime time) {
  final kst = time.toUtc().add(const Duration(hours: 9));
  String two(int value) => value.toString().padLeft(2, '0');
  return '${kst.year}-${two(kst.month)}-${two(kst.day)}';
}

/// 완료된 레슨계약서를 회원에게 보내는 카드: PDF 만들기 → 올리기 → 열람 링크 → 문자·카톡 공유.
///
/// - 링크가 아직 없는 완료 계약은 열자마자 PDF를 만들고 링크를 발급한다.
/// - 이전에 링크를 만든 계약은 자동으로 새 링크를 만들지 않는다(이전 링크가 무효가 되므로).
///   보낸 횟수·열람 현황을 보여 주고 \`새 링크 만들어 보내기\`를 확인한 뒤에만 다시 발급한다.
class ContractDeliveryCard extends StatefulWidget {
  const ContractDeliveryCard({
    super.key,
    required this.contractId,
    required this.contract,
    required this.gateway,
    this.buildPdf,
    this.share,
    this.copyText,
    this.savePdf,
  });

  final String contractId;
  final Map<String, dynamic> contract;
  final PersonalContractGateway gateway;

  /// PDF를 만드는 함수(테스트용 교체). 기본은 글꼴을 받아 계약 문서로 만든다.
  final Future<Uint8List> Function(
    Map<String, dynamic> contract,
    Map<String, Strokes> strokes,
  )?
  buildPdf;

  /// 공유 시트를 여는 함수(테스트용 교체). 실제로 보냈으면 true, 닫기만 했으면 false.
  final Future<bool> Function(String text)? share;

  /// 클립보드에 복사하는 함수(테스트용 교체).
  final Future<void> Function(String text)? copyText;

  /// 만든 PDF 파일을 폰에 저장·공유하는 함수(테스트용 교체). 기본은 임시 파일로 쓴 뒤 공유 시트를 연다.
  final Future<void> Function(Uint8List bytes, String fileName)? savePdf;

  @override
  State<ContractDeliveryCard> createState() => _ContractDeliveryCardState();
}

class _ContractDeliveryCardState extends State<ContractDeliveryCard> {
  late final ContractDeliveryService _service = ContractDeliveryService(
    widget.gateway,
  );

  _Phase _phase = _Phase.preparing;
  ContractDeliveryInfo? _info;
  String _error = '';
  bool _busy = false;
  bool _saving = false;

  Map<String, dynamic> get _delivery =>
      widget.contract['delivery'] is Map
          ? Map<String, dynamic>.from(widget.contract['delivery'] as Map)
          : <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    final hasLink = (_delivery['linkTokenHash'] ?? '').toString().isNotEmpty;
    if (hasLink) {
      _phase = _Phase.issued;
    } else {
      _prepare();
    }
  }

  void _toast(String message) =>
      AifcInteraction.toast(context: context, message: message);

  Future<Map<String, Strokes>> _loadAllStrokes() async {
    final signatures =
        widget.contract['signatures'] is Map
            ? Map<String, dynamic>.from(widget.contract['signatures'] as Map)
            : <String, dynamic>{};
    final result = <String, Strokes>{};
    for (final step in kDeliverySteps) {
      final entry = signatures[step];
      final eventId = entry is Map ? (entry['eventId'] ?? '').toString() : '';
      final strokes = await widget.gateway.loadSignatureStrokes(
        widget.contractId,
        eventId,
      );
      // 서명 그림이 빠진 PDF는 증빙으로 쓸 수 없으므로 만들지 않는다.
      if (strokes.isEmpty) throw StateError('signature_missing');
      result[step] = strokes;
    }
    return result;
  }

  Future<Uint8List> _defaultBuild(
    Map<String, dynamic> contract,
    Map<String, Strokes> strokes,
  ) async {
    final fonts = await loadContractPdfFonts();
    return buildContractPdfFromRecord(
      contractId: widget.contractId,
      contract: contract,
      strokes: strokes,
      fonts: fonts,
    );
  }

  /// PDF를 만들어 올리고 서버에 등록한 뒤 열람 링크를 새로 발급한다.
  Future<void> _prepare() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _phase = _Phase.preparing;
      _error = '';
    });
    try {
      final strokes = await _loadAllStrokes();
      final info = await _service.prepare(
        contractId: widget.contractId,
        trainerUid: (widget.contract['trainerId'] ?? '').toString(),
        version: (widget.contract['version'] as num?)?.toInt() ?? 1,
        buildPdf:
            () => (widget.buildPdf ?? _defaultBuild)(widget.contract, strokes),
      );
      if (!mounted) return;
      setState(() {
        _info = info;
        _phase = info.viewUrl == null ? _Phase.failed : _Phase.ready;
        if (info.viewUrl == null) _error = '열람 링크를 만들지 못했어요.';
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.failed;
        _error =
            error is StateError && error.message == 'signature_missing'
                ? '서명 정보를 불러오지 못해 계약서를 만들 수 없어요. 네트워크를 확인하고 다시 시도해 주세요.'
                : contractErrorMessage(error);
        _busy = false;
      });
    }
  }

  String _shareText(ContractDeliveryInfo info) {
    final party = widget.contract['party'];
    final name = party is Map ? (party['name'] ?? '').toString().trim() : '';
    final no = (widget.contract['contractNo'] ?? '').toString();
    final version = (widget.contract['version'] as num?)?.toInt() ?? 1;
    final contractNo = version > 1 ? '$no-v$version' : no;
    final expires = info.linkExpiresAt;
    return [
      '${name.isEmpty ? '' : '$name '}레슨 계약서가 완료됐어요.',
      '계약번호 $contractNo',
      '아래 링크에서 계약서(PDF)를 확인하실 수 있어요.'
          '${expires == null ? '' : ' (${_kstDate(expires)}까지)'}',
      info.viewUrl ?? '',
    ].join('\n');
  }

  String _pdfFileName() {
    final no = (widget.contract['contractNo'] ?? '').toString().trim();
    final version = (widget.contract['version'] as num?)?.toInt() ?? 1;
    final contractNo = version > 1 ? '$no-v$version' : no;
    final safe = contractNo.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
    return safe.isEmpty ? '레슨계약서.pdf' : '레슨계약서_$safe.pdf';
  }

  /// 폰에 PDF 파일로 저장하거나 다른 앱으로 보낼 수 있게 공유 시트를 연다(서버 등록·링크와 무관).
  Future<void> _defaultSavePdf(Uint8List bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        fileNameOverrides: [fileName],
        subject: fileName,
      ),
    );
  }

  Future<void> _savePdf() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final strokes = await _loadAllStrokes();
      final bytes = await (widget.buildPdf ?? _defaultBuild)(
        widget.contract,
        strokes,
      );
      await (widget.savePdf ?? _defaultSavePdf)(bytes, _pdfFileName());
    } catch (error) {
      if (mounted) {
        _toast(
          error is StateError && error.message == 'signature_missing'
              ? '서명 정보를 불러오지 못해 PDF를 만들 수 없어요. 네트워크를 확인하고 다시 시도해 주세요.'
              : 'PDF를 만들지 못했어요. 다시 시도해 주세요.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _saveButton() => OutlinedButton.icon(
    key: const ValueKey<String>('done_save_pdf'),
    onPressed: _saving ? null : _savePdf,
    icon:
        _saving
            ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
            : const Icon(Icons.download_rounded),
    label: Text(_saving ? 'PDF 만드는 중…' : 'PDF로 저장·공유'),
  );

  Future<bool> _defaultShare(String text) async {
    final result = await SharePlus.instance.share(ShareParams(text: text));
    return result.status != ShareResultStatus.dismissed;
  }

  Future<void> _markShared(String channel) async {
    try {
      await widget.gateway.markShared(widget.contractId, channel: channel);
    } catch (_) {
      // 보낸 기록을 못 남겨도 회원에게는 이미 전달됐으므로 화면은 그대로 둔다.
    }
  }

  Future<void> _share() async {
    final info = _info;
    if (info?.viewUrl == null) return;
    final sent = await (widget.share ?? _defaultShare)(_shareText(info!));
    if (sent) await _markShared('share_sheet');
  }

  Future<void> _copy() async {
    final url = _info?.viewUrl;
    if (url == null) return;
    await (widget.copyText ??
        (text) => Clipboard.setData(ClipboardData(text: text)))(url);
    if (!mounted) return;
    _toast('열람 링크를 복사했어요.');
    await _markShared('copy_link');
  }

  Future<void> _confirmReissue() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('새 링크를 만들까요?'),
            content: const Text('새 링크를 만들면 이전에 보낸 링크는 열리지 않아요.'),
            actions: [
              TextButton(
                key: const ValueKey<String>('delivery_reissue_cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                key: const ValueKey<String>('delivery_reissue_confirm'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('새 링크 만들기'),
              ),
            ],
          ),
    );
    if (ok == true && mounted) await _prepare();
  }

  String _issuedSummary() {
    final delivery = _delivery;
    final shared = (delivery['shareCount'] as num?)?.toInt() ?? 0;
    final viewed = (delivery['viewCount'] as num?)?.toInt() ?? 0;
    final first = delivery['firstViewedAt'];
    final firstText =
        first is Timestamp ? ' · 처음 연 날짜 ${_kstDate(first.toDate())}' : '';
    return '열람 링크를 이미 만들었어요.\n보낸 기록 $shared회 · 회원이 연 횟수 $viewed회$firstText';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final Widget body;
    switch (_phase) {
      case _Phase.preparing:
        body = Column(
          key: const ValueKey<String>('done_delivery_preparing'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
            Text('계약서 PDF를 만들고 있어요…', style: theme.textTheme.bodyMedium),
          ],
        );
      case _Phase.failed:
        body = Column(
          key: const ValueKey<String>('done_delivery_failed'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_error, style: TextStyle(color: scheme.error)),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              key: const ValueKey<String>('done_delivery_retry'),
              onPressed: _busy ? null : _prepare,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('다시 시도'),
            ),
          ],
        );
      case _Phase.issued:
        body = Column(
          key: const ValueKey<String>('done_delivery_issued'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_issuedSummary(), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(
              '보안을 위해 이전 링크 주소는 다시 볼 수 없어요. 다시 보내려면 새 링크를 만들어 주세요.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            _saveButton(),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey<String>('done_new_link'),
              onPressed: _busy ? null : _confirmReissue,
              icon: const Icon(Icons.link_rounded),
              label: const Text('새 링크 만들어 보내기'),
            ),
          ],
        );
      case _Phase.ready:
        final expires = _info?.linkExpiresAt;
        body = Column(
          key: const ValueKey<String>('done_delivery_ready'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '열람 링크를 만들었어요.'
              '${expires == null ? '' : ' ${_kstDate(expires)}까지 열 수 있어요.'}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '회원이 링크를 열면 열람 기록이 남아요.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const ValueKey<String>('done_share'),
              onPressed: _share,
              icon: const Icon(Icons.send_rounded),
              label: const Text('문자·카톡으로 보내기'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey<String>('done_copy_link'),
              onPressed: _copy,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('링크 복사'),
            ),
            const SizedBox(height: 8),
            _saveButton(),
          ],
        );
    }
    return LessonContractSectionCard(
      title: '회원에게 계약서 보내기',
      subtitle: '',
      child: AnimatedSize(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.topCenter,
        child: body,
      ),
    );
  }
}
