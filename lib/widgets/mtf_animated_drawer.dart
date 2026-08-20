import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'premium_banner_widget.dart';

const Color _kPrimary = AppColors.deepNavy;
const Color _kPrimary2 = Color(0xFF163A54);

// 상단은 흐릿하게, 측면/하단은 진하게
const Color _kNeonStart = Color(0x55EFCB62);
const Color _kNeonMid = AppColors.warmYellow;
const Color _kNeonEnd = AppColors.goldLight;
const Color _kNeonGlow = AppColors.warmYellow;

// LIVE 포인트
const Color _kLiveDot = Color(0xFFDC2626);

// ════════════════════════════════════════════════════════════════════════════════
//  진입점
// ════════════════════════════════════════════════════════════════════════════════
class MtfAnimatedDrawer extends StatelessWidget {
  const MtfAnimatedDrawer({
    super.key,
    required this.trainerName,
    required this.shortName,
    required this.tierName,
    required this.memberCount,
    required this.bannerData,
    this.onMyPage,
    this.onMembers,
    this.onContract,
    this.onMembershipContract,
    this.onStats,
    this.onSettings,
    this.onUpgrade,
    this.onGoods,
    this.onLiveBeta,
  });

  final String trainerName;
  final String shortName;
  final String tierName;
  final int memberCount;
  final PremiumBannerData bannerData;

  final VoidCallback? onMyPage;
  final VoidCallback? onMembers;
  final VoidCallback? onContract;
  final VoidCallback? onMembershipContract;
  final VoidCallback? onStats;
  final VoidCallback? onSettings;
  final VoidCallback? onUpgrade;
  final VoidCallback? onGoods;
  final VoidCallback? onLiveBeta;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    // 패널 너비: 화면의 72%, 최소 280, 최대 340
    final panelWidth = (screenWidth * 0.58).clamp(248.0, 290.0);

    return Drawer(
      width: screenWidth,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        children: [
          // ── 배경 딤 + 블러 ──────────────────────────────────────────────────
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox.expand(),
            ),
          ),

