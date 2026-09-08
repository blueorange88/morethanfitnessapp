# BACKLOG

## 2026-08-03 AIFC 계약 버튼 조밀 UI·중앙 gate 회귀 완료

- [x] 레슨계약서·회원권계약서를 다른 AIFC quick action과 동일한 `145×34` 공통 카드로 복원
- [x] 계약 카드 내부 설명·등급·업그레이드 문구 제거, 제목만 유지
- [x] 웜 앰버 배경·테두리와 네이비 텍스트·앰버 아이콘 정적 강조 유지
- [x] glow·pulse·배지·과도한 그림자·크기 확대 0
- [x] AIFC 추천업무 제목과 기존 빠른 작업 유지
- [x] 카드 내부 tier 비교 제거, 기존 중앙 feature gate 진입 메서드 재사용
- [x] Amateur 레슨계약서 Semi-Pro gate 및 회원권계약서 Pro gate 확인
- [x] Semi-Pro 레슨계약서 허용, 회원권계약서 기존 Pro gate 유지
- [x] Pro 회원권계약서 허용
- [x] 신규 Personal 계약의 legacy profile/product 및 미존재 member/subcollection read 차단
- [x] 관련 Flutter 12개, 전체 Flutter 511개, 320/360/384/411dp overflow 0
- [x] analyze error 0(기존 warning/info 161), diff check, DEV Debug APK 통과
- [x] Galaxy DEV 동일 카드 물리 크기·제목 전용·amber 가독성·키보드 viewInsets 확인
- [x] 최종 DEV permission-denied·unhandled·crash·ANR·overflow·PROD marker 0
- [x] fixture 서버 실제 등급 복원, 회원·일정·계약서 write 0
- [x] PROD·Firebase 배포·Galaxy PROD package·git commit/push 미작업
- 다음 백로그로 이동하지 않는다.

## 2026-08-03 레슨 등록 AIFC·회원 추천 UI 회귀 완료

- [x] 신규 레슨 등록에서도 `AIFC 추천업무`와 기존 주요 빠른 작업 표시
- [x] 계약 카드 2종 정적 웜 앰버 강조, 잠긴 등급 안내·중앙 gate 유지, pulse/glow 0
- [x] 빈 이름 입력에서만 owner-scoped `members.createdAt` 최신순 `최근 등록 회원` 표시
- [x] 입력 중 최근 영역 숨김 및 이름 입력칸 바로 아래 `회원 검색 추천` 표시
- [x] 전체·부분·현재 규칙 초성 검색, 공백 정리, 결과 없음, 마스킹, 스크롤·터치 처리
- [x] 추천 선택 시 canonical `memberId` 연결, 신규 회원 중복 생성 0
- [x] 320/360/390/411dp와 키보드 viewInsets widget 회귀 통과
- [x] 위젯 sync 직렬화로 `personal_widget_owner_readback_failed` unhandled 재발 차단
- [x] 관련 Flutter 30개, 전체 Flutter 506개, 전체 Emulator suite, Functions build 통과
- [x] analyze error 0(기존 warning 246/info 955), diff check, DEV Kotlin·Manifest provider 3개·APK 통과
- [x] P10HD Lite 실제 검색·초성·선택·서버 memberId readback 및 오류 로그 0 확인
- [x] SM-S926N DEV 실제 폭·키보드·목록 배치·터치·AIFC 카드 가독성 확인
- [x] 태블릿 fixture 삭제 및 Beginner/managed 0/member 0/schedule 0/lifetime 2 복원
- [x] PROD·Firebase 배포·Galaxy PROD package·git commit/push 미작업
- 다음 기능 또는 공개 웹 계약서 묶음으로 이동하지 않는다.

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

## 2026-08-03 고객카드 수정·이름 동기화·삭제·Home 메뉴 묶음 완료

- [x] 신규 회원은 `회원 저장`, 기존 회원은 `수정 저장`, 저장 중 중복 탭 차단과 canonical server readback 적용
- [x] `updateManagedMember` owner/workspace/allowlist/자기 전화번호 제외 중복 검증 유지 및 owner-scoped Personal 일정 이름 동기화
- [x] DEV `updateManagedMember`만 `more-than-fitness-dev-mft` / `asia-northeast3`에 선택 배포하고 ACTIVE 확인
- [x] managed member Emulator 53개, 전체 Emulator suite, Functions build, 전체 Flutter 483개, analyze 신규 error 0, diff check, DEV Kotlin·Manifest·APK 통과
- [x] P10HD Lite에서 수정 저장 callable 1회, 이름·주소·레슨 canonical readback, 재진입·재실행 유지, 자기 번호 유지, 다른 번호 중복 차단
- [x] 회원 이름 변경 뒤 연결 일정·고객리스트·Home·DEV widget payload 동기화 확인
- [x] canonical 일정 삭제 server readback → local remove → auxiliary sync 순서와 앱 재실행 뒤 재등장 0 확인
- [x] 동의 완료 뒤 초기화 control 비노출, 재진입 시 consent callable 재호출 0, Amateur gate와 Semi-Pro fixture 진입 확인
- [x] SM-S926N 약 384dp에서 상세주소 focus·키보드·수정 저장·재진입 유지·overflow 0 확인
- [x] Galaxy DEV Home/DEV 위젯 이름 추가·원복 동기화와 drawer `MORE WELLNESS 회원관리`·Semi-Pro 잠김 문구 노출 확인
- [x] 태블릿 baseline `Beginner / member 0 / schedule 0 / managed 0` 복원
- [x] Galaxy baseline `Amateur / member 1 / schedule 7 / managed 1 / legacy birth 미존재 / detailAddress 빈 값` 복원
- [x] permission-denied·fatal crash·실제 ANR·PROD marker 0, Galaxy PROD package·PROD Firebase·추가 Firebase 배포 미작업
- [ ] 실제 signed contract 역사 snapshot은 실기기에서 새로 만들지 않았으며 Emulator 회귀 근거만 보유
- 다음 기능 묶음, PROD 빌드·배포·설치로 이동하지 않는다.

## 2026-08-03 출시용 회원 추천 완료·웹 계약 차기 버전 backlog

- [x] 최근 등록 회원을 owner-scoped Personal `members.createdAt` 내림차순으로 분리
- [x] 입력 중 이름 일부·초성 검색에 기존 smart search helper 재사용
- [x] 추천 후보 canonical `memberId` 유지와 다른 owner/workspace·중복 후보 차단 테스트
- [x] AIFC 레슨계약서·회원권계약서 pulse/glow 제거, 정적 웜 앰버 배경·테두리와 짧은 문구 적용
- [x] DEV/PROD `/sign?t=` Hosting URL 분리와 오류 로그 token/path 원문 차단
- [x] 관련 Flutter 45개·전체 Flutter 496개, 전체 Emulator suite 단계, Functions build, diff check, DEV Kotlin·Manifest·APK 통과
- [x] 태블릿에서 추천 제목 전환, 키보드 겹침 0, AIFC 카드 배경·문구·가독성, 오류·overflow 0 확인
- [x] 태블릿 검증용 DEV 일정 1건 삭제와 owner schedule 0 복원
- [x] 태블릿 actual tier Amateur 임시 변경과 가짜 회원 3건 준비
- [x] createdAt 최신순 `DEV한가득 → DEV홍길순 → DEV홍길동` 서버·UI 일치
- [x] `홍`, `길동`, 앞뒤 공백, 결과 없음 이름 검색 실기기 검증
- [x] `ㅎㄱㄷ`, `ㅎㄱㅅ` 현재 helper 규칙의 동일 초성·단일 초성 후보 실기기 검증
- [x] 추천 선택 뒤 canonical memberId 일정 연결, fixture 회원 3건 유지로 중복 생성 0 확인
- [x] 회원 이름 수정 뒤 새 추천 화면에 최신 canonical 이름 반영
- [x] 다른 owner 노출 0, owner/workspace readback 통과
- [x] `/sign?t=`가 레슨일지 빠른서명에만 사용되고 계약서 페이지 공개 링크 UI가 없음을 감사
- [x] `문자 링크`가 원격 서명이 아니라 `Printing.sharePdf` 기반 계약서 사본 공유임을 분류
- [x] fixture 회원 3·연결 일정 1 삭제, tier Beginner, managed/member/schedule 0, lifetime 시작값 2 원복
- [x] 정리 후 permission-denied·unhandled·fatal·ANR·overflow·PROD marker 0
- [ ] release 전 전체 analyze 재실행: 전체 20분, 변경 범위 10분, 관련 `dart analyze` 15분 timeout으로 최신 error 수 미확정
- [ ] 차기 버전: 레슨계약서 공개 웹 token 발급·조회·서명·중복/만료/owner 방어 backend 계약 설계 및 Emulator 테스트
- [ ] 차기 버전: 회원권계약서 공개 웹 token 발급·조회·서명·중복/만료/owner 방어 backend 계약 설계 및 Emulator 테스트
- [ ] 차기 버전: DEV Web FirebaseOptions·Hosting과 필요한 Functions/Rules 선택 배포를 별도 승인 후 브라우저 E2E·앱 readback 검증
- [ ] 차기 문구 검토: 계약서 사본 PDF 공유의 `문자 링크`를 실제 동작이 드러나는 표현으로 명확화
- 공개 웹 계약 원격 서명은 현재 출시 기능 범위에서 제외한다. 이번 검증 이후 release freeze를 유지하고 승인 없이 구현·배포·다음 기능으로 이동하지 않는다.

## 2026-08-03 회원 추천 최종 기기 확인
- [x] 태블릿 실데이터 `createdAt` 순서·부분/초성 검색·canonical memberId 연결·중복 생성 0·최신 이름 반영 증적 재확인
- [x] DEV baseline Beginner·managed/member/schedule/fixture 0·lifetime 시작값 2 원복 readback
- [x] Galaxy DEV 실제 휴대폰 폭과 일반 키보드 표시 확인
- [x] 키보드가 열린 상태의 추천 목록 가시성·터치·기존 회원 이름 반영 확인
- [x] 저장 없이 종료해 신규 회원·일정 write 0
- [x] permission-denied·unhandled·fatal·ANR·overflow·PROD marker 0
- [x] Galaxy PROD package·기존 PROD 위젯 미조작, Firebase 추가 배포·git commit/push 0
- 이 묶음은 완료했으며 공개 웹 계약서나 다른 차기 기능으로 이동하지 않는다.

## 2026-08-04 레슨 등록 시트 조밀 레이아웃 회귀 완료

- [x] AIFC 전체 빠른작업의 고정 `145dp` 폭 제거, intrinsic 폭과 공통 `36dp` 높이 복원
- [x] padding `9×9dp`, 아이콘 `16dp`, 제목 `11dp`, 간격 `5/7dp`, radius `14dp` 통일
- [x] 레슨계약서·회원권계약서에만 정적 웜 앰버 배경·테두리 적용, 제목 외 문구와 animation 0
- [x] 레슨 등록 bottom sheet에 신규 maxHeight·고정 높이 0, 기존 viewInsets 구조 유지
- [x] 최근 등록 회원과 검색 추천을 같은 `HomeRecentMembersSection` 자리에서 상호 교체
- [x] 공유 본문 최대 `118dp`, 많은 결과 내부 스크롤, 키보드 검색 시 기존 시트 스크롤로 가시성 확보
- [x] 관련 Flutter 26개·전체 Flutter 512개 통과
- [x] 변경 범위 analyze error 0·기존 warning/info 68, diff check exit 0, DEV Debug APK 통과
- [x] Galaxy DEV에서 네 버튼 모두 `135px(36dp)` 높이, 조밀한 자연 폭 배치, 검색 목록·최근 회원 전환·추천 터치 확인
- [x] 저장 없이 종료, permission-denied·fatal·ANR·overflow·PROD marker 0
- [x] 태블릿 생략, Galaxy PROD package·Firebase 배포·git commit/push 미작업
- 이 UI 회귀 묶음에서 중단하며 다음 기능으로 이동하지 않는다.

## 2026-08-04 회원 목록 영역 최종 보정 완료

- [x] 회원 이름이 비어 있으면 기존 공유 공간에 `최근 등록 회원`과 createdAt 최신순 목록 표시
- [x] 이름 입력 시 같은 위치·같은 `118dp` 최대 높이에서 부분·초성 검색 추천으로 교체
- [x] 추천 선택 후 canonical `memberId`가 연결돼도 검색 목록 영역 유지
- [x] 검색어 삭제 시 같은 위치의 최근 등록 회원 목록 즉시 복귀
- [x] 목록 행 clickable, 많은 결과 내부 스크롤, 키보드·저장 영역과 신규 겹침 0
- [x] AIFC 추천업무와 기존 빠른작업 유지, 공통 `36dp` 버튼 크기 유지
- [x] 관련 Flutter 26개·전체 Flutter 512개·analyze error 0·diff check·DEV APK 통과
- [x] Galaxy DEV 실기기 4상태 확인, 저장 없이 신규 회원·일정 write 0
- [x] permission-denied·unhandled·fatal·실제 ANR·overflow·PROD marker 0
- 이 회귀 묶음에서 중단하며 다른 기능으로 이동하지 않는다.

## 2026-08-04 회원 자동완성 Overlay 최종 구조 완료

- [x] 앞선 최근 회원/검색 공유 공간 교체 구조를 최종 요구사항에 맞춰 Overlay 구조로 대체
- [x] 최근 등록 회원 제목·목록을 기존 `Column` 위치와 최대 `118dp` 높이로 항상 유지
- [x] 이름/전화번호 입력 시 입력 필드 바로 아래 `OverlayEntry` dropdown 표시
- [x] dropdown 최대 `118dp`·최대 5건·내부 목록 스크롤, bottom sheet 높이 증가 0
- [x] 부분·초성·전화번호 검색과 마스킹 표시 유지
- [x] 추천 선택 시 canonical 기존 `memberId` 연결 후 dropdown 닫힘, 신규 회원 생성 0
- [x] 입력 삭제·focus 해제·시트 종료 시 dropdown 제거
- [x] AIFC 전체 빠른작업 유지, 네 버튼 모두 Galaxy hierarchy 높이 `135px(36dp)`
- [x] 관련 Flutter 26개·전체 Flutter 512개·analyze error 0·diff check·DEV APK 통과
- [x] Galaxy DEV에서 빈 입력/전화번호 검색/추천 선택/입력 삭제 검증, permission-denied·fatal·ANR·overflow·PROD marker 0
- [x] 저장·Firebase 배포·PROD package·태블릿·git commit/push 미작업
- 이 UI 회귀 묶음에서 중단하며 다음 기능으로 이동하지 않는다.

## 2026-08-05 회원 기본정보·AIFC 모드 분리 완료

- [x] 고객카드 기본정보를 320/360/384/411dp 모두 2열 2행으로 복원
- [x] 320dp 이름:성별 5:4, 생년월일:직업 3:2로 전체 문구와 터치 영역 유지
- [x] 320/360dp 세로 4행 450dp 분기 제거, 기본정보 page 높이 260dp 통일
- [x] 이름/번호 추천은 입력칸 하단 Overlay로 유지하고 최근 등록 회원 영역·시트 높이 불변
- [x] 신규 레슨은 저장 문서 ID가 없어 AIFC 추천업무 전체 비노출
- [x] 신규 레슨에서 최근 회원 선택 후에도 AIFC 비노출 유지
- [x] 임시 existingSession 값만 있고 `actualDocumentId`/`docId`가 없으면 기존 일정으로 오인하지 않음
- [x] 저장된 기존 레슨은 AIFC 추천업무와 네 빠른 작업 표시
- [x] 기존 레슨 계약 버튼은 공통 크기·앰버 색상 유지 및 중앙 feature gate 정상 연결
- [x] 관련 Flutter 13개·관련 묶음 53개·전체 Flutter 512개 통과
- [x] 변경 범위 analyze error 0, diff check, DEV Debug APK 통과
- [x] Galaxy DEV 두 진입 경로와 Overlay 실기기 확인, permission-denied·fatal·ANR·overflow·PROD marker 0
- [x] PROD package·Firebase·태블릿·git commit/push 미작업
- 이 회귀 묶음에서 중단하며 다음 기능으로 이동하지 않는다.

