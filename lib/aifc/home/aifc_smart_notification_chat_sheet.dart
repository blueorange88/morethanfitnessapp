import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/lesson_notification_prefs.dart';
import '../core/aifc_avatar.dart';
import '../core/aifc_chat_bubble.dart';

const Color _kSmartBg = Color(0xFFF5F4FF);
const Color _kSmartPrimary = Color(0xFF4F46E5);
const Color _kSmartPrimary2 = Color(0xFF9333EA);
const Color _kSmartText = Color(0xFF1E1B4B);
const Color _kSmartMuted = Color(0xFF7C7ABB);
const Color _kSmartBorder = Color(0xFFE0DEFF);

class AifcSmartNotificationChatSheet {
  const AifcSmartNotificationChatSheet._();

  static Future<bool?> show({
    required BuildContext context,
    required String trainerName,
    required bool canUseSmartAlarm,
    required bool canUseContractBasisAlarm,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AifcSmartNotificationChatBody(
        trainerName: trainerName,
        canUseSmartAlarm: canUseSmartAlarm,
        canUseContractBasisAlarm: canUseContractBasisAlarm,
      ),
    );
  }
}

class _AifcSmartNotificationChatBody extends StatefulWidget {
  const _AifcSmartNotificationChatBody({
    required this.trainerName,
    required this.canUseSmartAlarm,
    required this.canUseContractBasisAlarm,
  });

  final String trainerName;
  final bool canUseSmartAlarm;
  final bool canUseContractBasisAlarm;

  @override
  State<_AifcSmartNotificationChatBody> createState() =>
      _AifcSmartNotificationChatBodyState();
}

