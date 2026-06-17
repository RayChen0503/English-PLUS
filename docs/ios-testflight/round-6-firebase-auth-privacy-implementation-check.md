# Round 6 - Firebase Auth, Firestore, And Privacy Consent Implementation Check

Date: 2026-06-18
Branch: `main`
Repository: `RayChen0503/English-PLUS`

## Source Of Truth

This round follows the Windows handoff log Round 6:

```text
Firebase Auth / Firestore architecture
Add Firebase SDK or a clean interface first
Support GoogleService-Info.plist
Create AuthService
Create FirestoreService
Map student/teacher/volunteer schemas
Add privacy consent flow
If Firebase config is missing, use mock implementation but keep it replaceable
Build/run check, commit/push
```

## Result

The iOS app now has a replaceable Firebase/Auth/Firestore boundary and a real in-app privacy consent step before entering a role home screen.

This round still does not add the Firebase SDK because `GoogleService-Info.plist` is not present and should not be faked. Instead, the app uses protocols and mock implementations that can be swapped for Firebase-backed implementations after the real Firebase project config is available.

## Implemented iOS Files

```text
ios/EnglishPlus/EnglishPlus/Services/AuthService.swift
ios/EnglishPlus/EnglishPlus/Services/MockAuthService.swift
ios/EnglishPlus/EnglishPlus/Services/FirestoreService.swift
ios/EnglishPlus/EnglishPlus/Services/MockFirestoreService.swift
ios/EnglishPlus/EnglishPlus/Models/PrivacyConsent.swift
ios/EnglishPlus/EnglishPlus/Features/Consent/ConsentView.swift
```

## Behavior

- Demo sign-in no longer auto-accepts consent.
- After selecting a role and entering through the demo account, the user sees a consent screen.
- The consent screen has two required acknowledgements:
  - learning/support data use
  - mood check-in and AI assistance data use
- Continuing saves a `PrivacyConsentRecord` through `FirestoreService`.
- Only after consent is saved does the app route to the selected role home screen.

## Firestore Contract Additions

Paths and models now cover:

```text
users/{uid}/consents/{consentVersion}
classes/{classId}/students/{studentUid}/consents/{consentVersion}
classes/{classId}/students/{studentUid}/deletionRequests/{requestId}
classes/{classId}/aiUsage/{usageId}
classes/{classId}/aiEvents/{eventId}
classes/{classId}/privacyAuditLogs/{eventId}
```

The Firestore draft rules now include conservative access for consent records, deletion requests, AI usage/events, and privacy audit logs.

## Safety Boundary

- `GoogleService-Info.plist` remains absent and ignored.
- Firebase SDK dependency is deferred until the real Firebase config exists.
- Mock services are explicitly replaceable by Firebase-backed implementations.
- The Android prototype remains untouched.

## Validation

Round 6 contract validation:

```bash
python3 scripts/validate_round6_firebase_privacy_contract.py
```

Result: passed on 2026-06-18.

iOS seed validation:

```bash
python3 scripts/validate_ios_seed.py
```

Result: passed on 2026-06-18.

Regression validation:

```bash
python3 scripts/validate_round4_backend_contract.py
python3 scripts/validate_round5_ai_proxy_contract.py
```

Result: both passed on 2026-06-18.

iOS build verification:

```bash
DEVELOPER_DIR=/Users/zhengyouxi/Downloads/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/EnglishPlus/EnglishPlus.xcodeproj \
  -scheme EnglishPlus \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /Users/zhengyouxi/Documents/Codex/2026-06-15/files-mentioned-by-the-user-english/work/EnglishPlusRound6DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Result: passed on 2026-06-18 with `** BUILD SUCCEEDED **`.

Simulator run verification:

```bash
DEVELOPER_DIR=/Users/zhengyouxi/Downloads/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/EnglishPlus/EnglishPlus.xcodeproj \
  -scheme EnglishPlus \
  -configuration Debug \
  -destination 'id=4935AFC4-E765-4863-BB3A-A8616B31CDFC' \
  -derivedDataPath /Users/zhengyouxi/Documents/Codex/2026-06-15/files-mentioned-by-the-user-english/work/EnglishPlusRound6RunDerivedData \
  build
```

Result: passed on 2026-06-18 with simulator install and launch succeeding for bundle `tw.edu.englishplus`.

## Round 6 Self-Check

- AuthService exists and returns a profile-backed auth session: yes
- FirestoreService exists and stores consent through a replaceable interface: yes
- Mock implementations are active because Firebase config is not available: yes
- `GoogleService-Info.plist` is supported by name but not committed: yes
- Consent flow is visible before role home screens: yes
- Student/teacher/volunteer profile schema remains mapped through seed and Firestore models: yes
- Firestore consent, deletion, AI event, AI usage, and audit paths exist: yes
- Firestore rules draft covers new privacy nodes: yes
- Android files preserved: yes
