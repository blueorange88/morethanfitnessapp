import {createRequire} from "node:module";
import {pathToFileURL} from "node:url";

const functionsRequire = createRequire(
  new URL("../functions/package.json", import.meta.url),
);

export const PLATFORM_ADMIN_EMAIL = "mtgroup.fitnessapp@gmail.com";
export const PLATFORM_ADMIN_DISPLAY_NAME = "LEON";

export async function upsertPlatformAdmin({
  auth,
  firestore,
  password,
  dryRun = false,
  logger = console,
  serverTimestamp = () => null,
}) {
  if (!dryRun && (!password || password.length < 6)) {
    throw new Error("A hidden temporary password of at least 6 characters is required.");
  }

  let existingUser = null;
  try {
    existingUser = await auth.getUserByEmail(PLATFORM_ADMIN_EMAIL);
  } catch (error) {
    if (error?.code !== "auth/user-not-found") throw error;
  }

  const profileRef = existingUser
    ? firestore.collection("trainer_profiles").doc(existingUser.uid)
    : null;
  const existingProfile = profileRef ? await profileRef.get() : null;

  if (dryRun) {
    logger.info(
      existingUser
        ? "DRY RUN: existing administrator account would be updated."
        : "DRY RUN: administrator account would be created.",
    );
    logger.info(
      existingProfile?.exists
        ? "DRY RUN: existing canonical profile would be preserved and gated."
        : "DRY RUN: canonical linked Beginner personal profile would be created.",
    );
    return {dryRun: true, created: false, uid: existingUser?.uid ?? null};
  }

  const user = existingUser ?? await auth.createUser({
    email: PLATFORM_ADMIN_EMAIL,
    displayName: PLATFORM_ADMIN_DISPLAY_NAME,
    password,
    emailVerified: true,
  });
  if (existingUser) {
    await auth.updateUser(user.uid, {
      displayName: PLATFORM_ADMIN_DISPLAY_NAME,
      password,
    });
  }

  const refreshedUser = await auth.getUser(user.uid);
  await auth.setCustomUserClaims(user.uid, {
    ...(refreshedUser.customClaims ?? {}),
    platformAdmin: true,
    legacyDataAccessApproved: true,
  });

  const targetRef = firestore.collection("trainer_profiles").doc(user.uid);
  await firestore.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(targetRef);
    const now = serverTimestamp();
    if (snapshot.exists) {
      const data = snapshot.data() ?? {};
      if (data.trainerId !== user.uid) {
        throw new Error("Existing profile identity does not match the Auth UID.");
      }
      transaction.update(targetRef, {
        displayName: PLATFORM_ADMIN_DISPLAY_NAME,
        mustChangePassword: true,
        passwordChangedAt: null,
        platformAdminProvisionedAt: now,
        updatedAt: now,
      });
      return;
    }
    transaction.create(targetRef, {
      trainerId: user.uid,
      displayName: PLATFORM_ADMIN_DISPLAY_NAME,
      accountState: "linked",
      tier: "Beginner",
      workspaceType: "personal",
      workspaceStatus: "active",
      role: "personal",
      schemaVersion: 1,
      managedMemberCount: 0,
      managedMemberLimit: 10,
      mustChangePassword: true,
      passwordChangedAt: null,
      platformAdminProvisionedAt: now,
      usageUpdatedAt: now,
      createdAt: now,
      updatedAt: now,
    });
  });

  logger.info(existingUser ? "Administrator account updated." : "Administrator account created.");
  logger.info("Claims and password-change gate applied. No legacy data was migrated.");
  return {dryRun: false, created: !existingUser, uid: user.uid};
}

export async function readHiddenPassword({
  input = process.stdin,
  output = process.stderr,
} = {}) {
  if (!input.isTTY || typeof input.setRawMode !== "function") {
    throw new Error("An interactive terminal is required for hidden password input.");
  }
  output.write("Temporary password: ");
  input.setRawMode(true);
  input.resume();
  input.setEncoding("utf8");
  return await new Promise((resolve, reject) => {
    let value = "";
    const cleanup = () => {
      input.setRawMode(false);
      input.pause();
      input.removeListener("data", onData);
      output.write("\n");
    };
    const onData = (chunk) => {
      for (const character of chunk) {
        if (character === "\u0003") {
          cleanup();
          reject(new Error("Password input cancelled."));
          return;
        }
        if (character === "\r" || character === "\n") {
          cleanup();
          resolve(value);
          return;
        }
        if (character === "\u007f" || character === "\b") {
          value = value.slice(0, -1);
        } else {
          value += character;
        }
      }
    };
    input.on("data", onData);
  });
}

async function main() {
  const args = new Set(process.argv.slice(2));
  const allowed = new Set(["--dry-run"]);
  for (const argument of args) {
    if (!allowed.has(argument)) {
      throw new Error("Only --dry-run is supported. Password CLI arguments are forbidden.");
    }
  }
  const dryRun = args.has("--dry-run");
  const {applicationDefault, getApps, initializeApp} = functionsRequire(
    "firebase-admin/app",
  );
  const {getAuth} = functionsRequire("firebase-admin/auth");
  const {FieldValue, getFirestore} = functionsRequire("firebase-admin/firestore");
  const app = getApps()[0] ?? initializeApp({credential: applicationDefault()});
  const firestore = getFirestore(app);
  const password = dryRun ? null : await readHiddenPassword();
  await upsertPlatformAdmin({
    auth: getAuth(app),
    firestore,
    password,
    dryRun,
    serverTimestamp: () => FieldValue.serverTimestamp(),
  });
}

const isDirectExecution = process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href;
if (isDirectExecution) {
  main().catch(() => {
    console.error("Provisioning failed. No credential details were logged.");
    process.exitCode = 1;
  });
}
