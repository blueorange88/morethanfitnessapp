// 레슨계약서 v2 P6-6: 완료된 계약서 해지.
//
// 해지는 환불을 처리하는 기능이 아니라 "이 계약이 언제, 왜, 어떤 상태에서 끝났는지"를 남기는 기록이다.
// 환불 계산·송금은 하지 않는다(강사와 회원이 따로 정한다). 처리는 다음과 같다.
// - 완료된 계약만, 기간 제한 없이 해지할 수 있다. 회원의 가장 최근 완료 계약만 해지한다
//   (재계약 횟수가 합산되므로 이전 계약만 따로 끝낼 수 없다).
// - 회원 서명은 **선택**이다. 서명이 유효하면 증빙 등급 `member_signed`, 없으면 `trainer_only`.
// - 서버가 해지 시각과 그 시점의 총·소진·잔여 횟수 스냅샷을 남긴다. 이벤트는 추가만 한다.
// - 해지하면 회원의 레슨 등록을 **항상 0으로 되돌린다**(총·잔여·소진 횟수 0, `레슨 미등록`, 마지막 등록
//   기록 삭제). 다시 등록하면 0에서 새로 시작한다. 해지 시점의 값은 계약서 `termination.snapshot`에
//   남는다. 입력의 `zeroRemain`은 예전 앱과의 호환을 위해 받기만 하고 무시한다(2026-11-01 결정).
// - 강사가 고르면 회원을 만료로 옮긴다(`markExpired`, 기본은 하지 않는다).
// - 해지하면 계약서는 `terminated`가 되고(삭제하지 않는다), 이미 해지된 계약을 다시 해지해도 안전하다.
// - 회원에게 갈 해지 알림 한 건을 `contract_notices`에 남긴다(발송은 나중에 붙인다).
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";

import {
  CONTRACT_NOTICES,
  buildContractTerminateNotice,
} from "./lesson_progress_notice.js";
import {kstDateString} from "./membership_expiry.js";
import {readMemberSessions} from "./personal_contract_registration.js";
import {validateStrokes} from "./personal_contract_rules.js";
import {
  CONTRACTS,
  Ctx,
  Data,
  Db,
  allowOnly,
  loadOwnedContract,
  objectData,
  requireContractId,
  requireOwnedMember,
  requireProfile,
  requireUid,
  summary,
  translated,
} from "./personal_contracts.js";

export const TERMINATE_REASONS = [
  "member_request",
  "trainer_reason",
  "other",
] as const;
export const TERMINATE_CHANNELS = [
  "verbal",
  "sms",
  "kakao",
  "visit",
  "other",
] as const;
export type TerminateEvidence = "member_signed" | "trainer_only";

const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/u;

function count(value: unknown): number {
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : 0;
}

function record(value: unknown): Data {
  return value != null && typeof value === "object" && !Array.isArray(value) ?
    (value as Data) :
    {};
}

function invalid(code: string): never {
  throw new functions.https.HttpsError("invalid-argument", code);
}

function fail(code: string): never {
  throw new functions.https.HttpsError("failed-precondition", code, {code});
}

function pick<T extends string>(
  value: unknown,
  allowed: readonly T[],
  code: string,
): T {
  if (typeof value !== "string" || !allowed.includes(value as T)) {
    invalid(code);
  }
  return value as T;
}

function flag(value: unknown, code: string): boolean {
  if (value == null) return false;
  if (typeof value !== "boolean") invalid(code);
  return value;
}

// 'YYYY-MM-DD' 실제 존재하는 날짜인지(2026-02-31 같은 값 거부).
function validDate(value: string): boolean {
  if (!DATE_PATTERN.test(value)) return false;
  const parsed = new Date(`${value}T00:00:00Z`);
  return !Number.isNaN(parsed.getTime()) &&
    parsed.toISOString().slice(0, 10) === value;
}

