# Round 5 - Personal learning mode

Status: Complete

## Objective

Make the full student learning loop work for an authenticated account that has
not joined a class. A class remains optional: mood check-in, AI mission
planning, daily questions, wrong-answer explanation, finite free practice and
personal progress must not depend on a demo class or class membership.

## Implemented

- `RootView` now starts the learning listener for both personal and classroom
  scopes. Personal accounts no longer stop synchronization merely because
  `activeClassId` is absent.
- Personal check-ins, daily missions, mission attempts and learning-flow state
  are mirrored to account-owned Firestore paths and listened back into the app.
- Firestore snapshots also hydrate the local execution engine, so a mission
  restored on a new device is not merely visible: it remains answerable.
- Local fallback snapshots are keyed by authenticated UID. Switching accounts
  cannot reuse another account's mission, support queue or assignment state.
- Personal scope explicitly removes class-only support threads and teacher
  assignments from the active snapshot.
- Daily-mission and free-practice help keep real AI explanation available in
  personal mode. Teacher/volunteer actions appear only after joining a class.
- Class and Support tabs now have honest personal-mode empty states.

## Flow acceptance

1. A signed-in student with no membership reaches the normal mood check-in.
2. AI planning creates a finite mission from the approved question bank.
3. Correct answers advance progress; wrong answers do not and can call AI.
4. Free practice records session completion in personal learning settings.
5. Relaunch restores today's check-in, mission, attempts and flow state from
   Firestore or the UID-scoped local fallback.
6. No-class learners never see a human-support action that cannot complete.

## Verification

- `scripts/validate_app_store_hardening_round5.py`
- Existing Round 2-4, mission/login, Firebase runtime, learning-flow,
  practice-center, Groq proxy and Xcode project source validators
- Online Firebase/Worker smoke test, including authenticated personal-scope AI
- `git diff --check`

The Windows host cannot run Xcode compilation. Per the four-round gate, Round 5
is committed only on `codex/app-store-hardening-b`; Xcode Cloud waits for the
Round 8 Block B audit.
