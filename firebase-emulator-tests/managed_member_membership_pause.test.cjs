const assert = require("node:assert/strict");
const fs = require("node:fs");
const {
  assertFails,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc, updateDoc} = require("firebase/firestore");
const {callCallable} = require("./functions_client.cjs");

const projectId = process.env.PAUSE_TEST_PROJECT_ID ||
  "demo-mtf-membership-pause";
const authHost = process.env.PAUSE_TEST_AUTH_HOST || "127.0.0.1:9099";
const functionsHost = process.env.PAUSE_TEST_FUNCTIONS_HOST ||
  "127.0.0.1:5001";
const firestorePort = Number(process.env.PAUSE_TEST_FIRESTORE_PORT || 8080);
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
  const text = await response.text();
  return {ok: response.ok, body: JSON.parse(text)};
}

async function signUpAnonymous() {
  const result = await authRequest("signUp", {returnSecureToken: true});
  assert.equal(result.ok, true, JSON.stringify(result.body));
  return result.body;
}

function context(env, uid) {
  return env.authenticatedContext(uid, {
    firebase: {sign_in_provider: "anonymous"},
  });
}

async function callFunction(name, idToken, data = {}) {
  return callCallable({projectId, name, idToken, data, host: functionsHost});
}

async function bootstrapAnonymous(user) {
  const result = await callFunction(
    "bootstrapAnonymousBeginnerProfile",
    user.idToken,
  );
  assert.equal(result.status, 200, JSON.stringify(result.body));
}

async function completeTrainerProfile(user) {
  return callFunction("updatePersonalTrainerProfile", user.idToken, {
    displayName: "김트레이너",
    realName: "김트레이너",
    jobTitle: "PT 트레이너",
    phone: "01099998888",
    activityRegion: "서울특별시 강남구",
    primaryActivity: "퍼스널트레이닝",
    affiliationType: "freelancer",
  });
}

async function seedPersonalSchedules(env, uid, count, prefix = "pause") {
  await env.withSecurityRulesDisabled(async (admin) => {
    for (let index = 0; index < count; index += 1) {
      await setDoc(
        doc(admin.firestore(), "schedules", `${uid}--${prefix}-${index}`),
        {
          trainerId: uid,
          workspaceType: "personal",
          status: "scheduled",
          name: `미등록회원${index}`,
        },
      );
    }
  });
}

async function promoteAnonymousToAmateur(env, user, prefix) {
  await seedPersonalSchedules(env, user.localId, 10, prefix);
  const completed = await completeTrainerProfile(user);
  assert.equal(completed.status, 200, JSON.stringify(completed.body));
  const reconciled = await callFunction("reconcilePersonalTier", user.idToken);
  assert.equal(reconciled.status, 200, JSON.stringify(reconciled.body));
  assert.equal(reconciled.body.result.tier, "Amateur");
}

function memberPayloadWithMembership({
  index,
  startAt,
  endAt,
  days,
  extra = {},
}) {
  return {
    idempotencyKey: `pause-member-${index}`,
    name: `정지 테스트 회원 ${index}`,
    gender: "male",
    birthDate: "1990-02-03",
    phone: `010${String(index).padStart(8, "0")}`,
    activityRegion: "서울",
    note: "membership pause fixture",
    membership: {
      notRegistered: false,
      termMonths: null,
      customDays: days,
      startAt,
      endAt,
      days,
      lastRegisteredAt: startAt,
      reregisterCount: 0,
      lastReregisterAt: null,
    },
    ...extra,
  };
}