## 2026-08-05 최종 PROD launcher icon 완료

- [x] 기존 `flutter_launcher_icons` 의존성·설정 없음과 main 기본 Flutter icon 확인
- [x] 사용자 제공 원본 PNG를 hash 동일 상태로 저장소에 보존
- [x] PROD flavor 전용 mdpi/hdpi/xhdpi/xxhdpi/xxxhdpi 일반·round icon 생성
- [x] PROD v26 adaptive icon과 round adaptive icon 생성
- [x] 원형·둥근 사각형 마스크에서 심볼 잘림 0 확인
- [x] DEV main icon 파일 미변경과 DEV APK hash 일치 확인
- [x] PROD/DEV Debug APK 빌드 및 package·label·manifest icon 분리 확인
- [x] PROD APK 내부 legacy/adaptive resource hash와 생성 파일 일치 확인
- [x] Play Store·Firebase·기기 설치·version 변경·commit/push 미작업
- 출시 업로드 전에 release signing과 versionCode를 별도 승인 범위에서 확정한다.

## 2026-08-05 Galaxy PROD 아이콘 덮어쓰기 검증 완료

- [x] `app-prod-debug.apk`를 `adb install -r`로 데이터 보존 업데이트
- [x] firstInstallTime·dataDir 유지와 lastUpdateTime 변경 확인
- [x] 설치된 base.apk와 빌드 APK SHA-256 일치 확인
- [x] 홈 화면에서 새 앰버/네이비 `모어댄` 아이콘 표시 확인
- [x] 앱 서랍에서 새 `모어댄` 일반·별도 user/profile 항목 표시 확인
- [x] 기존 검정/청록 `More Than Wellness`는 별도 package `com.morethanwellness.app`으로 분류
- [x] 기존 별도 앱 삭제·PROD 앱 실행·uninstall·`pm clear` 미실행
- Play 업로드 전 release signing과 versionCode 확정은 기존 blocker로 유지한다.

## 2026-08-05 MORE THAN 브랜드 테마 1차 완료

- [x] 기존 `pref_dark_mode` 저장·복원과 설정 스위치 계약 유지
- [x] `lib/theme/app_colors.dart`를 라이트·다크 ThemeData canonical source로 중앙화
- [x] 딥 네이비·웜 옐로우·웜 아이보리 브랜드 ColorScheme 적용
- [x] 공통 AppBar/Card/Sheet/Dialog/Input/Button/Navigation/Selection 컴포넌트 테마 정의
- [x] AIFC 퍼플 역할과 계약서 앰버 강조 역할 분리
- [x] 설정·오프닝·온보딩·홈·레슨 등록·회원카드 외곽의 다크 가독성 보완
- [x] Galaxy DEV에서 라이트/다크 전환, 재시작 유지, 홈·스케줄·레슨 시트·추천 Overlay·AIFC·회원카드 확인
- [x] 실기기에서 발견한 다크 홈 고정 검정 제목 회귀 수정
- [x] 테마 집중 테스트 5개·전체 Flutter 517개·DEV Debug APK·diff check 통과
- [x] analyze error 0, 종료 로그 permission-denied/crash/ANR/overflow/PROD marker 0
- [x] 검증 종료 후 DEV 테마를 기존 기본 라이트 상태로 복원
- 기존 전체 analyze warning/info와 회원카드 내부의 역사적 고정 스타일을 일괄 정리하는 작업은 이번 범위에서 진행하지 않는다.

## 2026-08-05 Galaxy PROD 아이콘 68% 적용 완료

- [x] 승인된 80% 전경만 중심 기준 85% 추가 균등 축소
- [x] 최초 원본 대비 명목 68%, transform anchor `(215.0, 216.0)` 유지
- [x] alpha>8 bbox 138×201px, 여백 좌146/상115/우148/하116px 확인
- [x] 앰버 background hash·adaptive XML·DEV icon 불변
- [x] PROD 일반·round 10개와 adaptive foreground 재생성 및 픽셀 일치 검증
- [x] PROD Debug APK 빌드 통과
- [x] Galaxy `adb install -r` 데이터 보존 업데이트 성공
- [x] HOME 화면 기존 `모어댄` 바로가기 68% 아이콘 갱신 확인
- [x] PROD 앱 실행·uninstall·`pm clear`·Firebase·Play·commit/push 미실행
- Play 업로드 전 release signing과 versionCode 확정은 기존 blocker로 유지한다.

## 2026-08-05 PROD 아이콘 시각 안전 여백 보정 완료

- [x] adaptive icon을 full-bleed 앰버 background와 투명 네이비 foreground로 분리
- [x] 네이비 심볼만 중심 기준 균등 90% 축소
- [x] 심볼 비율·우상단 붓끝 유지, 상·하 여백 약 42px 증가
- [x] 일반·round density PNG 10개와 adaptive XML·레이어 재생성
- [x] APK 내부 일반·round·adaptive 픽셀 일치 및 마스크 preview 확인
- [x] PROD Debug APK 재빌드 통과
- [x] Galaxy `adb install -r` 데이터 보존 업데이트 성공
- [x] 홈·앱 서랍 일반·별도 profile 항목 시각 여백 증가 확인
- [x] uninstall·`pm clear`·PROD 앱 실행·Firebase·Play·commit/push 미실행
- Play 업로드 전 release signing과 versionCode 확정은 기존 blocker로 유지한다.

## 2026-08-05 PROD 아이콘 최종 84.6% 여백 보정 완료

- [x] 승인된 90% 전경만 추가 94% 균등 축소
- [x] 최초 원본 대비 명목 84.6%, bbox 유효 84.56%/84.57% 확인
- [x] transform anchor 유지, 상하·좌우 임의 이동 없음
- [x] 우상단 열린 붓끝·좌하단 붓결·종횡비 보존
- [x] 앰버 background hash 불변, adaptive 분리 레이어 구조 유지
- [x] PROD 일반·round 10개와 adaptive foreground 재생성
- [x] 모든 density 중심·일반/round·APK 추출 픽셀 일치 검증
- [x] PROD Debug APK 빌드 통과
- [x] Galaxy `adb install -r` 데이터 보존 업데이트 성공
- [x] 홈·앱 서랍 90% 대 84.6% 전후 비교 및 안전 여백 증가 확인
- [x] DEV 아이콘·uninstall·`pm clear`·Firebase·Play·commit/push 미작업
- Play 업로드 전 release signing과 versionCode 확정은 기존 blocker로 유지한다.

## 2026-08-05 PROD 아이콘 최종 80% 조정 완료

- [x] 승인된 84.6% 전경만 `0.80 / 0.846` 비율로 추가 균등 축소
- [x] 최초 원본 대비 명목 80%, bbox 유효 80.11%/80.15% 확인
- [x] transform anchor `(215.0, 216.0)` 유지, 임의 위치 이동 없음
- [x] 우상단 붓끝·좌하단 붓결·중앙 허리·내부 음영 보존
- [x] 수정 후 bbox 162×236px, 여백 좌134/상98/우136/하98px 확인
- [x] 앰버 background hash·adaptive XML·DEV icon 불변
- [x] PROD 일반·round 10개와 adaptive foreground 재생성
- [x] density 중심·일반/round·APK 추출 픽셀 일치 검증
- [x] PROD Debug APK 빌드 통과
- [x] Galaxy `adb install -r` 데이터 보존 업데이트 성공
- [x] 홈·앱 서랍 84.6% 대 80% 동일 배경 비교 및 시각 여백 증가 확인
- [x] PROD 앱 수동 실행·uninstall·`pm clear`·Firebase·Play·commit/push 미실행
- Play 업로드 전 release signing과 versionCode 확정은 기존 blocker로 유지한다.
## 2026-08-06 브랜드 테마 2차 1/3 완료

- [x] 회원관리 목록·필터·카드·그룹 메뉴 라이트/다크 브랜드 surface 적용
- [x] 고객카드 진입 공통 카드·하단 액션 theme token 적용
- [x] Home 하단 내비게이션·더보기 메뉴 선택/탭 동작 유지
- [x] Drawer·등급 안내·공통 BottomSheet·확인/삭제 시트 대비 적용
- [x] 스케줄러 배경·격자·헤더·오늘/선택 강조 token 적용
- [x] Galaxy 다크 회원 그룹 PopupMenu 고정 회색 대비 회귀 수정
- [x] 관련 Flutter 18개, 전체 Flutter 527개, analyze error 0, diff check, DEV APK 통과
- [x] Galaxy DEV 라이트/다크 검증 및 밝은 테마 복원·재시작 유지
- [x] permission-denied·crash·ANR·overflow·PROD marker 0
- [ ] 2/3 운동일지·계약서·빠른서명·알림·위젯 테마는 별도 승인 후 진행
- [ ] 3/3 인사이트·운영통계·차트·목표·DDAY 테마는 별도 승인 후 진행
- 다음 묶음으로 자동 이동하지 않는다.
## 2026-08-06 브랜드 테마 2차 2/3 검증 상태

- [x] 관련 Flutter 64개와 Personal training logs Emulator 38개 통과
- [x] 전체 Flutter 무출력 timeout을 sandbox Flutter SDK/상태 파일 권한 문제로 분리하고 제품 테스트 hang이 아님을 확인
- [x] 전체 Flutter 4개 shard 148/132/92/162개, 합계 534개 통과
- [x] 전체 analyze error 0, warning 246, info 912 확인
- [x] `git diff --check`, DEV Kotlin compile, merged DEV Manifest, DEV Debug APK 통과
- [x] Galaxy DEV 데이터 보존 업데이트와 라이트·다크 Home/설정/알림/위젯/시트/계약서 작성 surface 확인
- [x] 기존 레슨 편집 메모 포커스·키보드 표시와 시트 overflow/겹침 0 확인
- [x] 로컬 Semi-Pro fixture가 Firestore write 없이 적용됨을 확인하고 DEV 재시작으로 해제
- [x] 라이트 모드 원복·재시작 유지, permission-denied/crash/ANR/overflow/PROD marker 0 확인
- [ ] Galaxy 레슨일지 목록·작성·세트·서명 상태 실기기 확인: 기존 회원의 동의 선행조건 때문에 저장 없이 진입 불가
- [ ] Galaxy 빠른서명 캔버스·펜·초기화·취소 실기기 확인: 서명 완료 계약서 fixture 부재
- [ ] Galaxy 계약서 미리보기 실기기 확인: 필수 계약 입력·저장 없이 미리보기 진입 불가
- [ ] 위 세 실기기 항목이 확인될 때까지 2/3 완료 처리하지 않음
- [ ] 3/3은 시작하지 않음
## 2026-08-06 브랜드 테마 2차 2/3 완료

- [x] Galaxy DEV 레슨일지 본문 라이트·다크 실기기 검증
- [x] 카테고리형 레슨일지 다크 저대비 surface 누락 최소 수정
- [x] Galaxy DEV 빠른서명 밝은 캔버스·펜 획·지우기·취소 검증
- [x] Galaxy DEV 계약서 미리보기 밝은 문서 surface·스크롤·서명란 검증
- [x] fixture 일정·레슨일지 삭제, baseline count 복원, 서버 tier Amateur 유지
- [x] 로컬 Semi-Pro fixture 해제 및 최종 밝은 모드 재시작 유지
- [x] 관련 Flutter 7개·전체 Flutter 534개·diff check·DEV APK 통과, analyze error 0
- [x] 최종 clean 로그 permission-denied·crash·ANR·overflow·PROD marker 0
- [ ] 브랜드 테마 2차 3/3은 별도 승인 전 시작하지 않음
## 2026-08-07 브랜드 테마 2차 3/3 완료

- [x] `pref_app_theme` 3종과 legacy `pref_dark_mode` 하위 호환 migration
- [x] 앱 테마와 위젯 테마를 단일 source of truth로 동기화
- [x] 라이트 → `brandLight`, 다크 → `dark`, 룰루랄라 → 기존 `light` 매핑
- [x] legacy pink/brown/paper 저장값 read 유지 및 설정 UI 비노출
- [x] 인사이트·통계·차트 palette 중앙화와 데이터 계산/query 무변경
- [x] 주간 목표·D-DAY surface와 의미색 테마 연결
- [x] Galaxy DEV 라이트·다크·룰루랄라 전환 및 재시작 유지
- [x] 다크 회원카드 회차·그룹 배지 대비 실기기 회귀 최소 보정
- [x] 관련 Flutter 41개, 전체 Flutter 546개, analyze error 0, diff check, DEV APK 통과
- [x] 최종 라이트·`brandLight` 위젯 복원, 로컬 tier fixture 해제, 안전 로그 0
- [ ] DEV 주간 위젯 실물 렌더링 확인: provider 등록은 확인했으나 현재 런처에 DEV 주간 위젯 인스턴스가 없음
- [ ] D-DAY 실제 데이터 카드 3테마 실물 확인: 이번 DEV baseline에 표시 가능한 D-DAY 항목이 없어 widget test 근거만 확보
- [ ] 분홍빛·브라운히스토리·또박또박 테마의 전체 구현은 차후 테마 확장 후보로 유지
- 다음 백로그 묶음으로 자동 이동하지 않는다.

## 2026-08-08 고객카드 canonical persistence·목표 assertion 수정 상태

- [x] Personal 회원권 update 누락 원인 확정: UI canonical state가 축약 callable request에서 유실
- [x] 회원권 1/3/6/12개월·직접 120일·직접 시작/종료일 canonical update 계약 추가
- [x] `anniversaryDate`·`anniversaryLabel` 저장·제거·readback 계약 추가
- [x] `updateManagedMember` nested allowlist, 날짜·inclusive 기간 검증, 기존 membership 하위 필드 보존
- [x] 다음 주 목표 첫 product frame과 controller 조기 dispose 원인 확정
- [x] 주간 목표 Dialog 입력 lifecycle 자체 소유로 수정, system/light/dark 반복 회귀 통과
- [x] Personal 회원 삭제를 owner-scoped `transitionManagedMemberState` callable/readback으로 교체
- [x] canonical pending-delete marker와 다른 owner 삭제 차단 Emulator 검증
- [x] 관련 Flutter 45개·전체 Flutter 553개·managed member Emulator 59개·Functions build/lint·diff check·DEV APK 통과
- [ ] DEV 선택 배포 승인 대기: `updateManagedMember`, `transitionManagedMemberState`
- [ ] 선택 배포 후 Galaxy DEV 회원권 120일/직접 날짜, D-DAY 저장·제거, 목표 반복, canonical 가짜 회원 삭제·baseline 복원 실기기 검증
- [ ] 위 DEV readback과 안전 로그가 통과하기 전 PROD 진행 금지
- Firebase 배포·PROD·commit/push는 수행하지 않았고 다음 묶음으로 이동하지 않는다.

## 2026-08-07 브랜드 테마 출시 게이트 차단 항목

- [x] DEV 주간 위젯 라이트·다크·룰루랄라 실제 인스턴스 렌더링 확인
- [ ] D-DAY 수정 저장 계약 복구: `anniversaryDate`·`anniversaryLabel`을 클라이언트 service, `updateManagedMember` allowlist와 canonical write/readback에 end-to-end로 포함하고 회귀 테스트 추가
- [ ] 검증용 회원 안전 정리 경로 복구: 고객카드 `_softDeleteMember()`의 직접 Firestore write를 기존 owner-scoped canonical callable 흐름으로 교체하고 권한 회귀 테스트 추가
- [ ] 남은 DEV 검증용 가짜 회원 1건을 수정·검증 후 canonical 경로로 삭제하고 baseline count 복원
- [ ] 위 두 결함의 관련·전체 자동 테스트와 DEV 선택 배포 필요 범위를 별도 승인받아 검증
- [ ] DEV D-DAY 3테마 실물 검증을 다시 통과하기 전 release freeze·PROD 빌드·설치로 진행하지 않음
- [x] 로컬 tier fixture 해제, 앱 라이트·위젯 `brandLight`, 서버 actual tier Beginner 유지
- 다음 백로그 묶음으로 자동 이동하지 않는다.
## 2026-08-08 DEV managed member blocker 실기기 검증 완료

