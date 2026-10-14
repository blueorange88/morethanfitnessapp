# Firebase Functions 배포 매트릭스

감사일: 2026-07-17
대상 프로젝트: `more-than-fitness-f6adb`
결론: **현재 배포 함수 0개, 로컬 top-level export 14개, 공통 0개, 원격 전용 0개**

## 확인 근거

- `functions/package.json`: Node.js 22, entry point `lib/index.js`.
- `functions/src/index.ts`와 build 산출물 `functions/lib/index.js`: top-level export 14개가 서로 일치한다.
- local endpoint metadata: 14개 모두 `platform=gcfv1`, callable HTTPS trigger다.
- 출시 필수 9개는 공통 v1 builder로 `asia-northeast3`와 `runWith({maxInstances: 10})`을 실제 적용했다.
- build 산출물 endpoint metadata에서 필수 9개 모두 `region=[asia-northeast3]`, `maxInstances=10`을 확인했다.
- 관리자 `completeInitialPasswordChange`와 legacy 4개는 이번 범위에서 region/runtime option을 변경하지 않았다.
- Firebase CLI 15.23.0의 `functions:list --project more-than-fitness-f6adb --json`: `result: []`.
- Flutter에서 실제 `httpsCallable`로 호출하는 이름은 아래 출시 필수 9개와 관리자용 1개뿐이다. `chargeOnce`, `cancelNoShow`, `lockConsent`, `unlockConsent`의 Flutter 호출은 현재 저장소에서 발견되지 않았다.

Firestore `(default)`와 필수 9개 Functions는 모두 `asia-northeast3`다. Flutter는 `MtfFirebaseFunctions.instance`, Emulator는 `functions_client.cjs`를 통해 같은 리전을 사용한다. 현재 원격 함수가 0개라 region migration/redirect는 필요 없다.

Flutter의 callable 기본 instance는 요청대로 전부 서울 리전으로 중앙화했지만, 범위 밖 관리자 `completeInitialPasswordChange` 서버 export는 기존 기본 리전에 남겨 두었다. 이 함수는 첫 Anonymous 배포 목록에 포함하지 않는다. 향후 관리자 활성화 배포 전에는 별도 승인 작업에서 서버 region을 서울로 맞춘 뒤 관리자 비밀번호 변경 smoke를 해야 하며, 현재 상태에서 해당 관리자 함수를 기본 리전으로 배포하면 앱 호출 리전과 불일치한다.

## 전수 export 목록

| Export | 구현 근거 | Trigger | 로컬 runtime/region | 현재 배포 | 분류 | Anonymous 출시 | 영향 | 권장 순서 | 롤백 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `bootstrapAnonymousBeginnerProfile` | `index.ts` → `profile_bootstrap.ts` | v1 callable | Node 22 / `asia-northeast3` / max 10 | 미배포 | 신규 personal | 필수 | 익명 UID의 Beginner profile 멱등 생성 | A1 | 이전 배포 없음. 앱 출시 중지 후 함수 개별 삭제 또는 승인된 이전 source 재배포 |
| `bootstrapTrainerProfile` | `index.ts` → `profile_bootstrap.ts` | v1 callable | Node 22 / `asia-northeast3` / max 10 | 미배포 | 신규 personal | 필수 | 기존 linked 계정의 빈 personal profile 생성 | A1 | 동일 |
| `transitionAnonymousProfileToLinked` | `index.ts` → `profile_bootstrap.ts` | v1 callable | Node 22 / `asia-northeast3` / max 10 | 미배포 | 신규 personal | 필수 | `linkWithCredential` 후 같은 UID의 local→linked 전환 | A1 | 동일 |
| `updatePersonalTrainerProfile` | `index.ts` → `profile_bootstrap.ts` | v1 callable | Node 22 / `asia-northeast3` / max 10 | 미배포 | 신규 personal | 필수 | 내 정보, profileComplete, 서버 tier 재평가 | A1 | 동일 |
| `completeInitialPasswordChange` | `index.ts` → `profile_bootstrap.ts` | v1 callable | Node 22 / `us-central1` | 미배포 | 관리자 | 첫 Anonymous 출시에 비필수 | 관리자 `mustChangePassword` gate 해제. legacy 진입에 필요 | D1 | 함수 개별 삭제 또는 이전 source 재배포 |
| `createManagedMember` | `index.ts` → `managed_members.ts` | v1 callable | Node 22 / `asia-northeast3` / max 10 | 미배포 | 신규 personal | 필수 | 정식 회원 생성, 필수값·중복·10/11명·tier transaction | A2 | 앱 출시 중지 후 함수 개별 삭제. 이미 생성된 회원은 자동 삭제하지 않음 |
| `transitionManagedMemberState` | `index.ts` → `managed_members.ts` | v1 callable | Node 22 / `asia-northeast3` / max 10 | 미배포 | 신규 personal | 필수 | 회원 상태와 서버 count/tier transaction | A2 | 함수 rollback과 데이터 보정은 분리. 자동 역변경 금지 |
| `updateManagedMember` | `index.ts` → `managed_members.ts` | v1 callable | Node 22 / `asia-northeast3` / max 10 | 미배포 | 신규 personal | 필수 | 회원 수정과 전화번호 owner-scoped 중복 검사 | A2 | 동일 |
| `finalizePersonalTrainingLog` | `index.ts` → `personal_training_logs.ts` | v1 callable | Node 22 / `asia-northeast3` / max 10 | 미배포 | 신규 personal | 필수 | 레슨일지 확정, 일정·회차·통계 transaction | A3 | 새 확정을 중지하고 함수 개별 rollback. 완료 transaction은 자동 원복 금지 |
| `cancelPersonalTrainingLog` | `index.ts` → `personal_training_logs.ts` | v1 callable | Node 22 / `asia-northeast3` / max 10 | 미배포 | 신규 personal | 필수 | 확정취소, 회차·통계·일정 멱등 원복 | A3 | 동일 |
| `chargeOnce` | `index.ts` 직접 구현 | v1 callable | Node 22 / `us-central1` | 미배포 | legacy 회차 | 미배포 유지 | legacy member event/회차 차감. 현재 Flutter 직접 호출 없음 | 보류 | 배포하지 않음. 후속 배포 시 이전 source 또는 개별 삭제 |
| `cancelNoShow` | `index.ts` 직접 구현 | v1 callable | Node 22 / `us-central1` | 미배포 | legacy 노쇼 | 미배포 유지 | staff claim 기반 event 취소 마킹 | 보류 | 동일 |
| `lockConsent` | `index.ts` 직접 구현 | v1 callable | Node 22 / `us-central1` | 미배포 | legacy 동의서 | 미배포 유지 | legacy member consent 잠금 | 보류 | 동일 |
| `unlockConsent` | `index.ts` 직접 구현 | v1 callable | Node 22 / `us-central1` | 미배포 | legacy 동의서 | 미배포 유지 | staff claim 기반 잠금 해제 | 보류 | 동일 |

