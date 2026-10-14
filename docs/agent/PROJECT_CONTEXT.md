# PROJECT_CONTEXT

## 앱 개요
More Than Fitness는 한국 프리랜서 피트니스 강사를 위한 Flutter/Firebase 앱이다.

## 핵심 모듈
- 홈: Firestore `schedules` 기반 주간 스케줄러
- 회원관리: 회원리스트, 그룹, 회원카드
- 레슨일지: 텍스트/보이스, 카테고리, 아나토미 시제품
- 계약서: 레슨계약서, 회원권계약서, 서명
- 통계/알림/등급
- Android Glance 홈 위젯

## 기술
- Flutter/Dart
- Firebase Auth / Firestore / Storage / Functions
- Riverpod
- Android Kotlin / Jetpack Glance

## 중요 데이터 원칙
- 레슨 확정 상태: completed / no_show_deducted / no_show_not_deducted / service
- 차감 레슨은 잔여 횟수 감소
- 회원 데이터는 과거 루트 필드와 `sessions`, `lessonStats`, `membership` 중첩 필드가 함께 존재할 수 있다.
- 기존 데이터를 깨는 마이그레이션은 별도 승인 없이 하지 않는다.

## 알려진 현황
- `client_card_page.dart`의 `initState()` 닫는 중괄호 누락은 수정함.
- 홈 레슨 삭제 후 약 10초 뒤 되살아났다가 다시 사라지는 현상이 있었음.
- 주간 위젯의 현재시간 빨간 테두리가 표시 범위를 지난 뒤에도 마지막 시간에 남고, 자정 후에도 전날 하이라이트가 남는 현상이 있었음.
- 다음 레슨 위젯 관련 Flutter/Kotlin 파일은 이미 존재함.
- 아나토미는 UI 시제품이 있으나 실제 저장/영상/회원 연동은 미완성.
- Cloud Functions `src/index.ts`에는 중복 TypeScript와 Dart 코드 혼입 가능성이 확인됨.
- `test/widget_test.dart`는 기본 카운터 예제일 가능성이 높음.
