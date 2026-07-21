import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';

import '../utils/member_input_validation.dart';
import '../utils/membership_pause_status_utils.dart';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:mtf_app/pages/contract_page.dart';
import 'package:mtf_app/pages/personal_training_log_page.dart'
    show PersonalTrainingLogPage;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mtf_app/pages/training_log_consent_page.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'membership_contract_page.dart';

import '../services/app_tier_access_service.dart';
import '../services/lesson_product_service.dart';
import '../services/inbody_camera_permission_service.dart';
import '../widgets/aifc_tier_guide_chat_sheet.dart';

import '../aifc/core/aifc_avatar.dart';
import '../aifc/core/aifc_nickname.dart';

import '../widgets/aifc_info_chat_sheet.dart';
import '../widgets/aifc_option_chat_sheet.dart';
import '../widgets/aifc_tier_feature_gate_sheet.dart';
import '../widgets/aifc_care_milestone_chat_sheet.dart';
import '../widgets/mtf_floating_more_menu.dart';
import '../widgets/aifc_contract_history_chat_sheet.dart';
import '../widgets/aifc_interaction.dart';
import '../widgets/aifc_confirm_chat_sheet.dart';
import '../widgets/aifc_badge_chat_sheet.dart';

const Color kPagePrimary = Color(0xFF4F46E5);
const Color kPagePrimary2 = Color(0xFF9333EA);
const Color kPageBg = Color(0xFFF8FAFC);
const Color kPageBorder = Color(0xFFE5E7EB);
const Color kPageText = Color(0xFF111827);
const Color kPageMuted = Color(0xFF6B7280);
const Color kPageFieldBg = Color(0xFFF8FAFC);

enum AchievementBadgeCode {
  lesson100,
  bodyProfileDone,
  competitionDone,
  weddingDone,
  ddayDone,
  reregister10,
  longTerm,
  attendance,
  manual,
}

class AchievementBadge {
  const AchievementBadge({
    required this.id,
    required this.title,
    required this.code,
    required this.type,
    required this.source,
    required this.isRepresentative,
    required this.earnedAt,
    this.sourceGoalId,
  });

  final String id;
  final String title;
  final AchievementBadgeCode code;
  final String type; // auto / manual
  final String source;
  final bool isRepresentative;
  final DateTime earnedAt;
  final String? sourceGoalId;

  bool get isAuto => type == 'auto';
  bool get isManual => type == 'manual';

  static DateTime _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  static AchievementBadgeCode _codeFromString(String value) {
    return AchievementBadgeCode.values.firstWhere(
      (code) => code.name == value,
      orElse: () => AchievementBadgeCode.manual,
    );
  }

  factory AchievementBadge.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return AchievementBadge(
      id: id,
      title: (data['title'] ?? '').toString().trim(),
      code: _codeFromString((data['code'] ?? 'manual').toString()),
      type: (data['type'] ?? 'auto').toString(),
      source: (data['source'] ?? '').toString(),
      sourceGoalId: (data['sourceGoalId'] ?? '').toString().trim().isEmpty
          ? null
          : (data['sourceGoalId'] ?? '').toString().trim(),
      isRepresentative: data['isRepresentative'] == true,
      earnedAt: _toDate(data['earnedAt']),
    );
  }
}

class _ManualBadgeOption {
  const _ManualBadgeOption({
    required this.title,
    required this.code,
  });

  final String title;
  final AchievementBadgeCode code;
}

AchievementBadge? _resolveRepresentativeBadge(
  List<AchievementBadge> badges,
) {
  if (badges.isEmpty) return null;

  final selected = badges.where((badge) => badge.isRepresentative).toList();
  if (selected.isNotEmpty) return selected.first;

  return null;
}

List<Color> _resolveCardGradient(String grade, String status) {
  final base = _gradeBaseColors(grade);

  switch (status) {
    case '활성':
      return base;
    case '휴면':
      return base
          .map((c) => _adjustCardColor(
                c,
                saturation: 0.50,
                brightness: 0.75,
              ))
          .toList();
    case '만료':
      return base
          .map((c) => _adjustCardColor(
                c,
                saturation: 0.25,
                brightness: 0.62,
              ))
          .toList();
    default:
      return base;
  }
}

List<Color> _gradeBaseColors(String grade) {
  switch (grade.trim().toUpperCase()) {
    case 'VVIP':
      return [
        Color(0xFF5B21B6),
        Color(0xFF7C3AED),
        Color(0xFFDB2777),
      ];
    case 'VIP':
      return [
        Color(0xFF3730A3),
        Color(0xFF4F46E5),
        Color(0xFF6366F1),
      ];
    case 'GOLD':
      return [
        Color(0xFFB45309),
        Color(0xFFD97706),
        Color(0xFFF59E0B),
      ];
    case 'SILVER':
      return [
        Color(0xFF475569),
        Color(0xFF64748B),
        Color(0xFF94A3B8),
      ];
    case 'BRONZE':
      return [
        Color(0xFF78350F),
        Color(0xFF92400E),
        Color(0xFFB45309),
      ];
    default:
      return [
        Color(0xFF4F46E5),
        Color(0xFF7C3AED),
        Color(0xFF9333EA),
      ];
  }
}

List<Color> _resolveIcChipColors(String grade) {
  switch (grade.trim().toUpperCase()) {
    case 'VVIP':
      return [
        Color(0xFFE0D7FF),
        Color(0xFF7C3AED),
      ];
    case 'VIP':
      return [
        Color(0xFFC7D2FE),
        Color(0xFF4338CA),
      ];
    case 'GOLD':
      return [
        Color(0xFFFDE68A),
        Color(0xFFD97706),
      ];
    case 'SILVER':
      return [
        Color(0xFFE2E8F0),
        Color(0xFF94A3B8),
      ];
    case 'BRONZE':
      return [
        Color(0xFFFCD7AA),
        Color(0xFF92400E),
      ];
    default:
      return [
        Color(0xFFC4B5FD),
        Color(0xFF7C3AED),
      ];
  }
}

List<Color> _resolveBackGradient(List<Color> frontGradient) {
  return frontGradient
      .map((c) => _adjustCardColor(
            c,
            saturation: 0.70,
            brightness: 0.82,
          ))
      .toList();
}

Color _adjustCardColor(
  Color color, {
  required double saturation,
  required double brightness,
}) {
  final hsl = HSLColor.fromColor(color);

  return hsl
      .withSaturation(
        (hsl.saturation * saturation).clamp(0.0, 1.0),
      )
      .withLightness(
        (hsl.lightness * brightness).clamp(0.0, 1.0),
      )
      .toColor();
}

double _membershipCardGroupLetterSpacing(String label) {
  final value = label.trim();

  final isLatin = RegExp(r'^[A-Za-z0-9\s\-_]+$').hasMatch(value);

  if (isLatin) {
    return 4.0;
  }

  return 1.2;
}

class MembershipCardFlip extends StatefulWidget {
  const MembershipCardFlip({
    super.key,
    required this.onBackTap,
    required this.onMoreSelected,
    required this.gradientColors,
    required this.icChipColors,
    required this.avatarImage,
    required this.onAvatarTap,
    required this.onAvatarLongPress,
    required this.name,
    required this.phone,
    required this.lessonType,
    required this.totalSessions,
    required this.remainSessions,
    required this.membershipLabel,
    required this.membershipPeriod,
    required this.daysLeft,
    required this.groupLabel,
    required this.memoText,
    required this.reregisterCount,
    required this.noShowDeductedCount,
    required this.noShowUndeductedCount,
    required this.serviceCount,
    required this.firstRegisteredAt,
    required this.anniversaryLabel,
    required this.anniversaryDate,
    required this.birthdayDate,
    required this.contractSigned,
    required this.contractSignedAt,
    required this.consentAgreed,
    required this.confirmTalkEnabled,
    required this.onMemoTap,
    required this.onContractTap,
    required this.onConsentTap,
    required this.onConfirmTalkToggle,
    required this.badges,
    required this.onBadgeTap,
    this.representativeBadge,
  });

  final VoidCallback onBackTap;
  final ValueChanged<String> onMoreSelected;

  final List<Color> gradientColors;
  final List<Color> icChipColors;
  final ImageProvider<Object>? avatarImage;

  final String name;
  final String phone;
  final String lessonType;
  final int totalSessions;
  final int remainSessions;
  final String membershipLabel;
  final String membershipPeriod;
  final int? daysLeft;
  final String groupLabel;

  final String memoText;
  final int reregisterCount;
  final int noShowDeductedCount;
  final int noShowUndeductedCount;
  final int serviceCount;
  final bool contractSigned;
  final DateTime? contractSignedAt;
  final DateTime? firstRegisteredAt;
  final String anniversaryLabel;
  final DateTime? anniversaryDate;
  final DateTime? birthdayDate;
  final bool consentAgreed;
  final bool confirmTalkEnabled;

  final VoidCallback onAvatarTap;
  final VoidCallback onAvatarLongPress;
  final VoidCallback onMemoTap;
  final VoidCallback onContractTap;
  final VoidCallback onConsentTap;
  final ValueChanged<bool> onConfirmTalkToggle;

  final AchievementBadge? representativeBadge;
  final List<AchievementBadge> badges;
  final ValueChanged<AchievementBadge> onBadgeTap;

  @override
  State<MembershipCardFlip> createState() => _MembershipCardFlipState();
}

class _MembershipCardFlipState extends State<MembershipCardFlip> {
  bool _isFlipped = false;

  void _flip() {
    setState(() {
      _isFlipped = !_isFlipped;
    });
  }

  String _buildMembershipLine() {
    final days = widget.daysLeft;

    final dayText = days == null
        ? ''
        : days >= 0
            ? ' · D-$days'
            : ' · D+${days.abs()}';

    final period = widget.membershipPeriod.trim();

    if (period.isEmpty) {
      return '${widget.membershipLabel}$dayText';
    }

    return '${widget.membershipLabel} · $period$dayText';
  }

  String _backAnniversaryLabel() {
    if (widget.anniversaryDate != null) {
      final label = widget.anniversaryLabel.trim().isEmpty
          ? 'MORE 데이'
          : widget.anniversaryLabel.trim();

      return 'MORE 데이 : $label ${DateFormat('yyyy.MM.dd').format(widget.anniversaryDate!)}';
    }

    if (widget.birthdayDate != null) {
      return 'MORE 데이 : 생일 ${DateFormat('MM.dd').format(widget.birthdayDate!)}';
    }

    return 'MORE 데이 : 미등록';
  }

  String _backAnniversaryShortLabel() {
    if (widget.anniversaryDate != null) {
      final label = widget.anniversaryLabel.trim().isEmpty
          ? '기념일'
          : widget.anniversaryLabel.trim();

      return '$label · ${DateFormat('yyyy.MM.dd').format(widget.anniversaryDate!)}';
    }

    if (widget.birthdayDate != null) {
      return '생일 · ${DateFormat('MM.dd').format(widget.birthdayDate!)}';
    }

    return '미등록';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(
          end: _isFlipped ? math.pi : 0,
        ),
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeOutCubic,
        builder: (context, angle, _) {
          final showBack = angle > math.pi / 2;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(angle),
            child: showBack
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _buildBack(),
                  )
                : _buildFront(),
          );
        },
      ),
    );
  }

  Widget _buildFront() {
    return Container(
      height: double.infinity,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: widget.gradientColors.last.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          const _MembershipCardTextureLayer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onBackTap,
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white.withOpacity(0.30),
                      size: 25,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ' MEMBERSHIP CARD',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.48),
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.4,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: widget.onContractTap,
                      child: Icon(
                        Icons.description_outlined,
                        color: Colors.white.withOpacity(0.68),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 4),
                    MtfFloatingMoreMenuButton<String>(
                      tooltip: '더보기',
                      icon: Icons.more_vert_rounded,
                      iconColor: Colors.white.withOpacity(0.68),
                      iconSize: 24,
                      cardWidth: 212,
                      offset: const Offset(0, 8),
                      onSelected: widget.onMoreSelected,
                      items: const [
                        MtfMoreMenuItem(
                          value: 'history',
                          icon: Icons.description_outlined,
                          label: '지난 레슨계약서',
                          subLabel: '계약 이력 확인',
                        ),
                        MtfMoreMenuItem(
                          value: 'membership_manage',
                          icon: Icons.card_membership_rounded,
                          label: '회원권 관리',
                          subLabel: '정지 이력 · 회원권계약서',
                        ),
                        MtfMoreMenuItem(
                          value: 'badges',
                          icon: Icons.workspace_premium_outlined,
                          label: '메달 전체보기',
                          subLabel: '회원 상태 배지',
                        ),
                        MtfMoreMenuItem(
                          value: 'inbody_scan',
                          icon: Icons.document_scanner_outlined,
                          label: '인바디 사진 읽기',
                          subLabel: '사진에서 수치를 자동 입력',
                        ),
                        MtfMoreMenuItem(
                          value: 'reset',
                          icon: Icons.restart_alt_rounded,
                          label: '입력 리셋',
                          subLabel: '작성 내용 초기화',
                        ),
                        MtfMoreMenuItem(
                          value: 'delete',
                          icon: Icons.delete_outline_rounded,
                          label: '회원 삭제',
                          subLabel: '회원카드 삭제',
                          isDanger: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: widget.onAvatarTap,
                      onLongPress: widget.onAvatarLongPress,
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                          ),
                          color: Colors.white.withOpacity(0.14),
                        ),
                        clipBehavior: Clip.hardEdge,
                        child: widget.avatarImage != null
                            ? Image(
                                image: widget.avatarImage!,
                                fit: BoxFit.cover,
                              )
                            : Icon(
                                Icons.person_rounded,
                                size: 30,
                                color: Colors.white.withOpacity(0.75),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            aifcPersonLabel(widget.name),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.70),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${widget.lessonType} · 총 ${widget.totalSessions}회 / 잔여 ${widget.remainSessions}회',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _MembershipIcChip(
                                colors: widget.icChipColors,
                                representativeBadge: widget.representativeBadge,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _buildMembershipLine(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.82),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _MembershipMagneticStripe(
                groupLabel: widget.groupLabel,
                onTap: _flip,
              ),
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: widget.gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    final backGradient = _resolveBackGradient(widget.gradientColors);

    return Container(
      height: double.infinity,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: backGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: backGradient.last.withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          const _MembershipCardTextureLayer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: widget.onBackTap,
                      child: const SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_left_rounded,
                      color: Colors.white.withOpacity(0.30),
                      size: 25,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'MORE 데이',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.90),
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _MembershipContractWifiIcon(
                      isSigned: widget.contractSigned,
                      onTap: widget.onContractTap,
                    ),
                    const SizedBox(width: 5),
                    _MembershipConsentQr(
                      isAgreed: widget.consentAgreed,
                      accentColor: widget.gradientColors.first,
                      onTap: widget.onConsentTap,
                    ),
                    const SizedBox(width: 5),
                    _MembershipTalkBellIcon(
                      enabled: widget.confirmTalkEnabled,
                      contractSigned: widget.contractSigned,
                      onTap: () {
                        widget.onConfirmTalkToggle(!widget.confirmTalkEnabled);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.only(left: 63),
                  child: Text(
                    _backAnniversaryShortLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.2,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _MembershipSignatureBand(
                  memoText: widget.memoText,
                  contractSigned: widget.contractSigned,
                  contractSignedAt: widget.contractSignedAt,
                  onTap: widget.onMemoTap,
                ),
                const SizedBox(height: 11),
                _MembershipBackStats(
                  reregisterCount: widget.reregisterCount,
                  noShowDeducted: widget.noShowDeductedCount,
                  noShowUndeducted: widget.noShowUndeductedCount,
                  serviceCount: widget.serviceCount,
                  firstRegisteredAt: widget.firstRegisteredAt,
                ),
                const Spacer(),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: _MembershipBadgeSlotRow(
                        badges: widget.badges,
                        onBadgeTap: widget.onBadgeTap,
                      ),
                    ),
                    const SizedBox(width: 7),
                    _MembershipHologramButton(
                      onTap: _flip,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipIcChip extends StatelessWidget {
  const _MembershipIcChip({
    required this.colors,
    this.representativeBadge,
  });

  final List<Color> colors;
  final AchievementBadge? representativeBadge;

  @override
  Widget build(BuildContext context) {
    final badge = representativeBadge;

    if (badge != null) {
      return AchievementIcChip(
        code: badge.code,
        width: 48,
        height: 36,
      );
    }

    return Container(
      width: 48,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        border: Border.all(
          color: Colors.white.withOpacity(0.28),
        ),
      ),
      child: CustomPaint(
        painter: _MembershipIcChipPainter(),
      ),
    );
  }
}

class _MembershipIcChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.28)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      linePaint,
    );

    canvas.drawLine(
      Offset(size.width / 2, 0),
      Offset(size.width / 2, size.height),
      linePaint,
    );

    final centerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: 15,
        height: 12,
      ),
      const Radius.circular(2),
    );

    canvas.drawRRect(
      centerRect,
      Paint()
        ..color = Colors.white.withOpacity(0.20)
        ..style = PaintingStyle.fill,
    );

    canvas.drawRRect(
      centerRect,
      Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MembershipMagneticStripe extends StatelessWidget {
  const _MembershipMagneticStripe({
    required this.groupLabel,
    required this.onTap,
  });

  final String groupLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label =
        groupLabel.trim().isEmpty ? 'MORE THAN GYM' : groupLabel.trim();

    final displayLabel = RegExp(r'^[A-Za-z0-9\s\-_]+$').hasMatch(label)
        ? label.toUpperCase()
        : label;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0E0E0E),
              Color(0xFF1C1C1C),
              Color(0xFF0E0E0E),
            ],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Color(0x0DFFFFFF),
                    Color(0x14FFFFFF),
                    Color(0x0DFFFFFF),
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.35, 0.5, 0.65, 1.0],
                ),
              ),
            ),
            Positioned(
              left: 14,
              child: Row(
                children: [
                  Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white.withOpacity(0.35),
                    size: 28,
                  ),
                  Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white.withOpacity(0.15),
                    size: 28,
                  ),
                ],
              ),
            ),
            Positioned(
              right: 14,
              child: Row(
                children: [
                  Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white.withOpacity(0.15),
                    size: 28,
                  ),
                  Icon(
                    Icons.chevron_left_rounded,
                    color: Colors.white.withOpacity(0.35),
                    size: 28,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 46),
              child: Text(
                displayLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white.withOpacity(0.55),
                  letterSpacing:
                      _membershipCardGroupLetterSpacing(displayLabel),
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.80),
                      offset: const Offset(0, 1),
                      blurRadius: 3,
                    ),
                    Shadow(
                      color: Colors.white.withOpacity(0.08),
                      offset: const Offset(0, -1),
                      blurRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembershipSignatureBand extends StatelessWidget {
  const _MembershipSignatureBand({
    required this.memoText,
    required this.contractSigned,
    required this.contractSignedAt,
    required this.onTap,
  });

  final String memoText;
  final bool contractSigned;
  final DateTime? contractSignedAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final memo = memoText.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AUTHORIZED SIGNATURE · SPECIAL NOTE',
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.3,
            color: Colors.white.withOpacity(0.28),
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 38),
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.91),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(
                    painter: _MembershipSignatureLinePainter(),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const RotatedBox(
                      quarterTurns: 1,
                      child: Text(
                        'NOTE',
                        style: TextStyle(
                          fontSize: 7,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF9CA3AF),
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        memo.isEmpty ? '탭하여 메모 입력' : memo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          fontStyle: FontStyle.italic,
                          color: memo.isEmpty
                              ? const Color(0xFFD1D5DB)
                              : const Color(0xFF374151),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3FF),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '✎',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFA78BFA),
                        ),
                      ),
                    ),
                  ],
                ),
                if (contractSigned && contractSignedAt != null)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Text(
                      '✓ Signed · ${DateFormat('yyyy.MM.dd').format(contractSignedAt!)}',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF34D399).withOpacity(0.58),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MembershipSignatureLinePainter extends CustomPainter {
  const _MembershipSignatureLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.052)
      ..strokeWidth = 0.5;

    for (double y = 18; y < size.height; y += 18) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MembershipBackStats extends StatelessWidget {
  const _MembershipBackStats({
    required this.reregisterCount,
    required this.noShowDeducted,
    required this.noShowUndeducted,
    required this.serviceCount,
    required this.firstRegisteredAt,
  });

  final int reregisterCount;
  final int noShowDeducted;
  final int noShowUndeducted;
  final int serviceCount;
  final DateTime? firstRegisteredAt;

  String _firstRegisteredLabel() {
    if (firstRegisteredAt == null) return '-';
    return DateFormat('yy.MM.dd').format(firstRegisteredAt!);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MembershipBackStatItem(
          label: '재등록',
          value: '${reregisterCount}회',
        ),
        const _MembershipBackStatDivider(),
        _MembershipBackStatItem(
          label: '노쇼/미차감',
          value: '$noShowDeducted/$noShowUndeducted회',
        ),
        const _MembershipBackStatDivider(),
        _MembershipBackStatItem(
          label: '서비스',
          value: '${serviceCount}회',
        ),
        const _MembershipBackStatDivider(),
        _MembershipBackStatItem(
          label: '첫 등록일',
          value: _firstRegisteredLabel(),
          valueFontSize: 12.5,
        ),
      ],
    );
  }
}

class _MembershipBackStatItem extends StatelessWidget {
  const _MembershipBackStatItem({
    required this.label,
    required this.value,
    this.valueFontSize = 16,
  });

  final String label;
  final String value;
  final double valueFontSize;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: Colors.white.withOpacity(0.42),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: valueFontSize,
              fontWeight: FontWeight.w900,
              color: Colors.white.withOpacity(0.84),
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MembershipBackStatDivider extends StatelessWidget {
  const _MembershipBackStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 0.5,
      height: 31,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      color: Colors.white.withOpacity(0.14),
    );
  }
}

class _MembershipContractWifiIcon extends StatelessWidget {
  const _MembershipContractWifiIcon({
    required this.isSigned,
    required this.onTap,
  });

