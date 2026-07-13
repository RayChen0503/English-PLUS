import { after, before, beforeEach, test } from "node:test";
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
  query,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";
import { readFileSync } from "node:fs";

const PROJECT_ID = "demo-englishplus-round8";
const HOST = "127.0.0.1";
const PORT = 8080;
const CLASS_ID = "CLASS-ROUND8";
const joinedAt = Timestamp.fromDate(new Date("2026-07-01T00:00:00.000Z"));
const activityAt = Timestamp.fromDate(new Date("2026-07-05T00:00:00.000Z"));
const leftAt = Timestamp.fromDate(new Date("2026-07-08T00:00:00.000Z"));
const changedAt = Timestamp.fromDate(new Date("2026-07-09T00:00:00.000Z"));
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
  await seedIdentityAndClass();
});

function profile(role, activeClassId = CLASS_ID) {
  return {
    displayName: role,
    preferredName: role,
    primaryRole: role,
    activeClassId,
    active: true,
    accountStatus: "active",
    provisioningSource: role === "teacher"
      ? "selfServiceTeacher"
      : role === "volunteer"
        ? "administratorApprovedVolunteer"
        : "selfServiceStudent",
    identityProviders: ["emailPassword"],
    createdAt: joinedAt,
    updatedAt: joinedAt,
  };
}

function membership(uid, role, status = "active") {
  const active = status === "active";
  return {
    uid,
    classId: CLASS_ID,
    className: "Round 8 class",
    displayName: uid,
    role,
    status,
    active,
    joinedAt,
    visibilityStartsAt: joinedAt,
    leftAt: active ? null : leftAt,
    updatedAt: active ? joinedAt : leftAt,
  };
}

function supportThread(threadId, studentUid, createdAt = activityAt) {
  return {
    threadId,
    studentUid,
    studentName: studentUid,
    classId: CLASS_ID,
    status: "waitingForStaff",
    reason: "stuck_on_question",
    route: "teacherAndVolunteer",
    priority: "medium",
    assignedToUid: null,
    assignedRole: null,
    studentVisible: true,
    studentMessage: "I need help.",
    latestMessagePreview: "I need help.",
    createdAt,
    updatedAt: createdAt,
  };
}

function supportMessage(messageId, authorUid, authorRole, messageType) {
  return {
    messageId,
    authorUid,
    authorName: authorUid,
    authorRole,
    body: "A useful reply.",
    visibility: "studentVisible",
    messageType,
    createdAt: changedAt,
  };
}

function practiceAssignment(assignmentId, studentUid = "studentA", questionCount = 3) {
  return {
    assignmentId,
    classId: CLASS_ID,
    studentUid,
    studentName: studentUid,
    setId: `set-${assignmentId}`,
    setTitle: "Focused practice",
    questionIds: Array.from({ length: questionCount }, (_, index) => `q-${index + 1}`),
    assignedByUid: "teacherA",
    assignedByName: "Teacher A",
    status: "pending",
    questionResults: [],
    createdAt: activityAt,
    updatedAt: activityAt,
  };
}

function staffAssignment(assignmentId = "volunteerA_studentA") {
  return {
    assignmentId,
    classId: CLASS_ID,
    studentUid: "studentA",
    assignedToUid: "volunteerA",
    assignedRole: "volunteer",
    title: "Follow up",
    contextSummary: "Student requested help.",
    nextAction: "Reply to the student.",
    priority: "medium",
    status: "active",
    createdAt: activityAt,
    updatedAt: activityAt,
  };
}

