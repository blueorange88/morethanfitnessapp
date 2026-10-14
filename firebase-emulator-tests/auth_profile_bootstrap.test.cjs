const assert = require("node:assert/strict");
const fs = require("node:fs");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require("firebase/firestore");
const {callCallable} = require("./functions_client.cjs");

const projectId = process.env.PROFILE_TEST_PROJECT_ID ||
  "demo-mtf-auth-profile";
const authHost = process.env.PROFILE_TEST_AUTH_HOST || "127.0.0.1:9099";
const functionsHost = process.env.PROFILE_TEST_FUNCTIONS_HOST ||
  "127.0.0.1:5001";
const firestorePort = Number(process.env.PROFILE_TEST_FIRESTORE_PORT || 8080);

let passed = 0;

async function scenario(name, action) {
  await action();
  passed += 1;
  process.stdout.write(`PASS ${passed}: ${name}\n`);
}

async function signUp(email) {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({
        email,
        password: "test-password-123",
        returnSecureToken: true,
      }),
    },
  );
  const text = await response.text();
  assert.equal(response.ok, true, text);
  return JSON.parse(text);
}

async function signUpAnonymous() {
  const response = await fetch(
    `http://${authHost}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake`,
    {
      method: "POST",
      headers: {"content-type": "application/json"},
      body: JSON.stringify({returnSecureToken: true}),
    },
  );
  const text = await response.text();
  assert.equal(response.ok, true, text);
  return JSON.parse(text);
}

async function callBootstrap(idToken, data = {}) {
  return callCallable({
    projectId,
    name: "bootstrapTrainerProfile",
    idToken,
    data,
    host: functionsHost,
  });
}

function authContext(testEnv, uid) {
  return testEnv.authenticatedContext(uid, {
    email: `${uid}@example.com`,
    firebase: {sign_in_provider: "password"},
  });
}

