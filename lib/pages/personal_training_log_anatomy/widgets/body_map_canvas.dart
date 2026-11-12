import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/anatomy_log.dart';
import '../models/anatomy_marks.dart';
import '../models/body_map_data.dart';
import '../models/body_mask.dart';

/// 표시 종류별 색. 물감처럼 섞이지 않게 종류마다 고정색을 쓴다.
Color anatomyMarkColor(
  AnatomyMark mark, {
  required bool dark,
}) => switch (mark) {
  AnatomyMark.target =>
    dark ? const Color(0xFF818CF8) : const Color(0xFF1E3A8A),
  AnatomyMark.related =>
    dark ? const Color(0xFF7DB4F5) : const Color(0xFF93C5FD),
  AnatomyMark.pain => dark ? const Color(0xFFFCA5A5) : const Color(0xFFF87171),
  AnatomyMark.caution =>
    dark ? const Color(0xFFFDBA74) : const Color(0xFFFDBA74),
  AnatomyMark.mobility =>
    dark ? const Color(0xFFFDE68A) : const Color(0xFFFDE047),
};

String anatomyMarkLabel(AnatomyMark mark) => switch (mark) {
  AnatomyMark.target => '운동 목표',
  AnatomyMark.related => '함께 쓴 부위',
  AnatomyMark.pain => '통증·불편',
  AnatomyMark.caution => '주의',
  AnatomyMark.mobility => '가동성',
};

/// 점으로 찍는 기록(통증·주의·가동성)의 표시 종류.
AnatomyMark anatomyPinMark(AnatomyLogRecord record) => switch (record
    .recordType) {
  AnatomyRecordType.pain => AnatomyMark.pain,
  AnatomyRecordType.caution => AnatomyMark.caution,
  _ => AnatomyMark.mobility,
};

/// 점 안에 넣는 글자. 통증은 정도, 주의는 !, 가동성은 ○ △ × (결과 없으면 -).
String anatomyPinSymbol(AnatomyLogRecord record) {
  switch (record.recordType) {
    case AnatomyRecordType.pain:
      return '${record.painLevel}';
    case AnatomyRecordType.caution:
      return '!';
    default:
      return switch (record.mobilityResult) {
        MobilityResult.normal => '○',
        MobilityResult.mild => '△',
        MobilityResult.severe => '×',
        null => '-',
      };
  }
}

/// 바디맵에서 점으로 표시되는 기록인지(운동이 아니고 점 위치가 있는 기록).
bool isPinnedRecord(AnatomyLogRecord record) =>
    record.recordType != AnatomyRecordType.exercise && record.pin != null;

/// 바디맵을 눌렀을 때 전달되는 정보.
class AnatomyMapTap {
  const AnatomyMapTap({required this.point, this.zone, this.pinRecord});

  /// 누른 자리(viewBox 좌표).
  final Offset point;

  /// 누른 자리의 구역. 구역 밖이면 null.
  final BodyMapZone? zone;

  /// 눌린 점이 있으면 그 기록.
  final AnatomyLogRecord? pinRecord;
}

/// 바디 이미지 위에 부위 구역과 점을 그리고, 터치를 알려준다.
/// 기록([records])에서 구역마다 칠할 표시와 점을 계산한다. 배경은 이미지가 투명이라
/// 테마(라이트/다크)에 맞춘 색을 이 위젯이 깐다.
class BodyMapCanvas extends StatefulWidget {
  const BodyMapCanvas({
    super.key,
    required this.scene,
    required this.viewBox,
    required this.records,
    required this.onTapped,
    this.pinsOnly = false,
  });

  final BodyMapScene scene;
  final Size viewBox;
  final List<AnatomyLogRecord> records;
  final ValueChanged<AnatomyMapTap> onTapped;

  /// true 면 점만 눌린다(최종 확인 화면처럼 읽기 전용).
  final bool pinsOnly;

  /// 점 하나를 누를 수 있는 반경(화면 dp).
  static const double pinHitRadiusDp = 20;

  @override
  State<BodyMapCanvas> createState() => _BodyMapCanvasState();
}

class _BodyMapCanvasState extends State<BodyMapCanvas> {
  BodyMask? _mask;

  @override
  void initState() {
    super.initState();
    _loadMask();
  }

