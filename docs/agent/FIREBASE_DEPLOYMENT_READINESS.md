# Firebase 실제 배포 준비 감사

감사일: 2026-07-17
범위: 실제 배포 전 read-only 감사와 계획
현재 결론: **코드 NO-GO 해소 / 수동 NO-GO 유지**

## 프로젝트 식별 결과

| 항목 | 확인 결과 | 근거/주의 |
| --- | --- | --- |
| Firebase project ID | `more-than-fitness-f6adb` | `.firebaserc`, `firebase.json`, Android config, CLI 선택 프로젝트 일치 |
| Firebase display name | `More Than Fitness` | `firebase projects:list` read-only 결과 |
| Project state | `ACTIVE` | CLI read-only 결과 |
| 현재 CLI 계정 | `mtgroup.fitnessapp@gmail.com` | `firebase login:list` read-only 결과 |
| Firebase CLI | 15.23.0 | root local devDependency |
| Firestore database | `projects/more-than-fitness-f6adb/databases/(default)` | Native mode, Standard edition |
| Firestore location | `asia-northeast3` | `firestore:databases:list` |
| Firestore 보호 상태 | PITR disabled, delete protection disabled, version retention 1시간 | 현재 managed backup/schedule도 없음 |
| Storage bucket config | `more-than-fitness-f6adb.firebasestorage.app` | Android config의 safe field만 확인. bucket 실제 location은 Console 확인 필요 |
| Functions local runtime | Node.js 22, gcfv1 callable | `functions/package.json`, local endpoint metadata |
| Functions local region | 출시 필수 9개 `asia-northeast3`; 관리자·legacy 5개 기본 리전 유지 | 필수 9개는 Firestore와 같은 서울 리전 |
| Functions v1 cost cap | 출시 필수 9개 `maxInstances=10` | 공통 v1 builder의 실제 endpoint metadata로 확인 |
| 현재 배포 Functions | 0개 | `functions:list --json` result empty |
| 현재 production composite index | 0개 | `firestore:indexes --json` |

Android config의 API key는 읽거나 문서화하지 않았다.

## 개발/운영 프로젝트 판단

코드만으로 개발/운영 여부를 확정할 수 없다. 프로젝트명에 dev/prod 표식이 없고 database는 2025년에 생성됐으며 legacy 데이터가 있다고 알려져 있다. 반면 현재 Functions와 composite index가 0개라 신규 personal backend는 배포되지 않았다. 따라서 현재 프로젝트를 **기존 실제 데이터가 있는 미분류 단일 프로젝트**로 취급한다.

다음 수동 확인 전에는 운영 또는 개발이라고 단정하지 않는다.

- Firebase Console 상단 project와 billing account/environment owner 확인
- 실제 사용자 UID와 legacy 데이터가 운영 데이터인지 확인
- 별도 staging project 존재 여부 확인
- Android production package가 이 project를 사용 중인지 확인
- 장애 공지/배포 시간대/복구 담당자 지정

## Console 필수 확인

### Authentication

- [ ] Sign-in method에서 Anonymous provider enabled
- [ ] Email/Password provider enabled
- [ ] Authorized domains에 실제 앱/웹 흐름에 필요한 domain만 존재
- [ ] 비밀번호 재설정 sender name, reply-to, action URL, 한국어 template 확인
- [ ] 실제 관리자 계정을 만들거나 claim을 변경하지 않고 현재 정책만 확인
- [ ] App Check enforcement 상태 확인. Emulator callable verification에는 App Check `MISSING`이 기록됨

### Firestore

- [ ] 현재 Published Rules 원문과 publish metadata 백업
- [ ] `members`, `schedules`, `training_logs`, `contracts`, `trainer_profile`, `trainer_profiles`, `member_groups`, `lesson_products`, `contractCounters`, `sign_requests`, queue/More Care의 count 기록
- [ ] representative legacy 문서에 `workspaceType`이 없거나 `personal`이 아닌지 표본 확인
- [ ] billing plan과 managed export 사용 가능 여부 확인
- [ ] 별도 backup bucket의 location, IAM, retention/versioning 확인

### Functions

- [ ] 첫 deploy가 gcfv1/Node 22로 생성 가능한지 CLI preflight/승인 창에서 확인
- [x] 출시 필수 9개를 Firestore와 같은 `asia-northeast3`로 명시
- [ ] quota/budget alert/log retention 설정 확인
- [x] 출시 필수 9개 v1 endpoint에 `runWith({maxInstances: 10})` 적용

