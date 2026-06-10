# Round 17-18 Local Loop And Sync Readiness

## Goal

Rounds 17 and 18 tighten the parts that used to be easy to overstate:

- A student help request should become a visible teacher/volunteer action.
- A teacher or volunteer reply should return to the student's support thread.
- The app should have one local source of truth for collaboration status.
- Offline/cloud sync should have explicit retry, success, and conflict rules.

This round does not claim real cross-device cloud collaboration is finished. That still requires a deployed backend, credentials, and production authorization rules. The work here makes the local app loop and cloud payload rules testable and ready for that backend.

## Round 17: Student, Teacher, And Volunteer Local Loop

Implemented behavior:

- Student help requests use the readable status `學生求助`.
- Staff replies use `老師/志工已回覆`.
- Read replies use `學生已讀回覆`.
- Internal handoff notes use `內部接力紀錄`.
- Student support screens can show:
  - waiting requests,
  - unread replies,
  - latest support status,
  - the student's next action.
- Staff screens can show:
  - waiting student requests,
  - whether staff can reply,
  - teacher-specific next action,
  - volunteer-specific next action.
- Student-visible support timelines exclude internal staff-only notes.
- Teacher/volunteer queues do not reinterpret student screens as staff screens.

Primary contract:

- `CollaborationFlowContract`

Primary UI integration:

- Student support center now reads from `localSupportLoopSnapshot`.
- Staff action queue now shows the current local handoff state.

## Round 18: Sync Retry And Conflict Rules

Implemented behavior:

- Cloud sync schema was raised to version 4.
- Collaboration sync schema was raised to version 5.
- Sync items now have:
  - failure recording,
  - success recording,
  - retry/backoff plan,
  - blocked state after repeated failures.
- Queue states use readable user-facing messages.
- Collaboration conflict handling now reports:
  - merged notes,
  - duplicate event count,
  - local-only event count,
  - remote-only event count,
  - the rule `latest-createdAt-wins`.

Primary contracts:

- `CloudDataContract`
- `CollaborationSyncContract`

## Verification Expectations

This round should pass:

```powershell
.\gradlew.bat test --rerun-tasks --console=plain
.\gradlew.bat assembleDebug --console=plain
.\gradlew.bat lintDebug --console=plain
```

Additional scans should confirm:

- No real API keys are committed.
- Normal user screens do not show setup/prototype wording.
- Newly edited collaboration/sync files do not contain corrupted replacement characters.

## Remaining External Boundary

The app is now more honest and more complete locally, but true production behavior still requires decisions and credentials for:

- Firebase/Auth or school account login.
- Deployed backend database.
- Real cross-device realtime updates.
- Production AI proxy and server-held API keys.
- Final security rules and privacy documents.
