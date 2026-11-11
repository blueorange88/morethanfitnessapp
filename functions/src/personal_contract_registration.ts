// 레슨계약서 v2 P6-3: 계약이 완료되면 회원의 레슨 횟수(총·잔여)에 계약 횟수를 합산해 등록한다.
//
// - 재계약(새 계약)은 기존 잔여 횟수에 **더한다**(총 30·잔여 1 + 새 계약 30 → 총 60·잔여 31).
// - 새 버전(정정)은 이전 완료 계약이 이미 등록한 횟수와의 **차이만** 반영해 이중으로 더하지 않는다.
// - 이미 소진한 횟수(done)와 다른 필드는 건드리지 않는다.
// 홈·빠른 서명·레슨 확정이 읽는 필드(루트 `totalSessions`·`remainSessions`·`remainingSessions`,
// `sessions.*`, `lessonType`, `lessonsNotRegistered`)를 예전 계약서와 같은 이름으로 쓴다.
import {FieldValue} from "firebase-admin/firestore";

type Data = Record<string, unknown>;

function count(value: unknown): number {
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : 0;
}

function record(value: unknown): Data {
  return value != null && typeof value === "object" && !Array.isArray(value) ?
    (value as Data) :
    {};
}

export interface MemberSessionCounts {
  total: number;
  remain: number;
}

// 회원 문서에서 총·잔여 횟수를 읽는다(홈 레슨 확정이 읽는 순서와 같다).
export function readMemberSessions(member: Data): MemberSessionCounts {
  const sessions = record(member.sessions);
  const total = count(
    member.totalSessions ?? sessions.total ?? member.sessionTotal,
  );
  const remain = count(
    member.remainSessions ??
    member.remainingSessions ??
    sessions.remain ??
    member.remainingPt ??
    member.ptRemaining,
  );
  return {total, remain};
}

// 상품명에서 레슨 종류를 뽑는다. 알 수 없으면 `레슨`(홈이 `미입력`을 `레슨`으로 보여 주는 것과 같다).
export function lessonTypeFromProductName(name: string): string {
  const text = name.trim();
  const lower = text.toLowerCase();
  if (text.includes("필라테스")) return "필라테스";
  if (text.includes("골프")) return "골프";
  if (text.includes("요가")) return "요가";
  if (text.includes("댄스")) return "댄스";
  if (text.includes("발레")) return "발레핏";
  if (lower.includes("pt") || text.includes("피티")) return "PT";
  return "레슨";
}

export interface RegistrationResult {
  // 회원 문서에 `transaction.update`로 쓸 값(점 표기 포함).
  memberUpdate: Data;
  // 계약 문서의 `registration`에 기록할 값.
  registration: {
    // 이 계약이 등록한 횟수(= 계약 횟수). 다음 새 버전이 이 값과의 차이만 반영한다.
    registered: number;
    // 등록 직후의 받은 레슨 횟수. 파기할 때 그 뒤에 레슨을 받았는지 가리는 기준이다.
    doneAtRegistration: number;
    // 이번 완료로 회원 횟수에 더해진 양(정정이면 음수일 수 있다).
    added: number;
    totalAfter: number;
    remainAfter: number;
    // 이미 횟수가 있던 회원의 새 계약(재등록)이라 카드 뒷면 `재등록` 횟수를 1 올렸는지.
    reregistration: boolean;
  };
}

/**
 * 계약 완료 시 회원에게 등록할 횟수를 계산한다.
 * @param {Data} member 회원 문서의 현재 값
 * @param {{name: string, sessionCount: number}} product 완료되는 계약의 상품
 * @param {number} alreadyRegistered 정정 대상 이전 계약이 이미 등록한 횟수(새 계약이면 0)
 * @param {{contractId: string, contractNo: string}} contract 완료되는 계약
 * @return {RegistrationResult} 회원 문서 갱신 값과 계약에 남길 기록
 */
export function buildRegistration(
  member: Data,
  product: {name: string; sessionCount: number},
  alreadyRegistered: number,
  contract: {contractId: string; contractNo: string},
): RegistrationResult {
  const current = readMemberSessions(member);
  const added = count(product.sessionCount) - count(alreadyRegistered);
  const totalAfter = Math.max(0, current.total + added);
  const remainAfter = Math.max(0, current.remain + added);
  const sessions = record(member.sessions);
  const done = count(member.doneSessions ?? sessions.done);

  const existingType = String(member.lessonType ?? "").trim();
  const keepType = existingType !== "" && existingType !== "미입력";
  const lessonType = keepType ?
    existingType :
    lessonTypeFromProductName(product.name);

  const memberUpdate: Data = {
    "totalSessions": totalAfter,
    "remainSessions": remainAfter,
    "remainingSessions": remainAfter,
    "doneSessions": done,
    "sessions.total": totalAfter,
    "sessions.remain": remainAfter,
    "sessions.done": done,
    "sessions.notRegistered": totalAfter <= 0,
    "lessonsNotRegistered": totalAfter <= 0,
    lessonType,
    "contractLessonType": lessonType,
    "lastRegistration": {
      contractId: contract.contractId,
      contractNo: contract.contractNo,
      added,
      totalAfter,
      remainAfter,
      at: FieldValue.serverTimestamp(),
    },
  };
  // 재등록: 이미 등록된 횟수가 있던 회원이 새 계약을 완료한 경우(정정인 새 버전은 제외).
  const reregistration =
    current.total > 0 && count(alreadyRegistered) === 0 && added > 0;
  if (reregistration) {
    memberUpdate["membership.reregisterCount"] = FieldValue.increment(1);
    memberUpdate["membership.lastReregisterAt"] =
      FieldValue.serverTimestamp();
  }
  return {
    memberUpdate,
    registration: {
      registered: count(product.sessionCount),
      doneAtRegistration: done,
      added,
      totalAfter,
      remainAfter,
      reregistration,
    },
  };
}
