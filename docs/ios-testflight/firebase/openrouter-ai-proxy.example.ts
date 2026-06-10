import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import { randomUUID } from "crypto";

admin.initializeApp();

const OPENROUTER_API_KEY = defineSecret("OPENROUTER_API_KEY");
const OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions";
const DEFAULT_MODEL = "openrouter/free";
const QUALITY_MODEL = "openrouter/auto";
const FUNCTION_REGION = "asia-east1";

type Role = "student" | "teacher" | "volunteer";
type QualityMode = "free" | "quality";
type TaskType =
  | "dailyMission"
  | "wrongAnswerExplanation"
  | "emotionalSupport"
  | "teacherFeedbackDraft"
  | "volunteerReplyCoach"
  | "progressSummary";

interface AiProxyRequest {
  taskType: TaskType;
  classId: string;
  studentUid?: string;
  sessionId?: string;
  qualityMode?: QualityMode;
  locale?: string;
  context?: Record<string, unknown>;
}

interface Membership {
  role: Role;
  active: boolean;
  displayName?: string;
}

const taskRoleAccess: Record<TaskType, Role[]> = {
  dailyMission: ["student", "teacher"],
  wrongAnswerExplanation: ["student", "teacher", "volunteer"],
  emotionalSupport: ["student", "teacher", "volunteer"],
  teacherFeedbackDraft: ["teacher"],
  volunteerReplyCoach: ["teacher", "volunteer"],
  progressSummary: ["student", "teacher"],
};

export const englishPlusAiProxy = onCall(
  {
    region: FUNCTION_REGION,
    secrets: [OPENROUTER_API_KEY],
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "Sign in is required.");
    }

    const data = normalizeRequest(request.data);
    const membership = await loadMembership(data.classId, uid);
    assertTaskAccess(data, uid, membership);

    await assertRateLimit(data.classId, uid, membership.role);

    const messages = buildMessages(data, membership.role);
    const openRouterRequest = buildOpenRouterRequest(data, messages, uid);

    try {
      const openRouterResponse = await callOpenRouter(openRouterRequest);
      const normalized = normalizeOpenRouterResponse(data, openRouterResponse);

      await recordAiUsage(data.classId, uid, membership.role, normalized);

      return normalized;
    } catch (error) {
      const fallback = buildFallbackResponse(data, error);
      await recordAiFailure(data.classId, uid, membership.role, fallback);
      return fallback;
    }
  }
);

function normalizeRequest(raw: unknown): AiProxyRequest {
  if (!raw || typeof raw !== "object") {
    throw new HttpsError("invalid-argument", "Request data is required.");
  }

  const data = raw as Partial<AiProxyRequest>;
  if (!data.taskType || !(data.taskType in taskRoleAccess)) {
    throw new HttpsError("invalid-argument", "Unsupported AI task type.");
  }

  if (!data.classId || !/^[A-Z0-9-]{3,64}$/.test(data.classId)) {
    throw new HttpsError("invalid-argument", "Invalid classId.");
  }

  return {
    taskType: data.taskType,
    classId: data.classId,
    studentUid: safeString(data.studentUid),
    sessionId: safeString(data.sessionId),
    qualityMode: data.qualityMode === "quality" ? "quality" : "free",
    locale: data.locale === "en-US" ? "en-US" : "zh-TW",
    context: sanitizeContext(data.context),
  };
}

async function loadMembership(classId: string, uid: string): Promise<Membership> {
  const snap = await admin
    .firestore()
    .doc(`classes/${classId}/members/${uid}`)
    .get();

  if (!snap.exists) {
    throw new HttpsError("permission-denied", "Class membership is required.");
  }

  const data = snap.data() as Partial<Membership>;
  if (!data.active || !isRole(data.role)) {
    throw new HttpsError("permission-denied", "Active role is required.");
  }

  return {
    role: data.role,
    active: true,
    displayName: safeString(data.displayName),
  };
}

