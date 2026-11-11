import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/lesson_contract/lesson_contract_form.dart';
import '../../models/lesson_contract/lesson_contract_settings.dart';
import '../../services/lesson_contract_delivery_service.dart';
import '../../services/personal_contract_gateway.dart';
import '../../utils/lesson_contract/lesson_contract_document.dart';
import '../../utils/lesson_contract/lesson_contract_pdf.dart';
import '../../utils/lesson_contract/lesson_contract_rules.dart';
import '../../utils/lesson_contract/signature_strokes.dart';
import '../../widgets/aifc_confirm_chat_sheet.dart';
import '../../widgets/aifc_interaction.dart';
import '../../widgets/contract_signature_pad.dart';
import '../../widgets/mtf_floating_more_menu.dart';
import 'lesson_contract_delivery_card.dart';
import 'lesson_contract_preview_page.dart';
import 'lesson_contract_terminate_sheet.dart';
import 'lesson_contract_void_sheet.dart';
import 'lesson_contract_widgets.dart';

const double kLessonContractSignMaxWidth = 480;

/// 서명을 마치고 `닫기`로 나갈 때 띄우는 안내.
const String kContractSavedAfterSignToast =
    '계약서 저장이 완료되었습니다.\n확인 및 전송은 계약서관리 페이지에서 가능합니다.';

/// 서명이 거듭 너무 다르게 나올 때, 이 횟수째 시도부터 강사 확인으로 진행할 수 있다.
const int _kMismatchBeforeOverride = 3;

/// 서명 단계 이름(서버 `signPersonalContract`의 `step`).
const String kStepDisclosure = 'disclosure';
const String kStepMember = 'member';
const String kStepTrainer = 'trainer';

/// 해지할 때 선택으로 받은 회원 서명(서버 `signatures.terminate`).
const String kStepTerminate = 'terminate';

enum _Stage {
  loading,
  failed,
  handoffToMember,
  disclosure,
  terms,
  handoffToTrainer,
  trainer,
  done,
  locked,
}

DateTime? _toDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

String _two(int value) => value.toString().padLeft(2, '0');

String formatSignedAt(DateTime? date) =>
    date == null
        ? '-'
        : '${date.year}-${_two(date.month)}-${_two(date.day)} '
            '${_two(date.hour)}:${_two(date.minute)}';

/// 레슨계약서 서명 흐름: 폰을 회원에게 건네 핵심 고지 확인(서명 ①) → 나머지 조항 동의(서명 ②)
/// → 폰을 강사에게 돌려 강사 서명 → 완료. 단계와 내용 해시는 서버가 검증하고, 어디까지
/// 했는지는 서버의 계약 상태가 기준이라 앱이 꺼져도 이어서 진행할 수 있다.
class LessonContractSignFlowPage extends StatefulWidget {
  const LessonContractSignFlowPage({
    super.key,
    required this.contractId,
    this.gateway,
    this.capture,
    this.buildPdf,
    this.share,
    this.copyText,
  });

  final String contractId;
  final PersonalContractGateway? gateway;

  /// 완료 화면의 PDF 만들기·공유·복사 동작(테스트용 교체). 기본은 실제 PDF 생성과 공유 시트.
  final Future<Uint8List> Function(
    Map<String, dynamic> contract,
    Map<String, Strokes> strokes,
  )?
  buildPdf;
  final Future<bool> Function(String text)? share;
  final Future<void> Function(String text)? copyText;

  /// 서명판을 띄우는 함수(테스트용 교체). 기본은 손가락 서명판.
  final ContractSignatureCapture? capture;

  @override
  State<LessonContractSignFlowPage> createState() =>
      _LessonContractSignFlowPageState();
}

