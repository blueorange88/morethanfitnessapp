# 계정 정책

## 2026-07-16 Anonymous/Linked personal 레슨일지 정책

- personal 레슨일지의 owner는 현재 Firebase Auth UID이며 문자열 `me`나 이메일을 사용하지 않는다. Anonymous와 Linked는 동일한 owner 규칙을 사용한다.
- 레슨일지는 같은 UID의 personal 회원에만 연결된다. 일정 참조는 선택이며, 사용할 경우 같은 UID/personal 및 동일 memberId를 강제한다.
- 초안·자동저장은 허용된 내용 필드만 client가 수정한다. 완료·노쇼 차감·노쇼 미차감·서비스 확정과 확정취소는 Cloud Function transaction만 수행한다.
- 중복 확정과 중복 취소는 같은 log 상태를 확인해 멱등 처리한다. 다른 UID의 Function 호출과 문서 read/write는 거부한다.
- Guest sample, legacy 레슨일지, personal 레슨일지는 혼합하지 않는다. 시작 로그인 gate와 UID 유지 계정 연결 정책은 변경하지 않았다.

## 2026-07-16 Anonymous/Linked personal 일정 정책

- 신규 personal 일정의 canonical owner는 현재 Firebase Auth UID이며 문자열 `me`를 사용하지 않는다. `trainerId`와 `workspaceType=personal`은 생성 이후 변경할 수 없다.
- Anonymous와 Linked 계정은 같은 owner 정책을 사용한다. 현재 anonymous user를 `linkWithCredential`로 연결하므로 UID와 기존 일정 소유권이 유지된다.
- 시간은 identity가 아니다. Firestore random 문서 ID를 사용하고 `dateKey`·`slotKey`는 조회·표시용 필드로만 둔다. 같은 시간의 여러 일정과 서로 다른 trainer 일정이 충돌하지 않는다.
- 확정 증거가 있는 일정은 일반 수정·삭제가 잠긴다. 이동은 문서 ID를 바꾸지 않는 transaction update로 처리하여 실패 시 원본을 유지한다.
- 회원 연결은 현재 UID의 canonical personal 회원만 가능하다. 이름만 입력한 임시 일정은 canonical 회원을 만들지 않는다.
- Guest 체험 일정은 기존 로컬 저장소에만 남고 personal Firestore 일정과 섞지 않는다. legacy 일정은 관리자/Debug 경로에만 유지하며 migration·backfill하지 않는다.

## 2026-07-16 Anonymous Beginner 회원·승급 정책

- anonymous UID의 personal workspace는 Function을 통해 10번째 유효 회원까지 저장할 수 있다.
- 11번째 저장은 같은 UID에 non-anonymous provider가 연결되고 내 정보가 완료된 경우에만 허용한다. 연결은 기존 `linkWithCredential` 정책을 유지한다.
- 계정 연결 또는 내 정보 완료 시 서버 transaction이 누적 유효 회원 수를 다시 평가한다. 10명 이상이면 Amateur, 30명 이상이면 Semi-Pro, 50명 이상이면 Pro가 되며 후원 상태는 사용하지 않는다.
- 회원 휴면·만료·삭제는 관리 중 회원 수에는 반영하지만 누적 유효 회원 수와 달성 등급은 낮추지 않는다.
- 시작 로그인 gate는 이번 작업에서 제거하지 않았다. schedules, training_logs, contracts 권한도 열지 않았다.

## 2026-07-16 Anonymous Beginner identity 기반

