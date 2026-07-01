# Round 8 - TestFlight Preparation Check

Date: 2026-06-18  
Branch: `main`  
Repository: `RayChen0503/English-PLUS`

## Source Of Truth

This round follows the Windows handoff log Round 8:

```text
TestFlight preparation
Fix signing
Set Team / Bundle ID
Archive
Upload to App Store Connect if possible
Create TestFlight testing information
Prepare tester email flow
Generate internal beta release notes
If Apple ID 2FA, agreements, payment, or permissions block progress, pause and ask the user
Build/run check, commit/push
```

## Completed Repo Preparation

| Item | Status |
| --- | --- |
| Bundle ID | `com.englishplus` confirmed in Xcode project |
| App display name | `English+` confirmed in `Info.plist` |
| Version/build | `1.0 (3)` confirmed |
| Target device | iPhone-only target confirmed |
| Signing style | Automatic signing confirmed |
| Team | `X7Y2V4D87G` set in Debug and Release build settings |
| Export options | `ios/EnglishPlus/Config/ExportOptions.TestFlight.plist` added |
| TestFlight test info | `docs/ios-testflight/testflight/app-store-connect-test-info.md` added |
| Tester email flow | `docs/ios-testflight/testflight/tester-email-template.md` added |
| Internal build notes | `docs/ios-testflight/testflight/internal-build-release-notes.md` added |

## Local Signing State

The local keychain contains an Apple Development signing identity:

```text
Apple Development: Yuju Tang (X7Y2V4D87G)
```

No local provisioning profiles were present before the archive attempt. No Apple Distribution signing identity was present in the local keychain during this round.

## Archive / Upload Boundary

Archive was attempted on this Mac with:

```bash
DEVELOPER_DIR=/Users/zhengyouxi/Downloads/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/EnglishPlus/EnglishPlus.xcodeproj \
  -scheme EnglishPlus \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath /Users/zhengyouxi/Documents/Codex/2026-06-15/files-mentioned-by-the-user-english/work/EnglishPlusRound8.xcarchive \
  -derivedDataPath /Users/zhengyouxi/Documents/Codex/2026-06-15/files-mentioned-by-the-user-english/work/EnglishPlusRound8ArchiveDerivedData \
  -allowProvisioningUpdates \
  archive
```

Result:

```text
ARCHIVE FAILED
No Account for Team "X7Y2V4D87G".
No profiles for 'com.englishplus' were found.
```

App Store Connect upload was not attempted because there is no signed archive to export/upload.

If archive or upload is blocked by Apple ID two-factor authentication, missing App Store Connect permission, missing Apple Distribution certificate, missing provisioning profile, paid account agreements, or other Account Holder actions, that is considered a handoff blocker rather than an iOS code blocker.

To separate signing/account issues from code issues, a Release iPhoneOS build without code signing was also run:

```bash
DEVELOPER_DIR=/Users/zhengyouxi/Downloads/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/EnglishPlus/EnglishPlus.xcodeproj \
  -scheme EnglishPlus \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath /Users/zhengyouxi/Documents/Codex/2026-06-15/files-mentioned-by-the-user-english/work/EnglishPlusRound8DeviceNoSignDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Result:

```text
BUILD SUCCEEDED
```

## Validation Commands

```bash
python3 scripts/validate_round8_testflight_preparation.py
python3 scripts/validate_windows_handoff_rounds_1_to_8.py
```

Regression validation:

```bash
python3 scripts/validate_ios_seed.py
python3 scripts/validate_round5_ai_proxy_contract.py
python3 scripts/validate_round6_firebase_privacy_contract.py
python3 scripts/validate_round7_ai_service_contract.py
npm --prefix functions run build
git diff --check
```

Simulator validation:

```bash
DEVELOPER_DIR=/Users/zhengyouxi/Downloads/Xcode.app/Contents/Developer \
xcodebuild \
  -project ios/EnglishPlus/EnglishPlus.xcodeproj \
  -scheme EnglishPlus \
  -configuration Debug \
  -destination 'id=4935AFC4-E765-4863-BB3A-A8616B31CDFC' \
  -derivedDataPath /Users/zhengyouxi/Documents/Codex/2026-06-15/files-mentioned-by-the-user-english/work/EnglishPlusRound8RunDerivedData \
  build
```

Result:

```text
BUILD SUCCEEDED
Installed and launched on simulator 4935AFC4-E765-4863-BB3A-A8616B31CDFC.
Bundle id: com.englishplus
Launch pid: 88027
Screenshot: work/round8-simulator-launch.png
```

## Round 8 Self-Check

- Signing style automatic: yes
- Development Team configured: yes
- Bundle ID correct: yes
- App display name correct: yes
- Archive attempted: yes, blocked by Apple account/provisioning profile availability
- App Store Connect upload attempted if archive succeeds: no, because archive did not produce a signed archive
- Release iPhoneOS code build without signing: passed
- Tester information prepared: yes
- Tester email flow prepared: yes
- Internal beta release notes prepared: yes
- User-facing debug/backend/key text avoided: covered by previous flow checks and manual screenshot review