async function main() {
  const env = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: "127.0.0.1",
      port: firestorePort,
      rules: fs.readFileSync("firestore.rules", "utf8"),
    },
  });

  try {
    await env.clearFirestore();

    await scenario("unauthenticated pause is rejected", async () => {
      const result = await callFunction(
        "updateManagedMemberMembershipPause",
        null,
        {memberId: "does-not-matter", action: "pause", pauseDays: 7},
      );
      assert.equal(result.body.error.status, "UNAUTHENTICATED");
    });

    const owner = await signUpAnonymous();
    await bootstrapAnonymous(owner);
    await promoteAnonymousToAmateur(env, owner, "pause-owner");

    // 오늘로부터 90일 뒤 종료되는, 30일짜리 회원권을 가진 회원 fixture.
    const today = new Date();
    const startAt = today.toISOString().slice(0, 10);
    const endDate = new Date(today.getTime());
    endDate.setUTCDate(endDate.getUTCDate() + 89);
    const endAt = endDate.toISOString().slice(0, 10);

    const created = await callFunction(
      "createManagedMember",
      owner.idToken,
      memberPayloadWithMembership({index: 1, startAt, endAt, days: 90}),
    );
    assert.equal(created.status, 200, JSON.stringify(created.body));
    const memberId = created.body.result.memberId;
    const db = context(env, owner.localId).firestore();

    await scenario(
      "direct client write to members membershipStatus is rejected",
      async () => {
        await assertFails(
          updateDoc(doc(db, "members", memberId), {
            membershipStatus: "paused",
          }),
        );
      },
    );

    await scenario("resume before any pause is rejected", async () => {
      const result = await callFunction(
        "updateManagedMemberMembershipPause",
        owner.idToken,
        {memberId, action: "resume"},
      );
      assert.equal(result.body.error.status, "FAILED_PRECONDITION");
      assert.equal(result.body.error.message, "not_paused");
    });

    await scenario("pausing more days than remaining is rejected", async () => {
      const result = await callFunction(
        "updateManagedMemberMembershipPause",
        owner.idToken,
        {memberId, action: "pause", pauseDays: 9999},
      );
      assert.equal(result.body.error.status, "FAILED_PRECONDITION");
      assert.equal(result.body.error.message, "pause_days_over_remaining");
      const snapshot = await getDoc(doc(db, "members", memberId));
      assert.equal(snapshot.data().membershipStatus, undefined);
    });

    await scenario(
      "pause persists status, history, and resume due date",
      async () => {
        const result = await callFunction(
          "updateManagedMemberMembershipPause",
          owner.idToken,
          {memberId, action: "pause", pauseDays: 7},
        );
        assert.equal(result.status, 200, JSON.stringify(result.body));
        assert.equal(result.body.result.pauseDays, 7);
        assert.ok(result.body.result.resumeDueAtMillis);

        const snapshot = await getDoc(doc(db, "members", memberId));
        const data = snapshot.data();
        assert.equal(data.membershipStatus, "paused");
        assert.equal(data.membership.status, "paused");
        assert.equal(data.memberStatus, "휴면");
        assert.equal(data.membershipPausePlannedDays, 7);
        assert.equal(data.membership.pausePlannedDays, 7);
        assert.ok(data.membershipPausedAt);
        assert.ok(data.membership.pausedAt);
        assert.equal(data.membershipPauseHistory.length, 1);
        assert.equal(data.membershipPauseHistory[0].type, "pause");
        assert.equal(data.membershipPauseHistory[0].plannedDays, 7);
      },
    );

    await scenario("pausing an already-paused membership is rejected", async () => {
      const result = await callFunction(
        "updateManagedMemberMembershipPause",
        owner.idToken,
        {memberId, action: "pause", pauseDays: 3},
      );
      assert.equal(result.body.error.status, "FAILED_PRECONDITION");
      assert.equal(result.body.error.message, "already_paused");
    });

    await scenario("other trainer cannot pause or resume this member", async () => {
      const other = await signUpAnonymous();
      await bootstrapAnonymous(other);
      const result = await callFunction(
        "updateManagedMemberMembershipPause",
        other.idToken,
        {memberId, action: "resume"},
      );
      assert.equal(result.body.error.status, "PERMISSION_DENIED");
    });

    await scenario(
      "resume persists active status, extends end date, and appends history",
      async () => {
        const before = await getDoc(doc(db, "members", memberId));
        const beforeEndAt = before.data().membership.endAt.toMillis();

        const result = await callFunction(
          "updateManagedMemberMembershipPause",
          owner.idToken,
          {memberId, action: "resume"},
        );
        assert.equal(result.status, 200, JSON.stringify(result.body));
        assert.ok(result.body.result.actualPauseDays >= 1);

        const snapshot = await getDoc(doc(db, "members", memberId));
        const data = snapshot.data();
        assert.equal(data.membershipStatus, "active");
        assert.equal(data.membership.status, "active");
        assert.equal(data.memberStatus, "활성");
        assert.equal(
          data.membershipPauseActualDays,
          result.body.result.actualPauseDays,
        );
        assert.equal(
          data.membershipPauseUsedDays,
          result.body.result.actualPauseDays,
        );
        // 회원권 종료일이 실제 정지일만큼 뒤로 연장되어야 한다.
        const afterEndAt = data.membership.endAt.toMillis();
        const expectedDelta =
          result.body.result.actualPauseDays * 24 * 60 * 60 * 1000;
        assert.equal(afterEndAt - beforeEndAt, expectedDelta);
        assert.equal(data.membershipPauseHistory.length, 2);
        assert.equal(data.membershipPauseHistory[1].type, "resume");
      },
    );

    await scenario(
      "a second pause/resume cycle keeps both history entries and accumulates used days",
      async () => {
        const paused = await callFunction(
          "updateManagedMemberMembershipPause",
          owner.idToken,
          {memberId, action: "pause", pauseDays: 5},
        );
        assert.equal(paused.status, 200, JSON.stringify(paused.body));

        const beforeUsedDays = (await getDoc(doc(db, "members", memberId)))
          .data().membershipPauseUsedDays;

        const resumed = await callFunction(
          "updateManagedMemberMembershipPause",
          owner.idToken,
          {memberId, action: "resume"},
        );
        assert.equal(resumed.status, 200, JSON.stringify(resumed.body));

        const snapshot = await getDoc(doc(db, "members", memberId));
        const data = snapshot.data();
        assert.equal(data.membershipPauseHistory.length, 4);
        assert.equal(
          data.membershipPauseUsedDays,
          beforeUsedDays + resumed.body.result.actualPauseDays,
        );
      },
    );

    assert.equal(passed, 9);
    process.stdout.write(
      "All 9 membership pause/resume scenarios passed.\n",
    );
  } finally {
    await env.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
