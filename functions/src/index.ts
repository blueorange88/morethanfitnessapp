/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import {setGlobalOptions} from "firebase-functions";
import {onRequest} from "firebase-functions/https";
import * as logger from "firebase-functions/logger";

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });
// functions/src/index.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
admin.initializeApp();

const db = admin.firestore();

function isStaff(ctx: functions.https.CallableContext) {
  const role = ctx.auth?.token?.role;
  return role === 'admin' || role === 'staff' || role === 'manager';
}

exports.chargeOnce = functions.https.onCall(async (data, ctx) => {
  if (!ctx.auth) throw new functions.https.HttpsError('unauthenticated', 'auth required');
  const { memberId, rowKey, reason } = data as { memberId: string, rowKey: string, reason: 'lesson'|'noshow_deduct' };
  if (!memberId || !rowKey) throw new functions.https.HttpsError('invalid-argument', 'memberId/rowKey required');

  const eventRef = db.doc(`members/${memberId}/events/${rowKey}`);
  const memRef   = db.doc(`members/${memberId}`);

  await db.runTransaction(async tx => {
    const ev = await tx.get(eventRef);
    if (ev.exists) return; // idempotent

    const mem = await tx.get(memRef);
    if (!mem.exists) throw new functions.https.HttpsError('not-found','member not found');

    const sessions = (mem.get('sessions') || {}) as any;
    if (sessions.notRegistered === true) return;

    const total = sessions.total || 0;
    let remain  = sessions.remain || 0;
    remain = Math.max(0, Math.min(total, remain - 1));
    const done  = total - remain;

    tx.set(eventRef, {
      type: 'charge',
      reason,
      byUid: ctx.auth!.uid,
      at: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(memRef, {
      sessions: { notRegistered: !!sessions.notRegistered, total, remain, done },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  return { ok: true };
});

exports.cancelNoShow = functions.https.onCall(async (data, ctx) => {
  if (!ctx.auth || !isStaff(ctx)) throw new functions.https.HttpsError('permission-denied','staff only');
  const { memberId, rowKey } = data as { memberId: string, rowKey: string };
  if (!memberId || !rowKey) throw new functions.https.HttpsError('invalid-argument','memberId/rowKey required');

  const eventRef = db.doc(`members/${memberId}/events/${rowKey}`);
  // 단순 이벤트 마킹(실제 세션 롤백은 정책상 미수행, 필요 시 롤백 트랜잭션 추가)
  await eventRef.set({
    canceled: true,
    canceledBy: ctx.auth.uid,
    canceledAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return { ok: true };
});

exports.lockConsent = functions.https.onCall(async (data, ctx) => {
  if (!ctx.auth) throw new functions.https.HttpsError('unauthenticated','auth required');
  const { memberId, consent } = data as { memberId: string, consent: any };
  if (!memberId || !consent) throw new functions.https.HttpsError('invalid-argument','memberId/consent required');

  const memRef = db.doc(`members/${memberId}`);
  await db.runTransaction(async tx => {
    const mem = await tx.get(memRef);
    if (!mem.exists) throw new functions.https.HttpsError('not-found','member not found');

    const checks = consent.checks || {};
    const trainer = consent.trainer || {};
    const customer = consent.customer || {};
    if (!(checks.risk && checks.privacy && checks.policy)) throw new functions.https.HttpsError('failed-precondition','missing required consents');
    if (!(trainer.type && trainer.value && customer.type && customer.value)) throw new functions.https.HttpsError('failed-precondition','missing signatures');

    tx.set(memRef, {
      consent: {
        ...consent,
        locked: true,
        lockedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  return { ok: true };
});

exports.unlockConsent = functions.https.onCall(async (data, ctx) => {
  if (!ctx.auth || !isStaff(ctx)) throw new functions.https.HttpsError('permission-denied','staff only');
  const { memberId } = data as { memberId: string };
  if (!memberId) throw new functions.https.HttpsError('invalid-argument','memberId required');

  const memRef = db.doc(`members/${memberId}`);
  await memRef.set({
    consent: { locked: false, unlockedAt: admin.firestore.FieldValue.serverTimestamp(), unlockedBy: ctx.auth.uid },
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return { ok: true };
});
// lib/core/functions_api.dart
import 'package:cloud_functions/cloud_functions.dart';

class FunctionsApi {
  final _fn = FirebaseFunctions.instance;

  Future<void> chargeOnce({
    required String memberId,
    required String rowKey,      // ex) '2025-10-25_7'
    required String reason,      // 'lesson' | 'noshow_deduct'
  }) async {
    await _fn.httpsCallable('chargeOnce').call({
      'memberId': memberId,
      'rowKey'  : rowKey,
      'reason'  : reason,
    });
  }

  Future<void> cancelNoShow({
    required String memberId,
    required String rowKey,
  }) async {
    await _fn.httpsCallable('cancelNoShow').call({
      'memberId': memberId,
      'rowKey'  : rowKey,
    });
  }

  Future<void> lockConsent({
    required String memberId,
    required Map<String, dynamic> consent, // 전체 동의서 스냅샷
  }) async {
    await _fn.httpsCallable('lockConsent').call({
      'memberId': memberId,
      'consent' : consent,
    });
  }

  Future<void> unlockConsent({
    required String memberId,
  }) async {
    await _fn.httpsCallable('unlockConsent').call({
      'memberId': memberId,
    });
  }
}

// functions/src/index.ts
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
admin.initializeApp();

const db = admin.firestore();

function isStaff(ctx: functions.https.CallableContext) {
  const role = ctx.auth?.token?.role;
  return role === 'admin' || role === 'staff' || role === 'manager';
}

exports.chargeOnce = functions.https.onCall(async (data, ctx) => {
  if (!ctx.auth) throw new functions.https.HttpsError('unauthenticated', 'auth required');
  const { memberId, rowKey, reason } = data as { memberId: string, rowKey: string, reason: 'lesson'|'noshow_deduct' };
  if (!memberId || !rowKey) throw new functions.https.HttpsError('invalid-argument', 'memberId/rowKey required');

  const eventRef = db.doc(`members/${memberId}/events/${rowKey}`);
  const memRef   = db.doc(`members/${memberId}`);

  await db.runTransaction(async tx => {
    const ev = await tx.get(eventRef);
    if (ev.exists) return; // idempotent

    const mem = await tx.get(memRef);
    if (!mem.exists) throw new functions.https.HttpsError('not-found','member not found');

    const sessions = (mem.get('sessions') || {}) as any;
    if (sessions.notRegistered === true) return;

    const total = sessions.total || 0;
    let remain  = sessions.remain || 0;
    remain = Math.max(0, Math.min(total, remain - 1));
    const done  = total - remain;

    tx.set(eventRef, {
      type: 'charge',
      reason,
      byUid: ctx.auth!.uid,
      at: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.set(memRef, {
      sessions: { notRegistered: !!sessions.notRegistered, total, remain, done },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  return { ok: true };
});

exports.cancelNoShow = functions.https.onCall(async (data, ctx) => {
  if (!ctx.auth || !isStaff(ctx)) throw new functions.https.HttpsError('permission-denied','staff only');
  const { memberId, rowKey } = data as { memberId: string, rowKey: string };
  if (!memberId || !rowKey) throw new functions.https.HttpsError('invalid-argument','memberId/rowKey required');

  const eventRef = db.doc(`members/${memberId}/events/${rowKey}`);
  // 단순 이벤트 마킹(실제 세션 롤백은 정책상 미수행, 필요 시 롤백 트랜잭션 추가)
  await eventRef.set({
    canceled: true,
    canceledBy: ctx.auth.uid,
    canceledAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return { ok: true };
});

exports.lockConsent = functions.https.onCall(async (data, ctx) => {
  if (!ctx.auth) throw new functions.https.HttpsError('unauthenticated','auth required');
  const { memberId, consent } = data as { memberId: string, consent: any };
  if (!memberId || !consent) throw new functions.https.HttpsError('invalid-argument','memberId/consent required');

  const memRef = db.doc(`members/${memberId}`);
  await db.runTransaction(async tx => {
    const mem = await tx.get(memRef);
    if (!mem.exists) throw new functions.https.HttpsError('not-found','member not found');

    const checks = consent.checks || {};
    const trainer = consent.trainer || {};
    const customer = consent.customer || {};
    if (!(checks.risk && checks.privacy && checks.policy)) throw new functions.https.HttpsError('failed-precondition','missing required consents');
    if (!(trainer.type && trainer.value && customer.type && customer.value)) throw new functions.https.HttpsError('failed-precondition','missing signatures');

    tx.set(memRef, {
      consent: {
        ...consent,
        locked: true,
        lockedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  return { ok: true };
});

exports.unlockConsent = functions.https.onCall(async (data, ctx) => {
  if (!ctx.auth || !isStaff(ctx)) throw new functions.https.HttpsError('permission-denied','staff only');
  const { memberId } = data as { memberId: string };
  if (!memberId) throw new functions.https.HttpsError('invalid-argument','memberId required');

  const memRef = db.doc(`members/${memberId}`);
  await memRef.set({
    consent: { locked: false, unlockedAt: admin.firestore.FieldValue.serverTimestamp(), unlockedBy: ctx.auth.uid },
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return { ok: true };
});
