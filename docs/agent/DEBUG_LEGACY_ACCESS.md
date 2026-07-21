# Debug 전용 기존 개발 데이터 접근

기준일: 2026-07-15

## 목적과 진입 위치

- 미로그인 Guest 시작 화면의 `기존 개발 데이터 열기` 버튼으로 진입한다.
- 버튼과 우회 분기는 `kDebugMode`일 때만 구성된다. Profile과 Release에서는 버튼 callback이 전달되지 않고 우회 분기도 실행되지 않는다.
- 진입 상태는 `AppAccountGate` 인스턴스 안의 메모리 값이며 로컬 저장소나 서버에 저장하지 않는다.
- workspace mode는 `AppWorkspaceMode.legacyDeveloper`다. Guest의 로컬 샘플 일정과 Linked personal workspace를 이 모드에 전달하지 않는다.

## 재사용한 기존 경로

- Debug 진입은 `SplashRouter`를 건너뛰고 기존 `HomePage`를 직접 사용한다.
- 따라서 `SplashRouter`의 `trainer_profile/me` onboarding 확인은 실행하지 않는다.
- `HomePage`가 이미 사용하던 legacy 회원, 일정, 레슨일지, 계약서 query/write를 owner-scoped repository로 바꾸지 않고 그대로 사용한다.
- 기존 문서에 `trainerId`나 `ownerId`를 추가하거나 문서 ID를 바꾸는 migration/backfill은 없다.

## 우회 범위

`kDebugMode && workspaceMode == legacyDeveloper`인 메모리 세션에서만 다음 gate를 거치지 않는다.

- Firebase 로그인 요구
- `trainer_profiles/{uid}` bootstrap과 profile 상태 확인
- `mustChangePassword`
- `platformAdmin`과 `legacyDataAccessApproved` claim 확인

일반 Guest, Linked personal, legacy admin 흐름은 기존 gate를 그대로 사용한다. 이메일 또는 표시 이름을 관리자 판정에 사용하지 않고 claim을 client에서 설정하지 않는다.

## 종료와 데이터 격리

- 상단의 `체험 화면으로 돌아가기`를 누르면 Debug legacy child tree를 폐기하고 Guest 시작 화면을 다시 만든다.
- 이 과정에서 legacy 상태를 Guest 저장소로 복사하지 않으며 Guest 샘플을 legacy 저장 경로로 올리지 않는다.
- Debug legacy 선택은 재실행 후 복원하지 않는다.

## Release 차단 근거

- 진입 버튼 렌더링과 callback 전달이 모두 `kDebugMode` 조건 안에 있다.
- `AppAccountGate`의 직접 HomePage 분기도 `kDebugMode && _debugLegacyWorkspaceOpen`을 동시에 요구한다.
- 외부 route, deep link, SharedPreferences 플래그, 이메일 예외 또는 숨은 제스처를 추가하지 않았다.

## 실제 읽기·쓰기 확인 전 주의

현재 저장소의 Firestore/Storage Rules는 비익명 사용자와 관리자 claim을 요구한다. 이 Rules가 실제 프로젝트에 배포되어 있고 Debug 앱이 미로그인 상태라면 화면 진입은 가능해도 legacy 읽기·쓰기는 `permission-denied`가 된다. 이번 작업에서는 Rules를 완화하거나 배포하지 않았으며, 권한 실패를 성공으로 기록하지 않는다.

실제 기기에서는 다음을 별도로 확인해야 한다.

1. 기존 회원 목록 조회 및 회원카드 열기·수정·저장
2. 일정 조회·등록·수정·이동·삭제
3. 레슨일지 조회·작성·확정
4. 계약서 조회·작성
5. 권한 거부 시 성공 표시가 남지 않는지
6. Guest 복귀 후 legacy 데이터와 구독이 화면에 남지 않는지

Firestore Rules, Storage Rules, Functions, 관리자 계정, claim, 운영 데이터는 이 작업에서 변경하거나 배포하지 않았다.
