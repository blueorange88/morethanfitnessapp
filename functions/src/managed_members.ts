import {createHash} from "crypto";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";

import {
  evaluateEarnedTier,
  hasLinkedProvider,
  isTrainerProfileComplete,
  tierRank,
} from "./tier_qualification.js";
import {
  applyPersonalMemberTaxonomyUpdate,
  parsePersonalMemberTaxonomyAssignments,
  personalMemberTaxonomyCreateFields,
  validatePersonalMemberTaxonomyAssignments,
} from "./personal_member_taxonomy.js";

const BEGINNER_MEMBER_THRESHOLD = 10;
const MEMBER_SCHEMA_VERSION = 2;
const MANAGED_STATES = ["active", "paused", "dormant", "expired", "deleted"] as const;
const GENDERS = ["male", "female"] as const;
const MEMBER_GRADES = ["VVIP", "VIP", "GOLD", "SILVER", "BRONZE"] as const;

type ManagedState = typeof MANAGED_STATES[number];
type Gender = typeof GENDERS[number];
type MemberGrade = typeof MEMBER_GRADES[number];

type ManagedMembershipUpdate = {
  notRegistered: boolean;
  termMonths: number | null;
  customDays: number | null;
  startAt: Timestamp | null;
  endAt: Timestamp | null;
  days: number | null;
  lastRegisteredAt: Timestamp | null;
  reregisterCount: number;
  lastReregisterAt: Timestamp | null;
};

type ProfileUsage = {
  managedCount: number;
  lifetimeCount: number;
  accountLinked: boolean;
  profileCompleted: boolean;
  tier: string;
};

function requireUid(ctx: functions.https.CallableContext): string {
  if (!ctx.auth) {
    throw new functions.https.HttpsError("unauthenticated", "auth_required");
  }
  return ctx.auth.uid;
}

function objectData(data: unknown): Record<string, unknown> {
  if (data == null || typeof data !== "object" || Array.isArray(data)) {
    throw new functions.https.HttpsError("invalid-argument", "invalid_payload");
  }
  return data as Record<string, unknown>;
}

function allowOnly(data: Record<string, unknown>, keys: string[]): void {
  if (Object.keys(data).some((key) => !keys.includes(key))) {
    throw new functions.https.HttpsError("invalid-argument", "unknown_fields");
  }
}

function requiredString(data: Record<string, unknown>, key: string): string {
  const value = data[key];
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new functions.https.HttpsError("invalid-argument", `${key}_required`);
  }
  return value.trim();
}

function optionalString(data: Record<string, unknown>, key: string): string {
  const value = data[key];
  if (value == null) return "";
  if (typeof value !== "string") {
    throw new functions.https.HttpsError("invalid-argument", `${key}_invalid`);
  }
  return value.trim();
}

function hasOwn(data: Record<string, unknown>, key: string): boolean {
  return Object.prototype.hasOwnProperty.call(data, key);
}

function nullableString(
  data: Record<string, unknown>,
  key: string,
): string | null {
  const value = data[key];
  if (value == null) return null;
  if (typeof value !== "string") {
    throw new functions.https.HttpsError("invalid-argument", `${key}_invalid`);
  }
  const normalized = value.trim();
  return normalized.length === 0 ? null : normalized;
}

function nullableInteger(
  data: Record<string, unknown>,
  key: string,
  minimum = 0,
): number | null {
  const value = data[key];
  if (value == null) return null;
  if (!Number.isInteger(value) || Number(value) < minimum) {
    throw new functions.https.HttpsError("invalid-argument", `${key}_invalid`);
  }
  return Number(value);
}

function nullableCalendarDate(
  data: Record<string, unknown>,
  key: string,
): Timestamp | null {
  const raw = data[key];
  if (raw == null) return null;
  if (typeof raw !== "string") {
    throw new functions.https.HttpsError("invalid-argument", `${key}_invalid`);
  }
  const display = raw.trim();
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(display);
  if (!match) {
    throw new functions.https.HttpsError("invalid-argument", `${key}_invalid`);
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== year ||
      date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) {
    throw new functions.https.HttpsError("invalid-argument", `${key}_invalid`);
  }
  return Timestamp.fromDate(date);
}

function managedMembershipUpdate(value: unknown): ManagedMembershipUpdate {
  const data = objectData(value);
  allowOnly(data, [
    "notRegistered", "termMonths", "customDays", "startAt", "endAt",
    "days", "lastRegisteredAt", "reregisterCount", "lastReregisterAt",
  ]);
  if (typeof data.notRegistered !== "boolean") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "membership_notRegistered_invalid",
    );
  }
  const termMonths = nullableInteger(data, "termMonths", 1);
  const customDays = nullableInteger(data, "customDays", 1);
  const startAt = nullableCalendarDate(data, "startAt");
  const endAt = nullableCalendarDate(data, "endAt");
  const days = nullableInteger(data, "days", 1);
  const lastRegisteredAt = nullableCalendarDate(data, "lastRegisteredAt");
  const reregisterCount = nullableInteger(data, "reregisterCount") ?? 0;
  const lastReregisterAt = nullableCalendarDate(data, "lastReregisterAt");
  if (termMonths != null && ![1, 3, 6, 12].includes(termMonths)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "membership_termMonths_invalid",
    );
  }
  if (termMonths != null && customDays != null) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "membership_period_mode_invalid",
    );
  }
  const hasStart = startAt != null;
  const hasEnd = endAt != null;
  if (hasStart !== hasEnd || (hasStart && days == null) ||
      (!hasStart && days != null)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "membership_period_invalid",
    );
  }
  if (startAt != null && endAt != null && days != null) {
    const expectedDays = Math.floor(
      (endAt.toMillis() - startAt.toMillis()) / 86400000,
    ) + 1;
    if (expectedDays <= 0 || expectedDays !== days ||
        (termMonths != null && days !== termMonths * 30) ||
        (customDays != null && days !== customDays)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "membership_period_invalid",
      );
    }
  }
  return {
    notRegistered: data.notRegistered,
    termMonths,
    customDays,
    startAt,
    endAt,
    days,
    lastRegisteredAt,
    reregisterCount,
    lastReregisterAt,
  };
}

