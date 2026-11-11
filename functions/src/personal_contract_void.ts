// 레슨계약서 v2 P6: 완료된 계약서 파기.
//
// 잘못 써서 완료까지 한 계약서는 정정하지 않고 파기한다. 조건과 처리는 다음과 같다.
// - 계약이 완료된 지 [VOID_WINDOW_DAYS]일 이내에만 가능하다(그 뒤에는 환불·해지로 따로 진행).
// - 회원이 서명(파기 확인)해야 한다. 강사 서명은 받지 않는다.
// - 계약 뒤에 레슨을 한 번이라도 받았으면(횟수가 소진됐으면) 파기할 수 없다.
// - 파기하면 계약서는 \`voided\`가 되고(삭제하지 않는다), 이 계약이 더한 총·잔여 횟수와 재등록 횟수를
//   되돌리며, 회원 문서의 계약 연결 표시는 가장 최근의 다른 완료 계약으로 바꾸거나(없으면) 지운다.
// - 회원에게 갈 파기 알림 한 건을 \`contract_notices\`에 남긴다(발송은 나중에 붙인다).
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";

import {
  CONTRACT_NOTICES,
  buildContractVoidNotice,
} from "./lesson_progress_notice.js";
import {buildMembershipRestore} from "./membership_expiry.js";
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
  requiredString,
  summary,
  translated,
} from "./personal_contracts.js";

export const VOID_WINDOW_DAYS = 3;
const DAY_MS = 24 * 60 * 60 * 1000;

function count(value: unknown): number {
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) && n > 0 ? Math.floor(n) : 0;
}

function record(value: unknown): Data {
  return value != null && typeof value === "object" && !Array.isArray(value) ?
    (value as Data) :
    {};
}

function fail(code: string, message = code): never {
  throw new functions.https.HttpsError("failed-precondition", message, {code});
}

