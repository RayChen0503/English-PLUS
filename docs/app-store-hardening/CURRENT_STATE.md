# English+ current state

> **Read this first at the start of every hardening round.** Keep this file
> concise. It is the working source of truth, not a replacement for the
> round reports.

Last verified: 2026-07-13

## Product in one paragraph

English+ is an iPhone-first English learning app with student, teacher, and
volunteer roles. A student can learn independently, complete a short mood
check-in, receive an adaptive daily mission, practise freely, and ask for
human help on a specific question. Classroom membership is optional: personal
learning must remain usable without joining a class.

## Repository and release safety

- Repository: `RayChen0503/English-PLUS`
- Stable Block B baseline: `main` at `8b1db6c`
- Active Block C branch: `codex/app-store-hardening-c`
- Completed hardening rounds:
  - Round 1 - baseline audit (`round-01-baseline-audit.md`)
  - Round 2 - personal and multi-class domain (`round-02-personal-and-class-domain.md`)
  - Round 3 - multi-provider role onboarding (`round-03-multi-provider-role-onboarding.md`)
  - Round 4 - provider UI and private volunteer review (`round-04-provider-ui-private-volunteer-review.md`)
  - Round 5 - personal learning mode (`round-05-personal-learning-mode.md`)
  - Round 6 - classroom lifecycle (`round-06-classroom-lifecycle.md`)
  - Round 7 - teacher class management (`round-07-teacher-class-management.md`)
  - Round 8 - Firestore synchronization and Block B audit (`round-08-firestore-sync-audit.md`)
  - Round 9 - authenticated AI gateway, quota and monitoring (`round-09-ai-gateway-hardening.md`)
  - Round 10 - executable AI learning and staff actions (`round-10-executable-ai-actions.md`)
  - Round 11 - account deletion and explicit human help
    (`round-11-account-deletion-human-help.md`)
- Hardening progress: **11/20 fully signed off**.
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

- Student: provider-neutral sign-in/account foundation, consent, mood
  check-in, adaptive mission foundation, free practice, learning map,
  assignments, and support threads.
- Teacher and volunteer: class/workspace, shared support relay, replies,
  notification records, assignment and reporting foundations.
- Services: Firebase Auth/Firestore boundaries, local fallbacks, and a
  Cloudflare Worker boundary for Groq-powered AI tasks.
- Round 2 has added account-owned personal learning paths, class membership
  lifecycle data, active-class selection, and draft access rules.
- Round 3 has added Google/Apple/Email identity contracts, provider linking,
  teacher self-registration with a self-declared institution, volunteer
  pending-review applications, and a deterministic Ministry of Education
  institution catalog pipeline. Email verification and password recovery are
  retained.
- Round 4 has added the provider SDK/UI wiring, official Apple and Google
  controls, automatic same-account provider linking, a 3,921-entry institution
  picker, a two-stage volunteer application, private signed R2 evidence
  uploads, and an administrator-only review surface. The Block A final audit
  also verified user-facing quota/retention guidance, failed-upload recovery,
  temporary evidence cleanup, and legal review-state transitions.
- Round 5 has made personal learning a complete authenticated runtime scope:
  check-ins, missions, attempts and learning-flow state restore from personal
  Firestore paths; local fallback data is isolated by UID; and class-only
  assignments or human support are not shown without a class.
- Round 6 has added trusted class creation, teacher-resettable private join
  codes, multi-class joining and switching, safe leaving, legacy membership
  migration, UID-and-class cache isolation, and historical report boundaries.
  The deployed Worker passed authenticated student, teacher and volunteer
  smoke checks at version `de12abab-5cb9-44f8-91e2-33ba859832a2`. Firestore
  Emulator coverage also passes the complete isolated create, join, switch,
  reset-code, leave and rejoin lifecycle.
