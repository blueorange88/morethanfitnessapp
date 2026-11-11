import {createHash} from "crypto";
import {FieldValue} from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";

import {
  ContractContent,
  ContractStatus,
  ContractValidationError,
  MEMBER_AGREEMENT_ITEMS,
  SignStep,
  contentHash,
  displayContractNo,
  formatContractNo,
  isOpenStatus,
  isSignStep,
  kstYearMonth,
  normalizeContent,
  normalizeCenterLogoPath,
  normalizeContractDefaults,
  normalizeParty,
  normalizeProductPresets,
  requiredDisclosureItems,
  signTransition,
  validateCheckedItems,
  validateStrokes,
  CONTRACT_TEMPLATE_VERSION,
} from "./personal_contract_rules.js";
import {
  RegistrationResult,
  buildRegistration,
} from "./personal_contract_registration.js";
import {buildMembershipPeriodSync} from "./membership_expiry.js";
import {hasLinkedProvider, tierRank} from "./tier_qualification.js";

export const CONTRACTS = "personal_contracts";
const COUNTERS = "personal_contract_counters";
const SEMI_PRO_RANK = 2;

export type Data = Record<string, unknown>;
export type Db = FirebaseFirestore.Firestore;
export type Ctx = functions.https.CallableContext;

export function requireUid(ctx: Ctx): string {
  if (!ctx.auth) {
    throw new functions.https.HttpsError("unauthenticated", "auth_required");
  }
  return ctx.auth.uid;
}

export function objectData(value: unknown): Data {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new functions.https.HttpsError("invalid-argument", "invalid_payload");
  }
  return value as Data;
}

export function allowOnly(data: Data, keys: string[]): void {
  if (Object.keys(data).some((key) => !keys.includes(key))) {
    throw new functions.https.HttpsError("invalid-argument", "unknown_fields");
  }
}

export function requiredString(data: Data, key: string, max = 128): string {
  const value = data[key];
  if (typeof value !== "string" || value.trim().length === 0 ||
      value.trim().length > max) {
    throw new functions.https.HttpsError("invalid-argument", `${key}_required`);
  }
  return value.trim();
}

export function translated(error: unknown, operation: string): never {
  if (error instanceof functions.https.HttpsError) throw error;
  if (error instanceof ContractValidationError) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      error.issue.code,
      {field: error.issue.field},
    );
  }
  functions.logger.error(`[MTF_PERSONAL_CONTRACT] ${operation} failed`, {
    errorName: error instanceof Error ? error.name : "UnknownError",
  });
  throw new functions.https.HttpsError("internal", "internal");
}

function digestId(prefix: string, seed: string): string {
  const digest = createHash("sha256").update(seed, "utf8").digest("hex");
  return `${prefix}_${digest.slice(0, 32)}`;
}

const CONTRACT_ID_PATTERN = /^pc_[a-f0-9]{32}$/u;

export function requireContractId(data: Data): string {
  const value = requiredString(data, "contractId");
  if (!CONTRACT_ID_PATTERN.test(value)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "contractId_invalid",
    );
  }
  return value;
}

export function requireProfile(
  uid: string,
  snapshot: FirebaseFirestore.DocumentSnapshot,
  ctx: Ctx,
): void {
  if (!snapshot.exists) {
    throw new functions.https.HttpsError("failed-precondition", "profile_required");
  }
  const profile = snapshot.data() ?? {};
  const accountLinked = hasLinkedProvider(ctx);
  const validLinked = accountLinked &&
    (profile.accountState === "linked" || profile.accountState === "verified") &&
    profile.isAnonymous !== true;
  if (profile.trainerId !== uid || profile.workspaceType !== "personal" ||
      profile.workspaceStatus !== "active" || profile.role !== "personal" ||
      !validLinked) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "workspace_not_eligible",
    );
  }
  if (tierRank(profile.tier) < SEMI_PRO_RANK) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "semi_pro_required",
    );
  }
}

