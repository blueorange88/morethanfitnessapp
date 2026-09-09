import 'package:flutter/material.dart';

import '../../../services/home_member_lookup_service.dart';
import 'home_member_match_info_chip.dart';

class HomeMemberMatchPickerSheet {
  const HomeMemberMatchPickerSheet._();

  static Future<Map<String, dynamic>?> show({
    required BuildContext context,
    required String typedName,
    required String lessonLabel,
    required List<Map<String, dynamic>> candidates,
  }) {
    String nextLessonLabel(dynamic value) {
      if (value is! DateTime) return '다음 레슨 없음';

      final month = value.month;
      final day = value.day;
      final hour = value.hour.toString().padLeft(2, '0');
      final minute = value.minute.toString().padLeft(2, '0');

      return '다음 레슨 $month월 $day일 $hour:$minute';
    }

    String memberMetaLabel(Map<String, dynamic> candidate) {
      final gender = (candidate['gender'] ?? '-').toString().trim();
      final job = (candidate['job'] ?? '').toString().trim();

      if (job.isEmpty) return gender;
      return '$gender / $job';
    }

    String sessionLabel(Map<String, dynamic> candidate) {
      final remain = candidate['remainingSessions'];
      final total = candidate['totalSessions'];

      final remainValue = remain is num
          ? remain.toInt()
          : int.tryParse((remain ?? '').toString()) ?? 0;

      final totalValue = total is num
          ? total.toInt()
          : int.tryParse((total ?? '').toString()) ?? 0;

      if (totalValue <= 0 && remainValue <= 0) {
        return '회차정보 없음';
      }

      return '잔여 $remainValue/$totalValue';
    }

    String shortPhoneLabel(String value) {
      final digits = HomeMemberLookupService.normalizePhone(value);

      if (digits.length == 11) {
        return '${digits.substring(0, 3)}-****-${digits.substring(7)}';
      }

      if (digits.length == 10) {
        return '${digits.substring(0, 3)}-***-${digits.substring(6)}';
      }

      return digits.isEmpty
          ? '-'
          : HomeMemberLookupService.formatPhoneDisplay(digits);
    }

    Map<String, dynamic>? selectedCandidate;

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(sheetContext).size.height * 0.78,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '기존 회원과 이름이 같아요',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => Navigator.of(sheetContext).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${typedName.trim().isEmpty ? '입력한 이름' : typedName.trim()} 후보 ${candidates.length}명을 확인해 주세요.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: candidates.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final candidate = candidates[index];
                            final isSelected =
                            identical(selectedCandidate, candidate);

                            final name = (candidate['name'] ?? typedName)
                                .toString()
                                .trim();

                            final phone = (candidate['phone'] ?? '')
                                .toString()
                                .trim();

                            final meta = memberMetaLabel(candidate);
                            final phoneText = shortPhoneLabel(phone);
                            final sessionText = sessionLabel(candidate);
                            final nextLesson =
                            nextLessonLabel(candidate['nextLessonAt']);

                            return InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                setSheetState(() {
                                  selectedCandidate = candidate;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 140),
                                width: double.infinity,
                                padding:
                                const EdgeInsets.fromLTRB(12, 12, 12, 12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF4F46E5)
                                      .withOpacity(0.07)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF4F46E5)
                                        : const Color(0xFFE5E7EB),
                                    width: isSelected ? 1.4 : 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.025),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Icon(
                                        isSelected
                                            ? Icons.radio_button_checked_rounded
                                            : Icons
                                            .radio_button_unchecked_rounded,
                                        size: 20,
                                        color: isSelected
                                            ? const Color(0xFF4F46E5)
                                            : const Color(0xFF9CA3AF),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$name 님',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w900,
                                              color: Color(0xFF111827),
                                            ),
                                          ),
                                          const SizedBox(height: 5),
                                          Text(
                                            '$meta · $phoneText',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF4B5563),
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            children: [
                                              HomeMemberMatchInfoChip(
                                                label: sessionText,
                                              ),
                                              HomeMemberMatchInfoChip(
                                                label: nextLesson,
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.of(sheetContext).pop({
                                  'manual': true,
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF374151),
                                side: const BorderSide(
                                  color: Color(0xFFD1D5DB),
                                ),
                                padding:
                                const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                '새로 저장',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton(
                              onPressed: selectedCandidate == null
                                  ? null
                                  : () {
                                Navigator.of(sheetContext)
                                    .pop(selectedCandidate);
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                const Color(0xFFE5E7EB),
                                disabledForegroundColor:
                                const Color(0xFF9CA3AF),
                                padding:
                                const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                '선택한 회원으로 저장',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        ],
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
  }
}