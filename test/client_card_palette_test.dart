import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/client_card_page.dart';
import 'package:mtf_app/theme/app_colors.dart';

double _contrast(Color foreground, Color background, Color base) {
  // 반투명 색은 바탕 위에 겹쳐 실제로 보이는 색으로 계산한다.
  final bg = Color.alphaBlend(background, base);
  final fg = Color.alphaBlend(foreground, bg);
  final a = fg.computeLuminance();
  final b = bg.computeLuminance();
  final hi = a > b ? a : b;
  final lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  tearDown(() => PagePalette.sync(lightTheme()));

  test('밝은 모드는 기존 회원카드 색을 그대로 쓴다', () {
    PagePalette.sync(lightTheme());
    expect(kPageBg, const Color(0xFFF8FAFC));
    expect(kPageCard, Colors.white);
    expect(kPageBorder, const Color(0xFFE5E7EB));
    expect(kPageText, const Color(0xFF111827));
    expect(kPageMuted, const Color(0xFF6B7280));
    expect(kPageSoft, const Color(0xFF9CA3AF));
    expect(kPageFieldBg, const Color(0xFFF8FAFC));
    expect(kPageAccent, const Color(0xFF4F46E5));
    expect(kPageInfoBg, const Color(0xFFF5F3FF));
    expect(kPageInfoBorder, const Color(0xFFE9D5FF));
    expect(kPageWarnBg, const Color(0xFFFFFBEB));
    expect(kPageWarnBorder, const Color(0xFFFDE68A));
    expect(kPageWarnIcon, const Color(0xFFB45309));
    expect(kPageWarnText, const Color(0xFF92400E));
    expect(kPageErrorBg, const Color(0xFFFFF1F2));
    expect(kPageErrorText, const Color(0xFFB91C1C));
  });

  test('어두운 모드는 앱 테마의 배경·카드·글씨를 따른다', () {
    final theme = darkTheme();
    PagePalette.sync(theme);
    expect(kPageBg, theme.scaffoldBackgroundColor);
    expect(kPageCard, theme.colorScheme.surface);
    expect(kPageText, theme.colorScheme.onSurface);
    expect(kPageMuted, theme.colorScheme.onSurfaceVariant);
    expect(kPageFieldBg, theme.inputDecorationTheme.fillColor);
    expect(kPageBg.computeLuminance(), lessThan(0.1));
    expect(kPageCard.computeLuminance(), lessThan(0.1));
    expect(kPageText.computeLuminance(), greaterThan(0.6));
  });

  test('어두운 모드에서 이름·생년월일 같은 글씨가 바탕 위에서 읽힌다', () {
    PagePalette.sync(darkTheme());
    final card = kPageCard;
    final pairs = <String, double>{
      '본문/카드': _contrast(kPageText, card, card),
      '본문/배경': _contrast(kPageText, kPageBg, kPageBg),
      '본문/입력칸': _contrast(kPageText, kPageFieldBg, card),
      '보조/카드': _contrast(kPageMuted, card, card),
      '보조/입력칸': _contrast(kPageMuted, kPageFieldBg, card),
      '강조/카드': _contrast(kPageAccent, card, card),
      '강조/안내(보라) 배경': _contrast(kPageAccent, kPageInfoBg, card),
      '안내(노랑) 글씨': _contrast(kPageWarnText, kPageWarnBg, card),
      '안내(노랑) 아이콘': _contrast(kPageWarnIcon, kPageWarnBg, card),
      '오류 글씨': _contrast(kPageErrorText, kPageErrorBg, card),
    };
    pairs.forEach((name, ratio) {
      expect(ratio, greaterThan(4.5), reason: '$name 대비 $ratio');
    });
    expect(_contrast(kPageSoft, card, card), greaterThan(3.0));
    expect(_contrast(kPageBorder, card, card), greaterThan(1.1));
  });

  test('테마가 바뀌면 같은 이름의 색이 바뀐다', () {
    PagePalette.sync(lightTheme());
    final lightText = kPageText;
    PagePalette.sync(darkTheme());
    expect(kPageText, isNot(lightText));
  });
}
