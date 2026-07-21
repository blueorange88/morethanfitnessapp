# Firebase 백업·롤백 계획

감사일: 2026-07-17
대상 project: `more-than-fitness-f6adb`
현재 상태: managed backup schedule 0개, managed backup 0개, PITR disabled, delete protection disabled

이 문서는 실행 계획이다. 이번 감사에서는 export, backup 생성, restore, delete, claim 변경을 실행하지 않았다.

## PITR 주의

PITR를 활성화해도 활성화 이전의 7일 이력이 즉시 생성되지 않는다. 보호 가능한 이력은 활성화 이후 시간이 흐르며 누적된다. 따라서 지금 PITR를 켜는 일은 첫 배포 직전 기존 데이터의 백업을 대신하지 못한다. 첫 실제 배포 전에는 성공 상태와 object 존재를 확인할 수 있는 Firestore managed export를 우선하고, 그 뒤 PITR와 delete protection을 추가 보호 수단으로 검토한다.

## 보호 대상

### Firestore data

- `members`
- `schedules`
- root `training_logs`
- `contracts`, `contractCounters`, `sign_requests`
- `trainer_profile`, `trainer_profiles`
- `member_groups`, `lesson_products`
- `talk_notification_queue`
- `more_care_slot_requests`, `organizations/*/more_care_slot_requests`
- members 아래 `events`, `membership_contracts`, `lesson_ledger`, `client_card`, `training_logs`, `inbody_records`, `goal_ddays`, `care_milestones`, `achievement_badges`
- training_logs 아래 `anatomyRecords`

### Configuration/source

- 현재 production Firestore Rules 원문과 publish metadata
- 현재 production composite indexes 목록
- local `firestore.rules`, `firestore.indexes.json`, `storage.rules`, `firebase.json`
- 배포할 `functions/src`, `functions/package-lock.json`, build 결과가 재생성되는 immutable commit/tag/archive
- Auth provider/domain/template 수동 기록
- 배포 전 각 주요 collection count와 legacy/personal representative document field 목록

Firestore export는 Firebase Auth 사용자, custom claims, Authentication provider 설정, Storage object, Functions source를 포함하지 않는다. 각각 별도로 보존해야 한다.

## 배포 전 백업 go/no-go

1. Console에서 billing plan을 확인한다. Firestore managed export/import는 billing과 Google Cloud Storage가 필요하므로 사용할 수 없는 plan이면 실행하지 않는다.
2. Firestore location은 `asia-northeast3`이다. export bucket의 실제 location과 retention/versioning을 확인한다. 현재 Firebase Storage bucket을 확인 없이 backup bucket으로 재사용하지 않는다.
3. caller와 Firestore service agent에 필요한 Firestore export/import와 bucket IAM만 최소 부여한다.
4. backup prefix는 날짜·release ID로 불변하게 만든다.
5. export operation이 성공 상태가 되고 object 목록이 보이기 전에는 deploy하지 않는다.
6. collection count와 sample document metadata를 export 전후에 기록한다.
7. export를 사용할 수 없으면 아래 최소 수동 백업을 수행하고 데이터 소유자의 서면 승인을 받아야 한다. 승인 없이는 NO-GO다.

현재 `firestore:databases:list`는 database `freeTier: true`를 보여 주지만 이것만으로 Firebase billing plan을 단정하지 않는다. Console billing 확인이 필요하다.

## Firestore managed export 초안

실행하지 않은 PowerShell 초안이다. bucket 이름과 release ID는 실제 승인 때 채운다.

```powershell
$ProjectId = 'more-than-fitness-f6adb'
$DatabaseId = '(default)'
$BackupBucket = 'gs://REPLACE_WITH_APPROVED_BACKUP_BUCKET'
$ReleaseId = 'pre-anonymous-release-YYYYMMDD-HHmm'

# 실행 전: gcloud auth/account/project, billing, bucket location/IAM을 수동 확인
gcloud firestore export "$BackupBucket/$ReleaseId" --project $ProjectId --database $DatabaseId

# operation success와 bucket object를 별도로 확인한 뒤에만 다음 단계 진행
```

전체 export가 기본안이다. collection별 export는 subcollection 관계와 누락 위험 때문에 대체안으로만 사용한다. 실제 command는 이번 감사에서 실행하지 않았다.

## 최소 수동 백업 대체안

managed export가 불가능한 경우에만 사용한다.

- Console에서 현재 Rules 전체와 publish metadata 저장
- `firebase functions:list`, `firestore:indexes`, database metadata JSON을 read-only 캡처
- 주요 root collection별 count 기록
- legacy와 personal schema별 representative document field/key 목록 기록. 개인정보 값은 문서에 복사하지 않음
- 계약·서명·회차·training log처럼 복구가 어려운 collection은 승인된 read-only Admin export 도구로 JSONL/CSV를 암호화 저장
- Storage object는 bucket inventory/count와 versioning 상태만 먼저 기록하고, object copy는 별도 승인
- Auth user/claims는 개인정보 취급 절차가 필요하므로 이번 작업에서 export하지 않음

