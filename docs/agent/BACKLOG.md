# BACKLOG

## 2026-07-27 PROD 1.0.4 코드·저장소 release blocker
- [x] 1.0.3 실제 `createManagedMember` no-birth payload와 1.0.4 `birthDate` payload 확인
- [x] 생년월일 미제공 legacy만 허용하고 supplied invalid는 거부하는 compatibility layer 적용
- [x] 신규 요청의 canonical `birth`·`birthDisplay`·`birthAt` 저장과 legacy 재요청 비rewrite 확인
- [x] auth UID·owner/workspace·전화번호 중복·identity 주입·legacy group 미생성·PII 미로그 방어 유지
- [x] 위젯 exact 호출 경로 확인 후 inexact 단일 경로 전환과 `SCHEDULE_EXACT_ALARM` 제거
- [x] POST/BOOT·일반 inexact 알림·3개 widget provider·rollover receiver 유지
- [x] 관련 Flutter 115개, 전체 Flutter 474개 통과
- [x] managed member Emulator 52개와 전체 Emulator suite 통과
- [x] Functions build, analyze error 0(기존 warning 246/info 955), diff check 통과
- [x] DEV Kotlin·merged Manifest·DEV Debug APK 통과
- [x] 미추적 제품 7개와 테스트 8개를 release 필수로 분류
- [x] 문서 12·prompts 25·임시 4·ignore artifacts를 release commit 제외로 분류
- [x] DEV fixture·viewport의 Debug+DEV 차단과 PROD 무시 테스트 확인
- [ ] 총 58개 release allowlist를 재감사한 뒤 선별 stage·commit — 별도 승인 필요
- [ ] Android release signing을 debug key에서 배포 key로 전환 — 별도 승인과 보안 입력 필요
- [ ] `1.0.4` versionName 및 Play에서 미사용인 versionCode 확정·변경 — 별도 승인 필요
- [ ] 승인된 정확한 PROD Functions만 선택 배포하고 하위 호환 smoke 확인 — 별도 승인 필요
- [ ] PROD release AAB 빌드·문자열/Manifest/서명 감사와 1.0.3 위 업데이트 canary — 별도 승인 필요
- PROD Firebase·배포·PROD build·Galaxy·version/signing/keystore·Play Console·git stage/commit/push는 이번 작업에서 수행하지 않았다.

## 2026-07-26 고객카드 stale 최근 회원 캐시 최종 완료
- [x] Firestore 로컬 schedule snapshot의 stale member ID 출처와 Home 조회 시점을 확정
- [x] Personal members 조회를 `trainerId=current UID` + `workspaceType=personal`로 제한하고 owner 없는 document-ID query 제거
- [x] missing·deleted ID 일부/전체 제외, 빈 ID query 0, cache/pending cleanup write 차단, authoritative cleanup 허용
- [x] member resolution 오류의 unhandled 전파 차단과 식별자 없는 안전 로그
- [x] Personal 일정 저장 후 legacy `members.nextLessonAt` 직접 write 생략, canonical schedules 기준 유지
- [x] 관련 Flutter 86개, 전체 Flutter 459개 통과
- [x] Personal schedules Emulator 27개와 전체 Emulator 묶음 통과
- [x] analyze 신규 error 0·기존 62개 유지, diff check 오류 0, DEV Debug APK·데이터 보존 설치 통과
- [x] 삭제 전 최근 회원 표시와 authoritative schedule 1건 확인
- [x] 서버 회원·일정만 precondition 삭제 후 첫 재실행 cache 1→server 0 self-heal
- [x] 삭제 회원 최근 목록 제거와 고객리스트 0명 확인
- [x] 두 번째 재실행 cache 0건으로 동일 삭제 ID 재조회 입력 제거 확인
- [x] permission-denied·unhandled exception·fatal crash·ANR·PROD marker 0
- [x] 서버 tier Beginner·회원 0·일정 0·custom type 0·managed count 0·기본 그룹명 복원
- [x] 고객카드 잔여 묶음 완료; 다음 Semi-Pro·동의·위젯 묶음 미진행
- [x] Galaxy·PROD·Firebase 추가 배포·`pm clear` 미작업

## 2026-07-26 고객카드 stale 최근 회원 캐시 blocker
- [x] stale ID 출처를 Firestore 로컬 `schedules` snapshot과 `HomeDeletedMemberScheduleService.deletedMemberIdsFromScheduleDocs()`의 owner 없는 document-ID query로 확정
- [x] Personal `members` 조회를 현재 Auth UID의 `trainerId` + `workspaceType=personal` 조건으로 제한하고 owner 없는 fallback 제거
- [x] missing·deleted·pending-delete ID만 제외하며 다른 로컬 설정·익명 UID·DEV fixture를 변경하지 않는 순수 self-heal 판정 추가
- [x] cache/pending snapshot에서 cleanup write 금지, authoritative server snapshot에서만 unlink cleanup 허용
- [x] member resolution 예외를 Home에서 처리하고 식별자 없는 error code·안전한 빈 schedule UI로 unhandled exception 차단
- [x] 신규 7개, 관련 Flutter 80개, 전체 Flutter 458개, Personal schedules Emulator 27개, 전체 Emulator 묶음 통과
- [x] 변경 범위 analyze 신규 error 0, `git diff --check` 오류 0, DEV Debug APK와 데이터 보존 업데이트 설치 통과
- [x] 실기기 DEV 합성 회원 1건과 연결 일정 1건 생성, authoritative schedule snapshot 1건 확인
- [x] 삭제 후 force-stop/restart stale cache self-heal·동일 ID 재조회 입력 제거·고객리스트 0명 실증 완료
- [x] `HomeScheduleFirestoreService.refreshMemberNextLesson()`의 Personal `members.nextLessonAt` 직접 write를 차단하고 legacy 동작 유지
- [x] 중단 후 이번 테스트 회원·일정만 precondition 삭제, 서버 tier Beginner·회원 0·일정 0·custom type 0·managed count 0 복원
- [x] 고객카드 잔여 묶음 완료; Semi-Pro·개인정보 동의·위젯 회귀로 이동하지 않음
- [x] Galaxy·PROD·Firebase 추가 배포·`pm clear` 미작업

## 2026-07-26 고객카드 저장 무결성·DEV 선택 배포
- [x] 남성 선택이 `female`로 저장되던 UI 문자열 비교 원인 수정
- [x] 생년월일 create/update callable payload·allowlist·canonical write·readback 계약 복구
- [x] Personal 기존 회원 수정을 `updateManagedMember` callable 경로로 통일
- [x] auth 필수, owner/workspace 검증, identity 강제, 변경 필드 allowlist 감사
- [x] 자기 전화번호 제외 owner 범위 중복 검사와 다른 trainer 수정 차단 검증
- [x] legacy `groupId/groupName` 신규 저장 0, `member_groups` 접근 0 확인
- [x] Functions build, managed member 48개와 전체 Emulator 묶음 통과
- [x] 관련 Flutter 29개, 전체 Flutter 443개, 신규 analyze error 0, diff check 통과
- [x] DEV `more-than-fitness-dev-mft`의 `createManagedMember`, `updateManagedMember`만 `asia-northeast3`에 선택 배포
- [x] 배포 전후 함수 목록 비교로 다른 함수·Rules·indexes·Storage 미배포 확인
- [x] `TO2408FB00746` 데이터 보존 DEV 설치와 validation 실패 callable 0 확인
- [x] 주소 포함·미포함 생성, canonical identity·성별·생년월일 서버 readback 확인
- [x] 동일 전화번호 기존 회원 수정 성공과 다른 회원 전화번호 중복 차단 확인
- [x] permission-denied·fatal crash·ANR·PROD marker 0 확인
- [x] 테스트 회원 2건 삭제, DEV UID Beginner·카운터·회원 집합 원복
- [x] PROD·Galaxy·`pm clear`·PROD APK·기타 Firebase 배포 미작업
- [x] 다음 백로그 미진행

현재 고객카드 성별·생년월일 저장 무결성 수정과 승인된 DEV 두 함수 선택 배포, 실기기 생성·수정·중복 차단·서버 readback·원복까지 완료됐다. Artifact Registry cleanup policy 경고는 요청대로 설정을 변경하지 않았으며 배포된 두 함수의 ACTIVE 상태는 별도 확인했다.

## 2026-07-26 DEV 서버 저장 재검증 후 신규 결함
- [x] 현재 DEV UID canonical profile 원본 Beginner·count 0·사용자 종류 0 확인
- [x] DEV project 고정·precondition guard로 tier만 Amateur 임시 변경
- [x] 주소 포함 회원 저장·function readback·목록 표시·재진입 주소 유지
- [x] 주소 없는 회원 저장·레슨 OFF·미등록·0/0·기간 미등록 서버 경로
- [x] 사용자 레슨 종류 추가·readback·재표시·중복 1개 유지·삭제
- [x] 삭제된 종류를 사용하는 기존 DEVTYPE 값 유지
- [x] 신규 문서 legacy `groupId/groupName` 0 확인
- [ ] 신규 personal 회원 생년월일 저장 계약 추가: client service payload, Function allowlist·transaction, readback 테스트 필요
- [ ] 남/여 → male/female 매핑 수정: 현재 `남성` 비교로 남성이 female로 저장됨
- [ ] 위 두 결함 관련 Flutter·Functions Emulator 회귀 테스트 추가
- [ ] Functions 변경이 필요하면 DEV 선택 배포를 별도 승인받은 뒤 서버 재검증
- [x] 테스트 회원 3개 삭제와 profile count·customLessonTypes 원복
- [x] 현재 UID Beginner, 회원 0, 사용자 종류 0 최종 readback
- [x] 앱 재시작 후 Home Beginner·고객리스트 0명·새 세션 오류 로그 0
- [x] PROD·Galaxy·Firebase 배포·`pm clear` 미작업
- [x] 다음 백로그 미진행

현재 고객카드 서버 저장 검증 판정은 **실패**다. 주소·그룹·사용자 레슨 종류 경로는 통과했지만 생년월일 누락과 성별 오저장 두 결함을 수정하기 전에는 완료 처리하지 않는다.

## 2026-07-26 고객카드 반복 validation focus 수정 및 후속 검증
- [x] 기본정보 2/2에서 offscreen 이름 validator가 `FormState`에서 빠지는 정확한 원인 확인
- [x] 매 저장마다 controller 기반 필수 오류 목록과 첫 오류를 새로 계산
- [x] 이전 focus 요청 취소와 stale callback 차단을 공통 coordinator에 구현
- [x] 이름+전화 오류 저장 1·2·3회 이름 focus 회귀 테스트
- [x] 이름 정상화 후 전화 오류 저장 1·2회 전화번호 focus 회귀 테스트
- [x] 관련 Flutter 테스트 41개, 전체 Flutter 테스트 439개 통과
- [x] 회원/tier Emulator 41개, owner-scoped 일정 Emulator 27개 통과
- [x] 변경 범위 analyze 신규 error 0, `git diff --check` 오류 0
- [x] `TO2408FB00746` DEV 데이터 보존 업데이트 설치
- [x] 실기기 이름 저장 1·2·3회 이름 focused·일반 키보드·전화 unfocused 확인
- [x] 실기기 이름 정상 후 전화 저장 1·2회 전화 focused·숫자 키보드 확인
- [x] 생년월일 오류, 직접입력 레슨 종류 빈 값, 여러 오류 첫 항목 이동 확인
- [x] Daum 주소 검색 `about://` callback 결함 수정 및 공개 예시 주소 callback 확인
- [x] 레슨 등록 OFF, 레슨 미등록, 총 0/잔여 0, 기간 미등록 표시 확인
- [x] legacy `member_groups` 요청 0 및 owner-scoped schedules Emulator 검증
- [ ] 주소 포함·미포함 회원 저장 후 재진입: 실제 DEV server tier `Beginner`의 `failed-precondition`으로 차단
- [ ] 사용자 레슨 종류 추가·실기기 readback·재표시·삭제·기존 회원 값 유지: 신규 회원 저장 차단으로 물리 검증 불가
- [ ] 기본 그룹 표시명 네 화면 실기기 교차 확인: 자동 테스트 통과, 실기기 3지점 확인
- [ ] 고객카드 5개 진입 경로 실기기 교차 확인: 정적·자동 검증 통과, 실기기 목록 신규 1경로 확인
- [x] permission-denied·회원 저장 성공·회원 문서 생성·crash·ANR·PROD project 징후 0
- [x] Galaxy·PROD·Firebase 배포·`pm clear` 미작업
- [x] 다음 백로그 미진행

남은 실기기 항목은 서버 tier를 변경하지 않는 현재 안전 조건에서는 완료할 수 없다. Firestore tier 변경 승인을 받기 전에는 재시도하지 않는다.

## 2026-07-25 P10HD Lite DEV 고객카드 통합 실기기 검증

- [x] 지정 기기 `TO2408FB00746`과 DEV package/foreground 확인
- [x] DEV 로컬 Amateur fixture 적용 및 Firestore/Functions 변경 없음 확인
- [x] 고객리스트에서 신규 고객카드 진입
- [x] 360dp 기본정보 2/2 키보드 닫힘/열림 overflow·주소 요소·터치 확인
- [x] 이름 오류 1회차 이동·포커스·키보드·호출 부재 확인
- [ ] 이름 오류 2회차 이름 재포커스: 전화번호 필드와 숫자 키보드로 잘못 이동
- [x] 전화번호 오류 1회차 이동·포커스·숫자 키보드·호출 부재 확인
- [x] 전화번호 오류 2회차 초기화 후 반복 이동·포커스·숫자 키보드 확인
- [x] 320/390/411dp 키보드 닫힘/열림 주소 요소·겹침·터치 확인
- [x] permission-denied/createManagedMember/저장 완료/overflow/crash/ANR/PROD project marker 0건
- [x] DEV 고객리스트 `DEVTEST` 미표시로 회원 미생성 교차 확인
- [ ] 전체 통합 판정: 이름 오류 2회차 실패로 미완료
- Galaxy·PROD·Firebase 배포·`pm clear`·실제 회원 저장은 미작업. 다음 백로그로 이동하지 않는다.

## 2026-07-23 PROD 오늘 레슨 위젯 날짜 변경 후 재검증 중단