export function createTerminatePersonalContractHandler(
  db: Db,
  options: {now?: () => Date} = {},
) {
  const nowDate = options.now ?? (() => new Date());
  return async (raw: unknown, ctx: Ctx) => {
    const uid = requireUid(ctx);
    const data = objectData(raw);
    allowOnly(data, [
      "contractId",
      "reasonCode",
      "reasonNote",
      "noticeChannel",
      "noticeDate",
      "zeroRemain",
      "markExpired",
      "strokes",
    ]);
    const contractId = requireContractId(data);
    const reasonCode = pick(data.reasonCode, TERMINATE_REASONS, "reasonCode_invalid");
    const noticeChannel = pick(
      data.noticeChannel,
      TERMINATE_CHANNELS,
      "noticeChannel_invalid",
    );
    const reasonNote = typeof data.reasonNote === "string" ?
      data.reasonNote.trim() : "";
    if (reasonNote.length > 200) invalid("reasonNote_invalid");
    if (reasonCode === "other" && reasonNote.length < 2) {
      invalid("reasonNote_required");
    }
    const noticeDate = typeof data.noticeDate === "string" ?
      data.noticeDate.trim() : "";
    if (!validDate(noticeDate)) invalid("noticeDate_invalid");
    flag(data.zeroRemain, "zeroRemain_invalid"); // 예전 앱 호환: 값은 무시한다
    const markExpired = flag(data.markExpired, "markExpired_invalid");
    try {
      const strokes = data.strokes == null ? null : validateStrokes(data.strokes);
      const contractRef = db.collection(CONTRACTS).doc(contractId);
      const profileRef = db.collection("trainer_profiles").doc(uid);

      return await db.runTransaction(async (transaction) => {
        // 읽기는 모두 쓰기보다 먼저.
        const [profileSnap, contractSnap] = await Promise.all([
          transaction.get(profileRef),
          transaction.get(contractRef),
        ]);
        requireProfile(uid, profileSnap, ctx);
        const contract = loadOwnedContract(uid, contractSnap);
        if (contract.status === "terminated") {
          return {alreadyTerminated: true, ...summary(contractId, contract)};
        }
        if (contract.status !== "completed") {
          fail("terminate_requires_completed");
        }
        const completedAt = contract.completedAt instanceof Timestamp ?
          contract.completedAt.toDate() :
          null;
        if (completedAt == null) fail("terminate_requires_completed");

        // 해지 의사표시 날짜는 계약 완료일 이전이거나 오늘 이후일 수 없다(한국 날짜 기준).
        const now = nowDate();
        if (noticeDate > kstDateString(now) ||
            noticeDate < kstDateString(completedAt)) {
          invalid("noticeDate_out_of_range");
        }

        const memberId = String(contract.memberId);
        const memberRef = db.collection("members").doc(memberId);
        const [memberSnap, othersSnap] = await Promise.all([
          transaction.get(memberRef),
          transaction.get(
            db.collection(CONTRACTS)
              .where("trainerId", "==", uid)
              .where("memberId", "==", memberId)
              .where("status", "==", "completed"),
          ),
        ]);
        requireOwnedMember(uid, memberId, memberSnap);
        const member = memberSnap.data() ?? {};

        // 더 나중에 완료된 계약이 있으면 이 계약만 따로 해지할 수 없다.
        const thisAt = completedAt.getTime();
        const hasNewer = othersSnap.docs.some((doc) => {
          if (doc.id === contractId) return false;
          const at = doc.data().completedAt;
          return at instanceof Timestamp && at.toMillis() > thisAt;
        });
        if (hasNewer) fail("terminate_not_latest");

        // ---- 그 시점의 횟수 스냅샷 ----
        const current = readMemberSessions(member);
        const sessions = record(member.sessions);
        const done = count(member.doneSessions ?? sessions.done);
        const snapshot = {
          total: current.total,
          done,
          remain: current.remain,
        };

        // ---- 회원 문서 ----
        const stamp = FieldValue.serverTimestamp();
        const memberUpdate: Data = {
          // 계약이 끝났으니 홈이 '계약 미완료'로 보게 한다. 계약 번호·연결은 기록으로 남긴다.
          contractSigned: false,
          contractStatus: "terminated",
          contractTerminatedAt: stamp,
        };
        // 레슨 등록을 0으로 되돌린다(`zeroRemain` 입력과 상관없이 항상). 카드는 저장할 때 소진을
        // 총-잔여로 다시 계산하므로 소진 횟수도 함께 0으로 맞춘다.
        Object.assign(memberUpdate, {
          "totalSessions": 0,
          "remainSessions": 0,
          "remainingSessions": 0,
          "doneSessions": 0,
          "sessions.total": 0,
          "sessions.remain": 0,
          "sessions.done": 0,
          "sessions.notRegistered": true,
          "lessonsNotRegistered": true,
          "lastRegistration": FieldValue.delete(),
        });
        let expired = false;
        if (markExpired && member.managementState === "active") {
          expired = true;
          Object.assign(memberUpdate, {
            managementState: "expired",
            countsTowardLimit: false,
            managementStateHistory: FieldValue.arrayUnion({
              previousState: "active",
              nextState: "expired",
              changedAt: Timestamp.now(),
              changedBy: uid,
              source: "contract_terminate",
              contractId,
            }),
          });
        }
        memberUpdate.updatedAt = stamp;
        transaction.update(memberRef, memberUpdate);
        if (expired && profileSnap.exists) {
          const managed = Number(profileSnap.data()?.managedMemberCount ?? 0);
          transaction.update(profileRef, {
            managedMemberCount: Math.max(0, managed - 1),
            usageUpdatedAt: stamp,
            updatedAt: stamp,
          });
        }

        // ---- 계약서·이벤트 ----
        const evidence: TerminateEvidence =
          strokes != null ? "member_signed" : "trainer_only";
        let signEventId: string | null = null;
        if (strokes != null) {
          const signEventRef = contractRef.collection("events").doc();
          signEventId = signEventRef.id;
          transaction.create(signEventRef, {
            type: "terminate_signed",
            at: stamp,
            actorRole: "member",
            contentHash: String(contract.contentHash ?? ""),
            payload: {strokes},
          });
        }
        const termination = {
          reasonCode,
          reasonNote,
          noticeChannel,
          noticeDate,
          evidence,
          snapshot,
          zeroedRemain: true,
          markedExpired: expired,
        };
        transaction.create(contractRef.collection("events").doc(), {
          type: "terminated",
          at: stamp,
          actorRole: "trainer",
          contentHash: String(contract.contentHash ?? ""),
          payload: {previousStatus: "completed", ...termination},
        });
        const contractUpdate: Data = {
          "status": "terminated",
          "terminatedAt": stamp,
          termination,
          "updatedAt": stamp,
        };
        if (signEventId != null) {
          contractUpdate["signatures.terminate"] = {
            eventId: signEventId,
            signedAt: stamp,
          };
        }
        transaction.update(contractRef, contractUpdate);

        const memberName = String(record(contract.member).name ?? "").trim();
        const version = Number(contract.version ?? 1);
        const no = String(contract.contractNo ?? "");
        const notice = buildContractTerminateNotice({
          trainerId: uid,
          memberId,
          memberName,
          contractId,
          contractNo: version > 1 ? `${no}-v${version}` : no,
          reason: reasonNote === "" ? reasonCode : reasonNote,
        });
        if (notice != null) {
          transaction.set(
            db.collection(CONTRACT_NOTICES).doc(`${contractId}_terminate`),
            {...notice, createdAt: stamp},
          );
        }
        return {
          alreadyTerminated: false,
          evidence,
          snapshot,
          zeroedRemain: true,
          markedExpired: expired,
          ...summary(contractId, {...contract, status: "terminated"}),
        };
      });
    } catch (error) {
      return translated(error, "terminate");
    }
  };
}
