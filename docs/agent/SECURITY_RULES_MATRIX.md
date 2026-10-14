# 계약·서명 보안 및 Rules 매트릭스

## 2026-07-16 Anonymous/Linked personal training_logs 최소 Rules

| 경로 | read | create | update | delete |
| --- | --- | --- | --- | --- |
| `training_logs/{lessonLogId}` personal | 로그인한 본인 UID + personal | draft canonical 필드, 본인 member, 선택한 본인 schedule 관계만 | draft의 일정·일시·종류·메모 자동저장만 | 본인 draft만 |
| finalized personal log | 본인 read만 | Function 전용 | client 거부 | client 거부 |
| legacy training log | 기존 두 관리자 claim 조건 유지 | 기존 관리자 조건 | 기존 관리자 조건 | 기존 관리자 조건 |
| `anatomyRecords` child | legacy 관리자만 | legacy 관리자만 | legacy 관리자만 | legacy 관리자만 |

- create는 `lessonLogId == documentId`, `trainerId == Auth UID`, `workspaceType=personal`, `schemaVersion=1`, `status=draft`, 서버 timestamp를 강제한다.
- member는 같은 UID의 personal canonical 회원이어야 한다. scheduleDocId가 있으면 같은 UID/personal이며 schedule memberId와 log memberId도 같아야 한다. 이름만 있는 미연결 일정은 관계로 사용할 수 없다.
- client는 finalized status, 차감 증거, 통계, owner/member identity를 쓰지 못한다. 확정·취소 server field는 Admin SDK Function transaction만 변경한다.
- 앱 query는 trainerId·workspaceType·memberId·기간을 포함한다. owner 없는 root query, 다른 UID, legacy 문서는 Emulator에서 거부됨을 확인했다.
- contracts, sign_requests 및 Storage Rules는 변경하지 않았다. personal anatomy child도 계속 닫혀 있다.

## 2026-07-16 Anonymous/Linked personal schedules 최소 Rules

| 경로 | read | create | update | delete |
| --- | --- | --- | --- | --- |
| `schedules/{scheduleId}` personal | 로그인한 본인 UID + `workspaceType == personal` | 본인 UID, canonical 필드, 서버 timestamp, 유효 시간·회원 연결만 | owner·workspace·scheduleId·schemaVersion·createdAt 불변, 허용 필드만, 확정 일정 제외 | 본인 소유이며 미확정 일정만 |
| `schedules/{scheduleId}` legacy | 두 관리자 claim과 비밀번호 변경 완료 조건 유지 | 기존 legacy 관리자 조건 유지 | 기존 legacy 관리자 조건 유지 | 기존 legacy 관리자 조건 유지 |

- 앱 목록 query는 `trainerId == current uid`, `workspaceType == personal`, `startAt` 기간 조건을 모두 사용한다. owner 조건 없는 root query, 다른 UID, owner 없는 legacy 문서는 Emulator에서 거부됨을 확인했다.
- 신규 personal 문서는 Firestore random document ID를 사용하며 `scheduleId == documentId`를 강제한다. 이동은 같은 문서 transaction update라 부분 delete 위험이 없다.
- 연결 회원은 같은 UID의 `workspaceType=personal`이며 삭제 상태가 아닌 문서만 허용한다. 이름만 입력한 일정에는 `memberId`가 없고 회원 생성 Function을 호출하지 않는다.
- training_logs, contracts, anatomy 및 Storage Rules는 이번 단계에서 변경하지 않았다. 실제 Firebase 배포도 실행하지 않았다.

## 2026-07-16 Anonymous personal members 최소 Rules

| 경로 | read | create | update | delete |
| --- | --- | --- | --- | --- |
| `members/{memberId}` personal | 로그인한 본인 UID + `workspaceType == personal` | client 거부 | client 거부 | client 거부 |

- 익명 사용자도 `trainerId == request.auth.uid`와 personal workspace 조건을 만족한 자기 회원만 읽을 수 있다. 앱 query도 두 필터를 모두 포함한다.
- 회원 생성·수정·상태 전환, 누적 수와 등급 갱신, owner-scoped 전화번호 중복 조회는 Admin SDK Function transaction만 수행한다.
- schedules, training_logs, contracts Rules는 이번 작업에서 변경하지 않았고 익명 접근 Emulator 회귀 테스트도 계속 거부된다.
- 실제 Firebase 프로젝트에는 배포하지 않았다.

