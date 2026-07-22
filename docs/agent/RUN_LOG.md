# RUN_LOG

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
