# Round 3 - iOS Seed Data Implementation Check

Date: 2026-06-15
Branch: `main`
Repository: `RayChen0503/English-PLUS`

## Result

The iOS app now has the first real data bridge from the Android prototype into SwiftUI.

This round keeps the existing Round 3 data-format specification as the contract and adds the first Mac/Xcode implementation:

- Bundled `Resources/SeedData` JSON files.
- Swift `Codable` models for demo accounts, question bank items, support options, and daily mission rules.
- A reusable `SeedLoader` that decodes JSON from the app bundle.
- Practice and support screens now read from seed data instead of hard-coded temporary arrays.
- A local validation script checks seed shape, enum values, duplicate prompts, required source fields, and mojibake markers.

## Implemented Seed Files

```text
ios/EnglishPlus/EnglishPlus/Resources/SeedData/
  seed_manifest.json
  accounts_seed.json
  question_bank_seed.json
  daily_mission_rules_seed.json
  support_options_seed.json
```

The first question bank seed intentionally uses a small approved subset from `PrototypeRepository.kt` so the iOS data pipe is testable before importing the full generated Android bank.

## Implemented Swift Files

```text
Models/AppUserProfile.swift
Models/DailyMissionSeed.swift
Models/Question.swift
Models/SupportSeed.swift
Data/SeedLoader.swift
Data/SeedData.swift
```

## Data Rules Covered

- Role IDs use `student`, `teacher`, and `volunteer`.
- The old Android `Mentor` role remains excluded from iOS data and maps conceptually to `volunteer`.
- Question types use stable IDs: `choice`, `fillBlank`, `cloze`, `reading`, and `translation`.
- Question levels use `A1`, `A2`, `B1`, and `B2`.
- Review states use `draft`, `approved`, and `archived`.
- Support routes use `aiCoach`, `humanHandoff`, `readingBreakdown`, and `recovery`.
- Daily mission time and goal rules match the Round 3 contract.

## Validation

Seed validation command:

```bash
python3 scripts/validate_ios_seed.py
```

Result:

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
  -derivedDataPath /Users/zhengyouxi/Documents/Codex/2026-06-15/files-mentioned-by-the-user-english/work/EnglishPlusDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Result:

```text
BUILD SUCCEEDED
```

Simulator run verification:

- Signed simulator build for `EnglishPlus Test iPhone`: passed, `BUILD SUCCEEDED`.
- The built `.app` contains the bundled `SeedData` JSON folder.
- The third-round build installed successfully on `EnglishPlus Test iPhone`.
- The third-round build launched successfully as `tw.edu.englishplus`.
- Simulator screenshot confirmed the app still opens to the English+ role-selection screen.

## Round 3 Self-Check

- Seed JSON folder exists: yes
- Swift Codable data models exist: yes
- Bundle seed loader exists: yes
- Practice center reads question bank seed: yes
- Support screen reads support option seed: yes
- Demo login can read seeded demo accounts: yes
- Seed validation script exists: yes
- Obsolete Round 2 `seed_questions.json` removed: yes
- Generic simulator build: yes
- Signed simulator install/run: yes
- Android files preserved: yes
- Full Android question bank imported: no, deferred until the seed export pipeline is generated
