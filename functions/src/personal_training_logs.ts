import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";

import {
  LESSON_PROGRESS_NOTICES,
  buildLessonProgressNotice,
} from "./lesson_progress_notice.js";

const FINAL_STATUSES = [
  "completed",
  "no_show_deducted",
  "no_show_not_deducted",
  "service",
] as const;

type FinalStatus = typeof FINAL_STATUSES[number];
type Data = Record<string, unknown>;

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

function requiredString(data: Data, key: string): string {
  const value = data[key];
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new functions.https.HttpsError("invalid-argument", `${key}_required`);
  }
  return value.trim();
}

function finalStatus(data: Data): FinalStatus {
  const status = requiredString(data, "status");
  if (!FINAL_STATUSES.includes(status as FinalStatus)) {
    throw new functions.https.HttpsError("invalid-argument", "invalid_status");
  }
  return status as FinalStatus;
}

function mapData(value: unknown): Data {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    return {};
  }
  return {...value as Data};
}

function integer(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  const parsed = Number.parseInt(String(value ?? ""), 10);
  return Number.isFinite(parsed) ? parsed : 0;
}

function isPersonalOwner(data: Data, uid: string): boolean {
  return data.trainerId === uid && data.workspaceType === "personal";
}

function statusCountKey(status: FinalStatus): string {
  switch (status) {
  case "no_show_deducted":
    return "noShowDeductedCount";
  case "no_show_not_deducted":
    return "noShowUndeductedCount";
  case "service":
    return "serviceSessionCount";
  case "completed":
    return "completedCount";
  }
}

function shouldDeduct(status: FinalStatus): boolean {
  return status === "completed" || status === "no_show_deducted";
}

// 빠른 서명(손글씨) 한 건. 점 개수는 문서 크기(1MiB) 안에 두 서명이 들어가도록 제한한다.
const MAX_SIGNATURE_POINTS = 8000;
const MIN_SIGNATURE_POINTS = 2;

type SignaturePoint = {x: number; y: number} | null;
type SignatureInput = {
  points: SignaturePoint[];
  signedAt: Timestamp;
  signedBy: string;
};
type QuickSignInput = {
  trainer: SignatureInput;
  member: SignatureInput | null;
};

function parseSignature(value: unknown, field: string): SignatureInput {
  if (value == null || typeof value !== "object" || Array.isArray(value)) {
    throw new functions.https.HttpsError("invalid-argument", `${field}_invalid`);
  }
  const raw = value as Data;
  const rawPoints = raw.points;
  if (!Array.isArray(rawPoints) || rawPoints.length > MAX_SIGNATURE_POINTS) {
    throw new functions.https.HttpsError("invalid-argument", `${field}_invalid`);
  }
  const points: SignaturePoint[] = [];
  let drawn = 0;
  for (const item of rawPoints) {
    if (item == null) {
      points.push(null);
      continue;
    }
    const point = item as Data;
    if (typeof item !== "object" || Array.isArray(item) ||
        typeof point.x !== "number" || !Number.isFinite(point.x) ||
        typeof point.y !== "number" || !Number.isFinite(point.y)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        `${field}_invalid`,
      );
    }
    points.push({x: point.x, y: point.y});
    drawn += 1;
  }
  if (drawn < MIN_SIGNATURE_POINTS) {
    throw new functions.https.HttpsError("invalid-argument", `${field}_empty`);
  }
  const signedAtMs = raw.signedAt;
  const signedAt = typeof signedAtMs === "number" &&
      Number.isFinite(signedAtMs) && signedAtMs > 0 ?
    Timestamp.fromMillis(Math.trunc(signedAtMs)) : Timestamp.now();
  return {
    points,
    signedAt,
    signedBy: raw.signedBy === "member_web" ? "member_web" : "member_app",
  };
}

