// 레슨계약서 v2 서버 규칙·callable·보안 규칙 시나리오.
// Firestore 에뮬레이터만 필요하고, functions/lib 의 컴파일 결과(핸들러)를 직접 호출한다.
const assert = require("node:assert/strict");
const fs = require("node:fs");
const admin = require("../functions/node_modules/firebase-admin");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  doc,
  getDoc,
  getDocs,
  orderBy,
  query,
  setDoc,
  where,
} = require("firebase/firestore");
const rules = require("../functions/lib/personal_contract_rules.js");
const {autoExpireMemberships} = require("../functions/lib/membership_expiry.js");
const {
  createManagePersonalContractHandler,
  createSavePersonalContractDraftHandler,
  createSavePersonalContractSettingsHandler,
  createSignPersonalContractHandler,
} = require("../functions/lib/personal_contracts.js");

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

const save = createSavePersonalContractDraftHandler(db);
const sign = createSignPersonalContractHandler(db);
const manage = createManagePersonalContractHandler(db);

function ctx(uid, provider = "password") {
  return {auth: {uid, token: {firebase: {sign_in_provider: provider}}}};
}

function validContent(overrides = {}) {
  const base = {
    party: {
      kind: "individual",
      name: "김트레이너",
      trainerName: "김트레이너",
      phone: "010-1234-5678",
      place: "서울 강남구 테스트로 1",
      businessNo: "",
      logoPath: "",
    },
    member: {name: "홍회원", phone: "010-9999-8888", birthDate: "", email: ""},
    product: {
      name: "PT 10회",
      serviceContent: "1:1 개인 트레이닝 50분",
      sessionCount: 10,
      sessionMinutes: 50,
      paidAmount: 1000000,
      vatIncluded: true,
      listPrice: null,
      paymentMethod: "card",
      paymentDate: "2026-10-20",
      periodStart: "2026-10-20",
      periodEnd: "2027-01-20",
    },
    terms: {
      cancelDeadline: {mode: "hours_before", hours: 24},
      lateNoShowMinutes: null,
      penaltyPercent: 10,
      refundBasis: "contract_unit",
      refundBusinessDays: 3,
      transfer: {policy: "conditional", feeType: "none", feeValue: 0},
      expiryExtensionClause: true,
      unavoidableRefundClause: false,
      extraTerms: "",
    },
  };
  return {
    party: {...base.party, ...(overrides.party ?? {})},
    member: {...base.member, ...(overrides.member ?? {})},
    product: {...base.product, ...(overrides.product ?? {})},
    terms: {...base.terms, ...(overrides.terms ?? {})},
  };
}

const strokes = [[[10, 10], [20, 30], [40, 20], [60, 50], [80, 40], [90, 90],
  [100, 80], [120, 100], [140, 90], [150, 120]]];
const allDisclosure = ["amount", "refund", "validity", "cancel_noshow", "health_risk"];

async function seed() {
  const profile = (uid, tier, extra = {}) => db.collection("trainer_profiles")
    .doc(uid).set({
      trainerId: uid,
      workspaceType: "personal",
      workspaceStatus: "active",
      role: "personal",
      accountState: "linked",
      isAnonymous: false,
      tier,
      ...extra,
    });
  await profile("trainer-a", "Semi-Pro");
  await profile("trainer-b", "Pro");
  await profile("trainer-low", "Amateur");
  const member = (id, uid, extra = {}) => db.collection("members").doc(id).set({
    memberId: id,
    trainerId: uid,
    workspaceType: "personal",
    name: id,
    ...extra,
  });
  await member("member-a", "trainer-a");
  await member("member-a2", "trainer-a");
  await member("member-b", "trainer-b");
  await member("member-low", "trainer-low");
  await member("member-deleted", "trainer-a", {isDeleted: true});
  // 회차 등록(P6-3) 시나리오용 회원
  await member("member-reg-add", "trainer-a", {
    lessonType: "PT",
    lessonsNotRegistered: false,
    totalSessions: 30,
    remainSessions: 1,
    remainingSessions: 1,
    doneSessions: 29,
    sessions: {notRegistered: false, total: 30, remain: 1, done: 29,
      noShowDeductedCount: 2},
    membership: {reregisterCount: 2, keepMe: "keep-me"},
  });
  await member("member-reg-new", "trainer-a", {
    lessonType: "미입력",
    lessonsNotRegistered: true,
    sessions: {notRegistered: true, total: 0, remain: 0, done: 0},
  });
  await member("member-reg-fix", "trainer-a", {
    lessonType: "필라테스",
    totalSessions: 5,
    remainSessions: 5,
    sessions: {total: 5, remain: 5, done: 0, notRegistered: false},
  });
  await member("member-reg-bare", "trainer-a");
  await member("member-reg-bare2", "trainer-a");
  await member("member-reg-bare3", "trainer-a");
  await member("member-reg-bare4", "trainer-a");
  // 파기(P6) 시나리오용 회원
  await member("member-void-a", "trainer-a", {
    lessonType: "PT",
    lessonsNotRegistered: false,
    totalSessions: 30,
    remainSessions: 1,
    remainingSessions: 1,
    doneSessions: 29,
    sessions: {notRegistered: false, total: 30, remain: 1, done: 29},
    membership: {reregisterCount: 2},
  });
  await member("member-void-b", "trainer-a", {
    totalSessions: 30, remainSessions: 8, remainingSessions: 8, doneSessions: 22,
    sessions: {total: 30, remain: 8, done: 22, notRegistered: false},
  });
  await member("member-void-c", "trainer-a", {
    lessonsNotRegistered: true,
    sessions: {notRegistered: true, total: 0, remain: 0, done: 0},
  });
  await member("member-void-d", "trainer-a", {
    totalSessions: 12, remainSessions: 12, remainingSessions: 12,
    sessions: {total: 12, remain: 12, done: 0, notRegistered: false},
  });
  // 해지(P6-6) 시나리오용 회원: 모두 활동 중, 총 30·소진 25·잔여 5
  for (const id of ["a", "b", "c", "d", "e", "f"]) {
    await member(`member-term-${id}`, "trainer-a", {
      lessonType: "PT",
      managementState: "active",
      countsTowardLimit: true,
      lessonsNotRegistered: false,
      totalSessions: 30,
      remainSessions: 5,
      remainingSessions: 5,
      doneSessions: 25,
      sessions: {notRegistered: false, total: 30, remain: 5, done: 25},
    });
  }
  await member("member-term-dormant", "trainer-a", {
    lessonType: "PT",
    managementState: "dormant",
    totalSessions: 30,
    remainSessions: 5,
    remainingSessions: 5,
    doneSessions: 25,
    sessions: {notRegistered: false, total: 30, remain: 5, done: 25},
  });
  // 회원권 기간·만료 연동 시나리오용 회원
  const kstTs = (text) => admin.firestore.Timestamp.fromDate(
    new Date(`${text}T00:00:00+09:00`));
  await member("member-exp-x", "trainer-a", {
    managementState: "expired",
    countsTowardLimit: false,
    passStart: "2026-06-01",
    passEnd: "2026-10-01",
    expireAt: kstTs("2026-10-01"),
    membership: {startAt: kstTs("2026-06-01"), endAt: kstTs("2026-10-01")},
  });
  await member("member-exp-y", "trainer-a", {
    managementState: "active",
    countsTowardLimit: true,
    passStart: "2026-06-01",
    passEnd: "2026-10-01",
    membership: {startAt: kstTs("2026-06-01"), endAt: kstTs("2026-10-01")},
  });
}

async function createDraft(key, content = validContent(), memberId = "member-a") {
  return save({idempotencyKey: key, memberId, content}, ctx("trainer-a"));
}

async function signAll(contractId, hash, items = allDisclosure) {
  await sign({contractId, step: "disclosure", contentHash: hash,
    checkedItems: items, strokes}, ctx("trainer-a"));
  await sign({contractId, step: "member", contentHash: hash,
    checkedItems: ["terms", "privacy"], strokes}, ctx("trainer-a"));
}