- [x] 기존 설치 PROD `1.0.2 (3)`와 unlocked `R3CX40M6EEM` 확인
- [x] 7월 23일 owner metadata와 payload 179건 write/readback/update 성공
- [x] native 계산에서 owner/payload 유효 및 `upcomingCount=10`, `hiddenCount=4`, `result=ready` 확인
- [ ] 런처 RemoteViews 반영: 실제 화면은 계속 `남은 레슨 0개` 빈 상태
- [ ] 요청한 6건/`외 1개` 실제 렌더
- [ ] PROD warm/cold 위젯 탭: 렌더 중단 조건에 따라 실행하지 않음

7월 23일에는 native Glance 계산 자체는 빈 상태에서 ready 상태로 바뀌었지만 launcher에 표시된 오늘 위젯은 갱신되지 않았다. 요청서의 `외 1개` 미표시 즉시 중단 조건에 따라 추가 코드 수정, APK 재설치, Firebase/운영 데이터 작업과 탭 검증을 진행하지 않는다.

## 2026-07-22 PROD 1.0.2 오늘 레슨 위젯 카나리 중단

- [x] PROD `1.0.2+3` APK 빌드, package/project/version/provider 확인
- [x] 기존 설치 APK와 신규 APK signer SHA-256 일치 확인
- [x] `adb install -r` 데이터 보존 업데이트 성공
- [x] 설치 전후 UID·nickname fingerprint, profile, schedule stream 180건 유지
- [x] PROD owner metadata와 payload 180건 write/readback/update 성공
- [x] 기존 주간 위젯 인스턴스와 세 provider 유지
- [ ] PROD 오늘 위젯 `외 1개` 렌더: 실제 native 결과가 `upcomingCount=0`, 빈 상태로 표시됨
- [ ] PROD warm/cold 위젯 탭: 렌더 중단 조건에 따라 실행하지 않음

현재 PROD 주간 위젯에는 7월 22일 일정이 표시되고 personal schedule stream도 180건이지만, 오늘 위젯 native parser는 같은 시점에 `payloadCount=180`, `ownerMatched=true`, `result=empty`를 반환했다. 요청서의 `외 1개` 미표시 즉시 중단 조건에 따라 Firebase·운영 데이터 추가 작업과 warm/cold 탭을 진행하지 않았다. 동일한 두 번째 작업문은 중복 설치·검증하지 않는다.

## 2026-07-22 Android 오늘 레슨 위젯 overflow·cold tap 보완

- [x] 실제 표시 행 기준 `topCardCount`·`visibleRemainingCount`·`hiddenCount` 계산
- [x] `외 N개`를 잘리지 않는 `오늘 남은 일정` 제목 행에 배치
- [x] 오늘 위젯 MainActivity Intent에 고유 action/data와 Activity launch flags 적용
- [x] cold/warm action을 Home 준비 뒤 한 번만 consume하도록 pending 유지
- [x] 개인정보 없는 render·tap·deep-link Debug 로그 추가
- [x] 0~8개 overflow, 6개/하단 3행 `외 1개`, 중복 없음, cold/warm 단일 consume 테스트
- [x] 관련 14개·전체 377개 Flutter 테스트, 변경 범위 analyze, DEV/PROD Kotlin·Manifest·Debug APK, diff 검사
- [x] DEV warm tap: MainActivity foreground와 action 1회 consume 확인
- [x] DEV 정상 cold tap: DEV recent task 제거·process 없음 뒤 MainActivity foreground와 initial intent 1회 consume 확인
- [x] DEV owner self-heal: schedule source/payload 6건, owner/environment/project/workspace/date 재읽기 검증과 widget update 확인
- [ ] DEV 6개/`외 1개` 육안 렌더: 현재 6개 source가 7/20~7/23에 분산되고 오늘 7/22는 1건이라 실제 화면 조건 미충족
- [ ] DEV 주간 위젯 실제 배치 회귀: provider는 있으나 launcher instance 없음
- [x] `1.0.2+3` PROD 패치 빌드·서명/identity 비교·`adb install -r` 데이터 보존 검증
- [ ] PROD 오늘 위젯 실제 일정 렌더와 warm/cold 탭 검증

기기 `R3CX40M6EEM`은 연결됐지만 세 차례 모두 Keyguard `showing=true`여서 DEV 앱 설치와 홈 위젯 조작을 시작하지 않았다. 실기기 성공을 추측하지 않았고 PROD 버전 변경·APK 설치·Firebase 작업도 하지 않았다. 다음 백로그로 이동하지 않는다.

후속 재검증에서는 Keyguard 해제와 정확한 `main_dev.dart` DEV APK의 데이터 보존 설치를 확인했다. warm tap은 통과했지만 force-stop 뒤 cold tap은 process만 생성되고 launcher가 top에 남아 실패했다. canonical Home schedule cache는 6건인데 widget owner cache가 비어 오늘 위젯은 0건으로 렌더됐다. 따라서 `1.0.2+3` PROD 단계는 계속 보류한다.

최종 보완에서 canonical `HomePage`의 snapshot/resume 동기화가 owner metadata를 같은 `HomeWidgetPreferences`에 쓰고 재읽기한 뒤 payload와 update를 수행하도록 수정했다. DEV 실기기에서 owner와 payload 6건은 정상 복구됐고, 정상 cold는 `force-stop`이 아닌 DEV recent task 제거 후 process 없음 상태에서 통과했다. 현재 DEV 6건 중 오늘 일정은 1건뿐이므로 `외 1개` 실화면은 추측하지 않고 자동 6건 layout 테스트 통과와 별개로 미검증 유지한다. PROD 단계로 이동하지 않는다.

## Android Debug Emulator host 127.0.0.1 통일 (2026-07-17)

- [x] Auth·Firestore·Functions 공통 host `127.0.0.1`
- [x] 9099·8080·5001 및 Functions `asia-northeast3` 유지
- [x] `lib` Emulator 연결용 `localhost` 0개 확인
- [x] Firebase 초기화 직후 세 Emulator 연결 및 production fallback 없음 확인
- [x] Debug 전용 127.0.0.1 cleartext 설정, Profile/Release manifest 미변경
- [x] 안전한 host·port·region 연결 로그
- [x] 관련 28개·전체 197개 테스트, analyze, 최종 Debug APK, diff 검사
- [ ] 실기기 `bootstrapAnonymousBeginnerProfile success`
- [ ] 실기기 `personalProfileRead success`
- [ ] 실기기 `personalWorkspace success` 및 personal Home 진입

실기기에서 익명 세션은 성공했지만 FlutterFire Functions 요청은 Emulator 실행 로그에 도달하지 않고 code=unknown으로 실패했다. 성공 처리하지 않았으며 다음 백로그로 이동하지 않는다.

## Flutter callable regional 단일 인스턴스 연결 복구 (2026-07-17)

- [x] `lib` 전체 Functions 생성·Emulator·callable 사용처 전수 검색
- [x] `asia-northeast3` `mtfFirebaseFunctions` 단일 lazy 인스턴스
- [x] 동일 객체에 Debug localhost:5001 Emulator 연결
- [x] 모든 personal callable과 비밀번호 callable의 공통 호출기 사용
- [x] 성공 응답은 FlutterFire `HttpsCallableResult.data`만 사용
- [x] Debug projectId·region·emulator·callable 안전 로그
- [x] 공통 파일 밖 direct Functions API 사용 차단 테스트
- [x] 관련 60개·전체 197개 테스트, 변경 범위 analyze, Debug/Profile/Release APK, AOT marker, diff 검사
- [ ] Android 실기기 연결 후 네 단계 success 로그와 로그인 없는 personal Home 진입 확인

현재 `adb devices`에 연결된 기기가 없어 실기기 항목은 미검증이다. Firebase deploy와 운영 데이터 변경은 수행하지 않았고 다음 백로그로 이동하지 않는다.

## Android 실기기 LOCAL EMULATOR 시작 실패 진단·복구 (2026-07-17)

- [x] Anonymous session, profile bootstrap, profile server read, personal workspace 단계별 안전 로그
- [x] Firebase/Functions code와 runtime type 보존, UID·token·이메일·회원정보 및 원문 message 비기록
- [x] 첫 배포 필수 9개 callable의 `enforceAppCheck` 미설정 확인 및 App Check 경고 원인 배제
- [x] Debug 전용 network security config에서 localhost cleartext만 허용
- [x] Auth/Firestore/Functions 초기 연결 순서, 서울 region, production fallback 없음 재확인
- [x] 단계별 사용자 오류 안내와 Firestore 서버 프로필 확인
- [x] 관련 테스트, 전체 196개 테스트, 변경 범위 analyze, Debug/Profile/Release APK, variant 격리, diff 검사
- [ ] 최신 Debug APK로 Android 실기기 Anonymous 시작과 네 단계 로그 재확인

실제 Firebase deploy와 Rules/Functions/Storage 변경은 수행하지 않았고 다음 백로그로 이동하지 않는다.

## Android 실기기 Debug 전용 Firebase Emulator 연결 (2026-07-17)

- [x] `USE_FIREBASE_EMULATORS=true`와 Debug를 동시에 요구하는 compile-time gate
- [x] Firebase 초기화 직후 Auth/Firestore/Functions 연결
- [x] Auth localhost:9099, Firestore localhost:8080, Functions localhost:5001
- [x] 실기기 `adb reverse`용 automatic host mapping 차단
- [x] Functions `asia-northeast3` 공통 instance 재사용
- [x] 연결 실패 시 다음 connector·production fallback 차단과 오류 화면
- [x] Debug Emulator 모드의 작은 `LOCAL EMULATOR` overlay
- [x] Profile/Release define=true 빌드와 Emulator marker 미포함 확인
- [x] 관련 26개, 전체 Flutter 193개, 변경 범위 analyze, Debug/Profile/Release APK, diff 검증
- [ ] USB 실기기에서 Anonymous 시작·회원·일정·레슨일지 Emulator 수동 검증

실제 Firebase deploy, Rules/Functions/Storage 변경은 수행하지 않았고 다음 백로그로 이동하지 않는다.

## Firebase NO-GO 해소 — Region·maxInstances·Indexes·Console 확인 (2026-07-17)

- [x] 첫 배포 필수 9개 v1 callable을 `asia-northeast3`로 명시
- [x] 필수 9개 callable에 실제 `runWith({maxInstances: 10})` 적용 및 endpoint metadata 확인
- [x] Flutter callable 기본 instance를 `MtfFirebaseFunctions`로 중앙화
- [x] Emulator callable URL을 공통 wrapper로 중앙화하고 서울 리전 회귀 확인
- [x] 실제 query 전수 감사: schedules 1개, training_logs 1개 composite 유지
- [x] equality-only members 목록·전화 중복과 메모리 status filter에 불필요한 composite 미추가
- [x] 한국어 Firebase Console 출시 전 수동 확인 체크리스트 작성
- [x] PITR 이력은 활성화 이후 누적되며 기존 7일 이력이 즉시 생기지 않음을 기록
- [x] Functions lint/build, Emulator 168개, Flutter 187개, 변경 범위 analyze 통과
- [x] Debug APK, Release APK, Release AAB와 `git diff --check` 통과
- [ ] Console에서 실제 데이터 project 성격, Auth provider/domain/template 확인
- [ ] 현재 Published Rules 원문·주요 collection count 확보
- [ ] billing·bucket·IAM 확인 후 첫 배포 전 managed export 완료
- [ ] 두 composite index 실제 배포 후 `Enabled` 확인
- [ ] 승인된 9개 Functions·indexes·Rules 선택 배포 및 release smoke

코드 NO-GO는 해소했다. Console 확인과 배포 전 백업이 남아 실제 배포는 계속 **NO-GO**다. deploy/export/admin 생성은 실행하지 않았고 다음 백로그로 이동하지 않는다.

## Firebase 실제 배포 준비 감사 (2026-07-17)

- [x] project/CLI/database/bucket/runtime/region read-only 확인
- [x] 로컬 top-level Functions export 14개 전수 목록과 앱 실제 호출 비교
- [x] 현재 배포 Functions 0개, 로컬 전용 14개, 원격 전용 0개 확인
- [x] Anonymous 출시 필수 callable 9개와 관리자·legacy 보류 5개 분리
- [x] collection별 Anonymous/Linked/Legacy Rules 영향표 작성
- [x] personal query 전수 감사와 local 2개/production 0개 composite index 비교
- [x] Storage Rules를 첫 Anonymous 배포에서 제외하는 근거 기록
- [x] 백업·Rules/Functions/index/Auth rollback과 release smoke 계획 작성
- [x] 전체 Functions 일괄 배포가 아닌 A1 4개 → A2 3개 → A3 2개 PowerShell 초안 작성
- [x] Functions lint/build, Firebase Emulator 168개, Flutter 186개 통과
- [ ] Console에서 개발/운영 project 성격과 Anonymous/Email provider/domain/template 확인
- [ ] 현재 Published Firestore Rules 원문·metadata와 주요 collection count 확보
- [ ] billing/IAM/bucket 확인 후 managed export 또는 승인된 대체 백업 완료
- [x] 출시 필수 9개 v1 `maxInstances=10`과 `asia-northeast3` 적용
- [ ] member equality production query smoke 확인
- [ ] 승인 후 선택 Functions, indexes, Rules 단계별 배포와 실기기 smoke

현재 판정은 **NO-GO**다. 실제 deploy/export/provider/claim/admin/data 변경은 수행하지 않았고 다음 백로그로 이동하지 않는다.

## 닉네임 온보딩·마이페이지 정보 넛지 (2026-07-18)

- [x] anonymous bootstrap 뒤 nickname/onboardingCompleted 기반 기존 온보딩 복구
- [x] `completeNicknameOnboarding` v1 callable의 Auth UID·personal identity·멱등 transaction
- [x] 내부 nickname 정책: trim 후 1~6자, 사용자 간 중복·동일 재저장 허용, 공개 식별자 미사용
- [x] nickname과 선생님 5개 정보 완료/profileCompleted 분리
- [x] personal Home 생성 전 온보딩 완료 확인
- [x] 마이페이지 진입당 미완성 항목 한 개 AIFC 넛지와 UID별 순환
- [x] UID 유지 이메일 연결 시트와 작은 `계정 및 기록` 고정 진입점
- [x] 미구현 Google/Kakao를 `준비 중`으로 표시
- [x] Functions lint/build, Emulator 11개, Flutter 전체 204개, Debug/Profile APK
- [ ] 내부 nickname 1~6자 정책 반영 뒤 Release APK 재검증(이번 실행은 5분·10분 제한 종료)
- [ ] `completeNicknameOnboarding` 선택 배포와 anonymous/linked 실제 기기 검증
- [ ] Google/Kakao provider SDK·Firebase Auth 설정·UID 유지 link 구현

