import { DurableObject } from "cloudflare:workers";

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
const TAIPEI_TIMEZONE_OFFSET_MS = 8 * 60 * 60 * 1000;
const ACCOUNT_DELETION_CONFIRMATION = "DELETE";
const ACCOUNT_DELETION_POLICY_VERSION = "2026-07-13";
const ACCOUNT_DELETION_RECENT_AUTH_SECONDS = 10 * 60;
const ACCOUNT_DELETION_JOB_LIMIT = 20;
const ACCOUNT_DELETION_LEGACY_THREAD_BATCH = 20;
const ACCOUNT_DELETION_OWNED_CLASS_BATCH = 1;
const ACCOUNT_DELETION_CLASS_STUDENT_BATCH = 1;
const SUPPORT_MESSAGE_CONTEXT_VERSION = 2;
const FIRESTORE_COMMIT_WRITE_LIMIT = 350;
const USER_OWNED_COLLECTIONS = Object.freeze([
  "classMemberships",
  "settings",
  "personalCheckIns",
  "personalDailyMissions",
  "personalAnswerEvents",
  "personalLearningEvents",
  "consents",
]);
const CLASS_STUDENT_COLLECTIONS = Object.freeze([
  "checkIns",
  "consents",
  "deletionRequests",
  "dailyMissions",
  "answerEvents",
  "learningEvents",
]);
const FINAL_REVIEW_STATUSES = new Set(["approved", "rejected", "suspended"]);
const VOLUNTEER_REVIEW_STATUSES = new Set([
  "draft",
  "pendingReview",
  "needsMoreInformation",
  "approved",
  "rejected",
  "suspended",
]);
const VOLUNTEER_REVIEW_ACTIONS = Object.freeze({
  approved: { applicationStatus: "approved", accountStatus: "active", active: true },
  rejected: { applicationStatus: "rejected", accountStatus: "disabled", active: false },
  needsMoreInformation: {
    applicationStatus: "needsMoreInformation",
    accountStatus: "pendingApplication",
    active: false,
  },
  suspended: { applicationStatus: "suspended", accountStatus: "suspended", active: false },
});
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

