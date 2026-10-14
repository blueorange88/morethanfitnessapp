# Tenant Identity Migration Plan

작성일: 2026-07-15  
상태: 계획만 작성, 운영 데이터 접근·변경 없음

## 목적

`members`, `training_logs`, `contracts`, `schedules`의 owner identity를 검증된 Firebase Auth UID와 조직 membership에 결속한다. 이름이나 화면 표시값으로 trainerId를 추측하지 않는다.

## 선행조건

다음이 완료되기 전에는 dry-run도 운영 프로젝트에 실행하지 않는다.

1. 실제 인증 provider와 계정 생성·로그인·로그아웃·계정전환 정책 확정.
2. Auth UID와 UID 기반 trainer profile의 1:1 결속.
3. 개인/조직/지점 membership과 active tenant 정책 확정.
4. 원본 데이터 백업·복구 승인과 개인정보 접근 권한 확정.
5. migration 도구 실행 주체와 감사 로그 보존정책 확정.

## Legacy 판정 기준

### members

- `trainerId`가 없거나 빈 값.
- trainerId가 있으나 Auth UID/profile membership에서 검증되지 않음.
- 기존 `trainer` 표시 문자열만 존재.
- 여러 trainer가 동일 회원을 관리했으나 담당/조직 권위 기록이 없음.

### training_logs

- `lessonLogId != document.id` 또는 lessonLogId 누락.
- trainerId/memberId/createdAt 누락.
- trainerId가 parent schedule/member/서명 request의 검증된 owner와 충돌.
- merge update로 만들어져 생성 주체를 판정할 수 없는 부분 문서.
- 공개 원격서명이 만든 owner 없는 parent.

### contracts

- trainerId/tenant identity가 없음.
- profile 표시명만 있고 계약 작성 Auth UID가 없음.
- 완료 revision과 작성자/조직 결속이 불명확.

### schedules

- trainerId/organization membership이 없음.
- 연결 member와 owner가 충돌.
- 복사·이동 과정의 source/target owner가 불명확.

## trainerId를 추론할 수 있는 근거

자동 apply가 아니라 사람 검토 후보를 만드는 근거다.

- Firebase Auth export의 UID와 검증된 UID profile 문서의 직접 일치.
- 서버가 기록한 불변 작성자 UID 또는 검증된 audit event.
- 조직 membership 문서와 문서 생성 시점의 active membership.
- 신뢰 가능한 schedule owner와 transaction으로 함께 생성된 training log 연결.
- 검증된 sign request가 보존한 원래 trainer UID.

이름, 닉네임, 이메일 표시 문자열, 전화번호, 회원 이름, `trainer_profile/me`, 문자열 `me`는 단독 근거로 사용하지 않는다. 동명이인, 계정 변경, 공유 기기, 조직 이동 때문에 owner를 잘못 귀속할 수 있다.

## Dry-run 보고서

실제 값을 불필요하게 출력하지 않고 식별자는 해시/내부 reference로 제한한다.

| 필드 | 설명 |
| --- | --- |
| collection/path hash | 원문 경로 대신 검토용 안정 해시 |
| documentType | member/training_log/contract/schedule |
| legacyReasons | 누락·충돌 코드 목록 |
| candidateTrainerIdHash | 후보가 있을 때 UID 해시 |
| evidenceTypes | profile/audit/schedule/membership 등 |
| confidence | auto 금지, reviewable/ambiguous/unresolved 분류 |
| proposedChanges | trainerId, lessonLogId, schemaVersion 등 필드명만 |
| blockers | 조직 충돌, 다중 후보, source 부재 |
| action | review/skip/quarantine |

원문 개인정보, 서명 좌표, 건강 메모, 전화번호는 보고서에 넣지 않는다.

## Apply 절차

1. Firestore managed export 또는 승인된 동등 백업 생성 및 복원 시험.
2. dry-run 결과를 데이터 책임자가 검토하고 명시 승인.
3. migration run ID와 schema target version 발급.
4. 문서별 precondition/updateTime을 사용해 동시 수정 충돌 차단.
5. 이미 target schema와 동일하면 no-op인 idempotent update.
6. 기존 값은 migration audit에 해시·상태로 기록하고 무분별한 overwrite 금지.
7. ambiguous/unresolved 문서는 변경하지 않고 계속 deny 대상으로 유지.
8. 실패 문서는 error code와 재시도 가능 여부를 별도 기록.

## Rollback

- apply 전에 생성한 managed export가 최종 복구 기준이다.
- field-level rollback을 지원하려면 run ID별 before snapshot을 승인된 보안 저장소에 보관한다.
- 부분 실패 시 성공 문서를 즉시 임의 되돌리지 않고 run을 중단하고 영향 범위를 보고한다.
- Rules 전환 전 migration 결과를 검증하므로 rollback 중 owner-scoped Rules가 데이터를 숨기는 상황을 피한다.

## 완료 확인 기준

- 신규 쓰기 100%가 canonical repository를 사용.
- 대상 parent에 trainerId/memberId/lessonLogId/schemaVersion/createdAt/updatedAt 존재.
- lessonLogId가 document ID와 100% 일치.
- trainerId가 Auth/profile 또는 조직 membership에서 검증됨.
- unresolved legacy 수와 경로 유형이 별도 보고되고 자동 허용되지 않음.
- 공개 원격서명 direct write 제거.
- owner-scoped query와 Emulator Rules 행렬 통과.

## Query·Rules 전환 순서

1. Auth gate와 canonical 신규 쓰기 배포.
2. 신규 데이터의 owner-scoped shadow query/telemetry 검증.
3. legacy dry-run, 승인, 백업, apply.
4. members → schedules → training_logs → contracts 순으로 관계 정합성 확인.
5. trainer filter를 앱 query에 단계적으로 적용.
6. unresolved legacy를 별도 운영 검토 목록으로 격리.
7. Firestore Emulator에서 본인/타 trainer/조직/공개 사용자 행렬 통과.
8. 실제 배포 Rules diff와 rollback 계획 승인 후 Rules 배포.

이번 작업에서는 planner 코드, 서비스 계정, 비밀키, 운영 연결, apply를 만들거나 실행하지 않았다.
