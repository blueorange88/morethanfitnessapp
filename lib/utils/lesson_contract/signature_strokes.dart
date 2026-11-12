/// 서명 획 데이터. 서버는 `[[[x,y], ...], ...]`(획 → 점) 형태의 0~1000 좌표를 받고, 저장할 때
/// 획마다 `{points:[x1,y1,x2,y2,...]}`로 바꿔 둔다(Firestore가 중첩 배열을 못 담기 때문).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 획 → 점 → [x, y].
typedef Strokes = List<List<List<double>>>;

/// 서버가 받는 좌표 상한(가로 기준 0~1000).
const double kSignatureUnits = 1000;
const int kMaxSignatureStrokes = 40;
const int kMaxSignaturePoints = 4000;
const int kMinSignaturePoints = 8;

double _round2(double value) => (value * 100).roundToDouble() / 100;

/// 서명판에서 그린 점(획 사이는 null)을 서버 형식으로 바꾼다. 가로 길이를 1000으로 맞추고
/// 세로도 같은 비율로 줄인다. 점이 너무 많으면 고르게 덜어 낸다.
Strokes strokesFromOffsets(
  List<Offset?> points,
  Size canvas, {
  int maxPoints = 3500,
}) {
  if (canvas.width <= 0) return const [];
  final scale = kSignatureUnits / canvas.width;
  final strokes = <List<Offset>>[];
  var current = <Offset>[];
  for (final point in points) {
    if (point == null) {
      if (current.isNotEmpty) strokes.add(current);
      current = <Offset>[];
    } else {
      current.add(point);
    }
  }
  if (current.isNotEmpty) strokes.add(current);

  var total = strokes.fold<int>(0, (sum, stroke) => sum + stroke.length);
  final step = total > maxPoints ? (total / maxPoints).ceil() : 1;
  final result = <List<List<double>>>[];
  for (final stroke in strokes.take(kMaxSignatureStrokes)) {
    final kept = <Offset>[];
    for (var i = 0; i < stroke.length; i++) {
      if (i % step == 0 || i == stroke.length - 1) kept.add(stroke[i]);
    }
    result.add([
      for (final p in kept)
        [
          _round2((p.dx * scale).clamp(0, kSignatureUnits)),
          _round2((p.dy * scale).clamp(0, kSignatureUnits)),
        ],
    ]);
  }
  return result;
}

/// 서명 ②가 서명 ①과 같은 사람의 서명으로 인정되는 유사도(이 값 이상이면 그대로 통과).
const double kSignatureSimilarityPass = 0.60;

/// 이 값 미만이면 다른 사람의 서명이거나 전혀 다른 모양이라 그대로 쓸 수 없고 다시 서명해야 한다.
/// 이 값 이상 [kSignatureSimilarityPass] 미만은 `그대로 사용`을 고를 수 있는 확인 구간이다.
const double kSignatureSimilarityReject = 0.35;

/// 예전 이름(확인 구간의 위쪽 경계). 같은 값이다.
const double kSignatureSimilarityWarning = kSignatureSimilarityPass;

enum SignatureMatch {
  /// 같은 서명으로 본다.
  same,

  /// 비슷하지 않아 확인이 필요하다(사용자가 그대로 쓸 수는 있다).
  uncertain,

  /// 너무 달라서 그대로 쓸 수 없다.
  different,
}

SignatureMatch signatureMatchLevel(double similarity) {
  if (similarity >= kSignatureSimilarityPass) return SignatureMatch.same;
  if (similarity >= kSignatureSimilarityReject) return SignatureMatch.uncertain;
  return SignatureMatch.different;
}

const int _kSimilaritySamples = 96;
// 겹침 거리가 이 값(가장 긴 변 대비)만큼 벌어지면 모양 점수가 0이 된다. 같은 사람의 서명을 크기·기울기·
// 떨림·점 간격을 바꿔 만든 변형과 서로 다른 모양의 서명으로 맞춰 정한 값이다.
const double _kShapeDistanceScale = 0.12;