// 앱이 손글씨 서명을 같이 보낸 경우에만 값이 있다(없으면 기존 확정과 동일).
function parseQuickSign(
  raw: unknown,
  status: FinalStatus,
): QuickSignInput | null {
  if (raw == null) return null;
  const data = objectData(raw);
  const trainer = parseSignature(data.trainerSignature, "trainer_signature");
  const needsMember = status === "completed" || status === "service";
  if (needsMember && data.memberSignature == null) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "member_signature_required",
    );
  }
  const member = needsMember ?
    parseSignature(data.memberSignature, "member_signature") : null;
  return {trainer, member};
}

function quickSignLogFields(
  quickSign: QuickSignInput,
  member: Data,
  now: Timestamp,
): Data {
  const lessonSync = mapData(member.lessonSync);
  const contractId = String(lessonSync.contractId ?? "").trim();
  const contractLinked = member.contractSigned === true ||
    contractId.length > 0;
  const memberSig = quickSign.member;
  return {
    inputMethod: "quick_sign",
    isQuickSignLog: true,
    quickSignedOnly: true,
    basis: contractLinked ? "contract" : "manual",
    contractLinked,
    ...(contractId.length > 0 ? {contractId} : {}),
    ...(contractLinked ? {
      cancelLockedByContract: true,
      cancelLockContractReason: "contract_linked_lesson_confirm",
    } : {}),
    trainerSignature: {
      type: "drawing",
      points: quickSign.trainer.points,
      signedAt: quickSign.trainer.signedAt,
    },
    memberSignature: memberSig == null ? null : {
      type: "drawing",
      points: memberSig.points,
      signedAt: memberSig.signedAt,
      signedBy: memberSig.signedBy,
    },
    trainerSig: "[drawing]",
    trainerSigned: true,
    memberSigned: memberSig != null,
    ...(memberSig == null ? {} : {
      memberSig: "[drawing]",
      customerSig: "[drawing]",
      memberSignedAt: memberSig.signedAt,
      cancelLockedByMemberSignature: true,
      cancelLockReason: "member_signed_lesson_confirm",
    }),
    waitingTrainerConfirm: false,
    confirmedByTrainer: true,
    confirmedAt: now,
    lockedAt: now,
    signedAt: now,
  };
}

function quickSignScheduleFields(
  quickSign: QuickSignInput,
  member: Data,
  lessonLogId: string,
  now: Timestamp,
): Data {
  const lessonSync = mapData(member.lessonSync);
  const contractId = String(lessonSync.contractId ?? "").trim();
  const contractLinked = member.contractSigned === true ||
    contractId.length > 0;
  const memberSig = quickSign.member;
  return {
    quickTrainingLogId: lessonLogId,
    lastTrainingLogId: lessonLogId,
    lastSignedAt: now,
    basis: contractLinked ? "contract" : "manual",
    contractLinked,
    ...(contractId.length > 0 ? {contractId} : {}),
    ...(contractLinked ? {
      cancelLockedByContract: true,
      cancelLockContractReason: "contract_linked_lesson_confirm",
    } : {}),
    ...(memberSig == null ? {} : {
      memberSigned: true,
      memberSignedAt: memberSig.signedAt,
      cancelLockedByMemberSignature: true,
      cancelLockReason: "member_signed_lesson_confirm",
    }),
  };
}

function translated(error: unknown, operation: string): never {
  if (error instanceof functions.https.HttpsError) throw error;
  console.error(`[MTF_PERSONAL_LOG] ${operation} failed`, error);
  throw new functions.https.HttpsError("internal", "personal_log_failed");
}

function validateMember(
  snapshot: FirebaseFirestore.DocumentSnapshot,
  memberId: string,
  uid: string,
): Data {
  if (!snapshot.exists) {
    throw new functions.https.HttpsError("not-found", "member_not_found");
  }
  const member = snapshot.data() ?? {};
  if (!isPersonalOwner(member, uid) || member.memberId !== memberId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "member_owner_mismatch",
    );
  }
  if (member.managementState === "deleted") {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "member_deleted",
    );
  }
  return member;
}