function requireMaxLength(value: string, key: string, maxLength: number): void {
  if (value.length > maxLength) {
    throw new functions.https.HttpsError("invalid-argument", `${key}_too_long`);
  }
}

function normalizedPhone(value: string): string {
  const digits = value.replace(/[^0-9]/g, "");
  if (digits.length < 9 || digits.length > 15) {
    throw new functions.https.HttpsError("invalid-argument", "phone_invalid");
  }
  return digits;
}

function requiredGender(data: Record<string, unknown>): Gender {
  const gender = requiredString(data, "gender").toLowerCase();
  if (!GENDERS.includes(gender as Gender)) {
    throw new functions.https.HttpsError("invalid-argument", "gender_invalid");
  }
  return gender as Gender;
}

function requiredMemberGrade(
  data: Record<string, unknown>,
  key = "membershipGrade",
): MemberGrade {
  const grade = requiredString(data, key).toUpperCase();
  if (!MEMBER_GRADES.includes(grade as MemberGrade)) {
    throw new functions.https.HttpsError("invalid-argument", `${key}_invalid`);
  }
  return grade as MemberGrade;
}

type BirthDate = {
  display: string;
  timestamp: Timestamp;
};

function requiredBirthDate(data: Record<string, unknown>): BirthDate {
  const raw = data.birthDate ?? data.birthDisplay;
  if (typeof raw !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "birthDate_required",
    );
  }
  const display = raw.trim();
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(display);
  if (!match) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "birthDate_invalid",
    );
  }
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const date = new Date(Date.UTC(year, month - 1, day));
  if (date.getUTCFullYear() !== year ||
      date.getUTCMonth() !== month - 1 || date.getUTCDate() !== day) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "birthDate_invalid",
    );
  }
  const today = new Date();
  const todayUtc = new Date(Date.UTC(
    today.getUTCFullYear(),
    today.getUTCMonth(),
    today.getUTCDate(),
  ));
  let age = todayUtc.getUTCFullYear() - year;
  if (todayUtc.getUTCMonth() < month - 1 ||
      (todayUtc.getUTCMonth() === month - 1 && todayUtc.getUTCDate() < day)) {
    age -= 1;
  }
  if (year < 1900 || date > todayUtc || age < 4 || age >= 100) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "birthDate_invalid",
    );
  }
  return {display, timestamp: Timestamp.fromDate(date)};
}

function optionalCreateBirthDate(
  data: Record<string, unknown>,
): BirthDate | null {
  if (!Object.prototype.hasOwnProperty.call(data, "birthDate")) {
    return null;
  }
  return requiredBirthDate(data);
}

function countsTowardManaged(state: ManagedState): boolean {
  return state === "active" || state === "paused";
}

function validateProfile(
  uid: string,
  snapshot: FirebaseFirestore.DocumentSnapshot,
  ctx: functions.https.CallableContext,
): ProfileUsage {
  if (!snapshot.exists) {
    throw new functions.https.HttpsError("failed-precondition", "profile_required");
  }
  const data = snapshot.data() ?? {};
  const accountLinked = hasLinkedProvider(ctx);
  const validLocal = !accountLinked &&
    data.accountState === "local" && data.isAnonymous === true;
  const validLinked = accountLinked &&
    (data.accountState === "linked" || data.accountState === "verified") &&
    data.isAnonymous !== true;
  if (data.trainerId !== uid || data.workspaceType !== "personal" ||
      data.workspaceStatus !== "active" || data.role !== "personal" ||
      (!validLocal && !validLinked)) {
    throw new functions.https.HttpsError("permission-denied", "workspace_not_eligible");
  }

  const managedCount = Number(data.managedMemberCount ?? 0);
  const lifetimeCount = Number(data.lifetimeQualifiedMemberCount ?? 0);
  if (!Number.isInteger(managedCount) || managedCount < 0 ||
      !Number.isInteger(lifetimeCount) || lifetimeCount < 0 ||
      data.managedMemberLimit !== BEGINNER_MEMBER_THRESHOLD) {
    throw new functions.https.HttpsError("failed-precondition", "member_count_conflict");
  }
  return {
    managedCount,
    lifetimeCount,
    accountLinked,
    profileCompleted: isTrainerProfileComplete(data),
    tier: String(data.tier ?? "Beginner"),
  };
}

function enforceBeyondBeginnerThreshold(profile: ProfileUsage): void {
  if (profile.lifetimeCount < BEGINNER_MEMBER_THRESHOLD) return;
  if (!profile.accountLinked) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "account_link_required",
    );
  }
  if (!profile.profileCompleted) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "profile_completion_required",
    );
  }
}

function memberIdFor(uid: string, idempotencyKey: string): string {
  const digest = createHash("sha256")
    .update(`${uid}:${idempotencyKey}`, "utf8")
    .digest("hex")
    .slice(0, 32);
  return `m_${digest}`;
}

