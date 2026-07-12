import Foundation

struct AuthSession: Equatable {
    let user: DemoUser
    let profile: AppUserProfile
}

enum AccountCreationOutcome: Equatable {
    case authenticated(AuthSession)
    case emailVerificationRequired(email: String)
    case approvalPending(email: String, role: UserRole)
}

enum AuthServiceError: Error, Equatable {
    case invalidEmail
    case invalidCredentials
    case weakPassword
    case emailAlreadyInUse
    case emailNotVerified(email: String)
    case accountDisabled
    case accountPendingApproval
    case profileUnavailable
    case roleMismatch(expected: UserRole, actual: UserRole)
    case staffSelfServiceUnavailable
    case missingTeacherAffiliation
    case invalidVolunteerApplication
    case identityAlreadyLinked
    case identityProviderUnavailable
    case invalidClassSelection
    case networkUnavailable
    case tooManyRequests
    case operationUnavailable

    var userMessage: String {
        switch self {
        case .invalidEmail:
            return "請輸入有效的 email。"
        case .invalidCredentials:
            return "帳號或密碼不正確，請再確認一次。"
        case .weakPassword:
            return "密碼至少需要 8 碼。"
        case .emailAlreadyInUse:
            return "這個 email 已經建立過帳號，請直接登入或重設密碼。"
        case .emailNotVerified:
            return "請先到信箱完成驗證，再回來登入。"
        case .accountDisabled:
            return "這個帳號目前無法使用，請聯絡管理者。"
        case .accountPendingApproval:
            return "這個工作端帳號仍在等待管理者核准。"
        case .profileUnavailable:
            return "帳號資料尚未準備完成，請聯絡管理者。"
        case .roleMismatch(_, let actual):
            return "這個帳號屬於\(actual.title)端，請返回並選擇\(actual.title)。"
        case .staffSelfServiceUnavailable:
            return "這個帳號類型目前無法自行註冊。"
        case .missingTeacherAffiliation:
            return "請先選擇任職的學校或教育機構。"
        case .invalidVolunteerApplication:
            return "志工申請資料尚未完整，請確認年齡、守則與證明資料。"
        case .identityAlreadyLinked:
            return "這個登入方式已連結到其他帳號。"
        case .identityProviderUnavailable:
            return "這個登入方式目前無法使用，請稍後再試或改用其他方式。"
        case .invalidClassSelection:
            return "無法切換班級，請確認你仍是該班級成員。"
        case .networkUnavailable:
            return "目前無法連線，請檢查網路後再試。"
        case .tooManyRequests:
            return "嘗試次數過多，請稍後再試。"
        case .operationUnavailable:
            return "目前無法完成這個操作，請稍後再試。"
        }
    }
}

protocol AuthService {
    func demoSession(for role: UserRole) -> AuthSession
    func signInDemoAccount(for role: UserRole) async throws -> AuthSession
    func signIn(email: String, password: String, expectedRole: UserRole) async throws -> AuthSession
    func createAccount(_ registration: AccountRegistration) async throws -> AccountCreationOutcome
    func signIn(
        with credential: FederatedIdentityCredential,
        expectedRole: UserRole
    ) async throws -> AuthSession
    func createAccount(
        with credential: FederatedIdentityCredential,
        profile: RoleOnboardingProfile
    ) async throws -> AccountCreationOutcome
    func linkIdentity(
        _ credential: FederatedIdentityCredential,
        to session: AuthSession
    ) async throws -> AuthSession
    func sendPasswordReset(email: String) async throws
    func resendVerification(email: String, password: String) async throws
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
            throw AuthServiceError.invalidCredentials
        }
        return demoSession(for: expectedRole)
    }

    func createAccount(
        email: String,
        password: String,
        displayName: String,
        role: UserRole
    ) async throws -> AccountCreationOutcome {
        try await createAccount(
            AccountRegistration(
                email: email,
                password: password,
                displayName: displayName,
                role: role,
                teacherAffiliation: nil,
                volunteerApplication: nil
            )
        )
    }

    func signIn(
        with credential: FederatedIdentityCredential,
        expectedRole: UserRole
    ) async throws -> AuthSession {
        throw AuthServiceError.identityProviderUnavailable
    }

    func createAccount(
        with credential: FederatedIdentityCredential,
        profile: RoleOnboardingProfile
    ) async throws -> AccountCreationOutcome {
        throw AuthServiceError.identityProviderUnavailable
    }

    func linkIdentity(
        _ credential: FederatedIdentityCredential,
        to session: AuthSession
    ) async throws -> AuthSession {
        throw AuthServiceError.identityProviderUnavailable
    }

    func sendPasswordReset(email: String) async throws {}

    func resendVerification(email: String, password: String) async throws {}

    func restorePreviousSession() async throws -> AuthSession? {
        nil
    }

    func selectActiveClass(_ classId: String?, in session: AuthSession) async throws -> AuthSession {
        guard let profile = session.profile.selectingClass(classId) else {
            throw AuthServiceError.invalidClassSelection
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