const AI_TASK_ROLES = Object.freeze({
  student: new Set([
    "dailyMission",
    "wrongAnswerExplanation",
    "emotionalSupport",
    "progressSummary",
  ]),
  teacher: new Set(["teacherFeedbackDraft"]),
  volunteer: new Set(["volunteerReplyCoach"]),
});
const AI_STAFF_SUPPORT_TASKS = new Set([
  "teacherFeedbackDraft",
  "volunteerReplyCoach",
]);
const AI_QUALITY_TASKS = new Set([
  "teacherFeedbackDraft",
  "volunteerReplyCoach",
]);
const AI_TASK_UNIT_COSTS = Object.freeze({
  dailyMission: 4,
  wrongAnswerExplanation: 2,
  emotionalSupport: 2,
  teacherFeedbackDraft: 3,
  volunteerReplyCoach: 3,
  progressSummary: 3,
});
const AI_QUOTA_POLICIES = Object.freeze({
  internal: Object.freeze({ dailyUnitLimit: 180, burstLimit: 30, burstPeriodSeconds: 60 }),
  public: Object.freeze({ dailyUnitLimit: 60, burstLimit: 8, burstPeriodSeconds: 60 }),
});

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET,POST,PATCH,PUT,DELETE,OPTIONS",
  "Access-Control-Allow-Headers": "Authorization,Content-Type,X-EnglishPlus-Request-ID",
  "Access-Control-Expose-Headers":
    "X-EnglishPlus-Request-ID,X-EnglishPlus-Quota-Remaining,X-EnglishPlus-Quota-Reset,Retry-After",
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

    if (url.pathname === "/ai/quota" && request.method === "GET") {
      return handleAiQuotaStatus(request, env);
    }

    if (url.pathname === "/account/deletion-preview" && request.method === "GET") {
      return handleAccountDeletionPreview(request, env);
    }

    if (url.pathname === "/account" && request.method === "DELETE") {
      return handleAccountDeletion(request, env);
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

    if (url.pathname === "/admin/session" && request.method === "GET") {
      return handleAdminSession(request, env);
    }

    if (url.pathname === "/admin/volunteer-applications" && request.method === "GET") {
      return handleVolunteerApplicationList(request, env, url);
    }

    if (url.pathname === "/admin/volunteer-audit" && request.method === "GET") {
      return handleVolunteerAudit(request, env, url);
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

    if (url.pathname === "/volunteer-services" && request.method === "GET") {
      return handleVolunteerServiceList(request, env);
    }

    if (url.pathname === "/volunteer-services/request" && request.method === "POST") {
      return handleVolunteerServiceRequest(request, env);
    }

    const volunteerServiceLeave = url.pathname.match(
      /^\/volunteer-services\/([A-Z0-9-]{3,64})\/leave$/
    );
    if (volunteerServiceLeave && request.method === "POST") {
      return handleVolunteerServiceLeave(request, env, volunteerServiceLeave[1]);
    }

    const classroomStudents = url.pathname.match(
      /^\/classrooms\/([A-Z0-9-]{3,64})\/students$/
    );
    if (classroomStudents && request.method === "GET") {
      return handleClassroomStudentList(request, env, classroomStudents[1]);
    }

    const classroomVolunteerList = url.pathname.match(
      /^\/classrooms\/([A-Z0-9-]{3,64})\/volunteers$/
    );
    if (classroomVolunteerList && request.method === "GET") {
      return handleClassroomVolunteerList(request, env, classroomVolunteerList[1]);
    }

    const classroomVolunteerCode = url.pathname.match(
      /^\/classrooms\/([A-Z0-9-]{3,64})\/volunteer-code(?:\/(reset))?$/
    );
    if (classroomVolunteerCode && request.method === "GET" && !classroomVolunteerCode[2]) {
      return handleVolunteerInviteCodeGet(request, env, classroomVolunteerCode[1]);
    }
    if (classroomVolunteerCode && request.method === "POST" && classroomVolunteerCode[2] === "reset") {
      return handleVolunteerInviteCodeReset(request, env, classroomVolunteerCode[1]);
    }

    const classroomVolunteerAction = url.pathname.match(
      /^\/classrooms\/([A-Z0-9-]{3,64})\/volunteers\/([^/]{1,160})\/(approve|reject|remove)$/
    );
    if (classroomVolunteerAction && request.method === "POST") {
      return handleClassroomVolunteerAction(
        request,
        env,
        classroomVolunteerAction[1],
        decodeURIComponent(classroomVolunteerAction[2]),
        classroomVolunteerAction[3]
      );
    }

    const classroomSettings = url.pathname.match(
      /^\/classrooms\/([A-Z0-9-]{3,64})$/
    );
    if (classroomSettings && request.method === "PATCH") {
      return handleClassroomUpdate(request, env, classroomSettings[1]);
    }
    if (classroomSettings && request.method === "DELETE") {
      return handleClassroomDelete(request, env, classroomSettings[1]);
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
      Promise.all([
        cleanupExpiredReviewedEvidence(env),
        retryPendingAccountDeletions(env),
      ])
        .then(([evidence, accountDeletion]) => {
          console.log(JSON.stringify({
            event: "scheduled_privacy_cleanup",
            evidence,
            accountDeletion,
          }));
        })
        .catch((error) => {
          console.error(JSON.stringify({
            event: "scheduled_privacy_cleanup_failed",
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
    quotaMode: aiQuotaMode(env),
    aiGatewayReady: Boolean(
      env.AI_QUOTA
      && env.AI_INTERNAL_BURST_LIMITER
      && env.AI_PUBLIC_BURST_LIMITER
    ),
  });
}

async function handleAi(request, env) {
  const startedAt = Date.now();
  const requestId = requestIdentifier(request);
  let user;
  let actor;
  let normalized;
  let quota;

  try {
    user = await requireFirebaseUser(request, env);
  } catch (error) {
    return authOrValidationError(error, requestId);
  }

  try {
    const body = await request.json();
    normalized = normalizeRequest(body?.data ?? body);
    actor = await authorizeAiRequest(env, user, normalized);
    normalized = actor.request;
  } catch (error) {
    await logAiRequest({
      requestId,
      user,
      taskType: normalized?.taskType,
      outcome: "rejected",
      errorCode: safeString(error?.code) || "INVALID_AI_REQUEST",
      latencyMs: Date.now() - startedAt,
    });
    return authOrValidationError(error, requestId);
  }

  try {
    await enforceAiBurstLimit(env, user.sub);
    quota = await reserveAiQuota(env, user.sub, normalized, requestId);
  } catch (error) {
    const status = Number(error?.status) || 503;
    const errorCode = safeString(error?.code) || "AI_QUOTA_UNAVAILABLE";
    await logAiRequest({
      requestId,
      user,
      role: actor.role,
      taskType: normalized.taskType,
      quotaMode: aiQuotaMode(env),
      outcome: status === 429 ? "rate_limited" : "quota_error",
      errorCode,
      latencyMs: Date.now() - startedAt,
    });
    return jsonResponse(
      {
        ok: false,
        error: errorCode,
        requestId,
        retryAfterSeconds: Number(error?.retryAfterSeconds) || undefined,
      },
      status,
      {
        "X-EnglishPlus-Request-ID": requestId,
        ...(status === 429
          ? { "Retry-After": String(Number(error?.retryAfterSeconds) || 60) }
          : {}),
      }
    );
  }

  if (!env.GROQ_API_KEY) {
    const result = buildFallbackResponse(normalized, "GROQ_API_KEY_NOT_CONFIGURED");
    result.requestId = requestId;
    await logAiRequest({
      requestId,
      user,
      role: actor.role,
      taskType: normalized.taskType,
      quota,
      quotaMode: aiQuotaMode(env),
      outcome: "fallback",
      errorCode: result.errorCode,
      latencyMs: Date.now() - startedAt,
    });
    return jsonResponse({ result }, 200, aiResponseHeaders(requestId, quota));
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
      signal: AbortSignal.timeout(12_000),
    });

    const groqJson = await groqResponse.json().catch(() => ({}));
    if (!groqResponse.ok) {
      const result = buildFallbackResponse(normalized, `GROQ_HTTP_${groqResponse.status}`);
      result.requestId = requestId;
      await logAiRequest({
        requestId,
        user,
        role: actor.role,
        taskType: normalized.taskType,
        quota,
        quotaMode: aiQuotaMode(env),
        outcome: "fallback",
        providerStatus: groqResponse.status,
        errorCode: result.errorCode,
        latencyMs: Date.now() - startedAt,
      });
      return jsonResponse({ result }, 200, aiResponseHeaders(requestId, quota));
    }

    const result = normalizeGroqResponse(normalized, groqJson);
    const providerRequestId = result.requestId;
    result.requestId = requestId;
    await logAiRequest({
      requestId,
      providerRequestId,
      user,
      role: actor.role,
      taskType: normalized.taskType,
      quota,
      quotaMode: aiQuotaMode(env),
      outcome: "success",
      model: result.modelUsed,
      usage: result.usage,
      latencyMs: Date.now() - startedAt,
    });
    return jsonResponse({ result }, 200, aiResponseHeaders(requestId, quota));
  } catch (error) {
    const errorCode = error?.name === "TimeoutError" ? "GROQ_TIMEOUT" : "GROQ_UNAVAILABLE";
    const result = buildFallbackResponse(normalized, errorCode);
    result.requestId = requestId;
    await logAiRequest({
      requestId,
      user,
      role: actor.role,
      taskType: normalized.taskType,
      quota,
      quotaMode: aiQuotaMode(env),
      outcome: "fallback",
      errorCode,
      latencyMs: Date.now() - startedAt,
    });
    return jsonResponse({ result }, 200, aiResponseHeaders(requestId, quota));
  }
}

async function handleAiQuotaStatus(request, env) {
  const requestId = requestIdentifier(request);
  try {
    const user = await requireFirebaseUser(request, env);
    const context = await classroomUserContext(env, user);
    const role = activeProfileRole(context.profile);
    const quota = await readAiQuota(env, user.sub);
    return jsonResponse(
      { ok: true, role, ...quota, requestId },
      200,
      aiResponseHeaders(requestId, quota)
    );
  } catch (error) {
    return authOrValidationError(error, requestId);
  }
}

async function handleAccountDeletionPreview(request, env) {
  const requestId = requestIdentifier(request);
  try {
    const user = await requireFirebaseUser(request, env);
    const context = await accountDeletionContext(env, user.sub, user.firebaseIdToken);
    const summary = await discoverAccountDeletionSummary(context);
    return jsonResponse(
      { ok: true, preview: accountDeletionPreview(summary), requestId },
      200,
      { "X-EnglishPlus-Request-ID": requestId }
    );
  } catch (error) {
    console.error(JSON.stringify({
      event: "account_deletion_preview_failed",
      requestId,
      errorName: safeString(error?.name) || "Error",
      errorCode: safeString(error?.code) || "unclassified",
      errorMessage: (safeString(error?.message) || "unknown").slice(0, 400),
    }));
    return authOrValidationError(error, requestId);
  }
}

async function handleAccountDeletion(request, env) {
  const requestId = requestIdentifier(request);
  try {
    const user = await requireFirebaseUser(request, env);
    const body = await request.json();
    normalizeAccountDeletionRequest(body);
    const context = await accountDeletionContext(env, user.sub, user.firebaseIdToken);
    const existingPhase = firestoreString(context.job?.fields?.phase);

    if (!existingPhase) {
      requireRecentAuthentication(user);
      const summary = await discoverAccountDeletionSummary(context);
      await stageAccountDeletionSummary(context, summary, false);
      return accountDeletionPendingResponse(requestId, accountDeletionJobProgress(context.job));
    }

    if (existingPhase === "legacySupportMessages") {
      const progress = await processLegacySupportMessageBatch(context);
      return accountDeletionPendingResponse(requestId, progress);
    }

    if (existingPhase === "ownedClasses") {
      const progress = await processOwnedClassBatch(context);
      return accountDeletionPendingResponse(requestId, progress);
    }

    if (existingPhase === "classStudentData") {
      const progress = await processClassStudentDataBatch(context);
      return accountDeletionPendingResponse(requestId, progress);
    }

    if (existingPhase === "ready") {
      const lateData = await discoverAccountDeletionSummary(context);
      if (accountDeletionPhase(lateData) !== "ready") {
        await stageAccountDeletionSummary(context, lateData, true);
        return accountDeletionPendingResponse(requestId, accountDeletionJobProgress(context.job));
      }
    }

    const result = await executeAccountDeletion(env, user.sub, context);
    return jsonResponse(
      { ok: true, result, requestId },
      200,
      { "X-EnglishPlus-Request-ID": requestId }
    );
  } catch (error) {
    return authOrValidationError(error, requestId);
  }
}

function accountDeletionPendingResponse(requestId, progress) {
  const completed = Math.max(0, progress.total - progress.remaining);
  return jsonResponse(
    {
      ok: true,
      result: {
        completed: false,
        phase: progress.phase,
        processedItems: completed,
        remainingItems: progress.remaining,
        totalItems: progress.total,
      },
      requestId,
    },
    202,
    {
      "Retry-After": "1",
      "X-EnglishPlus-Request-ID": requestId,
    }
  );
}

function accountDeletionPhase(summary) {
  if (summary.legacyThreadPaths.length > 0) return "legacySupportMessages";
  if (summary.ownedClassPaths.length > 0) return "ownedClasses";
  if (summary.classStudentPaths.length > 0) return "classStudentData";
  return "ready";
}

async function stageAccountDeletionSummary(context, summary, appendToExisting) {
  const existingLegacyTotal = appendToExisting
    ? firestoreInteger(context.job?.fields?.legacyThreadTotal)
    : 0;
  const existingOwnedClassTotal = appendToExisting
    ? firestoreInteger(context.job?.fields?.ownedClassTotal)
    : 0;
  const existingClassStudentTotal = appendToExisting
    ? firestoreInteger(context.job?.fields?.classStudentTotal)
    : 0;
  await writeAccountDeletionJob(context, {
    phase: accountDeletionPhase(summary),
    metricRecorded: context.job?.fields?.metricRecorded?.booleanValue === true,
    legacyThreadPaths: summary.legacyThreadPaths,
    legacyThreadTotal: existingLegacyTotal + summary.legacyThreadPaths.length,
    ownedClassPaths: summary.ownedClassPaths,
    ownedClassTotal: existingOwnedClassTotal + summary.ownedClassPaths.length,
    classStudentPaths: summary.classStudentPaths,
    classStudentTotal: existingClassStudentTotal + summary.classStudentPaths.length,
  });
}

function accountDeletionJobProgress(job) {
  const phase = firestoreString(job?.fields?.phase) || "ready";
  const progressFields = {
    legacySupportMessages: ["legacyThreadPaths", "legacyThreadTotal"],
    ownedClasses: ["ownedClassPaths", "ownedClassTotal"],
    classStudentData: ["classStudentPaths", "classStudentTotal"],
  };
  const [pathField, totalField] = progressFields[phase] || [];
  if (!pathField) return { phase, remaining: 0, total: 0 };
  const remaining = firestoreStringArray(job?.fields?.[pathField]).length;
  return {
    phase,
    remaining,
    total: Math.max(firestoreInteger(job?.fields?.[totalField]), remaining),
  };
}

function normalizeAccountDeletionRequest(raw) {
  const confirmation = safeString(raw?.confirmation);
  const policyVersion = safeString(raw?.policyVersion);
  if (confirmation !== ACCOUNT_DELETION_CONFIRMATION) {
    throw httpError(400, "ACCOUNT_DELETION_CONFIRMATION_REQUIRED");
  }
  if (policyVersion !== ACCOUNT_DELETION_POLICY_VERSION) {
    throw httpError(409, "ACCOUNT_DELETION_POLICY_CHANGED");
  }
  return { confirmation, policyVersion };
}

function requireRecentAuthentication(user, nowSeconds = Math.floor(Date.now() / 1000)) {
  const authTime = Number(user?.auth_time);
  if (
    !Number.isFinite(authTime)
    || authTime > nowSeconds + 30
    || nowSeconds - authTime > ACCOUNT_DELETION_RECENT_AUTH_SECONDS
  ) {
    throw httpError(409, "ACCOUNT_RECENT_SIGN_IN_REQUIRED");
  }
}

async function accountDeletionContext(env, uid, firebaseIdToken = null) {
  const projectId = env.FIREBASE_PROJECT_ID || "englishplus-testflight";
  const firestoreBaseURL = firestoreEmulatorBaseURL(env);
  const accessToken = firestoreBaseURL ? "owner" : await serviceAccountAccessToken(env);
  const [profile, job] = await Promise.all([
    getFirestoreDocument(
      projectId,
      accessToken,
      `users/${uid}`,
      firestoreBaseURL
    ),
    getFirestoreDocument(
      projectId,
      accessToken,
      `accountDeletionJobs/${uid}`,
      firestoreBaseURL
    ),
  ]);
  if (!profile && !job) {
    throw httpError(404, "ACCOUNT_PROFILE_NOT_FOUND");
  }
  const role = firestoreString(profile?.fields?.primaryRole)
    || firestoreString(job?.fields?.role);
  if (!new Set(["student", "teacher", "volunteer"]).has(role)) {
    throw httpError(409, "ACCOUNT_ROLE_INVALID");
  }
  return {
    env,
    uid,
    role,
    projectId,
    accessToken,
    firestoreBaseURL,
    firebaseIdToken,
    profile,
    job,
  };
}

async function discoverAccountDeletionSummary(context) {
  const [memberDocuments, studentDocuments, ownedClasses, studentThreads] = await Promise.all([
    runFirestoreEqualQuery(context, "members", "uid", context.uid),
    runFirestoreEqualQuery(context, "students", "uid", context.uid),
    listFirestoreCollection(
      context.projectId,
      context.accessToken,
      "classes",
      context.firestoreBaseURL
    ).then((documents) => documents.filter(
      (document) => firestoreString(document.fields?.ownerTeacherUid) === context.uid
    )),
    runFirestoreEqualQuery(context, "supportThreads", "studentUid", context.uid),
  ]);
  const legacyThreadPaths = studentThreads
    .filter((thread) => firestoreInteger(thread.fields?.messageContextVersion) < SUPPORT_MESSAGE_CONTEXT_VERSION)
    .map((thread) => relativeFirestorePath(thread.name))
    .sort();
  return {
    role: context.role,
    membershipCount: memberDocuments.length,
    ownedClassCount: ownedClasses.length,
    legacyThreadPaths,
    ownedClassPaths: ownedClasses
      .map((classroom) => relativeFirestorePath(classroom.name))
      .sort(),
    classStudentPaths: studentDocuments
      .map((student) => relativeFirestorePath(student.name))
      .sort(),
  };
}

async function discoverAccountDeletionPlan(context) {
  const deletePaths = new Set([
    `users/${context.uid}`,
    `teacherProfiles/${context.uid}`,
    `volunteerApplications/${context.uid}`,
    `classJoinAttempts/${context.uid}`,
  ]);
  const updates = new Map();

  for (const collectionId of USER_OWNED_COLLECTIONS) {
    const documents = await listFirestoreCollection(
      context.projectId,
      context.accessToken,
      `users/${context.uid}/${collectionId}`,
      context.firestoreBaseURL
    );
    documents.forEach((document) => deletePaths.add(relativeFirestorePath(document.name)));
  }

  const [memberDocuments, studentDocuments, ownedClasses] = await Promise.all([
    runFirestoreEqualQuery(context, "members", "uid", context.uid),
    runFirestoreEqualQuery(context, "students", "uid", context.uid),
    listFirestoreCollection(
      context.projectId,
      context.accessToken,
      "classes",
      context.firestoreBaseURL
    ).then((documents) => documents.filter(
      (document) => firestoreString(document.fields?.ownerTeacherUid) === context.uid
    )),
  ]);

  memberDocuments.forEach((document) => deletePaths.add(relativeFirestorePath(document.name)));

  for (const studentDocument of studentDocuments) {
    const studentPath = relativeFirestorePath(studentDocument.name);
    for (const collectionId of CLASS_STUDENT_COLLECTIONS) {
      const documents = await listFirestoreCollection(
        context.projectId,
        context.accessToken,
        `${studentPath}/${collectionId}`,
        context.firestoreBaseURL
      );
      documents.forEach((document) => deletePaths.add(relativeFirestorePath(document.name)));
    }
    deletePaths.add(studentPath);
  }

  const studentThreads = await runFirestoreEqualQuery(
    context,
    "supportThreads",
    "studentUid",
    context.uid
  );
  studentThreads.forEach((thread) => deletePaths.add(relativeFirestorePath(thread.name)));

  const deleteQueryPairs = [
    ["messages", "studentUid"],
    ["practiceAssignments", "studentUid"],
    ["staffAssignments", "studentUid"],
    ["staffAssignments", "assignedToUid"],
    ["aiUsage", "uid"],
    ["aiEvents", "uid"],
    ["privacyAuditLogs", "uid"],
    ["privacyAuditLogs", "studentUid"],
    ["privacyAuditLogs", "actorUid"],
    ["syncQueue", "uid"],
    ["syncQueue", "studentUid"],
    ["reports", "uid"],
    ["reports", "studentUid"],
  ];
  const deleteQueryResults = await Promise.all(
    deleteQueryPairs.map(([collectionId, fieldPath]) =>
      runFirestoreEqualQuery(context, collectionId, fieldPath, context.uid)
    )
  );
  deleteQueryResults.flat().forEach((document) => {
    deletePaths.add(relativeFirestorePath(document.name));
  });

  const [authoredMessages, authoredAssignments, handledThreads] = await Promise.all([
    runFirestoreEqualQuery(context, "messages", "authorUid", context.uid),
    runFirestoreEqualQuery(context, "practiceAssignments", "assignedByUid", context.uid),
    runFirestoreEqualQuery(context, "supportThreads", "handledByUid", context.uid),
  ]);
  authoredMessages.forEach((document) => addAccountDeletionUpdate(
    updates,
    relativeFirestorePath(document.name),
    {
      authorUid: { stringValue: "deleted-account" },
      authorName: { stringValue: "已刪除帳號" },
      body: { stringValue: "此回覆已因帳號刪除移除。" },
      messageType: { stringValue: "systemStatus" },
    }
  ));
  authoredAssignments.forEach((document) => addAccountDeletionUpdate(
    updates,
    relativeFirestorePath(document.name),
    {
      assignedByUid: { stringValue: "deleted-account" },
      assignedByName: { stringValue: "已刪除的老師" },
    }
  ));
  handledThreads.forEach((document) => addAccountDeletionUpdate(
    updates,
    relativeFirestorePath(document.name),
    {
      handledByUid: { nullValue: null },
      handledByName: { stringValue: "已刪除帳號" },
    }
  ));

  for (const classroom of ownedClasses) {
    await appendOwnedClassArchivePlan(context, classroom, deletePaths, updates);
  }

  for (const path of deletePaths) {
    updates.delete(path);
  }

  return {
    uid: context.uid,
    role: context.role,
    deletePaths: [...deletePaths].sort(compareFirestoreDeletionPaths),
    updates: [...updates.values()],
    membershipCount: memberDocuments.length,
    ownedClassCount: Math.max(
      ownedClasses.length,
      firestoreInteger(context.job?.fields?.ownedClassTotal)
    ),
    hadVolunteerEvidence: Boolean(context.env.VOLUNTEER_EVIDENCE),
  };
}

async function appendOwnedClassArchivePlan(
  context,
  classroom,
  deletePaths,
  updates
) {
  const classId = documentId(classroom.name);
  if (!classId) return;
  const now = new Date().toISOString();
  addAccountDeletionUpdate(updates, `classes/${classId}`, {
    ownerTeacherUid: { stringValue: "deleted-account" },
    active: { booleanValue: false },
    archivedReason: { stringValue: "ownerAccountDeleted" },
    archivedAt: { timestampValue: now },
    updatedAt: { timestampValue: now },
  });

  const [
    admin,
    members,
    assignments,
    supportThreads,
    volunteerRequests,
    activeClassProfiles,
  ] = await Promise.all([
    getFirestoreDocument(
      context.projectId,
      context.accessToken,
      `classAdmins/${classId}`,
      context.firestoreBaseURL
    ),
    listFirestoreCollection(
      context.projectId,
      context.accessToken,
      `classes/${classId}/members`,
      context.firestoreBaseURL
    ),
    listFirestoreCollection(
      context.projectId,
      context.accessToken,
      `classes/${classId}/practiceAssignments`,
      context.firestoreBaseURL
    ),
    listFirestoreCollection(
      context.projectId,
      context.accessToken,
      `classes/${classId}/supportThreads`,
      context.firestoreBaseURL
    ),
    listFirestoreCollection(
      context.projectId,
      context.accessToken,
      `classes/${classId}/volunteerRequests`,
      context.firestoreBaseURL
    ),
    runFirestoreEqualQuery(context, "users", "activeClassId", classId),
  ]);
  const joinCode = firestoreString(admin?.fields?.joinCode);
  const volunteerJoinCode = firestoreString(admin?.fields?.volunteerJoinCode);
  deletePaths.add(`classAdmins/${classId}`);
  if (joinCode) deletePaths.add(`classJoinCodes/${joinCode}`);
  if (volunteerJoinCode) deletePaths.add(`volunteerJoinCodes/${volunteerJoinCode}`);

  for (const member of members) {
    const memberUid = firestoreString(member.fields?.uid) || documentId(member.name);
    if (!memberUid || memberUid === context.uid) continue;
    addAccountDeletionUpdate(updates, relativeFirestorePath(member.name), {
      status: { stringValue: "left" },
      active: { booleanValue: false },
      leftAt: { timestampValue: now },
      updatedAt: { timestampValue: now },
    });
    deletePaths.add(`users/${memberUid}/classMemberships/${classId}`);
  }
  activeClassProfiles.forEach((profile) => addAccountDeletionUpdate(
    updates,
    relativeFirestorePath(profile.name),
    {
      activeClassId: { nullValue: null },
      updatedAt: { timestampValue: now },
    }
  ));

  assignments
    .filter((assignment) => new Set(["pending", "active"]).has(
      firestoreString(assignment.fields?.status)
    ))
    .forEach((assignment) => addAccountDeletionUpdate(
      updates,
      relativeFirestorePath(assignment.name),
      {
        status: { stringValue: "withdrawn" },
        updatedAt: { timestampValue: now },
      }
    ));
  supportThreads
    .filter((thread) => new Set(["open", "waitingForStaff"]).has(
      firestoreString(thread.fields?.status)
    ))
    .forEach((thread) => addAccountDeletionUpdate(
      updates,
      relativeFirestorePath(thread.name),
      {
        status: { stringValue: "closed" },
        updatedAt: { timestampValue: now },
      }
    ));
  volunteerRequests.forEach((request) => {
    const volunteerUid = firestoreString(request.fields?.volunteerUid) || documentId(request.name);
    if (!volunteerUid) return;
    const fields = {
      status: { stringValue: "removed" },
      decidedAt: { timestampValue: now },
      decisionReason: { stringValue: "ownerAccountDeleted" },
      updatedAt: { timestampValue: now },
    };
    addAccountDeletionUpdate(updates, relativeFirestorePath(request.name), fields);
    addAccountDeletionUpdate(
      updates,
      `users/${volunteerUid}/volunteerServices/${classId}`,
      fields
    );
  });
}

function addAccountDeletionUpdate(updates, path, fields) {
  const existing = updates.get(path);
  updates.set(path, {
    path,
    fields: { ...(existing?.fields || {}), ...fields },
  });
}

function compareFirestoreDeletionPaths(left, right) {
  const depthDifference = right.split("/").length - left.split("/").length;
  return depthDifference || left.localeCompare(right);
}

function accountDeletionPreview(plan) {
  return {
    role: plan.role,
    classMembershipCount: plan.membershipCount,
    ownedClassCount: plan.ownedClassCount,
    archivesOwnedClasses: plan.ownedClassCount > 0,
    removesIdentifiableData: true,
    retainsAnonymousAggregateOnly: true,
    requiresRecentSignIn: true,
  };
}

async function processLegacySupportMessageBatch(context) {
  const storedPaths = firestoreStringArray(context.job?.fields?.legacyThreadPaths);
  const total = Math.max(
    firestoreInteger(context.job?.fields?.legacyThreadTotal),
    storedPaths.length
  );
  const batch = storedPaths.slice(0, ACCOUNT_DELETION_LEGACY_THREAD_BATCH);
  const remainingPaths = storedPaths.slice(batch.length);
  const messagePaths = [];

  for (const threadPath of batch) {
    const messages = await listFirestoreCollection(
      context.projectId,
      context.accessToken,
      `${threadPath}/messages`,
      context.firestoreBaseURL
    );
    messages.forEach((message) => messagePaths.push(relativeFirestorePath(message.name)));
  }
  await commitAccountDeletionDeletes(context, messagePaths);
  await commitAccountDeletionUpdates(
    context,
    batch.map((threadPath) => ({
      path: threadPath,
      fields: {
        messageContextVersion: { integerValue: String(SUPPORT_MESSAGE_CONTEXT_VERSION) },
      },
    })),
    []
  );
  const ownedClassPaths = firestoreStringArray(context.job?.fields?.ownedClassPaths);
  const classStudentPaths = firestoreStringArray(context.job?.fields?.classStudentPaths);
  await writeAccountDeletionJob(context, {
    phase: remainingPaths.length > 0
      ? "legacySupportMessages"
      : ownedClassPaths.length > 0
        ? "ownedClasses"
        : classStudentPaths.length > 0
          ? "classStudentData"
          : "ready",
    metricRecorded: false,
    legacyThreadPaths: remainingPaths,
    legacyThreadTotal: total,
  });
  return accountDeletionJobProgress(context.job);
}

async function processOwnedClassBatch(context) {
  const storedPaths = firestoreStringArray(context.job?.fields?.ownedClassPaths);
  const batch = storedPaths.slice(0, ACCOUNT_DELETION_OWNED_CLASS_BATCH);
  const remainingPaths = storedPaths.slice(batch.length);
  const updates = new Map();
  const deletePaths = new Set();

  for (const classPath of batch) {
    const classroom = await getFirestoreDocument(
      context.projectId,
      context.accessToken,
      classPath,
      context.firestoreBaseURL
    );
    if (classroom) {
      await appendOwnedClassArchivePlan(context, classroom, deletePaths, updates);
    }
  }
  await commitAccountDeletionUpdates(context, [...updates.values()], [...deletePaths]);
  await commitAccountDeletionDeletes(context, [...deletePaths]);

  const classStudentPaths = firestoreStringArray(context.job?.fields?.classStudentPaths);
  await writeAccountDeletionJob(context, {
    phase: remainingPaths.length > 0
      ? "ownedClasses"
      : classStudentPaths.length > 0
        ? "classStudentData"
        : "ready",
    metricRecorded: false,
    ownedClassPaths: remainingPaths,
  });
  return accountDeletionJobProgress(context.job);
}

async function processClassStudentDataBatch(context) {
  const storedPaths = firestoreStringArray(context.job?.fields?.classStudentPaths);
  const batch = storedPaths.slice(0, ACCOUNT_DELETION_CLASS_STUDENT_BATCH);
  const remainingPaths = storedPaths.slice(batch.length);
  const deletePaths = [];

  for (const studentPath of batch) {
    for (const collectionId of CLASS_STUDENT_COLLECTIONS) {
      const documents = await listFirestoreCollection(
        context.projectId,
        context.accessToken,
        `${studentPath}/${collectionId}`,
        context.firestoreBaseURL
      );
      documents.forEach((document) => deletePaths.push(relativeFirestorePath(document.name)));
    }
    deletePaths.push(studentPath);
  }
  deletePaths.sort(compareFirestoreDeletionPaths);
  await commitAccountDeletionDeletes(context, deletePaths);
  await writeAccountDeletionJob(context, {
    phase: remainingPaths.length > 0 ? "classStudentData" : "ready",
    metricRecorded: false,
    classStudentPaths: remainingPaths,
  });
  return accountDeletionJobProgress(context.job);
}

async function executeAccountDeletion(env, uid, existingContext = null) {
  const context = existingContext || await accountDeletionContext(env, uid);
  const plan = await discoverAccountDeletionPlan(context);
  const existingMetricRecorded = context.job?.fields?.metricRecorded?.booleanValue === true;
  await writeAccountDeletionJob(context, {
    phase: "cleaning",
    metricRecorded: existingMetricRecorded,
  });

  await deleteVolunteerEvidenceForAccount(env, uid);
  await commitAccountDeletionUpdates(context, plan.updates, plan.deletePaths);
  await commitAccountDeletionDeletes(context, plan.deletePaths);

  if (!existingMetricRecorded) {
    await commitFirestoreWrites(context, [
      accountDeletionMetricWrite(context.projectId, plan),
      accountDeletionJobWrite(context, {
        phase: "authPending",
        metricRecorded: true,
      }),
    ]);
  } else {
    await writeAccountDeletionJob(context, {
      phase: "authPending",
      metricRecorded: true,
    });
  }

  await deleteFirebaseAuthAccount(context, uid);
  try {
    await commitFirestoreWrites(context, [
      { delete: `${firestoreRoot(context.projectId)}/accountDeletionJobs/${uid}` },
    ]);
  } catch (error) {
    console.error(JSON.stringify({
      event: "account_deletion_job_cleanup_pending",
      error: error instanceof Error ? error.message : "unknown",
    }));
  }

  console.log(JSON.stringify({
    event: "account_deleted",
    role: plan.role,
    deletedDocuments: plan.deletePaths.length,
    redactedDocuments: plan.updates.length,
    archivedOwnedClasses: plan.ownedClassCount,
  }));
  return {
    completed: true,
    deletedDocuments: plan.deletePaths.length,
    redactedDocuments: plan.updates.length,
    archivedOwnedClasses: plan.ownedClassCount,
    retainedData: "anonymousAggregateOnly",
  };
}

async function writeAccountDeletionJob(context, state) {
  await commitFirestoreWrites(context, [accountDeletionJobWrite(context, state)]);
  context.job = await getFirestoreDocument(
    context.projectId,
    context.accessToken,
    `accountDeletionJobs/${context.uid}`,
    context.firestoreBaseURL
  );
  if (!context.job) {
    throw httpError(502, "ACCOUNT_DELETION_JOB_WRITE_FAILED");
  }
}

function accountDeletionJobWrite(context, state) {
  const now = new Date().toISOString();
  const existing = context.job;
  const attempts = Number(existing?.fields?.attempts?.integerValue || 0) + 1;
  const fields = {
    uid: { stringValue: context.uid },
    role: { stringValue: context.role },
    phase: { stringValue: state.phase },
    policyVersion: { stringValue: ACCOUNT_DELETION_POLICY_VERSION },
    metricRecorded: { booleanValue: state.metricRecorded === true },
    attempts: { integerValue: String(attempts) },
    createdAt: existing?.fields?.createdAt || { timestampValue: now },
    updatedAt: { timestampValue: now },
  };
  const legacyThreadPaths = state.legacyThreadPaths
    ?? firestoreStringArray(existing?.fields?.legacyThreadPaths);
  const legacyThreadTotal = Number.isInteger(state.legacyThreadTotal)
    ? state.legacyThreadTotal
    : Math.max(
        firestoreInteger(existing?.fields?.legacyThreadTotal),
        legacyThreadPaths.length
      );
  fields.legacyThreadPaths = {
    arrayValue: {
      values: legacyThreadPaths.map((path) => ({ stringValue: path })),
    },
  };
  fields.legacyThreadTotal = { integerValue: String(legacyThreadTotal) };
  const ownedClassPaths = state.ownedClassPaths
    ?? firestoreStringArray(existing?.fields?.ownedClassPaths);
  const ownedClassTotal = Number.isInteger(state.ownedClassTotal)
    ? state.ownedClassTotal
    : Math.max(
        firestoreInteger(existing?.fields?.ownedClassTotal),
        ownedClassPaths.length
      );
  fields.ownedClassPaths = {
    arrayValue: {
      values: ownedClassPaths.map((path) => ({ stringValue: path })),
    },
  };
  fields.ownedClassTotal = { integerValue: String(ownedClassTotal) };
  const classStudentPaths = state.classStudentPaths
    ?? firestoreStringArray(existing?.fields?.classStudentPaths);
  const classStudentTotal = Number.isInteger(state.classStudentTotal)
    ? state.classStudentTotal
    : Math.max(
        firestoreInteger(existing?.fields?.classStudentTotal),
        classStudentPaths.length
      );
  fields.classStudentPaths = {
    arrayValue: {
      values: classStudentPaths.map((path) => ({ stringValue: path })),
    },
  };
  fields.classStudentTotal = { integerValue: String(classStudentTotal) };
  return {
    update: {
      name: `${firestoreRoot(context.projectId)}/accountDeletionJobs/${context.uid}`,
      fields,
    },
    currentDocument: existing?.updateTime
      ? { updateTime: existing.updateTime }
      : { exists: false },
  };
}

function accountDeletionMetricWrite(projectId, plan) {
  const month = new Date().toISOString().slice(0, 7);
  return {
    update: {
      name: `${firestoreRoot(projectId)}/anonymousProductMetrics/account-deletions-${month}`,
      fields: {
        metricKind: { stringValue: "accountDeletion" },
        month: { stringValue: month },
        updatedAt: { timestampValue: new Date().toISOString() },
      },
    },
    updateMask: { fieldPaths: ["metricKind", "month", "updatedAt"] },
    updateTransforms: [
      { fieldPath: "totalAccountsDeleted", increment: { integerValue: "1" } },
      { fieldPath: `role_${plan.role}`, increment: { integerValue: "1" } },
      ...(plan.membershipCount > 0
        ? [{ fieldPath: "accountsWithClasses", increment: { integerValue: "1" } }]
        : []),
    ],
  };
}

async function commitAccountDeletionUpdates(context, updates, deletePaths) {
  const deleting = new Set(deletePaths);
  const writes = updates
    .filter((update) => !deleting.has(update.path))
    .map((update) => maskedUpdateWrite(
      `${firestoreRoot(context.projectId)}/${update.path}`,
      update.fields,
      Object.keys(update.fields)
    ));
  await commitFirestoreWriteChunks(context, writes);
}

async function commitAccountDeletionDeletes(context, deletePaths) {
  const writes = deletePaths.map((path) => ({
    delete: `${firestoreRoot(context.projectId)}/${path}`,
  }));
  await commitFirestoreWriteChunks(context, writes);
}

async function commitFirestoreWriteChunks(context, writes) {
  for (let index = 0; index < writes.length; index += FIRESTORE_COMMIT_WRITE_LIMIT) {
    await commitFirestoreWrites(
      context,
      writes.slice(index, index + FIRESTORE_COMMIT_WRITE_LIMIT)
    );
  }
}

async function deleteVolunteerEvidenceForAccount(env, uid) {
  if (!env.VOLUNTEER_EVIDENCE) {
    throw httpError(503, "ACCOUNT_EVIDENCE_STORAGE_UNAVAILABLE");
  }
  const objects = await listEvidenceObjectsForUid(env, uid);
  await Promise.all(objects.map((object) => env.VOLUNTEER_EVIDENCE.delete(object.key)));
}

async function deleteFirebaseAuthAccount(context, uid) {
  if (context.firestoreBaseURL) return;
  if (context.firebaseIdToken) {
    const apiKey = safeString(context.env?.FIREBASE_WEB_API_KEY);
    const endpoint = apiKey
      ? `https://identitytoolkit.googleapis.com/v1/accounts:delete?key=${encodeURIComponent(apiKey)}`
      : "https://identitytoolkit.googleapis.com/v1/accounts:delete";
    const selfDeleteResponse = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ idToken: context.firebaseIdToken }),
    });
    if (selfDeleteResponse.ok) return;
    const selfDeletePayload = await selfDeleteResponse.json().catch(() => ({}));
    console.error(JSON.stringify({
      event: "account_self_auth_deletion_failed",
      status: selfDeleteResponse.status,
      providerCode: (
        safeString(selfDeletePayload?.error?.message) || "unknown"
      ).slice(0, 160),
    }));
  }

  const response = await fetch(
    `https://identitytoolkit.googleapis.com/v1/projects/${context.projectId}/accounts:batchDelete`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${context.accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        localIds: [uid],
        force: true,
      }),
    }
  );
  const payload = await response.json().catch(() => ({}));
  if (response.ok && !Array.isArray(payload?.errors)) return;
  if (response.ok && payload.errors.length === 0) return;
  const message = safeString(payload?.error?.message) || "";
  console.error(JSON.stringify({
    event: "account_auth_deletion_failed",
    status: response.status,
    providerCode: (
      safeString(message)
      || safeString(payload?.errors?.[0]?.message)
      || "unknown"
    ).slice(0, 160),
  }));
  throw httpError(502, "ACCOUNT_AUTH_DELETION_FAILED");
}

