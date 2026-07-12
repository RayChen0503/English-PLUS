const GROQ_CHAT_COMPLETIONS_URL = "https://api.groq.com/openai/v1/chat/completions";
const FIREBASE_JWKS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";
const MAX_EVIDENCE_BYTES = 10 * 1024 * 1024;
const MAX_EVIDENCE_FILES_PER_APPLICANT = 5;
const MAX_EVIDENCE_TOTAL_BYTES = 25 * 1024 * 1024;
const EVIDENCE_RESERVATION_SECONDS = 10 * 60;
const REVIEW_EVIDENCE_RETENTION_DAYS = 30;
const FINAL_REVIEW_STATUSES = new Set(["approved", "rejected", "suspended"]);
const ALLOWED_EVIDENCE_MIME_TYPES = new Set([
  "application/pdf",
  "image/jpeg",
  "image/png",
]);
const VOLUNTEER_QUALIFICATIONS = new Set([
  "universityEnrollment",
  "englishProficiency",
  "educatorCredential",
  "nonprofitOrVolunteerService",
  "other",
]);

const TASKS = new Set([
  "dailyMission",
  "wrongAnswerExplanation",
  "emotionalSupport",
  "teacherFeedbackDraft",
  "volunteerReplyCoach",
  "progressSummary",
]);

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
  "Access-Control-Allow-Headers": "Authorization,Content-Type",
  "Access-Control-Max-Age": "86400",
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }

    if (url.pathname === "/health" && request.method === "GET") {
      return handleHealth(env);
    }

    if (url.pathname === "/ai" && request.method === "POST") {
      return handleAi(request, env);
    }

    if (url.pathname === "/evidence/upload-ticket" && request.method === "POST") {
      return handleEvidenceUploadTicket(request, env);
    }

    if (url.pathname === "/evidence/upload" && request.method === "PUT") {
      return handleEvidenceUpload(request, env);
    }

    if (url.pathname === "/evidence/object" && request.method === "DELETE") {
      return handleEvidenceDelete(request, env);
    }

    if (
      url.pathname.startsWith("/admin/volunteer-review/") &&
      request.method === "POST"
    ) {
      return handleVolunteerReview(request, env, url);
    }

    if (url.pathname === "/admin/volunteer-applications" && request.method === "GET") {
      return handleVolunteerApplicationList(request, env);
    }

    if (url.pathname === "/admin/evidence" && request.method === "GET") {
      return handleAdminEvidence(request, env, url);
    }

    return jsonResponse({ ok: false, error: "NOT_FOUND" }, 404);
  },

  async scheduled(_controller, env, ctx) {
    ctx.waitUntil(
      cleanupExpiredReviewedEvidence(env)
        .then((result) => {
          console.log(JSON.stringify({ event: "evidence_retention_cleanup", ...result }));
        })
        .catch((error) => {
          console.error(JSON.stringify({
            event: "evidence_retention_cleanup_failed",
            error: error instanceof Error ? error.message : "unknown",
          }));
          throw error;
        })
    );
  },
};

function handleHealth(env) {
  return jsonResponse({
    ok: true,
    service: "englishplus-ai-proxy",
    provider: "groq",
    defaultModel: env.GROQ_DEFAULT_MODEL || "llama-3.1-8b-instant",
  });
}

async function handleAi(request, env) {
  let normalized;

  try {
    await requireFirebaseUser(request, env);
  } catch (error) {
    return authOrValidationError(error);
  }

  try {
    const body = await request.json();
    normalized = normalizeRequest(body?.data ?? body);
  } catch {
    return jsonResponse({
      result: buildFallbackResponse(
        fallbackRequest("dailyMission"),
        "INVALID_JSON"
      ),
    }, 400);
  }

  if (!env.GROQ_API_KEY) {
    return jsonResponse({
      result: buildFallbackResponse(normalized, "GROQ_API_KEY_NOT_CONFIGURED"),
    });
  }

  try {
    const groqBody = buildGroqRequest(normalized, env);
    const groqResponse = await fetch(GROQ_CHAT_COMPLETIONS_URL, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${env.GROQ_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(groqBody),
    });

    const groqJson = await groqResponse.json().catch(() => ({}));
    if (!groqResponse.ok) {
      return jsonResponse({
        result: buildFallbackResponse(
          normalized,
          `GROQ_HTTP_${groqResponse.status}`
        ),
      });
    }

    return jsonResponse({
      result: normalizeGroqResponse(normalized, groqJson),
    });
  } catch {
    return jsonResponse({
      result: buildFallbackResponse(normalized, "GROQ_UNAVAILABLE"),
    });
  }
}