/// 서명 획을 펜이 닿은 길이를 따라 같은 간격으로 다시 찍고, 크기와 위치를 맞춰(가장 긴 변을 1로)
/// 돌려준다. 점이 너무 적거나 길이가 없으면 null.
List<({double x, double y})>? _normalizedSamples(Strokes strokes) {
  final lines = <List<List<double>>>[
    for (final stroke in strokes)
      if (stroke.isNotEmpty) stroke,
  ];
  if (lines.isEmpty || signaturePointCount(strokes) < 6) return null;

  // 획 안의 길이만 합친다(획 사이로 펜을 든 구간은 길이에 넣지 않는다).
  final lengths = <double>[];
  var total = 0.0;
  for (final line in lines) {
    var length = 0.0;
    for (var i = 1; i < line.length; i++) {
      length += math.sqrt(
        math.pow(line[i][0] - line[i - 1][0], 2) +
            math.pow(line[i][1] - line[i - 1][1], 2),
      );
    }
    lengths.add(length);
    total += length;
  }
  if (total <= 0) return null;

  final samples = <({double x, double y})>[];
  for (var s = 0; s < lines.length; s++) {
    final line = lines[s];
    // 이 획에 배정하는 점 수(길이에 비례, 아주 짧은 획도 최소 2점).
    final count = math.max(
      2,
      (_kSimilaritySamples * lengths[s] / total).round(),
    );
    if (lengths[s] <= 0) {
      for (var i = 0; i < count; i++) {
        samples.add((x: line.first[0], y: line.first[1]));
      }
      continue;
    }
    var segment = 1;
    var walked = 0.0;
    var segmentLength = math.sqrt(
      math.pow(line[1][0] - line[0][0], 2) +
          math.pow(line[1][1] - line[0][1], 2),
    );
    for (var i = 0; i < count; i++) {
      final target = lengths[s] * i / (count - 1);
      while (walked + segmentLength < target && segment < line.length - 1) {
        walked += segmentLength;
        segment += 1;
        segmentLength = math.sqrt(
          math.pow(line[segment][0] - line[segment - 1][0], 2) +
              math.pow(line[segment][1] - line[segment - 1][1], 2),
        );
      }
      final t =
          segmentLength <= 0
              ? 0.0
              : ((target - walked) / segmentLength).clamp(0.0, 1.0);
      samples.add((
        x: line[segment - 1][0] + (line[segment][0] - line[segment - 1][0]) * t,
        y: line[segment - 1][1] + (line[segment][1] - line[segment - 1][1]) * t,
      ));
    }
  }

  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  for (final p in samples) {
    minX = math.min(minX, p.x);
    maxX = math.max(maxX, p.x);
    minY = math.min(minY, p.y);
    maxY = math.max(maxY, p.y);
  }
  final side = math.max(math.max(maxX - minX, maxY - minY), 1.0);
  final cx = (minX + maxX) / 2;
  final cy = (minY + maxY) / 2;
  return [
    for (final p in samples) (x: (p.x - cx) / side, y: (p.y - cy) / side),
  ];
}

/// 두 점 집합 사이의 평균 최근접 거리(양방향 평균, 가장 긴 변 = 1 기준).
double _chamferDistance(
  List<({double x, double y})> a,
  List<({double x, double y})> b,
) {
  double oneWay(
    List<({double x, double y})> from,
    List<({double x, double y})> to,
  ) {
    var sum = 0.0;
    for (final p in from) {
      var best = double.infinity;
      for (final q in to) {
        final dx = p.x - q.x;
        final dy = p.y - q.y;
        final d = dx * dx + dy * dy;
        if (d < best) best = d;
      }
      sum += math.sqrt(best);
    }
    return sum / from.length;
  }

  return (oneWay(a, b) + oneWay(b, a)) / 2;
}

/// 길이를 크기로 나눈 값(얼마나 꼬불꼬불한지). 같은 사람의 서명은 이 값이 비슷하다.
double _complexity(Strokes strokes) {
  var length = 0.0;
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  for (final stroke in strokes) {
    for (var i = 0; i < stroke.length; i++) {
      minX = math.min(minX, stroke[i][0]);
      maxX = math.max(maxX, stroke[i][0]);
      minY = math.min(minY, stroke[i][1]);
      maxY = math.max(maxY, stroke[i][1]);
      if (i > 0) {
        length += math.sqrt(
          math.pow(stroke[i][0] - stroke[i - 1][0], 2) +
              math.pow(stroke[i][1] - stroke[i - 1][1], 2),
        );
      }
    }
  }
  final side = math.max(math.max(maxX - minX, maxY - minY), 1.0);
  return length / side;
}

