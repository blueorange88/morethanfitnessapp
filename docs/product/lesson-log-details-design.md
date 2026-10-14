# 레슨일지 세부 기록(details) 저장 설계 (2026-10-11)

## 문제
`PersonalTrainingLogPage`의 작성 방식(텍스트·카테고리) 에디터 결과는 화면 메모리(`_TrainingLogItem`)에만 담기고 서버에 저장되지 않는다. 서버(`training_logs`)의 personal 문서는 `memo`·`lessonType`·`startAt` 등 몇 필드만 허용하고(firestore.rules), 이 화면은 서버에서 다시 읽어오는 것도 빠른 서명·아나토미 일지뿐이다. 그래서 제목·체크·특이사항·숙제·운동 구성이 앱을 나가면 사라진다(2026-10-11 폰에서 확인).

## 구조
`training_logs/{id}`에 `details`(map) 필드를 추가한다. 기존 필드와 `memo`는 그대로다. 초안(`status == 'draft'`)일 때만 클라이언트가 쓸 수 있고, 확정 후에는 규칙이 막는다.

- 최상위: `v`(=1), `title`, `inputMethod`, `rawVoiceText`, `issueChips[]`, `homeworkStatus`, `nextLessonCheckpoint`, `exercises[]`
- `pre`: condition, meal, sleep, pain, painDetail, stretching, note
- `during`: goals[], focusParts[], reactions[], painDetail, focusResponse, cognitiveResponse, performanceResponse
- `post`: painChange, painDetail, performance, nextAction, homework
- `notes`: internal, publicSummary, publicGood, publicHomeworkNote, publicCaution
- `exercises[]` 항목: main, part, name, sets, reps, assist, note

에디터의 평면 map ↔ 이 구조 변환은 `lib/models/personal_training_log_details.dart`가 맡는다(길이·개수 제한 포함).

## 규칙 설계 메모
- Firestore Rules는 요청당 평가 횟수가 제한된다. 필드마다 크기를 검사하면 키가 19개를 넘을 때 거절된다(에뮬레이터로 확인). 그래서 최상위 8개 항목만 크기·타입을 검사하고, 체크 항목은 `pre/during/post/notes` 묶음으로 나눠 묶음마다 허용 키만 검사한다.
- 묶음 안 값의 길이는 규칙이 아니라 앱(`personal_training_log_details.dart`)이 제한한다. 규칙은 키 집합과 묶음 타입만 막는다. 개인 워크스페이스의 본인 문서라 남용 위험은 본인 저장공간에 한정된다.
- 필드 변경이 필요하면 `v`를 올리고 호환 변환을 추가한다.

## 진행 단계
1. (완료) 규칙 + 에뮬레이터 테스트 + 모델/저장소/변환 + 단위 테스트
2. (대기) `PersonalTrainingLogPage` 에디터 저장을 저장소(`createDraft`/`autosave`)에 연결하고, 열 때 서버의 일지를 목록에 불러와 `details`를 복원
3. (대기) 이 화면의 확정·확정취소를 저장소의 `finalize`/`cancelFinalize`(서버 함수)에 연결 — 현재 직접 쓰기는 personal 규칙과 맞지 않을 가능성이 있음(점검 필요)
4. (대기) 시작 전 체크 공용 위젯·요약 카드·특이사항, 최근 사용/자주 쓰는 순, 통계

## 배포
Firestore Rules 변경이라 DEV 배포 → 확인 → 사용자 승인 후 PROD 순서로 한다. 앱이 규칙보다 먼저 나가면 `details` 쓰기가 거절되므로 항상 규칙을 먼저 배포한다.
