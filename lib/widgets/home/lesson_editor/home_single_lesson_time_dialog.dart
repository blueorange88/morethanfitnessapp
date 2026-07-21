import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_time_dialog_parts.dart';

class HomeSingleLessonTimeDialog {
  const HomeSingleLessonTimeDialog._();

  static const Color _primaryColor = Color(0xFF4F46E5);

  static String _formatLessonSheetTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return time;

    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;

    final isPm = hour >= 12;
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final ampm = isPm ? '오후' : '오전';

    return '$ampm ${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required String initialTime,
    required String title,
    required int selectedDurationMinutes,
    String? startPreviewTime,
    bool showDurationChips = true,
    bool showUnsetPreview = false,
  }) async {
    final validMinutes = List<int>.generate(12, (index) => index * 5);

    final initialParts = initialTime.split(':');

    int tempHour = int.tryParse(initialParts.first) ?? 9;

    int tempMinute = initialParts.length > 1
        ? int.tryParse(initialParts[1]) ?? 0
        : 0;

    tempMinute = ((tempMinute / 5).round() * 5).clamp(0, 55).toInt();

    int tempSelectedDuration = selectedDurationMinutes;
    bool useKeyboard = false;

    final hourWheelController = FixedExtentScrollController(
      initialItem: tempHour,
    );

    final minuteWheelController = FixedExtentScrollController(
      initialItem: validMinutes.indexOf(tempMinute),
    );

    final hourTextController = TextEditingController(
      text: tempHour.toString().padLeft(2, '0'),
    );

    final minuteTextController = TextEditingController(
      text: tempMinute.toString().padLeft(2, '0'),
    );

    String currentPickedTime() {
      return '${tempHour.toString().padLeft(2, '0')}:${tempMinute.toString().padLeft(2, '0')}';
    }

    void syncInputsFromPickedTime() {
      hourTextController.text = tempHour.toString().padLeft(2, '0');
      minuteTextController.text = tempMinute.toString().padLeft(2, '0');

      if (!useKeyboard) {
        hourWheelController.animateToItem(
          tempHour,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );

        minuteWheelController.animateToItem(
          validMinutes.indexOf(tempMinute),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    }

    void applyDurationFromStart(int minutes) {
      if (startPreviewTime == null || startPreviewTime.trim().isEmpty) {
        return;
      }

      final startParts = startPreviewTime.split(':');
      if (startParts.length != 2) return;

      final startHour = int.tryParse(startParts[0]) ?? 0;
      final startMinute = int.tryParse(startParts[1]) ?? 0;

      final base = DateTime(2000, 1, 1, startHour, startMinute);
      final next = base.add(Duration(minutes: minutes));

      tempHour = next.hour;
      tempMinute = next.minute;

      syncInputsFromPickedTime();
    }

    String previewText() {
      final picked = currentPickedTime();

      if (startPreviewTime != null && startPreviewTime.trim().isNotEmpty) {
        return '레슨 시간 : ${_formatLessonSheetTime(startPreviewTime)} - ${_formatLessonSheetTime(picked)}';
      }

      if (showUnsetPreview) {
        return '레슨 시간 : ${_formatLessonSheetTime(picked)} - 종료시간 설정전';
      }

      return '레슨 시간 : ${_formatLessonSheetTime(picked)}';
    }

    Widget buildDurationChip(
        int minutes,
        String label,
        void Function(void Function()) setStateDialog,
        ) {
      final selected = tempSelectedDuration == minutes;

      return GestureDetector(
        onTap: () {
          tempSelectedDuration = minutes;

          if (startPreviewTime != null && startPreviewTime.trim().isNotEmpty) {
            applyDurationFromStart(minutes);
          }

          setStateDialog(() {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: selected ? _primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? _primaryColor : const Color(0xFFE5E7EB),
              width: 0.9,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Colors.white : const Color(0xFF6B7280),
            ),
          ),
        ),
      );
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, localSetState) {
            String headerTimeRange() {
              final picked = currentPickedTime();

              if (startPreviewTime != null &&
                  startPreviewTime.trim().isNotEmpty) {
                return '${_formatLessonSheetTime(startPreviewTime)} — ${_formatLessonSheetTime(picked)}';
              }

              if (showUnsetPreview) {
                return '${_formatLessonSheetTime(picked)} — 미설정';
              }

              return _formatLessonSheetTime(picked);
            }

            void confirmPickedTime() {
              FocusManager.instance.primaryFocus?.unfocus();

              int nextHour = tempHour;
              int nextMinute = tempMinute;

              if (useKeyboard) {
                final parsedHour = int.tryParse(
                  hourTextController.text.trim(),
                );

                final parsedMinute = int.tryParse(
                  minuteTextController.text.trim(),
                );

                if (parsedHour == null || parsedMinute == null) {
                  return;
                }

                if (parsedHour < 0 || parsedHour > 23) {
                  return;
                }

                if (parsedMinute < 0 ||
                    parsedMinute > 55 ||
                    parsedMinute % 5 != 0) {
                  return;
                }

                nextHour = parsedHour;
                nextMinute = parsedMinute;
              }

              Navigator.of(dialogContext).pop({
                'time':
                '${nextHour.toString().padLeft(2, '0')}:${nextMinute.toString().padLeft(2, '0')}',
                'duration': tempSelectedDuration,
              });
            }

            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 48,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: SafeArea(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(dialogContext).size.height * 0.72,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      HomeTimeDialogHeader(
                        title: title,
                        timeRange: headerTimeRange(),
                        useKeyboard: useKeyboard,
                        onKbToggle: () {
                          localSetState(() {
                            useKeyboard = !useKeyboard;
                            syncInputsFromPickedTime();
                          });
                        },
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showDurationChips) ...[
                                Center(
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      buildDurationChip(
                                        30,
                                        '30분',
                                        localSetState,
                                      ),
                                      buildDurationChip(
                                        50,
                                        '50분',
                                        localSetState,
                                      ),
                                      buildDurationChip(
                                        60,
                                        '1시간',
                                        localSetState,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 10),
                              ],
                              if (!useKeyboard) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    HomeDialWheel(
                                      label: '시',
                                      controller: hourWheelController,
                                      itemCount: 24,
                                      selectedIndex: tempHour,
                                      labelBuilder: (index) =>
                                          index.toString().padLeft(2, '0'),
                                      onChanged: (idx) {
                                        localSetState(() {
                                          tempHour = idx;
                                          syncInputsFromPickedTime();
                                        });
                                      },
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        left: 10,
                                        right: 10,
                                        bottom: 24,
                                      ),
                                      child: Text(
                                        ':',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF374151),
                                        ),
                                      ),
                                    ),
                                    HomeDialWheel(
                                      label: '분',
                                      controller: minuteWheelController,
                                      itemCount: validMinutes.length,
                                      selectedIndex:
                                      validMinutes.indexOf(tempMinute),
                                      labelBuilder: (index) =>
                                          validMinutes[index]
                                              .toString()
                                              .padLeft(2, '0'),
                                      onChanged: (idx) {
                                        localSetState(() {
                                          tempMinute = validMinutes[idx];
                                          syncInputsFromPickedTime();
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: hourTextController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          const HomeMaxNumberInputFormatter(max: 23),
                                        ],
                                        decoration: InputDecoration(
                                          labelText: '시',
                                          hintText: '0~23',
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          isDense: true,
                                          contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 10,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                            BorderRadius.circular(9),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFD7DCE5),
                                              width: 0.8,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                            BorderRadius.circular(9),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFD7DCE5),
                                              width: 0.8,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                            BorderRadius.circular(9),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF8B5CF6),
                                              width: 1.1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextField(
                                        controller: minuteTextController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          const HomeMaxNumberInputFormatter(max: 55),
                                        ],
                                        decoration: InputDecoration(
                                          labelText: '분',
                                          hintText: '00~55',
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          isDense: true,
                                          contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 10,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                            BorderRadius.circular(9),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFD7DCE5),
                                              width: 0.8,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                            BorderRadius.circular(9),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFD7DCE5),
                                              width: 0.8,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                            BorderRadius.circular(9),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF8B5CF6),
                                              width: 1.1,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              const Text(
                                '분은 5분 단위로 설정할 수 있어요',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF9CA3AF),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  previewText(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF374151),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      HomeDialogFooter(
                        onCancel: () {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(dialogContext).pop();
                        },
                        onConfirm: confirmPickedTime,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    // 안정화 우선:
    // 키보드/닫힘 애니메이션 중 TextField가 controller를 다시 참조할 수 있어
    // 여기서는 dispose하지 않습니다.
    // 추후 StatefulWidget으로 더 분리하면 State.dispose()에서 정리합니다.

    return result;
  }
}