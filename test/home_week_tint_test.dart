import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/widgets/home/schedule/home_weekly_schedule_table.dart';

void main() {
  group('homeWeekTintColor (표 전체 배경)', () {
    test('이번 주는 기존 배경 그대로', () {
      expect(homeWeekTintColor(weekOffset: 0, isDark: false), isNull);
      expect(homeWeekTintColor(weekOffset: 0, isDark: true), isNull);
    });

    test('멀수록 눈에 띄게 더 진해지고 4주에서 멈춘다', () {
      for (final isDark in [false, true]) {
        for (final sign in [-1, 1]) {
          double a(int step) =>
              homeWeekTintColor(weekOffset: sign * step, isDark: isDark)!.a;
          expect(a(2), greaterThan(a(1)));
          expect(a(3), greaterThan(a(2)));
          expect(a(4), greaterThan(a(3)));
          expect(a(9), closeTo(a(4), 0.0001));
          // 단계 사이 차이가 너무 작지 않다(1주 색의 25% 이상).
          expect(a(2) - a(1), greaterThanOrEqualTo(a(1) * 0.25));
          expect(a(4) - a(3), greaterThanOrEqualTo(a(1) * 0.2));
        }
      }
    });

    test('이번 주에서 ±1주로 넘어갈 때가 이후 한 단계 변화보다 크다', () {
      for (final isDark in [false, true]) {
        for (final sign in [-1, 1]) {
          double a(int step) =>
              homeWeekTintColor(weekOffset: sign * step, isDark: isDark)!.a;
          expect(a(1), greaterThan(a(2) - a(1)));
          expect(a(1), greaterThan(a(3) - a(2)));
          expect(a(1), greaterThan(a(4) - a(3)));
        }
      }
    });

    test('지난 주는 검정, 다음 주는 파랑 계열이다', () {
      for (final isDark in [false, true]) {
        final past = homeWeekTintColor(weekOffset: -2, isDark: isDark)!;
        final next = homeWeekTintColor(weekOffset: 2, isDark: isDark)!;
        expect(past.toARGB32() & 0xFFFFFF, 0);
        final hue = HSLColor.fromColor(next.withValues(alpha: 1)).hue;
        expect(hue, inInclusiveRange(200, 240));
      }
    });
  });

  group('주 제목 한 줄', () {
    test('두 줄로 만든 날짜 범위 제목만 한 줄로 바꾼다', () {
      expect(homeWeekTitleIsDateRange('11월 9일부터\n11월 15일까지'), isTrue);
      expect(homeWeekTitleIsDateRange('이번 주 스케줄'), isFalse);
      expect(homeWeekTitleOneLine('11월 9일부터\n11월 15일까지'), '11월 9일부터 11월 15일까지');
    });
  });
}
