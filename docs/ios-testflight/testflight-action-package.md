# TestFlight action package

This package is the practical checklist for moving English+ from GitHub `main` to TestFlight.

## What is complete

- Xcode project path: `ios/EnglishPlus/EnglishPlus.xcodeproj`
- Scheme: `EnglishPlus`
- Shared scheme file: `EnglishPlus.xcscheme`
- Bundle ID: `tw.edu.englishplus`
- Team ID: `SMKVWY55QH`
- App name: `English+`
- Export file: `ExportOptions.TestFlight.plist`
- Existing TestFlight docs:
  - `docs/ios-testflight/testflight/app-store-connect-test-info.md`
  - `docs/ios-testflight/testflight/internal-build-release-notes.md`
  - `docs/ios-testflight/testflight/tester-email-template.md`
  - `docs/ios-testflight/xcode-cloud-preflight.md`

## What is not complete yet

- Signed Archive has not been completed in this Windows workspace.
- Upload remains pending.
- TestFlight tester email groups still need final real addresses.
- Privacy policy URL and support URL still need final public URLs before broader testing.
- Runtime Firebase and AI behavior still use mock fallback until the real backend steps are complete.

## Manual boundary

This manual boundary section identifies the Apple-side actions that must be done by an authorized account.

Apple account and App Store Connect actions require an Account Holder, Admin, App Manager, or Developer with the correct role. They cannot be solved by a normal commit.

Required manual abilities:

- Apple ID two-factor authentication.
- App Store Connect access to the app record.
- Apple Developer agreement acceptance.
- Apple Distribution certificate and provisioning access.
- Xcode Cloud or local Xcode permission to use Team `SMKVWY55QH`.

## Manual action order

1. Open GitHub `RayChen0503/English-PLUS`.
2. Confirm branch `main`.
3. Open `ios/EnglishPlus/EnglishPlus.xcodeproj`.
4. Select target `EnglishPlus`.
5. Open Signing & Capabilities.
6. Set Team to the real Developer Team for `SMKVWY55QH`, not Personal Team.
7. Confirm Bundle Identifier is exactly `tw.edu.englishplus`.
8. Keep Automatically manage signing enabled.
9. Confirm `EnglishPlus.xcscheme` appears in the scheme selector.
10. Build for iOS Simulator.
11. Build Release for generic iOS with signing disabled.
12. Create or confirm the App Store Connect app record for `tw.edu.englishplus`.
13. Archive with automatic signing.
14. Distribute through App Store Connect / TestFlight.
15. Add internal tester email groups.

## Failure interpretation

- If Xcode only shows Personal Team, the Apple ID is not seeing the paid Developer Team in Xcode.
- If Xcode says no profiles for `tw.edu.englishplus`, the Bundle ID or provisioning profile is missing or not accessible.
- If Xcode says communication with Apple failed, retry after network, Apple account, or two-factor state is clean.
- If Archive fails but no-sign Release build passes, it is probably signing or provisioning.
- If Upload fails after Archive, check App Store Connect role, app record, agreements, and export options.

## Commands to run

```bash
python scripts/validate_ios_parity_round_8_action_package.py
python scripts/validate_ios_parity_round_7_xcode_cloud.py
python scripts/validate_round8_testflight_preparation.py
```

Mac:

```bash
xcodebuild \
  -project ios/EnglishPlus/EnglishPlus.xcodeproj \
  -scheme EnglishPlus \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

```bash
xcodebuild \
  -project ios/EnglishPlus/EnglishPlus.xcodeproj \
  -scheme EnglishPlus \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  archive
```

## What to send back to Codex

Send one of these exact states:

- "Simulator build failed" plus log.
- "Release no-sign build failed" plus log.
- "Archive failed" plus signing/provisioning log.
- "Upload failed" plus App Store Connect or Organizer error.
- "TestFlight processing failed" plus App Store Connect status.

Also send whether the Team shown in Xcode is `SMKVWY55QH`, Personal Team, or missing.