`training_logs` 초안 생성·자동저장·삭제와 `schedules` CRUD는 Function export가 아니다. 현재 앱은 owner-scoped Firestore Rules를 사용한다. 존재하지 않는 `createTrainingLog`, `updateTrainingLog`, schedule callable 이름을 만들어 배포 목록에 넣지 않는다.

## 현재 배포와 로컬 비교

| 구분 | 결과 |
| --- | --- |
| 원격과 로컬에 모두 존재 | 없음 |
| 로컬에만 존재 | 위 14개 전부 |
| 원격에만 존재 | 없음 |
| 이름 차이 | 비교할 원격 함수가 없어 없음 |
| region/runtime 차이 | 비교할 원격 함수가 없어 없음 |
| 전체 Functions 배포 위험 | 보류 대상 legacy 4개와 관리자용 1개까지 동시에 새로 공개되고, v1 cost cap 미적용 상태를 한 번에 노출함 |

## 선택 배포 초안

실행하지 않은 PowerShell 초안이다. 각 묶음은 앞 묶음 smoke가 통과한 뒤에만 진행한다.

```powershell
Set-Location C:\src\mtf_app
$ProjectId = 'more-than-fitness-f6adb'

npm.cmd --prefix functions run lint
npm.cmd --prefix functions run build
npx.cmd firebase functions:list --project $ProjectId

# A1: 시작·계정·프로필 4개
npx.cmd firebase deploy --project $ProjectId --only "functions:bootstrapAnonymousBeginnerProfile,functions:bootstrapTrainerProfile,functions:transitionAnonymousProfileToLinked,functions:updatePersonalTrainerProfile"

# A2: 회원·등급 3개
npx.cmd firebase deploy --project $ProjectId --only "functions:createManagedMember,functions:transitionManagedMemberState,functions:updateManagedMember"

# A3: 레슨일지 확정·취소 2개
npx.cmd firebase deploy --project $ProjectId --only "functions:finalizePersonalTrainingLog,functions:cancelPersonalTrainingLog"
```

`completeInitialPasswordChange`는 관리자 활성화 단계에서 별도 승인 후 단독 배포한다. legacy 4개는 이번 Anonymous 첫 배포에서 제외한다. `firebase deploy --only functions`는 기본안으로 사용하지 않는다.

## Functions go/no-go

배포 전 아래가 모두 충족되어야 한다.

- [ ] 프로젝트가 개발/운영 중 무엇인지 소유자가 Console에서 확정했다.
- [ ] Anonymous와 Email/Password provider, authorized domain, reset template을 확인했다.
- [ ] 현재 source를 immutable commit/tag 또는 승인된 archive로 보존했다. 현재 dirty worktree만으로는 이전 source rollback을 보장할 수 없다.
- [x] 출시 필수 9개 v1 endpoint에 `maxInstances: 10` 적용과 metadata 확인을 완료했다.
- [x] 출시 필수 9개 Functions와 Flutter/Emulator client를 `asia-northeast3`로 맞췄다.
- [ ] billing/quota/App Check/로그 모니터 담당자를 정했다. Emulator 로그는 App Check가 `MISSING`임을 보여 준다.
- [ ] A1→A2→A3 각각의 smoke와 중단 기준을 승인했다.

Functions 코드 NO-GO는 해소했다. Console·백업 수동 gate가 남아 전체 판정은 **NO-GO**다. 실제 배포는 수행하지 않았다.
