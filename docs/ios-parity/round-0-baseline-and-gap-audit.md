# English+ iOS Parity Round 0 Baseline And Gap Audit

## Locked GitHub Baseline

- Repository: `RayChen0503/English-PLUS`
- Branch: `main`
- Baseline commit: `f8d4d13`
- Commit title: `Complete Firebase sync AI readiness`
- Commit author: `yusi-1027`
- Commit time: `2026-06-26 09:05:54 +0800`

This commit is the latest verified GitHub baseline for the iOS/TestFlight migration. It already contains the Mac-side handoff work that was pushed to GitHub, including the SwiftUI iOS project, Firebase-ready service boundaries, Firestore-ready repository boundaries, AI proxy-ready service boundaries, Cloud Functions source, and TestFlight preparation documents.

## Source Of Truth

GitHub `main` is the source of truth from this point forward. The previous Mac machine is not required as a source of project files as long as its work remains pushed to this commit or later. Local-only machine state is intentionally not expected in GitHub:

- Apple ID login state
- Xcode signing certificates
- provisioning profiles
- `GoogleService-Info.plist`
- Firebase CLI login state
- OpenRouter API keys
- App Store Connect account session state

## Android parity gaps

The Android product in this repository remains the most complete product reference for user-facing behavior. The iOS project is a strong migration foundation, but it is not yet a full parity copy. The verified gaps before this round are:

1. iOS question bank has only 10 seed questions, while Android generates a 1000+ item CAP-style bank across multiple types and levels.
2. iOS learning map is a placeholder tab, while Android has a personal map with weekly summary, current focus, storage/sync/question-bank status, modules, mistake repair, and support timeline.
3. iOS teacher and volunteer flows are simplified compared with the Android classroom, report, handoff, and queue tools.
4. iOS runtime persistence and sync are Firebase-ready but not yet equivalent to Android SQLite plus sync-center behavior.
5. iOS TestFlight/Xcode Cloud readiness still needs a committed shared scheme and final signing/account work.

## iOS parity plan

Rounds 0 to 2 focus on the student core because it is the product center:

1. Round 0 locks the source-of-truth commit and creates this gap audit.
2. Round 1 expands the iOS seed question bank to at least 1000 approved items, covering vocabulary, grammar, fill blank, cloze, reading, translation, and dialogue across A1, A2, B1, and B2.
3. Round 2 replaces the placeholder learning map with a real SwiftUI student route that reflects today's mission, progress, repair/steady/challenge track, question-bank breadth, and next action.

Later rounds should continue with teacher parity, volunteer parity, persistence/sync parity, report/export parity, and Xcode Cloud/TestFlight hardening.