function duplicatePhoneQuery(
  db: FirebaseFirestore.Firestore,
  uid: string,
  phoneNormalized: string,
) {
  return db.collection("members")
    .where("trainerId", "==", uid)
    .where("workspaceType", "==", "personal")
    .where("phoneNormalized", "==", phoneNormalized)
    .limit(2);
}

function profilePromotionUpdate(
  profile: ProfileUsage,
  lifetimeCount: number,
): Record<string, unknown> {
  const earned = evaluateEarnedTier({
    currentTier: profile.tier,
    lifetimeQualifiedMemberCount: lifetimeCount,
    accountLinked: profile.accountLinked,
    profileCompleted: profile.profileCompleted,
  });
  return {
    lifetimeQualifiedMemberCount: lifetimeCount,
    accountLinked: profile.accountLinked,
    profileCompleted: profile.profileCompleted,
    tier: earned.tier,
    earnedTier: earned.tier,
    earnedTierRank: earned.rank,
  };
}

function translateError(error: unknown, operation: string): never {
  if (error instanceof functions.https.HttpsError) throw error;
  functions.logger.error(`${operation} failed`, {
    errorName: error instanceof Error ? error.name : "UnknownError",
  });
  throw new functions.https.HttpsError("internal", "internal");
}

export function createManagedMemberHandler(db: FirebaseFirestore.Firestore) {
  return async (raw: unknown, ctx: functions.https.CallableContext) => {
    const uid = requireUid(ctx);
    const data = objectData(raw);
    allowOnly(data, [
      "idempotencyKey", "name", "gender", "birthDate", "phone", "note",
      "postal", "address", "detailAddress", "lessonType",
      "totalSessions", "remainingSessions", "lessonsNotRegistered",
      "activityRegion", "registrationMode", "nextReservationAt",
      "membershipGrade", "membership", "anniversaryDate", "anniversaryLabel",
      "personalGroupId", "personalTagIds",
    ]);
    const taxonomyAssignments = parsePersonalMemberTaxonomyAssignments(data);
    const registrationMode = optionalString(data, "registrationMode") || "full";
    if (registrationMode !== "full" && registrationMode !== "quick") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "registration_mode_invalid",
      );
    }
    const idempotencyKey = requiredString(data, "idempotencyKey");
    const name = requiredString(data, "name");
    const gender = registrationMode === "quick" && !hasOwn(data, "gender") ?
      null : requiredGender(data);
    const birthDate = optionalCreateBirthDate(data);
    const phone = requiredString(data, "phone");
    const phoneNormalized = normalizedPhone(phone);
    const nextReservationAt = hasOwn(data, "nextReservationAt") ?
      nullableCalendarDate(data, "nextReservationAt") : null;
    const note = optionalString(data, "note");
    const activityRegion = optionalString(data, "activityRegion");
    const postal = optionalString(data, "postal");
    const address = optionalString(data, "address");
    const detailAddress = optionalString(data, "detailAddress");
    const lessonType = optionalString(data, "lessonType") || "미입력";
    const totalSessions = Number(data.totalSessions ?? 0);
    const remainingSessions = Number(data.remainingSessions ?? 0);
    const lessonsNotRegistered = data.lessonsNotRegistered === true;
    const membershipGrade = hasOwn(data, "membershipGrade") ?
      requiredMemberGrade(data) : null;
    const membership = hasOwn(data, "membership") ?
      managedMembershipUpdate(data.membership) : null;
    const anniversaryDate = hasOwn(data, "anniversaryDate") ?
      nullableCalendarDate(data, "anniversaryDate") : null;
    const anniversaryLabel = hasOwn(data, "anniversaryLabel") ?
      nullableString(data, "anniversaryLabel") : null;
    if (anniversaryLabel != null) {
      requireMaxLength(anniversaryLabel, "anniversaryLabel", 40);
    }
    if (anniversaryDate == null && anniversaryLabel != null) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "anniversary_pair_invalid",
      );
    }
    requireMaxLength(idempotencyKey, "idempotencyKey", 128);
    requireMaxLength(name, "name", 80);
    requireMaxLength(phone, "phone", 32);
    requireMaxLength(note, "note", 1000);
    requireMaxLength(activityRegion, "activityRegion", 120);
    requireMaxLength(postal, "postal", 12);
    requireMaxLength(address, "address", 240);
    requireMaxLength(detailAddress, "detailAddress", 240);
    requireMaxLength(lessonType, "lessonType", 40);
    if (!Number.isInteger(totalSessions) || totalSessions < 0 ||
        !Number.isInteger(remainingSessions) || remainingSessions < 0 ||
        remainingSessions > totalSessions) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "session_count_invalid",
      );
    }

    const memberId = memberIdFor(uid, idempotencyKey);
    const profileRef = db.collection("trainer_profiles").doc(uid);
    const memberRef = db.collection("members").doc(memberId);
    const phoneQuery = duplicatePhoneQuery(db, uid, phoneNormalized);
    try {
      return await db.runTransaction(async (transaction) => {
        const [profileSnapshot, memberSnapshot, duplicateSnapshot] = await Promise.all([
          transaction.get(profileRef),
          transaction.get(memberRef),
          transaction.get(phoneQuery),
        ]);
        const profile = validateProfile(uid, profileSnapshot, ctx);
        if (memberSnapshot.exists) {
          const existing = memberSnapshot.data() ?? {};
          if (existing.trainerId !== uid || existing.workspaceType !== "personal") {
            throw new functions.https.HttpsError("already-exists", "member_id_conflict");
          }
          return {
            created: false,
            memberId,
            managedMemberCount: profile.managedCount,
            lifetimeQualifiedMemberCount: profile.lifetimeCount,
            tier: profile.tier,
          };
        }
        if (!duplicateSnapshot.empty) {
          throw new functions.https.HttpsError("already-exists", "duplicate_member");
        }
        if (tierRank(profile.tier) < 1) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "amateur_required",
          );
        }
        enforceBeyondBeginnerThreshold(profile);
        await validatePersonalMemberTaxonomyAssignments({
          transaction,
          db,
          uid,
          tier: profile.tier,
          assignments: taxonomyAssignments,
        });

        const now = FieldValue.serverTimestamp();
        const nextManagedCount = profile.managedCount + 1;
        const nextLifetimeCount = profile.lifetimeCount + 1;
        transaction.create(memberRef, {
          memberId,
          trainerId: uid,
          workspaceType: "personal",
          schemaVersion: MEMBER_SCHEMA_VERSION,
          managementState: "active",
          countsTowardLimit: true,
          countsTowardLifetimeQualification: true,
          qualifiedAt: now,
          name,
          ...(gender == null ? {} : {gender}),
          ...(birthDate == null ? {} : {
            birth: birthDate.timestamp,
            birthDisplay: birthDate.display,
            birthAt: birthDate.timestamp,
          }),
          phone,
          phoneNormalized,
          postal,
          address,
          detailAddress,
          activityRegion,
          lessonType,
          totalSessions,
          remainingSessions,
          remainSessions: remainingSessions,
          sessions: {
            notRegistered: lessonsNotRegistered,
            total: totalSessions,
            remain: remainingSessions,
          },
          ...(membershipGrade == null ? {} : {membershipGrade}),
          ...(membership == null ? {} : {membership}),
          ...(anniversaryDate == null ? {} : {anniversaryDate}),
          ...(anniversaryLabel == null ? {} : {anniversaryLabel}),
          note,
          ...(nextReservationAt == null ? {} : {nextReservationAt}),
          ...personalMemberTaxonomyCreateFields(taxonomyAssignments),
          createdAt: now,
          updatedAt: now,
        });
        transaction.set(profileRef, {
          managedMemberCount: nextManagedCount,
          managedMemberLimit: BEGINNER_MEMBER_THRESHOLD,
          ...profilePromotionUpdate(profile, nextLifetimeCount),
          usageUpdatedAt: now,
          updatedAt: now,
        }, {merge: true});
        const earned = evaluateEarnedTier({
          currentTier: profile.tier,
          lifetimeQualifiedMemberCount: nextLifetimeCount,
          accountLinked: profile.accountLinked,
          profileCompleted: profile.profileCompleted,
        });
        return {
          created: true,
          memberId,
          managedMemberCount: nextManagedCount,
          lifetimeQualifiedMemberCount: nextLifetimeCount,
          tier: earned.tier,
        };
      });
    } catch (error) {
      return translateError(error, "createManagedMember");
    }
  };
}

