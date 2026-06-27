# Firebase and AI real connection checklist

This checklist is for turning the current Firebase-ready and AI-ready app into real runtime behavior.

## What is complete

- The iOS service layer already has boundaries for auth, Firestore, learning repository sync, and AI.
- The code includes `MockAuthService`, `MockAIService`, mock fallback, `FirebaseAuthService`, `FirebaseFirestoreService`, `FirebaseLearningRepository`, and `RemoteAIService`.
- The repo includes Cloud Functions proxy examples and schema files.
- The app is designed so the iOS client does not hold `OPENROUTER_API_KEY`.

## What is not complete yet

- `GoogleService-Info.plist` is not present in the repo and should not be committed.
- Firebase SDK products still need to be added in Xcode when real runtime is enabled.
- Firestore rules and indexes still need deployment permission.
- Cloud Functions still need deployment permission.
- `OPENROUTER_API_KEY` still needs to be stored as a Cloud Functions secret.
- Real cross-device sync needs real Auth users and membership documents.

## Manual boundary

This manual boundary section covers Firebase, Firestore, Cloud Functions, and secret access.

The following cannot be done safely without account authorization:

- Firebase Console project access.
- Firebase CLI login.
- Billing or Blaze plan decision if Cloud Functions requires it.
- Secret creation for `OPENROUTER_API_KEY`.
- Real student, teacher, and volunteer test accounts.
- Real class membership documents, for example `classes/{classId}/members/{uid}`.

## Manual action order

1. Create or confirm Firebase project.
2. Register iOS app with Bundle ID `com.englishplus`.
3. Download `GoogleService-Info.plist`.
4. Add `GoogleService-Info.plist` to the Xcode target without committing it.
5. Add Firebase SDK products to the Xcode project.
6. Enable Firebase Auth providers.
7. Create test users for student, teacher, and volunteer.
8. Create Firestore membership documents under `classes/{classId}/members/{uid}`.
9. Deploy Firestore rules and indexes.
10. Deploy Cloud Functions.
11. Store `OPENROUTER_API_KEY` as a Cloud Functions secret.
12. Run real runtime smoke tests for login, daily mission sync, support requests, teacher feedback, volunteer response, and AI explanations.

## Failure interpretation

- App launches but still uses mock fallback: the service factory is not seeing Firebase runtime readiness.
- Login fails: Firebase Auth provider, bundle config, or user account state is wrong.
- Firestore read/write fails: rules, indexes, class membership, or document path mismatch.
- Teacher cannot see student requests: `classes/{classId}/members/{uid}` or support request paths are missing.
- AI returns fallback: Cloud Functions proxy, Firebase Auth token, timeout, response schema, or `OPENROUTER_API_KEY` is missing.

## Commands to run

Repo validation:

```bash
python scripts/validate_ios_parity_round_8_action_package.py
python scripts/validate_firebase_sync_ai_readiness.py
python scripts/validate_round7_ai_service_contract.py
python scripts/validate_round6_firebase_privacy_contract.py
python scripts/validate_round5_ai_proxy_contract.py
python scripts/validate_round4_backend_contract.py
```

Cloud Functions build:

```bash
npm --prefix functions run build
```

Mac smoke build after SDK setup:

```bash
xcodebuild \
  -project ios/EnglishPlus/EnglishPlus.xcodeproj \
  -scheme EnglishPlus \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  build
```

## What to send back to Codex

- Firebase project ID.
- Confirmation that `GoogleService-Info.plist` is added to the Xcode target.
- Auth provider list.
- Firestore rules deploy output.
- Cloud Functions deploy output.
- Whether `OPENROUTER_API_KEY` secret exists.
- One real login test result for student, teacher, and volunteer.
