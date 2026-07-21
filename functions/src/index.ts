/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

// functions/src/index.ts
import * as functions from "firebase-functions/v1";
import * as admin from "firebase-admin";
import {
  createBootstrapAnonymousBeginnerProfileHandler,
  createBootstrapTrainerProfileHandler,
  createCompleteInitialPasswordChangeHandler,
  createCompleteNicknameOnboardingHandler,
  createClaimTierCelebrationHandler,
  createClaimFirstLessonGuideHandler,
  createReconcilePersonalTierHandler,
  createTransitionAnonymousProfileToLinkedHandler,
  createUpdatePersonalTrainerProfileHandler,
} from "./profile_bootstrap.js";
import {
  createManagedMemberHandler,
  transitionManagedMemberStateHandler,
  updateManagedMemberHandler,
} from "./managed_members.js";
import {
  cancelPersonalTrainingLogHandler,
  finalizePersonalTrainingLogHandler,
} from "./personal_training_logs.js";
admin.initializeApp();

const db = admin.firestore();
const personalFunctions = functions
  .region("asia-northeast3")
  .runWith({maxInstances: 10});

exports.bootstrapAnonymousBeginnerProfile = personalFunctions.https.onCall(
  createBootstrapAnonymousBeginnerProfileHandler(db),
);
exports.bootstrapTrainerProfile = personalFunctions.https.onCall(
  createBootstrapTrainerProfileHandler(db),
);
exports.transitionAnonymousProfileToLinked = personalFunctions.https.onCall(
  createTransitionAnonymousProfileToLinkedHandler(db),
);
exports.updatePersonalTrainerProfile = personalFunctions.https.onCall(
  createUpdatePersonalTrainerProfileHandler(db),
);
exports.completeNicknameOnboarding = personalFunctions.https.onCall(
  createCompleteNicknameOnboardingHandler(db),
);
exports.reconcilePersonalTier = personalFunctions.https.onCall(
  createReconcilePersonalTierHandler(db),
);
exports.claimTierCelebration = personalFunctions.https.onCall(
  createClaimTierCelebrationHandler(db),
);
exports.claimFirstLessonGuide = personalFunctions.https.onCall(
  createClaimFirstLessonGuideHandler(db),
);
exports.completeInitialPasswordChange = functions.https.onCall(
  createCompleteInitialPasswordChangeHandler(db),
);
exports.createManagedMember = personalFunctions.https.onCall(
  createManagedMemberHandler(db),
);
exports.transitionManagedMemberState = personalFunctions.https.onCall(
  transitionManagedMemberStateHandler(db),
);
exports.updateManagedMember = personalFunctions.https.onCall(
  updateManagedMemberHandler(db),
);
exports.finalizePersonalTrainingLog = personalFunctions.https.onCall(
  finalizePersonalTrainingLogHandler(db),
);
exports.cancelPersonalTrainingLog = personalFunctions.https.onCall(
  cancelPersonalTrainingLogHandler(db),
);

function isStaff(ctx: functions.https.CallableContext) {
  const role = ctx.auth?.token?.role;
  return role === "admin" || role === "staff" || role === "manager";
}

type SessionData = {
  notRegistered?: boolean;
  total?: number;
  remain?: number;
};

type ConsentSignature = {
  type?: unknown;
  value?: unknown;
};

type ConsentData = Record<string, unknown> & {
  checks?: {
    risk?: unknown;
    privacy?: unknown;
    policy?: unknown;
  };
  trainer?: ConsentSignature;
  customer?: ConsentSignature;
};

exports.chargeOnce = functions.https.onCall(async (data, ctx) => {
  if (!ctx.auth) {
    throw new functions.https.HttpsError("unauthenticated", "auth required");
  }
  const uid = ctx.auth.uid;
  const {memberId, rowKey, reason} = data as {
    memberId: string;
    rowKey: string;
    reason: "lesson" | "noshow_deduct";
  };
  if (!memberId || !rowKey) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "memberId/rowKey required",
    );
  }

  const eventRef = db.doc(`members/${memberId}/events/${rowKey}`);
  const memRef = db.doc(`members/${memberId}`);

  await db.runTransaction(async (tx) => {
    const ev = await tx.get(eventRef);
    if (ev.exists) return; // idempotent

    const mem = await tx.get(memRef);
    if (!mem.exists) {
      throw new functions.https.HttpsError("not-found", "member not found");
    }

    const sessions = (mem.get("sessions") || {}) as SessionData;
    if (sessions.notRegistered === true) return;

    const total = sessions.total || 0;
    let remain = sessions.remain || 0;
    remain = Math.max(0, Math.min(total, remain - 1));
    const done = total - remain;

    tx.set(eventRef, {
      type: "charge",
      reason,
      byUid: uid,
      at: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(memRef, {
      sessions: {notRegistered: !!sessions.notRegistered, total, remain, done},
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  });

  return {ok: true};
});

exports.cancelNoShow = functions.https.onCall(async (data, ctx) => {
  if (!ctx.auth || !isStaff(ctx)) {
    throw new functions.https.HttpsError("permission-denied", "staff only");
  }
  const {memberId, rowKey} = data as { memberId: string, rowKey: string };
  if (!memberId || !rowKey) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "memberId/rowKey required",
    );
  }

  const eventRef = db.doc(`members/${memberId}/events/${rowKey}`);
  // 단순 이벤트 마킹(실제 세션 롤백은 정책상 미수행, 필요 시 롤백 트랜잭션 추가)
  await eventRef.set({
    canceled: true,
    canceledBy: ctx.auth.uid,
    canceledAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  return {ok: true};
});

exports.lockConsent = functions.https.onCall(async (data, ctx) => {
  if (!ctx.auth) {
    throw new functions.https.HttpsError("unauthenticated", "auth required");
  }
  const {memberId, consent} = data as {
    memberId: string;
    consent: ConsentData;
  };
  if (!memberId || !consent) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "memberId/consent required",
    );
  }

  const memRef = db.doc(`members/${memberId}`);
  await db.runTransaction(async (tx) => {
    const mem = await tx.get(memRef);
    if (!mem.exists) {
      throw new functions.https.HttpsError("not-found", "member not found");
    }

    const checks = consent.checks || {};
    const trainer = consent.trainer || {};
    const customer = consent.customer || {};
    if (!(checks.risk && checks.privacy && checks.policy)) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "missing required consents",
      );
    }
    if (!(trainer.type && trainer.value && customer.type && customer.value)) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "missing signatures",
      );
    }

    tx.set(memRef, {
      consent: {
        ...consent,
        locked: true,
        lockedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  });

  return {ok: true};
});

exports.unlockConsent = functions.https.onCall(async (data, ctx) => {
  if (!ctx.auth || !isStaff(ctx)) {
    throw new functions.https.HttpsError("permission-denied", "staff only");
  }
  const {memberId} = data as { memberId: string };
  if (!memberId) {
    throw new functions.https.HttpsError("invalid-argument", "memberId required");
  }

  const memRef = db.doc(`members/${memberId}`);
  await memRef.set({
    consent: {
      locked: false,
      unlockedAt: admin.firestore.FieldValue.serverTimestamp(),
      unlockedBy: ctx.auth.uid,
    },
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  return {ok: true};
});