async function seedIdentityAndClass() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const profiles = {
      studentA: profile("student"),
      studentB: profile("student"),
      leftStudent: profile("student", null),
      teacherA: profile("teacher"),
      teacherB: profile("teacher", null),
      volunteerA: profile("volunteer"),
      volunteerB: profile("volunteer"),
    };
    for (const [uid, data] of Object.entries(profiles)) {
      await setDoc(doc(db, "users", uid), data);
    }

    await setDoc(doc(db, "classes", CLASS_ID), {
      classId: CLASS_ID,
      name: "Round 8 class",
      ownerTeacherUid: "teacherA",
      active: true,
      createdAt: joinedAt,
      updatedAt: joinedAt,
    });

    for (const [uid, role, status] of [
      ["studentA", "student", "active"],
      ["studentB", "student", "active"],
      ["leftStudent", "student", "left"],
      ["teacherA", "teacher", "active"],
      ["volunteerA", "volunteer", "active"],
      ["volunteerB", "volunteer", "active"],
    ]) {
      await setDoc(doc(db, "classes", CLASS_ID, "members", uid), membership(uid, role, status));
    }

    await setDoc(
      doc(db, "classes", CLASS_ID, "supportThreads", "left-thread"),
      supportThread("left-thread", "leftStudent", activityAt)
    );
  });
}

