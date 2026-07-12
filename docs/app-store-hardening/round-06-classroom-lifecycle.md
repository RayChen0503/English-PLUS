# Round 6 - Classroom lifecycle

Status: Complete

## Objective

Make optional classrooms usable end to end without weakening personal mode:
an active teacher can create a class, keep a stable join code until choosing to
reset it, and switch among classes; a student can join multiple classes,
choose one current class, leave safely, and return to personal learning.

## Confirmed decisions

- `4B`: the join code stays valid until the teacher explicitly resets it.
- `5A`: leaving removes live class access and new assignments while preserving
  personal learning and the teacher's historical class reports.
- `6A`: every active teacher account can create a class.

## Implemented

- Added authenticated Worker endpoints for listing, creating, joining,
  leaving, resetting a code, and migrating the legacy demonstration class.
- Class IDs and eight-character codes use Web Crypto. Join-code documents,
  owner metadata and join-attempt counters remain private to the trusted
  backend; students cannot enumerate codes through Firestore.
- Class creation and membership changes use atomic Firestore commits. Resetting
  a code invalidates the previous code without affecting existing members.
- Join attempts are limited to 12 per 15-minute window per Firebase UID.
- Leaving marks membership, student summary and user membership as left instead
  of deleting records. The learner returns to personal mode and no longer
  receives class tasks or live access.
- Firestore access rules preserve teacher read-only access to records inside
  the student's membership window. Volunteers and the former student lose
  class access immediately; old reports cannot be changed after leaving.
- Added a native classroom service boundary with remote, unavailable and local
  test implementations, plus AppState loading/error/success transitions.
- Student UI now supports joining, switching, personal mode and confirmed
  leaving. Teacher UI supports creation, switching, copying and resetting the
  current code before showing the selected class workspace.
- Learning fallback caches are isolated by full UID and scope. Existing
  UID-only personal caches are migrated once, while class scopes cannot collide
  or flash another class's mission, assignments or support threads.

## Flow acceptance

1. A personal-mode student continues using all independent learning features.
2. An eight-character teacher code joins exactly one active class.
3. The same account may join several classes and switch the current class.
4. Switching class or returning to personal mode replaces the realtime
   listener and local fallback scope before class data is shown.
5. Resetting a code makes the old code unusable while existing members remain.
6. Leaving removes live class access and new assignments but does not erase
   personal progress or the teacher's historical report window.
7. A teacher cannot join as a student; a student cannot create or reset a
   class; private join-code collections remain unreadable to every client.

## Verification

Local verification includes:

- `scripts/validate_app_store_hardening_round5.py`
- `scripts/validate_app_store_hardening_round6.py`
- Worker syntax and unit tests
- Existing identity, mission, learning-flow, practice, Firebase and Xcode
  source validators
- `git diff --check`

Remote verification includes:

- Worker version `c50812b0-2eb5-48af-8b52-951d209220e4`
- 23/23 production smoke checks across Firebase student, teacher and volunteer
  sessions
- successful legacy membership migration and authenticated classroom listing
- role-denial checks for create, join and reset operations
- real Groq AI responses with `fallbackUsed=false`, R2 state enforcement and
  cross-user Firestore denial

## Remote deployment gate

Passed. Round 6 remains on `codex/app-store-hardening-b`; it is not merged into
`main`, and Xcode Cloud will not be triggered before the Round 8 Block B audit.
