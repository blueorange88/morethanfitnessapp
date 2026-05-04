import 'package:flutter/material.dart';

class ShadcnInputOtp extends StatelessWidget {
  final int length;
  final List<TextEditingController> controllers;

  ShadcnInputOtp({
    super.key,
    this.length = 6,
  }) : controllers =
  List.generate(6, (_) => TextEditingController());

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        length,
            (i) => Container(
          width: 44,
          height: 54,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cs.outline.withOpacity(0.5)),
          ),
          child: TextField(
            controller: controllers[i],
            maxLength: 1,
            textAlign: TextAlign.center,
            decoration: const InputDecoration(
              counterText: "",
              border: InputBorder.none,
            ),
            keyboardType: TextInputType.number,
          ),
        ),
      ),
    );
  }
}
