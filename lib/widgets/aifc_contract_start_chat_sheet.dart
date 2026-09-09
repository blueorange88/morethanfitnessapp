import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../aifc/core/aifc_chat_bubble.dart';
import '../aifc/core/aifc_chat_flow.dart';
import '../aifc/core/aifc_sheet_frame.dart';
import '../aifc/core/aifc_theme.dart';

const Color _kSheetBg = Color(0xFFF5F4FF);
const Color _kFcBubBg = Color(0xFFFFFFFF);
const Color _kFcBubBdr = Color(0xFFE0DEFF);
const Color _kFcText = Color(0xFF1E1B4B);
const Color _kPrimary = Color(0xFF4F46E5);
const Color _kTextMuted = Color(0xFF7C7ABB);
const Color _kTextHint = Color(0xFFA5A3C8);
const Color _kCardBdr = Color(0xFFE0DEFF);

enum AifcContractStartAction {
  later,
  startContract,
  upgradeSemiPro,
}

enum _ContractChatMode {
  initial,
  semiProGuide,
  upgradePrompt,
}

class AifcContractStartChatSheet extends StatefulWidget {
  const AifcContractStartChatSheet({
    super.key,
    required this.trainerName,
    required this.canUseContract,
  });

  final String trainerName;
  final bool canUseContract;

  static Future<AifcContractStartAction?> show({
    required BuildContext context,
    required String trainerName,
    required bool canUseContract,
  }) {
    return showModalBottomSheet<AifcContractStartAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AifcContractStartChatSheet(
        trainerName: trainerName,
        canUseContract: canUseContract,
      ),
    );
  }

  @override
  State<AifcContractStartChatSheet> createState() =>
      _AifcContractStartChatSheetState();
}

