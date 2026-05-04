// lib/pages/test_sketch_ui_lab_page_gp.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 테스트 허브에서 부르는 진입 페이지
class TestSketchUiLabGpPage extends StatefulWidget {
  const TestSketchUiLabGpPage({super.key});

  @override
  State<TestSketchUiLabGpPage> createState() => _TestSketchUiLabGpPageState();
}

class _TestSketchUiLabGpPageState extends State<TestSketchUiLabGpPage> {
  // 스케줄 구성: 월~일 / 07:00~22:00 (16칸)
  final List<String> days = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final List<String> hours =
  List.generate(16, (i) => '${(7 + i).toString().padLeft(2, '0')}:00');

  // 선택된 셀 저장: (dayIndex, hourIndex)
  final Set<_Cell> selected = <_Cell>{};

  // 터치 좌표 -> 셀 찾기
  _Cell? _hitTestCell(Offset localPos, Size size) {
    const padding = 16.0;
    const headerH = 56.0; // 상단 요일 헤더 높이
    const timeColW = 64.0; // 좌측 시간 헤더 너비

    final gridOrigin = const Offset(padding + timeColW, padding + headerH);
    final gridSize = Size(
      size.width - padding * 2 - timeColW,
      size.height - padding * 2 - headerH,
    );
    if (gridSize.width <= 0 || gridSize.height <= 0) return null;

    final cellW = gridSize.width / days.length;
    final cellH = gridSize.height / hours.length;

    final dx = localPos.dx - gridOrigin.dx;
    final dy = localPos.dy - gridOrigin.dy;
    if (dx < 0 || dy < 0) return null;

    final inGrid =
        dx >= 0 && dy >= 0 && dx <= gridSize.width && dy <= gridSize.height;
    if (!inGrid) return null;

    // ✅ clamp는 num 반환 → int로 확정 변환
    final int dayIndex =
    (dx ~/ cellW).clamp(0, days.length - 1).toInt();
    final int hourIndex =
    (dy ~/ cellH).clamp(0, hours.length - 1).toInt();

    return _Cell(dayIndex, hourIndex);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sketch Schedule (데생 표현 데모)'),
        actions: [
          IconButton(
            tooltip: '초기화',
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() => selected.clear()),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, bc) {
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final pos = box.globalToLocal(d.globalPosition);
              final cell = _hitTestCell(pos, Size(bc.maxWidth, bc.maxHeight));
              if (cell != null) {
                setState(() {
                  if (!selected.add(cell)) selected.remove(cell);
                });
              }
            },
            child: CustomPaint(
              painter: _SketchSchedulePainter(
                days: days,
                hours: hours,
                // ✅ Set은 같은 인스턴스를 계속 쓰면 shouldRepaint에서 감지 못함
                //    그래서 복사본을 넘겨서 변화가 repaint에 반영되게 함
                selected: Set<_Cell>.from(selected),
                theme: c,
              ),
              child: const SizedBox.expand(),
            ),
          );
        },
      ),
    );
  }
}

/* ───────────────────────── Painter ───────────────────────── */

class _SketchSchedulePainter extends CustomPainter {
  _SketchSchedulePainter({
    required this.days,
    required this.hours,
    required this.selected,
    required this.theme,
  });

  final List<String> days;
  final List<String> hours;
  final Set<_Cell> selected;
  final ColorScheme theme;

  final _rng = math.Random(7); // 일정한 "손떨림" 패턴을 위해 고정 시드

  // 스케치 느낌 파라미터
  final double padding = 16.0;
  final double headerH = 56.0;
  final double timeColW = 64.0;
  final double wobble = 1.4; // 선 흔들림 강도
  final double stroke = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    // 배경 종이 느낌
    _drawPaper(canvas, size);

