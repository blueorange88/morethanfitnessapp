import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String kpiCard;
  late String summary;

  setUpAll(() {
    final source = File('lib/pages/stats_page.dart').readAsStringSync();
    final cardStart = source.indexOf('class _KpiCard extends');
    final cardEnd = source.indexOf('class _WeekdayBarChart');
    kpiCard = source.substring(cardStart, cardEnd);
    final summaryStart = source.indexOf('Widget _buildSummary()');
    final summaryEnd = source.indexOf('Widget _buildLessonSection()');
    summary = source.substring(summaryStart, summaryEnd);
  });

  test('인사이트 요약 카드는 머리말과 같은 네이비 그라데이션 하나만 쓴다', () {
    expect(kpiCard, contains('context.mtfHeaderGradient'));
    expect(kpiCard, isNot(contains('LinearGradient(')));
  });

  test('브랜드 골드는 숫자와 아이콘에만 쓴다', () {
    expect(kpiCard, contains('AppColors.warmYellow'));
    expect(kpiCard, isNot(contains('colors')));
  });

  test('요약 카드 4개는 색을 각각 정하지 않는다', () {
    expect('_KpiCard('.allMatches(summary).length, 4);
    expect(summary, isNot(contains('colors:')));
    expect(summary, isNot(contains('Series')));
  });
}
