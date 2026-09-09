import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/theme/app_colors.dart';

void main() {
  test('운동일지·알림·위젯 surface는 라이트와 다크 의미 토큰을 분리한다', () {
    expect(
      MtfThemeTokens.light.trainingLogSurface,
      isNot(MtfThemeTokens.dark.trainingLogSurface),
    );
    expect(
      MtfThemeTokens.light.notificationCardSurface,
      isNot(MtfThemeTokens.dark.notificationCardSurface),
    );
    expect(
      MtfThemeTokens.light.widgetPreviewSurface,
      isNot(MtfThemeTokens.dark.widgetPreviewSurface),
    );
    expect(
        MtfThemeTokens.light.trainingLogCompleted, isNot(Colors.transparent));
    expect(MtfThemeTokens.dark.trainingLogCompleted, isNot(Colors.transparent));
  });

  test('계약서 문서와 서명 캔버스는 다크에서도 밝은 인쇄 surface를 유지한다', () {
    expect(
      MtfThemeTokens.light.contractDocumentSurface,
      MtfThemeTokens.dark.contractDocumentSurface,
    );
    expect(
      MtfThemeTokens.light.signatureCanvasSurface,
      MtfThemeTokens.dark.signatureCanvasSurface,
    );
    expect(MtfThemeTokens.dark.contractDocumentText, AppColors.deepNavy);
    expect(MtfThemeTokens.dark.signatureStroke, AppColors.deepNavy);
  });

  test('운동일지 목록·작성·빠른서명은 공통 theme token을 사용한다', () {
    final page =
        File('lib/pages/personal_training_log_page.dart').readAsStringSync();
    final workspace =
        File('lib/pages/personal_training_log_workspace_page.dart')
            .readAsStringSync();
    final textVoice =
        File('lib/pages/personal_training_log_text_voice_page.dart')
            .readAsStringSync();
    final category = File('lib/pages/personal_training_log_category_page.dart')
        .readAsStringSync();
    final quickSign =
        File('lib/pages/personal_training_log_quick_sign_page.dart')
            .readAsStringSync();

    for (final source in [page, workspace, textVoice, category, quickSign]) {
      expect(source, contains("theme/app_colors.dart"));
      expect(source, contains('scaffoldBackgroundColor'));
    }
    expect(page, contains('trainingLogSurface'));
    expect(page, contains('trainingLogSetDivider'));
    expect(category, contains('trainingLogSurface'));
    expect(category, contains('trainingLogSetRow'));
    expect(category, contains('trainingLogSetDivider'));
    expect(
        category, isNot(contains('backgroundColor: const Color(0xFFF3F4F6)')));
    expect(quickSign, contains('signatureCanvasSurface'));
  });

  test('계약서 외곽은 theme surface, 문서 본문은 document token을 사용한다', () {
    final list = File('lib/pages/contract_list_page.dart').readAsStringSync();
    final lesson = File('lib/pages/contract_page.dart').readAsStringSync();
    final membership =
        File('lib/pages/membership_contract_page.dart').readAsStringSync();

    expect(list, contains('scaffoldBackgroundColor'));
    expect(lesson, contains('scaffoldBackgroundColor'));
    expect(membership, contains('scaffoldBackgroundColor'));
    expect(list, contains('contractDocumentSurface'));
    expect(membership, contains('contractDocumentSurface'));
    expect(membership, contains('signatureCanvasSurface'));
  });

  test('알림 설정은 smart alarm gate를 유지하고 exact alarm 권한을 추가하지 않는다', () {
    final page =
        File('lib/pages/notification_settings_page.dart').readAsStringSync();
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    expect(page, contains('canUseSmartAlarm'));
    expect(page, contains('notificationLockedSurface'));
    expect(page, contains('LessonNotificationPrefs'));
    expect(manifest, isNot(contains('SCHEDULE_EXACT_ALARM')));
    expect(manifest, isNot(contains('USE_EXACT_ALARM')));
  });

  test('위젯 설정은 앱 surface만 테마화하고 실제 미리보기 데이터는 유지한다', () {
    final page = File('lib/pages/widget_settings_page.dart').readAsStringSync();
    final service =
        File('lib/services/mtf_home_widget_service.dart').readAsStringSync();

    expect(page, contains('widgetPreviewSurface'));
    expect(page, contains('widgetColorFromHex(theme.bodyBgColor)'));
    expect(page, contains('kMtfWidgetThemes'));
    expect(service, contains('HomeWidget'));
  });

  test('빠른서명 URL 의미와 서명 반환 경로는 변경하지 않는다', () {
    final quickSign =
        File('lib/pages/personal_training_log_quick_sign_page.dart')
            .readAsStringSync();
    final memberWeb =
        File('lib/pages/member_signature_web_page.dart').readAsStringSync();
    final signUrl =
        File('lib/services/member_sign_url_service.dart').readAsStringSync();

    expect(quickSign, contains('_saveQuickSignedLog'));
    expect(memberWeb, contains('_submitSignature'));
    expect(memberWeb, contains('_MemberWebSignaturePainter'));
    expect(signUrl, contains("'/sign'"));
    expect(signUrl, contains("{'t': cleanToken}"));
  });
}
