const assert = require("node:assert/strict");
const fs = require("node:fs");
const {initializeTestEnvironment} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc} = require("firebase/firestore");
const {callCallable} = require("./functions_client.cjs");

const projectId = process.env.NICKNAME_TEST_PROJECT_ID ||
  "demo-mtf-nickname-onboarding";
const authHost = process.env.NICKNAME_TEST_AUTH_HOST || "127.0.0.1:9099";
const functionsHost = process.env.NICKNAME_TEST_FUNCTIONS_HOST ||
  "127.0.0.1:5001";
const firestorePort = Number(process.env.NICKNAME_TEST_FIRESTORE_PORT || 8080);
let passed = 0;

async function scenario(name, action) {
  await action();
  passed += 1;
  process.stdout.write(`PASS ${passed}: ${name}\n`);
}

async function signUp({email} = {}) {
  const body = email
    ? {email, password: "test-password-123", returnSecureToken: true}
    : {returnSecureToken: true};
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify(body),
    },
  );
  const text = await response.text();
  assert.equal(response.ok, true, text);
  return JSON.parse(text);
}

async function call(name, idToken, data = {}) {
  return callCallable({
    projectId,
    name,
    idToken,
    data,
    host: functionsHost,
  });
}

async function readAsAdmin(testEnv, uid) {
  let snapshot;
  await testEnv.withSecurityRulesDisabled(async (context) => {
    snapshot = await getDoc(
      doc(context.firestore(), "trainer_profiles", uid),
    );
  });
  return snapshot;
}

