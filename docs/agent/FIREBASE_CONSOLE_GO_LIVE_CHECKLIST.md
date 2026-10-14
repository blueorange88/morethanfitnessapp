# Firebase Console 출시 전 수동 확인 체크리스트

확인 대상 project: `more-than-fitness-f6adb`
상태: **미완료 — 모두 확인하고 증거를 보존하기 전 실제 배포 NO-GO**

이 문서는 Console에서만 확인 가능한 항목의 작업표다. 이번 작업에서는 provider, billing, Rules, 데이터, backup 설정을 변경하지 않았다.

## 1. 프로젝트와 데이터 성격

- [ ] Firebase Console 상단 프로젝트 선택기에서 `more-than-fitness-f6adb`를 재확인한다.
- [ ] 프로젝트 설정 → 일반 → 프로젝트 ID와 Android 앱 package가 실제 출시 앱과 일치하는지 확인한다.
- [ ] 프로젝트 설정 → 사용자 및 권한에서 운영 책임자와 배포 담당자를 확인한다.
- [ ] 별도 개발·스테이징 프로젝트 존재 여부를 확인한다.
- [ ] Firestore Database → 데이터에서 기존 실제 회원·일정·레슨일지·계약 데이터인지 소유자가 판정한다.

## 2. Authentication

경로: Firebase Console → 빌드 → Authentication

- [ ] 로그인 방법 → 익명(Anonymous)이 사용 설정인지 확인한다.
- [ ] 로그인 방법 → 이메일/비밀번호가 사용 설정인지 확인한다.
- [ ] 설정 → 승인된 도메인에서 실제 사용하는 도메인만 허용됐는지 확인한다.
- [ ] 템플릿 → 비밀번호 재설정에서 발신자 이름, 회신 주소, action URL, 한국어 본문을 확인하고 테스트 메일을 별도 승인 후 확인한다.
- [ ] 사용자 목록과 custom claim은 이 체크에서 만들거나 변경하지 않는다.

## 3. Firestore 현재 상태 보존

경로: Firebase Console → 빌드 → Firestore Database

- [ ] 규칙 탭의 현재 Published Rules 원문 전체를 publish 시각과 함께 변경 불가 백업에 저장한다.
- [ ] 데이터 탭 또는 승인된 read-only count 도구로 `members`, `schedules`, `training_logs`, `contracts`, `trainer_profile`, `trainer_profiles`, `member_groups`, `lesson_products`, `contractCounters`, `sign_requests` 문서 건수를 기록한다.
- [ ] legacy 대표 문서와 personal 대표 문서의 필드 이름만 기록하고 개인정보 값은 복사하지 않는다.
- [ ] 인덱스 탭에서 production composite index 목록을 저장한다. 현재 CLI 감사 시점에는 0개였다.
- [ ] 데이터베이스 설정에서 위치가 `asia-northeast3`인지 재확인한다.

## 4. 결제·Functions 운영 조건

경로: Firebase Console → 프로젝트 설정 → 사용량 및 결제 / 빌드 → Functions

- [ ] Blaze 요금제 여부와 결제 계정을 확인한다.
- [ ] 예산 알림과 quota 경보 수신자를 정한다.
- [ ] Functions 첫 선택 배포 후 필수 9개만 존재하고 리전이 `asia-northeast3`인지 확인할 계획을 승인한다.
- [ ] 각 필수 함수의 최대 인스턴스가 10인지 배포 상세에서 확인할 담당자를 정한다.
- [ ] App Check enforcement와 로그 보존 정책을 확인한다. 준비되지 않았다고 임의로 enforcement를 켜지 않는다.

## 5. 백업·PITR·삭제 보호

경로: Google Cloud Console → Firestore → Databases / Import/Export, Cloud Storage → Buckets

- [ ] managed export용 별도 bucket 이름, 위치, IAM, 보존 정책, 객체 버전 관리를 확인한다.
- [ ] bucket 위치가 Firestore export 요구사항과 조직 정책에 맞는지 확인한다.
- [ ] 첫 배포 전 managed export를 실행할 승인·담당자·prefix를 정하고 operation 성공 및 object 존재를 확인한다.
- [ ] 현재 managed backup schedule, PITR, delete protection 상태를 캡처한다. 감사 시점에는 schedule 0, backup 0, PITR disabled, delete protection disabled였다.
- [ ] PITR를 지금 활성화해도 과거 7일 이력이 즉시 생기지 않고 활성화 이후부터 이력이 누적된다는 점을 승인자가 확인한다.
- [ ] PITR는 배포 전 managed export의 대체가 아니라 후속 보호 수단으로 취급한다.

## 6. 최종 Go/No-go

- [ ] 현재 Published Rules와 로컬 후보의 collection별 diff 승인
- [ ] 기존 데이터 count와 managed export 성공 증거 확보
- [ ] 두 composite index가 `Enabled`
- [ ] 선택 배포 대상 9개, region, maxInstances 재확인
- [ ] rollback Rules 파일·source checkpoint·담당자 준비
- [ ] 배포 시간대와 중단 기준 승인

하나라도 미완료면 수동 판정은 **NO-GO**다. `firebase deploy`, export, provider 변경, 관리자 생성은 별도 명시 승인 전 실행하지 않는다.
