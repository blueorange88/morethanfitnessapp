// 레슨계약서 v2 P5: PDF 등록·열람 링크·보낸 기록·열람 기록 시나리오.
// Firestore 에뮬레이터만 필요하고 PDF 저장소는 메모리로 바꿔 끼운다(Storage 규칙은 별도 테스트).
const assert = require("node:assert/strict");
const crypto = require("node:crypto");
const admin = require("../functions/node_modules/firebase-admin");
const {
  createManagePersonalContractHandler,
  createSavePersonalContractDraftHandler,
  createSignPersonalContractHandler,
} = require("../functions/lib/personal_contracts.js");
const delivery = require("../functions/lib/personal_contract_delivery.js");

const firestorePort = Number(process.env.CONTRACT_FIRESTORE_PORT || 8080);
process.env.FIRESTORE_EMULATOR_HOST =
  process.env.FIRESTORE_EMULATOR_HOST || `127.0.0.1:${firestorePort}`;
const projectId = process.env.CONTRACT_PROJECT_ID || "demo-mtf-personal-contracts";
admin.initializeApp({projectId});
const db = admin.firestore();
let passed = 0;

async function scenario(name, action) {
  await action();
  passed += 1;
  process.stdout.write(`PASS ${passed}: ${name}\n`);
}

async function expectError(promise, code, message) {
  try {
    await promise;
  } catch (error) {
    assert.equal(error.code, code, `code: ${error.code} / ${error.message}`);
    if (message != null) assert.equal(error.message, message);
    return error;
  }
  assert.fail(`expected ${code} ${message ?? ""}`);
}

// ---- 메모리 PDF 저장소 ----
const files = new Map();
const store = {
  async read(path) {
    const bytes = files.get(path);
    if (bytes == null) return null;
    if (bytes.length > delivery.MAX_PDF_BYTES) {
      throw new delivery.PdfTooLargeError("pdf_too_large");
    }
    return bytes;
  },
};

function makePdf(extra = "") {
  return Buffer.from(
    `%PDF-1.7\n1 0 obj\n<< /Type /Catalog >>\nendobj\n${extra}\ntrailer\n<< >>\n%%EOF\n`,
    "latin1",
  );
}

let clock = new Date("2026-10-21T00:00:00Z");
const save = createSavePersonalContractDraftHandler(db);
const sign = createSignPersonalContractHandler(db);
const manage = createManagePersonalContractHandler(db);
const attach = delivery.createAttachPersonalContractPdfHandler(db, store, {
  now: () => clock,
  projectId: "demo-project",
});
const view = delivery.createViewPersonalContractHandler(db, store, {
  now: () => clock,
});
const verify = delivery.createVerifyPersonalContractHandler(db);

function ctx(uid, provider = "password") {
  return {auth: {uid, token: {firebase: {sign_in_provider: provider}}}};
}

const content = {
  party: {kind: "individual", name: "김트레이너", trainerName: "김트레이너",
    phone: "010-1234-5678", place: "서울 강남구 테스트로 1", businessNo: "", logoPath: ""},
  member: {name: "홍회원", phone: "010-9999-8888", birthDate: "", email: ""},
  product: {name: "PT 10회", serviceContent: "1:1 개인 트레이닝 50분", sessionCount: 10,
    sessionMinutes: 50, paidAmount: 1000000, vatIncluded: true, listPrice: null,
    paymentMethod: "card", paymentDate: "2026-10-20", periodStart: "2026-10-20",
    periodEnd: "2027-01-20"},
  terms: {cancelDeadline: {mode: "hours_before", hours: 24}, lateNoShowMinutes: null,
    penaltyPercent: 10, refundBasis: "contract_unit", refundBusinessDays: 3,
    transfer: {policy: "conditional", feeType: "none", feeValue: 0},
    expiryExtensionClause: true, unavoidableRefundClause: false, extraTerms: ""},
};
const strokes = [[[10, 10], [20, 30], [40, 20], [60, 50], [80, 40], [90, 90],
  [100, 80], [120, 100], [140, 90], [150, 120]]];
