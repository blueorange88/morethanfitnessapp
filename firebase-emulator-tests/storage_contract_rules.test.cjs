// 레슨계약서 v2 Storage 규칙 시나리오: 당사자 로고(contract_logos)와 완료본 PDF(personal_contracts).
// Firestore·Storage 에뮬레이터가 필요하다(PDF 규칙이 계약 문서를 교차 조회한다).
const assert = require("node:assert/strict");
const fs = require("node:fs");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {ref, uploadBytes, getBytes, deleteObject} = require("firebase/storage");

const projectId = process.env.STORAGE_TEST_PROJECT_ID ||
  "demo-mtf-storage-contract";
const firestorePort = Number(process.env.STORAGE_TEST_FIRESTORE_PORT || 8080);
const storagePort = Number(process.env.STORAGE_TEST_STORAGE_PORT || 9199);
let passed = 0;

async function scenario(name, action) {
  await action();
  passed += 1;
  process.stdout.write(`PASS ${passed}: ${name}\n`);
}

function ctxFor(env, uid, provider = "password") {
  return env.authenticatedContext(uid, {firebase: {sign_in_provider: provider}});
}

const png = Uint8Array.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
const pdf = Uint8Array.from([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31, 0x2e, 0x34]);
const MB = 1024 * 1024;

const id = (n) => `pc_${String(n).padStart(32, "a")}`;

