import SwiftUI

@main
struct EnglishPlusApp: App {
    @StateObject private var appState: AppState
    @StateObject private var learningRepository: LearningRepositoryStore

    init() {
        EnglishPlusLaunchConfiguration.prepareProcessIfNeeded()
        let services = EnglishPlusServiceFactory.makeServices()
        _appState = StateObject(
            wrappedValue: AppState(
                authService: services.authService,
                firestoreService: services.firestoreService,
                aiService: services.aiService,
                evidenceUploadService: services.evidenceUploadService,
                volunteerReviewService: services.volunteerReviewService,
                classroomService: services.classroomService,
                accountLifecycleService: services.accountLifecycleService,
                runtimeDiagnostics: services.runtimeDiagnostics
            )
        )
        let connectivityMonitor: any NetworkConnectivityMonitoring
        if EnglishPlusLaunchConfiguration.shouldUseMockServices {
            connectivityMonitor = LaunchArgumentNetworkConnectivityMonitor(
                status: EnglishPlusLaunchConfiguration.shouldStartOffline
                    ? .disconnected
                    : .connected
            )
        } else {
            connectivityMonitor = NetworkConnectivityMonitor()
        }
        _learningRepository = StateObject(
            wrappedValue: LearningRepositoryStore(
                backend: services.learningBackend,
                connectivityMonitor: connectivityMonitor
            )
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
