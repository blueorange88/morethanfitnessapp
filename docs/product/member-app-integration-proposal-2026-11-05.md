# 회원앱 DEV 연동 제안 · 사인 출석 v1

2026-11-05. 근거: 전달된 member-app-integration.zip의 INTEGRATION.md §0~9, REMOTE_SIGNATURE_MIGRATION_PLAN.md, personal_training_logs.ts. 이 문서는 서버 담당자가 검토할 **미배포 API 제안**이다. 회원 로그인·회원 연결·원격 서명 서버 구현은 ZIP에 없다. 기존 강사용 함수를 회원용으로 호출하는 구현은 하지 않았다.

## 현재 구현과 선행 조건

회원앱 마이 웰니스 → 사인 출석에서 요청 코드 확인, 최소 레슨 요약, 정규화 손글씨 사인, 내용 확인 체크, 멱등 제출, 상태 재조회를 지원한다. 제출 성공은 `사인 제출됨 · 강사 확인 대기`이며, 서버의 `confirmed` 응답을 받았을 때만 출석 확인 완료로 표시한다. 횟수 차감이나 training_logs 확정은 회원앱이 수행하지 않는다.

기본 상태는 미연동이다. 임시 성공·샘플 실데이터·자동 회원 연결은 없다. 제안한 API 2개가 구현·검증·배포되고 회원 연결이 만들어지기 전까지 실제 통신 성공을 기대하면 안 된다. 채팅·계약 원격 서명·운동영상 전체 공유는 후속 기능이다. 계약서의 disclosure/member/trainer 상태 머신과 레슨 출석 사인은 별개의 기능이다.

## 로그인 의견 — 제품 책임자 확정 전 제안

첫 단계는 **이메일 인증 로그인 + 강사가 발급한 일회성 초대 + 서버 연결 승인**을 권장한다. 현재 회원앱의 이메일 UX를 재사용하기 쉽고 SMS 도입 전 계정 연결 경계를 먼저 검증할 수 있다. 소셜은 같은 Firebase Auth UID에 계정을 연결하는 후속 편의 기능으로 추가한다. 전화번호 인증은 회원 친숙도가 높지만 SMS 운영·할당량과 전화번호 처리 동의가 필요하므로 첫 통합의 필수 조건으로 삼지 않는 편이 낫다. Firebase는 전화번호가 Google로 전송·저장됨과 동의 필요성을 안내한다: https://firebase.google.com/docs/auth/flutter/phone-auth

로그인 성공은 기존 회원 소유권의 증거가 아니다. 이름·이메일·전화번호 일치로 members를 검색·자동 연결하지 않는다. 회원앱 계정 등록은 Firebase Auth 안에서만 하고, 트레이너 DEV에 현재 앱의 profiles·conversations 스키마를 생성하지 않는다.

### 연결 API 제안 (현재 클라이언트 미구현)

- 강사 `issueMemberInviteV1({memberId})`: 인증 강사의 정확한 personal 회원만 대상. 32바이트 이상 난수 토큰을 발급하며 DB에는 해시·만료·대상 결속만 저장한다.
- 회원 `claimMemberInviteV1({token, idempotencyKey})`: 인증된 비익명·이메일 인증 회원과 단일 사용 초대를 트랜잭션으로 결합한다. 재연결·복수 계정 충돌·다른 강사·삭제/정지 회원을 거부한다. 민감정보 동의와 강사 승인 방식을 제품 책임자가 확정한다.
- 서버 전용 `member_links/{linkId}`: memberUid/memberId/trainerId/workspaceType/status/연결 버전. 원래 members 문서는 수정하지 않는다. 링크 취소 즉시 모든 회원 API 권한을 회수한다.
- 초대 연결 승인 뒤 서버가 기존 custom claims를 보존하면서 `memberAppAccess: true`를 부여하고, 연결 해제/정지 시 회수하는 제안을 추가한다. 이 claim은 ZIP에 존재한다고 확인한 것이 아닌 신규 서버 계약이다. 회원앱은 로그인만으로 이 권한을 만들지 않는다. 토큰 갱신 후 UI를 열고, 오래된 토큰이 있어도 서버는 각 호출에서 활성 링크를 다시 확인한다.
- 응답은 회원이 읽을 최소 요약만 제공한다. health/전화/생년/계약 원문/다른 회원·강사 문서를 통째로 반환하지 않는다.

## 구현된 클라이언트가 기대하는 제안 API

서울 asia-northeast3 Firebase Callable. SDK가 DEV ID token과 설정된 App Check 토큰을 전송한다. 다른 프로젝트의 ID token을 넘겨 사용하지 않는다. 클라이언트는 ownerUid를 서버 payload에 넣지 않고 서버가 auth.uid와 member_links로 결정한다. 토큰은 URL 대신 요청 본문에 넣고 저장·로그하지 않는다. 아래 이름과 JSON은 ZIP에 존재하는 함수라고 주장하는 것이 아니다.

