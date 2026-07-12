import assert from "node:assert/strict";
import test from "node:test";

import worker, {
  evidenceQuotaSnapshot,
  enforceEvidenceQuota,
  generateClassCode,
  membershipIsActiveDocument,
  normalizeClassroomCode,
  normalizeClassroomCreateRequest,
  normalizeClassroomJoinRequest,
  normalizeEvidenceTicketRequest,
  reviewTransitionAllowed,
  selectExpiredReviewedApplications,
  signUploadTicket,
  verifyUploadTicket,
} from "../src/index.js";

test("classroom names and join codes are normalized without weakening validation", () => {
  assert.deepEqual(
    normalizeClassroomCreateRequest({ name: "  八年級   英文 A 班  " }),
    { name: "八年級 英文 A 班" }
  );
  assert.deepEqual(
    normalizeClassroomJoinRequest({ code: "abcd efgh" }),
    { code: "ABCDEFGH" }
  );
  assert.equal(normalizeClassroomCode("ABCD-EFGH"), "ABCDEFGH");
  assert.throws(
    () => normalizeClassroomCreateRequest({ name: "A" }),
    (error) => error.code === "INVALID_CLASSROOM_NAME"
  );
  assert.throws(
    () => normalizeClassroomJoinRequest({ code: "OOOO-1111" }),
    (error) => error.code === "INVALID_CLASSROOM_CODE"
  );
});

test("classroom codes use the unambiguous alphabet deterministically", () => {
  const code = generateClassCode(
    new Uint8Array([0, 1, 2, 3, 4, 5, 6, 7])
  );
  assert.equal(code, "ABCDEFGH");
  assert.match(code, /^[A-HJ-NP-Z2-9]{8}$/);
  assert.throws(() => generateClassCode(new Uint8Array([1, 2, 3])));
});

test("legacy and current membership shapes migrate only while active", () => {
  assert.equal(membershipIsActiveDocument({
    fields: { active: { booleanValue: true } },
  }), true);
  assert.equal(membershipIsActiveDocument({
    fields: {
      status: { stringValue: "active" },
      active: { booleanValue: true },
      leftAt: { nullValue: null },
    },
  }), true);
  assert.equal(membershipIsActiveDocument({
    fields: {
      status: { stringValue: "left" },
      active: { booleanValue: false },
      leftAt: { timestampValue: "2026-07-12T00:00:00.000Z" },
    },
  }), false);
});

test("AI requests require a verified Firebase session", async () => {
  const response = await worker.fetch(
    new Request("https://example.test/ai", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ taskType: "dailyMission" }),
    }),
    {}
  );

  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), { ok: false, error: "AUTH_REQUIRED" });
});

test("evidence metadata only accepts the supported private upload contract", () => {
  assert.deepEqual(
    normalizeEvidenceTicketRequest({
      filename: "toeic.pdf",
      mimeType: "application/pdf",
      sizeBytes: 2048,
      qualificationKind: "englishProficiency",
    }),
    {
      filename: "toeic.pdf",
      mimeType: "application/pdf",
      sizeBytes: 2048,
      qualificationKind: "englishProficiency",
    }
  );

  assert.throws(() =>
    normalizeEvidenceTicketRequest({
      filename: "script.html",
      mimeType: "text/html",
      sizeBytes: 32,
      qualificationKind: "other",
    })
  );
  assert.throws(() =>
    normalizeEvidenceTicketRequest({
      filename: "oversized.pdf",
      mimeType: "application/pdf",
      sizeBytes: 10 * 1024 * 1024 + 1,
      qualificationKind: "other",
    })
  );
});

