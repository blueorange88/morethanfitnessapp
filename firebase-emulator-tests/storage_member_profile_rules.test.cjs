const assert = require("node:assert/strict");
const fs = require("node:fs");
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require("@firebase/rules-unit-testing");
const {ref, uploadBytes, getBytes} = require("firebase/storage");

const projectId = process.env.STORAGE_TEST_PROJECT_ID ||
  "demo-mtf-storage-member-profile";
const firestorePort = Number(process.env.STORAGE_TEST_FIRESTORE_PORT || 8080);
const storagePort = Number(process.env.STORAGE_TEST_STORAGE_PORT || 9199);
let passed = 0;

async function scenario(name, action) {
  await action();
  passed += 1;
  process.stdout.write(`PASS ${passed}: ${name}\n`);
}

function authedContext(env, uid) {
  return env.authenticatedContext(uid, {
    firebase: {sign_in_provider: "anonymous"},
  });
}

const jpegBytes = Uint8Array.from([0xff, 0xd8, 0xff, 0xd9]);

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
    const ownerUid = "owner-trainer";
    const otherUid = "other-trainer";
    const memberId = "personal-member-1";

    const ownerCtx = authedContext(env, ownerUid);
    const otherCtx = authedContext(env, otherUid);

    const ownerPath =
      `member_profiles_personal/${ownerUid}/${memberId}/profile_1.jpg`;

    await scenario(
      "개인워크스페이스 소유 트레이너는 자기 회원의 프로필 사진을 업로드할 수 있다",
      async () => {
        await assertSucceeds(
          uploadBytes(ref(ownerCtx.storage(), ownerPath), jpegBytes, {
            contentType: "image/jpeg",
          }),
        );
      },
    );

    await scenario(
      "개인워크스페이스 소유 트레이너는 업로드한 사진을 읽을 수 있다",
      async () => {
        const bytes = await assertSucceeds(
          getBytes(ref(ownerCtx.storage(), ownerPath)),
        );
        assert.equal(bytes.byteLength, jpegBytes.length);
      },
    );

    await scenario(
      "다른 트레이너는 해당 회원의 프로필 사진을 읽을 수 없다",
      async () => {
        await assertFails(getBytes(ref(otherCtx.storage(), ownerPath)));
      },
    );

    await scenario(
      "다른 트레이너는 자기 uid 경로가 아니면 업로드할 수 없다",
      async () => {
        await assertFails(
          uploadBytes(
            ref(
              otherCtx.storage(),
              `member_profiles_personal/${ownerUid}/${memberId}/profile_2.jpg`,
            ),
            jpegBytes,
            {contentType: "image/jpeg"},
          ),
        );
      },
    );

    await scenario(
      "파일명 패턴을 벗어나면 소유 트레이너라도 업로드할 수 없다",
      async () => {
        await assertFails(
          uploadBytes(
            ref(
              ownerCtx.storage(),
              `member_profiles_personal/${ownerUid}/${memberId}/not-allowed.jpg`,
            ),
            jpegBytes,
            {contentType: "image/jpeg"},
          ),
        );
      },
    );

    await scenario(
      "레거시 member_profiles 경로는 여전히 legacy admin 전용이다",
      async () => {
        await assertFails(
          uploadBytes(
            ref(ownerCtx.storage(), `member_profiles/${memberId}/profile_1.jpg`),
            jpegBytes,
            {contentType: "image/jpeg"},
          ),
        );
      },
    );

    const trainerPhotoPath = `trainer_photos/${ownerUid}/photo_1.jpg`;

    await scenario(
      "트레이너는 자기 명함 사진을 업로드할 수 있다",
      async () => {
        await assertSucceeds(
          uploadBytes(ref(ownerCtx.storage(), trainerPhotoPath), jpegBytes, {
            contentType: "image/jpeg",
          }),
        );
      },
    );

    await scenario(
      "다른 트레이너는 남의 명함 사진 경로에 업로드할 수 없다",
      async () => {
        await assertFails(
          uploadBytes(ref(otherCtx.storage(), trainerPhotoPath), jpegBytes, {
            contentType: "image/jpeg",
          }),
        );
      },
    );

    await scenario(
      "다른 트레이너는 남의 명함 사진을 읽을 수 없다",
      async () => {
        await assertFails(getBytes(ref(otherCtx.storage(), trainerPhotoPath)));
      },
    );

    assert.equal(passed, 9);
    process.stdout.write("All 9 storage member-profile rule scenarios passed.\n");
  } finally {
    await env.cleanup();
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
