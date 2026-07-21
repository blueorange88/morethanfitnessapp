import {createHash} from "crypto";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";

import {
  evaluateEarnedTier,
  hasLinkedProvider,
  isTrainerProfileComplete,
  tierRank,
} from "./tier_qualification.js";

const BEGINNER_MEMBER_THRESHOLD = 10;
const MEMBER_SCHEMA_VERSION = 2;
const MANAGED_STATES = ["active", "paused", "dormant", "expired", "deleted"] as const;
const GENDERS = ["male", "female"] as const;

type ManagedState = typeof MANAGED_STATES[number];
type Gender = typeof GENDERS[number];

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
      "idempotencyKey", "name", "gender", "phone", "activityRegion", "note",
    ]);
    const idempotencyKey = requiredString(data, "idempotencyKey");
    const name = requiredString(data, "name");
    const gender = requiredGender(data);
    const phone = requiredString(data, "phone");
    const phoneNormalized = normalizedPhone(phone);
    const activityRegion = requiredString(data, "activityRegion");
    const note = optionalString(data, "note");
    requireMaxLength(idempotencyKey, "idempotencyKey", 128);
    requireMaxLength(name, "name", 80);
    requireMaxLength(phone, "phone", 32);
    requireMaxLength(activityRegion, "activityRegion", 120);
    requireMaxLength(note, "note", 1000);

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
          gender,
          phone,
          phoneNormalized,
          activityRegion,
          note,
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
        transaction.update(memberRef, {
          managementState: nextState,
          countsTowardLimit: countsTowardManaged(nextState),
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

export function updateManagedMemberHandler(db: FirebaseFirestore.Firestore) {
  return async (raw: unknown, ctx: functions.https.CallableContext) => {
    const uid = requireUid(ctx);
    const data = objectData(raw);
    allowOnly(data, ["memberId", "name", "gender", "phone", "activityRegion", "note"]);
    const memberId = requiredString(data, "memberId");
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
        const current = memberSnapshot.data() ?? {};
        if (current.memberId !== memberId || current.trainerId !== uid ||
            current.workspaceType !== "personal") {
          throw new functions.https.HttpsError("permission-denied", "member_owner_mismatch");
        }
        const merged = {...current, ...data};
        const name = requiredString(merged, "name");
        const gender = requiredGender(merged);
        const phone = requiredString(merged, "phone");
        const phoneNormalized = normalizedPhone(phone);
        const activityRegion = requiredString(merged, "activityRegion");
        const note = optionalString(merged, "note");
        requireMaxLength(name, "name", 80);
        requireMaxLength(phone, "phone", 32);
        requireMaxLength(activityRegion, "activityRegion", 120);
        requireMaxLength(note, "note", 1000);
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
        transaction.update(memberRef, {
          name,
          gender,
          phone,
          phoneNormalized,
          activityRegion,
          note,
          countsTowardLifetimeQualification: true,
          ...(firstQualification ? {qualifiedAt: now} : {}),
          updatedAt: now,
        });
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
        };
      });
    } catch (error) {
      return translateError(error, "updateManagedMember");
    }
  };
}
