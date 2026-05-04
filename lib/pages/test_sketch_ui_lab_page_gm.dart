// lib/pages/test_sketch_ui_lab_page_gm.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Gemini 스타일 스케치 UI 실험 페이지 (개선판)
class TestSketchUiLabGmPage extends StatelessWidget {
  const TestSketchUiLabGmPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F3EA), // 더 종이 같은 색
      appBar: AppBar(
        title: Text('스케치 UI (GM)', style: textTheme.titleLarge),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SketchCard(
                wobble: 1.8,
                strokeWidth: 1.4,
                shadowBlurSigma: 8,
                cornerRadius: 14,
                paperTexture: true,
                child: const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Icon(Icons.edit_outlined, size: 50, color: Colors.black54),
                      SizedBox(height: 16),
                      Text(
                        'Sketch Style Card',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'CustomPainter로 손으로 그린 듯한 외곽선과\n번진 그림자를 흉내냈습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SketchCard(
                wobble: 2.4,
                strokeWidth: 1.6,
                shadowOpacity: 0.10,
                fillColor: const Color(0xFFFFFBF4),
                cornerRadius: 10,
                onTap: () {},
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _SketchIconButton(icon: Icons.thumb_up_outlined, label: '좋아요'),
                      _SketchIconButton(icon: Icons.share_outlined, label: '공유'),
                      _SketchIconButton(icon: Icons.bookmark_border, label: '저장'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // 데모: 리스트처럼 여러 개
              for (int i = 0; i < 3; i++) ...[
                SketchCard(
                  wobble: 2.2,
                  strokeWidth: 1.5,
                  shadowOffset: const Offset(6, 6),
                  cornerRadius: 12,
                  paperTexture: i.isEven,
                  onTap: () {},
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: const Icon(Icons.event_note_outlined),
                    title: Text('스케치 카드 #${i + 1}'),
                    subtitle: const Text('살짝 울퉁불퉁한 외곽선 + 번진 그림자'),
                    trailing: const Icon(Icons.chevron_right),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// 데생 스타일 카드 (재사용 컴포넌트)
class SketchCard extends StatefulWidget {
  final Widget child;

  /// 선 흔들림 정도 (픽셀). 높을수록 손그림 느낌이 강해짐.
  final double wobble;

  /// 선 굵기
  final double strokeWidth;

  /// 선/그림자 색
  final Color strokeColor;
  final Color shadowColor;

  /// 그림자 투명도/블러/오프셋
  final double shadowOpacity;
  final double shadowBlurSigma;
  final Offset shadowOffset;

  /// 둥근 모서리 반경(대략) - 실제로는 손떨림이 들어가므로 완전한 라운드와 다름
  final double cornerRadius;

  /// 안쪽 면색(=종이색)
  final Color? fillColor;

  /// 카드 외곽 여백(그림자 잘림 방지용)
  final EdgeInsets outerMargin;

  /// 종이 도트 텍스처 여부(가벼운 점 무늬)
  final bool paperTexture;

  /// 탭 핸들러(있으면 프레스 애니메이션 활성화)
  final VoidCallback? onTap;

  const SketchCard({
    super.key,
    required this.child,
    this.wobble = 2.0,
    this.strokeWidth = 1.5,
    this.strokeColor = const Color(0xCC000000),
    this.shadowColor = Colors.black,
    this.shadowOpacity = 0.08,
    this.shadowBlurSigma = 7.5,
    this.shadowOffset = const Offset(5, 5),
    this.cornerRadius = 12,
    this.fillColor,
    this.outerMargin = const EdgeInsets.fromLTRB(8, 8, 12, 12),
    this.paperTexture = false,
    this.onTap,
  });

  @override
  State<SketchCard> createState() => _SketchCardState();
}

class _SketchCardState extends State<SketchCard> with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;
  late final double _seed;

  @override
  void initState() {
    super.initState();
    _seed = (widget.hashCode ^ DateTime.now().millisecondsSinceEpoch).toDouble();

    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeOut, reverseCurve: Curves.easeOutBack),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) => _press.forward();
  void _handleTapUp(TapUpDetails _) => _press.reverse();
  void _handleTapCancel() => _press.reverse();

  @override
  Widget build(BuildContext context) {
    final card = RepaintBoundary(
      child: Padding(
        // 그림자 번짐이 밖으로 나가므로 안전 여백
        padding: widget.outerMargin,
        child: CustomPaint(
          painter: _SketchPainter(
            seed: _seed,
            wobble: widget.wobble,
            strokeWidth: widget.strokeWidth,
            strokeColor: widget.strokeColor,
            isForeground: false,
            shadowColor: widget.shadowColor,
            shadowOpacity: widget.shadowOpacity,
            shadowBlurSigma: widget.shadowBlurSigma,
            shadowOffset: widget.shadowOffset,
            cornerRadius: widget.cornerRadius,
            fillColor: widget.fillColor,
            paperTexture: widget.paperTexture,
          ),
          foregroundPainter: _SketchPainter(
            seed: _seed,
            wobble: widget.wobble,
            strokeWidth: widget.strokeWidth,
            strokeColor: widget.strokeColor,
            isForeground: true,
            cornerRadius: widget.cornerRadius,
          ),
          child: widget.child,
        ),
      ),
    );

    if (widget.onTap == null) return card;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: (d) {
        _handleTapUp(d);
        widget.onTap?.call();
      },
      onTapCancel: _handleTapCancel,
      child: AnimatedBuilder(
        animation: _press,
        builder: (context, _) => Transform.scale(scale: _scale.value, child: card),
      ),
    );
  }
}

/// 실제 데생 효과를 그리는 Painter
class _SketchPainter extends CustomPainter {
  final double seed;
  final bool isForeground;

  final double wobble;
  final double strokeWidth;
  final Color strokeColor;

  // 배경 전용
  final Color? fillColor;
  final Color shadowColor;
  final double shadowOpacity;
  final double shadowBlurSigma;
  final Offset shadowOffset;
  final double cornerRadius;
  final bool paperTexture;

  _SketchPainter({
    required this.seed,
    required this.wobble,
    required this.strokeWidth,
    required this.strokeColor,
    required this.isForeground,
    this.fillColor,
    this.shadowColor = Colors.black,
    this.shadowOpacity = 0.08,
    this.shadowBlurSigma = 7.5,
    this.shadowOffset = const Offset(5, 5),
    this.cornerRadius = 12,
    this.paperTexture = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed.toInt());
    final rect = Offset.zero & size;

    if (!isForeground) {
      // 1) 종이 면 채우기
      if (fillColor != null) {
        final fillPaint = Paint()..color = fillColor!;
        canvas.drawPath(_createWobblyRRect(rect, rnd, wobble, cornerRadius), fillPaint);
      }

      // 2) 아주 약한 도트 텍스처(가벼움)
      if (paperTexture) {
        final tex = Paint()..color = Colors.black.withOpacity(0.03);
        final step = 14.0;
        for (double y = step / 2; y < rect.height; y += step) {
          for (double x = step / 2; x < rect.width; x += step) {
            if (rnd.nextDouble() < 0.18) {
              // 희박하게 점 뿌리기
              canvas.drawCircle(Offset(x + (rnd.nextDouble() - .5) * 2, y + (rnd.nextDouble() - .5) * 2), 0.6, tex);
            }
          }
        }
      }

      // 3) 번진 그림자 (여러 번 겹쳐 자연스럽게)
      final shadowPaint = Paint()
        ..color = shadowColor.withOpacity(shadowOpacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlurSigma);
      for (int i = 0; i < 3; i++) {
        final shifted = rect.translate(
          shadowOffset.dx + (rnd.nextDouble() * 2 - 1) * 1.5,
          shadowOffset.dy + (rnd.nextDouble() * 2 - 1) * 1.5,
        );
        canvas.drawPath(_createWobblyRRect(shifted, rnd, wobble * 1.6, cornerRadius + 1.5), shadowPaint);
      }
    } else {
      // 4) 손그림 외곽선 (여러 겹)
      final ink = Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;

      for (int i = 0; i < 3; i++) {
        canvas.drawPath(_createWobblyRRect(rect, rnd, wobble * (1.2 + i * 0.25), cornerRadius), ink);
      }
    }
  }

  Path _createWobblyRRect(Rect rect, math.Random rnd, double wobble, double radius) {
    // 라운드 사각형을 8 포인트(각 꼭짓점 2포인트)로 근사하고 흔들림 추가
    final points = <Offset>[
      Offset(rect.left + radius, rect.top),
      Offset(rect.right - radius, rect.top),
      Offset(rect.right, rect.top + radius),
      Offset(rect.right, rect.bottom - radius),
      Offset(rect.right - radius, rect.bottom),
      Offset(rect.left + radius, rect.bottom),
      Offset(rect.left, rect.bottom - radius),
      Offset(rect.left, rect.top + radius),
    ].map((p) {
      final jx = (rnd.nextDouble() - 0.5) * wobble * 2;
      final jy = (rnd.nextDouble() - 0.5) * wobble * 2;
      return Offset(p.dx + jx, p.dy + jy);
    }).toList();

    final path = Path()..moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length; i++) {
      final from = points[i];
      final to = points[(i + 1) % points.length];
      final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
      final ctrl = mid.translate(
        (rnd.nextDouble() - 0.5) * wobble * 2.2,
        (rnd.nextDouble() - 0.5) * wobble * 2.2,
      );
      path.quadraticBezierTo(ctrl.dx, ctrl.dy, to.dx, to.dy);
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _SketchPainter old) {
    // 파라미터가 바뀔 때만 리페인트
    return old.seed != seed ||
        old.isForeground != isForeground ||
        old.wobble != wobble ||
        old.strokeWidth != strokeWidth ||
        old.strokeColor != strokeColor ||
        old.fillColor != fillColor ||
        old.shadowColor != shadowColor ||
        old.shadowOpacity != shadowOpacity ||
        old.shadowBlurSigma != shadowBlurSigma ||
        old.shadowOffset != shadowOffset ||
        old.cornerRadius != cornerRadius ||
        old.paperTexture != paperTexture;
  }
}

class _SketchIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SketchIconButton({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(icon: Icon(icon), onPressed: () {}),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
