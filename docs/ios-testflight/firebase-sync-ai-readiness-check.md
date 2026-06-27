# Firebase / Firestore Sync / AI Proxy Readiness Check

Date: 2026-06-26  
Branch: `main`  
Scope: continue after Round 8, excluding TestFlight signing/archive/upload

## Goal

Move the iOS project to the highest local readiness level before real Firebase config, Firebase SDK wiring, Cloud Functions deployment access, or OpenRouter secrets are provided.

## Implemented

- Added `FirebaseAppConfigurator` and `EnglishPlusServiceFactory`.
- Added `FirebaseAuthService` with Firebase Auth ID token boundary.
- Added `FirebaseFirestoreService` with consent write/listener boundary.
- Added `LearningRepositoryStore` so user-facing role screens depend on a replaceable repository store instead of directly depending on `MockLearningRepository`.
- Added `FirebaseLearningRepository` to mirror mood check-ins, daily missions, answer attempts, support requests, teacher replies, and volunteer replies to Firestore paths when Firebase is available.
- Kept mock fallback active when `GoogleService-Info.plist` or Firebase SDK products are absent.
- Added AI proxy timeout, invalid-response, and task-mismatch fallback handling.
- Kept OpenRouter key and URL out of iOS Swift code.

## Current Runtime Behavior

Because `GoogleService-Info.plist` is not present and Firebase SDK products are not added to the Xcode target yet, the app still uses mock services at runtime.

This is intentional. The real service code is present, target-included, and conditionally compiled with `canImport(FirebaseAuth)` / `canImport(FirebaseFirestore)`, so local simulator builds continue to work without pretending Firebase is connected.

## Ready Boundaries

| Area | Status |
| --- | --- |
| Firebase initialization | Ready, guarded by bundled config check |
| Auth ID token for AI proxy | Ready in `FirebaseAuthService.currentIdToken()` |
| Consent Firestore write/listen | Ready in `FirebaseFirestoreService` |
| Three-end repository switch | Ready via `LearningRepositoryStore` |
| Firestore mirror paths | Ready for check-ins, missions, attempts, support threads, support messages |
| Realtime listener interface | Ready via `LearningRepositoryBackend.startRealtimeListener` |
| AI proxy fallback | Ready for missing token, timeout, HTTP failure, invalid schema, task mismatch |
| User-facing technical text | Not exposed in role views |

## Still Mock

- Runtime Auth/Firestore until Firebase SDKs and `GoogleService-Info.plist` are added.
- Runtime AI until Firebase Auth ID token and deployed `englishPlusAiProxy` are available.
- Cross-device sync is not real until Firestore is connected and security rules/indexes are deployed.

## Manual Inputs Needed For Real Connection

- Add Firebase iOS SDK products to the Xcode project:
  - `FirebaseCore`
  - `FirebaseAuth`
  - `FirebaseFirestore`
  - `FirebaseFunctions` if using callable SDK later
- Add the real `GoogleService-Info.plist` to the iOS app target.
- Deploy Firestore rules and indexes from `docs/ios-testflight/firebase`.
- Deploy `functions/src/index.ts` as Cloud Functions.
- Set the Cloud Functions secret `OPENROUTER_API_KEY`.
- Create real Firebase Auth users and class membership documents under `classes/{classId}/members/{uid}`.

## Validation

```bash
python3 scripts/validate_firebase_sync_ai_readiness.py
python3 scripts/validate_windows_handoff_rounds_1_to_8.py
python3 scripts/validate_round8_testflight_preparation.py
python3 scripts/validate_round7_ai_service_contract.py
python3 scripts/validate_round6_firebase_privacy_contract.py
python3 scripts/validate_round5_ai_proxy_contract.py
python3 scripts/validate_round4_backend_contract.py
python3 scripts/validate_ios_seed.py
npm --prefix functions run build
git diff --check
```

## Simulator Verification

- Generic iOS simulator build succeeded with code signing disabled.
- Specific iPhone simulator build succeeded.
- First install attempt found the simulator shut down; after booting the simulator, install succeeded.
- App launch succeeded on simulator with bundle id `com.englishplus`.
- Launch screenshot was checked at `work/firebase-ready-final-launch.png`; it shows the English+ role selection screen without user-facing Firebase, OpenRouter, mock, or debug text.
