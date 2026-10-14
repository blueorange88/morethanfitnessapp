# 계약서·전자서명 테스트 매트릭스

감사일: 2026-07-15

현재 저장소에는 계약/서명 전용 테스트를 찾지 못했다. 아래는 구현 전 실패 테스트와 emulator 통합 테스트의 권장 범위다.

## 레슨계약서

| ID | 시나리오 | 계층 | 기대 결과 | 우선순위 |
|---|---|---|---|---|
| C-01 | 기본정보 누락 후 1단계 저장 | unit/widget + fake repository | write 0회, 첫 오류 표시 | P0 |
| C-02 | 결제/기간 오류 후 저장 | unit | contract/member/counter write 0회 | P0 |
| C-03 | 저장 버튼 빠른 2회 탭 | concurrency integration | 계약 1개, 번호 1회, member update 1회 | P0 |
| C-04 | 기본 양측 서명만 완료 | emulator | `awaiting_final_signature`, member `contractSigned=false` | P0 |
| C-05 | 최종 동의/건강고지 누락 | unit/integration | completed 전이 거부 | P0 |
| C-06 | 최종 양측 서명 완료 | emulator | immutable revision 1개, server completedAt, current pointer 원자 갱신 | P0 |
| C-07 | 완료 후 중요 필드 수정 | Rules emulator | update 거부 또는 새 draft version 생성 | P0 |
| C-08 | 내용 변경 후 기존 서명 재사용 | unit/integration | hash 불일치로 완료 거부 | P0 |
| C-09 | 새 계약/새 버전 | integration | 이전 version 보존, previous/superseded 연결 | P1 |
| C-10 | 완료 계약 취소/무효 | integration | append-only revoke event, member current pointer 일관 | P1 |
| C-11 | 목록 soft delete | integration | 유효 계약 상태를 삭제로 오인하지 않고 정책에 따른 숨김 | P1 |
| C-12 | 네트워크 중단 후 재시도 | fault injection | 같은 idempotency key/contract version 유지 | P0 |
| C-13 | counter 성공 후 계약 실패 | fault injection | 중복 계약 없음, gap 정책 문서화 | P1 |
| C-14 | 완료 후 회원 자동등록 실패 | integration | 부분 성공 상태가 명시되고 안전한 재시도 가능 | P0 |
| C-15 | 기존 회원 재등록 | integration | 기존 ledger 보존 + 신규 credit만 추가 | P0 |

## 회원권계약서

| ID | 시나리오 | 계층 | 기대 결과 | 우선순위 |
|---|---|---|---|---|
| M-01 | 초안 저장 | emulator | draft version과 member pointer가 원자적으로 일치 | P1 |
| M-02 | signed 문서에서 초안 저장 | unit/Rules | 기존 signed version 변경 거부 | P0 |
| M-03 | 서명 완료 | emulator+Storage | artifact finalize와 signed version/current pointer 일치 | P0 |
| M-04 | 이미지 업로드 성공, Firestore 실패 | fault injection | staging artifact 정리 또는 재시도 상태 기록 | P1 |
| M-05 | contract write 성공, member write 실패 | fault injection | transaction으로 부분 성공 없음 | P0 |
| M-06 | 서명 버튼 연속 탭 | concurrency | artifact/version 1개 | P1 |
| M-07 | 새 버전 작성 | integration | 새 ID, 이전 버전 immutable | P1 |
| M-08 | 이전 버전 조회 | integration | signed 당시 본문/서명/해시 보존 | P1 |
| M-09 | 서명 후 화면 캡처 전 내용 변경 | integration | signed revision과 다른 이미지 archive 차단 | P1 |

## 원격 서명

| ID | 시나리오 | 계층 | 기대 결과 | 우선순위 |
|---|---|---|---|---|
| R-01 | 정상 token 교환/서명 | Functions+emulator | 최소 payload, request used와 signed revision 원자 commit | P0 |
| R-02 | 만료 token | Functions | 읽기/서명 거부, expired audit event | P0 |
| R-03 | 이미 사용한 token | concurrency | 두 번째 제출 거부, 서명 revision 1개 | P0 |
| R-04 | 취소/revoked token | Functions | 제출 거부, revoke 사유 보존 | P0 |
| R-05 | 동시에 두 번 제출 | concurrency | 정확히 하나만 성공 | P0 |
| R-06 | request의 memberId 위조 | Functions | 저장된 request 대상과 불일치해 거부 | P0 |
| R-07 | contractId/trainingLogId 위조 | Functions | 불일치 거부 | P0 |
| R-08 | token 교환 응답 최소화 | API contract | 전화번호/다른 log/health 정보 미노출 | P0 |
| R-09 | 서명 transaction 중단 | fault injection | request unused, revision 없음 또는 완전 commit | P0 |
| R-10 | 만료 직전 경쟁 | fake clock/concurrency | server time 기준 단일 결정 | P1 |
| R-11 | 반복 실패/rate limit | Functions | 제한 및 attempt audit, 다른 token 영향 없음 | P1 |
| R-12 | trainer가 확정해 pending 요청 취소 | integration | 이후 공개 제출 불가 | P0 |
| R-13 | 공개 페이지 서명 이력 | security integration | 해당 회원에게 허용된 최소 이력만 서버 제공 | P1 |

## 레슨확정·회차

