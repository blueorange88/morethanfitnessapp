# Anonymous Personal 출시 Smoke Test

감사일: 2026-07-17
상태: 실행 계획. 실제 Firebase 프로젝트에서는 미실행

## 사전 조건

- project ID를 `more-than-fitness-f6adb`로 재확인
- 이 project가 개발/운영 중 무엇인지 승인
- predeploy Rules/source/data backup 완료
- 필수 Functions 9개만 배포됨
- schedule/training log index 2개가 `Enabled`
- local Rules가 배포됐고 Storage Rules는 첫 배포에서 제외됨
- 테스트 Android build, 기기, 네트워크, 로그 관찰 담당자 준비
- 실제 고객 개인정보가 아닌 승인된 test data 사용

각 단계에서 UID, 내부 token, 전화번호 원문을 RUN_LOG에 남기지 않는다. UID 비교는 화면/Console에서 동일·상이 여부만 기록한다.

## 단계별 검증

| # | 시나리오 | 기대 결과 | 실패 시 중단/롤백 |
| --- | --- | --- | --- |
| 1 | 앱 신규 설치/데이터 초기화 후 실행 | 로그인 화면 없이 anonymous session 준비 화면을 거쳐 actual personal 홈 진입 | bootstrap 오류면 A1 중단. sample/legacy 홈으로 가면 release 중단 |
| 2 | Auth와 profile 확인 | anonymous UID 1개, `trainer_profiles/{uid}`가 Beginner/local/personal/active로 1개 생성 | profile conflict/중복이면 A1 rollback |
| 3 | 앱 강제 종료 후 재실행 | 같은 anonymous UID와 같은 personal workspace 유지 | UID 변경이면 출시 중단, 새 문서 생성 금지 |
| 4 | 정식 회원 1명 등록 | 필수 이름·성별·전화번호·활동 지역 검증 후 현재 UID owner로 저장 | Function/index/owner 오류면 A2 중단 |
| 5 | 같은 trainer에서 같은 전화번호 재등록 | `duplicate_member`로 거부, 입력 유지, 문서/누적 count 증가 없음 | 중복 생성이면 A2 rollback 및 데이터 audit |
| 6 | 다른 test UID에서 같은 전화번호 등록 | 별도 personal workspace에서 허용, 서로 목록에 노출되지 않음 | global 중복 또는 cross-UID 노출이면 Rules/Function rollback |
| 7 | 2~10번째 회원 등록 | 10번째까지 성공, anonymous tier는 Beginner 유지 | 10번째 차단/누적 오류면 A2 rollback |
| 8 | 11번째 회원 시도 | 계정 연결과 내 정보 완료 전 차단, 작성값 유지 | 11번째 생성되면 즉시 release 중단 |
| 9 | personal 일정 CRUD | 현재 UID 일정 생성·수정·이동·삭제, 재실행 후 동일, 다른 UID 미노출 | index/Rules/owner 오류면 Rules rollback |
| 10 | 이름-only 임시 일정 | 일정은 저장되지만 canonical member 자동 생성 없음 | member 자동 생성이면 release 중단 |
| 11 | 레슨일지 draft/autosave | 같은 UID member/schedule만 연결, draft 생성·수정, 재실행 후 유지 | 다른 owner 연결/identity 변경이면 Rules rollback |
| 12 | 레슨일지 확정 | completed/no-show/service 상태별 회차·통계·schedule이 한 transaction으로 일치 | 부분 write/이중 차감이면 A3 rollback 및 audit |
| 13 | 중복 확정과 확정취소 | 중복 확정 1회 효과, 취소 1회 원복, 중복 취소 추가 효과 없음 | 멱등 실패면 A3 rollback |
| 14 | MyPage 내 정보 | 다섯 필수 항목 저장 후 profileComplete server 값 갱신 | client tier/count write 또는 입력 유실이면 중단 |
| 15 | 이메일 계정 연결 | 현재 anonymous user에 link, 전후 UID 동일, 기존 회원·일정·레슨일지 유지 | UID 변경/자동 병합이면 즉시 중단 |
| 16 | linked 재실행 | 로그인 화면 없이 같은 personal 홈과 데이터 복구 | login gate/빈 workspace면 중단 |
| 17 | linked 로그아웃 | widget/cache 정리 후 새 anonymous UID의 빈 personal workspace | 이전 UID 데이터나 widget 잔상 노출 시 중단 |
| 18 | 기존 linked 계정 재로그인 | MyPage account flow로 원래 linked UID 복귀 후 원래 데이터 표시 | 새 UID merge/legacy 귀속이면 중단 |
| 19 | tier progression test | 승인된 test fixture에서 10 + linked + profile complete는 Amateur, 30 Semi-Pro, 50 Pro, 후원 미사용 | client 계산/강등/후원 혼합이면 A2 중단 |
| 20 | 관리자/legacy 격리 | anonymous와 일반 linked는 legacy 미노출. 두 claim + password 완료 admin만 legacy 접근 | claim 하나만으로 노출되면 Rules rollback |
| 21 | Debug legacy 회귀 | Debug 버튼만 legacy 직접 경로 제공. Profile/Release에는 버튼/우회 없음 | Release 우회 노출 시 앱 release 중단 |
| 22 | 계약·원격서명/anatomy | personal에서 계속 거부/미노출. legacy admin 범위만 기존 동작 | personal 권한이 열렸으면 Rules rollback |
| 23 | Storage | personal core smoke에서 Storage 요청이 발생하지 않음 | 필수 흐름이 Storage에 의존하면 첫 배포 설계 재검토 |

## 관찰 항목

- Firebase Functions logs: callable name, success/error code, transaction retry. 개인정보 payload 기록 금지
- Firestore: owner UID equality, workspaceType, stable document ID, createdAt/updatedAt
- Auth: provider가 anonymous→password로 연결되며 UID 유지
- Android widget: UID 변경/로그아웃 전 UID 일정 cache 제거
- 비용/성능: `us-central1` callable과 `asia-northeast3` Firestore transaction latency, invocation/read/write count
- App Check: enforcement 여부와 callable verification

## 통과 기준

- 필수 1~18, 20~23 전부 통과
- 19는 production에서 50개 실제 문서를 만들지 않고 승인된 Emulator/test project fixture로 증명 가능. production에서 수행하면 별도 데이터 승인 필요
- 다른 UID/legacy 데이터 노출 0건
- 10번째 허용, 11번째 차단, UID 유지 연결, 중복 확정 방지 확인
- Functions/Rules/index error 0건
- 실패 시 입력값 보존과 사용자 안내 확인

## 실패 처리

1. 신규 app 공개를 즉시 중지한다.
2. owner/data 노출이면 predeploy Firestore Rules를 먼저 복원한다.
3. Function transaction 문제면 해당 A1/A2/A3 묶음이 아니라 문제 함수만 rollback한다.
4. 이미 작성된 문서를 자동 삭제·migration하지 않는다.
5. `FIREBASE_BACKUP_AND_ROLLBACK.md`의 audit 절차로 영향을 계산한다.
6. 원인과 실행 결과를 기록하고 재승인 전까지 다음 단계로 가지 않는다.

현재 이 smoke test는 production에서 실행되지 않았다.
