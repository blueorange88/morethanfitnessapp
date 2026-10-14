import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';

/// 다른 레슨일지 화면과 같은 머리말(공통 그라데이션, 둥근 아래 모서리, 뒤로가기).
/// [trailing] 은 오른쪽 끝 버튼(없으면 빈 칸).
class AnatomyHeader extends StatelessWidget {
  const AnatomyHeader({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 14, left: 16, right: 16, bottom: 18),
      decoration: BoxDecoration(
        gradient: context.mtfHeaderGradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
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
              InkWell(
                onTap: () => Navigator.of(context).maybePop(),
                borderRadius: BorderRadius.circular(999),
                child: const SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(Icons.arrow_back, color: Colors.white, size: 28),
                ),
              ),
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
    );
  }
}
