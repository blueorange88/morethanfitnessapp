// P0 실측: 일반(personal) 트레이너가 레거시 계약 경로에 쓸 수 있는가?
// 현재 규칙에서 계약 관련 경로는 레거시 관리자(platformAdmin + legacyDataAccessApproved)
// 전용이다. 이 테스트는 그 사실을 고정하는 회귀 테스트이기도 하다
// (레슨계약서 v2는 레거시 경로를 바꾸지 않고 새 컬렉션을 추가한다).
const fs = require("node:fs");
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
  limit,
  orderBy,
  query,
  setDoc,
  serverTimestamp,
} = require("firebase/firestore");
const {deleteObject, getBytes, ref, uploadBytes} = require("firebase/storage");

const projectId = process.env.CONTRACT_PROBE_PROJECT_ID ||
  "demo-mtf-contract-access-probe";
const firestorePort = Number(process.env.CONTRACT_PROBE_FIRESTORE_PORT || 8080);
const storagePort = Number(process.env.CONTRACT_PROBE_STORAGE_PORT || 9199);
let passed = 0;

async function scenario(name, action) {
  await action();
  passed += 1;
  process.stdout.write(`PASS ${passed}: ${name}\n`);
}

const png = Uint8Array.from([0x89, 0x50, 0x4e, 0x47]);

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
    await env.clearFirestore();
    await env.clearStorage();

    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      for (const uid of ["trainer-a", "legacy-admin"]) {
        await setDoc(doc(db, "trainer_profiles", uid), {
          trainerId: uid,
          mustChangePassword: false,
          workspaceType: "personal",
        });
      }
      await setDoc(doc(db, "members", "member-a"), {
        name: "회원A",
        trainerId: "trainer-a",
        workspaceType: "personal",
      });
      await setDoc(doc(db, "contracts", "someone-elses"), {status: "draft"});
    });

    // 일반 트레이너: 비로그인 익명이 아닌 이메일 로그인 계정, 관리자 권한 없음.
    const trainer = env.authenticatedContext("trainer-a", {
      firebase: {sign_in_provider: "password"},
    });
    const trainerDb = trainer.firestore();

    // 비교 대조군: 레거시 관리자.
    const admin = env.authenticatedContext("legacy-admin", {
      firebase: {sign_in_provider: "password"},
      platformAdmin: true,
      legacyDataAccessApproved: true,
    });
    const adminDb = admin.firestore();

    await scenario("일반 트레이너는 contracts에 계약을 만들 수 없다", async () => {
      await assertFails(
        setDoc(doc(trainerDb, "contracts", "new-contract"), {
          memberId: "member-a",
          status: "step1Saved",
          createdAt: serverTimestamp(),
        }),
      );
    });

    await scenario(
      "일반 트레이너는 contracts를 읽을 수 없다(소유자 필터 없는 목록 조회 포함)",
      async () => {
        await assertFails(getDoc(doc(trainerDb, "contracts", "someone-elses")));
        await assertFails(
          getDocs(
            query(
              collection(trainerDb, "contracts"),
              orderBy("updatedAt", "desc"),
              limit(50),
            ),
          ),
        );
      },
    );

    await scenario(
      "일반 트레이너는 자기 회원 문서에 계약 정보를 직접 쓸 수 없다",
      async () => {
        await assertFails(
          setDoc(
            doc(trainerDb, "members", "member-a"),
            {
              contractId: "c1",
              contractNo: "PT-0001",
              contractSigned: true,
              lastContractSummary: {totalPrice: 1000000},
            },
            {merge: true},
          ),
        );
      },
    );

    await scenario(
      "일반 트레이너는 회원권계약서 하위 문서를 읽고 쓸 수 없다",
      async () => {
        const path = ["members", "member-a", "membership_contracts", "current"];
        await assertFails(
          setDoc(doc(trainerDb, ...path), {status: "draft"}),
        );
        await assertFails(getDoc(doc(trainerDb, ...path)));
      },
    );

    await scenario("일반 트레이너는 계약 서명·이미지를 Storage에 올릴 수 없다", async () => {
      await assertFails(
        uploadBytes(
          ref(
            trainer.storage(),
            "membership_contract_signatures/member-a/signature_1.png",
          ),
          png,
          {contentType: "image/png"},
        ),
      );
      await assertFails(
        uploadBytes(
          ref(
            trainer.storage(),
            "membership_contract_images/member-a/contract_1.png",
          ),
          png,
          {contentType: "image/png"},
        ),
      );
    });

    await scenario(
      "대조군: 레거시 관리자는 contracts를 읽고 쓸 수 있다",
      async () => {
        await assertSucceeds(
          setDoc(doc(adminDb, "contracts", "admin-contract"), {
            status: "draft",
          }),
        );
        await assertSucceeds(getDoc(doc(adminDb, "contracts", "someone-elses")));
      },
    );

    // 레슨계약서 v2 당사자 로고(contract_logos): 본인 비익명 계정만 PNG 2MB 이하.
    const logoPath = (uid, name) => `contract_logos/${uid}/${name}`;
    await scenario("로고: 본인만 logo_숫자.png(2MB 이하)를 올리고 읽을 수 있다", async () => {
      await assertSucceeds(uploadBytes(
        ref(trainer.storage(), logoPath("trainer-a", "logo_1700000000000.png")),
        png,
        {contentType: "image/png"},
      ));
      await assertSucceeds(getBytes(
        ref(trainer.storage(), logoPath("trainer-a", "logo_1700000000000.png")),
      ));
      const stranger = env.authenticatedContext("someone-else", {
        firebase: {sign_in_provider: "password"},
      });
      await assertFails(uploadBytes(
        ref(stranger.storage(), logoPath("trainer-a", "logo_1.png")),
        png,
        {contentType: "image/png"},
      ));
      await assertFails(getBytes(
        ref(stranger.storage(), logoPath("trainer-a", "logo_1700000000000.png")),
      ));
    });

    await scenario("로고: 익명·JPEG·잘못된 이름·2MB 초과는 거부된다", async () => {
      const anon = env.authenticatedContext("trainer-a", {
        firebase: {sign_in_provider: "anonymous"},
      });
      await assertFails(uploadBytes(
        ref(anon.storage(), logoPath("trainer-a", "logo_2.png")),
        png,
        {contentType: "image/png"},
      ));
      await assertFails(uploadBytes(
        ref(trainer.storage(), logoPath("trainer-a", "logo_3.jpg")),
        png,
        {contentType: "image/jpeg"},
      ));
      await assertFails(uploadBytes(
        ref(trainer.storage(), logoPath("trainer-a", "logo_4.png")),
        png,
        {contentType: "image/jpeg"},
      ));
      await assertFails(uploadBytes(
        ref(trainer.storage(), logoPath("trainer-a", "evil.png")),
        png,
        {contentType: "image/png"},
      ));
      await assertFails(uploadBytes(
        ref(trainer.storage(), logoPath("trainer-a", "logo_5.png")),
        new Uint8Array(2 * 1024 * 1024 + 1),
        {contentType: "image/png"},
      ));
    });

    // 레슨계약서 v2 완료본 PDF(personal_contracts): 완료된 본인 계약에 한 번만, PDF 10MB 이하.
    const pdf = new Uint8Array([0x25, 0x50, 0x44, 0x46, 0x2d]);
    const contractId = "pc_" + "a".repeat(32);
    const draftId = "pc_" + "b".repeat(32);
    const otherId = "pc_" + "c".repeat(32);
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, "personal_contracts", contractId),
        {trainerId: "trainer-a", status: "completed", version: 2});
      await setDoc(doc(db, "personal_contracts", draftId),
        {trainerId: "trainer-a", status: "draft", version: 1});
      await setDoc(doc(db, "personal_contracts", otherId),
        {trainerId: "someone-else", status: "completed", version: 1});
    });
    const pdfPath = (uid, id, name) => `personal_contracts/${uid}/${id}/${name}`;
    const pdfType = {contentType: "application/pdf"};
    await scenario("계약 PDF: 완료된 본인 계약에 현재 버전 이름으로 한 번만 올릴 수 있다", async () => {
      const path = pdfPath("trainer-a", contractId, "contract_v2.pdf");
      await assertSucceeds(uploadBytes(ref(trainer.storage(), path), pdf, pdfType));
      // 본인은 읽을 수 있고, 다른 사람은 못 읽는다.
      await assertSucceeds(getBytes(ref(trainer.storage(), path)));
      const stranger = env.authenticatedContext("someone-else", {
        firebase: {sign_in_provider: "password"},
      });
      await assertFails(getBytes(ref(stranger.storage(), path)));
      // 같은 이름으로 다시 올리기(덮어쓰기)는 거부된다.
      await assertFails(uploadBytes(
        ref(trainer.storage(), path),
        new Uint8Array([0x25, 0x50, 0x44, 0x46, 0x2d, 0x31]),
        pdfType,
      ));
    });

    await scenario("계약 PDF: 미완료·남의 계약·없는 계약·틀린 버전 이름은 거부된다", async () => {
      const upload = (path) => uploadBytes(ref(trainer.storage(), path), pdf, pdfType);
      // 아직 완료되지 않은 계약
      await assertFails(upload(pdfPath("trainer-a", draftId, "contract_v1.pdf")));
      // 다른 트레이너의 계약(경로 uid를 내 것으로 해도 계약 소유자가 달라 거부)
      await assertFails(upload(pdfPath("trainer-a", otherId, "contract_v1.pdf")));
      // 다른 사람 경로로 올리기
      await assertFails(upload(pdfPath("someone-else", otherId, "contract_v1.pdf")));
      // 계약 문서가 없는 ID
      await assertFails(upload(pdfPath("trainer-a", "pc_" + "d".repeat(32), "contract_v1.pdf")));
      // 완료 계약이지만 버전이 맞지 않는 이름(현재 버전은 2)
      await assertFails(upload(pdfPath("trainer-a", contractId, "contract_v1.pdf")));
      await assertFails(upload(pdfPath("trainer-a", contractId, "evil.pdf")));
    });

    await scenario("계약 PDF: PDF가 아닌 형식·10MB 초과·빈 파일·익명·삭제는 거부된다", async () => {
      const fresh = "pc_" + "e".repeat(32);
      await env.withSecurityRulesDisabled(async (ctx) => {
        await setDoc(doc(ctx.firestore(), "personal_contracts", fresh),
          {trainerId: "trainer-a", status: "completed", version: 1});
      });
      const path = pdfPath("trainer-a", fresh, "contract_v1.pdf");
      await assertFails(uploadBytes(ref(trainer.storage(), path), pdf,
        {contentType: "image/png"}));
      await assertFails(uploadBytes(ref(trainer.storage(), path),
        new Uint8Array(10 * 1024 * 1024 + 1), pdfType));
      await assertFails(uploadBytes(ref(trainer.storage(), path), new Uint8Array(0), pdfType));
      const anon = env.authenticatedContext("trainer-a", {
        firebase: {sign_in_provider: "anonymous"},
      });
      await assertFails(uploadBytes(ref(anon.storage(), path), pdf, pdfType));
      // 올바른 업로드는 통과하지만 삭제는 거부된다.
      await assertSucceeds(uploadBytes(ref(trainer.storage(), path), pdf, pdfType));
      await assertFails(deleteObject(ref(trainer.storage(), path)));
    });

    process.stdout.write(`All ${passed} contract access probe scenarios passed.\n`);
  } finally {
    await env.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
