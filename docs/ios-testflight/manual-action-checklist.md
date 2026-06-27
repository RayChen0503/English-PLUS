# Manual action checklist

This file separates what Codex can do from what a human account owner must do.

## What is complete

- The repo contains the Xcode project, shared scheme, ExportOptions, Firebase-ready boundaries, AI proxy-ready boundaries, seed data, role flows, and validation scripts.
- `MockAuthService`, `MockAIService`, and mock fallback behavior keep the prototype usable without real credentials.
- The iOS app does not store `OPENROUTER_API_KEY`.
- The repo keeps `GoogleService-Info.plist` out of Git.

## What is not complete yet

- Real Apple signing and provisioning have not been proven in this Windows environment.
- Real Firebase runtime has not been enabled.
- Real Cloud Functions AI proxy has not been deployed.
- Real cross-device teacher/student/volunteer sync has not been proven.

## Manual boundary

This manual boundary section lists tasks that cannot be completed by committing source code.

The following actions require a real account session, payment state, or secret:

### Apple

- Complete Apple ID two-factor when prompted.
- Confirm Account Holder agreements, payment, tax, and membership are active.
- Confirm App Store Connect has an app record for `com.englishplus`.
- Confirm the teammate or Xcode Cloud has enough role access.
- Confirm Apple Distribution signing and provisioning can be created.
- Provide tester email list.
- Provide privacy policy URL.
- Provide support URL.

### Firebase

- Create or confirm Firebase project.
- Register iOS app with Bundle ID `com.englishplus`.
- Download `GoogleService-Info.plist`.
- Add Firebase SDK products in Xcode.
- Enable Firebase Auth providers.
- Deploy Firestore rules and indexes.
- Create starter documents such as `classes/{classId}/members/{uid}`.

### AI

- Create or confirm OpenRouter account/key.
- Store `OPENROUTER_API_KEY` as a Cloud Functions secret.
- Deploy Cloud Functions proxy.
- Confirm the iOS app calls only Cloud Functions, not OpenRouter directly.

## Manual action order

1. Apple account and signing first.
2. TestFlight app record second.
3. Xcode Cloud or local Archive third.
4. Internal TestFlight tester email setup fourth.
5. Firebase project and `GoogleService-Info.plist` fifth.
6. Firestore rules, indexes, Auth providers, and membership seed data sixth.
7. Cloud Functions and `OPENROUTER_API_KEY` seventh.
8. Real cross-device sync and real AI smoke test last.

## Failure interpretation

- Personal Team only: the Apple ID in Xcode does not have usable paid Developer Team access.
- No profiles: provisioning is missing or the Bundle ID is not registered.
- App record missing: App Store Connect needs the app created before upload.
- Firebase build issue: the SDK or `GoogleService-Info.plist` target membership is likely wrong.
- Firebase permission issue: Firestore rules or Auth/membership documents are likely wrong.
- AI fallback: Cloud Functions URL, auth token, proxy schema, or `OPENROUTER_API_KEY` is likely missing.

## Commands to run

```bash
python scripts/validate_ios_parity_round_8_action_package.py
python scripts/validate_firebase_sync_ai_readiness.py
python scripts/validate_round8_testflight_preparation.py
```

## What to send back to Codex

For Apple:

- Screenshot of Xcode Signing & Capabilities.
- The Team dropdown options.
- The exact signing error.

For Firebase:

- Whether `GoogleService-Info.plist` exists locally.
- Firebase project ID.
- Enabled Auth providers.
- Firestore rules deploy output.

For AI:

- Cloud Functions deploy output.
- Whether `OPENROUTER_API_KEY` secret exists.
- Any proxy response or timeout log.
