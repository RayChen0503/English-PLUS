# Round 20 Release Candidate Audit

## Objective

Round 20 turns the completed A-E hardening work into a release candidate. It audits the full student, teacher, volunteer and administrator experience, checks production boundaries and makes the automated gate traceable to a real-device TestFlight pass.

## Automated Acceptance Surface

| Surface | Automated evidence |
| --- | --- |
| Authentication and consent | Swift account-linking/session tests, three role UI sign-in journeys, Firebase configuration validators |
| Personal learning | Mission, practice, answer, AI-after-submit, question-quality and mastery tests |
| Classroom lifecycle | Firestore emulator class create/join/switch/leave/delete and permission tests |
| Assignments | Scope, retraction, live progress and completion tests plus student/teacher route checks |
| Human support | Cross-device request/reply/read/withdraw/archive tests and shared staff-state tests |
| Volunteer governance | Evidence Worker tests, admin portal checks, service-class approval and permission tests |
| Privacy and safety | Privacy manifest, consent, diagnostics opt-in, deletion, AI boundary and public-link validators |
| UI and accessibility | All-role route sweep, Dark Mode, large Dynamic Type and small/large iPhone matrix |
| Build and release | Firebase/Worker/admin checks, clean `build-for-testing`, Swift tests, UI tests and xcresult artifacts on macOS |

## Round 20 Corrections

- Production builds no longer expose the hidden runtime diagnostics gesture or backend identifiers.
- Telephone help links no longer force-unwrap malformed URLs.
- Student, teacher and volunteer primary workspaces have stable accessibility identifiers and route-sweep UI tests.
- Internal TestFlight notes now describe real Firebase, Firestore, Cloudflare and Groq behavior instead of obsolete mock boundaries.
- App Store Connect test information treats the build number as Xcode Cloud-managed.
- A single real-device checklist covers first use, cross-device synchronization, failure recovery, privacy, accessibility and release blocking criteria.
- The obsolete OpenRouter Firebase Functions prototype is no longer deployable from `firebase.json`; it remains explicitly archived while Cloudflare/Groq is the only active AI route.
- Administrator-review tests now require a decision note and protect the applicant-facing correction/rejection explanation contract.
- Automated test hosts cannot initialize production Firebase, and their placeholder configuration remains syntactically valid for SDK compilation.
- Large Dynamic Type authentication now keeps Email, password and the primary action reachable above the keyboard, scrolls focus deliberately and exposes a keyboard-safe continuation path.
- Consent toggles expose confirmed accessibility values; automation waits for each state transition and for the final action to become enabled instead of racing SwiftUI updates.
- The complete gate retains every appearance test and uses a 75-minute cold-run budget; it no longer loses the final matrix to the previous 45-minute workflow ceiling.

## Local Verification Evidence

- Python contract sweep: `90/90` validators passed, including refreshed historical contracts.
- Cloudflare Worker: syntax check passed; Node-compatible tests passed `24/24`.
- Firestore Emulator: role, lifecycle, assignment, support, volunteer and deletion tests passed `35/35` with Java 21.
- Administrator portal: tests passed `7/7`; production bundle completion is delegated to the macOS Node 22 gate because the local Windows Node 24 process exits after transformation without a source diagnostic.
- Firebase Functions historical prototype still compiles, but it is not part of the deploy configuration or production runtime.
- Public availability: privacy policy, support page and administrator portal returned HTTP `200`; Worker health reported Groq ready; unauthenticated `/ai` returned `401`.
- Dependency audit: administrator production dependencies reported zero vulnerabilities. The archived Functions prototype retains transitive moderate advisories and is deliberately excluded from deployment; forcing the audit suggestion would require a breaking Admin SDK/runtime migration for code that is no longer active.

## macOS Release Gate Evidence

- GitHub Actions run: `29351922007` for release-branch commit `33f8539`.
- Cloudflare Worker checks and tests: passed.
- Administrator portal checks: passed.
- Firestore Emulator permission and lifecycle suite: passed `35/35`.
- Historical and current Round 5-20 contract validators: passed.
- Clean iOS `build-for-testing`: passed on Xcode 16.4/macOS 15.
- Swift unit and integration tests: passed.
- Critical student, teacher and volunteer UI journeys: passed.
- Dark Mode and large Dynamic Type on small and Pro Max iPhone simulators: passed.
- `.xcresult` diagnostics were preserved by the workflow.

## Required Gates

1. Every Python contract validator passes locally.
2. Worker TypeScript, Node tests and administrator portal checks pass.
3. Firestore Emulator permission and lifecycle tests pass.
4. macOS CI compiles the iOS test bundle and passes Swift/UI tests on its device matrix.
5. No unresolved secret, release metadata, privacy manifest, signing or app-icon issue remains.
6. The newest TestFlight build passes the manual checklist on real devices before App Store submission.

## Final Status

Round 20 and the combined 20-round automated release gate are signed off. The
release branch is ready for its deliberate `main` merge and Xcode Cloud
delivery. A successful cloud build is not by itself App Store approval: the
real-device Traditional Chinese checklist remains mandatory evidence before
production promotion.
