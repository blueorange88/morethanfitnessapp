import {createHash} from "crypto";
import {FieldValue} from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";

import {hasLinkedProvider, tierRank} from "./tier_qualification.js";

const PERSONAL_GROUPS_COLLECTION = "personal_groups";
const PERSONAL_TAGS_COLLECTION = "personal_tags";
const TAXONOMY_SCHEMA_VERSION = 1;
const MAX_TAXONOMY_ITEMS = 30;
const MAX_TAGS_PER_MEMBER = 20;
const MAX_TRANSACTION_WRITES = 500;

type Data = Record<string, unknown>;
type TaxonomyKind = "group" | "tag";

export type PersonalMemberTaxonomyAssignments = {
  groupProvided: boolean;
  groupId: string | null;
  tagsProvided: boolean;
  tagIds: string[];
};

type NormalizedTaxonomyName = {
  name: string;
  normalizedName: string;
};

function requireUid(ctx: functions.https.CallableContext): string {
  if (!ctx.auth) {
    throw new functions.https.HttpsError("unauthenticated", "auth_required");
  }
  return ctx.auth.uid;
}

function objectData(value: unknown): Data {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new functions.https.HttpsError("invalid-argument", "invalid_payload");
  }
  return value as Data;
}

function allowOnly(data: Data, keys: string[]): void {
  if (Object.keys(data).some((key) => !keys.includes(key))) {
    throw new functions.https.HttpsError("invalid-argument", "unknown_fields");
  }
}

function requiredString(data: Data, key: string): string {
  const value = data[key];
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new functions.https.HttpsError("invalid-argument", `${key}_required`);
  }
  return value.trim();
}

function hasOwn(data: Data, key: string): boolean {
  return Object.prototype.hasOwnProperty.call(data, key);
}

function collectionName(kind: TaxonomyKind): string {
  return kind === "group" ? PERSONAL_GROUPS_COLLECTION : PERSONAL_TAGS_COLLECTION;
}

function idField(kind: TaxonomyKind): string {
  return kind === "group" ? "personalGroupId" : "personalTagId";
}

function requiredRank(kind: TaxonomyKind): number {
  return kind === "group" ? 1 : 2;
}

function tierError(kind: TaxonomyKind): string {
  return kind === "group" ? "amateur_required" : "semi_pro_required";
}

export function normalizePersonalTaxonomyName(
  value: unknown,
  errorCode = "personal_taxonomy_name_invalid",
): NormalizedTaxonomyName {
  if (typeof value !== "string") {
    throw new functions.https.HttpsError("invalid-argument", errorCode);
  }
  const name = value.normalize("NFC").trim().replace(/\s+/gu, " ");
  if (name.length < 2 || name.length > 30) {
    throw new functions.https.HttpsError("invalid-argument", errorCode);
  }
  return {
    name,
    normalizedName: name.toLocaleLowerCase("ko-KR"),
  };
}

function validateProfile(
  uid: string,
  snapshot: FirebaseFirestore.DocumentSnapshot,
  ctx: functions.https.CallableContext,
  minimumRank: number,
  rankError: string,
): FirebaseFirestore.DocumentData {
  if (!snapshot.exists) {
    throw new functions.https.HttpsError("failed-precondition", "profile_required");
  }
  const profile = snapshot.data() ?? {};
  const accountLinked = hasLinkedProvider(ctx);
  const validLocal = !accountLinked && profile.accountState === "local" &&
    profile.isAnonymous === true;
  const validLinked = accountLinked &&
    (profile.accountState === "linked" || profile.accountState === "verified") &&
    profile.isAnonymous !== true;
  if (profile.trainerId !== uid || profile.workspaceType !== "personal" ||
      profile.workspaceStatus !== "active" || profile.role !== "personal" ||
      (!validLocal && !validLinked)) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "workspace_not_eligible",
    );
  }
  if (tierRank(profile.tier) < minimumRank) {
    throw new functions.https.HttpsError("failed-precondition", rankError);
  }
  return profile;
}

function taxonomyId(uid: string, idempotencyKey: string, kind: TaxonomyKind): string {
  const digest = createHash("sha256")
    .update(`${uid}:${kind}:${idempotencyKey}`, "utf8")
    .digest("hex")
    .slice(0, 32);
  return `${kind === "group" ? "pg" : "pt"}_${digest}`;
}

