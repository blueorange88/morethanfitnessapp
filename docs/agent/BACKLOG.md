# BACKLOG

## Android Debug Emulator host 127.0.0.1 통일 (2026-07-17)

- [x] Auth·Firestore·Functions 공통 host `127.0.0.1`
- [x] 9099·8080·5001 및 Functions `asia-northeast3` 유지
- [x] `lib` Emulator 연결용 `localhost` 0개 확인
- [x] Firebase 초기화 직후 세 Emulator 연결 및 production fallback 없음 확인
- [x] Debug 전용 127.0.0.1 cleartext 설정, Profile/Release manifest 미변경
- [x] 안전한 host·port·region 연결 로그
- [x] 관련 28개·전체 197개 테스트, analyze, 최종 Debug APK, diff 검사
- [ ] 실기기 `bootstrapAnonymousBeginnerProfile success`
- [ ] 실기기 `personalProfileRead success`
- [ ] 실기기 `personalWorkspace success` 및 personal Home 진입

실기기에서 익명 세션은 성공했지만 FlutterFire Functions 요청은 Emulator 실행 로그에 도달하지 않고 code=unknown으로 실패했다. 성공 처리하지 않았으며 다음 백로그로 이동하지 않는다.

## Flutter callable regional 단일 인스턴스 연결 복구 (2026-07-17)

- [x] `lib` 전체 Functions 생성·Emulator·callable 사용처 전수 검색
- [x] `asia-northeast3` `mtfFirebaseFunctions` 단일 lazy 인스턴스
- [x] 동일 객체에 Debug localhost:5001 Emulator 연결
- [x] 모든 personal callable과 비밀번호 callable의 공통 호출기 사용
- [x] 성공 응답은 FlutterFire `HttpsCallableResult.data`만 사용
- [x] Debug projectId·region·emulator·callable 안전 로그
- [x] 공통 파일 밖 direct Functions API 사용 차단 테스트
- [x] 관련 60개·전체 197개 테스트, 변경 범위 analyze, Debug/Profile/Release APK, AOT marker, diff 검사
- [ ] Android 실기기 연결 후 네 단계 success 로그와 로그인 없는 personal Home 진입 확인

현재 `adb devices`에 연결된 기기가 없어 실기기 항목은 미검증이다. Firebase deploy와 운영 데이터 변경은 수행하지 않았고 다음 백로그로 이동하지 않는다.

## Android 실기기 LOCAL EMULATOR 시작 실패 진단·복구 (2026-07-17)

- [x] Anonymous session, profile bootstrap, profile server read, personal workspace 단계별 안전 로그
- [x] Firebase/Functions code와 runtime type 보존, UID·token·이메일·회원정보 및 원문 message 비기록
- [x] 첫 배포 필수 9개 callable의 `enforceAppCheck` 미설정 확인 및 App Check 경고 원인 배제
- [x] Debug 전용 network security config에서 localhost cleartext만 허용
- [x] Auth/Firestore/Functions 초기 연결 순서, 서울 region, production fallback 없음 재확인
- [x] 단계별 사용자 오류 안내와 Firestore 서버 프로필 확인
- [x] 관련 테스트, 전체 196개 테스트, 변경 범위 analyze, Debug/Profile/Release APK, variant 격리, diff 검사
- [ ] 최신 Debug APK로 Android 실기기 Anonymous 시작과 네 단계 로그 재확인

실제 Firebase deploy와 Rules/Functions/Storage 변경은 수행하지 않았고 다음 백로그로 이동하지 않는다.

## Android 실기기 Debug 전용 Firebase Emulator 연결 (2026-07-17)

- [x] `USE_FIREBASE_EMULATORS=true`와 Debug를 동시에 요구하는 compile-time gate
- [x] Firebase 초기화 직후 Auth/Firestore/Functions 연결
- [x] Auth localhost:9099, Firestore localhost:8080, Functions localhost:5001
- [x] 실기기 `adb reverse`용 automatic host mapping 차단
- [x] Functions `asia-northeast3` 공통 instance 재사용
- [x] 연결 실패 시 다음 connector·production fallback 차단과 오류 화면
- [x] Debug Emulator 모드의 작은 `LOCAL EMULATOR` overlay
- [x] Profile/Release define=true 빌드와 Emulator marker 미포함 확인
- [x] 관련 26개, 전체 Flutter 193개, 변경 범위 analyze, Debug/Profile/Release APK, diff 검증
- [ ] USB 실기기에서 Anonymous 시작·회원·일정·레슨일지 Emulator 수동 검증

실제 Firebase deploy, Rules/Functions/Storage 변경은 수행하지 않았고 다음 백로그로 이동하지 않는다.

## Firebase NO-GO 해소 — Region·maxInstances·Indexes·Console 확인 (2026-07-17)

- [x] 첫 배포 필수 9개 v1 callable을 `asia-northeast3`로 명시
- [x] 필수 9개 callable에 실제 `runWith({maxInstances: 10})` 적용 및 endpoint metadata 확인
- [x] Flutter callable 기본 instance를 `MtfFirebaseFunctions`로 중앙화
- [x] Emulator callable URL을 공통 wrapper로 중앙화하고 서울 리전 회귀 확인
- [x] 실제 query 전수 감사: schedules 1개, training_logs 1개 composite 유지
- [x] equality-only members 목록·전화 중복과 메모리 status filter에 불필요한 composite 미추가
- [x] 한국어 Firebase Console 출시 전 수동 확인 체크리스트 작성
- [x] PITR 이력은 활성화 이후 누적되며 기존 7일 이력이 즉시 생기지 않음을 기록
- [x] Functions lint/build, Emulator 168개, Flutter 187개, 변경 범위 analyze 통과
- [x] Debug APK, Release APK, Release AAB와 `git diff --check` 통과
- [ ] Console에서 실제 데이터 project 성격, Auth provider/domain/template 확인
- [ ] 현재 Published Rules 원문·주요 collection count 확보
- [ ] billing·bucket·IAM 확인 후 첫 배포 전 managed export 완료
- [ ] 두 composite index 실제 배포 후 `Enabled` 확인
- [ ] 승인된 9개 Functions·indexes·Rules 선택 배포 및 release smoke

코드 NO-GO는 해소했다. Console 확인과 배포 전 백업이 남아 실제 배포는 계속 **NO-GO**다. deploy/export/admin 생성은 실행하지 않았고 다음 백로그로 이동하지 않는다.

## Firebase 실제 배포 준비 감사 (2026-07-17)

- [x] project/CLI/database/bucket/runtime/region read-only 확인
- [x] 로컬 top-level Functions export 14개 전수 목록과 앱 실제 호출 비교
- [x] 현재 배포 Functions 0개, 로컬 전용 14개, 원격 전용 0개 확인
- [x] Anonymous 출시 필수 callable 9개와 관리자·legacy 보류 5개 분리
- [x] collection별 Anonymous/Linked/Legacy Rules 영향표 작성
- [x] personal query 전수 감사와 local 2개/production 0개 composite index 비교
- [x] Storage Rules를 첫 Anonymous 배포에서 제외하는 근거 기록
- [x] 백업·Rules/Functions/index/Auth rollback과 release smoke 계획 작성
- [x] 전체 Functions 일괄 배포가 아닌 A1 4개 → A2 3개 → A3 2개 PowerShell 초안 작성
- [x] Functions lint/build, Firebase Emulator 168개, Flutter 186개 통과
- [ ] Console에서 개발/운영 project 성격과 Anonymous/Email provider/domain/template 확인
- [ ] 현재 Published Firestore Rules 원문·metadata와 주요 collection count 확보
- [ ] billing/IAM/bucket 확인 후 managed export 또는 승인된 대체 백업 완료
- [x] 출시 필수 9개 v1 `maxInstances=10`과 `asia-northeast3` 적용
- [ ] member equality production query smoke 확인
- [ ] 승인 후 선택 Functions, indexes, Rules 단계별 배포와 실기기 smoke

