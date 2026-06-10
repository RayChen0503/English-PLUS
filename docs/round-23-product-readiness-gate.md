# Round 23 Product Readiness Gate

## Goal

Round 23 creates one unified readiness gate for English+.

Before this round, the project already had separate contracts for QA, store readiness, backend handoff, demo evidence, and privacy operations. Those were useful, but they still required a person to mentally combine them. This round adds a single product-level contract that answers:

- Can this be shown in class?
- Can this enter a closed internal pilot?
- Can this be treated as ready for public launch?
- If not, what exactly is blocking it?

## New Contract

- `ProductReadinessContract`

## Readiness Levels

### Classroom Demo

Requires:

- automated checks pass;
- runnable APK build exists;
- GitHub is clean after push.

Default local prototype status:

- ready for classroom demo.

### Internal Pilot

Requires classroom demo readiness plus:

- manual smoke test;
- physical device test;
- teacher brief;
- classroom consent;
- accepted showcase evidence package.

Default local prototype status:

- not ready until real device and consent/evidence checks are complete.

### Public Launch

Requires internal pilot readiness plus:

- signed release;
- privacy policy URL;
- deployed backend;
- production backend gate;
- formal question-bank license;
- Play Data Safety review.

Default local prototype status:

- not ready for public launch because several external credentials and policy decisions remain.

## Why This Matters

The readiness gate prevents a common prototype problem: saying "the app is done" when what is actually done is a strong local product prototype. English+ can now describe its status honestly:

- suitable for classroom demo;
- eligible for internal pilot only after evidence and consent are completed;
- public launch only after backend, signing, privacy, and content-license blockers are resolved.

## Verification

Targeted test:

```powershell
.\gradlew.bat testDebugUnitTest --tests tw.edu.citizenaction.soracompanion.qa.ProductReadinessContractTest --console=plain
```

Full verification:

```powershell
.\gradlew.bat test --rerun-tasks --console=plain
.\gradlew.bat assembleDebug --console=plain
.\gradlew.bat lintDebug --console=plain
```
