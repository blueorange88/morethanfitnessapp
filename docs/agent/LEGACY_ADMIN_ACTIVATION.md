# Legacy Admin 실제 활성화 체크리스트

이 문서는 후속 운영 작업용이다. 이번 작업에서는 아래 배포·계정 생성·데이터 변경을 실행하지 않았다.

1. 대상 Firebase 개발 프로젝트 ID를 사람이 콘솔에서 재확인한다. 운영 프로젝트와 혼동하지 않는다.
2. Firestore와 Storage를 백업하거나, 최소한 legacy 핵심 collection별 문서 건수와 Storage 객체 건수를 변경 불가능한 기록으로 남긴다.
3. Functions/Firestore Rules/Storage Rules 배포 diff를 검토한다. 광역 allow, 이메일 기반 관리자 판정, 원격서명 공개 allow가 없는지 확인한다.
4. 관리자 provisioning 스크립트를 `--dry-run`으로 실행한다. 비밀번호, service account 경로, token은 출력·기록하지 않는다.
5. 승인된 보안 환경에서 관리자 계정을 실제 생성한다. 임시 비밀번호는 숨김 입력으로만 전달한다.
6. Admin SDK에서 `platformAdmin: true`와 `legacyDataAccessApproved: true` 두 claim을 확인한다. profile 필드만으로 대체하지 않는다.
7. 검토 완료된 Functions와 Rules만 배포한다. 문제가 있으면 이전 Rules/Functions 버전으로 즉시 롤백한다.
8. 관리자 계정으로 로그인한다.
9. 최초 로그인에서 비밀번호 변경 화면 외 workspace 진입이 차단되는지 확인하고 비밀번호를 변경한다.
10. 로그아웃·재로그인 또는 강제 ID token refresh 후 두 claim이 새 token에 반영됐는지 확인한다.
11. `기존 개발 데이터` workspace에 진입하고 상단 표시가 보이는지 확인한다.
12. 기존 회원·일정·레슨일지·계약서의 기준 건수를 백업 기록과 비교한다.
13. 별도 샘플 1건을 수정한 뒤 재조회하고, 기존 문서 ID와 소유 필드가 바뀌지 않았는지 확인한다. 실제 데이터에서 삭제 테스트는 하지 않는다.
14. Guest, anonymous, 일반 Linked, claim 하나만 가진 테스트 계정에서 legacy Firestore/Storage 접근이 모두 거부되는지 확인한다.
15. 오류 발생 시 앱 배포와 Rules/Functions를 이전 버전으로 롤백하고 claim을 제거한 뒤 token을 폐기·갱신한다. 데이터 migration/backfill은 롤백 절차로 실행하지 않는다.

추가 확인:

- App Check 적용 여부와 callable Functions 보호 수준
- 기존 공개 download URL 노출 여부
- 원격서명 공개 흐름의 별도 인증·일회성 token 설계
- 실제 legacy 문서의 `workspaceType` 필드 분포
