import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { readFileSync } from "node:fs";
import { initializeTestEnvironment } from "@firebase/rules-unit-testing";
import {
  Timestamp,
  doc,
  getDoc,
  setDoc,
} from "firebase/firestore";
import {
  accountDeletionContext,
  accountDeletionJobProgress,
  discoverAccountDeletionSummary,
  executeAccountDeletion,
  processClassStudentDataBatch,
  processLegacySupportMessageBatch,
  processOwnedClassBatch,
  stageAccountDeletionSummary,
} from "../../workers/englishplus-ai-proxy/src/index.js";

const PROJECT_ID = "demo-englishplus-round11";
const HOST = "127.0.0.1";
const PORT = 8080;
const UID = "teacher-delete";
const MEMBER_UID = "student-retained";
const CLASS_ID = "CLASS-DELETE";
const NOW = Timestamp.fromDate(new Date("2026-07-13T00:00:00.000Z"));
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

function profile(role, activeClassId = null) {
  return {
    displayName: role,
    preferredName: role,
    primaryRole: role,
    activeClassId,
    active: true,
    accountStatus: "active",
    provisioningSource: role === "teacher" ? "selfServiceTeacher" : "selfServiceStudent",
    identityProviders: ["emailPassword"],
    createdAt: NOW,
    updatedAt: NOW,
  };
}

async function seedDeletionAccount() {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", UID), profile("teacher"));
    await setDoc(doc(db, "teacherProfiles", UID), {
      uid: UID,
      institutionName: "Test school",
    });
    await setDoc(doc(db, "users", MEMBER_UID), profile("student", CLASS_ID));
    await setDoc(doc(db, "users", UID, "classMemberships", CLASS_ID), {
      uid: UID,
      classId: CLASS_ID,
      status: "active",
    });
    await setDoc(doc(db, "users", MEMBER_UID, "classMemberships", CLASS_ID), {
      uid: MEMBER_UID,
      classId: CLASS_ID,
      status: "active",
    });
    await setDoc(doc(db, "classes", CLASS_ID), {
      classId: CLASS_ID,
      name: "Deletion integration class",
      ownerTeacherUid: UID,
      active: true,
      createdAt: NOW,
      updatedAt: NOW,
    });
    await setDoc(doc(db, "classAdmins", CLASS_ID), {
      classId: CLASS_ID,
      ownerTeacherUid: UID,
      joinCode: "DELETE11",
    });
    await setDoc(doc(db, "classJoinCodes", "DELETE11"), {
      classId: CLASS_ID,
      active: true,
    });
    for (const [memberUid, role] of [[UID, "teacher"], [MEMBER_UID, "student"]]) {
      await setDoc(doc(db, "classes", CLASS_ID, "members", memberUid), {
        uid: memberUid,
        classId: CLASS_ID,
        displayName: memberUid,
        role,
        status: "active",
        active: true,
        joinedAt: NOW,
        visibilityStartsAt: NOW,
        updatedAt: NOW,
      });
    }
    await setDoc(doc(db, "classes", CLASS_ID, "students", UID), {
      uid: UID,
      displayName: UID,
      classCode: CLASS_ID,
      membershipStatus: "active",
      createdAt: NOW,
      updatedAt: NOW,
    });
    await setDoc(doc(db, "classes", CLASS_ID, "students", UID, "dailyMissions", "mission-1"), {
      studentUid: UID,
      status: "active",
      createdAt: NOW,
    });
    await setDoc(doc(db, "classes", CLASS_ID, "supportThreads", "legacy-thread"), {
      threadId: "legacy-thread",
      studentUid: UID,
      classId: CLASS_ID,
      messageContextVersion: 1,
      status: "open",
      handledByUid: UID,
      createdAt: NOW,
      updatedAt: NOW,
    });
    await setDoc(doc(db, "classes", CLASS_ID, "supportThreads", "legacy-thread", "messages", "message-1"), {
      messageId: "message-1",
      authorUid: UID,
      authorName: "Deleting teacher",
      body: "Identifiable message",
      createdAt: NOW,
    });
    await setDoc(doc(db, "classes", CLASS_ID, "practiceAssignments", "assignment-1"), {
      assignmentId: "assignment-1",
      classId: CLASS_ID,
      studentUid: MEMBER_UID,
      assignedByUid: UID,
      assignedByName: "Deleting teacher",
      status: "pending",
      questionIds: ["q-1"],
      createdAt: NOW,
      updatedAt: NOW,
    });
  });
}