const allDisclosure = ["amount", "refund", "validity", "cancel_noshow", "health_risk"];

async function seed() {
  const profile = (uid, tier) => db.collection("trainer_profiles").doc(uid).set({
    trainerId: uid, workspaceType: "personal", workspaceStatus: "active",
    role: "personal", accountState: "linked", isAnonymous: false, tier,
  });
  await profile("trainer-a", "Semi-Pro");
  await profile("trainer-b", "Pro");
  const member = (id, uid) => db.collection("members").doc(id).set({
    memberId: id, trainerId: uid, workspaceType: "personal", name: id,
  });
  await member("member-a", "trainer-a");
  await member("member-b", "trainer-b");
}

async function completed(key, uid = "trainer-a", memberId = "member-a") {
  const draft = await save({idempotencyKey: key, memberId, content}, ctx(uid));
  const id = draft.contractId;
  const hash = draft.contentHash;
  await sign({contractId: id, step: "disclosure", contentHash: hash,
    checkedItems: allDisclosure, strokes}, ctx(uid));
  await sign({contractId: id, step: "member", contentHash: hash,
    checkedItems: ["terms", "privacy"], strokes}, ctx(uid));
  await sign({contractId: id, step: "trainer", contentHash: hash,
    checkedItems: [], strokes}, ctx(uid));
  return {id, version: draft.version, hash};
}

function upload(uid, id, version, bytes = makePdf()) {
  const path = delivery.pdfStoragePath(uid, id, version);
  files.set(path, bytes);
  return path;
}

// 응답 흉내(express 비슷한 최소 구현)
function fakeRes() {
  const res = {statusCode: 200, headers: {}, body: null, ended: false};
  res.status = (code) => { res.statusCode = code; return res; };
  res.set = (a, b) => {
    if (typeof a === "string") res.headers[a.toLowerCase()] = b;
    else for (const [k, v] of Object.entries(a)) res.headers[k.toLowerCase()] = v;
    return res;
  };
  res.send = (body) => { res.body = body; res.ended = true; return res; };
  res.end = (body) => { res.body = body ?? null; res.ended = true; return res; };
  res.json = (body) => { res.body = body; res.ended = true; return res; };
  return res;
}

async function request(id, token, {method = "GET", ua = "Mozilla/5.0"} = {}) {
  const res = fakeRes();
  const req = {
    method,
    query: {c: id, t: token},
    get: (name) => (name.toLowerCase() === "user-agent" ? ua : undefined),
  };
  await view(req, res);
  return res;
}

async function verifyRequest(query, method = "GET") {
  const res = fakeRes();
  await verify({method, query, get: () => undefined}, res);
  return res;
}

async function deliveryOf(id) {
  return (await db.collection("personal_contracts").doc(id).get()).data().delivery;
}

async function eventTypes(id) {
  const snap = await db.collection("personal_contracts").doc(id)
    .collection("events").get();
  return snap.docs.map((d) => d.data().type);
}