function validateSchedule(
  snapshot: FirebaseFirestore.DocumentSnapshot,
  scheduleId: string,
  memberId: string,
  uid: string,
): Data {
  if (!snapshot.exists) {
    throw new functions.https.HttpsError("not-found", "schedule_not_found");
  }
  const schedule = snapshot.data() ?? {};
  if (!isPersonalOwner(schedule, uid) || schedule.scheduleId !== scheduleId) {
    throw new functions.https.HttpsError(
      "permission-denied",
      "schedule_owner_mismatch",
    );
  }
  const linkedMemberId = String(schedule.memberId ?? "").trim();
  if (linkedMemberId !== memberId) {
    throw new functions.https.HttpsError(
      "failed-precondition",
      "schedule_member_mismatch",
    );
  }
  return schedule;
}

export function finalizePersonalTrainingLogHandler(
  db: FirebaseFirestore.Firestore,
) {
  return async (raw: unknown, ctx: functions.https.CallableContext) => {
    const uid = requireUid(ctx);
    const data = objectData(raw);
    const lessonLogId = requiredString(data, "lessonLogId");
    const requestedStatus = finalStatus(data);
    const quickSign = parseQuickSign(data.quickSign, requestedStatus);
    const logRef = db.collection("training_logs").doc(lessonLogId);

    try {
      return await db.runTransaction(async (transaction) => {
        const logSnapshot = await transaction.get(logRef);
        if (!logSnapshot.exists) {
          throw new functions.https.HttpsError("not-found", "log_not_found");
        }
        const log = logSnapshot.data() ?? {};
        if (!isPersonalOwner(log, uid) || log.lessonLogId !== lessonLogId) {
          throw new functions.https.HttpsError(
            "permission-denied",
            "log_owner_mismatch",
          );
        }

        const currentStatus = String(log.status ?? "").trim();
        if (FINAL_STATUSES.includes(currentStatus as FinalStatus)) {
          if (currentStatus !== requestedStatus) {
            throw new functions.https.HttpsError(
              "failed-precondition",
              "already_finalized_different_status",
            );
          }
          return {
            lessonLogId,
            status: currentStatus,
            alreadyFinalized: true,
            deductionApplied: log.deductionApplied === true,
          };
        }
        if (currentStatus !== "draft") {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "log_not_finalizable",
          );
        }

        const memberId = String(log.memberId ?? "").trim();
        if (memberId.length === 0) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "member_required",
          );
        }
        const memberRef = db.collection("members").doc(memberId);
        const memberSnapshot = await transaction.get(memberRef);
        const member = validateMember(memberSnapshot, memberId, uid);

        const scheduleId = String(log.scheduleDocId ?? "").trim();
        let scheduleRef: FirebaseFirestore.DocumentReference | null = null;
        let schedule: Data = {};
        if (scheduleId.length > 0) {
          scheduleRef = db.collection("schedules").doc(scheduleId);
          const scheduleSnapshot = await transaction.get(scheduleRef);
          schedule = validateSchedule(
            scheduleSnapshot,
            scheduleId,
            memberId,
            uid,
          );
          const confirmedLogId = String(schedule.trainingLogId ?? "").trim();
          if ((schedule.lessonConfirmed === true || confirmedLogId.length > 0) &&
              confirmedLogId !== lessonLogId) {
            throw new functions.https.HttpsError(
              "failed-precondition",
              "schedule_already_finalized",
            );
          }
        }

        const sessions = mapData(member.sessions);
        const stats = mapData(member.lessonStats);
        const remainingBefore = integer(
          member.remainingSessions ?? member.remainSessions ?? sessions.remain,
        );
        const doneBefore = integer(member.doneSessions ?? sessions.done);
        const total = integer(member.totalSessions ?? sessions.total);
        const deductionApplied = shouldDeduct(requestedStatus) &&
          remainingBefore > 0;
        const remainingAfter = deductionApplied ? remainingBefore - 1 :
          remainingBefore;
        const doneAfter = deductionApplied ? doneBefore + 1 : doneBefore;
        const countKey = statusCountKey(requestedStatus);
        const nextStats = {
          ...stats,
          confirmedCount: integer(stats.confirmedCount) + 1,
          [countKey]: integer(stats[countKey]) + 1,
          lastConfirmStatus: requestedStatus,
          lastConfirmedAt: log.startAt ?? log.lessonDate ?? Timestamp.now(),
          lastLessonType: String(log.lessonType ?? ""),
        };
        const nextSessions = {
          ...sessions,
          ...(deductionApplied ? {remain: remainingAfter, done: doneAfter} : {}),
          ...(countKey === "completedCount" ? {} : {
            [countKey]: integer(sessions[countKey]) + 1,
          }),
        };
        const memberUpdate: Data = {
          lessonStats: nextStats,
          sessions: nextSessions,
          lastLogAt: log.startAt ?? log.lessonDate ?? Timestamp.now(),
          lastLessonAt: log.startAt ?? log.lessonDate ?? Timestamp.now(),
          lastLessonType: String(log.lessonType ?? ""),
          lastLessonStatus: requestedStatus,
          confirmedTrainingLogIds: FieldValue.arrayUnion(lessonLogId),
          updatedAt: FieldValue.serverTimestamp(),
        };
        if (deductionApplied) {
          memberUpdate.remainingSessions = remainingAfter;
          memberUpdate.remainSessions = remainingAfter;
          memberUpdate.doneSessions = doneAfter;
          memberUpdate.deductedTrainingLogIds =
            FieldValue.arrayUnion(lessonLogId);
        }
        if (countKey !== "completedCount") {
          memberUpdate[countKey] = integer(member[countKey]) + 1;
        }
        transaction.update(memberRef, memberUpdate);

        const finalizedAt = FieldValue.serverTimestamp();
        const memberNameSnapshot = String(member.name ?? "").trim();
        transaction.update(logRef, {
          status: requestedStatus,
          sessionStatus: requestedStatus,
          memberNameSnapshot,
          lessonConfirmed: true,
          locked: true,
          finalizedAt,
          finalizedBy: uid,
          confirmationRevision: 1,
          deductionTarget: shouldDeduct(requestedStatus),
          deductionApplied,
          remainBeforeDeduct: remainingBefore,
          remainAfterDeduct: remainingAfter,
          sessionSnapshotTotal: total,
          sessionSnapshotRemainBefore: remainingBefore,
          sessionSnapshotRemainAfter: remainingAfter,
          sessionSnapshotDoneBefore: doneBefore,
          sessionSnapshotDoneAfter: doneAfter,
          sessionSnapshotLessonNumber: doneAfter,
          ...(quickSign == null ? {} :
            quickSignLogFields(quickSign, member, Timestamp.now())),
          updatedAt: finalizedAt,
        });

        // 레슨 진행 알림(발송 전): 확정할 때마다 보낼 알림 한 건을 남긴다. 실제 발송은 별도로 붙인다.
        const notice = buildLessonProgressNotice({
          trainerId: uid,
          memberId,
          memberName: memberNameSnapshot,
          lessonType: String(log.lessonType ?? member.lessonType ?? ""),
          lessonLogId,
          status: requestedStatus,
          progressChanged: deductionApplied,
          total,
          done: doneAfter,
          remain: remainingAfter,
        });
        if (notice != null) {
          transaction.set(
            db.collection(LESSON_PROGRESS_NOTICES).doc(lessonLogId),
            {...notice, createdAt: FieldValue.serverTimestamp()},
          );
        }

        const ledgerRef = memberRef.collection("lesson_ledger").doc(lessonLogId);
        transaction.create(ledgerRef, {
          lessonLogId,
          trainerId: uid,
          workspaceType: "personal",
          type: "lesson_finalize",
          status: requestedStatus,
          deltaRemain: deductionApplied ? -1 : 0,
          remainBefore: remainingBefore,
          remainAfter: remainingAfter,
          createdAt: FieldValue.serverTimestamp(),
        });

        if (scheduleRef != null) {
          transaction.update(scheduleRef, {
            lessonConfirmed: true,
            lessonConfirmedAt: finalizedAt,
            lessonConfirmStatus: requestedStatus,
            trainingLogId: lessonLogId,
            attended: requestedStatus === "completed" ||
              requestedStatus === "service",
            attendanceOverride: requestedStatus === "completed" ?
              FieldValue.delete() : requestedStatus,
            scheduleStatusBeforeConfirm: schedule.status ?? "scheduled",
            scheduleAttendedBeforeConfirm: schedule.attended ?? null,
            scheduleAttendanceOverrideBeforeConfirm:
              schedule.attendanceOverride ?? null,
            sessionSnapshotTotal: total,
            sessionSnapshotRemainBefore: remainingBefore,
            sessionSnapshotRemainAfter: remainingAfter,
            sessionSnapshotDoneBefore: doneBefore,
            sessionSnapshotDoneAfter: doneAfter,
            ...(quickSign == null ? {} :
              quickSignScheduleFields(
                quickSign,
                member,
                lessonLogId,
                Timestamp.now(),
              )),
            updatedAt: finalizedAt,
          });
        }

        return {
          lessonLogId,
          status: requestedStatus,
          alreadyFinalized: false,
          deductionApplied,
          remainingBefore,
          remainingAfter,
        };
      });
    } catch (error) {
      return translated(error, "finalize");
    }
  };
}