export function transitionManagedMemberStateHandler(db: FirebaseFirestore.Firestore) {
  return async (raw: unknown, ctx: functions.https.CallableContext) => {
    const uid = requireUid(ctx);
    const data = objectData(raw);
    allowOnly(data, ["memberId", "nextState"]);
    const memberId = requiredString(data, "memberId");
    const nextStateValue = requiredString(data, "nextState");
    if (!MANAGED_STATES.includes(nextStateValue as ManagedState)) {
      throw new functions.https.HttpsError("invalid-argument", "invalid_management_state");
    }
    const nextState = nextStateValue as ManagedState;
    const profileRef = db.collection("trainer_profiles").doc(uid);
    const memberRef = db.collection("members").doc(memberId);
    try {
      return await db.runTransaction(async (transaction) => {
        const [profileSnapshot, memberSnapshot] = await Promise.all([
          transaction.get(profileRef), transaction.get(memberRef),
        ]);
        const profile = validateProfile(uid, profileSnapshot, ctx);
        if (!memberSnapshot.exists) {
          throw new functions.https.HttpsError("not-found", "member_not_found");
        }
        const member = memberSnapshot.data() ?? {};
        if (member.memberId !== memberId || member.trainerId !== uid ||
            member.workspaceType !== "personal") {
          throw new functions.https.HttpsError("permission-denied", "member_owner_mismatch");
        }
        const currentStateValue = member.managementState;
        if (typeof currentStateValue !== "string" ||
            !MANAGED_STATES.includes(currentStateValue as ManagedState)) {
          throw new functions.https.HttpsError("failed-precondition", "invalid_member_state");
        }
        const currentState = currentStateValue as ManagedState;
        if (currentState === nextState) {
          return {changed: false, memberId, managedMemberCount: profile.managedCount};
        }
        const delta = Number(countsTowardManaged(nextState)) -
          Number(countsTowardManaged(currentState));
        const nextCount = profile.managedCount + delta;
        if (nextCount < 0) {
          throw new functions.https.HttpsError("failed-precondition", "member_count_conflict");
        }
        const now = FieldValue.serverTimestamp();
        const deletedAt = Timestamp.now();
        const deletionFields = nextState === "deleted" ? {
          isDeleted: true,
          deletedAt,
          deleteScheduledAt: Timestamp.fromMillis(
            deletedAt.toMillis() + 7 * 24 * 60 * 60 * 1000,
          ),
          deleteStatus: "pending_delete",
          deletedSource: "managed_member_function",
        } : currentState === "deleted" ? {
          isDeleted: FieldValue.delete(),
          deletedAt: FieldValue.delete(),
          deleteScheduledAt: FieldValue.delete(),
          deleteStatus: FieldValue.delete(),
          deletedSource: FieldValue.delete(),
        } : {};
        transaction.update(memberRef, {
          managementState: nextState,
          countsTowardLimit: countsTowardManaged(nextState),
          ...deletionFields,
          updatedAt: now,
          managementStateHistory: FieldValue.arrayUnion({
            previousState: currentState,
            nextState,
            changedAt: Timestamp.now(),
            changedBy: uid,
            source: "managed_member_function",
          }),
        });
        transaction.update(profileRef, {
          managedMemberCount: nextCount,
          usageUpdatedAt: now,
          updatedAt: now,
        });
        return {changed: true, memberId, managedMemberCount: nextCount};
      });
    } catch (error) {
      return translateError(error, "transitionManagedMemberState");
    }
  };
}

