# RELEASE-0 competition freeze and production boundary

Recorded on 2026-07-17 (Asia/Taipei). This file contains identifiers and
hashes only. It contains no passwords, API keys, service-account keys or
Firebase configuration payloads.

The machine-readable source of truth is
`docs/app-store-release/release-environment-lock.json`.

## Immutable competition lane

- Frozen source commit: `1207a359708b8d83bec867bfdec5a8bdd5d229ac`
- Annotated source tag: `maic-competition-build-52`
- Protection branch: `release/maic-2026-build-52`
- Internal baseline build: `1.0 (52)`
- public TestFlight build: `1.0 (53)`
- Public group: `English+公測`
- Public link: `https://testflight.apple.com/join/xTWGUg3f`

Build 53 is the external-testing rebuild used by judges. It was built from the
same frozen source represented by the build-52 tag and protection branch.
Release work must not replace build 53, remove it from `English+公測`, change
the public link, or assign a production candidate to that group.

## Production release lane

- Completed STORE source: `5ec3f9f981ab615697c52fcb2e9924ad7e678c93`
- Local release branch: `codex/app-store-production-release`
- Production candidate floor: `1.0 (54)`
- App bundle identifier: `com.englishplus`
- Release scheme: `EnglishPlus`
- Release environment: `production`

The STORE source is already on `origin/main`. The Xcode Cloud run associated
with `5ec3f9f` failed before a candidate archive was produced because the
production Firebase configuration was intentionally absent. No build 54 or
later has been uploaded from this source.

## Competition deployment fingerprint

### Firebase

- Project: `englishplus-testflight`
- Project number: `106475996050`
- State observed on 2026-07-17: `ACTIVE`
- Firestore rules source SHA-256:
  `1C3C1C4F08383B921130D5C9220F3FAC8AA0052BD7E5CE71F287972A3F7462B7`
- Firestore indexes source SHA-256:
  `C9B51F1E7A73DA26B87152CBF0A6A43A031FB6900E8CB2A86FCE50548B81D491`
- Firebase deployment config SHA-256:
  `825D12A45776A1C3F7A31C28D9C440734D6EB8F9A5B184A6C32C9423ADBE3C92`

The authenticated Firebase project listing contained no
`englishplus-production` project on 2026-07-17.

### Cloudflare Worker

- Worker: `englishplus-ai-proxy`
- URL: `https://englishplus-ai-proxy.englishplus-ray.workers.dev`
- Current version: `5aa866c5-743e-4349-85ae-26d179c36e06`
- Current deployment: `ac37a7c4-7f36-459b-8ac9-96903b65a99a`
- Health observed on 2026-07-17: `ok=true`, provider `groq`, model
  `llama-3.1-8b-instant`, quota mode `internal`
- Wrangler source SHA-256:
  `8A64D7F3BEC9A47F19BF6ECECEFB4229E53FB5BD98550207D1A56B4711997728`
- Configured secret names:
  - `EVIDENCE_UPLOAD_SIGNING_SECRET`
  - `FIREBASE_SERVICE_ACCOUNT_EMAIL`
  - `FIREBASE_SERVICE_ACCOUNT_PRIVATE_KEY`
  - `FIREBASE_WEB_API_KEY`
  - `GROQ_API_KEY`

The authenticated Cloudflare deployment query returned error `10007` for
`englishplus-ai-proxy-production` on 2026-07-17 because that Worker does not
yet exist.

### R2

- Competition bucket: `englishplus-volunteer-evidence`
- Region: APAC
- Storage class: Standard
- Incomplete multipart uploads: abort after 7 days
- `volunteer-evidence/`: delete after 90 days

The authenticated bucket listing contained only the competition bucket on
2026-07-17. `englishplus-volunteer-evidence-production` does not yet exist.

### Administrator website

- URL: `https://englishplus-testflight.firebaseapp.com`
- Live and local HTML SHA-256:
  `D716EA6CCCD2077D5616A6ABDFDB0820E679B9E773B41CD15388B15D657C13D5`
- Live CSS: `assets/index-BgkTZOBR.css`
- Live JavaScript: `assets/index-BQsBLfXp.js`

## Locked environment boundary

| Surface | Competition | Production |
| --- | --- | --- |
| Xcode configuration | `Competition` | `Release` |
| Xcode scheme | `EnglishPlusCompetition` | `EnglishPlus` |
| TestFlight build | `53` in `English+公測` | `54+`, never in `English+公測` |
| Firebase project | `englishplus-testflight` | `englishplus-production` |
| Worker | `englishplus-ai-proxy` | `englishplus-ai-proxy-production` |
| R2 bucket | `englishplus-volunteer-evidence` | `englishplus-volunteer-evidence-production` |
| Admin host | `englishplus-testflight.firebaseapp.com` | `englishplus-production.firebaseapp.com` |
| AI quota | `internal` | `public` |

Runtime and CI both reject a Firebase project or Worker host mismatch.
Production does not fall back to the competition plist, mock services or
competition deployment targets.

## Mandatory release guard

Run before every production deployment, candidate build and App Store action:

```text
python scripts/validate_release0_competition_guard.py
python scripts/validate_store0_environment_isolation.py
```

Firebase commands must always use the explicit production alias and config:

```text
firebase deploy --project production --config firebase.production.json
```

Cloudflare commands must always name the production environment:

```text
wrangler deploy --env production
```

The following actions are prohibited:

1. Deploying release changes through the default or `competition` Firebase alias.
2. Running release Worker deployment without `--env production`.
3. Adding build 54 or later to `English+公測`.
4. Removing build 53 or changing the competition public link.
5. Storing production plist, `.env.production`, review passwords or private
   keys in Git.

## RELEASE-0 completion boundary

RELEASE-0 creates the local release branch, corrects the source/build record,
records the current competition fingerprint and installs a repeatable guard.
It does not create production cloud resources, deploy anything, push GitHub,
trigger Xcode Cloud or open App Store Connect.
