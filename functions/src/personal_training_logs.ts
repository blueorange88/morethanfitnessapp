import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";

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
          updatedAt: finalizedAt,
        });

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
