import Foundation

enum SupportRoute: String, Codable {
    case aiCoach
    case humanHandoff
    case readingBreakdown
    case recovery
}

struct SupportOption: Identifiable, Codable, Equatable {
    let id: String
    let reason: String
    let studentText: String
    let platformAction: String
    let route: SupportRoute
}

struct SupportOptionsSeed: SeedLoadable {
    static let seedFileName = "support_options_seed"

    let schemaVersion: Int
    let supportOptions: [SupportOption]
}
