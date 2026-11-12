# 레슨계약서 v2 구현 계획 (초안)

- 상태: 초안 (사용자 검토 전). **이 문서 작성 시점까지 코드·규칙·서버 변경 없음.**
- 작성일: 2026-10-15
- 기준 문서: `docs/product/lesson-contract-spec.md`(조항·흐름·결정 확정), `docs/agent/CONTRACT_SIGNATURE_AUDIT.md`
- 범위: 레슨계약서만. 회원권계약서·상담·인사이트는 이 계획 밖.

## 0. 한 줄 요약

**서버가 계약의 상태와 증빙을 소유하는 새 구조**(`personal_contracts` + callable 함수)를 만들고, 앱은 그 위에 새 계약 화면(조항 선택형·고지 화면·서명 2+1·PDF 링크 교부)을 얹는다. 기존 `contracts` 컬렉션과 기존 `ContractPage`는 **건드리지 않아** 레거시 관리자 흐름에 영향이 없다.

## 1. 현재 코드에서 확인한 사실 (계획의 근거)

| # | 사실 | 계획에 미치는 영향 |
|---|---|---|
| 1 | 일반(personal) 트레이너는 `contracts`, `members`(직접 쓰기), `membership_contracts`, 서명 Storage 경로에 **규칙상 쓸 수 없다**(legacy admin 전용, 에뮬레이터 테스트로도 확인) | 클라이언트 직접 쓰기를 전부 **서버 함수로 이전**해야 한다 |
| 2 | 서버 함수(`functions/src`)에는 계약 관련 코드가 **전혀 없다** | 계약 도메인을 서버에 새로 만든다 |
| 3 | 계약 목록(`ContractListPage`)은 `contracts`를 **소유자 필터 없이** 최근 순 전체 조회 | 일반 계정에서는 거부되고, 허용되면 교차 노출 위험. 새 목록은 `trainerId` 필터 필수 |
| 4 | 회원 자동 등록(`_registerClientCardFromContract`)이 클라이언트에서 `members`를 직접 병합 | 서버 트랜잭션으로 이전(기존 회원 함수의 검증 재사용) |
| 5 | 일반 워크스페이스의 레슨 확정·차감은 서버(`finalizePersonalTrainingLog`)가 처리하고, 거기에 계약 참조는 없다 | 계약 완료가 레슨 확정 기준(`contract`)에 영향을 주려면 서버 쪽 연동 지점이 필요하다(P6) |
| 6 | 레슨 확정 기준은 `memberData.contractSigned == true || lessonSync.contractId != ''`이면 `contract`(취소 잠금 포함) | 서버가 `contractSigned`·`lessonSync.contractId`를 **완료 시에만** 기록한다 |
| 7 | 센터명 기본값 `MORE THAN FITNESS`, 앱 메모리(static) 기본 조건, 로컬 시각 서명, 계약번호 클라이언트 발급 | 모두 새 구조에서 제거·대체 |
| 8 | 계약 로직 테스트가 사실상 없다 | 새 모듈은 **테스트 우선**으로 만든다 |
| 9 | 일반 워크스페이스에서 계약 저장이 지금까지 불가능했으므로 **personal 소유 계약 데이터는 거의 없을 것**이다 | 데이터 이관 부담이 작다(P0에서 실제로 확인) |

## 2. 설계 결정 (권장안)

| # | 결정 | 권장 | 이유 |
|---|---|---|---|
| A | 데이터 위치 | **새 컬렉션 `personal_contracts`** (기존 `contracts` 유지) | 소유자 경계를 처음부터 넣고 레거시와 격리. 기존 관리자 기능 무영향 |
| B | 화면 | **새 모듈** `lib/pages/lesson_contract/`(작은 파일들). 기존 11,000줄 `ContractPage`는 레거시용으로 그대로 두고 personal 진입점만 새 화면으로 분기 | 대규모 리팩터링 금지 원칙. 롤백이 쉬움 |
| C | 서명 저장 | 서명 이미지가 아니라 **획(stroke) 데이터를 서명 이벤트 문서에 저장**하고 PDF에서 렌더링 | Storage 규칙·고아 파일 문제 회피 |
| D | PDF 열람 링크 | 서버 HTTPS 함수가 **토큰 검증 후 PDF 제공** + 열람 시각 기록. 링크 유효 **90일**(강사가 재발급 가능) | 문자·카톡 링크가 메인(확정), 열람 기록이 전달 증빙 |
| E | 서버 티어 검증 | 계약 생성 함수에서 **서버가 등급(Semi-Pro 이상)을 다시 확인** | 현재는 클라이언트 게이트만 있어 우회 가능 |

