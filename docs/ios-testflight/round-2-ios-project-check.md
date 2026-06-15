# Round 2 - iOS Project Skeleton Check

Date: 2026-06-15
Branch: `main`
Repository: `RayChen0503/English-PLUS`

## Result

The native SwiftUI iOS project skeleton now exists under `ios/EnglishPlus`.

## Project Settings

- Xcode project: `ios/EnglishPlus/EnglishPlus.xcodeproj`
- Target: `EnglishPlus`
- Scheme: `EnglishPlus`
- Product name: `EnglishPlus`
- App display name: `English+`
- Bundle identifier: `tw.edu.englishplus`
- Organization identifier target: `tw.edu`
- Interface: SwiftUI
- Language: Swift
- Initial storage: local/mock only
- Device family: iPhone
- Deployment target: iOS 17.0

## Source Structure

Created starter folders:

- `App`
- `Core`
- `Models`
- `Services`
- `Data`
- `Features/RoleSelection`
- `Features/Student`
- `Features/Teacher`
- `Features/Volunteer`
- `Features/Practice`
- `Features/Support`
- `Resources`

## Starter App Flow

The starter app includes:

- Root role selection for student, teacher, and volunteer.
- Demo login entry for each role.
- Student shell with Home, Practice, Support, and Map tabs.
- Teacher shell with Today, Students, and Support tabs.
- Volunteer shell with Relay, Students, and Records tabs.
- Mock auth service and starter seed question data.

Normal user screens do not show Firebase, OpenRouter, API-key, signing, or debug setup status.

## Verification

Xcode used:

```text
/Users/zhengyouxi/Downloads/Xcode.app
```

Build command:

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

- `xcodebuild -list`: succeeded and found target/scheme `EnglishPlus`.
- `Info.plist` lint: passed.
- Generic iOS Simulator build: passed, `BUILD SUCCEEDED`.
- Signed iOS Simulator device build: passed, `BUILD SUCCEEDED`.
- Built app display name: `English+`.
- Built app bundle identifier: `tw.edu.englishplus`.

## Simulator Run Status

Follow-up simulator verification was completed after installing the missing iOS Simulator runtime.

Runtime and test device:

```text
iOS 26.5 (26.5 - 23F77) - com.apple.CoreSimulator.SimRuntime.iOS-26-5
EnglishPlus Test iPhone - 4935AFC4-E765-4863-BB3A-A8616B31CDFC
```

Verification steps completed:

- Installed the iOS 26.5 Simulator runtime.
- Restarted CoreSimulator after the first runtime setup stalled.
- Created a fresh dedicated simulator named `EnglishPlus Test iPhone`.
- Waited for first-boot data migration and system app setup to finish.
- Installed `EnglishPlus.app` into the simulator.
- Confirmed the app bundle exists in the simulator app container.
- Confirmed the `EnglishPlus` process is running.
- Captured a simulator screenshot showing the English+ role-selection screen with student, teacher, and volunteer options.

Note: `simctl launch` did not return promptly even though the app process started successfully. The running process and simulator screenshot confirmed the app was launched.

## Round 2 Self-Check

- Xcode project exists in repo: yes
- Bundle ID is `tw.edu.englishplus`: yes
- Display name is `English+`: yes
- Required starter folders exist: yes
- Student/teacher/volunteer role shells exist: yes
- Android files preserved: yes
- Simulator build: yes
- Simulator run: yes, verified on `EnglishPlus Test iPhone`
- Commit created: yes, as the Round 2 iOS project skeleton checkpoint
- Push completed: yes, after the Round 2 checkpoint commit
