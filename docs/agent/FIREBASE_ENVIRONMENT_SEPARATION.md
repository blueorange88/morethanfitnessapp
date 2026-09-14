# Firebase dev/prod 환경 분리

## 현재 운영 환경

- Flutter environment: `prod`
- Firebase projectId: `more-than-fitness-f6adb`
- Android applicationId/packageName: `com.example.mtf_app`
- Android Firebase 설정: `android/app/google-services.json`
- prod entrypoint: `lib/main_prod.dart`

기존 운영 설정 파일과 Firebase 프로젝트 설정은 변경하지 않는다. `prod`는 기존 `DefaultFirebaseOptions.currentPlatform`을 계속 사용한다.

## 개발 환경 구조

- Flutter environment: `dev`
- Android applicationId/packageName: `com.example.mtf_app.dev`
- 앱 표시 이름: `모어댄 DEV`
- Android Firebase 설정 위치: `android/app/src/dev/google-services.json`
- dev entrypoint: `lib/main_dev.dart`

dev는 Android native Firebase 설정으로 초기화한다. dev 설정 파일이 없으면 `processDev...GoogleServices` 단계에서 명확히 실패한다. 파일이 있더라도 projectId가 운영 projectId인 `more-than-fitness-f6adb`이면 앱 시작을 거부한다. 운영 설정으로 자동 fallback하지 않는다.

## 별도 dev Firebase 준비

권장 절차는 별도 Firebase 개발 프로젝트를 만든 뒤 Android 앱 `com.example.mtf_app.dev`를 등록하고 Firebase Console에서 내려받은 `google-services.json`을 다음 위치에 두는 것이다.

`android/app/src/dev/google-services.json`

Firebase CLI로 등록할 경우 실행 전 `<DEV_PROJECT_ID>`와 `<DEV_FIREBASE_APP_ID>`를 실제 개발 프로젝트 값으로 교체한다. 이번 작업에서는 실행하지 않았다.

```powershell
npx.cmd firebase apps:create android "모어댄 DEV" --package-name com.example.mtf_app.dev --project <DEV_PROJECT_ID>
New-Item -ItemType Directory -Force android\app\src\dev
npx.cmd firebase apps:sdkconfig android <DEV_FIREBASE_APP_ID> --project <DEV_PROJECT_ID> > android\app\src\dev\google-services.json
```

FlutterFire CLI는 현재 PC에 설치되어 있지 않다. 새 도구 설치는 별도 승인 없이 실행하지 않는다.

## 실행 명령

운영 Firebase를 사용하는 prod Debug 확인:

```powershell
flutter run --flavor prod -t lib\main_prod.dart
```

별도 dev Firebase 설정 파일을 준비한 뒤 개발 환경 실행:

```powershell
flutter run --flavor dev -t lib\main_dev.dart
```

## 실행 진단 로그

Debug 시작 시:

```text
[MTF_APP_ENV] environment=dev|prod projectId=... packageName=...
```

personal profile 서버 조회 시:

```text
[MTF_ENV_IDENTITY] projectId=... appId=... packageName=... uid=... isAnonymous=... profilePath=trainer_profiles/{uid} nickname=... realName=... onboardingCompleted=...
```

이메일, 전화번호, token은 기록하지 않는다.

## 로컬 저장 범위

이번 단계에서 직접 관련된 personal 설정만 `mtf_{projectId}_{uid}_{featureKey}` 형태로 분리했다.

- Home 시간표 시작·종료·기본 분·행별 분 설정
- Home 사용자 고정 인사
- Home 최근 문구·질문 노출 기록
- MyPage AI FC 프로필 nudge 진행 상태

legacy/debug key는 기존 값을 유지한다. 기존 운영 key를 삭제하거나 migration하지 않으며 새 환경 범위 key가 없으면 기존 기본값에서 시작한다. Android packageName도 dev/prod가 달라 OS 저장 공간 자체가 추가로 분리된다.

## 기존 값이 보이는 원인 판정

personal Home과 MyPage는 모두 `trainer_profiles/{currentUid}`를 읽는다. Home에 nickname이 표시되고 MyPage에 실명 등 과거 값이 보이면 UI fallback이 아니라 현재 Firebase project와 현재 UID의 같은 profile 문서에 값이 존재하는 경로다. 다만 실제 기기 UID가 과거 개발 UID와 같은지는 연결된 기기의 `[MTF_ENV_IDENTITY]` 로그 없이는 확정하지 않는다.

