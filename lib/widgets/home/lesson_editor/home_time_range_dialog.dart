import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_time_dialog_parts.dart';

class HomeTimeRangeDialog {
  const HomeTimeRangeDialog._();

  static String _formatHour(int hour) {
    final isPm = hour >= 12;
    final displayHour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final ampm = isPm ? '오후' : '오전';

    return '$ampm ${displayHour12.toString().padLeft(2, '0')}:00';
  }

  static Future<Map<String, int>?> show({
    required BuildContext context,
    required int startHour,
    required int endHourExclusive,
    required ValueChanged<String> onError,
  }) async {
    int tempStart = startHour;
    int tempEnd = endHourExclusive - 1;
    bool useKeyboard = false;

    final startWheelController = FixedExtentScrollController(
      initialItem: tempStart,
    );

    final endWheelController = FixedExtentScrollController(
      initialItem: tempEnd,
    );

    final startTextController = TextEditingController(
      text: tempStart.toString().padLeft(2, '0'),
    );

    final endTextController = TextEditingController(
      text: tempEnd.toString().padLeft(2, '0'),
    );

    String headerTimeRange() {
      return '${_formatHour(tempStart)} — ${_formatHour(tempEnd)}';
    }

    void syncInputsFromRange() {
      startTextController.text = tempStart.toString().padLeft(2, '0');
      endTextController.text = tempEnd.toString().padLeft(2, '0');

      if (!useKeyboard) {
        startWheelController.animateToItem(
          tempStart,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );

        endWheelController.animateToItem(
          tempEnd,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    }

    return showDialog<Map<String, int>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, localSetState) {
            void confirmTimeRange() {
              FocusManager.instance.primaryFocus?.unfocus();

              int applyStart = tempStart;
              int applyEnd = tempEnd;

              if (useKeyboard) {
                final parsedStart = int.tryParse(
                  startTextController.text.trim(),
                );

                final parsedEnd = int.tryParse(
                  endTextController.text.trim(),
                );

                if (parsedStart == null || parsedEnd == null) {
                  onError('숫자만 입력해주세요. (0~23)');
                  return;
                }

                applyStart = parsedStart.clamp(0, 23);
                applyEnd = parsedEnd.clamp(0, 23);
              }

              if (applyEnd < applyStart) {
                onError('종료 시간이 시작 시간보다 빠를 수 없습니다.');
                return;
              }

              if (applyEnd - applyStart < 2) {
                onError('최소 3시간 이상으로 설정해주세요.');
                return;
              }

              Navigator.of(dialogContext).pop({
                'startHour': applyStart,
                'endHourExclusive': applyEnd + 1,
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
                        title: '시간 범위 설정',
                        timeRange: headerTimeRange(),
                        useKeyboard: useKeyboard,
                        onKbToggle: () {
                          localSetState(() {
                            useKeyboard = !useKeyboard;
                            syncInputsFromRange();
                          });
                        },
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 13, 16, 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!useKeyboard) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    HomeDialWheel(
                                      label: '시작',
                                      controller: startWheelController,
                                      itemCount: 24,
                                      selectedIndex: tempStart,
                                      labelBuilder: (index) =>
                                          index.toString().padLeft(2, '0'),
                                      onChanged: (idx) {
                                        localSetState(() {
                                          tempStart = idx;

                                          if (tempEnd < tempStart + 2) {
                                            tempEnd =
                                                (tempStart + 2).clamp(2, 23);
                                            endWheelController.jumpToItem(
                                              tempEnd,
                                            );
                                          }

                                          startTextController.text = tempStart
                                              .toString()
                                              .padLeft(2, '0');
                                          endTextController.text = tempEnd
                                              .toString()
                                              .padLeft(2, '0');
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
                                        '~',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF374151),
                                        ),
                                      ),
                                    ),
                                    HomeDialWheel(
                                      label: '종료',
                                      controller: endWheelController,
                                      itemCount: 24,
                                      selectedIndex: tempEnd,
                                      labelBuilder: (index) =>
                                          index.toString().padLeft(2, '0'),
                                      onChanged: (idx) {
                                        localSetState(() {
                                          tempEnd = idx;

                                          if (tempEnd < tempStart + 2) {
                                            tempStart =
                                                (tempEnd - 2).clamp(0, 21);
                                            startWheelController.jumpToItem(
                                              tempStart,
                                            );
                                          }

                                          startTextController.text = tempStart
                                              .toString()
                                              .padLeft(2, '0');
                                          endTextController.text = tempEnd
                                              .toString()
                                              .padLeft(2, '0');
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
                                        controller: startTextController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          const HomeMaxNumberInputFormatter(
                                            max: 23,
                                          ),
                                        ],
                                        decoration: InputDecoration(
                                          labelText: '시작',
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
                                        controller: endTextController,
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                          const HomeMaxNumberInputFormatter(
                                            max: 23,
                                          ),
                                        ],
                                        decoration: InputDecoration(
                                          labelText: '종료',
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
                                  ],
                                ),
                              ],
                              const SizedBox(height: 9),
                              const Text(
                                '시간표에 표시할 시작/종료 시간을 설정합니다',
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
                                  '현재: ${_formatHour(tempStart)} ~ ${_formatHour(tempEnd)}',
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
                        onConfirm: confirmTimeRange,
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
  }
}