| ID | 시나리오 | 기대 결과 | 우선순위 |
|---|---|---|---|
| L-01 | 미완료 계약의 레슨확정 | contract basis가 되지 않음 | P0 |
| L-02 | 완료 계약 레슨 1회 확정 | ledger 1건, remain -1, 중복 confirm 무효 | P0 |
| L-03 | 서비스 레슨 | 차감 0, service event 1건 | P1 |
| L-04 | 노쇼 차감/미차감 | 각각 정책에 맞는 ledger/count | P1 |
| L-05 | 확정 취소 | reverse event 1건, 정확히 1회 복원 | P0 |
| L-06 | 취소 연속 2회 | 두 번째 복원 0회 | P0 |
| L-07 | schedule/log/member 중 하나 write 실패 | transaction 전체 실패 | P0 |
| L-08 | legacy remaining 필드 불일치 | canonical 값 사용, drift 감지 | P1 |

## 권한/멀티테넌시

| ID | 시나리오 | 기대 결과 | 우선순위 |
|---|---|---|---|
| S-01 | 트레이너 A가 B의 member 읽기 | 거부 | P0 |
| S-02 | A가 B의 contract/list 조회 | 거부, query 자체 owner-scoped | P0 |
| S-03 | A가 B의 training_log/schedule 쓰기 | 거부 | P0 |
| S-04 | 비로그인 사용자의 Firestore 직접 읽기 | 모두 거부 | P0 |
| S-05 | 공개 서명 사용자의 members/training_logs query | 거부 | P0 |
| S-06 | 다른 tenant 서명 이미지 읽기 | 거부 | P0 |
| S-07 | 잘못된 contentType/과대 Storage 업로드 | 거부 | P1 |
| S-08 | completed contract update/delete | client에서 거부 | P0 |
| S-09 | soft-deleted 문서 일반 목록 노출 | 제외 | P1 |

## 전송/공유

| ID | 시나리오 | 기대 결과 | 우선순위 |
|---|---|---|---|
| D-01 | OS 공유창 열고 취소 | `share_opened`, `sent` 아님 | P1 |
| D-02 | 인쇄 dialog 열고 취소 | `print_opened`, printed 아님 | P1 |
| D-03 | provider 접수 실패 | failed event와 오류, sent/delivered 아님 | P1 |
| D-04 | provider 접수/전달 webhook | provider ID와 accepted/delivered 구분 | P1 |
| D-05 | 같은 revision 재전송 | append-only delivery event, 대상 마스킹 | P1 |
| D-06 | 서명 후 본문 변경 PDF 생성 | hash 불일치로 차단 | P0 |

## Anatomy 실데이터·권한

| ID | 시나리오 | 계층 | 기대 결과 | 우선순위 |
|---|---|---|---|---|
| A-01 | 존재하는 parent와 정상 child 저장 | service+emulator | parent metadata와 child가 한 번에 저장 | P0 |
| A-02 | 존재하지 않는 parent에 child 저장 | service+Rules | 암묵 parent 생성 없이 거부; 별도 parent 생성 흐름 요구 | P0 |
| A-03 | parent trainerId와 auth UID 불일치 | Rules emulator | list/get/create/update/delete 모두 거부 | P0 |
| A-04 | parent memberId와 child/context memberId 불일치 | service+Rules | 저장·조회 거부 | P0 |
| A-05 | path lessonLogId와 child field 불일치 | service+Rules | 자동 교정하지 않고 거부 | P0 |
| A-06 | path anatomyLogId와 child field 불일치 | service+Rules | create/update 거부 | P0 |
| A-07 | update에서 trainerId/memberId/lessonLogId 변경 | Rules emulator | 불변 field 변경 거부 | P0 |
| A-08 | 다른 trainer의 record ID를 삭제 요청 | service+Rules | 삭제 거부, 원본 유지 | P0 |
| A-09 | owner 없는 과거 parent | migration+Rules | client 선점 거부, 승인 backfill 전 비공개 | P0 |
| A-10 | scheduleDocId 없는 수동 parent | integration | parent owner/member가 유효하면 anatomy 저장 가능 | P1 |
| A-11 | scheduleDocId 없는 quick/remote/과거 log | integration | schedule 없는 이유만으로 차단하지 않음 | P1 |
| A-12 | parent와 child의 비어 있지 않은 scheduleDocId 불일치 | service+Rules | 저장 거부 | P1 |
| A-13 | parent soft delete/void 정책 상태 | Rules | 정책에 따른 read-only 또는 접근 거부를 일관 적용 | P1 |
| A-14 | parent hard delete 후 orphan child 직접 접근 | Rules emulator | parent exists 검사로 read/write 거부 | P0 |
| A-15 | 승인된 recursive cleanup | Functions/emulator | 해당 parent child만 삭제, 건수·실행자 audit | P1 |
| A-16 | 신규 child 구조 목록 개수 | integration | 실제 child 0/1/N 및 삭제 후 정확한 count | P2 |
| A-17 | legacy parent 배열 fallback | security integration | parent owner 일치 기록만 읽고 migration 후 배열 제거 | P1 |
| A-18 | parent/child batch 중 한 write 실패 | fault injection | 전체 실패, 성공 토스트·로컬 완료 없음 | P0 |

## 실행 단계

1. 순수 상태 전이와 validator 단위 테스트.
2. Firestore/Storage Rules emulator 교차 사용자 및 anatomy parent-child 불변조건 테스트.
3. Functions emulator token/동시성/fake clock 테스트.
4. repository fault injection으로 각 write 경계 실패 테스트.
5. 실제 staging 프로젝트에서 Storage finalize와 provider sandbox receipt 테스트.

실제 배포 Rules와 외부 전송 사업자 없이 단위 테스트만 통과한 경우 “실제 권한/전송 검증 완료”로 기록하면 안 된다.
