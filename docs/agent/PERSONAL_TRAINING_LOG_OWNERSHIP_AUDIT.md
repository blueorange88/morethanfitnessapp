# Personal 레슨일지 소유권 감사

감사일: 2026-07-16

구현 결과: personal 전용 모델·repository·화면과 `finalizePersonalTrainingLog`, `cancelPersonalTrainingLog` callable을 추가했다. draft create/autosave는 최소 Rules를 사용하고 finalized server field는 Function만 쓴다. personal 회원 목록과 memberId가 연결된 personal 일정은 같은 화면·repository로 진입하며 source만 `formal`/`home_quick_sign`으로 구분한다.

검증 결과: Auth·Firestore·Functions demo Emulator에서 37개 시나리오가 통과했다. 네 확정 상태, 상태별 차감, 중복 확정·취소, 통계·일정 원복, 다른 owner/member/schedule, 미연결 일정, 부분 실패, archive query, legacy 제외, anatomy/contracts/sign_requests 계속 거부를 확인했다. 실제 Firebase 배포와 실제 기기 검증은 수행하지 않았다.

## 결론

현재 루트 `training_logs`는 legacy 전역 구조다. 정식 레슨일지 화면과 빠른서명 화면은 `memberId`만으로 목록을 조회하고, owner/workspace 조건 없이 문서를 직접 생성·merge한다. 홈 확정, 빠른서명, 정식 레슨일지 확정취소에는 member·log·schedule·ledger를 함께 수정하는 서로 다른 transaction 구현이 존재한다. 동일 상태를 여러 진입점이 각자 계산하므로 중복 저장 시 회차 차감은 일부 막아도 `lessonStats.confirmedCount` 같은 통계가 다시 증가할 수 있다.

따라서 legacy 화면과 문서는 유지하고 Anonymous/Linked personal workspace에는 별도의 canonical repository와 서버 transaction을 둔다. 신규 personal 문서는 random ID를 사용하며 Auth UID, personal workspace, 같은 owner의 member와 선택 schedule을 강제한다. 확정·확정취소는 client Rules로 열지 않고 Cloud Function transaction 한 경로로만 처리한다.

## 현재 경로 감사

| 영역 | 현재 동작 | personal 위험 | 결정 |
| --- | --- | --- | --- |
| 정식 목록 | root `training_logs where memberId` | 다른 trainer 문서 혼입 | personal query에 trainerId·workspaceType·memberId 추가 |
| 빠른서명 목록/stream | memberId query 또는 고정 문서 ID 직접 구독 | owner 검증 없음 | personal repository/get으로 분리 |
| 문서 ID | `quick_sign_{scheduleId}` 또는 member/time, 수동 로컬 ID | 다른 tenant 충돌 가능 | personal은 Firestore random ID |
| 초안/자동저장 | 화면이 root 문서를 직접 merge | identity 주입·불변성 부재 | draft allowlist repository + Rules |
| 홈 확정 | `LessonConfirmationService` client transaction | owner 미검증, legacy 필드 fallback | legacy 전용으로 유지 |
| 빠른서명 확정 | 페이지 내부 client transaction | 중복 저장 시 통계 재증가 가능 | personal quick/formal 모두 공통 Function |
| 정식 확정취소 | 페이지 내부 별도 transaction | 홈 취소 서비스와 계산 중복 | personal은 공통 Function cancel |
| 홈 확정취소 | `LessonConfirmCancelService` client transaction | owner 미검증 | legacy 전용으로 유지 |
| 회차 | member root·sessions 여러 필드와 ledger 복제 | drift·부분 정책 차이 | Function transaction에서 함께 갱신 |
| 일정 상태 | schedule 확정 flag와 trainingLogId | 다른 owner 연결 가능 | parent owner/member를 transaction에서 검증 |
| 통계 | member root/sessions/lessonStats | 진입점별 증감 차이 | status별 한 번만 증감·정확히 원복 |
| anatomy | parent log identity를 서비스가 검증 | Rules는 legacy admin만 허용 | personal parent read만 열고 child는 이번 단계에서 계속 차단 |
| 원격서명 | `sign_requests`와 공개 웹 직접 write | 공개 권한 확대 필요 | 이번 단계 제외, Rules 유지 |