현재 판정은 **NO-GO**다. 실제 deploy/export/provider/claim/admin/data 변경은 수행하지 않았고 다음 백로그로 이동하지 않는다.

## 닉네임 온보딩·마이페이지 정보 넛지 (2026-07-18)

- [x] anonymous bootstrap 뒤 nickname/onboardingCompleted 기반 기존 온보딩 복구
- [x] `completeNicknameOnboarding` v1 callable의 Auth UID·personal identity·멱등 transaction
- [x] 내부 nickname 정책: trim 후 1~6자, 사용자 간 중복·동일 재저장 허용, 공개 식별자 미사용
- [x] nickname과 선생님 5개 정보 완료/profileCompleted 분리
- [x] personal Home 생성 전 온보딩 완료 확인
- [x] 마이페이지 진입당 미완성 항목 한 개 AIFC 넛지와 UID별 순환
- [x] UID 유지 이메일 연결 시트와 작은 `계정 및 기록` 고정 진입점
- [x] 미구현 Google/Kakao를 `준비 중`으로 표시
- [x] Functions lint/build, Emulator 11개, Flutter 전체 204개, Debug/Profile APK
- [ ] 내부 nickname 1~6자 정책 반영 뒤 Release APK 재검증(이번 실행은 5분·10분 제한 종료)
- [ ] `completeNicknameOnboarding` 선택 배포와 anonymous/linked 실제 기기 검증
- [ ] Google/Kakao provider SDK·Firebase Auth 설정·UID 유지 link 구현

### 회원 앱 연동 단계의 공개 활동명 설계 — 현재 배포 범위 제외

- [ ] 회원 앱 연동 시 별도 `publicDisplayName` 생성 제안
- [ ] 회원에게 보이는 이름을 `nickname / realName / publicDisplayName` 중 선택
- [ ] `publicDisplayName`은 전체 사용자 범위에서 고유하도록 서버 권위 예약·확정 transaction 설계
- [ ] 흔한 이름은 시스템 예약 데이터로 선점하되 현재 nickname과 혼합하지 않음
- [ ] 예약되었거나 사용 중인 공개 활동명 안내를 `이미 등록된 활동명이에요. 조금 더 나만의 이름으로 만들어볼까요?`로 통일
- [ ] 충돌 시 개인정보를 노출하지 않는 대체 활동명 후보 제안
- [ ] Google/Kakao/email은 로그인 provider로만 취급하고 공개 이름의 출처로 사용하지 않음

Firestore/Storage Rules와 실제 Firebase 프로젝트는 변경하지 않았다. 다음 백로그로 이동하지 않는다.

## Anonymous/Linked personal 레슨일지 소유권 격리 (2026-07-16)

- [x] legacy 레슨일지·빠른서명·확정·확정취소·회차·통계 경로 감사
- [x] random ID와 Auth UID 기반 canonical personal training log
- [x] owner/member/date query 및 초안·자동저장 Rules 격리
- [x] 같은 owner의 member와 선택 schedule/member 관계 검증
- [x] completed·노쇼 차감·노쇼 미차감·service 공통 Function transaction
- [x] 중복 확정·중복 확정취소 멱등과 transaction 실패 무반영
- [x] 정식 작성과 personal 일정 빠른 레슨일지의 공통 repository 연결
- [x] personal Rules/Functions Emulator 37개 통과
- [ ] 실제 Firebase Functions·Rules·index 배포와 실제 기기 검증
- [ ] personal anatomy child 최소 Rules 및 Emulator
- [x] MyPage 계정 연결 UI와 모든 경로 완료 후 시작 로그인/Guest gate 제거

legacy migration/backfill, contracts·원격서명 권한, 실제 배포와 다음 백로그 작업은 수행하지 않았다.

## Anonymous/Linked personal 일정 소유권 격리 (2026-07-16)

- [x] 기존 시간 기반 전역 document ID 충돌과 owner 없는 query/write 감사
- [x] random document ID + `slotKey` canonical personal 일정 모델
- [x] Auth UID·personal·기간 범위 query와 CRUD·멀티 등록·주간 복사 격리
- [x] 같은 문서 transaction 이동과 실패 시 원본 보존
- [x] 현재 trainer 소유 회원 연결 검증과 이름-only 일정의 회원 자동 생성 차단
- [x] UID 변경·로그아웃 Android widget cache 정리
- [x] personal Rules Emulator 20개와 legacy Rules Emulator 28개 통과
- [ ] 실제 Firebase Rules·index 배포와 실제 기기 검증
- [ ] personal training_logs 소유권 격리
- [x] MyPage 계정 연결 UI와 모든 경로 완료 후 시작 로그인/Guest gate 제거

실제 Firebase 배포, legacy migration/backfill, 다음 백로그 작업은 수행하지 않았다.

## Anonymous 회원 10명·등급 승급 (2026-07-16)

- [x] 유효 회원 필수값 이름·성별·전화번호·활동 지역 서버 검증
- [x] 정규화 전화번호 기반 workspace 중복 방지와 멱등 저장
- [x] 익명 Beginner 10번째 저장 허용, 11번째 계정 연결·내 정보 완료 gate
- [x] Function transaction 기반 누적 유효 회원 수와 Amateur 10명·Semi-Pro 30명·Pro 50명 승급
- [x] 휴면·만료·삭제 이후 누적 수와 달성 등급 비하락
- [x] 후원 상태 등급 계산 제외와 legacy 회원 자동 귀속 금지
- [x] anonymous owner personal member read, client 직접 write 차단 Rules
- [x] 신규 회원·등급 Emulator 27개, 익명 identity 회귀 26개, profile 회귀 30개 통과
- [ ] 실제 Firebase 배포와 실제 기기 검증
- [x] MyPage의 계정 연결·내 정보 입력 UI 완성 (personal canonical profile/Auth 기준, 실제 배포·실기기 검증 제외)
- [ ] schedules, training_logs, contracts owner 권한 — 이번 작업 범위 밖

시작 로그인 gate는 유지했다. `prompts/19_anonymous_members_tier_promotion.md` 파일은 저장소에 없어 사용자 메시지의 명시 조건을 작업 기준으로 사용했다. 다음 백로그로 이동하지 않는다.

## Anonymous Beginner identity 기반 (2026-07-16)

- [x] 현재 Auth adapter, gate, profile bootstrap, Rules, 관리자 흐름 감사
- [x] 중복 호출을 합치는 `ensureAnonymousSession` service API
- [x] anonymous Beginner profile server bootstrap과 멱등성
- [x] 이메일 `linkWithCredential` 및 연결 전후 UID 일치 검증
- [x] 기존 이메일 충돌 비병합 처리
- [x] profile local→linked transaction과 불변 identity 유지
- [x] anonymous owner의 자기 profile read 최소 Rules
- [x] Auth·Firestore·Functions Emulator 신규 26개 + 기존 profile 30개 통과
- [x] anonymous owner-scoped members와 10명·승급 정책
- [x] anonymous owner-scoped schedules
- [x] anonymous owner-scoped training_logs
- [x] MyPage 계정 연결 UI (UID 유지 email 연결, provider/profile/tier 서버 상태 표시)
- [x] `AppAccountGate`를 로그인 gate에서 anonymous/linked personal bootstrap router로 전환

