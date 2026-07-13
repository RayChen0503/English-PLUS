# Round 8 - Firestore synchronization and Block B audit

Status: In verification

## Objective

Make personal learning and classroom collaboration obey one deployable
Firestore contract. A screen is not considered synchronized merely because a
local fallback changes; the same action must be authorized under production
Rules, reach the correct listener query, and remain invisible to unrelated
roles.

## Confirmed decisions carried into this round

- `4B`: teachers may reset their class join code.
- `5A`: leaving removes current class access while retaining historical class
  reports inside the membership window.
- `6A`: every active teacher may create and manage their own classes.

## Defects found and corrected

1. Teacher and volunteer support replies still used demo author UIDs in the
   Firebase repository. They now use the active authenticated UID, display
   name and role.
2. Students could not persist assigned-practice progress because the previous
   Rules allowed only teachers to update assignment documents. Students may
   now update only `status`, `questionResults` and `updatedAt`; assignment
   identity and question selection remain immutable.
3. A student who had left a class could still update an old support thread or
   append a message. All new support writes now require active membership.
4. A volunteer could claim a teacher author role in a message. The stored role
   and message type must now match the authenticated class membership.
5. Student support listeners did not include the `studentVisible` constraint
   required by Rules. The runtime query and index contract now include both
   `studentUid` and `studentVisible`.
6. Staff collection listeners depended on per-document fields that Firestore
   could not prove for an unrestricted list query. `get` and `list` permissions
   are now explicit for support threads and practice assignments.
7. Volunteers created an unused full-class practice-assignment listener. It is
   removed; assigned volunteers retain only the specific learning context
   needed for a handoff.
8. The index file existed without being referenced by `firebase.json`, and its
   entries described obsolete collection-group queries. It is now deployable
   and matches the two compound production queries.
9. Large `questionSnapshot` and `questionResults` payloads are excluded from
   automatic indexing because they are never query filters.

## Runtime path and query contract

| Runtime area | Firestore path/query | Intended access |
| --- | --- | --- |
| Personal learning | `users/{uid}/personal*` | Owner only |
| Class roster | `classes/{classId}/members` plus active `students` summaries | Teacher list; student own record |
| Student learning | `students/{uid}/checkIns`, `dailyMissions`, `answerEvents` | Student writes; authorized staff reads within membership window |
| Support inbox | `supportThreads` and `messages` | Student own visible threads; class staff inbox; active members write |
| Teacher practice | `practiceAssignments` | Teacher creates/withdraws; target student reports progress |
| Volunteer handoff | `staffAssignments` | Teacher assigns; target volunteer and student read |
| AI volunteer scope | `assignedToUid + studentUid + status` | Trusted backend query with a collection-scope composite index |

## Acceptance flow

1. A student without a class can read and write personal learning data, while
   every other account is denied.
2. An active class student can create its summary and mission progress but
   cannot alter identity, class, question selection or another student's data.
3. Teacher and volunteer replies persist with the real signed-in identity;
   neither role can impersonate the other.
4. Leaving a class preserves support history created inside the membership
   window but blocks every subsequent student or staff write to that thread.
5. A teacher can create at most a twelve-question assignment for an active
   student. The student can start and complete it; another student cannot edit
   it; the teacher can withdraw it without rewriting its recipient.
6. Student, teacher and volunteer listener query shapes pass Rules as used by
   the App. The volunteer does not subscribe to unused assignment data.
7. Rules and indexes are deployable from one `firebase.json` contract and the
   production authenticated smoke suite remains green.

## Verification plan

- Round 8 source-contract validator
- complete repository Python validator sweep
- Firestore Emulator positive and negative role matrix
- Worker unit tests and Functions TypeScript build
- isolated macOS iOS Simulator compile gate
- deployed Firestore Rules and indexes
- authenticated production Worker/Firebase smoke suite
- `git diff --check` and sensitive-file audit

## Release gate

Round 8 remains on `codex/app-store-hardening-b` until all checks above pass.
Only then may Block B merge deliberately into `main` and trigger one Xcode
Cloud build.

Xcode Cloud is therefore a final Block B release gate, not a per-commit test.
