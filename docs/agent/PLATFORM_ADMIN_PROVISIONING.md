# 플랫폼 관리자 프로비저닝

기준일: 2026-07-15  
상태: 도구 구현 및 로컬 가짜 계층/Emulator 검증 완료, 실제 계정 생성 미실행

## 확정 계정과 권한 경계

- 계정 이메일: `mtgroup.fitnessapp@gmail.com`
- 표시 이름: `LEON`
- Auth Custom Claims: `platformAdmin: true`, `legacyDataAccessApproved: true`
- 앱은 이메일이나 profile role 문자열로 관리자 권한을 판정하지 않는다. ID token의 위 두 claim만 사용한다.
- claim 변경 뒤에는 앱이 ID token을 강제 갱신하며, 반영되지 않으면 재로그인이 필요하다.
- 기존 `trainer_profile/me`, 회원, 일정, 레슨일지, 계약 데이터의 owner는 생성 도구가 변경하거나 신규 UID에 귀속하지 않는다.

## one-time 스크립트

파일: `scripts/upsert_platform_admin.mjs`

스크립트는 `functions/package.json`에 이미 선언된 Firebase Admin SDK를 사용한다. 루트나 Functions 의존성을 새로 추가하지 않았다. Application Default Credentials 또는 실행 환경의 `GOOGLE_APPLICATION_CREDENTIALS`를 사용하며 서비스 계정 JSON을 저장소에 두지 않는다.

안전 확인만 수행:

```powershell
node .\scripts\upsert_platform_admin.mjs --dry-run
```

승인된 운영 절차에서만 실제 실행:

```powershell
node .\scripts\upsert_platform_admin.mjs
```

- 실제 실행은 TTY의 숨김 입력으로만 임시 비밀번호를 받는다.
- CLI 평문 인자와 비대화형 stdin은 거부한다.
- 비밀번호를 로그, 결과 객체, 문서 또는 profile에 기록하지 않는다.
- 이메일로 기존 사용자를 찾고, 없으면 생성하며 있으면 UID와 기존 claim을 보존한다.
- 기존 custom claims에 두 관리자 claim을 merge한다.
- canonical profile이 없으면 `linked/Beginner/personal/active`, role `personal`로 생성한다.
- profile에는 `mustChangePassword: true`, `passwordChangedAt: null`, 서버 `platformAdminProvisionedAt`을 기록한다.
- 기존 profile의 `trainerId`가 Auth UID와 다르면 중단한다.
- 재실행 가능하도록 같은 계정과 profile을 갱신하며 legacy migration이나 backfill은 실행하지 않는다.

이번 작업에서는 dry-run을 포함해 실제 Firebase 프로젝트를 대상으로 스크립트를 실행하지 않았다. 순수 테스트는 가짜 Auth/Firestore와 실행 중 생성한 일회성 secret만 사용했다.

## 최초 로그인과 비밀번호 변경

1. 앱이 `trainer_profiles/{uid}`를 읽는다.
2. `mustChangePassword == true`이면 personal, legacy, 관리자 workspace보다 강제 변경 화면을 먼저 표시한다.
3. 사용자가 현재 비밀번호, 새 비밀번호, 확인값을 입력한다.
4. 앱이 Email credential로 재인증하고 Auth 비밀번호를 변경한다.
5. ID token을 강제 갱신한 뒤 비밀번호·credential 없이 `completeInitialPasswordChange`를 호출한다.
6. Function은 non-anonymous 본인, profile trainerId, 최근 `auth_time`을 확인하고 `mustChangePassword: false`, 서버 `passwordChangedAt`을 기록한다.
7. Function까지 성공해야 완료로 판단하고 관리자 workspace 선택을 표시한다.

Function 실패 시 비밀번호 변경 자체가 성공했더라도 workspace gate를 해제하지 않는다. 화면은 민감 입력을 지우고 새 비밀번호로 다시 확인하도록 안내한다.

## workspace 선택

- `platformAdmin == true`: 내 personal workspace 선택 표시.
- 위 claim과 `legacyDataAccessApproved == true`가 모두 있음: 기존 개발 데이터 선택도 표시.
- 일반 계정: 관리자 선택 화면과 버튼을 표시하지 않음.
- 선택은 Auth gate 내부의 현재 세션 상태이며, 로그아웃하면 Guest 진입으로 교체되어 관리자 화면이 남지 않는다.
- workspace 선택은 데이터 owner 변경이나 migration을 의미하지 않는다.

## Rules와 검증

`trainer_profiles/{uid}`의 기존 client update allowlist에는 다음 필드가 없으므로 client 직접 변경이 거부된다.

- `mustChangePassword`
- `passwordChangedAt`
- `platformAdminProvisionedAt`
- `legacyDataAccessApproved`
- 그 밖의 관리자 claim/profile 관리 필드

로컬 demo Auth·Firestore·Functions Emulator에서 비로그인·익명·오래된 인증 거부, 최근 인증 성공, 멱등 완료, tier/role 불변, 위 필드의 client 직접 변경 거부를 확인했다. 실제 배포, 실제 관리자 계정 생성, 실제 재설정 메일 수신은 별도 승인과 실기기 검증 전까지 완료로 간주하지 않는다.
