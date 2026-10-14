# 회원 데이터 완성도 기준

기준일: 2026-07-16

## 2026-07-16 Anonymous Beginner 회원 구현 기준

- 신규 personal 회원은 Function transaction에서 이름, `male`/`female` 성별, 숫자로 정규화한 9~15자리 전화번호, 활동 지역이 모두 있어야 유효 회원으로 등록된다.
- 별도 전화번호 claim 문서를 만들지 않는다. Function transaction에서 `trainerId + workspaceType + phoneNormalized` 조건으로 기존 canonical member를 조회하고 같은 workspace의 중복만 `duplicate_member`로 거부한다.
- 전화번호 원문이나 정규화값을 문서 ID 또는 전역 path에 사용하지 않는다. 서로 다른 trainer UID의 동일 전화번호는 현재 단계에서 허용한다.
- `members/{memberId}.trainerId`는 요청값이 아니라 현재 Auth UID로 고정하고, legacy 회원이나 다른 trainer 회원을 신규 UID에 포함하지 않는다.
- 최초 자격 취득 때만 `lifetimeQualifiedMemberCount`를 올린다. 이후 휴면·만료·삭제 또는 재활성화는 이 누적값과 달성 등급을 낮추거나 다시 올리지 않는다.
- 익명 Beginner는 10번째 유효 회원까지 저장할 수 있다. 11번째부터 non-anonymous provider 연결과 아래 프로필 완성 조건을 모두 요구한다.

## 누적 유효 회원 후보 기준

한 회원은 다음 조건을 모두 만족할 때 한 번만 누적 유효 회원 후보가 된다.

- `memberId`가 비어 있지 않다.
- `trainerId`가 현재 workspace의 Auth UID와 같다.
- 이름이 비어 있지 않다.
- 정규화된 전화번호가 비어 있지 않다.
- 성별 입력이 완료됐다.
- 활동 지역 또는 주소 정책상 필수값이 완료됐다.
- 삭제, 임시, 테스트 문서가 아니다.

현재 신규 personal workspace의 중복 판정은 정규화된 전화번호를 사용한다. 같은 전화번호의 여러 카드는 허용하지 않는다. `memberAccountId` 기반 병합은 이번 단계에서 구현하지 않았고, 민감한 건강·통증 정보는 등급 계산에 사용하지 않는다.

## 프로필 완성도 후보 기준

출시 1차의 내 정보 필수값은 다음과 같다.

- 이름 또는 활동명
- 연락처
- 활동 지역
- 주 활동 종목
- 소속 형태: 프리랜서, 센터 소속, 개인샵

상세 주소는 필수로 만들지 않는다. 완성도는 공통 pure function으로 표현할 수 있지만, 등급 확정값은 서버가 검증해야 한다.

## 현재 데이터와의 간극

- legacy `HomePage`의 빠른 회원 저장은 이름·전화번호 중심이며 `trainerId`, 성별, 지역을 강제하지 않는다.
- personal managed member Function은 신규·정상 수정 경로에서 위 누적 자격 기준과 중복 방지를 보장한다. legacy 직접 저장 경로에는 소급 적용하지 않는다.
- legacy 회원의 owner를 추정하거나 새 UID로 자동 귀속해서는 안 된다.

따라서 기존 문서를 새 등급 계산에 즉시 포함하지 않는다. canonical owner와 필수 필드가 확정된 신규·정상 수정 경로부터 서버가 자격을 판정하고, legacy 보강은 별도 승인 작업으로 다룬다.
# 2026-07-17 선생님 내 정보 완성도

- personal 승급용 선생님 내 정보 필수 항목은 이름/활동명, 연락처, 활동 지역, 주 활동 종목, 소속 형태의 다섯 개다.
- 소속 형태의 UI 선택값은 `freelancer`, `center`, `personal_shop`이다.
- 상세 주소, 프로필 이미지, 소개, 경력, 센터명, SNS는 선택 항목이며 `profileComplete` 조건에 포함하지 않는다.
- client는 누락 항목만 안내하고 다섯 필드를 `updatePersonalTrainerProfile`에 전달한다. 최종 `profileCompleted`는 서버가 판정한다.
