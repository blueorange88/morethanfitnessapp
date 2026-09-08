import {FieldValue} from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";

import {
  areValidActivityRegions,
  evaluateEarnedTier,
  hasLinkedProvider,
  isValidActivityRegion,
  isKnownActivityRegion,
  isValidAffiliationType,
  isValidPrimaryActivity,
  isValidTrainerJobTitle,
  isValidTrainerEnglishName,
  isValidTrainerRealName,
  isTrainerProfileComplete,
  normalizeActivityRegions,
  tierRank,
} from "./tier_qualification.js";
import {normalizePersonalTaxonomyName} from "./personal_member_taxonomy.js";

const PROFILE_SCHEMA_VERSION = 1;
const RECENT_AUTH_MAX_AGE_SECONDS = 5 * 60;

type BootstrapProfileResult = {
  created: boolean;
  profile: {
    trainerId: string;
    accountState: string;
    tier: string;
    workspaceType: string;
    workspaceStatus: string;
    role: string;
    isAnonymous?: boolean;
    managedMemberLimit?: number;
    managedMemberCount?: number;
    lifetimeQualifiedMemberCount?: number;
    schemaVersion: number;
  };
};

type LinkedProfileResult = {
  changed: boolean;
  profile: BootstrapProfileResult["profile"];
};

type NicknameOnboardingResult = {
  completed: true;
  changed: boolean;
  nickname: string;
};

type PersonalTierReconcileResult = {
  tier: string;
  scheduleCount: number;
  scheduleGoal: number;
  scheduleMissionCompleted: boolean;
  teacherInfoCompleted: boolean;
  completedMissionCount: number;
  totalMissionCount: number;
  eligible: boolean;
  changed: boolean;
  promoted: boolean;
  transitionId?: string;
};

type FirstLessonGuideClaimResult = {
  shouldShow: boolean;
  alreadyShown: boolean;
  scheduleCount: number;
};

const AMATEUR_SCHEDULE_GOAL = 10;

function isActivePersonalSchedule(
  data: FirebaseFirestore.DocumentData,
): boolean {
  if (data.isDeleted === true || data.deleted === true ||
      data.tombstone === true || data.voided === true ||
      data.archived === true || data.deletedAt != null) {
    return false;
  }
  const status = [
    data.status,
    data.scheduleStatus,
    data.lessonStatus,
    data.deleteStatus,
  ].map((value) => String(value ?? "").trim().toLowerCase()).join(" ");
  return !status.includes("deleted") &&
    !status.includes("delete") &&
    !status.includes("removed") &&
    !status.includes("archived") &&
    !status.includes("voided") &&
    !status.includes("pending_delete");
}

function isAnonymous(ctx: functions.https.CallableContext): boolean {
  const firebase = ctx.auth?.token?.firebase as
    | {sign_in_provider?: string}
    | undefined;
  return firebase?.sign_in_provider === "anonymous";
}

export function isRecentAuthentication(
  authTime: unknown,
  nowSeconds = Math.floor(Date.now() / 1000),
): boolean {
  const parsed = Number(authTime);
  return Number.isFinite(parsed) &&
    parsed <= nowSeconds + 60 &&
    nowSeconds - parsed <= RECENT_AUTH_MAX_AGE_SECONDS;
}

export function createCompleteInitialPasswordChangeHandler(
  db: FirebaseFirestore.Firestore,
) {
  return async (
    _data: unknown,
    ctx: functions.https.CallableContext,
  ): Promise<{completed: true; changed: boolean}> => {
    if (!ctx.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication is required.",
      );
    }
    if (isAnonymous(ctx)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "anonymous_not_allowed",
      );
    }
    if (!isRecentAuthentication(ctx.auth.token.auth_time)) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "recent_auth_required",
      );
    }

    const uid = ctx.auth.uid;
    const profileRef = db.collection("trainer_profiles").doc(uid);
    try {
      return await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(profileRef);
        if (!snapshot.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            "profile_not_found",
          );
        }
        const profile = snapshot.data() ?? {};
        if (profile.trainerId !== uid) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "profile_conflict",
          );
        }
        if (profile.mustChangePassword !== true) {
          return {completed: true, changed: false};
        }
        transaction.update(profileRef, {
          mustChangePassword: false,
          passwordChangedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {completed: true, changed: true};
      });
    } catch (error) {
      if (error instanceof functions.https.HttpsError) throw error;
      functions.logger.error("completeInitialPasswordChange failed", {
        uid,
        errorName: error instanceof Error ? error.name : "UnknownError",
      });
      throw new functions.https.HttpsError("internal", "internal");
    }
  };
}

