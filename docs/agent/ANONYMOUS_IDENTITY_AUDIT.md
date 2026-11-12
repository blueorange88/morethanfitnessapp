# Anonymous Beginner identity 감사

기준일: 2026-07-16

## 감사 대상

- 앱 인증 계층: `app_account_service.dart`, `account_gate.dart`, `email_auth_page.dart`
- 진입 흐름: `main.dart`, `AppAccountGate`, `SplashRouter`
- 서버 profile: `profile_bootstrap.ts`, `index.ts`
- 권한: `firestore.rules`의 `trainer_profiles/{uid}`
- 회귀 범위: 관리자 claim, `mustChangePassword`, Debug legacy workspace

## 기존 상태

- `AppAccountAuthGateway`에는 이메일 가입·로그인·재설정·로그아웃만 있었고 `signInAnonymously`와 provider link가 없었다.
- anonymous Firebase user는 `AppAccountSnapshot.guest()`로 표현되어 시작 gate에서 Guest 화면으로 이동했다.
- `bootstrapTrainerProfile`, `completeInitialPasswordChange`, managed member Functions는 anonymous provider를 거부했다.
- `trainer_profiles/{uid}`는 non-anonymous owner만 읽을 수 있었다.
- 이메일 가입은 `createUserWithEmailAndPassword`, 로그인은 `signInWithEmailAndPassword`를 사용하므로 기존 anonymous UID를 유지하는 계정 연결 방식이 아니었다.
- 관리자 진입은 `platformAdmin`, `legacyDataAccessApproved`, `mustChangePassword`를 별도 gate에서 검사하고 Debug legacy는 `kDebugMode` 분기로 격리돼 있었다.

## 구현한 기반

### 앱 Auth service

- `ensureAnonymousSession`은 linked/anonymous current user를 그대로 반환하고 user가 없을 때만 `signInAnonymously`를 호출한다.
- 같은 service의 동시 호출은 하나의 in-flight Future를 공유해 anonymous 계정 중복 생성을 막는다.
- `linkAnonymousWithEmail`은 현재 user가 anonymous인지 확인하고 `EmailAuthProvider.credential`과 `currentUser.linkWithCredential`을 사용한다.
- 연결 전후 UID가 다르면 `uidChangedUnexpectedly`로 중단한다. sign-out, 새 UID sign-in, 데이터 병합은 호출하지 않는다.
- 연결 후 ID token을 강제 갱신하고 `transitionAnonymousProfileToLinked` callable을 호출한다.
- anonymous provider 비활성, 네트워크, 과다 요청과 이메일 credential 충돌을 typed error로 구분한다. UID/token은 로그에 출력하지 않는다.

### 서버 profile

- `bootstrapAnonymousBeginnerProfile`은 anonymous auth만 허용하고 `trainer_profiles/{auth.uid}`를 transaction으로 생성한다.
- 서버 고정값은 `local`, `Beginner`, `personal`, `active`, `role=personal`, `isAnonymous=true`, 관리 한도 10, 현재·누적 count 0이다.
- 기존 local anonymous profile은 그대로 반환하며 linked profile과 owner 충돌은 덮어쓰지 않는다.
- `transitionAnonymousProfileToLinked`는 non-anonymous provider가 연결된 token과 동일 owner profile을 검증한다.
- 전환 시 `accountState`와 `isAnonymous`, `updatedAt`만 변경한다. `trainerId`, `createdAt`, tier, role, 한도·count와 organization/admin 관련 필드는 유지한다.
- legacy `trainer_profile/me` 또는 운영 데이터를 읽거나 복사하지 않는다.

### Rules

- `trainer_profiles/{uid}` read만 signed-in owner에게 허용했다. anonymous와 non-anonymous 모두 path UID가 Auth UID와 같아야 한다.
- client create/delete는 계속 거부하며 anonymous client update도 열지 않았다.
- `members`, `schedules`, `training_logs`, `contracts` Rules는 변경하지 않았다.

## 의도적으로 보류한 항목

- 앱 시작에서 `ensureAnonymousSession` 자동 호출
- 시작 로그인/Guest gate 제거
- MyPage 계정 연결 UI
- anonymous 회원 저장과 10명 정책
- anonymous 일정·레슨일지 권한
- 계약서 gate 변경
- Google·카카오 연결
- legacy migration/backfill 및 실제 Firebase 배포

