import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// ── 등급 enum ─────────────────────────────────────────────────────────────────
enum AppTier { beginner, amateur, semiPro, pro, master, grandPrix }

extension AppTierExt on AppTier {
  String get label {
    switch (this) {
      case AppTier.beginner:
        return 'Beginner';
      case AppTier.amateur:
        return 'Amateur';
      case AppTier.semiPro:
        return 'Semi-Pro';
      case AppTier.pro:
        return 'Pro';
      case AppTier.master:
        return 'Master';
      case AppTier.grandPrix:
        return 'Grand Prix';
    }
  }

  bool get showBanner =>
      this == AppTier.beginner ||
      this == AppTier.amateur ||
      this == AppTier.semiPro ||
      this == AppTier.pro;
}

// ── 배너 데이터 ────────────────────────────────────────────────────────────────
class PremiumBannerData {
  const PremiumBannerData({
    required this.currentTier,
    required this.isSponsor,
    this.scheduleCount = 0,
    this.memberCount = 0,
    this.trainerInfoDone = false,
    this.accountLinked = false,
    this.requiresLinkedAccount = false,
    this.hasProduct = false,
  });

  final AppTier currentTier;
  final bool isSponsor;
  final int scheduleCount;
  final int memberCount;
  final bool trainerInfoDone;
  final bool accountLinked;
  final bool requiresLinkedAccount;
  final bool hasProduct;
}

// ── 메인 배너 위젯 (풀사이즈) ──────────────────────────────────────────────────
class PremiumBannerWidget extends StatefulWidget {
  const PremiumBannerWidget({
    super.key,
    required this.data,
    required this.onTap,
  });

  final PremiumBannerData data;
  final VoidCallback onTap;

  @override
  State<PremiumBannerWidget> createState() => _PremiumBannerWidgetState();
}

