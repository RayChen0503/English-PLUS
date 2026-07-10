# English+ current state

> **Read this first at the start of every hardening round.** Keep this file
> concise. It is the working source of truth, not a replacement for the
> round reports.

Last verified: 2026-07-10

## Product in one paragraph

English+ is an iPhone-first English learning app with student, teacher, and
volunteer roles. A student can learn independently, complete a short mood
check-in, receive an adaptive daily mission, practise freely, and ask for
human help on a specific question. Classroom membership is optional: personal
learning must remain usable without joining a class.

## Repository and release safety

- Repository: `RayChen0503/English-PLUS`
- Stable baseline: `main` at `cf5381fea1c595632a897b2fa38076358870ff39`
- Active hardening branch: `codex/app-store-hardening`
- Completed hardening commits:
  - `fdb4d7f` - Round 1 baseline audit
  - `ebfff09` - Round 2 personal and multi-class domain
- Do not merge to `main` or trigger Xcode Cloud until the end of a four-round
  block: 4, 8, 12, 16, and 20.
- Never reset, overwrite, or silently discard user work.

## Non-negotiable product behavior

1. Role selection and explicit sign-in are always shown on a cold launch.
   Do **not** call automatic session restoration from `RootView`; it previously
   skipped role choice and opened the student experience unexpectedly.
2. A new self-service account is a **student in personal mode**. It is not
   automatically enrolled in a demonstration class.
3. A student can belong to multiple classes but selects one active class at a
   time. No active class means personal learning mode.
4. Teachers and authorized class staff may see only records created after the
   student's class `visibilityStartsAt` timestamp. Personal history is not
   imported into a class.
5. Technical implementation details, provider names, mock status, diagnostics,
   API keys, and internal fallback language must not be shown in student,
   teacher, or volunteer UI.
6. User-visible flows must have one clear next action. Avoid duplicate support
   information, duplicate navigation routes, and UI controls that imply an
   action but do nothing.

## What is implemented now

- Student: email/password sign-in and account creation, consent, mood
  check-in, adaptive mission foundation, free practice, learning map,
  assignments, and support threads.
- Teacher and volunteer: class/workspace, shared support relay, replies,
  notification records, assignment and reporting foundations.
- Services: Firebase Auth/Firestore boundaries, local fallbacks, and a
  Cloudflare Worker boundary for Groq-powered AI tasks.
- Round 2 has added account-owned personal learning paths, class membership
  lifecycle data, active-class selection, and draft access rules.

## Current technical constraints

- Firestore rules are draft-only. They are not yet deployed or emulator-tested.
- Swift compilation is not available on this Windows host. Xcode Cloud is the
  release-level verification gate at the agreed checkpoint.
- Existing legacy validators can fail because they assert removed UI or old
  copy. Preserve useful behavioral coverage by replacing them, not by reviving
  obsolete UI.

## Test cadence

- Every round: focused validator(s), relevant existing regressions, type/syntax
  checks, and `git diff --check`.
- Every two rounds: mini regression over affected roles and service contracts.
- Every four rounds: full validator audit, reconcile all failures, then merge
  deliberately and use Xcode Cloud once.
- A round is incomplete until implementation, report, test evidence, and Git
  state agree.

## Fast source map

| Concern | Primary location |
| --- | --- |
| App entry, role and sign-in flow | `ios/EnglishPlus/EnglishPlus/App/RootView.swift`, `AppState.swift` |
| Student flow | `Features/Student/`, `Features/Practice/`, `Features/Support/` |
| Teacher and volunteer flows | `Features/Teacher/`, `Features/Volunteer/` |
| Identity and class selection | `Services/AuthService.swift`, `FirebaseAuthService.swift`, `Models/AppUserProfile.swift` |
| Learning persistence | `Services/FirebaseLearningRepository.swift`, `Data/FirestorePath.swift` |
| Firestore contract | `Models/FirestoreSchema.swift`, `docs/ios-testflight/firebase/firestore.rules.draft` |
| AI boundary | `Services/AIService.swift`, `RemoteAIService.swift`, `AiProxyService.swift` |
| Question data | `Resources/SeedData/question_bank_seed.json`, `Data/SeedData.swift` |
| Hardening evidence | `docs/app-store-hardening/round-*.md`, `scripts/validate_*.py` |

## Next decision gate: Round 3

The next round is identity and staff provisioning. User decision is required
before implementation:

1. Identity providers: Google + Sign in with Apple + email/password (recommended),
   Apple + email/password, or email/password only.
2. Staff provisioning: invitation/admin approval only (recommended), or
   self-registration followed by approval.

## Maintenance rule

After every completed round, update this file only when a current fact,
decision, blocker, branch, or next decision changes. Put full evidence in that
round's report. This keeps future work context compact without losing detail.
