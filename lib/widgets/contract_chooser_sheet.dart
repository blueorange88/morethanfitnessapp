import 'package:flutter/material.dart';

/// `신규계약서`에서 고를 수 있는 계약서 종류.
enum ContractKind { lesson, membership }

/// 레슨계약서·회원권계약서 중 하나를 고르는 바텀시트. 닫으면 null.
/// 홈 레슨 시트의 `신규계약서`와 회원카드 상단 계약서 아이콘이 함께 쓴다.
Future<ContractKind?> showContractChooserSheet(BuildContext context) {
  return showModalBottomSheet<ContractKind>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ContractChooserSheet(),
  );
}

class _ContractChooserSheet extends StatelessWidget {
  const _ContractChooserSheet();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget option({
      required Key key,
      required IconData icon,
      required String label,
      required ContractKind value,
    }) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.of(context).pop(value),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.outlineVariant),
              color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            child: Row(
              children: [
                Icon(icon, size: 20, color: colors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Container(
          key: const Key('aifc_contract_chooser'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '어떤 계약서를 열까요?',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              option(
                key: const Key('aifc_lesson_contract_action'),
                icon: Icons.description_outlined,
                label: '레슨계약서',
                value: ContractKind.lesson,
              ),
              const SizedBox(height: 8),
              option(
                key: const Key('aifc_membership_contract_action'),
                icon: Icons.card_membership_rounded,
                label: '회원권계약서',
                value: ContractKind.membership,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
