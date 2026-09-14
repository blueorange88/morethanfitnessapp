# Training Logs + Anatomy Rules 사전 감사

감사일: 2026-07-15  
대상: `training_logs/{lessonLogId}`와 `training_logs/{lessonLogId}/anatomyRecords/{anatomyLogId}`  
결론: **Rules 구현·Emulator 완료 판정 중단**

## 09 tenant identity 감사 추가 결론

후속 09 작업에서 Auth 흐름을 확인했으나 `FirebaseAuth.currentUser.uid`를 canonical trainerId로 보장할 수 없었다.

- 앱 시작에 Auth gate가 없고 SplashRouter는 `trainer_profile/me`만 확인한다.
- onboarding도 인증 확인 없이 고정 `me` profile을 저장한다.
- 앱 코드에 sign-in, anonymous sign-in, sign-out, account switch 흐름이 없다.
- More Care는 profile identity가 없으면 문자열 `me`를 trainerId로 사용한다.
- organizationId/branchId와 Auth UID membership 관계가 정의되지 않았다.

따라서 신규 training log/member에 current UID를 주입하는 repository 구현도 중단했다. Auth와 tenant membership을 먼저 확정하지 않고 기존 parent에 trainerId를 추가하거나 legacy owner를 추정하지 않는다. 상세 모델과 전환 절차는 `TENANT_IDENTITY_MODEL.md`, `TENANT_IDENTITY_MIGRATION_PLAN.md`, `REMOTE_SIGNATURE_MIGRATION_PLAN.md`에 기록했다.

## 결론

현재 루트 `training_logs`의 정상 생성·수정 계약은 owner 기반 Rules를 안전하게 만들 수 있는 상태가 아니다.

- 빠른서명, 홈 레슨확정, 공개 원격서명이 서로 다른 payload를 `set(merge: true)`로 생성한다.
- 확인한 루트 부모 생성 payload에는 공통 `trainerId`와 필드 `lessonLogId`가 없다. 대부분 `id`만 기록한다.
- 일부 확정·취소·회차 차감 경로는 부모가 없을 때 `createdAt`도 없는 부분 문서를 만들 수 있다.
- 공개 원격서명 페이지는 비로그인 사용자가 토큰 문서를 읽고 루트 training log를 직접 create/update한다. 안전한 owner Rules와 양립하지 않는다.
- 앱의 빠른서명/anatomy 부모 목록 쿼리와 공개 서명 이력 쿼리는 `trainerId` 조건이 없다.
- `members` 문서는 트레이너 표시 문자열 `trainer`를 쓰지만 Auth UID 기반 `trainerId/ownerId`가 일관되게 존재하지 않아 parent create에서 회원 소유권을 `get()`으로 검증할 근거가 없다.
- anatomy service 자체는 부모 존재와 identity를 검사하지만, 부모를 만드는 앞선 경로가 그 identity를 제공하지 않는다.

따라서 `allow read, write: if request.auth != null`, role만 확인하는 broad rule, trainerId 없는 legacy fallback, token 문자열 기반 직접 쓰기를 추가하지 않았다. `firestore.rules`는 수정하지 않았고 Rules Emulator 테스트도 작성·실행하지 않았다.

## 실제 루트 training_logs 경로 감사

`members/{memberId}/training_logs/*`는 별도 하위 컬렉션이며 아래 루트 컬렉션 감사와 구분한다.

