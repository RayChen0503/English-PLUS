import assert from "node:assert/strict";
import { test } from "vitest";

import worker, {
  adminEvidenceHeaders,
  filterVolunteerApplications,
  normalizeAdminApplicationQuery,
  normalizeAdminReviewRequest,
  summarizeVolunteerApplications,
} from "../src/index.js";

test("admin evidence preview is browser-readable without downloading or caching", () => {
  const headers = adminEvidenceHeaders({
    filename: "qualification.pdf",
    contentType: "application/pdf",
    requestId: "evidence-request",
  });
  assert.equal(headers.get("Access-Control-Allow-Origin"), "*");
  assert.equal(headers.get("Content-Type"), "application/pdf");
  assert.equal(headers.get("Content-Disposition"), 'inline; filename="qualification.pdf"');
  assert.equal(headers.get("Cache-Control"), "private, no-store");
  assert.equal(headers.get("X-Content-Type-Options"), "nosniff");
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
    () => normalizeAdminReviewRequest({ action: "approved", expectedVersion: "old" }),
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
  ]) {
    const response = await worker.fetch(new Request(`https://example.test${path}`), {});
    assert.equal(response.status, 401);
    const payload = await response.json();
    assert.equal(payload.ok, false);
    assert.equal(payload.error, "AUTH_REQUIRED");
    assert.ok(payload.requestId);
  }
});
