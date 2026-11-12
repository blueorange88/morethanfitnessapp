import 'dart:io';

import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/theme/app_colors.dart';
import 'package:mtf_app/widgets/mtf_header_neon_overlay.dart';

void main() {
  _allBottomRoundedHeadersHaveGlow();
  _expandableHeadersUseStrongGlow();
  test('머리말 네온 빛은 기본이 브랜드 골드이고 보라색이 아니다', () {
    const overlay = MtfHeaderNeonOverlay(isExpanded: false, child: SizedBox());
    expect(overlay.glowColor, AppColors.warmYellow);
    expect(overlay.lineColor, AppColors.goldLight);
    expect(overlay.bottomRadius, kMtfHeaderBottomRadius);
    // 열리지 않는 머리말의 기본값(열리는 머리말보다 한 단계 약함).
    expect(overlay.intensity, 0.75);
    expect(overlay.strokeWidth, 1.9);
  });

  test('홈 머리말은 네온 색을 따로 정하지 않고(공통 골드), 열리는 머리말용 강한 빛을 쓴다', () {
    final source =
        File(
          'lib/widgets/home/sections/home_header_section.dart',
        ).readAsStringSync();
    final start = source.indexOf('return MtfHeaderNeonOverlay(');
    final body = source.substring(start, start + 400);

    expect(body, isNot(contains('lineColor:')));
    expect(body, isNot(contains('glowColor:')));
    expect(body, contains('strokeWidth: kMtfHeaderGlowStrokeExpandable'));
    expect(body, contains('intensity: kMtfHeaderGlowIntensityExpandable'));
    expect(body, contains('bottomRadius: kMtfHeaderBottomRadius'));
  });

  test('아래가 둥근 머리말은 화면마다 다른 숫자 없이 공통 곡선 값을 쓴다', () {
    const pages = [
      'lib/pages/stats_page.dart',
      'lib/pages/settings_page.dart',
      'lib/pages/widget_settings_page.dart',
      'lib/pages/notification_settings_page.dart',
      'lib/pages/lesson_type_management_page.dart',
      'lib/pages/personal_member_taxonomy_management_page.dart',
      'lib/pages/more_care_admin_page.dart',
    ];
    for (final path in pages) {
      final source = File(path).readAsStringSync();
      expect(source, contains('kMtfHeaderBottomRadius'), reason: path);
      expect(
        source,
        isNot(contains('bottom: Radius.circular(28)')),
        reason: path,
      );
      expect(
        source,
        isNot(contains('bottom: Radius.circular(30)')),
        reason: path,
      );
    }
  });

  test('MORE CARE 관리 머리말은 보라 그라데이션 대신 공통 머리말 그라데이션을 쓴다', () {
    final source =
        File('lib/pages/more_care_admin_page.dart').readAsStringSync();
    final start = source.indexOf('Widget _buildHeader(');
    final body = source.substring(start, start + 500);

    expect(body, contains('context.mtfHeaderGradient'));
    expect(body, isNot(contains('0xFF9333EA')));
  });
}

void _expandableHeadersUseStrongGlow() {
  test('아래로 열리는 머리말 4곳은 홈과 같은 강한 빛을 쓴다', () {
    const files = [
      'lib/widgets/home/sections/home_header_section.dart',
      'lib/pages/my_page.dart',
      'lib/pages/client_list_page.dart',
      'lib/pages/personal_training_log_page.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      final start = source.indexOf('MtfHeaderNeonOverlay(');
      final body = source.substring(start, start + 400);
      expect(body, contains('kMtfHeaderGlowStrokeExpandable'), reason: path);
      expect(body, contains('kMtfHeaderGlowIntensityExpandable'), reason: path);
    }
    expect(kMtfHeaderGlowStrokeExpandable, 2.3);
    expect(kMtfHeaderGlowIntensityExpandable, 1.0);
  });

  test('열리지 않는 머리말은 빛 값을 따로 정하지 않고 기본값을 쓴다', () {
    for (final path in [
      'lib/pages/stats_page.dart',
      'lib/pages/contract_page.dart',
      'lib/pages/lesson_contract/lesson_contract_widgets.dart',
    ]) {
      final source = File(path).readAsStringSync();
      final start = source.indexOf('MtfHeaderNeonOverlay(');
      final body = source.substring(start, start + 200);
      expect(body, isNot(contains('intensity:')), reason: path);
      expect(body, isNot(contains('strokeWidth:')), reason: path);
    }
  });
}

void _allBottomRoundedHeadersHaveGlow() {
  test('아래가 둥근 머리말은 열리지 않는 화면도 모두 같은 빛 위젯으로 감싼다', () {
    const files = [
      'lib/pages/contract_list_page.dart',
      'lib/pages/personal_member_taxonomy_management_page.dart',
      'lib/pages/lesson_type_management_page.dart',
      'lib/pages/settings_page.dart',
      'lib/pages/notification_settings_page.dart',
      'lib/pages/widget_settings_page.dart',
      'lib/pages/more_care_admin_page.dart',
      'lib/pages/personal_training_log_text_voice_page.dart',
      'lib/pages/personal_training_log_category_page.dart',
      'lib/pages/personal_training_log_quick_sign_page.dart',
      'lib/pages/personal_training_log_anatomy/widgets/anatomy_header.dart',
    ];
    for (final path in files) {
      final source = File(path).readAsStringSync();
      expect(source, contains('MtfHeaderNeonOverlay('), reason: path);
      expect(source, contains('mtf_header_neon_overlay.dart'), reason: path);
    }
  });

  test('레슨계약 머리말은 기본으로 빛을 그린다', () {
    final source =
        File(
          'lib/pages/lesson_contract/lesson_contract_widgets.dart',
        ).readAsStringSync();
    expect(source, contains('this.neon = true,'));
  });
}
