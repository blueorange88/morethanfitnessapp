# 출시 계정 흐름 감사

## 2026-07-16 Anonymous/Linked personal 레슨일지 연결

- personal 회원 목록과 연결 회원이 있는 personal 일정에서 전용 레슨일지 화면으로 진입한다. 시작 로그인 gate는 그대로 유지했으며 Anonymous는 repository·Auth/Firestore/Functions Emulator harness로 검증했다.
- 신규 레슨일지는 현재 Auth UID를 `trainerId`로, `workspaceType=personal`로 저장한다. 연결 전후 UID 유지 정책 때문에 이메일 연결 후에도 같은 레슨일지를 계속 사용한다.
- 초안과 자동저장은 client 최소 Rules를 사용하고, 확정·확정취소는 `finalizePersonalTrainingLog`와 `cancelPersonalTrainingLog` Function transaction만 사용한다. 정식 작성과 personal 일정의 빠른 레슨일지는 같은 repository와 Function을 사용하며 source만 `formal`/`home_quick_sign`으로 구분한다.
- legacy `HomePage`, 기존 빠른서명·정식 레슨일지·원격서명은 변경하지 않았다. owner 없는 legacy 문서를 personal에 귀속하거나 backfill하지 않는다.
- contracts·sign_requests와 personal anatomy child 권한, 실제 배포, 시작 gate 제거는 이번 단계에서 진행하지 않았다.

## 2026-07-16 Anonymous/Linked personal 일정 연결

- 시작 로그인 gate는 그대로 유지했다. Linked personal 작업공간에는 전용 `PersonalSchedulePage` 진입만 추가했고, Anonymous 흐름은 현재 gate를 우회하지 않은 Emulator·repository 테스트 harness로 검증했다.
- personal 일정은 현재 Firebase Auth UID를 `trainerId`로 고정하고 `workspaceType=personal`로 저장한다. 계정 연결은 기존 UID 유지 정책을 그대로 사용하므로 연결 전후 일정 owner도 바뀌지 않는다.
- Debug/관리자 legacy `HomePage`와 시간 기반 legacy 일정 문서는 수정·이관하지 않았다. personal 화면은 legacy 전역 query, Guest 로컬 샘플, 운영통계·레슨일지 query를 호출하지 않는다.
- 로그아웃 시 personal Android widget cache를 먼저 비우며, 다른 UID가 동기화를 시작하면 저장된 widget owner와 비교해 이전 cache를 제거한다.
- 다음 단계인 training_logs 소유권, 마이페이지 계정 연결 UI, 시작 gate 제거는 진행하지 않았다.

## 2026-07-16 Anonymous identity 기반 반영

- 공통 Auth service에 `ensureAnonymousSession`과 현재 anonymous user의 이메일 `linkWithCredential` 기반을 추가했다.
- anonymous Beginner profile은 별도 callable이 `trainer_profiles/{uid}`에 생성하며 linked 전환도 서버 transaction으로 수행한다.
- Auth·Firestore·Functions Emulator에서 이메일 연결 전후 UID 동일, 충돌 시 비병합, profile 멱등 전환을 확인했다.
- 이번 단계에서는 앱 시작에서 anonymous session을 호출하지 않았고 `AppAccountGate`와 Guest 진입을 유지했다.
- 실제 홈 전환 전에는 anonymous owner-scoped members/10명 정책, schedules, training_logs, MyPage 연결 UI가 순서대로 필요하다.

기준일: 2026-07-16

## 결론

`prompts/17_release_my_page_account_linking.md`의 중단 조건이 현재 코드에서 확인되어 앱 시작 로그인 gate 제거를 적용하지 않았다. 현재 상태에서 익명 사용자를 기존 `HomePage`로 보내면 저장이 Rules와 Functions에서 거부되거나, UID 소유권이 없는 legacy 조회·쓰기에 합류할 수 있다.

## 현재 진입 흐름

- 모바일 시작점은 `main.dart`의 `AppAccountGate`다.
- 미로그인 또는 익명 사용자는 `AppAccountSnapshot.guest()`로 축약되어 UID가 화면 흐름에 전달되지 않고 `GuestStartPage`로 간다.
- non-anonymous 계정만 profile bootstrap과 linked/admin 분기를 통과한다.
- Debug의 `legacyDeveloper` 분기는 별도로 유지되며 기존 `HomePage`에 직접 진입한다.

## 확인된 중단 조건