async function retryPendingAccountDeletions(env) {
  const projectId = env.FIREBASE_PROJECT_ID || "englishplus-testflight";
  const firestoreBaseURL = firestoreEmulatorBaseURL(env);
  const accessToken = firestoreBaseURL ? "owner" : await serviceAccountAccessToken(env);
  const jobs = await listFirestoreCollection(
    projectId,
    accessToken,
    "accountDeletionJobs",
    firestoreBaseURL
  );
  let completed = 0;
  let failed = 0;
  for (const job of jobs.slice(0, ACCOUNT_DELETION_JOB_LIMIT)) {
    const uid = firestoreString(job.fields?.uid) || documentId(job.name);
    if (!uid) continue;
    try {
      const context = await accountDeletionContext(env, uid);
      const phase = firestoreString(context.job?.fields?.phase);
      if (phase === "legacySupportMessages") {
        await processLegacySupportMessageBatch(context);
      } else if (phase === "ownedClasses") {
        await processOwnedClassBatch(context);
      } else if (phase === "classStudentData") {
        await processClassStudentDataBatch(context);
      } else {
        await executeAccountDeletion(env, uid, context);
        completed += 1;
      }
    } catch (error) {
      failed += 1;
      console.error(JSON.stringify({
        event: "account_deletion_retry_failed",
        phase: firestoreString(job.fields?.phase) || "unknown",
        error: error instanceof Error ? error.message : "unknown",
      }));
    }
  }
  return { scanned: Math.min(jobs.length, ACCOUNT_DELETION_JOB_LIMIT), completed, failed };
}

async function runFirestoreEqualQuery(context, collectionId, fieldPath, value) {
  const endpoint = context.firestoreBaseURL
    ? `${context.firestoreBaseURL}/v1/projects/${context.projectId}/databases/(default)/documents:runQuery`
    : `https://firestore.googleapis.com/v1/projects/${context.projectId}/databases/(default)/documents:runQuery`;
  const headers = { "Content-Type": "application/json" };
  if (context.accessToken) headers.Authorization = `Bearer ${context.accessToken}`;
  const response = await fetch(endpoint, {
    method: "POST",
    headers,
    body: JSON.stringify({
      structuredQuery: {
        from: [{ collectionId, allDescendants: true }],
        where: {
          fieldFilter: {
            field: { fieldPath },
            op: "EQUAL",
            value: { stringValue: value },
          },
        },
      },
    }),
  });
  const payload = await response.json();
  if (!response.ok) {
    const firestoreError = Array.isArray(payload) ? payload[0]?.error : payload?.error;
    console.error(JSON.stringify({
      event: "firestore_query_failed",
      collectionId,
      fieldPath,
      status: response.status,
      firestoreStatus: safeString(firestoreError?.status) || "unknown",
      firestoreMessage: (safeString(firestoreError?.message) || "unknown").slice(0, 400),
    }));
    throw httpError(502, "FIRESTORE_QUERY_FAILED");
  }
  return (Array.isArray(payload) ? payload : [])
    .map((item) => item.document)
    .filter(Boolean);
}

