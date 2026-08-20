import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtf_app/pages/client_card_page.dart';
import 'package:mtf_app/pages/training_log_consent_page.dart';

void main() {
  List<String> missingFields({
    String name = '',
    String gender = '남',
    String birthText = '2000-01-01',
    String phone = '12',
  }) {
    return clientCardMissingRequiredFields(
      name: name,
      gender: gender,
      birthText: birthText,
      phone: phone,
      hasPhoneDuplicate: false,
      isEnteringCustomLessonType: false,
      customLessonType: '',
    );
  }

  test('canonical membership이 없는 회원은 기간 미등록으로 복원한다', () {
    expect(
      clientCardMembershipNotRegisteredFromCanonical(<String, dynamic>{}),
      isTrue,
    );
    expect(
      clientCardMembershipNotRegisteredFromCanonical(<String, dynamic>{
        'notRegistered': true,
      }),
      isTrue,
    );
  });

  test('기존 membership 기간 데이터와 명시 상태는 그대로 복원한다', () {
    expect(
      clientCardMembershipNotRegisteredFromCanonical(<String, dynamic>{
        'notRegistered': false,
      }),
      isFalse,
    );
    expect(
      clientCardMembershipNotRegisteredFromCanonical(<String, dynamic>{
        'customDays': 120,
      }),
      isFalse,
    );
  });

  test('태그 assignment는 실제 선택값이 바뀐 경우에만 update patch를 보낸다', () {
    expect(
      clientCardPersonalTagsChanged(
        loadedTagIds: const <String>[],
        selectedTagIds: const <String>[],
      ),
      isFalse,
    );
    expect(
      clientCardPersonalTagsChanged(
        loadedTagIds: const <String>['tag_b', 'tag_a'],
        selectedTagIds: const <String>['tag_a', 'tag_b'],
      ),
      isFalse,
    );
    expect(
      clientCardPersonalTagsChanged(
        loadedTagIds: const <String>[],
        selectedTagIds: const <String>['tag_a'],
      ),
      isTrue,
    );
  });

  test('주소 검색 callback은 도로명·지번·우편번호·건물명을 보존한다', () {
    final result = parsePostcodeSearchMessage(
      '{"zonecode":"06236","roadAddress":"서울특별시 강남구 테헤란로 1",'
      '"jibunAddress":"서울특별시 강남구 역삼동 1","buildingName":"모어댄빌딩"}',
    );

    expect(result, isNotNull);
    expect(result!['zonecode'], '06236');
    expect(result['roadAddress'], '서울특별시 강남구 테헤란로 1');
    expect(result['jibunAddress'], '서울특별시 강남구 역삼동 1');
    expect(result['buildingName'], '모어댄빌딩');
    expect(parsePostcodeSearchMessage('not-json'), isNull);
  });

  test('주소 검색 HTML은 callback 가능한 HTTPS origin에서 로드한다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();

    expect(
      source,
      contains("baseUrl: 'https://postcode.map.daum.net/'"),
    );
  });

  test('주소 callback은 canonical 주소 controller와 저장 payload에 연결된다', () {
    final page = File('lib/pages/client_card_page.dart').readAsStringSync();
    final service = File(
      'lib/services/personal_member_card_save_service.dart',
    ).readAsStringSync();
    final callbackStart = page.indexOf('Future<void> _openPostcodeSearch()');
    final callbackEnd = page.indexOf('Future<int?> _askDays', callbackStart);
    final callback = page.substring(callbackStart, callbackEnd);

    expect(callback, contains('_postalC.text = result.zonecode;'));
    expect(callback, contains('_addrC.text = result.displayAddress;'));
    expect(callback, contains('_addrDetailC.text = result.buildingName;'));
    expect(page, contains("_postalC.text = (d['postal'] ?? '').toString();"));
    expect(page, contains("_addrC.text = (d['address'] ?? '').toString();"));
    expect(
      page,
      contains("_addrDetailC.text = (d['detailAddress'] ?? '').toString();"),
    );
    for (final field in <String>['postal', 'address', 'detailAddress']) {
      expect(RegExp("'$field': $field").allMatches(service), hasLength(2));
    }
  });

  test('삭제된 사용자 레슨 종류를 쓰는 기존 회원은 경고와 소속 그룹 높이를 확보한다', () {
    expect(
      clientCardMemberSetupPageHeight(
        isCustomLessonTypeSelected: true,
        isLessonTypeLockedByContract: false,
        isLegacyCurrentLessonType: true,
      ),
      462,
    );
    expect(
      clientCardMemberSetupPageHeight(
        isCustomLessonTypeSelected: true,
        isLessonTypeLockedByContract: false,
        isLegacyCurrentLessonType: false,
      ),
      392,
    );
    expect(
      clientCardMemberSetupPageHeight(
        isCustomLessonTypeSelected: false,
        isLessonTypeLockedByContract: false,
        isLegacyCurrentLessonType: false,
      ),
      348,
    );
  });

  test('320·360·384·411dp 기본정보는 모두 2열 2행 높이를 유지한다', () {
    for (final width in const [320.0, 360.0, 384.0, 411.0]) {
      expect(
        clientCardUsesStackedBasicInfoLayout(width),
        isFalse,
        reason: 'width=$width',
      );
      expect(
        clientCardBasicInfoPageHeight(width),
        260,
        reason: 'width=$width',
      );
    }
  });

  testWidgets('동의 저장 실패 시 화면과 재시도 입력 상태를 유지한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: TrainingLogConsentPage(
          onAgree: () async => throw StateError('network_failure'),
        ),
      ),
    );

    await tester.tap(find.text('동의하고 계속하기'));
    await tester.pumpAndSettle();

    expect(find.byType(TrainingLogConsentPage), findsOneWidget);
    expect(
      find.byKey(const Key('training_log_consent_save_error')),
      findsOneWidget,
    );
    expect(find.text('동의하고 계속하기'), findsOneWidget);
  });

  test('모든 Personal 레슨일지 mutation 진입점에 Semi-Pro gate를 둔다', () {
    final home = File('lib/pages/home_page.dart').readAsStringSync();
    final log =
        File('lib/pages/personal_training_log_page.dart').readAsStringSync();
    final quickSign = File(
      'lib/pages/personal_training_log_quick_sign_page.dart',
    ).readAsStringSync();

    for (final entryPoint in <String>[
      'home_schedule_training_log',
      'home_schedule_quick_sign',
      'home_schedule_lesson_finalize',
      'home_schedule_member_signature_request',
    ]) {
      expect(home, contains("entryPoint: '$entryPoint'"));
    }
    expect(log, contains("entryPoint: 'personal_training_log_direct_route'"));
    expect(
      quickSign,
      contains(
        "entryPoint: 'personal_training_log_quick_sign_direct_route'",
      ),
    );
  });

  test('첫 오류 이동 전에 해당 고객카드 섹션을 펼친다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();

    expect(source, contains('_basicInfoExpansionController.expand();'));
    expect(source, contains('_memberSetupExpansionController.expand();'));
    expect(source, contains('await WidgetsBinding.instance.endOfFrame;'));
    expect(source, contains('Scrollable.ensureVisible('));
  });
  test('Home 일정에서 여는 Personal 고객카드에 canonical owner를 전달한다', () {
    final source = File('lib/pages/home_page.dart').readAsStringSync();

    expect(
      RegExp(
        r'Future<void> _openClientCardFromSchedule\([\s\S]*?'
        r'ClientCardPage\([\s\S]*?'
        r'personalOwnerUid: _isPersonalWorkspace \? _personalOwnerUid : null',
      ).hasMatch(source),
      isTrue,
    );
  });

  test('Personal 고객카드는 legacy profile과 nested member read를 차단한다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();

    expect(
      RegExp(
        r'Future<String> _loadDefaultTrainerName\(\) async \{[\s\S]*?'
        r"collection\('trainer_profiles'\)[\s\S]*?"
        r"collection\('trainer_profile'\)",
      ).hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(
        r'Future<void> _loadCareMilestonesFromFirestore\(\) async \{[\s\S]*?'
        r'if \(_isPersonalWorkspace\)[\s\S]*?return;[\s\S]*?'
        r"collection\('care_milestones'\)",
      ).hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(
        r'Future<void> _loadAchievementBadgesFromFirestore\(\) async \{'
        r'[\s\S]*?if \(_isPersonalWorkspace\)[\s\S]*?return;[\s\S]*?'
        r"collection\('achievement_badges'\)",
      ).hasMatch(source),
      isTrue,
    );
  });

  test('Personal 회원 일정 listener는 owner와 workspace를 모두 제한한다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();

    expect(
      RegExp(
        r'void _bindNextReservationStream\(\) \{[\s\S]*?'
        r"where\('trainerId', isEqualTo: authUid\)[\s\S]*?"
        r"where\('workspaceType', isEqualTo: 'personal'\)[\s\S]*?"
        r"where\('memberId', isEqualTo: cleanMemberId\)",
      ).hasMatch(source),
      isTrue,
    );
    expect(source, contains("if (data['isArchived'] == true) return false;"));
    expect(source, contains("if (data['voided'] == true) return false;"));
  });

  test('Personal 회원 일정 연결 해제도 owner와 workspace를 모두 제한한다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();
    final methodStart = source.indexOf(
      'Future<void> _unlinkSchedulesFromDeletedMember',
    );
    final methodEnd = source.indexOf(
      'Future<void> _softDeleteMember()',
      methodStart,
    );
    final methodSource = source.substring(methodStart, methodEnd);

    expect(
      methodSource,
      contains("where('trainerId', isEqualTo: authUid)"),
    );
    expect(
      methodSource,
      contains("where('workspaceType', isEqualTo: 'personal')"),
    );
    expect(
      methodSource,
      contains("where('memberId', isEqualTo: cleanMemberId)"),
    );
    expect(methodSource, contains("authUid != _personalOwnerUid"));
  });

  test('고객카드 주요 진입점은 Personal owner를 전달한다', () {
    final list = File('lib/pages/client_list_page.dart').readAsStringSync();
    final home = File('lib/pages/home_page.dart').readAsStringSync();

    expect(
      RegExp(
        r'Future<void> _openEdit\(Member member\) async[\s\S]*?'
        r'ClientCardPage\.edit\([\s\S]*?personalOwnerUid: widget\.personalOwnerUid',
      ).hasMatch(list),
      isTrue,
    );
    expect(
      RegExp(
        r'Future<void> _openCreate\(\) async[\s\S]*?'
        r'ClientCardPage\.newMember\([\s\S]*?personalOwnerUid: owner\.isEmpty \? null : owner',
      ).hasMatch(list),
      isTrue,
    );
    expect(
      RegExp(
        r'Future<void> _openClientCardFromSchedule\([\s\S]*?'
        r'ClientCardPage\([\s\S]*?personalOwnerUid: _isPersonalWorkspace \? _personalOwnerUid : null',
      ).hasMatch(home),
      isTrue,
    );
  });

  test('Home 고객카드 소유권 로그는 UID 원문을 출력하지 않는다', () {
    final source = File(
      'lib/services/home_member_lookup_service.dart',
    ).readAsStringSync();

    expect(source, isNot(contains("'uid=\$owner")));
    expect(source, isNot(contains('memberId=\$cleanId')));
    expect(source, contains('ownerScope='));
  });

  test('고객카드 Firestore listener 오류는 onError에서 안전하게 처리한다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();

    expect(source, contains('[MTF_FIRESTORE_ERROR_HANDLED]'));
    expect(source, contains('[MTF_LEGACY_READ_BLOCKED]'));
    expect(source, contains('[MTF_CANONICAL_READ]'));
    expect(
      RegExp(
        r'_nextReservationSub = query\.snapshots\(\)\.listen\([\s\S]*?'
        r'onError: \(Object error, StackTrace stackTrace\)',
      ).hasMatch(source),
      isTrue,
    );
  });

  test('Personal 신규 고객카드는 문서 생성 전에 member get과 listener를 시작하지 않는다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();
    final methodStart = source.indexOf(
      'Future<void> _loadInitialNewClientCardData() async',
    );
    final methodEnd = source.indexOf(
      'void _bindPersonalMemberPreferences()',
      methodStart,
    );
    final methodSource = source.substring(methodStart, methodEnd);

    expect(
      RegExp(
        r'if \(allowed\) \{\s*await _loadInitialNewClientCardData\(\);',
      ).hasMatch(source),
      isTrue,
    );
    expect(
      RegExp(
        r'_loadMemberGroupOptions\(\)[\s\S]*?'
        r'_fillDefaultTrainerIfEmpty\(\)[\s\S]*?'
        r'_isClientCardLoaded = true',
      ).hasMatch(methodSource),
      isTrue,
    );
    expect(methodSource, isNot(contains('_loadFromFirestore()')));
    expect(methodSource, isNot(contains('_bindMemberStatsStream()')));
    expect(methodSource, isNot(contains('_bindNextReservationStream()')));
  });

  test('Personal 휴대폰 중복 조회는 현재 owner와 workspace로 제한한다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();
    final methodStart = source.indexOf(
      'Future<bool> _ensurePhoneIsNotDuplicatedBeforeSave() async',
    );
    final methodEnd = source.indexOf(
      'List<String> _missingRequiredFields()',
      methodStart,
    );
    final methodSource = source.substring(methodStart, methodEnd);

    expect(
      methodSource,
      contains("where('trainerId', isEqualTo: _personalOwnerUid)"),
    );
    expect(
      methodSource,
      contains("where('workspaceType', isEqualTo: 'personal')"),
    );
    expect(
      methodSource,
      contains('query.where(target.key, isEqualTo: value)'),
    );
    expect(
      methodSource,
      contains('if (_isPersonalWorkspace && !_isEditMode)'),
    );
  });

  test('검증 실패 재시도는 같은 입력칸을 다시 포커스하고 키보드를 표시한다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();

    expect(source, contains('final _nameFocusNode = FocusNode();'));
    expect(source, contains('final _phoneFocusNode = FocusNode();'));
    expect(source, contains('_validationFocusCoordinator.cancelPending();'));
    expect(source, contains('await waitForFocusSettlement();'));
    expect(source, contains('if (!focusNode.hasFocus)'));
    expect(
      source,
      contains(
        "SystemChannels.textInput.invokeMethod<void>('TextInput.show')",
      ),
    );
    expect(
      source,
      contains(
        '_scrollToBasicInfoField(\n'
        '        _phoneFieldKey,\n'
        '        focusNode: _phoneFocusNode,',
      ),
    );
  });

  test('이름과 전화번호가 모두 오류면 저장 1·2·3회 모두 이름이 첫 오류다', () {
    for (var attempt = 1; attempt <= 3; attempt++) {
      final missing = missingFields();
      expect(missing.first, '이름', reason: '$attempt회차');
      expect(missing, contains('전화번호'), reason: '$attempt회차');
      expect(
        clientCardValidationPassed(
          formValid: true,
          missingRequiredFields: missing,
        ),
        isFalse,
        reason: '오프스크린 Form validator가 true여도 $attempt회차 저장 차단',
      );
    }
  });

  test('이름이 정상이 된 뒤에는 반복 저장마다 전화번호가 첫 오류다', () {
    for (var attempt = 1; attempt <= 2; attempt++) {
      final missing = missingFields(name: 'DEVTEST');
      expect(missing.first, '전화번호', reason: '$attempt회차');
      expect(missing, isNot(contains('이름')), reason: '$attempt회차');
      expect(
        clientCardValidationPassed(
          formValid: true,
          missingRequiredFields: missing,
        ),
        isFalse,
        reason: '오프스크린 전화번호 오류가 남은 $attempt회차 저장 차단',
      );
    }
  });

  test('Form과 현재값 오류 목록이 모두 정상일 때만 저장 검증을 통과한다', () {
    expect(
      clientCardValidationPassed(
        formValid: true,
        missingRequiredFields: const <String>[],
      ),
      isTrue,
    );
    expect(
      clientCardValidationPassed(
        formValid: false,
        missingRequiredFields: const <String>[],
      ),
      isFalse,
    );
  });

  testWidgets('반복 저장 focus 요청은 이전 필드가 focused여도 현재 첫 오류만 유지한다', (
    tester,
  ) async {
    final nameFocusNode = FocusNode();
    final phoneFocusNode = FocusNode();
    final coordinator = ClientCardValidationFocusCoordinator();
    var keyboardShowCount = 0;
    addTearDown(nameFocusNode.dispose);
    addTearDown(phoneFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(focusNode: nameFocusNode),
              TextField(focusNode: phoneFocusNode),
            ],
          ),
        ),
      ),
    );

    Future<bool> focus(FocusNode focusNode) {
      coordinator.cancelPending();
      return coordinator.refocus(
        focusNode: focusNode,
        unfocusCurrent: () => FocusManager.instance.primaryFocus?.unfocus(),
        waitForFocusSettlement: tester.pump,
        showKeyboard: () async {
          keyboardShowCount++;
        },
      );
    }

    for (var attempt = 1; attempt <= 3; attempt++) {
      phoneFocusNode.requestFocus();
      await tester.pump();

      expect(await focus(nameFocusNode), isTrue, reason: '$attempt회차');
      expect(nameFocusNode.hasFocus, isTrue, reason: '$attempt회차');
      expect(phoneFocusNode.hasFocus, isFalse, reason: '$attempt회차');
    }

    for (var attempt = 1; attempt <= 2; attempt++) {
      nameFocusNode.requestFocus();
      await tester.pump();

      expect(await focus(phoneFocusNode), isTrue, reason: '$attempt회차');
      expect(phoneFocusNode.hasFocus, isTrue, reason: '$attempt회차');
      expect(nameFocusNode.hasFocus, isFalse, reason: '$attempt회차');
    }

    expect(keyboardShowCount, 5);
  });

  testWidgets('늦게 완료된 이전 focus callback은 새 첫 오류를 덮어쓰지 않는다', (
    tester,
  ) async {
    final nameFocusNode = FocusNode();
    final phoneFocusNode = FocusNode();
    final coordinator = ClientCardValidationFocusCoordinator();
    final staleSettlement = Completer<void>();
    var staleKeyboardShowCount = 0;
    var currentKeyboardShowCount = 0;
    addTearDown(nameFocusNode.dispose);
    addTearDown(phoneFocusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              TextField(focusNode: nameFocusNode),
              TextField(focusNode: phoneFocusNode),
            ],
          ),
        ),
      ),
    );

    final staleRequest = coordinator.refocus(
      focusNode: phoneFocusNode,
      unfocusCurrent: () => FocusManager.instance.primaryFocus?.unfocus(),
      waitForFocusSettlement: () => staleSettlement.future,
      showKeyboard: () async {
        staleKeyboardShowCount++;
      },
    );

    coordinator.cancelPending();
    final currentResult = await coordinator.refocus(
      focusNode: nameFocusNode,
      unfocusCurrent: () => FocusManager.instance.primaryFocus?.unfocus(),
      waitForFocusSettlement: tester.pump,
      showKeyboard: () async {
        currentKeyboardShowCount++;
      },
    );

    staleSettlement.complete();
    final staleResult = await staleRequest;

    expect(staleResult, isFalse);
    expect(currentResult, isTrue);
    expect(nameFocusNode.hasFocus, isTrue);
    expect(phoneFocusNode.hasFocus, isFalse);
    expect(staleKeyboardShowCount, 0);
    expect(currentKeyboardShowCount, 1);
  });

  test('기본정보 PageView는 2열 2행과 주소 페이지의 자연 높이를 수용한다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();
    final methodStart = source.indexOf('Widget _basicInfoSection()');
    final methodEnd = source.indexOf(
      'Widget _memberSetupSection()',
      methodStart,
    );
    final methodSource = source.substring(methodStart, methodEnd);

    expect(
      methodSource,
      contains('height: clientCardBasicInfoPageHeight(viewportWidth),'),
    );
    expect(methodSource, isNot(contains('if (useStackedLayout)')));
    expect(
      methodSource,
      contains('Expanded(flex: 5, child: buildNameField())'),
    );
    expect(
      methodSource,
      contains('Expanded(flex: 4, child: buildGenderField())'),
    );
    expect(
      methodSource,
      contains('Expanded(flex: 3, child: buildBirthField())'),
    );
    expect(
      methodSource,
      contains('Expanded(flex: 2, child: buildJobField())'),
    );
    expect(methodSource, isNot(contains('height: 236,')));
  });

  test('신규와 기존 고객카드는 같은 DEV viewport wrapper를 사용한다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();

    expect(source, contains('return DevClientCardViewport('));
    expect(source, contains('child: _buildClientCardContent(context)'));
    expect(source, contains('Widget _buildClientCardContent('));
  });

  test('검증 실패 return은 Personal create 진입보다 앞에 있다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();
    final methodStart = source.indexOf('Future<void> _submitAndStay() async');
    final methodEnd = source.indexOf(
      'Future<void> _resetForm() async',
      methodStart,
    );
    final methodSource = source.substring(methodStart, methodEnd);

    final invalidBranch = methodSource.indexOf('if (!valid)');
    final invalidReturn = methodSource.indexOf('return;', invalidBranch);
    final createCall = methodSource.indexOf('.createAndVerify(');
    expect(invalidBranch, greaterThanOrEqualTo(0));
    expect(invalidReturn, greaterThan(invalidBranch));
    expect(createCall, greaterThan(invalidReturn));
  });

  test('Personal 생성과 수정은 같은 성별·생년월일 저장 계약을 사용한다', () {
    final source = File('lib/pages/client_card_page.dart').readAsStringSync();
    final methodStart = source.indexOf('Future<void> _submitAndStay() async');
    final methodEnd = source.indexOf(
      'Future<void> _resetForm() async',
      methodStart,
    );
    final methodSource = source.substring(methodStart, methodEnd);

    expect(methodSource, isNot(contains("_gender == '남성'")));
    expect(RegExp(r'gender: _gender,').allMatches(methodSource), hasLength(2));
    expect(
      RegExp(r'birthDate: _birthTextC\.text,').allMatches(methodSource),
      hasLength(2),
    );
    final updateCall = methodSource.indexOf('.updateAndVerify(');
    final directWrite = methodSource.indexOf(
      'final raw = _collectFormMap(includeRegisteredAt: true);',
    );
    expect(updateCall, greaterThanOrEqualTo(0));
    expect(updateCall, lessThan(directWrite));
  });
}