async function handleEvidenceUploadTicket(request, env) {
  if (!env.EVIDENCE_UPLOAD_SIGNING_SECRET || !env.VOLUNTEER_EVIDENCE) {
    return jsonResponse({ ok: false, error: "EVIDENCE_STORAGE_NOT_CONFIGURED" }, 503);
  }

  let user;
  let input;
  try {
    user = await requireFirebaseUser(request, env);
    await requireVolunteerApplicant(user, env, ["pendingApplication"]);
    input = normalizeEvidenceTicketRequest(await request.json());
  } catch (error) {
    return authOrValidationError(error);
  }

  const evidenceId = crypto.randomUUID();
  const extension = extensionForMimeType(input.mimeType);
  const objectKey = `volunteer-evidence/${user.sub}/${evidenceId}.${extension}`;
  const expiresAtSeconds = Math.floor(Date.now() / 1000) + 5 * 60;
  try {
    await reserveEvidenceUpload(env, {
      uid: user.sub,
      evidenceId,
      objectKey,
      mimeType: input.mimeType,
      sizeBytes: input.sizeBytes,
      qualificationKind: input.qualificationKind,
      nowSeconds: Math.floor(Date.now() / 1000),
    });
  } catch (error) {
    return authOrValidationError(error);
  }
  const ticket = await signUploadTicket(
    {
      uid: user.sub,
      evidenceId,
      objectKey,
      mimeType: input.mimeType,
      sizeBytes: input.sizeBytes,
      qualificationKind: input.qualificationKind,
      exp: expiresAtSeconds,
    },
    env.EVIDENCE_UPLOAD_SIGNING_SECRET
  );
  const uploadURL = new URL("/evidence/upload", request.url);
  uploadURL.searchParams.set("ticket", ticket);

  return jsonResponse({
    evidenceId,
    objectKey,
    uploadURL: uploadURL.toString(),
    expiresAt: new Date(expiresAtSeconds * 1000).toISOString(),
  });
}

async function handleEvidenceUpload(request, env) {
  if (!env.EVIDENCE_UPLOAD_SIGNING_SECRET || !env.VOLUNTEER_EVIDENCE) {
    return jsonResponse({ ok: false, error: "EVIDENCE_STORAGE_NOT_CONFIGURED" }, 503);
  }

  let ticket;
  try {
    ticket = await verifyUploadTicket(
      new URL(request.url).searchParams.get("ticket"),
      env.EVIDENCE_UPLOAD_SIGNING_SECRET
    );
  } catch (error) {
    return authOrValidationError(error);
  }

  const contentType = request.headers.get("Content-Type")?.split(";", 1)[0] || "";
  const contentLength = Number(request.headers.get("Content-Length"));
  if (
    contentType !== ticket.mimeType ||
    !Number.isInteger(contentLength) ||
    contentLength !== ticket.sizeBytes ||
    contentLength < 1 ||
    contentLength > MAX_EVIDENCE_BYTES
  ) {
    return jsonResponse({ ok: false, error: "UPLOAD_METADATA_MISMATCH" }, 400);
  }
  if (!ticket.objectKey.startsWith(`volunteer-evidence/${ticket.uid}/`)) {
    return jsonResponse({ ok: false, error: "INVALID_OBJECT_KEY" }, 400);
  }

  const reservation = await env.VOLUNTEER_EVIDENCE.head(ticket.objectKey);
  const reservationMetadata = reservation?.customMetadata || {};
  if (
    !reservation ||
    reservationMetadata.uploadState !== "reserved" ||
    reservationMetadata.ownerUid !== ticket.uid ||
    reservationMetadata.evidenceId !== ticket.evidenceId ||
    Number(reservationMetadata.expectedSizeBytes) !== ticket.sizeBytes ||
    Number(reservationMetadata.reservedUntilSeconds) <= Math.floor(Date.now() / 1000)
  ) {
    return jsonResponse({ ok: false, error: "UPLOAD_RESERVATION_INVALID" }, 409);
  }

  const stored = await env.VOLUNTEER_EVIDENCE.put(ticket.objectKey, request.body, {
    httpMetadata: { contentType },
    customMetadata: {
      ownerUid: ticket.uid,
      evidenceId: ticket.evidenceId,
      qualificationKind: ticket.qualificationKind,
      uploadState: "complete",
      expectedSizeBytes: String(ticket.sizeBytes),
      uploadedAt: new Date().toISOString(),
    },
  });
  if (!stored) {
    return jsonResponse({ ok: false, error: "UPLOAD_FAILED" }, 500);
  }

  return jsonResponse({
    ok: true,
    evidenceId: ticket.evidenceId,
    objectKey: ticket.objectKey,
    etag: stored.etag,
  });
}

async function handleEvidenceDelete(request, env) {
  if (!env.VOLUNTEER_EVIDENCE) {
    return jsonResponse({ ok: false, error: "EVIDENCE_STORAGE_NOT_CONFIGURED" }, 503);
  }
  let user;
  let body;
  try {
    user = await requireFirebaseUser(request, env);
    await requireVolunteerApplicant(user, env, ["pendingApplication"]);
    body = await request.json();
  } catch (error) {
    return authOrValidationError(error);
  }
  const objectKey = safeString(body?.objectKey);
  if (!objectKey || !objectKey.startsWith(`volunteer-evidence/${user.sub}/`)) {
    return jsonResponse({ ok: false, error: "INVALID_OBJECT_KEY" }, 403);
  }
  await env.VOLUNTEER_EVIDENCE.delete(objectKey);
  return jsonResponse({ ok: true });
}