이번 작업은 identity 기반까지만 완료했다. 다음 백로그로 이동하지 않는다.

## 출시 계정 연결 전환 감사 (2026-07-16)

- [x] 시작 gate, 익명 Auth, profile bootstrap, 회원·일정 owner 흐름 감사
- [x] 현재 credential 흐름과 `linkWithCredential` 부재 확인
- [x] 현재 등급 계산과 요청한 누적 유효 회원 정책 차이 확인
- [x] `RELEASE_ACCOUNT_FLOW.md`, `AUTH_ACCOUNT_POLICY.md`, `TIER_QUALIFICATION_POLICY.md`, `MEMBER_DATA_COMPLETENESS.md` 기록
- [ ] anonymous UID용 personal profile·workspace Rules/Functions 설계 및 Emulator 검증
- [ ] 회원·일정·레슨일지·계약서의 모든 query/write를 Auth UID owner로 통일
- [ ] 현재 anonymous user를 유지하는 이메일 `linkWithCredential` 및 충돌 처리
- [ ] 서버 transaction 기반 누적 유효 회원·프로필·연결 상태 등급 계산
- [x] 위 선행 조건 통과 후 앱 시작 로그인/Guest gate 제거 및 canonical personal workspace 전환

상태: **중단 조건 확인으로 미완료**. 다음 백로그로 이동하지 않는다.

## Functions lint + predeploy 복구 (2026-07-15)

- [x] Functions TypeScript 세 파일 ESLint 오류 정리
- [x] ESLint TypeScript 내부 함수 JSDoc·코드 폭 설정 정리
- [x] `RESOURCE_DIR` 비의존 predeploy lint/build 명령 적용
- [x] Functions lint 0 errors/0 warnings
- [x] Functions TypeScript build 통과
- [ ] 실제 Firebase deploy 및 배포 후 callable 검증

## Debug 긴급 legacy 접근 (2026-07-15)

- [x] Guest 시작 화면의 Debug 전용 `기존 개발 데이터 열기` 버튼
- [x] `legacyDeveloper` workspace mode와 기존 `HomePage` 직접 진입
- [x] Debug 세션에서 Auth/profile/password/claim gate 미호출 테스트
- [x] 체험 화면 복귀 시 legacy child tree 폐기와 비영구 상태
- [x] Guest/Linked/관리자 gate 관련 회귀 테스트
- [x] Profile 산출물에서 Debug 버튼 문구 미포함 확인
- [x] Release 산출물 확인 — 한국어 ML Kit runtime 명시와 미사용 언어 최소 R8 규칙 적용, APK/AAB 통과
- [ ] 실제 기기에서 legacy 회원·일정·레슨일지·계약 읽기·쓰기 확인
- [ ] 실제 배포 Rules의 미로그인 Debug 접근 허용 여부 확인

## Legacy Admin workspace 접근 (2026-07-15)

- [x] legacy Firestore·Storage·로컬 상태 경로 감사
- [x] `guest`·`linkedPersonal`·`legacyAdmin` 명시적 workspace mode 분리
- [x] `platformAdmin`과 `legacyDataAccessApproved` 두 claim 및 최초 비밀번호 변경 완료 조건 강제
- [x] 실제 사용 경로만 Firestore·Storage Rules에 명시
- [x] Auth·Firestore·Functions·Storage demo Emulator 28개 시나리오 통과
- [x] 기존 데이터 표시와 개인 작업공간 전환 경로 구현
- [ ] 실제 Firebase 프로젝트 Rules·Functions 배포
- [ ] 실제 관리자 계정 생성과 claim 부여
- [ ] 실제 기기에서 legacy 건수·수정·격리 확인
- [ ] 원격서명 공개 흐름의 별도 보안 설계

## 플랫폼 관리자 LEON + 비밀번호 변경 (2026-07-15)

- [x] 숨김 입력·dry-run·멱등 Admin SDK 프로비저닝 도구
- [x] 기존 claims 보존 및 platformAdmin/legacy 승인 claims merge
- [x] 최초 로그인 비밀번호 변경 전 workspace 차단
- [x] 재인증·updatePassword·token refresh·서버 finalize 흐름
- [x] claim 기반 관리자 workspace 선택과 legacy 버튼 분리
- [x] 마이페이지·설정 비밀번호 변경 진입
- [x] profile 관리 필드 client 직접 변경 거부 Emulator 검증
- [ ] 실제 관리자 계정 생성과 claim 부여
- [ ] 실제 Firebase 배포 전 Rules/Functions diff와 App Check 검토
- [ ] 실제 기기 최초 변경·재로그인·재설정 메일 수신 검증
- [ ] 승인된 legacy owner migration

## Guest Home parity + soft gates (2026-07-15)

- [x] 실제 홈 공통 헤더·주간표·하단 내비 재사용
- [x] Guest 헤더 동행 문구와 작은 로컬 저장 안내
- [x] 로컬 체험 일정 CRUD·이동·재실행 복원·최대 5개
- [x] 6번째 저장 입력 유지와 계정 연결/둘러보기 안내
- [x] 회원·레슨일지·인사이트 샘플 및 계약·서명·알림·위젯 soft gate
- [x] Guest Firestore·Storage·Functions·실제 회원 검색·알림/위젯 sync 경로 미사용
- [ ] 실제 기기에서 일정 편집·앱 재실행·계정 전환 수동 검증
- [ ] Guest 일정의 명시적 동의 기반 Linked 가져오기 정책
- [ ] platformAdmin Custom Claim 부여와 관리자 화면은 legacy migration 직전 별도 작업

## Linked Beginner 회원 기반 (2026-07-15)

- [x] 신규 personal 회원 canonical identity와 owner-scoped repository
- [x] active·paused 포함, dormant·expired·deleted 제외 10명 transaction 제한
- [x] client 직접 create/update/delete 및 관리 상태·count 우회 차단
- [x] Auth·Firestore·Functions Emulator 회원/Rules 시나리오 통과
- [x] 첫 회원 등록, 사용량 표시, 실패 시 입력 유지 UI
- [ ] 실제 Firebase 배포 전 Rules diff·Functions region·App Check·실기기 검증
- [ ] Guest 메모리 draft handoff
- [ ] schedules/training_logs owner 기반 신규 쓰기와 회원카드 상세 필드 확장
- [ ] 기존 회원권 정지·재개와 canonical managementState의 단일 transaction 연결

## 계정 기반 2단계 — UID profile bootstrap (2026-07-15)

- [x] non-anonymous UID profile의 서버 전용 멱등 bootstrap
- [x] 신규 Beginner/linked/personal 빈 작업공간의 무승인 진입
- [x] anonymous profile create/read/update 차단
- [x] `trainer_profiles/{uid}` 본인 read·표시 필드 update 최소 Rules
- [x] Auth·Firestore·Functions Emulator 30개 시나리오 통과
- [ ] 실제 Firebase 배포 전 provider·region·App Check·Rules diff와 실기기 bootstrap 확인
- [ ] 첫 실제 회원 저장과 UID owner-scoped data 구조
- [ ] Linked Beginner 관리 중 회원 10명 제한
- [ ] legacy `trainer_profile/me` 및 운영 데이터의 근거 기반 승인·migration


