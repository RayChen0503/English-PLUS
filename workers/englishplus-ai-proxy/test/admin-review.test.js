import assert from "node:assert/strict";
import { test } from "vitest";

import worker, {
  adminEvidenceHeaders,
  filterVolunteerApplications,
  normalizeAdminApplicationQuery,
  normalizeAdminReviewRequest,
  signAdminEvidenceTicket,
  summarizeVolunteerApplications,
  verifyAdminEvidenceTicket,
} from "../src/index.js";

test("admin evidence preview is browser-readable without downloading or caching", () => {
  const headers = adminEvidenceHeaders({
    filename: "qualification.pdf",
    contentType: "application/pdf",
    contentLength: 128,
    requestId: "evidence-request",
  });
  assert.equal(headers.get("Access-Control-Allow-Origin"), "*");
  assert.equal(headers.get("Content-Type"), "application/pdf");
  assert.equal(headers.get("Content-Disposition"), 'inline; filename="qualification.pdf"');
  assert.equal(headers.get("Cache-Control"), "private, no-store");
  assert.equal(headers.get("Content-Length"), "128");
  assert.equal(headers.get("Cross-Origin-Resource-Policy"), "cross-origin");
  assert.equal(headers.get("X-Content-Type-Options"), "nosniff");
});

test("short-lived admin evidence tickets are purpose-bound and stream private R2 files", async () => {
  const secret = "evidence-preview-test-secret";
  const payload = {
    purpose: "adminEvidencePreview",
    uid: "applicant123",
    objectKey: "volunteer-evidence/applicant123/evidence.pdf",
    filename: "qualification.pdf",
    mimeType: "application/pdf",
    exp: Math.floor(Date.now() / 1000) + 120,
  };
  const ticket = await signAdminEvidenceTicket(payload, secret);
  await assert.doesNotReject(() => verifyAdminEvidenceTicket(ticket, secret));

  const bytes = new TextEncoder().encode("%PDF evidence preview");
  const response = await worker.fetch(
    new Request(`https://example.test/admin/evidence-file?ticket=${encodeURIComponent(ticket)}`),
    {
      EVIDENCE_UPLOAD_SIGNING_SECRET: secret,
      VOLUNTEER_EVIDENCE: {
        async get(key) {
          assert.equal(key, payload.objectKey);
          return {
            body: new Blob([bytes], { type: "application/pdf" }).stream(),
            size: bytes.byteLength,
            httpMetadata: { contentType: "application/pdf" },
          };
        },
      },
    }
  );
  assert.equal(response.status, 200);
  assert.equal(response.headers.get("Content-Type"), "application/pdf");
  assert.equal(response.headers.get("Content-Length"), String(bytes.byteLength));
  assert.equal(await response.text(), "%PDF evidence preview");

  const [encodedPayload, signature] = ticket.split(".");
  const replacement = encodedPayload.endsWith("A") ? "B" : "A";
  const tampered = `${encodedPayload.slice(0, -1)}${replacement}.${signature}`;
  await assert.rejects(
    () => verifyAdminEvidenceTicket(tampered, secret),
    (error) => error.code === "INVALID_EVIDENCE_PREVIEW_TICKET"
  );
  const expired = await signAdminEvidenceTicket({ ...payload, exp: 1 }, secret);
  await assert.rejects(
    () => verifyAdminEvidenceTicket(expired, secret),
    (error) => error.code === "EXPIRED_OR_INVALID_EVIDENCE_PREVIEW_TICKET"
  );
});

test("admin review input accepts valid decisions and protects consequential actions", () => {
  assert.deepEqual(
    normalizeAdminReviewRequest({ action: "approved", note: "資料完整，核准加入志工服務" }),
    { action: "approved", note: "資料完整，核准加入志工服務", expectedVersion: "" }
  );
  assert.deepEqual(
    normalizeAdminReviewRequest({
      action: "needsMoreInformation",
      note: "請補上仍在有效期限內的證明",
      expectedVersion: "2026-07-14T04:00:00.000000Z",
    }),
    {
      action: "needsMoreInformation",
      note: "請補上仍在有效期限內的證明",
      expectedVersion: "2026-07-14T04:00:00.000000Z",
    }
  );
  assert.throws(
    () => normalizeAdminReviewRequest({ action: "approved", note: "" }),
    (error) => error.code === "REVIEW_NOTE_REQUIRED"
  );
  assert.throws(
    () => normalizeAdminReviewRequest({ action: "rejected", note: "" }),
    (error) => error.code === "REVIEW_NOTE_REQUIRED"
  );
  assert.throws(
    () => normalizeAdminReviewRequest({ action: "delete" }),
    (error) => error.code === "INVALID_REVIEW_ACTION"
  );
  assert.throws(
    () =>
      normalizeAdminReviewRequest({
        action: "approved",
        note: "資格文件已確認。",
        expectedVersion: "old",
      }),
    (error) => error.code === "INVALID_REVIEW_VERSION"
  );
});

test("admin application query defaults to actionable work and normalizes search", () => {
  assert.deepEqual(normalizeAdminApplicationQuery(new URLSearchParams()), {
    scope: "actionable",
    status: "",
    query: "",
  });
  assert.deepEqual(
    normalizeAdminApplicationQuery(
      new URLSearchParams("scope=all&status=approved&query=%20Ray%20")
    ),
    { scope: "all", status: "approved", query: "ray" }
  );
  assert.equal(
    normalizeAdminApplicationQuery(new URLSearchParams("status=unknown")).status,
    ""
  );
});

test("admin application filters and summary keep completed history separate", () => {
  const applications = [
    { uid: "student-one", displayName: "小安", motivation: "陪伴學習", status: "pendingReview" },
    { uid: "student-two", displayName: "Ray", motivation: "英文志工", status: "approved" },
    { uid: "student-three", displayName: "小美", motivation: "課後協助", status: "needsMoreInformation" },
    { uid: "student-four", displayName: "Alex", motivation: "陪讀", status: "rejected" },
  ];

  assert.deepEqual(
    filterVolunteerApplications(applications, {
      scope: "actionable",
      status: "",
      query: "",
    }).map((item) => item.uid),
    ["student-one", "student-three"]
  );
  assert.deepEqual(
    filterVolunteerApplications(applications, {
      scope: "all",
      status: "approved",
      query: "ray",
    }).map((item) => item.uid),
    ["student-two"]
  );
  assert.deepEqual(summarizeVolunteerApplications(applications), {
    total: 4,
    actionable: 2,
    draft: 0,
    pendingReview: 1,
    needsMoreInformation: 1,
    approved: 1,
    rejected: 1,
    suspended: 0,
  });
});

test("admin endpoints reject unauthenticated requests", async () => {
  for (const path of [
    "/admin/session",
    "/admin/volunteer-applications?scope=all",
    "/admin/volunteer-audit?uid=applicant-123",
    "/admin/evidence?objectKey=volunteer-evidence%2Fapplicant-123%2Ffile.pdf",
    "/admin/evidence-ticket?objectKey=volunteer-evidence%2Fapplicant-123%2Ffile.pdf",
  ]) {
    const response = await worker.fetch(new Request(`https://example.test${path}`), {});
    assert.equal(response.status, 401);
    const payload = await response.json();
    assert.equal(payload.ok, false);
    assert.equal(payload.error, "AUTH_REQUIRED");
    assert.ok(payload.requestId);
  }
});
