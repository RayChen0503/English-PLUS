import assert from "node:assert/strict";
import { after, before, beforeEach, test } from "node:test";
import { readFileSync } from "node:fs";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from "@firebase/rules-unit-testing";
import {
  Timestamp,
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
} from "firebase/firestore";
import {
  createClassroom,
  deleteClassroom,
  getVolunteerInviteCode,
  joinClassroom,
  leaveVolunteerService,
  listClassroomVolunteers,
  listClassroomsForUser,
  listVolunteerServices,
  requestVolunteerService,
  resetVolunteerInviteCode,
  reviewVolunteerService,
} from "../../workers/englishplus-ai-proxy/src/index.js";

const PROJECT_ID = "demo-englishplus-fix-e";
const HOST = "127.0.0.1";
const PORT = 8080;
const RULES = readFileSync(
  new URL("../../docs/ios-testflight/firebase/firestore.rules.draft", import.meta.url),
  "utf8"
);

const teacher = { sub: "fixETeacher", name: "Teacher", email: "teacher@example.test" };
const student = { sub: "fixEStudent", name: "Student", email: "student@example.test" };
const volunteer = { sub: "fixEVolunteer", name: "Volunteer", email: "volunteer@example.test" };
const outsider = { sub: "fixEOutsider", name: "Outsider", email: "outsider@example.test" };
const now = Timestamp.fromDate(new Date("2026-07-14T06:00:00.000Z"));
const env = {
  FIREBASE_PROJECT_ID: PROJECT_ID,
  FIRESTORE_EMULATOR_HOST: `${HOST}:${PORT}`,
};

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
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", teacher.sub), profile("teacher", "selfServiceTeacher"));
    await setDoc(doc(db, "users", student.sub), profile("student", "selfServiceStudent"));
    await setDoc(doc(db, "users", volunteer.sub), profile(
      "volunteer",
      "administratorApprovedVolunteer"
    ));
    await setDoc(doc(db, "users", outsider.sub), profile(
      "volunteer",
      "administratorApprovedVolunteer"
    ));
  });
});

function profile(role, provisioningSource) {
  return {
    displayName: role,
    preferredName: role,
    primaryRole: role,
    activeClassId: null,
    active: true,
    accountStatus: "active",
    provisioningSource,
    identityProviders: ["emailPassword"],
    createdAt: now,
    updatedAt: now,
  };
}

function dbFor(uid) {
  return testEnv.authenticatedContext(uid, { email_verified: true }).firestore();
}

async function createReadyClass() {
  const classroom = await createClassroom(env, teacher, "FIX-E service class");
  await joinClassroom(env, student, classroom.joinCode);
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "classes", classroom.classId, "supportThreads", "question-help"), {
      threadId: "question-help",
      studentUid: student.sub,
      studentName: "Student",
      classId: classroom.classId,
      studentVisible: true,
      messageContextVersion: 2,
      status: "waitingForStaff",
      reason: "stuckOnQuestion",
      route: "humanHandoff",
      priority: "medium",
      studentMessage: "I need help.",
      questionSnapshot: {
        mapValue: {
          fields: {
            prompt: { stringValue: "Choose the correct verb." },
            correctAnswer: { stringValue: "is" },
            explanation: { stringValue: "A singular subject takes is." },
          },
        },
      },
      createdAt: now,
      updatedAt: now,
    });
    await setDoc(doc(db, "classes", classroom.classId, "students", student.sub), {
      uid: student.sub,
      displayName: "Student",
      classCode: classroom.classId,
      membershipStatus: "active",
      lastMoodScore: 2,
      createdAt: now,
      updatedAt: now,
    });
  });
  return classroom;
}

test("approved platform volunteer still needs teacher-approved class scope", async () => {
  const classroom = await createReadyClass();
  const invitation = await resetVolunteerInviteCode(env, teacher, classroom.classId);
  assert.equal(invitation.code.length, 8);
  assert.deepEqual(await getVolunteerInviteCode(env, teacher, classroom.classId), invitation);

  const pending = await requestVolunteerService(env, volunteer, invitation.code);
  assert.equal(pending.status, "pendingApproval");
  assert.equal((await listVolunteerServices(env, volunteer))[0].classId, classroom.classId);
  assert.equal((await listClassroomVolunteers(env, teacher, classroom.classId))[0].status, "pendingApproval");

  const volunteerDb = dbFor(volunteer.sub);
  await assertFails(getDoc(doc(volunteerDb, "classes", classroom.classId)));
  await assertFails(getDoc(doc(
    volunteerDb,
    "classes",
    classroom.classId,
    "supportThreads",
    "question-help"
  )));

  await reviewVolunteerService(env, teacher, classroom.classId, volunteer.sub, "approve");
  assert.equal((await listVolunteerServices(env, volunteer))[0].status, "active");
  assert.equal((await listClassroomsForUser(env, volunteer))[0].role, "volunteer");
  await assertSucceeds(getDoc(doc(
    volunteerDb,
    "classes",
    classroom.classId,
    "supportThreads",
    "question-help"
  )));

  // A volunteer sees a student-submitted support thread, not the class roster or mood profile.
  await assertFails(getDoc(doc(
    volunteerDb,
    "classes",
    classroom.classId,
    "students",
    student.sub
  )));
  await assertFails(getDocs(collection(volunteerDb, "classes", classroom.classId, "members")));

  const outsiderDb = dbFor(outsider.sub);
  await assertFails(getDoc(doc(
    outsiderDb,
    "classes",
    classroom.classId,
    "supportThreads",
    "question-help"
  )));
});

