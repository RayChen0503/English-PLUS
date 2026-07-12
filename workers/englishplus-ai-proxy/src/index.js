const GROQ_CHAT_COMPLETIONS_URL = "https://api.groq.com/openai/v1/chat/completions";
const FIREBASE_JWKS_URL =
  "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";
const MAX_EVIDENCE_BYTES = 10 * 1024 * 1024;
const MAX_EVIDENCE_FILES_PER_APPLICANT = 5;
const MAX_EVIDENCE_TOTAL_BYTES = 25 * 1024 * 1024;
const EVIDENCE_RESERVATION_SECONDS = 10 * 60;
const REVIEW_EVIDENCE_RETENTION_DAYS = 30;
const CLASS_JOIN_WINDOW_SECONDS = 15 * 60;
const CLASS_JOIN_MAX_ATTEMPTS = 12;
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

    if (url.pathname === "/classrooms" && request.method === "GET") {
      return handleClassroomList(request, env);
    }

    if (url.pathname === "/classrooms" && request.method === "POST") {
      return handleClassroomCreate(request, env);
    }

    if (url.pathname === "/classrooms/bootstrap" && request.method === "POST") {
      return handleClassroomBootstrap(request, env);
    }

    if (url.pathname === "/classrooms/join" && request.method === "POST") {
      return handleClassroomJoin(request, env);
    }

    const classroomAction = url.pathname.match(
      /^\/classrooms\/([A-Z0-9-]{3,64})\/(leave|reset-code)$/
    );
    if (classroomAction && request.method === "POST") {
      return classroomAction[2] === "leave"
        ? handleClassroomLeave(request, env, classroomAction[1])
        : handleClassroomCodeReset(request, env, classroomAction[1]);
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
      action: body.action,
      reviewerUid: admin.sub,
      note: safeString(body?.note)?.slice(0, 1000) || "",
      ...decision,
    });
    return jsonResponse({ ok: true, uid, status: decision.applicationStatus });
  } catch (error) {
    if (error?.status) return authOrValidationError(error);
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

async function handleClassroomList(request, env) {
  try {
    const user = await requireFirebaseUser(request, env);
    const classrooms = await listClassroomsForUser(env, user);
    return jsonResponse({ ok: true, classrooms });
  } catch (error) {
    if (error?.status) return authOrValidationError(error);
    return jsonResponse({ ok: false, error: "CLASSROOM_LIST_FAILED" }, 502);
  }
}

async function handleClassroomCreate(request, env) {
  try {
    const user = await requireFirebaseUser(request, env);
    const input = normalizeClassroomCreateRequest(await request.json());
    const classroom = await createClassroom(env, user, input.name);
    return jsonResponse({ ok: true, classroom }, 201);
  } catch (error) {
    if (error?.status) return authOrValidationError(error);
    return jsonResponse({ ok: false, error: "CLASSROOM_CREATE_FAILED" }, 502);
  }
}

async function handleClassroomBootstrap(request, env) {
  try {
    const user = await requireFirebaseUser(request, env);
    const migrated = await ensureLegacyClassroomAccount(env, user);
    return jsonResponse({ ok: true, migrated });
  } catch (error) {
    if (error?.status) return authOrValidationError(error);
    return jsonResponse({ ok: false, error: "CLASSROOM_BOOTSTRAP_FAILED" }, 502);
  }
}

async function handleClassroomJoin(request, env) {
  try {
    const user = await requireFirebaseUser(request, env);
    const input = normalizeClassroomJoinRequest(await request.json());
    const classroom = await joinClassroom(env, user, input.code);
    return jsonResponse({ ok: true, classroom });
  } catch (error) {
    if (error?.status) return authOrValidationError(error);
    return jsonResponse({ ok: false, error: "CLASSROOM_JOIN_FAILED" }, 502);
  }
}

async function handleClassroomLeave(request, env, classId) {
  try {
    const user = await requireFirebaseUser(request, env);
    await leaveClassroom(env, user, classId);
    return jsonResponse({ ok: true, classId, left: true });
  } catch (error) {
    if (error?.status) return authOrValidationError(error);
    return jsonResponse({ ok: false, error: "CLASSROOM_LEAVE_FAILED" }, 502);
  }
}

async function handleClassroomCodeReset(request, env, classId) {
  try {
    const user = await requireFirebaseUser(request, env);
    const classroom = await resetClassroomCode(env, user, classId);
    return jsonResponse({ ok: true, classroom });
  } catch (error) {
    if (error?.status) return authOrValidationError(error);
    return jsonResponse({ ok: false, error: "CLASSROOM_CODE_RESET_FAILED" }, 502);
  }
}

function normalizeClassroomCreateRequest(raw) {
  const name = safeString(raw?.name)?.normalize("NFKC").replace(/\s+/g, " ");
  if (!name || name.length < 2 || name.length > 40 || /[\u0000-\u001F]/.test(name)) {
    throw httpError(400, "INVALID_CLASSROOM_NAME");
  }
  return { name };
}

function normalizeClassroomCode(value) {
  const code = safeString(value)?.normalize("NFKC").toUpperCase().replace(/[^A-Z0-9]/g, "");
  if (!code || !/^[A-HJ-NP-Z2-9]{8}$/.test(code)) {
    throw httpError(400, "INVALID_CLASSROOM_CODE");
  }
  return code;
}

function normalizeClassroomJoinRequest(raw) {
  return { code: normalizeClassroomCode(raw?.code) };
}

function generateClassCode(randomBytes) {
  const alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  const bytes = randomBytes || crypto.getRandomValues(new Uint8Array(8));
  if (!(bytes instanceof Uint8Array) || bytes.length < 8) {
    throw new Error("Eight random bytes are required.");
  }
  return Array.from(bytes.slice(0, 8), (byte) => alphabet[byte % alphabet.length]).join("");
}

async function createClassroom(env, user, name) {
  const teacherUid = user.sub;
  const context = await classroomUserContext(env, user);
  requireActiveRole(context.profile, "teacher", "TEACHER_ACCOUNT_REQUIRED");
  const classId = `CLS-${crypto.randomUUID().replace(/-/g, "").slice(0, 20).toUpperCase()}`;
  const now = new Date().toISOString();

  for (let attempt = 0; attempt < 5; attempt += 1) {
    const joinCode = generateClassCode();
    try {
      await commitClassroomCreation({
        ...context,
        classId,
        name,
        joinCode,
        teacherUid,
        displayName: firestoreString(context.profile.fields?.displayName) || "老師",
        now,
      });
      return classroomSummary({
        classId,
        name,
        role: "teacher",
        status: "active",
        joinedAt: now,
        visibilityStartsAt: now,
        leftAt: "",
        joinCode,
      });
    } catch (error) {
      if (error?.code !== "FIRESTORE_CONFLICT" || attempt === 4) throw error;
    }
  }
  throw httpError(503, "CLASSROOM_CODE_UNAVAILABLE");
}

async function joinClassroom(env, user, joinCode) {
  const studentUid = user.sub;
  const context = await classroomUserContext(env, user);
  requireActiveRole(context.profile, "student", "STUDENT_ACCOUNT_REQUIRED");
  await assertClassJoinRateLimit(context, studentUid);
  const mapping = await getFirestoreDocument(
    context.projectId,
    context.accessToken,
    `classJoinCodes/${joinCode}`,
    context.firestoreBaseURL
  );
  if (!mapping) throw httpError(404, "CLASSROOM_CODE_NOT_FOUND");
  const classId = firestoreString(mapping.fields?.classId);
  if (!/^[A-Z0-9-]{3,64}$/.test(classId)) {
    throw httpError(404, "CLASSROOM_CODE_NOT_FOUND");
  }
  const classroom = await getFirestoreDocument(
    context.projectId,
    context.accessToken,
    `classes/${classId}`,
    context.firestoreBaseURL
  );
  if (!classroom || classroom.fields?.active?.booleanValue !== true) {
    throw httpError(410, "CLASSROOM_UNAVAILABLE");
  }

  const now = new Date().toISOString();
  const className = firestoreString(classroom.fields?.name) || "English+ 班級";
  const displayName = firestoreString(context.profile.fields?.displayName) || "學生";
  const memberPath = `classes/${classId}/members/${studentUid}`;
  const existingMembership = await getFirestoreDocument(
    context.projectId,
    context.accessToken,
    memberPath,
    context.firestoreBaseURL
  );
  const firstJoinedAt = existingMembership?.fields?.joinedAt?.timestampValue || now;
  // Rejoining the same class must not erase the historical reporting window.
  // The class-scoped records were already visible to this teacher before the
  // student left, while personal-scope records live on a separate path.
  const visibilityStartsAt = existingMembership
    ? existingMembership.fields?.visibilityStartsAt?.timestampValue || firstJoinedAt
    : now;
  const root = firestoreRoot(context.projectId);

  const writes = [
    {
      update: {
        name: `${root}/${memberPath}`,
        fields: membershipFields({
          uid: studentUid,
          classId,
          className,
          role: "student",
          displayName,
          joinedAt: firstJoinedAt,
          visibilityStartsAt,
          leftAt: null,
        }),
      },
    },
    {
      update: {
        name: `${root}/users/${studentUid}/classMemberships/${classId}`,
        fields: userMembershipFields({
          classId,
          className,
          role: "student",
          joinedAt: firstJoinedAt,
          visibilityStartsAt,
          leftAt: null,
        }),
      },
    },
    {
      update: {
        name: `${root}/classes/${classId}/students/${studentUid}`,
        fields: {
          uid: { stringValue: studentUid },
          displayName: { stringValue: displayName },
          gradeBand: { stringValue: "" },
          classCode: { stringValue: classId },
          currentLevel: { stringValue: "基礎" },
          recommendedTrack: { stringValue: "steady" },
          lastMissionStatus: { stringValue: "active" },
          riskLevel: { stringValue: "low" },
          membershipStatus: { stringValue: "active" },
          joinedAt: { timestampValue: firstJoinedAt },
          visibilityStartsAt: { timestampValue: visibilityStartsAt },
          leftAt: { nullValue: null },
          updatedAt: { timestampValue: now },
        },
      },
    },
    userActiveClassWrite(root, studentUid, classId, now, context),
  ];
  const legacyMigration = legacyMembershipMigrationWrite(context, root, now);
  if (legacyMigration && context.legacyClassId !== classId) {
    writes.splice(writes.length - 1, 0, legacyMigration);
  }
  await commitFirestoreWrites(context, writes);

  return classroomSummary({
    classId,
    name: className,
    role: "student",
    status: "active",
    joinedAt: firstJoinedAt,
    visibilityStartsAt,
    leftAt: "",
    joinCode: "",
  });
}

async function leaveClassroom(env, user, classId) {
  const uid = user.sub;
  const context = await classroomUserContext(env, user);
  requireActiveRole(context.profile, "student", "STUDENT_ACCOUNT_REQUIRED");
  const memberPath = `classes/${classId}/members/${uid}`;
  const membership = await getFirestoreDocument(
    context.projectId,
    context.accessToken,
    memberPath,
    context.firestoreBaseURL
  );
  if (!membership || !membershipIsActiveDocument(membership) || firestoreString(membership.fields?.role) !== "student") {
    throw httpError(409, "CLASSROOM_MEMBERSHIP_INACTIVE");
  }
  const now = new Date().toISOString();
  const activeClassId = firestoreString(context.profile.fields?.activeClassId);
  const root = firestoreRoot(context.projectId);
  const statusFields = {
    status: { stringValue: "left" },
    active: { booleanValue: false },
    leftAt: { timestampValue: now },
    updatedAt: { timestampValue: now },
  };

  await commitFirestoreWrites(context, [
    maskedUpdateWrite(`${root}/${memberPath}`, statusFields, Object.keys(statusFields), membership.updateTime),
    maskedUpdateWrite(
      `${root}/users/${uid}/classMemberships/${classId}`,
      statusFields,
      Object.keys(statusFields)
    ),
    maskedUpdateWrite(
      `${root}/classes/${classId}/students/${uid}`,
      {
        membershipStatus: { stringValue: "left" },
        leftAt: { timestampValue: now },
        updatedAt: { timestampValue: now },
      },
      ["membershipStatus", "leftAt", "updatedAt"]
    ),
    userActiveClassWrite(
      root,
      uid,
      activeClassId === classId ? null : activeClassId || null,
      now,
      context
    ),
  ]);
}

async function resetClassroomCode(env, user, classId) {
  const teacherUid = user.sub;
  const context = await classroomUserContext(env, user);
  requireActiveRole(context.profile, "teacher", "TEACHER_ACCOUNT_REQUIRED");
  const [classroom, membership, admin] = await Promise.all([
    getFirestoreDocument(
      context.projectId,
      context.accessToken,
      `classes/${classId}`,
      context.firestoreBaseURL
    ),
    getFirestoreDocument(
      context.projectId,
      context.accessToken,
      `classes/${classId}/members/${teacherUid}`,
      context.firestoreBaseURL
    ),
    getFirestoreDocument(
      context.projectId,
      context.accessToken,
      `classAdmins/${classId}`,
      context.firestoreBaseURL
    ),
  ]);
  if (!classroom || !membership) throw httpError(404, "CLASSROOM_NOT_FOUND");
  const existingOwnerUid = firestoreString(classroom.fields?.ownerTeacherUid);
  if (
    (existingOwnerUid && existingOwnerUid !== teacherUid) ||
    firestoreString(membership.fields?.role) !== "teacher" ||
    !membershipIsActiveDocument(membership)
  ) {
    throw httpError(403, "CLASSROOM_OWNER_REQUIRED");
  }

  const oldCode = firestoreString(admin?.fields?.joinCode);
  const newCode = await unusedClassroomCode(context);
  const now = new Date().toISOString();
  const version = admin
    ? Number(admin.fields?.codeVersion?.integerValue || 1) + 1
    : 1;
  const root = firestoreRoot(context.projectId);
  const writes = [];
  if (oldCode) writes.push({ delete: `${root}/classJoinCodes/${oldCode}` });
  writes.push(
    {
      update: {
        name: `${root}/classJoinCodes/${newCode}`,
        fields: {
          classId: { stringValue: classId },
          active: { booleanValue: true },
          codeVersion: { integerValue: String(version) },
          createdAt: { timestampValue: now },
        },
      },
      currentDocument: { exists: false },
    },
    admin
      ? maskedUpdateWrite(
          `${root}/classAdmins/${classId}`,
          {
            joinCode: { stringValue: newCode },
            codeVersion: { integerValue: String(version) },
            updatedAt: { timestampValue: now },
          },
          ["joinCode", "codeVersion", "updatedAt"],
          admin.updateTime
        )
      : {
          update: {
            name: `${root}/classAdmins/${classId}`,
            fields: {
              classId: { stringValue: classId },
              ownerTeacherUid: { stringValue: teacherUid },
              joinCode: { stringValue: newCode },
              codeVersion: { integerValue: "1" },
              createdAt: { timestampValue: now },
              updatedAt: { timestampValue: now },
            },
          },
          currentDocument: { exists: false },
        },
    maskedUpdateWrite(
      `${root}/classes/${classId}`,
      {
        ownerTeacherUid: { stringValue: existingOwnerUid || teacherUid },
        updatedAt: { timestampValue: now },
      },
      ["ownerTeacherUid", "updatedAt"],
      classroom.updateTime
    )
  );
  await commitFirestoreWrites(context, writes);

  return classroomSummary({
    classId,
    name: firestoreString(classroom.fields?.name) || "English+ 班級",
    role: "teacher",
    status: "active",
    joinedAt: membership.fields?.joinedAt?.timestampValue || now,
    visibilityStartsAt: membership.fields?.visibilityStartsAt?.timestampValue || now,
    leftAt: "",
    joinCode: newCode,
  });
}

async function listClassroomsForUser(env, user) {
  const uid = user.sub;
  const context = await classroomUserContext(env, user);
  const memberships = await listFirestoreCollection(
    context.projectId,
    context.accessToken,
    `users/${uid}/classMemberships`,
    context.firestoreBaseURL
  );
  const activeMemberships = memberships.filter(membershipIsActiveDocument);
  const activeClassId = firestoreString(context.profile.fields?.activeClassId);
  if (
    activeClassId &&
    !activeMemberships.some((item) => {
      const itemClassId = membershipClassId(item);
      return itemClassId === activeClassId;
    })
  ) {
    const legacyMembership = await getFirestoreDocument(
      context.projectId,
      context.accessToken,
      `classes/${activeClassId}/members/${uid}`,
      context.firestoreBaseURL
    );
    if (legacyMembership && membershipIsActiveDocument(legacyMembership)) {
      activeMemberships.push(legacyMembership);
    }
  }
  const summaries = await Promise.all(activeMemberships.map(async (membership) => {
    const classId = membershipClassId(membership);
    const role = firestoreString(membership.fields?.role);
    const classroom = await getFirestoreDocument(
      context.projectId,
      context.accessToken,
      `classes/${classId}`,
      context.firestoreBaseURL
    );
    if (!classroom || classroom.fields?.active?.booleanValue !== true) return null;
    const admin = role === "teacher"
      ? await getFirestoreDocument(
          context.projectId,
          context.accessToken,
          `classAdmins/${classId}`,
          context.firestoreBaseURL
        )
      : null;
    return classroomSummary({
      classId,
      name: firestoreString(classroom.fields?.name) || firestoreString(membership.fields?.className) || "English+ 班級",
      role,
      status: "active",
      joinedAt: membership.fields?.joinedAt?.timestampValue || "",
      visibilityStartsAt: membership.fields?.visibilityStartsAt?.timestampValue || "",
      leftAt: "",
      joinCode: role === "teacher" ? firestoreString(admin?.fields?.joinCode) : "",
    });
  }));
  return summaries.filter(Boolean).sort((left, right) => left.name.localeCompare(right.name, "zh-Hant"));
}

async function classroomUserContext(env, user) {
  const uid = user.sub;
  const projectId = env.FIREBASE_PROJECT_ID || "englishplus-testflight";
  const firestoreBaseURL = firestoreEmulatorBaseURL(env);
  // The Firestore emulator recognizes the reserved owner token as an Admin
  // request. This branch is reachable only for an explicitly local host.
  const accessToken = firestoreBaseURL ? "owner" : await serviceAccountAccessToken(env);
  let profile = await getFirestoreDocument(
    projectId,
    accessToken,
    `users/${uid}`,
    firestoreBaseURL
  );
  if (profile) {
    return {
      env,
      projectId,
      accessToken,
      firestoreBaseURL,
      profile,
      profileExists: true,
      firebaseUser: user,
      legacyMembership: null,
      legacyClassId: "",
    };
  }

  const legacyClassId = "YILAN-CHENGZHI-8A";
  const legacyMembership = await getFirestoreDocument(
    projectId,
    accessToken,
    `classes/${legacyClassId}/members/${uid}`,
    firestoreBaseURL
  );
  if (!legacyMembership || !membershipIsActiveDocument(legacyMembership)) {
    throw httpError(404, "ACCOUNT_PROFILE_NOT_FOUND");
  }
  const role = firestoreString(legacyMembership.fields?.role);
  if (!new Set(["student", "teacher", "volunteer"]).has(role)) {
    throw httpError(403, "ACCOUNT_ROLE_INVALID");
  }
  const displayName = firestoreString(legacyMembership.fields?.displayName)
    || safeString(user.name)
    || safeString(user.email)
    || "English+";
  profile = {
    fields: {
      displayName: { stringValue: displayName },
      preferredName: { stringValue: displayName },
      primaryRole: { stringValue: role },
      accountStatus: { stringValue: "active" },
      active: { booleanValue: true },
      activeClassId: { stringValue: legacyClassId },
    },
  };
  return {
    env,
    projectId,
    accessToken,
    firestoreBaseURL,
    profile,
    profileExists: false,
    firebaseUser: user,
    legacyMembership,
    legacyClassId,
  };
}

async function ensureLegacyClassroomAccount(env, user) {
  const context = await classroomUserContext(env, user);
  const now = new Date().toISOString();
  const root = firestoreRoot(context.projectId);
  if (context.profileExists) {
    const legacyClassId = "YILAN-CHENGZHI-8A";
    const userMembership = await getFirestoreDocument(
      context.projectId,
      context.accessToken,
      `users/${user.sub}/classMemberships/${legacyClassId}`,
      context.firestoreBaseURL
    );
    if (userMembership && membershipIsActiveDocument(userMembership)) return false;

    const legacyMembership = await getFirestoreDocument(
      context.projectId,
      context.accessToken,
      `classes/${legacyClassId}/members/${user.sub}`,
      context.firestoreBaseURL
    );
    if (!legacyMembership || !membershipIsActiveDocument(legacyMembership)) return false;

    const migrationContext = {
      ...context,
      legacyMembership,
      legacyClassId,
    };
    const migration = legacyMembershipMigrationWrite(migrationContext, root, now);
    if (!migration) throw httpError(409, "LEGACY_MEMBERSHIP_MISSING");
    await commitFirestoreWrites(context, [migration]);
    return true;
  }

  const migration = legacyMembershipMigrationWrite(context, root, now);
  if (!migration) throw httpError(409, "LEGACY_MEMBERSHIP_MISSING");
  await commitFirestoreWrites(context, [
    migration,
    userActiveClassWrite(root, user.sub, context.legacyClassId, now, context),
  ]);
  return true;
}

function requireActiveRole(profile, role, errorCode) {
  const fields = profile.fields || {};
  if (
    firestoreString(fields.primaryRole) !== role ||
    firestoreString(fields.accountStatus) !== "active" ||
    fields.active?.booleanValue !== true
  ) {
    throw httpError(403, errorCode);
  }
}

async function commitClassroomCreation(input) {
  const root = firestoreRoot(input.projectId);
  const writes = [
    {
      update: {
        name: `${root}/classes/${input.classId}`,
        fields: {
          classId: { stringValue: input.classId },
          name: { stringValue: input.name },
          ownerTeacherUid: { stringValue: input.teacherUid },
          active: { booleanValue: true },
          createdAt: { timestampValue: input.now },
          updatedAt: { timestampValue: input.now },
        },
      },
      currentDocument: { exists: false },
    },
    {
      update: {
        name: `${root}/classAdmins/${input.classId}`,
        fields: {
          classId: { stringValue: input.classId },
          ownerTeacherUid: { stringValue: input.teacherUid },
          joinCode: { stringValue: input.joinCode },
          codeVersion: { integerValue: "1" },
          createdAt: { timestampValue: input.now },
          updatedAt: { timestampValue: input.now },
        },
      },
      currentDocument: { exists: false },
    },
    {
      update: {
        name: `${root}/classJoinCodes/${input.joinCode}`,
        fields: {
          classId: { stringValue: input.classId },
          active: { booleanValue: true },
          codeVersion: { integerValue: "1" },
          createdAt: { timestampValue: input.now },
        },
      },
      currentDocument: { exists: false },
    },
    {
      update: {
        name: `${root}/classes/${input.classId}/members/${input.teacherUid}`,
        fields: membershipFields({
          uid: input.teacherUid,
          classId: input.classId,
          className: input.name,
          role: "teacher",
          displayName: input.displayName,
          joinedAt: input.now,
          visibilityStartsAt: input.now,
          leftAt: null,
        }),
      },
      currentDocument: { exists: false },
    },
    {
      update: {
        name: `${root}/users/${input.teacherUid}/classMemberships/${input.classId}`,
        fields: userMembershipFields({
          classId: input.classId,
          className: input.name,
          role: "teacher",
          joinedAt: input.now,
          visibilityStartsAt: input.now,
          leftAt: null,
        }),
      },
      currentDocument: { exists: false },
    },
    userActiveClassWrite(root, input.teacherUid, input.classId, input.now, input),
  ];
  const legacyMigration = legacyMembershipMigrationWrite(input, root, input.now);
  if (legacyMigration && input.legacyClassId !== input.classId) {
    writes.splice(writes.length - 1, 0, legacyMigration);
  }
  await commitFirestoreWrites(input, writes);
}

function membershipFields(input) {
  return {
    uid: { stringValue: input.uid },
    classId: { stringValue: input.classId },
    className: { stringValue: input.className },
    role: { stringValue: input.role },
    displayName: { stringValue: input.displayName },
    status: { stringValue: input.leftAt ? "left" : "active" },
    active: { booleanValue: !input.leftAt },
    joinedAt: { timestampValue: input.joinedAt },
    visibilityStartsAt: { timestampValue: input.visibilityStartsAt },
    leftAt: input.leftAt ? { timestampValue: input.leftAt } : { nullValue: null },
    updatedAt: { timestampValue: new Date().toISOString() },
  };
}

function userMembershipFields(input) {
  return {
    classId: { stringValue: input.classId },
    className: { stringValue: input.className },
    role: { stringValue: input.role },
    groupId: { nullValue: null },
    status: { stringValue: input.leftAt ? "left" : "active" },
    active: { booleanValue: !input.leftAt },
    joinedAt: { timestampValue: input.joinedAt },
    visibilityStartsAt: { timestampValue: input.visibilityStartsAt },
    leftAt: input.leftAt ? { timestampValue: input.leftAt } : { nullValue: null },
    updatedAt: { timestampValue: new Date().toISOString() },
  };
}

function userActiveClassWrite(root, uid, classId, now, context) {
  if (context?.profileExists === false) {
    const displayName = firestoreString(context.profile?.fields?.displayName) || "English+";
    const role = firestoreString(context.profile?.fields?.primaryRole) || "student";
    return {
      update: {
        name: `${root}/users/${uid}`,
        fields: {
          displayName: { stringValue: displayName },
          preferredName: { stringValue: displayName },
          primaryRole: { stringValue: role },
          createdAt: { timestampValue: now },
          lastLoginAt: { timestampValue: now },
          updatedAt: { timestampValue: now },
          active: { booleanValue: true },
          activeClassId: classId ? { stringValue: classId } : { nullValue: null },
          accountStatus: { stringValue: "active" },
          emailVerificationRequired: { booleanValue: false },
          provisioningSource: { stringValue: "legacyMigration" },
          identityProviders: {
            arrayValue: { values: [{ stringValue: "emailPassword" }] },
          },
        },
      },
      currentDocument: { exists: false },
    };
  }
  return maskedUpdateWrite(
    `${root}/users/${uid}`,
    {
      activeClassId: classId ? { stringValue: classId } : { nullValue: null },
      updatedAt: { timestampValue: now },
    },
    ["activeClassId", "updatedAt"]
  );
}

function legacyMembershipMigrationWrite(context, root, now) {
  const membership = context?.legacyMembership;
  const classId = context?.legacyClassId;
  if (!membership || !classId) return null;
  const fields = membership.fields || {};
  const role = firestoreString(fields.role);
  const joinedAt = fields.joinedAt?.timestampValue || now;
  return {
    update: {
      name: `${root}/users/${context.firebaseUser.sub}/classMemberships/${classId}`,
      fields: userMembershipFields({
        classId,
        className: firestoreString(fields.className) || "English+ 班級",
        role,
        joinedAt,
        visibilityStartsAt: fields.visibilityStartsAt?.timestampValue || joinedAt,
        leftAt: null,
      }),
    },
  };
}

function maskedUpdateWrite(name, fields, fieldPaths, updateTime) {
  return {
    update: { name, fields },
    updateMask: { fieldPaths },
    currentDocument: updateTime ? { updateTime } : { exists: true },
  };
}

async function unusedClassroomCode(context) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const code = generateClassCode();
    const existing = await getFirestoreDocument(
      context.projectId,
      context.accessToken,
      `classJoinCodes/${code}`,
      context.firestoreBaseURL
    );
    if (!existing) return code;
  }
  throw httpError(503, "CLASSROOM_CODE_UNAVAILABLE");
}

