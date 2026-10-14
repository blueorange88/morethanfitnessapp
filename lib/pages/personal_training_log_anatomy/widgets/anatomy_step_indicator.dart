import 'package:flutter/material.dart';

class AnatomyStepIndicator extends StatelessWidget {
  const AnatomyStepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.labels,
  });

  final int currentStep;
  final int totalSteps;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(totalSteps, (index) {
        final isCompleted = index < currentStep;
        final isCurrent = index == currentStep;
        final isLast = index == totalSteps - 1;

        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        // 연결선 왼쪽
                        if (index > 0)
                          Expanded(
                            child: Container(
                              height: 2,
                              color:
                                  isCompleted || isCurrent
                                      ? colors.primary
                                      : colors.outline,
                            ),
                          ),
                        // 스텝 원
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                isCompleted
                                    ? colors.primary
                                    : isCurrent
                                    ? Colors.white
                                    : const Color(0xFFF3F4F6),
                            border: Border.all(
                              color:
                                  isCurrent
                                      ? colors.primary
                                      : isCompleted
                                      ? colors.primary
                                      : colors.outline,
                              width: isCurrent ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child:
                                isCompleted
                                    ? const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                    : Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                        color:
                                            isCurrent
                                                ? colors.primary
                                                : colors.onSurface.withValues(
                                                  alpha: 0.45,
                                                ),
                                      ),
                                    ),
                          ),
                        ),
                        // 연결선 오른쪽
                        if (!isLast)
                          Expanded(
                            child: Container(
                              height: 2,
                              color:
                                  isCompleted ? colors.primary : colors.outline,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      index < labels.length ? labels[index] : '',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color:
                            isCurrent
                                ? colors.primary
                                : isCompleted
                                ? colors.onSurface.withValues(alpha: 0.65)
                                : colors.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