export function requireOwnedMember(
  uid: string,
  memberId: string,
  snapshot: FirebaseFirestore.DocumentSnapshot,
): void {
  if (!snapshot.exists) {
    throw new functions.https.HttpsError("not-found", "member_not_found");
  }
  const member = snapshot.data() ?? {};
  if (member.memberId !== memberId || member.trainerId !== uid ||
      member.workspaceType !== "personal") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "member_owner_mismatch",
    );
  }
  if (member.managementState === "deleted" || member.isDeleted === true ||
      member.deleteStatus === "pending_delete") {
    throw new functions.https.HttpsError("failed-precondition", "member_deleted");
  }
}

export function loadOwnedContract(
  uid: string,
  snapshot: FirebaseFirestore.DocumentSnapshot,
): Data {
  if (!snapshot.exists) {
    throw new functions.https.HttpsError("not-found", "contract_not_found");
  }
  const contract = snapshot.data() ?? {};
  if (contract.trainerId !== uid || contract.workspaceType !== "personal") {
    throw new functions.https.HttpsError(
      "permission-denied",
      "contract_owner_mismatch",
    );
  }
  return contract;
}

function emptySignatures(): Data {
  return {disclosure: null, member: null, trainer: null};
}

function contentOf(contract: Data): ContractContent {
  return {
    party: contract.party,
    member: contract.member,
    product: contract.product,
    terms: contract.terms,
  } as ContractContent;
}

export function summary(contractId: string, contract: Data): Data {
  const version = Number(contract.version ?? 1);
  return {
    contractId,
    contractNo: displayContractNo(String(contract.contractNo ?? ""), version),
    version,
    status: contract.status,
    contentHash: contract.contentHash,
  };
}

// ---- savePersonalContractDraft ----
export function createSavePersonalContractDraftHandler(db: Db) {
  return async (raw: unknown, ctx: Ctx) => {
    const uid = requireUid(ctx);
    const data = objectData(raw);
    allowOnly(data, ["idempotencyKey", "contractId", "memberId", "content"]);
    const hasKey = data.idempotencyKey != null;
    const hasId = data.contractId != null;
    if (hasKey === hasId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "idempotencyKey_or_contractId_required",
      );
    }
    const memberId = requiredString(data, "memberId");
    try {
      const content = normalizeContent(data.content, uid);
      const hash = contentHash(content);
      const profileRef = db.collection("trainer_profiles").doc(uid);
      const memberRef = db.collection("members").doc(memberId);
      const contractId = hasKey ?
        digestId("pc", `${uid}:draft:${requiredString(data, "idempotencyKey")}`) :
        requireContractId(data);
      const contractRef = db.collection(CONTRACTS).doc(contractId);

      return await db.runTransaction(async (transaction) => {
        const {yyyyMM, yyMM} = kstYearMonth(new Date());
        const counterRef = db.collection(COUNTERS).doc(`${uid}_${yyyyMM}`);
        const [profileSnap, memberSnap, contractSnap, counterSnap] =
          await Promise.all([
            transaction.get(profileRef),
            transaction.get(memberRef),
            transaction.get(contractRef),
            hasKey ? transaction.get(counterRef) : Promise.resolve(null),
          ]);
        requireProfile(uid, profileSnap, ctx);
        requireOwnedMember(uid, memberId, memberSnap);

        if (hasKey) {
          if (contractSnap.exists) {
            const existing = loadOwnedContract(uid, contractSnap);
            if (existing.memberId !== memberId) {
              throw new functions.https.HttpsError(
                "already-exists",
                "idempotency_key_conflict",
              );
            }
            return {created: false, ...summary(contractId, existing)};
          }
          const lastSequence = Number(counterSnap?.data()?.lastSequence ?? 0);
          const sequence = lastSequence + 1;
          const contractNo = formatContractNo(yyMM, sequence);
          const now = FieldValue.serverTimestamp();
          transaction.set(counterRef, {
            trainerId: uid,
            yyyyMM,
            lastSequence: sequence,
            updatedAt: now,
          });
          transaction.create(contractRef, {
            trainerId: uid,
            workspaceType: "personal",
            memberId,
            contractNo,
            version: 1,
            supersedesId: null,
            supersededById: null,
            status: "draft",
            templateVersion: CONTRACT_TEMPLATE_VERSION,
            ...content,
            contentHash: hash,
            signatures: emptySignatures(),
            disclosure: null,
            delivery: {},
            createdAt: now,
            updatedAt: now,
            completedAt: null,
          });
          transaction.create(contractRef.collection("events").doc(), {
            type: "draft_saved",
            at: now,
            actorRole: "trainer",
            contentHash: hash,
            payload: {created: true},
          });
          return {
            created: true,
            contractId,
            contractNo,
            version: 1,
            status: "draft",
            contentHash: hash,
          };
        }

        const existing = loadOwnedContract(uid, contractSnap);
        if (existing.memberId !== memberId) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "member_immutable",
          );
        }
        if (!isOpenStatus(existing.status)) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "contract_locked",
          );
        }
        if (existing.contentHash === hash) {
          return {created: false, unchanged: true, ...summary(contractId, existing)};
        }
        const previousStatus = existing.status as ContractStatus;
        const invalidated = previousStatus !== "draft";
        const now = FieldValue.serverTimestamp();
        transaction.update(contractRef, {
          ...content,
          templateVersion: CONTRACT_TEMPLATE_VERSION,
          contentHash: hash,
          status: "draft",
          ...(invalidated ?
            {signatures: emptySignatures(), disclosure: null} :
            {}),
          updatedAt: now,
        });
        if (invalidated) {
          transaction.create(contractRef.collection("events").doc(), {
            type: "signatures_invalidated",
            at: now,
            actorRole: "trainer",
            contentHash: hash,
            payload: {
              previousStatus,
              previousContentHash: existing.contentHash,
            },
          });
        }
        transaction.create(contractRef.collection("events").doc(), {
          type: "draft_saved",
          at: now,
          actorRole: "trainer",
          contentHash: hash,
          payload: {created: false},
        });
        return {
          created: false,
          unchanged: false,
          invalidatedSignatures: invalidated,
          ...summary(contractId, {...existing, status: "draft", contentHash: hash}),
        };
      });
    } catch (error) {
      return translated(error, "save_draft");
    }
  };
}

