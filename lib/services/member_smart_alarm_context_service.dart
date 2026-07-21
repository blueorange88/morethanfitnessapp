import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class MemberSmartAlarmContextService {
  const MemberSmartAlarmContextService._();

  static Future<void> updateFromLessonLog({
    required String memberId,
    required String trainingLogId,
    required DateTime lessonAt,
    String? summary,
    String? memo,
    String? conditionText,
    String? painText,
    String? nextLessonHint,
  }) async {
    final cleanMemberId = memberId.trim();
    if (cleanMemberId.isEmpty) return;

    final cleanTrainingLogId = trainingLogId.trim();

    final mergedText = [
      summary,
      memo,
      conditionText,
      painText,
      nextLessonHint,
    ]
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(' · ');

    if (mergedText.isEmpty && cleanTrainingLogId.isEmpty) {
      return;
    }

    final keywords = _extractKeywords(mergedText);
    final hint = _buildNextLessonHint(
      explicitHint: nextLessonHint,
      mergedText: mergedText,
      keywords: keywords,
    );

    final context = <String, dynamic>{
      if (cleanTrainingLogId.isNotEmpty) 'lastLessonLogId': cleanTrainingLogId,
      'lastLessonLogAt': Timestamp.fromDate(lessonAt),
      if (mergedText.isNotEmpty) 'lastLessonLogSummary': mergedText,
      if (keywords.isNotEmpty) 'lastLessonLogKeywords': keywords,
      if (hint.isNotEmpty) 'nextLessonReminderHint': hint,
      'source': 'lesson_log',
      'updatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('members')
          .doc(cleanMemberId)
          .set({
        'smartAlarmContext': context,

        // NotificationService가 직접 읽을 수도 있게 상위 필드에도 캐시합니다.
        if (mergedText.isNotEmpty) 'lastLessonLogSummary': mergedText,
        if (keywords.isNotEmpty) 'lastLessonLogKeywords': keywords,
        if (hint.isNotEmpty) 'nextLessonReminderHint': hint,

        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('회원 스마트 알림 context 저장 실패: $e');
    }
  }

  static List<String> _extractKeywords(String value) {
    final text = value.trim().toLowerCase();
    if (text.isEmpty) return const [];

    const candidates = [
      '통증',
      '불편',
      '부상',
      '재활',
      '가동성',
      '어깨',
      '허리',
      '무릎',
      '목',
      '손목',
      '발목',
      '측정',
      '인바디',
      '체중',
      '식단',
      '컨디션',
      '수면',
      '피로',
      '주의',
      '체크',
      '상담',
      '바디프로필',
      '대회',
    ];

    final result = <String>[];

    for (final keyword in candidates) {
      if (text.contains(keyword.toLowerCase())) {
        result.add(keyword);
      }
    }

    return result;
  }

  static String _buildNextLessonHint({
    String? explicitHint,
    required String mergedText,
    required List<String> keywords,
  }) {
    final cleanExplicit = explicitHint?.trim() ?? '';
    if (cleanExplicit.isNotEmpty) {
      return cleanExplicit;
    }

    if (keywords.isEmpty) return '';

    if (keywords.contains('통증') ||
        keywords.contains('부상') ||
        keywords.contains('불편')) {
      final bodyPart = _firstMatched(
        keywords,
        const ['어깨', '허리', '무릎', '목', '손목', '발목'],
      );

      if (bodyPart.isNotEmpty) {
        return '$bodyPart 상태 확인 후 운동 강도를 조절해 주세요.';
      }

      return '통증 여부를 먼저 확인하고 운동 강도를 조절해 주세요.';
    }

    if (keywords.contains('컨디션') ||
        keywords.contains('수면') ||
        keywords.contains('피로')) {
      return '컨디션을 먼저 확인하고 레슨 강도를 조절해 주세요.';
    }

    if (keywords.contains('인바디') ||
        keywords.contains('측정') ||
        keywords.contains('체중')) {
      return '측정 결과 변화를 확인하고 레슨 방향을 조정해 주세요.';
    }

    if (keywords.contains('식단')) {
      return '식단 진행 상황을 먼저 확인해 주세요.';
    }

    if (keywords.contains('상담')) {
      return '상담 내용 이어서 확인해 주세요.';
    }

    if (mergedText.length > 42) {
      return '${mergedText.substring(0, 42)}...';
    }

    return mergedText;
  }

  static String _firstMatched(
      List<String> source,
      List<String> candidates,
      ) {
    for (final candidate in candidates) {
      if (source.contains(candidate)) {
        return candidate;
      }
    }

    return '';
  }
}