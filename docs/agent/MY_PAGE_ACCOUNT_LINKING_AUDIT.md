# 마이페이지 계정 연결 감사

## 2026-07-17 — 출시 전 5단계

### 기존 구조

- legacy `MyPage`와 `SettingsPage`는 `trainer_profile/me`를 중심으로 닉네임·실명·연락처·지역·종목·소속·후원·카카오 상태를 읽는다. legacy 등급 접근 서비스는 저장 등급, 활성 회원 수, 후원 등급, 조직 등급 등을 합산하므로 personal 계정 카드의 source of truth로 사용할 수 없다.
- personal 작업공간은 `PersonalWorkspaceReadyPage`에 회원·일정·레슨일지 진입만 있었고 별도 마이페이지가 없었다. 상단 로그아웃은 anonymous/linked 상태를 구분하지 않았다.
- 이메일 UID 유지 연결은 `AppAccountService.linkAnonymousWithEmail`에 이미 구현되어 있었다. 현재 anonymous user의 `linkWithCredential`, 연결 전후 UID 비교, ID token 강제 갱신, `transitionAnonymousProfileToLinked` 호출 순서이며 충돌 시 sign-out·새 로그인·자동 병합을 하지 않는다.
- 서버 권위 personal 상태는 `trainer_profiles/{uid}`의 `tier`, `lifetimeQualifiedMemberCount`, `profileCompleted`, `accountLinked`이다. 필수 프로필은 `displayName` 또는 legacy-compatible `nickname`, `phone`, `activityRegion`, `primaryActivity`, `affiliationType` 다섯 항목이며 `updatePersonalTrainerProfile` transaction만 완성도와 등급을 다시 계산한다.
- 일반/관리자 비밀번호 변경은 공용 `PasswordChangePage`를 사용한다. `AppAccountGate`가 `mustChangePassword`를 workspace보다 먼저 검사하고, 두 관리자 claim에 따른 personal/legacy 선택을 별도로 유지한다.
- Google은 서비스에서 `googleSetupRequired`만 반환하며 실제 credential 연결이 없다. 카카오 provider도 없다. 성공처럼 보이는 personal 버튼을 만들 수 없는 상태다.

### 구현 결정

- legacy `MyPage`를 수정하거나 복제하지 않고 personal 전용 `PersonalMyPage`를 추가했다. 이 화면은 `ManagedMemberWorkspaceGateway.watchUsage()`가 읽은 canonical profile과 Firebase Auth의 현재 user만 사용한다. 후원·legacy tier·카카오 수치는 읽지 않는다.
- 계정·등급 카드는 서버 tier와 누적 유효 회원 수를 그대로 표시한다. 프로필 완료도는 서버에 저장된 필수 다섯 필드의 채움 수를 안내용으로 계산하지만, 최종 완료 여부와 승급은 서버 `profileCompleted`/`tier`만 권위가 있다.
- 내 정보 저장은 기존 `updatePersonalTrainerProfile` callable만 호출한다. client가 `tier`, count, `profileCompleted`, provider 상태를 쓰지 않는다. 상세 주소는 입력 또는 필수 항목에 포함하지 않았다.
- email 연결 실패·profile 저장 실패 시 route를 닫거나 controller를 지우지 않는다. 기존 이메일 충돌은 안전한 별도 계정 전환이 필요하다고 안내한다. 성공한 email 연결만 비밀번호 입력을 지운다.
- linked 계정만 비밀번호 변경과 로그아웃을 표시한다. 로그아웃 전에 Android widget의 현재 UID 캐시를 지운다. anonymous에는 로그아웃 메뉴가 없다.
- Google·카카오는 `준비 중` 문구만 표시한다.

### 유지·제외 범위

- 시작 로그인 gate, 관리자 `mustChangePassword`, 두 claim legacy workspace, 계약서·전자서명 Semi-Pro gate를 변경하지 않았다.
- Rules, Functions 비즈니스 로직, Firebase 배포, 신규 SDK, 운영 데이터 migration은 변경하거나 실행하지 않았다.
- 시작 gate가 유지되므로 신규 설치 anonymous session을 실제 HomePage/personal MyPage로 보내는 것은 다음 단계다. 이번 단계는 기존 personal workspace 진입과 후속 anonymous 진입에 사용할 UI·서비스 연결을 준비했다.