export function createVoidPersonalContractHandler(
  db: Db,
  options: {now?: () => Date} = {},
) {
  const nowDate = options.now ?? (() => new Date());
  return async (raw: unknown, ctx: Ctx) => {
    const uid = requireUid(ctx);
    const data = objectData(raw);
    allowOnly(data, ["contractId", "reason", "strokes"]);
    const contractId = requireContractId(data);
    const reason = requiredString(data, "reason", 200);
    if (reason.trim().length < 2) {
      throw new functions.https.HttpsError("invalid-argument", "reason_required");
    }
    try {
      const strokes = validateStrokes(data.strokes);
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
        if (contract.status === "voided") {
          return {alreadyVoided: true, ...summary(contractId, contract)};
        }
        if (contract.status !== "completed") {
          fail("void_requires_completed");
        }
        const completedAt = contract.completedAt instanceof Timestamp ?
          contract.completedAt.toDate() :
          null;
        if (completedAt == null) fail("void_requires_completed");
        if (nowDate().getTime() - completedAt.getTime() >
            VOID_WINDOW_DAYS * DAY_MS) {
          fail("void_window_passed");
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

        // ---- 횟수 되돌리기 ----
        const registration = record(contract.registration);
        const registered = count(registration.registered);
        const hasRegistration = contract.registration != null;
        const memberUpdate: Data = {};
        if (hasRegistration) {
          const lastRegistration = record(member.lastRegistration);
          if (String(lastRegistration.contractId ?? "") !== contractId) {
            // 이 계약 뒤에 다른 계약이 횟수를 더했으면 순서를 되돌릴 수 없다.
            fail("void_not_latest_registration");
          }
          const current = readMemberSessions(member);
          const sessions = record(member.sessions);
          const doneNow = count(member.doneSessions ?? sessions.done);
          const taken = registration.doneAtRegistration != null ?
            doneNow > count(registration.doneAtRegistration) :
            current.remain < count(registration.remainAfter);
          if (taken) fail("void_lessons_taken");

          const totalAfter = Math.max(0, current.total - registered);
          const remainAfter = Math.max(0, current.remain - registered);
          Object.assign(memberUpdate, {
            "totalSessions": totalAfter,
            "remainSessions": remainAfter,
            "remainingSessions": remainAfter,
            "sessions.total": totalAfter,
            "sessions.remain": remainAfter,
            "sessions.notRegistered": totalAfter <= 0,
            "lessonsNotRegistered": totalAfter <= 0,
            "lastRegistration": FieldValue.delete(),
          });
          if (registration.reregistration === true) {
            const reregisterCount = count(record(member.membership)
              .reregisterCount);
            memberUpdate["membership.reregisterCount"] =
              Math.max(0, reregisterCount - 1);
          }
        }

        // ---- 회원권 기간·상태 되돌리기 ----
        let deactivated = false;
        if (hasRegistration && registration.membershipBefore != null) {
          const restore = buildMembershipRestore(
            record(registration.membershipBefore),
            registration.reactivated === true,
            member,
          );
          Object.assign(memberUpdate, restore.update);
          deactivated = restore.deactivated;
        }

        // ---- 계약 연결 표시 ----
        if (String(member.contractId ?? "") === contractId) {
          const others = othersSnap.docs
            .filter((doc) => doc.id !== contractId)
            .map((doc) => ({id: doc.id, data: doc.data() as Data}))
            .sort((a, b) => {
              const at = a.data.completedAt instanceof Timestamp ?
                a.data.completedAt.toMillis() : 0;
              const bt = b.data.completedAt instanceof Timestamp ?
                b.data.completedAt.toMillis() : 0;
              return bt - at;
            });
          const latest = others[0];
          if (latest != null) {
            const product = record(latest.data.product);
            const version = Number(latest.data.version ?? 1);
            const no = String(latest.data.contractNo ?? "");
            const displayNo = version > 1 ? `${no}-v${version}` : no;
            Object.assign(memberUpdate, {
              "contractId": latest.id,
              "contractNo": displayNo,
              "contractStatus": "completed",
              "contractSigned": true,
              "contractSignedAt": latest.data.completedAt ?? FieldValue.delete(),
              "lessonSync.contractId": latest.id,
              "lessonSync.contractNo": displayNo,
              "lastContractSummary": {
                contractId: latest.id,
                contractNo: displayNo,
                productName: product.name,
                sessionCount: product.sessionCount,
                totalPrice: product.paidAmount,
                contractDate: product.periodStart,
                endDate: product.periodEnd,
                finalSigned: true,
              },
            });
          } else {
            Object.assign(memberUpdate, {
              "contractSigned": false,
              "contractStatus": "voided",
              "contractId": FieldValue.delete(),
              "contractNo": FieldValue.delete(),
              "contractSignedAt": FieldValue.delete(),
              "lessonSync.contractId": FieldValue.delete(),
              "lessonSync.contractNo": FieldValue.delete(),
              "lastContractSummary": FieldValue.delete(),
            });
          }
        }

        const now = FieldValue.serverTimestamp();
        // ---- 쓰기 ----
        if (Object.keys(memberUpdate).length > 0) {
          memberUpdate.updatedAt = now;
          transaction.update(memberRef, memberUpdate);
        }
        if (deactivated && profileSnap.exists) {
          // 계약으로 다시 활동 중이 되었던 회원을 만료로 되돌렸으니 관리 회원 수를 하나 내린다.
          transaction.update(profileRef, {
            managedMemberCount: FieldValue.increment(-1),
            usageUpdatedAt: now,
            updatedAt: now,
          });
        }
        const signEventRef = contractRef.collection("events").doc();
        transaction.create(signEventRef, {
          type: "void_signed",
          at: now,
          actorRole: "member",
          contentHash: String(contract.contentHash ?? ""),
          payload: {strokes, reason},
        });
        transaction.create(contractRef.collection("events").doc(), {
          type: "voided",
          at: now,
          actorRole: "trainer",
          contentHash: String(contract.contentHash ?? ""),
          payload: {
            reason,
            previousStatus: "completed",
            rolledBack: hasRegistration ? registered : 0,
          },
        });
        transaction.update(contractRef, {
          "status": "voided",
          "voidedAt": now,
          "voidReason": reason,
          "signatures.void": {eventId: signEventRef.id, signedAt: now},
          "updatedAt": now,
        });

        const memberName = String(record(contract.member).name ?? "").trim();
        const version = Number(contract.version ?? 1);
        const no = String(contract.contractNo ?? "");
        const notice = buildContractVoidNotice({
          trainerId: uid,
          memberId,
          memberName,
          contractId,
          contractNo: version > 1 ? `${no}-v${version}` : no,
          reason,
        });
        if (notice != null) {
          transaction.set(
            db.collection(CONTRACT_NOTICES).doc(`${contractId}_void`),
            {...notice, createdAt: now},
          );
        }
        return {
          alreadyVoided: false,
          rolledBack: hasRegistration ? registered : 0,
          ...summary(contractId, {...contract, status: "voided"}),
        };
      });
    } catch (error) {
      return translated(error, "void");
    }
  };
}
