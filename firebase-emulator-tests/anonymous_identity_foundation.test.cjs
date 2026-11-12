const assert = require("node:assert/strict");
const fs = require("node:fs");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {deleteDoc, doc, getDoc, setDoc} = require("firebase/firestore");
const {callCallable} = require("./functions_client.cjs");

const projectId = "demo-mtf-anonymous-identity";
const authHost = "127.0.0.1:9099";
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
  return {ok: response.ok, status: response.status, body: JSON.parse(text)};
}

async function signUpAnonymous() {
  const result = await authRequest("signUp", {returnSecureToken: true});
  assert.equal(result.ok, true, JSON.stringify(result.body));
  return result.body;
}

async function signUpEmail(email) {
  const result = await authRequest("signUp", {
    email,
    password: "test-password-123",
    returnSecureToken: true,
  });
  assert.equal(result.ok, true, JSON.stringify(result.body));
  return result.body;
}

async function linkEmail(idToken, email) {
  return authRequest("update", {
    idToken,
    email,
    password: "test-password-123",
    returnSecureToken: true,
  });
}

async function callFunction(name, idToken, data = {}) {
  return callCallable({projectId, name, idToken, data});
}

function anonymousContext(testEnv, uid) {
  return testEnv.authenticatedContext(uid, {
    firebase: {sign_in_provider: "anonymous"},
  });
}

