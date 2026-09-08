import assert from "node:assert/strict";
import { after, before, beforeEach, test } from "node:test";
import { readFileSync } from "node:fs";
import { initializeTestEnvironment, assertFails, assertSucceeds } from "@firebase/rules-unit-testing";
import { doc, getDoc, setDoc, updateDoc, writeBatch, Timestamp } from "firebase/firestore";
import {
  accountDeletionContext, discoverAccountDeletionSummary, stageAccountDeletionSummary,
  executeAccountDeletion, createClassroom, joinClassroom, deleteClassroom,
  cleanupUnreferencedEvidence, cleanupExpiredReviewedEvidence, evidenceObjectIsCurrent,
} from "../../workers/englishplus-ai-proxy/src/index.js";

const PROJECT_ID = "demo-englishplus-audit-repair";
const now = Timestamp.now();
let testEnv;
const env = {
  FIREBASE_PROJECT_ID: PROJECT_ID,
  FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080",
  VOLUNTEER_EVIDENCE: { list: async () => ({ objects: [], truncated: false }), delete: async () => {} },
};
const profile = (role, classId = null) => ({
  displayName: role, preferredName: role, primaryRole: role, activeClassId: classId,
  active: true, accountStatus: "active", createdAt: now, updatedAt: now,
});
before(async () => {
  testEnv = await initializeTestEnvironment({ projectId: PROJECT_ID, firestore: {
    host: "127.0.0.1", port: 8080,
    rules: readFileSync(new URL("../../docs/ios-testflight/firebase/firestore.rules.draft", import.meta.url), "utf8"),
  } });
});
beforeEach(async () => testEnv.clearFirestore());
after(async () => testEnv?.cleanup());
async function admin(run) { return testEnv.withSecurityRulesDisabled((ctx) => run(ctx.firestore())); }
async function classroom() {
  await admin(async (db) => {
    await setDoc(doc(db, "users/teacher"), profile("teacher"));
    await setDoc(doc(db, "users/student"), profile("student"));
  });
  return createClassroom(env, { sub: "teacher" }, "Repair integration class");
}

test("email policy applies to Worker classroom operations and verified users still work", async () => {
  await admin((db) => setDoc(doc(db, "users/teacher"), { ...profile("teacher"), emailVerificationRequired: true }));
  await assert.rejects(() => createClassroom(env, { sub: "teacher", email_verified: false }, "Blocked"),
    (error) => error.code === "EMAIL_VERIFICATION_REQUIRED");
  assert.ok((await createClassroom(env, { sub: "teacher", email_verified: true }, "Allowed")).classId);
});

test("joining again preserves learning progress and unrelated summary fields", async () => {
  const room = await classroom();
  await joinClassroom(env, { sub: "student" }, room.joinCode);
  const path = `classes/${room.classId}/students/student`;
  const progress = { currentLevel: "B2", riskLevel: "high", lastMissionStatus: "completed", totalCorrect: 42 };
  await admin((db) => updateDoc(doc(db, path), progress));
  await joinClassroom(env, { sub: "student" }, room.joinCode);
  await admin(async (db) => {
    const result = (await getDoc(doc(db, path))).data();
    for (const [key, value] of Object.entries(progress)) assert.equal(result[key], value);
  });
});

test("account deletion removes volunteer service mirrors, requests and nested review events", async () => {
  const paths = ["users/volunteer/volunteerServices/CLASS-A", "users/volunteer/learningWriteReceipts/op-1", "classes/CLASS-A/volunteerRequests/volunteer",
    "volunteerApplications/volunteer/reviewEvents/review-1"];
  await admin(async (db) => {
    await setDoc(doc(db, "users/volunteer"), profile("volunteer"));
    await setDoc(doc(db, "volunteerApplications/volunteer"), { uid: "volunteer", status: "rejected" });
    for (const path of paths) await setDoc(doc(db, path), { volunteerUid: "volunteer", privateNote: "fixture" });
  });
  assert.equal((await executeAccountDeletion(env, "volunteer")).completed, true);
  await admin(async (db) => {
    for (const path of paths) assert.equal((await getDoc(doc(db, path))).exists(), false, path);
  });
});