### 회원 앱 연동 단계의 공개 활동명 설계 — 현재 배포 범위 제외

- [ ] 회원 앱 연동 시 별도 `publicDisplayName` 생성 제안
- [ ] 회원에게 보이는 이름을 `nickname / realName / publicDisplayName` 중 선택
- [ ] `publicDisplayName`은 전체 사용자 범위에서 고유하도록 서버 권위 예약·확정 transaction 설계
- [ ] 흔한 이름은 시스템 예약 데이터로 선점하되 현재 nickname과 혼합하지 않음
- [ ] 예약되었거나 사용 중인 공개 활동명 안내를 `이미 등록된 활동명이에요. 조금 더 나만의 이름으로 만들어볼까요?`로 통일
- [ ] 충돌 시 개인정보를 노출하지 않는 대체 활동명 후보 제안
- [ ] Google/Kakao/email은 로그인 provider로만 취급하고 공개 이름의 출처로 사용하지 않음

Firestore/Storage Rules와 실제 Firebase 프로젝트는 변경하지 않았다. 다음 백로그로 이동하지 않는다.

## Anonymous/Linked personal 레슨일지 소유권 격리 (2026-07-16)

- [x] legacy 레슨일지·빠른서명·확정·확정취소·회차·통계 경로 감사
- [x] random ID와 Auth UID 기반 canonical personal training log
- [x] owner/member/date query 및 초안·자동저장 Rules 격리
- [x] 같은 owner의 member와 선택 schedule/member 관계 검증
- [x] completed·노쇼 차감·노쇼 미차감·service 공통 Function transaction
- [x] 중복 확정·중복 확정취소 멱등과 transaction 실패 무반영
- [x] 정식 작성과 personal 일정 빠른 레슨일지의 공통 repository 연결
- [x] personal Rules/Functions Emulator 37개 통과
- [ ] 실제 Firebase Functions·Rules·index 배포와 실제 기기 검증
- [ ] personal anatomy child 최소 Rules 및 Emulator
- [x] MyPage 계정 연결 UI와 모든 경로 완료 후 시작 로그인/Guest gate 제거

legacy migration/backfill, contracts·원격서명 권한, 실제 배포와 다음 백로그 작업은 수행하지 않았다.

## Anonymous/Linked personal 일정 소유권 격리 (2026-07-16)

- [x] 기존 시간 기반 전역 document ID 충돌과 owner 없는 query/write 감사
- [x] random document ID + `slotKey` canonical personal 일정 모델
- [x] Auth UID·personal·기간 범위 query와 CRUD·멀티 등록·주간 복사 격리
- [x] 같은 문서 transaction 이동과 실패 시 원본 보존
- [x] 현재 trainer 소유 회원 연결 검증과 이름-only 일정의 회원 자동 생성 차단
- [x] UID 변경·로그아웃 Android widget cache 정리
- [x] personal Rules Emulator 20개와 legacy Rules Emulator 28개 통과
- [ ] 실제 Firebase Rules·index 배포와 실제 기기 검증
- [ ] personal training_logs 소유권 격리
- [x] MyPage 계정 연결 UI와 모든 경로 완료 후 시작 로그인/Guest gate 제거

실제 Firebase 배포, legacy migration/backfill, 다음 백로그 작업은 수행하지 않았다.

## Anonymous 회원 10명·등급 승급 (2026-07-16)

- [x] 유효 회원 필수값 이름·성별·전화번호·활동 지역 서버 검증
- [x] 정규화 전화번호 기반 workspace 중복 방지와 멱등 저장
- [x] 익명 Beginner 10번째 저장 허용, 11번째 계정 연결·내 정보 완료 gate
- [x] Function transaction 기반 누적 유효 회원 수와 Amateur 10명·Semi-Pro 30명·Pro 50명 승급
- [x] 휴면·만료·삭제 이후 누적 수와 달성 등급 비하락
- [x] 후원 상태 등급 계산 제외와 legacy 회원 자동 귀속 금지
- [x] anonymous owner personal member read, client 직접 write 차단 Rules
- [x] 신규 회원·등급 Emulator 27개, 익명 identity 회귀 26개, profile 회귀 30개 통과
- [ ] 실제 Firebase 배포와 실제 기기 검증
- [x] MyPage의 계정 연결·내 정보 입력 UI 완성 (personal canonical profile/Auth 기준, 실제 배포·실기기 검증 제외)
- [ ] schedules, training_logs, contracts owner 권한 — 이번 작업 범위 밖

시작 로그인 gate는 유지했다. `prompts/19_anonymous_members_tier_promotion.md` 파일은 저장소에 없어 사용자 메시지의 명시 조건을 작업 기준으로 사용했다. 다음 백로그로 이동하지 않는다.

## Anonymous Beginner identity 기반 (2026-07-16)

- [x] 현재 Auth adapter, gate, profile bootstrap, Rules, 관리자 흐름 감사
- [x] 중복 호출을 합치는 `ensureAnonymousSession` service API
- [x] anonymous Beginner profile server bootstrap과 멱등성
- [x] 이메일 `linkWithCredential` 및 연결 전후 UID 일치 검증
- [x] 기존 이메일 충돌 비병합 처리
- [x] profile local→linked transaction과 불변 identity 유지
- [x] anonymous owner의 자기 profile read 최소 Rules
- [x] Auth·Firestore·Functions Emulator 신규 26개 + 기존 profile 30개 통과
- [x] anonymous owner-scoped members와 10명·승급 정책
- [x] anonymous owner-scoped schedules
- [x] anonymous owner-scoped training_logs
- [x] MyPage 계정 연결 UI (UID 유지 email 연결, provider/profile/tier 서버 상태 표시)
- [x] `AppAccountGate`를 로그인 gate에서 anonymous/linked personal bootstrap router로 전환

이번 작업은 identity 기반까지만 완료했다. 다음 백로그로 이동하지 않는다.

## 출시 계정 연결 전환 감사 (2026-07-16)

- [x] 시작 gate, 익명 Auth, profile bootstrap, 회원·일정 owner 흐름 감사
- [x] 현재 credential 흐름과 `linkWithCredential` 부재 확인
- [x] 현재 등급 계산과 요청한 누적 유효 회원 정책 차이 확인
- [x] `RELEASE_ACCOUNT_FLOW.md`, `AUTH_ACCOUNT_POLICY.md`, `TIER_QUALIFICATION_POLICY.md`, `MEMBER_DATA_COMPLETENESS.md` 기록
- [ ] anonymous UID용 personal profile·workspace Rules/Functions 설계 및 Emulator 검증
- [ ] 회원·일정·레슨일지·계약서의 모든 query/write를 Auth UID owner로 통일
- [ ] 현재 anonymous user를 유지하는 이메일 `linkWithCredential` 및 충돌 처리
- [ ] 서버 transaction 기반 누적 유효 회원·프로필·연결 상태 등급 계산
- [x] 위 선행 조건 통과 후 앱 시작 로그인/Guest gate 제거 및 canonical personal workspace 전환

상태: **중단 조건 확인으로 미완료**. 다음 백로그로 이동하지 않는다.

## Functions lint + predeploy 복구 (2026-07-15)

- [x] Functions TypeScript 세 파일 ESLint 오류 정리
- [x] ESLint TypeScript 내부 함수 JSDoc·코드 폭 설정 정리
- [x] `RESOURCE_DIR` 비의존 predeploy lint/build 명령 적용
- [x] Functions lint 0 errors/0 warnings
- [x] Functions TypeScript build 통과
- [ ] 실제 Firebase deploy 및 배포 후 callable 검증

## Debug 긴급 legacy 접근 (2026-07-15)

- [x] Guest 시작 화면의 Debug 전용 `기존 개발 데이터 열기` 버튼
- [x] `legacyDeveloper` workspace mode와 기존 `HomePage` 직접 진입
- [x] Debug 세션에서 Auth/profile/password/claim gate 미호출 테스트
- [x] 체험 화면 복귀 시 legacy child tree 폐기와 비영구 상태
- [x] Guest/Linked/관리자 gate 관련 회귀 테스트
- [x] Profile 산출물에서 Debug 버튼 문구 미포함 확인
- [x] Release 산출물 확인 — 한국어 ML Kit runtime 명시와 미사용 언어 최소 R8 규칙 적용, APK/AAB 통과
- [ ] 실제 기기에서 legacy 회원·일정·레슨일지·계약 읽기·쓰기 확인
- [ ] 실제 배포 Rules의 미로그인 Debug 접근 허용 여부 확인

## Legacy Admin workspace 접근 (2026-07-15)

- [x] legacy Firestore·Storage·로컬 상태 경로 감사
- [x] `guest`·`linkedPersonal`·`legacyAdmin` 명시적 workspace mode 분리
- [x] `platformAdmin`과 `legacyDataAccessApproved` 두 claim 및 최초 비밀번호 변경 완료 조건 강제
- [x] 실제 사용 경로만 Firestore·Storage Rules에 명시
- [x] Auth·Firestore·Functions·Storage demo Emulator 28개 시나리오 통과
- [x] 기존 데이터 표시와 개인 작업공간 전환 경로 구현
- [ ] 실제 Firebase 프로젝트 Rules·Functions 배포
- [ ] 실제 관리자 계정 생성과 claim 부여
- [ ] 실제 기기에서 legacy 건수·수정·격리 확인
- [ ] 원격서명 공개 흐름의 별도 보안 설계

## 플랫폼 관리자 LEON + 비밀번호 변경 (2026-07-15)

- [x] 숨김 입력·dry-run·멱등 Admin SDK 프로비저닝 도구
- [x] 기존 claims 보존 및 platformAdmin/legacy 승인 claims merge
- [x] 최초 로그인 비밀번호 변경 전 workspace 차단
- [x] 재인증·updatePassword·token refresh·서버 finalize 흐름
- [x] claim 기반 관리자 workspace 선택과 legacy 버튼 분리
- [x] 마이페이지·설정 비밀번호 변경 진입
- [x] profile 관리 필드 client 직접 변경 거부 Emulator 검증
- [ ] 실제 관리자 계정 생성과 claim 부여
- [ ] 실제 Firebase 배포 전 Rules/Functions diff와 App Check 검토
- [ ] 실제 기기 최초 변경·재로그인·재설정 메일 수신 검증
- [ ] 승인된 legacy owner migration

## Guest Home parity + soft gates (2026-07-15)

- [x] 실제 홈 공통 헤더·주간표·하단 내비 재사용
- [x] Guest 헤더 동행 문구와 작은 로컬 저장 안내
- [x] 로컬 체험 일정 CRUD·이동·재실행 복원·최대 5개
- [x] 6번째 저장 입력 유지와 계정 연결/둘러보기 안내
- [x] 회원·레슨일지·인사이트 샘플 및 계약·서명·알림·위젯 soft gate
- [x] Guest Firestore·Storage·Functions·실제 회원 검색·알림/위젯 sync 경로 미사용
- [ ] 실제 기기에서 일정 편집·앱 재실행·계정 전환 수동 검증
- [ ] Guest 일정의 명시적 동의 기반 Linked 가져오기 정책
- [ ] platformAdmin Custom Claim 부여와 관리자 화면은 legacy migration 직전 별도 작업

## Linked Beginner 회원 기반 (2026-07-15)

- [x] 신규 personal 회원 canonical identity와 owner-scoped repository
- [x] active·paused 포함, dormant·expired·deleted 제외 10명 transaction 제한
- [x] client 직접 create/update/delete 및 관리 상태·count 우회 차단
- [x] Auth·Firestore·Functions Emulator 회원/Rules 시나리오 통과
- [x] 첫 회원 등록, 사용량 표시, 실패 시 입력 유지 UI
- [ ] 실제 Firebase 배포 전 Rules diff·Functions region·App Check·실기기 검증
- [ ] Guest 메모리 draft handoff
- [ ] schedules/training_logs owner 기반 신규 쓰기와 회원카드 상세 필드 확장
- [ ] 기존 회원권 정지·재개와 canonical managementState의 단일 transaction 연결

## 계정 기반 2단계 — UID profile bootstrap (2026-07-15)

- [x] non-anonymous UID profile의 서버 전용 멱등 bootstrap
- [x] 신규 Beginner/linked/personal 빈 작업공간의 무승인 진입
- [x] anonymous profile create/read/update 차단
- [x] `trainer_profiles/{uid}` 본인 read·표시 필드 update 최소 Rules
- [x] Auth·Firestore·Functions Emulator 30개 시나리오 통과
- [ ] 실제 Firebase 배포 전 provider·region·App Check·Rules diff와 실기기 bootstrap 확인
- [ ] 첫 실제 회원 저장과 UID owner-scoped data 구조
- [ ] Linked Beginner 관리 중 회원 10명 제한
- [ ] legacy `trainer_profile/me` 및 운영 데이터의 근거 기반 승인·migration


## 계정 기반 1단계 (2026-07-15)

- [x] 첫 실행 Guest 진입과 서버 비접속 정적 미리보기
- [x] 이메일 가입·로그인·재설정·로그아웃 adapter 및 계정 상태 분리
- [x] 신규 UID 계정의 기존 `trainer_profile/me`·운영 데이터 자동 연결 차단
- [ ] 실제 Firebase 프로젝트 이메일 provider·메일 발송·실기기 인증 검증
- [ ] Google provider와 Android SHA-1/SHA-256 설정 확인 후 로그인 구현
- [ ] `trainer_profiles/{uid}` 생성·읽기 Rules와 명시적 legacy 데이터 접근 승인 절차
- [ ] Linked Beginner 관리 중 회원 10명 한도 및 회원저장 중 계정 연결


## P0 — 기준 상태
- [ ] Git 저장소와 복구 지점 확인
- [ ] `flutter pub get`
- [ ] `flutter analyze` 기준 결과 기록
- [ ] `flutter test` 기준 결과 기록
- [ ] `flutter build apk --debug` 기준 결과 기록
- [ ] 현재 컴파일 차단 오류만 수정
- [ ] 앱 시작 Auth gate와 로그인·로그아웃·계정전환 정책 확정
- [ ] Firebase Auth UID 기반 trainer profile 결속 및 조직 membership 모델 정의
- [ ] canonical trainerId 신규 쓰기 도입 전 legacy identity dry-run·승인 migration 계획 검토