async function handleVolunteerReview(request, env, url) {
  let admin;
  try {
    admin = await requireFirebaseUser(request, env);
    if (admin.admin !== true) {
      throw httpError(403, "ADMIN_REQUIRED");
    }
  } catch (error) {
    return authOrValidationError(error);
  }

  const uid = decodeURIComponent(url.pathname.split("/").pop() || "").trim();
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(uid)) {
    return jsonResponse({ ok: false, error: "INVALID_UID" }, 400);
  }

  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ ok: false, error: "INVALID_JSON" }, 400);
  }
  const actions = {
    approved: { applicationStatus: "approved", accountStatus: "active", active: true },
    rejected: { applicationStatus: "rejected", accountStatus: "disabled", active: false },
    needsMoreInformation: {
      applicationStatus: "needsMoreInformation",
      accountStatus: "pendingApplication",
      active: false,
    },
    suspended: { applicationStatus: "suspended", accountStatus: "suspended", active: false },
  };
  const decision = actions[body?.action];
  if (!decision) {
    return jsonResponse({ ok: false, error: "INVALID_REVIEW_ACTION" }, 400);
  }

  try {
    await commitVolunteerReview(env, {
      uid,
      reviewerUid: admin.sub,
      note: safeString(body?.note)?.slice(0, 1000) || "",
      ...decision,
    });
    return jsonResponse({ ok: true, uid, status: decision.applicationStatus });
  } catch {
    return jsonResponse({ ok: false, error: "REVIEW_COMMIT_FAILED" }, 502);
  }
}

async function handleVolunteerApplicationList(request, env) {
  try {
    const admin = await requireFirebaseUser(request, env);
    if (admin.admin !== true) throw httpError(403, "ADMIN_REQUIRED");
    const applications = await listVolunteerApplications(env);
    return jsonResponse({ ok: true, applications });
  } catch (error) {
    if (error?.status) return authOrValidationError(error);
    return jsonResponse({ ok: false, error: "APPLICATION_LIST_FAILED" }, 502);
  }
}

async function handleAdminEvidence(request, env, url) {
  if (!env.VOLUNTEER_EVIDENCE) {
    return jsonResponse({ ok: false, error: "EVIDENCE_STORAGE_NOT_CONFIGURED" }, 503);
  }
  try {
    const admin = await requireFirebaseUser(request, env);
    if (admin.admin !== true) throw httpError(403, "ADMIN_REQUIRED");
    const objectKey = safeString(url.searchParams.get("objectKey"));
    if (!objectKey || !objectKey.startsWith("volunteer-evidence/")) {
      throw httpError(400, "INVALID_OBJECT_KEY");
    }
    const object = await env.VOLUNTEER_EVIDENCE.get(objectKey);
    if (!object?.body) throw httpError(404, "EVIDENCE_NOT_FOUND");
    const headers = new Headers({
      "Cache-Control": "private, no-store",
      "Content-Type": object.httpMetadata?.contentType || "application/octet-stream",
      "Content-Disposition": "attachment",
      "X-Content-Type-Options": "nosniff",
    });
    return new Response(object.body, { status: 200, headers });
  } catch (error) {
    return authOrValidationError(error);
  }
}

function normalizeEvidenceTicketRequest(raw) {
  const filename = safeString(raw?.filename);
  const mimeType = safeString(raw?.mimeType);
  const sizeBytes = Number(raw?.sizeBytes);
  const qualificationKind = safeString(raw?.qualificationKind);
  if (!filename || filename.length > 180) {
    throw httpError(400, "INVALID_FILENAME");
  }
  if (!mimeType || !ALLOWED_EVIDENCE_MIME_TYPES.has(mimeType)) {
    throw httpError(400, "UNSUPPORTED_FILE_TYPE");
  }
  if (!Number.isInteger(sizeBytes) || sizeBytes < 1 || sizeBytes > MAX_EVIDENCE_BYTES) {
    throw httpError(400, "INVALID_FILE_SIZE");
  }
  if (!qualificationKind || !VOLUNTEER_QUALIFICATIONS.has(qualificationKind)) {
    throw httpError(400, "INVALID_QUALIFICATION_KIND");
  }
  return { filename, mimeType, sizeBytes, qualificationKind };
}

function extensionForMimeType(mimeType) {
  switch (mimeType) {
    case "application/pdf":
      return "pdf";
    case "image/jpeg":
      return "jpg";
    case "image/png":
      return "png";
    default:
      throw httpError(400, "UNSUPPORTED_FILE_TYPE");
  }
}

async function reserveEvidenceUpload(env, reservation) {
  let objects = await listEvidenceObjectsForUid(env, reservation.uid);
  let quota = evidenceQuotaSnapshot(objects, reservation.nowSeconds);
  if (quota.expiredReservationKeys.length > 0) {
    await Promise.all(
      quota.expiredReservationKeys.map((key) => env.VOLUNTEER_EVIDENCE.delete(key))
    );
    objects = await listEvidenceObjectsForUid(env, reservation.uid);
    quota = evidenceQuotaSnapshot(objects, reservation.nowSeconds);
  }

  enforceEvidenceQuota(quota, reservation.sizeBytes);
  const reservedUntilSeconds =
    reservation.nowSeconds + EVIDENCE_RESERVATION_SECONDS;
  await env.VOLUNTEER_EVIDENCE.put(
    reservation.objectKey,
    new Uint8Array(0),
    {
      httpMetadata: { contentType: reservation.mimeType },
      customMetadata: {
        ownerUid: reservation.uid,
        evidenceId: reservation.evidenceId,
        qualificationKind: reservation.qualificationKind,
        uploadState: "reserved",
        expectedSizeBytes: String(reservation.sizeBytes),
        reservedAtSeconds: String(reservation.nowSeconds),
        reservedUntilSeconds: String(reservedUntilSeconds),
      },
    }
  );

  const confirmed = evidenceQuotaSnapshot(
    await listEvidenceObjectsForUid(env, reservation.uid),
    reservation.nowSeconds
  );
  if (
    confirmed.fileCount > MAX_EVIDENCE_FILES_PER_APPLICANT ||
    confirmed.totalBytes > MAX_EVIDENCE_TOTAL_BYTES
  ) {
    await env.VOLUNTEER_EVIDENCE.delete(reservation.objectKey);
    throw httpError(
      confirmed.fileCount > MAX_EVIDENCE_FILES_PER_APPLICANT ? 409 : 413,
      confirmed.fileCount > MAX_EVIDENCE_FILES_PER_APPLICANT
        ? "EVIDENCE_FILE_LIMIT_REACHED"
        : "EVIDENCE_TOTAL_SIZE_LIMIT_REACHED"
    );
  }
}