class _AifcSmartNotificationChatBodyState
    extends State<_AifcSmartNotificationChatBody> {
  final ScrollController _scrollController = ScrollController();

  bool _loading = true;
  bool _saving = false;

  bool _showSaveTyping = false;
  bool _showSaveReply = false;
  bool _showSaveUserBubble = false;

  bool _enabled = true;
  int _gapMinutes = LessonNotificationPrefs.defaultSmartGapMinutes;

  bool _priorityMemoEnabled = true;
  bool _firstLessonEnabled = true;

  LessonNotificationAlertStyle _alertStyle =
      LessonNotificationAlertStyle.vibrationOnly;

  LessonNotificationDeviceMode _deviceMode =
      LessonNotificationDeviceMode.followDevice;

  String get _safeTrainerName {
    final text = widget.trainerName.trim();
    if (text.isEmpty) return '강사님';
    return text.endsWith('님') ? text : '$text님';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final enabled = await LessonNotificationPrefs.loadSmartAlarmEnabled();
    final gap = await LessonNotificationPrefs.loadSmartAlarmGapMinutes();
    final priorityMemoEnabled =
        await LessonNotificationPrefs.loadSmartAlarmPriorityMemoEnabled();
    final firstLessonEnabled =
        await LessonNotificationPrefs.loadSmartAlarmFirstLessonEnabled();
    final alertStyle = await LessonNotificationPrefs.loadAlertStyle();
    final deviceMode = await LessonNotificationPrefs.loadDeviceMode();

    if (!mounted) return;

    setState(() {
      _enabled = enabled;
      _gapMinutes = gap;
      _priorityMemoEnabled = priorityMemoEnabled;
      _firstLessonEnabled = firstLessonEnabled;
      _alertStyle = alertStyle;
      _deviceMode = deviceMode;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    HapticFeedback.mediumImpact();

    setState(() {
      _saving = true;
      _showSaveUserBubble = true;
      _showSaveTyping = false;
      _showSaveReply = false;
    });

    _scrollToBottomSoon();

    await LessonNotificationPrefs.saveSmartAlarmEnabled(_enabled);
    await LessonNotificationPrefs.saveSmartAlarmGapMinutes(_gapMinutes);
    await LessonNotificationPrefs.saveSmartAlarmPriorityMemoEnabled(
      _priorityMemoEnabled,
    );
    await LessonNotificationPrefs.saveSmartAlarmFirstLessonEnabled(
      _firstLessonEnabled,
    );
    await LessonNotificationPrefs.saveAlertStyle(_alertStyle);
    await LessonNotificationPrefs.saveDeviceMode(_deviceMode);

    await Future<void>.delayed(const Duration(milliseconds: 360));

    if (!mounted) return;

    setState(() {
      _showSaveTyping = true;
    });

    _scrollToBottomSoon();

    await Future<void>.delayed(const Duration(milliseconds: 760));

    if (!mounted) return;

    setState(() {
      _showSaveTyping = false;
      _showSaveReply = true;
    });

    _scrollToBottomSoon();

    await Future<void>.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  String _gapLabel(int value) {
    switch (value) {
      case 60:
        return '1시간';
      case 90:
        return '1시간 30분';
      case 120:
        return '2시간';
      case 180:
        return '3시간';
      default:
        return '$value분';
    }
  }

  String get _saveReplyText {
    if (!_enabled) {
      return '좋아요. MORE 스마트 알림은 꺼두고, 선택한 기본 알림 시간대로 알려드릴게요.';
    }

    if (_priorityMemoEnabled) {
      return '좋아요. 이제 ${_gapLabel(_gapMinutes)} 이상 빈 시간이 있는 다음 레슨과 중요한 메모가 있는 레슨만 똑똑하게 알려드릴게요.';
    }

    return '좋아요. 이제 ${_gapLabel(_gapMinutes)} 이상 빈 시간이 있는 다음 레슨만 똑똑하게 알려드릴게요.';
  }

  String _smartSummaryText() {
    if (!widget.canUseContractBasisAlarm) {
      return '좋아요. 이제 ${_gapLabel(_gapMinutes)} 이상 빈 시간이 있는 다음 레슨 위주로 알려드릴게요.\n스케줄표에 적은 메모는 알림에 함께 표시돼요.';
    }

    final extras = <String>[];

    if (_priorityMemoEnabled) {
      extras.add('레슨일지 중요 메모');
    }

    if (_firstLessonEnabled) {
      extras.add('첫 레슨/신규회원');
    }

    extras.add('레슨계약서 자동 연동');

    if (extras.isEmpty) {
      return '좋아요. 이제 ${_gapLabel(_gapMinutes)} 이상 빈 시간이 있는 다음 레슨만 똑똑하게 알려드릴게요.';
    }

    return '좋아요. 이제 ${_gapLabel(_gapMinutes)} 이상 빈 시간이 있는 다음 레슨과 ${extras.join(', ')}도 함께 확인해드릴게요.';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.86,
          ),
          decoration: const BoxDecoration(
            color: _kSmartBg,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8D4FF),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: _kSmartPrimary,
                        ),
                      )
                    : SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _FcBubble(
                              text:
                                  '$_safeTrainerName, MORE 스마트 알림을 같이 맞춰볼게요.\n아래 항목을 편하게 선택해주세요.',
                            ),
                            const SizedBox(height: 12),
                            if (!widget.canUseSmartAlarm)
                              _LockedGuideCard()
                            else ...[
                              _UserQuestionCard(
                                title: '1. 스마트 알림을 사용할까요?',
                                subtitle: _enabled
                                    ? '연속 레슨은 생략하고 필요한 알림만 예약합니다.'
                                    : '모든 레슨에 기본 알림 시간이 적용됩니다.',
                                children: [
                                  _OptionButton(
                                    selected: _enabled,
                                    label: '켜기',
                                    icon: Icons.auto_awesome_rounded,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _enabled = true;
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  _OptionButton(
                                    selected: !_enabled,
                                    label: '끄기',
                                    icon: Icons.notifications_outlined,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      setState(() {
                                        _enabled = false;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _UserQuestionCard(
                                title: '2. 어느정도 빈시간부터 알려드릴까요?',
                                subtitle: '이 기준 이상 비어 있으면 다음 레슨 전에 알려드려요.',
                                enabled: _enabled,
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [60, 90, 120, 180].map((value) {
                                    final selected = _gapMinutes == value;

                                    return _ChoicePill(
                                      label: _gapLabel(value),
                                      selected: selected,
                                      enabled: _enabled,
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _gapMinutes = value;
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _UserQuestionCard(
                                title: '3. 알림 방식은 어떻게 할까요?',
                                subtitle: '무음, 진동, 소리 방식을 선택할 수 있어요.',
                                child: Column(
                                  children: LessonNotificationAlertStyle.values
                                      .map((style) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _WideChoiceTile(
                                        selected: _alertStyle == style,
                                        title: style.label,
                                        subtitle: style.description,
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          setState(() {
                                            _alertStyle = style;
                                          });
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (widget.canUseContractBasisAlarm) ...[
                                _UserQuestionCard(
                                  title: '4. 레슨일지의 중요한 메모도 볼까요?',
                                  subtitle:
                                      '통증, 부상, 상담, 재등록 같은 레슨일지 메모가 있으면 연속된 레슨이라도 알려드려요.',
                                  enabled: _enabled,
                                  children: [
                                    _OptionButton(
                                      selected: _priorityMemoEnabled,
                                      label: '알려줘요',
                                      icon: Icons.priority_high_rounded,
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _priorityMemoEnabled = true;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    _OptionButton(
                                      selected: !_priorityMemoEnabled,
                                      label: '괜찮아요',
                                      icon: Icons.notes_rounded,
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _priorityMemoEnabled = false;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _UserQuestionCard(
                                  title: '5. 첫 레슨이나 신규회원도 알려드릴까요?',
                                  subtitle:
                                      '계약서 또는 레슨일지 기준으로 첫 레슨/신규회원으로 보이면 연속 레슨이어도 알려드려요.',
                                  enabled: _enabled,
                                  children: [
                                    _OptionButton(
                                      selected: _firstLessonEnabled,
                                      label: '알려줘요',
                                      icon: Icons.person_add_alt_1_rounded,
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _firstLessonEnabled = true;
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    _OptionButton(
                                      selected: !_firstLessonEnabled,
                                      label: '괜찮아요',
                                      icon: Icons.person_outline_rounded,
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _firstLessonEnabled = false;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ] else ...[
                                const _SemiProSmartFeatureNotice(),
                                const SizedBox(height: 12),
                              ],
                              _UserQuestionCard(
                                title: widget.canUseContractBasisAlarm
                                    ? '6. 휴대폰 모드는 어떻게 따를까요?'
                                    : '4. 휴대폰 모드는 어떻게 따를까요?',
                                subtitle: '방해금지/무음 설정에 따라 제한될 수 있어요.',
                                child: Column(
                                  children: LessonNotificationDeviceMode.values
                                      .map((mode) {
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _WideChoiceTile(
                                        selected: _deviceMode == mode,
                                        title: mode.label,
                                        subtitle: mode.description,
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          setState(() {
                                            _deviceMode = mode;
                                          });
                                        },
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_showSaveUserBubble) ...[
                                AifcChatBubble(
                                  side: AifcBubbleSide.user,
                                  text: '설정 저장할게요',
                                ),
                                const SizedBox(height: 10),
                              ],
                              if (_showSaveTyping) ...[
                                const AifcTypingBubble(),
                                const SizedBox(height: 10),
                              ],
                              if (_showSaveReply) ...[
                                _FcBubble(
                                  text: _saveReplyText,
                                ),
                              ],
                            ],
                          ],
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: widget.canUseSmartAlarm
                    ? Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () {
                                      Navigator.of(context).pop(false);
                                    },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF6B7280),
                                side: const BorderSide(
                                  color: Color(0xFFE5E7EB),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                '나중에',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: _saving ? null : _save,
                              style: FilledButton.styleFrom(
                                backgroundColor: _kSmartPrimary,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: Text(
                                _saving ? '저장 중...' : '설정 저장',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : FilledButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: FilledButton.styleFrom(
                          backgroundColor: _kSmartPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '확인',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FcBubble extends StatelessWidget {
  const _FcBubble({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AifcAvatar(
          size: 34,
          isAnimating: true,
          backgroundColor: Colors.white,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(18),
              ),
              border: Border.all(
                color: _kSmartBorder,
              ),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: _kSmartText,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SemiProSmartFeatureNotice extends StatelessWidget {
  const _SemiProSmartFeatureNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFDDD6FE),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              size: 17,
              color: Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Semi-Pro부터 더 똑똑해져요',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF312E81),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '아마추어에서는 연속 레슨 알림을 줄이고, 스케줄표 메모를 알림에 함께 표시해요.\n'
                  'Semi-Pro부터는 계약서, 레슨일지 메모, 첫 레슨/신규회원 관리까지 함께 확인해요.',
                  style: TextStyle(
                    fontSize: 11.2,
                    height: 1.38,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF5B21B6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UserQuestionCard extends StatelessWidget {
  const _UserQuestionCard({
    required this.title,
    required this.subtitle,
    this.children,
    this.child,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final List<Widget>? children;
  final Widget? child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.86),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _kSmartBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: _kSmartText,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: _kSmartMuted,
                fontSize: 11.2,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 11),
            if (children != null)
              Row(
                children: children!,
              )
            else if (child != null)
              child!,
          ],
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected
                ? _kSmartPrimary.withOpacity(0.11)
                : const Color(0xFFF8F7FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? _kSmartPrimary : _kSmartBorder,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? _kSmartPrimary : _kSmartMuted,
                size: 20,
              ),
              const SizedBox(height: 5),
              Text(
                label,
                style: TextStyle(
                  color: selected ? _kSmartPrimary : _kSmartMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: enabled ? (_) => onTap() : null,
      showCheckmark: false,
      selectedColor: const Color(0xFFEEF2FF),
      backgroundColor: const Color(0xFFF8F7FF),
      side: BorderSide(
        color: selected ? _kSmartPrimary : _kSmartBorder,
      ),
      labelStyle: TextStyle(
        color: selected ? _kSmartPrimary : _kSmartMuted,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _WideChoiceTile extends StatelessWidget {
  const _WideChoiceTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          color: selected
              ? _kSmartPrimary.withOpacity(0.10)
              : const Color(0xFFF8F7FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _kSmartPrimary : _kSmartBorder,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: selected ? _kSmartPrimary : _kSmartMuted,
              size: 20,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? _kSmartPrimary : _kSmartText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _kSmartMuted,
                      fontSize: 10.8,
                      fontWeight: FontWeight.w600,
                      height: 1.32,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedGuideCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _kSmartBorder,
        ),
      ),
      child: Column(
        children: const [
          Icon(
            Icons.workspace_premium_outlined,
            color: _kSmartPrimary,
            size: 32,
          ),
          SizedBox(height: 10),
          Text(
            '아마추어부터 사용할 수 있어요',
            style: TextStyle(
              color: _kSmartText,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '회원 관리 흐름이 조금 더 쌓이면 MORE가 레슨 간격을 보고 필요한 알림만 골라드릴게요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kSmartMuted,
              fontSize: 11.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