/// 두 서명의 닮은 정도(0~1). 서명 모양을 길이를 따라 같은 간격으로 다시 찍어 크기·위치를 맞춘 뒤
/// 겹치는 정도(양방향 평균 최근접 거리)를 보고, 획의 복잡한 정도와 획 수 차이를 조금 반영한다.
/// 크기·위치·그리는 속도가 달라도 같은 사람의 서명이면 높게, 모양이 다르면 낮게 나온다.
/// 점이 너무 적어 비교할 수 없으면 1.0(같다고 봄)을 돌려준다.
double signatureSimilarity(Strokes a, Strokes b) {
  final pa = _normalizedSamples(a);
  final pb = _normalizedSamples(b);
  if (pa == null || pb == null) return 1.0;

  final distance = _chamferDistance(pa, pb);
  final shape = (1.0 - distance / _kShapeDistanceScale).clamp(0.0, 1.0);

  final ca = _complexity(a);
  final cb = _complexity(b);
  final complexity = (math.min(ca, cb) / math.max(ca, cb)).clamp(0.0, 1.0);

  final strokesA = a.where((s) => s.isNotEmpty).length;
  final strokesB = b.where((s) => s.isNotEmpty).length;
  final strokeCount =
      1.0 -
      ((strokesA - strokesB).abs() / math.max(strokesA, strokesB)).clamp(
        0.0,
        1.0,
      );

  return (shape * 0.8 + complexity * 0.12 + strokeCount * 0.08).clamp(0.0, 1.0);
}

int signaturePointCount(Strokes strokes) =>
    strokes.fold<int>(0, (sum, stroke) => sum + stroke.length);

/// 서버가 받아들이는 길이이고 한 점을 찍은 정도가 아니라 실제로 그은 서명인지.
bool isMeaningfulSignature(Strokes strokes) {
  if (strokes.isEmpty || strokes.length > kMaxSignatureStrokes) return false;
  final count = signaturePointCount(strokes);
  if (count < kMinSignaturePoints || count > kMaxSignaturePoints) return false;
  var minX = double.infinity;
  var minY = double.infinity;
  var maxX = double.negativeInfinity;
  var maxY = double.negativeInfinity;
  for (final stroke in strokes) {
    for (final point in stroke) {
      minX = math.min(minX, point[0]);
      maxX = math.max(maxX, point[0]);
      minY = math.min(minY, point[1]);
      maxY = math.max(maxY, point[1]);
    }
  }
  return (maxX - minX) >= 20 || (maxY - minY) >= 20;
}

/// Firestore에 저장된 획(`[{points:[x,y,...]}, ...]`)을 [Strokes]로 되돌린다.
Strokes strokesFromStored(Object? stored) {
  if (stored is! List) return const [];
  final result = <List<List<double>>>[];
  for (final item in stored) {
    final raw = item is Map ? item['points'] : item;
    if (raw is! List) continue;
    final points = <List<double>>[];
    for (var i = 0; i + 1 < raw.length; i += 2) {
      final x = raw[i];
      final y = raw[i + 1];
      if (x is num && y is num) points.add([x.toDouble(), y.toDouble()]);
    }
    if (points.isNotEmpty) result.add(points);
  }
  return result;
}

/// 저장된 서명을 칸 크기에 맞춰 그린다(획의 범위를 칸에 맞추고 가운데 정렬).
class SignatureStrokesView extends StatelessWidget {
  const SignatureStrokesView({
    super.key,
    required this.strokes,
    this.color = const Color(0xFF111111),
    this.strokeWidth = 1.8,
  });

  final Strokes strokes;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StrokesPainter(strokes, color, strokeWidth),
      child: const SizedBox.expand(),
    );
  }
}

class _StrokesPainter extends CustomPainter {
  _StrokesPainter(this.strokes, this.color, this.strokeWidth);

  final Strokes strokes;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (strokes.isEmpty) return;
    var minX = double.infinity;
    var minY = double.infinity;
    var maxX = double.negativeInfinity;
    var maxY = double.negativeInfinity;
    for (final stroke in strokes) {
      for (final p in stroke) {
        minX = math.min(minX, p[0]);
        maxX = math.max(maxX, p[0]);
        minY = math.min(minY, p[1]);
        maxY = math.max(maxY, p[1]);
      }
    }
    final width = math.max(maxX - minX, 1);
    final height = math.max(maxY - minY, 1);
    final scale = math.min(
      (size.width - 4) / width,
      (size.height - 4) / height,
    );
    final dx = (size.width - width * scale) / 2 - minX * scale;
    final dy = (size.height - height * scale) / 2 - minY * scale;
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(
          Offset(stroke[0][0] * scale + dx, stroke[0][1] * scale + dy),
          strokeWidth / 2,
          paint..style = PaintingStyle.fill,
        );
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path =
          Path()..moveTo(stroke[0][0] * scale + dx, stroke[0][1] * scale + dy);
      for (var i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i][0] * scale + dx, stroke[i][1] * scale + dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokesPainter oldDelegate) =>
      oldDelegate.strokes != strokes ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}