async function main() {
  // ---------------- 순수 규칙 ----------------
  await scenario("해시는 키 순서와 무관하고 내용이 바뀌면 달라진다", async () => {
    const a = validContent();
    const reordered = {
      terms: a.terms, product: a.product, member: a.member, party: a.party,
    };
    assert.equal(rules.contentHash(a), rules.contentHash(reordered));
    assert.match(rules.contentHash(a), /^[a-f0-9]{64}$/);
    const b = validContent({product: {paidAmount: 1000001}});
    assert.notEqual(rules.contentHash(a), rules.contentHash(b));
  });

  await scenario("금지·경고 문구 가드가 환불 제한·면책 문구를 막고 정상 문구는 통과시킨다", async () => {
    for (const bad of [
      "환불 불가", "환불불가 상품", "단순 변심 환불 안 됨", "카드 수수료 공제 후 환불",
      "환불 신청 7일 이내", "재판관할은 서울중앙지방법원", "모든 사고에 대해 책임을 지지 않음",
      "구두 약정은 효력이 없다", "환불은 불가합니다",
    ]) {
      assert.notEqual(rules.findForbiddenPhrase(bad), null, bad);
    }
    for (const ok of [
      "1:1 개인 트레이닝 50분", "환불은 신청일부터 3영업일 이내 처리합니다",
      "수업은 센터 2층에서 진행합니다", "",
    ]) {
      assert.equal(rules.findForbiddenPhrase(ok), null, ok);
    }
  });

  await scenario("입력 검증: 상한·필수·알 수 없는 필드·고정 값", async () => {
    const bad = (overrides, code) => {
      assert.throws(
        () => rules.normalizeContent(validContent(overrides), "trainer-a"),
        (error) => error.issue?.code === code,
        code,
      );
    };
    bad({terms: {penaltyPercent: 11}}, "penaltyPercent_invalid");
    bad({terms: {penaltyPercent: -1}}, "penaltyPercent_invalid");
    bad({terms: {refundBusinessDays: 131}}, "refundBusinessDays_invalid");
    bad({terms: {refundBusinessDays: 0}}, "refundBusinessDays_invalid");
    // 3영업일을 넘는 값도 6개월(130영업일)까지는 입력할 수 있다.
    for (const days of [1, 3, 5, 130]) {
      rules.normalizeContent(validContent({terms: {refundBusinessDays: days}}), "trainer-a");
    }
    bad({terms: {refundBasis: "list_price"}}, "listPrice_required_for_basis");
    bad({product: {listPrice: 900000}}, "listPrice_invalid");
    bad({product: {periodEnd: "2026-10-19"}}, "period_invalid");
    bad({product: {periodEnd: "2031-01-01"}}, "period_invalid");
    bad({product: {sessionCount: 0}}, "sessionCount_invalid");
    bad({product: {vatIncluded: "yes"}}, "vatIncluded_invalid");
    bad({product: {paidAmount: 0}}, "paidAmount_invalid");
    bad({terms: {noShowDeduction: 0}}, "unknown_fields");
    bad({terms: {trainerCancelDeduction: 1}}, "unknown_fields");
    bad({terms: {extraTerms: "환불불가"}}, "forbidden_phrase:refund_denied");
    bad({party: {logoPath: "contract_logos/other-user/logo.png"}}, "logoPath_invalid");
    bad({party: {phone: "abc"}}, "phone_invalid");
    bad({terms: {transfer: {policy: "denied", feeType: "amount", feeValue: 1000}}},
      "transfer_fee_without_policy");
    // 유효기간 종료일 없음: periodUnlimited가 true이고 종료일이 비어 있을 때만 허용한다.
    const unlimited = rules.normalizeContent(
      validContent({product: {periodEnd: "", periodUnlimited: true}}), "trainer-a",
    );
    assert.equal(unlimited.product.periodEnd, "");
    assert.equal(unlimited.product.periodUnlimited, true);
    assert.equal(unlimited.terms.expiryForfeit, false);
    bad({product: {periodUnlimited: true}}, "period_invalid");
    bad({product: {periodEnd: ""}}, "periodEnd_invalid");
    bad({product: {periodUnlimited: "yes"}}, "periodUnlimited_invalid");
    // 비고: 입력했을 때만 저장하고(기존 계약의 내용 해시 불변), 금지 문구·길이 검사를 한다.
    const withRemarks = rules.normalizeContent(
      validContent({product: {remarks: "11월 50만원, 12월 50만원 분할 결제"}}), "trainer-a",
    );
    assert.equal(withRemarks.product.remarks, "11월 50만원, 12월 50만원 분할 결제");
    const emptyRemarks = rules.normalizeContent(
      validContent({product: {remarks: ""}}), "trainer-a",
    );
    assert.equal("remarks" in emptyRemarks.product, false);
    assert.equal(
      rules.contentHash(emptyRemarks),
      rules.contentHash(rules.normalizeContent(validContent(), "trainer-a")),
      "비고가 비어 있으면 비고 없는 계약과 내용 해시가 같다",
    );
    assert.notEqual(
      rules.contentHash(withRemarks),
      rules.contentHash(rules.normalizeContent(validContent(), "trainer-a")),
    );
    bad({product: {remarks: "환불불가"}}, "forbidden_phrase:refund_denied");
    bad({product: {remarks: "가".repeat(101)}}, "remarks_invalid");
    bad({product: {remarks: 123}}, "remarks_invalid");
    const normalized = rules.normalizeContent(validContent(), "trainer-a");
    assert.equal(normalized.product.periodUnlimited, undefined);
    assert.equal(normalized.terms.noShowDeduction, 1);
    assert.equal(normalized.terms.lateCancelDeduction, 1);
    assert.equal(normalized.terms.trainerCancelDeduction, 0);
    assert.equal(normalized.terms.expiryForfeit, true);
  });

  await scenario("앱(Dart)이 만드는 계약 내용 예시가 서버 검증을 통과한다(공유 골든 파일)", async () => {
    const golden = JSON.parse(fs.readFileSync(
      "firebase-emulator-tests/fixtures/lesson_contract_content_golden.json", "utf8"));
    for (const [name, content] of Object.entries(golden)) {
      const normalized = rules.normalizeContent(content, "trainer-a");
      assert.equal(normalized.terms.noShowDeduction, 1, name);
      assert.equal(normalized.product.paidAmount, content.product.paidAmount, name);
      assert.match(rules.contentHash(normalized), /^[a-f0-9]{64}$/, name);
    }
    assert.equal(
      rules.normalizeContent(golden.full, "trainer-a").terms.refundBasis, "list_price");
  });

  await scenario("환불 계산: 명세서 예시(계약 단가 60만·정상가 45만)와 상한", async () => {
    const base = {
      paidAmount: 1000000, sessionCount: 10, usedSessions: 3,
      listPrice: 1500000, penaltyPercent: 10,
    };
    assert.equal(rules.computeRefund({
      ...base, kind: "member_reason", basis: "contract_unit",
    }).refund, 600000);
    assert.equal(rules.computeRefund({
      ...base, kind: "member_reason", basis: "list_price",
    }).refund, 450000);
    assert.equal(rules.computeRefund({
      ...base, kind: "before_first_lesson", usedSessions: 0, basis: "contract_unit",
    }).refund, 900000);
    // 소진분 + 위약금이 결제금액을 넘으면 0, 음수 없음
    const capped = rules.computeRefund({
      ...base, kind: "member_reason", usedSessions: 7, basis: "list_price",
    });
    assert.equal(capped.refund, 0);
    // 강사 귀책: 위약금 없음, 잔여 × 계약 단가
    const provider = rules.computeRefund({
      ...base, kind: "provider_fault", basis: "list_price",
    });
    assert.equal(provider.penalty, 0);
    assert.equal(provider.refund, 700000);
    // 불가피 사유: 위약금 면제
    assert.equal(rules.computeRefund({
      ...base, kind: "unavoidable", basis: "contract_unit",
    }).refund, 700000);
    assert.throws(() => rules.computeRefund({
      ...base, kind: "member_reason", basis: "contract_unit", penaltyPercent: 11,
    }));
  });

  await scenario("계약번호는 KST 월 기준으로 만들고 새 버전은 -v 표기", async () => {
    assert.deepEqual(rules.kstYearMonth(new Date("2026-10-31T15:30:00Z")),
      {yyyyMM: "202611", yyMM: "2611"});
    assert.deepEqual(rules.kstYearMonth(new Date("2026-10-31T14:30:00Z")),
      {yyyyMM: "202610", yyMM: "2610"});
    assert.equal(rules.formatContractNo("2610", 7), "PT-2610-0007");
    assert.equal(rules.displayContractNo("PT-2610-0007", 1), "PT-2610-0007");
    assert.equal(rules.displayContractNo("PT-2610-0007", 2), "PT-2610-0007-v2");
  });

  // ---------------- 서버 핸들러 ----------------
  await seed();

  await scenario("초안 생성: 계약번호 발급·이벤트 기록·같은 키 재시도는 중복 없음", async () => {
    const first = await createDraft("k1");
    assert.equal(first.created, true);
    assert.match(first.contractNo, /^PT-\d{4}-0001$/);
    assert.equal(first.status, "draft");
    const retry = await createDraft("k1");
    assert.equal(retry.created, false);
    assert.equal(retry.contractId, first.contractId);
    const second = await createDraft("k2", validContent(), "member-a2");
    assert.match(second.contractNo, /^PT-\d{4}-0002$/);
    const events = await db.collection("personal_contracts").doc(first.contractId)
      .collection("events").get();
    assert.equal(events.size, 1);
    assert.equal(events.docs[0].data().type, "draft_saved");
    const stored = (await db.collection("personal_contracts")
      .doc(first.contractId).get()).data();
    assert.equal(stored.trainerId, "trainer-a");
    assert.equal(stored.terms.noShowDeduction, 1);
    assert.equal(stored.contentHash, first.contentHash);
    assert.equal(stored.completedAt, null);
    assert.ok(stored.createdAt);
  });

  await scenario("동시 생성 5건도 계약번호가 겹치지 않는다", async () => {
    const results = await Promise.all(
      [0, 1, 2, 3, 4].map((i) => createDraft(`parallel-${i}`)),
    );
    const numbers = new Set(results.map((r) => r.contractNo));
    assert.equal(numbers.size, 5);
  });

  await scenario("초안 생성 거부: 등급·익명·타 트레이너 회원·삭제 회원·금지 문구", async () => {
    await expectError(
      save({idempotencyKey: "x1", memberId: "member-low", content: validContent()},
        ctx("trainer-low")),
      "failed-precondition", "semi_pro_required");
    await expectError(
      save({idempotencyKey: "x2", memberId: "member-a", content: validContent()},
        ctx("trainer-a", "anonymous")),
      "permission-denied", "workspace_not_eligible");
    await expectError(
      save({idempotencyKey: "x3", memberId: "member-b", content: validContent()},
        ctx("trainer-a")),
      "permission-denied", "member_owner_mismatch");
    await expectError(
      createDraft("x4", validContent(), "member-deleted"),
      "failed-precondition", "member_deleted");
    await expectError(
      createDraft("x5", validContent({terms: {extraTerms: "환불불가"}})),
      "invalid-argument", "forbidden_phrase:refund_denied");
    await expectError(
      save({idempotencyKey: "x6", memberId: "member-a", content: validContent(),
        evil: true}, ctx("trainer-a")),
      "invalid-argument", "unknown_fields");
    await expectError(
      save({memberId: "member-a", content: validContent()}, ctx("trainer-a")),
      "invalid-argument", "idempotencyKey_or_contractId_required");
    await expectError(
      save({idempotencyKey: "x7", memberId: "member-a", content: validContent()}, {}),
      "unauthenticated", "auth_required");
  });

  await scenario("정상 흐름: 서명 ① → ② → 강사 서명 후에만 완료되고 회원 포인터가 기록된다", async () => {
    const draft = await createDraft("flow-1");
    const {contractId, contentHash: hash} = draft;
    const memberRef = db.collection("members").doc("member-a");
    await sign({contractId, step: "disclosure", contentHash: hash,
      checkedItems: allDisclosure, strokes}, ctx("trainer-a"));
    let contract = (await db.collection("personal_contracts").doc(contractId).get()).data();
    assert.equal(contract.status, "disclosed");
    assert.equal((await memberRef.get()).data().contractSigned, undefined);
    await sign({contractId, step: "member", contentHash: hash,
      checkedItems: ["terms", "privacy"], strokes}, ctx("trainer-a"));
    contract = (await db.collection("personal_contracts").doc(contractId).get()).data();
    assert.equal(contract.status, "member_signed");
    assert.equal(contract.completedAt, null);
    // 서명 ②까지로는 회원 문서가 계약 완료로 바뀌지 않는다.
    assert.equal((await memberRef.get()).data().contractSigned, undefined);
    const done = await sign({contractId, step: "trainer", contentHash: hash,
      strokes}, ctx("trainer-a"));
    assert.equal(done.status, "completed");
    contract = (await db.collection("personal_contracts").doc(contractId).get()).data();
    assert.equal(contract.status, "completed");
    assert.ok(contract.completedAt);
    assert.ok(contract.signatures.disclosure.signedAt);
    const member = (await memberRef.get()).data();
    assert.equal(member.contractSigned, true);
    assert.equal(member.contractId, contractId);
    assert.equal(member.contractStatus, "completed");
    assert.equal(member.lessonSync.contractId, contractId);
    assert.equal(member.lastContractSummary.finalSigned, true);
    assert.equal(member.lastContractSummary.totalPrice, 1000000);
    const events = await db.collection("personal_contracts").doc(contractId)
      .collection("events").get();
    const types = new Set(events.docs.map((e) => e.data().type));
    for (const t of ["draft_saved", "disclosure_signed", "member_signed",
      "trainer_signed", "completed"]) {
      assert.ok(types.has(t), t);
    }
    const signedEvent = events.docs.find((e) => e.data().type === "member_signed").data();
    assert.equal(signedEvent.contentHash, hash);
    assert.deepEqual(signedEvent.payload.checkedItems, ["privacy", "terms"]);
    assert.equal(signedEvent.payload.strokes.length, 1);
    assert.equal(signedEvent.payload.strokes[0].points.length, 20);
    assert.equal(signedEvent.actorRole, "member");
  });

  await scenario("서명 순서·확인 항목·서명 데이터·해시 검증", async () => {
    const draft = await createDraft("flow-2", validContent(), "member-a2");
    const {contractId, contentHash: hash} = draft;
    await expectError(
      sign({contractId, step: "member", contentHash: hash,
        checkedItems: ["terms", "privacy"], strokes}, ctx("trainer-a")),
      "failed-precondition", "invalid_state");
    await expectError(
      sign({contractId, step: "trainer", contentHash: hash, strokes}, ctx("trainer-a")),
      "failed-precondition", "invalid_state");
    await expectError(
      sign({contractId, step: "disclosure", contentHash: hash,
        checkedItems: allDisclosure.slice(1), strokes}, ctx("trainer-a")),
      "invalid-argument", "checkedItems_mismatch");
    await expectError(
      sign({contractId, step: "disclosure", contentHash: hash,
        checkedItems: [...allDisclosure, "extra"], strokes}, ctx("trainer-a")),
      "invalid-argument", "checkedItems_mismatch");
    await expectError(
      sign({contractId, step: "disclosure", contentHash: "0".repeat(64),
        checkedItems: allDisclosure, strokes}, ctx("trainer-a")),
      "failed-precondition", "content_changed");
    await expectError(
      sign({contractId, step: "disclosure", contentHash: hash,
        checkedItems: allDisclosure, strokes: [[[1, 1]]]}, ctx("trainer-a")),
      "invalid-argument", "strokes_invalid");
    await expectError(
      sign({contractId, step: "disclosure", contentHash: hash,
        checkedItems: allDisclosure, strokes: []}, ctx("trainer-a")),
      "invalid-argument", "strokes_invalid");
    await expectError(
      sign({contractId, step: "bogus", contentHash: hash, strokes}, ctx("trainer-a")),
      "invalid-argument", "step_invalid");
    // 같은 단계를 같은 내용으로 다시 호출하면 중복 기록 없이 성공한다.
    await sign({contractId, step: "disclosure", contentHash: hash,
      checkedItems: allDisclosure, strokes}, ctx("trainer-a"));
    const again = await sign({contractId, step: "disclosure", contentHash: hash,
      checkedItems: allDisclosure, strokes}, ctx("trainer-a"));
    assert.equal(again.alreadySigned, true);
    const events = await db.collection("personal_contracts").doc(contractId)
      .collection("events").where("type", "==", "disclosure_signed").get();
    assert.equal(events.size, 1);
  });

  await scenario("정상가 기준 계약은 정상가 확인 항목이 추가로 필요하다", async () => {
    const content = validContent({
      product: {listPrice: 1500000},
      terms: {refundBasis: "list_price"},
    });
    const draft = await createDraft("flow-3", content);
    await expectError(
      sign({contractId: draft.contractId, step: "disclosure",
        contentHash: draft.contentHash, checkedItems: allDisclosure, strokes},
      ctx("trainer-a")),
      "invalid-argument", "checkedItems_mismatch");
    const signed = await sign({contractId: draft.contractId, step: "disclosure",
      contentHash: draft.contentHash,
      checkedItems: [...allDisclosure, "list_price_basis"], strokes}, ctx("trainer-a"));
    assert.equal(signed.status, "disclosed");
  });

  await scenario("서명 ① 이후 내용을 바꾸면 서명이 무효가 되고 재고지를 해야 한다", async () => {
    const draft = await createDraft("flow-4");
    const {contractId, contentHash: oldHash} = draft;
    await signAll(contractId, oldHash);
    const updated = await save({
      contractId,
      memberId: "member-a",
      content: validContent({product: {paidAmount: 900000}}),
    }, ctx("trainer-a"));
    assert.equal(updated.invalidatedSignatures, true);
    assert.equal(updated.status, "draft");
    assert.notEqual(updated.contentHash, oldHash);
    const stored = (await db.collection("personal_contracts").doc(contractId).get()).data();
    assert.equal(stored.status, "draft");
    assert.equal(stored.signatures.disclosure, null);
    assert.equal(stored.signatures.member, null);
    assert.equal(stored.disclosure, null);
    const invalidated = await db.collection("personal_contracts").doc(contractId)
      .collection("events").where("type", "==", "signatures_invalidated").get();
    assert.equal(invalidated.size, 1);
    // 예전 해시로는 서명할 수 없다.
    await expectError(
      sign({contractId, step: "disclosure", contentHash: oldHash,
        checkedItems: allDisclosure, strokes}, ctx("trainer-a")),
      "failed-precondition", "content_changed");
    // 내용이 같은 저장은 변화 없음.
    const same = await save({
      contractId, memberId: "member-a",
      content: validContent({product: {paidAmount: 900000}}),
    }, ctx("trainer-a"));
    assert.equal(same.unchanged, true);
    // 회원 변경은 불가.
    await expectError(
      save({contractId, memberId: "member-a2", content: validContent()}, ctx("trainer-a")),
      "failed-precondition", "member_immutable");
  });

  await scenario("완료된 계약은 수정·취소·재서명이 모두 거부된다", async () => {
    const draft = await createDraft("flow-5", validContent(), "member-a2");
    const {contractId, contentHash: hash} = draft;
    await signAll(contractId, hash);
    await sign({contractId, step: "trainer", contentHash: hash, strokes}, ctx("trainer-a"));
    await expectError(
      save({contractId, memberId: "member-a2",
        content: validContent({product: {paidAmount: 1}})}, ctx("trainer-a")),
      "failed-precondition", "contract_locked");
    await expectError(
      manage({contractId, action: "cancel", reason: "취소 시도"}, ctx("trainer-a")),
      "failed-precondition", "contract_locked");
    const resign = await sign({contractId, step: "trainer", contentHash: hash,
      strokes}, ctx("trainer-a"));
    assert.equal(resign.alreadySigned, true);
  });

  await scenario("다른 트레이너는 남의 계약을 수정·서명·취소할 수 없다", async () => {
    const draft = await createDraft("flow-6");
    const {contractId, contentHash: hash} = draft;
    await expectError(
      save({contractId, memberId: "member-b", content: validContent()}, ctx("trainer-b")),
      "permission-denied", "contract_owner_mismatch");
    await expectError(
      sign({contractId, step: "disclosure", contentHash: hash,
        checkedItems: allDisclosure, strokes}, ctx("trainer-b")),
      "permission-denied", "contract_owner_mismatch");
    await expectError(
      manage({contractId, action: "cancel", reason: "남의 계약"}, ctx("trainer-b")),
      "permission-denied", "contract_owner_mismatch");
    await expectError(
      manage({contractId: "pc_" + "0".repeat(32), action: "cancel", reason: "없음"},
        ctx("trainer-a")),
      "not-found", "contract_not_found");
  });

  await scenario("취소: 사유 필수, 중복 호출 안전, 이후 수정 불가", async () => {
    const draft = await createDraft("cancel-1", validContent(), "member-a2");
    await expectError(
      manage({contractId: draft.contractId, action: "cancel"}, ctx("trainer-a")),
      "invalid-argument", "reason_required");
    const cancelled = await manage({contractId: draft.contractId, action: "cancel",
      reason: "회원 변심 전 취소"}, ctx("trainer-a"));
    assert.equal(cancelled.status, "cancelled");
    const again = await manage({contractId: draft.contractId, action: "cancel",
      reason: "회원 변심 전 취소"}, ctx("trainer-a"));
    assert.equal(again.alreadyCancelled, true);
    await expectError(
      save({contractId: draft.contractId, memberId: "member-a2", content: validContent()},
        ctx("trainer-a")),
      "failed-precondition", "contract_locked");
  });

  await scenario("새 버전: 완료 계약에서만, 열린 버전은 하나, 완료 시 원본이 대체됨", async () => {
    const draft = await createDraft("ver-1", validContent(), "member-a2");
    const v1 = draft.contractId;
    await expectError(
      manage({contractId: v1, action: "new_version", idempotencyKey: "nv"}, ctx("trainer-a")),
      "failed-precondition", "new_version_requires_completed");
    await signAll(v1, draft.contentHash);
    await sign({contractId: v1, step: "trainer", contentHash: draft.contentHash,
      strokes}, ctx("trainer-a"));
    const v2 = await manage({contractId: v1, action: "new_version",
      idempotencyKey: "nv"}, ctx("trainer-a"));
    assert.equal(v2.created, true);
    assert.equal(v2.version, 2);
    assert.match(v2.contractNo, /-v2$/);
    const retry = await manage({contractId: v1, action: "new_version",
      idempotencyKey: "nv"}, ctx("trainer-a"));
    assert.equal(retry.created, false);
    assert.equal(retry.contractId, v2.contractId);
    await expectError(
      manage({contractId: v1, action: "new_version", idempotencyKey: "nv-other"},
        ctx("trainer-a")),
      "failed-precondition", "new_version_already_open");
    // 새 버전이 완료되기 전에는 원본이 그대로 완료 상태다.
    assert.equal((await db.collection("personal_contracts").doc(v1).get())
      .data().status, "completed");
    await signAll(v2.contractId, v2.contentHash);
    await sign({contractId: v2.contractId, step: "trainer", contentHash: v2.contentHash,
      strokes}, ctx("trainer-a"));
    const old = (await db.collection("personal_contracts").doc(v1).get()).data();
    assert.equal(old.status, "superseded");
    assert.equal(old.supersededById, v2.contractId);
    const member = (await db.collection("members").doc("member-a2").get()).data();
    assert.equal(member.contractId, v2.contractId);
    assert.match(member.contractNo, /-v2$/);
  });

  // ---------------- 회차 등록(P6-3) ----------------
  const complete = async (key, memberId, content) => {
    const draft = await createDraft(key, content, memberId);
    await signAll(draft.contractId, draft.contentHash);
    await sign({contractId: draft.contractId, step: "trainer",
      contentHash: draft.contentHash, strokes}, ctx("trainer-a"));
    return draft;
  };
  const memberDoc = async (id) =>
    (await db.collection("members").doc(id).get()).data();
  const contractDoc = async (id) =>
    (await db.collection("personal_contracts").doc(id).get()).data();

  await scenario("회차 등록: 재계약은 기존 총·잔여 횟수에 합산하고 소진 횟수는 그대로 둔다", async () => {
    const draft = await complete("reg-add", "member-reg-add", validContent());
    const member = await memberDoc("member-reg-add");
    assert.equal(member.totalSessions, 40);
    assert.equal(member.remainSessions, 11);
    assert.equal(member.remainingSessions, 11);
    assert.equal(member.doneSessions, 29);
    assert.equal(member.sessions.total, 40);
    assert.equal(member.sessions.remain, 11);
    assert.equal(member.sessions.done, 29);
    assert.equal(member.sessions.notRegistered, false);
    assert.equal(member.sessions.noShowDeductedCount, 2, "다른 sessions 필드는 유지");
    assert.equal(member.lessonsNotRegistered, false);
    assert.equal(member.lessonType, "PT", "이미 있는 레슨 종류는 바꾸지 않는다");
    assert.equal(member.lastRegistration.contractId, draft.contractId);
    assert.equal(member.lastRegistration.added, 10);
    assert.equal(member.lastRegistration.totalAfter, 40);
    assert.equal(member.lastRegistration.remainAfter, 11);
    assert.ok(member.lastRegistration.at);
    const contract = await contractDoc(draft.contractId);
    assert.equal(contract.registration.registered, 10);
    assert.equal(contract.registration.added, 10);
    assert.equal(contract.registration.doneAtRegistration, 29, "등록 직후 받은 레슨 횟수");
    assert.ok(contract.registration.registeredAt);
    // 이미 횟수가 있던 회원의 새 계약은 재등록이다: 카드 뒷면 재등록 +1, 최근 재등록일 갱신.
    assert.equal(contract.registration.reregistration, true);
    assert.equal(member.membership.reregisterCount, 3);
    assert.ok(member.membership.lastReregisterAt);
    assert.equal(member.membership.keepMe, "keep-me", "다른 membership 필드는 유지");
  });

  await scenario("회차 등록: 레슨 미등록 회원은 계약 횟수로 등록되고 레슨 종류가 정해진다", async () => {
    await complete("reg-new", "member-reg-new", validContent());
    const member = await memberDoc("member-reg-new");
    assert.equal(member.totalSessions, 10);
    assert.equal(member.remainSessions, 10);
    assert.equal(member.sessions.total, 10);
    assert.equal(member.sessions.remain, 10);
    assert.equal(member.sessions.notRegistered, false);
    assert.equal(member.lessonsNotRegistered, false);
    assert.equal(member.lessonType, "PT", "상품명 'PT 10회'에서 레슨 종류를 뽑는다");
    assert.equal(member.contractLessonType, "PT");
    // 첫 등록은 재등록이 아니다.
    assert.equal(member.membership?.reregisterCount, undefined);
    assert.equal(member.membership?.lastReregisterAt, undefined);
  });

  await scenario("회차 등록: 횟수 정보가 전혀 없는 회원도 등록되고, 알 수 없는 상품명은 '레슨'이 된다", async () => {
    await complete("reg-bare", "member-reg-bare",
      validContent({product: {name: "스트레칭 패키지"}}));
    const member = await memberDoc("member-reg-bare");
    assert.equal(member.totalSessions, 10);
    assert.equal(member.remainSessions, 10);
    assert.equal(member.doneSessions, 0);
    assert.equal(member.lessonType, "레슨");
  });

  await scenario("회차 등록: 새 버전(정정)은 이전 계약이 등록한 횟수와의 차이만 반영한다", async () => {
    const v1 = await complete("reg-fix", "member-reg-fix",
      validContent({product: {sessionCount: 10}}));
    let member = await memberDoc("member-reg-fix");
    assert.equal(member.totalSessions, 15);
    assert.equal(member.remainSessions, 15);
    assert.equal(member.lessonType, "필라테스");

    // 10회 → 8회로 정정: 2회만 빠지고, 이중으로 더해지지 않는다.
    const v2 = await manage({contractId: v1.contractId, action: "new_version",
      idempotencyKey: "reg-fix-v2"}, ctx("trainer-a"));
    const fixed = validContent({product: {sessionCount: 8}});
    const saved = await save({contractId: v2.contractId, memberId: "member-reg-fix",
      content: fixed}, ctx("trainer-a"));
    await signAll(v2.contractId, saved.contentHash);
    await sign({contractId: v2.contractId, step: "trainer",
      contentHash: saved.contentHash, strokes}, ctx("trainer-a"));
    member = await memberDoc("member-reg-fix");
    assert.equal(member.totalSessions, 13);
    assert.equal(member.remainSessions, 13);
    assert.equal(member.lastRegistration.added, -2);
    const second = await contractDoc(v2.contractId);
    assert.equal(second.registration.registered, 8);
    assert.equal(second.registration.added, -2);

    // 다시 12회로 정정하면 이전 버전(8회)과의 차이 +4만 더해진다.
    const v3 = await manage({contractId: v2.contractId, action: "new_version",
      idempotencyKey: "reg-fix-v3"}, ctx("trainer-a"));
    const again = await save({contractId: v3.contractId, memberId: "member-reg-fix",
      content: validContent({product: {sessionCount: 12}})}, ctx("trainer-a"));
    await signAll(v3.contractId, again.contentHash);
    await sign({contractId: v3.contractId, step: "trainer",
      contentHash: again.contentHash, strokes}, ctx("trainer-a"));
    member = await memberDoc("member-reg-fix");
    assert.equal(member.totalSessions, 17);
    assert.equal(member.remainSessions, 17);
    // 정정(새 버전)은 재등록 횟수를 올리지 않는다: 처음 새 계약에서만 +1.
    assert.equal(member.membership.reregisterCount, 1);
    assert.equal((await contractDoc(v3.contractId)).registration.reregistration, false);
  });

  await scenario("회차 등록: 이미 소진한 횟수보다 적게 정정해도 잔여 횟수는 0 아래로 내려가지 않는다", async () => {
    const reg = require("../functions/lib/personal_contract_registration.js");
    const result = reg.buildRegistration(
      {totalSessions: 10, remainSessions: 2, doneSessions: 8, lessonType: "PT"},
      {name: "PT", sessionCount: 4},
      10,
      {contractId: "pc_x", contractNo: "PT-1"},
    );
    assert.equal(result.registration.added, -6);
    assert.equal(result.memberUpdate.totalSessions, 4);
    assert.equal(result.memberUpdate.remainSessions, 0);
    assert.equal(result.memberUpdate.lessonsNotRegistered, false);
    assert.deepEqual(
      reg.readMemberSessions({sessions: {total: 7, remain: 3}}), {total: 7, remain: 3});
    assert.deepEqual(reg.readMemberSessions({}), {total: 0, remain: 0});
    assert.equal(reg.lessonTypeFromProductName("PT 10회"), "PT");
    assert.equal(reg.lessonTypeFromProductName("필라테스 그룹"), "필라테스");
    assert.equal(reg.lessonTypeFromProductName("피티 20"), "PT");
    assert.equal(reg.lessonTypeFromProductName("10"), "레슨");
  });

  // ---------------- 계약서 파기(P6) ----------------
  const DAY = 24 * 60 * 60 * 1000;
  const voidNow = delivery_void_handler();
  function delivery_void_handler(now) {
    return require("../functions/lib/personal_contract_void.js")
      .createVoidPersonalContractHandler(db, now ? {now} : {});
  }
  const voidIn = (handler, id, extra = {}) => handler({
    contractId: id, reason: "잘못 작성함", strokes, ...extra,
  }, ctx("trainer-a"));
  const noticeDoc = async (id) =>
    (await db.collection("contract_notices").doc(id).get()).data();

  await scenario("파기: 3일 안에 회원 서명으로 파기하면 횟수·재등록·계약 연결이 되돌려지고 알림이 남는다", async () => {
    const draft = await complete("void-1", "member-void-a", validContent());
    let member = await memberDoc("member-void-a");
    assert.equal(member.totalSessions, 40);
    assert.equal(member.membership.reregisterCount, 3);
    assert.equal(member.contractSigned, true);

    const result = await voidIn(voidNow, draft.contractId);
    assert.equal(result.alreadyVoided, false);
    assert.equal(result.status, "voided");
    assert.equal(result.rolledBack, 10);

    const contract = await contractDoc(draft.contractId);
    assert.equal(contract.status, "voided");
    assert.equal(contract.voidReason, "잘못 작성함");
    assert.ok(contract.voidedAt);
    assert.ok(contract.signatures.void.signedAt);
    const events = (await db.collection("personal_contracts").doc(draft.contractId)
      .collection("events").get()).docs.map((d) => d.data());
    const signed = events.find((e) => e.type === "void_signed");
    assert.equal(signed.actorRole, "member");
    assert.ok(signed.payload.strokes.length > 0, "파기 서명 획이 남는다");
    assert.equal(events.find((e) => e.type === "voided").payload.rolledBack, 10);

    member = await memberDoc("member-void-a");
    assert.equal(member.totalSessions, 30);
    assert.equal(member.remainSessions, 1);
    assert.equal(member.remainingSessions, 1);
    assert.equal(member.doneSessions, 29, "받은 레슨 횟수는 그대로");
    assert.equal(member.sessions.total, 30);
    assert.equal(member.sessions.remain, 1);
    assert.equal(member.membership.reregisterCount, 2, "재등록 횟수도 되돌린다");
    assert.equal(member.lastRegistration, undefined);
    assert.equal(member.contractSigned, false);
    assert.equal(member.contractId, undefined);
    assert.equal(member.contractNo, undefined);
    assert.equal(member.lessonSync?.contractId, undefined);
    assert.equal(member.lastContractSummary, undefined);

    const notice = await noticeDoc(`${draft.contractId}_void`);
    assert.equal(notice.kind, "contract_void");
    assert.equal(notice.state, "pending");
    assert.equal(notice.channel, null);
    assert.equal(notice.memberName, "홍회원");
    assert.match(notice.message, /^홍회원님, PT-\d{4}-\d{4} 레슨계약서가 파기되었습니다\.$/);
    assert.equal(notice.reason, "잘못 작성함");
  });

  await scenario("파기: 같은 요청을 다시 보내도 한 번만 처리된다", async () => {
    const draft = await complete("void-2", "member-void-b", validContent());
    await voidIn(voidNow, draft.contractId);
    const again = await voidIn(voidNow, draft.contractId);
    assert.equal(again.alreadyVoided, true);
    const member = await memberDoc("member-void-b");
    assert.equal(member.totalSessions, 30);
    assert.equal(member.remainSessions, 8);
  });

  await scenario("파기: 계약 뒤 레슨을 받았으면 거부되고 아무것도 바뀌지 않는다", async () => {
    const draft = await complete("void-3", "member-void-d", validContent());
    // 레슨 한 번 소진(홈 확정과 같은 필드).
    await db.collection("members").doc("member-void-d").update({
      remainSessions: 21, remainingSessions: 21, doneSessions: 1,
      "sessions.remain": 21, "sessions.done": 1,
    });
    await expectError(voidIn(voidNow, draft.contractId),
      "failed-precondition", "void_lessons_taken");
    assert.equal((await contractDoc(draft.contractId)).status, "completed");
    const member = await memberDoc("member-void-d");
    assert.equal(member.totalSessions, 22);
    assert.equal(member.remainSessions, 21);
    assert.equal(await noticeDoc(`${draft.contractId}_void`), undefined);
  });

  await scenario("파기: 완료 후 3일이 지나면 거부된다(해지로 따로 진행)", async () => {
    const draft = await complete("void-4", "member-void-c", validContent());
    const late = delivery_void_handler(() => new Date(Date.now() + 4 * DAY));
    await expectError(voidIn(late, draft.contractId),
      "failed-precondition", "void_window_passed");
    const edge = delivery_void_handler(() => new Date(Date.now() + 2.9 * DAY));
    // 3일 안이면 가능하다(경계 안쪽).
    const ok = await voidIn(edge, draft.contractId);
    assert.equal(ok.status, "voided");
    const member = await memberDoc("member-void-c");
    assert.equal(member.totalSessions, 0);
    assert.equal(member.sessions.notRegistered, true);
    assert.equal(member.lessonsNotRegistered, true);
  });

  await scenario("파기: 완료되지 않은 계약·남의 계약·서명/사유 없음은 거부된다", async () => {
    const draft = await createDraft("void-5", validContent(), "member-a");
    await expectError(voidIn(voidNow, draft.contractId),
      "failed-precondition", "void_requires_completed");
    const done = await complete("void-6", "member-a2", validContent());
    await expectError(
      voidNow({contractId: done.contractId, reason: "x", strokes}, ctx("trainer-a")),
      "invalid-argument", "reason_required");
    await expectError(
      voidNow({contractId: done.contractId, reason: "잘못 작성함", strokes: []},
        ctx("trainer-a")),
      "invalid-argument");
    await expectError(
      voidNow({contractId: done.contractId, reason: "잘못 작성함"}, ctx("trainer-a")),
      "invalid-argument");
    await expectError(
      voidNow({contractId: done.contractId, reason: "잘못 작성함", strokes}, ctx("trainer-b")),
      "permission-denied", "contract_owner_mismatch");
    assert.equal((await contractDoc(done.contractId)).status, "completed");
    await expectError(voidNow({contractId: done.contractId, reason: "잘못 작성함", strokes}, {}),
      "unauthenticated");
  });

  await scenario("파기: 이전에 완료한 다른 계약이 있으면 계약 연결이 그 계약으로 돌아가고 이 계약의 횟수만 뺀다", async () => {
    const first = await complete("void-7a", "member-reg-bare2", validContent());
    const second = await complete("void-7b", "member-reg-bare2",
      validContent({product: {sessionCount: 5, paidAmount: 500000}}));
    let member = await memberDoc("member-reg-bare2");
    assert.equal(member.totalSessions, 15);
    assert.equal(member.contractId, second.contractId);
    assert.equal(member.membership.reregisterCount, 1);

    // 첫 계약은 최근 등록이 아니라 파기할 수 없다.
    await expectError(voidIn(voidNow, first.contractId),
      "failed-precondition", "void_not_latest_registration");

    await voidIn(voidNow, second.contractId);
    member = await memberDoc("member-reg-bare2");
    assert.equal(member.totalSessions, 10);
    assert.equal(member.remainSessions, 10);
    assert.equal(member.contractId, first.contractId);
    assert.equal(member.contractSigned, true);
    assert.equal(member.lessonSync.contractId, first.contractId);
    assert.equal(member.lastContractSummary.contractId, first.contractId);
    assert.equal(member.membership.reregisterCount, 0);
    assert.equal((await contractDoc(first.contractId)).status, "completed");
  });

  await scenario("파기: 횟수를 등록하기 전에 완료된 옛 계약은 횟수를 건드리지 않고 파기된다", async () => {
    const draft = await complete("void-8", "member-reg-bare3", validContent());
    // 이번 기능 이전에 완료된 계약처럼 등록 기록과 회원의 마지막 등록을 지운다.
    await db.collection("personal_contracts").doc(draft.contractId)
      .update({registration: admin.firestore.FieldValue.delete()});
    await db.collection("members").doc("member-reg-bare3").update({
      totalSessions: 3, remainSessions: 3, remainingSessions: 3,
      lastRegistration: admin.firestore.FieldValue.delete(),
    });
    const result = await voidIn(voidNow, draft.contractId);
    assert.equal(result.rolledBack, 0);
    const member = await memberDoc("member-reg-bare3");
    assert.equal(member.totalSessions, 3);
    assert.equal(member.remainSessions, 3);
    assert.equal(member.contractSigned, false);
  });

  await scenario("파기: 파기된 계약은 새 버전·취소·링크 발급이 모두 막힌다", async () => {
    const draft = await complete("void-9", "member-reg-bare4", validContent());
    await voidIn(voidNow, draft.contractId);
    await expectError(
      manage({contractId: draft.contractId, action: "new_version", idempotencyKey: "nv-void"},
        ctx("trainer-a")),
      "failed-precondition", "new_version_requires_completed");
    await expectError(
      manage({contractId: draft.contractId, action: "cancel", reason: "취소"}, ctx("trainer-a")),
      "failed-precondition", "contract_locked");
    await expectError(
      manage({contractId: draft.contractId, action: "mark_shared", channel: "copy_link"},
        ctx("trainer-a")),
      "failed-precondition", "link_not_issued");
  });

  await scenario("파기 알림은 앱이 읽거나 쓸 수 없고 서버 전용이다(규칙 미정의)", async () => {
    const rules = fs.readFileSync(require("path").join(__dirname, "..", "firestore.rules"), "utf8");
    assert.ok(!rules.includes("contract_notices"), "규칙에 정의하지 않아 기본 거부");
  });

  // ---------------- 회원권 기간·만료 연동 ----------------
  const kstTs = (text) => admin.firestore.Timestamp.fromDate(
    new Date(`${text}T00:00:00+09:00`));
  const profileDoc = async (id) =>
    (await db.collection("trainer_profiles").doc(id).get()).data();

  await scenario("만료 연동: 만료 회원이 재계약하면 활동 중으로 돌아가고 기간이 계약의 사용 기간으로 다시 시작된다", async () => {
    const before = await profileDoc("trainer-a");
    const baseCount = Number(before.managedMemberCount ?? 0);
    const draft = await complete("exp-1", "member-exp-x", validContent());
    const member = await memberDoc("member-exp-x");
    assert.equal(member.managementState, "active");
    assert.equal(member.countsTowardLimit, true);
    assert.equal(member.passStart, "2026-10-20");
    assert.equal(member.passEnd, "2027-01-20");
    assert.equal(member.membership.startAt.toDate().toISOString(),
      kstTs("2026-10-20").toDate().toISOString());
    assert.equal(member.membership.endAt.toDate().toISOString(),
      kstTs("2027-01-20").toDate().toISOString());
    assert.equal(member.expireAt.toDate().toISOString(),
      kstTs("2027-01-20").toDate().toISOString());
    assert.equal(member.membership.notRegistered, false);
    const last = member.managementStateHistory.at(-1);
    assert.equal(last.previousState, "expired");
    assert.equal(last.nextState, "active");
    assert.equal(last.source, "contract_complete");
    const contract = await contractDoc(draft.contractId);
    assert.equal(contract.registration.reactivated, true);
    assert.ok(contract.registration.membershipBefore);
    assert.equal((await profileDoc("trainer-a")).managedMemberCount, baseCount + 1);
  });

  await scenario("만료 연동: 그 계약을 파기하면 이전 기간과 만료 상태로 돌아가고 관리 회원 수도 되돌린다", async () => {
    const baseCount = Number((await profileDoc("trainer-a")).managedMemberCount);
    const contractId = (await db.collection("members").doc("member-exp-x").get())
      .data().contractId;
    await voidIn(voidNow, contractId);
    const member = await memberDoc("member-exp-x");
    assert.equal(member.managementState, "expired");
    assert.equal(member.countsTowardLimit, false);
    assert.equal(member.passEnd, "2026-10-01");
    assert.equal(member.passStart, "2026-06-01");
    assert.equal(member.membership.endAt.toDate().toISOString(),
      kstTs("2026-10-01").toDate().toISOString());
    assert.equal(member.expireAt.toDate().toISOString(),
      kstTs("2026-10-01").toDate().toISOString());
    assert.equal(member.managementStateHistory.at(-1).source, "contract_void");
    assert.equal((await profileDoc("trainer-a")).managedMemberCount, baseCount - 1);
  });

  await scenario("만료 연동: 활동 중 회원이 재계약하면 상태는 그대로 두고 기간만 갱신하며 파기하면 되돌린다", async () => {
    const baseCount = Number((await profileDoc("trainer-a")).managedMemberCount ?? 0);
    const draft = await complete("exp-2", "member-exp-y", validContent());
    let member = await memberDoc("member-exp-y");
    assert.equal(member.managementState, "active");
    assert.equal(member.passEnd, "2027-01-20");
    assert.equal(member.membership.endAt.toDate().toISOString(),
      kstTs("2027-01-20").toDate().toISOString());
    assert.equal((await contractDoc(draft.contractId)).registration.reactivated, false);
    assert.equal((await profileDoc("trainer-a")).managedMemberCount, baseCount,
      "이미 활동 중이면 관리 회원 수는 그대로");
    await voidIn(voidNow, draft.contractId);
    member = await memberDoc("member-exp-y");
    assert.equal(member.managementState, "active");
    assert.equal(member.passEnd, "2026-10-01");
    assert.equal(member.membership.endAt.toDate().toISOString(),
      kstTs("2026-10-01").toDate().toISOString());
    assert.equal((await profileDoc("trainer-a")).managedMemberCount, baseCount);
  });

  await scenario("만료 연동: 종료일 없음 계약이면 회원권 종료일을 지운다", async () => {
    const draft = await complete("exp-3", "member-exp-y",
      validContent({product: {periodEnd: "", periodUnlimited: true}}));
    const member = await memberDoc("member-exp-y");
    assert.equal(member.membership.endAt, undefined);
    assert.equal(member.expireAt, undefined);
    assert.equal(member.membership.unlimitedEndDate, true);
    await voidIn(voidNow, draft.contractId);
    const restored = await memberDoc("member-exp-y");
    assert.equal(restored.membership.endAt.toDate().toISOString(),
      kstTs("2026-10-01").toDate().toISOString());
    assert.equal(restored.membership.unlimitedEndDate, undefined);
  });

  // ---------------- 자동 만료(스케줄) ----------------
  const sweepNow = new Date("2026-10-26T00:40:00+09:00");
  const sweepMember = (id, extra = {}) => db.collection("members").doc(id).set({
    memberId: id,
    trainerId: "trainer-sweep",
    workspaceType: "personal",
    name: id,
    managementState: "active",
    countsTowardLimit: true,
    membership: {endAt: kstTs("2026-10-20")},
    ...extra,
  });
  const sweepContract = (id, memberId, product, completedAt = "2026-10-01") =>
    db.collection("personal_contracts").doc(id).set({
      trainerId: "trainer-sweep",
      workspaceType: "personal",
      memberId,
      status: "completed",
      completedAt: kstTs(completedAt),
      product,
    });

  await scenario("자동 만료: 종료일이 지난 활동 회원만 만료로 옮기고 이력·관리 회원 수를 남긴다", async () => {
    await db.collection("trainer_profiles").doc("trainer-sweep").set({
      trainerId: "trainer-sweep", workspaceType: "personal", managedMemberCount: 7,
    });
    // 앞 시나리오의 회원이 이번 집계에 섞이지 않도록 종료일을 멀리 둔다.
    await db.collection("members").doc("member-exp-y").update({
      "membership.endAt": kstTs("2027-12-31"),
    });
    await sweepMember("sw-expired");
    await sweepMember("sw-today", {membership: {endAt: kstTs("2026-10-26")}});
    await sweepMember("sw-renewed");
    await sweepContract("sw-c1", "sw-renewed",
      {periodStart: "2026-10-01", periodEnd: "2027-03-31"});
    await sweepMember("sw-unlimited");
    await sweepContract("sw-c2", "sw-unlimited",
      {periodStart: "2026-01-01", periodEnd: "", periodUnlimited: true});
    await sweepMember("sw-paused", {managementState: "paused"});
    await sweepMember("sw-dormant", {managementState: "dormant"});
    await sweepMember("sw-zero-left", {
      membership: {endAt: kstTs("2026-12-31")},
      remainSessions: 0, totalSessions: 10, doneSessions: 10,
    });
    await sweepMember("sw-no-end", {membership: {}});
    await sweepMember("sw-legacy", {workspaceType: "legacy"});
    // 종료일이 지난 오래된 카드값이 있어도 더 늦은 계약 종료일이 있으면 만료하지 않는다.
    const result = await autoExpireMemberships(db, sweepNow);
    assert.equal(result.expired, 1);

    const get = async (id) => (await db.collection("members").doc(id).get()).data();
    const expired = await get("sw-expired");
    assert.equal(expired.managementState, "expired");
    assert.equal(expired.countsTowardLimit, false);
    assert.equal(expired.autoExpire.endDate, "2026-10-20");
    const entry = expired.managementStateHistory.at(-1);
    assert.equal(entry.previousState, "active");
    assert.equal(entry.nextState, "expired");
    assert.equal(entry.source, "auto_expire");
    assert.equal(entry.changedBy, "system");
    assert.equal((await profileDoc("trainer-sweep")).managedMemberCount, 6);

    for (const id of ["sw-today", "sw-renewed", "sw-unlimited", "sw-zero-left", "sw-no-end"]) {
      assert.equal((await get(id)).managementState, "active", id);
    }
    assert.equal((await get("sw-paused")).managementState, "paused");
    assert.equal((await get("sw-dormant")).managementState, "dormant");
    assert.equal((await get("sw-legacy")).managementState, "active");
  });

  await scenario("자동 만료: 다시 실행해도 중복 처리하지 않고, 선생님이 활동 중으로 되돌린 회원은 같은 종료일로 다시 만료시키지 않는다", async () => {
    const again = await autoExpireMemberships(db, sweepNow);
    assert.equal(again.expired, 0);
    assert.equal((await profileDoc("trainer-sweep")).managedMemberCount, 6);

    await db.collection("members").doc("sw-expired").update({
      managementState: "active", countsTowardLimit: true,
    });
    const skipped = await autoExpireMemberships(db, sweepNow);
    assert.equal(skipped.expired, 0);
    assert.equal((await db.collection("members").doc("sw-expired").get())
      .data().managementState, "active");

    // 종료일이 더 늦게 바뀌었다가 다시 지나면 새 종료일로 만료한다.
    await db.collection("members").doc("sw-expired").update({
      "membership.endAt": kstTs("2026-10-24"),
    });
    const next = await autoExpireMemberships(db, sweepNow);
    assert.equal(next.expired, 1);
    assert.equal((await db.collection("members").doc("sw-expired").get())
      .data().autoExpire.endDate, "2026-10-24");
  });

  await scenario("자동 만료: 계약 종료일과 카드 종료일 중 더 늦은 날을 기준으로 하고 파기된 계약은 제외한다", async () => {
    await sweepMember("sw-contract-past", {membership: {endAt: kstTs("2026-10-10")}});
    await sweepContract("sw-c3", "sw-contract-past",
      {periodStart: "2026-07-01", periodEnd: "2026-10-22"});
    // 파기·취소된 계약은 종료일 판단에서 제외한다.
    await sweepMember("sw-voided-contract", {membership: {endAt: kstTs("2026-10-10")}});
    await db.collection("personal_contracts").doc("sw-c4").set({
      trainerId: "trainer-sweep", workspaceType: "personal",
      memberId: "sw-voided-contract", status: "voided",
      completedAt: kstTs("2026-10-02"),
      product: {periodStart: "2026-10-02", periodEnd: "2027-12-31"},
    });
    const result = await autoExpireMemberships(db, sweepNow);
    assert.equal(result.expired, 2);
    const get = async (id) => (await db.collection("members").doc(id).get()).data();
    assert.equal((await get("sw-contract-past")).autoExpire.endDate, "2026-10-22");
    assert.equal((await get("sw-voided-contract")).autoExpire.endDate, "2026-10-10");
  });

  // ---------------- 설정 ----------------
  const saveSettings = createSavePersonalContractSettingsHandler(db);
  const defaultsInput = () => {
    const {terms} = validContent();
    return {
      cancelDeadline: terms.cancelDeadline,
      lateNoShowMinutes: null,
      penaltyPercent: 5,
      refundBusinessDays: 2,
      transfer: {policy: "conditional", feeType: "percent", feeValue: 5},
      expiryExtensionClause: true,
      unavoidableRefundClause: true,
    };
  };

  // ---------------- 계약서 해지(P6-6) ----------------
  const termHandler = (now) =>
    require("../functions/lib/personal_contract_terminate.js")
      .createTerminatePersonalContractHandler(db, now ? {now} : {});
  const termNow = termHandler();
  const todayKst = () => new Date(Date.now() + 9 * 60 * 60 * 1000)
    .toISOString().slice(0, 10);
  const dayKst = (offset) => new Date(Date.now() + 9 * 60 * 60 * 1000 + offset * DAY)
    .toISOString().slice(0, 10);
  const termIn = (id, extra = {}, uid = "trainer-a") => termNow({
    contractId: id,
    reasonCode: "member_request",
    reasonNote: "",
    noticeChannel: "sms",
    noticeDate: todayKst(),
    ...extra,
  }, ctx(uid));
  const eventsOf = async (id) => (await db.collection("personal_contracts")
    .doc(id).collection("events").get()).docs.map((d) => d.data());

  await scenario("해지: 서명 없이도 강사 단독 기록으로 해지되고 스냅샷·이벤트·알림이 남으며 환불은 다루지 않는다", async () => {
    const draft = await complete("term-1", "member-term-a", validContent());
    const result = await termIn(draft.contractId);
    assert.equal(result.alreadyTerminated, false);
    assert.equal(result.status, "terminated");
    assert.equal(result.evidence, "trainer_only");
    assert.deepEqual(result.snapshot, {total: 40, done: 25, remain: 15});

    const contract = await contractDoc(draft.contractId);
    assert.equal(contract.status, "terminated");
    assert.ok(contract.terminatedAt);
    assert.equal(contract.termination.reasonCode, "member_request");
    assert.equal(contract.termination.noticeChannel, "sms");
    assert.equal(contract.termination.noticeDate, todayKst());
    assert.equal(contract.termination.evidence, "trainer_only");
    assert.deepEqual(contract.termination.snapshot, {total: 40, done: 25, remain: 15});
    assert.equal(contract.signatures.terminate, undefined);
    assert.equal(Object.keys(contract.termination).some((k) => /refund|amount/i.test(k)), false);

    const events = await eventsOf(draft.contractId);
    assert.equal(events.some((e) => e.type === "terminate_signed"), false);
    const terminated = events.find((e) => e.type === "terminated");
    assert.equal(terminated.payload.previousStatus, "completed");
    assert.equal(terminated.payload.evidence, "trainer_only");

    const member = await memberDoc("member-term-a");
    assert.equal(member.contractSigned, false);
    assert.equal(member.contractStatus, "terminated");
    assert.ok(member.contractTerminatedAt);
    // 해지하면 레슨 등록은 항상 0(미등록)으로 되돌아가고, 해지 시점 값은 계약서 스냅샷에 남는다.
    assert.equal(member.totalSessions, 0);
    assert.equal(member.remainSessions, 0);
    assert.equal(member.remainingSessions, 0);
    assert.equal(member.doneSessions, 0);
    assert.equal(member.sessions.total, 0);
    assert.equal(member.sessions.remain, 0);
    assert.equal(member.sessions.done, 0);
    assert.equal(member.sessions.notRegistered, true);
    assert.equal(member.lessonsNotRegistered, true);
    assert.equal(member.lastRegistration, undefined, "마지막 등록 기록(+N 표시)이 지워진다");
    assert.equal(member.lessonType, "PT", "레슨 종류 등 다른 필드는 건드리지 않는다");
    assert.equal(member.managementState, "active", "기본은 회원 상태를 바꾸지 않는다");

    const notice = await noticeDoc(`${draft.contractId}_terminate`);
    assert.equal(notice.kind, "contract_terminate");
    assert.equal(notice.state, "pending");
    assert.match(notice.message, /해지되었습니다/);
  });

  await scenario("해지: 회원 서명이 있으면 증빙 등급이 올라가고, 만료 이동을 고르면 반영되며 관리 회원 수가 줄어든다", async () => {
    const draft = await complete("term-2", "member-term-b", validContent());
    const baseCount = Number((await profileDoc("trainer-a")).managedMemberCount ?? 0);
    const result = await termIn(draft.contractId, {
      reasonCode: "other", reasonNote: "이사로 인한 해지", noticeChannel: "kakao",
      strokes, zeroRemain: true, markExpired: true,
    });
    assert.equal(result.evidence, "member_signed");
    assert.equal(result.zeroedRemain, true);
    assert.equal(result.markedExpired, true);

    const contract = await contractDoc(draft.contractId);
    assert.equal(contract.termination.reasonNote, "이사로 인한 해지");
    assert.ok(contract.signatures.terminate.signedAt);
    const events = await eventsOf(draft.contractId);
    const signed = events.find((e) => e.type === "terminate_signed");
    assert.equal(signed.actorRole, "member");
    assert.ok(signed.payload.strokes.length > 0);

    const member = await memberDoc("member-term-b");
    assert.equal(member.remainSessions, 0);
    assert.equal(member.remainingSessions, 0);
    assert.equal(member.sessions.remain, 0);
    assert.equal(member.totalSessions, 0, "해지하면 총 횟수도 0으로 되돌린다");
    assert.equal(member.doneSessions, 0);
    assert.deepEqual(contract.termination.snapshot, {total: 40, done: 25, remain: 15},
      "해지 시점 값은 계약서에 남는다");
    assert.equal(member.managementState, "expired");
    assert.equal(member.countsTowardLimit, false);
    const last = member.managementStateHistory.at(-1);
    assert.equal(last.previousState, "active");
    assert.equal(last.nextState, "expired");
    assert.equal(last.source, "contract_terminate");
    assert.equal((await profileDoc("trainer-a")).managedMemberCount, Math.max(0, baseCount - 1));
  });

  await scenario("해지: 활동 중이 아닌 회원은 만료 이동을 골라도 상태가 바뀌지 않는다", async () => {
    const draft = await complete("term-3", "member-term-dormant", validContent());
    const baseCount = Number((await profileDoc("trainer-a")).managedMemberCount ?? 0);
    const result = await termIn(draft.contractId, {markExpired: true});
    assert.equal(result.markedExpired, false);
    assert.equal((await memberDoc("member-term-dormant")).managementState, "dormant");
    assert.equal((await profileDoc("trainer-a")).managedMemberCount, baseCount);
  });

  await scenario("해지: 이미 해지한 계약을 다시 해지해도 안전하고 기록이 늘지 않는다", async () => {
    const draft = await complete("term-4", "member-term-c", validContent());
    await termIn(draft.contractId);
    const before = (await eventsOf(draft.contractId)).length;
    const again = await termIn(draft.contractId, {zeroRemain: true});
    assert.equal(again.alreadyTerminated, true);
    assert.equal((await eventsOf(draft.contractId)).length, before);
    // 첫 해지에서 이미 0으로 되돌렸고, 두 번째 호출은 아무것도 바꾸지 않는다.
    const member = await memberDoc("member-term-c");
    assert.equal(member.remainSessions, 0);
    assert.equal(member.totalSessions, 0);
  });

  await scenario("해지: 완료 전 계약·남의 계약·잘못된 입력·날짜 범위 밖은 거부된다", async () => {
    const open = await createDraft("term-5", validContent(), "member-a");
    await expectError(termIn(open.contractId),
      "failed-precondition", "terminate_requires_completed");
    const done = await complete("term-6", "member-term-d", validContent());
    await expectError(termIn(done.contractId, {}, "trainer-b"),
      "permission-denied", "contract_owner_mismatch");
    await expectError(termNow({contractId: done.contractId}, {}), "unauthenticated");
    await expectError(termIn(done.contractId, {reasonCode: "x"}),
      "invalid-argument", "reasonCode_invalid");
    await expectError(termIn(done.contractId, {noticeChannel: "fax"}),
      "invalid-argument", "noticeChannel_invalid");
    await expectError(termIn(done.contractId, {reasonCode: "other", reasonNote: " "}),
      "invalid-argument", "reasonNote_required");
    await expectError(termIn(done.contractId, {reasonNote: "가".repeat(201)}),
      "invalid-argument", "reasonNote_invalid");
    await expectError(termIn(done.contractId, {noticeDate: "2026-02-31"}),
      "invalid-argument", "noticeDate_invalid");
    await expectError(termIn(done.contractId, {noticeDate: dayKst(1)}),
      "invalid-argument", "noticeDate_out_of_range");
    await expectError(termIn(done.contractId, {noticeDate: dayKst(-2)}),
      "invalid-argument", "noticeDate_out_of_range");
    await expectError(termIn(done.contractId, {zeroRemain: "yes"}),
      "invalid-argument", "zeroRemain_invalid");
    await expectError(termIn(done.contractId, {strokes: []}), "invalid-argument");
    await expectError(termIn(done.contractId, {refundAmount: 1000}),
      "invalid-argument", "unknown_fields");
    const contract = await contractDoc(done.contractId);
    assert.equal(contract.status, "completed", "거부되면 아무것도 바뀌지 않는다");
    assert.equal((await memberDoc("member-term-d")).contractSigned, true);
  });

  await scenario("해지: 회원의 가장 최근 완료 계약만 해지할 수 있고, 해지 후 새 계약을 다시 완료할 수 있다", async () => {
    const first = await complete("term-7a", "member-term-e", validContent());
    const second = await complete("term-7b", "member-term-e", validContent());
    await expectError(termIn(first.contractId),
      "failed-precondition", "terminate_not_latest");
    assert.equal((await contractDoc(first.contractId)).status, "completed");
    const ok = await termIn(second.contractId);
    assert.equal(ok.status, "terminated");
    assert.deepEqual(ok.snapshot, {total: 50, done: 25, remain: 25});
    // 이제 첫 계약이 최신 완료 계약이라 해지할 수 있다.
    const firstOk = await termIn(first.contractId);
    assert.equal(firstOk.status, "terminated");
    const renewed = await complete("term-7c", "member-term-e", validContent());
    const member = await memberDoc("member-term-e");
    // 해지로 0이 된 뒤 재계약하면 0에서 새로 시작한다(이전 횟수가 합산되지 않는다).
    assert.equal(member.totalSessions, 10);
    assert.equal(member.remainSessions, 10);
    assert.equal(member.doneSessions, 0);
    assert.equal(member.sessions.notRegistered, false);
    assert.equal(member.lastRegistration.added, 10);
    assert.equal(member.contractSigned, true);
    assert.equal(member.contractStatus, "completed");
    assert.equal(member.contractId, renewed.contractId);
  });

  await scenario("해지: 해지된 계약은 파기할 수 없다", async () => {
    const draft = await complete("term-8", "member-term-f", validContent());
    await termIn(draft.contractId);
    await expectError(voidIn(voidNow, draft.contractId),
      "failed-precondition", "void_requires_completed");
  });

  await scenario("설정: 당사자와 내 기본 조건이 프로필에 저장되고 서버 시각이 남는다", async () => {
    const result = await saveSettings({
      contractParty: validContent().party,
      contractDefaults: defaultsInput(),
    }, ctx("trainer-a"));
    assert.deepEqual(result.saved, ["contractDefaults", "contractParty"]);
    const profile = (await db.collection("trainer_profiles").doc("trainer-a").get()).data();
    assert.equal(profile.contractParty.name, "김트레이너");
    assert.equal(profile.contractDefaults.penaltyPercent, 5);
    assert.equal(profile.contractDefaults.refundBusinessDays, 2);
    assert.ok(profile.contractSettingsUpdatedAt);
    // 일부만 보내면 나머지는 그대로 둔다.
    await saveSettings({contractDefaults: {...defaultsInput(), penaltyPercent: 3}},
      ctx("trainer-a"));
    const after = (await db.collection("trainer_profiles").doc("trainer-a").get()).data();
    assert.equal(after.contractDefaults.penaltyPercent, 3);
    assert.equal(after.contractParty.name, "김트레이너");
  });

  await scenario("내 수업 상품: 저장·교체되고 중복·상한·금지 문구는 거부된다", async () => {
    const preset = (name, extra = {}) => ({
      name, serviceContent: "1:1 개인 트레이닝 50분", sessionCount: 10,
      sessionMinutes: 50, paidAmount: 1000000, listPrice: null, ...extra,
    });
    const saved = await saveSettings({
      contractProducts: [preset("PT 10회"), preset("PT 20회", {
        sessionCount: 20, paidAmount: 1800000, listPrice: 2400000,
      })],
    }, ctx("trainer-a"));
    assert.deepEqual(saved.saved, ["contractProducts"]);
    let profile = (await db.collection("trainer_profiles").doc("trainer-a").get()).data();
    assert.equal(profile.contractProducts.length, 2);
    assert.equal(profile.contractProducts[1].listPrice, 2400000);
    // 전체 교체: 한 개로 줄이면 한 개만 남는다.
    await saveSettings({contractProducts: [preset("PT 5회")]}, ctx("trainer-a"));
    profile = (await db.collection("trainer_profiles").doc("trainer-a").get()).data();
    assert.equal(profile.contractProducts.length, 1);
    await saveSettings({contractProducts: []}, ctx("trainer-a"));
    profile = (await db.collection("trainer_profiles").doc("trainer-a").get()).data();
    assert.equal(profile.contractProducts.length, 0);
    await expectError(
      saveSettings({contractProducts: [preset("PT"), preset("pt")]}, ctx("trainer-a")),
      "invalid-argument", "product_name_duplicate");
    await expectError(
      saveSettings({contractProducts: [preset("환불불가 상품")]}, ctx("trainer-a")),
      "invalid-argument", "forbidden_phrase:refund_denied");
    await expectError(
      saveSettings({contractProducts: [preset("PT", {listPrice: 900000})]}, ctx("trainer-a")),
      "invalid-argument", "listPrice_invalid");
    await expectError(
      saveSettings({contractProducts: [preset("PT", {sessionCount: 0})]}, ctx("trainer-a")),
      "invalid-argument", "sessionCount_invalid");
    await expectError(
      saveSettings({contractProducts: [{...preset("PT"), extra: 1}]}, ctx("trainer-a")),
      "invalid-argument", "unknown_fields");
    const many = Array.from({length: 21}, (_, i) => preset(`상품 ${i}`));
    await expectError(
      saveSettings({contractProducts: many}, ctx("trainer-a")),
      "invalid-argument", "products_too_many");
  });

  await scenario("센터 로고 경로: 마이페이지에서 저장하고 지울 수 있으며 남의 경로는 거부된다", async () => {
    const mine = "contract_logos/trainer-a/logo_1700000000001.png";
    const saved = await saveSettings({centerLogoPath: mine}, ctx("trainer-a"));
    assert.deepEqual(saved.saved, ["centerLogoPath"]);
    let profile = (await db.collection("trainer_profiles").doc("trainer-a").get()).data();
    assert.equal(profile.centerLogoPath, mine);
    // 빈 문자열은 로고 삭제
    await saveSettings({centerLogoPath: ""}, ctx("trainer-a"));
    profile = (await db.collection("trainer_profiles").doc("trainer-a").get()).data();
    assert.equal(profile.centerLogoPath, "");
    for (const bad of [
      "contract_logos/trainer-b/logo_1.png",
      "contract_logos/trainer-a/../trainer-b/logo_1.png",
      "contract_logos/trainer-a/evil.png",
      "member_profiles/trainer-a/logo_1.png",
      "contract_logos/trainer-a/logo_1.jpg",
    ]) {
      await expectError(
        saveSettings({centerLogoPath: bad}, ctx("trainer-a")),
        "invalid-argument", "logoPath_invalid");
    }
    await expectError(
      saveSettings({centerLogoPath: 5}, ctx("trainer-a")),
      "invalid-argument", "centerLogoPath_invalid");
    await expectError(
      saveSettings({centerLogoPath: "contract_logos/trainer-low/logo_1.png"}, ctx("trainer-low")),
      "failed-precondition", "semi_pro_required");
  });

  await scenario("설정 거부: 상한 초과·정상가·정액 수수료·특약·다른 사람 로고·등급·익명", async () => {
    await expectError(
      saveSettings({contractDefaults: {...defaultsInput(), penaltyPercent: 11}}, ctx("trainer-a")),
      "invalid-argument", "penaltyPercent_invalid");
    await expectError(
      saveSettings({contractDefaults: {...defaultsInput(), refundBasis: "list_price"}},
        ctx("trainer-a")),
      "invalid-argument", "unknown_fields");
    await expectError(
      saveSettings({contractDefaults: {...defaultsInput(), extraTerms: "특약"}},
        ctx("trainer-a")),
      "invalid-argument", "unknown_fields");
    await expectError(
      saveSettings({contractDefaults: {
        ...defaultsInput(),
        transfer: {policy: "conditional", feeType: "amount", feeValue: 1000},
      }}, ctx("trainer-a")),
      "invalid-argument", "transfer_amount_not_allowed_in_defaults");
    await expectError(
      saveSettings({contractParty: {
        ...validContent().party, logoPath: "contract_logos/trainer-b/logo_1.png",
      }}, ctx("trainer-a")),
      "invalid-argument", "logoPath_invalid");
    await expectError(
      saveSettings({}, ctx("trainer-a")), "invalid-argument", "no_updates");
    await expectError(
      saveSettings({contractParty: validContent().party, other: 1}, ctx("trainer-a")),
      "invalid-argument", "unknown_fields");
    await expectError(
      saveSettings({contractParty: validContent().party}, ctx("trainer-low")),
      "failed-precondition", "semi_pro_required");
    await expectError(
      saveSettings({contractParty: validContent().party}, ctx("trainer-a", "anonymous")),
      "permission-denied", "workspace_not_eligible");
    // 내 로고 경로는 허용
    const ok = await saveSettings({contractParty: {
      ...validContent().party, logoPath: "contract_logos/trainer-a/logo_1700000000000.png",
    }}, ctx("trainer-a"));
    assert.deepEqual(ok.saved, ["contractParty"]);
  });

  // ---------------- 보안 규칙 ----------------
  const env = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: "127.0.0.1",
      port: firestorePort,
      rules: fs.readFileSync("firestore.rules", "utf8"),
    },
  });
  try {
    const owner = env.authenticatedContext("trainer-a", {
      firebase: {sign_in_provider: "password"},
    }).firestore();
    const other = env.authenticatedContext("trainer-b", {
      firebase: {sign_in_provider: "password"},
    }).firestore();
    const anonymous = env.authenticatedContext("trainer-a", {
      firebase: {sign_in_provider: "anonymous"},
    }).firestore();
    const existing = (await db.collection("personal_contracts")
      .where("trainerId", "==", "trainer-a").limit(1).get()).docs[0];
    const path = ["personal_contracts", existing.id];

    await scenario("규칙: 소유자는 자기 계약과 이벤트를 읽고 목록 조회도 된다", async () => {
      await assertSucceeds(getDoc(doc(owner, ...path)));
      await assertSucceeds(getDocs(collection(owner, ...path, "events")));
      await assertSucceeds(getDocs(query(
        collection(owner, "personal_contracts"),
        where("trainerId", "==", "trainer-a"),
        orderBy("updatedAt", "desc"),
      )));
    });

    await scenario("규칙: 다른 트레이너·익명·비소유 조회는 거부된다", async () => {
      await assertFails(getDoc(doc(other, ...path)));
      await assertFails(getDocs(collection(other, ...path, "events")));
      await assertFails(getDoc(doc(anonymous, ...path)));
      await assertFails(getDocs(collection(other, "personal_contracts")));
      await assertFails(getDocs(query(
        collection(other, "personal_contracts"),
        where("trainerId", "==", "trainer-a"),
      )));
    });

    await scenario("규칙: 앱에서 계약·이벤트·카운터를 직접 쓰거나 읽을 수 없다", async () => {
      await assertFails(setDoc(doc(owner, "personal_contracts", "pc_direct"), {
        trainerId: "trainer-a", workspaceType: "personal", status: "completed",
      }));
      await assertFails(setDoc(doc(owner, ...path), {status: "completed"}, {merge: true}));
      await assertFails(setDoc(doc(owner, ...path, "events", "fake"), {type: "completed"}));
      await assertFails(getDoc(doc(owner, "personal_contract_counters", "trainer-a_202610")));
      await assertFails(setDoc(doc(owner, "personal_contract_counters", "x"), {lastSequence: 0}));
    });
  } finally {
    await env.cleanup();
  }

  process.stdout.write(`All ${passed} personal contract scenarios passed.\n`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}).finally(() => {
  setTimeout(() => process.exit(process.exitCode ?? 0), 100);
});
