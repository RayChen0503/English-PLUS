# TestFlight action package

This package is the practical checklist for moving English+ from GitHub `main` to TestFlight.

## What is complete

- Xcode project path: `ios/EnglishPlus/EnglishPlus.xcodeproj`
- Scheme: `EnglishPlus`
- Shared scheme file: `EnglishPlus.xcscheme`
- Bundle ID: `com.englishplus`
- Team ID: `X7Y2V4D87G`
- App name: `English+`
- Export file: `ExportOptions.TestFlight.plist`
- A previous `main` build has completed the Xcode Cloud/TestFlight pipeline.
- Runtime Firebase authentication, Firestore synchronization and the
  authenticated Cloudflare/Groq AI route are implemented and verified.
- Privacy policy:
  `https://sites.google.com/view/englishplus-privacy/%E9%9A%B1%E7%A7%81%E6%94%BF%E7%AD%96`
- Support URL:
  `https://sites.google.com/view/englishplus-privacy/%E6%94%AF%E6%8F%B4%E8%88%87%E8%81%AF%E7%B5%A1`
- Support email: `englishplus.tw@gmail.com`
- Existing TestFlight docs:
  - `docs/ios-testflight/testflight/app-store-connect-test-info.md`
  - `docs/ios-testflight/testflight/internal-build-release-notes.md`
  - `docs/ios-testflight/testflight/tester-email-template.md`
  - `docs/ios-testflight/xcode-cloud-preflight.md`

## What remains for each release candidate

- TestFlight tester email groups still need final real addresses.
- App Store Connect privacy answers must be entered or rechecked against
  `docs/ios-testflight/privacy/app-privacy-label-draft.md`.
- App Review credentials and instructions must be entered privately in App
  Store Connect; never commit passwords to Git.
- Each hardening block must pass its branch checks before one deliberate merge
  to `main` triggers Xcode Cloud.

## Manual boundary

This manual boundary section identifies the Apple-side actions that must be done by an authorized account.

Apple account and App Store Connect actions require an Account Holder, Admin, App Manager, or Developer with the correct role. They cannot be solved by a normal commit.

Required manual abilities:

- Apple ID two-factor authentication.
- App Store Connect access to the app record.
- Apple Developer agreement acceptance.
- Apple Distribution certificate and provisioning access.
- Xcode Cloud or local Xcode permission to use Team `X7Y2V4D87G`.

## Manual action order

1. Open GitHub `RayChen0503/English-PLUS`.
2. Confirm branch `main`.
3. Open `ios/EnglishPlus/EnglishPlus.xcodeproj`.
4. Select target `EnglishPlus`.
5. Open Signing & Capabilities.
6. Set Team to the real Developer Team for `X7Y2V4D87G`, not Personal Team.
7. Confirm Bundle Identifier is exactly `com.englishplus`.
8. Keep Automatically manage signing enabled.
9. Confirm `EnglishPlus.xcscheme` appears in the scheme selector.
10. Build for iOS Simulator.
11. Build Release for generic iOS with signing disabled.
12. Create or confirm the App Store Connect app record for `com.englishplus`.
13. Archive with automatic signing.
14. Distribute through App Store Connect / TestFlight.
15. Add internal tester email groups.

## Failure interpretation

- If Xcode only shows Personal Team, the Apple ID is not seeing the paid Developer Team in Xcode.
- If Xcode says no profiles for `com.englishplus`, the Bundle ID or provisioning profile is missing or not accessible.
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

Also send whether the Team shown in Xcode is `X7Y2V4D87G`, Personal Team, or missing.