메뉴별 상세 확인 절차는 `FIREBASE_CONSOLE_GO_LIVE_CHECKLIST.md`를 따른다.

## 출시 필수와 제외 대상

Anonymous personal 첫 출시의 실제 필수 callable은 9개다.

1. `bootstrapAnonymousBeginnerProfile`
2. `bootstrapTrainerProfile`
3. `transitionAnonymousProfileToLinked`
4. `updatePersonalTrainerProfile`
5. `createManagedMember`
6. `transitionManagedMemberState`
7. `updateManagedMember`
8. `finalizePersonalTrainingLog`
9. `cancelPersonalTrainingLog`

현재 9개 모두 미배포다. 관리자 비밀번호 gate용 `completeInitialPasswordChange`도 미배포지만 Anonymous 핵심에는 포함하지 않고 관리자 활성화 단계로 분리한다. `chargeOnce`, `cancelNoShow`, `lockConsent`, `unlockConsent`는 legacy 영향 함수이고 앱 직접 호출이 확인되지 않아 첫 배포에서 제외한다.

schedule CRUD와 training log draft CRUD는 callable이 아니라 client + owner-scoped Firestore Rules 경로다. 존재하지 않는 Function 이름을 만들지 않는다.

상세 표는 `FIREBASE_FUNCTIONS_DEPLOY_MATRIX.md`를 따른다.

## Firestore와 Storage 판단

- local Rules는 Anonymous/Linked personal profile read, member read, schedule CRUD, training log draft CRUD를 owner 범위로 열고 member/tier/finalize write는 Function 전용으로 둔다.
- contracts, sign_requests, anatomyRecords, More Care, 알림 queue와 상품은 personal에 열지 않는다.
- production Rules 원문은 CLI로 자동 확보하지 못했으므로 Console diff 전에는 배포 불가다.
- 실제 query 기준 composite index는 schedule 1개와 training log 1개뿐이며 local 파일에 정확히 정의돼 있다. production에는 없으므로 해당 query 전에 먼저 배포하고 `Enabled`를 기다려야 한다.
- members 목록과 owner-scoped 전화번호 중복 검사는 equality-only라 composite index를 추가하지 않았다.
- personal 핵심 홈·회원 필수 입력·일정·레슨일지 text/draft/finalize·MyPage 계정 연결에는 Storage upload가 필요하지 않다.
- 현재 Storage Rules는 legacy admin의 profile/inbody/contract/signature image만 허용한다. 첫 Anonymous 배포에서 `storage:rules`를 제외한다.

상세 권한표는 `FIRESTORE_RULES_DEPLOY_MATRIX.md`를 따른다.

## 단계별 배포 계획

| 단계 | 작업 | Go 조건 | No-go/즉시 중단 | rollback |
| --- | --- | --- | --- | --- |
| 0 | project/environment 확정 | Console owner가 dev/prod와 시간대 승인 | 미분류 상태 유지 | 변경 없음 |
| 1 | Auth provider 수동 확인 | Anonymous + Email/Password + domain/template 확인 | 하나라도 불명확 | provider 변경하지 않음 |
| 2 | 현재 Rules/count/source 백업 | Rules 원문, count, immutable source checkpoint 확보 | dirty source만 존재, Rules 원문 없음 | 변경 없음 |
| 3 | Firestore managed export 또는 승인된 최소 백업 | export operation success 또는 서면 승인된 대체 백업 | billing/IAM/bucket/count 불명확 | 변경 없음 |
| 4 | A1 Functions 4개 | lint/build/Emulator, budget/region 승인 | deploy 오류, callable bootstrap smoke 실패 | 신규 함수 개별 삭제 또는 checkpoint source 재배포 |
| 5 | A2 Functions 3개 | profile smoke 후 회원 1개 test transaction | 중복/index/10명 정책 오류 | 회원 함수 개별 rollback, 생성 데이터 자동 삭제 금지 |
| 6 | A3 Functions 2개 | draft fixture에서 finalize/cancel 멱등 확인 | 회차/통계/일정 불일치 | 확정 중지, 함수 rollback, 데이터 수동 감사 |
| 7 | Firestore indexes | local 2개가 Enabled | build failure/예상 외 삭제 prompt | Rules 배포 보류, 정확한 index만 수동 복구 |
| 8 | Firestore Rules | Published source diff 승인, index enabled | legacy 접근 상실, owner query 실패 | predeploy Rules 즉시 재배포 |
| 9 | Release smoke | `RELEASE_SMOKE_TEST.md` 전체 통과 | UID/데이터/10·11명/확정 오류 | 신규 배포 노출 중지 후 Rules→Functions 순으로 rollback |
| 10 | 관리자/legacy | 별도 승인 | Anonymous smoke와 혼합 | 별도 rollback |
| 11 | Storage | 실제 personal upload 요구가 생긴 후 별도 설계 | 첫 배포에 포함됨 | 배포하지 않음 |