test("teacher removal and volunteer leave revoke support access immediately", async () => {
  const classroom = await createReadyClass();
  const invitation = await resetVolunteerInviteCode(env, teacher, classroom.classId);
  await requestVolunteerService(env, volunteer, invitation.code);
  await reviewVolunteerService(env, teacher, classroom.classId, volunteer.sub, "approve");

  const volunteerDb = dbFor(volunteer.sub);
  const supportRef = doc(
    volunteerDb,
    "classes",
    classroom.classId,
    "supportThreads",
    "question-help"
  );
  await assertSucceeds(getDoc(supportRef));

  await reviewVolunteerService(env, teacher, classroom.classId, volunteer.sub, "remove");
  await assertFails(getDoc(supportRef));
  assert.equal((await listVolunteerServices(env, volunteer))[0].status, "removed");
  assert.equal((await listClassroomsForUser(env, volunteer)).length, 0);

  await requestVolunteerService(env, volunteer, invitation.code);
  await reviewVolunteerService(env, teacher, classroom.classId, volunteer.sub, "approve");
  await assertSucceeds(getDoc(supportRef));
  await leaveVolunteerService(env, volunteer, classroom.classId);
  await assertFails(getDoc(supportRef));
  assert.equal((await listVolunteerServices(env, volunteer))[0].status, "left");
});

test("student join code and volunteer invite code cannot be used interchangeably", async () => {
  const classroom = await createReadyClass();
  const invitation = await resetVolunteerInviteCode(env, teacher, classroom.classId);
  await assert.rejects(
    () => requestVolunteerService(env, volunteer, classroom.joinCode),
    (error) => error?.code === "CLASSROOM_CODE_NOT_FOUND"
  );
  await assert.rejects(
    () => joinClassroom(env, student, invitation.code),
    (error) => error?.code === "CLASSROOM_CODE_NOT_FOUND"
  );
});

test("volunteer can withdraw a pending request without ever receiving class access", async () => {
  const classroom = await createReadyClass();
  const invitation = await resetVolunteerInviteCode(env, teacher, classroom.classId);
  await requestVolunteerService(env, volunteer, invitation.code);

  await leaveVolunteerService(env, volunteer, classroom.classId);
  assert.equal((await listVolunteerServices(env, volunteer))[0].status, "left");
  assert.equal((await listClassroomsForUser(env, volunteer)).length, 0);
  assert.equal((await listClassroomVolunteers(env, teacher, classroom.classId))[0].status, "left");
  await assertFails(getDoc(doc(
    dbFor(volunteer.sub),
    "classes",
    classroom.classId,
    "supportThreads",
    "question-help"
  )));
});

test("class deletion revokes active and pending volunteer services plus the invite code", async () => {
  const classroom = await createReadyClass();
  const invitation = await resetVolunteerInviteCode(env, teacher, classroom.classId);
  await requestVolunteerService(env, volunteer, invitation.code);
  await reviewVolunteerService(env, teacher, classroom.classId, volunteer.sub, "approve");
  await requestVolunteerService(env, outsider, invitation.code);

  const supportRef = doc(
    dbFor(volunteer.sub),
    "classes",
    classroom.classId,
    "supportThreads",
    "question-help"
  );
  await assertSucceeds(getDoc(supportRef));

  const result = await deleteClassroom(env, teacher, classroom.classId);
  assert.equal(result.deleted, true);
  await assertFails(getDoc(supportRef));
  assert.equal((await listVolunteerServices(env, volunteer))[0].status, "removed");
  assert.equal((await listVolunteerServices(env, outsider))[0].status, "removed");
  await assert.rejects(
    () => requestVolunteerService(env, volunteer, invitation.code),
    (error) => error?.code === "CLASSROOM_CODE_NOT_FOUND"
  );
});