  @override
  void didUpdateWidget(covariant BodyMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scene.image != widget.scene.image) {
      _mask = null;
      _loadMask();
    }
  }

  Future<void> _loadMask() async {
    final asset = widget.scene.image;
    final mask = await BodyMask.load(asset, widget.viewBox);
    if (!mounted || widget.scene.image != asset) return;
    setState(() => _mask = mask);
  }

  Iterable<AnatomyLogRecord> get _pinRecords => widget.records.where(
    (r) => isPinnedRecord(r) && r.bodyView == widget.scene.view,
  );

  void _handleTap(Offset local, double width, double height) {
    final viewBox = widget.viewBox;
    final point = Offset(
      local.dx * viewBox.width / width,
      local.dy * viewBox.height / height,
    );
    final radius = BodyMapCanvas.pinHitRadiusDp * viewBox.width / width;
    AnatomyLogRecord? hit;
    var best = double.infinity;
    for (final record in _pinRecords) {
      final pin = record.pin!;
      final distance = (Offset(pin.x, pin.y) - point).distance;
      if (distance <= radius && distance < best) {
        best = distance;
        hit = record;
      }
    }
    if (hit != null) {
      widget.onTapped(AnatomyMapTap(point: point, pinRecord: hit));
      return;
    }
    if (widget.pinsOnly) return;
    final zone = widget.scene.hitTest(point);
    if (zone != null) {
      widget.onTapped(AnatomyMapTap(point: point, zone: zone));
      return;
    }
    if (_mask?.contains(point) ?? false) {
      widget.onTapped(AnatomyMapTap(point: point));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final viewBox = widget.viewBox;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite
                ? constraints.maxWidth.clamp(0.0, 420.0).toDouble()
                : 360.0;
        final height = width * viewBox.height / viewBox.width;
        return Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: theme.colorScheme.outline),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors:
                    isDark
                        ? const [Color(0xFF111827), Color(0xFF0B1220)]
                        : const [Color(0xFFEFF2F8), Color(0xFFDDE3EE)],
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: SizedBox(
                width: width,
                height: height,
                child: GestureDetector(
                  key: const ValueKey<String>('body_map_canvas'),
                  behavior: HitTestBehavior.opaque,
                  onTapUp:
                      (details) =>
                          _handleTap(details.localPosition, width, height),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        widget.scene.image,
                        fit: BoxFit.fill,
                        gaplessPlayback: true,
                      ),
                      CustomPaint(
                        painter: _BodyMapPainter(
                          scene: widget.scene,
                          viewBox: viewBox,
                          records: widget.records,
                          dark: isDark,
                          hint:
                              isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 바디맵 색 범례. 운동은 구역(네모), 통증·주의·가동성은 점(동그라미)으로 표시한다.
class BodyMapLegend extends StatelessWidget {
  const BodyMapLegend({super.key});

  static bool _isPin(AnatomyMark mark) =>
      mark == AnatomyMark.pain ||
      mark == AnatomyMark.caution ||
      mark == AnatomyMark.mobility;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final mark in AnatomyMark.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: anatomyMarkColor(mark, dark: dark),
                  shape: _isPin(mark) ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: _isPin(mark) ? null : BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                anatomyMarkLabel(mark),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _BodyMapPainter extends CustomPainter {
  _BodyMapPainter({
    required this.scene,
    required this.viewBox,
    required this.records,
    required this.dark,
    required this.hint,
  });

  final BodyMapScene scene;
  final Size viewBox;
  final List<AnatomyLogRecord> records;
  final bool dark;
  final Color hint;

  static double _alpha(AnatomyMark mark) => switch (mark) {
    AnatomyMark.target => 0.66,
    AnatomyMark.related => 0.82,
    _ => 0.84,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final unitsPerDp = viewBox.width / size.width;
    canvas.scale(size.width / viewBox.width, size.height / viewBox.height);
    final hintPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..color = hint;
    // 조각마다 칠할 표시를 먼저 계산하고, 위쪽 조각과 겹치는 부분은 잘라 낸다
    // (터치는 위쪽 조각이 받으므로 보이는 색도 위쪽 조각 것만 남긴다).
    final zones = scene.zones;
    final marksOf = [for (final zone in zones) anatomyMarksFor(zone, records)];
    for (var i = 0; i < zones.length; i++) {
      final zone = zones[i];
      final marks = marksOf[i];
      if (marks.isEmpty) {
        canvas.drawPath(zone.path, hintPaint);
        continue;
      }
      var visible = zone.path;
      for (var j = i + 1; j < zones.length; j++) {
        if (marksOf[j].isEmpty || !zones[j].bounds.overlaps(zone.bounds)) {
          continue;
        }
        visible = Path.combine(
          PathOperation.difference,
          visible,
          zones[j].path,
        );
      }
      if (marks.length == 1) {
        // 한 부위에 한 번만 칠해 색이 겹쳐 어두워지지 않는다. 가장자리만 살짝 번진다.
        canvas.drawPath(
          visible,
          Paint()
            ..style = PaintingStyle.fill
            ..color = anatomyMarkColor(
              marks.first,
              dark: dark,
            ).withValues(alpha: _alpha(marks.first))
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
        );
      } else {
        _paintStripes(canvas, zone, visible, marks);
      }
    }
    _paintPins(canvas, unitsPerDp);
  }

  /// 통증·주의·가동성 점. 겹치면 나중에 기록한 점이 위에 놓인다.
  void _paintPins(Canvas canvas, double unitsPerDp) {
    final radius = 9 * unitsPerDp;
    final fontSize = 11 * unitsPerDp;
    for (final record in records) {
      if (!isPinnedRecord(record) || record.bodyView != scene.view) continue;
      final pin = record.pin!;
      final center = Offset(pin.x, pin.y);
      final color = anatomyMarkColor(anatomyPinMark(record), dark: dark);
      canvas.drawCircle(
        center.translate(0, 0.8 * unitsPerDp),
        radius,
        Paint()..color = Colors.black.withValues(alpha: 0.18),
      );
      canvas.drawCircle(center, radius, Paint()..color = color);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6 * unitsPerDp
          ..color = Colors.white,
      );
      final text = TextPainter(
        text: TextSpan(
          text: anatomyPinSymbol(record),
          style: TextStyle(
            color: const Color(0xFF1F2937),
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
    }
  }

  /// 종류가 겹친 조각은 섞지 않고 사선 줄무늬로 번갈아 칠한다. 작은 조각일수록
  /// 줄 간격을 좁혀 줄무늬가 여러 개 보이게 한다.
  void _paintStripes(
    Canvas canvas,
    BodyMapZone zone,
    Path visible,
    List<AnatomyMark> marks,
  ) {
    final b = zone.bounds;
    final period = (math.min(b.width, b.height) / 4).clamp(3.0, 9.0);
    canvas.save();
    canvas.clipPath(visible);
    var index = 0;
    // 줄은 왼쪽 위에서 오른쪽 아래로 비스듬히 지나므로, 점 (x, y)는
    // c = (x - left) + (y - top) 인 줄에 속한다. 0 ~ (너비 + 높이) 전체를 덮어야 한다.
    for (var c = -period; c < b.width + b.height + period; c += period) {
      final mark = marks[index % marks.length];
      index++;
      final path =
          Path()
            ..moveTo(b.left + c, b.top)
            ..lineTo(b.left + c + period, b.top)
            ..lineTo(b.left + c + period - b.height, b.bottom)
            ..lineTo(b.left + c - b.height, b.bottom)
            ..close();
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..isAntiAlias = true
          ..color = anatomyMarkColor(
            mark,
            dark: dark,
          ).withValues(alpha: _alpha(mark)),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BodyMapPainter oldDelegate) =>
      oldDelegate.scene != scene ||
      oldDelegate.viewBox != viewBox ||
      oldDelegate.dark != dark ||
      oldDelegate.hint != hint ||
      !_sameRecords(oldDelegate.records, records);

  static bool _sameRecords(List<AnatomyLogRecord> a, List<AnatomyLogRecord> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      final x = a[i];
      final y = b[i];
      if (x.anatomyLogId != y.anatomyLogId ||
          x.bodyPartId != y.bodyPartId ||
          x.bodySide != y.bodySide ||
          x.recordType != y.recordType ||
          x.painLevel != y.painLevel ||
          x.mobilityResult != y.mobilityResult ||
          x.pin != y.pin ||
          x.relatedPartIds.join(',') != y.relatedPartIds.join(',')) {
        return false;
      }
    }
    return true;
  }
}