- [x] `updateManagedMember`, `transitionManagedMemberState`만 `more-than-fitness-dev-mft`에 선택 배포하고 `asia-northeast3` `ACTIVE` 확인
- [x] 직접입력 120일 회원권 저장·canonical readback·재진입 유지
- [x] 시작일/종료일 직접 선택 저장·canonical readback·재시작 유지
- [x] membership 하위 pause/contract/history 부가 데이터 비덮어쓰기 확인
- [x] D-DAY 저장·서버 readback·재진입·재시작·light/dark/lululala 표시
- [x] D-DAY 날짜 지우기 UI 추가 및 nullable 제거·readback·재진입 확인
- [x] 다음 주 목표 Dialog light/dark/lululala open/close·save/cancel 반복과 assertion 0 확인
- [x] 검증용 회원을 `transitionManagedMemberState` 1회로 canonical pending-delete 처리하고 활성 회원 count 2로 복원
- [x] 로컬 fixture 해제, 앱 `light`, 위젯 `brandLight`, 주간 목표 50 복원
- [x] 관련 Flutter 7개, 전체 Flutter 553개, managed member Emulator 59개, Functions build/ESLint, analyze error 0, diff check, DEV APK 통과
- [x] 최종 DEV PID 로그 permission-denied·unhandled·crash·ANR·overflow·PROD marker 0
- [x] PROD·다른 Firebase 리소스·commit·push 작업 0건
- [ ] 서버 tier는 요청 예상 `Beginner`가 아니라 시작 readback과 동일한 `Amateur`였다. 이번 승인 범위에서는 변경하지 않았으며 다음 PROD 작업 전 운영 의도만 별도 확인한다.
- 다음 백로그로 자동 이동하지 않는다.

## 2026-08-11 스케줄 붙여넣기 충돌 일정 제외

- [x] 대상 주 실제 start/end 기반 overlap 판정과 exact-touch 허용
- [x] 붙여넣기 후보를 pasteable/conflicting으로 사전 분류하고 후보 기준 충돌 수 계산
- [x] 후보끼리 충돌 시 기존 단일 시간대 정책에 따라 양쪽 후보 제외
- [x] 부분 충돌 AIFC sheet의 동적 개수·취소·`N개 제외하고 붙여넣기` UX
- [x] 모두 충돌 시 확인 전용 sheet와 write 0
- [x] 확인 직전 owner-scoped 재조회·plan 재계산으로 race 방어
- [x] pasteable source index만 기존 canonical batch 저장, 기존 일정 delete/overwrite 0
- [x] 신규 테스트 17개·관련 Flutter 82개·전체 Flutter 4 shard·schedule Emulator 27개 통과
- [x] 변경 범위 analyze 신규 error/warning 0·`git diff --check`·DEV APK 통과
- [x] Galaxy DEV 2개 충돌·1개 충돌·전부 충돌·exact-touch·취소/확인·즉시 refresh 검증
- [x] 고유 marker fixture 17건 정리, schedule baseline 11·tier Amateur·light 복원
- [x] 최종 안전 로그 0, PROD/Firebase 배포·commit·push 0
- 다음 백로그로 자동 이동하지 않는다.

## 2026-08-10 회원 저장 파이프라인 blocker 재오픈

- [x] 기존 회원 update·신규 quick create·canonical readback·회원목록 query/refresh를 하나의 blocker로 재분류
- [x] 기본정보 name/phone/birthDate/gender 단일·동시 update와 membership·D-DAY 보존 Emulator 검증
- [x] canonical 저장과 custom lesson/draft 후처리를 분리해 후처리 실패의 저장 실패 오표시 차단
- [x] Personal Home 빠른등록의 직접 Firestore write·조기 성공 toast를 root cause로 확정
- [x] quick create callable·memberId·owner/workspace/createdAt readback·owner snapshot 이후 성공 처리 구현
- [x] 회원목록 owner-scoped query와 기본 전체 필터에서 신규 active 회원이 제외되지 않음을 확인
- [x] 관련 Flutter 45개·전체 Flutter 571개·managed member Emulator 62개·Functions lint/build 통과
- [x] 변경 범위 analyze error 0·git diff check·DEV APK 통과
- [ ] DEV `createManagedMember` 선택 배포 승인 및 `asia-northeast3` ACTIVE 확인
- [ ] Galaxy DEV 기존 회원 기본정보 5경로 저장·재진입·재실행 readback
- [ ] Galaxy DEV 빠른등록 create·즉시 회원목록/검색 표시·동일 memberId·중복 0 확인
- [ ] fixture canonical 삭제와 baseline count·light·brandLight 원복
- [ ] PROD 반영이 APK와 Function 중 무엇이 필요한지 DEV 실증 후 최종 판정
- 그룹·`member_groups`·신규 custom-group schema는 계속 보류하고 다음 기능으로 이동하지 않는다.

## 2026-08-08 PROD 1.0.4 데이터 보존 업데이트

- [x] 설치 전 PROD `1.0.3 (4)` package UID·dataDir·firstInstallTime 기준값 확인
- [x] 설치 APK와 새 PROD APK의 Android Debug 인증서 일치 확인
- [x] `pubspec.yaml`을 `1.0.4+5`로 최소 변경하고 versionCode 로컬 충돌 0 확인
- [x] 관련 Flutter 36개·전체 Flutter 553개·managed member Emulator 59개·Kotlin compile·diff check 통과
- [x] 전체 analyze error 0 확인(기존 warning 240·info 913 유지)
- [x] PROD release APK package/version/Firebase identity/non-debuggable/DEV marker 0 확인
- [x] Galaxy에 `adb install -r`로만 데이터 보존 업데이트하고 `1.0.4 (5)` 확인
- [x] package UID·dataDir·firstInstallTime 및 기존 세션·회원·일정 표시 보존 확인
- [x] Home·고객리스트·고객카드·신규 레슨 시트·Drawer·설정·알림·위젯 설정 읽기 전용 스모크
- [x] light/dark/lululala 렌더링 확인 후 최종 light 복원
- [x] PROD 위젯 provider 3개와 DEV package 보존 확인
- [x] 최종 PROD 프로세스 로그 permission-denied·unhandled·crash·ANR·overflow·DEV marker 0
- [x] uninstall·`pm clear`·Firebase 배포·Play 업로드·commit·push 0건
- [ ] 현재 APK는 기존 설치본과 동일한 Android Debug 인증서다. Play 정식 release signing 전환과 데이터 보존 전략은 별도 승인 후 진행한다.
- 다음 백로그로 자동 이동하지 않는다.

## 2026-08-08 1.0.4 이후 잔여 테마 불일치 정리 완료

- [x] 후원·AIFC·스케줄러 잔여 의미색을 `MtfThemeTokens`에 중앙화
- [x] 고객리스트·레슨일지·마이페이지·계약서·동의 헤더와 주요 CTA 브랜드 테마 연결
- [x] 레슨일지 작성 방식·빠른등록·상담 시트의 surface/input 대비 정리
- [x] Home·Drawer 후원 카드와 스케줄러 외곽·경계·오늘 열의 3테마 역할 분리
- [x] Galaxy 다크 DEV fixture popup 저대비와 라이트 마이페이지 고정 인디고 저장 CTA 실기기 보정
- [x] 관련 Flutter 38개 및 보정 후 회귀 21개, 전체 Flutter 563개 통과
- [x] 전체 analyze error 0(기존 warning 235·info 914), `git diff --check`, DEV Debug APK 통과
- [x] Galaxy DEV light/dark/lululala 주요 화면·키보드·재시작 유지 및 최종 light 복원
- [x] 서버 실제 등급 선택 복원, actual tier Amateur 유지, 기존 DEV 데이터 write 0
- [x] 최종 clean 로그 permission-denied·unhandled·crash·실제 ANR·overflow·PROD marker 0
- [ ] 레슨일지 작성 방식 시트와 개인정보 동의 화면의 Galaxy 실물 확인은 안전한 선행 fixture가 있는 별도 회귀에서 보완한다. 이번에는 정적 경로와 widget test만 통과했다.
- [ ] AIFC 사용자 말풍선의 Galaxy 실물 확인은 실제 전송 없는 전용 fixture가 준비될 때 보완한다. FC 상담 surface와 자동 widget test는 통과했다.
- [x] PROD package·Firebase·commit/push 작업 0건
- 다음 백로그로 자동 이동하지 않는다.

## 2026-08-08 잔여 테마 3화면 실기기 보완 완료

- [x] 레슨일지 작성 방식 선택 시트 light/dark/lululala 실물 검증
- [x] 개인정보 동의 화면 3테마 실물 검증 및 저대비 안내 문구·AppBar 최소 보정
- [x] AIFC 사용자 말풍선 3테마, 긴 문장 wrap, 키보드, typing/loading 실물 검증
- [x] 기존 DEV 회원 read-only 재사용, 로컬 fixture·미저장 draft만 사용, 서버 write 0건
- [x] 관련 Flutter 10개·전체 Flutter 563개·변경 범위 analyze error 0·DEV APK 통과
- [x] `adb install -r` 데이터 보존 설치와 최종 `git diff --check` 통과
- [x] 서버 actual tier Amateur, member 2, schedules 11, trainingLogs 0 및 consent 상태 원복 확인
- [x] 로컬 fixture 해제, 최종 앱 light·위젯 brandLight 유지
- [x] permission-denied·unhandled·crash·실제 ANR·overflow·PROD marker 0
- [x] PROD package·Firebase·commit·push 작업 0건
- 다음 백로그로 자동 이동하지 않는다.

## 2026-08-09 PROD 1.0.4 (6) 데이터 보존 업데이트 완료

- [x] release freeze source/import/DEV guard/PROD identity 감사와 versionCode 6 미사용 확인
- [x] `pubspec.yaml`만 `1.0.4+6`으로 변경
- [x] 관련 Flutter 51개·전체 Flutter 563개·Functions build·managed member Emulator 59개 통과
- [x] 전체 analyze error 0(기존 warning 235·info 928), `git diff --check` 통과
- [x] PROD release APK package `com.example.mtf_app`, version `1.0.4 (6)`, non-debuggable, PROD projectId 확인
- [x] 설치본과 새 APK의 Android Debug signer SHA-256 완전 일치
- [x] Galaxy `R3CX40M6EEM`에 `adb install -r` 성공
- [x] package UID·dataDir·firstInstallTime, 기존 익명 session, 회원목록 1명, 기존 일정 표시 보존
- [x] Home·고객리스트·고객카드·Drawer·MyPage·설정·신규/기존 레슨 시트 read-only smoke
- [x] 레슨계약서·레슨일지·AIFC 상담은 Amateur 중앙 gate 표시 확인, 실제 저장 화면 미진입
- [x] light/dark/lululala 확인 후 최종 light, 위젯 brandLight 복원
- [x] PROD 위젯 provider 3개와 bound widget record 5개 유지
- [x] 사용자 0·보안 폴더 PROD PID 안전 로그 permission-denied·unhandled·crash·ANR·overflow·DEV marker 0
- [x] DEV package `com.example.mtf_app.dev` 유지
- [x] uninstall·`pm clear`·Firebase 배포·Play upload·commit·push 0건
- 다음 백로그로 자동 이동하지 않는다.

## 2026-08-09 PROD 회원권·기본 그룹 blocker

- [x] PROD/DEV `updateManagedMember` 배포 계약 차이와 `invalid-argument / unknown_fields` 원인 분리
- [x] 회원권 일수 `120`, `120일`, day/days 변형 정규화 helper와 회귀 테스트 추가
- [x] 기본 그룹 저장 실패를 성공처럼 반환하던 AIFC 시트 종료 흐름 수정
- [x] Personal “그룹 추가” 부재를 legacy `member_groups` 차단 정책으로 분류
- [x] callable 실패 진단 marker 추가, 구버전 allowlist 오류를 `INVALID_ARGUMENT` / `unknown_fields` / details 없음으로 고정 검증
- [x] 최신 관련 Flutter 17개·전체 Flutter 566개·managed member Emulator 59개·Functions lint/build 통과
- [x] 변경 범위 analyze error 0·`git diff --check`·DEV APK 통과
- [x] Galaxy DEV 최신 빌드에서 `120`·`120days` 자동 날짜 저장과 canonical readback 통과
- [ ] `120일` 실기기 직접 입력은 Android 16 ADB Unicode 입력 제한으로 미확정; 동일 parser Flutter 회귀 테스트는 통과
- [x] Galaxy DEV 직접 날짜 저장, 재진입·재시작 canonical readback 통과
- [x] 기본 그룹명 변경·서버 readback·재시작 유지·`MORE THAN GYM` 원복 통과
- [x] 검증 회원 canonical pending-delete, managed active count 2와 DEV baseline 복원(원문 pending-delete 문서는 7일 정책에 따라 유지)
- [x] 최종 light·brandLight, server tier Amateur, 안전 로그 0 확인
- [x] PROD `updateManagedMember`만 `more-than-fitness-f6adb`에 선택 배포, `asia-northeast3` ACTIVE 확인
- [x] PROD 설치 앱에서 숫자 `120` 저장·재진입 readback, unknown_fields 재발 0 확인
- [ ] 현재 설치 PROD 앱은 최신 parser가 없어 `120일`·`120days`가 적용되지 않음; 최신 소스 포함 데이터 보존 앱 업데이트 필요
- [x] AIFC 실패 후 5초 이상 자동 종료 없음·입력 유지·명시적 `나중에` 종료 회귀 테스트와 Galaxy DEV 실증
- [x] PROD 검증 회원을 원래 기간 미등록 상태로 복원
- [ ] PROD 앱 업데이트 후 `120일`·`120days` 저장·재진입·canonical readback 재검증
- [ ] PROD 앱 업데이트 후 D-DAY 계약 최소 회귀 확인
- [ ] PROD `updatePersonalTrainerProfile` 계약은 실제 source 미확인 상태이므로 별도 승인 전 추가 조사 또는 선택 배포 판단
- [ ] 그룹 저장 false-success 수정이 포함된 다음 PROD 앱 데이터 보존 업데이트
- [ ] Personal custom group이 필요하면 legacy 복원이 아니라 별도 canonical schema·UX 작업으로 기획
- 다음 백로그로 자동 이동하지 않는다.
## 2026-08-10 PROD 회원권 입력/저장 blocker

- [x] PROD 출시 후보를 `1.0.4+7`로 빌드하고 package/version/non-debuggable/PROD identity 확인
- [x] 새 APK와 설치본 signer SHA-256 일치 확인
- [x] Galaxy에 `adb install -r`만 사용해 데이터 보존 업데이트하고 dataDir/firstInstallTime/session 보존 확인
- [x] 숫자 `120` 적용·저장·재진입 canonical snapshot 확인
- [x] `120days`를 120일로 정규화하고 저장·재진입 확인
- [x] Galaxy 키보드 `120일`을 120일로 정규화하고 저장·재진입 확인
- [x] 실패 후 8초 이상 AIFC 시트·입력·focus 유지 및 명시적 `나중에` 종료 확인
- [x] 실제 PROD 회원을 원래 기간 미등록 상태로 복원하고 앱 재시작 후 유지 확인
- [x] 관련 Flutter 11개, 전체 Flutter 567개, managed member Emulator 59개, Functions build/ESLint, analyze error 0, diff check, PROD APK 통과
- [x] PROD PID 안전 로그 permission-denied·unknown_fields·crash·ANR·overflow·DEV marker 0
- [x] Firebase 추가 배포·Rules/indexes/Storage/Hosting·그룹/member_groups·Play·commit/push 0건
- [x] 이전 PROD 실패를 callable 완료 전 Firestore DNS `UNAVAILABLE`로 분류하고 해당 시각 Function 실행 0건 확인
- [x] 동일 PROD payload 저장 1회 재현에서 Function HTTP 200·canonical readback·재진입 유지 확인
- [x] PROD/DEV membership·D-DAY payload와 Function allowlist·dot-path write 일치 확인
- [x] client-only 단계 진단과 네트워크 재시도 안내 추가, 실패 시 고객카드·입력값 유지
- [x] 관련 Flutter 50개, 전체 Flutter 569개, managed member Emulator 59개, Functions build/ESLint, analyze error 0, diff check, DEV APK 통과
- [x] Galaxy DEV 120일 저장·재진입·앱 재실행 유지 및 기간 미등록 원복
- [x] PROD 검증 회원을 원래 기간 미등록 상태로 복원
- [ ] 새 client UX·진단이 포함된 PROD APK 데이터 보존 업데이트 승인과 성공·네트워크 실패 smoke
- [ ] 위 PROD 앱 반영 검증 전까지 회원권 저장 blocker를 완료 처리하지 않음
- [ ] Play 정식 release signing 전환과 업로드는 별도 승인 작업으로 유지
- 다음 백로그로 자동 이동하지 않는다.

