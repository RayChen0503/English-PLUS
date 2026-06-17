import SwiftUI

@main
struct EnglishPlusApp: App {
    @StateObject private var appState = AppState(
        authService: MockAuthService(),
        firestoreService: MockFirestoreService()
    )
    @StateObject private var learningRepository = MockLearningRepository()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(learningRepository)
        }
    }
}
