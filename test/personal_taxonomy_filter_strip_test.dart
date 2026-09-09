import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/theme.dart';
import 'package:mtf_app/widgets/personal_member_status_filter.dart';
import 'package:mtf_app/widgets/personal_taxonomy_filter_strip.dart';

const _defaultId = '__ungrouped__';
const _allId = '__all__';

List<PersonalTaxonomyFilterEntry> _entries({
  Map<String, String> groups = const {},
  Map<String, String> tags = const {},
}) {
  return buildPersonalTaxonomyFilterEntries(
    defaultGroupId: _defaultId,
    defaultGroupLabel: 'MORE THAN GYM',
    customGroups: groups,
    tags: tags,
    visibleSystemGroups: const {},
    allId: _allId,
    dormantCount: 2,
    expiredCount: 3,
  );
}

Widget _app({
  required double width,
  required List<PersonalTaxonomyFilterEntry> entries,
  ThemeData? theme,
  ValueChanged<PersonalTaxonomyFilterEntry>? onSelected,
  String? selectedGroupId,
  String? selectedTagId,
  PersonalMemberStatusFilter selectedStatus = PersonalMemberStatusFilter.all,
}) {
  return MaterialApp(
    theme: theme ?? lightTheme(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          child: PersonalTaxonomyFilterStrip(
            entries: entries,
            selectedGroupId: selectedGroupId,
            selectedTagId: selectedTagId,
            selectedStatus: selectedStatus,
            onManage: () {},
            onSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('group 0 / tag 0이면 기본 그룹과 예시, 마지막 전체를 만든다', () {
    final entries = _entries();
    expect(
      entries.map((entry) => entry.label),
      [
        'MORE THAN GYM',
        '모어헬스',
        'VIP',
        '허리통증',
        '다이어트',
        '전체',
        '휴면 2',
        '만료 3',
      ],
    );
    expect(entries[5].role, PersonalTaxonomyFilterRole.all);
    expect(entries[6].role, PersonalTaxonomyFilterRole.statusDormant);
    expect(entries[7].role, PersonalTaxonomyFilterRole.statusExpired);
    expect(entries.where((entry) => entry.isExample), hasLength(4));
  });

  test('실제 custom group이 있으면 group 예시는 숨기고 중복하지 않는다', () {
    final entries = _entries(groups: const {'group-health': '모어헬스'});
    expect(
      entries.where((entry) => entry.label == '모어헬스'),
      hasLength(1),
    );
    expect(
      entries.any(
        (entry) => entry.role == PersonalTaxonomyFilterRole.exampleGroup,
      ),
      isFalse,
    );
  });

  test('실제 tag가 있으면 tag 예시는 모두 실제 tag로 교체한다', () {
    final entries = _entries(tags: const {'tag-vip': 'VIP'});
    expect(entries.where((entry) => entry.label == 'VIP'), hasLength(1));
    expect(
      entries.any(
        (entry) => entry.role == PersonalTaxonomyFilterRole.exampleTag,
      ),
      isFalse,
    );
    expect(entries[entries.length - 3].label, '전체');
    expect(entries.last.label, '만료 3');
  });

  test('group·tag·status 선택은 같은 row에서도 독립적으로 판정한다', () {
    final entries = _entries(
      groups: const {'group-a': '센터B'},
      tags: const {'tag-vip': 'VIP'},
    );
    bool selected(String label) => isPersonalTaxonomyFilterEntrySelected(
          entry: entries.singleWhere((entry) => entry.label == label),
          selectedGroupId: 'group-a',
          selectedTagId: 'tag-vip',
          selectedStatus: PersonalMemberStatusFilter.expired,
        );

    expect(selected('센터B'), isTrue);
    expect(selected('VIP'), isTrue);
    expect(selected('만료 3'), isTrue);
    expect(selected('전체'), isFalse);
    expect(selected('휴면 2'), isFalse);
  });

  test('group·tag·status가 모두 없을 때만 전체가 선택된다', () {
    final all = _entries().singleWhere(
      (entry) => entry.role == PersonalTaxonomyFilterRole.all,
    );
    expect(
      isPersonalTaxonomyFilterEntrySelected(
        entry: all,
        selectedGroupId: null,
        selectedTagId: null,
        selectedStatus: PersonalMemberStatusFilter.all,
      ),
      isTrue,
    );
    expect(
      isPersonalTaxonomyFilterEntrySelected(
        entry: all,
        selectedGroupId: null,
        selectedTagId: null,
        selectedStatus: PersonalMemberStatusFilter.dormant,
      ),
      isFalse,
    );
  });

  for (final width in <double>[320, 360, 384, 411]) {
    for (final count in <int>[10, 20]) {
      testWidgets('${width.toInt()}dp $count개에서도 한 줄이며 gear가 고정된다',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 720));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final tags = {
          for (var index = 0; index < count; index++) 'tag-$index': '태그 $index',
        };
        await tester.pumpWidget(
          _app(width: width, entries: _entries(tags: tags)),
        );
        final gear = find.bySemanticsLabel('분류 관리');
        final scroll = find.byKey(
          const ValueKey('client_list_personal_taxonomy_scroll'),
        );
        final before = tester.getTopLeft(gear);
        expect(
          tester.getSize(find.byType(PersonalTaxonomyFilterStrip)).height,
          32,
        );
        expect(find.byKey(const ValueKey('personal_member_status_filter_bar')),
            findsNothing);
        await tester.drag(scroll, const Offset(-900, 0));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(gear), before);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('예시 chip은 semantics를 제공하고 탭 callback만 실행한다', (tester) async {
    final semantics = tester.ensureSemantics();
    PersonalTaxonomyFilterEntry? selected;
    await tester.pumpWidget(
      _app(
        width: 360,
        entries: _entries(),
        onSelected: (entry) => selected = entry,
      ),
    );
    await tester.tap(
      find.byKey(
        const ValueKey(
          'personal_taxonomy_filter_$personalTaxonomyExampleGroupId',
        ),
      ),
    );
    expect(selected?.id, personalTaxonomyExampleGroupId);
    expect(
      tester
          .widgetList<Semantics>(find.byType(Semantics))
          .any((widget) => widget.properties.label == '모어헬스 예시'),
      isTrue,
    );
    expect(find.byTooltip('VIP 예시'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('통합 chip은 선택 상태 semantics를 제공한다', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _app(
        width: 360,
        entries: _entries(groups: const {'group-a': '센터B'}),
        selectedGroupId: 'group-a',
        selectedStatus: PersonalMemberStatusFilter.expired,
      ),
    );
    final semanticWidgets = tester.widgetList<Semantics>(
      find.byType(Semantics),
    );
    expect(
      semanticWidgets.any(
        (widget) =>
            widget.properties.label == '센터B' &&
            widget.properties.selected == true,
      ),
      isTrue,
    );
    expect(
      semanticWidgets.any(
        (widget) =>
            widget.properties.label == '만료 3' &&
            widget.properties.selected == true,
      ),
      isTrue,
    );
    semantics.dispose();
  });

  testWidgets('group·tag·expired 동시 선택은 역할별 surface와 굵기로 구분된다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        width: 1000,
        entries: _entries(
          groups: const {'group-a': '센터B'},
          tags: const {'tag-vip': 'VIP'},
        ),
        selectedGroupId: 'group-a',
        selectedTagId: 'tag-vip',
        selectedStatus: PersonalMemberStatusFilter.expired,
      ),
    );

    BoxDecoration decorationFor(String id) {
      final chip = find.byKey(ValueKey('personal_taxonomy_filter_$id'));
      final ink = find.descendant(of: chip, matching: find.byType(Ink));
      return tester.widget<Ink>(ink).decoration! as BoxDecoration;
    }

    TextStyle textStyleFor(String id) {
      final chip = find.byKey(ValueKey('personal_taxonomy_filter_$id'));
      final text = find.descendant(of: chip, matching: find.byType(Text));
      return tester.widget<Text>(text).style!;
    }

    final groupDecoration = decorationFor('group-a');
    final tagDecoration = decorationFor('tag-vip');
    final expiredDecoration = decorationFor(personalTaxonomyExpiredStatusId);

    expect(groupDecoration.color, isNot(tagDecoration.color));
    expect(tagDecoration.color, isNot(expiredDecoration.color));
    expect(groupDecoration.border, isA<Border>());
    expect((groupDecoration.border! as Border).top.width, 1.4);
    expect((tagDecoration.border! as Border).top.width, 1.4);
    expect((expiredDecoration.border! as Border).top.width, 1.4);
    expect(textStyleFor('group-a').fontWeight, FontWeight.w900);
    expect(textStyleFor('tag-vip').fontWeight, FontWeight.w900);
    expect(
      textStyleFor(personalTaxonomyExpiredStatusId).fontWeight,
      FontWeight.w900,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('비선택 group·tag·dormant·expired는 같은 크기에서 약한 역할 위계를 유지한다',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _app(
        width: 1000,
        entries: _entries(
          groups: const {'group-a': '센터B'},
          tags: const {'tag-vip': 'VIP'},
        ),
      ),
    );

    Color backgroundFor(String id) {
      final chip = find.byKey(ValueKey('personal_taxonomy_filter_$id'));
      final ink = find.descendant(of: chip, matching: find.byType(Ink));
      return (tester.widget<Ink>(ink).decoration! as BoxDecoration).color!;
    }

    final colors = <Color>{
      backgroundFor('group-a'),
      backgroundFor('tag-vip'),
      backgroundFor(personalTaxonomyDormantStatusId),
      backgroundFor(personalTaxonomyExpiredStatusId),
    };
    expect(colors.length, greaterThanOrEqualTo(3));
    expect(
      tester.getSize(find.byType(PersonalTaxonomyFilterStrip)).height,
      32,
    );
    expect(tester.takeException(), isNull);
  });

  test('empty-state strip은 Firestore 또는 taxonomy service를 직접 호출하지 않는다', () {
    final source = File(
      'lib/widgets/personal_taxonomy_filter_strip.dart',
    ).readAsStringSync();
    expect(source, isNot(contains('FirebaseFirestore')));
    expect(source, isNot(contains('PersonalMemberTaxonomyService')));
    expect(source, isNot(contains('.set(')));
    expect(source, isNot(contains('.update(')));
  });

  for (final theme in <MapEntry<String, ThemeData>>[
    MapEntry('light', lightTheme()),
    MapEntry('dark', darkTheme()),
    MapEntry('lululala', lululalaTheme()),
  ]) {
    testWidgets('${theme.key} empty-state strip이 overflow 없이 표시된다',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _app(width: 320, entries: _entries(), theme: theme.value),
      );
      expect(find.text('MORE THAN GYM'), findsOneWidget);
      expect(find.text('전체'), findsOneWidget);
      expect(find.text('휴면 2'), findsOneWidget);
      expect(find.text('만료 3'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