## 2026-07-15 members 최소 Rules

| 경로 | read | create | update | delete |
| --- | --- | --- | --- | --- |
| `members/{memberId}` personal | 로그인한 owner + personal만 | client 거부 | client 거부 | client 거부 |
| `members/{memberId}` legacy | 기존 role claim staff만 | staff이면서 personal이 아닌 문서만 | staff이면서 기존/신규 모두 personal이 아닌 문서만 | 거부 |

신규 Linked Beginner는 owner/workspace 필터를 포함한 query만 허용된다. trainerId 없는 legacy, 다른 trainer 문서, 필터 없는 전체 query는 거부된다. Admin SDK Functions가 canonical 생성·수정·상태 전환을 수행한다. 다른 collection Rules는 이번 작업에서 변경하지 않았다.

## 2026-07-15 trainer_profiles 최소 Rules

| 경로 | read | create | update | delete |
|---|---|---|---|---|
| `trainer_profiles/{uid}` | non-anonymous 본인 UID만 허용 | client 거부, Admin Function만 생성 | 본인 표시 필드 allowlist + server updatedAt만 허용 | client 거부 |

- anonymous, 비로그인, 타인 UID read/update를 거부한다.
- tier, role, organizationId, trainerId, accountState, workspaceType/status, schemaVersion, createdAt은 client 변경 불가다.
- Auth·Firestore·Functions Emulator 30개 시나리오가 통과했다.
- 이번 Rules 변경은 `trainer_profiles/{uid}`에만 해당한다. members, schedules, training_logs, contracts, sign_requests 및 Storage Rules는 변경하지 않았다.
- 기존 `members` Rules의 signed-in broad read 위험은 그대로 남아 있으므로 신규 personal workspace UI는 legacy Home/회원관리 흐름을 열지 않는다.


감사일: 2026-07-15

기준: 저장소의 `firestore.rules`, 빈 `storage.rules`, `firebase.json`, 현재 앱 query/write. 실제 배포 Rules는 확인하지 않았다.

## 저장소 Rules 현황

- Firestore Rules는 `members/{memberId}`와 그 하위 `events/{eventId}`만 정의한다. 그 밖의 경로는 default deny다.
- `members` read는 로그인 사용자 모두에게 허용되며 owner/trainer 조건이 없다.
- 비스태프도 로그인 상태면 임의 `members/{memberId}`의 제한 필드(name, phone, address, detailAddress, trainer, note, health)를 수정할 수 있다. 본인 회원 문서인지 확인하는 조건이 없다.
- `membership_contracts`와 `lesson_ledger`는 `members` match의 권한을 자동 상속하지 않으며 별도 match가 없으므로 거부된다.
- `storage.rules`는 내용이 없다. `firebase.json`에도 Firestore/Storage rules 및 index 파일 연결 항목이 없다. 이 파일 상태로 Storage 권한을 판단하거나 배포할 수 없다.
- Functions에는 `chargeOnce`, `cancelNoShow`, `lockConsent`, `unlockConsent`만 있고 계약/서명 토큰 검증 Function은 없다.

## 경로별 매트릭스

