import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aifc/core/aifc_chat_bubble.dart';
import '../aifc/core/aifc_chat_flow.dart';
import '../aifc/core/aifc_sheet_frame.dart';
import '../aifc/core/aifc_theme.dart';
import '../aifc/core/aifc_nickname.dart';
import '../widgets/premium_banner_widget.dart';

enum AifcUpgradeAction {
  later,
  sponsor,
  goFillInfo,
  goAddMember,
  goAddProduct,
  showTierGuide,
}

class AifcUpgradeChatSheet extends StatefulWidget {
  const AifcUpgradeChatSheet({
    super.key,
    required this.data,
    required this.trainerName,
  });

  final PremiumBannerData data;
  final String trainerName;

  static Future<AifcUpgradeAction?> show({
    required BuildContext context,
    required PremiumBannerData data,
    required String trainerName,
  }) {
    return showModalBottomSheet<AifcUpgradeAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AifcUpgradeChatSheet(data: data, trainerName: trainerName),
    );
  }

  @override
  State<AifcUpgradeChatSheet> createState() => _AifcUpgradeChatSheetState();
}

class _AifcUpgradeChatSheetState extends State<AifcUpgradeChatSheet>
    with TickerProviderStateMixin, AifcChatFlowMixin<AifcUpgradeChatSheet> {
  static const _groupInitial = 'upgrade_initial';
  static const _groupSponsorGuide = 'upgrade_sponsor_guide';
  static const _groupProgressGuide = 'upgrade_progress_guide';
  static const _groupSponsorConfirm = 'upgrade_sponsor_confirm';
  static const _groupShowTierGuide = 'upgrade_show_tier_guide';
  static const _groupProgressAction = 'upgrade_progress_action';

  String get _name {
    return aifcNicknameLabel(widget.trainerName);
  }

  AppTier get _tier => widget.data.currentTier;

  // ── 다음 등급 정보 ─────────────────────────────────────────────────────────
  String get _nextTierLabel {
    switch (_tier) {
      case AppTier.beginner:
        return 'Amateur';
      case AppTier.amateur:
        return 'Semi-Pro';
      case AppTier.semiPro:
        return 'Pro';
      default:
        return 'Pro';
    }
  }

  String get _nextTierFeature {
    switch (_tier) {
      case AppTier.beginner:
        return '고객카드 기능이 열려요';
      case AppTier.amateur:
        return '계약서 작성 기능이 열려요';
      case AppTier.semiPro:
        return '인사이트 + 전체 기능이 열려요';
      default:
        return '모든 기능이 열려요';
    }
  }

  String get _mainMessage {
    switch (_tier) {
      case AppTier.beginner:
        return '$_name 고객카드를 열면 회원 관리가 훨씬 체계적으로 돼요.\n\n'
            'Amateur까지 두 가지만 채우면 돼요.';
      case AppTier.amateur:
        return '$_name 계약서로 레슨을 더 단단하게 관리할 수 있어요.\n\n'
            'Semi-Pro까지 고객 ${(30 - widget.data.memberCount).clamp(0, 30)}명 더 필요해요.';
      case AppTier.semiPro:
        return '$_name 더 강화된 AI 기능과 체계적인 관리 시스템을 써보세요.\n\n'
            'Pro까지 고객 ${(50 - widget.data.memberCount).clamp(0, 50)}명 더 필요해요.';
      default:
        return '$_name 모어댄을 응원해주셔서 감사해요.';
    }
  }

  // ── initState ──────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    aifcSetActiveGroup(_groupInitial);

    aifcAddFcMessage(
      text: _mainMessage,
      groupKey: _groupInitial,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NextTierFeatureCard(tier: _tier, feature: _nextTierFeature),
          const SizedBox(height: 12),
          _ProgressCard(data: widget.data, tier: _tier),
          const SizedBox(height: 12),
          _InitialActionCard(
            tier: _tier,
            onSponsor: _handleSponsor,
            onProgress: _handleProgress,
            onShowTierGuide: _handleShowTierGuide,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ── 후원 탭 ────────────────────────────────────────────────────────────────
  Future<void> _handleSponsor() async {
    if (aifcIsBusy) return;
    HapticFeedback.mediumImpact();

    aifcSetActiveGroup(_groupSponsorGuide);

    await aifcUserThenFc(
      userText: '후원하고 바로 $_nextTierLabel 열기',
      fcText: '감사해요 🙏\n'
          '작은 후원으로 모어댄의 멋진 한걸음을 함께 만들어주시는 거예요.\n\n'
          '후원하면 $_nextTierFeature\n'
          '광고와 결제 유도 배너도 사라져요.',
      groupKey: _groupSponsorGuide,
      fcChild: _SponsorActionCard(
        nextTier: _nextTierLabel,
        onConfirm: _handleSponsorConfirm,
      ),
    );
  }

  Future<void> _handleSponsorConfirm() async {
    if (aifcIsBusy) return;
    HapticFeedback.mediumImpact();

    await aifcRunActionThenReply(
      userText: '후원 결제 진행할게요',
      groupKey: _groupSponsorConfirm,
      action: () async {
        await Future.delayed(const Duration(milliseconds: 300));
      },
      successText: '좋아요. 후원 결제 화면으로 연결할게요.\n'
          '모어댄을 응원해주셔서 감사해요 ✨',
      closeAfterReply: true,
      popResult: AifcUpgradeAction.sponsor,
    );
  }

  // ── 운영으로 달성 탭 ───────────────────────────────────────────────────────
  Future<void> _handleShowTierGuide() async {
    if (aifcIsBusy) return;

    HapticFeedback.lightImpact();

    await aifcRunActionThenReply(
      userText: '전체 등급 볼게요',
      groupKey: _groupShowTierGuide,
      action: () async {
        await Future.delayed(const Duration(milliseconds: 200));
      },
      successText: '좋아요. 전체 등급 안내로 연결할게요.',
      closeAfterReply: true,
      popResult: AifcUpgradeAction.showTierGuide,
    );
  }

  Future<void> _handleProgress() async {
    if (aifcIsBusy) return;
    HapticFeedback.lightImpact();

    aifcSetActiveGroup(_groupProgressGuide);

    final String progressMessage = _buildProgressMessage();

    await aifcUserThenFc(
      userText: '사용하면서 달성할게요',
      fcText: progressMessage,
      groupKey: _groupProgressGuide,
      fcChild: _ProgressDetailCard(
        data: widget.data,
        tier: _tier,
        onAction: _handleProgressAction,
      ),
    );
  }

  String _buildProgressMessage() {
    switch (_tier) {
      case AppTier.beginner:
        final parts = <String>[];
        if (widget.data.scheduleCount < 10) {
          parts.add('레슨 일정 ${10 - widget.data.scheduleCount}개 더 등록');
        }
        if (!widget.data.trainerInfoDone) {
          parts.add('선생님 정보 입력 완료');
        }
        return '두 가지 미션을 채우면 Amateur가 돼요.\n\n'
            '${parts.map((e) => '• $e').join('\n')}';

      case AppTier.amateur:
        final remaining = (30 - widget.data.memberCount).clamp(0, 30);
        return '고객카드에 회원 $remaining명 더 등록하면 Semi-Pro가 돼요!\n\n'
            '• 현재 ${widget.data.memberCount}명 등록됨\n'
            '• 레슨 상품도 1개 이상 등록 필요해요\n\n'
            '고객카드 페이지로 바로 이동할까요?';

      case AppTier.semiPro:
        final remaining = (50 - widget.data.memberCount).clamp(0, 50);
        return '활성 고객 $remaining명 더 등록하면 Pro가 돼요!\n\n'
            '• 현재 ${widget.data.memberCount}명 등록됨\n'
            '• Pro부터 인사이트와 전체 기능이 열려요\n\n'
            '고객카드 페이지로 바로 이동할까요?';

      default:
        return '조건을 채우면 다음 등급으로 올라갈 수 있어요.';
    }
  }

  Future<void> _handleProgressAction(AifcUpgradeAction action) async {
    if (aifcIsBusy) return;

    String userText;
    String fcReply;

    switch (action) {
      case AifcUpgradeAction.goFillInfo:
        userText = '마이페이지에서 정보 채울게요';
        fcReply = '좋아요! 마이페이지로 이동할게요.\n이름, 연락처, 레슨분야, 센터명만 채워주시면 돼요.';
        break;
      case AifcUpgradeAction.goAddMember:
        userText = '고객카드 추가하러 갈게요';
        fcReply = '좋아요! 고객카드 페이지로 이동할게요.\n한 명씩 쌓다 보면 금방 달성해요 💪';
        break;
      case AifcUpgradeAction.goAddProduct:
        userText = '레슨 상품 추가할게요';
        fcReply = '좋아요! 마이페이지 레슨 상품 관리로 이동할게요.';
        break;
      default:
        userText = '알겠어요';
        fcReply = '언제든 필요하면 다시 불러주세요!';
    }

    await aifcRunActionThenReply(
      userText: userText,
      groupKey: _groupProgressAction,
      action: () async {
        await Future.delayed(const Duration(milliseconds: 200));
      },
      successText: fcReply,
      closeAfterReply: true,
      popResult: action,
    );
  }

  Future<void> _handleLater() async {
    if (aifcIsBusy) return;
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(AifcUpgradeAction.later);
  }

  // ── build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AifcSheetFrame(
      maxHeightFactor: 0.84,
      children: [
        Flexible(
          child: SingleChildScrollView(
            controller: aifcScrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (int i = 0; i < aifcMessages.length; i++)
                  AifcAnimatedChatMessage(
                    controller: aifcMessageAnimations[i],
                    dimmed: aifcMessages[i].groupKey != null &&
                        aifcActiveGroupKey != null &&
                        aifcMessages[i].groupKey != aifcActiveGroupKey,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AifcChatBubble(
                        side: aifcMessages[i].side,
                        text: aifcMessages[i].text,
                        child: aifcMessages[i].child,
                      ),
                    ),
                  ),
                if (aifcShowTyping)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: AifcTypingBubble(),
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
        if (!aifcIsBusy)
          GestureDetector(
            onTap: _handleLater,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text('나중에',
                    style: TextStyle(
                        color: AifcColors.textHint,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          )
        else
          const SizedBox(height: 16),
      ],
    );
  }
}

// ── 다음 등급 기능 카드 ────────────────────────────────────────────────────────
class _NextTierFeatureCard extends StatelessWidget {
  const _NextTierFeatureCard({required this.tier, required this.feature});

  final AppTier tier;
  final String feature;

  List<Map<String, dynamic>> get _features {
    switch (tier) {
      case AppTier.beginner:
        return [
          {
            'icon': Icons.person_outline_rounded,
            'title': '고객카드 해금',
            'desc': '회원 상세 정보, 레슨 기록, 상담 메모를 한 곳에서 관리해요.'
          },
          {
            'icon': Icons.history_edu_rounded,
            'title': '레슨 이력 관리',
            'desc': '고객별 레슨 진행 현황과 잔여 횟수를 추적해요.'
          },
        ];
      case AppTier.amateur:
        return [
          {
            'icon': Icons.description_outlined,
            'title': '계약서 작성',
            'desc': '회원 정보와 레슨 조건을 문서로 남길 수 있어요.'
          },
          {
            'icon': Icons.draw_rounded,
            'title': '전자서명 관리',
            'desc': '서명된 계약서를 기준값으로 관리해요.'
          },
        ];
      case AppTier.semiPro:
        return [
          {
            'icon': Icons.bar_chart_rounded,
            'title': '인사이트',
            'desc': '레슨 추이, 매출 흐름을 한눈에 볼 수 있어요.'
          },
          {
            'icon': Icons.auto_awesome_rounded,
            'title': '강화된 AI FC',
            'desc': '더 똑똑해진 AI FC가 이용 전반을 도와드려요.'
          },
          {
            'icon': Icons.lock_open_rounded,
            'title': '전체 기능 해금',
            'desc': '앱의 모든 기능을 제한 없이 사용해요.'
          },
        ];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _features
          .map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F7FF),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFE0DEFF), width: 0.5),
                      ),
                      child: Icon(f['icon'] as IconData,
                          color: AifcColors.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f['title'] as String,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E1B4B))),
                          const SizedBox(height: 2),
                          Text(f['desc'] as String,
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: AifcColors.textHint,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ── 진행도 카드 ────────────────────────────────────────────────────────────────
class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.data, required this.tier});

  final PremiumBannerData data;
  final AppTier tier;

  List<Map<String, dynamic>> get _items {
    switch (tier) {
      case AppTier.beginner:
        return [
          {
            'label': '레슨 일정 10개 등록',
            'done': data.scheduleCount >= 10,
            'detail': '현재 ${data.scheduleCount}개',
          },
          {
            'label': '선생님 정보 입력 완료',
            'done': data.trainerInfoDone,
            'detail': '이름·연락처·활동 지역·주 활동 종목·소속 형태',
          },
        ];
      case AppTier.amateur:
        return [
          {
            'label': '고객카드 30명 이상',
            'done': data.memberCount >= 30,
            'detail': '현재 ${data.memberCount}명',
          },
          {
            'label': '레슨 상품 1개 이상 등록',
            'done': data.hasProduct,
            'detail': data.hasProduct ? '완료' : '마이페이지에서 추가',
          },
        ];
      case AppTier.semiPro:
        return [
          {
            'label': '활성 고객 50명 이상',
            'done': data.memberCount >= 50,
            'detail': '현재 ${data.memberCount}명',
          },
        ];
      default:
        return [];
    }
  }

  int get _doneCount => _items.where((e) => e['done'] == true).length;
  double get _progress => _doneCount / _items.length;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0DEFF), width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('달성 현황',
                  style: TextStyle(
                      fontSize: 11,
                      color: AifcColors.textHint,
                      fontWeight: FontWeight.w700)),
              Text('$_doneCount / ${_items.length} 완료',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AifcColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 4,
              backgroundColor: const Color(0xFFE0DEFF),
              valueColor: const AlwaysStoppedAnimation(AifcColors.primary),
            ),
          ),
          const SizedBox(height: 10),
          ..._items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      item['done'] == true
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: item['done'] == true
                          ? AifcColors.primary
                          : const Color(0xFFD1D5DB),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(item['label'] as String,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: item['done'] == true
                                  ? AifcColors.primary
                                  : const Color(0xFF6B7280))),
                    ),
                    Text(item['detail'] as String,
                        style: const TextStyle(
                            fontSize: 10.5, color: AifcColors.textHint)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ── 초기 액션 카드 ─────────────────────────────────────────────────────────────
class _InitialActionCard extends StatelessWidget {
  const _InitialActionCard({
    required this.tier,
    required this.onSponsor,
    required this.onProgress,
    required this.onShowTierGuide,
  });

  final AppTier tier;
  final VoidCallback onSponsor;
  final VoidCallback onProgress;
  final VoidCallback onShowTierGuide;

  String get _nextTierLabel {
    switch (tier) {
      case AppTier.beginner:
        return 'Amateur';
      case AppTier.amateur:
        return 'Semi-Pro';
      case AppTier.semiPro:
        return 'Pro';
      default:
        return '다음 등급';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _UpgradeActionButton(
          label: '후원하고 바로 $_nextTierLabel 열기',
          foregroundColor: Colors.white,
          backgroundColor: AifcColors.primary,
          borderColor: AifcColors.primary,
          onTap: onSponsor,
        ),
        const SizedBox(height: 8),
        _UpgradeActionButton(
          label: '사용하면서 달성할게요',
          foregroundColor: AifcColors.primary,
          backgroundColor: AifcColors.primary.withOpacity(0.07),
          borderColor: AifcColors.primary.withOpacity(0.16),
          onTap: onProgress,
        ),
        const SizedBox(height: 8),
        _UpgradeActionButton(
          label: '전체 등급 보기',
          foregroundColor: AifcColors.primary,
          backgroundColor: Colors.white,
          borderColor: const Color(0xFFE0DEFF),
          onTap: onShowTierGuide,
        ),
      ],
    );
  }
}

