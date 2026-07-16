# STORE-0 competition freeze and environment isolation

Recorded on 2026-07-16 (Asia/Taipei). This document contains deployment
identifiers and hashes only. It intentionally contains no secret values.

## Immutable competition baseline

- Commit: `1207a359708b8d83bec867bfdec5a8bdd5d229ac`
- Annotated tag: `maic-competition-build-52`
- Protection branch: `release/maic-2026-build-52`
- App Store work branch: `codex/app-store-release-1.0`
- TestFlight build: `1.0 (52)`
- Public group: `English+公測`
- Public link: `https://testflight.apple.com/join/xTWGUg3f`

The tag and protection branch are local until the user explicitly approves a
remote push. Existing `main` and the public TestFlight group are unchanged.

## Competition deployment fingerprint

### Firebase

- Project: `englishplus-testflight`
- Firestore rules source SHA-256:
  `1C3C1C4F08383B921130D5C9220F3FAC8AA0052BD7E5CE71F287972A3F7462B7`
- Firestore indexes source SHA-256:
  `C9B51F1E7A73DA26B87152CBF0A6A43A031FB6900E8CB2A86FCE50548B81D491`
- Firebase deployment config SHA-256:
  `825D12A45776A1C3F7A31C28D9C440734D6EB8F9A5B184A6C32C9423ADBE3C92`

### Cloudflare Worker

- Worker: `englishplus-ai-proxy`
- URL: `https://englishplus-ai-proxy.englishplus-ray.workers.dev`
- Recorded version: `5aa866c5-743e-4349-85ae-26d179c36e06`
- Recorded at: `2026-07-14T19:00:12Z`
- Health: `ok=true`, provider `groq`, model `llama-3.1-8b-instant`, quota mode `internal`
- Wrangler source SHA-256:
  `8A64D7F3BEC9A47F19BF6ECECEFB4229E53FB5BD98550207D1A56B4711997728`
- Configured secret names:
  - `EVIDENCE_UPLOAD_SIGNING_SECRET`
  - `FIREBASE_SERVICE_ACCOUNT_EMAIL`
  - `FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY`
  - `FIREBASE_WEB_API_KEY`
  - `GROQ_API_KEY`

### R2

- Bucket: `englishplus-volunteer-evidence`
- Region: APAC
- Storage class: Standard
- Snapshot: 8 objects, 9.78 MB
- Incomplete multipart uploads: abort after 7 days
- `volunteer-evidence/`: delete after 90 days

### Administrator website

- URL: `https://englishplus-testflight.firebaseapp.com`
- Live and local HTML SHA-256:
  `D716EA6CCCD2077D5616A6ABDFDB0820E679B9E773B41CD15388B15D657C13D5`
- Live CSS: `assets/index-BgkTZOBR.css`
- Live JavaScript: `assets/index-BQsBLfXp.js`

## New environment boundary

| Surface | Competition | Production |
| --- | --- | --- |
| Xcode configuration | `Competition` | `Release` |
| Xcode scheme | `EnglishPlusCompetition` | `EnglishPlus` |
| Firebase project | `englishplus-testflight` | `englishplus-production` |
| Worker | `englishplus-ai-proxy` | `englishplus-ai-proxy-production` |
| R2 bucket | `englishplus-volunteer-evidence` | `englishplus-volunteer-evidence-production` |
| Admin build mode | `competition` | `production` |

Runtime and CI both validate the expected Firebase project and Worker host.
Production does not fall back to the legacy competition plist or mock services.

## Commands and release guard

Competition archive:

```text
Scheme: EnglishPlusCompetition
ENGLISHPLUS_CI_ENVIRONMENT=competition
Secret: GOOGLE_SERVICE_INFO_PLIST_BASE64_COMPETITION
```

Production archive:

```text
Scheme: EnglishPlus
ENGLISHPLUS_CI_ENVIRONMENT=production
Secret: GOOGLE_SERVICE_INFO_PLIST_BASE64_PRODUCTION
```

Firebase commands must always use an explicit alias and config:

```text
firebase deploy --project competition --config firebase.competition.json
firebase deploy --project production --config firebase.production.json
```

Worker commands must always name the environment:

```text
wrangler deploy
wrangler deploy --env production
```

## External actions intentionally pending

1. Verify Xcode Cloud branch/tag start conditions before pushing the snapshot refs.
2. Push the tag and protection branch only after explicit user approval.
3. Create `englishplus-production`, its iOS/Web apps and production credentials.
4. Create the production R2 bucket and inject production Worker secrets.
5. Deploy production Rules, indexes, Worker and administrator website.
6. Create the App Store Connect group `AppStore RC`; do not add build 52 or
   alter `English+公測`.

None of these external actions were performed during the local isolation pass.