function requireTaxonomyId(data: Data, kind: TaxonomyKind): string {
  const key = idField(kind);
  const value = requiredString(data, key);
  const pattern = kind === "group" ? /^pg_[a-f0-9]{32}$/ : /^pt_[a-f0-9]{32}$/;
  if (!pattern.test(value)) {
    throw new functions.https.HttpsError("invalid-argument", `${key}_invalid`);
  }
  return value;
}

function ensureDefaultGroupNameAvailable(
  kind: TaxonomyKind,
  profile: FirebaseFirestore.DocumentData,
  normalizedName: string,
): void {
  if (kind !== "group") return;
  const defaultName = normalizePersonalTaxonomyName(
    String(profile.memberDefaultGroupLabel ?? "MORE THAN GYM"),
    "member_default_group_label_invalid",
  );
  if (defaultName.normalizedName === normalizedName) {
    throw new functions.https.HttpsError("already-exists", "duplicate_group_name");
  }
}

function translated(error: unknown, operation: string): never {
  if (error instanceof functions.https.HttpsError) throw error;
  functions.logger.error(`[MTF_PERSONAL_TAXONOMY] ${operation} failed`, {
    errorName: error instanceof Error ? error.name : "UnknownError",
  });
  throw new functions.https.HttpsError("internal", "internal");
}

function createTaxonomyHandler(
  db: FirebaseFirestore.Firestore,
  kind: TaxonomyKind,
) {
  return async (raw: unknown, ctx: functions.https.CallableContext) => {
    const uid = requireUid(ctx);
    const data = objectData(raw);
    allowOnly(data, ["idempotencyKey", "name"]);
    const idempotencyKey = requiredString(data, "idempotencyKey");
    if (idempotencyKey.length > 128) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "idempotencyKey_too_long",
      );
    }
    const normalized = normalizePersonalTaxonomyName(data.name);
    const taxonomyIdValue = taxonomyId(uid, idempotencyKey, kind);
    const profileRef = db.collection("trainer_profiles").doc(uid);
    const collectionRef = profileRef.collection(collectionName(kind));
    const taxonomyRef = collectionRef.doc(taxonomyIdValue);
    try {
      return await db.runTransaction(async (transaction) => {
        const [profileSnapshot, taxonomySnapshot, duplicateSnapshot, countSnapshot] =
          await Promise.all([
            transaction.get(profileRef),
            transaction.get(taxonomyRef),
            transaction.get(
              collectionRef.where("normalizedName", "==", normalized.normalizedName),
            ),
            transaction.get(collectionRef.limit(MAX_TAXONOMY_ITEMS + 1)),
          ]);
        const profile = validateProfile(
          uid,
          profileSnapshot,
          ctx,
          requiredRank(kind),
          tierError(kind),
        );
        ensureDefaultGroupNameAvailable(kind, profile, normalized.normalizedName);
        if (taxonomySnapshot.exists) {
          const existing = taxonomySnapshot.data() ?? {};
          if (existing.normalizedName !== normalized.normalizedName) {
            throw new functions.https.HttpsError(
              "already-exists",
              "idempotency_key_conflict",
            );
          }
          return {
            created: false,
            [idField(kind)]: taxonomyIdValue,
          };
        }
        if (!duplicateSnapshot.empty) {
          throw new functions.https.HttpsError(
            "already-exists",
            kind === "group" ? "duplicate_group_name" : "duplicate_tag_name",
          );
        }
        if (countSnapshot.size >= MAX_TAXONOMY_ITEMS) {
          throw new functions.https.HttpsError(
            "resource-exhausted",
            kind === "group" ? "group_limit_reached" : "tag_limit_reached",
          );
        }
        const now = FieldValue.serverTimestamp();
        transaction.create(taxonomyRef, {
          name: normalized.name,
          normalizedName: normalized.normalizedName,
          schemaVersion: TAXONOMY_SCHEMA_VERSION,
          createdAt: now,
          updatedAt: now,
        });
        return {
          created: true,
          [idField(kind)]: taxonomyIdValue,
        };
      });
    } catch (error) {
      return translated(error, `create_${kind}`);
    }
  };
}