function publicProfile(
  uid: string,
  data: FirebaseFirestore.DocumentData,
): BootstrapProfileResult["profile"] {
  return {
    trainerId: uid,
    accountState: String(data.accountState ?? ""),
    tier: String(data.tier ?? ""),
    workspaceType: String(data.workspaceType ?? ""),
    workspaceStatus: String(data.workspaceStatus ?? ""),
    role: String(data.role ?? ""),
    isAnonymous: data.isAnonymous === true,
    managedMemberLimit: Number(data.managedMemberLimit ?? 0),
    managedMemberCount: Number(data.managedMemberCount ?? 0),
    lifetimeQualifiedMemberCount: Number(
      data.lifetimeQualifiedMemberCount ?? 0,
    ),
    schemaVersion: Number(data.schemaVersion ?? 0),
  };
}

export function createBootstrapAnonymousBeginnerProfileHandler(
  db: FirebaseFirestore.Firestore,
) {
  return async (
    _data: unknown,
    ctx: functions.https.CallableContext,
  ): Promise<BootstrapProfileResult> => {
    if (!ctx.auth) {
      throw new functions.https.HttpsError("unauthenticated", "auth_required");
    }
    if (!isAnonymous(ctx)) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "anonymous_required",
      );
    }

    const uid = ctx.auth.uid;
    const profileRef = db.collection("trainer_profiles").doc(uid);
    try {
      return await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(profileRef);
        if (existing.exists) {
          const data = existing.data() ?? {};
          if (data.trainerId !== uid) {
            throw new functions.https.HttpsError(
              "failed-precondition",
              "profile_conflict",
            );
          }
          if (data.isAnonymous !== true || data.accountState !== "local") {
            throw new functions.https.HttpsError(
              "already-exists",
              "linked_profile_exists",
            );
          }
          return {created: false, profile: publicProfile(uid, data)};
        }

        const now = FieldValue.serverTimestamp();
        const profile = {
          trainerId: uid,
          accountState: "local",
          tier: "Beginner",
          workspaceType: "personal",
          workspaceStatus: "active",
          role: "personal",
          isAnonymous: true,
          managedMemberLimit: 10,
          managedMemberCount: 0,
          lifetimeQualifiedMemberCount: 0,
          schemaVersion: PROFILE_SCHEMA_VERSION,
          createdAt: now,
          updatedAt: now,
        };
        transaction.create(profileRef, profile);
        return {created: true, profile: publicProfile(uid, profile)};
      });
    } catch (error) {
      if (error instanceof functions.https.HttpsError) throw error;
      functions.logger.error("bootstrapAnonymousBeginnerProfile failed", {
        errorName: error instanceof Error ? error.name : "UnknownError",
      });
      throw new functions.https.HttpsError("internal", "internal");
    }
  };
}