test("concurrent successor deletion cannot leave an active class owned by a missing account", async () => {
  const room = await classroom();
  await admin(async (db) => {
    await setDoc(doc(db, "users/successor"), profile("teacher", room.classId));
    await setDoc(doc(db, `classes/${room.classId}/members/successor`), {
      uid: "successor", role: "teacher", status: "active", active: true,
    });
  });
  const context = await accountDeletionContext(env, "teacher");
  await stageAccountDeletionSummary(context, await discoverAccountDeletionSummary(context), false, { [room.classId]: "successor" });
  const originalFetch = globalThis.fetch;
  let interleaved = false;
  globalThis.fetch = async (url, options) => {
    const writes = options?.body && String(url).endsWith(":commit") ? JSON.parse(options.body).writes : [];
    if (!interleaved && writes.some((write) => write.update?.fields?.ownerTeacherUid?.stringValue === "successor")) {
      interleaved = true;
      await executeAccountDeletion(env, "successor");
    }
    return originalFetch(url, options);
  };
  try { await assert.rejects(() => executeAccountDeletion(env, "teacher", context)); }
  finally { globalThis.fetch = originalFetch; }
  assert.equal(interleaved, true);
  await admin(async (db) => {
    assert.equal((await getDoc(doc(db, `classes/${room.classId}`))).data().ownerTeacherUid, "teacher");
    assert.equal((await getDoc(doc(db, "users/successor"))).exists(), false);
  });
  assert.equal((await executeAccountDeletion(env, "teacher")).completed, true);
  await admin(async (db) => assert.equal((await getDoc(doc(db, `classes/${room.classId}`))).data().active, false));
});

test("class deletion resumes after a batch failure and reconciles already-left members", async () => {
  const room = await classroom();
  const uids = Array.from({ length: 90 }, (_, index) => `student-${index.toString().padStart(3, "0")}`);
  await admin(async (db) => {
    const batch = writeBatch(db);
    for (const uid of uids) {
      batch.set(doc(db, `users/${uid}`), profile("student", room.classId));
      batch.set(doc(db, `users/${uid}/classMemberships/${room.classId}`), { status: "active", active: true });
      batch.set(doc(db, `classes/${room.classId}/members/${uid}`), { uid, role: "student", status: "active", active: true });
      batch.set(doc(db, `classes/${room.classId}/students/${uid}`), { uid, membershipStatus: "active" });
    }
    await batch.commit();
  });
  const originalFetch = globalThis.fetch;
  let memberBatches = 0;
  globalThis.fetch = async (url, options) => {
    const writes = options?.body && String(url).endsWith(":commit") ? JSON.parse(options.body).writes : [];
    if (writes.some((write) => write.update?.name?.includes("/members/student-") && write.update.fields.status?.stringValue === "left")) {
      memberBatches += 1;
      if (memberBatches === 2) return new Response(JSON.stringify({ error: { message: "Injected batch failure" } }), { status: 503 });
    }
    return originalFetch(url, options);
  };
  try { await assert.rejects(() => deleteClassroom(env, { sub: "teacher" }, room.classId)); }
  finally { globalThis.fetch = originalFetch; }
  assert.equal(memberBatches, 2);
  assert.equal((await deleteClassroom(env, { sub: "teacher" }, room.classId)).deleted, true);
  await admin(async (db) => {
    for (const uid of uids) {
      assert.equal((await getDoc(doc(db, `users/${uid}`))).data().activeClassId, null, uid);
      assert.equal((await getDoc(doc(db, `classes/${room.classId}/students/${uid}`))).data().membershipStatus, "left", uid);
    }
  });
});

