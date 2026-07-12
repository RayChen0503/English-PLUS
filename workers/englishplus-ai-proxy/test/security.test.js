import assert from "node:assert/strict";
import test from "node:test";

import worker, {
  evidenceQuotaSnapshot,
  enforceEvidenceQuota,
  normalizeEvidenceTicketRequest,
  selectExpiredReviewedApplications,
  signUploadTicket,
  verifyUploadTicket,
} from "../src/index.js";

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
