# 앱 시작 라우팅 감사

기준일: 2026-07-17

## 현재 호출 흐름

- 모바일 앱 root는 `main.dart`의 `AppAccountGate`다. Web 공개 서명 `/sign` 경로는 이 gate를 사용하지 않는다.
- 변경 전 `AppAccountGate`는 `AppAccountSnapshot.fromUser`를 구독한다. 이 변환은 `currentUser == null`과 anonymous user를 모두 `guest`로 축약하고 user 객체를 버리므로, 신규 설치와 기존 anonymous 재실행 모두 `GuestStartPage`로 이동한다.
- `GuestStartPage`는 로컬 sample 홈과 이메일 가입·로그인 화면의 진입점이다. canonical personal 회원·일정·레슨일지 repository는 호출하지 않는다.
- `AppAccountService.ensureAnonymousSession`은 current user를 재사용하고 user가 없을 때만 `signInAnonymously`를 호출한다. 동시 호출은 같은 Future로 합친다.
- `bootstrapAnonymousBeginnerProfile`은 현재 anonymous Auth user만 허용하고 server Function의 멱등 transaction으로 `trainer_profiles/{uid}`를 준비한다.
- non-anonymous user는 `_LinkedAccountGate`에서 canonical profile 상태와 관리자 claims를 확인한다. `mustChangePassword`가 workspace보다 먼저 적용되고 platform admin의 personal/legacy 선택과 Debug legacy 직접 진입은 별도 분기다.
- canonical personal 실제 데이터 화면은 현재 `PersonalWorkspaceReadyPage`다. `members`, `schedules`, `training_logs`, 마이페이지가 Auth UID와 `workspaceType=personal` repository를 사용하며 legacy `HomePage`와 Guest sample을 열지 않는다.

## 확인된 수정 지점

1. 시작 gate가 raw Auth user 상태를 보존해 null/anonymous/linked를 구분해야 한다.
2. null은 anonymous session 생성 후, anonymous는 같은 UID로 멱등 profile bootstrap 후에만 personal 화면을 열어야 한다.
3. bootstrap Future가 완료되기 전에는 실제 화면이나 sample 화면을 만들지 않아야 하며 실패는 명시적 재시도 화면에 머물러야 한다.
4. linked personal 판정은 `tier == Beginner`에 한정하면 승급 후 재실행이 막힌다. canonical personal identity/state를 기준으로 판정하고 서버 tier 값은 허용 범위가 아니라 표시 값으로 취급해야 한다.
5. linked 로그아웃은 widget cache를 지운 뒤 Auth sign-out해야 한다. root gate가 null을 관찰하면 새 anonymous UID/profile을 준비하고 UID key로 personal subtree를 교체해 이전 stream을 폐기해야 한다.
6. Debug legacy 버튼은 Guest 시작 화면 의존성을 제거하고도 Debug 빌드에서만 별도 진입할 수 있어야 한다.

## 유지할 경계

- legacy `HomePage`를 anonymous/linked personal 홈으로 재사용하지 않는다. owner 없는 legacy query가 personal 데이터와 섞일 수 있기 때문이다.
- 관리자 `mustChangePassword`, `platformAdmin + legacyDataAccessApproved`, legacy workspace, Debug legacy 우회는 유지한다.
- 이메일 가입·로그인·재설정 화면 파일은 삭제하지 않고 마이페이지 계정 전환과 관리자용 후속 경로로 보존한다.
- contracts/sign_requests Rules, 계약 상태 머신, Google·카카오, legacy migration/backfill은 변경하지 않는다.
- 실제 Firebase 배포와 운영 데이터 변경은 수행하지 않는다.

## 선행 회귀 기준선

- Auth anonymous identity Emulator, profile bootstrap Emulator, managed member/tier Emulator, personal schedule Emulator, personal training log Emulator가 모두 통과했다.
- 관련 Flutter 테스트 64개, 전체 Flutter 테스트 184개, 변경 예상 범위 analyze, Debug APK build, `git diff --check`가 통과했다.

## 구현 결과

- root gate는 raw Auth user를 구독한다. null은 `ensureAnonymousSession`, anonymous는 같은 UID의 `bootstrapAnonymousBeginnerProfile`을 완료한 뒤에만 canonical personal 화면을 연다.
- 준비 중에는 짧은 splash만 표시하고 실패하면 오류 코드만 로그로 남긴 뒤 수동 재시도 화면에 머문다. UID/token/개인정보는 로그에 남기지 않는다.
- linked personal은 로그인 화면을 거치지 않고 canonical profile 검사 후 같은 personal 화면으로 들어간다. Beginner로 고정하던 조건을 제거해 Amateur/Semi-Pro/Pro 재실행도 허용한다.
- canonical personal 홈은 legacy `HomePage`가 아니라 UID-scoped `PersonalWorkspaceReadyPage`다. 화면 제목을 `홈`으로 정리하고 member/schedule/training log/MyPage의 existing personal repository를 그대로 사용한다.
- linked 로그아웃은 마이페이지에서 Android widget cache를 먼저 지우고 Auth sign-out한다. root가 새 anonymous UID/profile을 준비하며 UID key가 바뀌어 이전 personal subtree와 stream을 폐기한다.
- Guest/sample 파일과 이메일 인증 파일은 삭제하지 않았다. sample은 출시 기본 root에서 참조하지 않으며 Debug legacy 진입은 canonical personal 홈의 Debug 전용 overlay에서 유지한다.
