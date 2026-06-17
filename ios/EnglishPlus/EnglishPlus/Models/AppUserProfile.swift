import Foundation

enum ConsentStatus: String, Codable {
    case demo
    case pending
    case granted
    case declined
}

struct AppUserProfile: Identifiable, Codable, Equatable {
    let id: String
    let displayName: String
    let role: UserRole
    let classId: String
    let groupId: String?
    let consentStatus: ConsentStatus
    let isDemo: Bool
    let createdAt: Date
    let updatedAt: Date
}

struct AccountsSeed: SeedLoadable {
    static let seedFileName = "accounts_seed"

    let schemaVersion: Int
    let accounts: [AppUserProfile]
}
