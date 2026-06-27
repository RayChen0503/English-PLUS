# Round 7 - AI Backend Proxy Architecture Implementation Check

Date: 2026-06-18
Branch: `main`
Repository: `RayChen0503/English-PLUS`

## Source Of Truth

This round follows the Windows handoff log Round 7:

```text
Create AIService protocol
Create MockAIService
Create RemoteAIService connected to Cloud Functions proxy
Do not put OpenRouter key in the iOS app
AI use cases:
  - daily mission generation
  - wrong-answer explanation
  - emotional support
  - teacher/volunteer summary and suggestions
  - student practice recommendation
If OpenRouter key or Cloud Functions deploy access is missing, keep mock + remote interface
Build/run check, commit/push
```

## Result

The iOS app now has a high-level `AIService` boundary above the lower-level `AiProxyRequest` contract.

Default runtime still uses `MockAIService` because the app does not yet have real Firebase Auth SDK tokens or deployed callable-function access in this local run. `RemoteAIService` is present and points only to the Firebase Callable Function `englishPlusAiProxy`.

## Implemented iOS Files

```text
ios/EnglishPlus/EnglishPlus/Services/AIService.swift
ios/EnglishPlus/EnglishPlus/Services/MockAIService.swift
ios/EnglishPlus/EnglishPlus/Services/RemoteAIService.swift
```

Existing proxy contract files remain in place:

```text
ios/EnglishPlus/EnglishPlus/Models/AiProxyModels.swift
ios/EnglishPlus/EnglishPlus/Services/AiProxyService.swift
ios/EnglishPlus/EnglishPlus/Services/MockAiProxyService.swift
functions/src/index.ts
```

## AI Use Cases Covered

- `generateDailyMission`: mood check-in to daily mission plan
- `explainWrongAnswer`: wrong-answer explanation, hint, and retry guidance
- `provideEmotionalSupport`: low-pressure emotional support path
- `draftTeacherFeedback`: teacher-side summary and suggested feedback
- `coachVolunteerReply`: volunteer-side reply guidance
- `recommendPractice`: student practice recommendation through the `progressSummary` proxy task

## Safety Boundary

- iOS Swift code does not reference `OPENROUTER_API_KEY`.
- iOS Swift code does not call `https://openrouter.ai` directly.
- `RemoteAIService` calls the Firebase Functions endpoint shape:

```text
https://asia-east1-englishplus-testflight.cloudfunctions.net/englishPlusAiProxy
```

- If no Firebase Auth ID token is available, `RemoteAIService` falls back to `MockAIService`.
- User-facing screens still do not show model, key, backend, or debug status.

## Contract Alignment

The AI proxy schema now accepts the full iOS question-type vocabulary used by the current seed data:

```text
multipleChoice
vocabulary
grammar
fillBlank
cloze
translation
sentenceReorder
reading
dialogue
```

## Validation

Round 7 contract validation:

```bash
python3 scripts/validate_round7_ai_service_contract.py
```

Result:

```text
Round 7 AI service contract validation passed
```

Regression validation:

```bash
python3 scripts/validate_round5_ai_proxy_contract.py
python3 scripts/validate_round6_firebase_privacy_contract.py
python3 scripts/validate_windows_handoff_rounds_1_to_6.py
npm --prefix functions run build
```

Result: passed.

iOS build/run validation:

```bash
DEVELOPER_DIR=/Users/zhengyouxi/Downloads/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/EnglishPlus/EnglishPlus.xcodeproj \
  -scheme EnglishPlus \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /Users/zhengyouxi/Documents/Codex/2026-06-15/files-mentioned-by-the-user-english/work/EnglishPlusRound7DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Result: passed.

Simulator install/launch validation:

```text
Installed and launched on simulator 4935AFC4-E765-4863-BB3A-A8616B31CDFC.
Bundle id: com.englishplus
Launch pid: 75090
Screenshot: work/round7-simulator-launch.png
```

## Round 7 Self-Check

- AIService exists: yes
- MockAIService exists and uses local fallback proxy: yes
- RemoteAIService exists and targets Firebase callable proxy: yes
- iOS OpenRouter key exposure: no
- Direct iOS OpenRouter call: no
- Daily mission AI task covered: yes
- Wrong-answer AI task covered: yes
- Emotional support AI task covered: yes
- Teacher/volunteer AI tasks covered: yes
- Practice recommendation AI task covered: yes