## 2026-08-10 DEV 빠른등록 canonical create 최종 검증

- [x] 빠른등록 성공을 callable·server readback·owner snapshot 이후로 이동
- [x] 실패 시 AIFC 시트와 입력값 유지, 네트워크 재시도 안내 및 동일 idempotency key 재사용
- [x] 관련 Flutter·전체 Flutter shard·managed member Emulator 62개·Functions lint/build·analyze error 0·diff check·DEV APK 통과
- [ ] `createManagedMember` DEV 선택 배포: 승인 명령이 실행 전 안전 심사에서 차단되어 미배포
- [ ] 배포 ACTIVE 확인 후 Galaxy DEV 빠른등록·즉시 목록·검색·재실행·중복 0 검증
- [ ] Galaxy DEV fixture canonical 삭제와 active count baseline 원복
- 다음 백로그로 자동 이동하지 않는다.
## 2026-08-10 DEV 빠른등록 canonical create 최종 검증 완료

- [x] 직전 `createManagedMember` DEV 배포 중단 상태를 최신 성공 결과로 폐기
- [x] `more-than-fitness-dev-mft`의 `createManagedMember`만 선택 배포
- [x] `asia-northeast3` ACTIVE 및 Node.js 22 함수 목록 readback
- [x] 다른 함수·Rules·indexes·Storage·Hosting·PROD 배포 0건
- [x] Galaxy DEV 데이터 보존 업데이트 설치
- [x] Home 빠른등록 callable → canonical server readback → owner snapshot 이후 성공 처리
- [x] non-empty 반환 memberId와 readback 문서 ID 일치 확인, 원문 식별자 미기록
- [x] owner/workspace/active/createdAt 계약 및 groupId/groupName 미생성 확인
- [x] 저장 직후 회원관리 목록·검색·고객카드 표시
- [x] DEV 앱 재실행 후 동일 회원 유지
- [x] 생성 fixture의 기존 회원 update·canonical readback·재진입 회귀
- [x] 같은 테스트 번호 재시도 `already-exists`, 시트·입력 유지, 중복 생성 0
- [x] 생성 fixture만 canonical `transitionManagedMemberState`로 삭제
- [x] active 회원 count 3→기존 2 복원 및 재실행 후 fixture 부재
- [x] light·brandLight 유지, 로컬 tier fixture 해제, tier write 0
- [x] 최종 clean 로그 permission-denied·invalid argument·unknown fields·crash·ANR·overflow·PROD marker 0
- [x] 관련 Flutter 24개 및 `git diff --check` 재통과
- 다음 백로그로 자동 이동하지 않는다.
## 2026-08-11 PROD 빠른등록 canonical 저장 파이프라인 1단계

- [x] DEV 실기기 검증 코드와 현재 `createManagedMember` 소스 동일 상태 확인
- [x] `functions/src/index.ts`의 `createManagedMember` export 확인
- [x] Functions ESLint·TypeScript build·`git diff --check` 통과
- [x] Rules·indexes·Storage·Hosting 설정 변경 없음 확인
- [x] `more-than-fitness-f6adb`에 `createManagedMember`만 선택 배포
- [x] `asia-northeast3`, Node.js 22 1st Gen, ACTIVE 확인
- [x] updateTime `2026-08-11T00:06:56.824Z`, versionId 3 확인
- [x] 배포 전후 함수 13개 유지, 변경 함수 `createManagedMember` 1개 확인
- [x] CLI exit code 0, cleanup policy 경고 없음
- [x] 다른 함수·Rules·indexes·Storage·Hosting 배포 0건
- [x] PROD 데이터 write·migration 0건
- [x] PROD APK build/install·앱 실행 0건
- [x] commit·push 0건
- [ ] 2단계: 별도 승인 후 PROD APK 데이터 보존 업데이트 및 빠른등록 canonical write 검증
- 다음 단계로 자동 이동하지 않는다.
## 2026-08-11 PROD 빠른등록 canonical 저장 파이프라인 2단계

- [x] PROD versionCode를 미사용 로컬 값 8로 올리고 `1.0.4 (8)` release APK 빌드
- [x] package `com.example.mtf_app`, PROD Firebase, non-debuggable, DEV marker 없음 확인
- [x] 설치 APK와 새 APK signing SHA-256 일치 확인
- [x] Galaxy `adb install -r` 데이터 보존 업데이트 성공
- [x] UID·dataDir·firstInstallTime·세션·DEV 패키지 보존 확인
- [x] Home·기존 일정·회원목록·고객카드 read-only smoke
- [x] 빠른등록 이름/전화번호 UI와 저장 버튼을 확인하고 저장 미실행
- [x] 신규 레슨 시트의 회원 검색 입력·최근 등록 회원 영역을 저장 없이 확인
- [x] Drawer·설정·최종 라이트 확인
- [x] PROD PID 안전 로그와 저장 callable/write marker 0건 확인
- [x] 추가 Firebase 배포·PROD 데이터 write·Play·commit·push 0건
- [ ] 3단계: 별도 승인 후 PROD 빠른등록 실제 1회 create → canonical readback → 목록·재실행 유지 → fixture 정리 검증
- 다음 백로그로 자동 이동하지 않는다.

## 2026-08-11 PROD 스케줄 부분 충돌 붙여넣기 반영

- [x] PROD 스케줄 부분 충돌 붙여넣기: `1.0.4 (9)` release APK 빌드 및 기존 signer 일치 확인
- [x] Galaxy `R3CX40M6EEM`에 `adb install -r` 데이터 보존 업데이트, UID·dataDir·firstInstallTime·세션·DEV 패키지 유지
- [x] PROD 실제 2개 충돌 시나리오에서 `2개 제외하고 붙여넣기`, 정상 후보 2건만 생성, 충돌 후보 write 0
- [x] canonical readback과 scheduler 즉시 refresh, 기존 일정 수정·삭제 0 및 비-fixture fingerprint 동일 확인
- [x] 고유 marker fixture 7건만 정리, 일정 baseline 196·fixture 0·tier Amateur·light 복원
- [x] PROD clean 로그 permission-denied·invalid argument·unknown fields·crash·ANR·overflow·DEV marker 0
- [x] Firebase 배포·uninstall·pm clear·Play·commit·push 0
- 다음 백로그로 자동 이동하지 않는다.

## Personal canonical groups 설계안

### 1. 현재 그룹 구조

- Personal의 canonical 그룹 의미는 아직 “실제 그룹 문서”가 아니라 `trainer_profiles/{uid}.memberDefaultGroupLabel`로 이름을 바꿀 수 있는 가상 기본 그룹 하나다. 앱 내부 식별자는 `__ungrouped__`, 기본 표시값은 `MORE THAN GYM`이다.
- `client_list_page.dart`의 Personal 분기는 owner-scoped `members`만 구독하고, 기본 그룹 label만 profile stream에서 읽는다. `_groupIds`와 `_memberGroupMap`은 비우며 `member_groups`를 조회하지 않는다.
- 고객카드 Personal 분기는 그룹 옵션을 기본 그룹 하나로 제한하고, 기존 Personal 회원의 legacy `groupId`를 읽지 않는다. 신규/수정 canonical 저장도 현재 custom group을 저장하지 않는다.
- `personal_member_card_save_service.dart`에는 default/custom/virtual/legacy/other-owner를 구분하는 normalization 골격이 있으나, 현재 canonical custom ID 집합이 전달되지 않아 custom 선택은 기본 그룹으로 fallback한다.
- `Member` 모델의 `groupId`는 legacy 필드다. 새 Personal 필드와 이름·의미를 섞지 않고 별도 필드로 추가해야 한다.

### 2. legacy 구조와 재사용 금지 범위

- legacy는 root `member_groups/{groupId}`와 member의 `groupId`/`groupName`을 사용한다. owner UID와 `workspaceType`이 그룹 문서에 없고, `group_N` ID·`order`·system group 문서를 사용한다.
- Admin/legacy UI는 root `member_groups` 직접 CRUD, owner 조건 없는 `members.where(groupId == ...)`, client batch write를 포함한다. Personal에 재사용하면 다른 trainer 데이터 노출·수정, Rules 거부, denormalized 이름 불일치 위험이 있다.
- `firestore.rules`의 root `member_groups`는 `isLegacyAdmin()` 전용이며, Personal members의 client create/update/delete는 금지되어 있다. 새 기능은 이 경로와 규칙을 변경해 재활용하지 않는다.
- Admin 기능은 기존 동작을 유지하고, Personal 여부는 현재처럼 non-empty `personalOwnerUid`로 분리한다.

### 3. 추천 canonical path

- custom group: `trainer_profiles/{uid}/personal_groups/{personalGroupId}`
- 장점: owner namespace가 경로에 포함되고, 다른 trainer와 문서 ID가 우연히 같아도 충돌하지 않으며, profile과 lifecycle을 함께 관리하기 쉽다.
- `personalGroupId`는 이름이나 순번을 담지 않는 opaque ID로 한다. create callable이 `uid + idempotencyKey`에서 결정적 ID를 만들어 네트워크 재시도 중복 생성을 막는다.

### 4. 추천 group document schema

- 필수: `name: string`, `normalizedName: string`, `schemaVersion: 1`, `createdAt: server timestamp`, `updatedAt: server timestamp`.
- 1차 제외: `isDefault`, `sortOrder`, 색상, 태그, member count 복제값, owner UID 복제값, groupName member 복제값.
- 삭제를 단일 transaction으로 처리하는 1차안에서는 `state`도 불필요하다. 영향을 받는 회원이 transaction 안전 한도(권장 450명)를 넘으면 쓰기 전에 `failed-precondition`으로 중단하고 별도 chunked-delete 설계를 요구한다.
- 그룹 수는 UI/read 비용과 관리성을 위해 1차 서버 상한을 두되, 값은 제품 정책으로 확정해야 한다. 권장 시작값은 custom 20개이며 Functions와 Flutter에 동일 상수를 둔다.

### 5. 추천 member field

- `members/{memberId}.personalGroupId: string` 하나만 사용한다.
- member에 `groupName`을 복제하지 않는다. 이름은 owner의 `personal_groups` snapshot에서 한 번 읽어 ID→이름 map으로 렌더링한다.
- 기본 그룹은 필드를 저장하지 않는다. custom group으로 이동할 때만 `personalGroupId`를 기록하고 기본 그룹으로 이동하면 `FieldValue.delete()`로 제거한다.
- legacy `groupId`/`groupName`은 읽기·쓰기 모두 Personal 분기에서 계속 무시한다.

### 6. 기본 그룹 null fallback

- 채택한다. `personalGroupId`가 없거나 null/empty이면 `memberDefaultGroupLabel`의 기본 그룹으로 해석한다.
- 존재하지 않는 custom ID는 UI에서 조용히 “정상 custom group”으로 인정하지 않는다. 그룹 snapshot의 server readback이 끝난 뒤에도 ID가 없으면 기본 그룹 fallback과 진단 marker를 적용하고, 실제 정리는 명시적 저장/이동 또는 group delete callable에서만 한다.
- 그룹 snapshot 로딩 전에는 임의로 기본 그룹으로 확정하지 않고 loading 상태를 유지해 순간적인 오분류를 피한다.

### 7. 기본 그룹 document 여부

- **안 A(추천)**: 기본 문서 없음 + `personalGroupId` 부재를 기본으로 해석. migration 0, 현재 profile label/`__ungrouped__` UX 유지, 기본 이름 변경 시 member write 0, 기본 삭제 불가 정책이 단순하다.
- **안 B(비추천)**: 기본 document 생성 + 모든 member에 명시 ID 저장. query는 대칭적이지만 기존 회원 전체 migration, default document bootstrap/복구, profile label과 document 이름의 이중 source of truth가 생긴다.
- 결론: 안 A를 채택하고 `memberDefaultGroupLabel`을 기본 그룹 이름의 유일한 source of truth로 유지한다.

### 8. 기존 회원 migration

- 필요 없다. 기존 회원은 `personalGroupId` 부재 상태 그대로 기본 그룹에 표시한다.
- 배포 직후 회원 검색·최근 등록·회원목록에서 기존 회원이 사라지거나 “그룹 없음”으로 분리되지 않아야 한다.
- custom group으로 실제 이동한 회원만 필드를 갖는다. 기본으로 복귀하면 필드를 삭제한다. 일괄 rewrite와 default ID backfill은 하지 않는다.

### 9. 그룹 생성 UX

- 회원관리 우측 상단 기존 메뉴에서 `회원 추가`와 `그룹 관리`를 제공하고, 현재 chip/필터 구조를 유지한다.
- 그룹 관리 sheet/page에 기본 그룹을 첫 행으로 표시하고 하단에 `+ 새 그룹 만들기`를 둔다. 입력 즉시 trim/공백/길이/중복을 안내하되 서버 callable validation이 최종 기준이다.
- 생성 성공은 callable 응답만이 아니라 새 group document server readback과 owner group snapshot 반영 후 표시한다. 실패 시 입력 sheet와 값은 유지한다.
- 기존 “기본 그룹 이름 변경” shortcut은 한 릴리스 동안 유지하고 그룹 관리 안에도 같은 기능을 제공한 뒤, 사용 로그/UX 확인 후 중복 메뉴 제거를 별도 판단한다.

### 10. 그룹 이름 변경 UX

- 기본 그룹: 기존 `memberDefaultGroupLabel` 변경 흐름을 유지하되 custom group과의 normalized-name 충돌 검사를 서버에 추가한다. 삭제 버튼은 제공하지 않는다.
- custom group: 그룹 관리의 해당 행에서 이름 변경. group document만 갱신하며 member write는 0이다.
- list/card/header가 같은 group stream/helper를 사용해 즉시 갱신되고, offline cache 이후 server readback으로 확정한다.

### 11. 회원 이동 UX

- 고객카드의 `소속 그룹`을 Personal에서도 selector로 제공한다. 기본 그룹 + active custom groups를 같은 순서로 보여준다.
- 회원목록 카드의 기존 빠른 그룹 메뉴도 같은 canonical service를 사용한다. 이동 중에는 해당 member에 중복 요청을 막고, server readback 후 UI를 확정한다.
- 신규 “전체 고객카드”에는 selector를 제공하되 기본값은 기본 그룹이다. Home 빠른등록은 조밀한 UX를 유지해 1차에서는 selector 없이 기본 그룹으로 생성한다.
- 이동은 `personalGroupId`만 변경한다. memberId, schedule, training_logs, 계약서, membership, consent, anniversary/D-DAY, 위젯 연결 데이터는 수정하지 않는다.

### 12. 그룹 삭제 UX