index는 Function 회원 중복 equality query 외 schedule/training log client query에 필요하다. 실제 배포 순서는 A1 smoke → A2 smoke → A3 smoke → indexes Enabled → Rules → 전체 release smoke로 세분화한다. 앱 공개 전에 서버와 Rules를 모두 검증해야 한다.

## PowerShell 실행 초안

아래는 승인 후 실행 가능한 초안이며 이번 감사에서는 한 줄도 실행하지 않았다.

```powershell
Set-Location C:\src\mtf_app
$ProjectId = 'more-than-fitness-f6adb'

# 대상 재확인
npx.cmd firebase login:list
npx.cmd firebase use
npx.cmd firebase functions:list --project $ProjectId
npx.cmd firebase firestore:indexes --project $ProjectId

# 로컬 gate
npm.cmd --prefix functions run lint
npm.cmd --prefix functions run build
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
npm.cmd run test:profile-emulators
npm.cmd run test:anonymous-emulators
npm.cmd run test:member-emulators
npm.cmd run test:personal-schedule-emulators
npm.cmd run test:personal-training-log-emulators
npm.cmd run test:legacy-emulators
flutter test --no-pub

# 선택 Functions: 전체 functions 일괄 배포 금지
npx.cmd firebase deploy --project $ProjectId --only "functions:bootstrapAnonymousBeginnerProfile,functions:bootstrapTrainerProfile,functions:transitionAnonymousProfileToLinked,functions:updatePersonalTrainerProfile"
# A1 smoke 후
npx.cmd firebase deploy --project $ProjectId --only "functions:createManagedMember,functions:transitionManagedMemberState,functions:updateManagedMember"
# A2 smoke 후
npx.cmd firebase deploy --project $ProjectId --only "functions:finalizePersonalTrainingLog,functions:cancelPersonalTrainingLog"

# Index build 완료 확인 후 Rules
npx.cmd firebase deploy --project $ProjectId --only "firestore:indexes"
npx.cmd firebase firestore:indexes --project $ProjectId
npx.cmd firebase deploy --project $ProjectId --only "firestore:rules"
```

이 초안에는 `functions`, `storage`, hosting, 관리자 생성, claims, migration/backfill, 데이터 삭제, `gcloud firestore export` 실행이 포함되지 않는다.

## 코드 NO-GO 해소 결과

- 필수 9개 v1 callable은 `asia-northeast3`와 `maxInstances=10`을 실제 callable builder에 적용했다.
- Flutter callable은 `MtfFirebaseFunctions` 한 곳에서 서울 리전 instance를 얻는다. 테스트 주입용 기존 constructor는 유지했다.
- Emulator callable URL도 공통 helper를 사용한다. 필수 함수는 서울 리전, 범위 밖 관리자 함수 회귀만 기존 기본 리전을 명시한다.
- 현재 배포 함수가 0개이므로 기존 endpoint의 region migration, redirect, 중복 배포 정리는 필요 없다.
- `firestore.indexes.json`은 실제 range/order query 2개만 유지한다. equality-only members query와 메모리 status filter에는 composite를 만들지 않았다.

## 현재 검증 결과

- Functions lint: 통과
- Functions TypeScript build: 통과
- Emulator: profile 30 + anonymous 26 + member/tier 27 + schedules 20 + training logs 37 + legacy 28 = 168개 통과
- Flutter: 187개 통과
- 변경 범위 analyze: error/warning/info 0개
- Debug APK, Release APK, Release AAB: 모두 빌드 통과
- firebase-functions outdated 경고: 남음. 이번 작업에서 upgrade하지 않음
- 실제 Firebase deploy/export/provider/claim/admin 변경: 미실행

코드 차원의 region·maxInstances·index NO-GO는 해소했다. 그러나 Console 환경 확인, 현재 Published Rules 백업, 주요 collection count, billing·bucket·managed export가 완료되지 않았으므로 실제 배포 판정은 계속 **NO-GO**다. 백업·롤백은 `FIREBASE_BACKUP_AND_ROLLBACK.md`, 출시 후 검증은 `RELEASE_SMOKE_TEST.md`를 따른다. 다음 백로그로 이동하지 않는다.
