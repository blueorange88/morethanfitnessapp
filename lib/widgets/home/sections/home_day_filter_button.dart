import 'package:flutter/material.dart';

class HomeDayFilterButton extends StatelessWidget {
  const HomeDayFilterButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : colors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? primaryColor : colors.outline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : colors.onSurface,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
