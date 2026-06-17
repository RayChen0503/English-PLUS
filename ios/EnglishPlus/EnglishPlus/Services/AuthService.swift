import Foundation

struct AuthSession: Equatable {
    let user: DemoUser
    let profile: AppUserProfile
}

protocol AuthService {
    func demoSession(for role: UserRole) -> AuthSession
}
