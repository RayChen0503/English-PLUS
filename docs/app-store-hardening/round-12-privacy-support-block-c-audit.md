# Round 12 - privacy, support and Block C audit

Status: Complete.

## Scope

Round 12 turns the public English+ policy and support pages into one executable
product contract. It also closes the four-round Block C checkpoint covering
authenticated AI, executable AI actions, account deletion and legal/support
access.

## Product changes

- Replaced the placeholder policy URL with the public 2026-07-13 policy.
- Added pre-login, consent-time and signed-in access to the privacy policy,
  support page and `englishplus.tw@gmail.com`.
- Versioned consent so accounts that accepted the old draft see the new terms
  once; a matching version remains accepted on later launches.
- The app enters the role home only after the current consent record has been
  committed successfully; a failed write stays on the same page with a retry
  message and preserves the selected checkboxes.
- Added role-specific data explanations, explicit Cloudflare/Groq AI consent,
  a student minor-use confirmation and the no-automatic-staff-contact boundary.
- Reworked the shared account surface so viewing privacy or support does not
  eagerly start an account-deletion preview.
- Added `PrivacyInfo.xcprivacy` with collected-data, no-tracking and required
  reason API declarations, and added it to the app target resources.
- Reconciled the App Store privacy-label record and TestFlight review notes
  with the real Firebase, Cloudflare R2 and Groq runtime.

## Block C audit

The complete repository validator sweep passes `72/72`, including the new
Round 12 contract. The Cloudflare Worker runtime suite passes `22/22`, the
Functions TypeScript build passes, and the Firestore Emulator security matrix
passes `18/18`. The privacy manifest is a valid property list, all `61` Swift
sources are present in the Xcode project, and `git diff --check` reports no
whitespace errors.

Isolated macOS GitHub Actions run `29261085031` passed the clean Xcode 16.4
iOS Simulator build for commit `eba0065`. Block C is therefore ready for its
single deliberate merge to `main`; the release-level Xcode Cloud run starts
only after that merge.