class _LessonContractSignFlowPageState
    extends State<LessonContractSignFlowPage> {
  late final PersonalContractGateway _gateway =
      widget.gateway ?? PersonalContractGateway();

  _Stage _stage = _Stage.loading;
  Map<String, dynamic> _contract = const {};
  LessonContractForm _form = const LessonContractForm();
  ContractParty? _party;
  List<ContractDisclosureCard> _cards = const [];
  final Set<String> _checked = {};
  bool _termsChecked = false;
  bool _privacyChecked = false;
  bool _trainerConfirmed = false;
  bool _busy = false;
  bool _autoOpened = false;

  /// 이 화면에서 강사 서명까지 마쳐 계약이 완료됐는지(이미 완료된 계약서를 열어 본 경우는 false).
  bool _completedHere = false;

  /// 서명 ②가 서명 ①과 너무 달라 거절된 횟수(맞거나 확인하고 진행하면 0으로 돌아간다).
  int _signatureMismatches = 0;
  final Map<String, Strokes> _signatureStrokes = {};

  String get _status => (_contract['status'] ?? '').toString();
  bool get _terminated => _status == 'terminated';
  String get _hash => (_contract['contentHash'] ?? '').toString();

  String get _contractNo {
    final no = (_contract['contractNo'] ?? '').toString();
    final version = (_contract['version'] as num?)?.toInt() ?? 1;
    return version > 1 ? '$no-v$version' : no;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _toast(String message) =>
      AifcInteraction.toast(context: context, message: message);

  Future<void> _load({_Stage? forceStage}) async {
    try {
      final data = await _gateway.loadContract(widget.contractId);
      if (data == null) throw StateError('contract_not_found');
      final party = ContractParty.fromMap(
        data['party'] is Map
            ? Map<String, dynamic>.from(data['party'] as Map)
            : <String, dynamic>{},
      );
      final form = LessonContractForm.fromContract(data);
      if (!mounted) return;
      setState(() {
        _contract = data;
        _party = party;
        _form = form;
        _cards = buildDisclosureCards(form, party);
        _stage = forceStage ?? _stageFor((data['status'] ?? '').toString());
      });
      await _loadSignatures();
    } catch (_) {
      if (!mounted) return;
      setState(() => _stage = _Stage.failed);
    }
  }

  _Stage _stageFor(String status) {
    switch (status) {
      case 'draft':
      case 'disclosed':
        return _Stage.handoffToMember;
      case 'member_signed':
        return _Stage.trainer;
      case 'completed':
      case 'terminated':
        return _Stage.done;
      default:
        return _Stage.locked;
    }
  }

  /// 받은 서명 획을 읽어 요약·완료 화면과 미리보기에 쓴다(읽지 못해도 진행에는 영향 없음).
  Future<void> _loadSignatures() async {
    final signatures =
        _contract['signatures'] is Map
            ? Map<String, dynamic>.from(_contract['signatures'] as Map)
            : <String, dynamic>{};
    for (final step in const [
      kStepDisclosure,
      kStepMember,
      kStepTrainer,
      kStepTerminate,
    ]) {
      final entry = signatures[step];
      final eventId = entry is Map ? (entry['eventId'] ?? '').toString() : '';
      if (eventId.isEmpty || _signatureStrokes.containsKey(step)) continue;
      try {
        final strokes = await _gateway.loadSignatureStrokes(
          widget.contractId,
          eventId,
        );
        if (strokes.isNotEmpty && mounted) {
          setState(() => _signatureStrokes[step] = strokes);
        }
      } catch (_) {
        // 서명 그림을 못 읽어도 계약 진행은 계속한다.
      }
    }
  }

  DateTime? _signedAt(String step) {
    final signatures = _contract['signatures'];
    final entry = signatures is Map ? signatures[step] : null;
    return entry is Map ? _toDate(entry['signedAt']) : null;
  }

  // ---- 서명 ----
  Future<void> _sign({
    required String step,
    required List<String> items,
    required String padTitle,
    required _Stage next,
  }) async {
    if (_busy) return;
    final capture = widget.capture ?? showContractSignaturePad;
    final strokes = await capture(context, title: padTitle);
    if (strokes == null || !mounted) return;
    // 서명 ②는 서명 ①과 비교해, 많이 다르면 같은 회원이 쓴 서명인지 확인을 받는다.
    if (step == kStepMember && !await _confirmSimilarSignature(strokes)) return;
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await _gateway.signContract(
        contractId: widget.contractId,
        step: step,
        contentHash: _hash,
        checkedItems: items,
        strokes: strokes,
      );
      _signatureStrokes[step] = strokes;
      _autoOpened = false;
      if (next == _Stage.done) _completedHere = true;
      await _load(forceStage: next);
    } catch (error) {
      if (!mounted) return;
      _toast(contractErrorMessage(error));
      // 내용이 바뀌었거나 서명 순서가 어긋난 경우에만 서버 상태를 다시 읽어 맞춘다.
      // 네트워크 오류 같은 일시적 실패에는 지금 화면과 체크를 그대로 둔다.
      final code = contractErrorCode(error);
      if (code == 'content_changed' || code == 'invalid_state') {
        _checked.clear();
        _termsChecked = false;
        _privacyChecked = false;
        await _load();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 서명을 계약서에 남은 회원 서명과 비교해 판정한다(기본: 서명 ②를 서명 ①과). 계속하면 true, 다시 서명이면 false.
  /// - 비슷하면(같은 서명) 바로 통과한다.
  /// - 애매하면 확인창을 띄운다(`그대로 사용`을 고를 수 있다).
  /// - 너무 다르면 그대로 쓸 수 없고 다시 서명해야 한다. 같은 서명이 거듭 맞지 않으면
  ///   [_kMismatchBeforeOverride]번째 시도부터 강사가 직접 본인 서명임을 확인하고 진행할 수 있다.
  /// 서명 ①을 비교할 수 없으면(읽어 오지 못함) 묻지 않고 진행한다.
  Future<bool> _confirmSimilarSignature(
    Strokes current, {
    List<Strokes?>? references,
    String refLabel = '서명 ①',
  }) async {
    // 기준 서명이 여럿이면(파기: 서명 ①·②) 가장 비슷한 것과의 유사도로 판정한다.
    final candidates = [
      for (final reference
          in references ?? <Strokes?>[_signatureStrokes[kStepDisclosure]])
        if (reference != null && reference.isNotEmpty) reference,
    ];
    if (candidates.isEmpty) return true;
    final similarity = candidates
        .map((reference) => signatureSimilarity(reference, current))
        .reduce((a, b) => a > b ? a : b);
    final percent = (similarity * 100).round();
    switch (signatureMatchLevel(similarity)) {
      case SignatureMatch.same:
        _signatureMismatches = 0;
        return true;
      case SignatureMatch.uncertain:
        final keep = await AifcConfirmChatSheet.show(
          context: context,
          title: '회원 서명을 확인하시겠습니까?',
          message:
              '이번 서명이 $refLabel과 다소 다르게 감지되었습니다.\n'
              '동일한 회원의 서명이 맞는지 확인 후 진행해주세요.\n\n'
              '서명 유사도: $percent%',
          cancelText: '다시 서명',
          confirmText: '그대로 사용',
          userCancelText: '다시 서명하겠습니다',
          userConfirmText: '동일한 서명으로 확인합니다',
          cancelReplyText: '확인했습니다. 다시 서명을 진행해주세요.',
          confirmReplyText: '확인되었습니다. 현재 서명을 계약서에 반영합니다.',
        );
        if (keep) _signatureMismatches = 0;
        return keep;
      case SignatureMatch.different:
        _signatureMismatches += 1;
        final canOverride = _signatureMismatches >= _kMismatchBeforeOverride;
        final override = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder:
              (dialogContext) => AlertDialog(
                key: const ValueKey<String>('signature_mismatch_dialog'),
                title: Text('서명이 $refLabel과 많이 달라요'),
                content: Text(
                  '$refLabel과 같은 방식으로 다시 서명해 주세요.\n\n서명 유사도: $percent%'
                  '${canOverride ? '\n\n계속 맞지 않는다면 강사가 회원 본인 서명임을 직접 확인한 뒤 진행할 수 있어요.' : ''}',
                ),
                actions: [
                  if (canOverride)
                    TextButton(
                      key: const ValueKey<String>(
                        'signature_mismatch_override',
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('본인 서명임을 확인했어요'),
                    ),
                  FilledButton(
                    key: const ValueKey<String>('signature_mismatch_retry'),
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('다시 서명'),
                  ),
                ],
              ),
        );
        if (override == true) {
          _signatureMismatches = 0;
          return true;
        }
        return false;
    }
  }

  List<String> get _requiredChecks => disclosureCheckIds(_cards);

  bool get _allDisclosureChecked => _requiredChecks.every(_checked.contains);

  void _toggleCheck(String id, bool value) {
    setState(() {
      if (value) {
        _checked.add(id);
      } else {
        _checked.remove(id);
        _autoOpened = false;
      }
    });
    // 마지막 항목까지 확인하면 서명판이 자동으로 열린다.
    if (value && _allDisclosureChecked && !_autoOpened) {
      _autoOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _stage == _Stage.disclosure) _signDisclosure();
      });
    }
  }

  Future<void> _signDisclosure() => _sign(
    step: kStepDisclosure,
    items: _requiredChecks,
    padTitle: '서명 ① 핵심 고지 확인',
    next: _Stage.terms,
  );

  Future<void> _signMember() => _sign(
    step: kStepMember,
    items: const ['terms', 'privacy'],
    padTitle: '서명 ② 계약 전체 동의',
    next: _Stage.handoffToTrainer,
  );

  Future<void> _signTrainer() => _sign(
    step: kStepTrainer,
    items: const [],
    padTitle: '강사 서명',
    next: _Stage.done,
  );

  // ---- 미리보기 ----
  ContractDocument get _document => buildLessonContractDocument(
    form: _form,
    party:
        _party ??
        const ContractParty(
          kind: ContractPartyKind.individual,
          name: '',
          trainerName: '',
          phone: '',
          place: '',
        ),
    contractNo: _contractNo,
  );

  bool _voiding = false;

  /// 계약 완료 후 파기할 수 있는 기간(일). 서버와 같은 값이다.
  static const int _voidWindowDays = 3;

  /// 완료된 지 [_voidWindowDays]일 안인지(서버가 최종으로 다시 확인한다).
  bool get _canVoid {
    final completedAt = _toDate(_contract['completedAt']);
    if (completedAt == null) return false;
    return DateTime.now().difference(completedAt) <
        const Duration(days: _voidWindowDays);
  }

  /// 이 계약 뒤에 횟수를 등록한 계약이 있으면 어느 계약 때문에 막히는지 알리는 문구(없으면 null).
  Future<String?> _laterContractNotice() async {
    final later = await _gateway.findLaterRegisteredContract(_contract);
    if (later == null) return null;
    final date = _toDate(later['completedAt']);
    final product = later['product'];
    final name =
        product is Map ? (product['name'] ?? '').toString().trim() : '';
    final label = [
      if (date != null) '${date.year}.${_two(date.month)}.${_two(date.day)}',
      '계약한',
      if (name.isNotEmpty) '[$name]' else '계약',
    ].join(' ');
    return '이 계약 뒤에 등록된 $label이 있어 파기할 수 없어요.\n'
        '뒤에 등록된 계약부터 먼저 처리해 주세요.';
  }

  /// 잘못 써서 완료한 계약서를 파기한다: 사유 선택 → 회원 서명 → 서버 기록(횟수 되돌림·알림 기록).
  Future<void> _startVoid() async {
    if (_voiding) return;
    // 뒤에 등록된 계약이 있으면 서명을 받기 전에 먼저 알린다(서버도 같은 조건으로 막는다).
    if (_contract['registration'] != null) {
      final notice = await _laterContractNotice();
      if (!mounted) return;
      if (notice != null) {
        _toast(notice);
        return;
      }
    }
    final reason = await showContractVoidReasonSheet(
      context,
      sessionCount: _form.sessionCount,
      windowDays: _voidWindowDays,
    );
    if (reason == null || !mounted) return;
    final capture = widget.capture ?? showContractSignaturePad;
    final strokes = await capture(
      context,
      title: '${_form.memberName.isEmpty ? '회원' : _form.memberName}님 파기 확인 서명',
    );
    if (strokes == null || strokes.isEmpty || !mounted) return;
    // 파기 서명도 계약서에 남은 회원 서명(① 핵심 고지, ② 계약 동의)과 비슷한지 확인한다.
    if (!await _confirmSimilarSignature(
      strokes,
      references: [
        _signatureStrokes[kStepDisclosure],
        _signatureStrokes[kStepMember],
      ],
      refLabel: '계약서의 회원 서명',
    )) {
      return;
    }
    if (!mounted) return;
    setState(() => _voiding = true);
    try {
      await _gateway.voidContract(
        widget.contractId,
        reason: reason,
        strokes: strokes,
      );
      if (!mounted) return;
      _toast('계약서를 파기했어요. 등록된 횟수도 되돌렸어요.');
      setState(() => _voiding = false);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _voiding = false);
      // 서버가 "뒤에 등록된 계약이 있음"으로 막았으면 어느 계약인지 함께 알린다.
      final notice =
          contractErrorCode(error) == 'void_not_latest_registration'
              ? await _laterContractNotice()
              : null;
      if (!mounted) return;
      _toast(notice ?? contractErrorMessage(error));
    }
  }

  bool _terminating = false;

  /// 완료된 계약서를 해지한다: 시트(사유·의사표시 방법/날짜·정리 옵션·서명 여부) → (선택) 회원 서명 →
  /// 확인 → 서버 기록. 환불은 다루지 않는다.
  Future<void> _startTerminate() async {
    if (_terminating) return;
    final input = await showContractTerminateSheet(
      context,
      completedAt: _toDate(_contract['completedAt']),
    );
    if (input == null || !mounted) return;
    Strokes? strokes;
    if (input.withSignature) {
      final capture = widget.capture ?? showContractSignaturePad;
      final signed = await capture(
        context,
        title:
            '${_form.memberName.isEmpty ? '회원' : _form.memberName}님 해지 확인 서명',
      );
      if (signed == null || signed.isEmpty || !mounted) return;
      if (!await _confirmSimilarSignature(
        signed,
        references: [
          _signatureStrokes[kStepDisclosure],
          _signatureStrokes[kStepMember],
        ],
        refLabel: '계약서의 회원 서명',
      )) {
        return;
      }
      if (!mounted) return;
      strokes = signed;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            key: const ValueKey<String>('terminate_confirm_dialog'),
            title: const Text('정말 해지할까요?'),
            content: Text(
              strokes == null
                  ? '회원 서명 없이 강사 단독 기록으로 해지해요.\n환불은 앱이 처리하지 않으며, 총·잔여 횟수는 0으로 정리되고 해지는 되돌릴 수 없어요.'
                  : '환불은 앱이 처리하지 않으며, 총·잔여 횟수는 0으로 정리되고 해지는 되돌릴 수 없어요.',
            ),
            actions: [
              TextButton(
                key: const ValueKey<String>('terminate_confirm_cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('취소'),
              ),
              TextButton(
                key: const ValueKey<String>('terminate_confirm_ok'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(
                  '해지하기',
                  style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _terminating = true);
    try {
      final result = await _gateway.terminateContract(
        widget.contractId,
        reasonCode: input.reasonCode,
        reasonNote: input.reasonNote,
        noticeChannel: input.noticeChannel,
        noticeDate: input.noticeDate,
        markExpired: input.markExpired,
        strokes: strokes,
      );
      if (!mounted) return;
      _toast(
        result.alreadyTerminated
            ? '이미 해지된 계약서예요.'
            : result.evidence == 'member_signed'
            ? '계약서를 해지했어요. (회원 서명 확인)'
            : '계약서를 해지했어요. (강사 단독 기록)',
      );
      setState(() => _terminating = false);
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _terminating = false);
      _toast(contractErrorMessage(error));
    }
  }

  void _openPreview() {
    final completedAt = _toDate(_contract['completedAt']);
    // 서명이 모두 끝난 계약은 문서확인번호·QR까지 들어간 실제 PDF와 같은 모양으로 보여 준다.
    final contentHash = (_contract['contentHash'] ?? '').toString();
    final verified =
        _stage == _Stage.done &&
        contentHash.isNotEmpty &&
        LessonContractPreviewPage.realPdfEnabled;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => LessonContractPreviewPage(
              document: _document,
              signatures: [
                _signatureStrokes[kStepDisclosure],
                _signatureStrokes[kStepMember],
                _signatureStrokes[kStepTrainer],
              ],
              signedDate:
                  completedAt == null
                      ? ''
                      : '${completedAt.year}년 ${completedAt.month}월 ${completedAt.day}일',
              contentHash: verified ? contentHash : '',
              verifyUrl:
                  verified
                      ? contractVerifyUrl(
                        base: defaultContractVerifyBase(),
                        contractId: widget.contractId,
                        contentHash: contentHash,
                      )
                      : '',
              completedAt: completedAt,
              // 해지된 계약은 정상 계약서로 오해하거나 캡처해 쓰지 못하도록 쪽마다 표시한다.
              watermark: _terminated ? '해지 완료' : '',
            ),
      ),
    );
  }

  // ---- 나가기 ----
  Future<void> _leave() async {
    final navigator = Navigator.of(context);
    final inProgress =
        _stage == _Stage.disclosure ||
        _stage == _Stage.terms ||
        _stage == _Stage.trainer;
    if (!inProgress || _busy) {
      navigator.pop(_stage == _Stage.done);
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            key: const ValueKey<String>('sign_leave_dialog'),
            title: const Text('서명 진행을 멈출까요?'),
            content: const Text('지금까지 받은 서명은 유지돼요. 확인 체크는 처음부터 다시 해야 해요.'),
            actions: [
              TextButton(
                key: const ValueKey<String>('sign_leave_stay'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('계속 진행'),
              ),
              TextButton(
                key: const ValueKey<String>('sign_leave_exit'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('나가기'),
              ),
            ],
          ),
    );
    if (leave == true && mounted) navigator.pop(false);
  }

  String get _title {
    switch (_stage) {
      case _Stage.disclosure:
        return '핵심 고지 확인';
      case _Stage.terms:
        return '계약 조건 동의';
      case _Stage.trainer:
        return '강사 확인·서명';
      case _Stage.done:
        return _terminated ? '해지된 계약' : '계약 완료';
      default:
        return '계약서 서명';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: kLessonContractSignMaxWidth,
            ),
            child: Column(
              children: [
                LessonContractHeader(
                  title: _title,
                  backKey: const ValueKey<String>('sign_back'),
                  onBack: _leave,
                  trailing: _buildHeaderMenu(context),
                ),
                if (_stage != _Stage.loading && _stage != _Stage.failed)
                  _StepIndicator(status: _status, stage: _stage),
                Expanded(child: _buildStage(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 완료된 계약서의 머리말 더보기(⋮) 메뉴. 파기(완료 후 3일 안)와 해지(언제든)는 자주 쓰지 않는
  /// 동작이라 화면에 늘어놓지 않고 여기에 둔다. 이미 해지된 계약서에는 메뉴가 없다.
  Widget? _buildHeaderMenu(BuildContext context) {
    if (_stage != _Stage.done || _terminated) return null;
    // 다른 페이지(회원카드·계약서 관리)와 같은 공용 더보기 메뉴. 두 동작 모두 되돌리기 어려워 빨간색으로 둔다.
    return MtfFloatingMoreMenuButton<String>(
      key: const ValueKey<String>('done_more_menu'),
      tooltip: '더보기',
      icon: Icons.more_vert_rounded,
      iconSize: 24,
      cardWidth: 212,
      offset: const Offset(0, 8),
      onSelected: (value) {
        if (_voiding || _terminating) return;
        if (value == 'void') _startVoid();
        if (value == 'terminate') _startTerminate();
      },
      items: [
        if (_canVoid)
          const MtfMoreMenuItem(
            value: 'void',
            icon: Icons.block_rounded,
            label: '계약 파기',
            subLabel: '완료 후 $_voidWindowDays일 이내',
            isDanger: true,
          ),
        const MtfMoreMenuItem(
          value: 'terminate',
          icon: Icons.event_busy_rounded,
          label: '계약 해지',
          subLabel: '언제든 가능',
          isDanger: true,
        ),
      ],
    );
  }

  Widget _buildStage(BuildContext context) {
    switch (_stage) {
      case _Stage.loading:
        return const Center(child: CircularProgressIndicator());
      case _Stage.failed:
        return _Message(
          text: '계약서를 불러오지 못했어요.',
          buttonKey: const ValueKey<String>('sign_retry'),
          buttonLabel: '다시 불러오기',
          onPressed: () {
            setState(() => _stage = _Stage.loading);
            _load();
          },
        );
      case _Stage.locked:
        return _Message(
          key: const ValueKey<String>('sign_locked'),
          text: switch ((_contract['status'] ?? '').toString()) {
            'voided' => '파기된 계약서입니다.\n작성하신 계약서의 효력 및 등록한 레슨은\n무효로 처리되었습니다.',
            'cancelled' => '취소된 계약서예요.',
            'superseded' => '새 버전으로 대체된 이전 버전 계약서예요.',
            _ => '취소되었거나 새 버전으로 대체된 계약서라 서명할 수 없어요.',
          },
          buttonKey: const ValueKey<String>('sign_locked_close'),
          buttonLabel: '닫기',
          onPressed: () => Navigator.of(context).pop(false),
        );
      case _Stage.handoffToMember:
        return _Handoff(
          key: const ValueKey<String>('sign_handoff_member'),
          title: '폰을 회원에게 전달해 주세요',
          message:
              '회원이 직접 계약의 핵심 내용을 확인하고 서명해요.\n'
              '${_form.memberName.isEmpty ? '회원' : _form.memberName}님이 아래 내용을 읽고 서명합니다.',
          buttonKey: const ValueKey<String>('sign_handoff_member_button'),
          buttonLabel: '회원에게 전달했어요',
          onContinue:
              () => setState(
                () =>
                    _stage =
                        _status == 'disclosed'
                            ? _Stage.terms
                            : _Stage.disclosure,
              ),
        );
      case _Stage.handoffToTrainer:
        return _Handoff(
          key: const ValueKey<String>('sign_handoff_trainer'),
          title: '폰을 강사에게 돌려주세요',
          message: '회원 서명이 끝났어요. 강사가 내용을 확인하고 서명하면 계약이 완료돼요.',
          buttonKey: const ValueKey<String>('sign_handoff_trainer_button'),
          buttonLabel: '돌려받았어요',
          onContinue: () => setState(() => _stage = _Stage.trainer),
        );
      case _Stage.disclosure:
        return _buildDisclosure(context);
      case _Stage.terms:
        return _buildTerms(context);
      case _Stage.trainer:
        return _buildTrainer(context);
      case _Stage.done:
        return _buildDone(context);
    }
  }

  // ---- 핵심 고지 ----
  Widget _buildDisclosure(BuildContext context) {
    final required = _requiredChecks;
    final done = required.where(_checked.contains).length;
    return Theme(
      data: contractFormTheme(context),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Text(
                  '아래 5가지를 읽고 항목마다 확인해 주세요. 모두 확인하면 서명할 수 있어요.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                for (final card in _cards) ...[
                  _DisclosureCardView(
                    card: card,
                    checked: _checked,
                    onChanged: _toggleCheck,
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          _BottomBar(
            summary: '확인 $done/${required.length}',
            buttonKey: const ValueKey<String>('disclosure_sign_button'),
            buttonLabel: '서명 ① 하기',
            enabled: _allDisclosureChecked && !_busy,
            busy: _busy,
            onPressed: _signDisclosure,
          ),
        ],
      ),
    );
  }

  // ---- 나머지 조항 + 서명 ② ----
  Widget _buildTerms(BuildContext context) {
    final theme = Theme.of(context);
    final articles = remainingArticles(_document);
    final ready = _termsChecked && _privacyChecked;
    return Theme(
      data: contractFormTheme(context),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Text(
                  '나머지 조항을 읽고 동의하면 서명 ②로 계약이 확정돼요.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                LessonContractSectionCard(
                  title: '나머지 조항',
                  subtitle: '앞서 확인한 핵심 고지는 같은 계약서에 포함돼요.',
                  child: Column(
                    key: const ValueKey<String>('terms_articles'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (number, article) in articles) ...[
                        Text(
                          '제$number조  ${article.heading}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        for (final paragraph in article.paragraphs)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              paragraph,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.6,
                              ),
                            ),
                          ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  key: const ValueKey<String>('terms_check_terms'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text(
                    '위 조항과 앞서 확인한 핵심 고지 내용을 모두 확인하고 계약에 동의합니다.',
                  ),
                  value: _termsChecked,
                  onChanged: (v) => setState(() => _termsChecked = v ?? false),
                ),
                CheckboxListTile(
                  key: const ValueKey<String>('terms_check_privacy'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('개인정보의 수집 및 이용에 동의합니다.'),
                  value: _privacyChecked,
                  onChanged:
                      (v) => setState(() => _privacyChecked = v ?? false),
                ),
              ],
            ),
          ),
          _BottomBar(
            summary: ready ? '서명할 수 있어요' : '두 항목에 동의해 주세요',
            buttonKey: const ValueKey<String>('terms_sign_button'),
            buttonLabel: '서명 ② 하기',
            enabled: ready && !_busy,
            busy: _busy,
            onPressed: _signMember,
          ),
        ],
      ),
    );
  }

  // ---- 강사 서명 ----
  Widget _buildTrainer(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: contractFormTheme(context),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                LessonContractSectionCard(
                  title: '계약 요약',
                  subtitle: '회원이 서명한 내용을 확인한 뒤 서명해 주세요.',
                  child: _summary(context),
                ),
                const SizedBox(height: 12),
                LessonContractSectionCard(
                  title: '회원 서명',
                  subtitle: '',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _signatureRow(
                        context,
                        keyName: 'trainer_member_sig_1',
                        label: '서명 ① 핵심 고지 확인',
                        step: kStepDisclosure,
                      ),
                      const SizedBox(height: 8),
                      _signatureRow(
                        context,
                        keyName: 'trainer_member_sig_2',
                        label: '서명 ② 계약 전체 동의',
                        step: kStepMember,
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey<String>('trainer_preview'),
                    onPressed: _openPreview,
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('계약서 최종 미리보기'),
                  ),
                ),
                CheckboxListTile(
                  key: const ValueKey<String>('trainer_confirm'),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    '계약 내용과 회원 서명을 확인했습니다.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  value: _trainerConfirmed,
                  onChanged:
                      (v) => setState(() => _trainerConfirmed = v ?? false),
                ),
              ],
            ),
          ),
          _BottomBar(
            summary: _trainerConfirmed ? '서명할 수 있어요' : '확인 후 서명해 주세요',
            buttonKey: const ValueKey<String>('trainer_sign_button'),
            buttonLabel: '강사 서명하고 완료',
            enabled: _trainerConfirmed && !_busy,
            busy: _busy,
            onPressed: _signTrainer,
          ),
        ],
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final paid = _form.paidAmount;
    final rows = <(String, String)>[
      ('계약번호', _contractNo.isEmpty ? '-' : _contractNo),
      ('회원', _form.memberName.isEmpty ? '-' : _form.memberName),
      ('상품', _form.productName.isEmpty ? '-' : _form.productName),
      ('실결제금액', paid == null ? '-' : '${formatWon(paid)}원'),
      (
        '사용 가능 기간',
        '${_form.periodStart.isEmpty ? '-' : _form.periodStart} ~ '
            '${_form.periodEndLabel}',
      ),
    ];
    final theme = Theme.of(context);
    return Column(
      key: const ValueKey<String>('sign_summary'),
      children: [
        for (final (label, value) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 104,
                  child: Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _signatureRow(
    BuildContext context, {
    required String keyName,
    required String label,
    required String step,
  }) {
    final strokes = _signatureStrokes[step];
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                formatSignedAt(_signedAt(step)),
                key: ValueKey<String>('${keyName}_time'),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Container(
          key: ValueKey<String>(keyName),
          width: 120,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFF3A3A3A), width: 0.8),
            borderRadius: BorderRadius.circular(4),
          ),
          child:
              strokes == null
                  ? const Center(
                    child: Text(
                      '서명 완료',
                      style: TextStyle(fontSize: 11, color: Color(0xFF666666)),
                    ),
                  )
                  : SignatureStrokesView(strokes: strokes),
        ),
      ],
    );
  }

  // ---- 완료 ----
  /// 해지 기록 카드: 해지 시각, 사유, 회원이 의사를 밝힌 방법·날짜, 증빙 등급, 해지 시점의 횟수.
  /// 환불 금액은 다루지 않는다.
  Widget _buildTerminationCard(BuildContext context) {
    final termination =
        _contract['termination'] is Map
            ? Map<String, dynamic>.from(_contract['termination'] as Map)
            : <String, dynamic>{};
    final snapshot =
        termination['snapshot'] is Map
            ? Map<String, dynamic>.from(termination['snapshot'] as Map)
            : <String, dynamic>{};
    String reasonLabel() {
      final code = (termination['reasonCode'] ?? '').toString();
      final label =
          kContractTerminateReasons
              .where((reason) => reason.$1 == code)
              .map((reason) => reason.$2)
              .firstOrNull ??
          '-';
      final note = (termination['reasonNote'] ?? '').toString().trim();
      return note.isEmpty ? label : '$label · $note';
    }

    String channelLabel() {
      final code = (termination['noticeChannel'] ?? '').toString();
      return kContractTerminateChannels
              .where((channel) => channel.$1 == code)
              .map((channel) => channel.$2)
              .firstOrNull ??
          '-';
    }

    final signed = (termination['evidence'] ?? '') == 'member_signed';
    String count(String key) {
      final value = snapshot[key];
      return value is num ? '${value.toInt()}회' : '-';
    }

    final rows = <(String, String)>[
      ('해지 처리', formatSignedAt(_toDate(_contract['terminatedAt']))),
      ('사유', reasonLabel()),
      (
        '해지 의사',
        '${channelLabel()} · ${(termination['noticeDate'] ?? '-').toString()}',
      ),
      ('증빙 등급', signed ? '회원 서명 확인' : '강사 단독 기록'),
      (
        '해지 시점 횟수',
        '총 ${count('total')} · 소진 ${count('done')} · 잔여 ${count('remain')}',
      ),
    ];
    final theme = Theme.of(context);
    return LessonContractSectionCard(
      title: '해지 기록',
      subtitle: '환불은 앱이 처리하지 않아요. 이 기록은 수정할 수 없어요.',
      child: Column(
        key: const ValueKey<String>('termination_card'),
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 104,
                    child: Text(label, style: theme.textTheme.bodySmall),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDone(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: contractFormTheme(context),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
              children: [
                Icon(
                  _terminated
                      ? Icons.event_busy_rounded
                      : Icons.verified_rounded,
                  size: 56,
                  color:
                      _terminated
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                ),
                const SizedBox(height: 10),
                Text(
                  _terminated ? '해지된 계약서예요' : '계약이 완료되었습니다',
                  key: const ValueKey<String>('sign_done_title'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '완료 시각 ${formatSignedAt(_toDate(_contract['completedAt']))}',
                  key: const ValueKey<String>('sign_done_time'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                if (_terminated) ...[
                  _buildTerminationCard(context),
                  const SizedBox(height: 12),
                ] else ...[
                  // 완료된 계약서를 PDF로 만들어 회원에게 보내는 카드(처음이면 자동으로 PDF·링크를 만든다).
                  ContractDeliveryCard(
                    key: ValueKey<String>('delivery_${widget.contractId}'),
                    contractId: widget.contractId,
                    contract: _contract,
                    gateway: _gateway,
                    buildPdf: widget.buildPdf,
                    share: widget.share,
                    copyText: widget.copyText,
                  ),
                  const SizedBox(height: 12),
                ],
                LessonContractSectionCard(
                  title: '계약 요약',
                  subtitle: '',
                  child: _summary(context),
                ),
                const SizedBox(height: 12),
                LessonContractSectionCard(
                  title: '서명',
                  subtitle: '',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _signatureRow(
                        context,
                        keyName: 'done_sig_1',
                        label: '회원 서명 ① 핵심 고지 확인',
                        step: kStepDisclosure,
                      ),
                      const SizedBox(height: 8),
                      _signatureRow(
                        context,
                        keyName: 'done_sig_2',
                        label: '회원 서명 ② 계약 전체 동의',
                        step: kStepMember,
                      ),
                      const SizedBox(height: 8),
                      _signatureRow(
                        context,
                        keyName: 'done_sig_3',
                        label: '강사 서명',
                        step: kStepTrainer,
                      ),
                      if (_terminated && _signedAt(kStepTerminate) != null) ...[
                        const SizedBox(height: 8),
                        _signatureRow(
                          context,
                          keyName: 'done_sig_terminate',
                          label: '회원 해지 확인 서명',
                          step: kStepTerminate,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey<String>('done_preview'),
                  onPressed: _openPreview,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('계약서 보기'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  key: const ValueKey<String>('done_close'),
                  onPressed: () {
                    // 닫기로 바로 나가므로, 방금 완료한 계약이면 저장됐다는 것과 이어서 할 일을 알려 준다.
                    if (_completedHere) {
                      AifcInteraction.toast(
                        context: context,
                        message: kContractSavedAfterSignToast,
                        duration: const Duration(milliseconds: 3200),
                      );
                    }
                    Navigator.of(context).pop(true);
                  },
                  child: const Text('닫기'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.status, required this.stage});

  final String status;
  final _Stage stage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final order = {
      'draft': 0,
      'disclosed': 1,
      'member_signed': 2,
      'completed': 3,
    };
    final progress = order[status] ?? 0;
    Widget step(String key, String label, int index) {
      final done = progress > index;
      final current = progress == index && stage != _Stage.done;
      final color =
          done || current
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant;
      return Expanded(
        child: Column(
          key: ValueKey<String>(key),
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
              size: 18,
              color: color,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: current ? FontWeight.w900 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        children: [
          step('sign_step_1', '서명 ① 고지 확인', 0),
          step('sign_step_2', '서명 ② 계약 동의', 1),
          step('sign_step_3', '강사 서명', 2),
        ],
      ),
    );
  }
}

class _Handoff extends StatelessWidget {
  const _Handoff({
    super.key,
    required this.title,
    required this.message,
    required this.buttonKey,
    required this.buttonLabel,
    required this.onContinue,
  });

  final String title;
  final String message;
  final Key buttonKey;
  final String buttonLabel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.swap_horiz_rounded,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: buttonKey,
            onPressed: onContinue,
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    super.key,
    required this.text,
    required this.buttonKey,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String text;
  final Key buttonKey;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              key: buttonKey,
              onPressed: onPressed,
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.summary,
    required this.buttonKey,
    required this.buttonLabel,
    required this.enabled,
    required this.busy,
    required this.onPressed,
  });

  final String summary;
  final Key buttonKey;
  final String buttonLabel;
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  summary,
                  key: const ValueKey<String>('sign_bottom_summary'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilledButton(
                key: buttonKey,
                onPressed: enabled ? onPressed : null,
                child:
                    busy
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text(buttonLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisclosureCardView extends StatelessWidget {
  const _DisclosureCardView({
    required this.card,
    required this.checked,
    required this.onChanged,
  });

  final ContractDisclosureCard card;
  final Set<String> checked;
  final void Function(String id, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LessonContractSectionCard(
      title: '${card.number} ${card.title}',
      subtitle: '',
      child: Column(
        key: ValueKey<String>('disclosure_card_${card.id}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (label, value) in card.rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 112,
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          for (final line in card.lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                line,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
              ),
            ),
          const SizedBox(height: 4),
          CheckboxListTile(
            key: ValueKey<String>('disclosure_check_${card.id}'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              card.checkLabel,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            value: checked.contains(card.id),
            onChanged: (value) => onChanged(card.id, value ?? false),
          ),
          for (final (id, label) in card.extraChecks)
            CheckboxListTile(
              key: ValueKey<String>('disclosure_check_$id'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              value: checked.contains(id),
              onChanged: (value) => onChanged(id, value ?? false),
            ),
        ],
      ),
    );
  }
}