export function createReconcilePersonalTierHandler(
  db: FirebaseFirestore.Firestore,
) {
  return async (
    _data: unknown,
    ctx: functions.https.CallableContext,
  ): Promise<PersonalTierReconcileResult> => {
    if (!ctx.auth) {
      throw new functions.https.HttpsError("unauthenticated", "auth_required");
    }

    const uid = ctx.auth.uid;
    const profileRef = db.collection("trainer_profiles").doc(uid);
    const transitionId = profileRef.collection("_transition_ids").doc().id;
    const schedulesQuery = db.collection("schedules")
      .where("trainerId", "==", uid)
      .where("workspaceType", "==", "personal");
    try {
      return await db.runTransaction(async (transaction) => {
        const [snapshot, schedulesSnapshot] = await Promise.all([
          transaction.get(profileRef),
          transaction.get(schedulesQuery),
        ]);
        if (!snapshot.exists) {
          throw new functions.https.HttpsError("not-found", "profile_not_found");
        }
        const profile = snapshot.data() ?? {};
        if (profile.trainerId !== uid || profile.workspaceType !== "personal" ||
            profile.workspaceStatus !== "active" || profile.role !== "personal") {
          throw new functions.https.HttpsError(
            "permission-denied",
            "workspace_not_eligible",
          );
        }

        const scheduleCount = schedulesSnapshot.docs
          .filter((document) => isActivePersonalSchedule(document.data()))
          .length;
        const scheduleMissionCompleted =
          scheduleCount >= AMATEUR_SCHEDULE_GOAL;
        const teacherInfoCompleted = isTrainerProfileComplete(profile);
        const completedMissionCount = Number(scheduleMissionCompleted) +
          Number(teacherInfoCompleted);
        const eligible = completedMissionCount === 2;
        const currentRank = tierRank(profile.tier);
        const progress = {
          scheduleCount,
          scheduleGoal: AMATEUR_SCHEDULE_GOAL,
          scheduleMissionCompleted,
          teacherInfoCompleted,
          completedMissionCount,
          totalMissionCount: 2,
        };
        const previousProgress = profile.personalTierProgress ?? {};
        const progressChanged = JSON.stringify(previousProgress) !==
          JSON.stringify(progress);
        const shouldPromote = eligible && currentRank < 1;
        const updates: Record<string, unknown> = {};
        if (progressChanged) {
          updates.personalTierProgress = progress;
        }
        if (shouldPromote) {
          updates.tier = "Amateur";
          updates.tierUpdatedAt = FieldValue.serverTimestamp();
          updates.tierTransitionSource = "reconcilePersonalTier";
          updates.lastTierTransitionId = transitionId;
          updates.lastTierTransitionFrom = "Beginner";
          updates.lastTierTransitionTo = "Amateur";
          if (profile.amateurAchievedAt == null) {
            updates.amateurAchievedAt = FieldValue.serverTimestamp();
          }
        }
        if (Object.keys(updates).length > 0) transaction.update(profileRef, updates);

        const tier = shouldPromote ? "Amateur" :
          String(profile.tier ?? "Beginner");
        functions.logger.info("[MTF_TIER_RECONCILE]", {
          currentTier: String(profile.tier ?? "Beginner"),
          scheduleCount,
          scheduleGoal: AMATEUR_SCHEDULE_GOAL,
          scheduleMissionCompleted,
          teacherInfoCompleted,
          completedMissionCount,
          eligible,
          action: shouldPromote ? "promote" : "keep",
          result: "success",
        });
        return {
          tier,
          ...progress,
          eligible,
          changed: shouldPromote || progressChanged,
          promoted: shouldPromote,
          ...(shouldPromote ? {transitionId} : {}),
        };
      });
    } catch (error) {
      if (error instanceof functions.https.HttpsError) throw error;
      functions.logger.error("reconcilePersonalTier failed", {
        errorName: error instanceof Error ? error.name : "UnknownError",
      });
      throw new functions.https.HttpsError("internal", "internal");
    }
  };
}

