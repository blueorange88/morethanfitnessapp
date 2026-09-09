# Firestore Rules·Index 배포 매트릭스

감사일: 2026-07-17
대상: 로컬 `firestore.rules`, `firestore.indexes.json`, production `(default)` database
Production database: `asia-northeast3`, Native mode, Standard edition

Firebase CLI 15.23.0은 현재 배포 Rules 원문 조회 명령을 제공하지 않는다. 따라서 아래 권한표는 **로컬 후보 Rules** 기준이며, production Rules와의 diff는 Console에서 현재 published source를 복사하기 전까지 확정할 수 없다. 현재 production composite index 조회 결과는 0개다.

## 권한 영향표

| 경로 | Anonymous personal | Linked personal | Platform admin + legacy 승인 | Client direct write | Function/Admin write | owner query 요건 | 기존 데이터 영향 | 첫 배포 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `trainer_profiles/{uid}` | 본인 read, client create/delete/update 거부 | 본인 read, 표시명 등 제한 필드 update | 자기 UID read/update. claim만으로 다른 UID profile read 불가 | linked owner의 제한 update만 | bootstrap/link/profile/tier Function은 Admin SDK로 write | 문서 ID가 Auth UID | `trainer_profile/me`를 복사·귀속하지 않음 | 필수 |
| `trainer_profile/me` | 거부 | 거부 | 두 claim + 비밀번호 변경 완료 시 read/create/update | legacy admin만 | 필요 시 Admin SDK 우회 가능 | 단일 legacy 문서 | 기존 legacy profile 유지 | legacy 보존에 필수 |
| `members/{memberId}` | 본인 `trainerId` + `personal` read | 동일 | workspaceType이 personal이 아닌 legacy 문서 read/create/update | personal create/update/delete 거부 | managed member Functions가 canonical write | `trainerId == uid`, `workspaceType == personal` | owner 없는 legacy를 새 UID에 귀속하지 않음 | 필수 |
| `members/{id}/events/*` | 거부 | 거부 | legacy member일 때 read/create | legacy admin create만 | legacy Functions는 Admin SDK로 Rules 우회 | 상위 legacy member 확인 | 기존 event 보존 | Anonymous에는 비필수 |
| `members/{id}/membership_contracts/*` | 거부 | 거부 | legacy member read/create/update | legacy admin | Admin SDK 가능 | 상위 legacy member 확인 | personal 계약은 열리지 않음 | 비필수 |
| `members/{id}/lesson_ledger/*` | 직접 client 거부 | 직접 client 거부 | legacy member read/create/update | legacy admin | personal finalize/cancel Function이 Admin SDK로 write | Function에서 member owner 확인 | personal ledger는 client에 노출하지 않음 | Function과 함께 필수 |
| `members/{id}/client_card/*` | 거부 | 거부 | legacy member read/create/update | legacy admin | Admin SDK 가능 | 상위 legacy member 확인 | legacy 전용 | 비필수 |
| `members/{id}/training_logs/*` | 거부 | 거부 | legacy member read/create/update | legacy admin | 별도 root personal log와 무관 | 상위 legacy member 확인 | nested legacy 경로 유지 | 비필수 |
| `members/{id}/inbody_records/*` 등 감사된 card 하위 컬렉션 | 거부 | 거부 | legacy member CRUD | legacy admin | Admin SDK 가능 | 상위 legacy member 확인 | personal에 자동 공개하지 않음 | 비필수 |
| `member_groups/{groupId}` | 거부 | 거부 | CRUD | legacy admin | Admin SDK 가능 | legacy claim | 기존 그룹 유지 | 비필수 |
| `schedules/{scheduleId}` | 본인 personal read/create/update/delete | 동일 | legacy 문서 CRUD | personal owner가 schema/관계/확정 잠금 조건 아래 CRUD | 확정 Function이 Admin SDK로 update | 모든 list에 `trainerId == uid`, `workspaceType == personal`, 기간 조건 | owner 없는 legacy는 admin만. backfill 없음 | 필수 |
| `training_logs/{lessonLogId}` | 본인 personal read, draft create/update/delete | 동일 | legacy 문서 CRUD | draft와 제한 필드만 | finalize/cancel Function이 상태·회차·통계를 transaction write | list에 `trainerId == uid`, `workspaceType == personal`, member/date 조건 | owner 없는 legacy는 admin만 | 필수 |
| `training_logs/{lessonLogId}/anatomyRecords/{id}` | 거부 | 거부 | CRUD | legacy admin만 | 현재 personal anatomy Function 없음 | parent owner만으로도 아직 허용하지 않음 | orphan/identity 정책 유지 | 제외 |
| `contracts/{contractId}` | 거부 | 거부 | read/create/update | legacy admin | personal 계약 Function 없음 | legacy claim | personal 계약 미개방 | 제외 |
| `contractCounters/{counterId}` | 거부 | 거부 | read/create/update | legacy admin | Admin SDK 가능 | legacy claim | 기존 counter 유지 | 제외 |
| `sign_requests/{requestId}` | 거부 | 거부 | read/create/update | legacy admin | 공개 원격서명 Function 없음 | legacy claim | 공개 direct read/write 계속 거부 | 제외 |
| `lesson_products/{productId}` | 거부 | 거부 | read/create/update | legacy admin | Admin SDK 가능 | legacy claim | personal 상품 미개방 | 제외 |
| `talk_notification_queue/{id}` | 거부 | 거부 | read/create | legacy admin create | 발송 worker 확인 필요 | legacy claim | notification queue 확대 없음 | 제외 |
| `more_care_slot_requests/{id}` | 거부 | 거부 | read/create/update | legacy admin | Admin SDK 가능 | legacy claim | 문자열 `me` fallback 경로를 personal에 열지 않음 | 제외 |
| `organizations/{orgId}/more_care_slot_requests/{id}` | 거부 | 거부 | read/create/update | legacy admin | Admin SDK 가능 | legacy claim | 조직 권한 확대 없음 | 제외 |
| 나머지 경로 | 거부 | 거부 | 거부 | 없음 | Admin SDK만 가능 | 해당 없음 | 암시적 deny 유지 | 제외 |