## 계정 기반 1단계 (2026-07-15)

- [x] 첫 실행 Guest 진입과 서버 비접속 정적 미리보기
- [x] 이메일 가입·로그인·재설정·로그아웃 adapter 및 계정 상태 분리
- [x] 신규 UID 계정의 기존 `trainer_profile/me`·운영 데이터 자동 연결 차단
- [ ] 실제 Firebase 프로젝트 이메일 provider·메일 발송·실기기 인증 검증
- [ ] Google provider와 Android SHA-1/SHA-256 설정 확인 후 로그인 구현
- [ ] `trainer_profiles/{uid}` 생성·읽기 Rules와 명시적 legacy 데이터 접근 승인 절차
- [ ] Linked Beginner 관리 중 회원 10명 한도 및 회원저장 중 계정 연결


## P0 — 기준 상태
- [ ] Git 저장소와 복구 지점 확인
- [ ] `flutter pub get`
- [ ] `flutter analyze` 기준 결과 기록
- [ ] `flutter test` 기준 결과 기록
- [ ] `flutter build apk --debug` 기준 결과 기록
- [ ] 현재 컴파일 차단 오류만 수정
- [ ] 앱 시작 Auth gate와 로그인·로그아웃·계정전환 정책 확정
- [ ] Firebase Auth UID 기반 trainer profile 결속 및 조직 membership 모델 정의
- [ ] canonical trainerId 신규 쓰기 도입 전 legacy identity dry-run·승인 migration 계획 검토

## P0 — 운영 버그
- [ ] 홈 레슨 단일 편집 시 이전 다중 날짜·요일 상태 미상속 실제 기기 검증
- [ ] 단일 이동 후 재진입·삭제 시 target 1개만 mutation되는지 검증
- [ ] 단일 메모·색상 수정 시 update 1회/createOrUpdateMany 0회 검증
- [ ] 명시적 다중 선택에서 선택한 날짜만 저장되는지 검증
- [ ] 삭제 후 다른 레슨 편집 시 이전 선택 상태 미상속 검증
- [ ] 연속 이동·삭제/재진입/앱 강제 종료 후 재실행 재검증
- [ ] 주간 위젯 표시 종료시간 이후 현재시간 테두리 제거
- [ ] 자정 이후 오늘 요일 하이라이트 전환
- [ ] 위젯 갱신 예약과 Android 날짜 변경 수신 검증

## P1 — 기반 정리
- [x] `functions/src/index.ts` 중복 코드와 Dart 혼입 정리
- [x] Cloud Functions TypeScript build 통과
- [x] 기본 카운터 테스트 제거
- [x] 홈 레슨 시트 회원 추천 칩 위치·안내 토스트 실제 기기 검증
- [ ] 다음 레슨 계산 단위 테스트 추가
- [ ] 레슨 차감/상태 계산 단위 테스트 추가

## P2 — 위젯 확장
- [ ] 공통 일정 스냅샷 모델
- [ ] 진행 중/다음/다다음 계산
- [ ] 다음 레슨 위젯 보완
- [ ] 다음 2개 + 오늘 일정 위젯
- [ ] 위젯 회원명 개인정보 설정
- [ ] 위젯 테마 공통화

## P3 — 앱 테마
- [ ] 공통 의미 색상 모델
- [ ] 기존 위젯 테마와 앱 테마 연결
- [ ] 신규 화면부터 점진 적용
- [ ] 기존 직접 색상 점진 이전

## P4 — 레슨일지 확장
- [x] 바디맵 부위 ID/좌우/앞뒤 데이터 모델
- [ ] 남/여 바디맵 디자인
- [ ] 부위별 운동/통증/주의 기록 (앱 CRUD·서비스 무결성 완료, parent owner schema/migration 선행 후 Rules·Emulator·실기기 검증 필요)
- [ ] 영상 촬영/압축/썸네일/Storage
- [ ] 회원 공개 권한과 감사 필드
- [ ] 회원 앱 공개 레슨일지/영상
# 2026-07-18 — personal 최초 준비 화면과 실제 HomePage 연결

- [x] Onboarding과 같은 `kOnboardingBg` 및 시스템 영역 배경 적용
- [x] 기존 `AifcAvatar` 92px와 `AifcTypingDots` 재사용
- [x] 역할형 50%·브랜드형 25%·귀여운 문구 25% 후보 및 1.6초 이후 fade 전환
- [x] nickname 미완료는 기존 Onboarding, 완료는 `HomePage(personalOwnerUid: currentUid)`
- [x] `PersonalWorkspaceReadyPage`의 별도 주간 홈/첫 탭 구현 제거
- [x] Home 회원·일정 조회 및 일정 mutation을 current UID personal 범위로 제한
- [x] 홈 햄버거 메뉴를 기존 명함 UI가 있는 `MyPage`의 personal 프로필 경로에 연결
- [x] 관리자·mustChangePassword·Debug legacy 분기 유지
- [x] 관련 테스트, 전체 206개, Debug/Profile APK
- [x] 변경 범위 analyze 신규 error 0건(기존 warning/info 151건 유지)
- [ ] 실제 기기에서 personal Home 회원·일정·레슨일지·마이페이지 전체 동선 확인

# 2026-07-18 — 모어댄 브랜드·Home FC/MORE 센스·공통 네온

- [x] 앱 표시 브랜드를 `모어댄`, 보조 영문을 `MORE THAN`으로 정리
- [x] 계약서 센터명 등 실제 업무·법적 `MORE THAN FITNESS` 문맥 유지
- [x] personal 준비 화면 브랜드 계층과 가로형 FC 메시지 복원
- [x] 시간대·실제 레슨 흐름·실제 회원 이벤트 기반 Home 인사/FC 순수 선택 엔진
- [x] 최근 5개 문구와 일별 질문 중복을 owner 범위 로컬 저장소로 억제
- [x] FC와 확장 MORE 센스에서 동일 회원 이벤트 중복 노출 방지
- [x] Home·마이페이지·회원관리·레슨일지·계약서·운영통계 큰 헤더에 공통 네온 적용
- [x] 전체 217개 테스트 및 Debug/Profile/Release APK 빌드
- [ ] 검증된 위치·날씨 provider와 사용자 동의·실패 정책 확정 후 날씨 문맥 연결
- [ ] Flutter 도구 정체 해소 후 최종 `MORE 센스` 표기 상태 전체 테스트 재실행
- [ ] 실제 Android 기기에서 준비 화면 overflow, 네온 밝기·프레임, 재진입 문구, 실제 MORE 센스 이벤트 육안 검증

# 2026-07-19 — personal 온보딩·Home 인사·MyPage UID 격리