function relativeFirestorePath(name) {
  const marker = "/documents/";
  const index = String(name || "").indexOf(marker);
  if (index < 0) throw httpError(502, "FIRESTORE_DOCUMENT_NAME_INVALID");
  return String(name).slice(index + marker.length);
}

export class AIQuotaCoordinator extends DurableObject {
  async reserve(input) {
    const command = normalizeAiQuotaCommand(input);
    return this.ctx.storage.transaction(async (transaction) => {
      const stored = await transaction.get("daily-usage");
      const state = quotaStateForDate(stored, command.nowMs);
      const duplicate = state.recentRequestIds.includes(command.requestId);
      if (duplicate) {
        return quotaDecision(state, command.mode, true, true);
      }

      const policy = aiQuotaPolicy(command.mode);
      if (state.usedUnits + command.cost > policy.dailyUnitLimit) {
        return quotaDecision(state, command.mode, false, false);
      }

      const next = {
        ...state,
        usedUnits: state.usedUnits + command.cost,
        callCount: state.callCount + 1,
        taskCounts: {
          ...state.taskCounts,
          [command.taskType]: (state.taskCounts[command.taskType] || 0) + 1,
        },
        recentRequestIds: [...state.recentRequestIds, command.requestId].slice(-100),
        updatedAt: new Date(command.nowMs).toISOString(),
      };
      await transaction.put("daily-usage", next);
      return quotaDecision(next, command.mode, true, false);
    });
  }

  async status(input = {}) {
    const nowMs = normalizedNow(input.nowMs);
    const mode = normalizedAiQuotaMode(input.mode);
    const stored = await this.ctx.storage.get("daily-usage");
    return quotaDecision(quotaStateForDate(stored, nowMs), mode, true, false);
  }
}

function aiQuotaMode(env) {
  return normalizedAiQuotaMode(env?.AI_QUOTA_MODE);
}

function normalizedAiQuotaMode(value) {
  return value === "public" ? "public" : "internal";
}

function aiQuotaPolicy(mode) {
  return AI_QUOTA_POLICIES[normalizedAiQuotaMode(mode)];
}

function aiTaskCost(taskType, qualityMode = "free") {
  const baseCost = AI_TASK_UNIT_COSTS[taskType];
  if (!baseCost) throw httpError(400, "AI_TASK_NOT_SUPPORTED");
  return qualityMode === "quality" ? baseCost * 2 : baseCost;
}

function normalizeAiQuotaCommand(input) {
  const mode = normalizedAiQuotaMode(input?.mode);
  const taskType = safeString(input?.taskType);
  const requestId = safeString(input?.requestId);
  const cost = Number(input?.cost);
  if (!taskType || !TASKS.has(taskType) || !requestId) {
    throw httpError(400, "AI_QUOTA_COMMAND_INVALID");
  }
  if (!Number.isInteger(cost) || cost < 1 || cost > 20) {
    throw httpError(400, "AI_QUOTA_COST_INVALID");
  }
  return {
    mode,
    taskType,
    requestId,
    cost,
    nowMs: normalizedNow(input?.nowMs),
  };
}

function normalizedNow(value) {
  const number = Number(value);
  if (Number.isFinite(number) && number >= 0) return Math.floor(number);
  return Date.now();
}

function quotaStateForDate(stored, nowMs) {
  const dateKey = new Date(nowMs + TAIPEI_TIMEZONE_OFFSET_MS)
    .toISOString()
    .slice(0, 10);
  if (stored?.dateKey === dateKey) {
    return {
      dateKey,
      usedUnits: Math.max(0, Number(stored.usedUnits) || 0),
      callCount: Math.max(0, Number(stored.callCount) || 0),
      taskCounts: stored.taskCounts && typeof stored.taskCounts === "object"
        ? stored.taskCounts
        : {},
      recentRequestIds: Array.isArray(stored.recentRequestIds)
        ? stored.recentRequestIds.filter((item) => typeof item === "string").slice(-100)
        : [],
      updatedAt: safeString(stored.updatedAt) || new Date(nowMs).toISOString(),
      nowMs,
    };
  }
  return {
    dateKey,
    usedUnits: 0,
    callCount: 0,
    taskCounts: {},
    recentRequestIds: [],
    updatedAt: new Date(nowMs).toISOString(),
    nowMs,
  };
}

function quotaDecision(state, mode, allowed, duplicate) {
  const policy = aiQuotaPolicy(mode);
  const nextTaipeiMidnightAsUTC =
    Date.parse(`${state.dateKey}T00:00:00.000Z`)
    + 24 * 60 * 60 * 1000
    - TAIPEI_TIMEZONE_OFFSET_MS;
  return {
    allowed,
    duplicate,
    mode: normalizedAiQuotaMode(mode),
    dateKey: state.dateKey,
    usedUnits: state.usedUnits,
    dailyUnitLimit: policy.dailyUnitLimit,
    remainingUnits: Math.max(0, policy.dailyUnitLimit - state.usedUnits),
    callCount: state.callCount,
    taskCounts: state.taskCounts,
    resetAt: new Date(nextTaipeiMidnightAsUTC).toISOString(),
  };
}

async function enforceAiBurstLimit(env, uid) {
  const mode = aiQuotaMode(env);
  const limiter = mode === "public"
    ? env.AI_PUBLIC_BURST_LIMITER
    : env.AI_INTERNAL_BURST_LIMITER;
  if (!limiter || typeof limiter.limit !== "function") {
    throw httpError(503, "AI_RATE_LIMITER_NOT_CONFIGURED");
  }
  const result = await limiter.limit({ key: `firebase:${uid}` });
  if (!result?.success) {
    const error = httpError(429, "AI_BURST_LIMIT_REACHED");
    error.retryAfterSeconds = aiQuotaPolicy(mode).burstPeriodSeconds;
    throw error;
  }
}

async function reserveAiQuota(env, uid, request, requestId) {
  if (!env.AI_QUOTA || typeof env.AI_QUOTA.getByName !== "function") {
    throw httpError(503, "AI_QUOTA_NOT_CONFIGURED");
  }
  const mode = aiQuotaMode(env);
  const stub = env.AI_QUOTA.getByName(`firebase:${uid}`);
  const quota = await stub.reserve({
    mode,
    taskType: request.taskType,
    requestId,
    cost: aiTaskCost(request.taskType, request.qualityMode),
    nowMs: Date.now(),
  });
  if (quota?.duplicate) {
    throw httpError(409, "AI_REQUEST_ID_REUSED");
  }
  if (!quota?.allowed) {
    const error = httpError(429, "AI_DAILY_LIMIT_REACHED");
    error.retryAfterSeconds = Math.max(
      60,
      Math.ceil((Date.parse(quota.resetAt) - Date.now()) / 1000)
    );
    throw error;
  }
  return quota;
}

async function readAiQuota(env, uid) {
  if (!env.AI_QUOTA || typeof env.AI_QUOTA.getByName !== "function") {
    throw httpError(503, "AI_QUOTA_NOT_CONFIGURED");
  }
  return env.AI_QUOTA.getByName(`firebase:${uid}`).status({
    mode: aiQuotaMode(env),
    nowMs: Date.now(),
  });
}

async function authorizeAiRequest(env, user, request) {
  const context = await classroomUserContext(env, user);
  const role = activeProfileRole(context.profile);
  assertAiTaskRole(role, request.taskType);

  const normalized = {
    ...request,
    qualityMode: AI_QUALITY_TASKS.has(request.taskType) ? "quality" : "free",
  };
  const isPersonal = request.classId.startsWith("PERSONAL-");

  if (isPersonal) {
    if (role !== "student" || request.classId !== personalScopeIdForUid(user.sub)) {
      throw httpError(403, "AI_PERSONAL_SCOPE_FORBIDDEN");
    }
  } else {
    const membership = await getAiMembership(context, request.classId, user.sub);
    if (
      !membershipIsActiveDocument(membership)
      || firestoreString(membership.fields?.role) !== role
    ) {
      throw httpError(403, "AI_CLASS_MEMBERSHIP_REQUIRED");
    }
  }

  if (role === "student") {
    if (request.studentUid && request.studentUid !== user.sub) {
      throw httpError(403, "AI_STUDENT_IDENTITY_MISMATCH");
    }
    normalized.studentUid = user.sub;
  } else {
    if (!request.studentUid || isPersonal) {
      throw httpError(403, "AI_STUDENT_SCOPE_REQUIRED");
    }
    const studentMembership = await getAiMembership(context, request.classId, request.studentUid);
    if (
      !membershipIsActiveDocument(studentMembership)
      || firestoreString(studentMembership.fields?.role) !== "student"
    ) {
      throw httpError(403, "AI_TARGET_STUDENT_NOT_ACTIVE");
    }
  }

  if (AI_STAFF_SUPPORT_TASKS.has(request.taskType)) {
    await requireAiSupportThread(context, normalized);
  }

  return { role, request: normalized };
}

function activeProfileRole(profile) {
  const fields = profile?.fields || {};
  const role = firestoreString(fields.primaryRole);
  if (
    !AI_TASK_ROLES[role]
    || firestoreString(fields.accountStatus) !== "active"
    || fields.active?.booleanValue !== true
  ) {
    throw httpError(403, "AI_ACCOUNT_NOT_ACTIVE");
  }
  return role;
}

function assertAiTaskRole(role, taskType) {
  if (!AI_TASK_ROLES[role]?.has(taskType)) {
    throw httpError(403, "AI_TASK_ROLE_FORBIDDEN");
  }
}

async function getAiMembership(context, classId, uid) {
  const classroom = await getFirestoreDocument(
    context.projectId,
    context.accessToken,
    `classes/${classId}`,
    context.firestoreBaseURL
  );
  if (!classroomIsOperationalDocument(classroom)) {
    throw httpError(410, "CLASSROOM_UNAVAILABLE");
  }
  if (
    context.legacyClassId === classId
    && context.firebaseUser.sub === uid
    && context.legacyMembership
  ) {
    return context.legacyMembership;
  }
  return getFirestoreDocument(
    context.projectId,
    context.accessToken,
    `classes/${classId}/members/${uid}`,
    context.firestoreBaseURL
  );
}

async function requireAiSupportThread(context, request) {
  const supportThreadId = safeString(request.context?.supportThreadId);
  if (!supportThreadId || !/^[A-Za-z0-9._:-]{3,160}$/.test(supportThreadId)) {
    throw httpError(400, "AI_SUPPORT_THREAD_REQUIRED");
  }
  const thread = await getFirestoreDocument(
    context.projectId,
    context.accessToken,
    `classes/${request.classId}/supportThreads/${supportThreadId}`,
    context.firestoreBaseURL
  );
  const fields = thread?.fields || {};
  const status = firestoreString(fields.status);
  if (
    !thread
    || firestoreString(fields.classId) !== request.classId
    || firestoreString(fields.studentUid) !== request.studentUid
    || fields.studentVisible?.booleanValue === false
    || fields.withdrawnAt?.timestampValue
    || status === "archived"
    || status === "closed"
  ) {
    throw httpError(403, "AI_SUPPORT_THREAD_FORBIDDEN");
  }
}

function personalScopeIdForUid(uid) {
  const compact = String(uid || "")
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 48);
  return `PERSONAL-${compact}`;
}

function requestIdentifier(request) {
  const supplied = request.headers.get("X-EnglishPlus-Request-ID") || "";
  return /^[A-Za-z0-9._:-]{8,100}$/.test(supplied)
    ? supplied
    : crypto.randomUUID();
}

function aiResponseHeaders(requestId, quota) {
  return {
    "X-EnglishPlus-Request-ID": requestId,
    ...(quota
      ? {
          "X-EnglishPlus-Quota-Remaining": String(quota.remainingUnits),
          "X-EnglishPlus-Quota-Reset": quota.resetAt,
        }
      : {}),
  };
}

async function logAiRequest(event) {
  let actorHash = "anonymous";
  if (event.user?.sub) {
    const digest = await crypto.subtle.digest(
      "SHA-256",
      new TextEncoder().encode(event.user.sub)
    );
    actorHash = Array.from(new Uint8Array(digest).slice(0, 8))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");
  }
  console.log({
    event: "ai_request",
    requestId: event.requestId,
    providerRequestId: event.providerRequestId,
    actorHash,
    role: event.role,
    taskType: event.taskType,
    quotaMode: event.quotaMode,
    quotaUsedUnits: event.quota?.usedUnits,
    quotaRemainingUnits: event.quota?.remainingUnits,
    outcome: event.outcome,
    model: event.model,
    promptTokens: event.usage?.promptTokens,
    completionTokens: event.usage?.completionTokens,
    totalTokens: event.usage?.totalTokens,
    providerStatus: event.providerStatus,
    errorCode: event.errorCode,
    latencyMs: event.latencyMs,
  });
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
  const requestId = requestIdentifier(request);
  let admin;
  let body;
  try {
    admin = await requireAdministrator(request, env);
    body = normalizeAdminReviewRequest(await request.json());
  } catch (error) {
    return authOrValidationError(error, requestId);
  }

  const uid = decodeURIComponent(url.pathname.split("/").pop() || "").trim();
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(uid)) {
    return authOrValidationError(httpError(400, "INVALID_UID"), requestId);
  }
  if (uid === admin.sub) {
    return authOrValidationError(httpError(409, "SELF_REVIEW_NOT_ALLOWED"), requestId);
  }
  const decision = VOLUNTEER_REVIEW_ACTIONS[body.action];

  try {
    const result = await commitVolunteerReview(env, {
      uid,
      action: body.action,
      reviewerUid: admin.sub,
      reviewerEmail: safeString(admin.email)?.slice(0, 320) || "",
      note: body.note,
      expectedVersion: body.expectedVersion,
      requestId,
      ...decision,
    });
    console.log(JSON.stringify({
      event: "volunteer_review_completed",
      requestId,
      reviewerUid: admin.sub,
      applicantUid: uid,
      action: body.action,
      fromStatus: result.previousStatus,
      toStatus: decision.applicationStatus,
    }));
    return jsonResponse(
      {
        ok: true,
        uid,
        status: decision.applicationStatus,
        previousStatus: result.previousStatus,
        version: result.version,
        auditId: result.auditId,
        requestId,
      },
      200,
      { "X-EnglishPlus-Request-ID": requestId }
    );
  } catch (error) {
    console.error(JSON.stringify({
      event: "volunteer_review_failed",
      requestId,
      reviewerUid: admin.sub,
      applicantUid: uid,
      action: body.action,
      errorCode: safeString(error?.code) || "REVIEW_COMMIT_FAILED",
    }));
    if (error?.status) return authOrValidationError(error, requestId);
    return authOrValidationError(httpError(502, "REVIEW_COMMIT_FAILED"), requestId);
  }
}

