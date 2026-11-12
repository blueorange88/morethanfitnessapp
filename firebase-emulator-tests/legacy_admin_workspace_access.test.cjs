const assert = require("node:assert/strict");
const fs = require("node:fs");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  addDoc,
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} = require("firebase/firestore");
const {
  deleteObject,
  getMetadata,
  ref,
  uploadBytes,
} = require("firebase/storage");

const projectId = "demo-mtf-legacy-admin";
let passed = 0;

async function scenario(name, action) {
  await action();
  passed += 1;
  process.stdout.write(`PASS ${passed}: ${name}\n`);
}

function passwordClaims(overrides = {}) {
  return {
    email: "user@example.com",
    firebase: {sign_in_provider: "password"},
    ...overrides,
  };
}

function adminContext(env, uid = "legacy-admin", overrides = {}) {
  return env.authenticatedContext(
    uid,
    passwordClaims({
      platformAdmin: true,
      legacyDataAccessApproved: true,
      ...overrides,
    }),
  );
}

async function seed(env) {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const uid of [
      "legacy-admin",
      "platform-only",
      "legacy-only",
      "linked-user",
      "password-pending",
      "claims-removed",
    ]) {
      await setDoc(doc(db, "trainer_profiles", uid), {
        trainerId: uid,
        mustChangePassword: uid === "password-pending",
        workspaceType: "personal",
      });
    }
    await setDoc(doc(db, "members", "legacy-member"), {
      name: "legacy",
      sessions: {total: 10, remain: 8, done: 2},
    });
    await setDoc(doc(db, "members", "personal-member"), {
      name: "personal",
      trainerId: "linked-user",
      workspaceType: "personal",
    });
    await setDoc(doc(db, "schedules", "legacy-schedule"), {title: "lesson"});
    await setDoc(doc(db, "training_logs", "legacy-log"), {memo: "legacy"});
    await setDoc(doc(db, "contracts", "legacy-contract"), {status: "draft"});
    await setDoc(doc(db, "sign_requests", "private-sign"), {status: "pending"});
    await setDoc(
      doc(db, "members", "legacy-member", "lesson_ledger", "ledger-1"),
      {delta: -1},
    );
  });
}