test("staged account deletion removes identifiable data and preserves only safe class history", async () => {
  await seedDeletionAccount();
  const env = {
    FIREBASE_PROJECT_ID: PROJECT_ID,
    FIRESTORE_EMULATOR_HOST: `${HOST}:${PORT}`,
    VOLUNTEER_EVIDENCE: {
      list: async () => ({ objects: [], truncated: false }),
      delete: async () => undefined,
    },
  };
  const context = await accountDeletionContext(env, UID);
  const summary = await discoverAccountDeletionSummary(context);
  assert.deepEqual(summary.legacyThreadPaths, [`classes/${CLASS_ID}/supportThreads/legacy-thread`]);
  assert.deepEqual(summary.ownedClassPaths, [`classes/${CLASS_ID}`]);
  assert.deepEqual(summary.classStudentPaths, [`classes/${CLASS_ID}/students/${UID}`]);

  await stageAccountDeletionSummary(context, summary, false);
  assert.equal(accountDeletionJobProgress(context.job).phase, "legacySupportMessages");
  assert.equal((await processLegacySupportMessageBatch(context)).phase, "ownedClasses");
  assert.equal((await processOwnedClassBatch(context)).phase, "classStudentData");
  assert.equal((await processClassStudentDataBatch(context)).phase, "ready");

  const result = await executeAccountDeletion(env, UID, context);
  assert.equal(result.completed, true);
  assert.equal(result.retainedData, "anonymousAggregateOnly");
  assert.equal(result.archivedOwnedClasses, 1);

  await testEnv.withSecurityRulesDisabled(async (adminContext) => {
    const db = adminContext.firestore();
    assert.equal((await getDoc(doc(db, "users", UID))).exists(), false);
    assert.equal((await getDoc(doc(db, "teacherProfiles", UID))).exists(), false);
    assert.equal((await getDoc(doc(db, "classes", CLASS_ID, "students", UID))).exists(), false);
    assert.equal((await getDoc(doc(db, "classes", CLASS_ID, "students", UID, "dailyMissions", "mission-1"))).exists(), false);
    assert.equal((await getDoc(doc(db, "classes", CLASS_ID, "supportThreads", "legacy-thread"))).exists(), false);
    assert.equal((await getDoc(doc(db, "accountDeletionJobs", UID))).exists(), false);

    const classroom = (await getDoc(doc(db, "classes", CLASS_ID))).data();
    assert.equal(classroom.ownerTeacherUid, "deleted-account");
    assert.equal(classroom.active, false);
    const retainedMember = (await getDoc(doc(db, "classes", CLASS_ID, "members", MEMBER_UID))).data();
    assert.equal(retainedMember.status, "left");
    assert.equal((await getDoc(doc(db, "users", MEMBER_UID, "classMemberships", CLASS_ID))).exists(), false);
    assert.equal((await getDoc(doc(db, "users", MEMBER_UID))).data().activeClassId, null);

    const assignment = (await getDoc(doc(db, "classes", CLASS_ID, "practiceAssignments", "assignment-1"))).data();
    assert.equal(assignment.status, "withdrawn");
    assert.equal(assignment.assignedByUid, "deleted-account");
    assert.equal(assignment.assignedByName, "已刪除的老師");

    const metric = (await getDoc(doc(db, "anonymousProductMetrics", "account-deletions-2026-07"))).data();
    assert.equal(metric.totalAccountsDeleted, 1);
    assert.equal(JSON.stringify(metric).includes(UID), false);
  });
});
