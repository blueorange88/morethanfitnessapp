import 'package:flutter/material.dart';

import '../widgets/more_care_slot_request_panel.dart';

class MoreCareAdminPage extends StatelessWidget {
  const MoreCareAdminPage({
    super.key,
    this.isBusinessOwner = false,
    this.isCompanyLinked = false,
    this.companyName = '',
  });

  final bool isBusinessOwner;
  final bool isCompanyLinked;
  final String companyName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: const [
                  _MoreCareAdminIntroCard(),
                  SizedBox(height: 14),
                  MoreCareSlotRequestPanel(),
                  SizedBox(height: 14),
                  _MoreCareAdminComingSoonCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF4F46E5),
            Color(0xFF9333EA),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.of(context).maybePop(),
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MORE 비즈니스',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  isBusinessOwner
                      ? '센터와 선생님들의 MORE 비즈니스 흐름을 운영합니다.'
                      : isCompanyLinked
                      ? '연결된 회사와 MORE 비즈니스 흐름을 관리합니다.'
                      : '회사 연결 후 MORE 비즈니스 흐름을 사용할 수 있어요.',
                  style: TextStyle(
                    color: Color(0xFFEDE9FE),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreCareAdminIntroCard extends StatelessWidget {
  const _MoreCareAdminIntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.spa_rounded,
              color: Color(0xFF4F46E5),
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '살짝 열어두고, 필요하면 이어서 관리해요',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '트레이너가 레슨일지나 계약서 흐름에서 먼저 MORE 비즈니스를 열어두면, 여기에서 계속 열어둘지 기본 관리로 유지할지 확인할 수 있어요.',
                  style: TextStyle(
                    fontSize: 12.2,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreCareAdminComingSoonCard extends StatelessWidget {
  const _MoreCareAdminComingSoonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: Color(0xFF64748B),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              '관리자 권한, 지점별 관리, 트레이너별 슬롯 배정은 다음 단계에서 연결할 예정입니다. 지금은 요청 확인과 승인/기본 관리 유지 틀만 먼저 준비합니다.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                fontWeight: FontWeight.w700,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}