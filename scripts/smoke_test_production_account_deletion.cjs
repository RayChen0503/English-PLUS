#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");
const admin = require("../functions/node_modules/firebase-admin");

const ROOT = path.resolve(__dirname, "..");
const PROJECT_ID = "englishplus-production";
const WORKER_BASE_URL = "https://englishplus-ai-proxy-production.englishplus-ray.workers.dev";
const POLICY_VERSION = "2026-07-13";
const MAX_DELETE_ROUNDS = 12;

function fail(message) {
  throw new Error(message);
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function parseEnv(filePath) {
  const result = {};
  for (const line of fs.readFileSync(filePath, "utf8").split(/\r?\n/)) {
    const match = line.match(/^([^#=]+)=(.*)$/);
    if (match) result[match[1].trim()] = match[2].trim();
  }
  return result;
}

function serviceAccount() {
  const filePath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!filePath || !fs.existsSync(filePath)) {
    fail("GOOGLE_APPLICATION_CREDENTIALS must point to the production service account file.");
  }
  const credentials = readJson(filePath);
  if (credentials.project_id !== PROJECT_ID) {
    fail(`Refusing to run against unexpected project ${credentials.project_id || "unknown"}.`);
  }
  return credentials;
}

async function passwordSignIn(apiKey, email, password) {
  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(apiKey)}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, password, returnSecureToken: true }),
    }
  );
  const payload = await response.json().catch(() => ({}));
  if (!response.ok || !payload.idToken) {
    fail(`Disposable account sign-in failed with HTTP ${response.status}.`);
  }
  return payload.idToken;
}

async function workerRequest(pathname, idToken, options = {}) {
  const response = await fetch(`${WORKER_BASE_URL}${pathname}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(options.headers || {}),
      Authorization: `Bearer ${idToken}`,
    },
  });
  const payload = await response.json().catch(() => ({}));
  return { response, payload };
}

async function authUserExists(auth, uid) {
  try {
    await auth.getUser(uid);
    return true;
  } catch (error) {
    if (error?.code === "auth/user-not-found") return false;
    throw error;
  }
}

async function main() {
  if (process.argv[2] !== "--confirm" || process.argv[3] !== PROJECT_ID) {
    fail(`Run with --confirm ${PROJECT_ID}; only a disposable account will be created and deleted.`);
  }

  const credentials = serviceAccount();
  const env = parseEnv(path.join(ROOT, "admin-web", ".env.production"));
  const apiKey = env.VITE_FIREBASE_API_KEY;
  if (!apiKey) fail("Production Firebase Web API key is unavailable.");

  admin.initializeApp({
    credential: admin.credential.cert(credentials),
    projectId: PROJECT_ID,
  });
  const auth = admin.auth();
  const db = admin.firestore();
  const suffix = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
  const email = `account-deletion-smoke-${suffix}@example.invalid`;
  const password = `Smoke-${suffix}-aA7!`;
  let uid = null;

  try {
    const user = await auth.createUser({
      email,
      password,
      displayName: "Account Deletion Smoke Test",
      emailVerified: true,
    });
    uid = user.uid;
    await db.doc(`users/${uid}`).set({
      uid,
      email,
      displayName: "Account Deletion Smoke Test",
      primaryRole: "student",
      roles: ["student"],
      active: true,
      accountStatus: "active",
      identityProviders: ["emailPassword"],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const idToken = await passwordSignIn(apiKey, email, password);
    const preview = await workerRequest("/account/deletion-preview", idToken);
    if (!preview.response.ok || preview.payload?.ok !== true || !preview.payload?.preview) {
      fail(
        `Deletion preview failed with HTTP ${preview.response.status} `
        + `(${preview.payload?.error || "UNKNOWN"}).`
      );
    }

    let completed = false;
    for (let round = 1; round <= MAX_DELETE_ROUNDS; round += 1) {
      const deletion = await workerRequest("/account", idToken, {
        method: "DELETE",
        body: JSON.stringify({
          confirmation: "DELETE",
          policyVersion: POLICY_VERSION,
          classTransfers: {},
        }),
      });
      if (!deletion.response.ok) {
        fail(
          `Deletion round ${round} failed with HTTP ${deletion.response.status} `
          + `(${deletion.payload?.error || "UNKNOWN"}).`
        );
      }
      if (deletion.payload?.result?.completed === true) {
        completed = true;
        break;
      }
    }
    if (!completed) fail(`Deletion did not complete within ${MAX_DELETE_ROUNDS} rounds.`);

    if (await authUserExists(auth, uid)) fail("Firebase Auth user still exists after deletion.");
    if ((await db.doc(`users/${uid}`).get()).exists) fail("User profile still exists after deletion.");

    console.log("Production account deletion smoke test passed");
    console.log("- deletion preview accepted a fresh authenticated account");
    console.log("- backend cleanup completed through the public Worker contract");
    console.log("- Firebase Auth user and identifiable profile were removed");
  } finally {
    if (uid && await authUserExists(auth, uid)) {
      await auth.deleteUser(uid);
    }
    if (uid) {
      await Promise.all([
        db.doc(`users/${uid}`).delete().catch(() => {}),
        db.doc(`accountDeletionJobs/${uid}`).delete().catch(() => {}),
      ]);
    }
    await admin.app().delete();
  }
}

main().catch((error) => {
  console.error(`Production account deletion smoke test failed: ${error.message}`);
  process.exitCode = 1;
});