## P0 — 운영 버그
- [ ] 홈 레슨 단일 편집 시 이전 다중 날짜·요일 상태 미상속 실제 기기 검증
- [ ] 단일 이동 후 재진입·삭제 시 target 1개만 mutation되는지 검증
- [ ] 단일 메모·색상 수정 시 update 1회/createOrUpdateMany 0회 검증
- [ ] 명시적 다중 선택에서 선택한 날짜만 저장되는지 검증
- [ ] 삭제 후 다른 레슨 편집 시 이전 선택 상태 미상속 검증
- [ ] 연속 이동·삭제/재진입/앱 강제 종료 후 재실행 재검증
- [ ] 주간 위젯 표시 종료시간 이후 현재시간 테두리 제거
- [ ] 자정 이후 오늘 요일 하이라이트 전환
- [ ] 위젯 갱신 예약과 Android 날짜 변경 수신 검증

## P1 — 기반 정리
- [x] `functions/src/index.ts` 중복 코드와 Dart 혼입 정리
- [x] Cloud Functions TypeScript build 통과
- [x] 기본 카운터 테스트 제거
- [x] 홈 레슨 시트 회원 추천 칩 위치·안내 토스트 실제 기기 검증
- [ ] 다음 레슨 계산 단위 테스트 추가
- [ ] 레슨 차감/상태 계산 단위 테스트 추가

## P2 — 위젯 확장
- [ ] 공통 일정 스냅샷 모델
- [ ] 진행 중/다음/다다음 계산
- [ ] 다음 레슨 위젯 보완
- [ ] 다음 2개 + 오늘 일정 위젯
- [ ] 위젯 회원명 개인정보 설정
- [ ] 위젯 테마 공통화

## P3 — 앱 테마
- [ ] 공통 의미 색상 모델
- [ ] 기존 위젯 테마와 앱 테마 연결
- [ ] 신규 화면부터 점진 적용
- [ ] 기존 직접 색상 점진 이전

## P4 — 레슨일지 확장
- [x] 바디맵 부위 ID/좌우/앞뒤 데이터 모델
- [ ] 남/여 바디맵 디자인
- [ ] 부위별 운동/통증/주의 기록 (앱 CRUD·서비스 무결성 완료, parent owner schema/migration 선행 후 Rules·Emulator·실기기 검증 필요)
- [ ] 영상 촬영/압축/썸네일/Storage
- [ ] 회원 공개 권한과 감사 필드
- [ ] 회원 앱 공개 레슨일지/영상
# 2026-07-18 — personal 최초 준비 화면과 실제 HomePage 연결

- [x] Onboarding과 같은 `kOnboardingBg` 및 시스템 영역 배경 적용
- [x] 기존 `AifcAvatar` 92px와 `AifcTypingDots` 재사용
- [x] 역할형 50%·브랜드형 25%·귀여운 문구 25% 후보 및 1.6초 이후 fade 전환
- [x] nickname 미완료는 기존 Onboarding, 완료는 `HomePage(personalOwnerUid: currentUid)`
- [x] `PersonalWorkspaceReadyPage`의 별도 주간 홈/첫 탭 구현 제거
- [x] Home 회원·일정 조회 및 일정 mutation을 current UID personal 범위로 제한
- [x] 홈 햄버거 메뉴를 기존 명함 UI가 있는 `MyPage`의 personal 프로필 경로에 연결
- [x] 관리자·mustChangePassword·Debug legacy 분기 유지
- [x] 관련 테스트, 전체 206개, Debug/Profile APK
- [x] 변경 범위 analyze 신규 error 0건(기존 warning/info 151건 유지)
- [ ] 실제 기기에서 personal Home 회원·일정·레슨일지·마이페이지 전체 동선 확인

# 2026-07-18 — 모어댄 브랜드·Home FC/MORE 센스·공통 네온

- [x] 앱 표시 브랜드를 `모어댄`, 보조 영문을 `MORE THAN`으로 정리
- [x] 계약서 센터명 등 실제 업무·법적 `MORE THAN FITNESS` 문맥 유지
- [x] personal 준비 화면 브랜드 계층과 가로형 FC 메시지 복원
- [x] 시간대·실제 레슨 흐름·실제 회원 이벤트 기반 Home 인사/FC 순수 선택 엔진
- [x] 최근 5개 문구와 일별 질문 중복을 owner 범위 로컬 저장소로 억제
- [x] FC와 확장 MORE 센스에서 동일 회원 이벤트 중복 노출 방지
- [x] Home·마이페이지·회원관리·레슨일지·계약서·운영통계 큰 헤더에 공통 네온 적용
- [x] 전체 217개 테스트 및 Debug/Profile/Release APK 빌드
- [ ] 검증된 위치·날씨 provider와 사용자 동의·실패 정책 확정 후 날씨 문맥 연결
- [ ] Flutter 도구 정체 해소 후 최종 `MORE 센스` 표기 상태 전체 테스트 재실행
- [ ] 실제 Android 기기에서 준비 화면 overflow, 네온 밝기·프레임, 재진입 문구, 실제 MORE 센스 이벤트 육안 검증

# 2026-07-19 — personal 온보딩·Home 인사·MyPage UID 격리

- [x] nickname 비어 있음 또는 onboarding 미완료 시 기존 OnboardingPage 유지
- [x] personal Home에서 nickname 우선 및 nickname 로드 전 `강사님` placeholder 제거
- [x] 과거 네 가지 `강사님` 기본 인사를 자동 모드로 분류
- [x] Home 사용자 고정 인사와 MyPage AI FC 넛지 SharedPreferences를 UID별로 분리
- [x] 오늘·MORE 센스·이번 주 카드의 동일 너비·높이·탭 영역 및 확대 글꼴 검증
- [x] personal MyPage profile read를 `trainer_profiles/{uid}`로 제한
- [x] personal MyPage에서 legacy 목표·상품 하위 위젯 생성 차단
- [x] 명함 `Semi-Pro` 보조 칩 제거 및 상단 이용 멤버십 유지
- [x] 관련 59개·전체 224개 테스트와 Debug/Profile/Release APK
- [ ] 실제 Android 기기 연결 후 `[MTF_PERSONAL_IDENTITY]`로 현재 UID·신규/기존 여부 확인
- [ ] 실제 기기에서 nickname 저장 직후 Home 인사와 서로 다른 두 UID의 MyPage 격리 확인
# 2026-07-19 — Home 시간표 후속 최적화

- [ ] 현재 시간 또는 첫 레슨 기준 자동 포커스의 UX와 기존 스크롤 상태 보존 정책을 별도 설계·검증
- [ ] Android 위젯 시간 범위 최적화를 앱 시간표 기본 범위와 분리해 별도 검증
- [ ] 실제 Android 기기에서 personal UID 전환 시 최근 회원 0명·stale memberId 차단·2줄 헤더 overflow 확인
- [ ] Release APK 빌드가 10분 제한 없이 완료되는 환경에서 재검증

# 2026-07-19 Home 인사 문장부호·nickname canonical 통일
- [x] 질문형·서술형 greetingText를 문장부호까지 포함한 최종 문자열로 관리
- [x] personal AccountGate·Onboarding·Home·MyPage·넛지를 `trainer_profiles/{uid}.nickname`으로 통일
- [x] nickname 완료 후 MyPage가 다음 미완성 프로필 항목부터 안내
- [x] 관련 73개·전체 236개 테스트와 Debug APK 회귀 검증
- [ ] 실제 Android 기기에서 온보딩 완료 직후 Home 2줄 인사와 MyPage 다음 넛지 확인
# 2026-07-19 nickname 저장 경로·MyPage 이름 검증·Home 인사 축소

- [x] 현재 personal nickname 생성·수정 경로 전수 감사
- [x] bootstrap 및 realName/displayName/trainerName 자동 복사 없음 확인
- [x] nickname profile read/write Debug source 로그 추가
- [x] MyPage nickname·실명 모두 공백 저장 차단
- [x] 실명만 있을 때 명시적 nickname 복사 확인 시트 및 6자 초과 자동 축약 차단
- [x] 계약서 반영 설정과 profile 이름 필수 검증 분리
- [x] nickname callable 성공 후 서버 profile 재조회 및 Home stream 갱신 확인
- [x] Home 첫 줄 13px/w600, 둘째 줄 18px/w700로 축소
- [x] 관련 64개·전체 240개 테스트 및 Debug/Profile APK
- [ ] 실제 기기 Debug 로그로 기존 nickname의 다음 read/write source 확인(과거 생성 시점은 미확정)
- [ ] 실제 기기에서 MyPage 이름 조합 4가지와 Home 즉시 갱신 수동 확인
# 2026-07-19 Firebase dev/prod 환경 분리 후속

- [x] prod/dev Android flavor 및 `.dev` applicationIdSuffix 기반 추가
- [x] prod 기존 Firebase 옵션·packageName 유지
- [x] dev Firebase 설정 누락 시 운영 fallback 차단
- [x] dev 설정이 운영 projectId를 담은 경우 시작 차단
- [x] Flutter `AppEnvironment`와 Debug environment/identity 로그
- [x] dev 전용 작은 `DEV` overlay, prod 미표시
- [x] 직접 관련 personal SharedPreferences key에 projectId+UID 범위 적용
- [x] Home 헤더 12px/w600, nickname 17px/w700 적용
- [x] 전체 245개 테스트 및 prod Debug APK
- [x] 별도 Firebase 개발 프로젝트 생성
- [x] dev Android 앱 `com.example.mtf_app.dev` 등록
- [x] `android/app/src/dev/google-services.json` 배치 후 dev Debug APK 빌드
- [ ] dev/운영 앱 동시 설치 및 서로 다른 Auth UID·Firestore 데이터 실기기 확인
- [ ] 실제 기기 `[MTF_ENV_IDENTITY]`로 기존 UID 재사용 여부 확인

## 2026-07-19 DEV Firebase 최초 진입 검증 잔여

- [x] DEV Firebase Android 설정 식별값과 PROD 분리 확인
- [x] 신규 익명 최초 진입 필수 callable 2개 DEV 선택 배포 및 ACTIVE 확인
- [x] 프로필·닉네임·회원 Rules Emulator 테스트와 warning 없는 DEV Rules 배포
- [ ] Android 기기 `R3CX40M6EEM` 재연결 후 DEV 실제 UID와 최초 nickname 온보딩 화면 확인
- [x] Flutter 도구 정지 해소 후 관련 Flutter 테스트, 변경 범위 analyze, dev/prod Debug APK 회귀 빌드
- Artifact Registry cleanup policy는 이번 범위에서 임의 설정하지 않았으며 DEV 비용 관리 후속 확인이 필요하다.
- 다음 백로그 작업으로 이동하지 않는다.

## 2026-07-19 DEV MyPage 저장·tier 후속

- [x] `updatePersonalTrainerProfile`에 nickname·realName을 포함한 MyPage 단일 transaction 저장
- [x] 익명·linked 저장, UID 격리, nickname 검증, 부분 실패 방지 Emulator 14개
- [x] DEV `updatePersonalTrainerProfile` 단일 선택 배포 및 asia-northeast3 목록 확인
- [x] 직업 AI FC 문구에서 nickname을 직책/호칭으로 사용하지 않도록 정리
- [x] 비밀번호 변경 배너 320/360/412dp·text scale 1.0/1.3/1.8 overflow 검증
- [x] personal tier source를 `trainer_profiles/{uid}.tier`로 고정하고 loading/failure 구분
- [x] 전체 Flutter 테스트 257개, DEV/PROD Debug APK
- [ ] 실기기 네트워크 정상 상태에서 MyPage nickname·realName·직업 저장과 즉시 Home 반영 확인
- [ ] 실기기에서 `[MTF_TIER_READ]` success와 Home/MyPage 동일 tier 표시 확인
- [ ] DEV Artifact Registry cleanup policy를 비용 정책 확인 후 별도 설정
- Firestore/Storage Rules와 운영 프로젝트는 이번 작업에서 변경하지 않았다. 다음 백로그로 이동하지 않는다.

## 2026-07-19 DEV MyPage 데이터 소스·계약서 이름 선택 유지

- [x] personal MyPage 읽기·초기화 source를 `trainer_profiles/{currentUid}`로 통일
- [x] 직업 `jobTitle`, 레슨 분야 `primaryActivity`, 소속 형태 `affiliationType` 저장 경계 분리
- [x] 계약서 담당강사명 source `displayName`/`realName`/`manual` 명시 저장 및 값 존재 기반 추론 제거
- [x] 선택값이 비면 저장 차단하고 다른 source로 자동 전환하지 않음
- [x] `updatePersonalTrainerProfile` transaction 저장 후 서버 재조회 일치 확인
- [x] anonymous/linked·UID 격리·source 유지·권위 필드 보존 DEV Emulator 16개
- [x] DEV `updatePersonalTrainerProfile` 단일 선택 배포 및 asia-northeast3 목록 확인
- [x] 관련 36개·전체 263개 Flutter 테스트, 변경 범위 analyze, DEV/PROD Debug APK
- [ ] Android 기기 재연결 후 MyPage 저장→앱 완전 종료→재진입 시 nickname·실명·직업·레슨 분야·소속 형태·계약서 source 유지 확인
- [ ] DEV Artifact Registry cleanup policy를 비용 정책 확인 후 별도 설정
- 운영 프로젝트와 Firestore/Storage Rules는 변경하지 않았다. 다음 백로그로 이동하지 않는다.

## 2026-07-20 DEV/PROD 표시·DEV 일정 인덱스·personal tier 격리

- [x] prod launcher 이름 `모어댄`, dev launcher 이름 `모어댄 DEV`를 flavor Android resource로 분리
- [x] 기존 내부 DEV 배지 유지, launcher 이미지 신규 생성·변경 없음
- [x] existing schedules 복합 인덱스를 DEV에만 선택 배포
- [x] schedules stream 오류의 unhandled 전파 차단 및 안전한 빈 상태 처리
- [x] personal Home tier gate를 `trainer_profiles/{uid}.tier`로 통일
- [x] smart alarm 동기화·알림 설정에 personal UID 전달, `trainer_profile/me` 조회 차단
- [x] Debug legacy의 기존 tier/profile 경로 유지
- [x] 관련 52개·전체 267개 Flutter 테스트, 변경 범위 analyze, DEV/PROD Debug APK, diff 검증
- [ ] Android 기기 재연결 후 launcher의 `모어댄`/`모어댄 DEV` 동시 표시 확인
- [ ] DEV 실기기에서 재진입 값 유지, schedules stream 정상, `trainer_profile/me` permission-denied 없음 확인
- 운영 Firebase에는 어떤 배포나 데이터 작업도 수행하지 않았다. 다음 백로그로 이동하지 않는다.
-
## 2026-07-20 DEV personal nickname 시작 flash

