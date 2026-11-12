# 해부학 레슨일지 데이터 모델

## 2026-07-16 personal parent 권한 상태

신규 canonical personal `training_logs/{lessonLogId}` parent는 본인 read와 안전한 draft create/update가 열렸다. 그러나 `anatomyRecords` child는 parent metadata update·child allowlist·고아 정책을 함께 검증하는 후속 단계 전까지 legacy 관리자 전용으로 유지한다. 따라서 personal parent가 생겼다는 사실만으로 anatomy 저장이 허용된 것은 아니다.

## 관계와 저장 위치

해부학 기록은 기존 일반 레슨일지의 하위 컬렉션에 기록별 문서로 저장한다.

```text
training_logs/{lessonLogId}
  trainerId
  memberId
  scheduleDocId?             // 선택 참조
  anatomySchemaVersion: 1
  hasAnatomyRecords: true/false
  anatomyRecordCount: number
  anatomyRecords/{anatomyLogId}
    ...AnatomyLogRecord
```

- 관계의 원본은 존재하는 `training_logs/{lessonLogId}` 경로다.
- 한 레슨에 여러 `anatomyRecords` 문서를 둘 수 있다.
- 하위 문서 ID와 필드 `anatomyLogId`는 항상 같고, 수정 시 유지한다.
- 한 기록 삭제는 해당 하위 문서만 대상으로 하며 부모나 다른 기록을 삭제하지 않는다.
- 정렬은 `recordedAt` 내림차순 → `createdAt` 내림차순 → `anatomyLogId` 오름차순이다.
- 회원 또는 상위 레슨일지 삭제 시 클라이언트 cascade delete를 실행하지 않는다. Firestore는 부모 삭제 시 하위 컬렉션을 자동 삭제하지 않으므로, 고아 기록은 후속 Rules에서 부모 존재를 확인해 접근을 차단하고 별도의 승인된 보존·정리 정책으로 처리한다.

## 부모 생성 원칙과 현재 진입 경로

`AnatomyLogService`는 상위 `training_logs` 문서를 만들거나 식별자를 backfill하지 않는다. 생성·수정·삭제 트랜잭션에서 부모를 먼저 읽고, 부모가 없으면 `parent_not_found`로 중단한다.

현재 저장소에는 수동 레슨일지 초안을 정식 `training_logs` 부모로 만드는 공통 service/repository가 명확히 존재하지 않는다. 새 수동 레슨일지는 로컬 ID만 먼저 만들며, 홈에서 레슨일지 페이지로 이동할 때도 schedule ID를 전달하지 않는다. 따라서 새 구조를 추측해 추가하지 않았고 다음처럼 처리한다.

- 기존 부모가 있고 필수 identity가 유효한 기록: anatomy CRUD 가능.
- `scheduleDocId`가 없는 수동·빠른서명·원격서명·과거 기록: schedule 부재만으로 차단하지 않음.
- 부모가 없는 수동 초안: 일반 레슨일지를 먼저 저장하라는 안내와 함께 anatomy 저장 차단.
- 부모는 있지만 `trainerId` 또는 `memberId`가 없는 과거 문서: `legacy_parent_missing_identity`로 차단하며 클라이언트가 값을 채우지 않음.

공통 training log 생성 경로를 후속 작업에서 먼저 정의하고 모든 신규·수동 진입점이 그 경로로 부모의 안정 ID, trainer, member를 확정한 뒤 anatomy 화면을 열어야 한다.

## AnatomyLogRecord

