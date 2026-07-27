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
      const db = context(env, owner.localId, true).firestore();
      const snapshot = await getDoc(doc(db, "members", firstId));
      const data = snapshot.data();
      assert.equal(data.gender, "female");
      assert.equal(data.birthDisplay, "1992-02-29");
      assert.equal(data.birth.toDate().toISOString(), "1992-02-29T00:00:00.000Z");
      assert.equal(data.birthAt.toDate().toISOString(), "1992-02-29T00:00:00.000Z");
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

    for (let index = 2; index <= 10; index += 1) {
      const result = await create(owner, index);
      assert.equal(result.status, 200, JSON.stringify(result.body));
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

    const completeWhileAnonymous = await completeTrainerProfile(owner);
    await scenario("teacher profile can complete without promoting anonymous", async () => {
      assert.equal(completeWhileAnonymous.body.result.profileCompleted, true);
      assert.equal(completeWhileAnonymous.body.result.accountLinked, false);
      assert.equal(completeWhileAnonymous.body.result.tier, "Amateur");
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

    assert.equal(passed, 52);
    process.stdout.write("All 52 anonymous member and tier scenarios passed.\n");
  } finally {
    await env.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
