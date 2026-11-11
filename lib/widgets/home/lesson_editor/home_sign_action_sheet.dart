import 'package:flutter/material.dart';

/// 서명요청 버튼에서 고를 수 있는 서명 방법.
enum HomeSignAction { quickSign, signRequest }

/// `빠른 서명`(이 폰에서 회원이 바로 서명)과 `서명 요청하기`(회원 폰으로 QR·링크를 보내 서명 받기) 중
/// 하나를 고르는 바텀시트. 닫으면 null. 홈 레슨 시트의 AIFC 추천업무 `서명요청` 버튼이 연다.
Future<HomeSignAction?> showHomeSignActionSheet(BuildContext context) {
  return showModalBottomSheet<HomeSignAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _HomeSignActionSheet(),
  );
}

class _HomeSignActionSheet extends StatelessWidget {
  const _HomeSignActionSheet();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget option({
      required Key key,
      required IconData icon,
      required String label,
      required String sub,
      required HomeSignAction value,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).pop(value),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant),
              color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: colors.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      key: const Key('home_sign_action_sheet'),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        18,
        16,
        18 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '서명요청',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          option(
            key: const Key('home_sign_action_quick'),
            icon: Icons.draw_rounded,
            label: '빠른 서명',
            sub: '이 폰에서 회원이 바로 서명해요',
            value: HomeSignAction.quickSign,
          ),
          const SizedBox(height: 8),
          option(
            key: const Key('home_sign_action_request'),
            icon: Icons.qr_code_2_rounded,
            label: '서명 요청하기',
            sub: '회원 폰으로 QR을 보내 서명을 받아요',
            value: HomeSignAction.signRequest,
          ),
        ],
      ),
    );
  }
}