async function syncManagedMemberNameToSchedules(
  db: FirebaseFirestore.Firestore,
  uid: string,
  memberId: string,
  name: string,
): Promise<number> {
  const snapshot = await db.collection("schedules")
    .where("trainerId", "==", uid)
    .where("workspaceType", "==", "personal")
    .where("memberId", "==", memberId)
    .get();
  const documents = snapshot.docs.filter((document) =>
    String(document.data().name ?? "").trim() !== name,
  );
  let updatedCount = 0;
  for (let index = 0; index < documents.length; index += 450) {
    const batch = db.batch();
    const chunk = documents.slice(index, index + 450);
    for (const document of chunk) {
      batch.update(document.ref, {
        name,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    updatedCount += chunk.length;
  }
  return updatedCount;
}

export function updateManagedMemberHandler(db: FirebaseFirestore.Firestore) {
  return async (raw: unknown, ctx: functions.https.CallableContext) => {
    const uid = requireUid(ctx);
    const data = objectData(raw);
    allowOnly(data, [
      "memberId", "name", "gender", "birthDate", "phone", "note",
      "postal", "address", "detailAddress", "lessonType",
      "totalSessions", "remainingSessions", "lessonsNotRegistered",
      "activityRegion", "membership", "anniversaryDate", "anniversaryLabel",
      "membershipGrade",
      "personalGroupId", "personalTagIds",
    ]);
    const taxonomyAssignments = parsePersonalMemberTaxonomyAssignments(data);
    const taxonomyOnly =
      (taxonomyAssignments.groupProvided || taxonomyAssignments.tagsProvided) &&
      Object.keys(data).every((key) => [
        "memberId",
        "personalGroupId",
        "personalTagIds",
      ].includes(key));
    const memberId = requiredString(data, "memberId");
    const membership = hasOwn(data, "membership") ?
      managedMembershipUpdate(data.membership) : null;
    const membershipGrade = hasOwn(data, "membershipGrade") ?
      requiredMemberGrade(data) : undefined;
    const anniversaryDate = hasOwn(data, "anniversaryDate") ?
      nullableCalendarDate(data, "anniversaryDate") : undefined;
    const anniversaryLabel = hasOwn(data, "anniversaryLabel") ?
      nullableString(data, "anniversaryLabel") : undefined;
    if (anniversaryLabel != null) {
      requireMaxLength(anniversaryLabel, "anniversaryLabel", 40);
    }
    if (anniversaryDate === null && anniversaryLabel != null) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "anniversary_pair_invalid",
      );
    }
    const profileRef = db.collection("trainer_profiles").doc(uid);
    const memberRef = db.collection("members").doc(memberId);
    try {
      const updateResult = await db.runTransaction(async (transaction) => {
        const [profileSnapshot, memberSnapshot] = await Promise.all([
          transaction.get(profileRef), transaction.get(memberRef),
        ]);
        const profile = validateProfile(uid, profileSnapshot, ctx);
        if (!memberSnapshot.exists) {
          throw new functions.https.HttpsError("not-found", "member_not_found");
        }
        const current = memberSnapshot.data() ?? {};
        if (current.memberId !== memberId || current.trainerId !== uid ||
            current.workspaceType !== "personal") {
          throw new functions.https.HttpsError("permission-denied", "member_owner_mismatch");
        }
        await validatePersonalMemberTaxonomyAssignments({
          transaction,
          db,
          uid,
          tier: profile.tier,
          assignments: taxonomyAssignments,
        });
        if (taxonomyOnly) {
          const taxonomyUpdate: Record<string, unknown> = {
            updatedAt: FieldValue.serverTimestamp(),
          };
          applyPersonalMemberTaxonomyUpdate(
            taxonomyUpdate,
            taxonomyAssignments,
          );
          transaction.update(memberRef, taxonomyUpdate);
          return {
            updated: true,
            memberId,
            lifetimeQualifiedMemberCount: profile.lifetimeCount,
            updatedName: null,
          };
        }
        const merged = {...current, ...data};
        const name = requiredString(merged, "name");
        const gender = requiredGender(merged);
        const birthDate = requiredBirthDate(merged);
        const phone = requiredString(merged, "phone");
        const phoneNormalized = normalizedPhone(phone);
        const activityRegion = optionalString(merged, "activityRegion");
        const note = optionalString(merged, "note");
        const postal = optionalString(merged, "postal");
        const address = optionalString(merged, "address");
        const detailAddress = optionalString(merged, "detailAddress");
        const lessonType = optionalString(merged, "lessonType") || "미입력";
        const totalSessions = Number(merged.totalSessions ?? 0);
        const remainingSessions = Number(merged.remainingSessions ?? 0);
        const lessonsNotRegistered = merged.lessonsNotRegistered === true;
        requireMaxLength(name, "name", 80);
        requireMaxLength(phone, "phone", 32);
        requireMaxLength(activityRegion, "activityRegion", 120);
        requireMaxLength(note, "note", 1000);
        requireMaxLength(postal, "postal", 12);
        requireMaxLength(address, "address", 240);
        requireMaxLength(detailAddress, "detailAddress", 240);
        requireMaxLength(lessonType, "lessonType", 40);
        if (!Number.isInteger(totalSessions) || totalSessions < 0 ||
            !Number.isInteger(remainingSessions) || remainingSessions < 0 ||
            remainingSessions > totalSessions) {
          throw new functions.https.HttpsError(
            "invalid-argument",
            "session_count_invalid",
          );
        }
        const duplicateSnapshot = await transaction.get(
          duplicatePhoneQuery(db, uid, phoneNormalized),
        );
        if (duplicateSnapshot.docs.some((document) => document.id !== memberId)) {
          throw new functions.https.HttpsError("already-exists", "duplicate_member");
        }
        const firstQualification = current.countsTowardLifetimeQualification !== true;
        if (firstQualification) enforceBeyondBeginnerThreshold(profile);
        const nextLifetimeCount = profile.lifetimeCount + Number(firstQualification);
        const now = FieldValue.serverTimestamp();
        const canonicalUpdate: Record<string, unknown> = {
          name,
          gender,
          birth: birthDate.timestamp,
          birthDisplay: birthDate.display,
          birthAt: birthDate.timestamp,
          phone,
          phoneNormalized,
          activityRegion,
          note,
          postal,
          address,
          detailAddress,
          lessonType,
          totalSessions,
          remainingSessions,
          remainSessions: remainingSessions,
          sessions: {
            notRegistered: lessonsNotRegistered,
            total: totalSessions,
            remain: remainingSessions,
          },
          countsTowardLifetimeQualification: true,
          ...(firstQualification ? {qualifiedAt: now} : {}),
          updatedAt: now,
        };
        if (membership != null) {
          canonicalUpdate["membership.notRegistered"] = membership.notRegistered;
          canonicalUpdate["membership.termMonths"] = membership.termMonths;
          canonicalUpdate["membership.customDays"] = membership.customDays;
          canonicalUpdate["membership.startAt"] = membership.startAt;
          canonicalUpdate["membership.endAt"] = membership.endAt;
          canonicalUpdate["membership.days"] = membership.days;
          canonicalUpdate["membership.lastRegisteredAt"] =
            membership.lastRegisteredAt;
          canonicalUpdate["membership.reregisterCount"] =
            membership.reregisterCount;
          canonicalUpdate["membership.lastReregisterAt"] =
            membership.lastReregisterAt;
        }
        if (membershipGrade !== undefined) {
          canonicalUpdate.membershipGrade = membershipGrade;
        }
        if (anniversaryDate !== undefined) {
          canonicalUpdate.anniversaryDate = anniversaryDate;
        }
        if (anniversaryLabel !== undefined) {
          canonicalUpdate.anniversaryLabel = anniversaryLabel;
        }
        applyPersonalMemberTaxonomyUpdate(
          canonicalUpdate,
          taxonomyAssignments,
        );
        transaction.update(memberRef, canonicalUpdate);
        if (firstQualification) {
          transaction.update(profileRef, {
            ...profilePromotionUpdate(profile, nextLifetimeCount),
            usageUpdatedAt: now,
            updatedAt: now,
          });
        }
        return {
          updated: true,
          memberId,
          lifetimeQualifiedMemberCount: nextLifetimeCount,
          updatedName: name,
        };
      });
      const {
        updatedName,
        ...response
      } = updateResult;
      if (updatedName == null) {
        return {
          ...response,
          scheduleNameSyncSucceeded: true,
          scheduleNameUpdatedCount: 0,
        };
      }
      try {
        const scheduleNameUpdatedCount =
          await syncManagedMemberNameToSchedules(
            db,
            uid,
            memberId,
            updatedName,
          );
        return {
          ...response,
          scheduleNameSyncSucceeded: true,
          scheduleNameUpdatedCount,
        };
      } catch (_) {
        return {
          ...response,
          scheduleNameSyncSucceeded: false,
          scheduleNameUpdatedCount: 0,
        };
      }
    } catch (error) {
      return translateError(error, "updateManagedMember");
    }
  };
}

export function updateManagedMemberConsentHandler(
  db: FirebaseFirestore.Firestore,
) {
  return async (raw: unknown, ctx: functions.https.CallableContext) => {
    const uid = requireUid(ctx);
    const data = objectData(raw);
    allowOnly(data, ["memberId", "agreed"]);
    const memberId = requiredString(data, "memberId");
    if (typeof data.agreed !== "boolean") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "consent_state_invalid",
      );
    }
    const agreed = data.agreed;
    const profileRef = db.collection("trainer_profiles").doc(uid);
    const memberRef = db.collection("members").doc(memberId);
    try {
      return await db.runTransaction(async (transaction) => {
        const [profileSnapshot, memberSnapshot] = await Promise.all([
          transaction.get(profileRef),
          transaction.get(memberRef),
        ]);
        validateProfile(uid, profileSnapshot, ctx);
        if (!memberSnapshot.exists) {
          throw new functions.https.HttpsError("not-found", "member_not_found");
        }
        const current = memberSnapshot.data() ?? {};
        if (current.memberId !== memberId || current.trainerId !== uid ||
            current.workspaceType !== "personal") {
          throw new functions.https.HttpsError(
            "permission-denied",
            "member_owner_mismatch",
          );
        }
        if (current.managementState === "deleted" ||
            current.isDeleted === true ||
            current.deleteStatus === "pending_delete") {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "member_deleted",
          );
        }
        const update: Record<string, unknown> = {
          trainingLogConsentAgreed: agreed,
          updatedAt: FieldValue.serverTimestamp(),
        };
        if (agreed) {
          if (current.trainingLogConsentAgreed !== true ||
              current.trainingLogConsentAgreedAt == null) {
            update.trainingLogConsentAgreedAt = FieldValue.serverTimestamp();
          }
        } else {
          update.trainingLogConsentAgreedAt = FieldValue.delete();
        }
        transaction.update(memberRef, update);
        return {updated: true, memberId, agreed};
      });
    } catch (error) {
      return translateError(error, "updateManagedMemberConsent");
    }
  };
}