- [x] AccountGate 서버 profile map을 canonical HomePage 초기 데이터로 전달
- [x] Home 첫 build 전에 nickname/tier/profile 배너 상태 초기화
- [x] 초기 profile이 있는 personal Home에서 Firestore cached profile snapshot 적용 차단
- [x] 서버 snapshot 갱신 및 offline 초기 nickname 유지 테스트
- [x] `[MTF_PROFILE_SNAPSHOT]` metadata·적용 사유 안전 로그 추가
- [x] HomeHeaderSection 내부 nickname state/SharedPreferences/`김트` fallback 없음 감사
- [x] DEV flavor Android 시작 화면을 중립 배경으로 설정하고 이전 preview 차단
- [x] 관련 52개·전체 270개 Flutter 테스트, DEV/PROD Debug APK, diff 검증
- [ ] Android 실기기 재연결 후 `fromCache=true 김트 applied=false → fromCache=false 최신 nickname applied=true` 로그 및 시작 flash 제거 확인
- Firebase Functions/Rules/Storage 배포와 PROD 데이터 작업은 수행하지 않았다. 다음 백로그로 이동하지 않는다.
## 2026-07-20 PROD 개발 작업공간 차단 · MyPage 앵커 메뉴

- [x] Debug legacy 허용 조건을 DEV Debug + 정확한 DEV projectId/packageName 단일 getter로 통합
- [x] AccountGate, GuestStart, DEV 아이콘, shell 생성 분기를 단일 getter로 차단
- [x] PROD Debug 직접 상태 주입에도 `DebugLegacyWorkspaceShell` 생성 불가 테스트
- [x] 정식 PlatformAdmin/LegacyAdmin claim 경로 미변경 확인
- [x] MyPage 바텀시트를 기존 `MtfFloatingMoreMenu` 앵커 드롭다운으로 교체
- [x] 통계 → 계약서 관리 → 설정 → 비밀번호 변경 순서와 기존 action 유지
- [x] 선택·바깥 탭·아이콘 재탭·Android back 메뉴 닫기
- [x] 320/360/412 너비와 text scale 1.0/1.3/1.8 회귀 테스트
- [x] 관련 29개, 전체 272개 Flutter 테스트와 DEV/PROD Debug·DEV Release 빌드 통과
- [x] PROD 실기기 runtime guard `allowed=false` 확인
- [ ] DEV 실기기 버튼·MyPage 메뉴 확인: 별도 기존 Firebase default app 중복 초기화 오류로 UI 진입 전 중단
- [ ] PROD Release APK: 904초 빌드 제한으로 미검증
- Firebase/Rules/Storage 배포와 PROD 데이터 작업은 수행하지 않았으며 다음 백로그로 이동하지 않는다.
## 2026-07-20 DEV Firebase [DEFAULT] 중복 초기화

- [x] 저장소 전체 Dart Firebase 초기화와 DEV/PROD main entrypoint 감사
- [x] Android `FirebaseInitProvider` DEV 기본 앱 + 잘못된 PROD Dart options 충돌 원인 확인
- [x] 공통 `MtfFirebaseInitializer`로 기본 앱 initialize/reuse 멱등 처리
- [x] DEV/PROD 정확한 projectId 검증과 안전한 `[MTF_FIREBASE_INIT]` 로그 추가
- [x] 관련 11개 및 전체 273개 Flutter 테스트 통과
- [x] DEV `-t lib/main_dev.dart`, PROD `-t lib/main_prod.dart` Debug APK 빌드 성공
- [ ] DEV 실기기 cold start/hot restart/완전 종료 재실행: ADB 연결 이탈로 미검증
- [ ] DEV 개발 전환 버튼·DebugLegacyWorkspaceShell 진입/복귀 실기기 확인
- [ ] PROD 실기기 identity·개발 전환 버튼 미표시 회귀 확인
- Firebase CLI/배포/데이터 작업은 수행하지 않았으며 다음 백로그로 이동하지 않는다.
## 2026-07-20 DEV 운영 통계 월별 레슨 기록 달력

- [x] personal 월간 canonical 원본을 `training_logs`로 확정하고 schedules/lessonStats 역할 분리
- [x] 현재 Auth UID + personal workspace + 선택 월 한 달 범위 exact query 구현
- [x] 확정 transaction에 회원명·회차 snapshot 최소 추가 및 DEV 단일 Function 선택 배포
- [x] 기존 운영 요약 아래 월 요약·달력·일별 읽기 전용 상세 추가
- [x] 확정취소 총계 제외·상세 보존 정책 적용
- [x] owner 검증을 통과한 memberId만 회원카드 이동 허용
- [x] loading/success/empty/permission denied/network error 및 월 이동 stale 결과 차단
- [x] `training_logs(trainerId ASC, workspaceType ASC, startAt ASC)` DEV 인덱스 배포
- [x] 관련 Flutter 21개, Functions lint/build, Emulator 38개, DEV/PROD Debug APK, diff 검증
- [ ] 전체 Flutter 테스트의 기존 시간대 인사 기대값 실패 1건은 별도 범위에서 재검토
- [ ] Pro 이상 DEV 계정 또는 승인된 테스트 조건에서 월별 달력 실기기 육안 검증
- PROD Firebase·데이터는 건드리지 않았고 다음 백로그로 이동하지 않는다.

## 2026-07-20 Personal 월간 레슨 기록 최종 검증·접근 정책

- [x] Personal 월간 확정 이력 달력을 페이지 전체 Pro gate 밖으로 분리
- [x] Beginner~Grand Prix 공통 월 이동·상태 집계·날짜 상세·당시 회원명/레슨 종류/회차 공개
- [x] 기존 고급 운영 분석과 업그레이드 안내의 Pro gate 유지
- [x] Personal Home 일반 확정·빠른서명·정식 레슨일지의 canonical finalize 경로 및 snapshot 저장 보강
- [x] Personal 확정취소를 canonical cancel 경로로 통일하고 snapshot 보존
- [x] 현재 production 인사 문구에 기존 실패 테스트 기대값만 일치
- [x] 관련 49개·전체 292개 Flutter 테스트, Emulator 38개, DEV/PROD Debug APK, diff 검증
- [ ] Android 기기 재연결 후 DEV 앱 UI로 비개인정보 테스트 회원 및 completed/service/no_show_deducted/no_show_not_deducted/confirm_cancelled 생성
- [ ] Beginner DEV 실기기에서 달력·집계·상세·owner 격리·overflow 최종 육안 확인
- Firebase 재배포와 PROD Firebase·데이터 작업은 하지 않았으며 다음 백로그로 이동하지 않는다.

## 2026-07-20 Personal 레슨 인사이트 Pro gate·월간 더보기·비밀번호 UI

- [x] Personal 레슨 인사이트 canonical Pro rank 3 feature 정의
- [x] Home 하단·Drawer·주간 callback·MyPage 더보기의 동일 AI FC gate 적용
- [x] Beginner·Amateur·Semi-Pro 차단, Pro·Master·Grand Prix 허용 테스트
- [x] StatsPage 직접 route 이중 방어와 tier 확인 전 통계 query 차단
- [x] tier 빈 값·알 수 없는 값·조회 실패의 안전한 차단과 오류 안내
- [x] 사용자 진입 명칭을 `레슨 인사이트`로 통일하고 내부 Stats 이름 유지
- [x] 첫 화면에서 월간 달력 제거, 기존 그래프·요약 순서 복원
- [x] 우측 더보기 → 별도 `월간 레슨 기록` 화면과 지연 query
- [x] 직접 월간 route 비Pro 우회 차단과 기존 집계·snapshot 정책 유지
- [x] 비밀번호 변경·재설정 화면의 온보딩 연보라 토큰·흰 카드 적용
- [x] 일반 back·forced back 차단·인증/검증/성공/실패 로직 회귀 테스트
- [x] 관련 71개, 최종 관련 47개, 전체 307개 Flutter 테스트 통과
- [x] DEV/PROD Debug APK와 `git diff --check` 통과
- [ ] Android 기기 재연결 후 DEV Beginner 안내 시트, Pro 첫 화면·월간 기록, 비밀번호 UI 실기기 확인
- [ ] DEV/PROD Release APK: 이번 실행은 15분 이상 출력 정지로 종료해 미검증
- Firebase CLI와 DEV/PROD 데이터 작업은 하지 않았으며 다음 백로그로 이동하지 않는다.

## 2026-07-20 Amateur 승급 self-heal·레슨 편집·헤더 피드백

- [x] Amateur 2개 표시 조건을 canonical 유효 회원 수 및 provider+프로필 완료 조건과 일치
- [x] Beginner→Amateur 전용 멱등 transaction callable `reconcilePersonalTier` 구현
- [x] 시작·프로필 저장·정식 회원 생성 후 제한된 self-heal 연결
- [x] DEV에 `reconcilePersonalTier`만 선택 배포하고 Rules/Storage/인덱스 미배포
- [x] Functions lint/build와 DEV Emulator 33개 시나리오 통과
- [x] 레슨 편집 actual scoped document ID 비교 오류 수정
- [x] update/move/copyMany/replaceMany 분기와 원본 보존 불변조건 테스트
- [x] 자기 source·duplicate·tombstone·pending delete의 허위 충돌 제외
- [x] atomic 저장 성공 직후 로컬 일정 상태 patch, 실패 시 원본/화면 유지
- [x] 저장 실패·충돌 안내를 시트 단일 토스트로 통합
- [x] 오늘 레슨 수 0/1~3/4~6/7~8/9~11/12+ 헤더 피드백 적용
- [x] 전체 Flutter 테스트 318개와 DEV Debug APK 통과
- [ ] 최종 PROD Debug APK 재검증: 901초 출력 정지로 timeout, 앞선 회귀 빌드 성공만 확인
- [ ] Android 기기 재연결 후 Amateur 승급·금→금+목·빈 목요일 14시·즉시 반영·토스트·9개 레슨 헤더 육안 확인
- PROD Firebase·데이터는 건드리지 않았으며 다음 백로그로 이동하지 않는다.

## 2026-07-21 DEV Personal 스케줄 저장 권한·신규 create 계획

- [x] 빈 source 신규 일정의 `branch=create`, `deleteCount=0` 계획 적용
- [x] Personal 신규 schedule document ID를 `uid--generatedId`로 고정
- [x] Home direct Firestore write에 canonical schedule identity/slot 필드 보강
- [x] 실제 Home 필드 allowlist 기반 owner-scoped schedules client CRUD Rules 정합화
- [x] copyMany retained source exists=true, move/delete source exists=false 검증 분리
- [x] 삭제 후 Source.server 부재 확인을 위한 owner path get과 owner-filtered list 분리
- [x] Firestore Emulator 26개 owner/other UID/batch 시나리오 통과
- [x] 최종 Firestore Rules를 DEV `more-than-fitness-dev-mft`에만 선택 배포
- [x] 전체 Flutter 테스트 320개·DEV Debug APK·diff 검증 통과
- [ ] Android 기기 재연결 후 PROD force-stop 및 DEV 신규 저장·재실행 유지·수→수+목·로그 격리 확인
- PROD Firebase·데이터에는 아무 작업도 하지 않았으며 다음 백로그로 이동하지 않는다.
## 2026-07-21 DEV Personal Amateur 미션·첫 레슨 AI FC·기능 gate 통합

- [x] Amateur 미션을 정상 Personal 일정 10개 + 기존 선생님 정보 완료 2개로 교체
- [x] 고객카드 수·누적 회원 수·provider 연결을 Amateur 판정과 표시에서 제거
- [x] 서버 transaction 일정 집계와 기존 DEV 사용자 self-heal 구현
- [x] Home·MyPage를 동일 `personalTierProgress` canonical 값으로 통일
- [x] 첫 정상 신규 일정 저장 후 기존 AI FC 채팅형 안내를 단일·멀티요일 모두 정확히 1회 표시
- [x] 고객카드 신규 생성의 UI 이중 gate와 `createManagedMember` 서버 Amateur gate 적용
- [x] Home 최근 회원 0명 상태를 경량 AI FC CTA로 교체
- [x] Personal 레슨 인사이트 전체를 Pro 이상으로 제한하고 직접 route/query 이중 방어
- [x] 상담·신규 계약·고객카드·레슨 인사이트 제한 UI를 공통 `AifcTierFeatureGateSheet`로 통일
- [x] Functions lint/build, DEV Emulator 36개, 관련 Flutter 7개, 전체 Flutter 329개, DEV/PROD Debug APK, diff 검증
- [x] 변경 Functions 5개 DEV 선택 배포 성공(Artifact Registry cleanup policy 미설정으로 CLI 종료 코드 1)
- [ ] Android 기기 재연결 후 10개 일정 self-heal, Home/MyPage 2/2, 첫 안내, Amateur 고객카드 등록, 최근 회원 빈 CTA, Pro gate 육안 확인
- PROD Firebase와 데이터에는 아무 작업도 하지 않았고 다음 백로그로 이동하지 않는다.

## 2026-07-23 DEV 네 가지 회귀

- [x] 스마트 알람 사용 기준과 사용자 안내를 Semi-Pro 이상으로 통일
- [x] legacy 고객카드 route 복귀 시 그룹 목록 재조회
- [x] Personal 고객카드에서 unscoped legacy 그룹 조회·노출 차단
- [x] 이번 주·다음 주 목표 제목 자동 테스트 및 DEV 실기기 확인
- [x] MyPage 저장 검증 실패 시 전체 Form 기준 첫 오류 필드 이동
- [x] 관련 테스트 30개 및 DEV Debug APK 검증
- [ ] DEV Rules가 허용하는 legacy 검증 계정/환경에서 그룹 저장 후 목록 즉시 노출 실기기 확인
- [ ] 최종 변경 뒤 전체 Flutter 테스트와 변경 범위 analyze 재실행(현재 Flutter 도구가 15분 동안 종료되지 않음)
- PROD APK/Firebase/운영 데이터 작업 없이 중단하며 다음 백로그로 이동하지 않는다.

### 2026-07-24 실기기 재검증 결과

