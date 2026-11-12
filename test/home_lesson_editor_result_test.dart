import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/home_lesson_editor_result.dart';

void main() {
  test('삭제 결과는 저장 성공 결과를 함께 반환하지 않는다', () {
    const result = HomeLessonEditorResult(
      lessonTypes: [],
      selectedLessonTypeId: 'pt',
      deletedSuccessfully: true,
      editSessionId: 'edit-1',
    );

    expect(result.deletedSuccessfully, isTrue);
    expect(result.savedSuccessfully, isFalse);
  });
}
