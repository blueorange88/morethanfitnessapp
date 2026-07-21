import assert from "node:assert/strict";
import {randomBytes} from "node:crypto";

import {upsertPlatformAdmin} from "../scripts/upsert_platform_admin.mjs";

class FakeAuth {
  constructor() {
    this.users = new Map();
    this.createCalls = 0;
    this.updateCalls = 0;
    this.claimCalls = 0;
  }

  async getUserByEmail(email) {
    const user = [...this.users.values()].find((item) => item.email === email);
    if (!user) throw Object.assign(new Error("not found"), {code: "auth/user-not-found"});
    return {...user};
  }

  async createUser(input) {
    this.createCalls += 1;
    const user = {uid: "generated-admin-uid", customClaims: {}, ...input};
    this.users.set(user.uid, user);
    return {...user};
  }

  async updateUser(uid, input) {
    this.updateCalls += 1;
    Object.assign(this.users.get(uid), input);
  }

  async getUser(uid) {
    return {...this.users.get(uid)};
  }

  async setCustomUserClaims(uid, claims) {
    this.claimCalls += 1;
    this.users.get(uid).customClaims = {...claims};
  }
}

class FakeFirestore {
  constructor() {
    this.documents = new Map();
    this.writeCalls = 0;
  }

  collection(name) {
    return {
      doc: (id) => ({
        path: `${name}/${id}`,
        get: async () => this.snapshot(`${name}/${id}`),
      }),
    };
  }

  snapshot(path) {
    const value = this.documents.get(path);
    return {exists: value != null, data: () => value == null ? undefined : {...value}};
  }

  async runTransaction(action) {
    await action({
      get: async (reference) => this.snapshot(reference.path),
      create: (reference, value) => {
        assert.equal(this.documents.has(reference.path), false);
        this.writeCalls += 1;
        this.documents.set(reference.path, {...value});
      },
      update: (reference, value) => {
        assert.equal(this.documents.has(reference.path), true);
        this.writeCalls += 1;
        Object.assign(this.documents.get(reference.path), value);
      },
    });
  }
}

const auth = new FakeAuth();
const firestore = new FakeFirestore();
const logs = [];
const logger = {info: (message) => logs.push(String(message))};

const dryRun = await upsertPlatformAdmin({
  auth,
  firestore,
  dryRun: true,
  logger,
});
assert.equal(dryRun.dryRun, true);
assert.equal(auth.createCalls, 0);
assert.equal(auth.claimCalls, 0);
assert.equal(firestore.writeCalls, 0);

const temporarySecret = randomBytes(18).toString("base64url");
const first = await upsertPlatformAdmin({
  auth,
  firestore,
  password: temporarySecret,
  logger,
  serverTimestamp: () => "server-time",
});
assert.equal(first.created, true);
auth.users.get(first.uid).customClaims.existingClaim = "preserved";

const second = await upsertPlatformAdmin({
  auth,
  firestore,
  password: temporarySecret,
  logger,
  serverTimestamp: () => "server-time",
});
assert.equal(second.created, false);
assert.equal(second.uid, first.uid);
assert.equal(auth.createCalls, 1);
assert.equal(auth.users.size, 1);
assert.equal(auth.users.get(first.uid).displayName, "LEON");
assert.equal(auth.users.get(first.uid).customClaims.existingClaim, "preserved");
assert.equal(auth.users.get(first.uid).customClaims.platformAdmin, true);
assert.equal(
  auth.users.get(first.uid).customClaims.legacyDataAccessApproved,
  true,
);

const profile = firestore.documents.get(`trainer_profiles/${first.uid}`);
assert.equal(profile.trainerId, first.uid);
assert.equal(profile.tier, "Beginner");
assert.equal(profile.role, "personal");
assert.equal(profile.mustChangePassword, true);
assert.equal(profile.passwordChangedAt, null);
assert.equal("legacyOwner" in profile, false);
assert.equal(logs.join("\n").includes(temporarySecret), false);

process.stdout.write("Platform administrator provisioning unit scenarios passed.\n");
