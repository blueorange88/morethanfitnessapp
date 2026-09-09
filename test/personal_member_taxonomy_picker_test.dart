import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/models/personal_member_taxonomy.dart';
import 'package:mtf_app/widgets/personal_member_taxonomy_picker.dart';

PersonalMemberTaxonomyItem _item({
  required String id,
  required String name,
  required PersonalMemberTaxonomyKind kind,
}) {
  final timestamp = DateTime.utc(2026, 8, 12);
  return PersonalMemberTaxonomyItem(
    id: id,
    kind: kind,
    name: name,
    normalizedName: name.toLowerCase(),
    schemaVersion: 1,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

void main() {
  for (final width in <double>[320, 360, 384, 411]) {
    testWidgets('group picker는 ${width.toInt()}dp에서 overflow 없이 선택된다',
        (tester) async {
      PersonalGroupPickerResult? result;
      await tester.binding.setSurfaceSize(Size(width, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showPersonalGroupPicker(
                    context: context,
                    defaultGroupLabel: 'MORE THAN GYM',
                    groups: [
                      _item(
                        id: 'group-a',
                        name: '아주 긴 이름의 오전 운동 회원 그룹',
                        kind: PersonalMemberTaxonomyKind.group,
                      ),
                    ],
                    selectedGroupId: null,
                  );
                },
                child: const Text('열기'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('열기'));
      await tester.pumpAndSettle();
      expect(find.text('그룹 선택'), findsOneWidget);
      await tester.tap(find.text('아주 긴 이름의 오전 운동 회원 그룹'));
      await tester.pumpAndSettle();
      expect(result?.personalGroupId, 'group-a');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tag picker는 복수 선택 후 정렬된 ID를 반환한다', (tester) async {
    List<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showPersonalTagPicker(
                  context: context,
                  tags: [
                    _item(
                      id: 'tag-b',
                      name: '다이어트',
                      kind: PersonalMemberTaxonomyKind.tag,
                    ),
                    _item(
                      id: 'tag-a',
                      name: 'VIP',
                      kind: PersonalMemberTaxonomyKind.tag,
                    ),
                  ],
                  selectedTagIds: const [],
                );
              },
              child: const Text('열기'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('다이어트'));
    await tester.tap(find.text('VIP'));
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    expect(result, ['tag-a', 'tag-b']);
    expect(tester.takeException(), isNull);
  });
}
