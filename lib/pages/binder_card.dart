// lib/pages/binder_card.dart
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:mtf_app/models/member.dart';

class BinderCard extends StatefulWidget {
  const BinderCard({
    super.key,
    required this.member,
    required this.onOpenJournal,
    required this.onOpenEdit,
    required this.onOpenContract,
    required this.onLongPress,

    // ✅ 추가: 진짜 바인더 안 버튼 슬롯
    this.topRightAction,
    this.bottomRightAction,
  });

  final Member member;
  final Future<void> Function() onOpenJournal;
  final Future<void> Function() onOpenEdit;
  final Future<void> Function() onOpenContract;
  final VoidCallback onLongPress;

  // ✅ 추가
  final Widget? topRightAction;
  final Widget? bottomRightAction;

  @override
  State<BinderCard> createState() => _BinderCardState();
}

enum _Stage { idle, lift, pulled }

class _BinderCardState extends State<BinderCard> with TickerProviderStateMixin {
  late final AnimationController _ctrl; // 0..2
  late final AnimationController _pressCtrl; // 0..1

  Offset _pressNorm = Offset.zero;
  _Stage _stage = _Stage.idle;
  bool _busy = false;

  static const _liftDur = Duration(milliseconds: 180);
  static const _pullDur = Duration(milliseconds: 420);
  static const _pullCurve = Cubic(0.16, 1.0, 0.30, 1.0);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      lowerBound: 0,
      upperBound: 2,
      duration: _pullDur,
      reverseDuration: const Duration(milliseconds: 260),
    );
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 130),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pressCtrl.dispose();
    super.dispose();
  }

  double get _liftT => _ctrl.value.clamp(0.0, 1.0);
  double get _pullT => (_ctrl.value - 1.0).clamp(0.0, 1.0);

  Future<void> _lift() async {
    if (_busy || _stage != _Stage.idle) return;
    _busy = true;
    HapticFeedback.selectionClick();
    try {
      _ctrl.duration = _liftDur;
      await _ctrl.animateTo(1.0, curve: Curves.easeOutCubic);
      _stage = _Stage.lift;
    } finally {
      _busy = false;
    }
  }

  Future<void> _unliftAll() async {
    if (_busy || _stage == _Stage.idle) return;
    _busy = true;
    try {
      await _ctrl.animateBack(0.0, curve: Curves.easeOutCubic);
      _stage = _Stage.idle;
    } finally {
      _busy = false;
    }
  }

  Future<void> _openPaperOverlay(String heroTag) async {
    if (_busy) return;
    _busy = true;
    HapticFeedback.mediumImpact();

    try {
      if (_ctrl.value < 1.0) {
        _ctrl.duration = _liftDur;
        await _ctrl.animateTo(1.0, curve: Curves.easeOutCubic);
        _stage = _Stage.lift;
      }

      _ctrl.duration = _pullDur;
      await _ctrl.animateTo(2.0, curve: _pullCurve);
      _stage = _Stage.pulled;

      if (!mounted) return;

      await Navigator.of(context).push(
        PageRouteBuilder(
          opaque: false,
          barrierDismissible: true,
          pageBuilder: (_, __, ___) {
            return _BinderPaperOverlayPage(
              heroTag: heroTag,
              member: widget.member,
              onOpenJournal: widget.onOpenJournal,
              onOpenEdit: widget.onOpenEdit,
              onOpenContract: widget.onOpenContract,
            );
          },
          transitionsBuilder: (_, anim, __, child) {
            final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
            return FadeTransition(opacity: curved, child: child);
          },
        ),
      );
    } finally {
      if (mounted) {
        await _ctrl.animateBack(0.0, curve: Curves.easeOutCubic);
      }
      _stage = _Stage.idle;
      _busy = false;
    }
  }

  void _onTap(String heroTag) {
    if (_stage == _Stage.idle) {
      _lift();
      return;
    }
    _openPaperOverlay(heroTag);
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.member;
    final heroTag = 'binderPaperHero_${m.id}';

    final isExpired = m.isExpired;
    final remain = m.remainingSessions;
    final isLowRemain = !isExpired && remain > 0 && remain <= 5;

    final spine = _genderColor(m.gender);
    final coverGrad = _coverGradient(
      gender: m.gender,
      isExpired: isExpired,
      lowRemain: isLowRemain,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // ✅ 중요: PageView 안에서 또 작게 줄이지 말기(겹쳐짐이 살아야 함)
        final maxW = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;

        final w = (maxW * 0.98).clamp(240.0, 420.0);
        final coverH = (w * 1.414).clamp(320.0, 520.0);

        return SizedBox(
          width: w,
          child: TapRegion(
            groupId: this,
            onTapOutside: (_) {
              if (_stage != _Stage.idle) _unliftAll();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,

              onTapDown: (d) {
                final box = context.findRenderObject() as RenderBox?;
                if (box == null) return;
                final local = box.globalToLocal(d.globalPosition);
                final s = box.size;
                _pressNorm = Offset((local.dx / s.width) - 0.5, (local.dy / s.height) - 0.5);
                _pressCtrl.forward();
              },
              onTapUp: (_) => _pressCtrl.reverse(),
              onTapCancel: () => _pressCtrl.reverse(),

              onTap: () => _onTap(heroTag),
              onDoubleTap: () => _openPaperOverlay(heroTag),
              onLongPress: widget.onLongPress,

              child: AnimatedBuilder(
                animation: Listenable.merge([_ctrl, _pressCtrl]),
                builder: (context, _) {
                  final liftT = _liftT;
                  final pullT = _pullT;

                  final liftY = -10 * liftT;
                  final hinge = -7 * math.pi / 180 * liftT;

                  final p = _pressCtrl.value;
                  final tiltX = (-_pressNorm.dy) * (5 * math.pi / 180) * p;
                  final tiltZ = (_pressNorm.dx) * (4 * math.pi / 180) * p;

                  final openCorner = 0.20 * liftT;

                  final mtx = Matrix4.identity()
                    ..setEntry(3, 2, 0.0019)
                    ..rotateX(tiltX)
                    ..rotateY(hinge)
                    ..rotateZ(tiltZ);

                  return Transform.translate(
                    offset: Offset(0, liftY),
                    child: Transform(
                      transform: mtx,
                      alignment: Alignment.center,
                      child: _StackedBinderVisual(
                        width: w,
                        coverH: coverH,
                        spineColor: spine,
                        coverGradient: coverGrad,
                        member: m,
                        openCorner: openCorner,
                        lifted: liftT,
                        pullOut: pullT,
                        lowRemain: isLowRemain,
                        heroTag: heroTag,

                        // ✅ 추가: 외부에서 받은 슬롯 전달
                        topRightAction: widget.topRightAction,
                        bottomRightAction: widget.bottomRightAction,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/* ─────────────  STYLE  ───────────── */
const _kPrimary = Color(0xFF4F46E5);

/* ─────────────  STACKED BINDER VISUAL  ───────────── */

class _StackedBinderVisual extends StatelessWidget {
  const _StackedBinderVisual({
    required this.width,
    required this.coverH,
    required this.spineColor,
    required this.coverGradient,
    required this.member,
    required this.openCorner,
    required this.lifted,
    required this.pullOut,
    required this.lowRemain,
    required this.heroTag,

    // ✅ 추가
    this.topRightAction,
    this.bottomRightAction,
  });

  final double width;
  final double coverH;
  final Color spineColor;
  final Gradient coverGradient;
  final Member member;
  final double openCorner;
  final double lifted;
  final double pullOut;
  final bool lowRemain;
  final String heroTag;

  // ✅ 추가
  final Widget? topRightAction;
  final Widget? bottomRightAction;

  @override
  Widget build(BuildContext context) {
    final back1 = Offset(16 + 10 * lifted, 12 + 8 * lifted);
    final back2 = Offset(9 + 6 * lifted, 7 + 5 * lifted);

    Widget backLayer(Offset o, double opacity) {
      return Positioned(
        left: o.dx,
        top: o.dy,
        child: Container(
          width: width - o.dx,
          height: coverH,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      );
    }

    final name = member.name ?? member.id;

    return SizedBox(
      height: coverH + 34,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          backLayer(back1, 0.92),
          backLayer(back2, 0.96),

          Positioned(
            left: 10,
            top: -12,
            child: _IndexTab(
              label: name,
              danger: member.isExpired || lowRemain,
              badge: member.isExpired ? '만료' : (lowRemain ? '잔여 ${member.remainingSessions}회' : null),
            ),
          ),

          _PaperBundle(
            heroTag: heroTag,
            width: width,
            coverH: coverH,
            pullOut: pullOut,
          ),

          Positioned(
            left: 0,
            top: 0,
            child: _FrontBinderCover(
              width: width,
              height: coverH,
              spineColor: spineColor,
              coverGradient: coverGradient,
              member: member,
              openCorner: openCorner,
              lowRemain: lowRemain,

              // ✅ 추가: 표지로 슬롯 전달
              topRightAction: topRightAction,
              bottomRightAction: bottomRightAction,
            ),
          ),

          Positioned(
            left: 10,
            right: 10,
            bottom: 6,
            child: Opacity(
              opacity: (1 - lifted * 0.7).clamp(0.0, 1.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.70),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  '탭: 들어올림 · 한 번 더 탭: 종이 펼치기',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.black.withOpacity(.55),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/* ─────────────  PAPER BUNDLE  ───────────── */

class _PaperBundle extends StatelessWidget {
  const _PaperBundle({
    required this.heroTag,
    required this.width,
    required this.coverH,
    required this.pullOut,
  });

  final String heroTag;
  final double width;
  final double coverH;
  final double pullOut;

  @override
  Widget build(BuildContext context) {
    final peek = 0.12;
    final t = (peek + (1 - peek) * pullOut).clamp(0.0, 1.0);

    final x = 10 + 54 * t;
    final y = 16 - 10 * t;
    final rot = -2.4 * math.pi / 180 * t;
    final scale = 0.98 + 0.05 * t;

    return Positioned(
      left: x,
      top: y,
      child: Transform.rotate(
        angle: rot,
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.topLeft,
          child: Hero(
            tag: heroTag,
            child: _PaperCardMini(
              width: width * 0.90,
              height: coverH * 0.86,
            ),
          ),
        ),
      ),
    );
  }
}

/* 작은 종이(겹침용) */
class _PaperCardMini extends StatelessWidget {
  const _PaperCardMini({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    Widget sheet(double dx, double dy, double opacity) {
      return Positioned(
        left: dx,
        top: dy,
        child: Container(
          width: width - dx,
          height: height - dy,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.08),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            sheet(18, 18, 0.86),
            sheet(12, 14, 0.90),
            sheet(7, 9, 0.94),
            sheet(3, 5, 0.97),
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.12),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 10,
                        width: width * 0.55,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.78),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(
                        9,
                            (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            height: 6,
                            width: width * (0.88 - i * 0.05),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(.06),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      ),
                    ],
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

/* ─────────────  INDEX TAB  ───────────── */

class _IndexTab extends StatelessWidget {
  const _IndexTab({
    required this.label,
    required this.danger,
    required this.badge,
  });

  final String label;
  final bool danger;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final bg = danger ? const Color(0xFFFFE4E6) : const Color(0xFFE0E7FF);
    final fg = danger ? const Color(0xFFBE123C) : _kPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.folder_open, size: 16, color: _kPrimary),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
              child: Text(
                badge!,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/* ─────────────  FRONT COVER  ───────────── */

class _FrontBinderCover extends StatelessWidget {
  const _FrontBinderCover({
    required this.width,
    required this.height,
    required this.spineColor,
    required this.coverGradient,
    required this.member,
    required this.openCorner,
    required this.lowRemain,

    // ✅ 추가
    this.topRightAction,
    this.bottomRightAction,
  });

  final double width;
  final double height;
  final Color spineColor;
  final Gradient coverGradient;
  final Member member;
  final double openCorner;
  final bool lowRemain;

  // ✅ 추가
  final Widget? topRightAction;
  final Widget? bottomRightAction;

  @override
  Widget build(BuildContext context) {
    final isExpired = member.isExpired;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: coverGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isExpired ? .16 : .10),
              blurRadius: isExpired ? 22 : 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.centerLeft,
                      colors: [
                        Colors.white.withOpacity(0),
                        Colors.white.withOpacity(.12),
                        Colors.white.withOpacity(0),
                      ],
                      stops: const [0.0, 0.33, 0.72],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              top: 48,
              child: _Spine(color: spineColor, title: member.name ?? member.id),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(50, 14, 12, 12),
                child: _FrontSummary(member: member),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: ClipPath(
                clipper: _CornerClipper(openCorner),
                child: Container(
                  width: width * 0.56,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Colors.white.withOpacity(.70),
                        Colors.white.withOpacity(.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // ✅ (추가) 상단 오른쪽 슬롯: 핀 버튼
            if (topRightAction != null)
              Positioned(
                right: 10,
                top: 52, // status pill(10,10)과 겹침 방지로 아래로
                child: topRightAction!,
              ),

            // ✅ (추가) 하단 오른쪽 슬롯: 드래그 핸들
            if (bottomRightAction != null)
              Positioned(
                right: 10,
                bottom: 12,
                child: bottomRightAction!,
              ),
            if (member.isExpired || member.memberStatus == '휴면' || lowRemain)
              Positioned(
                right: 10,
                top: 10,
                child: _StatusPill(
                  text: member.isExpired
                      ? '만료'
                      : (member.memberStatus == '휴면' ? '휴강' : '잔여 ${member.remainingSessions}회'),
                  danger: member.isExpired || lowRemain,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CornerClipper extends CustomClipper<Path> {
  _CornerClipper(this.openCorner);
  final double openCorner;

  @override
  Path getClip(Size size) {
    final k = openCorner.clamp(0.0, 0.24);
    final cut = size.width * k;
    final cutY = size.height * (0.34 + k);

    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - cut, cutY)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant _CornerClipper oldClipper) => oldClipper.openCorner != openCorner;
}

class _Spine extends StatelessWidget {
  const _Spine({required this.color, required this.title});
  final Color color;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 128,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(.55), color.withOpacity(.92)],
        ),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
        border: Border.all(color: color.withOpacity(.85), width: 2),
      ),
      child: RotatedBox(
        quarterTurns: 3,
        child: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _FrontSummary extends StatelessWidget {
  const _FrontSummary({required this.member});
  final Member member;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yy.MM.dd');

    final dday = _dday(member.expireAt);
    final ddayText = dday == null ? '-' : (dday == 0 ? 'D-DAY' : (dday > 0 ? 'D-$dday' : 'D+${dday.abs()}'));

    final total = member.totalSessions;
    final remain = member.remainingSessions;
    final p = total > 0 ? (remain / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  member.name ?? member.id,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _Ring(progress: p, label: '$remain/$total'),
            ],
          ),
          const SizedBox(height: 8),
          _InfoRow('만료일', member.expireAt != null ? fmt.format(member.expireAt!) : '-'),
          _InfoRow('D-day', ddayText),
          _InfoRow('최근', member.lastLogAt != null ? fmt.format(member.lastLogAt!) : '-'),
        ],
      ),
    );
  }
}

/* ─────────────  OVERLAY PAGE  ───────────── */

class _BinderPaperOverlayPage extends StatelessWidget {
  const _BinderPaperOverlayPage({
    required this.heroTag,
    required this.member,
    required this.onOpenJournal,
    required this.onOpenEdit,
    required this.onOpenContract,
  });

  final String heroTag;
  final Member member;
  final Future<void> Function() onOpenJournal;
  final Future<void> Function() onOpenEdit;
  final Future<void> Function() onOpenContract;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    final paperW = (size.width * 0.88).clamp(320.0, 420.0);
    final paperH = (paperW * 1.414).clamp(420.0, size.height * 0.82);

    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.black.withOpacity(0.22))),
            Center(
              child: GestureDetector(
                onTap: () {},
                child: Hero(
                  tag: heroTag,
                  child: Material(
                    color: Colors.transparent,
                    child: _PaperDetailCard(
                      width: paperW,
                      height: paperH,
                      member: member,
                      onClose: () => Navigator.pop(context),
                      onOpenJournal: onOpenJournal,
                      onOpenEdit: onOpenEdit,
                      onOpenContract: onOpenContract,
                    ),
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

class _PaperDetailCard extends StatelessWidget {
  const _PaperDetailCard({
    required this.width,
    required this.height,
    required this.member,
    required this.onClose,
    required this.onOpenJournal,
    required this.onOpenEdit,
    required this.onOpenContract,
  });

  final double width;
  final double height;
  final Member member;
  final VoidCallback onClose;
  final Future<void> Function() onOpenJournal;
  final Future<void> Function() onOpenEdit;
  final Future<void> Function() onOpenContract;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy-MM-dd');
    final total = member.totalSessions;
    final remain = member.remainingSessions;
    final progress = total > 0 ? (remain / total).clamp(0.0, 1.0) : 0.0;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.description_outlined, color: _kPrimary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    member.name ?? member.id,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        _Ring(progress: progress, label: '$remain/$total'),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '총 $total회\n잔여 $remain회',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('고객 정보', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 10),
                        _InfoRow('이름', member.name ?? member.id),
                        _InfoRow('전화', member.phone ?? '-'),
                        _InfoRow('만료일', member.expireAt != null ? fmt.format(member.expireAt!) : '-'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _BigActionButton(
                    icon: Icons.menu_book_outlined,
                    label: '운동 기록 일지',
                    onTap: () async {
                      onClose();
                      await onOpenJournal();
                    },
                  ),
                  const SizedBox(height: 10),
                  _BigActionButton(
                    icon: Icons.edit_outlined,
                    label: '고객 정보 수정',
                    onTap: () async {
                      onClose();
                      await onOpenEdit();
                    },
                  ),
                  const SizedBox(height: 10),
                  _BigActionButton(
                    icon: Icons.description_outlined,
                    label: '계약서',
                    onTap: () async {
                      onClose();
                      await onOpenContract();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BigActionButton extends StatelessWidget {
  const _BigActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: _kPrimary),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
            const Icon(Icons.chevron_right_rounded, color: Colors.black45),
          ],
        ),
      ),
    );
  }
}

/* ─────────────  SHARED  ───────────── */

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.danger});
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final bg = danger ? const Color(0xFFFFF7ED) : const Color(0xFFEFF6FF);
    final fg = danger ? const Color(0xFF9A3412) : const Color(0xFF1D4ED8);
    final bd = danger ? const Color(0xFFFED7AA) : const Color(0xFFBFDBFE);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: bd),
      ),
      child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

Color _genderColor(Gender g) {
  switch (g) {
    case Gender.female:
      return const Color(0xFFFF6FA4);
    case Gender.male:
      return const Color(0xFF2E6DD8);
    case Gender.unknown:
      return Colors.teal;
  }
}

Gradient _coverGradient({
  required Gender gender,
  required bool isExpired,
  required bool lowRemain,
}) {
  if (isExpired) {
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF3F4F6), Color(0xFFE5E7EB), Color(0xFFD1D5DB)],
    );
  }

  final base = (gender == Gender.female)
      ? const [Color(0xFFFFEEF7), Color(0xFFFFD7EA), Color(0xFFFFB8D8)]
      : const [Color(0xFFEEF2FF), Color(0xFFDDE7FF), Color(0xFFBFD3FF)];

  if (!lowRemain) {
    return LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: base);
  }

  const warnA = Color(0xFFFFE4E6);
  const warnB = Color(0xFFFFC7D1);
  const warnC = Color(0xFFFDA4AF);

  Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;

  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      mix(base[0], warnA, 0.45),
      mix(base[1], warnB, 0.45),
      mix(base[2], warnC, 0.35),
    ],
  );
}

int? _dday(DateTime? target) {
  if (target == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(target.year, target.month, target.day);
  return d.difference(today).inDays;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          SizedBox(width: 64, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.progress, required this.label});
  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(painter: _RingPainter(progress: progress, color: cs.primary), child: const SizedBox(width: 52, height: 52)),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const stroke = 7.0;

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.grey.shade300;

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..shader = SweepGradient(colors: [color, color.withOpacity(.85)]).createShader(Offset.zero & size);

    canvas.drawArc(Rect.fromLTWH(stroke / 2, stroke / 2, w - stroke, w - stroke), -math.pi / 2, math.pi * 2, false, bg);
    canvas.drawArc(Rect.fromLTWH(stroke / 2, stroke / 2, w - stroke, w - stroke), -math.pi / 2, math.pi * 2 * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.color != color;
}