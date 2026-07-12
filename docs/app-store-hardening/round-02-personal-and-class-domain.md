# Round 2 - Personal and class-mode domain

Date: 2026-07-10

Working branch: `codex/app-store-hardening`

## Confirmed product decisions

- **Decision 1B - Multiple active memberships.** One account may belong to
  multiple classes and select one active class at a time. Selecting no class
  places the account in personal learning mode.
- **Decision 2A - Post-join visibility.** Teachers and authorized class staff
  may read only class learning records created at or after the student's
  `visibilityStartsAt` timestamp for that membership. Personal learning data
  is never exposed through a class path.

## Domain contract

`AppUserProfile` now separates the account from its optional class context:

- `memberships` stores every known membership and its lifecycle status.
- `activeClassId` identifies the currently selected class or is `nil` for
  personal mode.
- `LearningScope` makes personal and classroom behavior explicit.
- `ClassMembership` records `joinedAt`, `visibilityStartsAt`, `status`, and
  `leftAt` so authorization does not depend on UI filtering.

The compatibility `classId` property remains temporarily available for older
local features. In personal mode it returns a clearly marked personal scope
identifier, but remote code must use the dedicated personal Firestore paths.

## Firestore shape

Account-owned membership mirrors:

```text
users/{uid}
  activeClassId: string | null
  classMemberships/{classId}
```

Authoritative class membership:

```text
classes/{classId}/members/{uid}
  role
  status
  joinedAt
  visibilityStartsAt
  leftAt
```

Personal learning records stay under the account:

```text
users/{uid}/personalCheckIns/{dateKey}
users/{uid}/personalDailyMissions/{missionId}
users/{uid}/personalAnswerEvents/{eventId}
users/{uid}/personalLearningEvents/{eventId}
```

Class learning records continue under `classes/{classId}` only while that
class is selected. Consent is always saved under the user; it is mirrored to a
class student record only in class mode.

## Runtime behavior

- New self-service accounts are student accounts in personal mode. Account
  creation no longer auto-enrolls a fixed demonstration class.
- Staff self-registration is rejected. Teacher and volunteer provisioning will
  be handled by an invitation or administrator flow in a later round.
- Cold launch continues to show role selection and explicit sign-in. Automatic
  session restoration remains disabled because it previously bypassed the
  selected role and opened the student flow unexpectedly.
- Realtime class listeners start only when an active class exists.
- Selecting a class is an Auth service operation that validates membership,
  persists `activeClassId`, and returns a refreshed session.
- Existing demo accounts remain usable through a legacy membership fallback.

## Authorization boundary

The draft Firestore rules now include personal collections, membership
mirrors, practice assignments, active membership checks, and post-join record
visibility. Class membership creation is server-controlled so a client cannot
join an arbitrary class by writing its own membership document.

These are source-controlled draft rules. Deployment and emulator-based rule
tests are deliberately deferred to the backend security block.

## Round acceptance

- Multiple membership model and active-class selection: complete.
- Personal account creation without forced class enrollment: complete.
- Personal/class persistence routing foundation: complete.
- Post-join visibility represented in data and draft rules: complete.
- Legacy demo compatibility: complete.
- Focused Round 2 source-contract validator: complete.
- `main` merge: not performed.
- **No Xcode Cloud trigger** in this round.

## Verification evidence

Passed focused checks:

- `validate_app_store_hardening_round2.py`
- `validate_ios_seed.py`
- `validate_ios_mission_login_regression.py`
- `validate_round6_firebase_privacy_contract.py`
- `validate_ios_xcode_project_sources.py`
- `validate_round4_backend_contract.py`
- `validate_firebase_deploy_config.py`
- Cloudflare Worker JavaScript syntax check
- Firebase Functions TypeScript `--noEmit`
- `git diff --check`

The complete validator sweep reports 41 passing and 21 failing checks. The 21
failures are the same historical-contract list recorded in Round 1; this round
added one new passing validator and introduced no additional regression.
`validate_round2_firebase_runtime_sync.py` remains in that historical list
because it requires automatic session restoration, which conflicts with the
explicit-login regression test and the confirmed product behavior.

Swift compilation is not available on this Windows host. Per the agreed
four-round release cadence, Xcode Cloud remains deferred until the Round 4
block gate rather than consuming a build for Round 2 alone.

## Deliberately deferred

- Class creation, join-code redemption, leave-class UI, and the active-class
  picker.
- Google and Apple identity providers.
- Backend transaction that atomically writes both membership mirrors.
- Firestore emulator tests and production rule deployment.
- Personal-history import into a class; Decision 2A intentionally forbids it.

## Decision gate for Round 3

> Historical note: the locally relabeled options below caused the original
> `3.C` answer to be misread. The corrected decision is Google + Apple +
> Email/password and is recorded in D-09 through D-12.

Round 3 will harden identity and account provisioning. Confirm:

1. Identity providers:
   - A (recommended): Google, Sign in with Apple, and email/password.
   - B: Sign in with Apple and email/password.
   - C: email/password only.
2. Teacher and volunteer provisioning:
   - A (recommended): invitation or administrator approval only.
   - B: self-registration followed by approval.

Recommended response: `1A, 2A`.
