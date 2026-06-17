import Foundation

struct DailyMissionRulesSeed: SeedLoadable, Equatable {
    static let seedFileName = "daily_mission_rules_seed"

    let schemaVersion: Int
    let timeScaleRules: [TimeScaleRule]
    let goalRules: [MissionGoalRule]
    let defaultPreferredQuestionTypes: [QuestionType]
}

struct TimeScaleRule: Codable, Identifiable, Equatable {
    let timeScale: Int
    let minutes: Int
    let label: String

    var id: Int { timeScale }
}

struct MissionGoalRule: Codable, Identifiable, Equatable {
    let minMinutes: Int
    let maxMinutes: Int?
    let questionGoal: Int

    var id: String {
        if let maxMinutes {
            return "\(minMinutes)-\(maxMinutes)"
        }
        return "\(minMinutes)+"
    }
}
