import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'contract_page.dart';
import '../services/app_tier_access_service.dart';
import '../widgets/aifc_tier_feature_gate_sheet.dart';

import '../widgets/aifc_confirm_chat_sheet.dart';
import '../widgets/aifc_interaction.dart';

const Color kContractListPrimary = Color(0xFF4F46E5);
const Color kContractListPrimary2 = Color(0xFF9333EA);
const Color kContractListBg = Color(0xFFF3F4F6);
const Color kContractListBorder = Color(0xFFE5E7EB);
const double kContractListMaxWidth = 480;

class ContractListPage extends StatefulWidget {
  const ContractListPage({super.key, this.personalOwnerUid});

  final String? personalOwnerUid;

  @override
  State<ContractListPage> createState() => _ContractListPageState();
}

class _ContractListPageState extends State<ContractListPage> {
  String _filter = 'all';

  bool _matchesFilter(String status) {
    switch (_filter) {
      case 'draft':
        return status == 'draft' || status == 'step1Saved';
      case 'completed':
        return status == 'completed' || status == 'signed';
      case 'shared':
        return status == 'sent' ||
            status == 'share_opened' ||
            status == 'print_opened' ||
            status == 'stored_only';
      case 'all':
      default:
        return true;
    }
  }

  String _statusLabel(String raw) {
    switch (raw) {
      case 'draft':
        return '임시저장';
      case 'step1Saved':
        return '1단계 저장';
      case 'signed':
      case 'completed':
        return '작성완료';
      case 'sent':
      case 'share_opened':
        return '전송/공유';
      case 'cancelled':
        return '취소';
      case 'superseded':
        return '새 버전 있음';
      case 'print_opened':
        return '인쇄';
      case 'stored_only':
        return '센터보관';
      case 'pdf_generated':
        return 'PDF 생성';

      default:
        return raw.isEmpty ? '상태 없음' : raw;
    }
  }

  Color _statusColor(String raw) {
    switch (raw) {
      case 'draft':
        return const Color(0xFF6B7280);
      case 'step1Saved':
        return const Color(0xFF2563EB);
      case 'signed':
      case 'completed':
        return const Color(0xFF059669);
      case 'sent':
      case 'share_opened':
        return const Color(0xFF7C3AED);
      case 'cancelled':
        return const Color(0xFFDC2626);
      case 'print_opened':
        return const Color(0xFFF97316);
      case 'stored_only':
        return const Color(0xFF475569);
      case 'pdf_generated':
        return const Color(0xFF2563EB);

      default:
        return kContractListPrimary;
    }
  }

