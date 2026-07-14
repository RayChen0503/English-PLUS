import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

enum EnglishPlusBackendMode: Equatable {
    case mock
    case firebase
}

struct EnglishPlusServiceBundle {
    let mode: EnglishPlusBackendMode
    let authService: AuthService
    let firestoreService: FirestoreService
    let aiService: AIService
    let learningBackend: any LearningRepositoryBackend
    let evidenceUploadService: EvidenceUploadService
    let volunteerReviewService: VolunteerReviewService
    let classroomService: ClassroomService
    let accountLifecycleService: AccountLifecycleService
    let runtimeDiagnostics: RuntimeDiagnosticsSnapshot
}

enum FirebaseAppConfigurator {
    static var bundledConfigPath: String? {
        Bundle.main.path(
            forResource: "GoogleService-Info",
            ofType: "plist"
        )
    }

    static var hasBundledConfig: Bool {
        bundledConfigPath != nil
    }

    static func configureIfPossible() -> EnglishPlusBackendMode {
        guard let configPath = bundledConfigPath else {
            return .mock
        }

        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            guard let options = FirebaseOptions(contentsOfFile: configPath) else {
                return .mock
            }
            FirebaseApp.configure(options: options)
        }
        return FirebaseApp.app() == nil ? .mock : .firebase
        #else
        return .mock
        #endif
    }
}

enum EnglishPlusServiceFactory {
    @MainActor
    static func makeServices() -> EnglishPlusServiceBundle {
        if EnglishPlusLaunchConfiguration.isUITesting {
            return makeMockServices()
        }

        let mode = FirebaseAppConfigurator.configureIfPossible()

        switch mode {
        case .firebase:
            let authService = FirebaseAuthService()
            return EnglishPlusServiceBundle(
                mode: .firebase,
                authService: authService,
                firestoreService: FirebaseFirestoreService(),
                aiService: RemoteAIService(
                    transport: CloudflareWorkerAiProxyTransport(
                        idTokenProvider: authService.currentIdToken
                    )
                ),
                learningBackend: FirebaseLearningRepository(),
                evidenceUploadService: EvidenceUploadConfig.workerBaseURL.map { baseURL in
                    RemoteEvidenceUploadService(
                        baseURL: baseURL,
                        idTokenProvider: authService.currentIdToken
                    )
                } ?? UnavailableEvidenceUploadService(),
                volunteerReviewService: EvidenceUploadConfig.workerBaseURL.map { baseURL in
                    RemoteVolunteerReviewService(
                        baseURL: baseURL,
                        idTokenProvider: authService.currentIdToken
                    )
                } ?? UnavailableVolunteerReviewService(),
                classroomService: EvidenceUploadConfig.workerBaseURL.map { baseURL in
                    RemoteClassroomService(
                        baseURL: baseURL,
                        idTokenProvider: authService.currentIdToken
                    )
                } ?? UnavailableClassroomService(),
                accountLifecycleService: EvidenceUploadConfig.workerBaseURL.map { baseURL in
                    RemoteAccountLifecycleService(
                        baseURL: baseURL,
                        idTokenProvider: authService.currentIdToken
                    )
                } ?? UnavailableAccountLifecycleService(),
                runtimeDiagnostics: RuntimeDiagnosticsSnapshot(
                    backendMode: .firebase,
                    hasFirebaseConfig: FirebaseAppConfigurator.hasBundledConfig,
                    authProvider: "FirebaseAuthService",
                    firestoreProvider: "FirebaseFirestoreService",
                    learningProvider: "FirebaseLearningRepository",
                    aiProvider: "RemoteAIService",
                    aiProxyEndpoint: EnglishPlusAIProxyConfig.workerEndpoint?.absoluteString
                )
            )
        case .mock:
            return makeMockServices()
        }
    }

    @MainActor
    private static func makeMockServices() -> EnglishPlusServiceBundle {
        EnglishPlusServiceBundle(
            mode: .mock,
            authService: MockAuthService(),
            firestoreService: MockFirestoreService(),
            aiService: MockAIService(),
            learningBackend: MockLearningRepository(),
            evidenceUploadService: UnavailableEvidenceUploadService(),
            volunteerReviewService: UnavailableVolunteerReviewService(),
            classroomService: MockClassroomService(),
            accountLifecycleService: MockAccountLifecycleService(),
            runtimeDiagnostics: RuntimeDiagnosticsSnapshot(
                backendMode: .mock,
                hasFirebaseConfig: FirebaseAppConfigurator.hasBundledConfig,
                authProvider: "MockAuthService",
                firestoreProvider: "MockFirestoreService",
                learningProvider: "MockLearningRepository",
                aiProvider: "MockAIService",
                aiProxyEndpoint: EnglishPlusAIProxyConfig.workerEndpoint?.absoluteString
            )
        )
    }
}
