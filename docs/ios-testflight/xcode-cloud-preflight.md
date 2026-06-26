# English+ Xcode Cloud preflight

This checklist is for running English+ through Xcode Cloud or a fresh Mac clone.

## Repo state required

- GitHub branch: `main`
- Xcode project: `ios/EnglishPlus/EnglishPlus.xcodeproj`
- Shared scheme: `EnglishPlus.xcscheme`
- Scheme location: `ios/EnglishPlus/EnglishPlus.xcodeproj/xcshareddata/xcschemes/EnglishPlus.xcscheme`
- Bundle identifier: `tw.edu.englishplus`
- Development team: `SMKVWY55QH`
- Signing style: Automatic
- Export options: `ios/EnglishPlus/Config/ExportOptions.TestFlight.plist`

## Suggested Xcode Cloud workflow

1. Start from App Store Connect or Xcode's Cloud tab.
2. Select the GitHub repository `RayChen0503/English-PLUS`.
3. Select branch `main`.
4. Select project `ios/EnglishPlus/EnglishPlus.xcodeproj`.
5. Select shared scheme `EnglishPlus`.
6. Add a first workflow for pull / branch build:
   - platform: iOS Simulator
   - configuration: Debug
   - action: build
7. Add a release workflow only after signing is clean:
   - platform: iOS
   - configuration: Release
   - action: ArchiveAction
   - distribution: App Store Connect / TestFlight

## Commands a Mac can run before Xcode Cloud

Simulator build:

```bash
xcodebuild \
  -project ios/EnglishPlus/EnglishPlus.xcodeproj \
  -scheme EnglishPlus \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Device build without signing, to separate code problems from signing problems:

```bash
xcodebuild \
  -project ios/EnglishPlus/EnglishPlus.xcodeproj \
  -scheme EnglishPlus \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Signed archive, only after Apple account access works:

```bash
xcodebuild \
  -project ios/EnglishPlus/EnglishPlus.xcodeproj \
  -scheme EnglishPlus \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  archive
```

## Manual boundary

These items cannot be solved by committing code alone:

- Account Holder must keep Apple Developer membership active.
- Account Holder or Admin must accept pending Apple agreements.
- Apple ID two-factor authentication must be completed when Xcode Cloud or Xcode asks.
- App Store Connect app record must exist for `tw.edu.englishplus`.
- Apple Distribution signing and provisioning must be available to Xcode Cloud or the Mac.
- `GoogleService-Info.plist` must be downloaded from Firebase and added to the Xcode target when real Firebase runtime is enabled.
- `OPENROUTER_API_KEY` must be stored only as a Firebase Cloud Functions secret, not inside the iOS app.

## Failure interpretation

- If simulator build fails, treat it as a code/project issue.
- If simulator build passes but archive fails, inspect signing, provisioning, team, bundle id, and App Store Connect state.
- If archive passes but upload fails, inspect App Store Connect role, app record, agreements, export options, and TestFlight processing state.

## Current expectation

The repo is ready for Xcode Cloud discovery through the shared scheme. A real TestFlight
upload still depends on Apple account/signing state and Firebase/OpenRouter secrets for
true backend runtime behavior.
