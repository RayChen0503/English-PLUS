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
}

enum FirebaseAppConfigurator {
    static var hasBundledConfig: Bool {
        Bundle.main.path(
            forResource: "GoogleService-Info",
            ofType: "plist"
        ) != nil
    }

    static func configureIfPossible() -> EnglishPlusBackendMode {
        guard hasBundledConfig else {
            return .mock
        }

        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
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
                learningBackend: FirebaseLearningRepository()
            )
        case .mock:
            return EnglishPlusServiceBundle(
                mode: .mock,
                authService: MockAuthService(),
                firestoreService: MockFirestoreService(),
                aiService: MockAIService(),
                learningBackend: MockLearningRepository()
            )
        }
    }
}
