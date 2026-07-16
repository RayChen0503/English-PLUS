import { after, before, beforeEach, test } from "node:test";
import assert from "node:assert/strict";
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
  writeBatch,
} from "firebase/firestore";
import { readFileSync } from "node:fs";

const PROJECT_ID = "demo-englishplus-fix-a";
const HOST = "127.0.0.1";
const PORT = 8080;
const CLASS_ID = "FIX-A-CLASS";
const STUDENT_UID = "fixAStudent";
const OTHER_STUDENT_UID = "fixAOtherStudent";
const TEACHER_UID = "fixATeacher";
const VOLUNTEER_UID = "fixAVolunteer";
const createdAt = Timestamp.fromDate(new Date("2026-07-14T01:00:00.000Z"));
const repliedAt = Timestamp.fromDate(new Date("2026-07-14T01:05:00.000Z"));
const readAt = Timestamp.fromDate(new Date("2026-07-14T01:06:00.000Z"));
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
  await seedClassIdentity();
});

function profile(role) {
  return {
    displayName: role,
    preferredName: role,
    primaryRole: role,
    activeClassId: CLASS_ID,
    active: true,
    accountStatus: "active",
    provisioningSource: role === "teacher"
      ? "selfServiceTeacher"
      : role === "volunteer"
        ? "administratorApprovedVolunteer"
        : "selfServiceStudent",
    studentAccessPath: role === "student" ? "age13OrOlder" : "notApplicable",
    identityProviders: ["emailPassword"],
    createdAt,
    updatedAt: createdAt,
  };
}

function membership(uid, role) {
  return {
    uid,
    classId: CLASS_ID,
    className: "FIX-A support class",
    displayName: uid,
    role,
    status: "active",
    active: true,
    joinedAt: createdAt,
    visibilityStartsAt: createdAt,
    leftAt: null,
    updatedAt: createdAt,
  };
}

function thread(threadId) {
  return {
    threadId,
    studentUid: STUDENT_UID,
    studentName: "Test student",
    classId: CLASS_ID,
    messageContextVersion: 2,
    status: "waitingForStaff",
    reason: "stuck_on_question",
    route: "humanHandoff",
    priority: "medium",
    assignedToUid: null,
    assignedRole: null,
    studentVisible: true,
    studentMessage: "I need help with this question.",
    latestQuestionId: "question-1",
    questionSnapshot: {
      questionId: "question-1",
      prompt: "My parents ___ at home.",
      options: ["be", "am", "is", "are"],
      questionTypeTitle: "Grammar",
      levelTitle: "Foundation",
      skill: "be verbs",
      selectedAnswer: "is",
      correctAnswer: "are",
      explanation: "A plural subject uses are.",
      repairHint: "Find the subject first.",
    },
    studentArchivedAt: null,
    withdrawnAt: null,
    teacherArchivedAt: null,
    volunteerArchivedAt: null,
    studentLastReadAt: null,
    latestMessagePreview: "I need help with this question.",
    createdAt,
    updatedAt: createdAt,
  };
}

function studentMessage(threadId) {
  return {
    messageId: `${threadId}-student-request`,
    threadId,
    classId: CLASS_ID,
    studentUid: STUDENT_UID,
    contextVersion: 2,
    authorUid: STUDENT_UID,
    authorName: "Test student",
    authorRole: "student",
    body: "I need help with this question.",
    visibility: "studentVisible",
    messageType: "studentRequest",
    createdAt,
  };
}

function staffReply(messageId, uid, role) {
  return {
    messageId,
    threadId: "thread-reply",
    classId: CLASS_ID,
    studentUid: STUDENT_UID,
    contextVersion: 2,
    authorUid: uid,
    authorName: role,
    authorRole: role,
    body: "Find the plural subject, then choose are.",
    visibility: "studentVisible",
    messageType: role === "teacher" ? "teacherReply" : "volunteerReply",
    createdAt: repliedAt,
  };
}

async function seedClassIdentity() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "classes", CLASS_ID), {
      classId: CLASS_ID,
      name: "FIX-A support class",
      ownerTeacherUid: TEACHER_UID,
      active: true,
      createdAt,
      updatedAt: createdAt,
    });
    for (const [uid, role] of [
      [STUDENT_UID, "student"],
      [OTHER_STUDENT_UID, "student"],
      [TEACHER_UID, "teacher"],
      [VOLUNTEER_UID, "volunteer"],
    ]) {
      await setDoc(doc(db, "users", uid), profile(role));
      await setDoc(doc(db, "classes", CLASS_ID, "members", uid), membership(uid, role));
    }
  });
}