### inspectMemberAttendanceV1

입력:

```json
{"schemaVersion":1,"token":"opaque-base64url-32bytes-or-more"}
```

응답:

```json
{
  "schemaVersion":1,
  "requestId":"opaque-request-id",
  "version":1,
  "summaryHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "trainerDisplayName":"공개 코치",
  "lessonTitle":"코어 레슨 50분",
  "startsAt":"2026-11-05T10:00:00Z",
  "expiresAt":"2026-11-05T11:00:00Z",
  "status":"pending"
}
```

status는 pending/submitted/confirmed/cancelled/expired만 허용한다. version은 양의 정수, summaryHash는 canonical 표시 레슨 스냅샷 SHA-256이다. requestId는 내부 memberId나 trainer UID를 담지 않는 opaque 값이다. trainerDisplayName은 승인된 공개 활동명이며 원본 실명으로 대체하지 않는다. 클라이언트는 제출 응답과 표시했던 요청 ID·버전·해시가 정확히 같은지 검사한다.

서버 검증: non-anonymous verified Auth, 회원 자격·정지/삭제 여부, 활성 member_link, 요청 토큰 해시·버전·만료·취소·사용 상태, request/member/trainer/lessonLogId/optional scheduleDocId 결속, canonical parent 존재/정체성. 검증 실패 시 동일한 일반 오류를 반환한다. 요청 ID를 바꿔 임의 조회하는 API는 제공하지 않는다.

### submitMemberAttendanceV1

입력:

```json
{
  "schemaVersion":1,
  "token":"opaque-base64url-32bytes-or-more",
  "requestVersion":1,
  "summaryHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "idempotencyKey":"000000000000000000000000000000000000000000000001",
  "signature":{"schemaVersion":1,"strokes":[[{"x":0.1,"y":0.2},{"x":0.3,"y":0.4}]]}
}
```

좌표 예시는 형태 설명용이다. 실제 서명은 총 8~4096점, 1~64획, 획당 2점 이상, 유한한 0~1 좌표와 최소 변화 폭을 요구한다. 클라이언트·서버가 같은 제한을 검사한다. 서명은 기기 메모리에서만 유지하고 성공/화면 폐기 시 제거한다. 서버 보존기간·암호화·삭제/철회 정책은 담당자 확정 후 활성화한다.

응답:

```json
{"schemaVersion":1,"requestId":"opaque-request-id","requestVersion":1,"summaryHash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","status":"submitted"}
```

서버는 읽기 검증을 **트랜잭션 안에서 다시** 수행한다. (회원 UID, 요청, 멱등 키)에 결합한 결과를 저장해 응답 유실 재시도에 같은 결과를 준다. 같은 키의 다른 서명/해시는 거부한다. 다른 키의 동시 제출·다른 계정·취소/만료·연결 회수·부모 교체는 거부하고 single use를 보장한다. 이미 성공한 동일 재시도는 만료 후에도 저장된 결과를 돌려주는 정책을 권장한다. 클라이언트는 로컬 만료 뒤 제출 대신 상태 재조회로 복구한다.

서명 제출은 `submitted`를 기록하고 기존 parent identity/createdAt을 보존한다. `waitingTrainerConfirm` 같은 허용된 상태와 서버 timestamp/audit event만 변경한다. 실제 출석 확정·차감·취소는 기존 강사 finalizePersonalTrainingLog/cancelPersonalTrainingLog가 소유하고, member confirmed 상태는 그 결과에서만 파생한다. 회원 submit이 레슨 횟수나 계약서 상태를 바꾸면 안 된다.

## 통신과 환경

- 실통신 허용 프로젝트는 more-than-fitness-dev-mft 하나이며 `APP_ENV=dev`를 강제한다. Firebase 초기화 전에 잘못된 환경을 거부하고 실제 FirebaseApp의 projectId도 검사한다.
- 기본 회원앱은 기존 환경을 바꾸지 않는다. API 플래그가 켜지면 별도 DEV 연동 프리뷰로 진입해 기존 FirebaseSessionRepository의 profiles 보정, Firestore repository 생성, 푸시 초기화를 실행하지 않는다.
- 프리뷰 로그인은 이미 발급된 이메일 인증 DEV 합성 계정의 Auth 로그인만 지원한다. 프리뷰는 서버가 부여한 정확한 `memberAppAccess: true` ID-token claim을 확인한 뒤 출석 UI·저장소를 생성한다. claim 없음·문자열 true·관리자·검증 실패에는 권한 안내와 로그아웃만 제공한다. 각 API 호출도 claim을 다시 확인하며, 회원 자격·활성 연결은 서버가 최종 검증한다. 회원 연결 생성·가입·비밀번호 재설정·소셜/전화번호 UX는 이 프리뷰의 구현 범위에 포함되지 않는다.
- DEV 전용 Firebase Web/Android 앱 등록과 클라이언트 설정은 담당자에게 받아 별도 ignored JSON에 둔다. 트레이너 앱 Android 패키지 설정을 회원앱에 복사하지 않는다. 서비스 계정 키는 사용하지 않는다.
- PROD 리소스·설정·콘솔을 조회하거나 배포하지 않았다. 원격 DEV에도 이번 작업으로 쓰기/함수 호출을 하지 않았다.

