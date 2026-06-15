import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var route: AppRoute = .roleSelection
    @Published var selectedRole: UserRole?
    @Published var currentUser: DemoUser?
    @Published var hasAcceptedConsent = false

    private let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }

    func chooseRole(_ role: UserRole) {
        selectedRole = role
        route = .demoLogin(role)
    }

    func signInForSelectedRole() {
        guard let selectedRole else { return }
        currentUser = authService.demoUser(for: selectedRole)
        hasAcceptedConsent = true
        route = .home(selectedRole)
    }

    func signOut() {
        selectedRole = nil
        currentUser = nil
        hasAcceptedConsent = false
        route = .roleSelection
    }
}
