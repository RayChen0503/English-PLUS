# Round 14 - Automated quality gates

Status: Implementation complete; macOS validation pending

Date: 2026-07-14

Branch: `codex/app-store-hardening-d`

Release boundary: branch-only implementation and isolated macOS validation.
No Xcode Cloud release is triggered in this round.

## Objective

Turn the most failure-prone product journeys into repeatable release gates.
The existing suite covered service and state contracts, but the project had no
UI-test target, no automated role journey, and no retained Xcode result bundle
when CI failed.

## Added coverage

- A real `EnglishPlusUITests` target runs independently from the unit target.
- UI tests always use a clean mock service bundle, even when CI generates a
  non-production Firebase plist for compilation.
- Launch arguments make cold-start and offline states deterministic without
  changing TestFlight behavior.
- Stable accessibility identifiers cover role selection, email sign-in,
  consent and the primary authentication action.
- Critical journeys cover role selection and legal links, then student,
  teacher and volunteer sign-in, consent and role-specific navigation.
- An offline student journey verifies that local navigation remains usable and
  that the visible retry action is available.

## Synchronization integration tests

Two additional XCTest cases exercise a real listener race: a cancelled class
scope may still deliver a delayed snapshot or error. Both callback paths now
verify the current account/class scope before changing state, preventing an
old class from replacing the active class or scheduling a retry for it.

## CI contract

The isolated macOS workflow now has separate gates for:

1. Cloudflare Worker, admin portal and Firebase Emulator tests;
2. clean iOS Simulator compilation;
3. Swift unit and repository integration tests;
4. serial critical-role UI tests;
5. seven-day retention of unit and UI `.xcresult` diagnostics, even after a
   failed test step.

Both Xcode test commands use explicit execution timeouts. A hung test therefore
fails with an inspectable result bundle instead of consuming the whole job.
The workflow compiles the app and both test bundles once with
`build-for-testing`; unit and UI gates then use `test-without-building` against
the same DerivedData directory. This avoids recompiling Firebase and Google
Sign-In for each test stage.

## Acceptance result

Pending isolated macOS execution. This section will be replaced with the exact
run, build, XCTest, UI-test and Firebase Emulator evidence before Round 14 is
marked complete.
