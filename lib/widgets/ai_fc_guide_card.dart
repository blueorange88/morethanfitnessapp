import 'package:flutter/material.dart';

class AiFcGuideCard extends StatelessWidget {
  const AiFcGuideCard({
    super.key,
    required this.title,
    required this.message,
    this.primaryText,
    this.secondaryText,
    this.onPrimaryTap,
    this.onSecondaryTap,
    this.icon = Icons.auto_awesome_rounded,
  });

  final String title;
  final String message;
  final String? primaryText;
  final String? secondaryText;
  final VoidCallback? onPrimaryTap;
  final VoidCallback? onSecondaryTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF4F46E5);
    const text = Color(0xFF111827);
    const muted = Color(0xFF6B7280);
    const border = Color(0xFFE5E7EB);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      message,
                      style: const TextStyle(
                        color: muted,
                        fontSize: 12.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (primaryText != null || secondaryText != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (secondaryText != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSecondaryTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: muted,
                        side: const BorderSide(color: border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        secondaryText!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                if (secondaryText != null && primaryText != null)
                  const SizedBox(width: 10),
                if (primaryText != null)
                  Expanded(
                    child: FilledButton(
                      onPressed: onPrimaryTap,
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        primaryText!,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}