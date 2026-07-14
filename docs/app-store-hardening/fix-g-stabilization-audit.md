# FIX-G integrated stabilization audit

Date: 2026-07-14

## Scope

FIX-G treats FIX-A through FIX-F as one product instead of six isolated
patches. The audit follows the first-use and returning-user paths for students,
teachers, volunteers and administrators, then checks the shared Firebase,
Firestore, Cloudflare Worker and local-resume boundaries.

## Product-flow matrix

| Role or boundary | Audited path | Required outcome |
| --- | --- | --- |
| All accounts | role choice, Google/Apple/Email, consent, relaunch, sign out | no role bypass, duplicate profile or leaked previous session UI |
| Student personal mode | check-in, AI mission, daily questions, free practice, map | personal learning works without a class and tab browsing does not mutate the mission stage |
| Student class mode | join/switch/leave, assignments, support, staff replies | only the active class is visible and cross-device updates reconcile without reopening a tab |
| Teacher | first login, roster, assignments, handoff, report | active roster starts immediately and counts come from membership rather than support activity |
| Volunteer | application, evidence, review, service class, handoff | approval grants eligibility only; an active service class grants narrowly scoped support access |
| Administrator | private review queue, evidence access, decision | ordinary teacher and volunteer accounts cannot access the review surface or evidence |
| Shared support | send, reply, read, withdraw, archive | lifecycle and badges represent threads, not duplicate reply messages |
| Practice | selection, primary set, repair set, resume, exit | every set is finite; repair returns to the suspended set; optional AI appears only after submission |
| Backend | Rules, indexes, Worker auth, quota, retention | cross-role access is denied and the App never stores provider secrets |

## Defects found and corrected

1. A returning teacher with an active class did not start the roster listener
   until the class workspace was opened. Role-scoped classroom listeners now
   start as part of authenticated-session completion and class-session changes.
2. Reapplying the same session could restart the same roster listener. The
   listener is now keyed by class ID and remains stable until the scope changes.
3. Teacher Home inferred its class list from support requests, so students who
   had never requested help disappeared. It now combines the authoritative
   active-membership roster with optional support context and renders explicit
   personal, loading, failure and empty-class states.
4. Empty support data reported one student because of a forced minimum. Empty
   data now reports zero, while teacher reports use the current roster count.
5. Volunteer completion counted reply messages. Multiple messages in one
   support thread now count as one completed thread.
6. Merely opening the Practice tab changed the student's learning-flow stage.
   Tab browsing is now side-effect free; only an explicit free-practice action
   changes that stage.
7. Teacher roster startup initially occurred before the current consent record
   was confirmed. Membership scope may reconcile during authentication, but
   student roster data now starts only after required consent is accepted.

## Automated acceptance

- Existing FIX-A through FIX-F validators must all remain green.
- Swift acceptance tests verify immediate teacher-roster bootstrap and prevent
  duplicate listener starts.
- Swift acceptance tests verify true zero states and thread-based volunteer
  completion counts.
- The FIX-G validator checks that tab navigation has no learning-state side
  effect and that teacher UI reads the real active-class roster.
- The complete Python validator sweep, Worker tests, administrator portal
  checks, Functions build and Firestore Emulator role matrix must pass.
- The isolated macOS GitHub Actions gate must complete a clean Simulator build
  and run the Swift acceptance suite before FIX-G is considered complete.

## Verification evidence

- Local validation passed all `80/80` Python contract validators.
- Cloudflare Worker tests passed `24/24`, the administrator portal passed
  `7/7`, the Functions TypeScript build passed, and `git diff --check` passed.
- Isolated macOS GitHub Actions run `29300137275` completed successfully on
  commit `d1834f4` in `17m 34s`.
- The Xcode 16.4 Simulator build and Swift acceptance suite passed `36/36`
  tests with zero failures.
- The workflow uses Node 24-compatible `setup-node@v6` and `setup-java@v5`;
  the final run completed with no annotations or deprecation warnings.
- Workflow-file changes are now included in the branch gate path filters, so
  future CI configuration edits cannot silently skip validation.

## Release boundary

FIX-G may be pushed to its isolated branch for macOS compilation. It must not
be merged to `main`, deploy backend resources or trigger Xcode Cloud without an
explicit release instruction from the user.