- Firebase anonymous Auth UID를 향후 personal workspace의 임시 canonical UID로 사용할 service와 server profile 기반을 마련했다.
- user가 없을 때만 anonymous 계정을 만들며 동시 요청은 한 번으로 합친다. 이번 단계에서는 앱 시작에서 자동 실행하지 않는다.
- anonymous profile은 `accountState=local`, `tier=Beginner`, `workspaceType=personal`, `isAnonymous=true`로 서버가 고정 생성한다.
- 이메일 연결은 현재 user의 `linkWithCredential`만 사용하고 연결 전후 UID 일치를 강제한다. sign-out 후 새 로그인과 자동 데이터 병합은 금지한다.
- 기존 이메일과 충돌하면 현재 익명 UID를 유지한 채 중단한다.
- 연결 profile 전환은 실제 non-anonymous provider token을 확인한 서버 transaction으로만 수행한다.
- anonymous는 자기 profile과 자기 personal 회원을 owner 조건으로 읽을 수 있다. profile/member의 client create/delete 및 member update는 허용하지 않으며, 일정·레슨일지·계약 권한은 열지 않는다.
- 기존 로그인, 관리자 claim, `mustChangePassword`, Debug legacy 정책은 유지한다.

## 2026-07-16 출시 계정 연결 감사

- 목표 흐름은 사용자 부재 시 Firebase anonymous UID를 만들고 같은 UID를 실제 personal workspace의 canonical `trainerId`로 사용하는 것이다.
- 계정 연결은 현재 anonymous user의 `linkWithCredential`만 허용한다. sign-out 후 신규 UID 로그인, 기존 이메일 계정과의 자동 병합, legacy 데이터 자동 귀속은 금지한다.
- 이메일 credential 충돌 시 현재 UID의 데이터 소유권을 보존한 채 중단하고 사용자에게 안내해야 한다. 명시적인 병합 정책과 서버 검증 없이는 다른 UID로 전환하지 않는다.
- Google과 카카오는 실제 provider 설정과 credential link 경로가 준비되기 전까지 성공처럼 표시하지 않는다. 카카오는 이번 출시 범위가 아니다.
- 현재 코드는 anonymous profile·회원 callable·Rules 접근을 거부하고 기존 홈 query/write도 UID owner로 일관되지 않다. 따라서 `AppAccountGate` 제거와 익명 실제 workspace 진입은 안전 조건 충족 전까지 보류한다.
- Debug legacy와 claim 기반 관리자 legacy workspace는 personal anonymous/linked workspace와 계속 분리한다.
- 자세한 중단 근거와 선행 순서는 `RELEASE_ACCOUNT_FLOW.md`를 따른다.

## 2026-07-15 Debug 긴급 legacy 접근 정책

- 미로그인 Guest 시작 화면의 `기존 개발 데이터 열기`는 `kDebugMode`에서만 제공한다.
- Debug legacy 세션은 `legacyDeveloper` workspace mode로 분리하며 로그인, profile bootstrap, `mustChangePassword`, 관리자 claim gate를 거치지 않고 기존 `HomePage`를 직접 연다.
- 선택 상태는 메모리에만 두고 앱 재실행 시 복원하지 않는다. Guest 샘플과 Linked personal 데이터를 legacy 경로로 옮기거나 섞지 않는다.
- Profile/Release에는 버튼 callback과 실행 가능한 우회 분기가 없으며 외부 route·deep link·영구 설정을 제공하지 않는다.
- 이 예외는 client 진입용 개발 편의일 뿐 서버 권한을 승격하지 않는다. 실제 배포 Rules가 비로그인 접근을 거부하면 legacy 읽기·쓰기도 실패하며, 이를 이유로 Rules를 완화하지 않는다.
- 기존 문서의 owner 추정, UID 귀속, `trainerId`/`ownerId` backfill은 금지한다.

## 2026-07-15 플랫폼 관리자와 비밀번호 변경 정책

