# Round 7 - Xcode Cloud and TestFlight hardening

## Purpose

Round 7 closes the repo-side gap for Xcode Cloud and TestFlight hardening.

Previous rounds already prepared signing settings, ExportOptions, tester notes, and
TestFlight metadata. The remaining repo-side issue was that the Xcode scheme existed
only as local Xcode state. Xcode Cloud, a teammate's Mac, or a fresh clone needs a
committed shared scheme.

## What changed

- Added the shared scheme:
  - `ios/EnglishPlus/EnglishPlus.xcodeproj/xcshareddata/xcschemes/EnglishPlus.xcscheme`
- The shared scheme points to:
  - target: `EnglishPlus`
  - product: `EnglishPlus.app`
  - bundle id: `com.englishplus`
  - team: `X7Y2V4D87G` through project build settings
- The scheme supports:
  - BuildAction
  - TestAction
  - LaunchAction
  - ProfileAction
  - AnalyzeAction
  - ArchiveAction
- `ArchiveAction` uses Release configuration for TestFlight upload preparation.

## Xcode Cloud impact

With `EnglishPlus.xcscheme` committed, Xcode Cloud can discover the project scheme from
GitHub without relying on a local Mac's user data.

The intended Xcode Cloud workflow is:

1. checkout GitHub `main`
2. open `ios/EnglishPlus/EnglishPlus.xcodeproj`
3. use shared scheme `EnglishPlus`
4. build Debug for simulator smoke checks
5. archive Release for App Store Connect / TestFlight

## Still manual boundary

This round does not bypass Apple account requirements. The following still need Account
Holder or authorized Apple Developer / App Store Connect access:

- Apple Developer agreements and membership state
- Xcode Cloud enablement for the app
- Apple Distribution certificate / provisioning availability
- App Store Connect app record for `com.englishplus`
- TestFlight internal group setup
- `GoogleService-Info.plist` for real Firebase runtime
- Cloud Functions secret `OPENROUTER_API_KEY`

Those are Apple/Firebase account operations, not source-code operations.

## Validation

Windows can validate the repo-side hardening with:

```bash
python scripts/validate_ios_parity_round_7_xcode_cloud.py
python scripts/validate_round8_testflight_preparation.py
```

Mac/Xcode or Xcode Cloud should later validate the actual archive path with:

```bash
xcodebuild \
  -project ios/EnglishPlus/EnglishPlus.xcodeproj \
  -scheme EnglishPlus \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -allowProvisioningUpdates \
  archive
```

If that fails for signing, treat it as an account/provisioning blocker unless a normal
simulator build also fails.
