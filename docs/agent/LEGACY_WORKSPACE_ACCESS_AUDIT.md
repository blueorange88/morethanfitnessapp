# Legacy Workspace 접근 감사

기준일: 2026-07-15

## 결론

Legacy workspace는 이메일, 표시 이름, profile role로 판정하지 않는다. 비익명 Firebase 사용자이면서 ID token의 `platformAdmin == true`, `legacyDataAccessApproved == true`가 모두 참이고, `trainer_profiles/{uid}.mustChangePassword != true`인 경우에만 진입·Firestore 접근이 가능하다. 기존 문서에는 `trainerId`, `ownerId`, 신규 UID를 추가하지 않았고 복사·이관도 하지 않았다.

## Firestore 경로

| 경로 | 주요 caller와 query/write | 삭제 방식 | Legacy 권한 |
|---|---|---|---|
| `trainer_profile/me` | 홈, 회원관리, 회원카드, 마이페이지, 설정, 알림, 계약서에서 단건 read/set/update | 확인된 hard delete 없음 | read/create/update |
| `members/{memberId}` | 홈 추천·검색, 회원관리/카드, 레슨일지, 계약서, 운영통계의 전체 snapshot·단건 get·set/update | `isDeleted`, `deleteStatus` soft delete | legacy 문서 read/create/update, root delete 거부 |
| `member_groups/{id}` | 회원관리/회원카드 그룹 조회·batch 정리 | 실제 delete 사용 | CRUD |
| `schedules/{id}` | 홈 스케줄 snapshot, 생성·수정·이동·삭제, 회원카드/레슨일지/운영통계 조회 | 실제 hard delete 사용 | CRUD |
| `training_logs/{lessonLogId}` | 일반/빠른서명 레슨일지, 홈, 레슨확정, anatomy 조회·저장 | 실제 delete 경로 존재 | CRUD |
| `training_logs/{lessonLogId}/anatomyRecords/{id}` | anatomy service의 정렬 조회·transaction create/update/delete | 선택 문서 hard delete | CRUD |
| `contracts/{id}` | 계약 목록·작성·상태 갱신 | `isDeleted` soft delete | read/create/update |
| `contractCounters/{id}` | 계약 번호 증가 transaction | 확인된 hard delete 없음 | read/create/update |
| `sign_requests/{id}` | 트레이너 홈·빠른서명·레슨일지의 생성/상태 조회·갱신 | 확인된 hard delete 없음 | 인증된 legacy admin read/create/update만 허용 |
| `lesson_products/{id}` | 홈·마이페이지 상품 조회·저장 | `isDeleted` soft delete | read/create/update |
| `talk_notification_queue/{id}` | 레슨 확정·취소 알림 enqueue | app은 create 중심 | read/create |
| `more_care_slot_requests/{id}` | More Care 신청 조회·상태 변경 | 확인된 hard delete 없음 | read/create/update |
| `organizations/{orgId}/more_care_slot_requests/{id}` | 조직 단위 More Care 신청 조회·상태 변경 | 확인된 hard delete 없음 | read/create/update |

## 회원 하위 컬렉션

- `events`: read/create만 사용 범위로 허용한다.
- `membership_contracts`, `lesson_ledger`, `client_card`, `training_logs`: 부모 회원이 legacy 문서일 때 read/create/update를 허용한다.
- `inbody_records`, `goal_ddays`, `care_milestones`, `achievement_badges`: 현재 UI에서 개별 삭제가 확인되어 부모 회원이 legacy 문서일 때 CRUD를 허용한다.
- 부모 회원이 `workspaceType == personal`이면 legacy admin도 접근할 수 없다. 과거 legacy 문서처럼 `workspaceType`이 없는 문서만 legacy로 취급한다.

## 명시적으로 열지 않은 경로

- `re_registration_requests`: 원격서명 공개 화면에서 비로그인 create를 시도하지만 현재 보안 감사에서 안전한 공개 식별·검증 구조가 확정되지 않았다. 이번 Rules에는 match를 추가하지 않았다.
- 그 밖의 미감사 collection과 모든 광역 wildcard: 기본 거부한다.
- `trainer_profiles/{uid}`: 기존 본인 전용 read와 제한 필드 update 정책을 유지하며 legacy admin 예외를 추가하지 않았다.

따라서 현재 원격서명 공개 쓰기는 계속 거부될 수 있다. 이는 이번 작업에서 새 공개 권한을 만들지 않는다는 요구에 따른 의도적인 미해결 항목이다.

## Storage 경로

코드에서 실제 업로드 경로와 MIME이 확인된 네 경로만 허용했다.

| 경로 | caller | 형식/상한 | Legacy 권한 |
|---|---|---|---|
| `member_profiles/{memberId}/{file}` | 회원카드 프로필 이미지 | JPEG, 10 MiB | read/create/update/delete |
| `member_inbody/{memberId}/{file}` | 회원카드 인바디 이미지 | JPEG, 15 MiB | read/create/update/delete |
| `membership_contract_signatures/{memberId}/{file}` | 회원권계약서 서명 이미지 | PNG, 10 MiB | read/create/update/delete |
| `membership_contract_images/{memberId}/{file}` | 회원권계약서 이미지 | PNG, 10 MiB | read/create/update/delete |

영상, 레슨일지 미디어, PDF 등 실제 경로와 업로드 계약이 확인되지 않은 Storage 경로는 열지 않았다. Storage Rules도 두 claim과 비익명 조건을 요구한다.

## 로컬 상태와 workspace 전환

- 홈·설정·회원관리 등은 다수의 SharedPreferences를 사용한다. 테마와 알림 설정 등은 계정 데이터 소유권을 바꾸지 않는 기기 설정이다.
- Guest 체험 일정은 `HomeGuestScheduleRepository`의 로컬 전용 namespace를 사용하며 legacy 전환 시 업로드하지 않는다.
- `AppWorkspaceScope`가 `guest`, `linkedPersonal`, `legacyAdmin`을 명시한다. 모드별 `ValueKey`와 child 교체로 이전 legacy Home의 widget tree/stream을 해제한다.
- legacy 상단에는 `기존 개발 데이터` 표시와 `내 작업공간` 전환 버튼을 둔다. 전환은 기존 child를 폐기하며 데이터 복사나 migration을 실행하지 않는다.

## 남은 위험

- Rules는 로컬 demo Emulator에서 검증했지만 실제 프로젝트에는 배포하지 않았다.
- 기존 legacy 문서의 실제 필드 분포와 건수는 운영 데이터에 접속하지 않아 확인하지 않았다.
- Remote signature 공개 접근은 계속 닫혀 있다.
- 다운로드 URL이 이미 외부에 공유된 Storage 객체는 Rules 변경만으로 URL 유출 이력을 회수하지 못하므로 실제 활성화 전 별도 점검이 필요하다.