(D의 90일, E는 확인이 필요한 항목이다. §10)

## 3. 데이터 모델

```
personal_contracts/{contractId}
  trainerId, workspaceType: 'personal', memberId
  contractNo            서버 발급 (예: PT-2610-0001, 트레이너·월별 카운터)
  version, supersedesId, supersededById
  status                draft | disclosed | member_signed | completed | cancelled | superseded
  party{}               당사자 스냅샷 (센터/개인, 상호, 사업자번호, 연락처, 장소, 로고 경로)
  member{}              회원 스냅샷 (이름, 연락처, 생년월일·이메일 선택)
  product{}             상품명, 서비스 내용, 횟수, 1회 시간, 실결제금액, 정상가(선택), 계약 단가, 결제방법·결제일, 기간(시작~종료)
  terms{}               취소 마감 시간, 노쇼·마감후취소 차감(1 고정), 강사사정 취소(미차감·보강 고정), 위약금 %(≤10),
                        소진 기준(contract|list_price), 환급 3영업일, 양도 정책, 만료 후 소멸, 추가 특약, 안내 문구 버전
  contentHash           terms+product+party+member+템플릿 버전의 정규화 JSON SHA-256 (서명 ① 이후 변경 시 달라짐 → 무효)
  disclosure{}          서명 ① 시각, 체크 항목 목록, 보여준 내용 해시
  delivery{}            pdfPath, pdfHash, linkTokenHash, linkExpiresAt, shareOpenedAt, firstViewedAt, viewCount
  createdAt, updatedAt, completedAt     (모두 서버 시각)

personal_contracts/{contractId}/events/{eventId}      (append-only, 서버만 쓰기)
  type: draft_saved | disclosure_signed | member_signed | trainer_signed | completed |
        link_created | shared | viewed | cancelled | superseded
  at(서버), actorRole(trainer|member), contentHash, payload{ checkedItems[], strokes, ... }

personal_contract_counters/{trainerId}_{yyyyMM}        (서버만, 트랜잭션 증가)
trainer_profiles/{uid}.contractParty / .contractDefaults   (설정, 기존 프로필 함수 확장)
Storage: personal_contracts/{trainerId}/{contractId}/contract_v{n}.pdf   (create-only)
         contract_logos/{trainerId}/logo_{ms}.png
```

### 상태 전이 (서버가 강제)
| 현재 | 동작 | 다음 | 서버 검증 |
|---|---|---|---|
| (없음) | 초안 저장 | `draft` | 필수값·상한(위약금 ≤10%)·금지 문구·고정 값(차감 1, 강사 취소 미차감) |
| `draft`/`disclosed` | 내용 수정 | `draft` | 이전 서명 ①이 있으면 **무효 처리**(재고지) |
| `draft` | 서명 ① | `disclosed` | 모든 고지 항목 체크, `contentHash` 확정 |
| `disclosed` | 서명 ② | `member_signed` | 같은 `contentHash` |
| `member_signed` | 강사 서명 | **`completed`** | 같은 `contentHash`, 이후 **수정·삭제 불가**, 회원 포인터 기록 |
| `draft`/`disclosed`/`member_signed` | 취소 | `cancelled` | 사유 기록 |
| `completed` | 새 버전 | 새 `draft`(+ 원본 `superseded`) | 완료 후 변경은 새 버전만 |

**서명 ①만으로는 절대 `completed`가 되지 않는다.**(현재 결함의 수정)

## 4. 서버 구성 (callable, 리전 asia-northeast3)

| 함수 | 역할 |
|---|---|
| `savePersonalContractDraft` | 초안 생성·수정, 서버 검증, 계약번호 발급, 서버 시각 |
| `signPersonalContract` | `step`(disclosure/member/trainer)별 서명 이벤트 기록, 상태 전이, 완료 시 회원 포인터 기록 |
| `managePersonalContract` | 취소·새 버전·초안 삭제 |
| `attachPersonalContractPdf` | 업로드된 PDF의 해시 계산·기록, 열람 링크 토큰 발급(해시만 저장) |
| `viewPersonalContract` (HTTPS) | 링크 토큰 검증 후 PDF 제공, 열람 시각·횟수 기록 |
| `updatePersonalTrainerProfile` (확장) | `contractParty`·`contractDefaults` 허용 키 추가 + 검증 |

