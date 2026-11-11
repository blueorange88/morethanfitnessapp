import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/utils/lesson_contract/signature_strokes.dart';

// 실제 서명처럼 점이 촘촘한 서명 모양들(좌표는 임의 단위).
Strokes _dense(Strokes base) => [
  for (final s in base)
    [
      for (var i = 0; i < s.length - 1; i++)
        for (var k = 0; k < 12; k++)
          [
            s[i][0] + (s[i + 1][0] - s[i][0]) * k / 12,
            s[i][1] + (s[i + 1][1] - s[i][1]) * k / 12,
          ],
      s.last,
    ],
];

/// 화면 캡처 속 서명 ①(화살표 모양).
Strokes _arrow() => [
  [
    [30, 45],
    [70, 42],
    [110, 40],
    [150, 42],
  ],
  [
    [128, 5],
    [127, 40],
    [126, 80],
    [124, 115],
  ],
  [
    [60, 90],
    [90, 72],
    [118, 58],
    [140, 45],
  ],
];

/// 화면 캡처 속 서명 ②(고리와 사선 모양).
Strokes _loop() {
  final pts = <List<double>>[];
  for (var i = 0; i <= 40; i++) {
    final t = i / 40 * 2 * math.pi * 1.1;
    pts.add([80 + 26 * math.cos(t - 1.2), 38 + 28 * math.sin(t - 1.2)]);
  }
  return [
    pts,
    [
      [78, 66],
      [66, 90],
      [52, 112],
      [40, 128],
    ],
    [
      [100, 60],
      [114, 84],
      [128, 108],
    ],
  ];
}

Strokes _wave() {
  final pts = <List<double>>[];
  for (var i = 0; i <= 80; i++) {
    final t = i / 80;
    pts.add([
      10 + 190 * t,
      50 + 28 * math.sin(t * 6 * math.pi) * (1 - 0.4 * t),
    ]);
  }
  return [pts];
}

Strokes _hangul() {
  final c = <List<double>>[];
  for (var i = 0; i <= 30; i++) {
    final t = i / 30 * 2 * math.pi;
    c.add([60 + 22 * math.cos(t), 70 + 22 * math.sin(t)]);
  }
  return [
    [
      [40, 30],
      [80, 28],
    ],
    [
      [60, 20],
      [60, 48],
    ],
    c,
    [
      [110, 20],
      [112, 120],
    ],
    [
      [110, 70],
      [150, 70],
    ],
  ];
}

Strokes _zigzag() => [
  [
    for (var i = 0; i < 14; i++) [10.0 + i * 14, i.isEven ? 20.0 : 90.0],
  ],
  [
    [20, 105],
    [190, 100],
  ],
];

/// 같은 사람이 다시 쓴 서명: 크기·기울기·위치·손떨림·점 간격이 매번 조금씩 다르다.
Strokes _variant(Strokes base, int seed) {
  final dense = _dense(base);
  final r = math.Random(seed);
  final scale = 0.6 + r.nextDouble() * 1.0;
  final angle = (r.nextDouble() - 0.5) * 0.24; // 약 ±7°
  final dx = r.nextDouble() * 200 - 100;
  final dy = r.nextDouble() * 100 - 50;
  final step = 1 + r.nextInt(3);
  var minX = double.infinity;
  var maxX = double.negativeInfinity;
  for (final s in dense) {
    for (final p in s) {
      minX = math.min(minX, p[0]);
      maxX = math.max(maxX, p[0]);
    }
  }
  final jitter = 0.025 * (maxX - minX) * scale;
  return [
    for (final s in dense)
      [
        for (var i = 0; i < s.length; i += step)
          () {
            final x = s[i][0] * scale;
            final y = s[i][1] * scale;
            return [
              x * math.cos(angle) -
                  y * math.sin(angle) +
                  dx +
                  (r.nextDouble() - 0.5) * 2 * jitter,
              x * math.sin(angle) +
                  y * math.cos(angle) +
                  dy +
                  (r.nextDouble() - 0.5) * 2 * jitter,
            ];
          }(),
      ],
  ];
}

double _percentile(List<double> sorted, double p) =>
    sorted[(sorted.length * p).floor().clamp(0, sorted.length - 1)];

