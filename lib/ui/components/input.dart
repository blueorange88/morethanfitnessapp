import 'package:flutter/material.dart';

class ShadcnInput extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final bool disabled;

  const ShadcnInput({
    super.key,
    required this.controller,
    this.hint,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      enabled: !disabled,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: cs.surface,
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
      ),
    );
  }
}