- 기존 관례(`requireUid`, `validateProfile`, `allowOnly`, `translateError`, 트랜잭션)를 그대로 따른다.
- 서버 검증 규칙은 **함수 한 곳**(`personal_contract_rules.ts`)에 두고 클라이언트도 같은 규칙의 Dart 구현을 쓴다(둘 다 테스트).
- 회원 포인터(완료 시): `members/{memberId}`에 `contractId`, `contractNo`, `contractStatus: 'completed'`, `contractSigned: true`(레거시 호환 플래그), `lessonSync.contractId`, `lastContractSummary` — **트랜잭션**으로 계약 문서와 함께 기록.

## 5. 규칙 (Firestore·Storage)

- `personal_contracts` 및 하위: **읽기** `trainerId == auth.uid && workspaceType == 'personal'`, **쓰기 전부 거부**(서버 전용).
- `personal_contract_counters`: 전부 거부.
- Storage `personal_contracts/{uid}/{contractId}/…pdf`: 소유자 `create`만(덮어쓰기·삭제 불가), `application/pdf`, ≤10MB, 해당 계약 문서가 `completed`일 때.
- Storage `contract_logos/{uid}/…`: 소유자 create/update, 이미지 형식·크기 제한.
- 인덱스: `personal_contracts (trainerId, updatedAt desc)`, `(trainerId, memberId, updatedAt desc)`.
- **기존 규칙 변경 없음**(추가만).

## 6. 클라이언트 구성

```
lib/pages/lesson_contract/
  lesson_contract_flow_page.dart       단계 진행 + 이어하기
  lesson_contract_form_page.dart       강사 입력(상품·조항 선택형)
  lesson_contract_disclosure_page.dart 핵심 고지 카드 ①~⑤ + 확인 체크
  lesson_contract_terms_page.dart      나머지 조항 + 서명 ②
  lesson_contract_trainer_sign_page.dart 요약 확인 + 강사 서명
  lesson_contract_done_page.dart       완료·교부(링크 공유)
  lesson_contract_settings_page.dart   당사자·내 기본 조건
lib/models/lesson_contract/            PersonalContract, Terms, Product, Party, 이벤트
lib/services/personal_contract_gateway.dart   callable 래퍼
lib/utils/lesson_contract/             환불 계산, 금지 문구 가드, 기본안과 다름 비교, 해시 입력 정규화
lib/widgets/signature_pad.dart         기존 서명 패드(`_SignatureDialog`)를 공용으로 분리
```

- 진입점: 계약 목록(personal)과 홈 빠른 작업의 레슨계약서 칩이 새 흐름으로 이동. `personalOwnerUid`가 없는 경로(레거시)는 기존 `ContractPage` 유지.
- 계약 목록: 새 목록이 `personal_contracts`를 `trainerId`로 조회.
- 재사용: 상품 프리셋, 서명 패드, PDF 라이브러리, 한글 폰트 처리.
- 새로 작성: PDF 본문(핵심 고지 요약 포함), 조항 구조, 입력 가드.

## 7. 단계별 계획

각 단계는 **DEV에서 검증하고 다음 단계로 넘어간다.** Firestore Rules·Functions·Storage·인덱스 배포와 PROD는 **단계마다 별도 승인**.

### P0. 사전 확인 (코드 변경 없음, 승인 불필요)
- 일반 트레이너로 `contracts`·`members` 쓰기가 막히는지 **에뮬레이터 + DEV 실기기**로 실측.
- DEV·PROD 콘솔에서 `contracts`에 personal 소유 문서가 있는지 확인(예상 0건).
- 레거시 관리자 계정이 지금 `contracts`를 실제로 쓰는지(사용 중이면 기존 화면 유지 필수).
- 서버 티어 정보를 읽는 방법 확인(`tier_qualification.ts`).
- 법률·전문가 확인 요청 시작(spec §18).
- **산출**: 실측 보고서, 확정된 읽는 곳 목록.