- 빈 custom group: “그룹을 삭제할까요?” 확인 후 삭제.
- 회원이 있는 custom group: owner-scoped count를 표시하고 “삭제하면 ‘현재 기본 그룹명’으로 이동합니다.”를 안내한다. 버튼은 `[취소] [삭제하고 이동]`.
- 기본 그룹은 삭제 UI를 제공하지 않는다. 삭제 진행 중 중복 탭을 막고, callable 완료 + group/member server readback 뒤 목록을 갱신한다.

### 13. 회원이 있는 그룹 삭제 처리

- client batch와 직접 Firestore write는 사용하지 않는다. `deletePersonalGroup` callable의 Firestore transaction에서 owner profile, group document, `trainerId == uid && workspaceType == personal && personalGroupId == target` 회원을 읽고, 각 member의 `personalGroupId`를 삭제한 뒤 group document를 삭제한다.
- transaction은 전부 성공하거나 전부 rollback되어 orphan/부분 이동을 만들지 않는다. 다른 owner member는 query와 개별 identity 검증 양쪽에서 제외한다.
- Firestore transaction write 한도를 고려해 대상 450명 초과 시 쓰기 전 중단한다. 실제 제품이 이 한도를 요구하면 `deleting` 상태 + idempotent chunk 처리 설계를 별도 단계로 도입하며, 1차에서 부분 batch 성공을 허용하지 않는다.

### 14. 정렬 정책

- 1차는 기본 그룹 항상 첫 번째, custom group은 `createdAt ASC`, 동률이면 document ID ASC로 고정한다.
- drag reorder와 `sortOrder`는 넣지 않는다. 현재 chip row와 그룹 관리 목록만 같은 정렬 helper를 사용한다.
- 사용자 순서 변경 요구가 확인되면 2차에서 `sortOrder`와 reorder callable을 별도 추가한다.

### 15. 이름 중복 정책

- 표시값: 앞뒤 trim, 내부 연속 공백 1칸, 길이 2~30자, 빈 값 금지.
- 비교키: Unicode NFC → trim → 내부 공백 축약 → `toLocaleLowerCase('ko-KR')`. 따라서 `VIP`, `vip`, `VIP `는 같은 이름이다.
- 동일 owner 안에서 custom-custom 중복을 금지하고, 현재 기본 그룹 이름과 custom 이름의 중복도 금지한다.
- UI 혼동 방지를 위해 `전체`, 현재 시스템 필터 표시명(휴면/만료)과 동일한 이름도 1차에서는 예약어로 차단한다. 최종 정규화와 중복 판정은 transaction 기반 Functions가 수행한다.

### 16. owner security

- 모든 callable은 `request.auth`를 요구하고 path UID를 client에서 받지 않으며 `request.auth.uid`만 사용한다.
- group CRUD는 `trainer_profiles/{uid}/personal_groups` 안에서만 수행하고 profile의 Personal identity를 검증한다.
- 회원 이동은 대상 member의 `memberId`, `trainerId == uid`, `workspaceType == personal`을 서버에서 확인하고, target group도 동일 UID 하위에 실제 존재하는 active document인지 확인한다.
- 다른 trainer의 group ID를 전달해도 read/list/create/rename/delete/assign이 모두 거부되어야 한다. UID/memberId/groupId 원문은 로그에 남기지 않는다.

### 17. 필요한 Functions

- 새 callable 3개: `createPersonalGroup`, `renamePersonalGroup`, `deletePersonalGroup`.
- `createPersonalGroup`: `idempotencyKey + name`만 허용, 결정적 opaque ID, group 수 상한, 기본/custom 중복 확인, transaction create.
- `renamePersonalGroup`: `personalGroupId + name`만 허용, owner group 존재/중복 확인, document 이름만 transaction update.
- `deletePersonalGroup`: owner-scoped member 이동 + group 삭제를 단일 transaction으로 처리.
- 별도 `assignManagedMemberGroup`은 만들지 않는다. 기존 `createManagedMember`에 optional `personalGroupId`를 추가하고, 기존 `updateManagedMember`에 optional `personalGroupId`와 group-only update 모드를 추가한다. absent=변경 없음, null/empty=기본 그룹으로 이동, string=owner group 존재 검증 후 저장이다.
- `updateManagedMember`의 group-only 모드는 빠른등록 회원처럼 gender/birth가 아직 없는 회원도 분류만 바꿀 수 있어야 하며, 다른 필드 update validation을 우회하지 않도록 payload key 조합을 명시적으로 제한한다.
- `updatePersonalTrainerProfile`의 기본 그룹 이름 변경 transaction에 custom group normalized-name 충돌 검사를 추가한다.

### 18. 필요한 Rules

- 신규 match: `trainer_profiles/{uid}/personal_groups/{personalGroupId}`.
- read: `request.auth != null && request.auth.uid == uid`만 허용. anonymous Personal 세션도 현재 profile/member read 정책과 일치하게 본인 UID면 읽을 수 있다.
- create/update/delete: 모두 `false`. 쓰기는 Admin SDK를 쓰는 canonical callable만 수행한다.
- root `member_groups` rule과 legacy Admin 규칙은 변경하지 않는다. Personal member client write 금지도 유지한다.

### 19. 필요한 indexes

- group 목록 `orderBy(createdAt)`와 `normalizedName ==`은 subcollection 단일 필드 자동 index로 충분하다.
- 현재 회원목록은 owner members 전체를 구독해 client에서 그룹별로 나누므로 기본 그룹(field missing)까지 포함한 별도 query/index가 필요 없다.
- 삭제 및 향후 server-side group filter를 위해 `members(trainerId ASC, workspaceType ASC, personalGroupId ASC)` composite index를 명시적으로 추가하는 안을 권장한다.
- 기본 그룹은 field missing이므로 `personalGroupId == null` query에 의존하지 않는다. owner 전체 query + local partition이 1차 source이다.

### 20. 기존 기능 영향

- 변경 필요: `createManagedMember` optional group 계약, `updateManagedMember` group/full update 계약, Personal 회원목록 group stream/map/filter, 고객카드 selector/readback, `Member` 모델에 별도 `personalGroupId`, 기본 label 중복 검증.
- 변경 없음: `transitionManagedMemberState`(group을 보존), 회원 검색/최근 등록의 owner·createdAt 기준, Home 빠른등록 UI(기본 그룹), schedule, week paste, contracts, training logs, consent, membership, anniversary/D-DAY, widgets, AIFC.
- 휴면/만료 virtual filter가 화면 분류에서 custom group보다 우선하되 `personalGroupId`는 보존해 활성 복귀 시 원래 group으로 돌아오게 한다.
- old app은 새 `personalGroupId`를 무시하고 기존처럼 기본 그룹으로 보므로 서버 선배포가 하위 호환된다. 새 앱은 legacy `groupId/groupName`을 계속 무시한다.

### 21. 단일 그룹 장단점

- 장점: member당 필드 하나, 이동 write 1건, 그룹 필터와 삭제 정책이 단순하고 현재 기본 그룹 fallback과 자연스럽게 호환된다. 이름 변경 때 member rewrite가 없다.
- 단점: 회원을 VIP이면서 재활처럼 동시에 분류할 수 없고, group 이동이 기존 분류를 대체한다. 기본 그룹 missing-field 필터는 server query보다 local partition이 적합하다.
- 1차 요구에는 단일 그룹이 적합하며 복수 의미는 tag 기능으로 분리한다.

### 22. 차후 태그 확장

- group과 tag를 합치지 않는다. group은 단일 주 소속, tag는 복수 속성이라 삭제·정렬·query·UI 의미가 다르다.
- 차후 별도 `trainer_profiles/{uid}/personal_tags/{tagId}`와 bounded `members.personalTagIds: string[]` 또는 규모가 커질 때 edge collection을 설계한다.
- 현재 `personalGroupId`는 그대로 유지되므로 `주 그룹: 오전 회원`, `태그: VIP, 재활`을 migration 없이 추가할 수 있다.

### 23. 구현 단계와 rollback

- 1단계 서버 계약: group model/normalization, 3개 callable, create/update member 확장, profile 기본 이름 중복 검증, Rules/indexes, Functions/Rules Emulator. Blocker는 동시 중복·other-owner·transaction rollback·450명 한도 검증. rollback은 앱 배포 전 이전 Functions/Rules로 복귀하며 생성된 새 필드는 기존 앱에서 무해하게 무시된다.
- 2단계 Flutter DEV: group service/readback, 회원관리 기존 chip/관리 sheet 확장, 고객카드 selector, 신규 회원 selector, 관련 widget/integration tests, 태블릿/Galaxy DEV 3테마. Blocker는 migration 0 표시, stale group fallback, quick member group-only update, legacy 요청 0. rollback은 DEV APK만 이전 버전으로 되돌리고 서버 계약은 하위 호환 상태로 유지한다.
- 3단계 출시: index 준비 완료 확인 → PROD Rules 및 필요한 Functions만 선택 배포 → read-only 확인 → PROD APK 데이터 보존 업데이트 → 가짜 owner fixture CRUD/이동/삭제/원복. 기존 회원 rewrite는 하지 않는다. 하나라도 owner mismatch/permission-denied/orphan이면 PROD APK 진행을 중단한다.

### 24. 예상 변경 파일

- Flutter 제품 코드: `lib/models/member.dart`, 신규 `lib/models/personal_member_group.dart`, 신규 `lib/services/personal_member_group_service.dart`, `lib/services/personal_member_card_save_service.dart`, `lib/services/personal_member_preferences_service.dart`, `lib/pages/client_list_page.dart`, `lib/pages/client_card_page.dart`.
- Functions/보안: 신규 `functions/src/personal_groups.ts`, `functions/src/managed_members.ts`, `functions/src/profile_bootstrap.ts`, `functions/src/index.ts`, `firestore.rules`, `firestore.indexes.json`.
- 테스트: `test/personal_member_card_save_service_test.dart`, 신규 group service/UI tests, `firebase-emulator-tests/managed_members_limit.test.cjs`, 신규 personal groups Rules/Functions Emulator test.
- `binder_card_page.dart`와 root legacy group UI는 Personal 구현에 재사용하지 않고 Admin/legacy 전용으로 유지한다.

### 25. 주요 위험 요소

- legacy `groupId/groupName`을 새 필드로 착각하거나 root `member_groups` direct write를 재사용하는 위험.
- default label과 custom group 이름의 동시 변경에서 중복이 생기는 race. 모든 이름 변경을 transaction으로 검증해야 한다.
- create 응답 유실 재시도에서 group이 중복 생성되는 위험. idempotencyKey 기반 결정적 ID가 필요하다.
- group 삭제가 Firestore 500 write 한도를 넘는 위험. 1차는 450명 초과를 쓰기 전 차단하고 부분 batch를 금지한다.
- group snapshot 로딩 실패를 “기본 그룹”으로 오판해 순간적으로 잘못 표시하는 위험. cache/server 상태를 구분한다.
- `updateManagedMember` group-only 분기가 기존 identity/phone validation을 우회해 다른 필드를 변경하는 위험. allowlist와 payload shape 테스트가 필요하다.
- old/new 앱 혼용 기간에 old app이 custom group을 표시하지 못하는 제한은 데이터 손상은 아니지만 출시 안내와 서버 선배포가 필요하다.
- 새 index 미준비, Rules path 오타, 다른 owner group ID 전달, 삭제 transaction contention은 DEV Emulator와 실제 owner-scoped readback을 통과하기 전 PROD 진행 blocker다.
- light/dark/lululala는 기존 ColorScheme만 사용하고 group별 색상은 1차에서 넣지 않는다.

- 상태: **설계 완료, 구현 미착수**. Dart/Functions/Rules/Firestore/pubspec 변경, migration, DEV/PROD 배포, UI 추가, commit/push는 이번 작업에서 수행하지 않는다.
-
## 2026-08-11 Personal canonical 그룹 + 복수 태그 후속 단계

- 상태: Phase 1 서버 canonical foundation 구현 및 자동 검증 완료. DEV 배포 직전에서 중단했다.
- DEV Functions 선택 배포 대기: `firebase deploy --project more-than-fitness-dev-mft --only "functions:createPersonalGroup,functions:renamePersonalGroup,functions:deletePersonalGroup,functions:createPersonalTag,functions:renamePersonalTag,functions:deletePersonalTag,functions:createManagedMember,functions:updateManagedMember,functions:updatePersonalTrainerProfile"`
- DEV Firestore Rules 선택 배포 대기: `firebase deploy --project more-than-fitness-dev-mft --only firestore:rules`
- Indexes: 추가 배포 불필요. `firestore.indexes.json` 변경 없음.
- 배포 후 필수 확인: 9개 Functions가 `asia-northeast3` ACTIVE인지, Rules만 갱신됐는지, 다른 Functions/Rules 외 리소스가 배포되지 않았는지 확인한다.
- Phase 2 미착수: 회원관리 그룹/태그 관리, 고객카드 단일 그룹·복수 태그 picker, 회원목록 그룹·태그 필터, Amateur 태그 gate, Semi-Pro tag access, light/dark/lululala UI와 Galaxy DEV 검증은 별도 승인 후 진행한다.
- 호환성: 기존 회원은 `personalGroupId` 부재 시 기본 표시명으로 유지한다. migration, default group document, legacy `member_groups`, legacy `groupId/groupName` write는 계속 금지한다.
- 대규모 owner의 그룹/태그 삭제가 499명 초과 cleanup을 요구하면 부분 batch로 우회하지 않는다. 별도 idempotent chunk 설계 승인을 받아야 한다.

## 2026-08-11 Personal canonical 그룹 + 복수 태그 Phase 1 DEV 검증 완료

- 상태: **Phase 1 DEV 배포·실서버 검증 완료**. 신규 6개 taxonomy 함수와 변경 3개 managed/profile 함수가 `more-than-fitness-dev-mft`, `asia-northeast3`, `ACTIVE`이며 owner-read/client-write-deny Rules도 DEV에 반영됐다.
- 실서버 완료: Amateur 그룹 CRUD/assignment/default fallback, Semi-Pro 태그 CRUD/복수 assignment, 사용 중 taxonomy 원자 cleanup, 기본 표시명 양방향 중복 차단, 빠른등록/full update 호환 smoke, legacy 신규 write 0을 확인했다.
- 원복 완료: fixture 회원·그룹·태그 0, 최종 tier `Beginner`, managed member 0, owner member 0, owner schedule 0이며 검증 전 lifetime qualified count와 taxonomy/legacy count를 보존했다. 정상 DEV 앱과 기존 Auth 세션도 데이터 보존 복원했다.
- owner isolation 근거: 다른 owner 실서버 fixture는 만들지 않았고 taxonomy Emulator 25개와 managed-member Emulator 62개를 source of truth로 사용한다. 실서버에서는 owner read와 client direct write 차단을 확인했다.
- 다음 단계: Phase 2 회원관리 그룹/태그 관리 UI, 고객카드 picker, 회원목록 필터, 3테마 Galaxy DEV 검증은 **미착수**다. 별도 사용자 승인 전 자동 이동하지 않는다.
- 계속 금지: PROD 배포·앱 작업, migration, default group document, legacy `member_groups`/`groupId`/`groupName` 신규 write, 499명 초과 delete 우회, commit, push.
## 2026-08-12 Personal taxonomy Phase 2 UI 후속 검증

- 구현 상태: canonical 그룹·복수 태그 Phase 2 제품 코드와 자동 검증은 완료했다. Functions/Rules/indexes/Storage/Hosting 변경·추가 배포는 없다.
- Galaxy DEV 직접 완료: 그룹/태그 관리 진입, 그룹 2개 create/rename/delete, 태그 3개 create/rename/delete, Amateur 태그 gate, 그룹/태그 count, 단일 태그 필터, 그룹+태그 결합 결과, 재실행, fixture 삭제와 서버 baseline readback.
- 출시 전 남은 실기기 확인: 개인정보를 노출하지 않는 전용 fixture 회원으로 고객카드 `personalGroupId` 저장·기본 그룹 복귀·복수 `personalTagIds` 저장/일부 제거·재진입, populated group delete 후 기본 그룹 이동, used tag delete 후 chip 제거를 Galaxy DEV에서 직접 확인한다.
- Phase 3/PROD 판단: 위 실기기 assignment·cleanup 항목이 미확정이므로 자동으로 Phase 3 또는 PROD 반영으로 이동하지 않는다. 별도 승인 후 전용 fixture로만 마무리한다.