async function listEvidenceObjectsForUid(env, uid) {
  return listEvidenceObjects(env, `volunteer-evidence/${uid}/`);
}

async function listEvidenceObjects(env, prefix = "volunteer-evidence/") {
  const objects = [];
  let cursor;
  do {
    const page = await env.VOLUNTEER_EVIDENCE.list({
      prefix,
      cursor,
      limit: 100,
      include: ["customMetadata"],
    });
    objects.push(...page.objects);
    cursor = page.truncated ? page.cursor : undefined;
  } while (cursor);
  return objects;
}

function evidenceQuotaSnapshot(objects, nowSeconds) {
  const snapshot = {
    fileCount: 0,
    totalBytes: 0,
    expiredReservationKeys: [],
  };
  for (const object of objects) {
    const metadata = object.customMetadata || {};
    if (metadata.uploadState === "reserved") {
      if (Number(metadata.reservedUntilSeconds) <= nowSeconds) {
        snapshot.expiredReservationKeys.push(object.key);
        continue;
      }
      snapshot.fileCount += 1;
      snapshot.totalBytes += Number(metadata.expectedSizeBytes) || 0;
      continue;
    }
    snapshot.fileCount += 1;
    snapshot.totalBytes += Number(object.size) || 0;
  }
  return snapshot;
}

function enforceEvidenceQuota(quota, requestedBytes) {
  if (quota.fileCount >= MAX_EVIDENCE_FILES_PER_APPLICANT) {
    throw httpError(409, "EVIDENCE_FILE_LIMIT_REACHED");
  }
  if (quota.totalBytes + requestedBytes > MAX_EVIDENCE_TOTAL_BYTES) {
    throw httpError(413, "EVIDENCE_TOTAL_SIZE_LIMIT_REACHED");
  }
}

async function requireFirebaseUser(request, env) {
  const authorization = request.headers.get("Authorization") || "";
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    throw httpError(401, "AUTH_REQUIRED");
  }
  const claims = await verifyFirebaseIdToken(
    match[1],
    env.FIREBASE_PROJECT_ID || "englishplus-testflight"
  );
  return { ...claims, firebaseIdToken: match[1] };
}

async function requireVolunteerApplicant(
  user,
  env,
  allowedStatuses = ["pendingApplication", "pendingApproval"]
) {
  const projectId = env.FIREBASE_PROJECT_ID || "englishplus-testflight";
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/users/${encodeURIComponent(user.sub)}`,
    { headers: { Authorization: `Bearer ${user.firebaseIdToken}` } }
  );
  if (!response.ok) {
    throw httpError(403, "VOLUNTEER_PROFILE_REQUIRED");
  }
  const document = await response.json();
  const role = document.fields?.primaryRole?.stringValue;
  const status = document.fields?.accountStatus?.stringValue;
  if (
    role !== "volunteer" ||
    !allowedStatuses.includes(status)
  ) {
    throw httpError(403, "VOLUNTEER_APPLICATION_NOT_EDITABLE");
  }
}

async function verifyFirebaseIdToken(token, projectId) {
  const segments = token.split(".");
  if (segments.length !== 3) {
    throw httpError(401, "INVALID_TOKEN");
  }
  const header = decodeJsonSegment(segments[0]);
  const claims = decodeJsonSegment(segments[1]);
  const now = Math.floor(Date.now() / 1000);
  if (
    header.alg !== "RS256" ||
    !header.kid ||
    claims.aud !== projectId ||
    claims.iss !== `https://securetoken.google.com/${projectId}` ||
    typeof claims.sub !== "string" ||
    claims.sub.length < 1 ||
    claims.sub.length > 128 ||
    typeof claims.exp !== "number" ||
    claims.exp <= now - 30 ||
    typeof claims.iat !== "number" ||
    claims.iat > now + 30
  ) {
    throw httpError(401, "INVALID_TOKEN_CLAIMS");
  }

  const response = await fetch(FIREBASE_JWKS_URL, {
    cf: { cacheEverything: true, cacheTtl: 3600 },
  });
  if (!response.ok) {
    throw httpError(503, "AUTH_KEYS_UNAVAILABLE");
  }
  const jwks = await response.json();
  const jwk = jwks.keys?.find((candidate) => candidate.kid === header.kid);
  if (!jwk) {
    throw httpError(401, "UNKNOWN_TOKEN_KEY");
  }

  const key = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["verify"]
  );
  const verified = await crypto.subtle.verify(
    "RSASSA-PKCS1-v1_5",
    key,
    decodeBase64Url(segments[2]),
    new TextEncoder().encode(`${segments[0]}.${segments[1]}`)
  );
  if (!verified) {
    throw httpError(401, "INVALID_TOKEN_SIGNATURE");
  }
  return claims;
}