- Round 7 has made the teacher's selected class a coherent workspace. Its
  roster comes from active memberships rather than support activity, updates
  in real time, clears safely when classes change, and exposes deliberate
  loading, retry and empty states. Teachers can rename only classes they own
  and assign one task either to one selected student or independently to every
  active student in that class. Firestore Rules and Worker version
  `4ee60303-29d4-42fe-ade7-d7ad576d2e7b` are deployed; the authenticated
  production suite passes `26/26` checks and the complete repository validator
  sweep passes `67/67`.
- Round 8 has made the iOS realtime repository, Firestore Rules and deployed
  query indexes one tested contract. Teacher and volunteer replies now use the
  real authenticated identity; students can report assignment progress
  without rewriting assignment scope; post-leave writes and role
  impersonation are denied; and listener queries match Rules exactly. The
  complete validator sweep passes `68/68`, the Emulator matrix passes `16/16`,
  the production Firebase/Worker suite passes `26/26`, and isolated macOS run
  `29236759213` passed a clean iOS Simulator build.
- Round 9 has made every AI request an authenticated, least-privilege server
  decision. Role, class, student and support-thread scope are checked before
  Groq; client-selected quality escalation and request-ID replay are rejected;
  per-user burst and atomic Taipei-day quotas are active in internal mode; and
  iOS degrades to clear local guidance on quota or provider failures. Worker
  version `cf6dfb11-0644-4680-9fb9-f66e86e26996` is deployed. Runtime tests
  pass `15/15`, production Firebase/Groq smoke tests pass `34/34`, the complete
  Python validator sweep passes `69/69`, and isolated macOS run `29241754603`
  passed the clean iOS Simulator build.
- Round 10 has converted AI output into three real action chains. Structured
  recommendations now select and launch exact approved question IDs; wrong
  answers open a finite same-skill repair set across the daily-mission and
  practice tabs; and teacher or volunteer assistance is previewed before
  explicit adoption and sending. Worker version
  `8db50781-98b4-4ef7-89e4-a8ff4e9319a6` is deployed. Runtime tests pass
  `19/19`, production Firebase/Groq smoke tests pass `36/36`, and the complete
  Python validator sweep passes `70/70`.
- Round 11 has added two-step in-app account deletion, UID-scoped local erasure,
  anonymous-only retained metrics, staged cleanup for multi-class accounts and
  an explicit student-controlled human-help route without automatic mood
  alerts. Firestore Rules and indexes are deployed; the base Worker version
  `c4cf2872-26ca-4829-90a2-66102a055eb4` passes production smoke checks `46/46`,
  the Firestore Emulator suite passes `18/18`, Worker tests pass `22/22`, and
  the complete validator sweep passes `71/71`. Scheduled recovery now uses a
  one-permission custom IAM role and passed a controlled production probe with
  `scanned: 1`, `completed: 1`, `failed: 0`; the deleted account could not sign
  in again. Final Worker version `addf0fc7-f6cc-41a0-ac49-04d32b76f48d`
  restores the daily Cron and contains no temporary test route.

## Current technical constraints

- The reviewed Firestore rules are deployed to `englishplus-testflight`; online
  access-boundary smoke tests and the isolated Firestore Emulator role matrix
  both pass.
- Swift compilation is not available on this Windows host. The isolated macOS
  GitHub Actions gate passed the Round 9 clean iOS Simulator build in run
  `29241754603`; Round 10 branch-only run `29243976304` and Round 11 run
  `29252015455` also passed clean Xcode 16.4 iOS Simulator builds. Xcode Cloud
  remains the release-level gate at the agreed checkpoint.
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

## Next gate

Round 11 is fully signed off on `codex/app-store-hardening-c`. Round 12 adds the
final privacy policy, third-party AI disclosure and support entry, then performs
the Block C four-round checkpoint audit. The branch stays separate from `main`
until that checkpoint, when one deliberate merge will trigger Xcode Cloud.

## Maintenance rule

After every completed round, update this file only when a current fact,
decision, blocker, branch, or next decision changes. Put full evidence in that
round's report. This keeps future work context compact without losing detail.