function renameTaxonomyHandler(
  db: FirebaseFirestore.Firestore,
  kind: TaxonomyKind,
) {
  return async (raw: unknown, ctx: functions.https.CallableContext) => {
    const uid = requireUid(ctx);
    const data = objectData(raw);
    allowOnly(data, [idField(kind), "name"]);
    const taxonomyIdValue = requireTaxonomyId(data, kind);
    const normalized = normalizePersonalTaxonomyName(data.name);
    const profileRef = db.collection("trainer_profiles").doc(uid);
    const collectionRef = profileRef.collection(collectionName(kind));
    const taxonomyRef = collectionRef.doc(taxonomyIdValue);
    try {
      return await db.runTransaction(async (transaction) => {
        const [profileSnapshot, taxonomySnapshot, duplicateSnapshot] =
          await Promise.all([
            transaction.get(profileRef),
            transaction.get(taxonomyRef),
            transaction.get(
              collectionRef.where("normalizedName", "==", normalized.normalizedName),
            ),
          ]);
        const profile = validateProfile(
          uid,
          profileSnapshot,
          ctx,
          requiredRank(kind),
          tierError(kind),
        );
        ensureDefaultGroupNameAvailable(kind, profile, normalized.normalizedName);
        if (!taxonomySnapshot.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            kind === "group" ? "group_not_found" : "tag_not_found",
          );
        }
        if (duplicateSnapshot.docs.some((document) => document.id !== taxonomyIdValue)) {
          throw new functions.https.HttpsError(
            "already-exists",
            kind === "group" ? "duplicate_group_name" : "duplicate_tag_name",
          );
        }
        transaction.update(taxonomyRef, {
          name: normalized.name,
          normalizedName: normalized.normalizedName,
          updatedAt: FieldValue.serverTimestamp(),
        });
        return {
          renamed: true,
          [idField(kind)]: taxonomyIdValue,
        };
      });
    } catch (error) {
      return translated(error, `rename_${kind}`);
    }
  };
}

function deleteTaxonomyHandler(
  db: FirebaseFirestore.Firestore,
  kind: TaxonomyKind,
) {
  return async (raw: unknown, ctx: functions.https.CallableContext) => {
    const uid = requireUid(ctx);
    const data = objectData(raw);
    allowOnly(data, [idField(kind)]);
    const taxonomyIdValue = requireTaxonomyId(data, kind);
    const profileRef = db.collection("trainer_profiles").doc(uid);
    const taxonomyRef = profileRef
      .collection(collectionName(kind))
      .doc(taxonomyIdValue);
    const membersQuery = db.collection("members")
      .where("trainerId", "==", uid)
      .where("workspaceType", "==", "personal");
    try {
      return await db.runTransaction(async (transaction) => {
        const [profileSnapshot, taxonomySnapshot, membersSnapshot] =
          await Promise.all([
            transaction.get(profileRef),
            transaction.get(taxonomyRef),
            transaction.get(membersQuery),
          ]);
        validateProfile(
          uid,
          profileSnapshot,
          ctx,
          requiredRank(kind),
          tierError(kind),
        );
        if (!taxonomySnapshot.exists) {
          throw new functions.https.HttpsError(
            "not-found",
            kind === "group" ? "group_not_found" : "tag_not_found",
          );
        }
        const affected = membersSnapshot.docs.filter((document) => {
          const member = document.data();
          if (kind === "group") {
            return String(member.personalGroupId ?? "").trim() === taxonomyIdValue;
          }
          return Array.isArray(member.personalTagIds) &&
            member.personalTagIds.includes(taxonomyIdValue);
        });
        const maximumMemberWrites = MAX_TRANSACTION_WRITES - 1;
        if (affected.length > maximumMemberWrites) {
          throw new functions.https.HttpsError(
            "resource-exhausted",
            "taxonomy_delete_write_limit",
          );
        }
        const now = FieldValue.serverTimestamp();
        for (const memberDocument of affected) {
          if (kind === "group") {
            transaction.update(memberDocument.ref, {
              personalGroupId: FieldValue.delete(),
              updatedAt: now,
            });
            continue;
          }
          const member = memberDocument.data();
          const remainingTagIds = (member.personalTagIds as unknown[])
            .map((value) => String(value).trim())
            .filter((value) => value.length > 0 && value !== taxonomyIdValue);
          transaction.update(memberDocument.ref, {
            personalTagIds: remainingTagIds.length === 0 ?
              FieldValue.delete() : remainingTagIds,
            updatedAt: now,
          });
        }
        transaction.delete(taxonomyRef);
        return {
          deleted: true,
          [idField(kind)]: taxonomyIdValue,
          affectedMemberCount: affected.length,
        };
      });
    } catch (error) {
      return translated(error, `delete_${kind}`);
    }
  };
}