  String _formatMoney(dynamic value) {
    final number = value is num
        ? value.toInt()
        : int.tryParse(
                (value ?? '').toString().replaceAll(RegExp(r'[^0-9]'), '')) ??
            0;

    final raw = number.toString();
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

  String _dateText(dynamic value) {
    if (value is Timestamp) {
      final d = value.toDate();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }

    final text = (value ?? '').toString().trim();
    return text.isEmpty ? '-' : text;
  }

  bool _isDraftLikeContract(String status) {
    return status == 'draft' || status == 'step1Saved' || status.trim().isEmpty;
  }

  bool _isCompletedLikeContract(String status) {
    return status == 'signed' ||
        status == 'completed' ||
        status == 'sent' ||
        status == 'share_opened' ||
        status == 'print_opened' ||
        status == 'stored_only' ||
        status == 'pdf_generated';
  }

  String _contractDeleteName(Map<String, dynamic> data) {
    final memberName = (data['memberName'] ?? '').toString().trim();
    final productName = (data['productName'] ?? '').toString().trim();
    final contractNo = (data['contractNo'] ?? '').toString().trim();

    if (memberName.isNotEmpty && contractNo.isNotEmpty) {
      return '$memberName 계약서 · $contractNo';
    }

    if (memberName.isNotEmpty) {
      return '$memberName 계약서';
    }

    if (productName.isNotEmpty) {
      return productName;
    }

    return '이름 없는 계약서';
  }

  Future<void> _confirmDeleteContract({
    required String contractId,
    required Map<String, dynamic> data,
  }) async {
    final status = (data['status'] ?? data['stage'] ?? '').toString().trim();
    final deleteName = _contractDeleteName(data);
    final isDraftLike = _isDraftLikeContract(status);
    final isCompletedLike = _isCompletedLikeContract(status);

    final result = await AifcConfirmChatSheet.show(
      context: context,
      nickname: '강사님',
      title: isDraftLike ? '임시저장 계약서를 삭제할까요?' : '완료된 계약서를 삭제할까요?',
      message: isDraftLike
          ? '$deleteName 문서를 계약서 목록에서 삭제할게요.\n임시저장 문서는 바로 삭제해도 운영 이력에 큰 영향이 적어요.'
          : '$deleteName 문서는 작성완료 또는 전송 이력이 있는 계약서예요.\n\n지금은 목록에서 숨김 처리하고 삭제 이력을 남길게요.\n추후 회원 알림 또는 관리자 확인 절차를 붙일 수 있어요.',
      cancelText: '취소',
      confirmText: isDraftLike ? '삭제' : '삭제 처리',
      userCancelText: '취소할게요',
      userConfirmText: isDraftLike ? '삭제할게요' : '삭제 처리할게요',
      cancelReplyText: '좋아요. 계약서는 그대로 둘게요.',
      confirmReplyText: isDraftLike
          ? '확인했어요. 임시저장 계약서를 삭제할게요.'
          : '확인했어요. 완료 계약서는 삭제 이력을 남기고 목록에서 숨길게요.',
      danger: true,
    );

    if (!result) return;

    try {
      await FirebaseFirestore.instance
          .collection('contracts')
          .doc(contractId)
          .set(
        {
          'isDeleted': true,
          'deleteStatus': isDraftLike ? 'deleted_draft' : 'deleted_completed',
          'deletedOriginalStatus': status,
          'deletedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),

          // 추후 회원 알림 / 관리자 PIN / 삭제 사유 연결용 자리
          'deleteRequiresMemberNotice': isCompletedLike,
          'deleteRequiresAdminConfirm': isCompletedLike,
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      AifcInteraction.toast(
        context: context,
        message: isDraftLike ? '임시저장 계약서를 삭제했어요.' : '완료 계약서를 목록에서 숨김 처리했어요.',
        bottomOffset: 110,
      );
    } catch (e) {
      debugPrint('계약서 삭제 실패: $e');

      if (!mounted) return;

      AifcInteraction.toast(
        context: context,
        message: '계약서 삭제에 실패했어요. 다시 시도해주세요.',
        bottomOffset: 110,
      );
    }
  }

  Future<void> _openNewContract(BuildContext context) async {
    final ownerUid = (widget.personalOwnerUid ?? '').trim();
    if (ownerUid.isNotEmpty) {
      final allowed = await AifcTierFeatureGateSheet.guard(
        context: context,
        access: null,
        feature: AppTierFeatureKey.contract,
        loadAccess: () => AppTierAccessService.loadPersonalTrainerAccess(
          uid: ownerUid,
        ),
        entryPoint: 'contract_list_create',
      );
      if (!allowed || !context.mounted) return;
    }
    final newMemberId =
        FirebaseFirestore.instance.collection('members').doc().id;

    String trainerName = '트레이너';

    try {
      final snap = await FirebaseFirestore.instance
          .doc(
            ownerUid.isEmpty
                ? 'trainer_profile/me'
                : 'trainer_profiles/$ownerUid',
          )
          .get();

      final data = snap.data();

      final contractTrainerName =
          (data?['contractTrainerName'] ?? '').toString().trim();
      final displayName = (data?['displayName'] ?? '').toString().trim();
      final name = (data?['name'] ?? '').toString().trim();

      if (contractTrainerName.isNotEmpty) {
        trainerName = contractTrainerName;
      } else if (displayName.isNotEmpty) {
        trainerName = displayName;
      } else if (name.isNotEmpty) {
        trainerName = name;
      }
    } catch (_) {}

    if (!context.mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContractPage(
          memberId: newMemberId,
          memberName: '',
          trainerName: trainerName,
          initialStage: ContractStage.requiredInfo,
          personalOwnerUid: ownerUid.isEmpty ? null : ownerUid,
        ),
      ),
    );
  }

  void _showContractPreview(
    BuildContext context,
    String id,
    Map<String, dynamic> data,
  ) {
    final status = (data['status'] ?? data['stage'] ?? '').toString();
    final memberName = (data['memberName'] ?? '').toString();
    final productName = (data['productName'] ?? '').toString();
    final totalPrice = data['totalPrice'];
    final contractNo = (data['contractNo'] ?? '').toString();
    final contractDate = (data['contractDate'] ?? '').toString();
    final delivery = data['delivery'] is Map
        ? Map<String, dynamic>.from(data['delivery'] as Map)
        : <String, dynamic>{};

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        memberName.isEmpty ? '이름 없는 계약서' : '$memberName 계약서',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(status).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _statusLabel(status),
                        style: TextStyle(
                          color: _statusColor(status),
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _PreviewRow(
                    label: '계약번호',
                    value: contractNo.isEmpty ? '저장 전' : contractNo),
                _PreviewRow(
                    label: '상품명',
                    value: productName.isEmpty ? '-' : productName),
                _PreviewRow(
                    label: '결제금액', value: '${_formatMoney(totalPrice)}원'),
                _PreviewRow(
                    label: '계약일',
                    value: contractDate.isEmpty ? '-' : contractDate),
                _PreviewRow(
                  label: '수령방식',
                  value: (delivery['methodLabel'] ?? '-').toString(),
                ),
                _PreviewRow(
                  label: '수령대상',
                  value: (delivery['target'] ?? '-').toString(),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: kContractListBorder),
                  ),
                  child: const Text(
                    '임시저장 또는 작성 중 계약서는 이어서 작성할 수 있습니다.\n완료된 계약서는 새 버전 작성 흐름으로 관리하는 것을 권장합니다.',
                    style: TextStyle(
                      fontSize: 12.2,
                      height: 1.45,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.pop(context);

                          await _confirmDeleteContract(
                            contractId: id,
                            data: data,
                          );
                        },
                        icon:
                            const Icon(Icons.delete_outline_rounded, size: 18),
                        label: const Text('삭제'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(
                            color: Color(0xFFFCA5A5),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ContractPage(
                                contractId: id,
                                memberId: (data['memberId'] ?? '').toString(),
                                memberName: memberName,
                                trainerName:
                                    (data['trainerName'] ?? '트레이너').toString(),
                                personalOwnerUid: widget.personalOwnerUid,
                                initialStage:
                                    status == 'draft' || status == 'step1Saved'
                                        ? ContractStage.requiredInfo
                                        : ContractStage.detailConfirm,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('이어서 작성'),
                        style: FilledButton.styleFrom(
                          backgroundColor: kContractListPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterTabs() {
    Widget tab(String value, String label) {
      final selected = _filter == value;

      return Expanded(
        child: GestureDetector(
          onTap: () {
            setState(() {
              _filter = value;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? kContractListPrimary : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? kContractListPrimary : kContractListBorder,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: selected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Row(
        children: [
          tab('all', '전체'),
          const SizedBox(width: 6),
          tab('draft', '임시'),
          const SizedBox(width: 6),
          tab('completed', '완료'),
          const SizedBox(width: 6),
          tab('shared', '전송'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth >= 600;
        final width = isTablet ? kContractListMaxWidth : constraints.maxWidth;

        return Scaffold(
          backgroundColor: kContractListBg,
          body: Center(
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  _ContractListHeader(
                    onBack: () => Navigator.of(context).maybePop(),
                    onNew: () => _openNewContract(context),
                  ),
                  _buildFilterTabs(),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('contracts')
                          .orderBy('updatedAt', descending: true)
                          .limit(50)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Center(
                            child: Text('계약서 목록을 불러오지 못했습니다.'),
                          );
                        }

                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: kContractListPrimary,
                            ),
                          );
                        }

                        final allDocs = snapshot.data!.docs.where((doc) {
                          final data = doc.data();
                          return data['isDeleted'] != true;
                        }).toList();

                        final docs = allDocs.where((doc) {
                          final data = doc.data();
                          final status = (data['status'] ?? data['stage'] ?? '')
                              .toString();
                          return _matchesFilter(status);
                        }).toList();

                        if (docs.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border:
                                      Border.all(color: kContractListBorder),
                                ),
                                child: Text(
                                  _filter == 'all'
                                      ? '아직 저장된 계약서가 없습니다.'
                                      : '해당 상태의 계약서가 없습니다.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                          itemCount: docs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();

                            return _ContractListTile(
                              data: data,
                              statusLabel: _statusLabel,
                              statusColor: _statusColor,
                              dateText: _dateText,
                              formatMoney: _formatMoney,
                              onTap: () => _showContractPreview(
                                context,
                                doc.id,
                                data,
                              ),
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
      },
    );
  }
}

class _ContractListHeader extends StatelessWidget {
  const _ContractListHeader({
    required this.onBack,
    required this.onNew,
  });

  final VoidCallback onBack;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: topInset + 16,
        left: 24,
        right: 24,
        bottom: 18,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            kContractListPrimary,
            kContractListPrimary2,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '계약서 관리',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  '임시저장, 작성완료, 전송 계약서를 확인합니다',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onNew,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.20),
                ),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractListTile extends StatelessWidget {
  const _ContractListTile({
    required this.data,
    required this.statusLabel,
    required this.statusColor,
    required this.dateText,
    required this.formatMoney,
    required this.onTap,
  });

  final Map<String, dynamic> data;
  final String Function(String raw) statusLabel;
  final Color Function(String raw) statusColor;
  final String Function(dynamic value) dateText;
  final String Function(dynamic value) formatMoney;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = (data['status'] ?? data['stage'] ?? '').toString();
    final color = statusColor(status);

    final memberName = (data['memberName'] ?? '').toString().trim();
    final productName = (data['productName'] ?? '').toString().trim();
    final contractNo = (data['contractNo'] ?? '').toString().trim();
    final totalPrice = data['totalPrice'];
    final updatedAt = data['updatedAt'];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kContractListBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.description_outlined,
                color: color,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memberName.isEmpty ? '이름 없는 계약서' : memberName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    productName.isEmpty ? '상품명 미입력' : productName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${contractNo.isEmpty ? '계약번호 없음' : contractNo} · ${formatMoney(totalPrice)}원 · ${dateText(updatedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF9CA3AF),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusLabel(status),
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kContractListBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyContractList extends StatelessWidget {
  const _EmptyContractList({
    required this.onNew,
  });

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: kContractListBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.description_outlined,
              color: kContractListPrimary,
              size: 36,
            ),
            const SizedBox(height: 12),
            const Text(
              '아직 저장된 계약서가 없습니다',
              style: TextStyle(
                color: Color(0xFF111827),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '새 계약서를 작성하면 임시저장과 완료 계약서가 여기에 표시됩니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add_rounded),
                label: const Text('새 계약서 작성'),
                style: FilledButton.styleFrom(
                  backgroundColor: kContractListPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
