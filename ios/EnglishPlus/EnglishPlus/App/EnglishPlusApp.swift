import SwiftUI

@main
struct EnglishPlusApp: App {
    @StateObject private var appState: AppState
    @StateObject private var learningRepository: LearningRepositoryStore

    init() {
        let services = EnglishPlusServiceFactory.makeServices()
        _appState = StateObject(
            wrappedValue: AppState(
                authService: services.authService,
                firestoreService: services.firestoreService,
                aiService: services.aiService,
                evidenceUploadService: services.evidenceUploadService,
                volunteerReviewService: services.volunteerReviewService,
                runtimeDiagnostics: services.runtimeDiagnostics
            )
        )
        _learningRepository = StateObject(
            wrappedValue: LearningRepositoryStore(backend: services.learningBackend)
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(learningRepository)
                .onOpenURL(perform: FederatedSignInCoordinator.handleOpenURL)
        }
    }
}
