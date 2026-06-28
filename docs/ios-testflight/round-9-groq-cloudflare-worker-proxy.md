# Round 9 - Groq + Cloudflare Worker AI Proxy

## Decision

English+ no longer uses the OpenRouter/Firebase Cloud Functions path as the active AI route.

Active AI route:

```text
iOS App -> Cloudflare Worker -> Groq Chat Completions
```

Firebase remains responsible for:

```text
Auth
Firestore class membership
Firestore learning/support sync
```

Cloudflare Worker is responsible for:

```text
Daily mission generation
Wrong-answer explanations
Emotional support
Teacher feedback drafts
Volunteer reply coaching
Progress summaries
```

## Why This Route

- It avoids Firebase Blaze for the AI proxy.
- It keeps `GROQ_API_KEY` out of the iOS app.
- It gives the prototype a real AI model route instead of local-only mock output.
- Groq free-tier models can handle short English+ responses quickly.

## Repo Paths

```text
workers/englishplus-ai-proxy/
  package.json
  wrangler.toml
  src/index.js
  README.md

ios/EnglishPlus/EnglishPlus/Services/RemoteAIService.swift
ios/EnglishPlus/EnglishPlus/Info.plist
```

## Worker Endpoints

```text
GET /health
POST /ai
```

The iOS app posts a Firebase-callable-style envelope:

```json
{
  "data": {
    "taskType": "dailyMission",
    "classId": "YILAN-CHENGZHI-8A",
    "studentUid": "firebase-auth-uid",
    "sessionId": "daily-mission-firebase-auth-uid",
    "qualityMode": "free",
    "locale": "zh-TW",
    "context": {
      "moodScore": 3,
      "availableTimeLevel": 4,
      "wantsChallenge": true,
      "preferredQuestionTypes": ["fillBlank", "cloze", "translation"]
    }
  }
}
```

The Worker returns:

```json
{
  "result": {
    "ok": true,
    "fallbackUsed": false,
    "taskType": "dailyMission",
    "qualityMode": "free",
    "modelUsed": "llama-3.1-8b-instant",
    "output": {
      "summary": "今天先完成三題短任務。",
      "mission": {
        "track": "steady",
        "targetCorrectCount": 3,
        "recommendedMinutes": 8,
        "questionPlan": [
          {
            "type": "fillBlank",
            "difficulty": "core",
            "targetCorrect": 1
          }
        ]
      }
    },
    "usage": {
      "promptTokens": 0,
      "completionTokens": 0,
      "totalTokens": 0
    },
    "requestId": "worker-generated-or-groq-id"
  }
}
```

## Model Defaults

```text
GROQ_DEFAULT_MODEL = llama-3.1-8b-instant
GROQ_QUALITY_MODEL = llama-3.3-70b-versatile
```

## Deployment

From the repo root:

```bash
cd workers/englishplus-ai-proxy
npx wrangler login
npx wrangler secret put GROQ_API_KEY
npx wrangler deploy
```

Do not paste the Groq key into chat, GitHub, Swift files, `.dev.vars`, or docs.

## iOS Worker URL

`Info.plist` now contains:

```text
ENGLISHPLUS_AI_PROXY_URL
```

Initial placeholder:

```text
https://englishplus-ai-proxy.YOUR_WORKERS_SUBDOMAIN.workers.dev/ai
```

After Cloudflare deploy, replace it with the actual Worker URL:

```text
https://englishplus-ai-proxy.<your-workers-subdomain>.workers.dev/ai
```

If the placeholder remains, iOS automatically falls back to local AI support and will not crash.

## Verification

Windows-side validation:

```bash
python scripts/validate_groq_cloudflare_proxy.py
node --check workers/englishplus-ai-proxy/src/index.js
```

Existing iOS/Firebase validations should still pass:

```bash
python scripts/validate_firebase_sync_ai_readiness.py
python scripts/validate_round7_ai_service_contract.py
python scripts/validate_ios_parity_round_8_action_package.py
```

## Mac Handoff

Mac Codex should:

1. Pull latest `main`.
2. Add `GoogleService-Info.plist` to the app target if not already added.
3. Add Firebase iOS SDK products.
4. Confirm `Info.plist` has the deployed `ENGLISHPLUS_AI_PROXY_URL`.
5. Build on simulator.
6. Test the three Firebase Auth accounts.
7. Archive/TestFlight only after build passes.

Mac Codex should not:

- Use OpenRouter.
- Add `GROQ_API_KEY` to the app.
- Commit `GoogleService-Info.plist`.
- Upgrade Firebase Blaze.