export function parsePersonalMemberTaxonomyAssignments(
  data: Data,
): PersonalMemberTaxonomyAssignments {
  const groupProvided = hasOwn(data, "personalGroupId");
  let groupId: string | null = null;
  if (groupProvided && data.personalGroupId != null) {
    if (typeof data.personalGroupId !== "string") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "personalGroupId_invalid",
      );
    }
    groupId = data.personalGroupId.trim();
    if (groupId.length === 0) groupId = null;
    if (groupId != null && !/^pg_[a-f0-9]{32}$/.test(groupId)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "personalGroupId_invalid",
      );
    }
  }

  const tagsProvided = hasOwn(data, "personalTagIds");
  let tagIds: string[] = [];
  if (tagsProvided) {
    if (!Array.isArray(data.personalTagIds) ||
        data.personalTagIds.length > MAX_TAGS_PER_MEMBER) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "personalTagIds_invalid",
      );
    }
    tagIds = data.personalTagIds.map((value) => {
      if (typeof value !== "string") {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "personalTagIds_invalid",
        );
      }
      return value.trim();
    });
    if (tagIds.some((value) => !/^pt_[a-f0-9]{32}$/.test(value)) ||
        new Set(tagIds).size !== tagIds.length) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "personalTagIds_invalid",
      );
    }
    tagIds.sort();
  }

  return {groupProvided, groupId, tagsProvided, tagIds};
}

export async function validatePersonalMemberTaxonomyAssignments(args: {
  transaction: FirebaseFirestore.Transaction;
  db: FirebaseFirestore.Firestore;
  uid: string;
  tier: string;
  assignments: PersonalMemberTaxonomyAssignments;
}): Promise<void> {
  const {transaction, db, uid, tier, assignments} = args;
  if (assignments.groupProvided) {
    if (tierRank(tier) < 1) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "amateur_required",
      );
    }
    if (assignments.groupId != null) {
      const snapshot = await transaction.get(
        db.collection("trainer_profiles")
          .doc(uid)
          .collection(PERSONAL_GROUPS_COLLECTION)
          .doc(assignments.groupId),
      );
      if (!snapshot.exists) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "personal_group_not_found",
        );
      }
    }
  }
  if (assignments.tagsProvided) {
    if (tierRank(tier) < 2) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "semi_pro_required",
      );
    }
    for (const tagId of assignments.tagIds) {
      const snapshot = await transaction.get(
        db.collection("trainer_profiles")
          .doc(uid)
          .collection(PERSONAL_TAGS_COLLECTION)
          .doc(tagId),
      );
      if (!snapshot.exists) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "personal_tag_not_found",
        );
      }
    }
  }
}

export function applyPersonalMemberTaxonomyUpdate(
  update: Data,
  assignments: PersonalMemberTaxonomyAssignments,
): void {
  if (assignments.groupProvided) {
    update.personalGroupId = assignments.groupId ?? FieldValue.delete();
  }
  if (assignments.tagsProvided) {
    update.personalTagIds = assignments.tagIds.length === 0 ?
      FieldValue.delete() : assignments.tagIds;
  }
}

export function personalMemberTaxonomyCreateFields(
  assignments: PersonalMemberTaxonomyAssignments,
): Data {
  return {
    ...(assignments.groupProvided && assignments.groupId != null ?
      {personalGroupId: assignments.groupId} : {}),
    ...(assignments.tagsProvided && assignments.tagIds.length > 0 ?
      {personalTagIds: assignments.tagIds} : {}),
  };
}

export function createPersonalGroupHandler(db: FirebaseFirestore.Firestore) {
  return createTaxonomyHandler(db, "group");
}

export function renamePersonalGroupHandler(db: FirebaseFirestore.Firestore) {
  return renameTaxonomyHandler(db, "group");
}

export function deletePersonalGroupHandler(db: FirebaseFirestore.Firestore) {
  return deleteTaxonomyHandler(db, "group");
}

export function createPersonalTagHandler(db: FirebaseFirestore.Firestore) {
  return createTaxonomyHandler(db, "tag");
}

export function renamePersonalTagHandler(db: FirebaseFirestore.Firestore) {
  return renameTaxonomyHandler(db, "tag");
}

export function deletePersonalTagHandler(db: FirebaseFirestore.Firestore) {
  return deleteTaxonomyHandler(db, "tag");
}
