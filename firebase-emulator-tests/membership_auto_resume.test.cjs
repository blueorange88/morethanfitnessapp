// 정지 기간이 끝난 회원의 자동 재개(resumeDuePausedMemberships) 시나리오.
// Firestore 에뮬레이터만 필요하고, functions/lib 의 컴파일 결과를 직접 호출한다.
const assert = require("node:assert/strict");
const admin = require("../functions/node_modules/firebase-admin");
const {resumeDuePausedMemberships} = require("../functions/lib/managed_members.js");

process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || "127.0.0.1:8080";
const projectId = process.env.AUTO_RESUME_PROJECT_ID ||
  "demo-mtf-membership-pause";
admin.initializeApp({projectId});
const db = admin.firestore();
const Timestamp = admin.firestore.Timestamp;
let passed = 0;

async function scenario(name, action) {
  await action();
  passed += 1;
  process.stdout.write(`PASS ${passed}: ${name}\n`);
}

const kst = (text) => new Date(`${text}T00:00:00+09:00`);
const ts = (text) => Timestamp.fromDate(kst(text));

function pausedMember(id, overrides = {}) {
  return {
    memberId: id,
    trainerId: "trainer-1",
    workspaceType: "personal",
    memberStatus: "휴면",
    membershipStatus: "paused",
    membership: {
      status: "paused",
      startAt: ts("2026-09-01"),
      endAt: ts("2026-12-31"),
      pausedAt: ts("2026-10-13"),
      pausePlannedDays: 7,
      resumeDueAt: ts("2026-10-20"),
      pauseUsedDays: 0,
    },
    membershipPausedAt: ts("2026-10-13"),
    membershipPausePlannedDays: 7,
    membershipResumeDueAt: ts("2026-10-20"),
    membershipPauseHistory: [],
    ...overrides,
  };
}

async function main() {
  const batch = db.batch();
  const members = db.collection("members");
  batch.set(members.doc("due-today"), pausedMember("due-today"));
  batch.set(members.doc("due-tomorrow"), pausedMember("due-tomorrow", {
    membership: {
      ...pausedMember("x").membership,
      resumeDueAt: ts("2026-10-21"),
    },
    membershipResumeDueAt: ts("2026-10-21"),
  }));
  batch.set(members.doc("overdue-late"), pausedMember("overdue-late", {
    membership: {
      ...pausedMember("x").membership,
      pausedAt: ts("2026-10-10"),
      resumeDueAt: ts("2026-10-17"),
    },
    membershipPausedAt: ts("2026-10-10"),
    membershipResumeDueAt: ts("2026-10-17"),
  }));
  batch.set(members.doc("other-workspace"), pausedMember("other-workspace", {
    workspaceType: "legacy",
  }));
  batch.set(members.doc("active"), {
    memberId: "active",
    trainerId: "trainer-1",
    workspaceType: "personal",
    memberStatus: "활성",
    membershipStatus: "active",
    membership: {status: "active", endAt: ts("2026-12-31")},
  });
  await batch.commit();

  const now = new Date("2026-10-20T00:20:00+09:00");
  let first;

  await scenario("예정일이 오늘이거나 지난 회원만 재개하고 나머지는 건드리지 않는다", async () => {
    first = await resumeDuePausedMemberships(db, now);
    assert.equal(first.resumed, 2);
    const get = async (id) => (await members.doc(id).get()).data();

    const today = await get("due-today");
    assert.equal(today.membershipStatus, "active");
    assert.equal(today.memberStatus, "활성");
    assert.equal(today.membership.status, "active");

    for (const id of ["due-tomorrow", "other-workspace"]) {
      const data = await get(id);
      assert.equal(data.membershipStatus, "paused", id);
      assert.equal(data.membershipPauseHistory.length, 0, id);
    }
    const active = await get("active");
    assert.equal(active.membership.status, "active");
    assert.equal(active.membershipPauseHistory, undefined);
  });

  await scenario("실제 정지 일수는 예정 일수까지만 인정하고 종료일을 그만큼 연장한다", async () => {
    const get = async (id) => (await members.doc(id).get()).data();
    const onTime = await get("due-today");
    assert.equal(onTime.membership.pauseActualDays, 7);
    assert.equal(onTime.membershipPauseUsedDays, 7);
    assert.equal(
      onTime.membership.endAt.toDate().toISOString(),
      "2027-01-07T00:00:00.000Z",
    );
    // 10일 전에 정지(예정 7일)했는데 늦게 재개돼도 7일만 인정
    const late = await get("overdue-late");
    assert.equal(late.membership.pauseActualDays, 7);
    assert.equal(late.membershipPauseUsedDays, 7);
    assert.equal(
      late.membership.endAt.toDate().toISOString(),
      "2027-01-07T00:00:00.000Z",
    );
  });

  await scenario("이력에 자동 재개로 남고 실제 일수·연장된 종료일이 기록된다", async () => {
    const data = (await members.doc("due-today").get()).data();
    assert.equal(data.membershipPauseHistory.length, 1);
    const entry = data.membershipPauseHistory[0];
    assert.equal(entry.type, "resume");
    assert.equal(entry.source, "auto_resume");
    assert.equal(entry.actualDays, 7);
    assert.equal(entry.plannedDays, 7);
    assert.ok(entry.extendedEndAt);
  });

  await scenario("다시 실행해도 이미 재개된 회원은 또 처리하지 않는다", async () => {
    const second = await resumeDuePausedMemberships(db, now);
    assert.equal(second.resumed, 0);
    const data = (await members.doc("due-today").get()).data();
    assert.equal(data.membershipPauseHistory.length, 1);
    assert.equal(data.membershipPauseUsedDays, 7);
  });

  await scenario("다음 날이 되면 내일 예정이던 회원이 재개된다", async () => {
    const nextDay = await resumeDuePausedMemberships(
      db, new Date("2026-10-21T00:20:00+09:00"));
    assert.equal(nextDay.resumed, 1);
    const data = (await members.doc("due-tomorrow").get()).data();
    assert.equal(data.membershipStatus, "active");
    assert.equal(data.membership.pauseActualDays, 7);
  });

  process.stdout.write(`All ${passed} auto-resume scenarios passed.\n`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
