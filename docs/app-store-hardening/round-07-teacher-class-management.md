# Round 7 - Teacher class management

Status: Complete

## Objective

Give a teacher one coherent class workspace whose roster, assignments and
settings always belong to the selected class. A student must appear after
joining even without a support request, and changing class must never leave
the previous class's students or tasks on screen.

## Confirmed decision

- `6A`: every active teacher account can create and manage its own classes.

## Implemented

- Added authenticated Worker endpoints for an owner teacher to list active
  class students and rename a class.
- The roster is derived from active membership documents instead of support
  requests. A student, volunteer or another teacher cannot enumerate it.
- Renaming updates the trusted class document and membership display names in
  one Firestore commit while preserving the join code and existing history.
- Added a native roster model, API fallback and Firestore realtime listener.
  Switching class cancels the previous listener, clears stale rows, and ignores
  late responses from the previous class.
- Student check-ins and mission changes now mirror mood, risk, current level,
  mission status and last activity into the class roster summary.
- The teacher workspace uses the selected class's active roster, exposes
  loading, retry and empty states, and supports editing the class name.
- Assignment scope can be either the selected student or every active student
  in the selected class. Every assignment retains the selected class ID and
  remains visible in the existing pending/completed/withdrawn lifecycle.

## Acceptance flow

1. A teacher opens one selected class and sees every active member, including
   students who have never requested help.
2. Joining or leaving updates the open roster through Firestore without an app
   restart; the authenticated API remains available for first load and retry.
3. Switching classes immediately removes old roster rows and old assignment
   scope before the next class is displayed.
4. A teacher can rename only a class it owns; the join code and membership
   history remain unchanged.
5. An individual assignment reaches only the selected student. A whole-class
   assignment creates one independently trackable assignment per active
   student and never includes students from another class.
6. Students and unrelated staff cannot read the roster endpoint, rename the
   class, or assign work to an inactive member.

## Verification

- Round 7 source-contract validator passed.
- Worker syntax and unit tests passed (`9/9`).
- Firestore Emulator rules, realtime roster query and isolated Worker lifecycle
  passed (`7/7`). During verification, the first roster rule was found to deny
  the required teacher query and a stale summary could appear without an active
  membership. Both defects were corrected before completion: the rule now
  permits only active teacher roster queries, and the iOS listener intersects
  summaries with canonical active memberships.
- The complete repository validator sweep passed (`67/67`). Two legacy
  teacher-assignment checks were updated to protect the current individual and
  whole-class assignment behavior instead of requiring removed copy and the
  former single-student call site.
- The isolated macOS iOS Simulator compile gate passed for commit `73a09c3` in
  GitHub Actions run `29226640748`.
- Firestore Rules compiled and were released to `englishplus-testflight` on
  2026-07-13.
- Cloudflare Worker version
  `4ee60303-29d4-42fe-ade7-d7ad576d2e7b` is the active deployment.
- The authenticated production smoke suite passed (`26/26`), including a
  teacher reading its two-student roster, a student receiving `403` for the
  same endpoint, ownership checks before class mutation, all three role
  sign-ins and live AI with `fallbackUsed=false`.
- `git diff --check` passed.

## Release gate

Round 7 remains on `codex/app-store-hardening-b`. It will not merge into
`main` or trigger Xcode Cloud before the Round 8 Block B audit.