// ── 후원 확인 카드 ─────────────────────────────────────────────────────────────
class _SponsorActionCard extends StatelessWidget {
  const _SponsorActionCard({
    required this.nextTier,
    required this.onConfirm,
  });

  final String nextTier;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0DEFF), width: 0.5),
          ),
          child: const Column(
            children: [
              _SponsorBenefitRow(
                  icon: Icons.block_rounded, text: '결제 유도 배너 제거'),
              SizedBox(height: 6),
              _SponsorBenefitRow(icon: Icons.ads_click_rounded, text: '광고 제거'),
              SizedBox(height: 6),
              _SponsorBenefitRow(
                  icon: Icons.lock_open_rounded, text: '다음 등급 기능 즉시 해금'),
              SizedBox(height: 6),
              _SponsorBenefitRow(
                  icon: Icons.favorite_rounded, text: '모어댄 개발 응원'),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _UpgradeActionButton(
          label: '후원 결제 진행하기',
          foregroundColor: Colors.white,
          backgroundColor: AifcColors.primary,
          borderColor: AifcColors.primary,
          onTap: onConfirm,
        ),
      ],
    );
  }
}

class _SponsorBenefitRow extends StatelessWidget {
  const _SponsorBenefitRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AifcColors.primary),
        const SizedBox(width: 8),
        Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E1B4B))),
      ],
    );
  }
}

