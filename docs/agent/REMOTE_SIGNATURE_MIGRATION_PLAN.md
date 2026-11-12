# Remote Signature Migration Plan

작성일: 2026-07-15  
상태: 계획만 작성, 원격서명 UI·Functions·Rules 변경 없음

## 현재 호출 흐름

1. 트레이너 앱 `home_page.dart`가 계산한 trainingLogId를 조회한다.
2. 앱이 `sign_requests/{token}`을 직접 생성하고 token URL을 만든다.
3. 공개 Web `MemberSignatureWebPage`가 token 문서를 직접 읽는다.
4. 공개 Web이 member 문서와 `training_logs where memberId/memberSigned` 이력을 직접 조회한다.
5. 제출 시 공개 Web transaction이 sign request와 `training_logs/{trainingLogId}`를 직접 merge한다.
6. parent가 없으면 trainerId/lessonLogId 없는 training log가 생성될 수 있다.
7. 공개 Web에서 재등록 요청 등 다른 컬렉션도 직접 쓴다.

이 경로는 비로그인 사용자를 trainer Auth identity repository로 통과시킬 수 없고, fake trainerId를 넣어서도 안 된다. 현재 direct write는 `public_signature_legacy`로 분류하며 신규 canonical trainer write의 예외로 허용하지 않는다.

## 목표 서버 경계

공개 클라이언트는 최소 callable/HTTPS API만 사용한다.

### token 교환/조회

입력:

- opaque token
- 선택적 client nonce/version

서버 검증:

- token hash 일치
- 만료, 사용, 취소 상태
- 요청 유형과 허용 origin/app version
- 대상 trainingLogId/memberId/scheduleDocId의 저장된 결속
- parent가 존재하고 canonical trainerId/memberId/lessonLogId가 유효함

응답:

- 회원에게 필요한 최소 표시명, 레슨 시각·종류, 서명 상태
- 내부 trainer UID, member document ID, 전체 과거 레슨일지, 전화번호 등은 최소화/비공개

### 서명 제출

입력:

- opaque token
- 서명 payload
- request version/idempotency key

서버 transaction:

- request 재검증 및 single use
- 기존 parent identity 보존
- memberSignature/memberSignedAt/waitingTrainerConfirm 등 허용 필드만 변경
- 공개 사용자가 trainerId/memberId/lessonLogId/scheduleDocId/createdAt을 변경하지 못함
- server timestamp와 audit event 기록

## Function에 필요한 저장 데이터

- token hash와 key version
- trainingLogId, memberId, canonical trainerId
- optional scheduleDocId
- expiresAt, status, usedAt, cancelledAt
- request version과 idempotency key
- signature schema/version
- 최소 client metadata와 rate-limit key
- createdAt/updatedAt 서버 시간

PII와 서명 원본의 보존기간, 암호화, 삭제/철회 정책은 별도 승인이 필요하다.

## 이관 단계

1. Auth/tenant identity와 canonical training log parent를 먼저 확정한다.
2. 공개 token 검증 Function/API 및 emulator tests를 추가한다.
3. trainer 앱의 request 생성·취소를 서버 호출로 전환한다.
4. 공개 Web의 request/member/history direct read를 최소 API로 전환한다.
5. 서명 submit을 서버 transaction으로 전환한다.
6. 이중 기록 없이 shadow 검증 후 legacy direct path를 제거한다.
7. Rules에서 공개 사용자의 sign_requests/training_logs/members direct 접근을 전부 거부한다.

## 필수 테스트

- 정상/만료/사용/취소/위조 token
- 동시 제출 하나만 성공
- 다른 trainingLogId/memberId로 바꾼 요청 거부
- parent trainer/member/path identity 불일치 거부
- 공개 사용자의 identity 필드 변경 거부
- response PII 최소화
- rate limit/App Check 적용 정책
- retry idempotency
- trainer 확인 전/후 상태 전이

이번 작업에서는 계약 상태 머신, 원격서명 UI, Functions, Firestore Rules를 수정하지 않았다.
