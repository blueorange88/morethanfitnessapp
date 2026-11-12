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
  setDoc,
  updateDoc,
} = require("firebase/firestore");
const {callCallable} = require("./functions_client.cjs");

const projectId = process.env.TAXONOMY_TEST_PROJECT_ID ||
  "demo-mtf-personal-taxonomy";
const authHost = process.env.TAXONOMY_TEST_AUTH_HOST || "127.0.0.1:9099";
const functionsHost = process.env.TAXONOMY_TEST_FUNCTIONS_HOST ||
  "127.0.0.1:5001";
const firestorePort = Number(process.env.TAXONOMY_TEST_FIRESTORE_PORT || 8080);
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

async function callFunction(name, idToken, data = {}) {
  return callCallable({projectId, name, idToken, data, host: functionsHost});
}

async function bootstrap(user) {
  const result = await callFunction(
    "bootstrapAnonymousBeginnerProfile",
    user.idToken,
  );
  assert.equal(result.status, 200, JSON.stringify(result.body));
}

async function setTier(env, uid, tier) {
  await env.withSecurityRulesDisabled(async (admin) => {
    await updateDoc(doc(admin.firestore(), "trainer_profiles", uid), {
      tier,
      earnedTier: tier,
    });
  });
}

function memberPayload(index, overrides = {}) {
  return {
    idempotencyKey: `taxonomy-member-${index}`,
    name: `Taxonomy Member ${index}`,
    gender: index % 2 === 0 ? "female" : "male",
    birthDate: "1990-02-03",
    phone: `01088${String(index).padStart(6, "0")}`,
    ...overrides,
  };
}