| 필드 | 형식 | 규칙 |
| --- | --- | --- |
| `anatomyLogId` | string | 필수. 하위 문서 ID와 동일, 수정 불가 |
| `trainerId` | string | 필수. Firebase Auth UID 및 부모 trainerId와 동일, 수정 불가 |
| `memberId` | string | 필수. 부모 memberId와 동일, 수정 불가 |
| `lessonLogId` | string | 필수. path의 lessonLogId와 동일, 수정 불가 |
| `scheduleDocId` | string | 선택. 부모와 자식 모두 값이 있으면 동일해야 함. 기존 값이 있으면 수정 불가 |
| `recordedAt` | timestamp | 해당 레슨 일시, 기록 내용 수정 시 변경 가능 |
| `bodyGender` | string | `male`, `female`, `unspecified` |
| `bodyView` | string | `front`, `back` |
| `bodySide` | string | `left`, `right`, `center`, `both` |
| `bodyPartId` | string | 안정적인 신체 부위 ID |
| `bodyPartLabel` | string | 저장 당시 표시명 |
| `recordType` | string | `exercise`, `pain`, `caution`, `mobility` |
| `exerciseName` | string | 운동명이 없으면 빈 문자열 |
| `painLevel` | int | 0~10 |
| `memo` | string | 트레이너 기록 메모 |
| `createdAt` | timestamp | 생성 시 서버 시간, 수정 불가 |
| `updatedAt` | timestamp | 저장할 때마다 서버 시간 |

수정 payload는 `recordedAt`, body 관련 필드, 부위 ID/표시명, 기록 유형, 운동명, 통증 단계, 메모와 `updatedAt`만 포함한다. `anatomyLogId`, `lessonLogId`, `trainerId`, `memberId`, `createdAt`은 재기록하지 않는다. 기존 `scheduleDocId`도 수정 payload에 포함하지 않는다.

## 서비스 무결성 규칙

모든 작업은 현재 Firebase Auth UID를 확인하며 UID와 요청 trainerId가 다르면 `trainer_mismatch`다.

### 생성·수정

1. 트랜잭션에서 부모를 읽고 존재를 확인한다.
2. 부모 trainerId/memberId가 비면 legacy 오류로 차단한다.
3. 부모와 context의 trainerId/memberId, 양쪽에 존재하는 scheduleDocId를 비교한다.
4. path lessonLogId와 자식 필드 lessonLogId, 문서 ID와 anatomyLogId를 비교한다.
5. 새 ID가 필요한 경우 한 번 생성한 ID를 문서 경로와 필드에 함께 사용한다.
6. 기존 문서는 같은 트랜잭션에서 읽고 불변 identity와 createdAt을 비교한다.
7. 새 문서는 서버 createdAt/updatedAt으로 생성하고 기존 문서는 허용된 내용과 서버 updatedAt만 갱신한다.
8. 부모에는 anatomy 요약 메타데이터만 `update`한다. 부모 `set` 또는 identity backfill은 하지 않는다.

초기 구현의 부모 `anatomyRecords` 배열은 읽기 fallback으로 유지한다. 검증된 부모 아래의 legacy 항목에서 child identity가 비어 있으면 메모리에서 검증된 parent/path identity를 사용해 읽되 부모에는 backfill하지 않는다. 정상 저장 시 하위 문서로 옮기고 부모 배열을 제거해 삭제된 항목이 fallback으로 재등장하지 않게 한다.

### 삭제

- 트랜잭션에서 부모와 삭제할 자식이 모두 존재하는지 확인한다.
- 부모와 자식의 trainerId/memberId/path identity를 검증한 뒤 선택 문서만 삭제한다.
- 존재하지 않는 자식은 `record_not_found`이며 성공으로 처리하지 않는다.
- 부모 문서는 삭제하지 않는다.

### 조회

- 인증 UID와 요청 trainerId가 일치하고 부모 identity가 검증된 경우에만 결과를 사용한다.
- 하위 컬렉션 전체를 읽어 path ID, trainerId, memberId, schedule 관계를 검사한다.
- 무결성이 어긋난 자식은 결과에서 제외하고 `[MTF_ANATOMY_INTEGRITY]` 로그에 개인정보나 내부 ID 없이 오류 코드와 단계만 남긴다.
- 과거 필드가 없는 내용 값은 성별 `unspecified`, 화면 `front`, 방향 `both`, 유형 `exercise`, 통증 `0`, 문자열 빈 값으로 안전하게 읽는다.

## 오류 코드와 화면 처리

