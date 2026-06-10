# Round 19-20 Production Handoff And Evidence Gates

## Goal

Rounds 19 and 20 cover the pieces that are easy to leave vague when an app is still running locally:

- what must be decided before real backend, login, cloud sync, and AI proxy deployment;
- what screenshots and recordings must exist before the app is shown to other people as a complete product prototype.

These rounds do not deploy Firebase, create a school backend, or sign a Play Store release. They turn those future steps into explicit, tested contracts so the project does not silently imply that external infrastructure is already finished.

## Round 19: Production Backend Handoff

New contract:

- `ProductionDeploymentContract`

What it defines:

- A deployment decision matrix for:
  - auth provider,
  - cloud database,
  - secure AI proxy,
  - security rules,
  - formal question-bank source,
  - release signing.
- A backend handoff gate that blocks production deployment unless:
  - auth endpoint uses HTTPS,
  - cloud endpoint uses HTTPS,
  - AI proxy endpoint uses HTTPS,
  - `google-services.json` or equivalent Firebase config is ready,
  - role claims exist,
  - privacy policy URL is ready,
  - AI key is server-held,
  - the mobile app does not store a production AI key.
- A security rules outline for student, teacher, and volunteer permissions.

Why it matters:

The app can now answer, in a testable way, what is code-complete locally and what still needs the user, school, or team to provide credentials or policy decisions.

## Round 20: Showcase Evidence Gate

Extended contract:

- `StoreReleaseContract`

What it defines:

- A complete evidence package for screenshots and videos:
  - student folder,
  - teacher folder,
  - volunteer folder,
  - unique screen IDs,
  - minimum role coverage,
  - minimum video length,
  - acceptance notes for every capture.
- A gate that blocks showcase readiness if:
  - role coverage is missing,
  - screenshots/videos are duplicated,
  - videos are too short,
  - captures do not show user action,
  - internal/debug/prototype copy appears.

Why it matters:

This makes future screenshot/recording work less dependent on memory. If the evidence package is followed, the app demonstration should show real usage flows instead of only login screens or repeated frames.

## Verification Expectations

This round should pass:

```powershell
.\gradlew.bat test --rerun-tasks --console=plain
.\gradlew.bat assembleDebug --console=plain
.\gradlew.bat lintDebug --console=plain
```

Targeted tests:

```powershell
.\gradlew.bat testDebugUnitTest --tests tw.edu.citizenaction.soracompanion.qa.ProductionDeploymentContractTest --tests tw.edu.citizenaction.soracompanion.qa.StoreReleaseContractTest --console=plain
```

## Remaining External Boundary

Even after this round, the following cannot be completed by code alone:

- choosing and creating the real Firebase or school identity project;
- providing OAuth/Firebase configuration files;
- deploying the real cloud database or sync endpoint;
- deploying the AI proxy and holding the production AI key on the server;
- choosing the official question-bank source and license;
- creating the Play Store signing key and public privacy-policy URL.