- [x] Amateur 고객카드·회원목록 레슨일지 Semi-Pro gate
- [x] 기본 그룹 표시명 임시 변경, 목록 필터·카드 배지·고객카드 검은 띠 반영
- [x] 앱 재실행 후 임시 그룹명 유지 및 `MORE THAN GYM` 복원
- [x] 회원 주소 선택 UI와 Kakao 우편번호 검색 화면 진입
- [ ] 서버 tier를 바꾸지 않는 Semi-Pro fixture 또는 기존 Semi-Pro DEV 테스트 계정 준비
- [ ] Semi-Pro 고객카드·목록·Home·직접 route·QR/회원서명 레슨일지 진입
- [ ] 개인정보 동의 저장·서버 readback·재진입·재실행·초기화
- [ ] 주소 결과 callback·저장·재진입과 주소 없이 저장
- [ ] 사용자 레슨 종류 추가·재진입·삭제 및 기존 회원 값 유지
- [ ] 고객카드 첫 오류별 이동
- [ ] 위젯 warm/cold, Smart Alarm, 이번 주·다음 주 목표 회귀
- [ ] Personal 고객카드의 nested collection·schedule·`trainer_profile/me` permission-denied 및 unhandled exception 원인 확인
- 기기 포그라운드가 반복 전환되어 다른 앱 오조작 위험 때문에 중단했다. PROD 1.0.4 준비 완료로 처리하지 않는다.

## 2026-07-21 Android 오늘 레슨 롤업 위젯

- [x] 기존 Home/Personal 공통 일정 스냅샷을 재사용한 오늘 레슨 롤업 데이터 연결
- [x] 진행 중·다음·다다음·세 번째 이후(높이별 2~4개)·초과 개수·빈 상태 Glance UI
- [x] UID 전환·로그아웃 시 롤업 캐시 정리
- [x] 날짜 변경·시간 갱신 broadcast에서 오늘 날짜 재필터링
- [x] 기존 주간 위젯과 다음 레슨 위젯 리시버·데이터 경로 유지
- [x] JSON 직렬화·날짜 필터 순수 단위 테스트 추가
- [x] Kotlin compile·Manifest/resource merge·관련/전체 Flutter 테스트·DEV/PROD Debug APK 재검증
- [x] 변경 범위 analyze 신규 compile error 0건(기존 home_page warning/info 59건)
- [x] 위젯 cold/warm action을 기존 Home 오늘 이동 메서드에 단일 consume 연결
- [ ] Android 실기기 위젯 선택 목록·0/1/2/3/6건·진행 중·갱신·탭·자정 전환 수동 확인
- [x] 전체 schedule 대신 current UID personal의 한국 날짜 오늘 일정만 담는 schema v2 payload 적용
- [x] writer/readback/parser/render를 appWidgetId·payloadRevision으로 연결하고 stale revision 차단
- [x] Glance 최상위 Column 10개 제한 초과로 인한 Null RemoteViews 복구
- [x] DEV 기존 오늘 위젯 ID 75 실제 1건 및 local fixture 6건 `외 1개`, 10건 `외 4개` 렌더 확인
- [x] DEV warm 탭 및 process 재생성 탭 MainActivity foreground·단일 consume 회귀 확인
- [ ] 사용자 홈 배치를 변경하지 않는 별도 수동 세션에서 새 DEV 오늘 위젯 인스턴스 추가·동일 revision 확인
- Firebase/Rules/Storage 배포와 PROD 데이터 작업은 수행하지 않음.

## 2026-07-21 MyPage 소속별 정보·활동 지역 3곳·영문 이름 검증

- [x] 실제 affiliationType `freelancer|center|personal_shop` 확인 및 새 enum 미추가
- [x] 센터/개인샵의 센터명 → 센터 위치 → 직책 → 주 활동 종목 순서와 직책 필수 적용
- [x] 프리랜서 직책·센터 정보를 탭 가능한 선택형 접힘 영역으로 구현
- [x] Flutter/Functions 공통 의미의 소속별 teacherInfoCompleted 판정 적용
- [x] `activityRegions` 1~3개와 기존 `activityRegion` 대표 mirror·legacy 1개 fallback
- [x] 지역 추가·중복/4번째 차단·대표 변경·변경·삭제 정책 구현
- [x] 선택 `nameEn`의 영문/공백/하이픈/아포스트로피 2~40자 검증과 서버 차단
- [x] Functions lint/build, DEV Emulator 22개, 관련 Flutter 32개, 전체 Flutter 361개 통과
- [x] DEV/PROD Debug APK와 `git diff --check` 통과
- [x] DEV의 `updatePersonalTrainerProfile`, `reconcilePersonalTier` 선택 배포 성공
- [ ] Artifact Registry cleanup policy는 별도 승인 후 설정
- [ ] Android 기기 재연결 후 소속별 순서·접힘 UX·지역 3곳·대표 변경/삭제·영문 오류 스크롤 육안 확인
- PROD Firebase와 데이터에는 아무 작업도 하지 않았으며 다음 백로그로 이동하지 않는다.

## 2026-07-21 PROD 반영 전 알림·등급 로그 정리

- [x] Smart Alarm INCLUDE/SKIP 로그에서 실제 회원명·미등록 일정명·레슨 종류 원문 제거
- [x] 알림 관련 예외 원문·memberId·알림 ID를 안전 코드/존재 여부로 대체
- [x] Home·MyPage·tierGuide의 raw/display 등급 진행률 로그 공통화
- [x] Beginner raw/display 동일, Amateur 이상 raw 보존·display 2/2 테스트
- [x] 관련 18개, 전체 Flutter 373개, DEV/PROD Debug APK, diff 검증
- Firebase 변경·배포와 PROD 데이터 작업 없음. 다음 백로그로 이동하지 않음.

## 2026-07-21 MyPage 편집 UX·등급 표시·Personal 진입 보완

- [x] MyPage 헤더 부제목 제거 및 약 33px 높이 축소
- [x] 키보드 위 SafeArea 고정 저장 버튼과 입력 자동 scroll padding
- [x] 정규화 dirty 판정과 상단/시스템/제스처 back 단일 AI FC 흐름
- [x] projectId+UID scoped local draft 저장·복원·폐기
- [x] 네트워크 단절 저장 실패의 입력 유지·성공 금지·임시 보관 제안
- [x] Amateur 이상 Beginner 미션 earned 2/2 표시와 raw 정보 품질 안내 분리
- [x] MORE 비즈니스 로딩 후 connected/empty/error 분기 및 빈 route 차단
- [x] 계약서 목록 +/빈 CTA와 direct create의 canonical Semi-Pro gate
- [x] Home 오늘 탭의 현재 주·전체 요일·다음 레슨/현재 시간 행 이동
- [x] Personal 사용자 노출 `인사이트`/`MORE 인사이트` 명칭과 기존 Pro gate 유지
- [x] 회원권 관리 첫 AI FC 문구의 회원명 및 `님` 중복 정규화
- [x] 인바디 OCR 실제 경로에 맞춘 사전 안내와 Android 카메라 권한/설정 이동
- [x] 전체 Flutter 테스트 355개, DEV/PROD Debug APK, diff 검증
- [ ] Android 기기 연결 후 DEV 헤더·키보드·dirty/draft·오프라인·등급·비즈니스·계약서·오늘 이동·회원권·카메라 권한 수동 확인
- Firebase 배포와 데이터 작업은 없었고 다음 백로그로 이동하지 않는다.

## 2026-07-21 DEV 등급 안내·Amateur 일정 미션·선생님 정보 검증

- [x] 등급 선택 시 채팅 누적 제거 및 단일 상세 AnimatedSwitcher 교체
- [x] 320/360/412/480dp × 글자 배율 1.0/1.3/1.8 overflow 회귀 테스트
- [x] Beginner 미션을 현재 정상 Personal 일정 10개 + canonical 선생님 정보 완료로 확정
- [x] 생성·삭제·요일 제거·전체 주 삭제 성공 후 서버 tier reconcile 연결
- [x] Beginner→Amateur transition ID와 서버 transaction 축하 claim 1회 보장
- [x] 기존 AI FC 축하 sheet를 Beginner→Amateur 문구·CTA로 확장
- [x] canonical 선생님 정보 5개 필드의 클라이언트·서버 동일 검증
- [x] 시·도/시·군·구 picker, 선택 전화번호 formatter, 생년월일 formatter/DatePicker 적용
- [x] Personal의 `trainer_profile/me` 및 unscoped `member_groups` 초기 조회 차단
- [x] Functions lint/build, DEV Emulator 38+16개, 관련 Flutter 42개, 전체 Flutter 345개 통과
- [x] DEV/PROD Debug APK 빌드 성공
- [x] DEV 함수 3개 선택 배포 성공(Artifact Registry cleanup policy 후처리 실패로 CLI 종료 코드 1)
- [ ] Android 기기 재연결 후 등급 교체·진행률 감소/재완료·승급 축하 1회·MyPage picker/formatter 육안 확인
- PROD Firebase와 데이터에는 아무 작업도 하지 않았고 다음 백로그로 이동하지 않는다.

## 2026-07-23 PROD 1.0.3 전 차단 요소

- [x] Personal 신규 고객카드를 기존 `createManagedMember` callable의 canonical `members/{memberId}` 경로로 저장
- [x] 서버 readback·owner/workspace 검증·목록 snapshot 수신·실제 카드 렌더 확인
- [x] Personal 신규 저장 전 unscoped 전화번호 중복 조회 제거, 서버 UID 범위 transaction 중복 검증만 사용
- [x] 가상/legacy/missing 그룹 cache를 무그룹으로 보정하고 다른 owner 그룹은 거부
- [ ] Personal canonical custom group의 저장 모델·owner 검증·callable 계약 설계 및 Emulator/실기기 검증
- [x] Amateur의 기존 pending 알림을 전체 재구축하고 Smart Alarm effective=false·일반 알림 유지 확인
- [x] Semi-Pro userRequested false/true 정책 단위 테스트
- [x] Flutter 명령 비종료가 Android Studio 자동 Flutter daemon의 SDK lock 점유임을 확인
- [x] 전체 Flutter 테스트 403개 exit code 0 및 analyze 정상 종료 확인
- [x] DEV Debug APK, DEV Kotlin compile, DEV Manifest merge, diff 검증
- [ ] 기존 잘못 저장된 PROD 카드의 비파괴 복구는 별도 승인·문서별 identity 감사 후 수행
- Custom group 실데이터 경로가 없어 PROD 1.0.3 준비 완료로 처리하지 않는다. PROD APK/Firebase/데이터 작업 없이 중단하고 다음 백로그로 이동하지 않는다.

## 2026-07-23 Personal custom group 정책 결정

- [x] 현재 저장소·전체 Git 이력·Rules·Functions·테스트·문서에서 group 계약 전수 감사
- [x] `member_groups/{groupId}`와 `members.groupId/groupName`이 owner/workspace 없는 legacy direct-write 계약임을 확인
- [x] Personal canonical custom group collection·owner field·workspace field·assignment callable이 존재하지 않음을 확인
- [x] `createManagedMember`가 group 인자를 허용하지 않고 안전한 무그룹 canonical member만 생성함을 확인
- [x] PROD `createManagedMember` read-only metadata 확인: ACTIVE, v1 callable, asia-northeast3, Node 22, maxInstances 10, hash `8575d4c179d15956d188e616e3928df8f7919617`
- [x] PROD 배포 기록 commit과 현재 Functions source diff 0, 신규 앱 request 계약 호환 확인
- [x] 관련 22개·전체 403개 Flutter 테스트, analyze 정상 종료, DEV Debug APK, diff 검증
- [x] 제품 결정: 1.0.3은 안전한 Personal 무그룹 저장 정책으로 고정
- [ ] 별도 후속 작업: owner-scoped Personal custom group schema·Rules·Functions·Emulator·실기기 검증 설계
- [x] PROD 1.0.3 (4) 자동 검증: 관련 44개·전체 403개 테스트, PROD Kotlin/Manifest/resource, PROD Debug APK, signer·세 widget provider, diff 검사
- [ ] 실기기 재연결 후 기존 앱 위 `adb install -r`와 데이터 보존·위젯·Smart Alarm·고객카드·MyPage·gate 카나리 검증
- 기기 목록이 비어 설치와 실기기 검증을 안전하게 중단했다. Firebase/운영 데이터 작업 없이 다음 백로그로 이동하지 않는다.

## 2026-07-24 PROD 1.0.3 (4) 카나리 반영

- [x] 기존 1.0.2 (3)와 신규 APK signer 일치 확인
- [x] `adb install -r` Success, 1.0.3 (4) 업데이트
- [x] UID·nickname fingerprint, profile, 일정 230건, Amateur 등급 보존
- [x] PROD identity 유지, DEV 데이터 혼입 및 신규 onboarding 없음
- [x] 오늘 schema v2 payload 7건, 현재 남은 5건 2+3행, 중복 0, hidden 0 실제 렌더
- [x] warm/cold MainActivity foreground·현재 주/오늘/다음 레슨 이동·1회 consume
- [x] 기존 주간 위젯 실제 일정 표시와 주간/다음/오늘 provider 유지
- [x] Amateur Smart Alarm `tierAllowed=false`, `effective=false`, pending 166건 일반 알림 정책 재구축
- [x] Personal `member_groups` 미조회, `__ungrouped__` 표시명만 유지, 신규 카드 legacy custom group 선택 없음
- [x] Amateur 고객카드 허용, Semi-Pro 계약서 gate, Pro 인사이트 gate, MORE 비즈니스 AI FC 대기 안내
- [x] permission-denied·fatal crash·ANR 0건
- [ ] 사용자 직접 신규 회원 저장 시 callable/readback/snapshot/무그룹/전체 목록 노출 관찰
- [ ] 별도 후속 작업에서 Personal 화면의 `__ungrouped__` 표시명을 제품 문구로 유지할지 검토
- Firebase 재배포, 운영 문서 자동 쓰기, 앱 삭제·데이터 초기화, Play Store 배포 없이 중단한다. 다음 백로그로 이동하지 않는다.
- [ ] DEV Personal 고객카드·레슨일지 회귀 실기기 최종 확인
  - 코드 및 자동 검증 완료: 레슨일지 Semi-Pro gate, 동의 persistence, 기본 그룹 표시명, 선택 회원 주소, 레슨 종류 직접입력/관리, 첫 오류 이동.
  - 연결된 Android 기기가 없어 실화면 검증은 미완료.
  - DEV Functions 선택 배포 미완료: `createManagedMember`, `updatePersonalTrainerProfile`, `updateManagedMemberConsent`.
  - 배포 후 확인: 그룹명 목록·카드 동기화, 주소 picker 적용, 동의 저장·초기화 재진입, 미입력/직접입력/삭제, 첫 오류 이동, 저장 후 목록 노출, 오늘 위젯 및 Smart Alarm 회귀.
  - PROD 1.0.4 검토 전 DEV 실기기 통과가 필요하며 PROD 배포·데이터 작업은 별도 승인 전 금지.