- [x] nickname 비어 있음 또는 onboarding 미완료 시 기존 OnboardingPage 유지
- [x] personal Home에서 nickname 우선 및 nickname 로드 전 `강사님` placeholder 제거
- [x] 과거 네 가지 `강사님` 기본 인사를 자동 모드로 분류
- [x] Home 사용자 고정 인사와 MyPage AI FC 넛지 SharedPreferences를 UID별로 분리
- [x] 오늘·MORE 센스·이번 주 카드의 동일 너비·높이·탭 영역 및 확대 글꼴 검증
- [x] personal MyPage profile read를 `trainer_profiles/{uid}`로 제한
- [x] personal MyPage에서 legacy 목표·상품 하위 위젯 생성 차단
- [x] 명함 `Semi-Pro` 보조 칩 제거 및 상단 이용 멤버십 유지
- [x] 관련 59개·전체 224개 테스트와 Debug/Profile/Release APK
- [ ] 실제 Android 기기 연결 후 `[MTF_PERSONAL_IDENTITY]`로 현재 UID·신규/기존 여부 확인
- [ ] 실제 기기에서 nickname 저장 직후 Home 인사와 서로 다른 두 UID의 MyPage 격리 확인
# 2026-07-19 — Home 시간표 후속 최적화

- [ ] 현재 시간 또는 첫 레슨 기준 자동 포커스의 UX와 기존 스크롤 상태 보존 정책을 별도 설계·검증
- [ ] Android 위젯 시간 범위 최적화를 앱 시간표 기본 범위와 분리해 별도 검증
- [ ] 실제 Android 기기에서 personal UID 전환 시 최근 회원 0명·stale memberId 차단·2줄 헤더 overflow 확인
- [ ] Release APK 빌드가 10분 제한 없이 완료되는 환경에서 재검증

# 2026-07-19 Home 인사 문장부호·nickname canonical 통일
- [x] 질문형·서술형 greetingText를 문장부호까지 포함한 최종 문자열로 관리
- [x] personal AccountGate·Onboarding·Home·MyPage·넛지를 `trainer_profiles/{uid}.nickname`으로 통일
- [x] nickname 완료 후 MyPage가 다음 미완성 프로필 항목부터 안내
- [x] 관련 73개·전체 236개 테스트와 Debug APK 회귀 검증
- [ ] 실제 Android 기기에서 온보딩 완료 직후 Home 2줄 인사와 MyPage 다음 넛지 확인
# 2026-07-19 nickname 저장 경로·MyPage 이름 검증·Home 인사 축소

- [x] 현재 personal nickname 생성·수정 경로 전수 감사
- [x] bootstrap 및 realName/displayName/trainerName 자동 복사 없음 확인
- [x] nickname profile read/write Debug source 로그 추가
- [x] MyPage nickname·실명 모두 공백 저장 차단
- [x] 실명만 있을 때 명시적 nickname 복사 확인 시트 및 6자 초과 자동 축약 차단
- [x] 계약서 반영 설정과 profile 이름 필수 검증 분리
- [x] nickname callable 성공 후 서버 profile 재조회 및 Home stream 갱신 확인
- [x] Home 첫 줄 13px/w600, 둘째 줄 18px/w700로 축소
- [x] 관련 64개·전체 240개 테스트 및 Debug/Profile APK
- [ ] 실제 기기 Debug 로그로 기존 nickname의 다음 read/write source 확인(과거 생성 시점은 미확정)
- [ ] 실제 기기에서 MyPage 이름 조합 4가지와 Home 즉시 갱신 수동 확인
# 2026-07-19 Firebase dev/prod 환경 분리 후속

- [x] prod/dev Android flavor 및 `.dev` applicationIdSuffix 기반 추가
- [x] prod 기존 Firebase 옵션·packageName 유지
- [x] dev Firebase 설정 누락 시 운영 fallback 차단
- [x] dev 설정이 운영 projectId를 담은 경우 시작 차단
- [x] Flutter `AppEnvironment`와 Debug environment/identity 로그
- [x] dev 전용 작은 `DEV` overlay, prod 미표시
- [x] 직접 관련 personal SharedPreferences key에 projectId+UID 범위 적용
- [x] Home 헤더 12px/w600, nickname 17px/w700 적용
- [x] 전체 245개 테스트 및 prod Debug APK
- [x] 별도 Firebase 개발 프로젝트 생성
- [x] dev Android 앱 `com.example.mtf_app.dev` 등록
- [x] `android/app/src/dev/google-services.json` 배치 후 dev Debug APK 빌드
- [ ] dev/운영 앱 동시 설치 및 서로 다른 Auth UID·Firestore 데이터 실기기 확인
- [ ] 실제 기기 `[MTF_ENV_IDENTITY]`로 기존 UID 재사용 여부 확인

## 2026-07-19 DEV Firebase 최초 진입 검증 잔여

- [x] DEV Firebase Android 설정 식별값과 PROD 분리 확인
- [x] 신규 익명 최초 진입 필수 callable 2개 DEV 선택 배포 및 ACTIVE 확인
- [x] 프로필·닉네임·회원 Rules Emulator 테스트와 warning 없는 DEV Rules 배포
- [ ] Android 기기 `R3CX40M6EEM` 재연결 후 DEV 실제 UID와 최초 nickname 온보딩 화면 확인
- [x] Flutter 도구 정지 해소 후 관련 Flutter 테스트, 변경 범위 analyze, dev/prod Debug APK 회귀 빌드
- Artifact Registry cleanup policy는 이번 범위에서 임의 설정하지 않았으며 DEV 비용 관리 후속 확인이 필요하다.
- 다음 백로그 작업으로 이동하지 않는다.

## 2026-07-19 DEV MyPage 저장·tier 후속

- [x] `updatePersonalTrainerProfile`에 nickname·realName을 포함한 MyPage 단일 transaction 저장
- [x] 익명·linked 저장, UID 격리, nickname 검증, 부분 실패 방지 Emulator 14개
- [x] DEV `updatePersonalTrainerProfile` 단일 선택 배포 및 asia-northeast3 목록 확인
- [x] 직업 AI FC 문구에서 nickname을 직책/호칭으로 사용하지 않도록 정리
- [x] 비밀번호 변경 배너 320/360/412dp·text scale 1.0/1.3/1.8 overflow 검증
- [x] personal tier source를 `trainer_profiles/{uid}.tier`로 고정하고 loading/failure 구분
- [x] 전체 Flutter 테스트 257개, DEV/PROD Debug APK
- [ ] 실기기 네트워크 정상 상태에서 MyPage nickname·realName·직업 저장과 즉시 Home 반영 확인
- [ ] 실기기에서 `[MTF_TIER_READ]` success와 Home/MyPage 동일 tier 표시 확인
- [ ] DEV Artifact Registry cleanup policy를 비용 정책 확인 후 별도 설정
- Firestore/Storage Rules와 운영 프로젝트는 이번 작업에서 변경하지 않았다. 다음 백로그로 이동하지 않는다.

## 2026-07-19 DEV MyPage 데이터 소스·계약서 이름 선택 유지

- [x] personal MyPage 읽기·초기화 source를 `trainer_profiles/{currentUid}`로 통일
- [x] 직업 `jobTitle`, 레슨 분야 `primaryActivity`, 소속 형태 `affiliationType` 저장 경계 분리
- [x] 계약서 담당강사명 source `displayName`/`realName`/`manual` 명시 저장 및 값 존재 기반 추론 제거
- [x] 선택값이 비면 저장 차단하고 다른 source로 자동 전환하지 않음
- [x] `updatePersonalTrainerProfile` transaction 저장 후 서버 재조회 일치 확인
- [x] anonymous/linked·UID 격리·source 유지·권위 필드 보존 DEV Emulator 16개
- [x] DEV `updatePersonalTrainerProfile` 단일 선택 배포 및 asia-northeast3 목록 확인
- [x] 관련 36개·전체 263개 Flutter 테스트, 변경 범위 analyze, DEV/PROD Debug APK
- [ ] Android 기기 재연결 후 MyPage 저장→앱 완전 종료→재진입 시 nickname·실명·직업·레슨 분야·소속 형태·계약서 source 유지 확인
- [ ] DEV Artifact Registry cleanup policy를 비용 정책 확인 후 별도 설정
- 운영 프로젝트와 Firestore/Storage Rules는 변경하지 않았다. 다음 백로그로 이동하지 않는다.

