import Foundation

enum QuestionType: String, CaseIterable, Identifiable, Codable {
    case vocabulary
    case grammar
    case fillBlank
    case cloze
    case reading
    case translation
    case dialogue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vocabulary:
            return "單字"
        case .grammar:
            return "文法選擇"
        case .fillBlank:
            return "填空"
        case .cloze:
            return "克漏字"
        case .reading:
            return "閱讀理解"
        case .translation:
            return "翻譯 / 句子重組"
        case .dialogue:
            return "情境對話"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        switch value {
        case "vocabulary", "單字":
            self = .vocabulary
        case "choice", "grammar", "multipleChoice", "文法", "文法選擇", "選擇":
            self = .grammar
        case "fillBlank", "fill_blank", "填空":
            self = .fillBlank
        case "cloze", "克漏字":
            self = .cloze
        case "reading", "閱讀", "閱讀理解":
            self = .reading
        case "translation", "翻譯", "翻譯/句子重組", "翻譯 / 句子重組":
            self = .translation
        case "dialogue", "對話", "情境對話":
            self = .dialogue
        default:
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unknown question type: \(value)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum QuestionLevel: String, CaseIterable, Identifiable, Codable {
    case a1 = "A1"
    case a2 = "A2"
    case b1 = "B1"
    case b2 = "B2"

    var id: String { rawValue }

    var uiTitle: String {
        switch self {
        case .a1:
            return "基礎"
        case .a2:
            return "穩定"
        case .b1:
            return "會考挑戰"
        case .b2:
            return "進階挑戰"
        }
    }
}

enum ReviewState: String, Codable {
    case draft
    case approved
    case archived
}

struct Question: Codable, Equatable {
    let prompt: String
    let type: QuestionType
    let options: [String]
    let answer: String
    let acceptedAnswers: [String]
    let explanation: String
    let concept: String
    let repairHint: String
}

struct QuestionBankSeed: SeedLoadable {
    static let seedFileName = "question_bank_seed"

    let questionBankSchemaVersion: Int
    let app: String
    let items: [QuestionBankItem]
}

struct QuestionBankItem: Identifiable, Codable, Equatable {
    let id: String
    let level: QuestionLevel
    let unit: String
    let skill: String
    let source: String
    let reviewState: ReviewState
    let importBatchId: String
    let updatedAt: Date
    let question: Question
}

struct QuestionPracticeSet: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let type: QuestionType
    let level: QuestionLevel
    let skill: String
    let items: [QuestionBankItem]

    var questionIds: [String] {
        items.map(\.id)
    }

    var questionCount: Int {
        items.count
    }

    var estimatedMinutes: Int {
        max(3, min(18, items.count * 2))
    }

    var previewText: String {
        items.first?.question.concept ?? skill
    }

    static func catalog(
        from items: [QuestionBankItem],
        maxQuestionsPerSet: Int = 12
    ) -> [QuestionPracticeSet] {
        let approved = items.filter { $0.reviewState == .approved }
        let grouped = Dictionary(grouping: approved) { item in
            PracticeSetGroupKey(
                type: item.question.type,
                level: item.level,
                skill: normalizedSkill(item.skill)
            )
        }

        let sortedGroups = grouped.sorted { lhs, rhs in
            if lhs.key.type.rawValue != rhs.key.type.rawValue {
                return lhs.key.type.rawValue < rhs.key.type.rawValue
            }
            if lhs.key.level.rawValue != rhs.key.level.rawValue {
                return lhs.key.level.rawValue < rhs.key.level.rawValue
            }
            return lhs.key.skill < rhs.key.skill
        }

        return sortedGroups.enumerated().flatMap { groupIndex, entry in
            QuestionGroupingEngine.balancedItems(from: entry.value, limit: entry.value.count)
                .chunked(size: max(1, maxQuestionsPerSet))
                .enumerated()
                .map { chunkIndex, chunk in
                    let first = chunk[0]
                    let skill = first.skill.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? first.question.concept
                        : first.skill
                    let setIndex = chunkIndex + 1
                    return QuestionPracticeSet(
                        id: "practice-set-\(groupIndex)-\(setIndex)",
                        title: "\(first.question.type.title) / \(skill)",
                        subtitle: "\(first.level.uiTitle) / \(chunk.count) 題 / 約 \(max(3, min(18, chunk.count * 2))) 分鐘",
                        type: first.question.type,
                        level: first.level,
                        skill: skill,
                        items: chunk
                    )
                }
        }
    }

    private static func normalizedSkill(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "general" : trimmed.lowercased()
    }
}

struct QuestionPracticeSelection: Equatable {
    let items: [QuestionBankItem]
    let fallbackUsed: Bool
}

enum QuestionGroupingEngine {
    private static let recentAnswerPenalty = 90
    private static let recentSkillPenalty = 54
    private static let recentSlotPenalty = 42

