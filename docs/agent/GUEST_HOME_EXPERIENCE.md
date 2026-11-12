# Guest Home 경험과 데이터 경계

기준일: 2026-07-15

## Home UI 재사용

Guest는 소개 카드 목록을 별도로 복제하지 않고 실제 홈의 다음 공통 위젯을 사용한다.

- `HomeHeaderSection`
- `HomeThisWeekScheduleSection` / `HomeWeeklyScheduleTable`
- `HomeBottomNavBar`

`HomeHeaderSection`에는 기존 동작이 기본값인 `loadProfileFromFirestore=true`를 유지하면서 Guest만 false로 전달하는 정적 프로필 모드를 추가했다. 따라서 Linked/legacy 홈은 기존 `trainer_profile/me` stream과 실제 동작을 그대로 사용하고, Guest는 같은 레이아웃을 사용하면서 Firestore stream을 생성하지 않는다.

Guest 전용 화면은 기존 `GuestPreviewPage`를 실메인 동선으로 교체했다. `HomePage` 전체를 복사하지 않았으며, 실제 `HomePage`의 저장·회원 검색·알림·위젯 로직도 호출하지 않는다.

## 데이터와 capability

`HomeGuestCapabilities`가 Guest 권한을 한곳에 정의한다.

- 로컬 일정 생성: 허용, 최대 5개
- 회원 저장·실제 회원 검색: 금지
- cloud sync·Functions: 금지
- 계약 발행·원격 서명: 금지
- 실제 알림 예약·홈 위젯 동기화: 금지

Guest 화면은 Firebase repository를 주입받지 않는다. 서버 초기화 없이 widget test가 렌더링되는 것으로 헤더·홈 진입 시 Firestore 접근이 없음을 확인했다. Guest 관련 파일에는 Cloud Firestore, Firebase Storage, Cloud Functions, 알림/위젯 sync service 호출이 없다. 계정 연결 보조 액션만 명시적으로 Firebase Auth 화면으로 이동한다.

## 로컬 일정

저장 위치는 SharedPreferences의 `guest_home_schedules_v1`이며 서버와 무관한 로컬 JSON 배열이다. 앱 재실행 후 다시 읽지만 계정 연결 시 자동 업로드·자동 귀속·자동 삭제하지 않는다.

저장 필드:

- guestScheduleId
- nameOrAlias
- lessonType
- startAt / endAt
- memo
- colorHex
- createdAtLocal / updatedAtLocal

전화번호, 생년월일, 통증·건강정보, 인바디, 계약·서명 정보, 실제 memberId, trainerId, organizationId는 모델과 직렬화 대상에 없다.

repository 내부 직렬 실행으로 동시 저장을 순서화한다. 신규 문서인 경우 현재 개수를 다시 읽어 5개에서 차단하며 수정·이동은 같은 ID와 createdAtLocal을 유지한다. 삭제 후에만 새 일정을 등록할 수 있다. 삭제한 일정은 로컬 저장값에서도 제거되어 다시 나타나지 않는다.

6번째 일정은 편집 화면까지 열리며 저장 시 입력값을 유지한 채 다음 안내와 `계정 연결` / `조금 더 둘러보기`를 표시한다. 로그인 화면을 취소해도 편집값과 기존 5개는 유지된다. 로그인 성공 후 자동 업로드는 구현하지 않았다.

## 헤더와 체험 표시

Guest 헤더는 실제 높이와 구조를 유지하고 정적 프로필명 `체험`, 제목 `우리, 같이 시작해볼까요`와 다음 동행 문구 풀을 날짜 기준으로 안정적으로 표시한다.

- 함께하길 꿈꿔요.
- 앞으로의 재밌고 즐거운 일을 함께하고 싶어요.
- 우리, 차근차근 같이 성장해나가요.
- 앞으로 펼쳐질 많은 일들을 함께 만들어가요.
- 오늘의 작은 시작도 함께할게요.
- 조금씩, 오래 함께해나가요.

헤더 아래에는 `체험 중 · 일정은 이 기기에만 저장돼요`만 작게 표시한다. 반복 워터마크나 큰 가입 배너는 두지 않았다.

## soft gate

회원, 레슨일지, 레슨 인사이트, MORE 포커스는 로컬 샘플 sheet로 진입한다. 계약서, 서명, 알림, 홈 위젯, 설정, 빠른 회원등록, 빠른 계약등록, 레슨 확정은 모두 탭 가능하며 `AifcToast`로 따뜻한 안내를 표시한다. `AifcToast`는 새 안내 전에 기존 overlay와 timer를 제거하므로 반복 탭에도 누적되지 않고 `Overlay`를 사용해 본문 레이아웃을 움직이지 않는다.

실제 데이터가 필요한 탭은 안내 전에 실제 page/repository를 열지 않는다. 회색 disabled 기능이나 숨긴 기능은 없다.

## 계정 전환 경계

- Guest 일정은 Guest 전용 repository에서만 읽는다.
- Linked/legacy 홈은 Guest repository를 읽지 않는다.
- `AppAccountGate`가 계정 상태에 따라 Guest page를 제거하므로 Linked 화면에 Guest 샘플이 혼입되지 않는다.
- 로그아웃 시 Linked 화면이 제거되고 Guest 시작 화면으로 돌아오며 Linked 데이터 snapshot을 Guest가 받지 않는다.
- Guest→Linked 일정 가져오기는 별도 동의·충돌·소유권 정책이 필요한 후속 작업이다.

## 플랫폼 관리자 후속 정책

이번 작업에서 관리자 화면이나 claim 설정을 구현하지 않았다. 후속 플랫폼 관리자는 Firebase Auth Custom Claims의 `platformAdmin: true`만 권위로 사용하며 이메일 하드코딩, 일반 profile role, organization 관리자 권한으로 대체하지 않는다. 실제 claim 부여는 별도 승인된 Admin SDK 작업이다.

## 검증과 남은 수동 확인

- repository: 생성, 5개, 6번째 차단, 삭제 후 재등록, 수정·이동 ID, 재실행 복원, 금지 필드, 동시 저장, 삭제 재등장 방지를 검증했다.
- UI: 공통 홈 구조, 동행 문구, 좁은 화면 overflow, 샘플 동선, soft gate 비누적·레이아웃 고정, 하단 내비, 6번째 입력/로그인 취소 보존을 검증했다.
- Firebase Emulator는 Functions/Rules를 변경하지 않았으므로 실행하지 않았다.
- 실제 기기에서 스케줄 빈 칸 탭, 날짜·시간 picker, 앱 강제 종료 후 복원, 키보드가 열린 6번째 안내, Guest→Linked→로그아웃 전환은 추가 수동 확인이 필요하다.
