# 레슨계약서 v2 PROD 배포 계획서 (P7-5)

작성: 2026-11-01(같은 날 사용자 결정 2건 반영). 대상 PROD 프로젝트: `more-than-fitness-f6adb`. DEV: `more-than-fitness-dev-mft`.
이 문서는 **계획**이다. 각 배포 단계는 시작 직전에 사용자가 따로 승인한다(Rules·Indexes·Storage·Functions·앱 릴리스 모두). 모든 명령에 `--project more-than-fitness-f6adb`를 명시하고 `--force`는 쓰지 않는다. `.firebaserc`의 default가 PROD라서 `--project` 없이 실행하면 PROD로 간다.

결정(2026-11-01, 사용자):
1. **진입점 플래그 없이 배포 순서로 진행한다.** 서버를 먼저 올리고 앱을 마지막에 내보낸다. 앱이 나간 뒤 문제가 생기면 롤아웃을 중단하거나 앱 버전을 되돌린다.
2. **앱 릴리스는 현재 작업 전체를 `1.0.7`로 묶는다.** 계약서만 따로 분리하지 않는다(0-5, 6단계).
3. **`autoExpireMemberships`는 이번 배포에서 뺀다.** 나중에 PROD 회원의 종료일 분포를 읽기 전용으로 점검한 뒤 따로 승인받아 배포한다(4-2단계).

## 0. 시작 조건 (모두 충족돼야 1단계로 간다)

| # | 조건 | 담당 | 상태 |
|---|---|---|---|
| 0-1 | DEV 폰 점검표(`lesson-contract-p7-checklist.md`) 31개 중 ×가 없다 | 사용자 | 대기 |
| 0-2 | PROD Storage 서비스 에이전트에 `Firebase Rules Firestore Service Agent` 역할 부여 후 읽기 전용 재확인 | 사용자 부여, 제가 재확인 | **완료(2026-11-01)**: 사용자가 콘솔에서 부여, 읽기 전용 재조회로 PROD에 `roles/firebaserules.firestoreServiceAgent` 반영 확인(DEV와 같은 상태) |
| 0-3 | 현재 PROD에 게시된 Firestore 규칙·Storage 규칙 원문 백업 — **완료(2026-11-01)**: 읽기 전용 조회로 `docs/agent/backups/prod-rules-2026-11-01/`에 저장, 직전 릴리스 커밋(`7744027`)의 규칙과 **내용이 같음**을 확인. 배포 직전에 PROD가 그 사이 바뀌지 않았는지 한 번 더 비교 | 제가 읽기 전용으로 수행 | 완료(배포 직전 재확인) |
| 0-4 | 명세서 §18 법률·전문가 확인 8개 검토(문구 최종 확정) | 사용자 | 대기 |
| 0-5 | 앱 릴리스 범위: **현재 작업 전체를 1.0.7로 묶는다(결정됨)**. 이에 따라 릴리스 전에 DEV 앱 전체(월렛 목록·고객카드·아나토미·위젯·테마 등 계약서 외 변경 포함)를 폰에서 한 번 더 점검하고 `flutter test`·`analyze`·PROD 빌드를 통과시킨다 | 사용자 점검(`release-1.0.7-checklist.md`), 제가 빌드·테스트 | 결정 완료, 점검 대기 |
| 0-6 | PROD 결제(Blaze)·Cloud Scheduler API 사용 가능 확인(4-2단계 `autoExpireMemberships` 배포 전까지만 있으면 됨) | 제가 읽기 전용으로 확인 | 4-2 전으로 연기 |

## 1. 변경 목록 (2026-11-01 DEV/PROD 비교 기준)

| 구분 | PROD에 추가·변경될 것 |
|---|---|
| Firestore 인덱스 | `personal_contracts` 2개 추가(`trainerId`+`updatedAt`↓, `trainerId`+`memberId`+`updatedAt`↓). 나머지 5개는 PROD와 이미 같음(서버가 `__name__`을 붙여 다르게 보일 뿐) → 삭제 대상 없음 |
| Firestore 규칙 | `personal_contracts`(+`events`)·`personal_contract_counters` 추가. 앱은 소유자 읽기만, 쓰기는 전부 거부. 기존 규칙은 변경 없음 |
| Storage 규칙 | `contract_logos/…`, `personal_contracts/{uid}/{계약}/contract_v{n}.pdf` 추가. 기존 규칙 변경 없음 |
| 함수 신규 9개 (이번 배포) | `savePersonalContractDraft`, `savePersonalContractSettings`, `signPersonalContract`, `managePersonalContract`, `voidPersonalContract`, `terminatePersonalContract`, `attachPersonalContractPdf`, `viewPersonalContract`(HTTPS), `verifyPersonalContract`(HTTPS) |
| 함수 신규 1개 (**이번 배포 제외, 4-2단계에서 따로**) | `autoExpireMemberships`(매일 00:40 KST) |
| 함수 수정 2개 | `finalizePersonalTrainingLog`, `cancelPersonalTrainingLog` — 레슨 진행 알림(`lesson_progress_notices`) 기록 추가 |
| 새 컬렉션(서버만 쓰기) | `personal_contracts`, `personal_contract_counters`, `contract_notices`, `lesson_progress_notices` |
| 앱 | 새 계약서 화면 등(§6 참고) |

