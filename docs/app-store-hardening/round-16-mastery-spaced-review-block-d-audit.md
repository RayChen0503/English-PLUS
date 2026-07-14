# Round 16 - Mastery, spaced review, and Block D audit

Status: In progress - awaiting the final macOS isolated gate

Date: 2026-07-14

Branch: `codex/app-store-hardening-d`

Release boundary: the implementation and production backend are validated on
the hardening branch. The branch must not merge to `main` until the current
commit passes the complete macOS GitHub Actions gate.

This report will be finalized only after the Round 13-16 validators, Swift
acceptance suite, critical UI suite, Worker tests, administrator portal checks,
Firebase Emulator permissions, and the macOS isolated gate all pass.

## Round 13-16 scope

- Round 13: repository boundaries, offline recovery, and retry behavior.
- Round 14: XCTest, critical-role UI tests, Emulator coverage, and CI gates.
- Round 15: question-bank curriculum balance, duplicate defense, and answer
  distribution quality.
- Round 16: shared mastery, wrong-answer review, spaced repetition, and
  teacher-visible assignment progress.

## Round 16 implementation

- Shared skill mastery is updated by free practice, repair practice, daily
  missions and teacher assignments without creating separate progress silos.
- First-attempt correctness, total attempts, current streak, mastery band and
  next-review time are persisted in personal and class-scoped projections.
- The spaced-repetition engine uses 1, 3, 7, 14 and 30-day intervals and keeps
  wrong answers immediately due for repair.
- Review selection excludes the last question and its semantic duplicates.
- Teacher assignment reporting includes partial progress, retry history and
  first-try accuracy instead of showing only a final completion flag.
- Firestore Rules protect both personal and class mastery paths, prevent
  identity rewrites or inflated counters, and preserve the class visibility
  boundary.

## Block D final deployment audit

- Cloudflare Worker version `a204be36-8e3c-4644-9ef5-de80c31cc851` is deployed
  at `https://englishplus-ai-proxy.englishplus-ray.workers.dev` with the daily
  `17 3 * * *` cleanup schedule and retained production secrets.
- Production Firestore Rules and indexes are deployed to
  `englishplus-testflight`; the Rules deployment emits no warnings.
- The administrator portal is deployed at
  `https://englishplus-testflight.firebaseapp.com`. Its `web.app` alias is
  canonicalized to the same-origin Firebase Auth host.
- The portal intentionally uses an Email-only administrator login. It does not
  expose the previously unreliable Google administrator path, and this does
  not change Google or Apple sign-in inside the iOS App.
- `englishplus.tw@gmail.com` exists in Firebase Authentication with the
  `admin: true` custom claim. The user completed the password setup and
  confirmed a successful real administrator login on 2026-07-14.
- Application registration remains closed: the portal cannot create ordinary
  accounts, and all review data and evidence endpoints require both a valid
  Firebase ID token and the administrator claim.

## Current verification evidence

- Round 5-16, FIX-A through FIX-G and the Block D preflight validators pass.
- Round 15 confirms all 1,080 ids, 218 semantic families, 36 skills and exact
  answer slots `{0: 270, 1: 270, 2: 270, 3: 270}`.
- Worker Node-compatible tests pass `24/24`; JavaScript syntax validation
  passes. The production Firebase/Groq security smoke suite passes `45/45`.
- Firebase Emulator permission coverage passes `31/31` using Java 21.
- The administrator portal passes `7/7` tests and produces a minified
  production Vite bundle.
- Firebase Functions build and no-emit typecheck both pass.
- The full Cloudflare workerd pool cannot resolve `cloudflare:test-internal`
  from this Windows Unicode workspace. It remains a mandatory macOS CI check,
  not a waived test.

## Evidence awaiting final sign-off

- Swift acceptance: pending the isolated macOS run for the current commit.
- Firebase Emulator: local complete permission matrix passes `31/31`.
- macOS isolated gate: pending the branch push and current-commit run.
- Formal `Status: Passed` and the `16/20` state update are intentionally
  withheld until that gate succeeds.
