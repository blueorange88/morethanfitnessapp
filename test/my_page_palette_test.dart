import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/my_page.dart';
import 'package:mtf_app/theme/app_colors.dart';

double _contrast(Color foreground, Color background, Color base) {
  // 반투명 색은 바탕 위에 겹쳐 실제로 보이는 색으로 계산한다.
  Color flatten(Color color, Color under) =>
      Color.alphaBlend(color, Color.alphaBlend(under, base));
  final bg = Color.alphaBlend(background, base);
  final fg = flatten(foreground, bg);
  final a = fg.computeLuminance();
  final b = bg.computeLuminance();
  final hi = a > b ? a : b;
  final lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  tearDown(() => MyPalette.sync(lightTheme()));

  test('밝은 모드는 기존 색을 그대로 쓴다', () {
    MyPalette.sync(lightTheme());
    expect(kMyBg, const Color(0xFFF3F4F6));
    expect(kMyCard, Colors.white);
    expect(kMyBorder, const Color(0xFFE5E7EB));
    expect(kMyText, const Color(0xFF111827));
    expect(kMyMuted, const Color(0xFF6B7280));
    expect(kMySoft, const Color(0xFF9CA3AF));
    expect(kMyFill, const Color(0xFFF8FAFC));
    expect(kMyAccent, const Color(0xFF4F46E5));
    expect(kMyActiveBg, const Color(0xFFEEF2FF));
    expect(kMyInfoBg, const Color(0xFFF5F3FF));
    expect(kMyInfoBorder, const Color(0xFFDDD6FE));
    expect(kMyWarnBg, const Color(0xFFFFFBEB));
    expect(kMyWarnBorder, const Color(0xFFFDE68A));
    expect(kMyWarnIcon, const Color(0xFFB45309));
    expect(kMyWarnText, const Color(0xFF92400E));
    expect(kMyErrorBg, const Color(0xFFFFF1F2));
    expect(kMyErrorBorder, const Color(0xFFFCA5A5));
    expect(kMyErrorText, const Color(0xFFB91C1C));
    expect(kMyDanger, const Color(0xFFDC2626));
  });

  test('어두운 모드는 앱 테마의 배경·카드·글씨를 따른다', () {
    final theme = darkTheme();
    MyPalette.sync(theme);
    expect(kMyBg, theme.scaffoldBackgroundColor);
    expect(kMyCard, theme.colorScheme.surface);
    expect(kMyText, theme.colorScheme.onSurface);
    expect(kMyMuted, theme.colorScheme.onSurfaceVariant);
    expect(kMyFill, theme.inputDecorationTheme.fillColor);
    // 배경이 어둡고 본문 글씨가 밝다.
    expect(kMyBg.computeLuminance(), lessThan(0.1));
    expect(kMyCard.computeLuminance(), lessThan(0.1));
    expect(kMyText.computeLuminance(), greaterThan(0.6));
  });

  test('어두운 모드의 글씨와 바탕 대비가 충분하다', () {
    final theme = darkTheme();
    MyPalette.sync(theme);
    final card = kMyCard;
    final pairs = <String, double>{
      '본문/카드': _contrast(kMyText, card, card),
      '본문/배경': _contrast(kMyText, kMyBg, kMyBg),
      '본문/입력칸': _contrast(kMyText, kMyFill, card),
      '보조/카드': _contrast(kMyMuted, card, card),
      '강조/카드': _contrast(kMyAccent, card, card),
      '강조/선택 배경': _contrast(kMyAccent, kMyActiveBg, card),
      '본문/선택 배경': _contrast(kMyText, kMyActiveBg, card),
      '안내(노랑)': _contrast(kMyWarnText, kMyWarnBg, card),
      '안내 아이콘(노랑)': _contrast(kMyWarnIcon, kMyWarnBg, card),
      '오류': _contrast(kMyErrorText, kMyErrorBg, card),
      '위험 항목/카드': _contrast(kMyDanger, card, card),
      '강조/안내(보라) 배경': _contrast(kMyAccent, kMyInfoBg, card),
    };
    pairs.forEach((name, ratio) {
      expect(ratio, greaterThan(4.5), reason: '$name 대비 $ratio');
    });
    // 아주 옅은 안내 아이콘/비활성 문구도 읽을 수 있어야 한다.
    expect(_contrast(kMySoft, card, card), greaterThan(3.0));
    // 구분선은 카드와 구별된다.
    expect(_contrast(kMyBorder, card, card), greaterThan(1.1));
  });

  test('테마가 바뀌면 같은 이름의 색이 바뀐다', () {
    MyPalette.sync(lightTheme());
    final lightText = kMyText;
    MyPalette.sync(darkTheme());
    expect(kMyText, isNot(lightText));
  });
}
