import 'package:flutter/material.dart';

class ShadcnAvatar extends StatelessWidget {
  final double size;
  final String? imageUrl;
  final Widget? fallback;

  const ShadcnAvatar({
    super.key,
    this.size = 40,
    this.imageUrl,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size / 2);

    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        color: Colors.grey.shade200,
        child: imageUrl != null
            ? Image.network(
          imageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback ?? _defaultFallback(),
        )
            : fallback ?? _defaultFallback(),
      ),
    );
  }

  Widget _defaultFallback() => Center(
    child: Icon(Icons.person, size: size * 0.5, color: Colors.grey),
  );
}
