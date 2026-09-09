// lib/pages/training_log_consent_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

/// 수업일지 / PT 로그용 개인정보 수집·이용 동의 페이지
/// - 홈 페이지처럼 모바일 기준(최대 480px) 레이아웃
/// - 모어댄 컬러(인디고+퍼플 그라데이션) 사용
/// - 저장 callback이 있으면 서버 저장 성공 뒤에만 true를 반환한다.
class TrainingLogConsentPage extends StatefulWidget {
  const TrainingLogConsentPage({
    super.key,
    this.onAgree,
  });

  final Future<void> Function()? onAgree;

  @override
  State<TrainingLogConsentPage> createState() => _TrainingLogConsentPageState();
}

class _TrainingLogConsentPageState extends State<TrainingLogConsentPage> {
  bool _saving = false;
  String? _saveError;

  Future<void> _submitAgreement() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await widget.onAgree?.call();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = '동의를 저장하지 못했어요. 입력 상태를 유지했으니 다시 시도해주세요.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double width = isTablet ? 480 : constraints.maxWidth;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: context.mtfHeaderGradient.colors.first,
            foregroundColor: Colors.white,
            systemOverlayStyle: SystemUiOverlayStyle.light,
            flexibleSpace: DecoratedBox(
              decoration: BoxDecoration(gradient: context.mtfHeaderGradient),
            ),
            title: const Text(
              '수업일지 개인정보 동의',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Center(
              child: SizedBox(
                width: width,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 상단 그라데이션 헤더 카드
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: context.mtfHeaderGradient,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Row(
                              children: [
                                Icon(
                                  Icons.privacy_tip_outlined,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '개인정보 수집·이용 동의서',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '수업일지 및 PT 진행을 위해 필요한 최소한의 정보를\n'
                              '수집·이용하는 것에 대한 안내입니다.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 본문 동의 내용 카드
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle('1. 수집 항목'),
                              SizedBox(height: 4),
                              _SectionBody(
                                '- 성명, 연락처, 수업일지(세션 일시, 내용, 메모 등)\n'
                                '- 신체 상태 및 운동 관련 특이사항(회원님이 직접 제공한 정보)',
                              ),
                              SizedBox(height: 12),
                              _SectionTitle('2. 수집·이용 목적'),
                              SizedBox(height: 4),
                              _SectionBody(
                                '- 수업 진행 및 운동 프로그램 설계\n'
                                '- 수업 경과 기록, 상담 및 사후 관리\n'
                                '- 서비스 품질 향상을 위한 통계 자료\n'
                                '  (개인 식별이 불가능한 형태로 활용)',
                              ),
                              SizedBox(height: 12),
                              _SectionTitle('3. 보유·이용 기간'),
                              SizedBox(height: 4),
                              _SectionBody(
                                '- 회원 탈퇴 또는 동의 철회 시까지 보관 후 지체 없이 파기합니다.\n'
                                '- 다만, 관련 법령에서 별도로 보관 기간을 정한 경우 그에 따릅니다.',
                              ),
                              SizedBox(height: 12),
                              _SectionTitle('4. 동의 거부 권리 및 불이익'),
                              SizedBox(height: 4),
                              _SectionBody(
                                '- 개인정보 수집·이용에 대한 동의를 거부하실 수 있습니다.\n'
                                '- 다만 이 경우 수업일지 서비스 제공이 제한될 수 있습니다.',
                              ),
                              SizedBox(height: 14),
                              Text(
                                '※ 「개인정보 보호법」에 따라 위 내용을 충분히 안내받았으며, '
                                '이에 동의하시는 경우에만 하단의 동의 버튼을 눌러 주세요.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 버튼 2개 (동의 / 동의 안함)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _saving
                                  ? null
                                  : () {
                                      Navigator.of(context).pop(false);
                                    },
                              style: OutlinedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
                                '동의하지 않음',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saving ? null : _submitAgreement,
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: _saving
                                  ? SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: scheme.onSecondary,
                                      ),
                                    )
                                  : const Text(
                                      '동의하고 계속하기',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                      if (_saveError != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          _saveError!,
                          key: const Key('training_log_consent_save_error'),
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      Center(
                        child: Text(
                          '언제든지 동의를 철회하실 수 있으며,\n'
                          '철회 시에는 추후 수업일지 열람이 제한될 수 있습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
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

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  final String text;
  const _SectionBody(this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        color: scheme.onSurfaceVariant,
        height: 1.5,
      ),
    );
  }
}
