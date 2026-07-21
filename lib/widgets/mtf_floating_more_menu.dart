import 'dart:math' as math;
import 'package:flutter/material.dart';

const Color _kMoreBg = Color(0xFFEDEFFA);
const Color _kMoreText = Color(0xFF111827);
const Color _kMoreSubText = Color(0xFF6B7280);
const Color _kMoreBorder = Color(0xFFD8D5EA);
const Color _kMoreIconBg = Color(0xFFFFFFFF);
const Color _kMoreIconBorder = Color(0xFFDAD7EE);
const Color _kMorePrimary = Color(0xFF4F46E5);
const Color _kMoreNeonStart = Color(0x554F46E5);
const Color _kMoreNeonMid = Color(0xFF5B21B6);
const Color _kMoreNeonEnd = Color(0xFF7C3AED);
const Color _kMoreNeonGlow = Color(0xFF7C3AED);

class MtfMoreMenuItem<T> {
  const MtfMoreMenuItem({
    required this.value,
    required this.icon,
    required this.label,
    this.subLabel,
    this.isSelected = false,
    this.isDanger = false,
  });

  final T value;
  final IconData icon;
  final String label;
  final String? subLabel;
  final bool isSelected;
  final bool isDanger;
}

class MtfFloatingMoreMenuButton<T> extends StatefulWidget {
  const MtfFloatingMoreMenuButton({
    super.key,
    required this.items,
    required this.onSelected,
    this.icon = Icons.more_vert_rounded,
    this.iconColor = Colors.white,
    this.iconSize = 24,
    this.tooltip = '더보기',
    this.cardWidth = 218,
    this.offset = const Offset(0, 8),
  });

  final List<MtfMoreMenuItem<T>> items;
  final ValueChanged<T> onSelected;

  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final String tooltip;

  /// 카드 폭
  final double cardWidth;

  /// 버튼 아래로 얼마나 띄울지.
  /// CompositedTransformFollower가 버튼 bottomRight 기준으로 열기 때문에
  /// Offset(0, 8)이면 버튼 바로 아래 8px 지점에서 시작합니다.
  final Offset offset;

  @override
  State<MtfFloatingMoreMenuButton<T>> createState() =>
      _MtfFloatingMoreMenuButtonState<T>();
}

class _MtfFloatingMoreMenuButtonState<T>
    extends State<MtfFloatingMoreMenuButton<T>> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _entry;
  LocalHistoryEntry? _historyEntry;

  bool get _isOpen => _entry != null;

  void _openMenu() {
    if (_isOpen) {
      _closeMenu();
      return;
    }

    _entry = OverlayEntry(
      builder: (context) {
        return _MtfMoreMenuOverlay<T>(
          layerLink: _layerLink,
          items: widget.items,
          cardWidth: widget.cardWidth,
          offset: widget.offset,
          onDismiss: _closeMenu,
          onSelected: (value) {
            _closeMenu();
            widget.onSelected(value);
          },
        );
      },
    );

    Overlay.of(context, rootOverlay: true).insert(_entry!);
    final route = ModalRoute.of(context);
    if (route != null) {
      _historyEntry = LocalHistoryEntry(onRemove: () {
        _historyEntry = null;
        _removeOverlay();
      });
      route.addLocalHistoryEntry(_historyEntry!);
    }
  }

  void _closeMenu() {
    final historyEntry = _historyEntry;
    if (historyEntry != null) {
      _historyEntry = null;
      historyEntry.remove();
      _removeOverlay();
      return;
    }
    _removeOverlay();
  }

  void _removeOverlay() {
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _closeMenu();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: IconButton(
        tooltip: widget.tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        visualDensity: VisualDensity.compact,
        onPressed: _openMenu,
        icon: Icon(
          widget.icon,
          color: widget.iconColor,
          size: widget.iconSize,
        ),
      ),
    );
  }
}

class _MtfMoreMenuOverlay<T> extends StatefulWidget {
  const _MtfMoreMenuOverlay({
    required this.layerLink,
    required this.items,
    required this.cardWidth,
    required this.offset,
    required this.onDismiss,
    required this.onSelected,
  });

  final LayerLink layerLink;
  final List<MtfMoreMenuItem<T>> items;
  final double cardWidth;
  final Offset offset;
  final VoidCallback onDismiss;
  final ValueChanged<T> onSelected;

  @override
  State<_MtfMoreMenuOverlay<T>> createState() => _MtfMoreMenuOverlayState<T>();
}

