# Personal 일정 소유권 감사

감사일: 2026-07-16

구현 결과: personal 전용 모델·repository·화면을 추가하고 기존 legacy `HomePage`는 변경하지 않았다. 생성·멀티 등록·복사는 공통 canonical builder로 owner를 주입하며, 수정·이동·삭제는 문서를 transaction에서 다시 읽고 owner와 확정 상태를 검증한다. 이동은 같은 random 문서 ID의 시간을 갱신하므로 write 실패가 source 삭제로 이어지지 않는다.

Rules/Emulator 결과: personal owner CRUD, owner query, 다른 UID 차단, legacy 제외, 같은 시간 두 trainer 분리, immutable identity, 확정 잠금, 회원 owner 검증, training_logs·contracts 계속 거부를 포함한 20개 시나리오가 통과했다. legacy 관리자 28개 시나리오도 통과했다. 실제 Firebase Rules·복합 index 배포와 실제 기기 검증은 수행하지 않았다.

## 결론

기존 `HomePage` 일정 흐름은 legacy 개발 데이터용 전역 `schedules` 구조다. 주간 stream은 `startAt` 범위만 사용하고 owner 조건이 없으며, 문서 ID는 `yyyyMMdd-HHmm-요일`이다. 서로 다른 트레이너가 같은 시각에 저장하면 같은 전역 문서를 대상으로 하므로 충돌한다. 이 경로에 Auth UID 필드를 부분적으로 끼워 넣으면 회원 조회, 레슨확정, 레슨일지, 통계, 삭제 tombstone, 위젯의 owner 없는 보조 경로가 섞인다.

따라서 legacy `HomePage`와 기존 문서는 그대로 유지하고, Anonymous/Linked personal workspace에는 random 문서 ID와 Auth UID owner를 사용하는 전용 repository를 둔다. legacy 일정은 읽거나 backfill하거나 migration하지 않는다.

## 현재 경로 감사

| 영역 | 현재 동작 | personal 위험 | 결정 |
| --- | --- | --- | --- |
| 주간 stream | `schedules where startAt range` | owner 없는 전체 query | personal 전용 query에 `trainerId`, `workspaceType`, range 강제 |
| 문서 ID | `yyyyMMdd-HHmm-요일` | 같은 시간의 다른 UID 충돌 | personal은 Firestore random ID, `slotKey`는 필드로 저장 |
| 단일·멀티 저장 | 시간 ID에 set/merge | 다른 owner 덮어쓰기, identity 혼합 | personal repository의 canonical create/batch 사용 |
| 이동 | source delete + 시간 target create | 부분 실패 시 원본 유실 가능 | personal random ID는 동일 문서 transaction update |
| 삭제 | actual snapshot ID batch delete | owner 확인은 Rules에 의존 | personal transaction과 Rules에서 owner·확정 잠금 검증 |
| 복사·붙여넣기 | local payload를 시간 target ID로 batch set | owner/member 재검증 없음 | 새 random ID를 발급하고 owner/member를 재검증 |
| 회원 연결 | legacy 전체 회원 lookup 및 상태 fallback | 다른 trainer 회원 연결 가능 | personal member의 `trainerId == uid`, `workspaceType == personal` 확인 |
| 임시 이름 일정 | 이름만으로 저장 가능 | canonical 회원 자동 생성 위험 | memberId 없는 personal 일정으로만 저장, member Function 미호출 |
| 회원 다음 예약 | memberId 단독 schedule query | 다른 owner 일정 혼입 | 이번 personal repository에서는 사용하지 않음 |
| 운영통계·마이페이지 | root schedule owner 없는 query | personal 집계에 legacy 혼입 | 이번 단계에서 기존 화면 미연결, 후속 owner-aware 집계 필요 |
| Android widget | HomePage 메모리 전체를 cache | UID 변경 후 잔상 가능 | personal sync 전에 owner UID 비교, 변경·로그아웃 시 일정 cache 제거 |
| Rules | schedules는 legacy admin만 허용 | Anonymous/Linked personal 사용 불가 | personal owner 최소 CRUD만 추가, legacy admin 경로 유지 |

## Canonical personal schedule

경로는 기존과 동일한 `schedules/{randomDocumentId}`를 사용하되 신규 personal 문서만 다음 identity를 갖는다.

- `scheduleId == documentId`
- `trainerId == Firebase Auth UID`
- `workspaceType == personal`
- `schemaVersion == 1`
- `startAt`, `endAt`, `dateKey`, `slotKey`
- `name`, `type`, 선택 `memberId`, `phone`, 회차 snapshot, `memo`
- `status`, 서버 `createdAt`, 서버 `updatedAt`

`dateKey`와 `slotKey`는 조회·표시용이며 identity가 아니다. 동일 trainer도 같은 시각의 겹치는 일정을 별도 random ID로 저장할 수 있다. 이동은 문서 ID를 바꾸지 않는다.

## 소유권 경계

- 모든 repository 작업은 현재 Auth UID와 생성 당시 repository owner UID가 같아야 한다.
- 목록 query는 `trainerId == uid`, `workspaceType == personal`, `startAt` 범위를 모두 포함한다.
- memberId가 있으면 같은 UID의 canonical personal member인지 먼저 확인한다.
- memberId가 없으면 이름 일정으로 저장할 뿐 회원 생성 callable을 호출하지 않는다.
- create/update/move/delete/copy/multi의 identity 주입은 공통 canonical builder를 사용한다.
- confirmed evidence가 있는 일정은 일반 update/delete를 거부한다.

## legacy와 범위 밖 경로

- Debug/관리자 legacy `HomePage` query와 시간 ID는 이번 단계에서 변경하지 않는다.
- `my_page.dart`, `stats_page.dart`, 레슨확정 service의 owner 없는 legacy query/write는 personal 화면에서 호출하지 않는다.
- training_logs, contracts, anatomy Rules와 데이터 모델은 변경하지 않는다.
- 시작 로그인 gate를 제거하지 않는다. Anonymous personal 흐름은 repository와 Emulator harness로 검증한다.
- 실제 Firebase 배포와 운영 데이터 migration/backfill은 수행하지 않는다.