- 플랫폼 관리자 권한은 Firebase Auth ID token의 `platformAdmin: true` claim만 권위로 사용한다. 관리자 이메일과 profile role은 권한 판정에 사용하지 않는다.
- 기존 개발 데이터 선택은 `platformAdmin`과 `legacyDataAccessApproved` claim이 모두 있을 때만 표시한다.
- 두 claim은 one-time Admin SDK 도구에서만 설정하며 client와 callable Function은 claim을 만들거나 승격하지 않는다.
- 관리자 canonical profile은 personal Beginner 구조를 유지하며 legacy 데이터를 자동 귀속·복사·backfill하지 않는다.
- `mustChangePassword == true`인 이메일 계정은 비밀번호 변경·로그아웃·재설정 메일 외의 workspace 진입을 차단한다.
- 비밀번호 변경은 재인증 → Auth 비밀번호 변경 → token 강제 갱신 → 서버 finalize 순서이며, finalize까지 성공해야 gate를 해제한다.
- `mustChangePassword`, `passwordChangedAt`, `platformAdminProvisionedAt`과 legacy 승인 관련 필드는 client가 직접 변경할 수 없다.
- 마이페이지와 설정에서 일반 비밀번호 변경 진입을 제공하되 모든 민감 입력은 시도 종료 시 지운다.
- 실제 관리자 계정 생성, Firebase 배포, 실제 재설정 메일 검증은 이번 작업에서 수행하지 않는다.

## 2026-07-15 Guest Home parity 정책

- Guest는 실제 홈 공통 헤더·주간 스케줄표·하단 내비를 사용하지만 Firebase 데이터 계층은 사용하지 않는다.
- 체험 일정은 이 기기의 `guest_home_schedules_v1`에 최대 5개만 저장하며 실제 회원·trainer·organization identity를 포함하지 않는다.
- 계정 연결 후 Guest 일정은 자동 업로드·귀속·삭제하지 않는다. 명시적 migration은 후속 정책이다.
- 실제 데이터가 필요한 기능은 숨기거나 disabled 처리하지 않고 탭 가능한 샘플 화면 또는 AI FC 안내로 막는다.
- Guest에서 계약 발행, 원격 서명, 실제 알림 예약, 홈 위젯 동기화, 실제 회원 검색은 실행하지 않는다.

## 2026-07-15 Linked Beginner 회원 정책

- 신규 personal workspace의 관리 중 회원 한도는 10명이다. active와 paused는 포함하고 dormant, expired, deleted는 제외한다.
- `trainer_profiles/{uid}.managedMemberCount`가 서버 권위 값이며 client 목록 개수는 권위 값이 아니다.
- 회원 생성·관리 상태 전환·일반 필드 수정은 owner 검증 Cloud Function을 사용한다. client 직접 create/update/delete는 허용하지 않는다.
- 신규 회원 trainerId는 Function이 현재 non-anonymous Auth UID로 고정한다. legacy 회원 자동 귀속과 migration은 없다.
- 한도 초과 시 기존 기록을 삭제하거나 숨기지 않으며 신규 생성과 false→true 재활성화만 제한한다.
- Guest draft handoff와 Amateur 이상 한도는 후속 정책이다.

## 2026-07-15 Profile bootstrap 정책

- 신규 non-anonymous 연결 계정은 관리자 승인 없이 자기 UID의 빈 personal workspace를 시작한다.
- profile은 client가 만들지 않고 `bootstrapTrainerProfile` Cloud Function이 `Beginner/linked/personal/active`로 고정 생성한다.
- 신규 personal workspace 준비는 legacy 데이터 접근 승인을 요구하지 않는다.
- `trainer_profile/me` 및 기존 회원·일정·레슨일지·계약 데이터 연결만 별도 승인·migration 대상으로 유지한다.
- 익명 Firebase 계정은 Guest이며 profile 생성·읽기·수정이 금지된다.
- server 관리 필드와 client 표시 필드를 분리하며 tier, role, organization, accountState를 client가 승격할 수 없다.


기준일: 2026-07-15

## 계정 상태와 등급

- 계정 상태는 `guest`, `linked`, `verified`, `organizationMember`로 관리한다.
- 앱 등급은 Beginner, Amateur, SemiPro, Pro, Master, Grand Prix로 별도 관리한다.
- 계정 상태와 등급은 서로 대체하거나 한 문자열에 합치지 않는다.

## Guest Beginner

- 로그인 없이 첫 화면과 정적 예시 기능을 이용할 수 있다.
- 실제 회원·일정·레슨일지·계약 데이터에는 접근하지 않는다.
- 개인정보 입력을 서버 또는 로컬 저장소에 저장하지 않는다.
- 계약서 최종 발행과 원격 서명은 사용할 수 없다.

