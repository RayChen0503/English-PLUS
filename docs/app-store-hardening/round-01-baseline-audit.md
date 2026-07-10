# Round 1 - Baseline audit and freeze

Date: 2026-07-10

Baseline commit: `cf5381fea1c595632a897b2fa38076358870ff39`

Baseline subject: `Improve class assignments and teacher workspace`

Working branch: `codex/app-store-hardening`

## Round outcome

The current product was frozen and re-audited before the App Store hardening
work begins. No user-facing feature was changed in this round and `main` was
not modified.

The iOS app is a substantial SwiftUI prototype with real Firebase and Groq
integration boundaries, but it is not yet an App Store-ready multi-tenant
product. Its largest architectural constraint is that authentication,
consent, learning data, support, AI requests, and realtime listeners all assume
one fixed class: `YILAN-CHENGZHI-8A`.

## Current product baseline

### Student

- Role selection, email/password sign-in, and student email/password account
  creation.
- Privacy consent, mood check-in, AI-assisted daily mission generation, daily
  mission progress, free practice, teacher assignments, support threads, and a
  learning map.
- Multi-type seed question bank with vocabulary, grammar, fill-in-the-blank,
  cloze, reading, translation, and dialogue content.
- Question selection includes approved-item filtering, fallback tiers, answer
  diversity scoring, and balanced answer positions.

### Teacher

- Class dashboard, per-student assignment workflows, assignment history and
  progress, support relay, AI reply drafting, and report surfaces.

### Volunteer

- Volunteer home, shared support relay, reply coaching, notification badges,
  and support records.

### Services

- Firebase Core, Authentication, and Firestore service boundaries.
- Local mock/fallback implementations for unavailable configuration or
  network services.
- Cloudflare Worker proxy to Groq for daily missions, wrong-answer help,
  emotional support, teacher drafts, volunteer coaching, and progress
  summaries.
- Xcode project: bundle id `com.englishplus`, iOS 17 minimum, iPhone target,
  version `1.0` build `3` at this baseline.

## Verification baseline

### Passed

- 40 of 61 repository Python validators passed.
- Cloudflare Worker JavaScript syntax check passed.
- Firebase Functions TypeScript `--noEmit` check passed using the checked-in
  dependencies.
- Git baseline was clean before this report was added.

### Failed validator classification

Twenty-one validators failed. They are not twenty-one current product bugs.
The existing suite contains historical contract tests for UI and workflows
that the product owner later removed or replaced.

#### Obsolete contracts - retire or replace

These validators still demand removed support-center AI cards, the removed
"read without replying" action, old volunteer-only cards, old support-page
navigation buttons, or pre-classroom assignment placement:

- `validate_cross_role_flow_consistency_round6.py`
- `validate_ios_ai_task_crash_and_support_cleanup.py`
- `validate_ios_learning_flow_round4.py`
- `validate_ios_learning_flow_round6.py`
- `validate_ios_parity_rounds_3_to_4.py`
- `validate_ios_windows_parity_runtime.py`
- `validate_round4_ai_runtime_usage.py`
- `validate_shared_support_round4_final_ux.py`
- `validate_staff_handoff_notifications_round4.py`
- `validate_student_support_reply_center_round3.py`
- `validate_support_thread_closed_loop.py`
- `validate_volunteer_handoff_round5.py`
- `validate_windows_handoff_rounds_1_to_6.py`
- `validate_windows_handoff_rounds_1_to_8.py`

#### Valuable intent, but assertions must be rewritten

These seven checks cover behavior that still matters, but their current source
markers no longer match the implementation:

- `validate_firebase_role_entry_signin.py`
- `validate_firebase_sync_ai_readiness.py`
- `validate_learning_map_staff_darkmode_round4.py`
- `validate_round2_firebase_runtime_sync.py`
- `validate_round5_practice_center_flow.py`
- `validate_round6_user_visible_copy_and_records.py`
- `validate_support_lifecycle_round1.py`

The replacement suite must test observable behavior and data contracts rather
than the presence of old view names or exact copy.