// ---- signPersonalContract ----
export function createSignPersonalContractHandler(db: Db) {
  return async (raw: unknown, ctx: Ctx) => {
    const uid = requireUid(ctx);
    const data = objectData(raw);
    allowOnly(data, [
      "contractId", "step", "contentHash", "checkedItems", "strokes",
    ]);
    const contractId = requireContractId(data);
    const step = data.step;
    if (!isSignStep(step)) {
      throw new functions.https.HttpsError("invalid-argument", "step_invalid");
    }
    const shownHash = requiredString(data, "contentHash", 64);
    try {
      const strokes = validateStrokes(data.strokes);
      const contractRef = db.collection(CONTRACTS).doc(contractId);
      const profileRef = db.collection("trainer_profiles").doc(uid);

      return await db.runTransaction(async (transaction) => {
        const [profileSnap, contractSnap] = await Promise.all([
          transaction.get(profileRef),
          transaction.get(contractRef),
        ]);
        requireProfile(uid, profileSnap, ctx);
        const contract = loadOwnedContract(uid, contractSnap);
        const signatures = (contract.signatures ?? {}) as Data;
        if (signatures[step] != null && contract.contentHash === shownHash) {
          return {alreadySigned: true, ...summary(contractId, contract)};
        }
        const transition = signTransition(step);
        if (contract.status !== transition.from) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "invalid_state",
          );
        }
        if (contract.contentHash !== shownHash) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "content_changed",
          );
        }
        const required = requiredCheckedItems(step, contract);
        const checkedItems = validateCheckedItems(
          data.checkedItems ?? [],
          required,
        );

        const memberId = String(contract.memberId);
        const memberRef = db.collection("members").doc(memberId);
        const isCompletion = step === "trainer";
        const supersedesId = contract.supersedesId == null ?
          null : String(contract.supersedesId);
        const [memberSnap, previousSnap] = isCompletion ?
          await Promise.all([
            transaction.get(memberRef),
            supersedesId == null ?
              Promise.resolve(null) :
              transaction.get(db.collection(CONTRACTS).doc(supersedesId)),
          ]) :
          [null, null];
        if (isCompletion && memberSnap != null) {
          requireOwnedMember(uid, memberId, memberSnap);
        }

        const now = FieldValue.serverTimestamp();
        const eventRef = contractRef.collection("events").doc();
        const actorRole = step === "trainer" ? "trainer" : "member";
        transaction.create(eventRef, {
          type: `${step}_signed`,
          at: now,
          actorRole,
          contentHash: shownHash,
          payload: {checkedItems, strokes},
        });
        const update: Data = {
          status: transition.to,
          [`signatures.${step}`]: {eventId: eventRef.id, signedAt: now},
          updatedAt: now,
        };
        if (step === "disclosure") {
          update.disclosure = {
            checkedItems,
            shownContentHash: shownHash,
            signedAt: now,
          };
        }
        if (isCompletion) {
          update.completedAt = now;
          transaction.create(contractRef.collection("events").doc(), {
            type: "completed",
            at: now,
            actorRole: "trainer",
            contentHash: shownHash,
            payload: {},
          });
          const previousRegistered =
            previousSnap?.exists === true &&
            previousSnap.data()?.trainerId === uid &&
            previousSnap.data()?.status === "completed" ?
              Number(
                (previousSnap.data()?.registration as Data | undefined)
                  ?.registered ?? 0,
              ) :
              0;
          const pointer = writeMemberPointer(
            transaction,
            memberRef,
            contractId,
            contract,
            now,
            memberSnap?.data() ?? {},
            previousRegistered,
          );
          update.registration = {
            ...pointer.registration,
            registeredAt: now,
            ...(pointer.membershipBefore == null ? {} : {
              membershipBefore: pointer.membershipBefore,
              reactivated: pointer.reactivated,
            }),
          };
          if (pointer.reactivated && profileSnap.exists) {
            // 만료였던 회원이 다시 활동 중이 되었으니 관리 회원 수를 하나 올린다.
            transaction.update(profileRef, {
              managedMemberCount: FieldValue.increment(1),
              usageUpdatedAt: now,
              updatedAt: now,
            });
          }
          if (supersedesId != null && previousSnap?.exists === true &&
              previousSnap.data()?.trainerId === uid &&
              previousSnap.data()?.status === "completed") {
            transaction.update(previousSnap.ref, {
              status: "superseded",
              supersededById: contractId,
              updatedAt: now,
            });
            transaction.create(previousSnap.ref.collection("events").doc(), {
              type: "superseded",
              at: now,
              actorRole: "trainer",
              contentHash: String(previousSnap.data()?.contentHash ?? ""),
              payload: {supersededById: contractId},
            });
          }
        }
        transaction.update(contractRef, update);
        return {
          alreadySigned: false,
          ...summary(contractId, {...contract, status: transition.to}),
        };
      });
    } catch (error) {
      return translated(error, "sign");
    }
  };
}