test("uploaded drafts are recoverable while applicants cannot edit review controls", async () => {
  for (const status of ["draft", "needsMoreInformation", "rejected"]) {
    await admin(async (db) => {
      await setDoc(doc(db, "users/volunteer"), { ...profile("volunteer"), active: false, accountStatus: "pendingApplication" });
      await setDoc(doc(db, "volunteerApplications/volunteer"), { uid: "volunteer", status, evidence: [], reviewNote: "Keep", updatedAt: now });
    });
    const db = testEnv.authenticatedContext("volunteer", { email_verified: true }).firestore();
    await assertSucceeds(updateDoc(doc(db, "volunteerApplications/volunteer"), {
      evidence: [{ id: "new", storageObjectKey: "volunteer-evidence/volunteer/new.pdf" }], motivation: "Draft", updatedAt: Timestamp.now(),
    }));
    assert.equal((await getDoc(doc(db, "volunteerApplications/volunteer"))).data().evidence.length, 1);
    await assertFails(updateDoc(doc(db, "volunteerApplications/volunteer"), { reviewNote: "Changed" }));
    await assertFails(updateDoc(doc(db, "volunteerApplications/volunteer"), { evidenceDeletedAt: null }));
  }
});

test("orphan cleanup frees old uploads and retains referenced or recent files", async () => {
  const key = (id) => `volunteer-evidence/volunteer/${id}.pdf`;
  await admin((db) => setDoc(doc(db, "volunteerApplications/volunteer"), { evidence: [{ storageObjectKey: key("keep") }] }));
  const objects = ["orphan", "keep", "recent"].map((id) => ({
    key: key(id), customMetadata: { ownerUid: "volunteer", uploadState: "complete",
      uploadedAt: id === "recent" ? "2026-09-07T00:00:00Z" : "2026-01-01T00:00:00Z" },
  }));
  const deleted = [];
  const count = await cleanupUnreferencedEvidence({ ...env, VOLUNTEER_EVIDENCE: { delete: async (value) => deleted.push(value) } }, objects, new Date("2026-09-08T00:00:00Z"));
  assert.equal(count, 1);
  assert.deepEqual(deleted, [key("orphan")]);
  assert.equal(evidenceObjectIsCurrent(objects[2], "2026-08-01T00:00:00Z"), true);
  assert.equal(evidenceObjectIsCurrent(objects[0], "2026-08-01T00:00:00Z"), false);
});

test("review retention cleanup cannot erase a concurrently saved new application", async () => {
  const path = "volunteerApplications/volunteer";
  const oldKey = "volunteer-evidence/volunteer/old.pdf";
  const newKey = "volunteer-evidence/volunteer/new.pdf";
  await admin((db) => setDoc(doc(db, path), {
    uid: "volunteer", status: "rejected", reviewedAt: Timestamp.fromDate(new Date("2026-01-01T00:00:00Z")),
    evidence: [{ storageObjectKey: oldKey }],
  }));
  const deleted = [];
  const cleanupEnv = { ...env, VOLUNTEER_EVIDENCE: {
    list: async () => ({ objects: [], truncated: false }), delete: async (key) => deleted.push(key),
    head: async () => ({ customMetadata: { uploadedAt: "2025-12-01T00:00:00Z" } }),
  } };
  const originalFetch = globalThis.fetch;
  let interleaved = false;
  globalThis.fetch = async (url, options) => {
    const writes = options?.body && String(url).endsWith(":commit") ? JSON.parse(options.body).writes : [];
    if (!interleaved && writes.some((write) => write.update?.fields?.evidenceDeletedAt)) {
      interleaved = true;
      await admin((db) => updateDoc(doc(db, path), { status: "pendingReview", evidence: [{ storageObjectKey: newKey }] }));
    }
    return originalFetch(url, options);
  };
  try { await assert.rejects(() => cleanupExpiredReviewedEvidence(cleanupEnv, new Date("2026-09-08T00:00:00Z"))); }
  finally { globalThis.fetch = originalFetch; }
  assert.equal(interleaved, true);
  assert.deepEqual(deleted, []);
  await admin(async (db) => assert.equal((await getDoc(doc(db, path))).data().evidence[0].storageObjectKey, newKey));
});

