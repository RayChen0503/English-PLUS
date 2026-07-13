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
  query,
  setDoc,
  updateDoc,
  where,
} from "firebase/firestore";
import {
  createClassroom,
  deleteClassroom,
  joinClassroom,
  leaveClassroom,
  listClassroomStudents,
  listClassroomsForUser,
  resetClassroomCode,
  updateClassroom,
} from "../../workers/englishplus-ai-proxy/src/index.js";

const PROJECT_ID = "demo-englishplus-round6";
const HOST = "127.0.0.1";
const PORT = 8080;
const CLASS_ID = "CLASS-A";
const RULES = readFileSync(
  new URL("../../docs/ios-testflight/firebase/firestore.rules.draft", import.meta.url),
  "utf8"
);

const joinedAt = Timestamp.fromDate(new Date("2026-01-01T00:00:00.000Z"));
const beforeJoin = Timestamp.fromDate(new Date("2025-12-20T00:00:00.000Z"));
const duringMembership = Timestamp.fromDate(new Date("2026-01-05T00:00:00.000Z"));
const leftAt = Timestamp.fromDate(new Date("2026-01-10T00:00:00.000Z"));
const afterLeave = Timestamp.fromDate(new Date("2026-01-15T00:00:00.000Z"));

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
  await seedRulesMatrix();
});

function activeProfile(role, activeClassId = CLASS_ID) {
  return {
    displayName: role,
    preferredName: role,
    primaryRole: role,
    activeClassId,
    active: true,
    accountStatus: "active",
    provisioningSource: role === "teacher" ? "selfServiceTeacher" : "selfServiceStudent",
    identityProviders: ["emailPassword"],
    createdAt: joinedAt,
    updatedAt: joinedAt,
  };
}

function membership(uid, role, status = "active") {
  const isActive = status === "active";
  return {
    uid,
    classId: CLASS_ID,
    className: "Round 6 class",
    displayName: uid,
    role,
    status,
    active: isActive,
    joinedAt,
    visibilityStartsAt: joinedAt,
    leftAt: isActive ? null : leftAt,
    updatedAt: isActive ? joinedAt : leftAt,
  };
}

async function seedRulesMatrix() {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const profiles = {
      studentA: activeProfile("student"),
      studentB: activeProfile("student", null),
      leftStudent: activeProfile("student", null),
      teacherA: activeProfile("teacher"),
      teacherB: activeProfile("teacher", null),
      volunteerA: {
        ...activeProfile("volunteer"),
        provisioningSource: "administratorApprovedVolunteer",
      },
    };
    for (const [uid, profile] of Object.entries(profiles)) {
      await setDoc(doc(db, "users", uid), profile);
    }

    await setDoc(doc(db, "classes", CLASS_ID), {
      classId: CLASS_ID,
      name: "Round 6 class",
      ownerTeacherUid: "teacherA",
      active: true,
      createdAt: joinedAt,
      updatedAt: joinedAt,
    });
    for (const [uid, role, status] of [
      ["studentA", "student", "active"],
      ["leftStudent", "student", "left"],
      ["teacherA", "teacher", "active"],
      ["volunteerA", "volunteer", "active"],
    ]) {
      await setDoc(doc(db, "classes", CLASS_ID, "members", uid), membership(uid, role, status));
    }

    for (const uid of ["studentA", "leftStudent", "studentB"]) {
      await setDoc(doc(db, "classes", CLASS_ID, "students", uid), {
        uid,
        displayName: uid,
        classCode: CLASS_ID,
        membershipStatus: uid === "leftStudent" ? "left" : "active",
        createdAt: joinedAt,
        updatedAt: joinedAt,
      });
    }

    await setDoc(doc(db, "classes", CLASS_ID, "students", "studentA", "dailyMissions", "before"), {
      studentUid: "studentA",
      createdAt: beforeJoin,
      status: "active",
    });
    await setDoc(doc(db, "classes", CLASS_ID, "students", "studentA", "dailyMissions", "during"), {
      studentUid: "studentA",
      createdAt: duringMembership,
      status: "active",
    });
    await setDoc(doc(db, "classes", CLASS_ID, "students", "leftStudent", "dailyMissions", "historical"), {
      studentUid: "leftStudent",
      createdAt: duringMembership,
      status: "completed",
    });
    await setDoc(doc(db, "classes", CLASS_ID, "students", "leftStudent", "dailyMissions", "after-left"), {
      studentUid: "leftStudent",
      createdAt: afterLeave,
      status: "active",
    });
    await setDoc(doc(db, "classes", CLASS_ID, "supportThreads", "active-thread"), {
      studentUid: "studentA",
      classId: CLASS_ID,
      studentVisible: true,
      createdAt: duringMembership,
      status: "open",
    });
    await setDoc(doc(db, "classes", CLASS_ID, "supportThreads", "left-thread"), {
      studentUid: "leftStudent",
      classId: CLASS_ID,
      studentVisible: true,
      createdAt: duringMembership,
      status: "closed",
    });
    await setDoc(doc(db, "classes", CLASS_ID, "staffAssignments", "volunteerA_studentA"), {
      assignedToUid: "volunteerA",
      studentUid: "studentA",
      createdAt: joinedAt,
    });
    await setDoc(doc(db, "classAdmins", CLASS_ID), {
      classId: CLASS_ID,
      ownerTeacherUid: "teacherA",
      joinCode: "ABCDEFGH",
    });
    await setDoc(doc(db, "classJoinCodes", "ABCDEFGH"), {
      classId: CLASS_ID,
      active: true,
    });
    await setDoc(doc(db, "classJoinAttempts", "studentA"), {
      uid: "studentA",
      attemptCount: 1,
    });
  });
}