function requiredCheckedItems(step: SignStep, contract: Data): string[] {
  if (step === "disclosure") {
    return requiredDisclosureItems(contentOf(contract));
  }
  if (step === "member") return MEMBER_AGREEMENT_ITEMS;
  return [];
}

function writeMemberPointer(
  transaction: FirebaseFirestore.Transaction,
  memberRef: FirebaseFirestore.DocumentReference,
  contractId: string,
  contract: Data,
  now: FirebaseFirestore.FieldValue,
  memberData: Data,
  previousRegistered: number,
): {
  registration: RegistrationResult["registration"];
  membershipBefore: Data | null;
  reactivated: boolean;
} {
  const product = contract.product as Data;
  const version = Number(contract.version ?? 1);
  const contractNo = displayContractNo(String(contract.contractNo), version);
  const update: Data = {};
  update.contractId = contractId;
  update.contractNo = contractNo;
  update.contractStatus = "completed";
  update.contractSigned = true;
  update.contractSignedAt = now;
  update["lessonSync.contractId"] = contractId;
  update["lessonSync.contractNo"] = contractNo;
  update.lastContractSummary = {
    contractId,
    contractNo,
    productName: product.name,
    sessionCount: product.sessionCount,
    totalPrice: product.paidAmount,
    contractDate: product.periodStart,
    endDate: product.periodEnd,
    finalSigned: true,
  };
  // 계약 횟수를 회원의 총·잔여 횟수에 합산한다(재계약은 더하고, 새 버전은 차이만 반영).
  const registration = buildRegistration(
    memberData,
    {
      name: String(product.name ?? ""),
      sessionCount: Number(product.sessionCount ?? 0),
    },
    previousRegistered,
    {contractId, contractNo},
  );
  Object.assign(update, registration.memberUpdate);
  // 회원권 기간을 계약의 사용 기간으로 맞추고, 만료였던 회원은 새 기간으로 다시 시작한다.
  const period = buildMembershipPeriodSync(memberData, product);
  if (period != null) Object.assign(update, period.update);
  update.updatedAt = now;
  transaction.update(memberRef, update);
  return {
    registration: registration.registration,
    membershipBefore: period?.before ?? null,
    reactivated: period?.reactivated ?? false,
  };
}