function assertTaskAccess(
  data: AiProxyRequest,
  uid: string,
  membership: Membership
) {
  const allowedRoles = taskRoleAccess[data.taskType];
  if (!allowedRoles.includes(membership.role)) {
    throw new HttpsError("permission-denied", "This role cannot use this AI task.");
  }

  if (membership.role === "student") {
    const requestedStudent = data.studentUid || uid;
    if (requestedStudent !== uid) {
      throw new HttpsError("permission-denied", "Students can only request their own AI tasks.");
    }
  }
}

async function assertRateLimit(classId: string, uid: string, role: Role) {
  const dateKey = new Date().toISOString().slice(0, 10);
  const limit = role === "teacher" ? 80 : role === "volunteer" ? 50 : 20;
  const ref = admin
    .firestore()
    .doc(`classes/${classId}/aiUsage/${dateKey}_${uid}`);

  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = snap.exists ? Number(snap.data()?.callCount ?? 0) : 0;

    if (current >= limit) {
      throw new HttpsError("resource-exhausted", "Daily AI limit reached.");
    }

    tx.set(
      ref,
      {
        uid,
        role,
        dateKey,
        callCount: current + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );
  });
}

function buildMessages(data: AiProxyRequest, role: Role) {
  const system = [
    "You are English+, a rural junior-high English learning companion.",
    "Use Traditional Chinese for student-facing output unless locale is en-US.",
    "Never mention API keys, model routing, backend internals, or implementation details.",
    "Do not diagnose mental health. If risk is high, recommend teacher or trusted adult support.",
    "Return compact JSON only, with no markdown fences.",
  ].join(" ");

  const taskInstruction = getTaskInstruction(data.taskType);

  return [
    { role: "system", content: system },
    {
      role: "user",
      content: JSON.stringify({
        taskType: data.taskType,
        role,
        locale: data.locale,
        instruction: taskInstruction,
        context: data.context ?? {},
      }),
    },
  ];
}

function buildOpenRouterRequest(
  data: AiProxyRequest,
  messages: Array<{ role: string; content: string }>,
  uid: string
) {
  const model = data.qualityMode === "quality" ? QUALITY_MODEL : DEFAULT_MODEL;
  const body: Record<string, unknown> = {
    model,
    messages,
    stream: false,
    temperature: data.taskType === "dailyMission" ? 0.3 : 0.5,
    max_completion_tokens: maxTokensForTask(data.taskType),
    user: uid,
    session_id: data.sessionId ?? `${uid}:${data.taskType}`,
  };

  if (data.qualityMode === "quality") {
    body.plugins = [
      {
        id: "auto-router",
        cost_quality_tradeoff: 3,
      },
    ];
  }

  return body;
}

