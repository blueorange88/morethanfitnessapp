# 회원앱 연동 — 논의 메모 (2026-11-06)

새 채팅에서 이어가기 위한 요약이다. 코드·서버·Rules는 이 메모 작성 중 변경하지 않았다.

## 자료 위치
- 팀원 제안서 원문(사본): `docs/product/member-app-integration-proposal-2026-11-05.md` (원본: 바탕화면 `회원앱_트레이너앱_연동문서.md`)
- 우리가 팀원에게 준 전달물(10/29): `handoff/member-app/INTEGRATION.md`, `handoff/member-app-integration.zip`
- 기존 계획: `docs/agent/REMOTE_SIGNATURE_MIGRATION_PLAN.md`, `docs/agent/BACKLOG.md`의 "회원 앱 연동" 항목(약 338, 2367, 2389줄)

## 팀원 제안서 한 줄 요약
회원앱 쪽에 "사인 출석" 첫 기능(요청 코드 입력 → 레슨 요약 확인 → 손글씨 사인 → `제출됨·강사 확인 대기`)을 구현했다. 동작에 필요한 서버 API는 **미구현 제안**이고, 서버 일은 이 저장소(우리)에 남아 있다. 회원앱은 DEV 프로젝트(`more-than-fitness-dev-mft`)만 허용하며 기본은 미연동 상태다.

## 제안서의 핵심 설계
- 로그인: 이메일 인증 + 강사가 발급한 일회성 초대 + 서버 연결 승인(소셜은 후속, 전화번호는 SMS 운영·동의 때문에 필수로 두지 않음). 이름/이메일/전화 일치로 members 자동 연결 금지.
- 신규 Callable: `issueMemberInviteV1`(강사), `claimMemberInviteV1`(회원), `inspectMemberAttendanceV1`, `submitMemberAttendanceV1`. 서버 전용 `member_links/{linkId}`, 해시 기반 `attendance_requests`. 승인 후 custom claim `memberAppAccess: true` 부여, 호출마다 활성 링크 재확인.
- 서명 제출은 `submitted`만 기록. 출석 확정·차감·취소는 기존 `finalizePersonalTrainingLog` / `cancelPersonalTrainingLog`가 소유(두 함수는 `functions/src/index.ts`에 실제 존재). 회원 submit이 횟수·계약서 상태를 바꾸면 안 됨.
- 멱등 키, 단일 사용, 트랜잭션 재검증, payload 로깅 금지, App Check·호출 빈도 제한.

## 내 평가 (2026-11-06)
- 방향 좋음: 자동 연결 없음, 최소 정보, 서버가 매 호출 권한 재확인, 횟수는 강사 앱만 변경, PROD 미접촉.
- 우리가 만들어야 할 것(큰 작업): 초대 발급·사용, `member_links`, 사인 요청 발급·취소, 조회·제출 API, 강사 앱 UI(회원카드 `회원앱 초대`, `회원 사인 대기` 확인). Functions + Firestore Rules 배포 동반.
- 선행/주의:
  1. 로그인 방식은 **사장님 결정 대기**(제안: 이메일+초대로 시작, 카카오는 후속).
  2. `publicDisplayName`(강사 공개 활동명) 필드가 우리 앱에 아직 없음 — 회원 화면에 실명이 나가지 않으려면 선행 필요(BACKLOG 338줄).
  3. 사인 방식 중복: 기존 공개 웹 링크 서명(`sign_requests`, `member_signature_web_page.dart`)과 새 회원앱 사인 출석 — 장기적으로 하나로 정리.
  4. 서명 원본 보관기간·삭제/철회, 건강정보 동의는 개인정보 정책 결정 필요(AGENTS.md상 정책 변경 전 중단).
  5. SVG 바디맵 참고자료: 부위 ID가 중복·자동 생성이라 `bodyPartId`로 직접 쓰지 말고 매핑표 먼저(아나토미 작업과 연결).

## 합의한 진행 방향 (제안, 사용자 최종 확정 전)
- **1.0.7 릴리스에는 포함하지 않는다.** 서버 배포가 따라붙고 출시 직전이다.
- 릴리스 후 순서: ① 로그인 방식 결정 → ② `member_links`·사인 요청 데이터 구조/규칙 설계 문서 → ③ 에뮬레이터 테스트 → DEV 배포 → ④ 강사 앱 초대·사인 대기 화면 → ⑤ 계약서 원격 서명·채팅은 그 다음.
- 레슨계약서 v2(회원 2 + 강사 1 서명)의 원격 서명은 이 연동 이후의 별도 수직 기능.

## 사용자가 요청한 보조 방식
- 팀원이 만든 회원앱 APK를 PC 폴더에 두면 `adb install`로 폰에 설치해 화면을 캡처하며 같이 볼 수 있다고 안내함(설치는 사용자가 명시적으로 지시할 때만, 강사 앱과 패키지명이 다른지 확인, 강사 앱 화면에는 실제 회원 정보가 있으니 회원앱 화면일 때만 캡처, 로그인은 사용자가 직접). 화면 녹화/스크린샷 전달도 대안.
- 폰: R3CX40M6EEM, adb는 `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`.

## 결정 대기
1. 로그인 방식(이메일+초대로 시작할지)
2. 개인정보: 서명 보관기간·삭제 정책, 건강정보 동의 방식
3. 서버 구현을 어떤 순서·누가 맡을지(팀원과 역할 분담)
