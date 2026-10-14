const assert = require("node:assert/strict");
const fs = require("node:fs");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  collectionGroup,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  Timestamp,
  deleteDoc,
  updateDoc,
  deleteField,
  where,
  writeBatch,
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
    const detailsSample = {
      v: 1,
      title: "하체운동 + 근력",
      inputMethod: "category",
      issueChips: ["피로", "PMS"],
      homeworkStatus: "없음",
      nextLessonCheckpoint: "무릎 통증 확인",
      pre: {
        condition: "나쁨", meal: "4시간 이상(공복)", sleep: "부족",
        pain: "있음", painDetail: "오른쪽 어깨가 당김", stretching: "안 함",
        note: "어깨 당김",
      },
      during: {
        goals: ["근력"], focusParts: ["하체"], reactions: [],
        focusResponse: "보통", cognitiveResponse: "보통",
        performanceResponse: "보통",
      },
      post: {
        painChange: "없음", performance: "보통", nextAction: "유지",
        homework: "없음",
      },
      notes: {internal: "내부 기록", publicSummary: "요약"},
      exercises: [
        {part: "하체", main: "웨이트 트레이닝", name: "스쿼트", sets: 3, reps: 12},
      ],
    };
    await scenario("draft details are saved and read back", async () => {
      await assertSucceeds(updateDoc(doc(ownerDb, "training_logs", "direct-log"), {
        details: detailsSample,
        updatedAt: serverTimestamp(),
      }));
      const snapshot = await assertSucceeds(
        getDoc(doc(ownerDb, "training_logs", "direct-log")),
      );
      assert.equal(snapshot.data().details.pre.condition, "나쁨");
      assert.equal(snapshot.data().details.exercises[0].name, "스쿼트");
    });
    await scenario("draft can be created with details and removed", async () => {
      await assertSucceeds(setDoc(doc(ownerDb, "training_logs", "details-create-log"),
        logData("details-create-log", anonymous.localId, "member-a", {
          details: detailsSample,
        })));
      await assertSucceeds(deleteDoc(doc(ownerDb, "training_logs", "details-create-log")));
    });
    await scenario("details with unknown key is denied", async () => {
      await assertFails(updateDoc(doc(ownerDb, "training_logs", "direct-log"), {
        details: {...detailsSample, secretField: "x"},
        updatedAt: serverTimestamp(),
      }));
    });
    await scenario("details with oversize text is denied", async () => {
      await assertFails(updateDoc(doc(ownerDb, "training_logs", "direct-log"), {
        details: {...detailsSample, title: "가".repeat(101)},
        updatedAt: serverTimestamp(),
      }));
      await assertFails(updateDoc(doc(ownerDb, "training_logs", "direct-log"), {
        details: {...detailsSample, exercises: Array.from({length: 41}, () => ({}))},
        updatedAt: serverTimestamp(),
      }));
    });
    await scenario("details groups only accept their own keys", async () => {
      await assertFails(updateDoc(doc(ownerDb, "training_logs", "direct-log"), {
        details: {...detailsSample, pre: {...detailsSample.pre, secret: "x"}},
        updatedAt: serverTimestamp(),
      }));
      await assertFails(updateDoc(doc(ownerDb, "training_logs", "direct-log"), {
        details: {...detailsSample, pre: "text"},
        updatedAt: serverTimestamp(),
      }));
    });
    await scenario("details with wrong types is denied", async () => {
      await assertFails(updateDoc(doc(ownerDb, "training_logs", "direct-log"), {
        details: {...detailsSample, issueChips: "피로"},
        updatedAt: serverTimestamp(),
      }));
      await assertFails(updateDoc(doc(ownerDb, "training_logs", "direct-log"), {
        details: "text",
        updatedAt: serverTimestamp(),
      }));
    });
    await scenario("another trainer cannot write details to owner log", async () => {
      await assertFails(updateDoc(doc(otherDb, "training_logs", "direct-log"), {
        details: detailsSample,
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
    await scenario("finalized log details are immutable", async () => {
      await assertFails(updateDoc(doc(ownerDb, "training_logs", "log-a"), {
        details: {title: "확정 후 수정"},
        updatedAt: serverTimestamp(),
      }));
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
    // ---- 아나토미 기록(training_logs/{id}/anatomyRecords) ----
    const anatomyLogId = "anatomy-log";
    await assertSucceeds(setDoc(doc(ownerDb, "training_logs", anatomyLogId),
      logData(anatomyLogId, anonymous.localId, "member-a")));
    const anatomyPath = (id) => `training_logs/${anatomyLogId}/anatomyRecords/${id}`;
    const anatomyData = (id, overrides = {}) => ({
      anatomyLogId: id,
      trainerId: anonymous.localId,
      memberId: "member-a",
      lessonLogId: anatomyLogId,
      scheduleDocId: "",
      recordedAt: Timestamp.fromDate(start),
      bodyGender: "male",
      bodyView: "front",
      bodySide: "right",
      bodyPartId: "delt_side",
      bodyPartLabel: "측면삼각근",
      recordType: "exercise",
      exerciseName: "사이드 레터럴 레이즈",
      painLevel: 0,
      memo: "",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      ...overrides,
    });
    const anatomySummary = (count) => ({
      anatomySchemaVersion: 1,
      hasAnatomyRecords: count > 0,
      anatomyRecordCount: count,
      updatedAt: serverTimestamp(),
    });
    const saveAnatomy = async (db, ids, overrides = {}) => {
      const batch = writeBatch(db);
      ids.forEach((id) => batch.set(
        doc(db, anatomyPath(id)), anatomyData(id, overrides)));
      batch.update(doc(db, "training_logs", anatomyLogId),
        anatomySummary(ids.length));
      await batch.commit();
    };

    await scenario("personal anatomy record and parent summary save together", async () => {
      await assertSucceeds(saveAnatomy(ownerDb, ["rec-1"]));
      const snapshot = await assertSucceeds(getDoc(doc(ownerDb, anatomyPath("rec-1"))));
      assert.equal(snapshot.data().bodySide, "right");
      const parent = (await readAdmin(env, `training_logs/${anatomyLogId}`)).data();
      assert.equal(parent.anatomyRecordCount, 1);
      assert.equal(parent.hasAnatomyRecords, true);
    });
    await scenario("personal anatomy owner can list the child collection", async () => {
      const result = await assertSucceeds(getDocs(collection(
        ownerDb, `training_logs/${anatomyLogId}/anatomyRecords`)));
      assert.equal(result.size, 1);
    });
    await scenario("personal anatomy several records fit one save", async () => {
      await assertSucceeds(saveAnatomy(
        ownerDb, ["rec-2", "rec-3", "rec-4", "rec-5", "rec-6", "rec-7", "rec-8"]));
    });
    await scenario("personal anatomy sets are saved, updated and bounded", async () => {
      const sets = (n) => Array.from({length: n}, () => ({w: 8, r: 12}));
      await assertSucceeds(setDoc(doc(ownerDb, anatomyPath("sets-1")),
        anatomyData("sets-1", {sets: sets(3)})));
      const stored = await assertSucceeds(getDoc(doc(ownerDb, anatomyPath("sets-1"))));
      assert.equal(stored.data().sets.length, 3);
      assert.equal(stored.data().sets[0].w, 8);
      await assertSucceeds(updateDoc(doc(ownerDb, anatomyPath("sets-1")), {
        sets: sets(5), updatedAt: serverTimestamp(),
      }));
      await assertSucceeds(setDoc(doc(ownerDb, anatomyPath("sets-max")),
        anatomyData("sets-max", {sets: sets(30)})));
      await assertFails(setDoc(doc(ownerDb, anatomyPath("sets-31")),
        anatomyData("sets-31", {sets: sets(31)})));
      await assertFails(setDoc(doc(ownerDb, anatomyPath("sets-bad")),
        anatomyData("sets-bad", {sets: "3 x 8kg"})));
      await assertFails(updateDoc(doc(ownerDb, anatomyPath("sets-1")), {
        sets: sets(31), updatedAt: serverTimestamp(),
      }));
      await assertSucceeds(deleteDoc(doc(ownerDb, anatomyPath("sets-1"))));
      await assertSucceeds(deleteDoc(doc(ownerDb, anatomyPath("sets-max"))));
    });
    await scenario("personal anatomy related parts are saved, updated, cleared and bounded", async () => {
      const parts = (n) => Array.from({length: n}, (_, i) => `part_${i}`);
      await assertSucceeds(setDoc(doc(ownerDb, anatomyPath("rel-1")),
        anatomyData("rel-1", {relatedPartIds: ["glute", "hamstring"]})));
      const stored = await assertSucceeds(getDoc(doc(ownerDb, anatomyPath("rel-1"))));
      assert.deepEqual(stored.data().relatedPartIds, ["glute", "hamstring"]);
      await assertSucceeds(updateDoc(doc(ownerDb, anatomyPath("rel-1")), {
        bodyPartId: "glute", bodyPartLabel: "둔근",
        relatedPartIds: ["quad"], updatedAt: serverTimestamp(),
      }));
      await assertSucceeds(updateDoc(doc(ownerDb, anatomyPath("rel-1")), {
        relatedPartIds: deleteField(), sets: deleteField(),
        updatedAt: serverTimestamp(),
      }));
      const cleared = await assertSucceeds(getDoc(doc(ownerDb, anatomyPath("rel-1"))));
      assert.equal(cleared.data().relatedPartIds, undefined);
      await assertSucceeds(setDoc(doc(ownerDb, anatomyPath("rel-8")),
        anatomyData("rel-8", {relatedPartIds: parts(8)})));
      await assertFails(setDoc(doc(ownerDb, anatomyPath("rel-9")),
        anatomyData("rel-9", {relatedPartIds: parts(9)})));
      await assertFails(setDoc(doc(ownerDb, anatomyPath("rel-bad")),
        anatomyData("rel-bad", {relatedPartIds: "glute"})));
      await assertFails(updateDoc(doc(ownerDb, anatomyPath("rel-8")), {
        relatedPartIds: parts(9), updatedAt: serverTimestamp(),
      }));
      await assertSucceeds(deleteDoc(doc(ownerDb, anatomyPath("rel-1"))));
      await assertSucceeds(deleteDoc(doc(ownerDb, anatomyPath("rel-8"))));
    });
    await scenario("personal anatomy pin and mobility result are validated", async () => {
      await assertSucceeds(setDoc(doc(ownerDb, anatomyPath("pin-1")),
        anatomyData("pin-1", {
          recordType: "mobility", pin: {x: 120.5, y: 300}, mobilityResult: "mild",
        })));
      const stored = await assertSucceeds(getDoc(doc(ownerDb, anatomyPath("pin-1"))));
      assert.equal(stored.data().pin.x, 120.5);
      assert.equal(stored.data().mobilityResult, "mild");
      for (const [i, overrides] of [
        {pin: {x: -1, y: 10}},
        {pin: {x: 10, y: 901}},
        {pin: {x: 701, y: 10}},
        {pin: {x: "10", y: 10}},
        {pin: {x: 10}},
        {pin: {x: 10, y: 10, z: 1}},
        {pin: [10, 10]},
        {pin: "10,10"},
        {mobilityResult: "bad"},
        {mobilityResult: 2},
      ].entries()) {
        await assertFails(setDoc(doc(ownerDb, anatomyPath(`pin-bad-${i}`)),
          anatomyData(`pin-bad-${i}`, overrides)));
      }
      await assertSucceeds(updateDoc(doc(ownerDb, anatomyPath("pin-1")), {
        mobilityResult: "severe", pin: {x: 130, y: 310}, updatedAt: serverTimestamp(),
      }));
      await assertSucceeds(updateDoc(doc(ownerDb, anatomyPath("pin-1")), {
        mobilityResult: deleteField(), pin: deleteField(), updatedAt: serverTimestamp(),
      }));
      const cleared = await assertSucceeds(getDoc(doc(ownerDb, anatomyPath("pin-1"))));
      assert.equal(cleared.data().pin, undefined);
      assert.equal(cleared.data().mobilityResult, undefined);
      await assertFails(updateDoc(doc(ownerDb, anatomyPath("pin-1")), {
        pin: {x: 1000, y: 1}, updatedAt: serverTimestamp(),
      }));
      await assertSucceeds(deleteDoc(doc(ownerDb, anatomyPath("pin-1"))));
    });
    await scenario("personal anatomy mutable fields update", async () => {
      await assertSucceeds(updateDoc(doc(ownerDb, anatomyPath("rec-1")), {
        bodySide: "both",
        bodyView: "back",
        recordType: "pain",
        painLevel: 6,
        memo: "움직일 때 통증",
        updatedAt: serverTimestamp(),
      }));
    });
    await scenario("personal anatomy identity and creation time are immutable", async () => {
      for (const patch of [
        {memberId: "member-b"},
        {trainerId: other.localId},
        {lessonLogId: "other-log"},
        {anatomyLogId: "rec-x"},
        {createdAt: serverTimestamp()},
        {scheduleDocId: "schedule-a"},
      ]) {
        await assertFails(updateDoc(doc(ownerDb, anatomyPath("rec-1")), {
          ...patch,
          updatedAt: serverTimestamp(),
        }));
      }
    });
    await scenario("personal anatomy invalid values are denied", async () => {
      const bad = [
        {bodySide: "up"},
        {bodyView: "side"},
        {bodyGender: "x"},
        {recordType: "other"},
        {painLevel: 11},
        {painLevel: -1},
        {painLevel: 5.5},
        {bodyPartId: ""},
        {bodyPartId: "x".repeat(41)},
        {exerciseName: "x".repeat(101)},
        {memo: "x".repeat(2001)},
        {recordedAt: "2026-07-20"},
        {unknownKey: "x"},
      ];
      for (const [i, overrides] of bad.entries()) {
        await assertFails(setDoc(
          doc(ownerDb, anatomyPath(`bad-${i}`)),
          anatomyData(`bad-${i}`, overrides)));
      }
    });
    await scenario("personal anatomy mismatched identity is denied", async () => {
      await assertFails(setDoc(doc(ownerDb, anatomyPath("mis-1")),
        anatomyData("mis-1", {memberId: "member-b"})));
      await assertFails(setDoc(doc(ownerDb, anatomyPath("mis-2")),
        anatomyData("mis-2", {trainerId: other.localId})));
      await assertFails(setDoc(doc(ownerDb, anatomyPath("mis-3")),
        anatomyData("mis-3", {lessonLogId: "another"})));
      await assertFails(setDoc(doc(ownerDb, anatomyPath("mis-4")),
        anatomyData("mis-4", {anatomyLogId: "different"})));
    });
    await scenario("personal anatomy schedule id must match the parent schedule", async () => {
      const schedLog = "anatomy-sched-log";
      await assertSucceeds(setDoc(doc(ownerDb, "training_logs", schedLog),
        logData(schedLog, anonymous.localId, "member-a", {
          scheduleDocId: "schedule-a",
        })));
      const path = (id) => `training_logs/${schedLog}/anatomyRecords/${id}`;
      const data = (id, overrides = {}) =>
        anatomyData(id, {lessonLogId: schedLog, ...overrides});
      await assertSucceeds(setDoc(doc(ownerDb, path("s-ok-1")),
        data("s-ok-1", {scheduleDocId: "schedule-a"})));
      await assertSucceeds(setDoc(doc(ownerDb, path("s-ok-2")),
        data("s-ok-2", {scheduleDocId: ""})));
      await assertFails(setDoc(doc(ownerDb, path("s-bad-1")),
        data("s-bad-1", {scheduleDocId: "schedule-b"})));
      await assertFails(setDoc(doc(ownerDb, path("s-bad-2")),
        data("s-bad-2", {scheduleDocId: "x".repeat(129)})));
    });
    await scenario("personal anatomy record needs server timestamps", async () => {
      await assertFails(setDoc(doc(ownerDb, anatomyPath("ts-1")),
        anatomyData("ts-1", {createdAt: Timestamp.fromDate(start)})));
      await assertFails(setDoc(doc(ownerDb, anatomyPath("ts-2")),
        anatomyData("ts-2", {updatedAt: Timestamp.fromDate(start)})));
    });
    await scenario("personal anatomy record cannot drop required fields", async () => {
      const {memo: _memo, ...withoutMemo} = anatomyData("drop-1");
      await assertFails(setDoc(doc(ownerDb, anatomyPath("drop-1")), withoutMemo));
    });
    await scenario("personal anatomy parent summary rejects other keys and types", async () => {
      const parentRef = doc(ownerDb, "training_logs", anatomyLogId);
      await assertFails(updateDoc(parentRef, {...anatomySummary(1), status: "completed"}));
      await assertFails(updateDoc(parentRef, {...anatomySummary(1), anatomySchemaVersion: 2}));
      await assertFails(updateDoc(parentRef, {...anatomySummary(1), hasAnatomyRecords: "yes"}));
      await assertFails(updateDoc(parentRef, {...anatomySummary(1), anatomyRecordCount: 101}));
      await assertFails(updateDoc(parentRef, {...anatomySummary(1), anatomyRecordCount: -1}));
      await assertFails(updateDoc(parentRef, {...anatomySummary(1), anatomyRecords: []}));
    });
    await scenario("personal anatomy other trainer and unauthenticated are denied", async () => {
      await assertFails(getDoc(doc(otherDb, anatomyPath("rec-1"))));
      await assertFails(getDocs(collection(
        otherDb, `training_logs/${anatomyLogId}/anatomyRecords`)));
      await assertFails(setDoc(doc(otherDb, anatomyPath("o-1")),
        anatomyData("o-1", {trainerId: other.localId})));
      await assertFails(updateDoc(doc(otherDb, anatomyPath("rec-1")), {
        memo: "남의 기록", updatedAt: serverTimestamp(),
      }));
      await assertFails(deleteDoc(doc(otherDb, anatomyPath("rec-1"))));
      const anon = env.unauthenticatedContext().firestore();
      await assertFails(getDoc(doc(anon, anatomyPath("rec-1"))));
      await assertFails(setDoc(doc(anon, anatomyPath("u-1")), anatomyData("u-1")));
    });
    await scenario("personal anatomy record can be deleted by the owner", async () => {
      await assertSucceeds(deleteDoc(doc(ownerDb, anatomyPath("rec-8"))));
    });
    await scenario("personal anatomy of a finalized log stays readable but locked", async () => {
      await env.withSecurityRulesDisabled(async (adminContext) => {
        const db = adminContext.firestore();
        await setDoc(doc(db, "training_logs", "anatomy-done"), logData(
          "anatomy-done", anonymous.localId, "member-a", {status: "completed"}));
        await setDoc(doc(db, "training_logs/anatomy-done/anatomyRecords/done-1"), {
          ...anatomyData("done-1", {lessonLogId: "anatomy-done"}),
          createdAt: Timestamp.fromDate(start),
          updatedAt: Timestamp.fromDate(start),
        });
      });
      const base = "training_logs/anatomy-done/anatomyRecords";
      await assertSucceeds(getDoc(doc(ownerDb, `${base}/done-1`)));
      await assertFails(setDoc(doc(ownerDb, `${base}/done-2`),
        anatomyData("done-2", {lessonLogId: "anatomy-done"})));
      await assertFails(updateDoc(doc(ownerDb, `${base}/done-1`), {
        memo: "확정 뒤 수정", updatedAt: serverTimestamp(),
      }));
      await assertFails(deleteDoc(doc(ownerDb, `${base}/done-1`)));
    });
    await scenario("anatomy history collection group query is owner scoped", async () => {
      const group = (db, ...constraints) =>
        getDocs(query(collectionGroup(db, "anatomyRecords"), ...constraints));
      // 내 기록을 회원별로 모아 읽는다(여러 레슨일지에 걸쳐)
      const mine = await assertSucceeds(group(ownerDb,
        where("trainerId", "==", anonymous.localId),
        where("memberId", "==", "member-a"),
        orderBy("recordedAt", "desc")));
      assert.equal(mine.empty, false);
      assert.equal(mine.docs.every((d) => d.data().trainerId === anonymous.localId), true);
      const logIds = new Set(mine.docs.map((d) => d.ref.parent.parent.id));
      assert.equal(logIds.size >= 2, true);
      // 다른 강사의 기록은 읽을 수 없다
      await assertFails(group(otherDb,
        where("trainerId", "==", anonymous.localId),
        where("memberId", "==", "member-a")));
      // 내 uid 조건이 없는 조회는 거절
      await assertFails(group(ownerDb, where("memberId", "==", "member-a")));
      await assertFails(group(ownerDb));
      // 비로그인
      const anon = env.unauthenticatedContext().firestore();
      await assertFails(group(anon,
        where("trainerId", "==", anonymous.localId),
        where("memberId", "==", "member-a")));
      // 읽기만 허용: collection group 규칙으로는 쓸 수 없다
      await assertFails(setDoc(doc(ownerDb, "anatomyRecords", "stray"),
        anatomyData("stray")));
    });
    await scenario("personal anatomy of another trainer's log is denied", async () => {
      await assertFails(setDoc(
        doc(otherDb, "training_logs/log-a/anatomyRecords/x-1"),
        anatomyData("x-1", {trainerId: other.localId, lessonLogId: "log-a"})));
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
