import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomeWeeklyGoalDialog extends StatefulWidget {
  const HomeWeeklyGoalDialog({
    super.key,
    required this.initialValue,
  });

  final String initialValue;

  @override
  State<HomeWeeklyGoalDialog> createState() => _HomeWeeklyGoalDialogState();
}

class _HomeWeeklyGoalDialogState extends State<HomeWeeklyGoalDialog> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = widget.initialValue;
  }

  void _submit() => Navigator.of(context).pop(_value);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('주간 레슨 목표'),
      content: TextFormField(
        key: const ValueKey('home-weekly-goal-field'),
        initialValue: widget.initialValue,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(
          labelText: '목표 레슨 수',
          hintText: '비우면 기본값 40회',
          suffixText: '회',
        ),
        onChanged: (value) => _value = value,
        onFieldSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('저장'),
        ),
      ],
    );
  }
}