async function signUploadTicket(payload, secret) {
  const encodedPayload = encodeBase64Url(
    new TextEncoder().encode(JSON.stringify(payload))
  );
  const key = await hmacKey(secret, ["sign"]);
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(encodedPayload)
  );
  return `${encodedPayload}.${encodeBase64Url(new Uint8Array(signature))}`;
}

async function verifyUploadTicket(ticket, secret) {
  if (!ticket) {
    throw httpError(401, "UPLOAD_TICKET_REQUIRED");
  }
  const segments = ticket.split(".");
  if (segments.length !== 2) {
    throw httpError(401, "INVALID_UPLOAD_TICKET");
  }
  const key = await hmacKey(secret, ["verify"]);
  const verified = await crypto.subtle.verify(
    "HMAC",
    key,
    decodeBase64Url(segments[1]),
    new TextEncoder().encode(segments[0])
  );
  if (!verified) {
    throw httpError(401, "INVALID_UPLOAD_TICKET");
  }
  const payload = JSON.parse(
    new TextDecoder().decode(decodeBase64Url(segments[0]))
  );
  if (
    typeof payload.exp !== "number" ||
    payload.exp <= Math.floor(Date.now() / 1000) ||
    typeof payload.uid !== "string" ||
    typeof payload.objectKey !== "string" ||
    typeof payload.evidenceId !== "string" ||
    !ALLOWED_EVIDENCE_MIME_TYPES.has(payload.mimeType) ||
    !VOLUNTEER_QUALIFICATIONS.has(payload.qualificationKind)
  ) {
    throw httpError(401, "EXPIRED_OR_INVALID_UPLOAD_TICKET");
  }
  return payload;
}

async function hmacKey(secret, usages) {
  return crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    usages
  );
}

