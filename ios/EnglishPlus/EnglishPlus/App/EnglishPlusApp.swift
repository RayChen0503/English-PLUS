import SwiftUI

@main
struct EnglishPlusApp: App {
    @StateObject private var appState = AppState(authService: MockAuthService())

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
        }
    }
}