기존 데이터 영향: 레거시 `contracts` 컬렉션·`ContractPage`는 건드리지 않는다. 새 컬렉션은 추가만 하므로 기존 문서는 바뀌지 않는다. 단, `autoExpireMemberships`는 **종료일이 지난 활동 회원을 매일 새벽 만료로 옮기는** 동작이라 PROD 회원 데이터를 실제로 바꾸므로 이번 배포에서 뺀다(§6 위험 2). 이 함수 없이도 계약 완료·파기·해지 때 회원 기간·상태 연동(`signPersonalContract`·`voidPersonalContract`·`terminatePersonalContract`)은 동작하며, 빠지는 것은 "종료일이 지나면 자동으로 만료로 옮기는 매일 새벽 작업"뿐이다.

## 2. 배포 순서와 명령 (각 단계 직전 승인)

모든 단계 전: `npm --prefix functions run lint`, `npm --prefix functions run build`, 서버 전체 에뮬레이터 회귀, `flutter test`, `flutter analyze`(이미 2026-11-01 통과 — 배포 직전 한 번 더).

1. **Firestore 인덱스**
   `firebase deploy --only firestore:indexes --project more-than-fitness-f6adb --non-interactive`
   확인: `firebase firestore:indexes --project more-than-fitness-f6adb`에서 2개 추가, 상태가 READY가 될 때까지 대기(규칙 전에 준비돼야 목록 조회가 실패하지 않는다).
2. **Firestore 규칙**
   `firebase deploy --only firestore:rules --project more-than-fitness-f6adb --non-interactive`
   확인: 콘솔에서 게시 시각·내용 확인.
3. **Storage 규칙** — **`--non-interactive` 없이** 실행해 역할 확인 프롬프트가 뜨게 한다(0-2가 끝났어도 이중 확인).
   `firebase deploy --only storage --project more-than-fitness-f6adb`
   확인: 읽기 전용 IAM 확인 스크립트 재실행, 콘솔 게시 확인.
4-1. **함수 11개**(이름을 모두 명시, 전체 `--only functions` 금지, `autoExpireMemberships` 제외)
   `firebase deploy --only functions:savePersonalContractDraft,functions:savePersonalContractSettings,functions:signPersonalContract,functions:managePersonalContract,functions:voidPersonalContract,functions:terminatePersonalContract,functions:attachPersonalContractPdf,functions:viewPersonalContract,functions:verifyPersonalContract,functions:finalizePersonalTrainingLog,functions:cancelPersonalTrainingLog --project more-than-fitness-f6adb --non-interactive`
   확인: `firebase functions:list --project more-than-fitness-f6adb`로 11개 확인(신규 9 + 수정 2).
   주의: 소스에는 `autoExpireMemberships`가 `index.ts`에 남아 있으므로 `--only`에 이름을 넣지 않으면 배포되지 않는다. 이름을 명시한 배포만 사용한다.

4-2. **`autoExpireMemberships`(나중에, 별도 승인)** — 선행: ① 0-6(Blaze·Cloud Scheduler) 확인 ② PROD 회원의 종료일 분포를 **읽기 전용**으로 점검(활동 회원 중 카드 종료일이 지난 사람 수, 계약 종료일이 지난 사람 수 — 첫 실행에서 만료로 옮겨질 사람 수를 미리 계산) ③ 그 수와 대상을 사용자가 확인. 그 뒤 `firebase deploy --only functions:autoExpireMemberships --project more-than-fitness-f6adb --non-interactive`. 첫 실행(다음 00:40) 직후 `auto_expire_done` 로그와 이동 건수를 확인한다.
5. **서버 스모크**(앱 릴리스 전, PROD에서 읽기 위주): 테스트 계정·테스트 회원으로 서버만 호출하는 시험은 데이터를 만들므로 하지 않는다. 대신 `viewPersonalContract`/`verifyPersonalContract` URL이 잘못된 값에 404를 내는지, 함수 로그에 오류가 없는지 확인한다.
6. **앱 릴리스 `1.0.7`**: `pubspec.yaml` 버전을 `1.0.7+27`로 올리는 것은 이 단계의 시작에서 제가 하고(요청 시), 서명된 PROD 빌드·스토어 업로드는 사용자 영역. 계약서 외 변경이 전부 포함되므로 업로드 전에 DEV 앱 전체 점검(0-5)을 끝낸다. 단계 출시(점진 배포) 권장.
7. **릴리스 후 확인**: 실제 PROD 계정의 테스트 회원 1명으로 작성 → 서명 → 완료 → PDF → (파기 또는 해지) 한 바퀴. 월렛 목록·위젯·레슨일지 등 1.0.7에 같이 들어간 기능의 기본 동작도 확인. (`autoExpireMemberships`는 4-2에서 따로 확인)

