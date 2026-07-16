import assert from "node:assert/strict";
import { test } from "vitest";

import {
  accountDeletionJobProgress,
  accountDeletionJobWrite,
  accountDeletionMetricWrite,
  accountDeletionPhase,
  accountDeletionPreview,
  normalizeAccountDeletionRequest,
  normalizeOutput,
  requireRecentAuthentication,
  validateAccountDeletionClassTransfers,
} from "../src/index.js";

test("account deletion requires the current policy and an explicit destructive confirmation", () => {
  assert.deepEqual(
    normalizeAccountDeletionRequest({
      confirmation: "DELETE",
      policyVersion: "2026-07-13",
    }),
    { confirmation: "DELETE", policyVersion: "2026-07-13", classTransfers: {} }
  );
  assert.throws(
    () => normalizeAccountDeletionRequest({ confirmation: "delete", policyVersion: "2026-07-13" }),
    (error) => error.code === "ACCOUNT_DELETION_CONFIRMATION_REQUIRED"
  );
  assert.throws(
    () => normalizeAccountDeletionRequest({ confirmation: "DELETE", policyVersion: "old" }),
    (error) => error.code === "ACCOUNT_DELETION_POLICY_CHANGED"
  );
});

test("AI output can never claim that a human escalation happened automatically", () => {
  const normalized = normalizeOutput("emotionalSupport", {
    summary: "先慢下來。",
    staffEscalationNeeded: true,
  });
  assert.equal(normalized.staffEscalationNeeded, false);
});

test("account deletion rejects a stale sign-in but accepts a recent provider session", () => {
  assert.doesNotThrow(() => requireRecentAuthentication({ auth_time: 9_500 }, 10_000));
  assert.throws(
    () => requireRecentAuthentication({ auth_time: 9_000 }, 10_000),
    (error) => error.code === "ACCOUNT_RECENT_SIGN_IN_REQUIRED"
  );
  assert.throws(
    () => requireRecentAuthentication({}, 10_000),
    (error) => error.code === "ACCOUNT_RECENT_SIGN_IN_REQUIRED"
  );
});

test("deletion preview explains class impact without exposing storage paths", () => {
  assert.deepEqual(
    accountDeletionPreview({
      role: "teacher",
      membershipCount: 3,
      ownedClassCount: 2,
      ownedClasses: [
        {
          classId: "class-a",
          className: "Class A",
          eligibleCoTeachers: [{ uid: "teacher-2", displayName: "Teacher 2" }],
        },
        {
          classId: "class-b",
          className: "Class B",
          eligibleCoTeachers: [],
        },
      ],
    }),
    {
      role: "teacher",
      classMembershipCount: 3,
      ownedClassCount: 2,
      archivesOwnedClasses: true,
      transfersOwnedClasses: true,
      ownedClasses: [
        {
          classId: "class-a",
          className: "Class A",
          eligibleCoTeachers: [{ uid: "teacher-2", displayName: "Teacher 2" }],
        },
        {
          classId: "class-b",
          className: "Class B",
          eligibleCoTeachers: [],
        },
      ],
      removesIdentifiableData: true,
      retainsAnonymousAggregateOnly: true,
      requiresRecentSignIn: true,
    }
  );
});

test("owned classes require a confirmed eligible co-teacher and archive only without one", () => {
  const summary = {
    ownedClasses: [
      {
        classId: "class-a",
        eligibleCoTeachers: [{ uid: "teacher-2", displayName: "Teacher 2" }],
      },
      { classId: "class-b", eligibleCoTeachers: [] },
    ],
  };
  assert.deepEqual(
    validateAccountDeletionClassTransfers(
      summary,
      { "class-a": "teacher-2" },
      true
    ),
    { "class-a": "teacher-2" }
  );
  assert.throws(
    () => validateAccountDeletionClassTransfers(summary, {}, true),
    (error) => error.code === "ACCOUNT_CLASS_TRANSFER_SELECTION_REQUIRED"
  );
  assert.throws(
    () => validateAccountDeletionClassTransfers(
      summary,
      { "class-a": "former-teacher" },
      true
    ),
    (error) => error.code === "ACCOUNT_CLASS_TRANSFER_SELECTION_STALE"
  );
});

