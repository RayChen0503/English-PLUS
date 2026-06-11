# Firebase iOS Setup For Teammate

This file explains what the Mac teammate should do when Firebase is ready.

## Values To Use

| Item | Value |
| --- | --- |
| Firebase project ID | `englishplus-testflight` |
| Firebase display name | `English+` |
| iOS Bundle ID | `tw.edu.englishplus` |
| Xcode project | `EnglishPlus` |
| App display name | `English+` |
| Config file | `GoogleService-Info.plist` |

## If Firebase Project Is Not Ready Yet

Continue building the SwiftUI app with local/mock services.

Do not block UI work on Firebase.

## If Firebase Project Is Ready

1. Open Firebase Console.
2. Open project `englishplus-testflight`.
3. Add an Apple app.
4. Bundle ID:

```text
tw.edu.englishplus
```

5. Download:

```text
GoogleService-Info.plist
```

6. Drag the file into the root of the Xcode app target.
7. Make sure the file is included in the app target.

## Add SDK With Swift Package Manager

In Xcode:

```text
File > Add Packages
```

Repository:

```text
https://github.com/firebase/firebase-ios-sdk
```

Add:

```text
FirebaseCore
FirebaseAuth
FirebaseFirestore
FirebaseFunctions
```

## Configure In App Startup

Create `AppDelegate.swift`:

```swift
import FirebaseCore
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
```

Update `EnglishPlusApp.swift`:

```swift
import SwiftUI

@main
struct EnglishPlusApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            RoleChoiceView()
        }
    }
}
```

## Keep A Local Fallback

Even after Firebase is added, keep local services available:

```text
LocalSeedService
DemoAuthService
LocalMissionEngine
```

This makes it possible to demo the app even if Firebase is offline or not fully configured.

## Do Not Do This

Do not put OpenRouter keys in Swift files.

Do not paste production secrets into Xcode build settings.

Do not send real student names to OpenRouter from the client.

AI calls should go:

```text
iOS app -> Firebase Cloud Function -> OpenRouter
```
