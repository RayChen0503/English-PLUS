# TestFlight onboarding acceptance hotfix

Status: Awaiting isolated macOS compile and XCTest execution.

## TestFlight findings

- A first-time Google / Apple authentication created a Firebase identity but
  then required a pre-existing Firestore profile, producing the misleading
  message that account data was not ready.
- Provider buttons on the create-account tab were disabled until every role
  field was complete, so users could not start with the identity provider as
  they expect in a modern app.
- The teacher institution search looked like an unrestricted text field even
  though the app ships a 3,921-entry Ministry of Education catalog.
- Volunteer evidence upload existed but appeared only after account creation;
  the first screen did not communicate the two-stage flow clearly, and the
  provider defect could prevent the second screen from ever being reached.

## Product contract

- Google / Apple is one continue action for both returning and new users.
  Existing profiles enter the selected role; first-time identities continue to
  a short role-specific profile step without replaying the Apple credential.
- Email/password keeps separate create-account and sign-in actions because it
  requires password creation and email verification.
- Teachers self-register without administrator approval. Institution data is a
  self-declared classroom context, not teacher-credential verification. The
  primary path is an explicit searchable catalog; manual entry is a labelled
  fallback for experimental education and homeschool groups.
- Volunteer registration has two visible stages. Stage one establishes the
  authenticated Firebase UID and basic declarations. Stage two uploads private
  evidence and submits it for review; no student data is exposed before
  approval.

## Release safety

This work remains on `codex/testflight-onboarding-hotfix`. It must pass the
complete validator sweep and an isolated macOS compile before it can be merged
to `main`. Merging is deferred so the current TestFlight acceptance cycle does
not trigger Xcode Cloud prematurely.

## Acceptance coverage

The `EnglishPlusTests` target now executes first-use and returning-account
scenarios against `AppState` with a controllable authentication service. The
suite covers first Google identity, first Apple identity, returning provider
accounts, wrong-role selection, cancellation, retry after network failure,
Email verification, unverified Email sign-in, identity linking, role switching,
pending-volunteer blocking, sign-out cleanup, volunteer evidence routing,
restored sessions, and consent restoration.

Local evidence before the macOS gate:

- 73 / 73 repository validators passed.
- Cloudflare Worker syntax check and 22 / 22 tests passed.
- Firebase Functions TypeScript build passed.
- Firestore Emulator role and privacy suite passed 18 / 18.
- `git diff --check` passed.