export function createClaimTierCelebrationHandler(
  db: FirebaseFirestore.Firestore,
) {
  return async (raw: unknown, ctx: functions.https.CallableContext) => {
    if (!ctx.auth) {
      throw new functions.https.HttpsError("unauthenticated", "auth_required");
    }
    if (raw == null || typeof raw !== "object" || Array.isArray(raw)) {
      throw new functions.https.HttpsError("invalid-argument", "invalid_payload");
    }
    const data = raw as Record<string, unknown>;
    const transitionId = String(data.transitionId ?? "").trim();
    if (transitionId.length === 0 || transitionId.length > 80) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "transition_id_invalid",
      );
    }

    const profileRef = db.collection("trainer_profiles").doc(ctx.auth.uid);
    return db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(profileRef);
      if (!snapshot.exists) {
        throw new functions.https.HttpsError("not-found", "profile_not_found");
      }
      const profile = snapshot.data() ?? {};
      if (profile.trainerId !== ctx.auth?.uid ||
          profile.workspaceType !== "personal") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "workspace_not_eligible",
        );
      }
      if (profile.lastTierTransitionId !== transitionId ||
          profile.lastTierTransitionTo !== "Amateur") {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "transition_not_current",
        );
      }
      if (profile.lastCelebratedTierTransitionId === transitionId) {
        return {claimed: false, alreadyClaimed: true};
      }
      transaction.update(profileRef, {
        lastCelebratedTierTransitionId: transitionId,
        tierCelebrationClaimedAt: FieldValue.serverTimestamp(),
      });
      return {claimed: true, alreadyClaimed: false};
    });
  };
}

export function createClaimFirstLessonGuideHandler(
  db: FirebaseFirestore.Firestore,
) {
  return async (
    data: unknown,
    ctx: functions.https.CallableContext,
  ): Promise<FirstLessonGuideClaimResult> => {
    if (!ctx.auth) {
      throw new functions.https.HttpsError("unauthenticated", "auth_required");
    }
    const uid = ctx.auth.uid;
    const raw = data as {createdScheduleCount?: unknown} | null;
    const createdScheduleCount = Number(raw?.createdScheduleCount);
    if (!Number.isInteger(createdScheduleCount) ||
        createdScheduleCount < 1 || createdScheduleCount > 7) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "invalid_created_schedule_count",
      );
    }
    const profileRef = db.collection("trainer_profiles").doc(uid);
    const schedulesQuery = db.collection("schedules")
      .where("trainerId", "==", uid)
      .where("workspaceType", "==", "personal");
    try {
      return await db.runTransaction(async (transaction) => {
        const [profileSnapshot, schedulesSnapshot] = await Promise.all([
          transaction.get(profileRef),
          transaction.get(schedulesQuery),
        ]);
        if (!profileSnapshot.exists) {
          throw new functions.https.HttpsError("not-found", "profile_not_found");
        }
        const profile = profileSnapshot.data() ?? {};
        if (profile.trainerId !== uid || profile.workspaceType !== "personal" ||
            profile.workspaceStatus !== "active" || profile.role !== "personal") {
          throw new functions.https.HttpsError(
            "permission-denied",
            "workspace_not_eligible",
          );
        }
        const scheduleCount = schedulesSnapshot.docs
          .filter((document) => isActivePersonalSchedule(document.data()))
          .length;
        const guide = profile.aiFcNudge as Record<string, unknown> | undefined;
        const alreadyShown = guide?.firstLessonGuideShown === true;
        if (alreadyShown || scheduleCount !== createdScheduleCount) {
          return {shouldShow: false, alreadyShown, scheduleCount};
        }
        transaction.update(profileRef, {
          "aiFcNudge.firstLessonGuideShown": true,
          "aiFcNudge.firstLessonGuideShownAt": FieldValue.serverTimestamp(),
        });
        return {shouldShow: true, alreadyShown: false, scheduleCount};
      });
    } catch (error) {
      if (error instanceof functions.https.HttpsError) throw error;
      functions.logger.error("claimFirstLessonGuide failed", {
        errorName: error instanceof Error ? error.name : "UnknownError",
      });
      throw new functions.https.HttpsError("internal", "internal");
    }
  };
}