단계 사이에는 이전 단계의 확인이 끝나야 다음으로 간다. 중간에 오류가 나면 거기서 멈추고 보고한다.

## 3. 롤백

| 시점 | 방법 |
|---|---|
| 1~2단계 후 | 새 인덱스·규칙은 추가만이라 앱에 영향 없음. 되돌리려면 0-3에서 백업한 이전 규칙 원문을 재게시(승인 후) |
| 3단계 후 | 같은 방식으로 이전 Storage 규칙 재게시. 서비스 에이전트 역할은 남겨 둬도 무해(기존 규칙도 이 역할이 필요) |
| 4단계 후 | 신규 함수는 앱이 호출하기 전까지 아무도 쓰지 않음. 문제가 있으면 `firebase functions:delete 이름 --project …`(승인 후)로 삭제. 수정한 2개 함수는 이전 소스로 재배포(릴리스 커밋 `7744027`의 `functions/`) |
| `autoExpireMemberships` 오작동(4-2 이후) | 가장 먼저 예약 작업을 일시 중지(Cloud Scheduler)하거나 함수 삭제. 이미 만료로 옮겨진 회원은 `managementStateHistory`의 `source: auto_expire` 이력으로 찾아 복구 |
| 6단계(앱) 후 | 스토어 단계 출시 중단·이전 버전 복귀. 서버는 그대로 두어도 이전 앱에는 영향 없음 |

데이터 백업: 이번 배포(4-1까지)는 추가 위주라 데이터 복구가 필요한 경우가 없다. 데이터를 바꾸는 `autoExpireMemberships`(4-2) 전에 백업을 정한다. PROD는 PITR이 꺼져 있고 관리형 백업이 없다(2026-10 기록). 첫 배포 전 Firestore 관리형 export를 만들지 사용자가 결정한다(권장: 최소한 `members` 컬렉션 export).

## 4. 배포 후 모니터링

- 첫 24시간: 함수 로그의 오류 비율(`terminatePersonalContract` 등 신규 함수), Storage 403 로그.
- 4-2 배포 다음 날 00:40 이후: `auto_expire_done` 로그의 `checked/expired/skipped`와 PROD 회원 만료 이동 건수를 사용자 확인.

## 5. 이번 계획에서 제외한 것

- 해지 사실 통지 링크, 파기·해지 알림 실제 발송, 오프라인 지원, 회원권계약서, 상담·인사이트.
- 진입점 플래그(2026-11-01 결정: 만들지 않음).

## 6. 위험과 사용자 결정이 필요한 것

1. **앱 릴리스 범위가 계약서만이 아니다 → 결정: 전체를 1.0.7로 묶는다.** 직전 릴리스(`7744027`, 1.0.6+26) 이후 커밋되지 않은 변경이 약 170개 파일이고 대부분 계약서와 무관하다(월렛식 회원 목록, 고객카드 헤더, 레슨일지 아나토미, 위젯 3종·지금·다음 위젯, 테마 등). 앱을 릴리스하면 전부 함께 나가므로 계약서 점검(0-1)과 별개로 **DEV 앱 전체 회귀 점검**이 필요하다. 커밋·푸시는 요청이 있을 때만 하며 지금은 하지 않았다. 남은 위험: 위젯의 PROD 변형(`모어댄 지금·다음`)이 처음 실기기에서 확인되는 것도 이 릴리스다(PROD 빌드·매니페스트까지만 확인함).
2. **`autoExpireMemberships`는 PROD 데이터를 바꾼다 → 결정: 이번엔 뺀다(4-2).** 종료일이 지난 활동 회원을 매일 새벽 `만료`로 옮긴다. 종료일 판단은 "최근 완료 계약 종료일 또는 회원카드 종료일 중 늦은 날"이고 계약이 없는 회원은 카드 종료일만 본다. 카드 종료일이 지난 활동 회원이 많으면 첫 실행에서 대량 만료가 일어날 수 있어, 읽기 전용 분포 점검 후 따로 배포한다.
3. **Storage 규칙은 서비스 에이전트 역할 부여 전에는 올리지 않는다**(0-2).
4. **법률 문구는 법률 자문이 아니다.** §18 전문가 확인 전에는 계약서 문구를 최종본으로 보지 않는다.