void main() {
  final shapes = {
    'arrow': _arrow(),
    'loop': _loop(),
    'wave': _wave(),
    'hangul': _hangul(),
    'zigzag': _zigzag(),
  };

  test('같은 서명을 그대로 다시 비교하면 거의 1이다', () {
    for (final shape in shapes.values) {
      expect(signatureSimilarity(shape, shape), greaterThan(0.97));
    }
  });

  test('같은 사람이 크기·기울기·위치·점 간격을 달리해 다시 쓴 서명은 대부분 통과 기준을 넘는다', () {
    final scores = <double>[];
    for (final shape in shapes.values) {
      for (var i = 0; i < 25; i++) {
        scores.add(signatureSimilarity(_variant(shape, i), shape));
        scores.add(
          signatureSimilarity(_variant(shape, i), _variant(shape, 1000 + i)),
        );
      }
    }
    scores.sort();
    // 가장 나쁜 경우도 거절 기준(0.35)보다 위라서 같은 사람의 서명이 거절되지는 않는다.
    expect(scores.first, greaterThan(kSignatureSimilarityReject + 0.05));
    // 95%는 그대로 통과한다.
    expect(
      _percentile(scores, 0.05),
      greaterThanOrEqualTo(kSignatureSimilarityPass),
    );
  });

  test('서로 다른 모양의 서명은 대부분 통과하지 못하고 절반 이상은 거절 구간이다', () {
    final scores = <double>[];
    final names = shapes.keys.toList();
    for (var i = 0; i < names.length; i++) {
      for (var j = 0; j < names.length; j++) {
        if (i == j) continue;
        for (var k = 0; k < 15; k++) {
          scores.add(
            signatureSimilarity(
              _variant(shapes[names[i]]!, k),
              _variant(shapes[names[j]]!, 500 + k),
            ),
          );
        }
      }
    }
    scores.sort();
    expect(_percentile(scores, 0.95), lessThan(kSignatureSimilarityPass));
    expect(scores[scores.length ~/ 2], lessThan(kSignatureSimilarityReject));
  });

  test('화면 캡처의 두 서명(화살표 모양 ↔ 고리 모양)은 거절 구간이다', () {
    final similarity = signatureSimilarity(_arrow(), _loop());
    expect(similarity, lessThan(kSignatureSimilarityReject));
    expect(signatureMatchLevel(similarity), SignatureMatch.different);
    // 같은 크기·같은 칸에 그려도 모양이 다르면 마찬가지다.
    expect(
      signatureSimilarity(_variant(_arrow(), 7), _variant(_loop(), 8)),
      lessThan(kSignatureSimilarityPass),
    );
  });

  test('판정 단계: 통과 · 확인 · 거절', () {
    expect(signatureMatchLevel(0.9), SignatureMatch.same);
    expect(signatureMatchLevel(kSignatureSimilarityPass), SignatureMatch.same);
    expect(signatureMatchLevel(0.5), SignatureMatch.uncertain);
    expect(
      signatureMatchLevel(kSignatureSimilarityReject),
      SignatureMatch.uncertain,
    );
    expect(signatureMatchLevel(0.2), SignatureMatch.different);
    expect(kSignatureSimilarityReject, lessThan(kSignatureSimilarityPass));
  });

  test('점이 너무 적어 비교할 수 없으면 같다고 본다(막지 않는다)', () {
    expect(
      signatureSimilarity(_arrow(), const [
        [
          [1, 1],
          [2, 2],
        ],
      ]),
      1.0,
    );
    expect(signatureSimilarity(const [], _arrow()), 1.0);
  });

  test('획 사이로 펜을 든 구간이나 점 하나짜리 획이 있어도 오류 없이 계산된다', () {
    final Strokes withDot = [
      ..._arrow(),
      [
        [10, 10],
      ],
    ];
    expect(signatureSimilarity(withDot, _arrow()), inInclusiveRange(0.0, 1.0));
    final Strokes flat = [
      [
        for (var i = 0; i < 12; i++) [i * 10.0, 50.0],
      ],
    ];
    expect(signatureSimilarity(flat, flat), greaterThan(0.97));
  });
}
