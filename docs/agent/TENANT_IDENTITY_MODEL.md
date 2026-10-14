# Tenant Identity Model

## 2026-07-15 personal member identity

- 신규 member의 tenant boundary는 `trainerId == non-anonymous Auth UID`와 `workspaceType == personal`의 결합이다.
- `members/{memberId}`의 path ID와 `memberId` 필드는 같고 Function만 생성한다.
- 신규 personal query는 trainerId와 workspaceType을 모두 필터링한다. legacy 전체 members query는 신규 작업공간에서 호출하지 않는다.
- identity/server 필드는 client가 변경하지 못하며 legacy identity 누락 문서를 자동 backfill하지 않는다.

## 2026-07-15 UID personal workspace bootstrap 반영

- non-anonymous Auth UID는 신규 `trainer_profiles/{uid}`의 canonical trainerId다.
- 이 결론은 신규 personal workspace에만 적용하며 legacy 운영 데이터 owner를 해당 UID로 자동 확정하지 않는다.
- Function이 신규 profile을 `trainerId=uid`, `accountState=linked`, `tier=Beginner`, `workspaceType=personal`, `workspaceStatus=active`, `role=personal`로 고정 생성한다.
- 신규 personal profile은 별도 관리자 승인 없이 빈 작업공간에 진입한다.
- `legacyDataAccessApproved`는 기존 `trainer_profile/me`와 legacy 운영 데이터 연결에만 사용한다.
- 조직 membership, Master/Grand Prix 역할, owner migration은 여전히 별도 모델과 승인 근거가 필요하다.
- 익명 Auth UID는 canonical trainerId가 아니며 profile 생성·읽기 대상이 아니다.


## 2026-07-15 계정 기반 1단계 반영

- 앱 진입은 이제 Firebase Auth 상태를 구독하며 미로그인 및 익명 user를 Guest로 분류한다.
- Firebase UID는 계정 identity이지만, 기존 운영 데이터의 canonical trainerId로 자동 승격하지 않는다.
- 연결 계정은 `trainer_profiles/{uid}`가 존재하고 `trainerId == uid`, `legacyDataAccessApproved == true`인 경우에만 legacy 앱 흐름으로 진입한다.
- 이 확인은 읽기 전용이다. `trainer_profile/me` 복사, UID profile 생성, owner backfill, 회원·일정·계약 migration을 수행하지 않는다.
- 현재 Rules가 `trainer_profiles/{uid}` 읽기를 허용하지 않으면 운영 데이터 접근은 차단된다. 필요한 Rules와 승인·migration 절차는 후속 작업이다.
- 계정 상태(`guest/linked/verified/organizationMember`)와 앱 등급은 독립 모델이다.

감사일: 2026-07-15  
상태: **canonical trainer identity 도입 중단**

## 결론

`FirebaseAuth.currentUser.uid`는 장기적으로 개인 강사 owner의 적절한 후보지만, 현재 앱에서는 모든 정상 트레이너 세션에 UID가 존재한다고 보장할 수 없다. 따라서 이번 작업에서 UID를 `trainerId`로 자동 주입하는 identity service, training log repository, member create 변경을 구현하지 않았다.

확인 근거:

- `main.dart`는 Firebase 초기화 후 Auth 상태를 기다리지 않고 앱을 시작한다.
- 모바일 `SplashRouter`는 `trainer_profile/me` 존재와 onboarding 필드만 보고 Home/Onboarding을 선택한다.
- Onboarding은 로그인 확인 없이 `trainer_profile/me`를 직접 merge 저장한다.
- 저장소 앱 코드에는 이메일·소셜·커스텀 토큰·익명 `signIn` 흐름이 없다.
- `authStateChanges`, `idTokenChanges`, `userChanges`를 이용한 Auth gate가 없다.
- 로그아웃과 계정전환 구현도 확인되지 않았다.
- `AuthRoleUtil`과 anatomy만 nullable `currentUser`를 읽으며, 앱 전체 쓰기 흐름의 전제는 아니다.
- `MoreCareSlotService`는 `trainer_profile/me`의 여러 legacy key를 fallback하고 없으면 문자열 `me`를 trainerId로 사용한다. 이 값은 Firebase UID가 아니다.

## canonical trainerId

### 목표 모델

인증 체계가 마련된 뒤 개인 강사 Beginner~Pro의 canonical owner는 다음 하나만 사용한다.

```text
trainerId = FirebaseAuth.currentUser.uid
```

- 표시명, 이메일, 닉네임, `trainer_profile/me`, 문자열 `me`는 owner ID가 아니다.
- `ownerId`, `staffId`, `trainerId`를 동시에 신규 저장하지 않는다.
- canonical 필드는 `trainerId` 하나로 정하고 profile/display 필드는 별도로 유지한다.

