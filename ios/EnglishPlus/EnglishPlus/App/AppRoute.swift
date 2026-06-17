import Foundation

enum AppRoute: Equatable {
    case roleSelection
    case demoLogin(UserRole)
    case privacyConsent(UserRole)
    case home(UserRole)
}
