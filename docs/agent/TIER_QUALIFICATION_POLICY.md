# 등급 자격 정책

## 2026-07-16 Anonymous 회원 등급 권위 구현

- `createManagedMember`, `updateManagedMember`, `transitionAnonymousProfileToLinked`, `updatePersonalTrainerProfile`의 transaction이 `lifetimeQualifiedMemberCount`, `accountLinked`, `profileCompleted`, `tier`, `earnedTier`, `earnedTierRank`를 갱신한다.
- 익명 Beginner는 누적 10명이어도 Beginner를 유지한다. 같은 UID에 non-anonymous provider가 연결되고 내 정보가 완료되면 10명에서 Amateur로 승급한다.
- 누적 30명은 Semi-Pro, 50명은 Pro로 승급한다. 11번째 저장부터는 계정 연결과 내 정보 완료가 선행되므로 정상 생성 경로에서는 두 조건을 충족한 workspace만 30명·50명에 도달한다.
- 현재 등급과 새 계산 등급 중 높은 값을 저장해 휴면·만료·삭제 후 자동 강등하지 않는다.
- 후원 필드는 평가 함수의 입력에 포함하지 않는다. 기존 계약서·전자서명의 Semi-Pro gate는 변경하지 않았다.
- 클라이언트는 표시만 하며 등급과 누적값을 직접 쓰지 못한다.

## 2026-07-16 identity 기반 필드 기록

- anonymous profile은 서버에서 `tier=Beginner`, `managedMemberLimit=10`, `managedMemberCount=0`, `lifetimeQualifiedMemberCount=0`으로 시작한다.
- 이메일 provider 연결로 profile이 `local`에서 `linked`로 전환돼도 tier와 count는 변경하지 않는다.
- 당시 `managedMemberLimit`은 기반 필드였고, 현재는 위 Function transaction으로 10/30/50명 승급 정책을 구현했다.
- 후원은 계속 등급 source of truth와 분리해야 한다.

기준일: 2026-07-16

## 목표 정책

- Beginner: 기본 등급.
- Amateur: 누적 유효 회원 10명 이상, 내 정보 필수 항목 완료, non-anonymous provider 1개 이상 연결을 모두 만족.
- Semi-Pro: 누적 유효 회원 30명 이상. 계약서와 전자서명의 기존 Semi-Pro gate를 유지한다.
- Pro: 누적 유효 회원 50명 이상.
- 한 번 획득한 earned tier는 회원의 휴면·만료 등으로 자동 하락하지 않는다.
- 후원 여부와 후원 혜택은 earned tier 계산에서 분리한다.

## 권위와 갱신

- 클라이언트가 회원 문서를 조회해 등급을 확정해서는 안 된다.
- 회원 생성·유효성 변경과 프로필 완성도 변경 시 서버 transaction이 자격을 다시 계산해야 한다.
- 서버는 현재 Auth UID, owner-scoped 회원, 계정 provider 상태만 사용해야 한다.
- 최소 저장 후보는 `earnedTier`, `earnedTierRank`, `cumulativeQualifiedMemberCount`, `profileCompleted`, `accountLinked`, `tierEvaluatedAt`이다. 정확한 필드명은 Functions와 Rules 설계 작업에서 확정하며 이번 감사에서 추가하지 않는다.

## legacy 등급 계산과의 차이

- 현재 `AppTierAccessService`는 legacy `trainer_profile/me`에서 active member 수, 카카오 연동 수, 계약 수, stored tier, organization tier, support tier를 읽어 최댓값을 클라이언트에서 계산한다.
- 현재 Amateur는 카카오 연결 또는 프로필 완료 중 하나만으로 가능하며, 요청한 세 조건의 AND 규칙이 아니다.
- 현재 `isSponsor`는 최소 Semi-Pro로 올릴 수 있어 후원과 earned tier가 분리되지 않는다.
- 현재 `managedMemberCount`는 관리 중 active/paused 회원 10명 제한용이며, 누적 유효 회원 자격 원장이 아니다.

따라서 legacy `AppTierAccessService` 계산은 신규 personal workspace의 source of truth가 아니다. 신규 경로는 서버 권위 구현과 Emulator 검증을 완료했지만 legacy 등급 표시 통합은 별도 작업이다.
# 2026-07-17 personal 등급 카드

- personal 카드는 `trainer_profiles/{uid}.tier`와 `lifetimeQualifiedMemberCount`를 그대로 표시한다. legacy tier, organization tier, support tier, 후원값, 카카오 연결 수를 합산하지 않는다.
- 필수 다섯 필드의 채움 수는 진행 안내용 UI 값이다. `profileCompleted`, 누적 count, tier 판정과 쓰기는 계속 Functions transaction만 수행한다.
- Beginner는 10명과 provider/profile 조건, Amateur는 30명, Semi-Pro는 50명까지의 남은 조건을 안내하고 Pro는 완료 문구를 표시한다. 실제 현재 등급은 client가 재계산해 덮어쓰지 않는다.
# 2026-07-17 시작 gate 제거 회귀

- 시작 라우팅은 tier를 계산하거나 쓰지 않는다. canonical profile의 서버 tier를 그대로 사용한다.
- linked personal 재진입 조건에서 `tier == Beginner` 제한만 제거했다. Amateur/Semi-Pro/Pro도 동일 owner/workspace 조건으로 홈에 들어가며 승급 transaction, 후원 분리, 계약서 Semi-Pro gate는 변경하지 않았다.

# 2026-07-20 Beginner→Amateur reconcile

- `reconcilePersonalTier`가 현재 Auth UID의 personal profile을 transaction에서 다시 검증한다.
- 화면의 두 조건은 `lifetimeQualifiedMemberCount >= 10`과 `non-anonymous provider 연결 + 선생님 내 정보 완료`이다. 일정 수는 Amateur 자격 조건이 아니다.
- 조건 충족 시 Beginner만 Amateur로 승급하며 이미 Amateur 이상인 등급은 유지하고 downgrade하지 않는다.
- 성공 시 `tier`, `tierUpdatedAt`, 최초 `amateurAchievedAt`, `tierTransitionSource`만 갱신한다. 다른 profile 및 legacy 등급 필드는 변경하지 않는다.
