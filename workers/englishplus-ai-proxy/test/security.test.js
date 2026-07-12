import assert from "node:assert/strict";
import test from "node:test";

import worker, {
  normalizeEvidenceTicketRequest,
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