export function createTransitionAnonymousProfileToLinkedHandler(
  db: FirebaseFirestore.Firestore,
) {
  return async (
    _data: unknown,
    ctx: functions.https.CallableContext,
  ): Promise<LinkedProfileResult> => {
    if (!ctx.auth) {
      throw new functions.https.HttpsError("unauthenticated", "auth_required");
    }
    if (!hasLinkedProvider(ctx)) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "linked_provider_required",
      );
    }

    const uid = ctx.auth.uid;
    const profileRef = db.collection("trainer_profiles").doc(uid);
    try {
      return await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(profileRef);
        if (!snapshot.exists) {
          throw new functions.https.HttpsError("not-found", "profile_not_found");
        }
        const profile = snapshot.data() ?? {};
        if (profile.trainerId !== uid) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "profile_conflict",
          );
        }
        if (profile.role !== "personal") {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "immutable_identity_conflict",
          );
        }
        if (profile.accountState === "linked" && profile.isAnonymous === false) {
          return {changed: false, profile: publicProfile(uid, profile)};
        }
        if (profile.accountState !== "local" && profile.isAnonymous !== true) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "anonymous_profile_required",
          );
        }

        const profileCompleted = isTrainerProfileComplete(profile);
        const lifetimeCount = Number(
          profile.lifetimeQualifiedMemberCount ?? 0,
        );
        const earned = evaluateEarnedTier({
          currentTier: profile.tier,
          lifetimeQualifiedMemberCount: lifetimeCount,
          accountLinked: true,
          profileCompleted,
        });
        transaction.update(profileRef, {
          accountState: "linked",
          isAnonymous: false,
          accountLinked: true,
          profileCompleted,
          tier: earned.tier,
          earnedTier: earned.tier,
          earnedTierRank: earned.rank,
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {
          changed: true,
          profile: publicProfile(uid, {
            ...profile,
            accountState: "linked",
            isAnonymous: false,
            tier: earned.tier,
          }),
        };
      });
    } catch (error) {
      if (error instanceof functions.https.HttpsError) throw error;
      functions.logger.error("transitionAnonymousProfileToLinked failed", {
        errorName: error instanceof Error ? error.name : "UnknownError",
      });
      throw new functions.https.HttpsError("internal", "internal");
    }
  };
}

function profileString(
  data: Record<string, unknown>,
  key: string,
  maxLength: number,
): string {
  const value = data[key];
  if (typeof value !== "string") {
    throw new functions.https.HttpsError("invalid-argument", `${key}_invalid`);
  }
  const clean = value.trim();
  if (clean.length > maxLength) {
    throw new functions.https.HttpsError("invalid-argument", `${key}_too_long`);
  }
  return clean;
}

export function createCompleteNicknameOnboardingHandler(
  db: FirebaseFirestore.Firestore,
) {
  return async (
    raw: unknown,
    ctx: functions.https.CallableContext,
  ): Promise<NicknameOnboardingResult> => {
    if (!ctx.auth) {
      throw new functions.https.HttpsError("unauthenticated", "auth_required");
    }
    if (raw == null || typeof raw !== "object" || Array.isArray(raw)) {
      throw new functions.https.HttpsError("invalid-argument", "invalid_payload");
    }
    const data = raw as Record<string, unknown>;
    if (Object.keys(data).some((key) => key !== "nickname")) {
      throw new functions.https.HttpsError("invalid-argument", "unknown_fields");
    }
    const nickname = profileString(data, "nickname", 6);
    if (nickname.length === 0) {
      throw new functions.https.HttpsError("invalid-argument", "nickname_empty");
    }

    const uid = ctx.auth.uid;
    const profileRef = db.collection("trainer_profiles").doc(uid);
    try {
      return await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(profileRef);
        if (!snapshot.exists) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "profile_not_found",
          );
        }
        const current = snapshot.data() ?? {};
        if (current.trainerId !== uid || current.workspaceType !== "personal" ||
            current.workspaceStatus !== "active" || current.role !== "personal") {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "profile_identity_conflict",
          );
        }

        const alreadyCompleted = current.onboardingCompleted === true;
        const changed = current.nickname !== nickname || !alreadyCompleted;
        const updates: Record<string, unknown> = {
          nickname,
          onboardingCompleted: true,
          updatedAt: FieldValue.serverTimestamp(),
        };
        if (!alreadyCompleted) {
          updates.onboardingCompletedAt = FieldValue.serverTimestamp();
        }
        transaction.update(profileRef, updates);
        return {completed: true, changed, nickname};
      });
    } catch (error) {
      if (error instanceof functions.https.HttpsError) throw error;
      functions.logger.error("completeNicknameOnboarding failed", {
        errorName: error instanceof Error ? error.name : "UnknownError",
      });
      throw new functions.https.HttpsError("internal", "internal");
    }
  };
}