async function handleAdminSession(request, env) {
  const requestId = requestIdentifier(request);
  try {
    const admin = await requireAdministrator(request, env);
    return jsonResponse(
      {
        ok: true,
        admin: {
          uid: admin.sub,
          email: safeString(admin.email) || "",
          displayName: safeString(admin.name) || safeString(admin.email) || "English+ 管理員",
        },
        requestId,
      },
      200,
      { "X-EnglishPlus-Request-ID": requestId }
    );
  } catch (error) {
    return authOrValidationError(error, requestId);
  }
}

async function handleVolunteerApplicationList(request, env, url) {
  const requestId = requestIdentifier(request);
  try {
    await requireAdministrator(request, env);
    const query = normalizeAdminApplicationQuery(url.searchParams);
    const result = await listVolunteerApplications(env, query);
    return jsonResponse(
      { ok: true, ...result, requestId },
      200,
      { "X-EnglishPlus-Request-ID": requestId }
    );
  } catch (error) {
    if (error?.status) return authOrValidationError(error, requestId);
    return authOrValidationError(httpError(502, "APPLICATION_LIST_FAILED"), requestId);
  }
}

async function handleVolunteerAudit(request, env, url) {
  const requestId = requestIdentifier(request);
  try {
    await requireAdministrator(request, env);
    const uid = safeString(url.searchParams.get("uid"));
    if (!uid || !/^[A-Za-z0-9_-]{8,128}$/.test(uid)) {
      throw httpError(400, "INVALID_UID");
    }
    const events = await listVolunteerReviewEvents(env, uid);
    return jsonResponse(
      { ok: true, uid, events, requestId },
      200,
      { "X-EnglishPlus-Request-ID": requestId }
    );
  } catch (error) {
    if (error?.status) return authOrValidationError(error, requestId);
    return authOrValidationError(httpError(502, "AUDIT_LIST_FAILED"), requestId);
  }
}

