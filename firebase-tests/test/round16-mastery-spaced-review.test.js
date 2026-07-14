import { after, before, beforeEach, test } from "node:test";
import { readFileSync } from "node:fs";
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
  updateDoc,
} from "firebase/firestore";

const PROJECT_ID = "demo-englishplus-round16";
const HOST = "127.0.0.1";
const PORT = 8080;
const CLASS_ID = "ROUND16-CLASS";
const masteryId = "mastery-be-verbs";
const joinedAt = Timestamp.fromDate(new Date("2026-07-01T00:00:00.000Z"));
const firstAttemptAt = Timestamp.fromDate(new Date("2026-07-14T02:00:00.000Z"));
const secondAttemptAt = Timestamp.fromDate(new Date("2026-07-15T02:00:00.000Z"));
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
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const [uid, role, provisioningSource] of [
      ["studentA", "student", "selfServiceStudent"],
      ["studentB", "student", "selfServiceStudent"],
      ["teacherA", "teacher", "selfServiceTeacher"],
      ["volunteerA", "volunteer", "administratorApprovedVolunteer"],
    ]) {
      await setDoc(doc(db, "users", uid), {
        displayName: uid,
        preferredName: uid,
        primaryRole: role,
        activeClassId: CLASS_ID,
        active: true,
        accountStatus: "active",
        provisioningSource,
        identityProviders: ["emailPassword"],
        createdAt: joinedAt,
        updatedAt: joinedAt,
      });
    }

    await setDoc(doc(db, "classes", CLASS_ID), {
      classId: CLASS_ID,
      name: "Round 16 class",
      ownerTeacherUid: "teacherA",
      active: true,
      createdAt: joinedAt,
      updatedAt: joinedAt,
    });
    for (const [uid, role] of [
      ["studentA", "student"],
      ["studentB", "student"],
      ["teacherA", "teacher"],
      ["volunteerA", "volunteer"],
    ]) {
      await setDoc(doc(db, "classes", CLASS_ID, "members", uid), {
        uid,
        classId: CLASS_ID,
        className: "Round 16 class",
        displayName: uid,
        role,
        status: "active",
        active: true,
        joinedAt,
        visibilityStartsAt: joinedAt,
        leftAt: null,
        updatedAt: joinedAt,
      });
    }
  });
});

function dbFor(uid) {
  return testEnv.authenticatedContext(uid, { email_verified: true }).firestore();
}

function mastery(studentUid = "studentA", overrides = {}) {
  return {
    masteryId,
    studentUid,
    curriculumKey: "grammar.be-verbs.present",
    unit: "Be verbs",
    skill: "Present-tense be verbs",
    questionType: "grammar",
    level: "A2",
    attemptCount: 1,
    correctCount: 0,
    firstTryCorrectCount: 0,
    consecutiveCorrectCount: 0,
    masteryScore: 40,
    lastQuestionId: "grammar-be-001",
    lastResultCorrect: false,
    lastAttemptSource: "freePractice",
    lastAnsweredAt: firstAttemptAt,
    nextReviewAt: firstAttemptAt,
    updatedAt: firstAttemptAt,
    ...overrides,
  };
}

test("student mastery sync is private while the current teacher can read it", async () => {
  const student = dbFor("studentA");
  const teacher = dbFor("teacherA");
  const volunteer = dbFor("volunteerA");
  const otherStudent = dbFor("studentB");
  const path = ["classes", CLASS_ID, "students", "studentA", "skillMastery", masteryId];

  await assertSucceeds(setDoc(doc(student, ...path), mastery()));
  await assertSucceeds(getDoc(doc(student, ...path)));
  await assertSucceeds(getDoc(doc(teacher, ...path)));
  await assertFails(getDoc(doc(volunteer, ...path)));
  await assertFails(getDoc(doc(otherStudent, ...path)));
  await assertFails(setDoc(doc(otherStudent, ...path), mastery()));
});

test("personal-mode mastery works without exposing it to staff or another student", async () => {
  const student = dbFor("studentA");
  const teacher = dbFor("teacherA");
  const otherStudent = dbFor("studentB");
  const path = ["users", "studentA", "skillMastery", masteryId];

  await assertSucceeds(setDoc(doc(student, ...path), mastery()));
  await assertSucceeds(getDoc(doc(student, ...path)));
  await assertFails(getDoc(doc(teacher, ...path)));
  await assertFails(getDoc(doc(otherStudent, ...path)));
});

test("mastery updates advance attempts but cannot rewrite identity or inflate counters", async () => {
  const student = dbFor("studentA");
  const ref = doc(
    student,
    "classes",
    CLASS_ID,
    "students",
    "studentA",
    "skillMastery",
    masteryId
  );
  await assertSucceeds(setDoc(ref, mastery()));
  await assertSucceeds(updateDoc(ref, {
    attemptCount: 2,
    correctCount: 1,
    firstTryCorrectCount: 1,
    consecutiveCorrectCount: 1,
    masteryScore: 61,
    lastQuestionId: "grammar-be-002",
    lastResultCorrect: true,
    lastAttemptSource: "dailyMission",
    lastAnsweredAt: secondAttemptAt,
    nextReviewAt: Timestamp.fromDate(new Date("2026-07-16T02:00:00.000Z")),
    updatedAt: secondAttemptAt,
  }));
  await assertFails(updateDoc(ref, { attemptCount: 1, updatedAt: secondAttemptAt }));
  await assertFails(updateDoc(ref, { curriculumKey: "reading.inference" }));
  await assertFails(updateDoc(ref, {
    attemptCount: 3,
    correctCount: 4,
    updatedAt: Timestamp.fromDate(new Date("2026-07-16T02:00:00.000Z")),
  }));
  await assertFails(updateDoc(ref, {
    attemptCount: 3,
    masteryScore: 101,
    updatedAt: Timestamp.fromDate(new Date("2026-07-16T02:00:00.000Z")),
  }));
});

test("a forged mastery identity is rejected at creation", async () => {
  const student = dbFor("studentA");
  const classRef = doc(
    student,
    "classes",
    CLASS_ID,
    "students",
    "studentA",
    "skillMastery",
    masteryId
  );
  const personalRef = doc(student, "users", "studentA", "skillMastery", masteryId);

  await assertFails(setDoc(classRef, mastery("studentB")));
  await assertFails(setDoc(personalRef, mastery("studentB")));
  await assertFails(setDoc(classRef, mastery("studentA", { masteryId: "different-id" })));
  await assertFails(setDoc(classRef, mastery("studentA", { lastAttemptSource: "adminOverride" })));
});