class _MtfMoreMenuOverlayState<T> extends State<_MtfMoreMenuOverlay<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _anim = CurvedAnimation(
      parent: _ctrl,
      curve: Curves.easeOutCubic,
    );

    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Animation<double> _itemAnim(int index) {
    final start = 0.05 + index * 0.045;
    final end = (start + 0.38).clamp(0.0, 1.0);

    return CurvedAnimation(
      parent: _ctrl,
      curve: Interval(
        start,
        end,
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: widget.onDismiss,
              child: const SizedBox.expand(),
            ),
          ),

          // 더보기 버튼을 가리지 않도록 targetAnchor는 bottomRight,
          // followerAnchor는 topRight로 맞춤.
          // 즉 카드가 버튼 "아래"에서 시작합니다.
          CompositedTransformFollower(
            link: widget.layerLink,
            showWhenUnlinked: false,
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: widget.offset,
            child: FadeTransition(
              opacity: _anim,
              child: Transform.scale(
                alignment: Alignment.topRight,
                scale: 0.985 + (_anim.value * 0.015),
                child: _MtfMoreMenuCard<T>(
                  width: widget.cardWidth,
                  progress: _anim.value,
                  items: widget.items,
                  itemAnimBuilder: _itemAnim,
                  onSelected: widget.onSelected,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MtfMoreMenuCard<T> extends StatelessWidget {
  const _MtfMoreMenuCard({
    required this.width,
    required this.progress,
    required this.items,
    required this.itemAnimBuilder,
    required this.onSelected,
  });

  final double width;
  final double progress;
  final List<MtfMoreMenuItem<T>> items;
  final Animation<double> Function(int index) itemAnimBuilder;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(9, 9, 9, 9),
            decoration: BoxDecoration(
              color: _kMoreBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _kMoreBorder,
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF111827).withOpacity(0.20),
                  blurRadius: 24,
                  offset: const Offset(-8, 10),
                ),
                BoxShadow(
                  color: _kMorePrimary.withOpacity(0.10),
                  blurRadius: 18,
                  offset: const Offset(-4, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final anim = itemAnimBuilder(index);

                return FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: _MtfMoreMenuTile<T>(
                      item: item,
                      onSelected: onSelected,
                    ),
                  ),
                );
              }),
            ),
          ),

          // ✅ 공통 더보기 카드 네온라인
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _MtfMoreNeonPainter(progress: progress),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MtfMoreMenuTile<T> extends StatelessWidget {
  const _MtfMoreMenuTile({
    required this.item,
    required this.onSelected,
  });

  final MtfMoreMenuItem<T> item;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final Color accent = item.isDanger
        ? const Color(0xFFDC2626)
        : item.isSelected
            ? _kMorePrimary
            : const Color(0xFF6D28D9);

    return InkWell(
      onTap: () => onSelected(item.value),
      borderRadius: BorderRadius.circular(13),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 7,
          vertical: 7,
        ),
        decoration: BoxDecoration(
          color: item.isSelected
              ? Colors.white.withOpacity(0.62)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Container(
              width: 31,
              height: 31,
              decoration: BoxDecoration(
                color: _kMoreIconBg.withOpacity(0.92),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _kMoreIconBorder,
                  width: 0.6,
                ),
              ),
              child: Icon(
                item.icon,
                size: 16,
                color: accent,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color:
                          item.isDanger ? const Color(0xFFB91C1C) : _kMoreText,
                      fontSize: 12.7,
                      fontWeight:
                          item.isSelected ? FontWeight.w900 : FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                  if ((item.subLabel ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _kMoreSubText,
                        fontSize: 10.2,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (item.isSelected)
              const Icon(
                Icons.check_rounded,
                size: 16,
                color: _kMorePrimary,
              )
            else
              Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: _kMoreSubText.withOpacity(0.48),
              ),
          ],
        ),
      ),
    );
  }
}

class _MtfMoreNeonPainter extends CustomPainter {
  const _MtfMoreNeonPainter({
    required this.progress,
  });

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final double w = size.width;
    final double h = size.height;

    const double radius = 18.0;
    const double stroke = 2.2;
    const double inset = stroke / 2;

    final double p = progress.clamp(0.0, 1.0).toDouble();
    final double alpha = p < 0.10 ? p / 0.10 : 1.0;

    // 오른쪽 상단 → 왼쪽 상단 → 왼쪽 하단 → 하단 오른쪽
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

    final shader = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomRight,
      colors: const [
        _kMoreNeonStart,
        _kMoreNeonMid,
        _kMoreNeonMid,
        _kMoreNeonEnd,
      ],
      stops: const [0.0, 0.34, 0.74, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    final glowShader = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomRight,
      colors: [
        _kMoreNeonGlow.withOpacity(0.08 * alpha),
        _kMoreNeonGlow.withOpacity(0.20 * alpha),
        _kMoreNeonGlow.withOpacity(0.30 * alpha),
        _kMoreNeonGlow.withOpacity(0.34 * alpha),
      ],
      stops: const [0.0, 0.34, 0.74, 1.0],
    ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawPath(
      extractedPath,
      Paint()
        ..shader = glowShader
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

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
  bool shouldRepaint(covariant _MtfMoreNeonPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