최소 수동 백업은 managed export와 동등한 복구 보장이 아니다. 데이터 소유자가 이 제한을 승인하지 않으면 배포하지 않는다.

## Rules rollback

가장 먼저 수행할 rollback이다.

1. 앱 신규 배포/테스트를 중지한다.
2. predeploy에 저장한 production Rules 원문이 정확한 project의 것인지 재확인한다.
3. rollback 전용 config가 backup Rules 파일만 가리키게 한다.
4. Rules만 재배포한다. Functions/index/storage와 묶지 않는다.
5. legacy admin과 일반/anonymous deny smoke를 즉시 수행한다.

실행하지 않은 예시:

```powershell
$ProjectId = 'more-than-fitness-f6adb'
npx.cmd firebase deploy --project $ProjectId --config .\backups\firebase\RELEASE_ID\firebase.rules.rollback.json --only "firestore:rules"
```

rollback config와 Rules backup 파일은 실제 배포 전에 별도 생성·검토해야 한다. 현재 repository에는 해당 predeploy backup이 없으므로 지금은 Rules rollback 준비가 완료되지 않았다.

## Index rollback

현재 production composite index는 0개이고 local 후보는 2개다. index 생성은 데이터 내용을 바꾸지 않지만 build 시간과 query availability에 영향을 준다.

- Rules rollback과 앱 중단을 먼저 수행한다.
- index가 문제의 직접 원인이 아니면 즉시 삭제하지 않는다.
- 삭제가 필요하면 Console에서 정확한 collection group/field/order 두 개를 대조하고 한 개씩 제거한다.
- `--force` 또는 local 파일 전체를 기준으로 한 일괄 삭제를 사용하지 않는다.
- index 제거 전에 해당 query가 더 이상 release app에서 실행되지 않는지 확인한다.

## Functions rollback

현재 deployed Functions가 0개라 이전 cloud revision/source가 없다. 따라서 첫 배포 전 immutable source checkpoint가 필수다.

### 안전한 우선순위

1. 문제가 있는 기능의 app 진입을 중지한다.
2. Rules를 이전 버전으로 되돌려 client write 노출을 닫는다.
3. 이전에 승인된 source revision이 있으면 해당 function 이름만 재배포한다.
4. 이전 revision이 전혀 없고 함수가 위험한 write를 수행한다면 신규 함수만 개별 삭제한다.
5. 이미 완료된 Firestore transaction은 자동 역변경하지 않고 audit 후 보정한다.

실행하지 않은 삭제 초안:

```powershell
$ProjectId = 'more-than-fitness-f6adb'
npx.cmd firebase functions:delete bootstrapAnonymousBeginnerProfile --region asia-northeast3 --project $ProjectId
```

여러 함수를 한 번에 삭제하지 않는다. `--force` 없이 operator가 이름/project/region을 다시 확인한다. profile/member/training log 데이터는 함수 삭제와 함께 삭제하지 않는다.

## Auth provider·관리자 rollback

- Anonymous provider를 끄면 기존 anonymous 사용자의 재인증/신규 진입이 막힐 수 있지만 Firestore 문서는 삭제되지 않는다. 즉시 비활성화하기 전에 앱 중단과 기존 UID 데이터 보존 계획을 승인한다.
- Email/Password provider를 끄면 linked 계정 복구가 막힌다. template/domain 문제와 provider 자체를 구분한다.
- 관리자 claims는 이메일이나 표시 이름으로 수정하지 않는다. UID를 재확인하고 `platformAdmin`, `legacyDataAccessApproved`만 제거하는 검토된 Admin SDK 절차를 사용한다.
- claim 제거 후 refresh token revoke와 재로그인 검증이 필요하다.
- 현재 repository에는 claim 제거 전용 승인 스크립트가 확인되지 않았으므로 명령을 추측해 만들지 않는다.

## Anonymous 신규 데이터 rollback 정책

- 신규 anonymous profile/member/schedule/training log를 legacy 데이터에 병합하거나 자동 귀속하지 않는다.
- release 중 생성된 문서는 `trainerId`와 `workspaceType=personal`로 식별해 보존한다.
- backup import는 merge 성격과 충돌 가능성이 있어 “이전 시점 전체 덮어쓰기”로 간주하지 않는다.
- restore가 필요하면 target database/collection, document conflict, release 이후 정상 데이터 보존을 별도 승인한다.
- orphan profile이나 테스트 회원 삭제는 이 rollback의 자동 단계가 아니다.

## 복구 완료 기준

- 이전 Rules가 publish됐고 legacy/anonymous/linked 접근 행렬이 예상과 일치
- 배포된 Function 목록이 승인된 목록과 일치
- owner가 다른 UID의 데이터가 노출되지 않음
- 기존 legacy count와 representative documents가 보존됨
- 회차·통계·training log transaction audit가 일치
- 관리자 claims/token 상태가 승인된 값과 일치
- incident timeline, 실행 command, operator, 결과를 RUN_LOG와 별도 운영 기록에 남김

현재는 backup/rollback **계획만 존재하며 실행 준비 완료 상태가 아니다**.