### 현재 상태

현재는 위 목표를 보장하는 Auth gate와 profile 결속이 없으므로 canonical trainerId가 **미확정**이다. 기존 `trainer_profile/me`를 현재 UID의 profile로 간주하거나, nullable currentUser가 우연히 있으면 그 UID로 legacy 데이터를 소유 처리하지 않는다.

## Trainer profile 관계

목표 profile 경로는 인증 UID와 직접 결속되어야 한다. 예:

```text
trainer_profiles/{uid}
  trainerId: uid
  displayName: ...
  organizationMemberships: ...
```

현재 `trainer_profile/me`는 모든 계정에서 동일한 고정 문서 ID이고, 내부 trainerId/uid/userId/ownerId fallback도 권위가 검증되지 않는다. migration 전에는 profile 표시값과 owner identity를 혼동하지 않는다.

## 개인 강사와 센터 계정

### 개인 강사 Beginner~Pro

- 목표 owner: 인증된 개인 trainer UID.
- 회원, 일정, training log의 `trainerId`는 해당 UID.
- organizationId/branchId는 원칙적으로 필요하지 않다.

### Master·Grand Prix 센터/조직

현재 코드는 `organizationTier`, `organizationId`, `branchCount` 등을 선택 metadata로 읽고, More Care 요청 경로를 organizationId 유무에 따라 나눈다. 그러나 다음 관계가 정의되지 않았다.

- organization 소유자와 소속 trainer UID의 membership 문서
- branchId와 organizationId의 권위 관계
- 센터 owner/manager/staff가 회원·레슨일지에 접근하는 위임 규칙
- 하나의 Auth UID가 여러 조직 또는 지점에 속할 때 active tenant 선택 방식
- 조직 레슨일지의 canonical owner가 trainer UID인지 organizationId인지

따라서 센터 데이터에 개인 UID만 주입하거나 organizationId를 tenantId로 자동 승격하지 않는다. 최소 모델은 `trainerId`를 작성자/담당 강사로 유지하고, 별도 검증된 organization membership을 통해 조직 접근권을 부여하는 방향이어야 한다.

## 공개 원격서명 예외

회원 공개 서명 사용자는 트레이너 Auth UID를 갖지 않는다. 공개 클라이언트가 fake trainerId를 만들거나 trainer repository를 호출해서는 안 된다.

- 공개 사용자는 opaque token 교환용 서버 API만 호출한다.
- 서버가 token, 만료, 대상 trainingLogId/memberId, 원래 trainerId를 검증한다.
- parent trainerId는 기존 검증된 값에서 보존하고 공개 사용자가 변경하지 못한다.
- 공개 서명 결과는 서버가 제한된 필드만 transaction으로 반영한다.

현재 direct Firestore 공개 서명은 이 모델과 양립하지 않으며 별도 migration이 필요하다.

## 오류 모델 목표

향후 current trainer identity service는 최소한 다음 typed error를 제공한다.

- `unauthenticated`: currentUser가 없음.
- `trainer_profile_missing`: UID에 결속된 profile이 없음.
- `trainer_identity_mismatch`: profile trainerId와 Auth UID가 다름.
- `organization_membership_missing`: 조직 기능에 필요한 검증된 membership이 없음.

UI는 UID, token, 내부 문서 ID를 노출하지 않는다.

## Legacy 정책

- trainerId가 없는 문서는 deny/migration 대상으로 분류한다.
- 표시명, nickname, email 문자열, `trainer`, `me`, member 이름만으로 owner를 추정하지 않는다.
- 정상 앱 저장 중 현재 UID를 legacy trainerId로 자동 backfill하지 않는다.
- 기존 trainerId가 있더라도 Auth export/profile membership과 검증되지 않으면 자동 신뢰하지 않는다.
- 실제 데이터는 승인된 dry-run → 검토 → 백업 → idempotent apply 절차 이후에만 변경한다.

## 도입 단계

1. 실제 인증 방식과 계정 생명주기 결정.
2. 앱 시작 Auth gate, 로그인, 로그아웃, 계정전환 구현.
3. UID 기반 trainer profile과 개인/조직 membership 모델 확정.
4. 신규 member/training log 쓰기에 canonical trainerId 적용.
5. legacy dry-run과 승인 migration.
6. owner-scoped query 전환.
7. Emulator로 Rules 허용/거부 행렬 검증.
8. 승인된 배포 순서로 Rules 적용.

이번 작업에서는 1~3단계가 미확정이라 코드 구현을 중단했다.