| 파일/메서드 | 작업 | 경로 | 필수/저장 identity | trainerId/owner 출처 | memberId 출처 | scheduleDocId | Auth UID 사용 | 원자성 | 안전한 Rules에 필요한 권한/판정 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `personal_training_log_quick_sign_page.dart::_loadExistingQuickLog` | get | `training_logs/{computedQuickId}` | ID로만 조회 | 없음 | ID 계산에 member 사용 가능 | ID 계산에 선택 사용 | 없음 | 단일 get | owner get 필요하지만 문서 trainerId가 없음 |
| 같은 파일 `_bindQuickLogStream` | get/listen | 같은 문서 | ID로만 listen | 없음 | widget | 선택 | 없음 | snapshot stream | owner get 필요, identity 부재로 안전하게 허용 불가 |
| 같은 파일 `_saveQuickSignedLog` | get + create/update | 같은 문서 | `id`, `memberId`, createdAt(신규), updatedAt. `trainerId/lessonLogId` 없음 | 저장하지 않음 | widget member | 선택 | 저장 로직에서 UID 확인 없음 | member/log/schedule transaction | owner create/update 불가. payload 계약 선행 수정 필요 |
| `personal_training_log_page.dart::_loadQuickSignedLogsFromFirestore` | list | `training_logs where memberId, quickSignedOnly` | member/quick 조건 | 필터 없음 | widget member | 결과에서 읽음 | 없음 | query | `trainerId == uid` 필터 추가 전 owner list Rule과 호환 불가 |
| 같은 파일 `_loadAnatomyLogsFromFirestore` | list | `training_logs where memberId` | member 조건 | 필터 없음 | widget member | 결과에서 읽음 | 없음 | query | owner 필터 없는 부모 collection query이므로 거부해야 함 |
| 같은 파일 `_confirmCancelLogWithPin` | get + update, 문서 부재 시 create 가능 | `training_logs/{resolvedId}` | 취소 상태와 member 요약. `trainerId/lessonLogId/createdAt` 보장 없음 | 없음 | widget/member/schedule fallback | 선택 | PIN만 검사, UID를 payload와 결속하지 않음 | log/member/schedule transaction | identity 없는 부분 부모 생성 가능. 안전한 update allowlist 확정 불가 |
| 같은 파일 `_applyRemainingSessionDeductionIfNeeded` | update, 문서 부재 시 create 가능 | `training_logs/{logId}` | 확정·차감 필드만 merge | 없음 | member 문서는 읽지만 log에 memberId를 항상 쓰지 않음 | 없음 | 없음 | member/log transaction | 최소 identity 없는 부모 생성 가능. create와 update 구분 필요 |
| `lesson_confirmation_service.dart::confirmFromHome` | get + create/update | `training_logs/{trainingLogId}` | `id`, `memberId`, scheduleDocId, createdAt(신규), updatedAt. `trainerId/lessonLogId` 없음 | request에도 없음 | request | 필수 | service 내부 UID 확인 없음 | member/log/schedule/ledger transaction | 홈 정상 생성 경로도 owner identity가 없어 create Rule 불가 |
| `lesson_confirm_cancel_service.dart::cancelByScheduleDocId` | get + update, 문서 부재 시 create 가능 | schedule이 가리키는 log | void 상태만 merge 가능 | 없음 | schedule | schedule에서 역참조 | service 내부 UID 확인 없음 | schedule/log/member/ledger transaction | identity 없는 void 부모 생성 가능. owner 검증 근거 없음 |
| `member_signature_web_page.dart::_loadSignatureHistory` | list | `training_logs where memberId, memberSigned` | member/sign 조건 | 필터 없음 | 공개 request의 member | 없음 | 공개 페이지, 인증 보장 없음 | query | 비로그인 broad list는 허용 불가. 서버 API 필요 |
| 같은 파일 `_submitSignature` | get + create/update | `training_logs/{request.trainingLogId}` | `id`, `memberId`, createdAt(신규), updatedAt. `trainerId/lessonLogId` 없음 | 없음 | token request | 선택 | 비로그인 직접 Firestore | sign request/log transaction | token만으로 직접 쓰는 Rule 금지. 검증 Function 필요 |
| `home_page.dart` 원격서명 요청 생성 경로 | get | 계산된 `training_logs/{id}` | 상태 중복 확인 | 부모 owner 검사 없음 | 현재 일정/회원 | 선택 | 앱 로그인 상태에 의존하나 get과 payload 결속 없음 | 단일 get | owner get 전환 전 parent trainerId 필요 |
| `anatomy_log_service.dart::load` | parent get + child list | parent 및 `anatomyRecords` | parent trainer/member 필수, child path identity 검사 | Firebase Auth UID | anatomy context | 선택 | UID와 trainerId 검사 | 개별 reads | 부모 owner get과 child list 필요. 현재 child query에 identity where 조건이 없어 Rules query 호환성 Emulator 확인 필요 |
| 같은 파일 `save` | parent get/update + child create/update/delete | 같은 경로 | parent identity 검증, child identity 불변 | Firebase Auth UID | 검증된 parent/context | 선택 | UID와 trainerId 검사 | Firestore transaction | parent metadata 제한 update와 child CRUD는 설계 가능하지만 안전한 parent 생성·조회 계약이 선행돼야 함 |
| `client_card_page.dart::_bootstrapMemberArtifacts` | create/update | `members/{memberId}/training_logs/{_index|date}` | nested template fields | 없음 | parent path | 없음 | 별도 UID 결속 없음 | batch | 루트 `training_logs`가 아니며 이번 Rules 범위 밖. 현재 members match도 하위 컬렉션에 상속되지 않음 |

## 필드 계약 불일치

### 공통으로 보장되지 않는 필드

