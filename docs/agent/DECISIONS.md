# DECISIONS

## 2026-07-11
- AI 개발 방식은 완전 무제한 자동화가 아니라 승인형 + 제한 자동 루프로 운영한다.
- 한 번에 큰 리팩터링하지 않고 빌드 가능한 작은 단위로 진행한다.
- 전체 스케줄 위젯 외에 다음 레슨 위젯과 다음 2개 + 오늘 일정 위젯을 개발한다.
- 위젯 색상 테마를 앱 전체 테마로 점진 확장한다.
- 레슨일지 아나토미를 남/여, 앞/뒤, 부위별 기록과 영상 공개 구조로 확장한다.
- `home_page.dart` 분리 파일은 `home_` 접두어를 사용한다.
- 배포, 실제 데이터 변경, Rules, 결제/인증 변경은 사람 승인 전에는 수행하지 않는다.
# 2026-07-18 — 실제 HomePage를 personal canonical Home으로 사용

- 일반 anonymous/linked personal 사용자의 정상 시작 목적지는 `lib/pages/home_page.dart`의 `HomePage`다. `PersonalWorkspaceReadyPage`를 별도 홈 셸이나 첫 주간 탭으로 사용하지 않는다.
- `HomePage(personalOwnerUid: currentUid)`는 회원·일정 조회를 `trainerId == currentUid`, `workspaceType == personal`로 제한하고, 프로필은 `trainer_profiles/{currentUid}`를 사용한다. personal 일정 쓰기에도 동일 owner/workspace를 유지하며 시간 기반 문서 ID는 UID 범위로 분리한다.
- `personalOwnerUid`가 없는 관리자 claim workspace와 Debug legacy 우회는 기존 `trainer_profile/me` 및 legacy 컬렉션 접근을 유지한다. legacy 데이터를 personal UID에 귀속하거나 backfill하지 않는다.
- Beginner, 유효 회원 0명, 누적 회원 0명은 시작 목적지를 바꾸는 조건이 아니다. 준비 화면과 닉네임 온보딩을 마치면 동일한 실제 `HomePage`로 진입한다.
- 홈 햄버거 메뉴는 별도 personal 마이페이지가 아니라 기존 `lib/pages/my_page.dart`의 `MyPage(personalOwnerUid: currentUid)`를 연다. 기존 명함 UI를 유지하면서 personal 프로필 경로만 UID 범위로 연결한다.
# 2026-10-09 — 회원카드 등록 tier gate 제거 (코드와 문서 불일치 정리)

- `prompts/12_linked_beginner_members_limit.md`의 확정 정책은 "Linked Beginner는 관리 중 실제 회원 최대 10명"이었으나, 이후 코드가 `AppTierFeatureKey.customerCardCreate`를 Amateur(레슨 일정 10개 + 선생님 정보 입력)로 막고 서버 `createManagedMember`도 Beginner를 `amateur_required`로 거부하고 있었다. 코드 동작이 문서와 달랐다.
- 사용자 결정으로 문서의 원래 정책에 맞춰 회원카드 등록은 모든 등급에서 허용한다. 클라이언트 `customerCardCreate.requiredRank`를 0으로, 서버 `amateur_required` 검사를 제거했다.
- 유지: 누적 유효 회원 10명 이후에는 계정 연결과 선생님 정보 완료가 필요하다(`enforceBeyondBeginnerThreshold`). 회원 그룹은 Amateur, 태그는 Semi-Pro 제한을 그대로 둔다.
- 남은 불일치: `aifc_tier_guide_chat_sheet.dart`의 "Amateur는 회원카드와 …" 등 등급 소개 문구는 아직 회원카드를 Amateur 기능처럼 설명한다. 등급별 가치 문구는 제품 결정이 필요해 이번에 바꾸지 않았다.