async function commitFirestoreWrites(context, writes) {
  const endpoint = context.firestoreBaseURL
    ? `${context.firestoreBaseURL}/v1/projects/${context.projectId}/databases/(default)/documents:commit`
    : `https://firestore.googleapis.com/v1/projects/${context.projectId}/databases/(default)/documents:commit`;
  const headers = { "Content-Type": "application/json" };
  if (context.accessToken) headers.Authorization = `Bearer ${context.accessToken}`;
  const response = await fetch(
    endpoint,
    {
      method: "POST",
      headers,
      body: JSON.stringify({ writes }),
    }
  );
  if (response.ok) return response.json();
  if (response.status === 409) throw httpError(409, "FIRESTORE_CONFLICT");
  console.error(JSON.stringify({ event: "firestore_classroom_commit_failed", status: response.status }));
  throw httpError(502, "FIRESTORE_COMMIT_FAILED");
}

async function assertClassJoinRateLimit(context, uid) {
  const path = `classJoinAttempts/${uid}`;
  const existing = await getFirestoreDocument(
    context.projectId,
    context.accessToken,
    path,
    context.firestoreBaseURL
  );
  const now = new Date();
  const nowSeconds = Math.floor(now.getTime() / 1000);
  const startedAt = existing?.fields?.windowStartedAt?.timestampValue;
  const startedSeconds = startedAt ? Math.floor(Date.parse(startedAt) / 1000) : 0;
  const sameWindow = Number.isFinite(startedSeconds)
    && nowSeconds - startedSeconds < CLASS_JOIN_WINDOW_SECONDS;
  const currentCount = sameWindow
    ? Number(existing?.fields?.attemptCount?.integerValue || 0)
    : 0;
  if (currentCount >= CLASS_JOIN_MAX_ATTEMPTS) {
    throw httpError(429, "CLASSROOM_JOIN_RATE_LIMIT");
  }
  const root = firestoreRoot(context.projectId);
  const fields = {
    uid: { stringValue: uid },
    windowStartedAt: {
      timestampValue: sameWindow && startedAt ? startedAt : now.toISOString(),
    },
    attemptCount: { integerValue: String(currentCount + 1) },
    updatedAt: { timestampValue: now.toISOString() },
  };
  await commitFirestoreWrites(context, [
    existing
      ? maskedUpdateWrite(
          `${root}/${path}`,
          fields,
          Object.keys(fields),
          existing.updateTime
        )
      : {
          update: { name: `${root}/${path}`, fields },
          currentDocument: { exists: false },
        },
  ]);
}