const MS_PER_DAY = 24 * 60 * 60 * 1000;
const KOREA_UTC_OFFSET_MS = 9 * 60 * 60 * 1000;

// members/{id} 클라이언트 직접 write는 Firestore Rules(workspaceType=='personal')로
// 차단되어 있어, 고객카드의 회원권 정지/재개는 이 서버 함수를 통해서만 반영된다.
// 날짜 계산은 트레이너 기기(한국 로컬 시간) 기준으로 client_card_page.dart가 쓰던
// 기존 계산식을 그대로 옮긴 것으로, 새 정책을 만들지 않는다.
function koreaDateOnly(instant: Date): Date {
  const shifted = new Date(instant.getTime() + KOREA_UTC_OFFSET_MS);
  return new Date(Date.UTC(
    shifted.getUTCFullYear(),
    shifted.getUTCMonth(),
    shifted.getUTCDate(),
  ));
}

function daysBetweenKoreaDates(from: Date, to: Date): number {
  return Math.round((to.getTime() - from.getTime()) / MS_PER_DAY);
}

export function updateManagedMemberMembershipPauseHandler(
  db: FirebaseFirestore.Firestore,
) {
  return async (raw: unknown, ctx: functions.https.CallableContext) => {
    const uid = requireUid(ctx);
    const data = objectData(raw);
    allowOnly(data, ["memberId", "action", "pauseDays"]);
    const memberId = requiredString(data, "memberId");
    const action = requiredString(data, "action");
    if (action !== "pause" && action !== "resume") {
      throw new functions.https.HttpsError("invalid-argument", "action_invalid");
    }
    const profileRef = db.collection("trainer_profiles").doc(uid);
    const memberRef = db.collection("members").doc(memberId);
    try {
      return await db.runTransaction(async (transaction) => {
        const [profileSnapshot, memberSnapshot] = await Promise.all([
          transaction.get(profileRef),
          transaction.get(memberRef),
        ]);
        validateProfile(uid, profileSnapshot, ctx);
        if (!memberSnapshot.exists) {
          throw new functions.https.HttpsError("not-found", "member_not_found");
        }
        const current = memberSnapshot.data() ?? {};
        if (current.memberId !== memberId || current.trainerId !== uid ||
            current.workspaceType !== "personal") {
          throw new functions.https.HttpsError(
            "permission-denied",
            "member_owner_mismatch",
          );
        }
        const membership = (current.membership &&
          typeof current.membership === "object") ?
          current.membership as Record<string, unknown> : {};
        const isPaused = membership.status === "paused" ||
          current.membershipStatus === "paused";
        const now = Timestamp.now();
        const nowServer = FieldValue.serverTimestamp();
        const today = koreaDateOnly(now.toDate());

        if (action === "pause") {
          if (isPaused) {
            throw new functions.https.HttpsError(
              "failed-precondition",
              "already_paused",
            );
          }
          const endAtRaw = membership.endAt;
          if (!(endAtRaw instanceof Timestamp)) {
            throw new functions.https.HttpsError(
              "failed-precondition",
              "membership_not_registered",
            );
          }
          const passEnd = koreaDateOnly(endAtRaw.toDate());
          const remainingDays = daysBetweenKoreaDates(today, passEnd);
          if (remainingDays <= 0) {
            throw new functions.https.HttpsError(
              "failed-precondition",
              "membership_expired",
            );
          }
          const pauseDays = nullableInteger(data, "pauseDays", 1);
          if (pauseDays == null) {
            throw new functions.https.HttpsError(
              "invalid-argument",
              "pause_days_required",
            );
          }
          if (pauseDays > remainingDays) {
            throw new functions.https.HttpsError(
              "failed-precondition",
              "pause_days_over_remaining",
            );
          }
          const contractDraftExists =
            current.membershipContractDraftExists === true ||
            membership.contractStatus === "draft" ||
            current.membershipContractStatus === "draft";
          const contractMax =
            typeof membership.maxPauseDaysFromContract === "number" ?
              membership.maxPauseDaysFromContract :
              typeof current.membershipContractMaxPauseDays === "number" ?
                current.membershipContractMaxPauseDays : null;
          const pauseUsedDays =
            typeof membership.pauseUsedDays === "number" ?
              membership.pauseUsedDays :
              typeof current.membershipPauseUsedDays === "number" ?
                current.membershipPauseUsedDays : 0;
          if (contractDraftExists && contractMax != null && contractMax > 0) {
            const contractRemaining = Math.min(
              contractMax,
              Math.max(0, contractMax - pauseUsedDays),
            );
            const availableDays = Math.min(remainingDays, contractRemaining);
            if (pauseDays > availableDays) {
              throw new functions.https.HttpsError(
                "failed-precondition",
                "pause_days_over_contract_limit",
              );
            }
          }
          const resumeDueAt = Timestamp.fromDate(
            new Date(today.getTime() + pauseDays * MS_PER_DAY),
          );
          transaction.update(memberRef, {
            "memberStatus": "휴면",
            "membershipStatus": "paused",
            "membership.status": "paused",
            "membership.pausedAt": nowServer,
            "membership.pausePlannedDays": pauseDays,
            "membership.resumeDueAt": resumeDueAt,
            "membership.pauseReason": "client_card_membership_pause",
            "membership.pauseSource": "client_card",
            "membership.updatedAt": nowServer,
            "membershipPausePlannedDays": pauseDays,
            "membershipResumeDueAt": resumeDueAt,
            "membershipPausedAt": nowServer,
            "membershipPauseHistory": FieldValue.arrayUnion({
              type: "pause",
              at: now,
              plannedDays: pauseDays,
              resumeDueAt: resumeDueAt,
              source: "client_card",
            }),
            "updatedAt": nowServer,
          });
          return {
            updated: true,
            memberId,
            action,
            pauseDays,
            resumeDueAtMillis: resumeDueAt.toMillis(),
          };
        }

        if (!isPaused) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "not_paused",
          );
        }
        const pausedAtRaw = membership.pausedAt ?? current.membershipPausedAt;
        const pausedAt = pausedAtRaw instanceof Timestamp ?
          koreaDateOnly(pausedAtRaw.toDate()) : today;
        const elapsedRaw = daysBetweenKoreaDates(pausedAt, today);
        const elapsedDays = elapsedRaw <= 0 ? 1 : elapsedRaw;
        const plannedDaysRaw =
          typeof membership.pausePlannedDays === "number" ?
            membership.pausePlannedDays :
            typeof current.membershipPausePlannedDays === "number" ?
              current.membershipPausePlannedDays : 0;
        const plannedDays = plannedDaysRaw <= 0 ? elapsedDays : plannedDaysRaw;
        const actualPauseDays =
          elapsedDays > plannedDays ? plannedDays : elapsedDays;
        const endAtRaw = membership.endAt;
        const passEnd = endAtRaw instanceof Timestamp ?
          endAtRaw.toDate() : null;
        let nextPassEndTimestamp: Timestamp | null = null;
        let nextDaysValue: number | null = null;
        if (passEnd != null) {
          const passEndDateOnly = koreaDateOnly(passEnd);
          const nextPassEnd = new Date(
            passEndDateOnly.getTime() + actualPauseDays * MS_PER_DAY,
          );
          nextPassEndTimestamp = Timestamp.fromDate(nextPassEnd);
          const startAtRaw = membership.startAt;
          if (startAtRaw instanceof Timestamp) {
            const startDateOnly = koreaDateOnly(startAtRaw.toDate());
            nextDaysValue =
              daysBetweenKoreaDates(startDateOnly, nextPassEnd) + 1;
          }
        }
        const pauseUsedDaysCurrent =
          typeof membership.pauseUsedDays === "number" ?
            membership.pauseUsedDays :
            typeof current.membershipPauseUsedDays === "number" ?
              current.membershipPauseUsedDays : 0;
        const nextPauseUsedDays = pauseUsedDaysCurrent + actualPauseDays;
        transaction.update(memberRef, {
          "memberStatus": "활성",
          "membershipStatus": "active",
          "membership.status": "active",
          "membership.resumedAt": nowServer,
          "membership.pauseActualDays": actualPauseDays,
          "membership.lastPauseActualDays": actualPauseDays,
          "membership.pauseUsedDays": nextPauseUsedDays,
          "membership.updatedAt": nowServer,
          ...(nextPassEndTimestamp != null ?
            {"membership.endAt": nextPassEndTimestamp} : {}),
          ...(nextDaysValue != null ?
            {"membership.days": nextDaysValue} : {}),
          ...(nextPassEndTimestamp != null ?
            {membershipResumeExtendedEndAt: nextPassEndTimestamp} : {}),
          "membershipPauseActualDays": actualPauseDays,
          "membershipPauseUsedDays": nextPauseUsedDays,
          "membershipPauseHistory": FieldValue.arrayUnion({
            type: "resume",
            at: now,
            actualDays: actualPauseDays,
            plannedDays: plannedDays,
            ...(nextPassEndTimestamp != null ?
              {extendedEndAt: nextPassEndTimestamp} : {}),
            source: "client_card",
          }),
          "updatedAt": nowServer,
        });
        return {
          updated: true,
          memberId,
          action,
          actualPauseDays,
          plannedDays,
          nextPassEndMillis: nextPassEndTimestamp?.toMillis() ?? null,
          nextDays: nextDaysValue,
        };
      });
    } catch (error) {
      return translateError(error, "updateManagedMemberMembershipPause");
    }
  };
}
