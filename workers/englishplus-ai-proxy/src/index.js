const GROQ_CHAT_COMPLETIONS_URL = "https://api.groq.com/openai/v1/chat/completions";

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
  "Access-Control-Allow-Methods": "GET,POST,OPTIONS",
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

    return jsonResponse({ ok: false, error: "NOT_FOUND" }, 404);
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
