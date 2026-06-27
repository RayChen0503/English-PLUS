# Round 5 - OpenRouter AI Proxy With Firebase Cloud Functions

This round defines the real AI path for the future English+ iOS/TestFlight app. The chosen architecture is:

```text
iOS App -> Firebase Callable Function -> OpenRouter -> Firebase Callable Function -> iOS App
```

The iOS app must not store the OpenRouter production API key. All OpenRouter calls go through Firebase Cloud Functions.

## Confirmed Decision

| Item | Decision |
| --- | --- |
| AI proxy backend | Firebase Cloud Functions |
| Firebase project ID | `englishplus-testflight` |
| iOS Bundle ID | `com.englishplus` |
| OpenRouter key location | Cloud Functions Secret Manager only |
| Default free model route | `openrouter/free` |
| Optional quality route | `openrouter/auto` |
| iOS call style | HTTPS Callable Function |

Why callable functions:

- Firebase Callable Functions automatically include Firebase Authentication tokens when called from supported Firebase client SDKs.
- The backend can check the signed-in user, role, class membership, and request type before calling OpenRouter.
- The app can receive a structured response instead of raw model text.
- App Check can be enforced later to reduce abuse from non-app clients.

## Current External API Facts

OpenRouter chat completions currently use:

```text
POST https://openrouter.ai/api/v1/chat/completions
Authorization: Bearer <OPENROUTER_API_KEY>
Content-Type: application/json
```

The request uses `messages`, `model`, and other chat completion parameters. OpenRouter documents `openrouter/free` as a free-model router and `openrouter/auto` as an automatic model router.

Firebase Cloud Functions secrets should use Secret Manager-backed parameters. The secret value is bound only to functions that need it.

## Model Strategy

### Default For TestFlight

Use:

```text
openrouter/free
```

This keeps the prototype low-cost while proving that the app is using a real AI path.

Expected tradeoffs:

- Free model availability changes.
- Output quality may vary.
- Rate limits may be lower.
- The selected model can change per request.

### Quality Upgrade Mode

Use:

```text
openrouter/auto
```

This should be behind a server-side switch because it may route to paid models. Recommended first quality setting:

```json
{
  "model": "openrouter/auto",
  "plugins": [
    {
      "id": "auto-router",
      "cost_quality_tradeoff": 3
    }
  ]
}
```

This favors quality more than the default while still considering cost. Before real students use it broadly, confirm budget and usage limits.

## Callable Function Name

Recommended deployed function:

```text
englishPlusAiProxy
```

Recommended region:

```text
asia-east1
```

Reason: Taiwan users are closer to Asia regions than US regions. The exact region can be changed later based on Firebase project availability and latency testing.

## Request Contract

The iOS app sends:

```json
{
  "taskType": "dailyMission",
  "classId": "YILAN-CHENGZHI-8A",
  "studentUid": "firebase-auth-uid",
  "sessionId": "2026-06-10-student-uid-daily",
  "qualityMode": "free",
  "locale": "zh-TW",
  "context": {
    "moodScore": 3,
    "availableTimeLevel": 4,
    "wantsChallenge": true,
    "preferredQuestionTypes": ["multipleChoice", "cloze", "translation"],
    "recentAccuracy": 0.62,
    "recentWeakSkills": ["past-tense", "reading-inference"]
  }
}
```

Allowed `taskType` values:

| Task | Student | Teacher | Volunteer | Purpose |
| --- | --- | --- | --- | --- |
| `dailyMission` | yes | yes | no | Build today's learning mission after mood check |
| `wrongAnswerExplanation` | yes | yes | yes | Explain a wrong answer in learner-friendly language |
| `emotionalSupport` | yes | yes | yes | Give low-pressure support and next action |
| `teacherFeedbackDraft` | no | yes | no | Draft teacher feedback for a student |
| `volunteerReplyCoach` | no | yes | yes | Help volunteers reply clearly and safely |
| `progressSummary` | yes | yes | no | Summarize progress for student or teacher view |

## Response Contract

The backend returns a normalized envelope:

```json
{
  "ok": true,
  "taskType": "dailyMission",
  "modelUsed": "openrouter/free-selected-model",
  "qualityMode": "free",
  "output": {
    "summary": "Start with one confidence question, then two cloze questions.",
    "mission": {
      "track": "repair",
      "targetCorrectCount": 3,
      "recommendedMinutes": 8,
      "questionPlan": [
        {
          "type": "multipleChoice",
          "difficulty": "foundation",
          "targetCorrect": 1
        },
        {
          "type": "cloze",
          "difficulty": "core",
          "targetCorrect": 2
        }
      ]
    }
  },
  "usage": {
    "promptTokens": 0,
    "completionTokens": 0,
    "totalTokens": 0
  },
  "requestId": "function-generated-id"
}
```

If AI fails, return a safe fallback:

```json
{
  "ok": false,
  "fallbackUsed": true,
  "errorCode": "AI_UNAVAILABLE",
  "output": {
    "summary": "AI is temporarily unavailable. Use a short repair mission.",
    "mission": {
      "track": "repair",
      "targetCorrectCount": 3,
      "recommendedMinutes": 8
    }
  }
}
```

The iOS app should never show raw backend errors to students.

## Required Authorization Checks

The function must check:

1. The user is signed in through Firebase Auth.
2. `classes/{classId}/members/{uid}` exists and is active.
3. The member role is allowed to call the requested `taskType`.
4. Student requests can only use their own `studentUid`.
5. Teacher requests are limited to their own classes.
6. Volunteer requests are limited to assigned students or assigned support threads.