## 2026-08-12 Personal taxonomy Phase 2 fixture 마무리 결과

- 완료: 전용 DEV fixture 회원으로 `personalGroupId` 저장·재진입·재실행, 기본 그룹 fallback, `personalTagIds` 2개/3개 저장과 일부 해제, 태그 및 group+tag 필터를 Galaxy DEV에서 확인했다.
- 완료: used-tag 삭제 시 taxonomy document와 member 배열의 원자 cleanup, populated group 삭제 시 기본 그룹 이동, stale chip/group 0과 재실행 유지까지 실기기에서 확인했다.
- 수정 완료: membership 등록 필드가 없는 canonical 회원을 `기간 미등록`으로 복원하고, 기존 태그가 실제 변경된 경우에만 `tagsProvided` patch를 보내도록 고객카드 공통 저장 흐름을 최소 수정했다.
- 원복 완료: fixture member/group/tag 0, 회원 6, 일정 11, 레슨일지 0, tier Amateur, 기본 그룹 `MORE THAN GYM`, light/brandLight. 실회원 변경 0이다.
- 검증 완료: 관련 Flutter 50개, 전체 Flutter 4 shard, taxonomy Emulator 25개, managed-member Emulator 62개, 변경 범위 analyze error 0, `git diff --check`, DEV APK, 최종 clean 로그가 통과했다.
- Amateur gate: 직전 동일 Galaxy Phase 2에서 중앙 Semi-Pro gate와 tag write 0을 확인했고 이번 실행에서 Amateur local-only fixture 복원을 다시 확인했다. fixture cleanup 후 gate sheet 신규 캡처는 만들지 않았다.
- Phase 3/PROD: Phase 2의 assignment·cleanup blocker는 해소됐다. Phase 3 PROD 진행은 가능하지만 별도 사용자 승인 전에는 시작하지 않는다. PROD 작업·Firebase 추가 배포·commit·push는 계속 0건이다.
## 2026-08-12 Personal taxonomy Phase 2 태그 관리 고정 접근 완료

- 완료: 회원관리 태그 필터의 관리 톱니바퀴를 수평 스크롤 밖에 고정하고 `전체 태그` 이후 실제 태그만 한 줄 수평 스크롤하도록 변경했다.
- 완료: 고객카드 태그 제목 오른쪽에 관리 톱니바퀴를 고정하고 `[+ 추가]` 및 선택 태그를 한 줄 수평 스크롤로 유지했다. 20개 태그·320/360/384/411dp 회귀는 widget test로 세로 확장 0을 확인했다.
- 완료: 태그 관리는 AIFC chatbot BottomSheet로 전환했고 create/rename/delete와 즉시 refresh를 기존 canonical callable/stream으로 유지했다. 그룹 관리는 기존 page를 유지한다.
- 완료: Galaxy DEV Semi-Pro fixture에서 태그 10개, 회원 태그 5개, 세 테마 고정 gear/수평 이동, chatbot CRUD refresh를 확인했다. Amateur 복원 후 중앙 Semi-Pro gate와 tag write 0을 확인했다.
- 완료: fixture member/tag 0, tier Amateur, 회원 6, 일정 11, 레슨일지 0, custom group/tag 0, 기본 그룹 `MORE THAN GYM`, light/brandLight baseline을 복원했다.
- 남은 blocker 없음. Phase 3 PROD 반영은 별도 사용자 승인 전 시작하지 않는다.

## 2026-08-12 Personal taxonomy empty-state 분류 바 완료

- 완료: 회원관리 Personal 상단을 고정 분류 관리 톱니바퀴와 한 줄 horizontal strip으로 통합하고, empty 상태에 실제 기본 그룹 + 약한 group/tag 예시 + 마지막 `전체`를 표시한다.
- 완료: 예시 칩은 실제 filter/query/write에 참여하지 않으며, 실제 custom group/tag가 생기면 해당 유형의 예시가 실제 데이터로 교체되고 중복되지 않는다. 고객카드에는 예시를 표시하지 않는다.
- 완료: example group 안내와 기존 그룹 관리 연결, example tag의 중앙 Semi-Pro gate 및 기존 AIFC 태그 관리 연결, 10/20개 고정 높이·gear 고정·3테마·Galaxy DEV 수평 swipe를 확인했다.
- 자동 검증 완료: 관련 Flutter 52개, 전체 Flutter 648개, taxonomy Emulator 25개, analyze error 0, `git diff --check`, DEV APK. 정상 DEV 앱 복원과 최종 안전 로그도 통과했다.
- 실기기 확인 구분: Amateur gate는 이번 Galaxy에서 직접 확인했다. Semi-Pro AIFC 태그 관리 시트는 기존 동일 manager의 직전 실기기 통과 결과와 이번 정적/자동 연결 검증을 유지하며, 개인정보 보호를 위해 이번 clean 구간에서 실데이터를 재생성하거나 전체 hierarchy를 저장하지 않았다.
- 남은 기능 blocker는 없다. PROD 반영은 별도 사용자 승인 전 시작하지 않는다.

## 2026-08-12 Personal taxonomy 상태 분류 후속 보정

- 코드 완료: Personal 휴면·만료를 group pseudo item에서 분리해 독립 상태 행으로 복원했다. `managementState` 우선/legacy `memberStatus` fallback, 상태·그룹·태그·검색 AND, taxonomy strip 한 줄 유지, canonical 상태 callable/readback을 적용했다.
- 정책 유지: membership 종료일 경고와 명시 회원 상태는 별개이며 새 시간 기반 자동 휴면·만료 규칙은 만들지 않았다. 상태 변경에 따른 group/tag write는 0건이다.
- 테마 완료: 그룹 관리 page는 공통 branded header와 3테마 token을 사용하며 별도 page navigation을 유지한다. 태그 관리는 기존 AIFC BottomSheet를 유지한다.
- 자동 검증 완료: 관련 Flutter 130개, 전체 Flutter 658개, taxonomy Emulator 25개, managed-member Emulator 62개, analyze error 0, `git diff --check`, DEV APK 통과.
- 실기기 확인: Galaxy DEV에서 상태 entry/count, taxonomy 한 줄, 그룹 page light CRUD, Amateur tag gate, cleanup과 안전 로그를 확인했다. fixture 생성은 기존 Amateur 한도에서 `failed-precondition`이 세 번 반복되어 중단했으므로 실제 상태+그룹+태그+검색 AND와 그룹 page/tag sheet dark·lululala 실데이터 렌더는 미확정이다. 자동 widget test는 통과했지만 실기기 확인으로 대체 기록하지 않는다.
- PROD 반영은 시작하지 않는다. 실기기 미확정 항목을 다시 검증하려면 기존 회원을 건드리지 않는 별도 DEV fixture 여유 또는 승인된 최소 tier/capacity 조건이 필요하다.

## 2026-08-12 Personal taxonomy 통합 한 줄 필터 완료

- 완료: 별도 상태 행을 제거하고 고정 gear 뒤 단일 horizontal strip에 기본/실제/예시 group, tag, `전체`, `휴면`, `만료`를 배치했다. pinned filter 높이는 209px에서 174px로 감소했고 strip 자체 높이는 32px로 유지된다.
- 완료: group/tag/status 내부 타입과 state는 분리된 채 deterministic AND를 유지한다. `[전체]`는 세 분류 축만 reset하고 검색은 유지한다. status mapping, membership 종료일 경고, taxonomy schema/write 계약은 변경하지 않았다.
- 자동 검증 완료: 관련 Flutter 126개, 최종 통합 위젯 26개, 전체 Flutter 659개, taxonomy Emulator 25개, managed-member Emulator 62개, analyze error 0, `git diff --check`, DEV APK 통과.
- Galaxy DEV 확인: 데이터 보존 업데이트 후 별도 상태 행 제거, 단일 32px horizontal strip, gear 고정, 동일 Y 구간의 `전체/휴면/만료`, light theme와 clean 로그 0을 확인했다. 상태 chip 실제 선택 조합은 swipe 자동화가 끝 위치를 반복 재현하지 못해 자동 테스트 확정 항목으로 구분한다.
- PROD/Firebase/commit/push는 0건이다. PROD 반영은 별도 사용자 승인 전 시작하지 않는다.
## 2026-08-13 Personal taxonomy PROD 전 최종 UI polish 완료

- 완료: 그룹 관리 기본 `AppBar`를 공통 브랜드 gradient/token 기반 헤더로 교체하고 본문 canonical 동작은 유지했다. Galaxy dark에서 발견한 헤더 전경 대비 결함까지 수정했으며 light/dark/lululala 실제 화면에서 header/card/CTA 가독성을 확인했다.
- 완료: taxonomy strip의 순서·32px 높이·gear 고정·AND/reset semantics는 유지하고 group/tag/all/dormant/expired 역할별 theme token과 선택 fill+border+weight를 보정했다. 320/360/384/411dp와 동시 selected는 widget test로 통과했다.
- 완료: AIFC 태그 관리 sheet를 Galaxy DEV 3테마에서 확인했고 light 입력 시트의 키보드/focus/취소까지 실제 확인했다. custom tag 0 상태를 유지했으므로 rename/delete/used-tag confirmation의 이번 실데이터 재현은 수행하지 않았으며 자동 계약 검증 결과와 구분한다.
- 검증 완료: 관련 Flutter 50개, 전체 Flutter 663개, taxonomy Emulator 25개, managed-member Emulator 62개, 변경 범위 analyze issue 0, `git diff --check`, DEV APK, `adb install -r`, 최종 안전 로그를 통과했다.
- 원복 완료: local tier fixture는 `서버 실제 등급`으로 해제했고 theme `light`, widget `brandLight`를 확인했다. 서버 write/fixture 생성 0건이며 서버 전체 count는 별도 probe하지 않아 기존 수치를 추측 갱신하지 않는다.
- 판정: 현재 확인 범위에서 Personal taxonomy PROD 전 UI blocker는 없다. Phase 3 PROD 반영은 별도 사용자 승인 전 시작하지 않는다. PROD/Firebase/commit/push는 0건이다.

## 2026-08-16 Personal taxonomy Phase 3 PROD 삭제 blocker

- 완료: Amateur 빠른등록의 빈 `personalTagIds` 전송을 제거해 canonical 회원 생성, 서버 readback, 회원관리 표시를 복구했다. PROD fixture에서 custom group assignment 저장과 populated group 삭제 후 `MORE THAN GYM` fallback까지 통과했다.
- blocker: 현재 PROD에 배포된 `transitionManagedMemberState`는 삭제 시 `managementState=deleted`만 기록하고 클라이언트가 canonical 삭제 완료로 검증하는 `isDeleted`, `deleteStatus`, `deletedSource` marker를 기록하지 않는다. callable은 HTTP 200이어도 owner snapshot 검증과 목록 필터가 완료되지 않아 삭제 UX가 실패한다.
- 필요한 승인 작업: 로컬에서 자동 검증된 현재 함수 코드와 export를 재확인한 뒤 PROD에 `transitionManagedMemberState` 한 개만 선택 배포한다. 예상 명령은 `firebase deploy --project more-than-fitness-f6adb --only "functions:transitionManagedMemberState"`이다. 승인 전 배포하지 않는다.
- 재검증 기준: 개인정보가 아닌 fixture 1건을 canonical 생성하고 고객카드 삭제 UI로 삭제한 뒤 `managementState=deleted`, `isDeleted=true`, delete marker, owner snapshot, 회원관리 목록 제거, 재실행 유지, count 원복을 모두 확인한다.
- 원복 완료: 이번 `P3MEMBER` fixture와 `P3GROUP`은 제거됐고 PROD baseline은 owner member 2, active member 2, schedule 236, training log 0, custom group/tag 0, tier Amateur, 기본 그룹 `MORE THAN GYM`이다. 실회원 변경은 0건이다.
- Phase 3는 blocker 해소 전 완료 처리하지 않는다. Rules/indexes/Storage/Hosting, 다른 Functions, Play, commit, push 작업은 금지 상태를 유지한다.

## 2026-08-16 Personal taxonomy Phase 3 PROD 완료

- 해소: PROD `transitionManagedMemberState` 한 함수만 선택 배포해 최신 deletion marker 계약을 반영했다. `asia-northeast3 / ACTIVE`, 배포 CLI exit 0을 확인했다.
- 실검증 완료: 개인정보 없는 PROD fixture를 canonical 생성한 뒤 고객카드 삭제 UI로 삭제했다. 함수 HTTP 200, `managementState=deleted`, `isDeleted=true`, `deleteStatus=pending_delete`, `deletedSource=managed_member_function`, 삭제 시각 2종, active 목록 제외와 회원관리 `총 2명` 복원을 확인했다.
- cleanup 완료: deleted fixture 문서 한 건만 안전 조건으로 물리 제거했고 fixture 검색 0, 기존 회원 2, 일정 236, 레슨일지 0, group/tag 0, tier Amateur, 기본 그룹 fallback `MORE THAN GYM` baseline을 유지했다.
- 검증 완료: 관련 Flutter 38개, managed-member Emulator 62개, taxonomy Emulator 25개, Functions lint/build, `git diff --check`, 최종 PROD PID 안전 로그를 통과했다.
- 판정: Personal taxonomy Phase 3 PROD blocker는 종료한다. 다른 Functions/Rules/indexes/Storage/Hosting/client APK/Play/commit/push는 작업하지 않았다. 다음 백로그로 자동 이동하지 않는다.
## 2026-08-16 일정 형태 변경 후 저장 실패
- [x] DEV root cause 수정: 빈 schedule source ID에 owner prefix를 붙여 `${ownerUid}--` delete를 생성하던 `homeScheduleScopedDocumentId` 회귀를 차단했다.
- [x] 자동 회귀: same-type 3종, type transition 8종, 관련 Flutter 78개, 전체 Flutter 675개, Personal schedule Emulator 27개, analyze issue 0, diff check, DEV APK 통과.
- [x] Galaxy DEV: PT -> 일정 -> 교육 -> PT 동일 document ID update, 형태+시간 move, 형태+요일 move, server verify, 중복 0을 확인했다.
- [x] fixture 원복: 테스트 일정 삭제 후 baseline 11건, 임시 로컬 형태 `EVENT`/`EDU` 제거, clean safety log 0.
- [x] PROD 반영: `1.0.4 (12)` release APK를 기존 인증서 일치 확인 후 `adb install -r`로 데이터 보존 업데이트했다. PT -> 일정 -> 교육 -> PT, 형태+시간, 형태+요일, 동일 형태 메모 저장·재진입, 단일 카드 유지와 generic error/permission-denied 0을 확인했다.
- [x] release 재시작 blocker: R8가 `flutter_local_notifications` Gson `TypeToken` generic signature를 제거해 `ScheduledNotificationBootReceiver`가 crash하던 문제를 공식 plugin release 규칙으로 보정했다. 재빌드·재설치 후 MainActivity 유지, receiver crash 0, 최종 clean 안전 로그 0을 확인했다.
- [x] fixture/baseline: PROD 검증 fixture 일정만 canonical 삭제했고 fixture 카드 0, 기존 회원 진행값 `4 / 30`, 기존 주간 스케줄, Auth session, light theme를 유지했다. 민감한 PROD 문서 ID와 별도 서버 총량 probe는 기록하지 않았다.
- [x] 판정: 일정 형태 변경 저장 hotfix의 PROD 반영을 완료했다. Firebase 배포, migration, Play Store, commit, push는 실행하지 않았으며 다음 백로그로 이동하지 않는다.

## 2026-08-19 DEV 앱 부팅·홈 Drawer 성능 개선 완료