test("an expired rejected review preserves evidence saved for the next submission before cleanup starts", async () => {
  const oldKey = "volunteer-evidence/volunteer/old.pdf";
  const newKey = "volunteer-evidence/volunteer/new.pdf";
  await admin((db) => setDoc(doc(db, "volunteerApplications/volunteer"), {
    uid: "volunteer", status: "rejected", reviewedAt: Timestamp.fromDate(new Date("2026-01-01T00:00:00Z")),
    evidence: [{ storageObjectKey: oldKey }, { storageObjectKey: newKey }],
  }));
  const deleted = [];
  await cleanupExpiredReviewedEvidence({ ...env, VOLUNTEER_EVIDENCE: {
    list: async () => ({ objects: [], truncated: false }),
    head: async (key) => ({ customMetadata: { uploadedAt: key === oldKey ? "2025-12-01T00:00:00Z" : "2026-09-01T00:00:00Z" } }),
    delete: async (key) => deleted.push(key),
  } }, new Date("2026-09-08T00:00:00Z"));
  assert.deepEqual(deleted, [oldKey]);
  await admin(async (db) => {
    const result = (await getDoc(doc(db, "volunteerApplications/volunteer"))).data();
    assert.deepEqual(result.evidence, [{ storageObjectKey: newKey }]);
    assert.equal(result.evidenceDeletedAt, null);
    assert.deepEqual(result.retiredEvidenceKeys, [oldKey]);
  });
});

async function orphanDraftFixture() {
  await admin(async (db) => {
    await setDoc(doc(db, "users/volunteer"), { ...profile("volunteer"), active: false, accountStatus: "pendingApplication" });
    await setDoc(doc(db, "volunteerApplications/volunteer"), { uid: "volunteer", status: "draft", evidence: [] });
  });
  const key = "volunteer-evidence/volunteer/recovered.pdf";
  return { key, db: testEnv.authenticatedContext("volunteer", { email_verified: true }).firestore(),
    objects: [{ key, customMetadata: { ownerUid: "volunteer", uploadState: "complete", uploadedAt: "2026-01-01T00:00:00Z" } }] };
}

test("orphan retirement prevents a late draft from claiming a file after cleanup committed", async () => {
  const { key, db, objects } = await orphanDraftFixture();
  const path = doc(db, "volunteerApplications/volunteer");
  let deleted = false;
  await cleanupUnreferencedEvidence({ ...env, VOLUNTEER_EVIDENCE: { delete: async () => {
    await assertFails(updateDoc(path, { evidence: [{ storageObjectKey: key }] }));
    deleted = true;
  } } }, objects, new Date("2026-09-08T00:00:00Z"));
  assert.equal(deleted, true);
  const application = (await getDoc(path)).data();
  assert.equal(application.uid, "volunteer");
  assert.equal(application.status, "draft");
  await assertSucceeds(updateDoc(path, { evidence: [{ storageObjectKey: "volunteer-evidence/volunteer/fresh.pdf" }] }));
});

test("a recovered draft that commits first defeats an orphan cleanup version claim", async () => {
  const { key, db, objects } = await orphanDraftFixture();
  const deleted = [];
  const originalFetch = globalThis.fetch;
  let interleaved = false;
  globalThis.fetch = async (url, options) => {
    const writes = options?.body && String(url).endsWith(":commit") ? JSON.parse(options.body).writes : [];
    if (!interleaved && writes.some((write) => write.updateTransforms?.some((transform) => transform.fieldPath === "retiredEvidenceKeys"))) {
      interleaved = true;
      await assertSucceeds(updateDoc(doc(db, "volunteerApplications/volunteer"), { evidence: [{ storageObjectKey: key }] }));
    }
    return originalFetch(url, options);
  };
  try { await assert.rejects(() => cleanupUnreferencedEvidence({ ...env, VOLUNTEER_EVIDENCE: { delete: async (value) => deleted.push(value) } }, objects, new Date("2026-09-08T00:00:00Z"))); }
  finally { globalThis.fetch = originalFetch; }
  assert.equal(interleaved, true);
  assert.deepEqual(deleted, []);
  assert.equal((await getDoc(doc(db, "volunteerApplications/volunteer"))).data().evidence[0].storageObjectKey, key);
});

