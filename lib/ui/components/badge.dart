import 'package:flutter/material.dart';

class ShadcnCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const ShadcnCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<ShadcnCheckbox> createState() => _ShadcnCheckboxState();
}

class _ShadcnCheckboxState extends State<ShadcnCheckbox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    if (widget.value) _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant ShadcnCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () => widget.onChanged(!widget.value),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            width: 2,
            color: widget.value ? cs.primary : cs.outline,
          ),
        ),
        child: ScaleTransition(
          scale: _ctrl,
          child: Container(
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Icon(
              Icons.check,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