- [x] 기존 anonymous profile은 server read를 우선하고 누락 시에만 bootstrap한다. tier reconcile, widget interactivity/sync, notification/timezone 초기화는 첫 frame 이후로 이동했으며 Auth/Firebase/workspace/profile 안전 검증은 유지한다.
- [x] Drawer neon animation 중 전체 본문 재빌드를 제거하고 장식 완료 시간을 500ms에서 300ms로 줄였다. 회원권계약서 설명은 `회원권 계약서 작성 및 운영 지원`으로 변경했으며 gate/navigation은 유지한다.
- [x] 전체 Flutter 680개, 전체 analyze error 0, `git diff --check`, DEV APK, Galaxy DEV 데이터 보존 설치와 기능·안전 로그를 통과했다.
- [x] cold start 평균은 3103ms에서 2982ms, 최악값은 3855ms에서 3283ms로 개선됐다. warm start는 220ms에서 244ms로 개선되지 않아 수치 그대로 기록했다. Hamburger tap-to-first-frame은 screencap 해상도 한계로 정확한 ms를 확정하지 않고 500→300ms animation contract와 실기기 open/close 결과로 구분했다.
- [ ] PROD 반영은 가능 후보이나 별도 사용자 승인 전 build/install/deploy를 시작하지 않는다. Firebase·PROD·commit/push 작업은 0건이다.

## 2026-08-19 앱 부팅·홈 Drawer 성능 개선 PROD 반영 완료

- [x] PROD `1.0.4 (13)` Release APK를 기존 signing fingerprint 일치 확인 후 `adb install -r`로 데이터 보존 업데이트했다. UID, dataDir, firstInstallTime, Auth session, DEV package를 유지했다.
- [x] PROD Release cold Home-route 5회 `808/909.6/967ms`, warm 10회 `238/263.4/374ms`를 별도 기록했다. DEV debug와 직접 비교하지 않았고 동일 PROD 사전 baseline이 없는 warm은 개선으로 판정하지 않았다.
- [x] Drawer 300ms, animation frame별 본문 rebuild 제거, light/dark/lululala 반복 open/close, 정확한 회원권계약서 설명과 기존 계약 gate를 확인하고 light로 복원했다.
- [x] 관련 Flutter 36개, 전체 Flutter 680개, analyze error 0, `git diff --check`, PROD Release build, clean restart와 PID 안전 로그를 통과했다. Firebase 배포·migration·Play 작업·commit·push는 0건이다.
- [x] PROD startup + Drawer 성능 hotfix 반영 완료. 다음 단계는 별도 승인 후 Play Store 출시 준비이며 자동 진행하지 않는다.

## 2026-08-19 Home Drawer 주요 기능 설명 통일 완료

- [x] 고객카드, 레슨계약서, 인사이트 설명을 회원권계약서와 같은 고정형 운영지원 문체로 통일했다.
- [x] 제목·아이콘·순서·콜백과 중앙 feature gate/navigation은 유지했다.
- [x] 관련 Flutter 5개, 전체 Flutter 4개 순차 shard, 변경 범위 analyze 신규 오류·경고 0, `git diff --check`, DEV Debug APK를 통과했다.
- [x] 실기기 설치, PROD/Firebase, commit/push는 수행하지 않았으며 다음 백로그로 이동하지 않는다.

## 2026-08-19 Play Store 사전점검 1 완료

- [x] DEV/PROD entrypoint는 공통 `runMtfApp`을 사용하며 최근 startup, Drawer, schedule, taxonomy 변경이 PROD 공통 source에 포함됨을 확인했다.
- [x] PROD Release APK dry-run은 `com.example.mtf_app`, `1.0.4 (13)`, 앱 이름 `모어댄`, non-debuggable, PROD Firebase identity로 통과했다. 실제 prod R8 configuration에도 Gson `TypeToken` keep rule이 포함된다.
- [x] 관련 Flutter 170개, 전체 Flutter 679개, analyze error 0, `git diff --check`, PROD Release APK build를 통과했다.
- [ ] release checkpoint 전에 untracked taxonomy 핵심 UI와 PROD manifest/icon 리소스를 allowlist로 명시 반영해야 한다.
- [ ] Play용 정식 signing 구성과 AAB 생성·검증은 별도 승인 단계다. 현재 release는 debug signing slot이므로 Play 출시 산출물로 확정하지 않는다.
- [x] APK 설치, Firebase, Play Store, signing 변경, commit/push는 수행하지 않았다. 다음 단계로 자동 이동하지 않는다.

## 2026-08-20 Play Store 출시 준비 Phase 1 완료

- [x] release checkpoint allowlist를 tracked modified 84개 + 명시적 untracked 제품/backend/test 50개 = 총 134개로 확정했다. untracked 제외 50개는 문서/증적·prompt·telemetry·zip·probe·중첩 0바이트 font이며 삭제하지 않았다.
- [x] 모든 untracked import target, PROD manifest/icon/resource, widget resource, taxonomy Functions source, pubspec asset, R8 rule, PROD Firebase source가 allowlist에 포함되어 working-tree release 재현성 blocker를 해소했다.
- [x] repo 밖 `C:\Users\morethan\.android\more_than_upload.jks`에 Play upload key를 생성하고 ignored `android/key.properties`로 secret을 분리했다. 공개 certificate PEM export도 repo 밖에 생성했으며 secret/private key는 로그·Git에 포함하지 않았다.
- [x] 기본 release는 upload key, 명시적 legacy local PROD APK만 기존 debug key를 사용하도록 분리했다. legacy flag의 AAB build는 차단하며 DEV debug 흐름은 유지한다.
- [x] upload certificate SHA-1/SHA-256과 기존 Galaxy debug signer가 다름을 확인했다. 새 Play release APK/AAB를 기존 Galaxy PROD 위에 설치하지 않았다.
- [x] 명시적 `lib/main_prod.dart`로 PROD APK/AAB를 빌드했다. package `com.example.mtf_app`, `1.0.4 (13)`, min/target 24/36, non-debuggable, PROD marker 포함/DEV marker 0, PROD icon과 3개 widget provider, R8 `TypeToken`/`Signature` keep을 확인했다.
- [x] 관련 Flutter 289개, 전체 Flutter 679개, analyze error 0(기존 warning 239/info 927), `git diff --check`, APK/AAB signing·build를 통과했다.
- [x] release checkpoint allowlist 134개만 명시적으로 stage했고 staged 경로 일치, secret/generated/probe 0, cached diff check, analyze error 0, upload-signed PROD AAB 재빌드를 통과했다. 이 기록을 포함한 단일 checkpoint commit으로 마무리하며 push하지 않는다.
- [ ] checkpoint 이후 Play Console 신규 앱 생성, Play App Signing 활성화, app-signing certificate 확인, AAB Internal Testing 업로드는 별도 승인 후 진행한다. 현재 anonymous/email Auth에는 SHA가 즉시 필요하지 않으며 Google Sign-In/App Check 활성화 시 Play app-signing SHA를 Firebase/Google Console에 등록한다.
- [x] Firebase/PROD data/Galaxy/Play upload/commit/push 작업은 0건이다. 다음 단계로 자동 이동하지 않는다.

## 2026-08-26 신규 회원 canonical 저장 회귀

- [x] root cause 수정: full 신규 create에서 빠진 `membershipGrade`, canonical nested `membership`, `anniversaryDate`, `anniversaryLabel`과 update의 `membershipGrade`를 Flutter/Functions 계약에 추가했다.
- [x] 저장 성공 검증 강화: callable 성공만이 아니라 server canonical readback과 owner snapshot에서 등급·회원권·D-DAY·taxonomy까지 확인한다. quick-register와 과거 호출은 선택 필드 생략 호환성을 유지한다.
- [x] 고객리스트 표기: 회원권 잔여일을 `회원권-n`, 당일 `회원권-0`, 종료 후 `만료`로 표시하고 `회원권+N`은 제거했다. 별도 D-DAY 계산/표기는 유지한다. 320/360/384/411dp 긴 이름 조합 overflow 0 테스트를 추가했다.
- [x] 자동 검증: 관련 Flutter 70개, 전체 Flutter 685개, managed-member Emulator 66개, taxonomy Emulator 25개, Functions lint/build, analyze error 0, `git diff --check`, DEV APK 통과.
- [x] DEV 선택 배포: `createManagedMember`, `updateManagedMember`만 `more-than-fitness-dev-mft`에 배포했다. 두 함수의 `asia-northeast3` successful update를 확인했고 cleanup policy 경고 외 배포 오류는 없었다. Rules/indexes/Storage/Hosting과 다른 함수는 배포하지 않았다.
- [x] Galaxy DEV: GOLD+lesson+membership+D-DAY create와 SILVER+120일 membership+D-DAY update를 canonical callable, server readback, owner snapshot으로 통과했다. 고객리스트 `회원권-119`, 고객카드 재진입, 앱 재시작 유지도 확인했다.
- [x] fixture cleanup: canonical soft-delete 후 active 목록 fixture 0, managed count 2, 일정 11, 레슨일지 0, tier Amateur, 기본 그룹 `MORE THAN GYM`, widget `brandLight`를 복원했다. soft-delete tombstone은 기존 보존 정책에 따라 owner 전체 문서에 남는다.
- [x] DEV 회원 저장 blocker 해소. PROD/Play Store 반영은 별도 승인 전 시작하지 않는다.
- [x] PROD/Play Store/Firebase PROD/실회원/migration/commit/push 작업은 0건이다. 다음 백로그로 자동 이동하지 않는다.

## 2026-08-26 PROD 신규 회원 저장 계정 연결 gate

- [x] 실기기 8단계 trace로 `createManagedMember`의 `failed-precondition / account_link_required`를 확정했다. 로컬 검증·전화번호 검증은 통과했고 callable 실패 뒤 readback/snapshot/write는 진행되지 않았다.
- [x] `BRONZE`, 레슨, 회원권 입력과 현재 active 회원 8명은 원인에서 제외했다. 실제 기준은 익명 계정의 누적 유효 회원 10명이며 11번째 생성부터 계정 연결이 필요하다.
- [x] 고객카드 저장 안내가 계정 연결 필요 사유와 마이페이지 경로, 입력값 보존·재시도를 명시하도록 최소 수정하고 관련 Flutter 30개, diff check, PROD APK build/sign/install을 통과했다.
- [ ] 사용자가 기존 UID 유지 이메일 계정 연결을 완료한 뒤 같은 고객카드에서 재시도하고 callable, canonical readback, owner snapshot, 중복 생성 0을 확인한다.
- [ ] 위 재검증 전에는 PROD 신규 회원 저장 blocker를 종료하지 않는다. Firebase 배포·정책 완화·누적 count 조작·commit/push는 금지한다.

## 2026-08-28 계정 연결 Phase 2

- [x] 이메일 credential 연결과 Firebase 이메일 인증을 별도 단계로 유지했다. 연결 성공 뒤 사용자가 인증메일 발송 또는 나중에를 선택하며 SMTP·자체 인증코드는 만들지 않았다.
- [x] MyPage에 마스킹 이메일, 미인증/인증 완료 상태, 인증메일 재발송, `reload()` 기반 인증 확인을 추가했다. Galaxy DEV에서 실제 메일 인증 뒤 `emailVerified=true`를 확인했다.
- [x] 미인증 상태에서도 기존 정책대로 canonical 회원 저장이 가능하고, 인증·앱 재실행 뒤에도 동일 owner의 회원/일정/tier가 유지됨을 확인했다. 이메일 인증을 새 저장 gate로 만들지 않았다.
- [x] 중앙 dialog의 이메일 primary·소셜 secondary 구조, social disabled/준비 중 상태, 3테마·320/360/384/411dp·키보드·validation·scroll 회귀를 자동 테스트로 확인했다.
- [x] Google은 SDK/OAuth client/DEV provider/SHA가 없는 구조적 미구현, Kakao/Naver는 SDK·OAuth redirect·custom-token backend가 없는 미구현 상태로 분류했다. 눌러도 동작하지 않는 활성 UI는 노출하지 않는다.
- [x] 관련 Flutter 84개, 전체 Flutter 740개, managed-member Emulator 67개, taxonomy Emulator 25개, Functions lint/build, analyze error 0, diff check, DEV APK와 Galaxy DEV 검증을 통과했다.
- [ ] Google 실제 연결은 `google_sign_in` 의존성 승인, DEV/PROD별 Firebase Google provider·OAuth client·SHA 구성, credential collision UX 설계 후 별도 Phase에서 진행한다.
- [ ] Kakao/Naver 실제 연결은 공식 SDK/redirect와 owner UID 보존 custom-token backend 설계를 별도 승인 후 진행한다. 이번 Phase에서는 구현하지 않는다.
- [ ] 연결 이메일 변경은 재인증·보안 정책을 포함한 별도 backlog로 유지한다.
- [x] PROD Firebase/Auth/앱, Play Store, Firebase 배포, commit/push 작업은 0건이다. 다음 기능으로 자동 이동하지 않는다.

## 2026-08-28 계정 연결 Phase 3 Google

- [x] DEV Google provider 활성화, DEV debug SHA-1/SHA-256 등록, 최신 DEV Firebase Android config 반영을 완료했다. Email/Password와 Anonymous provider는 유지했다.
- [x] Galaxy DEV에서 기존 사용자에 Google credential을 `linkWithCredential`로 연결했다. 연결 직후와 앱 재시작 후 identity hash 동일, password+google provider 2개, tier Amateur, 회원 6, 일정 11, 레슨일지 0, managed count 6을 확인했다.
- [x] PROD Google provider와 현재 legacy local PROD signer SHA를 올바른 PROD Android 앱에 설정하고 최신 PROD Firebase config를 반영했다. PROD 실제 사용자 연결·데이터 write·앱 조작은 하지 않았다.
- [ ] Play Store 설치본에서 Google 로그인을 사용하기 전에 Play App Signing 인증서 SHA-1/SHA-256을 Firebase PROD Android 앱에 추가한다. Play upload key SHA를 런타임 signer로 대신 등록하지 않는다.
- [ ] Kakao/Naver는 SDK·OAuth redirect·provider token 검증·Firebase custom-token backend와 UID 보존 연결 정책을 별도 설계/승인한 뒤 구현한다. 현재는 disabled `준비 중` 상태를 유지한다.
- [x] 관련 Flutter 127개, 전체 Flutter 749개, managed-member Emulator 67개, taxonomy Emulator 25개, Functions lint/build, analyze error 0, diff check, DEV Debug/R8 APK, Galaxy DEV 안전 로그를 통과했다.
- [x] PROD 실제 계정 연결, Firebase deploy, Rules/indexes/Storage/Hosting, Play Store, commit, push는 0건이다. 다음 단계로 자동 이동하지 않는다.

## 2026-08-31 MORE DAY·동의·동일 이름 일정 연결

- [x] MORE DAY가 범용 날짜 picker의 `lastDate=오늘`을 상속하던 회귀를 수정해 해당 picker만 미래 10년까지 허용했다.
- [x] 개인정보 동의 snapshot listener 오류를 비동기 미처리 예외로 남기지 않고 제어된 실패로 처리하며, 실패 시 화면·재시도 상태를 유지하도록 보강했다.
- [x] 같은 주의 동일 이름·미연결 일정을 기본 체크 목록으로 제안하고 선택분만 owner-scoped transaction으로 함께 연결하는 시트를 추가했다.
- [x] 관련 Flutter 47개, Home 회귀 32개, 전체 Flutter 755개, Personal schedule Emulator 27개, analyze error 0, `git diff --check`, DEV APK가 통과했다.
- [ ] 최신 DEV APK를 데이터 보존 설치한 뒤 MORE DAY 미래 선택, 동의 실패/재시도, 동일 이름 일정 선택 연결을 DEV fixture로 실기기 검증한다.
- [ ] PROD `updateManagedMemberConsent` 배포 상태와 Firestore `permission-denied` 원인을 별도 승인 후 감사한다. PROD 동의 저장은 현재 미통과이며 함수/Rules 배포를 추정 실행하지 않는다.
- [ ] permission-denied 중단 때문에 남은 검증용 PROD 회원 1건을 승인된 canonical 삭제 경로로 안전하게 정리한다.
- [x] Firebase 배포, PROD 빌드·설치, commit, push는 수행하지 않았다. 다음 작업으로 자동 이동하지 않는다.