## 2026-07-20 DEV/PROD 표시·DEV 일정 인덱스·personal tier 격리

- [x] prod launcher 이름 `모어댄`, dev launcher 이름 `모어댄 DEV`를 flavor Android resource로 분리
- [x] 기존 내부 DEV 배지 유지, launcher 이미지 신규 생성·변경 없음
- [x] existing schedules 복합 인덱스를 DEV에만 선택 배포
- [x] schedules stream 오류의 unhandled 전파 차단 및 안전한 빈 상태 처리
- [x] personal Home tier gate를 `trainer_profiles/{uid}.tier`로 통일
- [x] smart alarm 동기화·알림 설정에 personal UID 전달, `trainer_profile/me` 조회 차단
- [x] Debug legacy의 기존 tier/profile 경로 유지
- [x] 관련 52개·전체 267개 Flutter 테스트, 변경 범위 analyze, DEV/PROD Debug APK, diff 검증
- [ ] Android 기기 재연결 후 launcher의 `모어댄`/`모어댄 DEV` 동시 표시 확인
- [ ] DEV 실기기에서 재진입 값 유지, schedules stream 정상, `trainer_profile/me` permission-denied 없음 확인
- 운영 Firebase에는 어떤 배포나 데이터 작업도 수행하지 않았다. 다음 백로그로 이동하지 않는다.
-
## 2026-07-20 DEV personal nickname 시작 flash

- [x] AccountGate 서버 profile map을 canonical HomePage 초기 데이터로 전달
- [x] Home 첫 build 전에 nickname/tier/profile 배너 상태 초기화
- [x] 초기 profile이 있는 personal Home에서 Firestore cached profile snapshot 적용 차단
- [x] 서버 snapshot 갱신 및 offline 초기 nickname 유지 테스트
- [x] `[MTF_PROFILE_SNAPSHOT]` metadata·적용 사유 안전 로그 추가
- [x] HomeHeaderSection 내부 nickname state/SharedPreferences/`김트` fallback 없음 감사
- [x] DEV flavor Android 시작 화면을 중립 배경으로 설정하고 이전 preview 차단
- [x] 관련 52개·전체 270개 Flutter 테스트, DEV/PROD Debug APK, diff 검증
- [ ] Android 실기기 재연결 후 `fromCache=true 김트 applied=false → fromCache=false 최신 nickname applied=true` 로그 및 시작 flash 제거 확인
- Firebase Functions/Rules/Storage 배포와 PROD 데이터 작업은 수행하지 않았다. 다음 백로그로 이동하지 않는다.
## 2026-07-20 PROD 개발 작업공간 차단 · MyPage 앵커 메뉴

- [x] Debug legacy 허용 조건을 DEV Debug + 정확한 DEV projectId/packageName 단일 getter로 통합
- [x] AccountGate, GuestStart, DEV 아이콘, shell 생성 분기를 단일 getter로 차단
- [x] PROD Debug 직접 상태 주입에도 `DebugLegacyWorkspaceShell` 생성 불가 테스트
- [x] 정식 PlatformAdmin/LegacyAdmin claim 경로 미변경 확인
- [x] MyPage 바텀시트를 기존 `MtfFloatingMoreMenu` 앵커 드롭다운으로 교체
- [x] 통계 → 계약서 관리 → 설정 → 비밀번호 변경 순서와 기존 action 유지
- [x] 선택·바깥 탭·아이콘 재탭·Android back 메뉴 닫기
- [x] 320/360/412 너비와 text scale 1.0/1.3/1.8 회귀 테스트
- [x] 관련 29개, 전체 272개 Flutter 테스트와 DEV/PROD Debug·DEV Release 빌드 통과
- [x] PROD 실기기 runtime guard `allowed=false` 확인
- [ ] DEV 실기기 버튼·MyPage 메뉴 확인: 별도 기존 Firebase default app 중복 초기화 오류로 UI 진입 전 중단
- [ ] PROD Release APK: 904초 빌드 제한으로 미검증
- Firebase/Rules/Storage 배포와 PROD 데이터 작업은 수행하지 않았으며 다음 백로그로 이동하지 않는다.
## 2026-07-20 DEV Firebase [DEFAULT] 중복 초기화

- [x] 저장소 전체 Dart Firebase 초기화와 DEV/PROD main entrypoint 감사
- [x] Android `FirebaseInitProvider` DEV 기본 앱 + 잘못된 PROD Dart options 충돌 원인 확인
- [x] 공통 `MtfFirebaseInitializer`로 기본 앱 initialize/reuse 멱등 처리
- [x] DEV/PROD 정확한 projectId 검증과 안전한 `[MTF_FIREBASE_INIT]` 로그 추가
- [x] 관련 11개 및 전체 273개 Flutter 테스트 통과
- [x] DEV `-t lib/main_dev.dart`, PROD `-t lib/main_prod.dart` Debug APK 빌드 성공
- [ ] DEV 실기기 cold start/hot restart/완전 종료 재실행: ADB 연결 이탈로 미검증
- [ ] DEV 개발 전환 버튼·DebugLegacyWorkspaceShell 진입/복귀 실기기 확인
- [ ] PROD 실기기 identity·개발 전환 버튼 미표시 회귀 확인
- Firebase CLI/배포/데이터 작업은 수행하지 않았으며 다음 백로그로 이동하지 않는다.
## 2026-07-20 DEV 운영 통계 월별 레슨 기록 달력

- [x] personal 월간 canonical 원본을 `training_logs`로 확정하고 schedules/lessonStats 역할 분리
- [x] 현재 Auth UID + personal workspace + 선택 월 한 달 범위 exact query 구현
- [x] 확정 transaction에 회원명·회차 snapshot 최소 추가 및 DEV 단일 Function 선택 배포
- [x] 기존 운영 요약 아래 월 요약·달력·일별 읽기 전용 상세 추가
- [x] 확정취소 총계 제외·상세 보존 정책 적용
- [x] owner 검증을 통과한 memberId만 회원카드 이동 허용
- [x] loading/success/empty/permission denied/network error 및 월 이동 stale 결과 차단
- [x] `training_logs(trainerId ASC, workspaceType ASC, startAt ASC)` DEV 인덱스 배포
- [x] 관련 Flutter 21개, Functions lint/build, Emulator 38개, DEV/PROD Debug APK, diff 검증
- [ ] 전체 Flutter 테스트의 기존 시간대 인사 기대값 실패 1건은 별도 범위에서 재검토
- [ ] Pro 이상 DEV 계정 또는 승인된 테스트 조건에서 월별 달력 실기기 육안 검증
- PROD Firebase·데이터는 건드리지 않았고 다음 백로그로 이동하지 않는다.

## 2026-07-20 Personal 월간 레슨 기록 최종 검증·접근 정책