async function main() {
  const env = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: "127.0.0.1",
      port: firestorePort,
      rules: fs.readFileSync("firestore.rules", "utf8"),
    },
    storage: {
      host: "127.0.0.1",
      port: storagePort,
      rules: fs.readFileSync("storage.rules", "utf8"),
    },
  });

  try {
    const owner = "owner-trainer";
    const other = "other-trainer";

    // 계약 문서: 규칙은 trainerId·status·version을 본다.
    const seed = {
      [id(1)]: {trainerId: owner, status: "completed", version: 2},
      [id(2)]: {trainerId: owner, status: "completed", version: 1},
      [id(3)]: {trainerId: owner, status: "draft", version: 1},
      [id(4)]: {trainerId: owner, status: "terminated", version: 1},
      [id(5)]: {trainerId: other, status: "completed", version: 1},
      [id(6)]: {trainerId: owner, status: "completed", version: 1},
      [id(7)]: {trainerId: owner, status: "completed", version: 1},
      [id(8)]: {trainerId: owner, status: "completed", version: 1},
      [id(9)]: {trainerId: owner, status: "completed", version: 1},
    };
    await env.withSecurityRulesDisabled(async (context) => {
      for (const [contractId, data] of Object.entries(seed)) {
        await context.firestore().collection("personal_contracts")
          .doc(contractId).set({workspaceType: "personal", ...data});
      }
    });

    const ownerCtx = ctxFor(env, owner);
    const otherCtx = ctxFor(env, other);
    const anonCtx = ctxFor(env, owner, "anonymous");
    const noAuth = env.unauthenticatedContext();
    const upload = (context, path, bytes, contentType) =>
      uploadBytes(ref(context.storage(), path), bytes, {contentType});

    // ---------------- 당사자 로고 ----------------
    const logoPath = `contract_logos/${owner}/logo_1730000000.png`;

    await scenario("로고: 본인이 PNG 2MB 이하를 logo_숫자.png 이름으로 올릴 수 있다", async () => {
      await assertSucceeds(upload(ownerCtx, logoPath, png, "image/png"));
    });

    await scenario("로고: 본인은 읽고 지울 수 있고 다른 트레이너·비로그인은 읽을 수 없다", async () => {
      const bytes = await assertSucceeds(getBytes(ref(ownerCtx.storage(), logoPath)));
      assert.equal(bytes.byteLength, png.length);
      await assertFails(getBytes(ref(otherCtx.storage(), logoPath)));
      await assertFails(getBytes(ref(noAuth.storage(), logoPath)));
      await assertFails(deleteObject(ref(otherCtx.storage(), logoPath)));
      await assertSucceeds(deleteObject(ref(ownerCtx.storage(), logoPath)));
    });

    await scenario("로고: 남의 경로·비로그인·익명 로그인은 올릴 수 없다", async () => {
      await assertFails(upload(otherCtx, logoPath, png, "image/png"));
      await assertFails(upload(noAuth, logoPath, png, "image/png"));
      await assertFails(upload(anonCtx, logoPath, png, "image/png"));
    });

    await scenario("로고: 파일 이름·형식·크기가 맞지 않으면 올릴 수 없다", async () => {
      for (const name of ["logo.png", "logo_1.jpg", "photo_1.png", "logo_a.png"]) {
        await assertFails(upload(ownerCtx, `contract_logos/${owner}/${name}`, png, "image/png"));
      }
      await assertFails(upload(ownerCtx, `contract_logos/${owner}/logo_2.png`, png, "image/jpeg"));
      await assertFails(upload(
        ownerCtx,
        `contract_logos/${owner}/logo_3.png`,
        new Uint8Array(2 * MB + 1),
        "image/png",
      ));
      await assertSucceeds(upload(
        ownerCtx,
        `contract_logos/${owner}/logo_4.png`,
        new Uint8Array(2 * MB),
        "image/png",
      ));
    });

    // ---------------- 완료본 PDF ----------------
    const pdfPath = (uid, contractId, name) =>
      `personal_contracts/${uid}/${contractId}/${name}`;

    await scenario("PDF: 완료된 자기 계약에 현재 버전 이름(contract_v{n}.pdf)으로 올릴 수 있다", async () => {
      await assertSucceeds(upload(ownerCtx, pdfPath(owner, id(1), "contract_v2.pdf"), pdf, "application/pdf"));
    });

    await scenario("PDF: 본인만 읽을 수 있고 다른 트레이너·비로그인은 읽을 수 없다", async () => {
      const path = pdfPath(owner, id(1), "contract_v2.pdf");
      const bytes = await assertSucceeds(getBytes(ref(ownerCtx.storage(), path)));
      assert.equal(bytes.byteLength, pdf.length);
      await assertFails(getBytes(ref(otherCtx.storage(), path)));
      await assertFails(getBytes(ref(noAuth.storage(), path)));
    });

    await scenario("PDF: 이미 올라간 파일은 덮어쓰거나 지울 수 없다", async () => {
      const path = pdfPath(owner, id(1), "contract_v2.pdf");
      await assertFails(upload(ownerCtx, path, Uint8Array.from([1, 2, 3]), "application/pdf"));
      await assertFails(deleteObject(ref(ownerCtx.storage(), path)));
      const bytes = await getBytes(ref(ownerCtx.storage(), path));
      assert.equal(bytes.byteLength, pdf.length, "내용이 바뀌지 않았다");
    });

    await scenario("PDF: 계약의 현재 버전과 다른 파일 이름은 거부된다", async () => {
      // id(2)는 버전 1이다.
      await assertFails(upload(ownerCtx, pdfPath(owner, id(2), "contract_v2.pdf"), pdf, "application/pdf"));
      await assertFails(upload(ownerCtx, pdfPath(owner, id(2), "contract.pdf"), pdf, "application/pdf"));
      await assertFails(upload(ownerCtx, pdfPath(owner, id(2), "contract_v1.pdf.bak"), pdf, "application/pdf"));
      await assertSucceeds(upload(ownerCtx, pdfPath(owner, id(2), "contract_v1.pdf"), pdf, "application/pdf"));
    });

    await scenario("PDF: 완료되지 않은(작성 중) 계약·해지된 계약·없는 계약에는 올릴 수 없다", async () => {
      await assertFails(upload(ownerCtx, pdfPath(owner, id(3), "contract_v1.pdf"), pdf, "application/pdf"));
      await assertFails(upload(ownerCtx, pdfPath(owner, id(4), "contract_v1.pdf"), pdf, "application/pdf"));
      await assertFails(upload(ownerCtx, pdfPath(owner, id(99), "contract_v1.pdf"), pdf, "application/pdf"));
    });

    await scenario("PDF: 다른 트레이너의 계약에는 올릴 수 없고, 남의 경로에도 올릴 수 없다", async () => {
      // id(5)는 other의 계약이다. owner가 자기 uid 경로에 올려도 계약 소유자가 다르다.
      await assertFails(upload(ownerCtx, pdfPath(owner, id(5), "contract_v1.pdf"), pdf, "application/pdf"));
      // owner의 계약 id(6)를 other가 owner 경로·자기 경로 어디에 올려도 거부된다.
      await assertFails(upload(otherCtx, pdfPath(owner, id(6), "contract_v1.pdf"), pdf, "application/pdf"));
      await assertFails(upload(otherCtx, pdfPath(other, id(6), "contract_v1.pdf"), pdf, "application/pdf"));
    });

    await scenario("PDF: 비로그인·익명 로그인은 올릴 수 없다", async () => {
      await assertFails(upload(noAuth, pdfPath(owner, id(7), "contract_v1.pdf"), pdf, "application/pdf"));
      await assertFails(upload(anonCtx, pdfPath(owner, id(7), "contract_v1.pdf"), pdf, "application/pdf"));
    });

    await scenario("PDF: 형식(PDF)·크기(비어 있지 않음, 10MB 이하)·계약 ID 형식이 맞지 않으면 거부된다", async () => {
      await assertFails(upload(ownerCtx, pdfPath(owner, id(8), "contract_v1.pdf"), png, "image/png"));
      await assertFails(upload(ownerCtx, pdfPath(owner, id(8), "contract_v1.pdf"), new Uint8Array(0), "application/pdf"));
      await assertFails(upload(
        ownerCtx,
        pdfPath(owner, id(8), "contract_v1.pdf"),
        new Uint8Array(10 * MB + 1),
        "application/pdf",
      ));
      await assertFails(upload(ownerCtx, pdfPath(owner, "pc_xyz", "contract_v1.pdf"), pdf, "application/pdf"));
      // 위의 거부 뒤에도 같은 계약에 올바른 파일은 올릴 수 있다(거부는 아무것도 남기지 않는다).
      await assertSucceeds(upload(ownerCtx, pdfPath(owner, id(8), "contract_v1.pdf"), pdf, "application/pdf"));
    });

    await scenario("PDF: 계약이 완료 상태가 아니게 된 뒤에는 새로 올릴 수 없다(해지·파기 뒤)", async () => {
      await env.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection("personal_contracts").doc(id(9))
          .update({status: "voided"});
      });
      await assertFails(upload(ownerCtx, pdfPath(owner, id(9), "contract_v1.pdf"), pdf, "application/pdf"));
    });

    // ---------------- 규칙에 없는 경로 ----------------
    await scenario("계약 경로 밖의 임의 경로는 기본적으로 거부된다", async () => {
      await assertFails(upload(ownerCtx, `personal_contracts/${owner}/loose.pdf`, pdf, "application/pdf"));
      await assertFails(upload(ownerCtx, `contract_pdfs/${owner}/${id(1)}/contract_v1.pdf`, pdf, "application/pdf"));
    });
  } finally {
    await env.cleanup();
  }

  process.stdout.write(`All ${passed} storage contract rule scenarios passed.\n`);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
}).finally(() => {
  setTimeout(() => process.exit(process.exitCode ?? 0), 100);
});