    static func balancedItems(
        from items: [QuestionBankItem],
        limit: Int = Int.max
    ) -> [QuestionBankItem] {
        let approvedItems = uniqueItems(items.filter { $0.reviewState == .approved })
        let cappedLimit = min(max(0, limit), approvedItems.count)
        guard cappedLimit > 0 else { return [] }

        var remaining = approvedItems.sorted { stableSortKey($0) < stableSortKey($1) }
        var selected: [QuestionBankItem] = []
        var distributionState = AnswerDistributionState()

        while !remaining.isEmpty, selected.count < cappedLimit {
            let sessionIndex = selected.count
            let nextIndex = remaining.indices.max { leftIndex, rightIndex in
                let left = remaining[leftIndex]
                let right = remaining[rightIndex]
                let leftScore = diversityScore(for: left, state: distributionState, sessionIndex: sessionIndex)
                let rightScore = diversityScore(for: right, state: distributionState, sessionIndex: sessionIndex)
                if leftScore != rightScore {
                    return leftScore < rightScore
                }
                return stableSortKey(left) > stableSortKey(right)
            } ?? remaining.startIndex

            let nextItem = remaining.remove(at: nextIndex)
            selected.append(nextItem)
            distributionState.record(nextItem, sessionIndex: sessionIndex)
        }

        return selected
    }

    static func practiceSelection(
        from candidates: [QuestionBankItem],
        fallbackCandidates: [QuestionBankItem],
        limit: Int
    ) -> QuestionPracticeSelection {
        let cappedLimit = max(0, limit)
        guard cappedLimit > 0 else {
            return QuestionPracticeSelection(items: [], fallbackUsed: false)
        }

        let exactItems = balancedItems(from: candidates, limit: cappedLimit)
        if exactItems.count >= cappedLimit {
            return QuestionPracticeSelection(items: exactItems, fallbackUsed: false)
        }

        let exactIds = Set(exactItems.map(\.id))
        let fallbackItems = balancedFallbackCandidates(from: fallbackCandidates)
            .filter { !exactIds.contains($0.id) }
        let filledItems = balancedItems(from: exactItems + fallbackItems, limit: cappedLimit)
        let fallbackUsed = filledItems.count > exactItems.count || exactItems.count < cappedLimit
        return QuestionPracticeSelection(items: filledItems, fallbackUsed: fallbackUsed)
    }

    static func balancedFallbackCandidates(
        preferredTypes: [QuestionType] = [],
        preferredLevels: [QuestionLevel] = [],
        from items: [QuestionBankItem]
    ) -> [QuestionBankItem] {
        let approved = items.filter { $0.reviewState == .approved }
        var tiers: [[QuestionBankItem]] = []

        if !preferredTypes.isEmpty, !preferredLevels.isEmpty {
            tiers.append(approved.filter { preferredTypes.contains($0.question.type) && preferredLevels.contains($0.level) })
        }
        if !preferredTypes.isEmpty {
            tiers.append(approved.filter { preferredTypes.contains($0.question.type) })
        }
        if !preferredLevels.isEmpty {
            tiers.append(approved.filter { preferredLevels.contains($0.level) })
        }
        tiers.append(approved)

        let perTierLimit = max(24, min(72, approved.count))
        let candidatePool = uniqueItems(
            tiers.flatMap { diverseCandidateWindow(from: $0, limit: perTierLimit) }
        )
        return candidatePool
    }

    static func balancedOptions(
        for item: QuestionBankItem,
        sessionIndex: Int = 0
    ) -> [String] {
        let options = normalizedOptions(for: item)
        guard options.count > 1 else { return options }

        let answerKey = normalizedAnswer(item.question.answer)
        let correctOption = options.first { normalizedAnswer($0) == answerKey } ?? item.question.answer
        var distractors = options.filter { normalizedAnswer($0) != answerKey }
        if !distractors.isEmpty {
            let offset = stableHash("\(item.id)-distractors-\(sessionIndex)") % distractors.count
            distractors = distractors.indices.map { index in
                distractors[(index + offset) % distractors.count]
            }
        }

        let slot = answerSlot(for: item, sessionIndex: sessionIndex)
        var result: [String] = []
        var distractorIndex = 0
        for index in 0..<options.count {
            if index == slot {
                result.append(correctOption)
            } else if distractorIndex < distractors.count {
                result.append(distractors[distractorIndex])
                distractorIndex += 1
            }
        }
        return result
    }

    private static func diversityScore(
        for item: QuestionBankItem,
        state: AnswerDistributionState,
        sessionIndex: Int
    ) -> Int {
        guard state.selectedCount > 0 else {
            return 1_000 + stableHash(item.id) % 29
        }

        let itemAnswer = normalizedAnswer(item.question.answer)
        let itemSkill = normalizedSkill(item)
        let itemSlot = answerSlot(for: item, sessionIndex: sessionIndex)
        var score = 1_000

        if state.recentAnswers.contains(itemAnswer) {
            score -= recentAnswerPenalty
        }
        if state.recentSkills.contains(itemSkill) {
            score -= recentSkillPenalty
        }
        if state.recentSlots.contains(itemSlot) {
            score -= recentSlotPenalty
        }

        score -= (state.answerCounts[itemAnswer] ?? 0) * 18
        score -= (state.skillCounts[itemSkill] ?? 0) * 12
        score -= (state.typeCounts[item.question.type] ?? 0) * 3

        if state.lastType != item.question.type {
            score += 18
        }
        if state.lastLevel != item.level {
            score += 8
        }

        score += stableHash("\(item.id)-\(sessionIndex)") % 17
        return score
    }