// ---- managePersonalContract ----
export function createManagePersonalContractHandler(db: Db) {
  return async (raw: unknown, ctx: Ctx) => {
    const uid = requireUid(ctx);
    const data = objectData(raw);
    allowOnly(data, [
      "contractId", "action", "reason", "idempotencyKey", "channel",
    ]);
    const contractId = requireContractId(data);
    const action = data.action;
    if (action !== "cancel" && action !== "new_version" &&
        action !== "mark_shared") {
      throw new functions.https.HttpsError("invalid-argument", "action_invalid");
    }
    try {
      const contractRef = db.collection(CONTRACTS).doc(contractId);
      const profileRef = db.collection("trainer_profiles").doc(uid);

      if (action === "mark_shared") {
        // 강사가 열람 링크를 회원에게 보냈다는 사실을 남긴다(링크가 발급된 완료 계약만).
        const channel = data.channel;
        if (channel !== "share_sheet" && channel !== "copy_link") {
          throw new functions.https.HttpsError(
            "invalid-argument",
            "channel_invalid",
          );
        }
        return await db.runTransaction(async (transaction) => {
          const [profileSnap, contractSnap] = await Promise.all([
            transaction.get(profileRef),
            transaction.get(contractRef),
          ]);
          requireProfile(uid, profileSnap, ctx);
          const contract = loadOwnedContract(uid, contractSnap);
          const delivery = (contract.delivery ?? {}) as Data;
          if (contract.status !== "completed" || !delivery.linkTokenHash) {
            throw new functions.https.HttpsError(
              "failed-precondition",
              "link_not_issued",
            );
          }
          const now = FieldValue.serverTimestamp();
          transaction.update(contractRef, {
            delivery: {
              ...delivery,
              sharedAt: now,
              shareCount: Number(delivery.shareCount ?? 0) + 1,
            },
            updatedAt: now,
          });
          transaction.create(contractRef.collection("events").doc(), {
            type: "shared",
            at: now,
            actorRole: "trainer",
            contentHash: String(contract.contentHash ?? ""),
            payload: {channel},
          });
          return {
            shared: true,
            shareCount: Number(delivery.shareCount ?? 0) + 1,
            ...summary(contractId, contract),
          };
        });
      }

      if (action === "cancel") {
        const reason = requiredString(data, "reason", 200);
        if (reason.length < 2) {
          throw new functions.https.HttpsError(
            "invalid-argument",
            "reason_required",
          );
        }
        return await db.runTransaction(async (transaction) => {
          const [profileSnap, contractSnap] = await Promise.all([
            transaction.get(profileRef),
            transaction.get(contractRef),
          ]);
          requireProfile(uid, profileSnap, ctx);
          const contract = loadOwnedContract(uid, contractSnap);
          if (contract.status === "cancelled") {
            return {alreadyCancelled: true, ...summary(contractId, contract)};
          }
          if (!isOpenStatus(contract.status)) {
            throw new functions.https.HttpsError(
              "failed-precondition",
              "contract_locked",
            );
          }
          const now = FieldValue.serverTimestamp();
          transaction.update(contractRef, {
            status: "cancelled",
            cancelledAt: now,
            cancelReason: reason,
            updatedAt: now,
          });
          transaction.create(contractRef.collection("events").doc(), {
            type: "cancelled",
            at: now,
            actorRole: "trainer",
            contentHash: String(contract.contentHash ?? ""),
            payload: {reason, previousStatus: contract.status},
          });
          return {
            alreadyCancelled: false,
            ...summary(contractId, {...contract, status: "cancelled"}),
          };
        });
      }

      const idempotencyKey = requiredString(data, "idempotencyKey");
      const newId = digestId(
        "pc",
        `${uid}:new_version:${contractId}:${idempotencyKey}`,
      );
      const newRef = db.collection(CONTRACTS).doc(newId);
      const openVersionsQuery = db.collection(CONTRACTS)
        .where("trainerId", "==", uid)
        .where("supersedesId", "==", contractId);
      return await db.runTransaction(async (transaction) => {
        const [profileSnap, contractSnap, newSnap, versionsSnap] =
          await Promise.all([
            transaction.get(profileRef),
            transaction.get(contractRef),
            transaction.get(newRef),
            transaction.get(openVersionsQuery),
          ]);
        requireProfile(uid, profileSnap, ctx);
        const contract = loadOwnedContract(uid, contractSnap);
        if (newSnap.exists) {
          return {created: false, ...summary(newId, newSnap.data() ?? {})};
        }
        if (contract.status !== "completed") {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "new_version_requires_completed",
          );
        }
        if (versionsSnap.docs.some((doc) => isOpenStatus(doc.data().status))) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "new_version_already_open",
          );
        }
        const memberId = String(contract.memberId);
        const memberSnap = await transaction.get(
          db.collection("members").doc(memberId),
        );
        requireOwnedMember(uid, memberId, memberSnap);

        const content = contentOf(contract);
        const hash = contentHash(content);
        const version = Number(contract.version ?? 1) + 1;
        const now = FieldValue.serverTimestamp();
        transaction.create(newRef, {
          trainerId: uid,
          workspaceType: "personal",
          memberId,
          contractNo: contract.contractNo,
          version,
          supersedesId: contractId,
          supersededById: null,
          status: "draft",
          templateVersion: CONTRACT_TEMPLATE_VERSION,
          ...content,
          contentHash: hash,
          signatures: emptySignatures(),
          disclosure: null,
          delivery: {},
          createdAt: now,
          updatedAt: now,
          completedAt: null,
        });
        transaction.create(newRef.collection("events").doc(), {
          type: "draft_saved",
          at: now,
          actorRole: "trainer",
          contentHash: hash,
          payload: {created: true, supersedesId: contractId},
        });
        return {
          created: true,
          ...summary(newId, {
            contractNo: contract.contractNo,
            version,
            status: "draft",
            contentHash: hash,
          }),
        };
      });
    } catch (error) {
      return translated(error, `manage_${String(action)}`);
    }
  };
}

