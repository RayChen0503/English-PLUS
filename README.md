# English+

English+ is an Android prototype for a rural English learning support platform. The product direction is simple: students should not meet English practice as pressure first. The app starts from mood, time, and a small next action, then routes harder emotional or learning breakpoints to AI support, teachers, or volunteers.

## Current Version

- Version name: `0.7.0`
- Version code: `7`
- Android application id: `tw.edu.citizenaction.soracompanion`
- Minimum SDK: `26`
- Target SDK: `35`
- Current status: classroom demo / internal testing prototype

## Protected Baselines

- Earlier preserved classroom prototype tag: the existing initial-version rollback point.
- `pre-perfect-rebuild-2026-06-09`: the latest baseline before the final product-readiness rebuild.

Do not reset to these tags unless a rollback is explicitly requested. The current upgrade plan is documented in `docs/superpowers/plans/2026-06-09-perfect-product-readiness.md`.

## What Is Working Now

- Student and teacher/volunteer tracks.
- Today-first home screen with low-pressure next actions.
- Mood and time check-in.
- Short English practice tasks.
- Question answering, feedback, and repair hints.
- Help request flow for emotional or learning breakpoints.
- AI support lab with local fallback and proxy-ready architecture.
- Teacher/volunteer handoff board and action queue.
- Student roster and student detail screens.
- SQLite persistence for app state, learning events, accounts, collaboration notes, offline sync items, and question bank items.
- Question bank center with level, unit, skill, and source metadata.
- Offline task packs and sync center.
- Cloud backend client scaffolding for future sync and collaboration endpoints.
- Separate student, class, and pilot reports with text/HTML export boundaries that are ready for PDF, Word, and teacher-dashboard rendering.
- Product principles, OPPM checks, and in-app design system.
- Design-system contracts for bottom navigation, button hierarchy, card layout, copy fit, and success/loading/empty/error states.
- Privacy and data-governance contracts for sensitive emotional-support data, data export/deletion requests, no public ranking, API-key guardrails, and Firebase security-rule requirements.
- Full QA matrix for student happy path, free practice, student support, teacher path, and volunteer path.
- Internal-test readiness checklist for APK/AAB artifacts, Play Console setup, screenshots, and external credential gaps.
- Round 16 real-state inventory that separates implemented local capabilities from external dependencies, with tests preventing normal screens from exposing prototype/setup wording.
- Round 17-18 local collaboration loop and sync readiness: student help requests, teacher/volunteer replies, student-visible timelines, retry/backoff planning, and collaboration conflict reports are now tested as contracts.
- JVM unit tests for repository data and core model invariants.

## Prototype Limits

This is not a production release yet. The following areas still need formal implementation before public launch:

- Firebase Auth / Google sign-in or a school account system.
- Real cloud database and authorization rules.
- Real-time multi-device collaboration.
- Production AI proxy with server-side OpenAI key storage.
- Complete licensed question bank and content management workflow.
- Deployed PDF / Word rendering service or teacher dashboard using the prepared report boundaries.
- Public privacy policy URL and final Play Data Safety answers.
- Full Android UI tests, physical-device testing, and multi-screen QA.

## Build And Test

Open `D:\SoraCompanion` in Android Studio, wait for Gradle sync, then run the `app` configuration on an Android device or emulator.

Command-line verification:

```powershell
$env:JAVA_HOME='C:\Program Files\Android\Android Studio\jbr'
$env:PATH="$env:JAVA_HOME\bin;$env:PATH"
.\gradlew.bat test --rerun-tasks --console=plain
.\gradlew.bat assembleDebug --console=plain
.\gradlew.bat lintDebug --console=plain
```

Build artifact commands:

```powershell
.\gradlew.bat :app:assembleDebug --console=plain
.\gradlew.bat :app:assembleRelease --console=plain
.\gradlew.bat :app:bundleRelease --console=plain
```

Artifact outputs:

```text
Debug APK: app/build/outputs/apk/debug/app-debug.apk
Unsigned release APK: app/build/outputs/apk/release/app-release-unsigned.apk
Release AAB: app/build/outputs/bundle/release/app-release.aab
```

## Release Preparation Notes

The project now has a release build type and a placeholder `proguard-rules.pro`, but it is not signed for store upload yet. A Google Play release will still require:

- Release keystore.
- Signed Android App Bundle (`.aab`).
- Play App Signing.
- Store listing assets.
- Privacy policy URL.
- Data Safety answers.
- Closed/internal testing.

The current internal-test and screenshot plan is documented in `docs/round-14-15-full-qa-internal-test-readiness.md`.

The real-state audit is documented in `docs/round-16-real-state-audit.md`.

The local collaboration loop and sync-readiness work is documented in `docs/round-17-18-local-loop-sync.md`.

## Project Structure

```text
SoraCompanion/
  app/
    src/main/java/tw/edu/citizenaction/soracompanion/
      MainActivity.kt
      ai/
      auth/
      cloud/
      data/
      model/
      state/
      storage/
      ui/
    src/test/java/tw/edu/citizenaction/soracompanion/
  docs/
  build.gradle.kts
  settings.gradle.kts
```