    private static func answerSlot(for item: QuestionBankItem, sessionIndex: Int) -> Int {
        let optionCount = max(1, normalizedOptions(for: item).count)
        return stableHash("\(item.id)-answerSlot-\(sessionIndex)") % optionCount
    }

    private static func normalizedOptions(for item: QuestionBankItem) -> [String] {
        var seen: Set<String> = []
        var values: [String] = []

        for option in item.question.options + [item.question.answer] {
            let trimmed = option.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = normalizedAnswer(trimmed)
            guard !trimmed.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            values.append(trimmed)
        }
        return values
    }

    private static func uniqueItems(_ items: [QuestionBankItem]) -> [QuestionBankItem] {
        var seen: Set<String> = []
        var result: [QuestionBankItem] = []
        for item in items where !seen.contains(item.id) {
            seen.insert(item.id)
            result.append(item)
        }
        return result
    }

    private static func diverseCandidateWindow(
        from items: [QuestionBankItem],
        limit: Int
    ) -> [QuestionBankItem] {
        let unique = uniqueItems(items)
        let cappedLimit = min(max(0, limit), unique.count)
        guard cappedLimit > 0 else { return [] }
        guard unique.count > cappedLimit else {
            return unique.sorted { stableSortKey($0) < stableSortKey($1) }
        }

        let groupedBySkill = Dictionary(grouping: unique) { normalizedSkill($0) }
        let sortedSkillKeys = groupedBySkill.keys.sorted()
        let sortedGroups = sortedSkillKeys.map { key in
            (groupedBySkill[key] ?? []).sorted { stableSortKey($0) < stableSortKey($1) }
        }

        var result: [QuestionBankItem] = []
        var offset = 0
        while result.count < cappedLimit {
            var didAppend = false
            for group in sortedGroups where offset < group.count {
                result.append(group[offset])
                didAppend = true
                if result.count >= cappedLimit {
                    break
                }
            }
            if !didAppend {
                break
            }
            offset += 1
        }

        return result
    }

    private static func stableSortKey(_ item: QuestionBankItem) -> String {
        "\(item.question.type.rawValue)-\(item.level.rawValue)-\(normalizedSkill(item))-\(item.id)"
    }

    private static func normalizedSkill(_ item: QuestionBankItem) -> String {
        let skill = item.skill.trimmingCharacters(in: .whitespacesAndNewlines)
        let concept = item.question.concept.trimmingCharacters(in: .whitespacesAndNewlines)
        return (skill.isEmpty ? concept : skill)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private static func normalizedAnswer(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }

    private static func stableHash(_ text: String) -> Int {
        text.unicodeScalars.reduce(23) { partial, scalar in
            ((partial * 33) + Int(scalar.value)) % 1_000_003
        }
    }

    private struct AnswerDistributionState {
        private(set) var selectedCount = 0
        private(set) var answerCounts: [String: Int] = [:]
        private(set) var skillCounts: [String: Int] = [:]
        private(set) var typeCounts: [QuestionType: Int] = [:]
        private(set) var recentAnswers: [String] = []
        private(set) var recentSkills: [String] = []
        private(set) var recentSlots: [Int] = []
        private(set) var lastType: QuestionType?
        private(set) var lastLevel: QuestionLevel?

        mutating func record(_ item: QuestionBankItem, sessionIndex: Int) {
            let answer = QuestionGroupingEngine.normalizedAnswer(item.question.answer)
            let skill = QuestionGroupingEngine.normalizedSkill(item)
            let slot = QuestionGroupingEngine.answerSlot(for: item, sessionIndex: sessionIndex)

            selectedCount += 1
            answerCounts[answer, default: 0] += 1
            skillCounts[skill, default: 0] += 1
            typeCounts[item.question.type, default: 0] += 1
            recentAnswers = Self.appendingRecent(answer, to: recentAnswers)
            recentSkills = Self.appendingRecent(skill, to: recentSkills)
            recentSlots = Self.appendingRecent(slot, to: recentSlots)
            lastType = item.question.type
            lastLevel = item.level
        }

        private static func appendingRecent<T>(_ value: T, to values: [T]) -> [T] {
            Array((values + [value]).suffix(4))
        }
    }
}

private struct PracticeSetGroupKey: Hashable {
    let type: QuestionType
    let level: QuestionLevel
    let skill: String
}

private extension Array {
    func chunked(size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map { start in
            Array(self[start..<Swift.min(start + size, count)])
        }
    }
}
