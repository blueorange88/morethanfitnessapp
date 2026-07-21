const assert = require("node:assert/strict");
const fs = require("node:fs");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} = require("firebase/firestore");
const {callCallable} = require("./functions_client.cjs");

const projectId = "demo-mtf-personal-training-logs";
const authHost = "127.0.0.1:9099";
const start = new Date("2026-07-20T05:00:00.000Z");
let passed = 0;

async function scenario(name, action) {
  await action();
  passed += 1;
  process.stdout.write(`PASS ${passed}: ${name}\n`);
}

async function authRequest(method, body) {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:${method}?key=fake`,
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify(body),
    },
  );
  return {ok: response.ok, body: await response.json()};
}

async function signUpAnonymous() {
  const result = await authRequest("signUp", {returnSecureToken: true});
  assert.equal(result.ok, true, JSON.stringify(result.body));
  return result.body;
}

async function signUpLinked(email) {
  const result = await authRequest("signUp", {
    email,
    password: "test-password-123",
    returnSecureToken: true,
  });
  assert.equal(result.ok, true, JSON.stringify(result.body));
  return result.body;
}

async function callFunction(name, idToken, data = {}) {
  return callCallable({projectId, name, idToken, data});
}

function context(env, user, anonymous = true) {
  return env.authenticatedContext(user.localId, {
    ...(anonymous ? {} : {email: user.email}),
    firebase: {sign_in_provider: anonymous ? "anonymous" : "password"},
  }).firestore();
}

function logData(id, uid, memberId, overrides = {}) {
  return {
    lessonLogId: id,
    trainerId: uid,
    workspaceType: "personal",
    schemaVersion: 1,
    memberId,
    lessonDate: Timestamp.fromDate(new Date("2026-07-20T00:00:00.000Z")),
    startAt: Timestamp.fromDate(start),
    endAt: Timestamp.fromDate(new Date(start.getTime() + 50 * 60 * 1000)),
    lessonType: "PT",
    status: "draft",
    source: "formal",
    memo: "레슨 메모",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

async function seedMember(admin, id, uid, overrides = {}) {
  await setDoc(doc(admin, "members", id), {
    memberId: id,
    trainerId: uid,
    workspaceType: "personal",
    schemaVersion: 2,
    managementState: "active",
    name: "회원",
    remainingSessions: 5,
    remainSessions: 5,
    doneSessions: 5,
    totalSessions: 10,
    sessions: {remain: 5, done: 5, total: 10},
    lessonStats: {confirmedCount: 0},
    ...overrides,
  });
}

async function seedSchedule(admin, id, uid, memberId, overrides = {}) {
  await setDoc(doc(admin, "schedules", id), {
    scheduleId: id,
    trainerId: uid,
    workspaceType: "personal",
    schemaVersion: 1,
    memberId,
    startAt: Timestamp.fromDate(start),
    endAt: Timestamp.fromDate(new Date(start.getTime() + 50 * 60 * 1000)),
    dateKey: "2026-07-20",
    slotKey: "2026-07-20T14:00",
    name: "회원",
    type: "PT",
    status: "scheduled",
    memo: "",
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
    ...overrides,
  });
}

async function readAdmin(env, path) {
  let result;
  await env.withSecurityRulesDisabled(async (adminContext) => {
    result = await getDoc(doc(adminContext.firestore(), path));
  });
  return result;
}

async function main() {
  const env = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules: fs.readFileSync("firestore.rules", "utf8"),
    },
  });

  try {
    await env.clearFirestore();
    const anonymous = await signUpAnonymous();
    const linked = await signUpLinked("linked-log@example.com");
    const other = await signUpAnonymous();
    let adminDb;
    await env.withSecurityRulesDisabled(async (adminContext) => {
      adminDb = adminContext.firestore();
      await seedMember(adminDb, "member-a", anonymous.localId);
      await seedMember(adminDb, "member-linked", linked.localId);
      await seedMember(adminDb, "member-b", other.localId);
      await seedSchedule(
        adminDb,
        "schedule-a",
        anonymous.localId,
        "member-a",
      );
      await seedSchedule(
        adminDb,
        "schedule-b",
        other.localId,
        "member-b",
      );
      await seedSchedule(
        adminDb,
        "schedule-unlinked",
        anonymous.localId,
        "",
      );
      await setDoc(doc(adminDb, "training_logs", "legacy-log"), {
        memberId: "legacy-member",
        status: "completed",
      });
    });

    const ownerDb = context(env, anonymous);
    const linkedDb = context(env, linked, false);
    const otherDb = context(env, other);

    await scenario("unauthenticated personal log create is denied", async () => {
      const db = env.unauthenticatedContext().firestore();
      await assertFails(setDoc(doc(db, "training_logs", "unauth-log"),
        logData("unauth-log", anonymous.localId, "member-a")));
    });
    await scenario("anonymous owner can create and read draft", async () => {
      await assertSucceeds(setDoc(doc(ownerDb, "training_logs", "log-a"),
        logData("log-a", anonymous.localId, "member-a", {
          scheduleDocId: "schedule-a",
        })));
      await assertSucceeds(getDoc(doc(ownerDb, "training_logs", "log-a")));
    });
    await scenario("linked owner can create and read draft", async () => {
      await assertSucceeds(setDoc(doc(linkedDb, "training_logs", "log-linked"),
        logData("log-linked", linked.localId, "member-linked")));
      await assertSucceeds(getDoc(doc(linkedDb, "training_logs", "log-linked")));
    });
    await scenario("owner member date query succeeds", async () => {
      const result = await assertSucceeds(getDocs(query(
        collection(ownerDb, "training_logs"),
        where("trainerId", "==", anonymous.localId),
        where("workspaceType", "==", "personal"),
        where("memberId", "==", "member-a"),
        where("startAt", ">=", Timestamp.fromDate(new Date("2026-07-20"))),
        where("startAt", "<", Timestamp.fromDate(new Date("2026-07-21"))),
      )));
      assert.equal(result.docs.some((item) => item.id === "log-a"), true);
    });
    await scenario("owner monthly date query stays personal and ordered", async () => {
      const result = await assertSucceeds(getDocs(query(
        collection(ownerDb, "training_logs"),
        where("trainerId", "==", anonymous.localId),
        where("workspaceType", "==", "personal"),
        where("startAt", ">=", Timestamp.fromDate(new Date("2026-07-01"))),
        where("startAt", "<", Timestamp.fromDate(new Date("2026-08-01"))),
        orderBy("startAt", "asc"),
      )));
      assert.equal(result.docs.some((item) => item.id === "log-a"), true);
      assert.equal(result.docs.some((item) => item.id === "legacy-log"), false);
    });
    await scenario("owner filterless root query is denied", async () => {
      await assertFails(getDocs(collection(ownerDb, "training_logs")));
    });
    await scenario("another uid cannot read owner log", async () => {
      await assertFails(getDoc(doc(otherDb, "training_logs", "log-a")));
    });
    await scenario("legacy ownerless log is excluded", async () => {
      await assertFails(getDoc(doc(ownerDb, "training_logs", "legacy-log")));
    });
    await scenario("other trainer member link is denied", async () => {
      await assertFails(setDoc(doc(ownerDb, "training_logs", "bad-member"),
        logData("bad-member", anonymous.localId, "member-b")));
    });
    await scenario("other trainer schedule link is denied", async () => {
      await assertFails(setDoc(doc(ownerDb, "training_logs", "bad-schedule"),
        logData("bad-schedule", anonymous.localId, "member-a", {
          scheduleDocId: "schedule-b",
        })));
    });
    await scenario("schedule-free formal draft is allowed", async () => {
      await assertSucceeds(setDoc(doc(ownerDb, "training_logs", "direct-log"),
        logData("direct-log", anonymous.localId, "member-a")));
    });
    await scenario("draft autosave mutable fields is allowed", async () => {
      await assertSucceeds(updateDoc(doc(ownerDb, "training_logs", "direct-log"), {
        memo: "자동저장 메모",
        updatedAt: serverTimestamp(),
      }));
    });
    await scenario("unlinked schedule cannot be attached to a member log", async () => {
      await assertFails(setDoc(doc(ownerDb, "training_logs", "bad-unlinked"),
        logData("bad-unlinked", anonymous.localId, "member-a", {
          scheduleDocId: "schedule-unlinked",
        })));
    });
    await scenario("trainer identity mutation is denied", async () => {
      await assertFails(updateDoc(doc(ownerDb, "training_logs", "direct-log"), {
        trainerId: other.localId,
        updatedAt: serverTimestamp(),
      }));
    });
    await scenario("member identity mutation is denied", async () => {
      await assertFails(updateDoc(doc(ownerDb, "training_logs", "direct-log"), {
        memberId: "member-b",
        updatedAt: serverTimestamp(),
      }));
    });
    await scenario("client finalized status mutation is denied", async () => {
      await assertFails(updateDoc(doc(ownerDb, "training_logs", "direct-log"), {
        status: "completed",
        updatedAt: serverTimestamp(),
      }));
    });
    await scenario("home quick sign uses the same canonical create rules", async () => {
      await assertSucceeds(setDoc(doc(ownerDb, "training_logs", "quick-log"),
        logData("quick-log", anonymous.localId, "member-a", {
          scheduleDocId: "schedule-a",
          source: "home_quick_sign",
        })));
    });

    const completed = await callFunction(
      "finalizePersonalTrainingLog",
      anonymous.idToken,
      {lessonLogId: "log-a", status: "completed"},
    );
    await scenario("completed finalize succeeds", async () => {
      assert.equal(completed.status, 200, JSON.stringify(completed.body));
      assert.equal(completed.body.result.deductionApplied, true);
    });
    await scenario("completed deducts remaining exactly once", async () => {
      const member = (await readAdmin(env, "members/member-a")).data();
      assert.equal(member.remainingSessions, 4);
      assert.equal(member.doneSessions, 6);
      assert.equal(member.lessonStats.completedCount, 1);
      assert.equal(member.lessonStats.confirmedCount, 1);
    });
    await scenario("completed synchronizes schedule and log", async () => {
      const schedule = (await readAdmin(env, "schedules/schedule-a")).data();
      const log = (await readAdmin(env, "training_logs/log-a")).data();
      assert.equal(schedule.trainingLogId, "log-a");
      assert.equal(schedule.lessonConfirmStatus, "completed");
      assert.equal(log.status, "completed");
      assert.equal(log.locked, true);
      assert.equal(log.memberNameSnapshot, "회원");
      assert.equal(log.sessionSnapshotLessonNumber, 6);
      assert.equal(log.sessionSnapshotTotal, 10);
    });
    await scenario("duplicate finalize is idempotent", async () => {
      const result = await callFunction(
        "finalizePersonalTrainingLog",
        anonymous.idToken,
        {lessonLogId: "log-a", status: "completed"},
      );
      assert.equal(result.body.result.alreadyFinalized, true);
      const member = (await readAdmin(env, "members/member-a")).data();
      assert.equal(member.remainingSessions, 4);
      assert.equal(member.lessonStats.confirmedCount, 1);
    });
    await scenario("duplicate finalize cannot change finalized status", async () => {
      const result = await callFunction(
        "finalizePersonalTrainingLog",
        anonymous.idToken,
        {lessonLogId: "log-a", status: "service"},
      );
      assert.equal(result.body.error.status, "FAILED_PRECONDITION");
    });
    await scenario("another trainer cannot finalize owner log", async () => {
      const result = await callFunction(
        "finalizePersonalTrainingLog",
        other.idToken,
        {lessonLogId: "log-a", status: "completed"},
      );
      assert.equal(result.body.error.status, "PERMISSION_DENIED");
    });

    const cancelled = await callFunction(
      "cancelPersonalTrainingLog",
      anonymous.idToken,
      {lessonLogId: "log-a"},
    );
    await scenario("finalize cancel restores member count and stats", async () => {
      assert.equal(cancelled.status, 200, JSON.stringify(cancelled.body));
      const member = (await readAdmin(env, "members/member-a")).data();
      assert.equal(member.remainingSessions, 5);
      assert.equal(member.doneSessions, 5);
      assert.equal(member.lessonStats.completedCount, 0);
      assert.equal(member.lessonStats.confirmedCount, 0);
    });
    await scenario("finalize cancel restores schedule state", async () => {
      const schedule = (await readAdmin(env, "schedules/schedule-a")).data();
      const log = (await readAdmin(env, "training_logs/log-a")).data();
      assert.equal(schedule.status, "scheduled");
      assert.equal(schedule.trainingLogId, undefined);
      assert.equal(schedule.lessonConfirmStatus, undefined);
      assert.equal(log.status, "confirm_cancelled");
      assert.equal(log.memberNameSnapshot, "회원");
      assert.equal(log.sessionSnapshotLessonNumber, 6);
      assert.equal(log.sessionSnapshotTotal, 10);
    });
    await scenario("duplicate finalize cancel is idempotent", async () => {
      const result = await callFunction(
        "cancelPersonalTrainingLog",
        anonymous.idToken,
        {lessonLogId: "log-a"},
      );
      assert.equal(result.body.result.alreadyCancelled, true);
      const member = (await readAdmin(env, "members/member-a")).data();
      assert.equal(member.remainingSessions, 5);
      assert.equal(member.lessonStats.confirmedCount, 0);
    });

    async function createAndFinalize(id, status) {
      await setDoc(doc(ownerDb, "training_logs", id),
        logData(id, anonymous.localId, "member-a"));
      const result = await callFunction(
        "finalizePersonalTrainingLog",
        anonymous.idToken,
        {lessonLogId: id, status},
      );
      if (result.status === 200) {
        const log = (await readAdmin(env, `training_logs/${id}`)).data();
        assert.equal(log.memberNameSnapshot, "회원");
        assert.equal(log.sessionSnapshotLessonNumber, log.sessionSnapshotDoneAfter);
      }
      return result;
    }

    await scenario("no_show_deducted deducts and counts", async () => {
      const result = await createAndFinalize("no-show-deduct", "no_show_deducted");
      assert.equal(result.status, 200, JSON.stringify(result.body));
      const member = (await readAdmin(env, "members/member-a")).data();
      assert.equal(member.remainingSessions, 4);
      assert.equal(member.lessonStats.noShowDeductedCount, 1);
    });
    await scenario("no_show_not_deducted keeps remaining and counts", async () => {
      const cancelledNoShow = await callFunction(
        "cancelPersonalTrainingLog",
        anonymous.idToken,
        {
        lessonLogId: "no-show-deduct",
        },
      );
      assert.equal(cancelledNoShow.status, 200);
      let member = (await readAdmin(env, "members/member-a")).data();
      assert.equal(member.remainingSessions, 5);
      assert.equal(member.lessonStats.noShowDeductedCount, 0);
      const result = await createAndFinalize(
        "no-show-no-deduct",
        "no_show_not_deducted",
      );
      assert.equal(result.status, 200, JSON.stringify(result.body));
      member = (await readAdmin(env, "members/member-a")).data();
      assert.equal(member.remainingSessions, 5);
      assert.equal(member.lessonStats.noShowUndeductedCount, 1);
    });
    await scenario("no_show_not_deducted cancel restores its stats only", async () => {
      const result = await callFunction(
        "cancelPersonalTrainingLog",
        anonymous.idToken,
        {lessonLogId: "no-show-no-deduct"},
      );
      assert.equal(result.status, 200);
      const member = (await readAdmin(env, "members/member-a")).data();
      assert.equal(member.remainingSessions, 5);
      assert.equal(member.lessonStats.noShowUndeductedCount, 0);
    });
    await scenario("service keeps remaining and counts", async () => {
      const result = await createAndFinalize("service-log", "service");
      assert.equal(result.status, 200, JSON.stringify(result.body));
      const member = (await readAdmin(env, "members/member-a")).data();
      assert.equal(member.remainingSessions, 5);
      assert.equal(member.lessonStats.serviceSessionCount, 1);
    });
    await scenario("another trainer cannot cancel owner log", async () => {
      const result = await callFunction(
        "cancelPersonalTrainingLog",
        other.idToken,
        {lessonLogId: "service-log"},
      );
      assert.equal(result.body.error.status, "PERMISSION_DENIED");
    });
    await scenario("service cancel restores service stats without sessions", async () => {
      const result = await callFunction(
        "cancelPersonalTrainingLog",
        anonymous.idToken,
        {lessonLogId: "service-log"},
      );
      assert.equal(result.status, 200);
      const member = (await readAdmin(env, "members/member-a")).data();
      assert.equal(member.remainingSessions, 5);
      assert.equal(member.lessonStats.serviceSessionCount, 0);
    });
    await scenario("home quick sign finalizes through the common function", async () => {
      const result = await callFunction(
        "finalizePersonalTrainingLog",
        anonymous.idToken,
        {lessonLogId: "quick-log", status: "completed"},
      );
      assert.equal(result.status, 200, JSON.stringify(result.body));
      const log = (await readAdmin(env, "training_logs/quick-log")).data();
      assert.equal(log.source, "home_quick_sign");
      assert.equal(log.status, "completed");
      await callFunction("cancelPersonalTrainingLog", anonymous.idToken, {
        lessonLogId: "quick-log",
      });
    });
    await scenario("transaction failure leaves all documents unchanged", async () => {
      await env.withSecurityRulesDisabled(async (adminContext) => {
        await setDoc(doc(adminContext.firestore(), "training_logs", "broken-log"),
          logData("broken-log", anonymous.localId, "member-a", {
            scheduleDocId: "schedule-b",
            createdAt: Timestamp.now(),
            updatedAt: Timestamp.now(),
          }));
      });
      const before = (await readAdmin(env, "members/member-a")).data();
      const result = await callFunction(
        "finalizePersonalTrainingLog",
        anonymous.idToken,
        {lessonLogId: "broken-log", status: "completed"},
      );
      assert.equal(result.body.error.status, "PERMISSION_DENIED");
      const after = (await readAdmin(env, "members/member-a")).data();
      const log = (await readAdmin(env, "training_logs/broken-log")).data();
      assert.equal(after.remainingSessions, before.remainingSessions);
      assert.equal(after.lessonStats.confirmedCount, before.lessonStats.confirmedCount);
      assert.equal(log.status, "draft");
    });
    await scenario("cancelled archive remains owner scoped", async () => {
      const result = await assertSucceeds(getDocs(query(
        collection(ownerDb, "training_logs"),
        where("trainerId", "==", anonymous.localId),
        where("workspaceType", "==", "personal"),
        where("memberId", "==", "member-a"),
        where("status", "==", "confirm_cancelled"),
      )));
      assert.equal(result.docs.some((item) => item.id === "log-a"), true);
    });
    await scenario("uid change hides previous trainer logs", async () => {
      const result = await assertSucceeds(getDocs(query(
        collection(otherDb, "training_logs"),
        where("trainerId", "==", other.localId),
        where("workspaceType", "==", "personal"),
        where("memberId", "==", "member-b"),
      )));
      assert.equal(result.empty, true);
    });
    await scenario("personal anatomy child access remains denied", async () => {
      await assertFails(getDocs(collection(
        ownerDb,
        "training_logs/log-a/anatomyRecords",
      )));
    });
    await scenario("contracts and sign requests stay closed", async () => {
      await assertFails(getDoc(doc(ownerDb, "contracts", "closed")));
      await assertFails(getDoc(doc(ownerDb, "sign_requests", "closed")));
    });

    process.stdout.write(
      `All ${passed} personal training log scenarios passed.\n`,
    );
  } finally {
    await env.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
