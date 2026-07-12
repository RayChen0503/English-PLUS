import Foundation

struct SeedManifest: SeedLoadable, Equatable {
    static let seedFileName = "seed_manifest"

    let app: String
    let seedSchemaVersion: Int
    let generatedFrom: String
    let generatedAt: Date
    let files: [String]
}

struct SeedDataSnapshot {
    let manifest: SeedManifest
    let accounts: [AppUserProfile]
    let questionBankItems: [QuestionBankItem]
    let supportOptions: [SupportOption]
    let dailyMissionRules: DailyMissionRulesSeed

    var approvedQuestionBankItems: [QuestionBankItem] {
        questionBankItems.filter { $0.reviewState == .approved }
    }
}

struct SeedDataRepository {
    private let loader: SeedLoader

    init(loader: SeedLoader = SeedLoader()) {
        self.loader = loader
    }

    func loadSnapshot() throws -> SeedDataSnapshot {
        let manifest = try loader.load(SeedManifest.self)
        let accountsSeed = try loader.load(AccountsSeed.self)
        let questionBankSeed = try loader.load(QuestionBankSeed.self)
        let supportSeed = try loader.load(SupportOptionsSeed.self)
        let missionRules = try loader.load(DailyMissionRulesSeed.self)

        return SeedDataSnapshot(
            manifest: manifest,
            accounts: accountsSeed.accounts,
            questionBankItems: questionBankSeed.items,
            supportOptions: supportSeed.supportOptions,
            dailyMissionRules: missionRules
        )
    }
}

enum SeedData {
    static let current: SeedDataSnapshot = {
        do {
            return try SeedDataRepository().loadSnapshot()
        } catch {
            assertionFailure("Unable to load seed data: \(error)")
            return fallbackSnapshot
        }
    }()

    static var accounts: [AppUserProfile] { current.accounts }
    static var questionBankItems: [QuestionBankItem] { current.questionBankItems }
    static var approvedQuestionBankItems: [QuestionBankItem] { current.approvedQuestionBankItems }
    static var supportOptions: [SupportOption] { current.supportOptions }
    static let educationInstitutions: [EducationInstitution] = {
        (try? SeedLoader().load(EducationInstitutionCatalogSeed.self).institutions) ?? []
    }()

    static func demoAccount(for role: UserRole) -> AppUserProfile? {
        accounts.first { $0.role == role && $0.isDemo }
    }

    private static let fallbackDate = Date(timeIntervalSince1970: 1_718_668_800)

    private static var fallbackSnapshot: SeedDataSnapshot {
        let fallbackQuestion = QuestionBankItem(
            id: "cap-style-0001",
            level: .a1,
            unit: "基礎文法",
            skill: "主詞搭配",
            source: "English+ fallback seed",
            reviewState: .approved,
            importBatchId: "fallback",
            updatedAt: fallbackDate,
            question: Question(
                prompt: "He ___ a student.",
                type: .grammar,
                options: ["am", "is", "are", "be"],
                answer: "is",
                acceptedAnswers: ["is"],
                explanation: "He 是第三人稱單數，be 動詞要用 is。",
                concept: "He / She / It + is",
                repairHint: "先看主詞 He，再選 is。"
            )
        )

        let fallbackRules = DailyMissionRulesSeed(
            schemaVersion: 1,
            timeScaleRules: [
                TimeScaleRule(timeScale: 2, minutes: 3, label: "短任務"),
                TimeScaleRule(timeScale: 3, minutes: 5, label: "穩定練習")
            ],
            goalRules: [
                MissionGoalRule(minMinutes: 1, maxMinutes: 3, questionGoal: 1),
                MissionGoalRule(minMinutes: 4, maxMinutes: 5, questionGoal: 2)
            ],
            defaultPreferredQuestionTypes: [.grammar, .fillBlank]
        )

        return SeedDataSnapshot(
            manifest: SeedManifest(
                app: "English+",
                seedSchemaVersion: 1,
                generatedFrom: "fallback",
                generatedAt: fallbackDate,
                files: []
            ),
            accounts: [],
            questionBankItems: [fallbackQuestion],
            supportOptions: [],
            dailyMissionRules: fallbackRules
        )
    }
}
