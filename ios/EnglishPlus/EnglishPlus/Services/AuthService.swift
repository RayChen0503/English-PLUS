import Foundation

struct AuthSession: Equatable {
    let user: DemoUser
    let profile: AppUserProfile
}

protocol AuthService {
    func demoSession(for role: UserRole) -> AuthSession
    func signInDemoAccount(for role: UserRole) async throws -> AuthSession
    func restorePreviousSession() async throws -> AuthSession?
    func signOut()
}

extension AuthService {
    func signInDemoAccount(for role: UserRole) async throws -> AuthSession {
        demoSession(for: role)
    }

    func restorePreviousSession() async throws -> AuthSession? {
        nil
    }

    func signOut() {}
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