로컬 체험:

```sh
flutter run -d chrome --dart-define=MEMBER_ATTENDANCE_DEMO=true
```

로컬 회원 로그인 → 마이 웰니스 → 사인 출석 → 체험 요청 코드 넣기. 이 경로는 Firebase 비활성일 때만 허용한다.

서버 담당자 배포 이후 `config/member-integration.dev.example.json`을 `config/member-integration.dev.local.json`으로 복사하고 실제 DEV 회원앱 설정으로 교체한 뒤 합성 계정으로 확인:

```sh
flutter run -d chrome --dart-define-from-file=config/member-integration.dev.local.json --dart-define=MEMBER_ATTENDANCE_API_ENABLED=true
```

JSON에는 기존 AppConfig가 요구하는 APP_ENV=dev, FIREBASE_ENABLED=true, FIREBASE_PROJECT_ID=more-than-fitness-dev-mft, FIREBASE_DEPLOYMENT_PROFILE=full, FIREBASE_FUNCTIONS_ENABLED=true, FIREBASE_STORAGE_ENABLED=true 및 DEV 앱용 Firebase 설정/App Check 설정을 넣는다. 실제 설정 파일은 제공되지 않아 live run은 실행하지 않았다. emulator 사용 시 FIREBASE_USE_EMULATORS=true와 호스트를 설정한다. 클라이언트 에뮬레이터 연결은 제공하지만 제안 서버 API가 없으므로 end-to-end Emulator 테스트는 아직 불가하다.

## 담당자 변경 제안 — 배포 실행 없음

1. member_links, 해시 기반 attendance_requests, 최소 회원 요약 및 서버 전용 영수증 스키마를 확정한다. member raw 문서 read 권한은 열지 않는다.
2. 위 2개 Callable, 강사 요청 발급·취소와 회원 초대·승인 API를 구현한다. admin SDK의 Rules 우회를 고려해 모든 소유·역할·링크·만료 검증을 함수 자체에 둔다. App Check 강제·호출 빈도 제한·일반화 오류·payload 원문 로깅 금지도 적용한다.
3. 기존 members/training_logs/personal_contracts 및 legacy sign_requests/contracts에 대한 회원 직접 read/write deny를 유지한다. 새 연결·요청·서명 원본·영수증도 클라이언트 직접 쓰기는 deny다. 원격 회원 기능 때문에 인증 사용자 전체 허용을 넣지 않는다.
4. 현재 v1은 Callable 단건 요청이므로 회원앱을 위한 새 Firestore 인덱스는 필요 없다. 후속 목록 API 쿼리가 확정되면 링크 상태+회원 UID+정렬 등의 서버 쿼리 인덱스를 별도 제안한다. ZIP의 Rules/Functions/인덱스 파일은 이 저장소에 덮어쓰지 않았다.
5. 서버 Emulator에서 정상/위조/만료/취소/이미 사용된 토큰, 다른 회원·강사·센터·정지 계정, 연결 회수, 부모 미존재/정체성 불일치, 버전/해시 변경, 초과 payload, App Check/rate limit, 동시 제출 하나만 성공, 응답 유실 재시도, 다른 키 재사용 거부, 강사 확정·횟수 중복 차감 방지, PII 비노출을 검증한다.
6. 담당자가 DEV 배포 후 두 앱의 합성 회원으로 요청 발급→회원 사인→강사 확인→양쪽 상태 일치→재로그인 복원을 검증한다. 계약 원격서명과 채팅 요청 카드 연동은 다음 작은 수직 기능으로 진행한다.

## SVG 참고 자료

원본 4개는 assets/integration-reference/{female,male}-{front,back}.svg에 바이트 그대로 보존했다. 부위 ID에는 shoulder_R_*, chest 등 자동 생성/중복·면 간 재사용 값이 있다. 이를 bodyPartId로 직접 쓰지 말고 명시적인 bodyGender/bodyView/bodySide + 안정 bodyPartId 매핑표를 먼저 검토해야 한다. 이번 기능은 출석 요청 확인·사인에 한정하므로 기존 3D 근육맵과 터치존을 변경하지 않았다. SVG 렌더링 의존성도 추가하지 않았다.
