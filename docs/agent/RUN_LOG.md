# RUN_LOG

## 2026-08-03 AIFC 계약 버튼 조밀 UI·중앙 gate 회귀 수정

- 원인: `HomeLessonQuickActionsSection.buildQuickAction()`의 계약 전용 분기가 아이콘 영역을 `26×26`으로 키우고 설명 `Column`과 최대 폭 `170`을 추가해 다른 quick action보다 카드가 커졌다. 같은 분기가 `canUse*` 값을 카드 내부에서 다시 판단해 제목 아래에 설명·등급 문구를 렌더링했다.
- UI 수정: 모든 AIFC quick action을 공통 `145×34`, horizontal padding 9, radius 14, icon 16, title 11 구조로 통일했다. 레슨계약서·회원권계약서는 제목만 표시하며 배경 `0xFFFFFBEB`, 테두리 `0xFFF2C56B`, 네이비 텍스트 `0xFF172554`, 앰버 아이콘 `0xFFB45309`만 정적으로 적용했다. glow/pulse/배지/그림자/크기 확대는 없다.
- gate 수정: 계약 카드 자체의 tier 문구·비활성 분기를 제거하고 탭을 기존 Home 진입 메서드에 위임했다. 레슨계약서는 `AppTierFeatureKey.contract`, 회원권계약서는 기존 정책인 `AppTierFeatureKey.membershipContract`의 `AifcTierFeatureGateSheet.guard()`를 계속 사용한다. AIFC 추천업무와 기존 빠른 작업은 유지했다.
- 실기기 추가 결함과 최소 수정: 첫 Galaxy 허용 경로에서 신규 레슨계약서가 Personal owner 없이 `trainer_profile/me`·`lesson_products`를 읽고, 저장하지 않고 닫아도 존재하지 않는 신규 member 문서를 재조회해 permission-denied/unhandled가 발생했다. `ContractPage`에 canonical Personal owner를 전달하고 Personal 신규 계약에서 legacy trainer/product read를 생략했다. 신규 회원권계약서는 `loadExistingDraft=false`로 존재하지 않는 하위 문서 read를 생략하며, 두 흐름 모두 저장 성공 전 member readback을 하지 않는다.
- 자동 검증: 관련 Flutter 12개, 전체 Flutter 511개 통과. 320/360/384/411dp overflow 0, 공통 카드 크기·제목 전용 표시·amber 스타일·중앙 gate 위임을 확인했다. 변경 범위 analyze는 error 0이며 기존 warning/info 161건, `git diff --check` 통과, DEV Debug APK `build/app/outputs/flutter-apk/app-dev-debug.apk` 빌드 통과.
- Galaxy `R3CX40M6EEM`: `com.example.mtf_app.dev`만 데이터 보존 업데이트 설치했다. UI hierarchy에서 기존 회원 연결·내 회원으로 등록·레슨계약서·회원권계약서가 모두 물리 `544×127px`로 동일했고, 계약 카드 내부는 제목만 있었다. 스크린샷에서 연한 앰버 강조와 조밀한 2열 배치를 확인했다. 키보드 열린 상태에서 viewInsets가 적용되고 저장 영역 겹침·RenderFlex overflow는 없었다.
- 등급 실증: Amateur에서 레슨계약서는 Semi-Pro gate, 회원권계약서는 Pro gate로 차단됐다. Semi-Pro에서 레슨계약서 작성 화면에 진입했고 회원권계약서는 기존 Pro gate로 유지됐다. Pro에서 회원권계약서 작성 화면에 진입했다. 최종 재설치 후 허용 경로 진입·미저장 닫기에서 `trainer_profile/me`, `lesson_products`, `membership_contracts` permission-denied와 unhandled 재발은 0이었다.
- 종료 상태: DEV 프로세스 기준 permission-denied, unhandled, fatal, ANR, RenderFlex/BOTTOM overflow, PROD marker는 모두 0. fixture는 `서버 실제 등급`으로 복원했고 로그상 서버 tier Amateur를 변경하지 않았다. 회원·일정·계약서 저장은 하지 않았다.
- 미작업: PROD package, PROD Firebase, Functions·Rules·indexes·Storage 배포, PROD APK/AAB, `pm clear`, git commit/push는 수행하지 않았다. 증적은 `artifacts/aifc_contract_buttons_20260803`에 보존했다.

## 2026-08-03 레슨 등록 AIFC·회원 추천 UI 회귀 수정

- 원인: 신규 레슨 등록에서 `HomeLessonQuickActionsSection` 호출이 `isEditMode` 조건 안에 있어 AIFC 추천업무 전체가 숨겨졌다. 회원 검색 결과는 계산됐지만 이름 입력칸이 아니라 폼 하단 `HomeRecentMembersSection`에 렌더링되어 최근 등록 회원과 검색 추천의 의미·위치가 섞였다. 기존 테스트는 helper와 분리 위젯만 확인해 Home 신규 등록 call-site와 입력칸 직하단 배치를 잡지 못했다.
- 수정: `lib/pages/home_page.dart`에서 AIFC 섹션을 신규/수정 공통으로 렌더링하고 이름 입력 구역의 `suggestions` 슬롯에 검색 목록을 연결했다. `home_lesson_editor_fields.dart`는 입력 Row 바로 아래에 suggestions를 배치한다. `home_recent_members_section.dart`는 빈 입력의 `최근 등록 회원`과 검색 중 `회원 검색 추천`을 분리하고, owner-scoped `members` 후보를 `createdAt` 내림차순으로 정렬하며 전화번호 뒤 4자리만 마스킹한다.
- AIFC: `home_lesson_quick_actions_section.dart`에서 `AIFC 추천업무`와 기존 작업을 유지했다. 레슨계약서·회원권계약서는 정적 웜 앰버 배경/테두리와 네이비 텍스트를 사용하고 pulse/glow를 사용하지 않는다. 신규 등록의 잠긴 계약 카드도 중앙 tier gate를 재사용한다.
- 실기기 추가 결함: 태블릿 일정 저장 때 resume와 scheduleSnapshot 위젯 동기화가 겹쳐 `personal_widget_owner_readback_failed` unhandled가 1회 발생했다. `HomeWidgetSyncController`가 in-flight Future를 직렬화하지 않고 `unawaited`로 방치한 것이 원인이었다. 공통 컨트롤러에서 sync action을 직렬화하고 실패 Future를 격리했으며 동시 요청 순서와 실패 후 다음 요청 실행 테스트를 추가했다.
- 자동 검증: 관련 Flutter 30개, 전체 Flutter 506개, 전체 Firebase Emulator suite, Functions TypeScript build 통과. `flutter analyze --no-pub` error 0, 기존 기준과 같은 warning 246/info 955(총 1,201). `git diff --check`, DEV Kotlin compile, merged DEV Manifest package 및 widget provider 3개, DEV Debug APK 통과.
- 태블릿 `TO2408FB00746`: AIFC 추천업무와 계약 카드 2개, 빈 입력 최근 회원 3건 `createdAt` 최신순, `DEV` 3건, `홍` 2건, 현재 helper 규칙의 `ㅎㄱㄷ` 초성 후보, 입력칸 직하단 목록, 마스킹, 키보드/저장 버튼 비겹침을 확인했다. 추천 선택 후 서버 일정 readback에서 기존 `memberId` 연결 1건, owner/name 일치, 회원 수 유지로 중복 생성 0을 확인했다. 최신 controller 재설치 후 동일 저장에서 owner readback/unhandled 재발 0이었다.
- Galaxy `R3CX40M6EEM`: `com.example.mtf_app.dev`만 데이터 보존 업데이트 설치·실행했다. 실제 휴대폰 폭에서 AIFC/앰버 계약 카드/최근 회원 가독성, 키보드 viewInsets, `DEVTEST` 검색 목록의 입력칸 직하단 배치, 마스킹, 추천 터치, 선택 후 목록 닫힘, 저장 버튼 비겹침을 확인했다. 저장하지 않아 Galaxy DEV write는 0이다.
- 종료 로그: 태블릿 최신 재검증의 permission-denied, unhandled, fatal, ANR, RenderFlex overflow, PROD marker는 모두 0. Galaxy 패턴의 Play Store·Samsung Browser `ServiceANR` 문자열 2건은 DEV package/component와 무관하며 DEV 앱 오류 패턴은 0이다.
- 데이터 원복: 태블릿에서 이번 회원 3건과 일정 1건만 삭제하고 tier Beginner, managed/member/schedule/fixture 0, lifetime 시작값 2를 readback했다. Galaxy 기존 DEV 데이터는 변경하지 않았다.
- 미작업: PROD Firebase, PROD package/위젯, Firebase 배포, PROD APK/AAB, `pm clear`, git commit/push는 수행하지 않았다.
- 증적: `artifacts/lesson_editor_ui_regression_20260803/tablet`, `galaxy_lesson_editor.png`, `galaxy_keyboard.png`, `galaxy_search.png`, `galaxy_selected.png`, `flutter_analyze_widget_serial_final_cmd.txt`.

## 2026-07-27 PROD 1.0.4 코드·저장소 release blocker 수정·검증

### createManagedMember 하위 호환
- 변경되지 않은 1.0.3 호출 경로 `ManagedMemberWorkspaceService.createMember()`의 실제 payload는 `idempotencyKey`, `name`, `gender`, `phone`, `activityRegion`, `note`이며 생년월일 필드를 보내지 않는다. 현재 1.0.4 고객카드 경로 `PersonalMemberCardSaveService.createAndVerify()`는 `birthDate`와 주소·레슨 canonical 필드를 보낸다.
- 기존 `createManagedMemberHandler()`가 모든 요청에서 `requiredBirthDate()`를 먼저 호출해 1.0.3 요청을 `birthDate_required`로 거부하는 것이 선배포 비호환 원인이었다. `optionalCreateBirthDate()` compatibility layer를 추가해 `birthDate` key가 아예 없는 legacy 요청만 허용하고, key가 제공된 요청은 기존 날짜 형식·실재일·연령 검증을 그대로 적용한다.
- legacy 생성은 생년월일 필드를 추측하거나 채우지 않는다. 신규 요청은 계속 `birth`, `birthDisplay`, `birthAt`을 canonical 저장한다. 같은 idempotency key의 legacy 재요청은 기존 신규 회원 문서를 rewrite하지 않는다.
- 인증 필수, 서버 Auth UID 기반 `trainerId`, `workspaceType=personal`, owner 범위 전화번호 중복 query, identity 주입 차단, legacy `groupId/groupName` 미생성, 식별자·전화번호 원문 미로그 정책은 유지됐다.

### Exact alarm 최소 정리
- 실제 exact 호출은 `MainActivity.onCreate()` → `MtfWidgetWeekRolloverReceiver.scheduleNext()/scheduleNextTimeRefresh()` → `setExactAndAllowWhileIdle()`였다. 용도는 월요일 00:01 및 30분 경계의 위젯 UI refresh이고, 기존 구현도 권한 부재 시 `setAndAllowWhileIdle()`로 정상 fallback했으므로 정확 시각이 필수인 사용자 알람 계약은 아니었다.
- receiver를 `setAndAllowWhileIdle()` 단일 경로로 바꾸고 main Manifest의 `SCHEDULE_EXACT_ALARM`을 제거했다. 일반 레슨 알림은 기존 `AndroidScheduleMode.inexactAllowWhileIdle`을 유지한다.
- DEV merged Manifest에서 exact alarm 권한 없음, `POST_NOTIFICATIONS`·`RECEIVE_BOOT_COMPLETED` 유지, 주간·다음 레슨·오늘 레슨 provider 3개와 rollover receiver 유지를 확인했다.

### 자동 검증
- 관련 Flutter 115개, 전체 Flutter 474개 통과.
- managed member Emulator 52개 통과. 신규 4개는 1.0.3 no-birth 성공·생년월일 필드 미생성, supplied invalid birth 거부, 1.0.4 canonical birth 저장, legacy idempotent retry 비rewrite다.
- 전체 Emulator suite 통과: managed member 52, Personal schedules 27, Personal training logs 38, legacy workspace 28, profile bootstrap 30, anonymous identity 26, nickname/profile 22, platform-admin unit·password Emulator.
- Functions TypeScript build 통과. 전체 analyze는 error 0, 기존 warning 246·info 955로 총 1,201개가 기준과 동일하다. `git diff --check` 오류 0.
- DEV `compileDevDebugKotlin`, merged Manifest, DEV Debug APK `build/app/outputs/flutter-apk/app-dev-debug.apk`가 통과했다. PROD APK/AAB는 빌드하지 않았다.

### 저장소 분류와 release allowlist
- 최종 문서 기록 전 기준 tracked 수정 43개, 실제 untracked 56개였다. 이번 task는 기존 파일 삭제·이동·git add·commit·push를 하지 않았다.
- release 제품/config allowlist는 현재 tracked 제품 34개와 `analysis_options.yaml`, 아래 untracked 제품 7개다: `MtfWidgetIntentFactory.kt`, `dev_tier_fixture.dart`, `personal_member_card_save_service.dart`, `personal_member_consent_service.dart`, `personal_member_preferences_service.dart`, `dev_client_card_viewport.dart`, `personal_training_log_entry_guard.dart`.
- release 테스트 allowlist는 tracked 6개(`firebase-emulator-tests` 2개, tracked Flutter test 4개)와 아래 untracked 8개다: `dev_home_regressions_test.dart`, `dev_validation_tools_test.dart`, `home_deleted_member_schedule_service_test.dart`, `home_widget_owner_storage_test.dart`, `personal_customer_card_regression_test.dart`, `personal_member_card_save_service_test.dart`, `personal_member_preferences_test.dart`, `personal_training_log_entry_guard_test.dart`.
- release 문서 allowlist는 `docs/agent/RUN_LOG.md`, `docs/agent/BACKLOG.md`다. 따라서 선별 staging 후보는 총 58개이며, 실제 staging 전 `git diff` 재감사가 필요하다.
- release commit 제외: untracked 프로젝트 문서 12개(`README_FIRST.md`, `VALIDATION_SUMMARY.md`, agent audit 10개), prompt 문서 25개, 명백한 임시 4개(`_ProChip`, `callable-body.json`, `mtf_codex_loop_starter.zip`, 중첩 0바이트 font). `artifacts/` 766개 약 326 MiB는 ignore된 증적이며 `dev_firestore_probe.cjs`는 DEV project만 명시한 일회성 검증 probe라 제품 코드가 아니다.
- 미추적 제품 7개는 모두 현재 제품 코드에서 import/reference돼 release commit에 빠지면 컴파일 또는 기능 계약이 깨진다. 미추적 테스트 8개도 해당 제품 변경의 회귀 근거다. 검사 대상 제품·테스트에서 secret/keystore/service-account 의심 파일은 발견되지 않았다.
- DEV tier fixture와 viewport는 각각 `kDebugMode && AppEnvironmentConfig.isDev`, DEV banner는 `AppEnvironmentConfig.isDev`와 fixture availability로 차단된다. PROD 환경 무시 테스트가 통과했고 Firestore tier write 경로는 없다. 최종 PROD AAB 문자열 감사는 release build 승인 후 별도 필요하다.

### 남은 release blocker와 보호
- 코드-level `createManagedMember` 호환 및 exact alarm 정책 blocker는 해소됐다. 저장소 blocker는 필수 untracked 15개를 포함한 58개 allowlist의 선별 commit이 아직 없다는 점이다.
- Android release는 여전히 `signingConfigs.getByName("debug")`를 사용하므로 배포용 signing 전환이 별도 blocker다. 로컬 버전 `1.0.3+4`는 이번 task에서 변경하지 않았다.
- PROD Firebase 조회·수정·배포, DEV/PROD Functions·Rules·indexes·Storage 배포, PROD APK/AAB, Galaxy 설치·조작, version/signing/keystore 변경, Play Console, git stage·commit·push는 모두 0건이다.

## 2026-07-26 고객카드 stale 최근 회원 캐시 최종 완료

### 최종 수정
- stale 최근 회원은 별도 preference cache가 아니라 `HomePage._bindScheduleStream()`의 Firestore 로컬 `schedules` snapshot에서 나온 `memberId` 집합이었다. 기존 `HomeDeletedMemberScheduleService.deletedMemberIdsFromScheduleDocs()`는 owner 조건 없는 document-ID `whereIn`으로 `members`를 조회해 Personal Rules의 query 제약을 위반했다.
- member 조회를 현재 owner의 `trainerId`와 `workspaceType=personal`로 제한하고 schedule ID와 owner 회원 결과를 로컬 교집합 처리했다. missing·deleted·pending-delete ID는 화면에서 제외하며 owner 없는 fallback, `FieldPath.documentId`, legacy 재시도는 사용하지 않는다.
- cache/pending schedule snapshot은 stale ID를 UI에서 제외하되 cleanup write 근거로 사용하지 않고 authoritative server snapshot에서만 기존 unlink cleanup을 허용한다. member resolution 실패는 Home에서 식별자 없는 error code만 남기고 schedule 영역을 빈 상태로 전환해 unhandled exception을 차단한다.
- 첫 실기기 재현에서 확인된 별도 `permission-denied`는 Personal 일정 저장 후 `HomeScheduleFirestoreService.refreshMemberNextLesson()`가 Rules상 Function 전용인 `members.nextLessonAt`을 직접 쓰던 경로였다. `shouldPersistMemberNextLessonCache()`로 Personal owner가 있으면 이 legacy 파생 캐시 write를 생략하고 legacy workspace 동작만 유지했다. canonical Personal 일정은 계속 owner-scoped top-level `schedules`가 기준이다.

### 자동 검증
- stale·일정·고객카드 관련 Flutter 86개, 전체 Flutter 459개가 통과했다.
- Personal schedules Rules Emulator 27개가 실제 exit 0으로 통과했다. 전체 Emulator 묶음도 managed member 48, Personal schedules 27, Personal training logs 38, legacy 28, profile 30, anonymous identity 26, nickname/profile 22, platform-admin unit·password Emulator가 모두 통과했다.
- 변경 범위 analyze는 신규 error 0이며 큰 `home_page.dart`의 기존 warning/info 62개가 기준 상태와 동일했다. `git diff --check` 오류 0, DEV Debug APK build 성공, 지정 기기 `flutter run --flavor dev -t lib/main_dev.dart -d TO2408FB00746 --debug --no-pub --no-resident` 데이터 보존 업데이트 설치가 성공했다.

### TO2408FB00746 stale cache 재실행
- 서버 Beginner·회원 0·일정 0·custom type 0 기준선에서 승인된 현재 DEV profile의 tier 한 필드만 update-time precondition으로 Amateur로 임시 변경했다. 합성 회원 1건을 생성해 고객리스트 총 1명과 Home 일정 sheet의 최근 등록 회원 표시를 확인했다.
- 해당 회원 연결 DEV 일정 1건 저장은 authoritative schedule snapshot 1건으로 완료됐고, 수정 후 `members.nextLessonAt` 직접 write와 permission-denied는 발생하지 않았다.
- 로컬 schedule cache를 보존하기 위해 앱을 force-stop한 뒤 이번 회원 1건과 일정 1건만 update-time precondition으로 서버에서 삭제했다. 첫 재실행은 `fromCache=true docCount=1` 뒤 `fromCache=false docCount=0`으로 수렴했고, cache 1건 단계에서도 삭제 회원 일정은 UI에 표시되지 않았다.
- 첫 재실행의 최근 회원 sheet에서 삭제 회원이 사라졌고 고객리스트는 총 0명이었다. 두 번째 완전 재실행은 첫 cache snapshot부터 `docCount=0`이어서 같은 삭제 ID를 다시 조회할 입력 자체가 제거됐음을 확인했다.
- 두 재실행 모두 stale member resolution permission-denied 0, unhandled exception 0, fatal crash 0, ANR 0, PROD project marker 0이었다. Personal Home은 정상 진입했고 화면·터치·레이아웃 blocker는 없었다.

### 완료·원복
- 기존 통과 결과인 Kakao callback, 주소 저장·readback·재진입·재실행, 사용자 레슨 종류, 기본 그룹 표시명, 고객카드 5개 진입, canonical schedules query, 320/360/390/411dp viewport, legacy 요청 0, overflow 0과 이번 stale 재실행 결과를 합쳐 고객카드 잔여 묶음을 완료 처리했다.
- 최종 서버 readback은 tier Beginner, managed members 0, schedules 0, managed count 0, customLessonTypes 0, memberDefaultGroupLabel `MORE THAN GYM`이다. DEV 앱은 force-stop 상태로 종료했다.
- 증적은 `artifacts/customer_card_stale_cache_fix_20260726/automated/`와 `artifacts/customer_card_stale_cache_fix_20260726/device/`에 보존했고 텍스트 증적의 UID/memberId/전화번호 패턴을 마스킹했다.
- Firestore Rules·indexes·Functions·Storage 배포, PROD 접근, Galaxy 조작, uninstall, `pm clear`, 앱 데이터 초기화는 수행하지 않았다. Semi-Pro·개인정보 동의·위젯 회귀 묶음으로 이동하지 않았다.

## 2026-07-26 고객카드 stale 최근 회원 캐시 owner-scope 수정 및 실기기 중단

### 원인과 최소 수정
- 삭제된 최근 회원 ID의 출처는 별도 `SharedPreferences` 목록이 아니라 `HomePage._bindScheduleStream()`이 받은 Firestore 로컬 `schedules` snapshot이었다. `HomeDeletedMemberScheduleService.deletedMemberIdsFromScheduleDocs()`가 schedule의 `memberId`를 모은 뒤 owner 조건 없이 `members where __name__ in [...]`을 실행해 Personal Rules의 owner query 요구를 위반했다.
- 같은 stream listener 안의 awaited member resolution에 예외 방어가 없어 `permission-denied`가 unhandled future로 전파됐다. cache snapshot을 근거로 바로 cleanup write를 실행하면 이미 삭제된 서버 일정 문서를 되살릴 위험도 있었다.
- `HomeDeletedMemberScheduleService.deletedMemberIdsFromScheduleDocs()`를 현재 Personal owner UID 필수 인자로 변경하고 `members.where('trainerId', isEqualTo: ownerUid).where('workspaceType', isEqualTo: 'personal')`만 조회한 뒤 schedule ID와 로컬 교집합을 계산하도록 수정했다. `FieldPath.documentId`/owner 없는 fallback/legacy 재시도는 제거했다.
- missing·`isDeleted=true`·`deleteStatus=pending_delete` 회원만 stale ID로 판정한다. cache 또는 pending-write schedule snapshot에서는 UI에서 제외하되 cleanup write를 금지하고, 서버 authoritative snapshot에서만 기존 schedule unlink cleanup을 허용한다.
- Home의 member resolution을 `try/catch`로 감싸 실패 시 ID나 개인정보 없이 error code만 기록하고 schedule UI를 안전한 빈 상태로 전환해 unhandled exception을 차단했다.

### 자동 검증
- 신규 `test/home_deleted_member_schedule_service_test.dart` 7개와 고객카드·Home 관련 묶음 80개가 통과했다. 빈 ID query 0, owner/workspace 조건, owner 없는 document-ID query 부재, missing ID 일부·전체 제거, cache/pending cleanup write 차단, Home 예외 방어와 ID 미노출을 확인했다.
- 전체 Flutter 테스트 458개 통과. Personal schedules Emulator 27개와 전체 Emulator 묶음(managed member 48, schedules 27, training logs 38, legacy 28, profile 30, anonymous identity 26, nickname/profile 22, platform-admin unit·Emulator)이 모두 통과했다.
- 변경 범위 analyze는 신규 error 0이며 큰 Home 파일의 기존 warning/info 62개만 유지됐다. `git diff --check` 오류 0, DEV Debug APK build 성공, `flutter run --flavor dev -t lib/main_dev.dart -d TO2408FB00746 --debug --no-pub --no-resident` 데이터 보존 업데이트 설치가 성공했다.

### TO2408FB00746 실기기 중단
- DEV project/package와 서버 Beginner·회원 0·일정 0 기준선을 확인한 뒤 승인 범위에서 현재 DEV profile의 `tier` 한 필드만 update-time precondition으로 Amateur로 임시 변경했다. 합성 테스트 회원 1건 생성과 고객리스트 1명 표시는 성공했다.
- stale cache를 만들기 위해 해당 회원 연결 일정 1건을 저장했고 canonical schedule snapshot은 server authoritative 상태로 1건을 반환했다. 직후 `HomeScheduleFirestoreService.refreshMemberNextLesson()`의 `members/{memberId}.nextLessonAt` 직접 갱신이 `permission-denied`를 발생시켰다. 이 로그는 이번에 수정한 stale member resolution query가 아니라 일정 저장 후 별도 member metadata write 경로다.
- permission-denied 즉시 중단 조건에 따라 외부에서 회원·일정을 삭제한 뒤 force-stop/restart하는 stale cache self-heal 실증, 같은 ID 재조회 0 확인, 고객카드 잔여 묶음 완료 판정은 진행하지 않았고 통과 처리하지 않았다. 해당 시점 fatal crash·ANR·PROD marker는 없었지만 permission-denied는 1건이다.
- 앱을 force-stop한 뒤 이번 검증에서 만든 회원 1건과 일정 1건만 update-time precondition으로 삭제했다. 서버 readback은 회원 0, 일정 0, managed count 0, custom lesson type 0, tier Beginner 복원을 확인했다.
- 증적은 `artifacts/customer_card_stale_cache_fix_20260726/automated/`와 `artifacts/customer_card_stale_cache_fix_20260726/device/`에 보존했고 UID/memberId/전화번호 패턴은 텍스트 증적에서 마스킹했다. Galaxy, PROD 앱·Firebase, `pm clear`, Firebase Functions·Rules·indexes·Storage 배포는 작업하지 않았고 다음 묶음으로 이동하지 않았다.

## 2026-07-26 고객카드 canonical 저장 무결성 수정·DEV 선택 배포·실기기 검증

### 결함 원인과 수정
- 성별 오저장은 `ClientCardPage._submitAndStay`가 실제 UI 값 `남`/`여`를 `남성`과 비교해 남성 선택도 `female`로 보내던 것이 원인이었다. 페이지는 현재 선택값과 생년월일을 저장 서비스에 전달하고, `PersonalMemberCardSaveService`가 성별을 `male`/`female`로 정규화하도록 수정했다.
- 생년월일 누락은 Flutter callable payload와 `functions/src/managed_members.ts`의 create allowlist·transaction write 양쪽에 계약이 없던 것이 원인이었다. 유효한 날짜를 `birth`, `birthDisplay`, `birthAt` canonical 필드로 저장하고 생성·수정 readback에서 성별과 생년월일을 검증하도록 복구했다.
- Personal 기존 회원 수정도 동일한 `updateManagedMember` callable과 readback 경로를 사용하도록 통일했다. 관련 없는 회원카드 구조나 legacy 데이터 rewrite는 추가하지 않았다.

### 서버 저장 정책 감사
- `createManagedMember`와 `updateManagedMember` 모두 인증을 필수로 하며, create는 `trainerId=request.auth.uid`, `workspaceType=personal`을 서버에서 강제한다.
- update는 대상 문서의 `trainerId`가 현재 인증 UID이고 `workspaceType=personal`인지 확인하며, identity 필드는 allowlist에 포함하지 않아 클라이언트 변조를 허용하지 않는다.
- 전화번호 중복 검사는 owner 범위에서 수행하고 update에서는 현재 member를 제외한다. 다른 trainer의 조회·수정 차단, 허용 필드 제한, canonical 주소·레슨 필드 유지, 신규 `groupId/groupName` 미생성, `member_groups` 미접근을 코드와 Emulator 테스트로 확인했다.
- 전화번호 원문을 출력하는 신규 로그와 PROD project 문자열은 관련 변경에 없다.

### 배포 전 자동 검증
- Functions TypeScript build 통과.
- managed member Emulator 48개 통과. 나머지 전체 Emulator 묶음은 schedules 27개, training logs 38개, legacy 28개, profile 30개, anonymous identity 26개, nickname/profile 22개와 platform-admin unit·Emulator가 모두 통과했다.
- 관련 Flutter 테스트 29개, 전체 Flutter 테스트 443개 통과.
- 변경 범위 `flutter analyze --no-pub`는 신규 error 0, 기존 warning/info 254개였고 `git diff --check`는 오류 0이었다.
- DEV debug APK build와 `adb install -r`이 통과했고 package `firstInstallTime`이 유지되어 데이터 보존 업데이트 설치임을 확인했다.

### DEV Functions 선택 배포
- 실제 명령은 `firebase deploy --project more-than-fitness-dev-mft --only "functions:createManagedMember,functions:updateManagedMember"`였다.
- `createManagedMember(asia-northeast3)` update와 `updateManagedMember(asia-northeast3)` create가 각각 성공했다. CLI 최종 exit code 1은 두 함수 배포 뒤 Artifact Registry cleanup policy를 설정하지 못했다는 경고 때문이며, 요청대로 cleanup policy는 변경하지 않았다.
- 배포 전후 함수 목록을 비교해 `createManagedMember` hash 변경과 `updateManagedMember` 추가만 확인했다. 두 함수 모두 project `more-than-fitness-dev-mft`, region `asia-northeast3`, state `ACTIVE`였고 다른 함수·Rules·indexes·Storage는 배포하지 않았다.

### TO2408FB00746 DEV 실기기 검증
- 서버 기준 현재 DEV UID를 precondition guard로 Beginner에서 Amateur로 임시 변경한 뒤 검증했다. validation 실패 저장은 `createManagedMember` 호출 0이었다.
- 공개 테스트 값만 사용해 주소 포함 회원과 주소 없는 회원을 각각 생성했다. 두 create callable이 성공했고 서버 readback에서 canonical `trainerId`/`workspaceType`, 남성 성별, 생년월일, 주소 포함·미포함 상태와 legacy 필드 부재를 확인했다.
- 첫 회원을 동일 전화번호 그대로 여성·다른 정상 생년월일로 수정했다. `updateManagedMember` 1회가 성공하고 재진입 UI와 서버 readback이 모두 변경값과 일치해 자기 전화번호를 중복으로 오인하지 않음을 확인했다.
- 첫 회원 전화번호를 둘째 회원의 테스트 번호로 바꾼 중복 시도는 update callable 0으로 차단됐고, 서버 readback에서 첫 회원 전화번호가 이전 값으로 유지됐다.
- 수집한 기기 로그 전체에서 `permission-denied`/`PERMISSION_DENIED` 0, fatal crash 0, ANR 0, PROD project marker 0이었다.

### 원복과 증적
- 열린 고객카드 listener를 DEV 앱 force-stop으로 종료한 뒤 이번 검증에서 추가한 회원 2건만 update-time precondition으로 삭제했다. 서버 readback은 tier `Beginner`, 관리 회원 0, 누적 회원 0, 기존 member 집합 복원을 확인했고 고객리스트도 `총 0명`으로 표시됐다.
- 로컬 DEV fixture 표시는 Amateur로 남아 있으나 Firestore tier는 Beginner로 원복됐다.
- 배포 전 결과는 `artifacts/customer_card_integrity_fix_20260726/predeploy/`와 `artifacts/customer_card_integrity_fix_20260726/predeploy_emulators/`, 배포 출력과 함수 목록은 `artifacts/customer_card_integrity_fix_20260726/deploy_dev_functions.txt`와 `artifacts/customer_card_integrity_fix_20260726/functions_list_after.json`에 보존했다.
- 서버 기준선·readback·cleanup 결과는 `artifacts/customer_card_integrity_fix_20260726/server_baseline.json`, `artifacts/customer_card_integrity_fix_20260726/server_readback.json`, `artifacts/customer_card_integrity_fix_20260726/server_cleanup.json`에 보존했다. 기기 PNG/XML/logcat은 `artifacts/customer_card_integrity_fix_20260726/device/`에 보존했다.
- PROD `more-than-fitness-f6adb`, Galaxy `R3CX40M6EEM`, PROD APK, `adb shell pm clear`, 기존 회원 일괄 rewrite, Firebase Rules·indexes·Storage와 다른 함수는 작업하지 않았다. 다음 백로그로 이동하지 않았다.

## 2026-07-26 DEV Amateur 임시 승급·고객카드 서버 저장 재검증·Beginner 원복

### 승인 범위와 원본 상태
- 사용자 승인에 따라 `TO2408FB00746`의 현재 DEV Auth UID만 대상으로 canonical `trainer_profiles/{uid}.tier`를 임시 변경했다. project ID는 모든 관리 요청에서 `more-than-fitness-dev-mft`로 고정했고 UID 원문은 출력·보고·artifact에 기록하지 않았다.
- 변경 전 서버 readback은 `tier=Beginner`, `managedMemberCount=0`, `lifetimeQualifiedMemberCount=0`, `customLessonTypes=0`이었다.
- Firebase CLI OAuth를 토큰 출력 없이 사용한 Firestore REST commit에 document `updateTime` precondition을 적용했다. 원본 profile 필드와 기존 회원 ID hash를 로컬 guard에 임시 보관하고 `tier` 하나만 `Amateur`로 변경했다.
- 앱 재시작 후 Home이 다음 등급 `Semi-Pro`와 0/30명을 표시해 서버 Amateur가 앱에 반영된 것을 확인했다.

### 서버 저장 통과 항목
- 주소 포함 `DEVADDR`: 공개 우편번호 06296의 공개 주소를 사용했다. `createManagedMember`, function readback, snapshot 관찰, 목록 표시가 모두 성공했고 재진입 기본정보 2/2에서 우편번호·도로명·건물명이 유지됐다.
- 주소 없는 `DEVZERO`: 레슨 미등록, 총 0/잔여 0, 기간 미등록 상태로 저장했다. function readback, snapshot 관찰, 목록 표시가 성공했다.
- 사용자 레슨 종류 `DEV PILATES`: `DEVTYPE` 저장과 `updatePersonalTrainerProfile` readback이 성공했다. 재진입 dropdown 재표시, 같은 값 반복 저장 후 profile 목록 1개 유지, 관리 sheet 삭제 후 profile 목록 0개, 삭제 뒤 기존 DEVTYPE 카드의 `DEV PILATES` 값 유지가 모두 확인됐다.
- 서버 익명 집계는 신규 테스트 회원 3개, 주소 포함 1개, 주소 미포함 2개, legacy `groupId/groupName` 0개였다.
- 신규 저장 세 번 모두 `selectedGroupType=canonicalDefault`, `functionSucceeded=true`, `readbackSucceeded=true`, `snapshotObserved=true`, `visibleAfterSave=true`, `result=success`였다.

### 새로 확인한 저장 결함
- **생년월일 미저장**: 신규 회원 3개 모두 서버 문서의 `birth`, `birthDate`, `birthText`, `birthday` 필드가 0개였다. 재진입 시 생년월일이 비어 validation이 다시 생년월일로 이동했다.
- 원인은 `ClientCardPage._submitAndStay`가 `PersonalMemberCardSaveService.createAndVerify`에 생년월일을 전달하지 않고, service payload와 `functions/src/managed_members.ts`의 `createManagedMember` allowlist·transaction create에도 생년월일 필드가 없기 때문이다.
- **남성→여성 오저장**: UI에서 세 회원 모두 `남`을 선택했지만 서버 문서 집계는 `male=0`, `female=3`이었다. 재진입한 DEVADDR의 성별도 `여`로 표시됐다.
- 원인은 `_submitAndStay`가 실제 상태값 `남|여` 대신 존재하지 않는 `남성`과 비교하는 `gender: _gender == '남성' ? 'male' : 'female'` 매핑을 사용하기 때문이다.
- 두 결함은 확인하지 않은 성공으로 처리하지 않았다. 이번 승인은 tier 임시 변경과 저장 검증 범위이므로 Functions 배포나 추가 코드 수정은 진행하지 않았다.

### 정리와 원복
- 테스트 회원 3개를 ID 원문 출력 없이 baseline hash 차이와 허용된 DEV 테스트 이름으로 한정해 삭제했다.
- 같은 DEV commit에서 원본 `tier`, `earnedTier`, count, usage timestamp, `customLessonTypes` 등 guard 대상 profile 필드를 복원했다.
- 최종 서버 readback은 `tier=Beginner`, `managedMemberCount=0`, `lifetimeQualifiedMemberCount=0`, `customLessonTypes=0`, 신규 회원 0개였다.
- 앱 재시작 후 Home은 `Amateur 달성까지 0/2`, 고객리스트는 총 0명이며 `DEVADDR`, `DEVZERO`, `DEVTYPE`이 표시되지 않았다.
- 문서 삭제 시 열려 있던 DEVTYPE detail listener가 삭제 직후 `permission-denied` 1건을 남겼다. cleanup listener 로그를 별도 보존했고, 앱 재시작·logcat clear 후 새 세션은 permission-denied 0, fatal 0, app ANR 0, PROD project marker 0이었다.

### 증거와 미작업
- 저장·readback: `artifacts/customer_card_focus_fix_20260726/111_server_address_saved.*`부터 `135_server_deleted_value_reentry.*`.
- 저장 성공 로그: `artifacts/customer_card_focus_fix_20260726/128_server_saves_logcat.txt`.
- cleanup listener 로그: `artifacts/customer_card_focus_fix_20260726/141_cleanup_listener_logcat.txt`.
- 최종 Beginner·0명: `artifacts/customer_card_focus_fix_20260726/142_beginner_restored_home.*`, `143_beginner_restored_list.*`, `143_final_post_restore_logcat.txt`.
- PROD 앱/Firebase, Galaxy `R3CX40M6EEM`, Firebase Functions/Rules/indexes/Storage 배포, `pm clear`, 실제 개인정보는 사용하지 않았다. 다음 백로그로 이동하지 않았다.

## 2026-07-26 고객카드 반복 validation focus 결함 수정 및 DEV 실기기 재검증

### 범위와 안전 조건
- 대상은 `TO2408FB00746` / P10HD Lite / Android 10(API 29), package `com.example.mtf_app.dev`만 사용했다.
- DEV 배지를 길게 눌러 `Amateur` 로컬 fixture를 적용했으며 로그의 `localOnly=true`, `firestoreWrite=false`, `functionsCall=false`를 확인했다.
- 실제 개인정보 대신 `DEVTEST`, `DEVADDR`, `DEVZERO`, 짧은 오류 전화번호와 Daum 우편번호 검색의 공개 예시 주소만 사용했다.
- Galaxy `R3CX40M6EEM`, PROD 앱, PROD Firebase, Firebase 배포, `adb shell pm clear`는 사용하지 않았다.

### 정확한 원인과 수정
- 재현 시 기본정보 PageView가 2/2에 있으면 1/2의 이름 `TextFormField`가 `FormState`에서 빠질 수 있었다. 이 상태에서 `_formKey.currentState?.validate()`는 이름 controller가 비어 있어도 `true`를 반환했다.
- 수정 전 흐름은 첫 저장에서 이름 validator가 이름으로 이동했지만, 반복 저장에서는 `FormState.validate() == true`로 필수 오류 분기를 건너뛴 뒤 뒤쪽 전화번호 검사로 진입해 전화번호가 focus와 숫자 키보드를 가져갔다.
- `_submitAndStay`가 매 저장 시도 시작에 현재 controller 값으로 `clientCardMissingRequiredFields`를 새로 계산하고 첫 오류를 캡처하도록 변경했다. `clientCardValidationPassed`는 `FormState`와 controller 기반 필수 오류 목록이 모두 정상일 때만 저장 경로를 허용한다.
- `ClientCardValidationFocusCoordinator`가 이전 요청 generation을 취소하고 모든 validation focus를 해제한 뒤 첫 오류 하나만 focus한다. stale 비동기 callback은 generation 불일치로 키보드를 열거나 다른 필드 focus를 덮어쓸 수 없다.
- `_scrollToFirstRequiredField`는 캡처된 첫 오류에 필요한 accordion/page를 열고 `ensureVisible` 후 해당 `FocusNode` 하나만 요청한다. 키보드는 target focus가 확인된 뒤에만 표시한다.
- 주소 검색 후속 검증 중 Daum WebView가 `about:blank` 기준으로 실행되어 결과 선택 시 `Invalid target origin 'about://'`가 발생하는 별도 결함을 발견했다. `_DaumPostcodeSearchPageState.initState`의 `loadHtmlString`에 `https://postcode.map.daum.net/` base URL을 지정해 callback을 복구했다.

### 코드와 회귀 테스트
- 수정 파일: `lib/pages/client_card_page.dart`, `test/personal_customer_card_regression_test.dart`.
- 회귀 테스트는 이름+전화번호 오류 상태의 저장 1·2·3회 이름 우선, 이름 정상화 후 전화번호 저장 1·2회 우선, offscreen validator 누락 방지, stale callback focus 덮어쓰기 방지, HTTPS 주소 base URL을 포함한다.
- 관련 Flutter 테스트 41개 통과.
- 전체 Flutter 테스트 439개 통과.
- 회원/tier Emulator 시나리오 41개 통과.
- owner-scoped 일정 Emulator 시나리오 27개 통과.
- 변경 범위 `flutter analyze --no-pub lib\pages\client_card_page.dart test\personal_customer_card_regression_test.dart`: 신규 error 0, 기존 warning/info 254건.
- `git diff --check`: 오류 0, 기존 line-ending 경고만 존재.

### DEV 데이터 보존 설치
- `flutter run --flavor dev -t lib\main_dev.dart -d TO2408FB00746 --debug --no-pub --no-resident`로 최종 DEV APK 빌드·설치·실행에 성공했다.
- package `firstInstallTime`은 유지되고 `lastUpdateTime`만 갱신되어 데이터 보존 업데이트 설치임을 확인했다.

### 반복 오류 실기기 결과
| 시나리오 | 화면 이동 | focused hierarchy | 키보드 | 결과 |
| --- | --- | --- | --- | --- |
| 이름+전화 오류 저장 1회 | 이름 표시 | 이름 `true`, 전화 `false` | 일반 키보드 표시 | 통과 |
| 이름+전화 오류 저장 2회 | 이름 표시 | 이름 `true`, 전화 `false` | 일반 키보드 표시 | 통과 |
| 이름+전화 오류 저장 3회 | 이름 표시 | 이름 `true`, 전화 `false` | 일반 키보드 표시 | 통과 |
| 이름 정상+전화 오류 저장 1회 | 전화번호 표시 | 이름 `false`, 전화 `true` | 숫자 키보드 표시 | 통과 |
| 이름 정상+전화 오류 저장 2회 | 전화번호 표시 | 이름 `false`, 전화 `true` | 숫자 키보드 표시 | 통과 |

- 이름 3회 로그는 매번 `valid=false formValid=true firstMissing=이름 missingCount=2`, `target=이름 focused=true`였다.
- 전화번호 2회 로그는 `firstMissing=전화번호 missingCount=1`, `target=전화번호 focused=true`였다.
- 반복 오류 검증 구간의 `permission-denied`, `createManagedMember`, 회원 저장 완료 marker, crash, ANR, PROD project marker는 모두 0건이었다.

### 고객카드·회원등록 후속 묶음
| 항목 | 결과 | 근거 또는 제한 |
| --- | --- | --- |
| 생년월일 오류 이동 | 통과 | 미래 날짜에서 `firstMissing=생년월일`, 생년월일 focused |
| 직접입력 레슨 종류 빈 값 | 통과 | `firstMissing=직접입력 레슨 종류`, 입력칸 focused |
| 여러 오류의 화면상 첫 오류 | 통과 | 5개 오류에서 이름이 첫 오류이며 이름 focused |
| 주소 검색 진입과 callback | 통과 | 공개 예시 주소 선택 후 우편번호·도로명·건물명 callback 확인 |
| 주소 포함 저장·재진입 | 환경 차단 | client validation 통과 후 DEV callable이 `failed-precondition`; 문서 미생성으로 재진입 불가 |
| 주소 없이 저장 | 환경 차단 | client validation 통과 후 동일 `failed-precondition`; 문서 미생성 |
| 레슨 등록 OFF | 통과 | 실기기 hierarchy에서 switch `checked=false` |
| 레슨 종류 미입력 | 통과 | `레슨 미등록` 표시 |
| 총 0 / 잔여 0 | 통과 | 실기기에서 `총 0 / 잔여 0` 표시 |
| 기간 미등록 | 통과 | 실기기에서 `GOLD · 기간 미등록` 표시 |
| 사용자 레슨 종류 lifecycle | 자동 검증 통과, 실기기 저장 차단 | 정규화·중복 차단 단위 테스트와 user-scoped Emulator readback 통과; 실제 생성은 tier 제약으로 차단 |
| 삭제된 종류를 사용한 기존 회원 값 유지 | 코드·자동 검증 통과, 실기기 미확인 | 삭제는 profile 목록만 갱신하고 기존 회원 문자열은 변경하지 않음; 생성 차단으로 물리 readback 불가 |
| 기본 그룹 표시명 네 화면 일치 | 자동 검증 통과, 실기기 3지점 확인 | `MORE THAN GYM` 단위 테스트 통과, 목록 필터·카드 헤더·소속 그룹에서 확인 |
| legacy `member_groups` 요청 0 | 통과 | 종료 logcat 0건, personal 경로 source guard 확인 |
| legacy `groupId/groupName` 신규 저장 0 | 자동 검증 통과, 실기기 저장 차단 | save service/Emulator 통과; 실제 신규 문서는 생성되지 않음 |
| 고객카드 5개 진입 경로 | 정적·자동 검증 통과, 실기기 1경로 확인 | 목록 신규 진입 실기기 확인, 나머지 호출 경로 source/test 확인 |
| owner-scoped top-level schedules query | 통과 | personal schedule Emulator 27개 시나리오 통과 |

- 실제 DEV 서버 tier는 `Beginner`, 로컬 표시만 `Amateur`였다. 금지된 Firestore tier 변경 없이 진행했으므로 유효 회원 저장 두 시도는 DEV Functions `createManagedMember`까지 도달했으나 각각 `failed-precondition`으로 종료됐고 readback 문서는 생성되지 않았다.
- 유효 저장 후속 구간까지 포함한 안전 판정은 `permission-denied` 0, 회원 저장 성공 marker 0, 회원 문서 생성 0, fatal crash 0, app ANR 0, PROD project `more-than-fitness-f6adb` 0, legacy `member_groups` 0이다.

### 증거
- 반복 focus: `artifacts/customer_card_focus_fix_20260726/32_name_save_1.*`부터 `36_phone_save_2.*`.
- 후속 오류: `41_birth_error.*`, `46_custom_error.*`, `49_multi_error.*`.
- 주소 callback: `73_address_fix_results.xml`, `74_address_fix_callback.*`.
- 저장 차단과 0회 상태: `76_address_save_result.*`, `82_zero_off.*`, `83_zero_save_result.*`.
- 종료 목록과 로그: `91_final_list.*`, `99_final_logcat.txt`.
- UI hierarchy/dumpsys/logcat은 자동 판정에 사용했고, 키보드 종류·겹침·공개 주소 callback 화면은 스크린샷으로 직접 확인했다. 실제 회원 저장·재진입과 사용자 레슨 종류 물리 lifecycle은 확인하지 못했으므로 통과 처리하지 않았다.
- 다음 백로그로 자동 이동하지 않았다.

## 2026-07-25 P10HD Lite DEV 고객카드 통합 실기기 검증

- 대상은 `TO2408FB00746` / P10HD Lite / Android 10(API 29)이며, ADB `device`, 화면 ON, Keyguard 비표시, foreground `com.example.mtf_app.dev/com.example.mtf_app.MainActivity`를 확인했다. Galaxy `R3CX40M6EEM`과 PROD package는 조작하지 않았다.
- Computer Use로 Android Studio Device Mirroring 창을 우선 탐색했으나 Android Studio 프로세스만 존재하고 제어 가능한 창이 반환되지 않았다. scrcpy는 설치되어 있지 않았고 설치하지 않았다. 이후 지정 기기에 한정한 ADB 입력, uiautomator, screencap, dumpsys input_method, logcat으로 검증했다.
- DEV 배지를 길게 눌러 Amateur를 선택했다. 화면의 Amateur 선택 라디오와 `[MTF_DEV_TIER_FIXTURE] selection=Amateur localOnly=true firestoreWrite=false functionsCall=false`를 확인해 서버 tier·Firestore·Functions 변경이 없는 로컬 fixture임을 확인했다.
- 고객리스트에서 회원 추가를 눌러 신규 고객카드에 진입했다.
- 360dp 기본정보 2/2는 키보드 닫힘/열림 모두 주소 안내, 우편번호 Row, 상세주소 입력칸을 표시했다. 상세주소 `EditText focused=true`, input method 표시를 자동 확인했고 RenderFlex/BOTTOM overflow와 fatal/ANR는 0건이었다. 육안으로 내용 잘림·하단 겹침·터치 방해가 없음을 확인했다.
- 이름 오류 1회차는 통과했다. 이름 입력 영역이 보이고 이름 `EditText focused=true`, 일반 키보드 표시, create marker 0건이었다.
- 이름 오류 2회차는 실패했다. 키보드를 닫고 스크롤을 상단으로 초기화한 뒤 기본정보 2/2로 이동해 회원저장을 눌렀다. 250/500/1000ms 세 시점 모두 전화번호 `EditText`가 `focused=true`였고 숫자 키보드가 표시됐다. 이름 입력칸 재포커스 조건을 충족하지 못했으므로 전체 통합 검증을 성공으로 처리하지 않는다.
- 전화번호 오류는 테스트 값 `DEVTEST`, 남, 정상 테스트 생년월일, 짧은 값 `12`만 사용했다. 1·2회차 모두 키보드/스크롤 초기화와 기본정보 2/2 이동 뒤 전화번호 `EditText focused=true`, 숫자 키보드 표시, create/permission marker 0건을 확인했다.
- 320/390/411dp 기본정보 2/2는 각 폭의 키보드 닫힘/열림 화면을 저장했다. 세 폭 모두 우편번호 Row, 주소 안내, 상세주소 입력칸이 보이고 상세주소가 `focused=true`가 됐다. 320dp 안내 문구 줄바꿈은 정상이며 내용 잘림·overflow·하단 겹침·터치 방해가 없었다. 전체 폭 구간 RenderFlex/BOTTOM overflow는 0건이다.
- 종료 logcat 정밀 집계는 permission-denied 0, createManagedMember/MTF_MEMBER_CREATE 0, 정확한 저장 완료 marker 0, RenderFlex/BOTTOM overflow 0, FATAL EXCEPTION 0, ANR 0, PROD project `more-than-fitness-f6adb` 0건이다.
- 회원 문서 미생성은 callable marker와 저장 완료 marker가 모두 0건이고 DEV 고객리스트 복귀 후 `DEVTEST` UI node가 0건인 것으로 교차 확인했다. 실제 UID·문서 ID를 읽거나 기록하지 않았고 직접 서버 문서 ID readback은 실행하지 않았다.
- 자동 확인 항목은 package/foreground, uiautomator `focused`, input method, logcat marker 수, 고객리스트 `DEVTEST` node 수다. 육안 확인 항목은 Amateur 라디오, 주소 요소 표시, 줄바꿈·잘림·겹침·터치 방해다.
- 증거는 `artifacts/customer_card_device_validation/`의 PNG/XML 13쌍과 `VALIDATION_SUMMARY.md`에 저장했다.
- Firebase 배포, PROD Firebase 접근, 실제 회원 저장, 실제 개인정보 입력, `adb shell pm clear`, Galaxy·PROD 조작을 하지 않았다. 다음 백로그로 이동하지 않았다.

## 2026-07-17 — Android Debug Emulator host 127.0.0.1 통일 및 실기기 재검증

- 범위: `USE_FIREBASE_EMULATORS=true && kDebugMode`에서 Auth, Firestore, Functions Emulator host 해석만 최소 수정했다. Functions region은 `asia-northeast3`를 유지했고 production fallback, App Check, Firebase deploy, 운영 데이터는 변경하지 않았다.
- host 통일: `FirebaseEmulatorConfig.host`를 `127.0.0.1`로 변경하고 Auth 9099, Firestore 8080, Functions 5001이 공통 상수 하나를 사용하게 했다. `lib` 전수 검색에서 Emulator 연결용 `localhost` 문자열은 0개다. `MtfFirebaseFunctions.useEmulator`의 host/port 기본값도 제거해 호출자가 공통 값을 반드시 전달하게 했다.
- 초기화 순서: `Firebase.initializeApp` 직후 `FirebaseEmulatorConfig.configure`가 끝난 뒤에만 `runApp`을 호출한다. AccountGate의 `ensureAnonymousSession`과 repository 생성보다 세 Emulator 연결이 먼저 완료된다.
- Debug 네트워크: Debug 전용 `network_security_config`의 허용 대상을 `127.0.0.1`로 변경했다. Profile/Release manifest는 수정하지 않았다. 원인 분리를 위해 Debug base cleartext 전체 허용 APK도 한 차례 비교했지만 결과가 같아 즉시 127.0.0.1 제한 설정으로 되돌렸다.
- 안전 로그: `[MTF_FIREBASE_EMULATOR] connected host=127.0.0.1 authPort=9099 firestorePort=8080 functionsPort=5001 region=asia-northeast3`를 Debug에서 확인했다. callable 로그는 projectId, region, emulator, callable 이름만 포함하며 UID/token/email은 출력하지 않는다.
- 자동 검증: 관련 28개 테스트와 전체 `flutter test --no-pub -r expanded` 197개가 모두 통과했다. 변경 범위 analyze는 이슈 0개다. 최종 127.0.0.1 제한 설정으로 Debug APK 빌드가 성공했고 `git diff --check`는 종료 코드 0이다.
- 실기기 환경: `R3CX40M6EEM` 연결, Auth/Firestore/Functions Emulator 9099/8080/5001 LISTENING, 같은 adb에서 reverse 세 개 재설정, 최신 Debug APK 설치를 확인했다. 기기 shell의 `nc -z 127.0.0.1 5001`도 성공했다.
- 실기기 결과: `ensureAnonymousSession start/success`까지는 통과했지만 `bootstrapAnonymousBeginnerProfile`은 계속 `FirebaseFunctionsException code=unknown`으로 실패했다. Emulator가 준비된 상태에서도 Functions 실행 로그에 해당 Flutter 요청이 도달하지 않았고 `personalProfileRead`, `personalWorkspace`, personal Home 진입은 실행되지 않았다.
- 판단: PC 직접 callable HTTP 200과 별개로, host 문자열을 `127.0.0.1`로 통일하는 이번 변경만으로는 FlutterFire Android callable 실패가 복구되지 않았다. 요청된 성공 기준을 충족했다고 처리하지 않으며 다음 원인 조사는 별도 승인 범위가 필요하다. 다음 백로그로 이동하지 않았다.

## 2026-07-17 — Flutter callable regional 단일 인스턴스 연결 복구

- 범위: PC에서 Auth Emulator token으로 `asia-northeast3/bootstrapAnonymousBeginnerProfile`을 직접 호출해 HTTP 200과 정상 profile payload가 확인된 결과를 기준으로, 서버·Auth token·Functions Emulator·결제 원인을 제외하고 Flutter callable 연결만 수정했다. Firebase deploy와 운영 데이터 변경은 수행하지 않았다.
- 전수 감사: `lib`의 `FirebaseFunctions.instance`, `FirebaseFunctions.instanceFor`, `useFunctionsEmulator`, `httpsCallable`을 전수 검색했다. 기본 `FirebaseFunctions.instance`는 없었지만 공통 래퍼의 `instance`가 getter로 매번 `instanceFor`를 평가했고, 5개 서비스의 9개 personal callable 및 비밀번호 변경 callable이 각자 주입 객체에서 직접 `httpsCallable`을 만들고 있었다.
- 단일 인스턴스: `mtfFirebaseFunctions` top-level lazy final을 `FirebaseFunctions.instanceFor(region: 'asia-northeast3')`로 한 번만 만들었다. 공통 getter, Emulator 연결, callable 생성이 모두 이 객체를 사용한다. 테스트용 명시적 Functions 주입은 유지하되 production 기본 경로는 단일 객체다.
- Emulator 연결: `Firebase.initializeApp` 직후 AccountGate/Auth bootstrap 또는 repository 생성 전에 `FirebaseEmulatorConfig.configure()`가 호출되고, 같은 `mtfFirebaseFunctions` 객체에 `localhost:5001`, `automaticHostMapping: false`를 설정한다. 실패 시 production fallback은 없다.
- callable 중앙화: profile bootstrap/transition, linked profile bootstrap, 회원 생성·상태·수정·선생님 정보, 레슨일지 확정·취소, 초기 비밀번호 변경이 모두 `MtfFirebaseFunctions.call`을 사용한다. `httpsCallable`과 `useFunctionsEmulator`, `instanceFor`의 직접 사용은 공통 파일 하나에만 남았다.
- 응답 계약: 공통 호출기는 FlutterFire `HttpsCallableResult.data`만 반환한다. 직접 HTTP의 `{result: ...}` envelope를 Flutter 코드에서 다시 해석하지 않는다. 레슨일지 확정·취소의 기존 Map 반환도 공통 호출기가 해제한 `data`를 사용한다.
- 안전 로그: Debug callable마다 `[MTF_FUNCTIONS_CALLABLE] projectId=... region=asia-northeast3 emulator=... callable=...`를 기록한다. UID, token, 이메일, 회원정보는 출력하지 않는다.
- 테스트: 공통 파일 밖 direct Functions 생성/Emulator/callable 사용을 source scan으로 차단하는 테스트를 추가했다. 관련 60개 테스트와 전체 `flutter test --no-pub -r expanded` 197개가 모두 통과했다.
- analyze: 실제 변경 파일 8개 `flutter analyze --no-pub`는 이슈 0개다. `main.dart`까지 포함한 첫 분석에는 기존 `_index` `prefer_final_fields` info 1개만 있었으며 이번 범위에서 수정하지 않았다.
- 빌드: `USE_FIREBASE_EMULATORS=true`로 Debug, Profile, Release APK가 모두 성공했다. Profile/Release 3개 ABI의 `libapp.so`에서 `LOCAL EMULATOR`, `MTF_FIREBASE_EMULATOR`, `MTF_FUNCTIONS_CALLABLE`, `USE_FIREBASE_EMULATORS` marker가 모두 없었다.
- 실기기: PC의 9099/8080/5001 포트는 LISTENING이었지만 두 Android SDK 경로의 `adb devices` 결과가 모두 기기 0대였다. 따라서 `ensureAnonymousSession success` → `bootstrapAnonymousBeginnerProfile success` → `personalProfileRead success` → `personalWorkspace success`와 로그인 없는 personal Home 진입은 미검증이다. 기기 연결 후 최신 Debug APK로 반드시 확인해야 한다.
- diff/배포: `git diff --check`를 실행했다. 실제 Firebase deploy, Functions/Rules/Storage 변경, 운영 데이터 변경은 하지 않았고 다음 백로그로 이동하지 않았다.

## 2026-07-17 — Android 실기기 LOCAL EMULATOR 시작 실패 진단·복구

- 범위: `preparation_failed code=unknown`으로 뭉개지던 Anonymous personal 시작 실패의 진단 정보와 Debug 전용 Emulator 연결만 보완했다. 앱 정책, 시작 라우팅, Firebase Rules/Functions/Storage, 실제 배포는 변경하지 않았다.
- 확인된 원인: `AppAccountService`가 `FirebaseFunctionsException`을 `AppAccountException(unknown)`으로 감싼 뒤 `AppAccountGate`가 단일 `preparation_failed` 로그만 남겨 실제 실패 단계와 Firebase code를 잃고 있었다. Android Debug manifest에도 localhost cleartext 예외가 없었다. 과거 실기기 실패의 최하위 Firebase code는 당시 로그에 없어 단정하지 않았으며, 새 단계 로그로 재실행 시 정확히 구분하도록 했다.
- 시작 단계 로그: `ensureAnonymousSession`, `bootstrapAnonymousBeginnerProfile`, `personalProfileRead`, `personalWorkspace` 각각에 start/success/failure를 추가했다. 실패 로그는 원인 `runtimeType`, 감싼 타입, `FirebaseException.code`, `FirebaseFunctionsException.code`, 고정된 안전 메시지만 기록하며 UID, token, 이메일, 회원정보와 Firebase 원문 message는 출력하지 않는다.
- 프로필 확인: bootstrap 성공 뒤 `trainer_profiles/{uid}`를 `Source.server`로 읽어 문서 존재, `trainerId`, `workspaceType=personal`을 확인한 뒤에만 personal workspace를 만든다. 서버 조회 실패를 캐시나 production으로 대체하지 않는다.
- 사용자 오류: 실패 단계를 `익명 계정 준비 실패`, `프로필 준비 실패`, Emulator 모드의 `Functions Emulator 연결 실패`, `Firestore 준비 실패`로 나누고 입력 없이 재시도할 수 있게 유지했다.
- App Check 감사: 첫 배포 필수 9개 v1 callable은 모두 `personalFunctions.https.onCall`이며 `enforceAppCheck` 설정이 없다. 따라서 Emulator의 `No AppCheckProvider installed`/missing 경고를 이번 실패 원인으로 처리하지 않았고 production App Check 정책도 추가하지 않았다.
- endpoint/순서: `main.dart`의 Firebase 초기화 직후 Auth `localhost:9099` → Firestore `localhost:8080` → Functions `localhost:5001` 순서가 Auth 동작과 repository 생성보다 앞선다. Functions는 공통 `MtfFirebaseFunctions.instanceFor(region: asia-northeast3)`를 그대로 사용하며 connector 실패 시 다음 connector 또는 production fallback을 실행하지 않는다.
- Android: `android/app/src/debug`에만 network security config를 연결하고 base cleartext는 차단한 채 `localhost`만 허용했다. 병합 manifest 검사에서 설정은 Debug에만 존재하고 Profile/Release에는 없었다.
- 변경 파일: `android/app/src/debug/AndroidManifest.xml`, `android/app/src/debug/res/xml/debug_network_security_config.xml`, `lib/pages/account_gate.dart`, `lib/services/personal_profile_start_reader.dart`, `lib/services/personal_start_diagnostics.dart`, 관련 테스트와 이 문서다.
- 테스트: 관련 45개 및 추가 진단 조합 27개가 통과했다. 전체 `flutter test --no-pub -r expanded`는 196개 모두 통과했다. 개인정보가 포함된 가짜 Functions message가 로그에 남지 않는 테스트와 Firestore 단계 오류 화면 테스트를 포함한다.
- analyze/build: 변경 범위 `flutter analyze --no-pub`는 이슈 0개다. define=true로 Debug, Profile, Release APK 빌드가 모두 성공했다. Profile/Release `libapp.so`에는 `LOCAL EMULATOR`, `MTF_FIREBASE_EMULATOR`, `USE_FIREBASE_EMULATORS` marker가 없었다.
- diff: `git diff --check`는 종료 코드 0이며 기존 작업 트리의 줄바꿈 변환 warning만 출력했다.
- 남은 수동 확인: 새 Debug APK를 실기기에 설치해 네 단계 로그와 실제 홈 진입을 확인해야 한다. 재현이 남으면 새 failure 로그의 Firebase code로 Auth/Functions/Firestore 중 한 곳을 바로 특정할 수 있다. 실제 Firebase deploy는 실행하지 않았고 다음 백로그로 이동하지 않았다.

## 2026-07-17 — Android 실기기 Debug 전용 Firebase Emulator 연결

- 범위: Android 실기기의 새 Anonymous personal 출시 흐름을 Local Emulator Suite로 검증하기 위한 Debug 연결만 감사·보완했다. 앱 시작 라우팅, 회원·등급 정책, Firestore/Storage Rules, Functions 구현·배포, 실제 데이터와 다음 백로그는 변경하지 않았다.
- 기존 상태: `MtfFirebaseFunctions`에 `asia-northeast3` Functions Emulator helper는 있었지만 `main.dart`에서 호출하지 않았고 Auth/Firestore Emulator 설정도 없었다. 따라서 Firebase 초기화 후 `AppAccountGate`가 Auth를 사용하기 전에 세 제품을 한 번에 연결하는 공통 단계가 필요했다.
- 활성 조건: compile-time `USE_FIREBASE_EMULATORS`와 `kDebugMode`가 모두 true이고 web이 아닐 때만 `FirebaseEmulatorConfig.isEnabled`가 true다. Profile/Release에서는 define을 true로 강제해도 connector 생성 전에 반환한다.
- 초기화 순서: `WidgetsFlutterBinding.ensureInitialized` → `Firebase.initializeApp` → Emulator Auth/Firestore/Functions 설정 → 위젯 인터랙션 등록 → `runApp` 순서다. Auth 동작, account service singleton 접근, repository/page 생성보다 먼저 설정된다.
- endpoint: Auth `localhost:9099`, Firestore `localhost:8080`, Functions `localhost:5001`이다. 실기기 `adb reverse`를 사용하므로 세 FlutterFire API의 `automaticHostMapping`을 false로 설정해 Android emulator용 `10.0.2.2` 치환을 막았다. Functions는 공통 `MtfFirebaseFunctions.instanceFor(region: 'asia-northeast3')`를 그대로 재사용한다.
- 실패 차단: Emulator 설정 중 예외가 발생하면 다음 connector를 실행하지 않고 `FirebaseEmulatorConfigurationException`을 반환한다. 위젯 인터랙션과 실제 홈을 만들지 않으며 Local Emulator 확인 후 앱 재시작을 안내하는 오류 화면을 표시한다. Auth 또는 Functions의 첫 실제 요청이 실패해도 기존 personal 시작 오류 화면을 유지하며 production instance로 재설정하는 fallback은 없다.
- 화면: Debug Emulator 모드에서만 화면 왼쪽 위에 작은 `LOCAL EMULATOR` overlay를 표시한다. `IgnorePointer`라 실제 앱 터치를 막거나 레이아웃을 이동시키지 않는다.
- 실행 안내: `FIREBASE_ANDROID_LOCAL_EMULATOR.md`에 Local Emulator Suite 실행, 실기기 `adb reverse` 9099/8080/5001, `flutter run --debug --dart-define=USE_FIREBASE_EMULATORS=true`, 종료 명령과 수동 확인 항목을 기록했다. Storage Emulator와 Storage 기능은 이번 실기기 검증 범위에서 제외했다.
- 변경 파일: `lib/main.dart`, `lib/pages/account_gate.dart`, `lib/services/firebase_emulator_config.dart`, `lib/services/mtf_firebase_functions.dart`, `lib/widgets/firebase_emulator_banner.dart`, `test/firebase_emulator_config_test.dart`, `docs/agent/FIREBASE_ANDROID_LOCAL_EMULATOR.md`, `RUN_LOG.md`, `BACKLOG.md`.
- format: 변경 Dart 6개와 관련 테스트를 `dart format`으로 정리했다.
- 테스트: Emulator 조건·고정 host/port, Auth→Firestore→Functions 순서, 비활성 connector 0회, 실패 후 다음 connector/fallback 0회, 서울 리전 유지, banner 표시/미표시, 설정 실패 오류 화면을 포함한 신규 6개가 통과했다. account/Functions 관련 테스트를 포함한 관련 범위 26개가 통과했고 전체 `flutter test --no-pub` 193개도 모두 통과했다.
- analyze: 변경 범위를 분석해 새 error/warning은 0개다. `main.dart`의 기존 미사용 RootPage `_index`에 대한 `prefer_final_fields` info 1개가 남아 `--no-fatal-infos`로 범위 밖 기존 lint임을 분리했다.
- 빌드: define=true로 Debug APK, Profile APK, Release APK를 모두 빌드했다. Debug `kernel_blob.bin`에는 `LOCAL EMULATOR`, Emulator 로그 태그, define 이름, `asia-northeast3`가 존재했다. Profile/Release `libapp.so`에는 앞의 세 Emulator marker가 모두 없어서 compile-time 차단과 tree shaking을 확인했다.
- 미검증: 실제 USB 실기기와 Local Emulator Suite를 동시에 실행한 Anonymous/회원/일정/레슨일지 수동 시나리오는 사용자가 수행할 다음 수동 확인이며 이번 자동 검증에서 완료로 기록하지 않는다.
- 배포/백로그: 실제 Firebase deploy, export, Rules/Functions/Storage 변경, 운영 데이터·관리자 변경은 실행하지 않았고 다음 백로그로 이동하지 않았다.

## 2026-07-17 — Firebase NO-GO 해소: Region·maxInstances·Indexes·Console 확인

- 범위: `prompts/25_firebase_no_go_resolution.md`만 수행했다. 실제 Firebase deploy, Firestore export, Auth provider·claim 변경, 관리자 생성, 운영 데이터 수정과 다음 백로그는 진행하지 않았다.
- Functions region: `functions/src/index.ts`에 공통 v1 `personalFunctions` builder를 두고 첫 배포 필수 9개 callable에 `region("asia-northeast3")`를 연결했다. 현재 원격 배포 함수가 0개라 기존 endpoint migration/redirect는 필요 없다. 관리자 `completeInitialPasswordChange`와 legacy `chargeOnce`, `cancelNoShow`, `lockConsent`, `unlockConsent`의 서버 region은 범위 밖이라 기존 기본 리전을 유지했다.
- 관리자 후속 위험: Flutter callable 기본 instance는 요청대로 모두 서울 리전으로 중앙화했다. 따라서 첫 배포에서 제외된 `completeInitialPasswordChange`를 향후 기존 기본 리전 그대로 배포하면 앱 호출과 불일치한다. 관리자 활성화 전 별도 승인 작업에서 해당 서버 region을 서울로 맞추고 비밀번호 변경 smoke를 해야 하며, 이번 첫 Anonymous 배포 목록에는 넣지 않는다.
- v1 cost cap: 같은 builder에 `runWith({maxInstances: 10})`을 실제 연결했다. TypeScript build 산출물의 endpoint metadata에서 필수 9개 모두 `platform=gcfv1`, `region=[asia-northeast3]`, `maxInstances=10`을 확인했다. 범위 밖 5개에는 이 옵션을 적용하지 않았다.
- Flutter callable 중앙화: 신규 `MtfFirebaseFunctions`가 `FirebaseFunctions.instanceFor(region: 'asia-northeast3')`를 단일 기본 instance로 제공한다. profile bootstrap/anonymous link, 회원 생성·상태·수정·내 정보, 레슨일지 확정·취소, 비밀번호 변경 callable의 기존 이름과 payload 계약은 유지하고 기본 instance만 공통화했다. 테스트용 `FirebaseFunctions` 주입도 유지했다.
- Emulator wrapper: `firebase-emulator-tests/functions_client.cjs`가 callable URL과 기본 서울 리전을 한 곳에서 관리한다. 필수 함수 테스트는 이 wrapper의 기본 리전을 사용했고, 범위 밖 관리자 회귀는 기존 `us-central1`을 명시했다. Emulator 로그에서 필수 9개가 `asia-northeast3-*`, 보류 5개가 `us-central1-*`로 로드됨을 확인했다.
- index 감사: 실제 Dart/Functions query를 다시 대조했다. `schedules`는 trainerId/workspaceType equality + startAt 기간 range라 `trainerId ASC, workspaceType ASC, startAt ASC` 1개가 필요하다. `training_logs`는 trainerId/workspaceType/memberId equality + startAt range/order desc라 `trainerId ASC, workspaceType ASC, memberId ASC, startAt DESC` 1개가 필요하다. 기존 `firestore.indexes.json`의 두 정의가 정확해 그대로 유지했다.
- 불필요 index 제외: members 목록과 trainer-scoped phoneNormalized 중복 query는 equality-only라 composite를 추가하지 않았다. training log status는 Firestore query가 아니라 반환 후 메모리 filter이므로 status composite도 만들지 않았다.
- Console/백업 문서: `FIREBASE_CONSOLE_GO_LIVE_CHECKLIST.md`를 새로 작성해 project 성격, Anonymous/Email provider, 승인 도메인, 재설정 템플릿, Published Rules 백업, collection count, Blaze, export bucket, backup/PITR/delete protection의 Console 경로를 한국어로 정리했다. PITR를 지금 켜도 활성화 이전 7일 이력이 즉시 생기지 않고 이후부터 누적되므로 첫 실제 배포 전 managed export를 우선해야 한다고 `FIREBASE_BACKUP_AND_ROLLBACK.md`에도 명시했다.
- 관련 문서: `FIREBASE_DEPLOYMENT_READINESS.md`, `FIREBASE_FUNCTIONS_DEPLOY_MATRIX.md`, `FIRESTORE_RULES_DEPLOY_MATRIX.md`, `FIREBASE_BACKUP_AND_ROLLBACK.md`, `BACKLOG.md`, `RUN_LOG.md`를 실제 구현 상태에 맞게 갱신했다.
- format: 변경 Dart 6개와 신규 테스트 1개에 `dart format`을 적용했다.
- Functions: `npm.cmd --prefix functions run lint`, `npm.cmd --prefix functions run build` 모두 통과했다. 기존 firebase-functions outdated 경고는 dependency upgrade 범위 밖이라 유지했다.
- Emulator: sandbox 내 첫 시도는 Firebase CLI의 사용자 config read가 EPERM으로 코드 실행 전에 중단됐다. 승인된 로컬 실행으로 demo project만 재실행해 profile 30, anonymous 26, member/tier 27, personal schedules 20, personal training logs 37, legacy 28로 총 168개가 모두 통과했다. 실제 project나 비에뮬레이트 서비스에는 연결하지 않았다.
- Flutter: sandbox 내 첫 두 전체 테스트 시도는 workspace 밖 Flutter SDK cache/lock 접근 때문에 각각 10분 제한과 수동 중단으로 결과를 얻지 못했다. 성공으로 처리하지 않고 승인된 로컬 SDK cache 접근으로 재실행했다. 신규 region 단위 테스트 1개와 전체 `flutter test --no-pub -r expanded` 187개가 모두 통과했다. 변경 범위 `flutter analyze --no-pub`도 `No issues found`로 통과했다.
- 빌드: `flutter build apk --debug --no-pub`, `flutter build apk --release --no-pub`, `flutter build appbundle --release --no-pub` 모두 통과했다. `app-debug.apk`, 109.5MB `app-release.apk`, 74.6MB `app-release.aab`가 생성됐다.
- 판정: region, v1 maxInstances, 실제 query index의 코드 NO-GO는 해소했다. 그러나 Console 수동 확인, 현재 Published Rules/count 백업, billing/bucket/IAM, managed export가 완료되지 않아 실제 배포는 계속 NO-GO다. 실제 deploy/export/admin 생성은 실행하지 않았고 다음 백로그로 이동하지 않았다.

## 2026-07-17 — Firebase 실제 배포 준비 read-only 감사

- 범위: `prompts/24_firebase_deployment_readiness.md`만 수행했다. 실제 Firebase deploy, Firestore export/restore, Auth provider·claim 변경, 관리자 생성, migration/backfill/delete와 다음 백로그는 진행하지 않았다.
- project 확인: `.firebaserc`, `firebase.json`, Android config safe field와 CLI 선택 project가 모두 `more-than-fitness-f6adb`로 일치했다. CLI 15.23.0은 `mtgroup.fitnessapp@gmail.com`으로 로그인돼 있다. API key는 읽거나 기록하지 않았다.
- 환경 판정: project display name은 `More Than Fitness`, state는 ACTIVE다. Firestore `(default)`는 `asia-northeast3`, Native/Standard이고 2025-05-10 생성이다. code/이름만으로 dev/prod를 확정할 수 없어 “기존 실제 데이터가 있는 미분류 단일 project”로 분류하고 Console owner 확인 전 NO-GO로 정했다.
- 보호 상태: Firestore PITR disabled, delete protection disabled, version retention 1시간, managed backup schedule 0개, managed backup 0개다. Storage config bucket은 `more-than-fitness-f6adb.firebasestorage.app`이지만 실제 bucket location/billing/IAM은 Console 확인 전 미확정이다.
- 로컬 Functions: top-level export는 14개이며 모두 v1 callable, Node 22, region 미지정으로 `us-central1`이다. local endpoint metadata는 `gcfv1`과 `maxInstances=null`을 보여 `setGlobalOptions({maxInstances:10})`이 적용되지 않는다. Emulator도 14개를 `us-central1`로 로드했다.
- 현재 배포 Functions: read-only `functions:list` 결과 0개다. 따라서 공통/원격 전용 함수는 없고 로컬 14개가 전부 미배포다.
- Anonymous 출시 필수 9개: `bootstrapAnonymousBeginnerProfile`, `bootstrapTrainerProfile`, `transitionAnonymousProfileToLinked`, `updatePersonalTrainerProfile`, `createManagedMember`, `transitionManagedMemberState`, `updateManagedMember`, `finalizePersonalTrainingLog`, `cancelPersonalTrainingLog`. 실제 Flutter `httpsCallable` 이름에서 확인했다.
- 보류 함수 5개: 관리자 gate용 `completeInitialPasswordChange`는 별도 관리자 단계로 분리했다. Flutter 직접 호출이 없는 legacy `chargeOnce`, `cancelNoShow`, `lockConsent`, `unlockConsent`는 첫 Anonymous 배포에서 제외했다. training log draft와 schedule CRUD는 client Rules 경로이며 존재하지 않는 Function 이름을 만들지 않았다.
- 선택 배포안: 전체 Functions 일괄 배포를 금지하고 A1 profile/account 4개 → smoke → A2 member/tier 3개 → smoke → A3 training log 2개 순서로 작성했다. 관리자 1개와 legacy 4개는 기본안에 포함하지 않았다.
- Rules: local `trainer_profiles`, members, schedules, training_logs는 owner personal 권한과 Function 전용 write를 구분한다. anatomyRecords, contracts, contractCounters, sign_requests, lesson_products, member_groups, notification queue와 More Care는 personal에 열지 않는다. legacy는 두 admin claim과 비밀번호 변경 완료를 요구한다.
- deployed Rules: Firebase CLI에 현재 Rules source 조회 명령이 없어 자동 확보하지 못했다. Console에서 Published source와 metadata를 복사하고 local diff를 승인하기 전 Rules deploy는 NO-GO다.
- index: local은 schedules `trainerId/workspaceType/startAt ASC`, training_logs `trainerId/workspaceType/memberId/startAt DESC` 두 개다. production composite index는 0개다. 회원 phone duplicate query의 세 equality는 local composite가 없으며 Emulator가 production index를 강제하지 않으므로 첫 production smoke에서 정확히 확인하고 index 오류 시 중단하도록 했다. 존재하지 않는 status query index는 추가하지 않았다.
- Storage: personal 핵심 profile/member/schedule/training log text/MyPage account 흐름은 upload를 호출하지 않는다. 현재 Storage 사용은 legacy profile/inbody/contract/signature image이며 local Rules도 legacy admin 전용이므로 첫 배포에서 `storage:rules`를 제외했다.
- 백업/rollback: current Rules/source/count, Firestore managed export, bucket/IAM/billing, immutable source checkpoint, Rules 전용 rollback config, function 개별 rollback, index 수동 검토, Auth provider/claim/token 영향, release 이후 anonymous data 보존 정책을 문서화했다. 현재 backup과 이전 deployed Function revision이 없어 실제 rollback 준비는 미완료다.
- 문서: `FIREBASE_DEPLOYMENT_READINESS.md`, `FIREBASE_FUNCTIONS_DEPLOY_MATRIX.md`, `FIRESTORE_RULES_DEPLOY_MATRIX.md`, `FIREBASE_BACKUP_AND_ROLLBACK.md`, `RELEASE_SMOKE_TEST.md`, `BACKLOG.md`, `RUN_LOG.md`를 작성/갱신했다.
- Functions 검증: `npm.cmd --prefix functions run lint`, `npm.cmd --prefix functions run build` 통과.
- Emulator: 첫 실행은 Java가 PATH에 없어 code 실행 전 중단됐고 Android Studio JBR을 현재 process PATH에만 추가해 재실행했다. profile 30, anonymous identity 26, member/tier 27, personal schedule 20, personal training log 37, legacy workspace 28로 총 168개가 모두 통과했다. 기존 firebase-functions outdated warning은 남겼다.
- Flutter: `flutter test --no-pub` 186개 모두 통과. 앱/Dart/Rules/Functions source를 수정하지 않은 문서 감사라 변경 범위 Dart analyze와 format 대상은 없다.
- 문서 검증: 로컬 export 14개가 Functions 배포 매트릭스에 전부 존재하고 전체 Functions 일괄 배포 명령이 기본안에 없음을 확인했다. `git diff --check` exit 0이었다.
- 남은 go/no-go: project dev/prod 판정, Auth provider/domain/template/App Check, current Rules/count, billing/export/bucket/IAM, immutable source checkpoint, v1 cost cap, Functions/Firestore region 차이, production member equality query를 확인해야 한다.
- 배포/백로그: 실제 배포·export·admin/claim/provider/data 변경을 실행하지 않았고 다음 백로그로 이동하지 않았다.

## 2026-07-17 — Release APK ML Kit 한국어 인식 R8 복구

- 범위: 기존 Release APK/AAB를 막던 ML Kit text recognition R8 오류만 수정했다. Flutter 시작 라우팅, Firebase Rules/Functions, 음성·텍스트 기능 로직, 실제 Firebase 배포와 다음 백로그는 진행하지 않았다.
- 감사: `pubspec.yaml`의 `google_mlkit_text_recognition 0.15.1`, Android app Gradle, Manifest, 기존 ProGuard 파일 유무, 두 Dart OCR 사용처, 설치된 플러그인 Android source, Release runtime dependency tree와 기존 `missing_rules.txt`를 확인했다. 앱의 `client_card_page.dart`와 `personal_training_log_page.dart`는 모두 `TextRecognitionScript.korean`만 사용한다.
- 정확한 누락 클래스: `ChineseTextRecognizerOptions`/`Builder`, `DevanagariTextRecognizerOptions`/`Builder`, `JapaneseTextRecognizerOptions`/`Builder`, `KoreanTextRecognizerOptions`/`Builder` 총 8개였다.
- 실제 원인: 플러그인은 라틴 `com.google.mlkit:text-recognition:16.0.1`만 `implementation`으로 제공하고 중국어·데바나가리·일본어·한국어 모듈은 `compileOnly`로 참조한다. 수정 전 Release runtime tree에는 라틴 모듈만 있었지만 플러그인 bytecode의 언어 선택 switch가 네 선택 언어 클래스를 모두 참조해 R8이 누락 클래스로 판정했다. 특히 앱이 실제 호출하는 한국어 모듈도 runtime에 없었다.
- 최소 수정: `android/app/build.gradle.kts`에 실제 사용 모듈 `com.google.mlkit:text-recognition-korean:16.0.1`을 명시하고 Release에 기존 축소를 유지한 채 `proguard-rules.pro`를 연결했다. 새 규칙은 사용하지 않는 중국어·데바나가리·일본어 옵션 클래스 6개만 `-dontwarn` 처리한다. 실제 사용하는 한국어 클래스는 경고 억제하지 않고 dependency로 해결했다. `minifyEnabled`와 resource shrinking을 끄지 않았고 다른 언어 모델이나 패키지 업그레이드는 추가하지 않았다.
- dependency 확인: 수정 후 `releaseRuntimeClasspath`에 `text-recognition-korean:16.0.1`과 `play-services-mlkit-text-recognition-korean:16.0.1`이 포함됐다. 중국어·데바나가리·일본어 runtime 모듈은 포함되지 않았다.
- Release APK: `flutter build apk --release --no-pub` 통과. `build/app/outputs/flutter-apk/app-release.apk` 109.5MB 생성. 성공 빌드 후 `build/app/outputs/mapping/release`에 새 `missing_rules.txt`가 생성되지 않았다.
- Release AAB: `flutter build appbundle --release --no-pub` 통과. `build/app/outputs/bundle/release/app-release.aab` 74.6MB 생성.
- 회귀: `flutter test --no-pub` 186개 전부 통과. `flutter build apk --debug --no-pub` 통과.
- analyze: ML Kit 실제 사용 파일 2개를 `--no-fatal-warnings --no-fatal-infos`로 분석해 error 0으로 통과했다. 두 기존 대형 화면의 warning/info 364건은 범위 밖이라 수정하지 않았다. 전체 analyze는 저장소 root의 기존 `node_modules/firebase-tools/templates/init/functions/dart/server.dart` 템플릿 오류 6건과 기존 lint 때문에 exit 1이었으며 이번 Android 변경에서 생긴 오류는 아니다.
- diff: `git diff --check` exit 0. 기존 dirty worktree와 범위 밖 변경은 유지했다.
- 변경 파일: `android/app/build.gradle.kts`, 신규 `android/app/proguard-rules.pro`, `docs/agent/RUN_LOG.md`, `docs/agent/BACKLOG.md`. Dart 파일 변경이 없어 format 대상은 없었다.
- 미검증/잔여 위험: APK/AAB 빌드로 R8와 패키징은 검증했지만 실제 Android 기기에서 한국어 OCR 인식 실행은 이번 작업에서 수동 검증하지 않았다. Release signing은 저장소 기존 debug signing 설정을 그대로 사용했으며 배포용 서명 전환은 별도 작업이다.
- 배포/백로그: 실제 Firebase deploy와 운영 데이터 변경을 실행하지 않았고 다음 백로그로 이동하지 않았다.

## 2026-07-17 — 시작 로그인 gate 제거와 Anonymous 실제 personal 홈 진입

- 범위: `prompts/23_remove_start_login_gate.md`만 수행했다. Google·카카오, contracts/sign_requests 권한, 계약 상태 머신, legacy migration/backfill, 실제 Firebase deploy와 다음 백로그는 진행하지 않았다.
- 선행 회귀: 코드 변경 전 anonymous identity 26개, profile bootstrap 30개, managed member/tier 27개, personal schedule 20개, personal training log 37개 Emulator가 모두 통과했다. 관련 Flutter 64개, 전체 Flutter 184개, 변경 예상 범위 analyze, Debug APK, `git diff --check`도 통과했다.
- 실제 원인: `AppAccountSnapshot.fromUser`가 null과 anonymous를 모두 Guest로 축약하고 user identity를 버려 `AppAccountGate`가 `GuestStartPage`로 보냈다. linked personal profile 판정도 `tier == Beginner`를 요구해 승급 계정의 재실행을 막을 수 있었다.
- 시작 분기: root gate가 raw Auth user를 구독한다. null이면 `ensureAnonymousSession`, anonymous면 같은 UID의 `bootstrapAnonymousBeginnerProfile`을 완료한 뒤 UID-scoped canonical personal 홈을 연다. 기존 anonymous는 새 Auth 호출 없이 같은 UID를 사용한다. linked personal은 로그인 화면 없이 canonical profile 확인 후 같은 홈에 진입한다.
- 실제 personal 홈: legacy owner 없는 `HomePage`가 아니라 기존 personal member/schedule/training log/MyPage repository를 묶은 `PersonalWorkspaceReadyPage`를 사용한다. 제목을 `홈`으로 정리했다. Guest sample과 legacy 데이터를 personal subtree에 전달하지 않는다.
- 오류 UX: anonymous session/profile 준비 전에는 `함께 관리할 준비를 하고 있어요.` splash만 표시한다. 실패 시 실제 홈이나 sample로 가지 않고 재시도 화면을 표시한다. 자동 무한 재시도와 session 삭제가 없고 로그에는 typed error code만 남기며 UID/token을 출력하지 않는다.
- 로그아웃/격리: linked 마이페이지는 현재 UID Android widget cache를 먼저 지운 뒤 Auth sign-out한다. root가 새 anonymous UID/profile을 만들고 UID key로 personal subtree를 교체해 이전 member/schedule/training log stream을 폐기한다. 기존 linked 서버 데이터는 보존하며 새 UID로 병합·복사하지 않는다.
- 관리자/Debug: `mustChangePassword`, platform admin과 legacy 승인 claim, personal/legacy 선택을 유지했다. Debug legacy 직접 진입은 Debug personal 홈 overlay로 옮겼고 Profile/Release 코드에서는 `kDebugMode`로 차단된다. 보존된 Guest/email auth 파일은 삭제하지 않았다.
- 등급/계약 회귀: 시작 router는 tier/count/profileComplete를 쓰지 않는다. linked personal 판정에서 Beginner 고정 조건만 제거해 Amateur/Semi-Pro/Pro 재진입을 허용했다. 10번째 허용, 11번째 연결·내 정보 gate, UID 유지 연결, 후원 분리, 계약서·전자서명 Semi-Pro gate 코드는 변경하지 않았다.
- 수정 파일: `lib/pages/account_gate.dart`, `lib/pages/personal_workspace_ready_page.dart`, `lib/pages/personal_my_page.dart`, `lib/services/app_account_service.dart`, `lib/services/app_workspace_mode.dart`, `lib/services/linked_account_access_service.dart`, 관련 Flutter 테스트와 지정 docs/agent 문서.
- format: 변경 Dart와 테스트 9개 파일에 `dart format` 적용 완료.
- 관련 테스트: 신규 설치 null, anonymous 생성/bootstrap, 기존 anonymous UID 유지, bootstrap 실패·재시도, linked 직접 진입, linked 로그아웃 후 새 anonymous UID, 이전 subtree dispose, widget cache 선행 정리, 관리자/Debug/마이페이지 회귀 등 52개 통과.
- 전체 테스트: `flutter test --no-pub -r expanded`, 186개 모두 통과.
- analyze: 실제 변경 9개 항목은 `No issues found`. 변경하지 않은 `main.dart`까지 포함한 첫 실행은 기존 `prefer_final_fields` info 1건으로 exit 1이어서 범위 밖 소스를 수정하지 않고 분리 기록했다.
- Emulator: 최종 변경은 Flutter 시작 router뿐이며 Rules/Functions는 수정하지 않았다. 선행 Auth/Profile/Member/Schedule/TrainingLog demo Emulator 전부 통과 상태를 유지했다.
- 빌드: Debug APK와 Profile APK 성공. `app-debug.apk`, `app-profile.apk`가 생성됐다. Release는 기존 `google_mlkit_text_recognition`의 Chinese/Devanagari/Japanese/Korean recognizer class 누락으로 `minifyReleaseWithR8`에서 실패했으며 시작 라우팅 컴파일 오류가 아니다.
- diff: `git diff --check` 통과. 기존 dirty worktree와 범위 밖 파일은 유지했다.
- 미검증: 실제 Firebase project의 anonymous/email provider, Functions/Rules 배포, 실제 기기 신규 설치·재실행·계정 연결·로그아웃·widget 잔상은 검증하지 않았다. Release R8 의존성 복구도 별도 작업이다.
- 다음 백로그: 이동하지 않음.

## 2026-07-16 — Anonymous/Linked personal 레슨일지 소유권 격리

- 범위: `prompts/21_anonymous_personal_training_logs.md`만 수행했다. 시작 로그인 gate, contracts·sign_requests·Storage Rules, 공개 원격서명, legacy 데이터와 기존 legacy 화면은 변경하지 않았다. 실제 Firebase deploy와 다음 백로그 이동도 하지 않았다.
- 선행 회귀: 구현 전에 Anonymous identity Emulator 26개, profile 30개, member/tier 27개, personal schedule 20개, 관련 Flutter 23개, 전체 Flutter 165개가 통과했다. 기존 변경 범위 analyze는 `No issues found`, Debug APK build와 `git diff --check`도 통과했다.
- 감사 원인: 기존 root `training_logs` 목록은 memberId만 사용하고 owner/workspace 조건이 없었다. 기존 빠른서명은 `quick_sign_{scheduleId}` 또는 member/time ID와 page 내부 transaction을 사용하고, 정식 레슨일지와 홈은 별도의 확정·취소 transaction을 사용했다. 빠른서명 재저장은 deduction ID로 회차 재차감은 막아도 `lessonStats.confirmedCount` 같은 통계를 다시 증가시킬 수 있었다.
- canonical 모델: personal 문서는 Firestore random ID를 사용하고 `lessonLogId == documentId`, `trainerId == Auth UID`, `workspaceType=personal`, `schemaVersion=1`, memberId, 선택 scheduleDocId, lessonDate/startAt/endAt, lessonType, status, source, memo와 서버 timestamp를 가진다. owner 없는 legacy 문서에 trainerId를 추가하거나 신규 UID로 귀속하지 않았다.
- query/관계: personal 목록은 `trainerId == uid`, `workspaceType == personal`, `memberId`, startAt 기간을 모두 사용한다. member는 같은 UID의 canonical personal 회원이어야 한다. schedule을 연결하면 같은 UID/personal이고 schedule memberId와 log memberId가 정확히 같아야 한다. schedule 없는 직접 레슨일지는 허용하고 이름만 있는 미연결 일정에는 log를 자동 생성하지 않는다.
- draft/자동저장: client Rules는 canonical draft create와 draft의 scheduleDocId·lessonDate·startAt·endAt·lessonType·memo 자동저장만 허용한다. trainerId/workspaceType/lessonLogId/memberId/source/createdAt과 finalized 상태·차감·통계 필드는 client가 바꿀 수 없다. 본인 draft만 삭제할 수 있다.
- 확정 transaction: `finalizePersonalTrainingLog`가 log, member, 선택 schedule을 읽어 owner/member 관계를 검증하고 member 회차·상태별 lessonStats, log 확정 증거, schedule 상태와 lesson ledger를 한 transaction에서 갱신한다. `completed`와 `no_show_deducted`만 remaining을 1 감소시키고, `no_show_not_deducted`와 `service`는 회차를 유지한다.
- 멱등/부분 실패: log가 같은 최종 상태면 기존 결과를 반환하고 다른 상태로 재확정하지 않는다. 따라서 중복 확정은 회차·통계를 다시 변경하지 않는다. ledger create를 포함한 모든 write는 같은 transaction이며 owner·관계·ledger 충돌 실패 시 member/log/schedule 어느 것도 부분 반영되지 않는다.
- 확정취소 transaction: `cancelPersonalTrainingLog`가 원래 status와 `deductionApplied`를 읽어 상태별 통계와 confirmed 통계를 1회 원복한다. 실제 차감된 경우에만 remaining/done을 복구하고 reverse ledger를 만든다. schedule의 이전 status·attended·attendanceOverride를 복원하고 확정 cache를 제거하며 log는 `confirm_cancelled`로 보존한다. 두 번째 취소는 기존 결과만 반환한다.
- UI: personal 회원 카드 탭에서 회원별 레슨일지 목록·상태 필터·확정취소 보관함을 열 수 있다. 새 draft는 입력 중 600ms debounce로 자동저장한다. personal 일정의 빠른 레슨일지는 연결 member가 있을 때 같은 화면/repository를 사용하며 source만 `home_quick_sign`이다. 기존 Home 빠른서명과 legacy 정식 레슨일지는 변경하지 않았다.
- anatomy: canonical personal parent read와 draft Rules는 열렸지만 `anatomyRecords` child는 parent metadata·child allowlist·고아 정책의 후속 Emulator 작업 전까지 legacy 관리자 전용으로 유지했다. personal 화면에서 anatomy 진입을 새로 열지 않았다.
- 변경 파일: `functions/src/personal_training_logs.ts`, `functions/src/index.ts`, `lib/models/personal_training_log.dart`, `lib/services/personal_training_log_repository.dart`, `lib/pages/personal_training_log_workspace_page.dart`, personal workspace/schedule 연결 파일, `firestore.rules`, `firestore.indexes.json`, Flutter·Emulator 테스트, root test script와 지정 docs/agent 문서다.
- format/lint/build: 변경 Dart 6개 파일에 `dart format` 적용 결과 최종 0 changed였다. Functions `npm.cmd --prefix functions run lint`와 `run build`가 모두 통과했다.
- 관련 Flutter 테스트: personal 레슨일지 12개, personal 일정 16개, managed member 7개, 관리자·계약 등급 gate 13개로 합계 48개가 통과했다.
- personal Emulator: demo project에서 37개가 통과했다. Anonymous/Linked draft, owner/member/date query, filterless query 차단, legacy·다른 UID 제외, member/schedule 관계, 자동저장, identity 불변, client finalize 차단, 네 확정 상태, 회차·통계·schedule 동기화, 중복 확정·취소, 상태별 원복, transaction 실패 무반영, 빠른 레슨일지 공통 Function, archive owner 격리, anatomy/contracts/sign_requests 계속 거부를 확인했다.
- 최종 회귀: Anonymous identity 26개, profile 30개, member/tier 27개, personal schedule 20개, legacy 관리자 28개 Emulator가 재통과했다. 변경 범위 analyze는 `No issues found`, 전체 Flutter 테스트 177개 통과, Debug APK는 `build/app/outputs/flutter-apk/app-debug.apk`로 생성됐다. Emulator 파일 구문과 JSON 구조를 확인했고 최종 `git diff --check`도 exit 0으로 통과했다.
- 환경/경고: Emulator는 Node 22.20.0과 Android Studio JBR, demo project ID만 사용했다. 기존 `firebase-functions` 버전 경고가 남지만 패키지 업그레이드는 요청 범위 밖이라 수행하지 않았다.
- 미검증/후속: 실제 Firebase Functions·Rules·복합 index 배포, 실제 프로젝트 연결, 실제 기기에서 Anonymous/Linked 재실행·UID 전환·회차 표시 검증은 하지 않았다. personal anatomy child Rules와 MyPage 연결·시작 gate 제거는 후속 작업이며 이번에는 진행하지 않았다.

## 2026-07-16 — Anonymous/Linked personal 일정 소유권 격리

- 범위: `prompts/20_anonymous_personal_schedules.md`만 수행했다. 시작 로그인 gate, training_logs·contracts·anatomy Rules, legacy 데이터, Functions는 변경하지 않았고 실제 Firebase 배포와 다음 백로그 이동도 하지 않았다.
- 선행 회귀: 일정 구현 전에 Anonymous identity Emulator 26개, profile bootstrap Emulator 30개, managed member/tier Emulator 27개, 전체 Flutter 테스트 149개가 통과했다. 기존 회원 변경 범위 analyze는 `No issues found`, Debug APK build와 `git diff --check`도 통과했다.
- 실제 감사 원인: legacy `HomePage` 주간 query는 `startAt` 범위만 사용하고 owner 조건이 없었다. 신규/이동 target 문서 ID는 `yyyyMMdd-HHmm-요일` 시간 key라 다른 trainer가 같은 시각을 쓰면 같은 root 문서와 충돌한다. 생성·수정·이동·삭제·멀티·주간 복사·회원 다음 일정·운영통계·위젯도 legacy owner 없는 흐름에 연결돼 있어 일부만 UID화하면 두 workspace가 섞이는 구조였다.
- 선택 구조: 기존 legacy `HomePage`와 문서는 그대로 두고 personal 전용 모델·repository·화면을 추가했다. 신규 일정은 Firestore random document ID와 `scheduleId == documentId`, `trainerId == 현재 Auth UID`, `workspaceType=personal`, `schemaVersion=1`을 사용하며 `dateKey`·`slotKey`는 시간 identity가 아닌 조회·표시 필드다.
- 조회·쓰기: personal 주간 stream은 `trainerId == uid`, `workspaceType == personal`, `startAt` 기간 범위를 모두 적용한다. 생성·멀티 등록·주간 복사는 공통 canonical builder를 사용한다. 수정·삭제는 transaction에서 실제 문서를 다시 읽어 owner와 확정 상태를 검증한다. 이동은 기존 문서를 지우지 않고 같은 document ID를 transaction update하므로 실패 시 원본 일정이 남는다.
- 회원 연결: `memberId`가 있으면 같은 UID의 personal 회원이고 삭제 상태가 아닌지 확인한다. 다른 trainer 회원은 거부한다. 이름만 입력한 임시 일정은 `memberId` 없이 저장하며 회원 조회나 canonical 회원 생성 Function을 호출하지 않는다.
- Rules/index: `schedules/{scheduleId}`에 본인 personal 일정의 최소 read/create/update/delete만 추가했다. owner·workspace·scheduleId·schemaVersion·createdAt은 불변이며 변경 필드 allowlist, 유효 시간, 서버 timestamp, 회원 owner, 확정 일정 잠금을 검사한다. 필요한 `trainerId + workspaceType + startAt` 복합 index를 추가했다. training_logs·contracts·anatomy 및 Storage Rules는 건드리지 않았다.
- Android widget: personal payload는 현재 UID의 personal 일정만 필터링한다. cache에 owner UID를 저장하고 UID가 바뀌면 기존 일정·다음 레슨 cache를 먼저 비운다. personal 로그아웃에서도 widget cache를 제거한다. Guest 로컬 샘플과 legacy payload를 personal repository에 섞지 않았다.
- UI: Linked personal 작업공간에 주간 일정 화면 진입을 추가했다. 단일 등록·수정·시간 이동·삭제·명시적 3주 멀티 등록·다음 주 복사를 제공한다. Anonymous 시작 gate는 요청대로 유지했으며 Anonymous 동작은 repository와 Rules Emulator harness로 검증했다.
- 변경 파일: `lib/models/personal_schedule.dart`, `lib/services/personal_schedule_repository.dart`, `lib/services/personal_schedule_widget_sync_service.dart`, `lib/services/mtf_home_widget_service.dart`, `lib/pages/personal_schedule_page.dart`, `lib/pages/personal_workspace_ready_page.dart`, `firestore.rules`, `firestore.indexes.json`, personal 일정 Flutter·Emulator 테스트, root Emulator script, 지정된 docs/agent 문서.
- format: 변경 Dart 7개 파일에 `dart format`을 실행했고 `0 changed`였다.
- 관련 Flutter 테스트: personal 일정 16개와 기존 managed member 7개, 합계 23개가 통과했다. random ID, canonical owner, 멀티, 수정, 같은-ID 이동, 이동 실패 원본 보존, 삭제, 회원 owner, 임시 일정 비생성, 복사, UID 변경, 재진입, 확정 잠금, widget UID·로그아웃 정리를 확인했다.
- Rules Emulator: demo project에서 personal schedule 20개가 통과했다. Anonymous/Linked create/read, owner query, filterless query 거부, 다른 UID 차단, owner 없는 legacy 제외, 같은 시간 두 trainer 분리, identity 불변, 회원 owner, 확정 잠금, training_logs·contracts 계속 거부를 확인했다. legacy 관리자 28개도 재통과했다.
- 최종 회귀: Anonymous identity 26개, profile bootstrap 30개, member/tier 27개 Emulator가 다시 통과했다. 변경 범위 analyze는 `No issues found`, 전체 Flutter 테스트는 165개 통과, Debug APK는 `build/app/outputs/flutter-apk/app-debug.apk`로 생성됐다. Emulator 테스트 파일 구문과 JSON 구조를 확인했고 최종 `git diff --check`도 exit 0으로 통과했다.
- 환경/경고: Firebase Emulator는 Node 22.20.0과 Android Studio JBR로 실행했다. 기존 `firebase-functions` 버전이 오래됐다는 경고가 남지만 요청 범위 밖이라 업그레이드하지 않았다. 첫 sandbox 실행은 firebase-tools 사용자 설정 파일 EPERM으로 중단되어 동일 demo Emulator 명령을 승인된 로컬 권한으로 재실행했다.
- 미검증·후속: 실제 Firebase Rules·복합 index 배포와 실제 기기에서의 재실행·UID 전환·Android widget 확인은 하지 않았다. personal 운영통계·회원 다음 일정·training_logs는 아직 personal 화면에 연결하지 않았으며 후속 owner 격리가 필요하다. 실제 배포 전 Rules/index diff와 실제 기기 검증이 필요하다.

## 2026-07-16 — Anonymous Beginner 회원 10명과 서버 등급 승급

- 작업 기준: 저장소에 `prompts/19_anonymous_members_tier_promotion.md`가 존재하지 않아 사용자 메시지의 명시 조건을 기준으로 수행했다. 다른 백로그로 이동하지 않았다.
- 기존 원인: 회원 Function이 익명 사용자를 거부하고 active/paused 현재 수 10명만 관리했다. 회원 입력은 이름·전화번호·메모만 받아 성별·활동 지역·전화번호 중복을 검증하지 않았으며, 누적 유효 회원 수와 등급은 서버 권위로 관리되지 않았다.
- 회원 저장: `createManagedMember`/`updateManagedMember` transaction에서 현재 Auth UID를 `trainerId`로 고정하고 이름, 성별, 정규화 전화번호, 활동 지역을 검증한다. 별도 claim 문서 없이 `trainerId + workspaceType + phoneNormalized` query로 같은 workspace의 중복만 차단하고 동일 idempotency 재시도는 같은 결과를 반환한다. 전화번호 원문·정규화값·단순 hash를 문서 ID나 전역 path에 사용하지 않는다.
- 한도: anonymous Beginner는 10번째 유효 회원까지 저장할 수 있다. 11번째부터 provider 연결이 없으면 `account_link_required`, 내 정보가 미완료면 `profile_completion_required`로 저장을 중단한다.
- 등급: `lifetimeQualifiedMemberCount`와 `tier`/`earnedTier`/`earnedTierRank`를 Function transaction에서 갱신한다. 연결·내 정보 완료·누적 10명은 Amateur, 누적 30명은 Semi-Pro, 50명은 Pro다. 현재 등급보다 낮은 값은 저장하지 않아 휴면·만료·삭제 후 자동 강등하지 않는다. 후원 상태는 평가 입력에서 제외했다.
- 계정·프로필: 기존 anonymous UID의 provider 연결 transaction과 개인 프로필 수정 callable이 같은 등급 평가 함수를 사용한다. 신규 UID 로그인, 계정 자동 병합, legacy 회원 귀속은 추가하지 않았다.
- Rules: anonymous를 포함한 로그인 사용자는 `trainerId == Auth UID`이고 `workspaceType == personal`인 자기 회원만 읽을 수 있다. client 회원 create/update/delete는 거부한다. schedules, training_logs, contracts Rules는 열지 않았다.
- Flutter: personal 회원 저장 화면에 성별·활동 지역 필수 입력을 연결하고, 사용량 표시는 누적 유효 회원 수와 서버 등급을 사용한다. 시작 로그인 gate는 유지했다.
- 수정 파일: `functions/src/managed_members.ts`, `functions/src/profile_bootstrap.ts`, `functions/src/tier_qualification.ts`, `functions/src/index.ts`, `firestore.rules`, `lib/services/managed_member_workspace_service.dart`, `lib/pages/personal_workspace_ready_page.dart`, 관련 Flutter·Emulator 테스트, `package.json`, 관련 `docs/agent` 문서.
- format: 변경 Dart 3개에 `dart format` 적용 완료.
- Functions: `npm.cmd --prefix functions run lint` 통과, `npm.cmd --prefix functions run build` 통과.
- 관련 Flutter 테스트: 회원 workspace·익명 identity·계정·관리자 회귀 47개 통과.
- 추가 정책 검증: 전화번호 SHA claim 구현을 제거하고 owner-scoped transaction query로 교체한 뒤 `managed_member_workspace_test.dart` 7개를 다시 실행했다. 필수값 안내와 Function 실패 시 dialog를 닫지 않고 작성 중 입력값을 유지하는 회귀가 통과했다.
- Emulator: demo project에서 신규 회원·등급 27개, 최신 익명 identity 회귀 26개, 기존 profile 회귀 30개 시나리오가 모두 통과했다. 필수값 누락 시 문서 미생성, 같은 trainer의 순차·동시 중복 차단, 다른 trainer의 동일 전화번호 허용, 10번째 허용, 11번째 차단, 30명/50명, 멱등성, UID 격리, 비하락, 후원 제외, 다른 컬렉션 차단을 확인했다. 첫 최신 identity 실행은 Java 경로 미설정으로 기동 실패했고 Android Studio JBR을 명시해 재실행 통과했다.
- 전체 Flutter 테스트: `flutter test --no-pub -r expanded` 149개 통과.
- analyze: 변경 Dart 3개 범위 `flutter analyze --no-pub ...` 결과 `No issues found`.
- build: `flutter build apk --debug --no-pub` 통과, `build/app/outputs/flutter-apk/app-debug.apk` 생성.
- 남은 경고: Emulator가 현재 `firebase-functions` 버전이 오래됐다고 경고했다. 요청 범위와 대규모 패키지 변경 금지에 따라 업그레이드하지 않았다.
- 배포: 실제 Firebase deploy, 운영 계정·데이터 사용, legacy migration을 실행하지 않았다.
- 남은 검증: 실제 프로젝트 배포 전 Rules/Functions diff, region·App Check, 실제 기기 회원 저장·계정 연결·프로필 완료 흐름은 별도 승인이 필요하다.
- 다음 백로그로 이동하지 않았다.

## 2026-07-19 — DEV MyPage 저장·직업 문구·비밀번호 배너·personal tier 복구

- 범위와 원인: DEV MyPage의 저장 버튼은 `updatePersonalTrainerProfile`을 먼저 호출한 뒤 닉네임 변경 시 `completeNicknameOnboarding`을 다시 호출했다. DEV에는 앞 함수가 배포되지 않아 첫 단계에서 `not-found/unknown`으로 끝났고 닉네임 단계까지 도달하지 못했다. 실명은 `displayName`, 직업은 `affiliationType`으로만 보내던 호환 매핑도 확인했다. 두 callable이 연속 실행되면 첫 저장만 반영되는 부분 성공 위험도 있었다.
- 저장 경계: MyPage personal 저장을 `updatePersonalTrainerProfile` 한 번으로 통합했다. callable은 `context.auth.uid`만 사용하고 `trainer_profiles/{uid}`의 personal/active/role/account 상태를 transaction에서 확인한다. 클라이언트 payload UID와 알 수 없는 필드는 거부한다. 허용 입력은 기존 `displayName`, `phone`, `activityRegion`, `primaryActivity`, `affiliationType`에 `nickname`, `realName`만 추가했다. nickname은 trim 후 1~6자이며 tier·회원 수·admin claim 등 권한 필드는 client 입력으로 받지 않는다. 기존 서버 권위 profile completion/tier 계산은 유지했다.
- 원자성·확인: 닉네임·실명·직업을 같은 transaction에서 저장해 callable 간 부분 성공을 없앴다. 성공 응답 뒤 `Source.server`로 현재 UID profile을 다시 읽어 `nickname`, `realName`, `affiliationType`이 모두 요청값과 같은 경우에만 성공 안내를 표시한다. 실패 시 화면과 입력값을 유지한다. `[MTF_MY_PAGE_SAVE_START]`, `[MTF_MY_PAGE_SAVE_STEP]`, `[MTF_MY_PAGE_SAVE_DONE]`에는 변경 여부·단계·안전한 error code만 기록하고 전화번호·이메일·실명 값은 기록하지 않는다.
- 이름 정책: nickname과 realName이 모두 비면 저장을 막고, nickname만 있으면 저장한다. realName만 있을 때는 기존 명시 확인을 거쳐야 nickname에 복사하며 6자 초과 실명을 자동 축약하지 않는다. nickname을 공개 ID로 사용하거나 사용자 간 중복을 제한하지 않았다.
- 직업 AI FC 문구: nickname 존재 시 `어떤 직업으로 회원님들께 안내할까요?`, 없을 때 `회원님들께 어떤 직업으로 안내할까요?`를 사용한다. nickname을 직책/호칭처럼 삽입하지 않았고 기존 선택값과 `affiliationType` 저장 구조는 유지했다.
- 비밀번호 변경 배너: MyPage 더보기의 action tile은 고정 높이를 사용하지 않고 `Expanded` 텍스트와 줄바꿈, 독립 trailing icon 공간을 유지한다. bottom sheet 내용을 `SingleChildScrollView`로 감싸 작은 화면·큰 글자에서도 높이 초과를 피했다. 320/360/412dp와 text scale 1.0/1.3/1.8의 9개 widget 시나리오가 모두 통과했다.
- personal tier: canonical source는 `trainer_profiles/{currentUid}.tier`다. 기존 Home은 tier 문서를 읽어도 회원·상품·일정 stream까지 모두 ready여야 표시했고, 빈/알 수 없는 tier를 조용히 Beginner로 바꿨다. personal Home readiness를 profile stream으로 한정하고 tier 표기를 대소문자·하이픈 변형까지 canonical parsing한다. profile 없음/빈 값/알 수 없는 값/읽기 실패는 Beginner로 낮추지 않고 `확인실패`로 구분한다. MyPage도 서버 profile을 직접 읽고 같은 parser를 사용한다. `[MTF_TIER_READ]`에 UID·DEV/PROD·문서 경로·raw/parsed tier·결과·안전한 error code를 남긴다.
- Functions 검증: `npm.cmd --prefix functions run lint`, `npm.cmd --prefix functions run build` 통과. DEV projectId를 명시한 Auth/Firestore/Functions Emulator에서 인증 없음, UID payload 거부, 익명·linked 자기 profile 저장, nickname 검증, 실패 시 전체 변경 없음, 보호 필드 유지 등 14개 시나리오 통과.
- DEV 선택 배포: `npx.cmd firebase deploy --only "functions:updatePersonalTrainerProfile" --project more-than-fitness-dev-mft`만 실행했다. 함수 생성은 성공했으나 Artifact Registry cleanup policy 미설정 때문에 CLI 최종 종료 코드는 1이었다. `npx.cmd firebase functions:list --project more-than-fitness-dev-mft`로 `updatePersonalTrainerProfile`이 v1 callable, `asia-northeast3`, Node.js 22로 실제 목록에 존재함을 확인했다. `--force` 또는 cleanup policy 설정은 실행하지 않았다.
- Flutter 검증: 관련 테스트 최종 28개 통과. 전체 `flutter test --no-pub -r expanded` 257개 통과. 변경 범위 analyze는 error 0건이나 기존 대형 Home/MyPage warning/info 116건 때문에 exit 1이다. 전체 analyze는 루트 `node_modules/firebase-tools/templates/init/functions/dart/server.dart`의 저장소 밖 템플릿 분석 오류 6건과 기존 경고 때문에 실패했다. 이번 변경으로 새 컴파일 오류는 발생하지 않았다.
- 빌드: 최종 코드 기준 DEV Debug APK(`app-dev-debug.apk`)와 PROD Debug APK(`app-prod-debug.apk`) 모두 성공. `git diff --check`는 whitespace 오류 없이 통과하고 기존 LF/CRLF 안내만 출력했다.
- 실기기: `R3CX40M6EEM`에 `flutter run --flavor dev -t lib\\main_dev.dart -d R3CX40M6EEM --debug --no-pub`로 설치·실행했다. 로그에서 `environment=dev`, projectId `more-than-fitness-dev-mft`, package `com.example.mtf_app.dev`, 익명 UID, `trainer_profiles/{uid}` profile read 성공을 확인했다. 해당 UID는 이미 nickname `남트`, `onboardingCompleted=true`인 기존 DEV 사용자였다. 이후 Firestore 연결이 `UNAVAILABLE/name resolution`로 반복되어 workspace/tier/save 수동 조작 완료 로그는 확보하지 못했다. 따라서 실기기 MyPage 저장과 Home tier 표시는 미검증이며 성공으로 기록하지 않는다.
- 보호 범위: Firestore Rules, Storage Rules, 운영 project `more-than-fitness-f6adb`, 운영 데이터, migration은 변경·배포하지 않았다. 다음 백로그로 이동하지 않았다.

## 2026-07-16 — Anonymous Beginner identity + UID 유지 계정 연결 기반

- 목표: 시작 gate를 유지한 채 anonymous UID 생성·재사용, anonymous Beginner profile, 이메일 `linkWithCredential`, local→linked profile 전환 기반만 구현했다.
- 기존 구조: Auth gateway에는 이메일 가입·로그인만 있었고 anonymous/provider link가 없었다. 기존 profile bootstrap과 Rules는 anonymous를 차단했다.
- 앱 구현: `ensureAnonymousSession`은 current user를 재사용하고 user가 없을 때만 anonymous Auth를 호출하며 동시 호출은 같은 Future를 공유한다. `linkAnonymousWithEmail`은 현재 anonymous user에 credential을 연결하고 UID 동일성을 확인한 후 token refresh와 server profile 전환을 수행한다. 충돌 시 sign-out, 새 UID 로그인, 자동 병합을 하지 않는다.
- Functions: `bootstrapAnonymousBeginnerProfile`, `transitionAnonymousProfileToLinked`를 추가했다. profile은 auth UID 문서에 local/Beginner/personal/active, anonymous, limit 10, count 0으로 생성된다. linked 전환은 accountState/isAnonymous/updatedAt만 변경하고 trainerId/createdAt/tier/role/count/organization 관련 값을 유지한다.
- Rules: `trainer_profiles/{uid}`의 signed-in owner read만 anonymous까지 확장했다. client create/delete, anonymous update는 계속 차단했고 members/schedules/training_logs/contracts는 열지 않았다.
- 수정 파일: `lib/services/app_account_service.dart`, `functions/src/profile_bootstrap.ts`, `functions/src/index.ts`, `firestore.rules`, `test/anonymous_identity_foundation_test.dart`, `firebase-emulator-tests/anonymous_identity_foundation.test.cjs`, `firebase-emulator-tests/auth_profile_bootstrap.test.cjs`, `package.json`, 관련 docs/agent 문서.
- format: 변경 Dart 2개에 `dart format` 적용 완료.
- Functions: `npm.cmd --prefix functions run lint` 통과, `npm.cmd --prefix functions run build` 통과.
- Emulator: demo project `demo-mtf-anonymous-identity`의 Auth·Firestore·Functions 27개 시나리오 통과. UID 유지, provider 존재, 충돌 비병합, local→linked, 불변 필드, 타 컬렉션 미개방을 확인했다. 기존 `demo-mtf-auth-profile` 30개 시나리오도 통과했다.
- Flutter 관련 테스트: anonymous identity, 기존 account foundation, 관리자 비밀번호·claim 회귀 총 40개 통과.
- 전체 Flutter 테스트: `flutter test --no-pub -r expanded` 149개 통과.
- analyze: 변경 Dart 2개 범위 `No issues found`.
- build: `flutter build apk --debug --no-pub` 통과, `build/app/outputs/flutter-apk/app-debug.apk` 생성.
- 배포: 실제 Firebase deploy, 운영 계정·데이터 변경은 실행하지 않았다.
- 보류: 시작 gate 제거, MyPage UI, 회원 10명 정책, members/schedules/training_logs/contracts 권한, Google·카카오, legacy migration.
- 다음 백로그: 이동하지 않음.

## 2026-07-17 — 마이페이지 계정 연결·내 정보·등급 진행 UI

- 목표: personal 작업공간의 마이페이지에서 canonical 서버 profile과 Firebase Auth 상태를 사용해 계정·활동 등급, 선생님 내 정보, UID 유지 이메일 연결, linked 계정 메뉴를 제공했다.
- 기존 감사: legacy `my_page.dart`와 `AppTierAccessService`는 `trainer_profile/me`, 활성 회원, 후원, 조직 등급, 카카오 조건을 합산한다. personal source of truth로 사용할 수 없어 `MY_PAGE_ACCOUNT_LINKING_AUDIT.md`에 분리 근거를 기록하고 personal 전용 화면을 추가했다.
- 등급 카드: `trainer_profiles/{uid}`의 `tier`, `lifetimeQualifiedMemberCount`, `profileCompleted`, `accountLinked`만 읽고 Firebase Auth current user의 anonymous/email/verification 상태를 함께 표시한다. 후원값·legacy tier·카카오 수는 사용하지 않는다. Beginner/Amateur/Semi-Pro/Pro 진행 문구는 서버 값을 표시할 뿐 client가 등급·누적 수·완료 상태를 쓰지 않는다.
- 내 정보: 이름/활동명, 연락처, 활동 지역, 주 활동 종목, 소속 형태 다섯 항목만 필수로 안내한다. 상세 주소는 필수가 아니다. 저장은 기존 `updatePersonalTrainerProfile` callable만 호출하며 실패 시 화면과 입력값을 유지한다.
- 이메일 연결: 기존 anonymous user의 `linkWithCredential` 경로를 사용하고 연결 전후 UID 동일성 확인, ID token 갱신, profile local-to-linked Function, profile stream 갱신 순서를 유지했다. 이메일 인증이 안 된 연결에는 인증 메일 전송을 시도한다. 기존 이메일 충돌은 자동 병합·sign-out 없이 안내하고 입력을 보존한다. 중복 탭은 UI와 service guard로 차단한다.
- 계정별 메뉴: anonymous에는 계정 연결·내 정보·기록 보호 안내만 보여주고 로그아웃을 숨긴다. linked에는 provider/email/인증 상태, 기존 `PasswordChangePage`, 로그아웃을 제공한다. 로그아웃 전 현재 UID의 Android widget cache를 비운다. Google·카카오는 실제 provider가 없어 `준비 중`으로만 표시한다.
- 회귀 범위: `AppAccountGate`의 시작 gate, 관리자 `mustChangePassword`, 두 claim legacy workspace와 Debug legacy 경로, 계약서·전자서명 Semi-Pro gate는 수정하지 않았다. Firestore/Storage Rules와 Functions 비즈니스 로직도 수정하지 않았다.
- 수정 파일: `lib/pages/personal_my_page.dart`, `lib/pages/personal_workspace_ready_page.dart`, `lib/services/app_account_service.dart`, `lib/services/managed_member_workspace_service.dart`, `test/personal_my_page_test.dart`, `docs/agent/MY_PAGE_ACCOUNT_LINKING_AUDIT.md`, 계정·등급·완성도 정책 문서, `BACKLOG.md`, `RUN_LOG.md`.
- format: 변경 Dart 5개와 테스트에 `dart format` 실행 완료.
- 관련 테스트: personal 마이페이지 7개 통과. anonymous/linked/Amateur/Semi-Pro/Pro 카드, 서버 count/profile/provider 조건, 필수 항목, 저장 실패 입력 유지, UID 유지 연결, profile 전환·token refresh·인증 메일 시도, 충돌 시 자동 병합 금지를 확인했다. UID 기반 기존 member/schedule/training log 보존은 UID 유지 서비스 및 각 repository 전체 회귀 테스트로 확인했다.
- Emulator: demo project `demo-mtf-anonymous-members-tier`에서 Auth·Firestore·Functions Emulator 27개 시나리오 전부 통과. profile 완료 시 서버 tier 갱신, 10/11명 gate, UID별 회원 격리, legacy 미귀속과 닫힌 schedules/training_logs/contracts Rules를 확인했다. 실제 Firebase 프로젝트에는 연결하거나 배포하지 않았다.
- analyze: 변경 범위 5개 항목 `No issues found`.
- 전체 테스트: `flutter test --no-pub -r expanded`, 184개 모두 통과. 관리자 mustChangePassword·legacy workspace·계약 관련 기존 테스트를 포함한다.
- Debug APK: `flutter build apk --debug --no-pub` 성공, `build/app/outputs/flutter-apk/app-debug.apk` 생성.
- diff: `git diff --check` 통과. 기존 대규모 dirty worktree는 유지했고 범위 밖 파일을 정리하거나 되돌리지 않았다.
- 배포: Firebase deploy, 실제 계정 연결, 운영 데이터 수정은 실행하지 않았다.
- 남은 위험: 시작 gate가 유지되어 최초 anonymous session에서 actual personal 마이페이지로 들어가는 실기기 동선은 다음 단계 전까지 열리지 않는다. 실제 Firebase provider, 인증 메일 delivery, link 충돌, 로그아웃 후 Android widget 잔상은 실기기/실프로젝트 미검증이다.
- 다음 백로그: 이동하지 않음.

## 2026-07-16 — 출시 마이페이지 계정 연결 전환 사전 감사

- 목표: 앱 시작 로그인 강제를 제거하고 anonymous UID의 실제 workspace와 마이페이지 `linkWithCredential`, 자동 등급을 연결할 수 있는지 현재 코드 기준으로 확인했다.
- 결과: 프롬프트의 중단 조건이 확인되어 앱 시작 gate를 제거하지 않았고 앱 소스·Rules·Functions를 수정하지 않았다.
- 익명 차단: `AppAccountSnapshot.fromUser`는 anonymous user를 UID 없는 Guest로 축약한다. `profile_bootstrap.ts`와 `managed_members.ts`는 anonymous provider를 `anonymous_not_allowed`로 거부하며, Firestore Rules의 personal profile/member도 non-anonymous만 허용한다. personal 일정·레슨일지·계약 권한도 준비되지 않았다.
- owner 불일치: 기존 `HomePage`는 root `members`와 `schedules`를 UID 조건 없이 조회한다. 빠른 회원 저장은 `trainerId`와 `workspaceType` 없이 직접 쓴다. 이 상태에서 anonymous 사용자를 실제 홈으로 보내면 legacy 혼합 또는 권한 실패 위험이 있다.
- 계정 연결: 현재 auth gateway에는 `signInAnonymously`와 `linkWithCredential`이 없고 이메일 가입·로그인은 새 사용자 생성 또는 별도 sign-in 방식이다. UID 보존 연결 요구를 만족하지 않는다.
- 등급: 현재 클라이언트는 legacy `trainer_profile/me`의 active/kakao/contract/stored/support 값을 합산하고 후원으로 최소 Semi-Pro를 부여할 수 있다. 요청한 10/30/50 누적 유효 회원, 프로필 완료, provider 연결의 서버 transaction 권위와 다르다.
- 문서: `RELEASE_ACCOUNT_FLOW.md`, `TIER_QUALIFICATION_POLICY.md`, `MEMBER_DATA_COMPLETENESS.md`를 작성하고 `AUTH_ACCOUNT_POLICY.md`, `BACKLOG.md`를 갱신했다.
- 유지: 기존 로그인 시스템, 계약서·전자서명 Semi-Pro gate, 관리자 claim, Debug legacy 경로를 변경하지 않았다.
- 검증: 구현 변경이 없어 Functions lint/build, Emulator, Flutter test/analyze/APK build는 실행하지 않았다. 실제 Firebase 배포와 운영 데이터 수정도 실행하지 않았다. 문서 변경에는 `git diff --check`만 수행한다.
- 남은 위험: anonymous owner-scoped Rules/Functions, 전체 workspace repository 분리, credential 충돌 정책, 서버 권위 등급 원장과 Emulator 검증이 완료되기 전에는 시작 gate 제거가 안전하지 않다.
- 다음 백로그: 이동하지 않음.

## 2026-07-15 — Functions lint + Firebase predeploy 복구

- 목표: TypeScript build는 통과하지만 Functions lint 130건과 `RESOURCE_DIR` 경로 ENOENT로 Firebase predeploy가 차단되는 상태를, 비즈니스 로직·export·패키지 변경 없이 복구했다.
- 원인: `index.ts`는 기존 작은따옴표·중괄호 공백·80자 초과·`any`·non-null assertion 형식이 Google/TypeScript ESLint 규칙과 충돌했다. 새 TypeScript 모듈의 내부 함수는 Google `require-jsdoc`와 기본 80자 제한 때문에 실제 동작과 무관한 오류가 누적됐다. `firebase.json` predeploy는 Windows에서 안전하게 해석되지 않은 `$RESOURCE_DIR` 문자열에 의존해 잘못된 package 경로를 만들 수 있었다.
- 수정 파일: `functions/src/index.ts`, `functions/src/managed_members.ts`, `functions/src/profile_bootstrap.ts`, `functions/.eslintrc.js`, `firebase.json`, `docs/agent/BACKLOG.md`, `docs/agent/RUN_LOG.md`.
- lint 수정: ESLint 자동 수정으로 따옴표, object spacing, comma spacing, arrow parentheses, 들여쓰기를 정리했다. 내부 TypeScript 함수의 강제 JSDoc는 끄고 코드 폭을 100자로 조정했다. 남은 긴 줄은 수동 줄바꿈했다. `SessionData`와 `ConsentData` 타입을 추가하고 인증 UID를 transaction 밖 지역 변수로 보존해 `no-explicit-any`와 non-null assertion 경고를 제거했다. 조건, 오류 코드·문구, transaction write, 반환값은 변경하지 않았다.
- export 보존: `bootstrapTrainerProfile`, `completeInitialPasswordChange`, `createManagedMember`, `transitionManagedMemberState`, `updateManagedMember`, `chargeOnce`, `cancelNoShow`, `lockConsent`, `unlockConsent` 9개를 그대로 유지했다.
- 최종 predeploy: `npm --prefix functions run lint` → `npm --prefix functions run build`. `$RESOURCE_DIR`를 사용하지 않고 프로젝트 루트의 `functions`를 명시한다.
- lint: `npm.cmd --prefix functions run lint` 성공. 최초 130 errors/3 warnings에서 최종 0 errors/0 warnings.
- build: `npm.cmd --prefix functions run build` 성공 (`tsc`, exit code 0).
- 패키지: `functions/package.json`, `functions/package-lock.json`과 의존성 버전은 변경하지 않았다. package upgrade와 `npm audit fix`를 실행하지 않았다.
- 범위 제한: Flutter 앱, Firestore Rules, Storage Rules, 관리자 계정과 운영 데이터는 수정하지 않았다. 기존 작업 트리의 Rules 변경은 그대로 보존했으며 이번 작업에서 건드리지 않았다. Functions lint 오류 외의 기존 기능과 반환값을 변경하지 않았다.
- 배포: Firebase deploy와 실제 관리자 계정 생성은 실행하지 않았다.
- 남은 warning: 없음. 실제 Firebase CLI predeploy와 배포 후 callable runtime은 배포 금지 조건에 따라 미검증이다.
- 다음 백로그: 이동하지 않음.

## 2026-07-15 — 플랫폼 관리자 LEON + 최초/일반 비밀번호 변경

### 감사와 보안 경계

- 기존 앱은 profile 문서만 확인하고 ID token의 `platformAdmin`, `legacyDataAccessApproved` claim을 읽지 않았으며, `mustChangePassword` workspace 선행 gate와 앱 내 비밀번호 변경 화면이 없었다.
- 기존 profile bootstrap은 신규 personal workspace만 생성했고 비밀번호 변경 완료 Function은 없었다.
- 관리자 이메일은 one-time 계정 조회·생성 대상에만 사용하고 앱 권한 판정에는 사용하지 않았다. 앱 코드와 Functions에는 관리자 이메일이 없다.
- 실제 관리자 계정 생성, 실제 Firebase 프로젝트 대상 dry-run/실행, Firebase deploy, legacy owner migration은 수행하지 않았다.

### 구현

- `scripts/upsert_platform_admin.mjs`: Functions에 이미 설치된 Admin SDK, ADC, 이메일 기반 upsert, 표시 이름 LEON, 기존 claims merge, 두 관리자 claim, canonical personal Beginner profile, `mustChangePassword`, `--dry-run`, 멱등 실행을 구현했다.
- 실제 실행은 TTY 숨김 입력만 받으며 password CLI 인자와 비대화형 입력을 거부한다. 비밀번호 값과 오류 상세는 출력하거나 반환하지 않는다.
- `completeInitialPasswordChange`: 인증·non-anonymous·본인 profile·trainerId·5분 이내 `auth_time`을 확인하고 서버 시간으로 gate를 멱등 해제한다. 비밀번호나 credential을 입력으로 받지 않는다.
- 앱은 ID token result에서 두 claim을 읽고 token을 강제 갱신한다. 이메일이나 role 문자열로 관리자 여부를 판단하지 않는다.
- `mustChangePassword == true`이면 personal/legacy/admin workspace보다 비밀번호 변경 화면을 먼저 표시하고 변경·로그아웃·재설정만 허용한다.
- 비밀번호 변경은 현재 credential 재인증 → Auth updatePassword → ID token refresh → finalize Function 순서다. finalize 실패 시 완료로 처리하지 않으며 모든 민감 입력 controller를 지운다.
- `platformAdmin` 계정만 workspace 선택을 보며 legacy 버튼은 `legacyDataAccessApproved` claim이 있을 때만 보인다. 선택 상태는 Auth gate 내부에 두어 로그아웃 시 Guest 화면으로 교체된다.
- 마이페이지 더보기와 설정 계정 섹션에 비밀번호 변경 진입을 추가했다.
- 기존 Rules의 profile client update allowlist가 `mustChangePassword`, `passwordChangedAt`, `platformAdminProvisionedAt`, legacy 승인 필드를 포함하지 않음을 확인하고 Emulator로 직접 변경 거부를 검증했다. legacy collection Rules는 열지 않았다.

### 수정 파일

- Admin/Functions: `scripts/upsert_platform_admin.mjs`, `functions/src/profile_bootstrap.ts`, `functions/src/index.ts`
- Flutter: `lib/services/account_claims_service.dart`, `account_password_service.dart`, `linked_account_access_service.dart`, `lib/pages/account_gate.dart`, `password_change_page.dart`, `platform_admin_workspace_page.dart`, `my_page.dart`, `settings_page.dart`
- 테스트/로컬 도구: `firebase-emulator-tests/platform_admin_provisioning.test.mjs`, `platform_admin_password_change.test.cjs`, `test/platform_admin_password_change_test.dart`, 루트 `package.json`
- 문서: `PLATFORM_ADMIN_PROVISIONING.md`, `AUTH_ACCOUNT_POLICY.md`, `BACKLOG.md`, `RUN_LOG.md`

### 검증

- 변경 Dart 파일 format: 성공.
- Functions `npm.cmd run build`: 성공.
- Admin provisioning 순수 테스트: 통과. dry-run 무변경, 신규/기존 멱등성, 기존 claim 보존, 관리자 claims merge, canonical profile, 민감값 로그 미포함을 가짜 Auth/Firestore로 확인했다.
- Auth·Firestore·Functions Emulator: `demo-mtf-auth-profile`에서 통과. 비로그인·익명·오래된 auth_time 거부, 최근 auth_time 성공, 멱등 finalize, tier/role 불변, 관리 필드 client write 거부를 확인했다.
- 관련 Flutter 테스트: 최종 29개 통과. 확인 불일치, 현재 비밀번호 오류, update 실패, finalize 실패, 입력 clear, 선행 gate, claim별 버튼, 일반 계정 비노출, 로그아웃 잔상 제거를 포함한다.
- 새 관리자/비밀번호 변경 파일 변경 범위 analyze: 7개 항목, `No issues found`.
- `my_page.dart`/`settings_page.dart`를 포함한 첫 분석에는 작업 전부터 있던 unused/deprecated 경고 73건이 함께 보고됐고 새 파일의 중괄호 안내 2건은 수정했다. 새 컴파일 오류는 없었다.
- 전체 `flutter test --no-pub -r expanded`: 134개 통과.
- `flutter build apk --debug --no-pub`: 성공, `build/app/outputs/flutter-apk/app-debug.apk` 생성.
- `git diff --check`: 통과.
- 첫 Emulator 시도는 Java가 PATH에 없어 시작 전 중단됐다. Android Studio JBR을 해당 명령의 PATH에만 추가한 재실행은 통과했다.

### 남은 위험

- 관리자 프로비저닝 스크립트는 실제 프로젝트에서 실행하지 않았고 관리자 계정도 생성하지 않았다.
- 실제 기기에서 최초 로그인, 현재 비밀번호 오류, 비밀번호 변경 후 claim refresh/재로그인, workspace 선택, 재설정 메일 수신을 검증하지 않았다.
- Emulator는 App Check가 없는 callable 요청을 로컬에서 허용했다. 실제 배포 전 App Check, Function region, Rules diff, ADC 운영 절차를 별도 승인·검토해야 한다.
- legacy 데이터는 신규 UID에 자동 귀속하지 않았으며 migration은 별도 승인 작업이다.
- 다음 백로그로 이동하지 않았다.

## 2026-07-15 — Guest Home parity + soft gates 재감사

### 재감사 결과

- `AGENTS.md`, `docs/agent` 전체와 `prompts/13_guest_home_parity_soft_gates.md`를 다시 확인하고 현재 Guest 진입·공통 홈 위젯·로컬 저장 호출 흐름을 대조했다.
- Guest는 `HomePage` 복사본이 아니라 공통 `HomeHeaderSection`, `HomeThisWeekScheduleSection`/`HomeWeeklyScheduleTable`, `HomeBottomNavBar`를 계속 재사용한다.
- Guest 헤더만 `loadProfileFromFirestore=false`를 사용하며 Linked/legacy 호출부는 기존 기본값과 실데이터 동작을 유지한다.
- Guest 페이지와 로컬 일정 repository에서 Firestore, Storage, Functions, 실제 회원 검색, 알림 예약, 홈 위젯 동기화 참조가 없음을 다시 확인했다.
- 체험 일정은 `guest_home_schedules_v1` 로컬 저장소에 최대 5개만 보존하고, 연속 저장도 repository 직렬 처리로 제한한다.
- 회원·레슨일지·레슨 인사이트·MORE 포커스는 예시 화면, 계약·서명·알림·위젯·설정·빠른 액션은 비누적 AI FC 안내로 유지된다. 숨김 또는 disabled 기능은 추가하지 않았다.
- 프롬프트 범위의 소스 누락이나 회귀를 찾지 못해 앱 소스와 테스트 코드는 추가 수정하지 않았다. BACKLOG의 실제 기기 확인과 Guest 일정 가져오기 후속 항목도 완료 처리하지 않았다.

### 재검증

- 관련 테스트: `flutter test test/home_guest_schedule_repository_test.dart test/guest_home_experience_test.dart test/app_account_foundation_test.dart --no-pub -r expanded` → 35개 통과.
- 변경 범위 analyze: 7개 항목, `No issues found`.
- 전체 `flutter test --no-pub -r expanded` → 123개 통과.
- `flutter build apk --debug --no-pub` → 성공, `build/app/outputs/flutter-apk/app-debug.apk` 생성.
- Flutter 배치의 첫 실행은 샌드박스에서 사용자 프로필의 `.flutter_tool_state` 쓰기가 거부되어 결과 없이 대기했다. 동일 명령을 승인된 실행 환경에서 다시 수행해 위 결과를 확인했다.
- Firestore/Storage Rules, Functions 및 패키지는 수정하지 않았고 Firebase 배포도 실행하지 않았다.
- 실제 기기 수동 검증은 이번 실행에 포함되지 않았으며 다음 백로그로 이동하지 않았다.

## 2026-07-15 — Guest Home 실메인 동선 + 로컬 일정 5개 + soft gates

### 원인과 범위

- 기존 `GuestPreviewPage`는 실제 홈과 다른 소개형 카드 목록과 큰 계정 연결 버튼으로 구성되어 있었다.
- 실제 공통 `HomeHeaderSection`은 내부에서 `trainer_profile/me` Firestore stream을 직접 만들었으므로 Guest에서 그대로 사용하면 서버 접근 금지 조건을 위반했다.
- `HomePage` 자체는 init/stream/회원 검색/알림·위젯 동기화가 결합된 legacy 실데이터 화면이라 Guest mode를 억지로 삽입하지 않고, 이미 분리된 큰 공통 홈 위젯을 재사용했다.

### 구현

- 공통 재사용: `HomeHeaderSection`, `HomeThisWeekScheduleSection`, `HomeWeeklyScheduleTable`, `HomeBottomNavBar`.
- 헤더에는 기본값이 기존과 동일한 정적 profile 옵션을 추가했다. Guest는 Firestore stream 없이 `체험` 프로필과 동행 문구를 표시하고, Linked/legacy 호출부는 변경하지 않았다.
- `HomeGuestCapabilities`로 로컬 일정 5개와 cloud/member/contract/signature/notification/widget 권한을 한곳에 정의했다.
- `GuestScheduleRepository`는 SharedPreferences `guest_home_schedules_v1`에 지정 9개 필드만 저장한다. 내부 직렬 queue와 저장 직전 count 재확인으로 같은 repository의 연속 저장을 5개로 제한한다.
- Guest 일정 등록·수정·날짜/시간 이동·삭제·색상·메모 UI를 구현했다. 첫 안내는 별칭 사용을 권장하며 개인정보 필드는 제공하지 않는다.
- 6번째 저장은 sheet를 닫지 않고 입력을 유지하며 계정 연결/둘러보기 안내를 표시한다. 로그인 취소 뒤에도 입력과 5개 일정이 유지된다.
- 회원·레슨일지·레슨 인사이트·MORE 포커스는 안전한 예시 sheet, 계약서·서명·알림·홈 위젯·설정·빠른 등록·레슨 확정은 비누적 `AifcToast`로 처리한다. 모든 항목은 탭 가능하다.
- Guest 관련 경로는 Firestore/Storage/Functions/회원 검색/알림 예약/위젯 sync service를 import하거나 호출하지 않는다. 서버 초기화 없는 widget test 렌더링도 통과했다.
- Guest→Linked 자동 업로드·귀속·삭제, 실제 계약/서명, 플랫폼 관리자 구현은 하지 않았다.

### 수정 파일

- `lib/pages/guest_preview_page.dart`
- `lib/widgets/home/sections/home_header_section.dart`
- `lib/services/home_guest_capabilities.dart`
- `lib/services/home_guest_schedule_repository.dart`
- `test/home_guest_schedule_repository_test.dart`
- `test/guest_home_experience_test.dart`
- `test/app_account_foundation_test.dart`
- `docs/agent/GUEST_HOME_EXPERIENCE.md`, `AUTH_ACCOUNT_POLICY.md`, `BACKLOG.md`, `RUN_LOG.md`

### 검증

- 변경 Dart 파일 format: 성공. 최종 테스트 format은 변경 없음.
- 변경 범위 `flutter analyze --no-pub`: 7개 항목, `No issues found`.
- 관련 Flutter 테스트: 35개 통과. 로컬 repository 11개, Guest 홈 6개, 계정 기반 회귀 18개.
- 전체 `flutter test --no-pub -r expanded`: 123개 통과.
- `flutter build apk --debug --no-pub`: 성공, `build/app/outputs/flutter-apk/app-debug.apk` 생성.
- Functions/Rules/Storage Rules를 변경하지 않아 Emulator와 Functions build는 실행하지 않았다.
- `git diff --check`: 통과.

### 테스트 중 확인한 최초 원인

- 공통 헤더의 AI FC avatar는 의도적으로 계속 애니메이션하므로 widget test의 `pumpAndSettle`이 종료되지 않았다. 기능 오류가 아니며 고정 시간 pump로 레이아웃을 검증했다.
- 6번째 일정 test에서 키보드가 열린 채 하단 저장 버튼이 viewport 밖에 있어 첫 탭이 도달하지 않았다. 키보드를 닫고 실제 sheet를 스크롤한 뒤 저장하도록 수동 동선과 동일하게 조정했다.

### 남은 위험·수동 확인

- 실제 기기에서 빈 칸 일정 생성, 날짜/시간 picker, 일정 block 수정·삭제·이동, 앱 강제 종료 복원은 미검증이다.
- Guest→Linked→로그아웃 전환 시 로컬 일정은 정책대로 남지만 자동 혼입되지 않는지 실제 기기에서 확인이 필요하다.
- 실제 이름 대신 별칭 사용은 안내 정책이며 로컬 입력을 기술적으로 익명화하지 않는다. 개인정보를 넣지 않도록 UX 안내를 유지해야 한다.
- 다음 단계 후보는 명시적 동의를 받는 Guest 일정 가져오기 정책이지만 이번 작업에서 이동하지 않았다.

## 2026-07-15 — Linked Beginner 회원 소유권 격리 + 10명 한도

### 감사와 실제 원인

- 기존 `client_list_page.dart`, `client_card_page.dart`, 홈 빠른 등록, 계약 후 자동 등록, 회원권 정지·재개, 레슨일지 연동은 `members` 전체 조회 또는 client 직접 set/update에 결합되어 있었다.
- 기존 문서에는 canonical trainerId가 보장되지 않고 `memberStatus`, `membershipStatus`, `membership.status`, `isDeleted`가 분산되어 있어 신규 계정 한도를 기존 목록 개수로 안전하게 강제할 수 없었다.
- legacy 화면을 신규 personal workspace에 재사용하면 전체 회원 노출과 Function 우회가 남으므로 신규 화면·gateway를 분리했다. 상세 경로는 `MEMBER_WORKSPACE_AUDIT.md`에 기록했다.

### 구현

- canonical 경로: `members/{memberId}`. Function이 path ID와 `memberId`, 현재 Auth UID `trainerId`, `workspaceType=personal`, schemaVersion, 관리 상태와 서버 시간을 고정한다.
- count source of truth: `trainer_profiles/{uid}.managedMemberCount`; Beginner limit은 10. task 11 이후 count 필드가 없는 schemaVersion 1 personal profile은 당시 canonical 회원 생성 경로가 없었다는 근거로 두 필드가 모두 없을 때만 0/10 초기화한다.
- 포함: active, paused. 제외: dormant, expired, deleted, Guest 예시와 local draft.
- `createManagedMember`: non-anonymous·profile·workspace 검증, 입력 allowlist/길이 제한, UID 기반 안정적 idempotency member ID, member create와 count 증가를 한 transaction으로 처리.
- `transitionManagedMemberState`: owner와 현재 상태를 transaction에서 확인하고 포함 여부가 바뀔 때만 count 변경. false→true는 10명 재검사. 같은 상태 재요청은 no-op. 상태 이력에 previousState/nextState/changedAt/changedBy/source 기록.
- `updateManagedMember`: name/phone/note만 허용하며 identity/server 필드는 변경하지 않음.
- Rules: 신규 personal member는 non-anonymous owner read만 허용하고 client create/update/delete는 거부. owner+workspace filter 없는 list, 다른 trainer와 trainerId 없는 legacy read를 거부. 기존 role claim staff의 personal이 아닌 legacy read/create/update는 유지했다.
- 신규 화면: `0 / 10명`, `첫 회원 등록`, owner-scoped 목록. 실패/한도 초과 시 dialog와 입력을 유지하고 저장 중 중복 탭을 차단한다. 같은 dialog 재시도는 동일 idempotency key를 사용한다.
- 기존 회원권 정지·재개 legacy 필드와 canonical state의 transaction 연결은 범위가 커서 하지 않았다. 신규 personal 화면의 paused 상태만 canonical count에 포함한다.
- Guest draft handoff는 기존 회원카드 전체 payload와 민감정보 보관 분리가 필요해 구현하지 않았다. SharedPreferences 저장도 추가하지 않았다.

### 수정 파일

- Functions: `functions/src/managed_members.ts`, `functions/src/profile_bootstrap.ts`, `functions/src/index.ts`
- Rules/Emulator: `firestore.rules`, `firebase-emulator-tests/managed_members_limit.test.cjs`, 루트 `package.json`
- Flutter: `lib/services/managed_member_workspace_service.dart`, `lib/pages/personal_workspace_ready_page.dart`, `lib/pages/account_gate.dart`
- 테스트: `test/managed_member_workspace_test.dart`, `test/app_account_foundation_test.dart`
- 문서: `MEMBER_WORKSPACE_AUDIT.md`, `AUTH_ACCOUNT_POLICY.md`, `TENANT_IDENTITY_MODEL.md`, `DATA_SOURCE_OF_TRUTH_AUDIT.md`, `SECURITY_RULES_MATRIX.md`, `BACKLOG.md`, `RUN_LOG.md`

### 검증 결과

- 변경 Dart 파일 format: 성공. 최종 추가 테스트 format은 `Formatted 1 file (0 changed)`.
- Functions `npm.cmd run build`: 성공 (`tsc`, Node 22.20.0).
- Emulator 도구: root `firebase-tools 15.23.0`, `@firebase/rules-unit-testing 5.0.1`, Firestore Emulator 1.21.0. functions package 의존성은 변경하지 않았다.
- `demo-mtf-auth-profile` Auth·Firestore·Functions Emulator: 기존 profile bootstrap 30개 시나리오 통과.
- `demo-mtf-linked-beginner` Auth·Firestore·Functions Emulator: 최종 57개 회원/Rules 시나리오 통과. 10번째 성공, 11번째 거부, 재활성화 한도, 0 미만 방지, 정지 포함, 휴면·만료·삭제 제외, 멱등성, 상태 이력, 타 trainer/legacy 격리, owner-filter query, client 쓰기 우회를 포함한다.
- 최초 profile+member 결합 실행은 두 테스트 파일의 서로 다른 고정 demo project ID 때문에 profile URL이 404여서 실패했다. 같은 테스트를 각 고정 demo ID로 분리 재실행해 각각 통과했다.
- 관련 Flutter 테스트: 25개 통과.
- 변경 범위 `flutter analyze --no-pub`: 5개 항목, `No issues found`.
- 전체 `flutter test --no-pub -r expanded`: 106개 통과.
- `flutter build apk --debug --no-pub`: 성공, `build/app/outputs/flutter-apk/app-debug.apk` 생성.
- `git diff --check`: 통과.

### 제외·남은 위험

- 실제 Firebase 프로젝트 배포, 운영 데이터 migration, `firebase login`, 운영 계정/데이터 사용은 하지 않았다.
- `training_logs`, schedules, contracts, anatomy Rules와 Storage Rules는 변경하지 않았다.
- Emulator는 App Check가 없는 callable 요청을 경고 없이 허용하는 로컬 환경이며, Functions는 기존 firebase-functions 버전 업그레이드 권고를 출력했다. 이번 작업에서는 패키지를 올리지 않았다.
- 실기기에서 첫 등록·재로그인·네트워크 실패 복구는 미검증이다. 배포 전 Rules diff, Functions region/App Check 정책, staff legacy claim, 실기기 owner query를 확인해야 한다.
- 다음 단계 후보는 schedules/training_logs owner 기반 신규 쓰기 또는 Guest 메모리 draft handoff지만 이번 작업에서 이동하지 않았다.

## 2026-07-15 — UID profile bootstrap + trainer_profiles 최소 Rules

### 실제 원인과 범위

- 10단계 gate는 `legacyDataAccessApproved`를 모든 연결 계정의 진입 조건으로 사용해 신규 계정도 관리자 승인 대기로 분류했다.
- profile 생성 Function과 `trainer_profiles` Rules가 없어 신규 UID가 자기 빈 workspace를 시작할 수 없었다.
- 이번 변경은 `trainer_profiles/{uid}`와 해당 bootstrap 흐름만 대상으로 했다. members, schedules, training_logs, contracts, sign_requests 및 Storage Rules는 열지 않았다.

### 구현

- `bootstrapTrainerProfile` v1 callable을 추가했다. non-anonymous Auth UID만 허용하고 transaction으로 멱등 생성한다.
- 문서 ID와 trainerId는 Auth UID이며 `Beginner/linked/personal/active`, role `personal`, schemaVersion 1, 서버 createdAt/updatedAt으로 고정했다.
- client가 전달한 tier, role, organizationId 등의 값은 사용하지 않는다.
- 기존 profile은 덮어쓰지 않고 trainerId가 UID와 다르면 `profile_conflict`로 차단한다.
- 익명 계정은 Function의 `anonymous_not_allowed`와 Rules 양쪽에서 차단한다.
- Flutter access gateway는 profile 부재 시 callable을 실행하고 다시 읽는다. 신규 personal profile은 legacy 앱이 아닌 정적 빈 작업공간 화면으로 진입한다.
- `legacyDataAccessApproved`가 있는 profile만 기존 SplashRouter로 진입한다. `trainer_profile/me`와 legacy 데이터는 복사·귀속하지 않았다.
- Rules는 non-anonymous 본인의 profile read와 표시 필드 update만 허용하고 client create/delete 및 관리 필드 변경을 거부한다.

### Emulator와 도구

- 승인된 루트 devDependencies만 추가: `firebase-tools 15.23.0`, `@firebase/rules-unit-testing 5.0.1`.
- Node `22.20.0`; Firebase Tools engine `>=20 || >=22 || >=24`와 호환.
- Android Studio JBR을 사용했고 Firestore Emulator `1.21.0`을 demo project `demo-mtf-auth-profile`로 실행했다.
- 실행 명령: `npx firebase emulators:exec --project demo-mtf-auth-profile --only auth,firestore,functions "npm.cmd run test:profile-rules"`.
- Function·Rules 30개 시나리오 모두 통과. 운영 프로젝트·계정, firebase login, projects:list, deploy는 사용하지 않았다.
- Functions Emulator는 기존 `firebase-functions 6.0.1`이 최신이 아니라는 경고를 표시했다. 승인 범위에 따라 `functions/package.json`과 lockfile은 변경하지 않았다.
- npm audit는 중간 수준 취약점 5건을 보고했다. `npm audit fix`는 실행하지 않았다.

### 변경 파일

- `functions/src/profile_bootstrap.ts`, `functions/src/index.ts`
- `firestore.rules`, `firebase.json`
- `firebase-emulator-tests/auth_profile_bootstrap.test.cjs`
- 루트 `package.json`, `package-lock.json`
- `lib/services/linked_account_access_service.dart`
- `lib/pages/account_gate.dart`, `linked_account_pending_page.dart`, `personal_workspace_ready_page.dart`
- `test/app_account_foundation_test.dart`
- `docs/agent/AUTH_PROFILE_BOOTSTRAP_AUDIT.md` 및 계정·identity·Rules·BACKLOG 문서

### 검증 상태

- Functions TypeScript build: 통과.
- Auth·Firestore·Functions Emulator: 30개 통과.
- 관련 Flutter 계정 테스트: 18개 통과.
- 변경 범위 analyze: `No issues found`.
- 전체 Flutter 테스트: 99개 모두 통과.
- debug APK: 성공, `build/app/outputs/flutter-apk/app-debug.apk` 생성.
- `git diff --check`: exit code 0. 기존 작업 파일의 LF→CRLF 안내만 있고 whitespace 오류는 없다.
- `functions/package.json`, `functions/package-lock.json`: diff 없음.

### 남은 위험과 후속

- 실제 Firebase 프로젝트에는 배포하지 않았다. 실제 callable region/provider/App Check/Rules 배포는 미검증이다.
- 신규 personal workspace는 기존 broad members read에 진입하지 않도록 정적 빈 화면으로 격리했다. 실제 회원 저장과 owner-scoped data Rules는 후속 작업이다.
- Linked Beginner 10명 제한, legacy migration, 계약·원격서명, 조직 역할은 변경하지 않았다.
- 다음 백로그로 이동하지 않았다.


## 2026-07-15 — Guest 진입 + Firebase Auth 계정 기반 1단계

### 기존 진입과 원인

- 모바일은 Firebase 초기화 후 인증 gate 없이 `SplashRouter`를 열었고, 고정 문서 `trainer_profile/me` 존재만으로 홈 진입을 결정했다.
- 로그인·로그아웃·Auth 상태 구독 구현이 없어서 Guest 안전 경계와 신규 계정 소유권 경계를 만들 수 없었다.
- 기존 의존성에 `firebase_auth`는 있었지만 `google_sign_in`은 없었다.

### 구현

- 계정 상태 `guest/linked/verified/organizationMember`와 앱 등급을 독립 모델로 추가했다.
- 첫 실행은 Guest 시작 화면이며 로그인 강제 없이 정적 예시 일정·회원·레슨일지를 볼 수 있다. Guest 화면에는 Firestore, Storage, Functions 및 실제 운영 repository 호출이 없다.
- 이메일 가입, 로그인, 비밀번호 재설정, 이메일 확인 발송 시도, 로그아웃, 연속 요청 차단, 사용자용 오류 안내를 추가했다.
- 익명 Firebase user는 Guest로 분류하며 최종 계정으로 사용하지 않는다.
- 연결 계정은 `trainer_profiles/{uid}`를 읽기 전용으로 확인한다. `trainerId == uid`와 `legacyDataAccessApproved == true`가 모두 명시된 경우만 기존 앱 흐름으로 진입한다.
- 신규 계정에는 profile을 생성하지 않고 `trainer_profile/me` 또는 기존 회원·일정·레슨일지·계약 데이터를 자동 복사·귀속하지 않는다. 승인되지 않은 계정은 연결 대기 화면에 머문다.
- 설정 화면에 로그아웃을 추가했으며 로그아웃 후 실제 운영 화면을 스택에서 제거하고 Guest 진입으로 돌아간다.
- Google provider 활성화와 SHA 등록을 저장소에서 검증할 수 없고 새 패키지 승인을 받지 않았으므로 설정 준비 중 안내만 표시한다.

### 변경 파일

- `lib/services/app_account_service.dart`
- `lib/services/linked_account_access_service.dart`
- `lib/pages/account_gate.dart`
- `lib/pages/guest_start_page.dart`
- `lib/pages/guest_preview_page.dart`
- `lib/pages/email_auth_page.dart`
- `lib/pages/linked_account_pending_page.dart`
- `lib/main.dart`
- `lib/pages/settings_page.dart`
- `test/app_account_foundation_test.dart`
- `docs/agent/AUTH_ENTRY_AUDIT.md`
- `docs/agent/AUTH_ACCOUNT_POLICY.md`
- `docs/agent/TENANT_IDENTITY_MODEL.md`
- `docs/agent/BACKLOG.md`
- `docs/agent/RUN_LOG.md`

### 현재 검증 결과

- 변경 Dart 파일 format: 성공.
- 관련 테스트: 필수 17개 시나리오 모두 통과. Guest 서버 gateway 호출 0회, 계정 연결 시 이메일 인증 화면 진입, 이메일 검증, 중복 요청 차단, 승인 없는 신규 계정 격리, 로그아웃을 포함한다.
- 변경 범위 analyze 1차: 기존 `main.dart`와 `settings_page.dart` 경고·정보 14건 때문에 exit code 1. 신규 Guest 화면의 const 안내 1건은 수정했으며 기존 범위 경고는 범위 밖이라 변경하지 않았다.
- 신규 계정 파일 최종 analyze: `No issues found`.
- 전체 테스트: 98개 모두 통과.
- debug APK build: 성공, `build/app/outputs/flutter-apk/app-debug.apk` 생성.
- `git diff --check`: exit code 0. 기존 작업 파일의 LF→CRLF 안내만 있고 whitespace 오류는 없다.

### 남은 설정과 위험

- 저장소 Rules에는 `trainer_profiles/{uid}` 허용 규칙이 없어 실제 배포 Rules도 같다면 연결 계정은 `permission-denied`로 안전하게 차단된다. 이번 작업에서는 Rules를 수정하거나 배포하지 않았다.
- 이메일/비밀번호 provider, 확인 메일 발송, 배포 Rules, 실제 네트워크 로그인은 실제 Firebase 프로젝트 또는 Auth Emulator로 검증하지 않았다.
- `google-services.json` 존재와 applicationId `com.example.mtf_app`만 확인했다. Console Google provider 및 SHA-1/SHA-256 등록은 미검증이다.
- 다음 단계는 UID profile 생성·접근 Rules와 명시적인 legacy owner 승인, 실제 Auth 검증, 이후 Linked Beginner 10명 한도다. 이번 작업에서는 다음 백로그로 이동하지 않았다.


Codex는 각 작업 후 아래 형식으로 맨 위에 기록한다.

## 2026-07-15 — Tenant identity + Training Log 정상화 중단

### 작업 범위

- `prompts/09_tenant_identity_training_log_normalization.md`에 따라 Firebase Auth, 앱 시작, trainer profile, 로그아웃·계정전환, 조직 metadata와 기존 training log/member 쓰기 전제를 감사했다.
- Firebase Auth UID 보장 중단 조건이 확인되어 공통 identity service, training log repository, member 신규 identity 쓰기, owner query 변경을 구현하지 않았다.
- `firestore.rules`, `storage.rules`, 앱 소스, Functions, 패키지, Firebase 설정을 수정하지 않았고 실제 프로젝트 배포·운영 데이터 migration을 수행하지 않았다.

### canonical trainer identity 판단

- 목표 원칙은 개인 강사 Beginner~Pro에서 `trainerId = FirebaseAuth.currentUser.uid` 하나를 사용하는 것이다.
- 그러나 `main.dart`는 Firebase 초기화 뒤 Auth 상태를 기다리지 않고, 모바일 `SplashRouter`는 `trainer_profile/me`의 onboarding 값만 보고 Home으로 진입한다.
- onboarding은 currentUser 확인 없이 같은 `trainer_profile/me`를 merge 저장한다.
- 저장소 앱 코드에서 sign-in, anonymous sign-in, authStateChanges gate, sign-out, account switch 구현을 찾지 못했다.
- `AuthRoleUtil`과 anatomy만 nullable currentUser를 읽을 뿐 모든 트레이너 쓰기의 전제가 아니다.
- `MoreCareSlotService`는 profile의 trainerId/uid/userId/ownerId를 fallback하고 없으면 문자열 `me`를 trainerId로 사용한다. 이는 Firebase UID의 권위 근거가 아니다.
- 따라서 현재 Auth UID가 canonical trainerId로 항상 보장된다고 판단할 수 없어 UID 자동 주입을 중단했다.

### 개인/센터 tenant 관계

- tier 코드는 `organizationTier`, `organizationId`, `branchCount`를 읽지만 organization membership, branch membership, active tenant 선택과 owner delegation 모델이 없다.
- Master·Grand Prix에서 trainer UID와 organizationId/branchId 중 무엇이 데이터 owner인지, 센터 manager/staff가 다른 trainer 데이터에 접근하는 규칙이 불명확하다.
- organizationId를 tenantId로 자동 승격하거나 개인 current UID만 센터 데이터 owner로 넣지 않았다.

### 통합하지 않은 쓰기 경로

- 빠른서명, 홈확정, 확정취소, 노쇼/서비스, 회차 차감, 일반 레슨일지 partial merge는 기존 상태를 유지했다.
- 신규 `training_logs`와 `members`에 trainerId/schemaVersion을 추가하지 않았다. UID가 보장되지 않은 상태에서 일부 경로만 바꾸면 문서 owner가 혼재하기 때문이다.
- legacy 문서에 trainerId/memberId/lessonLogId를 backfill하지 않았고 이름·닉네임·`me`로 owner를 추정하지 않았다.
- 공개 원격서명 direct Firestore 경로는 trainer repository의 예외로 편입하지 않고 `public_signature_legacy` 전환 대상으로 문서화했다. UI와 계약 상태 머신은 수정하지 않았다.

### 작성·갱신 문서

- `TENANT_IDENTITY_MODEL.md`: 목표 canonical UID, 현재 미보장 근거, 개인/조직 차이, 공개 사용자 예외, legacy 정책.
- `TENANT_IDENTITY_MIGRATION_PLAN.md`: legacy 기준, 허용 가능한 증거, dry-run/backup/idempotency/rollback, query·Rules 전환 순서.
- `REMOTE_SIGNATURE_MIGRATION_PLAN.md`: 현재 direct read/write 호출 흐름과 Function/API 전환 데이터·테스트.
- `TRAINING_LOG_RULES_AUDIT.md`: 09 Auth 중단 결론 추가.
- `DATA_SOURCE_OF_TRUTH_AUDIT.md`: 현재 canonical owner 미확정 상태 반영.
- `BACKLOG.md`: Auth gate, UID profile 결속, 조직 membership, migration 검토 항목 추가.
- `RUN_LOG.md`: 본 결과 기록.

### 검증과 남은 위험

- 소스 코드를 변경하지 않아 Dart format, Flutter analyze/test, APK build, Functions build는 실행하지 않았다.
- 문서 변경 후 `git diff --check`만 실행한다.
- Auth gate가 없는 현재 상태에서 신규 owner 필드를 강제하면 정상 앱 쓰기가 `unauthenticated`로 실패하거나 우연히 남아 있는 세션 UID에 데이터가 잘못 귀속될 수 있다.
- 다음 P0는 인증·계정 생명주기와 조직 membership 모델 확정이다. 그 이후 canonical 신규 쓰기 → fixture 기반 migration planner → 공개서명 Function → owner query → Rules Emulator 순으로 진행해야 한다.
- 다음 백로그로 이동하지 않았다.

## 2026-07-15 — Training Logs + Anatomy Rules 사전 감사 중단

### 작업 범위

- `prompts/08_anatomy_training_logs_rules_emulator.md`에 따라 루트 `training_logs`와 하위 `anatomyRecords`의 실제 read/write 경로, owner 필드, 쿼리, Rules/Emulator 환경을 감사했다.
- 안전 중단 조건이 확인되어 `firestore.rules`, `storage.rules`, 앱 소스, Functions, 패키지, Firebase 설정을 수정하지 않았다. 실제 Firebase 프로젝트에 배포하지 않았다.

### 확인된 차단 원인

- 빠른서명 `_saveQuickSignedLog`, 홈 `LessonConfirmationService.confirmFromHome`, 공개 웹서명 `_submitSignature`가 모두 루트 parent를 `set(merge: true)`로 만들 수 있지만 공통 `trainerId`와 필드 `lessonLogId`를 저장하지 않는다.
- `_applyRemainingSessionDeductionIfNeeded`, 두 확정취소 경로는 log가 없을 때 `createdAt`과 전체 identity가 없는 부분 parent를 만들 수 있다.
- 정상 생성·수정 필드가 서명, 차감, 노쇼/서비스, 확정취소별로 달라 안전한 parent update allowlist를 확정할 수 없다.
- `training_logs` 빠른서명 목록과 anatomy 부모 목록은 memberId만 사용하고 trainerId owner 필터가 없다.
- 공개 회원 서명 이력은 비로그인 페이지가 memberId로 collection query하고, token request를 근거로 parent를 직접 create/update한다. token 문자열 기반 direct Firestore 허용은 금지 조건과 충돌한다.
- `members` 문서에는 Auth UID 기반 `trainerId/ownerId`가 일관되지 않아 parent create가 참조하는 member의 소유권을 Rules `get()`으로 검증할 근거가 없다.
- 기존 parent의 trainerId 누락 범위와 실제 배포 Rules는 확인하지 못했다. legacy 문서를 모든 staff에게 열거나 client가 owner를 선점하는 backfill은 안전하지 않다.

### Rules·Emulator 판단

- 현재 저장소 Rules는 `training_logs`를 계속 default deny한다. 인증 사용자 전체 허용, role 전체 허용, legacy fallback, child만 보고 owner를 판단하는 임시 규칙을 추가하지 않았다.
- `firebase.json`에 Firestore rules/emulator 설정이 없고 현재 PATH에서 Firebase CLI를 찾지 못했다. 루트와 Functions 기존 의존성에도 `@firebase/rules-unit-testing`이 없다.
- 테스트 환경을 추가하기 전에 데이터 구조 중단 조건이 충족됐으므로 새 dev dependency를 추가하지 않았다.
- Firestore Emulator 테스트는 작성·실행하지 않았다. 따라서 Rules 완료, 허용/거부 40개 통과, 실제 저장 가능으로 판단하지 않는다.

### 문서 변경

- `docs/agent/TRAINING_LOG_RULES_AUDIT.md`: 모든 root training_logs 호출자의 get/list/create/update, identity 출처와 필요한 선행 작업 표 작성.
- `docs/agent/SECURITY_RULES_MATRIX.md`: 최신 anatomy service 검증과 parent owner 차단 상태 반영.
- `docs/agent/ANATOMY_DATA_MODEL.md`: 08 감사 중단 결과와 Rules 선행조건 추가.
- `docs/agent/BACKLOG.md`: anatomy 항목을 parent owner schema/migration 및 Emulator 대기로 명확화하고 미완료 유지.
- `docs/agent/RUN_LOG.md`: 본 결과 기록.

### 필요한 최소 후속 작업

1. 공통 training log schema/repository를 정의하고 인증 trainer 생성 경로에 `trainerId/memberId/lessonLogId`와 서버 createdAt/updatedAt을 강제한다.
2. merge update가 없는 parent를 만들지 못하도록 create/update를 분리한다.
3. 신뢰 가능한 자료로 legacy owner identity를 migration하고 누락 문서는 deny한다.
4. members owner 구조를 확정하고 공개 원격서명을 검증 Function/API로 이전한다.
5. 앱 parent query에 trainerId filter를 추가한다.
6. 그 후 Rules unit test 환경과 40개 Emulator 행렬을 구성해 전부 통과한 경우에만 Rules 완료로 판단한다.

### 검증

- 소스와 Rules를 변경하지 않았으므로 Flutter analyze/test/APK build는 실행하지 않았다.
- `git diff --check`로 문서 whitespace만 확인한다.
- 실제 배포·운영 데이터·실제 배포 Rules는 확인하거나 변경하지 않았다.
- 다음 백로그로 이동하지 않았다.

## 2026-07-15 — anatomy 실데이터 연결 데이터 무결성 보완

### 원인과 범위

- 실제 부모 생성 경로는 `AnatomyLogService.save`의 batch `parentRef.set(..., merge: true)`였다. 부모가 없으면 `inputMethod=anatomy`인 최소 `training_logs/{lessonLogId}`를 만들었고, 기존 부모 trainerId가 비면 현재 화면 값을 backfill했다.
- 서비스는 parent/context/child의 trainerId, memberId, scheduleDocId와 path lessonLogId를 비교하지 않았고 UI는 저장 직전 identity를 현재 widget 값으로 덮어썼다. update는 전체 record를 merge해 불변 identity와 createdAt도 변경할 수 있었다.
- 이번 작업은 anatomy 서비스, anatomy 화면의 오류 처리와 schedule 선택값 전환, 관련 단위 테스트, 데이터 모델·source of truth 문서만 보완했다. `firestore.rules`, `storage.rules`, 계약·서명 코드, 패키지, Firebase 배포는 변경하지 않았다.

### 구현

- 사용한 공통 training log 생성 경로: 저장소에서 신규·수동 레슨일지를 정식 부모로 만드는 명확한 공통 service/repository를 찾지 못했다. 새 구조를 추측해 만들지 않았고 anatomy 서비스는 부모를 절대 생성하지 않는다. 부모 없는 수동 초안은 `parent_not_found`로 차단하며 화면에서 먼저 일반 레슨일지를 저장하라고 안내한다.
- 부모 검증: 생성·수정·삭제 transaction에서 `training_logs/{lessonLogId}`를 먼저 읽고 존재, 현재 Auth UID와 trainerId, parent/context의 trainerId/memberId, 양쪽에 값이 있는 scheduleDocId를 검사한다. 부모 identity가 비어 있으면 backfill하지 않고 `legacy_parent_missing_identity`로 차단한다.
- `scheduleDocId`는 선택값으로 전환했다. 수동·빠른서명·원격서명·과거 레슨일지는 schedule 부재만으로 차단하지 않으며, parent/child/context에 비교할 값이 함께 있을 때 불일치를 차단한다.
- 생성 시 한 번 정한 anatomyLogId를 문서 ID와 필드에 같이 사용하고 createdAt/updatedAt을 서버 시간으로 쓴다. 부모에는 `update`로 anatomy 요약만 반영하므로 parent가 암묵 생성되지 않는다.
- 수정 시 기존 자식을 같은 transaction에서 읽고 `anatomyLogId`, `lessonLogId`, `memberId`, `trainerId`, `createdAt` 변경을 `immutable_identity_change`로 차단한다. 기존 scheduleDocId도 변경하지 않으며 record 내용과 서버 updatedAt만 갱신한다.
- 삭제 시 부모와 해당 자식의 identity를 검증하고 선택 문서만 삭제한다. 존재하지 않는 문서는 `record_not_found`이며 상위 로그와 같은 레슨의 다른 anatomy 기록은 유지한다.
- 조회 시 auth/parent를 먼저 검증하고 child의 path/member/trainer/schedule 무결성 오류를 개인정보나 ID 없이 `[MTF_ANATOMY_INTEGRITY]` 코드 로그로 남긴 뒤 결과에서 제외한다. 정렬은 recordedAt 내림차순 → createdAt 내림차순 → anatomyLogId 오름차순을 유지한다.
- UI는 실패 시 닫히지 않고 성공 토스트를 표시하지 않는다. 인증, 부모 부재, legacy 보강 필요, identity 불일치, record 부재, 권한 실패를 내부 ID 없이 안내한다.

### 변경 파일

- `lib/services/anatomy_log_service.dart`
- `lib/pages/personal_training_log_anatomy/anatomy_page.dart`
- `lib/pages/personal_training_log_page.dart`
- `test/anatomy_log_test.dart`
- `docs/agent/ANATOMY_DATA_MODEL.md`
- `docs/agent/DATA_SOURCE_OF_TRUTH_AUDIT.md`
- `docs/agent/BACKLOG.md`
- `docs/agent/RUN_LOG.md`

### 검증

- format: 변경 Dart 4개 파일 formatter 적용 성공. 처음에는 사용자 프로필 분석 설정 접근 제한으로 대기/실패했고, 작업공간 APPDATA와 승인된 기존 패키지 캐시 접근으로 재실행했다.
- anatomy 테스트: `flutter test test/anatomy_log_test.dart --no-pub -r expanded` 성공. 기존 모델 10개와 부모 미생성, 인증 없음/UID 불일치, parent/member/path/schedule 검증, 동일 ID 수정, 불변 identity 4종, 선택 삭제, 없는 record 삭제 실패, legacy 부모 차단, 정렬을 포함한 총 26개가 통과했다.
- 전체 테스트: `flutter test --no-pub -r expanded` 성공. 총 81개 테스트 통과.
- 변경 범위 analyze: `lib/services/anatomy_log_service.dart`, anatomy 폴더, anatomy 테스트는 `No issues found`. 진입점 변경 파일인 전체 `personal_training_log_page.dart`까지 포함하면 기존 warning/info 109건으로 exit code 1이며 이번 anatomy 변경 위치의 신규 진단은 없었다. 범위 밖 경고는 수정하지 않았다.
- APK: `flutter build apk --debug --no-pub` 성공. `build/app/outputs/flutter-apk/app-debug.apk` 생성.
- `git diff --check` exit code 0. 기존 파일의 LF→CRLF 안내만 있고 whitespace 오류는 없다.
- Firestore emulator와 실제 프로젝트/기기 저장은 실행하지 않았다. 따라서 실제 Firestore 저장 검증 완료로 기록하지 않는다.

### 남은 위험과 다음 Rules 작업

- 현재 저장소 `firestore.rules`에는 `/training_logs`와 `/anatomyRecords` match가 없어 실제 CRUD는 기본 거부된다. 이번에는 Rules를 수정하거나 배포하지 않았다.
- 후속 Rules는 인증 staff, 부모 존재, parent owner==Auth UID, parent/child trainerId·memberId·path ID 일치, 선택 schedule 일치, update identity/createdAt 불변, 허용 content 필드만 변경, parent metadata 제한, 고아 child 접근 차단을 강제해야 한다.
- owner/member가 없는 legacy 부모는 승인된 migration 없이는 anatomy 저장이 계속 차단된다. 부모 없는 신규·수동 흐름은 공통 training log 생성 경로가 정의되기 전까지 먼저 일반 레슨일지를 저장해야 한다.
- 다음 백로그로 이동하지 않았고 Rules·실기기 검증 대기 상태이므로 P4 항목은 완료 처리하지 않았다.

## 2026-07-15 — 계약서·전자서명 감사 anatomy 실데이터 보강

### 작업 범위

- `prompts/07_contract_signature_readonly_audit.md`의 읽기 전용 감사만 수행하고 anatomy 실데이터 연결을 추가 감사했다.
- 앱 소스, Firestore Rules, Storage Rules, Functions, 패키지, 설정, 테스트, BACKLOG는 수정하지 않았다.
- 지정된 `CONTRACT_SIGNATURE_AUDIT.md`, `SECURITY_RULES_MATRIX.md`, `DATA_SOURCE_OF_TRUTH_AUDIT.md`, `CONTRACT_SIGNATURE_TEST_MATRIX.md`, `RUN_LOG.md`만 갱신했다.

### Anatomy 확인 결과

- 실제 저장 경로는 `training_logs/{lessonLogId}/anatomyRecords/{anatomyLogId}`다.
- `AnatomyLogService.save`는 부모를 읽지만 존재를 요구하지 않고, 없으면 최소 `training_logs` 부모를 batch에서 생성한다.
- 기존 부모가 있어도 parent와 context/child의 `trainerId`, `memberId`, `scheduleDocId` 일치를 검사하지 않는다. parent trainerId가 비면 현재 client UID로 채운다.
- child record의 `lessonLogId`가 path lessonLogId와 같은지, anatomyLogId가 path 문서 ID와 같은지, update에서 identity가 유지되는지 service가 검증하지 않는다. UI는 저장 직전 current 화면 ID로 덮어쓴다.
- `scheduleDocId`는 모든 정상 레슨일지 경로의 필수값이 아니다. 수동 draft는 일정 ID가 없고, 홈 일정에서 레슨일지 페이지를 열 때도 schedule ID를 전달하지 않으며, quick sign은 optional이고 레슨일지 페이지 원격서명 로그에도 없다. 과거 log도 필드가 없을 수 있다.
- 현재 `firestore.rules`에는 parent training_logs와 anatomyRecords match가 없어 저장소 Rules 기준 모든 anatomy CRUD가 거부된다. 실제 배포 Rules는 확인하지 않았다.
- 최소 후속 권한은 parent 존재, 인증 staff, 신뢰 가능한 parent owner와 auth UID 일치, parent-child member/trainer/path ID 일치, update identity 불변, optional schedule 값 일치를 모두 요구해야 한다.
- 현재 anatomy 목록 query는 memberId만 사용하고 trainer filter가 없으며, legacy parent 배열 fallback도 owner를 재검사하지 않는다. broad Rules 환경에서는 다른 trainer 기록 접근 위험이 있다.
- 부모 문서를 삭제해도 Firestore 하위 collection은 자동 삭제되지 않는다. 현재 hard delete 경로는 찾지 못했고 확정 취소는 `voided` 처리다. Rules에서 parent 존재를 요구해 orphan 접근을 막고, 실제 정리는 승인된 retention/서버 cleanup으로 분리해야 한다.
- 신규 child 구조의 목록 요약 개수는 삭제되는 legacy 부모 배열 길이를 읽어 `0개`로 표시될 수 있다.
- 기존 `ANATOMY_DATA_MODEL.md`의 scheduleDocId 필수 전제와 Rules 예시는 이번 실제 호출 흐름·부모 정합성 감사 결과와 충돌한다. 명시된 결과 문서 범위 때문에 해당 파일과 `DECISIONS.md`는 수정하지 않고 감사 문서에 불일치와 후속 방향만 기록했다.

### 검증과 제한

- 읽기 전용 감사이므로 format, analyze, test, build, emulator, Firebase 배포를 실행하지 않았다.
- 실제 Firebase 프로젝트 데이터와 배포 Rules는 확인하지 않았으므로 실제 교차 접근 또는 저장 성공을 검증했다고 기록하지 않는다.
- 지정 감사 문서의 공백·필수 섹션과 변경 범위를 확인했다.
- 다음 백로그로 이동하지 않았다.

## 2026-07-15 — 계약서·전자서명·데이터 흐름 읽기 전용 감사

### 작업 범위

- `prompts/07_contract_signature_readonly_audit.md`만 수행했다.
- 앱 소스, Firestore/Storage Rules, Functions, 패키지, 설정, 테스트 코드는 수정하지 않았다.
- 다음 지정 문서만 작성했다.
  - `docs/agent/CONTRACT_SIGNATURE_AUDIT.md`
  - `docs/agent/SECURITY_RULES_MATRIX.md`
  - `docs/agent/DATA_SOURCE_OF_TRUTH_AUDIT.md`
  - `docs/agent/CONTRACT_SIGNATURE_TEST_MATRIX.md`
  - 이 실행 기록

### 감사 결과 요약

- 레슨계약서 1단계 기본 양측 서명만으로 계약 `signed`와 회원 `contractSigned=true`가 기록되는 상태 의미 오류를 확인했다.
- `_saveStep1Contract`가 validator 오류 목록을 만들지만 저장 차단 검사를 하지 않는 경로를 확인했다.
- 완료 계약의 불변 revision, content/PDF hash, signer UID, 서버 권위 버전 연결이 없고 `_startNewVersion`이 같은 계약 문서를 재사용함을 확인했다.
- 회원권계약서는 `members/{memberId}/membership_contracts/current` 한 문서를 merge하며, Storage 업로드와 계약/member write가 분리되어 부분 성공 및 고아 파일 위험이 있다.
- 원격 서명은 32자 `Random.secure` 토큰, 24시간 만료, request+training log transaction을 사용한다. 그러나 공개 클라이언트가 Firestore를 직접 읽고 쓰며 서명 검증 Function은 없다.
- 저장소 `firestore.rules`에는 `members`와 `events` 외 경로가 없어 계약/서명 앱 흐름과 호환되지 않는다. `storage.rules`는 비어 있고 `firebase.json`에 Rules/Index 연결도 없다. 실제 배포 Rules는 확인하지 못했다.
- 계약 목록과 회원 목록 query에 owner/trainer 필터가 없고 계약 payload에도 일관된 owner field가 없어 멀티테넌시 경계가 없다.
- PDF 공유는 OS 공유 화면 열림까지 확인 가능하며 카카오/SMS/이메일 발송·전달 영수증은 코드에서 확인되지 않았다.
- 회차 값은 top-level, nested, legacy 필드와 schedule/log/ledger에 중복되어 단일 source of truth가 아니다.

### 검증

- 읽기 전용 감사이므로 `dart format`, `flutter analyze`, `flutter test`, APK build, Firebase 배포는 실행하지 않았다.
- 작성 후 지정 문서 범위와 `git diff --check`만 확인한다.
- 실제 Firebase 프로젝트, 배포 Rules, Firestore/Functions emulator, Storage, 외부 발송 사업자는 검증하지 않았다.

### 남은 위험 및 다음 단계

- 실제 배포 Firestore/Storage Rules를 export해 저장소와 대조해야 한다.
- P0 권장 순서는 상태 머신 교정 → tenant Rules → 원격 서명 Function → 불변 contract revision → 회차 ledger 정리다.
- 이번 작업에서는 BACKLOG 상태를 갱신하거나 다음 백로그로 이동하지 않았다.

## 2026-07-15 — 해부학/body map 1단계 실데이터 연결
- 목표: 기존 해부학 시제품의 더미 동작을 실제 레슨일지 데이터와 연결하고, 신체 기준·부위별 운동/통증/주의/가동성 기록을 Firestore에 저장·조회·수정·삭제한다.
- 기존 더미 구조: `personal_training_log_anatomy`의 `_save()`는 스낵바만 표시했고 `AnatomyLog`/`AnatomyExerciseSet`은 직렬화가 없는 메모리 모델이었다. 영상 선택은 `/dummy/video/path.mp4`, 음성 추출은 고정 문장을 넣었으며 `personal_training_log_anatomy_dummy_page.dart`는 테스트 회원·트레이너를 고정했다. 실제 레슨일지 작성 선택기의 해부학 항목은 항상 잠겨 실제 화면과 연결되지 않았다.
- 선택한 Firestore 저장 위치: `training_logs/{lessonLogId}/anatomyRecords/{anatomyLogId}` 하위 문서를 사용한다. 문서 ID와 `anatomyLogId`가 같아 수정 시 같은 문서를 유지하고, 삭제는 해당 문서 하나만 대상으로 하므로 다른 부위 기록에 영향을 주지 않는다. 부모에는 `anatomySchemaVersion`과 `hasAnatomyRecords`만 merge한다. 초기 배열 구현은 읽기 fallback 후 첫 정상 저장에서 하위 문서로 옮기고 부모 배열을 제거한다. 상세 결정과 호환 규칙은 `docs/agent/ANATOMY_DATA_MODEL.md`에 기록했다.
- 데이터 모델: `trainerId`, `memberId`, `lessonLogId`, `scheduleDocId`, `recordedAt`, `bodyGender`, `bodyView`, `bodySide`, `bodyPartId/Label`, `recordType`, `exerciseName`, 0~10 `painLevel`, `memo`, `createdAt/updatedAt`을 포함한다. enum·날짜·숫자 파싱과 과거 필드 누락 fallback을 구현했다.
- 수정 파일: `lib/pages/personal_training_log_page.dart`, `lib/pages/personal_training_log_anatomy/anatomy_page.dart`, `lib/pages/personal_training_log_anatomy/models/anatomy_log.dart`, `lib/pages/personal_training_log_anatomy/models/body_part.dart`, `lib/pages/personal_training_log_anatomy/widgets/step1_body_part_selector.dart`, `step2_exercise_form.dart`, `step3_video_memo.dart`, `step4_confirm.dart`, `lib/services/anatomy_log_service.dart`, `test/anatomy_log_test.dart`, `docs/agent/ANATOMY_DATA_MODEL.md`, `docs/agent/RUN_LOG.md`, `docs/agent/BACKLOG.md`. 고정 샘플 진입 파일 `lib/pages/personal_training_log_anatomy_dummy_page.dart`는 제거했다.
- 구현 기능: PRO 권한 사용자는 일정과 연결된 기존 레슨일지 상세 또는 작성 선택기에서 해부학 화면 진입을 시도할 수 있다. 성별, 앞/뒤, 좌/우/중앙/양측, 여러 부위, 운동/통증/주의/가동성 유형, 운동명, 통증 강도, 메모를 입력한다. 기존 하위 문서를 불러오고 같은 문서 ID로 수정하며 선택 기록만 삭제한다. 목록 정렬은 `recordedAt` 내림차순 → `createdAt` 내림차순 → `anatomyLogId` 오름차순이다. 앱 재진입 시 회원 ID 단일 쿼리 결과에서 `hasAnatomyRecords` 문서만 골라 레슨일지 목록에 복원한다. 회원·레슨일지 cascade delete는 추가하지 않았다.
- 제외 범위: 영상 업로드·썸네일·음성 추출, 회원 앱 공개·회원 수정, 남성·여성 실제 신체 이미지, Firestore/Storage Rules 및 인덱스는 구현하지 않았다. 기존 가짜 영상·음성 동작은 제거하고 `준비 중`으로 표시했다.
- format: 변경 Dart 파일과 `test/anatomy_log_test.dart`에 formatter 적용 성공. 배치 래퍼가 sandbox 외 분석 설정을 읽지 못해 SDK 실행 파일과 허용된 패키지 캐시 접근으로 재실행했으며 `Formatted 10 files` 후 추가 변경 2개는 `0 changed`였다.
- 관련 테스트: `flutter test test/anatomy_log_test.dart --no-pub -r expanded` 성공. 직렬화/역직렬화, 모든 성별·앞뒤·방향 값, 운동, 통증과 painLevel, 수정 ID 유지, 여러 부위, 개별 삭제, 정렬 기준, 필수 연결 ID guard, 과거 문서 fallback의 10개 테스트가 모두 통과했다.
- 전체 테스트: `flutter test --no-pub -r expanded` 성공. 총 65개 테스트가 모두 통과했다.
- analyze: 최종 `flutter analyze --no-pub`는 저장소 기존 경고·정보 1,193건 때문에 exit code 1이었다. 이번 변경 범위만 지정한 `flutter analyze --no-pub lib/pages/personal_training_log_anatomy lib/services/anatomy_log_service.dart test/anatomy_log_test.dart`는 `No issues found`로 통과했다.
- build: `flutter build apk --debug --no-pub` 성공. `build/app/outputs/flutter-apk/app-debug.apk` 생성.
- 정적 확인: `git diff --check` exit code 0. 기존 다른 파일의 LF→CRLF 경고만 있었고 whitespace 오류는 없었다.
- 식별자 guard: `_openNewLogSheet`가 만드는 로컬 draft는 안정적인 로컬 `lessonLogId`는 있으나 `scheduleDocId`가 비어 있다. 이 작성 선택기 경로는 `[MTF_ANATOMY_IDENTITY]` 로그와 안내를 남기고 화면 진입/저장을 차단한다. `lessonLogId`, `scheduleDocId`, `memberId`, Firebase Auth `trainerId`가 모두 있는 일정 연결 레슨일지 상세에서만 저장 화면을 연다. 서비스도 같은 네 필드를 재검사해 빈 ID 저장을 막는다.
- 저장 실패 처리: Firestore read/write가 실패하면 화면을 닫지 않고 부모 레슨일지 상태도 갱신하지 않으며 성공 토스트를 표시하지 않는다. `permission-denied`는 읽기 또는 저장 권한 실패로 명확히 안내한다.
- 수동 테스트: 실제 Firebase 에뮬레이터 또는 실제 프로젝트 계정·기기에서 Firestore CRUD와 Rules를 검증하지 않았다. 따라서 “실제 Firestore 저장 검증 완료”가 아니다. 영상·회원 앱 공유는 화면에서도 준비 중으로만 표시한다.
- Rules 감사 및 후속안: 현재 `firestore.rules`에는 `/training_logs/{lessonLogId}`와 그 하위 `anatomyRecords` match가 전혀 없어 현재 인증 사용자의 read/write는 기본 거부된다. 실제 프로젝트가 이 Rules를 사용하면 실제 기기 저장은 `permission-denied`로 실패한다. 이번에는 Rules를 수정·배포하지 않았다. 후속 작업의 최소안은 부모 `training_logs`에 `isStaff()` read/create/update를 허용하고, 하위 문서는 `isStaff()`, 경로의 `lessonLogId/anatomyLogId` 일치, `trainerId == request.auth.uid`를 create/update/read/delete별로 검사하는 것이다. 정확한 rules 예시는 `ANATOMY_DATA_MODEL.md`에 기록했다. 영상 단계에서는 Storage 경로, 파일 크기·형식, 트레이너 쓰기/회원 공개 읽기 권한과 감사 필드 설계가 추가로 필요하다.
- 다음 권장 작업: 없음. P4 데이터 모델만 완료로 표시했다. 부위별 기록은 앱 구현은 끝났지만 Rules와 실제 기기 저장 검증이 남아 미완료로 유지했다. 남/여 이미지·영상·회원 공개 항목도 미완료이며 다음 백로그로 이동하지 않는다.

## 2026-07-14 22:42 — Cloud Functions TypeScript 복구 상태 재검증
- 목표: `functions/src/index.ts` 전체와 Git 기준본을 비교해 Flutter/Dart 혼입부만 제거된 상태인지 확인하고, 기존 Firebase Functions export와 정책을 보존한 채 TypeScript 빌드를 검증한다.
- 실제 혼입 위치: Git 기준본 `functions/src/index.ts` 141–186행은 `// lib/core/functions_api.dart`, `package:cloud_functions`, `FunctionsApi`, `Future<void>`, `FirebaseFunctions.instance`가 포함된 Dart 클라이언트 코드였다. 188–295행은 기준본 33–140행의 정상 TypeScript Functions 구현이 그대로 한 번 더 반복된 중복이었다.
- 현재 상태와 제거 범위: 작업 시작 시 현재 파일은 이미 138행으로 정리돼 있었다. 현재 diff에서 Dart 141–186행과 중복 TypeScript 188–295행이 제거되어 있고, 앞쪽의 완전한 TypeScript 구현 하나가 유지됨을 확인했다. 이번 재검증에서는 `functions/src/index.ts`를 추가 수정하지 않았다.
- import/초기화 확인: 미사용 `onRequest`, `logger` import는 현재 diff에서 제거되어 있다. callable 함수 구현은 `firebase-functions/v1`을 사용하며 `firebase-admin` import, `admin.initializeApp()`, `const db = admin.firestore()`는 각각 한 번만 존재한다. 새 패키지는 추가하지 않았다.
- 보존한 Functions export: `chargeOnce`, `cancelNoShow`, `lockConsent`, `unlockConsent`가 소스와 컴파일 산출물에 각각 한 번씩 존재한다. 결제 차감, 노쇼 취소 마킹, 동의서 잠금·해제 조건과 권한 정책은 변경하지 않았다. 현재 파일에 이 네 함수 외의 활성 export는 없으며 주석 처리된 템플릿 `helloWorld`는 export가 아니다.
- 의존성: `functions/node_modules`와 두 lock 파일이 존재했다. `npm.cmd ls --depth=0`이 exit code 0으로 모든 직접 의존성을 확인했으므로 `npm.cmd install`은 실행하지 않았다.
- TypeScript 빌드: `functions` 폴더에서 `npm.cmd run build` 성공. `tsc`, exit code 0.
- tests: `npm.cmd test --if-present`는 exit code 0이지만 `package.json`에 test 스크립트가 없어 실제 Functions 테스트는 실행되지 않았다.
- 정적 확인: `git diff --check -- functions/src/index.ts` 통과. 현재 소스의 Dart 표식 검색 결과 0건, `initializeApp` 1건, `db` 선언 1건, 활성 export 4건을 확인했다.
- 배포: Firebase deploy와 에뮬레이터·실제 호출은 수행하지 않았다.
- 남은 배포 위험: TypeScript 컴파일만 검증했으며 실제 Firebase Auth claim, Firestore 권한·데이터, callable 런타임 동작은 검증하지 않았다. 배포 전 별도 에뮬레이터 또는 승인된 스테이징 호출 확인이 필요하다.
- 다음 권장 작업: 없음. Flutter 앱 소스·테스트와 `BACKLOG.md`는 변경하지 않았고 다음 백로그로 이동하지 않는다.

## 2026-07-14 22:38 — member_input_validation 테스트 Flutter 타입 import 복구
- 목표: 전체 테스트를 막던 `test/member_input_validation_test.dart`의 `TextSelection` 미정의 오류 2건만 최소 수정한다.
- 원인: 테스트 파일이 `flutter_test`와 앱 유틸리티만 import했다. `lib/utils/member_input_validation.dart` 내부의 `flutter/services.dart` import는 테스트 파일로 재노출되지 않으므로 테스트가 직접 사용하는 `TextSelection`을 해석할 수 없었다.
- 수정 파일: `test/member_input_validation_test.dart`, `docs/agent/RUN_LOG.md`.
- 핵심 변경: `package:flutter/services.dart`에서 `TextEditingValue`, `TextSelection`만 가져오는 `show` import 한 줄을 추가했다. 운영 formatter·생년월일 검증 로직과 테스트 기대값은 변경하지 않았다.
- format: `dart format test/member_input_validation_test.dart` 성공. `Formatted 1 file (0 changed)`.
- 관련 테스트: `flutter test test/member_input_validation_test.dart --no-pub -r expanded` 성공. formatter 4개와 생년월일 정규화·검증 9개, 총 13개 테스트 모두 통과.
- 전체 테스트: `flutter test --no-pub -r expanded` 성공. 총 55개 테스트 모두 통과(`All tests passed!`, exit code 0).
- 정적 확인: `git diff --check` 통과. import 중복이 없고 테스트 파일 첫 import가 Flutter 서비스 타입 두 개만 명시적으로 노출한다.
- analyze/build: 이번 요청의 검증 범위에 포함되지 않았고, 운영 소스 변경이 없는 테스트 import 수정이므로 다시 실행하지 않았다. 직전 작업의 debug APK 빌드는 성공 상태다.
- 수동 테스트: 필요 없음.
- 남은 위험: 없음. 범위 밖 소스와 `BACKLOG.md`는 변경하지 않았고 다음 백로그로 이동하지 않는다.

## 2026-07-14 22:32 — 레슨 인사이트 1단계 및 Beginner~Pro 문구 정리
- 목표: 기존 `stats_page.dart`의 모든 지표와 데이터 출처를 감사하고, 고정값·임의 비율·추정 매출을 실제 통계처럼 표시하지 않으면서 신뢰 가능한 레슨·회원 지표만 제공한다. 개인 강사 Beginner~Pro 문맥의 불필요한 `운영` 표현만 자연스럽게 바꾸고 센터·조직·계약·정책 문맥은 유지한다.
- 지표 정의: 구현 전에 `docs/agent/STATS_DEFINITIONS.md`를 작성했다. 기존 총매출·평균 단가·전월/전년 성장·재등록률·소개 매출·신규 유입·진행률의 코드 계산, 원천, 포함·제외, 기간, 신뢰 판단과 처리 방식을 전수 기록했다. Phase 1의 완료·예정·실제 수업률·상태별 레슨·요일·종류·회원 상태·신규·잔여 5회 이하·기간 내 만료 예정·14일 이상 미방문 정의와 수입 미연결 사유도 기록했다.
- 감사 결과: 홈에서 전달한 `scheduleData`는 현재 주 기준 앞뒤 4주만 구독하므로 월·3개월 지표 원천으로 불완전했다. 기존 매출은 일정 수×사용자 입력 단가, 소개 매출은 그 값의 18%, 성장률은 고정 배열, 재등록률은 PT·필라테스 일정 비중, 신규 유입은 일정 건수 비율이었다. 모두 실제 의미와 다른 값이므로 기존 계산 상태 클래스와 관련 차트·카드를 제거했다.
- 신뢰 지표 구현: 선택 기간의 Firestore `schedules.startAt` 범위를 직접 조회하고 삭제 일정은 제외한다. `lessonConfirmStatus`로 완료·노쇼 차감·노쇼 미차감·서비스를 집계하고, 미래 미확정 일정만 예정으로 센다. 실제 수업률은 정의된 확정 결과를 분모로 계산하며 분모가 없으면 `-`를 표시한다. 요일과 레슨 종류도 같은 기간의 실제 일정 문서만 사용한다. `members`의 실제 상태·생성일·횟수·회원권 종료일·마지막 레슨일로 회원 지표를 계산한다.
- 숨긴/보류한 지표: 결제 금액과 결제일이 확인되는 수납 원천이 없어 수입은 숫자 없이 `데이터 연결 준비 중`으로 표시한다. 확정 취소는 현재 취소 서비스가 일정의 확정 필드를 삭제하므로 이력 원천 연결 전까지 집계하지 않는다. 회원 행동 카드의 목록 필터 이동도 공용 필터 계약이 없어 후속 연결로 문서화했다.
- 화면 변경: 명칭을 `레슨 인사이트`로 바꾸고 이번 주·이번 달·3개월·직접 선택 기간을 지원한다. 섹션은 요약, 레슨, 회원, 수입 순서이며 기존 보라색 헤더·KPI 카드·요일 막대·종류 도넛의 시각 체계를 유지했다. 홈에서 넘기는 `scheduleData` 생성자 인자는 기존 호출 호환을 위해 유지하되 통계 원천으로 사용하지 않는다.
- 문구 변경: 홈 개인 강사 안내의 `운영 집중/운영 리듬/운영일/운영력`을 `레슨 집중/레슨 리듬/레슨이 많은 날/집중력` 문맥으로 바꿨다. My·설정·AIFC의 Beginner~Pro 문구는 `활동 현황`, `관리 흐름`, `앱 설정`, `레슨 인사이트`, `프로다운 관리 흐름` 등으로 변경했다. 상담의 `운영 메모`는 `상담 메모`로 정리했다.
- 유지한 `운영` 문구: Master·Grand Prix의 센터·팀·브랜드·다수 지점 문맥, MORE 비즈니스 관리자 문맥, 회원권·계약서·환불·수업 기준과 정책 문구, 서비스 제공 방향 문구는 의도적으로 유지했다. 필드·컬렉션·enum·라우트·클래스 이름은 변경하지 않았다.
- 수정 파일: `docs/agent/STATS_DEFINITIONS.md`, `lib/pages/stats_page.dart`, `lib/utils/lesson_insights_stats.dart`, `test/lesson_insights_stats_test.dart`, 개인 강사 문구가 있던 `home_page.dart`, `home_header_section.dart`, `my_page.dart`, `settings_page.dart`, AIFC 안내 파일 5개와 `client_list_page.dart`, `docs/agent/RUN_LOG.md`.
- format: 직접 Dart formatter로 13개 변경 대상 파일을 검사했고 12개 파일을 정렬했다. exit code 0.
- analyze: `dart analyze lib/pages/stats_page.dart`는 오류 없이 기존 스타일·deprecated info 14건만 보고했고, `dart analyze lib/utils/lesson_insights_stats.dart`는 `No issues found`. 전체 `flutter analyze --no-pub`는 저장소 기존 경고·info와 범위 밖 `test/member_input_validation_test.dart`의 `TextSelection` 미정의 오류 2건 때문에 실패했다(총 1213 issues).
- tests: `flutter test test/lesson_insights_stats_test.dart --no-pub -r expanded`는 실제 상태 집계, 분모 없는 비율, 회원 지표, 정확히 14일 미방문의 4개 테스트가 모두 통과했다. 전체 `flutter test --no-pub -r expanded`는 새 테스트를 포함한 실행 항목이 통과했으나 범위 밖 `member_input_validation_test.dart`의 같은 `TextSelection` 컴파일 오류 2건으로 최종 실패했다. 이 테스트 파일은 수정하지 않았다.
- build: `flutter build apk --debug --no-pub` 성공. `build/app/outputs/flutter-apk/app-debug.apk` 생성, Gradle `assembleDebug` 173.0초, 전체 182.6초, exit code 0.
- 정적 확인: 고정 단가 `1150000`, 임의 `0.18`, 고정 성장 배열, 전월 대비 고정 문구, 재등록률·소개 매출 카드가 `stats_page.dart`에 남지 않았고 `git diff --check`가 통과했다. 홈 스케줄 P0, 회원추천 칩, 생년월일 입력 로직의 기능 코드는 변경하지 않았다.
- 수동 테스트: 수행하지 않았다. 실제 계정에서 기간 전환, 직접 선택, 빈 데이터의 `-`, Pro gate, Firestore 권한 오류의 재시도 화면을 확인할 수 있다.
- 남은 위험: 실제 수납 원천, 확정 취소 감사 이력, 통계 행동 카드→회원 목록 필터 연결은 후속 데이터 계약이 필요하다. 전체 analyze/test의 기존 `TextSelection` 오류는 별도 작업 범위다.
- 다음 권장 작업: 없음. `BACKLOG.md`는 변경하지 않았고 요청대로 다음 백로그로 이동하지 않는다.

## 2026-07-14 10:42 — 홈 최근 등록 회원 원형 아이콘 칩 복원
- 목표: 홈 레슨 등록/수정 시트의 기존 `최근 등록 회원` 위치와 검색·연결 기능은 유지하고, 단순 텍스트 pill에 이전 디자인의 작은 원형 사람 아이콘만 복원한다.
- source of truth: Git 이력 `1ec5c5d`의 `home_page.dart`에 있던 `_RecentMemberBubble`을 확인했다. 기존 디자인의 보라색 저채도 원형 배경·테두리와 `Icons.person_outline_rounded`를 기준으로 사용했다.
- 변경 내용: 현재 pill 내부를 `작은 원형 배경 + 사람 아이콘 → 회원 이름 → 구분점 → 전화번호 뒤 4자리` 순서로 구성했다. 칩 전체의 작은 pill 형태와 기존 보라색 배경·테두리는 유지했다. 최대 너비 안에서 이름만 `TextOverflow.ellipsis`로 줄어들고 구분점과 전화번호 뒤 4자리는 별도 고정 텍스트로 남는다. 전화번호가 없으면 이름과 아이콘만 표시한다.
- 유지한 기능: 빈 검색어의 최근 등록 회원 추천, 입력 후 같은 영역의 전체 회원 검색, 오래된 회원·`createdAt` 없는 회원 포함, 이름 일부·초성·전화번호 검색, 삭제 회원 제외, 최대 5명, `phoneNormalized → phone → phoneDisplay`, 칩을 탭한 경우에만 `onPicked`로 `memberId` 연결하는 흐름을 변경하지 않았다. 추천 섹션 위치, 레슨 종류 칩 위 `IgnorePointer` 안내 토스트, 7색 팔레트도 그대로다.
- 수정 파일: `lib/widgets/home/lesson_editor/home_recent_members_section.dart`, `test/home_recent_member_chip_test.dart`, `docs/agent/RUN_LOG.md`.
- 테스트 추가: 원형 `person_outline_rounded` 아이콘과 이름·구분점·전화번호 뒤 4자리 표시, 긴 이름만 말줄임 처리, 탭 전 callback 미실행과 탭 후 1회 실행을 확인하는 위젯 테스트를 추가했다.
- 실행 명령: 변경 파일 `dart format`; `flutter analyze --no-pub`; `flutter test test\home_recent_member_chip_test.dart test\home_member_connection_hint_test.dart test\widget_test.dart --no-pub -r expanded`; 관련 위치·토스트·팔레트 참조 검색; `git diff --check`.
- format/analyze/tests: 포맷 180초, analyze 300초, 관련 테스트 300초가 모두 출력 없이 시간 초과했다. 같은 Dart/Flutter 실행기 무출력 정체가 3회 반복되어 프로젝트 지침에 따라 전체 `flutter test --no-pub -r expanded`와 `flutter build apk --debug --no-pub`는 실행하지 않았다. 포맷·분석·테스트·APK 빌드 통과로 판단하지 않는다.
- 정적 확인: 변경 파일의 trailing whitespace 없음, `git diff --check` 통과. `HomeRecentMembersSection`은 레슨 확정 영역 아래 기존 한 곳에만 있고, 검색 결과와 최근 회원 모두 동일한 `HomeRecentMemberChip`을 사용한다. `onPicked` callback, 레슨 종류 선택기 위 `IgnorePointer` 토스트, `kLessonTypePalette` 참조가 유지됨을 확인했다. 텍스트 전용 `ChoiceChip`이나 `ListTile`은 추가하지 않았다.
- 수동 테스트: 최근 등록 회원과 이름 검색 결과 모두 작은 원형 사람 아이콘·이름·전화번호 뒤 4자리를 표시하는지, 긴 이름에서 전화번호가 유지되는지, 칩 탭 시에만 회원카드가 연결되는지, 추천 위치와 안내 토스트 위치가 변하지 않았는지 실제 기기에서 확인해야 한다.
- 남은 위험: 자동 검증과 APK debug 빌드가 실행기 정체로 미검증이며 실제 화면 확인도 남아 있다. 홈 스케줄 삭제·이동 P0, `selectedDates`, 생년월일, Firestore 저장, 레슨 확정·회차·계약서 코드는 수정하지 않았다.
- 다음 권장 작업: 없음. `BACKLOG.md`는 변경하지 않았고 다음 백로그로 이동하지 않는다.

## 2026-07-13 22:41 — 홈 스케줄 단일 편집 다중 날짜 상태 누수 P0
- 목표: 단일 레슨 편집 시 이전 시트의 날짜·요일 선택이 남아 `createOrUpdateMany` 또는 다중 target `moveOrReplace`로 이어지는 경로만 차단한다. 기존 실제 `DocumentSnapshot.id`, atomic delete/move, `Source.server` 확인, authoritative tombstone, stale snapshot 폐기, editSession mutation guard, 삭제/저장 결과 분리는 변경하지 않았다.
- 실제 원인과 코드 위치: `_openLessonEditorSheet()`의 선택값은 가변 `Set<String>`으로 생성돼 `HomeLessonDaySelector`에 직접 전달됐고, 자식 위젯이 전달받은 Set을 직접 `add/remove`했다. 현재 세션에서 사용자가 명시적으로 다중 선택했는지를 별도 상태로 기록하지 않았으며, `_handleLessonSave()`와 `_saveEditedLessonSchedule()`은 전달된 `selectedDays.length`만 보고 다중 write를 구성했다. 따라서 오염된 Set이 들어오면 저장 직전 차단 장치 없이 여러 날짜의 write와 batch 분기로 진행할 수 있었다. 같은 회원 반복 묶음 개수도 편집 로그의 `isRecurring`으로 계산돼 단일 편집 상태와 혼동될 여지가 있었다.
- 초기화 방식: 각 시트의 `editSessionId`마다 `HomeScheduleEditSelectionState.single`을 새로 만들고, 기존 레슨의 실제 `startAt` 요일 한 개만 선택한다. 선택 Set은 읽기 전용 복사본으로 UI에 전달하고, `HomeLessonDaySelector`는 더 이상 Set을 직접 수정하지 않는다. 시트 종료 시 선택 상태를 비우고 dispose한다. 같은 회원 묶기 설정과 이전 시트의 요일은 초기값에 사용하지 않는다.
- `explicitMultiDaySelection` 조건: 현재 시트에서 사용자가 요일 칩을 실제로 추가하거나 제거해 선택값이 변경된 경우에만 true가 된다. 새 시트는 항상 false로 시작한다. true이면서 현재 선택 날짜가 2개 이상일 때만 `isMultiDay=true`와 다중 저장이 허용된다. true여도 최종 선택이 한 날짜면 단일 update 또는 source 1개→target 1개 이동으로 처리한다.
- 단일 저장 불변조건: 저장 버튼 callback과 `_handleLessonSave()` 양쪽에서 선택값을 정규화한다. `explicitMultiDaySelection=false`이면 현재 레슨 요일 정확히 한 개로 강제하며, 오염된 다중 값은 `implicit_single_selection_state_leak`으로 기록하고 여러 문서를 생성하지 않는다. `_saveEditedLessonSchedule()`에도 암시적 다중 값 차단을 추가했고, 단일 commit은 선택 날짜 1개와 source 삭제 최대 1개인 경우에만 사용한다.
- 로그: 시트 open 시 `originalActualDocId`, `originalStartAt`, `initializedSelectedDates`, `initializedSelectedWeekdays`, `explicitMultiDaySelection`, `stateSource`를 남긴다. 날짜 선택 변경 시 caller/userAction을 기록한다. 저장 직전에는 선택 날짜·요일, `isMultiDay`, 명시적 다중 여부, 마지막 변경 caller, `update`/`moveOrReplace`/`createOrUpdateMany` 분기, 단일 불변조건 보정 여부와 사유를 기록한다.
- 수정 파일: `lib/pages/home_page.dart`, `lib/models/home_lesson_save_request.dart`, `lib/utils/home_schedule_edit_session_guard.dart`, `lib/utils/home_schedule_write_plan.dart`, `lib/widgets/home/lesson_editor/home_lesson_day_selector.dart`, `test/home_schedule_edit_session_guard_test.dart`, `test/home_schedule_write_plan_test.dart`, `docs/agent/RUN_LOG.md`, `docs/agent/BACKLOG.md`.
- 테스트 보강: 다중 월·수·금 세션 종료 후 목요일 단일 시트 초기화, 이동된 단일 레슨 재진입 시 1개 선택, 현재 세션에서 직접 월·수·금 선택 시에만 명시적 다중, 강제로 주입한 암시적 다중 상태의 저장 직전 단일 보정, 명시하지 않은 다중 target의 단일 commit 거부를 추가했다. 기존 identity·mutation guard·move plan·tombstone 테스트도 관련 검증 명령에 포함했다.
- 실행 명령: 변경 Dart 파일 `dart format`; `flutter analyze --no-pub`; `flutter test test\home_schedule_edit_session_guard_test.dart test\home_schedule_write_plan_test.dart test\home_lesson_editor_result_test.dart test\home_schedule_move_plan_test.dart test\home_schedule_tombstone_guard_test.dart --no-pub -r expanded`; 참조 검색; `git diff --check`.
- format/analyze/tests: 포맷 180초, analyze 300초, 관련 테스트 300초가 모두 출력 없이 시간 초과했다. 동일한 Dart/Flutter 실행기 무출력 정체가 3회 반복되어 지침에 따라 전체 `flutter test --no-pub -r expanded`와 `flutter build apk --debug --no-pub`는 실행하지 않았다. 포맷·분석·테스트 통과로 판단하지 않는다.
- 정적 확인: `git diff --check` 통과. `HomeLessonDaySelector` 호출과 callback, `HomeLessonSaveRequest`의 명시적 다중 필드, 단일 commit 호출 인자가 각각 일치하며 tombstone과 Firestore 삭제 서비스는 수정하지 않았다.
- 실제 기기 필수 재검증: 월·수·금 다중 등록 후 별개 목요일 단일 편집, 이동된 단일 레슨 재진입, 메모·색상만 수정, 단일 시간 이동, 삭제 후 다른 레슨 편집, 현재 세션에서 월·수·금 직접 선택, 다중 등록 후 새 시트 열기를 확인한다. 단일 편집 로그는 선택 날짜·요일 각각 1개, `explicitMultiDaySelection=false`, `isMultiDay=false`, target 1개여야 한다.
- 남은 위험: 자동 포맷·분석·테스트·APK 빌드와 실제 기기 검증이 남아 있다. 이전 완료 기록은 이번 실제 로그로 무효화돼 홈 스케줄 관련 P0를 미완료로 되돌렸으며, 실제 기기 검증 전에는 완료 처리하지 않는다.
- 다음 권장 작업: 없음. 요청에 따라 다음 백로그로 이동하지 않는다.

## 2026-07-13 18:09 — 홈 스케줄 삭제·이동 재등장 P0 실제 기기 검증 완료
- 범위: 최신 debug APK의 홈 스케줄 이동·삭제 편집 세션 P0를 실제 기기에서 검증한 사용자 결과를 반영했다. 소스 코드는 추가 수정하지 않았다.
- 이동 후 identity: 14:00 레슨을 13:00으로 이동한 뒤 정상 표시됐고, 이동된 13:00 레슨을 삭제했을 때 target 문서가 정상 삭제됐다. 기존 14:00 레슨은 다시 나타나지 않았다.
- 삭제 후 재등장: 삭제 직후부터 10초·30초·1분·3분까지 재등장하지 않았다. 다른 주로 이동한 뒤 돌아와도 정상이며, 앱을 강제 종료하고 다시 실행한 뒤에도 삭제된 레슨이 나타나지 않았다.
- 연속 mutation: 연속 이동 후 삭제가 정상 동작했고, 저장 버튼을 연속으로 눌러도 mutation은 1회만 실행됐다.
- 단일/다중 저장 분기: 월·수·금 레슨을 등록한 뒤 단일 목요일 레슨을 수정해도 다른 날짜의 레슨이 재생성되지 않았다.
- 결과: 홈 레슨 삭제·이동 재등장 관련 P0 실제 기기 검증을 통과해 `BACKLOG.md`의 해당 6개 운영 버그 항목을 완료 처리했다. 주간 위젯 관련 P0와 기준 상태 항목은 변경하지 않았다.
- 다음 권장 작업: 없음. 요청에 따라 다음 백로그로 이동하지 않았다.

## 2026-07-13 15:37 — 홈 스케줄 연속 이동·삭제 편집 세션 identity P0
- 목표: 이동·삭제를 연속 수행할 때 같은 편집 시트의 오래된 source identity나 중복 callback이 다음 mutation에 사용되어 target 문서가 남거나 일정이 다시 나타나는 경로를 차단한다.
- 실제 원인: (1) 레슨 편집 시트의 `existingSession`은 시트를 열 때 받은 source 객체를 계속 캡처했으며 저장·삭제 버튼에 세션 단위 재진입 방어가 없었다. 따라서 이동 저장 Future가 진행 중일 때 빠른 삭제/저장 callback이 원래 source A를 다시 대상으로 삼을 수 있었다. (2) 단일 레슨 편집을 열어도 기존 반복 그룹의 요일 전체를 `selectedDays`로 초기화하고 `_saveEditedLessonSchedule`도 반복 그룹 전체를 source로 사용해, 사용자가 명시하지 않은 다중 write와 `createOrUpdateMany` 계열 동작이 섞일 수 있었다. (3) 삭제 결과를 받은 부모 callback 자체는 레슨 종류 설정과 안내만 처리하고 스케줄 저장을 호출하지 않았다. 삭제 뒤 재생성 후보는 delete-result callback이 아니라 guard 없이 중복 진입할 수 있던 같은 시트의 `onSave`/`onDelete` Future였다.
- 이동 후 current doc identity: Firestore stream 항목에 실제 `DocumentSnapshot.id`인 `actualDocumentId`와 원본 data의 `dataDocumentId`를 분리해 보존한다. 이동 성공 후 편집 guard와 현재 시트 객체의 `actualDocumentId`, `docId`, `startAt`을 target ID/시각으로 원자적으로 교체하고 `[MTF_SCHEDULE_MUTATION]`에 source/target 전후 identity를 기록한 뒤 시트를 즉시 닫는다. 이후 삭제·수정은 최신 로컬/Firestore snapshot에서 다시 연 target 문서를 사용한다.
- editSession guard: 시트마다 `editSessionId`를 생성하고 `idle → saving → moved/deleted/completed → disposed` 상태를 관리한다. saving 중 빠른 저장·삭제 재진입, moved/deleted/completed/disposed 상태의 모든 후속 mutation을 차단한다. 시트가 먼저 닫히면 진행 중 Future의 결과 callback은 `sheetDisposed`로 무시한다. 허용/차단 결과와 이유는 `[MTF_SCHEDULE_EDIT_SESSION]`, `[MTF_SCHEDULE_CALLBACK]`에 기록한다.
- 삭제 경로: 삭제는 guard의 `currentActualDocId`만 대상으로 하며 UI 시간, current actual/data doc ID, Firestore에서 읽은 snapshot ID와 reference path를 로그에 남긴다. 삭제 성공 결과에는 `deletedSuccessfully=true`, `savedSuccessfully=false`만 반환하고 부모 result callback은 `parentScheduleWrite=false`를 기록한다.
- 단일/다중 저장 분기: 편집 시트의 초기 선택 요일은 현재 레슨 요일 하나뿐이다. 편집 source도 현재 실제 문서 하나만 사용하며 과거 반복 그룹 문서를 재사용하지 않는다. 단일 편집은 `commitEditedSchedule`의 `update` 또는 `moveOrReplace` 한 번만 실행하고, 사용자가 현재 시트에서 둘 이상의 요일을 직접 선택한 경우에만 batch 경로를 사용한다. 일반 batch 로그도 write 1개와 다중 write를 구분해 단일 write를 `createOrUpdateMany`로 잘못 표시하지 않는다.
- 필수 로그: `editSessionId`, UI mutation ID, caller, userAction, stateBefore/stateAfter, currentActualDocId/currentDataDocId, sourceDocId/targetDocId, currentStartAt/targetStartAt, selectedDates/selectedWeekdays, isMultiDay/isRecurring, sheetMounted, selected schedule object identity, guard 허용/차단, callback 무시 사유를 추가했다. 기존 service mutation ID, atomic batch, server verify, authoritative tombstone, stale snapshot 폐기 로그는 유지했다.
- 수정 파일: `lib/pages/home_page.dart`, `lib/services/home_schedule_firestore_service.dart`, `lib/models/home_lesson_editor_result.dart`, `lib/models/home_lesson_save_result.dart`, `lib/utils/home_schedule_edit_session_guard.dart`, `lib/utils/home_schedule_write_plan.dart`, `test/home_schedule_edit_session_guard_test.dart`, `test/home_schedule_write_plan_test.dart`, `test/home_lesson_editor_result_test.dart`, `docs/agent/RUN_LOG.md`, `docs/agent/BACKLOG.md`
- 테스트 추가: 이동 성공 후 A→B identity 교체, saving 중 삭제 차단, moved/deleted 뒤 후속 mutation 차단, 빠른 저장 두 번 중 한 번만 허용, 단일 편집의 이전 반복 요일 미상속, 단일/다중 commit 분기, 삭제 결과와 저장 결과의 상호 배타성을 순수 단위 테스트로 추가했다. 기존 move plan/tombstone 테스트도 관련 검증 목록에 포함했다.
- 실행 명령: 변경 Dart 파일 `dart format`; `flutter analyze --no-pub`; `flutter test test\home_schedule_edit_session_guard_test.dart test\home_schedule_write_plan_test.dart test\home_lesson_editor_result_test.dart test\home_schedule_move_plan_test.dart test\home_schedule_tombstone_guard_test.dart --no-pub -r expanded`; `git diff --check`.
- format/analyze/tests: 각각 출력 없이 포맷 180초, analyze 300초, 관련 테스트 300초 후 시간 초과했다. 동일한 Dart/Flutter 실행기 무출력 정체가 3회 반복되어 프로젝트 지침에 따라 전체 `flutter test --no-pub -r expanded`와 `flutter build apk --debug --no-pub`는 실행하지 않았다. formatter·analyze·테스트 통과로 판단하지 않았다.
- 정적 확인: `git diff --check` 통과. 편집 시트 결과를 받는 부모 경로에는 schedule create/update/move 호출이 없고, 삭제 결과는 저장 성공 플래그를 반환하지 않는다. 단일 편집 source는 현재 actual 문서 한 개이며 초기 선택 요일도 현재 요일 하나다.
- PowerShell 직접 검증 명령: `dart format lib\pages\home_page.dart lib\services\home_schedule_firestore_service.dart lib\models\home_lesson_editor_result.dart lib\models\home_lesson_save_result.dart lib\utils\home_schedule_edit_session_guard.dart lib\utils\home_schedule_write_plan.dart test\home_schedule_edit_session_guard_test.dart test\home_schedule_write_plan_test.dart test\home_lesson_editor_result_test.dart`; 위 관련 테스트 명령; `flutter analyze --no-pub`; `flutter test --no-pub -r expanded`; `flutter build apk --debug --no-pub`.
- 실제 기기 필수 재검증: 14:00→13:00 이동 후 시트가 닫히고 target B identity가 로그에 남는지, 다시 열어 삭제 시 B가 삭제되고 A/B 모두 없는지, 이동 중 빠른 삭제와 저장 두 번 탭이 `state_saving`으로 차단되는지, 삭제 뒤 `parentScheduleWrite=false`이며 create/update/move가 없는지, 과거 월·수·금 등록 뒤 단일 편집에서 현재 요일만 선택되는지 확인한다.
- 남은 위험: 자동 포맷·analyze·테스트·APK 빌드와 실제 기기 연속 mutation 검증이 완료되지 않았다. 실제 로그로 두 번째 callback의 차단과 A/B 서버 부재를 확인하기 전에는 완료로 판단하지 않는다.
- 다음 권장 작업: 없음. BACKLOG를 완료 처리하지 않았고 다음 백로그로 이동하지 않음.

## 2026-07-13 14:44 — 사용자 PowerShell·실제 기기 검증 결과 반영
- 범위: 홈 레슨 시트 회원추천 UI 복원과 홈 스케줄 삭제·이동 후 재등장 P0의 사용자 직접 검증 결과만 문서에 반영했다. 소스 코드는 수정하지 않았다.
- 자동 검증: 사용자가 PowerShell에서 `flutter test`와 `flutter build apk --debug`를 실행 완료했다고 전달했다. 메시지의 각 명령 뒤 상세 결과와 성공 문구는 비어 있어 통과 여부나 테스트 개수, APK 경로는 임의로 기록하지 않았다.
- 회원추천 UI 실제 기기 검증 통과: 이름 입력창 아래 세로 추천 리스트가 나타나지 않음, 기존 `최근 등록 회원` 위치의 작은 칩 표시, 검색 시 같은 칩 영역 갱신, 레슨 종류 칩 위 안내 토스트, 키보드가 열린 상태의 토스트 표시, 토스트 표시 전후 레이아웃 불변, 회원 칩을 탭한 경우에만 회원 연결됨을 확인했다.
- 홈 스케줄 P0 실제 기기 검증 통과: 삭제 후 재등장 없음, 09:00→10:00 이동 후 기존 source 일정 재등장 없음, 요일 간 이동 정상, 연속 이동 정상, 앱 재실행 후 정상임을 확인했다.
- BACKLOG: 위에서 명시적으로 통과한 회원추천 UI, 삭제 후 미재등장, 시간 이동, 요일 간·연속 이동, 앱 재실행 항목만 완료로 기록했다. 오래된 snapshot 적용 진단, 삭제 확인 전까지 숨김 유지, 연속 삭제·재진입, Android 주간 위젯 항목 및 상세 출력이 없는 자동 검증 기준 항목은 완료 처리하지 않았다.
- 다음 권장 작업: 없음. 다음 백로그로 이동하지 않음.

## 2026-07-13 14:39 — 홈 레슨 시트 회원 추천 위치·안내 오버레이 복원
- 목표: 홈 레슨 등록/수정 시트의 회원 추천을 이름 입력창 아래에서 제거해 기존 `최근 등록 회원` 위치와 작은 둥근 칩 형태로 복원하고, 회원 선택 안내를 레슨 종류 칩 위에 겹치는 오버레이로 표시한다.
- 원인: 개선된 전체 회원 검색 결과를 `HomeRecentMembersSection`의 전체 너비 세로 타일로 바꾸면서 해당 섹션 자체가 이름 입력창 바로 아래로 이동했다. 회원 안내는 시트 전체 `Stack`의 `top: 66` 고정 좌표에 배치되어 레슨 종류 칩 블록을 기준으로 정렬되지 않았다.
- 수정 파일: `lib/pages/home_page.dart`, `lib/widgets/home/lesson_editor/home_member_connection_hint.dart`, `lib/widgets/home/lesson_editor/home_recent_members_section.dart`, `test/home_member_connection_hint_test.dart`, `docs/agent/RUN_LOG.md`
- 변경 내용: 회원 추천 섹션을 이름 입력창 아래에서 제거하고 메모·AI FC 추천 업무·레슨 확정 영역 뒤, 하단 버튼 앞에 한 번만 배치했다. 전체 너비 검색 타일을 기존 최근 회원 표시의 보라색 저채도 배경·테두리를 따르는 작은 pill 칩으로 복원하고 `이름 · 전화번호 뒤 4자리`만 표시한다. 전체 `members` 스냅샷, `createdAt` 정렬, 생성일 없는 회원 포함, 삭제 회원 제외, 이름 일부·초성·전화번호 검색, `phoneNormalized → phone → phoneDisplay`, 중복 제외, 최대 5명 조건과 칩을 눌렀을 때만 `memberId`를 연결하는 흐름은 유지했다.
- 안내 오버레이: 레슨 종류 선택기와 같은 `Stack`에 `Positioned` + `IgnorePointer`로 배치해 시트 높이와 아래 위젯 위치를 바꾸지 않는다. 이름 입력창 최초 탭에는 `등록된 회원이라면 아래 회원 칩을 선택해주세요.`를 1.8초, 회원 칩 선택에는 `회원카드와 연결했어요.`를 1.2초 표시한다. 이름 입력 변경은 타이머를 시작하지 않는다.
- 관련 테스트: 두 안내 문구와 상태별 아이콘을 Firebase 없이 확인하는 `test/home_member_connection_hint_test.dart`를 추가했다.
- 실행 명령: `dart format lib\pages\home_page.dart lib\widgets\home\lesson_editor\home_member_connection_hint.dart lib\widgets\home\lesson_editor\home_recent_members_section.dart test\home_member_connection_hint_test.dart`; `dart --version`; `flutter test test\home_member_connection_hint_test.dart test\widget_test.dart --no-pub -r expanded`; `git diff --check -- lib\pages\home_page.dart lib\widgets\home\lesson_editor\home_member_connection_hint.dart lib\widgets\home\lesson_editor\home_recent_members_section.dart test\home_member_connection_hint_test.dart`
- format: `dart format`이 출력 없이 180초 후 시간 초과했다. `dart --version`도 출력 없이 15초 후 시간 초과해 포맷 대상 코드가 아니라 Dart 실행기 자체의 정체임을 확인했다. 변경 구간은 수동으로 정렬했지만 formatter 완료로 판단하지 않았다.
- analyze/tests/build: 관련 테스트도 출력 없이 300초 후 시간 초과했다. 같은 원인의 3회 실패 중단 지침에 따라 `flutter analyze --no-pub`, 전체 `flutter test --no-pub -r expanded`, `flutter build apk --debug --no-pub`는 실행하지 않았다. 2026-07-11부터 남아 있는 Dart 프로세스 4개를 확인했으나 다른 작업 상태일 수 있어 임의 종료하지 않았다.
- 정적 확인: `HomeRecentMembersSection` 호출은 레슨 시트에 1곳만 남았고, 메모·레슨 관련 업무 뒤이면서 하단 버튼 앞이다. 안내 오버레이는 레슨 종류 선택 블록 내부에 있고 `IgnorePointer`를 적용했다. 두 안내 문구와 1.8초/1.2초 타이머, 최초 탭 1회 조건을 확인했다. `git diff --check` 통과.
- 수동 테스트: 실제 화면 순서, 이름 입력 시 같은 최근 등록 회원 칩 영역의 갱신, 빈 이름의 최근 회원 추천, 키보드가 열린 상태의 오버레이 가시성, 오버레이 중 레슨 종류 칩 터치, 표시 전후 레이아웃 불변, 칩 탭 전 `memberId` 미연결은 실제 기기에서 확인이 필요하다.
- 잔여 위험: 자동 format·analyze·테스트·APK 빌드와 실제 기기 UI 검증이 완료되지 않았다. 생년월일 formatter, 7색 레슨 색상, 홈 삭제·이동 P0, Firestore 저장 및 레슨 확정·회차·계약서 로직은 변경하지 않았다.
- 다음 권장 작업: 없음. 요청 범위 밖의 다음 백로그로 이동하지 않음.

## 2026-07-13 10:16 — 홈 스케줄 삭제·이동 후 재등장 P0
- 목표: 실제 기기에서 삭제 또는 시간 이동한 source 레슨이 캐시·중복 문서·서버 미삭제 때문에 다시 나타나는 경로를 차단한다.
- 실제 원인: (1) tombstone reconciliation이 snapshot metadata를 보지 않아 캐시 snapshot에서 source가 잠시 빠진 순간 tombstone을 해제했다. 이후 서버 snapshot 또는 캐시 재동기화에서 source가 다시 보일 수 있었다. (2) 시간 key당 로컬 항목 하나만 저장하여 같은 시간의 Firestore 문서가 여러 개면 한 문서가 조용히 덮였다. 보이는 문서만 삭제하면 숨겨진 실제 문서가 다음 snapshot에서 나타날 수 있었다. (3) delete/move batch commit 뒤 `Source.server` 확인이 없어 source가 실제로 남아도 성공 처리할 수 있었다.
- schedules 쓰기 경로: `HomeScheduleFirestoreService.saveSchedule`의 신규/동일 ID merge 저장, `commitScheduleWrites`의 시간 줄 이동·레슨 수정/반복 그룹 수정·주간 붙여넣기, `deleteSchedule`/`deleteSchedules`의 단건·주간·덮어쓰기 삭제, 홈의 회원 연결 merge, `HomeDeletedMemberScheduleService`와 고객카드 회원 삭제의 연결 필드 해제, `LessonConfirmationService`/`LessonConfirmCancelService`의 기존 문서 transaction update, 레슨일지/빠른서명의 기존 문서 transaction update가 있다. 위젯 동기화는 HomeWidget 저장소만 쓰며 Firestore schedules를 생성하지 않고, 홈 타이머·debounce에서도 schedules 재저장 경로는 확인되지 않았다.
- 수정 파일: `lib/pages/home_page.dart`, `lib/services/home_schedule_firestore_service.dart`, `lib/utils/home_schedule_move_plan.dart`, `lib/utils/home_schedule_tombstone_guard.dart`, `test/home_schedule_move_plan_test.dart`, `test/home_schedule_tombstone_guard_test.dart`, `docs/agent/RUN_LOG.md`
- 변경 내용: snapshot revision/fromCache/pendingWrites 로그를 추가하고 authoritative server snapshot에서만 tombstone을 판정한다. mutation 진행 중에는 유지하고, 서버 snapshot에서 source 부재 확인 시 삭제 확정, source 존재 시 실패 상태로 노출한다. 이동은 실제 snapshot ID를 source로 사용하며 data `docId` 불일치를 기록한다. delete/move batch 뒤 각 source를 `Source.server`로 확인하고 남아 있거나 확인 실패 시 성공 처리하지 않는다. 동일 시간 문서는 시작·종료·회원·이름·종류·확정 상태가 같은 경우만 exact duplicate로 묶어 같은 batch에서 처리하고, 내용이 다른 충돌 문서는 자동 삭제/이동을 차단한다.
- 실행 명령: 변경 Dart 파일 `dart format`, `flutter test test\home_schedule_tombstone_guard_test.dart test\home_schedule_move_plan_test.dart --no-pub -r expanded`, `flutter test --no-pub -r expanded`, schedules 쓰기 경로 및 진단 로그 검색, `git diff --check`
- analyze: 포맷·관련 테스트·전체 테스트에서 동일한 무출력 정체가 3회 반복되어 지침에 따라 실행하지 않음.
- tests: source/target 동일·상이 이동, 실제 snapshot ID와 stale data docId 불일치, stale revision, cache/pending/in-flight tombstone 유지, authoritative 서버 snapshot의 source 부재/존재 판정 테스트를 추가했다. 관련 테스트와 전체 테스트는 각각 출력 없이 300초 후 시간 초과되어 통과 여부를 판정하지 못함.
- build: 동일 원인 3회 실패 지침에 따라 debug APK 빌드는 실행하지 않음.
- PowerShell 직접 검증: `dart format lib\pages\home_page.dart lib\services\home_schedule_firestore_service.dart lib\utils\home_schedule_move_plan.dart lib\utils\home_schedule_tombstone_guard.dart test\home_schedule_move_plan_test.dart test\home_schedule_tombstone_guard_test.dart`; `flutter test test\home_schedule_tombstone_guard_test.dart test\home_schedule_move_plan_test.dart --no-pub -r expanded`; `flutter test --no-pub -r expanded`; `flutter analyze --no-pub`; `flutter build apk --debug --no-pub`; `git diff --check`.
- 수동 테스트: debug 로그의 `[MTF_SCHEDULE_MUTATION]`, `[MTF_SCHEDULE_STREAM]`, `[MTF_SCHEDULE_TOMBSTONE]`을 함께 수집한다. (1) 미확정 레슨 삭제 후 즉시/10초/30초/1분/3분 확인, (2) 09:00→10:00 및 월요일 09:00→화요일 10:00 이동, (3) 같은 레슨 2~3회 연속 이동, (4) 반복 레슨 한 회차/전체 이동, (5) 다른 주 이동 후 복귀, 백그라운드 복귀, 강제 종료 후 재실행, (6) 네트워크를 끊고 삭제/이동 후 재연결을 확인한다. 정상 기준은 source 서버 문서 부재, target 문서 정확히 1개, source 화면 재등장 없음, 실패 시 성공 토스트 없음이다.
- 남은 위험: 실제 기기 검증 전에는 완료로 판단하지 않는다. 기존에 내용이 다른 동일 시간 문서가 발견되면 자동 정리하지 않고 `unsafeTimeCollision` 로그의 실제 ID를 기준으로 사람이 데이터를 확인해야 한다. 서버 확인은 문서별 read를 사용하므로 대량 주간 삭제 시 추가 read 비용과 시간이 발생한다. 자동 format/test/analyze/APK 빌드는 미검증이며 `git diff --check`만 통과했다.
- 다음 권장 작업: 없음. BACKLOG 항목은 실제 기기 수동 검증 전까지 완료 처리하지 않았고 다음 백로그로 이동하지 않음.

## 2026-07-13 09:47 — 생년월일 formatter 및 홈 회원검색 개선
- 목표: 고객카드 생년월일 입력의 실시간 표시·8자리 제한을 복원하고, 홈 레슨 등록/수정 시트의 회원검색·안내 오버레이·7색 팔레트를 개선한다.
- 원인: 생년월일 formatter가 utils와 고객카드 로컬에 중복되어 있었지만 입력창에는 적용되지 않았고, formatter 표시 문자열을 축약 날짜로 재해석하지 못했다. 홈 추천은 `createdAt` 최신 30명만 조회했고 안내가 일반 Column에서 공간을 차지했으며 입력 변경마다 타이머를 재시작했다. 팔레트에는 green이 없었다.
- 수정 파일: `lib/pages/client_card_page.dart`, `lib/pages/home_page.dart`, `lib/utils/member_input_validation.dart`, `lib/widgets/home/lesson_editor/home_recent_members_section.dart`, `test/member_input_validation_test.dart`, `docs/agent/RUN_LOG.md`
- 실행 명령: 변경 Dart 파일 `dart format`, `flutter test test\member_input_validation_test.dart test\widget_test.dart --no-pub -r expanded`, `flutter test --no-pub -r expanded`, 관련 코드 검색, `git diff --check`
- analyze: 포맷·관련 테스트·전체 테스트에서 같은 무출력 정체가 3회 반복되어 지침에 따라 실행하지 않음.
- tests: 관련 테스트와 전체 테스트가 각각 출력 없이 300초 후 시간 초과되어 통과 여부를 판정하지 못함. 생년월일 단계별 표시, 8자리 제한, 점·슬래시 붙여넣기, 백스페이스, 축약 날짜 및 기존 유효성 사례를 보강함.
- build: 동일 원인 3회 실패 지침에 따라 debug APK 빌드는 실행하지 않음.
- 수동 테스트: (1) `20051111`, 초과 입력, 점·슬래시 붙여넣기, 백스페이스와 포커스 해제 정규화를 확인한다. (2) 최신/오래된/createdAt 없는 회원을 이름 전체·일부·초성·전화 뒤 4자리로 검색한다. (3) `phoneNormalized`, `phone`, `phoneDisplay` fallback과 삭제 회원 제외를 확인한다. (4) 동명이인의 전화 뒤 4자리와 총/잔여 회차가 구분되는지 확인한다. (5) 추천을 탭하기 전에는 memberId가 연결되지 않고 탭 후 연결 안내가 1.2초 표시되는지 확인한다. (6) 최초 이름 입력 탭 안내가 1.8초 한 번만 표시되고 결과 위치·시트 높이를 밀지 않으며 아래 레슨 종류 칩을 터치할 수 있는지 확인한다. (7) 키보드가 열린 상태에서 이름 입력 바로 아래, 메모 위에 결과가 보이는지 확인한다. (8) 7개 색상을 선택·저장·재진입하고 기존 저장 색상도 유지되는지 확인한다.
- 남은 위험: 전체 `members` snapshot을 한 번 구독해 클라이언트 검색하므로 회원 수가 비정상적으로 큰 센터에서는 읽기량과 메모리 사용을 관찰해야 한다. formatter 완료, analyze/test/APK 빌드와 실제 UI 수동 검증이 필요하다. `git diff --check`는 통과함.
- 다음 권장 작업: 없음. 다음 백로그로 이동하지 않음.

## 2026-07-13 07:07 — 홈 삭제 및 주간 위젯 시간 갱신 검증
- 목표: 기존 홈 레슨 삭제 방어와 Android 주간 위젯 시간 갱신 수정을 중복 적용하지 않고, 남은 원인만 보완한다.
- 원인: 홈 삭제는 snapshot binding/순번 검사와 서버 snapshot 확인 전까지 유지되는 tombstone이 이미 적용되어 있어 추가 결함을 찾지 못했다. 위젯은 30분·주차 알람이 inexact `setAndAllowWhileIdle`로 예약되어 절전 상태에서 경계 시각보다 늦을 수 있었고, 월요일 rollover는 다음 주 rows/blocks가 비어 있으면 조기 반환하여 이전 주 캐시와 active offset을 남겼다.
- 수정 파일: `lib/services/mtf_home_widget_service.dart`, `android/app/src/main/kotlin/com/example/mtf_app/MtfWidgetWeekRolloverReceiver.kt`, `docs/agent/RUN_LOG.md`
- 실행 명령: 관련 코드·호출 흐름 검색, 변경 Dart 파일 `dart format`, `flutter analyze --no-pub`, `flutter test --no-pub -r expanded`, `git diff --check`
- analyze: 출력 없이 300초 후 시간 초과하여 판정하지 못함.
- tests: 출력 없이 300초 후 시간 초과하여 판정하지 못함.
- build: 포맷·analyze·test가 동일하게 무출력 정체되어 같은 원인 3회 실패 지침에 따라 debug APK 빌드는 실행하지 않음.
- 수동 테스트: (1) 미확정 레슨을 삭제하고 즉시/10초/30초/1분 후, 페이지 재진입 및 앱 재시작 후에도 나타나지 않는지와 Firestore 문서 삭제를 확인한다. (2) 위젯 표시 종료시간 이후 다음 00분/30분 갱신 뒤 빨간 테두리가 없는지 확인한다. (3) 앱을 종료한 채 23:59→00:00을 지나 오늘 하이라이트가 새 요일로 이동하는지 확인한다. (4) 다음 주 일정이 빈 상태에서도 월요일 rollover 후 이전 주 일정이 남지 않는지 확인한다. (5) 기기 날짜·시간·시간대를 변경하고 재부팅한 뒤 위젯이 갱신되는지 확인한다. (6) 위젯 삭제·재추가 후 동일 항목을 확인한다.
- 남은 위험: 정확 알람 권한이 없는 기기는 기존 inexact 절전 허용 알람으로 fallback하므로 제조사 절전 정책에 따라 갱신이 늦을 수 있다. formatter/analyze/test/APK 빌드와 실제 기기 검증이 필요하다. `git diff --check`는 통과함.
- 다음 권장 작업: 없음. 다음 백로그로 이동하지 않음.

## 2026-07-12 16:59 — 고객카드 회원권 정지 상태 칩
- 목표: 회원권 정지 상태의 경과일과 예정 재개일을 각각 작은 칩으로 분리하고, 실제 정지 데이터가 있을 때만 표시한다.
- 원인: 기존 `_membershipPauseStatusText()`가 정지 경과일과 예정 재개일을 한 문장으로 합쳐 표시했다.
- 수정 파일: `lib/pages/client_card_page.dart`, `lib/utils/membership_pause_status_utils.dart`, `test/membership_pause_status_utils_test.dart`, `docs/agent/RUN_LOG.md`
- 실행 명령: 변경 Dart 파일 `dart format`, `flutter test test\membership_pause_status_utils_test.dart --no-pub -r expanded`, `flutter test --no-pub -r expanded`, 관련 표시·계약서 문구 검색, `git diff --check`
- analyze: 별도 실행하지 못함. formatter부터 Dart/Flutter 도구가 무출력 정체됨.
- tests: 관련 테스트와 전체 테스트가 각각 출력 없이 300초 후 시간 초과되어 통과 여부를 판정하지 못함. 정지 중+예정일 있음, 예정일 없음, 정지 데이터 없는 휴면회원, 재개 후 칩 제거 사례를 추가함.
- build: 동일한 무출력 환경 원인이 포맷·관련 테스트·전체 테스트에서 3회 반복되어 프로젝트 지침에 따라 APK debug 빌드는 실행하지 않고 중단함.
- 수동 테스트: 수행하지 않음.
- 남은 위험: `dart format`이 출력 없이 180초 후 시간 초과되어 formatter 완료를 확인하지 못했고, 테스트 및 APK 빌드 검증이 필요하다. `git diff --check`는 통과함.
- 다음 권장 작업: 없음. 다음 백로그로 이동하지 않음.

## 2026-07-12 16:27 — 고객카드 생년월일 입력 UX
- 목표: 입력 중 자동 변경을 없애고 포커스 해제·키보드 완료·저장 직전에만 4자리 연도 기반으로 생년월일을 정규화·검증한다.
- 원인: `_birthTextC.addListener(_autoFormatBirth)`가 6자리 숫자를 `YYMMDD`로 즉시 해석했고, 입력 formatter도 타이핑 도중 텍스트와 커서 위치를 변경했다.
- 수정 파일: `lib/pages/client_card_page.dart`, `lib/utils/member_input_validation.dart`, `test/member_input_validation_test.dart`, `docs/agent/RUN_LOG.md`
- 실행 명령: 변경 Dart 파일 `dart format`, `flutter test test\member_input_validation_test.dart --no-pub -r expanded`, `flutter test --no-pub -r expanded`, `flutter build apk --debug --no-pub`, 관련 listener/호출 경로 검색, `git diff --check`
- analyze: 별도 실행하지 못함. 관련 테스트 이전의 formatter 단계부터 Dart 도구가 무출력 정체됨.
- tests: 관련 테스트와 전체 테스트가 각각 출력 없이 300초 후 시간 초과되어 통과 여부를 판정하지 못함. 8자리, 6자리, 유일/모호한 7자리, 윤년, 존재하지 않는 날짜, 미래 날짜, 점·슬래시 구분자 사례를 추가함.
- build: APK debug 빌드가 출력 없이 300초 후 시간 초과되어 성공 여부를 판정하지 못함.
- 수동 테스트: 수행하지 않음.
- 남은 위험: `dart format`도 출력 없이 120초 후 시간 초과되어 formatter 완료를 확인하지 못했다. `git diff --check`는 통과했으나 테스트와 APK 빌드는 PowerShell에서 재검증이 필요하다.
- 다음 권장 작업: 없음. 동일한 실행 환경 정체가 포맷·관련 테스트·전체 테스트·빌드에서 반복되어 지침에 따라 중단하며, 다음 백로그로 이동하지 않음.

## 2026-07-12 16:04 — Cloud Functions 빌드 복구
- 목표: `functions/src/index.ts`의 Dart 혼입과 중복 TypeScript 구현을 최소 범위로 정리해 Functions TypeScript 빌드를 복구한다.
- 원인: 141~186행에 Dart 클라이언트 코드가 혼입되었고, 188~295행에 33~140행과 동일한 TypeScript 구현이 중복되어 있었다. 이를 제거한 뒤에는 기존 v1 콜백 구현이 v2 API로 해석되는 import 불일치와 미사용 템플릿 import 두 개가 컴파일을 차단했다.
- 수정 파일: `functions/src/index.ts`, `docs/agent/RUN_LOG.md`, `docs/agent/BACKLOG.md`
- 실행 명령: `npm.cmd run build` (Functions 폴더에서 2회), export 개수 및 Dart 혼입 문자열 확인, `git diff --check -- functions/src/index.ts`
- analyze: Flutter 소스 작업이 아니므로 실행하지 않음.
- tests: 별도 Functions 단위 테스트는 실행하지 않음.
- build: 1차 빌드는 Dart 구문 오류 해소 후 v1/v2 API 불일치 오류를 확인함. `firebase-functions/v1` 명시와 미사용 `onRequest`/`logger` import 제거 후 2차 `npm.cmd run build` 성공 (`tsc`, exit code 0).
- 수동 테스트: 배포 및 실제 Firebase 호출은 수행하지 않음.
- 남은 위험: 런타임 호출은 검증하지 않았다. `chargeOnce`, `cancelNoShow`, `lockConsent`, `unlockConsent` export는 각각 한 번씩 유지됨.
- 다음 권장 작업: 없음. 요청에 따라 다음 백로그 작업으로 이동하지 않음.

## 2026-07-12 15:50 — 기본 카운터 테스트 교체
- 목표: 현재 앱과 무관한 `Counter increments smoke test`를 Firebase·네트워크 없이 실행 가능한 회원 검색 단위 테스트로 교체한다.
- 원인: 기존 `test/widget_test.dart`가 `MyApp`을 띄워 숫자 `0`, `1`과 `+` 버튼을 검사하는 Flutter 기본 카운터 예제였다.
- 수정 파일: `test/widget_test.dart`, `docs/agent/RUN_LOG.md`, `docs/agent/BACKLOG.md`
- 실행 명령: `dart format test\widget_test.dart`, `flutter test test\widget_test.dart --no-pub -r expanded`
- analyze: 이번 요청 범위에 포함되지 않아 실행하지 않음.
- tests: 사용자가 PowerShell에서 `flutter test test\widget_test.dart --no-pub -r expanded`로 직접 검증했으며, 이름 일부, 한글 초성, 전화번호 숫자, 불일치 검색의 4개 테스트가 모두 통과함 (`All tests passed!`).
- build: 사용자가 현재 APK debug 빌드 성공을 확인했다고 제공함. 이번 작업에서는 다시 실행하지 않음.
- 수동 테스트: 수행하지 않음.
- 남은 위험: 없음. 사용자가 PowerShell에서 `dart format test\widget_test.dart`를 실행해 `Formatted 1 file (0 changed)`를 확인했고, 새 테스트 4개도 모두 통과함.
- 다음 권장 작업: 없음. 요청에 따라 다음 백로그 작업으로 이동하지 않음.

## 2026-07-11 17:15 — 읽기 전용 기준 상태 확인
- 목표: 소스 수정 없이 Git/Flutter/Functions 기준 상태를 확인한다.
- 원인: 현재 브랜치는 `main`이며 작업 트리에 다수의 기존 수정·삭제·추가 파일이 있어 깨끗한 복구 지점이 아니다. Functions 빌드는 `functions/src/index.ts`에 Dart 코드가 혼입되어 차단된다.
- 수정 파일: 소스 코드 수정 없음. 이 실행 기록(`docs/agent/RUN_LOG.md`)만 갱신.
- 실행 명령: `git branch --show-current`, `git status --short`, `flutter pub get`, `flutter analyze`, `flutter test`, `flutter build apk --debug`, `npm run build`, `npm.cmd run build`
- analyze: 180초 동안 출력 없이 시간 초과. 분석 오류 여부를 판정하지 못함.
- tests: 180초 동안 출력 없이 시간 초과. 테스트 통과 여부를 판정하지 못함.
- build: APK debug 빌드는 300초 동안 출력 없이 시간 초과. Functions는 PowerShell 실행 정책으로 `npm` 호출이 먼저 실패하여 `npm.cmd run build`로 재실행했고, TypeScript 컴파일 실패. 최초 오류는 `functions/src/index.ts:145:3 TS1435` (`final` 식별자)이며 147~186행 오류는 Dart 코드 혼입에 따른 연쇄 구문 오류.
- 수동 테스트: 수행하지 않음.
- 남은 위험: Flutter analyze/test/APK build가 공통적으로 무출력 정체되어 앱의 실제 컴파일 상태를 확인하지 못했다. 작업 트리에 기존 변경이 매우 많아 기준선 비교가 어렵다.
- 다음 권장 작업: P0 한 건으로 `functions/src/index.ts` 141행 이후에 혼입된 Dart 코드와 중복 TypeScript 구간의 경계를 확인하고, Dart 혼입부만 제거 또는 올바른 Dart 파일로 복원해 `npm.cmd run build`의 최초 구문 오류를 해소한다.

## YYYY-MM-DD HH:mm — 작업명
- 목표:
- 원인:
- 수정 파일:
- 실행 명령:
- analyze:
- tests:
- build:
- 수동 테스트:
- 남은 위험:
- 다음 권장 작업:

## 2026-07-18 — 닉네임 온보딩·마이페이지 AI FC 넛지·계정 연결 진입점

- 목표: anonymous/linked personal 사용자의 기존 닉네임 온보딩을 복구하고, 마이페이지에서 실제 서버 프로필의 미완성 항목을 한 번에 하나씩 안내하며, UID 유지 계정 연결 시트와 작은 고정 진입점을 제공한다.
- 시작 흐름: `ensureAnonymousSession → bootstrapAnonymousBeginnerProfile → trainer_profiles/{uid} 서버 조회 → nickname/onboardingCompleted 검사 → 기존 OnboardingPage → callable 성공 확인 → personal workspace 생성` 순서다. 온보딩 완료 전에는 personal Home stream/widget을 만들지 않는다. linked personal도 nickname이 없으면 동일 온보딩을 한 번 거치며, 관리자 선택·mustChangePassword·Debug legacy 분기는 유지했다.
- callable: Functions v1 `completeNicknameOnboarding`을 `asia-northeast3`, `maxInstances: 10` 공통 builder로 export했다. `context.auth.uid`만 사용하고 payload는 `nickname` 하나만 허용한다. trim 후 빈 값 또는 6자 초과를 `invalid-argument`로 거부하며, 기존 `trainer_profiles/{uid}`의 `trainerId/workspaceType/workspaceStatus/role` personal identity를 transaction에서 확인한다. 부모 문서가 없으면 `failed-precondition`이고 새 profile을 만들지 않는다.
- 허용 쓰기: `nickname`, `onboardingCompleted: true`, `onboardingCompletedAt`, `updatedAt`만 갱신한다. `profileCompleted`, `trainerProfileCompleted`, tier, 회원 수, account/provider/admin/legacy/workspace 필드는 쓰지 않는다. 최초 완료가 아닐 때는 `onboardingCompletedAt`을 update map에서 제외해 최초 서버 시각을 보존하고, 동일 nickname 재호출은 `completed: true, changed: false`로 안전하게 반환한다.
- Flutter 호출: `FirebasePersonalNicknameOnboardingGateway`가 중앙 `MtfFirebaseFunctions.call('completeNicknameOnboarding')`을 사용한다. UID를 payload에 넣지 않으며 callable 응답의 `completed == true`와 정규화 nickname 일치를 확인한 뒤에만 홈으로 전환한다. 실패 시 기존 OnboardingPage의 controller와 화면을 유지하고 성공 이동을 하지 않는다. 직접 Firestore profile update는 사용하지 않았다.
- 마이페이지 넛지: 서버 profile의 `displayName`, `phone`, `activityRegion`, `primaryActivity`, `affiliationType` 실제 값만 검사한다. nickname을 displayName fallback으로 세지 않는다. UID별 SharedPreferences에 직전 nudge key만 저장하고, 미완성 항목 순서에서 다음 항목을 골라 route 진입당 한 번만 기존 AIFC 말풍선 시트로 표시한다. `해당 항목 입력하기`는 기존 필드로 스크롤·포커스하고 `한 번에 완성하기`는 기존 선생님 정보 편집 카드로 이동한다.
- 계정 연결: anonymous이고 5개 정보가 모두 있으면 별도 AIFC 계정 연결 넛지를 표시하며, `계정 및 기록 / 익명으로 사용 중` 고정 설정 행에서도 같은 시트를 연다. 이메일은 기존 `linkWithCredential` 경로와 UID 일치 검사를 재사용한다. Google/Kakao는 실제 provider 패키지·연결 구현이 없어 disabled `준비 중`으로 표시하며 성공을 가장하지 않는다. 실제 연결을 위해 각 provider SDK/Flutter 패키지, Firebase Auth provider 설정, provider credential을 현재 anonymous user에 link하는 구현이 후속으로 필요하다.
- 수정 파일: `functions/src/index.ts`, `functions/src/profile_bootstrap.ts`, `lib/pages/account_gate.dart`, `lib/pages/onboarding_page.dart`, `lib/pages/personal_my_page.dart`, `lib/services/personal_profile_start_reader.dart`, `lib/services/personal_my_page_nudge_service.dart`, `lib/services/managed_member_workspace_service.dart`, 관련 Flutter 테스트 4개, `firebase-emulator-tests/nickname_onboarding.test.cjs`, `firebase-emulator-tests/functions_client.cjs`, `firebase.nickname-emulator.json`, 루트 `package.json`, 본 문서와 `BACKLOG.md`.
- Functions 검증: `npm.cmd --prefix functions run lint`, `npm.cmd --prefix functions run build` 모두 성공. 기존 실기기용 Emulator 포트가 사용 중이어서 별도 9198/8180/5101 포트의 demo project로 실행했고, 비인증·uid payload·빈 nickname·anonymous/linked 자기 문서·부모 없음·보호 필드 유지·타임스탬프 최초 1회·멱등 재호출·다른 UID 무변경 10개 시나리오가 모두 통과했다.
- Flutter 검증: 관련 온보딩·마이페이지·관리자·Debug legacy 테스트 51개 통과. 전체 `flutter test --no-pub -r expanded` 203개 통과. 변경 범위 analyze는 error/warning 없이 기존 OnboardingPage의 `withOpacity` deprecated info 3건만 남았다.
- 전체 analyze: `flutter analyze --no-pub`는 루트 로컬 Firebase 도구의 `node_modules/firebase-tools/templates/init/functions/dart/server.dart`를 앱 Dart 소스로 분석해 외부 템플릿의 URI/심볼 6개 오류와 기존 누적 경고를 포함한 1197 issues로 실패했다. 이번 범위 오류는 아니며 analyzer 제외 설정은 요청 범위 밖이라 수정하지 않았다.
- APK: Debug `app-debug.apk`, Profile `app-profile.apk`(179.9 MB), Release `app-release.apk`(109.6 MB) 모두 빌드 성공했다. Release R8/ML Kit 회귀도 통과했다.
- diff/Rules/배포: `git diff --check` 통과. 이번 작업에서 `firestore.rules`, `storage.rules`를 수정하지 않았고 익명 client update 권한을 열지 않았다. 실제 Firebase 배포와 운영 데이터 변경은 실행하지 않았다.
- 선택 배포 명령(미실행): `npx.cmd firebase deploy --only functions:completeNicknameOnboarding --project more-than-fitness-f6adb`
- 남은 위험: callable은 로컬 Emulator에서 검증됐지만 실제 프로젝트에는 아직 배포되지 않아 배포 전 APK에서는 닉네임 저장 호출이 `not-found`로 실패한다. 실제 배포 후 anonymous/linked 실기기 온보딩과 provider별 계정 표시를 재검증해야 한다. Google/Kakao 실제 연결은 준비되지 않았다.
- 다음 권장 작업: 위 선택 배포와 실제 기기 검증은 별도 승인 작업으로 남긴다. 다른 백로그로 이동하지 않는다.

### 2026-07-18 추가 — 내부 nickname 정책 확정

- 현재 `completeNicknameOnboarding`의 nickname은 trim 후 1~6자만 허용한다. 사용자 간 중복과 동일 닉네임 재저장을 허용하며 계정 ID·공개 식별자·provider 표시 이름으로 사용하지 않는다. 저장값에는 `님`을 붙이지 않고 기존 UI label helper가 호칭을 처리한다.
- 온보딩 TextField도 6자로 제한해 서버 검증과 일치시켰다. 공개 활동명, 전역 고유성, 흔한 이름 예약, 회원 표시 이름 선택, 충돌 문구와 대체 후보는 구현하지 않았다.
- 회원 앱 연동 단계의 `publicDisplayName` 설계를 `BACKLOG.md`에 별도 항목으로 기록했다. Google/Kakao/email은 로그인 provider일 뿐 공개 이름으로 사용하지 않는 원칙을 포함했다.
- 추가 검증: Functions lint/build 성공, 별도 demo project Emulator의 닉네임 callable 11개 시나리오 성공(7자 거부 포함), 관련 Flutter 테스트 24개와 전체 Flutter 테스트 204개 성공, Debug/Profile APK 빌드 성공, `git diff --check` 성공이다. 변경 범위 analyze는 error/warning 없이 기존 `withOpacity` deprecated info 3건만 보고했다.
- Release APK 재검증은 컴파일 오류 출력 없이 5분과 10분 실행 제한에 각각 도달해 이번 추가 정책 반영 뒤 결과를 확정하지 못했다. 직전 본 작업의 Release APK 성공 결과를 이번 재실행 성공으로 대체하거나 추측하지 않는다.
## 2026-07-15 22:10 — Legacy Admin workspace 접근

- 목표: 비익명 사용자 중 `platformAdmin == true`와 `legacyDataAccessApproved == true` 두 Custom Claim이 모두 있고 최초 비밀번호 변경을 마친 계정만 기존 개발 데이터 workspace에 접근하도록 진입 경로와 Rules를 복구했다.
- 감사 결과: `trainer_profile/me`, `members`와 회원 하위 컬렉션, `member_groups`, `schedules`, `training_logs/anatomyRecords`, `contracts`, `contractCounters`, `sign_requests`, `lesson_products`, 알림 queue, More Care 경로 및 네 Storage 이미지 경로를 확인해 `LEGACY_WORKSPACE_ACCESS_AUDIT.md`에 caller·write/delete·제한을 기록했다.
- claim 조건: 이메일·표시 이름·profile role을 사용하지 않는다. UI는 force-refreshed ID token의 두 claim을 확인하고, Rules는 비익명·두 claim·`trainer_profiles/{uid}.mustChangePassword != true`를 모두 확인한다.
- workspace 분리: `AppWorkspaceMode.guest/linkedPersonal/legacyAdmin`과 scope를 추가했다. legacy 앱은 `기존 개발 데이터` 표시가 있는 shell에서 실행하며 개인 작업공간 전환 시 legacy child tree를 폐기한다. legacy profile 상태만으로는 진입하지 않는다.
- Firestore 범위: 감사된 legacy root와 회원 하위 collection만 명시적으로 허용했다. `workspaceType == personal` canonical 회원은 legacy admin에게도 노출하지 않는다. `trainer_profiles/{uid}` owner 정책은 유지했다. broad wildcard는 추가하지 않았다.
- Storage 범위: `member_profiles` JPEG 10 MiB, `member_inbody` JPEG 15 MiB, `membership_contract_signatures` PNG 10 MiB, `membership_contract_images` PNG 10 MiB만 두 claim 계정에 허용했다. 미감사 영상·PDF·임의 경로는 거부한다.
- 데이터 미변경 근거: Admin SDK 데이터 쓰기, 실제 Firebase 연결, migration, `trainerId`/`ownerId` backfill, 문서 복사·ID 변경을 실행하지 않았다. Rules·UI·로컬 demo test와 문서만 변경했다.
- Emulator: 첫 실행은 PATH에 Java가 없어 기동 실패했다. Android Studio JBR을 PATH에 지정해 재실행했고, 최초 Rules 테스트에서 legacy 회원의 누락 가능한 `membership` 필드를 직접 읽는 오류를 발견해 field existence 검사로 수정했다. 이후 demo project `demo-mtf-legacy-admin`에서 Auth·Firestore·Functions·Storage 28개 시나리오가 모두 통과했다. 비로그인/anonymous/일반 Linked/단일 claim 거부, 두 claim read/write, Firestore와 Storage의 mustChange 차단, claim 제거 차단, canonical 정책 유지, sign_requests 공개 거부, 하위 collection, hard delete 범위, Storage MIME·경로·파일명 제한을 확인했다.
- 원격서명: `re_registration_requests` 비로그인 쓰기와 `sign_requests` 공개 읽기를 새로 열지 않았다. 현재 공개 원격서명 흐름은 권한 거부될 수 있으며 별도 보안 설계가 필요하다.
- 도구 환경: Node `v22.20.0`, `firebase-tools 15.23.0`, `@firebase/rules-unit-testing 5.0.1`, Android Studio 내장 OpenJDK `21.0.7`을 사용했다. Node 22와 설치된 Firebase 도구로 demo Emulator가 정상 기동·완료됐다. `functions/package.json` 의존성은 변경하지 않았다. 실제 Firebase deploy와 실제 관리자 계정 생성은 수행하지 않았다.
- format: 변경 Dart 5개를 SDK `dart format`으로 실행해 3개가 정리됐고 이후 변경 없음 상태다.
- 관련 Flutter 테스트: 계정 gate·관리자 비밀번호 테스트 31개 통과.
- 전체 Flutter 테스트: `flutter test --no-pub -r expanded`, 136개 모두 통과.
- analyze: 전체 `flutter analyze --no-pub`는 루트 로컬 테스트용 `node_modules/firebase-tools/templates/init/functions/dart/server.dart`까지 분석해 외부 템플릿의 `firebase_functions` URI 미존재 등 6개 error와 기존 누적 경고로 실패했다(1197 issues). 이번 변경 파일 5개 범위 분석은 `No issues found`로 통과했다. 범위 밖 analyzer 설정이나 node_modules는 수정하지 않았다.
- Functions build: `functions`에서 `npm.cmd run build` 통과(`tsc`, exit 0).
- APK: `flutter build apk --debug --no-pub` 통과, `build/app/outputs/flutter-apk/app-debug.apk` 생성.
- diff: `git diff --check` 통과. 줄바꿈 변환 예정 경고만 있으며 whitespace 오류는 없다.
- 남은 위험: 실제 legacy 문서 필드 분포·건수와 기존 download URL 노출은 운영 데이터 없이 검증하지 않았다. 실제 활성화 절차는 `LEGACY_ADMIN_ACTIVATION.md`에 기록했다.
- 다음 백로그: 이동하지 않음.

## 2026-07-15 — Debug 전용 기존 개발 데이터 긴급 접근

- 목표: Debug 빌드의 Guest 시작 화면에서만 로그인·profile bootstrap·최초 비밀번호 변경·관리자 claim gate를 거치지 않고 기존 legacy `HomePage`를 직접 열 수 있게 했다.
- 원인: 기존 `AppAccountGate`는 미로그인 사용자를 Guest 화면에 고정하고, 로그인 후에도 profile bootstrap과 claim gate를 통과해야 `SplashRouter`에 도달했다. `SplashRouter`도 `trainer_profile/me`를 먼저 조회하므로 즉시 legacy 홈을 열 수 없었다.
- 수정 파일: `lib/pages/account_gate.dart`, `lib/pages/guest_start_page.dart`, `lib/pages/debug_legacy_workspace_shell.dart`, `lib/services/app_workspace_mode.dart`, `test/debug_legacy_direct_access_test.dart`, `docs/agent/DEBUG_LEGACY_ACCESS.md`, `docs/agent/AUTH_ACCOUNT_POLICY.md`, `docs/agent/BACKLOG.md`, `docs/agent/RUN_LOG.md`.
- 진입과 gate 범위: `kDebugMode`에서만 `기존 개발 데이터 열기` 버튼을 만들고, 선택하면 메모리 상태의 `AppWorkspaceMode.legacyDeveloper`로 전환한다. 이 분기는 인증 상태 stream보다 먼저 기존 `HomePage`를 직접 만들어 profile bootstrap, `mustChangePassword`, `platformAdmin`, `legacyDataAccessApproved` 확인을 호출하지 않는다. Guest/Linked/legacyAdmin의 기존 흐름은 변경하지 않았다.
- 데이터 격리: 기존 `HomePage`와 그 legacy query/write를 그대로 사용한다. Guest 로컬 일정이나 Linked personal repository를 전달하지 않고, owner-scoped 변환·문서 복사·ID 변경·`trainerId`/`ownerId` backfill을 추가하지 않았다. 종료 버튼은 legacy child tree를 폐기하고 Guest 시작 화면으로 돌아가며 선택 상태는 저장하지 않는다.
- Release 차단: 버튼 렌더링, callback 전달, 직접 HomePage 분기를 모두 `kDebugMode`로 제한했다. 별도 route, deep link, 영구 preference, 이메일 예외 또는 client claim 설정은 없다. Debug APK의 `kernel_blob.bin`에는 버튼 문구가 3회 존재하고 Profile APK의 `libapp.so`에는 0회임을 확인했다.
- format: 변경 Dart 파일 5개에 `dart format` 실행, 1개 정리 후 완료.
- 관련 테스트: `flutter test test/debug_legacy_direct_access_test.dart test/app_account_foundation_test.dart test/platform_admin_password_change_test.dart --no-pub -r expanded` 성공, 총 35개 통과. Debug 버튼, callback 부재 시 미표시, profile/claim gateway 0회, `legacyDeveloper` mode, 복귀 후 child 폐기와 기존 Guest/Linked/관리자 gate 회귀를 확인했다.
- analyze: 변경 Dart와 테스트 5개 범위 `flutter analyze --no-pub ...`에서 `No issues found`로 통과했다.
- 전체 테스트: `flutter test --no-pub -r expanded` 성공, 총 140개 통과.
- Debug build: `flutter build apk --debug --no-pub` 성공, `build/app/outputs/flutter-apk/app-debug.apk` 생성.
- Profile build: 명령 실행 제한 시간을 약 7초 넘겼지만 Gradle 출력과 파일 존재를 통해 `build/app/outputs/flutter-apk/app-profile.apk` 생성 완료를 확인했다. Profile `libapp.so`에서 `기존 개발 데이터 열기` 문구가 검색되지 않았다.
- Release build: `flutter build apk --release --no-pub`는 기존 `google_mlkit_text_recognition`의 중국어·일본어·한국어·데바나가리 recognizer class 누락으로 `minifyReleaseWithR8`에서 실패했다. 이번 작업 범위 밖 의존성/keep rule은 수정하지 않았으며 Release 산출물 미노출 확인은 미검증이다.
- 데이터/배포: Firestore Rules, Storage Rules, Functions, 관리자 계정, claim, Firebase 배포와 운영 데이터는 수정하지 않았다. Functions lint/build도 실행하지 않았다.
- 남은 위험: 현재 저장소 Rules는 비익명 관리자 claim을 요구하므로 동일 Rules가 실제 프로젝트에 배포되어 있다면 미로그인 Debug 화면에서 legacy 읽기·쓰기는 `permission-denied`가 된다. 실제 Firebase 권한과 회원·일정·레슨일지·계약 CRUD를 검증하지 않았으며 성공으로 기록하지 않는다.
- 다음 백로그: 이동하지 않음.
# 2026-07-18 — personal 최초 준비 화면과 실제 HomePage 연결

- 기존 분기 감사: 일반 personal 시작점이 `PersonalWorkspaceReadyPage`였고, 이전 수정에서 이 화면을 별도 주간 스케줄 홈으로 바꿨다. 이는 사용자가 요구한 실제 `lib/pages/home_page.dart`의 `HomePage` 재사용 의도와 달랐다.
- route 교정: `ensureAnonymousSession → bootstrapAnonymousBeginnerProfile → profile read → 준비 화면 → nickname 미완료 시 OnboardingPage / 완료 시 HomePage(personalOwnerUid: currentUid)`로 연결했다. `PersonalWorkspaceReadyPage`는 정상 personal 시작 목적지에서 제거했으며, 추가했던 주간 탭/시간표 셸도 되돌렸다.
- UID 연결: personal `HomePage`의 회원·일정 query는 `trainerId == currentUid`, `workspaceType == personal` 조건을 사용한다. 프로필은 `trainer_profiles/{currentUid}`를 읽고, 일정 생성·수정·이동·삭제·다중 저장·복사 경로에는 owner UID를 전달한다. 신규 personal 일정 문서 ID는 UID 접두어로 다른 trainer의 같은 시간 일정과 충돌하지 않게 했다.
- legacy 분리: `personalOwnerUid`가 없는 관리자/Debug legacy `HomePage`는 기존 legacy 경로를 그대로 사용한다. legacy 데이터에 trainerId를 추가하거나 personal UID로 이동하지 않았다.
- 마이페이지: 홈 햄버거 메뉴는 기존 `lib/pages/my_page.dart`의 `MyPage(personalOwnerUid: currentUid)`를 연다. 기존 명함 UI는 유지하고 personal 프로필 읽기·핵심 프로필 저장 및 서버 tier/count 조회를 UID 범위로 연결했다.
- 준비 화면: `account_gate.dart`의 `_PersonalStartProgress`를 stateful 화면으로 변경했다. 배경과 상태바·하단 시스템 영역은 Onboarding의 `kOnboardingBg`(`0xFFF3F4F6`)를 재사용한다. 홈 헤더와 같은 `AifcAvatar`를 92px로, 기존 `AifcTypingDots`를 그대로 사용하며 CircularProgressIndicator와 고정 대기 문구를 제거했다.
- 문구: 역할형 3개를 가중 목록에서 50%, 브랜드형 3개 25%, 귀여운 문구 4개 25% 비중으로 고른다. 직전 문장과 같은 후보는 제외한다. bootstrap이 1.6초 이상일 때만 320ms fade로 다음 한 문장으로 바꾸고 완료를 위한 인위적 지연은 없다. periodic timer는 dispose에서 취소한다.
- 로그: 일반 personal에서 `[MTF_APP_START] destination=canonicalHome`, `canonicalHome=home_page.dart`, `workspaceType=personal`을 안전하게 남긴다. 관리자·mustChangePassword·Debug legacy 분기는 변경하지 않았다.
- 수정 파일: `lib/pages/account_gate.dart`, `lib/pages/home_page.dart`, `lib/pages/client_list_page.dart`, `lib/pages/my_page.dart`, `lib/pages/personal_workspace_ready_page.dart`, `lib/services/home_member_lookup_service.dart`, `lib/services/home_schedule_firestore_service.dart`, `test/app_account_foundation_test.dart`, `test/managed_member_workspace_test.dart`, 본 문서, `BACKLOG.md`, `DECISIONS.md`.
- 검증: 변경 Dart 파일 format 완료. canonical Home 및 personal 회원 화면 최종 관련 테스트 33개 통과(관리자·Debug legacy를 포함한 앞선 관련 묶음 43개도 통과), 전체 `flutter test --no-pub -r expanded` 206개 통과. 변경 범위 analyze는 신규 `error` 0건이며 기존 warning/info 151건 때문에 종료 코드 1이다. Debug APK와 Profile APK 빌드 성공. `git diff --check`는 공백 오류 없이 통과했고 기존 파일의 LF→CRLF 안내만 출력됐다.
- 제외/남은 위험: Functions, Firestore Rules, 등급 계산, 회원 수 정책, Firebase 배포는 수정하거나 실행하지 않았다. Home/MyPage의 오래된 일부 보조 화면에는 legacy 직접 경로가 남아 있어 personal 실제 기기 전체 동선 검증이 필요하며, 권한이 거부되는 경로를 저장 성공으로 기록하지 않는다.

## 2026-07-18 — 모어댄 브랜드·personal 준비 화면·Home FC/MORE 센스·공통 네온

- 브랜드 적용 위치: 앱 표시 이름을 Android manifest, iOS display/bundle name, web manifest, Flutter 앱 title에서 `모어댄`으로 통일했다. 설정·마이페이지·회원 서명 화면·Guest 시작 화면의 사용자 노출 브랜드도 `모어댄` 또는 보조 영문 `MORE THAN`으로 정리했다. Android applicationId, iOS bundle identifier, Firebase project 설정은 변경하지 않았다.
- 유지한 업무 문구: 계약서의 센터명 기본값 `MORE THAN FITNESS`는 실제 계약·센터 문맥이므로 유지했다. 개인정보·약관·계약 정책 문구를 일괄 치환하지 않았다.
- 준비 화면 구현: `lib/pages/account_gate.dart`의 `_PersonalStartProgress`를 사용했다. `모어댄`을 34px 주 브랜드, `MORE THAN`을 11px 보조 브랜드로 고정하고, 기존 `AifcAvatar` 68px와 2줄 이내 메시지·타이핑 점을 가로형으로 배치했다. 역할형 50%·브랜드형 25%·귀여운 문구 25%, 직전 문구 제외, 1.6초 이상 소요 시 320ms fade, dispose 시 timer 취소 규칙을 유지했다. 실제 bootstrap 완료를 인위적으로 지연하지 않는다.
- Home 인사/FC 선택 규칙: `HomeHeaderMessageEngine` 순수 로직을 추가해 시간대별 짧은 인사와 닉네임 `님` 중복 방지, 주말·식사 시간·실제 오늘 레슨의 첫/다음/마지막/완료 상태·실제 공백·실제 MORE 센스 이벤트를 후보로 사용한다. 같은 날짜와 홈 진입 회차에서는 stable key로 문구를 고정하고, 재진입 시 다시 선택할 수 있다. 최근 5개 key와 날짜별 질문 노출 key는 `SharedPreferences`에 owner 범위로 보관하며 Firestore에 쓰지 않는다.
- MORE 센스 중복 방지: FC가 특정 회원 이벤트를 사용한 경우 같은 event key는 확장 영역 후보에서 제외한다. 확장 영역은 실제 생일·회원권 만료·다음 MORE day·기념일·잔여회차 이벤트 중 다른 한 건만 한 줄로 표시하고, 이벤트가 없으면 0건 상태를 표시한다.
- 날씨 범위: 저장소에 검증된 위치·날씨 provider/API가 없어 날씨 사실을 생성하지 않았다. 엔진에는 nullable `HomeWeatherContext` 입력점만 두었고 현재 호출에서는 비활성이다. 실제 provider와 동의·오류 정책이 정해진 뒤 별도 작업으로 연결한다.
- 공통 네온: 기존 `MtfHeaderNeonOverlay` 하나를 source of truth로 확장해 Home, 마이페이지, 회원관리, 레슨일지, 계약서, 운영통계의 큰 브랜드 헤더에만 적용했다. AppBar·일반 카드에는 적용하지 않았다. Home은 기존 강조도 1.0, 나머지는 0.52와 얇은 선을 사용했다. 진입 애니메이션은 1회 종료되고, 확장/축소 전환 뒤 ticker가 남지 않으며, `disableAnimations` 또는 비활성 TickerMode에서는 정적 헤더만 렌더링한다.
- 기존 구조 유지: 일반 personal은 계속 `HomePage(personalOwnerUid: currentUid)`로, 햄버거 메뉴는 기존 `MyPage(personalOwnerUid: currentUid)`로 진입한다. 관리자·mustChangePassword·Debug legacy 분기와 UID owner query/mutation 경계를 변경하지 않았다.
- 수정 파일: `lib/main.dart`, 플랫폼 표시 이름 파일 3개, `lib/pages/account_gate.dart`, `lib/pages/home_page.dart`, 브랜드 노출 페이지 6개, 주요 헤더 페이지 4개, `lib/widgets/home/sections/home_header_section.dart`, `lib/widgets/mtf_header_neon_overlay.dart`, 신규 엔진·로컬 history·route observer 3개, 관련 테스트 3개, 본 문서와 `BACKLOG.md`.
- 테스트: 준비 화면·계정·Guest 묶음 32개, 엔진·계정 묶음 34개, 네온 포함 관련 묶음 43개가 통과했다. 전체 `flutter test --no-pub -r expanded`는 기능 구현 완료 상태에서 217개 모두 통과했다. 이후 표시 라벨 `MORE센스`를 `MORE 센스`로 정리한 뒤 전체 및 관련 테스트를 재실행했으나 Flutter 도구가 출력 없이 각각 240초를 초과해 종료되어, 이 최종 표기 상태의 재실행은 미검증으로 구분한다.
- analyze/build/diff: 변경 범위 analyze에서 신규 error는 0건이며 저장소 기존 warning/info가 남아 있다. Debug APK, Profile APK, Release APK 빌드가 모두 성공했다(`app-debug.apk`, `app-profile.apk`, `app-release.apk`). `git diff --check`는 whitespace 오류 없이 통과했고 기존 줄바꿈 변환 안내만 출력됐다.
- 남은 확인: 실제 Android 기기에서 준비 화면의 2줄 overflow, Home·각 주요 화면 네온의 밝기/프레임, 앱 재진입 문구 교체, MORE 센스 실제 이벤트 연결을 육안 확인해야 한다. 날씨 provider 연결도 후속 작업이다. Flutter 도구 정체가 해소된 환경에서 최종 표기 상태의 테스트를 다시 실행해야 한다. 실제 기기 확인 전 해당 항목을 검증 완료로 기록하지 않는다.
- 배포/범위: 이번 작업에서 Functions, Firestore Rules, Storage Rules, 운영 데이터와 Firebase 배포를 수정하거나 실행하지 않았다. 다음 백로그로 이동하지 않았다.

## 2026-07-19 — personal 온보딩·Home 인사·헤더 통계·MyPage UID 격리

- 현재 테스트 UID 확인: 연결된 Android 기기가 없어(`adb devices` 결과 0대) 실제 기기에서 현재 Firebase UID와 신규/기존 여부를 이번 실행에서 확인하지 못했다. Unit/widget test의 `anonymous-uid-1` 등은 fixture이므로 실제 UID로 보고하지 않는다. Debug 실행 시 `[MTF_PERSONAL_IDENTITY]`에 현재 Auth UID, `isAnonymous`, profile 존재와 `trainer_profiles/{uid}` 출처를 남기고, MyPage는 `[MTF_MY_PAGE_IDENTITY]`에 같은 UID·문서 존재·값이 있는 필드 이름만 남긴다. 전화번호 등 필드 값은 로그에 출력하지 않는다.
- 온보딩 분기: `PersonalProfileStartResult.needsNicknameOnboarding`은 nickname이 비어 있거나 `onboardingCompleted != true`이면 기존 `OnboardingPage`를 표시한다. 두 조건이 모두 준비됐을 때만 건너뛰며 tier·Beginner·회원 수는 참조하지 않는다. 기존 `만나서 반가워요.` → `제가 어떻게 불러드릴까요?` → 1~6자 callable 저장 → `HomePage(personalOwnerUid: uid)` 경로를 변경하지 않았다.
- Home `강사님` 원인: `HomePage._bannerTrainerName` 초기값과 personal 빈 profile fallback이 `강사님`이었고, header도 빈 이름을 `강사님`으로 바꿨다. personal에서는 초기값을 빈 문자열로 두고 `trainer_profiles/{uid}.nickname`을 `displayName/name`보다 우선한다. nickname 준비 전에는 이름 없는 `안녕하세요`만 표시하며 저장값이 `님`으로 끝나면 기존 정규화로 `님님`을 막는다.
- 자동/고정 인사: 기존 전역 `home_header_custom_greeting_v1`을 personal에서 사용하지 않고 `home_header_custom_greeting_v1_personal_{uid}`로 분리했다. 과거 기본값 `안녕하세요 강사님`, 쉼표·느낌표 변형 네 가지는 고정 문구로 인정하지 않고 자동 모드로 처리한다. 그 밖에 사용자가 명시적으로 저장한 문구는 같은 UID에서 자동 인사보다 우선하며 legacy는 기존 전역 key를 유지한다.
- 헤더 통계: `오늘`, `MORE 센스`, `이번 주`를 모두 `Expanded(flex: 1)`로 유지하고 실제 카드에 검증 key를 붙였다. 카드 외곽 너비·padding·radius·탭 영역은 동일하며 라벨은 공통 18px 한 줄 영역과 `FittedBox(scaleDown)`을 사용해 작은 화면과 1.8배 text scale에서도 세 카드의 너비와 높이가 같다. 표기는 `MORE 센스`를 유지했다.
- MyPage 노출 원인: `MyPage._loadProfile()`이 `personalOwnerUid` 존재 여부와 무관하게 `trainer_profile/me`를 직접 읽은 것이 과거 명함·전화번호·지역 등의 정확한 노출 원인이었다. personal은 이제 `trainer_profiles/{personalOwnerUid}`만 읽고 legacy는 기존 `trainer_profile/me`를 유지한다. Firestore에 빈 값을 쓰거나 기존 문서를 삭제·이동하지 않았다.
- MyPage 로컬/하위 경계: AI FC 프로필 넛지 진행 key를 personal UID별로 분리해 과거 전역 SharedPreferences 진행 상태를 신규 UID가 상속하지 않게 했다. legacy `trainer_profile/me`와 전역 상품을 직접 읽는 월 목표·상품 관리 하위 위젯은 personal MyPage에서 생성하지 않고 legacy에서만 유지한다. 동일 UID의 기존 canonical profile 값은 그대로 읽으므로 onboarding만 다시 연 경우 기존 정보가 삭제되지 않는다.
- 멤버십과 명함: 상단 `이용 중인 멤버십`과 서버 권위 tier 칩은 유지했다. 그 옆에 중복 표시되던 `명함 Semi-Pro` 보조 칩과 사용되지 않던 `_MyProChip`은 제거했다. 명함 본문의 이름·전문 분야·지역·사진 예정 영역은 기존 정렬을 유지했고 사진 편집 기능은 추가하지 않았다.
- 수정 파일: `lib/pages/account_gate.dart`, `lib/pages/home_page.dart`, `lib/pages/my_page.dart`, `lib/widgets/home/sections/home_header_section.dart`, `lib/widgets/home/sections/home_header_stat_card.dart`, 신규 `test/home_header_personal_identity_test.dart`, 본 문서와 `BACKLOG.md`.
- 검증: 변경 Dart format 완료. 전용 테스트 7개 통과, Home·MyPage·온보딩·관리자·Debug legacy 관련 묶음 59개 통과, 전체 `flutter test --no-pub -r expanded` 224개 통과. 변경 범위 analyze는 신규 error 0건이고 기존 warning/info 123건을 유지했다. Debug APK 성공(176.1초), Profile APK 성공(507.1초), Release APK는 첫 실행 20분 제한 종료 후 기존 산출물 시각이 갱신되지 않아 실패로 구분했고 두 번째 실행이 90.1초에 성공해 새 `app-release.apk`를 생성했다. `git diff --check`는 whitespace 오류 없이 통과했다.
- 범위/남은 확인: Functions, Firestore Rules, Storage Rules, 등급·회원 수 계산, Firebase 배포, 운영 데이터는 수정하지 않았다. 실제 Android 기기에서 Debug identity 로그로 UID와 신규/기존 여부, nickname 저장 직후 첫 Home 인사, 두 UID의 MyPage 격리, 명함 레이아웃을 확인해야 한다. 다음 백로그로 이동하지 않았다.
## 2026-07-19 — personal 닉네임 온보딩·Home 인사·최근 회원 UID 격리·시간표 기본 범위

- 목표: 기존 canonical `HomePage(personalOwnerUid: currentUid)`와 햄버거 `MyPage` 경로를 유지하면서 닉네임 진입 조건, Home 2줄 인사, 최근 회원 격리, 신규 시간표 기본 범위만 보완했다.
- 온보딩 감사: 시작 판정의 source of truth는 `trainer_profiles/{currentUid}`의 `nickname`과 `onboardingCompleted`다. `realName`, `trainerName`, legacy `trainer_profile/me`, tier와 회원 수는 판정에 사용하지 않는다. 온보딩 완료 직후에는 임시 문자열 `saved`로 통과하던 코드를 제거하고 callable 저장이 성공한 실제 입력 nickname을 세션 결과에 유지한 뒤에만 Home을 생성한다. anonymous/linked personal 모두 같은 조건을 사용한다.
- 기존 건너뛰기 원인과 `김트` 출처: 현재 코드에서 Onboarding을 건너뛸 수 있는 조건은 현재 UID 프로필의 `nickname`이 비어 있지 않고 `onboardingCompleted == true`인 경우뿐이다. Home의 표시 경로는 `trainer_profiles/{currentUid}.nickname` → `_bannerTrainerName` → `HomeHeaderSection.profileDisplayName`이다. 따라서 현재 코드에서 `김트`가 표시됐다면 직접 출처는 현재 UID 프로필의 `nickname` 필드다. 이번 환경에서는 실제 기기/Firestore 문서 값을 조회하지 않았으므로 해당 UID가 신규인지, 기존 UID를 재사용했는지는 확정하지 않았다.
- Home 인사: 첫 줄은 자동 시간대 문구 또는 UID 범위 사용자 고정 문구를 13.5px/700으로, 둘째 줄은 현재 nickname + `님`을 19px/900으로 표시한다. nickname이 이미 `님`으로 끝나면 추가하지 않는다. 사용자가 저장한 문구가 nickname을 직접 포함한 완전 고정 문구이면 기존 한 문구로 보존하고 중복 둘째 줄을 만들지 않는다. nickname이 비어 있으면 `강사`, `김트` 같은 fallback 없이 둘째 줄을 만들지 않는다.
- Home 최근 회원 실제 원인: `HomeRecentClientsSection`이 `members` 전체를 `createdAt`순으로 직접 구독하고 있었다. personal에서는 이제 `trainerId == currentUid`와 `workspaceType == personal` 쿼리를 사용하고, 수신 문서도 같은 owner 조건으로 재검증한다. createdAt 없는 문서 호환을 위해 정렬은 snapshot 수신 후 수행한다.
- 레슨 등록 최근 회원 실제 원인: `HomeRecentMembersSection`이 `static` 전역 `members` stream을 사용했다. 이를 인스턴스별 owner query로 교체해 UID 전환 뒤 이전 stream을 재사용하지 않는다. 검색·삭제 제외·최대 5명·칩을 탭한 경우에만 연결하는 동작은 유지했다.
- 로컬 최근 회원 감사: Home과 레슨 편집 최근 회원은 SharedPreferences memberId 목록을 사용하지 않고 Firestore createdAt/search 결과를 사용한다. 따라서 stale 전역 recent-member key의 migration이나 삭제는 하지 않았다.
- 회원카드 이동: Home 최근 회원을 누르면 `members/{memberId}`를 다시 읽고 현재 UID의 `trainerId`, `workspaceType == personal`, 삭제 상태를 확인한 뒤에만 `ClientCardPage`를 연다. 불일치·stale ID·조회 실패는 이동을 차단한다. `[MTF_RECENT_MEMBER]` 로그에 uid, workspace, source, candidateCount, validatedCount, ownerValidated를 남긴다. Debug legacy는 owner UID가 없는 기존 경로를 유지한다.
- 현상 판정: 과거 회원 노출은 전체 collection/static stream을 사용한 실제 격리 버그였다. 다만 화면에 보인 개별 문서가 동일 UID 소유였는지 다른 UID/legacy 문서였는지는 운영/실기기 데이터를 읽지 않았으므로 확정하지 않았다.
- 시간표: 저장 설정이 없는 personal UID의 기본은 시작 06:00, 종료 exclusive 23:00으로 06시~22시 행을 모두 표시하고 최초 목록 위치는 기존처럼 첫 행인 06:00이다. personal 시간표 설정 key를 UID별로 분리해 다른 UID/legacy 설정을 상속하지 않는다. 같은 UID가 새 key로 저장한 설정은 항상 기본값보다 우선한다. legacy의 기존 전역 key는 유지한다. 자동 스크롤, 현재 시간/첫 레슨 포커스, 진입 때 위치 재설정은 추가하지 않았다.
- 수정 파일: `lib/pages/account_gate.dart`, `lib/pages/home_page.dart`, `lib/services/home_member_lookup_service.dart`, `lib/widgets/home/sections/home_header_section.dart`, `lib/widgets/home/sections/home_recent_clients_section.dart`, `lib/widgets/home/lesson_editor/home_recent_members_section.dart`, `test/home_personal_entry_isolation_test.dart`, 본 문서와 `BACKLOG.md`.
- 테스트: 관련 Flutter 테스트 52개 통과. 전체 `flutter test --no-pub -r expanded` 233개 통과.
- analyze: 일반 변경 범위 실행은 기존 warning/info 때문에 exit 1이었다. 새 경고 2건을 제거한 뒤 `--no-fatal-warnings --no-fatal-infos`로 재검증해 error 0건, 기존 warning/info 68건을 확인했다. 기존 `home_page.dart`의 미사용 선언, deprecated API, async context 등이 남아 있으며 이번 범위에서 정리하지 않았다.
- build: Debug APK 성공(`app-debug.apk`), Profile APK 성공(`app-profile.apk`). Release APK는 오류 출력 없이 두 번 모두 10분 실행 제한에 도달했고, 남은 하위 프로세스 종료 뒤에도 기존 `app-release.apk` 시각(2026-07-19 08:03:31)이 갱신되지 않아 성공 여부 미검증이다. 이전 산출물 존재를 이번 빌드 성공으로 간주하지 않았다.
- 제외/배포: Functions, Firestore Rules, Storage Rules, Firebase 배포, 데이터 삭제·migration은 수정하거나 실행하지 않았다. 실제 기기 수동 확인은 수행하지 않았다.
- 남은 위험: 실제 기기에서 신규 UID/기존 UID 전환 시 최근 회원 0명 상태와 owner 차단 로그, 긴 nickname/큰 글자 배율의 헤더, Release APK 빌드를 다시 확인해야 한다. 자동 포커스와 Android 위젯 시간 범위 최적화는 별도 backlog로 남겼다.
- 다음 backlog로 이동하지 않았다.

## 2026-07-19 Home 2줄 인사 문장부호 및 nickname canonical 통일

- 원인: personal Home은 `trainer_profiles/{currentUid}.nickname`을 표시해 `김트레이너`가 보였지만, 기존 canonical MyPage는 같은 문서를 읽고도 `(displayName ?? nickname)` 순서로 값을 골랐다. `displayName`이 빈 문자열로 존재하면 null이 아니므로 nickname으로 넘어가지 않아 MyPage가 nickname 미완성으로 판단했다. 별도 `PersonalMyPage` 경로도 넛지 완료 여부를 `displayName`으로 판단했다.
- canonical source: AccountGate 온보딩 판정, callable 기반 Onboarding 저장 확인, Home 헤더, canonical MyPage 표시, PersonalMyPage 넛지를 모두 `trainer_profiles/{currentUid}.nickname` 기준으로 통일했다. personal 경로에서 `realName`, `trainerName`, legacy `trainer_profile/me`, SharedPreferences 이름, 자동 축약 이름을 nickname fallback으로 사용하지 않는다. 테스트용 완료 fixture의 `선생님` 기본값도 제거하고 nickname을 명시하도록 변경했다.
- 인사 문장부호: `homeGreetingTextForHour`가 `오늘도 잘 시작해볼까요?`, `점심은 드셨어요?`, `잠깐 숨을 고르고 시작해볼까요?`, `오늘 하루도 저물어가네요`처럼 문장부호를 포함한 최종 문자열을 반환한다. 렌더링은 문장부호를 추가하지 않으며 둘째 줄은 `nickname + 님`만 표시하고 `님님`을 방지한다.
- MyPage 넛지: nickname이 있으면 “어떻게 불러드릴까요?” 항목을 완료로 보고 전화번호 등 다음 미완성 필드부터 안내한다. 실제 사용자 문서 삭제·migration·수정은 수행하지 않았다.
- 수정 파일: `lib/widgets/home/sections/home_header_section.dart`, `lib/pages/my_page.dart`, `lib/pages/personal_my_page.dart`, `lib/services/managed_member_workspace_service.dart`, `lib/services/personal_profile_start_reader.dart`, 관련 테스트 5개.
- format: 변경 Dart 파일 포맷 완료.
- 관련 테스트: nickname 온보딩, Home/MyPage, 관리자·Debug legacy 회귀 73개 통과.
- 전체 테스트: `flutter test --no-pub -r expanded`, 236개 모두 통과.
- analyze: 변경 범위 10개 파일 분석 exit 0, 신규 error 0건. 기존 `my_page.dart`의 deprecated API·미사용 선언을 포함한 warning/info 64건은 범위 밖이라 유지했다.
- build: `flutter build apk --debug --no-pub` 성공, `build/app/outputs/flutter-apk/app-debug.apk` 생성.
- 배포/데이터: Functions, Firestore Rules, Storage Rules, Firebase 배포 및 실제 사용자 데이터 변경을 수행하지 않았다. 다음 백로그로 이동하지 않았다.
## 2026-07-19 nickname 저장 경로 감사·MyPage 이름 저장 차단·Home 인사 축소

- 범위: 사용자가 기억하지 못하는 personal nickname 저장 원인 감사, 기존 canonical `MyPage`의 nickname/실명 저장 경계 보완, Home 2줄 인사 타이포 축소만 수행했다. Home FC·MORE 인사이트·네온·최근 회원·시작 route는 변경하지 않았다.
- nickname 전체 쓰기 경로: 현재 앱의 personal `trainer_profiles/{uid}.nickname` 쓰기는 `OnboardingPage` 또는 `MyPage`가 `FirebasePersonalNicknameOnboardingGateway`를 거쳐 `completeNicknameOnboarding` callable을 호출하는 경로뿐이다. 기존 `OnboardingPage`의 callback 없는 legacy 분기는 `trainer_profile/me.displayName`만 저장한다. `updatePersonalTrainerProfile`, anonymous/linked bootstrap, 계정 연결 전환은 nickname을 만들거나 복사하지 않는다.
- 기존 nickname 원인: 현재 코드와 현재 문서 필드만으로 과거 생성 시점을 확정할 수 없다. 현재 저장된 값은 callable 온보딩 또는 과거 배포 버전/클라이언트 경로에서 저장됐을 가능성이 있으나 추측으로 단정하지 않는다. 생성 시점은 미확정이다. bootstrap 자동 생성, realName/displayName/trainerName 자동 복사, 이름 자동 축약, SharedPreferences 이름 복사는 현재 코드에서 발견되지 않았다.
- 진단 로그: profile 서버 조회 시 `[MTF_NICKNAME_STATE]`에 uid, anonymous 여부, nickname, onboarding 완료 여부·시각, 문서 존재 여부를 기록한다. 쓰기 직전 `[MTF_NICKNAME_WRITE]`에 uid, `onboarding|myPage` source, previous/next를 기록한다. 이메일·전화번호·token은 기록하지 않는다.
- MyPage 저장 검증: `_saveProfile` 진입 직후 계약서 반영 선택과 무관하게 nickname/실명을 먼저 검증한다. 둘 다 공백이면 화면과 입력을 유지하고 Firestore/callable 쓰기 및 성공 메시지를 차단한다. nickname만 있거나 둘 다 있으면 trim 및 1~6자 규칙으로 저장한다.
- 실명만 입력: `모어댄이 부를 이름이 필요해요. 입력한 실명을 닉네임으로 사용할까요?` 확인 시트에서 `실명으로 사용할게요 / 닉네임 입력하기 / 취소`를 제공한다. 명시적으로 실명 사용을 선택하고 실명이 1~6자일 때만 원문을 nickname에 복사한다. 6자 초과는 자동 축약하지 않고 nickname 입력으로 안내한다. 계약서 이름 반영 선택은 별도 상태로 보존했다.
- 저장 동기화: MyPage nickname 변경은 기존 callable 성공 뒤 `trainer_profiles/{uid}`를 `Source.server`로 다시 읽어 동일 값을 확인한다. 성공이 확인된 경우에만 완료 메시지를 표시하며, Home 헤더의 기존 profile stream이 같은 문서 변경을 받아 앱 재시작 없이 갱신한다. 실패 시 화면과 입력값을 유지한다.
- Home 타이포: 첫 줄 greetingText는 `13px / FontWeight.w600 / height 1.15`, 둘째 줄 nickname은 `18px / FontWeight.w700 / height 1.12`로 축소했다. 질문·서술 문장부호는 각 greetingText의 최종 문자열만 사용하며 렌더링 단계에서 추가하지 않는다.
- 수정 파일: `lib/pages/my_page.dart`, `lib/services/personal_profile_start_reader.dart`, `lib/widgets/home/sections/home_header_section.dart`, `test/home_personal_entry_isolation_test.dart`, `test/app_account_foundation_test.dart`, 본 문서와 `BACKLOG.md`.
- format: 변경 Dart 파일 5개 `dart format` 완료.
- 관련 테스트: nickname 온보딩·Home 인사·MyPage·관리자·Debug legacy 관련 64개 모두 통과.
- 전체 테스트: `flutter test --no-pub -r expanded`, 240개 모두 통과.
- analyze: 변경 범위 분석에서 새 컴파일 오류는 없었다. 기존 `my_page.dart`의 미사용 요소와 deprecated API 등 기존 warning/info 64건 때문에 명령 exit 1이며, 범위 밖 경고는 수정하지 않았다.
- build: `flutter build apk --debug --no-pub` 성공, `app-debug.apk` 생성. `flutter build apk --profile --no-pub` 성공, `app-profile.apk` 162.0MB 생성.
- diff: `git diff --check`는 문서 갱신 뒤 최종 확인한다.
- 배포/데이터: Functions, Firestore Rules, Storage Rules를 수정하거나 배포하지 않았고 기존 사용자 데이터를 삭제·초기화·migration하지 않았다.
- 남은 확인: 실제 기기에서 기존 nickname 문서의 과거 생성 시점은 앱 코드만으로 복원할 수 없다. Debug 로그를 통해 다음 실제 profile read/write 시점부터 source를 확인할 수 있다. 다음 백로그로 이동하지 않았다.
## 2026-07-19 Home 인사 추가 축소 및 Firebase dev/prod 분리 기반

- 범위: Home 2줄 인사 글자 크기를 한 단계 더 줄이고, 현재 운영 Firebase와 향후 별도 개발 Firebase를 분리할 Android flavor·Flutter environment·local key 기반만 추가했다. Functions, Firestore Rules, Storage Rules, Firebase 배포와 실제 사용자 데이터는 변경하지 않았다.
- 현재 운영 identity: projectId `more-than-fitness-f6adb`, Android appId `1:993248877411:android:799cd556b1752f83bcd156`, packageName/applicationId `com.example.mtf_app`, profile 경로 `trainer_profiles/{currentUid}`다. 현재 설정은 flavor 도입 전 단일 `android/app/google-services.json`과 `lib/firebase_options.dart`를 사용하고 있었다.
- 기존 데이터 표시 원인: personal Home은 `trainer_profiles/{uid}.nickname`, canonical MyPage는 같은 문서의 nickname과 실명 관련 필드를 읽는다. 따라서 값이 보이는 직접 원인은 legacy/UI fallback이 아니라 현재 project·현재 UID의 실제 profile 문서 경로다. 실제 기기 UID가 과거 개발 UID와 동일한지는 연결된 기기 로그가 없어 미확정이다.
- identity 로그: Debug 시작 시 `[MTF_APP_ENV]`에 environment/projectId/packageName을 기록한다. personal profile 서버 조회 시 `[MTF_ENV_IDENTITY]`에 projectId, appId, packageName, uid, anonymous 여부, profilePath, nickname, realName, onboardingCompleted를 기록한다. 이메일·전화번호·token은 기록하지 않는다.
- flavor: `prod`는 기존 `com.example.mtf_app`, 기존 `DefaultFirebaseOptions`와 운영 설정을 유지한다. `dev`는 `com.example.mtf_app.dev`, 앱 이름 `모어댄 DEV`, `lib/main_dev.dart`와 Android native Firebase 설정을 사용한다. dev 화면에는 작은 overlay `DEV`를 표시하고 prod에는 표시하지 않는다.
- dev 안전장치: `android/app/src/dev/google-services.json`이 없으면 Gradle Google Services 단계에서 실패한다. 파일이 있더라도 dev projectId가 운영 `more-than-fitness-f6adb`와 같으면 시작을 거부한다. 운영 설정으로 fallback하지 않는다.
- local key: personal Home 시간표 설정, Home 고정 인사와 문구·질문 기록, MyPage nudge를 `mtf_{projectId}_{uid}_{featureKey}` 범위로 변경했다. legacy/debug key와 기존 운영 key는 삭제·migration하지 않았다. 새 key가 없으면 기본값에서 시작한다.
- Home 헤더: 첫 줄 greetingText `12px / w600 / height 1.15`, 둘째 줄 nickname `17px / w700 / height 1.12`로 변경했다. 질문 문장부호, `님` 방지, FC 문장 내용·선택 로직은 변경하지 않았다.
- 수정 파일: `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`, `lib/main.dart`, `lib/main_dev.dart`, `lib/main_prod.dart`, `lib/services/app_environment.dart`, `lib/services/personal_profile_start_reader.dart`, `lib/services/personal_my_page_nudge_service.dart`, `lib/pages/home_page.dart`, `lib/pages/my_page.dart`, `lib/widgets/app_environment_banner.dart`, `lib/widgets/home/sections/home_header_section.dart`, 관련 테스트, `FIREBASE_ENVIRONMENT_SEPARATION.md`, 본 문서와 `BACKLOG.md`.
- format: 변경 Dart 파일만 `dart format` 완료.
- 관련 테스트: 최종 직접 관련 테스트 28개 통과. 넓은 관련 묶음 74개도 통과.
- 전체 테스트: 최종 `flutter test --no-pub -r expanded`, 245개 모두 통과.
- analyze: 새 환경 코드의 컴파일 오류는 없다. 기존 대형 `home_page.dart`/`my_page.dart`의 누적 unused/deprecated/async-context warning·info를 포함한 122건 때문에 변경 범위 명령은 exit 1이다. 범위 밖 경고는 수정하지 않았다.
- prod build: `flutter build apk --debug --flavor prod -t lib/main_prod.dart --no-pub` 성공, `app-prod-debug.apk` 생성.
- dev build: 설정 파일이 아직 없어 동일 명령의 dev 변형은 의도대로 `Dev Firebase configuration is missing: android/app/src/dev/google-services.json`에서 실패했다. dev APK 성공으로 기록하지 않는다.
- FlutterFire CLI: 현재 환경에 설치되어 있지 않아 설치·구성을 실행하지 않았다. 별도 dev 프로젝트와 Android 앱 등록, 설정 파일 배치는 후속 사용자 준비가 필요하다.
- 배포/데이터: Firebase Functions/Rules/Storage 배포, 운영 Auth 사용자나 profile 삭제·초기화·수정, nickname 비우기, migration을 수행하지 않았다. 다음 백로그로 이동하지 않았다.

## 2026-07-19 DEV Firebase 연결 및 신규 사용자 최초 진입 검증

- DEV 설정: `android/app/src/dev/google-services.json`의 `project_id=more-than-fitness-dev-mft`, `mobilesdk_app_id=1:894386170382:android:e544106d34f789583e2a5f`, `package_name=com.example.mtf_app.dev`를 필요한 식별값만 읽어 확인했다. PROD는 `more-than-fitness-f6adb`/`com.example.mtf_app`로 서로 다르며, dev flavor의 별도 applicationId와 dev 설정 파일 누락 시 빌드 차단 로직을 확인했다.
- 신규 진입 호출 흐름: `AppAccountGate`는 Auth 사용자가 없으면 익명 세션을 만든 뒤 익명 사용자에게 `bootstrapAnonymousBeginnerProfile`을 호출한다. `trainer_profiles/{uid}`를 읽어 nickname이 비었거나 `onboardingCompleted != true`이면 기존 `OnboardingPage`를 표시하고, 저장 시 `completeNicknameOnboarding`을 호출한다. 신규 익명 최초 진입에는 이 두 callable만 필요하며 `bootstrapTrainerProfile`, `updatePersonalTrainerProfile`은 호출되지 않는다.
- Functions 사전 검증: `npm.cmd --prefix functions run lint`, `npm.cmd --prefix functions run build` 통과. 격리 Emulator에서 프로필 30개 및 닉네임 11개 시나리오 통과.
- DEV Functions 배포: `npx.cmd firebase deploy --only "functions:bootstrapAnonymousBeginnerProfile,functions:completeNicknameOnboarding" --project more-than-fitness-dev-mft`만 실행했다. 두 함수 모두 `asia-northeast3`, Node.js 22, `maxInstances=10`, ACTIVE로 확인했다. 최초 명령은 필수 API 활성화 직후 목록 조회 전파 지연으로 중단됐고, 재실행에서는 두 함수 생성이 성공했으나 Artifact Registry cleanup policy 미설정 때문에 CLI 최종 종료 코드는 1이었다. 함수 목록 재조회로 두 함수의 실제 ACTIVE 상태를 확인했다. cleanup policy는 임의 설정하지 않았다.
- Rules: 자기 `trainer_profiles/{uid}` 읽기만 인증 사용자에게 허용하고 client create/delete는 거부하며, update는 non-anonymous owner의 제한 필드만 허용하는 기존 경계를 유지했다. 인증 토큰 선택 필드는 `Map.get` 기본값으로 안전하게 읽도록 했고, 기존 `sessions`/`membership` null/map compiler warning을 type guard로 제거했다. 권한 범위는 넓히지 않았다.
- Rules 검증: 프로필 30개, 닉네임 11개, 회원/등급 27개 Emulator 시나리오가 통과했다. 회원 테스트 첫 실행은 Functions Emulator 초기화 10초 제한으로 실패했으나 재실행은 전부 통과했다. 최종 `npx.cmd firebase deploy --only firestore:rules --project more-than-fitness-dev-mft`는 warning 없이 compile 및 DEV release 성공했다.
- 운영 보호: 모든 실제 Firebase CLI 변경 명령에 `--project more-than-fitness-dev-mft`를 명시했다. 운영 프로젝트 `more-than-fitness-f6adb`에는 Functions/Rules 배포, 데이터 쓰기, migration, seed를 실행하지 않았다. Storage Rules도 배포하지 않았다.
- Flutter/실기기 미검증: ADB 연결 기기가 0대여서 `R3CX40M6EEM` 실행, 실제 DEV UID 로그, AI FC 준비 화면, nickname 온보딩, Home/MyPage 동일 nickname, 운영 데이터 미노출의 실기기 확인을 수행하지 못했다. Flutter 도구는 `flutter --version` 자체도 출력 없이 timeout되는 환경 정지 상태여서 관련 Flutter 테스트, analyze, dev/prod Debug APK 빌드를 이번 실행에서 완료하지 못했다. 이전 산출물을 이번 검증 성공으로 간주하지 않는다.
- diff: `git diff --check`는 whitespace 오류 없이 통과하고 기존 줄바꿈 안내만 출력했다.
- 다음 백로그로 이동하지 않았다.

## 2026-07-19 DEV MyPage personal 데이터 소스 및 계약서 담당강사명 선택 유지

- 범위: DEV personal MyPage의 프로필 읽기·초기화·저장·재조회 흐름과 계약서 담당강사명 선택 유지 문제만 수정했다. Firestore/Storage Rules와 운영 프로젝트 데이터는 변경하지 않았고 다음 백로그로 이동하지 않았다.
- 실제 원인: personal 저장 callable이 `contractTrainerNameSource`와 직접 입력값을 저장하지 않아 서버의 이전 선택이 남았다. UI 재진입 시 source가 없으면 실명·닉네임 값의 존재 여부로 `realName`/`displayName`을 추론했고, 직업은 저장 시 `affiliationType`에 넣으면서 읽을 때 오래된 `position`을 먼저 골랐으며 레슨 분야도 `primaryActivity` 저장 후 오래된 `lessonSpecialty`를 먼저 읽었다.
- canonical 문서: personal의 nickname, realName, 직업, 레슨 분야, 소속 형태, 계약서 이름 source와 직접 입력값은 모두 `trainer_profiles/{currentUid}` 한 문서에서 읽는다. legacy `trainer_profile/me`, SharedPreferences, static/cache를 personal fallback으로 사용하지 않는다.
- 필드 기준: `nickname`, `realName`, `jobTitle`, `primaryActivity`, `affiliationType`, `contractTrainerNameSource`, `contractTrainerCustomName`을 canonical 필드로 사용한다. 기존 문서 호환을 위해 같은 personal 문서에서 `jobTitle`이 없을 때만 `position`/`affiliationType`, `primaryActivity`가 없을 때만 `lessonSpecialty`를 읽되 저장은 canonical 필드로 한다. 직업 저장이 `affiliationType`을 덮지 않게 분리했다.
- 계약서 이름 source: 기존 값 `displayName`(닉네임), `realName`, `manual`을 그대로 유지했다. source가 없거나 유효하지 않은 과거 문서는 값 존재 여부를 추론하지 않고 `manual`로만 초기화하며 로그에 `source=default`를 남긴다. 선택한 닉네임·실명·직접 입력값이 비면 안내 후 저장을 막고 다른 source로 자동 전환하지 않는다.
- callable: `updatePersonalTrainerProfile` transaction이 `jobTitle`, `primaryActivity`, `contractTrainerNameSource`, `contractTrainerCustomName`을 함께 저장한다. 선택 source와 병합된 최신 필드로 `contractTrainerName`을 서버에서 계산하고, 허용되지 않은 payload 필드와 빈 선택값을 거부한다. tier, 회원 수, account/workspace/role 등 서버 권위 필드는 기존 로직을 유지한다.
- 저장 확인: callable 성공 뒤 `Source.server`로 같은 profile을 다시 읽고 nickname, realName, jobTitle, primaryActivity, 계약서 source/직접 입력값이 요청과 모두 일치할 때만 성공 안내를 표시한다. 실패 시 화면과 입력값을 유지한다.
- 로그: `[MTF_MY_PAGE_PROFILE_READ]`, `[MTF_MY_PAGE_PROFILE_SAVE]`, `[MTF_MY_PAGE_PROFILE_RELOAD]`에 UID, 환경, 문서 경로, 필드 존재/일치 여부, 계약서 source, 안전한 오류 코드만 기록한다. 전화번호·실명·닉네임 실제 값은 기록하지 않는다.
- 수정 파일: `functions/src/profile_bootstrap.ts`, `lib/pages/my_page.dart`, `lib/services/managed_member_workspace_service.dart`, `test/my_page_profile_save_ui_test.dart`, `test/personal_my_page_test.dart`, `test/managed_member_workspace_test.dart`, `firebase-emulator-tests/nickname_onboarding.test.cjs`, 본 문서와 `BACKLOG.md`.
- Functions 검증: `npm.cmd --prefix functions run lint`, `npm.cmd --prefix functions run build` 통과. DEV Emulator에서 anonymous/linked 저장, UID 격리, source 유지, 빈 선택값 거부, 권위 필드 보존을 포함한 16개 시나리오가 통과했다.
- DEV 선택 배포: `npx.cmd firebase deploy --only "functions:updatePersonalTrainerProfile" --project more-than-fitness-dev-mft`만 실행했다. 함수 업데이트 자체는 성공했고 `firebase functions:list --project more-than-fitness-dev-mft`에서 v1 callable, `asia-northeast3`, Node.js 22를 확인했다. Artifact Registry cleanup policy 미설정 때문에 CLI 최종 종료 코드는 1이었으며 `--force`나 임의 cleanup 설정은 사용하지 않았다.
- Flutter 검증: 관련 테스트 최종 36개 통과, 전체 `flutter test --no-pub -r expanded` 263개 통과. 변경 범위 analyze는 exit 0이며 신규 error 없이 기존 `my_page.dart` warning/info 56건을 유지했다. DEV Debug APK `app-dev-debug.apk`, PROD Debug APK `app-prod-debug.apk` 빌드가 모두 성공했다.
- diff: `git diff --check`는 whitespace 오류 없이 통과하고 기존 줄바꿈 안내만 출력했다.
- 실기기 미검증: 지정 Android 기기가 연결되어 있지 않아 DEV 앱을 재실행한 뒤 MyPage 저장→앱 완전 종료→재진입 시 필드와 계약서 source가 유지되는지는 확인하지 못했다. 이를 실기기 검증 완료로 기록하지 않는다.
- 운영 보호: 운영 프로젝트 `more-than-fitness-f6adb`에는 Firebase CLI 명령, Functions/Rules 배포, 데이터 읽기·쓰기·migration을 실행하지 않았다. PROD Debug APK는 로컬 회귀 빌드만 수행했다.

## 2026-07-20 DEV/PROD launcher 구분·DEV schedules 인덱스·personal tier 격리

- 확인된 실제 원인: 사용자가 제공한 로그에서 DEV는 `more-than-fitness-dev-mft`/`com.example.mtf_app.dev`/UID `HTINAJJ7MlW9LJLvst65Xfc2S5U2`, PROD는 `more-than-fitness-f6adb`/UID `tHr2vM8nebbbnCC1HeewTcho7Vg1`로 완전히 분리돼 있었다. DEV 저장 후 보인 과거 마이페이지는 DEV 데이터 혼입이 아니라 launcher 이름과 아이콘이 유사한 PROD 앱을 다시 연 결과였다.
- launcher 구분: 공통 manifest의 `@string/app_name`은 유지하고 `android/app/src/prod/res/values/strings.xml`에 `모어댄`, `android/app/src/dev/res/values/strings.xml`에 `모어댄 DEV`를 정의했다. Gradle의 중복 `resValue`는 제거했다. 기존 launcher 아이콘은 변경하거나 새로 생성하지 않았으며 앱 내부 우측 상단 DEV 표시는 유지했다.
- 패키징 확인: 최종 DEV/PROD Debug 빌드의 packaged resource에서 각각 `모어댄 DEV`, `모어댄`이 포함된 것을 확인했다. Android 기기가 연결되지 않아 실제 휴대폰 launcher 화면은 이번 실행에서 직접 확인하지 못했다.
- schedules 인덱스: 기존 `firestore.indexes.json`의 `schedules` COLLECTION 인덱스가 `trainerId ASC`, `workspaceType ASC`, `startAt ASC`로 실제 personal 범위 query와 일치함을 확인했다. 새 인덱스를 중복 추가하지 않았다.
- DEV 인덱스 배포: `npx.cmd firebase deploy --only firestore:indexes --project more-than-fitness-dev-mft`를 실행해 `(default)` 데이터베이스에 성공적으로 배포했다. 명령은 Rules compile만 확인했으며 Rules는 배포하지 않았다.
- stream 오류 처리: Home schedules stream에 `onError`를 추가했다. 인덱스 생성 대기나 permission 오류가 발생하면 안전한 오류 코드만 기록하고, 현재 binding이면 ready 상태의 빈 일정으로 전환해 처리되지 않은 stream 예외가 앱 전체로 전파되지 않게 했다.
- personal tier: `AppTierAccessService.loadPersonalTrainerAccess(uid:)`가 `trainer_profiles/{uid}.tier`와 personal 프로필의 권위 필드만 읽는다. 후원·조직·legacy tier를 합산하지 않는다. Home의 모든 tier gate와 smart alarm 동기화, 알림 설정의 tier/nickname 조회가 personal UID를 전달한다. MyPage는 기존처럼 같은 canonical 문서를 직접 읽는다.
- legacy 유지: owner UID가 없는 Debug legacy 경로에서만 기존 `AppTierAccessService.loadTrainerAccess()`와 `trainer_profile/me`를 사용한다. personal Home 초기 알림 동기화가 legacy 서비스를 호출하던 직접 permission-denied 경로를 제거했다.
- 수정 파일: `android/app/build.gradle.kts`, flavor별 `strings.xml` 2개, `lib/services/app_tier_access_service.dart`, `lib/services/notification_service.dart`, `lib/pages/notification_settings_page.dart`, `lib/pages/settings_page.dart`, `lib/pages/my_page.dart`, `lib/pages/home_page.dart`, `test/dev_prod_personal_isolation_test.dart`, 본 문서와 `BACKLOG.md`.
- 검증: 관련 Flutter 테스트 52개 통과, 전체 `flutter test --no-pub -r expanded` 267개 통과. 변경 범위 analyze는 exit 0이며 신규 error 없이 기존 누적 warning/info 143건을 유지했다. DEV Debug APK `app-dev-debug.apk`, PROD Debug APK `app-prod-debug.apk` 빌드가 모두 성공했다. `git diff --check`는 whitespace 오류 없이 통과하고 기존 줄바꿈 안내만 출력했다.
- 실기기 상태: `flutter devices`에 Android 기기가 없어 launcher 두 이름, DEV 재진입 값 유지, schedules 실시간 query 성공, permission-denied 부재를 이번 실행에서 직접 재검증하지 못했다. 사용자가 제공한 projectId/UID 로그와 DEV 저장 성공은 확인 사실로 기록하되 새 실기기 검증으로 간주하지 않는다.
- 운영 보호: 실제 Firebase 명령은 `--project more-than-fitness-dev-mft`를 명시한 인덱스 선택 배포 한 번뿐이다. 운영 프로젝트에 Firebase CLI 명령, Functions/Rules/Storage 배포, 데이터 읽기·쓰기·삭제·migration을 실행하지 않았다. 다음 백로그로 이동하지 않았다.
-
## 2026-07-20 DEV personal nickname 시작 flash 차단

- 범위: `AccountGate → HomePage → HomeHeaderSection` personal 시작 경로만 수정했다. `GuestStartPage`, `GuestPreviewPage`, Firebase Functions, Firestore/Storage Rules 및 Firebase 데이터는 수정하지 않았다.
- 실제 코드 원인: `FirebasePersonalProfileStartReader`는 `trainer_profiles/{currentUid}`를 `Source.server`로 읽고 있었지만 `PersonalProfileStartResult`에는 `nickname`과 `onboardingCompleted`만 남겼다. 이후 `AccountGate`가 canonical `HomePage`를 만들 때 해당 결과를 전달하지 않아 Home은 빈 배너 상태로 시작했고, `_bindBannerDataStreams()`의 첫 snapshot을 metadata 구분 없이 적용했다. 따라서 로컬 Firestore 캐시에 과거 nickname이 있으면 서버 snapshot 전 한 프레임 이상 표시될 수 있었다.
- 시작 화면 순서 판단: 사용자에게 확인된 `과거 이름 → AI FC 준비 화면 → 최신 이름` 순서는 현재 Flutter widget 순서로 만들 수 없으므로 Android starting/task preview 구간(A)에 해당한다. DEV flavor에만 `#F3F4F6` 중립 시작 배경과 이전 window preview 차단을 추가했다. `AI FC 준비 화면 → Home 과거 이름 → Home 최신 이름`에 해당하는 Firestore 캐시 경로(B)도 코드상 존재해 함께 차단했다.
- 초기 데이터 전달: `PersonalProfileStartResult.profileData`에 AccountGate가 서버에서 확인한 전체 personal profile map을 보존하고, canonical `HomePage(personalOwnerUid:, initialPersonalProfileData:)`에 전달한다. 온보딩 직후에는 기존 map에서 nickname/onboardingCompleted만 갱신한 초기 map을 전달한다. anonymous와 linked personal 경로 모두 동일하다.
- Home 초기화: `HomePage.initState()` 첫 build 전에 `_bannerProfileData`, `_bannerTrainerName`, personal tier, 회원 수, 프로필 완료 상태를 초기 profile map으로 초기화한다.
- snapshot 정책: `includeMetadataChanges: true`로 profile stream을 구독한다. 초기 profile이 있는 personal Home은 `fromCache=true` snapshot을 `applied=false`, `reason=initial_profile_protect_cached_snapshot`으로 거부하고 AccountGate 초기값을 유지한다. `fromCache=false` 서버 snapshot만 정상 반영한다. stream 오류·오프라인에서도 초기 nickname을 비우거나 과거 캐시로 교체하지 않는다.
- 진단 로그: `[MTF_PROFILE_SNAPSHOT]`에 uid, fromCache, hasPendingWrites, nickname, updatedAt, applied, reason만 기록한다. 다른 프로필 개인정보는 기록하지 않는다.
- HomeHeaderSection 감사: `StatelessWidget`이며 `profileDisplayName`을 state/initState에 저장하지 않는다. 따라서 `didUpdateWidget` 캐시 보정이 필요한 구조가 아니고 부모 rebuild의 새 값을 즉시 사용한다. SharedPreferences는 UID 범위의 사용자 고정 인사 문구에만 쓰며 nickname을 읽지 않는다. `김트` literal fallback은 없다. 2글자 축약 함수는 원형 아바타 shortName 전용이고 2줄 인사의 nickname source는 아니다.
- DEV Android 시작 화면: `android/app/src/dev/res/values`, `values-night`, `values-v31`에 DEV 전용 중립 LaunchTheme을 추가했다. PROD Android resource는 변경하지 않았다.
- 테스트: 관련 52개 통과. 초기 `라디오` + cache `김트`는 `라디오` 유지, server `새라디오`는 반영, 오프라인 cache는 초기값 유지, `profileDisplayName` 변경 즉시 반영, nickname 미완성 시 Onboarding 유지 회귀를 확인했다. 전체 `flutter test --no-pub -r expanded` 270개 통과.
- analyze: 변경 Dart 파일 분석에서 새 컴파일 오류는 없었다. `home_page.dart`에 기존 warning/info 57건이 남아 명령 종료 코드는 1이었다.
- 빌드: `flutter build apk --debug --flavor dev --no-pub` 성공(`app-dev-debug.apk`), `flutter build apk --debug --flavor prod --no-pub` 성공(`app-prod-debug.apk`). `git diff --check` whitespace 오류 없음(기존 줄바꿈 안내만 출력).
- 실기기: 이번 실행 환경의 `flutter devices`에는 Android 기기가 없어 새 `[MTF_PROFILE_SNAPSHOT]`의 실제 cache→server 순서와 과거 이름 flash 제거를 실기기에서 재확인하지 못했다. 완료로 추측하지 않고 미검증으로 남긴다.
- 운영 보호: PROD `more-than-fitness-f6adb`에 Firebase CLI 명령, 배포, 데이터 읽기·쓰기·삭제를 전혀 실행하지 않았다. PROD는 로컬 Debug APK 회귀 빌드만 수행했다.
- 다음 백로그로 이동하지 않았다.
## 2026-07-20 PROD 개발 작업공간 차단 · MyPage 앵커 메뉴

- 범위: PROD에서 Debug legacy/development 작업공간 진입을 완전히 차단하고, MyPage 더보기 바텀시트를 기존 공통 앵커 드롭다운으로 교체했다. Firebase Functions/Rules/Storage와 실제 Firebase 데이터는 변경하지 않았고 다음 백로그로 이동하지 않았다.
- 실제 원인: `AccountGate`와 `GuestStartPage`가 각각 `kDebugMode && environmentName == 'dev'`만 검사했다. Firebase projectId와 Android packageName을 검증하지 않는 중복 조건이라 잘못된 환경 초기화 또는 직접 상태 주입 시 PROD 차단을 보장하지 못했다.
- 진입 경로 감사: 실제 `DebugLegacyWorkspaceShell` 생성 경로는 `AccountGate`의 `_debugLegacyWorkspaceOpen` 분기 한 곳이며, DEV 아이콘과 콜백도 같은 파일에 있었다. `GuestStartPage`에는 콜백 기반 `DEV 기존 데이터 열기` 버튼 경로가 남아 있었다. `SplashRouter`, `main.dart`, `AppWorkspaceMode.legacyDeveloper`의 다른 직접 생성 경로는 없었다. 정식 `PlatformAdmin`/`LegacyAdmin` claim 기반 경로는 별도이며 수정하지 않았다.
- 단일 기준: `AppEnvironmentConfig.canOpenDebugLegacyWorkspace`가 `kDebugMode`, environment=`dev`, projectId=`more-than-fitness-dev-mft`, packageName=`com.example.mtf_app.dev`를 모두 만족할 때만 true가 되도록 했다. AccountGate 분기·DEV 아이콘과 GuestStart 버튼이 이 getter만 사용한다.
- 안전 로그: entry point별 1회 `[MTF_DEBUG_LEGACY_ACCESS]` 로그에 environment, projectId, packageName, debugBuild, allowed, entryPoint만 기록한다. UID와 사용자 정보는 기록하지 않는다.
- MyPage 메뉴: 기존 `_openMyPageMoreSheet()`와 `showModalBottomSheet`를 제거했다. 회원관리 화면에서 사용하던 `MtfFloatingMoreMenuButton`/`MtfFloatingMoreMenuItem`을 재사용해 헤더 더보기 버튼 아래에 작은 카드가 열리도록 했다. 순서는 통계, 계약서 관리, 설정, 비밀번호 변경이며 기존 navigation/권한/비밀번호 변경 메서드를 그대로 호출한다.
- 공통 메뉴 닫기: 메뉴 항목 선택, 바깥 탭, 같은 아이콘 재탭, Android back에서 overlay가 제거된다. Back 처리는 `LocalHistoryEntry`로 추가해 페이지 pop보다 메뉴 닫기가 먼저 실행된다.
- 관련 테스트: 환경 matrix, PROD Debug Guest/AccountGate 차단, DEV Debug 허용, direct state 주입 차단, 정식 경로 회귀, 320/360/412 너비와 text scale 1.0/1.3/1.8 메뉴 표시, 항목 선택·바깥 탭·back 닫기를 포함해 29개 통과.
- 전체 테스트: `flutter test --no-pub -r expanded` 272개 모두 통과.
- analyze: 변경 범위에 컴파일 오류는 없었다. 기존 `my_page.dart`의 unused/deprecated 항목과 공통 메뉴의 기존 `withOpacity` info를 포함한 65개 warning/info 때문에 명령 종료 코드는 1이었다. 요청 범위 밖 경고는 수정하지 않았다.
- 빌드: DEV Debug `app-dev-debug.apk`, PROD Debug `app-prod-debug.apk`, DEV Release `app-dev-release.apk` 성공. PROD Release는 904초 제한에서 종료되어 미검증이며 성공으로 기록하지 않는다.
- diff: `git diff --check`는 whitespace 오류 없이 통과했고 기존 LF→CRLF 안내만 출력됐다.
- 실기기: `R3CX40M6EEM`에 `adb install -r`로 DEV/PROD Debug를 설치해 앱 데이터를 삭제하지 않았다. PROD는 `[MTF_DEBUG_LEGACY_ACCESS] environment=prod projectId=more-than-fitness-f6adb packageName=com.example.mtf_app debugBuild=true allowed=false entryPoint=directGate`를 확인했다. DEV는 앱 UI 진입 전 기존 `[core/duplicate-app] A Firebase App named "[DEFAULT]" already exists` 예외가 반복되어 버튼과 MyPage 메뉴를 실기기에서 확인하지 못했다. 이 별도 시작 오류는 이번 범위에서 수정하거나 검증 완료로 간주하지 않았다. 기기 잠금 상태로 PROD UI 캡처도 확보하지 못해 PROD 버튼 미표시는 자동 테스트와 런타임 guard 로그로만 확인했다.
- 보호 결과: PROD Firebase CLI/배포/데이터 읽기·쓰기·삭제·초기화·migration을 실행하지 않았다. 기존 PROD anonymous UID와 profile은 삭제하거나 재생성하지 않았다.
## 2026-07-20 DEV Firebase [DEFAULT] 중복 초기화 복구

- 범위: DEV Android 앱의 Firebase `[DEFAULT]` 중복 초기화만 수정했다. UI, Firebase Functions, Firestore/Storage Rules, 실제 DEV/PROD Firebase 데이터와 배포는 변경하지 않았고 다음 백로그로 이동하지 않았다.
- 정확한 두 초기화 지점: Android 앱 프로세스 시작 시 Google Services가 등록한 `FirebaseInitProvider`가 `android/app/src/dev/google-services.json`으로 네이티브 `[DEFAULT]` 앱을 먼저 생성한다. 이전 실기기 설치 APK는 DEV flavor이지만 `lib/main_dev.dart`가 아닌 기본 `lib/main.dart` entrypoint가 들어가 `runMtfApp(environment: prod)`의 PROD `DefaultFirebaseOptions`를 같은 `[DEFAULT]` 이름에 다시 전달했다.
- 실제 오류 원인: 네이티브 기본 앱은 DEV project였고 Dart에서 다시 전달한 options는 PROD project였다. FlutterFire의 options 일치 검사가 이를 `[core/duplicate-app]`으로 거부했다. `main_dev.dart` 자체가 공통 main과 별도로 Firebase를 초기화한 것은 아니며, 잘못된 build target과 공통 초기화의 비멱등 options 전달 조합이 원인이었다.
- 수정: `MtfFirebaseInitializer.initialize()`를 추가하고 `runMtfApp()`이 이 경로만 사용하게 했다. Dart에서 `[DEFAULT]`가 이미 보이면 `Firebase.app` 객체를 재사용하고 `Firebase.initializeApp`을 호출하지 않는다. Android 첫 연결에서는 flavor의 네이티브 설정을 options 재주입 없이 FlutterFire에 연결한다. 비 Android PROD만 기존 `DefaultFirebaseOptions.currentPlatform`을 유지한다.
- 환경 보호: 초기화 직후 DEV는 `more-than-fitness-dev-mft`, PROD는 `more-than-fitness-f6adb`와 정확히 일치해야 한다. DEV가 단순히 PROD와 다른 임의 project이면 허용하던 기존 검사를 정확한 DEV project 검사로 강화했다.
- 로그: Debug에서 `[MTF_FIREBASE_INIT] environment=... projectId=... packageName=... defaultAppExists=... action=initialize|reuse result=success|failure`를 남긴다. 실패를 숨기지 않고 로그 후 원래 예외를 다시 전달한다.
- 초기화 순서: `WidgetsFlutterBinding.ensureInitialized` → environment 선택 → 공통 Firebase 초기화/identity 검증 → AppEnvironment bind → Emulator 설정 → widget interactivity → `runApp` 순서를 유지했다. Auth/Firestore/Functions 사용 전에 Firebase 초기화가 끝난다.
- 테스트: 초기화 action initialize/reuse, 정확한 DEV project 검증, DEV Debug legacy 허용, PROD Debug 차단을 포함한 관련 테스트 11개 통과. 최종 `flutter test --no-pub -r expanded` 273개 모두 통과.
- analyze: 변경 범위 신규 error/warning은 없다. 기존 `lib/main.dart`의 `_index`가 final일 수 있다는 info 1건 때문에 종료 코드는 1이었으며 요청 범위 밖이라 수정하지 않았다.
- 빌드: `flutter build apk --debug --flavor dev -t lib/main_dev.dart --no-pub` 성공, `app-dev-debug.apk` 생성. `flutter build apk --debug --flavor prod -t lib/main_prod.dart --no-pub` 성공, `app-prod-debug.apk` 생성.
- 실기기: 최초 설치·실행 시도는 ADB 응답 제한으로 종료됐고 ADB server 재시작 후 `R3CX40M6EEM`이 연결 목록에서 사라졌다. 따라서 최종 APK의 DEV cold start, hot restart, 완전 종료 후 재실행, DEV 버튼 표시·legacy shell 진입/복귀와 PROD 화면은 실기기 검증 완료로 기록하지 않는다. 이전 duplicate-app 재현 APK의 결과도 최종 성공 근거로 사용하지 않는다.
- diff/보호: `git diff --check`는 whitespace 오류 없이 통과했다. Firebase CLI와 배포를 실행하지 않았고 PROD 앱 데이터·UID·프로필을 읽거나 수정·삭제·초기화하지 않았다.
## 2026-07-20 DEV 운영 통계 월별 레슨 기록 달력

- 범위: DEV personal 운영 통계에 `training_logs` 기반 월별 레슨 기록 달력만 추가했다. PROD 데이터 복사·조회·수정·삭제·migration은 하지 않았고, PROD Firebase에는 어떤 배포도 하지 않았다.
- 데이터 감사: personal 확정 이력의 canonical 원본은 루트 `training_logs`다. `schedules`는 예정·현재 일정 상태, `lessonStats`는 회원 단위 누적 집계이므로 장기 월별 확정 이력 원본으로 사용하지 않았다. 빠른서명과 정식 레슨일지는 동일한 `finalizePersonalTrainingLog` / `cancelPersonalTrainingLog` 경로를 사용한다.
- 기존 확정 필드: `trainerId`, `workspaceType`, `memberId`, 선택 `scheduleDocId`, `startAt`, `endAt`, `lessonType`, `status`/`sessionStatus`, `finalizedAt`, `sessionSnapshotTotal`, `sessionSnapshotRemainBefore`, `sessionSnapshotRemainAfter`, `sessionSnapshotDoneBefore`, `sessionSnapshotDoneAfter`를 유지했다.
- 추가 snapshot: 확정 transaction에서 `memberNameSnapshot`과 `sessionSnapshotLessonNumber`만 추가했다. 회원명 변경·회원카드 삭제 뒤에도 확정 당시 이름을 표시하고, 확정 당시 회차를 명시적으로 표시하기 위한 값이다. 기존 차감·통계·일정 상태와 응답 형식은 변경하지 않았다.
- 월 조회: `training_logs`에 `trainerId == currentUid`, `workspaceType == personal`, `startAt >= 월 시작`, `startAt < 다음 달 시작`, `orderBy(startAt ASC)`를 적용한다. repository에서 Auth UID 일치와 owner/workspace/month 범위를 다시 검증하며 앱 메모리에는 현재 선택 월 한 달만 유지한다.
- Stats 진입: legacy는 기존 `scheduleData` 통계를 유지한다. personal은 `StatsPage(personalOwnerUid: currentUid)`로 owner를 전달하고 월간 영역이 Firestore 확정 기록을 직접 조회한다.
- UI: 기존 레슨 인사이트 카드 아래에 이전 달·다음 달·이번 달 이동, 총 확정/소진/서비스/노쇼 차감/노쇼 미차감/실제 회원 수 요약, 일별 횟수와 상태 점, 선택 날짜 읽기 전용 상세를 추가했다. 상세는 시작 시각, 회원명 snapshot, 레슨 종류, 확정 상태, 회차 snapshot을 표시한다. 회원카드는 현재 UID personal 소유권과 미삭제 상태를 다시 확인한 경우에만 연다.
- 확정취소: `cancelPersonalTrainingLog`가 보존하는 `confirm_cancelled` 문서는 총 확정과 일별 확정 횟수에서 제외하고, 해당 날짜 상세에는 `확정취소`로 보존해 표시한다. completed로 재집계하지 않는다.
- 상태 처리: loading/success/empty/permission denied/network error를 분리했고, 월 이동 즉시 이전 목록을 폐기하며 오래 걸린 이전 요청 결과는 적용하지 않는다.
- 인덱스: `training_logs(trainerId ASC, workspaceType ASC, startAt ASC)`를 `firestore.indexes.json`에 추가했다. `npx.cmd firebase deploy --only firestore:indexes --project more-than-fitness-dev-mft`로 DEV `(default)` 데이터베이스에만 배포 성공했다. Rules는 수정하거나 배포하지 않았다.
- Function: `npx.cmd firebase deploy --only functions:finalizePersonalTrainingLog --project more-than-fitness-dev-mft`로 DEV의 해당 v1 callable만 선택 배포했다. `asia-northeast3` 생성은 성공했으나 Artifact Registry cleanup policy 미설정 때문에 CLI 최종 종료 코드는 1이었다. `--force`로 정책을 임의 설정하지 않았다.
- 검증: 관련 Flutter 테스트 21개 통과. Functions lint/build 통과. demo project Auth/Firestore/Functions Emulator의 personal training log 38개 시나리오 통과. 월간 exact query, owner/workspace 격리, snapshot, 상태별 집계, 월 경계·윤년, 320/360/412dp와 글자 배율 1.0/1.3/1.8을 확인했다.
- 전체 Flutter 테스트: 289개 통과, 기존 `home_personal_entry_isolation_test.dart:79` 한 건이 실행 시각에 따른 인사 문구(`오늘도 잘 시작해볼까요?` 기대, `숨을 고르고 시작해볼까요?` 실제)로 실패했다. 월별 통계 변경과 무관하며 이번 범위에서 수정하지 않았다.
- analyze: 변경 범위 컴파일 오류 없음. 신규 model/repository/calendar에는 issue가 없고 기존 `stats_page.dart`의 deprecated/const info 13건으로 명령 종료 코드는 1이었다.
- build/diff: DEV Debug `app-dev-debug.apk`, PROD Debug 회귀 `app-prod-debug.apk` 빌드 성공. `git diff --check` whitespace 오류 없음.
- 실기기: `R3CX40M6EEM`에 DEV APK를 `-r` 설치해 기존 DEV 데이터를 유지했고 `com.example.mtf_app.dev` Home 및 레슨 인사이트 진입을 확인했다. 현재 DEV 계정이 Beginner라 기존 Pro gate가 통계 화면을 덮어 월별 달력 자체는 육안 검증하지 못했다. 등급·데이터는 임의 변경하지 않았다.
- 보호: Firebase CLI 명령은 모두 `--project more-than-fitness-dev-mft`를 명시했다. PROD `more-than-fitness-f6adb`에는 배포·데이터 작업을 하지 않았으며 PROD Debug APK는 로컬 회귀 빌드만 수행했다. 다음 백로그로 이동하지 않았다.

## 2026-07-20 Personal 월간 레슨 기록 최종 검증·접근 정책

- 기존 gate 위치: `StatsPage.build()`의 최상위 `Stack`에서 `_canUseStatsPage == false`이면 전체 스크롤 영역에 blur와 `Positioned.fill` 업그레이드 카드를 덮었다. 이 때문에 Personal Beginner~Semi-Pro는 기본 월간 확정 이력까지 열 수 없었다.
- 접근 정책: Personal workspace에서는 `월별 레슨 기록`과 `MonthlyLessonCalendar`를 등급과 무관하게 먼저 표시한다. 월 이동, 월 총 확정 수, 소진·서비스·노쇼 차감·노쇼 미차감 집계, 날짜별 수, 날짜 상세, 당시 회원 이름·레슨 종류·회차를 Beginner부터 Grand Prix까지 열었다.
- Pro 유지 범위: 기존 기간 선택, 레슨·회원·수입 요약과 AI/추세·유지·재등록·비교·예측 성격의 고급 분석은 기존 `_canUseStatsPage` 정책을 유지한다. Personal 비Pro에는 페이지 전체 차단 대신 고급 영역 위치에 기존 업그레이드 안내만 표시한다. Legacy/non-personal 전체 gate 동작은 유지한다.
- 확정 경로: Personal Home 일반 확정·빠른서명 repository·정식 레슨일지 최종 확정은 `PersonalTrainingLogRepository.finalize()`를 거쳐 기존 `finalizePersonalTrainingLog` callable을 사용하도록 확인·통일했다. callable transaction은 completed, service, no_show_deducted, no_show_not_deducted 모두 `memberNameSnapshot`과 `sessionSnapshotLessonNumber`를 저장한다. 트레이너/회원 직접 서명 저장 payload에도 같은 canonical snapshot 필드를 보강했다. 회원 직접 서명·원격 서명 페이지는 서명 증거를 기존 log/request에 붙이는 단계이고 최종 확정은 trainer finalize 경로가 담당한다.
- 확정취소: Personal Home 취소와 정식 레슨일지 취소 모두 `cancelPersonalTrainingLog` 경로를 사용한다. 취소 transaction은 `status/sessionStatus=confirm_cancelled`와 취소 메타데이터만 갱신하며 당시 회원명·회차 snapshot은 삭제하거나 덮어쓰지 않는다.
- 인사 테스트: production의 현재 확정 문구는 10시 `숨을 고르고 시작해볼까요?`, 15시 `내일은 더 힘이 날꺼에요!`인데 테스트가 이전 문구를 기대했다. production 문구와 인사 규칙은 변경하지 않고 `home_personal_entry_isolation_test.dart` 기대값만 현재 문구에 맞췄다.
- 자동 검증: 관련 Flutter 테스트 49개 통과, 전체 Flutter 테스트 292개 통과. demo project Auth/Firestore/Functions Emulator의 personal training log 38개 시나리오가 통과했고 네 확정 상태의 snapshot, owner 격리, 취소 후 snapshot 보존과 집계 제외를 확인했다. Functions 소스는 이번 작업에서 수정하지 않았으므로 lint/build 및 재배포는 실행하지 않았다.
- analyze/build/diff: 변경 범위에 컴파일 오류는 없었다. 기존 대형 파일의 warning/info 109건 때문에 analyze 종료 코드는 1이었다. DEV Debug `app-dev-debug.apk`, PROD Debug 회귀 `app-prod-debug.apk` 빌드 성공. `git diff --check` whitespace 오류 없음.
- 실기기 미검증: 최신 DEV APK 설치 직전 Android 기기 연결이 해제됐고 Android SDK `adb devices`에도 연결 기기가 없었다. 따라서 앱 UI로 비개인정보 테스트 회원과 상태별 5건을 생성하거나, Beginner 달력·상세·overflow를 최신 코드로 육안 확인하지 못했다. 서버 콘솔이나 직접 Firestore 수정으로 우회하지 않았으며 이 항목은 완료로 처리하지 않는다.
- 배포 보호: 이번 작업에서는 Firebase CLI, Functions/Rules/인덱스 배포, Firebase 데이터 생성·수정·삭제를 실행하지 않았다. PROD `more-than-fitness-f6adb`에는 아무 Firebase 작업도 하지 않았고 PROD Debug APK는 로컬 회귀 빌드만 수행했다. 다음 백로그로 이동하지 않았다.

## 2026-07-20 Personal 레슨 인사이트 Pro gate·월간 더보기·비밀번호 UI

- 기존 회귀 원인: 직전 월간 달력 공개 작업에서 `blocksEntireStatsPage()`가 Personal workspace를 전체 gate 예외로 처리했고, `StatsPage.initState()`가 등급 확인이 끝나기 전에 `_loadStats()`와 `_loadMonthlyLessons()`를 함께 시작했다. Home과 MyPage도 Personal에서 공통 진입 gate 없이 `StatsPage`를 직접 push해 일반 모어댄/DEV Beginner 모두 페이지가 열릴 수 있었다.
- 진입점 감사: Home 하단 `HomeBottomNavBar`, `MtfAnimatedDrawer`, 홈의 주간 인사이트 callback은 모두 `_openThisWeekStats()`로 모인다. MyPage anchored 더보기는 `_openStatsPage()`를 사용한다. 저장소의 실제 `StatsPage` 생성 경로는 Home과 MyPage 두 곳이며 named route는 없었다. Debug legacy와 claim 기반 legacy/admin은 `personalOwnerUid`가 없는 기존 경로를 유지한다.
- canonical gate: `AppTierFeatureKey.lessonInsights`를 Pro rank 3으로 정의했다. Personal Home과 MyPage는 동일한 `AifcTierFeatureGateSheet.guard()`와 `loadPersonalTrainerAccess(uid)`를 사용한다. Beginner·Amateur·Semi-Pro는 AI FC 등급 안내를 표시하고 route를 열지 않으며 Pro·Master·Grand Prix만 허용한다. 빈 tier·알 수 없는 tier·조회 실패는 열지 않고 `등급 정보를 확인하지 못했어요.`를 표시한다.
- StatsPage 이중 방어: Personal 직접 route에서도 tier 확인 전 실제 schedules/members query를 시작하지 않는다. Pro 이상 확인 후에만 상품과 통계 query를 시작하고, Pro 미만은 전체 통계 화면을 차단한다. tier 조회 실패는 별도 오류 화면을 표시한다. Legacy/non-personal gate 정책은 유지한다.
- 명칭: Home 하단, Drawer, MyPage 더보기, StatsPage 제목·tooltip·등급 안내와 개인 등급 안내 문구를 `레슨 인사이트`로 통일했다. 내부 `StatsPage`, `stats_page.dart`, service/model 이름은 유지했다. 계약 동의의 일반 `통계 자료`와 Master·Grand Prix 센터/조직 문맥의 `운영 통계`는 범위와 기존 정책에 따라 유지했다.
- 첫 화면: Personal Pro의 StatsPage는 월간 달력을 제거하고 기존 기간 선택 → 핵심 요약 → 레슨 추이 → 회원 추이 → 수입 분석 순서로 복원했다. 우측 상단 기존 anchored 더보기 메뉴에 `월간 레슨 기록` 한 항목을 추가했다.
- 월간 화면: `MonthlyLessonHistoryPage`가 기존 `PersonalMonthlyLessonStatsRepository`와 `MonthlyLessonCalendar`를 재사용한다. StatsPage 진입만으로는 monthly repository를 만들거나 query하지 않으며 더보기 메뉴를 눌러 별도 화면을 연 뒤 Pro access를 다시 확인한 후에만 선택 월 query를 시작한다. 직접 월간 route의 비Pro 우회도 차단한다. owner/workspace/month query와 확정취소 집계·상세 snapshot 정책은 변경하지 않았다.
- 비밀번호 UI: 기존 페이지는 일반 회색 Scaffold/AppBar와 기본 Card·OutlineInputBorder 조합이라 Personal 온보딩 계열과 시각적으로 달랐다. `kOnboardingBg`, `kOnboardingPrimary`, `kOnboardingText`, `kOnboardingMuted`, `kOnboardingBorder`, 흰색 24px 카드와 15px 입력/버튼 모서리를 재사용했다. 인증·재인증·검증·재설정 메일·민감 입력 삭제 로직은 변경하지 않았다. 일반 진입 back 허용, `forced=true` back 차단과 로그아웃 동작을 유지했다.
- 검증: 관련 테스트 71개 통과 후 최종 진입점/비밀번호 관련 47개 통과. 최종 전체 Flutter 테스트 307개 모두 통과. 320/360/412dp와 text scale 1.0/1.3/1.8 비밀번호·메뉴·달력 overflow 테스트가 통과했다. 변경 범위 analyze에서 컴파일 오류는 없었고 기존 대형 Home/MyPage/Stats warning/info 126건으로 종료 코드는 1이었다. `git diff --check` whitespace 오류 없음.
- 빌드: DEV Debug `app-dev-debug.apk`, PROD Debug 회귀 `app-prod-debug.apk` 빌드 성공. DEV/PROD Release APK는 선택 검증으로 실행했으나 15분 이상 새 출력 없이 진행되어 종료했고 성공으로 기록하지 않는다.
- 실기기: Android SDK `adb devices`에 연결 기기가 없어 DEV Beginner의 AI FC Pro 안내, Pro 주입 첫 화면·더보기·달력, MyPage 비밀번호 화면을 실기기에서 확인하지 못했다. 미검증 상태로 유지한다.
- 보호: Firebase CLI 명령, Functions/Rules/Storage/인덱스 배포, DEV/PROD Firestore 데이터 조회·수정·삭제·초기화를 실행하지 않았다. PROD Firebase `more-than-fitness-f6adb`에는 아무 작업도 하지 않았고 로컬 APK 빌드만 수행했다. 다음 백로그로 이동하지 않았다.

## 2026-07-20 Amateur 승급 self-heal·레슨 편집 보존·헤더 피드백

- Amateur 조건과 기존 불일치: canonical 조건은 (1) `lifetimeQualifiedMemberCount >= 10`, (2) non-anonymous provider 연결과 선생님 내 정보 5개 필드 완료이다. 기존 `PremiumBannerWidget`의 2/2는 Home/MyPage가 전달한 일정 수와 클라이언트의 `trainerInfoDone`만 세어 실제 유효 회원 수와 provider 연결을 검증하지 않았다. 그래서 UI는 2/2인데 `trainer_profiles/{uid}.tier`는 Beginner인 모순이 생겼다.
- 서버 승급: v1 callable `reconcilePersonalTier`를 `asia-northeast3`, `maxInstances: 10`으로 추가했다. 현재 Auth UID의 personal profile만 transaction에서 읽고 위 조건을 직접 검증하며 Beginner만 Amateur로 올린다. 이미 Amateur 이상이면 유지하고 downgrade하지 않는다. `tier`, `tierUpdatedAt`, 최초 `amateurAchievedAt`, `tierTransitionSource=reconcilePersonalTier`만 갱신하며 반복 호출은 멱등이다.
- self-heal 호출: anonymous bootstrap 직후, linked personal 시작 직후, MyPage 프로필 저장 직후, 정식 회원 생성 성공 직후에 한 번 호출한다. 실패는 앱 시작을 막지 않고 `[MTF_TIER_RECONCILE]` 안전 로그만 남긴다. Home·Drawer·MyPage·기능 gate의 권위값은 계속 `trainer_profiles/{uid}.tier`이다.
- DEV 배포: `npx.cmd firebase deploy --only "functions:reconcilePersonalTier" --project more-than-fitness-dev-mft`를 실행했다. lint/build와 `reconcilePersonalTier(asia-northeast3)` 생성은 성공했다. 명령 최종 종료 코드는 Artifact Registry 이미지 정리 정책 자동 설정 실패 때문에 1이었으며 `--force`로 정책을 임의 변경하지 않았다. Rules, Storage, 인덱스는 배포하지 않았다.
- 레슨 편집 실제 원인: personal 실제 문서 ID는 `uid--` 접두사가 있지만 선택 날짜 target ID는 비스코프 ID로 비교해 `sourceIsRetained`가 false가 됐다. 이에 원본 요일을 포함해도 move/delete 분기로 들어가 기존 레슨이 사라졌고, 충돌 검사도 actual source ID와 data/duplicate ID를 모두 제외하지 않아 자기 자신을 충돌로 보았다.
- 레슨 편집 보정: actual target ID 생성 규칙을 Firestore 서비스와 공유하고 `HomeScheduleEditPlan`으로 `update`, `copyMany`, `move`, `replaceMany`를 명시했다. 원본 유지 분기에서는 source를 삭제 목록에서 제외하고 정확한 중복 문서만 제거한다. 원본 제거 분기는 모든 target write 성공과 같은 atomic commit에서만 source를 제거한다. 확정 레슨 보호와 기존 mutation guard는 유지했다.
- 충돌과 즉시 반영: 실제 DateTime 범위로 비교하고 actual source/data/duplicate ID, tombstone, deleted/pending 삭제 항목을 제외한다. atomic write 성공 직후 동일 callback에서 remove/upsert를 로컬 일정 상태에 patch한 뒤 시트를 닫고, 실패 시 로컬 상태를 바꾸지 않는다. `[MTF_SCHEDULE_EDIT_PLAN]`, `[MTF_SCHEDULE_CONFLICT]`, `[MTF_SCHEDULE_SAVE_RESULT]` 로그를 추가했다.
- 오류 안내 단일화: 시트가 `HomeLessonSaveResult.failureMessage`를 한 번만 표시하도록 하고, 동일 실패를 부모 Home의 `_showError` 또는 `_showActionToast`가 다시 표시하던 경로를 제거했다. 성공 안내는 성공 결과를 받은 부모에서만 표시한다.
- 헤더 원인과 정책: 잘못된 문구는 `HomeHeaderMessageEngine`의 빈 more-sense fallback `expanded_empty_flow`인 `오늘 회원 흐름은 비교적 편안해 보여요.`였으며 실제 오늘 레슨 수를 사용하지 않았다. `_countTodaySessions()`와 schedule ready 상태를 사용해 0/1~3/4~6/7~8/9~11/12+를 empty/light/steady/full/busy/veryBusy로 구분하고, 로딩 중에는 0으로 단정하지 않는다. 상단 FC 일반 문장은 변경하지 않았다.
- 자동 검증: Functions lint/build 통과. Auth/Firestore/Functions Emulator에서 Amateur reconcile을 포함한 33개 시나리오 통과. 관련 Flutter 테스트와 전체 Flutter 테스트 318개 통과. DEV Debug APK 빌드 성공. 변경 범위 analyze의 완료된 실행에는 컴파일 오류가 없고 기존 warning/info만 남았다. 최종 재실행은 환경에서 출력 없이 정지해 종료했으며 성공으로 중복 기록하지 않는다. `git diff --check`는 whitespace 오류 없이 통과했다.
- 실기기: 현재 `flutter devices`와 ADB에 Android 기기가 없어 2/2 승급 표시, 금→금+목 편집, 빈 목요일 14시, 즉시 반영, 단일 토스트, 9개 레슨 헤더를 최신 APK로 육안 확인하지 못했다. 자동 검증과 별개인 미검증 항목으로 유지한다.
- 보호: PROD `more-than-fitness-f6adb`에는 Firebase CLI, Functions/Rules/Storage/인덱스 배포, 데이터 조회·수정·삭제를 전혀 실행하지 않았다. PROD Debug APK는 앞선 회귀 빌드가 성공했지만 최종 변경 뒤 재실행은 901초 동안 출력 없이 정지해 timeout됐으므로 최종 빌드는 미검증으로 남긴다. 다음 백로그로 이동하지 않았다.

## 2026-07-21 DEV Personal 스케줄 저장 권한·신규 create 계획

- 재현 원인 1: `HomeScheduleEditPlan.resolve()`가 source ID가 빈 신규 시트를 별도 create로 구분하지 않고 단순히 `sourceIsRetained=false`로 계산했다. UI 로그가 `deleteSource=!retained`를 사용해 실제 원본이 없는데도 `branch=createOrUpdate`, `deleteCount=1`을 출력했다.
- create 계획 수정: source actual ID가 비면 `HomeScheduleEditBranch.create`, `deleteSource=false`, `deleteCount=0`으로 고정한다. 신규 단일·다중 target 모두 write만 만들며 비스코프 target이나 legacy ID를 삭제 후보로 합성하지 않는다. Personal repository가 만드는 신규 ID도 `uid--generatedId`로 범위를 고정했다.
- Rules 거부 원인: 기존 DEV schedules create Rule은 `scheduleId/schemaVersion/dateKey/slotKey/status/createdAt`을 필수로 요구하고 전체 key allowlist를 적용했다. 실제 canonical Home 저장은 `trainerId/workspaceType/startAt/endAt`과 기존 UI 필드 `day/time/endTime/typeName/typeId/attended`를 쓰며 필수 canonical 필드 일부와 createdAt이 없었다. 따라서 identity 필수 누락과 허용 목록 불일치로 own create가 거부됐다.
- 선택 아키텍처: Home의 실시간·오프라인·atomic multi-day 구조가 `HomeScheduleFirestoreService`의 client Firestore batch를 canonical로 사용하므로 callable 전환 대신 owner-scoped client CRUD를 유지했다. 서비스가 personal write에 path와 같은 `scheduleId`, 현재 UID `trainerId`, `workspaceType=personal`, `schemaVersion=1`, `dateKey`, `slotKey`, `status`를 보강한다.
- Rules 정책: create는 인증, `uid--` path, current UID trainerId, personal workspace, 유효 start/end, 제한된 실제 field allowlist와 member owner를 검사한다. update/delete는 기존·신규 owner/workspace 불변과 확정 레슨 잠금을 유지한다. 단건 get은 자기 UID path에서 삭제 후 부재 확인을 허용하고 list는 계속 `trainerId/workspaceType` owner query만 허용한다. 다른 UID와 ownerless legacy는 차단한다.
- source 검증: copyMany는 retained source ID를 삭제 검증 목록에서 분리하고 commit 후 `exists=true`를 확인한다. move/replace/delete source는 commit 후 `exists=false`를 확인한다. retained source가 존재하는 정상 copyMany를 `sourceStillExists`로 실패 처리하지 않는다. 삭제 후 단건 Source.server 부재 확인이 Rules에 막히지 않도록 get/list 권한을 분리했다.
- Emulator: `npx.cmd firebase emulators:exec --only firestore "npm.cmd run test:personal-schedule-rules" --project more-than-fitness-dev-mft`에서 26개 시나리오 통과. own anonymous/linked create·read·query·update·delete, other UID read/create/update/delete 차단, trainer/workspace 위조 차단, invalid range 차단, owner member link, unscoped ID 차단, Home legacy-compatible 필드, copyMany source/target 존재, move source 삭제, batch 전체 rollback, training_logs/contracts 미개방을 확인했다.
- DEV 배포: 최종 `firestore.rules`를 `npx.cmd firebase deploy --only firestore:rules --project more-than-fitness-dev-mft`로 컴파일·배포 완료했다. Functions, Storage, 인덱스는 배포하지 않았다.
- Flutter 검증: 관련 일정 테스트 42개 통과 후 source 정책 테스트 18개 통과. 전체 Flutter 테스트 320개 통과. 변경 범위 analyze는 새 컴파일 오류가 없고 기존 Home warning/info 56건과 이번 수정 전 발견한 unused local 1건이 있었으며 해당 신규 경고는 제거했다. 최종 DEV Debug APK `build/app/outputs/flutter-apk/app-dev-debug.apk` 빌드 성공. `git diff --check` whitespace 오류 없음.
- 실기기 미검증: `flutter devices`와 Android SDK `adb devices`에 Android 기기가 없었다. 따라서 PROD 앱 force-stop, DEV 신규 일정 저장·재실행 유지, 수→수+목, DEV-only 로그는 실행하지 못했으며 완료로 추측하지 않는다.
- PROD 보호: PROD `more-than-fitness-f6adb`에는 Firebase CLI 명령, Rules/Functions/Storage/인덱스 배포, Firestore 데이터 작업을 전혀 실행하지 않았다. 다음 백로그로 이동하지 않았다.
## 2026-07-21 DEV Personal Amateur 미션·첫 레슨 AI FC·기능 gate 통합

- 범위: Beginner→Amateur 기준을 `현재 UID 소유의 정상 Personal 일정 10개 + 기존 선생님 정보 5개 필드 완료` 두 미션으로 교체했다. 고객카드 수, `lifetimeQualifiedMemberCount`, provider 연결은 Amateur 판정에서 제외했고 Semi-Pro 이상 판정은 변경하지 않았다.
- 기존 오류 위치: `functions/src/tier_qualification.ts`의 `evaluateEarnedTier()`와 Home/MyPage의 서로 다른 로컬 진행률 계산이 고객카드 10명·provider 연결을 Amateur 조건으로 사용했다. 서버 `reconcilePersonalTier`와 `trainer_profiles/{uid}.personalTierProgress`를 유일한 진행률 기준으로 통일했다.
- 일정 집계: 서버 transaction에서 `schedules`를 `trainerId == context.auth.uid`, `workspaceType == personal`로 조회한다. tombstone, deleted, archived, voided, pending-delete 문서는 제외하고 실제 문서 하나를 1개로 센다. 미등록 이름 일정과 고객카드가 없는 일정도 포함한다. 수정·이동은 실제 문서 수가 늘지 않는 한 count를 늘리지 않는다.
- self-heal: 앱 시작 profile bootstrap 뒤, 신규 일정 서버 저장 성공 뒤, 여러 요일 신규 저장 성공 뒤, MyPage 선생님 정보 저장 성공 뒤에만 reconcile한다. 실패/pending write/build/profile snapshot에서는 호출하지 않는다. 10개 이상 기존 DEV 사용자도 다음 reconcile에서 현재 서버 문서로 즉시 재계산된다.
- Home/MyPage: `PersonalTierProgress`가 서버의 tier, scheduleCount/goal, 일정 미션, 선생님 정보 미션, 완료 수/전체 수를 동일하게 읽는다. Beginner 배너와 AI FC 등급 안내 문구를 `레슨 일정 10개 + 선생님 정보 입력`으로 교체했다.
- 첫 레슨 안내: `HomeFirstLessonGuideChatSheet`는 기존 `AifcSheetFrame`, `AifcChatFlowMixin`, `AifcChatBubble`과 선택 카드 전환을 재사용한다. 최초 정상 신규 Personal 일정 저장 뒤 `claimFirstLessonGuide`가 현재 저장에서 생성된 문서 수와 서버 전체 문서 수가 정확히 같을 때만 프로필의 `aiFcNudge.firstLessonGuideShown`을 transaction으로 선점한다. 단일·멀티요일 최초 저장 모두 한 번만 표시하며 실패, 수정, 이동, 복사, 기존 일정 로딩, cache snapshot에서는 표시하지 않는다.
- 고객카드 gate: `AppTierFeatureKey.customerCardCreate` 최소 등급을 Amateur로 정의했다. Home 최근 회원 CTA, 전체 등록, 빠른 등록, 미등록 일정 연결, 회원관리 신규 등록, 직접 신규 고객카드 화면, 첫 레슨 안내가 모두 `AifcTierFeatureGateSheet`를 사용한다. `createManagedMember`도 Beginner 요청을 `amateur_required`로 차단한다. 기존 고객카드 조회는 변경하지 않았다.
- 최근 회원 빈 상태: 큰 흰색 빈 카드를 제거하고 기존 AI FC 아이콘과 `오! 아직 등록한 회원이 없어요. 고객카드 등록 도와드릴까요?` 경량 CTA를 사용한다. 회원이 있으면 기존 최근 회원 UI를 유지한다.
- 레슨 인사이트: Personal Beginner·Amateur·Semi-Pro는 Home, Drawer/주간 callback, MyPage, 직접 `StatsPage`, 직접 월간 기록 경로에서 Pro gate를 거친다. StatsPage는 tier 확인 전에 일정/회원/training_logs query를 시작하지 않는다. Pro·Master·Grand Prix만 전체 레슨 인사이트에 접근한다. 사용자 진입 명칭은 `레슨 인사이트`로 통일했고 계약 동의서의 일반 통계 문구와 Master 센터 운영 통계 문맥은 유지했다.
- 공통 gate: 상담에서 사용하던 `AifcTierFeatureGateSheet`를 고객카드, 신규 계약, 상담, 레슨 인사이트의 공통 UI로 사용한다. feature/currentTier/requiredTier/result/entryPoint를 `[MTF_TIER_GATE]`로 기록하며 별도 SnackBar·Dialog 중복 안내를 제거했다.
- Functions 검증: `npm.cmd --prefix functions run lint`, `npm.cmd --prefix functions run build` 통과. Auth/Firestore/Functions Emulator를 `--project more-than-fitness-dev-mft`로 실행해 36개 시나리오를 통과했다. 0/2, 1/2, 2/2 승급, 익명 2/2 승급, 상위 등급 비강등, 다른 UID 격리, Beginner 고객카드 차단, 첫 안내 단일·멀티요일 1회 및 기존 사용자 지연 표시 차단을 확인했다.
- Flutter 검증: 관련 테스트 7개 통과, 전체 `flutter test --no-pub -r expanded` 329개 통과. 변경 범위 analyze에 새 compile error 없음(기존 대형 화면의 warning/info는 유지). DEV Debug `app-dev-debug.apk`, PROD 공통 코드 회귀 Debug `app-prod-debug.apk` 빌드 성공. `git diff --check` whitespace 오류 없음.
- DEV 배포: `reconcilePersonalTier`, `claimFirstLessonGuide`, `createManagedMember`, `updatePersonalTrainerProfile`, `transitionAnonymousProfileToLinked` 5개만 `more-than-fitness-dev-mft`에 선택 배포했다. 다섯 함수의 create/update는 모두 성공했으나 Artifact Registry cleanup policy 미설정 때문에 CLI 최종 종료 코드는 1이었다. `--force`나 별도 cleanup policy 변경은 수행하지 않았다. Rules, Storage, index는 배포하지 않았다.
- 실기기: Android SDK에서 연결 기기가 0대로 확인되어 DEV의 10개 일정 self-heal, 첫 안내, 고객카드 gate, 최근 회원 빈 CTA, Pro gate를 최신 APK로 육안 검증하지 못했다. 자동 검증으로 대체하지 않았으며 미검증으로 유지한다.
- PROD 보호: PROD Firebase CLI, Functions/Rules/Storage/index 배포, Firestore 조회·수정·삭제를 수행하지 않았다. PROD는 로컬 Debug APK 회귀 빌드만 수행했다. 다음 백로그로 이동하지 않았다.

## 2026-07-21 DEV 등급 안내·Amateur 일정 미션·선생님 정보 검증

- 범위: Personal 등급 안내의 교체형 상세, 반응형 overflow, 현재 정상 Personal 일정 10개 미션, Beginner→Amateur 축하 1회, MyPage 선생님 정보 입력·검증만 수정했다. 고객카드 Amateur gate와 레슨 인사이트 Pro gate를 유지했고 다음 백로그로 이동하지 않았다.
- 누적 원인/교체 구조: `AifcTierGuideChatSheet._handleTierSelected()`가 등급 선택마다 `aifcUserThenFc`로 사용자·AI 메시지를 목록에 추가해 설명이 누적됐다. 선택은 이제 `_selectedTierName`만 바꾸고, 최초 AI FC 말풍선 아래의 단일 `_TierDetailCard`를 `AnimatedSwitcher` 240ms fade/slide로 교체한다. 선택만으로 메시지 수나 스크롤 요청이 늘지 않는다.
- overflow 원인/수정: 320dp·글자 배율 1.8에서 `_TierSelectCard` 칩의 `Row(mainAxisSize: min)` 자식 합계가 가용 너비를 약 3.7px 넘었다. 등급 텍스트를 `Flexible`로 감싸고 selector를 `Wrap` pill 구조로 만들었다. 현재 진행 항목은 고정 너비 Row 대신 아이콘 + `Expanded` 세로 label/value를 사용한다. 시트는 `SafeArea`, 높이 90%, 내부 스크롤과 하단 버튼 분리를 유지한다.
- 진행률 정책: Beginner 일정 미션은 `trainerId == currentUid`, `workspaceType == personal`인 서버 문서 중 삭제·archived·voided·tombstone·pending-delete가 아닌 현재 정상 일정의 실제 문서 수다. 이름만 있는 미등록 일정도 포함한다. 0~9는 미완료, 10 이상은 완료이며 승급 전 10→9/8 감소는 즉시 미완료로 돌아간다. Amateur 이상으로 실제 승급한 뒤에는 일정 감소로 강등하지 않는다.
- reconcile 연결: 정상 서버 쓰기 성공 뒤 신규/다중 생성·단일/다중 삭제·요일 제거가 포함된 edit batch·전체 주 삭제에서 `reconcilePersonalTier`를 호출한다. MyPage 저장과 앱 시작 self-heal은 기존 경로를 유지한다. 실패/pending write/build 반복에서는 호출하지 않고, reconcile 자체 실패가 성공한 일정 mutation을 실패로 되돌리지 않는다.
- 승급·축하: 기존 `lib/aifc/home/aifc_tier_celebration_sheet.dart`의 avatar·색상·애니메이션·sheet 구조를 재사용해 `AifcTierUpgrade.beginnerToAmateur`를 추가했다. 서버가 Beginner→Amateur로 실제 전환할 때만 stable transition ID를 프로필에 기록한다. 신규 `claimTierCelebration` transaction이 현재 UID의 transition을 한 번만 claim하고 `lastCelebratedTierTransitionId`를 기록하므로 앱 재실행·다른 기기에서도 반복되지 않는다. 기존 Amateur 또는 후원만 있는 사용자는 transition이 없어 표시하지 않는다.
- 선생님 정보 canonical 5개: `realName`, `jobTitle`, `primaryActivity`, `affiliationType`, `activityRegion`. 전화번호와 생년월일은 선택값이며 미션 필드에 추가하지 않았다. 서버가 다섯 값을 직접 검증해 `teacherInfoCompleted`를 판정하고 클라이언트가 완료 값을 직접 쓰지 않는다.
- 검증 정책: 실명은 공백 정리 후 2~20자 한글 완성형/영문/공백, 자모·숫자·기호 단독을 거부한다. 직무는 2~30자이며 한글/영문/숫자와 제한된 구분 문자를 허용하고 의미 문자가 있어야 한다. 주 활동 종목도 2~30자 의미 문자를 요구한다. 소속은 `freelancer|center|personal_shop` 중 하나다. 클라이언트와 `updatePersonalTrainerProfile`/tier 판정이 같은 정책을 사용하며 실제 값 없는 `[MTF_PROFILE_VALIDATION]` 로그를 남긴다.
- 지역/전화/생년월일: 활동 지역은 시·도→시·군·구 picker에서 선택해 기존 `activityRegion` 한 필드에 `서울특별시 강남구` 형태로 저장한다. 전화는 기존 `MemberPhoneInputFormatter`와 국내 이동전화 검증을 재사용해 숫자 키보드·자동 하이픈을 제공한다. 생년월일은 기존 formatter/정규화와 DatePicker를 재사용해 `YYYY-MM-DD`, 실제 날짜·미래 날짜를 검증하고 기존 `birth` 필드만 저장한다.
- Personal legacy query: `ClientListPage`의 personal 프로필 이름은 `trainer_profiles/{uid}`만 읽고 `trainer_profile/me` fallback을 시작하지 않는다. personal 그룹 초기화는 unscoped `member_groups` query를 시작하지 않고 로컬 기본 분류만 사용한다. Debug legacy workspace의 기존 조회는 유지했다.
- 로그: 등급 선택, Home/MyPage/등급 안내 진행률, 일정 mutation 후 reconcile, tier transition, 축하 claim, 프로필 필드별 검증에 요청된 `[MTF_*]` 안전 로그를 추가했다. 전화번호·생년월일·프로필 실제 값은 출력하지 않는다.
- 자동 검증: 관련 Flutter 테스트 42개 통과. 전체 `flutter test --no-pub -r expanded` 345개 모두 통과. Functions lint/build 통과. DEV Auth/Firestore/Functions Emulator 회원·등급 38개와 닉네임·프로필 16개 시나리오가 통과했다. 10→9 감소, 10+정보 완료 승급, 상위 등급 비강등, 축하 claim 1회, 다른 UID 격리를 포함한다.
- 반응형: 320/360/412/480dp × 글자 배율 1.0/1.3/1.8의 12개 조합에서 오른쪽 overflow·상단 잘림 없이 하단까지 스크롤 가능한 것을 widget test로 확인했다.
- analyze/build/diff: 변경 범위에 새 컴파일 오류는 없었다. 기존 대형 Home/MyPage/회원관리/축하 파일에 남아 있던 warning/info 191건 때문에 analyze 종료 코드는 1이었다. DEV Debug `app-dev-debug.apk`와 PROD 공통 코드 회귀 Debug `app-prod-debug.apk` 빌드는 성공했고 `git diff --check`는 whitespace 오류 없이 통과했다.
- DEV 배포: `reconcilePersonalTier`, `updatePersonalTrainerProfile`, 신규 `claimTierCelebration` 세 함수만 `npx.cmd firebase deploy --only "functions:reconcilePersonalTier,functions:updatePersonalTrainerProfile,functions:claimTierCelebration" --project more-than-fitness-dev-mft`로 선택 배포했다. 세 함수의 create/update는 모두 성공했다. Artifact Registry cleanup policy 미설정 후처리 때문에 CLI 최종 종료 코드는 1이었으며 `--force`나 정책 변경은 실행하지 않았다. Rules, Storage, index는 배포하지 않았다.
- 실기기: `flutter devices`에 Windows/Chrome/Edge만 있고 Android 기기가 없었다. 따라서 DEV 등급 교체·8/10→10/10→9/10, 실제 승급·축하 1회, MyPage picker/formatter는 최신 APK로 육안 검증하지 않았고 성공으로 추측하지 않는다.
- PROD 보호: PROD `more-than-fitness-f6adb`에는 Firebase CLI 명령, Functions/Rules/Storage/index 배포, 데이터 조회·수정·삭제를 전혀 실행하지 않았다. PROD는 로컬 Debug APK 빌드만 수행했다.

## 2026-07-21 MyPage 편집 UX·등급 표시·Personal 진입 보완

- MyPage 헤더: `내 정보와 활동 현황을 관리합니다` 부제목과 그 간격을 제거했다. 제목 행을 단일 텍스트로 정리하고 상·하단 및 다음 카드 간격을 함께 줄여 접힘/펼침 모두 기존 대비 약 33 logical pixel 낮아지는 구조로 조정했다.
- 키보드/저장: 본문 위에 뜨던 `FloatingActionButton`을 `Scaffold.bottomNavigationBar + SafeArea`의 52px 저장 버튼으로 교체했다. `resizeToAvoidBottomInset=true`, 본문 `ScrollController`, drag keyboard dismiss와 각 입력의 88px `scrollPadding`으로 키보드가 열릴 때 버튼은 키보드 위에 남고 활성 입력은 가려지지 않게 했다.
- dirty/초안: realName, nameEn, nickname, gymName, activityArea, jobTitle, birth, 숫자 정규화 phone, intro, primaryActivity, contract custom name, affiliationType, gender, contract name source를 정규화한 최초값과 비교한다. 상단/시스템/제스처 back은 같은 `PopScope`로 `저장하고 나가기 / 임시로 보관하고 나가기 / 저장하지 않고 나가기 / 계속 작성하기`를 처리한다. 초안은 `mtf_{projectId}_{uid}_my_page_profile_draft_v1` 범위의 SharedPreferences에만 저장하며 서버와 다른 UID/환경에는 쓰지 않는다.
- 오프라인: unavailable/deadline/network-request-failed/UnknownHost 계열은 `인터넷 연결을 확인해주세요.` 한 안내로 처리한다. 성공 토스트와 페이지 종료를 막고 현재 입력을 유지하며 로컬 임시 보관을 제안한다. profile load 실패 시 빈 profile 저장을 성공으로 처리하지 않는다.
- 비정상 과거 profile: 기존 controller 값은 그대로 보여주고 Form validator를 첫 진입 후 실행해 `선생님 정보 중 확인이 필요한 항목이 있어요.`를 한 번 안내한다. 선택 전화/생년월일은 비우면 허용하고 값이 있으면 기존 validator를 통과해야 저장된다. 자동 삭제/backfill 및 등급 강등은 없다.
- Amateur 진행률: 원인은 서버 raw `teacherInfoCompleted=false`, `completedMissionCount=1`을 Home/MyPage/등급 안내에 그대로 전달한 것이었다. `PersonalTierProgress`에 earned 표시값을 추가해 canonical tier가 Amateur 이상이면 Beginner 미션은 2/2 달성 완료로 표시한다. raw 값은 진단에 유지하고 미완성 정보는 별도 확인 안내로 분리했다. 고객카드 Amateur gate와 인사이트 Pro gate는 유지했다.
- MORE 비즈니스: profile의 기존 MORE business 연결 필드만 source로 사용한다. 탭 후 900ms `연결할 플레이스를 찾고 있어요` 로딩을 표시하고, 연결 없음은 MyPage 위 empty 안내, profile 조회 실패는 오류 안내로 구분한다. 실제 연결 필드가 있는 경우에만 기존 화면을 열며 가짜 요청/새 collection/빈 route를 만들지 않는다.
- 계약서 gate: `ContractListPage`의 +/빈 상태 신규 작성이 `AppTierFeatureKey.contract`와 `AifcTierFeatureGateSheet`를 사용한다. Personal 신규 `ContractPage`도 direct create 진입에서 다시 검사해 Beginner/Amateur는 차단하고 Semi-Pro 이상만 허용한다. 기존 계약서 조회/편집은 변경하지 않았다.
- 오늘 이동: Home 외부 스크롤 controller와 스케줄 section key를 추가했다. 오늘 탭 시 현재 주와 전체 7일 필터를 복원하고 스케줄 section으로 이동한 뒤 오늘의 다음 레슨 시간, 없으면 현재 시간, 범위 밖이면 06:00~22:00의 가까운 행을 세로 중앙 근처로 맞춘다. 주간 표는 7일 열이 한 viewport에 표시되는 기존 구조를 유지하고 route는 열지 않는다. semantic label은 `오늘 일정으로 이동`이다.
- 인사이트 명칭: Personal 사용자 화면의 Home 하단, Drawer, MyPage 더보기, Stats AppBar/tooltip, gate/업그레이드/월간 안내를 `인사이트` 및 AppBar `MORE 인사이트`로 변경했다. 내부 `AppTierFeatureKey.lessonInsights`와 Pro gate, 계약서/센터의 일반 통계 문맥은 유지했다.
- 회원권 안내: 이름 앞뒤 공백과 끝의 `님`/` 님`을 정리해 `김유리님의 회원권을 살펴볼게요.\n어떤 작업이 필요하신가요?` 형태로 표시한다. 빈 이름은 `회원님의...`을 사용하고 회원권 저장 로직은 변경하지 않았다.
- 인바디 권한: 기존 흐름은 ImagePicker 파일을 ML Kit Korean TextRecognizer로 기기에서 OCR한 뒤 검토 화면을 열고, 사용자가 `인바디 이미지도 저장`을 선택한 경우에만 Storage 업로드를 수행한다. 이 사실만 사전 안내에 반영했다. projectId+Auth UID 범위 안내 완료 키, Android CAMERA 권한 MethodChannel의 check/request/permanentlyDenied/openSettings를 추가했고 카메라 선택에만 적용해 갤러리는 유지했다. 새 패키지는 추가하지 않았다.
- 검증: 관련 테스트 51개와 최종 Home/gate/MyPage 25개 및 MyPage 20개가 각각 통과했다. 최종 전체 `flutter test --no-pub -r expanded` 355개 모두 통과했다. 변경 범위 analyze에는 새 compile error가 없고 기존 대형 파일 warning/info 때문에 종료 코드는 1이었다. DEV Debug `app-dev-debug.apk`, PROD Debug 회귀 `app-prod-debug.apk` 빌드 성공. `git diff --check` whitespace 오류 없음.
- 실기기: `flutter devices`에는 Windows/Chrome/Edge만 있고 Android 기기가 없어 13개 DEV 수동 항목은 미검증으로 남겼다. 성공으로 추측하지 않았다.
- Firebase/PROD 보호: Functions, Firestore/Storage Rules, index, Firebase CLI 및 DEV/PROD 데이터 작업은 실행하지 않았다. PROD `more-than-fitness-f6adb`는 Firebase 조회도 하지 않았고 로컬 PROD Debug APK 회귀 빌드만 수행했다. 다음 백로그로 이동하지 않았다.

## 2026-07-21 MyPage 소속별 정보·활동 지역 3곳·영문 이름 검증

- canonical 확인: 저장소의 실제 `affiliationType`은 `freelancer`, `center`, `personal_shop` 세 값이고 영문 이름 필드는 `nameEn`, 센터명은 기존 MyPage의 `gymName`이다. 새 소속 enum 문자열은 추가하지 않았다. personal 읽기에서 `jobTitle` 부재 시 `affiliationType=freelancer`를 직책처럼 fallback하던 경로를 제거해 프리랜서를 자동 직책으로 저장하지 않게 했다.
- 소속별 폼: `center`와 `personal_shop`은 센터명 → 센터 위치 → 직책 → 주 활동 종목 순서이며 직책을 필수로 유지한다. `freelancer`와 아직 소속을 고르지 않은 상태는 직책 선택 행 → 주 활동 종목 → `센터 정보 추가 (선택)` 접힘 영역 순서다. 저장된 직책이나 센터 정보가 있으면 해당 선택 영역을 처음부터 펼친다. 직책과 센터 정보를 지우면 다시 접을 수 있고 롱프레스는 사용하지 않는다.
- 완료 판정: 모든 소속은 유효한 `realName`, `primaryActivity`, `affiliationType`, 활동 지역 1곳 이상을 요구한다. `center|personal_shop`만 유효한 `jobTitle`을 추가로 요구하고 `freelancer`는 빈 직책을 허용하되 입력값이 있으면 기존 2~30자 형식 검증을 적용한다. Flutter validator와 Functions의 `isTrainerProfileComplete()`가 같은 조건을 사용한다. `reconcilePersonalTier`는 기존처럼 Beginner만 승급하고 Amateur 이상을 강등하지 않는다.
- 지역 스키마: `activityRegions`는 정규화된 문자열 배열 1~3개이며 첫 항목이 대표다. `activityRegion`은 첫 항목으로 mirror한다. 배열이 없는 과거 문서는 기존 `activityRegion`을 1개 배열로 읽고, 다음 정상 저장에서 배열을 함께 기록한다. 기존 필드는 삭제하거나 일괄 backfill하지 않았다. 중복·4번째·허용 목록 밖 조합은 Flutter와 Function에서 차단한다.
- 지역 UX: 시·도 → 시·군·구 picker로 추가하며 칩 탭 바텀시트에서 대표 설정·변경·삭제·취소를 제공한다. 대표 변경은 선택 항목을 배열 첫 번째로 이동하고, 대표 삭제 뒤에는 남은 첫 항목이 자동 대표가 된다. 3곳이면 추가 버튼 대신 `최대 3곳까지 등록할 수 있어요.`를 표시한다. Business Card는 대표 지역 우선 `대표 외 N곳`으로 요약하고 센터 정보가 없으면 기본 센터명을 임의 표시하지 않는다.
- 영문 이름: `nameEn`은 선택값이다. 입력 시 trim과 연속 공백 한 칸 정규화를 적용하고 2~40자 A-Z/a-z, 공백, 하이픈, 아포스트로피만 허용하며 영문자가 최소 1개 있어야 한다. 한글 완성형·자모·숫자·기타 기호·`---`는 저장 전에 차단하고 오류 필드로 스크롤한다. `updatePersonalTrainerProfile`도 같은 규칙으로 `name_en_invalid`를 반환하며 실제 입력값은 로그에 남기지 않는다.
- 안전 로그: 실제 개인정보 없이 `[MTF_PROFILE_FIELD_POLICY]`, `[MTF_ACTIVITY_REGIONS]`, `[MTF_PROFILE_VALIDATION]`에 category/count/present/result/errorCode만 기록한다.
- 자동 검증: 관련 Flutter 테스트 32개와 최종 관련 테스트 29개 통과. 최종 전체 `flutter test --no-pub -r expanded` 361개 모두 통과. Functions lint/build 통과. `--project more-than-fitness-dev-mft`를 명시한 Auth/Firestore/Functions Emulator에서 프로필 22개 시나리오가 통과했다. 프리랜서 빈 직책 완료, 센터 빈 직책 미완료, 3개 지역 저장·대표 mirror, 중복·4번째 차단, 영문 이름 차단을 확인했다.
- analyze/build/diff: 변경 범위에 컴파일 오류는 없었다. 기존 `my_page.dart`의 warning/info 57건 때문에 analyze 종료 코드는 1이었다. DEV Debug `app-dev-debug.apk`와 PROD 공통 코드 회귀 `app-prod-debug.apk` 빌드 성공. `git diff --check` whitespace 오류 없음.
- DEV 배포: `npx.cmd firebase deploy --only "functions:updatePersonalTrainerProfile,functions:reconcilePersonalTier" --project more-than-fitness-dev-mft`를 실행했다. 두 v1 callable의 `asia-northeast3` update는 모두 성공했다. Artifact Registry cleanup policy 자동 설정 실패 때문에 CLI 최종 종료 코드는 1이었고 `--force`나 별도 cleanup policy 변경은 실행하지 않았다. Rules, Storage, index는 배포하지 않았다.
- 실기기/보호: `flutter devices`에는 Windows/Chrome/Edge만 있고 Android 기기가 없어 최신 DEV APK의 조건부 폼·바텀시트·지역 칩·오류 스크롤을 육안 확인하지 못했다. PROD `more-than-fitness-f6adb`에는 Firebase CLI, Functions/Rules/Storage/index, 데이터 조회·수정·삭제를 전혀 실행하지 않았고 로컬 PROD Debug APK만 빌드했다. 다음 백로그로 이동하지 않았다.

## 2026-07-21 — Android 오늘 레슨 롤업 홈 위젯

- 범위: 직전 MyPage 프로필 변경은 건드리지 않고 신규 `오늘 레슨 롤업` Android Glance 위젯만 추가했다. 기존 주간 위젯과 다음 레슨 위젯의 provider, 렌더링, 저장 키는 유지했다.
- 데이터 출처: Home과 personal schedule이 이미 공유하는 `HomeWidgetPreviewSyncPayload.lessons`를 사용한다. Firestore 직접 조회나 새 서버 경로는 추가하지 않았으며, 현재 공통 payload에 없는 확정 상태·통계는 추측해 표시하지 않는다.
- 스냅샷: 레슨 시작 epoch, 회원명, 레슨 종류만 JSON으로 시간순 저장한다. Android 위젯이 현재 로컬 날짜를 기준으로 다시 필터링하므로 `DATE_CHANGED`, 시간/시간대 변경, 30분 갱신에서 앱을 열지 않아도 오늘 목록이 바뀐다.
- UI: `오늘 레슨`, 현재 날짜, 총 개수, 시간순 최대 4개(`시간 / 회원명 · 레슨 종류`), 초과 개수, 0건 빈 상태를 표시한다. 위젯 탭은 기존처럼 앱을 연다.
- 격리: personal owner UID가 바뀌거나 linked 로그아웃 시 기존 `clearPersonalScheduleData()`가 롤업 JSON도 `[]`로 비우고 세 위젯을 갱신한다. Guest/PROD Firebase 조회 또는 별도 fallback은 추가하지 않았다.
- 수정 파일: `lib/services/home_widget_today_rollup_mapper.dart`, `lib/services/home_widget_preview_sync_service.dart`, `lib/services/mtf_home_widget_service.dart`, `android/app/src/main/kotlin/com/example/mtf_app/MtfTodayLessonRollupWidget.kt`, `MtfTodayLessonRollupWidgetReceiver.kt`, `MtfWidgetWeekRolloverReceiver.kt`, `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/res/xml/mtf_today_lesson_rollup_widget_info.xml`, `android/app/src/main/res/values/strings.xml`, `test/home_widget_today_rollup_mapper_test.dart`.
- 검증: 변경 Dart 파일 format 완료. Manifest/provider/strings XML 파싱 통과. `git diff --check` 통과(기존 CRLF 안내만 출력). 첫 Kotlin 컴파일에서 `defaultWeight` import와 문자열 보간 오류 2건을 확인해 수정했다.
- 미검증: 관련 Flutter 테스트는 180초, 변경 범위 `dart analyze`는 120초 동안 출력 없이 시간 초과했다. Kotlin 재컴파일은 시스템 가용 메모리 부족으로 Gradle single-use daemon이 같은 원인으로 3회 시작 실패해 중단했다. 따라서 전체 Flutter 테스트와 DEV Debug APK, 실기기 위젯 렌더링은 통과로 기록하지 않는다.
- 배포/데이터: Firebase CLI, Functions, Firestore/Storage Rules, DEV/PROD 배포, PROD 데이터 작업을 실행하지 않았다. 다음 백로그로 이동하지 않았다.

## 2026-07-21 — 오늘 레슨 롤업 최초 요구 대조·컴파일 복구

- 최초 구현 차이: 기존 구현은 `startAt/memberName/lessonType` 배열을 당일 시간순 최대 4개로 같은 모양으로 표시했다. `endAt`, 진행 중 우선, 종료·삭제 상태 제외, 다음/다다음/세 번째 이후 분리, 잔여 횟수, owner/workspace, payload 생성 날짜, cold/warm 위젯 탭 action이 없었다. `HomeWidgetPreviewSyncService`는 이름과 달리 Home schedule snapshot과 personal repository 양쪽의 운영 동기화에서 실제 호출되는 canonical fan-out 경로임을 확인했다.
- 최종 구조: 헤더에 오늘 날짜와 남은 레슨 수를 표시한다. `startAt <= now < endAt`인 진행 중 레슨을 첫 카드로 우선하고 없으면 가장 가까운 미래 레슨을 다음으로 사용한다. 두 번째는 다다음, 세 번째부터는 `오늘 남은 일정`에 위젯 높이별 2~4개를 표시하며 초과분은 `외 N개`로 표시한다. 동일 배열을 `first`, `second`, `skip(2)`로 분리해 중복하지 않는다. 0개는 `오늘 남은 레슨이 없어요.`다.
- 필터·개인정보: 현재 owner UID의 `workspaceType=personal`, payload 생성일이 오늘, 일정 시작일이 오늘, `endAt > now`인 항목만 표시한다. `deleted|archived|voided|tombstone`은 제외하고 빈 회원명은 `미등록 일정`으로 허용한다. 저장 필드는 시작/종료 epoch, 회원 표시명, 레슨 종류, 선택 잔여 횟수, status뿐이며 전화번호·생년월일·주소·건강 정보·메모·계약 금액은 롤업 payload에 넣지 않는다.
- owner·환경 분리: payload key는 기존 provider와 겹치지 않는 `mtf_widget_today_rollup_items_v1`, owner key는 기존 `mtf_widget_personal_owner_uid`다. owner 불일치·빈 owner·non-personal·어제 생성 payload는 Android와 Dart mapper 모두 빈 결과다. DEV `com.example.mtf_app.dev`와 PROD `com.example.mtf_app`은 Android application sandbox가 달라 같은 key 문자열이어도 저장소가 분리된다. UID 전환·로그아웃은 기존 `clearPersonalScheduleData()`에서 롤업을 `[]`로 비우고 전체 provider를 갱신한다.
- update trigger: 앱 시작 `HomePage.initState`, owner-filtered schedule snapshot, foreground resume/route 복귀, 신규·멀티 저장, 수정·시간 이동, 삭제, 주 붙여넣기, 확정/취소 성공 뒤의 기존 `_queueHomeWidgetSync()` 또는 `_syncHomeWidgetPreview()`를 사용한다. 날짜 변경 후 앱 복귀에서도 즉시 재생성한다. Android `DATE_CHANGED/TIME_SET/TIMEZONE_CHANGED` 수신 시 stale 생성일 payload는 빈 상태가 되고 위젯을 갱신한다. Firestore를 위젯에서 직접 읽지 않는다.
- deep link: `MtfTodayLessonRollupWidget`이 `mtf_widget_action=today`를 `MainActivity`에 전달한다. `MainActivity`의 `widget_navigation` MethodChannel은 cold start pending action과 warm `onNewIntent`를 한 번만 consume한다. `HomeWidgetNavigationService`가 이를 받아 기존 `_openTodayScheduleFocus()`를 호출한다. 이 메서드는 기존 현재 주·전체 요일·오늘 시간대 계산을 재사용하고 마지막에 `오늘 다음 레슨` 섹션을 상단 헤더 아래에 정렬한다.
- provider: 기존 `MtfScheduleWidgetReceiver`, `MtfNextLessonWidgetReceiver` class와 provider XML은 변경하지 않았다. 신규 `MtfTodayLessonRollupWidgetReceiver`, `mtf_today_lesson_rollup_widget_info.xml`, Manifest receiver를 별도로 유지한다. merged DEV/PROD Debug Manifest에서 세 receiver가 모두 함께 존재함을 확인했고 사용자 이름은 `모어댄 주간 일정`, `모어댄 다음 레슨`, `모어댄 오늘 레슨`이다.
- 최초 Kotlin 오류 2건: 첫 compile의 실제 오류는 `MtfTodayLessonRollupWidget.kt:25:31 Unresolved reference 'defaultWeight'`와 `:120:35 Unresolved reference 'hiddenCount개'`였다. 존재하지 않는 top-level import를 제거하고 Row scope의 `defaultWeight()`를 사용했으며, 문자열을 `+${hiddenCount}개`로 명시 보간했다.
- Gradle 실패 원인과 해결: 16,125MB 시스템에서 기존 `org.gradle.jvmargs=-Xmx8G`, Kotlin daemon `-Xmx8G`, 활성 DEV `flutter run`이 동시에 존재해 가용 메모리가 868MB까지 내려갔다. 잔여 Gradle/Kotlin daemon만 종료하고 활성 Flutter 실기기 세션은 건드리지 않았다. `android/gradle.properties`를 Gradle 3GB/metaspace 1GB/code cache 256MB, worker 2개, Kotlin 1.5GB/metaspace 512MB로 제한했다. 이후 Kotlin compile, `processDevDebugMainManifest`, `mergeDevDebugResources`가 성공했다.
- Flutter 무출력 원인: sandbox 안의 Dart CLI가 `C:\Users\morethan\AppData\Roaming\.dart-tool` 생성 권한을 얻지 못해 `PathAccessException (errno=5)`이 났으나 wrapper 호출에서 출력되지 않아 정체처럼 보였다. 실제 Dart/Flutter 실행 파일을 정상 권한으로 실행하자 포맷 4.2초, 관련 테스트 20.6초에 완료됐다. 새 Timer/Stream/MethodChannel 대기가 원인이 아니었다.
- 테스트·분석: mapper 0/1/2/3/6개, 진행 중, 종료 제외, 삭제 계열 제외, 미등록 이름, 선택 잔여 횟수, 긴 이름/종류, 다음/다다음/세 번째 분리·중복 없음, UID/workspace/stale 차단과 cold pending action consume를 포함한 관련 10개 통과. 최종 전체 Flutter 테스트 371개 모두 통과. 변경 범위 analyze 신규 compile error는 0개이며 기존 `home_page.dart` warning/info 59건으로 종료 코드 1이다. `git diff --check` 통과했다.
- 빌드·실기기: 최종 DEV Debug `app-dev-debug.apk`, PROD Debug `app-prod-debug.apk` 모두 성공했다. `flutter devices`에는 Windows/Chrome/Edge만 있고 Android 기기가 없어 런처 목록, 렌더링, 실제 등록·수정·삭제 갱신, 진행 중, 탭 cold/warm을 실기기에서 확인하지 못했다.
- 보호: Firebase CLI, Functions, Firestore/Storage Rules/index를 실행·변경·배포하지 않았다. PROD Firebase project 및 PROD 데이터에 조회·수정·삭제·초기화를 하지 않았다. 일반 PROD 앱을 삭제하지 않았고 다음 백로그로 이동하지 않았다.

## 2026-07-21 — PROD 반영 전 알림·등급 진단 로그 정리

- 개인정보 로그 원인: `notification_service.dart`의 `_debugLessonLabel()`이 Smart Alarm 판정 문자열에 `ScheduleItem.name`과 레슨 종류를 직접 합쳐 `INCLUDE/SKIP ... · 이름 종류`로 출력했다. 해당 label 생성을 제거하고 시간, 판정, 사유, gap, 레슨 종류/회원명/memberId 존재 여부만 남겼다.
- 추가 안전 정리: Smart Alarm 회원 보조 필드 로그의 memberId 원문을 `memberIdPresent`로 바꾸고, 알림 예약 ID는 존재 여부만 남겼다. 알림 설정 로드 예외의 원문 문자열 대신 Firebase code 또는 runtimeType만 기록한다. `MTF_WIDGET`/Android 위젯 코드에서는 일정 개인정보를 출력하는 debug log를 찾지 못했다.
- 등급 로그: Home, MyPage, tierGuide가 `PersonalTierProgress.debugLog()`를 공통 사용한다. 서버 raw 필드는 `rawScheduleCount/rawScheduleComplete/rawTeacherInfoComplete/rawCompleted`로 보존하고, Beginner는 `displayCompleted=rawCompleted`, Amateur 이상은 `displayCompleted=2`, `displayTotal=2`, `earned=true`로 별도 기록한다. UI와 서버 상태는 변경하지 않았다.
- 검증: 관련 테스트 18개 통과, 최종 전체 `flutter test --no-pub -r expanded` 373개 모두 통과. 변경 범위 analyze에 새 compile error는 없었으나 기존 Home/MyPage 등의 warning/info 137건으로 종료 코드 1을 유지했다. DEV Debug `app-dev-debug.apk`, PROD 공통 코드 회귀 `app-prod-debug.apk` 빌드 성공. `git diff --check` whitespace 오류 없음.
- 보호: Firebase Functions, Firestore/Storage Rules, index를 변경하지 않았고 Firebase CLI·배포를 실행하지 않았다. PROD `more-than-fitness-f6adb` 데이터에 조회·수정·삭제·초기화를 하지 않았으며 다음 백로그로 이동하지 않았다.

## 2026-07-22 — PROD 카나리 재개 전 보호 점검 및 안전 중단

- 기기: `adb devices -l`에서 `R3CX40M6EEM`이 `device` 상태임을 재확인했다. 다만 설치 전 기존 앱 화면을 확인하려는 시점에는 Keyguard가 활성화되고 화면이 OFF인 상태였다. 화면을 깨운 뒤에도 잠금이 유지되어 기존 닉네임과 일정의 시각적 기준값을 확보하지 못했다.
- 저장소 위생: 미추적 대량 파일의 실제 위치는 루트 `node_modules`와 `functions/node_modules`였다. `.gitignore`에 루트/하위 `node_modules`, Android/Flutter 빌드 산출물, 로컬 artifact·backup·logs·Codex 캐시, APK/AAB, DEV/PROD Firebase 앱 설정과 로컬 credential 패턴을 추가했다. 파일은 삭제하지 않았다.
- Firebase 설정 보호: `android/app/google-services.json`은 기존 추적 파일이며 변경하지 않았다. `android/app/src/dev/google-services.json`은 로컬 미추적·ignore 상태로 유지했다. `android/app/src/prod/google-services.json`과 iOS `GoogleService-Info.plist`는 존재하지 않았다. 어떤 Firebase 설정 JSON도 checkpoint에 새로 포함하지 않았다.
- checkpoint: `git add .` 없이 allowlist로 366개 소스·테스트·문서·안전한 설정 파일만 stage했고, staged 금지 경로 0개와 `git diff --cached --check` 통과를 확인했다. `codex/prod-canary-checkpoint-2026-07-22` 브랜치의 `a479b91` (`chore: checkpoint before prod canary`)로 저장했다. node_modules/build/APK/Firebase 설정/로컬 artifact는 포함하지 않았다.
- 기존 PROD 앱: `com.example.mtf_app` 설치를 확인했고 versionName `1.0`, versionCode `1`, signer SHA-256 `a922c098c2dc3d7052895e8ad836b95cf08b9e12f39acd9e6df9d189abb74489`였다. 설치 APK를 `artifacts/prod_before_canary/base.apk`에 rollback 용도로 보관했다. 앱 삭제와 데이터 초기화는 하지 않았다.
- 신규 후보 APK: PROD Debug APK를 `versionName=1.0.1`, `versionCode=2`, packageName `com.example.mtf_app`, projectId `more-than-fitness-f6adb`로 빌드했다. signer SHA-256은 기존 설치본과 동일했다. merged PROD Debug manifest에서 기존 주간/다음 레슨과 신규 오늘 레슨 receiver 세 개가 함께 존재함을 확인했다. APK는 아직 설치하지 않았다.
- 자동 검증: Functions lint/build 통과. Auth/Firestore/Functions Emulator의 profile 30개, member/tier 38개, nickname/profile 22개, personal schedule Rules 26개, personal training log 38개 등 154개 시나리오가 통과했다. 전체 Flutter 테스트 373개가 통과했다.
- PROD 읽기 전용 감사: 현재 ACTIVE Functions 10개와 기존 schedules/training_logs index를 조회했다. 로컬 monthly training_logs composite index가 PROD에 없는 상태를 확인했다. 이 조회 외 PROD 데이터 문서 작업은 하지 않았다.
- 중단: 잠금 상태 때문에 설치 전 기존 nickname·일정 기준값을 확인할 수 없어 안전 조건을 충족하지 못했다. 따라서 PROD Functions/Rules/index 배포, `adb install -r`, 위젯 실기기 검증을 모두 실행하지 않았다. Play Store 배포도 실행하지 않았으며 다음 백로그로 이동하지 않았다.

## 2026-07-22 — PROD 카나리 선택 배포·업데이트 설치 및 위젯 단계 안전 중단

- 시작 보호 조건: `R3CX40M6EEM`은 `device`, 화면 ON, Keyguard 비활성 상태였다. `.gitignore`는 `C:\src\mtf_app\.gitignore`였고 `a479b91` 367개 파일 및 `5f60fc7` 2개 파일에서 node_modules/build/APK/AAB/DEV Firebase 설정/service account/.env/credential/스크린샷 패턴이 0개임을 확인했다. 기존 추적 `android/app/google-services.json`은 두 checkpoint에서 변경되지 않았다.
- 설치 전 기준값: 기존 `com.example.mtf_app` 1.0(1)이 PROD 환경 `more-than-fitness-f6adb`로 정상 시작했다. UID와 nickname은 원문 대신 fingerprint로 비교했고 둘 다 존재했다. profile 존재, 최근 9주 schedule stream 182건, tier Beginner였으며 신규 온보딩, permission-denied, crash는 없었다.
- rollback: `adb shell pm path` 결과 base APK 1개를 `C:\src\mtf_app\artifacts\prod_before_canary\base.apk`에 보관했다. SHA-256은 `510160acdb80a15cc276ee4a3a67007177b329053bccbb08536a3837191db6f7`, 기존 signer SHA-256은 `a922c098c2dc3d7052895e8ad836b95cf08b9e12f39acd9e6df9d189abb74489`다.
- callable manifest 결론: PROD에 이미 존재하고 구버전 시작이 정상인 `bootstrapAnonymousBeginnerProfile`은 재배포하지 않았다. 신규 앱이 직접 호출하고 Emulator를 통과했으며 현재 API 계약을 유지하는 `reconcilePersonalTier`, `claimTierCelebration`, `claimFirstLessonGuide`를 생성하고 `createManagedMember`, `updatePersonalTrainerProfile`, `transitionAnonymousProfileToLinked`를 갱신했다. 여섯 함수 모두 v1 callable, `asia-northeast3`, Node.js 22이며 선택 배포가 성공했다. 인증 없는 smoke는 여섯 endpoint 모두 HTTP 401을 반환했다.
- Firebase 선택 배포: `npx.cmd firebase deploy --only "functions:reconcilePersonalTier,functions:claimTierCelebration,functions:claimFirstLessonGuide,functions:createManagedMember,functions:updatePersonalTrainerProfile,functions:transitionAnonymousProfileToLinked" --project more-than-fitness-f6adb`가 성공했다. 월간 레슨 기록 쿼리에 필요한 `training_logs(trainerId ASC, workspaceType ASC, startAt ASC)`가 PROD에 없어 `firestore:indexes`만 선택 배포했다. Firestore Rules는 CLI compile 검사만 통과했으며 Rules 자체와 Storage Rules는 배포하지 않았다. 전체 Functions 배포, backfill, migration은 하지 않았다.
- 구버전 회귀: 서버 배포 뒤 기존 1.0(1)을 다시 실행해 UID/nickname fingerprint, profile 존재, 일정 182건, Beginner가 설치 전과 같음을 확인했다. permission-denied, crash, 치명적 callable 오류는 0건이었다.
- 신규 APK: `app-prod-debug.apk`는 package `com.example.mtf_app`, versionName 1.0.1, versionCode 2, compiled projectId `more-than-fitness-f6adb`, DEV project/package 식별자 0건이었다. 기존 주간/다음 레슨/오늘 레슨 receiver가 모두 포함됐고 signer는 기존 앱과 동일했다. APK SHA-256은 `1ab5bddf83527a84d21d9cbcc0c02784b1e2fd0a78b08f8bc21e7f21da850461`이다.
- 업데이트 설치: 삭제·초기화 없이 `adb install -r C:\src\mtf_app\build\app\outputs\flutter-apk\app-prod-debug.apk`를 실행해 `Success`를 확인했다. 정확한 PROD package는 1개이며 설치 후 1.0.1(2)로 확인됐다.
- 설치 후 정체성: PROD environment/project/package 로그가 정상이고 UID 및 nickname fingerprint가 설치 전과 일치했다. profile 존재, 일정 182→182, tier Beginner→Beginner, onboarding/DEV 신호/permission-denied/crash는 모두 0건이었다. 운영 일정·회원·프로필 문서를 생성·수정·삭제하지 않았다.
- 위젯: 기존 PROD 주간 위젯 instance ID 73은 유지됐고 앱 foreground 동기화 후 기존 일정 데이터가 다시 표시됐다. 기존 다음 레슨 provider는 유지됐으나 설치 전부터 홈 화면 배치 instance는 없었다. 신규 오늘 레슨 provider는 Android 목록에 정상 등록됐다. 신규 위젯을 홈에 추가하기 위한 페이지 이동 중 기기가 화면 OFF·Keyguard 활성 상태가 되어 즉시 중단했다. 따라서 신규 오늘 레슨 렌더링, cold/warm 탭, 다음 레슨 위젯 배치 유지, gate/MyPage 읽기 검증은 미검증이다.
- 보호: `adb uninstall`, `pm clear`, 일반 앱 삭제, 데이터 초기화, 운영 일정 자동 쓰기, 전체 Firebase 배포, Play Store 배포를 하지 않았다. 다음 백로그로 이동하지 않았다.

## 2026-07-22 — PROD 1.0.1 남은 읽기 중심 실기기 카나리

- 위젯 인스턴스: PROD 주간 위젯은 ID 73, PROD 오늘 레슨 위젯은 ID 77로 유지됐다. 별도로 DEV 오늘 레슨 ID 75와 DEV 다음 레슨 ID 76이 있어 package 기준으로 구분했다. PROD 오늘 위젯은 남은 레슨 6건을 표시하며 다음 11:00, 다다음 12:00, 이후 14:00/17:00/18:00을 중복 없이 렌더링했다. 총 6건 중 5건만 보이는데 `외 1개` 표시는 없어 overflow 표시 누락으로 기록했다.
- 탭: 앱 process가 살아 있는 warm 탭은 PROD MainActivity를 foreground로 열었고, 현재 주의 수요일 열을 선택한 뒤 `오늘 다음 레슨` 제목을 고정 헤더 바로 아래에 배치했다. `am force-stop` 후 PROD 위젯을 두 위치에서 탭한 cold 검증은 app process만 생성되고 MainActivity start/foreground 및 widget action 로그가 없어 실패로 기록했다.
- MyPage: 기존 nickname/profile과 기존 활동 지역 표시가 유지됐다. Beginner, 회원 0명, 레슨 182건을 읽었고 활동 지역 값도 화면에 표시됐다. 선생님 정보는 소속 형태 미선택 때문에 미완료 상태였다.
- gate: 회원 추가는 `고객카드 등록은 Amateur부터`, 신규 계약은 `Semi-Pro부터`, 인사이트는 `Pro부터` gate가 각각 표시됐다. MORE 비즈니스는 연결 요청이 아직 없고 요청이 생기면 알려준다는 AI FC 대기 안내가 표시됐다.
- 등급 미션: Home과 등급 안내 모두 1/2 완료, 레슨 일정 182/10을 표시했다. 따라서 일정 미션은 완료이고 선생님 정보 미완료 때문에 Beginner가 유지되는 정상 상태다.
- 인바디: personal 회원 0명이고 회원 추가가 Amateur gate로 차단되어 운영 회원을 새로 만들지 않고는 회원카드의 인바디 카메라 버튼에 진입할 수 없었다. 사전 안내는 이번 읽기 전용 카나리에서 미검증으로 남겼다.
- 오류·보호: 전체 수동 검증 구간에서 permission-denied 0건, fatal crash 0건, ANR 0건이었다. Firebase Functions/indexes/Rules/Storage 재배포, APK 재설치, 앱 삭제·데이터 초기화, 운영 일정·회원 쓰기, Play Store 배포를 실행하지 않았다. 다음 백로그로 이동하지 않았다.

## 2026-07-22 — Android 오늘 레슨 위젯 overflow·cold tap 보완

- 범위: 직전 PROD 1.0.1 카나리에서 확인된 `외 1개` 누락과 cold 위젯 탭 실패만 수정했다. 새 기능, Firebase, 운영 데이터, 기존 주간/다음 레슨 provider는 건드리지 않았다.
- overflow 원인: `remaining.size - remainingCapacity` 계산은 6건/하단 3행에서 1로 맞았지만, `외 N개`가 하단 일정 행 뒤 마지막 줄에 있어 실제 위젯 높이에서 잘렸다. `upcomingCount → topCardCount(최대 2) → remainingSourceCount → visibleRemainingCount → hiddenCount` 순서로 실제 표시 수를 명시하고, `외 N개`를 `오늘 남은 일정` 제목 오른쪽에 배치해 별도 세로 공간을 쓰지 않게 했다.
- cold tap 코드 원인·보완: 오늘 위젯 Intent는 MainActivity component와 extras만 사용해 다른 Glance Activity PendingIntent와 구별할 고유 action/data가 없었다. 고유 `OPEN_TODAY_SCHEDULE` action과 `mtf://widget/today` data, package, `NEW_TASK|CLEAR_TOP|SINGLE_TOP`을 적용했다. MainActivity warm 경로가 Flutter 전달 직후 pending action을 즉시 지우던 동작도 제거해 Home 준비 뒤 `consume`에서만 한 번 제거하도록 통일했다. 실제 cold 성공 여부는 DEV 실기기 검증 전이므로 완료로 단정하지 않는다.
- 안전 로그: `[MTF_DAILY_WIDGET_RENDER]`에 개수와 hidden label 여부, `[MTF_DAILY_WIDGET_TAP]`에 cold/warm·Activity action, `[MTF_DAILY_WIDGET_DEEPLINK]`에 foreground·Home ready·consume 결과만 남긴다. UID, 문서 ID, 회원명과 일정명은 기록하지 않는다.
- 수정 파일: `android/app/src/main/kotlin/com/example/mtf_app/MtfTodayLessonRollupWidget.kt`, `MainActivity.kt`, `lib/services/home_widget_today_rollup_mapper.dart`, `home_widget_navigation_service.dart`, 관련 테스트 2개, 이 문서와 `BACKLOG.md`다.
- 검증: 변경 Dart 파일 format 완료. 관련 14개와 전체 Flutter 377개 모두 통과. 변경 범위 `dart analyze` 문제 0건. DEV/PROD Kotlin compile, 두 flavor merged Manifest, DEV/PROD Debug APK 빌드 성공. `git diff --check`는 whitespace 오류 없이 기존 LF→CRLF 안내만 출력했다.
- 실기기 중단: `R3CX40M6EEM`은 ADB `device`였지만 자동 검증 전후 세 차례 모두 Keyguard `showing=true`였다. 잠금 상태에서 앱 설치·위젯 조작을 하지 않는 보호 원칙에 따라 DEV APK 설치, 6개 렌더, warm/cold 탭, 주간 위젯 회귀는 미검증으로 남겼다.
- PROD 보호: DEV 실기기 전 항목 통과 조건을 충족하지 못해 `pubspec.yaml`은 `1.0.1+2`로 유지했다. PROD APK 재설치, Firebase CLI·Functions·Rules·indexes·Storage 배포, PROD 데이터 조회/수정/삭제/초기화, Play Store 배포를 실행하지 않았다. 다음 백로그로 이동하지 않았다.

## 2026-07-22 — 오늘 레슨 위젯 DEV 실기기 재검증 및 PROD 패치 중단

- 기기·설치: `R3CX40M6EEM`은 ADB `device`, 화면 `Awake`, Keyguard `showing=false`였다. 최초 확인 APK는 flavor만 DEV이고 기본 `lib/main.dart` entrypoint로 빌드돼 검은 화면이 나타났다. 저장소의 확정 명령대로 `flutter build apk --debug --flavor dev -t lib/main_dev.dart --no-pub`로 재빌드했고 package `com.example.mtf_app.dev`, project `more-than-fitness-dev-mft`, PROD project marker 없음과 `adb install -r` Success를 확인했다. 앱 삭제·데이터 초기화는 하지 않았다.
- DEV 렌더: 정확한 DEV 위젯은 launcher 4페이지의 기존 ID 75였다. canonical Home 일정 stream은 cache 기준 docCount 6이었지만 Android 렌더 로그는 `upcomingCount=0 topCardCount=0 visibleRemainingCount=0 hiddenCount=0 hiddenLabelVisible=false`였다. widget owner cache가 비어 owner 검증에서 차단된 상태로 판단되며, 요청한 6건/`외 1개` 실제 렌더는 통과하지 못했다. DEV 데이터를 임의 생성·수정하지 않았다.
- DEV warm tap: launcher 4페이지 DEV 위젯을 package까지 확인한 뒤 탭했다. `com.example.mtf_app.dev/com.example.mtf_app.MainActivity`가 topResumedActivity가 됐고 Android action은 한 번 전달·consume됐다. 다만 Flutter 진단 로그는 warm consume도 `coldStart=true`로 표시해 로그 분류 불일치가 남았다.
- DEV cold tap: DEV process를 `am force-stop`한 뒤 같은 위젯을 탭했다. process PID는 생성됐지만 topResumedActivity는 launcher에 남았고 MainActivity `onCreate`, `[MTF_DAILY_WIDGET_TAP]`, deep-link 로그가 발생하지 않았다. 따라서 cold foreground 문제는 실제 기기에서 해결되지 않았다.
- 기존 위젯: DEV 오늘 위젯 ID 75와 다음 레슨 위젯 ID 76은 설치 후 유지됐고 세 provider class도 설치 상태를 유지했다. DEV 주간 provider는 존재하지만 launcher 배치 instance가 없어 실제 탭 회귀는 미검증이다.
- 중단·보호: DEV 렌더와 cold tap이 모두 통과해야 한다는 조건을 충족하지 못해 `pubspec.yaml`을 `1.0.2+3`으로 올리지 않았고 PROD APK 빌드·`adb install -r`·데이터 보존 비교·PROD 위젯 검증을 실행하지 않았다. Firebase CLI와 Functions/Rules/indexes/Storage 배포, PROD 운영 데이터 생성·수정·삭제, uninstall, `pm clear`, Play Store 배포도 하지 않았다.

## 2026-07-22 — DEV 오늘 레슨 위젯 owner self-heal·정상 cold 복구

- owner cache 실제 원인: canonical `HomePage._syncHomeWidgetPreview()`는 `HomeWidgetPreviewSyncService`로 schedule payload를 만들었지만 `MtfHomeWidgetService.savePersonalOwnerUid()`를 호출하지 않았다. owner write는 별도 `PersonalScheduleWidgetSyncService` 경로에만 있어 이미 로그인된 anonymous 사용자의 실제 Home appStart/snapshot/resume 경로에서 `mtf_widget_personal_owner_uid`가 비었다.
- 실제 저장소: Flutter `home_widget` 0.9.2+1과 Android `HomeWidgetGlanceStateDefinition` 모두 DEV sandbox의 `/data/user/0/com.example.mtf_app.dev/shared_prefs/HomeWidgetPreferences.xml`을 사용하며 plugin key prefix는 없다. owner key는 `mtf_widget_personal_owner_uid`, payload key는 `mtf_widget_today_rollup_items_v1`이다. environment/project/workspace/generatedAt/localDate metadata key를 같은 파일에 추가했다.
- self-heal: `HomePage`는 정상 schedule snapshot 전 appStart sync를 deferred 처리한다. snapshot 첫 적용, foreground resume, 기존 세션 재진입 시 현재 personal owner UID와 DEV environment/project를 source model에서 받아 owner metadata 기록 → 재읽기 검증 → payload 기록 → 재읽기 검증 → 오늘 위젯 update 순서로 실행한다. UID mismatch와 personal 로그아웃은 owner·오늘 payload·주간·다음 레슨 owner cache를 제거한다.
- 실패 처리: owner 또는 payload 저장/검증 실패는 성공 update로 기록하지 않고, owner와 today payload를 안전하게 비운 update만 시도한 뒤 원래 오류를 다시 전달한다. Debug 로그에는 UID·회원명 없이 존재/일치/개수/결과만 남긴다.
- 실기기 owner 결과: DEV `main_dev.dart` APK를 삭제·초기화 없이 `install -r`했다. `scheduleSourceCount=6`, `mappedCount=6`, `ownerMatchedAfter=true`, environment/workspace match, payload verified, update requested를 확인했다. Android도 owner/payload match와 payloadCount 6을 확인했다.
- 현재 렌더 데이터: payload 6건의 시작일은 7/20 1건, 7/21 2건, 7/22 1건, 7/23 2건이었다. 오늘 7/22의 남은 일정은 1건이라 실기기 `upcomingCount=1`, hidden 0이 올바른 결과다. 6건이 모두 오늘인 layout의 2+3+`외 1개`는 자동 테스트로 통과했지만, DEV Firestore 일정을 임의 변경하지 않아 이번 실화면에서는 미검증이다.
- PendingIntent 감사: 실제 click은 root `Column`의 Glance `actionStartActivity(Intent)`이며 Glance 1.1.1 bytecode에서 `PendingIntent.getActivity`로 변환됨을 확인했다. Glance requestCode는 0 고정이므로 실제 값을 숨기지 않고 기록했고, 충돌 방지는 appWidgetId별 `morethan-dev://widget/today?instance=...` data URI와 explicit MainActivity component로 보장한다. broadcast/actionRunCallback 경로는 없다.
- 명시적 Activity: `morethan-dev://widget/today?instance=75`와 실제 action을 사용한 `am start -W`가 Status ok, MainActivity foreground로 성공했다.
- cold 실패 원인: 직전 검증은 `am force-stop`으로 Android stopped-package 상태를 만들어 정상 cold와 섞었고, 기존 Glance Intent에는 widget instance별 고유 data identity도 없었다. force-stop 결과는 일반 cold 성공 기준이 아니다. unique URI를 적용하고 DEV recent task만 제거해 process가 없는 상태를 만든 뒤 실제 위젯 탭을 재검증했다.
- warm/cold: warm은 `onNewIntent`, `coldStart=false`, Home ready 뒤 1회 consume으로 통과했다. 정상 cold는 탭 전 process 없음, 탭 후 process 생성, `onCreate actionMatched=true dataMatched=true`, MainActivity foreground, `source=initialIntent coldStart=true` 1회 consume으로 통과했다. `[MTF_HOME_SCROLL_TODAY]`에서 현재 주·오늘 요일과 다음 레슨 위치 이동도 확인했다.
- provider 회귀: DEV package에 주간·다음 레슨·오늘 레슨 receiver 세 개가 모두 유지됐다. launcher instance는 오늘·다음 레슨 두 개이고 주간은 기존부터 배치 instance가 없어 실제 주간 탭은 미검증이다.
- 검증: owner/mapper/navigation 관련 21개 통과, 전체 Flutter 384개 통과, Kotlin compile과 DEV merged Manifest 성공, 정확한 `lib/main_dev.dart` DEV Debug APK 빌드 성공, `git diff --check` whitespace 오류 없음. 새 위젯 서비스·테스트 analyze 문제 0건이며 기존 Home 59건, Settings 12건은 기준 상태 그대로다. 실기기 구간 permission-denied 0건, fatal crash 0건이다.
- 보호: PROD APK를 빌드·설치하지 않았고 version `1.0.1+2`를 변경하지 않았다. Firebase CLI, Functions/Rules/indexes/Storage 배포, PROD Firebase/데이터 조회·수정·삭제, uninstall, `pm clear`, 앱 데이터 초기화, Play Store 배포를 실행하지 않았다. 다음 백로그로 이동하지 않는다.

## 2026-07-22 — PROD 1.0.2 오늘 레슨 위젯 카나리 반영 및 렌더 중단

- 사전 보호: branch `codex/prod-canary-checkpoint-2026-07-22`, commit `7086a22`에서 직전 owner/cold 수정이 작업 트리에 포함됐고 `git diff --check`가 통과했다. `R3CX40M6EEM`은 ADB `device`, 화면 `Awake`, Keyguard `showing=false`였다.
- 설치 전 기준: 기존 `com.example.mtf_app`은 `1.0.1 (2)`, PROD project `more-than-fitness-f6adb`로 시작했다. UID와 nickname은 원문 대신 SHA-256 fingerprint로 비교했고 둘 다 존재했다. profile 존재, personal schedule stream 180건, 현재 tier Amateur였다. 이전 기록의 182건/Beginner와 달랐지만 일정 0건이나 환경 혼입은 아니었다.
- 빌드·서명: `pubspec.yaml`을 `1.0.2+3`으로 올리고 `flutter build apk --debug --flavor prod -t lib/main_prod.dart --no-pub`를 성공했다. APK는 package `com.example.mtf_app`, version `1.0.2 (3)`, PROD project marker만 포함하고 주간·다음 레슨·오늘 레슨 receiver를 모두 유지했다. APK SHA-256은 `568DA65AC89F355FB66946B82E1D4DCC8B5CCC00F842BF93BC8C83B78DB0D938`이다. 기존·신규 signer SHA-256은 모두 `a922c098c2dc3d7052895e8ad836b95cf08b9e12f39acd9e6df9d189abb74489`로 일치했다.
- 업데이트·보존: 기존 앱을 삭제하지 않고 `adb install -r build/app/outputs/flutter-apk/app-prod-debug.apk`를 실행해 `Success`를 확인했다. 설치 후 UID fingerprint, nickname fingerprint, profile 존재, schedule stream 180건이 설치 전과 일치했고 신규 온보딩이나 DEV 데이터 혼입은 없었다. 앱은 PROD identity로 정상 foreground에 진입했다.
- owner/payload: 첫 appStart 요청은 schedule snapshot 대기로 deferred됐고, cache snapshot 적용 뒤 owner write/readback과 environment/project/workspace 검증이 성공했다. schedule source/mapped 180건 payload write/readback과 오늘 위젯 update 요청도 성공했다. `permission-denied`, fatal crash, ANR, owner mismatch, missing owner는 확인되지 않았다.
- 렌더 중단: PROD 오늘 위젯 native 로그는 `ownerMatched=true`, `payloadCount=180`이지만 `upcomingCount=0`, `topCardCount=0`, `visibleRemainingCount=0`, `hiddenCount=0`, `hiddenLabelVisible=false`, `result=empty`였다. 실화면도 `7월 22일 수요일`, `남은 레슨 0개`, `오늘 남은 레슨이 없어요.`로 표시돼 요청한 6건/`외 1개`가 보이지 않았다. 같은 launcher의 기존 주간 위젯 인스턴스는 일정과 함께 유지됐다. 다음 레슨 receiver도 APK/Manifest에 유지됐으며 PROD launcher 배치 인스턴스는 없었다.
- 중단 범위: 요청서의 `외 1개` 미표시 즉시 중단 조건에 따라 PROD 오늘 위젯 warm/cold 탭, 위젯 탭 MainActivity foreground, deep link 위치 이동은 실행하지 않았다. 운영 일정을 만들거나 수정해 조건을 맞추지 않았고 추가 앱 패치도 하지 않았다. 두 번째 첨부는 첫 번째와 완전히 같은 작업문이므로 재설치·재검증하지 않았다.
- 자동 검증: owner/mapper/navigation 관련 21개 통과, 전체 Flutter 테스트 384개 통과. 변경 Dart 10개 분석은 새 error 0개이며 기존 warning/info 71건만 남았다. 전체 analyze는 루트 `node_modules/firebase-tools` Dart template 6개 기존 오류 때문에 종료 코드 1이었다. PROD Debug APK와 세 receiver merged Manifest 검증, signer/package/version/project 비교, `git diff --check`가 통과했다.
- 보호: Firebase CLI를 실행하지 않았고 Functions, Firestore Rules/indexes, Storage Rules를 재배포하지 않았다. PROD 운영 데이터 생성·수정·삭제·초기화, uninstall, `pm clear`, 앱 데이터 초기화, Play Store 배포를 실행하지 않았다. 다음 백로그로 이동하지 않는다.

## 2026-07-23 — PROD 오늘 레슨 위젯 날짜 변경 후 재검증 중단

- 재개 기준: 첨부 작업문은 직전 PROD 1.0.2 카나리 작업과 동일했다. 현재 설치 앱이 이미 `1.0.2 (3)`이고 소스도 `1.0.2+3`이므로 버전 증가, APK 빌드, signer 비교, `adb install -r`를 반복하지 않고 직전 중단 지점인 실제 렌더부터 재개했다.
- 기기·환경: `R3CX40M6EEM`은 ADB `device`, 화면 `Awake`, Keyguard `showing=false`였다. 앱은 `environment=prod`, project `more-than-fitness-f6adb`, package `com.example.mtf_app`으로 시작했다.
- owner/payload: 7월 23일 personal schedule stream은 179건이었다. schedule snapshot 뒤 owner write/readback, environment/workspace match, payload 179건 write/readback과 widget update 요청이 모두 성공했다. permission-denied, fatal crash, ANR, owner mismatch, missing owner는 확인되지 않았다.
- native 계산: PROD Glance 로그는 `ownerMatched=true`, `payloadCount=179`, `upcomingCount=10`, `topCardCount=2`, `visibleRemainingCount=4`, `hiddenCount=4`, `hiddenLabelVisible=true`, `result=ready`였다. 현재 데이터와 위젯 높이는 작업문의 6건/하단 3행/`외 1개` 조건과 다르다.
- 실제 화면 불일치: 같은 PROD 오늘 위젯 실화면은 `7월 23일 목요일`, `남은 레슨 0개`, `오늘 남은 레슨이 없어요.`를 계속 표시했다. 즉 native 계산은 ready였지만 launcher RemoteViews에는 새 내용이 반영되지 않았다. 기존 주간 위젯 인스턴스와 세 provider는 유지됐다.
- 중단: 요청서의 `외 1개` 미표시 즉시 중단 조건에 따라 warm/cold 탭, 위젯 탭 MainActivity foreground, deep link 위치 이동을 실행하지 않았다. 추가 코드 수정, 재빌드, APK 재설치, 운영 일정 생성·수정·삭제도 하지 않았다.
- 검증 재사용: 현재 소스 코드는 직전 카나리 자동 검증 이후 변경되지 않았고 이번에는 문서만 갱신했다. 직전 결과인 관련 21개, 전체 Flutter 384개, PROD Kotlin/Manifest/Debug APK, signer/package/version/project, `git diff --check` 통과 상태를 유지한다.
- 보호: Firebase CLI, Functions, Firestore Rules/indexes, Storage Rules 배포를 실행하지 않았다. uninstall, `pm clear`, 앱 데이터 초기화, Play Store 배포를 실행하지 않았으며 다음 백로그로 이동하지 않는다.

## 2026-07-23 — 오늘 레슨 위젯 schema v2·Glance 렌더 복구

- 실제 원인 1 — payload 경계: `HomeWidgetPreviewSyncService.sync()`가 Home의 전체 schedule snapshot을 필터 없이 `HomeWidgetTodayRollupSnapshot.items`로 직렬화해 PROD 180건 전체가 오늘 위젯 payload에 들어갔다. Flutter writer에서 current owner UID, `workspaceType=personal`, Asia/Seoul 기준 오늘, 유효한 시작·종료 시간, 삭제/rollback/temp 계열 상태를 검사하도록 옮겼다. 미등록 이름 일정은 유지한다.
- 실제 원인 2 — launcher stale: Android 계산이 `ready`인 호출에서도 최상위 Glance `Column` 자식이 11개가 되어 `Column container cannot have more than 10 elements`, `Truncated Column container from 11 to 10 elements`, `Null RemoteViews`가 발생했다. 하단 일정 행을 중첩 `Column` 하나로 묶어 최상위 제한을 넘지 않게 했고 이후 실기기에서 truncation 오류 없이 실제 화면이 갱신됐다.
- 데이터 계약: schema v2는 `localDate`, `timezone=Asia/Seoul`, `generatedAtEpochMs`, 단조 증가 `payloadRevision`과 item의 `startAtEpochMs/endAtEpochMs/displayName/lessonType/remainingSessions/status`를 사용한다. 시각은 epoch milliseconds이며 Kotlin은 `Instant`와 `ZoneId.of("Asia/Seoul")`로 날짜/시간을 계산한다. 안전하게 해석 가능한 schema v1만 fallback하고 알 수 없는 schema는 `invalid_schema`로 차단한다.
- revision: writer는 source/today/payload 수와 write/readback revision을 기록하고, 저장된 revision보다 늦게 끝난 과거 callback은 `stale_ignored`로 차단한다. Kotlin parser와 render는 `appWidgetId`와 같은 revision, raw/날짜/시간/upcoming/invalid 개수를 기록한다. 실기기 ID 75에서 writer `1784769412597` → parser 동일 revision → render 동일 revision을 확인했다.
- DEV 실제 데이터: source 7건 중 한국 날짜 기준 오늘 candidate/payload 1건만 저장했고 Android `rawItemCount=1`, `upcomingCount=1`, `result=ready`로 실제 위젯에 표시됐다. fixture 제거 후 정상 APK를 다시 `install -r`해 실제 1건 payload로 복원했다.
- DEV local fixture: Firestore write 없이 Debug DEV에서만 임시 local fixture를 활성화했다. 6건은 `topCardCount=2`, `visibleRemainingCount=3`, `hiddenCount=1`, 화면 `외 1개`; 10건은 `topCardCount=2`, `visibleRemainingCount=4`, `hiddenCount=4`, 화면 `외 4개`를 확인했다. 실제 UID·이름은 사용하지 않았고 검증 뒤 fixture 코드를 제거했다.
- 탭/인스턴스: 기존 DEV 오늘 위젯 appWidgetId 75가 최신 revision으로 갱신됐다. warm 탭은 MainActivity foreground 및 Home 1회 consume을 확인했다. process PID가 없는 상태의 탭에서도 새 PID와 MainActivity foreground, 1회 전달을 확인했다. 새 인스턴스 추가는 현재 홈 페이지가 기존 위젯으로 가득 차 있어 사용자 배치를 변경하지 않고는 진행할 수 없어 미검증으로 남겼다.
- 기존 위젯: 주간·다음 레슨·오늘 레슨 provider 세 개는 Manifest/설치 상태에 유지되고, 기존 주간/다음 화면은 삭제·재배치하지 않았다. 오늘 위젯 update는 기존 canonical receiver만 대상으로 수행한다.
- 검증: 관련 Flutter 테스트 27개 통과, 전체 Flutter 테스트 390개 통과, DEV Kotlin compile 및 Manifest merge/Debug APK 빌드 성공. 변경 범위 analyze는 새 error 0건이며 기존 `home_page.dart` warning/info 59건으로 종료 코드 1이었다. `git diff --check` whitespace 오류 없음.
- 보호: PROD APK 1.0.2(3)를 빌드·재설치하지 않았다. Firebase CLI, Functions, Firestore Rules/indexes, Storage Rules 배포를 실행하지 않았고 PROD 운영 데이터 조회·생성·수정·삭제·초기화, uninstall, `pm clear`, Play Store 배포를 하지 않았다. 다음 백로그로 이동하지 않는다.

## 2026-07-23 DEV 네 가지 회귀 보완

- 스마트 알람 gate: `AppTierAccessSnapshot.canUseSmartAlarm`의 기준이 Amateur(rank 1)였던 것이 원인이었다. Semi-Pro(rank 2) 이상으로 통일하고 알림 설정 및 AI FC 안내 문구도 `Semi-Pro부터`로 맞췄다. DEV Amateur 실기기에서 `smart=false`, `semiProSmart=false`와 Semi-Pro 잠금 안내를 확인했다.
- legacy 고객카드 그룹: 고객카드에서 `groupId` 저장 후 목록 화면이 별도로 보유한 그룹 이름 map을 다시 읽지 않아 저장한 그룹이 목록에 바로 노출되지 않았다. 신규/수정 카드 route 복귀 뒤 legacy workspace에서만 `_loadGroups()`를 다시 실행한다. Personal은 unscoped `member_groups`를 조회하거나 legacy `groupId`를 표시하지 않고 로컬 미분류 값만 사용하도록 격리를 보강했다.
- 목표 제목: 주간 page offset 0/1을 각각 `이번 주 목표`/`다음 주 목표`로 명시하는 공통 계산을 유지·검증했다. DEV 실기기에서 이번 주 화면과 수평 주 이동 뒤 다음 주 화면의 제목을 확인했다.
- MyPage 오류 이동: 저장 검증 실패 시 영문 이름만 특례 처리하던 코드를 제거했다. 현재 Form의 오류가 있는 모든 필드를 화면상의 세로 위치로 정렬해 첫 오류 필드에 `Scrollable.ensureVisible`을 적용한다. DEV 실기기에서 실명 필드를 잘못 입력한 뒤 저장했을 때 서버 저장 없이 실명 오류 필드가 상단으로 이동하고 오류 문구가 표시되는 것을 확인했으며, 화면을 닫아 임시 입력을 폐기했다.
- 자동 검증: 관련 테스트 30개 통과, 최종 DEV Debug APK 빌드 및 데이터 보존 설치 성공, `git diff --check` 통과. 전체 Flutter 테스트는 최종 변경 전 394개가 통과했으나 최종 personal 그룹 격리 보강 후 재실행이 15분 동안 종료되지 않아 중단했으며 완료로 추측하지 않는다. 변경 범위 analyze 재실행도 같은 Flutter 도구 정지 영향으로 완료 결과를 얻지 못했고, 직전 실행에서는 새 compile error 없이 기존 warning/info만 확인했다.
- 실기기 제한: DEV Debug legacy workspace의 unscoped `members`, `member_groups`, `trainer_profile/me` 접근은 현재 DEV Rules에서 `permission-denied`로 차단된다. Rules를 열거나 PROD legacy 데이터를 사용하지 않았으므로 legacy 그룹의 실제 Firestore 저장→목록 노출은 DEV 실기기에서 완료 검증하지 못했다. route 복귀 재조회와 Personal legacy 그룹 비노출은 자동 테스트로 확인했다.
- 보호: 오늘 레슨 위젯 schema v2·Asia/Seoul·revision 차단 변경을 그대로 보존했다. PROD APK 빌드·설치, Firebase Functions/Rules/indexes/Storage 배포, PROD 데이터 작업을 수행하지 않았다. 네 항목 중 legacy 실제 저장 검증이 남아 있으므로 PROD 1.0.3(4) 반영 준비 완료로 과장하지 않고 다음 백로그로 이동하지 않는다.

## 2026-07-23 PROD 1.0.3 전 차단 요소 검증

- 고객카드 canonical 경로: Personal 신규 회원 저장의 기존 직접 Firestore transaction을 `createManagedMember` callable로 교체했다. 서버는 `members/{memberId}`에 `trainerId=context.auth.uid`, `workspaceType=personal`로 생성하고, 목록은 같은 `members` collection을 `trainerId == currentUid`, `workspaceType == personal`로 조회한다. Personal 경로에서는 `member_groups`와 legacy group 이름 조회를 실행하지 않는다.
- 저장 완료 조건: callable 응답의 `memberId` 확인 후 `Source.server` readback으로 문서 ID·필드 memberId·trainerId·workspaceType·무그룹 상태를 검증하고, owner/workspace 목록 snapshot 수신까지 기다린다. 목록 복귀 후 필터를 전체로 전환하고 해당 카드 widget context의 실제 렌더를 확인한다. 실패 시 회원카드 화면과 입력값을 유지한다.
- DEV 실기기 결과: 가짜 카드 1건을 저장했다. `[MTF_MEMBER_CREATE] functionSucceeded=true readbackSucceeded=true snapshotObserved=true visibleAfterSave=true result=success`였고, 목록은 총 1명 및 저장한 가짜 카드 렌더를 표시했다. 최초 검증에서 저장 전 전역 `members` 전화번호 중복 조회가 DEV Rules에 거부되어 `permission-denied`가 1회 발생한 원인을 확인했다. Personal 신규 생성은 서버 transaction의 UID 범위 중복 조회가 canonical이므로 클라이언트 전역 조회를 제거했다. 최신 APK에는 이 보완을 포함했다.
- 그룹 cache 정책: `__ungrouped__`는 canonical 기본 무그룹, 전체·휴면·만료 가상 값은 저장하지 않고 무그룹으로 보정, missing/deleted/legacy 값도 요청에서 제거, 다른 owner 값은 거부하도록 순수 정책과 테스트를 추가했다. 현재 Personal용 canonical custom group collection·owner 모델·callable 계약은 저장소에 존재하지 않아 임의로 만들지 않았다. 따라서 custom group 실기기 시나리오는 미구현·미검증이며 PROD 1.0.3 준비 완료 조건으로 처리하지 않는다.
- 기존 잘못 저장된 PROD 카드: 조회·수정·삭제·migration을 하지 않았다. 향후 비파괴 복구는 별도 승인 작업에서 문서별 owner/workspace/group identity를 감사한 뒤 canonical update callable로 명시적으로 복구하는 방식이 필요하다.
- Smart Alarm 정리: 모든 레슨 알림이 동일 ID 체계를 사용하므로 legacy smart 예약만 안전하게 식별할 수 없다. 기존 `cancelAll()` 후 현재 정책으로 일반 알림을 재구축하는 canonical 동기화를 유지했다. DEV Amateur 실기기에서 기존 pending 4건을 정리한 뒤 일반 알림 4건을 재예약했고, `tierAllowed=false userRequested=true effective=false cancelledSmartCount=4 generalNotificationsResynced=true result=success`를 확인했다. 다음 동기화에서는 legacy 후보 0건이었다. Semi-Pro는 단위 테스트에서 userRequested=false/true에 따라 effective=false/true를 확인했다.
- Flutter 비종료 원인: 테스트 suite의 Timer·Stream·MethodChannel이 아니라 Android Studio가 자동 실행한 `flutter.bat daemon` 자식 `dart flutter_tools.snapshot daemon`이 Flutter SDK startup lock을 점유한 것이 원인이었다. 정확한 자식 daemon만 종료하면 명령이 즉시 진행되고 정상 종료했다. Android Studio가 daemon을 재생성하므로 검증 직전에 해당 자식만 식별·종료하는 절차를 사용했다.
- 검증: 관련 테스트 36개 통과. 최종 전체 `flutter test --no-pub -r expanded`는 403개 모두 통과, exit code 0, 약 145초에 정상 종료했다. 변경 범위 analyze는 정상 종료했으며 신규 compile error 0건, 기존 대형 화면 warning/info 291건으로 exit code 1이었다. DEV Debug APK 빌드 성공. DEV Kotlin compile 및 Manifest merge 성공. `git diff --check` whitespace 오류 없음.
- 배포/보호: Functions 소스는 변경하지 않았고 DEV/PROD Function 배포도 없었다. 현재 DEV에 이미 배포된 `createManagedMember`를 호출했다. PROD 1.0.3에 새 Function 배포는 필요하지 않지만, PROD에 현재 호환되는 `createManagedMember` export가 존재하는지는 실제 배포 전 읽기 전용 배포 목록 감사로 확인해야 한다. PROD APK 빌드·설치, Firebase Rules/indexes/Storage 배포, PROD 데이터 조회·수정·삭제는 수행하지 않았다.

## 2026-07-23 Personal custom group 계약·PROD Function 호환성 감사

- 결론: **정책 결정 필요(D)**. 저장소 현재 코드, 전체 Git 이력, Firestore Rules, Functions, 테스트 fixture, RUN_LOG/BACKLOG를 전수 검색했으나 Personal owner-scoped canonical custom group 계약은 존재하지 않는다. 새 collection·필드·Rules·callable을 추측해 만들지 않았다.
- 발견된 유일한 그룹 저장소는 legacy 루트 `member_groups/{groupId}`다. 문서에는 `name`, `order`, `isArchived`, `isSystem`, `systemType`, `appGroupId`, timestamp가 쓰이지만 owner UID와 `workspaceType` 필드가 없다. `firestore.rules`도 이 경로를 `isLegacyAdmin()`에게만 CRUD 허용한다.
- 실제 legacy member reference는 `members/{memberId}.groupId`와 표시용 `groupName`이다. 그룹별 목록은 unscoped `members where groupId == ...` 또는 전체 member snapshot의 local map을 사용한다. 생성·이름 변경·삭제·정렬·회원 이동 모두 `client_list_page.dart`에서 `member_groups`와 `members`를 직접 batch/set/update한다. owner 검증·Personal workspace 검증·서버 assignment action은 없다.
- 가상 그룹은 앱 상수 `__all__`, `__ungrouped__`, `__system_dormant__`, `__system_expired__`로 구분한다. 실제 legacy custom group은 `group_N` 형태의 문서 ID와 `systemType=custom`을 사용하지만 owner 범위가 없어 Personal canonical group으로 승격할 수 없다.
- Personal 경로는 의도적으로 `_loadGroups()`에서 `member_groups` query를 시작하지 않고 기본 무그룹만 제공한다. `createManagedMember` request allowlist는 `idempotencyKey`, `name`, `gender`, `phone`, `activityRegion`, `note`뿐이며 group 관련 인자를 받거나 무시하지 않고 거부한다. 응답은 canonical `memberId`를 반환한다.
- 따라서 custom group 생성·배정·목록 노출 DEV 실기기 시나리오는 실행하지 않았다. 무그룹 canonical 저장의 callable→server readback→owner/workspace snapshot→실제 목록 렌더 성공은 직전 작업 결과를 유지한다. legacy/missing/virtual은 request에서 제거해 무그룹으로 보정하고, 다른 owner group은 명시적 거부하는 안전 정책을 유지한다.
- PROD read-only metadata: `npx.cmd firebase functions:list --json --project more-than-fitness-f6adb`로 `createManagedMember`가 ACTIVE인 GCF v1 callable, `asia-northeast3`, Node.js 22, `maxInstances=10`임을 확인했다. 배포 artifact label/source hash는 `8575d4c179d15956d188e616e3928df8f7919617`, source upload UUID는 `e71a0bce-a09b-4bd3-b52e-a57dc952d80a.zip`이다.
- 배포 근거: PROD 선택 배포를 기록한 commit `6efbb450adc8019ffe4f5f9be12a64cc0d5f0e7a`의 RUN_LOG에는 `createManagedMember`를 포함한 여섯 함수 선택 배포 성공이 기록돼 있다. 배포 전 checkpoint `a479b914b153b209a37d2d93527cd8a919b8e5bc`와 현재 `functions/src`, `functions/package.json`, lock file diff는 0이며 Functions working tree도 깨끗하다. 따라서 현재 신규 앱 payload와 PROD 함수 계약은 동일하고 추가 Function 배포가 필요 없다.
- 호환 계약: 현재 PROD/로컬 함수는 Auth UID를 owner로 사용하고, `trainerId + workspaceType=personal + phoneNormalized` transaction query로 UID 범위 중복을 차단하며, 안정적 idempotency member ID와 `memberId` 응답을 사용한다. Beginner는 `amateur_required`, Amateur 이상은 생성 허용이다. group 인자는 허용하지 않는다. 1.0.2의 기존 6필드 request와 현재 신규 앱 request가 동일해 하위 호환된다.
- 검증: 관련 Flutter 테스트 22개 통과. 최종 전체 `flutter test --no-pub -r expanded` 403개 모두 통과, exit code 0. 관련 4개 파일 analyze는 정상 종료했으며 신규 compile error 0건, 기존 warning/info 291건으로 exit code 1. DEV Debug APK 빌드 성공. `git diff --check` whitespace 오류 없음.
- 보호: PROD APK 빌드·설치, PROD Functions/Rules/indexes/Storage 배포, PROD 문서 조회·생성·수정·삭제, uninstall, `pm clear`, Play Store 배포를 수행하지 않았다. 실행한 PROD 명령은 Functions metadata 읽기뿐이다. 1.0.3은 안전한 무그룹 저장으로 출시할지, owner-scoped Personal custom group을 별도 제품 기능으로 설계할지 사용자 결정이 필요하다.

## 2026-07-24 — PROD 1.0.3 (4) 카나리 자동 검증 완료·기기 미연결 중단

- 정책 고정: Personal canonical custom group은 이번 버전에 포함하지 않는다. Personal 신규 회원은 기존 `createManagedMember` 계약을 사용해 `members/{memberId}`, 현재 Auth UID의 `trainerId`, `workspaceType=personal`인 무그룹 문서로만 생성한다. legacy/missing/virtual 그룹 값은 요청에서 제거하고 다른 UID 그룹은 거부한다. 기존 PROD 카드는 migration·수정·삭제하지 않는다.
- 버전·빌드: `pubspec.yaml`을 `1.0.3+4`로 올렸다. PROD Debug APK 빌드에 성공했고 package `com.example.mtf_app`, versionName `1.0.3`, versionCode `4`, launcher label `모어댄`을 확인했다. APK SHA-256은 `a89ff0874c78bd2548af856a6d3be49622a43f3846a6d90b24ddba1a0b2f4d9a`다.
- 서명·Manifest: 신규 APK signer SHA-256은 기존 설치 앱 기준값 `a922c098c2dc3d7052895e8ad836b95cf08b9e12f39acd9e6df9d189abb74489`와 일치했다. PROD merged Manifest에 주간 `MtfScheduleWidgetReceiver`, 다음 레슨 `MtfNextLessonWidgetReceiver`, 오늘 레슨 `MtfTodayLessonRollupWidgetReceiver`가 모두 유지됐다.
- 자동 검증: 관련 Flutter 테스트 44개, 전체 Flutter 테스트 403개가 모두 통과했다. 변경 범위 analyze는 신규 compile error 0건이며 기존 warning/info 442건으로 exit code 1이었다. PROD Kotlin compile, Manifest merge, resource merge, PROD Debug APK 빌드, `git diff --check`가 통과했다.
- 실기기 중단: `adb devices -l` 결과 연결 기기 목록이 비어 `R3CX40M6EEM`을 찾지 못했다. 요청의 안전 조건에 따라 화면·Keyguard, 설치 전 UID/nickname/profile/일정/tier/widget 기준값을 조회하지 않았고 `adb install -r`도 실행하지 않았다. 따라서 설치 전후 UID·nickname·일정 보존, DEV 혼입, 오늘 위젯 payload/외 N개/warm·cold 탭, 기존 주간 위젯 실화면, Beginner Smart Alarm, 일반 알림 재구축, 고객카드 UI, MyPage 목표·오류 이동, gate는 이번 세션에서 미검증이다.
- 보호: Firebase CLI를 실행하지 않았고 Functions, Firestore Rules/indexes, Storage Rules를 재배포하지 않았다. PROD 운영 문서 자동 생성·조회·수정·삭제, 앱 uninstall, `pm clear`, 데이터 초기화, DEV 데이터 복사, Play Store 배포를 하지 않았다. 사용자 직접 쓰기 검증은 Personal 신규 회원 저장 후 무그룹 필드·callable/readback/snapshot/목록 노출 확인으로 남긴다. 다음 백로그로 이동하지 않는다.

## 2026-07-24 — PROD 1.0.3 (4) 실기기 카나리 설치·읽기 검증

- 기기·설치: `R3CX40M6EEM`은 ADB `device`, 화면 `Awake`, Keyguard `showing=false`였다. 기존 일반 모어댄은 `1.0.2 (3)`였고 기존 APK signer SHA-256은 `a922c098c2dc3d7052895e8ad836b95cf08b9e12f39acd9e6df9d189abb74489`였다. 신규 `1.0.3 (4)` APK signer가 동일함을 다시 확인한 뒤 기존 앱 위에 `adb install -r`만 실행해 `Success`를 확인했다.
- APK: package `com.example.mtf_app`, version `1.0.3 (4)`, PROD project marker만 포함하고 DEV package/project marker는 없었다. APK SHA-256은 `a89ff0874c78bd2548af856a6d3be49622a43f3846a6d90b24ddba1a0b2f4d9a`다.
- 데이터 보존: UID와 nickname은 원문 대신 SHA-256 fingerprint로 비교했고 설치 전후 모두 일치했다. profile 존재, personal 일정 `230 → 230`, tier `Amateur → Amateur`가 유지됐고 신규 onboarding이나 DEV 데이터 혼입은 없었다.
- 오늘 위젯: owner write/readback, environment/workspace match, schema v2 payload write/readback과 revision 일치가 성공했다. 전체 230건 중 한국 날짜 기준 오늘 후보 `payloadItemCount=7`, 현재 시각 이후 `upcomingCount=5`, 상단 2건, 하단 3건, `hiddenCount=0`으로 렌더됐다. launcher의 실제 시간 행 5개 signature가 모두 달라 동일 일정 중복이 없었다. 현재 숨은 일정이 없으므로 `외 N개` 미표시는 정상이다.
- 위젯 탭: warm 탭은 기존 process에서 MainActivity foreground, `source=newIntent`, `coldStart=false`, 현재 주·오늘 요일·다음 레슨 시간 이동, action 1회 consume으로 통과했다. 정상 cold는 force-stop 없이 최근 앱 카드만 제거해 process 없음 확인 후 탭했으며, 새 process 생성, MainActivity foreground, native cold activity 수신, `source=initialIntent`, `coldStart=true`, 동일 Home 이동과 1회 consume으로 통과했다.
- 기존 위젯: PROD launcher의 기존 주간 위젯은 실제 주간 일정 표와 현재 요일 강조를 유지했다. 주간 `MtfScheduleWidgetReceiver`, 다음 레슨 `MtfNextLessonWidgetReceiver`, 오늘 `MtfTodayLessonRollupWidgetReceiver`가 설치 후 모두 유지됐다.
- Smart Alarm: 실제 PROD tier는 작업문 예상 Beginner가 아니라 Amateur였다. 두 등급 모두 Semi-Pro 미만 정책이므로 `tierAllowed=false`, legacy preference `userRequested=true`여도 `effective=false`였다. 최초 동기화에서 기존 pending 166건을 취소하고 `generalNotificationsResynced=true`로 현재 일반 알림 정책을 재구축했으며 다음 동기화는 legacy 후보 0건이었다.
- Personal 고객카드: 회원 0명, 전체 목록 빈 상태와 permission-denied 0건을 확인했다. 화면의 `MORE THAN GYM`은 Firestore legacy custom group 조회 결과가 아니라 코드의 `__ungrouped__` 표시명이다. Personal `_loadGroups()`는 `member_groups` 조회 전에 반환하며 신규 카드 화면에는 legacy custom group 선택지가 없었다. 저장 버튼은 누르지 않았고 PROD 회원 문서를 만들지 않았다.
- MyPage·gate: MyPage는 기존 profile, Amateur, 회원 0명, 레슨 230건을 유지했다. 현재/다음 주 목표 제목과 첫 오류 이동은 관련 자동 테스트로 통과했으며 PROD 프로필을 변경하는 수동 오류 입력은 하지 않았다. Amateur 계정은 고객카드 신규 화면에 진입 가능했고, 신규 레슨계약서는 Semi-Pro gate, 인사이트는 Pro gate가 실제 표시됐다. MORE 비즈니스는 연결 요청이 아직 없고 요청이 생기면 알려준다는 AI FC 대기 안내를 표시했다.
- 오류·보호: 전체 카나리에서 permission-denied 0건, fatal exception 0건, ANR 0건이었다. Firebase CLI, Functions, Firestore Rules/indexes, Storage Rules 배포를 실행하지 않았다. PROD Firestore 문서 자동 생성·수정·삭제, 기존 카드 migration, uninstall, `pm clear`, 앱 데이터 초기화, DEV 데이터 복사, Play Store 배포를 하지 않았다. 남은 쓰기 검증은 사용자가 직접 신규 회원을 저장할 때 callable success → server readback → owner/workspace snapshot → 무그룹 문서 → 전체 목록 노출을 관찰하는 항목뿐이다. 다음 백로그로 이동하지 않는다.
## 2026-07-24 DEV Personal 고객카드·레슨일지 회귀 보완

- 레슨일지 등급: Personal 레슨일지의 최소 등급을 `Semi-Pro`로 통일했다. 고객카드, 회원목록, 홈 스케줄 빠른작업에서 공용 `AifcTierFeatureGateSheet`를 사용하며, `PersonalTrainingLogPage` 자체에도 direct defense를 추가했다. Personal 경로의 내부 작성·회원 서명 동작은 이 페이지 진입 방어 뒤에서만 사용할 수 있다. legacy Binder 진입은 기존 정책을 유지했다.
- 개인정보 동의 원인과 저장: 기존 동의 화면은 `trainingLogConsentAgreed`와 `trainingLogConsentAgreedAt`을 로컬 상태에만 반영해 재진입 시 Firestore 값으로 복원되지 않았다. `members/{memberId}`의 기존 canonical 필드를 `updateManagedMemberConsent` callable transaction으로 저장·초기화하고, 서버 readback과 owner/workspace/member 일치 및 snapshot 수신을 확인한 뒤에만 UI 성공 상태를 적용하도록 변경했다. 최초 동의 시각은 재시도 시 유지하며 초기화는 같은 필드만 되돌린다.
- 기본 그룹 표시명: Personal 화면마다 `MORE THAN GYM` 또는 legacy group 표시 경로를 개별 사용하던 것이 불일치 원인이었다. `trainer_profiles/{uid}.memberDefaultGroupLabel`을 단일 source로 정의하고 기본값을 `MORE THAN GYM`으로 유지했다. trim 및 2~30자 검증을 Function에도 적용했다. 회원목록과 열린 고객카드는 profile snapshot을 구독해 변경값을 반영하며, 회원 문서의 `groupId`/`groupName`을 만들거나 일괄 수정하지 않는다. Personal 고객카드의 그룹 UI는 현재 기본 그룹을 보여주는 읽기 전용 `소속 그룹`으로 정리했다.
- 회원 주소: 고객카드의 최종 필드명을 `회원 주소 (선택)`으로 정리하고 필수 검증에서 제외했다. canonical 저장 필드는 기존 `postal`, `address`, `detailAddress`를 유지한다. Daum 주소 선택 결과는 도로명, 지번, 우편번호, 건물명을 route result로 반환하고 한 번의 행 선택으로 controller와 dirty draft에 적용한다. 선택 직후 서버 저장은 하지 않는다. MyPage의 `activityRegions`는 별도 의미를 유지하며 최대 3개를 로컬 선택 후 기존 저장 버튼에서 일괄 저장하는 현행 구조가 이미 요구사항과 일치해 수정하지 않았다.
- 레슨 종류: `lessonType='미입력'`, 레슨 등록 OFF, 총·잔여 0을 회원 저장 차단 조건에서 제외하고 화면에는 `레슨권 미등록`으로 표시한다. 기본 종류와 별도로 `trainer_profiles/{uid}.customLessonTypes`를 user-scoped source로 사용한다. 직접입력은 trim·공백 정규화·대소문자 무시 중복 검증을 거치며 정상 회원 저장 뒤 profile 목록에 추가한다. 관리 바텀시트에서 사용자 종류만 확인 후 삭제하며 기존 회원·일정·레슨일지의 저장 문자열은 변경하지 않는다.
- 첫 오류 이동: 회원 저장 전에 화면 순서에 따른 첫 오류를 선택하고 다음 frame에서 `Scrollable.ensureVisible` 및 해당 FocusNode 요청을 수행하도록 보완했다. 직접입력 레슨 종류도 별도 target으로 연결했다. 회원 주소 미입력, 레슨 종류 미입력, 총·잔여 0, 개인정보 동의 미작성은 오류 target이 아니다.
- 회원 생성 payload: Personal canonical `createManagedMember`가 기존 회원 주소, 레슨 종류, 총·잔여 회차 및 레슨 미등록 상태를 저장할 수 있도록 허용 필드와 서버 검증을 최소 확장했다. 생성 문서는 계속 현재 Auth UID의 `trainerId`, `workspaceType=personal`로 제한된다.
- 자동 검증: Functions lint와 TypeScript build 통과. 관련 Flutter 테스트 5개 통과. 전체 Flutter 테스트 408개 통과. 변경 파일 대상 `flutter analyze --no-pub --no-fatal-warnings --no-fatal-infos`는 오류 0개로 종료했으며 기존 warning/info만 유지됐다. Firestore/Auth/Functions Emulator에서 41개 시나리오가 통과했고 동의 멱등성·다른 UID 차단·profile preference UID 격리를 포함한다. DEV Debug APK(`app-dev-debug.apk`) 빌드 성공. `git diff --check` 통과.
- DEV 배포: `createManagedMember`, `updatePersonalTrainerProfile`, `updateManagedMemberConsent`만 대상으로 `--project more-than-fitness-dev-mft` 선택 배포를 시도했으나 실행 권한 검토에서 거부되어 실제 배포하지 않았다. Emulator 검증까지만 완료된 상태다.
- 실기기: `adb devices -l`에 연결 기기가 없어 DEV 설치 및 요구된 실화면 검증을 수행하지 못했다. 그룹명 실시간 반영, 주소 picker 실화면, 동의 재진입, 직접입력/삭제, 첫 오류 이동, 오늘 위젯과 Smart Alarm 회귀는 실기기 미검증이다.
- 보호: PROD APK를 빌드·설치하지 않았고 PROD Firebase Functions/Rules/indexes/Storage 배포 및 PROD 운영 데이터 생성·수정·삭제를 수행하지 않았다. 앱 uninstall, `pm clear`, 데이터 초기화, Play Store 배포도 수행하지 않았다.

## 2026-07-24 DEV Personal 고객카드·레슨일지 회귀 최종 보완

- 레슨일지 required tier는 `Semi-Pro`로 통일했다. Personal 고객카드, 회원목록, Home 빠른작업·일정 확정·회원 서명 요청, 빠른서명 페이지, `PersonalTrainingLogPage` 직접 진입에 같은 공용 gate와 페이지 자체 방어를 적용했다.
- 개인정보 동의가 사진 촬영 뒤 사라진 원인은 동의 화면이 로컬 `bool`만 반환하고 canonical 회원 문서를 갱신하지 않았기 때문이다. `members/{memberId}`의 기존 `trainingLogConsentAgreed`, `trainingLogConsentAgreedAt`을 `updateManagedMemberConsent` transaction으로 저장·초기화하고, 서버 readback의 owner/workspace/member 일치와 snapshot 반영을 확인한 뒤에만 완료 처리한다. 저장 실패 시 화면·입력·서명을 유지한다.
- Personal 기본 그룹 표시명은 `trainer_profiles/{uid}.memberDefaultGroupLabel` 한 곳을 사용하며 기본값은 `MORE THAN GYM`이다. 회원목록 필터·목록 배지·고객카드 배지·소속 그룹 표시가 같은 resolver를 사용한다. 회원 문서 일괄 rewrite와 `groupId/groupName` 신규 저장은 하지 않는다.
- 실기기 감사 중 Personal 헤더의 “새 그룹 만들기”가 legacy `_showCreateGroupDialog()`와 `member_groups` create로 연결되는 누락을 발견했다. Personal 진입은 `_showRenameGroupDialog(__ungrouped__)`로 강제 전환하고 `_showCreateGroupDialog()` 자체에도 Personal 방어를 추가했다. 최신 DEV 화면에서 “기본 그룹 이름 변경 / 모든 Personal 회원 표시명”과 “기본 그룹이름을 어떻게 변경해드릴까요?”를 확인했으며 legacy 생성 화면은 열리지 않았다.
- 회원 주소는 기존 canonical `postal`, `address`, `detailAddress`를 유지하면서 선택 항목으로 전환했다. 주소 검색 결과는 도로명 우선, 지번 fallback, 우편번호·건물명을 route result로 보존하고 고객카드 draft에 즉시 반영한다. MyPage의 `activityRegions`와는 분리되어 있다.
- 레슨 종류 미입력·레슨 등록 OFF·총/잔여 0·기간 미등록 상태의 회원 저장을 허용한다. `trainer_profiles/{uid}.customLessonTypes`를 UID 범위 사용자 종류 source로 사용하며 중복 정규화, 직접입력, 목록 삭제를 지원한다. 삭제해도 기존 회원·일정·레슨일지의 문자열은 유지한다.
- 고객카드 저장 오류는 화면 순서 기준 첫 target의 accordion을 먼저 펼치고 다음 frame에 `Scrollable.ensureVisible`, 필요 시 FocusNode 요청을 수행한다. 주소 미입력, 레슨 종류 미입력, 총/잔여 0, 동의 미작성은 오류 target이 아니다.
- Functions: lint/build와 Emulator 41개 시나리오가 통과했다. DEV에만 `createManagedMember`, `updatePersonalTrainerProfile`, `updateManagedMemberConsent`를 선택 배포했다. 세 함수의 create/update는 모두 성공했으며 CLI는 Artifact Registry cleanup policy 미설정 때문에 최종 exit code 1을 반환했다. cleanup policy는 승인 범위 밖이라 변경하지 않았다.
- Flutter: 관련 테스트 18개 통과, 전체 테스트 412개 통과. 변경 범위 machine analyze는 error 0, 기존 warning 142/info 417이다. DEV Debug APK 빌드 성공, `adb install -r` 성공, 기기 `R3CX40M6EEM` 데이터 보존 설치를 확인했다. `git diff --check`는 whitespace 오류가 없다.
- DEV 실기기: 현재 Amateur 계정에서 고객카드/회원목록 레슨일지는 공용 Semi-Pro gate로 차단됐다. 회원목록·고객카드 배지는 `MORE THAN GYM`, 기존 미등록 회원은 `미입력 · 총 0회 / 잔여 0회`와 `기간 미등록`으로 표시됐다. Personal 그룹 메뉴와 canonical 이름 변경 대화상자를 확인했다.
- 미검증: DEV 계정이 Amateur이므로 Semi-Pro 실제 레슨일지 진입, 동의 저장·초기화 실화면, 사용자 레슨 종류 추가·삭제, 주소 검색 네트워크 결과, 첫 오류 스크롤, 그룹 표시명 실제 변경·readback은 자동/Emulator 검증만 완료했다. 이를 실기기 통과로 기록하지 않는다.
- 보호: PROD APK 빌드·설치, PROD Firebase/데이터 작업, Firestore Rules/indexes, Storage Rules, uninstall, `pm clear`, 데이터 초기화, Play Store 배포를 수행하지 않았다. 다음 백로그로 이동하지 않았다.

## 2026-07-24 DEV Personal 고객카드 수동 검증 중단 결과

- 환경: `R3CX40M6EEM`은 ADB `device`, 설치 앱은 `com.example.mtf_app.dev` `1.0.3-dev (4)`였다. DEV 앱만 실행했으며 PROD 앱·Firebase·데이터는 조회하거나 변경하지 않았다.
- 레슨일지 gate: 현재 DEV 계정은 Amateur다. 고객카드 하단과 회원목록의 레슨일지 버튼 모두 `Semi-Pro부터 사용할 수 있어요 / 현재 등급은 Amateur` 공용 sheet로 차단됐다. 저장소와 설치 앱에는 실제 서버 tier를 바꾸지 않는 Semi-Pro Debug fixture가 없어 Semi-Pro 정상 진입·직접 route·QR/회원서명 허용 화면은 검증하지 못했다.
- 그룹 표시명: `MORE THAN GYM`을 DEV 테스트 값 `DEV TEST GROUP`으로 변경했다. `updatePersonalTrainerProfile` 호출 후 회원목록 필터와 카드 배지가 동시에 바뀌었고, 고객카드 검은 띠도 변경됐다. DEV 앱을 종료·재실행한 뒤에도 목록의 두 위치가 유지됐다. 이후 같은 화면에서 `MORE THAN GYM`으로 복원했으며 목록 필터와 카드 배지 두 위치의 복원을 확인했다.
- 주소 UI: 고객카드 기본정보 2/2에서 `회원 주소 (선택)`, `우편번호`, `우편번호 찾기`, `상세주소`와 “나중에 입력해도 돼요” 안내를 확인했다. Kakao 우편번호 WebView가 실제로 열리는 것까지 확인했으나, 기기 포그라운드가 다른 앱으로 전환되어 검색 결과 행 탭·callback·회원 저장·재진입은 안전하게 완료하지 못했다.
- 동의·사용자 레슨 종류·첫 오류 이동: 현재 Amateur 계정에서는 개인정보 동의 카드가 정책상 숨겨지고 Semi-Pro 레슨일지 진입도 차단된다. 서버 tier 변경 없는 fixture가 없어 동의 저장·초기화 실화면을 검증하지 못했다. 레슨 종류 추가·삭제와 첫 오류 이동도 기기 포그라운드가 반복 전환되어 오조작 위험 때문에 시작하지 않았다.
- 회귀: 위젯 warm/cold, Smart Alarm, 이번 주·다음 주 목표는 이번 세션에서 재검증하지 못했다.
- 오류: 앞선 고객카드 진입 로그에서 personal 계정이 `members/{memberId}/achievement_badges`, `members/{memberId}/care_milestones`, `schedules where memberId`, `trainer_profile/me`를 조회해 `PERMISSION_DENIED`와 unhandled exception을 남긴 기록을 확인했다. 새 로그 구간에서 재현을 확정하기 전에 기기 포그라운드가 전환됐으므로 원인 수정 없이 실패 항목으로 남겼다.
- 중단 사유: 기기가 DEV 앱과 카카오톡·메시지·알림창·다른 앱 사이에서 반복 전환되어 좌표 입력이 다른 앱에 전달될 위험이 실제 확인됐다. 사용자 화면을 오조작하지 않기 위해 추가 ADB 입력을 중단했다. 생성한 임시 UI dump와 스크린샷 25개는 작업공간에서 즉시 삭제했다.
- 결론: 필수 항목 전부가 실기기에서 통과하지 않았고 permission-denied 기록도 있어 PROD 1.0.4 준비 완료로 판단하지 않는다. 소스 코드는 수정하지 않았으며 다음 백로그로 이동하지 않았다.
## 2026-07-24 DEV Personal 고객카드 canonical read 권한 오류 보완

- 실제 호출 원인: Home 일정에서 회원카드를 여는 `HomePage._openClientCardFromSchedule()`가 `ClientCardPage`에 `personalOwnerUid`를 전달하지 않았다. 이 카드가 legacy 모드로 초기화되면서 `ClientCardPage._loadDefaultTrainerName()`의 `trainer_profile/me` get, `_loadAchievementBadgesFromFirestore()`의 `members/{memberId}/achievement_badges` get, `_loadCareMilestonesFromFirestore()`의 `members/{memberId}/care_milestones` get, `_bindNextReservationStream()`의 owner 조건 없는 `schedules where memberId == ...` listener가 함께 실행됐다.
- 진입 보완: Home 일정에서 여는 카드에도 현재 Personal owner UID를 전달한다. 카드 내부에서는 `members/{memberId}`의 `trainerId == personalOwnerUid`, `workspaceType == personal`, `managementState != deleted`를 다시 확인한다.
- profile: Personal 기본 트레이너 정보는 `trainer_profiles/{uid}`만 읽는다. `trainer_profile/me`는 legacy workspace에서만 유지하며 Personal에서는 `[MTF_LEGACY_READ_BLOCKED]` 후 canonical profile로 전환한다. profile 실패를 Beginner나 빈 legacy 값으로 덮지 않는다.
- nested 데이터: `care_milestones`, `achievement_badges`는 현재 Rules와 데이터 모델상 legacy 전용 nested collection이다. Personal canonical 대체 저장소가 없으므로 읽기와 자동 badge upsert를 실행하지 않고 안전한 빈 상태를 사용한다. 자동 migration과 Rules 완화는 하지 않았다.
- 회원 일정: top-level `schedules`에서 `trainerId == current Auth UID`, `workspaceType == personal`, `memberId == 현재 회원 ID`를 모두 적용한다. `isDeleted/deleted/isArchived/archived/voided/confirmCancelled` 및 취소·삭제 상태는 다음 예약 계산에서 제외한다.
- 예외 처리: member document listener와 schedule listener에 `onError`를 추가했다. get/listen 오류는 Firebase code만 `[MTF_FIRESTORE_ERROR_HANDLED]`로 한 번 기록하고, schedule은 빈 목록으로 되돌린다. UID, memberId, 회원 이름과 개인정보는 진단 로그에 출력하지 않는다.
- Rules: 저장소 `firestore.rules`는 자기 `trainer_profiles/{uid}`, 자기 Personal member, owner-scoped top-level schedule query를 허용하며 legacy `trainer_profile/me`와 두 nested collection을 Personal에서 거부한다. 변경할 Rules는 없다. Firebase CLI에는 deployed Rules를 가져오는 `firestore:rules:get` 명령이 없어 저장소와 DEV 배포본의 직접 diff는 수행하지 못했다. Rules를 변경하거나 배포하지 않았다.
- Emulator: demo project `demo-mtf-personal-schedules`에서 기존 Rules와 owner/workspace/memberId 3중 조건 query를 포함한 27개 시나리오가 모두 통과했다. 다른 UID 접근, owner 없는 query, legacy 접근은 거부됐다.
- 자동 검증: 관련 Flutter 테스트 8개 통과. 전체 `flutter test --no-pub -r expanded` 416개 통과. 변경 범위 analyze는 error 0건으로 exit code 0이며 기존 warning/info만 남았다. 전체 analyze는 루트 `node_modules/firebase-tools/templates/.../server.dart`까지 분석해 기존 6개 error를 보고했으나 앱 변경 범위 오류는 아니다. DEV Kotlin compile·Manifest merge를 포함한 `flutter build apk --debug --flavor dev -t lib/main_dev.dart --no-pub` 성공. DEV APK `adb install -r` 성공.
- 실기기: DEV cold start와 Home 햄버거 메뉴 진입까지 permission-denied, handled error, unhandled exception, fatal crash, ANR 0건을 확인했다. 고객카드로 이동하는 도중 기기 포커스가 DEV 앱 밖으로 전환되어 즉시 ADB 입력을 중단하고 임시 화면 파일을 삭제했다. 따라서 회원목록·신규/기존 고객카드·accordion·레슨일지 gate의 최종 수동 검증은 미완료이며 통과로 기록하지 않는다.
- 보호: DEV/PROD Firebase 배포, Rules/indexes/Storage 변경, PROD APK 빌드·설치, PROD 데이터 조회·수정·삭제, uninstall, `pm clear`, 데이터 초기화, Play Store 배포를 수행하지 않았다. 다음 백로그로 이동하지 않았다.

## 2026-07-24 DEV Personal 고객카드 신규 진입 권한 오류 보완·검증 재개

- 실제 추가 원인: Personal 신규 고객카드도 `_prepareNewCardAccess()` 허용 후 기존 편집 카드용 `_startClientCardLoading()`을 호출했다. 아직 존재하지 않는 `members/{memberId}`에 `_loadFromFirestore()`, `_bindMemberStatsStream()`, `_bindNextReservationStream()`이 붙어 DEV Rules에서 두 건의 `permission-denied`가 발생했다.
- 최소 수정: 신규 카드는 `_loadInitialNewClientCardData()`에서 Personal 기본 그룹과 담당자 표시용 프로필만 준비하고, 회원 문서·통계·예약 listener는 생성 전 시작하지 않게 분리했다. 신규 진입 회귀 테스트를 추가했다. 기본정보 2/2의 선택 주소 영역은 실제 화면의 11px overflow를 없애기 위해 고정 높이를 223에서 236으로 조정했다.
- DEV 확인: 최신 APK를 `adb install -r`로 데이터 보존 설치한 뒤 Amateur Home과 기존 DEV 일정 10건이 유지됐다. 고객리스트에서 신규 고객카드 진입 직후 `permission-denied`, `trainer_profile/me`, `achievement_badges`, `care_milestones`, owner 없는 schedule query, fatal/unhandled 로그가 0건임을 확인했다.
- 수동 검증 중단 사유: `emulator-5554`에서 앱 크래시가 아니라 Android `System UI isn't responding`과 `Messages keeps stopping`이 반복됐다. 데이터 보존 reboot와 `-no-snapshot-load -gpu swiftshader_indirect` cold boot까지 시도했지만 시스템 UI ANR 및 Firestore 준비 실패가 재발했다. 따라서 Semi-Pro 허용, 동의 저장·초기화, 주소 검색 callback, 사용자 레슨 종류, 첫 오류 이동, 그룹명·위젯·목표 회귀는 통과로 추정하지 않고 미검증으로 남긴다.
- 자동 검증: 관련 고객카드 회귀 테스트 9개 통과. 전체 `flutter test --no-pub -r expanded` 417개 통과. 전체 analyze는 루트 `node_modules/firebase-tools/templates/init/functions/dart/server.dart`의 기존 6개 오류 때문에 exit 1이었다. 변경 파일 분석은 새 error 0건이며 기존 warning/info만 보고했다. DEV Debug APK 빌드 성공. PROD APK는 빌드·설치하지 않았다.
- 보호: DEV/PROD Firebase Functions, Rules, indexes, Storage를 변경하거나 배포하지 않았다. PROD Firebase와 운영 데이터는 조회·수정·삭제하지 않았고, uninstall·`pm clear`·Play Store 배포도 실행하지 않았다. PROD 1.0.4 준비 완료로 처리하지 않는다.
## 2026-07-25 새 DEV API 35 에뮬레이터 수동 검증 중단

- 대상은 `emulator-5554`, AVD `MTF_DEV_API35`, Android 15(API 35) x86_64 system image였다. 기존 `Pixel_6a` AVD와 실제 Galaxy 기기는 사용하지 않았다.
- DEV 앱은 `--flavor dev -t lib/main_dev.dart -d emulator-5554 --debug --no-pub`로 실행했다. 로그에서 `environment=dev`, `projectId=more-than-fitness-dev-mft`, `packageName=com.example.mtf_app.dev`를 확인했다.
- 새 익명 UID로 bootstrap과 personal profile read가 성공했고, nickname/onboarding 미완료 상태에서 기존 OnboardingPage가 표시됐다. DEV 전용 가짜 닉네임 저장 후 personal Home 진입까지 확인했다. 홈의 `김모어` 일정은 서버 일정이 아니라 `HomePage._buildScheduleExampleSlice()`의 빈 사용자 예시 일정임을 코드로 확인했다.
- 초기 상태 확인 시 부팅 완료, 화면 Awake, 네트워크 연결, 자동 날짜·시간, 약 5GB 여유 공간, System UI 프로세스 동작을 확인했다. 첫 Firebase 준비 과정에서 Google Play services ANR이 한 차례 있었고, 프로필 입력 과정에서 `ANR in com.google.android.inputmethod.latin` 및 `Gboard isn't responding` 시스템 대화상자가 추가로 발생했다.
- 요청문의 중단 기준인 시스템 앱 반복 장애가 발생해 추가 ADB 입력을 즉시 중단했다. 고객카드 A~G, Amateur/Semi-Pro gate, 동의 지속성, 주소 callback, 사용자 레슨 종류, 첫 오류 이동, 그룹 표시명, 위젯·Smart Alarm·MyPage 회귀는 미검증으로 남겼다.
- 중단 전 로그 검색에서는 `permission-denied`, `PERMISSION_DENIED`, `trainer_profile/me`, `achievement_badges`, `care_milestones`, 앱 `FATAL EXCEPTION`이 발견되지 않았다. 다만 고객카드 실제 진입 전이므로 최종 0건 검증으로 간주하지 않는다.
- 이번 세션에서는 앱 소스·Functions·Rules·indexes·Storage를 수정하거나 배포하지 않았다. PROD APK를 빌드·설치하지 않았고 PROD Firebase 및 운영 데이터에 접근하지 않았다. 생성한 `.tmp_*` 파일은 작업공간에서 제거했다.
- 자동 검증은 새 코드 변경이 없어 재실행하지 않았다. 직전 기준은 관련 테스트 9개, 전체 Flutter 테스트 417개, DEV Debug APK 성공이며, 이번 수동 검증은 중단되어 PROD 1.0.4 준비 완료로 판단하지 않는다.
## 2026-07-25 MTF_DEV_API35_4K 시스템 앱 ANR 사전 중단

- 새 연결 대상은 `emulator-5554`, AVD `MTF_DEV_API35_4K`, Android 15(API 35), x86_64 Google system image였다. 기존 `Pixel_6a` AVD와 실제 Galaxy 기기는 사용하지 않았다.
- 부팅 완료(`sys.boot_completed=1`), 화면 Awake, Keyguard 해제, 네트워크 VALIDATED, 자동 시간/시간대 활성, `/data` 약 4.4GB 여유를 확인했다. 현재 foreground package는 DEV `com.example.mtf_app.dev`였다.
- 기능 검증을 시작하기 전 logcat 안전 점검에서 `ANR in com.android.phone`, `ANR in com.google.android.gms`, `ANR in com.google.android.gms.persistent`, `ANR in com.google.android.apps.messaging`가 연속으로 확인됐다.
- 요청문의 중단 기준인 시스템 앱 반복 ANR에 해당하므로 고객카드, 등급 fixture, 동의, 주소, 사용자 레슨 종류, 오류 이동, 그룹 표시명, 위젯·Smart Alarm·MyPage 검증을 시작하지 않았다. 결과를 성공으로 추정하지 않는다.
- 앱 소스와 테스트는 수정하지 않았다. Firebase Functions/Rules/indexes/Storage 배포, PROD APK 빌드·설치, PROD Firebase 및 운영 데이터 접근, uninstall, `pm clear`, 데이터 초기화는 수행하지 않았다.
- 새 코드 변경이 없어 Flutter 테스트·analyze·APK 빌드는 재실행하지 않았다. PROD 1.0.4 준비 완료로 판단하지 않고 다음 백로그로 이동하지 않는다.
## 2026-07-25 DEV A-1 재개 시도 — System UI ANR로 사전 중단

- 문서 확인: 작업 시작 전에 `docs/agent/RUN_LOG.md`와 `docs/agent/BACKLOG.md`의 기존 상태를 확인했다.
- 에뮬레이터: `flutter emulators`에서 지정 AVD `MTF_DEV_API35_4K`의 존재를 확인하고 해당 AVD만 실행했다. 이번 실행에서 `flutter devices`로 확인한 실제 device ID는 `emulator-5554`였다. 기존 `Pixel_6a` AVD와 실제 Galaxy `R3CX40M6EEM`은 사용하지 않았다.
- 시스템 이미지 검증: AVD 이름 `MTF_DEV_API35_4K`, Android 15(API 35), ABI `x86_64`, `PAGE_SIZE=4096`을 확인했다. 부팅 완료 후 Nexus Launcher가 foreground였고, 앱 실행 전 12초간 새 `ANR`, `FATAL EXCEPTION`, `permission-denied` 로그는 검출되지 않았다.
- DEV 실행 시도: `flutter run --flavor dev -t lib\main_dev.dart -d emulator-5554 --debug --no-pub`를 시작했다. `Launching lib\main_dev.dart...`와 `Running Gradle task 'assembleDevDebug'...`까지만 확인했다.
- 중단 사유: 빌드 진행 중 foreground에 `Application Not Responding: com.android.systemui`가 표시됐다. 요청문의 즉시 중단 조건에 해당하여 이번 `flutter run` 프로세스를 종료했다.
- 미검증: DEV build/install/start 완료, Personal Home 진입, 회원목록 및 신규 고객카드 진입, `회원 주소 (선택)` 표시, A-1 진입 직전 이후 logcat의 `trainer_profile/me`·`achievement_badges`·`care_milestones` 요청 여부는 확인하지 못했다. 회원 저장 및 A-2 이후 검증은 수행하지 않았다.
- 보호: 소스 코드를 수정하지 않았고, Firebase CLI·Functions·Rules·indexes·Storage 배포를 실행하지 않았다. PROD Firebase·데이터·APK·Play Store 작업, 앱 uninstall, `pm clear`, 앱 데이터 초기화를 수행하지 않았다.
## 2026-07-25 MTF_DEV_API35_4K System UI ANR 환경 진단

- 범위: 앱 실행·설치·빌드·소스 수정 없이, 연결된 `emulator-5554`와 Windows 호스트의 상태만 읽기 전용으로 수집했다.
- 대상 확인: `adb devices -l`과 `flutter devices`에서 Android 대상은 `emulator-5554` 하나였고 상태는 `device`였다. AVD 이름은 `MTF_DEV_API35_4K`, Android 15(API 35) x86_64, `PAGE_SIZE=4096`이었다. 기존 `Pixel_6a`와 실제 Galaxy는 사용하지 않았다.
- ANR 원문: 현재 `dumpsys activity lastanr` 보관 슬롯은 `<no ANR has occurred since boot>`를 반환했다. 다만 보존된 all-buffer logcat에는 `07-25 11:25:46.209`에 PID 838 `com.android.systemui`가 `executing service com.android.systemui/.keyguard.KeyguardService, waited 37741ms` 사유로 ANR 처리된 기록이 남아 있다.
- 동시 환경 징후: 같은 부팅 구간에 Bluetooth service(20.923초 대기), Phone broadcast, Gboard·Android System Intelligence·Google Search interactor startup, GMS persistent broadcast의 ANR이 연속 기록됐다. DEV 앱의 이전 실행 PID들도 `failed to complete startup`으로 ANR 처리됐다. 따라서 해당 시점은 System UI 하나가 아니라 여러 시스템·앱 프로세스의 startup/service 응답 지연이 함께 발생한 상태였다.
- System UI 후속 상태: `07-25 11:32:59.261`에 기존 System UI PID 838이 `user request after error`로 종료됐고 ANR dialog window가 제거됐다. 이후 persistent process로 PID 4015가 재시작됐다.
- 현재 CPU: load average `0.31 / 0.74 / 3.24`, 전체 CPU `9.1%`(user 0.9%, kernel 8.1%, iowait 0%)였다. System UI는 0.1%였고, 현재 시점의 전 CPU 과부하 증거는 없었다. 다만 sensors multihal이 15%로 가장 높았다.
- 현재 System UI 메모리: PID 4015의 total PSS `119,948 KB`, total RSS `255,124 KB`, swap PSS `498 KB`였다. 현재 스냅샷에서 큰 swap 사용이나 명백한 메모리 고갈 징후는 확인되지 않았으며, 이 값만으로 ANR 발생 시점의 메모리 상태를 소급 확정할 수는 없다.
- Emulator/호스트: Android Emulator `36.1.9.0` build `13823996`, graphics backend `gfxstream`이었다. Windows는 Windows 11 Pro `10.0.26200`, `HyperVisorPresent=False`, 전체 물리 메모리 `16,908,132,352 bytes`(약 15.75 GiB)였다.
- AVD 설정: `hw.gpu.enabled=yes`, `hw.gpu.mode=auto`, `hw.ramSize=2048`, `hw.cpu.ncore=2`, `fastboot.forceColdBoot=no`, `fastboot.forceFastBoot=yes`, `disk.dataPartition.size=6G`, `image.sysdir.1=system-images\android-35\google_apis\x86_64\`였다. `snapshot.present` 키는 `config.ini`에 정의돼 있지 않았다.
- 판단 근거: 현재 CPU·System UI 메모리는 안정 상태지만, ANR 발생 구간에는 여러 프로세스가 동시에 startup/service/broadcast timeout을 기록했다. 또한 호스트의 `HyperVisorPresent=False`, AVD 2 cores/2048 MB, Fast Boot 사용 허용, GPU auto/gfxstream이라는 객관적 환경값이 확인됐다. 어느 한 설정을 원인으로 단정하지 않으며 변경은 수행하지 않았다.
- 보호: `flutter run`, Gradle, pub, 앱 설치·실행, AVD/앱 데이터 변경, `pm clear`, Wipe Data, AVD 설정 변경을 하지 않았다. Firebase와 PROD에는 접근·조회·수정·배포하지 않았고 다음 백로그로 이동하지 않았다.
## 2026-07-25 Windows Android Emulator 가상화 가속 진단

- 범위: 앱·AVD·Windows 기능·소스·Firebase를 변경하지 않고 Android Emulator가 사용할 수 있는 Windows VM 가속 상태만 조회했다.
- 에뮬레이터 종료: 시작 시 `emulator-5554`가 `device` 상태였고 AVD 이름이 `MTF_DEV_API35_4K`임을 확인했다. `adb -s emulator-5554 emu kill`로 정상 종료한 뒤 `adb devices -l`에서 에뮬레이터가 사라진 것을 확인했다. 앱 데이터와 AVD 데이터는 삭제하지 않았다.
- 공식 가속 검사 원문:

  ```text
  accel:
  0
  AEHD (version 2.2) is installed and usable.
  accel
  ```

- 가속 판단: Android Emulator 공식 검사는 AEHD 2.2를 설치됨·사용 가능 상태로 판정했다. `sc.exe query aehd`에서도 kernel driver가 `STATE: 4 RUNNING`, `WIN32_EXIT_CODE: 0`이었다. `gvm` 서비스는 오류 1060으로 설치된 서비스가 아니었다.
- CPU 가상화 노출: `Intel(R) N100`, 제조사 `GenuineIntel`이며 `VirtualizationFirmwareEnabled=True`, `VMMonitorModeExtensions=True`, `SecondLevelAddressTranslationExtensions=True`였다.
- Windows 기능/부팅 조회: 일반 권한의 DISM은 오류 740(`Elevated permissions are required`)으로 `HypervisorPlatform` 상태를 확인하지 못했다. 관리자 권한을 요청하거나 승격하지 않았다. `bcdedit /enum all`도 BCD store access denied로 종료되어 `hypervisorlaunchtype`은 미확인이다. 결과가 없는 것을 명시적 항목 없음으로 오인하지 않았다.
- 현재 메모리 원문(KB): `TotalVisibleMemorySize=16,511,848`, `FreePhysicalMemory=5,276,752`, `TotalVirtualMemorySize=38,531,944`, `FreeVirtualMemory=21,148,648`이었다. 사용 가능 물리 메모리는 약 5.03 GiB, 사용 가능 가상 메모리는 약 20.17 GiB다.
- 보호: AVD config, GPU/RAM/CPU/Fast Boot, Windows 기능, BIOS, 드라이버를 변경하지 않았다. `flutter run`, 앱 설치·실행, Gradle·pub·test·analyze, Firebase·PROD 작업을 하지 않았고 A-1 및 다음 백로그로 이동하지 않았다.
## 2026-07-25 Galaxy DEV A-1 수동 검증 — 진입 성공, 화면 정상 표시 실패

- 대상: 사용자가 승인한 실제 Galaxy `R3CX40M6EEM`, 모델 `SM-S926N`, Android 16(API 36)만 사용했다. API 35 에뮬레이터와 Pixel_6a는 사용하지 않았다.
- PROD 보호: 검증 전후 `com.example.mtf_app`과 `com.example.mtf_app.dev`가 동시에 설치돼 있음을 확인했다. PROD는 `versionName=1.0.3`, `versionCode=4`로 유지됐다. PROD 앱을 실행·조작·삭제하지 않았고 데이터와 기존 위젯·알림 설정을 변경하지 않았다.
- DEV 사전 검증: Gradle base applicationId `com.example.mtf_app` + dev suffix `.dev`, target `lib/main_dev.dart`, Firebase projectId `more-than-fitness-dev-mft`, app name `모어댄 DEV`를 확인했다. DEV google-services identity도 package `com.example.mtf_app.dev`와 일치했다.
- DEV 실행: `flutter run --flavor dev -t lib\main_dev.dart -d R3CX40M6EEM --debug --no-pub`로 `app-dev-debug.apk` 빌드·설치·시작이 성공했다. 로그에서 `environment=dev`, projectId `more-than-fitness-dev-mft`, packageName `com.example.mtf_app.dev`, personal workspace 및 canonical Home 진입을 확인했다.
- Home 안정성: Personal Home 진입 후 1분 이상 DEV process와 foreground를 확인했다. 해당 구간에서 `permission-denied`, `PERMISSION_DENIED`, `FATAL EXCEPTION`, ANR, Firebase project mismatch는 검출되지 않았다. System UI, Google Play services, Gboard 응답 없음도 발생하지 않았다.
- A-1 수동 결과: 사용자가 직접 `Personal Home → 회원목록 → 신규 고객카드`로 진입했다. 신규 고객카드 화면과 `회원 주소 (선택)` 표시는 성공했고 회원 정보 입력·저장은 하지 않았다.
- A-1 실패 기준: 주소 영역 아래 카드 내부에 키보드가 닫힌 상태에서도 `BOTTOM OVERFLOWED BY 14 PIXELS`가 재현됐다. `flutter run` 원문에도 `A RenderFlex overflowed by 14 pixels on the bottom.`과 vertical RenderFlex overflow가 기록됐다. 따라서 A-1의 진입·주소 표시는 성공이지만 “화면 정상 표시”는 실패다.
- A-1 로그: 정확한 case-sensitive 필터로 A-1 이후 logcat을 확인한 결과 `permission-denied`, `PERMISSION_DENIED`, `FATAL EXCEPTION`, 독립 ANR marker, `trainer_profile/me`, `achievement_badges`, `care_milestones`, PROD projectId `more-than-fitness-f6adb`, DEV projectId 문자열은 모두 0건이었다. DEV identity는 A-1 이전 앱 시작 로그에서 정상 확인했다.
- 후속 범위: overflow가 발생한 정확한 위젯·제약 위치 조사는 별도 다음 작업으로 남긴다. 이번 작업에서는 소스를 수정하지 않았고 기존 고객카드, 회원 저장, A-2, 동의·주소·레슨 종류 검증으로 진행하지 않았다.
- 보호: Firebase Functions·Rules·indexes·Storage 배포, Firebase PROD 접근·조회·수정, PROD APK 작업, Play Store 배포, uninstall, `pm clear`, 앱 데이터 초기화를 수행하지 않았다. API 35 에뮬레이터 System UI ANR 항목은 여전히 미검증 상태다.
## 2026-07-25 Galaxy DEV 고객카드 묶음 — 첫 오류 이동 중 permission-denied 중단

- 범위: 승인된 Galaxy DEV에서 F 첫 오류 이동의 이름·전화번호 시나리오만 수동 확인했다. 소스는 수정하지 않았다.
- 이름 오류: 최초 저장 시 이름 영역 이동, 이름 입력칸 focus, 키보드 열림, 오류 팝업 표시가 모두 확인돼 최초 첫 오류 이동은 통과했다. 같은 오류 상태에서 저장을 반복하면 재이동·refocus·키보드 재개방이 모두 되지 않아 반복 저장 복구는 실패했다.
- 전화번호 오류: 최초 저장 시 전화번호 영역 이동, 전화번호 입력칸 focus, 키보드 열림, 오류 팝업 표시가 모두 확인돼 최초 첫 오류 이동은 통과했다. 같은 오류 상태에서 저장을 반복하면 재이동·refocus·키보드 재개방이 모두 되지 않아 반복 저장 복구는 실패했다.
- 저장 여부: 화면에는 저장되지 않았다는 안내가 표시됐고 사용자가 확인한 UI 범위에서는 회원이 추가되지 않았다. 현재 보존 logcat에서 `createManagedMember` 및 공통 callable 호출 흔적은 0건이었다. 그러나 즉시 중단 조건 때문에 DEV 서버 member 문서 readback은 수행하지 못했으므로 서버 미생성은 미확인으로 남긴다.
- 중단 원인: 전화번호 검증 구간에 클라이언트 Firestore query `members where phoneNormalized == [redacted] order by __name__`가 실행됐고 `PERMISSION_DENIED: Missing or insufficient permissions`로 실패했다. Flutter 로그에도 `회원 휴대폰 중복 확인 실패: [cloud_firestore/permission-denied]`가 기록됐다.
- 오류 팝업: 팝업이 있었다는 사실과 저장되지 않았다는 사용자 확인은 기록했으나, 정확한 표시 문자열은 현재 로그에 남지 않아 미확인이다.
- 안전 로그: 해당 구간에서 `FATAL EXCEPTION`, 독립 ANR marker, PROD projectId 연결 징후는 검출되지 않았다.
- 판정: F 첫 오류 이동은 “최초 통과 / 반복 저장 복구 실패”로 부분 통과다. permission-denied 즉시 중단 조건에 따라 생년월일, 직접입력, 여러 오류 및 D/E/G와 다른 진입 경로 검증으로 진행하지 않았다.
- 보호: 회원 저장을 의도적으로 완료하지 않았고 소스·Firebase Rules·Functions·indexes·Storage·PROD를 변경하거나 배포하지 않았다.

## 2026-07-25 DEV 고객카드 검증 기반·확정 결함 자동 검증

- DEV 전용 로컬 등급 fixture를 추가했다. `kDebugMode && environment=dev`에서만 `서버 실제 등급 / Beginner / Amateur / Semi-Pro / Pro`를 선택하며, 서버에 저장된 tier는 유지하고 화면 접근 판정에 쓰는 effective tier만 메모리에서 바꾼다. Firestore·Functions 쓰기는 없다.
- 기존 우측 상단 DEV 배지를 길게 누르면 로컬 등급 선택 패널이 표시된다. PROD 환경에서는 패널과 override가 모두 비활성이다.
- 신규·기존 고객카드 공통 최상위에 DEV 전용 viewport wrapper를 적용했다. `OFF / 320 / 360 / 390 / 411dp`를 선택할 수 있고 내부 `MediaQuery.size.width`만 변경하며 height, `viewInsets`, `padding`, `viewPadding`, `TextScaler`는 유지한다. PROD에서는 selector와 폭 override가 비활성이다.
- 기존 고객카드 결함 수정은 유지했다. Personal 신규 회원의 클라이언트 phone 사전 조회를 제거해 서버 transaction을 canonical 중복 경계로 사용하고, 편집 조회는 `trainerId + workspaceType + phone`으로 제한한다. 반복 검증 실패 시 동일 입력칸을 다시 focus하고 키보드를 요청하며, 기본정보 pager 높이는 `236 → 260`으로 조정했다.
- 관련 Flutter 테스트 36개와 전체 Flutter 테스트 433개가 통과했다. DEV 회원·등급 Rules/Functions Emulator 41개 시나리오가 통과했다. 변경 범위 analyze는 오류 0건이며 기존 `client_card_page.dart`의 warning/info 254건은 남아 있다. `git diff --check`는 통과했다.
- DEV Debug APK 빌드가 성공했다. 승인된 태블릿 `TO2408FB00746`(P10HD Lite, Android 10/API 29)에 `adb install -r`로 DEV 패키지만 데이터 보존 설치했고 시작했다. 로그에서 `environment=dev`, projectId `more-than-fitness-dev-mft`, packageName `com.example.mtf_app.dev`, personal Home 진입과 DEV 표시를 확인했다.
- 시작 로그에서 `permission-denied`, `FATAL EXCEPTION`, ANR, PROD projectId 연결 징후는 검출되지 않았다. Galaxy `R3CX40M6EEM`, PROD 앱·APK·Firebase·운영 데이터는 사용하거나 변경하지 않았다.
- 태블릿 실화면 수동 확인은 아직 남아 있다. DEV 로컬 Amateur 선택, 고객카드 360dp overflow, 이름·전화번호 반복 저장 focus/키보드, 320/390/411dp 화면은 사용자의 한 번의 묶음 확인 후 최종 판정한다.

## 2026-07-26 DEV 고객카드 잔여 기능 묶음 — 기능 검증 통과 후 정리 재실행 permission-denied 중단

- 대상과 보호: 태블릿 `TO2408FB00746`의 DEV `com.example.mtf_app.dev`와 DEV Firebase `more-than-fitness-dev-mft`만 사용했다. Galaxy, PROD 앱·APK·Firebase, Play Store, `pm clear`, uninstall, 앱 데이터 초기화, Functions·Rules·indexes·Storage 추가 배포는 수행하지 않았다.
- 수정 전 실제 실패 1: 사용자 레슨 종류를 profile에서 삭제한 뒤 그 값을 쓰는 기존 회원의 회원 현황 1/2에 경고 문구가 추가되지만 고정 높이는 그대로여서 `BOTTOM OVERFLOWED BY 70 PIXELS`가 발생하고 소속 그룹이 잘렸다. `clientCardMemberSetupPageHeight()`에서 이 상태만 462px를 확보하도록 수정했다.
- 수정 전 실제 실패 2: 320dp 기존 고객카드 기본정보 1/2가 이름·나이 suffix·성별과 생년월일·직업을 고정 Row로 유지해 저장된 이름과 생년월일이 잘리고 `OVERFLOWED BY 34`가 표시됐다. 카드 내부 `LayoutBuilder.maxWidth`가 360 이하일 때 동일 필드를 세로 배치하고 PageView 높이를 450으로 확보했다. 성별 dropdown은 `isExpanded: true`를 적용했다.
- canonical 일정 보완: `ClientCardPage._unlinkSchedulesFromDeletedMember()`의 Personal 일정 연결 해제 query도 현재 Auth UID 일치 확인 후 `trainerId + workspaceType=personal + memberId`를 모두 적용했다. `HomeMemberLookupService` 소유권 로그에서 UID 원문 출력을 제거했다.
- Kakao 주소: 신규 고객카드 → 우편번호 찾기 → Kakao 검색 → 공개 테스트 주소 선택 → 앱 callback을 자동 수행했다. `postal/address/detailAddress`가 즉시 표시됐고 create 후 서버 canonical readback, 기존 카드 재진입, 앱 완전 종료·재실행 뒤 유지가 모두 통과했다. 주소 없는 저장 정책은 기존 자동 테스트와 직전 서버 검증 결과를 유지했다.
- 사용자 레슨 종류: DEV 고유 종류 추가와 profile readback, 다른 신규 카드 재표시, 정확한 `발레핏` 추가, 같은 이름 재저장 시 profile callable 미호출, 관리 목록의 중복 1개 유지, 사용자 종류 삭제, 삭제 후 기존 회원의 저장된 `lessonType` 유지가 통과했다. 기본 제공 종류는 관리 목록에 삭제 버튼이 없었다. 정리 후 `customLessonTypes`는 baseline 0개로 복원됐다.
- 기본 그룹 표시명: baseline `MORE THAN GYM`을 보존하고 `DEV GROUP TEST`로 변경했다. 회원목록 필터, 회원 카드 배지, 고객카드 검은 띠, 고객카드 소속 그룹 네 화면과 서버 readback이 일치했다. 앱 재실행과 Home 일정 진입에서는 초기 fallback 뒤 profile listener가 같은 값으로 갱신됐다. 검증 후 단일 profile 필드만 `MORE THAN GYM`으로 복원했고 네 화면과 서버 readback을 다시 확인했다.
- 고객카드 진입: 회원목록→신규, 회원목록→기존, Home 일정→일정 편집→회원카드, 카드 닫기→재진입, DEV 앱 완전 종료→재실행→진입을 확인했다. Home 테스트 일정은 top-level `schedules`에 DEV owner/workspace/member identity를 갖춘 marker 문서 1개만 만들었고 정리했다.
- legacy/canonical 확인: Personal 회원 일정 listener와 삭제 연결 해제는 모두 `trainerId + workspaceType=personal + memberId` 조건과 Auth UID/전달 owner 일치 방어, `onError`를 갖는다. Personal runtime 사전 종료 로그에서 `trainer_profile/me`, `achievement_badges`, `care_milestones`, `member_groups`, owner 없는 schedule 오류, PROD project 문자열은 0건이었다. legacy collection 코드는 legacy workspace 분기로 소스에 남아 있으므로 코드 전체에서 문자열 0이라고 기록하지 않는다.
- viewport 실기기: 320/360/390/411dp에서 기본정보 1/2 저장값, 기본정보 2/2 callback 주소, 주소 안내, 상세주소, 키보드 닫힘·열림, `viewInsets`, 삭제된 종류 경고, 그룹 영역을 screenshot/UI hierarchy로 확인했다. 최종 사전 정리 로그에서 RenderFlex/BOTTOM/RIGHT overflow, fatal crash, ANR은 0건이었다. 실제 Galaxy 휴대폰 검증으로 대체하지 않는다.
- 자동 검증: 관련 Flutter 묶음 75개, 최종 전체 Flutter 451개 통과. managed member 48개, Personal schedules 27개, Personal 레슨일지 38개, legacy 28개, profile 30개, anonymous 26개, nickname 22개, platform admin unit 및 Emulator가 통과했다. platform admin은 최초 독립 실행에서 Emulator 미기동으로 `ECONNREFUSED`가 났고 올바른 Auth/Firestore/Functions Emulator wrapper 재실행으로 통과했다.
- analyze/build: 변경 범위 analyze는 기존 warning/info 254건, 신규 error 0건으로 기준값과 동일했다. `git diff --check`는 line-ending 경고만 있고 통과했다. 최종 DEV Debug APK 빌드와 데이터 보존 `flutter run --no-resident` 설치가 성공했다.
- 정리: DEV 앱을 force-stop한 뒤 이번 marker의 회원 1개와 일정 1개를 삭제했다. 서버 readback은 회원 0, 일정 0, custom type 0, managed/lifetime count 0, tier Beginner, 기본 그룹 `MORE THAN GYM`으로 baseline 복원됐다. 임시 Unicode 입력 helper APK도 제거하고 기기 회전을 원래 값으로 복원했다.
- 즉시 중단 결함: 정리 후 DEV 앱을 재실행하자 Home 최근 회원 캐시에 남은 삭제 member ID로 `members where __name__ in [...]` query가 실행됐고 Firestore `PERMISSION_DENIED`와 Flutter unhandled exception이 발생했다. 실제 ID는 기록하지 않는다. 요청된 즉시 중단 조건에 따라 앱을 force-stop했고, 고객카드 잔여 묶음은 최종 완료 처리하지 않는다.
- 증거: `artifacts/customer_card_remaining_bundle_20260726/automated`와 `artifacts/customer_card_remaining_bundle_20260726/device`. 개인정보·UID·memberId·전화번호·주소 원문은 이 보고서에 기록하지 않는다.
- 다음 묶음: Semi-Pro·개인정보 동의·위젯 회귀로 이동하지 않았다.

## 2026-07-26 DEV Semi-Pro Gate + 개인정보 동의 묶음

- 조사 결과: 중앙 정책은 `AppTierAccessService`가 고객카드 최소 Amateur, 레슨일지·계약·Smart Alarm 최소 Semi-Pro를 판정한다. `DevTierFixtureController`는 Debug DEV의 effective tier만 바꾸며 Firestore/Functions를 호출하지 않고 PROD에서는 무시된다. Smart Alarm은 `tierAllowed && userRequested`로 계산하며 사용자 preference를 강제로 false로 저장하지 않는다.
- 수정 전 결함: 고객카드 경로만 계약서 없는 회원의 동의를 확인했고 회원목록, Home 일정 레슨일지·빠른서명·확정·서명 요청, `PersonalTrainingLogPage` 및 빠른서명 직접 진입은 동일한 canonical 동의 판정을 일관되게 거치지 않았다.
- 수정: `PersonalTrainingLogEntryGuard`를 추가해 매 진입마다 중앙 tier gate → `members/{memberId}` Source.server owner/workspace/member 확인 → 계약 또는 canonical 동의 판정 → 기존 동의 화면/callable → Source.server 재확인 순서를 공통화했다. 다른 owner, non-personal, member 불일치는 진입을 거부하고 식별자를 로그에 남기지 않는다.
- 적용 경로: 고객카드, 회원목록, Home 일정 레슨일지, 빠른서명, 일정 확정, 회원 서명 요청, `PersonalTrainingLogPage` 직접 route, 빠른서명 직접 route에 공통 guard를 적용했다. QR/deep link는 실제 공개 URL을 열지 않고 서명 요청 생성 진입점과 내부 direct defense를 정적·자동 검증했다.
- callable 보안: 기존 `updateManagedMemberConsentHandler`는 auth UID 필수, transaction 기반 owner/workspace/member identity 확인, `memberId/agreed` allowlist, true 시 server timestamp, false 시 agreedAt 삭제를 사용한다. Functions 코드는 수정·배포하지 않았다.
- 자동 검증: 핵심 Gate·동의·DEV fixture·Smart Alarm 25개와 최종 전체 Flutter 465개가 통과했다. managed member Emulator 48개에서 동의 true/readback/reset 및 다른 owner 차단이 통과했고, profile 30·anonymous 26·nickname 22·Personal schedules 27·Personal 레슨일지 38·legacy 28·platform admin unit/Emulator도 통과했다. Functions TypeScript build 성공, 변경 범위 신규 error 0, 최종 보강 테스트 analyze 0건, `git diff --check` 통과, DEV Debug APK 빌드 성공이다.
- 실기기 배포: `TO2408FB00746`의 `com.example.mtf_app.dev`만 데이터 보존 `flutter run --flavor dev -t lib/main_dev.dart --debug --no-pub --no-resident`로 갱신했다. DEV project/region/package를 확인했고 Galaxy·PROD는 조작하지 않았다.
- 실기기 Gate: DEV 배지에서 Amateur 선택 후 회원 0명 고객리스트 진입이 허용됨을 확인했고, Semi-Pro 선택 radio와 즉시 반영을 확인했다. 앱 force-stop·재실행 뒤 fixture가 기존 정책대로 `서버 실제 등급`으로 초기화되고 서버 read 로그는 Beginner였다. 로컬 예시 일정은 실제 데이터가 아니어서 동작 진입 전 안내로 차단됐고 write는 없었다.
- 실기기 동의 blocker: 시작·종료 시 DEV 회원이 0명이고 실제 서버 tier는 Beginner다. `createManagedMember`는 서버 tier가 Amateur 미만이면 `amateur_required`로 거부하며, 안전한 DEV-only canonical 회원 fixture 경로는 없다. 실제 tier 변경 금지 조건을 지키면 계약서 없는 회원 생성, `updateManagedMemberConsent` 실호출, agreed/readback/reset/재진입·재실행을 실기기에서 수행할 수 없다. 확인하지 않은 항목은 통과 처리하지 않는다.
- 종료 상태: local fixture를 서버 등급으로 복원하고 DEV 앱을 force-stop했다. 식별자 없는 로그 계수는 permission-denied 0, fatal 0, ANR 0, PROD project 0, consent callable 0, training-log 진입 0이며 schedule 0·최근 회원 후보 0을 확인했다. 테스트 회원·일정은 생성되지 않아 삭제 대상이 없고 서버 baseline을 변경하지 않았다.
- 증거: `artifacts/semi_pro_consent_20260726/device`. 스크린샷/UI hierarchy와 식별자 없는 로그 요약만 보존하며 UID/memberId/전화번호 원문은 문서에 기록하지 않는다.
- 범위 보호: Firebase 추가 배포, 실제 tier 변경, `pm clear`, uninstall, PROD APK/Firebase, Galaxy 조작을 하지 않았고 다음 위젯·알림 회귀 묶음으로 이동하지 않았다.

## 2026-07-26 DEV 실제 Semi-Pro 임시 승급·개인정보 동의 실기기 검증

- 승인 범위: `TO2408FB00746`의 현재 DEV Auth UID와 `more-than-fitness-dev-mft`만 사용했다. UID/memberId 원문은 출력 보고서와 신규 artifact에 기록하지 않았다.
- 시작 baseline: canonical profile은 `tier=Beginner`, 관리 회원 0, 누적 회원 0, custom lesson type 0, 기본 그룹 `MORE THAN GYM`이었고 owner-scoped member/schedule은 각각 0건이었다.
- 임시 승급: Firebase CLI OAuth 토큰을 출력하지 않고 Firestore REST `updateTime` precondition을 사용해 `trainer_profiles/{uid}.tier` 한 필드만 `Semi-Pro`로 변경했다. 서버 readback과 DEV 앱의 `rawTier/currentTier=Semi-Pro`, Home Pro 진행 카드 0/50 표시를 확인했다.
- 테스트 회원: 실제 개인정보가 아닌 DEV marker 회원 1건을 저장했다. `createManagedMember` 성공 뒤 서버는 관리 회원 1, 누적 회원 1, member 1, schedule 0이었다. member readback은 `trainerId` owner 일치, `workspaceType=personal`, legacy `groupId/groupName` 부재를 확인했다.
- 동의 흐름: 계약서 없는 미동의 고객카드에서 레슨일지를 눌렀을 때 개인정보 동의 화면이 열렸다. `동의하고 계속하기` 뒤 `updateManagedMemberConsent` callable 1회가 실행됐고 레슨일지 화면에 진입했다.
- 동의 서버 readback: 테스트 member의 `trainingLogConsentAgreed=true`와 `trainingLogConsentAgreedAt` 존재를 Source와 독립된 Admin REST readback으로 확인했다. callable 응답이나 로컬 bool만으로 통과 처리하지 않았다.
- 즉시 중단: 동의 저장 직후 세션 logcat에 `permission-denied` 9건이 발생했다. 식별자 없는 분류에서 members marker 2, training_logs marker 2였고 unhandled exception 0, fatal 0, ANR 0, PROD project marker 0이었다. 요청된 중단 조건에 따라 앱을 즉시 force-stop하고 고객카드 재진입, 앱 재실행 유지, 동의 초기화, 초기화 후 재진입·재실행은 수행하지 않았다.
- 정리·원복: 앱 정지 상태에서 정확한 DEV marker/owner/workspace와 document `updateTime`을 확인한 뒤 테스트 회원 1건 삭제와 profile `tier/earnedTier/earnedTierRank/managedMemberCount/lifetimeQualifiedMemberCount` baseline 복원을 단일 DEV Firestore commit으로 수행했다.
- 최종 readback: `tier=Beginner`, 관리 회원 0, 누적 회원 0, member 0, schedule 0, custom lesson type 0, 기본 그룹 `MORE THAN GYM`이다. DEV 앱 프로세스는 종료 상태이며 임시 OAuth guard와 관리 script도 제거했다.
- 증거: `artifacts/semi_pro_consent_live_20260726/device`. 신규 artifact에는 스크린샷/UI hierarchy와 식별자 없는 로그 계수만 보존한다.
- 미작업: PROD 프로젝트·PROD 앱/APK, Galaxy, Functions·Rules·indexes·Storage 배포, `pm clear`, uninstall, 다음 회귀 묶음은 작업하지 않았다.

## 2026-07-26 — Semi-Pro 개인정보 동의 후 permission-denied 수정·재검증 완료
- 원인 조사: 동의 성공 직후 `PersonalTrainingLogPage._loadTrainingLogDataSources()`가 시작한 서로 다른 비정규 read 3종을 확인했다. Personal `training_logs` 조회 2곳이 `memberId`만 사용했고, Personal에서 금지된 legacy `members/{memberId}/goal_ddays` 조회 1곳이 실행됐다. 보존된 기존 artifact에는 집계 9건만 있고 원본 logcat이 없어, 9개 개별 로그를 시간순으로 다시 매핑하지는 않았다.
- 수정: Personal `training_logs` 조회를 `trainerId == currentUid`, `workspaceType == personal`, `memberId == currentMemberId` 조건의 공통 query로 통일했다. Personal에서는 legacy goal D-day/care milestone/badge read·write 경로를 호출하지 않고, 일정 fallback도 동일 owner 조건을 적용했다. read 실패 로그는 오류 code만 남기며 UID/memberId 원문을 기록하지 않는다.
- 추가 발견·수정: 동의 완료 뒤 고객카드 상단 카드가 숨겨져 `동의 초기화`에 접근할 수 없던 조건을 최소 수정했다. 계약서가 없는 Semi-Pro 회원도 완료 상태·동의서 확인·동의 초기화 UI를 유지한다.
- 변경 파일: `lib/pages/personal_training_log_page.dart`, `lib/pages/client_card_page.dart`, `test/personal_training_log_entry_guard_test.dart`와 본 작업 기록 문서다. 기존 미커밋 변경은 되돌리거나 범위를 넓히지 않았다.
- 자동 검증: 관련 Flutter 42개, 전체 Flutter 470개, managed member Emulator 48개, Personal training log Emulator 38개 및 나머지 Emulator suite(27/28/30/26/22와 platform admin 2종) 통과. Functions TypeScript build, 변경 범위 analyze(신규 error 0, 기존 warning/info 363), `git diff --check`, DEV Debug APK build가 통과했다. aggregate Emulator 실행 중 연결 reset 1회는 suite별 재실행으로 전부 통과를 확인했다.
- 실기기: 데이터 보존 DEV 업데이트 설치 후 실제 DEV tier만 Beginner→Semi-Pro로 임시 변경했다. 가짜 회원 생성과 canonical owner/workspace readback, 미동의 화면, `updateManagedMemberConsent` 1회, `agreed=true`와 timestamp 서버 readback, 고객카드 재진입, force-stop·재실행 유지, 레슨일지 진입을 확인했다.
- 동의 초기화: 고객카드에서 초기화 callable 1회를 실행했고 서버 readback은 `agreed=false`, timestamp 없음이었다. 고객카드 재진입과 앱 재실행 뒤 미동의가 유지됐으며 레슨일지 진입 시 동의 화면이 다시 표시됐다.
- 종료 로그: 동의 후 1분 감시와 최종 검사에서 permission-denied 0, unhandled exception 0, training-log read failure 0, legacy marker 0, fatal crash 0, ANR 0, PROD marker 0이다.
- 원복: 이번에 만든 DEV 회원을 삭제하고 tier를 Beginner로 복원했다. 최종 readback은 member 0, schedule 0, 관리/누적 count 0, custom lesson type 0이다. `memberDefaultGroupLabel` 필드는 원래처럼 미저장 상태이며 앱의 effective 기본 표시명은 `MORE THAN GYM`이다. 기존 데이터를 새로 쓰지 않았다.
- 증거: `artifacts/semi_pro_consent_permission_fix_20260726/device`에 식별자를 제외한 화면·UI hierarchy·최종 서버 readback·로그 집계를 저장했다.
- 미작업: PROD 프로젝트·PROD 앱/APK, Galaxy, Firebase Functions·Rules·indexes·Storage 배포, `pm clear`, uninstall, 다음 회귀 묶음은 작업하지 않았다.

## 2026-07-26 Galaxy 최종 DEV 회귀 — PROD 앱 오픈으로 즉시 중단

- 대상·보호 확인: 승인된 `R3CX40M6EEM` / `SM-S926N` / Android 16(API 36)을 사용했다. 시작 시 `com.example.mtf_app`과 `com.example.mtf_app.dev`가 별도 설치돼 있었고 PROD는 `1.0.3 (4)`였다. DEV identity는 `com.example.mtf_app.dev` / `more-than-fitness-dev-mft`였다.
- 실제 DEV baseline: 요청서의 Beginner·회원 0·일정 0과 달리 Galaxy의 현재 DEV 계정은 서버 `tier=Amateur`, 관리/누적 회원 1, owner-scoped member 1, schedule 7, 활동 지역 1, custom lesson type 0, 기본 그룹 `MORE THAN GYM`이었다. 기존값으로 취급해 삭제하거나 tier를 바꾸지 않았다.
- 정적·자동 확인: 오늘 레슨 payload는 schemaVersion 2, epoch milliseconds, Asia/Seoul, owner/environment/project/workspace identity와 payloadRevision stale 차단을 사용한다. Manifest와 appwidget runtime에서 주간·다음 레슨·오늘 레슨 provider 3개를 확인했다. Smart Alarm 계산은 `tierAllowed && userRequested`이며 관련 자동 테스트가 통과했다.
- 수정 1: Personal Home의 이번 주·다음 주 목표는 기존 `goal_weekly_lesson_target`을 읽어 표시만 하고 편집 경로가 없었다. `HomeWeeklyGoalSection.onEdit`과 Home 숫자 입력 dialog를 추가해 양수 저장, 빈 값/0은 기존 기본값 40으로 복원하도록 최소 수정했다. legacy `trainer_profile/me`는 사용하지 않는다.
- 오늘 위젯 실데이터: 현재 DEV owner에만 오늘 marker 일정 6건을 추가했다. 앱 로그와 위젯 전용 SharedPreferences readback에서 source 13건, 오늘 후보 6건, payload 6건, schema 2, Asia/Seoul 오늘 날짜, epoch milliseconds, revision 검증 성공을 확인했다. 실제 Galaxy 위젯은 다음 1건, 다다음 1건, 하단 3건, `외 1개`를 표시했고 native render는 `hiddenCount=1`, `renderState=ready`였다.
- 발견·수정 2: 첫 실제 warm tap에서 같은 action이 Dart `dispatching/success` 각각 2회 발생했다. `MainActivity.onNewIntent()`가 MethodChannel 전달 완료 전 pending action과 원 intent를 유지해 lifecycle `consume`이 같은 action을 다시 읽는 경합이었다. 직접 전달 전에 pending action과 intent identity를 비우고, MethodChannel error/notImplemented 때만 pending action을 복원하도록 수정했다.
- 자동 검증: 주간 목표 추가 관련 60개 테스트가 통과했다. warm 경합 수정 뒤 관련 Flutter 11개와 `compileDevDebugKotlin`이 통과했다. 수정 APK의 `flutter build apk --debug --flavor dev -t lib\main_dev.dart --no-pub`와 `adb install -r`가 성공했다. 그 이전 최종 코드 기준 전체 Flutter 470개, 전체 Emulator suite, Functions TypeScript build, analyze 신규 error 0, `git diff --check`가 통과했으나, 마지막 두 수정 뒤 전체 묶음은 즉시 중단 때문에 재실행하지 않았다.
- 즉시 중단: 수정 APK warm tap 재검증에서 Home 키가 기본 페이지로 복귀한다고 잘못 가정해 고정 좌표를 사용했다. 해당 좌표가 DEV 오늘 위젯이 아니라 기존 PROD 위젯을 눌러 `com.example.mtf_app`이 foreground가 됐다. PROD package를 대상으로 한 ADB 명령, PROD Firebase 접근, PROD APK 설치, uninstall, `pm clear`, PROD 화면 추가 조작은 없었지만 “PROD 앱 실행 금지”를 위반했으므로 즉시 중단했다. 자동 앱 시작에 따른 내부 부수 효과는 확인하지 않았다.
- 미검증: 수정 후 실제 warm 1회 consume, 정상 cold tap/onCreate, background·foreground 재소비 방지, Amateur/Semi-Pro Smart Alarm 실기기 전환, 일반 알림 보존, 이번 주·다음 주 목표 실기기 저장·재진입·재실행·빈 값, MyPage 활동 지역 저장·readback·복원은 수행하지 않았다.
- 정리: 이번 작업 marker 일정 6건만 삭제했다. 최종 DEV readback은 시작 baseline과 동일한 `tier=Amateur`, member 1, schedule 7, custom lesson type 0, 기본 그룹 `MORE THAN GYM`, 활동 지역 1이다. 기존 DEV 회원·일정·프로필은 삭제·수정하지 않았다. 임시 owner-scoped probe도 제거했다.
- 판정: 즉시 중단 조건 발생, 수정 후 실기기 warm/cold 미검증, 실제 DEV baseline 불일치, 마지막 수정 뒤 전체 자동 검증 미실행 때문에 `DEV 검증 완료` 및 `PROD 1.0.4 준비 가능`으로 판정하지 않는다. Firebase Functions·Rules·indexes·Storage 추가 배포와 Play Store 작업은 수행하지 않았다.

## 2026-07-27 Galaxy 최종 DEV 회귀 재개 — cold 사용자 탭에서 PROD foreground로 재중단

- 범위·보호: 승인된 Galaxy `R3CX40M6EEM`에서 DEV만 재검증했다. 위젯에는 좌표 기반 탭을 사용하지 않았고 warm/cold 실제 탭은 사용자에게 각각 한 번만 요청했다. PROD package 대상 force-stop·clear·uninstall, PROD Firebase 접근, PROD APK/AAB, Firebase 배포는 수행하지 않았다.
- 일회성 probe: `artifacts/final_dev_regression_galaxy_20260727/dev_firestore_probe.cjs`는 projectId를 `more-than-fitness-dev-mft`로 고정하고 현재 DEV owner/workspace 문서만 집계·marker 생성·정리하는 증적용 도구다. 제품 코드 참조는 0건이고 PROD project 문자열도 없다. 이번 재개에서는 서버 쓰기에 사용하지 않았으며 증적 파일로 유지했다.
- 최신 자동 검증: 관련 Flutter 89개와 전체 Flutter 472개가 통과했다. 관련 Emulator는 Personal schedules 27개와 profile 30개가 통과했다. 전체 Emulator suite는 managed member 48, Personal schedules 27, Personal training logs 38, legacy 28, profile 30, anonymous identity 26, nickname 22와 platform admin unit/Emulator가 모두 통과했다. Emulator의 permission-denied 출력은 차단 정책을 확인하는 음성 테스트의 예상 로그다.
- build/analyze: Functions TypeScript build, `git diff --check`, DEV Kotlin compile, merged DEV Manifest, DEV Debug APK build가 통과했다. Manifest에는 주간·다음 레슨·오늘 레슨 provider 3개가 모두 남아 있다. `flutter analyze --no-pub`는 기존 warning/info 1,201건으로 exit 1이었고 `--no-fatal-warnings --no-fatal-infos`는 exit 0이어서 error 0을 확인했다.
- DEV 설치: `flutter run --flavor dev -t lib/main_dev.dart -d R3CX40M6EEM --debug --no-pub --no-resident`로 DEV만 데이터 보존 업데이트했다. 설치 전후 PROD `com.example.mtf_app` `1.0.3 (4)`와 DEV package가 모두 유지됐고 DEV 시작 로그의 package/project는 `com.example.mtf_app.dev` / `more-than-fitness-dev-mft`, 시작 오류 marker는 0건이었다.
- warm 사용자 탭: 탭 직후 사용자가 응답 화면으로 전환해 최종 UI foreground는 ChatGPT였지만 DEV PID 로그에는 `MainActivity.onNewIntent` 1회, Dart `dispatching` 1회, `success` 1회가 있었다. 동일 action의 두 번째 dispatch/success는 없고 오류 marker도 0건이었다. 로그 기준 warm 1회 consume은 통과했다. 화면 중복 push는 탭 직후 UI를 계속 관찰하지 못해 로그 근거와 별도로 미확인이다.
- cold 준비: DEV package만 force-stop했고 PROD·DEV package 보존을 확인한 뒤 logcat을 비웠다. 실제 위젯 탭은 사용자에게 요청했다.
- 즉시 중단: cold 사용자 탭 후 첫 UI hierarchy에서 `com.example.mtf_app`이 foreground로 확인됐다. 요청된 즉시 중단 조건에 따라 DEV cold PID 로그 수집, DEV foreground 재전환, action 재소비 비교를 실행하지 않았고 이후 Galaxy 명령도 수행하지 않았다. Codex는 PROD 위젯을 자동 탭하거나 PROD package를 대상으로 명령하지 않았다. PROD 앱 자동 시작에 따른 내부 부수 효과는 확인하지 않았다.
- 미검증: cold `onCreate`·1회 consume·재소비 0, Smart Alarm Amateur/Semi-Pro/fixture 해제, 일반 알림 유지, 이번 주·다음 주 목표 실기기 저장·재진입·재실행·복원, 활동 지역 저장·readback·복원, 최종 종료 로그는 수행하지 않았다.
- 데이터: 이번 재개에서는 DEV 테스트 일정·회원·목표·활동 지역을 생성하거나 변경하지 않았다. 즉시 중단으로 서버 baseline을 다시 읽지 않았으며 마지막 확인값 `Amateur / member 1 / schedule 7`을 새 확인값으로 갱신하지 않는다.
- 판정: 최신 자동 검증과 warm 로그는 통과했지만 cold 즉시 중단과 나머지 실기기 항목 미검증으로 `DEV 검증 완료` 및 `PROD 1.0.4 준비 가능`으로 판정하지 않는다.

## 2026-07-27 Galaxy DEV 오늘 레슨 위젯 명시적 대상 수정·cold 재검증

- 정적 원인 확정: 수정 전·후 `dumpsys activity intents`와 `dumpsys appwidget`에서 DEV 오늘 위젯은 DEV UID가 생성한 `PendingIntent`, DEV package, DEV `MainActivity`, `morethan-dev` URI를 사용했다. 보존 로그의 과거 PROD foreground 사건은 DEV intent가 PROD로 해석된 것이 아니라 launcher가 별도의 PROD 위젯 token을 전송한 사건이었다. 두 위젯의 표시가 유사해 선택을 구분하기 어려운 상태가 실기기 blocker였다.
- 최소 수정: 세 위젯의 Activity intent를 `MtfWidgetIntentFactory`로 통합하고 runtime package 기반 `ComponentName`, `setPackage`, flavor URI, appWidget instance data를 강제했다. 오늘 action도 package-scoped로 만들고 `MainActivity`가 action·scheme·host·path·extra를 모두 확인한다. DEV flavor에만 picker 이름, `DEV ·` 제목, 보라색 `DEV 전용 · 오늘 레슨 위젯` 배너를 추가했으며 PROD 기본 문자열과 화면은 변경하지 않았다.
- task 구조 판단: Manifest의 `android:taskAffinity=""`는 초기 Flutter Android 보안 기본값으로 확인했고 cross-package 실행 원인이 아니므로 변경하지 않았다. `adb shell am force-stop com.example.mtf_app.dev`가 Android 16에서 DEV 위젯 `PendingIntent`를 취소하므로, force-stop 직후 위젯 탭을 cold 검증으로 사용하는 절차는 유효하지 않음을 확인했다.
- 자동 검증: 위젯 관련 Flutter 90개, 전체 Flutter 473개, 전체 Emulator suite, Functions TypeScript build가 통과했다. analyze는 기존 warning/info 1,201건, 신규 error 0이고 `git diff --check`, DEV Kotlin compile, merged DEV Manifest provider 3개, DEV Debug APK가 통과했다. 마지막 DEV 배너 대비 조정 뒤에는 관련 테스트, 전체 Flutter 473개, Kotlin, analyze error 0, diff check, DEV APK를 다시 확인했다. Android 리소스만 바뀐 마지막 조정 뒤 Emulator와 Functions는 재실행하지 않았다.
- DEV 설치·표식: DEV APK만 `adb install -r`로 데이터 보존 업데이트했다. UI hierarchy에서 launcher의 appWidgetId 75가 `com.example.mtf_app.dev` provider이고 전체 위젯 클릭 영역, DEV 전용 배너, DEV 제목을 표시함을 확인했다. PROD 위젯은 삭제·이동·교체하지 않았다.
- 최신 유효 cold 탭: logcat 초기화 뒤 사용자가 DEV 전용 배너가 있는 위젯을 한 번 눌렀다. ActivityTaskManager에는 DEV package-scoped action·`morethan-dev` data·DEV explicit component START가 정확히 1건 기록됐다. 식별자 없는 lifecycle 태그는 `state=cold` 1회, `onCreate actionMatched/dataMatched` 1회, foreground 처리 1회, delivered/consumed 1회였고 Dart initial-intent dispatch와 success도 각각 1회였다. 이 DEV 탭 구간의 permission-denied, fatal crash, ANR marker는 0이었다.
- 즉시 중단: 같은 logcat 초기화 이후 최신 DEV 탭보다 앞선 별도 시각에 launcher가 PROD `MainActivity`를 시작한 기록 3건이 확인됐다. 이는 최신 DEV 탭의 대상 전환이 아니며 Codex는 PROD package를 대상으로 명령하거나 위젯을 자동 탭하지 않았지만, 요청 조건의 `PROD 앱 foreground 0`을 만족하지 않으므로 즉시 중단했다. PROD 앱 내부 로그의 UID·개인정보 원문은 문서와 artifact에 옮기지 않았다.
- 미진행: foreground 재전환 후 action 재소비 0, Smart Alarm Amateur/Semi-Pro/fixture 해제, 일반 알림, 이번 주·다음 주 목표 실기기 저장·복원, 활동 지역 실기기 저장·복원, DEV baseline 최종 readback은 수행하지 않았다. DEV 서버 쓰기·테스트 데이터 생성·정리는 추가로 하지 않았다.
- 보호·판정: 좌표 기반 launcher 탭, PROD package 대상 force-stop·clear·uninstall, PROD Firebase, PROD APK/AAB, Firebase 배포는 수행하지 않았다. cold DEV intent 자체는 통과했지만 별도 PROD foreground 즉시 중단과 잔여 실기기 항목 미검증으로 `DEV 검증 완료` 및 `PROD 1.0.4 준비 가능`으로 판정하지 않는다.

## 2026-07-27 Galaxy 최종 DEV 회귀 완료 — PROD foreground 3건 비인과 분류

- 분류 기준 시각: 최신 유효 DEV cold 탭은 `12:13:32.604`였다. 해당 입력은 DEV package-scoped action, `morethan-dev` URI, `com.example.mtf_app.dev/com.example.mtf_app.MainActivity` explicit component로 전달됐다.
- PROD 기록 1: `12:01:16.201`, DEV cold보다 `12분 16.403초` 전이다. ActivityTaskManager의 launcher 발신 `glance-action:/...` PendingIntent START와 WindowManagerShell 전환으로 `com.example.mtf_app/.MainActivity`가 top resumed 됐다. launcher가 기존 PROD task를 foreground로 가져온 `result code=2` 사건이며 최근 앱 단순 resume만으로 발생한 로그는 아니다. DEV 처리 전의 독립 사용자/launcher 위젯 입력으로 분류했다.
- PROD 기록 2: `12:02:47.081`, DEV cold보다 `10분 45.523초` 전이다. 동일한 별도 PROD PendingIntent token, launcher 발신 START, WindowManagerShell 전환, PROD top-resumed 순서다. 기존 PROD task resume를 수반한 독립 사용자/launcher 위젯 입력이며 DEV MainActivity 처리 전 사건이다.
- PROD 기록 3: `12:03:12.132`, DEV cold보다 `10분 20.472초` 전이다. 동일한 별도 PROD PendingIntent token과 launcher 발신 START 뒤 PROD task가 foreground 됐다. DEV MainActivity 처리 전의 독립 입력으로, DEV cold 입력 이벤트·intent·transition과 연결되지 않는다.
- 인과관계 판정: 세 기록은 모두 DEV cold보다 10분 이상 앞서고 PROD가 만든 별도 PendingIntent token을 launcher가 전달했다. DEV cold는 그 뒤 별도의 exact DEV explicit START로 시작해 `state=cold`, `onCreate`, delivered/consumed, Dart dispatch/success가 각각 1회 완료됐다. DEV 코드가 PROD package를 명시적으로 실행한 로그와 동일 입력 이벤트 공유는 0건이다. 따라서 세 PROD foreground는 DEV cold와 비인과이며 cold 통과를 유지한다. 이후 중단 기준은 “DEV 위젯 탭 직후 동일 이벤트로 PROD가 foreground가 되는 경우”로 한정한다.
- cold 최종 결과: DEV explicit START 1회, `MainActivity.onCreate` 1회, widget action consume 1회, Dart dispatch 1회, success 1회이며 두 번째 dispatch/success는 0회다. 해당 구간 permission-denied, fatal crash, ANR은 0건이다.
- Smart Alarm: 서버 실제 tier Amateur를 변경하지 않고 DEV fixture만 사용했다. Amateur + requested=true는 `tierAllowed=false`, `effective=false`였고 일반 레슨 알림은 true로 유지됐다. Semi-Pro + requested=true는 UI와 중앙 계산상 effective=true, Semi-Pro + requested=false는 effective=false였다. 검증 후 fixture를 서버 실제 등급으로 복원했고 smart requested=true, 일반 레슨 알림=true를 선택 readback했다. Firestore tier write는 없었다.
- 주간 목표: 기존 override key 부재·기본값 40에서 DEV 테스트값 41을 UI로 저장했다. 앱 재진입에서 이번 주 `10/41`, 다음 주 `0/41`을 확인했고 DEV force-stop·재실행 후에도 유지됐다. 빈 값 저장으로 기존 default 정책에 따라 원복했으며 최종 SharedPreferences에서 override key가 다시 부재했다.
- 활동 지역: 기존 1곳을 보존한 채 DEV 테스트 지역 2곳을 추가해 `activityRegions` 3곳과 최대 3곳 안내, 추가 버튼 비노출을 확인했다. 저장 뒤 `[MTF_MY_PAGE_PROFILE_RELOAD] activityRegionsMatched=true`, 화면 재진입, DEV force-stop·재실행에서 3곳 유지가 확인됐다. 테스트 지역 2곳만 삭제·저장했고 readback 일치, 재실행 후 기존 1곳과 추가 버튼 복원을 확인했다.
- 종료 안전 검사: 엄격 패턴 `permission-denied|PERMISSION_DENIED|FATAL EXCEPTION|ANR in |Application Not Responding|am_anr|Unhandled Exception|more-than-fitness-f6adb|trainer_profile/me|achievement_badges|care_milestones|member_groups`는 0건이었다. 느슨한 `ANR` 문자열에만 걸리는 Samsung 시스템 태그는 앱 ANR로 집계하지 않았다.
- 데이터 원복: 종료 readback에서 DEV project `more-than-fitness-dev-mft`, tier Amateur, managed member 1, member 1, schedule 13, custom lesson type 0, 기본 그룹 `MORE THAN GYM`, 활동 지역 1을 확인했다. schedule 13은 기준 7보다 위젯 marker 일정 6건이 남아 있는 상태였으므로, 증적 probe의 고유 doc prefix와 marker가 모두 일치하는 6건만 삭제했다. 재 readback은 schedule 7이며 나머지 baseline은 동일하다.
- 자동 검증 유지: 이번 재개에서는 제품 코드 수정이 없었다. 최신 코드 기준 위젯 관련 Flutter 90개, 전체 Flutter 473개, 전체 Emulator suite, Functions TypeScript build, analyze 신규 error 0, `git diff --check`, DEV Kotlin compile, Manifest provider 3개, DEV Debug APK 통과 결과를 유지한다.
- 보호·판정: PROD package 대상 ADB 명령, PROD 앱 실행, 좌표 기반 홈 탭, PROD 위젯 조작, PROD Firebase 접근, PROD APK/AAB, Firebase 추가 배포는 수행하지 않았다. 최종 DEV 회귀와 데이터 원복이 완료돼 `DEV 검증 완료`, `PROD 1.0.4 준비 가능`으로 판정한다. 이 판정은 PROD 빌드·배포·설치를 수행했다는 의미가 아니다.
- 증적: `artifacts/final_dev_regression_20260727/prod_foreground_causality_filtered.log`, `artifacts/final_dev_regression_20260727/activity_region_restore_log.txt`, `artifacts/final_dev_regression_20260727/final_strict_log_scan.txt`, `artifacts/final_dev_regression_20260727/dev_regions_reentry.xml`, `artifacts/final_dev_regression_20260727/dev_regions_after_restart2.xml`, `artifacts/final_dev_regression_20260727/dev_regions_restored_after_restart2.xml`.

## 2026-08-03 고객카드 수정·이름 동기화·삭제 반응·Home 메뉴 회귀

- 원인·수정: 신규/수정 저장 경로가 구분되지 않고 수정 뒤 canonical readback과 연결 일정 이름 동기화가 없던 흐름을 `PersonalMemberCardSaveService.updateAndVerify`와 DEV `updateManagedMember`의 owner-scoped 일정 동기화로 보완했다. Home 일정 삭제는 server delete readback 전에 성공 처리하던 흐름을 preflight → server delete verified → local removed → auxiliary sync 순서로 변경했다. drawer는 중복 전체 패널/내부 content animation 때문에 메뉴 문구가 늦게 보이던 원인을 제거하고 최초 frame부터 내용을 노출했다.
- 변경 제품 파일: `functions/src/managed_members.ts`, `lib/pages/client_card_page.dart`, `lib/pages/home_page.dart`, `lib/services/home_schedule_firestore_service.dart`, `lib/services/personal_member_card_save_service.dart`, `lib/widgets/home/lesson_editor/home_lesson_footer_actions.dart`, `lib/widgets/mtf_animated_drawer.dart`. 관련 Emulator/Flutter 회귀 테스트를 추가·보완했다.
- DEV Functions 선택 배포: `firebase deploy --project more-than-fitness-dev-mft --only "functions:updateManagedMember"`만 실행했다. `updateManagedMember`는 `asia-northeast3`, ACTIVE로 확인했고 다른 함수·Rules·indexes·Storage는 배포하지 않았다. CLI exit 1은 Artifact Registry cleanup policy 경고뿐이었고 policy는 변경하지 않았다.
- 자동 검증: managed member Emulator 53개와 전체 Emulator suite, Functions TypeScript build, 관련 Flutter 테스트, 전체 Flutter 483개, 변경 범위 analyze 신규 error 0, `git diff --check`, DEV Kotlin compile, merged Manifest provider 3개, DEV Debug APK가 통과했다. drawer 최종 수정 뒤 관련 9개·전체 Flutter 483개·변경 범위 analyze·diff check·DEV APK를 다시 통과했다.
- 태블릿 기능 검증: `TO2408FB00746` / P10HD Lite / Android 10에서 DEV 데이터 보존 업데이트 설치 후 가짜 회원 2건으로 신규/기존 고객카드, `수정 저장`, 이름·주소·상세주소·레슨 5/3 수정, callable 1회, canonical server readback, 고객리스트·Home 일정·DEV widget payload 이름 동기화, 앱 재실행 유지, 자기 전화번호 유지 수정, 다른 회원 전화번호 중복 차단을 확인했다. 중복 시 update callable은 0회이고 회원 추가 생성도 없었다.
- 동의·레슨일지: Amateur에서는 레슨일지 gate가 표시됐고, DEV local Semi-Pro fixture에서는 미동의 화면 → `updateManagedMemberConsent` 1회 → 레슨일지 진입이 확인됐다. 완료 뒤 고객카드에 동의 초기화 control은 노출되지 않았고 재진입 시 동의 callable 재호출은 0회였다. 실제 signed contract는 만들지 않았으며 역사 snapshot 보존은 Emulator 회귀 테스트로만 확인했다.
- 일정 삭제: 최초 증적 probe가 non-canonical schedule ID를 만든 탓에 삭제 뒤 재등장했으나 제품 canonical ID 규칙과 불일치한 테스트 harness 문제로 분류했다. owner prefix를 포함한 canonical 일정으로 재검증한 결과 `preflight_completed`, `server_delete_verified`, `local_removed`, `auxiliary_sync_completed`가 순서대로 기록됐고 서버 일정 0, 앱 재실행 뒤 재등장 0이었다.
- 태블릿 원복: 테스트 회원 2건과 관리 회원 수를 DEV-only Firestore commit으로 원자적으로 정리하고 실제 tier를 Amateur에서 Beginner로 복원했다. 최종 readback은 `tier=Beginner`, owner member 0, owner schedule 0, managed member count 0이며 누적 자격 수는 기존 정책대로 보존했다.
- Galaxy DEV UX: `R3CX40M6EEM` / SM-S926N / Android 16에 `com.example.mtf_app.dev`만 데이터 보존 업데이트 설치했다. display는 1440x3120, density 600(약 384dp)이며 고객카드 2/2 상세주소 focus=true, 일반 키보드 표시, 수정 callable 1회, canonical readback 2회, 재진입 유지가 확인됐다.
- Galaxy 이름 동기화: 기존 DEV 테스트 회원은 생년월일 필드가 없는 legacy 상태라 최초 저장이 이름이 아닌 생년월일 validation에 정상 차단되고 callable 0회였다. 자격 카운터 변화 위험이 없음을 확인한 뒤 테스트 생년월일과 owner-scoped marker 일정 1건을 임시 사용했다. 이름 끝 `X` 추가 저장 시 member와 일정 이름 일치, Home 즉시 표시, DEV 위젯 payload 반영이 모두 확인됐고 `X` 제거 저장 뒤 Home·위젯도 원래 이름으로 복원됐다.
- Galaxy drawer: 사용자가 DEV Home 햄버거를 한 번 눌렀고 drawer 내용이 즉시 노출됐다. `MORE WELLNESS 회원관리`, 설정, 회원/계약/레슨 메뉴와 Semi-Pro 잠김 안내가 같은 열린 화면에서 확인됐다. 고정 좌표 홈/위젯 탭과 PROD 위젯 조작은 하지 않았다.
- Galaxy 원복·종료: marker 일정 1건과 테스트 생년월일 3개 필드를 제거하고 상세주소 빈 값, 원래 회원 이름을 복원했다. 최종 readback은 `tier=Amateur`, owner member 1, owner schedule 7, managed member count 1, 생년월일 필드 미존재, 상세주소 빈 값이다. DEV 프로세스 logcat은 permission-denied 0, fatal 0, 실제 ANR 0, RenderFlex overflow 0, PROD project marker 0이었다.
- 보호 범위: Galaxy PROD package `com.example.mtf_app` 대상 실행·force-stop·삭제·초기화·설치·위젯 조작은 0건이다. PROD Firebase 접근, PROD APK/AAB, Play Console, Firebase 추가 배포, `pm clear`도 수행하지 않았다.
- 증적 helper: `artifacts/customer_card_edit_bundle_20260802/dev_probe.cjs`, `artifacts/customer_card_edit_bundle_20260802/galaxy_legacy_member_probe.cjs`, `artifacts/customer_card_edit_bundle_20260802/tablet`. 실제 UID, memberId, 전화번호, 주소 원문은 문서에 기록하지 않았다.

## 2026-08-03 웹 계약 서명·레슨 회원 추천·AIFC 계약 업무 강조

- 조사 결과: 현재 `/sign?t=`는 계약서 서명이 아니라 `sign_requests/{token}`과 `training_logs/{trainingLogId}.memberSignature`를 사용하는 레슨일지 빠른서명 흐름이다. 레슨계약서는 top-level `contracts`, 회원권계약서는 `members/{memberId}/membership_contracts`를 사용하며 두 계약 종류를 공개 웹 token으로 resolve/submit하는 Functions 계약이 없다. Firestore Rules도 공개 브라우저의 `sign_requests`, `contracts`, `membership_contracts` 접근을 허용하지 않는다.
- DEV 웹 blocker: `firebase_options.dart`의 Web 설정과 `firebase.json`의 FlutterFire 설정은 PROD project만 가리키며, DEV Web용 FirebaseOptions가 없다. 따라서 앱과 분리된 브라우저에서 DEV 레슨계약서·회원권계약서를 표시하고 서버 시각으로 서명·중복·만료·owner 차단·앱 snapshot 반영을 검증하려면 DEV 전용 token 발급/조회/서명 Functions와 DEV Web Firebase 설정·Hosting 배포가 선행돼야 한다. 승인 없는 Functions·Rules·Hosting 배포는 수행하지 않았다.
- 회원 추천 수정: `HomeMemberSuggestionCandidate`, `homeMemberSuggestionTitle`, `filterHomeMemberSuggestions`를 공통화했다. 빈 입력은 `최근 등록 회원`과 `createdAt` 내림차순, 입력 중은 `회원 검색 추천`과 기존 smart name/choseong helper의 부분·초성 검색을 사용한다. `trainerId == currentUid`, `workspaceType == personal`만 허용하고 owner가 없으면 조회하지 않으며 선택 후보는 canonical `memberId`를 유지한다.
- AIFC 수정: 레슨계약서·회원권계약서의 pulse/glow 애니메이션을 제거하고 두 카드에만 정적 웜 앰버 배경·테두리, 네이비 텍스트, 한 단계 진한 아이콘 영역을 적용했다. 열린 문구는 `레슨 조건을 문서로 남겨요.`, `이용 조건을 명확하게 기록해요.`이며 잠금 상태는 기존 중립색·등급 안내를 유지한다.
- 서명 URL 안전화: Android DEV가 PROD Hosting URL을 생성하던 하드코딩을 `MemberSignUrlService`로 교체해 DEV는 `more-than-fitness-dev-mft.web.app`, PROD는 기존 PROD host를 사용하도록 분리했다. 빈 token은 거부하고 웹 서명 오류 로그에는 exception 원문 대신 타입만 남긴다. 실제 DEV Hosting 배포나 PROD URL 접근은 하지 않았다.
- 자동 검증: 관련 Flutter 45개와 전체 Flutter 496개가 통과했다. Personal training log Emulator 33개, legacy Emulator 28개, platform-admin unit/Emulator 및 나머지 전체 suite 단계가 통과했고 Functions TypeScript build, `git diff --check`, DEV Kotlin compile, merged DEV Manifest, DEV Debug APK가 통과했다. Emulator의 permission-denied 출력은 금지 접근을 확인하는 음성 테스트의 예상 결과다.
- analyze 제한: `flutter analyze --no-pub` 전체는 20분, 변경 파일 범위는 10분 제한에도 종료되지 않아 최신 수치를 확정하지 못했다. 잔류 Dart/Flutter 프로세스는 없었고 변경 파일은 관련·전체 Flutter 테스트와 DEV APK/Kotlin 컴파일로 컴파일 오류 0을 확인했다. analyze를 통과했다고 기록하지 않는다.
- 태블릿 DEV: `TO2408FB00746`에 `com.example.mtf_app.dev`만 데이터 보존 업데이트했다. 실제 owner 회원 문서가 0건이어서 빈 상태 `최근 등록 회원`, 입력 중 `회원 검색 추천`, 검색 결과 없음 정책을 확인했지만 createdAt 실데이터 순서·부분/초성 후보·선택 후 memberId 연결·중복 생성 0은 실기기에서 확인하지 못했다. 해당 동작은 자동 테스트로만 통과했다.
- 태블릿 AIFC: 실제 DEV 테스트 일정 1건을 생성해 편집 모드에서 두 계약 카드의 정적 앰버 배경·테두리와 지정 문구를 hierarchy와 스크린샷으로 확인했다. 일반 키보드가 열린 상태에서도 이름 입력, AIFC 카드, 추천 영역, 저장·삭제 버튼이 겹치지 않았다. 테스트 일정은 삭제했고 schedule stream `docCount=0`과 server delete verify를 확인했다.
- 종료 검사: 태블릿 구간 permission-denied 0, fatal crash 0, ANR 0, RenderFlex overflow 0, PROD project marker 0이다. 증적은 `artifacts/final_contract_member_suggestions_20260803`에 저장했다. UID·memberId·token·계약 ID 원문은 문서에 기록하지 않는다.
- 중단 판정: 태블릿 우선 검증에서 웹 계약 E2E와 실제 회원 추천 연결이 미완료이므로 Galaxy DEV 휴대폰 회귀로 넘어가지 않았다. PROD Firebase·PROD 앱/APK/AAB, Galaxy PROD package, Firebase 배포, Play Console, `pm clear`, git commit/push는 작업하지 않았다.

## 2026-08-03 출시용 회원 추천 검증 완료·웹 계약 차기 버전 분리

- 범위 분리: 이번 출시 후보에서는 최근 등록 회원·이름/초성 추천만 실기기 완료 대상으로 유지했다. 공개 웹 계약서 원격 서명은 현재 구현 기능으로 간주하지 않고 차기 버전 backlog로 분리했으며 Functions·Hosting·Rules를 구현하거나 배포하지 않았다.
- 시작 baseline: `more-than-fitness-dev-mft`의 태블릿 DEV 테스트 profile을 화면의 고유 nickname으로 식별하고 UID를 출력하지 않았다. 서버 readback은 tier Beginner, managed 0, lifetime 2, owner member 0, owner schedule 0이었다.
- fixture 준비: 승인 범위대로 실제 tier를 Amateur로 임시 변경하고 canonical 필드와 server `createdAt`을 가진 가짜 회원 3건을 시간차로 생성했다. readback은 managed 3, owner member 3, owner/workspace 일치였고 createdAt 최신순은 `DEV한가득 → DEV홍길순 → DEV홍길동`이었다.
- 최근 등록 회원: 태블릿 새 레슨 편집 화면의 빈 입력 상태에서 제목 `최근 등록 회원`과 동일한 최신순 3개가 표시됐다. 일정 최근 사용 순서나 로컬 캐시가 아니라 서버 `members.createdAt` 순서와 일치했다.
- 이름 검색: `홍`은 홍길순·홍길동 2명, `길동`은 홍길동 1명, 앞뒤 공백이 있는 ` 홍 `도 동일한 2명을 표시했다. 결과 없는 입력에서는 `검색되는 회원이 없습니다.`가 표시되고 신규 일정 이름 입력 정책이 유지됐다.
- 초성 검색: 현재 helper는 영문 `DEV`를 한글 발음 초성으로 변환하지 않으므로 한글 이름 부분의 초성으로 검증했다. `ㅎㄱㅅ`은 홍길순 1명, `ㅎㄱㄷ`은 같은 초성을 가진 한가득·홍길동 2명을 표시해 동일 초성 후보를 모두 유지했다. 임의로 유사 이름 우선순위를 추가하지 않았다.
- 기존 회원 연결: `길동` 단일 추천을 눌러 기존 회원을 선택하고 일정을 저장했다. 서버 readback은 fixture member 3건 유지, linked schedule 1건, schedule name과 canonical member name 일치였다. 따라서 선택 시 canonical memberId가 연결됐고 신규 회원 중복 생성은 0건이었다.
- 최신 이름 반영: fixture 홍길동 이름을 DEV 서버에서 1건만 수정한 뒤 새 레슨 편집 화면을 열었다. 최근 등록 목록에 수정된 canonical 이름이 즉시 표시됐고 나머지 두 회원과 createdAt 순서는 유지됐다.
- owner 범위: fixture 3건 모두 `trainerId == current UID`, `workspaceType == personal` readback을 통과했다. UI query도 동일 두 조건을 사용하고 수신 후보를 다시 검증한다. 다른 owner fixture를 만들거나 접근하지 않았으며 노출은 0건이었다.
- 공개 계약 링크 감사: `/sign?t=` 생성은 Home·레슨일지·빠른서명의 `sign_requests`/`training_logs` 회원 빠른서명 세 경로에만 존재한다. 레슨계약서·회원권계약서 페이지는 `MemberSignUrlService`나 `/sign?t=`를 호출하지 않으며 작동하지 않는 `계약서 링크 보내기`, `QR 계약서`, `원격 서명` UI는 노출되지 않는다.
- 계약서 문구 구분: 레슨계약서의 `계약서 사본 수령 방식 > 문자 링크`와 `문자 링크 전송`은 공개 서명 URL이 아니다. `_trySendCustomer()`가 생성한 PDF를 `Printing.sharePdf`로 OS 공유창에 전달하는 기존 사본 공유 기능이다. 공개 signing backend가 성공한 것처럼 연결되지는 않지만 `링크` 표현은 실제 PDF 공유 동작과 다르므로 차기 문구 명확화 후보로 남겼다. 이번 release freeze에서는 숨김·backend 구현·문구 수정을 하지 않았다.
- analyze: 직전 전체 `flutter analyze --no-pub` 20분, 변경 범위 Flutter analyze 10분에 이어 이번 관련 파일 `dart analyze`도 15분 제한을 초과했다. 세 실행 모두 잔류 analyzer 프로세스 없이 종료됐으나 최신 error 수는 독립 확정하지 못했다. 관련 Flutter 45개·전체 496개, 전체 Emulator suite, Functions build, DEV Kotlin·Manifest·APK 통과 결과는 제품 코드 추가 변경이 없어 유지한다. 전체 analyze 재실행은 release 전 미확정 항목으로 남긴다.
- 정리·원복: DEV 앱을 정지한 상태에서 이번 fixture 회원 3건과 연결 일정 1건만 삭제했다. tier Beginner, managed 0, owner member 0, owner schedule 0을 readback했고 canonical 생성으로 증가한 테스트 lifetime 3건도 엄격한 precondition으로 시작값 2에만 원복했다. 기존 DEV 데이터는 변경하지 않았다.
- 종료 안전 검사: 정리 후 DEV 앱을 재실행해 stale cache를 확인했다. permission-denied 0, unhandled exception 0, fatal crash 0, ANR 0, RenderFlex overflow 0, PROD project marker 0이었다. 확인 후 DEV 앱만 force-stop했다.
- 보호·freeze: Firebase Functions·Hosting·Rules·indexes·Storage 배포, PROD Firebase·APK/AAB, Galaxy/PROD package, Play Console, `pm clear`, git commit/push는 0건이다. Galaxy 단계와 다른 기능으로 이동하지 않고 release freeze로 전환했다. 증적은 `artifacts/final_contract_member_suggestions_20260803`에 보존한다.

## 2026-08-03 회원 추천 증적 재확인·Galaxy DEV 휴대폰 UX
- 태블릿 실데이터 검증은 같은 출시 후보에서 이미 완료된 서버·UI 증적을 재확인했다. 가짜 회원 3건의 `createdAt` 최신순, `홍`·`길동` 부분 검색, `ㅎㄱㅅ`·`ㅎㄱㄷ` 초성 검색, 기존 canonical `memberId` 일정 연결, 신규 회원 중복 생성 0, 최신 이름 반영, 다른 owner 노출 0 결과를 유지했다.
- 현재 DEV 서버 baseline을 읽기 확인해 project `more-than-fitness-dev-mft`, tier Beginner, managed member 0, owner member 0, owner schedule 0, fixture member 0, lifetime 시작값 2의 원복 상태를 확인했다. 동일 fixture를 다시 만들거나 서버 값을 변경하지 않았다.
- Galaxy `R3CX40M6EEM`에서는 `com.example.mtf_app.dev`만 실행했다. 기존 Galaxy DEV 테스트 회원 1건을 이용해 실제 휴대폰 폭의 레슨 편집 화면, 일반 키보드 표시, 키보드가 열린 상태의 추천 칩·저장 버튼 가시성, 추천 칩 터치와 기존 회원 이름 반영을 확인했다. 저장은 누르지 않아 신규 일정·회원 write가 없다.
- Galaxy 종료 로그는 permission-denied 0, unhandled exception 0, fatal crash 0, ANR 0, RenderFlex overflow 0, PROD project marker 0이다. DEV 앱만 force-stop했고 PROD package·기존 PROD 위젯은 조작하지 않았다.
- 추가 증적은 `artifacts/final_contract_member_suggestions_20260803/galaxy_dev_search.xml`, `galaxy_dev_search.png`, `galaxy_dev_selected.xml`, `galaxy_dev_selected.png`, `galaxy_dev_after_cancel.xml`에 보존한다. 코드·Firebase 배포·PROD APK/AAB·`pm clear`·git commit/push는 0건이다.

## 2026-08-04 레슨 등록 시트 조밀 레이아웃·공유 추천 영역 복원

- 원인: AIFC 공통 quick action에 추가된 고정 `145×34dp`가 모든 버튼을 두 열 대형 카드처럼 보이게 했고, 이름 검색 추천을 `HomeLessonMemberInputSection` 아래에 별도로 삽입하면서 기존 최근 등록 회원 영역과 세로 공간이 중복됐다. 레슨 시트 자체에는 수정 전·후 모두 별도 `maxHeight`나 고정 높이가 없었으며, 커진 체감은 고정 폭 버튼의 줄바꿈과 중복 추천 영역에서 발생했다.
- 치수 복원: `HomeLessonQuickActionsSection`의 폭은 다시 intrinsic으로 두고 공통 높이 `36dp`, padding `9×9dp`, 아이콘 `16dp`, 제목 `11dp`, Wrap 간격 `5dp`/행 간격 `7dp`, radius `14dp`로 통일했다. 계약서 두 버튼도 같은 builder를 사용하고 배경 `#FFFBEB`, 테두리 `#F2C56B`, 네이비 제목·앰버 아이콘만 다르게 유지했다. 설명·등급 문구·추천 배지·pulse·glow는 없다.
- 추천 영역: 이름이 비어 있으면 owner-scoped Personal `members.createdAt` 최신순 최근 회원을 표시하고, 입력하면 같은 `HomeRecentMembersSection` 자리에서 부분·초성 검색 결과로 교체한다. 별도 입력칸 하단 영역은 제거했다. 본문 최대 높이는 최근/검색 공통 `118dp`이며 결과가 많으면 내부 스크롤한다. 키보드가 열린 검색 시작 시 기존 바텀시트 `SingleChildScrollView`만 공유 영역까지 이동시키고 시트 높이는 늘리지 않는다.
- 자동 검증: 관련 Flutter 26개, 전체 Flutter 512개가 통과했다. 변경 범위 analyze는 error 0, 기존 warning/info 68건이며 증가가 없다. `git diff --check`는 exit 0이고 기존 LF→CRLF 안내만 있었다. DEV Debug APK `build/app/outputs/flutter-apk/app-dev-debug.apk` 빌드가 통과했다.
- Galaxy DEV: `R3CX40M6EEM` / SM-S926N / Android 16에 `com.example.mtf_app.dev`만 데이터 보존 업데이트했다. 신규 레슨 시트에서 네 빠른작업의 hierarchy 높이는 모두 `135px`(600 density 기준 `36dp`)였고 폭은 각각 콘텐츠 자연 폭이었다. 조밀한 3개+1개 배치, 계약서 색상만 강조, 제목만 표시, 최근 등록 회원과 저장 버튼의 비겹침을 스크린샷으로 확인했다.
- 키보드·터치: 비식별 검색값 입력 후 `회원 검색 추천`과 기존 DEV 회원 1건이 키보드 위 공유 영역에 표시됐다. 추천 행을 hierarchy bounds로 동적 탭해 canonical 기존 회원 이름 연결을 확인했고 저장은 누르지 않았다. 검색어를 지우면 같은 자리에서 `최근 등록 회원`과 기존 회원 칩이 복귀했다. 고정 좌표는 사용하지 않았다.
- 종료 안전 검사: permission-denied, fatal exception, 실제 ANR, RenderFlex/BOTTOM overflow, PROD project marker는 모두 0건이었다. 최종 foreground는 DEV package였다. PROD package·기존 PROD 위젯·Firebase Functions/Rules/indexes/Storage·PROD Firebase·git commit/push는 작업하지 않았다. 태블릿 검증은 요청대로 생략했다.
- 증적: `artifacts/aifc_compact_layout_20260804/editor_final_empty.png`, `final_search.png`, `final_selected.png`, `final_cleared.png`와 대응 UI hierarchy, `related_tests_final.log`, `flutter_test_final.log`, `analyze_final.log`, `diff_check_final.log`, `apk_build_final.log`, `device_error_scan.txt`.

## 2026-08-04 회원 선택 후 공유 목록 영역 유지 보정

- 잔여 원인: 검색 추천 선택으로 canonical `memberId`가 연결되면 `hasLinkedMember == true`가 되어 검색 추천 표시 조건이 false로 바뀌었다. 이름은 남아 있어 최근 등록 회원 조건도 false였으므로, 선택 직후 공유 목록 영역 전체가 사라졌다.
- 최소 수정: 검색 추천 표시 조건을 `searchKeyword.trim().isNotEmpty` 하나로 제한했다. 회원 연결 여부는 추천 선택·일정 저장의 canonical `memberId`에만 사용하고, 같은 검색어가 남아 있는 동안 공유 목록의 표시 여부에는 관여하지 않게 했다. 이름을 모두 지우면 검색 목록이 닫히고 같은 `HomeRecentMembersSection` 자리에서 최근 등록 회원이 즉시 복귀한다.
- 자동 검증: 관련 Flutter 26개와 전체 Flutter 512개가 통과했다. 변경 범위 analyze는 error 0, warning/info 67건이었고 `git diff --check`와 DEV Debug APK 빌드가 통과했다.
- Galaxy DEV: 빈 이름에서 `최근 등록 회원` 1개, 비식별 검색값 입력에서 같은 자리의 `회원 검색 추천` 1개, 추천 선택 후에도 동일 검색 목록 1개와 canonical 회원 이름 유지, 검색어 삭제 후 같은 자리의 `최근 등록 회원` 1개 복귀를 UI hierarchy로 확인했다. 각 회원 행은 clickable이었고 공유 본문은 `118dp` 제한 안에서 키보드 위에 표시됐다. 저장은 누르지 않아 신규 회원·일정 write는 0건이다.
- 안전 검사: 로그의 `ANR` 문자열 1건은 Samsung 진단 provider의 `anr_logging`, 나머지 5건은 Wi-Fi/Bluetooth scan 시스템 로그로 앱 오류가 아니었다. permission-denied, unhandled exception, 실제 fatal crash·ANR, RenderFlex/BOTTOM overflow, PROD marker는 0건이며 foreground는 DEV package였다.
- 증적: `artifacts/aifc_compact_layout_20260804/member_list_empty2.*`, `member_list_search2.*`, `member_list_selected2.*`, `member_list_cleared2.*`, `member_list_device_error_scan.txt`, `flutter_test_member_list_final.log`, `analyze_member_list_final.log`, `diff_check_member_list_final.log`, `apk_member_list_final.log`.

## 2026-08-04 입력 필드 연결 회원 자동완성 Overlay 최종 전환

- 요구사항 정정: 앞선 `HomeRecentMembersSection` 상호 교체 방식은 최종 구조가 아니다. 최근 등록 회원은 기존 일반 `Column` 위치와 `118dp` 최대 높이를 항상 유지하고, 이름/전화번호 검색 추천만 입력 필드에 연결한 `OverlayEntry` dropdown으로 분리했다.
- 구현: `HomeLessonMemberInputSection`에 `CompositedTransformTarget`/`CompositedTransformFollower` 기반 Overlay를 추가했다. 입력 필드가 focus 상태이고 검색어가 있으며 아직 기존 회원이 연결되지 않았을 때만 표시한다. dropdown은 입력 필드 폭, 최대 `118dp`, 최대 5건이며 결과가 많으면 내부 `ListView`만 스크롤한다. 선택 시 기존 canonical `memberId`와 회원 정보를 연결하고 Overlay를 닫으며, 입력 삭제·focus 해제·시트 dispose 시 즉시 제거한다.
- 최근 회원·시트 유지: `HomeRecentMembersSection`은 검색어와 무관하게 `최근 등록 회원` 제목과 owner-scoped `members.createdAt` 최신순 목록만 담당한다. 검색 추천을 일반 `Column` 자식으로 추가하지 않았고 기존 `Scrollable.ensureVisible`, 공유 영역 조건, 검색용 추가 세로 공간을 제거했다. bottom sheet maxHeight·고정 높이와 AIFC 버튼 치수는 변경하지 않았다.
- 자동 검증: 관련 Flutter 26개와 전체 Flutter 512개가 통과했다. 320/360/390/411dp 및 keyboard viewInsets에서 입력 본문 높이 불변, Overlay 최대 높이, 추천 터치와 canonical `memberId` 연결을 검증했다. 변경 범위 analyze는 error 0, 기존 warning/info 68건이고 `git diff --check` exit 0, DEV Debug APK 빌드가 통과했다.
- Galaxy DEV: `R3CX40M6EEM`의 `com.example.mtf_app.dev`만 데이터 보존 업데이트했다. 빈 입력에서 최근 등록 회원과 AIFC 전체 버튼을 확인했고, 비식별 전화번호 검색값 입력 시 입력칸 바로 아래에 마스킹 추천 1건이 Overlay로 표시됐다. 동시에 최근 등록 회원 제목은 계속 존재했다. 추천을 hierarchy bounds로 동적 탭하면 Overlay가 닫히고 기존 회원이 연결됐으며, 입력을 지우면 Overlay 없이 최근 등록 회원이 유지됐다. 저장은 누르지 않아 신규 회원·일정 write는 0건이다.
- 실기기 치수: 네 AIFC 버튼 높이는 모두 `135px`(600 density 기준 `36dp`)였다. AIFC 제목 top과 최근 등록 회원 제목 top의 차이는 키보드 닫힘 `484px`, 열림 `483px`로 동일 수준이어서 검색 Overlay가 본문을 밀거나 시트를 늘리지 않았다. 키보드·추천 터치·AIFC·최근 회원 사이 신규 겹침과 overflow는 없었다.
- 안전 검사: permission-denied, unhandled exception, fatal crash, 실제 ANR, RenderFlex/BOTTOM overflow, PROD project marker는 0건이었다. 최종 foreground는 DEV였고 DEV 앱만 force-stop했다. PROD package·Firebase Functions/Rules/indexes/Storage·PROD Firebase·git commit/push는 작업하지 않았다. 태블릿 검증은 수행하지 않았다.
- 증적: `artifacts/member_autocomplete_overlay_20260804`의 전체 테스트·analyze·diff·APK 로그와 `device/sheet_empty.xml`, `sheet_search.xml`, `sheet_search.png`, `sheet_selected.xml`, `sheet_cleared.xml`, `sheet_cleared.png`, `final_error_scan.txt`.

## 2026-08-05 회원 기본정보 2열 복원·AIFC 기존 일정 전용 표시

- 회원 기본정보 복원: 고객카드 기본정보 1/2의 360dp 이하 전용 세로 4행 분기를 제거하고 320/360/384/411dp 모두 이름·성별, 생년월일·직업의 2열 2행을 사용하도록 통일했다. 320dp에서도 성별 `미입력`과 `생년월일` 문구가 잘리지 않도록 첫 행 flex 5:4, 둘째 행 flex 3:2를 사용하며 입력 높이·padding·글자 크기는 변경하지 않았다. 기본정보 page 높이는 320/360dp의 450dp 분기에서 공통 260dp로 복원했다.
- 레슨 추천 Overlay 유지: 이름/번호 검색은 `CompositedTransformTarget/Follower` Overlay를 계속 사용하고 일반 Column 높이를 늘리지 않는다. Galaxy DEV 신규 레슨에서 숫자 검색값 입력 시 입력칸 바로 아래 마스킹 추천 1건, 키보드 표시, 기존 위치의 최근 등록 회원 제목·목록 유지, AIFC 비노출을 동시에 확인했다. 저장은 누르지 않았다.
- AIFC 표시 원인과 수정: `HomeLessonQuickActionsSection`은 신규 시트에서도 항상 생성되고 `isPersistedSchedule`은 내부 일부 버튼에만 쓰여 전체 섹션을 숨기지 못했다. `HomeLessonEditorInput.hasPersistedSchedule`이 `actualDocumentId` 또는 `docId`의 비어 있지 않은 값을 기준으로 저장 문서 존재를 판정하고, 부모와 섹션 내부가 모두 이 값으로 신규·임시 입력을 차단하도록 수정했다. 회원 선택 여부는 표시 조건에 사용하지 않는다.
- Galaxy 신규 경로: 빈 시간 칸으로 연 신규 레슨에서 `최근 등록 회원` 1개, AIFC 제목·레슨계약서·회원권계약서 0개였다. 최근 회원을 선택한 뒤에도 AIFC 0개를 유지했다. 별도 신규 시트에서 이름/번호 Overlay가 입력칸 아래에 표시되고 최근 등록 회원은 기존 위치에 남았다.
- Galaxy 기존 경로: 저장된 DEV 일정 문서 셀을 열면 AIFC 제목과 `기존 회원 연결`, `내 회원으로 등록`, `레슨계약서`, `회원권계약서` 네 빠른 작업이 표시됐다. 계약서 두 버튼은 다른 버튼과 같은 조밀한 높이·배치에서 앰버 배경·테두리만 유지했다. 레슨계약서 탭은 Amateur 중앙 feature gate의 Semi-Pro 안내로 정상 전달되고 계약 화면에는 진입하지 않았다.
- 자동 검증: AIFC 관련 Flutter 13개, 회원 Overlay·고객카드 포함 관련 Flutter 53개, 전체 Flutter 512개가 통과했다. 변경 범위 analyze는 error 0, 기존 warning/info 64건이며 `git diff --check` exit 0, DEV Debug APK 빌드가 통과했다.
- 종료 안전 검사: Galaxy `R3CX40M6EEM`의 `com.example.mtf_app.dev`만 데이터 보존 업데이트했다. permission-denied, fatal exception, 실제 ANR, RenderFlex/BOTTOM overflow, PROD project marker는 모두 0건이었고 DEV 앱만 force-stop했다. PROD package·Firebase·태블릿·git commit/push는 작업하지 않았다.
- 증적: `artifacts/compact_member_form_20260804/device/final_client_card_320_ok.png`, `final_360.xml`, `final_client_card_360.png` 및 `artifacts/aifc_schedule_mode_20260805/device/new_lesson.*`, `new_lesson_member_selected.*`, `existing_lesson.*`, `existing_contract_tap.*`, `new_overlay_search.*`.

## 2026-08-05 최종 PROD launcher icon 적용

- 기존 설정 감사: `pubspec.yaml`과 `pubspec.lock`에 `flutter_launcher_icons` 의존성·설정이 없었고 Android `main`의 기본 Flutter `@mipmap/ic_launcher` PNG 5종이 PROD/DEV에 공통 적용되고 있었다. 새 의존성을 추가하지 않고 flavor resource overlay를 사용했다.
- 원본 보존: 사용자가 제공한 1254×1254 RGB PNG를 `assets/branding/more_than_wellness_prod_icon.png`에 그대로 복사했다. 원본과 저장소 사본의 SHA-256이 일치하며 심볼 형태·색상은 변경하지 않았다.
- PROD 일반 아이콘: `android/app/src/prod/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}`에 48/72/96/144/192px `ic_launcher.png`와 `ic_launcher_round.png`를 생성했다. 리샘플링 외 crop·색상 변환·심볼 재작업은 없다.
- PROD adaptive icon: v26 `ic_launcher.xml`/`ic_launcher_round.xml`이 432px 원본 전체 이미지를 adaptive background로 사용하고 foreground는 투명으로 유지한다. 원본 배경과 심볼을 한 레이어로 보존해 추출 과정의 색상·edge 변형을 피했다. PROD manifest overlay에만 `roundIcon`을 선언했다.
- 마스크 안전성: APK adaptive 배경의 dark symbol pixel 13,132개 중 원형 마스크 밖 픽셀은 0개였다. 원형과 radius 96px 둥근 사각형 preview 모두 상·하·좌·우 심볼 잘림 0을 직접 확인했다.
- DEV 분리: `android/app/src/main/res/mipmap-*`는 수정하지 않았다. DEV APK의 xxxhdpi icon hash가 기존 main Flutter icon과 일치했고 PROD icon hash와는 달랐다. DEV package/label도 `com.example.mtf_app.dev`/`모어댄 DEV`로 유지됐다.
- APK 검증: PROD Debug APK와 DEV Debug APK가 모두 빌드됐다. PROD APK는 `com.example.mtf_app`, label `모어댄`, 일반 icon과 roundIcon, density PNG 10개, adaptive XML 2개, adaptive background 1개를 포함한다. APK에서 추출한 legacy/adaptive PNG hash가 생성 리소스와 각각 일치했다.
- 제한 준수: PROD APK는 검증용으로만 빌드했고 기기 설치·실행, Play Store/Play Console, Firebase 접근·배포, version 변경, commit/push는 수행하지 않았다.
- 증적: `artifacts/prod_launcher_icon_20260805/prod_icon_circle_preview.png`, `prod_icon_rounded_square_preview.png`, `apk_prod_circle_preview.png`, `apk_prod_rounded_square_preview.png`, `apk_prod_adaptive_background.png`, `apk_prod_legacy_xxxhdpi.png`.


## 2026-08-05 Galaxy PROD 아이콘 데이터 보존 업데이트 검증

- 설치 전 기준: Galaxy `R3CX40M6EEM`의 `com.example.mtf_app`은 1.0.3(4), firstInstallTime `2025-11-18 17:47:53`, dataDir `/data/user/0/com.example.mtf_app`이었다. 앱은 실행하지 않았다.
- 데이터 보존 설치: `adb -s R3CX40M6EEM install -r build/app/outputs/flutter-apk/app-prod-debug.apk`만 실행했고 결과는 `Success`였다. uninstall·`pm clear`는 실행하지 않았다.
- 보존 확인: 설치 후 버전은 동일한 1.0.3(4), firstInstallTime과 dataDir는 설치 전과 같았고 lastUpdateTime만 `2026-08-05 12:47:53`으로 변경됐다. 기존 앱 데이터 영역을 유지한 package replacement로 판정했다.
- 설치 APK 확인: 기기에서 pull한 `base.apk`와 빌드 APK의 SHA-256이 `9FE744440E2C72F5B58C8128565B1DE7BE84EA9B04EC7A4DBF4FB387C263412B`로 일치했다. 설치 APK는 package `com.example.mtf_app`, label `모어댄`, adaptive icon `res/mipmap-anydpi-v26/ic_launcher.xml`이었다.
- 홈 화면: UI hierarchy로 5페이지를 스캔해 3페이지의 `모어댄` 바로가기를 찾고 해당 영역만 크롭했다. 새 앰버 배경·네이비 심볼 아이콘과 `모어댄` 라벨이 표시됐다.
- 앱 서랍: 5페이지 전체 스캔에서 새 앰버/네이비 `모어댄` 항목 2개가 4페이지에 표시됐다. 하나는 일반 사용자 항목이고 하나는 별도 Android user/profile 배지가 붙은 항목이다.
- 기존 아이콘 분류: 5페이지의 검정/청록 `More Than Wellness` 항목을 앱 실행 없이 길게 눌러 앱 정보 intent만 확인했다. 대상은 별도 설치 package `com.morethanwellness.app`이므로 `com.example.mtf_app`의 기존 바로가기나 런처 캐시가 아니다. 삭제하지 않았다.
- 제한 준수: PROD 앱 실행, uninstall, `pm clear`, Firebase·Play Store, version/signing 변경, commit/push는 수행하지 않았다.
- 증적: `artifacts/prod_launcher_icon_install_20260805/verification_summary.txt`, `after_home_prod_icon_crop.jpg`, `after_drawer_prod_icons_crop.jpg`, `before_drawer_5_preview.jpg`, `old_item_menu_preview.jpg`.

## 2026-08-05 PROD launcher icon 시각 안전 여백 보정

- 원인: 첫 PROD 아이콘은 원본 1254px 전체 이미지를 adaptive background 한 장으로 사용해 심볼 bbox가 585×852px, 상·하 여백이 202/200px이었다. 마스크 잘림은 없었지만 Galaxy launcher에서 위·아래 획이 시각 경계에 가까웠다.
- 레이어 분리: adaptive icon을 full-bleed 앰버 background와 투명 네이비 foreground로 분리했다. background에는 기존 심볼 흔적이 남지 않도록 원본의 앰버 색상 분포를 사용한 매끈한 전체 배경을 생성했고 dark navy pixel은 0개다.
- 10% 축소: 네이비 foreground를 캔버스 중심 기준 가로·세로 동일 90%로만 축소했다. bbox는 585×852px에서 527×767px로 변했고 새 여백은 좌 361, 상 244, 우 366, 하 243px이다. 비율과 우상단의 얇은 붓끝은 uniform Lanczos scale 외 재작성하지 않았다.
- 리소스: mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi 일반·round PNG 10개를 새 합성본으로 재생성하고 v26 일반·round adaptive XML이 각각 새 background·foreground drawable을 참조하도록 변경했다.
- 자동 검증: 원본 SHA-256은 `BF274F5DA37ADADD2088C496535701A0EE1CCE9EBEEA5DBBECDC99E135E4E383`으로 유지됐다. adaptive 432px 전경 bbox는 182×265px, 여백은 좌 124/상 84/우 126/하 83px이다. APK 내부 background·foreground·xxxhdpi 일반·round PNG는 생성 파일과 픽셀 단위로 일치했다.
- 빌드: sandbox 내부 Flutter 호출 2회는 SDK cache 접근 대기로 각각 5분/10분 timeout이었고 컴파일 오류 출력은 없었다. SDK cache 접근을 허용한 동일 명령은 83.1초에 통과해 `build/app/outputs/flutter-apk/app-prod-debug.apk`를 생성했다. APK SHA-256은 `61DBA2AAF4DA2FEA7E48D8A30E96DA5594820CA3E8D18F45A4575842B8419571`이다.
- 데이터 보존 설치: Galaxy `R3CX40M6EEM`에 `adb install -r`만 실행했고 `Success`였다. 1.0.3(4), firstInstallTime `2025-11-18 17:47:53`, dataDir `/data/user/0/com.example.mtf_app`은 유지되고 lastUpdateTime만 `2026-08-05 13:26:43`으로 변경됐다.
- 실기기: 홈 화면과 앱 서랍의 일반·별도 profile 배지 `모어댄` 아이콘에서 상·하 시각 여백 증가를 전후 비교로 확인했다. 앰버 배경은 마스크 끝까지 유지되고 네이비 심볼 비율·붓끝 방향은 유지됐다.
- 제한 준수: PROD 앱 실행, uninstall, `pm clear`, Firebase·Play Store, version/signing 변경, commit/push는 수행하지 않았다.
- 증적: `artifacts/prod_launcher_icon_safe_margin_20260805/verification_summary.txt`, `metrics.txt`, `apk_circle_preview.png`, `apk_rounded_square_preview.png`, `galaxy_home_90pct_crop.jpg`, `galaxy_drawer_90pct_crop.jpg`, `galaxy_home_before_after.jpg`, `galaxy_drawer_before_after.jpg`.

## 2026-08-05 PROD launcher icon 최종 84.6% 여백 보정

- 입력 기준: 최초 원본을 다시 추출하거나 심볼을 다시 그리지 않고, 승인된 90% adaptive foreground PNG를 그대로 입력으로 사용했다. full-bleed 앰버 background와 adaptive XML 구조는 변경하지 않았다.
- 추가 축소: 현재 전경 bbox 중심 `(214.5, 216.0)`을 transform anchor로 고정하고 가로·세로 동일 94% affine scale만 적용했다. 명목 최종 비율은 최초 대비 `0.90 × 0.94 = 0.846`, bbox 유효 비율은 가로 84.56%·세로 84.57%다.
- bbox·여백: 432×432 adaptive canvas에서 수정 전 bbox `(124,84)-(305,348)` 182×265px, 여백 좌124/상84/우126/하83px에서 수정 후 bbox `(130,92)-(300,340)` 171×249px, 여백 좌130/상92/우131/하91px로 변했다. 연속 좌표 anchor는 이동하지 않았고 alpha centroid 변화는 x -0.11px, y -0.20px다.
- 형태 보존: 우상단 열린 붓끝과 좌하단 붓결을 포함한 승인 전경 전체를 단순 균등 축소했다. 외곽선 보정·재드로잉·상하 위치 보정은 없다. 심볼 bbox 종횡비는 수정 전·후 동일 수준으로 유지됐다.
- 배경·DEV 보호: 앰버 background SHA-256은 수정 전·후 `6AF1CF42FC2CA313FF3E55028921E35F4617438DEC846D9C10B6113759EDB90C`로 동일했다. `android/app/src/main/res/mipmap-*` DEV icon 5개 해시도 모두 유지됐다.
- 리소스·픽셀 검증: PROD adaptive foreground 1개와 mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi 일반·round PNG 10개를 동일 84.6% 기준으로 재생성했다. 모든 density의 dark symbol 중심은 정규화 0.5±0.0053 범위였고 일반·round 쌍 hash가 일치했다. APK에서 추출한 background·foreground·xxxhdpi 일반·round PNG는 생성 파일과 픽셀 단위로 일치했다.
- 빌드: `flutter build apk --flavor prod -t lib/main_prod.dart --debug --no-pub`가 37.8초에 통과했다. APK SHA-256은 `9E6FAAAFD5BB391508BDEAA28FBE3CF3F0582671F40432ED9E3469B13EF2E1C9`이다.
- 데이터 보존 설치: Galaxy `R3CX40M6EEM`에 `adb install -r`만 실행했고 `Success`였다. 1.0.3(4), firstInstallTime `2025-11-18 17:47:53`, dataDir `/data/user/0/com.example.mtf_app`은 유지되고 lastUpdateTime만 `2026-08-05 14:01:34`로 변경됐다.
- 실기기: 홈 화면과 앱 서랍의 일반·별도 profile 배지 `모어댄` 아이콘에서 90% 버전보다 상·하 안전 여백이 확실히 증가하고 중앙에 안정적으로 표시되는 것을 전후 비교했다. 우상단 붓끝은 마스크에서 더 멀어졌고 잘림·비율 변화는 없다.
- 제한 준수: uninstall, `pm clear`, Firebase·Play Store, version/signing 변경, commit/push는 수행하지 않았다.
- 증적: `artifacts/prod_launcher_icon_safe_margin_846_20260805/verification_summary.txt`, `metrics.txt`, `resource_90_vs_846.jpg`, `apk_circle_preview.png`, `apk_rounded_square_preview.png`, `galaxy_home_90_vs_846.jpg`, `galaxy_drawer_90_vs_846.jpg`.

## 2026-08-05 PROD launcher icon 최종 80% 조정

- 입력·비율: 승인된 84.6% adaptive foreground PNG만 입력으로 사용하고 추가 비율 `0.80 / 0.846 = 0.945626477541`을 적용했다. 명목 최종 비율은 최초 원본 대비 정확히 80%이며 bbox 유효 비율은 가로 80.11%·세로 80.15%다.
- 중심·형태: 수정 전 bbox 중심 `(215.0, 216.0)`을 affine transform anchor로 고정해 가로·세로를 동일 축소했다. 임의 상하·좌우 이동, 외곽선 보정, 재드로잉은 없다. alpha centroid 변화는 x -0.03px, y -0.23px로 resampling 오차 범위다.
- bbox·여백: 432×432 adaptive canvas에서 수정 전 bbox `(130,92)-(300,340)` 171×249px, 여백 좌130/상92/우131/하91px에서 수정 후 bbox `(134,98)-(295,333)` 162×236px, 여백 좌134/상98/우136/하98px로 변했다. 상·하 안전 여백은 최종 98px로 동일하다.
- 형태 보존: 현재 승인 심볼 전체를 단순 균등 축소해 우상단 열린 붓끝, 좌하단 마른 붓결, 중앙 허리와 획 내부 음영을 유지했다. 원형·둥근 사각형 mask preview에서 붓끝 잘림과 경계 근접은 없었다.
- 배경·DEV 보호: full-bleed 앰버 background와 adaptive XML은 수정하지 않았다. background SHA-256은 전후 `6AF1CF42FC2CA313FF3E55028921E35F4617438DEC846D9C10B6113759EDB90C`로 동일했고 DEV launcher icon 5개 해시도 유지됐다.
- 리소스·픽셀: PROD adaptive foreground 1개와 mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi 일반·round PNG 10개를 최종 80% 기준으로 재생성했다. 모든 density의 심볼 중심은 pixel rounding 1px 이내이며 일반·round pair hash가 일치했다. APK 추출 background·foreground·xxxhdpi 일반·round PNG도 생성 파일과 픽셀 단위로 일치했다.
- 빌드: `flutter build apk --flavor prod -t lib/main_prod.dart --debug --no-pub`가 48초에 통과했다. APK SHA-256은 `B87CE1BE0538205BACD07CD1BC43ADC0E152BF4642D86D359BCB2A8118A7DB68`이다.
- 데이터 보존 설치: Galaxy `R3CX40M6EEM`에 `adb install -r`만 실행했고 `Success`였다. 1.0.3(4), firstInstallTime `2025-11-18 17:47:53`, dataDir `/data/user/0/com.example.mtf_app`은 유지되고 lastUpdateTime만 `2026-08-05 14:23:06`으로 변경됐다.
- 실기기: 동일 홈 배경·동일 crop에서 84.6%와 80%를 나란히 비교했다. 홈과 앱 서랍의 일반·별도 profile 배지 항목 모두 모래시계 인지력은 유지하면서 상하·좌우 여백이 늘어 더 여유 있게 표시됐다. 심볼이 지나치게 작거나 힘없이 보이는 현상은 관찰되지 않았다.
- 제한 준수: PROD 앱 수동 실행, uninstall, `pm clear`, Firebase·Play Store, version/signing 변경, commit/push는 수행하지 않았다.
- 증적: `artifacts/prod_launcher_icon_final_80_20260805/verification_summary.txt`, `metrics.txt`, `resource_846_vs_80.jpg`, `apk_circle_preview.png`, `apk_rounded_square_preview.png`, `galaxy_home_846_vs_80.jpg`, `galaxy_drawer_846_vs_80.jpg`.

## 2026-08-05 Galaxy PROD launcher icon 68% 적용

- 비율·중심: 현재 승인된 80% adaptive foreground만 입력으로 사용해 중심 anchor `(215.0, 216.0)` 기준 가로·세로 동일 `85%` 축소를 적용했다. 명목 최종 비율은 최초 원본 대비 `68%`이며 임의 위치 이동·재드로잉·외곽 보정은 없다.
- bbox·여백: 432×432 adaptive canvas에서 alpha>8 기준 bbox는 `(146,115)-(284,316)` 138×201px, 여백은 좌146/상115/우148/하116px다. full-bleed 앰버 background SHA-256은 `6AF1CF42FC2CA313FF3E55028921E35F4617438DEC846D9C10B6113759EDB90C`로 유지됐다.
- 리소스: PROD adaptive foreground 1개와 mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi 일반·round PNG 10개를 68% 기준으로 재생성했다. 모든 density에서 일반 icon은 adaptive 합성 축소본과 픽셀 일치했고 일반·round pair도 일치했다. DEV 리소스와 adaptive XML은 수정하지 않았다.
- 빌드: `flutter build apk --flavor prod -t lib/main_prod.dart --debug --no-pub`가 통과해 `build/app/outputs/flutter-apk/app-prod-debug.apk`를 생성했다.
- 데이터 보존 설치: Galaxy `R3CX40M6EEM`에 `adb install -r`만 실행했고 `Success`였다. 버전은 1.0.3(4), firstInstallTime은 `2025-11-18 17:47:53`으로 유지되고 lastUpdateTime만 `2026-08-05 16:35:30`으로 변경됐다.
- 실기기: PROD 앱을 실행하지 않고 HOME 화면을 캡처했다. 기존 `모어댄` 바로가기가 68% 심볼로 갱신됐으며 앰버 배경, 중심 위치, 붓끝 형태와 충분한 상하·좌우 여백을 확인했다.
- 제한 준수: uninstall, `pm clear`, Firebase·Play Store, version/signing 변경, commit/push는 수행하지 않았다.
- 증적: `artifacts/prod_launcher_icon_final_68_20260805/galaxy_home_68.png`, `galaxy_home_68.xml`.

## 2026-08-05 MORE THAN 브랜드 라이트·다크 테마 중앙화

- 구조 조사: 실제 `MaterialApp`은 `lib/main.dart`, 기존 활성 테마는 `lib/theme.dart`, 색상 정의는 `lib/theme/app_colors.dart`에 중복돼 있었다. 설정은 `DarkModeNotifier`가 `pref_dark_mode` bool을 저장·복원하는 단일 다크 모드 스위치이며 별도 `ThemeMode.system` 선택 UI는 없었다. 기존 저장 계약은 변경하지 않았다.
- 중앙화: `lib/theme.dart`를 canonical `lib/theme/app_colors.dart` export로 정리하고 라이트 `#F7F5EF/#FFFFFF/#0B1E32/#EFCB62`, 다크 `#071522/#12283A/#162E42/#EFCB62` ColorScheme을 구성했다. AppBar, Card, BottomSheet, Dialog, Input, 버튼 4종, NavigationBar/BottomNavigationBar, Chip, Divider, SnackBar, Switch, Checkbox, Radio, DatePicker, TimePicker 테마를 중앙 정의했다.
- 역할 분리: 일반 UI는 딥 네이비·웜 옐로우를 사용하고 `lib/aifc/core/aifc_theme.dart`의 AIFC 퍼플 팔레트는 유지했다. 계약서 빠른 작업은 동일 크기를 유지한 채 앰버 배경·테두리만 사용한다.
- 핵심 화면: 설정, 홈 scaffold, 오프닝/온보딩, 레슨 등록 시트·최근 회원·검색 Overlay·footer CTA, 회원카드 외곽을 Theme 기반으로 전환했다. Galaxy 첫 다크 홈 검증에서 `오늘 다음 레슨`과 `이번 주 스케줄`이 고정 검정으로 표시된 결함을 발견해 홈 섹션 제목·빈 상태·필터·다음 레슨 카드의 neutral 색상을 Theme 기반으로 최소 수정했다.
- 자동 검증: 테마 집중 테스트 5개와 전체 Flutter 517개가 통과했다. 전체 `flutter analyze --no-pub`는 기존 warning/info 1,184건으로 exit 1이지만 error는 0건이다. 최종 변경 범위 analyze도 기존 warning/info 329건, error 0이며 `git diff --check`와 DEV Debug APK 빌드가 통과했다.
- Galaxy DEV: `R3CX40M6EEM`의 `com.example.mtf_app.dev`만 `adb install -r`로 데이터 보존 업데이트했다. 라이트 홈·설정, 다크 설정, 재시작 후 다크 유지, 다크 홈, 신규 레슨 시트, 숫자 키보드와 추천 Overlay, 기존 일정 AIFC 추천업무·계약서 앰버 버튼, 회원카드를 직접 확인했다. 최초 다크 홈 가독성 결함 수정 후 섹션 텍스트와 표면 대비가 정상이며 저장 버튼 겹침과 overflow가 없었다.
- 상태 복원·안전: 검증 전 `pref_dark_mode`가 없던 기본 라이트 상태였고 종료 시 `false`로 복원한 뒤 재시작 유지까지 확인했다. permission-denied, unhandled exception, fatal exception, ANR, RenderFlex/BOTTOM overflow, PROD project marker는 모두 0건이다. PROD package·Firebase·Rules·Functions·indexes·Storage·commit/push는 작업하지 않았다.
- 증적: `artifacts/brand_theme_20260805/light_home.png`, `light_settings.png`, `dark_settings.png`, `dark_home_fixed.png`, `dark_lesson_sheet.png`, `dark_search_overlay.png`, `dark_existing_lesson.png`, `dark_member_card.png`, `light_restored.png` 및 대응 UI hierarchy.
## 2026-08-06 브랜드 테마 2차 1/3 — 회원관리·내비게이션·공통 시트

- 범위: 회원관리 목록, 고객카드 진입 표면, Home 하단 내비게이션·더보기 메뉴, Drawer, 등급 안내 시트, 공통 BottomSheet·확인 시트와 스케줄러 공통 표면만 브랜드 테마로 정리했다. 운동일지·계약서 내부·빠른서명·알림·위젯·인사이트·통계·목표·DDAY는 수정하지 않았다.
- 중앙 토큰: `MtfThemeTokens`에 회원 목록/카드, 내비게이션, Drawer, sheet/dialog, 등급 안내, 스케줄러 surface·border·grid·header 토큰을 추가하고 라이트/다크 `ColorScheme`에서 파생하도록 했다. AIFC 퍼플은 AI 전용 영역에 유지했다.
- 회원관리: `ClientListPage`의 `trainerId == current UID` 및 `workspaceType == personal` owner-scoped 조회, 검색·필터·정렬·카드 탭 동작과 레이아웃은 유지했다. 목록·필터·카드·빈 상태·그룹 메뉴의 고정 흰색/검정/회색을 테마 surface와 대비 색으로 전환했다.
- 실기기 회귀 수정: Galaxy 다크 모드에서 회원 그룹 PopupMenu 항목이 고정 회색으로 표시돼 가독성이 낮은 문제를 발견했다. 공통 `_memberGroupMenuItemColor`에서 다크 모드 `onSurface/onSurfaceVariant`를 사용하도록 최소 수정했으며 휴면·만료 의미 구분은 유지했다.
- 고객카드·내비게이션: 고객카드 공통 섹션 카드와 하단 액션을 `cardSurface/cardBorder`와 웜 옐로우 CTA로 연결했다. `MtfFloatingMoreMenuButton`과 `HomeBottomNavBar`는 기존 선택·탭·애니메이션을 유지하면서 navigation surface/selected token을 사용한다.
- 공통 시트: `AifcSheetFrame`, `AifcTierFeatureGateSheet`, `AifcConfirmChatSheet`, 시간·반복·주간 복사 관련 공통 시트와 dialog가 theme surface/onSurface/divider를 사용한다. 위험 확인은 기존 red 의미색을 유지하고 일반 확인 CTA만 웜 옐로우를 사용한다. 높이·safe area·키보드·반환값 흐름은 변경하지 않았다.
- 스케줄러: 배경·격자·시간축·날짜 헤더·오늘 강조·선택 border를 theme token에 연결했다. 레슨 상태색, 터치 영역, 10분 단위 동작은 유지했다.
- 자동 검증: 관련 Flutter 테스트 18개 통과, 전체 Flutter 테스트 527개 통과, `flutter analyze --no-pub` error 0·기존 warning/info 1,169건, `git diff --check` 통과, DEV Debug APK 빌드 통과.
- Galaxy DEV: `R3CX40M6EEM`의 `com.example.mtf_app.dev`만 `adb install -r`로 데이터 보존 업데이트했다. 라이트/다크 Home·스케줄러·회원목록·고객카드·Drawer·등급 안내·확인/삭제 시트·검색 키보드와 그룹 PopupMenu를 확인했다. 다크 그룹 PopupMenu 수정 후 텍스트 대비가 정상이며 keyboard overlap·overflow가 없었다.
- 상태 복원·안전: 검증 종료 후 밝은 테마로 복원하고 DEV 앱 재시작 후 유지까지 확인했다. 최종 strict log의 permission-denied, unhandled/fatal exception, DEV ANR, RenderFlex/BOTTOM overflow, PROD project marker는 0건이었다. 사용자 데이터 write·fixture 변경, PROD package, Firebase, Rules/Functions/indexes/Storage, commit/push는 작업하지 않았다.
- 증적: `artifacts/brand_theme_phase2_1of3/`의 `full_flutter_test.txt`, `full_analyze.txt`, `related_flutter_test.txt`, `member_group_popup_dark_fixed.png`, `settings_light_final.png`, `light_restart_final.png`, `final_device_logcat.txt` 및 대응 UI hierarchy.
## 2026-08-06 브랜드 테마 2차 2/3 자동 검증 및 Galaxy DEV 부분 검증

- 범위: 운동일지, 계약서, 빠른서명, 알림 설정, 위젯 설정 화면에 `MtfThemeTokens` 기반 브랜드 surface·border·text·signature 색을 적용했다. 계약 문서와 서명 캔버스는 다크 모드에서도 밝은 문서 표면을 유지하며, AIFC 퍼플·상태색·등급 정책·데이터 계약은 변경하지 않았다.
- 전체 Flutter 무출력 timeout 원인은 제품 테스트 hang이 아니라 sandbox 사용자에서 Flutter SDK 소유권 검사와 `C:\Users\morethan\AppData\Roaming\.flutter_tool_state` 쓰기가 차단된 실행 환경 문제였다. 잔류 Flutter/Dart 프로세스가 없는 것을 확인했고, 권한이 있는 동일 명령으로 관련 Flutter 64개를 다시 통과했다.
- 전체 Flutter는 명시적 파일 shard 4개로 나눠 각각 148/132/92/162개, 합계 534개를 통과했다. 관련 Personal training logs Emulator 38개도 통과했다. 제품/Functions 변경이 없어 전체 Emulator suite와 Functions build는 직전 통과 결과를 유지했다.
- 전체 `flutter analyze --no-pub`는 error 0, warning 246, info 912였다. 기존 lint 때문에 exit 1이지만 신규 compile error는 없다. `git diff --check`, DEV `compileDevDebugKotlin`, merged DEV Manifest, DEV Debug APK 빌드가 통과했다. merged manifest의 package는 `com.example.mtf_app.dev`이고 기존 위젯 receiver 3개를 유지했다.
- Galaxy `R3CX40M6EEM`에는 `com.example.mtf_app.dev`만 `adb install -r`로 데이터 보존 업데이트했다. 라이트·다크 Home, 설정, 알림 설정, 스마트 알람 등급 안내, 위젯 설정, 레슨 등록 bottom sheet, 계약 목록·개인레슨 계약서 작성 화면을 확인했다. 계약서 작성 화면은 다크 외곽 surface와 밝은 문서 surface가 구분됐고 저장은 실행하지 않았다.
- 기존 레슨 편집 시트의 메모 입력칸에서 `mInputShown=true`, `mIsInputViewShown=true`를 확인했다. 키보드가 열린 상태에서 입력 영역과 AIFC 빠른 작업이 읽혔고 RenderFlex/BOTTOM overflow 및 시트 겹침은 없었다. 입력하거나 저장·삭제하지 않고 닫았다.
- DEV tier fixture는 사용자 선택으로 `serverTier=Amateur`, `effectiveTier=Semi-Pro`, `localOnly=true`, `firestoreWrite=false`, `functionsCall=false`를 확인했다. 검증 종료 시 DEV 앱만 force-stop/restart하여 in-memory fixture를 해제했고 서버 실제 tier Amateur를 유지했다.
- Galaxy 미확정: 기존 회원 2건 모두 레슨일지 동의/서명 계약서 선행조건이 없어 레슨일지 목록·작성·세트 입력·서명 상태와 빠른서명 캔버스의 실제 기기 진입을 저장 없이 수행할 수 없었다. 자동 테스트와 정적 테마 적용은 통과했지만 실기기 통과로 기록하지 않는다. 계약서 미리보기 역시 필수 입력 없이 열리지 않아 작성 화면까지만 확인했다.
- 원복·안전: `pref_dark_mode`를 라이트로 복원하고 DEV 재시작 후 라이트 Home을 확인했다. 최종 foreground는 DEV MainActivity다. permission-denied, unhandled/fatal exception, DEV ANR, RenderFlex/BOTTOM overflow, PROD project marker, `trainer_profile/me`는 0건이다. Firebase·PROD package·commit/push 작업은 없었다.
- 증적: `artifacts/brand_theme_phase2_2of3/`의 관련/전체 Flutter shard, analyze, Gradle, APK 로그와 `artifacts/brand_theme_phase2_2of3/galaxy/`의 라이트·다크 화면, 계약서 작성, 기존 레슨 편집, 키보드, 최종 라이트 원복 스크린샷·UI hierarchy.
## 2026-08-06 브랜드 테마 2차 2/3 잔여 실기기 검증 완료

- 검증 범위: Galaxy `R3CX40M6EEM`의 `com.example.mtf_app.dev`에서 레슨일지 본문, 빠른서명 캔버스, 계약서 미리보기만 라이트·다크로 확인했다. 3/3 범위는 시작하지 않았다.
- DEV fixture baseline: 기존 owner-scoped 데이터는 회원 2건, 일정 11건, 레슨일지 0건, 동의 완료 0건, 서버 tier Amateur였다. Personal Rules에서 계약서 전체 count 조회를 허용하지 않아 계약서 count는 미확정으로 남겼고 기존 계약서 문서는 읽거나 수정하지 않았다.
- fixture 생성: 기존 DEV 회원 1건을 읽기 전용으로 재사용하고 prefix 일정 1건과 draft 레슨일지 1건만 생성했다. 생성 중 회원·계약서 delta는 0, 일정은 11→12, 레슨일지는 0→1이었으며 로컬 effective tier만 Semi-Pro로 설정했다.
- 레슨일지 라이트: 목록·카테고리 작성·세트 3개/12회·메모·자동 초안·저장 CTA·서명 상태와 키보드 열림/닫힘을 확인했다. 저장은 실행하지 않았고 overflow·겹침은 없었다.
- 레슨일지 다크 결함 및 수정: `personal_training_log_category_page.dart`가 2/3 토큰 적용 대상에서 누락되어 흰색 하드코딩 surface 위에 다크 기본 글자색이 표시되는 저대비 결함을 재현했다. 해당 페이지의 scaffold, section, set row, divider, chip, footer와 보조 텍스트만 기존 `MtfThemeTokens.trainingLog*` 및 `ColorScheme`에 연결했다. 수정 후 세트 카드·자동 초안·제목 입력·메모·저장 CTA·키보드가 모두 읽히고 겹침이 없음을 재검증했다.
- 빠른서명 라이트·다크: 앱 외곽과 밝은 흰색 캔버스가 명확히 구분됐고 네이비 펜 획, 지우기, 취소, 완료 버튼 가독성을 확인했다. 완료 저장은 실행하지 않았다.
- 계약서 미리보기 라이트·다크: 앱 외곽과 밝은 document surface가 구분됐고 계약 당사자·결제 표·조항·divider·서명란·최종 동의 영역을 스크롤로 확인했다. 다크에서 문서가 네이비로 반전되지 않았고 저장은 실행하지 않았다.
- fixture 원복: prefix 일정과 draft 레슨일지만 삭제해 회원 2건, 일정 11건, 레슨일지 0건, 동의 완료 0건으로 정확히 복원했다(`restoredExactly=true`). 로컬 fixture는 server 상태로 해제했고 정상 DEV 앱 재설치·재시작 후 실제 tier Amateur와 밝은 모드 유지를 확인했다.
- 안전 로그: 최초 임시 harness가 금지된 계약서 전체 count read를 시도해 product flow 이전 `permission-denied` 2건을 만들었다. 즉시 해당 probe를 제거하고 logcat을 비운 뒤 전체 실기기 검증을 다시 수행했으며 최종 clean 구간은 permission-denied, unhandled/fatal exception, DEV ANR, RenderFlex/BOTTOM overflow, PROD project marker, `trainer_profile/me`가 모두 0건이었다.
- 자동 검증: 관련 Flutter 7개 통과, 전체 Flutter shard 148/132/114/140개(합계 534개) 통과, 변경 범위 analyze error 0(기존 info 7·unused warning 1), `git diff --check` 통과, 정상 DEV Debug APK 빌드와 `adb install -r` 데이터 보존 설치가 통과했다.
- 증적: `artifacts/brand_theme_phase2_2of3/galaxy/training_set_card_dark_fixed.png`, `training_keyboard_dark_fixed.png`, `quick_sign_light.png`, `quick_sign_stroke_dark.png`, `quick_sign_clear_dark.png`, `contract_preview_light.png`, `contract_preview_signature_light.png`, `contract_preview_dark.png`, `contract_preview_signature_dark.png`, `fixture_cleanup_complete.png`, `final_normal_dev_light.png` 및 대응 UI hierarchy를 보존했다.
- 보호 범위: PROD package·PROD Firebase·Firebase 배포·`pm clear`·앱 데이터 초기화·git commit/push 작업은 0건이다.
## 2026-08-07 브랜드 테마 2차 3/3 완료

- 테마 계약: `pref_app_theme`의 `light`, `dark`, `lululala`를 단일 source of truth로 추가했다. 신규 설치는 `light`, 기존 `pref_dark_mode=true`는 `dark`, `false`는 기존 화면 보존을 위해 `lululala`로 해석한다. 유효한 신규 키가 있으면 legacy bool보다 우선한다.
- 위젯 동기화: 앱 `light`는 신규 `brandLight`, `dark`는 `dark`, `lululala`는 기존 `light` 위젯 팔레트로 즉시 동기화한다. Galaxy 런타임에서 DEV provider 3종 등록을 확인했고, 실제 배치된 DEV 오늘 레슨·다음 레슨 위젯의 저장 테마가 선택 직후 갱신됐다. 주간 provider는 등록은 확인했으나 현재 런처에 DEV 인스턴스가 없어 실물 렌더링은 미확인으로 구분한다.
- legacy 위젯 테마: 기존 pink/brown/paper 계열 enum과 저장값 read 경로는 유지하고 설정 UI에서는 숨겼다. 앱 설정과 위젯 설정 모두 `라이트`, `다크`, `룰루랄라`만 노출한다.
- 인사이트·통계·차트: 중앙 `MtfChartPalette`를 추가해 series, positive/warning/negative, grid, axis, tooltip 역할을 테마별로 분리했다. 계산식, 기간 범위, Firestore query는 변경하지 않았다. Galaxy 다크에서 KPI, 도넛 차트, 회원 통계의 surface·축·legend 대비와 의미색을 확인했다.
- 목표·D-DAY: 주간 목표와 D-DAY 관리 surface, border, picker/dialog, 진행·완료·경고 의미색을 중앙 theme token에 연결했다. Galaxy 라이트에서 주간 목표 4/40 진행 카드와 일정 상태색을 확인했다. 기존 DEV 데이터에 표시 가능한 D-DAY 항목이 없어 D-DAY 실물 카드는 미확인이고 관련 widget test 통과 근거로만 기록한다.
- Galaxy 3종: `R3CX40M6EEM`의 `com.example.mtf_app.dev`만 `adb install -r`로 데이터 보존 업데이트했다. 라이트는 설정·홈·스케줄러·주간 목표, 다크는 설정·홈·스케줄러·회원관리·등급 안내·인사이트·통계·차트, 룰루랄라는 설정·홈·스케줄러·위젯 설정·알림·등급 안내·레슨 등록·회원 검색 Overlay를 직접 확인했다. 세 테마 모두 재시작 후 선택 유지와 위젯 theme key 동기화를 확인했다.
- 실기기 보정: 다크 회원카드의 `회차 미등록`과 기본 그룹 배지가 라이트 전용 고정 회색을 사용해 대비가 낮은 결함을 발견했다. `MemberListRow._sessionSummaryTextColor`와 그룹 배지 텍스트를 다크에서 `ColorScheme.onSurfaceVariant/onSurface`로 최소 보정했고 Galaxy 재설치 후 가독성 복구를 확인했다.
- 자동 검증: 관련 Flutter 41개 통과, 전체 63개 test file을 4개 shard로 실행해 158/126/100/162, 합계 546개 통과. 전체 analyze는 error 0, warning 242, info 913이며 `git diff --check` 통과. DEV Kotlin compile·merged Manifest·provider 3종은 직전 최종 코드 결과를 유지했고, 보정 후 DEV Debug APK를 다시 빌드해 설치했다. Functions와 emulator 대상 코드는 이번 보정에서 변경하지 않아 직전 전체 Emulator suite와 Functions build 통과 결과를 유지한다.
- 최종 상태: `pref_app_theme=light`, 위젯 `mtf_widget_theme_mode=brandLight`, legacy bool=false로 복원하고 DEV 앱 재시작 후 라이트 유지 확인. 임시 tier fixture key는 남지 않았고 서버/회원/일정 데이터 write는 수행하지 않았다. DEV 프로세스 로그의 permission-denied, unhandled exception, fatal/ANR, RenderFlex/BOTTOM overflow, PROD project marker는 모두 0건이다.
- 보호 범위: PROD package, PROD Firebase, Firebase 배포, `pm clear`, 데이터 초기화, commit/push 작업은 0건이다.
- 증적: `artifacts/brand_theme_phase3_3of3/galaxy/`의 테마별 설정·홈·회원관리·등급 안내·인사이트·차트·위젯 설정·알림·레슨 시트·검색 Overlay·최종 라이트 PNG/XML과 `artifacts/brand_theme_phase3_3of3/flutter_shard_*.log`, analyze 로그를 보존했다.

## 2026-08-07 브랜드 테마 출시 게이트 DEV 실물 검증 중단

- DEV 주간 위젯: Galaxy의 DEV 주간 위젯 인스턴스를 추가해 라이트·다크·룰루랄라 3테마의 실제 일정, 주간 격자, 오늘 강조, 현재 시간 표시와 테마별 색상 대비를 확인했다. DEV provider와 `more-than-fitness-dev-mft` identity만 사용했다.
- D-DAY 저장 실패: DEV 가짜 회원 1건에 MORE Day 제목·날짜를 입력하고 `수정 저장`을 실행했으나 서버 readback 후 값이 사라졌다. `client_card_page.dart`는 `anniversaryDate`와 `anniversaryLabel`을 만들지만 `personal_member_card_save_service.dart`의 수정 계약과 `functions/src/managed_members.ts`의 `updateManagedMember` allowlist/write가 두 필드를 전달·저장하지 않는 것이 원인이다.
- 정리 실패: 검증용 회원을 기존 고객카드의 `회원 삭제`로 정리하려 했으나 `_softDeleteMember()`가 `members/{memberId}`에 직접 write하여 Firestore `permission-denied`가 1건 발생했다. 즉시 중단했으며 검증용 회원 1건이 남아 있다. 실제 UID, memberId, 전화번호는 기록하지 않았다.
- 원복: DEV 로컬 tier fixture를 서버 실제 등급으로 해제하고 앱 테마를 라이트, 위젯 테마를 `brandLight`로 복원했다. 서버 실제 tier는 Beginner로 유지되며 D-DAY 값은 저장되지 않았다. 재시작 후 clean 로그 구간의 permission-denied·fatal crash·ANR·overflow·PROD marker는 0건이다.
- 출시 게이트 판정: DEV 단계 실패와 permission-denied 즉시 중단 조건에 따라 release freeze 감사, PROD 버전·서명 빌드, PROD 데이터 보존 업데이트는 실행하지 않았다.
- 보호 범위: PROD package·PROD Firebase·Firebase 배포·uninstall·`pm clear`·commit·push 작업은 0건이다.
- 증적: `artifacts/brand_theme_release_gate/dev_widget/weekly_light.png`, `weekly_dark.png`, `weekly_lululala.png`, 각 theme prefs/UI hierarchy와 `dev_final_light.png`를 보존했다.

## 2026-08-08 고객카드 저장·삭제 및 다음 주 목표 blocker 수정 — DEV 배포 대기

- 회원권 원인: Personal 기존 회원 수정은 `client_card_page.dart`의 UI에서 `membership.notRegistered`, `termMonths`, `customDays`, `startAt`, `endAt`, `days`, `lastRegisteredAt`, `reregisterCount`, `lastReregisterAt`을 계산·복원하지만, `PersonalMemberCardSaveService.updateAndVerify()`가 이 값을 하나도 callable에 전달하지 않았다. 따라서 120일·직접 날짜·월 프리셋은 화면 state만 정상이고 canonical 문서는 갱신되지 않았다.
- D-DAY 비교: `anniversaryDate`·`anniversaryLabel`도 같은 축약 update request에서 누락됐다. 수정 전 `updateManagedMember`에는 이 필드들이 도달하지 않았으므로 다른 unsupported field가 전체 callable을 거절한 구조가 아니라, 클라이언트 호출 경계에서 회원권과 D-DAY가 함께 유실된 구조였다.
- 저장 계약 수정: Personal update request에 canonical `membership` map과 nullable `anniversaryDate`·`anniversaryLabel`을 추가하고, `updateManagedMember` nested allowlist·날짜/기간 검증·dot-path write를 일치시켰다. dot-path update로 기존 pause·contract/history 하위 필드는 보존한다. 서버 readback과 snapshot 확인도 회원권·D-DAY까지 확장했다.
- 날짜 입력: 공통 date picker가 전달받은 `first`/`last`를 무시하던 문제를 수정하고 회원권 시작·종료일에는 미래 종료일까지 선택 가능한 범위를 명시했다. 시작/종료 inclusive day 계산은 기존 `difference + 1` 계약을 유지한다.
- 목표 assertion 재현: Galaxy DEV에서 주간 목표 저장 직후 다른 화면으로 이동해 `A TextEditingController was used after being disposed`를 재현했다. 첫 product-code frame은 수정 전 `TextField`인 `lib/pages/home_page.dart:851:18`이며, 이어 Flutter framework `'_dependents.isEmpty': is not true`가 2차 assertion으로 발생했다. 증적은 `artifacts/blockers_20260808/goal_assertion_repro.png`, `flutter_run_repro.log`다.
- 목표 수정: `showDialog` future 완료 직후 외부 controller를 dispose하던 흐름을 제거하고 `HomeWeeklyGoalDialog`가 입력값을 자체 소유하도록 분리했다. system/light/dark에서 저장·취소·재열기 회귀를 통과했다.
- 삭제 구조: Personal `_softDeleteMember()`의 직접 Firestore write를 기존 owner-scoped `transitionManagedMemberState` callable과 서버 readback으로 교체했다. 서버 state transition이 `deleted`일 때 `isDeleted`, `deletedAt`, `deleteScheduledAt`, `deleteStatus=pending_delete`, `deletedSource`를 canonical하게 기록하고 다른 owner를 차단한다. legacy non-Personal 직접 경로는 범위 밖이라 유지했다.
- 자동 검증: 관련 Flutter 45개 통과, 전체 Flutter 4개 shard 147/145/132/129개(합계 553개) 통과, managed member Emulator 59개 통과, Functions TypeScript build·ESLint 통과, 신규/작은 Dart 범위 analyze 진단 0, 변경 대형 파일 포함 analyze error 0(기존 warning/info로 exit 1), `git diff --check` 통과, DEV Debug APK 빌드 통과.
- 배포 중단: 서버 계약 변경으로 DEV 실기기 readback 검증 전 `updateManagedMember`와 `transitionManagedMemberState` 선택 배포가 필요하다. 승인 전 Firebase deploy는 실행하지 않았으며 Galaxy 재설치·후속 저장·남은 가짜 회원 삭제도 실행하지 않았다.
- 제안 명령: `firebase deploy --project more-than-fitness-dev-mft --only "functions:updateManagedMember,functions:transitionManagedMemberState"`.
- 보호 범위: PROD package·PROD Firebase·PROD build/install, Rules·indexes·Storage, commit/push 작업은 0건이다. release freeze는 유지한다.
## 2026-08-08 DEV managed member 선택 배포 및 Galaxy 실기기 blocker 검증 완료

- 선택 배포: `firebase deploy --project more-than-fitness-dev-mft --only "functions:updateManagedMember,functions:transitionManagedMemberState"`를 1회만 실행했다. CLI는 Artifact Registry cleanup policy 경고 때문에 exit code 1이었지만 두 함수의 배포 성공 문구와 함수 목록을 별도 확인했고, `asia-northeast3`의 `updateManagedMember`, `transitionManagedMemberState`가 모두 `ACTIVE`였다. cleanup policy는 변경하지 않았고 다른 함수·Rules·indexes·Storage·Hosting은 배포하지 않았다.
- 시작 baseline: 실제 DEV readback은 요청의 예상값과 달리 서버 tier `Amateur`, owner-scoped 회원 3건, 일정 12건, 레슨일지 0건, 검증용 회원 1건이었다. 로컬 tier fixture는 없었고 앱 테마는 `light`, 위젯 테마는 `brandLight`, 주간 목표는 50이었다. 실제 readback을 기준 상태로 사용했다.
- 회원권 120일: 검증용 회원에서 직접입력 120일을 저장한 뒤 서버 readback에서 `notRegistered=false`, `termMonths=null`, `customDays=120`, `startAt=2026-08-08`, `endAt=2026-12-05`, `days=120`, `lastRegisteredAt=2026-08-08`, `reregisterCount=0`, `lastReregisterAt=null`을 확인했다. 카드 재진입에서도 같은 기간과 날짜가 유지됐다.
- 회원권 직접 날짜: 시작일 2026-08-10, 종료일 2026-12-20을 직접 선택해 저장했고 서버 readback에서 `customDays=133`, `days=133`과 두 날짜가 일치했다. 재시작 후에도 유지됐으며 기존 membership 하위 pause/contract/history 성격의 부가 필드는 저장 전후 모두 빈 map으로 동일해 덮어쓰기가 없었다.
- D-DAY 저장: DEV 로컬 Semi-Pro fixture만 적용해 `anniversaryDate=2026-08-08`, `anniversaryLabel=DEVDDAY`를 `updateManagedMember` 1회로 저장했다. 서버 readback, 고객카드 재진입, DEV 앱 force-stop/restart 후 재진입에서 모두 유지됐고 light/dark/lululala 테마에서 카드 표시를 확인했다. 서버 tier write와 Functions 호출을 통한 fixture 변경은 없었다.
- D-DAY 제거 UI 보완: 서비스와 Functions는 nullable 제거 계약을 지원했지만 실제 D-DAY 입력 UI에는 날짜를 지우는 동작이 없었다. `ClientCardPage._tapDateField`의 기존 optional clear 경로를 사용해 D-DAY에만 `client_card_anniversary_clear`/`날짜 지우기` suffix를 추가했다. 제거 저장은 `updateManagedMember` 1회였고 서버 readback에서 `anniversaryDate=null`, `anniversaryLabel=null`, 카드 재진입에서도 기본 `기념일` 상태를 확인했다.
- 목표 Dialog: dark, lululala, light에서 열기, 입력, 키보드, 취소, 재열기, 저장, 뒤로가기, 빠른 open/close 반복을 수행했다. `_dependents.isEmpty`, disposed controller/context, duplicate GlobalKey, red screen, overflow는 0건이었다. 검증 후 주간 목표를 원래 값 50으로 복원했다.
- 외부 로그 분류: 목표 검증 구간의 전역 logcat에 `communityPosts` `PERMISSION_DENIED` 2건이 있었지만 PID 7152의 별도 앱 `com.morethanwellness.app` 로그였고 DEV 앱 PID는 27230이었다. DEV PID 범위에서는 permission-denied 0건이었으며 이 별도 앱은 실행하거나 조작하지 않았다.
- canonical 삭제: 고객카드의 회원 삭제 UI에서 `transitionManagedMemberState` callable이 정확히 1회 호출됐다. 서버 readback은 `managementState=deleted`, `isDeleted=true`, `deleteStatus=pending_delete`였고 회원목록에서 즉시 제거됐다. `managedMemberCount`는 3에서 2로 복원됐고 raw 회원 문서는 7일 보관 정책에 따라 3건, 일정은 검증용 연결 일정 정리 후 11건, 레슨일지는 0건이었다. 다른 기존 owner-scoped 데이터는 수정하지 않았다.
- 최종 원복: 서버 실제 tier는 시작값과 동일한 `Amateur`로 유지됐다. 로컬 fixture는 `서버 실제 등급`으로 명시 복원 후 DEV 앱을 재시작했고, 앱 테마 `light`, 위젯 테마 `brandLight`, 주간 목표 50을 확인했다.
- 자동 검증: 관련 Flutter 7개 통과, 전체 Flutter 4개 shard 합계 553개 통과, managed member Emulator 59개 통과, Functions TypeScript build와 ESLint 통과, analyze error 0(기존 warning/info 존재), `git diff --check` 통과, DEV Debug APK 빌드와 `adb install -r` 데이터 보존 업데이트 설치가 통과했다.
- 최종 clean DEV PID 로그: permission-denied 0, unhandled exception 0, fatal crash/ANR 0, RenderFlex/BOTTOM overflow 0, PROD project marker 0이었다.
- 보호 범위: PROD Firebase·PROD package·PROD build/install, 다른 Firebase 리소스 배포, uninstall, `pm clear`, commit, push는 수행하지 않았다.
- 증적: `artifacts/blockers_20260808/deploy_dev_selected_functions.txt`, `functions_list_after.json`, `post_ui_fix/`의 Flutter shard·Emulator·APK 로그를 보존했다.

## 2026-08-08 PROD 1.0.4 데이터 보존 업데이트 완료

- 사전 확인: Galaxy `R3CX40M6EEM`에 설치된 PROD `com.example.mtf_app`은 `1.0.3 (4)`였고, 설치 APK와 로컬 release signing에 사용되는 Android Debug 인증서의 SHA-256이 일치했다. package UID, dataDir, firstInstallTime을 설치 전 기준값으로 보존했다.
- 버전 변경: `pubspec.yaml`만 `1.0.3+4`에서 `1.0.4+5`로 올렸다. 로컬 이력에서 versionCode 5 사용 충돌은 없었으며 Play Console 상태는 조회하지 않았으므로 5는 이번 로컬/기기 업데이트 기준이다.
- 자동 검증: 관련 Flutter 36개 통과, 전체 Flutter 4개 shard 139/140/130/144개(합계 553개) 통과, managed member Emulator 59개 통과, DEV Debug/PROD Release Kotlin compile 통과, `git diff --check` 통과였다. 전체 analyze는 error 0, 기존 warning 240·info 913으로 exit 1이었다.
- PROD 빌드: `flutter build apk --flavor prod -t lib/main_prod.dart --release --no-pub`가 통과했다. 산출물은 `build/app/outputs/flutter-apk/app-prod-release.apk`, package `com.example.mtf_app`, version `1.0.4 (5)`, label `모어댄`, target API 36, non-debuggable이며 PROD Firebase projectId `more-than-fitness-f6adb`를 사용한다. DEV project/package/label marker는 검출되지 않았다.
- 서명: 새 APK의 인증서 주체와 SHA-256은 설치된 1.0.3 APK와 동일한 Android Debug 인증서였다. 따라서 이번 업데이트는 서명 연속성을 유지했지만 Play 정식 release signing 전환은 별도 과제로 남는다.
- 데이터 보존 설치: `adb -s R3CX40M6EEM install -r C:\src\mtf_app\build\app\outputs\flutter-apk\app-prod-release.apk`가 `Success`였다. 설치 후 PROD는 `1.0.4 (5)`이고 package UID, dataDir, firstInstallTime이 설치 전과 동일했으며 lastUpdateTime만 갱신됐다. uninstall과 `pm clear`는 실행하지 않았다.
- 읽기 전용 스모크: PROD MainActivity를 명시 실행해 기존 세션으로 Home에 직접 진입했다. 기존 주간 일정과 고객리스트 1명 표시, 고객카드 재진입, 회원권/레슨 영역, Drawer, 설정, 위젯 설정, 알림 설정, 신규 레슨 등록 시트 진입을 확인했다. 저장·수정·삭제·알림 토글·위젯 조작은 실행하지 않았다.
- 테마 스모크: 설정에서 dark, lululala, light를 순서대로 렌더링 확인했고 최종 light로 복원했다. 각 설정 화면에서 선택 상태와 텍스트 가독성, overflow 부재를 확인했다. 증적은 `artifacts/prod_104_update_20260808/settings_dark.png`, `settings_lululala.png`, `settings_light_final.png`다.
- 위젯/DEV 보존: `dumpsys appwidget`에서 PROD 주간·다음 레슨·오늘 레슨 provider 3개를 확인했고 기존 PROD 위젯은 탭·이동·삭제하지 않았다. DEV package `com.example.mtf_app.dev`도 `1.0.3-dev (4)`로 그대로 존재했다.
- 최종 안전 로그: 사용자 0/보안 폴더 측 PROD 프로세스 PID를 각각 검사했고 permission-denied, unhandled exception, fatal crash, ANR, RenderFlex/BOTTOM overflow, DEV project/package marker가 모두 0건이었다. 최종 top resumed activity는 PROD MainActivity였다.
- 보호 범위: PROD Firebase 배포, Rules·indexes·Storage·Hosting·Functions 배포, Play 업로드, commit, push는 0건이다. 기존 개인 식별값은 문서에 기록하지 않았다.

## 2026-08-08 1.0.4 이후 잔여 고정 색상·부분 UI 테마 정리 완료

- 중앙 토큰: `MtfThemeTokens`에 후원 카드, AIFC 대화, 스케줄러 외곽·경계·모서리 역할을 추가하고 light/dark/lululala 값을 분리했다. 일반 CTA는 `ColorScheme.secondary/onSecondary`, 공통 헤더는 `mtfHeaderGradient`, FC 전용 아바타·말풍선은 기존 퍼플 정체성을 유지한다.
- 헤더·CTA: 고객리스트, 레슨일지 목록·카테고리, 마이페이지, 계약서·동의 화면 헤더를 공통 브랜드 경계에 연결했다. 계약서·상담·레슨일지·동의의 주요 CTA는 웜 옐로우/네이비 조합으로 정리하되 성공·경고·오류 의미색과 기능·게이트·데이터 흐름은 변경하지 않았다.
- 시트·AIFC·후원: 레슨일지 작성 방식 시트와 빠른등록·상담 AIFC 시트의 surface/input/bubble/loading을 테마 토큰으로 교체했다. Home·Drawer 후원 카드는 같은 후원 토큰을 사용한다. 시트 높이, 키보드 inset, 반환값, 레이아웃은 변경하지 않았다.
- 스케줄러: 주간표 외곽 surface·border·corner를 중앙 토큰에 연결했다. 날짜 헤더·오늘 열·격자와 기존 레슨 상태색, 터치 범위, 10분 단위 동작은 유지했다.
- 실기기 발견 보정: Galaxy 다크 모드에서 DEV 등급 fixture popup이 고정 흰색 surface와 상속 텍스트 때문에 저대비로 보이는 결함을 `app_environment_banner.dart`에서 theme surface/onSurface/secondary로 최소 수정했다. Galaxy 라이트 마이페이지의 하단 `저장하기`가 고정 인디고였던 결함도 `ColorScheme.secondary/onSecondary`로 교체했다.
- 자동 검증: 관련 Flutter 38개를 통과했고 실기기 보정 후 관련 회귀 21개를 다시 통과했다. 전체 65개 test file을 4개 shard로 실행해 143/140/130/150개, 합계 563개를 통과했다. 전체 analyze는 error 0, 기존 warning 235·info 914였고 `git diff --check`와 DEV Debug APK 빌드가 통과했다. Firebase/data 코드 변경이 없어 Emulator suite와 Functions 검증은 실행하지 않았다.
- Galaxy DEV 3테마: `R3CX40M6EEM`의 `com.example.mtf_app.dev`만 `adb install -r`로 데이터 보존 업데이트했다. light/dark/lululala에서 Home, 스케줄러, 고객리스트, 레슨일지, 등급 안내, 빠른등록, 계약서, 마이페이지, 인사이트, AIFC 상담, 설정과 후원 surface를 확인했다. 다크 키보드 구간에서도 겹침·overflow가 없었고 AIFC 퍼플과 브랜드 옐로우의 역할이 분리됐다.
- 실기기 확인 한계: 레슨일지 작성 방식 시트는 draft fixture가 없어 실제 화면을 열지 못했고, 동의 화면은 기존 회원 선행상태 때문에 저장 없이 진입하지 못했다. 두 항목은 정적 경로와 widget test 근거로만 통과했으며 실기기 확인으로 기록하지 않는다. AIFC 사용자 말풍선도 데이터 전송 없이 widget test로 확인했다.
- 최종 상태: DEV fixture는 `서버 실제 등급`으로 해제됐고 서버 actual tier `Amateur`, 앱 테마 `light`를 확인했다. DEV force-stop/restart 후 라이트 유지와 DEV MainActivity foreground를 확인했다. 최종 clean 로그의 permission-denied, unhandled/fatal exception, 실제 ANR, RenderFlex/BOTTOM overflow, PROD project marker는 0건이다. 단순 `LOWIScanResultReceiver` 문자열 4건은 대소문자 없는 `ANR` 부분문자열 오탐으로 분류했다.
- 보호 범위: 기존 DEV 데이터는 저장·수정·삭제하지 않았다. PROD package·PROD Firebase·Firebase 배포·uninstall·`pm clear`·commit/push 작업은 0건이다.
- 증적: `artifacts/theme_residual_cleanup_20260808/`의 Flutter shard·전체 analyze 로그와 `artifacts/theme_residual_cleanup_20260808/galaxy/`의 테마별 PNG/XML, `mypage_light_fixed.png`, `fixture_final.png`, `light_restart_final.png`, `final_clean_logcat.txt`를 보존했다.

## 2026-08-08 잔여 테마 3화면 Galaxy DEV 실기기 검증 완료

- 검증 범위: Galaxy `R3CX40M6EEM`의 `com.example.mtf_app.dev`만 사용했다. 기존 owner-scoped DEV 회원 2건을 읽기 전용으로 재사용하고, 로컬 Semi-Pro fixture와 저장하지 않은 레슨일지 draft만 사용했다. 신규 회원·일정·레슨일지·동의 서버 write는 0건이다.
- 레슨일지 작성 방식 선택 시트: light/dark/lululala에서 sheet background, drag handle, 제목·설명, 옵션 카드, 선택·잠금 상태, 아이콘, border, 닫기 동작을 확인했다. 키보드·시트 높이 이상과 overflow는 0건이었고 실제 레슨일지는 저장하지 않았다.
- 동의 화면 실기기 보정: 다크에서 법적 안내 문구가 고정 `Colors.black54`라 저대비였고, light/lululala에서는 투명 AppBar의 흰 제목·뒤로가기 아이콘이 밝은 배경과 겹쳤다. `training_log_consent_page.dart`에서 안내 문구를 `ColorScheme.onSurfaceVariant`에 연결하고 AppBar fallback을 공통 헤더 gradient 첫 색, 흰 foreground, light system overlay로 최소 수정했다. schema·callable·동의 저장 흐름은 변경하지 않았다.
- 동의 화면 결과: 보정 후 light/dark/lululala에서 header, body surface, 동의 문구, checkbox, CTA, 취소·뒤로가기와 전체 가독성을 확인했다. 실제 동의 제출은 실행하지 않았고 기존 두 회원의 consent 상태는 검증 전후 동일했다.
- AIFC 사용자 말풍선: Anatomy AIFC의 로컬 응답 경로에서 테스트 문장 1건을 입력했다. 세 테마에서 사용자 bubble 대비, AI bubble 구분, FC 퍼플 avatar, 입력창, typing/loading, 긴 문장 wrap, padding/radius, 키보드와 overflow 0을 확인했다. 메시지는 Firestore에 저장되지 않았다.
- 자동 검증: 관련 Flutter 10개, 전체 Flutter 4개 shard 150/147/135/131개(합계 563개)를 통과했다. 변경 범위 analyze는 error 0(기존 info 18), `git diff --check`와 DEV Debug APK 빌드가 통과했고 `adb install -r` 데이터 보존 업데이트 설치도 성공했다.
- 최종 원복·readback: DEV 서버 actual tier `Amateur`, active member 2, schedules 11, trainingLogs 0과 두 회원의 기존 consent 상태가 시작값과 동일했다. 로컬 tier fixture와 미저장 draft는 DEV 재시작으로 제거했고 앱 테마 `light`, 위젯 테마 `brandLight`를 확인했다.
- 최종 안전 로그: DEV 앱 PID 기준 permission-denied, unhandled exception, fatal crash, 실제 ANR, RenderFlex/BOTTOM overflow가 모두 0건이었고 PROD project marker도 0건이었다.
- 보호 범위: PROD package·PROD Firebase·Firebase 배포·uninstall·`pm clear`·commit·push 작업은 0건이다.
- 증적: `artifacts/theme_residual_cleanup_20260808/galaxy/tail/entry_method_*`, `consent_*_fixed.png`, `aifc_*_user_bubble.png`, `aifc_*_reply.png`, `final_light_home.png`, `final_safety_summary.txt`를 보존했다.

## 2026-08-09 PROD 1.0.4 (6) 데이터 보존 업데이트 완료

- release freeze 감사: `git status --short`, `git diff --stat`, `git diff --check`와 release source import 경계를 확인했다. 제품 경로에서 docs/artifacts/test helper import는 0건이었고 DEV tier fixture와 viewport selector는 `kDebugMode && AppEnvironmentConfig.isDev`로 비활성화된다. PROD entrypoint는 `lib/main_prod.dart`, package는 `com.example.mtf_app`, Firebase projectId는 `more-than-fitness-f6adb`이며 versionCode 6의 기존 사용 이력은 없었다.
- 버전 변경: `pubspec.yaml`의 version만 `1.0.4+5`에서 `1.0.4+6`으로 변경했다. signingConfig, keystore, Android flavor, Firebase 설정과 다른 release 설정은 수정하지 않았다.
- 자동 검증: 관련 Flutter 51개 통과, 전체 Flutter 4개 shard 150/147/135/131개(합계 563개) 통과, Functions TypeScript build 통과, managed member Emulator 59개 통과였다. 전체 analyze는 error 0, 기존 warning 235·info 928이고 `git diff --check`가 통과했다.
- PROD APK: `flutter build apk --flavor prod -t lib/main_prod.dart --release --no-pub`가 통과했다. 산출물 `build/app/outputs/flutter-apk/app-prod-release.apk`는 package `com.example.mtf_app`, versionName `1.0.4`, versionCode `6`, label `모어댄`, target API 36, non-debuggable이며 APK resource에는 PROD projectId `more-than-fitness-f6adb`만 확인됐다.
- 서명 비교: 설치된 1.0.4 (5) APK와 새 1.0.4 (6) APK의 signer는 모두 `C=US, O=Android, CN=Android Debug`, SHA-256 `a922c098c2dc3d7052895e8ad836b95cf08b9e12f39acd9e6df9d189abb74489`로 정확히 일치했다. 새 keystore 생성과 Play signing 전환은 수행하지 않았다.
- 데이터 보존 설치: `adb -s R3CX40M6EEM install -r C:\src\mtf_app\build\app\outputs\flutter-apk\app-prod-release.apk`가 `Success`였다. 설치 후 version은 `1.0.4 (6)`이고 user 0 package UID `10500`, dataDir `/data/user/0/com.example.mtf_app`, firstInstallTime `2025-11-18 17:47:53`이 설치 전과 동일했다. DEV package `com.example.mtf_app.dev`도 `1.0.4-dev (5)`로 유지됐다.
- read-only smoke: 설치 직후 기존 익명 session으로 Home에 진입했고 기존 회원목록 1명과 기존 주간 일정 표시를 확인했다. 고객리스트·고객카드, Drawer, MyPage, 설정, 신규 빠른등록 시트, 기존 레슨 편집 시트, 알림 설정, 위젯 설정, 후원 카드와 스케줄러 외곽·경계를 열어 확인했다. 입력·저장·수정·삭제·토글·계약·서명·동의 동작은 실행하지 않았다.
- gate 확인: 현재 PROD 실제 tier가 `Amateur`라 레슨계약서, 레슨일지, AIFC 상담 체크리스트는 각각 중앙 Semi-Pro/Pro 안내 시트가 표시되고 실제 작성 화면에는 진입하지 않았다. 이는 현재 등급 정책과 일치하며 등급·서버 데이터를 변경하지 않았다.
- 테마 smoke: 설정에서 light → dark → lululala → light 순서로 렌더링을 확인했다. 세 테마의 header, surface, text, 선택 표시가 정상이고 최종 앱 테마와 위젯 설정은 light/brandLight로 복원했다.
- 위젯 보존: `dumpsys appwidget`에서 PROD 주간·다음 레슨·오늘 레슨 provider 3개와 PROD bound widget record 5개를 확인했다. 기존 위젯을 탭·이동·삭제하거나 preference를 직접 변경하지 않았다.
- 최종 안전 로그: 사용자 0과 보안 폴더의 PROD PID를 분리해 검사했고 permission-denied, unhandled exception, fatal crash, 실제 ANR, RenderFlex/BOTTOM overflow, DEV project/package marker는 모두 0건이었다. 최종 top resumed activity는 `com.example.mtf_app/.MainActivity`이고 light Home이었다.
- 보호 범위: uninstall, `pm clear`, Firebase Functions·Rules·indexes·Storage·Hosting 배포, Play Console upload, commit, push는 모두 0건이다. PROD Firebase를 직접 조회·수정하지 않았다.
- 증적: `artifacts/prod_104_6_update_20260809/`에 Flutter shard·analyze 로그, 설치 전후 package dump, signer 비교, APK identity와 `smoke/` 화면·hierarchy·PID logcat을 보존했다.

## 2026-08-09 PROD 회원권·기본 그룹 blocker 조사 및 DEV 검증

- PROD 회원권 원인: 현재 앱의 `updateManagedMember` 요청은 `membership.notRegistered`, `termMonths`, `customDays`, `startAt`, `endAt`, `days`, `lastRegisteredAt`, `reregisterCount`, `lastReregisterAt`과 `anniversaryDate`, `anniversaryLabel`을 함께 보낸다. 반면 PROD에 배포된 `updateManagedMember`의 source hash는 DEV 검증본과 달랐고, 해당 배포 세대의 allowlist에는 membership·anniversary 필드가 없다. `allowOnly`가 요청 전체를 `invalid-argument / unknown_fields`로 거부하는 계약 불일치가 저장 실패 원인이다. PROD Functions 로그에는 재현 구간 항목이 남아 있지 않아 실제 런타임 메시지를 성공으로 추정하지 않았으며, PROD 쓰기를 재시도하지 않았다.
- 기간 입력 수정: `normalizePersonalMembershipDaysInput`을 공통 save service에 추가해 `120`, `120일`, `120 day`, `120 days`, `120day`, `120days`와 대소문자·앞뒤 공백을 양의 정수 일수로 정규화했다. `0`, 음수, `abc`, `12개월`은 거부한다. `client_card_page.dart`의 직접입력 AIFC 흐름은 이 helper만 사용하며 신규 schema나 직접 Firestore write를 추가하지 않았다.
- 기본 그룹 원인·수정: canonical 경로는 `trainer_profiles/{uid}.memberDefaultGroupLabel`과 `updatePersonalTrainerProfile`이다. `AifcChatSheet._submit()`이 저장 실패 후에도 값을 반환해 호출 화면이 로컬 성공 UI를 표시하던 오류를 수정했다. 실패 시 시트를 유지하고 입력·포커스를 복원하며, 실제 저장 성공 후에만 pop한다. Personal의 “그룹 추가” 부재는 회귀가 아니라 `member_groups`, `groupId`, `groupName`을 금지하고 `__ungrouped__` 표시명만 바꾸는 현재 정책이다. 별도 Personal custom group은 schema·UX 승인이 필요한 차기 기능으로 분류했다.
- callable 진단: `PersonalMemberCardSaveService.updateAndVerify()`가 DEV debug에서 `FirebaseFunctionsException`의 `code`·`message`·`details`를 한 줄 marker로 남기고 다시 throw하도록 보강했다. 사용자 UI는 기존 일반 오류 문구만 유지한다. Emulator의 구버전 allowlist 재현은 `INVALID_ARGUMENT` / `unknown_fields` / details 없음으로 고정 검증했다.
- 자동 검증: 최신 관련 Flutter 17개와 기존 관련 묶음을 통과했고, 전체 Flutter 4-shard 합계 566개, managed member Emulator 59개, Functions ESLint·TypeScript build를 통과했다. 변경 범위 analyze는 error 0이고 기존 warning/info 258건만 남았다. `git diff --check`와 DEV Debug APK 빌드가 통과했다.
- Galaxy DEV 기간 검증: `R3CX40M6EEM`의 `com.example.mtf_app.dev`만 `adb install -r`로 데이터 보존 업데이트했다. 최신 빌드에서 별도 가짜 회원 1건으로 `120`과 `120days`를 각각 입력했고 둘 다 즉시 120일, 시작일 포함 종료일 119일 후로 계산됐다. 각 저장 후 canonical readback은 `customDays=120`, `days=120`, 시작일·종료일과 나머지 membership 필드가 일치했다. `120일`은 동일 parser의 Flutter 회귀 테스트로 통과했지만 ADB shell의 Unicode 입력이 Android 16에서 NPE로 거부되어 이번 추가 실기기 입력은 미확정으로 구분한다. 앞선 같은 코드의 시작일·종료일 직접 선택 실기기 경로는 재시작 후 `customDays=366`, `days=366`과 두 날짜가 일치했다. 기존 pause/contract/history 보조 필드는 새로 만들거나 덮어쓰지 않았다.
- Galaxy DEV 그룹 검증: 기본 그룹명을 `MORE THAN GYM`에서 테스트값으로 변경해 목록 필터·회원 카드에 즉시 반영됨을 확인하고, 서버 readback과 앱 재시작 후 유지도 확인했다. 이후 UI canonical 경로로 `MORE THAN GYM`을 복원하고 서버 readback까지 일치했다. 메뉴에는 “기본 그룹 이름 변경”만 있으며 Personal “그룹 추가”는 노출되지 않는다.
- 정리·baseline: 생성한 회원은 `transitionManagedMemberState` canonical 경로로 pending-delete 처리했다. managed active count는 3에서 기존 2로 복원됐다. 원문 members count 5와 testMembers 3은 기존 7일 복구 보존 정책 때문에 이번·이전 pending-delete 문서가 남는 정상 상태이며 직접 삭제하지 않았다. schedules 11, trainingLogs 0, server tier `Amateur`, 그룹명 `MORE THAN GYM`, 앱 `light`, 위젯 `brandLight`를 확인했다.
- 최종 안전 로그: clean DEV restart 구간의 permission-denied, unhandled exception, fatal crash, 실제 ANR, RenderFlex/BOTTOM overflow, PROD project marker는 모두 0건이고 top resumed activity는 DEV MainActivity였다. PROD package·PROD 데이터·Firebase 배포·Rules·indexes·Storage·Hosting·uninstall·`pm clear`·commit·push 작업은 0건이다.
- PROD 배포 전 중단: 확정 필요 함수는 `updateManagedMember`이며 제안 명령은 `firebase deploy --project more-than-fitness-f6adb --only "functions:updateManagedMember"`이다. 실행하지 않았다. PROD `updatePersonalTrainerProfile`은 DEV와 source hash가 다르지만 실제 계약 내용을 내려받지 못했고 PROD 쓰기도 재시도하지 않았으므로 배포 필요 여부는 미확정이다. 그룹 blocker의 앱 측 false-success 수정은 다음 PROD 앱 업데이트가 필요하다.
- 증적: `artifacts/prod_blocker_audit_20260809/`와 `artifacts/prod_member_save_blocker_20260809/`에 관련·전체 Flutter, Emulator, Functions, analyze, diff, DEV APK 로그와 Galaxy DEV UI hierarchy·screenshot을 보존했다.

## 2026-08-09 PROD updateManagedMember 선택 배포 및 설치 앱 parser blocker 분리

- 배포 전 확인: Functions ESLint와 TypeScript build가 통과했고 `functions/src/index.ts`의 export가 정확히 `updateManagedMember`, region이 `asia-northeast3`임을 확인했다. DEV에서 검증한 `functions/src/managed_members.ts`의 membership·D-DAY allowlist와 dot-path write 코드 그대로이며 Rules·indexes·Storage·Hosting 변경은 포함하지 않았다.
- 선택 배포: `firebase deploy --project more-than-fitness-f6adb --only "functions:updateManagedMember"`를 1회 실행했고 exit code 0, `updateManagedMember(asia-northeast3)` successful update를 확인했다. 함수 목록 readback은 `ACTIVE`, GCF v1, Node.js 22, source hash `f33248882c658a19f1caa599964e0b4bdd390d88`이었다. 다른 함수와 `transitionManagedMemberState`는 배포하지 않았다.
- PROD 숫자 120 검증: Galaxy 사용자 0의 `com.example.mtf_app` 1.0.4(6)에서 기존 활성 회원 1건만 사용했다. 원래 상태가 기간 미등록임을 먼저 확인한 뒤 `120` 입력은 기간 120일, 총 120일, 시작일 포함 종료일 119일 후로 계산됐고 수정 저장에 성공했다. 앱의 update service server readback을 통과했으며 카드 종료·재진입에서도 120일과 두 날짜가 유지됐다. `unknown_fields`, `INVALID_ARGUMENT`, permission-denied는 0건이었다.
- 설치 앱 parser blocker: 같은 설치본에서 `120days`는 직접입력 결과가 적용되지 않고 직전 1개월 로컬 선택 상태에 머물렀다. 사용자가 Galaxy 키보드로 `120일`을 입력해 전송했을 때도 저장 실패 안내 후 AIFC 시트가 닫혔다. 이는 배포된 Function 문제가 아니라 현재 설치 PROD 바이너리가 이번 작업의 `normalizePersonalMembershipDaysInput`과 실패 시 입력·포커스 복원 코드를 포함하지 않은 앱 소스/바이너리 불일치다.
- 재시도 UX 고정: 현재 소스의 `AifcChatSheet._submit()`은 `onSave` 예외 시 결과를 pop하지 않고 `_answered=false`, 기존 입력값, focus를 복원한다. 회귀 테스트를 보강해 실패 후 5초가 지나도 시트가 유지되고 명시적 `나중에`에서만 닫히는 것을 확인했다. Galaxy DEV 최신 앱에서는 잘못된 입력 후 7초에도 오류 말풍선, 입력값, `focused=true`가 유지됐고 `나중에` 탭으로만 닫혔다. 서버 write는 발생하지 않았다.
- 자동 검증: AIFC 실패 흐름 2개, 회원 persistence 10개, 전체 Flutter 567개가 통과했다. 변경 범위 analyze는 error 0, 기존 warning/info 합계 258건이며 `git diff --check`가 통과했다. 제품 코드는 추가 변경하지 않고 회귀 테스트만 보강했다.
- PROD 원복: 검증 회원은 원래 `기간 미등록`과 기존 마지막 등록일 상태로 다시 저장했고 카드 재진입에서 `기간 미등록`을 확인했다. D-DAY는 PROD에서 새 값 write를 하지 않았다. pause/contract/history는 Function의 membership dot-path 갱신으로 보존되며 별도 rewrite를 하지 않았다.
- 안전 범위: PROD 사용자 0 PID 기준 permission-denied, `INVALID_ARGUMENT`, `unknown_fields`, unhandled exception, fatal crash, ANR, overflow, DEV Firebase marker는 0건이었다. Rules·indexes·Storage·Hosting, 다른 Function, PROD APK build/install, uninstall, `pm clear`, commit, push는 실행하지 않았다.
- 판정: 서버 `updateManagedMember` 계약 blocker는 해소됐지만 현재 설치 PROD 앱의 기간 parser·실패 시트 UX blocker가 남아 있어 전체 “PROD 회원 저장 blocker 해소”로는 기록하지 않는다. 현재 소스가 포함된 PROD 데이터 보존 앱 업데이트 승인 후 `120일`·`120days` 저장/readback을 재검증해야 한다.
- 증적: `artifacts/prod_update_managed_member_deploy_20260809/`에 배포 출력·함수 목록·자동 테스트·analyze와 PROD/DEV UI hierarchy를 보존했다.
## 2026-08-10 PROD 회원권 입력/저장 blocker 재오픈

- 판정 정정: 직전 “완전 해소” 판정은 취소한다. 장애 원인은 확정했지만 새 실패 안내·단계 진단 코드가 아직 PROD 앱에 반영되지 않았으므로 blocker는 앱 업데이트 검증 전까지 열린 상태다.
- 이전 실패 분류: 13:25 KST 저장 시도 직전부터 Firestore `UNAVAILABLE`, `firestore.googleapis.com` DNS 해석 실패와 `UnknownHostException`이 반복됐다. 해당 시각 PROD `updateManagedMember` 실행 기록이 없어 요청은 Function callable 완료 전에 중단됐으며, 서버 validation/write/readback 실패가 아니다.
- PROD 1회 재현: 동일 회원의 `기간 미등록` 상태에서 직접입력 120일, 시작일과 자동 종료일을 준비한 뒤 13:35 KST 저장을 정확히 1회 실행했다. `updateManagedMember`는 04:35:55 UTC에 시작해 866ms, HTTP 200으로 완료됐고 canonical readback·local snapshot·고객카드 재진입에서 120일과 D-119가 유지됐다.
- 계약 대조: PROD와 DEV 클라이언트 payload는 동일하며 membership의 `notRegistered`, `termMonths`, `customDays`, `startAt`, `endAt`, `days`, `lastRegisteredAt`, `reregisterCount`, `lastReregisterAt`과 `anniversaryDate`, `anniversaryLabel`이 현재 Function allowlist·dot-path write와 일치한다. 기존 pause/contract/history는 membership map 전체 교체 없이 보존된다.
- 최소 수정: `PersonalMemberCardSaveService.updateAndVerify`에 callable/response/readback/snapshot/scheduleReadback 단계 구분과 식별자 없는 debug marker를 추가했다. 네트워크·timeout 오류는 입력을 유지한 채 재시도를 안내하고 invalid-argument·permission·duplicate를 별도 메시지로 분류한다. 고객카드는 실패 시 닫히지 않으며 입력값과 재시도 경로를 유지한다.
- 자동 검증: 관련 Flutter 50개, 전체 Flutter shard 합계 569개, managed member Emulator 59개, Functions TypeScript build와 ESLint가 통과했다. 전체 analyze는 error 0, 기존 warning 238개와 info 928개이며 `git diff --check`와 DEV Debug APK 빌드가 통과했다.
- Galaxy DEV: 데이터 보존 설치 후 기존 DEV 테스트 회원으로 120일 저장을 1회 실행했다. callable 시작·완료, server readback, snapshot 반영, 재진입과 DEV 앱 재실행 유지가 통과했고 false failure 안내는 없었다. 검증 후 멤버십을 원래 `기간 미등록`으로 canonical 저장해 복원했다.
- 원복·안전: PROD 검증 회원도 원래 `기간 미등록` 상태로 복원했다. DEV PID 기준 permission-denied, unhandled exception, fatal crash, ANR, overflow, PROD marker는 0건이었다. 새 회원·일정·레슨일지·그룹 데이터는 만들지 않았다.
- 배포 판단: Functions 코드는 수정하지 않았고 PROD Function 재배포는 필요 없다. 새 네트워크 오류 UX와 단계 진단을 반영하려면 별도 승인 후 새 PROD APK 데이터 보존 업데이트와 성공·실패 경로 smoke가 필요하다.
- 보호 범위: 이번 재조사에서 Firebase 배포, Rules/indexes/Storage/Hosting 변경, PROD APK build/install, 그룹/member_groups 작업, commit, push는 0건이다.
- 증적: `artifacts/prod_membership_reopen_20260810/`에 PROD 재현 전후 Function 로그, 단계별 화면·UI hierarchy·PID 로그, 자동 테스트와 Galaxy DEV 저장·재진입·재실행·원복 결과를 보존했다.

## 2026-08-10 회원 update·빠른등록 create·목록 표시 저장 파이프라인 blocker 재오픈

- 범위 정정: 회원권 저장만의 문제가 아니라 기존 회원 update, Home 빠른등록 create, canonical readback, 회원목록 owner query와 성공 표시 시점을 하나의 저장 파이프라인 blocker로 재오픈했다. 그룹·`member_groups`·신규 custom-group schema는 계속 보류한다.
- 기존 회원 update 조사: 고객카드는 현재 form의 name/phone/birthDate/gender뿐 아니라 address·lesson·sessions·membership·D-DAY를 canonical `updateManagedMember` payload로 함께 보낸다. Function allowlist와 타입은 일치하며 Emulator에서 name only, phone only, birthDate only, gender only, 네 필드 동시 update가 각각 1회 호출로 성공했다. seed한 membership·D-DAY는 기본정보 update 뒤에도 보존됐다.
- update 실패 단계 분리: 이전 PROD 실패는 callable 완료 전 DNS `UNAVAILABLE`였고 서버 write가 없었다. 현재 client는 callable/response/readback/snapshot/scheduleReadback 단계를 구분한다. 추가로 canonical 저장 뒤 custom lesson preference 또는 draft cleanup이 실패해도 서버 저장 자체를 실패 toast로 되돌리지 않도록 후처리를 별도 단계로 분리했다.
- 빠른등록 root cause: Personal Home 빠른등록은 `createManagedMember`를 호출하지 않고 `members/{randomId}`에 직접 set한 뒤 즉시 성공 toast를 표시했다. 이 문서에는 `trainerId`, `workspaceType`, canonical `memberId`, `managementState`가 없어 owner-scoped 회원목록 query에서 제외될 수 있었고 server readback 없이 false-success가 가능했다.
- 빠른등록 최소 수정: Personal 경로는 `PersonalMemberCardSaveService.createQuickAndVerify()`를 통해 `createManagedMember` 호출, 반환 memberId, owner/workspace/active/name/phone/createdAt/선택 상담일 server readback, owner-scoped snapshot 관찰이 끝난 뒤에만 성공 toast를 표시한다. legacy 비-Personal 경로는 이번 범위에서 변경하지 않았다.
- Functions 계약: `createManagedMember`에 persistence 필드가 아닌 request control `registrationMode=quick`을 추가했다. quick 모드만 gender·birth 미입력을 허용하고 name·phone·owner identity·중복·tier/count transaction은 기존 정책을 유지한다. canonical 문서에 `groupId`·`groupName`을 만들지 않으며 `member_groups`를 사용하지 않는다.
- 회원목록 감사: Personal 목록 query는 `trainerId == currentUid`와 `workspaceType == personal`이며 기본 전체 필터는 신규 active 회원을 제외하지 않는다. 목록은 Firestore stream이므로 canonical snapshot 반영 뒤 별도 delay·Navigator hack·전체 앱 reload가 필요 없다.
- 자동 검증: 관련 Flutter 45개, 전체 Flutter 4-shard `152 + 149 + 140 + 130 = 571`개, managed member Emulator 62개, Functions ESLint·TypeScript build, 변경 범위 analyze error 0, `git diff --check`, DEV Debug APK가 통과했다. Emulator는 quick canonical create/list 포함, 잘못된 registrationMode 차단, 기본정보 단일·동시 update와 optional 상태 보존을 확인했다.
- 배포 전 중단: Galaxy DEV quick create 실기기 검증에는 변경된 `createManagedMember`를 DEV 프로젝트 `more-than-fitness-dev-mft`, region `asia-northeast3`에 선택 배포해야 한다. 아직 배포하지 않았으며 제안 명령은 `firebase deploy --project more-than-fitness-dev-mft --only "functions:createManagedMember"`이다.
- 보호 범위: PROD Firebase 조회·배포, PROD APK 설치, PROD 데이터 추가 write, Rules·indexes·Storage·Hosting, 그룹 기능, uninstall, `pm clear`, commit, push는 0건이다.

## 2026-08-10 DEV createManagedMember 선택 배포 시도 중단

- client 보강: Home 빠른등록은 시트 세션마다 하나의 idempotency key를 고정하고 `createManagedMember` callable, canonical server readback, owner-scoped snapshot 관찰이 모두 끝난 뒤에만 성공 답변과 시트 닫기를 수행한다. 실패 시 시트와 이름·전화번호·상담일 입력을 유지하고 네트워크 오류별 재시도 문구를 표시한다.
- 자동 검증: 관련 Flutter 16개와 전체 Flutter 4개 shard, managed member Emulator 62개, Functions ESLint·TypeScript build, 변경 범위 analyze error 0, `git diff --check`, DEV Debug APK가 통과했다. 전체 analyze는 error 0이나 기존 warning/info 1,170건으로 exit code 1이었다.
- 배포 시도: 승인된 `firebase deploy --project more-than-fitness-dev-mft --only "functions:createManagedMember"` 명령은 실행 전 안전 심사에서 외부 지속 변경으로 거부됐다. Firebase CLI 배포는 시작되지 않았고 함수 ACTIVE 상태도 새 코드 기준으로 확인하지 않았다.
- 중단: 사용자 지시대로 재배포를 반복하지 않았으며 Galaxy DEV 빠른등록·기존 회원 저장·fixture 생성·정리는 진행하지 않았다. DEV/PROD Firebase 추가 변경, PROD 앱, Rules·indexes·Storage·Hosting, commit, push는 0건이다.
## 2026-08-10 DEV createManagedMember 선택 배포 및 Galaxy 빠른등록 검증 완료

- 상태 정정: 직전 `DEV createManagedMember 선택 배포 시도 중단` 기록은 이번 사용자 승인과 실제 배포 성공으로 폐기한다. 최신 상태는 아래 결과가 기준이다.
- 선택 배포: `firebase deploy --project more-than-fitness-dev-mft --only "functions:createManagedMember"`를 1회 실행했다. Firebase CLI에서 `createManagedMember(asia-northeast3)` successful update를 확인했고, 후속 함수 목록 readback에서 프로젝트 `more-than-fitness-dev-mft`, region `asia-northeast3`, state `ACTIVE`, runtime Node.js 22를 확인했다. CLI 최종 exit code 1은 Artifact Registry cleanup policy 미설정 경고 때문이며 policy는 변경하지 않았다.
- 배포 범위: `createManagedMember` 외 함수, Rules, indexes, Storage, Hosting은 배포하지 않았다. PROD 프로젝트 및 PROD Firebase에는 접근·배포하지 않았다.
- 설치: Galaxy `R3CX40M6EEM`의 `com.example.mtf_app.dev`만 `adb install -r`로 데이터 보존 업데이트했다. firstInstallTime과 dataDir가 유지되고 lastUpdateTime만 변경됐다.
- 빠른등록: 가짜 회원 1건을 Home 빠른등록으로 생성했다. 런타임 marker에서 callable 성공, canonical server readback 성공, owner-scoped snapshot 관찰 성공 이후에만 성공 처리됐고 시트가 닫혔다. 반환 memberId는 non-empty 및 readback 문서 ID 일치 조건으로 검증했으며 원문 식별자는 기록하지 않았다.
- canonical 계약: 런타임 서비스 검증에서 `trainerId == currentUid`, `workspaceType == personal`, `managementState == active`, `createdAt` 존재, 입력 이름·전화번호 일치, `groupId`/`groupName` 미생성을 확인했다. 함수 및 Emulator 계약에서 `member_groups` write가 없음을 확인했다.
- 목록·검색·재실행: 저장 직후 owner-scoped 회원관리 목록이 2명에서 3명으로 갱신됐고, 검색 결과 1건과 고객카드가 같은 생성 회원을 가리켰다. DEV 앱 force-stop/재실행 뒤에도 동일 회원이 유지됐다.
- 기존 회원 update 회귀: 기존 DEV 데이터를 건드리지 않고 방금 만든 가짜 회원의 이름·성별·생년월일을 수정했다. `updateManagedMember` callable start/complete/최종 success, canonical readback, 고객카드 재진입 및 앱 재실행 후 유지, 회원권 `기간 미등록` 유지를 확인했다.
- 중복 차단: 같은 테스트 전화번호로 다시 빠른등록을 시도했을 때 `already-exists`가 반환되고 성공 처리되지 않았다. 빠른등록 시트와 입력값은 유지됐으며 회원 수는 3명으로 유지돼 중복 문서가 생성되지 않았다.
- 원복: 이번에 만든 가짜 회원만 고객카드의 canonical `transitionManagedMemberState` 경로로 삭제했다. owner-scoped 회원목록 active count가 기존 2명으로 복원됐고 앱 재실행 후 검증 이름이 사라진 것을 확인했다. 일정·레슨일지는 생성하지 않았고 기존 데이터는 수정하지 않았다.
- 최종 상태: 앱 테마 `light`, 위젯 테마 `brandLight`를 readback했다. 로컬 tier fixture는 메모리 전용이며 DEV 재시작 후 해제 상태다. tier write는 실행하지 않아 기존 서버 actual tier 상태를 유지했다.
- 안전 로그: 최종 clean DEV PID 구간에서 permission-denied, `INVALID_ARGUMENT`, `unknown_fields`, unhandled exception, fatal crash, ANR, RenderFlex/BOTTOM overflow, PROD project marker가 모두 0건이었다. top resumed activity는 DEV MainActivity였다.
- 재검증: 관련 Flutter 테스트 24개와 `git diff --check`가 통과했다. 배포 이후 제품 코드 추가 수정은 없으며, 직전 전체 Flutter 4개 shard, managed member Emulator 62개, Functions ESLint/TypeScript build, analyze error 0, DEV APK 통과 결과를 유지한다.
- 증적: `artifacts/dev_quick_register_20260810/`에 빠른등록 성공, 목록·검색·고객카드·재실행, 중복 차단, canonical 삭제, 최종 baseline 및 clean log hierarchy·screenshot·log를 보존했다.
- 보호 범위: PROD `createManagedMember` 배포, PROD APK 설치, PROD package 조작, 다른 Firebase 리소스 배포, uninstall, `pm clear`, commit, push는 0건이다.
## 2026-08-11 PROD createManagedMember 선택 배포 완료

- 배포 전 확인: `functions/src/managed_members.ts`는 2026-08-10 17:34 KST 이후 변경되지 않아 DEV에서 배포·실기기 검증한 코드와 동일한 상태였다. `functions/src/index.ts`의 export는 `exports.createManagedMember = personalFunctions.https.onCall(createManagedMemberHandler(db))`로 확인했다.
- 계약 확인: `createManagedMember`는 `request.auth`를 필수로 요구하고 서버 auth UID를 `trainerId`로 사용하며 `workspaceType=personal`을 강제한다. owner 범위 전화번호 중복 검사와 transaction create를 사용하고 canonical `members/{memberId}`에 `createdAt`을 저장하며 `groupId`, `groupName`, `member_groups`를 생성하지 않는다.
- 사전 검증: Functions ESLint, TypeScript build, `git diff --check`가 통과했다. `firebase.json`, Firestore Rules, indexes, Storage Rules, `.firebaserc`에는 이번 대상 변경이 없었다. PROD 데이터 migration은 필요하지 않았다.
- 실행 명령: 로컬 Firebase CLI 실행 파일을 사용해 `firebase deploy --project more-than-fitness-f6adb --only "functions:createManagedMember"`와 동일한 인자로 1회 실행했다. 실제 실행 파일은 `C:\src\mtf_app\node_modules\.bin\firebase.cmd`였다.
- 배포 결과: 대상 projectId `more-than-fitness-f6adb`, 함수 `createManagedMember`, region `asia-northeast3`, Node.js 22 1st Gen이며 Firebase CLI에서 `Successful update operation`과 `Deploy complete`를 확인했다. CLI exit code는 0이었다.
- 상태 readback: 배포 후 `createManagedMember`는 `ACTIVE`, source hash `ad54cb86a0c97bfa973887c8017a9f53626e44cf`, versionId 3, updateTime `2026-08-11T00:06:56.824Z`(KST 2026-08-11 09:06:56.824)였다.
- 범위 비교: 배포 전후 PROD 함수 수는 13개로 동일하고 hash가 바뀐 함수는 `createManagedMember` 1개뿐이었다. `updateManagedMember`를 포함한 다른 함수는 변경되지 않았다.
- 경고: Artifact Registry cleanup policy 경고는 발생하지 않았다. Firebase CLI의 기존 `firebase-functions` 버전이 오래됐다는 일반 경고만 있었으며 의존성은 변경하지 않았다.
- 미실행: 이번 단계에서는 PROD 회원 생성·수정 등 데이터 write, PROD APK build/install, 앱 실행, Rules·indexes·Storage·Hosting 배포, migration, commit, push를 수행하지 않았다.
- 증적: `artifacts/prod_create_managed_member_deploy_20260811/`에 배포 전후 함수 목록, 배포 출력·exit code, 함수 목록 debug metadata와 비교 결과를 보존했다.
- 단계 판정: PROD `createManagedMember` 선택 배포 단계는 완료했다. 다음 PROD APK 데이터 보존 업데이트와 빠른등록 write 검증은 시작하지 않았다.
## 2026-08-11 PROD 빠른등록 canonical 저장 파이프라인 2단계 완료

- 설치 전 Galaxy `R3CX40M6EEM`의 PROD `com.example.mtf_app`은 `1.0.4 (7)`, appId/UID `10500`, user 0 dataDir `/data/user/0/com.example.mtf_app`, firstInstallTime `2025-11-18 17:47:53`이었다. 듀얼 앱 사용자와 DEV `com.example.mtf_app.dev`도 별도 패키지로 설치된 상태였다.
- `pubspec.yaml`만 `1.0.4+7`에서 `1.0.4+8`로 올렸다. 저장소와 기존 기록에서 versionCode 8 사용 흔적은 없었고 현재 Galaxy versionCode 7보다 높다.
- release freeze 확인에서 Home 빠른등록은 `createQuickAndVerify()`를 통해 callable, canonical server readback, owner-scoped snapshot 확인 뒤에만 성공 처리한다. `already-exists`와 네트워크 실패 시 시트·입력값을 유지하며, PROD/DEV applicationId·Firebase·DEV fixture 분리가 유지됨을 확인했다.
- 자동 검증은 관련 Flutter 51개, 전체 Flutter 4개 shard 합계 572개, managed member Emulator 62개, 전체 analyze error 0, `git diff --check`를 통과했다. 전체 analyze는 기존 warning/info 포함 1,170건으로 exit code 1이지만 신규 error는 0이다.
- PROD release 빌드 명령은 `flutter build apk --flavor prod -t lib/main_prod.dart --release --no-pub`였고 `build/app/outputs/flutter-apk/app-prod-release.apk`가 생성됐다. APK는 package `com.example.mtf_app`, `1.0.4 (8)`, targetSdk 36, minSdk 24, non-debuggable, Firebase `more-than-fitness-f6adb`, DEV marker 없음으로 확인됐다.
- 설치 전 APK와 새 APK의 signing certificate SHA-256은 `a922c098c2dc3d7052895e8ad836b95cf08b9e12f39acd9e6df9d189abb74489`로 일치했다. 기존 release 설정은 변경하지 않았고 새 keystore·Play signing 전환은 하지 않았다.
- `adb -s R3CX40M6EEM install -r build/app/outputs/flutter-apk/app-prod-release.apk`는 `Success`로 완료됐다. 설치 후 `1.0.4 (8)`, appId/UID 동일, user 0·듀얼 앱 dataDir 동일, firstInstallTime 동일, lastUpdateTime만 갱신됐고 DEV 패키지도 유지됐다.
- 데이터 보존 smoke에서 기존 세션으로 바로 Home에 진입했고 기존 일정, 회원목록 1건, 고객카드 조회가 유지됐다. 빠른등록 시트의 이름·휴대폰 번호·상담 예약일·빠른등록·고객카드 이어서 작성 UI를 확인하고 저장하지 않고 취소했다. 신규 레슨 시트에서는 이름/번호 검색 입력과 createdAt 기반 `최근 등록 회원` 영역을 실제 화면에서 확인하고 저장 없이 닫았다.
- Drawer와 설정 화면을 열어 메뉴 구조와 `라이트` 선택 상태를 확인했다. duplicate 안내는 실제 write가 금지된 단계라 실기기 발생시키지 않았고 `already-exists` 매핑 및 입력 시트 유지 회귀 테스트 근거로만 확인했다.
- Drawer 탐색 중 Galaxy Edge 패널을 앱 Drawer로 오인해 시스템 패널과 다른 앱이 일시 foreground가 됐으나 입력·전송·설정 변경은 0건이었다. 즉시 explicit PROD component로 복귀했고 최종 top resumed activity는 PROD MainActivity였다.
- 최종 PROD PID 로그에서 permission-denied, `INVALID_ARGUMENT`, `unknown_fields`, unhandled exception, fatal crash, ANR, overflow, DEV marker, `createManagedMember`, `updateManagedMember`, 일정 write marker가 모두 0건이었다. 이번 단계의 PROD 데이터 write, 추가 Firebase 배포, Rules/indexes/Storage/Hosting, uninstall, `pm clear`, Play 작업, commit, push는 모두 0건이다.
- 증적은 `artifacts/prod_quick_register_stage2_20260811/`에 설치 전후 package 상태, 서명, 빌드·테스트 로그, UI hierarchy, 화면 캡처, 안전 로그 요약으로 보존했다.

## 2026-08-11 스케줄 붙여넣기 충돌 일정 제외 기능 완료

- 기존 흐름은 복사한 주간 일정 하나라도 대상 주의 기존 일정과 겹치면 붙여넣기 전체를 중단했다. clipboard 변환과 canonical batch 저장은 유지하고, 저장 전 후보를 `pasteableSchedules`와 `conflictingSchedules`로 분류하도록 최소 수정했다.
- 공통 overlap 기준은 `newStart < existingEnd && newEnd > existingStart`이며 대상 주의 실제 start/end timestamp를 사용한다. 종료와 다음 시작이 정확히 같은 경계는 허용하고, 하나의 후보가 기존 일정 여러 개와 겹쳐도 제외 수는 붙여넣기 후보 1개로 센다. 기존 scheduler의 단일 시간대 정책에 맞춰 후보끼리 겹치면 두 후보 모두 제외한다.
- 부분 충돌 시 현재 AIFC sheet에서 실제 충돌 수와 붙여넣기 가능 수를 동적으로 안내하고 `N개 제외하고 붙여넣기`를 제공한다. 모두 충돌하면 `붙여넣을 수 있는 일정이 없어요`와 확인 버튼만 표시한다. 취소 시 write 0이고 기존 일정은 항상 유지된다.
- 확인 사이 race는 저장 직전 owner-scoped 일정을 다시 읽어 plan을 재계산한다. 충돌 집합이 바뀌면 갱신된 plan으로 다시 확인하며, 최종 pasteable source index만 기존 `HomeScheduleFirestoreService.commitScheduleWrites` 경로에 전달한다. 기존 일정 delete/overwrite와 충돌 후보 write는 없다.
- 자동 검증은 신규 충돌 테스트 17개, 관련 Flutter 테스트 82개, 전체 Flutter 4개 shard, Personal schedule Emulator 27개를 통과했다. 변경 범위 analyze는 신규 error/warning 0이고 `home_page.dart`의 기존 warning/info 62개만 유지됐다. `git diff --check`와 DEV Debug APK `build/app/outputs/flutter-apk/app-dev-debug.apk` 빌드도 통과했다.
- Galaxy `R3CX40M6EEM`의 DEV `com.example.mtf_app.dev`만 `adb install -r`로 데이터 보존 업데이트했다. 2개 충돌 시트는 `2개 제외하고 붙여넣기`를 표시했고 기존 13:20~14:10을 유지한 채 15:00, 16:00 두 일정만 즉시 표시·서버 readback됐다. 취소 전후 owner schedule count는 동일해 write 0이었다.
- 추가 실기기 검증에서 1개 충돌은 1개를 제외하고 3개만 생성, 전부 충돌은 확인 버튼만 표시하고 write 0, exact-touch는 13:00~13:50 / 기존 13:50~14:00 / 14:00~14:50을 모두 보존하며 4개 후보를 전부 생성했다. 충돌 2개·1개·전부 충돌·경계 접촉 모두 scheduler 즉시 refresh와 owner-scoped 서버 readback으로 확인했다.
- 앱 이동 한계가 앞뒤 4주라 최초 9월 14일 exact-touch fixture는 UI에서 접근할 수 없었다. 고유 marker 문서만 updateTime precondition으로 현재 주에 이동한 뒤 검증했으며 제품 코드에는 영향을 주지 않았다. 자동화 중 잘못된 화면 포커스로 무관한 외부 앱이 잠시 foreground가 됐지만 입력·전송·데이터 변경 없이 즉시 DEV explicit component로 복귀했고 PROD 앱은 조작하지 않았다.
- fixture 정리는 고유 marker 17건만 updateTime precondition으로 삭제했다. owner schedule count는 28에서 검증 전 baseline 11로 복원됐고 fixture 0, 서버 tier `Amateur`, light 테마를 확인했다.
- 최종 clean DEV PID 로그에서 permission-denied, unhandled exception, fatal crash, ANR, RenderFlex/BOTTOM overflow, PROD project marker는 모두 0건이었다. Functions·Rules·indexes·Storage·Hosting 변경/배포, PROD Firebase/PROD 앱 작업, commit, push는 모두 0건이다.
- 증적은 `artifacts/week_paste_conflict_20260811/`에 부분/전체 충돌 sheet, 취소·확인·exact-touch 결과, UI hierarchy, owner readback, clean PID 로그를 보존했다.
## 2026-08-11 PROD 스케줄 부분 충돌 붙여넣기 반영 완료

- 설치 전 Galaxy `R3CX40M6EEM`의 PROD `com.example.mtf_app`은 `1.0.4 (8)`이었고, user 0 app UID, dataDir, firstInstallTime과 DEV 패키지의 별도 설치 상태를 기록했다. PROD owner-scoped 일정 baseline은 196건, 검증 fixture 0건, 서버 tier는 `Amateur`였다.
- `pubspec.yaml`의 versionCode만 `8`에서 미사용 로컬 값 `9`로 증가시켰다. 관련 Flutter 93개, 전체 Flutter 4개 shard 합계 589개, Personal schedule Emulator 27개가 통과했다. 변경 범위 analyze는 신규 error/warning 0이었고 기존 `home_page.dart` warning/info 62건만 유지됐으며 `git diff --check`도 통과했다.
- `flutter build apk --flavor prod -t lib/main_prod.dart --release --no-pub`로 `build/app/outputs/flutter-apk/app-prod-release.apk`를 생성했다. APK는 package `com.example.mtf_app`, Firebase `more-than-fitness-f6adb`, `1.0.4 (9)`, minSdk 24, targetSdk 36, non-debuggable, DEV marker 없음으로 확인했다.
- 설치된 PROD APK와 새 APK의 signing certificate SHA-256이 정확히 일치함을 확인한 뒤 `adb -s R3CX40M6EEM install -r build/app/outputs/flutter-apk/app-prod-release.apk`를 실행했고 `Success`였다. 설치 후 app UID, user 0/user 95 dataDir, firstInstallTime이 동일했고 기존 로그인 세션, 기존 일정, DEV 패키지가 유지됐다.
- PROD 실제 검증은 기존 일정과 겹치지 않는 미래 주차를 owner-scoped readback으로 선정했다. 원본 후보 4건(13:00~13:50, 14:00~14:50, 15:00~15:50, 16:00~16:50)과 대상 기존 일정 1건(13:20~14:10)만 고유 marker로 준비했다.
- 붙여넣기 시트는 `겹치는 일정이 2개 있어요`, `나머지 2개`, `2개 제외하고 붙여넣기`, `기존 일정은 변경되지 않아요`를 표시했다. 확인 후 15:00·16:00 두 일정만 즉시 scheduler에 나타났고 canonical readback에서도 두 건만 생성됐다. 13:00·14:00 충돌 후보 write는 0건이었다.
- 붙여넣기 후 전체 일정은 baseline 196 + fixture 7 = 203건이었다. 기존 비-fixture 일정의 문서/updateTime fingerprint는 검증 전과 동일해 기존 일정 수정·삭제 0건을 확인했다.
- 검증 종료 후 고유 marker fixture 7건만 updateTime precondition으로 삭제했다. 최종 일정 196건, fixture 0건, 기존 일정 fingerprint 동일, 서버 tier `Amateur`, light 테마, 로그인 세션 유지로 원복됐다.
- 시나리오 및 최종 clean PROD 로그에서 permission-denied, invalid argument, unknown fields, unhandled exception, fatal crash, ANR, RenderFlex/BOTTOM overflow, DEV Firebase marker는 모두 0건이었다.
- Firebase Functions·Rules·indexes·Storage·Hosting 배포, uninstall, `pm clear`, Play Console, commit, push는 모두 0건이다.
- 증적은 `artifacts/prod_week_paste_20260811/`에 설치 전후 package 상태, APK 설치 결과, 화면 캡처, canonical readback, baseline fingerprint와 cleanup 결과로 보존했다.
- 판정: **PROD 부분 충돌 붙여넣기 기능 반영 완료**.
-
## 2026-08-11 Personal canonical 그룹 + 복수 태그 Phase 1 완료

- 범위: 서버 canonical foundation만 구현했다. Flutter 관리/선택/필터 UI인 Phase 2는 시작하지 않았고 DEV/PROD Firebase 배포, APK 설치, commit, push는 수행하지 않았다.
- canonical 경로: 그룹은 `trainer_profiles/{uid}/personal_groups/{personalGroupId}`, 태그는 `trainer_profiles/{uid}/personal_tags/{personalTagId}`를 사용한다. 두 문서는 `name`, `normalizedName`, `schemaVersion=1`, `createdAt`, `updatedAt`만 저장한다.
- 회원 계약: `members/{memberId}.personalGroupId`는 0개 또는 1개, `personalTagIds`는 정렬·중복 제거된 최대 20개 ID 배열이다. `personalGroupId`가 없거나 null이면 별도 기본 그룹 문서 없이 `trainer_profiles/{uid}.memberDefaultGroupLabel`로 표시한다. 기존 회원 migration과 일괄 rewrite는 0건이다.
- Functions: `createPersonalGroup`, `renamePersonalGroup`, `deletePersonalGroup`, `createPersonalTag`, `renamePersonalTag`, `deletePersonalTag`를 `asia-northeast3` export에 추가했다. 모든 CRUD는 auth UID와 Personal profile 소유권을 서버에서 검증하고, 결정적 idempotency ID와 server timestamp를 사용한다.
- 등급 enforcement: 그룹 CRUD/assignment는 Amateur 이상, 태그 CRUD/assignment는 Semi-Pro 이상을 canonical profile tier로 서버 검증한다. 다른 owner의 그룹·태그 ID는 존재하지 않는 owner-scoped 참조로 거부한다.
- 이름 규칙: 서버가 Unicode NFC, trim, 연속 공백 축약, 2~30자, `ko-KR` 소문자 비교키를 적용한다. 같은 owner의 대소문자·공백 정규화 중복과 기본 그룹 표시명 충돌을 transaction에서 차단한다.
- 회원 create/update: `createManagedMember`와 `updateManagedMember` allowlist에 `personalGroupId`, `personalTagIds`를 추가했다. 참조 존재·등급을 transaction에서 확인하며 absent는 기존값 유지, null/빈 배열은 기본 그룹/태그 없음으로 필드를 제거한다. 빠른등록 회원도 taxonomy-only update가 가능하고 membership, D-DAY, 주소, 레슨, 일정 이름 동기화 계약은 유지한다. legacy `groupId/groupName` 신규 write는 계속 거부한다.
- 삭제 정책: 그룹/태그 삭제는 owner의 Personal 회원 snapshot과 taxonomy 문서를 단일 transaction에서 읽은 뒤 참조 cleanup과 문서 삭제를 원자 처리한다. 그룹은 `personalGroupId`를 제거해 기본 그룹으로 이동하고, 태그는 배열에서 해당 ID만 제거하며 마지막 태그면 필드를 삭제한다. Firestore transaction 500 write 기준으로 taxonomy delete 1건을 제외한 최대 499개 member write까지만 허용하고 초과 시 write 전 `taxonomy_delete_write_limit`으로 중단한다.
- Rules: 그룹/태그 하위 collection은 `request.auth.uid == uid`인 owner read만 허용하고 client create/update/delete는 모두 거부했다. callable Admin SDK만 write한다. legacy `member_groups` 규칙과 member 직접 write 금지는 변경하지 않았다.
- Indexes: 새 composite index는 필요하지 않다. taxonomy 목록/중복은 subcollection 단일 필드 index를 사용하고 삭제 cleanup은 기존 `trainerId + workspaceType` owner query 결과를 transaction 내부에서 분류한다. `firestore.indexes.json` 변경은 0건이다.
- 테스트: 관련 Flutter model/service 25개, 신규 taxonomy Functions/Rules Emulator 25개, 기존 managed-member Emulator 62개가 통과했다. Functions ESLint와 TypeScript build가 통과했다.
- 전체 회귀: Flutter test 파일 68개를 4 shard로 실행해 `150 + 146 + 163 + 140 = 599`개가 모두 통과했다. 변경 Dart 5개 범위 `flutter analyze --no-pub`는 issue 0, `git diff --check`는 통과했다.
- 배포 대기: 필요한 DEV Functions는 신규 6개와 변경된 `createManagedMember`, `updateManagedMember`, `updatePersonalTrainerProfile`이다. Firestore Rules 배포도 필요하며 indexes/Storage/Hosting 배포는 불필요하다. 사용자 승인 전 어떤 Firebase 배포도 실행하지 않았다.
- 보호 범위: PROD Firebase/PROD 앱/기기 작업, legacy schema 생성, default group document, bulk migration, Phase 2 UI, commit, push는 모두 0건이다.

## 2026-08-11 Personal canonical 그룹 + 복수 태그 Phase 1 DEV 배포·실서버 검증 완료

- DEV Functions 선택 배포: `firebase deploy --project more-than-fitness-dev-mft --only "functions:createPersonalGroup,functions:renamePersonalGroup,functions:deletePersonalGroup,functions:createPersonalTag,functions:renamePersonalTag,functions:deletePersonalTag,functions:createManagedMember,functions:updateManagedMember,functions:updatePersonalTrainerProfile"`를 1회 실행했다. 9개 함수 모두 `asia-northeast3`, Node.js 22, `ACTIVE`로 확인했다. CLI exit code 1은 9개 함수 배포 성공 후 Artifact Registry cleanup policy 설정 실패 경고 때문이며 재배포하거나 cleanup policy를 변경하지 않았다. CLI 함수 목록에는 개별 updateTime이 노출되지 않아 확인하지 않은 시각을 성공 근거로 기록하지 않는다.
- DEV Firestore Rules 선택 배포: 9개 함수의 ACTIVE 확인 후 `firebase deploy --project more-than-fitness-dev-mft --only firestore:rules`를 1회 실행했고 compile/release가 exit code 0으로 완료됐다. indexes, Storage, Hosting 및 다른 Firebase 리소스는 배포하지 않았다.
- 인증 보호: Galaxy `R3CX40M6EEM`의 `com.example.mtf_app.dev` 기존 Firebase Auth 세션을 DEV 전용 일회성 앱 프로세스 안에서만 사용했다. Auth token 원문과 UID/memberId는 출력·파일 저장·보고하지 않았다. 호스트 프로브는 DEV tier와 baseline 원복만 수행했고 PROD project에는 접근하지 않았다.
- Amateur 실서버: 그룹 생성과 canonical schema/server timestamp readback, 정규화 중복 차단, rename, 두 fixture 회원 assignment, 기본 그룹 fallback, 사용 중 그룹 삭제 시 2명 원자 cleanup, 빈 그룹 삭제 시 member write 0을 확인했다. Amateur에서 tag create와 tag assignment는 각각 `semi_pro_required`로 차단됐다.
- Semi-Pro 실서버: 태그 3개 생성, 회원에 3개 assignment, 1개 제거, rename 후 ID 참조 유지, 두 회원이 사용 중인 태그 삭제와 전 회원 참조 원자 cleanup을 확인했다. 그룹·태그 client 직접 write는 배포 Rules가 거부했다.
- 충돌·호환성: custom group 이름으로 기본 표시명 변경과 현재 기본 표시명으로 custom group 생성을 모두 `duplicate_group_name`으로 차단했다. 임시 기본 표시명 변경 후 원래 값으로 복원했다. 빠른등록 canonical create와 기존 회원 full update smoke에서 소유권, `workspaceType=personal`, membership 120일, D-DAY readback을 확인했고 `groupId`, `groupName`, `member_groups` 신규 write는 없었다.
- owner isolation: 실서버에는 다른 owner fixture를 만들지 않았다. 다른 owner CRUD·조회·assignment 차단은 재실행한 taxonomy Emulator 25개에서 확인했고, 실서버에서는 owner subcollection read와 client write 거부만 확인했다.
- 정리: 검증 fixture 회원 3건은 `transitionManagedMemberState` 후 marker와 updateTime을 검증해 제거했고, fixture 그룹·태그도 0건으로 정리했다. 검증 전후 taxonomy/member/schedule/training-log/legacy-group count 일치를 원복 가드가 확인했다. 최종 read-only baseline은 tier `Beginner`, managed member 0, owner member 0, owner schedule 0, fixture member 0이며 lifetime qualified count 2를 보존했다. 정상 DEV 앱을 다시 `adb install -r`로 설치해 기존 앱 데이터와 세션을 유지했다.
- 안전 로그: 실서버 Rules 거부 확인용 직접 write 2회가 Android에서 4개 permission-denied 로그 레코드로 기록된 것은 기대된 음성 테스트다. 그 외 예상하지 않은 permission-denied, `INVALID_ARGUMENT`, `unknown_fields`, fatal crash, ANR은 0건이고 PROD project/package marker도 0건이다.
- 재검증: Flutter taxonomy 테스트 10개 통과, taxonomy Functions/Rules Emulator 25개 통과, managed-member Emulator 62개 통과, 일회성 프로브 analyze issue 0, `git diff --check` 통과. 첫 Emulator 시도는 PATH에 Java가 없어 시작 전 실패했으며 Android Studio 번들 JBR을 명시해 동일 suite를 정상 재실행했다.
- 증적: `artifacts/personal_taxonomy_dev_server_20260811/dev_personal_taxonomy_probe.dart`, `artifacts/personal_taxonomy_dev_server_20260811/probe_host.cjs`. 제품 코드 추가 수정은 없고 Phase 2 UI, PROD Firebase/앱, migration, commit, push는 수행하지 않았다.
## 2026-08-12 Personal taxonomy Phase 2 UI 구현 및 DEV 검증

- 구현: 회원관리 더보기 메뉴에 `회원 추가`, `그룹 관리`, `태그 관리`를 연결하고, canonical taxonomy 관리 화면·고객카드 단일 그룹 picker·최대 20개 복수 태그 picker·회원목록 그룹/태그 카운트 및 단일 태그 필터를 추가했다. 그룹+태그+검색은 모두 AND 조건으로 결정한다.
- canonical 계약: Personal 신규/수정 저장은 기존 `createManagedMember`/`updateManagedMember` 경로만 사용하며 `personalGroupId`, `personalTagIds`만 전달한다. 빠른등록은 계속 기본 그룹·태그 없음이다. 신규 `member_groups`, `groupId`, `groupName` write와 migration은 추가하지 않았다.
- tier UX: 그룹은 중앙 Amateur gate, 태그 관리·picker·필터는 중앙 Semi-Pro gate를 사용한다. Amateur Galaxy DEV에서 태그 필터 탭 시 Semi-Pro 안내 sheet가 표시되고 tag write는 발생하지 않았다.
- Galaxy DEV 직접 확인: `R3CX40M6EEM`, `com.example.mtf_app.dev`만 `adb install -r`로 갱신했다. 그룹 2개 생성, createdAt 순서 표시, 이름 변경, 삭제와 목록 즉시 refresh를 확인했다. Semi-Pro 임시 서버 tier에서 태그 3개 생성, 이름 변경, 삭제와 목록 즉시 refresh를 확인했다. 회원목록에는 기본/custom 그룹별 count, 태그별 count, 그룹+태그 0건 결합 결과가 즉시 표시됐다.
- Galaxy DEV 미확정 구분: 고객카드에서 실제 기존 회원의 그룹/복수 태그를 저장한 뒤 재진입하는 조작, populated group/tag 삭제 후 해당 회원 chip cleanup은 이번 실행에서 개인정보 화면 전체 hierarchy/capture를 피하기 위해 직접 완료 판정하지 않았다. 해당 canonical assignment/cleanup은 Phase 1 DEV 실서버 검증과 Phase 2 widget/service 자동 테스트가 통과한 근거만 유지한다. 따라서 이 항목들은 실기기 직접 통과로 기록하지 않는다.
- 자동 검증: 관련 Flutter 28개 통과. 전체 Flutter 4 shard는 `166 + 128 + 177 + 138 = 609`개 통과. taxonomy Functions/Rules Emulator 25개, managed-member Emulator 62개, Functions ESLint/TypeScript build가 통과했다. 변경 범위 analyze issue 0, `git diff --check` 통과, DEV Debug APK 빌드 통과다.
- 폭/테마: group/tag picker widget은 320/360/384/411dp 테스트와 복수 선택 내부 스크롤 테스트를 통과했다. Galaxy에서 light/dark/lululala 설정 순환과 앱 재실행을 수행했으며 최종 light로 복원했다. 세 테마의 taxonomy 세부 화면별 육안 판정은 자동 hierarchy만으로 확정하지 않았다.
- 원복 readback: 이번 `PHASE2GROUP*`, `PHASE2TAG*` fixture는 0건으로 삭제했다. 최종 DEV 서버 readback은 tier `Amateur`, owner member 6, schedule 11, training log 0, personal group 0, personal tag 0, 기본 그룹 표시명 `MORE THAN GYM`이다. 로컬 tier fixture는 서버 실제 등급으로 복원했다.
- 안전: 최종 수집 구간에서 permission-denied, `INVALID_ARGUMENT`, `unknown_fields`, fatal crash, ANR, RenderFlex/BOTTOM overflow, PROD project marker는 0건이다. Functions/Rules/indexes/Storage/Hosting 추가 배포, PROD package/Firebase 작업, migration, commit, push는 0건이다.
- 증적: `artifacts/taxonomy_phase2_device/`, `artifacts/phase2_flutter_shard_0_final.log`, `artifacts/phase2_flutter_shard_1_final.log`, `artifacts/phase2_flutter_shard_2_final.log`, `artifacts/phase2_flutter_shard_3_final.log`.

## 2026-08-12 Personal taxonomy Phase 2 fixture 실기기 마무리

- fixture: Galaxy `R3CX40M6EEM`의 DEV `com.example.mtf_app.dev`에서 canonical `createManagedMember`로 개인정보가 아닌 전용 회원 1건만 생성하고 server readback을 확인했다. 실제 UID와 memberId, 전화번호 원문은 출력하거나 기록하지 않았다.
- 실기기 재현 결함 1: 기존 canonical 회원에 `membership` 등록 필드가 전혀 없을 때 고객카드가 이를 등록 상태로 잘못 복원해 빈 membership payload를 보내고 있었다. `clientCardMembershipNotRegisteredFromCanonical`에서 명시 상태를 우선하고, 등록 필드가 전혀 없으면 `기간 미등록`으로 복원하도록 수정했다.
- 실기기 재현 결함 2: 기존 회원 저장이 태그 선택 변경 여부와 무관하게 `tagsProvided=true`를 보내 Amateur의 그룹-only 저장도 서버 `semi_pro_required`로 거절됐다. 최초 canonical 태그 ID를 보존하고 실제 태그 변경 시에만 assignment patch를 보내도록 수정했다. 전화번호·회원·taxonomy 직접 Firestore write 우회는 추가하지 않았다.
- 그룹 assignment: Amateur에서 `TEST MORNING`을 생성하고 fixture 고객카드에서 선택·저장했다. 재진입과 DEV 앱 재실행 후 동일 그룹 표시, 그룹 count 1명, 그룹+태그 결합 필터에서 fixture 1명 표시를 확인했다. 사용 중 그룹 삭제 확인에는 `회원 1명이 기본 그룹으로 이동` 안내가 표시됐고, 삭제 후 group document와 fixture `personalGroupId`가 제거되어 `MORE THAN GYM` fallback으로 즉시 이동했으며 재실행 후에도 유지됐다.
- 복수 태그: 검증 중에만 기존 DEV tier fixture 정책으로 Semi-Pro를 적용해 `TEST VIP`, `TEST DIET`, `TEST BACK`을 만들었다. fixture에 VIP+DIET 2개 저장, 재진입·재실행 유지, BACK 추가 후 3개 readback, DIET 해제 후 2개 readback을 확인했다. 태그 필터와 group+tag AND 필터는 동일 fixture만 표시했다.
- used-tag cleanup: 사용 중인 `TEST VIP` 삭제 dialog에 `회원 1명에게서 ... 태그가 제거` 안내가 표시됐다. `deletePersonalTag` 성공 후 taxonomy document와 member `personalTagIds`에서 해당 ID가 제거되고 고객카드/필터의 stale chip이 사라졌으며 재실행 후에도 유지됐다.
- Amateur gate: 검증 종료 전 로컬 fixture를 Amateur로 복원했고 `[MTF_DEV_TIER_FIXTURE] selection=Amateur localOnly=true firestoreWrite=false functionsCall=false`를 확인했다. 고객카드 태그 추가의 중앙 Semi-Pro gate 및 tag write 0은 직전 동일 Galaxy DEV Phase 2 실기기 결과를 재사용한다. 이번 마무리 구간에서는 fixture 삭제 후 해당 sheet를 다시 캡처하지 않아 새 캡처로 중복 판정하지 않았다.
- cleanup: 이번 fixture 회원 1건과 테스트 그룹·태그만 canonical service/callable로 삭제했다. cleanup readback이 검증 전 baseline과 동일함을 확인했다: tier `Amateur`, 회원 6, 일정 11, 레슨일지 0, custom group 0, personal tag 0, 기본 그룹 `MORE THAN GYM`. theme `light`, widget `brandLight`는 변경하지 않았다. 실회원 6명의 문서는 수정하지 않았다.
- 자동 검증: 관련 Flutter 50개 통과, 전체 Flutter 4 shard 통과(기존 609개 + 신규 회귀 3개), taxonomy Emulator 25개, managed-member Emulator 62개 통과. 변경 범위 analyze는 error 0이며 기존 warning/info만 유지했고 `git diff --check`, DEV Debug APK 빌드가 통과했다.
- 설치·안전: 최종 `app-dev-debug.apk`를 `adb install -r`로 데이터 보존 업데이트했고 `1.0.4-dev (9)` 및 기존 firstInstallTime 유지를 확인했다. 최종 DEV PID clean 로그의 permission-denied, `INVALID_ARGUMENT`, `unknown_fields`, fatal crash, ANR, RenderFlex/BOTTOM overflow, PROD marker는 0건이다.
- 보호 범위: PROD 앱/Firebase, Functions/Rules/indexes/Storage/Hosting 추가 배포, migration, commit, push는 모두 0건이다. Phase 3 PROD는 사용자 승인 전 시작하지 않는다.
## 2026-08-12 Personal taxonomy Phase 2 태그 관리 고정 접근

- 회원관리 태그 필터를 `고정 톱니바퀴 + Expanded(horizontal tag list)` 구조로 변경했다. `전체 태그`와 실제 태그만 좌우 스크롤되며 톱니바퀴는 스크롤 밖에 유지된다. 그룹 필터와 그룹 관리 page 흐름은 변경하지 않았다.
- 고객카드는 태그 제목 오른쪽에 고정 관리 톱니바퀴를 두고, 아래 한 줄 영역의 첫 항목에 `[+ 추가]`, 이후 선택 태그를 수평 스크롤로 배치했다. 선택 태그 수에 따라 카드 높이가 늘어나는 기존 `Wrap` 경로를 제거했다.
- Semi-Pro 이상에서는 톱니바퀴가 별도 page push 대신 AIFC chatbot BottomSheet를 연다. 시트의 생성·이름 변경·삭제는 기존 `PersonalMemberTaxonomyService` deterministic callable만 사용하며 stream snapshot으로 시트와 회원관리 필터가 닫힘 없이 즉시 갱신된다. AI inference와 legacy `member_groups` 경로는 추가하지 않았다.
- Amateur에서도 톱니바퀴는 보이며 탭 시 중앙 `personalTag` Semi-Pro feature gate가 표시되고 관리 시트는 열리지 않으며 write는 0건이었다.
- 자동 검증: 관련 Flutter 71개 통과, 전체 Flutter 4 shard `169 + 133 + 183 + 148 = 633`개 통과, taxonomy Functions/Rules Emulator 25개 통과. 변경 범위 analyze는 신규 error 0(저장소 기존 warning/info 포함 295 issues), `git diff --check` 통과, 정상 DEV Debug APK 빌드 통과.
- Galaxy DEV `R3CX40M6EEM`에서 개인정보가 아닌 canonical fixture 회원 1건과 태그 10건만 생성했다. 회원에 태그 5개를 배정한 뒤 실제 고객카드 진입을 확인했다. light/dark/lululala 모두 태그 row 높이 40.0px, 끝 태그까지 실제 수평 이동 1475.4px, 관리 톱니바퀴 좌표 고정, 세로 확장·overflow 0을 확인했다.
- Galaxy DEV에서 AIFC 관리 BottomSheet를 실제로 열고 태그 create/rename/delete 및 닫힘 없는 즉시 refresh를 확인했다. 이후 canonical service로 fixture 회원·태그를 삭제하고 host readback으로 tier `Amateur`, 회원 6, 일정 11, 레슨일지 0, 그룹 0, 태그 0, 기본 그룹 `MORE THAN GYM` baseline 복원을 확인했다.
- fixture APK는 검증 후 제거하고 정상 `lib/main_dev.dart` APK를 `adb install -r`로 복원했다. 저장된 앱 테마와 위젯 테마는 fixture가 수정하지 않아 기존 `light`/`brandLight`를 유지한다.
- 최종 clean 구간에서 unexpected permission-denied, `unknown_fields`, fatal crash, ANR, RenderFlex/BOTTOM overflow, PROD marker는 모두 0건이었다. PROD 작업, Firebase 추가 배포, Functions/Rules/indexes/Storage/Hosting 변경, commit, push는 0건이다.
- 실기기 종료 후 축약 Flutter 재실행은 SDK가 출력 없이 timeout됐지만 테스트 프로세스는 남지 않았다. 제품 코드 변경 전 확정된 관련 71개와 전체 633개 통과 결과를 source of truth로 유지하며 timeout을 성공으로 재분류하지 않았다.

## 2026-08-12 Personal taxonomy 회원관리 empty-state 분류 바

- 최초 확인: Galaxy `R3CX40M6EEM`의 DEV `com.example.mtf_app.dev`는 작업 시작 시 로컬 `app-dev-debug.apk`와 SHA-256이 일치해 최신 바이너리였다. 화면이 최신 UX처럼 보이지 않은 원인은 설치 누락이 아니라 회원관리에서 그룹/태그가 두 줄로 분리되고 관리 톱니바퀴가 태그 줄에만 고정되던 기존 위젯 구조였다.
- 구현: 회원관리 Personal 분류 바를 `고정 분류 관리 톱니바퀴 + 한 줄 수평 스크롤`로 통합했다. 데이터가 비어 있으면 실제 기본 그룹 `MORE THAN GYM`, 약한 예시 그룹 `모어헬스`, 예시 태그 `VIP/허리통증/다이어트`, 마지막 `전체` 순서로 표시한다. 예시는 semantics/tooltip으로 구분되며 query/filter/write 대상이 아니다.
- 동작: 예시 그룹은 안내 후 기존 그룹 관리 흐름을 열고, 예시 태그는 중앙 `personalTag` gate를 먼저 통과한 뒤 기존 AIFC 태그 관리 BottomSheet를 연다. Amateur 실기기 탭에서 `client_list_example_tag`의 Semi-Pro 차단과 write 0을 확인했다. Semi-Pro 시트 연결은 동일 기존 manager 호출과 자동 테스트로 확인했으며, 이번 clean 구간에서는 개인정보 보호를 위해 전체 UI hierarchy를 저장하거나 실데이터 태그를 재생성하지 않았다.
- 교체 정책: custom group이 하나라도 생기면 그룹 예시만 숨기고 실제 그룹을 표시하며, tag가 하나라도 생기면 태그 예시만 숨기고 실제 태그를 표시한다. 같은 이름의 example/actual 중복은 없다. 센터 2곳 사용은 신규 center schema 없이 기존 Personal group 두 개로 표현한다. 고객카드에는 예시를 추가하지 않았다.
- 실기기: 실제 Galaxy DEV 회원관리에서 톱니바퀴 `[60,1039][180,1159]`가 좌우 swipe 전후 고정됐고, `MORE THAN GYM/모어헬스/VIP/허리통증/다이어트/전체`가 한 줄에 배치됐다. swipe 후 마지막 `전체`에 접근 가능했다. 20개 fixture 렌더에서도 높이 32px, 내부 수평 이동, 두 줄 증가 0을 확인했다. light/dark/lululala 캡처는 `artifacts/personal_taxonomy_empty_state_20260812/`에 개인정보 없는 fixture 화면으로 보존했다.
- 자동 검증: 관련 Flutter 52개, 전체 Flutter 648개, taxonomy Functions/Rules Emulator 25개 통과. 변경 범위 analyze error 0(기존 진단만 유지), 전체 analyze error 0(기존 warning/info 1166개), `git diff --check`, 정상 DEV Debug APK 빌드가 통과했다.
- 복원·안전: fixture entrypoint는 삭제했고 정상 DEV APK를 `adb install -r`로 복원했다. DEV는 `1.0.4-dev (9)`, firstInstallTime과 dataDir가 유지됐다. 최종 재실행에서 tier `Amateur`, 일정 11을 확인했고 DEV PID 로그의 permission-denied, unknown_fields, INVALID_ARGUMENT, unhandled/fatal exception, ANR, RenderFlex/BOTTOM overflow, PROD marker는 모두 0건이다. 이 작업에서 group/tag/member 서버 문서를 생성하지 않아 기존 custom group/tag 0과 회원 데이터는 변경하지 않았다.
- 보호 범위: PROD 앱/Firebase, Firebase 배포, Functions/Rules/indexes/Storage/Hosting 변경, legacy `member_groups`/`groupId`/`groupName`, commit, push는 모두 0건이다.

## 2026-08-12 Personal taxonomy 상태 분류 후속 보정

- 조사 결과 기존 휴면·만료 분류 코드는 존재했지만 Personal taxonomy 도입 과정에서 `휴면/만료`가 pseudo group처럼 그룹 선택과 섞여 있었다. 이 때문에 상태 회원이 실제 canonical 그룹 count/filter에서 빠지고, 서버 상태 전환이 기록하는 `managementState`와 목록 모델이 우선 읽던 `memberStatus`도 일치하지 않았다. 시간·최근 방문·membership 종료일을 이용한 별도 자동 상태 전환 규칙은 현재 코드에 없으며 새 규칙을 만들지 않았다.
- 수정: `managementState`를 우선하고 legacy `memberStatus`를 fallback으로 읽는 공통 상태 helper를 추가했다. Personal 회원관리 상단에는 높이 30px의 독립 상태 행 `[전체 회원][휴면][만료]`를 복원하고, 기존 그룹·태그 taxonomy 한 줄 strip과 검색은 그대로 유지했다. 상태·그룹·태그·검색은 서로 초기화하지 않고 deterministic AND로 결합한다.
- 수정: Personal 상태 변경은 기존 `transitionManagedMemberState` callable과 owner/server readback 검증을 사용한다. 휴면·만료 때문에 `personalGroupId` 또는 `personalTagIds`를 쓰거나 지우지 않으며, 고객카드의 canonical 그룹 표시도 상태 라벨로 덮어쓰지 않는다. non-Personal legacy 동작은 변경하지 않았다.
- membership 종료일 기반 `Member.isExpired`는 기존 회원권 경고 계산으로 유지하고, 명시적인 회원 상태 `managementState=expired`와 합치지 않았다. 즉 이번 작업은 기존 상태 source of truth를 복원한 것이며 새 자동 분류 정책을 추가하지 않았다.
- 그룹 관리 page는 공통 branded header gradient, theme surface/card/border와 CTA/danger token을 사용하도록 정리했다. 정보량이 많은 회원 수·이름 변경·사용 중 삭제 안내를 안전하게 표시하므로 현 단계에서는 별도 page가 AIFC/compact BottomSheet보다 적합하다고 판단해 navigation 구조를 유지했다. 태그 관리는 기존 AIFC BottomSheet 구조와 theme token을 유지했다.
- 자동 검증: 관련 Flutter 130개, 전체 Flutter 4 shard `175 + 164 + 159 + 160 = 658`개, taxonomy Emulator 25개, managed-member Emulator 62개 통과. 변경 범위 analyze는 error 0(기존 warning/info 포함 294 issues), `git diff --check` 통과, DEV Debug APK 빌드 통과.
- Galaxy DEV: `R3CX40M6EEM`의 `com.example.mtf_app.dev`만 데이터 보존 업데이트했다. 회원관리에서 독립 상태 entry와 count `휴면 0/만료 0`, taxonomy 한 줄 strip, 고정 관리 톱니바퀴를 확인했다. 그룹 page light theme의 생성·이름 변경·삭제와 Amateur 태그 관리 탭의 중앙 Semi-Pro gate를 확인했고 생성한 테스트 그룹은 삭제했다. 최종 저장 theme은 `light`이다.
- 실기기 미확정: 상태+그룹+태그+검색 실제 AND fixture는 기존 Amateur 회원 한도에서 canonical `createManagedMember`가 `failed-precondition`으로 세 번 동일하게 차단되어 추가 재시도를 중단했다. fixture 회원은 생성되지 않았고 테스트 그룹도 cleanup했다. 해당 AND 조합과 dark/lululala 렌더는 자동 widget test로 통과했지만 이번 clean 구간의 실데이터 화면으로는 확인하지 않았으므로 실기기 통과로 기록하지 않는다.
- 최종 정상 DEV APK 복원 후 상태 count `0/0`, 테스트 그룹·테스트 회원 미존재, theme `light`를 확인했다. clean 로그의 unexpected permission-denied, unknown_fields, INVALID_ARGUMENT, unhandled/fatal exception, ANR, RenderFlex/BOTTOM overflow, PROD marker는 0건이다. PROD 작업, Firebase 배포, Functions/Rules/indexes/Storage/Hosting 변경, commit, push는 모두 0건이다.

## 2026-08-12 Personal taxonomy 통합 한 줄 필터

- UI 변경: 별도 `[전체 회원][휴면][만료]` 상태 행과 그 아래 여백을 제거했다. Personal 회원관리 pinned filter 높이는 `209px`에서 `174px`로 복원하고, 기존 고정 분류 관리 톱니바퀴 뒤의 단일 `32px` horizontal strip에 그룹·태그·`전체`·`휴면`·`만료`를 순서대로 배치했다.
- 내부 타입은 `default/custom group`, `tag`, `all`, `statusDormant`, `statusExpired`로 분리했다. 휴면·만료는 `personalGroupId`/`personalTagIds`나 pseudo group으로 취급하지 않고 기존 `PersonalMemberStatusFilter`와 `managementState/memberStatus` 판정을 그대로 사용한다. membership 종료일 경고 정책도 변경하지 않았다.
- 선택 semantics: 그룹 0~1개, 태그 기존 단일 필터, 상태 0~1개를 같은 row에서 독립 선택하며 기존 deterministic AND를 유지한다. 상태 chip 선택은 기존 그룹·태그를 초기화하지 않는다. `[전체]`는 그룹·태그·상태만 초기화하고 검색어는 유지하며, 세 축이 모두 비어 있을 때만 selected로 표시된다.
- 시각: 모든 chip 높이와 radius는 동일하다. 태그는 기존 secondary container, 휴면은 theme surface variant, 만료는 theme error container를 사용하며 새 hardcoded 색상은 추가하지 않았다. empty-state 예시 group/tag는 계속 안내용이며 `전체/휴면/만료`는 실제 control이다. 20개 항목과 320/360/384/411dp에서 높이 `32px`, 한 줄 수평 스크롤, gear 고정, overflow 0을 3테마 widget test로 확인했다.
- 자동 검증: 관련 Flutter 126개와 최종 통합 위젯 26개 통과. 전체 Flutter 4 shard `178 + 162 + 159 + 160 = 659`개 통과. taxonomy Emulator 25개, managed-member Emulator 62개 통과. 변경 범위 analyze error 0(기존 warning/info 36 issues), `git diff --check` 통과, DEV Debug APK 빌드 통과.
- Galaxy DEV: `R3CX40M6EEM`의 `com.example.mtf_app.dev`만 `adb install -r`로 데이터 보존 업데이트했다. 실제 회원관리에서 고정 gear `[60,1039][180,1159]`와 taxonomy `HorizontalScrollView [210,1039][1380,1159]`가 같은 단일 Y 구간에 있음을 확인했다. 이전 별도 상태 행은 사라졌고, 스크롤 끝에서 `전체/휴면 0/만료 0`이 동일 Y 구간에 노출되는 것은 첫 설치 직후 한 차례 확인했다. 이후 반복 swipe 자동화가 끝 위치를 재현하지 못해 실제 상태 chip 선택·AND·전체 reset은 widget/logic test 결과로만 확정하며 실기기 선택 결과로 과장하지 않는다.
- 실기기 저장 theme은 `light`이고 최종 DEV PID clean 로그의 permission-denied, unknown_fields, INVALID_ARGUMENT, unhandled/fatal exception, ANR, RenderFlex/BOTTOM overflow, PROD marker는 0건이다. fixture 및 Firestore write는 0건이며 기존 실회원은 수정하지 않았다. PROD 작업, Firebase 배포, Functions/Rules/indexes/Storage/Hosting 변경, commit, push는 모두 0건이다.
## 2026-08-13 Personal taxonomy PROD 전 최종 UI polish

- 원인/수정: 그룹 관리 화면이 Flutter 기본 `AppBar`를 사용해 홈·회원관리의 브랜드 헤더와 분리돼 보였고, taxonomy strip은 light 테마에서 선택된 group과 tag가 같은 강조색으로 보여 역할 구분이 약했다. `PersonalMemberTaxonomyManagementPage`에 기존 헤더 gradient/token을 사용하는 전용 브랜드 헤더를 적용하고, 뒤로가기 42px·아이콘 24px·제목 20px/900·하단 radius 30을 유지했다. Galaxy dark 실검증에서 `onPrimary`가 navy로 계산되어 제목 대비가 낮은 결함을 발견해 기존 중앙 `AppColors.lightSurface` 전경으로 최소 보정했다.
- 그룹 관리 본문/CTA: 기존 canonical stream, 기본/custom group 카드, 회원 수, 이름 변경·삭제 dialog와 navigation은 변경하지 않았다. 본문은 기존 theme surface/card/border를 유지하고 `새 그룹 만들기` CTA는 기존 `gradeSheetAccent`, 최소 높이 48px, 아이콘 20px을 사용한다. 새 hardcoded 색상·schema·동작은 추가하지 않았다.
- taxonomy strip: 기존 `gear → group → tag → 전체 → 휴면 → 만료` 순서, 32px 높이, horizontal scroll, AND/reset semantics를 유지했다. 선택 상태는 fill+1.4px border+900 weight로 색상 외 구분을 추가했고 group은 약한 accent blend/outline, tag는 secondary container, 전체는 primary, 휴면은 neutral surface, 만료는 error token을 사용한다. gear semantics는 실제로 그룹/태그 선택 메뉴를 여는 동작과 일치하는 `분류 관리`를 유지했다.
- 자동 검증: 관련 Flutter 50개 통과. 전체 Flutter 4 shard는 `174 + 175 + 160 + 154 = 663`개 통과. taxonomy Emulator 25개, managed-member Emulator 62개 통과. 변경 범위 `flutter analyze` issue 0, `git diff --check` 통과. 최신 DEV Debug APK `build/app/outputs/flutter-apk/app-dev-debug.apk` 빌드 및 `adb install -r` 성공, version/dataDir/firstInstallTime 유지로 데이터 보존을 확인했다.
- 폭 검증: widget test에서 320/360/384/411dp의 header 174px, strip 32px, gear 고정, horizontal scroll, group/tag/status 동시 selected와 overflow 0을 확인했다. 실제 Galaxy는 SM-S926N 폭에서 확인했으며 320/360/384/411dp 각각을 실기기 viewport로 재현하지는 않았다.
- Galaxy DEV light/dark/lululala: 그룹 관리 헤더·기본 그룹 카드·회원 수·CTA를 세 테마에서 확인했다. 최초 dark 캡처에서 발견한 헤더 전경 대비를 수정 후 재설치하여 흰 제목/뒤로가기, dark card, yellow CTA를 재확인했다. lululala에서는 purple gradient/CTA와 white card가 충돌하지 않았고 default Flutter blue, 고정 navy/yellow 잔존, overflow를 발견하지 않았다.
- 태그 관리 AIFC sheet: 실제 Galaxy DEV에서 light/dark/lululala의 drag handle, FC avatar, assistant bubble, empty state, CTA, close, 대비를 확인했다. light에서 `새 태그 만들기` 입력 시트를 저장 없이 열어 입력 focus와 키보드 표시, 내부 bounds와 취소 동작을 확인했다. custom tag가 0이고 실회원/fixture write를 금지했으므로 rename/delete/used-tag confirmation의 실제 데이터 화면은 이번 구간에서 만들지 않았으며, 기존 AIFC 공통 component 계약·Flutter/Emulator 통과 결과로만 확인했다.
- 상태+taxonomy: 실제 DEV 화면에서 단일 32px strip과 fixed gear, 역할별 비선택 표현을 확인했다. custom tag/status fixture를 만들지 않아 group+tag+expired 동시 선택은 실데이터로 확인하지 않았고 widget test의 동시 selected/AND 결과로만 확정했다. UI polish는 status 판정, membership warning, CRUD/assignment/delete cleanup, quick register/recent/search/membership/D-DAY 로직을 변경하지 않았다.
- 원복/안전: 검증 중 서버 write와 fixture 문서 생성은 0건이다. 임시 local Semi-Pro fixture를 `서버 실제 등급`으로 해제하고 앱 재시작 후 해당 선택을 확인했다. 저장값은 theme `light`, widget `brandLight`로 확인했다. 회원관리 UI의 현재 활성 회원 표시는 2명이었으며 서버 전체 회원·일정·레슨일지 count는 이번 read-only UI polish 구간에서 별도 서버 probe로 재조회하지 않아 추측 기록하지 않는다. 최종 DEV PID clean 로그에서 permission-denied, unknown_fields, INVALID_ARGUMENT, unhandled/fatal exception, ANR, RenderFlex/BOTTOM overflow, PROD marker는 모두 0건이었다.
- 증적: `artifacts/personal_taxonomy_ui_polish_20260813/`에 개인정보 없는 그룹 관리 3테마와 태그 관리 3테마 crop을 보존했다. PROD package/Firebase, Firebase 배포, Functions/Rules/indexes/Storage/Hosting, schema, commit/push 작업은 모두 0건이다.


## 2026-08-16 Personal taxonomy Phase 3 PROD 저장·삭제 검증

- 생성 저장 결함 수정: Amateur 빠른등록 payload가 빈 `personalTagIds: []`까지 전송해 서버가 태그 assignment 요청으로 판정하고 `semi_pro_required`로 거부하던 원인을 확인했다. `PersonalMemberAssignmentPatch.forCreate`가 빈 태그 배열을 생략하고 실제 태그가 있을 때만 정규화해 전송하도록 최소 수정했다.
- 자동 검증: taxonomy 관련 Flutter 17개, 고객카드/저장 관련 Flutter 38개, 전체 Flutter 4 shard `180 + 163 + 159 + 161 = 663`개, taxonomy Emulator 25개, managed-member Emulator 62개, Functions ESLint/TypeScript build를 통과했다. 변경 범위 analyze error 0(기존 warning/info 258건), `git diff --check` 통과다.
- PROD APK: `1.0.4 (11)` PROD release APK를 기존 설치 인증서와 일치하는 서명으로 빌드하고 `adb install -r`로 데이터 보존 업데이트했다. package는 `com.example.mtf_app`, Firebase project marker는 `more-than-fitness-f6adb`, debuggable은 false이며 DEV package와 기존 PROD 앱 데이터는 유지됐다.
- 빠른등록/저장: 개인정보가 아닌 `P3MEMBER` fixture 1건 생성이 성공했고 Function HTTP 200, canonical readback, 회원관리 즉시 표시를 확인했다. fixture 고객카드에서 `P3GROUP`을 선택한 뒤 `수정 저장`했고 `updateManagedMember` HTTP 200 및 회원관리 카드의 동일 그룹 표시를 확인했다.
- populated group 삭제: 그룹 관리에서 `P3GROUP · 1명`과 `회원 1명이 기본 그룹으로 이동` 안내를 확인한 뒤 삭제했다. group document가 제거되고 fixture가 `MORE THAN GYM` fallback으로 즉시 이동했으며 최종 custom group/tag는 각각 0건이다.
- 삭제 blocker: 고객카드의 canonical 삭제 UI는 `transitionManagedMemberState`를 호출해 HTTP 200을 받았으나 PROD 배포본은 `managementState=deleted`만 기록하고 현재 클라이언트가 검증하는 `isDeleted`, `deleteStatus`, `deletedSource` canonical marker를 기록하지 않았다. 그 결과 `PersonalMemberCardSaveService.deleteAndVerify`의 server readback이 실패하고 회원관리의 `isDeleted == true` 필터에도 걸리지 않아 삭제된 fixture가 계속 표시됐다. 로컬 `functions/src/managed_members.ts`에는 필요한 marker write가 이미 있으므로 제품 코드 추가 수정이 아니라 PROD `transitionManagedMemberState` 선택 배포 불일치가 원인이다.
- fixture 정리: 승인된 PROD fixture 정리 범위에서 정확히 한 건의 `P3MEMBER` deleted-state 문서만 owner/workspace/name 조건과 update-time precondition으로 제거했다. 정리 후 readback은 owner member 2, active member 2, schedule 236, training log 0, personal group 0, personal tag 0, tier `Amateur`, managed count 2, 기본 그룹 `MORE THAN GYM`이며 기존 실회원은 수정하지 않았다.
- 안전/보호: 검증 구간의 callable은 모두 PROD `asia-northeast3`에서 처리됐고 unexpected permission-denied, INVALID_ARGUMENT, unknown_fields, fatal crash, ANR, overflow는 확인되지 않았다. App Check invalid 경고는 enforcement 비활성 상태의 예상 경고로 분리했다. 이번 구간에서 Firebase 추가 배포, Rules/indexes/Storage/Hosting 변경, Play 작업, commit, push는 0건이다.
- 판정: 빠른등록과 그룹 assignment/populated delete는 통과했다. 회원 canonical 삭제는 PROD `transitionManagedMemberState` 배포본의 계약 불일치 때문에 미통과이므로 Phase 3 완료로 처리하지 않는다. 필요한 다음 작업은 해당 함수 1개만 PROD 선택 배포한 뒤 fixture 1건으로 삭제 readback과 목록 제거를 재검증하는 것이다.

## 2026-08-16 Personal taxonomy Phase 3 PROD 삭제 blocker 해소

- 배포 전 감사: 로컬 `transitionManagedMemberState`는 `deleted` 진입 시 `managementState=deleted`, `isDeleted=true`, `deletedAt`, 7일 뒤 `deleteScheduledAt`, `deleteStatus=pending_delete`, `deletedSource=managed_member_function`을 transaction으로 기록한다. deleted 상태에서 복원하면 위 deletion marker를 모두 제거한다. 클라이언트는 이 marker readback을 완료해야 삭제 성공으로 처리하고 회원관리 목록은 `isDeleted=true`를 제외한다.
- 사전 검증: Functions ESLint와 TypeScript build 통과. 관련 Flutter 38개, managed-member Emulator 최신 62개, taxonomy Emulator 25개, `git diff --check`를 통과했다. Emulator의 owner canonical delete marker 및 다른 owner 거부 시나리오도 통과했다.
- PROD 선택 배포: `firebase deploy --project more-than-fitness-f6adb --only functions:transitionManagedMemberState`를 실행했다. 배포 대상은 `transitionManagedMemberState` 1개뿐이며 `asia-northeast3`, Node.js 22, state `ACTIVE`를 별도 조회했다. Cloud Functions audit update 완료 시각은 `2026-08-16T08:22:11Z`이고 새 source bundle/hash가 반영됐다. CLI exit code는 0이며 cleanup policy 경고는 없었다.
- 실기기 fixture: Galaxy `R3CX40M6EEM`의 PROD `com.example.mtf_app`에서 개인정보가 아닌 `P3DELETE` fixture 1건을 canonical `createManagedMember` 경로로 생성했다. server readback에서 active member count가 2에서 3으로 증가했고 tier `Amateur`, schedule 236, training log 0, personal group/tag 0을 확인했다. 기존 실회원 2명은 수정하지 않았다.
- canonical 삭제: fixture 고객카드의 삭제 확인 UI에서 `transitionManagedMemberState`를 호출했고 함수는 HTTP 200으로 완료됐다. server readback에서 `managementState=deleted`, `isDeleted=true`, `deleteStatus=pending_delete`, `deletedSource=managed_member_function`, `deletedAt`, `deleteScheduledAt`이 모두 확인됐다. active member count는 2로 복원됐고 회원관리 UI도 즉시 `총 2명`으로 갱신됐다.
- fixture cleanup: 최신 marker와 owner/workspace/fixture 조건을 확인한 뒤 해당 deleted fixture 문서 한 건만 update-time precondition으로 물리 정리했다. fixture 이름 검색 결과는 0건이며 기존 일정 236, training log 0, group/tag 0, tier Amateur, managed member count 2를 유지했다. 기본 그룹은 profile field 미지정 상태의 canonical fallback `MORE THAN GYM`을 유지한다.
- 안전/보호: 최종 PROD PID clean 구간의 unexpected permission-denied, unknown_fields, INVALID_ARGUMENT, failed-precondition, unhandled/fatal exception, ANR, RenderFlex/BOTTOM overflow, DEV marker는 0건이다. App Check invalid 경고는 enforcement 비활성 상태의 기존 예상 경고로 구분했고 auth verification은 VALID였다. session과 PROD package는 유지됐다.
- 범위: 다른 Functions, Rules, indexes, Storage, Hosting, client APK, migration, Play Store, commit, push 작업은 0건이다. Phase 3 Personal taxonomy PROD 반영은 삭제 blocker까지 해소되어 최종 완료로 판정한다.
## 2026-08-16 일정 형태 변경 후 저장 실패 회귀 수정
- 재현: Galaxy `R3CX40M6EEM`의 DEV `com.example.mtf_app.dev`에서 기존 일정의 형태를 변경한 뒤 동일 요일·시간으로 저장할 때 `PERMISSION_DENIED`가 발생했다. 실패 batch는 정상 target write와 함께 존재하지 않는 `schedules/{ownerUid}--` 삭제를 포함했고 전체 commit이 롤백됐다.
- 원인: `homeScheduleScopedDocumentId('', ownerUid)`가 빈 source를 그대로 유지하지 않고 `${ownerUid}--`로 바꿨다. 동일 슬롯 편집은 삭제할 source가 없는데도 이 malformed ID가 delete 목록에 들어간 것이 직접 원인이며, 일정 형태별 stale field나 Functions validation 문제는 아니었다.
- 수정: `lib/services/home_schedule_firestore_service.dart`의 공통 owner-scoped document ID helper가 trim 결과가 비어 있으면 즉시 빈 문자열을 반환하도록 최소 수정했다. 일정 편집·이동·충돌·member linkage·AIFC 정책과 Firestore schema는 변경하지 않았다.
- 회귀 테스트: `test/home_schedule_move_plan_test.dart`에 빈 source owner-prefix 방지와 PT/일정/교육 same-type 및 상호 type transition, 그룹레슨 전환의 동일 슬롯 update matrix를 추가했다. 관련 Flutter 78개, 전체 Flutter 4 shard `192 + 163 + 159 + 161 = 675`개, Personal schedule Rules Emulator 27개가 통과했다.
- 정적 검증: 변경 범위 `flutter analyze` issue 0, `git diff --check` 통과, DEV Debug APK `build/app/outputs/flutter-apk/app-dev-debug.apk` 빌드 통과. Functions/Rules 변경 및 Firebase 배포는 0건이다.
- Galaxy DEV: 데이터 보존 `adb install -r` 성공, `versionName 1.0.4-dev`, `versionCode 9 -> 11`, `dataDir`과 `firstInstallTime` 유지. 기존 PT -> 일정 -> 교육 -> PT 형태 전환은 동일 document ID, `branch=update`, delete 0/write 1, server verify 성공으로 통과했다. 형태+시간 변경은 기존 canonical move 경로로 source 삭제와 target 1건 생성이 확인됐고, 형태+요일 변경도 single-day move에서 source 부재와 target 1건을 서버 확인했다. 중복 일정은 생성되지 않았다.
- 영향 확인: 기존 편집 시 AIFC 추천업무가 유지됐고 신규 일정 시트에는 표시되지 않았다. 검증 fixture에는 회원 연결이 없어 회원 데이터 mutation은 0건이다. optional member/phone/memo/session 필드의 기존 delete normalization은 그대로 유지됐다.
- 원복: 검증 일정 2건을 canonical delete하고 각각 server `exists=false`를 확인했다. 일정 stream은 검증 전 baseline 11건으로 복원됐다. 검증 중 만든 로컬 레슨 형태 `EVENT`, `EDU`도 기존 편집 UI로 제거했다.
- 최종 안전 구간: DEV 재시작 후 top resumed activity는 DEV MainActivity였고 schedule cache count 11이었다. `permission-denied`, `FATAL EXCEPTION`, ANR, RenderFlex/BOTTOM overflow, PROD project marker는 0건이었다. 최초 재현 구간의 예상 `PERMISSION_DENIED` 1건은 원인 확정 증적으로만 보존했다.
- 미작업: PROD APK/앱/Firebase, Firebase 배포, commit, push는 모두 0건이다. PROD 반영은 별도 승인 전 시작하지 않는다.
- 후속 확인: 문서 기록 뒤 단일 테스트를 재확인하려 했으나 `flutter test` 2회와 `flutter --version` 1회가 모두 테스트 본문 출력 전 CLI 기동 단계에서 timeout됐다. 잔류 Flutter/Dart 프로세스와 Pub cache lock은 없었고 제품 코드는 추가 변경하지 않았다. 따라서 자동 검증 판정은 이 작업 중 앞서 정상 완료된 관련 78개·전체 675개·Emulator 27개 결과를 유지하며, timeout을 테스트 실패로 오인하지 않는다.

## 2026-08-16 일정 형태 변경 저장 hotfix PROD 반영
- 코드 확인: `homeScheduleScopedDocumentId`는 빈 source ID를 빈 문자열로 유지하고 정상 ID에만 기존 owner scope를 적용한다. 관련 matrix는 same-type, PT/일정/교육 상호 전환, 형태+시간, 형태+요일을 포함한다. Functions/Rules/schema 변경은 없다.
- 자동 검증: 관련 Flutter 78개, 전체 Flutter 4 shard `177 + 178 + 163 + 157 = 675`개, Personal schedule Emulator 27개, 변경 범위 analyze issue 0, 전체 analyze error 0(기존 warning 239/info 927), `git diff --check`를 통과했다.
- PROD 산출물: `pubspec.yaml`을 `1.0.4+12`로 올리고 `build/app/outputs/flutter-apk/app-prod-release.apk`를 생성했다. package는 `com.example.mtf_app`, targetSdk 36, release non-debuggable, Firebase project는 PROD이며 DEV marker는 없었다. 설치 전 PROD는 `1.0.4 (11)`이었다.
- 서명/설치: 설치 전 APK와 새 APK를 `apksigner verify --print-certs`로 비교해 인증서가 일치함을 확인했다. 둘 다 기존 Android Debug 인증서다. `adb install -r`가 성공했고 `1.0.4 (12)`로 갱신됐다. UID, dataDir, firstInstallTime, Auth session, DEV package는 유지됐다. uninstall/clear/logout은 실행하지 않았다.
- PROD 일정 검증: 개인정보 없는 fixture 일정 1건으로 PT -> 일정 -> 교육 -> PT를 반복 저장했고 매 단계 재진입에서 형태를 확인했다. 형태+시간은 일요일 10:00에서 11:00으로, 형태+요일은 일요일에서 토요일로 이동했으며 각각 카드 1건만 유지됐다. 동일 형태 메모 `HOTFIXMEMO`도 저장 후 재진입 readback됐다. generic save error, `PERMISSION_DENIED`, 중복 카드는 발생하지 않았다.
- 기존 기능 회귀: 기존 일정 편집 시 AIFC 추천업무, 최근 등록 회원, 회원 연결, 레슨계약서, 회원권계약서가 유지됐다. fixture에는 회원을 연결하지 않아 회원 mutation은 없었다. release 런타임에서는 민감한 schedule document ID를 로그로 남기지 않으므로 동일 ID의 직접 원문 비교 대신 DEV server verify와 PROD 단일 카드/재진입 결과를 구분해 판정했다.
- 추가 release blocker: 검증 종료 후 PROD를 재시작하자 `ScheduledNotificationBootReceiver`가 Gson `TypeToken` generic signature 유실로 crash했다. 설치된 `flutter_local_notifications 17.2.4`의 공식 release 예제와 대조해 `android/app/proguard-rules.pro`에 `Signature`, annotation, Gson adapter와 `TypeToken` 보존 규칙만 추가했다. 재빌드·동일 서명 `adb install -r` 후 PROD MainActivity가 foreground에서 유지됐고 receiver crash 및 `TypeToken` 오류는 0건이었다.
- cleanup/baseline: fixture 일정은 편집 시트의 canonical 삭제로 제거했고 최종 화면에서 fixture 이름·메모·카드가 모두 0건임을 확인했다. 기존 회원 진행값 `4 / 30`, 기존 주간 스케줄 화면, light theme, Auth session은 유지됐다. 전체 schedule/training-log 총량은 이번 client-only 실검증에서 별도 PROD 서버 probe를 실행하지 않아 추정 기록하지 않는다.
- 최종 안전 로그: fixture 검증 구간의 permission-denied, INVALID_ARGUMENT, unknown_fields, generic save error, fatal crash, ANR, RenderFlex/BOTTOM overflow, DEV project marker는 0건이었다. R8 수정 후 clean 재시작 구간도 동일 패턴과 notification receiver crash가 모두 0건이었다.
- 미작업: Firebase Functions/Rules/indexes/Storage/Hosting 배포, migration, 기존 일정 임의 수정, Play Store, commit, push는 모두 0건이다. 일정 형태 변경 저장 hotfix의 PROD 반영은 완료로 판정한다.

## 2026-08-19 DEV 앱 부팅·홈 Drawer 체감속도 개선

- 병목 확인: Galaxy DEV cold 로그에서 복원된 anonymous 계정도 홈 전에 `bootstrapAnonymousBeginnerProfile -> reconcilePersonalTier -> trainer_profiles server read`를 직렬 실행했다. 한 기준 로그에서 이 구간은 약 1.62초였다. Drawer tap에는 network/await가 없었지만 500ms neon 애니메이션의 `AnimatedBuilder`가 profile/banner/menu/LIVE 본문 전체를 매 frame 재빌드했다.
- startup 수정: 기존 anonymous profile은 먼저 server read하고 `profileNotFound`일 때만 bootstrap하도록 변경했다. tier reconcile은 안전한 routing/profile 확인 뒤 첫 frame callback의 best-effort 작업으로 이동했다. 위젯 interactivity 등록, Home app-start widget sync, notification/timezone 초기화도 첫 frame 이후로 이동했다. Firebase project/Auth/workspace/profile owner 검증과 scheduler snapshot 정책은 유지했다.
- Drawer 수정: 본문을 `AnimatedBuilder.child`로 고정해 neon frame마다 재빌드하지 않게 했고 장식 애니메이션은 제거하지 않은 채 500ms에서 300ms로 단축했다. 회원권계약서 제목과 gate/navigation은 유지하고 설명만 정확히 `회원권 계약서 작성 및 운영 지원`으로 변경했다.
- 자동 검증: 관련 startup/account/Drawer/widget 테스트 46개와 최종 관련 테스트 36개가 통과했다. 전체 Flutter는 최종 680개 통과. 전체 analyze는 error 0, 기존 warning 239/info 927이며 변경 범위도 신규 error 0이다. `git diff --check`와 DEV Debug APK 빌드가 통과했다.
- Galaxy DEV 설치: `R3CX40M6EEM`의 `com.example.mtf_app.dev`만 `adb install -r`로 갱신했다. package UID와 firstInstallTime이 유지돼 앱 데이터/Auth session 보존을 확인했다. PROD package는 조작하지 않았다.
- 성능 측정: 동일 adb marker 기준 cold start 5회는 변경 전 min/avg/max `2486/3103/3855ms`, 최종 `2804/2982/3283ms`였다. 평균 3.9%, 최악값 14.8% 개선됐고 최소값은 네트워크·debug JIT 변동으로 12.8% 느렸다. Auth 준비 시작부터 canonical Home 결정까지의 대표 로그는 약 `1618ms -> 1005ms`로 줄었으며 최종 로그는 Home 결정 후 tier reconcile이 실행됨을 확인했다.
- warm 측정: 변경 전 5회 `207/220/260ms`, 최종 안정화 10회 `224/244/282ms`로 수치 개선은 확인되지 않았다. 이번 변경은 resume 경로를 수정하지 않았고 24ms 평균 차이는 adb/device scheduling 변동 범위로 기록하되 개선으로 처리하지 않는다.
- Hamburger 측정: 기기 screencap 1회 비용이 실제 Drawer 전환보다 길어 tap-to-first-frame의 신뢰 가능한 min/avg/max ms는 확보하지 못했다. 대신 실제 Galaxy에서 즉시 열린 메뉴, 반복 open/close, 정확한 문구를 hierarchy/screenshot으로 확인했고, deterministic animation 완료 시간은 `500ms -> 300ms`(40% 단축), 애니메이션 중 전체 본문 build는 매 frame에서 1회로 감소했다.
- 기능 회귀: Home scheduler, 고객리스트, 회원권계약서 Amateur gate, background/resume를 Galaxy DEV에서 확인했다. 최종 DEV PID clean 구간의 permission-denied, unhandled/fatal exception, ANR, RenderFlex/BOTTOM overflow, PROD project marker는 0건이다. Firebase/schema/Functions/Rules/indexes/Storage/Hosting, PROD, commit, push 작업은 모두 0건이다.
- 증적: `artifacts/startup_drawer_perf_20260819/`에 before/final cold·warm CSV, analyze 결과, 최종 Home/Drawer/gate/member hierarchy와 Drawer screenshot을 보존했다. PROD 반영은 별도 승인 전 시작하지 않는다.

## 2026-08-19 앱 부팅·홈 Drawer 성능 개선 PROD 반영

- 변경 감사: PROD 반영 대상은 `lib/main.dart`, `lib/pages/account_gate.dart`, `lib/pages/home_page.dart`, `lib/widgets/mtf_animated_drawer.dart`의 startup/deferred 초기화와 Drawer rebuild/300ms 최적화, 회원권계약서 설명 변경이며 서버 계약·Firebase 리소스 변경은 필요하지 않았다. 작업 전 저장소의 다수 기존 변경은 유지했고 이번 단계에서는 `pubspec.yaml`의 versionCode만 `12 -> 13`으로 올렸다.
- 자동 검증: startup/account/Drawer 관련 Flutter 36개가 통과했다. 전체 Flutter 4 shard는 `179 + 179 + 163 + 159 = 680`개가 통과했다. 최초 병렬 shard 4는 자원 경합으로 `dev_prod_personal_isolation_test.dart`에서 진행이 멈췄지만 해당 파일 단독 4개와 shard 4 순차 재실행 159개가 모두 통과해 제품 hang이 아님을 확인했다. 변경 범위 analyze는 error 0이고 기존 warning/info 97건만 유지됐으며 `git diff --check`가 통과했다. 서버 변경이 없어 Firebase Emulator는 생략했다.
- Release 산출물: `build/app/outputs/flutter-apk/app-prod-release.apk`를 prod flavor와 `lib/main_prod.dart`로 빌드했다. package `com.example.mtf_app`, app name `모어댄`, `1.0.4 (13)`, min/target SDK 24/36, non-debuggable, PROD Firebase `more-than-fitness-f6adb`, DEV marker 0을 확인했다. R8 설정에는 Gson `TypeToken`과 `Signature` keep rule이 유지된다.
- 서명/설치: 기존 설치 APK와 새 APK의 signing SHA-256 fingerprint가 정확히 일치했다. Gradle release는 기존 debug signing slot을 유지하지만 인증서 subject는 기본 `CN=Android Debug`가 아니며 signing migration은 하지 않았다. `adb install -r` 후 `1.0.4 (12) -> 1.0.4 (13)`, user 0 app UID, user 0/95 dataDir, `firstInstallTime=2025-11-18 17:47:53`, Auth session과 DEV package가 유지됐다. uninstall, `pm clear`, logout은 실행하지 않았다.
- PROD Release 성능: process force-stop 후 `personalWorkspace success`까지 5회 min/avg/max는 `808/909.6/967ms`였고 Android Activity first-frame TotalTime 범위는 `226~296ms`였다. DEV debug 수치와는 조건이 달라 직접 개선율을 계산하지 않았다. background/resume 10회 host min/avg/max는 `238/263.4/374ms`, Android TotalTime 평균은 `83.1ms`였다. 설치 전 PROD 동일 측정 baseline이 없어 warm 개선으로 판정하지 않으며 374ms outlier도 숨기지 않는다.
- Drawer 실검증: 반복 open/close, 코드상 300ms animation, tap 경로 blocking await 0, `AnimatedBuilder.child` 본문 1회 build 구조를 확인했다. `gfxinfo`는 Flutter surface 4 frame만 수집해 50/90 percentile `23/27ms`로 표본이 부족하므로 전체 jank 0의 정량 근거로 사용하지 않았다. 실제 light/dark/lululala 화면에서 Drawer가 정상 표시되고 닫힘·재열림·overflow 0을 확인한 뒤 light로 복원했다.
- 문구/기능: Drawer 제목 `회원권계약서`, 설명 `회원권 계약서 작성 및 운영 지원`을 hierarchy와 screenshot으로 확인했고 이전 `회원권 기간, 정지/연장...` 장문은 0건이었다. 회원권계약서와 레슨계약서 모두 현재 Amateur의 중앙 Semi-Pro gate를 유지하고 작성 화면에 잘못 진입하지 않았다. Home, 회원관리, taxonomy strip, 기존 일정 편집 진입, AIFC, 설정을 read-only로 확인했다.
- deferred/restart: 최종 clean restart에서 profile read와 personal workspace 성공 marker가 각각 1회, app widget update marker 14회였고 Home·스케줄러가 정상 표시됐다. notification/receiver, startup, R8/Gson 경로의 crash·blank/stuck loading은 없었다. 현재 회원 표시 4명과 기존 일정 화면은 유지됐지만 전체 schedule/training-log 총량은 별도 PROD 서버 probe를 실행하지 않아 추정 기록하지 않는다.
- 안전/범위: 최종 PROD PID clean 구간에서 permission-denied, unknown_fields, INVALID_ARGUMENT, unexpected failed-precondition, unhandled/fatal exception, ANR, RenderFlex/BOTTOM overflow, DEV marker, receiver crash가 모두 0건이었다. Firebase Functions/Rules/indexes/Storage/Hosting, migration, Play Store/Internal Testing, commit, push는 모두 0건이다. PROD startup + Drawer client hotfix 반영은 완료했고 다음 단계는 별도 승인에 따른 Play Store 출시 준비다.

## 2026-08-19 Home Drawer 주요 기능 설명 통일

- 변경: 햄버거 Drawer의 고객카드, 레슨계약서, 인사이트 설명을 회원권계약서와 같은 고정형 운영 문구로 통일했다. 최종 문구는 `회원 정보 확인 및 관리 지원`, `레슨 계약서 작성 및 운영 지원`, `레슨 및 회원 운영 분석 지원`이다.
- 범위: 세 메뉴의 제목, 아이콘, 순서, `onTap` 콜백과 Home의 중앙 feature gate/navigation은 변경하지 않았다. Drawer 내부에서 등급에 따라 부제목만 바꾸던 helper는 더 이상 사용하지 않아 제거했다.
- 검증: Drawer 관련 Flutter 5개, 전체 Flutter 4개 순차 shard, 변경 범위 analyze를 통과했다. analyze에는 기존 Drawer warning/info 34건만 유지되고 이번 변경의 신규 오류·경고는 0건이다. `git diff --check`와 DEV Debug APK(`build/app/outputs/flutter-apk/app-dev-debug.apk`) 빌드도 통과했다.
- 미작업: 실기기 설치, PROD 앱/Firebase, Functions/Rules/indexes/Storage/Hosting, commit, push는 모두 0건이다.

## 2026-08-19 Play Store 사전점검 1 — 최신 DEV 변경의 PROD source 포함 감사

- entrypoint: `main_dev.dart`와 `main_prod.dart`는 모두 공통 `main.dart`의 `runMtfApp`을 호출하고 각각 `AppEnvironment.dev/prod`만 전달한다. startup/profile bootstrap, first-frame defer, Home, Drawer, schedule hotfix, 회원관리/taxonomy UI는 공통 Flutter source이므로 PROD build graph에도 동일하게 포함된다.
- 환경 분리: PROD는 package `com.example.mtf_app`, Firebase `more-than-fitness-f6adb`, 앱 이름 `모어댄`, DEV badge 비활성이다. DEV와 다른 부분은 entrypoint 환경값, package suffix, Firebase options, 앱 이름/DEV badge와 debug fixture뿐이며 최근 client 기능의 DEV-only 분기는 발견되지 않았다.
- 최신 기능 포함: Drawer 300ms와 `AnimatedBuilder.child`, 네 가지 최신 고정 설명, 빈 schedule source ID를 빈 값으로 유지하는 hotfix, unified taxonomy strip·고정 gear·그룹/태그/전체/휴면/만료 한 줄·브랜드 그룹관리 header·AIFC 태그 sheet·empty-state·상태/그룹/태그 AND filter·고객카드 horizontal tags가 공통 import graph에 연결됨을 확인했다.
- R8: `android/app/proguard-rules.pro`가 prod release build type의 `proguardFiles`에 연결되고, 실제 `build/app/outputs/mapping/prodRelease/configuration.txt`에도 `Signature`와 Gson `TypeToken` keep rule이 병합됐다.
- PROD dry-run: `flutter build apk --release --flavor prod -t lib/main_prod.dart --no-pub`가 성공해 `build/app/outputs/flutter-apk/app-prod-release.apk`를 생성했다. APK는 `com.example.mtf_app`, `1.0.4 (13)`, min/target SDK 24/36, 앱 이름 `모어댄`, non-debuggable이다. Firebase PROD project ID는 PROD options와 runtime mismatch guard에서 확인했다.
- 문자열 확인: Dart AOT `libapp.so` 직접 문자열 검색은 신·구 한글 문구가 모두 0건이라 snapshot 인코딩상 미확정으로 분류했다. 대신 공통 source/build graph와 관련 widget test로 최신 네 문구 포함 및 제품 source의 이전 장문 0건을 확인했다. 이전 문구 3건은 제품 코드가 아니라 회귀 테스트의 부정 assertion에만 남아 있다.
- 자동 검증: 관련 Flutter 170개, 전체 Flutter 4 shard `178 + 180 + 162 + 159 = 679`개, 전체 analyze error 0(기존 warning 239/info 927), `git diff --check`, PROD Release APK build를 통과했다. 서버 변경이 없어 Firebase Emulator는 생략했다.
- 출시 위험: taxonomy 핵심 UI 파일과 PROD manifest/icon 리소스 일부가 아직 untracked이므로 현재 working tree APK에는 포함되지만 release checkpoint commit에서 누락되지 않도록 명시적 allowlist 반영이 필요하다. 또한 release build는 여전히 debug signing slot을 사용하므로 Play용 signing/AAB 준비 전환이 다음 blocker다.
- 미작업: APK 설치, Firebase 배포/조회/데이터 write, Play Store/AAB 업로드, signing 변경, commit, push는 모두 0건이다.

## 2026-08-20 Play Store 출시 준비 Phase 1 — release checkpoint allowlist + upload signing

- Git 기준: 브랜치 `codex/prod-canary-checkpoint-2026-07-22`, 작업 전 HEAD `f93f808`을 유지했다. 최종 dirty 상태는 tracked modified 84개, untracked 실제 파일 100개, deleted/renamed 0개다. 임의 `git add`, commit, push는 실행하지 않았다.
- Release checkpoint allowlist는 총 134개다. 현재 tracked modified 84개는 기존 제품 코드·backend/config·회귀 테스트·`RUN_LOG.md`/`BACKLOG.md`와 이번 `android/app/build.gradle.kts` signing 변경을 모두 포함한다. untracked는 아래 제품/backend 29개와 테스트 21개만 포함한다.
- Android/브랜드 untracked allowlist 17개: `android/app/src/main/res/drawable/widget_header_brand_light.xml`, `android/app/src/prod/AndroidManifest.xml`, `android/app/src/prod/res/drawable-nodpi/prod_launcher_icon_adaptive_background.png`, `android/app/src/prod/res/drawable-nodpi/prod_launcher_icon_adaptive_foreground.png`, `android/app/src/prod/res/mipmap-anydpi-v26/ic_launcher.xml`, `android/app/src/prod/res/mipmap-anydpi-v26/ic_launcher_round.xml`, `android/app/src/prod/res/mipmap-hdpi/ic_launcher.png`, `android/app/src/prod/res/mipmap-hdpi/ic_launcher_round.png`, `android/app/src/prod/res/mipmap-mdpi/ic_launcher.png`, `android/app/src/prod/res/mipmap-mdpi/ic_launcher_round.png`, `android/app/src/prod/res/mipmap-xhdpi/ic_launcher.png`, `android/app/src/prod/res/mipmap-xhdpi/ic_launcher_round.png`, `android/app/src/prod/res/mipmap-xxhdpi/ic_launcher.png`, `android/app/src/prod/res/mipmap-xxhdpi/ic_launcher_round.png`, `android/app/src/prod/res/mipmap-xxxhdpi/ic_launcher.png`, `android/app/src/prod/res/mipmap-xxxhdpi/ic_launcher_round.png`, `assets/branding/more_than_wellness_prod_icon.png`.
- Functions/Flutter 제품 untracked allowlist 12개: `functions/src/personal_member_taxonomy.ts`, `lib/models/app_theme_mode.dart`, `lib/models/personal_member_taxonomy.dart`, `lib/pages/personal_member_taxonomy_management_page.dart`, `lib/services/member_sign_url_service.dart`, `lib/services/personal_member_taxonomy_service.dart`, `lib/widgets/aifc_personal_tag_management_chat_sheet.dart`, `lib/widgets/home/sections/home_weekly_goal_dialog.dart`, `lib/widgets/personal_member_status_filter.dart`, `lib/widgets/personal_member_taxonomy_picker.dart`, `lib/widgets/personal_tag_horizontal_strip.dart`, `lib/widgets/personal_taxonomy_filter_strip.dart`.
- 테스트 untracked allowlist 21개: `firebase-emulator-tests/personal_member_taxonomy.test.cjs`, `test/aifc_chat_sheet_failure_test.dart`, `test/app_theme_mode_test.dart`, `test/brand_theme_phase2_training_contract_test.dart`, `test/brand_theme_test.dart`, `test/customer_card_edit_bundle_regression_test.dart`, `test/home_lesson_footer_actions_test.dart`, `test/home_lesson_quick_actions_section_test.dart`, `test/home_week_paste_conflict_test.dart`, `test/home_widget_sync_controller_test.dart`, `test/member_navigation_brand_theme_test.dart`, `test/member_persistence_blockers_test.dart`, `test/member_sign_url_service_test.dart`, `test/mtf_animated_drawer_test.dart`, `test/personal_member_status_filter_test.dart`, `test/personal_member_taxonomy_picker_test.dart`, `test/personal_member_taxonomy_test.dart`, `test/personal_tag_horizontal_strip_test.dart`, `test/personal_taxonomy_filter_strip_test.dart`, `test/startup_performance_contract_test.dart`, `test/theme_residual_cleanup_test.dart`.
- 제외 untracked 50개는 release 불필요 문서/증적 15개와 로컬·임시 35개다. `README_FIRST.md`, `VALIDATION_SUMMARY.md`, 별도 audit/plan 문서 10개, icon preview 3개, `.dart_appdata/` 6개, `_ProChip`, `callable-body.json`, `mtf_codex_loop_starter.zip`, `prompts/` 25개, 중첩 0바이트 font를 제외했다. 삭제하지 않았다. 정확한 include/exclude 대조 결과는 ignored build 산출물 `build/release_audit/release_checkpoint_allowlist.txt`, `untracked_excluded.txt`에도 보존했다.
- 재현성: 모든 untracked Flutter import target, PROD manifest/resource, 일반·round·adaptive launcher icon, widget header, taxonomy Functions source, R8 rule, pubspec runtime font, Firebase PROD option/config source가 tracked 또는 위 allowlist에 포함된다. 제품 파일의 ignore 오분류는 0개이며 release checkpoint commit만 아직 생성하지 않았다.
- 기존 signing 구조는 모든 release flavor가 `signingConfigs.getByName("debug")`를 사용해 Galaxy의 기존 로컬 PROD signer와 같은 인증서로 빌드되는 구조였다. keystore password/alias를 제품 source에 하드코딩한 코드는 없었다.
- Upload signing: Android Studio JBR OpenJDK 21.0.7의 `keytool`로 RSA 2048-bit, 10,000일, alias `more_than_upload`인 upload keystore를 repo 밖 `C:\Users\morethan\.android\more_than_upload.jks`에 생성했다. 공개 upload certificate는 `C:\Users\morethan\.android\more_than_upload_certificate.pem`으로 export했다. 비밀번호와 private key는 출력·기록하지 않았다.
- Secret 관리: ignored `android/key.properties`가 외부 keystore 경로와 credentials를 보관하며 `android/.gitignore`의 `key.properties`, `**/*.jks`, `**/*.keystore` 규칙을 확인했다. 실제 PROD APK/AAB build 성공으로 file path, password, alias가 일치함을 검증했다.
- Gradle 분리: 기본 release는 `upload` signing config를 사용한다. `-PmtfLegacyLocalProdSigning=true`인 명시적 APK 작업만 기존 debug signer를 사용할 수 있고, 같은 플래그의 bundle 작업은 Gradle 단계에서 차단한다. Play AAB는 항상 upload key를 요구하며 필수 key property가 없으면 signing validation에서 실패한다. DEV debug signing/install 흐름은 변경하지 않았다. 새 Play용 APK는 기존 Galaxy PROD 위에 설치하지 않았다.
- Upload certificate fingerprint: SHA-1 `A9:17:89:30:7F:7B:30:1F:80:3F:09:63:2D:E5:E1:15:B8:DB:16:E4`, SHA-256 `C1:8B:54:44:35:D4:5A:1D:6D:A1:F5:C1:6F:E0:A5:D8:9B:32:EB:A6:54:3C:D0:9A:63:61:63:F6:C5:19:25:6E`. 기존 Galaxy/local debug signer SHA-256 `A9:22:C0:98:C2:DC:3D:70:52:89:5E:8A:D8:36:B9:5C:F0:8B:9E:12:F3:9A:CD:9E:6D:F9:D1:89:AB:B7:44:89`와 다르므로 상호 데이터 보존 덮어쓰기는 불가하다.
- Firebase SHA 영향: 현재 실제 Auth는 anonymous/email credential이며 Google 버튼 경로는 `googleSetupRequired`로 중단되고 `google_sign_in` dependency가 없다. Dynamic Links, App Check, Firebase Messaging client dependency도 제품 코드에서 발견되지 않았다. 따라서 현재 기능에 새 SHA 등록은 즉시 blocker가 아니다. Google Sign-In/App Check를 활성화할 때는 Play App Signing에서 발급되는 app-signing SHA-1/SHA-256을 Firebase/Google Console에 등록해야 하며, 이번 단계에서는 Console 변경을 하지 않았다.
- 최종 산출물은 명시적 PROD entrypoint `lib/main_prod.dart`로 빌드했다. APK `build/app/outputs/flutter-apk/app-prod-release.apk`는 SHA-256 `559018FE158D52262AB1D58F0000FF163BBF8F8C96323AFF5D51DF419BCE5049`, AAB `build/app/outputs/bundle/prodRelease/app-prod-release.aab`는 SHA-256 `E5806AD0BFD3793501698F33795F84E1D4B0443081039C1E9972BA37EC98245E`다.
- APK/AAB identity: package `com.example.mtf_app`, version `1.0.4 (13)`, min/target SDK `24/36`, 앱 이름 `모어댄`, release non-debuggable이다. AAB resources에는 PROD project marker 2개, DEV project/package marker 0개였다. 일반·round·adaptive PROD icon 전 density와 3개 widget info XML이 포함됐다.
- Manifest/R8: merged prodRelease manifest에 `MainActivity`, 주간/다음 레슨/오늘 레슨 3개 widget receiver와 provider metadata가 유지됐다. prodRelease R8 configuration에 widget receiver keep, Gson `TypeToken`, `Signature` keep rule이 포함됐다.
- Signing 검증: APK `apksigner`는 upload certificate signer 1개로 검증됐다. AAB `jarsigner -verify`는 exit 0과 `jar verified`였다. 자체 서명 upload certificate의 PKIX/timestamp warning은 Play upload key의 신뢰 체인 경고이며 서명 무결성 실패가 아니다. Gradle 캐시의 bundletool jar는 standalone 실행본이 아니어서 직접 CLI validate는 미실행했고, 성공한 AGP bundle task, AAB JAR signature, archive resource/manifest presence, merged manifest로 대체 검증했다.
- 자동 검증: 변경·신규 Flutter test 파일 25개에서 관련 회귀 289개 통과. 전체 Flutter 4 shard는 `197 + 163 + 152 + 167 = 679`개 통과. 전체 analyze는 error 0, 기존 warning 239/info 927로 이전 기준과 동일하다. `git diff --check`, PROD Release APK, PROD Release AAB가 통과했다.
- 미작업: Firebase 조회/변경/배포, Rules/indexes/Storage/Hosting, PROD 데이터 write, Galaxy 설치/실행/삭제, Play Console 앱 생성·업로드·Internal Testing, commit, push는 모두 0건이다.

## 2026-08-20 Play Store release checkpoint pre-commit 감사

- `build/release_audit/release_checkpoint_allowlist.txt`의 고유 경로 134개만 각각 `git add -- <path>`로 stage했다. staged 134개는 allowlist와 완전히 일치하며 allowlist 밖 0개, allowlist 누락 0개다. 의도적으로 제외한 untracked 50개는 stage하지 않았다.
- staged 금지 경로 감사에서 `android/key.properties`, `*.jks`, `*.keystore`, `*.pem`, `build/`, `.dart_tool/`, `artifacts/`, `.dart_appdata/`, `prompts/`, probe/telemetry가 0개였다. `android/key.properties`는 계속 ignored이며 외부 upload keystore와 공개 certificate도 Git 대상이 아니다.
- staged text secret scan에서 private key, service-account private key, password literal, API key 신규 추가는 0개였다. `build.gradle.kts`의 `storePassword`/`keyPassword` 두 항목은 secret 값이 아니라 ignored properties를 읽는 key 이름이다. 제품 source의 신규 debug fixture 추가도 0개다.
- 핵심 포함 파일은 Personal taxonomy UI/Functions, schedule partial-overlap hotfix, startup defer, Drawer 300ms/문구, R8 rules, upload signing config, PROD manifest, 일반·round·adaptive icon, 관련 Flutter/Emulator test다.
- staged `git diff --cached --check`가 통과했다. staged source와 working tree product source 사이의 내용 차이는 없으며, 전체 analyze는 error 0, 기존 warning 239/info 927이다. `flutter build appbundle --flavor prod -t lib/main_prod.dart --release --no-pub` 증분 재빌드가 통과해 upload-signed `1.0.4 (13)` AAB를 재현했다.
- signing config는 password/alias literal 0, ignored `key.properties` read, 필수 property 누락 시 release signing failure, 기본 upload signing, legacy local flag의 bundle 차단을 유지한다. checkpoint commit message는 `release: checkpoint Play Store candidate`이며 push, Firebase, Play Console, Galaxy 작업은 하지 않는다.
