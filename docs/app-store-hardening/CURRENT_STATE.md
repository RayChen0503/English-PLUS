# English+ current state

> **Read this first at the start of every hardening round.** Keep this file
> concise. It is the working source of truth, not a replacement for the
> round reports.

Last verified: 2026-07-12

## Product in one paragraph

English+ is an iPhone-first English learning app with student, teacher, and
volunteer roles. A student can learn independently, complete a short mood
check-in, receive an adaptive daily mission, practise freely, and ask for
human help on a specific question. Classroom membership is optional: personal
learning must remain usable without joining a class.

## Repository and release safety

- Repository: `RayChen0503/English-PLUS`
- Stable Block A baseline: `main` at `9bb6307`
- Active Block B branch: `codex/app-store-hardening-b`
- Completed hardening rounds:
  - Round 1 - baseline audit (`round-01-baseline-audit.md`)
  - Round 2 - personal and multi-class domain (`round-02-personal-and-class-domain.md`)
  - Round 3 - multi-provider role onboarding (`round-03-multi-provider-role-onboarding.md`)
  - Round 4 - provider UI and private volunteer review (`round-04-provider-ui-private-volunteer-review.md`)
  - Round 5 - personal learning mode (`round-05-personal-learning-mode.md`)
  - Round 6 - classroom lifecycle, macOS compile pending (`round-06-classroom-lifecycle.md`)
- Hardening progress: **5/20 complete; Round 6 verification reopened**.
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
  smoke checks at version `c50812b0-2eb5-48af-8b52-951d209220e4`.

## Current technical constraints

- The reviewed Firestore rules are deployed to `englishplus-testflight` and
  online access-boundary smoke tests pass. A full role matrix in the Firebase
  emulator remains future defense-in-depth coverage.
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

## Next gate

Block A is complete and its Xcode Cloud build is green at `9bb6307`. Round 5 is
complete on `codex/app-store-hardening-b`; Round 6 has passed Worker, online and
Firestore Emulator verification but remains open until its isolated macOS
Simulator build passes. Do not merge to `main` or trigger Xcode Cloud until the
Round 8 Block B audit.

## Maintenance rule

After every completed round, update this file only when a current fact,
decision, blocker, branch, or next decision changes. Put full evidence in that
round's report. This keeps future work context compact without losing detail.