test("learning write receipts make replay atomic and cannot overwrite newer progress", async () => {
  await admin((db) => setDoc(doc(db, "users/student"), profile("student")));
  const db = testEnv.authenticatedContext("student", { email_verified: true }).firestore();
  const receipt = doc(db, "users/student/learningWriteReceipts/operation-1");
  const progress = doc(db, "users/student/settings/learningFlow");
  const replay = () => {
    const batch = writeBatch(db);
    batch.set(receipt, { operationId: "operation-1", createdAt: now });
    batch.set(progress, { completed: 1 });
    return batch.commit();
  };
  await assertSucceeds(replay());
  await assertSucceeds(setDoc(progress, { completed: 2 }));
  await assertFails(replay());
  assert.equal((await getDoc(receipt)).data().operationId, "operation-1");
  assert.equal((await getDoc(progress)).data().completed, 2);
  const stranger = testEnv.authenticatedContext("stranger").firestore();
  await assertFails(getDoc(doc(stranger, "users/student/learningWriteReceipts/operation-1")));
  await assertFails(setDoc(doc(db, "users/student/learningWriteReceipts/wrong-id"), { operationId: "operation-1", createdAt: now }));
});

test("confirmed deletion intent blocks new client records while account cleanup is in progress", async () => {
  await admin((db) => setDoc(doc(db, "users/student"), profile("student")));
  const context = await accountDeletionContext(env, "student");
  await stageAccountDeletionSummary(context, await discoverAccountDeletionSummary(context), false, {});
  const db = testEnv.authenticatedContext("student", { email_verified: true }).firestore();
  await assertFails(setDoc(doc(db, "users/student/learningWriteReceipts/late"), { operationId: "late", createdAt: now }));
  await assertFails(setDoc(doc(db, "users/student/personalAnswerEvents/late"), { studentUid: "student", createdAt: now }));
  await assertSucceeds(getDoc(doc(db, "users/student"))); // The deletion UI can still recover its account state.
});

function masteryPayload(at, attempts = 1) {
  return { masteryId: "mastery-q1", studentUid: "student", curriculumKey: "grammar.be-verbs.present",
    unit: "Be verbs", skill: "Present-tense be verbs", questionType: "grammar", level: "A2",
    attemptCount: attempts, correctCount: attempts, firstTryCorrectCount: attempts, consecutiveCorrectCount: attempts,
    masteryScore: 60, lastQuestionId: "q1", lastResultCorrect: true, lastAttemptSource: "dailyMission",
    lastAnsweredAt: at, nextReviewAt: at, updatedAt: at };
}

