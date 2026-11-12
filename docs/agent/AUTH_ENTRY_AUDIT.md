# 계정 진입 감사

감사일: 2026-07-15

## 변경 전 진입 흐름

- `main.dart`는 Firebase 초기화 후 모바일에서 바로 `SplashRouter`를 열었다.
- `SplashRouter`는 인증 사용자를 확인하지 않고 고정 문서 `trainer_profile/me`의 존재 여부만으로 온보딩 또는 홈을 선택했다.
- 온보딩도 `trainer_profile/me`에 직접 저장했다.
- 저장소에는 Firebase Auth 로그인, 로그아웃, `authStateChanges` 기반 진입 gate가 없었다.
- 로컬 설정에는 테마·알림 등 설정 키가 있었지만 계정 진입을 안전하게 판별하는 first-run/auth 키는 없었다.

## 현재 진입 흐름

```text
앱 시작
→ Firebase Auth 상태 확인
├─ 미로그인 또는 익명 user: Guest 시작 화면
│  ├─ 정적 Guest Beginner 미리보기
│  └─ 이메일 가입·로그인
└─ 이메일 계정
   → trainer_profiles/{uid} 읽기 전용 확인
   ├─ trainerId == uid && legacyDataAccessApproved == true: 기존 SplashRouter
   └─ 그 외: 운영 데이터 연결 대기 화면
```

- 첫 실행에서 로그인을 강제하지 않는다.
- Guest 미리보기는 코드에 포함된 예시 일정·회원·레슨일지만 표시한다. Firestore, Storage, Functions와 기존 홈/회원관리/계약 화면을 호출하지 않는다.
- Firebase 익명 user는 Guest로 취급하며 최종 계정이나 canonical trainer identity로 사용하지 않는다.
- 이메일 가입·로그인·비밀번호 재설정·로그아웃은 `firebase_auth` adapter를 통해 수행한다.
- 가입 성공은 Auth 계정 생성과 이메일 확인 발송 결과를 분리한다. 프로필 저장 실패를 가입 성공으로 숨기는 코드는 두지 않았다.
- 현재 단계에서는 `trainer_profiles/{uid}`를 생성하거나 기존 `trainer_profile/me`를 복사하지 않는다.
- 명시적인 `legacyDataAccessApproved`가 없는 신규 계정은 기존 운영 데이터 화면으로 진입하지 못한다.

## Google 로그인 감사

- `firebase_auth`는 기존 의존성이다.
- `google_sign_in` 의존성은 없다.
- Android applicationId는 `com.example.mtf_app`이다.
- `android/app/google-services.json` 파일 존재는 확인했으나 비밀값은 읽거나 출력하지 않았다.
- Firebase Console의 Google provider 활성화와 SHA-1/SHA-256 등록은 저장소만으로 확인할 수 없다.
- 새 패키지를 추가하지 않았고, Google 버튼은 설정 준비 중 오류만 안내한다. 인증 성공으로 가장하지 않는다.

## 남은 위험

- 저장소의 현재 Firestore Rules에는 `trainer_profiles/{uid}` 허용 규칙이 없다. 따라서 실제 프로젝트에서도 동일하면 계정 연결 확인은 `permission-denied`가 되고 안전한 대기 화면에 머문다.
- 배포된 Rules, 이메일/비밀번호 provider, 이메일 발송, 실제 기기 네트워크 동작은 이번 로컬 검증으로 확인하지 않았다.
- UID 프로필 생성 정책, 기존 데이터 소유권 승인, tenant migration은 별도 후속 작업이다.
- 기존 `SplashRouter`와 온보딩의 `trainer_profile/me` 사용은 승인된 legacy 진입 뒤에만 남아 있으며 이번 단계에서 구조를 변경하지 않았다.