### P1. 서버 기반 (가장 크고 중요)
- **진행(2026-10-15): 로컬 구현·에뮬레이터 19/19 통과, 배포 전.** 구현 중 달라진 점: 서명 획은 배열 중첩 불가로 `{points:[…]}` 맵 배열 저장 / 새 버전은 새 버전 완료 시 원본이 `superseded` / 읽기 규칙은 `trainerId`만 검사 / `delete_draft` 없음(취소로 대체). 자세한 내용은 RUN_LOG.
- 모델·상태 전이·검증 규칙·계약번호·해시를 순수 함수로 작성하고 단위 테스트.
- callable 3개(draft/sign/manage) + 규칙 + 인덱스.
- **에뮬레이터 테스트**: 소유자 읽기, 타 트레이너 거부, 클라이언트 쓰기 거부, 전이 규칙(잘못된 순서 거부), 서명 ① 이후 수정 시 무효, 완료 후 수정·삭제 거부, 새 버전, 계약번호 동시 발급 중복 없음, 해시 결정성, 서버 티어 검증.
- **승인 필요**: DEV 규칙·인덱스·함수 배포.

### P2. 설정
- `updatePersonalTrainerProfile` 확장(`contractParty`, `contractDefaults`), 로고 Storage, 설정 화면.
- 센터 연결 시 로고·상호 자동, 아니면 강사 개인. 센터명 기본값 제거.
- **승인 필요**: DEV 함수·Storage 규칙 배포.

### P3. 계약 입력 화면
- 조항 선택형, 환불 산식·계산 예시(계약 단가/정상가, 상한), 입력 가드, `기본안과 다름` 표시.
- 서버 draft 저장 연결, 이어하기(진행 상태 복원).
- 테스트: 환불 계산(계약 단가·정상가·상한 경계값), 금지 문구 가드, 위약금 상한 입력, 위젯 테스트.

### P4. 서명 흐름
- 고지 카드 ①~⑤(항목별 체크 → 서명 패드 자동) → 서명 ① → 나머지 조항 → 서명 ② → 강사 서명.
- 중단·재개, 서명 ① 이후 수정 시 재고지.
- 테스트: 상태 머신 위젯 테스트, 서명 패드 입력, 서버 연동 통합.

### P5. PDF·교부
- 새 PDF 레이아웃(표지 → 핵심 고지 요약 → 전체 조항 → 환불 예시 → 서명 3개와 시각).
- 완료 시 PDF 업로드 → 해시·링크 발급 → 문자·카톡 공유 화면 → `shared`/`viewed` 기록.
- **승인 필요**: DEV HTTPS 함수·Storage 규칙 배포.

### P6. 연동
- 계약 목록을 새 컬렉션으로 교체, 회원카드의 계약 표시·계약서 작성 유도(`계약 미완료`).
- 회원 자동 등록을 서버 트랜잭션으로 이전(기존 회원 함수 검증 재사용).
- 레슨 확정 기준 연동 방침 확정: 서버 `finalizePersonalTrainingLog`가 `contractSigned`/`lessonSync.contractId`를 `contract` 기준으로 쓰는지 확인하고 필요 시 최소 변경.
- 기존 홈의 계약서 칩·확정 흐름 회귀 확인.

### P7. 통합 검증과 PROD
- DEV 시나리오: 계약 없는 회원 / 작성 중 / 서명 ①만 / 서명 ②까지 / 완료 / 재계약(새 버전) / 완료 후 수정 시도 / 일반 계정 저장 / 레거시 관리자 계정 회귀 / 환불 계산값 / 금지 문구 / 중단·재개.
- 실기기(Galaxy): 전체 흐름, 다크모드, 작은 화면, PDF 열람 링크(문자·카톡).
- PROD 순서: **규칙·인덱스 → 함수 → 앱**(앱이 먼저 나가면 새 화면이 서버 함수를 못 찾는다). 앱 진입점은 서버 준비 전까지 숨긴다.

## 8. 위험과 대응