async function commitVolunteerReview(env, review) {
  const projectId = env.FIREBASE_PROJECT_ID || "englishplus-testflight";
  const accessToken = await serviceAccountAccessToken(env);
  const now = new Date().toISOString();
  const retentionUntil = FINAL_REVIEW_STATUSES.has(review.applicationStatus)
    ? new Date(Date.now() + REVIEW_EVIDENCE_RETENTION_DAYS * 24 * 60 * 60 * 1000)
        .toISOString()
    : null;
  const root = `projects/${projectId}/databases/(default)/documents`;
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents:commit`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        writes: [
          {
            update: {
              name: `${root}/volunteerApplications/${review.uid}`,
              fields: {
                status: { stringValue: review.applicationStatus },
                reviewedByUid: { stringValue: review.reviewerUid },
                reviewedAt: { timestampValue: now },
                reviewNote: { stringValue: review.note },
                evidenceRetentionUntil: retentionUntil
                  ? { timestampValue: retentionUntil }
                  : { nullValue: null },
                evidenceDeletedAt: { nullValue: null },
                updatedAt: { timestampValue: now },
              },
            },
            updateMask: {
              fieldPaths: [
                "status",
                "reviewedByUid",
                "reviewedAt",
                "reviewNote",
                "evidenceRetentionUntil",
                "evidenceDeletedAt",
                "updatedAt",
              ],
            },
            currentDocument: { exists: true },
          },
          {
            update: {
              name: `${root}/users/${review.uid}`,
              fields: {
                accountStatus: { stringValue: review.accountStatus },
                active: { booleanValue: review.active },
                updatedAt: { timestampValue: now },
              },
            },
            updateMask: {
              fieldPaths: ["accountStatus", "active", "updatedAt"],
            },
            currentDocument: { exists: true },
          },
        ],
      }),
    }
  );
  if (!response.ok) {
    throw new Error("Firestore review commit failed.");
  }
}

async function listVolunteerApplications(env) {
  const accessToken = await serviceAccountAccessToken(env);
  const documents = await listVolunteerApplicationDocuments(env, accessToken);
  return documents
    .map(normalizeVolunteerApplicationDocument)
    .filter((item) => ["pendingReview", "needsMoreInformation"].includes(item.status))
    .sort((left, right) => right.submittedAt.localeCompare(left.submittedAt));
}

async function listVolunteerApplicationDocuments(env, accessToken) {
  const projectId = env.FIREBASE_PROJECT_ID || "englishplus-testflight";
  const documents = [];
  let pageToken = "";

  do {
    const endpoint = new URL(
      `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/volunteerApplications`
    );
    endpoint.searchParams.set("pageSize", "100");
    if (pageToken) endpoint.searchParams.set("pageToken", pageToken);
    const response = await fetch(endpoint, {
      headers: { Authorization: `Bearer ${accessToken}` },
    });
    if (!response.ok) throw new Error("Unable to list volunteer applications.");
    const payload = await response.json();
    documents.push(...(payload.documents || []));
    pageToken = safeString(payload.nextPageToken);
  } while (pageToken);

  return documents;
}

function normalizeVolunteerApplicationDocument(document) {
  const fields = document.fields || {};
  const evidenceValues = fields.evidence?.arrayValue?.values || [];
  return {
    uid: firestoreString(fields.uid),
    displayName: firestoreString(fields.displayName) || "志工申請者",
    status: firestoreString(fields.status),
    motivation: firestoreString(fields.motivation),
    submittedAt:
      fields.submittedAt?.timestampValue || fields.updatedAt?.timestampValue || "",
    reviewedAt: fields.reviewedAt?.timestampValue || "",
    evidenceRetentionUntil: fields.evidenceRetentionUntil?.timestampValue || "",
    evidenceDeletedAt: fields.evidenceDeletedAt?.timestampValue || "",
    evidence: evidenceValues.map((value) => {
      const item = value.mapValue?.fields || {};
      return {
        id: firestoreString(item.id),
        kind: firestoreString(item.kind),
        objectKey: firestoreString(item.storageObjectKey),
        filename: firestoreString(item.originalFilename),
        mimeType: firestoreString(item.mimeType),
        sizeBytes: Number(item.sizeBytes?.integerValue || 0),
      };
    }),
  };
}

async function cleanupExpiredReviewedEvidence(env, now = new Date()) {
  if (!env.VOLUNTEER_EVIDENCE) {
    throw new Error("Volunteer evidence storage is not configured.");
  }
  const accessToken = await serviceAccountAccessToken(env);
  const documents = await listVolunteerApplicationDocuments(env, accessToken);
  const applications = documents.map(normalizeVolunteerApplicationDocument);
  const expired = selectExpiredReviewedApplications(applications, now);
  const expiredReservations = await cleanupExpiredUploadReservations(env, now);
  let deletedObjects = 0;

  for (const application of expired) {
    const prefix = `volunteer-evidence/${application.uid}/`;
    const keys = application.evidence
      .map((item) => item.objectKey)
      .filter((key) => key.startsWith(prefix));
    await Promise.all(keys.map((key) => env.VOLUNTEER_EVIDENCE.delete(key)));
    await commitEvidenceDeletion(env, accessToken, application.uid, now);
    deletedObjects += keys.length;
  }

  return {
    scannedApplications: applications.length,
    expiredApplications: expired.length,
    deletedObjects,
    deletedExpiredReservations: expiredReservations,
    completedAt: now.toISOString(),
  };
}

async function cleanupExpiredUploadReservations(env, now = new Date()) {
  const nowSeconds = Math.floor(now.getTime() / 1000);
  const objects = await listEvidenceObjects(env);
  const expiredKeys = objects
    .filter((object) => object.customMetadata?.uploadState === "reserved")
    .filter(
      (object) => Number(object.customMetadata?.reservedUntilSeconds) <= nowSeconds
    )
    .map((object) => object.key);
  await Promise.all(expiredKeys.map((key) => env.VOLUNTEER_EVIDENCE.delete(key)));
  return expiredKeys.length;
}

function selectExpiredReviewedApplications(applications, now = new Date()) {
  const fallbackCutoff = now.getTime()
    - REVIEW_EVIDENCE_RETENTION_DAYS * 24 * 60 * 60 * 1000;
  return applications.filter((application) => {
    if (!FINAL_REVIEW_STATUSES.has(application.status)) return false;
    if (application.evidenceDeletedAt || application.evidence.length === 0) return false;
    const retentionTime = Date.parse(application.evidenceRetentionUntil);
    if (Number.isFinite(retentionTime)) return retentionTime <= now.getTime();
    const reviewedTime = Date.parse(application.reviewedAt);
    return Number.isFinite(reviewedTime) && reviewedTime <= fallbackCutoff;
  });
}

async function commitEvidenceDeletion(env, accessToken, uid, now) {
  const projectId = env.FIREBASE_PROJECT_ID || "englishplus-testflight";
  const name = `projects/${projectId}/databases/(default)/documents/volunteerApplications/${uid}`;
  const timestamp = now.toISOString();
  const response = await fetch(
    `https://firestore.googleapis.com/v1/${name}?updateMask.fieldPaths=evidence&updateMask.fieldPaths=evidenceDeletedAt&updateMask.fieldPaths=updatedAt&currentDocument.exists=true`,
    {
      method: "PATCH",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        name,
        fields: {
          evidence: { arrayValue: { values: [] } },
          evidenceDeletedAt: { timestampValue: timestamp },
          updatedAt: { timestampValue: timestamp },
        },
      }),
    }
  );
  if (!response.ok) {
    throw new Error("Unable to record volunteer evidence deletion.");
  }
}

function firestoreString(value) {
  return value?.stringValue || "";
}

async function serviceAccountAccessToken(env) {
  if (!env.FIREBASE_SERVICE_ACCOUNT_EMAIL || !env.FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY) {
    throw new Error("Firebase service account is not configured.");
  }
  const now = Math.floor(Date.now() / 1000);
  const assertion = await signServiceAccountJwt(
    {
      iss: env.FIREBASE_SERVICE_ACCOUNT_EMAIL,
      scope: "https://www.googleapis.com/auth/datastore",
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    },
    env.FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY
  );
  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const payload = await response.json();
  if (!response.ok || !payload.access_token) {
    throw new Error("Unable to authorize Firestore review.");
  }
  return payload.access_token;
}

