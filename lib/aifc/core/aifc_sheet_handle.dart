import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

class AifcSheetHandle extends StatelessWidget {
  const AifcSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.mtfThemeTokens;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: tokens.cardBorder,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
