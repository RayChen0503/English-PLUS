import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

enum FirebaseAuthServiceError: Error, Equatable {
    case firebaseSDKUnavailable
    case noAuthenticatedUser
    case missingSeedProfile(String)
}

struct FirebaseAuthService: AuthService {
    private let fallback: MockAuthService

    init(fallback: MockAuthService = MockAuthService()) {
        self.fallback = fallback
    }

    func demoSession(for role: UserRole) -> AuthSession {
        fallback.demoSession(for: role)
    }

    func currentIdToken() async throws -> String? {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            throw FirebaseAuthServiceError.noAuthenticatedUser
        }
        return try await user.getIDToken()
        #else
        throw FirebaseAuthServiceError.firebaseSDKUnavailable
        #endif
    }

    func currentSession() async throws -> AuthSession? {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            return nil
        }
        guard let account = SeedData.current.accounts.first(where: { $0.id == user.uid }) else {
            throw FirebaseAuthServiceError.missingSeedProfile(user.uid)
        }
        return AuthSession(
            user: DemoUser(
                id: user.uid,
                displayName: account.displayName,
                role: account.role
            ),
            profile: account
        )
        #else
        throw FirebaseAuthServiceError.firebaseSDKUnavailable
        #endif
    }
}
