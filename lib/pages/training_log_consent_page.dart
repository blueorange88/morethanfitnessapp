// lib/pages/training_log_consent_page.dart
import 'package:flutter/material.dart';

/// 수업일지 / PT 로그용 개인정보 수집·이용 동의 페이지
/// - 홈 페이지처럼 모바일 기준(최대 480px) 레이아웃
/// - More Than Fitness 컬러(인디고+퍼플 그라데이션) 사용
/// - 확인 버튼 누르면 Navigator.pop(context, true), 취소는 false
class TrainingLogConsentPage extends StatelessWidget {
  const TrainingLogConsentPage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;
        final double width = isTablet ? 480 : constraints.maxWidth;

        return Scaffold(
          backgroundColor: Colors.grey[100],
          appBar: AppBar(
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
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
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF9333EA)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
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
                            children: const [
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
                                  color: Colors.black54,
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
                              onPressed: () {
                                // 동의 안 함
                                Navigator.of(context).pop(false);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.black87,
                                side: BorderSide(color: Colors.grey.shade400),
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
                              onPressed: () {
                                // 동의
                                Navigator.of(context).pop(true);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                padding:
                                const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text(
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

                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          '언제든지 동의를 철회하실 수 있으며,\n'
                              '철회 시에는 추후 수업일지 열람이 제한될 수 있습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.black54,
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
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF111827),
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  final String text;
  const _SectionBody(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xFF374151),
        height: 1.5,
      ),
    );
  }
}