export function createUpdatePersonalTrainerProfileHandler(
  db: FirebaseFirestore.Firestore,
) {
  return async (raw: unknown, ctx: functions.https.CallableContext) => {
    if (!ctx.auth) {
      throw new functions.https.HttpsError("unauthenticated", "auth_required");
    }
    if (raw == null || typeof raw !== "object" || Array.isArray(raw)) {
      throw new functions.https.HttpsError("invalid-argument", "invalid_payload");
    }
    const data = raw as Record<string, unknown>;
    const allowed = [
      "displayName", "phone", "activityRegion", "primaryActivity",
      "affiliationType", "nickname", "realName", "jobTitle",
      "birth", "contractTrainerNameSource", "contractTrainerCustomName",
      "nameEn", "activityRegions", "gymName", "centerLocation",
      "memberDefaultGroupLabel", "customLessonTypes", "intro",
    ];
    if (Object.keys(data).some((key) => !allowed.includes(key))) {
      throw new functions.https.HttpsError("invalid-argument", "unknown_fields");
    }
    if (Object.keys(data).length === 0) {
      throw new functions.https.HttpsError("invalid-argument", "no_updates");
    }
    const updates: Record<string, unknown> = {};
    for (const key of allowed) {
      if (Object.prototype.hasOwnProperty.call(data, key)) {
        if (key === "activityRegions" || key === "customLessonTypes") continue;
        const maxLength = key === "phone" ? 32 :
          key === "birth" ? 10 : key === "nickname" ? 6 :
            key === "nameEn" ? 40 : key === "intro" ? 200 : 120;
        updates[key] = profileString(data, key, maxLength);
      }
    }
    if (Object.prototype.hasOwnProperty.call(data, "activityRegions")) {
      if (!areValidActivityRegions(data.activityRegions)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "activity_regions_invalid",
        );
      }
      const regions = normalizeActivityRegions(data.activityRegions, null);
      updates.activityRegions = regions;
      updates.activityRegion = regions[0];
    }
    if (Object.prototype.hasOwnProperty.call(data, "customLessonTypes")) {
      if (!Array.isArray(data.customLessonTypes)) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "custom_lesson_types_invalid",
        );
      }
      const seen = new Set<string>();
      const values: string[] = [];
      for (const rawValue of data.customLessonTypes) {
        if (typeof rawValue !== "string") {
          throw new functions.https.HttpsError(
            "invalid-argument",
            "custom_lesson_types_invalid",
          );
        }
        const value = rawValue.trim().replace(/\s+/g, " ");
        const key = value.toLocaleLowerCase("ko-KR");
        if (value.length === 0 || value.length > 40 || seen.has(key)) {
          throw new functions.https.HttpsError(
            "invalid-argument",
            "custom_lesson_types_invalid",
          );
        }
        seen.add(key);
        values.push(value);
      }
      if (values.length > 30) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "custom_lesson_types_invalid",
        );
      }
      updates.customLessonTypes = values;
    }
    if (Object.prototype.hasOwnProperty.call(
      updates,
      "memberDefaultGroupLabel",
    )) {
      updates.memberDefaultGroupLabel = normalizePersonalTaxonomyName(
        updates.memberDefaultGroupLabel,
        "member_default_group_label_invalid",
      ).name;
    }

    const validateOptional = (
      key: string,
      validator: (value: unknown) => boolean,
      errorCode: string,
    ) => {
      if (!Object.prototype.hasOwnProperty.call(updates, key)) return;
      const value = String(updates[key] ?? "").trim();
      if (value.length > 0 && !validator(value)) {
        throw new functions.https.HttpsError("invalid-argument", errorCode);
      }
    };
    validateOptional("realName", isValidTrainerRealName, "real_name_invalid");
    validateOptional("jobTitle", isValidTrainerJobTitle, "job_title_invalid");
    validateOptional(
      "primaryActivity",
      isValidPrimaryActivity,
      "primary_activity_invalid",
    );
    validateOptional(
      "affiliationType",
      isValidAffiliationType,
      "affiliation_type_invalid",
    );
    validateOptional(
      "activityRegion",
      (value) => isValidActivityRegion(value) && isKnownActivityRegion(value),
      "activity_region_invalid",
    );
    validateOptional("nameEn", isValidTrainerEnglishName, "name_en_invalid");
    if (Object.prototype.hasOwnProperty.call(updates, "nameEn")) {
      updates.nameEn = String(updates.nameEn).replace(/\s+/g, " ");
    }
    functions.logger.debug("[MTF_PROFILE_VALIDATION]", {
      field: "englishName",
      present: String(updates.nameEn ?? "").length > 0,
      result: Object.prototype.hasOwnProperty.call(updates, "nameEn") ?
        "valid" : "not_provided",
      errorCode: "none",
    });
    validateOptional("phone", (value) => {
      const digits = String(value).replace(/\D/g, "");
      return /^(010\d{8}|01[16789]\d{7,8})$/.test(digits);
    }, "phone_invalid");
    validateOptional("birth", (value) => {
      const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(String(value));
      if (!match) return false;
      const year = Number(match[1]);
      const month = Number(match[2]);
      const day = Number(match[3]);
      const date = new Date(Date.UTC(year, month - 1, day));
      const now = new Date();
      return year >= 1900 && date.getUTCFullYear() === year &&
        date.getUTCMonth() === month - 1 && date.getUTCDate() === day &&
        date.getTime() <= now.getTime();
    }, "birth_invalid");
    if (Object.prototype.hasOwnProperty.call(updates, "nickname") &&
        (updates.nickname as string).length === 0) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "nickname_empty",
      );
    }
    if (Object.prototype.hasOwnProperty.call(
      updates,
      "contractTrainerNameSource",
    ) && !["displayName", "realName", "manual"].includes(
      updates.contractTrainerNameSource as string,
    )) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "contract_source_invalid",
      );
    }

    const uid = ctx.auth.uid;
    const profileRef = db.collection("trainer_profiles").doc(uid);
    try {
      return await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(profileRef);
        if (!snapshot.exists) {
          throw new functions.https.HttpsError("not-found", "profile_not_found");
        }
        const current = snapshot.data() ?? {};
        if (current.trainerId !== uid || current.workspaceType !== "personal" ||
            current.workspaceStatus !== "active" || current.role !== "personal") {
          throw new functions.https.HttpsError(
            "permission-denied",
            "workspace_not_eligible",
          );
        }
        const accountLinked = hasLinkedProvider(ctx);
        const validLocal = !accountLinked && current.accountState === "local" &&
          current.isAnonymous === true;
        const validLinked = accountLinked &&
          (current.accountState === "linked" || current.accountState === "verified") &&
          current.isAnonymous !== true;
        if (!validLocal && !validLinked) {
          throw new functions.https.HttpsError(
            "permission-denied",
            "workspace_not_eligible",
          );
        }
        if (Object.prototype.hasOwnProperty.call(
          updates,
          "memberDefaultGroupLabel",
        )) {
          const normalizedDefaultName = normalizePersonalTaxonomyName(
            updates.memberDefaultGroupLabel,
            "member_default_group_label_invalid",
          ).normalizedName;
          const duplicateGroups = await transaction.get(
            profileRef.collection("personal_groups")
              .where("normalizedName", "==", normalizedDefaultName)
              .limit(1),
          );
          if (!duplicateGroups.empty) {
            throw new functions.https.HttpsError(
              "already-exists",
              "duplicate_group_name",
            );
          }
        }
        const merged = {...current, ...updates};
        const contractPatch: Record<string, unknown> = {};
        if (Object.prototype.hasOwnProperty.call(
          updates,
          "contractTrainerNameSource",
        )) {
          const source = updates.contractTrainerNameSource as string;
          const nickname = String(merged.nickname ?? "").trim();
          const realName = String(merged.realName ?? "").trim();
          const customName = String(
            merged.contractTrainerCustomName ?? "",
          ).trim();
          let contractTrainerName = "";
          if (source === "displayName") contractTrainerName = nickname;
          if (source === "realName") contractTrainerName = realName;
          if (source === "manual") contractTrainerName = customName;
          if (contractTrainerName.length === 0) {
            throw new functions.https.HttpsError(
              "invalid-argument",
              `contract_${source}_empty`,
            );
          }
          contractPatch.contractTrainerName = contractTrainerName;
        }
        const profileCompleted = isTrainerProfileComplete(merged);
        const lifetimeCount = Number(
          current.lifetimeQualifiedMemberCount ?? 0,
        );
        if (!Number.isInteger(lifetimeCount) || lifetimeCount < 0) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "member_count_conflict",
          );
        }
        const earned = evaluateEarnedTier({
          currentTier: current.tier,
          lifetimeQualifiedMemberCount: lifetimeCount,
          accountLinked,
          profileCompleted,
        });
        transaction.update(profileRef, {
          ...updates,
          ...contractPatch,
          accountLinked,
          profileCompleted,
          tier: earned.tier,
          earnedTier: earned.tier,
          earnedTierRank: earned.rank,
          tierEvaluatedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {
          updated: true,
          profileCompleted,
          accountLinked,
          tier: earned.tier,
          lifetimeQualifiedMemberCount: lifetimeCount,
        };
      });
    } catch (error) {
      if (error instanceof functions.https.HttpsError) throw error;
      functions.logger.error("updatePersonalTrainerProfile failed", {
        errorName: error instanceof Error ? error.name : "UnknownError",
      });
      throw new functions.https.HttpsError("internal", "internal");
    }
  };
}