| 경로 | 현재 read caller | 현재 write caller | owner 필드 | 인증/현재 Rules | 교차 접근 및 공개 링크 위험 | 인덱스/Storage |
|---|---|---|---|---|---|---|
| `members/{memberId}` | 회원목록, 홈, 회원카드, 계약서, 공개 서명 Web | 여러 화면/서비스 | 일관된 `trainerId/ownerId` 없음 | 로그인 누구나 read; staff create/update; 비staff도 제한 필드 임의 member update 가능 | P0: tenant 격리 없음. 공개 Web은 비로그인이면 현재 Rules상 실패 | 앱은 전체 collection query 다수. owner index 설계 필요 |
| `members/{id}/events/{eventId}` | Functions/관리 흐름 | `chargeOnce`, `cancelNoShow` | 상위 owner 없음 | staff read/create, update/delete false. `cancelNoShow` Admin SDK는 Rules 우회 | 이벤트 update가 Rules에서 금지지만 Function은 가능 | append-only 성격이나 owner 검증은 role뿐 |
| `members/{id}/membership_contracts/current` | 회원권계약서 | 회원권 초안/서명/보관 | 없음 | 별도 match 없어 거부 | 배포 Rules가 다르면 memberId만으로 다른 회원 계약 접근 여부 확인 필요 | 단일 `current`; version index 없음 |
| `members/{id}/lesson_ledger/{logId}` | 레슨확정/취소 | confirmation/cancel transaction | 상위 owner 없음 | 별도 match 없어 거부 | tenant 경계와 append-only 강제 없음 | 안정 ID를 쓰지만 Rules 미정의 |
| `contracts/{contractId}` | 계약 목록/상세 | 계약 저장, 완료, delivery, soft delete | 없음 | match 없어 거부 | query가 owner filter 없이 전체 상위 50건. 허용 시 P0 교차 노출 | `updatedAt desc` 단일 인덱스는 자동 가능. owner+status+updatedAt 복합 필요 |
| `contractCounters/{yyyy-MM}` | 계약번호 생성 | client transaction | 없음 | match 없어 거부 | 허용 시 번호 경쟁/조작 경계 필요 | 서버 발급 권장 |
| `sign_requests/{token}` | 공개 Web, trainer 앱 재사용 조회 | trainer 앱 생성/취소, 공개 Web submit | 없음 | match 없어 거부 | 토큰 문서에 PII와 대상 ID 포함. client direct access를 허용하면 최소 권한 Rules 작성이 매우 어려움 | `trainingLogId` query는 단일 인덱스 자동 가능 |
| `training_logs/{logId}` | 레슨일지, 공개 Web 서명 이력 | quick sign, 공개 Web, confirmation/cancel | 일부 문서에도 일관된 owner 없음 | match 없어 거부 | 공개 Web이 memberId 조건으로 전체 signed logs 조회. 허용 시 다른 데이터 노출 위험 | memberId+memberSigned query는 복합 인덱스가 필요할 수 있으나 저장소 indexes는 비어 있음 |
| `training_logs/{lessonLogId}/anatomyRecords/{anatomyLogId}` | anatomy 화면 | `AnatomyLogService.save` transaction | 자식 `trainerId`; 서비스는 부모 owner/member를 요구하지만 quick/confirm/web parent 생성 경로에는 owner가 없음 | match 없어 인증 staff도 전부 거부 | 단순 `isStaff()` 또는 child trainer만 보고 열 수 없음. parent owner schema/migration이 선행돼야 함 | parent query의 trainerId 조건과 child identity 조건 필요. Emulator 미검증 |
| `schedules/{scheduleId}` | 홈/레슨일지 | 홈, confirm/cancel | 일관된 owner 확인 불가 | match 없어 거부 | 허용 Rules가 broad면 다른 강사 일정 접근 | owner+startAt 등 실제 query에 맞춘 복합 index 필요 |
| `re_registration_requests/{id}` | 확인 불가 | 공개 서명 Web | 없음 | match 없어 거부 | 공개 비로그인 임의 생성 방지 필요 | Function 경유 권장 |
| `talk_notification_queue/{id}` | 발송 worker 확인 불가 | 확정취소 흐름 | 없음 | match 없어 거부 | client가 queue status를 실제 발송처럼 만들 가능성. 서버 worker/owner 검증 필요 | provider status index 필요 가능 |
| `trainer_profile/{id}` 및 제품/설정 계열 | 마이페이지/계약 | 앱 | 서비스별 상이 | match 없어 거부 | tenant root 설계 부재 | 저장소 전체 query 감사 후 설계 |
| `membership_contract_signatures/{memberId}/...` | 회원권계약서 이미지 표시 | client upload | 경로에 memberId만 있음 | `storage.rules` 비어 판정 불가 | download URL 유출, 교차 접근, 영구 URL/삭제 정책 위험 | owner/contractVersion 경로와 content type/size 제한 필요 |
| `membership_contract_images/{memberId}/...` | 회원권 보관 이미지 | client upload | 경로에 memberId만 있음 | 판정 불가 | 화면 캡처에 개인정보 포함, 고아 파일 가능 | version ID/hash/retention 필요 |
| anatomy/영상 Storage | 영상은 준비 중이며 현재 anatomy record는 Firestore만 사용 | 현재 업로드 없음 | 미정 | 판정 불가 | 계약·anatomy owner 경계 확정 전 회원 공개 금지 권장 | 후속 Rules/Storage 설계 필요 |

## Rules와 앱 호환성 결론