## Confirmed production blockers

### P0 - data and security

1. **Class membership is mandatory and hard-coded.** New accounts are
   immediately written into `YILAN-CHENGZHI-8A`; session creation fails when
   that membership document is missing. A user cannot currently use English+
   without a class.
2. **Class creation and joining are not implemented.** Firestore paths and
   rules have no complete create-class, join-code, leave-class, active-class,
   or multi-class lifecycle.
3. **Assignment rules do not match runtime paths.** Runtime listeners use
   `classes/{classId}/practiceAssignments`, while the draft Firestore rules do
   not define that collection.
4. **Volunteer support queries and rules are incompatible.** The client listens
   to the whole support-thread collection, but the draft rule only lets a
   volunteer read a thread assigned specifically to that volunteer. This can
   reject the query instead of returning a filtered subset.
5. **Archive/withdraw writes exceed the narrow update allowlist.** Current
   support lifecycle fields and shared teacher/volunteer handling need a new
   rule contract and emulator tests.
6. **AI proxy authentication is not enforced.** The iOS app sends a Firebase ID
   token, but the Cloudflare Worker does not verify it. The `/ai` endpoint has
   wildcard CORS and no per-user quota or abuse protection.

### P0 - App Store and privacy

1. The privacy policy URL is still
   `https://example.edu/englishplus/privacy`.
2. Account creation exists, but there is no working in-app account-deletion
   flow. A deletion-request schema alone is not sufficient.
3. The repository has drafts for privacy labels and retention, not final public
   policy, support URL, retention enforcement, or verified consent handling for
   real minors.
4. There is no iOS unit-test or UI-test target; the Xcode project contains only
   the application target.

### P1 - runtime correctness and maintainability

1. `AppState.restoreSessionIfPossible()` exists, but `RootView` intentionally
   does not call it. Round 2 full-regression review confirmed that automatic
   restoration would bypass role selection and explicit sign-in, reproducing
   a previously fixed student-entry bug. This is no longer classified as a
   blocker; a future explicit "continue session" UX may use the method safely.
2. Student account creation is the only self-service registration flow.
   Google Sign-In and Sign in with Apple are not implemented.
3. The UI still contains implementation-oriented copy such as Firebase and
   test-account language. Diagnostics also expose mock/provider terminology.
4. Firestore learning writes commonly use fire-and-forget `setData` without
   surfacing completion errors to the repository or user.
5. Several ownership boundaries are oversized: 51 Swift files exist, while
   `TeacherHomeView.swift` is 1,642 lines, `PracticeCenterView.swift` is 1,489,
   `FirebaseLearningRepository.swift` is 1,288, and
   `MockLearningRepository.swift` is 1,108. These hotspots raise regression
   risk for the upcoming class and UI work.

## What is real versus fallback

- Firebase and Groq paths are real when bundled configuration and remote
  services are available.
- The app intentionally falls back to mock/local services when configuration
  is unavailable or AI fails. This is useful for development but must not be
  silent in release observability.
- The current UI can therefore appear functional even when a remote write or
  AI call fell back. Production hardening needs internal telemetry and explicit
  QA evidence, without exposing technical details to students.

## Architecture decision required before Round 2

Round 2 will separate a personal learning account from optional class
membership. It cannot be implemented safely until these product rules are
confirmed:

1. **Class capacity per account**
   - A: one account may join only one class.
   - B (recommended): one account may join multiple classes and select an
     active class.
2. **Teacher access to pre-join history**
   - A (recommended): a teacher sees only learning data created after the
     student joined that class.
   - B: a teacher may see the student's earlier personal learning history.

Recommended decision: `1B, 2A`. It supports school changes and multiple
teachers without disclosing personal learning history created outside the
class relationship.

## Round 1 acceptance

- Baseline commit and branch recorded: yes.
- `main` left unchanged: yes.
- Current feature and service inventory recorded: yes.
- Existing validators executed and classified: yes.
- Confirmed production blockers prioritized: yes.
- Next-round decision gate documented: yes.
