import { readFileSync } from "node:fs";
import { after, before, beforeEach, test } from "node:test";
import assert from "node:assert/strict";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  Timestamp,
  doc,
  getDoc,
  setDoc,
  writeBatch,
} from "firebase/firestore";

const PROJECT_ID = "demo-englishplus-volunteer-resubmission";
const HOST = "127.0.0.1";
const PORT = 8080;
const UID = "resubmittingVolunteer";
const reviewedAt = Timestamp.fromDate(new Date("2026-07-14T08:00:00.000Z"));
const submittedAt = Timestamp.fromDate(new Date("2026-07-14T09:00:00.000Z"));
const RULES = readFileSync(
  new URL("../../docs/ios-testflight/firebase/firestore.rules.draft", import.meta.url),
  "utf8"
);

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { host: HOST, port: PORT, rules: RULES },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

function profile() {
  return {
    displayName: "Volunteer",
    preferredName: "Volunteer",
    primaryRole: "volunteer",
    activeClassId: null,
    active: false,
    accountStatus: "pendingApplication",
    provisioningSource: "selfServiceVolunteer",
    identityProviders: ["emailPassword"],
    createdAt: reviewedAt,
    updatedAt: reviewedAt,
  };
}

function application(status, reviewNote) {
  return {
    uid: UID,
    displayName: "Volunteer",
    status,
    confirmsAge18OrOlder: true,
    acceptedConductVersion: "2026-07",
    motivation: "I want to help students practice English.",
    evidence: [{ id: "evidence-1", storageObjectKey: "volunteer/evidence-1.pdf" }],
    submittedAt: reviewedAt,
    updatedAt: reviewedAt,
    reviewNote,
    reviewedAt,
  };
}

async function seedReviewState(status, reviewNote) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", UID), profile());
    await setDoc(doc(db, "volunteerApplications", UID), application(status, reviewNote));
  });
}

async function resubmit(db) {
  const batch = writeBatch(db);
  batch.update(doc(db, "users", UID), {
    accountStatus: "pendingApproval",
    active: false,
    updatedAt: submittedAt,
  });
  batch.update(doc(db, "volunteerApplications", UID), {
    status: "pendingReview",
    motivation: "Updated motivation after reviewing the administrator note.",
    evidence: [{ id: "evidence-2", storageObjectKey: "volunteer/evidence-2.pdf" }],
    submittedAt,
    updatedAt: submittedAt,
  });
  return batch.commit();
}

for (const [status, reviewNote] of [
  ["needsMoreInformation", "Please upload a readable enrollment certificate."],
  ["rejected", "The submitted document did not establish eligibility."],
]) {
  test(`${status} volunteer can resubmit while the administrator note remains visible`, async () => {
    await seedReviewState(status, reviewNote);
    const db = testEnv.authenticatedContext(UID, { email_verified: true }).firestore();

    await assertSucceeds(resubmit(db));

    const profileSnapshot = await getDoc(doc(db, "users", UID));
    const applicationSnapshot = await getDoc(doc(db, "volunteerApplications", UID));
    assert.equal(profileSnapshot.data().accountStatus, "pendingApproval");
    assert.equal(applicationSnapshot.data().status, "pendingReview");
    assert.equal(applicationSnapshot.data().reviewNote, reviewNote);
  });
}

test("volunteer cannot resubmit only the application without restoring pending approval", async () => {
  await seedReviewState("needsMoreInformation", "Please add a clearer document.");
  const db = testEnv.authenticatedContext(UID, { email_verified: true }).firestore();

  await assertFails(setDoc(
    doc(db, "volunteerApplications", UID),
    {
      status: "pendingReview",
      motivation: "Trying to bypass the account transition.",
      evidence: [{ id: "evidence-2", storageObjectKey: "volunteer/evidence-2.pdf" }],
      submittedAt,
      updatedAt: submittedAt,
    },
    { merge: true }
  ));
});