async function handleAdminEvidence(request, env, url) {
  const requestId = requestIdentifier(request);
  if (!env.VOLUNTEER_EVIDENCE) {
    return authOrValidationError(
      httpError(503, "EVIDENCE_STORAGE_NOT_CONFIGURED"),
      requestId
    );
  }
  try {
    await requireAdministrator(request, env);
    const objectKey = safeString(url.searchParams.get("objectKey"));
    const keyMatch = objectKey?.match(
      /^volunteer-evidence\/([A-Za-z0-9_-]{8,128})\/[^/]{1,255}$/
    );
    if (!objectKey || !keyMatch) {
      throw httpError(400, "INVALID_OBJECT_KEY");
    }
    const projectId = env.FIREBASE_PROJECT_ID || "englishplus-testflight";
    const accessToken = await serviceAccountAccessToken(env);
    const applicationDocument = await getVolunteerApplicationDocument(
      projectId,
      accessToken,
      keyMatch[1]
    );
    const application = normalizeVolunteerApplicationDocument(applicationDocument);
    const evidence = application.evidence.find((item) => item.objectKey === objectKey);
    if (!evidence || application.evidenceDeletedAt) {
      throw httpError(404, "EVIDENCE_NOT_FOUND");
    }
    const object = await env.VOLUNTEER_EVIDENCE.get(objectKey);
    if (!object?.body) throw httpError(404, "EVIDENCE_NOT_FOUND");
    const filename = contentDispositionFilename(evidence.filename);
    const headers = new Headers({
      "Cache-Control": "private, no-store",
      "Content-Type": object.httpMetadata?.contentType || "application/octet-stream",
      "Content-Disposition": `attachment; filename="${filename}"`,
      "X-Content-Type-Options": "nosniff",
      "X-EnglishPlus-Request-ID": requestId,
    });
    return new Response(object.body, { status: 200, headers });
  } catch (error) {
    return authOrValidationError(error, requestId);
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

async function handleClassroomStudentList(request, env, classId) {
  try {
    const user = await requireFirebaseUser(request, env);
    const students = await listClassroomStudents(env, user, classId);
    return jsonResponse({ ok: true, classId, students });
  } catch (error) {
    if (error?.status) return authOrValidationError(error);
    return jsonResponse({ ok: false, error: "CLASSROOM_STUDENT_LIST_FAILED" }, 502);
  }
}

async function handleClassroomUpdate(request, env, classId) {
  try {
    const user = await requireFirebaseUser(request, env);
    const input = normalizeClassroomUpdateRequest(await request.json());
    const classroom = await updateClassroom(env, user, classId, input);
    return jsonResponse({ ok: true, classroom });
  } catch (error) {
    if (error?.status) return authOrValidationError(error);
    return jsonResponse({ ok: false, error: "CLASSROOM_UPDATE_FAILED" }, 502);
  }
}

async function handleClassroomDelete(request, env, classId) {
  try {
    const user = await requireFirebaseUser(request, env);
    const result = await deleteClassroom(env, user, classId);
    return jsonResponse({ ok: true, ...result });
  } catch (error) {
    if (error?.status) return authOrValidationError(error);
    return jsonResponse({ ok: false, error: "CLASSROOM_DELETE_FAILED" }, 502);
  }
}

async function handleVolunteerServiceList(request, env) {
  try {
    const user = await requireFirebaseUser(request, env);
    const services = await listVolunteerServices(env, user);
    return jsonResponse({ ok: true, services });
  } catch (error) {
    if (error?.status) return authOrValidationError(error);
    return jsonResponse({ ok: false, error: "VOLUNTEER_SERVICE_LIST_FAILED" }, 502);
  }
}

async function handleVolunteerServiceRequest(request, env) {
  try {
    const user = await requireFirebaseUser(request, env);
    const input = normalizeClassroomJoinRequest(await request.json());
    const service = await requestVolunteerService(env, user, input.code);
    return jsonResponse({ ok: true, service }, 201);
  } catch (error) {
    if (error?.status) return authOrValidationError(error);
    return jsonResponse({ ok: false, error: "VOLUNTEER_SERVICE_REQUEST_FAILED" }, 502);
  }
}

async function handleVolunteerServiceLeave(request, env, classId) {
  try {
    const user = await requireFirebaseUser(request, env);
    const result = await leaveVolunteerService(env, user, classId);
    return jsonResponse({ ok: true, ...result });
  } catch (error) {
    if (error?.status) return authOrValidationError(error);
    return jsonResponse({ ok: false, error: "VOLUNTEER_SERVICE_LEAVE_FAILED" }, 502);
  }
}

async function handleClassroomVolunteerList(request, env, classId) {
  try {
    const user = await requireFirebaseUser(request, env);
    const services = await listClassroomVolunteers(env, user, classId);
    return jsonResponse({ ok: true, services });
  } catch (error) {
    if (error?.status) return authOrValidationError(error);
    return jsonResponse({ ok: false, error: "CLASSROOM_VOLUNTEER_LIST_FAILED" }, 502);
  }
}

async function handleVolunteerInviteCodeReset(request, env, classId) {
  try {
    const user = await requireFirebaseUser(request, env);
    const invitation = await resetVolunteerInviteCode(env, user, classId);
    return jsonResponse({ ok: true, invitation });
  } catch (error) {
    if (error?.status) return authOrValidationError(error);
    return jsonResponse({ ok: false, error: "VOLUNTEER_CODE_RESET_FAILED" }, 502);
  }
}

async function handleVolunteerInviteCodeGet(request, env, classId) {
  try {
    const user = await requireFirebaseUser(request, env);
    const invitation = await getVolunteerInviteCode(env, user, classId);
    return jsonResponse({ ok: true, invitation });
  } catch (error) {
    if (error?.status) return authOrValidationError(error);
    return jsonResponse({ ok: false, error: "VOLUNTEER_CODE_LOOKUP_FAILED" }, 502);
  }
}

async function handleClassroomVolunteerAction(request, env, classId, volunteerUid, action) {
  try {
    const user = await requireFirebaseUser(request, env);
    const result = await reviewVolunteerService(env, user, classId, volunteerUid, action);
    return jsonResponse({ ok: true, ...result });
  } catch (error) {
    if (error?.status) return authOrValidationError(error);
    return jsonResponse({ ok: false, error: "VOLUNTEER_SERVICE_ACTION_FAILED" }, 502);
  }
}

function normalizeClassroomCreateRequest(raw) {
  const name = safeString(raw?.name)?.normalize("NFKC").replace(/\s+/g, " ");
  if (!name || name.length < 2 || name.length > 40 || /[\u0000-\u001F]/.test(name)) {
    throw httpError(400, "INVALID_CLASSROOM_NAME");
  }
  return { name };
}

function normalizeClassroomUpdateRequest(raw) {
  const normalized = normalizeClassroomCreateRequest({ name: raw?.name });
  return { name: normalized.name };
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
  if (!classroomIsOperationalDocument(classroom)) {
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

async function listVolunteerServices(env, user) {
  const context = await classroomUserContext(env, user);
  requireActiveRole(context.profile, "volunteer", "VOLUNTEER_APPROVAL_REQUIRED");
  const documents = await listFirestoreCollection(
    context.projectId,
    context.accessToken,
    `users/${user.sub}/volunteerServices`,
    context.firestoreBaseURL
  );
  return documents
    .map(volunteerServiceSummaryFromDocument)
    .filter(Boolean)
    .sort((left, right) => right.requestedAt.localeCompare(left.requestedAt));
}

async function requestVolunteerService(env, user, inviteCode) {
  const context = await classroomUserContext(env, user);
  requireActiveRole(context.profile, "volunteer", "VOLUNTEER_APPROVAL_REQUIRED");
  await assertClassJoinRateLimit(context, user.sub);
  const mapping = await getFirestoreDocument(
    context.projectId,
    context.accessToken,
    `volunteerJoinCodes/${inviteCode}`,
    context.firestoreBaseURL
  );
  if (!mapping || mapping.fields?.active?.booleanValue !== true) {
    throw httpError(404, "CLASSROOM_CODE_NOT_FOUND");
  }
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
  if (!classroomIsOperationalDocument(classroom)) {
    throw httpError(410, "CLASSROOM_UNAVAILABLE");
  }
  const requestPath = `classes/${classId}/volunteerRequests/${user.sub}`;
  const existing = await getFirestoreDocument(
    context.projectId,
    context.accessToken,
    requestPath,
    context.firestoreBaseURL
  );
  const existingStatus = firestoreString(existing?.fields?.status);
  if (existingStatus === "pendingApproval" || existingStatus === "active") {
    throw httpError(409, "VOLUNTEER_SERVICE_ALREADY_REQUESTED");
  }

  const now = new Date().toISOString();
  const className = firestoreString(classroom.fields?.name) || "English+ 班級";
  const volunteerName = firestoreString(context.profile.fields?.displayName) || "志工";
  const fields = volunteerServiceFields({
    classId,
    className,
    volunteerUid: user.sub,
    volunteerName,
    status: "pendingApproval",
    requestedAt: existing?.fields?.requestedAt?.timestampValue || now,
    decidedAt: null,
    joinedAt: null,
    updatedAt: now,
  });
  const root = firestoreRoot(context.projectId);
  await commitFirestoreWrites(context, [
    {
      update: { name: `${root}/${requestPath}`, fields },
      currentDocument: existing ? { updateTime: existing.updateTime } : { exists: false },
    },
    {
      update: {
        name: `${root}/users/${user.sub}/volunteerServices/${classId}`,
        fields,
      },
    },
  ]);
  return volunteerServiceSummaryFromFields(fields, `${classId}-${user.sub}`);
}

async function listClassroomVolunteers(env, user, classId) {
  const context = await classroomUserContext(env, user);
  await requireOwnedTeacherClassroom(context, user.sub, classId);
  const documents = await listFirestoreCollection(
    context.projectId,
    context.accessToken,
    `classes/${classId}/volunteerRequests`,
    context.firestoreBaseURL
  );
  return documents
    .map(volunteerServiceSummaryFromDocument)
    .filter(Boolean)
    .sort((left, right) => {
      if (left.status === right.status) return right.requestedAt.localeCompare(left.requestedAt);
      if (left.status === "pendingApproval") return -1;
      if (right.status === "pendingApproval") return 1;
      if (left.status === "active") return -1;
      if (right.status === "active") return 1;
      return 0;
    });
}

async function resetVolunteerInviteCode(env, user, classId) {
  const context = await classroomUserContext(env, user);
  const { admin } = await requireOwnedTeacherClassroom(context, user.sub, classId);
  const code = await unusedVolunteerCode(context);
  const oldCode = firestoreString(admin.fields?.volunteerJoinCode);
  const version = Number(admin.fields?.volunteerCodeVersion?.integerValue || 0) + 1;
  const now = new Date().toISOString();
  const root = firestoreRoot(context.projectId);
  const writes = [
    maskedUpdateWrite(
      `${root}/classAdmins/${classId}`,
      {
        volunteerJoinCode: { stringValue: code },
        volunteerCodeVersion: { integerValue: String(version) },
        updatedAt: { timestampValue: now },
      },
      ["volunteerJoinCode", "volunteerCodeVersion", "updatedAt"],
      admin.updateTime
    ),
    {
      update: {
        name: `${root}/volunteerJoinCodes/${code}`,
        fields: {
          classId: { stringValue: classId },
          active: { booleanValue: true },
          codeVersion: { integerValue: String(version) },
          createdAt: { timestampValue: now },
        },
      },
      currentDocument: { exists: false },
    },
  ];
  if (oldCode && oldCode !== code) {
    writes.push({ delete: `${root}/volunteerJoinCodes/${oldCode}` });
  }
  await commitFirestoreWrites(context, writes);
  return { classId, code };
}

async function getVolunteerInviteCode(env, user, classId) {
  const context = await classroomUserContext(env, user);
  const { admin } = await requireOwnedTeacherClassroom(context, user.sub, classId);
  const code = firestoreString(admin?.fields?.volunteerJoinCode);
  return code ? { classId, code } : null;
}

async function reviewVolunteerService(env, user, classId, volunteerUid, action) {
  if (!/^[A-Za-z0-9:_-]{1,160}$/.test(volunteerUid)) {
    throw httpError(400, "INVALID_VOLUNTEER_UID");
  }
  if (!new Set(["approve", "reject", "remove"]).has(action)) {
    throw httpError(400, "INVALID_VOLUNTEER_ACTION");
  }
  const context = await classroomUserContext(env, user);
  const { classroom } = await requireOwnedTeacherClassroom(context, user.sub, classId);
  const [service, volunteerProfile, membership, mirror] = await Promise.all([
    getFirestoreDocument(
      context.projectId,
      context.accessToken,
      `classes/${classId}/volunteerRequests/${volunteerUid}`,
      context.firestoreBaseURL
    ),
    getFirestoreDocument(
      context.projectId,
      context.accessToken,
      `users/${volunteerUid}`,
      context.firestoreBaseURL
    ),
    getFirestoreDocument(
      context.projectId,
      context.accessToken,
      `classes/${classId}/members/${volunteerUid}`,
      context.firestoreBaseURL
    ),
    getFirestoreDocument(
      context.projectId,
      context.accessToken,
      `users/${volunteerUid}/classMemberships/${classId}`,
      context.firestoreBaseURL
    ),
  ]);
  if (!service) throw httpError(404, "VOLUNTEER_SERVICE_NOT_FOUND");
  const previousStatus = firestoreString(service.fields?.status);
  if (action === "approve" && previousStatus !== "pendingApproval") {
    throw httpError(409, "VOLUNTEER_SERVICE_NOT_PENDING");
  }
  if (action === "reject" && previousStatus !== "pendingApproval") {
    throw httpError(409, "VOLUNTEER_SERVICE_NOT_PENDING");
  }
  if (action === "remove" && previousStatus !== "active") {
    throw httpError(409, "VOLUNTEER_SERVICE_NOT_ACTIVE");
  }
  if (
    action === "approve"
    && (
      firestoreString(volunteerProfile?.fields?.primaryRole) !== "volunteer"
      || firestoreString(volunteerProfile?.fields?.accountStatus) !== "active"
      || volunteerProfile?.fields?.active?.booleanValue !== true
    )
  ) {
    throw httpError(403, "VOLUNTEER_APPROVAL_REQUIRED");
  }

  const now = new Date().toISOString();
  const className = firestoreString(classroom.fields?.name) || "English+ 班級";
  const volunteerName = firestoreString(service.fields?.volunteerName)
    || firestoreString(volunteerProfile?.fields?.displayName)
    || "志工";
  const status = action === "approve" ? "active" : action === "reject" ? "rejected" : "removed";
  const joinedAt = action === "approve"
    ? service.fields?.joinedAt?.timestampValue || now
    : service.fields?.joinedAt?.timestampValue || null;
  const fields = volunteerServiceFields({
    classId,
    className,
    volunteerUid,
    volunteerName,
    status,
    requestedAt: service.fields?.requestedAt?.timestampValue || now,
    decidedAt: now,
    joinedAt,
    updatedAt: now,
  });
  const root = firestoreRoot(context.projectId);
  const writes = [
    {
      update: {
        name: `${root}/classes/${classId}/volunteerRequests/${volunteerUid}`,
        fields,
      },
      currentDocument: { updateTime: service.updateTime },
    },
    {
      update: {
        name: `${root}/users/${volunteerUid}/volunteerServices/${classId}`,
        fields,
      },
    },
  ];

  if (action === "approve") {
    const membershipFieldsValue = membershipFields({
      uid: volunteerUid,
      classId,
      className,
      role: "volunteer",
      displayName: volunteerName,
      joinedAt,
      visibilityStartsAt: now,
      leftAt: null,
    });
    writes.push({
      update: {
        name: `${root}/classes/${classId}/members/${volunteerUid}`,
        fields: membershipFieldsValue,
      },
      ...(membership ? { currentDocument: { updateTime: membership.updateTime } } : { currentDocument: { exists: false } }),
    });
    writes.push({
      update: {
        name: `${root}/users/${volunteerUid}/classMemberships/${classId}`,
        fields: userMembershipFields({
          classId,
          className,
          role: "volunteer",
          joinedAt,
          visibilityStartsAt: now,
          leftAt: null,
        }),
      },
      ...(mirror ? { currentDocument: { updateTime: mirror.updateTime } } : {}),
    });
  } else if (action === "remove") {
    writes.push(...volunteerMembershipExitWrites(
      root,
      classId,
      volunteerUid,
      membership,
      mirror,
      volunteerProfile,
      now,
      "teacherRemoved"
    ));
  }
  await commitFirestoreWrites(context, writes);
  return { classId, volunteerUid, status };
}

async function leaveVolunteerService(env, user, classId) {
  const context = await classroomUserContext(env, user);
  requireActiveRole(context.profile, "volunteer", "VOLUNTEER_APPROVAL_REQUIRED");
  const [service, membership, mirror] = await Promise.all([
    getFirestoreDocument(
      context.projectId,
      context.accessToken,
      `classes/${classId}/volunteerRequests/${user.sub}`,
      context.firestoreBaseURL
    ),
    getFirestoreDocument(
      context.projectId,
      context.accessToken,
      `classes/${classId}/members/${user.sub}`,
      context.firestoreBaseURL
    ),
    getFirestoreDocument(
      context.projectId,
      context.accessToken,
      `users/${user.sub}/classMemberships/${classId}`,
      context.firestoreBaseURL
    ),
  ]);
  const serviceStatus = firestoreString(service?.fields?.status);
  if (!service || !new Set(["pendingApproval", "active"]).has(serviceStatus)) {
    throw httpError(404, "VOLUNTEER_SERVICE_NOT_FOUND");
  }
  const now = new Date().toISOString();
  const fields = volunteerServiceFields({
    classId,
    className: firestoreString(service.fields?.className) || "English+ 班級",
    volunteerUid: user.sub,
    volunteerName: firestoreString(service.fields?.volunteerName) || "志工",
    status: "left",
    requestedAt: service.fields?.requestedAt?.timestampValue || now,
    decidedAt: now,
    joinedAt: service.fields?.joinedAt?.timestampValue || null,
    updatedAt: now,
  });
  const root = firestoreRoot(context.projectId);
  await commitFirestoreWrites(context, [
    {
      update: {
        name: `${root}/classes/${classId}/volunteerRequests/${user.sub}`,
        fields,
      },
      currentDocument: { updateTime: service.updateTime },
    },
    {
      update: {
        name: `${root}/users/${user.sub}/volunteerServices/${classId}`,
        fields,
      },
    },
    ...(serviceStatus === "active"
      ? volunteerMembershipExitWrites(
          root,
          classId,
          user.sub,
          membership,
          mirror,
          context.profile,
          now,
          "volunteerLeft"
        )
      : []),
  ]);
  return { classId, volunteerUid: user.sub, status: "left" };
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

async function listClassroomStudents(env, user, classId) {
  const context = await classroomUserContext(env, user);
  await requireOwnedTeacherClassroom(context, user.sub, classId);
  const memberships = await listFirestoreCollection(
    context.projectId,
    context.accessToken,
    `classes/${classId}/members`,
    context.firestoreBaseURL
  );
  const activeStudents = memberships.filter((membership) =>
    membershipIsActiveDocument(membership)
      && firestoreString(membership.fields?.role) === "student"
  );

  const students = await Promise.all(activeStudents.map(async (membership) => {
    const uid = documentId(membership.name);
    const summary = await getFirestoreDocument(
      context.projectId,
      context.accessToken,
      `classes/${classId}/students/${uid}`,
      context.firestoreBaseURL
    );
    const fields = summary?.fields || {};
    const moodValue = Number(fields.lastMoodScore?.integerValue);
    return {
      id: uid,
      studentUid: uid,
      studentName: firestoreString(fields.displayName)
        || firestoreString(membership.fields?.displayName)
        || "學生",
      classId,
      gradeBand: firestoreString(fields.gradeBand),
      currentLevel: firestoreString(fields.currentLevel) || "待評估",
      recommendedTrack: firestoreString(fields.recommendedTrack) || "steady",
      moodScore: Number.isInteger(moodValue) ? moodValue : null,
      riskLevel: firestoreString(fields.riskLevel) || "low",
      missionStatus: firestoreString(fields.lastMissionStatus) || "notStarted",
      membershipStatus: firestoreString(fields.membershipStatus) || "active",
      lastActivityAt: fields.lastActivityAt?.timestampValue || null,
      joinedAt: membership.fields?.joinedAt?.timestampValue || "",
    };
  }));

  return students.sort((left, right) =>
    left.studentName.localeCompare(right.studentName, "zh-Hant")
  );
}

async function updateClassroom(env, user, classId, input) {
  const context = await classroomUserContext(env, user);
  const { classroom, membership, admin } = await requireOwnedTeacherClassroom(
    context,
    user.sub,
    classId
  );
  const [memberships, volunteerRequests] = await Promise.all([
    listFirestoreCollection(
      context.projectId,
      context.accessToken,
      `classes/${classId}/members`,
      context.firestoreBaseURL
    ),
    listFirestoreCollection(
      context.projectId,
      context.accessToken,
      `classes/${classId}/volunteerRequests`,
      context.firestoreBaseURL
    ),
  ]);
  if (memberships.length + volunteerRequests.length > 240) {
    throw httpError(409, "CLASSROOM_TOO_LARGE_TO_RENAME");
  }

  const now = new Date().toISOString();
  const root = firestoreRoot(context.projectId);
  const writes = [
    maskedUpdateWrite(
      `${root}/classes/${classId}`,
      {
        name: { stringValue: input.name },
        ownerTeacherUid: { stringValue: user.sub },
        updatedAt: { timestampValue: now },
      },
      ["name", "ownerTeacherUid", "updatedAt"],
      classroom.updateTime
    ),
  ];
  for (const member of memberships) {
    const uid = documentId(member.name);
    const role = firestoreString(member.fields?.role);
    if (!uid || !new Set(["student", "teacher", "volunteer"]).has(role)) continue;
    writes.push(
      maskedUpdateWrite(
        `${root}/classes/${classId}/members/${uid}`,
        {
          className: { stringValue: input.name },
          updatedAt: { timestampValue: now },
        },
        ["className", "updatedAt"]
      )
    );
  }
  for (const service of volunteerRequests) {
    const volunteerUid = firestoreString(service.fields?.volunteerUid) || documentId(service.name);
    if (!volunteerUid) continue;
    const fields = {
      className: { stringValue: input.name },
      updatedAt: { timestampValue: now },
    };
    writes.push(maskedUpdateWrite(
      `${root}/classes/${classId}/volunteerRequests/${volunteerUid}`,
      fields,
      ["className", "updatedAt"],
      service.updateTime
    ));
    writes.push(maskedUpdateWrite(
      `${root}/users/${volunteerUid}/volunteerServices/${classId}`,
      fields,
      ["className", "updatedAt"]
    ));
  }
  await commitFirestoreWrites(context, writes);

  return classroomSummary({
    classId,
    name: input.name,
    role: "teacher",
    status: "active",
    joinedAt: membership.fields?.joinedAt?.timestampValue || now,
    visibilityStartsAt: membership.fields?.visibilityStartsAt?.timestampValue || now,
    leftAt: "",
    joinCode: firestoreString(admin?.fields?.joinCode),
  });
}

async function deleteClassroom(env, user, classId) {
  const context = await classroomUserContext(env, user);
  const { classroom, membership, admin } = await requireOwnedTeacherClassroomForDeletion(
    context,
    user.sub,
    classId
  );
  const lifecycleStatus = firestoreString(classroom.fields?.lifecycleStatus);
  if (lifecycleStatus === "deleted" || classroom.fields?.active?.booleanValue === false) {
    return {
      classId,
      deleted: true,
      alreadyDeleted: true,
      deletedAt: classroom.fields?.deletedAt?.timestampValue || null,
    };
  }

  const now = new Date().toISOString();
  const root = firestoreRoot(context.projectId);
  const ownerTeacherUid = firestoreString(classroom.fields?.ownerTeacherUid) || user.sub;
  const oldJoinCode = firestoreString(admin?.fields?.joinCode);
  const oldVolunteerJoinCode = firestoreString(admin?.fields?.volunteerJoinCode);

  if (classroom.fields?.deletionPending?.booleanValue !== true) {
    const controlPlaneWrites = [
      maskedUpdateWrite(
        `${root}/classes/${classId}`,
        {
          lifecycleStatus: { stringValue: "deleting" },
          deletionPending: { booleanValue: true },
          deletionRequestedAt: { timestampValue: now },
          deletionRequestedByUid: { stringValue: user.sub },
          updatedAt: { timestampValue: now },
        },
        [
          "lifecycleStatus",
          "deletionPending",
          "deletionRequestedAt",
          "deletionRequestedByUid",
          "updatedAt",
        ],
        classroom.updateTime
      ),
    ];
    if (admin) {
      controlPlaneWrites.push(
        maskedUpdateWrite(
          `${root}/classAdmins/${classId}`,
          {
            active: { booleanValue: false },
            deletionPending: { booleanValue: true },
            joinCode: { nullValue: null },
            volunteerJoinCode: { nullValue: null },
            updatedAt: { timestampValue: now },
          },
          ["active", "deletionPending", "joinCode", "volunteerJoinCode", "updatedAt"],
          admin.updateTime
        )
      );
    }
    if (oldJoinCode) {
      controlPlaneWrites.push({ delete: `${root}/classJoinCodes/${oldJoinCode}` });
    }
    if (oldVolunteerJoinCode) {
      controlPlaneWrites.push({ delete: `${root}/volunteerJoinCodes/${oldVolunteerJoinCode}` });
    }
    await commitFirestoreWrites(context, controlPlaneWrites);
  }

  const [members, volunteerRequests] = await Promise.all([
    listFirestoreCollection(
      context.projectId,
      context.accessToken,
      `classes/${classId}/members`,
      context.firestoreBaseURL
    ),
    listFirestoreCollection(
      context.projectId,
      context.accessToken,
      `classes/${classId}/volunteerRequests`,
      context.firestoreBaseURL
    ),
  ]);
  const activeMembers = members.filter(membershipIsActiveDocument);
  const preparedMembers = await Promise.all(activeMembers.map(async (member) => {
    const uid = documentId(member.name);
    const role = firestoreString(member.fields?.role);
    if (!uid) return null;
    const [profile, membershipMirror, studentSummary, volunteerRequest, volunteerServiceMirror] = await Promise.all([
      getFirestoreDocument(
        context.projectId,
        context.accessToken,
        `users/${uid}`,
        context.firestoreBaseURL
      ),
      getFirestoreDocument(
        context.projectId,
        context.accessToken,
        `users/${uid}/classMemberships/${classId}`,
        context.firestoreBaseURL
      ),
      role === "student"
        ? getFirestoreDocument(
            context.projectId,
            context.accessToken,
            `classes/${classId}/students/${uid}`,
            context.firestoreBaseURL
          )
        : Promise.resolve(null),
      role === "volunteer"
        ? getFirestoreDocument(
            context.projectId,
            context.accessToken,
            `classes/${classId}/volunteerRequests/${uid}`,
            context.firestoreBaseURL
          )
        : Promise.resolve(null),
      role === "volunteer"
        ? getFirestoreDocument(
            context.projectId,
            context.accessToken,
            `users/${uid}/volunteerServices/${classId}`,
            context.firestoreBaseURL
          )
        : Promise.resolve(null),
    ]);
    return {
      uid,
      role,
      member,
      profile,
      membershipMirror,
      studentSummary,
      volunteerRequest,
      volunteerServiceMirror,
    };
  }));

  const validMembers = preparedMembers.filter(Boolean);
  const recordedMemberCount = firestoreInteger(
    classroom.fields?.deletionAffectedMemberCount
  );
  const affectedMemberCount = Math.max(recordedMemberCount, validMembers.length);
  if (recordedMemberCount === 0 && validMembers.length > 0) {
    await commitFirestoreWrites(context, [
      maskedUpdateWrite(
        `${root}/classes/${classId}`,
        {
          deletionAffectedMemberCount: { integerValue: String(validMembers.length) },
          updatedAt: { timestampValue: now },
        },
        ["deletionAffectedMemberCount", "updatedAt"]
      ),
    ]);
  }
  const nonOwnerWrites = validMembers
    .filter((item) => item.uid !== ownerTeacherUid)
    .flatMap((item) => classroomMemberExitWrites(root, classId, item, now));
  await commitFirestoreWriteChunks(context, nonOwnerWrites);

  const activeVolunteerUids = new Set(
    validMembers
      .filter((item) => item.role === "volunteer")
      .map((item) => item.uid)
  );
  const inactiveVolunteerRequests = volunteerRequests.filter((request) => {
    const uid = firestoreString(request.fields?.volunteerUid) || documentId(request.name);
    return uid && !activeVolunteerUids.has(uid);
  });
  const pendingServiceWrites = (
    await Promise.all(inactiveVolunteerRequests.map(async (request) => {
      const volunteerUid = firestoreString(request.fields?.volunteerUid) || documentId(request.name);
      if (!volunteerUid) return [];
      const serviceMirror = await getFirestoreDocument(
        context.projectId,
        context.accessToken,
        `users/${volunteerUid}/volunteerServices/${classId}`,
        context.firestoreBaseURL
      );
      const serviceExitFields = {
        status: { stringValue: "removed" },
        decidedAt: { timestampValue: now },
        decisionReason: { stringValue: "classDeleted" },
        updatedAt: { timestampValue: now },
      };
      const requestWrites = [maskedUpdateWrite(
        `${root}/classes/${classId}/volunteerRequests/${volunteerUid}`,
        serviceExitFields,
        Object.keys(serviceExitFields),
        request.updateTime
      )];
      if (serviceMirror) {
        requestWrites.push(maskedUpdateWrite(
          `${root}/users/${volunteerUid}/volunteerServices/${classId}`,
          serviceExitFields,
          Object.keys(serviceExitFields),
          serviceMirror.updateTime
        ));
      }
      return requestWrites;
    }))
  ).flat();
  await commitFirestoreWriteChunks(context, pendingServiceWrites);

  const ownerState = validMembers.find((item) => item.uid === ownerTeacherUid);
  const finalWrites = ownerState
    ? classroomMemberExitWrites(root, classId, ownerState, now)
    : [];
  finalWrites.push(
    maskedUpdateWrite(
      `${root}/classes/${classId}`,
      {
        active: { booleanValue: false },
        lifecycleStatus: { stringValue: "deleted" },
        deletionPending: { booleanValue: false },
        deletedAt: { timestampValue: now },
        deletedByUid: { stringValue: user.sub },
        updatedAt: { timestampValue: now },
      },
      [
        "active",
        "lifecycleStatus",
        "deletionPending",
        "deletedAt",
        "deletedByUid",
        "updatedAt",
      ]
    ),
    {
      update: {
        name: `${root}/classDeletionAudits/${classId}`,
        fields: {
          classId: { stringValue: classId },
          className: {
            stringValue: firestoreString(classroom.fields?.name) || "English+ 班級",
          },
          ownerTeacherUid: { stringValue: ownerTeacherUid },
          deletedByUid: { stringValue: user.sub },
          deletedAt: { timestampValue: now },
          affectedActiveMemberCount: { integerValue: String(affectedMemberCount) },
          dataDisposition: { stringValue: "softDeletedRetainedForAudit" },
        },
      },
    }
  );
  if (admin) {
    finalWrites.push(
      maskedUpdateWrite(
        `${root}/classAdmins/${classId}`,
        {
          active: { booleanValue: false },
          deletionPending: { booleanValue: false },
          joinCode: { nullValue: null },
          volunteerJoinCode: { nullValue: null },
          deletedAt: { timestampValue: now },
          updatedAt: { timestampValue: now },
        },
        [
          "active",
          "deletionPending",
          "joinCode",
          "volunteerJoinCode",
          "deletedAt",
          "updatedAt",
        ]
      )
    );
  }
  await commitFirestoreWrites(context, finalWrites);

  return {
    classId,
    deleted: true,
    alreadyDeleted: false,
    deletedAt: now,
    affectedMemberCount,
  };
}

function classroomMemberExitWrites(root, classId, item, deletedAt) {
  const exitFields = {
    status: { stringValue: "left" },
    active: { booleanValue: false },
    leftAt: { timestampValue: deletedAt },
    exitReason: { stringValue: "classDeleted" },
    updatedAt: { timestampValue: deletedAt },
  };
  const writes = [
    maskedUpdateWrite(
      `${root}/classes/${classId}/members/${item.uid}`,
      exitFields,
      Object.keys(exitFields),
      item.member.updateTime
    ),
  ];
  if (item.membershipMirror) {
    writes.push(
      maskedUpdateWrite(
        `${root}/users/${item.uid}/classMemberships/${classId}`,
        exitFields,
        Object.keys(exitFields),
        item.membershipMirror.updateTime
      )
    );
  } else {
    writes.push({
      update: {
        name: `${root}/users/${item.uid}/classMemberships/${classId}`,
        fields: {
          classId: { stringValue: classId },
          role: { stringValue: item.role || "unknown" },
          ...exitFields,
        },
      },
    });
  }
  if (item.studentSummary) {
    writes.push(
      maskedUpdateWrite(
        `${root}/classes/${classId}/students/${item.uid}`,
        {
          membershipStatus: { stringValue: "left" },
          leftAt: { timestampValue: deletedAt },
          exitReason: { stringValue: "classDeleted" },
          updatedAt: { timestampValue: deletedAt },
        },
        ["membershipStatus", "leftAt", "exitReason", "updatedAt"],
        item.studentSummary.updateTime
      )
    );
  }
  if (item.volunteerRequest) {
    const volunteerExitFields = {
      status: { stringValue: "removed" },
      decidedAt: { timestampValue: deletedAt },
      updatedAt: { timestampValue: deletedAt },
    };
    writes.push(maskedUpdateWrite(
      `${root}/classes/${classId}/volunteerRequests/${item.uid}`,
      volunteerExitFields,
      Object.keys(volunteerExitFields),
      item.volunteerRequest.updateTime
    ));
  }
  if (item.volunteerServiceMirror) {
    const volunteerExitFields = {
      status: { stringValue: "removed" },
      decidedAt: { timestampValue: deletedAt },
      updatedAt: { timestampValue: deletedAt },
    };
    writes.push(maskedUpdateWrite(
      `${root}/users/${item.uid}/volunteerServices/${classId}`,
      volunteerExitFields,
      Object.keys(volunteerExitFields),
      item.volunteerServiceMirror.updateTime
    ));
  }
  if (firestoreString(item.profile?.fields?.activeClassId) === classId) {
    writes.push(
      maskedUpdateWrite(
        `${root}/users/${item.uid}`,
        {
          activeClassId: { nullValue: null },
          updatedAt: { timestampValue: deletedAt },
        },
        ["activeClassId", "updatedAt"],
        item.profile.updateTime
      )
    );
  }
  return writes;
}

async function requireOwnedTeacherClassroomForDeletion(context, teacherUid, classId) {
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
  if (!classroom) throw httpError(404, "CLASSROOM_NOT_FOUND");
  const ownerTeacherUid = firestoreString(classroom.fields?.ownerTeacherUid)
    || firestoreString(admin?.fields?.ownerTeacherUid);
  if (ownerTeacherUid !== teacherUid) {
    throw httpError(403, "CLASSROOM_OWNER_REQUIRED");
  }
  const lifecycleStatus = firestoreString(classroom.fields?.lifecycleStatus);
  if (
    lifecycleStatus !== "deleted"
    && (
      !membership
      || firestoreString(membership.fields?.role) !== "teacher"
      || !membershipIsActiveDocument(membership)
    )
  ) {
    throw httpError(403, "CLASSROOM_OWNER_REQUIRED");
  }
  return { classroom, membership, admin };
}

async function requireOwnedTeacherClassroom(context, teacherUid, classId) {
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
  if (!classroomIsOperationalDocument(classroom) || !membership) {
    throw httpError(404, "CLASSROOM_NOT_FOUND");
  }
  const ownerTeacherUid = firestoreString(classroom.fields?.ownerTeacherUid)
    || firestoreString(admin?.fields?.ownerTeacherUid);
  if (
    (ownerTeacherUid && ownerTeacherUid !== teacherUid)
    || firestoreString(membership.fields?.role) !== "teacher"
    || !membershipIsActiveDocument(membership)
  ) {
    throw httpError(403, "CLASSROOM_OWNER_REQUIRED");
  }
  return { classroom, membership, admin };
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
    if (!classroomIsOperationalDocument(classroom)) return null;
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
          lifecycleStatus: { stringValue: "active" },
          deletionPending: { booleanValue: false },
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
          active: { booleanValue: true },
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

function volunteerServiceFields(input) {
  return {
    classId: { stringValue: input.classId },
    className: { stringValue: input.className },
    volunteerUid: { stringValue: input.volunteerUid },
    volunteerName: { stringValue: input.volunteerName },
    status: { stringValue: input.status },
    requestedAt: { timestampValue: input.requestedAt },
    decidedAt: input.decidedAt ? { timestampValue: input.decidedAt } : { nullValue: null },
    joinedAt: input.joinedAt ? { timestampValue: input.joinedAt } : { nullValue: null },
    updatedAt: { timestampValue: input.updatedAt },
  };
}

function volunteerServiceSummaryFromDocument(document) {
  if (!document?.fields) return null;
  return volunteerServiceSummaryFromFields(document.fields, documentId(document.name));
}

function volunteerServiceSummaryFromFields(fields, id) {
  const classId = firestoreString(fields?.classId);
  const volunteerUid = firestoreString(fields?.volunteerUid);
  const status = firestoreString(fields?.status);
  if (!classId || !volunteerUid || !status) return null;
  return {
    id: id || `${classId}-${volunteerUid}`,
    classId,
    className: firestoreString(fields?.className) || "English+ 班級",
    volunteerUid,
    volunteerName: firestoreString(fields?.volunteerName) || "志工",
    status,
    requestedAt: fields?.requestedAt?.timestampValue || "",
    decidedAt: fields?.decidedAt?.timestampValue || null,
    joinedAt: fields?.joinedAt?.timestampValue || null,
  };
}

function volunteerMembershipExitWrites(
  root,
  classId,
  volunteerUid,
  membership,
  mirror,
  profile,
  now,
  exitReason
) {
  const writes = [];
  if (membership) {
    writes.push(maskedUpdateWrite(
      `${root}/classes/${classId}/members/${volunteerUid}`,
      {
        status: { stringValue: "left" },
        active: { booleanValue: false },
        leftAt: { timestampValue: now },
        exitReason: { stringValue: exitReason },
        updatedAt: { timestampValue: now },
      },
      ["status", "active", "leftAt", "exitReason", "updatedAt"],
      membership.updateTime
    ));
  }
  if (mirror) {
    writes.push(maskedUpdateWrite(
      `${root}/users/${volunteerUid}/classMemberships/${classId}`,
      {
        status: { stringValue: "left" },
        active: { booleanValue: false },
        leftAt: { timestampValue: now },
        exitReason: { stringValue: exitReason },
        updatedAt: { timestampValue: now },
      },
      ["status", "active", "leftAt", "exitReason", "updatedAt"],
      mirror.updateTime
    ));
  }
  if (firestoreString(profile?.fields?.activeClassId) === classId) {
    writes.push(maskedUpdateWrite(
      `${root}/users/${volunteerUid}`,
      {
        activeClassId: { nullValue: null },
        updatedAt: { timestampValue: now },
      },
      ["activeClassId", "updatedAt"],
      profile.updateTime
    ));
  }
  return writes;
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

async function unusedVolunteerCode(context) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const code = generateClassCode();
    const existing = await getFirestoreDocument(
      context.projectId,
      context.accessToken,
      `volunteerJoinCodes/${code}`,
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

function classroomIsOperationalDocument(document) {
  const fields = document?.fields || {};
  const lifecycleStatus = firestoreString(fields.lifecycleStatus);
  return Boolean(document)
    && fields.active?.booleanValue === true
    && fields.deletionPending?.booleanValue !== true
    && (!lifecycleStatus || lifecycleStatus === "active");
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

async function requireAdministrator(request, env) {
  const user = await requireFirebaseUser(request, env);
  if (user.admin !== true) {
    throw httpError(403, "ADMIN_REQUIRED");
  }
  return user;
}

function normalizeAdminReviewRequest(raw) {
  if (!raw || typeof raw !== "object") {
    throw httpError(400, "INVALID_JSON");
  }
  const action = safeString(raw.action);
  if (!action || !VOLUNTEER_REVIEW_ACTIONS[action]) {
    throw httpError(400, "INVALID_REVIEW_ACTION");
  }
  const note = safeString(raw.note)?.slice(0, 1000) || "";
  if (action !== "approved" && note.length < 3) {
    throw httpError(400, "REVIEW_NOTE_REQUIRED");
  }
  const expectedVersion = safeString(raw.expectedVersion) || "";
  if (expectedVersion && !Number.isFinite(Date.parse(expectedVersion))) {
    throw httpError(400, "INVALID_REVIEW_VERSION");
  }
  return { action, note, expectedVersion };
}

function normalizeAdminApplicationQuery(searchParams) {
  const scope = searchParams.get("scope") === "all" ? "all" : "actionable";
  const rawStatus = safeString(searchParams.get("status")) || "";
  const status = VOLUNTEER_REVIEW_STATUSES.has(rawStatus) ? rawStatus : "";
  const query = (safeString(searchParams.get("query")) || "")
    .toLocaleLowerCase("zh-TW")
    .slice(0, 120);
  return { scope, status, query };
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
  if (review.expectedVersion && review.expectedVersion !== application.updateTime) {
    throw httpError(409, "STALE_REVIEW_VERSION");
  }
  if (!reviewTransitionAllowed(currentStatus, review.action)) {
    throw httpError(409, "REVIEW_STATE_CONFLICT");
  }
  const now = new Date().toISOString();
  const auditId = crypto.randomUUID();
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
          {
            update: {
              name: `${root}/volunteerApplications/${review.uid}/reviewEvents/${auditId}`,
              fields: {
                id: { stringValue: auditId },
                applicantUid: { stringValue: review.uid },
                reviewerUid: { stringValue: review.reviewerUid },
                reviewerEmail: { stringValue: review.reviewerEmail },
                action: { stringValue: review.action },
                previousStatus: { stringValue: currentStatus },
                resultingStatus: { stringValue: review.applicationStatus },
                note: { stringValue: review.note },
                requestId: { stringValue: review.requestId },
                createdAt: { timestampValue: now },
              },
            },
            currentDocument: { exists: false },
          },
        ],
      }),
    }
  );
  if (!response.ok) {
    const payload = await response.json().catch(() => ({}));
    const status = safeString(payload?.error?.status);
    if (
      response.status === 409 ||
      status === "FAILED_PRECONDITION" ||
      status === "ABORTED"
    ) {
      throw httpError(409, "STALE_REVIEW_VERSION");
    }
    throw httpError(502, "REVIEW_COMMIT_FAILED");
  }
  const payload = await response.json();
  return {
    previousStatus: currentStatus,
    version: payload.writeResults?.[0]?.updateTime || now,
    auditId,
  };
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

async function listVolunteerApplications(env, query = { scope: "actionable", status: "", query: "" }) {
  const accessToken = await serviceAccountAccessToken(env);
  const documents = await listVolunteerApplicationDocuments(env, accessToken);
  const allApplications = documents.map(normalizeVolunteerApplicationDocument);
  const applications = filterVolunteerApplications(allApplications, query).sort(
    (left, right) => {
      const priority = { pendingReview: 0, needsMoreInformation: 1 };
      const leftPriority = priority[left.status] ?? 2;
      const rightPriority = priority[right.status] ?? 2;
      if (leftPriority !== rightPriority) return leftPriority - rightPriority;
      return right.submittedAt.localeCompare(left.submittedAt);
    }
  );
  return {
    applications,
    total: applications.length,
    summary: summarizeVolunteerApplications(allApplications),
  };
}

function filterVolunteerApplications(applications, query) {
  const actionable = new Set(["pendingReview", "needsMoreInformation"]);
  return applications.filter((application) => {
    if (query.scope !== "all" && !actionable.has(application.status)) return false;
    if (query.status && application.status !== query.status) return false;
    if (!query.query) return true;
    const haystack = [
      application.displayName,
      application.uid,
      application.motivation,
      application.status,
    ]
      .join(" ")
      .toLocaleLowerCase("zh-TW");
    return haystack.includes(query.query);
  });
}

function summarizeVolunteerApplications(applications) {
  const summary = {
    total: applications.length,
    actionable: 0,
    draft: 0,
    pendingReview: 0,
    needsMoreInformation: 0,
    approved: 0,
    rejected: 0,
    suspended: 0,
  };
  for (const application of applications) {
    if (Object.hasOwn(summary, application.status)) {
      summary[application.status] += 1;
    }
    if (["pendingReview", "needsMoreInformation"].includes(application.status)) {
      summary.actionable += 1;
    }
  }
  return summary;
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
    uid: firestoreString(fields.uid) || document.name?.split("/").pop() || "",
    displayName: firestoreString(fields.displayName) || "未提供姓名",
    status: firestoreString(fields.status) || "draft",
    motivation: firestoreString(fields.motivation),
    confirmsAge18OrOlder: Boolean(fields.confirmsAge18OrOlder?.booleanValue),
    acceptedConductVersion: firestoreString(fields.acceptedConductVersion),
    submittedAt:
      fields.submittedAt?.timestampValue || fields.updatedAt?.timestampValue || "",
    updatedAt: fields.updatedAt?.timestampValue || document.updateTime || "",
    reviewedAt: fields.reviewedAt?.timestampValue || "",
    reviewedByUid: firestoreString(fields.reviewedByUid),
    reviewNote: firestoreString(fields.reviewNote),
    evidenceRetentionUntil: fields.evidenceRetentionUntil?.timestampValue || "",
    evidenceDeletedAt: fields.evidenceDeletedAt?.timestampValue || "",
    version: document.updateTime || "",
    evidence: evidenceValues.map((value) => {
      const item = value.mapValue?.fields || {};
      return {
        id: firestoreString(item.id),
        kind: firestoreString(item.kind),
        objectKey: firestoreString(item.storageObjectKey),
        filename: firestoreString(item.originalFilename),
        mimeType: firestoreString(item.mimeType),
        sizeBytes: Number(item.sizeBytes?.integerValue || 0),
        uploadedAt: item.uploadedAt?.timestampValue || "",
      };
    }),
  };
}

async function listVolunteerReviewEvents(env, uid) {
  const projectId = env.FIREBASE_PROJECT_ID || "englishplus-testflight";
  const accessToken = await serviceAccountAccessToken(env);
  const endpoint = new URL(
    `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/documents/volunteerApplications/${encodeURIComponent(uid)}/reviewEvents`
  );
  endpoint.searchParams.set("pageSize", "100");
  endpoint.searchParams.set("orderBy", "createdAt desc");
  const response = await fetch(endpoint, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!response.ok) {
    throw httpError(502, "AUDIT_LIST_FAILED");
  }
  const payload = await response.json();
  return (payload.documents || []).map((document) => {
    const fields = document.fields || {};
    return {
      id: firestoreString(fields.id) || document.name?.split("/").pop() || "",
      reviewerUid: firestoreString(fields.reviewerUid),
      reviewerEmail: firestoreString(fields.reviewerEmail),
      action: firestoreString(fields.action),
      previousStatus: firestoreString(fields.previousStatus),
      resultingStatus: firestoreString(fields.resultingStatus),
      note: firestoreString(fields.note),
      requestId: firestoreString(fields.requestId),
      createdAt: fields.createdAt?.timestampValue || document.createTime || "",
    };
  });
}

function contentDispositionFilename(filename) {
  const normalized = safeString(filename) || "volunteer-evidence";
  return normalized
    .normalize("NFKD")
    .replace(/[^A-Za-z0-9._-]+/g, "_")
    .replace(/^\.+/, "")
    .slice(0, 120) || "volunteer-evidence";
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

function firestoreInteger(value) {
  const parsed = Number(value?.integerValue);
  return Number.isFinite(parsed) ? parsed : 0;
}

function firestoreStringArray(value) {
  return (value?.arrayValue?.values || [])
    .map(firestoreString)
    .filter(Boolean);
}

async function serviceAccountAccessToken(env) {
  if (!env.FIREBASE_SERVICE_ACCOUNT_EMAIL || !env.FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY) {
    throw new Error("Firebase service account is not configured.");
  }
  const now = Math.floor(Date.now() / 1000);
  const assertion = await signServiceAccountJwt(
    {
      iss: env.FIREBASE_SERVICE_ACCOUNT_EMAIL,
      scope: "https://www.googleapis.com/auth/cloud-platform",
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

function authOrValidationError(error, requestId) {
  const status = Number(error?.status) || 400;
  const code = safeString(error?.code) || "INVALID_REQUEST";
  return jsonResponse(
    {
      ok: false,
      error: code,
      ...(requestId ? { requestId } : {}),
    },
    status,
    requestId ? { "X-EnglishPlus-Request-ID": requestId } : {}
  );
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
        "Do not diagnose mental health and never claim that a teacher, volunteer, or guardian was notified automatically.",
        "For emotional distress, offer low-pressure language and let the student choose whether to contact a trusted adult. For immediate danger, direct them to a nearby trusted adult or Taiwan emergency service 119; 1925 and 113 may also be offered when relevant.",
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
      return [
        "Return keys: shortFeedback, whyWrong, nextHint, tryAgain, staffEscalationNeeded.",
        "Keep whyWrong specific to the supplied question and make nextHint a concrete step the learner can try.",
        "Set tryAgain true unless the supplied question data is unusable.",
      ].join(" ");
    case "emotionalSupport":
      return "Return keys: summary, supportLevel, recommendedNextAction. Keep it low-pressure.";
    case "teacherFeedbackDraft":
      return [
        "Return keys: teacherSummary, studentFacingFeedback, recommendedNextAction.",
        "teacherSummary is a concise staff-only diagnosis of the learning obstacle.",
        "studentFacingFeedback is an editable reply draft, not a diagnosis and not a promise of monitoring.",
        "recommendedNextAction is one specific follow-up the teacher can take.",
      ].join(" ");
    case "volunteerReplyCoach":
      return [
        "Return keys: studentFacingFeedback, recommendedNextAction, summary.",
        "summary is a concise staff-only reading of the learning obstacle.",
        "studentFacingFeedback is an editable, encouraging reply draft.",
        "recommendedNextAction is one specific follow-up the volunteer can take.",
      ].join(" ");
    case "progressSummary":
      return [
        "Create an executable English practice recommendation, not only prose.",
        "Return keys: summary, recommendedNextAction, practicePlan.",
        "practicePlan must include title, targetQuestionCount, focusSkills, questionPlan.",
        "targetQuestionCount must be 6 to 10.",
        "focusSkills must contain up to 3 short skill names grounded in recentWeakSkills.",
        "questionPlan must contain 1 to 4 items with type, difficulty, targetCorrect.",
        "Allowed types: vocabulary, multipleChoice, fillBlank, cloze, reading, translation, dialogue.",
        "Allowed difficulties: foundation, core, exam, advanced.",
        "The sum of targetCorrect should equal targetQuestionCount.",
      ].join(" ");
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

  const normalized = {
    summary: safeString(output.summary),
    shortFeedback: safeString(output.shortFeedback),
    whyWrong: safeString(output.whyWrong),
    nextHint: safeString(output.nextHint),
    tryAgain:
      taskType === "wrongAnswerExplanation"
        ? true
        : typeof output.tryAgain === "boolean"
          ? output.tryAgain
          : undefined,
    staffEscalationNeeded: false,
    supportLevel: safeString(output.supportLevel),
    teacherSummary: safeString(output.teacherSummary),
    studentFacingFeedback: safeString(output.studentFacingFeedback),
    recommendedNextAction: safeString(output.recommendedNextAction),
  };

  if (taskType === "progressSummary") {
    normalized.practicePlan = normalizePracticePlan(output.practicePlan || output);
  }

  return normalized;
}

function normalizePracticePlan(raw) {
  const allowedTypes = new Set([
    "vocabulary",
    "multipleChoice",
    "fillBlank",
    "cloze",
    "reading",
    "translation",
    "dialogue",
  ]);
  const allowedDifficulties = new Set(["foundation", "core", "exam", "advanced"]);
  const rawPlan = Array.isArray(raw?.questionPlan) ? raw.questionPlan : [];
  const questionPlan = rawPlan.slice(0, 4).map((item) => ({
    type: allowedTypes.has(item?.type) ? item.type : "multipleChoice",
    difficulty: allowedDifficulties.has(item?.difficulty) ? item.difficulty : "core",
    targetCorrect: clampInteger(item?.targetCorrect, 1, 6, 1),
  }));

  if (questionPlan.length === 0) {
    questionPlan.push({ type: "multipleChoice", difficulty: "core", targetCorrect: 6 });
  }

  const requestedCount = clampInteger(raw?.targetQuestionCount, 6, 10, 8);
  const normalizedPlan = normalizePlanTotal(questionPlan, requestedCount);
  const focusSkills = Array.isArray(raw?.focusSkills)
    ? raw.focusSkills.map(safeString).filter(Boolean).slice(0, 3)
    : [];

  return {
    title: safeString(raw?.title) || "下一組個人化練習",
    targetQuestionCount: normalizedPlan.reduce((total, item) => total + item.targetCorrect, 0),
    focusSkills,
    questionPlan: normalizedPlan,
  };
}

function normalizePlanTotal(plan, targetCount) {
  const result = plan.map((item) => ({ ...item }));
  let total = result.reduce((sum, item) => sum + item.targetCorrect, 0);

  while (total > targetCount) {
    const index = result.findIndex((item) => item.targetCorrect > 1);
    if (index < 0) break;
    result[index].targetCorrect -= 1;
    total -= 1;
  }

  let cursor = 0;
  while (total < targetCount) {
    const index = cursor % result.length;
    if (result[index].targetCorrect < 6) {
      result[index].targetCorrect += 1;
      total += 1;
    }
    cursor += 1;
    if (cursor > 48) break;
  }

  return result;
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
  const output = fallbackOutput(request);

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

function fallbackOutput(request) {
  switch (request.taskType) {
    case "dailyMission":
      return {
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
      };
    case "progressSummary":
      return {
        summary: "先從最近容易卡住的能力點開始，完成一組短練習。",
        recommendedNextAction: "套用題組後直接開始，完成後再看正確率。",
        practicePlan: {
          title: "最近卡點複習",
          targetQuestionCount: 8,
          focusSkills: request.context.recentWeakSkills || [],
          questionPlan: [
            { type: request.context.preferredQuestionTypes?.[0] || "multipleChoice", difficulty: "core", targetCorrect: 4 },
            { type: request.context.preferredQuestionTypes?.[1] || "fillBlank", difficulty: "exam", targetCorrect: 4 },
          ],
        },
      };
    case "wrongAnswerExplanation":
      return {
        shortFeedback: "先把這題拆成一個小規則，再試一次。",
        whyWrong: request.context.correctAnswer
          ? `先對照正確答案 ${request.context.correctAnswer} 與題目中的關鍵線索。`
          : "先找出題目要考的規則，再檢查答案是否符合。",
        nextHint: request.context.explanation || "把答案代回原句讀一次，再重新作答。",
        tryAgain: true,
        staffEscalationNeeded: false,
      };
    case "teacherFeedbackDraft":
      return {
        teacherSummary: "學生需要先釐清題目線索與規則，再重試原題。",
        studentFacingFeedback: "先別急，我們先圈出題目的關鍵字，再把答案代回句子檢查一次。",
        recommendedNextAction: "請學生用自己的話說一次規則，再完成一題同類題。",
      };
    case "volunteerReplyCoach":
      return {
        summary: "學生需要一個短步驟與鼓勵，而不是直接得到答案。",
        studentFacingFeedback: "你已經找到卡點了。先看題目的關鍵字，再試著排除一個不合理的答案。",
        recommendedNextAction: "鼓勵學生說出判斷依據，再確認是否需要老師補充規則。",
      };
    default:
      return {
        summary: "English+ 先給你一個簡短提示，稍後可以再請老師或志工協助。",
        supportLevel: "tryAgain",
        recommendedNextAction: "先看提示，再試一次。",
      };
  }
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

function jsonResponse(body, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...CORS_HEADERS,
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      ...extraHeaders,
    },
  });
}

export {
  accountDeletionContext,
  accountDeletionJobProgress,
  accountDeletionJobWrite,
  accountDeletionMetricWrite,
  accountDeletionPhase,
  accountDeletionPreview,
  aiQuotaPolicy,
  aiTaskCost,
  assertAiTaskRole,
  evidenceQuotaSnapshot,
  createClassroom,
  deleteClassroom,
  discoverAccountDeletionSummary,
  enforceEvidenceQuota,
  ensureLegacyClassroomAccount,
  executeAccountDeletion,
  generateClassCode,
  joinClassroom,
  getVolunteerInviteCode,
  leaveClassroom,
  leaveVolunteerService,
  listClassroomStudents,
  listClassroomVolunteers,
  listClassroomsForUser,
  listVolunteerServices,
  membershipIsActiveDocument,
  normalizeEvidenceTicketRequest,
  normalizeAdminApplicationQuery,
  normalizeAdminReviewRequest,
  normalizeAccountDeletionRequest,
  normalizeAiQuotaCommand,
  normalizeClassroomCode,
  normalizeClassroomCreateRequest,
  normalizeClassroomJoinRequest,
  normalizeClassroomUpdateRequest,
  normalizeOutput,
  normalizeRequest,
  personalScopeIdForUid,
  processClassStudentDataBatch,
  processLegacySupportMessageBatch,
  processOwnedClassBatch,
  reserveAiQuota,
  quotaDecision,
  quotaStateForDate,
  filterVolunteerApplications,
  reviewTransitionAllowed,
  requireRecentAuthentication,
  resetClassroomCode,
  resetVolunteerInviteCode,
  requestVolunteerService,
  reviewVolunteerService,
  selectExpiredReviewedApplications,
  signUploadTicket,
  stageAccountDeletionSummary,
  summarizeVolunteerApplications,
  verifyUploadTicket,
  updateClassroom,
  volunteerServiceSummaryFromFields,
};