## 2026-07-24 DEV Personal 고객카드·레슨일지 회귀

- [x] Personal 레슨일지 Semi-Pro gate 및 페이지 직접 진입 방어
- [x] 개인정보 동의 canonical 저장·readback·초기화 및 실패 화면 유지
- [x] `memberDefaultGroupLabel` 기반 Personal 기본 그룹 표시명 통일
- [x] Personal 그룹 메뉴의 legacy `member_groups` 생성 진입 차단
- [x] 회원 주소 선택값 전환과 주소 picker callback 보존
- [x] MyPage `activityRegions`와 회원 주소 분리
- [x] 레슨 종류 미입력·0회 회원 저장 허용
- [x] UID 범위 `customLessonTypes` 직접입력·관리
- [x] 고객카드 첫 오류 accordion 확장·스크롤·focus
- [x] 관련 18개 및 전체 Flutter 412개 테스트, DEV Debug APK
- [x] DEV Functions 3개 선택 배포(create/update 성공, cleanup policy 미변경)
- [x] DEV 실기기 Amateur gate, 미등록 레슨 표시, 기본 그룹 표시 및 legacy 생성 진입 차단
- [ ] DEV Semi-Pro 계정으로 레슨일지 정상 진입과 동의 저장·초기화 실화면 확인
- [ ] DEV 실기기 주소 검색, 사용자 레슨 종류 추가·삭제, 첫 오류 이동 확인
- [ ] DEV 실기기 기본 그룹 표시명 변경 후 목록·고객카드 동시 갱신과 재진입 확인
- PROD APK/Firebase/운영 데이터 작업 없이 중단하며 다음 백로그로 이동하지 않는다.
## 2026-07-24 DEV Personal 고객카드 canonical read 권한 오류

- [x] Home 일정 → 고객카드 진입에 Personal owner UID 전달
- [x] Personal `trainer_profile/me` 조회 차단 및 `trainer_profiles/{uid}` 사용
- [x] Personal legacy nested `care_milestones`·`achievement_badges` 조회 차단
- [x] 회원 일정 query를 top-level `schedules`의 Auth UID·personal workspace·memberId 범위로 제한
- [x] member/schedule listener `onError`와 중복 억제 진단 로그 적용
- [x] 관련 8개·전체 Flutter 416개 테스트, Rules Emulator 27개, 변경 범위 analyze, DEV Debug APK
- [ ] DEV 실기기 회원목록·신규/기존 고객카드·accordion·레슨일지 gate에서 permission-denied/unhandled 0건 최종 확인
- 실기기 포커스가 DEV 밖으로 전환되어 안전하게 중단했다. 이 확인 전에는 직전 Semi-Pro fixture·동의·주소 수동 검증을 재개하거나 PROD 1.0.4 준비 완료로 처리하지 않는다.

## 2026-07-24 DEV Personal 고객카드 최종 수동 검증

- [x] 신규 고객카드가 존재하지 않는 member 문서·통계·예약 listener를 생성 전에 시작하지 않도록 분리
- [x] 신규 고객카드 진입 직후 permission-denied 및 legacy/nested 실제 요청 0건 확인
- [x] 관련 9개·전체 Flutter 417개 테스트와 DEV Debug APK 빌드
- [ ] 안정적인 DEV 에뮬레이터에서 Semi-Pro 허용·동의 저장/초기화·주소 검색·사용자 레슨 종류·첫 오류 이동 재검증
- [ ] 그룹 표시명·오늘 위젯·Smart Alarm·이번 주/다음 주 목표 수동 회귀
- [ ] 위 항목 통과 전 PROD 1.0.4 준비 완료 처리 금지
- Android System UI/시스템 앱 ANR로 남은 수동 항목은 미검증이다. 다음 백로그로 이동하지 않는다.
## 2026-07-25 새 DEV API 35 에뮬레이터 수동 검증

- [x] `emulator-5554`가 새 AVD `MTF_DEV_API35`임을 확인
- [x] Android 15(API 35), x86_64, 부팅·화면·네트워크·자동 시간·저장 공간 확인
- [x] DEV identity 및 새 익명 UID bootstrap/profile read 확인
- [x] 닉네임 온보딩 완료 후 personal Home 진입 확인
- [ ] 안정적인 AVD에서 고객카드 A~G permission/legacy 요청 최종 검증
- [ ] Amateur 및 DEV 전용 Semi-Pro fixture gate 검증
- [ ] 개인정보 동의 저장·재진입·재실행·초기화 검증
- [ ] 주소 callback, 주소 없는 저장, 사용자 레슨 종류, 첫 오류 이동 검증
- [ ] 기본 그룹 표시명 및 위젯·Smart Alarm·MyPage 회귀 검증
- 중단 사유: Google Play services ANR 이후 Gboard ANR가 추가 발생해 시스템 앱 반복 장애 중단 기준을 충족했다.
- PROD 1.0.4 준비 완료 처리 금지. 다음 백로그로 이동하지 않는다.
## 2026-07-25 MTF_DEV_API35_4K 수동 검증 중단

- [x] `emulator-5554` / `MTF_DEV_API35_4K` / API 35 / x86_64 식별
- [x] 부팅·화면·Keyguard·네트워크·자동 시간·저장 공간 확인
- [ ] 고객카드 A~G 및 canonical permission 검증
- [ ] Semi-Pro gate·동의·주소·레슨 종류·오류 이동·그룹 표시명 검증
- [ ] 위젯·Smart Alarm·MyPage 회귀 검증
- 중단 사유: 기능 검증 시작 전 Phone, Google Play services, Messages 시스템 앱 ANR가 연속 확인됨.
- 안정적인 새 AVD가 준비되기 전 PROD 1.0.4 준비 완료 처리 및 다음 백로그 이동 금지.
## 2026-07-25 DEV A-1 수동 검증 재개

- [x] 지정 AVD `MTF_DEV_API35_4K`만 실행
- [x] 실제 device ID `emulator-5554` 확인
- [x] AVD 이름, Android 15/API 35, x86_64, `PAGE_SIZE=4096` 확인
- [ ] DEV build/install/start 및 Personal Home 진입
- [ ] A-1: 회원목록 → 신규 고객카드 화면 진입
- [ ] A-1 logcat: permission-denied, legacy/nested 요청, fatal crash 확인
- 중단 사유: DEV Gradle 빌드 진행 중 `Application Not Responding: com.android.systemui`가 발생해 즉시 중단했다. 안정적인 지정 AVD 환경에서 A-1만 다시 검증해야 하며 A-2 이후로 이동하지 않는다.
## 2026-07-25 MTF_DEV_API35_4K System UI ANR 환경 진단

- [x] `emulator-5554` / `MTF_DEV_API35_4K` / API 35 / x86_64 / `PAGE_SIZE=4096` 재확인
- [x] `dumpsys activity lastanr`, CPU, System UI meminfo, all-buffer ANR 관련 logcat 수집
- [x] Emulator 36.1.9.0, Windows 하이퍼바이저·물리 메모리, AVD GPU/RAM/CPU/Fast Boot 설정 확인
- [x] logcat에서 System UI KeyguardService 37.741초 service timeout과 같은 부팅 구간의 다중 프로세스 ANR 확인
- [ ] 안정적인 환경이 준비된 뒤 A-1(회원목록 → 신규 고객카드 진입)만 재검증
- 진단 결론: 현재 CPU와 System UI 메모리에는 명백한 과부하가 없지만 ANR 시점에는 다중 startup/service timeout이 있었다. `HyperVisorPresent=False`, 2 cores/2048 MB, GPU auto/gfxstream, Fast Boot 허용이라는 환경값을 다음 조치 판단 근거로 남긴다. 이번 작업에서는 어떤 설정도 변경하지 않고 다음 백로그로 이동하지 않는다.
## 2026-07-25 Windows Android Emulator 가상화 가속 진단

- [x] 실행 중 `emulator-5554`가 `MTF_DEV_API35_4K`임을 확인하고 데이터 삭제 없이 정상 종료
- [x] Android Emulator 공식 `-accel-check`: `AEHD (version 2.2) is installed and usable.`
- [x] AEHD kernel driver `RUNNING`, GVM 서비스 미설치 확인
- [x] Intel N100 BIOS virtualization, VM monitor extensions, SLAT 모두 `True` 확인
- [ ] `HypervisorPlatform` 기능 상태: 일반 권한 DISM 오류 740로 미확인
- [ ] `hypervisorlaunchtype`: BCD store access denied로 미확인
- [ ] 안정적인 환경이 준비된 뒤 A-1(회원목록 → 신규 고객카드 진입)만 재검증
- 이번 작업에서는 가속기·AVD·Windows 설정을 변경하지 않았으며 다음 백로그로 이동하지 않는다.
## 2026-07-25 Galaxy DEV A-1 수동 검증

- [x] 승인된 `R3CX40M6EEM` / `SM-S926N` / Android 16(API 36)에서 DEV flavor 빌드·설치·시작
- [x] PROD 1.0.3(4)와 DEV 패키지 동시 설치 및 PROD 보존 확인
- [x] DEV identity와 Personal Home 진입, 1분 안정성 확인
- [x] A-1 회원목록 → 신규 고객카드 진입
- [x] `회원 주소 (선택)` 표시
- [x] A-1 이후 permission-denied, legacy/nested 요청, PROD project 문자열, fatal crash, ANR 0건
- [ ] A-1 화면 정상 표시: 주소 영역 아래 vertical RenderFlex가 bottom 14px overflow
- [ ] 별도 승인 작업에서 overflow의 정확한 위젯·제약 위치만 조사하고 최소 수정 여부 판단
- 회원 정보 입력·저장과 A-2 이후 검증은 수행하지 않았다. API 35 에뮬레이터 ANR 항목도 여전히 미검증이며 다음 백로그로 이동하지 않는다.
## 2026-07-25 Galaxy DEV 고객카드 묶음 — 첫 오류 이동 중단

- [x] 이름 오류 최초 이동·focus·키보드·오류 팝업
- [ ] 이름 오류 반복 저장 시 재이동·refocus·키보드 재개방
- [x] 전화번호 오류 최초 이동·focus·키보드·오류 팝업
- [ ] 전화번호 오류 반복 저장 시 재이동·refocus·키보드 재개방
- [ ] 회원 문서 미생성 DEV 서버 readback: permission-denied 즉시 중단으로 미확인
- [ ] 중단 결함: client `members where phoneNormalized == ...` query가 Firestore Rules에서 permission-denied
- [ ] 오류 팝업 정확한 표시 문구: 런타임 로그에 없어 미확인
- [ ] 생년월일·직접입력·여러 오류, 주소, 사용자 레슨 종류, 기본 그룹 표시명, 나머지 고객카드 진입 경로
- permission-denied 중단 조건에 따라 고객카드 묶음 검증을 중단했다. 소스 수정이나 다음 백로그 진행은 별도 승인 전 금지한다.

## 2026-07-25 DEV 고객카드 검증 기반·확정 결함

- [x] DEV Debug + DEV 환경에서만 동작하는 로컬 effective tier fixture
- [x] 서버 실제 tier 보존 및 Firestore·Functions 쓰기 없음
- [x] DEV 배지 길게 누르기 등급 선택, PROD 비활성
- [x] 고객카드 공통 DEV viewport `OFF/320/360/390/411dp`, MediaQuery 부수 상태 보존
- [x] Personal phone 중복 검증 owner/workspace 경계 및 신규 서버 transaction 위임
- [x] 반복 오류 저장 시 동일 입력칸 refocus·키보드 재요청
- [x] 기본정보 2/2 PageView 높이 `260`으로 조정
- [x] 관련 Flutter 36개, 전체 Flutter 433개, Emulator 41개 통과
- [x] 변경 범위 analyze 오류 0건, DEV Debug APK 빌드·태블릿 데이터 보존 설치·Home 진입
- [ ] 태블릿 수동: Amateur 선택 후 신규 고객카드 360dp overflow 확인
- [ ] 태블릿 수동: 이름 오류 저장 2회, 전화번호 오류 저장 2회 모두 이동·focus·키보드 확인
- [ ] 태블릿 수동: 320/390/411dp 화면 확인
- 수동 확인 전 완료 처리하지 않고 다음 백로그로 이동하지 않는다.

## 2026-07-26 DEV 고객카드 잔여 기능 묶음

- [x] Kakao 주소 검색 진입·callback·canonical 주소 즉시 반영·저장 readback·재진입·재실행 유지
- [x] 사용자 레슨 종류 추가·profile readback·재표시·중복 방지·삭제·기존 회원 값 유지·기본 종류 삭제 UI 차단
- [x] 기본 그룹 표시명 네 화면 일치·재실행 유지·server readback·baseline 원복 및 네 화면 재확인
- [x] 회원목록 신규/기존, Home 일정, 닫기 후 재진입, 앱 완전 재실행의 고객카드 5개 진입 경로
- [x] Personal top-level schedules query의 Auth owner + `workspaceType=personal` + member 조건 및 owner 불일치 방어
- [x] Personal runtime에서 `trainer_profile/me`, `achievement_badges`, `care_milestones`, `member_groups`, PROD project 징후 0건 사전 정리 확인
- [x] 320/360/390/411dp 기본정보·주소·키보드·삭제된 종류 경고·그룹 영역 overflow 회귀
- [x] 삭제된 사용자 레슨 종류 경고 상태의 회원 현황 높이 보정과 회귀 테스트
- [x] 320/360dp 기본정보 저장값 잘림 방지용 카드 내부 constraint 기반 세로 배치와 회귀 테스트
- [x] 관련 Flutter 75개·전체 451개, 전체 Emulator suite, analyze 신규 error 0, diff check, DEV Debug APK·데이터 보존 설치
- [x] 테스트 회원·일정·custom type·그룹명·tier·count baseline 복원, helper APK 제거, 기기 회전 복원
- [ ] 즉시 중단 결함: 삭제 정리 후 앱 재실행 시 stale 최근 회원 ID의 `members where __name__ in [...]` 조회가 `permission-denied`와 unhandled exception을 발생시킨다. 실제 ID를 로그·보고서에 노출하지 않고, missing/deleted member를 안전하게 제외하는 최근 회원 read 경계를 조사·수정·재검증해야 한다.
- [ ] 위 permission-denied 수정 후 정리→완전 재실행→고객리스트 0명과 종료 로그 0건을 다시 확인해야 고객카드 잔여 묶음을 완료 처리할 수 있다.
- 즉시 중단 조건에 따라 DEV 앱은 force-stop 상태다. 서버는 Beginner, 회원 0, 일정 0, custom type 0, 기본 그룹 `MORE THAN GYM`으로 복원됐다. Semi-Pro·개인정보 동의·위젯 회귀로 이동하지 않는다.

