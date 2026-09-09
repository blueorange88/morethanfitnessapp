import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────
// 등급 정의
// ─────────────────────────────────────────
enum AifcTierUpgrade {
  beginnerToAmateur, // 비기너 → 아마추어
  amateurToSemiPro, // 아마추어 → 세미프로
  semiProToPro, // 세미프로 → 프로
}

// ─────────────────────────────────────────
// 진입점
// ─────────────────────────────────────────
class AifcTierCelebrationSheet {
  const AifcTierCelebrationSheet._();

  static Future<bool?> show({
    required BuildContext context,
    required String trainerName,
    required AifcTierUpgrade upgrade,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TierCelebrationBody(
        trainerName: trainerName,
        upgrade: upgrade,
      ),
    );
  }
}

// ─────────────────────────────────────────
// 등급별 테마 데이터
// ─────────────────────────────────────────
class _TierTheme {
  const _TierTheme({
    required this.sheetBg,
    required this.titleColor,
    required this.subColor,
    required this.featBg,
    required this.featBorderColor,
    required this.featTextColor,
    required this.handleColor,
    required this.btnColors,
    required this.fromIcon,
    required this.fromLabel,
    required this.fromIconColor,
    required this.fromBg,
    required this.fromBorder,
    required this.toIcon,
    required this.toLabel,
    required this.toIconColor,
    required this.toBg,
    required this.toBorder,
    required this.title,
    required this.subtitle,
    required this.features,
    required this.btnLabel,
    required this.fxType,
  });

  final Color sheetBg;
  final Color titleColor;
  final Color subColor;
  final Color featBg;
  final Color featBorderColor;
  final Color featTextColor;
  final Color handleColor;
  final List<Color> btnColors;

  final IconData fromIcon;
  final String fromLabel;
  final Color fromIconColor;
  final Color fromBg;
  final Color fromBorder;

  final IconData toIcon;
  final String toLabel;
  final Color toIconColor;
  final Color toBg;
  final Color toBorder;

  final String title;
  final String subtitle;
  final List<String> features;
  final String btnLabel;
  final _FxType fxType;
}

enum _FxType { popper, ranked, pro }

double _powDouble(num x, num exponent) {
  return pow(x, exponent).toDouble();
}