// ---- savePersonalContractSettings ----
// 당사자 정보(contractParty)와 내 기본 조건(contractDefaults)을 프로필에 저장한다.
// 새 계약의 입력 기본값일 뿐이고, 계약에는 시작 시점의 값이 스냅샷으로 복사된다.
export function createSavePersonalContractSettingsHandler(db: Db) {
  return async (raw: unknown, ctx: Ctx) => {
    const uid = requireUid(ctx);
    const data = objectData(raw);
    allowOnly(data, [
      "contractParty", "contractDefaults", "contractProducts", "centerLogoPath",
    ]);
    if (data.contractParty == null && data.contractDefaults == null &&
        data.contractProducts == null && data.centerLogoPath === undefined) {
      throw new functions.https.HttpsError("invalid-argument", "no_updates");
    }
    try {
      const updates: Data = {};
      if (data.contractParty != null) {
        updates.contractParty = normalizeParty(data.contractParty, uid);
      }
      if (data.contractDefaults != null) {
        updates.contractDefaults = normalizeContractDefaults(
          data.contractDefaults,
        );
      }
      if (data.centerLogoPath !== undefined) {
        updates.centerLogoPath = normalizeCenterLogoPath(
          data.centerLogoPath,
          uid,
        );
      }
      if (data.contractProducts != null) {
        updates.contractProducts = normalizeProductPresets(data.contractProducts);
      }
      const profileRef = db.collection("trainer_profiles").doc(uid);
      return await db.runTransaction(async (transaction) => {
        const profileSnap = await transaction.get(profileRef);
        requireProfile(uid, profileSnap, ctx);
        transaction.update(profileRef, {
          ...updates,
          contractSettingsUpdatedAt: FieldValue.serverTimestamp(),
        });
        return {saved: Object.keys(updates).sort()};
      });
    } catch (error) {
      return translated(error, "save_settings");
    }
  };
}