    // 전체 외곽
    final frameRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        padding - 6,
        padding - 6,
        size.width - (padding - 6) * 2,
        size.height - (padding - 6) * 2,
      ),
      const Radius.circular(18),
    );
    _drawWobblyRRect(
      canvas,
      frameRect,
      color: Colors.black87,
      strokeWidth: 2.2,
      wobble: 2.0,
    );

    // 헤더 박스(요일/시간 머리)
    final headerRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(padding, padding, size.width - padding * 2, headerH),
      const Radius.circular(12),
    );
    _drawWobblyRRect(canvas, headerRect, color: Colors.black87, strokeWidth: 1.8);

    final timeColRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(padding, padding, timeColW, size.height - padding * 2),
      const Radius.circular(12),
    );
    _drawWobblyRRect(canvas, timeColRect, color: Colors.black87, strokeWidth: 1.8);

    // 그리드
    final gridOrigin = Offset(padding + timeColW, padding + headerH);
    final gridSize = Size(
      size.width - padding * 2 - timeColW,
      size.height - padding * 2 - headerH,
    );

    // 수평/수직 가이드
    for (int i = 0; i <= hours.length; i++) {
      final y = gridOrigin.dy + gridSize.height * (i / hours.length);
      _drawWobblyLine(
        canvas,
        Offset(gridOrigin.dx, y),
        Offset(gridOrigin.dx + gridSize.width, y),
        color: Colors.black.withOpacity(0.75),
        width: stroke,
      );
    }
    for (int j = 0; j <= days.length; j++) {
      final x = gridOrigin.dx + gridSize.width * (j / days.length);
      _drawWobblyLine(
        canvas,
        Offset(x, gridOrigin.dy),
        Offset(x, gridOrigin.dy + gridSize.height),
        color: Colors.black.withOpacity(0.75),
        width: stroke,
      );
    }

    // 선택 셀 해칭
    final cellW = gridSize.width / days.length;
    final cellH = gridSize.height / hours.length;
    for (final cell in selected) {
      final rect = Rect.fromLTWH(
        gridOrigin.dx + cellW * cell.day,
        gridOrigin.dy + cellH * cell.hour,
        cellW,
        cellH,
      ).deflate(3);

      _drawHatching(
        canvas,
        rect,
        color: Colors.black87.withOpacity(0.18),
        gap: 7.5,
        angleDeg: -20,
      );

      _drawWobblyRRect(
        canvas,
        RRect.fromRectXY(rect, 6, 6),
        color: Colors.black87,
        strokeWidth: 1.1,
        wobble: 1.1,
      );
    }

    // 요일 헤더 텍스트
    for (int j = 0; j < days.length; j++) {
      final center = Offset(
        gridOrigin.dx + cellW * (j + .5),
        padding + headerH / 2,
      );
      _drawSketchText(canvas, days[j], center, fontSize: 16, weight: FontWeight.w800);
    }

    // 시간 헤더 텍스트
    for (int i = 0; i < hours.length; i++) {
      final center = Offset(
        padding + timeColW / 2,
        gridOrigin.dy + cellH * (i + .5),
      );
      _drawSketchText(canvas, hours[i], center, fontSize: 13, weight: FontWeight.w600);
    }

    // 제목 낙서
    _drawTitleDoodle(canvas, size);
  }

  /* ───────── Paper / Doodle ───────── */

  void _drawPaper(Canvas canvas, Size size) {
    final paper = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFFFDFCF8);
    canvas.drawRect(Offset.zero & size, paper);

    final dot = Paint()..color = Colors.black.withOpacity(0.05);
    for (int i = 0; i < (size.width * size.height * 0.00004).toInt(); i++) {
      final x = _rng.nextDouble() * size.width;
      final y = _rng.nextDouble() * size.height;
      final r = _rng.nextDouble() * 0.7 + 0.2;
      canvas.drawCircle(Offset(x, y), r, dot);
    }
  }

  void _drawTitleDoodle(Canvas canvas, Size size) {
    final base = Offset(padding + 6, padding - 2);
    final underlineA = Offset(size.width - padding - 180, padding + headerH + 8);
    _drawWobblyLine(
      canvas,
      underlineA,
      underlineA + const Offset(160, 0),
      color: Colors.black87,
      width: 1.8,
    );

    final titlePos = base + const Offset(10, 20);
    _drawSketchText(
      canvas,
      'WEEKLY SCHEDULE (Sketch)',
      titlePos,
      fontSize: 18,
      weight: FontWeight.w900,
      alignCenter: false,
    );
  }

  /* ───────── Sketch Primitives ───────── */

  void _drawWobblyLine(Canvas canvas, Offset a, Offset b,
      {required Color color, double width = 1.5}) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;

    for (int k = 0; k < 2; k++) {
      final path = Path();
      const seg = 14;
      for (int i = 0; i <= seg; i++) {
        final t = i / seg;
        final x = lerpDouble(a.dx, b.dx, t)! + (_rng.nextDouble() * 2 - 1) * wobble;
        final y = lerpDouble(a.dy, b.dy, t)! + (_rng.nextDouble() * 2 - 1) * wobble;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, p..color = color.withOpacity(k == 0 ? 0.9 : 0.6));
    }
  }

  void _drawWobblyRRect(Canvas canvas, RRect rrect,
      {required Color color, double strokeWidth = 1.5, double wobble = 1.4}) {
    const seg = 22;
    final rect = rrect.outerRect;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;

    Path jitterRect(Rect rect) {
      final path = Path();
      final pts = [
        Offset(rect.left, rect.top),
        Offset(rect.right, rect.top),
        Offset(rect.right, rect.bottom),
        Offset(rect.left, rect.bottom),
        Offset(rect.left, rect.top),
      ];
      for (int s = 0; s < pts.length - 1; s++) {
        for (int i = 0; i <= seg; i++) {
          final t = i / seg;
          final x = lerpDouble(pts[s].dx, pts[s + 1].dx, t)! +
              (_rng.nextDouble() * 2 - 1) * wobble;
          final y = lerpDouble(pts[s].dy, pts[s + 1].dy, t)! +
              (_rng.nextDouble() * 2 - 1) * wobble;
          if (s == 0 && i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
      }
      return path;
    }

    canvas.drawPath(jitterRect(rect), p..color = color.withOpacity(0.9));
    canvas.drawPath(jitterRect(rect.deflate(0.8)), p..color = color.withOpacity(0.6));
  }

  void _drawHatching(Canvas canvas, Rect rect,
      {required Color color, double gap = 8, double angleDeg = -20}) {
    final angle = angleDeg * math.pi / 180.0;
    final dir = Offset(math.cos(angle), math.sin(angle));
    final diag = rect.size.longestSide * 1.6;

    for (double d = -diag / 2; d < diag / 2; d += gap) {
      final center = rect.center + Offset(-dir.dy, dir.dx) * d;
      final a = center - dir * diag / 2;
      final b = center + dir * diag / 2;

      canvas.save();
      canvas.clipRect(rect);
      _drawWobblyLine(canvas, a, b, color: color, width: 1.1);
      canvas.restore();
    }
  }

  void _drawSketchText(Canvas canvas, String text, Offset center,
      {double fontSize = 14,
        FontWeight weight = FontWeight.w600,
        bool alignCenter = true}) {
    final rot = (_rng.nextDouble() * 4 - 2) * math.pi / 180;
    final shift = Offset((_rng.nextDouble() * 2 - 1) * 1.2, (_rng.nextDouble() * 2 - 1) * 1.2);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.black87,
          fontSize: fontSize,
          fontWeight: weight,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final pos = alignCenter ? center - Offset(tp.width / 2, tp.height / 2) : center;

    canvas.save();
    canvas.translate(pos.dx + tp.width / 2, pos.dy + tp.height / 2);
    canvas.rotate(rot);
    canvas.translate(-tp.width / 2, -tp.height / 2);
    tp.paint(canvas, shift);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SketchSchedulePainter oldDelegate) {
    // ✅ 복사본(Set.from)을 넘기기 때문에 레퍼런스가 달라져 repaint가 보장됨
    return oldDelegate.selected != selected ||
        oldDelegate.theme != theme ||
        oldDelegate.days != days ||
        oldDelegate.hours != hours;
  }
}

/* ───────────────────────── Util / Model ───────────────────────── */

double? lerpDouble(num? a, num? b, double t) {
  if (a == null && b == null) return null;
  a ??= 0.0;
  b ??= 0.0;
  return a * (1.0 - t) + b * t;
}

class _Cell {
  final int day;
  final int hour;
  const _Cell(this.day, this.hour);

  @override
  bool operator ==(Object other) =>
      other is _Cell && other.day == day && other.hour == hour;

  @override
  int get hashCode => Object.hash(day, hour);
}