## 2026-08-31 동일 이름 일정 연결 DEV 실검증·PROD 동의 감사

- [x] Galaxy DEV에서 같은 주 동일 이름·미연결 후보 시트 표시와 기본 체크를 확인했다.
- [x] 일부 선택, 전부 해제, 전부 선택을 각각 canonical server readback으로 확인했다. 현재 일정 항상 연결, 다음 주·다른 이름 제외, 기연결 일정 보호, 앱 재시작 유지가 통과했다.
- [x] 시스템 뒤로가기 취소 시 현재 일정 포함 연결 write 0인 현재 semantics를 실기기와 readback으로 확인했다.
- [x] 현재 이름 정규화 정책과 light/dark/lululala·320/360/384/411dp 회귀 테스트를 보강했다.
- [x] 이번 DEV marker 회원·일정을 전부 정리하고 actual tier Amateur, 회원 6, 일정 11, 레슨일지 0, managed count 6 baseline을 복원했다. 최종 DEV PID 안전 로그는 이상 0건이다.
- [x] PROD read-only 감사에서 Firestore Rules가 로컬과 일치하고 잔여 fixture owner/workspace/path가 정상임을 확인했다.
- [ ] PROD `updateManagedMemberConsent`가 미배포이므로 동의 저장은 계속 미통과다. 별도 승인 후 해당 함수 1개만 선택 배포하고 실제 동의 저장·server readback·snapshot을 재검증한다. Rules 배포는 필요하지 않다.
- [x] 과거 permission-denied 4건은 기기/Cloud 로그 원본이 남아 있지 않아 사건별 원인을 추측 분류하지 않았다. 현재 감사에서는 owner/workspace/path/Rules/query 불일치를 재현하지 못했다.
- [x] 잔여 PROD marker 문서는 이미 deleted tombstone이고 일정·레슨일지·taxonomy·consent linkage가 0이다. 이번 read-only 범위에서는 추가 cleanup write를 하지 않는다.
- [x] 관련 Flutter 16개, 전체 Flutter 768개, Personal schedule Emulator 27개, analyze error 0, `git diff --check`, DEV APK를 통과했다.
- [x] PROD write/install/실행, Firebase deploy, Rules/indexes/Storage/Hosting, Play Store, commit, push는 0건이다. 다음 단계로 자동 이동하지 않는다.

## 2026-08-31 PROD 회원 동의 저장 blocker 완료

- [x] PROD에 없던 `updateManagedMemberConsent`만 `more-than-fitness-f6adb`에 선택 배포했다. `asia-northeast3`, Node.js 22, `ACTIVE`와 갱신 시각을 확인했다.
- [x] auth/current owner/Personal workspace/허용 필드/transaction 계약과 Flutter의 callable → server readback → owner snapshot 완료 순서를 재확인했다.
- [x] deleted 또는 pending-delete 회원의 동의 변경을 `member_deleted`로 write 전에 거부하도록 보강하고 Emulator 회귀를 추가했다.
- [x] Galaxy PROD에서 개인정보 없는 신규 fixture의 동의 저장, canonical agreed/timestamp readback, 고객카드 재진입, 앱 재실행 유지가 통과했다.
- [x] fixture를 canonical soft-delete로 정리해 active 회원 28, managed count 28, 일정 318, 레슨일지 0, 그룹 2, 태그 0, tier Semi-Pro, 기본 그룹 `MORE THAN GYM` baseline을 복원했다. 정책상 새 deleted tombstone 1건은 보존하며 기존 tombstone과 실회원은 변경하지 않았다.
- [x] 관련 Flutter 63개, 전체 Flutter 768개, managed-member Emulator 68개, Functions lint/build, analyze error 0, `git diff --check`, 최종 PROD PID 안전 로그가 통과했다.
- [x] PROD 회원 동의 저장 blocker를 종료한다. 다른 Functions·Rules·indexes·Storage·Hosting, Play Store, AAB, commit, push는 0건이며 다음 작업으로 자동 이동하지 않는다.

## 2026-09-01 최신 PROD client validation

- [x] PROD build graph에 동일 이름 일정 연결, MORE DAY 미래 picker, consent retry, account dialog/Email·Google, keyboard-aware feedback, membership/D-DAY, 회원권 label, startup/Drawer, schedule hotfix, taxonomy, R8 keep이 포함됨을 확인했다.
- [x] Galaxy PROD `1.0.4 (15)`에서 versionCode만 16으로 올린 legacy validation APK를 만들었다. 잘못 서명된 최초 산출물은 설치 전에 차단했고, 설치본과 signer가 일치하는 APK만 `adb install -r`했다. UID/dataDir/firstInstallTime/Auth session/DEV package가 유지됐다.
- [x] PROD fixture로 동일 이름 후보 3건 기본 체크, 일부 선택, 다음 주·다른 이름·기연결 보호, Android back 취소 write 0, canonical readback, 재진입·재시작 유지, duplicate schedule 0을 확인했다.
- [x] PROD fixture 고객카드에서 GOLD+3개월 membership+미래 D-DAY 저장/readback과 회원권 표기, 개인정보 동의 저장/readback을 확인했다. 계정 provider 상태는 읽기 전용으로 확인해 PROD Auth를 변경하지 않았다.
- [x] 키보드 열린 빠른등록 시트의 로컬 validation 오류 feedback이 키보드 위에 표시되고 시트가 유지되며 callable/write 0임을 실기기에서 확인했다.
- [x] 숫자 marker가 전화번호 부분검색과 겹쳐 실제 회원 1건을 잘못 선택한 사건은 즉시 감지했다. 검증 전 상태와 대조해 이번 작업에서 바꾼 MORE DAY만 canonical 미등록 상태로 원복했고 다른 실제 필드는 변경하지 않았다. 이후 숫자 없는 정확한 fixture 검색만 사용했다.
- [x] fixture 일정 7건과 active fixture 회원 2건을 canonical 경로로 정리해 active 회원 28, managed count 28, 일정 317 baseline과 fixture 검색 0을 복원했다. 레슨일지/그룹/태그/tier/theme/widget은 이번 작업에서 변경하지 않았다.
- [x] 관련 Flutter 97개, 전체 Flutter 768개, schedule Emulator 27개, managed-member Emulator 68개, taxonomy Emulator 25개, analyze error 0, `git diff --check`, PROD APK와 최종 안전 로그를 통과했다.
- [x] 최신 PROD client validation 완료. Firebase 추가 배포, Play Store/AAB 업로드, commit, push는 0건이다.
- [ ] 다음 단계는 별도 승인 후 새 release checkpoint를 만들고 upload-key PROD AAB를 생성·검증하는 것이다. Play Console 업로드는 그 다음 별도 승인까지 시작하지 않는다.

## 2026-09-01 동일 이름 일정 연결 시트 safe-area

- [x] Flutter modal bottom sheet의 `useSafeArea`가 SDK 내부에서 `bottom: false`인 것을 확인해 실제 겹침 원인을 확정했다.
- [x] 기존 action row에만 `MediaQuery.viewPaddingOf(context).bottom`을 추가했다. 기존 20dp, CTA 스타일·높이, 0.72 maxHeight, Flexible 목록과 연결 정책은 변경하지 않았다.
- [x] light/dark/lululala·320/360/384/411dp, 후보 1/3/10개에서 safe bottom, CTA visible, 내부 스크롤, overflow 0을 확인했다.
- [x] Galaxy DEV의 현재 3버튼 navigation 180px 영역에서 CTA 하단과 system bar 사이 75px, 겹침 0을 fixture-only 캡처와 좌표로 확인했다. 실제 gesture mode 변경 대신 24/32dp `viewPadding` widget test로 가변 inset을 검증했다.
- [x] 실기기 `4개 일정 연결` canonical readback과 Android back 취소 write 0을 확인했다. 연결 후보·보호 일정 정책은 기존과 동일하다.
- [x] 실수로 삭제된 fixture 일정은 marker/owner/예상 ID guard 아래 남은 fixture만 정리하고 baseline 복원 후 재검증했다. 최종 회원 6, 일정 11, marker 회원·일정 0이다.
- [x] 시트 18개, 관련 106개, 전체 Flutter 770개, schedule Emulator 27개, analyze error 0, 변경 파일 issue 0, `git diff --check`, DEV APK와 최종 안전 로그가 통과했다.
- [x] safe-area 출시 blocker 해소. PROD/Firebase 배포/AAB/checkpoint/Play Store/commit/push는 0건이다.

## 2026-09-01 최종 Play Store 후보 checkpoint/AAB

- [x] 이전 checkpoint 이후 release allowlist 39개를 확정했다: 제품/backend/config 23개, 테스트 14개, 문서 2개. tracked 수정 30개와 신규 9개만 명시 stage했고 allowlist 밖·누락·삭제는 0이다.
- [x] secret 감사 통과: `android/key.properties` ignored, keystore/certificate/private key/token/credential staged·tracked 0. 남은 검증·prompt·audit·temp untracked 331개는 제외했다.
- [x] `1.0.4 (17)`로 versionCode를 올리고 동일 이름 일정 연결 safe-area, account link, 회원 저장·동의, taxonomy, schedule/Drawer/R8 최신 source를 checkpoint에 포함했다.
- [x] 최신 검증은 전체 Flutter 770개, Personal schedule Emulator 27개, analyze error 0(기존 warning/info 1166), diff check 통과다. version bump 외 제품 로직 변경이 없어 전체 test를 중복 실행하지 않았다.
- [x] upload key PROD AAB 생성 및 검증 완료: `build/app/outputs/bundle/prodRelease/app-prod-release.aab`, 79,011,079 bytes, SHA-256 `AE261ED663C36FC5A700556EC50F60D3351BCD71535F64C537A8EEE79E33C25E`, signer 공개 인증서 SHA-1/SHA-256 일치, `jarsigner` exit 0.
- [x] manifest/package/version/SDK/debuggable false/PROD Firebase/일반·round·adaptive icon/위젯 provider 3개/R8 receiver 보존을 확인했다. DEV project/package marker는 0이고 PROD widget DEV badge는 false다.
- [ ] Play Console 앱 생성 후 Internal Testing에 AAB를 업로드한다.
- [ ] Play App Signing 인증서 SHA-1/SHA-256을 확인해 Firebase PROD Android 앱에 등록한 뒤 Play 설치본 Google 연결 smoke test를 수행한다. upload key SHA를 런타임 signer로 대신 등록하지 않는다.
- [x] checkpoint commit 1건만 생성했다. Firebase 변경·배포, Play Console 업로드, Galaxy 설치, 추가 commit, push는 수행하지 않았으며 다음 단계로 자동 이동하지 않는다.

## 2026-09-02 PROD 주간 전체 붙여넣기 Rules access-budget hotfix

- [x] PROD 실패는 일정 삭제가 아니라 서로 다른 member link 17개를 한 atomic batch에서 검증하며 Firestore Rules access-call 한도를 넘은 `PERMISSION_DENIED`였다. 실패 batch의 server write/delete는 모두 0이다.
- [x] 주간 copy writes를 서로 다른 member link 최대 10개, write 최대 450개로 분할하고 batch별 server readback·부분 실패 재시도를 추가했다. paste 경로의 기존 일정 delete는 0이다.
- [x] 일정 mutation 로그의 raw source/target document ID를 제거하고 존재 여부와 건수만 기록한다.
- [x] 관련 Flutter 22개, 전체 Flutter 775개, Personal schedule Emulator 30개, analyze error 0, `git diff --check`, DEV Debug APK가 통과했다.
- [x] Galaxy DEV에서 이미 붙여넣어진 주를 빈 다음 주로 다시 복사해 54건 commit/readback/restart 유지가 통과했고, 검증 주를 삭제해 일정 227·target 0 baseline으로 원복했다.
- [x] 동일 legacy signer의 non-debuggable PROD validation APK `1.0.4 (18)`을 `adb install -r`했다. UID/dataDir/firstInstallTime/session과 PROD 일정 318·active 회원 28 baseline을 보존했다.
- [ ] 사용자 조작 가능한 시점에 개인정보 없는 PROD marker fixture만 사용해 paste 직후/T+5s/재진입/force-stop 재시작 server persistence, duplicate 0, unintended delete 0과 strict cleanup을 최종 확인한다. 실회원·실일정은 사용하지 않는다.
- [ ] 위 PROD fixture가 통과한 뒤에만 blocker를 종료하고 versionCode를 새로 올린 release checkpoint와 upload-key AAB를 생성한다. `1.0.4 (17)` AAB는 hotfix 미포함이므로 업로드하지 않는다.
- [x] Firebase 배포, Play Console/AAB, commit, push는 이번 작업에서 0건이다.

## 2026-09-07 회원권 이용정지/정지내역·강사 한줄소개 blocker

- [x] 원인 확정: 회원권 정지는 `client_card_page.dart`의 클라이언트 직접 `members/{memberId}` write가 `firestore.rules`(personal workspace 문서는 `isLegacyAdmin()`만 update 허용)에 막혀 항상 `permission-denied`로 조용히 실패했다. 한줄소개(`intro`)는 personal workspace 저장 경로(`updatePersonalTrainerProfile` gateway/callable)에 필드 자체가 없어 저장되지 않았다.
- [x] 회원권 정지/재개를 위한 신규 Cloud Function `updateManagedMemberMembershipPause`를 추가하고(`functions/src/managed_members.ts`, `index.ts`), `client_card_page.dart`가 personal workspace에서 이 callable을 쓰도록 수정했다. 기존 Firestore 필드 스키마와 pause/resume 계산식은 그대로 유지했다.
- [x] `updatePersonalTrainerProfile`의 allowlist에 `intro`를 추가하고 Flutter gateway·`my_page.dart`의 두 저장 경로 모두 `intro`를 payload에 포함하도록 수정했다.
- [x] Firestore/Functions Emulator 신규 회귀 테스트: `managed_member_membership_pause.test.cjs`(9개) 신규, `managed_members_limit.test.cjs`에 intro 저장/갱신 2건 추가(68→70). 전체 Flutter 775개, 변경 범위 analyze, functions build/lint, `git diff --check` 통과.
- [x] 사용자 승인 후 `firebase deploy --only functions --project more-than-fitness-dev-mft`로 DEV에 배포 완료(신규 `updateManagedMemberMembershipPause` 포함 전체 함수 갱신 성공). PROD는 미배포.
- [x] 배포 중간에 `intro`가 아직 미배포 상태에서 personal workspace의 모든 단일 필드 저장(직책·레슨플레이스·연락처 등)이 함께 실패하는 회귀를 발견해 즉시 hotfix(intro 인자 임시 제거) 후 재배포 확인 뒤 원복했다. 회귀 원인: `_saveSingleProfileField`/`_saveProfile`이 personal workspace에서 매번 전체 필드를 재전송하는 기존 패턴에 `intro`가 섞이면서, 서버가 아직 모르는 필드 하나 때문에 요청 전체가 `unknown_fields`로 거부됨.
- [x] 한줄소개 실기기 최종 확인 완료: 저장 → 로그상 서버 성공(`updatePersonalTrainerProfile` 에러 없음, 후속 `reconcilePersonalTier` 호출) → force-stop 후 콜드 재시작 → 마이페이지 재진입 → 값 유지 확인.
- [ ] 회원권 정지는 fixture 계정 tier가 Amateur(요구 Semi-Pro)라 실제 정지 버튼 흐름은 여전히 미확인이다. Semi-Pro 이상 계정이 생기면 정지→정지내역 표시→재개→재시작 유지를 확인한다.
- [x] Firebase 배포(DEV, 사용자 승인 하에 수행), Rules 변경, PROD 접근, 실회원 데이터 변경, migration, commit, push(배포 제외) 중 배포 외에는 이번 작업에서 0건이다.
