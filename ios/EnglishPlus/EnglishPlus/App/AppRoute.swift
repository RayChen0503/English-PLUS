import Foundation

enum AppRoute: Equatable {
    case roleSelection
    case demoLogin(UserRole)
    case home(UserRole)
}
