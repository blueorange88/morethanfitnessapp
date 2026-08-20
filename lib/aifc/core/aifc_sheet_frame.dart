import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'aifc_sheet_handle.dart';
import 'aifc_theme.dart';

class AifcSheetFrame extends StatelessWidget {
  const AifcSheetFrame({
    super.key,
    required this.children,
    this.maxHeightFactor = 0.85,
    this.showHandle = true,
    this.horizontalPadding = 12,
    this.bottomPadding = 12,
  });

  final List<Widget> children;
  final double? maxHeightFactor;
  final bool showHandle;
  final double horizontalPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final tokens = context.mtfThemeTokens;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          0,
          horizontalPadding,
          bottomPadding + bottomInset,
        ),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: maxHeightFactor == null
                ? null
                : BoxConstraints(
                    maxHeight:
                        MediaQuery.of(context).size.height * maxHeightFactor!,
                  ),
            decoration: BoxDecoration(
              color: tokens.sheetBackground,
              borderRadius: BorderRadius.circular(AifcRadius.sheet),
              boxShadow: AifcShadow.sheet,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showHandle) const AifcSheetHandle(),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
