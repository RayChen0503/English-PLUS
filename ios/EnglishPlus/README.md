# EnglishPlus iOS Project

This folder contains the native SwiftUI iOS project for English+.

Current Xcode layout:

```text
ios/
  EnglishPlus/
    EnglishPlus.xcodeproj
    EnglishPlus/
      App/
      Core/
      Models/
      Services/
      Data/
      Features/
      Resources/
```

Confirmed project settings:

- Product name: `EnglishPlus`
- App display name: `English+`
- Bundle identifier: `tw.edu.englishplus`
- Organization identifier: `tw.edu`
- Interface: SwiftUI
- Language: Swift
- Initial storage: None

Local simulator build command used in Round 2:

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

The Android prototype remains in the existing Android project folders and should not be moved or removed during iOS setup.
