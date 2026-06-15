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
- Built app display name: `English+`.
- Built app bundle identifier: `tw.edu.englishplus`.

## Simulator Run Status

Simulator runtime/device launch could not be completed in this round because `simctl` currently lists no available runtimes or devices:

```text
== Runtimes ==
== Devices ==
```

The app compiles for the iOS Simulator SDK. Once an iOS Simulator runtime and device are available in Xcode, the next step is to boot a simulator, install the built app, and confirm the role-selection screen appears.

## Round 2 Self-Check

- Xcode project exists in repo: yes
- Bundle ID is `tw.edu.englishplus`: yes
- Display name is `English+`: yes
- Required starter folders exist: yes
- Student/teacher/volunteer role shells exist: yes
- Android files preserved: yes
- Simulator build: yes
- Simulator run: blocked by missing simulator runtime/device
- Commit created: yes, as the Round 2 iOS project skeleton checkpoint
- Push completed: yes, after the Round 2 checkpoint commit
