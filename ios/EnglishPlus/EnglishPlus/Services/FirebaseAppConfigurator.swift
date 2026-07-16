import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

enum EnglishPlusBackendMode: Equatable {
    case mock
    case firebase
    case configurationError
}

enum EnglishPlusDeploymentEnvironment: String {
    case competition
    case production

    static let infoPlistKey = "ENGLISHPLUS_DEPLOYMENT_ENVIRONMENT"
    static let expectedFirebaseProjectIDKey = "ENGLISHPLUS_EXPECTED_FIREBASE_PROJECT_ID"

    static var current: EnglishPlusDeploymentEnvironment? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String else {
            return nil
        }
        return EnglishPlusDeploymentEnvironment(rawValue: value)
    }

    static var expectedFirebaseProjectID: String? {
        (Bundle.main.object(forInfoDictionaryKey: expectedFirebaseProjectIDKey) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var expectedAIHost: String {
        switch self {
        case .competition:
            return "englishplus-ai-proxy.englishplus-ray.workers.dev"
        case .production:
            return "englishplus-ai-proxy-production.englishplus-ray.workers.dev"
        }
    }
}

enum EnglishPlusEnvironmentBoundary {
    static func isValid(
        environment: EnglishPlusDeploymentEnvironment?,
        expectedProjectID: String?,
        aiEndpoint: URL?,
        evidenceEndpoint: URL?,
        bundledProjectID: String?
    ) -> Bool {
        guard let environment,
              let expectedProjectID,
              !expectedProjectID.isEmpty,
              let aiEndpoint,
              aiEndpoint.scheme == "https",
              aiEndpoint.host == environment.expectedAIHost,
              let evidenceEndpoint,
              evidenceEndpoint.scheme == "https",
              evidenceEndpoint.host == environment.expectedAIHost
        else {
            return false
        }

        if let bundledProjectID {
            return bundledProjectID == expectedProjectID
        }

        return environment == .competition
    }
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

    static var bundledProjectID: String? {
        guard let bundledConfigPath,
              let data = FileManager.default.contents(atPath: bundledConfigPath),
              let object = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ),
              let dictionary = object as? [String: Any]
        else {
            return nil
        }
        return dictionary["PROJECT_ID"] as? String
    }

    static var hasValidEnvironmentBoundary: Bool {
        EnglishPlusEnvironmentBoundary.isValid(
            environment: EnglishPlusDeploymentEnvironment.current,
            expectedProjectID: EnglishPlusDeploymentEnvironment.expectedFirebaseProjectID,
            aiEndpoint: EnglishPlusAIProxyConfig.workerEndpoint,
            evidenceEndpoint: EvidenceUploadConfig.workerBaseURL,
            bundledProjectID: bundledProjectID
        )
    }

    static func configureIfPossible() -> EnglishPlusBackendMode {
        guard hasValidEnvironmentBoundary else {
            return .configurationError
        }

        // Mock services are selected explicitly by EnglishPlusLaunchConfiguration
        // before this method is called. A real app build must never silently fall
        // back to seed data when its Firebase configuration is missing.
        guard let configPath = bundledConfigPath else {
            return .configurationError
        }

        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            guard let options = FirebaseOptions(contentsOfFile: configPath) else {
                return .configurationError
            }
            FirebaseApp.configure(options: options)
        }
        return FirebaseApp.app() == nil ? .configurationError : .firebase
        #else
        return .configurationError
        #endif
    }
}

enum EnglishPlusServiceFactory {
    @MainActor
    static func makeServices() -> EnglishPlusServiceBundle {
        if EnglishPlusLaunchConfiguration.shouldUseMockServices {
            return makeMockServices()
        }

        let mode = FirebaseAppConfigurator.configureIfPossible()

        switch mode {
        case .firebase:
            let authService = FirebaseAuthService()
            let idTokenProvider: @Sendable () async throws -> String? = {
                try await authService.currentIdToken()
            }
            return EnglishPlusServiceBundle(
                mode: .firebase,
                authService: authService,
                firestoreService: FirebaseFirestoreService(),
                aiService: RemoteAIService(
                    transport: CloudflareWorkerAiProxyTransport(
                        idTokenProvider: idTokenProvider
                    )
                ),
                learningBackend: FirebaseLearningRepository(),
                evidenceUploadService: EvidenceUploadConfig.workerBaseURL.map { baseURL in
                    RemoteEvidenceUploadService(
                        baseURL: baseURL,
                        idTokenProvider: idTokenProvider
                    )
                } ?? UnavailableEvidenceUploadService(),
                volunteerReviewService: EvidenceUploadConfig.workerBaseURL.map { baseURL in
                    RemoteVolunteerReviewService(
                        baseURL: baseURL,
                        idTokenProvider: idTokenProvider
                    )
                } ?? UnavailableVolunteerReviewService(),
                classroomService: EvidenceUploadConfig.workerBaseURL.map { baseURL in
                    RemoteClassroomService(
                        baseURL: baseURL,
                        idTokenProvider: idTokenProvider
                    )
                } ?? UnavailableClassroomService(),
                accountLifecycleService: EvidenceUploadConfig.workerBaseURL.map { baseURL in
                    RemoteAccountLifecycleService(
                        baseURL: baseURL,
                        idTokenProvider: idTokenProvider
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
        case .configurationError:
            return makeMockServices(mode: .configurationError)
        }
    }

    @MainActor
    private static func makeMockServices(
        mode: EnglishPlusBackendMode = .mock
    ) -> EnglishPlusServiceBundle {
        EnglishPlusServiceBundle(
            mode: mode,
            authService: MockAuthService(),
            firestoreService: MockFirestoreService(),
            aiService: MockAIService(),
            learningBackend: MockLearningRepository(),
            evidenceUploadService: UnavailableEvidenceUploadService(),
            volunteerReviewService: UnavailableVolunteerReviewService(),
            classroomService: MockClassroomService(),
            accountLifecycleService: MockAccountLifecycleService(),
            runtimeDiagnostics: RuntimeDiagnosticsSnapshot(
                backendMode: mode,
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