function ownerContext(env, user) {
  return env.authenticatedContext(user.localId, {
    firebase: {sign_in_provider: "anonymous"},
  }).firestore();
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
    const owner = await signUpAnonymous();
    const other = await signUpAnonymous();
    await bootstrap(owner);
    await bootstrap(other);

    await scenario("Beginner cannot create a personal group", async () => {
      const rejected = await callFunction(
        "createPersonalGroup",
        owner.idToken,
        {idempotencyKey: "beginner-group", name: "오전 회원"},
      );
      assert.equal(rejected.body.error.status, "FAILED_PRECONDITION");
      assert.equal(rejected.body.error.message, "amateur_required");
    });

    await setTier(env, owner.localId, "Amateur");
    const firstGroupResponse = await callFunction(
      "createPersonalGroup",
      owner.idToken,
      {idempotencyKey: "group-morning", name: "  오전  회원  "},
    );
    const firstGroupId = firstGroupResponse.body.result.personalGroupId;
    await scenario("Amateur creates normalized owner group", async () => {
      assert.equal(firstGroupResponse.status, 200, JSON.stringify(firstGroupResponse.body));
      assert.equal(firstGroupResponse.body.result.created, true);
      const snapshot = await getDoc(doc(
        ownerContext(env, owner),
        "trainer_profiles",
        owner.localId,
        "personal_groups",
        firstGroupId,
      ));
      const data = snapshot.data();
      assert.equal(data.name, "오전 회원");
      assert.equal(data.normalizedName, "오전 회원");
      assert.equal(data.schemaVersion, 1);
      assert.ok(data.createdAt);
      assert.ok(data.updatedAt);
    });

    await scenario("group create retry is idempotent", async () => {
      const replayed = await callFunction(
        "createPersonalGroup",
        owner.idToken,
        {idempotencyKey: "group-morning", name: "오전 회원"},
      );
      assert.equal(replayed.status, 200, JSON.stringify(replayed.body));
      assert.equal(replayed.body.result.created, false);
      assert.equal(replayed.body.result.personalGroupId, firstGroupId);
    });

    await scenario("normalized duplicate group name is rejected", async () => {
      const rejected = await callFunction(
        "createPersonalGroup",
        owner.idToken,
        {idempotencyKey: "group-duplicate", name: "오전   회원"},
      );
      assert.equal(rejected.body.error.status, "ALREADY_EXISTS");
      assert.equal(rejected.body.error.message, "duplicate_group_name");
    });

    await scenario("default group label cannot be duplicated", async () => {
      const rejected = await callFunction(
        "createPersonalGroup",
        owner.idToken,
        {idempotencyKey: "default-duplicate", name: "more than gym"},
      );
      assert.equal(rejected.body.error.status, "ALREADY_EXISTS");
      assert.equal(rejected.body.error.message, "duplicate_group_name");
    });

    const secondGroupResponse = await callFunction(
      "createPersonalGroup",
      owner.idToken,
      {idempotencyKey: "group-evening", name: "저녁 회원"},
    );
    const secondGroupId = secondGroupResponse.body.result.personalGroupId;

    await scenario("owner can read groups while other owner cannot", async () => {
      const ownerDb = ownerContext(env, owner);
      const otherDb = ownerContext(env, other);
      await assertSucceeds(getDocs(collection(
        ownerDb,
        "trainer_profiles",
        owner.localId,
        "personal_groups",
      )));
      await assertFails(getDocs(collection(
        otherDb,
        "trainer_profiles",
        owner.localId,
        "personal_groups",
      )));
    });

    await scenario("client direct group writes remain denied", async () => {
      const db = ownerContext(env, owner);
      const path = doc(
        db,
        "trainer_profiles",
        owner.localId,
        "personal_groups",
        firstGroupId,
      );
      await assertFails(setDoc(doc(
        db,
        "trainer_profiles",
        owner.localId,
        "personal_groups",
        "client-group",
      ), {name: "client"}));
      await assertFails(updateDoc(path, {name: "client"}));
      await assertFails(deleteDoc(path));
    });

    await scenario("Amateur cannot create a personal tag", async () => {
      const rejected = await callFunction(
        "createPersonalTag",
        owner.idToken,
        {idempotencyKey: "amateur-tag", name: "VIP"},
      );
      assert.equal(rejected.body.error.status, "FAILED_PRECONDITION");
      assert.equal(rejected.body.error.message, "semi_pro_required");
    });

    await setTier(env, owner.localId, "Semi-Pro");
    const vipResponse = await callFunction(
      "createPersonalTag",
      owner.idToken,
      {idempotencyKey: "tag-vip", name: "VIP"},
    );
    const vipTagId = vipResponse.body.result.personalTagId;
    const dietResponse = await callFunction(
      "createPersonalTag",
      owner.idToken,
      {idempotencyKey: "tag-diet", name: "다이어트"},
    );
    const dietTagId = dietResponse.body.result.personalTagId;

    await scenario("Semi-Pro creates tags with canonical schema", async () => {
      assert.equal(vipResponse.status, 200, JSON.stringify(vipResponse.body));
      const snapshot = await getDoc(doc(
        ownerContext(env, owner),
        "trainer_profiles",
        owner.localId,
        "personal_tags",
        vipTagId,
      ));
      const data = snapshot.data();
      assert.equal(data.name, "VIP");
      assert.equal(data.normalizedName, "vip");
      assert.equal(data.schemaVersion, 1);
    });

    await scenario("normalized duplicate tag name is rejected", async () => {
      const rejected = await callFunction(
        "createPersonalTag",
        owner.idToken,
        {idempotencyKey: "tag-vip-duplicate", name: " vip "},
      );
      assert.equal(rejected.body.error.status, "ALREADY_EXISTS");
      assert.equal(rejected.body.error.message, "duplicate_tag_name");
    });

    await scenario("owner can read tags while direct writes remain denied", async () => {
      const ownerDb = ownerContext(env, owner);
      const otherDb = ownerContext(env, other);
      const tagPath = doc(
        ownerDb,
        "trainer_profiles",
        owner.localId,
        "personal_tags",
        vipTagId,
      );
      await assertSucceeds(getDoc(tagPath));
      await assertFails(getDoc(doc(
        otherDb,
        "trainer_profiles",
        owner.localId,
        "personal_tags",
        vipTagId,
      )));
      await assertFails(updateDoc(tagPath, {name: "client"}));
      await assertFails(deleteDoc(tagPath));
    });

    await setTier(env, owner.localId, "Amateur");
    await scenario("Amateur cannot rename or delete personal tags", async () => {
      const renameRejected = await callFunction(
        "renamePersonalTag",
        owner.idToken,
        {personalTagId: vipTagId, name: "VIP renamed"},
      );
      assert.equal(renameRejected.body.error.status, "FAILED_PRECONDITION");
      assert.equal(renameRejected.body.error.message, "semi_pro_required");
      const deleteRejected = await callFunction(
        "deletePersonalTag",
        owner.idToken,
        {personalTagId: vipTagId},
      );
      assert.equal(deleteRejected.body.error.status, "FAILED_PRECONDITION");
      assert.equal(deleteRejected.body.error.message, "semi_pro_required");
    });
    await setTier(env, owner.localId, "Semi-Pro");

    const createdMember = await callFunction(
      "createManagedMember",
      owner.idToken,
      memberPayload(1, {
        personalGroupId: firstGroupId,
        personalTagIds: [dietTagId, vipTagId],
      }),
    );
    const memberId = createdMember.body.result.memberId;
    await scenario("member create stores one group and multiple tags", async () => {
      assert.equal(createdMember.status, 200, JSON.stringify(createdMember.body));
      const snapshot = await getDoc(doc(ownerContext(env, owner), "members", memberId));
      const data = snapshot.data();
      assert.equal(data.personalGroupId, firstGroupId);
      assert.deepEqual(data.personalTagIds, [dietTagId, vipTagId].sort());
      assert.equal(data.groupId, undefined);
      assert.equal(data.groupName, undefined);
    });

    await scenario("group and tags can be reassigned without full member fields", async () => {
      const updated = await callFunction(
        "updateManagedMember",
        owner.idToken,
        {
          memberId,
          personalGroupId: secondGroupId,
          personalTagIds: [dietTagId],
        },
      );
      assert.equal(updated.status, 200, JSON.stringify(updated.body));
      assert.equal(updated.body.result.scheduleNameUpdatedCount, 0);
      const data = (await getDoc(
        doc(ownerContext(env, owner), "members", memberId),
      )).data();
      assert.equal(data.personalGroupId, secondGroupId);
      assert.deepEqual(data.personalTagIds, [dietTagId]);
    });

    await scenario("return to default and remove all tags deletes assignment fields", async () => {
      const updated = await callFunction(
        "updateManagedMember",
        owner.idToken,
        {memberId, personalGroupId: null, personalTagIds: []},
      );
      assert.equal(updated.status, 200, JSON.stringify(updated.body));
      const data = (await getDoc(
        doc(ownerContext(env, owner), "members", memberId),
      )).data();
      assert.equal(data.personalGroupId, undefined);
      assert.equal(data.personalTagIds, undefined);
    });

    await setTier(env, other.localId, "Amateur");
    const otherGroupResponse = await callFunction(
      "createPersonalGroup",
      other.idToken,
      {idempotencyKey: "other-group", name: "Other Group"},
    );
    const otherGroupId = otherGroupResponse.body.result.personalGroupId;
    const otherMember = await callFunction(
      "createManagedMember",
      other.idToken,
      memberPayload(2, {personalGroupId: otherGroupId}),
    );
    const otherMemberId = otherMember.body.result.memberId;

    await scenario("Amateur tag assignment is blocked by the server", async () => {
      const rejected = await callFunction(
        "updateManagedMember",
        other.idToken,
        {memberId: otherMemberId, personalTagIds: []},
      );
      assert.equal(rejected.body.error.status, "FAILED_PRECONDITION");
      assert.equal(rejected.body.error.message, "semi_pro_required");
    });

    await setTier(env, other.localId, "Semi-Pro");
    await scenario("different owner cannot rename or delete taxonomy", async () => {
      const groupRenameRejected = await callFunction(
        "renamePersonalGroup",
        other.idToken,
        {personalGroupId: firstGroupId, name: "Other rename"},
      );
      assert.equal(groupRenameRejected.body.error.status, "NOT_FOUND");
      const groupDeleteRejected = await callFunction(
        "deletePersonalGroup",
        other.idToken,
        {personalGroupId: firstGroupId},
      );
      assert.equal(groupDeleteRejected.body.error.status, "NOT_FOUND");
      const tagRenameRejected = await callFunction(
        "renamePersonalTag",
        other.idToken,
        {personalTagId: vipTagId, name: "Other rename"},
      );
      assert.equal(tagRenameRejected.body.error.status, "NOT_FOUND");
      const tagDeleteRejected = await callFunction(
        "deletePersonalTag",
        other.idToken,
        {personalTagId: vipTagId},
      );
      assert.equal(tagDeleteRejected.body.error.status, "NOT_FOUND");
    });

    await scenario("different owner group and tag ids are rejected", async () => {
      const groupRejected = await callFunction(
        "updateManagedMember",
        other.idToken,
        {memberId: otherMemberId, personalGroupId: firstGroupId},
      );
      assert.equal(groupRejected.body.error.status, "FAILED_PRECONDITION");
      assert.equal(groupRejected.body.error.message, "personal_group_not_found");
      const tagRejected = await callFunction(
        "updateManagedMember",
        other.idToken,
        {memberId: otherMemberId, personalTagIds: [vipTagId]},
      );
      assert.equal(tagRejected.body.error.status, "FAILED_PRECONDITION");
      assert.equal(tagRejected.body.error.message, "personal_tag_not_found");
    });

    await scenario("group and tag rename update only taxonomy documents", async () => {
      const renamedGroup = await callFunction(
        "renamePersonalGroup",
        owner.idToken,
        {personalGroupId: firstGroupId, name: "새벽 회원"},
      );
      const renamedTag = await callFunction(
        "renamePersonalTag",
        owner.idToken,
        {personalTagId: vipTagId, name: "VIP 고객"},
      );
      assert.equal(renamedGroup.status, 200, JSON.stringify(renamedGroup.body));
      assert.equal(renamedTag.status, 200, JSON.stringify(renamedTag.body));
      const member = (await getDoc(
        doc(ownerContext(env, owner), "members", memberId),
      )).data();
      assert.equal(member.name, "Taxonomy Member 1");
    });

    await scenario("default label rename cannot collide with custom group", async () => {
      const rejected = await callFunction(
        "updatePersonalTrainerProfile",
        owner.idToken,
        {memberDefaultGroupLabel: "새벽 회원"},
      );
      assert.equal(rejected.body.error.status, "ALREADY_EXISTS");
      assert.equal(rejected.body.error.message, "duplicate_group_name");
    });

    await callFunction(
      "updateManagedMember",
      owner.idToken,
      {
        memberId,
        personalGroupId: secondGroupId,
        personalTagIds: [dietTagId, vipTagId],
      },
    );
    await scenario("deleting used group moves members to default atomically", async () => {
      const deleted = await callFunction(
        "deletePersonalGroup",
        owner.idToken,
        {personalGroupId: secondGroupId},
      );
      assert.equal(deleted.status, 200, JSON.stringify(deleted.body));
      assert.equal(deleted.body.result.affectedMemberCount, 1);
      const db = ownerContext(env, owner);
      const member = (await getDoc(doc(db, "members", memberId))).data();
      assert.equal(member.personalGroupId, undefined);
      assert.deepEqual(member.personalTagIds, [dietTagId, vipTagId].sort());
      const group = await getDoc(doc(
        db,
        "trainer_profiles",
        owner.localId,
        "personal_groups",
        secondGroupId,
      ));
      assert.equal(group.exists(), false);
    });

    await scenario("deleting used tag removes only that tag from members", async () => {
      const deleted = await callFunction(
        "deletePersonalTag",
        owner.idToken,
        {personalTagId: vipTagId},
      );
      assert.equal(deleted.status, 200, JSON.stringify(deleted.body));
      assert.equal(deleted.body.result.affectedMemberCount, 1);
      const member = (await getDoc(
        doc(ownerContext(env, owner), "members", memberId),
      )).data();
      assert.deepEqual(member.personalTagIds, [dietTagId]);
    });

    await scenario("deleting last used tag removes the member array field", async () => {
      const deleted = await callFunction(
        "deletePersonalTag",
        owner.idToken,
        {personalTagId: dietTagId},
      );
      assert.equal(deleted.status, 200, JSON.stringify(deleted.body));
      const member = (await getDoc(
        doc(ownerContext(env, owner), "members", memberId),
      )).data();
      assert.equal(member.personalTagIds, undefined);
    });

    await scenario("empty group deletes without member writes", async () => {
      const deleted = await callFunction(
        "deletePersonalGroup",
        owner.idToken,
        {personalGroupId: firstGroupId},
      );
      assert.equal(deleted.status, 200, JSON.stringify(deleted.body));
      assert.equal(deleted.body.result.affectedMemberCount, 0);
    });

    await scenario("legacy group fields remain rejected", async () => {
      const rejected = await callFunction(
        "createManagedMember",
        owner.idToken,
        {...memberPayload(3), groupId: "legacy", groupName: "legacy"},
      );
      assert.equal(rejected.body.error.status, "INVALID_ARGUMENT");
      assert.equal(rejected.body.error.message, "unknown_fields");
    });

    process.stdout.write(`All ${passed} personal taxonomy scenarios passed.\n`);
  } finally {
    await env.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