async function getFirestoreDocument(projectId, accessToken, path, firestoreBaseURL) {
  const headers = accessToken ? { Authorization: `Bearer ${accessToken}` } : {};
  const response = await fetch(firestoreDocumentUrl(projectId, path, firestoreBaseURL), { headers });
  if (response.status === 404) return null;
  if (!response.ok) throw httpError(502, "FIRESTORE_LOOKUP_FAILED");
  return response.json();
}

async function listFirestoreCollection(projectId, accessToken, path, firestoreBaseURL) {
  const documents = [];
  let pageToken = "";
  do {
    const endpoint = new URL(firestoreDocumentUrl(projectId, path, firestoreBaseURL));
    endpoint.searchParams.set("pageSize", "100");
    if (pageToken) endpoint.searchParams.set("pageToken", pageToken);
    const headers = accessToken ? { Authorization: `Bearer ${accessToken}` } : {};
    const response = await fetch(endpoint, { headers });
    if (!response.ok) throw httpError(502, "FIRESTORE_LIST_FAILED");
    const payload = await response.json();
    documents.push(...(payload.documents || []));
    pageToken = safeString(payload.nextPageToken) || "";
  } while (pageToken);
  return documents;
}

function firestoreDocumentUrl(projectId, path, firestoreBaseURL) {
  const encodedPath = path.split("/").map(encodeURIComponent).join("/");
  if (firestoreBaseURL) {
    return `${firestoreBaseURL}/v1/projects/${projectId}/databases/(default)/documents/${encodedPath}`;
  }
  return `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/${encodedPath}`;
}