- [x] Personal 월간 확정 이력 달력을 페이지 전체 Pro gate 밖으로 분리
- [x] Beginner~Grand Prix 공통 월 이동·상태 집계·날짜 상세·당시 회원명/레슨 종류/회차 공개
- [x] 기존 고급 운영 분석과 업그레이드 안내의 Pro gate 유지
- [x] Personal Home 일반 확정·빠른서명·정식 레슨일지의 canonical finalize 경로 및 snapshot 저장 보강
- [x] Personal 확정취소를 canonical cancel 경로로 통일하고 snapshot 보존
- [x] 현재 production 인사 문구에 기존 실패 테스트 기대값만 일치
- [x] 관련 49개·전체 292개 Flutter 테스트, Emulator 38개, DEV/PROD Debug APK, diff 검증
- [ ] Android 기기 재연결 후 DEV 앱 UI로 비개인정보 테스트 회원 및 completed/service/no_show_deducted/no_show_not_deducted/confirm_cancelled 생성
- [ ] Beginner DEV 실기기에서 달력·집계·상세·owner 격리·overflow 최종 육안 확인
- Firebase 재배포와 PROD Firebase·데이터 작업은 하지 않았으며 다음 백로그로 이동하지 않는다.

## 2026-07-20 Personal 레슨 인사이트 Pro gate·월간 더보기·비밀번호 UI

- [x] Personal 레슨 인사이트 canonical Pro rank 3 feature 정의
- [x] Home 하단·Drawer·주간 callback·MyPage 더보기의 동일 AI FC gate 적용
- [x] Beginner·Amateur·Semi-Pro 차단, Pro·Master·Grand Prix 허용 테스트
- [x] StatsPage 직접 route 이중 방어와 tier 확인 전 통계 query 차단
- [x] tier 빈 값·알 수 없는 값·조회 실패의 안전한 차단과 오류 안내
- [x] 사용자 진입 명칭을 `레슨 인사이트`로 통일하고 내부 Stats 이름 유지
- [x] 첫 화면에서 월간 달력 제거, 기존 그래프·요약 순서 복원
- [x] 우측 더보기 → 별도 `월간 레슨 기록` 화면과 지연 query
- [x] 직접 월간 route 비Pro 우회 차단과 기존 집계·snapshot 정책 유지
- [x] 비밀번호 변경·재설정 화면의 온보딩 연보라 토큰·흰 카드 적용
- [x] 일반 back·forced back 차단·인증/검증/성공/실패 로직 회귀 테스트
- [x] 관련 71개, 최종 관련 47개, 전체 307개 Flutter 테스트 통과
- [x] DEV/PROD Debug APK와 `git diff --check` 통과
- [ ] Android 기기 재연결 후 DEV Beginner 안내 시트, Pro 첫 화면·월간 기록, 비밀번호 UI 실기기 확인
- [ ] DEV/PROD Release APK: 이번 실행은 15분 이상 출력 정지로 종료해 미검증
- Firebase CLI와 DEV/PROD 데이터 작업은 하지 않았으며 다음 백로그로 이동하지 않는다.

## 2026-07-20 Amateur 승급 self-heal·레슨 편집·헤더 피드백

- [x] Amateur 2개 표시 조건을 canonical 유효 회원 수 및 provider+프로필 완료 조건과 일치
- [x] Beginner→Amateur 전용 멱등 transaction callable `reconcilePersonalTier` 구현
- [x] 시작·프로필 저장·정식 회원 생성 후 제한된 self-heal 연결
- [x] DEV에 `reconcilePersonalTier`만 선택 배포하고 Rules/Storage/인덱스 미배포
- [x] Functions lint/build와 DEV Emulator 33개 시나리오 통과
- [x] 레슨 편집 actual scoped document ID 비교 오류 수정
- [x] update/move/copyMany/replaceMany 분기와 원본 보존 불변조건 테스트
- [x] 자기 source·duplicate·tombstone·pending delete의 허위 충돌 제외
- [x] atomic 저장 성공 직후 로컬 일정 상태 patch, 실패 시 원본/화면 유지
- [x] 저장 실패·충돌 안내를 시트 단일 토스트로 통합
- [x] 오늘 레슨 수 0/1~3/4~6/7~8/9~11/12+ 헤더 피드백 적용
- [x] 전체 Flutter 테스트 318개와 DEV Debug APK 통과
- [ ] 최종 PROD Debug APK 재검증: 901초 출력 정지로 timeout, 앞선 회귀 빌드 성공만 확인
- [ ] Android 기기 재연결 후 Amateur 승급·금→금+목·빈 목요일 14시·즉시 반영·토스트·9개 레슨 헤더 육안 확인
- PROD Firebase·데이터는 건드리지 않았으며 다음 백로그로 이동하지 않는다.

## 2026-07-21 DEV Personal 스케줄 저장 권한·신규 create 계획

- [x] 빈 source 신규 일정의 `branch=create`, `deleteCount=0` 계획 적용
- [x] Personal 신규 schedule document ID를 `uid--generatedId`로 고정
- [x] Home direct Firestore write에 canonical schedule identity/slot 필드 보강
- [x] 실제 Home 필드 allowlist 기반 owner-scoped schedules client CRUD Rules 정합화
- [x] copyMany retained source exists=true, move/delete source exists=false 검증 분리
- [x] 삭제 후 Source.server 부재 확인을 위한 owner path get과 owner-filtered list 분리
- [x] Firestore Emulator 26개 owner/other UID/batch 시나리오 통과
- [x] 최종 Firestore Rules를 DEV `more-than-fitness-dev-mft`에만 선택 배포
- [x] 전체 Flutter 테스트 320개·DEV Debug APK·diff 검증 통과
- [ ] Android 기기 재연결 후 PROD force-stop 및 DEV 신규 저장·재실행 유지·수→수+목·로그 격리 확인
- PROD Firebase·데이터에는 아무 작업도 하지 않았으며 다음 백로그로 이동하지 않는다.
## 2026-07-21 DEV Personal Amateur 미션·첫 레슨 AI FC·기능 gate 통합

- [x] Amateur 미션을 정상 Personal 일정 10개 + 기존 선생님 정보 완료 2개로 교체
- [x] 고객카드 수·누적 회원 수·provider 연결을 Amateur 판정과 표시에서 제거
- [x] 서버 transaction 일정 집계와 기존 DEV 사용자 self-heal 구현
- [x] Home·MyPage를 동일 `personalTierProgress` canonical 값으로 통일
- [x] 첫 정상 신규 일정 저장 후 기존 AI FC 채팅형 안내를 단일·멀티요일 모두 정확히 1회 표시
- [x] 고객카드 신규 생성의 UI 이중 gate와 `createManagedMember` 서버 Amateur gate 적용
- [x] Home 최근 회원 0명 상태를 경량 AI FC CTA로 교체
- [x] Personal 레슨 인사이트 전체를 Pro 이상으로 제한하고 직접 route/query 이중 방어
- [x] 상담·신규 계약·고객카드·레슨 인사이트 제한 UI를 공통 `AifcTierFeatureGateSheet`로 통일
- [x] Functions lint/build, DEV Emulator 36개, 관련 Flutter 7개, 전체 Flutter 329개, DEV/PROD Debug APK, diff 검증
- [x] 변경 Functions 5개 DEV 선택 배포 성공(Artifact Registry cleanup policy 미설정으로 CLI 종료 코드 1)
- [ ] Android 기기 재연결 후 10개 일정 self-heal, Home/MyPage 2/2, 첫 안내, Amateur 고객카드 등록, 최근 회원 빈 CTA, Pro gate 육안 확인
- PROD Firebase와 데이터에는 아무 작업도 하지 않았고 다음 백로그로 이동하지 않는다.

