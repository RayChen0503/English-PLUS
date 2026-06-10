# Round 21-22 Backend Handoff And Privacy Operations

## Goal

Rounds 21 and 22 turn the previous production gates into concrete handoff and operations material:

- Round 21 defines the backend endpoints, example payloads, and deployment runbook needed by a Firebase or school backend team.
- Round 22 defines the internal-test consent packet, data lifecycle actions, and Play Data Safety draft needed before wider testing.

These rounds still do not deploy the real backend or create external credentials. They make those future steps precise, testable, and harder to misunderstand.

## Round 21: Backend Endpoint And Payload Handoff

Extended contract:

- `ProductionDeploymentContract`

Added:

- `backendEndpointManifest()`
  - `/health`
  - `/auth/login`
  - `/sync/push`
  - `/sync/fetch`
  - `/ai/support`
  - `/question-bank/import`
- `backendPayloadExamples()`
  - deployment metadata
  - login request
  - sync push request
  - AI support request
  - question-bank import request
- `deploymentRunbook()`
  - local verification and version freeze
  - HTTPS backend health check
  - role claims and class permissions
  - server-side AI proxy
  - closed internal test and rollback path

Important guardrail:

- Payload examples contain no real password, no production key, and no sensitive credential sample.

## Round 22: Privacy Operations And Data Safety

Extended contract:

- `PrivacyGovernanceContract`

Added:

- `internalTestConsentPacket()`
  - student notice
  - guardian notice
  - teacher notice
  - volunteer notice
  - school/team notice
- `dataLifecycleRunbook()`
  - export student data
  - delete internal-test records
  - opt out
  - incident review
- `playDataSafetyDraft()`
  - data type
  - sensitivity
  - purpose
  - sharing boundary
  - retention summary
  - deletion path
  - contact route

Important guardrail:

- Emotional support, collaboration notes, AI support context, and learning records remain sensitive and are never visible to other students.

## Verification Expectations

Targeted tests:

```powershell
.\gradlew.bat testDebugUnitTest --tests tw.edu.citizenaction.soracompanion.qa.ProductionDeploymentContractTest --tests tw.edu.citizenaction.soracompanion.qa.PrivacyGovernanceContractTest --console=plain
```

Full verification:

```powershell
.\gradlew.bat test --rerun-tasks --console=plain
.\gradlew.bat assembleDebug --console=plain
.\gradlew.bat lintDebug --console=plain
```

## Remaining External Boundary

The following still require user, school, or deployment decisions:

- creating the Firebase or school identity provider;
- deploying the HTTPS backend endpoints;
- choosing the real AI proxy host and storing the production model key server-side;
- confirming the official question-bank source and license;
- publishing a public privacy policy URL;
- naming the school/team data contact and test window.