1. 저장소 Rules를 그대로 적용하면 계약서, 회원권계약서, 일정, 레슨일지, 원격 서명의 대부분이 `permission-denied`다.
2. 실제 기기에서 이 기능들이 동작한다면 다음 중 하나다: 배포 Rules가 저장소와 다름, emulator/다른 프로젝트를 사용함, 또는 일부 경로가 Admin SDK를 경유함. 현재 코드만으로 어느 경우인지 확인할 수 없다.
3. 배포 Rules를 읽기 전에는 “현재 권한이 안전하다” 또는 “원격 서명이 정상 작동한다”고 결론 내릴 수 없다.
4. `firebase.json`이 rules/index 파일을 가리키지 않으므로 배포 재현성도 없다.

## Anatomy 현재 권한과 최소 조건

### 08 Rules 구현 사전 감사 결과

`TRAINING_LOG_RULES_AUDIT.md`에서 루트 training log의 모든 직접 read/write를 다시 확인했다. 빠른서명, 홈확정, 공개 원격서명 parent payload에 공통 `trainerId/lessonLogId`가 없고, merge 기반 차감·취소는 identity 없는 parent를 만들 수 있다. `members`에도 Auth UID 기반 owner가 일관되지 않으며, 공개 원격서명은 비로그인 direct write다.

이 상태에서는 parent create/update allowlist와 member 소유권을 안전하게 정의할 수 없어 `firestore.rules`를 변경하지 않았다. Firebase CLI와 기존 Rules unit test 환경도 없지만, 환경 구성 이전에 데이터 계약 중단 조건이 충족됐다. Emulator 결과가 없으므로 Rules 완료로 판단하지 않는다.

### 현재 결론

- 저장소 Rules에는 부모 `training_logs`와 하위 `anatomyRecords` match가 모두 없다. 현재 파일이 배포 기준이면 읽기·생성·수정·삭제는 전부 `permission-denied`다.
- 현재 앱의 `training_logs.where(memberId == ...)` anatomy 부모 목록 query에는 trainer filter가 없다. owner 기반 Rules를 추가하면 query도 같은 owner 조건을 포함해야 한다. Rules는 결과를 필터링하지 않으므로 owner 조건 없는 collection query를 허용해서는 안 된다.
- `AnatomyLogService.load`는 현재 Auth UID와 parent trainer/member를 먼저 검증하고 child identity 불일치를 로그로 남긴다. 다만 child collection을 조건 없이 읽으므로 엄격한 child list Rule과의 query 호환성은 Emulator로 확인하고 필요한 identity filter를 추가해야 한다.
- 부모 training log에는 quick sign/home confirm/remote sign 생성 경로에서 `trainerId`가 저장되지 않는다. 서비스는 이를 `legacy_parent_missing_identity`로 차단하고 backfill하지 않으며, Rules에서도 먼저 접근한 staff가 owner를 주장하는 fallback을 허용하면 안 된다.

### 최소 권한 불변조건

실제 Rules 문법과 배포는 별도 승인 작업이며, 최소 정책은 다음 조건을 모두 만족해야 한다.

1. 모든 접근은 `isStaff()`와 인증 UID를 요구한다.
2. child read/create/update/delete 전에 부모 `training_logs/{lessonLogId}`가 존재해야 한다.
3. 부모가 soft deleted/voided 정책상 비공개 상태면 child 접근을 거부한다. `voided` 레슨을 기록 보존 목적으로 읽어야 하는지 정책 결정이 필요하다.
4. 부모의 신뢰 가능한 `trainerId == request.auth.uid`이고 child의 `trainerId`도 같아야 한다.
5. child `memberId == parent.memberId`, child `lessonLogId == path lessonLogId`, child `anatomyLogId == path anatomyLogId`여야 한다.
6. `scheduleDocId`는 필수로 만들지 않는다. 부모와 자식 중 값이 있으면 `child.scheduleDocId == parent.scheduleDocId`를 요구하고 둘 다 없으면 허용한다.
7. update에서 `anatomyLogId`, `lessonLogId`, `trainerId`, `memberId`는 기존 값과 같아야 한다. schedule 연결 변경은 일반 update가 아니라 별도 감사 작업으로 제한한다.
8. delete는 기존 child와 부모의 owner/member/path 정합성을 모두 확인한다.
9. 부모 create를 anatomy child 저장의 부수 효과로 허용하지 않는다. 정식 training log 생성 경로에서 owner/member를 검증해 먼저 만든다.
10. 부모의 anatomy metadata update는 owner에게 `anatomySchemaVersion`, `hasAnatomyRecords`, `anatomyRecordCount`, `updatedAt` 같은 허용 필드만 열거나 서버에서 수행한다.