1. `profile_bootstrap.ts`와 `managed_members.ts`는 anonymous provider를 `anonymous_not_allowed`로 거부한다.
2. `firestore.rules`의 personal profile/member 권한은 `isNonAnonymous()`를 요구한다. 일정·레슨일지·계약서는 personal workspace 권한이 열려 있지 않다.
3. 기존 `HomePage`의 회원·일정 조회는 UID owner 조건이 없고, 빠른 회원 저장은 `trainerId`와 `workspaceType` 없이 root `members`에 직접 쓴다.
4. 앱 인증 gateway에는 `signInAnonymously`와 현재 사용자에 대한 `linkWithCredential`이 없다. 현재 이메일 흐름은 신규 UID 생성 또는 별도 로그인 방식이다.
5. 등급은 클라이언트가 legacy `trainer_profile/me`의 여러 필드와 후원값을 합산한다. 누적 유효 회원 수의 서버 transaction 원장이 없다.

## 안전한 출시를 위한 최소 분리 작업

다음 항목은 한 번에 대규모로 적용하지 않고 순서대로 완료해야 한다.

1. 익명 세션을 canonical UID로 유지하도록 account snapshot과 auth gateway를 확장한다. 익명 인증 실패 시 실제 workspace 진입을 막는다.
2. `trainer_profiles/{uid}`와 personal workspace에 대한 익명 owner 정책을 설계하고 Auth·Firestore·Functions Emulator로 검증한다.
3. 회원·일정·레슨일지·계약서의 모든 정상 query/write를 UID owner repository로 통일한다. legacy root 흐름은 admin/Debug 전용으로 계속 격리한다.
4. 계정 연결은 현재 anonymous user의 `linkWithCredential`만 사용한다. credential 충돌 시 자동 병합하거나 새 UID로 로그인하지 않는다.
5. 서버 transaction에서 누적 유효 회원, 프로필 완성도, provider 연결 상태를 계산하고 하락하지 않는 earned tier를 저장한다. 후원 상태는 별도 필드로 유지한다.
6. Emulator에서 익명 시작, UID 유지, owner 격리, credential 충돌, 등급 경계값, 계약서 Semi-Pro gate를 모두 통과한 뒤에만 시작 gate를 제거한다.

## 이번 작업에서 유지한 범위

- 기존 로그인·비밀번호 변경·관리자 claim 코드는 삭제하지 않았다.
- Debug legacy 진입과 관리자 legacy workspace 분기를 변경하지 않았다.
- 계약서와 전자서명의 기존 Semi-Pro gate를 변경하지 않았다.
- Firebase Rules, Functions, 앱 소스, 운영 데이터, 배포를 변경하지 않았다.
# 2026-07-17 마이페이지 계정 연결 UI

1. personal workspace의 마이페이지는 canonical profile stream과 Firebase Auth 현재 user를 읽는다.
2. anonymous는 내 정보 편집과 UID 유지 이메일 연결을 제공하되 로그아웃은 숨긴다.
3. 연결 성공은 `linkWithCredential` → UID 동일성 확인 → token 갱신 → profile local-to-linked Function → profile stream 갱신 순서다. 인증되지 않은 이메일에는 인증 메일 전송을 시도한다.
4. linked는 provider/email/인증 상태, 비밀번호 변경, 로그아웃을 제공한다. 로그아웃 전에 UID별 Android widget 캐시를 지운다.
5. 시작 gate 제거와 최초 anonymous session의 실제 HomePage 진입은 다음 단계이며 이번 작업에서는 변경하지 않는다.
# 2026-07-17 시작 라우팅 활성화

```text
앱 시작
→ Auth user 확인
→ null이면 anonymous session 생성
→ anonymous Beginner profile 멱등 bootstrap
→ UID-scoped canonical personal 홈
```

- anonymous와 linked personal은 동일한 `PersonalWorkspaceReadyPage`를 사용한다. Guest sample과 owner 없는 legacy `HomePage`는 출시 기본 진입에서 사용하지 않는다.
- linked user는 canonical profile과 claims를 확인한다. `mustChangePassword`와 platform admin personal/legacy 선택은 기존 순서를 유지한다.
- 준비 실패는 재시도 화면으로 끝나며 자동 무한 재시도, session 삭제, 가짜 성공 화면이 없다.
- linked 로그아웃은 Android widget cache 정리 → Auth sign-out → 새 anonymous session/profile → 새 UID personal subtree 순서다.
- 이메일/비밀번호 로그인 화면은 기본 시작에서 제거했지만 파일과 명시적 계정 전환·관리자·재설정 역할은 유지한다.
