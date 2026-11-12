# Linked Beginner 회원 작업공간 감사

## 2026-07-16 Anonymous Beginner 확장

- 기존 `managed_members.ts`는 non-anonymous 계정만 허용하고 active/paused 현재 수 10명만 제한했으며, 성별·활동 지역·중복 회원·누적 등급을 검증하지 않았다.
- 신규 경로는 Auth UID를 canonical `trainerId`로 사용하고 이름·성별·정규화 전화번호·활동 지역이 완성된 회원만 transaction에서 저장한다.
- 같은 transaction에서 `trainerId + workspaceType + phoneNormalized`로 중복을 조회한 뒤 회원 문서와 profile의 현재 관리 수·누적 유효 수·등급을 갱신한다. 전화번호 claim 문서는 만들지 않으며 동일 idempotency key 재시도는 새 회원이나 누적 수를 만들지 않는다.
- anonymous Beginner는 10번째까지 허용하고 11번째부터 provider 연결과 내 정보 완료를 요구한다. 연결·프로필 수정도 같은 서버 평가 함수를 사용한다.
- 익명 owner read만 Rules에 추가했으며 client 직접 회원 write는 계속 거부한다. legacy 전체 회원 UI/query는 신규 workspace에 연결하지 않았고 기존 회원을 자동 귀속하지 않는다.
- schedules, training_logs, contracts와 시작 로그인 gate는 변경하지 않았다.

감사일: 2026-07-15

## 결론

기존 회원 UI는 `members` 전체 조회와 직접 Firestore 쓰기에 강하게 결합되어 있어 신규 personal workspace에서 안전하게 재사용할 수 없다. 신규 계정은 별도 `PersonalWorkspaceReadyPage`와 `ManagedMemberWorkspaceGateway`만 사용한다. 이 경로는 `trainerId == Auth UID`와 `workspaceType == personal` 조회만 수행하며 생성·일반 수정·관리 상태 전환은 Cloud Function만 호출한다. legacy 문서를 신규 UID에 귀속하거나 복사하지 않는다.

## 기존 경로 감사

| 경로 | 동작 | ID/owner 현황 | 주요 상태 필드 | 신규 workspace 판정 | 한도/쓰기 위험 |
| --- | --- | --- | --- | --- | --- |
| `client_list_page.dart` `_openCreate`, `_updateMemberStatus`, 전체 snapshot | create 진입, update, query | client가 임의 doc ID 생성, trainerId 없음, 전체 조회 | `memberStatus`, `groupId`, `isDeleted` | legacy 전용 | 직접 update 및 전체 query로 소유권·한도 우회 |
| `client_card_page.dart` `_submitAndStay` 및 다수 보조 저장 | create/update/merge | 전달받은 memberId, trainerId 보장 없음 | 회원카드·회원권·정지·회차 필드 전체 | legacy 전용 | 큰 Map 직접 저장, canonical allowlist로 재사용 불가 |
| `home_page.dart` `_showQuickRegistrationDialog` | 빠른 create | client 임의 ID, trainerId 없음 | `memberStatus=활성`, 이름·전화·예약 | legacy 전용 | Function 없이 관리 회원 증가 |
| `home_page.dart` 회원 추천/검색 | 전체 query/get | owner filter 없음 | `isDeleted`, 전화 fallback | legacy 전용 | 신규 계정에 legacy 노출 가능 |
| `contract_page.dart` `_registerClientCardFromContract` | 계약 후 create/update | 기존 internal member ID, trainerId 보장 없음 | 계약·회차·회원 상태 | legacy 전용 | 계약 transaction 경계와 결합되어 이번 단계 재사용 중단 |
| `membership_contract_page.dart` `_saveDraft`, `_save` | member merge/update | memberId 직접 참조 | 회원권 기간·상태·정지 | legacy 전용 | canonical 상태와 동시 갱신되지 않음 |
| `client_card_page.dart`, `client_list_page.dart` 정지·재개·활성·휴면·만료 | update | owner 검증 없음 | `membership.status`, `membershipStatus`, `memberStatus` | legacy 전용 | 단순 `휴면`만으로 count 판단 불가 |
| `client_list_page.dart` 삭제/복원 계열 | soft delete/update | owner 검증 없음 | `isDeleted`, `deleteStatus`, `deletedAt` | legacy 전용 | 직접 상태 변경으로 count 우회 가능 |
| `binder_card_page.dart` 그룹 이동·전체 snapshot | update/query | owner filter 없음 | `groupId` | legacy 전용 | 신규 personal 조회에 사용 금지 |
| `personal_training_log_page.dart` member merge/update | update | 레슨일지 memberId 직접 참조 | 최근 레슨·회차 등 | legacy 전용 | training_logs 범위와 결합되어 이번 단계 미연결 |
| `stats_page.dart`, 홈 위젯/추천 서비스 | 전체 get/snapshot | owner filter 없음 | 다양한 legacy 필드 | legacy 전용 | 신규 workspace에서 호출 금지 |
| `managed_member_workspace_service.dart` | owner query, Function 호출 | Auth UID 필터, 서버 memberId | canonical 필드 | 신규 전용 | 직접 Firestore write 없음 |

