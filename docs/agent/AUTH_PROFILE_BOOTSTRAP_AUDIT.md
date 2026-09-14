# Auth Profile Bootstrap 감사

감사일: 2026-07-15  
범위: `trainer_profiles/{uid}` 신규 개인 작업공간 bootstrap과 해당 경로의 최소 Rules

## 기존 상태

- 이메일 가입·로그인 후 Auth gate는 `trainer_profiles/{uid}`를 직접 읽었다.
- 프로필이 없으면 생성 경로가 없었고 연결 대기 화면에 머물렀다.
- `legacyDataAccessApproved == true`를 모든 연결 계정의 기존 앱 진입 조건으로 사용해 신규 계정도 관리자 승인 대상으로 잘못 분류했다.
- Functions에는 `chargeOnce`, `cancelNoShow`, `lockConsent`, `unlockConsent`만 있었고 프로필 bootstrap callable이 없었다.
- `firestore.rules`에는 `trainer_profiles` match가 없어 client read/update가 모두 거부됐다.
- `firebase.json`에는 Auth·Firestore·Functions Emulator와 Firestore Rules 연결이 없었다.
- Functions는 Admin SDK를 한 번 초기화하는 v1 callable 구조이며 Node 22 runtime을 사용한다.

## 선택한 경계

### 신규 personal workspace

- non-anonymous Firebase Auth UID를 canonical profile document ID로 사용한다.
- `bootstrapTrainerProfile` callable이 `trainer_profiles/{uid}`를 transaction으로 멱등 생성한다.
- client 입력의 tier, role, organizationId는 사용하지 않는다.
- 서버 고정 필드는 다음과 같다.

```text
trainerId: auth.uid
accountState: linked
tier: Beginner
workspaceType: personal
workspaceStatus: active
role: personal
schemaVersion: 1
createdAt: server timestamp
updatedAt: server timestamp
```

- personal profile은 관리자 승인 없이 빈 작업공간 준비 화면으로 진입한다.
- 이 화면은 기존 Home/SplashRouter를 열지 않아 기존 회원·일정·계약 데이터를 표시하지 않는다.
- 첫 실제 회원 저장과 Linked Beginner 10명 제한은 후속 작업이다.

### Legacy 데이터

- `trainer_profile/me`와 legacy 회원·일정·레슨일지·계약 데이터는 복사하거나 귀속하지 않는다.
- 기존 데이터 연결은 `legacyDataAccessApproved == true`인 별도 프로필만 legacy 앱 흐름으로 보낸다.
- 표시 이름·이메일·문자열 `me`로 owner를 추측하지 않는다.

### 익명 계정

- Flutter gate에서 익명 user를 Guest로 분류한다.
- bootstrap callable은 Auth provider가 anonymous이면 `anonymous_not_allowed`로 거부한다.
- Rules도 anonymous provider의 profile read/update를 거부한다.
- Emulator에서 익명 UID profile이 생성되지 않았음을 Admin context로 확인했다.

## Function 멱등성과 오류

- 문서가 없으면 transaction `create`로 한 번 생성한다.
- 문서가 이미 있고 `trainerId == auth.uid`이면 변경 없이 현재 서버 관리 상태를 반환한다.
- 기존 문서 trainerId가 path UID와 다르면 `profile_conflict`로 중단한다.
- 비로그인은 `unauthenticated`, 익명은 `anonymous_not_allowed`, 예상하지 못한 오류는 `internal`로 구분한다.
- 내부 오류 로그에는 UID와 오류 종류·메시지만 기록하며 profile payload나 개인정보를 기록하지 않는다.

## Rules 허용 범위

- `trainer_profiles/{uid}`만 추가했다.
- non-anonymous 본인만 read할 수 있다.
- client create/delete는 항상 거부한다.
- client update는 `displayName`, `nickname`, `phone`, `profileImageUrl`, `locale`, `timezone`, `contractProfileDraft`, `updatedAt`만 허용한다.
- `updatedAt`은 `request.time`과 일치하는 서버 타임스탬프만 허용한다.
- trainerId, accountState, tier, workspaceType, workspaceStatus, organizationId, role, schemaVersion, createdAt 및 기타 관리 필드는 client가 변경할 수 없다.
- members, schedules, training_logs, contracts, sign_requests Rules는 변경하지 않았다.

## Emulator 결과

- demo project ID: `demo-mtf-auth-profile`
- 실행: 로컬 `firebase-tools`로 Auth·Firestore·Functions Emulator를 함께 기동
- 결과: Function·Rules 30개 시나리오 통과
- 검증 항목: 비로그인/익명 거부, UID 경로, 서버 고정 필드, 악성 입력 무시, server timestamp, 멱등성, 기존 profile 미덮어쓰기, legacy 미복사, profile conflict, 본인/타인 read, client create/delete, 표시 필드 update, 관리 필드 변경 거부
- 운영 프로젝트, 운영 계정, `firebase login`, `projects:list`, Firebase deploy를 사용하지 않았다.

## 도구와 남은 위험

- 루트 devDependencies: `firebase-tools 15.23.0`, `@firebase/rules-unit-testing 5.0.1`
- Node: `22.20.0`; Firebase Tools 요구 범위 `>=20 || >=22 || >=24`와 호환
- Firestore Emulator: `1.21.0`
- Firebase Tools는 Functions의 `firebase-functions 6.0.1`이 최신이 아니라는 경고를 표시했다. 이번 범위에서 Functions 의존성을 변경하지 않았다.
- npm은 중간 수준 취약점 5건을 보고했다. `npm audit fix`는 실행하지 않았다.
- 이번 Emulator 통과는 `trainer_profiles/{uid}` Rules 범위에 한정된다. 기존 members Rules의 광범위한 read 등 다른 경로의 기존 위험을 해결했다는 뜻이 아니다.
- 실제 배포 전 이메일 Auth provider, callable region, App Check 정책, 배포 Rules diff와 실제 기기 bootstrap을 별도로 검증해야 한다.