class _PremiumBannerWidgetState extends State<PremiumBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    if (!data.currentTier.showBanner || data.isSponsor) {
      return const SizedBox.shrink();
    }

    switch (data.currentTier) {
      case AppTier.beginner:
        return _BeginnerBanner(
          data: data,
          pulseAnim: _pulseAnim,
          onTap: widget.onTap,
        );
      case AppTier.amateur:
        return _AmateurBanner(
          data: data,
          pulseAnim: _pulseAnim,
          onTap: widget.onTap,
        );
      case AppTier.semiPro:
        return _SemiProBanner(data: data, onTap: widget.onTap);
      case AppTier.pro:
        return _ProBanner(onTap: widget.onTap);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── 미니 배너 위젯 (드로어용) ──────────────────────────────────────────────────
class PremiumMiniBanner extends StatelessWidget {
  const PremiumMiniBanner({
    super.key,
    required this.data,
    required this.onTap,
  });

  final PremiumBannerData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!data.currentTier.showBanner || data.isSponsor) {
      return const SizedBox.shrink();
    }

    switch (data.currentTier) {
      case AppTier.beginner:
        return _MiniBeginner(onTap: onTap);
      case AppTier.amateur:
        return _MiniAmateur(onTap: onTap);
      case AppTier.semiPro:
        return _MiniSemiPro(onTap: onTap);
      case AppTier.pro:
        return _MiniPro(onTap: onTap);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ── 미니 공용 레이아웃 ─────────────────────────────────────────────────────────
class _MiniLayout extends StatelessWidget {
  const _MiniLayout({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.titleColor,
    required this.subText,
    required this.subColor,
    required this.bg,
    this.bgGradient,
    this.border,
    this.gloss = false,
    required this.btnLabel,
    required this.btnTextColor,
    required this.btnBg,
    this.btnBorder,
    required this.onTap,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final String subText;
  final Color subColor;
  final Color bg;
  final Gradient? bgGradient;
  final Border? border;
  final bool gloss;
  final String btnLabel;
  final Color btnTextColor;
  final Color btnBg;
  final Border? btnBorder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.donationSurface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: tokens.donationAccent.withOpacity(0.35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // 광택 오버레이
            if (gloss)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 22,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: tokens.donationAccent.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          icon,
                          color: tokens.donationAccent,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.donationForeground,
                                fontSize: 12.2,
                                fontWeight: FontWeight.w900,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    tokens.donationForeground.withOpacity(0.70),
                                fontSize: 10.3,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: GestureDetector(
                      onTap: onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.donationAccent,
                          borderRadius: BorderRadius.circular(999),
                          border: btnBorder,
                        ),
                        child: Text(
                          btnLabel,
                          style: TextStyle(
                            color: scheme.onSecondary,
                            fontSize: 10.8,
                            fontWeight: FontWeight.w900,
                          ),
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
}

// ── 미니 Beginner — 골드 ───────────────────────────────────────────────────────
class _MiniBeginner extends StatelessWidget {
  const _MiniBeginner({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _MiniLayout(
      icon: Icons.rocket_launch_rounded,
      iconBg: Colors.black.withOpacity(0.10),
      iconColor: const Color(0xFF7A5C00),
      title: '고객카드로 섬세하게',
      titleColor: const Color(0xFF1A1200),
      subText: 'Amateur 달성까지 조금 더 남았어요',
      subColor: Colors.black.withOpacity(0.42),
      bg: const Color(0xFFFFD700),
      bgGradient: const LinearGradient(
        colors: [Color(0xFFE6B800), Color(0xFFFFD700), Color(0xFFFFE500)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      gloss: true,
      btnLabel: '후원하기',
      btnTextColor: const Color(0xFFFFD700),
      btnBg: const Color(0xFF1A1200),
      onTap: onTap,
    );
  }
}

// ── 미니 Amateur — 오렌지 ─────────────────────────────────────────────────────
class _MiniAmateur extends StatelessWidget {
  const _MiniAmateur({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _MiniLayout(
      icon: Icons.groups_rounded,
      iconBg: Colors.white.withOpacity(0.20),
      iconColor: Colors.white,
      title: '계약서로 더 체계적이게',
      titleColor: Colors.white,
      subText: 'Semi-Pro 달성을 응원해주세요',
      subColor: Colors.white.withOpacity(0.65),
      bg: const Color(0xFFFF5500),
      bgGradient: const LinearGradient(
        colors: [Color(0xFFFF5500), Color(0xFFFF7A00), Color(0xFFFFAA00)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      gloss: true,
      btnLabel: '후원하기',
      btnTextColor: const Color(0xFFFF5500),
      btnBg: Colors.white,
      onTap: onTap,
    );
  }
}

// ── 미니 Semi-Pro — 오렌지 희석 ───────────────────────────────────────────────
class _MiniSemiPro extends StatelessWidget {
  const _MiniSemiPro({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _MiniLayout(
      icon: Icons.bar_chart_rounded,
      iconBg: const Color(0xFFFF5500).withOpacity(0.12),
      iconColor: const Color(0xFFFF5500),
      title: '강화된 AI기능으로 확실하게',
      titleColor: const Color(0xFF111827),
      subText: 'Pro 달성까지 응원이 필요해요',
      subColor: const Color(0xFF9CA3AF),
      bg: Colors.transparent,
      bgGradient: LinearGradient(
        colors: [
          const Color(0xFFFF5500).withOpacity(0.10),
          const Color(0xFFFFAA00).withOpacity(0.06),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      border: Border.all(
        color: const Color(0xFFFF5500).withOpacity(0.18),
      ),
      btnLabel: '후원하기',
      btnTextColor: const Color(0xFFFF5500),
      btnBg: const Color(0xFFFF5500).withOpacity(0.08),
      btnBorder: Border.all(
        color: const Color(0xFFFF5500).withOpacity(0.22),
      ),
      onTap: onTap,
    );
  }
}

// ── 미니 Pro — 흰 카드 ────────────────────────────────────────────────────────
class _MiniPro extends StatelessWidget {
  const _MiniPro({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _MiniLayout(
      icon: Icons.favorite_rounded,
      iconBg: const Color(0xFFFF6B00).withOpacity(0.08),
      iconColor: const Color(0xFFFF6B00),
      title: '섬세하고 체계적인 관리',
      titleColor: const Color(0xFF6B7280),
      subText: '선택후원 · 등급 혜택 보기',
      subColor: const Color(0xFF9CA3AF),
      bg: Colors.white,
      border: Border.all(color: const Color(0xFFE5E7EB)),
      btnLabel: '후원',
      btnTextColor: const Color(0xFFFF6B00),
      btnBg: Colors.transparent,
      btnBorder: Border.all(
        color: const Color(0xFFFF6B00).withOpacity(0.28),
      ),
      onTap: onTap,
    );
  }
}

// ── Beginner 배너 — 형광 옐로우 + pulse ───────────────────────────────────────
class _BeginnerBanner extends StatelessWidget {
  const _BeginnerBanner({
    required this.data,
    required this.pulseAnim,
    required this.onTap,
  });

  final PremiumBannerData data;
  final Animation<double> pulseAnim;
  final VoidCallback onTap;

  int get _doneCount =>
      (data.scheduleCount >= 10 ? 1 : 0) + (data.trainerInfoDone ? 1 : 0);
  int get _totalCount => 2;
  double get _progress => _doneCount / _totalCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (context, child) {
        final glow = pulseAnim.value;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: tokens.donationAccent.withOpacity(0.20 + glow * 0.18),
                  blurRadius: 16 + glow * 20,
                  spreadRadius: glow * 4,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                tokens.donationSurface,
                Color.alphaBlend(
                  tokens.donationAccent.withOpacity(0.12),
                  tokens.donationSurface,
                ),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: tokens.donationAccent.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.rocket_launch_rounded,
                      color: tokens.donationAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('첫 10개의 레슨을 등록하고\nAmateur로 성장해보세요',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: tokens.donationForeground,
                                height: 1.45)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Amateur 달성까지',
                      style: TextStyle(
                          fontSize: 10.5,
                          color: tokens.donationForeground.withOpacity(0.66))),
                  Text('$_doneCount / $_totalCount 완료',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: tokens.donationAccent)),
                ],
              ),
              const SizedBox(height: 5),
              _ShimmerProgressBar(
                progress: _progress,
                trackColor: tokens.donationForeground.withOpacity(0.14),
                fillColor: tokens.donationProgress,
                shimmerColor: Colors.white.withOpacity(0.6),
                shimmerDuration: const Duration(milliseconds: 1400),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '레슨 일정 ${data.scheduleCount} / 10 · 선생님 정보 입력',
                      style: TextStyle(
                          fontSize: 10.5,
                          color: tokens.donationForeground.withOpacity(0.66)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _BannerButton(
                    label: '후원하기',
                    textColor: scheme.onSecondary,
                    bgColor: tokens.donationAccent,
                    onTap: onTap,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Amateur 배너 ───────────────────────────────────────────────────────────────
class _AmateurBanner extends StatelessWidget {
  const _AmateurBanner({
    required this.data,
    required this.pulseAnim,
    required this.onTap,
  });

  final PremiumBannerData data;
  final Animation<double> pulseAnim;
  final VoidCallback onTap;

  double get _progress => (data.memberCount / 30).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (context, child) {
        return GestureDetector(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: tokens.donationAccent
                      .withOpacity(0.18 + pulseAnim.value * 0.16),
                  blurRadius: 14 + pulseAnim.value * 14,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    tokens.donationSurface,
                    Color.alphaBlend(
                      tokens.donationAccent.withOpacity(0.12),
                      tokens.donationSurface,
                    ),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 56,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: tokens.donationAccent.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: Icon(
                          Icons.groups_rounded,
                          color: tokens.donationAccent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('계약서로 레슨을\n더 단단하게 관리해보세요',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    color: tokens.donationForeground,
                                    height: 1.45)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Semi-Pro 달성까지',
                          style: TextStyle(
                              fontSize: 10.5,
                              color:
                                  tokens.donationForeground.withOpacity(0.72))),
                      Text('${data.memberCount} / 30명',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: tokens.donationAccent)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  _ShimmerProgressBar(
                    progress: _progress,
                    trackColor: tokens.donationForeground.withOpacity(0.14),
                    fillColor: tokens.donationProgress,
                    shimmerColor: Colors.white.withOpacity(0.9),
                    shimmerDuration: const Duration(milliseconds: 1600),
                    glowColor: tokens.donationProgress,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '작은 후원으로 모어댄의 멋진 한걸음을 응원해주세요',
                          style: TextStyle(
                              fontSize: 10.5,
                              color:
                                  tokens.donationForeground.withOpacity(0.72)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _BannerButton(
                        label: '후원하기',
                        textColor: scheme.onSecondary,
                        bgColor: tokens.donationAccent,
                        onTap: onTap,
                      ),
                    ],
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

// ── Semi-Pro 배너 ──────────────────────────────────────────────────────────────
class _SemiProBanner extends StatelessWidget {
  const _SemiProBanner({required this.data, required this.onTap});

  final PremiumBannerData data;
  final VoidCallback onTap;

  double get _progress => (data.memberCount / 50).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            colors: [
              tokens.donationSurface,
              Color.alphaBlend(
                tokens.donationAccent.withOpacity(0.10),
                tokens.donationSurface,
              ),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: tokens.donationAccent.withOpacity(0.30),
          ),
        ),
        padding: const EdgeInsets.all(13),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: tokens.donationAccent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.bar_chart_rounded,
                    color: tokens.donationAccent,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text('더 강화된 AI 기능과\n체계적인 관리 시스템을 써보세요',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          color: tokens.donationForeground,
                          height: 1.45)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Pro 달성까지',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: tokens.donationForeground.withOpacity(0.70),
                    )),
                Text('${data.memberCount} / 50명',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: tokens.donationAccent)),
              ],
            ),
            const SizedBox(height: 5),
            _ShimmerProgressBar(
              progress: _progress,
              trackColor: tokens.donationForeground.withOpacity(0.12),
              fillColor: tokens.donationProgress,
              shimmerColor: Colors.white.withOpacity(0.5),
              shimmerDuration: const Duration(milliseconds: 2800),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '작은 후원으로 모어댄의 멋진 한걸음을 응원해주세요',
                    style: TextStyle(
                      fontSize: 10,
                      color: tokens.donationForeground.withOpacity(0.66),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _BannerButton(
                  label: '후원하기',
                  textColor: scheme.onSecondary,
                  bgColor: tokens.donationAccent,
                  borderColor: tokens.donationAccent,
                  onTap: onTap,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pro 배너 ───────────────────────────────────────────────────────────────────
class _ProBanner extends StatelessWidget {
  const _ProBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.mtfThemeTokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: tokens.donationSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.donationAccent.withOpacity(0.30)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Icon(
              Icons.volunteer_activism_rounded,
              size: 16,
              color: tokens.donationAccent,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '작은 후원으로 모어댄의 멋진 한걸음을 응원해주세요',
                style: TextStyle(
                    fontSize: 11.5,
                    color: tokens.donationForeground,
                    height: 1.4),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: tokens.donationAccent,
                  border: Border.all(color: tokens.donationAccent),
                ),
                child: Text('후원',
                    style: TextStyle(
                        fontSize: 10.5,
                        color: scheme.onSecondary,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shimmer 진행도 바 ──────────────────────────────────────────────────────────
class _ShimmerProgressBar extends StatefulWidget {
  const _ShimmerProgressBar({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.shimmerColor,
    required this.shimmerDuration,
    this.glowColor,
  });

  final double progress;
  final Color trackColor;
  final Color fillColor;
  final Color shimmerColor;
  final Duration shimmerDuration;
  final Color? glowColor;

  @override
  State<_ShimmerProgressBar> createState() => _ShimmerProgressBarState();
}

class _ShimmerProgressBarState extends State<_ShimmerProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.shimmerDuration)
      ..repeat();
    _anim = Tween<double>(begin: -1.0, end: 2.0).animate(
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
    return SizedBox(
      height: 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          children: [
            Container(color: widget.trackColor),
            FractionallySizedBox(
              widthFactor: widget.progress,
              child: AnimatedBuilder(
                animation: _anim,
                builder: (context, _) {
                  return Container(
                    decoration: BoxDecoration(
                      color: widget.fillColor,
                      boxShadow: widget.glowColor != null
                          ? [
                              BoxShadow(
                                color: widget.glowColor!.withOpacity(0.7),
                                blurRadius: 8,
                              )
                            ]
                          : null,
                      gradient: LinearGradient(
                        stops: [
                          (_anim.value - 0.3).clamp(0.0, 1.0),
                          _anim.value.clamp(0.0, 1.0),
                          (_anim.value + 0.3).clamp(0.0, 1.0),
                        ],
                        colors: [
                          widget.fillColor,
                          widget.shimmerColor,
                          widget.fillColor,
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 공용 버튼 ──────────────────────────────────────────────────────────────────
class _BannerButton extends StatelessWidget {
  const _BannerButton({
    required this.label,
    required this.textColor,
    required this.bgColor,
    required this.onTap,
    this.borderColor,
  });

  final String label;
  final Color textColor;
  final Color bgColor;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(999),
          border: borderColor != null ? Border.all(color: borderColor!) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w700, color: textColor)),
      ),
    );
  }
}