function anonymousContext(testEnv, uid) {
  return testEnv.authenticatedContext(uid, {
    firebase: {sign_in_provider: "anonymous"},
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

    await scenario("unauthenticated bootstrap is rejected", async () => {
      const result = await callBootstrap(null);
      assert.equal(result.body.error.status, "UNAUTHENTICATED");
    });

    const anonymous = await signUpAnonymous();
    await scenario("anonymous bootstrap is rejected", async () => {
      const result = await callBootstrap(anonymous.idToken);
      assert.equal(result.body.error.status, "PERMISSION_DENIED");
      assert.equal(result.body.error.message, "anonymous_not_allowed");
    });

    const user = await signUp("linked@example.com");
    const first = await callBootstrap(user.idToken, {
      tier: "GrandPrix",
      role: "admin",
      organizationId: "attacker-org",
    });
    await scenario("linked user bootstrap succeeds", async () => {
      assert.equal(first.status, 200);
      assert.equal(first.body.result.created, true);
    });
    await scenario("trainerId equals auth uid", async () => {
      assert.equal(first.body.result.profile.trainerId, user.localId);
    });
    await scenario("tier is fixed to Beginner", async () => {
      assert.equal(first.body.result.profile.tier, "Beginner");
    });
    await scenario("accountState is fixed to linked", async () => {
      assert.equal(first.body.result.profile.accountState, "linked");
    });
    await scenario("workspaceType is fixed to personal", async () => {
      assert.equal(first.body.result.profile.workspaceType, "personal");
    });
    await scenario("workspaceStatus is active", async () => {
      assert.equal(first.body.result.profile.workspaceStatus, "active");
    });
    await scenario("role input is ignored and fixed to personal", async () => {
      assert.equal(first.body.result.profile.role, "personal");
    });
    await scenario("schemaVersion is fixed to 1", async () => {
      assert.equal(first.body.result.profile.schemaVersion, 1);
    });

    const ownerDb = authContext(testEnv, user.localId).firestore();
    const ownerRef = doc(ownerDb, "trainer_profiles", user.localId);
    const initialDoc = await getDoc(ownerRef);
    const initialCreatedAt = initialDoc.data().createdAt.toMillis();
    await scenario("profile document id is the auth uid", async () => {
      assert.equal(initialDoc.exists(), true);
      assert.equal(initialDoc.id, user.localId);
    });
    await scenario("server creates timestamps and no organization input", async () => {
      const data = initialDoc.data();
      assert.ok(data.createdAt);
      assert.ok(data.updatedAt);
      assert.equal("organizationId" in data, false);
    });

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await updateDoc(
        doc(context.firestore(), "trainer_profiles", user.localId),
        {displayName: "kept display name"},
      );
    });
    const second = await callBootstrap(user.idToken, {displayName: "overwrite"});
    await scenario("second bootstrap reuses the same profile", async () => {
      assert.equal(second.body.result.created, false);
      const snapshot = await getDoc(ownerRef);
      assert.equal(snapshot.data().displayName, "kept display name");
      assert.equal(snapshot.data().createdAt.toMillis(), initialCreatedAt);
    });

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "trainer_profile", "me"), {
        displayName: "legacy owner",
        legacySecret: "must-not-copy",
      });
    });
    const secondUser = await signUp("new-personal@example.com");
    await callBootstrap(secondUser.idToken);
    await scenario("legacy trainer_profile me is not copied", async () => {
      const secondDb = authContext(testEnv, secondUser.localId).firestore();
      const snapshot = await getDoc(
        doc(secondDb, "trainer_profiles", secondUser.localId),
      );
      assert.equal(snapshot.data().displayName, undefined);
      assert.equal(snapshot.data().legacySecret, undefined);
    });

    const conflictUser = await signUp("conflict@example.com");
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), "trainer_profiles", conflictUser.localId),
        {trainerId: "different-owner"},
      );
    });
    await scenario("conflicting existing profile is rejected", async () => {
      const result = await callBootstrap(conflictUser.idToken);
      assert.equal(result.body.error.status, "FAILED_PRECONDITION");
      assert.equal(result.body.error.message, "profile_conflict");
    });

    await scenario("unauthenticated profile read is rejected", async () => {
      const unauthRef = doc(
        testEnv.unauthenticatedContext().firestore(),
        "trainer_profiles",
        user.localId,
      );
      await assertFails(getDoc(unauthRef));
    });
    await scenario("anonymous owner profile read is allowed", async () => {
      const ref = doc(
        anonymousContext(testEnv, anonymous.localId).firestore(),
        "trainer_profiles",
        anonymous.localId,
      );
      await assertSucceeds(getDoc(ref));
    });
    await scenario("owner can read own profile", async () => {
      await assertSucceeds(getDoc(ownerRef));
    });
    await scenario("other user cannot read profile", async () => {
      const ref = doc(
        authContext(testEnv, secondUser.localId).firestore(),
        "trainer_profiles",
        user.localId,
      );
      await assertFails(getDoc(ref));
    });
    await scenario("client create is rejected", async () => {
      const freshRef = doc(ownerDb, "trainer_profiles", "client-created");
      await assertFails(setDoc(freshRef, {trainerId: user.localId}));
    });
    await scenario("displayName and server updatedAt update is allowed", async () => {
      await assertSucceeds(
        updateDoc(ownerRef, {
          displayName: "updated by owner",
          updatedAt: serverTimestamp(),
        }),
      );
    });

    for (const [name, field, value] of [
      ["tier", "tier", "Pro"],
      ["role", "role", "admin"],
      ["organizationId", "organizationId", "org-1"],
      ["trainerId", "trainerId", "other"],
      ["accountState", "accountState", "verified"],
      ["createdAt", "createdAt", new Date(0)],
    ]) {
      await scenario(`${name} mutation is rejected`, async () => {
        await assertFails(
          updateDoc(ownerRef, {[field]: value, updatedAt: serverTimestamp()}),
        );
      });
    }

    await scenario("client delete is rejected", async () => {
      await assertFails(deleteDoc(ownerRef));
    });
    await scenario("anonymous account cannot create a profile", async () => {
      let snapshot;
      await testEnv.withSecurityRulesDisabled(async (context) => {
        snapshot = await getDoc(
          doc(
            context.firestore(),
            "trainer_profiles",
            anonymous.localId,
          ),
        );
      });
      assert.equal(snapshot.exists(), false);
    });
    await scenario("account state and tier remain separate values", async () => {
      const snapshot = await getDoc(ownerRef);
      assert.equal(snapshot.data().accountState, "linked");
      assert.equal(snapshot.data().tier, "Beginner");
    });

    assert.equal(passed, 30);
    process.stdout.write("All 30 profile bootstrap emulator scenarios passed.\n");
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