## 2026-07-21 Android 오늘 레슨 롤업 위젯

- [x] 기존 Home/Personal 공통 일정 스냅샷을 재사용한 오늘 레슨 롤업 데이터 연결
- [x] 진행 중·다음·다다음·세 번째 이후(높이별 2~4개)·초과 개수·빈 상태 Glance UI
- [x] UID 전환·로그아웃 시 롤업 캐시 정리
- [x] 날짜 변경·시간 갱신 broadcast에서 오늘 날짜 재필터링
- [x] 기존 주간 위젯과 다음 레슨 위젯 리시버·데이터 경로 유지
- [x] JSON 직렬화·날짜 필터 순수 단위 테스트 추가
- [x] Kotlin compile·Manifest/resource merge·관련/전체 Flutter 테스트·DEV/PROD Debug APK 재검증
- [x] 변경 범위 analyze 신규 compile error 0건(기존 home_page warning/info 59건)
- [x] 위젯 cold/warm action을 기존 Home 오늘 이동 메서드에 단일 consume 연결
- [ ] Android 실기기 위젯 선택 목록·0/1/2/3/6건·진행 중·갱신·탭·자정 전환 수동 확인
- Firebase/Rules/Storage 배포와 PROD 데이터 작업은 수행하지 않음.

## 2026-07-21 MyPage 소속별 정보·활동 지역 3곳·영문 이름 검증

- [x] 실제 affiliationType `freelancer|center|personal_shop` 확인 및 새 enum 미추가
- [x] 센터/개인샵의 센터명 → 센터 위치 → 직책 → 주 활동 종목 순서와 직책 필수 적용
- [x] 프리랜서 직책·센터 정보를 탭 가능한 선택형 접힘 영역으로 구현
- [x] Flutter/Functions 공통 의미의 소속별 teacherInfoCompleted 판정 적용
- [x] `activityRegions` 1~3개와 기존 `activityRegion` 대표 mirror·legacy 1개 fallback
- [x] 지역 추가·중복/4번째 차단·대표 변경·변경·삭제 정책 구현
- [x] 선택 `nameEn`의 영문/공백/하이픈/아포스트로피 2~40자 검증과 서버 차단
- [x] Functions lint/build, DEV Emulator 22개, 관련 Flutter 32개, 전체 Flutter 361개 통과
- [x] DEV/PROD Debug APK와 `git diff --check` 통과
- [x] DEV의 `updatePersonalTrainerProfile`, `reconcilePersonalTier` 선택 배포 성공
- [ ] Artifact Registry cleanup policy는 별도 승인 후 설정
- [ ] Android 기기 재연결 후 소속별 순서·접힘 UX·지역 3곳·대표 변경/삭제·영문 오류 스크롤 육안 확인
- PROD Firebase와 데이터에는 아무 작업도 하지 않았으며 다음 백로그로 이동하지 않는다.

## 2026-07-21 PROD 반영 전 알림·등급 로그 정리

- [x] Smart Alarm INCLUDE/SKIP 로그에서 실제 회원명·미등록 일정명·레슨 종류 원문 제거
- [x] 알림 관련 예외 원문·memberId·알림 ID를 안전 코드/존재 여부로 대체
- [x] Home·MyPage·tierGuide의 raw/display 등급 진행률 로그 공통화
- [x] Beginner raw/display 동일, Amateur 이상 raw 보존·display 2/2 테스트
- [x] 관련 18개, 전체 Flutter 373개, DEV/PROD Debug APK, diff 검증
- Firebase 변경·배포와 PROD 데이터 작업 없음. 다음 백로그로 이동하지 않음.

## 2026-07-21 MyPage 편집 UX·등급 표시·Personal 진입 보완

- [x] MyPage 헤더 부제목 제거 및 약 33px 높이 축소
- [x] 키보드 위 SafeArea 고정 저장 버튼과 입력 자동 scroll padding
- [x] 정규화 dirty 판정과 상단/시스템/제스처 back 단일 AI FC 흐름
- [x] projectId+UID scoped local draft 저장·복원·폐기
- [x] 네트워크 단절 저장 실패의 입력 유지·성공 금지·임시 보관 제안
- [x] Amateur 이상 Beginner 미션 earned 2/2 표시와 raw 정보 품질 안내 분리
- [x] MORE 비즈니스 로딩 후 connected/empty/error 분기 및 빈 route 차단
- [x] 계약서 목록 +/빈 CTA와 direct create의 canonical Semi-Pro gate
- [x] Home 오늘 탭의 현재 주·전체 요일·다음 레슨/현재 시간 행 이동
- [x] Personal 사용자 노출 `인사이트`/`MORE 인사이트` 명칭과 기존 Pro gate 유지
- [x] 회원권 관리 첫 AI FC 문구의 회원명 및 `님` 중복 정규화
- [x] 인바디 OCR 실제 경로에 맞춘 사전 안내와 Android 카메라 권한/설정 이동
- [x] 전체 Flutter 테스트 355개, DEV/PROD Debug APK, diff 검증
- [ ] Android 기기 연결 후 DEV 헤더·키보드·dirty/draft·오프라인·등급·비즈니스·계약서·오늘 이동·회원권·카메라 권한 수동 확인
- Firebase 배포와 데이터 작업은 없었고 다음 백로그로 이동하지 않는다.

## 2026-07-21 DEV 등급 안내·Amateur 일정 미션·선생님 정보 검증

- [x] 등급 선택 시 채팅 누적 제거 및 단일 상세 AnimatedSwitcher 교체
- [x] 320/360/412/480dp × 글자 배율 1.0/1.3/1.8 overflow 회귀 테스트
- [x] Beginner 미션을 현재 정상 Personal 일정 10개 + canonical 선생님 정보 완료로 확정
- [x] 생성·삭제·요일 제거·전체 주 삭제 성공 후 서버 tier reconcile 연결
- [x] Beginner→Amateur transition ID와 서버 transaction 축하 claim 1회 보장
- [x] 기존 AI FC 축하 sheet를 Beginner→Amateur 문구·CTA로 확장
- [x] canonical 선생님 정보 5개 필드의 클라이언트·서버 동일 검증
- [x] 시·도/시·군·구 picker, 선택 전화번호 formatter, 생년월일 formatter/DatePicker 적용
- [x] Personal의 `trainer_profile/me` 및 unscoped `member_groups` 초기 조회 차단
- [x] Functions lint/build, DEV Emulator 38+16개, 관련 Flutter 42개, 전체 Flutter 345개 통과
- [x] DEV/PROD Debug APK 빌드 성공
- [x] DEV 함수 3개 선택 배포 성공(Artifact Registry cleanup policy 후처리 실패로 CLI 종료 코드 1)
- [ ] Android 기기 재연결 후 등급 교체·진행률 감소/재완료·승급 축하 1회·MyPage picker/formatter 육안 확인
- PROD Firebase와 데이터에는 아무 작업도 하지 않았고 다음 백로그로 이동하지 않는다.