function firestoreEmulatorBaseURL(env) {
  const host = safeString(env?.FIRESTORE_EMULATOR_HOST);
  if (!host) return null;
  if (!/^(127\.0\.0\.1|localhost):[0-9]{2,5}$/.test(host)) {
    throw httpError(500, "INVALID_FIRESTORE_EMULATOR_HOST");
  }
  return `http://${host}`;
}

function firestoreRoot(projectId) {
  return `projects/${projectId}/databases/(default)/documents`;
}

function documentId(name) {
  return safeString(name)?.split("/").pop() || "";
}

function membershipClassId(document) {
  const explicit = firestoreString(document?.fields?.classId);
  if (explicit) return explicit;
  const parts = safeString(document?.name)?.split("/") || [];
  const membersIndex = parts.lastIndexOf("members");
  if (membersIndex > 0) return parts[membersIndex - 1];
  return parts.at(-1) || "";
}

function membershipIsActiveDocument(document) {
  const fields = document?.fields || {};
  const status = firestoreString(fields.status);
  return (status === "active" || (!status && fields.active?.booleanValue === true))
    && fields.active?.booleanValue !== false
    && !fields.leftAt?.timestampValue;
}

function classroomSummary(input) {
  return {
    id: input.classId,
    classId: input.classId,
    name: input.name,
    role: input.role,
    status: input.status,
    joinedAt: input.joinedAt,
    visibilityStartsAt: input.visibilityStartsAt,
    leftAt: input.leftAt || null,
    joinCode: input.joinCode || null,
  };
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
  const application = await getVolunteerApplicationDocument(
    projectId,
    accessToken,
    review.uid
  );
  const currentStatus = firestoreString(application.fields?.status);
  if (!reviewTransitionAllowed(currentStatus, review.action)) {
    throw httpError(409, "REVIEW_STATE_CONFLICT");
  }
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
            currentDocument: application.updateTime
              ? { updateTime: application.updateTime }
              : { exists: true },
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

async function getVolunteerApplicationDocument(projectId, accessToken, uid) {
  const response = await fetch(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/volunteerApplications/${encodeURIComponent(uid)}`,
    { headers: { Authorization: `Bearer ${accessToken}` } }
  );
  if (response.status === 404) {
    throw httpError(404, "VOLUNTEER_APPLICATION_NOT_FOUND");
  }
  if (!response.ok) {
    throw httpError(502, "VOLUNTEER_APPLICATION_LOOKUP_FAILED");
  }
  return response.json();
}

function reviewTransitionAllowed(currentStatus, action) {
  if (["approved", "rejected", "needsMoreInformation"].includes(action)) {
    return currentStatus === "pendingReview";
  }
  if (action === "suspended") {
    return currentStatus === "approved";
  }
  return false;
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
  createClassroom,
  enforceEvidenceQuota,
  ensureLegacyClassroomAccount,
  generateClassCode,
  joinClassroom,
  leaveClassroom,
  listClassroomsForUser,
  membershipIsActiveDocument,
  normalizeEvidenceTicketRequest,
  normalizeClassroomCode,
  normalizeClassroomCreateRequest,
  normalizeClassroomJoinRequest,
  normalizeRequest,
  reviewTransitionAllowed,
  resetClassroomCode,
  selectExpiredReviewedApplications,
  signUploadTicket,
  verifyUploadTicket,
};
