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
  writeBatch,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} = require("firebase/firestore");

const projectId = "demo-mtf-personal-schedules";
let passed = 0;

async function scenario(name, action) {
  await action();
  passed += 1;
  process.stdout.write(`PASS ${passed}: ${name}\n`);
}

function context(env, uid, anonymous = true) {
  return env.authenticatedContext(uid, {
    firebase: {sign_in_provider: anonymous ? "anonymous" : "password"},
  }).firestore();
}

function scheduleData(id, uid, start, overrides = {}) {
  const end = new Date(start.getTime() + 50 * 60 * 1000);
  const date = start.toISOString().slice(0, 10);
  const time = start.toISOString().slice(11, 16);
  return {
    scheduleId: id,
    trainerId: uid,
    workspaceType: "personal",
    schemaVersion: 1,
    startAt: Timestamp.fromDate(start),
    endAt: Timestamp.fromDate(end),
    dateKey: date,
    slotKey: `${date}T${time}`,
    name: "회원",
    type: "PT",
    status: "scheduled",
    memberId: "",
    phone: "",
    remainingSessions: null,
    totalSessions: null,
    memo: "",
    typeColorHex: "#7C3AED",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
    ...overrides,
  };
}

function scheduleId(uid, suffix) {
  return `${uid}--${suffix}`;
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
  const start = new Date("2026-07-20T05:00:00.000Z");
  try {
    await env.clearFirestore();
    const owner = context(env, "trainer-a");
    const linked = context(env, "trainer-linked", false);
    const other = context(env, "trainer-b");

    await scenario("unauthenticated create is denied", async () => {
      const db = env.unauthenticatedContext().firestore();
      const id = scheduleId("trainer-a", "unauth");
      await assertFails(setDoc(doc(db, "schedules", id),
        scheduleData(id, "trainer-a", start)));
    });
    await scenario("anonymous owner can create and read personal schedule", async () => {
      const id = scheduleId("trainer-a", "anonymous-a");
      await assertSucceeds(setDoc(doc(owner, "schedules", id),
        scheduleData(id, "trainer-a", start)));
      await assertSucceeds(getDoc(doc(owner, "schedules", id)));
    });
    await scenario("linked owner can create and read personal schedule", async () => {
      const id = scheduleId("trainer-linked", "linked-a");
      await assertSucceeds(setDoc(doc(linked, "schedules", id),
        scheduleData(id, "trainer-linked", start)));
      await assertSucceeds(getDoc(doc(linked, "schedules", id)));
    });
    await scenario("owner and workspace range query succeeds", async () => {
      const result = await assertSucceeds(getDocs(query(
        collection(owner, "schedules"),
        where("trainerId", "==", "trainer-a"),
        where("workspaceType", "==", "personal"),
        where("startAt", ">=", Timestamp.fromDate(new Date("2026-07-20"))),
        where("startAt", "<", Timestamp.fromDate(new Date("2026-07-27"))),
      )));
      assert.equal(result.docs.some((item) =>
        item.id === scheduleId("trainer-a", "anonymous-a")), true);
    });
    await scenario("owner-filterless root query is denied", async () => {
      await assertFails(getDocs(collection(owner, "schedules")));
    });
    await scenario("another uid cannot read schedule", async () => {
      await assertFails(getDoc(doc(other, "schedules",
        scheduleId("trainer-a", "anonymous-a"))));
    });
    await scenario("same time schedules for two trainers use separate documents", async () => {
      const rightId = scheduleId("trainer-b", "same-time-b");
      await assertSucceeds(setDoc(doc(other, "schedules", rightId),
        scheduleData(rightId, "trainer-b", start)));
      const left = await getDoc(doc(owner, "schedules",
        scheduleId("trainer-a", "anonymous-a")));
      const right = await getDoc(doc(other, "schedules", rightId));
      assert.equal(left.exists() && right.exists(), true);
      assert.notEqual(left.id, right.id);
    });
    await scenario("ownerless legacy schedule is excluded from personal access", async () => {
      await env.withSecurityRulesDisabled(async (admin) => {
        await setDoc(doc(admin.firestore(), "schedules", "legacy"), {
          startAt: Timestamp.fromDate(start), name: "legacy",
        });
      });
      await assertFails(getDoc(doc(owner, "schedules", "legacy")));
    });
    await scenario("owner can update mutable schedule fields", async () => {
      await assertSucceeds(updateDoc(doc(owner, "schedules",
        scheduleId("trainer-a", "anonymous-a")), {
        name: "수정",
        updatedAt: serverTimestamp(),
      }));
    });
    await scenario("move keeps document id and updates time atomically", async () => {
      const moved = new Date("2026-07-20T06:00:00.000Z");
      const id = scheduleId("trainer-a", "anonymous-a");
      await assertSucceeds(updateDoc(doc(owner, "schedules", id), {
        startAt: Timestamp.fromDate(moved),
        endAt: Timestamp.fromDate(new Date(moved.getTime() + 50 * 60 * 1000)),
        dateKey: "2026-07-20",
        slotKey: "2026-07-20T06:00",
        updatedAt: serverTimestamp(),
      }));
      assert.equal((await getDoc(doc(owner, "schedules", id))).id, id);
    });
    await scenario("another uid cannot update or delete", async () => {
      const id = scheduleId("trainer-a", "anonymous-a");
      await assertFails(updateDoc(doc(other, "schedules", id), {
        name: "침범", updatedAt: serverTimestamp(),
      }));
      await assertFails(deleteDoc(doc(other, "schedules", id)));
    });
    await scenario("trainerId mutation is denied", async () => {
      await assertFails(updateDoc(doc(owner, "schedules",
        scheduleId("trainer-a", "anonymous-a")), {
        trainerId: "trainer-b", updatedAt: serverTimestamp(),
      }));
    });
    await scenario("workspaceType mutation is denied", async () => {
      await assertFails(updateDoc(doc(owner, "schedules",
        scheduleId("trainer-a", "anonymous-a")), {
        workspaceType: "legacy", updatedAt: serverTimestamp(),
      }));
    });
    await scenario("invalid end before start is denied", async () => {
      const id = scheduleId("trainer-a", "invalid-time");
      await assertFails(setDoc(doc(owner, "schedules", id),
        scheduleData(id, "trainer-a", start, {
          endAt: Timestamp.fromDate(new Date(start.getTime() - 1000)),
        })));
    });
    await scenario("owned personal member can be linked", async () => {
      await env.withSecurityRulesDisabled(async (admin) => {
        await setDoc(doc(admin.firestore(), "members", "owned-member"), {
          trainerId: "trainer-a", workspaceType: "personal",
          managementState: "active",
        });
      });
      const id = scheduleId("trainer-a", "owned-link");
      await assertSucceeds(setDoc(doc(owner, "schedules", id),
        scheduleData(id, "trainer-a", start, {
          memberId: "owned-member",
        })));
    });
    await scenario("another trainer member link is denied", async () => {
      await env.withSecurityRulesDisabled(async (admin) => {
        await setDoc(doc(admin.firestore(), "members", "other-member"), {
          trainerId: "trainer-b", workspaceType: "personal",
          managementState: "active",
        });
      });
      const id = scheduleId("trainer-a", "other-link");
      await assertFails(setDoc(doc(owner, "schedules", id),
        scheduleData(id, "trainer-a", start, {
          memberId: "other-member",
        })));
    });
    await scenario("confirmed schedule update and delete are denied", async () => {
      await env.withSecurityRulesDisabled(async (admin) => {
        const id = scheduleId("trainer-a", "confirmed");
        await setDoc(doc(admin.firestore(), "schedules", id), {
          ...scheduleData(id, "trainer-a", start),
          createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
          lessonConfirmed: true,
        });
      });
      const id = scheduleId("trainer-a", "confirmed");
      await assertFails(updateDoc(doc(owner, "schedules", id), {
        name: "변경", updatedAt: serverTimestamp(),
      }));
      await assertFails(deleteDoc(doc(owner, "schedules", id)));
    });
    await scenario("owner can delete unconfirmed own schedule", async () => {
      await assertSucceeds(deleteDoc(doc(owner, "schedules",
        scheduleId("trainer-a", "owned-link"))));
    });
    await scenario("unscoped personal document id is denied", async () => {
      await assertFails(setDoc(doc(owner, "schedules", "unscoped"),
        scheduleData("unscoped", "trainer-a", start)));
    });
    await scenario("another uid cannot create in owner path", async () => {
      const id = scheduleId("trainer-a", "forged-create");
      await assertFails(setDoc(doc(other, "schedules", id),
        scheduleData(id, "trainer-a", start)));
    });
    await scenario("home legacy-compatible fields are allowed for owner", async () => {
      const id = scheduleId("trainer-a", "home-fields");
      await assertSucceeds(setDoc(doc(owner, "schedules", id),
        scheduleData(id, "trainer-a", start, {
          day: "화", time: "14:00", endTime: "14:50",
          typeName: "PT", typeId: "pt", attended: false,
        })));
    });
    await scenario("copyMany keeps source and creates target atomically", async () => {
      const sourceId = scheduleId("trainer-a", "copy-source");
      const targetId = scheduleId("trainer-a", "copy-target");
      await assertSucceeds(setDoc(doc(owner, "schedules", sourceId),
        scheduleData(sourceId, "trainer-a", start)));
      const batch = writeBatch(owner);
      batch.update(doc(owner, "schedules", sourceId), {
        memo: "원본 유지", updatedAt: serverTimestamp(),
      });
      const nextDay = new Date(start.getTime() + 24 * 60 * 60 * 1000);
      batch.set(doc(owner, "schedules", targetId),
        scheduleData(targetId, "trainer-a", nextDay));
      await assertSucceeds(batch.commit());
      assert.equal((await getDoc(doc(owner, "schedules", sourceId))).exists(), true);
      assert.equal((await getDoc(doc(owner, "schedules", targetId))).exists(), true);
    });
    await scenario("move batch creates target and deletes source", async () => {
      const sourceId = scheduleId("trainer-a", "move-source");
      const targetId = scheduleId("trainer-a", "move-target");
      await assertSucceeds(setDoc(doc(owner, "schedules", sourceId),
        scheduleData(sourceId, "trainer-a", start)));
      const batch = writeBatch(owner);
      const nextDay = new Date(start.getTime() + 24 * 60 * 60 * 1000);
      batch.set(doc(owner, "schedules", targetId),
        scheduleData(targetId, "trainer-a", nextDay));
      batch.delete(doc(owner, "schedules", sourceId));
      await assertSucceeds(batch.commit());
      const deletedSource = await assertSucceeds(
        getDoc(doc(owner, "schedules", sourceId)));
      assert.equal(deletedSource.exists(), false);
      assert.equal((await getDoc(doc(owner, "schedules", targetId))).exists(), true);
    });
    await scenario("one denied write rolls back entire batch", async () => {
      const goodId = scheduleId("trainer-a", "rollback-good");
      const badId = scheduleId("trainer-b", "rollback-bad");
      const batch = writeBatch(owner);
      batch.set(doc(owner, "schedules", goodId),
        scheduleData(goodId, "trainer-a", start));
      batch.set(doc(owner, "schedules", badId),
        scheduleData(badId, "trainer-b", start));
      await assertFails(batch.commit());
      const rolledBack = await assertSucceeds(
        getDoc(doc(owner, "schedules", goodId)));
      assert.equal(rolledBack.exists(), false);
    });
    for (const path of ["training_logs", "contracts"]) {
      await scenario(`${path} personal access remains denied`, async () => {
        await assertFails(getDoc(doc(owner, path, "closed")));
      });
    }

    assert.equal(passed, 26);
    process.stdout.write("All 26 personal schedule rules scenarios passed.\n");
  } finally {
    await env.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