## 2026-07-26 DEV Semi-Pro Gate + 개인정보 동의

- [x] 중앙 tier 정책과 DEV fixture 격리, PROD fixture 무시, Smart Alarm `tierAllowed && userRequested` 확인
- [x] 고객카드·회원목록·Home 레슨일지/빠른서명/확정/서명요청·직접 페이지에 canonical owner/workspace/member 동의 guard 공통 적용
- [x] callable 성공만으로 완료하지 않고 Source.server readback을 다시 요구하며 다른 owner/non-personal 진입 차단
- [x] 레슨일지 8개 진입 경로의 Amateur 차단·Semi-Pro 허용 정책과 direct defense 회귀 테스트 보강
- [x] 핵심 Flutter 25개·전체 Flutter 465개, managed member Emulator 48개와 전체 Emulator 묶음, Functions build, analyze 신규 error 0, diff check, DEV Debug APK
- [x] P10HD Lite에서 Amateur 고객리스트 허용, Semi-Pro fixture 선택, 앱 재실행 후 서버 등급 fixture 복귀, 실제 서버 tier Beginner 확인
- [ ] 실기기 계약서 없는 회원 동의 저장·readback·재진입·앱 재실행·초기화: 실제 tier Beginner와 회원 0명 상태에서 서버가 신규 회원을 `amateur_required`로 거부하며 실제 tier 변경이 금지되어 수행 불가
- [ ] 실기기 레슨일지 8개 경로 전수: canonical DEV 회원·일정이 없어 UI 전수 실행 불가. 자동/정적 검증과 실기기 확인을 구분해 유지
- [x] 종료 로그 permission-denied 0, fatal 0, ANR 0, PROD project 0, consent callable 0, 잘못된 write 0
- [x] local fixture 서버 등급 복원, DEV 앱 force-stop, 서버 baseline 미변경, Galaxy·PROD·Firebase 추가 배포 미작업
- 다음 위젯·알림 회귀 묶음으로 이동하지 않는다.

## 2026-07-26 DEV 실제 Semi-Pro 동의 검증 후 permission-denied 중단

- [x] 현재 태블릿 DEV UID profile baseline Beginner·회원 0·일정 0 확인
- [x] `updateTime` precondition으로 실제 tier Semi-Pro 한 필드 임시 변경 및 서버/앱 readback
- [x] DEV 테스트 회원 1건 canonical 생성과 owner/workspace/legacy group 부재 확인
- [x] 미동의 레슨일지 진입 → 동의 화면 → `updateManagedMemberConsent` 1회 → 레슨일지 화면 진입
- [x] 서버 readback `trainingLogConsentAgreed=true`, `trainingLogConsentAgreedAt` 존재 확인
- [ ] 동의 후 고객카드 재진입·앱 재실행 유지: 동의 직후 permission-denied 재발로 즉시 중단
- [ ] 동의 초기화와 초기화 후 재진입·재실행: 동일 즉시 중단 조건으로 미실행
- [ ] 동의 성공 뒤 레슨일지 초기 로딩의 members/training_logs permission-denied 원인 조사·최소 수정·자동/실기기 재검증
- [x] 정확한 테스트 회원 1건 삭제, tier/earned tier/count Beginner baseline 단일 commit 원복
- [x] 최종 member 0·schedule 0·관리/누적 count 0·custom type 0·기본 그룹 `MORE THAN GYM` readback
- [x] DEV 앱 force-stop, 임시 guard/script 제거, PROD·Galaxy·Firebase 배포 미작업
- permission-denied 수정 전에는 개인정보 동의 실기기 묶음을 완료 처리하지 않는다. 다음 회귀 묶음으로 이동하지 않는다.

## 2026-07-26 — Semi-Pro 개인정보 동의 permission-denied blocker 완료
- [x] 기존 9개 permission-denied 집계의 고유 원인을 owner 없는 Personal `training_logs` 조회 2종과 금지된 legacy `goal_ddays` 조회 1종으로 분류
- [x] Personal training log read를 owner/workspace/member 조건의 canonical query로 통일
- [x] Personal legacy goal D-day/care milestone/badge 경로 및 owner 없는 schedule fallback 차단
- [x] 식별자 없는 Firestore 오류 처리와 회귀 테스트 추가
- [x] 동의 완료 카드와 `동의 초기화` 접근을 막던 고객카드 표시 조건 수정
- [x] 관련 Flutter 42개·전체 Flutter 470개 및 전체 Emulator suite 통과
- [x] analyze 신규 error 0, `git diff --check`, DEV Debug APK 통과
- [x] 실기기 동의 저장·서버 readback·재진입·앱 재실행 유지 검증
- [x] 동의 초기화·서버 readback·재진입·앱 재실행·동의 화면 재표시 검증
- [x] permission-denied·unhandled exception·fatal crash·ANR·PROD marker 0 확인
- [x] 테스트 회원 삭제, tier Beginner 복원, member/schedule/count/custom type 0 확인
- [x] PROD·Galaxy·Firebase 추가 배포·다음 회귀 묶음 미진행

## 2026-07-26 Galaxy 최종 DEV 회귀 — 즉시 중단 후 남은 항목

- [x] Galaxy `R3CX40M6EEM` / `SM-S926N` / Android 16(API 36), DEV·PROD 별도 패키지, PROD `1.0.3 (4)` 시작 상태 확인
- [x] 주간·다음 레슨·오늘 레슨 widget provider 3개 Manifest·runtime 유지 확인
- [x] DEV 오늘 marker 일정 6건으로 schema 2·Asia/Seoul·revision·6개 payload와 실제 다음/다다음/하단 3건/`외 1개` 표시 확인
- [x] Personal Home 주간 목표 편집 경로 추가: 기존 로컬 key 유지, 양수 저장, 빈 값/0 기본값 40 복원
- [x] warm action 중복 원인 확인 및 `MainActivity.onNewIntent()` pending/intent 선소비·실패 시 복원 수정
- [x] 관련 Flutter 11개와 DEV Kotlin compile, 최종 DEV Debug APK build·데이터 보존 재설치
- [x] DEV marker 일정 6건 삭제와 기존 Galaxy DEV baseline `Amateur / member 1 / schedule 7` 복원
- [ ] 수정 후 실제 DEV 오늘 위젯 warm tap 1회 consume 재검증
- [ ] DEV force-stop 후 실제 오늘 위젯 cold tap, onCreate 1회 consume, foreground 재소비 0 재검증
- [ ] Amateur/Semi-Pro Smart Alarm과 일반 알림 실기기 회귀
- [ ] 이번 주·다음 주 목표 입력·저장·재진입·재실행·빈 값·기존값 복원 실기기 회귀
- [ ] MyPage 활동 지역 최대 3곳·저장·readback·재진입·재실행·기존값 복원 실기기 회귀
- [ ] 마지막 주간 목표·warm 경합 수정 기준 전체 Flutter·전체 Emulator·Functions build·analyze·diff check 재실행
- [ ] Galaxy 현재 DEV baseline이 요청 전제(Beginner/member 0/schedule 0)와 다른 이유를 사용자 확인 후, 기존 DEV 데이터를 건드리지 않는 검증 계획 재수립
- 즉시 중단 사유: 고정 홈 페이지 좌표가 기존 PROD 위젯을 눌러 PROD 앱이 foreground가 됐다. PROD에 추가 입력·데이터 명령·Firebase 접근은 하지 않았으며 이후 DEV marker 정리와 문서화 외 실기기 검증을 중단했다.
- `DEV 검증 완료`와 `PROD 1.0.4 준비 가능` 판정은 금지한다. Firebase 추가 배포와 다음 묶음으로 이동하지 않는다.

## 2026-07-27 Galaxy 최종 DEV 회귀 재개 — cold 탭 즉시 중단

- [x] 최신 관련 Flutter 89개·전체 Flutter 472개 통과
- [x] 관련 Emulator 27+30개와 전체 Emulator suite 통과
- [x] Functions build, analyze error 0(기존 warning/info 1,201), diff check, DEV Kotlin·Manifest provider 3개·DEV APK 통과
- [x] DEV 데이터 보존 업데이트와 DEV package/project identity, PROD `1.0.3 (4)` package 보존 확인
- [x] 사용자 warm 탭 로그에서 `onNewIntent` 1회, dispatch 1회, success 1회, 오류 0 확인
- [ ] warm 화면 중복 push 0: 탭 직후 사용자가 응답 화면으로 전환해 UI 연속 관찰 미확인
- [ ] cold `onCreate`·1회 consume·foreground 재전환 재소비 0: 사용자 cold 탭 뒤 PROD package foreground가 확인돼 즉시 중단
- [ ] Smart Alarm Amateur/Semi-Pro/fixture 해제 및 일반 알림 실기기 회귀
- [ ] 이번 주·다음 주 목표 저장·재진입·재실행·원복 실기기 회귀
- [ ] MyPage 활동 지역 최대 3곳·readback·재진입·재실행·원복 실기기 회귀
- [ ] 최종 DEV 종료 로그와 baseline `Amateur / member 1 / schedule 7` 재확인
- [x] 좌표 기반 위젯 탭 미사용, PROD package 대상 ADB 명령·PROD Firebase·PROD APK/AAB·추가 Firebase 배포 미작업
- 즉시 중단 조건이 재발했으므로 `DEV 검증 완료`와 `PROD 1.0.4 준비 가능` 판정은 계속 금지한다.

## 2026-07-27 Galaxy DEV 위젯 명시적 대상 수정 후 잔여 항목

- [x] DEV/PROD appWidget provider와 `PendingIntent` creator·package·component·URI를 정적으로 분리 확인
- [x] 세 위젯 공통 explicit intent factory, package-scoped 오늘 action, flavor URI와 appWidget instance identity 적용
- [x] DEV flavor에만 picker 이름·`DEV ·` 제목·보라색 DEV 전용 배너 추가, PROD 문자열/UI 미변경
- [x] 위젯 관련 Flutter 90개·전체 Flutter 473개, 전체 Emulator suite, Functions build, analyze error 0, diff check, DEV Kotlin·Manifest provider 3개·DEV APK 통과
- [x] DEV 데이터 보존 업데이트와 launcher UI hierarchy의 DEV provider·전용 배너·전체 클릭 영역 확인
- [x] 최신 사용자 cold 탭에서 DEV explicit START 1회, `onCreate` 1회, delivered/consumed 1회, Dart dispatch/success 1회 확인
- [x] 최신 DEV cold 탭 구간 permission-denied·fatal crash·ANR 0 확인
- [ ] foreground 재전환 후 같은 widget action 재소비 0 확인
- [ ] Smart Alarm Amateur/Semi-Pro/fixture 해제와 일반 알림 실기기 회귀
- [ ] 이번 주·다음 주 목표 저장·재진입·재실행·원복 실기기 회귀
- [ ] MyPage 활동 지역 최대 3곳·readback·재진입·재실행·원복 실기기 회귀
- [ ] DEV baseline `Amateur / member 1 / schedule 7` 최종 readback
- 즉시 중단: logcat 초기화 이후 최신 DEV 탭 이전에 launcher가 PROD `MainActivity`를 시작한 별도 기록 3건이 확인됐다. Codex의 PROD 대상 명령·자동 위젯 탭은 없었지만 `PROD 앱 foreground 0` 조건을 만족하지 않으므로 잔여 실기기 회귀를 진행하지 않는다.
- `DEV 검증 완료`와 `PROD 1.0.4 준비 가능` 판정은 계속 금지한다. PROD·Firebase 추가 작업과 다음 묶음으로 이동하지 않는다.

## 2026-07-27 Galaxy 최종 DEV 회귀 완료

- [x] PROD foreground 3건을 `12:01:16.201`, `12:02:47.081`, `12:03:12.132`의 별도 launcher→PROD PendingIntent 사건으로 분류
- [x] 세 사건이 최신 DEV cold `12:13:32.604`보다 10분 이상 앞선 비인과 로그임을 ActivityTaskManager·WindowManagerShell·top-resumed·component·token으로 확인
- [x] DEV cold explicit START·`onCreate`·consume·Dart dispatch/success 각 1회, 재소비 0, 오류 0으로 최종 통과
- [x] DEV fixture Amateur/Semi-Pro Smart Alarm `tierAllowed && userRequested` 실기기 회귀와 일반 레슨 알림 preference 유지 확인
- [x] 이번 주·다음 주 목표 UI 저장, 재진입, DEV 앱 재실행 유지, 기존 default 40 정책 원복 확인
- [x] MyPage 활동 지역 3곳 저장, 최대 3곳 제한, server readback, 재진입·재실행 유지, 기존 1곳 원복 확인
- [x] 종료 로그 permission-denied·unhandled exception·fatal crash·실제 ANR·PROD Firebase marker·legacy Personal marker 0 확인
- [x] 남아 있던 고유 위젯 marker 일정 6건만 정리하고 DEV baseline `Amateur / member 1 / schedule 7 / custom type 0 / MORE THAN GYM / 활동 지역 1` 복원
- [x] 최신 자동 검증 결과 유지: 관련 Flutter 90개, 전체 Flutter 473개, 전체 Emulator suite, Functions build, analyze error 0, diff check, DEV Kotlin·Manifest provider 3개·DEV APK
- [x] PROD package 대상 ADB 명령·PROD 앱 실행·홈 좌표 탭·PROD 위젯 조작·PROD Firebase·PROD APK/AAB·Firebase 추가 배포 미작업
- [x] 최종 판정: `DEV 검증 완료`, `PROD 1.0.4 준비 가능`
- 다음 회귀 묶음이나 PROD 빌드·배포·설치로 이동하지 않는다.
