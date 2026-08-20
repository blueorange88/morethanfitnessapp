import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../aifc/home/aifc_smart_notification_chat_sheet.dart';
import '../aifc/core/aifc_nickname.dart';

import '../services/app_tier_access_service.dart';
import '../services/lesson_notification_prefs.dart';
import '../theme/app_colors.dart';

const Color kNotifyPrimary = Color(0xFF4F46E5);
const Color kNotifyPrimary2 = Color(0xFF9333EA);
const Color kNotifyBg = Color(0xFFF3F4F6);
const Color kNotifyCard = Colors.white;
const Color kNotifyBorder = Color(0xFFE5E7EB);
const Color kNotifyText = Color(0xFF111827);
const Color kNotifyMuted = Color(0xFF6B7280);
const double kNotifyMaxContentWidth = 480;

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key, this.personalOwnerUid});

  final String? personalOwnerUid;

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool _loading = true;
  bool _changed = false;

  bool _lessonEnabled = true;
  List<int> _selectedMinutes = const [30];

  LessonNotificationAlertStyle _alertStyle =
      LessonNotificationAlertStyle.vibrationOnly;

  LessonNotificationDeviceMode _deviceMode =
      LessonNotificationDeviceMode.followDevice;

  bool _smartAlarmEnabled = true;
  int _smartAlarmGapMinutes = LessonNotificationPrefs.defaultSmartGapMinutes;
  bool _smartAlarmAccessLoading = true;
  bool _canUseSmartAlarm = false;
  bool _canUseContractBasisAlarm = false;
  bool _priorityMemoEnabled = true;
  bool _firstLessonEnabled = true;
  String _aifcTrainerName = '강사';

  static const List<int> _minuteOptions = [10, 30, 60];
  static const List<int> _gapOptions = [60, 90, 120, 180];

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _openSmartAlarmChatSheet() async {
    final result = await AifcSmartNotificationChatSheet.show(
      context: context,
      trainerName: aifcNicknameLabel(_aifcTrainerName),
      canUseSmartAlarm: _canUseSmartAlarm,
      canUseContractBasisAlarm: _canUseContractBasisAlarm,
    );

    if (!mounted) return;

    if (result == true) {
      final smartAlarmEnabled =
          await LessonNotificationPrefs.loadSmartAlarmEnabled();
      final smartGapMinutes =
          await LessonNotificationPrefs.loadSmartAlarmGapMinutes();
      final priorityMemoEnabled =
          await LessonNotificationPrefs.loadSmartAlarmPriorityMemoEnabled();
      final firstLessonEnabled =
          await LessonNotificationPrefs.loadSmartAlarmFirstLessonEnabled();
      final alertStyle = await LessonNotificationPrefs.loadAlertStyle();
      final deviceMode = await LessonNotificationPrefs.loadDeviceMode();

      if (!mounted) return;

      setState(() {
        _smartAlarmEnabled = smartAlarmEnabled;
        _smartAlarmGapMinutes = smartGapMinutes;
        _priorityMemoEnabled = priorityMemoEnabled;
        _alertStyle = alertStyle;
        _deviceMode = deviceMode;
        _firstLessonEnabled = firstLessonEnabled;
      });

      _markChanged();
    }
  }

  Future<void> _loadPrefs() async {
    try {
      final enabled = await LessonNotificationPrefs.loadEnabled();
      final minutes = await LessonNotificationPrefs.loadReminderMinutes();
      final alertStyle = await LessonNotificationPrefs.loadAlertStyle();
      final deviceMode = await LessonNotificationPrefs.loadDeviceMode();

      final smartAlarmEnabled =
          await LessonNotificationPrefs.loadSmartAlarmEnabled();
      final smartGapMinutes =
          await LessonNotificationPrefs.loadSmartAlarmGapMinutes();
      final priorityMemoEnabled =
          await LessonNotificationPrefs.loadSmartAlarmPriorityMemoEnabled();
      final firstLessonEnabled =
          await LessonNotificationPrefs.loadSmartAlarmFirstLessonEnabled();

      final ownerUid = (widget.personalOwnerUid ?? '').trim();
      final tierAccess = ownerUid.isEmpty
          ? await AppTierAccessService.loadTrainerAccess()
          : await AppTierAccessService.loadPersonalTrainerAccess(uid: ownerUid);

      final aifcTrainerName = await _loadAifcTrainerName();

      final canUseSmartAlarm = tierAccess.canUseSmartAlarm;
      final canUseContractBasisAlarm = tierAccess.canUseSemiProSmartAlarm;

      if (!mounted) return;

      setState(() {
        _lessonEnabled = enabled;
        _selectedMinutes = minutes;
        _alertStyle = alertStyle;
        _deviceMode = deviceMode;

        _smartAlarmEnabled = smartAlarmEnabled;
        _smartAlarmGapMinutes = smartGapMinutes;
        _priorityMemoEnabled = priorityMemoEnabled;
        _firstLessonEnabled = firstLessonEnabled;

        _canUseSmartAlarm = canUseSmartAlarm;
        _canUseContractBasisAlarm = canUseContractBasisAlarm;
        _aifcTrainerName = aifcTrainerName;
        _smartAlarmAccessLoading = false;

        _loading = false;
      });
    } catch (error) {
      debugPrint(
        '[MTF_NOTIFY_SETTINGS] action=load result=failure '
        'errorCode=${_safeNotificationErrorCode(error)}',
      );

      if (!mounted) return;

      setState(() {
        _lessonEnabled = true;
        _selectedMinutes = LessonNotificationPrefs.defaultReminderMinutes;
        _alertStyle = LessonNotificationAlertStyle.vibrationOnly;
        _deviceMode = LessonNotificationDeviceMode.followDevice;

        _smartAlarmEnabled = true;
        _smartAlarmGapMinutes = LessonNotificationPrefs.defaultSmartGapMinutes;
        _priorityMemoEnabled = true;
        _firstLessonEnabled = true;

        _canUseSmartAlarm = false;
        _canUseContractBasisAlarm = false;
        _smartAlarmAccessLoading = false;

        _loading = false;
      });
    }
  }

  String _pickTrainerNicknameFromProfile(Map<String, dynamic> data) {
    final candidates = [
      data['aifcNickname'],
      data['nickname'],
      data['trainerNickname'],
      data['displayName'],
      data['trainerName'],
      data['name'],
    ];

    for (final value in candidates) {
      final text = (value ?? '').toString().trim();

      if (text.isNotEmpty) {
        return normalizeAifcNickname(text);
      }
    }

    return '강사';
  }

  Future<String> _loadAifcTrainerName() async {
    try {
      final ownerUid = (widget.personalOwnerUid ?? '').trim();
      final snap = await FirebaseFirestore.instance
          .collection(ownerUid.isEmpty ? 'trainer_profile' : 'trainer_profiles')
          .doc(ownerUid.isEmpty ? 'me' : ownerUid)
          .get()
          .timeout(const Duration(seconds: 2));

      final data = snap.data() ?? <String, dynamic>{};

      return _pickTrainerNicknameFromProfile(data);
    } catch (error) {
      debugPrint(
        '[MTF_NOTIFY_SETTINGS] action=nicknameLoad result=failure '
        'errorCode=${_safeNotificationErrorCode(error)}',
      );
      return '강사';
    }
  }

  String _safeNotificationErrorCode(Object error) {
    return error is FirebaseException
        ? error.code
        : error.runtimeType.toString();
  }

  Future<void> _save() async {
    await LessonNotificationPrefs.saveEnabled(_lessonEnabled);
    await LessonNotificationPrefs.saveReminderMinutes(_selectedMinutes);
    await LessonNotificationPrefs.saveAlertStyle(_alertStyle);
    await LessonNotificationPrefs.saveDeviceMode(_deviceMode);
    await LessonNotificationPrefs.saveSmartAlarmEnabled(_smartAlarmEnabled);
    await LessonNotificationPrefs.saveSmartAlarmGapMinutes(
      _smartAlarmGapMinutes,
    );
    await LessonNotificationPrefs.saveSmartAlarmPriorityMemoEnabled(
      _priorityMemoEnabled,
    );
    await LessonNotificationPrefs.saveSmartAlarmFirstLessonEnabled(
      _firstLessonEnabled,
    );

    if (!mounted) return;

    Navigator.of(context).pop(true);
  }

  void _markChanged() {
    if (_changed) return;
    _changed = true;
  }

  void _handleBack() {
    Navigator.of(context).pop(_changed ? true : null);
  }

  void _toggleMinute(int value) {
    final next = _selectedMinutes.toSet();

    if (next.contains(value)) {
      next.remove(value);
    } else {
      next.add(value);
    }

    if (next.isEmpty) {
      next.add(value);
    }

    setState(() {
      _selectedMinutes = next.toList()..sort();
    });

    _markChanged();
  }

  String get _selectedMinuteSummary {
    final sorted = [..._selectedMinutes]..sort();

    if (sorted.isEmpty) return '30분 전';

    return sorted.map((e) => '$e분 전').join(' · ');
  }

  String get _smartAlarmGapSummary {
    switch (_smartAlarmGapMinutes) {
      case 60:
        return '1시간 이상 빈 시간';
      case 90:
        return '1시간 30분 이상 빈 시간';
      case 120:
        return '2시간 이상 빈 시간';
      case 180:
        return '3시간 이상 빈 시간';
      default:
        return '${_smartAlarmGapMinutes}분 이상 빈 시간';
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double width =
            isTablet ? kNotifyMaxContentWidth : constraints.maxWidth;

        final bottomSafe = MediaQuery.of(context).padding.bottom;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: SizedBox(
              width: width,
              child: Column(
                children: [
                  _NotificationHeader(
                    onBackTap: _handleBack,
                    lessonEnabled: _lessonEnabled,
                    selectedMinuteSummary: _selectedMinuteSummary,
                    alertStyleLabel: _alertStyle.label,
                    smartAlarmEnabled: _smartAlarmEnabled,
                    canUseSmartAlarm: _canUseSmartAlarm,
                    priorityMemoEnabled: _priorityMemoEnabled,
                    firstLessonEnabled: _firstLessonEnabled,
                    canUseContractBasisAlarm: _canUseContractBasisAlarm,
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(),
                          )
                        : SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              16,
                              16,
                              28 + bottomSafe + 4,
                            ),
                            child: Column(
                              children: [
                                _SectionCard(
                                  title: '레슨 알림',
                                  subtitle: '레슨 시작 전 필요한 타이밍에 알려드려요',
                                  icon: Icons.notifications_active_outlined,
                                  children: [
                                    _SwitchTile(
                                      icon: Icons.notifications_outlined,
                                      title: '레슨 알림 사용',
                                      subtitle: _lessonEnabled
                                          ? '레슨 시작 전 알림을 사용 중입니다'
                                          : '레슨 알림이 꺼져 있습니다',
                                      value: _lessonEnabled,
                                      onChanged: (value) {
                                        setState(() {
                                          _lessonEnabled = value;
                                        });
                                        _markChanged();
                                      },
                                    ),
                                    const _SettingsDivider(),
                                    _ReminderMinuteSelector(
                                      enabled: _lessonEnabled,
                                      selectedMinutes: _selectedMinutes,
                                      options: _minuteOptions,
                                      summary: _selectedMinuteSummary,
                                      onTap: _toggleMinute,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _SectionCard(
                                  title: '알림 방식',
                                  subtitle: '무음, 진동, 소리 방식을 선택해요',
                                  icon: Icons.volume_up_outlined,
                                  children: [
                                    _ChoiceTile<LessonNotificationAlertStyle>(
                                      enabled: _lessonEnabled,
                                      title: '무음',
                                      subtitle: LessonNotificationAlertStyle
                                          .silent.description,
                                      icon: Icons.notifications_paused_outlined,
                                      value:
                                          LessonNotificationAlertStyle.silent,
                                      groupValue: _alertStyle,
                                      onChanged: (value) {
                                        setState(() {
                                          _alertStyle = value;
                                        });
                                        _markChanged();
                                      },
                                    ),
                                    const _SettingsDivider(),
                                    _ChoiceTile<LessonNotificationAlertStyle>(
                                      enabled: _lessonEnabled,
                                      title: '진동만',
                                      subtitle: LessonNotificationAlertStyle
                                          .vibrationOnly.description,
                                      icon: Icons.vibration_rounded,
                                      value: LessonNotificationAlertStyle
                                          .vibrationOnly,
                                      groupValue: _alertStyle,
                                      onChanged: (value) {
                                        setState(() {
                                          _alertStyle = value;
                                        });
                                        _markChanged();
                                      },
                                    ),
                                    const _SettingsDivider(),
                                    _ChoiceTile<LessonNotificationAlertStyle>(
                                      enabled: _lessonEnabled,
                                      title: '소리 + 진동',
                                      subtitle: LessonNotificationAlertStyle
                                          .soundAndVibration.description,
                                      icon: Icons.volume_up_rounded,
                                      value: LessonNotificationAlertStyle
                                          .soundAndVibration,
                                      groupValue: _alertStyle,
                                      onChanged: (value) {
                                        setState(() {
                                          _alertStyle = value;
                                        });
                                        _markChanged();
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _SectionCard(
                                  title: '기기 모드',
                                  subtitle: '휴대폰 무음/방해금지 설정 반영 방식을 정해요',
                                  icon: Icons.phone_android_rounded,
                                  children: [
                                    _ChoiceTile<LessonNotificationDeviceMode>(
                                      enabled: _lessonEnabled,
                                      title: LessonNotificationDeviceMode
                                          .followDevice.label,
                                      subtitle: LessonNotificationDeviceMode
                                          .followDevice.description,
                                      icon: Icons.phone_iphone_rounded,
                                      value: LessonNotificationDeviceMode
                                          .followDevice,
                                      groupValue: _deviceMode,
                                      onChanged: (value) {
                                        setState(() {
                                          _deviceMode = value;
                                        });
                                        _markChanged();
                                      },
                                    ),
                                    const _SettingsDivider(),
                                    _ChoiceTile<LessonNotificationDeviceMode>(
                                      enabled: _lessonEnabled,
                                      title: LessonNotificationDeviceMode
                                          .appPreferred.label,
                                      subtitle: LessonNotificationDeviceMode
                                          .appPreferred.description,
                                      icon: Icons.app_settings_alt_rounded,
                                      value: LessonNotificationDeviceMode
                                          .appPreferred,
                                      groupValue: _deviceMode,
                                      onChanged: (value) {
                                        setState(() {
                                          _deviceMode = value;
                                        });
                                        _markChanged();
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                _SmartAlarmEntryCard(
                                  enabled: _lessonEnabled,
                                  smartAlarmEnabled: _smartAlarmEnabled,
                                  smartAlarmGapSummary: _smartAlarmGapSummary,
                                  priorityMemoEnabled: _priorityMemoEnabled,
                                  firstLessonEnabled: _firstLessonEnabled,
                                  canUseContractBasisAlarm:
                                      _canUseContractBasisAlarm,
                                  canUseSmartAlarm: _canUseSmartAlarm,
                                  accessLoading: _smartAlarmAccessLoading,
                                  onTap: _openSmartAlarmChatSheet,
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: _save,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: kNotifyPrimary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 15,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      '알림 설정 저장',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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

class _NotificationHeader extends StatelessWidget {
  const _NotificationHeader({
    required this.onBackTap,
    required this.lessonEnabled,
    required this.selectedMinuteSummary,
    required this.alertStyleLabel,
    required this.smartAlarmEnabled,
    required this.canUseSmartAlarm,
    required this.priorityMemoEnabled,
    required this.firstLessonEnabled,
    required this.canUseContractBasisAlarm,
  });

  final VoidCallback onBackTap;
  final bool lessonEnabled;
  final String selectedMinuteSummary;
  final String alertStyleLabel;
  final bool smartAlarmEnabled;
  final bool canUseSmartAlarm;
  final bool priorityMemoEnabled;
  final bool firstLessonEnabled;
  final bool canUseContractBasisAlarm;

  String get _headline {
    if (!lessonEnabled) {
      return '알림이 꺼져 있어요';
    }

    if (smartAlarmEnabled && canUseSmartAlarm) {
      return 'MORE 스마트 알림';
    }

    return '기본 레슨 알림';
  }

  String get _message {
    if (!lessonEnabled) {
      return '필요한 알림을 받으려면 레슨 알림을 켜주세요.';
    }

    if (smartAlarmEnabled && canUseSmartAlarm) {
      return canUseContractBasisAlarm
          ? 'AI FC가 레슨 흐름과 레슨일지 메모를 함께 보고 필요한 알림을 골라드려요.'
          : 'AI FC가 연속 레슨 흐름을 보고 불필요한 알림을 줄여드려요. 스케줄 메모는 알림에 함께 표시돼요.';
    }

    return '선택한 시간마다 모든 레슨 알림을 받아요.';
  }

  List<String> get _chips {
    if (!lessonEnabled) {
      return const [
        '레슨 알림 OFF',
        '설정 대기',
      ];
    }

    final chips = <String>[
      '레슨 알림 ON',
      selectedMinuteSummary,
      alertStyleLabel,
    ];

    if (smartAlarmEnabled && canUseSmartAlarm) {
      final smartParts = <String>['스마트 ON'];

      if (canUseContractBasisAlarm) {
        smartParts.add('세미프로 사용');
        smartParts.add('레슨일지 메모');
      } else {
        smartParts.add('빈 시간 기준');
        smartParts.add('스케줄 메모 표시');
      }

      chips.add(smartParts.join(' · '));
    } else {
      chips.add('기본 알림');
    }

    return chips;
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final gradient = context.mtfHeaderGradient;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(16, topPadding + 12, 16, 20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                InkWell(
                  onTap: onBackTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    '알림 설정',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  lessonEnabled
                      ? smartAlarmEnabled && canUseSmartAlarm
                          ? Icons.auto_awesome_rounded
                          : Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  color: Colors.white,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _headline,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _message,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11.7,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: _chips.map((chip) {
              return _HeaderStatusChip(text: chip);
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _HeaderStatusChip extends StatelessWidget {
  const _HeaderStatusChip({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          height: 1.0,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.subtitle,
    this.icon,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = Theme.of(context).extension<MtfThemeTokens>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: tokens.notificationCardSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scheme.outline),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 20,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Switch.adaptive(
              value: value,
              activeColor: scheme.secondary,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderMinuteSelector extends StatelessWidget {
  const _ReminderMinuteSelector({
    required this.enabled,
    required this.selectedMinutes,
    required this.options,
    required this.summary,
    required this.onTap,
  });

  final bool enabled;
  final List<int> selectedMinutes;
  final List<int> options;
  final String summary;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '알림 시간',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '여러 개를 선택하면 각각 알림이 울려요.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((minute) {
                final selected = selectedMinutes.contains(minute);

                return ChoiceChip(
                  label: Text('$minute분 전'),
                  selected: selected,
                  onSelected: enabled ? (_) => onTap(minute) : null,
                  showCheckmark: false,
                  selectedColor: scheme.secondaryContainer,
                  backgroundColor: scheme.surfaceContainerHighest,
                  side: BorderSide(
                    color: selected ? scheme.secondary : scheme.outline,
                  ),
                  labelStyle: TextStyle(
                    color: selected
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 9),
            Text(
              '선택됨: $summary',
              style: TextStyle(
                color: scheme.secondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceTile<T> extends StatelessWidget {
  const _ChoiceTile({
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final bool enabled;
  final String title;
  final String subtitle;
  final IconData icon;
  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;
    final scheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: InkWell(
        onTap: enabled ? () => onChanged(value) : null,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: selected
                      ? scheme.secondaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: selected ? scheme.secondary : scheme.onSurface,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? scheme.secondary : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GapSelector extends StatelessWidget {
  const _GapSelector({
    required this.enabled,
    required this.selectedGapMinutes,
    required this.options,
    required this.summary,
    required this.onChanged,
  });

  final bool enabled;
  final int selectedGapMinutes;
  final List<int> options;
  final String summary;
  final ValueChanged<int> onChanged;

  String _labelFor(int value) {
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.48,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '빈 시간 기준',
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 13.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '이 시간 이상 비어 있으면 다음 레슨 전에 알려드려요.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((gap) {
                final selected = gap == selectedGapMinutes;

                return ChoiceChip(
                  label: Text(_labelFor(gap)),
                  selected: selected,
                  onSelected: enabled ? (_) => onChanged(gap) : null,
                  showCheckmark: false,
                  selectedColor: scheme.secondaryContainer,
                  backgroundColor: scheme.surfaceContainerHighest,
                  side: BorderSide(
                    color: selected ? scheme.secondary : scheme.outline,
                  ),
                  labelStyle: TextStyle(
                    color: selected
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 9),
            Text(
              '현재 기준: $summary',
              style: TextStyle(
                color: scheme.secondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  const _InfoBox({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: tokens.notificationLockedSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outline,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onSurfaceVariant,
          fontSize: 11.5,
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  const _SettingsDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _SmartAlarmEntryCard extends StatelessWidget {
  const _SmartAlarmEntryCard({
    required this.enabled,
    required this.smartAlarmEnabled,
    required this.smartAlarmGapSummary,
    required this.canUseSmartAlarm,
    required this.accessLoading,
    required this.onTap,
    required this.priorityMemoEnabled,
    required this.firstLessonEnabled,
    required this.canUseContractBasisAlarm,
  });

  final bool enabled;
  final bool smartAlarmEnabled;
  final String smartAlarmGapSummary;
  final bool canUseSmartAlarm;
  final bool accessLoading;
  final VoidCallback onTap;
  final bool priorityMemoEnabled;
  final bool firstLessonEnabled;
  final bool canUseContractBasisAlarm;

  @override
  Widget build(BuildContext context) {
    final bool locked = !canUseSmartAlarm;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;

    String statusText() {
      if (accessLoading) {
        return '등급 정보를 확인하고 있어요';
      }

      if (!enabled) {
        return '레슨 알림이 꺼져 있어요';
      }

      if (!canUseSmartAlarm) {
        return 'Semi-Pro부터 사용할 수 있어요';
      }

      if (smartAlarmEnabled) {
        final parts = <String>[
          '사용 중',
          smartAlarmGapSummary,
        ];

        if (canUseContractBasisAlarm) {
          parts.add('계약서/레슨일지 메모');
          parts.add('첫 레슨 판단');
        } else {
          parts.add('연속 레슨 생략');
          parts.add('스케줄 메모 표시');
        }

        return parts.join(' · ');
      }

      return '꺼짐 · 선택한 기본 알림 시간대로 알려드려요';
    }

    String descriptionText() {
      if (accessLoading) {
        return '잠시만 기다려주세요. 등급 정보를 확인하고 있어요.';
      }

      if (!enabled) {
        return '레슨 알림을 켜면 기본 알림과 MORE 스마트 알림을 설정할 수 있어요.';
      }

      if (!canUseSmartAlarm) {
        return '현재는 기본 레슨 알림을 사용할 수 있어요. Semi-Pro부터는 빈 시간 기준으로 연속 레슨 알림을 줄일 수 있어요.';
      }

      if (canUseContractBasisAlarm) {
        return 'AI FC가 레슨 흐름, 계약서, 레슨일지 메모를 함께 보고 필요한 알림을 골라드려요.';
      }

      return 'AI FC가 연속 레슨 흐름을 보고 불필요한 알림을 줄여드려요. 스케줄표 메모는 알림에 함께 표시돼요.';
    }

    return Opacity(
      opacity: enabled ? 1 : 0.64,
      child: InkWell(
        onTap: accessLoading ? null : onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: locked
                ? tokens.notificationLockedSurface
                : tokens.notificationCardSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: locked ? scheme.outline : scheme.secondary,
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: locked
                      ? scheme.surfaceContainerHighest
                      : scheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  locked
                      ? Icons.lock_outline_rounded
                      : Icons.auto_awesome_rounded,
                  color: locked
                      ? scheme.onSurfaceVariant
                      : scheme.onSecondaryContainer,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MORE 스마트 알림',
                      style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusText(),
                      style: TextStyle(
                        color:
                            locked ? scheme.onSurfaceVariant : scheme.secondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (enabled &&
                        canUseSmartAlarm &&
                        !canUseContractBasisAlarm) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFDDD6FE),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.workspace_premium_rounded,
                              size: 16,
                              color: Color(0xFF4F46E5),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Semi-Pro부터 계약서, 레슨일지 메모, 첫 레슨/신규회원 판단까지 함께 확인해요.',
                                style: TextStyle(
                                  fontSize: 10.8,
                                  height: 1.35,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4C1D95),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (enabled && !accessLoading && !canUseSmartAlarm) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(11, 9, 11, 9),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFFFDE68A),
                          ),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 16,
                              color: Color(0xFFD97706),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Semi-Pro부터 MORE 스마트 알림을 사용할 수 있어요. 지금은 선택한 기본 알림 시간대로 레슨 시작 전에 알려드려요.',
                                style: TextStyle(
                                  fontSize: 10.8,
                                  height: 1.35,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Text(
                      descriptionText(),
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    if (enabled &&
                        canUseSmartAlarm &&
                        !canUseContractBasisAlarm) ...[
                      const SizedBox(height: 10),
                      // Semi-Pro 안내 박스
                    ],
                    if (enabled && !accessLoading && !canUseSmartAlarm) ...[
                      const SizedBox(height: 10),
                      // Semi-Pro 잠금 안내 박스
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                accessLoading
                    ? Icons.hourglass_empty_rounded
                    : Icons.chevron_right_rounded,
                color: locked ? scheme.onSurfaceVariant : scheme.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
