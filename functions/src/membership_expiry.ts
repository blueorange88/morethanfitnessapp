// 회원권 만료 자동 분류와 레슨계약서 기간 연동.
//
// - 매일 새벽 [autoExpireMemberships]가 활동 중(`active`) 개인 워크스페이스 회원 가운데 회원권 종료일이
//   지난 회원을 `expired`(만료)로 옮긴다. 종료일은 **최근 완료한 레슨계약서의 사용 기간 종료일**과 회원카드의
//   회원권 종료일 중 더 늦은 날이다(재계약·연장한 회원을 잘못 만료시키지 않기 위해). 종료일 없음 계약은 만료되지
//   않고, 정지·휴면 회원은 건드리지 않는다. 잔여 횟수 0(소진)은 만료로 보지 않는다.
// - 선생님이 만료를 풀어(`active`로) 둔 회원을 같은 종료일로 다시 만료시키지 않도록 `autoExpire.endDate`를
//   남기고 건너뛴다.
// - 레슨계약서가 완료되면([buildMembershipPeriodSync]) 회원권 기간을 그 계약의 사용 기간으로 갱신하고, 만료
//   상태였다면 활동 중으로 되돌려 새 기간으로 다시 시작한다. 파기하면([buildMembershipRestore]) 이전 값으로
//   돌린다.
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";

type Data = Record<string, unknown>;

const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/u;
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

function record(value: unknown): Data {
  return value != null && typeof value === "object" && !Array.isArray(value) ?
    (value as Data) :
    {};
}

// 한국 날짜(YYYY-MM-DD).
export function kstDateString(date: Date): string {
  return new Date(date.getTime() + KST_OFFSET_MS).toISOString().slice(0, 10);
}

// 한국 날짜의 자정(시각).
export function kstMidnight(date: string): Timestamp {
  return Timestamp.fromDate(new Date(`${date}T00:00:00+09:00`));
}

function timestampDate(value: unknown): string | null {
  return value instanceof Timestamp ? kstDateString(value.toDate()) : null;
}

export interface EffectiveEnd {
  // 만료 판단에 쓰는 마지막 날(없으면 null).
  end: string | null;
  // 종료일 없음 계약이라 만료되지 않는다.
  unlimited: boolean;
}

// 회원의 실제 회원권 종료일: 최근 완료 계약의 종료일과 회원카드의 종료일 중 더 늦은 날.
export function effectiveMembershipEnd(
  member: Data,
  latestContract: Data | null,
): EffectiveEnd {
  const product = record(latestContract?.product);
  if (latestContract != null && product.periodUnlimited === true) {
    return {end: null, unlimited: true};
  }
  const candidates: string[] = [];
  const contractEnd = String(product.periodEnd ?? "");
  if (latestContract != null && DATE_PATTERN.test(contractEnd)) {
    candidates.push(contractEnd);
  }
  const membership = record(member.membership);
  const cardEnd = timestampDate(membership.endAt) ??
    timestampDate(member.expireAt);
  if (cardEnd != null) candidates.push(cardEnd);
  if (candidates.length === 0) return {end: null, unlimited: false};
  return {end: candidates.sort()[candidates.length - 1], unlimited: false};
}

export interface PeriodSync {
  update: Data;
  // 되돌릴 때 쓰는 이전 값(없던 값은 null).
  before: Data;
  // 만료 상태였던 회원이 다시 활동 중이 되었는지.
  reactivated: boolean;
}

// 레슨계약서 완료 시 회원권 기간을 계약의 사용 기간으로 갱신한다.
export function buildMembershipPeriodSync(
  member: Data,
  product: Data,
): PeriodSync | null {
  const periodStart = String(product.periodStart ?? "");
  if (!DATE_PATTERN.test(periodStart)) return null;
  const unlimited = product.periodUnlimited === true;
  const periodEnd = unlimited ? "" : String(product.periodEnd ?? "");
  if (!unlimited && !DATE_PATTERN.test(periodEnd)) return null;
  const startTs = kstMidnight(periodStart);
  const endTs = unlimited ? null : kstMidnight(periodEnd);
  const membership = record(member.membership);
  const orNull = (value: unknown) => value === undefined ? null : value;
  const before: Data = {
    membershipNotRegistered: orNull(member.membershipNotRegistered),
    passStart: orNull(member.passStart),
    passEnd: orNull(member.passEnd),
    expireAt: orNull(member.expireAt),
    notRegistered: orNull(membership.notRegistered),
    startAt: orNull(membership.startAt),
    endAt: orNull(membership.endAt),
    contractDate: orNull(membership.contractDate),
    unlimitedEndDate: orNull(membership.unlimitedEndDate),
    lastRegisteredAt: orNull(membership.lastRegisteredAt),
  };
  const update: Data = {
    "membershipNotRegistered": false,
    "passStart": periodStart,
    "passEnd": periodEnd,
    "expireAt": endTs ?? FieldValue.delete(),
    "membership.notRegistered": false,
    "membership.startAt": startTs,
    "membership.endAt": endTs ?? FieldValue.delete(),
    "membership.contractDate": periodStart,
    "membership.unlimitedEndDate": unlimited,
    "membership.lastRegisteredAt": FieldValue.serverTimestamp(),
  };
  const reactivated = member.managementState === "expired";
  if (reactivated) {
    update.managementState = "active";
    update.countsTowardLimit = true;
    update.managementStateHistory = FieldValue.arrayUnion({
      previousState: "expired",
      nextState: "active",
      changedAt: Timestamp.now(),
      changedBy: String(member.trainerId ?? ""),
      source: "contract_complete",
    });
  }
  return {update, before, reactivated};
}

