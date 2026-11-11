import 'package:flutter/material.dart';
import '../../../widgets/mtf_back_button.dart';
import '../../../widgets/mtf_header_neon_overlay.dart';

import '../../../theme/app_colors.dart';

/// 다른 레슨일지 화면과 같은 머리말(공통 그라데이션, 둥근 아래 모서리, 뒤로가기).
/// [trailing] 은 오른쪽 끝 버튼(없으면 빈 칸).
class AnatomyHeader extends StatelessWidget {
  const AnatomyHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return MtfHeaderNeonOverlay(
      isExpanded: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(
          top: 14,
          left: 16,
          right: 16,
          bottom: 18,
        ),
        decoration: BoxDecoration(
          gradient: context.mtfHeaderGradient,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 46,
            child: Row(
              children: [
                MtfBackButton(onTap: () => Navigator.of(context).maybePop()),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(width: 42, height: 42, child: trailing),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
