# Round 4 - iOS Backend Boundary Implementation Check

Date: 2026-06-17
Branch: `main`
Repository: `RayChen0503/English-PLUS`

## Result

The Round 4 Firebase/Auth/Firestore specification now has an iOS-side implementation boundary.

This round does not add the Firebase SDK yet and does not commit a real `GoogleService-Info.plist`. Instead, it adds the app-side contracts that the future Firebase implementation should plug into:

- Firebase project constants for `englishplus-testflight` and bundle ID `tw.edu.englishplus`.
- Firestore path builders for every collection path in the Round 4 schema.
- Swift `Codable` document shapes for users, class members, students, check-ins, daily missions, answer events, support threads/messages, staff assignments, and question-bank documents.
- A seed-to-Firestore mapper that converts Round 3 demo accounts and question-bank seed into future Firestore write plans.
- A validation script for Firestore draft indexes, rules coverage, iOS path builders, backend constants, and `GoogleService-Info.plist` safety.

## Implemented Swift Files

```text
ios/EnglishPlus/EnglishPlus/Data/FirestorePath.swift
ios/EnglishPlus/EnglishPlus/Data/FirestoreSeedMapper.swift
ios/EnglishPlus/EnglishPlus/Models/FirestoreSchema.swift
```

## Safety Boundary

- The real `GoogleService-Info.plist` is still not present in the repo.
- `.gitignore` now blocks `ios/**/GoogleService-Info.plist`.
- The app still runs fully in local/mock mode until the Firebase project and iOS app registration exist.
- The Android prototype remains untouched.

## Validation

Backend contract validation command:

```bash
python3 scripts/validate_round4_backend_contract.py
```

Actual result:

```text
Round 4 backend contract validation passed
```

Seed validation command:

```bash
python3 scripts/validate_ios_seed.py
```

Actual result:

```text
iOS seed validation passed
```

Build verification command:

```bash
DEVELOPER_DIR=/Users/zhengyouxi/Downloads/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/EnglishPlus/EnglishPlus.xcodeproj \
  -scheme EnglishPlus \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /Users/zhengyouxi/Documents/Codex/2026-06-15/files-mentioned-by-the-user-english/work/EnglishPlusRound4DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Actual result:

```text
BUILD SUCCEEDED
```

Simulator verification:

```text
Signed simulator build: BUILD SUCCEEDED
Install to EnglishPlus Test iPhone: succeeded
Launch bundle tw.edu.englishplus: succeeded
Launch process ID: 23638
Visual check: English+ role-selection screen rendered normally
```

## Round 4 Self-Check

- Firebase project constants captured in Swift: yes
- Firestore path builders exist for all Round 4 collection paths: yes
- Swift document models match the Round 4 schema direction: yes
- Round 3 seed can be mapped into Firestore write plans: yes
- Firestore draft indexes parse as JSON: yes
- Firestore draft rules are covered by validation checks: yes
- Real `GoogleService-Info.plist` is not committed: yes
- `.gitignore` protects future local Firebase config: yes
- Generic simulator build passes: yes
- Signed simulator install and launch pass: yes
- Firebase SDK dependency added: no, deferred until the real Firebase project/config file exists
- Android files preserved: yes