  final bool isSigned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSigned
              ? Colors.white.withOpacity(0.12)
              : Colors.white.withOpacity(0.05),
          border: Border.all(
            color: isSigned
                ? Colors.white.withOpacity(0.18)
                : Colors.white.withOpacity(0.09),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size(18, 12),
              painter: _MembershipWifiSignalPainter(isSigned: isSigned),
            ),
            const SizedBox(height: 0),
            Text(
              '레슨계약서',
              style: TextStyle(
                fontSize: 5.2,
                fontWeight: FontWeight.w800,
                color: isSigned
                    ? Colors.white.withOpacity(0.60)
                    : Colors.white.withOpacity(0.22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembershipTalkBellIcon extends StatelessWidget {
  const _MembershipTalkBellIcon({
    required this.enabled,
    required this.contractSigned,
    required this.onTap,
  });

  final bool enabled;
  final bool contractSigned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool active = contractSigned && enabled;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: active
              ? Colors.white.withOpacity(0.12)
              : Colors.white.withOpacity(0.05),
          border: Border.all(
            color: active
                ? Colors.white.withOpacity(0.18)
                : Colors.white.withOpacity(0.09),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  active
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  size: 16,
                  color: active
                      ? Colors.white.withOpacity(0.92)
                      : Colors.white.withOpacity(0.24),
                ),
                const SizedBox(height: 1),
                Text(
                  '톡알림',
                  style: TextStyle(
                    fontSize: 5.4,
                    fontWeight: FontWeight.w900,
                    color: active
                        ? Colors.white.withOpacity(0.60)
                        : Colors.white.withOpacity(0.22),
                  ),
                ),
              ],
            ),
            if (!active)
              Positioned.fill(
                child: CustomPaint(
                  painter: _MembershipBellOffSlashPainter(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MembershipBellOffSlashPainter extends CustomPainter {
  const _MembershipBellOffSlashPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF5050).withOpacity(0.78)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.20),
      Offset(size.width * 0.78, size.height * 0.80),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _MembershipBellOffSlashPainter oldDelegate) {
    return false;
  }
}

class _MembershipWifiSignalPainter extends CustomPainter {
  const _MembershipWifiSignalPainter({
    required this.isSigned,
  });

  final bool isSigned;

  @override
  void paint(Canvas canvas, Size size) {
    final signalPaint = Paint()
      ..color = isSigned
          ? Colors.white.withOpacity(0.92)
          : Colors.white.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()
      ..color = isSigned
          ? Colors.white.withOpacity(0.92)
          : Colors.white.withOpacity(0.22);

    final cx = size.width / 2;
    final baseY = size.height - 3;

    // 아래 점
    canvas.drawCircle(
      Offset(cx, baseY),
      2.2,
      dotPaint,
    );

    // 위로 퍼지는 와이파이 3단
    for (final radius in [5.0, 8.5, 12.0]) {
      canvas.drawArc(
        Rect.fromCircle(
          center: Offset(cx, baseY),
          radius: radius,
        ),
        math.pi * 1.18,
        math.pi * 0.64,
        false,
        signalPaint,
      );
    }

    // 미완료 취소선
    if (!isSigned) {
      canvas.drawLine(
        Offset(size.width * 0.18, size.height * 0.16),
        Offset(size.width * 0.84, size.height * 0.84),
        Paint()
          ..color = const Color(0xFFFF5050).withOpacity(0.82)
          ..strokeWidth = 2.1
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MembershipWifiSignalPainter oldDelegate) {
    return oldDelegate.isSigned != isSigned;
  }
}

class _MembershipConsentQr extends StatelessWidget {
  const _MembershipConsentQr({
    required this.isAgreed,
    required this.accentColor,
    required this.onTap,
  });

  final bool isAgreed;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isAgreed ? Colors.white : Colors.white.withOpacity(0.05),
          border: isAgreed
              ? null
              : Border.all(
                  color: Colors.white.withOpacity(0.09),
                ),
        ),
        child: isAgreed
            ? Padding(
                padding: const EdgeInsets.all(3),
                child: CustomPaint(
                  painter: _MembershipQrPainter(accentColor: accentColor),
                ),
              )
            : Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_2_rounded,
                      size: 15,
                      color: Colors.white.withOpacity(0.26),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '동의필요',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 6.2,
                        fontWeight: FontWeight.w900,
                        color: Colors.white.withOpacity(0.34),
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _MembershipQrPainter extends CustomPainter {
  const _MembershipQrPainter({
    required this.accentColor,
  });

  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = accentColor.withOpacity(0.90);
    final cell = size.width / 9;

    for (final pos in [
      [0.0, 0.0],
      [6.0, 0.0],
      [0.0, 6.0],
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            pos[0] * cell,
            pos[1] * cell,
            cell * 3,
            cell * 3,
          ),
          const Radius.circular(1),
        ),
        paint,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            (pos[0] + 1) * cell,
            (pos[1] + 1) * cell,
            cell,
            cell,
          ),
          const Radius.circular(0.5),
        ),
        Paint()..color = Colors.white,
      );
    }

    for (final point in [
      [4, 0],
      [3, 2],
      [5, 1],
      [3, 4],
      [4, 4],
      [6, 4],
      [4, 5],
      [6, 6],
      [7, 6],
      [3, 7],
      [4, 7],
      [7, 8],
    ]) {
      canvas.drawRect(
        Rect.fromLTWH(
          point[0] * cell,
          point[1] * cell,
          cell * 0.85,
          cell * 0.85,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MembershipQrPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}

class _MembershipHologramButton extends StatefulWidget {
  const _MembershipHologramButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  State<_MembershipHologramButton> createState() =>
      _MembershipHologramButtonState();
}

class _MembershipHologramButtonState extends State<_MembershipHologramButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shine;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );

    _shine = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    await _controller.forward(from: 0);
    if (!mounted) return;
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _shine,
        builder: (context, _) {
          return Transform.scale(
            scale: 1.0 + (_shine.value * 0.05),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: Colors.white.withOpacity(0.38 + (_shine.value * 0.30)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF67E8F9)
                        .withOpacity(0.12 + (_shine.value * 0.25)),
                    blurRadius: 10 + (_shine.value * 10),
                    spreadRadius: _shine.value * 1.4,
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: CustomPaint(
                painter: _MembershipHologramPainter(
                  shineValue: _shine.value,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MembershipHologramPainter extends CustomPainter {
  const _MembershipHologramPainter({
    this.shineValue = 0,
  });

  final double shineValue;

  @override
  void paint(Canvas canvas, Size size) {
    final colors = [
      const Color(0xBFFF0064),
      const Color(0xBFFFC800),
      const Color(0xBF00FF78),
      const Color(0xBF00B4FF),
      const Color(0xBF8C00FF),
      const Color(0xBFFF0064),
      const Color(0xBFFFC800),
      const Color(0xBF00FF78),
      const Color(0xBF00B4FF),
    ];

    final cellWidth = size.width / 3;
    final cellHeight = size.height / 3;

    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        canvas.drawRect(
          Rect.fromLTWH(
            col * cellWidth,
            row * cellHeight,
            cellWidth,
            cellHeight,
          ),
          Paint()..color = colors[row * 3 + col],
        );
      }
    }

    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.07)
      ..strokeWidth = 0.5;

    for (double x = 0; x < size.width; x += 4) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        gridPaint,
      );
    }

    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }

    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.30 + shineValue * 0.35),
            Colors.transparent,
            const Color(0xFF67E8F9).withOpacity(0.12 + shineValue * 0.20),
            const Color(0xFFFF4FD8).withOpacity(0.10 + shineValue * 0.18),
          ],
          stops: const [0.0, 0.38, 0.68, 1.0],
        ).createShader(Offset.zero & size),
    );

    final shineX = -size.width + (size.width * 2.2 * shineValue);

    canvas.drawRect(
      Rect.fromLTWH(shineX, 0, size.width * 0.38, size.height),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.45),
            Colors.white.withOpacity(0.0),
          ],
        ).createShader(Offset.zero & size),
    );

    final flipPainter = TextPainter(
      text: TextSpan(
        text: 'FLIP',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: Colors.white.withOpacity(0.80),
          letterSpacing: 2.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    flipPainter.paint(
      canvas,
      Offset(
        (size.width - flipPainter.width) / 2,
        (size.height - flipPainter.height) / 2 - 4,
      ),
    );

    final subPainter = TextPainter(
      text: TextSpan(
        text: 'TAP TO FRONT',
        style: TextStyle(
          fontSize: 4.6,
          fontWeight: FontWeight.w800,
          color: Colors.white.withOpacity(0.80),
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    subPainter.paint(
      canvas,
      Offset(
        (size.width - subPainter.width) / 2,
        (size.height - subPainter.height) / 2 + 7,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _MembershipHologramPainter oldDelegate) {
    return oldDelegate.shineValue != shineValue;
  }
}

class _MembershipCardTextureLayer extends StatelessWidget {
  const _MembershipCardTextureLayer();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: CustomPaint(
        painter: _MembershipTexturePainter(),
      ),
    );
  }
}

class _MembershipTexturePainter extends CustomPainter {
  const _MembershipTexturePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.028)
      ..strokeWidth = 0.5;

    for (double x = -size.width; x < size.width * 2; x += 25) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CareMilestoneItem {
  const _CareMilestoneItem({
    required this.id,
    required this.title,
    required this.status,
    required this.type,
    this.dueDate,
  });

  final String id;
  final String title;
  final String status;
  final String type;
  final DateTime? dueDate;

  bool get isActive => status != 'done' && status != 'archived';
  bool get isDone => status == 'done';
  bool get isManual => type == 'manual';
  bool get isAuto => type == 'auto';

  static DateTime? _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.tryParse(value);
    return null;
  }

  factory _CareMilestoneItem.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return _CareMilestoneItem(
      id: id,
      title: (data['title'] ?? '').toString().trim(),
      status: (data['status'] ?? 'active').toString().trim(),
      type: (data['type'] ?? 'auto').toString().trim(),
      dueDate: _toDate(data['dueDate']),
    );
  }
}

class _MemberGroupOption {
  const _MemberGroupOption({
    required this.id,
    required this.label,
  });

  final String id;
  final String label;
}

class _PostcodeSearchResult {
  const _PostcodeSearchResult({
    required this.zonecode,
    required this.address,
  });

  final String zonecode;
  final String address;
}

class _MemberGradeTheme {
  final List<Color> gradient;
  final Color accent;
  final Color border;

  const _MemberGradeTheme({
    required this.gradient,
    required this.accent,
    required this.border,
  });
}

class _ContractHistoryItem {
  final String title;
  final String subtitle;
  final String badge;
  final bool isCurrent;

  const _ContractHistoryItem({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.isCurrent,
  });
}

enum _MembershipPauseConfirmAction {
  reset,
  confirm,
  cancel,
}

class _MembershipPauseHistoryItem {
  const _MembershipPauseHistoryItem({
    required this.type,
    required this.at,
    this.plannedDays,
    this.actualDays,
    this.resumeDueAt,
    this.extendedEndAt,
  });

  final String type;
  final DateTime at;
  final int? plannedDays;
  final int? actualDays;
  final DateTime? resumeDueAt;
  final DateTime? extendedEndAt;

  bool get isPause => type == 'pause';
  bool get isResume => type == 'resume';

  static DateTime? _dateFromAny(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  static int? _intFromAny(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString());
  }

  factory _MembershipPauseHistoryItem.fromMap(Map<String, dynamic> data) {
    return _MembershipPauseHistoryItem(
      type: (data['type'] ?? '').toString().trim(),
      at: _dateFromAny(data['at']) ?? DateTime.now(),
      plannedDays: _intFromAny(data['plannedDays']),
      actualDays: _intFromAny(data['actualDays']),
      resumeDueAt: _dateFromAny(data['resumeDueAt']),
      extendedEndAt: _dateFromAny(data['extendedEndAt']),
    );
  }
}

class ClientCardPage extends StatefulWidget {
  final String memberId;
  final bool isEditMode;
  final bool openMembershipManageOnStart;
  final String? personalOwnerUid;

  final String? initialName;
  final String? initialPhone;
  final DateTime? initialVisitDate;
  final DateTime? initialConsultDate;

  const ClientCardPage({
    super.key,
    required this.memberId,
    this.isEditMode = false,
    this.openMembershipManageOnStart = false,
    this.personalOwnerUid,
    this.initialName,
    this.initialPhone,
    this.initialVisitDate,
    this.initialConsultDate,
  });

  const ClientCardPage.edit({
    super.key,
    required this.memberId,
    this.initialName,
    this.openMembershipManageOnStart = false,
    this.personalOwnerUid,
  })  : isEditMode = true,
        initialPhone = null,
        initialVisitDate = null,
        initialConsultDate = null;

  factory ClientCardPage.newMember({
    Key? key,
    required String memberId,
    String? personalOwnerUid,
  }) {
    return ClientCardPage(
      key: key,
      memberId: memberId,
      isEditMode: false,
      openMembershipManageOnStart: false,
      personalOwnerUid: personalOwnerUid,
    );
  }

  const ClientCardPage.fromQuickRegistration({
    super.key,
    required this.memberId,
    required this.initialName,
    required this.initialPhone,
    this.initialVisitDate,
    this.initialConsultDate,
    this.personalOwnerUid,
  })  : isEditMode = false,
        openMembershipManageOnStart = false;

  factory ClientCardPage.fromAny({
    Key? key,
    required Map<String, dynamic> member,
  }) {
    final id = (member['id'] ?? member['memberId'] ?? '').toString();

    return ClientCardPage(
      key: key,
      memberId: id,
      isEditMode: true,
      openMembershipManageOnStart: false,
      personalOwnerUid: null,
      initialName: member['name'] as String?,
      initialPhone: member['phone'] as String?,
    );
  }

  @override
  State<ClientCardPage> createState() => _ClientCardPageState();
}

enum _MembershipManageAction {
  editPeriod,
  pauseHistory,
  contract,
  archive,
}

class _ClientCardPageState extends State<ClientCardPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameFieldKey = GlobalKey();
  final _genderFieldKey = GlobalKey();
  final _birthFieldKey = GlobalKey<FormFieldState<String>>();
  final _phoneFieldKey = GlobalKey();
  final _lessonMembershipSectionKey = GlobalKey();

  final _picker = ImagePicker();

  Uint8List? _profileBytes;
  String? _photoUrl;

  final _nameC = TextEditingController();
  String _gender = '미입력';
  DateTime? _birthDate;
  final _birthTextC = TextEditingController();
  final _birthFocusNode = FocusNode();
  final _phoneC = TextEditingController();

  final _postalC = TextEditingController();
  final _addrC = TextEditingController();
  final _addrDetailC = TextEditingController();

  String _membershipGrade = 'GOLD';
  final _jobC = TextEditingController();
  final _trainerC = TextEditingController();

  static const String _customLessonTypeValue = '__custom_lesson_type__';

  final _customLessonTypeC = TextEditingController();

  String _lessonType = '미입력';
  String _memberStatus = '활성';
  bool _lessonsNotRegistered = false;
  final _totalSessionsC = TextEditingController(text: '0');
  final _remainSessionsC = TextEditingController(text: '0');

  bool _didOpenMembershipManageOnStart = false;
  bool _membershipNotRegistered = false;
  int? _termMonths;
  int? _customDays;
  DateTime? _passStart;
  DateTime? _passEnd;
  DateTime? _lastRegisteredAt;
  DateTime? _lastLogAt;
  int _noShowDeductedCount = 0;
  int _noShowUndeductedCount = 0;
  int _serviceSessionCount = 0;
  int _reregisterCount = 0;
  DateTime? _lastReregisterAt;

  bool _membershipPaused = false;
  DateTime? _membershipPausedAt;
  String _membershipPauseReason = '';

  int _membershipPausePlannedDays = 0;
  DateTime? _membershipResumeDueAt;
  int _membershipPauseActualDays = 0;
  int _membershipPauseUsedDays = 0;

  bool _membershipContractDraftExists = false;
  String _membershipContractStatus = '';
  int? _membershipContractMaxPauseDays;

  final _noShowDeductedC = TextEditingController(text: '0');
  final _noShowUndeductedC = TextEditingController(text: '0');
  final _serviceSessionC = TextEditingController(text: '0');
  final _reregisterCountC = TextEditingController(text: '0');

  bool _inbodyNotProvided = false;
  final _diseaseC = TextEditingController();
  final _medicineC = TextEditingController();
  final _heightC = TextEditingController(text: '170.0');
  final _weightC = TextEditingController(text: '65.0');
  final _bfPctC = TextEditingController(text: '18.5');
  final _smmC = TextEditingController(text: '29.0');
  final _bfKgC = TextEditingController(text: '12.0');
  String? _latestInbodyImageUrl;
  DateTime? _latestInbodyMeasuredAt;

  bool _femaleConditionEnabled = false;
  final _femaleConditionLastStartC = TextEditingController();
  final _femaleConditionCycleC = TextEditingController(text: '28');
  final _femaleConditionMemoC = TextEditingController();

  DateTime? _nextReservation;
  final _noteC = TextEditingController();
  final _noteFocusNode = FocusNode();
  final _noteFieldKey = GlobalKey();

  DateTime? _anniversaryDate;
  final _anniversaryLabelC = TextEditingController(text: '기념일');
  final _specialEventC = TextEditingController();
  final List<_CareMilestoneItem> _careMilestones = [];
  final List<AchievementBadge> _achievementBadges = [];
  AchievementBadge? _representativeBadge;
  bool _autoMilestoneEnabled = true;
  bool _ddayFollowUpEnabled = true;
  late final PageController _memoPageController;
  int _memoPageIndex = 0;
  double _memoPageValue = 0.0;

  bool _contractSigned = false;
  DateTime? _contractSignedAt;

  bool _confirmTalkEnabled = false;

  bool _trainingLogConsentAgreed = false;
  DateTime? _trainingLogConsentAgreedAt;

  bool _isHeaderExpanded = false;
  late final PageController _basicInfoPageController;
  int _basicInfoPageIndex = 0;
  late final PageController _memberSetupPageController;
  int _memberSetupPageIndex = 0;
  late final PageController _bodyHealthPageController;
  int _bodyHealthPageIndex = 0;

  bool _showRequiredFieldsNotice = false;
  String? _phoneDuplicateMessage;

  bool _isHeaderCardFlipped = false;

  Timer? _draftTimer;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _memberStatsSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _nextReservationSub;
  Timer? _nextReservationTickTimer;
  List<QueryDocumentSnapshot<Map<String, dynamic>>>
      _nextReservationScheduleDocs = [];
  late final String _draftKey;
  String _headerDisplayName = '';
  String _headerGroupLabel = 'MORE THAN GYM';
  bool _isClientCardLoaded = false;
  bool _newCardAccessResolved = false;
  bool _newCardAccessAllowed = false;
  String _selectedGroupId = '__ungrouped__';
  AppTierAccessSnapshot? _tierAccess;
  bool _isTierAccessLoaded = false;
  final List<_MemberGroupOption> _groupOptions = [
    _MemberGroupOption(id: '__ungrouped__', label: 'MORE THAN GYM'),
  ];

  bool get _isEditMode => widget.isEditMode;
  bool get _isPersonalWorkspace =>
      (widget.personalOwnerUid ?? '').trim().isNotEmpty;

  bool get _canUseSemiProFeatures {
    return (_tierAccess?.tierRank ?? 0) >= 2;
  }

  String get _currentTierLabel {
    return _tierAccess?.tierLabel ?? 'Beginner';
  }

  String get _requiredInfoNudgeKey =>
      'client_card_required_info_nudge_seen_${widget.memberId}_v1';

  String get _milestoneNudgeKey =>
      'client_card_milestone_nudge_seen_${widget.memberId}_v1';

  String _membershipCardGroupLabelText() {
    try {
      final value = _headerGroupLabel.trim();
      return value.isEmpty ? 'MORE THAN GYM' : value;
    } catch (_) {
      return 'MORE THAN GYM';
    }
  }

  void _handleConsentTapFromCard() {
    if (_trainingLogConsentAgreed) {
      _showAifcToast('개인정보동의는 이미 완료되어 있어요.');
      return;
    }

    _openTrainingLogConsent();
  }

  Future<void> _setConfirmTalkEnabledFromCard(bool enabled) async {
    if (!_contractSigned) {
      _showAifcToast('레슨계약서가 연결된 회원부터 톡알림을 설정할 수 있어요.');
      return;
    }

    final previous = _confirmTalkEnabled;

    setState(() {
      _confirmTalkEnabled = enabled;
    });

    try {
      await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .set({
        'notificationSettings': {
          'confirmTalkEnabled': enabled,
          'confirmTalkUpdatedAt': FieldValue.serverTimestamp(),
          'confirmTalkSource': 'client_card_back',
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      final memberName = _nameC.text.trim().isEmpty ? '회원' : _nameC.text.trim();

      final memberLabel = aifcPersonLabel(memberName);

      _showAifcToast(
        enabled
            ? '$memberLabel 레슨 확정 톡알림을 켰어요.'
            : '$memberLabel 레슨 확정 톡알림을 껐어요. 확정 취소 알림은 발송 대상입니다.',
        duration: const Duration(milliseconds: 1900),
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _confirmTalkEnabled = previous;
      });

      _showAifcToast('톡알림 설정을 저장하지 못했어요. 다시 시도해주세요.');
    }
  }

  Future<String> _loadDefaultTrainerName() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('trainer_profile')
          .doc('me')
          .get();

      final data = snap.data();

      final contractTrainerName =
          (data?['contractTrainerName'] ?? '').toString().trim();
      final displayName = (data?['displayName'] ?? '').toString().trim();
      final name = (data?['name'] ?? '').toString().trim();

      if (contractTrainerName.isNotEmpty) return contractTrainerName;
      if (displayName.isNotEmpty) return displayName;
      if (name.isNotEmpty) return name;

      return '';
    } catch (_) {
      return '';
    }
  }

  void _showBadgeBubble(AchievementBadge badge) {
    final title = _achievementBadgeTitle(badge);
    final subtitle = _achievementBadgeSubtitle(badge);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '훈장 정보',
      barrierColor: Colors.black.withOpacity(0.08),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (dialogContext, animation, _, __) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(dialogContext),
                child: Container(color: Colors.transparent),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(top: 86, left: 18, right: 18),
                  child: ScaleTransition(
                    scale: curved,
                    child: FadeTransition(
                      opacity: animation,
                      child: _AchievementBadgeBubble(
                        badge: badge,
                        title: title,
                        subtitle: subtitle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _achievementBadgeTitle(AchievementBadge badge) {
    if (badge.title.trim().isNotEmpty) {
      return badge.title.trim();
    }

    return switch (badge.code) {
      AchievementBadgeCode.lesson100 => '100회 레슨',
      AchievementBadgeCode.bodyProfileDone => '바디프로필 완료',
      AchievementBadgeCode.competitionDone => '대회 완료',
      AchievementBadgeCode.weddingDone => '웨딩촬영 완료',
      AchievementBadgeCode.ddayDone => 'D-DAY 목표 완료',
      AchievementBadgeCode.reregister10 => '재등록 10회',
      AchievementBadgeCode.longTerm => '장기회원',
      AchievementBadgeCode.attendance => '우수 출석',
      AchievementBadgeCode.manual => '메달',
    };
  }

  String _achievementBadgeSubtitle(AchievementBadge badge) {
    final sourceLabel = switch (badge.source) {
      'sessions' => '레슨 기록',
      'goal_dday' => 'D-DAY 목표',
      'trainer' => '담당 강사 부여',
      'test' => '테스트',
      _ => badge.isAuto ? '자동 메달' : '수동 메달',
    };

    return '$sourceLabel · ${DateFormat('yyyy.MM.dd').format(badge.earnedAt)}';
  }

  final List<_ManualBadgeOption> _manualBadgeOptions = const [
    _ManualBadgeOption(
      title: '우수 출석',
      code: AchievementBadgeCode.attendance,
    ),
    _ManualBadgeOption(
      title: '운동 습관 형성',
      code: AchievementBadgeCode.manual,
    ),
    _ManualBadgeOption(
      title: '체중 감량 성공',
      code: AchievementBadgeCode.manual,
    ),
    _ManualBadgeOption(
      title: '근력 향상',
      code: AchievementBadgeCode.manual,
    ),
    _ManualBadgeOption(
      title: '컨디션 회복',
      code: AchievementBadgeCode.manual,
    ),
    _ManualBadgeOption(
      title: '부상 복귀',
      code: AchievementBadgeCode.manual,
    ),
    _ManualBadgeOption(
      title: '트레이너 추천',
      code: AchievementBadgeCode.manual,
    ),
  ];

  String get _pageTitle => 'MEMBERSHIP CARD';

  String get _pageSubtitle {
    if (!_isEditMode) {
      return '신규회원카드';
    }

    final name = _nameC.text.trim();
    if (name.isEmpty) {
      return '회원카드';
    }

    return '${aifcPersonLabel(name)} 회원카드';
  }

  int get _doneSessionValue {
    final total = _totalSessionValue;
    final remain = _remainSessionValue;

    if (total <= 0) return 0;
    return (total - remain).clamp(0, total);
  }

  String get _membershipProgressLabel {
    final total = _totalSessionValue;
    final done = _doneSessionValue;

    if (_lessonsNotRegistered || total <= 0) {
      return '수강권 미등록';
    }

    return '총 ${total}회 중 ${done}회 진행';
  }

  String get _membershipRemainLabel {
    final remain = _remainSessionValue;

    if (_lessonsNotRegistered || _totalSessionValue <= 0) {
      return '잔여 회차 없음';
    }

    return '잔여 ${remain}회';
  }

  @override
  void initState() {
    super.initState();

    _headerDisplayName = (widget.initialName ?? '').trim();
    _nameC.text = widget.initialName ?? '';
    _phoneC.text = formatKoreanMobilePhone(widget.initialPhone ?? '');

    _basicInfoPageController = PageController();
    _memberSetupPageController = PageController();
    _bodyHealthPageController = PageController();
    _memoPageController = PageController();
    _memoPageController.addListener(_handleMemoPageScroll);

    if (widget.initialVisitDate != null) {
      _membershipNotRegistered = false;
      _passStart = widget.initialVisitDate;
    }

    if (widget.initialConsultDate != null) {
      final noteText =
          '최초 방문일: ${DateFormat('yyyy-MM-dd').format(widget.initialVisitDate ?? DateTime.now())}\n'
          '상담 예정: ${DateFormat('yyyy-MM-dd').format(widget.initialConsultDate!)}';
      _noteC.text = noteText;
    }

    _draftKey = 'member_form_draft_${widget.memberId}_v6';

    if (widget.initialName == null && widget.initialPhone == null) {
      _loadDraft();
    }

    if (_isEditMode || !_isPersonalWorkspace) {
      _newCardAccessResolved = true;
      _newCardAccessAllowed = true;
      _startClientCardLoading();
    } else {
      _prepareNewCardAccess();
    }

    _nextReservationTickTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _applyNextReservationFromSchedules(),
    );

    for (final c in [
      _nameC,
      _birthTextC,
      _phoneC,
      _postalC,
      _addrC,
      _addrDetailC,
      _jobC,
      _trainerC,
      _customLessonTypeC,
      _totalSessionsC,
      _remainSessionsC,
      _diseaseC,
      _medicineC,
      _heightC,
      _weightC,
      _bfPctC,
      _smmC,
      _bfKgC,
      _noteC,
      _anniversaryLabelC,
      _specialEventC,
    ]) {
      c.addListener(_debouncedSave);
    }

    _birthFocusNode.addListener(_handleBirthFocusChange);

    _phoneC.addListener(() {
      if (_phoneDuplicateMessage == null) return;
      if (!mounted) return;

      setState(() {
        _phoneDuplicateMessage = null;
      });
    });
  }

  void _startClientCardLoading() {
    _loadInitialClientCardData();
    _bindMemberStatsStream();
    _bindNextReservationStream();
  }

  Future<void> _prepareNewCardAccess() async {
    try {
      final access = await AppTierAccessService.loadPersonalTrainerAccess(
        uid: widget.personalOwnerUid!.trim(),
      );
      final allowed = AppTierAccessService.canUseFeature(
        access,
        AppTierFeatureKey.customerCardCreate,
      );
      if (!mounted) return;
      setState(() {
        _tierAccess = access;
        _isTierAccessLoaded = true;
        _newCardAccessResolved = true;
        _newCardAccessAllowed = allowed;
      });
      if (allowed) {
        _startClientCardLoading();
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          AifcTierFeatureGateSheet.show(
            context: context,
            access: access,
            feature: AppTierFeatureKey.customerCardCreate,
          );
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _newCardAccessResolved = true;
        _newCardAccessAllowed = false;
      });
    }
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _memberStatsSub?.cancel();
    _nextReservationSub?.cancel();
    _nextReservationTickTimer?.cancel();
    _nameC.dispose();
    _birthFocusNode.removeListener(_handleBirthFocusChange);
    _birthFocusNode.dispose();
    _birthTextC.dispose();
    _phoneC.dispose();
    _postalC.dispose();
    _addrC.dispose();
    _addrDetailC.dispose();
    _jobC.dispose();
    _trainerC.dispose();
    _customLessonTypeC.dispose();
    _totalSessionsC.dispose();
    _remainSessionsC.dispose();
    _noShowDeductedC.dispose();
    _noShowUndeductedC.dispose();
    _serviceSessionC.dispose();
    _reregisterCountC.dispose();
    _diseaseC.dispose();
    _medicineC.dispose();
    _heightC.dispose();
    _weightC.dispose();
    _bfPctC.dispose();
    _smmC.dispose();
    _bfKgC.dispose();
    _noteC.dispose();
    _noteFocusNode.dispose();
    _basicInfoPageController.dispose();
    _memberSetupPageController.dispose();
    _bodyHealthPageController.dispose();
    _anniversaryLabelC.dispose();
    _specialEventC.dispose();
    _memoPageController.removeListener(_handleMemoPageScroll);
    _memoPageController.dispose();
    _femaleConditionLastStartC.dispose();
    _femaleConditionCycleC.dispose();
    _femaleConditionMemoC.dispose();
    super.dispose();
  }

  String _groupDocId(String groupId) {
    if (groupId == '__ungrouped__') return 'default_group';
    if (groupId == '__system_dormant__') return 'system_dormant';
    if (groupId == '__system_expired__') return 'system_expired';

    return groupId;
  }

  Future<String> _loadGroupDisplayName(String groupId) async {
    final fallback = switch (groupId) {
      '__ungrouped__' => 'MORE THAN GYM',
      '__system_dormant__' => '휴면회원',
      '__system_expired__' => '만료회원',
      _ => groupId,
    };

    try {
      final groupSnap = await FirebaseFirestore.instance
          .collection('member_groups')
          .doc(_groupDocId(groupId))
          .get();

      final data = groupSnap.data();
      final name = (data?['name'] ?? '').toString().trim();

      if (name.isNotEmpty) {
        return name;
      }
    } catch (_) {}

    return fallback;
  }

  Future<String> _loadDefaultGroupName() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('member_groups')
          .doc('default_group')
          .get();

      final name = (snap.data()?['name'] ?? '').toString().trim();

      if (name.isNotEmpty) {
        return name;
      }
    } catch (_) {}

    return 'MORE THAN GYM';
  }

  void _handleMemoPageScroll() {
    if (!_memoPageController.hasClients) return;

    final page =
        (_memoPageController.page ?? _memoPageIndex.toDouble()).clamp(0.0, 1.0);

    if ((page - _memoPageValue).abs() < 0.015) return;

    setState(() {
      _memoPageValue = page;
    });
  }

  double _memoPagerHeight() {
    // 첫 페이지에 다음 예약일 + SPECIAL NOTE 4줄이 들어가서
    // 작은 화면에서는 288 높이로 overflow가 날 수 있습니다.
    const firstPageHeight = 330.0;
    const secondPageHeight = 456.0;

    final t = _memoPageValue.clamp(0.0, 1.0);

    return firstPageHeight + ((secondPageHeight - firstPageHeight) * t);
  }

  Future<void> _fillDefaultTrainerIfEmpty() async {
    if (_trainerC.text.trim().isNotEmpty) return;

    final trainerName = await _loadDefaultTrainerName();

    if (!mounted) return;
    if (trainerName.trim().isEmpty) return;

    // 기다리는 사이 사용자가 직접 입력했으면 덮어쓰지 않음
    if (_trainerC.text.trim().isNotEmpty) return;

    setState(() {
      _trainerC.text = trainerName.trim();
    });
  }

  String _safeMemberStatus(String? raw) {
    final value = (raw ?? '').trim();
    const allowed = ['활성', '휴면', '만료'];
    return allowed.contains(value) ? value : '활성';
  }

  String _safeMembershipGrade(String? raw) {
    final value = (raw ?? '').trim().toUpperCase();
    const allowed = ['VVIP', 'VIP', 'GOLD', 'SILVER', 'BRONZE'];
    return allowed.contains(value) ? value : 'GOLD';
  }

  String _safeLessonType(String? raw) {
    final value = (raw ?? '').trim();

    if (value.isEmpty) return '미입력';

    return value;
  }

  Future<void> _loadCareMilestonesFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .collection('care_milestones')
          .orderBy('dueDate')
          .get();

      final items = snapshot.docs
          .map((doc) => _CareMilestoneItem.fromFirestore(doc.id, doc.data()))
          .where((item) => item.title.isNotEmpty)
          .toList();

      if (!mounted) return;

      setState(() {
        _careMilestones
          ..clear()
          ..addAll(items);
      });
    } catch (_) {
      // 인덱스나 권한 문제로 실패해도 회원카드 로딩은 막지 않음
    }
  }

  Future<void> _loadAchievementBadgesFromFirestore() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .collection('achievement_badges')
          .orderBy('earnedAt', descending: true)
          .get();

      final badges = snapshot.docs
          .map((doc) => AchievementBadge.fromFirestore(doc.id, doc.data()))
          .where((badge) => badge.title.isNotEmpty)
          .toList();

      if (!mounted) return;

      setState(() {
        _achievementBadges
          ..clear()
          ..addAll(badges);

        _representativeBadge = _resolveRepresentativeBadge(badges);
      });
    } catch (_) {
      // 메달 로드 실패해도 카드 표시를 막지 않음
    }
  }

  Future<void> _upsertAutoAchievementBadge({
    required AchievementBadgeCode code,
    required String title,
    required String source,
    required DateTime earnedAt,
  }) async {
    try {
      final docId = code.name;

      await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .collection('achievement_badges')
          .doc(docId)
          .set({
        'title': title,
        'code': code.name,
        'type': 'auto',
        'source': source,
        'isRepresentative': false,
        'earnedAt': Timestamp.fromDate(earnedAt),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _syncAutoAchievementBadges() async {
    final total = int.tryParse(_totalSessionsC.text.trim()) ?? 0;
    final remain = int.tryParse(_remainSessionsC.text.trim()) ?? 0;
    final done = (total - remain).clamp(0, total);

    final now = DateTime.now();

    if (done >= 100) {
      await _upsertAutoAchievementBadge(
        code: AchievementBadgeCode.lesson100,
        title: '100회 레슨',
        source: 'sessions',
        earnedAt: now,
      );
    }

    if (_reregisterCount >= 10) {
      await _upsertAutoAchievementBadge(
        code: AchievementBadgeCode.reregister10,
        title: '재등록 10회',
        source: 'membership',
        earnedAt: _lastReregisterAt ?? now,
      );
    }

    await _loadAchievementBadgesFromFirestore();
  }

  Future<void> _deleteAchievementBadge(AchievementBadge badge) async {
    final title = _achievementBadgeTitle(badge);

    final ok = await _showAifcConfirm(
      title: '메달을 삭제할까요?',
      message: '$title 메달을 삭제합니다.\n'
          '회원카드의 성취 기록에서 사라져요.',
      cancelText: '취소',
      confirmText: '삭제',
      userCancelText: '취소할게요',
      userConfirmText: '삭제할게요',
      cancelReplyText: '좋아요. 메달은 그대로 둘게요.',
      confirmReplyText: '확인했어요. 메달 삭제를 진행할게요.',
      danger: true,
    );

    if (!ok) return;

    try {
      await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .collection('achievement_badges')
          .doc(badge.id)
          .delete();

      await _loadAchievementBadgesFromFirestore();

      if (!mounted) return;
      _showAifcToast('$title 메달을 삭제했어요.');
    } catch (_) {
      if (!mounted) return;
      _showAifcToast('메달을 삭제하지 못했어요. 다시 시도해주세요.');
    }
  }

  Future<void> _deleteAchievementBadgeDirectly(AchievementBadge badge) async {
    try {
      await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .collection('achievement_badges')
          .doc(badge.id)
          .delete();

      await _loadAchievementBadgesFromFirestore();
    } catch (_) {
      throw Exception('delete_badge_failed');
    }
  }

  Future<void> _addManualAchievementBadge({
    required String title,
    required AchievementBadgeCode code,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) return;

    try {
      final docId =
          'manual_${DateTime.now().millisecondsSinceEpoch}_${cleanTitle.hashCode.abs()}';

      await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .collection('achievement_badges')
          .doc(docId)
          .set({
        'title': cleanTitle,
        'code': code.name,
        'type': 'manual',
        'source': 'trainer',
        'isRepresentative': false,
        'earnedAt': Timestamp.fromDate(DateTime.now()),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _loadAchievementBadgesFromFirestore();

      if (!mounted) return;
      _showAifcToast('$cleanTitle 메달을 추가했어요.');
    } catch (_) {
      if (!mounted) return;
      _showAifcToast('메달을 추가하지 못했어요. 다시 시도해주세요.');
    }
  }

  Future<void> _openAchievementBadgeSheet() async {
    if (!await _guardTierFeature(AppTierFeatureKey.badge)) return;

    await _loadAchievementBadgesFromFirestore();

    if (!mounted) return;

    await AifcBadgeChatSheet.show(
      context: context,
      memberName: _nameC.text.trim().isEmpty ? '회원' : _nameC.text.trim(),
      badges: _achievementBadges,
      nickname: _safeAifcNickname,
      onAddBadge: (title, code) async {
        await _addManualAchievementBadge(
          title: title,
          code: code,
        );
      },
      onDeleteBadge: (badge) async {
        await _deleteAchievementBadgeDirectly(badge);
      },
      onSetRepresentative: (badge) async {
        await _setRepresentativeBadgeDirectly(badge);
      },
      onClearRepresentative: (badge) async {
        await _clearRepresentativeBadgeDirectly(badge);
      },
    );

    await _loadAchievementBadgesFromFirestore();
  }

  Future<void> _openAddAchievementBadgeSheet() async {
    final customController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        final bottomPadding = MediaQuery.of(sheetContext).padding.bottom;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            16,
            16 + bottomPadding + bottomInset,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              final customText = customController.text.trim();

              return SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '메달 추가',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: kPageText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '회원의 긍정적인 성취를 직접 기록해요.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kPageMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _manualBadgeOptions.map((option) {
                        return InkWell(
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            await _addManualAchievementBadge(
                              title: option.title,
                              code: option.code,
                            );
                          },
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F3FF),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFFE9D5FF),
                              ),
                            ),
                            child: Text(
                              option.title,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF6D28D9),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: customController,
                      onChanged: (_) => setSheetState(() {}),
                      decoration: InputDecoration(
                        labelText: '직접 입력',
                        hintText: '예: 3개월 꾸준함, 식단 개선 성공',
                        filled: true,
                        fillColor: kPageFieldBg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: kPageBorder),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: kPageBorder),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: kPagePrimary,
                            width: 1.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: customText.isEmpty
                            ? null
                            : () async {
                                Navigator.pop(sheetContext);
                                await _addManualAchievementBadge(
                                  title: customText,
                                  code: AchievementBadgeCode.manual,
                                );
                              },
                        icon: const Icon(Icons.workspace_premium_rounded),
                        label: const Text('직접 입력 메달 추가'),
                        style: FilledButton.styleFrom(
                          backgroundColor: kPagePrimary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFE5E7EB),
                          disabledForegroundColor: const Color(0xFF9CA3AF),
                          minimumSize: const Size(0, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );

    customController.dispose();
  }

  Future<bool> _showAifcConfirm({
    required String title,
    required String message,
    String cancelText = '취소',
    String confirmText = '확인',
    String? userCancelText,
    String? userConfirmText,
    String cancelReplyText = '좋아요. 진행하지 않을게요.',
    String confirmReplyText = '확인했어요. 이어서 진행할게요.',
    bool danger = false,
  }) {
    return AifcConfirmChatSheet.show(
      context: context,
      nickname: _safeAifcNickname,
      title: title,
      message: message,
      cancelText: cancelText,
      confirmText: confirmText,
      userCancelText: userCancelText,
      userConfirmText: userConfirmText,
      cancelReplyText: cancelReplyText,
      confirmReplyText: confirmReplyText,
      danger: danger,
    );
  }

  Future<void> _setRepresentativeBadge(AchievementBadge badge) async {
    try {
      final ref = FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .collection('achievement_badges');

      final batch = FirebaseFirestore.instance.batch();

      for (final item in _achievementBadges) {
        batch.set(
          ref.doc(item.id),
          {
            'isRepresentative': item.id == badge.id,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      await _loadAchievementBadgesFromFirestore();

      if (!mounted) return;

      _showAifcToast('${_achievementBadgeTitle(badge)} 대표 메달로 설정했어요.');
    } catch (_) {
      if (!mounted) return;

      _showAifcToast('대표 메달을 설정하지 못했어요. 다시 시도해주세요.');
    }
  }

  Future<void> _clearRepresentativeBadgeDirectly(AchievementBadge badge) async {
    try {
      final ref = FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .collection('achievement_badges');

      final batch = FirebaseFirestore.instance.batch();

      for (final item in _achievementBadges) {
        batch.set(
          ref.doc(item.id),
          {
            'isRepresentative': false,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      await _loadAchievementBadgesFromFirestore();
    } catch (_) {
      throw Exception('clear_representative_failed');
    }
  }

  Future<void> _setRepresentativeBadgeDirectly(AchievementBadge badge) async {
    try {
      final ref = FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .collection('achievement_badges');

      final batch = FirebaseFirestore.instance.batch();

      for (final item in _achievementBadges) {
        batch.set(
          ref.doc(item.id),
          {
            'isRepresentative': item.id == badge.id,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();
      await _loadAchievementBadgesFromFirestore();
    } catch (_) {
      throw Exception('set_representative_failed');
    }
  }

  Future<void> _saveMilestoneSettings() async {
    try {
      await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .set({
        'milestoneSettings': {
          'autoMilestoneEnabled': _autoMilestoneEnabled,
          'ddayFollowUpEnabled': _ddayFollowUpEnabled,
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _addManualCareMilestone() async {
    if (!await _guardTierFeature(AppTierFeatureKey.moreFocus)) return;

    final title = _specialEventC.text.trim();
    if (title.isEmpty) return;

    try {
      final ref = FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .collection('care_milestones');

      await ref.add({
        'title': title,
        'type': 'manual',
        'status': 'active',
        'source': 'client_card_manual',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        _specialEventC.clear();
      });

      await _loadCareMilestonesFromFirestore();
      if (!mounted) return;
      _showAifcToast('MORE 포커스를 추가했어요.');
    } catch (_) {
      if (!mounted) return;
      _showAifcToast('MORE 포커스를 추가하지 못했어요. 다시 시도해주세요.');
    }
  }

  Future<void> _completeCareMilestone(_CareMilestoneItem item) async {
    try {
      await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .collection('care_milestones')
          .doc(item.id)
          .set({
        'status': 'done',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _loadCareMilestonesFromFirestore();

      if (!mounted) return;
      _showAifcToast('MORE 포커스를 완료로 기록했어요.');
    } catch (_) {
      if (!mounted) return;
      _showAifcToast('MORE 포커스를 완료 처리하지 못했어요.');
    }
  }

  Future<void> _deleteCareMilestone(_CareMilestoneItem item) async {
    final ok = await _showAifcConfirm(
      title: 'MORE 포커스를 삭제할까요?',
      message: '${item.title} 항목을 삭제합니다.\n'
          '회원 관리 체크포인트에서 사라져요.',
      cancelText: '취소',
      confirmText: '삭제',
      userCancelText: '취소할게요',
      userConfirmText: '삭제할게요',
      cancelReplyText: '좋아요. MORE 포커스는 그대로 둘게요.',
      confirmReplyText: '확인했어요. MORE 포커스 삭제를 진행할게요.',
      danger: true,
    );

    if (!ok) return;

    try {
      await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .collection('care_milestones')
          .doc(item.id)
          .delete();

      await _loadCareMilestonesFromFirestore();

      if (!mounted) return;
      _showAifcToast('MORE 포커스를 삭제했어요.');
    } catch (_) {
      if (!mounted) return;
      _showAifcToast('MORE 포커스를 삭제하지 못했어요.');
    }
  }

  Future<void> _loadTierAccess() async {
    try {
      final access = _isPersonalWorkspace
          ? await AppTierAccessService.loadPersonalTrainerAccess(
              uid: widget.personalOwnerUid!.trim(),
            )
          : await AppTierAccessService.loadTrainerAccess();

      if (!mounted) return;

      setState(() {
        _tierAccess = access;
        _isTierAccessLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _tierAccess = null;
        _isTierAccessLoaded = true;
      });
    }
  }

  Future<void> _loadInitialClientCardData() async {
    final startedAt = DateTime.now();

    await Future.wait([
      _loadMemberGroupOptions(),
      _loadTierAccess(),
      _loadFromFirestore(),
      _loadCareMilestonesFromFirestore(),
      _loadAchievementBadgesFromFirestore(),
    ]);

    final elapsed = DateTime.now().difference(startedAt);
    const minimumDelay = Duration(milliseconds: 220);

    if (elapsed < minimumDelay) {
      await Future.delayed(minimumDelay - elapsed);
    }

    await _fillDefaultTrainerIfEmpty();

    if (!mounted) return;

    setState(() {
      _isClientCardLoaded = true;
    });
  }

  Future<void> _loadMemberGroupOptions() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('member_groups').get();

      final defaultGroupName = await _loadDefaultGroupName();

      final options = <_MemberGroupOption>[
        _MemberGroupOption(
          id: '__ungrouped__',
          label: defaultGroupName,
        ),
      ];

      for (final doc in snapshot.docs) {
        if (doc.id == 'default_group') {
          continue;
        }

        final data = doc.data();
        final name = (data['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        String groupId = doc.id;

        if (doc.id == 'system_dormant') {
          groupId = '__system_dormant__';
        } else if (doc.id == 'system_expired') {
          groupId = '__system_expired__';
        }

        if (groupId == '__system_dormant__' ||
            groupId == '__system_expired__') {
          continue;
        }

        if (options.any((item) => item.id == groupId)) {
          continue;
        }

        options.add(
          _MemberGroupOption(
            id: groupId,
            label: name,
          ),
        );
      }

      options.sort((a, b) {
        if (a.id == '__ungrouped__') return -1;
        if (b.id == '__ungrouped__') return 1;
        return a.label.compareTo(b.label);
      });

      if (!mounted) return;

      setState(() {
        _groupOptions
          ..clear()
          ..addAll(options);

        if (_selectedGroupId == '__ungrouped__') {
          _headerGroupLabel = defaultGroupName.trim().isEmpty
              ? 'MORE THAN GYM'
              : defaultGroupName.trim();
        }
      });
    } catch (_) {}
  }

  void _setControllerTextIfNeeded(
    TextEditingController controller,
    String value,
  ) {
    if (controller.text == value) return;

    controller.text = value;
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
  }

  int _intFromAny(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse((value ?? '').toString()) ?? 0;
  }

  int _lessonStatCountFromMemberData(
    Map<String, dynamic> data,
    String key,
  ) {
    final sessions = data['sessions'] is Map
        ? Map<String, dynamic>.from(data['sessions'] as Map)
        : <String, dynamic>{};

    final lessonStats = data['lessonStats'] is Map
        ? Map<String, dynamic>.from(data['lessonStats'] as Map)
        : <String, dynamic>{};

    final values = <int>[
      _intFromAny(data[key]), // 예전 루트 필드 대비
      _intFromAny(sessions[key]), // sessions.xxx
      _intFromAny(lessonStats[key]), // lessonStats.xxx
    ];

    return values.reduce(math.max);
  }

  void _applyLessonStatsFromMemberData(Map<String, dynamic> data) {
    final loadedNoShowDeducted = _lessonStatCountFromMemberData(
      data,
      'noShowDeductedCount',
    );

    final loadedNoShowUndeducted = _lessonStatCountFromMemberData(
      data,
      'noShowUndeductedCount',
    );

    final loadedServiceSession = _lessonStatCountFromMemberData(
      data,
      'serviceSessionCount',
    );

    if (!mounted) return;

    setState(() {
      _noShowDeductedCount = loadedNoShowDeducted;
      _noShowUndeductedCount = loadedNoShowUndeducted;
      _serviceSessionCount = loadedServiceSession;

      _setControllerTextIfNeeded(
        _noShowDeductedC,
        loadedNoShowDeducted.toString(),
      );
      _setControllerTextIfNeeded(
        _noShowUndeductedC,
        loadedNoShowUndeducted.toString(),
      );
      _setControllerTextIfNeeded(
        _serviceSessionC,
        loadedServiceSession.toString(),
      );
    });
  }

  void _bindMemberStatsStream() {
    _memberStatsSub?.cancel();

    _memberStatsSub = FirebaseFirestore.instance
        .collection('members')
        .doc(widget.memberId)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data == null || !mounted) return;

      _applyLessonStatsFromMemberData(data);
    });
  }

  DateTime? _dateTimeFromAny(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;

    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }

    return null;
  }

  bool _isScheduleVisibleAsNextReservation(Map<String, dynamic> data) {
    if (data['isDeleted'] == true) return false;
    if (data['deleted'] == true) return false;
    if (data['voided'] == true) return false;
    if (data['confirmCancelled'] == true) return false;

    final status = [
      data['status'],
      data['lessonConfirmStatus'],
      data['sessionStatus'],
    ].map((e) => (e ?? '').toString().trim()).join(' ');

    if (status.contains('cancelled') ||
        status.contains('canceled') ||
        status.contains('deleted')) {
      return false;
    }

    return true;
  }

  void _applyNextReservationFromSchedules() {
    if (!mounted) return;

    final now = DateTime.now();

    DateTime? next;

    for (final doc in _nextReservationScheduleDocs) {
      final data = doc.data();

      if (!_isScheduleVisibleAsNextReservation(data)) continue;

      final startAt = _dateTimeFromAny(data['startAt']);
      if (startAt == null) continue;
      if (startAt.isBefore(now)) continue;

      if (next == null || startAt.isBefore(next)) {
        next = startAt;
      }
    }

    if (_nextReservation == next) return;

    setState(() {
      _nextReservation = next;
    });
  }

  void _bindNextReservationStream() {
    _nextReservationSub?.cancel();

    final cleanMemberId = widget.memberId.trim();
    if (cleanMemberId.isEmpty) return;

    _nextReservationSub = FirebaseFirestore.instance
        .collection('schedules')
        .where('memberId', isEqualTo: cleanMemberId)
        .snapshots()
        .listen((snapshot) {
      _nextReservationScheduleDocs = snapshot.docs;
      _applyNextReservationFromSchedules();
    });
  }

  Future<void> _loadFromFirestore() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .get();
      if (!snap.exists || !mounted) return;

      final d = snap.data() ?? <String, dynamic>{};

      DateTime? dt(dynamic v) {
        if (v == null) return null;
        if (v is Timestamp) return v.toDate();
        if (v is String && v.isNotEmpty) {
          final s = v.length == 10 ? '${v}T00:00:00.000' : v;
          return DateTime.tryParse(s);
        }
        return null;
      }

      final sessions = (d['sessions'] is Map)
          ? Map<String, dynamic>.from(d['sessions'] as Map)
          : <String, dynamic>{};

      final lessonStats = (d['lessonStats'] is Map)
          ? Map<String, dynamic>.from(d['lessonStats'] as Map)
          : <String, dynamic>{};

      final membership = (d['membership'] is Map)
          ? Map<String, dynamic>.from(d['membership'] as Map)
          : <String, dynamic>{};

      final health = (d['health'] is Map)
          ? Map<String, dynamic>.from(d['health'] as Map)
          : <String, dynamic>{};

      final femaleCondition = (health['femaleCondition'] is Map)
          ? Map<String, dynamic>.from(health['femaleCondition'] as Map)
          : <String, dynamic>{};

      final milestoneSettings = (d['milestoneSettings'] is Map)
          ? Map<String, dynamic>.from(d['milestoneSettings'] as Map)
          : <String, dynamic>{};

      final notificationSettings = (d['notificationSettings'] is Map)
          ? Map<String, dynamic>.from(d['notificationSettings'] as Map)
          : <String, dynamic>{};

      final lessonSync = d['lessonSync'] is Map
          ? Map<String, dynamic>.from(d['lessonSync'] as Map)
          : <String, dynamic>{};

      _membershipPaused =
          membership['status'] == 'paused' || d['membershipStatus'] == 'paused';

      _membershipPausedAt = dt(
        membership['pausedAt'] ?? d['membershipPausedAt'],
      );

      _membershipPauseReason =
          (membership['pauseReason'] ?? d['membershipPauseReason'] ?? '')
              .toString()
              .trim();

      _membershipPausePlannedDays =
          (membership['pausePlannedDays'] as num?)?.toInt() ??
              (d['membershipPausePlannedDays'] as num?)?.toInt() ??
              0;

      _membershipResumeDueAt = dt(
        membership['resumeDueAt'] ?? d['membershipResumeDueAt'],
      );

      _membershipPauseActualDays =
          (membership['pauseActualDays'] as num?)?.toInt() ??
              (d['membershipPauseActualDays'] as num?)?.toInt() ??
              0;

      _membershipPauseUsedDays =
          (membership['pauseUsedDays'] as num?)?.toInt() ??
              (d['membershipPauseUsedDays'] as num?)?.toInt() ??
              0;

      _membershipContractDraftExists =
          d['membershipContractDraftExists'] == true ||
              (membership['contractStatus'] ?? '').toString() == 'draft' ||
              (d['membershipContractStatus'] ?? '').toString() == 'draft';

      _membershipContractStatus =
          (d['membershipContractStatus'] ?? membership['contractStatus'] ?? '')
              .toString()
              .trim();

      _membershipContractMaxPauseDays =
          (membership['maxPauseDaysFromContract'] as num?)?.toInt() ??
              (d['membershipContractMaxPauseDays'] as num?)?.toInt();

      final loadedContractSigned = (d['contractSigned'] as bool?) ?? false;
      final loadedContractSignedAt = dt(d['contractSignedAt']);

      final contractLessonType = [
        lessonSync['lessonType'],
        lessonSync['productType'],
        lessonSync['programType'],
        d['contractLessonType'],
        d['lessonType'],
      ].map((e) => (e ?? '').toString().trim()).firstWhere(
            (e) => e.isNotEmpty && e != '미입력',
            orElse: () => '',
          );

      String nextGroupLabel = 'MORE THAN GYM';

      final rawStatus = (d['memberStatus'] as String?) ?? _memberStatus;
      final groupId = (d['groupId'] as String?)?.trim();
      String nextSelectedGroupId = '__ungrouped__';

      if (rawStatus == '휴면') {
        nextGroupLabel = await _loadGroupDisplayName('__system_dormant__');
        nextSelectedGroupId = '__ungrouped__';
      } else if (rawStatus == '만료') {
        nextGroupLabel = await _loadGroupDisplayName('__system_expired__');
        nextSelectedGroupId = '__ungrouped__';
      } else if (groupId != null && groupId.isNotEmpty) {
        nextGroupLabel = await _loadGroupDisplayName(groupId);
        nextSelectedGroupId = groupId;
      } else {
        nextGroupLabel = await _loadGroupDisplayName('__ungrouped__');
        nextSelectedGroupId = '__ungrouped__';
      }
      setState(() {
        final loadedName = (d['name'] as String?) ?? '';
        _nameC.text = loadedName;
        _headerDisplayName = loadedName.trim();
        _headerGroupLabel = nextGroupLabel.trim().isEmpty
            ? 'MORE THAN GYM'
            : nextGroupLabel.trim();

        _selectedGroupId = nextSelectedGroupId;

        _gender = _normalizeGender(d['gender'] as String?) ?? '미입력';

        final birthDisplay = (d['birthDisplay'] as String?) ?? '';
        final loadedBirthDate = dt(d['birth']);

        if (birthDisplay.isNotEmpty) {
          _birthTextC.text = birthDisplay;
          _birthDate = _parseDate(birthDisplay);
        } else if (loadedBirthDate != null) {
          _birthDate = loadedBirthDate;
          _birthTextC.text = _formatDate(loadedBirthDate);
        } else {
          _birthDate = null;
          _birthTextC.clear();
        }

        final loadedPhone = [
          (d['phoneDisplay'] ?? '').toString().trim(),
          (d['phoneNormalized'] ?? '').toString().trim(),
          (d['phone'] ?? '').toString().trim(),
        ].firstWhere(
          (value) => value.isNotEmpty,
          orElse: () => '',
        );

        _phoneC.text = formatKoreanMobilePhone(loadedPhone);

        _postalC.text = (d['postal'] as String?) ?? _postalC.text;
        _addrC.text = (d['address'] as String?) ?? _addrC.text;
        _addrDetailC.text =
            (d['detailAddress'] as String?) ?? _addrDetailC.text;

        _postalC.text = (d['postal'] ?? '').toString();
        _addrC.text = (d['address'] ?? '').toString();
        _addrDetailC.text = (d['detailAddress'] ?? '').toString();

        _membershipGrade =
            _safeMembershipGrade(d['membershipGrade'] as String?);
        _jobC.text = (d['job'] as String?) ?? '';
        _trainerC.text = (d['trainer'] ?? '').toString().trim();
        _memberStatus = _safeMemberStatus(d['memberStatus'] as String?);
        _lessonType = _safeLessonType(d['lessonType'] as String?);

        _photoUrl = (d['photoUrl'] ?? '').toString().trim().isEmpty
            ? null
            : (d['photoUrl'] ?? '').toString().trim();

        _lessonsNotRegistered =
            (sessions['notRegistered'] as bool?) ?? _lessonsNotRegistered;
        final rawTotalSessions =
            sessions['total'] ?? d['totalSessions'] ?? d['sessionTotal'];

        final rawRemainSessions = sessions['remain'] ??
            d['remainSessions'] ??
            d['remainingSessions'] ??
            d['remainingPt'] ??
            d['ptRemaining'];

        final rawDoneSessions = sessions['done'] ?? d['doneSessions'];

        _totalSessionsC.text = rawTotalSessions is num
            ? rawTotalSessions.toInt().toString()
            : int.tryParse((rawTotalSessions ?? '').toString())?.toString() ??
                _totalSessionsC.text;

        _remainSessionsC.text = rawRemainSessions is num
            ? rawRemainSessions.toInt().toString()
            : int.tryParse((rawRemainSessions ?? '').toString())?.toString() ??
                _remainSessionsC.text;

// doneSessions는 화면에서 직접 입력하지 않고 total - remain으로 계산하지만,
// 기존 데이터 확인용으로 fallback만 준비해 둡니다.
        if (rawDoneSessions != null &&
            _totalSessionsC.text.trim().isEmpty &&
            _remainSessionsC.text.trim().isEmpty) {
          final done = rawDoneSessions is num
              ? rawDoneSessions.toInt()
              : int.tryParse(rawDoneSessions.toString()) ?? 0;
          _totalSessionsC.text = done.toString();
          _remainSessionsC.text = '0';
        }

        _membershipNotRegistered =
            (membership['notRegistered'] as bool?) ?? false;
        _termMonths = (membership['termMonths'] as num?)?.toInt();
        _customDays = (membership['customDays'] as num?)?.toInt();
        _passStart = dt(membership['startAt']);
        _passEnd = dt(membership['endAt']);
        _lastRegisteredAt = dt(membership['lastRegisteredAt']);

        _lastLogAt = dt(d['lastLessonAt'] ?? d['lastLogAt']);

        final loadedNoShowDeducted = _lessonStatCountFromMemberData(
          d,
          'noShowDeductedCount',
        );

        final loadedNoShowUndeducted = _lessonStatCountFromMemberData(
          d,
          'noShowUndeductedCount',
        );

        final loadedServiceSession = _lessonStatCountFromMemberData(
          d,
          'serviceSessionCount',
        );

        final loadedReregister =
            (membership['reregisterCount'] as num?)?.toInt() ?? 0;

        _noShowDeductedCount = loadedNoShowDeducted;
        _noShowUndeductedCount = loadedNoShowUndeducted;
        _serviceSessionCount = loadedServiceSession;
        _reregisterCount = loadedReregister;

        _setControllerTextIfNeeded(
          _noShowDeductedC,
          loadedNoShowDeducted.toString(),
        );
        _setControllerTextIfNeeded(
          _noShowUndeductedC,
          loadedNoShowUndeducted.toString(),
        );
        _setControllerTextIfNeeded(
          _serviceSessionC,
          loadedServiceSession.toString(),
        );
        _setControllerTextIfNeeded(
          _reregisterCountC,
          loadedReregister.toString(),
        );
        _lastReregisterAt =
            dt(membership['lastReregisterAt']) ?? _lastReregisterAt;

        _inbodyNotProvided =
            (health['inbodyNotProvided'] as bool?) ?? _inbodyNotProvided;
        _diseaseC.text =
            (health['diseaseHistory'] as String?) ?? _diseaseC.text;
        _medicineC.text =
            (health['medicineHistory'] as String?) ?? _medicineC.text;

        _femaleConditionEnabled =
            (femaleCondition['enabled'] as bool?) ?? false;

        final femaleLastStart = dt(femaleCondition['lastStartAt']);

        _femaleConditionLastStartC.text =
            femaleLastStart == null ? '' : _fmtSoftDate(femaleLastStart);

        _femaleConditionCycleC.text =
            ((femaleCondition['cycleDays'] as num?)?.toInt() ?? 28).toString();

        _femaleConditionMemoC.text = (femaleCondition['memo'] ?? '').toString();

        final inbodyRaw = (health['inbody'] is Map)
            ? Map<String, dynamic>.from(health['inbody'])
            : null;

        _latestInbodyImageUrl =
            (health['inbodyImageUrl'] ?? '').toString().trim().isEmpty
                ? null
                : (health['inbodyImageUrl'] ?? '').toString().trim();

        _latestInbodyMeasuredAt =
            dt(health['inbodyMeasuredAt'] ?? inbodyRaw?['measuredAt']);

        if (inbodyRaw != null && inbodyRaw.isNotEmpty) {
          final h = inbodyRaw['heightCm'];
          if (h is num) _heightC.text = h.toString();
          final w = inbodyRaw['weightKg'];
          if (w is num) _weightC.text = w.toString();
          final bfPct = inbodyRaw['bodyFatPct'];
          if (bfPct is num) _bfPctC.text = bfPct.toString();
          final smm = inbodyRaw['skeletalMuscleKg'];
          if (smm is num) _smmC.text = smm.toString();
          final bfKg = inbodyRaw['bodyFatKg'];
          if (bfKg is num) _bfKgC.text = bfKg.toString();
        }

        _noteC.text = (d['note'] ?? '').toString();

        _anniversaryDate = dt(d['anniversaryDate']);

        final loadedAnniversaryLabel =
            (d['anniversaryLabel'] ?? '').toString().trim();

        _anniversaryLabelC.text =
            loadedAnniversaryLabel.isEmpty ? '기념일' : loadedAnniversaryLabel;

        _specialEventC.text = (d['specialEvent'] ?? '').toString();

        _contractSigned = loadedContractSigned;
        _contractSignedAt = loadedContractSignedAt;

        final hasContractLesson = _contractSigned ||
            _contractSignedAt != null ||
            contractLessonType.isNotEmpty;

        if (hasContractLesson && contractLessonType.isNotEmpty) {
          _lessonType = contractLessonType;
          _lessonsNotRegistered = false;
          _syncCustomLessonTypeControllerIfNeeded();
        }

        _confirmTalkEnabled =
            notificationSettings['confirmTalkEnabled'] == true;
        _trainingLogConsentAgreed =
            (d['trainingLogConsentAgreed'] as bool?) ?? false;
        _trainingLogConsentAgreedAt = dt(d['trainingLogConsentAgreedAt']);

        _autoMilestoneEnabled =
            (milestoneSettings['autoMilestoneEnabled'] as bool?) ?? true;

        _ddayFollowUpEnabled =
            (milestoneSettings['ddayFollowUpEnabled'] as bool?) ?? true;

        _headerGroupLabel = nextGroupLabel.trim().isEmpty
            ? 'MORE THAN GYM'
            : nextGroupLabel.trim();
      });
    } catch (_) {}
  }

  void _debouncedSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 600), _saveDraft);
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final map = _collectFormMap(includeRegisteredAt: false);

    map.remove('phone');
    map.remove('note');
    map.remove('inbody');
    map.remove('diseaseHistory');
    map.remove('medicineHistory');

    await prefs.setString(_draftKey, jsonEncode(map));
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || !mounted) return;

    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _nameC.text = (m['name'] ?? '').toString();
        _headerDisplayName = _nameC.text.trim();

        _birthTextC.text = (m['birthDate'] ?? '').toString();
        _birthDate = _parseDate(_birthTextC.text);

        _membershipGrade =
            (m['membershipGrade'] ?? _membershipGrade).toString();
        _jobC.text = (m['job'] ?? '').toString();
        _trainerC.text = (m['trainer'] ?? '').toString();
        _memberStatus = (m['memberStatus'] ?? _memberStatus).toString();
        _lessonType = (m['lessonType'] ?? _lessonType).toString();
        _syncCustomLessonTypeControllerIfNeeded();

        _lessonsNotRegistered = (m['lessonsNotRegistered'] == true);
        _totalSessionsC.text = (m['totalSessions']?.toString() ?? '0');
        _remainSessionsC.text = (m['remainSessions']?.toString() ?? '0');

        _membershipNotRegistered = (m['membershipNotRegistered'] == true);
        _termMonths =
            (m['termMonths'] is num) ? (m['termMonths'] as num).toInt() : null;
        _customDays =
            (m['customDays'] is num) ? (m['customDays'] as num).toInt() : null;
        _passStart = _parseDate(m['passStart'] as String?);
        _passEnd = _parseDate(m['passEnd'] as String?);
        _lastRegisteredAt = _parseDate(m['lastRegisteredAt'] as String?);

        _nextReservation = _parseDate(m['nextReservationDate'] as String?);

        _anniversaryDate = _parseDate(m['anniversaryDate'] as String?);

        final draftAnniversaryLabel =
            (m['anniversaryLabel'] ?? '').toString().trim();

        _anniversaryLabelC.text =
            draftAnniversaryLabel.isEmpty ? '기념일' : draftAnniversaryLabel;

        _specialEventC.text = (m['specialEvent'] ?? '').toString();
      });
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  Map<String, dynamic> _collectFormMap({required bool includeRegisteredAt}) {
    final rawTotal = int.tryParse(_totalSessionsC.text) ?? 0;
    final rawRemain = int.tryParse(_remainSessionsC.text) ?? 0;

    final phoneDigits = normalizeMemberPhone(_phoneC.text);
    final phoneDisplay = formatKoreanMobilePhone(phoneDigits);
    final birthText = _birthTextC.text.trim();

    final noShowDeducted =
        int.tryParse(_noShowDeductedC.text.trim()) ?? _noShowDeductedCount;

    final noShowUndeducted =
        int.tryParse(_noShowUndeductedC.text.trim()) ?? _noShowUndeductedCount;

    final serviceSession =
        int.tryParse(_serviceSessionC.text.trim()) ?? _serviceSessionCount;

    final reregister =
        int.tryParse(_reregisterCountC.text.trim()) ?? _reregisterCount;

    final total = _lessonsNotRegistered ? 0 : rawTotal;
    final remain = _lessonsNotRegistered ? 0 : rawRemain;
    final lessonType = _lessonsNotRegistered ? '미입력' : _lessonType;

    return {
      'memberId': widget.memberId,
      'name': _nameC.text.trim(),
      'gender': _gender,
      'birthDate': birthText,
      'birthDisplay': birthText,
      'phone': phoneDigits,
      'phoneDisplay': phoneDisplay,
      'phoneNormalized': phoneDigits,
      'postal': _postalC.text.trim(),
      'address': _addrC.text.trim(),
      'detailAddress': _addrDetailC.text.trim(),
      'membershipGrade': _membershipGrade,
      'job': _jobC.text.trim(),
      'trainer': _trainerC.text.trim(),
      'memberStatus': _memberStatus,
      'lessonType': lessonType,
      'groupId': _selectedGroupId == '__ungrouped__' ? null : _selectedGroupId,
      'lessonsNotRegistered': _lessonsNotRegistered,
      'totalSessions': total,
      'remainSessions': remain,
      'doneSessions': (total - remain).clamp(0, total),
      'membershipNotRegistered': _membershipNotRegistered,
      'termMonths': _termMonths,
      'customDays': _customDays,
      'passStart': _formatDate(_passStart),
      'passEnd': _formatDate(_passEnd),
      'passDays': _passDays(),
      'lastRegisteredAt': _formatDate(_lastRegisteredAt),
      'noShowDeductedCount': noShowDeducted,
      'noShowUndeductedCount': noShowUndeducted,
      'serviceSessionCount': serviceSession,
      'reregisterCount': reregister,
      'lastReregisterAt': _formatDate(_lastReregisterAt),
      'inbodyNotProvided': _inbodyNotProvided,
      'diseaseHistory': _diseaseC.text.trim(),
      'medicineHistory': _medicineC.text.trim(),
      'inbody': _inbodyNotProvided
          ? null
          : {
              'heightCm': double.tryParse(_heightC.text) ?? 0,
              'weightKg': double.tryParse(_weightC.text) ?? 0,
              'bodyFatPct': double.tryParse(_bfPctC.text) ?? 0,
              'skeletalMuscleKg': double.tryParse(_smmC.text) ?? 0,
              'bodyFatKg': double.tryParse(_bfKgC.text) ?? 0,
              'bmi': _safeBmi(
                double.tryParse(_heightC.text) ?? 0,
                double.tryParse(_weightC.text) ?? 0,
              ),
            },
      'anniversaryDate': _formatDate(_anniversaryDate).isEmpty
          ? null
          : _formatDate(_anniversaryDate),
      'anniversaryLabel': _anniversaryLabelC.text.trim().isEmpty
          ? '기념일'
          : _anniversaryLabelC.text.trim(),
      'specialEvent': _specialEventC.text.trim().isEmpty
          ? null
          : _specialEventC.text.trim(),
      'note': _noteC.text.trim().isEmpty ? null : _noteC.text.trim(),
      'trainingLogConsentAgreed': _trainingLogConsentAgreed,
      'trainingLogConsentAgreedAt': _formatDate(_trainingLogConsentAgreedAt),
      'milestoneSettings': {
        'autoMilestoneEnabled': _autoMilestoneEnabled,
        'ddayFollowUpEnabled': _ddayFollowUpEnabled,
      },
      'notificationSettings': {
        'confirmTalkEnabled': _confirmTalkEnabled,
      },
      if (includeRegisteredAt) 'registeredAt': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _toFirestorePayload(
    Map<String, dynamic> raw, {
    required bool includeCreatedAt,
    String? photoUrl,
  }) {
    Timestamp? ts(String? ymd) {
      if (ymd == null || ymd.isEmpty) return null;
      try {
        final d = DateFormat('yyyy-MM-dd').parseStrict(ymd);
        return Timestamp.fromDate(DateTime(d.year, d.month, d.day));
      } catch (_) {
        return null;
      }
    }

    final birthText = (raw['birthDate'] ?? '').toString().trim();
    final birthTimestamp = ts(birthText);
    final phoneDigits = normalizeMemberPhone((raw['phone'] ?? '').toString());
    final phoneDisplay = formatKoreanMobilePhone(phoneDigits);

    final bool activeMembership = raw['membershipNotRegistered'] != true;

    final notificationSettings = raw['notificationSettings'] is Map
        ? Map<String, dynamic>.from(raw['notificationSettings'] as Map)
        : <String, dynamic>{};

    final totalSessions = (raw['totalSessions'] as int?) ??
        int.tryParse((raw['totalSessions'] ?? '0').toString()) ??
        0;

    final remainSessions = (raw['remainSessions'] as int?) ??
        int.tryParse((raw['remainSessions'] ?? '0').toString()) ??
        0;

    final doneSessions = (raw['doneSessions'] as int?) ??
        (totalSessions - remainSessions).clamp(0, totalSessions);

    final payload = <String, dynamic>{
      'memberId': raw['memberId'],
      'name': raw['name'],
      'gender': raw['gender'],
      'birth': birthTimestamp,
      'birthDisplay': birthText,
      'birthAt': birthTimestamp,
      'phone': phoneDigits,
      'phoneDisplay': phoneDisplay,
      'phoneNormalized': phoneDigits,
      'postal': raw['postal'],
      'address': raw['address'],
      'detailAddress': raw['detailAddress'],
      'membershipGrade': raw['membershipGrade'],
      'job': raw['job'],
      'trainer': raw['trainer'],
      'memberStatus': raw['memberStatus'],
      'lessonType': raw['lessonType'],
      'memberStatus': _membershipPaused ? '휴면' : raw['memberStatus'],
      'membershipStatus': _membershipPaused ? 'paused' : 'active',
      if (_membershipPausedAt != null)
        'membershipPausedAt': Timestamp.fromDate(_membershipPausedAt!),
      if (_membershipResumeDueAt != null)
        'membershipResumeDueAt': Timestamp.fromDate(_membershipResumeDueAt!),
      'membershipPausePlannedDays': _membershipPausePlannedDays,
      'membershipPauseActualDays': _membershipPauseActualDays,
      'membershipPauseUsedDays': _membershipPauseUsedDays,
      'membershipContractDraftExists': _membershipContractDraftExists,
      'membershipContractStatus': _membershipContractStatus,
      if (_membershipContractMaxPauseDays != null)
        'membershipContractMaxPauseDays': _membershipContractMaxPauseDays,
      'lessonType': raw['lessonType'],
      'groupId': raw['groupId'],

// 홈, 회원관리, 레슨일지 차감 로직에서 같이 참조할 수 있도록 루트 필드도 유지합니다.
      'totalSessions': totalSessions,
      'remainSessions': remainSessions,
      'remainingSessions': remainSessions,
      'doneSessions': doneSessions,

      'sessions': {
        'notRegistered': raw['lessonsNotRegistered'] == true,
        'total': totalSessions,
        'remain': remainSessions,
        'done': doneSessions,
        'noShowDeductedCount': raw['noShowDeductedCount'] ?? 0,
        'noShowUndeductedCount': raw['noShowUndeductedCount'] ?? 0,
        'serviceSessionCount': raw['serviceSessionCount'] ?? 0,
      },

      'lessonStats': {
        'noShowDeductedCount': raw['noShowDeductedCount'] ?? 0,
        'noShowUndeductedCount': raw['noShowUndeductedCount'] ?? 0,
        'serviceSessionCount': raw['serviceSessionCount'] ?? 0,
      },

      'membership': {
        'notRegistered': raw['membershipNotRegistered'] == true,
        'termMonths': raw['termMonths'],
        'customDays': raw['customDays'],
        'startAt': ts(raw['passStart']),
        'endAt': ts(raw['passEnd']),
        'days': raw['passDays'],
        'reregisterCount': raw['reregisterCount'] ?? 0,
        'lastReregisterAt': ts(raw['lastReregisterAt']),

        // 회원권 정지/재개 상태 보존
        'status': _membershipPaused ? 'paused' : 'active',
        if (_membershipPausedAt != null)
          'pausedAt': Timestamp.fromDate(_membershipPausedAt!),
        if (_membershipResumeDueAt != null)
          'resumeDueAt': Timestamp.fromDate(_membershipResumeDueAt!),
        if (_membershipPauseReason.trim().isNotEmpty)
          'pauseReason': _membershipPauseReason.trim(),
        if (_membershipPaused) 'pauseSource': 'client_card',
        'pausePlannedDays': _membershipPausePlannedDays,
        'pauseActualDays': _membershipPauseActualDays,
        'pauseUsedDays': _membershipPauseUsedDays,

        // 회원권계약서 초안 기준값 보존
        if (_membershipContractStatus.trim().isNotEmpty)
          'contractStatus': _membershipContractStatus.trim(),
        if (_membershipContractMaxPauseDays != null)
          'maxPauseDaysFromContract': _membershipContractMaxPauseDays,

        if (activeMembership) 'lastRegisteredAt': FieldValue.serverTimestamp(),
      },

      'health': {
        'inbodyNotProvided': raw['inbodyNotProvided'] == true,
        'diseaseHistory': raw['diseaseHistory'],
        'medicineHistory': raw['medicineHistory'],
        'inbody': raw['inbody'],
        if (_latestInbodyImageUrl != null &&
            _latestInbodyImageUrl!.trim().isNotEmpty)
          'inbodyImageUrl': _latestInbodyImageUrl,
        if (_latestInbodyMeasuredAt != null)
          'inbodyMeasuredAt': Timestamp.fromDate(_latestInbodyMeasuredAt!),
        'femaleCondition': {
          'enabled': _gender == '여' && _femaleConditionEnabled,
          'lastStartAt': _parseSoftDate(_femaleConditionLastStartC.text) == null
              ? null
              : Timestamp.fromDate(
                  _parseSoftDate(_femaleConditionLastStartC.text)!,
                ),
          'cycleDays': int.tryParse(_femaleConditionCycleC.text.trim()) ?? 28,
          'memo': _femaleConditionMemoC.text.trim(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      },
      'nextReservationAt': ts(raw['nextReservationDate']),
      'anniversaryDate': ts(raw['anniversaryDate']),
      'anniversaryLabel': raw['anniversaryLabel'],
      'specialEvent': raw['specialEvent'],
      'note': raw['note'],
      'trainingLogConsentAgreed': raw['trainingLogConsentAgreed'] == true,
      'trainingLogConsentAgreedAt': ts(raw['trainingLogConsentAgreedAt']),
      'milestoneSettings': raw['milestoneSettings'] ??
          {
            'autoMilestoneEnabled': true,
            'ddayFollowUpEnabled': true,
          },
      'notificationSettings': {
        'confirmTalkEnabled':
            notificationSettings['confirmTalkEnabled'] == true,
      },
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (activeMembership) 'lastRegisteredAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (includeCreatedAt) {
      payload['createdAt'] = FieldValue.serverTimestamp();
    }
    return payload;
  }

  Future<void> _bootstrapMemberArtifacts({
    required String memberId,
    required Map<String, dynamic> raw,
    String? photoUrl,
  }) async {
    final db = FirebaseFirestore.instance;
    final memberRef = db.collection('members').doc(memberId);
    final batch = db.batch();

    final cardRef = memberRef.collection('client_card').doc('v1');
    final total = (raw['totalSessions'] as int?) ?? 0;
    final remain = (raw['remainSessions'] as int?) ?? 0;
    final done = (raw['doneSessions'] as int?) ?? 0;

    batch.set(cardRef, {
      'memberId': memberId,
      'name': (raw['name'] ?? '').toString(),
      'phone': normalizeMemberPhone((raw['phone'] ?? '').toString()),
      'phoneDisplay': (raw['phoneDisplay'] ?? '').toString(),
      'phoneNormalized': normalizeMemberPhone((raw['phone'] ?? '').toString()),
      'trainer': (raw['trainer'] ?? '').toString(),
      'membershipGrade': raw['membershipGrade'],
      'memberStatus': raw['memberStatus'],
      'totalSessions': total,
      'remainSessions': remain,
      'remainingSessions': remain,
      'doneSessions': done,
      'sessions': {'total': total, 'remain': remain, 'done': done},
      'membership': {
        'startAt': raw['passStart'],
        'endAt': raw['passEnd'],
        'days': raw['passDays'],
        'notRegistered': raw['membershipNotRegistered'] == true,
      },
      'photoUrl': photoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    final idxRef = memberRef.collection('training_logs').doc('_index');
    batch.set(
      idxRef,
      {
        'entries': 0,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    final todayYmd = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final firstLogRef = memberRef.collection('training_logs').doc(todayYmd);

    final inbody = (raw['inbody'] is Map)
        ? Map<String, dynamic>.from(raw['inbody'])
        : null;

    batch.set(firstLogRef, {
      'date': todayYmd,
      'memberId': memberId,
      'notes': null,
      'checklist': {'warmup': false, 'main': false, 'cooldown': false},
      'metrics': {
        'weightKg': inbody?['weightKg'],
        'bodyFatPct': inbody?['bodyFatPct'],
        'smmKg': inbody?['skeletalMuscleKg'],
      },
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      '_template': true,
    });

    await batch.commit();
  }

  static double _safeBmi(double hCm, double wKg) {
    if (hCm <= 0) return 0;
    final hM = hCm / 100.0;
    return double.parse((wKg / (hM * hM)).toStringAsFixed(2));
  }

  DateTime? _parseSoftDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final normalized = value
        .replaceAll('.', '-')
        .replaceAll('/', '-')
        .replaceAll(RegExp(r'\s+'), '');

    final match =
        RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(normalized);
    if (match == null) return null;

    final y = int.tryParse(match.group(1)!);
    final m = int.tryParse(match.group(2)!);
    final d = int.tryParse(match.group(3)!);

    if (y == null || m == null || d == null) return null;

    final parsed = DateTime(y, m, d);
    if (parsed.year != y || parsed.month != m || parsed.day != d) return null;

    return parsed;
  }

  String _fmtSoftDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  String? _normalizeGender(String? raw) {
    if (raw == null) return null;

    final value = raw.trim();
    if (value.isEmpty) return null;

    switch (value) {
      case '남':
      case '남성':
      case '남자':
      case 'male':
      case 'Male':
      case 'M':
        return '남';

      case '여':
      case '여성':
      case '여자':
      case 'female':
      case 'Female':
      case 'F':
        return '여';

      default:
        return null;
    }
  }

  String _formatDate(DateTime? d) =>
      d == null ? '' : DateFormat('yyyy-MM-dd').format(d);

  DateTime? _parseDate(String? s) {
    if (s == null || s.isEmpty) return null;
    try {
      return DateFormat('yyyy-MM-dd').parseStrict(s);
    } catch (_) {
      return null;
    }
  }

  bool _isSameOrAfterToday(DateTime date) {
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    final target = DateTime(date.year, date.month, date.day);
    return !target.isBefore(base);
  }

  DateTime _todayOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void _extendMembershipDays(int addedDays) {
    if (addedDays <= 0) return;

    final today = _todayOnly();

    final DateTime nextStart;
    if (_passEnd != null && _isSameOrAfterToday(_passEnd!)) {
      nextStart = DateTime(
        _passEnd!.year,
        _passEnd!.month,
        _passEnd!.day,
      ).add(const Duration(days: 1));
    } else {
      nextStart = today;
    }

    final nextEnd = nextStart.add(Duration(days: addedDays - 1));

    setState(() {
      _membershipNotRegistered = false;
      _memberStatus = '활성';

      if (_passStart == null ||
          (_passEnd != null && !_isSameOrAfterToday(_passEnd!))) {
        _passStart = nextStart;
      }

      _passEnd = nextEnd;
      _termMonths = null;
      _customDays = addedDays;

      _reregisterCount += 1;
      _lastReregisterAt = DateTime.now();
      _lastRegisteredAt = DateTime.now();
    });
  }

  void _addPtSessions(int addedSessions) {
    if (addedSessions <= 0) return;

    final currentTotal = int.tryParse(_totalSessionsC.text) ?? 0;
    final currentRemain = int.tryParse(_remainSessionsC.text) ?? 0;

    setState(() {
      _lessonsNotRegistered = false;
      _memberStatus = '활성';
      _totalSessionsC.text = (currentTotal + addedSessions).toString();
      _remainSessionsC.text = (currentRemain + addedSessions).toString();

      _reregisterCount += 1;
      _lastReregisterAt = DateTime.now();
    });
  }

  void _applyReregistration({
    int addedPtSessions = 0,
    int addedMembershipDays = 0,
  }) {
    if (addedPtSessions > 0) {
      _addPtSessions(addedPtSessions);
    }

    if (addedMembershipDays > 0) {
      _extendMembershipDays(addedMembershipDays);
    }
  }

  void _handleBirthFocusChange() {
    if (!_birthFocusNode.hasFocus) {
      _normalizeBirthInput(validateField: true);
    }
  }

  MemberBirthDateNormalizationResult _normalizeBirthInput({
    bool validateField = false,
  }) {
    final result = normalizeAndValidateMemberBirthDate(
      _birthTextC.text,
      required: true,
    );

    if (result.isValid) {
      final normalizedText = result.normalizedText!;
      if (_birthTextC.text != normalizedText) {
        _birthTextC.value = TextEditingValue(
          text: normalizedText,
          selection: TextSelection.collapsed(offset: normalizedText.length),
        );
      }
      _birthDate = result.date;
    } else {
      _birthDate = null;
    }

    if (mounted) {
      setState(() {});
    }
    if (validateField) {
      _birthFieldKey.currentState?.validate();
    }

    return result;
  }

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
    DateTime? first,
    DateTime? last,
  }) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      locale: const Locale('ko', 'KR'),
      initialDate: current ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) onPicked(picked);
  }

  int? _passDays() {
    if (_passStart == null || _passEnd == null) return null;
    final s = DateTime(_passStart!.year, _passStart!.month, _passStart!.day);
    final e = DateTime(_passEnd!.year, _passEnd!.month, _passEnd!.day);
    return e.difference(s).inDays + 1;
  }

  int? _daysLeft() {
    if (_passEnd == null) return null;
    final today = DateTime.now();
    final end = DateTime(_passEnd!.year, _passEnd!.month, _passEnd!.day);
    return end.difference(DateTime(today.year, today.month, today.day)).inDays;
  }

  int _approxDays(int months) => months * 30;

  Future<void> _pickProfileImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 55,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;

    setState(() {
      _profileBytes = bytes;
    });
  }

  Future<void> _clearProfileImage() async {
    if (_profileBytes == null && (_photoUrl == null || _photoUrl!.isEmpty)) {
      return;
    }

    final ok = await _showAifcConfirm(
      title: '프로필 사진을 삭제할까요?',
      message: '현재 회원카드에 표시된 프로필 사진을 삭제합니다.\n'
          '나중에 다시 등록할 수 있어요.',
      cancelText: '취소',
      confirmText: '삭제',
      userCancelText: '취소할게요',
      userConfirmText: '삭제할게요',
      cancelReplyText: '좋아요. 프로필 사진은 그대로 둘게요.',
      confirmReplyText: '확인했어요. 프로필 사진 삭제를 진행할게요.',
      danger: true,
    );

    if (ok != true || !mounted) return;

    setState(() {
      _profileBytes = null;
      _photoUrl = null;
    });

    try {
      await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .set({
        'photoUrl': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) return;
      _showAifcToast('프로필 사진을 삭제했어요.');
    } catch (_) {
      if (!mounted) return;
      _showAifcToast('프로필 사진을 삭제하지 못했어요.');
    }
  }

  String _nextTierNameFromRank(int rank) {
    if (rank < 1) return 'Amateur';
    if (rank < 2) return 'Semi-Pro';
    if (rank < 3) return 'Pro';
    if (rank < 4) return 'Master';
    if (rank < 5) return 'Grand Prix';

    return 'Grand Prix';
  }

  Future<bool> _hasAnyLessonProduct() async {
    try {
      final products = await LessonProductService.fetchProducts();
      return products.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _guardTierFeature(AppTierFeatureKey feature) async {
    AppTierAccessSnapshot? resolvedAccess = _tierAccess;

    final allowed = await AifcTierFeatureGateSheet.guard(
      context: context,
      access: resolvedAccess,
      feature: feature,
      loadAccess: () async {
        final access = _isPersonalWorkspace
            ? await AppTierAccessService.loadPersonalTrainerAccess(
                uid: widget.personalOwnerUid!.trim(),
              )
            : await AppTierAccessService.loadTrainerAccess();
        resolvedAccess = access;

        if (mounted) {
          setState(() {
            _tierAccess = access;
            _isTierAccessLoaded = true;
          });
        }

        return access;
      },
      onShowTierGuide: (info) async {
        final access = resolvedAccess ??
            _tierAccess ??
            (_isPersonalWorkspace
                ? await AppTierAccessService.loadPersonalTrainerAccess(
                    uid: widget.personalOwnerUid!.trim(),
                  )
                : await AppTierAccessService.loadTrainerAccess());

        if (!mounted) return;

        await _openTierGuideFromFeatureGate(access);
      },
    );

    return allowed;
  }

  Future<void> _openTierGuideFromFeatureGate(
    AppTierAccessSnapshot access,
  ) async {
    final hasProduct = await _hasAnyLessonProduct();

    if (!mounted) return;

    final trainerName = _safeAifcNickname.trim().isEmpty
        ? _trainerC.text.trim()
        : _safeAifcNickname;

    await AifcTierGuideChatSheet.show(
      context: context,
      trainerName: trainerName.trim().isEmpty ? '강사' : trainerName,
      currentTierName: access.tierLabel,
      nextTierName: _nextTierNameFromRank(access.tierRank),
      memberCount: access.activeMemberCount,
      lessonCount: _doneSessionValue,
      hasProduct: hasProduct,
      trainerInfoDone: access.profileCompleted,
    );
  }

  Future<String?> _uploadProfileIfAny() async {
    if (_profileBytes == null) return null;
    final path =
        'member_profiles/${widget.memberId}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = FirebaseStorage.instance.ref(path);
    final meta = SettableMetadata(
      contentType: 'image/jpeg',
      cacheControl: 'public, max-age=3600',
    );
    await ref.putData(_profileBytes!, meta);
    return await ref.getDownloadURL();
  }

  Future<void> _openContract() async {
    if (!await _guardTierFeature(AppTierFeatureKey.contract)) return;

    final defaultTrainerName = await _loadDefaultTrainerName();

    final trainerName = _trainerC.text.trim().isNotEmpty
        ? _trainerC.text.trim()
        : defaultTrainerName;

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ContractPage(
          memberId: widget.memberId,
          memberName: _nameC.text.trim(),
          trainerName: trainerName,
        ),
      ),
    );

    if (ok == true) {
      await _loadFromFirestore();

      if (mounted) {
        _showAifcToast('레슨계약서 저장이 완료되었어요.');
      }
    }
  }

  int _membershipPauseAvailableDays({
    required int remainingDays,
  }) {
    final contractMax = _membershipContractMaxPauseDays;

    if (!_membershipContractDraftExists ||
        contractMax == null ||
        contractMax <= 0) {
      return remainingDays;
    }

    final contractRemaining =
        (contractMax - _membershipPauseUsedDays).clamp(0, contractMax);

    return math.min(remainingDays, contractRemaining);
  }

  String _membershipPauseLimitGuideText({
    required int remainingDays,
    required int availableDays,
  }) {
    final contractMax = _membershipContractMaxPauseDays;

    if (!_membershipContractDraftExists ||
        contractMax == null ||
        contractMax <= 0) {
      return '현재 남은 회원권 기간은 $remainingDays일이에요.';
    }

    return '현재 남은 회원권 기간은 $remainingDays일이고,\n'
        '회원권계약서 기준 남은 정지 가능일은 $availableDays일이에요.';
  }

  String _membershipContractPauseLimitText() {
    final maxDays = _membershipContractMaxPauseDays;

    if (!_membershipContractDraftExists || maxDays == null || maxDays <= 0) {
      return '';
    }

    final remaining = (maxDays - _membershipPauseUsedDays).clamp(0, maxDays);

    return '계약서 기준 정지 가능일 $remaining/$maxDays일';
  }

  int _daysUntilThisMonthEnd() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    final days = monthEnd.difference(today).inDays;

    // 당일 월말이면 최소 1일로 처리
    return days <= 0 ? 1 : days;
  }

  int? _parsePauseDaysInput(String value) {
    final raw = value.trim().toLowerCase();

    if (raw.isEmpty) return null;

    final compact = raw.replaceAll(RegExp(r'\s+'), '');

    // 이번달말까지 / 이번 달 말까지 / 월말까지 / 말일까지
    if (compact == '이번달말' ||
        compact == '이번달말까지' ||
        compact == '월말' ||
        compact == '월말까지' ||
        compact == '말일' ||
        compact == '말일까지') {
      return _daysUntilThisMonthEnd();
    }

    // 일주일 / 한주 / 한 주 / 한주만
    if (compact == '일주일' ||
        compact == '일주일만' ||
        compact == '한주' ||
        compact == '한주만') {
      return 7;
    }

    // 보름 / 보름만
    if (compact == '보름' || compact == '보름만') {
      return 15;
    }

    // 한달 / 한 달 / 한달만 / 1개월
    if (compact == '한달' ||
        compact == '한달만' ||
        compact == '1개월' ||
        compact == '1개월만') {
      return 30;
    }

    // 7 / 7일 / 7일만 / 7일간
    final dayMatch = RegExp(r'^(\d{1,4})(일|일만|일간)?$').firstMatch(compact);

    if (dayMatch != null) {
      return int.tryParse(dayMatch.group(1) ?? '');
    }

    // 2주 / 2주만 / 2주간
    final weekMatch = RegExp(r'^(\d{1,2})(주|주만|주간|주일)?$').firstMatch(compact);

    if (weekMatch != null) {
      final weeks = int.tryParse(weekMatch.group(1) ?? '');
      if (weeks == null) return null;
      return weeks * 7;
    }

    return null;
  }

  String _pauseDaysParsedReplyText({
    required String input,
    required int days,
  }) {
    final raw = input.trim();

    if (raw.isEmpty || RegExp(r'^\d+$').hasMatch(raw)) {
      return '$days일 정지로 계산할게요.';
    }

    return '$raw이면 $days일 정지로 계산할게요.';
  }

  Future<_MembershipPauseConfirmAction> _showMembershipPauseConfirmAction({
    required String memberName,
    required int days,
    required int remainingDays,
    required int maxDays,
  }) async {
    final result = await showModalBottomSheet<_MembershipPauseConfirmAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F4FF),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: kPagePrimary.withOpacity(0.16),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AifcAvatar(
                        size: 34,
                        isAnimating: true,
                        backgroundColor: Color(0xFFF5F4FF),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: const Color(0xFFE0DEFF),
                            ),
                          ),
                          child: Text(
                            '${aifcPersonLabel(memberName)} 회원권을 $days일 정지할게요.\n\n'
                            '${_membershipPauseLimitGuideText(
                              remainingDays: remainingDays,
                              availableDays: maxDays,
                            )}\n\n'
                            '이 기간으로 저장할까요?',
                            style: const TextStyle(
                              color: Color(0xFF1E1B4B),
                              fontSize: 13,
                              height: 1.45,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop(
                              _MembershipPauseConfirmAction.reset,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPagePrimary,
                            side: BorderSide(
                              color: kPagePrimary.withOpacity(0.24),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            '기간재설정',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop(
                              _MembershipPauseConfirmAction.confirm,
                            );
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: kPagePrimary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: const Text(
                            '알겠어요',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(sheetContext).pop(
                        _MembershipPauseConfirmAction.cancel,
                      );
                    },
                    child: const Text(
                      '취소',
                      style: TextStyle(
                        color: kPageMuted,
                        fontWeight: FontWeight.w800,
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

    return result ?? _MembershipPauseConfirmAction.cancel;
  }

  Future<int?> _askMembershipPauseDays({
    required int maxDays,
    required int remainingDays,
    required String memberName,
  }) async {
    while (mounted) {
      int? selectedDays;
      String selectedInput = '';

      final memberLabel = aifcPersonLabel(memberName);

      final result = await AifcInteraction.ask(
        context: context,
        question: '$memberLabel 회원권을 얼마나 정지할까요?\n'
            '${_membershipPauseLimitGuideText(
          remainingDays: remainingDays,
          availableDays: maxDays,
        )}',
        inputLabel: '예: 7 / 일주일 / 보름 / 이번달말까지',
        keyboardType: TextInputType.text,
        skipLabel: '취소',
        onSkip: () {},
        onSave: (value) async {
          final days = _parsePauseDaysInput(value);

          if (days == null || days <= 0) {
            throw Exception('invalid_pause_days');
          }

          if (days > maxDays) {
            throw Exception('pause_days_over_remaining');
          }

          selectedDays = days;
          selectedInput = value.trim();

          return '${_pauseDaysParsedReplyText(
            input: selectedInput,
            days: days,
          )}\n'
              '회원권계약서 기준 정지 가능일 안에서만 저장할 수 있어요.';
        },
      );

      if (!mounted || result == null || selectedDays == null) {
        return null;
      }

      final days = selectedDays!;

      final action = await _showMembershipPauseConfirmAction(
        memberName: memberName,
        days: days,
        remainingDays: remainingDays,
        maxDays: maxDays,
      );

      if (!mounted) return null;

      switch (action) {
        case _MembershipPauseConfirmAction.confirm:
          return days;

        case _MembershipPauseConfirmAction.reset:
          continue;

        case _MembershipPauseConfirmAction.cancel:
          return null;
      }
    }

    return null;
  }

  Future<void> _toggleMembershipPause() async {
    if (!await _guardTierFeature(AppTierFeatureKey.membershipPauseResume)) {
      return;
    }

    final memberName = _nameC.text.trim().isEmpty ? '회원' : _nameC.text.trim();
    final now = DateTime.now();

    if (!_membershipPaused) {
      final remainingDays = _daysLeft();

      if (_membershipNotRegistered ||
          _passEnd == null ||
          remainingDays == null) {
        _showAifcToast('회원권 종료일이 있어야 정지할 수 있어요.');
        return;
      }

      if (remainingDays <= 0) {
        _showAifcToast('남은 회원권 기간이 없어 정지할 수 없어요.');
        return;
      }

      final availablePauseDays = _membershipPauseAvailableDays(
        remainingDays: remainingDays,
      );

      if (availablePauseDays <= 0) {
        _showAifcToast(
          _membershipContractDraftExists
              ? '회원권계약서 기준으로 더 이상 정지 가능한 일수가 없어요.'
              : '정지 가능한 남은 회원권 기간이 없어요.',
        );
        return;
      }

      final selectedPauseDays = await _askMembershipPauseDays(
        maxDays: availablePauseDays,
        remainingDays: remainingDays,
        memberName: memberName,
      );

      if (!mounted || selectedPauseDays == null) return;

      final pauseDays = selectedPauseDays;

      if (pauseDays > remainingDays) {
        _showAifcToast('정지기간이 남은 회원권 기간보다 많아요.');
        return;
      }

      if (pauseDays > availablePauseDays) {
        _showAifcToast(
          _membershipContractDraftExists
              ? '회원권계약서 기준 정지 가능일보다 많아요.'
              : '정지 가능한 기간보다 많아요.',
        );
        return;
      }

      final resumeDueAt = DateTime(
        now.year,
        now.month,
        now.day,
      ).add(Duration(days: pauseDays));

      await FirebaseFirestore.instance
          .collection('members')
          .doc(widget.memberId)
          .set({
        'memberStatus': '휴면',
        'membershipStatus': 'paused',
        'membership.status': 'paused',
        'membership.pausedAt': FieldValue.serverTimestamp(),
        'membership.pausePlannedDays': pauseDays,
        'membership.resumeDueAt': Timestamp.fromDate(resumeDueAt),
        'membership.pauseReason': 'client_card_membership_pause',
        'membership.pauseSource': 'client_card',
        'membership.updatedAt': FieldValue.serverTimestamp(),
        'membershipPausePlannedDays': pauseDays,
        'membershipResumeDueAt': Timestamp.fromDate(resumeDueAt),
        'membershipPausedAt': FieldValue.serverTimestamp(),
        'membershipPauseHistory': FieldValue.arrayUnion([
          {
            'type': 'pause',
            'at': Timestamp.fromDate(now),
            'plannedDays': pauseDays,
            'resumeDueAt': Timestamp.fromDate(resumeDueAt),
            'source': 'client_card',
          },
        ]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        _membershipPaused = true;
        _membershipPausedAt = now;
        _membershipPausePlannedDays = pauseDays;
        _membershipResumeDueAt = resumeDueAt;
        _membershipPauseReason = 'client_card_membership_pause';
        _memberStatus = '휴면';
      });

      _showAifcToast('회원권을 $pauseDays일 정지했어요. 휴면회원으로 분류됩니다.');
      return;
    }

    final pausedAt = _membershipPausedAt ?? now;
    final pausedStartDate = DateTime(
      pausedAt.year,
      pausedAt.month,
      pausedAt.day,
    );

    final today = DateTime(now.year, now.month, now.day);

    final elapsedDays = today.difference(pausedStartDate).inDays <= 0
        ? 1
        : today.difference(pausedStartDate).inDays;

    final plannedDays = _membershipPausePlannedDays <= 0
        ? elapsedDays
        : _membershipPausePlannedDays;

    final actualPauseDays =
        elapsedDays > plannedDays ? plannedDays : elapsedDays;

    final nextPassEnd = _passEnd == null
        ? null
        : DateTime(
            _passEnd!.year,
            _passEnd!.month,
            _passEnd!.day,
          ).add(Duration(days: actualPauseDays));

    final ok = await _showAifcConfirm(
      title: '회원권을 재개할까요?',
      message: '${aifcPersonLabel(memberName)} 회원권을 다시 진행 상태로 바꿉니다.\n\n'
          '실제 정지된 기간은 $actualPauseDays일로 기록하고,\n'
          '회원권 종료일도 $actualPauseDays일 연장해둘게요.',
      cancelText: '취소',
      confirmText: '재개',
      userCancelText: '취소할게요',
      userConfirmText: '재개할게요',
      cancelReplyText: '좋아요. 회원권 정지는 그대로 둘게요.',
      confirmReplyText: '확인했어요. 회원권을 다시 진행 상태로 바꿀게요.',
    );

    if (!ok || !mounted) return;

    await FirebaseFirestore.instance
        .collection('members')
        .doc(widget.memberId)
        .set({
      'memberStatus': '활성',
      'membershipStatus': 'active',
      'membership.status': 'active',
      'membership.resumedAt': FieldValue.serverTimestamp(),
      'membership.pauseActualDays': actualPauseDays,
      'membership.lastPauseActualDays': actualPauseDays,
      'membership.pauseUsedDays': FieldValue.increment(actualPauseDays),
      'membership.updatedAt': FieldValue.serverTimestamp(),
      if (nextPassEnd != null)
        'membership.endAt': Timestamp.fromDate(nextPassEnd),
      if (nextPassEnd != null)
        'membership.days': _passStart == null
            ? null
            : nextPassEnd
                    .difference(DateTime(
                      _passStart!.year,
                      _passStart!.month,
                      _passStart!.day,
                    ))
                    .inDays +
                1,
      if (nextPassEnd != null)
        'membershipResumeExtendedEndAt': Timestamp.fromDate(nextPassEnd),
      'membershipPauseActualDays': actualPauseDays,
      'membershipPauseUsedDays': FieldValue.increment(actualPauseDays),
      'membershipPauseHistory': FieldValue.arrayUnion([
        {
          'type': 'resume',
          'at': Timestamp.fromDate(now),
          'actualDays': actualPauseDays,
          'plannedDays': plannedDays,
          if (nextPassEnd != null)
            'extendedEndAt': Timestamp.fromDate(nextPassEnd),
          'source': 'client_card',
        },
      ]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

    setState(() {
      _membershipPaused = false;
      _membershipPausedAt = null;
      _membershipPausePlannedDays = 0;
      _membershipResumeDueAt = null;
      _membershipPauseActualDays = actualPauseDays;
      _membershipPauseUsedDays += actualPauseDays;
      _membershipPauseReason = '';
      _memberStatus = '활성';

      if (nextPassEnd != null) {
        _passEnd = nextPassEnd;
        if (_passStart != null) {
          final s = DateTime(
            _passStart!.year,
            _passStart!.month,
            _passStart!.day,
          );
          _customDays = nextPassEnd.difference(s).inDays + 1;
          _termMonths = null;
        }
      }
    });

    _showAifcToast('회원권을 재개했어요. 실제 정지 $actualPauseDays일을 기록했어요.');
  }

  Future<void> _openMembershipPauseHistorySheet() async {
    final snap = await FirebaseFirestore.instance
        .collection('members')
        .doc(widget.memberId)
        .get();

    if (!mounted) return;

    final data = snap.data() ?? <String, dynamic>{};
    final rawHistory = data['membershipPauseHistory'];

    final history = rawHistory is List
        ? rawHistory
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    String dateText(dynamic value) {
      if (value is Timestamp) {
        return DateFormat('yyyy.MM.dd').format(value.toDate());
      }
      if (value is DateTime) {
        return DateFormat('yyyy.MM.dd').format(value);
      }
      return '-';
    }

    String itemText(Map<String, dynamic> item) {
      final type = (item['type'] ?? '').toString();
      final at = dateText(item['at']);
      final plannedDays = (item['plannedDays'] as num?)?.toInt();
      final actualDays = (item['actualDays'] as num?)?.toInt();

      if (type == 'pause') {
        return plannedDays == null
            ? '$at · 회원권 정지'
            : '$at · 회원권 정지 · 예정 ${plannedDays}일';
      }

      if (type == 'resume') {
        return actualDays == null
            ? '$at · 회원권 재개'
            : '$at · 회원권 재개 · 실제 ${actualDays}일';
      }

      return '$at · 회원권 기록';
    }

    await AifcInfoChatSheet.show(
      context: context,
      nickname: _safeAifcNickname,
      title: '정지 / 재개 이력',
      message: history.isEmpty
          ? '아직 회원권 정지 또는 재개 이력이 없어요.'
          : '최근 회원권 정지와 재개 이력을 정리했어요.',
      items: history.isEmpty
          ? const [
              '정지/재개를 진행하면 이곳에 기록됩니다.',
            ]
          : history.map(itemText).toList().reversed.take(8).toList(),
      confirmText: '확인했어요',
      userConfirmText: '확인했습니다',
      replyText: '확인되었습니다. 필요한 기록이 생기면 계속 정리해둘게요.',
      icon: Icons.history_rounded,
      accentColor: kPagePrimary,
    );
  }

  Future<void> _jumpToMembershipSection() async {
    final targetContext = _lessonMembershipSectionKey.currentContext;

    if (targetContext == null) {
      _showAifcToast('레슨 / 멤버십 영역에서 기간을 수정할 수 있어요.');
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: 0.12,
    );

    if (!mounted) return;

    _showAifcToast('레슨 / 멤버십 영역으로 이동했어요.');
  }

  Future<void> _openMembershipManageIfRequested() async {
    if (_didOpenMembershipManageOnStart) return;
    if (!widget.openMembershipManageOnStart) return;
    if (!mounted) return;

    _didOpenMembershipManageOnStart = true;

    // 회원 정보 로드가 늦는 경우를 대비해 한 프레임 더 기다립니다.
    await Future<void>.delayed(const Duration(milliseconds: 220));

    if (!mounted) return;

    await _openMembershipManageSheet();
  }

  Future<void> _openMembershipManageSheet() async {
    final rawMemberName = _nameC.text.trim();
    final memberLabel = membershipMemberLabel(rawMemberName);

    final statusText = _membershipPaused ? '현재 멤버십 정지중' : '현재 멤버십 진행중';

    final periodText = [
      if (_passStart != null || _passEnd != null)
        '${_formatDate(_passStart)} ~ ${_formatDate(_passEnd)}',
      if (_passDays() != null) '총 ${_passDays()}일',
      if (_daysLeft() != null) '남은 ${_daysLeft()}일',
    ].join(' · ');

    final result = await AifcOptionChatSheet.show<_MembershipManageAction>(
      context: context,
      nickname: _safeAifcNickname,
      title: '회원권 관리',
      message: [
        '$memberLabel의 회원권을 살펴볼게요.\n어떤 작업이 필요하신가요?',
        statusText,
        if (periodText.trim().isNotEmpty) periodText,
      ].join('\n'),
      selectedValue: null,
      closeText: '닫기',
      guidanceText: '',
      items: const [
        AifcOptionItem<_MembershipManageAction>(
          value: _MembershipManageAction.editPeriod,
          title: '회원권 기간 수정',
          subtitle: '시작일/종료일/기간을 카드에서 조정해요.',
          icon: Icons.edit_calendar_rounded,
        ),
        AifcOptionItem<_MembershipManageAction>(
          value: _MembershipManageAction.pauseHistory,
          title: '정지 / 재개 이력',
          subtitle: '회원권 정지와 재개 기록을 확인해요.',
          icon: Icons.history_rounded,
        ),
        AifcOptionItem<_MembershipManageAction>(
          value: _MembershipManageAction.contract,
          title: '회원권계약서',
          subtitle: '정지/환불/양도 조건을 문서로 남겨요.',
          icon: Icons.assignment_outlined,
        ),
        AifcOptionItem<_MembershipManageAction>(
          value: _MembershipManageAction.archive,
          title: '계약서 보관',
          subtitle: '이미지 보관 가능 · PDF는 준비 중이에요.',
          icon: Icons.inventory_2_outlined,
        ),
      ],
      pickedReplyText: (item) {
        switch (item.value) {
          case _MembershipManageAction.editPeriod:
            return '회원권 기간 수정 위치로 이동할게요.';
          case _MembershipManageAction.pauseHistory:
            return '정지와 재개 이력을 확인해볼게요.';
          case _MembershipManageAction.contract:
            return '회원권계약서를 열어볼게요.';
          case _MembershipManageAction.archive:
            return '계약서 보관 상태를 확인해볼게요.';
        }
      },
    );
    if (kDebugMode) {
      debugPrint(
        '[MTF_MEMBERSHIP_SHEET] memberIdPresent=${widget.memberId.trim().isNotEmpty} '
        'memberNamePresent=${rawMemberName.isNotEmpty} normalizedSuffix=true',
      );
    }

    if (!mounted || result == null) return;

    switch (result) {
      case _MembershipManageAction.editPeriod:
        await _jumpToMembershipSection();
        break;

      case _MembershipManageAction.pauseHistory:
        await _openMembershipPauseHistorySheet();
        break;

      case _MembershipManageAction.contract:
        await _openMembershipContractDraft();
        break;

      case _MembershipManageAction.archive:
        await _openMembershipContractDraft();
        break;
    }
  }

  Future<void> _openMembershipContractDraft() async {
    if (!await _guardTierFeature(AppTierFeatureKey.membershipContract)) {
      return;
    }

    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MembershipContractPage(
          memberId: widget.memberId,
          memberName: _nameC.text.trim(),
          trainerName: _trainerC.text.trim(),
          lessonType: _lessonType.trim(),
          totalSessions: int.tryParse(_totalSessionsC.text.trim()) ?? 0,
          remainingSessions: int.tryParse(_remainSessionsC.text.trim()) ?? 0,
          membershipStartAt: _passStart,
          membershipEndAt: _passEnd,
          membershipPaused: _membershipPaused,
        ),
      ),
    );

    if (ok == true) {
      await _loadFromFirestore();

      if (!mounted) return;

      _showAifcToast('회원권계약서 초안을 저장했어요.');
    }
  }

  List<_ContractHistoryItem> _buildContractHistoryItems() {
    final items = <_ContractHistoryItem>[];

    final total = int.tryParse(_totalSessionsC.text) ?? 0;
    final remain = int.tryParse(_remainSessionsC.text) ?? 0;
    final start = _formatDate(_passStart);
    final end = _formatDate(_passEnd);

    if (_contractSigned || total > 0 || start.isNotEmpty || end.isNotEmpty) {
      items.add(
        _ContractHistoryItem(
          title: _contractSigned ? '현재 적용 계약' : '현재 계약 정보',
          subtitle: [
            if (start.isNotEmpty || end.isNotEmpty) '기간 $start ~ $end',
            '레슨 $remain / $total',
            if (_contractSignedAt != null)
              '서명 ${DateFormat('yyyy-MM-dd').format(_contractSignedAt!)}',
          ].join(' · '),
          badge: _contractSigned ? '현재 적용중' : '작성중',
          isCurrent: true,
        ),
      );
    }

    return items;
  }

  Future<void> _openContractHistorySheet() async {
    if (!await _guardTierFeature(AppTierFeatureKey.contractHistory)) return;

    final items = _buildContractHistoryItems()
        .map(
          (item) => AifcContractHistorySheetItem(
            title: item.title,
            subtitle: item.subtitle,
            badge: item.badge,
            isCurrent: item.isCurrent,
          ),
        )
        .toList();

    final action = await AifcContractHistoryChatSheet.show(
      context: context,
      memberName: _nameC.text.trim().isEmpty ? '회원' : _nameC.text.trim(),
      items: items,
    );

    if (!mounted) return;

    if (action == AifcContractHistoryAction.openContract) {
      await _openContract();
    }
  }

  Future<void> _openTrainingLogConsent() async {
    final agreed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const TrainingLogConsentPage(),
      ),
    );

    if (agreed == true) {
      setState(() {
        _trainingLogConsentAgreed = true;
        _trainingLogConsentAgreedAt = DateTime.now();
      });

      if (mounted) {
        _showAifcToast('레슨일지 개인정보 동의가 저장되었어요.');
      }
    } else if (agreed == false) {
      if (mounted) {
        _showAifcToast('개인정보 동의가 취소되었어요.');
      }
    }
  }

  Future<void> _openTrainingLogWithConsent() async {
    if (!_trainingLogConsentAgreed) {
      final agreed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const TrainingLogConsentPage(),
        ),
      );

      if (agreed != true) {
        if (mounted) {
          _showAifcToast('개인정보 동의 후 레슨일지를 사용할 수 있어요.');
        }
        return;
      }

      setState(() {
        _trainingLogConsentAgreed = true;
        _trainingLogConsentAgreedAt = DateTime.now();
      });
    }

    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PersonalTrainingLogPage(
          memberId: widget.memberId,
          memberName: _nameC.text.trim(),
          memberPhone: _phoneC.text.trim(),
          totalSessions: int.tryParse(_totalSessionsC.text.trim()) ?? 0,
          remainingSessions: int.tryParse(_remainSessionsC.text.trim()) ?? 0,
          lastLogAt: _lastLogAt,
        ),
      ),
    );

    if (!mounted) return;
    await _loadFromFirestore();
    await _loadCareMilestonesFromFirestore();
    await _syncAutoAchievementBadges();
  }

  Future<void> _scrollToFirstRequiredField() async {
    final missing = _missingRequiredFields();
    if (missing.isEmpty) return;

    // 기본정보 첫 페이지에 필수 항목이 모여 있으니 먼저 1페이지로 이동
    if (_basicInfoPageController.hasClients && _basicInfoPageIndex != 0) {
      setState(() {
        _basicInfoPageIndex = 0;
      });

      await _basicInfoPageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }

    await Future.delayed(const Duration(milliseconds: 80));

    final GlobalKey? targetKey = switch (missing.first) {
      '이름' => _nameFieldKey,
      '성별' => _genderFieldKey,
      '생년월일' => _birthFieldKey,
      '전화번호' => _phoneFieldKey,
      _ => null,
    };

    final targetContext = targetKey?.currentContext;
    if (targetContext == null) return;

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.18,
    );
  }

  Future<void> _submitAndStay() async {
    if (!_isEditMode && _isPersonalWorkspace && !_newCardAccessAllowed) {
      return;
    }
    _normalizeBirthInput(validateField: true);
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      setState(() {
        _showRequiredFieldsNotice = true;
      });

      await _scrollToFirstRequiredField();

      if (!mounted) return;
      _showAifcToast('필수 입력 항목을 먼저 확인해드릴게요.');

      return;
    }

    if (_showRequiredFieldsNotice) {
      setState(() {
        _showRequiredFieldsNotice = false;
      });
    }

    final phoneValidation = validateKoreanMobilePhone(
      _phoneC.text,
      required: true,
    );

    if (!phoneValidation.isValid) {
      setState(() {
        _showRequiredFieldsNotice = true;
      });

      await _scrollToBasicInfoField(_phoneFieldKey);

      if (!mounted) return;

      _showAifcToast(phoneValidation.errorText ?? '휴대폰 번호를 확인해주세요.');
      return;
    }

    final birthValidation = validateMemberBirthDate(
      _birthTextC.text,
      required: true,
    );

    if (!birthValidation.isValid) {
      setState(() {
        _showRequiredFieldsNotice = true;
      });

      await _scrollToBasicInfoField(_birthFieldKey);

      if (!mounted) return;

      _showAifcToast(birthValidation.errorText ?? '생년월일을 확인해주세요.');
      return;
    }

    final phoneAvailable = await _ensurePhoneIsNotDuplicatedBeforeSave();

    if (!phoneAvailable) {
      return;
    }

    if (!_membershipNotRegistered) {
      _lastRegisteredAt ??= DateTime.now();
    }

    String? photoUrl;
    try {
      photoUrl = await _uploadProfileIfAny();
      _photoUrl = photoUrl ?? _photoUrl;
    } catch (_) {}

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: kPagePrimary),
        ),
      );
    }

    try {
      final raw = _collectFormMap(includeRegisteredAt: true);
      final docRef =
          FirebaseFirestore.instance.collection('members').doc(widget.memberId);

      final preSnap = await docRef.get();
      final bool isNew = !preSnap.exists;

      void offerNextActionsDialog() {
        if (!mounted) return;

        _showAifcToast(
          isNew ? '회원카드를 저장했어요.' : '회원정보를 저장했어요.',
          bottomOffset: 110,
          duration: const Duration(milliseconds: 1500),
        );
      }

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final payload = _toFirestorePayload(
          raw,
          includeCreatedAt: isNew,
          photoUrl: photoUrl,
        );
        tx.set(docRef, payload, SetOptions(merge: true));
      });

      if (isNew) {
        await _bootstrapMemberArtifacts(
          memberId: widget.memberId,
          raw: raw,
          photoUrl: _photoUrl,
        );
      }

      await _syncAutoAchievementBadges();

      await _clearDraft();

      if (!mounted) return;

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      offerNextActionsDialog();

      Future.delayed(const Duration(milliseconds: 2600), () {
        if (!mounted) return;
        _maybeShowClientCardNudges();
      });
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      if (mounted) {
        _showAifcToast('저장 중 오류가 발생했어요. 다시 시도해주세요.');
      }
    }
  }

  Future<void> _resetForm() async {
    final ok = await _showAifcConfirm(
      title: '입력 내용을 초기화할까요?',
      message: '현재 입력한 내용과 저장된 초안을 초기화합니다.\n'
          '이미 저장된 회원 정보는 저장 버튼을 누르기 전까지 바뀌지 않아요.',
      cancelText: '취소',
      confirmText: '리셋',
      userCancelText: '취소할게요',
      userConfirmText: '리셋할게요',
      cancelReplyText: '좋아요. 입력 내용은 그대로 둘게요.',
      confirmReplyText: '확인했어요. 입력 내용을 초기화할게요.',
      danger: true,
    );

    if (!ok) return;

    setState(() {
      _profileBytes = null;
      _photoUrl = null;
      _headerDisplayName = _nameC.text.trim();
      _gender = '미입력';
      _birthDate = null;
      _birthTextC.clear();
      _phoneC.text = widget.initialPhone ?? '';
      _postalC.clear();
      _addrC.clear();
      _addrDetailC.clear();
      _membershipGrade = 'GOLD';
      _jobC.clear();
      _memberStatus = '활성';
      _lessonType = '미입력';
      _headerGroupLabel = 'MORE THAN GYM';
      _selectedGroupId = '__ungrouped__';

      _lessonsNotRegistered = false;
      _totalSessionsC.text = '0';
      _remainSessionsC.text = '0';

      _membershipNotRegistered = false;
      _termMonths = null;
      _customDays = null;
      _passStart = widget.initialVisitDate;
      _passEnd = null;
      _lastRegisteredAt = null;
      _noShowDeductedCount = 0;
      _noShowUndeductedCount = 0;
      _serviceSessionCount = 0;
      _reregisterCount = 0;
      _lastReregisterAt = null;

      _inbodyNotProvided = false;
      _diseaseC.clear();
      _medicineC.clear();
      _heightC.text = '170.0';
      _weightC.text = '65.0';
      _bfPctC.text = '18.5';
      _smmC.text = '29.0';
      _bfKgC.text = '12.0';

      _nextReservation = null;
      _noteC.text = '';
      _anniversaryDate = null;
      _anniversaryLabelC.text = '기념일';
      _specialEventC.clear();
      _contractSigned = false;
      _contractSignedAt = null;
      _confirmTalkEnabled = false;
      _isHeaderExpanded = false;
      _trainingLogConsentAgreed = false;
      _trainingLogConsentAgreedAt = null;
      _autoMilestoneEnabled = true;
      _ddayFollowUpEnabled = true;
      _membershipPauseUsedDays = 0;
      _membershipContractDraftExists = false;
      _membershipContractStatus = '';
      _membershipContractMaxPauseDays = null;
    });

    await _clearDraft();

    if (!mounted) return;
    _showAifcToast('입력 내용을 초기화했어요.');
  }

  String get _safeAifcNickname {
    // TODO: 실제 닉네임 변수 연결 전까지 기본값
    const nickname = '강사';

    final value = nickname.trim();

    if (value.isEmpty) {
      return '강사';
    }

    final cleaned = value.endsWith('님')
        ? value.substring(0, value.length - 1).trim()
        : value;

    return cleaned.isEmpty ? '강사' : cleaned;
  }

  Future<void> _confirmDeleteMember() async {
    final confirmed = await AifcConfirmChatSheet.show(
      context: context,
      nickname: _safeAifcNickname,
      title: '회원 정보를 삭제할까요?',
      message: '삭제하면 회원리스트에서는 즉시 사라집니다.\n\n'
          '단, 복구 요청을 위해 삭제일 기준 7일간 보관됩니다.\n'
          '복구가 필요한 경우 고객센터로 문의해주세요.',
      cancelText: '취소',
      confirmText: '삭제',
      userCancelText: '취소할게요',
      userConfirmText: '삭제할게요',
      cancelReplyText: '좋아요. 회원 정보는 그대로 둘게요.',
      confirmReplyText: '확인했어요. 회원 삭제를 진행할게요.',
      danger: true,
    );

    if (!confirmed) return;

    await _softDeleteMember();
  }

  Future<void> _jumpToNoteEditor() async {
    if (_memoPageController.hasClients && _memoPageIndex != 0) {
      setState(() {
        _memoPageIndex = 0;
      });

      await _memoPageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }

    await Future.delayed(const Duration(milliseconds: 80));

    final noteContext = _noteFieldKey.currentContext;
    if (noteContext != null) {
      await Scrollable.ensureVisible(
        noteContext,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.22,
      );
    }

    await Future.delayed(const Duration(milliseconds: 430));

    if (!mounted) return;
    FocusScope.of(context).requestFocus(_noteFocusNode);
  }

  Future<void> _showMemoEditDialog() async {
    final controller = TextEditingController(text: _noteC.text);

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Special Note',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '지인소개, 질환 이력, 특이사항 등',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(sheetContext, controller.text);
                      },
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );

    if (result == null || !mounted) return;

    setState(() {
      _noteC.text = result;
    });
  }

  Future<void> _unlinkSchedulesFromDeletedMember(String memberId) async {
    final cleanMemberId = memberId.trim();
    if (cleanMemberId.isEmpty) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('schedules')
          .where('memberId', isEqualTo: cleanMemberId)
          .get();

      if (snap.docs.isEmpty) return;

      const int chunkSize = 450;

      for (int i = 0; i < snap.docs.length; i += chunkSize) {
        final batch = FirebaseFirestore.instance.batch();
        final chunk = snap.docs.skip(i).take(chunkSize);

        for (final doc in chunk) {
          batch.set(
            doc.reference,
            {
              'memberId': FieldValue.delete(),
              'phone': FieldValue.delete(),
              'totalSessions': FieldValue.delete(),
              'remainingSessions': FieldValue.delete(),
              'remainSessions': FieldValue.delete(),
              'sessionSnapshotTotal': FieldValue.delete(),
              'sessionSnapshotRemainBefore': FieldValue.delete(),
              'sessionSnapshotRemainAfter': FieldValue.delete(),
              'sessionSnapshotDoneBefore': FieldValue.delete(),
              'sessionSnapshotDoneAfter': FieldValue.delete(),
              'sessionSnapshotLessonNumber': FieldValue.delete(),
              'sessionSnapshotLabel': FieldValue.delete(),
              'linkedMemberDeleted': true,
              'deletedMemberId': cleanMemberId,
              'deletedMemberName': _nameC.text.trim(),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }

        await batch.commit();
      }
    } catch (_) {
      // 회원 삭제 과정에서 스케줄 연결 해제 실패 시 별도 문구를 띄우지 않습니다.
      // 홈에서는 삭제된 회원 연결을 다시 복구하지 않고, 이후 저장/수정 시 미등록 레슨처럼 처리합니다.
    }
  }

  Future<void> _softDeleteMember() async {
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(color: kPagePrimary),
        ),
      );
    }

    try {
      final memberRef =
          FirebaseFirestore.instance.collection('members').doc(widget.memberId);

      final now = DateTime.now();
      final deleteScheduledAt = now.add(const Duration(days: 7));

      await memberRef.set({
        'isDeleted': true,
        'deletedAt': Timestamp.fromDate(now),
        'deleteScheduledAt': Timestamp.fromDate(deleteScheduledAt),
        'deleteStatus': 'pending_delete',
        'deletedSource': 'client_card',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _unlinkSchedulesFromDeletedMember(widget.memberId);

      if (!mounted) return;

      // 로딩 다이얼로그 닫기
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      _showAifcToast('삭제 처리했어요. 복구가 필요하면 고객센터로 문의해주세요.');

      // 회원카드 페이지 닫기 → 회원리스트에서는 isDeleted == true라 즉시 숨김
      if (Navigator.canPop(context)) {
        Navigator.of(context).maybePop();
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (!mounted) return;

      _showAifcToast('삭제 처리했어요. 복구가 필요하면 고객센터로 문의해주세요.');
    }
  }

  InputDecoration _inputDecoration(
    String label, {
    String? hint,
    String? suffixText,
    Widget? suffixIcon,
    bool requiredField = false,
  }) {
    final normalBorderColor =
        requiredField ? const Color(0xFFC7D2FE) : kPageBorder;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixText: suffixText,
      suffixIcon: suffixIcon,
      errorStyle: const TextStyle(
        height: 0,
        fontSize: 0,
      ),
      errorMaxLines: 1,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: kPageFieldBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: normalBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: normalBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kPagePrimary, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFEF4444),
          width: 1.4,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFEF4444),
          width: 1.6,
        ),
      ),
    );
  }

  Widget _buildHeaderContractButton() {
    return SizedBox(
      width: 36,
      height: 36,
      child: InkWell(
        onTap: _openContract,
        borderRadius: BorderRadius.circular(999),
        child: const Center(
          child: Icon(
            Icons.description_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoPagerHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _basicInfoPageIndex == 0 ? '기본정보 1/2' : '기본정보 2/2',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: kPageMuted,
          ),
        ),
        Row(
          children: [
            AnimatedOpacity(
              opacity: _basicInfoPageIndex == 0 ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                tooltip: '이전',
                onPressed: _basicInfoPageIndex == 0
                    ? null
                    : () {
                        _basicInfoPageController.previousPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                        );
                      },
                icon: const Icon(Icons.chevron_left_rounded),
                visualDensity:
                    const VisualDensity(horizontal: -3, vertical: -3),
              ),
            ),
            AnimatedOpacity(
              opacity: _basicInfoPageIndex == 1 ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                tooltip: '다음',
                onPressed: _basicInfoPageIndex == 1
                    ? null
                    : () {
                        _basicInfoPageController.nextPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                        );
                      },
                icon: const Icon(Icons.chevron_right_rounded),
                visualDensity:
                    const VisualDensity(horizontal: -3, vertical: -3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMemberSetupPagerHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _memberSetupPageIndex == 0 ? '상태/등급 1/2' : '상태/등급 2/2',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: kPageMuted,
          ),
        ),
        Row(
          children: [
            AnimatedOpacity(
              opacity: _memberSetupPageIndex == 0 ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                tooltip: '이전',
                onPressed: _memberSetupPageIndex == 0
                    ? null
                    : () {
                        _memberSetupPageController.previousPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                        );
                      },
                icon: const Icon(Icons.chevron_left_rounded),
                visualDensity:
                    const VisualDensity(horizontal: -3, vertical: -3),
              ),
            ),
            AnimatedOpacity(
              opacity: _memberSetupPageIndex == 1 ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                tooltip: '다음',
                onPressed: _memberSetupPageIndex == 1
                    ? null
                    : () {
                        _memberSetupPageController.nextPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                        );
                      },
                icon: const Icon(Icons.chevron_right_rounded),
                visualDensity:
                    const VisualDensity(horizontal: -3, vertical: -3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMemberSetupPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final selected = _memberSetupPageIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: selected ? kPagePrimary : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _buildBodyHealthPagerHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _bodyHealthPageIndex == 0 ? '인바디/건강 1/2' : '인바디/건강 2/2',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: kPageMuted,
          ),
        ),
        Row(
          children: [
            AnimatedOpacity(
              opacity: _bodyHealthPageIndex == 0 ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                tooltip: '이전',
                onPressed: _bodyHealthPageIndex == 0
                    ? null
                    : () {
                        _bodyHealthPageController.previousPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                        );
                      },
                icon: const Icon(Icons.chevron_left_rounded),
                visualDensity:
                    const VisualDensity(horizontal: -3, vertical: -3),
              ),
            ),
            AnimatedOpacity(
              opacity: _bodyHealthPageIndex == 1 ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                tooltip: '다음',
                onPressed: _bodyHealthPageIndex == 1
                    ? null
                    : () {
                        _bodyHealthPageController.nextPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                        );
                      },
                icon: const Icon(Icons.chevron_right_rounded),
                visualDensity:
                    const VisualDensity(horizontal: -3, vertical: -3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBodyHealthPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final selected = _bodyHealthPageIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: selected ? kPagePrimary : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _buildMemoPagerHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          _memoPageIndex == 0 ? '메모 1/2' : 'MORE 포커스 2/2',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: kPageMuted,
          ),
        ),
        Row(
          children: [
            AnimatedOpacity(
              opacity: _memoPageIndex == 0 ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                tooltip: '이전',
                onPressed: _memoPageIndex == 0
                    ? null
                    : () {
                        _memoPageController.previousPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                        );
                      },
                icon: const Icon(Icons.chevron_left_rounded),
                visualDensity:
                    const VisualDensity(horizontal: -3, vertical: -3),
              ),
            ),
            AnimatedOpacity(
              opacity: _memoPageIndex == 1 ? 0.0 : 1.0,
              duration: const Duration(milliseconds: 180),
              child: IconButton(
                tooltip: '다음',
                onPressed: _memoPageIndex == 1
                    ? null
                    : () {
                        _memoPageController.nextPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                        );
                      },
                icon: const Icon(Icons.chevron_right_rounded),
                visualDensity:
                    const VisualDensity(horizontal: -3, vertical: -3),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMemoPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final selected = _memoPageIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: selected ? kPagePrimary : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _buildBasicInfoPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(2, (index) {
        final selected = _basicInfoPageIndex == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: selected ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: selected ? kPagePrimary : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  String _careMilestoneDisplayText(_CareMilestoneItem item) {
    final title = item.title.trim();

    final dueDate = item.dueDate;
    if (dueDate == null) return title;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dueDate.year, dueDate.month, dueDate.day);

    final diff = target.difference(today).inDays;

    final dday = diff > 0
        ? 'D-$diff'
        : diff == 0
            ? 'D-DAY'
            : 'D+${diff.abs()}';

    return '$title $dday';
  }

  String _eventSummaryText() {
    final items = <String>[];

    if (_anniversaryDate != null) {
      final label = _anniversaryLabelText();
      items.add(
          'MORE 데이 $label ${DateFormat('MM.dd').format(_anniversaryDate!)}');
    } else if (_birthDate != null) {
      items.add('MORE 데이 생일 ${DateFormat('MM.dd').format(_birthDate!)}');
    }

    final total = int.tryParse(_totalSessionsC.text) ?? 0;
    final remain = int.tryParse(_remainSessionsC.text) ?? 0;

    if (total >= 100) {
      items.add('100번째 레슨');
    }

    if (_reregisterCount >= 10) {
      items.add('재등록 10회');
    }

    if (remain > 0 && remain <= 5) {
      items.add('잔여 ${remain}회');
    }

    if (_lastRegisteredAt != null) {
      final days = DateTime.now()
          .difference(DateTime(
            _lastRegisteredAt!.year,
            _lastRegisteredAt!.month,
            _lastRegisteredAt!.day,
          ))
          .inDays;

      if (days >= 100) {
        items.add('레슨 시작 100일');
      }
    }

    final firestoreMilestones = _careMilestones
        .where((item) => item.isActive)
        .map(_careMilestoneDisplayText)
        .where((text) => text.trim().isNotEmpty)
        .take(4)
        .toList();

    items.addAll(firestoreMilestones);

    if (_specialEventC.text.trim().isNotEmpty) {
      items.add(_specialEventC.text.trim());
    }

    if (items.isEmpty) return '표시할 MORE 포커스 없음';

    return items.join(' · ');
  }

  String _warningSummaryText() {
    final parts = <String>[];

    final disease = _diseaseC.text.trim();
    final medicine = _medicineC.text.trim();
    final note = _noteC.text.trim();
    final special = _specialEventC.text.trim();

    if (disease.isNotEmpty) parts.add('질병');
    if (medicine.isNotEmpty) parts.add('복약');
    if (note.isNotEmpty) parts.add('메모');
    if (special.isNotEmpty) parts.add('일정');

    if (parts.isEmpty) return '없음';
    return parts.join(' · ');
  }

  bool _hasAnyMeaningfulMilestone() {
    if (_specialEventC.text.trim().isNotEmpty) return true;
    if (_anniversaryDate != null) return true;

    final activeFirestoreMilestones =
        _careMilestones.where((item) => item.isActive).toList();

    if (activeFirestoreMilestones.isNotEmpty) return true;
    if (_computedAutoMilestoneTexts().isNotEmpty) return true;

    return false;
  }

  Future<bool> _maybeShowRequiredInfoNudge() async {
    if (!mounted) return false;

    final missing = _missingRequiredFields();

    if (!_showRequiredFieldsNotice || missing.isEmpty) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final alreadySeen = prefs.getBool(_requiredInfoNudgeKey) ?? false;
    if (alreadySeen) return false;

    await prefs.setBool(_requiredInfoNudgeKey, true);

    if (!mounted) return false;

    final result = await AifcInteraction.ask(
      context: context,
      question: '아직 ${missing.join(', ')} 정보가 남아 있어요.\n'
          '지금 다 채우지 않아도 괜찮아요. 필요할 때 제가 다시 챙겨드릴게요.',
      inputLabel: '예: 나중에 할게요 / 지금 확인할게요',
      skipLabel: '나중에',
      onSkip: () {},
      onSave: (value) async {
        final answer = value.trim();

        if (answer.contains('지금') ||
            answer.contains('확인') ||
            answer.contains('할게') ||
            answer.contains('네')) {
          return '좋아요. 아래 필수 입력 항목 카드에서 천천히 채워주세요 😊';
        }

        return '좋아요. 천천히 입력해도 괜찮아요.\n필요할 때 제가 다시 챙겨드릴게요.';
      },
    );

    if (!mounted) return true;

    if (result != null &&
        (result.contains('지금') ||
            result.contains('확인') ||
            result.contains('할게') ||
            result.contains('네'))) {
      _showAifcToast('아래 필수 입력 항목을 확인해보세요.');
    }

    return true;
  }

  Future<bool> _maybeShowMilestoneNudge() async {
    if (!mounted) return false;

    if (_hasAnyMeaningfulMilestone()) return false;

    final prefs = await SharedPreferences.getInstance();
    final alreadySeen = prefs.getBool(_milestoneNudgeKey) ?? false;
    if (alreadySeen) return false;

    await prefs.setBool(_milestoneNudgeKey, true);

    if (!mounted) return false;

    final result = await AifcInteraction.ask(
      context: context,
      question: '이 회원님에게 기억해둘 관리 포인트가 있을까요?\n'
          '예를 들면 무릎 이슈, 바디프로필 D-DAY, 재등록 체크 같은 내용이에요.',
      inputLabel: '예: 무릎 통증 주의 / 바디프로필 D-60',
      skipLabel: '나중에',
      onSkip: () {},
      onSave: (value) async {
        final title = value.trim();

        if (title.isEmpty) {
          return '좋아요. 나중에 필요할 때 다시 남겨도 괜찮아요.';
        }

        final ref = FirebaseFirestore.instance
            .collection('members')
            .doc(widget.memberId)
            .collection('care_milestones');

        await ref.add({
          'title': title,
          'type': 'manual',
          'status': 'active',
          'source': 'client_card_ai_fc_nudge',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await _loadCareMilestonesFromFirestore();

        return '$title 관리 포인트로 기억해둘게요 😊';
      },
    );

    if (!mounted) return true;

    if (result != null && result.trim().isNotEmpty) {
      _showAifcToast('관리 포인트를 기억했어요.');
    }

    return true;
  }

  Future<void> _maybeShowClientCardNudges() async {
    if (!mounted) return;

    final showedRequired = await _maybeShowRequiredInfoNudge();

    if (showedRequired) return;

    await Future.delayed(const Duration(milliseconds: 350));

    if (!mounted) return;

    await _maybeShowMilestoneNudge();
  }

  static const List<String> _baseLessonTypeOptions = [
    '미입력',
    'PT',
    '필라테스',
    '요가',
    '그룹',
    '줌바',
    '재활',
  ];

  bool get _isLessonTypeLockedByContract {
    return !_lessonsNotRegistered &&
        (_contractSigned || _contractSignedAt != null);
  }

  String get _lessonTypeDropdownValue {
    final value = _lessonType.trim();

    if (value.isEmpty) return '미입력';

    if (_baseLessonTypeOptions.contains(value)) {
      return value;
    }

    return _customLessonTypeValue;
  }

  bool get _isCustomLessonTypeSelected {
    return _lessonTypeDropdownValue == _customLessonTypeValue;
  }

  void _syncCustomLessonTypeControllerIfNeeded() {
    final value = _lessonType.trim();

    if (value.isEmpty) return;
    if (_baseLessonTypeOptions.contains(value)) return;

    if (_customLessonTypeC.text.trim() != value) {
      _customLessonTypeC.text = value;
    }
  }

  bool _isActiveDuplicateMemberDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    if (doc.id == widget.memberId) return false;

    final data = doc.data();

    if (data['isDeleted'] == true) return false;

    final deleteStatus = (data['deleteStatus'] ?? '').toString().trim();
    if (deleteStatus == 'pending_delete') return false;

    return true;
  }

  Future<void> _scrollToBasicInfoField(GlobalKey key) async {
    if (_basicInfoPageController.hasClients && _basicInfoPageIndex != 0) {
      setState(() {
        _basicInfoPageIndex = 0;
      });

      await _basicInfoPageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }

    await Future.delayed(const Duration(milliseconds: 80));

    final targetContext = key.currentContext;
    if (targetContext == null) return;

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      alignment: 0.18,
    );
  }

  Future<bool> _ensurePhoneIsNotDuplicatedBeforeSave() async {
    final phoneDigits = normalizeMemberPhone(_phoneC.text);

    if (phoneDigits.isEmpty) {
      return true;
    }

    final validation = validateKoreanMobilePhone(
      phoneDigits,
      required: true,
    );

    if (!validation.isValid) {
      return true;
    }

    final formattedPhone = formatKoreanMobilePhone(phoneDigits);
    final rawPhone = _phoneC.text.trim();

    final queryTargets = <MapEntry<String, String>>[
      MapEntry('phoneNormalized', phoneDigits),
      MapEntry('phone', phoneDigits),
      MapEntry('phoneDisplay', formattedPhone),
      if (rawPhone.isNotEmpty) MapEntry('phoneDisplay', rawPhone),
    ];

    final duplicateDocs =
        <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};

    try {
      for (final target in queryTargets) {
        final value = target.value.trim();
        if (value.isEmpty) continue;

        final snapshot = await FirebaseFirestore.instance
            .collection('members')
            .where(target.key, isEqualTo: value)
            .limit(8)
            .get();

        for (final doc in snapshot.docs) {
          if (_isActiveDuplicateMemberDoc(doc)) {
            duplicateDocs[doc.id] = doc;
          }
        }
      }

      if (duplicateDocs.isEmpty) {
        if (mounted && _phoneDuplicateMessage != null) {
          setState(() {
            _phoneDuplicateMessage = null;
          });
        }

        return true;
      }

      final names = duplicateDocs.values
          .map((doc) => (doc.data()['name'] ?? '').toString().trim())
          .where((name) => name.isNotEmpty)
          .take(2)
          .toList();

      final message = names.isEmpty
          ? '같은 휴대폰 번호로 등록된 회원이 이미 있어요.'
          : '같은 휴대폰 번호 회원이 이미 있어요: ${names.join(', ')}';

      if (!mounted) return false;

      setState(() {
        _phoneDuplicateMessage = message;
        _showRequiredFieldsNotice = true;
      });

      await _scrollToBasicInfoField(_phoneFieldKey);

      if (!mounted) return false;

      _showAifcToast(message);
      return false;
    } catch (e) {
      debugPrint('회원 휴대폰 중복 확인 실패: $e');

      // 네트워크 문제로 저장 전체를 막지는 않습니다.
      // 정상 연결 상태에서는 위 로직으로 중복을 차단합니다.
      return true;
    }
  }

  List<String> _missingRequiredFields() {
    final items = <String>[];

    if (_nameC.text.trim().isEmpty) {
      items.add('이름');
    }

    if (_gender != '남' && _gender != '여') {
      items.add('성별');
    }

    final birthValidation = validateMemberBirthDate(
      _birthTextC.text,
      required: true,
    );

    if (!birthValidation.isValid) {
      items.add('생년월일');
    }

    final phoneValidation = validateKoreanMobilePhone(
      _phoneC.text,
      required: true,
    );

    if (!phoneValidation.isValid || _phoneDuplicateMessage != null) {
      items.add('전화번호');
    }

    if (_lessonType.trim().isEmpty || _lessonType == '미입력') {
      items.add('레슨형태');
    }

    return items;
  }

  Widget _buildRequiredFieldsNoticeCard() {
    final missing = _missingRequiredFields();

    if (!_showRequiredFieldsNotice || missing.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Color(0xFFD97706),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '필수 입력 항목이 남아 있어요',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '먼저 저장하고, 아래 항목은 나중에 이어서 입력할 수 있어요.',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF92400E).withOpacity(0.84),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: missing.map((item) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFFCD34D)),
                ),
                child: Text(
                  item,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF92400E),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  _MemberGradeTheme _gradeTheme() {
    switch (_membershipGrade) {
      case 'VVIP':
        return const _MemberGradeTheme(
          gradient: [Color(0xFF7C3AED), Color(0xFFEC4899)],
          accent: Color(0xFFF9A8D4),
          border: Color(0xFFF5D0FE),
        );
      case 'VIP':
        return const _MemberGradeTheme(
          gradient: [Color(0xFF4338CA), Color(0xFF7C3AED)],
          accent: Color(0xFFC4B5FD),
          border: Color(0xFFD8B4FE),
        );
      case 'GOLD':
        return const _MemberGradeTheme(
          gradient: [Color(0xFFD97706), Color(0xFFF59E0B)],
          accent: Color(0xFFFDE68A),
          border: Color(0xFFFCD34D),
        );
      case 'SILVER':
        return const _MemberGradeTheme(
          gradient: [Color(0xFF64748B), Color(0xFF94A3B8)],
          accent: Color(0xFFE2E8F0),
          border: Color(0xFFCBD5E1),
        );
      case 'BRONZE':
        return const _MemberGradeTheme(
          gradient: [Color(0xFF92400E), Color(0xFFB45309)],
          accent: Color(0xFFFCD7AA),
          border: Color(0xFFF59E0B),
        );
      default:
        return const _MemberGradeTheme(
          gradient: [Color(0xFF4F46E5), Color(0xFF9333EA)],
          accent: Color(0xFFC4B5FD),
          border: Color(0xFFD8B4FE),
        );
    }
  }

  String _contractStatusText() {
    if (_contractSigned) return '레슨계약서 완료';
    return '레슨계약서 미작성';
  }

  IconData _memberStatusIcon() {
    switch (_memberStatus) {
      case '활성':
        return Icons.radio_button_on_rounded;
      case '휴면':
        return Icons.pause_circle_outline_rounded;
      case '만료':
        return Icons.do_not_disturb_on_outlined;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _memberStatusLabel() {
    switch (_memberStatus) {
      case '활성':
        return '활성';
      case '휴면':
        return '휴면';
      case '만료':
        return '만료';
      default:
        return _memberStatus;
    }
  }

  String _membershipLabelText() {
    if (_membershipNotRegistered) return '-';

    if (_termMonths != null) {
      return '${_termMonths}개월 회원권';
    }

    if (_customDays != null) {
      return '${_customDays}일 회원권';
    }

    return '회원권';
  }

  String _membershipPeriodText() {
    if (_membershipNotRegistered || _passStart == null || _passEnd == null) {
      return '-';
    }

    final start = DateFormat('yyyy. MM. dd').format(_passStart!);
    final end = DateFormat('yyyy. MM. dd').format(_passEnd!);
    final daysLeft = _daysLeft();

    final remainText = daysLeft == null
        ? ''
        : daysLeft >= 0
            ? ' (${daysLeft}일 남음)'
            : ' (${daysLeft.abs()}일 지남)';

    return '$start - $end$remainText';
  }

  Widget _buildMembershipPauseStatusChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE4E6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFFDA4AF)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFB91C1C),
          fontSize: 10.8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _lessonTypeOnlyText() {
    if (_lessonsNotRegistered) return '-';

    final value = _lessonType.trim();
    if (value.isEmpty || value == '미입력') return '-';

    return value;
  }

  String _consentStatusText() {
    if (_trainingLogConsentAgreed) return '개인정보동의 완료';
    return '개인정보동의 필요';
  }

  bool get _hideTopActionCards {
    if (!_isClientCardLoaded) return true;
    return _trainingLogConsentAgreed;
  }

  String _trainingLogReadyText() {
    if (_trainingLogConsentAgreed) return '레슨일지 사용 가능';
    return '레슨일지 사용 전 동의 필요';
  }

  Widget _buildHeaderExpandedBox() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _GlassHeaderChip(text: _contractStatusText()),
              _GlassHeaderChip(text: _consentStatusText()),
              _GlassHeaderChip(text: '등급 $_membershipGrade'),
              _GlassHeaderChip(text: '재등록 $_reregisterCount회'),
              _GlassHeaderChip(text: '노쇼 차감 $_noShowDeductedCount회'),
              _GlassHeaderChip(text: '노쇼 미차감 $_noShowUndeductedCount회'),
              _GlassHeaderChip(text: '서비스 $_serviceSessionCount회'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '간단한 기념일 / 메모',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.88),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (_anniversaryDate != null)
                  Text(
                    '기념일 ${DateFormat('yyyy.MM.dd').format(_anniversaryDate!)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                if (_specialEventC.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '일정 ${_specialEventC.text.trim()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                  ),
                if (_noteC.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _noteC.text.trim(),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ),
                if (_anniversaryDate == null &&
                    _specialEventC.text.trim().isEmpty &&
                    _noteC.text.trim().isEmpty)
                  Text(
                    '등록된 기념일이나 메모가 없습니다.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.78),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderLabelValue({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.72),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _consentStatusChip() {
    final color = _trainingLogConsentAgreed
        ? const Color(0xFF16A34A)
        : const Color(0xFFDC2626);

    final text = _trainingLogConsentAgreed
        ? (_trainingLogConsentAgreedAt == null
            ? '동의 완료'
            : '동의 ${DateFormat('yyyy-MM-dd').format(_trainingLogConsentAgreedAt!)}')
        : '동의필요';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _contractSummaryCard() {
    final signedText = _contractSigned ? '서명 완료' : '서명 전';
    final signedColor =
        _contractSigned ? const Color(0xFF16A34A) : const Color(0xFFDC2626);

    return _SectionCard(
      icon: Icons.description_outlined,
      title: '레슨계약서 / 서명',
      subtitle: _contractSignedAt == null
          ? '레슨계약서 없이도 먼저 등록하고, 나중에 작성할 수 있어요'
          : '서명일 ${DateFormat('yyyy-MM-dd').format(_contractSignedAt!)}',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: signedColor.withOpacity(0.10),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          signedText,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: signedColor,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _openContract,
              icon: const Icon(Icons.edit_document),
              label: Text(_contractSigned ? '레슨계약서 확인 / 재서명' : '레슨계약서 작성 / 서명'),
              style: FilledButton.styleFrom(
                backgroundColor: kPagePrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _openContractHistorySheet,
              icon: const Icon(Icons.history),
              label: const Text('지난 레슨계약서'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPageText,
                side: const BorderSide(color: kPageBorder),
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trainingLogConsentCard() {
    final needsConsent = !_trainingLogConsentAgreed;

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: needsConsent ? const Color(0xFFEF4444) : kPageBorder,
          width: needsConsent ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (needsConsent ? const Color(0xFFEF4444) : Colors.black)
                .withOpacity(needsConsent ? 0.10 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kPagePrimary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.privacy_tip_outlined,
                  color: kPagePrimary,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '개인정보동의서',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: kPageText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _trainingLogConsentAgreedAt == null
                          ? '레슨계약서 없이 레슨일지를 사용하는 경우 필요해요'
                          : '동의일 ${DateFormat('yyyy-MM-dd').format(_trainingLogConsentAgreedAt!)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: kPageMuted,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _consentStatusChip(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _openTrainingLogConsent,
                  icon: const Icon(Icons.description_outlined),
                  label: Text(_trainingLogConsentAgreed ? '동의서 확인' : '동의서 작성'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kPagePrimary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _trainingLogConsentAgreed = false;
                      _trainingLogConsentAgreedAt = null;
                    });
                    _showAifcToast('개인정보동의 상태를 초기화했어요.');
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('동의 초기화'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPageText,
                    side: const BorderSide(color: kPageBorder),
                    minimumSize: const Size(0, 46),
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
    );

    return card;
  }

  Widget _basicInfoSection() {
    return _ExpandableSectionCard(
      icon: Icons.person_outline_rounded,
      title: '회원 정보',
      subtitle: '담당 회원의 기본정보를 입력해요',
      initiallyExpanded: !_isEditMode,
      child: Column(
        children: [
          _buildBasicInfoPagerHeader(),
          const SizedBox(height: 8),
          SizedBox(
            height: 223,
            child: PageView(
              controller: _basicInfoPageController,
              onPageChanged: (index) {
                setState(() {
                  _basicInfoPageIndex = index;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              key: _nameFieldKey,
                              controller: _nameC,
                              decoration: _inputDecoration(
                                '이름',
                                suffixIcon: _buildAgeSuffix(),
                                requiredField: true,
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? '이름 입력'
                                  : null,
                              onChanged: (v) => setState(() {
                                _headerDisplayName = v.trim();
                              }),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              key: _genderFieldKey,
                              value: _gender,
                              decoration: _inputDecoration(
                                '성별',
                                requiredField: true,
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: '미입력', child: Text('미입력')),
                                DropdownMenuItem(value: '남', child: Text('남')),
                                DropdownMenuItem(value: '여', child: Text('여')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _gender = v ?? '미입력'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              key: _birthFieldKey,
                              controller: _birthTextC,
                              focusNode: _birthFocusNode,
                              decoration: _inputDecoration(
                                '생년월일',
                                hint: 'YYYY-MM-DD',
                                requiredField: true,
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.date_range),
                                  onPressed: () async {
                                    final current = _birthDate ??
                                        _parseDate(_birthTextC.text);
                                    final now = DateTime.now();
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: current ??
                                          DateTime(now.year - 25, now.month,
                                              now.day),
                                      firstDate: DateTime(1900),
                                      lastDate: now,
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        _birthDate = picked;
                                        _birthTextC.text = _formatDate(picked);
                                      });
                                    }
                                  },
                                ),
                              ),
                              keyboardType: TextInputType.datetime,
                              inputFormatters: const [
                                MemberBirthDateInputFormatter(),
                              ],
                              textInputAction: TextInputAction.done,
                              onEditingComplete: () {
                                _normalizeBirthInput(validateField: true);
                                _birthFocusNode.unfocus();
                              },
                              onChanged: (value) {
                                setState(() {
                                  _birthDate = _parseDate(value);
                                });
                              },
                              validator: (v) {
                                final result = validateMemberBirthDate(
                                  v ?? '',
                                  required: true,
                                );

                                return result.isValid
                                    ? null
                                    : result.errorText ?? '생년월일을 확인해주세요.';
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _jobC,
                              decoration: _inputDecoration(
                                '직업',
                                hint: '예: 사무직',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: _phoneFieldKey,
                        controller: _phoneC,
                        decoration: _inputDecoration(
                          '전화번호',
                          hint: '010-1234-5678',
                          requiredField: true,
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: const [
                          MemberPhoneInputFormatter(),
                        ],
                        validator: (v) {
                          final result = validateKoreanMobilePhone(
                            v ?? '',
                            required: true,
                          );

                          if (!result.isValid) return '';

                          if (_phoneDuplicateMessage != null) return '';

                          return null;
                        },
                        onChanged: (_) {
                          if (_phoneDuplicateMessage != null) {
                            _phoneDuplicateMessage = null;
                          }

                          setState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _postalC,
                              decoration: _inputDecoration('우편번호'),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: OutlinedButton(
                              onPressed: _openPostcodeSearch,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 56),
                                side: const BorderSide(color: kPageBorder),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('우편번호 찾기'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addrC,
                        decoration: _inputDecoration('주소'),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _addrDetailC,
                        decoration: _inputDecoration('상세주소'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _buildBasicInfoPageDots(),
        ],
      ),
    );
  }

  Widget _memberSetupSection() {
    return _ExpandableSectionCard(
      icon: Icons.badge_outlined,
      title: '회원 현황',
      subtitle: '회원 현황 등을 체크합니다',
      initiallyExpanded: !_isEditMode,
      child: Column(
        children: [
          _buildMemberSetupPagerHeader(),
          const SizedBox(height: 8),
          SizedBox(
            height: _isCustomLessonTypeSelected || _isLessonTypeLockedByContract
                ? 392
                : 348,
            child: PageView(
              controller: _memberSetupPageController,
              onPageChanged: (index) {
                setState(() {
                  _memberSetupPageIndex = index;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _memberStatus,
                              decoration: _inputDecoration('회원 상태'),
                              items: const [
                                DropdownMenuItem(
                                    value: '활성', child: Text('활성')),
                                DropdownMenuItem(
                                    value: '휴면', child: Text('휴면')),
                                DropdownMenuItem(
                                    value: '만료', child: Text('만료')),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _memberStatus = v ?? '활성';
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _membershipGrade,
                              decoration: _inputDecoration('회원 등급'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'VVIP', child: Text('VVIP')),
                                DropdownMenuItem(
                                    value: 'VIP', child: Text('VIP')),
                                DropdownMenuItem(
                                    value: 'GOLD', child: Text('GOLD')),
                                DropdownMenuItem(
                                    value: 'SILVER', child: Text('SILVER')),
                                DropdownMenuItem(
                                    value: 'BRONZE', child: Text('BRONZE')),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _membershipGrade = v ?? 'GOLD';
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _lessonTypeDropdownValue,
                        decoration: _inputDecoration(
                          _isLessonTypeLockedByContract
                              ? '레슨 형태 · 계약서 기준'
                              : '레슨 형태',
                        ),
                        items: const [
                          DropdownMenuItem(value: '미입력', child: Text('미입력')),
                          DropdownMenuItem(value: 'PT', child: Text('PT')),
                          DropdownMenuItem(value: '필라테스', child: Text('필라테스')),
                          DropdownMenuItem(value: '요가', child: Text('요가')),
                          DropdownMenuItem(value: '그룹', child: Text('그룹')),
                          DropdownMenuItem(value: '줌바', child: Text('줌바')),
                          DropdownMenuItem(value: '재활', child: Text('재활')),
                          DropdownMenuItem(
                            value: _customLessonTypeValue,
                            child: Text('직접입력'),
                          ),
                        ],
                        onChanged: (_lessonsNotRegistered ||
                                _isLessonTypeLockedByContract)
                            ? null
                            : (v) {
                                setState(() {
                                  if (v == _customLessonTypeValue) {
                                    final custom =
                                        _customLessonTypeC.text.trim();
                                    _lessonType = custom.isEmpty ? '' : custom;
                                  } else {
                                    _lessonType = v ?? '미입력';
                                    _customLessonTypeC.clear();
                                  }
                                });
                              },
                      ),
                      if (_isCustomLessonTypeSelected) ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _customLessonTypeC,
                          enabled: !_lessonsNotRegistered &&
                              !_isLessonTypeLockedByContract,
                          decoration: _inputDecoration(
                            _isLessonTypeLockedByContract
                                ? '계약서 레슨 형태'
                                : '레슨 형태 직접입력',
                            hint: '예: 듀엣PT / 산전필라테스 / 체형교정',
                          ),
                          onChanged: (value) {
                            setState(() {
                              _lessonType = value.trim();
                            });
                          },
                        ),
                      ],
                      if (_isLessonTypeLockedByContract) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 14,
                              color: kPageMuted,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                '계약서가 작성된 회원은 계약서의 레슨 형태를 기준으로 고정돼요.',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                  color: kPageMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _trainerC,
                        decoration: _inputDecoration(
                          '담당 강사',
                          hint: '예: 김팀장 / 민수쌤',
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _groupOptions
                                .any((item) => item.id == _selectedGroupId)
                            ? _selectedGroupId
                            : '__ungrouped__',
                        decoration: _inputDecoration('그룹설정'),
                        items: _groupOptions.map((group) {
                          return DropdownMenuItem<String>(
                            value: group.id,
                            child: Text(
                              group.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          final nextId = value ?? '__ungrouped__';
                          final nextLabel = _groupOptions
                              .firstWhere(
                                (item) => item.id == nextId,
                                orElse: () => const _MemberGroupOption(
                                  id: '__ungrouped__',
                                  label: 'MORE THAN GYM',
                                ),
                              )
                              .label;

                          setState(() {
                            _selectedGroupId = nextId;
                            _headerGroupLabel = nextLabel;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _noShowDeductedC,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('노쇼 차감'),
                              onChanged: (v) {
                                setState(() {
                                  _noShowDeductedCount = int.tryParse(v) ?? 0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _noShowUndeductedC,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('노쇼 미차감'),
                              onChanged: (v) {
                                setState(() {
                                  _noShowUndeductedCount = int.tryParse(v) ?? 0;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _serviceSessionC,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('서비스 레슨'),
                              onChanged: (v) {
                                setState(() {
                                  _serviceSessionCount = int.tryParse(v) ?? 0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: _reregisterCountC,
                              keyboardType: TextInputType.number,
                              decoration: _inputDecoration('재등록 횟수'),
                              onChanged: (v) {
                                setState(() {
                                  _reregisterCount = int.tryParse(v) ?? 0;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _tapDateField(
                        label: '최근 재등록일',
                        text: _formatDate(_lastReregisterAt),
                        onTap: () => _pickDate(
                          current: _lastReregisterAt,
                          onPicked: (d) =>
                              setState(() => _lastReregisterAt = d),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _buildMemberSetupPageDots(),
        ],
      ),
    );
  }

  Widget _lessonMembershipSection() {
    final total = int.tryParse(_totalSessionsC.text) ?? 0;
    final remain = int.tryParse(_remainSessionsC.text) ?? 0;
    final done = (total - remain).clamp(0, total);

    return KeyedSubtree(
      key: _lessonMembershipSectionKey,
      child: _ExpandableSectionCard(
        icon: Icons.inventory_2_outlined,
        title: '레슨 / 멤버십',
        subtitle: '레슨 등록 과 멤버십 등록을 체크합니다',
        initiallyExpanded: !_isEditMode,
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: kPageFieldBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPageBorder),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '레슨 등록',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: kPageText,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '회차를 등록해서 레슨 흐름을 관리해요',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: kPageMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: !_lessonsNotRegistered,
                          onChanged: (isRegistered) {
                            setState(() {
                              _lessonsNotRegistered = !isRegistered;

                              if (!isRegistered) {
                                _lessonType = '미입력';
                                _customLessonTypeC.clear();
                                _totalSessionsC.text = '0';
                                _remainSessionsC.text = '0';
                              }
                            });
                          },
                          activeColor: kPagePrimary,
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _totalSessionsC,
                            enabled: !_lessonsNotRegistered,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('총 횟수'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _remainSessionsC,
                            enabled: !_lessonsNotRegistered,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('잔여 횟수'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: Row(
                      children: [
                        _SoftInfoChip(
                          label: _lessonsNotRegistered
                              ? '레슨 미등록'
                              : '레슨 등록 · 완료 $done회',
                        ),
                        const SizedBox(width: 8),
                        _SoftInfoChip(label: '총 $total / 잔여 $remain'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: kPageFieldBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPageBorder),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '멤버십 등록',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: kPageText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _lastRegisteredAt == null
                                    ? '마지막 등록일 없음'
                                    : '마지막 등록일 ${DateFormat('yyyy-MM-dd').format(_lastRegisteredAt!)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: kPageMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: !_membershipNotRegistered,
                          onChanged: (isRegistered) {
                            setState(() {
                              _membershipNotRegistered = !isRegistered;

                              if (!isRegistered) {
                                _termMonths = null;
                                _customDays = null;
                                _passStart = null;
                                _passEnd = null;
                              }
                            });
                          },
                          activeColor: kPagePrimary,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                    child: AbsorbPointer(
                      absorbing: _membershipNotRegistered,
                      child: Opacity(
                        opacity: _membershipNotRegistered ? 0.45 : 1.0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final m in [1, 3, 6, 12])
                                  ChoiceChip(
                                    label: Text('$m개월'),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: const VisualDensity(
                                        horizontal: -2, vertical: -2),
                                    selected:
                                        _termMonths == m && _customDays == null,
                                    onSelected: (sel) {
                                      if (!sel) return;
                                      setState(() {
                                        _termMonths = m;
                                        _customDays = null;
                                        _passStart ??= DateTime.now();
                                        _passEnd = _passStart!.add(
                                          Duration(days: _approxDays(m) - 1),
                                        );
                                      });
                                    },
                                  ),
                                ChoiceChip(
                                  label: Text(
                                    _customDays == null
                                        ? '직접입력(일)'
                                        : '${_customDays}일',
                                  ),
                                  selected: _customDays != null,
                                  onSelected: (sel) async {
                                    if (!sel) return;
                                    final d = await _askDays(context);
                                    if (d == null) return;
                                    setState(() {
                                      _termMonths = null;
                                      _customDays = d;
                                      _passStart ??= DateTime.now();
                                      _passEnd = _passStart!.add(
                                        Duration(days: d - 1),
                                      );
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _tapDateField(
                                    label: '시작일',
                                    text: _formatDate(_passStart),
                                    onTap: () => _pickDate(
                                      current: _passStart,
                                      onPicked: (d) => setState(() {
                                        _passStart = d;
                                        if (_termMonths != null) {
                                          _passEnd = d.add(
                                            Duration(
                                                days:
                                                    _approxDays(_termMonths!) -
                                                        1),
                                          );
                                        } else if (_customDays != null) {
                                          _passEnd = d.add(
                                            Duration(days: _customDays! - 1),
                                          );
                                        }
                                      }),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _tapDateField(
                                    label: '종료일',
                                    text: _formatDate(_passEnd),
                                    onTap: () => _pickDate(
                                      current: _passEnd,
                                      onPicked: (d) => setState(() {
                                        _passEnd = d;
                                        if (_passStart != null) {
                                          final s = DateTime(
                                            _passStart!.year,
                                            _passStart!.month,
                                            _passStart!.day,
                                          );
                                          final e =
                                              DateTime(d.year, d.month, d.day);
                                          final days =
                                              e.difference(s).inDays + 1;
                                          _termMonths = null;
                                          _customDays = days;
                                        }
                                      }),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _SoftInfoChip(
                                  label:
                                      '기간 ${_termMonths != null ? '${_termMonths}개월' : (_customDays != null ? '${_customDays}일' : '-')}',
                                ),
                                _SoftInfoChip(
                                    label: '총 ${_passDays() ?? '-'}일'),
                                _SoftInfoChip(
                                  label:
                                      '남은 ${_daysLeft()?.toString() ?? '-'}일',
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding:
                                  const EdgeInsets.fromLTRB(12, 11, 12, 11),
                              decoration: BoxDecoration(
                                color: _membershipPaused
                                    ? const Color(0xFFFFF1F2)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _membershipPaused
                                      ? const Color(0xFFFCA5A5)
                                      : kPageBorder,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _membershipPaused
                                          ? const Color(0xFFEF4444)
                                          : const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      boxShadow: _membershipPaused
                                          ? [
                                              BoxShadow(
                                                color: const Color(0xFFEF4444)
                                                    .withOpacity(0.45),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ]
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _membershipPaused
                                              ? '회원권 정지중'
                                              : '회원권 진행중',
                                          style: TextStyle(
                                            color: _membershipPaused
                                                ? const Color(0xFFB91C1C)
                                                : kPageText,
                                            fontSize: 12.8,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        if (_membershipPaused) ...[
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              ...<String?>[
                                                membershipPauseElapsedLabel(
                                                  isPaused: _membershipPaused,
                                                  pausedAt: _membershipPausedAt,
                                                ),
                                                membershipResumeDueLabel(
                                                  isPaused: _membershipPaused,
                                                  resumeDueAt:
                                                      _membershipResumeDueAt,
                                                ),
                                              ].whereType<String>().map(
                                                    _buildMembershipPauseStatusChip,
                                                  ),
                                            ],
                                          ),
                                        ] else ...[
                                          const SizedBox(height: 3),
                                          const Text(
                                            '진행중',
                                            style: TextStyle(
                                              color: kPageMuted,
                                              fontSize: 11.2,
                                              height: 1.35,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                        if (_membershipContractPauseLimitText()
                                            .isNotEmpty) ...[
                                          const SizedBox(height: 3),
                                          Text(
                                            _membershipContractPauseLimitText(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: _membershipPaused
                                                  ? const Color(0xFFB91C1C)
                                                      .withOpacity(0.72)
                                                  : kPagePrimary,
                                              fontSize: 10.8,
                                              height: 1.3,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    onPressed: _membershipNotRegistered
                                        ? null
                                        : _toggleMembershipPause,
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: _membershipPaused
                                          ? const Color(0xFFB91C1C)
                                          : kPagePrimary,
                                      side: BorderSide(
                                        color: _membershipPaused
                                            ? const Color(0xFFFCA5A5)
                                            : kPagePrimary.withOpacity(0.24),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 10),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                    ),
                                    child: Text(
                                      _membershipPaused ? '재개' : '정지',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _membershipNotRegistered
                                        ? null
                                        : _openMembershipPauseHistorySheet,
                                    icon: const Icon(Icons.history_rounded,
                                        size: 18),
                                    label: const Text('정지/재개 이력'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: kPageText,
                                      side: const BorderSide(
                                        color: kPageBorder,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 13),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _membershipNotRegistered
                                        ? null
                                        : _openMembershipContractDraft,
                                    icon: const Icon(Icons.assignment_outlined,
                                        size: 18),
                                    label: const Text('회원권계약서'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: kPagePrimary,
                                      side: BorderSide(
                                        color: kPagePrimary.withOpacity(0.24),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 13),
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

  Future<void> _showClientCardInbodyScanOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('카메라로 인바디 읽기'),
                  subtitle: const Text('사진을 촬영해서 수치를 자동 입력해요'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    if (!await prepareInbodyCameraUse(context)) return;
                    if (!mounted) return;
                    await _pickAndScanInbodyForClientCard(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('갤러리에서 인바디 읽기'),
                  subtitle: const Text('저장된 인바디 사진을 불러와요'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _pickAndScanInbodyForClientCard(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndScanInbodyForClientCard(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1600,
      );

      if (picked == null) return;

      final recognizer = TextRecognizer(
        script: TextRecognitionScript.korean,
      );

      try {
        final inputImage = InputImage.fromFilePath(picked.path);
        final recognizedText = await recognizer.processImage(inputImage);
        final extracted = _extractClientCardInbodyData(recognizedText.text);

        if (!mounted) return;

        await _openClientCardInbodyReviewSheet(
          imageFile: File(picked.path),
          data: extracted,
        );
      } finally {
        await recognizer.close();
      }
    } catch (e) {
      if (!mounted) return;
      _showAifcToast('인바디 용지 인식 중 오류가 발생했어요.');
    }
  }

  _ClientCardInbodyOcrData _extractClientCardInbodyData(String raw) {
    final lines = raw
        .split(RegExp(r'[\r\n]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    String findValue(List<String> keywords) {
      for (int i = 0; i < lines.length; i++) {
        final compact = lines[i].replaceAll(' ', '').toLowerCase();

        final hasKeyword = keywords.any((keyword) {
          return compact.contains(
            keyword.replaceAll(' ', '').toLowerCase(),
          );
        });

        if (!hasKeyword) continue;

        final currentMatch =
            RegExp(r'(\d{1,3}(?:[.,]\d{1,2})?)').firstMatch(lines[i]);

        if (currentMatch != null) {
          return currentMatch.group(1)!.replaceAll(',', '.');
        }

        if (i + 1 < lines.length) {
          final nextMatch =
              RegExp(r'(\d{1,3}(?:[.,]\d{1,2})?)').firstMatch(lines[i + 1]);

          if (nextMatch != null) {
            return nextMatch.group(1)!.replaceAll(',', '.');
          }
        }
      }

      return '';
    }

    final dateMatch =
        RegExp(r'(20\d{2}[.\-/]\d{1,2}[.\-/]\d{1,2})').firstMatch(raw);

    return _ClientCardInbodyOcrData(
      date: dateMatch?.group(1)?.replaceAll('/', '.') ?? '',
      weight: findValue(['체중', 'weight']),
      skeletalMuscle: findValue(['골격근량', 'smm', 'skeletal']),
      bodyFatPercent: findValue(['체지방률', 'pbf', '%체지방']),
      bodyFatKg: findValue(['체지방량', 'fatmass', 'bodyfatmass']),
    );
  }

  DateTime? _parseInbodyMeasuredDate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final normalized = value
        .replaceAll('.', '-')
        .replaceAll('/', '-')
        .replaceAll(RegExp(r'\s+'), '');

    final match =
        RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$').firstMatch(normalized);
    if (match == null) return null;

    final y = int.tryParse(match.group(1)!);
    final m = int.tryParse(match.group(2)!);
    final d = int.tryParse(match.group(3)!);

    if (y == null || m == null || d == null) return null;

    try {
      final parsed = DateTime(y, m, d);
      if (parsed.year != y || parsed.month != m || parsed.day != d) {
        return null;
      }
      return parsed;
    } catch (_) {
      return null;
    }
  }

  String _formatInbodyMeasuredDate(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  double? _parseInbodyNumber(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  Future<String?> _uploadClientCardInbodyImage(File imageFile) async {
    try {
      final path =
          'member_inbody/${widget.memberId}/inbody_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final ref = FirebaseStorage.instance.ref(path);

      await ref.putFile(
        imageFile,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=3600',
        ),
      );

      return ref.getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveClientCardInbodyRecord({
    required DateTime measuredAt,
    required String? imageUrl,
    required double? weightKg,
    required double? skeletalMuscleKg,
    required double? bodyFatPct,
    required double? bodyFatKg,
  }) async {
    final memberRef =
        FirebaseFirestore.instance.collection('members').doc(widget.memberId);

    final recordRef = memberRef.collection('inbody_records').doc();

    final recordPayload = {
      'memberId': widget.memberId,
      'measuredAt': Timestamp.fromDate(measuredAt),
      'weightKg': weightKg,
      'skeletalMuscleKg': skeletalMuscleKg,
      'bodyFatPct': bodyFatPct,
      'bodyFatKg': bodyFatKg,
      'imageUrl': imageUrl,
      'source': 'client_card_ocr',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await recordRef.set(recordPayload);

    await memberRef.set({
      'health': {
        'inbodyNotProvided': false,
        'inbodyMeasuredAt': Timestamp.fromDate(measuredAt),
        if (imageUrl != null && imageUrl.trim().isNotEmpty)
          'inbodyImageUrl': imageUrl,
        'latestInbodyRecordId': recordRef.id,
        'inbody': {
          'heightCm': _parseInbodyNumber(_heightC.text),
          'weightKg': weightKg,
          'skeletalMuscleKg': skeletalMuscleKg,
          'bodyFatPct': bodyFatPct,
          'bodyFatKg': bodyFatKg,
          'bmi': _safeBmi(
            double.tryParse(_heightC.text) ?? 0,
            weightKg ?? 0,
          ),
        },
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _openClientCardInbodyReviewSheet({
    required File imageFile,
    required _ClientCardInbodyOcrData data,
  }) async {
    final dateController = TextEditingController(
      text: data.date.trim().isEmpty
          ? _formatInbodyMeasuredDate(DateTime.now())
          : data.date.replaceAll('.', '-').replaceAll('/', '-'),
    );

    final weightController = TextEditingController(text: data.weight);
    final skeletalController = TextEditingController(text: data.skeletalMuscle);
    final bodyFatPctController =
        TextEditingController(text: data.bodyFatPercent);
    final bodyFatKgController = TextEditingController(text: data.bodyFatKg);

    bool saveImage = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                top: false,
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '인바디 인식 결과 확인',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: kPageText,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '인식된 수치를 확인하고 회원카드에 반영해요.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: kPageMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          imageFile,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        value: saveImage,
                        activeColor: kPagePrimary,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          '인바디 이미지도 저장',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: kPageText,
                          ),
                        ),
                        subtitle: const Text(
                          '이미지를 저장하면 나중에 원본 용지도 다시 확인할 수 있어요.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: kPageMuted,
                          ),
                        ),
                        onChanged: (value) {
                          setSheetState(() {
                            saveImage = value;
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: dateController,
                        keyboardType: TextInputType.datetime,
                        decoration: const InputDecoration(
                          labelText: '측정일',
                          hintText: '예: 2026-06-01',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: weightController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '체중',
                          suffixText: 'kg',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: skeletalController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '골격근량',
                          suffixText: 'kg',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: bodyFatPctController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '체지방률',
                          suffixText: '%',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: bodyFatKgController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '체지방량',
                          suffixText: 'kg',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('회원카드에 반영'),
                          onPressed: () async {
                            final measuredAt =
                                _parseInbodyMeasuredDate(dateController.text) ??
                                    DateTime.now();

                            final weightKg =
                                _parseInbodyNumber(weightController.text);
                            final skeletalMuscleKg =
                                _parseInbodyNumber(skeletalController.text);
                            final bodyFatPct =
                                _parseInbodyNumber(bodyFatPctController.text);
                            final bodyFatKg =
                                _parseInbodyNumber(bodyFatKgController.text);

                            String? imageUrl;
                            if (saveImage) {
                              imageUrl =
                                  await _uploadClientCardInbodyImage(imageFile);
                            }

                            if (!mounted) return;

                            setState(() {
                              _inbodyNotProvided = false;
                              _latestInbodyMeasuredAt = measuredAt;
                              _latestInbodyImageUrl =
                                  imageUrl ?? _latestInbodyImageUrl;

                              if (weightKg != null) {
                                _weightC.text = weightKg.toString();
                              }
                              if (skeletalMuscleKg != null) {
                                _smmC.text = skeletalMuscleKg.toString();
                              }
                              if (bodyFatPct != null) {
                                _bfPctC.text = bodyFatPct.toString();
                              }
                              if (bodyFatKg != null) {
                                _bfKgC.text = bodyFatKg.toString();
                              }
                            });

                            await _saveClientCardInbodyRecord(
                              measuredAt: measuredAt,
                              imageUrl: imageUrl,
                              weightKg: weightKg,
                              skeletalMuscleKg: skeletalMuscleKg,
                              bodyFatPct: bodyFatPct,
                              bodyFatKg: bodyFatKg,
                            );

                            if (!mounted) return;

                            Navigator.pop(sheetContext);
                            _showAifcToast('인바디 기록을 회원카드에 반영했어요.');
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
      },
    );

    dateController.dispose();
    weightController.dispose();
    skeletalController.dispose();
    bodyFatPctController.dispose();
    bodyFatKgController.dispose();
  }

  Widget _femaleConditionSection() {
    if (_gender != '여') {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kPageBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile.adaptive(
            value: _femaleConditionEnabled,
            activeColor: kPagePrimary,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              '컨디션주기 체크',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: kPageText,
              ),
            ),
            subtitle: const Text(
              '회원 동의 후 필요한 경우에만 기록해 주세요. 레슨 강도와 컨디션 체크 용도로만 사용됩니다.',
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: kPageMuted,
              ),
            ),
            onChanged: (value) {
              setState(() {
                _femaleConditionEnabled = value;
              });
            },
          ),
          if (_femaleConditionEnabled) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _femaleConditionLastStartC,
              keyboardType: TextInputType.datetime,
              decoration: InputDecoration(
                labelText: '최근 컨디션 시작일',
                hintText: '예: 2026-06-01',
                filled: true,
                fillColor: Colors.white,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.date_range_rounded),
                  onPressed: () async {
                    final initial =
                        _parseSoftDate(_femaleConditionLastStartC.text) ??
                            DateTime.now();

                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(
                        const Duration(days: 365),
                      ),
                    );

                    if (picked == null) return;

                    setState(() {
                      _femaleConditionLastStartC.text = _fmtSoftDate(picked);
                    });
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _femaleConditionCycleC,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '평균 주기',
                hintText: '예: 28',
                suffixText: '일',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _femaleConditionMemoC,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: '강도 조절 메모',
                hintText: '예: 해당 주간은 복부 압박/고강도 하체운동 확인',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double _bodyHealthPageHeight() {
    if (_bodyHealthPageIndex == 0) {
      return 360;
    }

    if (_gender == '여' && _femaleConditionEnabled) {
      return 540;
    }

    if (_gender == '여') {
      return 430;
    }

    return 390;
  }

  Widget _healthSection() {
    final bmi = _calcBmi();

    return _ExpandableSectionCard(
      icon: Icons.monitor_heart_outlined,
      title: '인바디 / 건강정보',
      subtitle: '인바디 결과와 신체의 건강 입력을 입력합니다',
      initiallyExpanded: !_isEditMode,
      child: Column(
        children: [
          _buildBodyHealthPagerHeader(),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showClientCardInbodyScanOptions,
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('인바디 사진 읽기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPagePrimary,
                side: BorderSide(
                  color: kPagePrimary.withOpacity(0.22),
                ),
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          if (_latestInbodyMeasuredAt != null ||
              _latestInbodyImageUrl != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                [
                  if (_latestInbodyMeasuredAt != null)
                    '최근 인바디 ${DateFormat('yyyy-MM-dd').format(_latestInbodyMeasuredAt!)}',
                  if (_latestInbodyImageUrl != null) '이미지 저장됨',
                ].join(' · '),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kPageMuted,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: _bodyHealthPageHeight(),
            child: PageView(
              controller: _bodyHealthPageController,
              onPageChanged: (index) {
                setState(() {
                  _bodyHealthPageIndex = index;
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _numField(_heightC, '키', 'cm')),
                          const SizedBox(width: 10),
                          Expanded(child: _numField(_weightC, '체중', 'kg')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _numField(_bfPctC, '체지방률', '%')),
                          const SizedBox(width: 10),
                          Expanded(child: _numField(_smmC, '골격근량', 'kg')),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _numField(_bfKgC, '체지방량', 'kg')),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              height: 60,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: kPageFieldBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: kPageBorder),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'BMI',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: kPageText,
                                    ),
                                  ),
                                  Text(
                                    (_inbodyNotProvided || bmi <= 0)
                                        ? '-'
                                        : bmi.toStringAsFixed(2),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: kPagePrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        value: _inbodyNotProvided,
                        onChanged: (v) =>
                            setState(() => _inbodyNotProvided = v),
                        activeColor: kPagePrimary,
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          '인바디 미기입',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: const Text(
                          '측정값이 없으면 활성화하세요',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 8, bottom: 10),
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _diseaseC,
                        maxLines: 2,
                        decoration: _inputDecoration(
                          '건강정보 간단요약',
                          hint: '예: 허리 통증, 무릎 이슈, 어깨 불편감',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        maxLines: 2,
                        decoration: _inputDecoration(
                          '질병 / 수술 이력',
                          hint: '예: 디스크, 어깨 수술, 무릎 수술',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _medicineC,
                        maxLines: 2,
                        decoration: _inputDecoration(
                          '복약 이력',
                          hint: '복용 약물 기록',
                        ),
                      ),
                      _femaleConditionSection(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _buildBodyHealthPageDots(),
        ],
      ),
    );
  }

  Widget _inbodySection() {
    final bmi = _calcBmi();

    return _ExpandableSectionCard(
      icon: Icons.monitor_weight_outlined,
      title: '인바디',
      subtitle: _inbodyNotProvided ? '미기입 상태' : '선택 입력',
      initiallyExpanded: !_isEditMode,
      trailing: Switch.adaptive(
        value: _inbodyNotProvided,
        onChanged: (v) => setState(() => _inbodyNotProvided = v),
        activeColor: kPagePrimary,
      ),
      child: AbsorbPointer(
        absorbing: _inbodyNotProvided,
        child: Opacity(
          opacity: _inbodyNotProvided ? 0.45 : 1.0,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _numField(_heightC, '키', 'cm')),
                  const SizedBox(width: 10),
                  Expanded(child: _numField(_weightC, '체중', 'kg')),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _numField(_bfPctC, '체지방률', '%')),
                  const SizedBox(width: 10),
                  Expanded(child: _numField(_smmC, '골격근량', 'kg')),
                  const SizedBox(width: 10),
                  Expanded(child: _numField(_bfKgC, '체지방량', 'kg')),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: kPageFieldBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kPageBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'BMI (자동 계산)',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: kPageText,
                      ),
                    ),
                    Text(
                      (_inbodyNotProvided || bmi <= 0)
                          ? '-'
                          : bmi.toStringAsFixed(2),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: kPagePrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _computedAutoMilestoneTexts() {
    if (!_autoMilestoneEnabled) return [];

    final items = <String>[];

    if (_anniversaryDate != null) {
      final label = _anniversaryLabelText();
      items.add(
          'MORE 데이 $label ${DateFormat('MM.dd').format(_anniversaryDate!)}');
    } else if (_birthDate != null) {
      items.add('MORE 데이 생일 ${DateFormat('MM.dd').format(_birthDate!)}');
    }

    final rawTotal = int.tryParse(_totalSessionsC.text) ?? 0;
    final rawRemain = int.tryParse(_remainSessionsC.text) ?? 0;

    final total = _lessonsNotRegistered ? 0 : rawTotal;
    final remain = _lessonsNotRegistered ? 0 : rawRemain;
    final lessonType = _lessonsNotRegistered ? '미입력' : _lessonType;

    if (total >= 100) {
      items.add('100번째 레슨');
    }

    if (_reregisterCount >= 10) {
      items.add('재등록 10회');
    }

    if (remain > 0 && remain <= 5) {
      items.add('잔여 ${remain}회');
    }

    if (_lastRegisteredAt != null) {
      final days = DateTime.now()
          .difference(DateTime(
            _lastRegisteredAt!.year,
            _lastRegisteredAt!.month,
            _lastRegisteredAt!.day,
          ))
          .inDays;

      if (days >= 100) {
        items.add('레슨 시작 100일');
      }
    }

    return items;
  }

  Widget _buildCareMilestoneChips() {
    final firestoreItems = _careMilestones
        .where((item) {
          if (!item.isActive) return false;

          if (!_autoMilestoneEnabled && item.isAuto) {
            return false;
          }

          return true;
        })
        .take(8)
        .toList();

    final autoItems = _computedAutoMilestoneTexts();

    final hasAny = autoItems.isNotEmpty || firestoreItems.isNotEmpty;

    if (!hasAny) {
      return const Text(
        '표시할 MORE 포커스 없음',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: kPageMuted,
          height: 1.4,
        ),
      );
    }

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        ...autoItems.map((text) {
          return _MilestoneChip(
            label: text,
            isAuto: true,
          );
        }),
        ...firestoreItems.map((item) {
          return _MilestoneChip(
            label: _careMilestoneDisplayText(item),
            isAuto: item.isAuto,
            onDone: () => _completeCareMilestone(item),
            onDelete: item.isManual ? () => _deleteCareMilestone(item) : null,
          );
        }),
      ],
    );
  }

  Future<void> _openCareMilestoneSheet() async {
    if (!await _guardTierFeature(AppTierFeatureKey.moreFocus)) return;

    await _loadCareMilestonesFromFirestore();

    if (!mounted) return;

    final autoItems = _computedAutoMilestoneTexts();

    final activeItems = _careMilestones.where((item) {
      if (!item.isActive) return false;
      if (!_autoMilestoneEnabled && item.isAuto) return false;
      return true;
    }).toList();

    final doneItems = _careMilestones.where((item) => item.isDone).toList();

    final itemById = <String, _CareMilestoneItem>{
      for (final item in [...activeItems, ...doneItems]) item.id: item,
    };

    String badgeForActiveItem(_CareMilestoneItem item) {
      if (item.isManual) return '직접 추가';
      return 'D-DAY 후속 관리';
    }

    String badgeForDoneItem(_CareMilestoneItem item) {
      if (item.isManual) return '완료 · 직접 추가';
      return '완료 · 자동';
    }

    await AifcCareMilestoneChatSheet.show(
      context: context,
      memberName: _nameC.text.trim().isEmpty ? '회원' : _nameC.text.trim(),
      nickname: _trainerC.text.trim(),
      autoItems: autoItems,
      activeItems: activeItems.map((item) {
        return AifcCareMilestoneSheetItem(
          id: item.id,
          title: _careMilestoneDisplayText(item),
          badge: badgeForActiveItem(item),
          isAuto: item.isAuto,
          isManual: item.isManual,
          isDone: item.isDone,
          canComplete: true,
          canDelete: item.isManual,
        );
      }).toList(),
      doneItems: doneItems.map((item) {
        return AifcCareMilestoneSheetItem(
          id: item.id,
          title: _careMilestoneDisplayText(item),
          badge: badgeForDoneItem(item),
          isAuto: item.isAuto,
          isManual: item.isManual,
          isDone: item.isDone,
        );
      }).toList(),
      onComplete: (id) async {
        final item = itemById[id];
        if (item == null) return;
        await _completeCareMilestone(item);
      },
      onDelete: (id) async {
        final item = itemById[id];
        if (item == null) return;
        await _deleteCareMilestone(item);
      },
    );
  }

  Widget _etcSection() {
    return _ExpandableSectionCard(
      icon: Icons.event_note_outlined,
      title: '메모 / MORE 포커스',
      subtitle: '좌우로 넘기며 메모와 중요한 일정들을 관리합니다',
      initiallyExpanded: true,
      child: Column(
        children: [
          _buildMemoPagerHeader(),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            height: _memoPagerHeight(),
            child: PageView(
              controller: _memoPageController,
              onPageChanged: (index) {
                setState(() {
                  _memoPageIndex = index;
                  _memoPageValue = index.toDouble();
                });
              },
              children: [
                SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Column(
                    children: [
                      _buildAutoNextReservationCard(),
                      const SizedBox(height: 12),
                      TextFormField(
                        key: _noteFieldKey,
                        focusNode: _noteFocusNode,
                        controller: _noteC,
                        maxLines: 4,
                        decoration: _inputDecoration(
                          'SPECIAL NOTE',
                          hint: '선호 스포츠, 특이사항, 상담 내용 등',
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ],
                  ),
                ),
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 8, bottom: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _anniversaryLabelC,
                              readOnly: !(_tierAccess?.canUseMoreDay ?? false),
                              onTap: () async {
                                if (!(_tierAccess?.canUseMoreDay ?? false)) {
                                  await _guardTierFeature(
                                      AppTierFeatureKey.moreDay);
                                }
                              },
                              decoration: _inputDecoration(
                                'MORE 데이 제목 설정',
                                hint: '예: 결혼기념일 / 경조사',
                              ),
                              onChanged: (_tierAccess?.canUseMoreDay ?? false)
                                  ? (_) => setState(() {})
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _tapDateField(
                              label: 'MORE 데이 날짜',
                              text: _formatDate(_anniversaryDate),
                              onTap: () async {
                                if (!await _guardTierFeature(
                                    AppTierFeatureKey.moreDay)) return;

                                await _pickDate(
                                  current: _anniversaryDate,
                                  onPicked: (d) =>
                                      setState(() => _anniversaryDate = d),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                        decoration: BoxDecoration(
                          color: kPageFieldBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kPageBorder),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile.adaptive(
                              value: _autoMilestoneEnabled,
                              onChanged: (value) async {
                                setState(() {
                                  _autoMilestoneEnabled = value;
                                });
                                await _saveMilestoneSettings();
                              },
                              activeColor: kPagePrimary,
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                '자동 MORE 포커스',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: kPageText,
                                ),
                              ),
                              subtitle: const Text(
                                '100번째 레슨, 재등록 10회, 잔여 5회 이하 등을 자동 표시',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: kPageMuted,
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            SwitchListTile.adaptive(
                              value: _ddayFollowUpEnabled,
                              onChanged: (value) async {
                                setState(() {
                                  _ddayFollowUpEnabled = value;
                                });
                                await _saveMilestoneSettings();
                              },
                              activeColor: kPagePrimary,
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                'D-DAY 후속 케어',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: kPageText,
                                ),
                              ),
                              subtitle: const Text(
                                '목표형 D-DAY 완료 후 필요한 MORE 포커스를 자동으로 만들어요',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: kPageMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _specialEventC,
                              maxLines: 1,
                              decoration: _inputDecoration(
                                'MORE 포커스 추가',
                                hint: '예: 무릎 이슈 주의',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 58,
                            child: FilledButton(
                              onPressed: _specialEventC.text.trim().isEmpty
                                  ? null
                                  : _addManualCareMilestone,
                              style: FilledButton.styleFrom(
                                backgroundColor: kPagePrimary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    const Color(0xFFE5E7EB),
                                disabledForegroundColor:
                                    const Color(0xFF9CA3AF),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                '추가',
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kPageFieldBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kPageBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 15,
                                  color: kPagePrimary,
                                ),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text(
                                    'MORE 포커스',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                      color: kPageText,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _openCareMilestoneSheet,
                                  style: TextButton.styleFrom(
                                    visualDensity: const VisualDensity(
                                        horizontal: -3, vertical: -3),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8),
                                    minimumSize: const Size(0, 30),
                                  ),
                                  child: const Text(
                                    '더보기',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildCareMilestoneChips(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _buildMemoPageDots(),
        ],
      ),
    );
  }

  ImageProvider<Object>? _avatarImage() {
    if (_profileBytes != null) return MemoryImage(_profileBytes!);
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      return NetworkImage(_photoUrl!);
    }
    return null;
  }

  String _prettyPhone(String v) {
    final d = v.replaceAll(RegExp(r'\D'), '');
    if (d.isEmpty) return '-';

    if (d.startsWith('02')) {
      if (d.length <= 2) return d;
      if (d.length <= 5) return '${d.substring(0, 2)}-${d.substring(2)}';
      if (d.length <= 9) {
        return '${d.substring(0, 2)}-${d.substring(2, d.length - 4)}-${d.substring(d.length - 4)}';
      }
      return '${d.substring(0, 2)}-${d.substring(2, 6)}-${d.substring(6, 10)}';
    }

    if (d.length <= 3) return d;
    if (d.length <= 7) return '${d.substring(0, 3)}-${d.substring(3)}';
    return '${d.substring(0, 3)}-${d.substring(3, d.length - 4)}-${d.substring(d.length - 4)}';
  }

  String _nextReservationAutoText() {
    final next = _nextReservation;

    if (next == null) {
      return '등록된 다음 일정 없음';
    }

    return DateFormat('MM.dd E HH:mm', 'ko_KR').format(next);
  }

  Widget _buildAutoNextReservationCard() {
    final hasNext = _nextReservation != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: kPageFieldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPageBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kPagePrimary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasNext
                  ? Icons.event_available_rounded
                  : Icons.event_note_rounded,
              size: 19,
              color: kPagePrimary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '다음 예약일 · 자동',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: kPageText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _nextReservationAutoText(),
                  style: TextStyle(
                    fontSize: hasNext ? 14 : 12.5,
                    fontWeight: hasNext ? FontWeight.w900 : FontWeight.w700,
                    color: hasNext ? kPageText : kPageMuted,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  '홈 스케줄러에 이 회원이 연결된 일정 기준으로 자동 갱신돼요.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kPageMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tapDateField({
    required String label,
    required String text,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: _inputDecoration(
          label,
          suffixIcon: const Icon(Icons.date_range),
        ),
        child: Text(
          text.isEmpty ? '선택하세요' : text,
          style: TextStyle(
            color: text.isEmpty ? kPageMuted : kPageText,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _numField(TextEditingController ctrl, String label, String suffix) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(
        signed: false,
        decimal: true,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*\.?[0-9]*$')),
      ],
      decoration: _inputDecoration(label, suffixText: suffix),
      validator: (v) {
        if (_inbodyNotProvided) return null;
        if (v == null || v.trim().isEmpty) return '값 입력';
        final parsed = double.tryParse(v);
        if (parsed == null) return '숫자만 입력';
        if (parsed < 0) return '0 이상';
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }

  Future<void> _openPostcodeSearch() async {
    final result = await Navigator.of(context).push<_PostcodeSearchResult>(
      MaterialPageRoute(
        builder: (_) => const _DaumPostcodeSearchPage(),
        fullscreenDialog: true,
      ),
    );

    if (result == null || !mounted) return;

    setState(() {
      _postalC.text = result.zonecode;
      _addrC.text = result.address;
      _addrDetailC.clear();
    });

    _debouncedSave();
  }

  Future<int?> _askDays(BuildContext context) async {
    int? selectedDays;

    final result = await AifcInteraction.ask(
      context: context,
      question: '회원권 기간을 며칠로 잡아둘까요?\n'
          '예를 들어 45일, 100일처럼 숫자로 알려주세요.',
      inputLabel: '예: 45',
      skipLabel: '나중에',
      onSkip: () {},
      onSave: (value) async {
        final raw = value.trim();
        final days = int.tryParse(raw);

        if (days == null || days <= 0) {
          throw Exception('invalid_days');
        }

        selectedDays = days;

        return '$days일 회원권으로 잡아둘게요.';
      },
    );

    if (result == null) return null;

    return selectedDays ?? int.tryParse(result.trim());
  }

  double _calcBmi() {
    if (_inbodyNotProvided) return 0;
    final h = double.tryParse(_heightC.text) ?? 0;
    final w = double.tryParse(_weightC.text) ?? 0;
    if (h <= 0) return 0;
    final hm = h / 100.0;
    return double.parse((w / (hm * hm)).toStringAsFixed(2));
  }

  int get _totalSessionValue {
    return int.tryParse(_totalSessionsC.text.trim()) ?? 0;
  }

  int get _remainSessionValue {
    return int.tryParse(_remainSessionsC.text.trim()) ?? 0;
  }

  String _headerLessonTypeText() {
    final value = _lessonType.trim();
    return value.isEmpty ? '레슨' : value;
  }

  String _headerMembershipLabelText() {
    final grade = _membershipGrade.trim();
    return grade.isEmpty ? 'BRONZE' : grade.toUpperCase();
  }

  String _headerMembershipPeriodText() {
    final start = _passStart;
    final end = _passEnd;

    if (start == null && end == null) {
      return '기간 미등록';
    }

    String format(DateTime value) {
      return DateFormat('yy.MM.dd').format(value);
    }

    if (start != null && end != null) {
      return '${format(start)} - ${format(end)}';
    }

    if (start != null) {
      return '${format(start)} - 종료일 미등록';
    }

    return '시작일 미등록 - ${format(end!)}';
  }

  String? _ageBadgeText() {
    return memberAgeLabelFromBirthText(_birthTextC.text);
  }

  Widget? _buildAgeSuffix() {
    final label = _ageBadgeText();
    if (label == null) return null;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Center(
        widthFactor: 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
            ),
          ),
        ),
      ),
    );
  }

  String _anniversaryLabelText() {
    final label = _anniversaryLabelC.text.trim();
    return label.isEmpty ? '기념일' : label;
  }

  int? _headerDaysLeft() {
    final end = _passEnd;
    if (end == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final endDate = DateTime(end.year, end.month, end.day);

    return endDate.difference(today).inDays;
  }

  ImageProvider<Object>? _headerAvatarImage() {
    return _avatarImage();
  }

  void _handleMembershipCardMoreSelected(String value) {
    _handleMembershipCardMoreSelectedAsync(value);
  }

  void _showAifcToast(
    String message, {
    double bottomOffset = 110,
    Duration duration = const Duration(milliseconds: 1400),
  }) {
    if (!mounted) return;

    AifcInteraction.toast(
      context: context,
      message: message,
      bottomOffset: bottomOffset,
      duration: duration,
    );
  }

  Future<void> _handleMembershipCardMoreSelectedAsync(String value) async {
    switch (value) {
      case 'history':
        await _openContractHistorySheet();
        break;

      case 'membership_manage':
        await _openMembershipManageSheet();
        break;

      case 'badges':
        await _openAchievementBadgeSheet();
        break;

      case 'inbody_scan':
        await _showClientCardInbodyScanOptions();
        break;

      case 'reset':
        await _resetForm();
        break;

      case 'delete':
        await _confirmDeleteMember();
        break;
    }
  }

  void _showComingSoonSnack(String label) {
    if (!mounted) return;

    _showAifcToast('$label 기능은 준비 중이에요.');
  }

  Widget _buildClientCardLoadingHeader() {
    return Container(
      height: 280,
      decoration: const BoxDecoration(
        color: kPageBg,
      ),
      child: const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_newCardAccessResolved) {
      return const Scaffold(
        backgroundColor: kPageBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!_newCardAccessAllowed) {
      return Scaffold(
        backgroundColor: kPageBg,
        appBar: AppBar(
          backgroundColor: kPageBg,
          leading:
              BackButton(onPressed: () => Navigator.of(context).maybePop()),
          title: const Text('고객카드 등록'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '고객카드 등록은 Amateur부터 사용할 수 있어요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      );
    }
    final gradeTheme = _gradeTheme();
    return Scaffold(
      backgroundColor: kPageBg,
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kPageBorder)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: _ClientCardBottomActionButton(
                  icon: Icons.edit_note_rounded,
                  label: '레슨일지',
                  onTap: _openTrainingLogWithConsent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ClientCardBottomActionButton(
                  icon: Icons.description_outlined,
                  label: '레슨계약서',
                  onTap: _openContract,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ClientCardBottomActionButton(
                  icon: Icons.save_outlined,
                  label: '회원저장',
                  filled: true,
                  onTap: _submitAndStay,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: !_isClientCardLoaded
                ? _buildClientCardLoadingHeader()
                : MembershipCardFlip(
                    key: ValueKey('membership_card_${widget.memberId}'),
                    onBackTap: () => Navigator.of(context).maybePop(),
                    onMoreSelected: _handleMembershipCardMoreSelected,
                    gradientColors: _resolveCardGradient(
                      _membershipGrade,
                      _memberStatus,
                    ),
                    icChipColors: _resolveIcChipColors(_membershipGrade),
                    representativeBadge: _representativeBadge,
                    badges: _achievementBadges,
                    onBadgeTap: _showBadgeBubble,
                    avatarImage: _headerAvatarImage(),
                    name: _nameC.text.trim().isEmpty
                        ? '이름 미입력'
                        : _nameC.text.trim(),
                    phone: _prettyPhone(_phoneC.text),
                    lessonType: _headerLessonTypeText(),
                    totalSessions: _totalSessionValue,
                    remainSessions: _remainSessionValue,
                    membershipLabel: _headerMembershipLabelText(),
                    membershipPeriod: _headerMembershipPeriodText(),
                    daysLeft: _headerDaysLeft(),
                    groupLabel: _membershipCardGroupLabelText(),
                    memoText: _noteC.text.trim(),
                    reregisterCount: _reregisterCount,
                    noShowDeductedCount: _noShowDeductedCount,
                    noShowUndeductedCount: _noShowUndeductedCount,
                    serviceCount: _serviceSessionCount,
                    firstRegisteredAt: _passStart,
                    anniversaryLabel: _anniversaryLabelText(),
                    anniversaryDate: _anniversaryDate,
                    birthdayDate: _birthDate,
                    contractSigned: _contractSigned,
                    contractSignedAt: _contractSignedAt,
                    consentAgreed: _trainingLogConsentAgreed,
                    confirmTalkEnabled: _confirmTalkEnabled,
                    onAvatarTap: _pickProfileImage,
                    onAvatarLongPress: _clearProfileImage,
                    onMemoTap: _jumpToNoteEditor,
                    onContractTap: _openContract,
                    onConsentTap: _handleConsentTapFromCard,
                    onConfirmTalkToggle: _setConfirmTalkEnabledFromCard,
                  ),
          ),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                children: [
                  if (!_hideTopActionCards) ...[
                    _trainingLogConsentCard(),
                    const SizedBox(height: 8),
                  ],
                  _buildRequiredFieldsNoticeCard(),
                  if (_missingRequiredFields().isNotEmpty)
                    const SizedBox(height: 8),
                  _basicInfoSection(),
                  const SizedBox(height: 8),
                  _memberSetupSection(),
                  const SizedBox(height: 8),
                  _lessonMembershipSection(),
                  const SizedBox(height: 8),
                  _healthSection(),
                  const SizedBox(height: 8),
                  _etcSection(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ------------------------- widgets ------------------------- */

class _DaumPostcodeSearchPage extends StatefulWidget {
  const _DaumPostcodeSearchPage();

  @override
  State<_DaumPostcodeSearchPage> createState() =>
      _DaumPostcodeSearchPageState();
}

class _DaumPostcodeSearchPageState extends State<_DaumPostcodeSearchPage> {
  late final WebViewController _controller;

  String _postcodeHtml() {
    return '''
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta
    name="viewport"
    content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no"
  />
  <script src="https://t1.daumcdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js"></script>
  <style>
    html, body {
      width: 100%;
      height: 100%;
      margin: 0;
      padding: 0;
      overflow: hidden;
      background: #ffffff;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }
    #postcode {
      width: 100%;
      height: 100%;
    }
  </style>
</head>
<body>
  <div id="postcode"></div>

  <script>
    function openPostcode() {
      new daum.Postcode({
        width: '100%',
        height: '100%',
        oncomplete: function(data) {
          var roadAddress = data.roadAddress || '';
          var jibunAddress = data.jibunAddress || '';
          var address = roadAddress.length > 0 ? roadAddress : jibunAddress;

          var extra = '';

          if (data.bname && /[동|로|가]\$/g.test(data.bname)) {
            extra += data.bname;
          }

          if (data.buildingName && data.apartment === 'Y') {
            extra += extra.length > 0
              ? ', ' + data.buildingName
              : data.buildingName;
          }

          if (extra.length > 0 && roadAddress.length > 0) {
            address += ' (' + extra + ')';
          }

          DaumPostcodeChannel.postMessage(JSON.stringify({
            zonecode: data.zonecode || '',
            address: address || ''
          }));
        }
      }).embed(document.getElementById('postcode'));
    }

    window.onload = openPostcode;
  </script>
</body>
</html>
''';
  }

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'DaumPostcodeChannel',
        onMessageReceived: (message) {
          try {
            final decoded = jsonDecode(message.message);

            if (decoded is! Map) return;

            final zonecode = (decoded['zonecode'] ?? '').toString().trim();
            final address = (decoded['address'] ?? '').toString().trim();

            if (zonecode.isEmpty && address.isEmpty) return;

            Navigator.of(context).pop(
              _PostcodeSearchResult(
                zonecode: zonecode,
                address: address,
              ),
            );
          } catch (_) {}
        },
      )
      ..loadHtmlString(_postcodeHtml());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '우편번호 찾기',
          style: TextStyle(
            fontWeight: FontWeight.w900,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: kPageText,
        elevation: 0,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}

class AchievementIcChip extends StatelessWidget {
  const AchievementIcChip({
    super.key,
    required this.code,
    this.width = 52,
    this.height = 40,
  });

  final AchievementBadgeCode code;
  final double width;
  final double height;

  List<Color> get _colors {
    switch (code) {
      case AchievementBadgeCode.lesson100:
        return const [
          Color(0xFF78350F),
          Color(0xFFB45309),
          Color(0xFFFCD34D),
        ];
      case AchievementBadgeCode.bodyProfileDone:
        return const [
          Color(0xFF3B0764),
          Color(0xFF7C3AED),
          Color(0xFFDDD6FE),
        ];
      case AchievementBadgeCode.competitionDone:
        return const [
          Color(0xFF1E3A5F),
          Color(0xFF1D4ED8),
          Color(0xFF93C5FD),
        ];
      case AchievementBadgeCode.reregister10:
        return const [
          Color(0xFF0C4A6E),
          Color(0xFF0369A1),
          Color(0xFF7DD3FC),
        ];
      case AchievementBadgeCode.longTerm:
        return const [
          Color(0xFF064E3B),
          Color(0xFF047857),
          Color(0xFF6EE7B7),
        ];
      case AchievementBadgeCode.attendance:
      case AchievementBadgeCode.manual:
        return const [
          Color(0xFF831843),
          Color(0xFFBE185D),
          Color(0xFFFBCFE8),
        ];
      case AchievementBadgeCode.weddingDone:
        return const [
          Color(0xFF1C1917),
          Color(0xFF57534E),
          Color(0xFFD6D3D1),
        ];

      case AchievementBadgeCode.ddayDone:
        return const [
          Color(0xFF312E81),
          Color(0xFF4F46E5),
          Color(0xFFA5B4FC),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _colors,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.35),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.25),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.hardEdge,
      child: CustomPaint(
        painter: AchievementIcChipPainter(code: code),
      ),
    );
  }
}

class _AchievementBadgeBubble extends StatelessWidget {
  const _AchievementBadgeBubble({
    required this.badge,
    required this.title,
    required this.subtitle,
  });

  final AchievementBadge badge;
  final String title;
  final String subtitle;

  List<Color> get _colors {
    switch (badge.code) {
      case AchievementBadgeCode.lesson100:
        return const [
          Color(0xFF78350F),
          Color(0xFFB45309),
          Color(0xFFFCD34D),
        ];
      case AchievementBadgeCode.bodyProfileDone:
        return const [
          Color(0xFF3B0764),
          Color(0xFF7C3AED),
          Color(0xFFDDD6FE),
        ];
      case AchievementBadgeCode.competitionDone:
        return const [
          Color(0xFF1E3A5F),
          Color(0xFF1D4ED8),
          Color(0xFF93C5FD),
        ];
      case AchievementBadgeCode.weddingDone:
        return const [
          Color(0xFF1C1917),
          Color(0xFF57534E),
          Color(0xFFD6D3D1),
        ];
      case AchievementBadgeCode.ddayDone:
        return const [
          Color(0xFF312E81),
          Color(0xFF4F46E5),
          Color(0xFFA5B4FC),
        ];
      case AchievementBadgeCode.reregister10:
        return const [
          Color(0xFF0C4A6E),
          Color(0xFF0369A1),
          Color(0xFF7DD3FC),
        ];
      case AchievementBadgeCode.longTerm:
        return const [
          Color(0xFF064E3B),
          Color(0xFF047857),
          Color(0xFF6EE7B7),
        ];
      case AchievementBadgeCode.attendance:
      case AchievementBadgeCode.manual:
        return const [
          Color(0xFF831843),
          Color(0xFFBE185D),
          Color(0xFFFBCFE8),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _colors,
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.24),
            width: 0.7,
          ),
          boxShadow: [
            BoxShadow(
              color: _colors.first.withOpacity(0.30),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.20),
                        Colors.white.withOpacity(0.04),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AchievementIcChip(
                  code: badge.code,
                  width: 54,
                  height: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                          shadows: [
                            Shadow(
                              color: Colors.black45,
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.78),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        badge.isAuto ? '자동으로 생성된 성취 기록' : '트레이너가 직접 부여한 훈장',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.64),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white.withOpacity(0.72),
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MembershipBadgeSlotRow extends StatelessWidget {
  const _MembershipBadgeSlotRow({
    required this.badges,
    required this.onBadgeTap,
  });

  final List<AchievementBadge> badges;
  final ValueChanged<AchievementBadge> onBadgeTap;

  @override
  Widget build(BuildContext context) {
    final visibleBadges = badges.take(5).toList();

    return Row(
      children: List.generate(5, (index) {
        final hasBadge = index < visibleBadges.length;
        final badge = hasBadge ? visibleBadges[index] : null;

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: index == 4 ? 0 : 4),
            child: hasBadge
                ? GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onBadgeTap(badge),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: AchievementIcChip(
                        code: badge!.code,
                        width: double.infinity,
                        height: 30,
                      ),
                    ),
                  )
                : const Padding(
                    padding: EdgeInsets.symmetric(vertical: 2),
                    child: _EmptyAchievementSlot(),
                  ),
          ),
        );
      }),
    );
  }
}

class _EmptyAchievementSlot extends StatelessWidget {
  const _EmptyAchievementSlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        color: Colors.white.withOpacity(0.045),
        border: Border.all(
          color: Colors.white.withOpacity(0.14),
          width: 0.8,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.add_rounded,
          size: 13,
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
    );
  }
}

class AchievementIcChipPainter extends CustomPainter {
  const AchievementIcChipPainter({
    required this.code,
  });

  final AchievementBadgeCode code;

  @override
  void paint(Canvas canvas, Size size) {
    _drawBaseChip(canvas, size);

    switch (code) {
      case AchievementBadgeCode.lesson100:
        _drawTrophy(canvas, size, label: '100');
        break;
      case AchievementBadgeCode.bodyProfileDone:
        _drawCamera(canvas, size, label: 'BP');
        break;
      case AchievementBadgeCode.competitionDone:
        _drawMedal(canvas, size, label: 'WIN');
        break;
      case AchievementBadgeCode.weddingDone:
        _drawTextBadge(canvas, size, main: 'WED', sub: 'DAY');
        break;
      case AchievementBadgeCode.ddayDone:
        _drawTextBadge(canvas, size, main: 'D', sub: 'DONE');
        break;
      case AchievementBadgeCode.reregister10:
        _drawTextBadge(canvas, size, main: 'R10', sub: 'RE');
        break;
      case AchievementBadgeCode.longTerm:
        _drawCrown(canvas, size, label: 'VIP');
        break;
      case AchievementBadgeCode.attendance:
      case AchievementBadgeCode.manual:
        _drawStar(canvas, size, label: 'STAR');
        break;
    }

    _drawShine(canvas, size);
  }

  void _drawBaseChip(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final crossPaint = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..strokeWidth = 0.5;

    canvas.drawLine(Offset(0, cy), Offset(size.width, cy), crossPaint);
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), crossPaint);

    final outerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy),
        width: size.width * 0.72,
        height: size.height * 0.72,
      ),
      const Radius.circular(6),
    );

    canvas.drawRRect(
      outerRect,
      Paint()
        ..color = Colors.white.withOpacity(0.12)
        ..style = PaintingStyle.fill,
    );

    canvas.drawRRect(
      outerRect,
      Paint()
        ..color = Colors.white.withOpacity(0.48)
        ..strokeWidth = 0.6
        ..style = PaintingStyle.stroke,
    );
  }

  void _drawTrophy(Canvas canvas, Size size, {required String label}) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final cupLeft = cx - size.width * 0.20;
    final cupRight = cx + size.width * 0.20;
    final cupTop = cy - size.height * 0.23;
    final cupBottom = cy - size.height * 0.02;

    final cupPath = Path()
      ..moveTo(cupLeft, cupTop)
      ..quadraticBezierTo(
        cupLeft,
        cupBottom,
        cx,
        cupBottom + size.height * 0.045,
      )
      ..quadraticBezierTo(
        cupRight,
        cupBottom,
        cupRight,
        cupTop,
      )
      ..close();

    final fill = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..style = PaintingStyle.fill;

    canvas.drawPath(cupPath, fill);

    final handlePaint = Paint()
      ..color = Colors.white.withOpacity(0.86)
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cupLeft - size.width * 0.055, cy - size.height * 0.12),
        width: size.width * 0.14,
        height: size.height * 0.18,
      ),
      -math.pi / 2,
      math.pi,
      false,
      handlePaint,
    );

    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(cupRight + size.width * 0.055, cy - size.height * 0.12),
        width: size.width * 0.14,
        height: size.height * 0.18,
      ),
      math.pi / 2,
      math.pi,
      false,
      handlePaint,
    );

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, cy + size.height * 0.12),
        width: size.width * 0.07,
        height: size.height * 0.15,
      ),
      fill,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + size.height * 0.24),
          width: size.width * 0.34,
          height: size.height * 0.08,
        ),
        const Radius.circular(2),
      ),
      fill,
    );

    _drawBottomText(canvas, size, label);
  }

  void _drawCamera(Canvas canvas, Size size, {required String label}) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final paint = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..style = PaintingStyle.fill;

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy - size.height * 0.06),
        width: size.width * 0.48,
        height: size.height * 0.30,
      ),
      const Radius.circular(4),
    );

    canvas.drawRRect(body, paint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          cx - size.width * 0.18,
          cy - size.height * 0.30,
          size.width * 0.17,
          size.height * 0.08,
        ),
        const Radius.circular(2),
      ),
      paint,
    );

    canvas.drawCircle(
      Offset(cx, cy - size.height * 0.06),
      size.height * 0.095,
      Paint()
        ..color = Colors.black.withOpacity(0.28)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      Offset(cx, cy - size.height * 0.06),
      size.height * 0.055,
      Paint()
        ..color = Colors.white.withOpacity(0.88)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      Offset(cx + size.width * 0.17, cy - size.height * 0.15),
      size.height * 0.018,
      Paint()
        ..color = Colors.black.withOpacity(0.25)
        ..style = PaintingStyle.fill,
    );

    _drawBottomText(canvas, size, label);
  }

  void _drawMedal(Canvas canvas, Size size, {required String label}) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final ribbonPaint = Paint()
      ..color = Colors.white.withOpacity(0.82)
      ..style = PaintingStyle.fill;

    final leftRibbon = Path()
      ..moveTo(cx - size.width * 0.18, cy - size.height * 0.30)
      ..lineTo(cx - size.width * 0.05, cy - size.height * 0.30)
      ..lineTo(cx, cy - size.height * 0.08)
      ..lineTo(cx - size.width * 0.08, cy - size.height * 0.08)
      ..close();

    final rightRibbon = Path()
      ..moveTo(cx + size.width * 0.18, cy - size.height * 0.30)
      ..lineTo(cx + size.width * 0.05, cy - size.height * 0.30)
      ..lineTo(cx, cy - size.height * 0.08)
      ..lineTo(cx + size.width * 0.08, cy - size.height * 0.08)
      ..close();

    canvas.drawPath(leftRibbon, ribbonPaint);
    canvas.drawPath(rightRibbon, ribbonPaint);

    canvas.drawCircle(
      Offset(cx, cy + size.height * 0.02),
      size.height * 0.18,
      Paint()
        ..color = Colors.white.withOpacity(0.94)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      Offset(cx, cy + size.height * 0.02),
      size.height * 0.105,
      Paint()
        ..color = Colors.black.withOpacity(0.17)
        ..style = PaintingStyle.fill,
    );

    _drawBottomText(canvas, size, label);
  }

  void _drawTextBadge(
    Canvas canvas,
    Size size, {
    required String main,
    required String sub,
  }) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    _drawCenteredText(
      canvas,
      text: main,
      center: Offset(cx, cy - size.height * 0.06),
      fontSize: size.height * 0.30,
      weight: FontWeight.w900,
    );

    _drawCenteredText(
      canvas,
      text: sub,
      center: Offset(cx, cy + size.height * 0.20),
      fontSize: size.height * 0.13,
      weight: FontWeight.w800,
      opacity: 0.78,
      letterSpacing: 0.8,
    );
  }

  void _drawCrown(Canvas canvas, Size size, {required String label}) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final crownPaint = Paint()
      ..color = Colors.white.withOpacity(0.92)
      ..style = PaintingStyle.fill;

    final baseY = cy + size.height * 0.07;
    final crown = Path()
      ..moveTo(cx - size.width * 0.24, baseY)
      ..lineTo(cx - size.width * 0.18, cy - size.height * 0.20)
      ..lineTo(cx - size.width * 0.06, cy - size.height * 0.04)
      ..lineTo(cx, cy - size.height * 0.25)
      ..lineTo(cx + size.width * 0.06, cy - size.height * 0.04)
      ..lineTo(cx + size.width * 0.18, cy - size.height * 0.20)
      ..lineTo(cx + size.width * 0.24, baseY)
      ..close();

    canvas.drawPath(crown, crownPaint);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, baseY + size.height * 0.045),
          width: size.width * 0.46,
          height: size.height * 0.08,
        ),
        const Radius.circular(2),
      ),
      crownPaint,
    );

    for (final offset in [-0.18, 0.0, 0.18]) {
      canvas.drawCircle(
        Offset(cx + size.width * offset, cy - size.height * 0.21),
        size.height * 0.027,
        crownPaint,
      );
    }

    _drawBottomText(canvas, size, label);
  }

  void _drawStar(Canvas canvas, Size size, {required String label}) {
    final cx = size.width / 2;
    final cy = size.height / 2 - size.height * 0.06;

    final path = Path();
    const points = 5;
    final outerRadius = size.height * 0.18;
    final innerRadius = size.height * 0.075;

    for (int i = 0; i < points * 2; i++) {
      final radius = i.isEven ? outerRadius : innerRadius;
      final angle = -math.pi / 2 + i * math.pi / points;
      final point = Offset(
        cx + math.cos(angle) * radius,
        cy + math.sin(angle) * radius,
      );

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    path.close();

    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.94)
        ..style = PaintingStyle.fill,
    );

    _drawBottomText(canvas, size, label);
  }

  void _drawBottomText(Canvas canvas, Size size, String text) {
    final cx = size.width / 2;

    _drawCenteredText(
      canvas,
      text: text,
      center: Offset(cx, size.height * 0.79),
      fontSize: size.height * 0.15,
      weight: FontWeight.w900,
      opacity: 0.96,
      letterSpacing: 0.4,
    );
  }

  void _drawCenteredText(
    Canvas canvas, {
    required String text,
    required Offset center,
    required double fontSize,
    required FontWeight weight,
    double opacity = 0.95,
    double letterSpacing = 0.4,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: weight,
          color: Colors.white.withOpacity(opacity),
          letterSpacing: letterSpacing,
          shadows: const [
            Shadow(
              color: Colors.black54,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawShine(Canvas canvas, Size size) {
    final shinePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.32),
          Colors.white.withOpacity(0.06),
          Colors.transparent,
          Colors.white.withOpacity(0.04),
        ],
        stops: const [0.0, 0.3, 0.55, 1.0],
      ).createShader(
        Rect.fromLTWH(0, 0, size.width, size.height),
      );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      shinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant AchievementIcChipPainter oldDelegate) {
    return oldDelegate.code != code;
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kPageBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kPagePrimary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: kPagePrimary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                        color: kPageText,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kPageMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ExpandableSectionCard extends StatelessWidget {
  const _ExpandableSectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kPageBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          maintainState: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: kPagePrimary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: kPagePrimary, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: kPageText,
            ),
          ),
          subtitle: subtitle == null
              ? null
              : Text(
                  subtitle!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kPageMuted,
                  ),
                ),
          trailing: trailing,
          collapsedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          children: [
            child,
          ],
        ),
      ),
    );
  }
}

class _HeaderMiniStat extends StatelessWidget {
  const _HeaderMiniStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.74),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassHeaderChip extends StatelessWidget {
  const _GlassHeaderChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MilestoneChip extends StatelessWidget {
  const _MilestoneChip({
    required this.label,
    required this.isAuto,
    this.onDone,
    this.onDelete,
  });

  final String label;
  final bool isAuto;
  final VoidCallback? onDone;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = isAuto ? const Color(0xFF4F46E5) : const Color(0xFF059669);

    return Container(
      padding: const EdgeInsets.fromLTRB(9, 7, 7, 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAuto ? Icons.auto_awesome_rounded : Icons.edit_note_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          if (onDone != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDone,
              child: Icon(
                Icons.check_circle_outline_rounded,
                size: 15,
                color: color.withOpacity(0.85),
              ),
            ),
          ],
          if (onDelete != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDelete,
              child: Icon(
                Icons.close_rounded,
                size: 15,
                color: color.withOpacity(0.75),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SoftInfoChip extends StatelessWidget {
  const _SoftInfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: kPageBorder),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: kPageMuted,
        ),
      ),
    );
  }
}

/* ------------------------- phone formatter ------------------------- */

class _ClientCardInbodyOcrData {
  const _ClientCardInbodyOcrData({
    required this.date,
    required this.weight,
    required this.skeletalMuscle,
    required this.bodyFatPercent,
    required this.bodyFatKg,
  });

  final String date;
  final String weight;
  final String skeletalMuscle;
  final String bodyFatPercent;
  final String bodyFatKg;
}

class _ClientCardBottomActionButton extends StatelessWidget {
  const _ClientCardBottomActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final Color bgColor = filled ? kPagePrimary : Colors.white;
    final Color fgColor = filled ? Colors.white : kPageText;
    final Color borderColor = filled ? kPagePrimary : kPageBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 58,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: fgColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10.6,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  color: fgColor,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KoreaPhoneTextInputFormatter extends TextInputFormatter {
  static const int _maxDigits = 11;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.length > _maxDigits) {
      digits = digits.substring(0, _maxDigits);
    }

    String formatted = digits;

    if (digits.startsWith('02')) {
      if (digits.length > 2 && digits.length <= 5) {
        formatted = '${digits.substring(0, 2)}-${digits.substring(2)}';
      } else if (digits.length > 5 && digits.length <= 9) {
        formatted =
            '${digits.substring(0, 2)}-${digits.substring(2, digits.length - 4)}-${digits.substring(digits.length - 4)}';
      } else if (digits.length >= 10) {
        formatted =
            '${digits.substring(0, 2)}-${digits.substring(2, 6)}-${digits.substring(6, 10)}';
      }
    } else {
      if (digits.length > 3 && digits.length <= 7) {
        formatted = '${digits.substring(0, 3)}-${digits.substring(3)}';
      } else if (digits.length > 7) {
        formatted =
            '${digits.substring(0, 3)}-${digits.substring(3, digits.length - 4)}-${digits.substring(digits.length - 4)}';
      }
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

String membershipMemberLabel(String? value) {
  final clean = (value ?? '').trim();
  if (clean.isEmpty) return '회원님';
  final withoutSuffix = clean.replaceFirst(RegExp(r'\s*님$'), '').trim();
  return '${withoutSuffix.isEmpty ? '회원' : withoutSuffix}님';
}