test("retained deletion metric contains aggregate counters and no account identifier", () => {
  const write = accountDeletionMetricWrite("englishplus-testflight", {
    uid: "sensitive-user-id",
    role: "student",
    membershipCount: 1,
  });
  const serialized = JSON.stringify(write);
  assert.doesNotMatch(serialized, /sensitive-user-id/);
  assert.match(serialized, /anonymousProductMetrics/);
  assert.match(serialized, /totalAccountsDeleted/);
  assert.match(serialized, /role_student/);
  assert.match(serialized, /accountsWithClasses/);
});

test("deletion jobs use Firestore preconditions to prevent duplicate cleanup races", () => {
  const fresh = accountDeletionJobWrite(
    { uid: "account-1", role: "student", projectId: "project-1", job: null },
    { phase: "cleaning", metricRecorded: false }
  );
  assert.deepEqual(fresh.currentDocument, { exists: false });

  const retry = accountDeletionJobWrite(
    {
      uid: "account-1",
      role: "student",
      projectId: "project-1",
      job: { updateTime: "2026-07-13T00:00:00.000Z", fields: {} },
    },
    { phase: "authPending", metricRecorded: true }
  );
  assert.deepEqual(retry.currentDocument, { updateTime: "2026-07-13T00:00:00.000Z" });
});

test("deletion jobs persist bounded legacy-thread progress without exposing it to clients", () => {
  const write = accountDeletionJobWrite(
    { uid: "account-1", role: "student", projectId: "project-1", job: null },
    {
      phase: "legacySupportMessages",
      metricRecorded: false,
      legacyThreadPaths: [
        "classes/class-1/supportThreads/thread-1",
        "classes/class-1/supportThreads/thread-2",
      ],
    }
  );
  assert.equal(write.update.fields.legacyThreadTotal.integerValue, "2");
  assert.deepEqual(
    write.update.fields.legacyThreadPaths.arrayValue.values.map((value) => value.stringValue),
    [
      "classes/class-1/supportThreads/thread-1",
      "classes/class-1/supportThreads/thread-2",
    ]
  );
});

test("large accounts are staged before the final destructive pass", () => {
  assert.equal(accountDeletionPhase({
    legacyThreadPaths: ["thread-1"],
    ownedClassPaths: ["classes/class-1"],
    classStudentPaths: ["classes/class-1/students/student-1"],
  }), "legacySupportMessages");
  assert.equal(accountDeletionPhase({
    legacyThreadPaths: [],
    ownedClassPaths: ["classes/class-1"],
    classStudentPaths: ["classes/class-1/students/student-1"],
  }), "ownedClasses");
  assert.equal(accountDeletionPhase({
    legacyThreadPaths: [],
    ownedClassPaths: [],
    classStudentPaths: ["classes/class-1/students/student-1"],
  }), "classStudentData");
  assert.equal(accountDeletionPhase({
    legacyThreadPaths: [],
    ownedClassPaths: [],
    classStudentPaths: [],
  }), "ready");
});

test("deletion jobs retain class cleanup queues and expose counts without paths", () => {
  const write = accountDeletionJobWrite(
    { uid: "account-1", role: "teacher", projectId: "project-1", job: null },
    {
      phase: "ownedClasses",
      metricRecorded: false,
      ownedClassPaths: ["classes/class-1", "classes/class-2"],
      classStudentPaths: ["classes/class-3/students/account-1"],
    }
  );
  assert.equal(write.update.fields.ownedClassTotal.integerValue, "2");
  assert.equal(write.update.fields.classStudentTotal.integerValue, "1");
  assert.deepEqual(accountDeletionJobProgress({ fields: write.update.fields }), {
    phase: "ownedClasses",
    remaining: 2,
    total: 2,
  });
  assert.doesNotMatch(JSON.stringify(accountDeletionJobProgress({ fields: write.update.fields })), /class-1/);
});