서비스 오류는 다음을 구분한다.

- `unauthenticated`
- `trainer_mismatch`
- `parent_not_found`
- `legacy_parent_missing_identity`
- `member_mismatch`
- `schedule_mismatch`
- `path_lesson_log_mismatch`
- `immutable_identity_change`
- `record_not_found`
- `permission_denied`
- `unknown`

저장 실패 시 anatomy 화면은 닫히지 않고 성공 토스트도 표시하지 않는다. 사용자 안내에는 내부 문서 ID나 회원 정보가 포함되지 않는다. 부모 부재는 먼저 일반 레슨일지를 저장하라고 안내하고, legacy identity 부재는 데이터 보강이 필요하다고 안내한다.

## 현재 Firestore Rules와 후속 최소 조건

현재 `firestore.rules`는 canonical personal `/training_logs/{lessonLogId}` parent의 본인 read와 draft create/update/delete만 최소 허용한다. `/anatomyRecords`는 계속 legacy 관리자 전용이므로 Anonymous/Linked personal anatomy 읽기·쓰기는 거부된다. Functions·Rules를 실제 Firebase 프로젝트에 배포하지 않았으므로 Emulator 통과는 실제 프로젝트 저장 활성화를 의미하지 않는다.

### 2026-07-15 Rules 사전 감사 중단 결과

`TRAINING_LOG_RULES_AUDIT.md`에서 루트 parent를 만드는 빠른서명·홈확정·공개 원격서명 경로를 전수 확인했다. 이 경로들은 공통 `trainerId`와 필드 `lessonLogId`를 저장하지 않고, 일부 merge update는 없는 parent를 identity 없이 만들 수 있다. parent 목록 query도 trainerId 필터가 없고 공개 웹서명은 비로그인 direct write다.

따라서 child Rules만 먼저 열거나 인증 사용자 전체/role 전체 fallback을 만들지 않았다. parent schema·owner migration·공통 생성 경로·공개서명 서버 경계가 먼저 확정되어야 하며, 그 전까지 현재 deny 상태를 유지한다. Firestore Emulator 테스트도 안전한 Rules가 없는 상태에서는 작성·통과 처리하지 않았다.

후속 Rules 작업은 최소한 다음 조건을 동시에 강제해야 한다.

- 인증 및 승인된 staff role.
- 부모 `training_logs/{lessonLogId}`가 존재하고 `trainerId == request.auth.uid`.
- 부모 `trainerId/memberId`가 비어 있지 않음.
- create의 path lessonLogId/anatomyLogId가 request 필드와 동일.
- child trainerId/memberId가 부모와 동일.
- scheduleDocId는 선택이며 부모와 child 모두 값이 있을 때만 동일성 강제.
- update는 `anatomyLogId`, `lessonLogId`, `trainerId`, `memberId`, `createdAt` 불변. 기존 scheduleDocId도 변경 금지.
- delete/read도 기존 child identity와 부모 identity를 함께 검증.
- 부모 metadata update는 `anatomySchemaVersion`, `hasAnatomyRecords`, `anatomyRecordCount`, `updatedAt` 및 승인된 legacy 배열 제거만 허용하며 owner/member/schedule 변경 금지.
- 부모가 삭제된 고아 하위 문서는 read/write/delete를 거부.

Rules 구현 전에는 실제 배포 Rules와 역할 claim을 확인하고 emulator에서 본인/다른 트레이너/legacy/고아 문서 행렬을 검증해야 한다. 클라이언트 검증은 보안 경계가 아니므로 Rules 적용 전 실제 기기 저장은 완료로 간주하지 않는다.

## 이번 단계 제외

- Firestore/Storage Rules 수정 및 Firebase 배포
- 데이터 migration 또는 legacy identity backfill
- 공통 training log 생성 구조 신설
- 영상 업로드·썸네일·음성 추출·Storage 연동
- 회원 앱 공개, 실제 남성·여성 신체 이미지, anatomy 화면 대규모 개편
- 회원 또는 레슨일지 삭제 cascade