owner 없는 과거 부모 문서는 바로 공개하지 말고, schedule 작성자/서버 감사 자료처럼 신뢰 가능한 근거로 승인된 backfill을 한 뒤 접근시켜야 한다. memberId만 같다는 이유로 owner를 정하면 안 된다.

### 다른 트레이너 접근 가능성

- 현재 저장소 Rules: 모든 trainer의 anatomy 접근이 거부되므로 교차 접근도 불가능하다.
- 현재 코드 + broad deployed Rules: 부모 목록 query에 trainer filter가 없어 서비스 진입 전 parent 정보가 교차 조회될 수 있다. child service 검증만으로 parent collection 보안을 대신할 수 없다.
- `ANATOMY_DATA_MODEL.md`의 최소 조건은 방향 문서일 뿐 배포 가능한 Rules가 아니다. parent owner schema/migration과 40개 Emulator 행렬이 완료되기 전에는 그대로 구현·배포하지 않는다.

### 상위 로그 삭제 정책

- Firestore의 부모 삭제는 하위 collection을 삭제하지 않는다.
- 최소 Rules는 `exists(parent)`와 owner를 검사해 고아 child를 즉시 비공개로 만들어야 한다.
- 실제 삭제는 client cascade가 아니라 보존기간과 건강정보 정책을 거친 서버 관리 recursive cleanup으로 수행하고, lessonLogId·삭제 건수·실행자·시각을 감사 로그로 남긴다.
- 현재 코드에서 training log hard delete는 찾지 못했고 확정 취소는 `voided` merge다. 실제 관리자/서버 삭제 경로는 확인 불가다.

## 최소 보안 수정 방향

### P0

- 실제 배포 Firestore/Storage Rules를 export해 저장소와 차이를 검토한다.
- 모든 보호 문서에 신뢰 가능한 `tenantId`와 `ownerId/trainerId`를 서버가 기록한다.
- 앱 query에 동일한 owner 조건을 추가하고 Rules는 `request.auth.uid` 또는 서버 관리 membership으로 검증한다.
- 공개 서명은 Firestore direct read/write를 금지하고 Function에서 opaque token을 검증해 최소 payload만 반환한다.
- 완료 계약 revision은 client update를 거부하고 서버 전이만 허용한다.

### P1

- Storage 경로를 `{tenantId}/{contractVersionId}/{artifactId}`로 격리하고 size/contentType, create-only, download 권한, 삭제/보존 정책을 명시한다.
- soft delete 문서는 일반 list/read에서 Rules 또는 서버 API로 제외한다.
- notification queue는 client 직접 쓰기보다 검증 Function과 worker receipt를 사용한다.
- 필요한 복합 index를 실제 query 목록에서 생성하고 `firebase.json`에 rules/index 연결을 명시한다.

### P2

- App Check, rate limiting, audit log 보존기간, token attempt telemetry를 추가 검토한다.
- 오래된 owner 없는 문서의 backfill 계획과 차단 전환 시점을 수립한다.

## 필수 권한 테스트

- 트레이너 A가 B의 member/contract/schedule/training_log를 읽거나 쓰지 못한다.
- 비로그인 서명 사용자는 token 교환 API 외 Firestore/Storage에 접근하지 못한다.
- 사용자가 request의 memberId/contractId/trainingLogId를 바꿔도 서버가 저장된 대상과 비교해 거부한다.
- 완료 contract version update/delete가 거부되고 revoke/supersede event만 허용된다.
- 서명/계약 이미지 URL 또는 경로로 다른 tenant artifact를 읽지 못한다.
- 만료·사용·취소 토큰 제출이 거부되고 정상 토큰 동시 제출 중 하나만 성공한다.
- 트레이너 A가 B의 anatomy parent/child를 list/get/create/update/delete하지 못한다.
- parent/child의 trainerId·memberId 또는 path/field lessonLogId가 다르면 거부한다.
- scheduleDocId 없는 정상 manual/quick/legacy log는 부모 identity가 유효하면 허용하고, 값이 있는 불일치는 거부한다.
- 부모가 없거나 삭제 정책 상태면 orphan anatomy child read/write를 거부한다.