function dbFor(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

test("personal learning remains private and usable without class access", async () => {
  const student = dbFor("studentA");
  const otherStudent = dbFor("studentB");
  const teacher = dbFor("teacherA");
  const path = ["users", "studentA", "personalCheckIns", "2026-07-13"];

  await assertSucceeds(setDoc(doc(student, ...path), {
    dateKey: "2026-07-13",
    moodScore: 4,
    createdAt: activityAt,
  }));
  await assertSucceeds(getDoc(doc(student, ...path)));
  await assertFails(getDoc(doc(otherStudent, ...path)));
  await assertFails(getDoc(doc(teacher, ...path)));
  await assertFails(setDoc(doc(teacher, ...path), { moodScore: 1 }));
});

test("student roster summaries preserve identity and reject teacher tampering", async () => {
  const student = dbFor("studentA");
  const otherStudent = dbFor("studentB");
  const teacher = dbFor("teacherA");
  const ref = doc(student, "classes", CLASS_ID, "students", "studentA");
  const summary = {
    uid: "studentA",
    displayName: "Student A",
    classCode: CLASS_ID,
    membershipStatus: "active",
    currentLevel: "foundation",
    recommendedTrack: "steady",
    lastMoodScore: 4,
    lastMissionStatus: "active",
    lastActivityAt: activityAt,
    riskLevel: "low",
    updatedAt: activityAt,
  };

  await assertSucceeds(setDoc(ref, summary));
  await assertSucceeds(updateDoc(ref, { lastMoodScore: 3, updatedAt: changedAt }));
  await assertFails(updateDoc(doc(teacher, "classes", CLASS_ID, "students", "studentA"), {
    membershipStatus: "left",
  }));
  await assertFails(setDoc(doc(otherStudent, "classes", CLASS_ID, "students", "studentA"), summary));
  await assertFails(updateDoc(ref, { classCode: "OTHER-CLASS" }));
});

test("daily mission progress is student-owned while its identity stays immutable", async () => {
  const student = dbFor("studentA");
  const otherStudent = dbFor("studentB");
  const teacher = dbFor("teacherA");
  const missionPath = ["classes", CLASS_ID, "students", "studentA", "dailyMissions", "mission-1"];
  const mission = {
    missionId: "mission-1",
    studentUid: "studentA",
    dateKey: "2026-07-13",
    sourceCheckInId: "check-in-1",
    track: "steady",
    targetCorrectCount: 3,
    recommendedMinutes: 8,
    questionIds: ["q-1", "q-2", "q-3"],
    status: "active",
    correctCount: 0,
    progressPercent: 0,
    createdAt: activityAt,
    completedAt: null,
  };

  await assertSucceeds(setDoc(doc(student, ...missionPath), mission));
  await assertSucceeds(updateDoc(doc(student, ...missionPath), {
    correctCount: 1,
    progressPercent: 33,
  }));
  await assertFails(updateDoc(doc(student, ...missionPath), { studentUid: "studentB" }));
  await assertFails(updateDoc(doc(student, ...missionPath), { questionIds: ["replacement"] }));
  await assertSucceeds(getDoc(doc(teacher, ...missionPath)));
  await assertFails(getDoc(doc(otherStudent, ...missionPath)));
  await assertFails(updateDoc(doc(teacher, ...missionPath), { status: "completed" }));
});

test("support replies use the authenticated role and immutable student context", async () => {
  const student = dbFor("studentA");
  const teacher = dbFor("teacherA");
  const volunteer = dbFor("volunteerA");
  const threadPath = ["classes", CLASS_ID, "supportThreads", "active-thread"];
  const messagesPath = [...threadPath, "messages"];

  await assertSucceeds(setDoc(
    doc(student, ...threadPath),
    supportThread("active-thread", "studentA")
  ));
  await assertSucceeds(setDoc(
    doc(student, ...messagesPath, "student-message"),
    supportMessage("student-message", "studentA", "student", "studentRequest")
  ));
  await assertSucceeds(setDoc(
    doc(teacher, ...messagesPath, "teacher-message"),
    supportMessage("teacher-message", "teacherA", "teacher", "teacherReply")
  ));
  await assertSucceeds(setDoc(
    doc(volunteer, ...messagesPath, "volunteer-message"),
    supportMessage("volunteer-message", "volunteerA", "volunteer", "volunteerReply")
  ));
  await assertFails(setDoc(
    doc(volunteer, ...messagesPath, "spoofed-teacher"),
    supportMessage("spoofed-teacher", "volunteerA", "teacher", "teacherReply")
  ));
  await assertFails(setDoc(
    doc(student, ...messagesPath, "spoofed-student"),
    supportMessage("spoofed-student", "teacherA", "student", "studentRequest")
  ));
  await assertFails(updateDoc(doc(teacher, ...threadPath), { studentUid: "studentB" }));
  await assertSucceeds(updateDoc(doc(student, ...threadPath), {
    status: "readByStudent",
    studentLastReadAt: changedAt,
    updatedAt: changedAt,
  }));
});

test("leaving a class preserves readable history but blocks every new support write", async () => {
  const leftStudent = dbFor("leftStudent");
  const teacher = dbFor("teacherA");
  const volunteer = dbFor("volunteerA");
  const threadPath = ["classes", CLASS_ID, "supportThreads", "left-thread"];

  await assertSucceeds(getDoc(doc(teacher, ...threadPath)));
  await assertSucceeds(getDoc(doc(volunteer, ...threadPath)));
  await assertFails(updateDoc(doc(leftStudent, ...threadPath), {
    status: "closed",
    updatedAt: changedAt,
  }));
  await assertFails(setDoc(
    doc(leftStudent, ...threadPath, "messages", "after-leave"),
    supportMessage("after-leave", "leftStudent", "student", "studentRequest")
  ));
  await assertFails(setDoc(
    doc(volunteer, ...threadPath, "messages", "staff-after-leave"),
    supportMessage("staff-after-leave", "volunteerA", "volunteer", "volunteerReply")
  ));
});

test("students can report assigned-task progress but cannot rewrite assignment identity", async () => {
  const teacher = dbFor("teacherA");
  const student = dbFor("studentA");
  const otherStudent = dbFor("studentB");
  const assignmentPath = ["classes", CLASS_ID, "practiceAssignments", "practice-1"];

  await assertSucceeds(setDoc(
    doc(teacher, ...assignmentPath),
    practiceAssignment("practice-1")
  ));
  await assertFails(updateDoc(doc(student, ...assignmentPath), {
    questionIds: ["replacement"],
  }));
  await assertFails(updateDoc(doc(otherStudent, ...assignmentPath), {
    status: "active",
    updatedAt: changedAt,
  }));
  await assertSucceeds(updateDoc(doc(student, ...assignmentPath), {
    status: "active",
    updatedAt: changedAt,
  }));
  await assertSucceeds(updateDoc(doc(student, ...assignmentPath), {
    status: "completed",
    questionResults: [{ questionId: "q-1", isCorrect: true }],
    updatedAt: Timestamp.fromDate(new Date("2026-07-10T00:00:00.000Z")),
  }));
  await assertFails(setDoc(
    doc(teacher, "classes", CLASS_ID, "practiceAssignments", "too-large"),
    practiceAssignment("too-large", "studentA", 13)
  ));
  await assertFails(setDoc(
    doc(teacher, "classes", CLASS_ID, "practiceAssignments", "left-student"),
    practiceAssignment("left-student", "leftStudent", 3)
  ));

  const withdrawPath = ["classes", CLASS_ID, "practiceAssignments", "withdraw-me"];
  await assertSucceeds(setDoc(
    doc(teacher, ...withdrawPath),
    practiceAssignment("withdraw-me")
  ));
  await assertSucceeds(updateDoc(doc(teacher, ...withdrawPath), {
    status: "withdrawn",
    updatedAt: changedAt,
  }));
  await assertFails(updateDoc(doc(teacher, ...withdrawPath), { studentUid: "studentB" }));
});

test("staff handoff scope cannot be redirected after creation", async () => {
  const teacher = dbFor("teacherA");
  const volunteer = dbFor("volunteerA");
  const otherVolunteer = dbFor("volunteerB");
  const student = dbFor("studentA");
  const path = ["classes", CLASS_ID, "staffAssignments", "volunteerA_studentA"];

  await assertSucceeds(setDoc(doc(teacher, ...path), staffAssignment()));
  await assertSucceeds(getDoc(doc(volunteer, ...path)));
  await assertSucceeds(getDoc(doc(student, ...path)));
  await assertFails(getDoc(doc(otherVolunteer, ...path)));
  await assertSucceeds(updateDoc(doc(teacher, ...path), {
    status: "closed",
    nextAction: "No further action.",
    updatedAt: changedAt,
  }));
  await assertFails(updateDoc(doc(teacher, ...path), { assignedToUid: "volunteerB" }));
  await assertFails(setDoc(
    doc(teacher, "classes", CLASS_ID, "staffAssignments", "invalid-role"),
    { ...staffAssignment("invalid-role"), assignedToUid: "teacherB" }
  ));
});

test("production listener query shapes are authorized for each intended role", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(
      doc(db, "classes", CLASS_ID, "supportThreads", "active-query"),
      supportThread("active-query", "studentA")
    );
    await setDoc(
      doc(db, "classes", CLASS_ID, "practiceAssignments", "query-assignment"),
      practiceAssignment("query-assignment")
    );
    await setDoc(
      doc(db, "classes", CLASS_ID, "staffAssignments", "volunteerA_studentA"),
      staffAssignment()
    );
  });

  const student = dbFor("studentA");
  const teacher = dbFor("teacherA");
  const volunteer = dbFor("volunteerA");
  const supportCollection = (db) => collection(db, "classes", CLASS_ID, "supportThreads");
  const assignmentCollection = (db) => collection(db, "classes", CLASS_ID, "practiceAssignments");

  await assertSucceeds(getDocs(query(
    supportCollection(student),
    where("studentUid", "==", "studentA"),
    where("studentVisible", "==", true)
  )));
  await assertFails(getDocs(supportCollection(student)));
  await assertSucceeds(getDocs(supportCollection(teacher)));
  await assertSucceeds(getDocs(supportCollection(volunteer)));

  await assertSucceeds(getDocs(query(
    assignmentCollection(student),
    where("studentUid", "==", "studentA")
  )));
  await assertFails(getDocs(assignmentCollection(student)));
  await assertSucceeds(getDocs(assignmentCollection(teacher)));
  await assertFails(getDocs(assignmentCollection(volunteer)));
});

test("assigned volunteers read class learning context while unassigned volunteers cannot", async () => {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(
      doc(db, "classes", CLASS_ID, "staffAssignments", "volunteerA_studentA"),
      staffAssignment()
    );
    await setDoc(
      doc(db, "classes", CLASS_ID, "students", "studentA", "dailyMissions", "mission-context"),
      {
        missionId: "mission-context",
        studentUid: "studentA",
        questionIds: ["q-1"],
        status: "active",
        createdAt: activityAt,
      }
    );
  });

  const path = ["classes", CLASS_ID, "students", "studentA", "dailyMissions", "mission-context"];
  await assertSucceeds(getDoc(doc(dbFor("volunteerA"), ...path)));
  await assertFails(getDoc(doc(dbFor("volunteerB"), ...path)));
});
