const assert = require("node:assert/strict");
const fs = require("node:fs");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  updateDoc,
  where,
} = require("firebase/firestore");
const {callCallable} = require("./functions_client.cjs");

const projectId = process.env.MEMBER_TEST_PROJECT_ID ||
  "demo-mtf-anonymous-members-tier";
const authHost = process.env.MEMBER_TEST_AUTH_HOST || "127.0.0.1:9099";
const functionsHost = process.env.MEMBER_TEST_FUNCTIONS_HOST ||
  "127.0.0.1:5001";
const firestorePort = Number(process.env.MEMBER_TEST_FIRESTORE_PORT || 8080);
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

async function linkEmail(user, email) {
  const result = await authRequest("update", {
    idToken: user.idToken,
    email,
    password: "test-password-123",
    returnSecureToken: true,
  });
  assert.equal(result.ok, true, JSON.stringify(result.body));
  assert.equal(result.body.localId, user.localId);
  return result.body;
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

function memberPayload(index, prefix = "010") {
  return {
    idempotencyKey: `member-${prefix}-${index}`,
    name: `회원 ${index}`,
    gender: index % 2 === 0 ? "female" : "male",
    birthDate: "1990-02-03",
    phone: `${prefix}${String(index).padStart(8, "0")}`,
    activityRegion: "서울",
    note: "test",
  };
}

async function create(user, index, prefix = "010") {
  return callFunction(
    "createManagedMember",
    user.idToken,
    memberPayload(index, prefix),
  );
}

function endDateForInclusiveDays(startDate, days) {
  const date = new Date(`${startDate}T00:00:00.000Z`);
  date.setUTCDate(date.getUTCDate() + days - 1);
  return date.toISOString().slice(0, 10);
}

function context(env, uid, anonymous) {
  return env.authenticatedContext(uid, {
    ...(anonymous ? {} : {email: `${uid}@example.com`}),
    firebase: {
      sign_in_provider: anonymous ? "anonymous" : "password",
    },
  });
}

async function profileData(env, uid) {
  let snapshot;
  await env.withSecurityRulesDisabled(async (admin) => {
    snapshot = await getDoc(doc(admin.firestore(), "trainer_profiles", uid));
  });
  return snapshot.data();
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

async function seedPersonalSchedules(env, uid, count, prefix = "tier") {
  await env.withSecurityRulesDisabled(async (admin) => {
    for (let index = 0; index < count; index += 1) {
      await setDoc(doc(admin.firestore(), "schedules", `${uid}--${prefix}-${index}`), {
        trainerId: uid,
        workspaceType: "personal",
        status: "scheduled",
        name: `미등록회원${index}`,
      });
    }
  });
}

async function promoteAnonymousToAmateur(env, user, prefix) {
  await seedPersonalSchedules(env, user.localId, 10, prefix);
  const completed = await completeTrainerProfile(user);
  assert.equal(completed.status, 200, JSON.stringify(completed.body));
  const reconciled = await callFunction(
    "reconcilePersonalTier",
    user.idToken,
  );
  assert.equal(reconciled.status, 200, JSON.stringify(reconciled.body));
  assert.equal(reconciled.body.result.tier, "Amateur");
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
    const owner = await signUpAnonymous();
    await bootstrapAnonymous(owner);

    await scenario("unauthenticated member create is rejected", async () => {
      const result = await callFunction("createManagedMember", null, {});
      assert.equal(result.body.error.status, "UNAUTHENTICATED");
    });
    await scenario("unauthenticated tier reconcile is rejected", async () => {
      const result = await callFunction("reconcilePersonalTier", null, {});
      assert.equal(result.body.error.status, "UNAUTHENTICATED");
    });
    await scenario("unauthenticated first lesson guide claim is rejected", async () => {
      const result = await callFunction("claimFirstLessonGuide", null, {});
      assert.equal(result.body.error.status, "UNAUTHENTICATED");
    });
    const guideUser = await signUpAnonymous();
    await bootstrapAnonymous(guideUser);
    await seedPersonalSchedules(env, guideUser.localId, 1, "first-guide");
    await scenario("first lesson guide is claimed exactly once", async () => {
      const firstClaim = await callFunction(
        "claimFirstLessonGuide",
        guideUser.idToken,
        {createdScheduleCount: 1},
      );
      const secondClaim = await callFunction(
        "claimFirstLessonGuide",
        guideUser.idToken,
        {createdScheduleCount: 1},
      );
      assert.equal(firstClaim.body.result.shouldShow, true);
      assert.equal(secondClaim.body.result.shouldShow, false);
      assert.equal(secondClaim.body.result.alreadyShown, true);
    });
    const existingGuideUser = await signUpAnonymous();
    await bootstrapAnonymous(existingGuideUser);
    await seedPersonalSchedules(
      env,
      existingGuideUser.localId,
      2,
      "existing-guide",
    );
    await scenario("existing schedules do not trigger a late first guide", async () => {
      const result = await callFunction(
        "claimFirstLessonGuide",
        existingGuideUser.idToken,
        {createdScheduleCount: 1},
      );
      assert.equal(result.body.result.shouldShow, false);
      assert.equal(result.body.result.alreadyShown, false);
    });
    const multiGuideUser = await signUpAnonymous();
    await bootstrapAnonymous(multiGuideUser);
    await seedPersonalSchedules(env, multiGuideUser.localId, 3, "multi-guide");
    await scenario("first multi-day save shows one guide", async () => {
      const result = await callFunction(
        "claimFirstLessonGuide",
        multiGuideUser.idToken,
        {createdScheduleCount: 3},
      );
      assert.equal(result.body.result.shouldShow, true);
    });
    const beginnerMemberUser = await signUpAnonymous();
    await bootstrapAnonymous(beginnerMemberUser);
    await scenario("Beginner customer card create is rejected", async () => {
      const result = await create(beginnerMemberUser, 900);
      assert.equal(result.body.error.message, "amateur_required");
    });

    const reconcileUser = await signUpAnonymous();
    const reconcileLinked = await linkEmail(
      reconcileUser,
      "tier-reconcile@example.com",
    );
    await env.withSecurityRulesDisabled(async (admin) => {
      await setDoc(
        doc(admin.firestore(), "trainer_profiles", reconcileUser.localId),
        {
          trainerId: reconcileUser.localId,
          workspaceType: "personal",
          workspaceStatus: "active",
          role: "personal",
          accountState: "linked",
          isAnonymous: false,
          tier: "Beginner",
          lifetimeQualifiedMemberCount: 0,
        },
      );
    });
    await scenario("zero of two conditions keeps Beginner", async () => {
      const result = await callFunction(
        "reconcilePersonalTier",
        reconcileLinked.idToken,
      );
      assert.equal(result.body.result.completedMissionCount, 0);
      assert.equal(result.body.result.scheduleCount, 0);
      assert.equal(result.body.result.tier, "Beginner");
    });
    await env.withSecurityRulesDisabled(async (admin) => {
      await updateDoc(
        doc(admin.firestore(), "trainer_profiles", reconcileUser.localId),
        {
          realName: "Trainer",
          jobTitle: "PT Trainer",
          phone: "01099997777",
          activityRegion: "서울특별시 강남구",
          primaryActivity: "PT",
          affiliationType: "freelancer",
        },
      );
    });
    await seedPersonalSchedules(env, reconcileUser.localId, 9);
    await scenario("one of two conditions keeps Beginner", async () => {
      const result = await callFunction(
        "reconcilePersonalTier",
        reconcileLinked.idToken,
      );
      assert.equal(result.body.result.completedMissionCount, 1);
      assert.equal(result.body.result.scheduleCount, 9);
      assert.equal(result.body.result.tier, "Beginner");
    });
    const deleteBeforePromotion = await signUpAnonymous();
    await bootstrapAnonymous(deleteBeforePromotion);
    await completeTrainerProfile(deleteBeforePromotion);
    await seedPersonalSchedules(
      env,
      deleteBeforePromotion.localId,
      10,
      "delete-before-promotion",
    );
    await env.withSecurityRulesDisabled(async (admin) => {
      await deleteDoc(doc(
        admin.firestore(),
        "schedules",
        `${deleteBeforePromotion.localId}--delete-before-promotion-9`,
      ));
    });
    await scenario("ten to nine schedules before promotion stays Beginner", async () => {
      const result = await callFunction(
        "reconcilePersonalTier",
        deleteBeforePromotion.idToken,
      );
      assert.equal(result.body.result.scheduleCount, 9);
      assert.equal(result.body.result.scheduleMissionCompleted, false);
      assert.equal(result.body.result.teacherInfoCompleted, true);
      assert.equal(result.body.result.tier, "Beginner");
    });
    await seedPersonalSchedules(env, reconcileUser.localId, 10);
    await scenario("two of two conditions promote only own profile", async () => {
      const result = await callFunction(
        "reconcilePersonalTier",
        reconcileLinked.idToken,
        {uid: owner.localId},
      );
      assert.equal(result.body.result.completedMissionCount, 2);
      assert.equal(result.body.result.scheduleCount, 10);
      assert.equal(result.body.result.tier, "Amateur");
      assert.equal(result.body.result.changed, true);
      assert.equal(result.body.result.promoted, true);
      assert.ok(result.body.result.transitionId);
      assert.equal((await profileData(env, reconcileUser.localId)).tier, "Amateur");
      assert.equal((await profileData(env, owner.localId)).tier, "Beginner");
    });
    await scenario("Amateur celebration transition is claimed once", async () => {
      const profile = await profileData(env, reconcileUser.localId);
      const first = await callFunction(
        "claimTierCelebration",
        reconcileLinked.idToken,
        {transitionId: profile.lastTierTransitionId},
      );
      const second = await callFunction(
        "claimTierCelebration",
        reconcileLinked.idToken,
        {transitionId: profile.lastTierTransitionId},
      );
      assert.equal(first.body.result.claimed, true);
      assert.equal(second.body.result.claimed, false);
      assert.equal(second.body.result.alreadyClaimed, true);
    });
    await scenario("repeated tier reconcile is idempotent", async () => {
      const before = await profileData(env, reconcileUser.localId);
      const result = await callFunction(
        "reconcilePersonalTier",
        reconcileLinked.idToken,
      );
      const after = await profileData(env, reconcileUser.localId);
      assert.equal(result.body.result.changed, false);
      assert.equal(after.tier, "Amateur");
      assert.deepEqual(after.amateurAchievedAt, before.amateurAchievedAt);
    });
    await env.withSecurityRulesDisabled(async (admin) => {
      await updateDoc(
        doc(admin.firestore(), "trainer_profiles", reconcileUser.localId),
        {tier: "Pro"},
      );
    });
    await scenario("higher tier is never downgraded", async () => {
      const result = await callFunction(
        "reconcilePersonalTier",
        reconcileLinked.idToken,
      );
      assert.equal(result.body.result.tier, "Pro");
      assert.equal(result.body.result.changed, false);
    });

    await env.withSecurityRulesDisabled(async (admin) => {
      await updateDoc(
        doc(admin.firestore(), "trainer_profiles", owner.localId),
        {
          realName: "Anonymous Trainer",
          jobTitle: "PT Trainer",
          phone: "01011112222",
          activityRegion: "서울특별시 강남구",
          primaryActivity: "PT",
          affiliationType: "freelancer",
        },
      );
    });
    await seedPersonalSchedules(env, owner.localId, 10, "anonymous");
    await scenario("anonymous complete schedule missions promote to Amateur", async () => {
      const result = await callFunction("reconcilePersonalTier", owner.idToken);
      assert.equal(result.body.result.tier, "Amateur");
      assert.equal(result.body.result.scheduleMissionCompleted, true);
      assert.equal(result.body.result.teacherInfoCompleted, true);
    });
    await scenario("missing valid member fields are rejected", async () => {
      const result = await callFunction("createManagedMember", owner.idToken, {
        idempotencyKey: "incomplete",
        name: "미완성",
      });
      assert.equal(result.body.error.status, "INVALID_ARGUMENT");
      await env.withSecurityRulesDisabled(async (admin) => {
        const snapshot = await getDocs(query(
          collection(admin.firestore(), "members"),
          where("trainerId", "==", owner.localId),
        ));
        assert.equal(snapshot.empty, true);
      });
    });

    const legacyOwner = await signUpAnonymous();
    await bootstrapAnonymous(legacyOwner);
    await promoteAnonymousToAmateur(env, legacyOwner, "legacy-create");
    const legacyPayload = memberPayload(70, "014");
    delete legacyPayload.birthDate;
    const legacyCreated = await callFunction(
      "createManagedMember",
      legacyOwner.idToken,
      legacyPayload,
    );
    await scenario("1.0.3 legacy create without birth succeeds", async () => {
      assert.equal(legacyCreated.status, 200, JSON.stringify(legacyCreated.body));
      assert.equal(legacyCreated.body.result.created, true);
      const db = context(env, legacyOwner.localId, true).firestore();
      const snapshot = await getDoc(doc(
        db,
        "members",
        legacyCreated.body.result.memberId,
      ));
      const data = snapshot.data();
      assert.equal(data.trainerId, legacyOwner.localId);
      assert.equal(data.workspaceType, "personal");
      assert.equal(data.birth, undefined);
      assert.equal(data.birthDisplay, undefined);
      assert.equal(data.birthAt, undefined);
      assert.equal(data.groupId, undefined);
      assert.equal(data.groupName, undefined);
    });
    await scenario("supplied invalid create birth is rejected", async () => {
      const rejected = await callFunction(
        "createManagedMember",
        legacyOwner.idToken,
        {...memberPayload(71, "014"), birthDate: "1990-02-30"},
      );
      assert.equal(rejected.body.error.status, "INVALID_ARGUMENT");
      const db = context(env, legacyOwner.localId, true).firestore();
      const snapshot = await getDocs(query(
        collection(db, "members"),
        where("trainerId", "==", legacyOwner.localId),
        where("workspaceType", "==", "personal"),
      ));
      assert.equal(snapshot.size, 1);
    });
    const currentPayload = memberPayload(72, "014");
    const currentCreated = await callFunction(
      "createManagedMember",
      legacyOwner.idToken,
      currentPayload,
    );
    await scenario("1.0.4 create persists canonical birth fields", async () => {
      assert.equal(currentCreated.status, 200, JSON.stringify(currentCreated.body));
      const db = context(env, legacyOwner.localId, true).firestore();
      const snapshot = await getDoc(doc(
        db,
        "members",
        currentCreated.body.result.memberId,
      ));
      const data = snapshot.data();
      assert.equal(data.birthDisplay, "1990-02-03");
      assert.equal(data.birth.toDate().toISOString(), "1990-02-03T00:00:00.000Z");
      assert.equal(data.birthAt.toDate().toISOString(), "1990-02-03T00:00:00.000Z");
    });
    const fullPayload = {
      ...memberPayload(73, "014"),
      lessonType: "PT",
      totalSessions: 20,
      remainingSessions: 18,
      lessonsNotRegistered: false,
      membershipGrade: "GOLD",
      membership: {
        notRegistered: false,
        termMonths: null,
        customDays: 120,
        startAt: "2026-08-01",
        endAt: "2026-11-28",
        days: 120,
        lastRegisteredAt: "2026-08-01",
        reregisterCount: 0,
        lastReregisterAt: null,
      },
      anniversaryDate: "2026-12-25",
      anniversaryLabel: "대회",
    };
    const fullCreated = await callFunction(
      "createManagedMember",
      legacyOwner.idToken,
      fullPayload,
    );
    await scenario("full create persists grade lesson membership and anniversary", async () => {
      assert.equal(fullCreated.status, 200, JSON.stringify(fullCreated.body));
      const db = context(env, legacyOwner.localId, true).firestore();
      const memberId = fullCreated.body.result.memberId;
      const snapshot = await getDoc(doc(db, "members", memberId));
      const data = snapshot.data();
      assert.equal(data.membershipGrade, "GOLD");
      assert.equal(data.lessonType, "PT");
      assert.equal(data.totalSessions, 20);
      assert.equal(data.remainingSessions, 18);
      assert.equal(data.sessions.total, 20);
      assert.equal(data.sessions.remain, 18);
      assert.equal(data.membership.customDays, 120);
      assert.equal(data.membership.days, 120);
      assert.equal(
        data.membership.startAt.toDate().toISOString().slice(0, 10),
        "2026-08-01",
      );
      assert.equal(
        data.membership.endAt.toDate().toISOString().slice(0, 10),
        "2026-11-28",
      );
      assert.equal(data.anniversaryLabel, "대회");
      assert.equal(
        data.anniversaryDate.toDate().toISOString().slice(0, 10),
        "2026-12-25",
      );
    });
    await scenario("member grade update persists without changing membership", async () => {
      const memberId = fullCreated.body.result.memberId;
      const updated = await callFunction(
        "updateManagedMember",
        legacyOwner.idToken,
        {memberId, membershipGrade: "SILVER"},
      );
      assert.equal(updated.status, 200, JSON.stringify(updated.body));
      const db = context(env, legacyOwner.localId, true).firestore();
      const snapshot = await getDoc(doc(db, "members", memberId));
      const data = snapshot.data();
      assert.equal(data.membershipGrade, "SILVER");
      assert.equal(data.membership.customDays, 120);
      assert.equal(data.membership.days, 120);
      assert.equal(data.anniversaryLabel, "대회");
    });
    await scenario("unsupported member grade is rejected without write", async () => {
      const memberId = fullCreated.body.result.memberId;
      const rejected = await callFunction(
        "updateManagedMember",
        legacyOwner.idToken,
        {memberId, membershipGrade: "PLATINUM"},
      );
      assert.equal(rejected.body.error.status, "INVALID_ARGUMENT");
      const db = context(env, legacyOwner.localId, true).firestore();
      const snapshot = await getDoc(doc(db, "members", memberId));
      assert.equal(snapshot.data().membershipGrade, "SILVER");
    });
    await scenario("supported create grades normalize to canonical values", async () => {
      const db = context(env, legacyOwner.localId, true).firestore();
      for (const [index, grade] of [[74, "silver"], [75, "VVIP"]]) {
        const created = await callFunction(
          "createManagedMember",
          legacyOwner.idToken,
          {...memberPayload(index, "014"), membershipGrade: grade},
        );
        assert.equal(created.status, 200, JSON.stringify(created.body));
        const snapshot = await getDoc(doc(
          db,
          "members",
          created.body.result.memberId,
        ));
        assert.equal(snapshot.data().membershipGrade, grade.toUpperCase());
      }
    });
    await scenario("legacy retry does not rewrite a current member", async () => {
      const replayPayload = {...currentPayload};
      delete replayPayload.birthDate;
      const replayed = await callFunction(
        "createManagedMember",
        legacyOwner.idToken,
        replayPayload,
      );
      assert.equal(replayed.status, 200, JSON.stringify(replayed.body));
      assert.equal(replayed.body.result.created, false);
      const db = context(env, legacyOwner.localId, true).firestore();
      const snapshot = await getDoc(doc(
        db,
        "members",
        currentCreated.body.result.memberId,
      ));
      const data = snapshot.data();
      assert.equal(data.birthDisplay, "1990-02-03");
      assert.equal(data.birth.toDate().toISOString(), "1990-02-03T00:00:00.000Z");
      assert.equal(data.birthAt.toDate().toISOString(), "1990-02-03T00:00:00.000Z");
    });

    const quickOwner = await signUpAnonymous();
    await bootstrapAnonymous(quickOwner);
    await promoteAnonymousToAmateur(env, quickOwner, "quick-register");
    const quickCreated = await callFunction(
      "createManagedMember",
      quickOwner.idToken,
      {
        idempotencyKey: "quick-register-1",
        registrationMode: "quick",
        name: "Quick Register",
        phone: "010-5555-0001",
        note: "quick fixture",
        nextReservationAt: "2026-08-20",
      },
    );
    await scenario("quick registration creates an owner-scoped canonical member", async () => {
      assert.equal(quickCreated.status, 200, JSON.stringify(quickCreated.body));
      assert.equal(quickCreated.body.result.created, true);
      const db = context(env, quickOwner.localId, true).firestore();
      const memberId = quickCreated.body.result.memberId;
      const snapshot = await getDoc(doc(db, "members", memberId));
      const data = snapshot.data();
      assert.equal(data.memberId, memberId);
      assert.equal(data.trainerId, quickOwner.localId);
      assert.equal(data.workspaceType, "personal");
      assert.equal(data.managementState, "active");
      assert.equal(data.name, "Quick Register");
      assert.equal(data.phoneNormalized, "01055550001");
      assert.equal(data.gender, undefined);
      assert.equal(data.birth, undefined);
      assert.equal(data.groupId, undefined);
      assert.equal(data.groupName, undefined);
      assert.ok(data.createdAt);
      assert.equal(
        data.nextReservationAt.toDate().toISOString().slice(0, 10),
        "2026-08-20",
      );
      const ownerList = await getDocs(query(
        collection(db, "members"),
        where("trainerId", "==", quickOwner.localId),
        where("workspaceType", "==", "personal"),
      ));
      assert.equal(ownerList.docs.some((item) => item.id === memberId), true);
    });
    await scenario("unknown quick registration mode is rejected", async () => {
      const rejected = await callFunction(
        "createManagedMember",
        quickOwner.idToken,
        {
          idempotencyKey: "quick-register-invalid",
          registrationMode: "unknown",
          name: "Invalid Quick",
          phone: "010-5555-0002",
        },
      );
      assert.equal(rejected.body.error.status, "INVALID_ARGUMENT");
      assert.equal(rejected.body.error.message, "registration_mode_invalid");
    });

    const first = await create(owner, 1);
    await scenario("Amateur anonymous first valid member succeeds", async () => {
      assert.equal(first.status, 200);
      assert.equal(first.body.result.lifetimeQualifiedMemberCount, 1);
      assert.equal(first.body.result.tier, "Amateur");
    });
    const firstId = first.body.result.memberId;
    await scenario("member identity and qualification fields are server fixed", async () => {
      const db = context(env, owner.localId, true).firestore();
      const snapshot = await getDoc(doc(db, "members", firstId));
      const data = snapshot.data();
      assert.equal(data.memberId, firstId);
      assert.equal(data.trainerId, owner.localId);
      assert.equal(data.workspaceType, "personal");
      assert.equal(data.gender, "male");
      assert.equal(data.birthDisplay, "1990-02-03");
      assert.equal(data.birth.toDate().toISOString(), "1990-02-03T00:00:00.000Z");
      assert.equal(data.birthAt.toDate().toISOString(), "1990-02-03T00:00:00.000Z");
      assert.equal(data.phoneNormalized, "01000000001");
      assert.equal(data.groupId, undefined);
      assert.equal(data.groupName, undefined);
      assert.equal(data.countsTowardLifetimeQualification, true);
      assert.ok(data.qualifiedAt);
    });
    await scenario("basic fields update independently without rewriting optional state", async () => {
      const ownerDb = context(env, owner.localId, true).firestore();
      const seededMembership = {
        notRegistered: false,
        termMonths: null,
        customDays: 30,
        startAt: new Date("2026-08-01T00:00:00.000Z"),
        endAt: new Date("2026-08-30T00:00:00.000Z"),
        days: 30,
        lastRegisteredAt: new Date("2026-08-01T00:00:00.000Z"),
        reregisterCount: 2,
        lastReregisterAt: new Date("2026-08-01T00:00:00.000Z"),
      };
      await env.withSecurityRulesDisabled(async (admin) => {
        await updateDoc(doc(admin.firestore(), "members", firstId), {
          membership: seededMembership,
          anniversaryDate: new Date("2026-12-24T00:00:00.000Z"),
          anniversaryLabel: "Keep Anniversary",
        });
      });
      const updates = [
        {name: "Name Only"},
        {phone: "010-7777-0001"},
        {birthDate: "1991-03-04"},
        {gender: "female"},
        {
          name: "All Basic",
          phone: "010-7777-0002",
          birthDate: "1992-05-06",
          gender: "male",
        },
      ];
      for (const update of updates) {
        const result = await callFunction(
          "updateManagedMember",
          owner.idToken,
          {memberId: firstId, ...update},
        );
        assert.equal(result.status, 200, JSON.stringify(result.body));
        assert.equal(result.body.result.updated, true);
      }
      const snapshot = await getDoc(doc(ownerDb, "members", firstId));
      const data = snapshot.data();
      assert.equal(data.name, "All Basic");
      assert.equal(data.phoneNormalized, "01077770002");
      assert.equal(data.birthDisplay, "1992-05-06");
      assert.equal(data.gender, "male");
      assert.equal(data.membership.customDays, 30);
      assert.equal(data.membership.reregisterCount, 2);
      assert.equal(data.anniversaryLabel, "Keep Anniversary");
      const restored = await callFunction(
        "updateManagedMember",
        owner.idToken,
        {memberId: firstId, phone: memberPayload(1).phone},
      );
      assert.equal(restored.status, 200, JSON.stringify(restored.body));
    });
    await scenario("member gender and birth update persist for owner readback", async () => {
      const updated = await callFunction(
        "updateManagedMember",
        owner.idToken,
        {
          memberId: firstId,
          gender: "female",
          birthDate: "1992-02-29",
        },
      );
      assert.equal(updated.status, 200, JSON.stringify(updated.body));
      assert.equal(updated.body.result.updated, true);
      assert.equal(updated.body.result.scheduleNameSyncSucceeded, true);
      assert.equal(updated.body.result.scheduleNameUpdatedCount, 0);
      const db = context(env, owner.localId, true).firestore();
      const snapshot = await getDoc(doc(db, "members", firstId));
      const data = snapshot.data();
      assert.equal(data.gender, "female");
      assert.equal(data.birthDisplay, "1992-02-29");
      assert.equal(data.birth.toDate().toISOString(), "1992-02-29T00:00:00.000Z");
      assert.equal(data.birthAt.toDate().toISOString(), "1992-02-29T00:00:00.000Z");
    });
    await scenario("member name update synchronizes only owned personal schedules", async () => {
      const ownedScheduleIds = ["name-sync-1", "name-sync-2"];
      const foreignScheduleId = "name-sync-foreign";
      const contractId = "name-sync-contract";
      await env.withSecurityRulesDisabled(async (admin) => {
        for (const scheduleId of ownedScheduleIds) {
          await setDoc(doc(admin.firestore(), "schedules", scheduleId), {
            trainerId: owner.localId,
            workspaceType: "personal",
            memberId: firstId,
            name: "Before Name",
          });
        }
        await setDoc(doc(admin.firestore(), "schedules", foreignScheduleId), {
          trainerId: "another-owner",
          workspaceType: "personal",
          memberId: firstId,
          name: "Foreign Snapshot",
        });
        await setDoc(doc(admin.firestore(), "contracts", contractId), {
          trainerId: owner.localId,
          workspaceType: "personal",
          memberId: firstId,
          memberName: "Signed Snapshot",
          status: "signed",
        });
      });

      const updated = await callFunction(
        "updateManagedMember",
        owner.idToken,
        {memberId: firstId, name: "Updated Name"},
      );
      assert.equal(updated.status, 200, JSON.stringify(updated.body));
      assert.equal(updated.body.result.updated, true);
      assert.equal(updated.body.result.scheduleNameSyncSucceeded, true);
      assert.equal(updated.body.result.scheduleNameUpdatedCount, 2);

      await env.withSecurityRulesDisabled(async (admin) => {
        const db = admin.firestore();
        for (const scheduleId of ownedScheduleIds) {
          const snapshot = await getDoc(doc(db, "schedules", scheduleId));
          assert.equal(snapshot.data().name, "Updated Name");
        }
        const foreignSchedule = await getDoc(
          doc(db, "schedules", foreignScheduleId),
        );
        assert.equal(foreignSchedule.data().name, "Foreign Snapshot");
        const contract = await getDoc(doc(db, "contracts", contractId));
        assert.equal(contract.data().memberName, "Signed Snapshot");
      });

      await env.withSecurityRulesDisabled(async (admin) => {
        await updateDoc(
          doc(admin.firestore(), "schedules", ownedScheduleIds[0]),
          {name: "Stale Again"},
        );
      });
      const retried = await callFunction(
        "updateManagedMember",
        owner.idToken,
        {memberId: firstId, note: "retry schedule sync"},
      );
      assert.equal(retried.status, 200, JSON.stringify(retried.body));
      assert.equal(retried.body.result.scheduleNameSyncSucceeded, true);
      assert.equal(retried.body.result.scheduleNameUpdatedCount, 1);
      await env.withSecurityRulesDisabled(async (admin) => {
        const snapshot = await getDoc(
          doc(admin.firestore(), "schedules", ownedScheduleIds[0]),
        );
        assert.equal(snapshot.data().name, "Updated Name");
      });
    });
    await scenario("invalid birth update is rejected without changing stored data", async () => {
      const rejected = await callFunction(
        "updateManagedMember",
        owner.idToken,
        {memberId: firstId, birthDate: "1992-02-30"},
      );
      assert.equal(rejected.body.error.status, "INVALID_ARGUMENT");
      const db = context(env, owner.localId, true).firestore();
      const snapshot = await getDoc(doc(db, "members", firstId));
      assert.equal(snapshot.data().birthDisplay, "1992-02-29");
    });
    await scenario("membership month presets persist canonical dates and days", async () => {
      for (const termMonths of [1, 3, 6, 12]) {
        const days = termMonths * 30;
        const startAt = "2026-08-01";
        const endAt = endDateForInclusiveDays(startAt, days);
        const updated = await callFunction(
          "updateManagedMember",
          owner.idToken,
          {
            memberId: firstId,
            membership: {
              notRegistered: false,
              termMonths,
              customDays: null,
              startAt,
              endAt,
              days,
              lastRegisteredAt: startAt,
              reregisterCount: 0,
              lastReregisterAt: null,
            },
          },
        );
        assert.equal(updated.status, 200, JSON.stringify(updated.body));
        const db = context(env, owner.localId, true).firestore();
        const snapshot = await getDoc(doc(db, "members", firstId));
        const membership = snapshot.data().membership;
        assert.equal(membership.termMonths, termMonths);
        assert.equal(membership.customDays, null);
        assert.equal(membership.days, days);
        assert.equal(membership.startAt.toDate().toISOString().slice(0, 10), startAt);
        assert.equal(membership.endAt.toDate().toISOString().slice(0, 10), endAt);
      }
    });
    await scenario("membership custom 120 days persist after update", async () => {
      const startAt = "2026-08-15";
      const days = 120;
      const endAt = endDateForInclusiveDays(startAt, days);
      const updated = await callFunction(
        "updateManagedMember",
        owner.idToken,
        {
          memberId: firstId,
          membership: {
            notRegistered: false,
            termMonths: null,
            customDays: days,
            startAt,
            endAt,
            days,
            lastRegisteredAt: startAt,
            reregisterCount: 1,
            lastReregisterAt: startAt,
          },
        },
      );
      assert.equal(updated.status, 200, JSON.stringify(updated.body));
      const db = context(env, owner.localId, true).firestore();
      const snapshot = await getDoc(doc(db, "members", firstId));
      const membership = snapshot.data().membership;
      assert.equal(membership.termMonths, null);
      assert.equal(membership.customDays, 120);
      assert.equal(membership.days, 120);
      assert.equal(membership.startAt.toDate().toISOString().slice(0, 10), startAt);
      assert.equal(membership.endAt.toDate().toISOString().slice(0, 10), endAt);
    });
    await scenario("membership direct start and end persist canonical period", async () => {
      const startAt = "2026-10-10";
      const endAt = "2026-11-25";
      const days = 47;
      const updated = await callFunction(
        "updateManagedMember",
        owner.idToken,
        {
          memberId: firstId,
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
        },
      );
      assert.equal(updated.status, 200, JSON.stringify(updated.body));
      const db = context(env, owner.localId, true).firestore();
      const snapshot = await getDoc(doc(db, "members", firstId));
      const membership = snapshot.data().membership;
      assert.equal(membership.customDays, days);
      assert.equal(membership.days, days);
      assert.equal(membership.startAt.toDate().toISOString().slice(0, 10), startAt);
      assert.equal(membership.endAt.toDate().toISOString().slice(0, 10), endAt);
    });
    await scenario("D-DAY persists and removes canonical fields", async () => {
      const saved = await callFunction(
        "updateManagedMember",
        owner.idToken,
        {
          memberId: firstId,
          anniversaryDate: "2026-12-24",
          anniversaryLabel: "테스트 기념일",
        },
      );
      assert.equal(saved.status, 200, JSON.stringify(saved.body));
      let db = context(env, owner.localId, true).firestore();
      let snapshot = await getDoc(doc(db, "members", firstId));
      assert.equal(
        snapshot.data().anniversaryDate.toDate().toISOString().slice(0, 10),
        "2026-12-24",
      );
      assert.equal(snapshot.data().anniversaryLabel, "테스트 기념일");
      const removed = await callFunction(
        "updateManagedMember",
        owner.idToken,
        {
          memberId: firstId,
          anniversaryDate: null,
          anniversaryLabel: null,
        },
      );
      assert.equal(removed.status, 200, JSON.stringify(removed.body));
      db = context(env, owner.localId, true).firestore();
      snapshot = await getDoc(doc(db, "members", firstId));
      assert.equal(snapshot.data().anniversaryDate, null);
      assert.equal(snapshot.data().anniversaryLabel, null);
    });
    const deleteOwner = await signUpAnonymous();
    await bootstrapAnonymous(deleteOwner);
    await promoteAnonymousToAmateur(env, deleteOwner, "canonical-delete");
    const deleteCandidate = await create(deleteOwner, 1, "012");
    const deleteCandidateId = deleteCandidate.body.result.memberId;
    await scenario("other trainer cannot canonically delete member", async () => {
      const rejected = await callFunction(
        "transitionManagedMemberState",
        owner.idToken,
        {memberId: deleteCandidateId, nextState: "deleted"},
      );
      assert.equal(rejected.body.error.status, "PERMISSION_DENIED");
    });
    await scenario("owner canonical delete persists pending delete markers", async () => {
      const deleted = await callFunction(
        "transitionManagedMemberState",
        deleteOwner.idToken,
        {memberId: deleteCandidateId, nextState: "deleted"},
      );
      assert.equal(deleted.status, 200, JSON.stringify(deleted.body));
      const db = context(env, deleteOwner.localId, true).firestore();
      const snapshot = await getDoc(doc(db, "members", deleteCandidateId));
      const data = snapshot.data();
      assert.equal(data.managementState, "deleted");
      assert.equal(data.isDeleted, true);
      assert.equal(data.deleteStatus, "pending_delete");
      assert.ok(data.deletedAt);
      assert.ok(data.deleteScheduledAt);
    });
    await scenario("create identity fields cannot be supplied by the client", async () => {
      const rejected = await callFunction(
        "createManagedMember",
        owner.idToken,
        {
          ...memberPayload(90),
          idempotencyKey: "identity-injection",
          trainerId: "other-trainer",
          workspaceType: "legacy",
        },
      );
      assert.equal(rejected.body.error.status, "INVALID_ARGUMENT");
    });
    await scenario("update identity fields cannot be supplied by the client", async () => {
      const rejected = await callFunction(
        "updateManagedMember",
        owner.idToken,
        {
          memberId: firstId,
          trainerId: "other-trainer",
          workspaceType: "legacy",
        },
      );
      assert.equal(rejected.body.error.status, "INVALID_ARGUMENT");
      assert.equal(rejected.body.error.message, "unknown_fields");
      assert.equal(rejected.body.error.details, undefined);
    });
    await scenario("other trainer cannot update an owned member", async () => {
      const other = await signUpAnonymous();
      await bootstrapAnonymous(other);
      const rejected = await callFunction(
        "updateManagedMember",
        other.idToken,
        {memberId: firstId, gender: "male"},
      );
      assert.equal(rejected.body.error.status, "PERMISSION_DENIED");
    });
    const duplicateUpdateTrainer = await signUpAnonymous();
    await bootstrapAnonymous(duplicateUpdateTrainer);
    await promoteAnonymousToAmateur(
      env,
      duplicateUpdateTrainer,
      "duplicate-update",
    );
    const duplicateUpdateFirst = await callFunction(
      "createManagedMember",
      duplicateUpdateTrainer.idToken,
      memberPayload(1, "013"),
    );
    const duplicateUpdateSecond = await callFunction(
      "createManagedMember",
      duplicateUpdateTrainer.idToken,
      memberPayload(2, "013"),
    );
    const duplicateUpdateFirstId = duplicateUpdateFirst.body.result.memberId;
    await scenario("member update keeps its own phone without duplicate error", async () => {
      const updated = await callFunction(
        "updateManagedMember",
        duplicateUpdateTrainer.idToken,
        {
          memberId: duplicateUpdateFirstId,
          phone: memberPayload(1, "013").phone,
        },
      );
      assert.equal(updated.status, 200, JSON.stringify(updated.body));
      assert.equal(updated.body.result.updated, true);
    });
    await scenario("member update rejects another owned member phone", async () => {
      const rejected = await callFunction(
        "updateManagedMember",
        duplicateUpdateTrainer.idToken,
        {
          memberId: duplicateUpdateFirstId,
          phone: memberPayload(2, "013").phone,
        },
      );
      assert.equal(rejected.body.error.status, "ALREADY_EXISTS");
      const db = context(
        env,
        duplicateUpdateTrainer.localId,
        true,
      ).firestore();
      const snapshot = await getDoc(
        doc(db, "members", duplicateUpdateFirstId),
      );
      assert.equal(snapshot.data().phoneNormalized, memberPayload(1, "013").phone);
      assert.notEqual(
        duplicateUpdateFirstId,
        duplicateUpdateSecond.body.result.memberId,
      );
    });
    await scenario("member consent persists, reads back, and resets canonically", async () => {
      const agreed = await callFunction(
        "updateManagedMemberConsent",
        owner.idToken,
        {memberId: firstId, agreed: true},
      );
      assert.equal(agreed.status, 200, JSON.stringify(agreed.body));
      let agreedAt;
      await env.withSecurityRulesDisabled(async (admin) => {
        const snapshot = await getDoc(doc(admin.firestore(), "members", firstId));
        const data = snapshot.data();
        assert.equal(data.trainingLogConsentAgreed, true);
        assert.ok(data.trainingLogConsentAgreedAt);
        agreedAt = data.trainingLogConsentAgreedAt.toMillis();
      });
      const retried = await callFunction(
        "updateManagedMemberConsent",
        owner.idToken,
        {memberId: firstId, agreed: true},
      );
      assert.equal(retried.status, 200, JSON.stringify(retried.body));
      await env.withSecurityRulesDisabled(async (admin) => {
        const snapshot = await getDoc(doc(admin.firestore(), "members", firstId));
        assert.equal(
          snapshot.data().trainingLogConsentAgreedAt.toMillis(),
          agreedAt,
        );
      });
      const reset = await callFunction(
        "updateManagedMemberConsent",
        owner.idToken,
        {memberId: firstId, agreed: false},
      );
      assert.equal(reset.status, 200, JSON.stringify(reset.body));
      await env.withSecurityRulesDisabled(async (admin) => {
        const snapshot = await getDoc(doc(admin.firestore(), "members", firstId));
        const data = snapshot.data();
        assert.equal(data.trainingLogConsentAgreed, false);
        assert.equal(data.trainingLogConsentAgreedAt, undefined);
      });
    });
    await scenario("other uid cannot change member consent", async () => {
      const other = await signUpAnonymous();
      await bootstrapAnonymous(other);
      const result = await callFunction(
        "updateManagedMemberConsent",
        other.idToken,
        {memberId: firstId, agreed: true},
      );
      assert.equal(result.body.error.status, "PERMISSION_DENIED");
    });
    await scenario("deleted member consent cannot be changed", async () => {
      const result = await callFunction(
        "updateManagedMemberConsent",
        deleteOwner.idToken,
        {memberId: deleteCandidateId, agreed: true},
      );
      assert.equal(result.body.error.status, "FAILED_PRECONDITION");
      await env.withSecurityRulesDisabled(async (admin) => {
        const snapshot = await getDoc(
          doc(admin.firestore(), "members", deleteCandidateId),
        );
        const data = snapshot.data();
        assert.equal(data.trainingLogConsentAgreed, undefined);
        assert.equal(data.trainingLogConsentAgreedAt, undefined);
      });
    });
    await scenario("personal profile preferences are user scoped", async () => {
      const updated = await callFunction(
        "updatePersonalTrainerProfile",
        owner.idToken,
        {
          memberDefaultGroupLabel: "MY STUDIO",
          customLessonTypes: ["그룹레슨", "발레핏", "자이로토닉"],
        },
      );
      assert.equal(updated.status, 200, JSON.stringify(updated.body));
      const profile = await profileData(env, owner.localId);
      assert.equal(profile.memberDefaultGroupLabel, "MY STUDIO");
      assert.deepEqual(
        profile.customLessonTypes,
        ["그룹레슨", "발레핏", "자이로토닉"],
      );
    });
    await scenario("anonymous owner can read only own member", async () => {
      const db = context(env, owner.localId, true).firestore();
      await assertSucceeds(getDoc(doc(db, "members", firstId)));
      const other = await signUpAnonymous();
      await assertFails(
        getDoc(doc(context(env, other.localId, true).firestore(), "members", firstId)),
      );
    });
    await scenario("anonymous owner-filter query succeeds", async () => {
      const db = context(env, owner.localId, true).firestore();
      const snapshot = await assertSucceeds(
        getDocs(query(
          collection(db, "members"),
          where("trainerId", "==", owner.localId),
          where("workspaceType", "==", "personal"),
        )),
      );
      assert.equal(snapshot.size, 1);
      const phoneSnapshot = await assertSucceeds(
        getDocs(query(
          collection(db, "members"),
          where("trainerId", "==", owner.localId),
          where("workspaceType", "==", "personal"),
          where("phoneNormalized", "==", memberPayload(1).phone),
        )),
      );
      assert.equal(phoneSnapshot.size, 1);
      await assertFails(getDocs(query(
        collection(db, "members"),
        where("phoneNormalized", "==", memberPayload(1).phone),
      )));
      await assertFails(getDocs(collection(db, "members")));
    });
    await scenario("client member create update delete remain rejected", async () => {
      const db = context(env, owner.localId, true).firestore();
      await assertFails(setDoc(doc(db, "members", "client"), {}));
      await assertFails(updateDoc(doc(db, "members", firstId), {tier: "Pro"}));
      await assertFails(deleteDoc(doc(db, "members", firstId)));
    });

    const duplicate = await callFunction(
      "createManagedMember",
      owner.idToken,
      {...memberPayload(1), idempotencyKey: "duplicate-phone"},
    );
    await scenario("duplicate normalized phone is rejected and not counted", async () => {
      assert.equal(duplicate.body.error.status, "ALREADY_EXISTS");
      assert.equal(duplicate.body.error.message, "duplicate_member");
      assert.equal((await profileData(env, owner.localId)).lifetimeQualifiedMemberCount, 1);
    });
    await scenario("same normalized phone is allowed for another trainer", async () => {
      const otherTrainer = await signUpAnonymous();
      await bootstrapAnonymous(otherTrainer);
      await promoteAnonymousToAmateur(env, otherTrainer, "other-trainer");
      const result = await callFunction(
        "createManagedMember",
        otherTrainer.idToken,
        {...memberPayload(1), idempotencyKey: "other-trainer-same-phone"},
      );
      assert.equal(result.status, 200, JSON.stringify(result.body));
      const otherMemberId = result.body.result.memberId;
      await env.withSecurityRulesDisabled(async (admin) => {
        const snapshot = await getDoc(
          doc(admin.firestore(), "members", otherMemberId),
        );
        assert.equal(snapshot.data().trainerId, otherTrainer.localId);
        assert.equal(snapshot.data().phoneNormalized, "01000000001");
      });
    });
    await scenario("concurrent duplicate creates count only one member", async () => {
      const concurrentTrainer = await signUpAnonymous();
      await bootstrapAnonymous(concurrentTrainer);
      await promoteAnonymousToAmateur(env, concurrentTrainer, "concurrent");
      const payload = {
        ...memberPayload(1, "012"),
        phone: "012-0000-0001",
      };
      const [left, right] = await Promise.all([
        callFunction(
          "createManagedMember",
          concurrentTrainer.idToken,
          {...payload, idempotencyKey: "concurrent-left"},
        ),
        callFunction(
          "createManagedMember",
          concurrentTrainer.idToken,
          {...payload, idempotencyKey: "concurrent-right"},
        ),
      ]);
      const successes = [left, right].filter((result) => result.status === 200);
      const duplicates = [left, right].filter(
        (result) => result.body.error?.message === "duplicate_member",
      );
      assert.equal(successes.length, 1);
      assert.equal(duplicates.length, 1);
      assert.equal(
        (await profileData(env, concurrentTrainer.localId))
          .lifetimeQualifiedMemberCount,
        1,
      );
    });
    await scenario("same idempotency key does not duplicate member or count", async () => {
      const repeated = await create(owner, 1);
      assert.equal(repeated.body.result.created, false);
      assert.equal(repeated.body.result.lifetimeQualifiedMemberCount, 1);
    });

    const thresholdMemberIds = [];
    for (let index = 2; index <= 10; index += 1) {
      const result = await create(owner, index);
      assert.equal(result.status, 200, JSON.stringify(result.body));
      if (index >= 9) thresholdMemberIds.push(result.body.result.memberId);
    }
    await scenario("anonymous tenth valid member succeeds", async () => {
      const profile = await profileData(env, owner.localId);
      assert.equal(profile.lifetimeQualifiedMemberCount, 10);
      assert.equal(profile.tier, "Amateur");
    });
    const blockedEleventh = await create(owner, 11);
    await scenario("anonymous eleventh valid member requires account link", async () => {
      assert.equal(blockedEleventh.body.error.message, "account_link_required");
      assert.equal((await profileData(env, owner.localId)).lifetimeQualifiedMemberCount, 10);
    });
    await scenario("active eight with two cleaned historical members still requires account link", async () => {
      for (const memberId of thresholdMemberIds) {
        const deleted = await callFunction(
          "transitionManagedMemberState",
          owner.idToken,
          {memberId, nextState: "deleted"},
        );
        assert.equal(deleted.status, 200, JSON.stringify(deleted.body));
      }
      await env.withSecurityRulesDisabled(async (admin) => {
        for (const memberId of thresholdMemberIds) {
          await deleteDoc(doc(admin.firestore(), "members", memberId));
        }
      });
      const profile = await profileData(env, owner.localId);
      assert.equal(profile.managedMemberCount, 8);
      assert.equal(profile.lifetimeQualifiedMemberCount, 10);
      const blocked = await create(owner, 11);
      assert.equal(blocked.body.error.message, "account_link_required");
      await env.withSecurityRulesDisabled(async (admin) => {
        const snapshot = await getDocs(query(
          collection(admin.firestore(), "members"),
          where("trainerId", "==", owner.localId),
          where("workspaceType", "==", "personal"),
        ));
        assert.equal(snapshot.size, 8);
      });
    });

    const completeWhileAnonymous = await completeTrainerProfile(owner);
    await scenario("teacher profile can complete without promoting anonymous", async () => {
      assert.equal(completeWhileAnonymous.body.result.profileCompleted, true);
      assert.equal(completeWhileAnonymous.body.result.accountLinked, false);
      assert.equal(completeWhileAnonymous.body.result.tier, "Amateur");
    });
    await scenario("intro one-line bio persists and reads back", async () => {
      const saved = await callFunction(
        "updatePersonalTrainerProfile",
        owner.idToken,
        {intro: "회원의 목표를 함께 설계하는 트레이너입니다."},
      );
      assert.equal(saved.status, 200, JSON.stringify(saved.body));
      const profile = await profileData(env, owner.localId);
      assert.equal(profile.intro, "회원의 목표를 함께 설계하는 트레이너입니다.");
    });
    await scenario("intro one-line bio update overwrites the previous value", async () => {
      const saved = await callFunction(
        "updatePersonalTrainerProfile",
        owner.idToken,
        {intro: "운동을 넘어 건강한 일상을 함께 만듭니다."},
      );
      assert.equal(saved.status, 200, JSON.stringify(saved.body));
      const profile = await profileData(env, owner.localId);
      assert.equal(profile.intro, "운동을 넘어 건강한 일상을 함께 만듭니다.");
    });
    await scenario("sponsorship does not affect tier", async () => {
      await env.withSecurityRulesDisabled(async (admin) => {
        await updateDoc(
          doc(admin.firestore(), "trainer_profiles", owner.localId),
          {isSponsor: true},
        );
      });
      const result = await completeTrainerProfile(owner);
      assert.equal(result.body.result.tier, "Amateur");
    });

    const linkedOwner = await linkEmail(owner, "owner-tier@example.com");
    const transition = await callFunction(
      "transitionAnonymousProfileToLinked",
      linkedOwner.idToken,
    );
    await scenario("link preserves uid and promotes ten complete members to Amateur", async () => {
      assert.equal(linkedOwner.localId, owner.localId);
      assert.equal(transition.body.result.profile.tier, "Amateur");
      assert.equal((await profileData(env, owner.localId)).tier, "Amateur");
    });
    const eleventh = await create(linkedOwner, 11);
    await scenario("linked complete trainer can create eleventh member", async () => {
      assert.equal(eleventh.status, 200, JSON.stringify(eleventh.body));
      assert.equal(eleventh.body.result.lifetimeQualifiedMemberCount, 11);
    });

    for (let index = 12; index <= 30; index += 1) {
      const result = await create(linkedOwner, index);
      assert.equal(result.status, 200, JSON.stringify(result.body));
    }
    await scenario("thirty unique valid members promote to Semi-Pro", async () => {
      const profile = await profileData(env, owner.localId);
      assert.equal(profile.lifetimeQualifiedMemberCount, 30);
      assert.equal(profile.tier, "Semi-Pro");
    });
    for (let index = 31; index <= 50; index += 1) {
      const result = await create(linkedOwner, index);
      assert.equal(result.status, 200, JSON.stringify(result.body));
    }
    await scenario("fifty unique valid members promote to Pro", async () => {
      const profile = await profileData(env, owner.localId);
      assert.equal(profile.lifetimeQualifiedMemberCount, 50);
      assert.equal(profile.tier, "Pro");
    });

    await scenario("dormant and expired states never lower lifetime tier", async () => {
      const dormant = await callFunction(
        "transitionManagedMemberState",
        linkedOwner.idToken,
        {memberId: firstId, nextState: "dormant"},
      );
      assert.equal(dormant.status, 200);
      const second = await create(linkedOwner, 51);
      const expired = await callFunction(
        "transitionManagedMemberState",
        linkedOwner.idToken,
        {memberId: second.body.result.memberId, nextState: "expired"},
      );
      assert.equal(expired.status, 200);
      const profile = await profileData(env, owner.localId);
      assert.equal(profile.lifetimeQualifiedMemberCount, 51);
      assert.equal(profile.tier, "Pro");
    });

    await scenario("legacy member is never exposed or attributed", async () => {
      await env.withSecurityRulesDisabled(async (admin) => {
        await setDoc(doc(admin.firestore(), "members", "legacy-member"), {
          name: "legacy",
        });
      });
      const db = context(env, owner.localId, false).firestore();
      await assertFails(getDoc(doc(db, "members", "legacy-member")));
      const profile = await profileData(env, owner.localId);
      assert.equal(profile.lifetimeQualifiedMemberCount, 51);
    });
    for (const name of ["schedules", "training_logs", "contracts"]) {
      await scenario(`${name} rules remain closed`, async () => {
        const db = context(env, owner.localId, false).firestore();
        await assertFails(getDoc(doc(db, name, "closed")));
      });
    }

    assert.equal(passed, 70);
    process.stdout.write("All 70 anonymous member and tier scenarios passed.\n");
  } finally {
    await env.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