async function signServiceAccountJwt(claims, privateKeyPem) {
  const header = encodeBase64Url(
    new TextEncoder().encode(JSON.stringify({ alg: "RS256", typ: "JWT" }))
  );
  const body = encodeBase64Url(
    new TextEncoder().encode(JSON.stringify(claims))
  );
  const input = `${header}.${body}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemToArrayBuffer(privateKeyPem),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(input)
  );
  return `${input}.${encodeBase64Url(new Uint8Array(signature))}`;
}

function pemToArrayBuffer(pem) {
  const normalized = pem.replace(/\\n/g, "\n");
  const base64 = normalized
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s/g, "");
  return decodeBase64(base64).buffer;
}

function decodeJsonSegment(segment) {
  try {
    return JSON.parse(new TextDecoder().decode(decodeBase64Url(segment)));
  } catch {
    throw httpError(401, "INVALID_TOKEN");
  }
}

function encodeBase64Url(bytes) {
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/g, "");
}

function decodeBase64Url(value) {
  const base64 = value.replace(/-/g, "+").replace(/_/g, "/");
  return decodeBase64(base64.padEnd(Math.ceil(base64.length / 4) * 4, "="));
}

function decodeBase64(value) {
  const binary = atob(value);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

function httpError(status, code) {
  return Object.assign(new Error(code), { status, code });
}

function authOrValidationError(error) {
  const status = Number(error?.status) || 400;
  const code = safeString(error?.code) || "INVALID_REQUEST";
  return jsonResponse({ ok: false, error: code }, status);
}

function normalizeRequest(raw) {
  if (!raw || typeof raw !== "object") {
    throw new Error("Request data is required.");
  }

  if (!TASKS.has(raw.taskType)) {
    throw new Error("Unsupported task type.");
  }

  const classId = safeString(raw.classId);
  if (!classId || !/^[A-Z0-9-]{3,64}$/.test(classId)) {
    throw new Error("Invalid classId.");
  }

  return {
    taskType: raw.taskType,
    classId,
    studentUid: safeString(raw.studentUid),
    sessionId: safeString(raw.sessionId),
    qualityMode: raw.qualityMode === "quality" ? "quality" : "free",
    locale: raw.locale === "en-US" ? "en-US" : "zh-TW",
    context: sanitizeContext(raw.context),
  };
}

function buildGroqRequest(request, env) {
  const model =
    request.qualityMode === "quality"
      ? env.GROQ_QUALITY_MODEL || "llama-3.3-70b-versatile"
      : env.GROQ_DEFAULT_MODEL || "llama-3.1-8b-instant";

  return {
    model,
    messages: buildMessages(request),
    temperature: request.taskType === "dailyMission" ? 0.3 : 0.5,
    max_tokens: maxTokensForTask(request.taskType),
    response_format: { type: "json_object" },
  };
}

function buildMessages(request) {
  return [
    {
      role: "system",
      content: [
        "You are English+, a rural junior-high English learning companion.",
        "Use Traditional Chinese for student-facing output unless locale is en-US.",
        "Never mention APIs, providers, keys, backend internals, or implementation details.",
        "Return compact JSON only. Do not use markdown fences.",
        "Do not diagnose mental health. If risk is high, recommend teacher or trusted adult support.",
      ].join(" "),
    },
    {
      role: "user",
      content: JSON.stringify({
        taskType: request.taskType,
        locale: request.locale,
        instruction: taskInstruction(request.taskType),
        context: request.context,
      }),
    },
  ];
}

function taskInstruction(taskType) {
  switch (taskType) {
    case "dailyMission":
      return [
        "Create a short daily English mission.",
        "Return keys: summary, mission.",
        "mission must include track repair|steady|challenge, targetCorrectCount, recommendedMinutes, questionPlan.",
        "questionPlan items must include type, difficulty, targetCorrect.",
      ].join(" ");
    case "wrongAnswerExplanation":
      return "Return keys: shortFeedback, whyWrong, nextHint, tryAgain, staffEscalationNeeded.";
    case "emotionalSupport":
      return "Return keys: summary, supportLevel, recommendedNextAction. Keep it low-pressure.";
    case "teacherFeedbackDraft":
      return "Return keys: teacherSummary, studentFacingFeedback, recommendedNextAction.";
    case "volunteerReplyCoach":
      return "Return keys: studentFacingFeedback, recommendedNextAction, summary.";
    case "progressSummary":
      return "Return keys: summary, recommendedNextAction.";
    default:
      return "Return compact JSON for English+.";
  }
}

function normalizeGroqResponse(request, response) {
  const content = response?.choices?.[0]?.message?.content;
  const parsed = parseObject(content);

  return {
    ok: true,
    fallbackUsed: false,
    taskType: request.taskType,
    qualityMode: request.qualityMode,
    modelUsed: safeString(response?.model) || modelNameFromRequest(request),
    output: normalizeOutput(request.taskType, parsed || { summary: safeString(content) || "" }),
    usage: {
      promptTokens: Number(response?.usage?.prompt_tokens || 0),
      completionTokens: Number(response?.usage?.completion_tokens || 0),
      totalTokens: Number(response?.usage?.total_tokens || 0),
    },
    requestId: safeString(response?.id) || crypto.randomUUID(),
  };
}

function normalizeOutput(taskType, output) {
  if (taskType === "dailyMission") {
    const mission = normalizeMission(output.mission || output);
    return {
      summary: safeString(output.summary) || "English+ 已安排今天的小任務。",
      mission,
    };
  }

  return {
    summary: safeString(output.summary),
    shortFeedback: safeString(output.shortFeedback),
    whyWrong: safeString(output.whyWrong),
    nextHint: safeString(output.nextHint),
    tryAgain: typeof output.tryAgain === "boolean" ? output.tryAgain : undefined,
    staffEscalationNeeded:
      typeof output.staffEscalationNeeded === "boolean"
        ? output.staffEscalationNeeded
        : undefined,
    supportLevel: safeString(output.supportLevel),
    teacherSummary: safeString(output.teacherSummary),
    studentFacingFeedback: safeString(output.studentFacingFeedback),
    recommendedNextAction: safeString(output.recommendedNextAction),
  };
}

function normalizeMission(raw) {
  const track = ["repair", "steady", "challenge"].includes(raw?.track)
    ? raw.track
    : "steady";
  const plan = Array.isArray(raw?.questionPlan) ? raw.questionPlan : [];

  return {
    track,
    targetCorrectCount: clampInteger(raw?.targetCorrectCount, 1, 12, 3),
    recommendedMinutes: clampInteger(raw?.recommendedMinutes, 3, 30, 8),
    questionPlan: plan.slice(0, 6).map((item) => ({
      type: safeString(item?.type) || "multipleChoice",
      difficulty: safeString(item?.difficulty) || "core",
      targetCorrect: clampInteger(item?.targetCorrect, 1, 6, 1),
    })),
  };
}

function buildFallbackResponse(request, errorCode) {
  const output =
    request.taskType === "dailyMission"
      ? {
          summary: "今天先完成一個短任務，答對才算進度。",
          mission: {
            track: "repair",
            targetCorrectCount: 3,
            recommendedMinutes: 8,
            questionPlan: [
              { type: "multipleChoice", difficulty: "foundation", targetCorrect: 1 },
              { type: "fillBlank", difficulty: "core", targetCorrect: 2 },
            ],
          },
        }
      : {
          summary: "English+ 先給你一個簡短提示，稍後可以再請老師或志工協助。",
          supportLevel: "tryAgain",
          recommendedNextAction: "先看提示，再試一次。",
        };

  return {
    ok: false,
    fallbackUsed: true,
    taskType: request.taskType,
    qualityMode: request.qualityMode,
    modelUsed: "local-fallback",
    output,
    usage: { promptTokens: 0, completionTokens: 0, totalTokens: 0 },
    requestId: crypto.randomUUID(),
    errorCode,
  };
}

function sanitizeContext(context) {
  if (!context || typeof context !== "object") {
    return {};
  }

  const allowedKeys = new Set([
    "moodScore",
    "availableTimeLevel",
    "wantsChallenge",
    "preferredQuestionTypes",
    "recentAccuracy",
    "recentWeakSkills",
    "questionType",
    "questionPrompt",
    "studentAnswer",
    "correctAnswer",
    "explanation",
    "supportReason",
    "supportThreadId",
    "attemptCount",
  ]);

  return Object.fromEntries(
    Object.entries(context)
      .filter(([key]) => allowedKeys.has(key))
      .map(([key, value]) => [key, sanitizeValue(value)])
  );
}

function sanitizeValue(value) {
  if (typeof value === "string") {
    return value.trim().slice(0, 1200);
  }
  if (Array.isArray(value)) {
    return value.slice(0, 20).map(sanitizeValue);
  }
  if (typeof value === "number" || typeof value === "boolean") {
    return value;
  }
  return null;
}

function parseObject(value) {
  if (typeof value !== "string") {
    return null;
  }
  try {
    const parsed = JSON.parse(value);
    return parsed && typeof parsed === "object" && !Array.isArray(parsed)
      ? parsed
      : null;
  } catch {
    return null;
  }
}

function fallbackRequest(taskType) {
  return {
    taskType,
    classId: "YILAN-CHENGZHI-8A",
    qualityMode: "free",
    locale: "zh-TW",
    context: {},
  };
}

function maxTokensForTask(taskType) {
  switch (taskType) {
    case "dailyMission":
      return 450;
    case "wrongAnswerExplanation":
      return 350;
    case "emotionalSupport":
      return 300;
    case "teacherFeedbackDraft":
      return 400;
    case "volunteerReplyCoach":
      return 350;
    case "progressSummary":
      return 450;
    default:
      return 300;
  }
}

function modelNameFromRequest(request) {
  return request.qualityMode === "quality"
    ? "llama-3.3-70b-versatile"
    : "llama-3.1-8b-instant";
}

function clampInteger(value, min, max, fallback) {
  const number = Number(value);
  if (!Number.isFinite(number)) {
    return fallback;
  }
  return Math.min(max, Math.max(min, Math.round(number)));
}

function safeString(value) {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : undefined;
}

function jsonResponse(body, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}

export {
  evidenceQuotaSnapshot,
  enforceEvidenceQuota,
  normalizeEvidenceTicketRequest,
  normalizeRequest,
  selectExpiredReviewedApplications,
  signUploadTicket,
  verifyUploadTicket,
};