export function cancelPersonalTrainingLogHandler(
  db: FirebaseFirestore.Firestore,
) {
  return async (raw: unknown, ctx: functions.https.CallableContext) => {
    const uid = requireUid(ctx);
    const data = objectData(raw);
    const lessonLogId = requiredString(data, "lessonLogId");
    const logRef = db.collection("training_logs").doc(lessonLogId);

    try {
      return await db.runTransaction(async (transaction) => {
        const logSnapshot = await transaction.get(logRef);
        if (!logSnapshot.exists) {
          throw new functions.https.HttpsError("not-found", "log_not_found");
        }
        const log = logSnapshot.data() ?? {};
        if (!isPersonalOwner(log, uid) || log.lessonLogId !== lessonLogId) {
          throw new functions.https.HttpsError(
            "permission-denied",
            "log_owner_mismatch",
          );
        }
        const currentStatus = String(log.status ?? "").trim();
        if (currentStatus === "confirm_cancelled") {
          return {lessonLogId, alreadyCancelled: true};
        }
        if (!FINAL_STATUSES.includes(currentStatus as FinalStatus)) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "log_not_finalized",
          );
        }
        const originalStatus = currentStatus as FinalStatus;
        const memberId = String(log.memberId ?? "").trim();
        const memberRef = db.collection("members").doc(memberId);
        const memberSnapshot = await transaction.get(memberRef);
        const member = validateMember(memberSnapshot, memberId, uid);

        const scheduleId = String(log.scheduleDocId ?? "").trim();
        let scheduleRef: FirebaseFirestore.DocumentReference | null = null;
        let schedule: Data = {};
        if (scheduleId.length > 0) {
          scheduleRef = db.collection("schedules").doc(scheduleId);
          const scheduleSnapshot = await transaction.get(scheduleRef);
          schedule = validateSchedule(
            scheduleSnapshot,
            scheduleId,
            memberId,
            uid,
          );
          if (String(schedule.trainingLogId ?? "").trim() !== lessonLogId) {
            throw new functions.https.HttpsError(
              "failed-precondition",
              "schedule_log_mismatch",
            );
          }
        }

        const noticeRef = db.collection(LESSON_PROGRESS_NOTICES).doc(lessonLogId);
        const noticeSnapshot = await transaction.get(noticeRef);

        const sessions = mapData(member.sessions);
        const stats = mapData(member.lessonStats);
        const remaining = integer(
          member.remainingSessions ?? member.remainSessions ?? sessions.remain,
        );
        const done = integer(member.doneSessions ?? sessions.done);
        const deductionApplied = log.deductionApplied === true;
        const restoredRemaining = deductionApplied ? remaining + 1 : remaining;
        const restoredDone = deductionApplied ? Math.max(0, done - 1) : done;
        const countKey = statusCountKey(originalStatus);
        const nextStats = {
          ...stats,
          confirmedCount: Math.max(0, integer(stats.confirmedCount) - 1),
          [countKey]: Math.max(0, integer(stats[countKey]) - 1),
          lastConfirmStatus: "confirm_cancelled",
          lastCancelledAt: Timestamp.now(),
        };
        const nextSessions = {
          ...sessions,
          ...(deductionApplied ? {
            remain: restoredRemaining,
            done: restoredDone,
          } : {}),
          ...(countKey === "completedCount" ? {} : {
            [countKey]: Math.max(0, integer(sessions[countKey]) - 1),
          }),
        };
        const memberUpdate: Data = {
          lessonStats: nextStats,
          sessions: nextSessions,
          lastLessonStatus: "confirm_cancelled",
          confirmedTrainingLogIds: FieldValue.arrayRemove(lessonLogId),
          deductedTrainingLogIds: FieldValue.arrayRemove(lessonLogId),
          updatedAt: FieldValue.serverTimestamp(),
        };
        if (deductionApplied) {
          memberUpdate.remainingSessions = restoredRemaining;
          memberUpdate.remainSessions = restoredRemaining;
          memberUpdate.doneSessions = restoredDone;
        }
        if (countKey !== "completedCount") {
          memberUpdate[countKey] = Math.max(0, integer(member[countKey]) - 1);
        }
        transaction.update(memberRef, memberUpdate);

        transaction.update(logRef, {
          status: "confirm_cancelled",
          sessionStatus: "confirm_cancelled",
          previousFinalStatus: originalStatus,
          lessonConfirmed: false,
          locked: false,
          confirmCancelled: true,
          confirmCancelledAt: FieldValue.serverTimestamp(),
          cancelledDeductionApplied: deductionApplied,
          deductionApplied: false,
          updatedAt: FieldValue.serverTimestamp(),
        });

        // 아직 보내지 않은 레슨 진행 알림은 취소한다(이미 보낸 것은 그대로 둔다).
        if (noticeSnapshot.exists && noticeSnapshot.data()?.state === "pending") {
          transaction.update(noticeRef, {
            state: "cancelled",
            cancelledAt: FieldValue.serverTimestamp(),
          });
        }

        const reverseRef = memberRef.collection("lesson_ledger")
          .doc(`${lessonLogId}_reverse`);
        transaction.create(reverseRef, {
          lessonLogId,
          trainerId: uid,
          workspaceType: "personal",
          type: "lesson_finalize_cancel",
          status: originalStatus,
          deltaRemain: deductionApplied ? 1 : 0,
          createdAt: FieldValue.serverTimestamp(),
        });

        if (scheduleRef != null) {
          transaction.update(scheduleRef, {
            status: schedule.scheduleStatusBeforeConfirm ?? "scheduled",
            attended: schedule.scheduleAttendedBeforeConfirm == null ?
              FieldValue.delete() : schedule.scheduleAttendedBeforeConfirm,
            attendanceOverride:
              schedule.scheduleAttendanceOverrideBeforeConfirm == null ?
                FieldValue.delete() :
                schedule.scheduleAttendanceOverrideBeforeConfirm,
            lessonConfirmed: FieldValue.delete(),
            lessonConfirmedAt: FieldValue.delete(),
            lessonConfirmStatus: FieldValue.delete(),
            trainingLogId: FieldValue.delete(),
            scheduleStatusBeforeConfirm: FieldValue.delete(),
            scheduleAttendedBeforeConfirm: FieldValue.delete(),
            scheduleAttendanceOverrideBeforeConfirm: FieldValue.delete(),
            sessionSnapshotTotal: FieldValue.delete(),
            sessionSnapshotRemainBefore: FieldValue.delete(),
            sessionSnapshotRemainAfter: FieldValue.delete(),
            sessionSnapshotDoneBefore: FieldValue.delete(),
            sessionSnapshotDoneAfter: FieldValue.delete(),
            confirmCancelledAt: FieldValue.serverTimestamp(),
            confirmCancelledLogId: lessonLogId,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
        return {
          lessonLogId,
          alreadyCancelled: false,
          deductionRestored: deductionApplied,
          remainingAfterCancel: restoredRemaining,
        };
      });
    } catch (error) {
      return translated(error, "cancel");
    }
  };
}