export function createBootstrapTrainerProfileHandler(
  db: FirebaseFirestore.Firestore,
) {
  return async (
    _data: unknown,
    ctx: functions.https.CallableContext,
  ): Promise<BootstrapProfileResult> => {
    if (!ctx.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Authentication is required.",
      );
    }
    if (isAnonymous(ctx)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "anonymous_not_allowed",
      );
    }

    const uid = ctx.auth.uid;
    const profileRef = db.collection("trainer_profiles").doc(uid);

    try {
      return await db.runTransaction(async (transaction) => {
        const existing = await transaction.get(profileRef);
        if (existing.exists) {
          const data = existing.data() ?? {};
          if (data.trainerId !== uid) {
            throw new functions.https.HttpsError(
              "failed-precondition",
              "profile_conflict",
            );
          }
          return {created: false, profile: publicProfile(uid, data)};
        }

        const now = FieldValue.serverTimestamp();
        const profile = {
          trainerId: uid,
          accountState: "linked",
          tier: "Beginner",
          workspaceType: "personal",
          workspaceStatus: "active",
          role: "personal",
          schemaVersion: PROFILE_SCHEMA_VERSION,
          managedMemberCount: 0,
          managedMemberLimit: 10,
          usageUpdatedAt: now,
          createdAt: now,
          updatedAt: now,
        };
        transaction.create(profileRef, profile);
        return {created: true, profile: publicProfile(uid, profile)};
      });
    } catch (error) {
      if (error instanceof functions.https.HttpsError) throw error;
      functions.logger.error("bootstrapTrainerProfile failed", {
        uid,
        errorName: error instanceof Error ? error.name : "UnknownError",
        errorMessage: error instanceof Error ? error.message : String(error),
      });
      throw new functions.https.HttpsError("internal", "internal");
    }
  };
}
