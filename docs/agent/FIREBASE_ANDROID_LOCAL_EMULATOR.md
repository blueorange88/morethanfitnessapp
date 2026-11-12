# Android 실기기 Firebase Local Emulator 실행

작성일: 2026-07-17
범위: Debug APK의 Anonymous personal 출시 흐름 수동 검증

## 안전 경계

- `--dart-define=USE_FIREBASE_EMULATORS=true`와 Debug 모드가 모두 충족될 때만 연결한다.
- Auth `localhost:9099`, Firestore `localhost:8080`, Functions `localhost:5001`을 Firebase 초기화 직후 연결한다.
- Android 실기기는 `adb reverse`를 사용하므로 FlutterFire의 Android `10.0.2.2` 자동 치환을 끄고 `localhost`를 유지한다.
- Functions instance는 `asia-northeast3`을 유지한다.
- Profile/Release에서는 define이 true여도 `kDebugMode=false`라 연결 코드 진입 전에 반환한다.
- 연결 또는 첫 Auth/Functions 요청이 실패하면 production으로 전환하지 않는다. 시작 오류 화면을 유지한다.
- Storage는 이번 Debug 연결 대상이 아니다. Storage 기능은 이 검증에서 사용하지 않는다.

## 실행 순서

PowerShell 1 — 프로젝트 루트에서 Local Emulator Suite 실행:

```powershell
Set-Location C:\src\mtf_app
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"
npx.cmd firebase emulators:start --project more-than-fitness-f6adb --only auth,firestore,functions
```

이 명령은 로컬 Emulator만 시작한다. `firebase deploy`는 실행하지 않는다.

PowerShell 2 — USB 실기기 포트 연결과 앱 실행:

```powershell
Set-Location C:\src\mtf_app
adb devices
adb reverse tcp:9099 tcp:9099
adb reverse tcp:8080 tcp:8080
adb reverse tcp:5001 tcp:5001
adb reverse --list
flutter run --debug --dart-define=USE_FIREBASE_EMULATORS=true
```

특정 기기가 여러 대면 `adb -s <SERIAL> reverse ...`와 `flutter run -d <SERIAL> ...`을 사용한다.

## 실기기 확인

- 화면 왼쪽 위에 작은 `LOCAL EMULATOR` 표시가 보인다.
- 새 설치 또는 앱 데이터 삭제 후 Anonymous UID와 Beginner profile이 Emulator에만 생성된다.
- 회원 생성, 일정, 레슨일지 동작이 Emulator UI의 동일 UID personal workspace에만 나타난다.
- 앱 시작 전에 Emulator 또는 `adb reverse`가 준비되지 않으면 시작 오류 화면을 표시하며 실제 Firebase 데이터 화면으로 넘어가지 않는다.
- define 없이 실행한 Debug와 Profile/Release에는 `LOCAL EMULATOR` 표시가 없다.

## 종료

앱 종료 후 필요하면 해당 실기기의 reverse 설정만 제거한다.

```powershell
adb reverse --remove tcp:9099
adb reverse --remove tcp:8080
adb reverse --remove tcp:5001
```

Emulator 데이터는 로컬 임시 데이터다. 실제 Firebase deploy, export, Rules/Functions/Storage 변경은 이 절차에 포함하지 않는다.