| 위험 | 대응 |
|---|---|
| 레거시 관리자 흐름 파손 | 기존 `contracts`·`ContractPage`·규칙 무변경, 새 컬렉션 격리, 회귀 테스트 |
| 서버 규칙과 클라이언트 규칙 불일치 | 규칙을 한 곳에 정의 + 양쪽 단위 테스트에 같은 사례 |
| 서명 이후 변경으로 증빙 약화 | 해시 비교, 서버가 완료 후 수정 거부, 이벤트 append-only |
| PDF 링크 유출 | 토큰 해시만 저장, 만료, 재발급, 열람 기록 |
| 회원카드·레슨 확정 오작동 | 완료 시에만 포인터 기록, 기존 플래그 의미 유지, P6 회귀 |
| 작업 범위 팽창 | 단계별 승인과 검증, 회원권계약서·상담·인사이트는 범위 밖 |
| 법률 문구 미확정 | 문구는 데이터(템플릿 버전)로 분리해 코드 배포 없이도 개정 가능하게 설계(P3) |

## 9. 롤백

- 새 컬렉션·함수·규칙은 **추가만** 하므로 앱 진입점 숨김(플래그)으로 즉시 되돌릴 수 있다.
- 서버 함수는 이전 버전으로 재배포 가능. 규칙은 이전 파일 재배포.
- 이미 만들어진 `personal_contracts` 데이터는 새 구조에서만 읽히므로 레거시에 영향 없음.

## 10. 계획 중 확인이 필요한 것 (모두 권장안 있음)

| # | 질문 | 권장 |
|---|---|---|
| 1 | 새 컬렉션 `personal_contracts`를 쓰고 기존 `contracts`는 그대로 둔다 | 예 |
| 2 | PDF 열람 링크 유효기간 | 90일, 강사가 재발급 가능 |
| 3 | 계약 생성 시 서버가 등급(Semi-Pro 이상)을 다시 확인 | 예 |

## 11. 승인이 필요한 작업 (요약)

| 시점 | 작업 |
|---|---|
| P1 | DEV Firestore Rules·인덱스·Functions 배포 |
| P2 | DEV Functions·Storage 규칙 배포 |
| P5 | DEV HTTPS 함수·Storage 규칙 배포 |
| P7 | PROD 규칙·인덱스·함수·앱 배포, 버전 올림, Play 업로드 |

규모감(상대): P1 **크다**, P3·P4 **크다**, P5 **중간**, P2·P6 **중간**, P0 **작다**.

---

## 부록. P5 상세 설계 (2026-10-21)

### 흐름
1. 강사 서명으로 `completed`가 되면 완료 화면이 **PDF 만들기 → 업로드 → 서버 등록·링크 발급**을 자동으로 진행(실패 시 `다시 시도`).
2. 앱이 PDF를 만든다(`pdf` 패키지, `NotoSansKR`). **A4 한 장, 종이 계약서 양식**(2026-10-21 개정): 제목·계약번호 → 제1조 계약의 내용(3×4 칸, 계약 당사자 표 없음) → 전체 조항(한 줄 요약형) → 이용분 계산 기준 뒤 환불 예시와 **설명 확인 서명 ①** → 회원 서명(계약 전체 동의)·강사 서명(각 서명 그림·서버 시각) → 맨 아래 **문서 진위 확인 상자**(QR·문서확인번호·완료 시각·계약 내용 해시). 길면 글자 배율을 줄여 한 장에 맞춘다.
3. Storage `personal_contracts/{trainerId}/{contractId}/contract_v{n}.pdf`에 올린다(create-only, `completed` 계약만, `application/pdf`, ≤10MB).
4. `attachPersonalContractPdf`(callable)가 파일을 읽어 `%PDF` 헤더·크기·SHA-256을 확인하고 `delivery`에 기록, **열람 링크 토큰**을 발급한다. 토큰 원문은 응답으로만 주고 **해시만 저장**, 유효 90일. 다시 발급하면 이전 링크는 즉시 무효(재발급 = 회전).
5. 강사가 **공유 시트**(문자·카톡 등 `share_plus`)나 **링크 복사**로 회원에게 보낸다. 보낸 사실은 `managePersonalContract`(`mark_shared`)로 `shared` 이벤트와 `delivery.sharedAt`·`shareCount`에 기록.
6. 회원이 링크를 열면 `viewPersonalContract`(HTTPS)가 토큰 해시·만료·상태(`completed`/`superseded`)를 확인하고 PDF를 내려 주며 `viewed` 이벤트·`firstViewedAt`·`viewCount`를 기록한다.

