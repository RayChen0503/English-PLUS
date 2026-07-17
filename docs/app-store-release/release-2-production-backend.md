# RELEASE-2 production backend deployment

Prepared on 2026-07-17 (Asia/Taipei).

## Objective

Deploy and verify the App Store production backend without changing any MAIC
competition resource. This release covers Firestore, Rules, indexes, the AI
gateway, volunteer evidence storage and the private administrator website. It
does not push the Git branch, trigger Xcode Cloud, assign a TestFlight build or
submit an App Store version.

## Production resources

| Resource | Production identity |
| --- | --- |
| Firebase project | `englishplus-production` |
| Firestore database | `(default)`, `asia-east1`, deletion protection enabled |
| Firebase Hosting | `englishplus-production.web.app` and `englishplus-production.firebaseapp.com` |
| Cloudflare Worker | `englishplus-ai-proxy-production` |
| Worker version | `83577444-d957-4514-ade7-2964350f4600` |
| AI provider | Groq through the Worker; no provider key is stored in the app |
| R2 evidence bucket | `englishplus-volunteer-evidence-production` |
| Administrator account | `englishplus.tw@gmail.com`, Firebase custom claim `admin: true` |
| Backend service account | `englishplus-production-backend@englishplus-production.iam.gserviceaccount.com` |

The service account has only the backend roles needed by the current Worker:
`roles/datastore.user` and `roles/firebaseauth.admin`. Its key, the Groq key
and all Worker secrets are stored outside Git. The administrator chooses their
password through Firebase's official setup flow; the repository never receives
or stores it.

## Deployment completed

- Cloud Firestore API was enabled for `englishplus-production`.
- Firestore Rules and composite indexes from `firebase.production.json` were
  deployed explicitly to the production project.
- The production Worker was deployed with public quota mode, production-only
  rate-limit namespaces, a daily maintenance schedule and four encrypted
  secrets: evidence signing, Firebase service-account email, Firebase
  service-account private key and Groq API key.
- R2 lifecycle deletes evidence after 90 days and abandons incomplete multipart
  uploads after 7 days. Application-level review cleanup remains enforced by
  the Worker.
- The administrator website was built with production Firebase configuration,
  deployed to production Hosting and protected by CSP, frame, referrer,
  permissions and content-type headers.
- `englishplus.tw@gmail.com` was created in production Firebase Authentication,
  granted `admin: true`, and sent Firebase's official password setup email.

## Production smoke test

The disposable-account production smoke test completed with **21 passed and 0
failed**, followed by account, Firestore profile and R2 object cleanup.

Verified behavior:

- Worker health returns HTTP 200 with provider `groq` and public quota mode.
- Unauthenticated AI, administrator and evidence requests return HTTP 401.
- A verified student can read their own profile but cannot read another
  student's profile.
- A student cannot invoke teacher-only AI tasks or upload volunteer evidence.
- Real Groq daily-mission and wrong-answer requests both returned HTTP 200 with
  `fallbackUsed=false` using `llama-3.1-8b-instant`.
- An approved test volunteer obtained an evidence ticket, uploaded to the
  production R2 binding and the test object was removed afterward.

The production administrator's real password is never generated, read or
stored by the repository. The owner completes the official reset link and then
performs the final browser login smoke test.

## Local regression verification

- Node-based Worker suites passed: **4 files, 35 tests**.
- Cloudflare Workers runtime suites passed: **5 files, 41 tests**.
- The runtime suite was staged to an ASCII-only temporary directory before it
  ran. Cloudflare's open-beta Vitest pool currently fails to resolve its own
  `cloudflare:test-internal` virtual module when this Windows repository is
  reached through the non-ASCII `D:\公民行動` path. The identical locked source,
  configuration and dependencies pass from the ASCII path; this is a local
  tool-path limitation rather than an application or production-runtime error.
- The disposable production smoke test remains the release authority for live
  Firebase, Firestore, Groq, Worker and R2 integration behavior.

## Competition isolation

The following frozen competition identities were checked after deployment:

- Tag `maic-competition-build-52` and branch
  `release/maic-2026-build-52` both resolve to
  `1207a359708b8d83bec867bfdec5a8bdd5d229ac`.
- Competition Worker `englishplus-ai-proxy` health returns HTTP 200.
- Competition Hosting `englishplus-testflight.web.app` returns HTTP 200.
- Competition Firebase project remains `englishplus-testflight`.
- Competition Worker, R2 bucket, TestFlight group, build 53 and public link were
  not changed or redeployed.

## Release boundary

RELEASE-2 finishes with a local release-branch commit only. A later explicit
release gate controls GitHub push, Xcode Cloud and candidate-build creation.
Production builds must remain outside the competition public testing group.