function dbFor(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

async function createSupportThread(threadId) {
  const student = dbFor(STUDENT_UID);
  const threadRef = doc(student, "classes", CLASS_ID, "supportThreads", threadId);
  const messageRef = doc(threadRef, "messages", `${threadId}-student-request`);
  const batch = writeBatch(student);
  batch.set(threadRef, thread(threadId));
  batch.set(messageRef, studentMessage(threadId));
  await assertSucceeds(batch.commit());
}

test("student create, teacher reply, and student read form one cross-device timeline", async () => {
  await createSupportThread("thread-reply");

  const teacher = dbFor(TEACHER_UID);
  const teacherThread = doc(teacher, "classes", CLASS_ID, "supportThreads", "thread-reply");
  const replyRef = doc(teacherThread, "messages", "teacher-reply-1");
  const replyBatch = writeBatch(teacher);
  replyBatch.set(replyRef, staffReply("teacher-reply-1", TEACHER_UID, "teacher"));
  replyBatch.update(teacherThread, {
    status: "replied",
    latestMessagePreview: "Find the plural subject, then choose are.",
    updatedAt: repliedAt,
  });
  await assertSucceeds(replyBatch.commit());

  const student = dbFor(STUDENT_UID);
  const studentThread = doc(student, "classes", CLASS_ID, "supportThreads", "thread-reply");
  const visibleThreads = await assertSucceeds(getDocs(query(
    collection(student, "classes", CLASS_ID, "supportThreads"),
    where("studentUid", "==", STUDENT_UID),
    where("studentVisible", "==", true)
  )));
  assert.equal(visibleThreads.size, 1);
  const studentReplyRef = doc(
    studentThread,
    "messages",
    "teacher-reply-1"
  );
  assert.equal((await getDoc(studentReplyRef)).exists(), true);

  await assertSucceeds(updateDoc(studentThread, {
    status: "readByStudent",
    studentLastReadAt: readAt,
    updatedAt: readAt,
  }));
  assert.equal((await getDoc(studentThread)).data().status, "readByStudent");
});

test("withdraw keeps immutable query visibility and removes the thread from staff writes", async () => {
  await createSupportThread("thread-withdraw");
  const student = dbFor(STUDENT_UID);
  const studentThread = doc(student, "classes", CLASS_ID, "supportThreads", "thread-withdraw");

  await assertSucceeds(updateDoc(studentThread, {
    status: "closed",
    studentArchivedAt: readAt,
    withdrawnAt: readAt,
    updatedAt: readAt,
  }));
  await assertFails(updateDoc(studentThread, { studentVisible: false }));

  const teacher = dbFor(TEACHER_UID);
  const withdrawnThread = doc(teacher, "classes", CLASS_ID, "supportThreads", "thread-withdraw");
  await assertFails(setDoc(
    doc(withdrawnThread, "messages", "late-reply"),
    { ...staffReply("late-reply", TEACHER_UID, "teacher"), threadId: "thread-withdraw" }
  ));
  await assertFails(updateDoc(withdrawnThread, {
    status: "replied",
    latestMessagePreview: "Too late",
    updatedAt: repliedAt,
  }));
});

test("teacher and volunteer archive independently without changing student visibility", async () => {
  await createSupportThread("thread-archive");
  const teacher = dbFor(TEACHER_UID);
  const volunteer = dbFor(VOLUNTEER_UID);
  const teacherThread = doc(teacher, "classes", CLASS_ID, "supportThreads", "thread-archive");
  const volunteerThread = doc(volunteer, "classes", CLASS_ID, "supportThreads", "thread-archive");

  await assertSucceeds(updateDoc(teacherThread, {
    teacherArchivedAt: repliedAt,
    updatedAt: repliedAt,
  }));
  await assertSucceeds(updateDoc(volunteerThread, {
    volunteerArchivedAt: readAt,
    updatedAt: readAt,
  }));

  const student = dbFor(STUDENT_UID);
  const studentThread = await getDoc(doc(student, "classes", CLASS_ID, "supportThreads", "thread-archive"));
  assert.equal(studentThread.data().studentVisible, true);
  assert.ok(studentThread.data().teacherArchivedAt);
  assert.ok(studentThread.data().volunteerArchivedAt);
});

test("student can report a visible staff reply while unrelated roles cannot inspect the report", async () => {
  await createSupportThread("thread-report");

  const teacher = dbFor(TEACHER_UID);
  const teacherThread = doc(teacher, "classes", CLASS_ID, "supportThreads", "thread-report");
  await assertSucceeds(setDoc(
    doc(teacherThread, "messages", "teacher-report-reply"),
    {
      ...staffReply("teacher-report-reply", TEACHER_UID, "teacher"),
      threadId: "thread-report",
    }
  ));

  const student = dbFor(STUDENT_UID);
  const reportRef = doc(student, "classes", CLASS_ID, "reports", "report-1");
  await assertSucceeds(setDoc(reportRef, {
    reportId: "report-1",
    uid: STUDENT_UID,
    studentUid: STUDENT_UID,
    reporterUid: STUDENT_UID,
    reportedUid: TEACHER_UID,
    reportedRole: "teacher",
    threadId: "thread-report",
    messageId: "teacher-report-reply",
    reason: "inappropriateContent",
    status: "open",
    createdAt: repliedAt,
  }));

  assert.equal((await assertSucceeds(getDoc(reportRef))).data().status, "open");

  const otherStudent = dbFor(OTHER_STUDENT_UID);
  await assertFails(getDoc(doc(otherStudent, "classes", CLASS_ID, "reports", "report-1")));
  await assertFails(getDocs(collection(
    dbFor(VOLUNTEER_UID),
    "classes",
    CLASS_ID,
    "reports"
  )));

  const teacherReportRef = doc(teacher, "classes", CLASS_ID, "reports", "report-1");
  const reports = await assertSucceeds(getDocs(collection(
    teacher,
    "classes",
    CLASS_ID,
    "reports"
  )));
  assert.equal(reports.size, 1);
  await assertSucceeds(updateDoc(teacherReportRef, {
    status: "resolved",
    moderatedAt: readAt,
    moderatedByUid: TEACHER_UID,
    moderationNote: "Reviewed and resolved.",
  }));
  await assertFails(updateDoc(teacherReportRef, {
    reportedUid: VOLUNTEER_UID,
  }));

  await assertFails(setDoc(
    doc(student, "classes", CLASS_ID, "reports", "report-forged"),
    {
      reportId: "report-forged",
      uid: STUDENT_UID,
      studentUid: STUDENT_UID,
      reporterUid: STUDENT_UID,
      reportedUid: VOLUNTEER_UID,
      reportedRole: "volunteer",
      threadId: "thread-report",
      messageId: "teacher-report-reply",
      reason: "other",
      status: "open",
      createdAt: repliedAt,
    }
  ));
});

test("student blocking a staff author prevents future replies without blocking other staff", async () => {
  await createSupportThread("thread-block");

  const teacher = dbFor(TEACHER_UID);
  const teacherThread = doc(teacher, "classes", CLASS_ID, "supportThreads", "thread-block");
  await assertSucceeds(setDoc(
    doc(teacherThread, "messages", "teacher-before-block"),
    {
      ...staffReply("teacher-before-block", TEACHER_UID, "teacher"),
      threadId: "thread-block",
    }
  ));

  const student = dbFor(STUDENT_UID);
  await assertSucceeds(setDoc(
    doc(student, "users", STUDENT_UID, "blockedSupportAuthors", TEACHER_UID),
    {
      blockedUid: TEACHER_UID,
      blockedRole: "teacher",
      sourceThreadId: "thread-block",
      createdAt: readAt,
    }
  ));
  await assertSucceeds(updateDoc(
    doc(student, "classes", CLASS_ID, "supportThreads", "thread-block"),
    {
      status: "readByStudent",
      studentArchivedAt: readAt,
      studentLastReadAt: readAt,
      updatedAt: readAt,
    }
  ));

  await assertFails(setDoc(
    doc(teacherThread, "messages", "teacher-after-block"),
    {
      ...staffReply("teacher-after-block", TEACHER_UID, "teacher"),
      threadId: "thread-block",
    }
  ));
  await assertFails(getDoc(doc(
    teacher,
    "users",
    STUDENT_UID,
    "blockedSupportAuthors",
    TEACHER_UID
  )));

  const volunteer = dbFor(VOLUNTEER_UID);
  const volunteerThread = doc(volunteer, "classes", CLASS_ID, "supportThreads", "thread-block");
  await assertSucceeds(setDoc(
    doc(volunteerThread, "messages", "volunteer-after-block"),
    {
      ...staffReply("volunteer-after-block", VOLUNTEER_UID, "volunteer"),
      threadId: "thread-block",
    }
  ));
});