test("client mission and answer payloads commit together with summary, mastery and receipts", async () => {
  const room = await classroom();
  await joinClassroom(env, { sub: "student" }, room.joinCode);
  const db = testEnv.authenticatedContext("student", { email_verified: true }).firestore();
  const root = `classes/${room.classId}/students/student`;
  const createdAt = Timestamp.now();
  const summary = { uid: "student", displayName: "Student", classCode: room.classId, currentLevel: "A2",
    recommendedTrack: "steady", lastMoodScore: 3, lastMissionStatus: "active", lastActivityAt: createdAt,
    riskLevel: "low", membershipStatus: "active", updatedAt: createdAt };
  const mission = { missionId: "mission-1", dateKey: "2026-09-08", classId: room.classId, studentUid: "student",
    sourceCheckInId: "checkin-1", status: "active", track: "steady", targetCorrectCount: 1, correctCount: 0,
    progressPercent: 0, recommendedMinutes: 3, questionIds: ["q1"], createdAt, completedAt: null };
  const start = writeBatch(db);
  start.set(doc(db, "users/student/learningWriteReceipts/start"), { operationId: "start", createdAt });
  start.set(doc(db, `${root}/checkIns/2026-09-08`), { dateKey: "2026-09-08", classId: room.classId, studentUid: "student",
    moodScore: 3, availableTimeLevel: 2, wantsChallenge: false, preferredQuestionTypes: ["grammar"], recommendedMinutes: 3, createdAt });
  start.set(doc(db, `${root}/dailyMissions/mission-1`), mission, { merge: true });
  start.set(doc(db, root), summary, { merge: true });
  await assertSucceeds(start.commit());
  const answeredAt = Timestamp.now();
  const answer = writeBatch(db);
  answer.set(doc(db, "users/student/learningWriteReceipts/answer"), { operationId: "answer", createdAt: answeredAt });
  answer.set(doc(db, `${root}/answerEvents/answer-1`), { eventId: "answer-1", questionId: "q1", missionId: "mission-1",
    prompt: "I ___ a student.", studentAnswer: "am", acceptedAnswer: "am", isCorrect: true, attemptNumber: 1,
    aiExplanation: "Use am with I", repairHint: "Look at the subject", createdAt: answeredAt });
  answer.set(doc(db, `${root}/dailyMissions/mission-1`), { ...mission, status: "completed", correctCount: 1, progressPercent: 100, completedAt: answeredAt }, { merge: true });
  answer.set(doc(db, `${root}/skillMastery/mastery-q1`), masteryPayload(answeredAt), { merge: true });
  answer.set(doc(db, root), { ...summary, lastMissionStatus: "completed", lastActivityAt: answeredAt, updatedAt: answeredAt }, { merge: true });
  await assertSucceeds(answer.commit());
  assert.equal((await getDoc(doc(db, `${root}/dailyMissions/mission-1`))).data().correctCount, 1);
  assert.equal((await getDoc(doc(db, `${root}/skillMastery/mastery-q1`))).data().attemptCount, 1);
});

test("rebasing a stale mastery projection preserves one atomic answer and one receipt", async () => {
  await admin((db) => setDoc(doc(db, "users/student"), profile("student")));
  const db = testEnv.authenticatedContext("student", { email_verified: true }).firestore();
  const ahead = Timestamp.fromMillis(now.toMillis() + 1000);
  const mastery = doc(db, "users/student/skillMastery/mastery-q1");
  await assertSucceeds(setDoc(mastery, masteryPayload(ahead, 10)));
  const answer = doc(db, "users/student/personalAnswerEvents/offline-answer");
  const receipt = doc(db, "users/student/learningWriteReceipts/offline-answer");
  const commit = (projection) => {
    const batch = writeBatch(db);
    batch.set(receipt, { operationId: "offline-answer", createdAt: now });
    batch.set(answer, { eventId: "offline-answer", isCorrect: true, createdAt: now });
    batch.set(mastery, projection, { merge: true });
    return batch.commit();
  };
  await assertFails(commit(masteryPayload(now, 1)));
  assert.equal((await getDoc(answer)).exists(), false);
  assert.equal((await getDoc(receipt)).exists(), false);
  await assertSucceeds(commit({ ...masteryPayload(Timestamp.fromMillis(ahead.toMillis() + 1), 11), firstTryCorrectCount: 10 }));
  const saved = (await getDoc(mastery)).data();
  assert.equal(saved.attemptCount, 11);
  assert.equal(saved.correctCount, 11);
  assert.equal(saved.firstTryCorrectCount, 10);
  await assertFails(commit({ ...masteryPayload(Timestamp.fromMillis(ahead.toMillis() + 2), 12), firstTryCorrectCount: 10 }));
  assert.equal((await getDoc(mastery)).data().attemptCount, 11);
});
