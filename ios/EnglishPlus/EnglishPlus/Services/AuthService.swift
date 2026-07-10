import Foundation

struct AuthSession: Equatable {
    let user: DemoUser
    let profile: AppUserProfile
}

protocol AuthService {
    func demoSession(for role: UserRole) -> AuthSession
    func signInDemoAccount(for role: UserRole) async throws -> AuthSession
    func signIn(email: String, password: String, expectedRole: UserRole) async throws -> AuthSession
    func createAccount(
        email: String,
        password: String,
        displayName: String,
        role: UserRole
    ) async throws -> AuthSession
    func restorePreviousSession() async throws -> AuthSession?
    func selectActiveClass(_ classId: String?, in session: AuthSession) async throws -> AuthSession
    func signOut()
}

extension AuthService {
    func signInDemoAccount(for role: UserRole) async throws -> AuthSession {
        let credential = DemoAccountCredential.credential(for: role)
        return try await signIn(
            email: credential.email,
            password: credential.password,
            expectedRole: role
        )
    }

    func signIn(email: String, password: String, expectedRole: UserRole) async throws -> AuthSession {
        let credential = DemoAccountCredential.credential(for: expectedRole)
        guard
            email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == credential.email,
            password == credential.password
        else {
            throw DemoAuthError.invalidCredential
        }
        return demoSession(for: expectedRole)
    }

    func createAccount(
        email: String,
        password: String,
        displayName: String,
        role: UserRole
    ) async throws -> AuthSession {
        throw DemoAuthError.accountCreationUnavailable
    }

    func restorePreviousSession() async throws -> AuthSession? {
        nil
    }

    func selectActiveClass(_ classId: String?, in session: AuthSession) async throws -> AuthSession {
        guard let profile = session.profile.selectingClass(classId) else {
            throw DemoAuthError.invalidClassSelection
        }
        return AuthSession(
            user: DemoUser(
                id: session.user.id,
                displayName: session.user.displayName,
                role: profile.role
            ),
            profile: profile
        )
    }

    func signOut() {}
}

enum DemoAuthError: Error, Equatable {
    case invalidCredential
    case accountCreationUnavailable
    case invalidClassSelection
}

struct DemoAccountCredential: Equatable {
    let role: UserRole
    let email: String
    let password: String

    static func credential(for role: UserRole) -> DemoAccountCredential {
        switch role {
        case .student:
            return DemoAccountCredential(
                role: .student,
                email: "student.demo@englishplus.test",
                password: "EnglishPlusStudent2026!"
            )
        case .teacher:
            return DemoAccountCredential(
                role: .teacher,
                email: "teacher.demo@englishplus.test",
                password: "EnglishPlusTeacher2026!"
            )
        case .volunteer:
            return DemoAccountCredential(
                role: .volunteer,
                email: "volunteer.demo@englishplus.test",
                password: "EnglishPlusVolunteer2026!"
            )
        }
    }
}
