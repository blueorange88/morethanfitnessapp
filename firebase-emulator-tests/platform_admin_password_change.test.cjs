const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const fs = require("node:fs");
const {
  assertFails,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} = require("firebase/firestore");
const {
  createCompleteInitialPasswordChangeHandler,
} = require("../functions/lib/profile_bootstrap.js");
const {
  callCallable,
  LEGACY_FUNCTIONS_REGION,
} = require("./functions_client.cjs");

const projectId = "demo-mtf-auth-profile";
const authHost = "127.0.0.1:9099";

async function signUp({anonymous = false} = {}) {
  const body = {returnSecureToken: true};
  if (!anonymous) {
    body.email = `password-${crypto.randomUUID()}@example.com`;
    body.password = crypto.randomBytes(18).toString("base64url");
  }
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

async function callFunction(idToken) {
  return callCallable({
    projectId,
    name: "completeInitialPasswordChange",
    idToken,
    region: LEGACY_FUNCTIONS_REGION,
  });
}

async function main() {
  const testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules: fs.readFileSync("firestore.rules", "utf8"),
    },
  });
  try {
    await testEnv.clearFirestore();
    const unauthenticated = await callFunction(null);
    assert.equal(unauthenticated.body.error.status, "UNAUTHENTICATED");

    const anonymous = await signUp({anonymous: true});
    const anonymousResult = await callFunction(anonymous.idToken);
    assert.equal(anonymousResult.body.error.status, "PERMISSION_DENIED");

    const user = await signUp();
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "trainer_profiles", user.localId), {
        trainerId: user.localId,
        tier: "Beginner",
        role: "personal",
        mustChangePassword: true,
        passwordChangedAt: null,
      });
    });

    const result = await callFunction(user.idToken);
    assert.equal(result.status, 200);
    assert.equal(result.body.result.completed, true);
    assert.equal(result.body.result.changed, true);

    const ownerDb = testEnv.authenticatedContext(user.localId, {
      email: "owner@example.com",
      firebase: {sign_in_provider: "password"},
    }).firestore();
    const profileRef = doc(ownerDb, "trainer_profiles", user.localId);
    const profile = (await getDoc(profileRef)).data();
    assert.equal(profile.mustChangePassword, false);
    assert.ok(profile.passwordChangedAt);
    assert.equal(profile.tier, "Beginner");
    assert.equal(profile.role, "personal");

    const again = await callFunction(user.idToken);
    assert.equal(again.body.result.completed, true);
    assert.equal(again.body.result.changed, false);

    for (const [field, value] of [
      ["mustChangePassword", true],
      ["passwordChangedAt", serverTimestamp()],
      ["platformAdminProvisionedAt", serverTimestamp()],
      ["legacyDataAccessApproved", true],
    ]) {
      await assertFails(updateDoc(profileRef, {
        [field]: value,
        updatedAt: serverTimestamp(),
      }));
    }

    const staleHandler = createCompleteInitialPasswordChangeHandler({
      collection: () => {
        throw new Error("database must not be reached for stale auth");
      },
    });
    await assert.rejects(
      () => staleHandler({}, {
        auth: {
          uid: user.localId,
          token: {
            auth_time: Math.floor(Date.now() / 1000) - 3600,
            firebase: {sign_in_provider: "password"},
          },
        },
      }),
      (error) => error.message === "recent_auth_required",
    );

    process.stdout.write("Platform administrator password emulator scenarios passed.\n");
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