function linkedContext(testEnv, uid) {
  return testEnv.authenticatedContext(uid, {
    email: `${uid}@example.com`,
    firebase: {sign_in_provider: "password"},
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
    const anonymous = await signUpAnonymous();
    const bootstrap = await callFunction(
      "bootstrapAnonymousBeginnerProfile",
      anonymous.idToken,
      {tier: "Pro", role: "admin", managedMemberLimit: 999},
    );

    await scenario("anonymous bootstrap succeeds", async () => {
      assert.equal(bootstrap.status, 200);
      assert.equal(bootstrap.body.result.created, true);
    });
    await scenario("anonymous profile uses auth uid", async () => {
      assert.equal(bootstrap.body.result.profile.trainerId, anonymous.localId);
    });
    await scenario("anonymous profile is local Beginner", async () => {
      assert.equal(bootstrap.body.result.profile.accountState, "local");
      assert.equal(bootstrap.body.result.profile.tier, "Beginner");
      assert.equal(bootstrap.body.result.profile.isAnonymous, true);
    });
    await scenario("anonymous profile limit and counts are server fixed", async () => {
      assert.equal(bootstrap.body.result.profile.managedMemberLimit, 10);
      assert.equal(bootstrap.body.result.profile.managedMemberCount, 0);
      assert.equal(bootstrap.body.result.profile.lifetimeQualifiedMemberCount, 0);
    });

    const anonymousDb = anonymousContext(testEnv, anonymous.localId).firestore();
    const profileRef = doc(
      anonymousDb,
      "trainer_profiles",
      anonymous.localId,
    );
    const before = await getDoc(profileRef);
    const createdAt = before.data().createdAt.toMillis();
    await scenario("anonymous owner can read own profile", async () => {
      await assertSucceeds(getDoc(profileRef));
    });
    await scenario("anonymous cannot read another profile", async () => {
      await assertFails(
        getDoc(doc(anonymousDb, "trainer_profiles", "different-uid")),
      );
    });
    await scenario("unauthenticated user cannot read profile", async () => {
      await assertFails(
        getDoc(
          doc(
            testEnv.unauthenticatedContext().firestore(),
            "trainer_profiles",
            anonymous.localId,
          ),
        ),
      );
    });
    await scenario("anonymous client cannot create profile", async () => {
      await assertFails(
        setDoc(doc(anonymousDb, "trainer_profiles", "client-profile"), {}),
      );
    });
    await scenario("anonymous client cannot delete profile", async () => {
      await assertFails(deleteDoc(profileRef));
    });

    const secondBootstrap = await callFunction(
      "bootstrapAnonymousBeginnerProfile",
      anonymous.idToken,
    );
    await scenario("anonymous bootstrap is idempotent", async () => {
      assert.equal(secondBootstrap.body.result.created, false);
      const snapshot = await getDoc(profileRef);
      assert.equal(snapshot.data().createdAt.toMillis(), createdAt);
    });

    await testEnv.withSecurityRulesDisabled(async (context) => {
      await setDoc(doc(context.firestore(), "trainer_profile", "me"), {
        legacySecret: "must-not-copy",
      });
      await setDoc(
        doc(context.firestore(), "trainer_profiles", anonymous.localId),
        {organizationId: "kept-org", platformAdmin: false},
        {merge: true},
      );
    });
    await scenario("legacy profile data is not copied", async () => {
      const snapshot = await getDoc(profileRef);
      assert.equal(snapshot.data().legacySecret, undefined);
    });

    const linked = await linkEmail(
      anonymous.idToken,
      "anonymous-linked@example.com",
    );
    await scenario("email credential link succeeds and preserves uid", async () => {
      assert.equal(linked.ok, true, JSON.stringify(linked.body));
      assert.equal(linked.body.localId, anonymous.localId);
    });
    await scenario("linked token contains password provider", async () => {
      const lookup = await authRequest("lookup", {idToken: linked.body.idToken});
      assert.equal(lookup.ok, true);
      assert.equal(lookup.body.users[0].providerUserInfo[0].providerId, "password");
    });

    const transition = await callFunction(
      "transitionAnonymousProfileToLinked",
      linked.body.idToken,
    );
    await scenario("profile transitions local to linked", async () => {
      assert.equal(transition.status, 200);
      assert.equal(transition.body.result.changed, true);
      assert.equal(transition.body.result.profile.accountState, "linked");
      assert.equal(transition.body.result.profile.isAnonymous, false);
    });

    const linkedDb = linkedContext(testEnv, anonymous.localId).firestore();
    const linkedRef = doc(
      linkedDb,
      "trainer_profiles",
      anonymous.localId,
    );
    const after = await getDoc(linkedRef);
    await scenario("transition preserves tier trainerId and createdAt", async () => {
      assert.equal(after.data().tier, "Beginner");
      assert.equal(after.data().trainerId, anonymous.localId);
      assert.equal(after.data().createdAt.toMillis(), createdAt);
    });
    await scenario("transition preserves role organization and admin fields", async () => {
      assert.equal(after.data().role, "personal");
      assert.equal(after.data().organizationId, "kept-org");
      assert.equal(after.data().platformAdmin, false);
    });
    await scenario("transition preserves limit and lifetime count", async () => {
      assert.equal(after.data().managedMemberLimit, 10);
      assert.equal(after.data().lifetimeQualifiedMemberCount, 0);
    });

    const secondTransition = await callFunction(
      "transitionAnonymousProfileToLinked",
      linked.body.idToken,
    );
    await scenario("linked transition is idempotent", async () => {
      assert.equal(secondTransition.body.result.changed, false);
    });
    await scenario("linked profile cannot be overwritten by anonymous bootstrap", async () => {
      const result = await callFunction(
        "bootstrapAnonymousBeginnerProfile",
        linked.body.idToken,
      );
      assert.equal(result.body.error.status, "FAILED_PRECONDITION");
    });

    const existing = await signUpEmail("existing@example.com");
    const collisionAnonymous = await signUpAnonymous();
    const collision = await linkEmail(
      collisionAnonymous.idToken,
      "existing@example.com",
    );
    await scenario("existing email collision is rejected without merge", async () => {
      assert.equal(collision.ok, false);
      assert.match(
        collision.body.error.message,
        /EMAIL_EXISTS|CREDENTIAL_ALREADY_IN_USE/,
      );
      assert.notEqual(existing.localId, collisionAnonymous.localId);
    });
    await scenario("collision keeps original anonymous uid", async () => {
      const lookup = await authRequest("lookup", {
        idToken: collisionAnonymous.idToken,
      });
      assert.equal(lookup.ok, true);
      assert.equal(lookup.body.users[0].localId, collisionAnonymous.localId);
    });

    for (const collection of [
      "schedules",
      "training_logs",
      "contracts",
    ]) {
      await scenario(`anonymous access remains closed for ${collection}`, async () => {
        await assertFails(
          getDoc(doc(anonymousDb, collection, "not-opened")),
        );
      });
    }

    await scenario("unauthenticated anonymous bootstrap is rejected", async () => {
      const result = await callFunction(
        "bootstrapAnonymousBeginnerProfile",
        null,
      );
      assert.equal(result.body.error.status, "UNAUTHENTICATED");
    });
    await scenario("anonymous token cannot complete linked transition", async () => {
      const fresh = await signUpAnonymous();
      const result = await callFunction(
        "transitionAnonymousProfileToLinked",
        fresh.idToken,
      );
      assert.equal(result.body.error.status, "FAILED_PRECONDITION");
    });

    assert.equal(passed, 26);
    process.stdout.write("All 26 anonymous identity emulator scenarios passed.\n");
  } finally {
    await testEnv.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