## 기존 상태 의미

- `completed`: 회차 차감 대상이며 completed/confirmed 통계를 1회 증가한다.
- `no_show_deducted`: 회차 차감 대상이며 노쇼 차감/confirmed 통계를 1회 증가한다.
- `no_show_not_deducted`: 회차를 차감하지 않고 노쇼 미차감/confirmed 통계를 증가한다.
- `service`: 회차를 차감하지 않고 서비스/confirmed 통계를 증가한다.

확정취소는 원래 status에 해당하는 통계와 confirmed 통계를 1회 감소시키고, 실제 차감이 적용된 경우에만 remaining을 1 증가하고 done을 1 감소시킨다. schedule 확정 cache를 지우고 log는 `confirm_cancelled` 상태로 보존한다.

## Canonical personal 모델

경로는 기존 root collection을 유지하되 신규 문서만 격리한다.

```text
training_logs/{randomLessonLogId}
  lessonLogId == documentId
  trainerId == Firebase Auth UID
  workspaceType == personal
  schemaVersion: 1
  memberId
  scheduleDocId?             // 선택
  lessonDate/startAt/endAt
  lessonType
  status: draft | completed | no_show_deducted |
          no_show_not_deducted | service | confirm_cancelled
  source: formal | home_quick_sign
  memo
  createdAt/updatedAt
```

draft 생성·자동저장은 identity를 바꾸지 않는다. finalized status, deduction, snapshot, 취소 증거는 Function만 기록한다. 같은 `lessonLogId`를 다시 확정하면 기존 결과를 반환하며 통계와 회차를 다시 변경하지 않는다. 취소 후 재취소도 기존 취소 결과만 반환한다.

## 관계 검증

- member는 존재하고 `memberId` 필드가 path ID와 같으며 `trainerId == Auth UID`, `workspaceType == personal`이어야 한다.
- scheduleDocId가 있으면 schedule도 존재하고 같은 owner/personal이어야 하며 schedule memberId와 log memberId가 같아야 한다. 이름만 있는 미연결 일정은 레슨일지 관계의 부모로 사용하지 않는다.
- log의 scheduleDocId가 있으면 확정 요청에서 다른 schedule로 바꿀 수 없다.
- schedule 없이 직접 작성할 수 있지만 member owner는 항상 필수다.
- legacy owner 없는 문서는 personal query와 Function 대상에서 제외하며 backfill하지 않는다.

## UI와 범위 경계

personal 회원 목록에서 회원별 레슨일지 화면을 열고, personal 일정의 연결 회원이 있을 때 같은 화면을 열 수 있게 한다. 새 기록과 자동저장, 네 상태 확정, 확정취소는 personal service를 사용한다. 이름만 있는 일정은 canonical member가 없으므로 레슨일지를 자동 생성하지 않는다.

기존 `HomePage`, 기존 정식 레슨일지, 기존 빠른서명, 공개 원격서명은 legacy 관리자/Debug 경로로 유지한다. contracts·sign_requests Rules, 시작 로그인 gate, legacy 문서와 trainerId는 변경하지 않는다.

## Anatomy 판단

기존 `AnatomyLogService`는 parent/member/schedule identity를 transaction에서 검사한다. 그러나 personal anatomy child Rules까지 열려면 child allowlist, parent metadata update, 고아 parent 정책을 함께 검증해야 한다. 이번 단계에서는 personal parent training log read만 허용하고 `anatomyRecords`는 legacy 관리자 전용으로 유지한다. 따라서 personal 레슨일지에서 anatomy 진입은 후속 Rules 단계 전까지 노출하지 않는다.