async function main() {
  await seed();

  // ---------------- 순수 함수 ----------------
  await scenario("저장 경로·PDF 판별·토큰 해시·봇 판별", async () => {
    assert.equal(
      delivery.pdfStoragePath("u1", "pc_" + "a".repeat(32), 2),
      `personal_contracts/u1/pc_${"a".repeat(32)}/contract_v2.pdf`,
    );
    assert.equal(delivery.isPdfBuffer(makePdf()), true);
    assert.equal(delivery.isPdfBuffer(Buffer.from("hello world, not a pdf at all")), false);
    assert.equal(delivery.isPdfBuffer(Buffer.from("%PDF-1.7 but no end marker here")), false);
    const token = delivery.newLinkToken();
    assert.match(token, /^[A-Za-z0-9_-]{43}$/);
    assert.notEqual(token, delivery.newLinkToken());
    assert.equal(delivery.tokenMatches(token, delivery.hashLinkToken(token)), true);
    assert.equal(delivery.tokenMatches(token, delivery.hashLinkToken("x".repeat(43))), false);
    assert.equal(delivery.tokenMatches(token, undefined), false);
    assert.equal(delivery.tokenMatches(token, "nothex"), false);
    assert.equal(
      delivery.viewUrl("p", "pc_1", "tok"),
      "https://asia-northeast3-p.cloudfunctions.net/viewPersonalContract?c=pc_1&t=tok",
    );
    // 링크 미리보기 봇은 열람으로 세지 않지만 카카오톡 앱 안 브라우저는 센다.
    assert.equal(delivery.isPreviewBot("facebookexternalhit/1.1;kakaotalk-scrap/1.0"), true);
    assert.equal(delivery.isPreviewBot("Slackbot-LinkExpanding 1.0"), true);
    assert.equal(delivery.isPreviewBot("Mozilla/5.0 (Linux; Android 13) KAKAOTALK 10.4.0"), false);
    assert.equal(delivery.isPreviewBot("Mozilla/5.0 Chrome/120"), false);
    assert.equal(delivery.isPreviewBot(undefined), false);
  });

  // ---------------- PDF 등록 ----------------
  await scenario("완료 계약의 PDF를 등록하면 해시·크기를 기록하고 링크를 발급한다", async () => {
    const c = await completed("k-attach");
    const bytes = makePdf("attach-case");
    upload("trainer-a", c.id, c.version, bytes);
    const result = await attach({contractId: c.id}, ctx("trainer-a"));
    assert.equal(result.pdfHash, crypto.createHash("sha256").update(bytes).digest("hex"));
    assert.equal(result.pdfSize, bytes.length);
    assert.match(result.linkToken, /^[A-Za-z0-9_-]{43}$/);
    assert.equal(
      result.viewUrl,
      `https://asia-northeast3-demo-project.cloudfunctions.net/viewPersonalContract?c=${c.id}&t=${result.linkToken}`,
    );
    assert.equal(result.linkExpiresAtMs, clock.getTime() + 90 * 24 * 3600 * 1000);

    const d = await deliveryOf(c.id);
    assert.equal(d.pdfHash, result.pdfHash);
    assert.equal(d.pdfPath, delivery.pdfStoragePath("trainer-a", c.id, c.version));
    // 토큰 원문은 저장하지 않고 해시만 저장한다.
    assert.equal(d.linkTokenHash, delivery.hashLinkToken(result.linkToken));
    assert.ok(!JSON.stringify(d).includes(result.linkToken));
    const types = await eventTypes(c.id);
    assert.ok(types.includes("pdf_attached"));
    assert.ok(types.includes("link_created"));
  });

  await scenario("다시 호출해도 PDF는 한 번만 등록되고, 링크를 다시 발급하면 이전 링크는 무효가 된다", async () => {
    const c = await completed("k-rotate");
    upload("trainer-a", c.id, c.version);
    const first = await attach({contractId: c.id}, ctx("trainer-a"));
    const second = await attach({contractId: c.id}, ctx("trainer-a"));
    assert.equal(second.pdfHash, first.pdfHash);
    assert.notEqual(second.linkToken, first.linkToken);
    const types = await eventTypes(c.id);
    assert.equal(types.filter((t) => t === "pdf_attached").length, 1);
    assert.equal(types.filter((t) => t === "link_created").length, 2);
    // 이전 링크는 열리지 않고 새 링크만 열린다.
    assert.equal((await request(c.id, first.linkToken)).statusCode, 404);
    assert.equal((await request(c.id, second.linkToken)).statusCode, 200);
    // 링크 없이 등록만 확인할 수도 있다(링크 유지).
    const noLink = await attach({contractId: c.id, issueLink: false}, ctx("trainer-a"));
    assert.equal(noLink.linkToken, undefined);
    assert.equal((await request(c.id, second.linkToken)).statusCode, 200);
  });

  await scenario("등록 조건: 완료 계약·본인·업로드·PDF 형식·크기", async () => {
    // 완료 전
    const draft = await save({idempotencyKey: "k-draft", memberId: "member-a", content},
      ctx("trainer-a"));
    await expectError(attach({contractId: draft.contractId}, ctx("trainer-a")),
      "failed-precondition", "contract_not_completed");
    // 업로드 안 함
    const c = await completed("k-noupload");
    await expectError(attach({contractId: c.id}, ctx("trainer-a")),
      "failed-precondition", "pdf_not_uploaded");
    // 다른 계정
    upload("trainer-a", c.id, c.version);
    await expectError(attach({contractId: c.id}, ctx("trainer-b")),
      "permission-denied", "contract_owner_mismatch");
    // 인증 없음, 알 수 없는 필드, 잘못된 ID
    await expectError(attach({contractId: c.id}, {}), "unauthenticated", "auth_required");
    await expectError(attach({contractId: c.id, x: 1}, ctx("trainer-a")),
      "invalid-argument", "unknown_fields");
    await expectError(attach({contractId: "nope"}, ctx("trainer-a")),
      "invalid-argument", "contractId_invalid");
    await expectError(attach({contractId: c.id, issueLink: "yes"}, ctx("trainer-a")),
      "invalid-argument", "issueLink_invalid");
    // PDF가 아닌 파일
    const bad = await completed("k-badpdf");
    upload("trainer-a", bad.id, bad.version, Buffer.from("this is not a pdf file at all"));
    await expectError(attach({contractId: bad.id}, ctx("trainer-a")),
      "invalid-argument", "pdf_invalid");
    // 너무 큰 파일
    const big = await completed("k-bigpdf");
    upload("trainer-a", big.id, big.version,
      Buffer.concat([makePdf(), Buffer.alloc(delivery.MAX_PDF_BYTES + 1)]));
    await expectError(attach({contractId: big.id}, ctx("trainer-a")),
      "invalid-argument", "pdf_too_large");
  });

  // ---------------- 열람 ----------------
  await scenario("올바른 링크는 PDF를 내려 주고 열람 시각·횟수를 기록한다", async () => {
    const c = await completed("k-view");
    const bytes = makePdf("view-case");
    upload("trainer-a", c.id, c.version, bytes);
    const {linkToken} = await attach({contractId: c.id}, ctx("trainer-a"));

    const res = await request(c.id, linkToken);
    assert.equal(res.statusCode, 200);
    assert.equal(res.headers["content-type"], "application/pdf");
    assert.equal(res.headers["cache-control"], "private, no-store");
    assert.equal(res.headers["x-content-type-options"], "nosniff");
    assert.equal(res.headers["referrer-policy"], "no-referrer");
    assert.match(res.headers["content-disposition"], /^inline;/);
    assert.deepEqual(res.body, bytes);

    let d = await deliveryOf(c.id);
    assert.equal(d.viewCount, 1);
    assert.ok(d.firstViewedAt);
    const first = d.firstViewedAt.toMillis();
    await request(c.id, linkToken);
    d = await deliveryOf(c.id);
    assert.equal(d.viewCount, 2);
    assert.equal(d.firstViewedAt.toMillis(), first, "첫 열람 시각은 바뀌지 않는다");
    assert.equal((await eventTypes(c.id)).filter((t) => t === "viewed").length, 2);
  });

  await scenario("링크 미리보기 봇과 HEAD 요청은 열람으로 세지 않는다", async () => {
    const c = await completed("k-bot");
    upload("trainer-a", c.id, c.version);
    const {linkToken} = await attach({contractId: c.id}, ctx("trainer-a"));
    const bot = await request(c.id, linkToken, {ua: "facebookexternalhit/1.1;kakaotalk-scrap/1.0"});
    assert.equal(bot.statusCode, 200);
    const head = await request(c.id, linkToken, {method: "HEAD"});
    assert.equal(head.statusCode, 200);
    assert.equal(head.body, null);
    assert.equal((await deliveryOf(c.id)).viewCount ?? 0, 0);
    // 카카오톡 앱 안에서 회원이 연 경우는 센다.
    await request(c.id, linkToken, {ua: "Mozilla/5.0 (Linux; Android 13) KAKAOTALK 10.4.0"});
    assert.equal((await deliveryOf(c.id)).viewCount, 1);
  });

  await scenario("잘못된 링크는 존재 여부를 알리지 않는 404, 만료는 410, 메서드는 405", async () => {
    const c = await completed("k-bad");
    upload("trainer-a", c.id, c.version);
    const {linkToken} = await attach({contractId: c.id}, ctx("trainer-a"));
    const wrongToken = delivery.newLinkToken();
    const notFoundBody = (await request(c.id, wrongToken)).body;
    assert.equal((await request(c.id, wrongToken)).statusCode, 404);
    // 없는 계약과 틀린 토큰의 응답이 같다.
    const missing = await request("pc_" + "0".repeat(32), linkToken);
    assert.equal(missing.statusCode, 404);
    assert.equal(missing.body, notFoundBody);
    // 형식이 잘못된 입력은 DB를 읽지 않고 404
    assert.equal((await request("../x", linkToken)).statusCode, 404);
    assert.equal((await request(c.id, "short")).statusCode, 404);
    assert.equal((await request(c.id, undefined)).statusCode, 404);
    // 메서드
    const post = await request(c.id, linkToken, {method: "POST"});
    assert.equal(post.statusCode, 405);
    assert.equal(post.headers.allow, "GET, HEAD");
    // 만료
    const saved = clock;
    clock = new Date(saved.getTime() + 91 * 24 * 3600 * 1000);
    const expired = await request(c.id, linkToken);
    assert.equal(expired.statusCode, 410);
    assert.match(expired.body, /링크 기간이 지났어요/);
    // 90일 안에는 열린다
    clock = new Date(saved.getTime() + 89 * 24 * 3600 * 1000);
    assert.equal((await request(c.id, linkToken)).statusCode, 200);
    clock = saved;
  });

  await scenario("등록 뒤 파일이 바뀌면(해시 불일치) 내주지 않는다", async () => {
    const c = await completed("k-tamper");
    const path = upload("trainer-a", c.id, c.version);
    const {linkToken} = await attach({contractId: c.id}, ctx("trainer-a"));
    files.set(path, makePdf("tampered"));
    const res = await request(c.id, linkToken);
    assert.equal(res.statusCode, 500);
    assert.equal((await deliveryOf(c.id)).viewCount ?? 0, 0);
  });

  await scenario("취소·미완료 계약의 링크는 열리지 않는다", async () => {
    const c = await completed("k-state");
    upload("trainer-a", c.id, c.version);
    const {linkToken} = await attach({contractId: c.id}, ctx("trainer-a"));
    // 완료 계약은 새 버전을 만들면 superseded가 될 수 있고 그래도 이전 계약서는 열린다.
    const next = await manage({contractId: c.id, action: "new_version", idempotencyKey: "nv1"},
      ctx("trainer-a"));
    assert.equal(next.created, true);
    assert.equal((await request(c.id, linkToken)).statusCode, 200);
    // 수동으로 다른 상태로 바꿔도(방어) 열리지 않는다.
    await db.collection("personal_contracts").doc(c.id).update({status: "cancelled"});
    assert.equal((await request(c.id, linkToken)).statusCode, 404);
  });

  // ---------------- 보낸 기록 ----------------
  await scenario("보낸 기록(mark_shared): 링크 발급 뒤에만, 횟수·이벤트를 남긴다", async () => {
    const c = await completed("k-share");
    await expectError(
      manage({contractId: c.id, action: "mark_shared", channel: "share_sheet"}, ctx("trainer-a")),
      "failed-precondition", "link_not_issued");
    upload("trainer-a", c.id, c.version);
    await attach({contractId: c.id}, ctx("trainer-a"));
    const first = await manage({contractId: c.id, action: "mark_shared", channel: "share_sheet"},
      ctx("trainer-a"));
    assert.equal(first.shareCount, 1);
    const second = await manage({contractId: c.id, action: "mark_shared", channel: "copy_link"},
      ctx("trainer-a"));
    assert.equal(second.shareCount, 2);
    const d = await deliveryOf(c.id);
    assert.equal(d.shareCount, 2);
    assert.ok(d.sharedAt);
    assert.ok(d.pdfHash && d.linkTokenHash, "공유 기록이 기존 배송 정보를 지우지 않는다");
    assert.equal((await eventTypes(c.id)).filter((t) => t === "shared").length, 2);
    await expectError(
      manage({contractId: c.id, action: "mark_shared", channel: "sms"}, ctx("trainer-a")),
      "invalid-argument", "channel_invalid");
    await expectError(
      manage({contractId: c.id, action: "mark_shared", channel: "copy_link"}, ctx("trainer-b")),
      "permission-denied", "contract_owner_mismatch");
  });

  await scenario("새 계약서의 delivery는 비어 있고 서버 함수만 채운다", async () => {
    // 서버 함수만 delivery를 쓴다는 점을 확인한다(규칙 테스트는 contract_access_probe 쪽).
    const c = await completed("k-fields");
    const doc = (await db.collection("personal_contracts").doc(c.id).get()).data();
    assert.deepEqual(doc.delivery, {});
  });


  // ---------------- 진위 확인 ----------------
  await scenario("문서확인번호는 계약 내용 해시 앞 16자(대문자)다", async () => {
    assert.equal(
      delivery.contractVerificationCode(
        "a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90"),
      "A1B2C3D4E5F60718");
  });

  await scenario("진위 확인: 올바른 QR이면 계약번호·상태를 보여 주고 개인정보는 싣지 않는다", async () => {
    const c = await completed("k-verify");
    const code = delivery.contractVerificationCode(c.hash);
    const res = await verifyRequest({c: c.id, k: code});
    assert.equal(res.statusCode, 200);
    assert.match(res.headers["content-type"], /^text\/html/);
    assert.equal(res.headers["cache-control"], "private, no-store");
    assert.match(res.headers["content-security-policy"], /default-src 'none'/);
    const contractNo =
      (await db.collection("personal_contracts").doc(c.id).get()).data().contractNo;
    assert.ok(res.body.includes(contractNo));
    assert.ok(res.body.includes("유효한 계약서"));
    assert.ok(res.body.includes(code.match(/.{4}/g).join("-")));
    // 회원 이름·연락처, 강사 연락처는 화면에 나오지 않는다.
    for (const secret of ["홍회원", "010-9999-8888", "010-1234-5678", "김트레이너"]) {
      assert.ok(!res.body.includes(secret), secret);
    }
    // 소문자 확인번호도 같은 문서로 인정한다.
    assert.equal((await verifyRequest({c: c.id, k: code.toLowerCase()})).statusCode, 200);
  });

  await scenario("진위 확인: 번호가 틀리거나 형식이 다르거나 없는 문서는 모두 같은 404다", async () => {
    const c = await completed("k-verify-bad");
    const good = delivery.contractVerificationCode(c.hash);
    const wrong = good.slice(0, 15) + (good.endsWith("0") ? "1" : "0");
    for (const query of [
      {c: c.id, k: wrong},
      {c: c.id, k: "ZZZZZZZZZZZZZZZZ"},
      {c: c.id, k: good.slice(0, 8)},
      {c: c.id},
      {k: good},
      {c: "pc_" + "0".repeat(32), k: good},
      {c: "other", k: good},
    ]) {
      const res = await verifyRequest(query);
      assert.equal(res.statusCode, 404, JSON.stringify(query));
      assert.ok(res.body.includes("확인할 수 없는 문서"));
      assert.ok(!res.body.includes("계약번호"));
    }
    const json = await verifyRequest({c: c.id, k: wrong, format: "json", h: "a".repeat(64)});
    assert.equal(json.statusCode, 404);
    assert.deepEqual(json.body, {ok: false});
    assert.equal((await verifyRequest({c: c.id, k: good}, "POST")).statusCode, 405);
  });

  await scenario("진위 확인: 완료·이전 버전만 확인되고 미완료·취소 문서는 404다", async () => {
    const c = await completed("k-verify-state");
    const code = delivery.contractVerificationCode(c.hash);
    const ref = db.collection("personal_contracts").doc(c.id);
    await ref.update({status: "superseded"});
    const old = await verifyRequest({c: c.id, k: code});
    assert.equal(old.statusCode, 200);
    assert.ok(old.body.includes("이전 버전"));
    for (const status of ["cancelled", "draft", "disclosed", "member_signed"]) {
      await ref.update({status});
      assert.equal((await verifyRequest({c: c.id, k: code})).statusCode, 404, status);
    }
  });

  await scenario("진위 확인: 받은 PDF의 해시가 등록된 것과 같을 때만 같은 파일로 답한다", async () => {
    const c = await completed("k-verify-file");
    const bytes = makePdf("verify-file");
    upload("trainer-a", c.id, c.version, bytes);
    await attach({contractId: c.id}, ctx("trainer-a"));
    const code = delivery.contractVerificationCode(c.hash);
    const same = crypto.createHash("sha256").update(bytes).digest("hex");
    const ok = await verifyRequest({c: c.id, k: code, format: "json", h: same});
    assert.equal(ok.statusCode, 200);
    assert.deepEqual(ok.body, {ok: true, match: true});
    const changed = crypto.createHash("sha256").update(makePdf("tampered")).digest("hex");
    assert.deepEqual(
      (await verifyRequest({c: c.id, k: code, format: "json", h: changed})).body,
      {ok: true, match: false});
    // 해시 형식이 아니거나 없으면 같다고 하지 않는다.
    for (const h of ["", "xyz", same.toUpperCase(), same.slice(1)]) {
      assert.deepEqual(
        (await verifyRequest({c: c.id, k: code, format: "json", h})).body,
        {ok: true, match: false}, h);
    }
    // PDF를 아직 등록하지 않은 문서는 파일 대조가 항상 불일치다.
    const other = await completed("k-verify-nofile");
    assert.deepEqual(
      (await verifyRequest({
        c: other.id, k: delivery.contractVerificationCode(other.hash),
        format: "json", h: same,
      })).body,
      {ok: true, match: false});
  });

  await scenario("파기된 계약서: 열람 링크는 410 안내, 진위 확인은 파기됨으로 보인다", async () => {
    const c = await completed("k-voided");
    upload("trainer-a", c.id, c.version, makePdf("voided-case"));
    const {linkToken} = await attach({contractId: c.id}, ctx("trainer-a"));
    await db.collection("personal_contracts").doc(c.id).update({status: "voided"});

    const res = await request(c.id, linkToken);
    assert.equal(res.statusCode, 410);
    assert.ok(res.body.includes("파기된 계약서예요"));
    // 링크가 틀리면 상태를 알리지 않고 같은 404다.
    const wrong = await request(c.id, "A".repeat(43));
    assert.equal(wrong.statusCode, 404);
    assert.ok(!wrong.body.includes("파기"));

    const verified = await verifyRequest({c: c.id, k: delivery.contractVerificationCode(c.hash)});
    assert.equal(verified.statusCode, 200);
    assert.ok(verified.body.includes("파기된 계약서입니다(효력 없음)"));
    assert.ok(!verified.body.includes("유효한 계약서"));
  });

  await scenario("해지된 계약서: 이미 보낸 열람 링크와 진위 확인은 계속 동작하고 해지됨으로 보인다", async () => {
    const c = await completed("k-terminated");
    upload("trainer-a", c.id, c.version, makePdf("terminated-case"));
    const {linkToken} = await attach({contractId: c.id}, ctx("trainer-a"));
    await db.collection("personal_contracts").doc(c.id).update({status: "terminated"});

    const res = await request(c.id, linkToken);
    assert.equal(res.statusCode, 200, "해지된 계약서도 체결 당시 문서는 열람할 수 있다");
    const verified = await verifyRequest({c: c.id, k: delivery.contractVerificationCode(c.hash)});
    assert.equal(verified.statusCode, 200);
    assert.ok(verified.body.includes("체결 후 해지된 계약서입니다"));
    assert.ok(!verified.body.includes("유효한 계약서"));
  });

  process.stdout.write(`All ${passed} delivery scenarios passed.\n`);
}

main().then(() => process.exit(0)).catch((error) => {
  console.error(error);
  process.exit(1);
});