- `trainerId`: 루트 parent 생성/수정 payload에서 확인되지 않음.
- `lessonLogId`: path 문서 ID를 복제하지 않고 과거 코드가 `id`를 사용.
- `createdAt`: 빠른서명·홈확정·웹서명 정상 신규에는 서버 시간이 있으나, merge 기반 차감/취소가 없는 문서를 만들면 누락 가능.
- `memberId`: 정상 빠른서명·확정에는 있으나 부분 차감/취소 생성에서는 항상 보장되지 않음.
- `scheduleDocId`: 정상적으로 선택값이며 빠른서명·원격서명·과거 기록에서 없을 수 있음.

### update allowlist를 확정할 수 없는 이유

레슨확정, 노쇼/서비스, 서명, 확정취소, 회차 차감이 모두 같은 부모 문서에 서로 다른 상태·서명·스냅샷 필드를 merge한다. 현재는 parent schema/version과 상태 전이 계약이 없어 “허용된 내용 필드” 목록을 좁히면 정상 흐름을 깨뜨리고, 넓히면 서명·차감·잠금 상태를 클라이언트가 임의 변경할 수 있다.

## 목록 쿼리와 소유권

안전한 parent read/list Rule은 `resource.data.trainerId == request.auth.uid`를 요구해야 한다. 그러나 다음 쿼리는 trainer 조건이 없다.

- 빠른서명 목록: memberId + quickSignedOnly
- anatomy 부모 목록: memberId
- 공개 회원 서명 이력: memberId + memberSigned

Rules는 결과를 필터링하지 않으므로 이 쿼리들을 인증 사용자 전체에 열 수 없다. 앞의 두 앱 쿼리는 parent identity migration 후 `trainerId == currentUid` 조건을 추가할 수 있다. 공개 서명 이력은 비로그인 직접 query를 제거하고 최소 결과만 반환하는 검증된 서버 경로로 이전해야 한다.

## Legacy와 orphan 정책

- `trainerId`, `memberId`, `lessonLogId`, `createdAt` 중 필수 identity가 없는 parent는 read/create/update/delete를 자동 허용하지 않는다.
- 현재 로그인 사용자가 처음 접근했다는 이유로 trainerId를 backfill하지 않는다.
- 신뢰 가능한 schedule owner 또는 서버 감사 자료를 기준으로 승인된 migration이 필요하다.
- parent hard delete 뒤 child는 물리적으로 남는다. 후속 Rules는 `exists(parent)`와 parent owner를 확인해 orphan child 접근을 모두 거부해야 한다.
- cascade delete는 이번 작업에 추가하지 않는다. 보존정책이 확정된 서버 관리 cleanup으로 분리한다.

## scheduleDocId 정책

- parent와 child에서 모두 선택값이다.
- 양쪽 모두 값이 있으면 같아야 한다.
- parent에 값이 없고 child에만 값이 있는 현재 service 정책은 허용 가능하지만, parent identity 계약 확정 후 Emulator에서 명시적으로 검증해야 한다.
- 기존 child scheduleDocId는 일반 update로 변경하지 않는다.

## Rules/Emulator 환경 감사

- 현재 `firestore.rules`에는 `training_logs` match가 없으며 이번 감사에서 수정하지 않았다.
- `firebase.json`에는 Firestore rules/emulator 설정이 없다.
- 현재 실행 환경 PATH에서 Firebase CLI를 찾지 못했다.
- 루트와 `functions`의 기존 `node_modules`에 `@firebase/rules-unit-testing`이 없다.
- 안전한 Rules 자체를 확정할 수 없는 중단 조건이 먼저 충족됐으므로 새 dev dependency나 테스트 환경을 추가하지 않았다.
- Emulator 테스트 결과가 없으므로 Rules를 완료 또는 통과로 판단하지 않는다.

## 필요한 선행 작업

1. 루트 training log schema/version과 공통 repository를 정의한다.
2. 인증된 trainer 생성 경로가 `trainerId`, `memberId`, `lessonLogId`, 서버 `createdAt/updatedAt`을 원자적으로 기록하게 한다.
3. merge update가 없는 parent를 만들지 못하도록 create/update를 분리한다.
4. 기존 parent의 owner/member/path identity를 신뢰 가능한 근거로 migration하고 누락 문서는 계속 deny한다.
5. members에 Auth UID 기반 owner를 확정하거나, parent create의 member 결속을 검증하는 서버 경로를 만든다.
6. 공개 원격서명 direct Firestore 접근을 검증 Function/API로 이전한다.
7. 인증 앱의 모든 parent query에 trainerId 필터를 추가한다.
8. 그 후 최소 parent/child Rules와 40개 Emulator 행렬을 구현하고 전부 통과한 경우에만 Rules 완료를 판단한다.

실제 Firebase 프로젝트 배포와 운영 데이터 변경은 수행하지 않았다.