## Linked 계정

- 이메일/비밀번호 Firebase Auth 연결을 1차 방식으로 사용한다.
- Firebase 익명 인증은 최종 계정으로 사용하지 않는다.
- `trainer_profiles/{uid}`의 `trainerId == uid`와 명시적인 기존 데이터 접근 승인이 확인된 경우에만 기존 앱 흐름에 진입한다.
- 신규 계정에 `trainer_profile/me`, 회원, 일정, 레슨일지, 계약 데이터를 자동 귀속하거나 복사하지 않는다.
- 프로필이 없거나 권한이 거부되면 운영 데이터 접근을 차단하고 연결 대기 상태를 표시한다.

## 확인과 계약 정책

- 이메일 미확인 계정은 `linked`, 확인 계정은 `verified` 후보 상태다.
- 계약서 최종 발행은 verified, 계약서 프로필, 등급 조건을 모두 검증하는 후속 gate가 필요하다.
- 원격 서명은 전화 확인과 Cloud Function 서버 검증이 완성되기 전까지 잠금 상태를 유지한다.
- 이번 단계에서는 원격 서명과 계약 상태 머신을 변경하지 않는다.

## 한도와 제공자

- Linked Beginner의 관리 중 회원 한도는 10명이지만 차단 계산과 회원저장 중 로그인 연결은 다음 단계에서 구현한다.
- Google은 1차 후속 제공자이며 Console provider와 Android SHA 설정 확인 후 구현한다.
- 카카오 로그인은 2차 후속 범위다.

## 금지 정책

- 문자열 `me`를 canonical trainerId로 사용하지 않는다.
- 표시 이름이나 이메일 일치만으로 기존 운영 데이터 owner를 추측하지 않는다.
- 기존 데이터 자동 migration 또는 owner 변경을 하지 않는다.
- Rules와 Storage 권한을 인증 사용자 전체 허용으로 임시 완화하지 않는다.
# 2026-07-17 personal 마이페이지 적용

- personal 마이페이지 provider 표시는 Firebase Auth 현재 user와 canonical profile의 `accountLinked`가 함께 확인될 때만 완료로 표시한다.
- anonymous 이메일 연결은 현재 user의 `linkWithCredential`을 사용하고 UID 동일성 확인, token 갱신, server profile 전환 순서를 유지한다. 충돌 시 자동 병합·sign-out·새 UID 로그인을 하지 않으며 입력 화면을 유지한다.
- anonymous에는 로그아웃을 노출하지 않는다. linked personal 로그아웃은 Android widget의 UID별 캐시를 먼저 비우고 Auth 상태 변경으로 personal stream tree를 폐기한다.
- Google·카카오는 실제 credential/config가 준비되지 않아 `준비 중`으로만 표시한다.
# 2026-07-17 시작 로그인 gate 제거

- 모바일 기본 시작은 로그인/가입/Guest sample 화면을 표시하지 않는다. Auth user가 없으면 anonymous session을 만들고 멱등 Beginner profile bootstrap 완료 후 canonical personal 홈으로 진입한다.
- 기존 anonymous session은 같은 UID를 유지하고 매 실행 profile을 멱등 확인한다. linked personal도 로그인 화면 없이 canonical profile gate를 거쳐 같은 홈을 사용한다.
- bootstrap 실패는 sample/가짜 홈으로 fallback하지 않는다. 명시적 재시도만 허용하고 기존 session을 임의 삭제하지 않는다.
- linked 로그아웃은 widget cache를 먼저 지운 뒤 sign-out하고 새 anonymous UID의 빈 personal subtree를 만든다. 기존 linked 데이터는 서버에 보존하며 새 UID로 복사·귀속·병합하지 않는다.
- 관리자 `mustChangePassword`, 두 claim legacy workspace와 Debug legacy 경로는 유지한다. 로그인·가입·재설정 파일도 관리자 로그인과 명시적 계정 전환용으로 보존한다.