Admin SDK Cloud Functions는 Firestore Rules를 우회한다. 그러므로 client deny가 Function transaction까지 막는다고 해석하면 안 된다.

## query·index 전수 감사

| Query | 실제 조건 | 로컬 composite index | Production | 판정 |
| --- | --- | --- | --- | --- |
| personal 회원 목록 | `members`: trainerId equality + workspaceType equality | 없음 | 없음 | equality-only라 single-field index merging 후보. client sort/filter는 memory에서 수행 |
| 회원 전화 중복 | `members`: trainerId equality + workspaceType equality + phoneNormalized equality + limit 2 | 없음 | 없음 | equality-only query로 composite를 만들지 않음. 기본 single-field index와 index merging 사용 |
| personal 주간 일정 | `schedules`: trainerId equality + workspaceType equality + startAt range | `trainerId ASC, workspaceType ASC, startAt ASC` | 없음 | 로컬 정의 있음, production 배포 필수 |
| 회원별 personal 레슨일지 | `training_logs`: trainerId equality + workspaceType equality + memberId equality + startAt range/order desc | `trainerId ASC, workspaceType ASC, memberId ASC, startAt DESC` | 없음 | 로컬 정의 있음, production 배포 필수 |
| 레슨일지 status filter | 현재 Firestore query 없음. UI가 반환 목록을 memory filter | 없음 | 없음 | 존재하지 않는 status index를 추측해 추가하지 않음 |

`firestore.indexes.json`의 두 index는 현재 query와 정확히 맞으며 중복 정의는 없다. Production에는 둘 다 없으므로 Rules/app smoke 전에 `firestore:indexes`만 별도 배포하고 Console에서 상태가 `Enabled`가 될 때까지 기다려야 한다.

members의 세 조건은 equality-only라 불필요한 composite를 만들지 않았다. production smoke에서 예상 밖 `FAILED_PRECONDITION`이 발생하면 링크를 그대로 적용하지 말고 실제 query와 single-field exemption을 다시 감사한 뒤 중단한다.

## 현재 deployed Rules 확보 절차

배포 승인 전에 Firebase Console에서 다음을 수동 수행한다.

1. Project `more-than-fitness-f6adb`를 다시 확인한다.
2. Firestore Database → Rules에서 현재 Published source 전체를 복사한다.
3. publish timestamp/release identifier와 함께 변경 불가 백업 파일로 저장한다.
4. 로컬 `firestore.rules`와 text diff를 검토한다.
5. 기존 production 문서 표본이 local legacy predicate와 호환되는지 확인한다.
6. 차이가 이해되지 않으면 Rules 배포는 NO-GO다.

## 배포 명령 초안

실행하지 않은 PowerShell 초안이다.

```powershell
Set-Location C:\src\mtf_app
$ProjectId = 'more-than-fitness-f6adb'

npx.cmd firebase firestore:indexes --project $ProjectId
npx.cmd firebase deploy --project $ProjectId --only "firestore:indexes"

# Console에서 두 index가 Enabled인지 확인한 뒤에만 실행
npx.cmd firebase deploy --project $ProjectId --only "firestore:rules"
```

`firestore:indexes`와 `firestore:rules`는 같은 명령으로 묶지 않는다. `--force`를 사용하지 않는다. Storage Rules는 이 첫 배포 명령에 포함하지 않는다.

## Rules go/no-go

- [ ] 현재 Published Rules 원문과 release metadata 백업 완료
- [ ] local-vs-production Rules diff의 collection별 승인 완료
- [ ] production 주요 collection count와 legacy 표본 호환 확인
- [ ] 두 local composite index가 production에서 `Enabled`
- [ ] member equality query의 production smoke 성공
- [ ] Anonymous/Linked/Legacy Emulator 168개 재통과
- [ ] rollback config와 담당자 준비

현재 판정은 **NO-GO**다. Rules와 index는 실제 배포하지 않았다.