export interface PeriodRestore {
  update: Data;
  // 다시 만료로 돌렸는지(활동 중 회원 수가 하나 줄어든다).
  deactivated: boolean;
}

// 계약 파기 시 계약 완료 전의 회원권 기간·상태로 되돌린다.
export function buildMembershipRestore(
  before: Data,
  wasReactivated: boolean,
  member: Data,
): PeriodRestore {
  const put = (value: unknown) =>
    value === null || value === undefined ? FieldValue.delete() : value;
  const update: Data = {
    "membershipNotRegistered": put(before.membershipNotRegistered),
    "passStart": put(before.passStart),
    "passEnd": put(before.passEnd),
    "expireAt": put(before.expireAt),
    "membership.notRegistered": put(before.notRegistered),
    "membership.startAt": put(before.startAt),
    "membership.endAt": put(before.endAt),
    "membership.contractDate": put(before.contractDate),
    "membership.unlimitedEndDate": put(before.unlimitedEndDate),
    "membership.lastRegisteredAt": put(before.lastRegisteredAt),
  };
  const deactivated = wasReactivated && member.managementState === "active";
  if (deactivated) {
    update.managementState = "expired";
    update.countsTowardLimit = false;
    update.managementStateHistory = FieldValue.arrayUnion({
      previousState: "active",
      nextState: "expired",
      changedAt: Timestamp.now(),
      changedBy: String(member.trainerId ?? ""),
      source: "contract_void",
    });
  }
  return {update, deactivated};
}

// ---- 매일 새벽 자동 만료 ----
export async function autoExpireMemberships(
  db: FirebaseFirestore.Firestore,
  nowDate: Date = new Date(),
): Promise<{checked: number; expired: number; skipped: number}> {
  const today = kstDateString(nowDate);

  // 회원별 가장 최근 완료 계약.
  const contractsSnap = await db.collection("personal_contracts")
    .where("status", "==", "completed")
    .get();
  const latestByMember = new Map<string, Data>();
  for (const doc of contractsSnap.docs) {
    const data = doc.data();
    const memberId = String(data.memberId ?? "");
    const at = data.completedAt instanceof Timestamp ?
      data.completedAt.toMillis() : 0;
    const current = latestByMember.get(memberId);
    const currentAt = current?.completedAt instanceof Timestamp ?
      current.completedAt.toMillis() : -1;
    if (current == null || at > currentAt) latestByMember.set(memberId, data);
  }

  const membersSnap = await db.collection("members")
    .where("workspaceType", "==", "personal")
    .where("managementState", "==", "active")
    .get();

  let expired = 0;
  let skipped = 0;
  for (const doc of membersSnap.docs) {
    const member = doc.data();
    const effective = effectiveMembershipEnd(
      member,
      latestByMember.get(doc.id) ?? null,
    );
    if (effective.unlimited || effective.end == null ||
        effective.end >= today) {
      skipped += 1;
      continue;
    }
    if (record(member.autoExpire).endDate === effective.end) {
      // 이 종료일로 이미 자동 만료했는데 선생님이 다시 활동 중으로 돌려 둔 회원.
      skipped += 1;
      continue;
    }
    const endDate = effective.end;
    try {
      const done = await db.runTransaction(async (transaction) => {
        const trainerId = String(member.trainerId ?? "");
        const profileRef = db.collection("trainer_profiles").doc(trainerId);
        const [fresh, profileSnap] = await Promise.all([
          transaction.get(doc.ref),
          transaction.get(profileRef),
        ]);
        const current = fresh.data();
        if (!current || current.managementState !== "active" ||
            current.workspaceType !== "personal" ||
            record(current.autoExpire).endDate === endDate) {
          return false;
        }
        const now = FieldValue.serverTimestamp();
        transaction.update(doc.ref, {
          managementState: "expired",
          countsTowardLimit: false,
          autoExpire: {endDate, at: now},
          updatedAt: now,
          managementStateHistory: FieldValue.arrayUnion({
            previousState: "active",
            nextState: "expired",
            changedAt: Timestamp.now(),
            changedBy: "system",
            source: "auto_expire",
            endDate,
          }),
        });
        if (profileSnap.exists) {
          const count = Number(profileSnap.data()?.managedMemberCount ?? 0);
          transaction.update(profileRef, {
            managedMemberCount: Math.max(0, count - 1),
            usageUpdatedAt: now,
            updatedAt: now,
          });
        }
        return true;
      });
      if (done) expired += 1; else skipped += 1;
    } catch (error) {
      skipped += 1;
      functions.logger.error("auto_expire_failed", {
        memberId: doc.id,
        error: String(error),
      });
    }
  }
  return {checked: membersSnap.size, expired, skipped};
}
