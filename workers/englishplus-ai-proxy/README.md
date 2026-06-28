# English+ Groq AI Proxy

Cloudflare Worker proxy for English+ AI tasks.

The app calls this Worker instead of calling Groq directly:

```text
iOS App -> Cloudflare Worker -> Groq Chat Completions
```

The iOS app must never store `GROQ_API_KEY`.

## Endpoints

```text
GET /health
POST /ai
```

`POST /ai` accepts either the plain `AiProxyRequest` body or the Firebase-callable-style envelope used by the iOS transport:

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

## Local Check

```bash
npm run check
```

## Deploy

Install/login only when you are ready to deploy:

```bash
npx wrangler login
npx wrangler secret put GROQ_API_KEY
npx wrangler deploy
```

Do not commit `.dev.vars`, `.wrangler/`, or any Groq API key.

## Model Defaults

```text
GROQ_DEFAULT_MODEL = llama-3.1-8b-instant
GROQ_QUALITY_MODEL = llama-3.3-70b-versatile
```

The default route is optimized for fast short replies: daily missions, wrong-answer explanations, emotional support, and teacher/volunteer draft suggestions.
