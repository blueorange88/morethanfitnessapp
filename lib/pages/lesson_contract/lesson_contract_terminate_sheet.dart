import 'package:flutter/material.dart';

/// 계약 해지 사유(서버 코드, 화면 이름).
const List<(String, String)> kContractTerminateReasons = [
  ('member_request', '회원 요청'),
  ('trainer_reason', '강사 사정'),
  ('other', '기타'),
];

/// 회원이 해지 의사를 밝힌 방법(서버 코드, 화면 이름).
const List<(String, String)> kContractTerminateChannels = [
  ('verbal', '구두'),
  ('sms', '문자'),
  ('kakao', '카톡'),
  ('visit', '방문'),
  ('other', '기타'),
];

/// 해지 시트에서 강사가 입력한 값. [withSignature]가 true면 이어서 회원 서명을 받는다.
class ContractTerminateInput {
  const ContractTerminateInput({
    required this.reasonCode,
    required this.reasonNote,
    required this.noticeChannel,
    required this.noticeDate,
    required this.markExpired,
    required this.withSignature,
  });

  final String reasonCode;
  final String reasonNote;
  final String noticeChannel;

  /// 회원이 해지 의사를 밝힌 날짜(`YYYY-MM-DD`).
  final String noticeDate;
  final bool markExpired;
  final bool withSignature;
}

String _dateText(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

/// 완료된 계약서를 해지하기 전에 사유·의사표시 방법/날짜·정리 옵션·회원 서명 여부를 정하는 시트.
/// 값을 돌려주고, 닫으면 null. 환불은 앱이 처리하지 않고 기록만 남긴다는 것을 알려 준다.
Future<ContractTerminateInput?> showContractTerminateSheet(
  BuildContext context, {
  DateTime? completedAt,
  DateTime? today,
}) {
  return showModalBottomSheet<ContractTerminateInput>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TerminateSheet(completedAt: completedAt, today: today),
  );
}

class _TerminateSheet extends StatefulWidget {
  const _TerminateSheet({required this.completedAt, required this.today});

  final DateTime? completedAt;
  final DateTime? today;

  @override
  State<_TerminateSheet> createState() => _TerminateSheetState();
}

class _TerminateSheetState extends State<_TerminateSheet> {
  final TextEditingController _note = TextEditingController();
  String _reason = kContractTerminateReasons.first.$1;
  String _channel = kContractTerminateChannels.first.$1;
  late DateTime _noticeDate = _today;
  bool _markExpired = false;
  bool _withSignature = true;

  DateTime get _today {
    final now = widget.today ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _firstDate {
    final completed = widget.completedAt;
    if (completed == null) return _today.subtract(const Duration(days: 365));
    final day = DateTime(completed.year, completed.month, completed.day);
    return day.isAfter(_today) ? _today : day;
  }

  bool get _noteMissing => _reason == 'other' && _note.text.trim().length < 2;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _noticeDate,
      firstDate: _firstDate,
      lastDate: _today,
    );
    if (picked != null && mounted) {
      setState(
        () => _noticeDate = DateTime(picked.year, picked.month, picked.day),
      );
    }
  }

  void _submit() {
    if (_noteMissing) return;
    Navigator.of(context).pop(
      ContractTerminateInput(
        reasonCode: _reason,
        reasonNote: _note.text.trim(),
        noticeChannel: _channel,
        noticeDate: _dateText(_noticeDate),
        markExpired: _markExpired,
        withSignature: _withSignature,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    TextStyle label() => TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: colors.onSurface,
    );
    return Container(
      key: const Key('contract_terminate_sheet'),
      constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          18,
          16,
          18 + media.padding.bottom + media.viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '계약을 해지할까요?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '해지는 이 계약이 끝났다는 기록이에요. 환불 금액 계산과 송금은 앱이 하지 않고, '
              '해지 시각과 그 시점의 횟수만 기록으로 남겨요.\n'
              '해지하면 회원의 총·잔여 횟수는 0(미등록)으로 정리되고, 되돌릴 수 없어요.',
              key: const Key('contract_terminate_notice'),
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text('해지 사유', style: label()),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final reason in kContractTerminateReasons)
                  ChoiceChip(
                    key: ValueKey<String>(
                      'contract_terminate_reason_${reason.$1}',
                    ),
                    label: Text(reason.$2),
                    selected: _reason == reason.$1,
                    onSelected: (_) => setState(() => _reason = reason.$1),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('contract_terminate_note'),
              controller: _note,
              maxLength: 200,
              maxLines: 2,
              minLines: 1,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: _reason == 'other' ? '사유를 적어 주세요 (필수)' : '메모 (선택)',
                errorText:
                    _noteMissing && _note.text.isNotEmpty
                        ? '사유를 2자 이상 적어 주세요'
                        : null,
              ),
            ),
            const SizedBox(height: 8),
            Text('회원이 해지 의사를 밝힌 방법', style: label()),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                for (final channel in kContractTerminateChannels)
                  ChoiceChip(
                    key: ValueKey<String>(
                      'contract_terminate_channel_${channel.$1}',
                    ),
                    label: Text(channel.$2),
                    selected: _channel == channel.$1,
                    onSelected: (_) => setState(() => _channel = channel.$1),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('contract_terminate_date'),
              onPressed: _pickDate,
              icon: const Icon(Icons.event_rounded, size: 18),
              label: Text('의사를 밝힌 날짜 ${_dateText(_noticeDate)}'),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('contract_terminate_mark_expired'),
              contentPadding: EdgeInsets.zero,
              title: const Text('회원을 만료 상태로 옮기기'),
              subtitle: const Text('활동 중인 회원만 옮겨져요.'),
              value: _markExpired,
              onChanged: (value) => setState(() => _markExpired = value),
            ),
            SwitchListTile(
              key: const Key('contract_terminate_with_signature'),
              contentPadding: EdgeInsets.zero,
              title: const Text('회원 서명 받기 (선택)'),
              subtitle: Text(
                _withSignature
                    ? '증빙 등급: 회원 서명 확인'
                    : '서명 없이 진행해요. 증빙 등급: 강사 단독 기록',
                key: const Key('contract_terminate_evidence_hint'),
              ),
              value: _withSignature,
              onChanged: (value) => setState(() => _withSignature = value),
            ),
            const SizedBox(height: 12),
            FilledButton(
              key: const Key('contract_terminate_continue'),
              style: FilledButton.styleFrom(backgroundColor: colors.error),
              onPressed: _noteMissing ? null : _submit,
              child: Text(_withSignature ? '회원 서명 받고 해지하기' : '서명 없이 해지하기'),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('contract_terminate_cancel'),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
          ],
        ),
      ),
    );
  }
}
