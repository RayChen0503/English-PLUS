# Round 8 final audit and TestFlight action package

Date: 2026-06-27

This is the final audit for the Windows-side iOS parity work after the GitHub/Xcode Cloud path was chosen. It is also the entry point for the TestFlight action package.

## Source of truth

- Repository: `RayChen0503/English-PLUS`
- Branch: `main`
- iOS project: `ios/EnglishPlus/EnglishPlus.xcodeproj`
- Shared scheme: `ios/EnglishPlus/EnglishPlus.xcodeproj/xcshareddata/xcschemes/EnglishPlus.xcscheme`
- TestFlight export options: `ios/EnglishPlus/Config/ExportOptions.TestFlight.plist`
- Bundle ID: `tw.edu.englishplus`
- Apple Team ID: `SMKVWY55QH`
- Important prior repo states:
  - `f8d4d13` prepared Firebase sync and AI readiness boundaries.
  - `234c6a6` added shared Xcode Cloud and TestFlight hardening.

## What is complete

The repository has the iOS-side structure needed for the current English+ product prototype:

1. Student flow parity exists for role selection, demo login, privacy consent, four-question mood check-in, daily mission generation, correct-answer-only progress, completion feedback, support, map, and free practice.
2. Teacher flow parity exists for prioritized students, support queues, student summaries, teacher feedback, and report-oriented review.
3. Volunteer flow parity exists for relay tasks, support responses, encouragement, and response history.
4. Question bank parity exists through the iOS seed data pipeline with multiple question types and difficulty levels.
5. Local persistence and repository boundaries exist so the app can preserve attempts, mission state, support requests, feedback, and reports.
6. Firebase-ready service boundaries exist for Auth, Firestore, and repository switching.
7. AI-ready service boundaries exist through `MockAIService` and remote Cloud Functions proxy interfaces.
8. Xcode Cloud discovery is ready because `EnglishPlus.xcscheme` is committed.
9. TestFlight preparation files exist, including `ExportOptions.TestFlight.plist`, internal release notes, tester email text, and App Store Connect test information.

## What is not complete yet

These are not source-code gaps. They are account, service, or deployment boundaries:

1. Runtime Auth and Firestore still use `MockAuthService` and mock fallback behavior until `GoogleService-Info.plist`, Firebase SDK products, real Auth users, Firestore rules, and membership documents are enabled.
2. Runtime AI still falls back to mock behavior until Cloud Functions is deployed, Firebase Auth tokens work, and `OPENROUTER_API_KEY` is stored as a Cloud Functions secret.
3. Real cross-device sync is not active until the app runs with the Firebase SDK and Firestore backend.
4. TestFlight upload remains pending until Apple signing, Apple Distribution certificate access, provisioning, App Store Connect app record, and Account Holder agreements are clean.

## Manual boundary

This manual boundary section is the line between repo work and account/service work.

Codex can keep improving code, documents, validation scripts, and mock/demo behavior from this repo. Codex cannot complete these without account access or secrets:

- Apple ID two-factor authentication.
- Apple Developer Account Holder agreement prompts.
- App Store Connect app record ownership and compliance questions.
- Apple Distribution certificate or managed signing profile creation.
- Firebase Console project setup and `GoogleService-Info.plist` download.
- Firebase CLI login and Cloud Functions deployment authorization.
- `OPENROUTER_API_KEY` creation and secret storage.
- Real tester email list approval.
- Privacy policy URL and support URL publication.

## Manual action order

Use this order to prevent confusion:

1. Confirm GitHub `main` is the source of truth.
2. Confirm Xcode or Xcode Cloud opens `ios/EnglishPlus/EnglishPlus.xcodeproj`.
3. Confirm the shared scheme is `EnglishPlus`.
4. Confirm the Bundle ID remains `tw.edu.englishplus`.
5. Confirm the Team remains `SMKVWY55QH`.
6. Run a simulator build first.
7. Run a Release device build without signing to separate code issues from signing issues.
8. Create or confirm the App Store Connect app record.
9. Resolve Apple Developer agreements and signing.
10. Run Archive.
11. Upload to TestFlight after Archive succeeds.
12. After TestFlight is stable, connect Firebase and AI runtime.

## Failure interpretation

- Simulator build failure means a code or Xcode project problem.
- Release device build without signing failure means a code, target, SDK, or Xcode project problem.
- Archive failure after those two pass usually means signing, provisioning, Team, Bundle ID, Apple Distribution, or App Store Connect state.
- TestFlight processing failure after upload usually means App Store Connect metadata, compliance, encryption, privacy, or Apple processing state.
- Firebase runtime failure after the app launches usually means `GoogleService-Info.plist`, Firebase SDK, Auth, Firestore rules, indexes, or membership data.
- AI runtime failure usually means Cloud Functions deployment, Firebase Auth token, proxy URL, schema mismatch, timeout, or `OPENROUTER_API_KEY`.

## Commands to run

Windows repo validation:

```bash
python scripts/validate_ios_parity_round_8_action_package.py
python scripts/validate_ios_parity_round_7_xcode_cloud.py
python scripts/validate_ios_parity_round_6_reports.py
python scripts/validate_ios_parity_round_5_persistence.py
python scripts/validate_ios_parity_rounds_3_to_4.py
python scripts/validate_ios_parity_rounds_0_to_2.py
python scripts/validate_windows_handoff_rounds_1_to_8.py
python scripts/validate_round8_testflight_preparation.py
python scripts/validate_firebase_sync_ai_readiness.py
python scripts/validate_ios_seed.py
npm --prefix functions run build
git diff --check
```

Mac simulator build:

```bash
xcodebuild \
  -project ios/EnglishPlus/EnglishPlus.xcodeproj \
  -scheme EnglishPlus \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Mac Release build without signing:

```bash
xcodebuild \
  -project ios/EnglishPlus/EnglishPlus.xcodeproj \
  -scheme EnglishPlus \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Mac Archive after signing is available:

```bash
xcodebuild \
  -project ios/EnglishPlus/EnglishPlus.xcodeproj \
  -scheme EnglishPlus \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  archive
```

## What to send back to Codex

If the next attempt fails, send:

- The exact Xcode or Xcode Cloud error message.
- Whether the failure happened during simulator build, no-sign Release build, Archive, Upload, TestFlight processing, Firebase runtime, or AI runtime.
- A screenshot if the error is in App Store Connect or Xcode Accounts.
- Any Xcode Cloud log section around signing, provisioning, or archive.

Do not report only "it failed"; the failure stage determines whether the fix is code, Apple account, Firebase, or AI proxy.
