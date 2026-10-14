import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';

import 'anatomy_log.dart';

/// 바디맵 한 조각. 좌표는 JSON 의 viewBox(595.3 x 841.9) 단위이고,
/// 좌우는 그림 속 사람 기준이다. 좌우 구분이 없는 부위는 [BodySide.center].
class BodyMapZone {
  BodyMapZone({
    required this.part,
    required this.side,
    required List<Offset> points,
  }) : points = List<Offset>.unmodifiable(points),
       path = Path()..addPolygon(points, true) {
    bounds = path.getBounds();
  }

  final String part;
  final BodySide side;
  final List<Offset> points;
  final Path path;
  late final Rect bounds;

  /// 선택 상태 [selected] 가 이 조각을 칠해야 하는 상태인지.
  bool isCoveredBy(BodySide? selected) {
    if (selected == null) return false;
    if (selected == BodySide.both || selected == BodySide.center) return true;
    return side == BodySide.center || side == selected;
  }

  double distanceTo(Offset p) {
    var best = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final d = _distanceToSegment(p, a, b);
      if (d < best) best = d;
    }
    return best;
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) return (p - a).distance;
    final t =
        (((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lengthSquared)
            .clamp(0.0, 1.0)
            .toDouble();
    return (p - Offset(a.dx + t * dx, a.dy + t * dy)).distance;
  }
}

/// 성별·앞/뒷면 하나의 바디맵(이미지 + 조각 목록).
/// [zones] 는 아래에서 위 순서이며 터치는 위쪽 조각이 우선한다.
class BodyMapScene {
  const BodyMapScene({
    required this.view,
    required this.image,
    required this.zones,
    this.midline = 297.65,
  });

  final BodyView view;
  final String image;
  final List<BodyMapZone> zones;

  /// 몸의 가운데선 x 좌표(viewBox).
  final double midline;

  /// 가운데선에서 이만큼 안쪽에 찍은 점은 좌우 구분 없이 가운데로 본다.
  static const double centerBand = 8;

  /// 점 [p] 의 좌우(그림 속 사람 기준). 가운데선 근처는 center, 아니면 누른 구역의
  /// 좌우, 구역이 없거나 좌우가 없는 구역(복근 등)이면 x 위치로 정한다.
  BodySide sideForPoint(Offset p, BodyMapZone? zone) {
    if ((p.dx - midline).abs() <= centerBand) return BodySide.center;
    if (zone != null &&
        (zone.side == BodySide.left || zone.side == BodySide.right)) {
      return zone.side;
    }
    final screenLeft = p.dx < midline;
    if (view == BodyView.front) {
      return screenLeft ? BodySide.right : BodySide.left;
    }
    return screenLeft ? BodySide.left : BodySide.right;
  }

  /// [p] 는 viewBox 좌표. 조각 안이면 가장 위 조각, 아니면 [tolerance] 이내의
  /// 가장 가까운 조각(조각 사이 틈 터치 여유), 그래도 없으면 null.
  BodyMapZone? hitTest(Offset p, {double tolerance = 6}) {
    for (var i = zones.length - 1; i >= 0; i--) {
      final zone = zones[i];
      if (zone.bounds.contains(p) && zone.path.contains(p)) return zone;
    }
    BodyMapZone? best;
    var bestDistance = double.infinity;
    for (var i = zones.length - 1; i >= 0; i--) {
      final zone = zones[i];
      if (!zone.bounds.inflate(tolerance).contains(p)) continue;
      final d = zone.distanceTo(p);
      if (d <= tolerance && d < bestDistance) {
        bestDistance = d;
        best = zone;
      }
    }
    return best;
  }
}

class BodyMapData {
  const BodyMapData({required this.viewBox, required this.scenes});

  static const String assetPath = 'assets/anatomy/body_map.json';

  static BodyMapData? _cached;

  final Size viewBox;
  final Map<String, BodyMapScene> scenes;

  static Future<BodyMapData> load({AssetBundle? bundle}) async {
    final cached = _cached;
    if (cached != null && bundle == null) return cached;
    final source = await (bundle ?? rootBundle).loadString(assetPath);
    final data = parse(source);
    if (bundle == null) _cached = data;
    return data;
  }

  static BodyMapData parse(String source) {
    final root = jsonDecode(source) as Map<String, dynamic>;
    final box = root['viewBox'] as Map<String, dynamic>;
    final scenes = <String, BodyMapScene>{};
    final maps = root['maps'] as Map<String, dynamic>;
    for (final entry in maps.entries) {
      final map = entry.value as Map<String, dynamic>;
      final zones = <BodyMapZone>[];
      for (final raw in map['zones'] as List<dynamic>) {
        final zone = raw as Map<String, dynamic>;
        final flat = (zone['pts'] as List<dynamic>).cast<num>();
        final points = <Offset>[
          for (var i = 0; i + 1 < flat.length; i += 2)
            Offset(flat[i].toDouble(), flat[i + 1].toDouble()),
        ];
        if (points.length < 3) continue;
        zones.add(
          BodyMapZone(
            part: zone['part'] as String,
            side: _sideByName(zone['side'] as String),
            points: points,
          ),
        );
      }
      scenes[entry.key] = BodyMapScene(
        view: map['view'] == 'back' ? BodyView.back : BodyView.front,
        image: map['image'] as String,
        zones: List<BodyMapZone>.unmodifiable(zones),
        midline: (map['midline'] as num?)?.toDouble() ?? 297.65,
      );
    }
    return BodyMapData(
      viewBox: Size((box['w'] as num).toDouble(), (box['h'] as num).toDouble()),
      scenes: Map<String, BodyMapScene>.unmodifiable(scenes),
    );
  }

  /// 성별 미지정은 남성 몸으로 표시한다.
  BodyMapScene sceneFor(BodyGender gender, BodyView view) {
    final key =
        '${gender == BodyGender.female ? 'female' : 'male'}_${view.name}';
    return scenes[key]!;
  }

  static BodySide _sideByName(String name) => switch (name) {
    'left' => BodySide.left,
    'right' => BodySide.right,
    _ => BodySide.center,
  };

  /// 한쪽씩 선택 모드에서 [tapped] 쪽 조각을 눌렀을 때의 다음 선택 상태.
  /// null 은 선택 해제.
  static BodySide? nextSingleSide(BodySide? current, BodySide tapped) {
    if (tapped != BodySide.left && tapped != BodySide.right) return current;
    final opposite = tapped == BodySide.left ? BodySide.right : BodySide.left;
    if (current == null) return tapped;
    if (current == BodySide.both) return opposite;
    if (current == tapped) return null;
    if (current == opposite) return BodySide.both;
    return tapped;
  }
}