`members` 참조는 홈, 회원관리, 회원카드, 계약서, 레슨일지, 통계, 바인더와 서비스에 광범위하게 존재한다. 기존 화면 전체를 owner mode로 바꾸면 legacy 동작과 계약/레슨일지 범위를 동시에 변경하므로 이번 작업에서는 분리 경로가 최소 안전 변경이다.

## canonical member

경로는 `members/{memberId}`를 유지한다. 신규 문서는 Function이 다음을 고정한다.

- `memberId == document.id`
- `trainerId == request.auth.uid`
- `workspaceType == personal`
- `schemaVersion == 1`
- `managementState`: active / paused / dormant / expired / deleted
- `countsTowardLimit`: active·paused만 true
- `createdAt`, `updatedAt`: 서버 시간

신규 입력 allowlist는 현재 첫 등록 UX에 필요한 `name`, `phone`, `note`뿐이다. identity와 관리 상태는 입력 payload에서 거부한다. 기존 회원카드 전체 payload는 명시적 분리가 어려워 신규 경로에서 사용하지 않았다.

## count source of truth

`trainer_profiles/{uid}.managedMemberCount`가 서버 권위 사용량이며 `managedMemberLimit`은 Beginner에서 10이다. `createManagedMember`와 `transitionManagedMemberState`가 같은 Firestore transaction에서 member와 profile count를 갱신한다. task 11에서 생성된 schemaVersion 1 personal profile에는 canonical member 생성 경로가 없었으므로 두 count 필드가 모두 없는 경우에만 0/10으로 안전 초기화한다. legacy 회원은 집계하지 않는다.

- 포함: active, paused
- 제외: dormant, expired, deleted, Guest 예시, local draft
- false → true 전환은 10명에서 거부
- 같은 idempotency key와 같은 상태 재요청은 count를 다시 바꾸지 않음

기존 회원권 정지/재개는 여러 legacy 필드를 함께 변경하므로 이번 단계에서 canonical Function에 연결하지 않았다. 신규 personal 화면의 `paused` 전환만 canonical source다. legacy 회원권 UI 연결은 별도 transaction 설계가 필요하다.

## Rules와 격리

- canonical read: non-anonymous이고 resource의 trainerId가 UID이며 workspaceType이 personal인 경우만 허용
- list: 위 조건을 증명하는 owner/workspace 필터 필수
- canonical client create/update/delete: 모두 거부
- 기존 role claim 기반 staff의 legacy read/create/update는 보존하되 personal 문서 create/update는 거부
- trainerId 없는 legacy 문서는 신규 Linked Beginner에게 거부

`training_logs`, `schedules`, `contracts`, anatomy 규칙은 변경하지 않았다.

## UX와 미포함 범위

빈 personal workspace는 `0 / 10명`, `첫 회원 등록`, owner-scoped 목록을 표시한다. 실패와 10명 한도 오류는 dialog를 닫거나 입력을 지우지 않는다. dialog 생명주기 동안 같은 idempotency key를 재사용하고 저장 중 중복 탭을 막는다.

Guest draft handoff는 기존 전체 회원카드의 큰 payload와 로그인 전 민감정보 보관 정책을 분리해야 하므로 구현하지 않았다. SharedPreferences 평문 저장도 추가하지 않았다. schedules/training_logs/계약서 연결과 Amateur 이상 정책은 후속 범위다.
