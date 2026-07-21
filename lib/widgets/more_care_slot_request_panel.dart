import 'package:flutter/material.dart';

import '../services/more_care_slot_service.dart';

class MoreCareSlotRequestPanel extends StatefulWidget {
  const MoreCareSlotRequestPanel({
    super.key,
    this.compact = false,
  });

  final bool compact;

  @override
  State<MoreCareSlotRequestPanel> createState() =>
      _MoreCareSlotRequestPanelState();
}

class _MoreCareSlotRequestPanelState extends State<MoreCareSlotRequestPanel> {
  late final Future<MoreCareSlotActor> _actorFuture;
  final Set<String> _busyRequestIds = <String>{};

  @override
  void initState() {
    super.initState();
    _actorFuture = MoreCareSlotService.loadCurrentActor();
  }

  Future<void> _approve({
    required MoreCareSlotActor actor,
    required MoreCareSlotRequest request,
  }) async {
    if (_busyRequestIds.contains(request.id)) return;

    setState(() {
      _busyRequestIds.add(request.id);
    });

    try {
      await MoreCareSlotService.approveRequest(
        memberId: request.memberId,
        approvedByTrainerId: actor.trainerId,
        organizationId: actor.organizationId,
      );

      if (!mounted) return;

      _showSnack('${request.memberName}님 MORE 관리를 계속 열어두었어요.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('승인 처리에 실패했어요.');
    } finally {
      if (mounted) {
        setState(() {
          _busyRequestIds.remove(request.id);
        });
      }
    }
  }

  Future<void> _reject({
    required MoreCareSlotActor actor,
    required MoreCareSlotRequest request,
  }) async {
    if (_busyRequestIds.contains(request.id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('기본 관리로 유지할까요?'),
          content: Text(
            '${request.memberName}님은 기본 회원관리와 스케줄, 기본 레슨일지는 계속 사용할 수 있어요.\n\n'
                '다만 MORE 스마트 알림, 계약서/레슨일지 기반 고급 관리는 승인 전까지 열리지 않습니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('아니요'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('기본 관리로 유지'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() {
      _busyRequestIds.add(request.id);
    });

    try {
      await MoreCareSlotService.rejectRequest(
        memberId: request.memberId,
        rejectedByTrainerId: actor.trainerId,
        organizationId: actor.organizationId,
        reason: 'manager_keep_basic_from_panel',
      );

      if (!mounted) return;

      _showSnack('${request.memberName}님은 기본 관리로 유지했어요.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('기본 관리 처리에 실패했어요.');
    } finally {
      if (mounted) {
        setState(() {
          _busyRequestIds.remove(request.id);
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1600),
        ),
      );
  }

  String _reasonLabel(String? reason) {
    switch ((reason ?? '').trim()) {
      case 'lesson_log_saved':
        return '레슨일지 저장';
      case 'quick_sign_log_saved':
        return '빠른서명 저장';
      case 'contract_saved':
        return '계약서 저장';
      case 'lesson_log_advanced_more_care':
        return '레슨일지 고급 관리';
      case 'field_trainer_request':
        return '현장 요청';
      default:
        return 'MORE 관리 요청';
    }
  }

  String _remainingLabel(DateTime? temporaryUntil) {
    if (temporaryUntil == null) return '임시 사용 중';

    final now = DateTime.now();
    final diff = temporaryUntil.difference(now);

    if (diff.isNegative) {
      return '임시 사용 기간 확인 필요';
    }

    final days = diff.inDays;

    if (days >= 1) {
      return '임시 사용 ${days + 1}일 남음';
    }

    final hours = diff.inHours;

    if (hours >= 1) {
      return '임시 사용 ${hours}시간 남음';
    }

    return '임시 사용 오늘까지';
  }

  String _requestedAtLabel(DateTime? value) {
    if (value == null) return '';

    final now = DateTime.now();
    final diff = now.difference(value);

    if (diff.inMinutes < 1) return '방금 요청';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전 요청';
    if (diff.inDays < 1) return '${diff.inHours}시간 전 요청';

    return '${diff.inDays}일 전 요청';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MoreCareSlotActor>(
      future: _actorFuture,
      builder: (context, actorSnapshot) {
        if (actorSnapshot.connectionState != ConnectionState.done) {
          return _buildLoadingCard();
        }

        final actor = actorSnapshot.data ??
            const MoreCareSlotActor(
              trainerId: 'me',
              trainerName: '트레이너',
            );

        return StreamBuilder<List<MoreCareSlotRequest>>(
          stream: MoreCareSlotService.watchPendingRequests(
            organizationId: actor.organizationId,
          ),
          builder: (context, snapshot) {
            final requests = snapshot.data ?? const <MoreCareSlotRequest>[];

            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingCard();
            }

            if (requests.isEmpty) {
              return _buildEmptyCard();
            }

            return Container(
              width: double.infinity,
              padding: EdgeInsets.all(widget.compact ? 12 : 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: const Color(0xFFE5E7EB),
                ),
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
                  _buildHeader(requests.length),
                  const SizedBox(height: 12),
                  ...requests.map(
                        (request) {
                      final busy = _busyRequestIds.contains(request.id);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _MoreCareSlotRequestCard(
                          request: request,
                          reasonLabel: _reasonLabel(request.reason),
                          remainingLabel:
                          _remainingLabel(request.temporaryUntil),
                          requestedAtLabel:
                          _requestedAtLabel(request.requestedAt),
                          busy: busy,
                          onApprove: () => _approve(
                            actor: actor,
                            request: request,
                          ),
                          onReject: () => _reject(
                            actor: actor,
                            request: request,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(int count) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
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
                'MORE 관리 요청',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '$count건이 임시로 열려 있어요. 필요한 회원만 살짝 이어서 관리할 수 있습니다.',
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
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'MORE 관리 요청을 확인하고 있어요.',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xFF059669),
            size: 20,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '지금은 승인 대기 중인 MORE 관리 요청이 없어요.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreCareSlotRequestCard extends StatelessWidget {
  const _MoreCareSlotRequestCard({
    required this.request,
    required this.reasonLabel,
    required this.remainingLabel,
    required this.requestedAtLabel,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final MoreCareSlotRequest request;
  final String reasonLabel;
  final String remainingLabel;
  final String requestedAtLabel;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: busy ? 0.62 : 1,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFDE68A),
                    ),
                  ),
                  child: const Icon(
                    Icons.pending_actions_rounded,
                    color: Color(0xFFD97706),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${request.memberName}님 MORE 관리',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${request.trainerName}님이 현장에서 먼저 열어두었어요.',
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
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _MiniChip(
                  text: reasonLabel,
                  bg: const Color(0xFFEEF2FF),
                  fg: const Color(0xFF4F46E5),
                ),
                _MiniChip(
                  text: remainingLabel,
                  bg: const Color(0xFFFFFBEB),
                  fg: const Color(0xFF92400E),
                ),
                if (requestedAtLabel.isNotEmpty)
                  _MiniChip(
                    text: requestedAtLabel,
                    bg: const Color(0xFFF3F4F6),
                    fg: const Color(0xFF4B5563),
                  ),
              ],
            ),
            const SizedBox(height: 11),
            const Text(
              '승인하면 계약서·레슨일지 메모·스마트 알림까지 계속 이어서 관리됩니다.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.38,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6B7280),
                      side: const BorderSide(
                        color: Color(0xFFD1D5DB),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('기본 관리로 유지'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(busy ? '처리 중...' : '계속 열어두기'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({
    required this.text,
    required this.bg,
    required this.fg,
  });

  final String text;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10.8,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}