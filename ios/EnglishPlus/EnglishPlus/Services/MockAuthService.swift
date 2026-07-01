import Foundation

struct MockAuthService: AuthService {
    func demoSession(for role: UserRole) -> AuthSession {
        if let account = SeedData.demoAccount(for: role) {
            return AuthSession(
                user: DemoUser(id: account.id, displayName: account.displayName, role: account.role),
                profile: account
            )
        }

        let fallbackProfile: AppUserProfile
        switch role {
        case .student:
            fallbackProfile = Self.profile(id: "student-demo", displayName: "小安", role: .student)
        case .teacher:
            fallbackProfile = Self.profile(id: "teacher-demo", displayName: "老師", role: .teacher)
        case .volunteer:
            fallbackProfile = Self.profile(id: "volunteer-demo", displayName: "志工", role: .volunteer)
        }

        return AuthSession(
            user: DemoUser(id: fallbackProfile.id, displayName: fallbackProfile.displayName, role: fallbackProfile.role),
            profile: fallbackProfile
        )
    }

    private static func profile(id: String, displayName: String, role: UserRole) -> AppUserProfile {
        let now = Date(timeIntervalSince1970: 1_718_668_800)
        return AppUserProfile(
            id: id,
            displayName: displayName,
            role: role,
            classId: FirebaseBackendConfig.firstClassId,
            groupId: nil,
            consentStatus: .pending,
            isDemo: true,
            createdAt: now,
            updatedAt: now
        )
    }
}