          // ── 글래스 패널 (오른쪽 엣지에 완전히 붙임) ──────────────────────
          Positioned(
            top: safeTop + 10,
            right: 0,
            bottom: safeBottom + 52,
            width: panelWidth,
            child: _MtfGlassPanel(
              panelWidth: panelWidth,
              trainerName: trainerName,
              shortName: shortName,
              tierName: tierName,
              memberCount: memberCount,
              bannerData: bannerData,
              onMyPage: onMyPage,
              onMembers: onMembers,
              onContract: onContract,
              onMembershipContract: onMembershipContract,
              onStats: onStats,
              onSettings: onSettings,
              onUpgrade: onUpgrade,
              onGoods: onGoods,
              onLiveBeta: onLiveBeta,
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
//  글래스 패널 본체
// ════════════════════════════════════════════════════════════════════════════════
class _MtfGlassPanel extends StatefulWidget {
  const _MtfGlassPanel({
    required this.panelWidth,
    required this.trainerName,
    required this.shortName,
    required this.tierName,
    required this.memberCount,
    required this.bannerData,
    this.onMyPage,
    this.onMembers,
    this.onContract,
    this.onMembershipContract,
    this.onStats,
    this.onSettings,
    this.onUpgrade,
    this.onGoods,
    this.onLiveBeta,
  });

  final double panelWidth;
  final String trainerName;
  final String shortName;
  final String tierName;
  final int memberCount;
  final PremiumBannerData bannerData;

  final VoidCallback? onMyPage;
  final VoidCallback? onMembers;
  final VoidCallback? onContract;
  final VoidCallback? onMembershipContract;
  final VoidCallback? onStats;
  final VoidCallback? onSettings;
  final VoidCallback? onUpgrade;
  final VoidCallback? onGoods;
  final VoidCallback? onLiveBeta;

  @override
  State<_MtfGlassPanel> createState() => _MtfGlassPanelState();
}

class _MtfGlassPanelState extends State<_MtfGlassPanel>
    with TickerProviderStateMixin {
  // L자 네온라인 (왼쪽 + 하단)
  late final AnimationController _neonCtrl;
  late final Animation<double> _neonAnim;

  @override
  void initState() {
    super.initState();

    _neonCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _neonAnim = CurvedAnimation(
      parent: _neonCtrl,
      curve: Curves.easeOutCubic,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSequence();
    });
  }

  @override
  void dispose() {
    _neonCtrl.dispose();
    super.dispose();
  }

  void _startSequence() {
    _neonCtrl.forward(from: 0);
  }

  Animation<double> _staggerAnim(int ignoredIndex) {
    return const AlwaysStoppedAnimation<double>(1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _neonAnim,
      child: _buildBody(),
      builder: (context, child) {
        return Stack(
          children: [
            // ── 패널 본체 ────────────────────────────────────────────────
            child!,

            // ── L자 네온라인 (왼쪽 + 하단) ──────────────────────────────
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _LNeonPainter(
                    progress: _neonAnim.value,
                    startColor: _kNeonStart,
                    midColor: _kNeonMid,
                    endColor: _kNeonEnd,
                    glowColor: _kNeonGlow,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody() {
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final tokens = context.mtfThemeTokens;

    return Container(
      decoration: BoxDecoration(
        color: tokens.drawerBackground,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(26),
          bottomLeft: Radius.circular(26),
        ),
        border: Border(
          left: BorderSide(color: tokens.cardBorder, width: 0.8),
        ),
        boxShadow: [
          // 왼쪽으로 깊게 떨어지는 메인 그림자
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 34,
            spreadRadius: 0,
            offset: const Offset(-14, 10),
          ),
          // 퍼플 톤 보조 그림자
          BoxShadow(
            color: _kPrimary.withOpacity(0.12),
            blurRadius: 28,
            spreadRadius: 0,
            offset: const Offset(-8, 4),
          ),
        ],
      ),
      child: SafeArea(
        right: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 프로필 헤더 ────────────────────────────────────────────────
            _buildProfile(_staggerAnim(0)),

            const SizedBox(height: 2),

            // ── 미니 배너 ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: FadeTransition(
                opacity: _staggerAnim(1),
                child: PremiumMiniBanner(
                  data: widget.bannerData,
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onUpgrade?.call();
                  },
                ),
              ),
            ),

            const SizedBox(height: 8),
            _buildDivider(),
            const SizedBox(height: 6),

            // ── 메뉴 목록 ──────────────────────────────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
                child: Column(
                  children: [
                    _buildMenuItem(
                      index: 2,
                      icon: Icons.people_outline_rounded,
                      label: '고객카드',
                      sub: '회원 정보 확인 및 관리 지원',
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onMembers?.call();
                      },
                    ),
                    _buildMenuItem(
                      index: 3,
                      icon: Icons.description_outlined,
                      label: '레슨계약서',
                      sub: '레슨 계약서 작성 및 운영 지원',
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onContract?.call();
                      },
                    ),
                    _buildMenuItem(
                      index: 4,
                      icon: Icons.assignment_outlined,
                      label: '회원권계약서',
                      sub: '회원권 계약서 작성 및 운영 지원',
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onMembershipContract?.call();
                      },
                    ),
                    _buildMenuItem(
                      index: 5,
                      icon: Icons.bar_chart_rounded,
                      label: '인사이트',
                      sub: '레슨 및 회원 운영 분석 지원',
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onStats?.call();
                      },
                    ),

                    // 개발 중 항목 — 글리치 스타일
                    _buildGlitchMenuItem(
                      index: 6,
                      icon: Icons.design_services_outlined,
                      label: '브랜딩 굿즈',
                      sub: '퍼스널 브랜딩 굿즈를 만들어보세요',
                      onTap: () {
                        Navigator.of(context).pop();
                        widget.onGoods?.call();
                      },
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
              child: _buildLiveCard(_staggerAnim(6)),
            ),

            _buildDivider(),

            Padding(
              padding: const EdgeInsets.fromLTRB(10, 1, 10, 4),
              child: FadeTransition(
                opacity: _staggerAnim(7),
                child: _buildFooterItem(
                  icon: Icons.settings_outlined,
                  label: '설정',
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.onSettings?.call();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 프로필 ────────────────────────────────────────────────────────────────────
  Widget _buildProfile(Animation<double> anim) {
    final theme = Theme.of(context);
    final tokens = context.mtfThemeTokens;

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.06, 0),
          end: Offset.zero,
        ).animate(anim),
        child: ColoredBox(
          color: tokens.drawerHeaderBackground,
          child: InkWell(
            onTap: () {
              Navigator.of(context).pop();
              widget.onMyPage?.call();
            },
            overlayColor: WidgetStatePropertyAll(
              tokens.drawerSelectedBackground.withOpacity(0.18),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              child: Row(
                children: [
                  // 아바타
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [_kPrimary, _kPrimary2],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.20),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.shortName.isEmpty ? '강' : widget.shortName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.trainerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    tokens.gradeSheetAccent.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color:
                                      tokens.gradeSheetAccent.withOpacity(0.36),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                widget.tierName,
                                style: TextStyle(
                                  color: tokens.gradeSheetAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '회원 ${widget.memberCount}명',
                              style: TextStyle(
                                color: theme.colorScheme.onPrimary
                                    .withOpacity(0.72),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: theme.colorScheme.onPrimary.withOpacity(0.72),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 일반 메뉴 아이템 ──────────────────────────────────────────────────────────
  Widget _buildMenuItem({
    required int index,
    required IconData icon,
    required String label,
    required String sub,
    required VoidCallback onTap,
  }) {
    final anim = _staggerAnim(index);
    final theme = Theme.of(context);
    final tokens = context.mtfThemeTokens;

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(anim),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          overlayColor: WidgetStatePropertyAll(
            tokens.drawerSelectedBackground.withOpacity(0.55),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: Row(
              children: [
                Container(
                  width: 31,
                  height: 31,
                  decoration: BoxDecoration(
                    color: tokens.cardSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: tokens.cardBorder,
                      width: 0.5,
                    ),
                  ),
                  child: Icon(icon, color: theme.colorScheme.primary, size: 17),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  size: 17,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 개발 중 메뉴 아이템 (글리치 스타일) ───────────────────────────────────────
  Widget _buildGlitchMenuItem({
    required int index,
    required IconData icon,
    required String label,
    required String sub,
    required VoidCallback onTap,
  }) {
    final anim = _staggerAnim(index);

    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(anim),
        child: _GlitchMenuTile(
          icon: icon,
          label: label,
          sub: sub,
          onTap: onTap,
        ),
      ),
    );
  }

  // ── LIVE 카드 ─────────────────────────────────────────────────────────────────
  Widget _buildLiveCard(Animation<double> anim) {
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.05, 0),
          end: Offset.zero,
        ).animate(anim),
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop();
            widget.onLiveBeta?.call();
          },
          borderRadius: BorderRadius.circular(13),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              // 에너제틱 오렌지 다크 배경
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1A0800).withOpacity(0.9),
                  const Color(0xFF2D1200).withOpacity(0.9),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: const Color(0xFFF97316).withOpacity(0.22),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                // 파형 아이콘
                SizedBox(
                  width: 34,
                  height: 34,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: List.generate(5, (i) {
                      return _WaveBar(
                        index: i,
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _kLiveDot.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _kLiveDot.withOpacity(0.30),
                                width: 0.5,
                              ),
                            ),
                            child: const Text(
                              'LIVE',
                              style: TextStyle(
                                color: _kLiveDot,
                                fontSize: 8.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Text(
                            'BETA',
                            style: TextStyle(
                              color: Color(0xFFF97316),
                              fontSize: 8.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'MORE WELLNESS 회원관리',
                        style: TextStyle(
                          color: Color(0xFFFED7AA),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '회원 관리 화면으로 이동',
                        style: TextStyle(
                          color: Color(0xFFFDBA74),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: const Color(0xFFF97316).withOpacity(0.5),
                  size: 17,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 0.5,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: context.mtfThemeTokens.cardBorder,
    );
  }

  Widget _buildFooterItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
//  파형 막대 위젯
// ════════════════════════════════════════════════════════════════════════════════
class _WaveBar extends StatefulWidget {
  const _WaveBar({required this.index});
  final int index;

  @override
  State<_WaveBar> createState() => _WaveBarState();
}

class _WaveBarState extends State<_WaveBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  static const List<double> _baseHeights = [6, 14, 20, 12, 16];
  static const List<int> _delays = [0, 120, 240, 360, 480];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    Future.delayed(Duration(milliseconds: _delays[widget.index]), () {
      if (mounted) _ctrl.repeat(reverse: true);
    });

    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final baseH = _baseHeights[widget.index];

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final h = baseH * _anim.value;
        return Container(
          width: 3,
          height: h,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xFFF97316), Color(0xFFFBBF24)],
            ),
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
//  글리치 메뉴 타일 (개발 중 항목)
// ════════════════════════════════════════════════════════════════════════════════
class _GlitchMenuTile extends StatefulWidget {
  const _GlitchMenuTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback onTap;

  @override
  State<_GlitchMenuTile> createState() => _GlitchMenuTileState();
}

class _GlitchMenuTileState extends State<_GlitchMenuTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shakeAnim;
  bool _glitching = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -4, end: 4), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 4, end: -3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -3, end: 3), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 3, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() => _glitching = true);
    _ctrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _glitching = false);
    });
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.mtfThemeTokens;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _shakeAnim,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_shakeAnim.value, 0),
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  // 스캔라인 효과로 "미완성" 느낌
                  color: tokens.cardSurface.withOpacity(0.72),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: tokens.cardBorder,
                    width: 0.5,
                  ),
                ),
                child: Icon(
                  widget.icon,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.55),
                  size: 17,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        color: theme.colorScheme.onSurface.withOpacity(0.45),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: tokens.drawerSelectedBackground
                                .withOpacity(0.24),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: tokens.cardBorder,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '소규모 퍼스널 브랜딩 굿즈',
                            style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.lock_outline_rounded,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
//  L자 네온라인 Painter — 왼쪽(위→아래) + 하단(왼→오른)
// ════════════════════════════════════════════════════════════════════════════════
class _LNeonPainter extends CustomPainter {
  const _LNeonPainter({
    required this.progress,
    required this.startColor,
    required this.midColor,
    required this.endColor,
    required this.glowColor,
  });

  final double progress;
  final Color startColor;
  final Color midColor;
  final Color endColor;
  final Color glowColor;

  // L자 총 길이에서 왼쪽 세로가 차지하는 비율
  static const double _verticalRatio = 0.65;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final double w = size.width;
    final double h = size.height;

    // 패널 radius가 현재 topLeft/bottomLeft 26이므로 동일하게 맞춤
    const double radius = 26.0;

    // 선을 너무 안쪽으로 넣으면 라인이 안 맞아 보이므로
    // strokeWidth 3.2 기준 절반 정도만 안쪽으로 넣음
    const double stroke = 2.8;
    const double inset = stroke / 2;

    final double p = progress.clamp(0.0, 1.0).toDouble();

    // 초반 10%에서만 빠르게 보이게 하고 이후에는 선명도 고정
    // 그래서 "얇았다가 갑자기 두꺼워지는" 느낌이 줄어듦
    final double alpha = p < 0.10 ? p / 0.10 : 1.0;

    // 오른쪽 상단 → 왼쪽 상단 → 왼쪽 하단 → 하단 오른쪽
    // 오른쪽은 radius가 없는 엣지라서 w - inset에서 시작/종료
    final fullPath = Path()
      ..moveTo(w - inset, inset)
      ..lineTo(radius, inset)
      ..quadraticBezierTo(inset, inset, inset, radius)
      ..lineTo(inset, h - radius)
      ..quadraticBezierTo(inset, h - inset, radius, h - inset)
      ..lineTo(w - inset, h - inset);

    final metrics = fullPath.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final totalLength = metrics.fold<double>(
      0.0,
      (sum, metric) => sum + metric.length,
    );

    final drawLength = totalLength * p;

    final extractedPath = Path();
    double remaining = drawLength;

    for (final metric in metrics) {
      if (remaining <= 0) break;

      final segmentLength = math.min(remaining, metric.length);
      extractedPath.addPath(
        metric.extractPath(0, segmentLength),
        Offset.zero,
      );

      remaining -= segmentLength;
    }

    // 그라데이션은 상단→왼쪽→하단 흐름에 맞게 부드럽게
    final shader = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomRight,
      colors: [
        startColor,
        midColor.withOpacity(0.90),
        midColor,
        endColor,
      ],
      stops: const [0.0, 0.32, 0.68, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    final glowShader = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomRight,
      colors: [
        glowColor.withOpacity(0.06 * alpha),
        glowColor.withOpacity(0.18 * alpha),
        glowColor.withOpacity(0.28 * alpha),
        glowColor.withOpacity(0.34 * alpha),
      ],
      stops: const [0.0, 0.34, 0.72, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    final midGlowShader = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomRight,
      colors: [
        midColor.withOpacity(0.08 * alpha),
        midColor.withOpacity(0.22 * alpha),
        midColor.withOpacity(0.34 * alpha),
        midColor.withOpacity(0.42 * alpha),
      ],
      stops: const [0.0, 0.34, 0.72, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    // 외곽 글로우 — 너무 두껍지 않게
    canvas.drawPath(
      extractedPath,
      Paint()
        ..shader = glowShader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // 중간 글로우 — 메인선 주변만 살짝
    canvas.drawPath(
      extractedPath,
      Paint()
        ..shader = midGlowShader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );

    // 메인 네온선 — 네가 좋다고 한 3.2 고정
    canvas.drawPath(
      extractedPath,
      Paint()
        ..shader = shader
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_LNeonPainter old) => old.progress != progress;
}