// ── 달성 상세 카드 ─────────────────────────────────────────────────────────────
class _ProgressDetailCard extends StatelessWidget {
  const _ProgressDetailCard({
    required this.data,
    required this.tier,
    required this.onAction,
  });

  final PremiumBannerData data;
  final AppTier tier;
  final void Function(AifcUpgradeAction) onAction;

  @override
  Widget build(BuildContext context) {
    switch (tier) {
      case AppTier.beginner:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!data.trainerInfoDone) ...[
              _UpgradeActionButton(
                label: '마이페이지에서 정보 채우기',
                foregroundColor: Colors.white,
                backgroundColor: AifcColors.primary,
                borderColor: AifcColors.primary,
                onTap: () => onAction(AifcUpgradeAction.goFillInfo),
              ),
              const SizedBox(height: 8),
            ],
            _UpgradeActionButton(
              label: '스케줄 등록하러 가기',
              foregroundColor: AifcColors.primary,
              backgroundColor: AifcColors.primary.withOpacity(0.07),
              borderColor: AifcColors.primary.withOpacity(0.16),
              onTap: () => onAction(AifcUpgradeAction.later),
            ),
          ],
        );

      case AppTier.amateur:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _UpgradeActionButton(
              label: '고객카드 추가하러 가기',
              foregroundColor: Colors.white,
              backgroundColor: AifcColors.primary,
              borderColor: AifcColors.primary,
              onTap: () => onAction(AifcUpgradeAction.goAddMember),
            ),
            if (!data.hasProduct) ...[
              const SizedBox(height: 8),
              _UpgradeActionButton(
                label: '레슨 상품 등록하기',
                foregroundColor: AifcColors.primary,
                backgroundColor: AifcColors.primary.withOpacity(0.07),
                borderColor: AifcColors.primary.withOpacity(0.16),
                onTap: () => onAction(AifcUpgradeAction.goAddProduct),
              ),
            ],
          ],
        );

      case AppTier.semiPro:
        return _UpgradeActionButton(
          label: '고객카드 추가하러 가기',
          foregroundColor: Colors.white,
          backgroundColor: AifcColors.primary,
          borderColor: AifcColors.primary,
          onTap: () => onAction(AifcUpgradeAction.goAddMember),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

// ── 공용 액션 버튼 ─────────────────────────────────────────────────────────────
class _UpgradeActionButton extends StatelessWidget {
  const _UpgradeActionButton({
    required this.label,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.onTap,
  });

  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AifcRadius.button),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        alignment: Alignment.center,
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: foregroundColor,
                fontSize: 13,
                fontWeight: FontWeight.w900)),
      ),
    );
  }
}