_TierTheme _themeFor(AifcTierUpgrade upgrade) {
  switch (upgrade) {
    case AifcTierUpgrade.beginnerToAmateur:
      return _TierTheme(
        sheetBg: Colors.white,
        titleColor: const Color(0xFF111827),
        subColor: const Color(0xFF6B7280),
        featBg: const Color(0xFFF9FAFB),
        featBorderColor: const Color(0xFFE5E7EB),
        featTextColor: const Color(0xFF374151),
        handleColor: const Color(0xFFD1D5DB),
        btnColors: [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
        fromIcon: Icons.eco_outlined,
        fromLabel: '비기너',
        fromIconColor: const Color(0xFF9CA3AF),
        fromBg: const Color(0xFFF3F4F6),
        fromBorder: const Color(0xFFD1D5DB),
        toIcon: Icons.star_outline_rounded,
        toLabel: '아마추어',
        toIconColor: const Color(0xFF1D4ED8),
        toBg: const Color(0xFFEFF6FF),
        toBorder: const Color(0xFF93C5FD),
        title: 'Amateur 등급으로 성장했어요.',
        subtitle: '레슨 일정을 채우고 선생님 정보까지 완료하셨어요.\n'
            '이제 고객카드로 회원관리를 시작할 수 있어요.',
        features: ['고객카드 회원관리', '회원별 레슨 이력', '남은 회차 확인'],
        btnLabel: '고객카드 시작하기',
        fxType: _FxType.popper,
      );

    case AifcTierUpgrade.amateurToSemiPro:
      return _TierTheme(
        sheetBg: const Color(0xFF13112B),
        titleColor: const Color(0xFFEDE9FE),
        subColor: const Color(0xFFA78BFA),
        featBg: const Color(0xFF7C3AED).withOpacity(0.13),
        featBorderColor: const Color(0xFF8B5CF6).withOpacity(0.28),
        featTextColor: const Color(0xFFDDD6FE),
        handleColor: const Color(0xFF7C3AED),
        btnColors: [const Color(0xFF7C3AED), const Color(0xFF4F46E5)],
        fromIcon: Icons.star_outline_rounded,
        fromLabel: '아마추어',
        fromIconColor: const Color(0xFF93C5FD),
        fromBg: const Color(0xFF3B82F6).withOpacity(0.15),
        fromBorder: const Color(0xFF3B82F6).withOpacity(0.3),
        toIcon: Icons.emoji_events_outlined,
        toLabel: '세미프로',
        toIconColor: const Color(0xFFC4B5FD),
        toBg: const Color(0xFF7C3AED).withOpacity(0.2),
        toBorder: const Color(0xFFA78BFA).withOpacity(0.45),
        title: '세미프로 달성을 축하해요!',
        subtitle: '계약서 작성과 전자서명이 열렸어요.\n지금 바로 첫 계약서를 써볼 수 있어요.',
        features: ['계약서 작성 + 전자서명', '레슨 횟수 계약 기준 연동', '수입 분석 고급 인사이트'],
        btnLabel: '첫 계약서 작성 시작하기',
        fxType: _FxType.ranked,
      );

    case AifcTierUpgrade.semiProToPro:
      return _TierTheme(
        sheetBg: const Color(0xFF0E0700),
        titleColor: const Color(0xFFFEF3C7),
        subColor: const Color(0xFFFCD34D),
        featBg: const Color(0xFFD97706).withOpacity(0.12),
        featBorderColor: const Color(0xFFFBBF24).withOpacity(0.28),
        featTextColor: const Color(0xFFFDE68A),
        handleColor: const Color(0xFFF59E0B),
        btnColors: [const Color(0xFFD97706), const Color(0xFF92400E)],
        fromIcon: Icons.emoji_events_outlined,
        fromLabel: '세미프로',
        fromIconColor: const Color(0xFFA78BFA),
        fromBg: const Color(0xFF7C3AED).withOpacity(0.15),
        fromBorder: const Color(0xFFA78BFA).withOpacity(0.3),
        toIcon: Icons.workspace_premium_rounded,
        toLabel: '프로',
        toIconColor: const Color(0xFFFCD34D),
        toBg: const Color(0xFFD97706).withOpacity(0.2),
        toBorder: const Color(0xFFFBBF24).withOpacity(0.45),
        title: '드디어 프로 강사가 됐어요!',
        subtitle: '모든 기능이 제한 없이 열렸어요.\n최고의 강사로서 함께해요.',
        features: ['모든 기능 무제한 해금', '전용 분석 대시보드', '우선 고객 지원'],
        btnLabel: '프로 기능 전체 확인하기',
        fxType: _FxType.pro,
      );
  }
}

// ─────────────────────────────────────────
// 바텀시트 본체
// ─────────────────────────────────────────
class _TierCelebrationBody extends StatefulWidget {
  const _TierCelebrationBody({
    required this.trainerName,
    required this.upgrade,
  });

  final String trainerName;
  final AifcTierUpgrade upgrade;

  @override
  State<_TierCelebrationBody> createState() => _TierCelebrationBodyState();
}

class _TierCelebrationBodyState extends State<_TierCelebrationBody>
    with TickerProviderStateMixin {
  late final _TierTheme _theme;

  String get _safeTrainerName {
    final text = widget.trainerName.trim();

    if (text.isEmpty) return '강사님';
    return text.endsWith('님') ? text : '$text님';
  }

  // 공통
  late final AnimationController _fxCtrl;

  // 비기너→아마추어 전용 (꼬깔 폭죽)
  late final AnimationController _popperCtrl;

  // 배지 떠오르기 (세미프로→프로)
  late final AnimationController _riseCtrl;
  late final Animation<double> _riseOpacity;
  late final Animation<Offset> _riseSlide;

  // 플래시 (세미프로→프로, 아마추어→세미프로)
  late final AnimationController _flashCtrl;
  late final Animation<double> _flashAnim;

  @override
  void initState() {
    super.initState();
    _theme = _themeFor(widget.upgrade);

    _fxCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _popperCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _flashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _flashAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _flashCtrl, curve: Curves.easeInOut));

    _riseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _riseOpacity = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _riseCtrl, curve: Curves.easeOut));
    _riseSlide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
        CurvedAnimation(parent: _riseCtrl, curve: const _SpringCurve()));

    HapticFeedback.heavyImpact();
    _startSequence();
  }

  Future<void> _startSequence() async {
    await Future.delayed(const Duration(milliseconds: 80));

    switch (_theme.fxType) {
      case _FxType.popper:
        _popperCtrl.forward();
        break;

      case _FxType.ranked:
        _flashCtrl.forward();
        await Future.delayed(const Duration(milliseconds: 300));
        _fxCtrl.forward();
        break;

      case _FxType.pro:
        _flashCtrl.forward();
        await Future.delayed(const Duration(milliseconds: 480));
        _riseCtrl.forward();
        await Future.delayed(const Duration(milliseconds: 200));
        _fxCtrl.forward();
        break;
    }
  }

  @override
  void dispose() {
    _fxCtrl.dispose();
    _popperCtrl.dispose();
    _flashCtrl.dispose();
    _riseCtrl.dispose();
    super.dispose();
  }

  // 배지 — 프로만 떠오르기 애니메이션
  Widget _buildToBadge() {
    final badge = _TierBadge(
      icon: _theme.toIcon,
      label: _theme.toLabel,
      iconColor: _theme.toIconColor,
      bgColor: _theme.toBg,
      borderColor: _theme.toBorder,
    );

    if (_theme.fxType == _FxType.pro) {
      return FadeTransition(
        opacity: _riseOpacity,
        child: SlideTransition(position: _riseSlide, child: badge),
      );
    }
    return badge;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── 메인 시트 ──
            Container(
              decoration: BoxDecoration(
                color: _theme.sheetBg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _theme.handleColor.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 배지 행
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _TierBadge(
                          icon: _theme.fromIcon,
                          label: _theme.fromLabel,
                          iconColor: _theme.fromIconColor,
                          bgColor: _theme.fromBg,
                          borderColor: _theme.fromBorder,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: 18, left: 10, right: 10),
                          child: Icon(Icons.arrow_forward_rounded,
                              size: 16, color: _theme.subColor),
                        ),
                        _buildToBadge(),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Text(
                      '$_safeTrainerName,\n${_theme.title}',
                      style: TextStyle(
                        color: _theme.titleColor,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _theme.subtitle,
                      style: TextStyle(
                        color: _theme.subColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _theme.featBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _theme.featBorderColor),
                      ),
                      child: Column(
                        children: _theme.features
                            .map((f) => Padding(
                                  padding: EdgeInsets.only(
                                      bottom:
                                          f == _theme.features.last ? 0 : 8),
                                  child: _FeatureRow(
                                      text: f,
                                      dotColor: _theme.subColor,
                                      textColor: _theme.featTextColor),
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _theme.btnColors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          Navigator.of(context).pop(true);
                        },
                        child: Text(_theme.btnLabel,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(
                        widget.upgrade == AifcTierUpgrade.beginnerToAmateur
                            ? '홈으로 돌아가기'
                            : '나중에 시작할게요',
                        style: TextStyle(
                          color: _theme.subColor.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── 비기너→아마추어: 꼬깔 폭죽 ──
            if (_theme.fxType == _FxType.popper)
              AnimatedBuilder(
                animation: _popperCtrl,
                builder: (_, __) => Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(26)),
                      child: CustomPaint(
                        painter: _PopperPainter(progress: _popperCtrl.value),
                      ),
                    ),
                  ),
                ),
              ),

            // ── 아마추어→세미프로: 빔+링+파티클 ──
            if (_theme.fxType == _FxType.ranked)
              AnimatedBuilder(
                animation: _fxCtrl,
                builder: (_, __) => Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(26)),
                      child: CustomPaint(
                        painter: _RankedPainter(progress: _fxCtrl.value),
                      ),
                    ),
                  ),
                ),
              ),

            // ── 세미프로→프로: 모퉁이 문양+파티클 ──
            if (_theme.fxType == _FxType.pro)
              AnimatedBuilder(
                animation: _fxCtrl,
                builder: (_, __) => Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(26)),
                      child: CustomPaint(
                        painter: _GoldOrnamentPainter(progress: _fxCtrl.value),
                      ),
                    ),
                  ),
                ),
              ),

            // ── 플래시 (세미프로 / 프로 공통) ──
            if (_theme.fxType == _FxType.ranked || _theme.fxType == _FxType.pro)
              AnimatedBuilder(
                animation: _flashAnim,
                builder: (_, __) {
                  if (_flashAnim.value <= 0) return const SizedBox.shrink();
                  final flashColor = _theme.fxType == _FxType.ranked
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFFFFEB96);
                  return Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(26)),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.center,
                              radius: 1.2,
                              colors: [
                                flashColor.withOpacity(_flashAnim.value * 0.92),
                                flashColor.withOpacity(_flashAnim.value * 0.4),
                                Colors.transparent,
                              ],
                              stops: const [0, 0.5, 1],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

            // 흰 번쩍임 (프로만)
            if (_theme.fxType == _FxType.pro)
              AnimatedBuilder(
                animation: _flashAnim,
                builder: (_, __) {
                  final v = ((_flashAnim.value - 0.6).clamp(0.0, 0.4) / 0.4);
                  if (v <= 0) return const SizedBox.shrink();
                  return Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(26)),
                        child: ColoredBox(
                          color: Colors.white.withOpacity(v * 0.92),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// 공통 위젯
// ─────────────────────────────────────────
class _TierBadge extends StatelessWidget {
  const _TierBadge({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
    required this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color iconColor, bgColor, borderColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 2),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: iconColor, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.text,
    required this.dotColor,
    required this.textColor,
  });

  final String text;
  final Color dotColor, textColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 9),
        Text(text,
            style: TextStyle(
                color: textColor, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Painter: 비기너→아마추어 꼬깔 폭죽
// ─────────────────────────────────────────
class _PopperPainter extends CustomPainter {
  _PopperPainter({required this.progress});
  final double progress;

  static List<_Particle>? _p1, _p2, _p3;

  static List<_Particle> _makePopper(
      double ox, double oy, int seed, List<Color> cols) {
    final rng = Random(seed);
    return List.generate(32, (_) {
      final a = rng.nextDouble() * pi * 2;
      final spd = 3 + rng.nextDouble() * 6;
      return _Particle(
        ox: ox,
        oy: oy,
        vx: cos(a) * spd,
        vy: sin(a) * spd - 3,
        size: 4 + rng.nextDouble() * 5,
        aspect: 0.5 + rng.nextDouble() * 0.5,
        color: cols[rng.nextInt(cols.length)],
        rot: rng.nextDouble() * pi * 2,
        vr: (rng.nextDouble() - 0.5) * 0.22,
        delay: 0,
      );
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cols = [
      const Color(0xFF60A5FA),
      const Color(0xFF93C5FD),
      const Color(0xFFBFDBFE),
      Colors.white,
      const Color(0xFFFCA5A5),
      const Color(0xFF86EFAC),
      const Color(0xFFFDE68A),
    ];
    _p1 ??= _makePopper(size.width * .18, size.height * .42, 1, cols);
    _p2 ??= _makePopper(size.width * .82, size.height * .42, 2, cols);
    _p3 ??= _makePopper(size.width * .50, size.height * .46, 3, cols);

    _drawPopper(canvas, size, _p1!, 0.0);
    _drawPopper(canvas, size, _p2!, 0.12);
    _drawPopper(canvas, size, _p3!, 0.26);
  }

  void _drawPopper(
      Canvas canvas, Size size, List<_Particle> parts, double startT) {
    if (progress < startT) return;
    final t = ((progress - startT) / (1 - startT)).clamp(0.0, 1.0);
    final steps = t * 55;

    // 터질 때 플래시
    if (t < 0.12) {
      final fa = t / 0.12;
      final grd = Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withOpacity(fa * 0.7),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(
            center: Offset(parts[0].ox, parts[0].oy), radius: 30));
      canvas.drawCircle(Offset(parts[0].ox, parts[0].oy), 30 * fa, grd);
    }

    for (final p in parts) {
      final px = p.ox + p.vx * steps * _powDouble(0.97, steps);
      final py = p.oy + p.vy * steps + 0.2 * steps * steps;
      double alpha = t < 0.25 ? t / 0.25 : 1.0;
      if (py > size.height * .62)
        alpha -= (py - size.height * .62) / (size.height * .15);
      alpha = alpha.clamp(0.0, 1.0);
      if (alpha <= 0) continue;

      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(p.rot + p.vr * steps);
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset.zero, width: p.size, height: p.size * p.aspect),
        Paint()..color = p.color.withOpacity(alpha),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PopperPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────
// Painter: 아마추어→세미프로 빔+링+파티클
// ─────────────────────────────────────────
class _RankedPainter extends CustomPainter {
  _RankedPainter({required this.progress});
  final double progress;

  static List<_Particle>? _particles;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.36;

    final cols = [
      const Color(0xFFC4B5FD),
      const Color(0xFFA78BFA),
      const Color(0xFFDDD6FE),
      Colors.white,
      const Color(0xFFF0ABFC),
    ];

    _particles ??= List.generate(60, (i) {
      final rng = Random(i + 100);
      final a = rng.nextDouble() * pi * 2;
      final spd = 2 + rng.nextDouble() * 5;
      return _Particle(
        ox: cx + (rng.nextDouble() - 0.5) * size.width * 0.6,
        oy: cy + (rng.nextDouble() - 0.5) * size.height * 0.3,
        vx: cos(a) * spd,
        vy: sin(a) * spd - 1.5,
        size: 2 + rng.nextDouble() * 4,
        aspect: 1,
        color: cols[rng.nextInt(cols.length)],
        rot: 0,
        vr: 0,
        delay: 0.25 + rng.nextDouble() * 0.35,
        isCircle: rng.nextDouble() > 0.3,
      );
    });

    final t = progress;

    // 빔
    final beamAlpha = t < 0.3
        ? t / 0.3
        : t < 0.6
            ? 1.0
            : (1 - (t - 0.6) / 0.4).clamp(0.0, 1.0);
    if (beamAlpha > 0) {
      for (int i = 0; i < 16; i++) {
        final a = (i / 16) * pi * 2;
        final len = size.width * 0.55 * min(1, t * 3);
        final p = Paint()
          ..color = const Color(0xFFA78BFA).withOpacity(beamAlpha * 0.18)
          ..strokeWidth = 5
          ..style = PaintingStyle.stroke;
        canvas.drawLine(
          Offset(cx, cy),
          Offset(cx + cos(a) * len, cy + sin(a) * len),
          p,
        );
      }
    }

    // 링
    for (int ri = 0; ri < 3; ri++) {
      final delay = ri * 0.12;
      if (t < delay) continue;
      final rt = ((t - delay) / 0.6).clamp(0.0, 1.0);
      final r = size.width * 0.55 * Curves.easeOut.transform(rt);
      final ringAlpha = (1 - rt).clamp(0.0, 1.0) * [1.0, 0.7, 0.5][ri];
      final ringColors = [
        const Color(0xFFA78BFA),
        const Color(0xFF7C3AED),
        const Color(0xFF4F46E5),
      ];
      canvas.drawCircle(
        Offset(cx, cy),
        r,
        Paint()
          ..color = ringColors[ri].withOpacity(ringAlpha)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
    }

    // 글로우
    if (t < 0.4) {
      final grd = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFA78BFA).withOpacity((0.4 - t) / 0.4 * 0.4),
            Colors.transparent,
          ],
        ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.4));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), grd);
    }

    // 파티클
    for (final p in _particles!) {
      if (t < p.delay) continue;
      final pt = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      final steps = pt * 55;
      final px = p.ox + p.vx * steps * pow(0.98, steps);
      final py = p.oy + p.vy * steps + 0.12 * steps * steps;
      double alpha = pt < 0.3 ? pt / 0.3 : 1.0;
      if (py > size.height * 0.65)
        alpha -= (py - size.height * 0.65) / (size.height * 0.15);
      alpha = alpha.clamp(0.0, 1.0);
      if (alpha <= 0) continue;

      if (p.isCircle) {
        canvas.drawCircle(Offset(px, py), p.size,
            Paint()..color = p.color.withOpacity(alpha));
      } else {
        canvas.save();
        canvas.translate(px, py);
        canvas.rotate(pt * pi);
        final r = p.size;
        final path = Path()
          ..moveTo(0, -r)
          ..lineTo(r * 0.4, -r * 0.4)
          ..lineTo(r, 0)
          ..lineTo(r * 0.4, r * 0.4)
          ..lineTo(0, r)
          ..lineTo(-r * 0.4, r * 0.4)
          ..lineTo(-r, 0)
          ..lineTo(-r * 0.4, -r * 0.4)
          ..close();
        canvas.drawPath(path, Paint()..color = p.color.withOpacity(alpha));
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_RankedPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────
// Painter: 세미프로→프로 골드 모퉁이 문양+파티클
// ─────────────────────────────────────────
class _GoldOrnamentPainter extends CustomPainter {
  _GoldOrnamentPainter({required this.progress});
  final double progress;

  static List<_Particle>? _particles;

  @override
  void paint(Canvas canvas, Size size) {
    _particles ??= _buildParticles(size);
    _drawCorners(canvas, size, Curves.easeInOut.transform(progress));
    _drawParticles(canvas, size);
  }

  static List<_Particle> _buildParticles(Size size) {
    final rng = Random(42);
    final cols = [
      const Color(0xFFFCD34D),
      const Color(0xFFFDE68A),
      Colors.white,
      const Color(0xFFF59E0B),
      const Color(0xFFFCA5A5),
      const Color(0xFFFEF3C7),
    ];
    return List.generate(90, (i) {
      final a = rng.nextDouble() * pi * 2;
      final spd = 0.8 + rng.nextDouble() * 4.5;
      final double ox, oy;
      if (rng.nextDouble() < 0.5) {
        ox = size.width / 2 + (rng.nextDouble() - 0.5) * size.width * 0.7;
        oy = size.height * 0.1 + rng.nextDouble() * size.height * 0.4;
      } else {
        ox = rng.nextBool()
            ? rng.nextDouble() * size.width * 0.25
            : size.width * 0.75 + rng.nextDouble() * size.width * 0.25;
        oy = rng.nextDouble() * size.height * 0.5;
      }
      return _Particle(
        ox: ox,
        oy: oy,
        vx: cos(a) * spd,
        vy: sin(a) * spd - 1.5,
        size: 1 + rng.nextDouble() * 3,
        aspect: rng.nextDouble() < 0.25 ? 0.5 : 1.0,
        color: cols[rng.nextInt(cols.length)],
        rot: rng.nextDouble() * pi * 2,
        vr: (rng.nextDouble() - 0.5) * 0.15,
        delay: 0.28 + rng.nextDouble() * 0.45,
        isCircle: rng.nextDouble() > 0.25,
      );
    });
  }

  void _drawCorners(Canvas canvas, Size size, double ep) {
    if (ep <= 0) return;
    final sz = min(size.width, size.height) * 0.26 * ep;
    final corners = [
      _CornerDef(x: 0, y: 0, sx: 1, sy: 1),
      _CornerDef(x: size.width, y: 0, sx: -1, sy: 1),
      _CornerDef(x: 0, y: size.height, sx: 1, sy: -1),
      _CornerDef(x: size.width, y: size.height, sx: -1, sy: -1),
    ];

    for (final c in corners) {
      canvas.save();
      canvas.translate(c.x, c.y);

      // 바깥 곡선
      canvas.drawPath(
        Path()
          ..moveTo(c.sx * sz * 0.08, c.sy * sz * 0.52)
          ..cubicTo(c.sx * sz * .08, c.sy * sz * .22, c.sx * sz * .22,
              c.sy * sz * .08, c.sx * sz * .52, c.sy * sz * .08),
        Paint()
          ..color = const Color(0xFFF59E0B).withOpacity(ep * 0.9)
          ..strokeWidth = 1.6
          ..style = PaintingStyle.stroke,
      );
      // 안쪽 곡선
      canvas.drawPath(
        Path()
          ..moveTo(c.sx * sz * .14, c.sy * sz * .44)
          ..cubicTo(c.sx * sz * .14, c.sy * sz * .26, c.sx * sz * .26,
              c.sy * sz * .14, c.sx * sz * .44, c.sy * sz * .14),
        Paint()
          ..color = const Color(0xFFFCD34D).withOpacity(ep * 0.55)
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke,
      );
      // 보조 호
      canvas.drawPath(
        Path()
          ..moveTo(c.sx * sz * .10, c.sy * sz * .32)
          ..quadraticBezierTo(c.sx * sz * .10, c.sy * sz * .10, c.sx * sz * .32,
              c.sy * sz * .10),
        Paint()
          ..color = const Color(0xFFFDE68A).withOpacity(ep * 0.3)
          ..strokeWidth = 0.7
          ..style = PaintingStyle.stroke,
      );
      // 끝 점
      for (final pt in [
        Offset(c.sx * sz * .08, c.sy * sz * .52),
        Offset(c.sx * sz * .52, c.sy * sz * .08),
      ]) {
        canvas.drawCircle(pt, 2.4 * ep,
            Paint()..color = const Color(0xFFFCD34D).withOpacity(ep));
      }
      // 다이아
      final ds = 4.5 * ep;
      final dmx = c.sx * sz * 0.08, dmy = c.sy * sz * 0.08;
      canvas.drawPath(
        Path()
          ..moveTo(dmx, dmy - ds * c.sy)
          ..lineTo(dmx + ds * c.sx, dmy)
          ..lineTo(dmx, dmy + ds * c.sy)
          ..lineTo(dmx - ds * c.sx, dmy)
          ..close(),
        Paint()..color = const Color(0xFFF59E0B).withOpacity(ep * 0.95),
      );
      // 틱
      final tp = Paint()
        ..color = const Color(0xFFFDE68A).withOpacity(ep * 0.45)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;
      for (final f in [0.27, 0.38]) {
        canvas.drawLine(Offset(c.sx * sz * f, c.sy * sz * .08),
            Offset(c.sx * sz * f, c.sy * sz * .15), tp);
        canvas.drawLine(Offset(c.sx * sz * .08, c.sy * sz * f),
            Offset(c.sx * sz * .15, c.sy * sz * f), tp);
      }
      // 엣지선
      final ep2 = Paint()
        ..color = const Color(0xFFF59E0B).withOpacity(ep * 0.28)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(c.sx * sz * .52, c.sy * sz * .08),
          Offset(c.sx * sz * 1.05, c.sy * sz * .08), ep2);
      canvas.drawLine(Offset(c.sx * sz * .08, c.sy * sz * .52),
          Offset(c.sx * sz * .08, c.sy * sz * 1.05), ep2);

      canvas.restore();
    }
  }

  void _drawParticles(Canvas canvas, Size size) {
    for (final p in _particles!) {
      if (progress < p.delay) continue;
      final t = ((progress - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      final steps = t * 60;
      final px = p.ox + p.vx * steps * _powDouble(0.98, steps);
      final py = p.oy + p.vy * steps + 0.07 * steps * steps;
      double alpha = t < 0.3 ? t / 0.3 : 1.0;
      if (py > size.height * 0.75)
        alpha -= (py - size.height * 0.75) / (size.height * 0.15);
      alpha = alpha.clamp(0.0, 1.0);
      if (alpha <= 0) continue;

      if (p.isCircle) {
        canvas.drawCircle(Offset(px, py), p.size,
            Paint()..color = p.color.withOpacity(alpha));
      } else {
        canvas.save();
        canvas.translate(px, py);
        canvas.rotate(p.rot + p.vr * steps);
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero,
              width: p.size * 2,
              height: p.size * p.aspect),
          Paint()..color = p.color.withOpacity(alpha),
        );
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(_GoldOrnamentPainter old) => old.progress != progress;
}

// ─────────────────────────────────────────
// 공통 데이터 클래스
// ─────────────────────────────────────────
class _Particle {
  const _Particle({
    required this.ox,
    required this.oy,
    required this.vx,
    required this.vy,
    required this.size,
    required this.aspect,
    required this.color,
    required this.rot,
    required this.vr,
    required this.delay,
    this.isCircle = false,
  });
  final double ox, oy, vx, vy, size, aspect, rot, vr, delay;
  final Color color;
  final bool isCircle;
}

class _CornerDef {
  const _CornerDef({
    required this.x,
    required this.y,
    required this.sx,
    required this.sy,
  });
  final double x, y, sx, sy;
}

class _SpringCurve extends Curve {
  const _SpringCurve();
  @override
  double transformInternal(double t) {
    return 1 - _powDouble(1 - t, 3) * cos(t * pi * 2.5);
  }
}
