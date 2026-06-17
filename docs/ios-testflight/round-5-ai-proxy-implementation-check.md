# Round 5 - AI Proxy Implementation Check

Date: 2026-06-17
Branch: `main`
Repository: `RayChen0503/English-PLUS`

## Result

Round 5 now has a concrete implementation boundary for the OpenRouter AI path.

The app still does not call OpenRouter directly and does not store an OpenRouter API key. The production path remains:

```text
iOS App -> Firebase Callable Function -> OpenRouter -> Firebase Callable Function -> iOS App
```

## GitHub Question Bank Answer

The repository already contains the available question-bank sources:

- Android prototype source: `app/src/main/java/tw/edu/citizenaction/soracompanion/data/PrototypeRepository.kt`
- iOS bundled seed: `ios/EnglishPlus/EnglishPlus/Resources/SeedData/question_bank_seed.json`

There was no newer remote GitHub question-bank file on `origin/main` at the start of this round. The iOS app should not pull question-bank content directly from GitHub at runtime. The safer path is to keep bundled seed data for offline fallback, then sync reviewed question-bank documents through Firestore when the backend is ready.

## Implemented Backend Files

```text
functions/package.json
functions/tsconfig.json
functions/src/index.ts
```

The callable function scaffold includes:

- `englishPlusAiProxy` in region `asia-east1`
- Secret Manager binding for `OPENROUTER_API_KEY`
- OpenRouter chat completions URL
- default `openrouter/free` route
- optional `openrouter/auto` quality route
- Firebase Auth requirement
- class membership lookup
- task-by-role authorization
- volunteer scope guard
- daily rate limit counter
- prompt-context sanitization
- normalized success and fallback responses
- AI event logging without raw prompt storage

## Implemented iOS Files

```text
ios/EnglishPlus/EnglishPlus/Models/AiProxyModels.swift
ios/EnglishPlus/EnglishPlus/Services/AiProxyService.swift
ios/EnglishPlus/EnglishPlus/Services/MockAiProxyService.swift
```

The iOS side now has:

- Codable request and response models matching the Round 5 schema direction.
- A service protocol for the future Firebase callable implementation.
- A mock/local fallback service that uses the bundled seed rules and never needs an OpenRouter key.

## Safety Boundary

- `OPENROUTER_API_KEY` is referenced only as a Firebase Functions secret.
- `functions/.secret.local` is ignored and not present in the repository.
- `functions/node_modules/` and compiled `functions/lib/` output are ignored.
- iOS code does not reference the OpenRouter API key.
- The Android prototype remains untouched.

## Validation

AI proxy contract validation command:

```bash
python3 scripts/validate_round5_ai_proxy_contract.py
```

Actual result:

```text
Round 5 AI proxy contract validation passed
```

iOS seed validation command:

```bash
python3 scripts/validate_ios_seed.py
```

Actual result:

```text
iOS seed validation passed
```

Backend TypeScript verification:

```bash
npm --prefix functions run build
```

Actual result:

```text
tsc build passed
```

Backend dependency audit:

```bash
npm --prefix functions audit --audit-level=high
```

Actual result:

```text
No high severity or critical audit failure.
Remaining audit notices are moderate transitive Firebase dependency-chain notices.
```

iOS build verification:

```bash
DEVELOPER_DIR=/Users/zhengyouxi/Downloads/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/EnglishPlus/EnglishPlus.xcodeproj \
  -scheme EnglishPlus \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /Users/zhengyouxi/Documents/Codex/2026-06-15/files-mentioned-by-the-user-english/work/EnglishPlusRound5DerivedData \
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
Launch process ID: 39309
Visual check: English+ role-selection screen rendered normally
```

## Round 5 Self-Check

- GitHub remote checked before implementation: yes
- New remote question-bank file found: no
- iOS runtime pulls question bank directly from GitHub: no
- Firebase callable proxy scaffold exists: yes
- OpenRouter key kept out of iOS and repo secrets: yes
- Free and quality model routes captured: yes
- Role, membership, volunteer scope, and rate-limit boundaries captured: yes
- AI usage and AI event Firestore paths/models captured: yes
- iOS AI proxy contract models exist: yes
- Local fallback service uses bundled seed data: yes
- TypeScript build passes: yes
- iOS build, install, and launch pass: yes
- Android files preserved: yes