### 결정과 이유
| 항목 | 결정 | 이유 |
|---|---|---|
| PDF 생성 위치 | **앱**(강사 폰) | 기존 `pdf`·폰트 자산 재사용, 서버에 PDF·폰트 엔진을 추가하지 않음. 증빙은 서버가 파일 해시를 직접 계산해 기록 |
| 링크 보안 | 256비트 랜덤 토큰, 해시만 저장, `timingSafeEqual`, 90일, 회전 | 유출 시 재발급으로 이전 링크 무효 |
| 잘못된 링크 응답 | 존재 여부를 알리지 않는 같은 모양의 404, 만료만 410 안내 | 계약 ID 추측 방지 |
| 미리보기 봇 | 카카오·페이스북 등 링크 미리보기 봇 요청은 PDF를 주되 열람으로 세지 않음 | 회원이 열기 전에 `viewed`가 찍히지 않게 |
| 개인정보 | IP·전체 UA는 저장하지 않음(열람 시각·횟수만) | 증빙에 필요한 최소 |
| 응답 헤더 | `Cache-Control: private, no-store`, `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer` | 중간 저장·유출 최소화 |
| 문자 직접 발송 | 하지 않음(공유 시트만) | 새 의존성·발신 서비스·비용이 없고 강사가 보내는 번호·앱을 직접 고름 |

### 서버 변경(모두 추가, 기존 함수 동작 불변)
- 새 파일 `functions/src/personal_contract_delivery.ts`: 토큰·검증 순수 함수, `attachPersonalContractPdf`(callable), `viewPersonalContract`(HTTPS, `asia-northeast3`).
- `managePersonalContract`에 `mark_shared` 동작 추가.
- `storage.rules`에 `personal_contracts/{uid}/{contractId}/contract_v{n}.pdf` 규칙 추가(읽기: 본인, 생성: 본인+`completed`+PDF+≤10MB+계약 소유자 일치, 수정·삭제 불가).

### 승인이 필요한 것(구현·테스트 후 요청)
DEV Functions 배포(`attachPersonalContractPdf`·`viewPersonalContract`·`managePersonalContract`)와 DEV Storage 규칙 배포. PROD는 P7.


### 부록 보완. 위조 방지와 진위 확인 (2026-10-21)
- **문서확인번호**: 계약 내용 해시(SHA-256) 앞 16자 대문자(4자씩 하이픈). 앱(`contractVerificationCode`)과 서버(`contractVerificationCode`)가 같은 규칙이며 테스트로 고정.
- **QR·확인 주소**: `.../verifyPersonalContract?c=<계약ID>&k=<번호 16자>`. 계약 ID(128비트 랜덤)와 번호(64비트)가 모두 맞아야 하므로 추측 불가.
- **`verifyPersonalContract`(HTTPS, 새 함수·추가만)**: 번호 불일치·없는 문서·취소/미완료는 같은 404. 완료/이전 버전이면 계약번호·완료 시각·상태만 표시(개인정보 없음). 화면에서 PDF를 고르면 브라우저가 SHA-256을 계산해 `delivery.pdfHash`와 비교(JSON 응답은 일치 여부만).
- **한계**: 이 확인은 "서버에 기록된 원본과 같은 파일인가"를 보증한다. 종이로 인쇄해 서명한 사본이나 PDF 편집본은 해시가 달라 일치로 나오지 않는다. 문서확인번호는 서명 자체의 진위(회원 본인 여부)를 증명하지는 않는다.
- **승인이 필요한 것 추가**: DEV Functions 배포 대상에 `verifyPersonalContract` 포함.

### 부록 보완. Storage 교차 서비스 규칙 IAM (2026-10-22)
- PDF 업로드 규칙은 `firestore.get`을 쓰는 교차 서비스 규칙이라 Storage 서비스 에이전트(`service-<프로젝트번호>@gcp-sa-firebasestorage.iam.gserviceaccount.com`)에 `roles/firebaserules.firestoreServiceAgent` 역할이 필요하다. 에뮬레이터는 이를 검사하지 않아 DEV 실기기에서 403으로 드러났다. firebase-tools는 `--non-interactive`에서 이 역할 확인을 건너뛴다.
- **PROD 배포 전 체크리스트에 추가**: 서비스 에이전트 역할 확인.