async function main() {
  const env = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules: fs.readFileSync("firestore.rules", "utf8"),
    },
    storage: {
      host: "127.0.0.1",
      port: 9199,
      rules: fs.readFileSync("storage.rules", "utf8"),
    },
  });

  try {
    await env.clearFirestore();
    await env.clearStorage();
    await seed(env);

    const unauthDb = env.unauthenticatedContext().firestore();
    const anonymous = env.authenticatedContext("anonymous", {
      platformAdmin: true,
      legacyDataAccessApproved: true,
      firebase: {sign_in_provider: "anonymous"},
    });
    const linked = env.authenticatedContext("linked-user", passwordClaims());
    const platformOnly = env.authenticatedContext(
      "platform-only",
      passwordClaims({platformAdmin: true}),
    );
    const legacyOnly = env.authenticatedContext(
      "legacy-only",
      passwordClaims({legacyDataAccessApproved: true}),
    );
    const admin = adminContext(env);

    await scenario("unauthenticated legacy read is denied", async () => {
      await assertFails(getDoc(doc(unauthDb, "members", "legacy-member")));
    });
    await scenario("anonymous legacy read is denied", async () => {
      await assertFails(
        getDoc(doc(anonymous.firestore(), "members", "legacy-member")),
      );
    });
    await scenario("linked user legacy read is denied", async () => {
      await assertFails(
        getDoc(doc(linked.firestore(), "members", "legacy-member")),
      );
    });
    await scenario("platformAdmin-only access is denied", async () => {
      await assertFails(
        getDoc(doc(platformOnly.firestore(), "members", "legacy-member")),
      );
    });
    await scenario("legacy approval-only access is denied", async () => {
      await assertFails(
        getDoc(doc(legacyOnly.firestore(), "members", "legacy-member")),
      );
    });
    await scenario("both claims allow legacy member read", async () => {
      await assertSucceeds(
        getDoc(doc(admin.firestore(), "members", "legacy-member")),
      );
    });
    await scenario("both claims allow required legacy member write", async () => {
      await assertSucceeds(
        updateDoc(doc(admin.firestore(), "members", "legacy-member"), {
          memo: "updated",
        }),
      );
    });
    await scenario("canonical personal member owner policy is unchanged", async () => {
      await assertSucceeds(
        getDoc(doc(linked.firestore(), "members", "personal-member")),
      );
      await assertFails(
        getDoc(doc(admin.firestore(), "members", "personal-member")),
      );
    });
    await scenario("trainer_profiles owner policy is unchanged", async () => {
      await assertSucceeds(
        getDoc(doc(linked.firestore(), "trainer_profiles", "linked-user")),
      );
      await assertFails(
        getDoc(doc(admin.firestore(), "trainer_profiles", "linked-user")),
      );
    });
    await scenario("client profile create remains denied", async () => {
      await assertFails(
        setDoc(doc(linked.firestore(), "trainer_profiles", "new-profile"), {
          trainerId: "linked-user",
        }),
      );
    });
    await scenario("sign request public read remains denied", async () => {
      await assertFails(
        getDoc(doc(unauthDb, "sign_requests", "private-sign")),
      );
    });
    await scenario("legacy schedules read and write are allowed", async () => {
      await assertSucceeds(
        getDoc(doc(admin.firestore(), "schedules", "legacy-schedule")),
      );
      await assertSucceeds(
        setDoc(doc(admin.firestore(), "schedules", "new-schedule"), {
          title: "new",
        }),
      );
    });
    await scenario("legacy training logs read and write are allowed", async () => {
      await assertSucceeds(
        getDoc(doc(admin.firestore(), "training_logs", "legacy-log")),
      );
      await assertSucceeds(
        setDoc(doc(admin.firestore(), "training_logs", "new-log"), {
          memo: "new",
        }),
      );
    });
    await scenario("legacy contracts read and write are allowed", async () => {
      await assertSucceeds(
        getDoc(doc(admin.firestore(), "contracts", "legacy-contract")),
      );
      await assertSucceeds(
        updateDoc(doc(admin.firestore(), "contracts", "legacy-contract"), {
          status: "signed",
        }),
      );
    });
    await scenario("audited member subcollection access is allowed", async () => {
      await assertSucceeds(
        getDoc(
          doc(
            admin.firestore(),
            "members",
            "legacy-member",
            "lesson_ledger",
            "ledger-1",
          ),
        ),
      );
    });
    await scenario("unlisted collections remain denied", async () => {
      await assertFails(
        setDoc(doc(admin.firestore(), "unlisted_collection", "doc-1"), {
          value: true,
        }),
      );
    });
    await scenario("claim removal on a refreshed context blocks access", async () => {
      const removed = env.authenticatedContext(
        "claims-removed",
        passwordClaims(),
      );
      await assertFails(
        getDoc(doc(removed.firestore(), "members", "legacy-member")),
      );
    });
    await scenario("mustChangePassword blocks legacy access", async () => {
      const pending = adminContext(env, "password-pending");
      await assertFails(
        getDoc(doc(pending.firestore(), "members", "legacy-member")),
      );
    });
    await scenario("legacy query succeeds only for the admin context", async () => {
      await assertSucceeds(getDocs(collection(admin.firestore(), "schedules")));
      await assertFails(getDocs(collection(linked.firestore(), "schedules")));
    });
    await scenario("legacy hard delete is limited to paths that use it", async () => {
      await assertSucceeds(
        deleteDoc(doc(admin.firestore(), "schedules", "new-schedule")),
      );
      await assertFails(
        deleteDoc(doc(admin.firestore(), "contracts", "legacy-contract")),
      );
    });
    await scenario("remote re-registration public write stays denied", async () => {
      await assertFails(
        addDoc(collection(unauthDb, "re_registration_requests"), {
          memberId: "legacy-member",
        }),
      );
    });

    const jpeg = new Uint8Array([0xff, 0xd8, 0xff]);
    const png = new Uint8Array([0x89, 0x50, 0x4e, 0x47]);
    await scenario("legacy admin can upload an audited JPEG path", async () => {
      const object = ref(
        admin.storage(),
        "member_profiles/legacy-member/profile_1.jpg",
      );
      await assertSucceeds(uploadBytes(object, jpeg, {contentType: "image/jpeg"}));
      await assertSucceeds(getMetadata(object));
    });
    await scenario("mustChangePassword also blocks audited storage", async () => {
      const pending = adminContext(env, "password-pending");
      await assertFails(
        uploadBytes(
          ref(pending.storage(), "member_profiles/x/profile.jpg"),
          jpeg,
          {contentType: "image/jpeg"},
        ),
      );
    });
    await scenario("linked and anonymous storage access is denied", async () => {
      await assertFails(
        uploadBytes(
          ref(linked.storage(), "member_profiles/x/profile.jpg"),
          jpeg,
          {contentType: "image/jpeg"},
        ),
      );
      await assertFails(
        uploadBytes(
          ref(anonymous.storage(), "member_profiles/x/profile.jpg"),
          jpeg,
          {contentType: "image/jpeg"},
        ),
      );
    });
    await scenario("unlisted storage path is denied", async () => {
      await assertFails(
        uploadBytes(ref(admin.storage(), "training_media/video.mp4"), png, {
          contentType: "video/mp4",
        }),
      );
    });
    await scenario("storage content type restriction is enforced", async () => {
      await assertFails(
        uploadBytes(
          ref(admin.storage(), "member_profiles/x/not-image.png"),
          png,
          {contentType: "image/png"},
        ),
      );
    });
    await scenario("storage file name contract is enforced", async () => {
      await assertFails(
        uploadBytes(
          ref(admin.storage(), "member_profiles/x/arbitrary.jpg"),
          jpeg,
          {contentType: "image/jpeg"},
        ),
      );
    });
    await scenario("legacy admin can delete only an audited stored object", async () => {
      await assertSucceeds(
        deleteObject(
          ref(
            admin.storage(),
            "member_profiles/legacy-member/profile_1.jpg",
          ),
        ),
      );
    });

    assert.equal(passed, 28);
    process.stdout.write("All 28 legacy workspace emulator scenarios passed.\n");
  } finally {
    await env.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