test("signed upload tickets reject tampering and expiry", async () => {
  const secret = "round-four-test-secret";
  const payload = {
    uid: "student-safe-volunteer-uid",
    evidenceId: "evidence-id",
    objectKey: "volunteer-evidence/student-safe-volunteer-uid/evidence-id.pdf",
    mimeType: "application/pdf",
    sizeBytes: 512,
    qualificationKind: "universityEnrollment",
    exp: Math.floor(Date.now() / 1000) + 60,
  };
  const ticket = await signUploadTicket(payload, secret);
  assert.deepEqual(await verifyUploadTicket(ticket, secret), payload);

  await assert.rejects(() => verifyUploadTicket(`${ticket}x`, secret));

  const expired = await signUploadTicket(
    { ...payload, exp: Math.floor(Date.now() / 1000) - 1 },
    secret
  );
  await assert.rejects(() => verifyUploadTicket(expired, secret));
});

test("evidence quota counts active reservations and rejects file or byte overflow", () => {
  const now = 2_000;
  const snapshot = evidenceQuotaSnapshot(
    [
      { key: "complete.pdf", size: 5 * 1024 * 1024, customMetadata: {} },
      {
        key: "reserved.pdf",
        size: 0,
        customMetadata: {
          uploadState: "reserved",
          expectedSizeBytes: String(10 * 1024 * 1024),
          reservedUntilSeconds: "2500",
        },
      },
      {
        key: "expired.pdf",
        size: 0,
        customMetadata: {
          uploadState: "reserved",
          expectedSizeBytes: String(10 * 1024 * 1024),
          reservedUntilSeconds: "1999",
        },
      },
    ],
    now
  );
  assert.equal(snapshot.fileCount, 2);
  assert.equal(snapshot.totalBytes, 15 * 1024 * 1024);
  assert.deepEqual(snapshot.expiredReservationKeys, ["expired.pdf"]);
  assert.doesNotThrow(() => enforceEvidenceQuota(snapshot, 10 * 1024 * 1024));
  assert.throws(
    () => enforceEvidenceQuota(snapshot, 10 * 1024 * 1024 + 1),
    (error) => error.code === "EVIDENCE_TOTAL_SIZE_LIMIT_REACHED"
  );

  assert.throws(
    () => enforceEvidenceQuota({ fileCount: 5, totalBytes: 1 }, 1),
    (error) => error.code === "EVIDENCE_FILE_LIMIT_REACHED"
  );
});

test("retention cleanup selects only final reviews older than thirty days", () => {
  const now = new Date("2026-07-12T00:00:00.000Z");
  const evidence = [{ objectKey: "volunteer-evidence/u/e.pdf" }];
  const applications = [
    {
      uid: "expired",
      status: "approved",
      reviewedAt: "2026-05-01T00:00:00.000Z",
      evidenceRetentionUntil: "2026-06-01T00:00:00.000Z",
      evidenceDeletedAt: "",
      evidence,
    },
    {
      uid: "recent",
      status: "rejected",
      reviewedAt: "2026-07-01T00:00:00.000Z",
      evidenceRetentionUntil: "2026-07-31T00:00:00.000Z",
      evidenceDeletedAt: "",
      evidence,
    },
    {
      uid: "needs-info",
      status: "needsMoreInformation",
      reviewedAt: "2026-05-01T00:00:00.000Z",
      evidenceRetentionUntil: "",
      evidenceDeletedAt: "",
      evidence,
    },
    {
      uid: "already-deleted",
      status: "suspended",
      reviewedAt: "2026-05-01T00:00:00.000Z",
      evidenceRetentionUntil: "2026-06-01T00:00:00.000Z",
      evidenceDeletedAt: "2026-06-02T00:00:00.000Z",
      evidence,
    },
  ];

  assert.deepEqual(
    selectExpiredReviewedApplications(applications, now).map((item) => item.uid),
    ["expired"]
  );
});

test("volunteer review actions enforce legal application transitions", () => {
  assert.equal(reviewTransitionAllowed("pendingReview", "approved"), true);
  assert.equal(reviewTransitionAllowed("pendingReview", "rejected"), true);
  assert.equal(
    reviewTransitionAllowed("pendingReview", "needsMoreInformation"),
    true
  );
  assert.equal(reviewTransitionAllowed("needsMoreInformation", "approved"), false);
  assert.equal(reviewTransitionAllowed("approved", "suspended"), true);
  assert.equal(reviewTransitionAllowed("rejected", "approved"), false);
});
