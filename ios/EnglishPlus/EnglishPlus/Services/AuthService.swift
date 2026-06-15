import Foundation

protocol AuthService {
    func demoUser(for role: UserRole) -> DemoUser
}
