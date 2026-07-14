import Foundation

struct MockAuthService: AuthService, Sendable {
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

    func createAccount(_ registration: AccountRegistration) async throws -> AccountCreationOutcome {
        let cleanedEmail = registration.normalizedEmail
        let cleanedName = registration.normalizedDisplayName
        guard cleanedEmail.contains("@"), cleanedEmail.contains("."), !cleanedName.isEmpty else {
            throw AuthServiceError.invalidEmail
        }
        guard registration.password.count >= 8 else {
            throw AuthServiceError.weakPassword
        }
        guard registration.hasRequiredRoleDetails else {
            switch registration.role {
            case .student:
                throw AuthServiceError.profileUnavailable
            case .teacher:
                throw AuthServiceError.missingTeacherAffiliation
            case .volunteer:
                throw AuthServiceError.invalidVolunteerApplication
            }
        }

        let profileId = cleanedEmail.replacingOccurrences(of: "@", with: "-")
        let now = Date()
        let profile = AppUserProfile(
            id: profileId,
            displayName: cleanedName,
            role: registration.role,
            classId: FirebaseBackendConfig.personalScopeId(uid: profileId),
            groupId: nil,
            consentStatus: .pending,
            isDemo: false,
            accountStatus: registration.role == .volunteer ? .pendingApplication : .active,
            createdAt: now,
            updatedAt: now,
            memberships: [],
            activeClassId: nil
        )
        if registration.role == .volunteer {
            if registration.volunteerApplication?.isReadyToSubmit == true {
                return .approvalPending(email: cleanedEmail, role: .volunteer)
            }
            return .authenticated(
                AuthSession(
                    user: DemoUser(
                        id: profile.id,
                        displayName: profile.displayName,
                        role: profile.role
                    ),
                    profile: profile
                )
            )
        }

        return .authenticated(
            AuthSession(
                user: DemoUser(id: profile.id, displayName: profile.displayName, role: profile.role),
                profile: profile
            )
        )
    }

    func submitVolunteerApplication(
        _ application: VolunteerApplicationInput,
        in session: AuthSession
    ) async throws -> AccountCreationOutcome {
        guard session.user.role == .volunteer, application.isReadyToSubmit else {
            throw AuthServiceError.invalidVolunteerApplication
        }
        return .approvalPending(email: "", role: .volunteer)
    }

    func loadVolunteerApplication(
        in session: AuthSession
    ) async throws -> VolunteerApplicationInput? {
        guard session.user.role == .volunteer else { return nil }
        return VolunteerApplicationInput(
            confirmsAge18OrOlder: true,
            acceptedConductVersion: "volunteer-conduct-v1",
            motivation: "",
            evidence: []
        )
    }

    func currentUserIsAdministrator() async -> Bool { false }

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