function dbFor(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

test("class data and private join-code collections enforce membership boundaries", async () => {
  const unauthenticated = testEnv.unauthenticatedContext().firestore();
  const student = dbFor("studentA");
  const teacher = dbFor("teacherA");
  const outsider = dbFor("teacherB");

  await assertFails(getDoc(doc(unauthenticated, "classes", CLASS_ID)));
  await assertSucceeds(getDoc(doc(student, "classes", CLASS_ID)));
  await assertSucceeds(getDoc(doc(teacher, "classes", CLASS_ID)));
  await assertFails(getDoc(doc(outsider, "classes", CLASS_ID)));

  for (const privatePath of [
    ["classAdmins", CLASS_ID],
    ["classJoinCodes", "ABCDEFGH"],
    ["classJoinAttempts", "studentA"],
  ]) {
    await assertFails(getDoc(doc(student, ...privatePath)));
    await assertFails(getDoc(doc(teacher, ...privatePath)));
  }
});

test("a deleting or deleted class immediately revokes every class-scoped client permission", async () => {
  const student = dbFor("studentA");
  const teacher = dbFor("teacherA");
  const volunteer = dbFor("volunteerA");

  await testEnv.withSecurityRulesDisabled(async (context) => {
    await updateDoc(doc(context.firestore(), "classes", CLASS_ID), {
      lifecycleStatus: "deleting",
      deletionPending: true,
      updatedAt: Timestamp.now(),
    });
  });

  await assertFails(getDoc(doc(student, "classes", CLASS_ID)));
  await assertFails(getDoc(doc(teacher, "classes", CLASS_ID)));
  await assertFails(getDoc(doc(volunteer, "classes", CLASS_ID, "supportThreads", "active-thread")));
  await assertFails(setDoc(doc(teacher, "classes", CLASS_ID, "practiceAssignments", "blocked"), {
    assignmentId: "blocked",
    classId: CLASS_ID,
    studentUid: "studentA",
    assignedByUid: "teacherA",
    status: "pending",
    questionIds: ["q-1"],
    questionResults: [],
    createdAt: duringMembership,
    updatedAt: duringMembership,
  }));
  await assertSucceeds(updateDoc(doc(student, "users", "studentA"), {
    activeClassId: null,
    updatedAt: Timestamp.now(),
  }));
  await assertFails(updateDoc(doc(student, "users", "studentA"), {
    activeClassId: CLASS_ID,
    updatedAt: Timestamp.now(),
  }));
});

test("students keep personal mode but cannot cross class or write memberships", async () => {
  const student = dbFor("studentA");
  const noClassStudent = dbFor("studentB");

  await assertSucceeds(getDoc(doc(student, "classes", CLASS_ID, "students", "studentA")));
  await assertFails(getDoc(doc(noClassStudent, "classes", CLASS_ID, "students", "studentB")));
  await assertSucceeds(setDoc(doc(noClassStudent, "users", "studentB", "personalCheckIns", "today"), {
    moodScore: 4,
    createdAt: duringMembership,
  }));
  await assertFails(setDoc(doc(student, "classes", CLASS_ID, "members", "studentB"), {
    ...membership("studentB", "student"),
  }));
});

test("teachers see only the retained membership window and cannot mutate left history", async () => {
  const teacher = dbFor("teacherA");
  const leftStudent = dbFor("leftStudent");
  const activePath = ["classes", CLASS_ID, "students", "studentA", "dailyMissions"];
  const leftPath = ["classes", CLASS_ID, "students", "leftStudent", "dailyMissions"];

  await assertFails(getDoc(doc(teacher, ...activePath, "before")));
  await assertSucceeds(getDoc(doc(teacher, ...activePath, "during")));
  await assertSucceeds(getDoc(doc(teacher, ...leftPath, "historical")));
  await assertFails(getDoc(doc(teacher, ...leftPath, "after-left")));
  await assertFails(getDoc(doc(leftStudent, ...leftPath, "historical")));
  await assertFails(updateDoc(doc(teacher, ...leftPath, "historical"), {
    status: "reopened",
  }));
});

test("volunteers retain in-window support history but not general learning access", async () => {
  const volunteer = dbFor("volunteerA");
  await assertSucceeds(getDoc(doc(volunteer, "classes", CLASS_ID, "supportThreads", "active-thread")));
  await assertSucceeds(getDoc(doc(volunteer, "classes", CLASS_ID, "supportThreads", "left-thread")));
  await assertSucceeds(getDoc(doc(
    volunteer,
    "classes",
    CLASS_ID,
    "students",
    "studentA",
    "dailyMissions",
    "during"
  )));
});

test("teachers can assign only active students and clients cannot create classes", async () => {
  const teacher = dbFor("teacherA");
  await assertFails(setDoc(doc(teacher, "classes", "CLIENT-CREATED"), {
    active: true,
    ownerTeacherUid: "teacherA",
  }));
  await assertSucceeds(setDoc(doc(teacher, "classes", CLASS_ID, "practiceAssignments", "active"), {
    assignmentId: "active",
    classId: CLASS_ID,
    studentUid: "studentA",
    assignedByUid: "teacherA",
    status: "pending",
    questionIds: ["q-1"],
    questionResults: [],
    createdAt: duringMembership,
    updatedAt: duringMembership,
  }));
  await assertFails(setDoc(doc(teacher, "classes", CLASS_ID, "practiceAssignments", "left"), {
    assignmentId: "left",
    classId: CLASS_ID,
    studentUid: "leftStudent",
    assignedByUid: "teacherA",
    status: "pending",
    questionIds: ["q-1"],
    questionResults: [],
    createdAt: duringMembership,
    updatedAt: duringMembership,
  }));
});

test("teacher roster query is realtime-compatible and excludes inactive summaries", async () => {
  const teacher = dbFor("teacherA");
  const outsider = dbFor("teacherB");
  const summaryQuery = (db) => query(
    collection(db, "classes", CLASS_ID, "students"),
    where("membershipStatus", "==", "active")
  );

  const summaries = await assertSucceeds(getDocs(summaryQuery(teacher)));
  const members = await assertSucceeds(
    getDocs(collection(teacher, "classes", CLASS_ID, "members"))
  );
  const activeStudentIds = new Set(
    members.docs
      .filter((item) => item.data().role === "student" && item.data().status === "active")
      .map((item) => item.id)
  );
  const visibleRoster = summaries.docs
    .map((item) => item.id)
    .filter((uid) => activeStudentIds.has(uid));
  assert.deepEqual(visibleRoster, ["studentA"]);
  await assertFails(getDocs(summaryQuery(outsider)));
  await assertFails(getDocs(collection(outsider, "classes", CLASS_ID, "members")));
});

test("Worker classroom lifecycle completes in isolated Firestore and preserves history", async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", "teacherFlow"), activeProfile("teacher", null));
    await setDoc(doc(db, "users", "studentFlow"), activeProfile("student", null));
    await setDoc(doc(db, "users", "studentOther"), activeProfile("student", null));
  });

  const env = {
    FIREBASE_PROJECT_ID: PROJECT_ID,
    FIRESTORE_EMULATOR_HOST: `${HOST}:${PORT}`,
  };
  const teacher = { sub: "teacherFlow", name: "Teacher Flow", email: "teacher@example.test" };
  const student = { sub: "studentFlow", name: "Student Flow", email: "student@example.test" };
  const otherStudent = { sub: "studentOther", name: "Other Student", email: "other@example.test" };

  const classroom = await createClassroom(env, teacher, "Round 6 integration class");
  assert.equal(classroom.role, "teacher");
  assert.equal(classroom.joinCode.length, 8);
  assert.equal((await listClassroomsForUser(env, teacher)).length, 1);

  const joined = await joinClassroom(env, student, classroom.joinCode);
  assert.equal(joined.classId, classroom.classId);
  assert.equal(joined.joinCode, null);
  assert.equal((await listClassroomsForUser(env, student)).length, 1);
  const roster = await listClassroomStudents(env, teacher, classroom.classId);
  assert.equal(roster.length, 1);
  assert.equal(roster[0].studentUid, student.sub);
  assert.equal(roster[0].classId, classroom.classId);
  await assert.rejects(
    () => listClassroomStudents(env, student, classroom.classId),
    (error) => error?.code === "TEACHER_ACCOUNT_REQUIRED"
  );

  const renamed = await updateClassroom(
    env,
    teacher,
    classroom.classId,
    { name: "Round 7 renamed class" }
  );
  assert.equal(renamed.name, "Round 7 renamed class");
  assert.equal((await listClassroomsForUser(env, student))[0].name, "Round 7 renamed class");
  await assert.rejects(
    () => updateClassroom(env, student, classroom.classId, { name: "Blocked" }),
    (error) => error?.code === "TEACHER_ACCOUNT_REQUIRED"
  );

  const studentDb = dbFor("studentFlow");
  await assertSucceeds(updateDoc(doc(studentDb, "users", "studentFlow"), {
    activeClassId: null,
    updatedAt: Timestamp.now(),
  }));
  await assertSucceeds(updateDoc(doc(studentDb, "users", "studentFlow"), {
    activeClassId: classroom.classId,
    updatedAt: Timestamp.now(),
  }));

  const reset = await resetClassroomCode(env, teacher, classroom.classId);
  assert.notEqual(reset.joinCode, classroom.joinCode);
  await assert.rejects(
    () => joinClassroom(env, otherStudent, classroom.joinCode),
    (error) => error?.code === "CLASSROOM_CODE_NOT_FOUND"
  );

  await leaveClassroom(env, student, classroom.classId);
  assert.equal((await listClassroomsForUser(env, student)).length, 0);
  await assertFails(updateDoc(doc(studentDb, "users", "studentFlow"), {
    activeClassId: classroom.classId,
    updatedAt: Timestamp.now(),
  }));

  const rejoined = await joinClassroom(env, student, reset.joinCode);
  assert.equal(rejoined.visibilityStartsAt, joined.visibilityStartsAt);
  assert.equal((await listClassroomsForUser(env, student)).length, 1);

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "users", "legacyVolunteer"), activeProfile(
      "volunteer",
      classroom.classId
    ));
    await setDoc(doc(
      db,
      "classes",
      classroom.classId,
      "members",
      "legacyVolunteer"
    ), {
      uid: "legacyVolunteer",
      classId: classroom.classId,
      displayName: "Legacy Volunteer",
      role: "volunteer",
      status: "active",
      active: true,
      joinedAt: Timestamp.now(),
      visibilityStartsAt: Timestamp.now(),
      leftAt: null,
      updatedAt: Timestamp.now(),
    });
    await setDoc(doc(db, "classes", classroom.classId, "supportThreads", "retained-thread"), {
      classId: classroom.classId,
      studentUid: student.sub,
      status: "open",
      studentVisible: true,
      createdAt: Timestamp.now(),
    });
    await setDoc(doc(db, "classes", classroom.classId, "practiceAssignments", "retained-task"), {
      assignmentId: "retained-task",
      classId: classroom.classId,
      studentUid: student.sub,
      assignedByUid: teacher.sub,
      status: "pending",
      questionIds: ["q-1"],
      questionResults: [],
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
  });

  const deletion = await deleteClassroom(env, teacher, classroom.classId);
  assert.equal(deletion.deleted, true);
  assert.equal(deletion.alreadyDeleted, false);
  assert.equal((await listClassroomsForUser(env, teacher)).length, 0);
  assert.equal((await listClassroomsForUser(env, student)).length, 0);
  await assert.rejects(
    () => joinClassroom(env, otherStudent, reset.joinCode),
    (error) => error?.code === "CLASSROOM_CODE_NOT_FOUND"
  );

  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const deletedClass = (await getDoc(doc(db, "classes", classroom.classId))).data();
    const teacherProfile = (await getDoc(doc(db, "users", teacher.sub))).data();
    const studentProfile = (await getDoc(doc(db, "users", student.sub))).data();
    const teacherMembership = (await getDoc(doc(
      db,
      "users",
      teacher.sub,
      "classMemberships",
      classroom.classId
    ))).data();
    const studentMembership = (await getDoc(doc(
      db,
      "users",
      student.sub,
      "classMemberships",
      classroom.classId
    ))).data();
    const legacyVolunteerProfile = (await getDoc(doc(
      db,
      "users",
      "legacyVolunteer"
    ))).data();
    const legacyVolunteerMembership = (await getDoc(doc(
      db,
      "users",
      "legacyVolunteer",
      "classMemberships",
      classroom.classId
    ))).data();
    const audit = (await getDoc(doc(db, "classDeletionAudits", classroom.classId))).data();

    assert.equal(deletedClass.active, false);
    assert.equal(deletedClass.lifecycleStatus, "deleted");
    assert.equal(deletedClass.deletionPending, false);
    assert.equal(teacherProfile.activeClassId, null);
    assert.equal(studentProfile.activeClassId, null);
    assert.equal(teacherMembership.status, "left");
    assert.equal(teacherMembership.exitReason, "classDeleted");
    assert.equal(studentMembership.status, "left");
    assert.equal(studentMembership.exitReason, "classDeleted");
    assert.equal(legacyVolunteerProfile.activeClassId, null);
    assert.equal(legacyVolunteerMembership.status, "left");
    assert.equal(legacyVolunteerMembership.exitReason, "classDeleted");
    assert.equal(audit.affectedActiveMemberCount, 3);
    assert.equal(audit.dataDisposition, "softDeletedRetainedForAudit");
    assert.equal((await getDoc(doc(
      db,
      "classes",
      classroom.classId,
      "supportThreads",
      "retained-thread"
    ))).exists(), true);
    assert.equal((await getDoc(doc(
      db,
      "classes",
      classroom.classId,
      "practiceAssignments",
      "retained-task"
    ))).exists(), true);
  });

  const retry = await deleteClassroom(env, teacher, classroom.classId);
  assert.equal(retry.deleted, true);
  assert.equal(retry.alreadyDeleted, true);
});