async function callOpenRouter(body: Record<string, unknown>) {
  const response = await fetch(OPENROUTER_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${OPENROUTER_API_KEY.value()}`,
      "Content-Type": "application/json",
      "HTTP-Referer": "https://englishplus-testflight.local",
      "X-OpenRouter-Title": "English+",
    },
    body: JSON.stringify(body),
  });

  const json = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new HttpsError("unavailable", "OpenRouter request failed.", {
      status: response.status,
      response: json,
    });
  }

  return json;
}

function normalizeOpenRouterResponse(data: AiProxyRequest, response: any) {
  const content = response?.choices?.[0]?.message?.content;
  const parsed = parseJsonObject(content);

  return {
    ok: true,
    fallbackUsed: false,
    taskType: data.taskType,
    qualityMode: data.qualityMode ?? "free",
    modelUsed: safeString(response?.model) ?? "unknown",
    output: parsed ?? { summary: safeString(content) ?? "" },
    usage: {
      promptTokens: Number(response?.usage?.prompt_tokens ?? 0),
      completionTokens: Number(response?.usage?.completion_tokens ?? 0),
      totalTokens: Number(response?.usage?.total_tokens ?? 0),
    },
    requestId: safeString(response?.id) ?? randomUUID(),
  };
}

function buildFallbackResponse(data: AiProxyRequest, error: unknown) {
  const output =
    data.taskType === "dailyMission"
      ? {
          summary: "AI is temporarily unavailable. Start with a short repair mission.",
          mission: {
            track: "repair",
            targetCorrectCount: 3,
            recommendedMinutes: 8,
            questionPlan: [
              {
                type: "multipleChoice",
                difficulty: "foundation",
                targetCorrect: 1,
              },
              {
                type: "cloze",
                difficulty: "core",
                targetCorrect: 2,
              },
            ],
          },
        }
      : {
          summary: "AI is temporarily unavailable. Ask a teacher or volunteer for help.",
          supportLevel: "humanSupport",
        };

  return {
    ok: false,
    fallbackUsed: true,
    taskType: data.taskType,
    qualityMode: data.qualityMode ?? "free",
    errorCode: error instanceof HttpsError ? error.code : "AI_UNAVAILABLE",
    output,
    requestId: randomUUID(),
  };
}

async function recordAiUsage(
  classId: string,
  uid: string,
  role: Role,
  normalized: any
) {
  const dateKey = new Date().toISOString().slice(0, 10);
  await admin
    .firestore()
    .collection(`classes/${classId}/aiEvents`)
    .add({
      uid,
      role,
      dateKey,
      taskType: normalized.taskType,
      ok: normalized.ok,
      fallbackUsed: normalized.fallbackUsed,
      modelUsed: normalized.modelUsed ?? null,
      usage: normalized.usage ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}

async function recordAiFailure(
  classId: string,
  uid: string,
  role: Role,
  fallback: Record<string, unknown>
) {
  await admin
    .firestore()
    .collection(`classes/${classId}/aiEvents`)
    .add({
      uid,
      role,
      taskType: fallback.taskType,
      ok: false,
      fallbackUsed: true,
      errorCode: fallback.errorCode ?? "AI_UNAVAILABLE",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}

function getTaskInstruction(taskType: TaskType): string {
  switch (taskType) {
    case "dailyMission":
      return [
        "Create a short daily English mission.",
        "Return JSON with track, summary, targetCorrectCount, recommendedMinutes, and questionPlan.",
        "Question types may include multipleChoice, fillBlank, cloze, translation, sentenceReorder, reading.",
      ].join(" ");
    case "wrongAnswerExplanation":
      return "Explain why the answer is wrong, give one hint, and encourage a retry. Return JSON.";
    case "emotionalSupport":
      return "Give low-pressure support and one next action. Escalate high-risk content to teacherReview. Return JSON.";
    case "teacherFeedbackDraft":
      return "Draft concise teacher feedback and one next action. Return JSON.";
    case "volunteerReplyCoach":
      return "Help a volunteer write a safe, specific student reply. Return JSON.";
    case "progressSummary":
      return "Summarize progress and recommend one next learning action. Return JSON.";
  }
}

function maxTokensForTask(taskType: TaskType) {
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
  }
}

function sanitizeContext(context: unknown): Record<string, unknown> {
  if (!context || typeof context !== "object") {
    return {};
  }

  const raw = context as Record<string, unknown>;
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
    "attemptCount",
  ]);

  return Object.fromEntries(
    Object.entries(raw)
      .filter(([key]) => allowedKeys.has(key))
      .map(([key, value]) => [key, sanitizeValue(value)])
  );
}

function sanitizeValue(value: unknown): unknown {
  if (typeof value === "string") {
    return value.slice(0, 1200);
  }

  if (Array.isArray(value)) {
    return value.slice(0, 20).map(sanitizeValue);
  }

  if (typeof value === "number" || typeof value === "boolean") {
    return value;
  }

  return null;
}

function parseJsonObject(value: unknown): Record<string, unknown> | null {
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

function safeString(value: unknown): string | undefined {
  return typeof value === "string" && value.trim().length > 0
    ? value.trim()
    : undefined;
}

function isRole(value: unknown): value is Role {
  return value === "student" || value === "teacher" || value === "volunteer";
}