async function seedProtectedFields(testEnv, uid) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(context.firestore(), "trainer_profiles", uid),
      {
        profileCompleted: false,
        trainerProfileCompleted: false,
        tier: "Beginner",
        lifetimeMemberCount: 7,
        validMemberCount: 4,
        platformAdmin: false,
        legacyDataAccessApproved: false,
      },
      {merge: true},
    );
  });
}

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: "127.0.0.1",
      port: firestorePort,
      rules: fs.readFileSync("firestore.rules", "utf8"),
    },
  });

  try {
    await testEnv.clearFirestore();

    await scenario("unauthenticated call is rejected", async () => {
      const result = await call("completeNicknameOnboarding", null, {
        nickname: "레온",
      });
      assert.equal(result.body.error.status, "UNAUTHENTICATED");
    });

    const anonymous = await signUp();
    await call("bootstrapAnonymousBeginnerProfile", anonymous.idToken);
    await seedProtectedFields(testEnv, anonymous.localId);

    await scenario("uid payload is rejected", async () => {
      const result = await call(
        "completeNicknameOnboarding",
        anonymous.idToken,
        {nickname: "레온", uid: "different-uid"},
      );
      assert.equal(result.body.error.status, "INVALID_ARGUMENT");
      assert.equal(result.body.error.message, "unknown_fields");
    });
    await scenario("blank nickname is rejected", async () => {
      const result = await call(
        "completeNicknameOnboarding",
        anonymous.idToken,
        {nickname: "   "},
      );
      assert.equal(result.body.error.status, "INVALID_ARGUMENT");
      assert.equal(result.body.error.message, "nickname_empty");
    });
    await scenario("nickname longer than six characters is rejected", async () => {
      const result = await call(
        "completeNicknameOnboarding",
        anonymous.idToken,
        {nickname: "일이삼사오육칠"},
      );
      assert.equal(result.body.error.status, "INVALID_ARGUMENT");
      assert.equal(result.body.error.message, "nickname_too_long");
    });

    const first = await call(
      "completeNicknameOnboarding",
      anonymous.idToken,
      {nickname: "  레온쌤  "},
    );
    const firstSnapshot = await readAsAdmin(testEnv, anonymous.localId);
    const firstData = firstSnapshot.data();
    const firstCompletedAt = firstData.onboardingCompletedAt.toMillis();
    await scenario("anonymous owner completes own nickname onboarding", async () => {
      assert.equal(first.status, 200);
      assert.deepEqual(first.body.result, {
        completed: true,
        changed: true,
        nickname: "레온쌤",
      });
      assert.equal(firstData.nickname, "레온쌤");
      assert.equal(firstData.onboardingCompleted, true);
      assert.ok(firstData.onboardingCompletedAt);
      assert.ok(firstData.updatedAt);
    });
    await scenario("protected profile and tier fields are unchanged", async () => {
      assert.equal(firstData.profileCompleted, false);
      assert.equal(firstData.trainerProfileCompleted, false);
      assert.equal(firstData.tier, "Beginner");
      assert.equal(firstData.lifetimeMemberCount, 7);
      assert.equal(firstData.validMemberCount, 4);
      assert.equal(firstData.platformAdmin, false);
      assert.equal(firstData.legacyDataAccessApproved, false);
    });

    const profileUpdate = await call(
      "updatePersonalTrainerProfile",
      anonymous.idToken,
      {
        nickname: "새닉네임",
        realName: "실명테스트",
        displayName: "실명테스트",
        jobTitle: "트레이너",
        phone: "01012341234",
        activityRegion: "서울특별시 강남구",
        primaryActivity: "PT",
        affiliationType: "freelancer",
        contractTrainerNameSource: "displayName",
        contractTrainerCustomName: "",
      },
    );
    const updatedProfile =
      (await readAsAdmin(testEnv, anonymous.localId)).data();
    await scenario("personal profile update atomically saves names and job", async () => {
      assert.equal(profileUpdate.status, 200);
      assert.equal(updatedProfile.nickname, "새닉네임");
      assert.equal(updatedProfile.realName, "실명테스트");
      assert.equal(updatedProfile.jobTitle, "트레이너");
      assert.equal(updatedProfile.primaryActivity, "PT");
      assert.equal(updatedProfile.affiliationType, "freelancer");
      assert.equal(updatedProfile.contractTrainerNameSource, "displayName");
      assert.equal(updatedProfile.contractTrainerName, "새닉네임");
      assert.equal(updatedProfile.lifetimeMemberCount, 7);
      assert.equal(updatedProfile.validMemberCount, 4);
      assert.equal(updatedProfile.platformAdmin, false);
    });

    const beforeInvalid = updatedProfile.displayName;
    const invalidProfileUpdate = await call(
      "updatePersonalTrainerProfile",
      anonymous.idToken,
      {nickname: "일이삼사오육칠", displayName: "변경되면안됨"},
    );
    const afterInvalid =
      (await readAsAdmin(testEnv, anonymous.localId)).data();
    await scenario("invalid nickname leaves the entire profile update unchanged", async () => {
      assert.equal(invalidProfileUpdate.body.error.status, "INVALID_ARGUMENT");
      assert.equal(afterInvalid.displayName, beforeInvalid);
      assert.equal(afterInvalid.nickname, "새닉네임");
    });

    const second = await call(
      "completeNicknameOnboarding",
      anonymous.idToken,
      {nickname: "새닉네임"},
    );
    const secondData = (await readAsAdmin(testEnv, anonymous.localId)).data();
    await scenario("same request is idempotent", async () => {
      assert.equal(second.body.result.completed, true);
      assert.equal(second.body.result.changed, false);
      assert.equal(
        secondData.onboardingCompletedAt.toMillis(),
        firstCompletedAt,
      );
    });

    const linked = await signUp({email: "linked-nickname@example.com"});
    await call("bootstrapTrainerProfile", linked.idToken);
    await seedProtectedFields(testEnv, linked.localId);
    const linkedResult = await call(
      "completeNicknameOnboarding",
      linked.idToken,
      {nickname: "링크쌤"},
    );
    const linkedData = (await readAsAdmin(testEnv, linked.localId)).data();
    await scenario("linked owner completes own nickname onboarding", async () => {
      assert.equal(linkedResult.status, 200);
      assert.equal(linkedData.nickname, "링크쌤");
      assert.equal(linkedData.profileCompleted, false);
      assert.equal(linkedData.tier, "Beginner");
    });

    const linkedProfileUpdate = await call(
      "updatePersonalTrainerProfile",
      linked.idToken,
      {
        nickname: "연결쌤",
        realName: "연결실명",
        displayName: "연결실명",
        jobTitle: "강사",
        phone: "01098769876",
        activityRegion: "부산광역시 해운대구",
        primaryActivity: "필라테스",
        affiliationType: "center",
        contractTrainerNameSource: "realName",
        contractTrainerCustomName: "",
      },
    );
    const linkedProfile = (await readAsAdmin(testEnv, linked.localId)).data();
    await scenario("linked profile atomically saves names and job", async () => {
      assert.equal(linkedProfileUpdate.status, 200);
      assert.equal(linkedProfile.nickname, "연결쌤");
      assert.equal(linkedProfile.realName, "연결실명");
      assert.equal(linkedProfile.jobTitle, "강사");
      assert.equal(linkedProfile.primaryActivity, "필라테스");
      assert.equal(linkedProfile.affiliationType, "center");
      assert.equal(linkedProfile.contractTrainerNameSource, "realName");
      assert.equal(linkedProfile.contractTrainerName, "연결실명");
      assert.equal(linkedProfile.tier, "Beginner");
    });

    const multiRegionUpdate = await call(
      "updatePersonalTrainerProfile",
      linked.idToken,
      {
        nameEn: "Myeong Gu Nam",
        activityRegion: "다른 값은 대표 지역으로 정규화",
        activityRegions: [
          "서울특별시 강남구",
          "서울특별시 송파구",
          "경기도 성남시",
        ],
      },
    );
    const multiRegionProfile =
      (await readAsAdmin(testEnv, linked.localId)).data();
    await scenario("three activity regions save and primary mirrors first", async () => {
      assert.equal(multiRegionUpdate.status, 200);
      assert.deepEqual(multiRegionProfile.activityRegions, [
        "서울특별시 강남구",
        "서울특별시 송파구",
        "경기도 성남시",
      ]);
      assert.equal(multiRegionProfile.activityRegion, "서울특별시 강남구");
      assert.equal(multiRegionProfile.nameEn, "Myeong Gu Nam");
    });

    for (const [label, payload, message] of [
      ["duplicate activity region", {
        activityRegions: ["서울특별시 강남구", "서울특별시 강남구"],
      }, "activity_regions_invalid"],
      ["fourth activity region", {
        activityRegions: [
          "서울특별시 강남구", "서울특별시 송파구",
          "경기도 성남시", "제주특별자치도 제주시",
        ],
      }, "activity_regions_invalid"],
      ["invalid english name", {nameEn: "Myeong 구"}, "name_en_invalid"],
    ]) {
      const result = await call(
        "updatePersonalTrainerProfile",
        linked.idToken,
        payload,
      );
      await scenario(`${label} is rejected`, async () => {
        assert.equal(result.body.error.status, "INVALID_ARGUMENT");
        assert.equal(result.body.error.message, message);
      });
    }

    await call("updatePersonalTrainerProfile", linked.idToken, {
      affiliationType: "freelancer",
      jobTitle: "",
      realName: "연결실명",
      primaryActivity: "필라테스",
      activityRegions: ["부산광역시 해운대구"],
    });
    const freelanceProfile =
      (await readAsAdmin(testEnv, linked.localId)).data();
    await scenario("freelancer profile completes without job title", async () => {
      assert.equal(freelanceProfile.profileCompleted, true);
      assert.equal(freelanceProfile.jobTitle, "");
    });

    await call("updatePersonalTrainerProfile", linked.idToken, {
      affiliationType: "center",
      jobTitle: "",
    });
    const centerWithoutJob =
      (await readAsAdmin(testEnv, linked.localId)).data();
    await scenario("center profile remains incomplete without job title", async () => {
      assert.equal(centerWithoutJob.profileCompleted, false);
      assert.equal(centerWithoutJob.tier, "Beginner");
    });

    const manualSourceUpdate = await call(
      "updatePersonalTrainerProfile",
      linked.idToken,
      {
        nickname: "바뀐닉",
        realName: "바뀐실명",
        displayName: "바뀐실명",
        jobTitle: "대표",
        primaryActivity: "요가",
        contractTrainerNameSource: "manual",
        contractTrainerCustomName: "계약담당자",
      },
    );
    const manualProfile = (await readAsAdmin(testEnv, linked.localId)).data();
    await scenario("manual contract source survives nickname and real name changes", async () => {
      assert.equal(manualSourceUpdate.status, 200);
      assert.equal(manualProfile.nickname, "바뀐닉");
      assert.equal(manualProfile.realName, "바뀐실명");
      assert.equal(manualProfile.jobTitle, "대표");
      assert.equal(manualProfile.primaryActivity, "요가");
      assert.equal(manualProfile.contractTrainerNameSource, "manual");
      assert.equal(manualProfile.contractTrainerCustomName, "계약담당자");
      assert.equal(manualProfile.contractTrainerName, "계약담당자");
    });

    const missingSelectedName = await call(
      "updatePersonalTrainerProfile",
      linked.idToken,
      {
        nickname: "",
        realName: "실명있음",
        displayName: "실명있음",
        contractTrainerNameSource: "displayName",
        contractTrainerCustomName: "",
      },
    );
    const afterMissingSelectedName =
      (await readAsAdmin(testEnv, linked.localId)).data();
    await scenario("empty selected nickname is rejected without switching source", async () => {
      assert.equal(missingSelectedName.body.error.status, "INVALID_ARGUMENT");
      assert.equal(afterMissingSelectedName.contractTrainerNameSource, "manual");
      assert.equal(afterMissingSelectedName.contractTrainerName, "계약담당자");
    });

    const missing = await signUp();
    await scenario("missing profile is failed-precondition", async () => {
      const result = await call(
        "completeNicknameOnboarding",
        missing.idToken,
        {nickname: "없는프로필"},
      );
      assert.equal(result.body.error.status, "FAILED_PRECONDITION");
      assert.equal(result.body.error.message, "profile_not_found");
    });

    await scenario("another uid profile is never modified", async () => {
      const linkedAfter = (await readAsAdmin(testEnv, linked.localId)).data();
      assert.equal(linkedAfter.nickname, "바뀐닉");
      assert.equal(linkedAfter.onboardingCompleted, true);
    });

    await scenario("only onboarding fields changed on anonymous profile", async () => {
      const after = (await readAsAdmin(testEnv, anonymous.localId)).data();
      assert.equal(after.trainerId, anonymous.localId);
      assert.equal(after.workspaceType, "personal");
      assert.equal(after.role, "personal");
      assert.equal(after.managedMemberLimit, 10);
      assert.equal(after.managedMemberCount, 0);
    });

    assert.equal(passed, 22);
    process.stdout.write("All 22 nickname/profile emulator scenarios passed.\n");
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