class _AifcContractStartChatSheetState extends State<AifcContractStartChatSheet>
    with
        TickerProviderStateMixin,
        AifcChatFlowMixin<AifcContractStartChatSheet> {
  _ContractChatMode _mode = _ContractChatMode.initial;

  String get _safeTrainerName {
    final value = widget.trainerName.trim();

    if (value.isEmpty) {
      return '강사님';
    }

    return value.endsWith('님') ? value : '$value님';
  }

  @override
  void initState() {
    super.initState();

    aifcSetActiveGroup(_ContractChatMode.initial);

    final introText = widget.canUseContract
        ? '$_safeTrainerName, 계약서 작성을 시작해볼까요?\n회원 정보와 레슨 조건을 제가 차근차근 정리해드릴게요.'
        : '$_safeTrainerName, 계약서 작성은 Semi-Pro부터 열려 있어요.\n조건을 채우거나 후원으로 바로 열 수 있어요.';

    aifcAddFcMessage(
      text: introText,
      groupKey: _ContractChatMode.initial,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.canUseContract
                ? '계약서는 금액, 횟수, 서명처럼 중요한 내용을 안전하게 남기는 문서예요.'
                : '지금은 계약서 작성 조건을 확인하거나, 후원으로 바로 열 수 있어요.',
            style: const TextStyle(
              color: AifcColors.textHint,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const _ContractFeatureCard(),
          const SizedBox(height: 12),
          _ContractStartActionCard(
            canUseContract: widget.canUseContract,
            onShowSemiProGuide: _showSemiProGuide,
            onStartContract: _handleStartContract,
            onUpgradeSemiPro: _handleUpgradeSemiPro,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _showSemiProGuide() async {
    if (aifcIsBusy || _mode == _ContractChatMode.semiProGuide) return;

    HapticFeedback.lightImpact();

    setState(() {
      _mode = _ContractChatMode.semiProGuide;
    });

    await aifcUserThenFc(
      userText: '세미프로 조건 볼게요',
      fcText: '세미프로에서는 계약서 작성, 전자서명 기록, 계약서 기준 레슨 횟수 연동을 사용할 수 있어요.',
      groupKey: _ContractChatMode.semiProGuide,
      fcChild: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '고객카드에 직접 입력한 값보다 서명 완료된 계약서를 더 신뢰도 높은 기준값으로 관리할 수 있어요.',
            style: TextStyle(
              color: AifcColors.textHint,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const _SemiProSupportCard(),
          const SizedBox(height: 12),
          _SemiProActionCard(
            canUseContract: widget.canUseContract,
            onStartContract: _handleStartContract,
            onUpgradeSemiPro: _handleUpgradeSemiPro,
          ),
        ],
      ),
    );
  }

  Future<void> _handleStartContract() async {
    if (aifcIsBusy) return;

    HapticFeedback.mediumImpact();

    if (widget.canUseContract) {
      await aifcRunActionThenReply(
        userText: '계약서 작성 시작할게요',
        groupKey: 'start_contract',
        action: () async {
          await Future.delayed(const Duration(milliseconds: 250));
        },
        successText: '좋아요. 계약서 작성을 시작할게요.\n회원 정보와 레슨 조건부터 차근차근 정리해드릴게요.',
        closeAfterReply: true,
        popResult: AifcContractStartAction.startContract,
      );
      return;
    }

    await aifcRunActionThenReply(
      userText: '계약서 기능 열어볼게요',
      groupKey: 'contract_upgrade',
      action: () async {
        await Future.delayed(const Duration(milliseconds: 250));
      },
      successText: '좋아요. 등급과 후원 안내로 연결할게요.\n계약서 작성 조건을 같이 확인해볼게요.',
      closeAfterReply: true,
      popResult: AifcContractStartAction.upgradeSemiPro,
    );
  }

  Future<void> _handleUpgradeSemiPro() async {
    if (aifcIsBusy) return;

    HapticFeedback.mediumImpact();

    await aifcRunActionThenReply(
      userText: '후원하고 세미프로로 등급UP↑ 할게요',
      groupKey: 'upgrade_semipro',
      action: () async {
        await Future.delayed(const Duration(milliseconds: 250));
      },
      successText: '좋아요. 등급과 후원 안내로 연결할게요.\n계약서 작성 조건을 같이 확인해볼게요.',
      closeAfterReply: true,
      popResult: AifcContractStartAction.upgradeSemiPro,
    );
  }

  Future<void> _handleLater() async {
    HapticFeedback.lightImpact();

    if (aifcIsBusy) return;

    Navigator.of(context).pop(AifcContractStartAction.later);
  }

  @override
  Widget build(BuildContext context) {
    return AifcSheetFrame(
      maxHeightFactor: 0.82,
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
        if (aifcIsBusy)
          const SizedBox(height: 16)
        else
          GestureDetector(
            onTap: _handleLater,
            behavior: HitTestBehavior.opaque,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: Text(
                  '나중에',
                  style: TextStyle(
                    color: AifcColors.textHint,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ContractStartActionCard extends StatelessWidget {
  const _ContractStartActionCard({
    required this.canUseContract,
    required this.onShowSemiProGuide,
    required this.onStartContract,
    required this.onUpgradeSemiPro,
  });

  final bool canUseContract;
  final VoidCallback onShowSemiProGuide;
  final VoidCallback onStartContract;
  final VoidCallback onUpgradeSemiPro;

  @override
  Widget build(BuildContext context) {
    if (canUseContract) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ContractActionButton(
            label: '계약서 작성 시작',
            foregroundColor: Colors.white,
            backgroundColor: AifcColors.primary,
            borderColor: AifcColors.primary,
            onTap: onStartContract,
          ),
          const SizedBox(height: 8),
          _ContractActionButton(
            label: '등급/후원 안내 보기',
            foregroundColor: AifcColors.primary,
            backgroundColor: AifcColors.primary.withOpacity(0.07),
            borderColor: AifcColors.primary.withOpacity(0.16),
            onTap: onShowSemiProGuide,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ContractActionButton(
          label: '활용/후원으로 계약서 기능 열기',
          foregroundColor: Colors.white,
          backgroundColor: AifcColors.primary,
          borderColor: AifcColors.primary,
          onTap: onUpgradeSemiPro,
        ),
        const SizedBox(height: 8),
        const Text(
          '회원 수, 레슨 상품 등록, 활용 흐름을 쌓아가면 조건으로도 열 수 있어요.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AifcColors.textHint,
            fontSize: 10.8,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _SemiProActionCard extends StatelessWidget {
  const _SemiProActionCard({
    required this.canUseContract,
    required this.onStartContract,
    required this.onUpgradeSemiPro,
  });

  final bool canUseContract;
  final VoidCallback onStartContract;
  final VoidCallback onUpgradeSemiPro;

  @override
  Widget build(BuildContext context) {
    return _ContractActionButton(
      label: canUseContract ? '계약서 작성 시작' : '후원하고 세미프로로 등급 업',
      foregroundColor: Colors.white,
      backgroundColor: AifcColors.primary,
      borderColor: AifcColors.primary,
      onTap: canUseContract ? onStartContract : onUpgradeSemiPro,
    );
  }
}

class _ContractActionButton extends StatelessWidget {
  const _ContractActionButton({
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
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: foregroundColor,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ContractFeatureCard extends StatelessWidget {
  const _ContractFeatureCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _InfoRow(
          icon: Icons.person_outline_rounded,
          title: '회원 정보',
          subtitle: '회원 이름, 연락처, 수업 대상자를 확인해요.',
        ),
        SizedBox(height: 10),
        _InfoRow(
          icon: Icons.fitness_center_rounded,
          title: '레슨 조건',
          subtitle: '레슨형태, 총 횟수, 잔여 횟수를 기준값으로 정리해요.',
        ),
        SizedBox(height: 10),
        _InfoRow(
          icon: Icons.draw_rounded,
          title: '서명 기록',
          subtitle: '서명 완료 후 계약서 기준으로 레슨 횟수를 관리할 수 있어요.',
        ),
      ],
    );
  }
}

class _SemiProSupportCard extends StatelessWidget {
  const _SemiProSupportCard();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _InfoRow(
          icon: Icons.description_outlined,
          title: '계약서 작성',
          subtitle: '회원 정보와 레슨 조건을 문서로 남길 수 있어요.',
        ),
        SizedBox(height: 10),
        _InfoRow(
          icon: Icons.draw_rounded,
          title: '전자서명 관리',
          subtitle: '서명 완료된 계약서를 기준값으로 사용할 수 있어요.',
        ),
        SizedBox(height: 10),
        _InfoRow(
          icon: Icons.workspace_premium_outlined,
          title: '세미프로 해금',
          subtitle: '조건을 만족하거나 후원하면 세미프로 기능을 바로 열 수 있어요.',
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F7FF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kCardBdr, width: 0.5),
          ),
          child: Icon(
            icon,
            color: _kPrimary,
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
                  color: _kFcText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: _kTextHint,
                  fontSize: 11,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