The proxy should not rely only on client-provided role data.

## Privacy Rules For AI Prompts

Before sending anything to OpenRouter:

- Send only the minimum learning context needed.
- Prefer `studentUid` or pseudonymous identifiers over real names.
- Do not send phone numbers, emails, school IDs, addresses, guardian data, or raw private notes.
- For mood support, send scores and short category labels instead of long personal diary text.
- Store a compact AI summary in Firestore only when it helps the product flow.
- Do not store raw OpenRouter responses if they contain sensitive student text.

## Safety Rules For Emotional Support

English+ is not a therapy app. AI emotional support should:

- Validate the student's feeling in plain language.
- Suggest one small next learning action.
- Encourage asking a teacher or volunteer when the student is stuck.
- Avoid diagnosis, clinical claims, or medical advice.
- Escalate to teacher review if the text suggests self-harm, harm to others, abuse, or immediate danger.

Recommended escalation output:

```json
{
  "supportLevel": "teacherReview",
  "studentMessage": "??毀蝧?隢?葦?靽∩遙?之鈭箔?韏瑞??辣鈭?,
  "staffAlert": "Student response needs adult review before continuing."
}
```

## Prompt Templates

### Daily Mission

System:

```text
You are English+, a rural junior-high English learning companion. Create a short, low-pressure daily mission. Use Traditional Chinese for student-facing text. Do not mention internal routing, API, or model details.
```

User context:

```json
{
  "moodScore": 3,
  "availableTimeLevel": 4,
  "wantsChallenge": true,
  "preferredQuestionTypes": ["cloze", "translation"],
  "recentAccuracy": 0.62,
  "recentWeakSkills": ["past-tense"]
}
```

Expected JSON output:

```json
{
  "track": "repair | steady | challenge",
  "summary": "student-facing summary",
  "targetCorrectCount": 3,
  "recommendedMinutes": 8,
  "questionPlan": [
    {
      "type": "cloze",
      "difficulty": "core",
      "targetCorrect": 2
    }
  ]
}
```

### Wrong Answer Explanation

Return:

```json
{
  "shortFeedback": "student-facing sentence",
  "whyWrong": "simple reason",
  "nextHint": "one small hint",
  "tryAgain": true,
  "staffEscalationNeeded": false
}
```

### Teacher Feedback Draft

Return:

```json
{
  "teacherSummary": "private teacher-facing summary",
  "studentFacingFeedback": "encouraging feedback",
  "recommendedNextAction": "one concrete action"
}
```

## Firestore Writes From Proxy

The proxy may write:

```text
classes/{classId}/students/{studentUid}/dailyMissions/{missionId}
classes/{classId}/students/{studentUid}/learningEvents/{eventId}
classes/{classId}/supportThreads/{threadId}/messages/{messageId}
classes/{classId}/reports/{reportId}
```

Rules:

- Write only normalized results.
- Add `source: "aiProxy"`.
- Add `modelUsed`, `qualityMode`, and token usage when available.
- Do not store `OPENROUTER_API_KEY`.
- Do not store raw prompt text unless a future privacy review approves it.

## Rate Limits

Recommended first limits for TestFlight:

| Role | Limit |
| --- | --- |
| Student | 20 AI calls per day |
| Teacher | 80 AI calls per day |
| Volunteer | 50 AI calls per day |

Store counters in:

```text
classes/{classId}/aiUsage/{yyyy-MM-dd}_{uid}
```

Counter fields:

```json
{
  "uid": "firebase-auth-uid",
  "dateKey": "2026-06-10",
  "role": "student",
  "callCount": 3,
  "tokenTotal": 1200,
  "updatedAt": "serverTimestamp"
}
```

## Files Added In This Round

- `firebase/openrouter-ai-proxy.example.ts`
- `firebase/openrouter-ai-proxy.schema.json`
- `firebase/openrouter-ai-proxy.secret.local.example`

These files are reference drafts. They are not deployed from this Windows machine.

## Mac Setup Order

1. Confirm Firebase project `englishplus-testflight` exists.
2. Initialize Cloud Functions in the future Firebase project.
3. Choose TypeScript and Node.js 20 or newer.
4. Copy logic from `openrouter-ai-proxy.example.ts` into `functions/src/index.ts`.
5. Set the secret:

```bash
firebase functions:secrets:set OPENROUTER_API_KEY
```

6. For local emulator testing, create `functions/.secret.local` based on the example file.
7. Run Functions emulator.
8. Test callable requests with signed-in Firebase Auth test users.
9. Deploy only after role checks, rate limits, and fallback output are verified.

## References

- OpenRouter chat completion API: https://openrouter.ai/docs/api/api-reference/chat/send-chat-completion-request
- OpenRouter free models router: https://openrouter.ai/docs/guides/routing/routers/free-models-router
- OpenRouter auto router: https://openrouter.ai/docs/guides/routing/routers/auto-router
- OpenRouter app attribution headers: https://openrouter.ai/docs/app-attribution
- Firebase callable functions: https://firebase.google.com/docs/functions/callable
- Firebase Functions secrets: https://firebase.google.com/docs/functions/config-env
- Firebase ID token verification: https://firebase.google.com/docs/auth/admin/verify-id-tokens
- Firebase pricing reference: https://firebase.google.com/pricing
