# Round 29-31 Auth, Sync, And Support Loop Polish

This pass revisits the original Round 6-8 areas after the student mission and AI polish work.

## Round 29: Login Boundary Polish

- Demo classroom accounts remain available.
- Validation messages are user-facing Traditional Chinese instead of implementation text.
- Provider display names no longer expose Firebase, SSO, or remote-auth labels on normal product surfaces.
- Role labels continue to come from remote claims or the local classroom profile.

## Round 30: Cloud Data And Sync Polish

- Added a role-scoped write contract for cloud record types.
- Students can write only their own help requests, learning events, and mission completions.
- Teachers can write staff replies, internal staff notes, and question-bank records.
- Volunteers can write staff replies and staff notes, but cannot manage the question bank.
- Collaboration payloads now mark `studentVisible` and `staffOnly`, so backend adapters can keep student-visible replies separate from staff-only notes.
- Sync status wording in normal screens now uses product language such as data update status instead of setup-oriented wording.

## Round 31: Student-Teacher Closed Loop Polish

- Added a tested decision rule for student help requests.
- A student cannot create a duplicate open request for the same unresolved reason.
- After a teacher or volunteer reply closes the open request, the student can ask again for the same reason if needed.
- The student support UI now respects this decision and routes duplicate attempts back to the support thread instead of creating repeated cards.

## Verification Targets

- `AuthContractTest`
- `CloudDataContractTest`
- `CollaborationFlowContractTest`
- Full Gradle test/build/lint before completion.
